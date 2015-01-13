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
#import "METServerIntegrationTestCase.h"

#import "METDDPClient.h"
#import "METDDPClient+AccountsPassword.h"
#import "METAccount.h"

@interface METAccountsTests : METServerIntegrationTestCase

@end

@implementation METAccountsTests

- (void)testLoggingInWithEmailAndIncorrectPassword {
  XCTestExpectation *expectation = [self expectationWithDescription:@"login method returned"];
  
  [_client loginWithEmail:@"martijn@martijnwalraven.com" password:@"incorrect" completionHandler:^(NSError *error) {
    XCTAssertEqualObjects(error.domain, METDDPErrorDomain);
    XCTAssertEqual(error.code, METDDPServerError);
    [expectation fulfill];
  }];
  
  XCTAssertTrue(_client.loggingIn);

  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertFalse(_client.loggingIn);
  XCTAssertNil(_client.account);
}

- (void)testLoggingInWithEmailAndCorrectPassword {
  XCTestExpectation *expectation = [self expectationWithDescription:@"login method returned"];
  
  [_client loginWithEmail:@"martijn@martijnwalraven.com" password:@"correct" completionHandler:^(NSError *error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  
  XCTAssertTrue(_client.loggingIn);
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertFalse(_client.loggingIn);
  XCTAssertNotNil(_client.account);
}

- (void)testLoggingInAfterReconnect {
  XCTestExpectation *expectation = [self expectationWithDescription:@"login method returned"];
  
  [_client loginWithEmail:@"martijn@martijnwalraven.com" password:@"correct" completionHandler:^(NSError *error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  [_client disconnect];
  [_client connect];
  
  XCTAssertFalse(_client.loggingIn);
  XCTAssertNotNil(_client.account);
}

@end
