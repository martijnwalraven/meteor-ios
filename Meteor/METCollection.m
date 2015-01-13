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

#import "METCollection.h"
#import "METCollection_Internal.h"

#import "METDatabase.h"
#import "METDatabase_Internal.h"
#import "METDocumentCache.h"
#import "METDocumentKey.h"
#import "METDocument.h"
#import "METFetchRequest.h"
#import "METDDPClient.h"
#import "METDDPClient_Internal.h"
#import "NSDictionary+METAdditions.h"
#import "METMethodInvocationContext.h"
#import "METRandomStream.h"
#import "METRandomValueGenerator.h"
#import "METDataUpdate.h"

@interface METCollection ()
@end

@implementation METCollection {
}

- (instancetype)initWithName:(NSString *)name database:(METDatabase *)database {
  self = [super init];
  if (self) {
    _name = [name copy];
    _database = database;
    
    [self defineStubsForMutationMethods];
  }
  return self;
}

- (void)defineStubsForMutationMethods {
  [_database.client defineStubForMethodWithName:[self methodNameForUpdateType:@"insert"] usingBlock:^id(NSArray *parameters) {
    NSDictionary *document = parameters[0];
    
    id documentID = document[@"_id"];
    
    NSMutableDictionary *fields = [document mutableCopy];
    [fields removeObjectForKey:@"_id"];
    
    if (!documentID) {
      documentID = [self generateNewDocumentID];
    }
    
    __block BOOL success = NO;
    [_database performUpdatesInLocalCache:^(METDocumentCache *localCache) {
      success = [localCache addDocumentWithKey:[self keyWithID:documentID] fields:fields];
    }];
    
    if (success) {
      return documentID;
    } else {
      return nil;
    }
  }];
  
  [_database.client defineStubForMethodWithName:[self methodNameForUpdateType:@"update"] usingBlock:^id(NSArray *parameters) {
    id selector = parameters[0];
    NSDictionary *modifier = parameters[1];
    
    id documentID = [self documentIDFromSelector:selector];
    
    NSMutableDictionary *fields = modifier[@"$set"];
    NSArray *clearedFields = modifier[@"$unset"];
    for (NSString *field in clearedFields) {
      fields[field] = [NSNull null];
    }
    
    __block BOOL success = NO;
    [_database performUpdatesInLocalCache:^(METDocumentCache *localCache) {
      success = [localCache updateDocumentWithKey:[self keyWithID:documentID] changedFields:fields];
    }];
    
    if (success) {
      return @1;
    } else {
      return @0;
    }
  }];
  
  [_database.client defineStubForMethodWithName:[self methodNameForUpdateType:@"remove"] usingBlock:^id(NSArray *parameters) {
    id selector = parameters[0];
    id documentID = [self documentIDFromSelector:selector];
    
    __block BOOL success = NO;
    [_database performUpdatesInLocalCache:^(METDocumentCache *localCache) {
      success = [localCache removeDocumentWithKey:[self keyWithID:documentID]];
    }];
    
    if (success) {
      return @1;
    } else {
      return @0;
    }
  }];
}

- (id)documentIDFromSelector:(id)selector {
  if ([selector isKindOfClass:[NSDictionary class]]) {
    return selector[@"_id"];
  } else {
    return selector;
  }
}

- (NSArray *)allDocuments {
  return [_database executeFetchRequest:[[METFetchRequest alloc] initWithCollectionName:_name]];
}

- (METDocument *)documentWithID:(id)documentID {
  return [_database documentWithKey:[self keyWithID:documentID]];
}

- (METDocumentKey *)keyWithID:(id)documentID {
  return [METDocumentKey keyWithCollectionName:_name documentID:documentID];
}
   
- (NSString *)methodNameForUpdateType:(NSString *)updateType {
  return [NSString stringWithFormat:@"/%@/%@", _name, updateType];
}

- (id)insertDocumentWithID:(id)documentID fields:(NSDictionary *)fields {
  return [self insertDocumentWithID:documentID fields:fields completionHandler:nil];
}

- (id)insertDocumentWithID:(id)documentID fields:(NSDictionary *)fields completionHandler:(METMethodCompletionHandler)completionHandler {
  NSParameterAssert(documentID);
  return [self insertDocumentWithFields:[fields dictionaryByAddingObject:documentID forKey:@"_id"] completionHandler:completionHandler];
}

- (id)insertDocumentWithFields:(NSDictionary *)fields {
  return [self insertDocumentWithFields:fields completionHandler:nil];
}

- (id)insertDocumentWithFields:(NSDictionary *)fields completionHandler:(METMethodCompletionHandler)completionHandler {
  NSString *methodName = [self methodNameForUpdateType:@"insert"];
  
  if (!fields[@"_id"] && _database.client.currentMethodInvocationContext) {
    fields = [fields dictionaryByAddingObject:[self generateNewDocumentID] forKey:@"_id"];
  }
  
  id newDocumentID = [_database.client callMethodWithName:methodName parameters:@[fields] options:METMethodCallOptionsReturnStubValue completionHandler:completionHandler ? ^(id result, NSError *error) {
    if ([result isKindOfClass:[NSArray class]]) {
      NSArray *array = (NSArray *)result;
      if (array.count > 0) {
        completionHandler(array[0][@"_id"], error);
      }
    } else {
      NSLog(@"Received unexpected response to insert method call: %@", result);
      completionHandler(nil, error);
    };
  } : nil];
  
  return newDocumentID;
}

- (id)updateDocumentWithID:(id)documentID changedFields:(NSDictionary *)changedFields {
  return [self updateDocumentWithID:documentID changedFields:changedFields completionHandler:nil];
}

- (id)updateDocumentWithID:(id)documentID changedFields:(NSDictionary *)changedFields completionHandler:(METMethodCompletionHandler)completionHandler {
  NSParameterAssert(documentID);
  
  NSArray *clearedFields = [changedFields allKeysForObject:[NSNull null]];
  
  NSMutableDictionary *modifiers = [[NSMutableDictionary alloc] init];
  modifiers[@"$set"] = [changedFields dictionaryByRemovingObjectsForKeys:clearedFields];
  if (clearedFields.count != 0) {
    modifiers[@"$unset"] = [NSDictionary dictionaryWithObject:@"" forKeys:clearedFields];
  }
  
  NSString *methodName = [self methodNameForUpdateType:@"update"];
  return [_database.client callMethodWithName:methodName parameters:@[@{@"_id": documentID}, modifiers] options:METMethodCallOptionsReturnStubValue completionHandler:completionHandler];
}

- (id)removeDocumentWithID:(id)documentID {
  return [self removeDocumentWithID:documentID completionHandler:nil];
}

- (id)removeDocumentWithID:(id)documentID completionHandler:(METMethodCompletionHandler)completionHandler {
  NSParameterAssert(documentID);
  
  NSString *methodName = [self methodNameForUpdateType:@"remove"];
  return [_database.client callMethodWithName:methodName parameters:@[@{@"_id": documentID}] options:METMethodCallOptionsReturnStubValue completionHandler:completionHandler];
}

- (id)generateNewDocumentID {  
  METMethodInvocationContext *currentMethodInvocationContext = _database.client.currentMethodInvocationContext;
  
  METRandomValueGenerator *generator;
  if (currentMethodInvocationContext) {
    generator = [currentMethodInvocationContext.randomStream sequenceWithName:[NSString stringWithFormat:@"/collection/%@", _name]];
  } else {
    generator = [METRandomValueGenerator defaultRandomValueGenerator];
  }
  
  return [generator randomIdentifier];
}

@end
