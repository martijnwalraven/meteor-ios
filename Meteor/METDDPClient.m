// Copyright (c) 2014-2015 Martijn Walraven
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "METDDPClient.h"
#import "METDDPClient_Internal.h"

#import <UIKit/UIKit.h>

#import "METDDPConnection.h"
#import "METRetryStrategy.h"
#import "METTimer.h"
#import "METDocumentKey.h"
#import "METDataUpdate.h"
#import "METDatabase.h"
#import "METDatabase_Internal.h"
#import "METDocument.h"
#import "METSubscription.h"
#import "METSubscriptionManager.h"
#import "METMethodInvocation.h"
#import "METMethodInvocationCoordinator.h"
#import "METRandomStream.h"
#import "METRandomValueGenerator.h"
#import "METAccount.h"

NSString * const METDDPErrorDomain = @"com.meteor.DDPClient.ErrorDomain";

NSString * const METDDPClientDidChangeConnectionStatusNotification = @"METDDPClientDidChangeConnectionStatusNotification";
NSString * const METDDPClientDidChangeAccountNotification = @"METDDPClientDidChangeAccountNotification";

@interface METDDPClient ()

@property (nonatomic, copy) void (^pendingLoginResumeHandler)();

@end

@implementation METDDPClient {
  dispatch_queue_t _queue;
  METDDPConnection *_connection;
  METDDPConnectionStatus _connectionStatus;
  
  NSArray *_supportedProtocolVersions;
  NSString *_suggestedProtocolVersion;
  NSString *_protocolVersion;
  
  METRetryStrategy *_connectionRetryStrategy;
  METTimer *_connectionRetryTimer;
  NSUInteger _numberOfConnectionRetryAttempts;
  METNetworkReachabilityManager *_networkReachabilityManager;
  UIBackgroundTaskIdentifier _keepAliveBackgroundTask;
  
  NSString *_sessionID;
  
  METDDPHeartbeat *_heartbeat;
  
  METSubscriptionManager *_subscriptionManager;
  METMethodInvocationCoordinator *_methodInvocationCoordinator;
}

#pragma mark - NSKeyValueObserving

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
  if ([key isEqualToString:@"connected"]) {
    return [NSSet setWithObject:@"connectionStatus"];
  }
  
  return [super keyPathsForValuesAffectingValueForKey:key];
}

#pragma mark - Lifecycle

- (instancetype)initWithConnection:(METDDPConnection *)connection {
  self = [super init];
  if (self) {
    _queue = dispatch_queue_create("com.meteor.DDPClient", DISPATCH_QUEUE_SERIAL);
    _connection = connection;
    _connection.delegate = self;
    _connection.delegateQueue = _queue;
    
    _connectionRetryStrategy = [[METRetryStrategy alloc] init];
    _connectionRetryStrategy.minimumTimeInterval = 0.1;
    _connectionRetryStrategy.numberOfAttemptsAtMinimumTimeInterval = 2;
    _connectionRetryStrategy.baseTimeInterval = 1;
    _connectionRetryStrategy.exponent = 2.2;
    _connectionRetryStrategy.randomizationFactor = 0.5;
    
    _connectionRetryTimer = [[METTimer alloc] initWithQueue:_queue block:^{
      [self tryConnecting];
    }];
    
    _networkReachabilityManager = [[METNetworkReachabilityManager alloc] initWithHostName:connection.serverURL.host];
    _networkReachabilityManager.delegate = self;
    _networkReachabilityManager.delegateQueue = _queue;
    [_networkReachabilityManager startMonitoring];
    
    _keepAliveBackgroundTask = UIBackgroundTaskInvalid;
    
    _supportedProtocolVersions = @[@"1", @"pre2", @"pre1"];
    _suggestedProtocolVersion = @"1";
    
    _account = [METAccount defaultAccount];
    
    _database = [[METDatabase alloc] initWithClient:self];
    
    _subscriptionManager = [[METSubscriptionManager alloc] initWithClient:self];
    _subscriptionManager.defaultNotInUseTimeout = 180;
    
    _methodInvocationCoordinator = [[METMethodInvocationCoordinator alloc] initWithClient:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
  }
  return self;
}

- (instancetype)initWithServerURL:(NSURL *)serverURL {
  return [self initWithConnection:[[METDDPConnection alloc] initWithServerURL:serverURL]];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Application State Notifications

- (void)applicationDidEnterBackground:(NSNotification *)notification {
  _keepAliveBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"com.meteor.keep-alive" expirationHandler:^{
    _keepAliveBackgroundTask = UIBackgroundTaskInvalid;
    [self disconnect];
  }];
}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
  if (_keepAliveBackgroundTask != UIBackgroundTaskInvalid) {
    [[UIApplication sharedApplication] endBackgroundTask:_keepAliveBackgroundTask];
    _keepAliveBackgroundTask = UIBackgroundTaskInvalid;
  }
  
  [self connect];
}

