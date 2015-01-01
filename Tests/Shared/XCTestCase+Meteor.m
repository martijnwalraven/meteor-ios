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

#import "XCTestCase+Meteor.h"

#import "METDatabase.h"
#import "METDocument.h"
#import "METDocumentKey.h"
#import "METDatabaseChanges.h"
#import "METDocumentChangeDetails.h"

@implementation XCTestCase (Meteor)

- (void)verifyDatabase:(METDatabase *)database containsDocumentWithKey:(METDocumentKey *)documentKey fields:(NSDictionary *)fields {
  METDocument *document = [database documentWithKey:documentKey];
  XCTAssertNotNil(document, @"Expected local document set to contain document with key %@", documentKey);
  XCTAssertEqualObjects(documentKey,  document.key);
  XCTAssertEqualObjects(fields, document.fields);
}

- (void)verifyDatabaseChanges:(METDatabaseChanges *)databaseChanges containsChangeToDocumentWithKey:(METDocumentKey *)documentKey changeType:(METDocumentChangeType)changeType changedFields:(NSDictionary *)fields {
  METDocumentChangeDetails *documentChangeDetails = [databaseChanges changeDetailsForDocumentWithKey:documentKey];
  XCTAssertNotNil(documentChangeDetails, @"Expected database changes to contain change details for document with key %@", documentKey);
  XCTAssertEqual(changeType, documentChangeDetails.changeType);
  XCTAssertEqualObjects(fields, documentChangeDetails.changedFields);
}

- (XCTestExpectation *)expectationForDatabaseDidChangeNotificationWithHandler:(BOOL (^)(METDatabaseChanges *databaseChanges))handler {
  return [self expectationForNotification:METDatabaseDidChangeNotification object:nil handler:^BOOL(NSNotification *notification) {
    METDatabaseChanges *databaseChanges = notification.userInfo[METDatabaseChangesKey];
    if (databaseChanges) {
      if (handler) {
        return handler(databaseChanges);
      } else {
        return YES;
      }
    } else {
      return NO;
    }
  }];
}

- (XCTestExpectation *)expectationForChangeToDocumentWithKey:(METDocumentKey *)documentKey changeType:(METDocumentChangeType)changeType changedFields:(NSDictionary *)changedFields {
  return [self expectationForDatabaseDidChangeNotificationWithHandler:^BOOL(METDatabaseChanges *databaseChanges) {
    [self verifyDatabaseChanges:databaseChanges containsChangeToDocumentWithKey:documentKey changeType:changeType changedFields:changedFields];
    return YES;
  }];
}

- (void)performBlockWhileNotExpectingDatabaseDidChangeNotification:(void (^)())block {
  id observer = [[NSNotificationCenter defaultCenter] addObserverForName:METDatabaseDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *notification) {
    XCTFail(@"Should not post database did change notification");
  }];
  
  block();
  
  [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

@end
