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
#import "METDDPClientTestCase.h"
#import <OCMock/OCMock.h>

#import "METDDPClient.h"
#import "METDDPClient_Internal.h"

#import "MockMETDDPConnection.h"

#import "METMethodInvocation.h"
#import "METMethodInvocationContext.h"

@interface METDDPClientCallingMethods : METDDPClientTestCase

@end

@implementation METDDPClientCallingMethods {
}

- (void)setUp {
  [super setUp];
  
  [self establishConnection];
}

- (void)tearDown {
  [super tearDown];
}

#pragma mark - Calling Methods

- (void)testCallingMethodSendsMethodMessage {
  [self expectationForSentMessageWithHandler:^(NSDictionary *message) {
    XCTAssertEqualObjects(@"method", message[@"msg"]);
    XCTAssertEqualObjects(@"doSomething", message[@"method"]);
    XCTAssertEqualObjects(@[@"someParameter"], message[@"params"]);
    XCTAssertNotNil(message[@"id"]);
    return YES;
  }];
  
  [_client callMethodWithName:@"doSomething" parameters:@[@"someParameter"]];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testCallingMethodInvokesReceivedResultHandlerWithReceivedResult {
  XCTestExpectation *expectation = [self expectationWithDescription:@"received result handler invoked"];
  [_client callMethodWithName:@"doSomething" parameters:@[@"someParameter"] options:0 receivedResultHandler:^(id result, NSError *error) {
    XCTAssertEqualObjects(@"someResult", result);
    XCTAssertNil(error);
    [expectation fulfill];
  } completionHandler:nil];
  
  [_connection receiveMessage:@{@"msg": @"result", @"id": [self lastMethodID], @"result": @"someResult"}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testCallingMethodInvokesCompletionHandlerWithReceivedResult {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_client callMethodWithName:@"doSomething" parameters:@[@"someParameter"] completionHandler:^(id result, NSError *error) {
    XCTAssertEqualObjects(@"someResult", result);
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  
  NSString *lastMethodID = [self lastMethodID];
  [_connection receiveMessage:@{@"msg": @"result", @"id": lastMethodID, @"result": @"someResult"}];
  [_connection receiveMessage:@{@"msg": @"updated", @"methods": @[lastMethodID]}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testCallingMethodInvokesCompletionHandlerWithReceivedError {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_client callMethodWithName:@"doSomething" parameters:@[@"someParameter"] completionHandler:^(id result, NSError *error) {
    XCTAssertNil(result);
    NSError *expectedError = [NSError errorWithDomain:METDDPErrorDomain code:METDDPServerError userInfo:@{NSLocalizedDescriptionKey: @"Received error response from server", NSLocalizedFailureReasonErrorKey:@"bla"}];
    XCTAssertEqualObjects(expectedError, error);
    [expectation fulfill];
  }];
  
  NSString *lastMethodID = [self lastMethodID];
  [_connection receiveMessage:@{@"msg": @"result", @"id": lastMethodID, @"error": @{@"error": @403, @"reason": @"bla", @"details": @"morebla"}}];
  [_connection receiveMessage:@{@"msg": @"updated", @"methods": @[lastMethodID]}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testCallingMethodInvokesStubIfDefined {
  XCTestExpectation *expectation = [self expectationWithDescription:@"stub invoked"];
  [_client defineStubForMethodWithName:@"doSomething" usingBlock:^id(NSArray *parameters) {
    [expectation fulfill];
    return nil;
  }];
  
  [_client callMethodWithName:@"doSomething" parameters:@[@"someParameter"]];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testCallingMethodDoesntLetStubChangeParametersThatAreSentToServer {
  XCTestExpectation *expectation = [self expectationWithDescription:@"stub invoked"];
  [_client defineStubForMethodWithName:@"doSomething" usingBlock:^id(NSArray *parameters) {
    parameters[0][@"someParameter"] = @"someOtherValue";
    [expectation fulfill];
    return nil;
  }];
  
  [self expectationForSentMessageWithHandler:^(NSDictionary *message) {
    XCTAssertEqualObjects(@"method", message[@"msg"]);
    XCTAssertEqualObjects(@"doSomething", message[@"method"]);
    XCTAssertEqualObjects(@[@{@"someParameter": @"someValue"}], message[@"params"]);
    XCTAssertNotNil(message[@"id"]);
    return YES;
  }];
  
  [_client callMethodWithName:@"doSomething" parameters:@[[@{@"someParameter": @"someValue"} mutableCopy]]];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testCallingMethodDoesntReturnStubResult {
  [_client defineStubForMethodWithName:@"doSomething" usingBlock:^id(NSArray *parameters) {
    return @"someResult";
  }];
  
  id stubResult = [_client callMethodWithName:@"doSomething" parameters:@[@"someParameter"]];
  
  XCTAssertNil(stubResult);
}

- (void)testCallingMethodReturnsStubResultWhenIncludingResturnStubValueOption {
  [_client defineStubForMethodWithName:@"doSomething" usingBlock:^id(NSArray *parameters) {
    return @"someResult";
  }];
  
  id stubResult = [_client callMethodWithName:@"doSomething" parameters:@[@"someParameter"] options:METMethodCallOptionsReturnStubValue completionHandler:nil];
  
  XCTAssertEqualObjects(@"someResult", stubResult);
}

- (void)testCallingMethodFromWithinStubInvokesAnotherStub {
  [_client defineStubForMethodWithName:@"doSomething" usingBlock:^id(NSArray *parameters) {
    [_client callMethodWithName:@"doSomethingElse" parameters:@[@"someOtherParameter"]];
    return nil;
  }];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"stub invoked"];
  [_client defineStubForMethodWithName:@"doSomethingElse" usingBlock:^id(NSArray *parameters) {
    [expectation fulfill];
    return nil;
  }];
  
  [_client callMethodWithName:@"doSomething" parameters:@[@"someParameter"]];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testCallingMethodFromWithinStubReturnsMethodResult {
  [_client defineStubForMethodWithName:@"doSomething" usingBlock:^id(NSArray *parameters) {
    id result = [_client callMethodWithName:@"doSomethingElse" parameters:@[@"someOtherParameter"]];
    XCTAssertEqualObjects(@"someResult", result);
    return nil;
  }];
  
  [_client defineStubForMethodWithName:@"doSomethingElse" usingBlock:^id(NSArray *parameters) {
    return @"someResult";
  }];
  
  [_client callMethodWithName:@"doSomething" parameters:nil];
}

- (void)testCallingMethodFromWithinStubSendsNoMethodMessage {
  [_client defineStubForMethodWithName:@"doSomething" usingBlock:^id(NSArray *parameters) {
    [_client callMethodWithName:@"doSomethingElse" parameters:nil];
    return nil;
  }];
  
  [self whileNotExpectingSentMessageWithHandler:^BOOL(NSDictionary *message) {
    return [message[@"msg"] isEqualToString:@"method"] && [message[@"method"] isEqualToString:@"doSomethingElse"];
  } performBlock:^{
    [_client callMethodWithName:@"doSomething" parameters:nil];
    [self waitForTimeInterval:0.1];
  }];
}

- (void)testCallingMethodSendsMethodMessageWithRandomSeedIfUsedInStub {
  [_client defineStubForMethodWithName:@"doSomething" usingBlock:^id(NSArray *parameters) {
    _client.currentMethodInvocationContext.randomSeed = @"someSeed";
    return nil;
  }];
  
  [self expectationForSentMessageWithHandler:^(NSDictionary *message) {
    XCTAssertEqualObjects(@"someSeed", message[@"randomSeed"]);
    return YES;
  }];
  
  [_client callMethodWithName:@"doSomething" parameters:nil];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testCallingMethodSendsMethodMessageWithoutRandomSeedIfNotUsedInStub {
  [_client defineStubForMethodWithName:@"doSomething" usingBlock:^id(NSArray *parameters) {
    return nil;
  }];
  
  [self expectationForSentMessageWithHandler:^(NSDictionary *message) {
    XCTAssertNil(message[@"randomSeed"]);
    return YES;
  }];
  
  [_client callMethodWithName:@"doSomething" parameters:nil];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