#pragma mark - Connecting

- (METDDPConnectionStatus)connectionStatus {
  @synchronized(self) {
    return _connectionStatus;
  }
}

- (void)setConnectionStatus:(METDDPConnectionStatus)connectionStatus {
  @synchronized(self) {
    if (_connectionStatus != connectionStatus) {
      _connectionStatus = connectionStatus;
      [[NSNotificationCenter defaultCenter] postNotificationName:METDDPClientDidChangeConnectionStatusNotification object:self userInfo:nil];
    }
  }
}

- (BOOL)isConnected {
  @synchronized(self) {
    return _connectionStatus == METDDPConnectionStatusConnected;
  }
}

- (void)connect {
  @synchronized(self) {
    if (_connectionStatus == METDDPConnectionStatusOffline || _connectionStatus == METDDPConnectionStatusWaiting) {
        _numberOfConnectionRetryAttempts = 0;
      [self tryConnecting];
    }
  }
}

- (void)disconnect {
  @synchronized(self) {
    _methodInvocationCoordinator.suspended = YES;
    [_heartbeat stop];
    _heartbeat = nil;
    self.connectionStatus = METDDPConnectionStatusOffline;
    [_connection close];
  }
}

- (void)tryConnecting {
  @synchronized(self) {
    if (_connectionStatus == METDDPConnectionStatusWaiting) {
      [_connectionRetryTimer stop];
    }
    self.connectionStatus = METDDPConnectionStatusConnecting;
    [_connection open];
  }
}

- (void)retryConnectingLater {
  @synchronized(self) {
    NSTimeInterval retryInterval = [_connectionRetryStrategy retryIntervalForNumberOfAttempts:_numberOfConnectionRetryAttempts];
    NSLog(@"Will retry opening connection after %f seconds", retryInterval);
    [_connectionRetryTimer startWithTimeInterval:retryInterval];
    _numberOfConnectionRetryAttempts++;
    self.connectionStatus = METDDPConnectionStatusWaiting;
  }
}

- (void)possiblyReconnect {
  @synchronized(self) {
    switch (_connectionStatus) {
      case METDDPConnectionStatusConnected:
        [self disconnect];
        [self retryConnectingLater];
        break;
      case METDDPConnectionStatusConnecting:
        if (_networkReachabilityManager.reachabilityStatus == METNetworkReachabilityStatusNotReachable) {
          [self disconnect];
        } else {
          [self retryConnectingLater];
        }
        break;
      default:
        break;
    }
  }
}

#pragma mark - METDDPConnectionDelegate

- (void)connectionDidOpen:(METDDPConnection *)connection {
  [self establishConnection];
}

- (void)connection:(METDDPConnection *)connection didReceiveMessage:(NSDictionary *)message {
  [self handleReceivedMessage:message];
}

- (void)connection:(METDDPConnection *)connection didFailWithError:(NSError *)error {
  [self possiblyReconnect];
}

- (void)connectionDidClose:(METDDPConnection *)connection {
  [self possiblyReconnect];
}

#pragma mark - METNetworkReachabilityManagerDelegate

