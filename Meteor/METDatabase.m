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

#import "METDatabase.h"
#import "METDatabase_Internal.h"

#import "METDocumentCache.h"
#import "METCollection.h"
#import "METCollection_Internal.h"
#import "METDataUpdate.h"
#import "METDatabaseChanges.h"
#import "METDatabaseChanges_Internal.h"
#import "NSDictionary+METAdditions.h"

NSString * const METDatabaseDidChangeNotification = @"METDatabaseDidChangeNotification";
NSString * const METDatabaseChangesKey = @"METDatabaseChangesKey";

@interface METDatabase () <METDocumentCacheDelegate>

@end

@implementation METDatabase {
  NSDictionary *_collectionsByName;
  
  NSRecursiveLock *_writeLock;
  NSUInteger _writeLockRecursionCount;
  
  METDocumentCache *_localCache;
  
  BOOL _trackingChanges;
  METDatabaseChanges *_currentChanges;
  METDatabaseChanges *_changes;
  
  dispatch_queue_t _dataUpdatesQueue;
  NSMutableArray *_bufferedDataUpdates;
  dispatch_source_t _bufferedDataUpdatesSource;
  dispatch_block_t _pendingAfterFlushBlock;
  BOOL _removeExistingDocumentsBeforeNextFlush;
}

- (instancetype)initWithClient:(METDDPClient *)client {
  self = [super init];
  if (self) {
    _client = client;
    _collectionsByName = [[NSDictionary alloc] init];
    
    _writeLock = [[NSRecursiveLock alloc] init];
    _writeLock.name = @"com.meteor.Database.writeLock";
    
    _localCache = [[METDocumentCache alloc] init];
    _localCache.delegate = self;
    
    _trackingChanges = YES;
    _changes = [[METDatabaseChanges alloc] init];

    _dataUpdatesQueue = dispatch_queue_create("com.meteor.Database.dataUpdatesQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_set_target_queue(_dataUpdatesQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
    _bufferedDataUpdates = [[NSMutableArray alloc] init];
    
    _bufferedDataUpdatesSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_DATA_ADD, 0, 0, _dataUpdatesQueue);
    dispatch_source_set_event_handler(_bufferedDataUpdatesSource, ^{
      [self flushDataUpdatesOnQueue];
    });
    dispatch_resume(_bufferedDataUpdatesSource);
  }
  return self;
}

- (NSArray *)executeFetchRequest:(METFetchRequest *)fetchRequest {
  return [_localCache executeFetchRequest:fetchRequest];
}

- (METDocument *)documentWithKey:(METDocumentKey *)documentKey {
  return [_localCache documentWithKey:documentKey];
}

- (void)enumerateCollectionsUsingBlock:(void (^)(METCollection *collection, BOOL *stop))block {
  [_collectionsByName enumerateKeysAndObjectsUsingBlock:^(NSString *collectionName, METCollection *collection, BOOL *stop) {
    block(collection, stop);
  }];
}

- (METCollection *)collectionWithName:(NSString *)collectionName {
  NSDictionary *collectionsByName = _collectionsByName;
  METCollection *collection = collectionsByName[collectionName];
  if (!collection) {
    // As an optimization, _collectionsByName is immutable so we only need to lock when a new collection has to be created, and replace the dictionary completely instead of mutating it
    @synchronized(collectionsByName) {
      // Make sure no other thread has replaced the dictionary while we were waiting
      if (_collectionsByName != collectionsByName) {
        // If so, try again with the new dictionary
        return [self collectionWithName:collectionName];
      }
      collection = [[METCollection alloc] initWithName:collectionName database:self];
      _collectionsByName = [_collectionsByName dictionaryByAddingObject:collection forKey:collectionName];
    }
  }
  return collection;
}

- (void)applyDataUpdate:(METDataUpdate *)update {
  dispatch_async(_dataUpdatesQueue, ^{
    [_bufferedDataUpdates addObject:update];
    dispatch_source_merge_data(_bufferedDataUpdatesSource, 1);
  });
}

- (void)flushDataUpdates {
  dispatch_sync(_dataUpdatesQueue, ^{
    [self flushDataUpdatesOnQueue];
  });
}

