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

#import "NSDictionary+METAdditions.h"

@implementation NSDictionary (METAdditions)

+ (instancetype)dictionaryWithObject:(id)object forKeys:(NSArray *)keys {
  NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:keys.count];
  for (id<NSCopying> key in keys) {
    dictionary[key] = object;
  }
  return dictionary;
}

- (NSDictionary *)dictionaryByAddingEntriesFromDictionary:(NSDictionary *)otherDictionary {
  NSMutableDictionary *dictionary = [self mutableCopy];
  [dictionary addEntriesFromDictionary:otherDictionary];
  return dictionary;
}

- (NSDictionary *)dictionaryByAddingObject:(id)object forKey:(id<NSCopying>)key {
  NSMutableDictionary *dictionary = [self mutableCopy];
  dictionary[key] = object;
  return dictionary;
}

- (NSDictionary *)dictionaryByRemovingObjectForKey:(id<NSCopying>)key {
  NSMutableDictionary *dictionary = [self mutableCopy];
  [dictionary removeObjectForKey:key];
  return dictionary;
}

- (NSDictionary *)dictionaryByRemovingObjectsForKeys:(NSArray *)keys {
  NSMutableDictionary *dictionary = [self mutableCopy];
  [dictionary removeObjectsForKeys:keys];
  return dictionary;
}

- (NSDictionary *)fieldsByApplyingChangedFields:(NSDictionary *)changedFields {
  NSMutableDictionary *fields = [self mutableCopy];
  NSArray *clearedFieldNames = [changedFields allKeysForObject:[NSNull null]];
  [fields addEntriesFromDictionary:changedFields];
  [fields removeObjectsForKeys:clearedFieldNames];
  return fields;
}

@end
