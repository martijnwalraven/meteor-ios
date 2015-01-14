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

#import "METAccount.h"

#import <SimpleKeychain/A0SimpleKeychain.h>

NSString * const METAccountKeychainItemName = @"MeteorAccount";

@implementation METAccount

#pragma mark - Class Methods

+ (instancetype)defaultAccount {
  A0SimpleKeychain *keychain = [self keychain];
  if (!keychain) return nil;
  NSData *data = [keychain dataForKey:METAccountKeychainItemName];
  if (!data) return nil;
  return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

+ (void)setDefaultAccount:(METAccount *)account {
  A0SimpleKeychain *keychain = [self keychain];
  if (!keychain) return;
  
  if (account) {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:account];
    [keychain setData:data forKey:METAccountKeychainItemName];
  } else {
    [keychain deleteEntryForKey:METAccountKeychainItemName];
  }
}

+ (A0SimpleKeychain *)keychain {
  NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
  if (!bundleIdentifier) return nil;
  return [A0SimpleKeychain keychainWithService:bundleIdentifier];
}

#pragma mark - Lifecycle

- (instancetype)initWithUserID:(NSString *)userID resumeToken:(NSString *)resumeToken expiryDate:(NSDate *)expiryDate {
  self = [super init];
  if (self) {
    _userID = [userID copy];
    _resumeToken = [resumeToken copy];
    _expiryDate = [expiryDate copy];
  }
  return self;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
  NSString *userID = [coder decodeObjectForKey:@"userID"];
  NSString *resumeToken = [coder decodeObjectForKey:@"resumeToken"];
  NSDate *expiryDate = [coder decodeObjectForKey:@"expiryDate"];
  
  return [self initWithUserID:userID resumeToken:resumeToken expiryDate:expiryDate];
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:_userID forKey:@"userID"];
  [coder encodeObject:_resumeToken forKey:@"resumeToken"];
  [coder encodeObject:_expiryDate forKey:@"expiryDate"];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
  return self;
}

@end
