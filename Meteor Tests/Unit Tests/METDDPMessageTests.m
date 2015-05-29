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

#import "METDDPMessage.h"

@interface METDDPMessageTests : XCTestCase

@end

@implementation METDDPMessageTests

- (void)testParseMessageFromData {
  NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"msg": @"added", @"collection": @"players", @"id": @"bla", @"fields": @{@"name": @"Ada Lovelace"}} options:0 error:nil];
  
  NSError *error;
  METDDPMessage *message = [[METDDPMessage alloc] initWithData:data error:&error];
  
  XCTAssertEqualObjects(@"added", message[@"msg"]);
  XCTAssertEqualObjects(@"players", message[@"collection"]);
  XCTAssertEqualObjects(@"bla", message[@"id"]);
  XCTAssertEqualObjects(@{@"name": @"Ada Lovelace"}, message[@"fields"]);
}

- (void)testParseMessageFromDataWithEJSON {
  NSDate *createdAt = [NSDate date];
  NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"fields": @{@"createdAt": @{@"$date": @([createdAt timeIntervalSince1970] * 1000)}, @"name": @"Ada Lovelace"}} options:0 error:nil];
  
  NSError *error;
  METDDPMessage *message = [[METDDPMessage alloc] initWithData:data error:&error];
  
  XCTAssertEqualObjects(@"Ada Lovelace", message[@"fields"][@"name"]);
  XCTAssertEqualWithAccuracy([createdAt timeIntervalSinceDate:message[@"fields"][@"createdAt"]], 0, 0.001);
}

@end
