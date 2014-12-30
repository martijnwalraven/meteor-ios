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

#import "METDynamicVariable.h"

@interface METDynamicVariableTests : XCTestCase

@end

@implementation METDynamicVariableTests

- (void)testGettingCurrentValueInBlock {
  METDynamicVariable *variable = [[METDynamicVariable alloc] init];
  
  __block id valueInBlock;
  
  [variable performBlock:^{
    valueInBlock = [variable currentValue];
  } withValue:@"value"];
  
  XCTAssertEqualObjects(@"value", valueInBlock);
}

- (void)testGettingCurrentValueAfterBlock {
  METDynamicVariable *variable = [[METDynamicVariable alloc] init];
  
  [variable performBlock:^{
  } withValue:@"value"];
  
  XCTAssertNil([variable currentValue]);
}

- (void)testGettingCurrentValueInNestedBlock {
  METDynamicVariable *variable = [[METDynamicVariable alloc] init];
  
  __block id valueInNestedBlock;
  
  [variable performBlock:^{
    [variable performBlock:^{
      valueInNestedBlock = [variable currentValue];
    } withValue:@"anotherValue"];
  } withValue:@"originalValue"];
  
  XCTAssertEqualObjects(@"anotherValue", valueInNestedBlock);
}

- (void)testGettingCurrentValueAfterNestedBlock {
  METDynamicVariable *variable = [[METDynamicVariable alloc] init];
  
  __block id valueAfterNestedBlock;
  
  [variable performBlock:^{
    [variable performBlock:^{
    } withValue:@"anotherValue"];
    valueAfterNestedBlock = [variable currentValue];
  } withValue:@"originalValue"];
  
  XCTAssertEqualObjects(@"originalValue", valueAfterNestedBlock);
}

@end
