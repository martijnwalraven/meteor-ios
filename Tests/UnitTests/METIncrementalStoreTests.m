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

#import "METIncrementalStore.h"
#import "METIncrementalStore_Testing.h"

#import "METDDPClient.h"
#import "METDatabase.h"
#import "METDatabase_Internal.h"
#import "METCollection.h"
#import "METCollection_Internal.h"
#import "METDocument.h"
#import "METDocumentKey.h"
#import "METDocumentCache.h"
#import "METDatabaseChanges.h"
#import "METDocumentChangeDetails.h"
#import "METRandomValueGenerator.h"

@interface METIncrementalStoreTests : XCTAsyncTestCase

@end

@implementation METIncrementalStoreTests {
  METDDPClient *_client;
  METDatabase *_database;
  METIncrementalStore *_store;
  NSManagedObjectModel *_managedObjectModel;
  NSPersistentStoreCoordinator *_persistentStoreCoordinator;
  NSManagedObjectContext *_managedObjectContext;
}

- (void)setUp {
  [super setUp];
  
  NSError *error = nil;
  
  _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:@[[NSBundle bundleForClass:[self class]]]];
  _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_managedObjectModel];
  
  _store = (METIncrementalStore *)[_persistentStoreCoordinator addPersistentStoreWithType:[METIncrementalStore type] configuration:nil URL:nil options:nil error:&error];
  XCTAssertNotNil(_store);
  
  _client = [[METDDPClient alloc] initWithConnection:nil];
  _database = _client.database;
  _store.client = _client;
  
  _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
  _managedObjectContext.persistentStoreCoordinator = _persistentStoreCoordinator;
  
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"gauss"] fields:@{@"name": @"Carl Friedrich Gauss", @"score": @5}];
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"shannon"] fields:@{@"name": @"Claude Shannon", @"score": @10}];
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"turing"] fields:@{@"name": @"Alan Turing", @"score": @20}];
  }];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testMetadata {
  XCTAssertNotNil(_store.metadata);
}

- (void)testObjectIDForDocumentKeyReturnsNilForUnknownEntities {
  NSManagedObjectID *objectID = [_store objectIDForDocumentKey:[METDocumentKey keyWithCollectionName:@"scientists" documentID:@"lovelace"]];
  XCTAssertNil(objectID);
}

#pragma mark - Fetching Objects

- (void)testFetchingAllObjectsForEntity {
  NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Player"];
  NSArray *results = [self executeFetchRequest:request];
  
  XCTAssertEqualObjects([NSSet setWithArray:(@[@"gauss", @"shannon", @"turing", @"lovelace"])], [self documentIDsForObjects:[NSSet setWithArray:results]]);
  XCTAssertEqual(0, [_store numberOfCachedNodes]);
}

- (void)testFetchingAllObjectsForEntityReturningObjectIDs {
  NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Player"];
  request.resultType = NSManagedObjectIDResultType;
  NSArray *results = [self executeFetchRequest:request];
  
  XCTAssertEqualObjects([NSSet setWithArray:(@[@"gauss", @"shannon", @"turing", @"lovelace"])], [self documentIDsForObjectIDs:[NSSet setWithArray:results]]);
  XCTAssertEqual(0, [_store numberOfCachedNodes]);
}

- (void)testFetchingAllObjectsForEntityReturningCount {
  NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Player"];
  request.resultType = NSCountResultType;
  NSArray *results = [self executeFetchRequest:request];
  
  XCTAssertEqualObjects(@[@4], results);
  XCTAssertEqual(0, [_store numberOfCachedNodes]);
}

- (void)testFetchingAllObjectsForEntityWithSortDescriptors {
  NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Player"];
  request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"score" ascending:YES]];
  NSArray *results = [self executeFetchRequest:request];
  
  XCTAssertEqualObjects((@[@"gauss", @"shannon", @"turing", @"lovelace"]), [self documentIDsForOrderedObjects:results]);
  // XCTAssertEqual(0, [_store numberOfCachedNodes]);
}

