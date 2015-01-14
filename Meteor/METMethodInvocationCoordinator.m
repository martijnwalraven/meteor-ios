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

#import "METMethodInvocationCoordinator.h"
#import "METMethodInvocationCoordinator_Testing.h"

#import "METDDPClient.h"
#import "METDDPClient_Internal.h"
#import "METMethodInvocation.h"
#import "METMethodInvocation_Internal.h"
#import "METMethodInvocationContext.h"
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
#import "METDynamicVariable.h"

@interface METMethodInvocationCoordinator ()

@end

@implementation METMethodInvocationCoordinator {
  NSMutableDictionary *_methodStubsByName;
  METDynamicVariable *_methodInvocationContextDynamicVariable;
  NSOperationQueue *_operationQueue;
  NSMutableDictionary *_methodInvocationsByMethodID;
  NSMutableDictionary *_bufferedDocumentsByKey;
}

- (instancetype)initWithClient:(METDDPClient *)client {
  self = [super init];
  if (self) {
    _client = client;
    
    _methodStubsByName = [[NSMutableDictionary alloc] init];
    _methodInvocationContextDynamicVariable = [[METDynamicVariable alloc] init];
    _operationQueue = [[NSOperationQueue alloc] init];
    _operationQueue.suspended = YES;
    _methodInvocationsByMethodID = [[NSMutableDictionary alloc] init];
    _bufferedDocumentsByKey = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (void)defineStubForMethodWithName:(NSString *)methodName usingBlock:(METMethodStub)stub {
  @synchronized(self) {
    _methodStubsByName[methodName] = [stub copy];
  }
}

- (id)callMethodWithName:(NSString *)methodName parameters:(NSArray *)parameters options:(METMethodCallOptions)options receivedResultHandler:(METMethodCompletionHandler)receivedResultHandler completionHandler:(METMethodCompletionHandler)completionHandler {
  @synchronized(self) {
    METMethodInvocationContext *enclosingMethodInvocationContext = [_methodInvocationContextDynamicVariable currentValue];
    BOOL alreadyInSimulation = enclosingMethodInvocationContext != nil;
    
    METMethodStub stub = _methodStubsByName[methodName];
    __block id resultFromStub;
    
    if (!alreadyInSimulation) {
      METMethodInvocation *methodInvocation = [[METMethodInvocation alloc] init];
      methodInvocation.client = _client;
      methodInvocation.methodName = methodName;
      methodInvocation.parameters = parameters;
      // Setting NSOperation name can be useful for debug purposes
      methodInvocation.name = parameters ? [NSString stringWithFormat:@"%@(%@)", methodName, parameters] : methodName;
      methodInvocation.barrier = options & METMethodCallOptionsBarrier;
      methodInvocation.receivedResultHandler = receivedResultHandler;
      methodInvocation.completionHandler = completionHandler;
      
      if (stub) {
        METMethodInvocationContext *methodInvocationContext = [[METMethodInvocationContext alloc] initWithMethodName:methodName enclosingMethodInvocationContext:nil];
        
        [_methodInvocationContextDynamicVariable performBlock:^{
          METDatabaseChanges *changesPerformedByStub = [_client.database performUpdatesAndReturnChanges:^{
            NSArray *deepCopyOfParameters = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:parameters]];
            resultFromStub = stub(deepCopyOfParameters);
          }];
          methodInvocation.changesPerformedByStub = changesPerformedByStub;
        } withValue:methodInvocationContext];
        
        methodInvocation.randomSeed = methodInvocationContext.randomSeed;
      }
      
      [self addMethodInvocation:methodInvocation];
    } else if (stub) {
      METMethodInvocationContext *methodInvocationContext = [[METMethodInvocationContext alloc] initWithMethodName:methodName enclosingMethodInvocationContext:enclosingMethodInvocationContext];
      
      [_methodInvocationContextDynamicVariable performBlock:^{
        resultFromStub = stub(parameters);
      } withValue:methodInvocationContext];
    }
    
    if (alreadyInSimulation || (options & METMethodCallOptionsReturnStubValue)) {
      return resultFromStub;
    } else {
      return nil;
    }
  }
}

- (METMethodInvocationContext *)currentMethodInvocationContext {
  return _methodInvocationContextDynamicVariable.currentValue;
}

