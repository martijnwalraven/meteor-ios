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

#import <XCTest/XCTest.h>
#import "XCTAsyncTestCase.h"

#import "METSubscriptionManager.h"

#import "METDDPClient.h"
#import "METDDPClient_Internal.h"

@interface METSubscriptionManagerTests : XCTAsyncTestCase

@end

@implementation METSubscriptionManagerTests {
  METDDPClient *_client;
  METSubscriptionManager *_subscriptionManager;
}

- (void)setUp {
  _client = [[METDDPClient alloc] initWithConnection:nil];
  _subscriptionManager = [[METSubscriptionManager alloc] initWithClient:_client];
}

- (void)testInvokesCompletionHandlerWhenSubscriptionBecomesReady {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  METSubscription *subscription = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:^(NSError *error) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    XCTAssertNil(error);
#pragma clang diagnostic pop
    [expectation fulfill];
  }];
  
  [_subscriptionManager didReceiveReadyForSubscriptionWithID:subscription.identifier];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testInvokesCompletionHandlerWithErrorWhenNoSubIsReceived {
  NSError *expectedError = [NSError errorWithDomain:METDDPErrorDomain code:METDDPServerError userInfo:@{NSLocalizedDescriptionKey: @"Received error response from server", NSLocalizedFailureReasonErrorKey:@"bla"}];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  METSubscription *subscription = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:^(NSError *error) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    XCTAssertEqualObjects(expectedError, error);
#pragma clang diagnostic pop
    [expectation fulfill];
  }];
  
  [_subscriptionManager didReceiveNosubForSubscriptionWithID:subscription.identifier error:expectedError];

  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testReturnsExistingSubscriptionIfNameAndParametersMatch {
  METSubscription *subscription1 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  
  METSubscription *subscription2 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  
  XCTAssertEqual(subscription1, subscription2);
}

- (void)testReturnsExistingSubscriptionIfNameMatchesAndThereAreNoParameters {
  METSubscription *subscription1 = [_subscriptionManager addSubscriptionWithName:@"publicLists" parameters:nil completionHandler:nil];
  
  METSubscription *subscription2 = [_subscriptionManager addSubscriptionWithName:@"publicLists" parameters:nil completionHandler:nil];
  
  XCTAssertEqual(subscription1, subscription2);
}

- (void)testDoesNotReturnExistingSubscriptionIfParametersDontMatch {
  METSubscription *subscription1 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  
  METSubscription *subscription2 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"foo"] completionHandler:nil];
  
  XCTAssertNotEqual(subscription1, subscription2);
}

- (void)testReturningExistingSubscriptionInvokesCompletionHandlerImmediatelyIfSubscriptionIsReady {
  METSubscription *subscription1 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  [_subscriptionManager didReceiveReadyForSubscriptionWithID:subscription1.identifier];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:^(NSError *error) {
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testReturningExistingSubscriptionInvokesCompletionHandlersWhenSubscriptionBecomesReady {
  XCTestExpectation *expectation1 = [self expectationWithDescription:@"completion handler invoked"];
  METSubscription *subscription1 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:^(NSError *error) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    XCTAssertNil(error);
#pragma clang diagnostic pop
    [expectation1 fulfill];
  }];
  
  XCTestExpectation *expectation2 = [self expectationWithDescription:@"completion handler invoked"];
  [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:^(NSError *error) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    XCTAssertNil(error);
#pragma clang diagnostic pop
    [expectation2 fulfill];
  }];
  
  [_subscriptionManager didReceiveReadyForSubscriptionWithID:subscription1.identifier];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testReturningExistingSubscriptionInvokesCompletionHandlersWithErrorWhenNoSubIsReceived {
  NSError *expectedError = [NSError errorWithDomain:METDDPErrorDomain code:METDDPServerError userInfo:@{NSLocalizedDescriptionKey: @"Received error response from server", NSLocalizedFailureReasonErrorKey:@"bla"}];
  
  XCTestExpectation *expectation1 = [self expectationWithDescription:@"completion handler invoked"];
  METSubscription *subscription1 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:^(NSError *error) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    XCTAssertEqualObjects(expectedError, error);
#pragma clang diagnostic pop
    [expectation1 fulfill];
  }];
  
  XCTestExpectation *expectation2 = [self expectationWithDescription:@"completion handler invoked"];
  [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:^(NSError *error) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    XCTAssertEqualObjects(expectedError, error);
#pragma clang diagnostic pop
    [expectation2 fulfill];
  }];
  
  [_subscriptionManager didReceiveNosubForSubscriptionWithID:subscription1.identifier error:expectedError];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testSubscriptionIsRemovedWhenNoLongerInUseAfterTimeout {
  _subscriptionManager.defaultNotInUseTimeout = 0.1;
  
  METSubscription *subscription1 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  
  [_subscriptionManager removeSubscription:subscription1];
  
  [self waitForTimeInterval:0.2];
  
  METSubscription *subscription2 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  
  XCTAssertNotEqual(subscription1, subscription2);
}

- (void)testSubscriptionIsNotRemovedWhenReusedBeforeTimeout {
  _subscriptionManager.defaultNotInUseTimeout = 0.2;
  
  METSubscription *subscription1 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  
  [_subscriptionManager removeSubscription:subscription1];
  
  [self waitForTimeInterval:0.1];
  
  METSubscription *subscription2 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  
  XCTAssertEqual(subscription1, subscription2);
}

- (void)testReusingSubscriptionResetsTimeout {
  _subscriptionManager.defaultNotInUseTimeout = 0.2;
  
  METSubscription *subscription1 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  [_subscriptionManager removeSubscription:subscription1];
  
  [self waitForTimeInterval:0.1];
  
  [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  [_subscriptionManager removeSubscription:subscription1];
  
  [self waitForTimeInterval:0.1];
  
  METSubscription *subscription2 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  
  XCTAssertEqual(subscription1, subscription2);
}

- (void)testSubscriptionIsNotRemovedWhenStillInUse {
  _subscriptionManager.defaultNotInUseTimeout = 0;
  
  METSubscription *subscription1 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  
  [_subscriptionManager removeSubscription:subscription1];
  
  [self waitForTimeInterval:0.1];
  
  METSubscription *subscription2 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  
  XCTAssertEqual(subscription1, subscription2);
}

- (void)testTimeoutCanBeSpecifiedPerSubscription {
  _subscriptionManager.defaultNotInUseTimeout = 0.1;
  
  METSubscription *subscription1 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  subscription1.notInUseTimeout = 1;
  
  [_subscriptionManager removeSubscription:subscription1];
  
  [self waitForTimeInterval:0.2];
  
  METSubscription *subscription2 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  
  XCTAssertEqual(subscription1, subscription2);
}

- (void)testSubscriptionRemovedImmediatelyWhenSubHasNotInUseTimeoutOfZero {
  _subscriptionManager.defaultNotInUseTimeout = 0;
  
  METSubscription *subscription1 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  [_subscriptionManager removeSubscription:subscription1];
  METSubscription *subscription2 = [_subscriptionManager addSubscriptionWithName:@"todos" parameters:@[@"bla"] completionHandler:nil];
  
  XCTAssertNotEqual(subscription1, subscription2);
}

@end
