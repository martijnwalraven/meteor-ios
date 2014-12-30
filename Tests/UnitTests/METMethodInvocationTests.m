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

#import <XCTest/XCTest.h>

#import "METMethodInvocation.h"
#import "METMethodInvocation_Internal.h"

@interface METMethodInvocationTests : XCTestCase

@end

@implementation METMethodInvocationTests {
  METMethodInvocation *_methodInvocation;
}

- (void)setUp {
  [super setUp];
  
  _methodInvocation = [[METMethodInvocation alloc] init];
}

- (void)testInvokesReceivedResultHandlerAfterReceivingResult {
  __block BOOL receivedResultHandlerIsInvoked = NO;
  _methodInvocation.receivedResultHandler = ^(id result, NSError *error) {
    receivedResultHandlerIsInvoked = YES;
  };
  
  [_methodInvocation didReceiveResult:@"someResult" error:nil];
  
  XCTAssertTrue(receivedResultHandlerIsInvoked);
}

- (void)testInvokesCompletionHandlerAfterReceivingResultAndThenUpdatesFlushed {
  __block BOOL completionHandlerIsInvoked = NO;
  _methodInvocation.completionHandler = ^(id result, NSError *error) {
    completionHandlerIsInvoked = YES;
  };
  
  [_methodInvocation didReceiveResult:@"someResult" error:nil];
  
  XCTAssertFalse(completionHandlerIsInvoked);
  
  [_methodInvocation didFlushUpdates];
  
  XCTAssertTrue(completionHandlerIsInvoked);
}

- (void)testInvokesCompletionHandlerAfterReceivingUpdatesFlushedAndThenResult {
  __block BOOL completionHandlerIsInvoked = NO;
  _methodInvocation.completionHandler = ^(id result, NSError *error) {
    completionHandlerIsInvoked = YES;
  };
  
  [_methodInvocation didFlushUpdates];
  
  XCTAssertFalse(completionHandlerIsInvoked);
  
  [_methodInvocation didReceiveResult:@"someResult" error:nil];
  
  XCTAssertTrue(completionHandlerIsInvoked);
}

- (void)testInvokesCompletionHandlerWithReceivedResult {
  __block id resultFromCompletionHandler = nil;
  __block NSError *errorFromCompletionHandler = nil;
  _methodInvocation.completionHandler = ^(id result, NSError *error) {
    resultFromCompletionHandler = result;
    errorFromCompletionHandler = error;
  };
  
  [_methodInvocation didReceiveResult:@"someResult" error:nil];
  [_methodInvocation didFlushUpdates];
  
  XCTAssertEqualObjects(@"someResult", resultFromCompletionHandler);
  XCTAssertNil(errorFromCompletionHandler);
}

- (void)testInvokesCompletionHandlerWithReceivedError {
  __block id resultFromCompletionHandler = nil;
  __block NSError *errorFromCompletionHandler = nil;
  _methodInvocation.completionHandler = ^(id result, NSError *error) {
    resultFromCompletionHandler = result;
    errorFromCompletionHandler = error;
  };
  
  NSError *error = [NSError errorWithDomain:METDDPErrorDomain code:METDDPServerError userInfo:@{NSLocalizedDescriptionKey: @"Received error response from server", NSLocalizedFailureReasonErrorKey:@"bla"}];
  
  [_methodInvocation didReceiveResult:nil error:error];
  [_methodInvocation didFlushUpdates];
  
  XCTAssertNil(resultFromCompletionHandler);
  XCTAssertEqualObjects(error, errorFromCompletionHandler);
}

@end
