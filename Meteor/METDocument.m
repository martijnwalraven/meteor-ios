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

#import "METDocument.h"

#import "METDocumentKey.h"

@implementation METDocument {
  NSDictionary *_fields;
}

- (instancetype)initWithKey:(METDocumentKey *)key fields:(NSDictionary *)fields {
  self = [super init];
  if (self) {
    NSParameterAssert(key);
    NSParameterAssert(fields);
    
    _key = key;
    _fields = [fields copy];
  }
  return self;
}

- (id)valueForUndefinedKey:(NSString *)key {
  return [_fields valueForKey:key];
}

- (id)objectForKeyedSubscript:(id)key {
  return _fields[key];
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
  if (self == object) {
    return YES;
  }
  
  if (![object isKindOfClass:[METDocument class]]) {
    return NO;
  }
  
  return [self isEqualToDocument:(METDocument *)object];
}

- (BOOL)isEqualToDocument:(METDocument *)document {
  return [_key isEqual:document.key] && [_fields isEqualToDictionary:document.fields];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<METDocument key: %@, fields: %@>", _key, _fields];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
  return [[[self class] allocWithZone:zone] initWithKey:_key fields:_fields];
}

@end
