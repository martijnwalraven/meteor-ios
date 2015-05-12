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

#import "METDocumentChangeDetails.h"

#import "METDocument.h"
#import "METDocumentKey.h"

@interface METDocumentChangeDetailsTests : XCTestCase

@end

@implementation METDocumentChangeDetailsTests {
  METDocumentChangeDetails *_changeDetails;
}

- (void)setUp {
  [super setUp];
  
  _changeDetails = [[METDocumentChangeDetails alloc] initWithDocumentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"]];
}

- (void)testChangedFieldsWithSameNewFieldsReturnsEmptyDictionary {
  _changeDetails.fieldsBeforeChanges = @{@"name": @"Ada Lovelace"};
  _changeDetails.fieldsAfterChanges = @{@"name": @"Ada Lovelace"};
  
  XCTAssertEqualObjects(@{}, _changeDetails.changedFields);
}

- (void)testChangedFieldsWithNewFieldAddedReturnsAddedField {
  _changeDetails.fieldsBeforeChanges = @{@"name": @"Ada Lovelace"};
  _changeDetails.fieldsAfterChanges = @{@"name": @"Ada Lovelace", @"score": @30};
  
  XCTAssertEqualObjects(@{@"score": @30}, _changeDetails.changedFields);
}

- (void)testChangedFieldsWithFieldsBeforeChangesSetToNilReturnsAddedFields {
  _changeDetails.fieldsBeforeChanges = nil;
  _changeDetails.fieldsAfterChanges = @{@"name": @"Ada Lovelace", @"score": @25};
  
  XCTAssertEqualObjects((@{@"name": @"Ada Lovelace", @"score": @25}), _changeDetails.changedFields);
}

- (void)testChangedFieldsWithFieldValueChangedReturnsChangedField {
  _changeDetails.fieldsBeforeChanges = @{@"name": @"Ada Lovelace", @"score": @25};
  _changeDetails.fieldsAfterChanges = @{@"name": @"Ada Lovelace", @"score": @30};
  
  XCTAssertEqualObjects(@{@"score": @30}, _changeDetails.changedFields);
}

- (void)testChangedFieldsWithFieldRemovedReturnsNullValueForRemovedField {
  _changeDetails.fieldsBeforeChanges = @{@"name": @"Ada Lovelace", @"color": @"green"};
  _changeDetails.fieldsAfterChanges = @{@"name": @"Ada Lovelace"};
  
  XCTAssertEqualObjects(@{@"color": [NSNull null]}, _changeDetails.changedFields);
}

- (void)testChangedFieldsWithFieldsAfterChangesSetToNilReturnsRemovedFields {
  _changeDetails.fieldsBeforeChanges = @{@"name": @"Ada Lovelace", @"score": @25};
  _changeDetails.fieldsAfterChanges = nil;
  
  XCTAssertEqualObjects((@{@"name": [NSNull null], @"score": [NSNull null]}), _changeDetails.changedFields);
}

@end
