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

#import "METDataUpdate.h"

#import "METDocumentKey.h"

@implementation METDataUpdate

- (instancetype)initWithUpdateType:(METDataUpdateType)updateType documentKey:(METDocumentKey *)documentKey fields:(NSDictionary *)fields {
  self = [super init];
  if (self) {
    _updateType = updateType;
    _documentKey = documentKey;
    _fields = [fields copy];
  }
  return self;
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }
  
  if (![object isKindOfClass:[METDataUpdate class]]) {
    return NO;
  }
  
  return [self isEqualToDataUpdate:(METDataUpdate *)object];
}

- (BOOL)isEqualToDataUpdate:(METDataUpdate *)update {
  return _updateType == update.updateType && [_documentKey isEqual:update.documentKey] && (_fields == update.fields || [_fields isEqualToDictionary:update.fields]);
}

- (NSUInteger)hash {
  return _updateType ^ [_documentKey hash] ^ [_fields hash];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<METDataUpdate, type: %@, documentKey: %@, fields: %@>", [self descriptionOfUpdateType], _documentKey, _fields];
}

- (NSString *)descriptionOfUpdateType {
  switch (_updateType) {
    case METDataUpdateTypeAdd:
      return @"Add";
    case METDataUpdateTypeChange:
      return @"Change";
    case METDataUpdateTypeReplace:
      return @"Replace";
    case METDataUpdateTypeRemove:
      return @"Remove";
  }
}

@end
