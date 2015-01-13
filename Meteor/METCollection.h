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

@class METDatabase;
@class METDocument;

@interface METCollection : NSObject

- (instancetype)initWithName:(NSString *)name database:(METDatabase *)database NS_DESIGNATED_INITIALIZER;
- (instancetype)init __attribute__((unavailable("Use -initWithName:database: instead")));
@property (copy, nonatomic, readonly) NSString *name;
@property (weak, nonatomic) METDatabase *database;

@property (nonatomic, readonly, copy) NSArray *allDocuments;
- (METDocument *)documentWithID:(id)documentID;

- (id)insertDocumentWithID:(id)documentID fields:(NSDictionary *)fields;
- (id)insertDocumentWithID:(id)documentID fields:(NSDictionary *)fields completionHandler:(METMethodCompletionHandler)completionHandler;

- (id)insertDocumentWithFields:(NSDictionary *)fields;
- (id)insertDocumentWithFields:(NSDictionary *)fields completionHandler:(METMethodCompletionHandler)completionHandler;

- (id)updateDocumentWithID:(id)documentID changedFields:(NSDictionary *)fields;
- (id)updateDocumentWithID:(id)documentID changedFields:(NSDictionary *)fields completionHandler:(METMethodCompletionHandler)completionHandler;

- (id)removeDocumentWithID:(id)documentID;
- (id)removeDocumentWithID:(id)documentID completionHandler:(METMethodCompletionHandler)completionHandler;

@end
