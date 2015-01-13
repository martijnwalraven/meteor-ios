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

#import "METDocumentCache.h"

#import "METDocumentKey.h"
#import "METDocument.h"
#import "METFetchRequest.h"
#import "METDataUpdate.h"
#import "NSDictionary+METAdditions.h"

@implementation METDocumentCache {
  dispatch_queue_t _queue;
  NSMutableDictionary *_documentsByCollectionNameByDocumentID;
  NSMutableDictionary *_snapshot;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _queue = dispatch_queue_create([@"com.meteor.DocumentCache" UTF8String], DISPATCH_QUEUE_CONCURRENT);
    _documentsByCollectionNameByDocumentID = [[NSMutableDictionary alloc] init];
  }
  return self;
}

- (NSArray *)executeFetchRequest:(METFetchRequest *)fetchRequest {
  __block NSArray *result;
  dispatch_sync(_queue, ^{
    result = [_documentsByCollectionNameByDocumentID[fetchRequest.collectionName] allValues];
  });
  return result;
}

- (METDocument *)documentWithKey:(METDocumentKey *)documentKey {
  __block METDocument *document;
  dispatch_sync(_queue, ^{
    document = [self loadDocumentWithKey:documentKey];
  });
  return document;
}

- (BOOL)addDocumentWithKey:(METDocumentKey *)documentKey fields:(NSDictionary *)fields {
  NSParameterAssert(documentKey);
  NSParameterAssert(fields);
  
  __block BOOL result = NO;
  dispatch_barrier_sync(_queue, ^{
    METDocument *existingDocument = [self loadDocumentWithKey:documentKey];
    if (existingDocument) {
      NSLog(@"Couldn't add document because a document with the same key already exists: %@", documentKey);
      result = NO;
      return;
    }
    
    [_delegate documentCache:self willChangeDocumentWithKey:documentKey fieldsBeforeChanges:existingDocument.fields];
    METDocument *document = [[METDocument alloc] initWithKey:documentKey fields:fields];
    [self storeDocument:document forKey:documentKey];
    [_delegate documentCache:self didChangeDocumentWithKey:documentKey fieldsAfterChanges:fields];
    result = YES;
  });
  return result;
}

- (BOOL)updateDocumentWithKey:(METDocumentKey *)documentKey changedFields:(NSDictionary *)changedFields {
  NSParameterAssert(documentKey);
  NSParameterAssert(changedFields);
  
  __block BOOL result = NO;
  dispatch_barrier_sync(_queue, ^{
    METDocument *existingDocument = [self loadDocumentWithKey:documentKey];
    if (!existingDocument) {
      NSLog(@"Couldn't update document because no document with the specified ID exists: %@", documentKey);
      result = NO;
      return;
    }
    
    [_delegate documentCache:self willChangeDocumentWithKey:documentKey fieldsBeforeChanges:existingDocument.fields];
    METDocument *document = [[METDocument alloc] initWithKey:documentKey fields:[existingDocument.fields fieldsByApplyingChangedFields:changedFields]];
    [self storeDocument:document forKey:documentKey];
    [_delegate documentCache:self didChangeDocumentWithKey:documentKey fieldsAfterChanges:document.fields];
    result = YES;
  });
  return result;
}

- (void)replaceDocumentWithKey:(METDocumentKey *)documentKey fields:(NSDictionary *)fields {
  NSParameterAssert(documentKey);
  
  dispatch_barrier_sync(_queue, ^{
    METDocument *existingDocument = [self loadDocumentWithKey:documentKey];
    [_delegate documentCache:self willChangeDocumentWithKey:documentKey fieldsBeforeChanges:existingDocument.fields];
    if (fields) {
      METDocument *document = [[METDocument alloc] initWithKey:documentKey fields:fields];
      [self storeDocument:document forKey:documentKey];
      [_delegate documentCache:self didChangeDocumentWithKey:documentKey fieldsAfterChanges:fields];
    } else {
      [_documentsByCollectionNameByDocumentID[documentKey.collectionName] removeObjectForKey:documentKey.documentID];
      [_delegate documentCache:self didChangeDocumentWithKey:documentKey fieldsAfterChanges:nil];
    }
  });
}

- (BOOL)removeDocumentWithKey:(METDocumentKey *)documentKey {
  NSParameterAssert(documentKey);
  
  __block BOOL result = NO;
  dispatch_barrier_sync(_queue, ^{
    METDocument *existingDocument = [self loadDocumentWithKey:documentKey];
    if (!existingDocument) {
      NSLog(@"Couldn't remove document because no document with the specified ID exists: %@", documentKey);
      result = NO;
      return;
    }
    
    [_delegate documentCache:self willChangeDocumentWithKey:documentKey fieldsBeforeChanges:existingDocument.fields];
    [_documentsByCollectionNameByDocumentID[documentKey.collectionName] removeObjectForKey:documentKey.documentID];
    [_delegate documentCache:self didChangeDocumentWithKey:documentKey fieldsAfterChanges:nil];
    result = YES;
  });
  return result;
}

- (void)removeAllDocuments {
  dispatch_barrier_sync(_queue, ^{
    [self enumerateDocumentsUsingBlock:^(METDocument *document, BOOL *stop) {
      [_delegate documentCache:self willChangeDocumentWithKey:document.key fieldsBeforeChanges:document.fields];
      [_delegate documentCache:self didChangeDocumentWithKey:document.key fieldsAfterChanges:nil];
    }];
    
    [_documentsByCollectionNameByDocumentID removeAllObjects];
  });
}

- (void)applyDataUpdate:(METDataUpdate *)update {
  METDocumentKey *documentKey = update.documentKey;
  switch (update.updateType) {
    case METDataUpdateTypeAdd:
      [self addDocumentWithKey:documentKey fields:update.fields];
      break;
    case METDataUpdateTypeChange:
      [self updateDocumentWithKey:documentKey changedFields:update.fields];
      break;
    case METDataUpdateTypeReplace:
      [self replaceDocumentWithKey:documentKey fields:update.fields];
      break;
    case METDataUpdateTypeRemove:
      [self removeDocumentWithKey:documentKey];
      break;
  }
}

#pragma mark - Helper Methods

- (METDocument *)loadDocumentWithKey:(METDocumentKey *)documentKey {
  return _documentsByCollectionNameByDocumentID[documentKey.collectionName][documentKey.documentID];
}

- (void)storeDocument:(METDocument *)document forKey:(METDocumentKey *)documentKey {
  NSMutableDictionary *documentsByID = _documentsByCollectionNameByDocumentID[documentKey.collectionName];
  if (!documentsByID) {
    documentsByID = [[NSMutableDictionary alloc] init];
    _documentsByCollectionNameByDocumentID[documentKey.collectionName] = documentsByID;
  }
  documentsByID[documentKey.documentID] = document;
}

- (void)enumerateDocumentsUsingBlock:(void (^)(METDocument *document, BOOL *stop))block {
  [_documentsByCollectionNameByDocumentID enumerateKeysAndObjectsUsingBlock:^(NSString *collectionName, NSDictionary *documentsByID, BOOL *outerStop) {
    [documentsByID enumerateKeysAndObjectsUsingBlock:^(id documentID, METDocument *document, BOOL *innerStop) {
      block(document, innerStop);
      *outerStop = *innerStop;
    }];
  }];
}

@end
