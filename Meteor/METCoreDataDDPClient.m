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

#import "METCoreDataDDPClient.h"

#import "METDDPClient_Internal.h"
#import "METIncrementalStore.h"
#import "METDocumentKey.h"
#import "NSArray+METAdditions.h"

@implementation METCoreDataDDPClient {
}

#pragma mark - Lifecycle

- (instancetype)initWithConnection:(METDDPConnection *)connection {
  return [self initWithConnection:connection managedObjectModel:[NSManagedObjectModel mergedModelFromBundles:nil]];
}

- (instancetype)initWithConnection:(METDDPConnection *)connection managedObjectModel:(NSManagedObjectModel *)managedObjectModel {
  self = [super initWithConnection:connection];
  if (self) {
    NSError *error = nil;
    
    _managedObjectModel = managedObjectModel;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_managedObjectModel];
    
    _persistentStore = (METIncrementalStore *)[_persistentStoreCoordinator addPersistentStoreWithType:[METIncrementalStore type] configuration:nil URL:nil options:nil error:&error];
    if (!_persistentStore) {
      NSLog(@"Failed adding persistent store: %@", error);
      abort();
    }
    _persistentStore.client = self;
    
    _mainQueueManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    _mainQueueManagedObjectContext.persistentStoreCoordinator = _persistentStoreCoordinator;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(objectsDidChange:) name:METIncrementalStoreObjectsDidChangeNotification object:_persistentStore];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSArray *)convertParameters:(NSArray *)parameters {
  return [parameters mappedArrayUsingBlock:^id(id parameter) {
    if ([parameter isKindOfClass:[NSManagedObject class]]) {
      NSManagedObject *managedObject = (NSManagedObject *)parameter;
      parameter = [self documentKeyForObjectID:managedObject.objectID].documentID;
    } else if ([parameter isKindOfClass:[NSManagedObjectID class]]) {
      NSManagedObjectID *managedObjectID = (NSManagedObjectID *)parameter;
      parameter = [self documentKeyForObjectID:managedObjectID].documentID;
    }
    return parameter;
  }];
}

- (NSManagedObjectID *)objectIDForDocumentKey:(METDocumentKey *)documentKey {
  return [_persistentStore objectIDForDocumentKey:documentKey];
}

- (METDocumentKey *)documentKeyForObjectID:(NSManagedObjectID *)objectID {
  return [_persistentStore documentKeyForObjectID:objectID];
}

#pragma mark - Notifications

- (void)objectsDidChange:(NSNotification *)notification {
  [_mainQueueManagedObjectContext performBlock:^{
    // NSLog(@"objectsDidChange, inserted: %lu, updated: %lu, deleted: %lu", (unsigned long)[notification.userInfo[NSInsertedObjectsKey] count], (unsigned long)[notification.userInfo[NSUpdatedObjectsKey] count], (unsigned long)[notification.userInfo[NSDeletedObjectsKey] count]);
    // NSLog(@"objectsDidChange, inserted: %@, updated: %@, deleted: %@", notification.userInfo[NSInsertedObjectsKey], notification.userInfo[NSUpdatedObjectsKey], notification.userInfo[NSDeletedObjectsKey]);
    
    // Use NSPersistentStoreDidImportUbiquitousContentChangesNotification to allow object IDs in the userInfo for mergeChangesFromContextDidSaveNotification
    [_mainQueueManagedObjectContext mergeChangesFromContextDidSaveNotification:[[NSNotification alloc] initWithName:NSPersistentStoreDidImportUbiquitousContentChangesNotification object:notification.object userInfo:notification.userInfo]];
  }];
}

@end
