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

#import "NSArray+METAdditions.h"

@implementation NSArray (METAdditions)

- (id)firstObjectPassingTest:(BOOL (^)(id object))block {
  for (id object in self) {
    if (block(object)) {
      return object;
    }
  }
  return nil;
}

- (NSArray *)mappedArrayUsingBlock:(id (^)(id object))block {
  NSMutableArray *mappedArray = [NSMutableArray arrayWithCapacity:self.count];
  for (id object in self) {
    id mappedObject = block(object);
    if (mappedObject) {
      [mappedArray addObject:mappedObject];
    }
  }
  return mappedArray;
}

- (NSArray *)filteredArrayWithObjectsPassingTest:(BOOL (^)(id object))block {
  NSMutableArray *filteredArray = [NSMutableArray arrayWithCapacity:self.count];
  for (id object in self) {
    if (block(object)) {
      [filteredArray addObject:object];
    }
  }
  return filteredArray;
}

@end
