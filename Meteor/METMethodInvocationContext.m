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

#import "METMethodInvocationContext.h"

#import "METRandomStream.h"
#import "METRandomValueGenerator.h"

@implementation METMethodInvocationContext

- (instancetype)initWithMethodName:(NSString *)methodName enclosingMethodInvocationContext:(METMethodInvocationContext *)enclosingMethodInvocationContext {
  self = [super init];
  if (self) {
    _methodName = [methodName copy];
    _enclosingMethodInvocationContext = enclosingMethodInvocationContext;
  }
  return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
  METMethodInvocationContext *methodInvocationContext = [[self class] allocWithZone:zone];
  methodInvocationContext.userID = self.userID;
  return methodInvocationContext;
}

- (METRandomStream *)randomStream {
  if (!_randomStream) {
    METRandomValueGenerator *generator;
    if (_enclosingMethodInvocationContext) {
      generator = [_enclosingMethodInvocationContext.randomStream sequenceWithName:[NSString stringWithFormat:@"/rpc/%@", _methodName]];
    } else {
      generator = [METRandomValueGenerator defaultRandomValueGenerator];
    }
    
    _randomSeed = [generator randomSeed];
    _randomStream = [[METRandomStream alloc] initWithSeeds:@[_randomSeed]];
  }
  
  return _randomStream;
}

@end
