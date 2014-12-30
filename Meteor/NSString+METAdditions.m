//
//  Copyright 2014 Martijn Walraven. All rights reserved.
//

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
