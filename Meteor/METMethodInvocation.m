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

#import "METMethodInvocation.h"
#import "METMethodInvocation_Internal.h"

#import "METMethodInvocationCoordinator.h"
#import "METDDPClient.h"
#import "METDDPClient_Internal.h"

@interface METMethodInvocation ()

@property (assign, nonatomic, readwrite) BOOL messageSent;
@property (assign, nonatomic, readwrite) BOOL resultReceived;
@property (assign, nonatomic, readwrite) BOOL updatesDone;
@property (assign, nonatomic, readwrite) BOOL updatesFlushed;

@end

@implementation METMethodInvocation {
  BOOL _executing;
  BOOL _finished;
  BOOL _completionHandlerInvoked;
}

- (BOOL)isAsynchronous {
  return YES;
}

- (BOOL)isExecuting {
  return _executing;
}

- (BOOL)isFinished {
  return _finished;
}

- (void)beginOperation {
  [self willChangeValueForKey:@"isExecuting"];
  _executing = YES;
  [self didChangeValueForKey:@"isExecuting"];
}

- (void)finishOperation {
  [self willChangeValueForKey:@"isFinished"];
  [self willChangeValueForKey:@"isExecuting"];
  _executing = NO;
  _finished = YES;
  [self didChangeValueForKey:@"isExecuting"];
  [self didChangeValueForKey:@"isFinished"];
}


- (void)start {
  if (self.cancelled) {
    [self willChangeValueForKey:@"isFinished"];
    _finished = YES;
    [self didChangeValueForKey:@"isFinished"];
    return;
  }
  
  [self beginOperation];
  
  [_client sendMethodMessageForMethodInvocation:self];
  self.messageSent = YES;
}

- (void)cancel {
  [super cancel];
  
  if (_executing) {
    [self finishOperation];
  }
}

- (void)didReceiveResult:(id)result error:(NSError *)error {
  self.resultReceived = YES;
  _result = result;
  _error = error;
  
  if (_receivedResultHandler) {
    _receivedResultHandler(_result, _error);
  }
  
  [self maybeInvokeCompletionHandler];
}

- (void)didReceiveUpdatesDone {
  self.updatesDone = YES;
}

- (void)didFlushUpdates {
  self.updatesFlushed = YES;
  [self maybeInvokeCompletionHandler];
}

- (void)maybeInvokeCompletionHandler {
  // Could be called from different threads because didFlushUpdates is called from a background queue
  @synchronized(self) {
    if (_completionHandlerInvoked) return;
    if (!(_resultReceived && _updatesFlushed)) return;
    
    if (_completionHandler) {
      _completionHandlerInvoked = YES;
      _completionHandler(_result, _error);
    }
    
    if (_executing) {
      [self finishOperation];
    }
  }
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
  METMethodInvocation *copy = [[[self class] allocWithZone:zone] init];
  copy.name = self.name;
  copy.client = _client;
  copy.methodID = _methodID;
  copy.methodName = _methodName;
  copy.parameters = _parameters;
  copy.randomSeed = _randomSeed;
  copy.barrier = _barrier;
  copy.receivedResultHandler = _receivedResultHandler;
  copy.completionHandler = _completionHandler;
  return copy;
}

@end
