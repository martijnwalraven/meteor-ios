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

#import "METDatabaseChanges.h"

#import "METDocumentKey.h"
#import "METDocumentChangeDetails.h"

@implementation METDatabaseChanges {
  NSMutableDictionary *_changeDetailsByDocumentKey;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _changeDetailsByDocumentKey = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (BOOL)hasChanges {
  return _changeDetailsByDocumentKey.count > 0;
}

- (NSSet *)affectedDocumentKeys {
  return [NSSet setWithArray:_changeDetailsByDocumentKey.allKeys];
}

- (void)enumerateDocumentChangeDetailsUsingBlock:(void (^)(METDocumentChangeDetails *documentChangeDetails, BOOL *stop))block {
  [_changeDetailsByDocumentKey enumerateKeysAndObjectsUsingBlock:^(id documentID, METDocumentChangeDetails *documentChangeDetails, BOOL *stop) {
    block(documentChangeDetails, stop);
  }];
}

- (METDocumentChangeDetails *)changeDetailsForDocumentWithKey:(METDocumentKey *)documentKey {
  return _changeDetailsByDocumentKey[documentKey];
}

- (void)removeChangeDetailsForDocumentWithKey:(METDocumentKey *)documentKey {
  [_changeDetailsByDocumentKey removeObjectForKey:documentKey];
}

- (void)removeAllDocumentChangeDetails {
  [_changeDetailsByDocumentKey removeAllObjects];
}

- (void)willChangeDocumentWithKey:(METDocumentKey *)documentKey fieldsBeforeChanges:(NSDictionary *)fieldsBeforeChanges {
  METDocumentChangeDetails *changeDetails = _changeDetailsByDocumentKey[documentKey];
  
  if (!changeDetails) {
    changeDetails = [[METDocumentChangeDetails alloc] initWithDocumentKey:documentKey];
    changeDetails.fieldsBeforeChanges = fieldsBeforeChanges;
    _changeDetailsByDocumentKey[documentKey] = changeDetails;
  }
}

- (void)didChangeDocumentWithKey:(METDocumentKey *)documentKey fieldsAfterChanges:(NSDictionary *)fieldsAfterChanges {
  METDocumentChangeDetails *changeDetails = _changeDetailsByDocumentKey[documentKey];
  
  if (!changeDetails) {
    changeDetails = [[METDocumentChangeDetails alloc] initWithDocumentKey:documentKey];
    _changeDetailsByDocumentKey[documentKey] = changeDetails;
  }
  
  if (changeDetails.fieldsBeforeChanges == fieldsAfterChanges || [changeDetails.fieldsBeforeChanges isEqualToDictionary:fieldsAfterChanges]) {
    [_changeDetailsByDocumentKey removeObjectForKey:documentKey];
  } else {
    changeDetails.fieldsAfterChanges = fieldsAfterChanges;
  }
}

- (void)addDatabaseChanges:(METDatabaseChanges *)databaseChanges {
  [databaseChanges enumerateDocumentChangeDetailsUsingBlock:^(METDocumentChangeDetails *documentChangeDetails, BOOL *stop) {
    METDocumentKey *documentKey = documentChangeDetails.documentKey;
    [self willChangeDocumentWithKey:documentKey fieldsBeforeChanges:documentChangeDetails.fieldsBeforeChanges];
    [self didChangeDocumentWithKey:documentKey fieldsAfterChanges:documentChangeDetails.fieldsAfterChanges];
  }];
}

#pragma mark - NSObject

- (NSString *)description {
  return [[_changeDetailsByDocumentKey allValues] description];
}

@end
