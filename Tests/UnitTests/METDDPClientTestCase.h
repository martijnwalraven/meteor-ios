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

#import <XCTest/XCTest.h>
#import "XCTAsyncTestCase.h"
#import "XCTestCase+Meteor.h"

@class METDDPClient;
@class MockMETDDPConnection;
@class METMethodInvocation;
@class METSubscription;

@interface METDDPClientTestCase : XCTAsyncTestCase {
@protected
  METDDPClient *_client;
  MockMETDDPConnection *_connection;
}

- (void)establishConnection;

- (XCTestExpectation *)expectationForSentMessageWithHandler:(BOOL (^)(NSDictionary *message))handler;
- (XCTestExpectation *)expectationForSentMessage:(NSDictionary *)expectedMessage;

- (XCTestExpectation *)expectationForSentMessageForMethodWithName:(NSString *)methodName;
- (XCTestExpectation *)expectationForSentMessageForMethodWithName:(NSString *)methodName parameters:(NSArray *)parameters;
- (XCTestExpectation *)expectationForSentMessageForMethodInvocation:(METMethodInvocation *)methodInvocation;

- (XCTestExpectation *)expectationForSentSubMessageForSubscription:(METSubscription *)subscription;

- (void)whileNotExpectingSentMessageWithHandler:(BOOL (^)(NSDictionary *message))handler performBlock:(void (^)())block;

- (NSString *)lastMethodID;
- (METMethodInvocation *)lastMethodInvocation;
- (METMethodInvocation *)methodInvocationWithName:(NSString *)methodName;

@end
