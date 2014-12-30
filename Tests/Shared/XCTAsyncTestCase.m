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

#import "XCTAsyncTestCase.h"

#import "XCTFailure.h"

@implementation XCTAsyncTestCase {
  BOOL _bufferingFailures;
  NSMutableArray *_bufferedFailures;
}

- (void)waitForTimeInterval:(NSTimeInterval)timeInterval {
  NSDate *untilDate = [NSDate dateWithTimeIntervalSinceNow:timeInterval];
  
  while ([untilDate timeIntervalSinceNow] > 0) {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:untilDate];
  }
}

- (NSTimeInterval)waitUntilAssertionsPass:(void (^)())block {
  return [self waitWithTimeout:1.0 untilAssertionsPass:block];
}

- (NSTimeInterval)waitWithTimeout:(NSTimeInterval)timeout untilAssertionsPass:(void (^)())block {
  NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
  
  _bufferingFailures = YES;
  _bufferedFailures = [[NSMutableArray alloc] init];
  
  NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeout];
  
  while (({block(); (_bufferedFailures.count > 0);}) && [timeoutDate timeIntervalSinceNow] > 0) {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    [_bufferedFailures removeAllObjects];
  }
  
  for (XCTFailure *failure in _bufferedFailures) {
    [self recordFailure:failure];
  }
  
  _bufferingFailures = NO;
  _bufferedFailures = nil;
  
  NSTimeInterval endTime = [NSDate timeIntervalSinceReferenceDate];
  return endTime - startTime;
}

- (NSTimeInterval)waitWhileAssertionsPass:(void (^)())block {
  return [self waitWithTimeout:0.1 whileAssertionsPass:block];
}

- (NSTimeInterval)waitWithTimeout:(NSTimeInterval)timeout whileAssertionsPass:(void (^)())block {
  NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
  
  _bufferingFailures = YES;
  _bufferedFailures = [[NSMutableArray alloc] init];
  
  NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeout];
  
  while (({block(); (_bufferedFailures.count == 0);}) && [timeoutDate timeIntervalSinceNow] > 0) {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    [_bufferedFailures removeAllObjects];
  }
  
  for (XCTFailure *failure in _bufferedFailures) {
    [self recordFailure:failure];
  }
  
  _bufferingFailures = NO;
  _bufferedFailures = nil;
  
  NSTimeInterval endTime = [NSDate timeIntervalSinceReferenceDate];
  return endTime - startTime;
}

- (void)recordFailureWithDescription:(NSString *)description inFile:(NSString *)filename atLine:(NSUInteger) lineNumber expected:(BOOL)expected {
  if (_bufferingFailures) {
    XCTFailure *failure = [[XCTFailure alloc] initWithDescription:description inFile:filename atLine:lineNumber expected:expected];
    [_bufferedFailures addObject:failure];
  } else {
    [super recordFailureWithDescription:description inFile:filename atLine:lineNumber expected:expected];
  }
}

- (void)recordFailure:(XCTFailure *)failure {
  [super recordFailureWithDescription:failure.description inFile:failure.filename atLine:failure.lineNumber expected:failure.expected];
}

@end
