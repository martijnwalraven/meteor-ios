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

#import "METDDPClientTestCase.h"

#import "METDDPClient.h"
#import "METDDPClient_Internal.h"

#import "MockMETDDPConnection.h"
#import "METMethodInvocation.h"
#import "METMethodInvocation_Internal.h"
#import "METMethodInvocationCoordinator.h"
#import "METMethodInvocationCoordinator_Testing.h"
#import "METSubscription.h"
#import "METRandomValueGenerator.h"

@implementation METDDPClientTestCase {
}

- (void)setUp {
  [super setUp];
  _connection = [[MockMETDDPConnection alloc] init];
  _client = [[METDDPClient alloc] initWithConnection:_connection];
}

- (void)tearDown {
  [super tearDown];
}

#pragma mark - Helper Methods

- (void)establishConnection {
  [_client connect];
  NSString *sessionID = [[METRandomValueGenerator defaultRandomValueGenerator] randomIdentifier];
  [_connection receiveMessage:@{@"msg": @"connected", @"session": sessionID}];
}

- (XCTestExpectation *)expectationForSentMessageWithHandler:(BOOL (^)(NSDictionary *message))handler {
  XCTestExpectation *expectation = [self expectationForNotification:METDDPConnectionDidSendMessageNotification object:_connection handler:^BOOL(NSNotification *notification) {
    NSDictionary *message = notification.userInfo[METDDPConnectionSentMessageKey];
    return handler(message);
  }];
  return expectation;
}

- (XCTestExpectation *)expectationForSentMessage:(NSDictionary *)expectedMessage {
  XCTestExpectation *expectation = [self expectationForSentMessageWithHandler:^(NSDictionary *actualMessage) {
    return [expectedMessage isEqualToDictionary:actualMessage];
  }];
  return expectation;
}

- (XCTestExpectation *)expectationForSentMessageForMethodWithName:(NSString *)methodName {
  return [self expectationForSentMessageWithHandler:^BOOL(NSDictionary *message) {
    return [message[@"msg"] isEqualToString:@"method"] && [message[@"method"] isEqualToString:methodName];
  }];
}

- (XCTestExpectation *)expectationForSentMessageForMethodWithName:(NSString *)methodName parameters:(NSArray *)parameters {
  return [self expectationForSentMessageWithHandler:^BOOL(NSDictionary *message) {
    return [message[@"msg"] isEqualToString:@"method"] && [message[@"method"] isEqualToString:methodName] && (message[@"params"] == parameters || [message[@"params"] isEqualToArray:parameters]);
  }];
}

- (XCTestExpectation *)expectationForSentMessageForMethodInvocation:(METMethodInvocation *)methodInvocation {
  return [self expectationForSentMessageWithHandler:^BOOL(NSDictionary *message) {
    return [message[@"msg"] isEqualToString:@"method"] && [message[@"id"] isEqualToString:methodInvocation.methodID] && [message[@"method"] isEqualToString:methodInvocation.methodName] && (message[@"params"] == methodInvocation.parameters || [message[@"params"] isEqualToArray:methodInvocation.parameters]);
  }];
}

- (XCTestExpectation *)expectationForSentSubMessageForSubscription:(METSubscription *)subscription {
  return [self expectationForSentMessageWithHandler:^BOOL(NSDictionary *message) {
    return [message[@"msg"] isEqualToString:@"sub"] && [message[@"name"] isEqualToString:subscription.name] && (message[@"params"] == subscription.parameters || [message[@"params"] isEqualToArray:subscription.parameters]);
  }];
}

- (void)whileNotExpectingSentMessageWithHandler:(BOOL (^)(NSDictionary *message))handler performBlock:(void (^)())block {
  id observer = [[NSNotificationCenter defaultCenter] addObserverForName:METDDPConnectionDidSendMessageNotification object:nil queue:nil usingBlock:^(NSNotification *notification) {
    NSDictionary *message = notification.userInfo[METDDPConnectionSentMessageKey];
    if (handler(message)) {
      XCTFail(@"Should not have sent message: %@", message);
    }
  }];
  
  block();
  
  [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

- (NSString *)lastMethodID {
  return _client.methodInvocationCoordinator.lastMethodInvocation.methodID;
}

- (METMethodInvocation *)lastMethodInvocation {
  return _client.methodInvocationCoordinator.lastMethodInvocation;
}

- (METMethodInvocation *)methodInvocationWithName:(NSString *)methodName {
  return [_client.methodInvocationCoordinator methodInvocationWithName:methodName];
}

@end
