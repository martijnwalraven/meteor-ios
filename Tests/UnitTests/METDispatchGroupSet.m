// Copyright (c) 2014 Martijn Walraven
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

#import "METDispatchGroupSet.h"

@implementation METDispatchGroupSet {
  NSMutableDictionary *_groupsByKey;
  
  dispatch_queue_t _observerQueue;
  METDispatchGroupSetCompletionBlock _completionBlock;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _groupsByKey = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (BOOL)containsGroupForKey:(id<NSCopying>)key {
  return _groupsByKey[key] != nil;
}

- (dispatch_group_t)incrementTaskCountForKey:(id<NSCopying>)key {
  dispatch_group_t group = _groupsByKey[key];
  BOOL alreadyContainedGroup = group != nil;
  if (!group) {
    group = dispatch_group_create();
    _groupsByKey[key] = group;
  }
  
  dispatch_group_enter(group);
  
  if (!alreadyContainedGroup && _observerQueue && _completionBlock) {
    dispatch_group_notify(group, _observerQueue, ^{
      _completionBlock(key);
      [_groupsByKey removeObjectForKey:key];
    });
  }
  
  return group;
}

- (void)decrementTaskCountForKey:(id<NSCopying>)key {
  dispatch_group_leave(_groupsByKey[key]);
}

- (void)notifyWhenAnyKeyCompletedWithQueue:(dispatch_queue_t)queue usingBlock:(METDispatchGroupSetCompletionBlock)block {
  _observerQueue = queue;
  _completionBlock = [block copy];
}

- (void)addDependentGroupForCurrentKeys:(dispatch_group_t)dependentGroup queue:(dispatch_queue_t)queue {
  for (dispatch_group_t group in [_groupsByKey allValues]) {
    dispatch_group_enter(dependentGroup);
    dispatch_group_notify(group, queue, ^{
      dispatch_group_leave(dependentGroup);
    });
  }
}

@end
