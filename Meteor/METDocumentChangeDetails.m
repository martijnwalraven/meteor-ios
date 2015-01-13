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

#import "METDocumentChangeDetails.h"

@implementation METDocumentChangeDetails

- (instancetype)initWithDocumentKey:(METDocumentKey *)documentKey {
  self = [super init];
  if (self) {
    _documentKey = documentKey;
  }
  return self;
}

- (METDocumentChangeType)changeType {
  if (_fieldsBeforeChanges == nil) {
    return METDocumentChangeTypeAdd;
  } else if (_fieldsAfterChanges == nil) {
    return METDocumentChangeTypeRemove;
  } else {
    return METDocumentChangeTypeUpdate;
  }
}

- (NSDictionary *)changedFields {
  NSMutableDictionary *changedFields = [_fieldsAfterChanges mutableCopy];
  [changedFields enumerateKeysAndObjectsUsingBlock:^(NSString *name, id newValue, BOOL *stop) {
    id oldValue = _fieldsBeforeChanges[name];
    if (oldValue && [oldValue isEqual:newValue]) {
      [changedFields removeObjectForKey:name];
    }
  }];
  [_fieldsBeforeChanges enumerateKeysAndObjectsUsingBlock:^(id name, id oldValue, BOOL *stop) {
    id newValue = _fieldsAfterChanges[name];
    if (!newValue) {
      changedFields[name] = [NSNull null];
    }
  }];
  return changedFields;
}

#pragma mark - NSObject

- (NSString *)description {
  return [NSString stringWithFormat:@"<METDocumentChangeDetails %@, changeType: %@, changedFields: %@>", _documentKey, [self descriptionOfChangeType], self.changedFields];
}

- (NSString *)descriptionOfChangeType {
  switch ([self changeType]) {
    case METDocumentChangeTypeAdd:
      return @"Add";
    case METDocumentChangeTypeUpdate:
      return @"Update";
    case METDocumentChangeTypeRemove:
      return @"Remove";
  }
}

@end
