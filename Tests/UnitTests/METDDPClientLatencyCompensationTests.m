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

#import "METDDPClient.h"
#import "METDDPClient_Internal.h"

#import "MockMETDDPConnection.h"

#import "METDatabase.h"
#import "METDatabase_Internal.h"
#import "METCollection.h"
#import "METCollection_Internal.h"
#import "METDocument.h"
#import "METDocumentKey.h"
#import "METDocumentCache.h"
#import "METMethodInvocationCoordinator.h"
#import "METMethodInvocationCoordinator_Testing.h"
#import "METMethodInvocation.h"

@interface METDDPClientLatencyCompensationTests : METDDPClientTestCase

@end

@implementation METDDPClientLatencyCompensationTests {
  METDatabase *_database;
}

- (void)setUp {
  [super setUp];
  
  _database = _client.database;
  
  [self establishConnection];
}

- (void)tearDown {
  [super tearDown];
}

#pragma mark - Receiving Updated Message

- (void)testReceivingUpdatedMessageSetsUpdatesDoneOnMethodInvocation {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  }];
  
  [_client defineStubForMethodWithName:@"doSomething" usingBlock:^id(NSArray *parameters) {
    [[_database collectionWithName:@"players"] updateDocumentWithID:@"lovelace" changedFields:@{@"score": @20}];
    return nil;
  }];
  
  [_client callMethodWithName:@"doSomething" parameters:nil];
  METMethodInvocation *methodInvocation1 = [self lastMethodInvocation];
  
  [self keyValueObservingExpectationForObject:methodInvocation1 keyPath:@"updatesDone" expectedValue:[NSNumber numberWithBool:YES]];
  
  [_connection receiveMessage:@{@"msg": @"updated", @"methods": @[methodInvocation1.methodID]}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testReceivingUpdatedMessageRollsBackUpdatesPerformedByStub {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  }];
  
  [_client defineStubForMethodWithName:@"doSomething" usingBlock:^id(NSArray *parameters) {
    [[_database collectionWithName:@"players"] updateDocumentWithID:@"lovelace" changedFields:@{@"score": @20}];
    return nil;
  }];
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeUpdate changedFields:@{@"score": @20}];
  
  [_client callMethodWithName:@"doSomething" parameters:nil];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeUpdate changedFields:@{@"score": @25}];
  
  [_connection receiveMessage:@{@"msg": @"updated", @"methods": @[[self lastMethodID]]}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testReceivingUpdatedMessageAppliesBufferedDocumentsToLocalCacheWhenAllMethodsAffectingTheSameDocumentAreDone {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  }];
  
  [_client defineStubForMethodWithName:@"doSomething" usingBlock:^id(NSArray *parameters) {
    [[_database collectionWithName:@"players"] updateDocumentWithID:@"lovelace" changedFields:@{@"score": @20}];
    return nil;
  }];
  
  [_client defineStubForMethodWithName:@"doSomethingElse" usingBlock:^id(NSArray *parameters) {
    [[_database collectionWithName:@"players"] updateDocumentWithID:@"lovelace" changedFields:@{@"color": @"green"}];
    return nil;
  }];
  
  [self expectationForSentMessageForMethodWithName:@"doSomething"];
  [self expectationForSentMessageForMethodWithName:@"doSomethingElse"];
  
  [_client callMethodWithName:@"doSomething" parameters:nil];
  NSString *methodID1 = [self lastMethodID];
  [_client callMethodWithName:@"doSomethingElse" parameters:nil];
  NSString *methodID2 = [self lastMethodID];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  [_connection receiveMessage:@{@"msg": @"changed", @"collection": @"players", @"id": @"lovelace", @"fields":@{@"score": @30}}];
  [_connection receiveMessage:@{@"msg": @"updated", @"methods": @[methodID1]}];
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeUpdate changedFields:@{@"score": @30, @"color": @"blue"}];
  
  [_connection receiveMessage:@{@"msg": @"changed", @"collection": @"players", @"id": @"lovelace", @"fields":@{@"color": @"blue"}}];
  [_connection receiveMessage:@{@"msg": @"updated", @"methods": @[methodID2]}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testReceivingUpdatedMessageAppliesBufferedDocumentsToLocalCacheEvenWhenMethodsAffectingOtherDocumentsAreNotDone {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"gauss"] fields:@{@"name": @"Carl Friedrich Gauss", @"score": @15}];
  }];
  
  [_client defineStubForMethodWithName:@"doSomething" usingBlock:^id(NSArray *parameters) {
    [[_database collectionWithName:@"players"] updateDocumentWithID:@"lovelace" changedFields:@{@"score": @20}];
    return nil;
  }];
  
  [_client defineStubForMethodWithName:@"doSomethingElse" usingBlock:^id(NSArray *parameters) {
    [[_database collectionWithName:@"players"] updateDocumentWithID:@"gauss" changedFields:@{@"color": @"green"}];
    return nil;
  }];
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeUpdate changedFields:@{@"score": @20}];
  
  [_client callMethodWithName:@"doSomething" parameters:nil];
  NSString *methodID1 = [self lastMethodID];
  [_client callMethodWithName:@"doSomethingElse" parameters:nil];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  [_connection receiveMessage:@{@"msg": @"changed", @"collection": @"players", @"id": @"lovelace", @"fields":@{@"score": @30}}];
  
  [self expectationForChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeUpdate changedFields:@{@"score": @30}];
  
  [_connection receiveMessage:@{@"msg": @"updated", @"methods": @[methodID1]}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testSetsUpdatesFlushedOnMethodInvocationWhenAllCurrentlyBufferedDocumentsAreFlushed {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"gauss"] fields:@{@"name": @"Carl Friedrich Gauss", @"score": @15}];
  }];
  
  [_client defineStubForMethodWithName:@"doSomething" usingBlock:^id(NSArray *parameters) {
    [[_database collectionWithName:@"players"] updateDocumentWithID:@"lovelace" changedFields:@{@"score": @20}];
    return nil;
  }];
  
  [_client defineStubForMethodWithName:@"doSomethingElse" usingBlock:^id(NSArray *parameters) {
    [[_database collectionWithName:@"players"] updateDocumentWithID:@"gauss" changedFields:@{@"color": @"green"}];
    return nil;
  }];
  
  [_client callMethodWithName:@"doSomething" parameters:nil];
  METMethodInvocation *methodInvocation1 = [self lastMethodInvocation];
  [_client callMethodWithName:@"doSomethingElse" parameters:nil];
  METMethodInvocation *methodInvocation2 = [self lastMethodInvocation];
  
  [_connection receiveMessage:@{@"msg": @"updated", @"methods": @[methodInvocation1.methodID]}];
  
  [self keyValueObservingExpectationForObject:methodInvocation1 keyPath:@"updatesFlushed" expectedValue:[NSNumber numberWithBool:YES]];
  [self keyValueObservingExpectationForObject:methodInvocation2 keyPath:@"updatesFlushed" expectedValue:[NSNumber numberWithBool:YES]];
  
  [_connection receiveMessage:@{@"msg": @"updated", @"methods": @[methodInvocation2.methodID]}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#pragma mark - Receiving Ready Message

- (void)testReceivingReadyMessageWaitsUntilAllCurrentlyBufferedDocumentsAreFlushed {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  }];
  
  [_client defineStubForMethodWithName:@"doSomething" usingBlock:^id(NSArray *parameters) {
    [[_database collectionWithName:@"players"] updateDocumentWithID:@"lovelace" changedFields:@{@"score": @20}];
    return nil;
  }];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  METSubscription *subscription = [_client addSubscriptionWithName:@"allPlayers" parameters:nil completionHandler:^(NSError *error) {
    [expectation fulfill];
  }];

  [_client callMethodWithName:@"doSomething" parameters:nil];
  METMethodInvocation *methodInvocation = [self lastMethodInvocation];
  
  [_connection receiveMessage:@{@"msg": @"ready", @"subs": @[subscription.identifier]}];
  
  [self waitForTimeInterval:0.1];
  XCTAssertFalse(subscription.ready);
  
  [self keyValueObservingExpectationForObject:methodInvocation keyPath:@"updatesFlushed" expectedValue:[NSNumber numberWithBool:YES]];
  
  [_connection receiveMessage:@{@"msg": @"updated", @"methods": @[methodInvocation.methodID]}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
