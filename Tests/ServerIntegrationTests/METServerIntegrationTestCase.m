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

#import "METServerIntegrationTestCase.h"

@implementation METServerIntegrationTestCase {
  XCTestExpectation *_connectionEstablishedExpectation;
}

- (void)setUp {
  [super setUp];
  
  _client = [[METDDPClient alloc] initWithServerURL:[NSURL URLWithString:@"ws://localhost:3000/websocket"]];
  _client.delegate = self;
  
  _connectionEstablishedExpectation = [self expectationWithDescription:@"connection established"];
  [_client connect];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTestExpectation *serverResetExpectation = [self expectationWithDescription:@"server reset"];
  [_client callMethodWithName:@"reset" parameters:@[] completionHandler:^(id result, NSError *error) {
    [serverResetExpectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)tearDown {
  [super tearDown];
  
  _client.delegate = nil;
  [_client disconnect];
}

#pragma mark - METDDPClientDelegate

- (void)clientDidEstablishConnection:(METDDPClient *)client {
  [_connectionEstablishedExpectation fulfill];
  _connectionEstablishedExpectation = nil;
}

- (void)client:(METDDPClient *)client didFailWithError:(NSError *)error {
  XCTFail(@"Encountered DDP client error: %@", error);
}

@end
