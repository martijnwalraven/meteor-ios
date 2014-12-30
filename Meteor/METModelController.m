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

#import "METModelController.h"

#import "METIncrementalStore.h"
#import "METDocumentKey.h"

static METModelController *_sharedModelController;

@implementation METModelController {
  METIncrementalStore *_incrementalStore;
}

#pragma mark - Singleton

+ (instancetype)sharedModelController {
	return _sharedModelController;
}

+ (void)setSharedModelController:(METModelController *)modelController {
  _sharedModelController = modelController;
}

#pragma mark - Lifecycle

- (instancetype)initWithServerURL:(NSURL *)serverURL {
  self = [super init];
  if (self) {
    _serverURL = [serverURL copy];
    
    NSError *error = nil;
    
    _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_managedObjectModel];
    
    _incrementalStore = (METIncrementalStore *)[_persistentStoreCoordinator addPersistentStoreWithType:[METIncrementalStore type] configuration:nil URL:serverURL options:nil error:&error];
    if (!_incrementalStore) {
      NSLog(@"Failed adding persistent store: %@", error);
      abort();
    }
    
    _mainQueueManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    _mainQueueManagedObjectContext.persistentStoreCoordinator = _persistentStoreCoordinator;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(objectsDidChange:) name:METIncrementalStoreObjectsDidChangeNotification object:_incrementalStore];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (METDDPClient *)client {
  return _incrementalStore.client;
}

- (id)documentIDForObjectID:(NSManagedObjectID *)objectID {
  return [_incrementalStore documentKeyForObjectID:objectID].documentID;
}

#pragma mark - Notifications

- (void)objectsDidChange:(NSNotification *)notification {
  [_mainQueueManagedObjectContext performBlock:^{
    // Use NSPersistentStoreDidImportUbiquitousContentChangesNotification to allow object IDs in the userInfo for mergeChangesFromContextDidSaveNotification
    [_mainQueueManagedObjectContext mergeChangesFromContextDidSaveNotification:[[NSNotification alloc] initWithName:NSPersistentStoreDidImportUbiquitousContentChangesNotification object:notification.object userInfo:notification.userInfo]];
  }];
}

@end
