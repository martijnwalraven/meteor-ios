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
#import "METDDPClientTestCase.h"
#import <OCMock/OCMock.h>

#import "METDDPClient.h"
#import "METDDPClient_Internal.h"

#import "MockMETDDPConnection.h"

@interface METDDPClientConnectingTests : METDDPClientTestCase

@end

@implementation METDDPClientConnectingTests {
}

- (void)setUp {
  [super setUp];
}

- (void)testConnectingWithMatchingProtocolVersion {
  [_client connect];
  [_connection receiveMessage:@{@"msg": @"connected", @"session": @"oPnaPF5M5Bsz46XcA"}];
  
  XCTAssertTrue(_client.connected);
  XCTAssertEqualObjects(_client.protocolVersion, @"1");
  XCTAssertEqualObjects(@"oPnaPF5M5Bsz46XcA", _client.sessionID);
}

- (void)testConnectingWithServerRequestingOtherSupportedProtocolVersionReconnects {
  [_client connect];
  
  [self expectationForConnectMessageWithProtocolVersion:@"pre1"];
  
  [_connection receiveMessage:@{@"msg": @"failed", @"version": @"pre1"}];
  [_connection close];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertFalse(_client.connected);
}

- (void)testConnectingWithServerRequestingUnsupportedProtocolVersionDoesntReconnect {
  [_client connect];
  
  [self keyValueObservingExpectationForObject:_client keyPath:@"connectionStatus" expectedValue:[NSNumber numberWithInteger:METDDPConnectionStatusFailed]];
  
  [_connection receiveMessage:@{@"msg": @"failed", @"version": @"bla"}];
  [_connection close];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];

  XCTAssertFalse(_client.connected);
}

- (void)testEncounteringErrorWhileConnectingRetriesLater {
  [_client connect];
  
  [self keyValueObservingExpectationForObject:_client keyPath:@"connectionStatus" expectedValue:[NSNumber numberWithInteger:METDDPConnectionStatusWaiting]];
  
  [_client connection:_connection didFailWithError:nil];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testEncounteringConnectionCloseWhileConnectingRetriesLater {
  [_client connect];
  
  [self keyValueObservingExpectationForObject:_client keyPath:@"connectionStatus" expectedValue:[NSNumber numberWithInteger:METDDPConnectionStatusWaiting]];
  
  [_connection close];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testEncounteringErrorWhileConnectingDoesNotRetryIfNetworkIsNotReachable {
  id networkReachabilityManager = OCMClassMock([METNetworkReachabilityManager class]);
  _client.networkReachabilityManager = networkReachabilityManager;
  
  OCMStub([networkReachabilityManager reachabilityStatus]).andReturn(METNetworkReachabilityStateNotReachable);
  
  [_client connect];
  
  [self keyValueObservingExpectationForObject:_client keyPath:@"connectionStatus" expectedValue:[NSNumber numberWithInteger:METDDPConnectionStatusOffline]];
  
  [_client connection:_connection didFailWithError:nil];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testEncounteringConnectionCloseWhileConnectingDoesNotRetryIfNetworkIsNotReachable {
  id networkReachabilityManager = OCMClassMock([METNetworkReachabilityManager class]);
  _client.networkReachabilityManager = networkReachabilityManager;
  
  OCMStub([networkReachabilityManager reachabilityStatus]).andReturn(METNetworkReachabilityStateNotReachable);
  
  [_client connect];
  
  [self keyValueObservingExpectationForObject:_client keyPath:@"connectionStatus" expectedValue:[NSNumber numberWithInteger:METDDPConnectionStatusOffline]];
  
  [_client connection:_connection didFailWithError:nil];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testEncounteringErrorWhileConnectedRetriesLater {
  [self establishConnection];
  
  [self keyValueObservingExpectationForObject:_client keyPath:@"connectionStatus" expectedValue:[NSNumber numberWithInteger:METDDPConnectionStatusWaiting]];
  
  [_client connection:_connection didFailWithError:nil];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testEncounteringConnectionCloseWhileConnectedRetriesLater {
  [self establishConnection];
  
  [self keyValueObservingExpectationForObject:_client keyPath:@"connectionStatus" expectedValue:[NSNumber numberWithInteger:METDDPConnectionStatusWaiting]];
  
  [_connection close];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testConnectIfNetworkBecomesReachableWhileOffline {
  id networkReachabilityManager = OCMClassMock([METNetworkReachabilityManager class]);
  _client.networkReachabilityManager = networkReachabilityManager;
  
  OCMStub([networkReachabilityManager reachabilityStatus]).andReturn(METNetworkReachabilityStateReachable);
  
  [self keyValueObservingExpectationForObject:_client keyPath:@"connectionStatus" expectedValue:[NSNumber numberWithInteger:METDDPConnectionStatusConnecting]];
  
  [_client networkReachabilityManager:networkReachabilityManager didDetectReachabilityStatusChange:METNetworkReachabilityStateReachable];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testRespondWithPongMessageAfterReceivingPingMessage {
  [self expectationForSentMessage:@{@"msg": @"pong", @"id": @1}];

  [_connection receiveMessage:@{@"msg": @"ping", @"id": @1}];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testReceivingErrorMessageInvokesDidFailWithErrorDelegateMethod {
  id delegate = OCMProtocolMock(@protocol(METDDPClientDelegate));
  _client.delegate = delegate;
  
  NSError *expectedError = [NSError errorWithDomain:METDDPErrorDomain code:METDDPServerError userInfo:@{NSLocalizedDescriptionKey: @"Received error message from server", NSLocalizedFailureReasonErrorKey: @"bla"}];
  OCMExpect([delegate client:_client didFailWithError:expectedError]);
  
  [_connection receiveMessage:@{@"msg": @"error", @"reason": @"bla"}];
  
  OCMVerifyAll(delegate);
}

#pragma mark - Helper Methods

- (XCTestExpectation *)expectationForConnectMessageWithProtocolVersion:(NSString *)protocolVersion {
  return [self expectationForSentMessageWithHandler:^BOOL(NSDictionary *message) {
    return [message[@"msg"] isEqualToString:@"connect"] && [message[@"version"] isEqualToString:protocolVersion] && [message[@"support"] containsObject:protocolVersion];
  }];
}

@end
