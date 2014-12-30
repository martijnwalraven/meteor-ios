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

#import "METRetryStrategy.h"

@interface METRetryStrategyTests : XCTestCase

@end

@implementation METRetryStrategyTests {
  METRetryStrategy *_retryStrategy;
}

- (void)setUp {
  [super setUp];
  
  _retryStrategy = [[METRetryStrategy alloc] init];
}

- (void)testSpecifyingANumberOfAttemptsAtMinimumTimeInterval {
  _retryStrategy.minimumTimeInterval = 0.1;
  _retryStrategy.numberOfAttemptsAtMinimumTimeInterval = 2;
  
  for (NSUInteger numberOfAttempts = 0; numberOfAttempts < _retryStrategy.numberOfAttemptsAtMinimumTimeInterval; numberOfAttempts++) {
    NSTimeInterval timeInterval = [_retryStrategy retryIntervalForNumberOfAttempts:numberOfAttempts];
    XCTAssertEqual(_retryStrategy.minimumTimeInterval, timeInterval);
  }
}

- (void)testSpecifyingZeroNumberOfAttemptsAtMinimumTimeInterval {
  _retryStrategy.minimumTimeInterval = 0.1;
  _retryStrategy.numberOfAttemptsAtMinimumTimeInterval = 0;
  
  NSTimeInterval timeInterval = [_retryStrategy retryIntervalForNumberOfAttempts:1];
  XCTAssertNotEqual(_retryStrategy.minimumTimeInterval, timeInterval);
}

- (void)testUsesExponentialBackoffForAttemptsAfterNumberOfAttemptsAtMinimumTimeInterval {
  _retryStrategy.minimumTimeInterval = 0.1;
  _retryStrategy.numberOfAttemptsAtMinimumTimeInterval = 2;
  _retryStrategy.baseTimeInterval = 1;
  _retryStrategy.exponent = 2.2;
  
  for (NSUInteger numberOfAttempts = 2; numberOfAttempts < 10; numberOfAttempts++) {
    NSTimeInterval timeInterval = [_retryStrategy retryIntervalForNumberOfAttempts:numberOfAttempts];
    XCTAssertEqual(_retryStrategy.baseTimeInterval * pow(_retryStrategy.exponent, numberOfAttempts), timeInterval);
  }
}

- (void)testCapsResultsByMaximumTimeInterval {
  _retryStrategy.minimumTimeInterval = 0.1;
  _retryStrategy.numberOfAttemptsAtMinimumTimeInterval = 2;
  _retryStrategy.baseTimeInterval = 1;
  _retryStrategy.exponent = 2.2;
  _retryStrategy.maximumTimeInterval = 5 * 60;
  
  for (NSUInteger numberOfAttempts = 1; numberOfAttempts < 10; numberOfAttempts++) {
    NSTimeInterval timeInterval = [_retryStrategy retryIntervalForNumberOfAttempts:numberOfAttempts];
    XCTAssert(timeInterval <= _retryStrategy.maximumTimeInterval);
  }
}

- (void)testSpecifyingARandomizationFactor {
  _retryStrategy.minimumTimeInterval = 0.1;
  _retryStrategy.numberOfAttemptsAtMinimumTimeInterval = 2;
  _retryStrategy.baseTimeInterval = 1;
  _retryStrategy.exponent = 2.2;
  _retryStrategy.randomizationFactor = 0.5;
  
  for (NSUInteger numberOfAttempts = 2; numberOfAttempts < 10; numberOfAttempts++) {
    NSTimeInterval timeInterval = [_retryStrategy retryIntervalForNumberOfAttempts:numberOfAttempts];
    NSTimeInterval preciseTimeInterval = _retryStrategy.baseTimeInterval * pow(_retryStrategy.exponent, numberOfAttempts);
    XCTAssertEqualWithAccuracy(preciseTimeInterval, timeInterval, (_retryStrategy.randomizationFactor / 2) * preciseTimeInterval);
  }
}

@end