- (void)testFetchingObjectsForEntityWithPredicate {
  NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Player"];
  request.predicate = [NSPredicate predicateWithFormat:@"score >= 25"];
  NSArray *results = [self executeFetchRequest:request];
  
  XCTAssertEqualObjects([NSSet setWithArray:(@[@"lovelace"])], [self documentIDsForObjects:[NSSet setWithArray:results]]);
  // XCTAssertEqual(1, [_store numberOfCachedNodes]);
}

- (void)testFetchingObjectByObjectID {
  NSManagedObjectID *objectID = [_store objectIDForDocumentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
  NSManagedObject *object = [self existingObjectWithID:objectID];
  XCTAssertEqualObjects(@"Ada Lovelace", [object valueForKey:@"name"]);
}

- (void)testFetchingUnknownObjectByObjectID {
  NSManagedObjectID *objectID = [_store objectIDForDocumentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"unknown"]];
  NSError *error;
  NSManagedObject *object = [_managedObjectContext existingObjectWithID:objectID error:&error];
  XCTAssertNil(object);
  XCTAssertNotNil(error);
}

- (void)testFetchingObjectWithMappedFieldName {
  NSDate *date = [NSDate date];
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"messages" documentID:@"message1"] fields:@{@"createdAt": date}];
  }];
  
  NSManagedObject *object = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"messages" documentID:@"message1"]];
  XCTAssertEqualObjects(date, [object valueForKey:@"creationDate"]);
}

#pragma mark - Fetching Relationships

- (void)testFetchingOneToOneRelationship {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"avatars" documentID:@"avatar1"] fields:@{@"playerId": @"lovelace"}];
    [localCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changedFields:@{@"avatarId": @"avatar1"}];
  }];
  
  NSManagedObject *lovelace = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
  XCTAssertEqualObjects(@"avatar1", [self documentIDForObject:[lovelace valueForKey:@"avatar"]]);
}

- (void)testFetchingOneToOneRelationshipInverse {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"avatars" documentID:@"avatar1"] fields:@{@"playerId": @"lovelace"}];
    [localCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changedFields:@{@"avatarId": @"avatar1"}];
  }];
  
  NSManagedObject *avatar1 = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"avatars" documentID:@"avatar1"]];
  XCTAssertEqualObjects(@"lovelace", [self documentIDForObject:[avatar1 valueForKey:@"player"]]);
}

- (void)testFetchingOneToManyRelationship
{
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"messages" documentID:@"message1"] fields:@{@"senderId": @"lovelace"}];
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"messages" documentID:@"message2"] fields:@{@"senderId": @"lovelace"}];
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"messages" documentID:@"message3"] fields:@{@"senderId": @"gauss"}];
    [localCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changedFields:@{@"sentMessageIds": @[@"message1", @"message2"]}];
    [localCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"gauss"] changedFields:@{@"sentMessageIds": @[@"message3"]}];
  }];
  
  NSManagedObject *lovelace = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
  NSManagedObject *gauss = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"gauss"]];
  XCTAssertEqualObjects([NSSet setWithArray:(@[@"message1", @"message2"])], [self documentIDsForObjects:[lovelace valueForKey:@"sentMessages"]]);
  XCTAssertEqualObjects([NSSet setWithArray:(@[@"message3"])], [self documentIDsForObjects:[gauss valueForKey:@"sentMessages"]]);
}

- (void)testFetchingManyToOneRelationship
{
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"messages" documentID:@"message1"] fields:@{@"senderId": @"lovelace"}];
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"messages" documentID:@"message2"] fields:@{@"senderId": @"lovelace"}];
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"messages" documentID:@"message3"] fields:@{@"senderId": @"gauss"}];
    [localCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changedFields:@{@"sentMessageIds": @[@"message1", @"message2"]}];
    [localCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"gauss"] changedFields:@{@"sentMessageIds": @[@"message3"]}];
  }];
  
  NSManagedObject *message = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"messages" documentID:@"message1"]];
  XCTAssertEqualObjects(@"lovelace", [self documentIDForObject:[message valueForKey:@"sender"]]);
}

