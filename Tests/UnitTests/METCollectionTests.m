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
#import "XCTAsyncTestCase.h"
#import "XCTestCase+Meteor.h"
#import <OCMock/OCMock.h>

#import "METDDPClient.h"
#import "METDDPClient_Internal.h"
#import "METDatabase.h"
#import "METDatabase_Internal.h"
#import "METCollection.h"
#import "METCollection_Internal.h"
#import "METDocument.h"
#import "METDocumentKey.h"
#import "METDocumentChangeDetails.h"
#import "METDataUpdate.h"
#import "METDocumentCache.h"
#import "METMethodInvocationCoordinator.h"
#import "METMethodInvocationCoordinator_Testing.h"
#import "METMethodInvocation.h"

@interface METCollectionTests : XCTAsyncTestCase

@end

@implementation METCollectionTests {
  id _client;
  METDatabase *_database;
  METCollection *_collection;
}

- (void)setUp {
  [super setUp];
  
  _client = OCMPartialMock([[METDDPClient alloc] initWithConnection:nil]);
  _database = [_client database];
  _collection = [_database collectionWithName:@"players"];
}

- (void)tearDown {
  [super tearDown];
}

#pragma mark - Inserting Documents

- (void)testInsertingDocumentCallsInsertDDPMethod {
  OCMExpect(([_client callMethodWithName:@"/players/insert" parameters:@[@{@"_id": @"lovelace", @"name": @"Ada Lovelace", @"score": @25}] options:METMethodCallOptionsReturnStubValue completionHandler:[OCMArg any]]));
  
  [_collection insertDocumentWithID:@"lovelace" fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  
  OCMVerifyAll(_client);
}

- (void)testInsertingDocumentAddsItToLocalCache {
  [_collection insertDocumentWithID:@"lovelace" fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  
  [self verifyDatabase:_database containsDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
}

- (void)testInsertingDocumentReturnsSpecifiedID {
  id documentID = [_collection insertDocumentWithID:@"lovelace" fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  XCTAssertEqualObjects(documentID, @"lovelace");
}

- (void)testInsertingDocumentWithoutIDReturnsNewlyGeneratedID {
  id documentID = [_collection insertDocumentWithFields:@{@"name": @"Ada Lovelace", @"score": @25}];
  XCTAssertNotNil(documentID);
}

- (void)testInsertingDocumentWithExistingIDIsntAddedToLocalCacheAndReturnsNil {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  }];
  
  id documentID = [_collection insertDocumentWithID:@"lovelace" fields:  @{@"name": @"Ada Lovelace", @"score": @5}];
  
  [self verifyDatabase:_database containsDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  XCTAssertNil(documentID);
}

- (void)testInsertingDocumentWithCompletionHandlerReturnsIDWhenSuccesful {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_collection insertDocumentWithID:@"lovelace" fields:@{@"name": @"Ada Lovelace", @"score": @25} completionHandler:^(id result, NSError *error) {
    XCTAssertEqualObjects(result, @"bla");
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  
  [self invokeMethodInvocationCompletionHandlerWithResult:@[@{@"_id": @"bla"}] error:nil];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testInsertingDocumentWithCompletionHandlerReturnsErrorWhenFailed {
  NSError *expectedError = [NSError errorWithDomain:@"" code:1 userInfo:@{}];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_collection insertDocumentWithID:@"lovelace" fields:@{@"name": @"Ada Lovelace", @"score": @25} completionHandler:^(id result, NSError *error) {
    XCTAssertNil(result);
    XCTAssertEqualObjects(error, expectedError);
    [expectation fulfill];
  }];
  
  [self invokeMethodInvocationCompletionHandlerWithResult:nil error:expectedError];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testInsertingDocumentPostsNotificationAfterModifyingLocalCache {
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeAdd changedFields:@{@"name": @"Ada Lovelace", @"score": @25}];
  
  [_collection insertDocumentWithID:@"lovelace" fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testInsertingDocumentDoesNotPostAdditionalNotificationsAfterReceivingUpdatesDoneWithTheServerAddingTheSameDocument {
  [self expectationForNotification:METDatabaseDidChangeNotification object:_database handler:nil];
  [_collection insertDocumentWithID:@"lovelace" fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  [self performBlockWhileNotExpectingDatabaseDidChangeNotification:^{
    METDataUpdate *update = [[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeAdd documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
    [_client processDataUpdate:update];
    
    [self notifyDidReceiveUpdatesDoneForLastMethodInvocation];
    
    [self waitForTimeInterval:0.1];
  }];
}

- (void)testInsertingDocumentPostsRemoveNotificationAfterReceivingUpdatesDoneWithoutTheServerAddingTheDocument {
  [self expectationForNotification:METDatabaseDidChangeNotification object:_database handler:nil];
  [_collection insertDocumentWithID:@"lovelace" fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertEqual(1, [_collection allDocuments].count);
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeRemove changedFields:nil];
  
  [self notifyDidReceiveUpdatesDoneForLastMethodInvocation];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertEqual(0, [_collection allDocuments].count);
}

- (void)testInsertingDocumentPostsChangeNotificationAfterReceivingUpdatesDoneWithTheServerAddingAChangedDocument {
  [_collection insertDocumentWithID:@"lovelace" fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeUpdate changedFields:@{@"score": @30, @"color": [NSNull null]}];
  
  METDataUpdate *update = [[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeAdd documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @30}];
  [_client processDataUpdate:update];

  [self notifyDidReceiveUpdatesDoneForLastMethodInvocation];

  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#pragma mark - Updating Documents

- (void)testUpdatingDocumentCallsUpdateDDPMethod {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  }];
  
  OCMExpect(([_client callMethodWithName:@"/players/update" parameters:@[@{@"_id": @"lovelace"}, @{@"$set": @{@"score": @30}, @"$unset": @{@"color": @""}}] options:METMethodCallOptionsReturnStubValue completionHandler:[OCMArg any]]));
  
  [_collection updateDocumentWithID:@"lovelace" changedFields:@{@"score": @30, @"color": [NSNull null]}];
  
  OCMVerifyAll(_client);
}

- (void)testUpdatingDocumentUpdatesItInLocalCache {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  }];
  
  [_collection updateDocumentWithID:@"lovelace" changedFields:@{@"score": @30, @"color": [NSNull null]}];
  
  [self verifyDatabase:_database containsDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @30}];
}

- (void)testUpdatingDocumentWithIDReturnsOneForNumberOfAffectedDocuments {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  }];
  
  id numberOfAffectedDocuments = [_collection updateDocumentWithID:@"lovelace" changedFields:@{@"score": @30, @"color": [NSNull null]}];
  XCTAssertEqualObjects(numberOfAffectedDocuments, @1);
}

- (void)testUpdatingDocumentWithUnknownIDReturnsZeroForNumberOfAffectedDocuments {
  id numberOfAffectedDocuments = [_collection updateDocumentWithID:@"lovelace" changedFields:@{@"score": @30, @"color": [NSNull null]}];
  XCTAssertEqualObjects(numberOfAffectedDocuments, @0);
}

- (void)testUpdatingDocumentWithCompletionHandlerReturnsNumberOfAffectedDocumentsWhenSuccesful {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  }];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_collection updateDocumentWithID:@"lovelace" changedFields:@{@"score": @30, @"color": [NSNull null]} completionHandler:^(id result, NSError *error) {
    XCTAssertEqualObjects(result, @1);
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  
  [self invokeMethodInvocationCompletionHandlerWithResult:@1 error:nil];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testUpdatingDocumentWithCompletionHandlerReturnsErrorWhenFailed {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  }];
  
  NSError *expectedError = [NSError errorWithDomain:@"" code:1 userInfo:@{}];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_collection updateDocumentWithID:@"lovelace" changedFields:@{@"score": @30, @"color": [NSNull null]} completionHandler:^(id result, NSError *error) {
    XCTAssertNil(result);
    XCTAssertEqualObjects(error, expectedError);
    [expectation fulfill];
  }];
  
  [self invokeMethodInvocationCompletionHandlerWithResult:nil error:expectedError];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testUpdatingDocumentPostsNotificationAfterModifyingLocalCache {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  }];
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeUpdate changedFields:@{@"score": @30, @"color": [NSNull null]}];
  
  [_collection updateDocumentWithID:@"lovelace" changedFields:@{@"score": @30, @"color": [NSNull null]}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testUpdatingDocumentDoesNotPostAdditionalNotificationsAfterReceivingUpdatesDoneWithTheServerSendingTheSameUpdate {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  }];
  
  [self expectationForNotification:METDatabaseDidChangeNotification object:_database handler:nil];
  [_collection updateDocumentWithID:@"lovelace" changedFields:@{@"score": @30, @"color": [NSNull null]}];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  [self performBlockWhileNotExpectingDatabaseDidChangeNotification:^{
    METDataUpdate *update = [[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeChange documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"score": @30, @"color": [NSNull null]}];
    [_client processDataUpdate:update];
    
    [self notifyDidReceiveUpdatesDoneForLastMethodInvocation];
    
    [self waitForTimeInterval:0.1];
  }];
}

