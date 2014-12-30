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
#import "XCTAsyncTestCase.h"

#import "METTimer.h"

@interface METTimerTests : XCTAsyncTestCase

@end

@implementation METTimerTests {
}

- (void)setUp {
  [super setUp];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testTimerFiresAfterTimeoutIntervalWhenStarted {
  __block BOOL timerFired = NO;
  METTimer *timer = [[METTimer alloc] initWithQueue:dispatch_get_main_queue() block:^void() {
    timerFired = YES;
  }];
  
  [timer startWithTimeInterval:0.2];
  
  NSTimeInterval waitTime = [self waitUntilAssertionsPass:^{
    XCTAssertTrue(timerFired);
  }];
  XCTAssertEqualWithAccuracy(0.2, waitTime, 0.1);
}

- (void)testTimerOnlyFiresOnceWhenStarted {
  __block NSUInteger numberOfTimesTimerFired = 0;
  METTimer *timer = [[METTimer alloc] initWithQueue:dispatch_get_main_queue() block:^void() {
    numberOfTimesTimerFired++;
  }];
  
  [timer startWithTimeInterval:0.1];
  
  [self waitForTimeInterval:0.3];
  
  XCTAssertEqual(1, numberOfTimesTimerFired);
}

- (void)testTimerCanBeStopped {
  __block BOOL timerFired = NO;
  METTimer *timer = [[METTimer alloc] initWithQueue:dispatch_get_main_queue() block:^void() {
    timerFired = YES;
  }];
  
  [timer startWithTimeInterval:0.3];
  
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [timer stop];
  });
  
  [self waitWhileAssertionsPass:^{
    XCTAssertFalse(timerFired);
  }];
}

- (void)testTimerCanBeRestartedAfterFiring {
  __block NSUInteger numberOfTimesTimerFired = 0;
  METTimer *timer = [[METTimer alloc] initWithQueue:dispatch_get_main_queue() block:^void() {
    numberOfTimesTimerFired++;
  }];
  
  [timer startWithTimeInterval:0.1];
  
  [self waitUntilAssertionsPass:^{
    XCTAssertEqual(1, numberOfTimesTimerFired);
  }];
  
  [timer startWithTimeInterval:0.1];
  
  NSTimeInterval waitTime = [self waitUntilAssertionsPass:^{
    XCTAssertEqual(2, numberOfTimesTimerFired);
  }];
  XCTAssertEqualWithAccuracy(0.1, waitTime, 0.1);
}

- (void)testTimerCanBeRestartedAfterBeingStopped {
  __block NSUInteger numberOfTimesTimerFired = 0;
  METTimer *timer = [[METTimer alloc] initWithQueue:dispatch_get_main_queue() block:^void() {
    numberOfTimesTimerFired++;
  }];
  
  [timer startWithTimeInterval:0.2];
  
  [self waitForTimeInterval:0.1];
  [timer stop];
  
  [self waitForTimeInterval:0.3];
  
  [timer startWithTimeInterval:0.2];
  
  NSTimeInterval waitTime = [self waitUntilAssertionsPass:^{
    XCTAssertEqual(1, numberOfTimesTimerFired);
  }];
  XCTAssertEqualWithAccuracy(0.2, waitTime, 0.1);
}

- (void)testTimerCanBeResetByStartingItAgain {
  __block NSUInteger numberOfTimesTimerFired = 0;
  METTimer *timer = [[METTimer alloc] initWithQueue:dispatch_get_main_queue() block:^void() {
    numberOfTimesTimerFired++;
  }];
  
  [timer startWithTimeInterval:0.2];

  [self waitForTimeInterval:0.1];
  
  [timer startWithTimeInterval:0.2];
  
  NSTimeInterval waitTime = [self waitUntilAssertionsPass:^{
    XCTAssertEqual(1, numberOfTimesTimerFired);
  }];
  XCTAssertEqualWithAccuracy(0.2, waitTime, 0.1);
}

@end