- (void)testFetchingManyToManyRelationship {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"messages" documentID:@"message1"] fields:@{@"receiverIds": @[@"lovelace"]}];
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"messages" documentID:@"message2"] fields:@{@"receiverIds": @[@"lovelace", @"gauss"]}];
    [localCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changedFields:@{@"receivedMessageIds": @[@"message1", @"message2"]}];
    [localCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"gauss"] changedFields:@{@"receivedMessageIds": @[@"message2"]}];
  }];
  
  NSManagedObject *message1 = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"messages" documentID:@"message1"]];
  NSManagedObject *message2 = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"messages" documentID:@"message2"]];
  XCTAssertEqualObjects([NSSet setWithArray:(@[@"lovelace"])], [self documentIDsForObjects:[message1 valueForKey:@"receivers"]]);
  XCTAssertEqualObjects([NSSet setWithArray:(@[@"lovelace", @"gauss"])], [self documentIDsForObjects:[message2 valueForKey:@"receivers"]]);
}

- (void)testFetchingManyToManyRelationshipInverse {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"messages" documentID:@"message1"] fields:@{@"receiverIds": @[@"lovelace"]}];
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"messages" documentID:@"message2"] fields:@{@"receiverIds": @[@"lovelace", @"gauss"]}];
    [localCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changedFields:@{@"receivedMessageIds": @[@"message1", @"message2"]}];
    [localCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"gauss"] changedFields:@{@"receivedMessageIds": @[@"message2"]}];
  }];
  
  NSManagedObject *lovelace = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
  NSManagedObject *gauss = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"gauss"]];
  XCTAssertEqualObjects([NSSet setWithArray:(@[@"message1", @"message2"])], [self documentIDsForObjects:[lovelace valueForKey:@"receivedMessages"]]);
  XCTAssertEqualObjects([NSSet setWithArray:(@[@"message2"])], [self documentIDsForObjects:[gauss valueForKey:@"receivedMessages"]]);
}

#pragma mark - Saving Objects

- (void)testInsertingObjectInsertsDocumentInDatabase {
  NSManagedObject *crick = [NSEntityDescription insertNewObjectForEntityForName:@"Player" inManagedObjectContext:_managedObjectContext];
  [crick setValue:@"Francis Crick" forKey:@"name"];
  [crick setValue:@35 forKey:@"score"];
  [self saveManagedObjectContext];
  
  METDocument *document = [_store documentForObjectWithID:crick.objectID];
  XCTAssertEqualObjects(@"Francis Crick", document[@"name"]);
  XCTAssertEqualObjects(@35, document[@"score"]);
}