- (void)testUpdatingDocumentPostsChangeNotificationAfterReceivingUpdatesDoneWithTheServerSendingADifferentUpdate {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  }];
  
  [self expectationForNotification:METDatabaseDidChangeNotification object:_database handler:nil];
  [_collection updateDocumentWithID:@"lovelace" changedFields:@{@"score": @30, @"color": [NSNull null]}];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeUpdate changedFields:@{@"score": @35, @"color": @"blue"}];
  
  METDataUpdate *update = [[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeChange documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"score": @35}];
  [_client processDataUpdate:update];
  
  [self notifyDidReceiveUpdatesDoneForLastMethodInvocation];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#pragma mark - Removing Documents

- (void)testRemovingDocumentCallsRemoveDDPMethod {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  }];
  
  OCMExpect([_client callMethodWithName:@"/players/remove" parameters:@[@{@"_id": @"lovelace"}] options:METMethodCallOptionsReturnStubValue completionHandler:[OCMArg any]]);
  
  [_collection removeDocumentWithID:@"lovelace"];
  
  OCMVerifyAll(_client);
}

- (void)testRemovingDocumentRemovesItFromLocalCache {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  }];
  
  [_collection removeDocumentWithID:@"lovelace"];
  
  XCTAssertNil([_collection documentWithID:@"lovelace"]);
}

