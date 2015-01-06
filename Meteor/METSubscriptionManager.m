// Copyright (c) 2014 Martijn Walraven
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

#import "METSubscriptionManager.h"

#import "METDDPClient.h"
#import "METDDPClient_Internal.h"
#import "METRandomValueGenerator.h"
#import "METMethodInvocationCoordinator.h"

@implementation METSubscriptionManager {
  NSMutableDictionary *_subscriptionsByID;
  NSMutableSet *_subscriptionsToBeRevivedAfterReconnect;
}

- (instancetype)initWithClient:(METDDPClient *)client {
  self = [super init];
  if (self) {
    _client = client;
    
    _subscriptionsByID = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (METSubscription *)addSubscriptionWithName:(NSString *)name parameters:(NSArray *)parameters completionHandler:(METSubscriptionCompletionHandler)completionHandler {
  NSParameterAssert(name);
  
  NSString *subscriptionID = [[METRandomValueGenerator defaultRandomValueGenerator] randomIdentifier];
  METSubscription *subscription = [[METSubscription alloc] initWithIdentifier:subscriptionID name:name];
  subscription.parameters = parameters;
  subscription.completionHandler = completionHandler;
  
  _subscriptionsByID[subscriptionID] = subscription;
  if (_client.connected) {
    [_client sendSubMessageForSubscription:subscription];
  }
  
  return subscription;
}

- (void)removeSubscription:(METSubscription *)subscription {
  NSParameterAssert(subscription);
  
  [_subscriptionsByID removeObjectForKey:subscription.identifier];
  [self removeSubscriptionToBeRevivedAfterConnect:subscription];
  
  if (_client.connected) {
    [_client sendUnsubMessageForSubscription:subscription];
  }
}

- (void)didReceiveReadyForSubscriptionWithID:(NSString *)subscriptionID {
  NSParameterAssert(subscriptionID);
  
  METSubscription *subscription = _subscriptionsByID[subscriptionID];
  if (!subscription) {
    NSLog(@"Received ready message for unknown subscription ID: %@", subscriptionID);
    return;
  }
  
  [self removeSubscriptionToBeRevivedAfterConnect:subscription];
  
  [_client.methodInvocationCoordinator performAfterAllCurrentlyBufferedDocumentsAreFlushed:^{
    METSubscriptionCompletionHandler completionHandler = subscription.completionHandler;
    subscription.ready = YES;
    if (completionHandler) {
      completionHandler(nil);
    }
  }];
}

- (void)didReceiveNosubForSubscriptionWithID:(NSString *)subscriptionID error:(NSError *)error {
  METSubscription *subscription = _subscriptionsByID[subscriptionID];
  if (!subscription) {
    return;
  }
  
  [self removeSubscriptionToBeRevivedAfterConnect:subscription];
  
  METSubscriptionCompletionHandler completionHandler = subscription.completionHandler;
  if (completionHandler) {
    completionHandler(error);
  }
}

- (void)sendSubMessagesForSubscriptionsToBeRevivedAfterReconnect {
  _subscriptionsToBeRevivedAfterReconnect = [[NSMutableSet alloc] init];
  [_subscriptionsByID enumerateKeysAndObjectsUsingBlock:^(NSString *identifier, METSubscription *subscription, BOOL *stop) {
    if (subscription.ready) {
      [_subscriptionsToBeRevivedAfterReconnect addObject:subscription];
    }
    [_client sendSubMessageForSubscription:subscription];
  }];
}

- (BOOL)isWaitingForSubscriptionsToBeRevivedAfterReconnect {
  return _subscriptionsToBeRevivedAfterReconnect.count > 0;
}

- (void)removeSubscriptionToBeRevivedAfterConnect:(METSubscription *)subscription {
  [_subscriptionsToBeRevivedAfterReconnect removeObject:subscription];
  if (!self.waitingForSubscriptionsToBeRevivedAfterReconnect) {
    _subscriptionsToBeRevivedAfterReconnect = nil;
    [_client allSubscriptionsToBeRevivedAfterReconnectAreDone];
  }
}

@end
