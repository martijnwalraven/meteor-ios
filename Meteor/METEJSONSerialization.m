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

#import "METEJSONSerialization.h"

NSString * const METEJSONSerializationErrorDomain = @"com.meteor.EJSONSerialization.ErrorDomain";

@implementation METEJSONSerialization

+ (id)objectFromEJSONObject:(id)EJSONObject error:(NSError **)error {
  if ([EJSONObject isKindOfClass:[NSDictionary class]]) {
    if ([EJSONObject count] == 1) {
      id key = [[EJSONObject keyEnumerator] nextObject];
      id value = EJSONObject[key];
      
      if ([key isEqualToString:@"$date"]) {
        if (![value isKindOfClass:[NSNumber class]]) {
          if (error) {
            *error = [NSError errorWithDomain:METEJSONSerializationErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"Expected number of milliseconds as $date value"}];
          }
          return nil;
        }
        NSTimeInterval timestamp = [value doubleValue] / 1000.0;
        return [NSDate dateWithTimeIntervalSince1970:timestamp];
      } else if ([key isEqualToString:@"$binary"]) {
        if (![value isKindOfClass:[NSString class]]) {
          if (error) {
            *error = [NSError errorWithDomain:METEJSONSerializationErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"Expected base 64 encoded string as $binary value"}];
          }
          return nil;
        }
        return [[NSData alloc] initWithBase64EncodedString:value options:0];
      } else if ([key isEqualToString:@"$escape"]) {
        NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:[value count]];
        
        for (id escapedKey in value) {
          dictionary[escapedKey] = [self objectFromEJSONObject:value[escapedKey] error:error];
        }
        return dictionary;
      }
    }
    
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:[EJSONObject count]];
    
    for (id key in EJSONObject) {
      dictionary[key] = [self objectFromEJSONObject:EJSONObject[key] error:error];
    }
    
    return dictionary;
  } else if ([EJSONObject isKindOfClass:[NSArray class]]) {
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:[EJSONObject count]];
    
    [EJSONObject enumerateObjectsUsingBlock:^(id item, NSUInteger index, BOOL *stop) {
      array[index] = [self objectFromEJSONObject:item error:error];
    }];
    
    return array;
  } else {
    return EJSONObject;
  }
}

+ (id)EJSONObjectFromObject:(id)object error:(NSError **)error {
  if ([object isKindOfClass:[NSDate class]]) {
    return @{@"$date": @(floor([object timeIntervalSince1970] * 1000.0))};
  } else if ([object isKindOfClass:[NSData class]]) {
    return @{@"$binary": [object base64EncodedStringWithOptions:0]};
  } else if ([object isKindOfClass:[NSDictionary class]]) {
    if ([object count] == 1) {
      NSString *key = [[object keyEnumerator] nextObject];
      if ([key isEqualToString:@"$date"] || [key isEqualToString:@"$binary"]) {
        id value = object[key];
        return @{@"$escape": @{key: [self EJSONObjectFromObject:value error:error]}};
      }
    }
    
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:[object count]];
    
    for (id key in object) {
      dictionary[key] = [self EJSONObjectFromObject:object[key] error:error];
    }

    return dictionary;
  } else if ([object isKindOfClass:[NSArray class]]) {
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:[object count]];
    
    [object enumerateObjectsUsingBlock:^(id item, NSUInteger index, BOOL *stop) {
      array[index] = [self EJSONObjectFromObject:item error:error];
    }];
    
    return array;
  } else {
    return object;
  }
}

@end
