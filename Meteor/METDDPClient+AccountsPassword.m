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

#import "METDDPClient+AccountsPassword.h"
#import "METDDPClient_Internal.h"

#import "NSString+METAdditions.h"

@implementation METDDPClient (AccountsPassword)

- (void)loginWithEmail:(NSString *)email password:(NSString *)password completionHandler:(METLogInCompletionHandler)completionHandler {
  [self loginWithMethodName:@"login" parameters:@[@{@"user": @{@"email": email}, @"password": @{@"digest": [password SHA256String], @"algorithm": @"sha-256"}}] completionHandler:completionHandler];
}

- (void)signUpWithEmail:(NSString *)email password:(NSString *)password completionHandler:(METLogInCompletionHandler)completionHandler {
  [self loginWithMethodName:@"createUser" parameters:@[[self parametersForCreateUserMethodFromEmail:email password:password]] completionHandler:completionHandler];
}

- (void)signUpWithEmail:(NSString *)email password:(NSString *)password firstName:(NSString *)firstName lastName:(NSString *)lastName completionHandler:(METLogInCompletionHandler)completionHandler {
  [self loginWithMethodName:@"createUser" parameters:@[[self parametersForCreateUserMethodFromEmail:email password:password firstName:firstName lastName:lastName]] completionHandler:completionHandler];
}

#pragma mark - Helper Methods

- (NSDictionary *)parametersForCreateUserMethodFromEmail:(NSString *)email password:(NSString *)password
{
  return [self parametersForCreateUserMethodFromEmail:email password:password firstName:nil lastName:nil];
}

- (NSDictionary *)parametersForCreateUserMethodFromEmail:(NSString *)email password:(NSString *)password firstName:(NSString *)firstName lastName:(NSString *)lastName {
  // build the base parameters body with email/password
  NSDictionary *params =  @{@"email": email, @"password": @{@"digest": [password SHA256String], @"algorithm": @"sha-256"}};
  
  // if we have a firstName or last name, include it include the `profile` object
  if (firstName || lastName) {
    NSMutableDictionary *profileParams = [NSMutableDictionary dictionary];
    firstName ? profileParams[@"first_name"] = firstName : nil;
    lastName ? profileParams[@"last_name"] = lastName : nil;
    
    NSMutableDictionary *mutableParams = [params mutableCopy];
    mutableParams[@"profile"] = profileParams;
    params = mutableParams;
  }
  
  return params;
}

@end
