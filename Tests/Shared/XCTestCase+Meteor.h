// Copyright (c) 2014 Martijn Walraven
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

#import <XCTest/XCTest.h>

@class METDatabase;
@class METDocumentKey;
@class METDatabaseChanges;
#import "METDocumentChangeDetails.h"

#define METAssertContainsEqualObjects(expression1, expression2, ...) \
_XCTPrimitiveAssertEqualObjects(self, [NSSet setWithArray:expression1], @#expression1, [NSSet setWithArray:expression2], @#expression2, __VA_ARGS__)

@interface XCTestCase (Meteor)

- (void)verifyDatabase:(METDatabase *)database containsDocumentWithKey:(METDocumentKey *)documentKey fields:(NSDictionary *)fields;

- (XCTestExpectation *)expectationForDatabaseDidChangeNotificationWithHandler:(BOOL (^)(METDatabaseChanges *databaseChanges))handler;

- (XCTestExpectation *)expectationForChangeToDocumentWithKey:(METDocumentKey *)documentKey changeType:(METDocumentChangeType)changeType changedFields:(NSDictionary *)changedFields;

- (void)verifyDatabaseChanges:(METDatabaseChanges *)databaseChanges containsChangeToDocumentWithKey:(METDocumentKey *)documentKey changeType:(METDocumentChangeType)changeType changedFields:(NSDictionary *)fields;

- (void)performBlockWhileNotExpectingDatabaseDidChangeNotification:(void (^)())block;

@end
