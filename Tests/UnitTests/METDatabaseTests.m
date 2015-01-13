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
#import "XCTestCase+Meteor.h"
#import <OCMock/OCMock.h>

#import "METDatabase.h"
#import "METDatabase_Internal.h"
#import "METDocumentKey.h"
#import "METDocumentCache.h"
#import "METDataUpdate.h"
#import "METMethodInvocationCoordinator.h"
#import "METMethodInvocationCoordinator_Testing.h"
#import "METMethodInvocation.h"

@interface METDatabaseTests : XCTAsyncTestCase

@end

@implementation METDatabaseTests {
  METDatabase *_database;
}

- (void)setUp {
  [super setUp];
  
  _database = [[METDatabase alloc] initWithClient:nil];
}

- (void)tearDown {
  [super tearDown];
}

#pragma mark - Applying Data Updates

- (void)testApplyingAddUpdate {
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeAdd changedFields:@{@"name": @"Ada Lovelace", @"score": @25}];
  
  METDataUpdate *update = [[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeAdd documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  [_database applyDataUpdate:update];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  [self verifyDatabase:_database containsDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
}

- (void)testApplyingChangeUpdate {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  }];
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeUpdate changedFields:@{@"score": @30, @"color": [NSNull null]}];
  
  METDataUpdate *update = [[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeChange documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"score": @30, @"color": [NSNull null]}];
  [_database applyDataUpdate:update];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  [self verifyDatabase:_database containsDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @30}];
}

- (void)testApplyingRemoveUpdate {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  }];
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeRemove changedFields:nil];
  
  METDataUpdate *update = [[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeRemove documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:nil];
  [_database applyDataUpdate:update];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertNil([_database documentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]]);
}

- (void)testDataUpdatesAreNotFlushedWhenWaitingForQuiescence {
  _database.waitingForQuiescence = YES;
  
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  }];
  
  METDataUpdate *update = [[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeChange documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"score": @30}];
  [_database applyDataUpdate:update];
  
  [self waitWhileAssertionsPass:^{
    [self verifyDatabase:_database containsDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  }];
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeUpdate changedFields:@{@"score": @30}];
  
  _database.waitingForQuiescence = NO;
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testResettingRemovesBufferedDataUpdatesAndPendingAfterFlushDataUpdatesBlocks {
}

#pragma mark - Change Notifications

- (void)testPerformingSeparateUpdatesPostsSeparateNotifications {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  }];
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeUpdate changedFields:@{@"score": @30}];
  
  [_database performUpdatesInLocalCache:^(METDocumentCache *localCache) {
    [localCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changedFields:@{@"score": @30}];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeUpdate changedFields:@{@"color": @"blue"}];
  
  [_database performUpdatesInLocalCache:^(METDocumentCache *localCache) {
    [localCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changedFields:@{@"color": @"blue"}];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testPerformingBatchUpdatesOnADocumentPostsSingleNotification {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  }];
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeUpdate changedFields:@{@"score": @30, @"color": @"blue"}];
  
  [_database performUpdatesInLocalCache:^(METDocumentCache *localCache) {
    [localCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changedFields:@{@"score": @30}];
    [localCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changedFields:@{@"color": @"blue"}];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testPerformingBatchUpdatesOnDifferentDocumentsPostsSingleNotification {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"gauss"] fields:@{@"name": @"Carl Friedrich Gauss", @"score": @5}];
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"shannon"] fields:@{@"name": @"Claude Shannon", @"score": @10}];
  }];
  
  [self expectationForDatabaseDidChangeNotificationWithHandler:^BOOL(METDatabaseChanges *databaseChanges) {
    [self verifyDatabaseChanges:databaseChanges containsChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeAdd changedFields:@{@"name": @"Ada Lovelace", @"score": @25}];
    [self verifyDatabaseChanges:databaseChanges containsChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"gauss"] changeType:METDocumentChangeTypeUpdate changedFields:@{@"score": @10}];
    [self verifyDatabaseChanges:databaseChanges containsChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"shannon"] changeType:METDocumentChangeTypeRemove changedFields:nil];
    return YES;
  }];
  
  [_database performUpdatesInLocalCache:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
    [localCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"gauss"] changedFields:@{@"score": @10}];
    [localCache removeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"shannon"]];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
