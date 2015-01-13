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

#import "METEJSONSerialization.h"

@interface METEJSONSerializationTests : XCTestCase

@end

@implementation METEJSONSerializationTests

- (void)testObjectFromEJSONObjectConvertsDate {
  NSDate *date = [NSDate date];
  id EJSONObject = @{@"$date": @(floor([date timeIntervalSince1970] * 1000.0))};
  
  NSError *error;
  NSDate *convertedDate = [METEJSONSerialization objectFromEJSONObject:EJSONObject error:&error];
  
  XCTAssertEqualWithAccuracy([date timeIntervalSinceDate:convertedDate], 0, 0.001);
  XCTAssertNil(error);
}

- (void)testObjectFromEJSONObjectConvertDateWithoutNumberOfMillisecondsReturnsNilAndError {
  id EJSONObject = @{@"$date": @"bla"};
  
  NSError *error;
  NSDate *convertedDate = [METEJSONSerialization objectFromEJSONObject:EJSONObject error:&error];
  XCTAssertNil(convertedDate);
  XCTAssertNotNil(error);
}

- (void)testObjectFromEJSONObjectConvertsBinaryData {
  NSData *data = [self randomData];
  id EJSONObject = @{@"$binary": [data base64EncodedStringWithOptions:0]};
  
  NSError *error;
  NSData *convertedData = [METEJSONSerialization objectFromEJSONObject:EJSONObject error:&error];
  
  XCTAssertEqualObjects(data, convertedData);
  XCTAssertNil(error);
}

- (void)testObjectFromEJSONObjectConvertBinaryDataWithoutStringReturnsNilAndError {
  id EJSONObject = @{@"$binary": @1};
  
  NSError *error;
  NSData *convertedData = [METEJSONSerialization objectFromEJSONObject:EJSONObject error:&error];
  XCTAssertNil(convertedData);
  XCTAssertNotNil(error);
}

- (void)testObjectFromEJSONObjectConvertsEscapedValues {
  id EJSONObject = @{@"$escape": @{@"$date": @10000}};
  
  NSError *error;
  NSData *convertedObject = [METEJSONSerialization objectFromEJSONObject:EJSONObject error:&error];
  
  XCTAssertEqualObjects(@{@"$date": @10000}, convertedObject);
  XCTAssertNil(error);
}

- (void)testObjectFromEJSONObjectConvertsObjectsNestedInDictionaries {
  id EJSONObject = @{@"createdAt": @{@"$date": @(floor([[NSDate date] timeIntervalSince1970] * 1000.0))}};
  
  NSError *error;
  NSDictionary *object = [METEJSONSerialization objectFromEJSONObject:EJSONObject error:&error];
  XCTAssertTrue([object[@"createdAt"] isKindOfClass:[NSDate class]]);
  XCTAssertNil(error);
}

- (void)testObjectFromEJSONObjectConvertsObjectsNestedInArrays {
  id EJSONObject = @[@{@"$date": @(floor([[NSDate date] timeIntervalSince1970] * 1000.0))}];
  
  NSError *error;
  NSArray *object = [METEJSONSerialization objectFromEJSONObject:EJSONObject error:&error];
  XCTAssertTrue([object[0] isKindOfClass:[NSDate class]]);
  XCTAssertNil(error);
}

- (void)testEJSONObjectFromObjectConvertsDate {
  NSDate *date = [NSDate date];
  
  NSError *error;
  id EJSONObject = [METEJSONSerialization EJSONObjectFromObject:date error:&error];
  
  XCTAssertEqualObjects(@{@"$date": @(floor([date timeIntervalSince1970] * 1000.0))}, EJSONObject);
  XCTAssertNil(error);
}

- (void)testEJSONObjectFromObjectConvertsBinaryData {
  NSData *data = [self randomData];
  
  NSError *error;
  id EJSONObject = [METEJSONSerialization EJSONObjectFromObject:data error:&error];
  
  XCTAssertEqualObjects(@{@"$binary": [data base64EncodedStringWithOptions:0]}, EJSONObject);
  XCTAssertNil(error);
}

- (void)testEJSONObjectFromObjectEscapesValuesIfNecessary {
  id object = @{@"$date": @10000};

  NSError *error;
  id EJSONObject = [METEJSONSerialization EJSONObjectFromObject:object error:&error];
  
  XCTAssertEqualObjects(@{@"$escape": @{@"$date": @10000}}, EJSONObject);
  XCTAssertNil(error);
}

- (void)testEJSONObjectFromObjectOnlyEscapesValuesOneLevelDown {
  NSDate *date = [NSDate date];
  id object = @{@"$date": date};
  
  NSError *error;
  id EJSONObject = [METEJSONSerialization EJSONObjectFromObject:object error:&error];
  
  XCTAssertEqualObjects(@{@"$escape": @{@"$date": [METEJSONSerialization EJSONObjectFromObject:date error:&error]}}, EJSONObject);
  XCTAssertNil(error);
}

- (void)testEJSONObjectFromObjectConvertsObjectsNestedInDictionaries {
  id object = @{@"createdAt": [NSDate date]};
  
  NSError *error;
  NSDictionary *EJSONObject = [METEJSONSerialization EJSONObjectFromObject:object error:&error];
  XCTAssertTrue([EJSONObject[@"createdAt"] isKindOfClass:[NSDictionary class]]);
  XCTAssertNil(error);
}

- (void)testEJSONObjectFromObjectConvertsObjectsNestedInArrays {
  id object = @[[NSDate date]];
  
  NSError *error;
  NSArray *EJSONObject = [METEJSONSerialization EJSONObjectFromObject:object error:&error];
  XCTAssertTrue([EJSONObject[0] isKindOfClass:[NSDictionary class]]);
  XCTAssertNil(error);
}

#pragma mark - Helper Methods

- (NSData *)randomData {
  NSMutableData *data = [NSMutableData dataWithLength:1024];
  arc4random_buf([data mutableBytes], data.length);
  return data;
}

@end
