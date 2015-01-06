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
#import "METMethodInvocation_Internal.h"

@interface METDDPClientReconnectingTests : METDDPClientTestCase

@end

@implementation METDDPClientReconnectingTests {
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

#pragma mark - Subscriptions

- (void)testReconnectingResendsSubMessagesForSubscriptions {
  METSubscription *allPlayers = [_client addSubscriptionWithName:@"allPlayers" parameters:nil];
  METSubscription *playersWithMinimumScore = [_client addSubscriptionWithName:@"playersWithMinimumScore" parameters:@[@20]];
  
  [_client disconnect];
  
  [self expectationForSentSubMessageForSubscription:allPlayers];
  [self expectationForSentSubMessageForSubscription:playersWithMinimumScore];
  
  [_client connect];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testReconnectingDoesNotResendSubMessageForRemovedSubscription {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  }];
  
  METSubscription *allPlayers = [_client addSubscriptionWithName:@"allPlayers" parameters:nil];
  allPlayers.ready = YES;
  
  [_client disconnect];
  
  [_client removeSubscription:allPlayers];
  
  [self expectationForDatabaseDidChangeNotificationWithHandler:nil];
  
  [_client connect];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testReconnectingWaitsUntilReadySubscriptionsAreAllReadyAgain {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"gauss"] fields:@{@"name": @"Carl Friedrich Gauss", @"score": @15}];
  }];
  
  METSubscription *subscription1 = [_client addSubscriptionWithName:@"allPlayers" parameters:nil];
  subscription1.ready = YES;
  METSubscription *subscription2 = [_client addSubscriptionWithName:@"playersWithMinimumScore" parameters:@[@20]];
  subscription2.ready = YES;
  
  [_client disconnect];
  
  [self performBlockWhileNotExpectingDatabaseDidChangeNotification:^{
    [_client connect];
    
    [_connection receiveMessage:@{@"msg": @"added", @"collection": @"players", @"id": @"lovelace", @"fields": @{@"name": @"Ada Lovelace", @"score": @30}}];
    
    [_connection receiveMessage:@{@"msg": @"ready", @"subs": @[subscription1.identifier]}];
  }];
  
  [self expectationForDatabaseDidChangeNotificationWithHandler:^BOOL(METDatabaseChanges *databaseChanges) {
    [self verifyDatabaseChanges:databaseChanges containsChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeUpdate changedFields:@{@"score": @30}];
    [self verifyDatabaseChanges:databaseChanges containsChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"gauss"] changeType:METDocumentChangeTypeRemove changedFields:nil];
    return YES;
  }];
  
  [_connection receiveMessage:@{@"msg": @"ready", @"subs": @[subscription2.identifier]}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testReconnectingWithNoReadySubscriptionsRemovesAllDocuments {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"gauss"] fields:@{@"name": @"Carl Friedrich Gauss", @"score": @15}];
  }];
  
  [_client addSubscriptionWithName:@"allPlayers" parameters:nil];
  [_client addSubscriptionWithName:@"playersWithMinimumScore" parameters:@[@20]];
  
  [_client disconnect];
  
  [self expectationForDatabaseDidChangeNotificationWithHandler:^BOOL(METDatabaseChanges *databaseChanges) {
    [self verifyDatabaseChanges:databaseChanges containsChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeRemove changedFields:nil];
    [self verifyDatabaseChanges:databaseChanges containsChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"gauss"] changeType:METDocumentChangeTypeRemove changedFields:nil];
    return YES;
  }];
  
  [_client connect];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#pragma mark - Method Invocations

- (void)testReconnectingResendsMessagesForMethodInvocationsThatHaveNotReceivedTheirResult {
  [_client callMethodWithName:@"doSomething" parameters:nil];
  [_client callMethodWithName:@"doSomethingElse" parameters:nil];
  
  [[self methodInvocationWithName:@"doSomething"] didReceiveResult:nil error:nil];
  
  [_client disconnect];
  
  [self expectationForSentMessageForMethodInvocation:[self methodInvocationWithName:@"doSomethingElse"]];
  
  [_client connect];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertNil([self methodInvocationWithName:@"doSomething"]);
}

- (void)testReconnectingInvokesCompletionHandlerForMethodInvocationsThatHaveReceivedTheirResult {
  XCTestExpectation *expectation = [self expectationWithDescription:@"completion handler invoked"];
  [_client callMethodWithName:@"doSomething" parameters:@[@"someParameter"] completionHandler:^(id result, NSError *error) {
    [expectation fulfill];
  }];
  
  [_connection receiveMessage:@{@"msg": @"result", @"id": [self lastMethodID], @"result": @"someResult"}];
  
  [_client disconnect];
  [_client connect];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

@end