- (void)testRemovingDocumentWithIDReturnsOneForNumberOfAffectedDocuments {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  }];
  
  id numberOfAffectedDocuments = [_collection removeDocumentWithID:@"lovelace"];
  
  XCTAssertEqualObjects(numberOfAffectedDocuments, @1);
}

- (void)testRemovingDocumentWithUnknownIDReturnsZeroForNumberOfAffectedDocuments {
  id numberOfAffectedDocuments = [_collection removeDocumentWithID:@"lovelace"];
  
  XCTAssertEqualObjects(numberOfAffectedDocuments, @0);
}

- (void)testRemovingDocumentWithCompletionHandlerReturnsNumberOfAffectedDocumentsWhenSuccesful {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_collection removeDocumentWithID:@"lovelace" completionHandler:^(id result, NSError *error) {
    XCTAssertEqualObjects(result, @1);
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  
  [self invokeMethodInvocationCompletionHandlerWithResult:@1 error:nil];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testRemovingDocumentWithCompletionHandlerReturnsErrorWhenFailed {
  NSError *expectedError = [NSError errorWithDomain:@"" code:1 userInfo:@{}];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_collection removeDocumentWithID:@"lovelace" completionHandler:^(id result, NSError *error) {
    XCTAssertNil(result);
    XCTAssertEqualObjects(error, expectedError);
    [expectation fulfill];
  }];
  
  [self invokeMethodInvocationCompletionHandlerWithResult:nil error:expectedError];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testRemovingDocumentPostsNotificationAfterModifyingLocalCache {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  }];
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeRemove changedFields:nil];
  
  [_collection removeDocumentWithID:@"lovelace"];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testRemovingDocumentDoesNotPostAdditionalNotificationsAfterReceivingUpdatesDoneWithTheServerRemovingTheSameDocument {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  }];
  
  [self expectationForNotification:METDatabaseDidChangeNotification object:_database handler:nil];
  [_collection removeDocumentWithID:@"lovelace"];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  [self performBlockWhileNotExpectingDatabaseDidChangeNotification:^{
    METDataUpdate *update = [[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeRemove documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:nil];
    [_client processDataUpdate:update];
    
    [self notifyDidReceiveUpdatesDoneForLastMethodInvocation];
    
    [self waitForTimeInterval:0.1];
  }];  
}

- (void)testRemovingDocumentPostsAddNotificationAfterReceivingUpdatesDoneWithoutTheServerRemovingTheDocument {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  }];
  
  [self expectationForNotification:METDatabaseDidChangeNotification object:_database handler:nil];
  [_collection removeDocumentWithID:@"lovelace"];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertEqual(0, [_collection allDocuments].count);
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeAdd changedFields:@{@"name": @"Ada Lovelace", @"score": @25}];
  
  [self notifyDidReceiveUpdatesDoneForLastMethodInvocation];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertEqual(1, [_collection allDocuments].count);
}

- (void)testRemovingDocumentPostsAddNotificationAfterReceivingUpdatesDoneWithTheServerUpdatingTheDocument {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  }];
  
  [self expectationForNotification:METDatabaseDidChangeNotification object:_database handler:nil];
  [_collection removeDocumentWithID:@"lovelace"];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertEqual(0, [_collection allDocuments].count);
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeAdd changedFields:@{@"name": @"Ada Lovelace", @"score": @30}];
  
  METDataUpdate *update = [[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeChange documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"score": @30}];
  [_client processDataUpdate:update];
  
  [self notifyDidReceiveUpdatesDoneForLastMethodInvocation];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertEqual(1, [_collection allDocuments].count);
}

#pragma mark - Helper Methods

- (void)invokeMethodInvocationCompletionHandlerWithResult:(id)result error:(NSError *)error {
  METMethodInvocation *methodInvocation = [[_client methodInvocationCoordinator] lastMethodInvocation];
  methodInvocation.completionHandler(result, error);
}

- (void)notifyDidReceiveUpdatesDoneForLastMethodInvocation {
  METMethodInvocationCoordinator *methodInvocationCoordinator = [_client methodInvocationCoordinator];
  [methodInvocationCoordinator didReceiveUpdatesDoneForMethodID:[methodInvocationCoordinator lastMethodInvocation].methodID];
}

@end
