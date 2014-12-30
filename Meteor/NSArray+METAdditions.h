//
//  Copyright 2010-2014 Martijn Walraven. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSArray (METAdditions)

- (id)firstObjectPassingTest:(BOOL (^)(id object))block;
- (NSArray *)mappedArrayUsingBlock:(id (^)(id object))block;
- (NSArray *)filteredArrayWithObjectsPassingTest:(BOOL (^)(id object))block;

@end
