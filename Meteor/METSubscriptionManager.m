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

#import "METSubscriptionManager.h"

#import "METSubscription_Internal.h"
#import "METDDPClient.h"
#import "METDDPClient_Internal.h"
#import "METRandomValueGenerator.h"
#import "METDatabase.h"
#import "METDatabase_Internal.h"
#import "METMethodInvocationCoordinator.h"
#import "METTimer.h"

@interface METSubscriptionManager ()

@property (assign, nonatomic, readonly, getter=isWaitingForSubscriptionsToBeRevivedAfterReconnect) BOOL waitingForSubscriptionsToBeRevivedAfterReconnect;

@end

@implementation METSubscriptionManager {
  dispatch_queue_t _queue;
  NSMutableDictionary *_subscriptionsByID;
  NSMutableSet *_subscriptionsToBeRevivedAfterReconnect;
}

- (instancetype)initWithClient:(METDDPClient *)client {
  self = [super init];
  if (self) {
    _client = client;
    _queue = dispatch_queue_create("com.meteor.SubscriptionManager", DISPATCH_QUEUE_SERIAL);
    _subscriptionsByID = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (METSubscription *)addSubscriptionWithName:(NSString *)name parameters:(NSArray *)parameters completionHandler:(METSubscriptionCompletionHandler)completionHandler {
  NSParameterAssert(name);
  
  __block METSubscription *subscription;
  
  dispatch_sync(_queue, ^{
    subscription = [self existingSubscriptionWithName:name parameters:parameters];
    if (subscription) {
      [subscription beginUse];
      [subscription.reuseTimer stop];
      if (completionHandler) {
        [subscription whenDone:completionHandler];
      }
      return;
    };
    
    NSString *subscriptionID = [[METRandomValueGenerator defaultRandomValueGenerator] randomIdentifier];
    subscription = [[METSubscription alloc] initWithIdentifier:subscriptionID name:name parameters:parameters];
    if (completionHandler) {
      [subscription whenDone:completionHandler];
    }
    subscription.notInUseTimeout = _defaultNotInUseTimeout;
    [subscription beginUse];
    
    _subscriptionsByID[subscriptionID] = subscription;
    if (_client.connected) {
      [_client sendSubMessageForSubscription:subscription];
    }
  });
  
  return subscription;
}

- (METSubscription *)existingSubscriptionWithName:(NSString *)name parameters:(NSArray *)parameters {
  __block METSubscription *existingSubscription;
  
  [_subscriptionsByID enumerateKeysAndObjectsUsingBlock:^(NSString *subscriptionID, METSubscription *subscription, BOOL *stop) {
    if ([subscription.name isEqualToString:name] && (subscription.parameters == parameters || [subscription.parameters isEqualToArray:parameters])) {
      existingSubscription = subscription;
      *stop = YES;
    }
  }];
        
  return existingSubscription;
}

- (void)removeSubscription:(METSubscription *)subscription {
  NSParameterAssert(subscription);
  
  dispatch_async(_queue, ^{
    [subscription endUse];
    
    if (!subscription.inUse) {
      [self removeSubscriptionToBeRevivedAfterConnect:subscription];
      
      if (subscription.reuseTimer == nil) {
        subscription.reuseTimer = [[METTimer alloc] initWithQueue:_queue block:^{
          // Subscription was reused before timeout
          if (subscription.inUse) {
            return;
          }
          
          [_subscriptionsByID removeObjectForKey:subscription.identifier];
          
          if (_client.connected) {
            [_client sendUnsubMessageForSubscription:subscription];
          }
        }];
      }
      [subscription.reuseTimer startWithTimeInterval:subscription.notInUseTimeout];
    }
  });
}

- (void)didReceiveReadyForSubscriptionWithID:(NSString *)subscriptionID {
  NSParameterAssert(subscriptionID);
  
  dispatch_async(_queue, ^{
    METSubscription *subscription = _subscriptionsByID[subscriptionID];
    if (!subscription) {
      NSLog(@"Received ready message for unknown subscription ID: %@", subscriptionID);
      return;
    }
            
    [self removeSubscriptionToBeRevivedAfterConnect:subscription];
    
    [_client.methodInvocationCoordinator performAfterAllCurrentlyBufferedDocumentsAreFlushed:^{
      [subscription didChangeStatus:METSubscriptionStatusReady error:nil];
    }];
  });
}

- (void)didReceiveNosubForSubscriptionWithID:(NSString *)subscriptionID error:(NSError *)error {
  NSParameterAssert(subscriptionID);

  dispatch_async(_queue, ^{
    METSubscription *subscription = _subscriptionsByID[subscriptionID];
    if (!subscription) {
      return;
    }
    
    [self removeSubscriptionToBeRevivedAfterConnect:subscription];

    [subscription didChangeStatus:METSubscriptionStatusError error:error];
  });
}

- (void)reviveReadySubscriptionsAfterReconnect {
  dispatch_sync(_queue, ^{
    _subscriptionsToBeRevivedAfterReconnect = [[NSMutableSet alloc] init];
    NSDictionary *existingSubscriptionsByID = _subscriptionsByID;
    _subscriptionsByID = [existingSubscriptionsByID mutableCopy];
    [existingSubscriptionsByID enumerateKeysAndObjectsUsingBlock:^(NSString *identifier, METSubscription *subscription, BOOL *stop) {
      subscription.reuseTimer = nil;
      
      if (subscription.inUse) {
        if (subscription.ready) {
          [_subscriptionsToBeRevivedAfterReconnect addObject:subscription];
        }
        [_client sendSubMessageForSubscription:subscription];
      } else {
        [_subscriptionsByID removeObjectForKey:subscription.identifier];
      }
    }];
    
    if (!self.waitingForSubscriptionsToBeRevivedAfterReconnect) {
      // If there are no subscriptions to be revived, there is no need to wait for quiescence
      _client.database.waitingForQuiescence = NO;
      [_client.database flushDataUpdates];
    } else {
      _client.database.waitingForQuiescence = YES;
    }
  });
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
