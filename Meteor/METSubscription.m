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

#import "METSubscription.h"
#import "METSubscription_Internal.h"

@implementation METSubscription {
  METSubscriptionCompletionHandler _completionHandler;
  NSUInteger *_usageCount;
}

- (instancetype)initWithIdentifier:(NSString *)identifier name:(NSString *)name parameters:(id)parameters {
  self = [super init];
  if (self) {
    _identifier = [identifier copy];
    _name = [name copy];
    _parameters = [parameters copy];
  }
  return self;
}

- (void)didChangeStatus:(METSubscriptionStatus)status error:(NSError *)error {
  @synchronized(self) {
    _status = status;
    _error = error;
    if (_completionHandler) {
      _completionHandler(error);
      _completionHandler = nil;
    }
  }
}

- (BOOL)isReady {
  @synchronized(self) {
    return _status == METSubscriptionStatusReady;
  }
}

- (void)whenDone:(METSubscriptionCompletionHandler)completionHandler {
  NSParameterAssert(completionHandler);
  
  @synchronized(self) {
    // Invoke completion handler synchronously if we've already completed
    if (_status != METSubscriptionStatusPending) {
      if (completionHandler) {
        completionHandler(_error);
      }
    } else {
      METSubscriptionCompletionHandler existingCompletionHandler = _completionHandler;
      if (existingCompletionHandler) {
        _completionHandler = ^(NSError *error) {
          existingCompletionHandler(error);
          completionHandler(error);
        };
      } else {
        _completionHandler = completionHandler;
      }
    }
  }
}

#pragma mark - Usage Count

- (BOOL)isInUse {
  @synchronized(self) {
    return _usageCount > 0;
  }
}

- (void)beginUse {
  @synchronized(self) {
    _usageCount++;
  }
}

- (void)endUse {
  @synchronized(self) {
    _usageCount--;
  }
}

#pragma mark - NSObject

- (NSString *)description {
  return [NSString stringWithFormat:@"<METSubscription, identifier: %@, name: %@, parameters: %@>", _identifier, _name, _parameters];
}

@end
