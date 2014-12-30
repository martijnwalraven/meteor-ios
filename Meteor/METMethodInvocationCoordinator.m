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

#import "METMethodInvocationCoordinator.h"
#import "METMethodInvocationCoordinator_Testing.h"

#import "METDDPClient.h"
#import "METDDPClient_Internal.h"
#import "METMethodInvocation.h"
#import "METMethodInvocation_Internal.h"
#import "METRandomValueGenerator.h"
#import "METDatabase.h"
#import "METDatabase_Internal.h"
#import "METDatabaseChanges.h"
#import "METDatabaseChanges_Internal.h"
#import "METDocumentChangeDetails.h"
#import "METDocumentKey.h"
#import "METBufferedDocument.h"
#import "METDataUpdate.h"
#import "NSDictionary+METAdditions.h"

@interface METMethodInvocationCoordinator ()

@end

@implementation METMethodInvocationCoordinator {
  NSOperationQueue *_operationQueue;
  NSMutableDictionary *_methodInvocationsByMethodID;
  NSMutableDictionary *_bufferedDocumentsByKey;
}

- (instancetype)initWithClient:(METDDPClient *)client {
  self = [super init];
  if (self) {
    _client = client;
    
    _operationQueue = [[NSOperationQueue alloc] init];
    _operationQueue.suspended = YES;
    _methodInvocationsByMethodID = [[NSMutableDictionary alloc] init];
    _bufferedDocumentsByKey = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (BOOL)isSuspended {
  return _operationQueue.isSuspended;
}

- (void)setSuspended:(BOOL)suspended {
  _operationQueue.suspended = suspended;
}

- (void)addMethodInvocation:(METMethodInvocation *)methodInvocation {
  NSAssert(methodInvocation.queuePriority == NSOperationQueuePriorityNormal, @"Operation priorities not supported due to implementation of barrier semantics");
  
  NSString *methodID = methodInvocation.methodID;
  if (!methodID) {
    methodID = [[METRandomValueGenerator defaultRandomValueGenerator] randomIdentifier];
    methodInvocation.methodID = methodID;
  }
  _methodInvocationsByMethodID[methodID] = methodInvocation;
  methodInvocation.completionBlock = ^{
    [_methodInvocationsByMethodID removeObjectForKey:methodID];
  };
  
  for (METMethodInvocation *otherMethodInvocation in _operationQueue.operations.reverseObjectEnumerator) {
    if (otherMethodInvocation.barrier) {
      [methodInvocation addDependency:otherMethodInvocation];
      break;
    }
    if (methodInvocation.barrier) {
      [methodInvocation addDependency:otherMethodInvocation];
    }
  }
  
  [methodInvocation.changesPerformedByStub enumerateDocumentChangeDetailsUsingBlock:^(METDocumentChangeDetails *documentChangeDetails, BOOL *stop) {
    METDocumentKey *documentKey = documentChangeDetails.documentKey;
    METBufferedDocument *bufferedDocument = _bufferedDocumentsByKey[documentKey];
    if (!bufferedDocument) {
      bufferedDocument = [[METBufferedDocument alloc] init];
      bufferedDocument.fields = documentChangeDetails.fieldsBeforeChanges;
      _bufferedDocumentsByKey[documentKey] = bufferedDocument;
    }
    [bufferedDocument addMethodInvocationWaitingUntilUpdatesAreDone:methodInvocation];
  }];
  
  [_operationQueue addOperation:methodInvocation];
}

- (METMethodInvocation *)methodInvocationForMethodID:(NSString *)methodID {
  return _methodInvocationsByMethodID[methodID];
}

- (void)didReceiveResult:(id)result error:(NSError *)error forMethodID:(NSString *)methodID {
  METMethodInvocation *methodInvocation = [self methodInvocationForMethodID:methodID];
  if (!methodInvocation) {
    NSLog(@"Received result for unknown method ID: %@", methodID);
    return;
  }
  
  if (methodInvocation.resultReceived) {
    NSLog(@"Already received result for method ID: %@", methodID);
    return;
  }
  
  [methodInvocation didReceiveResult:result error:error];
}

- (void)didReceiveUpdatesDoneForMethodID:(NSString *)methodID {
  METMethodInvocation *methodInvocation = [self methodInvocationForMethodID:methodID];
  if (!methodInvocation) {
    NSLog(@"Received updates done for unknown method ID: %@", methodID);
    return;
  }
  
  if (methodInvocation.updatesDone) {
    NSLog(@"Already received updates done for method ID: %@", methodID);
    return;
  }
  
  [methodInvocation didReceiveUpdatesDone];
  
  [methodInvocation.changesPerformedByStub enumerateDocumentChangeDetailsUsingBlock:^(METDocumentChangeDetails *documentChangeDetails, BOOL *stop) {
    METDocumentKey *documentKey = documentChangeDetails.documentKey;
    METBufferedDocument *bufferedDocument = _bufferedDocumentsByKey[documentKey];
    
    [bufferedDocument removeMethodInvocationWaitingUntilUpdatesAreDone:methodInvocation];
    
    if (bufferedDocument.numberOfSentMethodInvocationsWaitingUntilUpdatesAreDone < 1) {
      METDataUpdate *update;
      if (bufferedDocument.fields) {
        update = [[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeReplace documentKey:documentKey fields:bufferedDocument.fields];
      } else {
        update = [[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeRemove documentKey:documentKey fields:nil];
      }
      [_client.database applyDataUpdate:update];
      [_bufferedDocumentsByKey removeObjectForKey:documentKey];
      [bufferedDocument didFlush];
    }
  }];
  
  [self performAfterAllCurrentlyBufferedDocumentsAreFlushed:^{
    [methodInvocation didFlushUpdates];
  }];
}

- (void)performAfterAllCurrentlyBufferedDocumentsAreFlushed:(void (^)())block {
  dispatch_group_t group = dispatch_group_create();
  [_bufferedDocumentsByKey enumerateKeysAndObjectsUsingBlock:^(METDocumentKey *documentKey, METBufferedDocument *bufferedDocument, BOOL *stop) {
    [bufferedDocument waitUntilFlushedWithGroup:group];
  }];
  dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    [_client.database performAfterBufferedUpdatesAreFlushed:block];
  });
}

- (void)resetWhileAddingMethodInvocationsToTheFrontOfTheQueueUsingBlock:(void (^)())block {
  NSArray *methodInvocations = [_operationQueue.operations copy];
  [_operationQueue cancelAllOperations];
  [_bufferedDocumentsByKey removeAllObjects];
  
  if (block) {
    block();
  }
  
  for (METMethodInvocation *methodInvocation in methodInvocations) {
    if (!methodInvocation.resultReceived) {
      [self addMethodInvocation:[methodInvocation copy]];
    } else if (!methodInvocation.updatesFlushed) {
      [_client.database performAfterBufferedUpdatesAreFlushed:^{
        [methodInvocation didFlushUpdates];
      }];
    }
  }
}

- (BOOL)isBufferingDocumentWithKey:(METDocumentKey *)
documentKey {
  return _bufferedDocumentsByKey[documentKey] != nil;
}

- (void)applyDataUpdate:(METDataUpdate *)update {
  METBufferedDocument *bufferedDocument = _bufferedDocumentsByKey[update.documentKey];
  NSAssert(bufferedDocument, @"Should only apply data updates to method invocation coordinator when currently tracking document");
  
  switch (update.updateType) {
    case METDataUpdateTypeAdd:
      if (bufferedDocument.fields != nil) {
        NSLog(@"Couldn't add document because a document with the same key already exists: %@", update.documentKey);
        return;
      }
      bufferedDocument.fields = update.fields;
      break;
    case METDataUpdateTypeChange:
      if (bufferedDocument.fields == nil) {
        NSLog(@"Couldn't update document because no document with the specified ID exists: %@", update.documentKey);
        return;
      }
      bufferedDocument.fields = [bufferedDocument.fields fieldsByApplyingChangedFields:update.fields];
      break;
    case METDataUpdateTypeReplace:
      bufferedDocument.fields = update.fields;
      break;
    case METDataUpdateTypeRemove:
      if (bufferedDocument.fields == nil) {
        NSLog(@"Couldn't remove document because no document with the specified ID exists: %@", update.documentKey);
      }
      bufferedDocument.fields = nil;
      break;
  }
}

#pragma mark - Testing

- (METMethodInvocation *)lastMethodInvocation {
  return [_operationQueue.operations lastObject];
}

- (METMethodInvocation *)methodInvocationWithName:(NSString *)name {
  for (METMethodInvocation *methodInvocation in _operationQueue.operations) {
    if ([methodInvocation.name isEqualToString:name]) {
      return methodInvocation;
    }
  }
  return nil;
}

- (METBufferedDocument *)bufferedDocumentForKey:(METDocumentKey *)documentKey {
  return _bufferedDocumentsByKey[documentKey];
}

@end
