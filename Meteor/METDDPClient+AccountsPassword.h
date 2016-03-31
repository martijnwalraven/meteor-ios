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

#import <Foundation/Foundation.h>

#import "METDDPClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface METDDPClient (AccountsPassword)

/// @name Logging In with Password

- (void)loginWithEmail:(NSString *)email password:(NSString *)password completionHandler:(nullable METLogInCompletionHandler)completionHandler;

/// @name Logging In with Parameters (e.g. Facebook Token, needs custom login handler on server side)
- (void)loginWithMethodName:(NSString *)methodName parameters:(nullable NSArray *)parameters completionHandler:(nullable METLogInCompletionHandler)completionHandler;

/// @name Signing Up with Password

- (void)signUpWithEmail:(NSString *)email password:(NSString *)password completionHandler:(nullable METLogInCompletionHandler)completionHandler;

- (void)signUpWithEmail:(NSString *)email password:(NSString *)password firstName:(NSString *)firstName lastName:(NSString *)lastName completionHandler:(nullable METLogInCompletionHandler)completionHandler;

- (void)signUpWithEmail:(NSString *)email password:(NSString *)password profile:(nullable NSDictionary *)profile completionHandler:(nullable METLogInCompletionHandler)completionHandler;

@end

NS_ASSUME_NONNULL_END
