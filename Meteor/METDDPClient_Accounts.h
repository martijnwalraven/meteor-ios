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

#import "METDDPClient.h"

@interface METDDPClient ()

/**
 * Performs login via the given methodName. The completion handler callback exposes the login response
 * body to the caller to allow for more flexibility in a custom meteor login.
 */
- (void)methodLoginWithMethodName:(NSString *)methodName parameters:(NSArray *)parameters completionHandler:(METMethodCompletionHandler)completionHandler;

/**
 * Performs login via the given methodName. Takes a traditional `METLogInCompletionHandler` to be
 * informed only whether the login has succeeded or failed.
 */
- (void)loginWithMethodName:(NSString *)methodName parameters:(NSArray *)parameters completionHandler:(METLogInCompletionHandler)completionHandler;

@end