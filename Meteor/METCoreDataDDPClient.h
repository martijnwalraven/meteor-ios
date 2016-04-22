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
#import <CoreData/CoreData.h>

#import "METDDPClient.h"
@class METIncrementalStore;
@class METDocumentKey;

NS_ASSUME_NONNULL_BEGIN

@interface METCoreDataDDPClient : METDDPClient

- (instancetype)initWithConnection:(METDDPConnection *)connection managedObjectModel:(NSManagedObjectModel *)managedObjectModel NS_DESIGNATED_INITIALIZER;

@property (strong, nonatomic, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (strong, nonatomic, readonly) NSManagedObjectModel *managedObjectModel;
@property (strong, nonatomic, readonly) METIncrementalStore *persistentStore;
@property (strong, nonatomic, readonly) NSManagedObjectContext *mainQueueManagedObjectContext;

- (NSManagedObjectID *)objectIDForDocumentKey:(METDocumentKey *)documentKey;
- (METDocumentKey *)documentKeyForObjectID:(NSManagedObjectID *)objectID;

@end

NS_ASSUME_NONNULL_END
