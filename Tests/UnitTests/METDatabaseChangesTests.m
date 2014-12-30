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
#import "XCTestCase+Meteor.h"

#import "METDatabaseChanges.h"
#import "METDatabaseChanges_Internal.h"

#import "METDocumentKey.h"

@interface METDatabaseChangesTests : XCTestCase

@end

@implementation METDatabaseChangesTests {
  METDatabaseChanges *_databaseChanges;
}

- (void)setUp {
  [super setUp];
  
  _databaseChanges = [[METDatabaseChanges alloc] init];
}

- (void)testAddingDocument {
  [_databaseChanges willChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsBeforeChanges:nil];
  [_databaseChanges didChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsAfterChanges:@{@"name": @"Ada Lovelace"}];
  
  [self verifyDatabaseChanges:_databaseChanges containsChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeAdd changedFields:@{@"name": @"Ada Lovelace"}];
}

- (void)testUpdatingDocument {
  [_databaseChanges willChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsBeforeChanges:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  [_databaseChanges didChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsAfterChanges:@{@"name": @"Ada Lovelace", @"score": @30}];
  
  [self verifyDatabaseChanges:_databaseChanges containsChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeUpdate changedFields:@{@"score": @30, @"color": [NSNull null]}];
}

- (void)testRemovingDocument {
  [_databaseChanges willChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsBeforeChanges:@{@"name": @"Ada Lovelace"}];
  [_databaseChanges didChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsAfterChanges:nil];
  
  [self verifyDatabaseChanges:_databaseChanges containsChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeRemove changedFields:nil];
}

- (void)testFieldsBeforeAndAfterAreTheSame {
  [_databaseChanges willChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsBeforeChanges:@{@"name": @"Ada Lovelace"}];
  [_databaseChanges didChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsAfterChanges:@{@"name": @"Ada Lovelace"}];
  
  XCTAssertNil([_databaseChanges changeDetailsForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]]);
}

- (void)testFieldsBeforeAndAfterAreBothNil {
  [_databaseChanges willChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsBeforeChanges:nil];
  [_databaseChanges didChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsAfterChanges:nil];
  
  XCTAssertNil([_databaseChanges changeDetailsForDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]]);
}

- (void)testAddingOtherDatabaseChanges {
  [_databaseChanges willChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsBeforeChanges:nil];
  [_databaseChanges didChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsAfterChanges:@{@"name": @"Ada Lovelace"}];
  
  METDatabaseChanges *otherDatabaseChanges = [[METDatabaseChanges alloc] init];
  [otherDatabaseChanges willChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsBeforeChanges:@{@"name": @"Ada Lovelace"}];
  [otherDatabaseChanges didChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsAfterChanges:@{@"name": @"Ada Lovelace", @"score": @30}];
  
  [_databaseChanges addDatabaseChanges:otherDatabaseChanges];
  
  [self verifyDatabaseChanges:_databaseChanges containsChangeToDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changeType:METDocumentChangeTypeAdd changedFields:@{@"name": @"Ada Lovelace", @"score": @30}];
}

@end
