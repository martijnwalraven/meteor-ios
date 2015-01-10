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
#import "METDDPClientTestCase.h"
#import <OCMock/OCMock.h>

#import "METDDPClient.h"
#import "METDDPClient_Internal.h"

#import "MockMETDDPConnection.h"

#import "METMethodInvocation.h"
#import "METMethodInvocation_Internal.h"

#import "METAccount.h"

@interface METDDPClientAccountsTests : METDDPClientTestCase

@end

@implementation METDDPClientAccountsTests

- (void)setUp {
  [super setUp];
  
  [self establishConnection];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testSuccessfullyLoggingIn {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_client loginWithMethodName:@"login" parameters:nil completionHandler:^(NSError *error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  
  XCTAssertTrue(_client.loggingIn);
  
  NSString *lastMethodID = [self lastMethodID];
  [_connection receiveMessage:@{@"msg": @"updated", @"methods": @[lastMethodID]}];
  [_connection receiveMessage:@{@"msg": @"result", @"id": lastMethodID, @"result": @{@"id": @"lovelace", @"token": @"foo", @"tokenExpires": @"2015-01-01 00:00:00 +0000"}}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertFalse(_client.loggingIn);
  XCTAssertEqualObjects(@"lovelace", _client.account.userID);
}

- (void)testUnsuccessfullyLoggingIn {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_client loginWithMethodName:@"login" parameters:nil completionHandler:^(NSError *error) {
    XCTAssertEqualObjects(error.domain, METDDPErrorDomain);
    XCTAssertEqual(error.code, METDDPServerError);
    [expectation fulfill];
  }];
  
  XCTAssertTrue(_client.loggingIn);

  NSString *lastMethodID = [self lastMethodID];
  [_connection receiveMessage:@{@"msg": @"result", @"id": lastMethodID, @"error": @{@"error": @"unsuccessfull", @"reason": @"bla"}}];
  [_connection receiveMessage:@{@"msg": @"updated", @"methods": @[lastMethodID]}];

  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertFalse(_client.loggingIn);
  XCTAssertNil(_client.account);
}

- (void)testSettingAccountPostsDidChangeAccountNotification {
  [self expectationForNotification:METDDPClientDidChangeAccountNotification object:_client handler:nil];
  
  _client.account = [[METAccount alloc] initWithUserID:@"lovelace" resumeToken:@"foo" expiryDate:nil];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testSettingAccountToNilPostsDidChangeAccountNotification {
  _client.account = [[METAccount alloc] initWithUserID:@"lovelace" resumeToken:@"foo" expiryDate:nil];
  
  [self expectationForNotification:METDDPClientDidChangeAccountNotification object:_client handler:nil];
  
  _client.account = nil;
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testLoggingInActsAsABarrierMethodInvocation {
  [_client callMethodWithName:@"doSomethingBefore" parameters:nil];
  METMethodInvocation *doSomethingBefore = [self methodInvocationWithName:@"doSomethingBefore"];
  [_client loginWithMethodName:@"login" parameters:nil completionHandler:nil];
  [_client callMethodWithName:@"doSomethingAfter" parameters:nil];
  
  METMethodInvocation *login = [self methodInvocationWithName:@"login"];
  XCTAssertFalse(login.isExecuting);
  
  [self keyValueObservingExpectationForObject:login keyPath:@"isExecuting" expectedValue:[NSNumber numberWithBool:YES]];
  
  [self finishMethodInvocation:doSomethingBefore];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  METMethodInvocation *doSomethingAfter = [self methodInvocationWithName:@"doSomethingAfter"];
  [self keyValueObservingExpectationForObject:doSomethingAfter keyPath:@"isExecuting" expectedValue:[NSNumber numberWithBool:YES]];
  
  [self finishMethodInvocation:login];
   
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testReconnectingWhenLoggedInAddsLoginMethodInvocationToTheFrontOfTheQueue {
  _client.account = [[METAccount alloc] initWithUserID:@"lovelace" resumeToken:@"foo" expiryDate:nil];
  
  [_client callMethodWithName:@"doSomething" parameters:nil];
  
  [_client disconnect];
  
  [self expectationForSentMessageForMethodWithName:@"login"];
  [_client connect];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertFalse([self methodInvocationWithName:@"doSomething"].messageSent);
}

- (void)testSuccesfullyLoggingInWithResumeTokenWhenReconnnectingIfLoggedIn {
  _client.account = [[METAccount alloc] initWithUserID:@"lovelace" resumeToken:@"foo" expiryDate:nil];
  
  [_client disconnect];
  
  [self expectationForSentMessageForMethodWithName:@"login" parameters:@[@{@"resume": @"foo"}]];
  [self establishConnection];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  [self keyValueObservingExpectationForObject:_client keyPath:@"loggingIn" expectedValue:[NSNumber numberWithBool:NO]];
  
  NSString *lastMethodID = [self lastMethodID];
  [_connection receiveMessage:@{@"msg": @"updated", @"methods": @[lastMethodID]}];
  [_connection receiveMessage:@{@"msg": @"result", @"id": lastMethodID, @"result": @{@"id": @"turing", @"token": @"foo", @"tokenExpires": @"2016-01-01 00:00:00 +0000"}}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertEqualObjects(@"turing", _client.account.userID);
}

- (void)testUnsuccesfullyLoggingInWithResumeTokenWhenReconnnectingIfLoggedIn {
  _client.account = [[METAccount alloc] initWithUserID:@"lovelace" resumeToken:@"foo" expiryDate:nil];
  
  [_client disconnect];
  
  [self expectationForSentMessageForMethodWithName:@"login" parameters:@[@{@"resume": @"foo"}]];
  [self establishConnection];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  [self keyValueObservingExpectationForObject:_client keyPath:@"loggingIn" expectedValue:[NSNumber numberWithBool:NO]];
  
  NSString *lastMethodID = [self lastMethodID];
  [_connection receiveMessage:@{@"msg": @"result", @"id": lastMethodID, @"error": @{@"error": @"unsuccessfull", @"reason": @"bla"}}];
  [_connection receiveMessage:@{@"msg": @"updated", @"methods": @[lastMethodID]}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertNil(_client.account);
}

- (void)testDoesntLoginWithResumeTokenWhenReconnnectingIfNotLoggedIn {
  [_client disconnect];
  
  [self establishConnection];
  
  // Message for doSomethingAfter will not be sent if login method is executing
  [self expectationForSentMessageForMethodWithName:@"doSomethingAfter"];
  [_client callMethodWithName:@"doSomethingAfter" parameters:nil];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testLogsInWithResumeTokenWhenReconnnectingWhenResultReceivedButNotUpdatesDone {
  [self expectationForSentMessageForMethodWithName:@"login"];
  [_client loginWithMethodName:@"login" parameters:nil completionHandler:nil];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  [_connection receiveMessage:@{@"msg": @"result", @"id": [self lastMethodID], @"result": @{@"id": @"lovelace", @"token": @"foo", @"tokenExpires": @"2016-01-01 00:00:00 +0000"}}];
  
  [_client disconnect];
  
  [self expectationForSentMessageForMethodWithName:@"login" parameters:@[@{@"resume": @"foo"}]];
  [self establishConnection];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testIsNotLoggedInAutomaticallyWhenResultReceivedButNotUpdatesDone {
  [self expectationForSentMessageForMethodWithName:@"login"];
  [_client loginWithMethodName:@"login" parameters:nil completionHandler:nil];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  [_connection receiveMessage:@{@"msg": @"result", @"id": [self lastMethodID], @"result": @{@"id": @"lovelace", @"token": @"foo", @"tokenExpires": @"2015-01-01 00:00:00 +0000"}}];
  
  [_client disconnect];
  
  XCTAssertNil(_client.account);
}

- (void)testInvokesCompletionHandlerWithMostRecentAccountWhenReconnectingWhenResultReceivedButNotUpdatesDone {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_client loginWithMethodName:@"login" parameters:@[] completionHandler:^(NSError *error) {
    XCTAssertEqualObjects(@"turing", _client.account.userID);
    [expectation fulfill];
  }];
  
  [_connection receiveMessage:@{@"msg": @"result", @"id": [self lastMethodID], @"result": @{@"id": @"lovelace", @"token": @"foo", @"tokenExpires": @"2016-01-01 00:00:00 +0000"}}];
  
  [_client disconnect];
  
  [self establishConnection];
  
  NSString *lastMethodID = [self lastMethodID];
  [_connection receiveMessage:@{@"msg": @"updated", @"methods": @[lastMethodID]}];
  [_connection receiveMessage:@{@"msg": @"result", @"id": lastMethodID, @"result": @{@"id": @"turing", @"token": @"foo", @"tokenExpires": @"2016-01-01 00:00:00 +0000"}}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testSuccessfullyLoggingOut {
  _client.account = [[METAccount alloc] initWithUserID:@"lovelace" resumeToken:@"foo" expiryDate:nil];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_client logoutWithCompletionHandler:^(NSError *error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  
  NSString *lastMethodID = [self lastMethodID];
  [_connection receiveMessage:@{@"msg": @"updated", @"methods": @[lastMethodID]}];
  [_connection receiveMessage:@{@"msg": @"result", @"id": lastMethodID}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertNil(_client.account);
}

#pragma mark - Helper Methods

- (void)finishMethodInvocation:(METMethodInvocation *)methodInvocation {
  [methodInvocation didReceiveResult:nil error:nil];
  [methodInvocation didFlushUpdates];
}

@end