- (BOOL)isSuspended {
  return _operationQueue.isSuspended;
}

- (void)setSuspended:(BOOL)suspended {
  _operationQueue.suspended = suspended;
}

- (void)addMethodInvocation:(METMethodInvocation *)methodInvocation {
  NSAssert(methodInvocation.queuePriority == NSOperationQueuePriorityNormal, @"Operation priorities not supported due to implementation of barrier semantics");
  
  @synchronized(self) {
    NSString *methodID = methodInvocation.methodID;
    if (!methodID) {
      methodID = [[METRandomValueGenerator defaultRandomValueGenerator] randomIdentifier];
      methodInvocation.methodID = methodID;
    }
    
    _methodInvocationsByMethodID[methodID] = methodInvocation;
    
    NSOperationQueue *operationQueue = _operationQueue;
    methodInvocation.completionBlock = ^{
      // Make sure there hasn't been a reset
      if (_operationQueue == operationQueue) {
        [_methodInvocationsByMethodID removeObjectForKey:methodID];
      }
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
}

- (void)didReceiveResult:(id)result error:(NSError *)error forMethodID:(NSString *)methodID {
  @synchronized(self) {
    METMethodInvocation *methodInvocation = _methodInvocationsByMethodID[methodID];
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
}

- (void)didReceiveUpdatesDoneForMethodID:(NSString *)methodID {
  @synchronized(self) {
    METMethodInvocation *methodInvocation = _methodInvocationsByMethodID[methodID];
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
        METDataUpdate *update = [[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeReplace documentKey:documentKey fields:bufferedDocument.fields];
        [_client.database applyDataUpdate:update];
        [_bufferedDocumentsByKey removeObjectForKey:documentKey];
        [bufferedDocument didFlush];
      }
    }];
    
    [self performAfterAllCurrentlyBufferedDocumentsAreFlushed:^{
      [methodInvocation didFlushUpdates];
    }];
  }
}

- (void)performAfterAllCurrentlyBufferedDocumentsAreFlushed:(void (^)())block {
  @synchronized(self) {    
    if (_bufferedDocumentsByKey.count < 1) {
      [_client.database performAfterBufferedUpdatesAreFlushed:block];
      return;
    }
    
    dispatch_group_t group = dispatch_group_create();
    [_bufferedDocumentsByKey enumerateKeysAndObjectsUsingBlock:^(METDocumentKey *documentKey, METBufferedDocument *bufferedDocument, BOOL *stop) {
      [bufferedDocument waitUntilFlushedWithGroup:group];
    }];
    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      [_client.database performAfterBufferedUpdatesAreFlushed:block];
    });
  }
}

- (void)resetWhileAddingMethodInvocationsToTheFrontOfTheQueueUsingBlock:(void (^)())block {
  @synchronized(self) {
    NSArray *methodInvocations = [_operationQueue.operations copy];
    [_operationQueue cancelAllOperations];
    [_bufferedDocumentsByKey removeAllObjects];
    
    _operationQueue = [[NSOperationQueue alloc] init];
    _operationQueue.suspended = YES;
    
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
}

- (BOOL)applyDataUpdate:(METDataUpdate *)update {
  @synchronized(self) {
    METBufferedDocument *bufferedDocument = _bufferedDocumentsByKey[update.documentKey];
    if (!bufferedDocument) {
      return NO;
    }
    
    switch (update.updateType) {
      case METDataUpdateTypeAdd:
        if (bufferedDocument.fields != nil) {
          NSLog(@"Couldn't add document because a document with the same key already exists: %@", update.documentKey);
          break;
        }
        bufferedDocument.fields = update.fields;
        break;
      case METDataUpdateTypeChange:
        if (bufferedDocument.fields == nil) {
          NSLog(@"Couldn't update document because no document with the specified ID exists: %@", update.documentKey);
          break;
        }
        bufferedDocument.fields = [bufferedDocument.fields fieldsByApplyingChangedFields:update.fields];
        break;
      case METDataUpdateTypeReplace:
        bufferedDocument.fields = update.fields;
        break;
      case METDataUpdateTypeRemove:
        if (bufferedDocument.fields == nil) {
          NSLog(@"Couldn't remove document because no document with the specified ID exists: %@", update.documentKey);
          break;
        }
        bufferedDocument.fields = nil;
        break;
    }
  }

  return YES;
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
