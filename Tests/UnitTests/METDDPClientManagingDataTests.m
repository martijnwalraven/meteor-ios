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

#import <XCTest/XCTest.h>
#import "XCTestCase+Meteor.h"
#import "METDDPClientTestCase.h"
#import <OCMock/OCMock.h>

#import "METDDPClient.h"
#import "METDDPClient_Internal.h"

#import "MockMETDDPConnection.h"

#import "METDatabase.h"
#import "METDatabase_Internal.h"
#import "METDocumentKey.h"
#import "METDataUpdate.h"
#import "METSubscription.h"
#import "METMethodInvocation.h"

@interface METDDPClientManagingDataTests : METDDPClientTestCase

@end

@implementation METDDPClientManagingDataTests {
  id _database;
}

- (void)setUp {
  [super setUp];
  
  _database = OCMPartialMock(_client.database);
  
  [self establishConnection];
}

- (void)tearDown {
  [super tearDown];
}

#pragma mark - Receiving Data Messages

- (void)testReceivingAddedMessage {
  OCMExpect([_database applyDataUpdate:[OCMArg isEqual:[[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeAdd documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace"}]]]);

  [_connection receiveMessage:@{@"msg": @"added", @"collection": @"players", @"id": @"lovelace", @"fields": @{@"name": @"Ada Lovelace"}}];
  
  OCMVerifyAll(_database);
}

- (void)testReceivingAddedMessageWithoutFields {
  OCMExpect([_database applyDataUpdate:[OCMArg isEqual:[[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeAdd documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{}]]]);
  
  [_connection receiveMessage:@{@"msg": @"added", @"collection": @"players", @"id": @"lovelace"}];
  
  OCMVerifyAll(_database);
}

- (void)testReceivingChangedMessageWithBothFieldsAndCleared {
  OCMExpect(([_database applyDataUpdate:[OCMArg isEqual:[[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeChange documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"score": @30, @"color": [NSNull null]}]]]));
  
  [_connection receiveMessage:@{@"msg": @"changed", @"collection": @"players", @"id": @"lovelace", @"fields":@{@"score": @30}, @"cleared": @[@"color"]}];
  
  OCMVerifyAll(_database);
}

- (void)testReceivingChangedMessageWithFieldsOnly {
  OCMExpect([_database applyDataUpdate:[OCMArg isEqual:[[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeChange documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"score": @30}]]]);
  
  [_connection receiveMessage:@{@"msg": @"changed", @"collection": @"players", @"id": @"lovelace", @"fields":@{@"score": @30}}];
  
  OCMVerifyAll(_database);
}

- (void)testReceivingChangedMessageWithClearedOnly {
  OCMExpect([_database applyDataUpdate:[OCMArg isEqual:[[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeChange documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"color": [NSNull null]}]]]);
  
  [_connection receiveMessage:@{@"msg": @"changed", @"collection": @"players", @"id": @"lovelace", @"cleared": @[@"color"]}];
  
  OCMVerifyAll(_database);
}

- (void)testReceivingRemovedMessage {
  OCMExpect([_database applyDataUpdate:[OCMArg isEqual:[[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeRemove documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:nil]]]);
  
  [_connection receiveMessage:@{@"msg": @"removed", @"collection": @"players", @"id": @"lovelace"}];
  
  OCMVerifyAll(_database);
}

#pragma mark - Subscribing

- (void)testSubscribingWithoutParametersSendsSubMessage {
  [self expectationForSentMessageWithHandler:^(NSDictionary *message) {
    XCTAssertEqualObjects(@"sub", message[@"msg"]);
    XCTAssertNotNil(message[@"id"]);
    XCTAssertEqualObjects(@"allPlayers", message[@"name"]);
    XCTAssertNil(message[@"params"]);
    return YES;
  }];
  
  [_client addSubscriptionWithName:@"allPlayers"];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testSubscribingWithParametersSendsSubMessage {
  [self expectationForSentMessageWithHandler:^(NSDictionary *message) {
    XCTAssertEqualObjects(@"sub", message[@"msg"]);
    XCTAssertNotNil(message[@"id"]);
    XCTAssertEqualObjects(@"playersWithMinimumScore", message[@"name"]);
    XCTAssertEqualObjects(@[@20], message[@"params"]);
    return YES;
  }];
  
  [_client addSubscriptionWithName:@"playersWithMinimumScore" parameters:@[@20]];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testSubscribingWhenNotConnectedSendsMessageWhenReconnected {
  [_client disconnect];
  
  METSubscription *subscription = [_client addSubscriptionWithName:@"allPlayers"];
  
  [self expectationForSentSubMessageForSubscription:subscription];
  
  [_client connect];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testSubscribingReturnsSubscriptionHandle {
  METSubscription *subscription = [_client addSubscriptionWithName:@"allPlayers"];
  
  XCTAssertNotNil(subscription);
  XCTAssertEqualObjects(@"allPlayers", subscription.name);
  XCTAssertFalse(subscription.ready);
}

- (void)testReceivingNoSubMessageInvokesCompletionHandlerWithReceivedError {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  METSubscription *subscription = [_client addSubscriptionWithName:@"playersWithMinimumScore" parameters:@[@20] completionHandler:^(NSError *error) {
    NSError *expectedError = [NSError errorWithDomain:METDDPErrorDomain code:METDDPServerError userInfo:@{NSLocalizedDescriptionKey: @"Received error response from server", NSLocalizedFailureReasonErrorKey:@"Subscription not found"}];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    XCTAssertEqualObjects(expectedError, error);
#pragma clang diagnostic pop
    [expectation fulfill];
  }];
  
  [_connection receiveMessage:@{@"msg": @"nosub", @"id": subscription.identifier, @"error": @{@"error": @404, @"reason": @"Subscription not found"}}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertFalse(subscription.ready);
}

- (void)testUnsubscribingSendsUnsubMessage {
  METSubscription *subscription = [_client addSubscriptionWithName:@"allPlayers"];
  
  [self expectationForSentMessageWithHandler:^BOOL(NSDictionary *message) {
    return [message[@"msg"] isEqualToString:@"unsub"] && [message[@"id"] isEqualToString:subscription.identifier];
  }];
  
  [_client removeSubscription:subscription];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testReceivingReadyMessageSetsReadyStatusAndInvokesCompletionHandlersAfterUpdatesAreFlushed {
  XCTestExpectation *expectation1 = [self expectationWithDescription:@"completion handler invoked"];
  METSubscription *subscription1 = [_client addSubscriptionWithName:@"allPlayers" parameters:nil completionHandler:^(NSError *error) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    XCTAssertNil(error);
#pragma clang diagnostic pop
    [expectation1 fulfill];
  }];
  
  XCTestExpectation *expectation2 = [self expectationWithDescription:@"completion handler invoked"];
  METSubscription *subscription2 = [_client addSubscriptionWithName:@"playersWithMinimumScore" parameters:@[@20] completionHandler:^(NSError *error) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    XCTAssertNil(error);
#pragma clang diagnostic pop
    [expectation2 fulfill];
  }];
  
  OCMExpect([_database performAfterBufferedUpdatesAreFlushed:[OCMArg any]]).andForwardToRealObject();
  
  [_connection receiveMessage:@{@"msg": @"ready", @"subs": @[subscription1.identifier, subscription2.identifier]}];
  
  OCMVerifyAll(_database);
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertTrue(subscription1.ready);
  XCTAssertTrue(subscription2.ready);
}

@end
