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
//  Alea PRNG implementation adapted from: https://github.com/nquinlan/better-random-numbers-for-javascript-mirror
//

#import "METAleaRandomValueGenerator.h"

const double norm32 = 2.3283064365386963e-10; // 2^-32

@implementation METAleaRandomValueGenerator  {
  double _s0, _s1, _s2;
  int _c;
}

- (instancetype)initWithSeeds:(NSArray *)seeds {
  self = [super init];
  if (self) {
    __block double n = 0xefc8249d;
    
    double (^mash)(NSString *) = ^double(NSString *string) {
      NSUInteger length = string.length;
      unichar characters[length];
      [string getCharacters:characters range:NSMakeRange(0, length)];
      
      for (int i = 0; i < length; i++) {
        n += characters[i];
        double h = 0.02519603282416938 * n;
        n = floor(h);
        h -= n;
        h *= n;
        n = floor(h);
        h -= n;
        n += h * 0x100000000ULL;
      }
      
      return floor(n) * 2.3283064365386963e-10; // 2^-32
    };
    
    _s0 = mash(@" ");
    _s1 = mash(@" ");
    _s2 = mash(@" ");
    
    for (__strong id seed in seeds) {
      if (![seed isKindOfClass:[NSString class]]) {
        if ([seed respondsToSelector:@selector(stringValue)]) {
          seed = [seed stringValue];
        } else {
          @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"METRandomNumberGenerator only supports strings or objects that implement stringValue as seeds" userInfo:nil];
        }
      }
      
      _s0 -= mash(seed);
      if (_s0 < 0.0) {
        _s0 += 1.0;
      }
      
      _s1 -= mash(seed);
      if (_s1 < 0.0) {
        _s1 += 1.0;
      }
      
      _s2 -= mash(seed);
      if (_s2 < 0.0) {
        _s2 += 1.0;
      }
    }
    _c = 1;
  }
    
  return self;
}

- (double)randomFraction {
  double t = 2091639.0 * _s0 + _c * norm32; // 2^-32
  _s0 = _s1;
  _s1 = _s2;
  return _s2 = t - (_c = t);
}

- (double)randomFractionWithPrecisionOf53Bits {
  return [self randomFraction] + floor([self randomFraction] * 0x200000) * 1.1102230246251565e-16; // 2^-53
}

- (NSUInteger)randomUnsignedInteger {
  return [self randomFraction] * 0x100000000; // 2^32
}

- (NSUInteger)randomIntegerLessThanInteger:(u_int32_t)upperBound {
  return floor([self randomFraction] * upperBound);
}

@end