- (void)networkReachabilityManager:(METNetworkReachabilityManager *)reachabilityManager didDetectReachabilityStatusChange:(METNetworkReachabilityStatus)reachabilityStatus {
  
  if (reachabilityStatus == METNetworkReachabilityStatusReachable && [UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
    [self connect];
  }
}

#pragma mark - Message Handling

- (void)sendMessage:(NSDictionary *)message {
  [_connection sendMessage:message];
}

- (void)handleReceivedMessage:(NSDictionary *)message {
  NSString *messageType = message[@"msg"];
  
  // Ignore deprecated welcome message
  if (messageType.length == 0) return;
  
  if ([messageType isEqualToString:@"connected"]) {
    [self didReceiveConnectedMessage:message];
  } else if ([messageType isEqualToString:@"failed"]) {
    [self didReceiveFailedMessage:message];
  } else if ([messageType isEqualToString:@"error"]) {
    [self didReceiveErrorMessage:message];
  } else if ([messageType isEqualToString:@"ping"]) {
    [self didReceivePingMessage:message];
  } else if ([messageType isEqualToString:@"pong"]) {
    [self didReceivePongMessage:message];
  } else if ([messageType isEqualToString:@"nosub"]) {
    [self didReceiveNoSubMessage:message];
  } else if ([messageType isEqualToString:@"added"]) {
    [self didReceiveAddedMessage:message];
  } else if ([messageType isEqualToString:@"changed"]) {
    [self didReceiveChangedMessage:message];
  } else if ([messageType isEqualToString:@"removed"]) {
    [self didReceiveRemovedMessage:message];
  } else if ([messageType isEqualToString:@"ready"]) {
    [self didReceiveReadyMessage:message];
  } else if ([messageType isEqualToString:@"result"]) {
    [self didReceiveResultMessage:message];
  } else if ([messageType isEqualToString:@"updated"]) {
    [self didReceiveUpdatedMessage:message];
  } else {
    NSLog(@"Received message of unknown type: %@", message);
  }
}

- (void)didReceiveErrorMessage:(NSDictionary *)message {
  NSString *reason = message[@"reason"];
  // NSString *offendingMessage = message[@"offendingMessage"];
  
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey: @"Received error message from server", NSLocalizedFailureReasonErrorKey: reason};
  NSError *error = [NSError errorWithDomain:METDDPErrorDomain code:METDDPServerError userInfo:userInfo];
  
  if ([_delegate respondsToSelector:@selector(client:didFailWithError:)]) {
    [_delegate client:self didFailWithError:error];
  }
}

#pragma mark - Establishing a Connection

- (void)establishConnection {
  [self sendConnectMessage];
  
  // Don't wait for connected message to minimize setup latency
  [self handleReconnecting];
}

- (void)sendConnectMessage {
  [self sendMessage:@{@"msg": @"connect", @"version": _suggestedProtocolVersion, @"support": _supportedProtocolVersions}];
}

- (void)handleReconnecting {
  [_methodInvocationCoordinator resetWhileAddingMethodInvocationsToTheFrontOfTheQueueUsingBlock:^{
    if (_pendingLoginResumeHandler) {
      _pendingLoginResumeHandler();
    } else if (_account) {
      [self loginWithResumeToken:_account.resumeToken completionHandler:nil];
    }
  }];
  _methodInvocationCoordinator.suspended = NO;
  
  [_database reset];
  
  [_subscriptionManager reviveReadySubscriptionsAfterReconnect];
}

- (void)allSubscriptionsToBeRevivedAfterReconnectAreDone {
  _database.waitingForQuiescence = NO;
}

- (void)didReceiveConnectedMessage:(NSDictionary *)message {
  _protocolVersion = _suggestedProtocolVersion;
  
  _heartbeat = [[METDDPHeartbeat alloc] initWithQueue:_queue];
  _heartbeat.delegate = self;
  _heartbeat.pingInterval = 35;
  _heartbeat.timeoutInterval = 15;
  [_heartbeat start];
  
  NSString *sessionID = message[@"session"];
  
  // If there is an existing session ID, we're reconnecting
  if (_sessionID) {
    NSAssert(![_sessionID isEqualToString:sessionID], @"Reconnecting to an existing session not yet supported");
  }
  
  _sessionID = sessionID;
  
  self.connectionStatus = METDDPConnectionStatusConnected;
  
  NSLog(@"Connected to DDP server with protocol version: %@, sessionID: %@", _protocolVersion, _sessionID);
  
  if ([_delegate respondsToSelector:@selector(clientDidEstablishConnection:)]) {
    [_delegate clientDidEstablishConnection:self];
  }
}

