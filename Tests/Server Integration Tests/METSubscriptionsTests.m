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

#import "METDatabase.h"
#import "METCollection.h"

@interface METSubscriptionsTests : METServerIntegrationTestCase

@end

@implementation METSubscriptionsTests

- (void)testSubscribingWithUnknownNameResultsInError {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_client addSubscriptionWithName:@"someSubscription" parameters:nil completionHandler:^(NSError *error) {
    NSError *expectedError = [NSError errorWithDomain:METDDPErrorDomain code:METDDPServerError userInfo:@{NSLocalizedDescriptionKey: @"Received error response from server", NSLocalizedFailureReasonErrorKey:@"Subscription 'someSubscription' not found"}];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    XCTAssertEqualObjects(expectedError, error);
#pragma clang diagnostic pop
    [expectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testSubscribingAddsRecordsThatWereNotVisibleBefore {
  METCollection *collection = [_client.database collectionWithName:@"players"];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_client callMethodWithName:@"addExamplePlayers" parameters:nil completionHandler:^(id result, NSError *error) {
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertEqual(0, [collection allDocuments].count);
  
  expectation = [self expectationWithDescription:@"completion handler invoked"];
  METSubscription *subscription = [_client addSubscriptionWithName:@"allPlayers" parameters:nil completionHandler:^(NSError *error) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    XCTAssertNil(error);
#pragma clang diagnostic pop
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertTrue(subscription.ready);
  XCTAssertEqual(6, [collection allDocuments].count);
}

- (void)testSubscribingAddsLocallyInsertedRecordThatWasntVisibleBefore {
  METCollection *collection = [_client.database collectionWithName:@"players"];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [collection insertDocumentWithFields:@{@"name": @"Ada Lovelace", @"score": @25} completionHandler:^(id result, NSError *error) {
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertEqual(0, [collection allDocuments].count);
  
  expectation = [self expectationWithDescription:@"completion handler invoked"];
  METSubscription *subscription = [_client addSubscriptionWithName:@"allPlayers" parameters:nil completionHandler:^(NSError *error) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
    XCTAssertNil(error);
#pragma clang diagnostic pop
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertTrue(subscription.ready);
  XCTAssertEqual(1, [collection allDocuments].count);
}

@end
