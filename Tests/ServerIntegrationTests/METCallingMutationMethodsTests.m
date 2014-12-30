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
#import "METServerIntegrationTestCase.h"

#import "METDDPClient.h"
#import "METDatabase.h"
#import "METCollection.h"

@interface METCallingMutationMethodsTests : METServerIntegrationTestCase

@end

@implementation METCallingMutationMethodsTests {
  METCollection *_collection;
}

- (void)setUp {
  [super setUp];
  
  _collection = [_client.database collectionWithName:@"players"];
  [_client addSubscriptionWithName:@"allPlayers"];
}

- (void)testInsertingDocumentWithClientSpecifiedID {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_collection insertDocumentWithID:@"lovelace" fields:@{@"name": @"Ada Lovelace", @"score": @25} completionHandler:^(id result, NSError *error) {
    XCTAssertEqualObjects(result, @"lovelace");
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testInsertingDocumentWithoutClientSpecifiedID {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_collection insertDocumentWithFields:@{@"name": @"Ada Lovelace", @"score": @25} completionHandler:^(id result, NSError *error) {
    XCTAssert([result isKindOfClass:[NSString class]]);
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testInsertingDocumentForUnknownCollectionResultsInError {
  METCollection *collection = [_client.database collectionWithName:@"students"];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [collection insertDocumentWithID:@"lovelace" fields:@{@"name": @"Ada Lovelace", @"score": @25} completionHandler:^(id result, NSError *error) {
    XCTAssertNil(result);
    XCTAssertEqualObjects(error.domain, METDDPErrorDomain);
    XCTAssertEqual(error.code, METDDPServerError);
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testUpdatingDocumentWithIDReturnsOneForNumberOfAffectedDocuments {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_collection insertDocumentWithID:@"lovelace" fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"} completionHandler:^(id result, NSError *error) {
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_collection updateDocumentWithID:@"lovelace" fields:@{@"score": @30, @"color": [NSNull null]} completionHandler:^(id result, NSError *error) {
    XCTAssertEqualObjects(result, @1);
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testUpdatingDocumentWithUnknownIDReturnsZeroForNumberOfAffectedDocuments {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_collection updateDocumentWithID:@"lovelace" fields:@{@"score": @30, @"color": [NSNull null]} completionHandler:^(id result, NSError *error) {
    XCTAssertEqualObjects(result, @0);
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testRemovingDocumentWithIDReturnsOneForNumberOfAffectedDocuments {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_collection insertDocumentWithID:@"lovelace" fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"} completionHandler:^(id result, NSError *error) {
    [expectation fulfill];
  }];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_collection removeDocumentWithID:@"lovelace" completionHandler:^(id result, NSError *error) {
    XCTAssertEqualObjects(result, @1);
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testRemovingDocumentWithUnknownIDReturnsZeroForNumberOfAffectedDocuments {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_collection removeDocumentWithID:@"lovelace" completionHandler:^(id result, NSError *error) {
    XCTAssertEqualObjects(result, @0);
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
