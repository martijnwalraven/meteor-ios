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

#import "METDDPHeartbeat.h"

@interface METDDPHeartbeatTests : XCTAsyncTestCase <METDDPHeartbeatDelegate>

@end

@implementation METDDPHeartbeatTests {
  METDDPHeartbeat *_heartbeat;
  BOOL _timeoutReceived;
  BOOL _wantsToSendPingReceived;
}

- (void)setUp {
  [super setUp];
  
  _heartbeat = [[METDDPHeartbeat alloc] initWithQueue:dispatch_get_main_queue()];
  _heartbeat.delegate = self;
}

- (void)testCallsWantsToSendPingOnDelegateAfterPingInterval {
  _heartbeat.pingInterval = 0.2;
  
  [_heartbeat start];
  
  NSTimeInterval waitTime = [self waitUntilAssertionsPass:^{
    XCTAssertTrue(_wantsToSendPingReceived);
  }];
  
  XCTAssertEqualWithAccuracy(0.2, waitTime, 0.1);
}

- (void)testCallsDidTimeoutOnDelegateAfterTimeoutInterval {
  _heartbeat.timeoutInterval = 0.2;
  
  [_heartbeat start];
  
  [self waitUntilAssertionsPass:^{
    XCTAssertTrue(_wantsToSendPingReceived);
  }];
  
  NSTimeInterval waitTime = [self waitUntilAssertionsPass:^{
    XCTAssertTrue(_timeoutReceived);
  }];
  
  XCTAssertEqualWithAccuracy(0.2, waitTime, 0.1);
}

- (void)testResetsPingTimerWhenPingIsReceived {
  _heartbeat.pingInterval = 0.2;
  
  [_heartbeat start];
  
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [_heartbeat didReceivePing];
  });
  
  NSTimeInterval waitTime = [self waitUntilAssertionsPass:^{
    XCTAssertTrue(_wantsToSendPingReceived);
  }];
  
  XCTAssertEqualWithAccuracy(0.2 + 0.1, waitTime, 0.1);
}

- (void)testStopsTimeoutTimerWhenPongIsReceived {
  _heartbeat.timeoutInterval = 0.2;
  
  [_heartbeat start];
  
  [self waitUntilAssertionsPass:^{
    XCTAssertTrue(_wantsToSendPingReceived);
  }];
  
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [_heartbeat didReceivePong];
  });
  
  NSTimeInterval waitTime = [self waitUntilAssertionsPass:^{
    XCTAssertTrue(_timeoutReceived);
  }];
  
  XCTAssertEqualWithAccuracy(0.2 + 0.1, waitTime, 0.1);
}

- (void)testDoesNotStopTimeoutTimerWhenPingIsReceived {
  _heartbeat.pingInterval = 0.2;
  _heartbeat.timeoutInterval = 0.2;
  
  [_heartbeat start];
  
  [self waitUntilAssertionsPass:^{
    XCTAssertTrue(_wantsToSendPingReceived);
  }];
  
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [_heartbeat didReceivePing];
  });
  
  NSTimeInterval waitTime = [self waitUntilAssertionsPass:^{
    XCTAssertTrue(_timeoutReceived);
  }];
  
  XCTAssertEqualWithAccuracy(0.2, waitTime, 0.1);
}

- (void)testResetsPingTimerWhenPongIsReceived {
  _heartbeat.pingInterval = 0.2;
  _heartbeat.timeoutInterval = 0.2;
  
  [_heartbeat start];
  
  [self waitUntilAssertionsPass:^{
    XCTAssertTrue(_wantsToSendPingReceived);
  }];
  _wantsToSendPingReceived = NO;
  
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [_heartbeat didReceivePong];
  });
  
  NSTimeInterval waitTime = [self waitUntilAssertionsPass:^{
    XCTAssertTrue(_wantsToSendPingReceived);
  }];
  
  XCTAssertEqualWithAccuracy(0.2 + 0.1, waitTime, 0.1);
}

- (void)testStopsPingTimerWhenStopping {
  _heartbeat.pingInterval = 0.1;
  
  [_heartbeat start];
  
  [self waitUntilAssertionsPass:^{
    XCTAssertTrue(_wantsToSendPingReceived);
  }];
  _wantsToSendPingReceived = NO;
  
  [_heartbeat didReceivePong];

  [_heartbeat stop];
  
  [self waitWhileAssertionsPass:^{
    XCTAssertFalse(_wantsToSendPingReceived);
  }];
}

- (void)testStopsTimeoutTimerWhenStopping {
  _heartbeat.timeoutInterval = 0.1;
  
  [_heartbeat start];
  
  [self waitUntilAssertionsPass:^{
    XCTAssertTrue(_wantsToSendPingReceived);
  }];
  
  [_heartbeat stop];
  
  [self waitWhileAssertionsPass:^{
    XCTAssertFalse(_timeoutReceived);
  }];
}

#pragma mark - METDDPHeartbeatDelegate

- (void)heartbeatWantsToSendPing:(METDDPHeartbeat *)heartbeat {
  _wantsToSendPingReceived = YES;
}

- (void)heartbeatDidTimeout:(METDDPHeartbeat *)heartbeat {
  _timeoutReceived = YES;
}

@end