- (void)didReceiveFailedMessage:(NSDictionary *)message {
  NSString *suggestedProtocolVersion = message[@"version"];
  if ([_supportedProtocolVersions containsObject:suggestedProtocolVersion]) {
    _suggestedProtocolVersion = suggestedProtocolVersion;
    NSLog(@"Connection attempt failed, server suggested other supported DDP protocol version: %@", _suggestedProtocolVersion);
    [self disconnect];
    [self connect];
  } else {
    self.connectionStatus = METDDPConnectionStatusFailed;
    
    NSError *error = [self errorWithCode:METDDPVersionError description:@"Couldn't negotiate supported DDP protocol version"];
    [_delegate client:self didFailWithError:error];
  }
}

#pragma mark - METDDPHeartbeatDelegate

- (void)heartbeatWantsToSendPing:(METDDPHeartbeat *)heartbeat {
  [self sendPingMessageWithID:nil];
}

- (void)heartbeatDidTimeout:(METDDPHeartbeat *)heartbeat {
  [self possiblyReconnect];
}

- (void)didReceivePingMessage:(NSDictionary *)message {
  NSString *id = message[@"id"];
  
  [self sendPongMessageWithID:id];
  
  [_heartbeat didReceivePing];
}

- (void)sendPingMessageWithID:(NSString *)id {
  NSMutableDictionary *message = [[NSMutableDictionary alloc] init];
  message[@"msg"] = @"ping";
  if (id) {
    message[@"id"] = id;
  }
  [self sendMessage:message];
}

- (void)sendPongMessageWithID:(NSString *)id {
  NSMutableDictionary *message = [[NSMutableDictionary alloc] init];
  message[@"msg"] = @"pong";
  if (id) {
    message[@"id"] = id;
  }
  [self sendMessage:message];
}

- (void)didReceivePongMessage:(NSDictionary *)message {
  [_heartbeat didReceivePong];
}

#pragma mark - Data Updates

