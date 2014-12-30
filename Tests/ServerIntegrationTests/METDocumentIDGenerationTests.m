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

@interface METDocumentIDGenerationTests : METServerIntegrationTestCase

@end

@implementation METDocumentIDGenerationTests

- (void)testInsertingDocumentWithClientSpecifiedID {
  METCollection *collection = [_client.database collectionWithName:@"players"];

  __block id newServerGeneratedDocumentID;
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  id newLocallyGeneratedDocumentID = [collection insertDocumentWithID:@"lovelace" fields:@{@"name": @"Ada Lovelace", @"score": @25} completionHandler:^(id result, NSError *error) {
    XCTAssertNotNil(result);
    newServerGeneratedDocumentID = result;
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  
  XCTAssertEqualObjects(newLocallyGeneratedDocumentID, @"lovelace");
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertEqualObjects(newLocallyGeneratedDocumentID, newServerGeneratedDocumentID);
}

- (void)testInsertingDocumentWithGeneratedID {
  METCollection *collection = [_client.database collectionWithName:@"players"];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  __block id newServerGeneratedDocumentID;
  id newLocallyGeneratedDocumentID = [collection insertDocumentWithID:@"lovelace" fields:@{@"name": @"Ada Lovelace", @"score": @25} completionHandler:^(id result, NSError *error) {
    XCTAssertNotNil(result);
    newServerGeneratedDocumentID = result;
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertEqualObjects(newLocallyGeneratedDocumentID, newServerGeneratedDocumentID);
}

- (void)testCallingMethodToInsertDocumentWithGeneratedID {
  METCollection *collection = [_client.database collectionWithName:@"players"];
  
  [_client defineStubForMethodWithName:@"anotherMethod" usingBlock:^id(NSArray *parameters) {
    return [collection insertDocumentWithFields:parameters[0]];
  }];
  
  __block id newLocallyGeneratedDocumentID;
  [_client defineStubForMethodWithName:@"addPlayer" usingBlock:^id(NSArray *parameters) {
    newLocallyGeneratedDocumentID = [_client callMethodWithName:@"anotherMethod" parameters:parameters];
    return nil;
  }];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  __block id newServerGeneratedDocumentID;
  [_client callMethodWithName:@"addPlayer" parameters:@[@{@"name": @"Ada Lovelace", @"score": @25}] completionHandler:^(id result, NSError *error) {
    XCTAssertNotNil(result);
    newServerGeneratedDocumentID = result;
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertEqualObjects(newLocallyGeneratedDocumentID, newServerGeneratedDocumentID);
}

@end