- (void)flushDataUpdatesOnQueue {
  NSAssert(!_waitingForQuiescence, @"flushDataUpdates invoked while waiting for quiescence");
  
  [self performUpdatesInLocalCache:^(METDocumentCache *localCache) {
    if (_removeExistingDocumentsBeforeNextFlush) {
      [_localCache removeAllDocuments];
      _removeExistingDocumentsBeforeNextFlush = NO;
    }
    
    for (METDataUpdate *update in _bufferedDataUpdates) {
      [localCache applyDataUpdate:update];
    }
    [_bufferedDataUpdates removeAllObjects];
  }];
  
  if (_pendingAfterFlushBlock) {
    _pendingAfterFlushBlock();
    _pendingAfterFlushBlock = nil;
  }
}

- (void)performAfterBufferedUpdatesAreFlushed:(void (^)())block {
  dispatch_async(_dataUpdatesQueue, ^{
    if (_bufferedDataUpdates.count > 0) {
      dispatch_block_t existingPendingAfterFlushBlock = _pendingAfterFlushBlock;
      if (existingPendingAfterFlushBlock) {
        _pendingAfterFlushBlock = ^{
          existingPendingAfterFlushBlock();
          block();
        };
      } else {
        _pendingAfterFlushBlock = block;
      }
    } else {
      block();
    }
  });
}

- (void)setWaitingForQuiescence:(BOOL)waitingForQuiescence {
  if (_waitingForQuiescence != waitingForQuiescence) {
    _waitingForQuiescence = waitingForQuiescence;
    if (waitingForQuiescence) {
      dispatch_suspend(_bufferedDataUpdatesSource);
    } else {
      dispatch_resume(_bufferedDataUpdatesSource);
    }
  }
}

- (void)performUpdates:(void (^)())block {
  [_writeLock lock];
  _writeLockRecursionCount++;
  
  block();
  
  if (_writeLockRecursionCount == 1) {
    [self postDidChangeNotificationIfNeeded];
  }
  
  _writeLockRecursionCount--;
  [_writeLock unlock];
}

- (METDatabaseChanges *)performUpdatesAndReturnChanges:(void (^)())block {
  NSAssert(_currentChanges == nil, @"performUpdatesAndReturnChanges: is not reentrant");
  
  METDatabaseChanges *changes = [[METDatabaseChanges alloc] init];
  _currentChanges = changes;
  
  [self performUpdates:^{
    if (!_waitingForQuiescence) {
      [self flushDataUpdates];
    }
    
    block();
    
    [_changes addDatabaseChanges:changes];
    _currentChanges = nil;
  }];
  
  return changes;
}

- (void)performUpdatesInLocalCache:(void (^)(METDocumentCache *localCache))block {
  [self performUpdates:^{
    block(_localCache);
  }];
}

- (void)performUpdatesInLocalCacheWithoutTrackingChanges:(void (^)(METDocumentCache *localCache))block {
  [self performUpdatesInLocalCache:^(METDocumentCache *localCache) {
    _trackingChanges = NO;
    block(localCache);
    _trackingChanges = YES;
  }];
}

- (void)reset {
  [self performUpdatesInLocalCache:^(METDocumentCache *localCache) {
    [_bufferedDataUpdates removeAllObjects];
    _pendingAfterFlushBlock = nil;
    _removeExistingDocumentsBeforeNextFlush = YES;
  }];
}

#pragma mark - METDocumentCacheDelegate

- (void)documentCache:(METDocumentCache *)cache willChangeDocumentWithKey:(METDocumentKey *)documentKey fieldsBeforeChanges:(NSDictionary *)fieldsBeforeChanges {
  if (_trackingChanges) {
    METDatabaseChanges *changes = _currentChanges ? _currentChanges : _changes;
    [changes willChangeDocumentWithKey:documentKey fieldsBeforeChanges:fieldsBeforeChanges];
  }
}

- (void)documentCache:(METDocumentCache *)cache didChangeDocumentWithKey:(METDocumentKey *)documentKey fieldsAfterChanges:(NSDictionary *)fieldsAfterChanges {
  if (_trackingChanges) {
    METDatabaseChanges *changes = _currentChanges ? _currentChanges : _changes;
    [changes didChangeDocumentWithKey:documentKey fieldsAfterChanges:fieldsAfterChanges];
  }
}

#pragma mark - Change Notifications

- (void)postDidChangeNotificationIfNeeded {
  METDatabaseChanges *databaseChanges = _changes;
  if ([databaseChanges hasChanges]) {
    _changes = [[METDatabaseChanges alloc] init];

    NSDictionary *userInfo = @{METDatabaseChangesKey: databaseChanges};
    [[NSNotificationCenter defaultCenter] postNotificationName:METDatabaseDidChangeNotification object:self userInfo:userInfo];
  }
}

@end
