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

#import "METCoreDataDDPClient.h"
#import "METDDPClient_Internal.h"
#import "METDatabase.h"
#import "METDatabase_Internal.h"
#import "METDocumentCache.h"
#import "METDocumentKey.h"

#import "METIncrementalStore.h"

@interface METCoreDataDDPClientTests : XCTestCase

@end

@implementation METCoreDataDDPClientTests {
  METCoreDataDDPClient *_client;
}

- (void)setUp {
  [super setUp];
  
  _client = [[METCoreDataDDPClient alloc] initWithConnection:nil managedObjectModel:[NSManagedObjectModel mergedModelFromBundles:@[[NSBundle bundleForClass:self.class]]]];
  
  [_client.database performUpdatesInLocalCacheWithoutTrackingChanges:^(METDocumentCache *localCache) {
    [localCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}];
  }];
}

- (void)testConvertsNSManagedObjectParametersToDocumentIDs {
  NSManagedObject *lovelace = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
  XCTAssertEqualObjects(@[@"lovelace"], [_client convertParameters:@[lovelace]]);
}

- (void)testConvertsNSManagedObjectIDParametersToDocumentIDs {
  NSManagedObject *lovelace = [self existingObjectForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
  XCTAssertEqualObjects(@[@"lovelace"], [_client convertParameters:@[lovelace.objectID]]);
}

#pragma mark - Helper Methods

- (NSManagedObject *)existingObjectWithID:(NSManagedObjectID *)objectID {
  NSError *error;
  NSManagedObject *object = [_client.mainQueueManagedObjectContext existingObjectWithID:objectID error:&error];
  if (!object) {
    XCTFail(@"Encountered error: %@", error);
  }
  return object;
}

- (NSManagedObject *)existingObjectForDocumentWithKey:(METDocumentKey *)documentKey {
  NSManagedObjectID *objectID = [_client.persistentStore objectIDForDocumentKey:documentKey];
  return [self existingObjectWithID:objectID];
}

@end
