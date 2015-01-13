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

#import "NSString+METAdditions.h"

#import <CommonCrypto/CommonDigest.h>

@implementation NSString (METAdditions)

- (NSString *)MD5String {
  const char *cString = [self UTF8String];
  unsigned char digest[CC_MD5_DIGEST_LENGTH];
  CC_MD5(cString, (CC_LONG)strlen(cString), digest);
  return [self hexStringFromBytes:digest length:CC_MD5_DIGEST_LENGTH];
}

- (NSString *)SHA256String {
  const char *cString = [self UTF8String];
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(cString, (CC_LONG)strlen(cString), digest);
  return [self hexStringFromBytes:digest length:CC_SHA256_DIGEST_LENGTH];
}

#pragma mark - Helper Methods

// Convert unsigned char buffer to NSString of hex values
- (NSString *)hexStringFromBytes:(unsigned char *)bytes length:(int)length {
  NSMutableString *hexString = [[NSMutableString alloc] initWithCapacity:length * 2];
  for (int i = 0; i < length; i++) {
    [hexString appendFormat:@"%02x", bytes[i]];
  }
  return hexString;
}

@end
