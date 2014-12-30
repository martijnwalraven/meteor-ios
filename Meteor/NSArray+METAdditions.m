//
//  Copyright 2010-2014 Martijn Walraven. All rights reserved.
//

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
