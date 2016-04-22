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

#import "METDDPConnection.h"
#import "METDDPHeartbeat.h"
#import "METNetworkReachabilityManager.h"

@class METDataUpdate;
@class METMethodInvocation;
@class METMethodInvocationContext;
@class METMethodInvocationCoordinator;

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSInteger, METMethodCallOptions) {
  METMethodCallOptionsNone = 0,
  METMethodCallOptionsReturnStubValue = 1 << 0,
  METMethodCallOptionsBarrier = 1 << 1
};

@class METDocumentCache;

@interface METDDPClient () <METDDPConnectionDelegate, METDDPHeartbeatDelegate, METNetworkReachabilityManagerDelegate>

@property (assign, nonatomic, readwrite) METDDPConnectionStatus connectionStatus;
@property (strong, nonatomic) METNetworkReachabilityManager *networkReachabilityManager;

@property (nullable, copy, nonatomic, readonly) NSString *protocolVersion;
@property (nullable, copy, nonatomic, readonly) NSString *sessionID;

@property (strong, nonatomic, readwrite) METDatabase *database;

@property (assign, nonatomic, readwrite, getter=isLoggingIn) BOOL loggingIn;
@property (nullable, copy, nonatomic) METAccount *account;

- (void)processDataUpdate:(METDataUpdate *)update;

- (void)sendSubMessageForSubscription:(METSubscription *)subscription;
- (void)sendUnsubMessageForSubscription:(METSubscription *)subscription;
- (void)allSubscriptionsToBeRevivedAfterReconnectAreDone;

- (id)callMethodWithName:(NSString *)methodName parameters:(nullable NSArray *)parameters options:(METMethodCallOptions)options completionHandler:(nullable METMethodCompletionHandler)completionHandler;
- (id)callMethodWithName:(NSString *)methodName parameters:(nullable NSArray *)parameters options:(METMethodCallOptions)options receivedResultHandler:(nullable METMethodCompletionHandler)receivedResultHandler completionHandler:(nullable METMethodCompletionHandler)completionHandler;

@property (strong, nonatomic, readonly) METMethodInvocationCoordinator *methodInvocationCoordinator;
@property (nullable, strong, nonatomic, readonly) METMethodInvocationContext *currentMethodInvocationContext;
- (void)sendMethodMessageForMethodInvocation:(METMethodInvocation *)methodInvocation;

- (NSArray *)convertParameters:(NSArray *)parameters;

@end

NS_ASSUME_NONNULL_END
