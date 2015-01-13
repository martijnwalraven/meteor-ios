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

#import "METDDPMessage.h"

#import "METEJSONSerialization.h"

static NSArray *EJSONTypedFields;

@implementation METDDPMessage {
  NSMutableDictionary *_fields;
}

+ (void)initialize {
  EJSONTypedFields = @[@"fields", @"params", @"result"];
}

- (instancetype)initWithData:(NSData *)data error:(NSError **)error {
  self = [super init];
  if (self) {
    _fields = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:error];
    if (!_fields) {
      return nil;
    }
    [self convertTypesFromEJSON];
  }
  return self;
}

- (id)objectForKeyedSubscript:(id)key {
  return [_fields objectForKeyedSubscript:key];
}

- (void)convertTypesFromEJSON {
  for (NSString *fieldName in EJSONTypedFields) {
    id EJSONObject = _fields[fieldName];
    if (EJSONObject) {
      _fields[fieldName] = [METEJSONSerialization objectFromEJSONObject:EJSONObject error:nil];
    }
  }
}

@end