- (void)didReceiveAddedMessage:(NSDictionary *)message {
  id documentID = message[@"id"];
  NSString *collectionName = message[@"collection"];
  NSDictionary *fields = message[@"fields"];
  if (fields == nil) {
    fields = @{};
  }
  
  if (documentID && collectionName) {
    METDocumentKey *documentKey = [METDocumentKey keyWithCollectionName:collectionName documentID:documentID];
    METDataUpdate *update = [[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeAdd documentKey:documentKey fields:fields];
    [self processDataUpdate:update];
  }
}

- (void)didReceiveChangedMessage:(NSDictionary *)message {
  id documentID = message[@"id"];
  NSString *collectionName = message[@"collection"];
  NSMutableDictionary *fields = [[NSMutableDictionary alloc] initWithDictionary:message[@"fields"]];
  NSArray *clearedFields = message[@"cleared"];
  
  if (documentID && collectionName) {
    for (NSString *field in clearedFields) {
      fields[field] = [NSNull null];
    }
    METDocumentKey *documentKey = [METDocumentKey keyWithCollectionName:collectionName documentID:documentID];
    METDataUpdate *update = [[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeChange documentKey:documentKey fields:fields];
    [self processDataUpdate:update];
  }
}

- (void)didReceiveRemovedMessage:(NSDictionary *)message {
  id documentID = message[@"id"];
  NSString *collectionName = message[@"collection"];
  
  if (documentID && collectionName) {
    METDocumentKey *documentKey = [METDocumentKey keyWithCollectionName:collectionName documentID:documentID];
    METDataUpdate *update = [[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeRemove documentKey:documentKey fields:nil];
    [self processDataUpdate:update];
  }
}

- (void)processDataUpdate:(METDataUpdate *)update {
  if (![_methodInvocationCoordinator applyDataUpdate:update]) {
    [_database applyDataUpdate:update];
  }
}

#pragma mark - Subscriptions

- (METSubscription *)addSubscriptionWithName:(NSString *)name {
  return [self addSubscriptionWithName:name parameters:nil completionHandler:nil];
}

- (METSubscription *)addSubscriptionWithName:(NSString *)name completionHandler:(METSubscriptionCompletionHandler)completionHandler {
  return [self addSubscriptionWithName:name parameters:nil completionHandler:completionHandler];
}

- (METSubscription *)addSubscriptionWithName:(NSString *)name parameters:(NSArray *)parameters {
  return [self addSubscriptionWithName:name parameters:parameters completionHandler:nil];
}

- (METSubscription *)addSubscriptionWithName:(NSString *)name parameters:(NSArray *)parameters completionHandler:(METSubscriptionCompletionHandler)completionHandler {
  return [_subscriptionManager addSubscriptionWithName:name parameters:[self convertParameters:parameters] completionHandler:completionHandler];
}

- (void)sendSubMessageForSubscription:(METSubscription *)subscription {
  NSParameterAssert(subscription);
  
  NSMutableDictionary *message = [[NSMutableDictionary alloc] init];
  message[@"msg"] = @"sub";
  message[@"id"] = subscription.identifier;
  message[@"name"] = subscription.name;
  
  id parameters = subscription.parameters;
  if (parameters) {
    message[@"params"] = parameters;
  }
  
  [self sendMessage:message];
}

- (void)removeSubscription:(METSubscription *)subscription {
  [_subscriptionManager removeSubscription:subscription];
}

- (void)sendUnsubMessageForSubscription:(METSubscription *)subscription {
  NSParameterAssert(subscription);
  
  [self sendMessage:@{@"msg": @"unsub", @"id": subscription.identifier}];
}

- (void)didReceiveNoSubMessage:(NSDictionary *)message {
  NSString *subscriptionID = message[@"id"];
  if (!subscriptionID) return;
  
  NSDictionary *errorResponse = message[@"error"];
  NSError *error = errorResponse ? [self errorWithErrorResponse:errorResponse] : nil;
  
  [_subscriptionManager didReceiveNosubForSubscriptionWithID:subscriptionID error:error];
}

- (void)didReceiveReadyMessage:(NSDictionary *)message {
  NSArray *subscriptionIDs = message[@"subs"];
  if (!subscriptionIDs) return;
  
  for (NSString *subscriptionID in subscriptionIDs) {
    [_subscriptionManager didReceiveReadyForSubscriptionWithID:subscriptionID];
  }
}

#pragma mark - RPC Methods

- (void)defineStubForMethodWithName:(NSString *)methodName usingBlock:(METMethodStub)stub {
  [_methodInvocationCoordinator defineStubForMethodWithName:methodName usingBlock:stub];
}

- (id)callMethodWithName:(NSString *)methodName parameters:(NSArray *)parameters {
  return [self callMethodWithName:methodName parameters:parameters completionHandler:nil];
}

- (id)callMethodWithName:(NSString *)methodName parameters:(NSArray *)parameters completionHandler:(METMethodCompletionHandler)completionHandler {
  return [self callMethodWithName:methodName parameters:parameters options:0 completionHandler:completionHandler];
}

- (id)callMethodWithName:(NSString *)methodName parameters:(NSArray *)parameters options:(METMethodCallOptions)options completionHandler:(METMethodCompletionHandler)completionHandler {
  return [self callMethodWithName:methodName parameters:parameters options:options receivedResultHandler:nil completionHandler:completionHandler];
}

- (id)callMethodWithName:(NSString *)methodName parameters:(NSArray *)parameters options:(METMethodCallOptions)options receivedResultHandler:(METMethodCompletionHandler)receivedResultHandler completionHandler:(METMethodCompletionHandler)completionHandler {
  return [_methodInvocationCoordinator callMethodWithName:methodName parameters:[self convertParameters:parameters] options:options receivedResultHandler:receivedResultHandler completionHandler:completionHandler];
}

- (METMethodInvocationContext *)currentMethodInvocationContext {
  return _methodInvocationCoordinator.currentMethodInvocationContext;
}

- (void)sendMethodMessageForMethodInvocation:(METMethodInvocation *)methodInvocation {
  NSMutableDictionary *message = [[NSMutableDictionary alloc] init];
  message[@"msg"] = @"method";
  message[@"method"] = methodInvocation.methodName;
  message[@"id"] = methodInvocation.methodID;
  
  NSDictionary *parameters = methodInvocation.parameters;
  if (parameters) {
    message[@"params"] = parameters;
  }
  
  NSString *randomSeed = methodInvocation.randomSeed;
  if (randomSeed) {
    message[@"randomSeed"] = randomSeed;
  }
  
  [self sendMessage:message];
}

- (void)didReceiveResultMessage:(NSDictionary *)message {
  NSString *methodID = message[@"id"];
  if (!methodID) return;
  
  id result = message[@"result"];
  NSDictionary *errorResponse = message[@"error"];
  NSError *error = errorResponse ? [self errorWithErrorResponse:errorResponse] : nil;
  
  [_methodInvocationCoordinator didReceiveResult:result error:error forMethodID:methodID];
}

- (void)didReceiveUpdatedMessage:(NSDictionary *)message {
  NSArray *methodIDs = message[@"methods"];
  
  for (NSString *methodID in methodIDs) {
    [_methodInvocationCoordinator didReceiveUpdatesDoneForMethodID:methodID];
  }
}

#pragma mark - Accounts

- (void)setAccount:(METAccount *)account {
  if (_account != account) {
    _account = account;
    [METAccount setDefaultAccount:_account];
    [[NSNotificationCenter defaultCenter] postNotificationName:METDDPClientDidChangeAccountNotification object:self userInfo:nil];
  }
}

- (NSString *)userID {
  return _account.userID;
}

- (void)loginWithMethodName:(NSString *)methodName parameters:(NSArray *)parameters completionHandler:(METLogInCompletionHandler)completionHandler {
  self.loggingIn = YES;
  __block BOOL reconnected = NO;
  __weak METDDPClient *weakSelf = self;
  [self callMethodWithName:methodName parameters:parameters options:METMethodCallOptionsBarrier receivedResultHandler:^(id result, NSError *error) {
    self.pendingLoginResumeHandler = ^{
      reconnected = YES;
      NSString *resumeToken = result[@"token"];
      [weakSelf loginWithResumeToken:resumeToken completionHandler:completionHandler];
    };
  } completionHandler:^(id result, NSError *error) {
    if (reconnected) return;
    
    _pendingLoginResumeHandler = nil;
    self.loggingIn = NO;
    self.account = [self accountFromLoginMethodResult:result];
    if (completionHandler) {
      completionHandler(error);
    }
  }];
}

- (METAccount *)accountFromLoginMethodResult:(id)result {
  if (result && [result isKindOfClass:[NSDictionary class]]) {
    NSString *userID = result[@"id"];
    NSString *resumeToken = result[@"token"];
    NSDate *expiryDate = result[@"tokenExpires"];
    
    if (userID && resumeToken && expiryDate) {
      METAccount *account = [[METAccount alloc] initWithUserID:userID resumeToken:resumeToken expiryDate:expiryDate];
      return account;
    }
  }
  return nil;
}

- (void)loginWithResumeToken:(NSString *)resumeToken completionHandler:(METLogInCompletionHandler)completionHandler {
  [self loginWithMethodName:@"login" parameters:@[@{@"resume": resumeToken}] completionHandler:completionHandler];
}

- (void)logoutWithCompletionHandler:(METLogOutCompletionHandler)completionHandler {
  [self callMethodWithName:@"logout" parameters:nil options:METMethodCallOptionsBarrier completionHandler:^(id result, NSError *error) {
    self.account = nil;
    if (completionHandler) {
      completionHandler(error);
    }
  }];
}

#pragma mark - Helper Methods

- (NSArray *)convertParameters:(NSArray *)parameters {
  return parameters;
}

- (NSError *)errorWithCode:(NSInteger)code description:(NSString *)description {
  NSDictionary *userInfo = @{NSLocalizedDescriptionKey: description};
  return [NSError errorWithDomain:METDDPErrorDomain code:code userInfo:userInfo];
}

- (NSError *)errorWithErrorResponse:(NSDictionary *)errorResponse {
  NSString *error = errorResponse[@"error"];
  if ([error isKindOfClass:[NSNumber class]]) {
    error = [((NSNumber *)error) stringValue];
  }
  NSString *reason = errorResponse[@"reason"];
  if (!reason) {
    NSLog(@"No reason specified in DDP error response");
    reason = error;
  }
  
  return [NSError errorWithDomain:METDDPErrorDomain code:METDDPServerError userInfo:@{NSLocalizedDescriptionKey: @"Received error response from server", NSLocalizedFailureReasonErrorKey: reason}];
}

@end
