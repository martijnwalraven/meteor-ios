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

#import "METAleaRandomValueGenerator.h"

@interface METAleaRandomValueGeneratorTests : XCTestCase

@end

@implementation METAleaRandomValueGeneratorTests

- (void)testGeneratingFractionsFromAleaReadme {
  METAleaRandomValueGenerator *generator = [[METAleaRandomValueGenerator alloc] initWithSeeds:@[@"my", @3, @"seeds"]];
  
  XCTAssertEqual([generator randomFraction], 0.30802189325913787);
  XCTAssertEqual([generator randomFraction], 0.5190450621303171);
  XCTAssertEqual([generator randomFraction], 0.43635262292809784);
}

- (void)testGeneratingFractionsWithPrecisionOf53BitsFromAleaReadme {
  METAleaRandomValueGenerator *generator = [[METAleaRandomValueGenerator alloc] initWithSeeds:@[@""]];
  
  XCTAssertEqual([generator randomFractionWithPrecisionOf53Bits], 0.16665777435687268);
  XCTAssertEqual([generator randomFractionWithPrecisionOf53Bits], 0.00011322738143160205);
  XCTAssertEqual([generator randomFractionWithPrecisionOf53Bits], 0.17695781631176488);
}

- (void)testGeneratingUnsignedIntegersFromAleaReadme {
  METAleaRandomValueGenerator *generator = [[METAleaRandomValueGenerator alloc] initWithSeeds:@[@""]];
  
  XCTAssertEqual([generator randomUnsignedInteger], 715789690);
  XCTAssertEqual([generator randomUnsignedInteger], 2091287642);
  XCTAssertEqual([generator randomUnsignedInteger], 486307);
}

- (void)testGeneratingIdentifiersFromMeteorTests {
  METAleaRandomValueGenerator *generator = [[METAleaRandomValueGenerator alloc] initWithSeeds:@[@0]];
  
  XCTAssertEqualObjects([generator randomIdentifier], @"cp9hWvhg8GSvuZ9os");
  XCTAssertEqualObjects([generator randomIdentifier], @"3f3k6Xo7rrHCifQhR");
  XCTAssertEqualObjects([generator randomIdentifier], @"shxDnjWWmnKPEoLhM");
  XCTAssertEqualObjects([generator randomIdentifier], @"6QTjB8C5SEqhmz4ni");
}

- (void)testGeneratingFractionsWithSeedsThatTriggeredAleaImplementationBug {
  METAleaRandomValueGenerator *generator = [[METAleaRandomValueGenerator alloc] initWithSeeds:@[@"8d5ad9d4598e8e59a023", @"/collection/players"]];
  
  NSArray *expectedValues = @[@(0.8605355687905103), @(0.5996392285451293), @(0.15409872471354902), @(0.7570449074264616), @(0.796773984329775), @(0.902753145666793), @(0.6531996221747249), @(0.5401782251428813), @(0.6872373721562326), @(0.8049655579961836), @(0.8429777375422418), @(0.49012255552224815), @(0.3550962624140084), @(0.1123671333771199), @(0.45232052775099874), @(0.19145806250162423), @(0.4786627166904509), @(0.2563992936629802), @(0.15061311377212405), @(0.6061689376365393)];
  
  NSMutableArray *actualValues = [[NSMutableArray alloc] init];
  for (int i = 0; i < expectedValues.count; i++) {
    [actualValues addObject:@([generator randomFraction])];
  }
  
  XCTAssertEqualObjects(actualValues, expectedValues);
}

- (void)testGeneratingFractionsWithSeedsThatTriggeredAnotherAleaImplementationBug {
  METAleaRandomValueGenerator *generator = [[METAleaRandomValueGenerator alloc] initWithSeeds:@[@"843ab55fd732dd06788f", @"/collection/players"]];
  
  NSArray *expectedValues = @[@(0.8768236360047013), @(0.2696537037845701), @(0.07896713959053159), @(0.5135481869801879), @(0.20375726534985006), @(0.7490173205733299), @(0.4163055098615587), @(0.6429891916923225), @(0.8394859083928168), @(0.8407060902100056), @(0.27012487733736634), @(0.4662579770665616), @(0.6462295935489237), @(0.7287184733431786), @(0.36902507580816746), @(0.021048143738880754), @(0.9791797650977969)];
  
  NSMutableArray *actualValues = [[NSMutableArray alloc] init];
  for (int i = 0; i < expectedValues.count; i++) {
    [actualValues addObject:@([generator randomFraction])];
  }
  
  XCTAssertEqualObjects(actualValues, expectedValues);
}

@end
