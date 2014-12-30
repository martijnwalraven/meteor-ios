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
#import <OCMock/OCMock.h>

#import "METDocumentCache.h"

#import "METDocument.h"
#import "METDocumentKey.h"
#import "METFetchRequest.h"
#import "METDataUpdate.h"

@interface METDocumentCacheTests : XCTestCase

@end

@implementation METDocumentCacheTests {
  METDocumentCache *_documentCache;
}

- (void)setUp {
  [super setUp];
  
  _documentCache = [[METDocumentCache alloc] init];
}

#pragma mark - Fetching Documents

- (void)testFetchingAllDocumentsInACollection {
  [_documentCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"fruits" documentID:@"apple"] fields:@{@"name": @"Apple"}];
  [_documentCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"fruits" documentID:@"banana"] fields:@{@"name": @"Banana"}];
  [_documentCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"vegetables" documentID:@"carrot"] fields:@{@"name": @"Carrot"}];
  [_documentCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"vegetables" documentID:@"onion"] fields:@{@"name": @"Onion"}];
  
  NSArray *result = [_documentCache executeFetchRequest:[[METFetchRequest alloc] initWithCollectionName:@"fruits"]];
  METAssertContainsEqualObjects((@[@"apple", @"banana"]), [result valueForKeyPath:@"key.documentID"]);
}

#pragma mark - Modifing Documents

- (void)testAddingDocument {
  BOOL result = [_documentCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace"}];
  
  XCTAssertTrue(result);
  [self verifyDocumentCacheContainsDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace"}];
}

- (void)testAddingDocumentWhenCacheContainsExistingDocument {
  [_documentCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace"}];
  BOOL result = [_documentCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Carl Friedrich Gauss"}];
  
  XCTAssertFalse(result);
  [self verifyDocumentCacheContainsDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace"}];
}

- (void)testUpdatingDocument {
  [_documentCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];

  BOOL result = [_documentCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changedFields:@{@"score": @30, @"color": [NSNull null]}];
  
  XCTAssertTrue(result);
  [self verifyDocumentCacheContainsDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @30}];
}

- (void)testUpdatingDocumentWhenCacheDoesNotContainExistingDocument {
  BOOL result = [_documentCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changedFields:@{@"score": @30, @"color": [NSNull null]}];
  
  XCTAssertFalse(result);
  XCTAssertNil([_documentCache documentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]]);
}

- (void)testReplacingDocumentWhenCacheDoesNotContainExistingDocument {
  [_documentCache replaceDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace"}];
  
  [self verifyDocumentCacheContainsDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace"}];
}

- (void)testReplacingDocumentWhenCacheContainsExistingDocument {
  [_documentCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Carl Friedrich Gauss"}];
  
  [_documentCache replaceDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace"}];
  
  [self verifyDocumentCacheContainsDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace"}];
}

- (void)testRemovingDocument {
  [_documentCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace"}];
  
  BOOL result = [_documentCache removeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
  
  XCTAssertTrue(result);
  XCTAssertNil([_documentCache documentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]]);
}

- (void)testRemovingDocumentWhenCacheDoesNotContainExistingDocument {
  BOOL result = [_documentCache removeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
  
  XCTAssertFalse(result);
}

#pragma mark - Change Tracking

- (void)testTracksChangesWhenAddingDocument {
  id delegate = OCMStrictProtocolMock(@protocol(METDocumentCacheDelegate));
  [delegate setExpectationOrderMatters:YES];
  _documentCache.delegate = delegate;
  
  OCMExpect([delegate documentCache:_documentCache willChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsBeforeChanges:nil]);
  OCMExpect([delegate documentCache:_documentCache didChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsAfterChanges:@{@"name": @"Ada Lovelace"}]);
  
  [_documentCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace"}];
  
  OCMVerifyAll(delegate);
}

- (void)testTracksChangesWhenChangingDocument {
  [_documentCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  
  id delegate = OCMStrictProtocolMock(@protocol(METDocumentCacheDelegate));
  [delegate setExpectationOrderMatters:YES];
  _documentCache.delegate = delegate;
  
  
  OCMExpect(([delegate documentCache:_documentCache willChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsBeforeChanges:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}]));
  OCMExpect(([delegate documentCache:_documentCache didChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsAfterChanges:@{@"name": @"Ada Lovelace", @"score": @30}]));
  
  [_documentCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changedFields:@{@"score": @30, @"color": [NSNull null]}];

  OCMVerifyAll(delegate);
}

- (void)testTracksChangesWhenReplacingDocumentWhenCacheDoesNotContainExistingDocument {
  id delegate = OCMStrictProtocolMock(@protocol(METDocumentCacheDelegate));
  [delegate setExpectationOrderMatters:YES];
  _documentCache.delegate = delegate;
  
  OCMExpect([delegate documentCache:_documentCache willChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsBeforeChanges:nil]);
  OCMExpect([delegate documentCache:_documentCache didChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsAfterChanges:@{@"name": @"Ada Lovelace"}]);
  
  [_documentCache replaceDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace"}];
  
  OCMVerifyAll(delegate);
}

- (void)testTracksChangesWhenReplacingDocumentWhenCacheContainsExistingDocument {
  [_documentCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Carl Friedrich Gauss"}];
  
  id delegate = OCMStrictProtocolMock(@protocol(METDocumentCacheDelegate));
  [delegate setExpectationOrderMatters:YES];
  _documentCache.delegate = delegate;
  
  OCMExpect([delegate documentCache:_documentCache willChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsBeforeChanges:@{@"name": @"Carl Friedrich Gauss"}]);
  OCMExpect([delegate documentCache:_documentCache didChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsAfterChanges:@{@"name": @"Ada Lovelace"}]);
  
  [_documentCache replaceDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace"}];
  
  OCMVerifyAll(delegate);
}

- (void)testTracksChangesWhenRemovingDocument {
  [_documentCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace"}];
  
  id delegate = OCMStrictProtocolMock(@protocol(METDocumentCacheDelegate));
  [delegate setExpectationOrderMatters:YES];
  _documentCache.delegate = delegate;
  
  
  OCMExpect([delegate documentCache:_documentCache willChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsBeforeChanges:@{@"name": @"Ada Lovelace"}]);
  OCMExpect([delegate documentCache:_documentCache didChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fieldsAfterChanges:nil]);
  
  [_documentCache removeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
  
  OCMVerifyAll(delegate);
}

#pragma mark - Snapshotting

- (void)testCreatingAndRestoringSnapshot {
  [_documentCache addDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
  
  [_documentCache createSnapshot];
  
  [_documentCache updateDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] changedFields:@{@"score": @30, @"color": [NSNull null]}];
  
  [self verifyDocumentCacheContainsDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @30}];
  
  [_documentCache restoreSnapshot];
  
  [self verifyDocumentCacheContainsDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25, @"color": @"blue"}];
}

#pragma mark - Helper Methods

- (void)verifyDocumentCacheContainsDocumentWithKey:(METDocumentKey *)documentKey fields:(NSDictionary *)fields {
  METDocument *document = [_documentCache documentWithKey:documentKey];
  XCTAssertNotNil(document, @"Expected document cache to contain document with key %@", documentKey);
  XCTAssertEqualObjects(documentKey,  document.key);
  XCTAssertEqualObjects(fields, document.fields);
}

@end
