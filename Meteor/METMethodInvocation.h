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
@class METDatabaseChanges;

@interface METMethodInvocation : NSOperation <NSCopying>

@property (weak, nonatomic) METDDPClient *client;
@property (copy, nonatomic) NSString *methodID;
@property (copy, nonatomic) NSString *methodName;
@property (strong, nonatomic) id parameters;
@property (copy, nonatomic) NSString *randomSeed;
@property (assign, nonatomic, getter=isBarrier) BOOL barrier;

@property (copy, nonatomic) METMethodCompletionHandler receivedResultHandler;
@property (copy, nonatomic) METMethodCompletionHandler completionHandler;

@property (strong, nonatomic) METDatabaseChanges *changesPerformedByStub;

@property (assign, nonatomic, readonly) BOOL messageSent;

@property (assign, nonatomic, readonly) BOOL resultReceived;
@property (strong, nonatomic, readonly) id result;
@property (strong, nonatomic, readonly) NSError *error;

@property (assign, nonatomic, readonly) BOOL updatesDone;
@property (assign, nonatomic, readonly) BOOL updatesFlushed;

@end