- (void)testInsertingObjectPostsDatabaseDidChangeNotification {
  NSManagedObject *crick = [NSEntityDescription insertNewObjectForEntityForName:@"Player" inManagedObjectContext:_managedObjectContext];
  [crick setValue:@"Francis Crick" forKey:@"name"];
  [crick setValue:@35 forKey:@"score"];
  [_managedObjectContext obtainPermanentIDsForObjects:@[crick] error:nil];
  
  [self expectationForChangeToDocumentWithKey:[_store documentKeyForObjectID:crick.objectID] changeType:METDocumentChangeTypeAdd changedFields:@{@"name": @"Francis Crick", @"score": @35}];
  
  [self saveManagedObjectContext];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testInsertingObjectPostsObjectsDidChangeNotification {
  NSManagedObject *crick = [NSEntityDescription insertNewObjectForEntityForName:@"Player" inManagedObjectContext:_managedObjectContext];
  [crick setValue:@"Francis Crick" forKey:@"name"];
  [crick setValue:@35 forKey:@"score"];
  [self saveManagedObjectContext];
  
  [self expectationForChangeToObjectWithID:crick.objectID userInfoKey:NSInsertedObjectsKey];
  
  [self saveManagedObjectContext];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testInsertingObjectWithNilFieldValue {
  NSManagedObject *player = [NSEntityDescription insertNewObjectForEntityForName:@"Player" inManagedObjectContext:_managedObjectContext];
  [player setValue:@10 forKey:@"score"];
  
  [self saveManagedObjectContext];
  
  METDocument *document = [_store documentForObjectWithID:player.objectID];
  XCTAssertEqualObjects(@10, document[@"score"]);
}

- (void)testInsertingObjectWithMappedFieldName {
  NSManagedObject *message = [NSEntityDescription insertNewObjectForEntityForName:@"Message" inManagedObjectContext:_managedObjectContext];
  NSDate *date = [NSDate date];
  [message setValue:date forKey:@"creationDate"];
  
  [self saveManagedObjectContext];
  
  METDocument *document = [_store documentForObjectWithID:message.objectID];
  XCTAssertEqualObjects(date, document[@"createdAt"]);
}

- (void)testUpdatingObjectUpdatesDocumentInDatabase {
  NSManagedObject *lovelace = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
  [lovelace setValue:@30 forKey:@"score"];
  [self saveManagedObjectContext];
  
  METDocument *document = [_store documentForObjectWithID:lovelace.objectID];
  XCTAssertEqualObjects(@"Ada Lovelace", document[@"name"]);
  XCTAssertEqualObjects(@30, document[@"score"]);
}

- (void)testUpdatingObjectPostsDatabaseDidChangeNotification {
  NSManagedObject *lovelace = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];

  [self expectationForChangeToDocumentWithKey:[_store documentKeyForObjectID:lovelace.objectID] changeType:METDocumentChangeTypeUpdate changedFields:@{@"score": @30}];
  
  [lovelace setValue:@30 forKey:@"score"];
  [self saveManagedObjectContext];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testUpdatingObjectPostsObjectsDidChangeNotification {
  NSManagedObject *lovelace = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
  
  [self expectationForChangeToObjectWithID:lovelace.objectID userInfoKey:NSUpdatedObjectsKey];
  
  [lovelace setValue:@30 forKey:@"score"];
  [self saveManagedObjectContext];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testDeletingObjectDeletesDocumentInDatabase {
  NSManagedObject *lovelace = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
  [_managedObjectContext deleteObject:lovelace];
  [self saveManagedObjectContext];
  
  METDocument *document = [_store documentForObjectWithID:lovelace.objectID];
  XCTAssertNil(document);
}

- (void)testDeletingObjectPostsDatabaseDidChangeNotification {
  NSManagedObject *lovelace = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
  
  [self expectationForChangeToDocumentWithKey:[_store documentKeyForObjectID:lovelace.objectID] changeType:METDocumentChangeTypeRemove changedFields:nil];
  
  [_managedObjectContext deleteObject:lovelace];
  [self saveManagedObjectContext];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testDeletingObjectPostsObjectsDidChangeNotification {
  NSManagedObject *lovelace = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
  
  [self expectationForChangeToObjectWithID:lovelace.objectID userInfoKey:NSDeletedObjectsKey];
  
  [_managedObjectContext deleteObject:lovelace];
  [self saveManagedObjectContext];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

#pragma mark - Saving Relationships

- (void)testSavingOneToOneRelationship {
  NSManagedObject *lovelace = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
  NSManagedObject *avatar = [NSEntityDescription insertNewObjectForEntityForName:@"Avatar" inManagedObjectContext:_managedObjectContext];
  
  [lovelace setValue:avatar forKey:@"avatar"];
  [self saveManagedObjectContext];

  XCTAssertEqualObjects([self documentIDForObjectID:avatar.objectID], [_store documentForObjectWithID:lovelace.objectID][@"avatarId"]);
  XCTAssertEqualObjects([self documentIDForObjectID:lovelace.objectID], [_store documentForObjectWithID:avatar.objectID][@"playerId"]);
}

- (void)testSavingOneToManyRelationship {
  NSManagedObject *lovelace = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
  NSManagedObject *message1 = [NSEntityDescription insertNewObjectForEntityForName:@"Message" inManagedObjectContext:_managedObjectContext];
  NSManagedObject *message2 = [NSEntityDescription insertNewObjectForEntityForName:@"Message" inManagedObjectContext:_managedObjectContext];
  
  [lovelace setValue:[NSSet setWithArray:@[message1, message2]] forKey:@"sentMessages"];
  [self saveManagedObjectContext];
  
  XCTAssertEqualObjects([self documentIDForObjectID:lovelace.objectID], [_store documentForObjectWithID:message1.objectID][@"senderId"]);
  XCTAssertEqualObjects([self documentIDForObjectID:lovelace.objectID], [_store documentForObjectWithID:message2.objectID][@"senderId"]);
  XCTAssertEqualObjects([NSSet setWithArray:(@[[self documentIDForObjectID:message1.objectID], [self documentIDForObjectID:message2.objectID]])], [self documentIDsForObjects:[lovelace valueForKey:@"sentMessages"]]);
}

- (void)testSavingManyToManyRelationship {
  NSManagedObject *lovelace = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
  NSManagedObject *gauss = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"gauss"]];
  NSManagedObject *message1 = [NSEntityDescription insertNewObjectForEntityForName:@"Message" inManagedObjectContext:_managedObjectContext];
  NSManagedObject *message2 = [NSEntityDescription insertNewObjectForEntityForName:@"Message" inManagedObjectContext:_managedObjectContext];
  
  [lovelace setValue:[NSSet setWithArray:@[message1, message2]] forKey:@"receivedMessages"];
  [gauss setValue:[NSSet setWithArray:@[message2]] forKey:@"receivedMessages"];
  [self saveManagedObjectContext];
  
  XCTAssertEqualObjects([NSSet setWithArray:(@[[self documentIDForObjectID:message1.objectID], [self documentIDForObjectID:message2.objectID]])], [self documentIDsForObjects:[lovelace valueForKey:@"receivedMessages"]]);
  XCTAssertEqualObjects([NSSet setWithArray:(@[[self documentIDForObjectID:message2.objectID]])], [self documentIDsForObjects:[gauss valueForKey:@"receivedMessages"]]);
  XCTAssertEqualObjects([NSSet setWithArray:(@[[self documentIDForObjectID:lovelace.objectID]])], [self documentIDsForObjects:[message1 valueForKey:@"receivers"]]);
  XCTAssertEqualObjects([NSSet setWithArray:(@[[self documentIDForObjectID:lovelace.objectID], [self documentIDForObjectID:gauss.objectID]])], [self documentIDsForObjects:[message2 valueForKey:@"receivers"]]);
}

#pragma mark - Responding To Database Changes

- (void)testPostsObjectsDidChangeNotificationWhenDocumentsChange {
  [self expectationForNotification:METIncrementalStoreObjectsDidChangeNotification object:_store handler:^BOOL(NSNotification *notification) {
    NSDictionary *userInfo = notification.userInfo;
    XCTAssertEqualObjects([NSSet setWithArray:@[@"crick"]], [self documentIDsForObjectIDs:userInfo[NSInsertedObjectsKey]]);
    XCTAssertEqualObjects([NSSet setWithArray:@[@"gauss"]], [self documentIDsForObjectIDs:userInfo[NSUpdatedObjectsKey]]);
    XCTAssertEqualObjects([NSSet setWithArray:@[@"shannon"]], [self documentIDsForObjectIDs:userInfo[NSDeletedObjectsKey]]);
    return YES;
  }];
  
  [_database performUpdates:^{
    METCollection *players = [_database collectionWithName:@"players"];
    [players insertDocumentWithID:@"crick" fields:@{@"name": @"Francis Crick", @"score": @35}];
    [players updateDocumentWithID:@"gauss" changedFields:@{@"score": @10}];
    [players removeDocumentWithID:@"shannon"];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testDoesNotPostObjectsDidChangeNotificationWhenDocumentsChangeIfThereIsNoEntityForACollection {
  [_database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"scientists" documentID:@"gauss"] fields:@{@"name": @"Carl Friedrich Gauss", @"score": @5}];
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"scientists" documentID:@"shannon"] fields:@{@"name": @"Claude Shannon", @"score": @10}];
  }];
  
  [self performBlockWhileNotExpectingObjectsDidChangeNotification:^{
    [_database performUpdates:^{
      METCollection *scientists = [_database collectionWithName:@"scientists"];
      [scientists insertDocumentWithID:@"crick" fields:@{@"name": @"Francis Crick", @"score": @35}];
      [scientists updateDocumentWithID:@"gauss" changedFields:@{@"score": @10}];
      [scientists removeDocumentWithID:@"shannon"];
    }];
    
    [self waitForTimeInterval:0.1];
  }];
}

#pragma mark - Helper Methods

- (id)documentIDForObject:(NSManagedObject *)object {
  NSParameterAssert(object);
  return [_store documentKeyForObjectID:object.objectID].documentID;
}

- (id)documentIDForObjectID:(NSManagedObjectID *)objectID {
  NSParameterAssert(objectID);
  return [_store documentKeyForObjectID:objectID].documentID;
}

- (NSSet *)documentIDsForObjectIDs:(NSSet *)objectIDs {
  NSParameterAssert(objectIDs);
  NSMutableSet *documentIDs = [[NSMutableSet alloc] initWithCapacity:objectIDs.count];
  for (NSManagedObjectID *objectID in objectIDs) {
    [documentIDs addObject:[self documentIDForObjectID:objectID]];
  }
  return documentIDs;
}

- (NSSet *)documentIDsForObjects:(NSSet *)objects {
  NSParameterAssert(objects);
  NSMutableSet *documentIDs = [[NSMutableSet alloc] initWithCapacity:objects.count];
  for (NSManagedObject *object in objects) {
    [documentIDs addObject:[self documentIDForObject:object]];
  }
  return documentIDs;
}

- (NSArray *)documentIDsForOrderedObjects:(NSArray *)objects {
  NSParameterAssert(objects);
  NSMutableArray *documentIDs = [[NSMutableArray alloc] initWithCapacity:objects.count];
  for (NSManagedObject *object in objects) {
    [documentIDs addObject:[self documentIDForObject:object]];
  }
  return documentIDs;
}

- (NSArray *)executeFetchRequest:(NSFetchRequest *)request {
  NSError *error;
  NSArray *results = [_managedObjectContext executeFetchRequest:request error:&error];
  if (!results) {
    XCTFail(@"Encountered error: %@", error);
  }
  return results;
}

- (NSManagedObject *)existingObjectWithID:(NSManagedObjectID *)objectID {
  NSError *error;
  NSManagedObject *object = [_managedObjectContext existingObjectWithID:objectID error:&error];
  if (!object) {
    XCTFail(@"Encountered error: %@", error);
  }
  return object;
}

- (NSManagedObject *)existingObjectForDocumentWithKey:(METDocumentKey *)documentKey {
  NSManagedObjectID *objectID = [_store objectIDForDocumentKey:documentKey];
  return [self existingObjectWithID:objectID];
}

- (void)saveManagedObjectContext {
  NSError *error;
  if (![_managedObjectContext save:&error]) {
    XCTFail(@"Encountered error: %@", error);
  }
}

- (XCTestExpectation *)expectationForChangeToObjectWithID:(NSManagedObjectID *)objectID userInfoKey:(NSString *)userInfoKey {
  return [self expectationForNotification:METIncrementalStoreObjectsDidChangeNotification object:nil handler:^BOOL(NSNotification *notification) {
    NSSet *changedObjects = notification.userInfo[userInfoKey];
    return [changedObjects containsObject:objectID];
  }];
}

- (void)performBlockWhileNotExpectingObjectsDidChangeNotification:(void (^)())block {
  id observer = [[NSNotificationCenter defaultCenter] addObserverForName:METIncrementalStoreObjectsDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *notification) {
    XCTFail(@"Should not post objects did change notification");
  }];
  
  block();
  
  [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

@end
