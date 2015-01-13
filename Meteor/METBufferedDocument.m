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

#import "METBufferedDocument.h"

#import "METMethodInvocation.h"

@implementation METBufferedDocument {
  NSMutableArray *_methodInvocationsWaitingUntilUpdatesAreDone;
  NSMutableArray *_groupsWaitingUntilFlushed;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _methodInvocationsWaitingUntilUpdatesAreDone = [[NSMutableArray alloc] init];
    _groupsWaitingUntilFlushed = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)addMethodInvocationWaitingUntilUpdatesAreDone:(METMethodInvocation *)methodInvocation {
  [_methodInvocationsWaitingUntilUpdatesAreDone addObject:methodInvocation];
}

- (void)removeMethodInvocationWaitingUntilUpdatesAreDone:(METMethodInvocation *)methodInvocation {
  [_methodInvocationsWaitingUntilUpdatesAreDone removeObject:methodInvocation];
}

- (NSUInteger)numberOfSentMethodInvocationsWaitingUntilUpdatesAreDone {
  NSUInteger count = 0;
  for (METMethodInvocation *methodInvocation in _methodInvocationsWaitingUntilUpdatesAreDone) {
    if (methodInvocation.messageSent && !methodInvocation.updatesDone) {
      count++;
    }
  }
  return count;
}

- (void)waitUntilFlushedWithGroup:(dispatch_group_t)group {
  dispatch_group_enter(group);
  [_groupsWaitingUntilFlushed addObject:group];
}

- (void)didFlush {
  for (dispatch_group_t group in _groupsWaitingUntilFlushed) {
    dispatch_group_leave(group);
  }
  [_groupsWaitingUntilFlushed removeAllObjects];
}

@end
