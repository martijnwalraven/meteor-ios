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

#import "METIncrementalStore.h"
#import "METIncrementalStore_Testing.h"

#import "METDDPClient.h"
#import "METDatabase.h"
#import "METDocument.h"
#import "METDocumentKey.h"
#import "METCollection.h"
#import "METCollection_Internal.h"
#import "METDatabaseChanges.h"
#import "METDocumentChangeDetails.h"
#import "NSArray+METAdditions.h"
#import "NSString+InflectorKit.h"

NSString * const METIncrementalStoreErrorDomain = @"com.meteor.IncrementalStore.ErrorDomain";

NSString * const METIncrementalStoreObjectsDidChangeNotification = @"METIncrementalStoreObjectsDidChangeNotification";

@implementation METIncrementalStore {
  NSManagedObjectModel *_managedObjectModel;
  NSMutableDictionary *_entityNamesByCollectionName;
  NSMutableDictionary *_collectionNamesByEntityName;
  
  NSCountedSet *_registeredObjectIDs;
  NSMutableDictionary *_nodesByObjectID;
}

#pragma mark - Class Methods

+ (void)initialize {
  [NSPersistentStoreCoordinator registerStoreClass:self forStoreType:[self type]];
}

+ (NSString *)type {
  return NSStringFromClass(self);
}

#pragma mark - Lifecycle

- (instancetype)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)persistentStoreCoordinator configurationName:(NSString *)configurationName URL:(NSURL *)URL options:(NSDictionary *)options {
  self = [super initWithPersistentStoreCoordinator:persistentStoreCoordinator configurationName:configurationName URL:URL options:options];
  if (self) {
    _managedObjectModel = persistentStoreCoordinator.managedObjectModel;
    [self initializeMapping];
    
    _registeredObjectIDs = [[NSCountedSet alloc] init];
    _nodesByObjectID = [[NSMutableDictionary alloc] init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(databaseDidChange:) name:METDatabaseDidChangeNotification object:_client.database];
  }
  
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - NSIncrementalStore

- (BOOL)loadMetadata:(NSError *__autoreleasing *)error {
  NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
  metadata[NSStoreUUIDKey] = [[NSProcessInfo processInfo] globallyUniqueString];
  metadata[NSStoreTypeKey] = [[self class] type];
  self.metadata = metadata;
  return YES;
}

- (id)executeRequest:(NSPersistentStoreRequest *)request withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
  switch (request.requestType) {
    case NSFetchRequestType:
      return [self executeFetchRequest:(NSFetchRequest *)request withContext:context error:error];
    case NSSaveRequestType:
      return [self executeSaveChangesRequest:(NSSaveChangesRequest *)request withContext:context error:error];
    default:
      if (error) {
        *error = [self errorWithCode:0 localizedDescription:[NSString stringWithFormat:@"Unsupported NSFetchRequest type, %lu", (unsigned long)request.requestType]];
      }
      return nil;
  }
}

- (NSIncrementalStoreNode *)newValuesForObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
  NSDictionary *values = [self valuesForObjectID:objectID];
  
  if (!values) {
    if (error) {
      *error = [self errorWithCode:0 localizedDescription:@"Values for object not found"];
    }
    return nil;
  }
  
  NSIncrementalStoreNode *node = [self nodeWithObjectID:objectID withValues:values version:1];
  return node;
}

- (id)newValueForRelationship:(NSRelationshipDescription *)relationship forObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
  if ([relationship isToMany]) {
    return [self objectIDsForToManyRelationship:relationship forObjectWithID:objectID];
  } else {
    return [self objectIDForToOneRelationship:relationship forObjectWithID:objectID];
  }
}

- (NSArray *)obtainPermanentIDsForObjects:(NSArray *)objects error:(NSError *__autoreleasing *)error {
  NSMutableArray *objectIDs = [NSMutableArray arrayWithCapacity:objects.count];
  
  for (NSManagedObject *object in objects) {
    NSEntityDescription *entity = object.entity;
    METCollection *collection = [self collectionForEntity:entity];
    id documentID = [collection generateNewDocumentID];
    NSManagedObjectID *objectID = [self objectIDForDocumentKey:[METDocumentKey keyWithCollectionName:collection.name documentID:documentID]];
    [objectIDs addObject:objectID];
  }
  
  return objectIDs;
}

- (void)managedObjectContextDidRegisterObjectsWithIDs:(NSArray *)objectIDs {
  for (NSManagedObjectID *objectID in objectIDs) {
    [_registeredObjectIDs addObject:objectID];
  }
}

- (void)managedObjectContextDidUnregisterObjectsWithIDs:(NSArray *)objectIDs {
  for (NSManagedObjectID *objectID in objectIDs) {
    [_registeredObjectIDs removeObject:objectID];
    
    if ([_registeredObjectIDs countForObject:objectID] == 0) {
      [_nodesByObjectID removeObjectForKey:objectID];
    }
  }
}

#pragma mark - Fetching

- (id)executeFetchRequest:(NSFetchRequest *)request withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
  NSEntityDescription *entity = request.entity;
  NSAssert(entity != nil, @"Entity shouldn't be nil");
  
  NSMutableArray *documents = [[self documentsForEntity:entity] mutableCopy];
  
  NSMutableArray *fetchedObjects = [NSMutableArray arrayWithCapacity:documents.count];
  for (METDocument *document in documents) {
    NSManagedObjectID *objectID = [self objectIDForDocumentKey:document.key];
    NSManagedObject *managedObject = [context objectWithID:objectID];
    [fetchedObjects addObject:managedObject];
  }
  
  if (request.predicate) {
    [fetchedObjects filterUsingPredicate:request.predicate];
  }
  
  if (request.sortDescriptors) {
    [fetchedObjects sortUsingDescriptors:request.sortDescriptors];
  }
  
  switch (request.resultType) {
    case NSManagedObjectResultType:
      return fetchedObjects;
      break;
    case NSManagedObjectIDResultType:
      return [fetchedObjects valueForKeyPath:@"objectID"];
      break;
    case NSCountResultType:
      return @[@(fetchedObjects.count)];
      break;
    default:
      if (error) {
        *error = [self errorWithCode:0 localizedDescription:[NSString stringWithFormat:@"Unsupported NSFetchRequest result type: %lu", (unsigned long)request.resultType]];
      }
      return nil;
  }
}

- (NSArray *)documentsForEntity:(NSEntityDescription *)entity {
  METCollection *collection = [self collectionForEntity:entity];
  return [collection allDocuments];
}

- (NSDictionary *)valuesForObjectID:(NSManagedObjectID *)objectID {
  METDocument *document = [self documentForObjectWithID:objectID];
  if (!document) {
    return nil;
  }
  
  NSMutableDictionary *values = [[NSMutableDictionary alloc] initWithCapacity:document.fields.count];
  NSEntityDescription *entity = objectID.entity;
  
  for (NSPropertyDescription *property in entity) {
    if ([property isKindOfClass:[NSAttributeDescription class]]) {
      NSAttributeDescription *attribute = (NSAttributeDescription *)property;
      NSString *fieldName = [self fieldNameForAttribute:attribute];
      id value = document[fieldName];
      if (value) {
        values[attribute.name] = value;
      }
    } else if ([property isKindOfClass:[NSRelationshipDescription class]]) {
      NSRelationshipDescription *relationship = (NSRelationshipDescription *)property;
      if (![self isReferenceStoredInSourceDocumentForRelationship:relationship]) continue;
      
      if ([relationship isToMany]) {
        NSArray *objectIDs = [self objectIDsForToManyRelationship:relationship inDocument:document];
        if (objectIDs) {
          values[relationship.name] = objectIDs;
        }
      } else {
          values[relationship.name] = [self objectIDForToOneRelationship:relationship inDocument:document];
      }
    }
  }
  
  return values;
}

- (BOOL)isReferenceStoredInSourceDocumentForRelationship:(NSRelationshipDescription *)relationship {
  id storageInfo = relationship.userInfo[@"storage"];
  return !storageInfo || ![storageInfo boolValue] == NO;
}

- (id)objectIDForToOneRelationship:(NSRelationshipDescription *)relationship forObjectWithID:(NSManagedObjectID *)objectID {
  if ([self isReferenceStoredInSourceDocumentForRelationship:relationship]) {
    METDocument *document = [self documentForObjectWithID:objectID];
    return [self objectIDForToOneRelationship:relationship inDocument:document];
  } else {
    NSString *sourceDocumentID = [self documentKeyForObjectID:objectID].documentID;
    NSArray *destinationDocuments = [self documentsForEntity:relationship.destinationEntity];
    NSRelationshipDescription *inverseRelationship = relationship.inverseRelationship;
    NSString *fieldName = [self fieldNameForRelationship:inverseRelationship];
    if ([inverseRelationship isToMany]) {
      for (METDocument *document in destinationDocuments) {
        NSArray *documentIDs = document[fieldName];
        if ([documentIDs containsObject:sourceDocumentID]) {
          return [self objectIDForDocument:document];
        }
      }
      return [NSNull null];
    } else {
      for (METDocument *document in destinationDocuments) {
        if ([document[fieldName] isEqual:sourceDocumentID]) {
          return [self objectIDForDocument:document];
        }
      }
      return [NSNull null];
    }
  }
}

- (id)objectIDForToOneRelationship:(NSRelationshipDescription *)relationship inDocument:(METDocument *)document {
  NSString *fieldName = [self fieldNameForRelationship:relationship];
  id destinationDocumentID = document[fieldName];
  
  if (destinationDocumentID) {
    return [self objectIDForDocumentKey:[METDocumentKey keyWithCollectionName:[self collectionNameForEntity:relationship.destinationEntity] documentID:destinationDocumentID]];
  }
  
  return [NSNull null];
}

- (NSArray *)objectIDsForToManyRelationship:(NSRelationshipDescription *)relationship forObjectWithID:(NSManagedObjectID *)objectID {
  if ([self isReferenceStoredInSourceDocumentForRelationship:relationship]) {
    METDocument *document = [self documentForObjectWithID:objectID];
    return [self objectIDsForToManyRelationship:relationship inDocument:document];
  } else {
    NSRelationshipDescription *inverseRelationship = relationship.inverseRelationship;
    NSString *sourceDocumentID = [self documentKeyForObjectID:objectID].documentID;
    NSArray *destinationDocuments = [self documentsForEntity:relationship.destinationEntity];
    NSString *fieldName = [self fieldNameForRelationship:inverseRelationship];
    NSMutableArray *objectIDs = [[NSMutableArray alloc] init];
    for (METDocument *document in destinationDocuments) {
      if ([document[fieldName] isEqual:sourceDocumentID]) {
        [objectIDs addObject:[self objectIDForDocument:document]];
      }
    }
    return objectIDs;
  }
}

- (NSArray *)objectIDsForToManyRelationship:(NSRelationshipDescription *)relationship inDocument:(METDocument *)document {
  NSString *fieldName = [self fieldNameForRelationship:relationship];
  NSArray *destinationDocumentIDs = document[fieldName];
  if (!destinationDocumentIDs) return nil;
  NSEntityDescription *destinationEntity = relationship.destinationEntity;
  return [destinationDocumentIDs mappedArrayUsingBlock:^id(id destinationDocumentID) {
    return [self objectIDForDocumentKey:[METDocumentKey keyWithCollectionName:[self collectionNameForEntity:destinationEntity] documentID:destinationDocumentID]];
  }];
}

#pragma mark - Saving

- (id)executeSaveChangesRequest:(NSSaveChangesRequest *)request withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
  
  [_client.database performUpdates:^{
    for (NSManagedObject *object in request.insertedObjects) {
      METCollection *collection = [self collectionForEntity:object.entity];
      id documentID = [self documentKeyForObjectID:object.objectID].documentID;
      NSDictionary *fields = [self changedFieldsForObject:object];
      [collection insertDocumentWithID:documentID fields:fields];
    }
    
    for (NSManagedObject *object in request.updatedObjects) {
      METCollection *collection = [self collectionForEntity:object.entity];
      id documentID = [self documentKeyForObjectID:object.objectID].documentID;
      NSDictionary *changedFields = [self changedFieldsForObject:object];
      if (changedFields.count > 0) {
        [collection updateDocumentWithID:documentID changedFields:changedFields];
      }
    }
    
    for (NSManagedObject *object in request.deletedObjects) {
      METCollection *collection = [self collectionForEntity:object.entity];
      id documentID = [self documentKeyForObjectID:object.objectID].documentID;
      [collection removeDocumentWithID:documentID];
    }
  }];
  
  return @[];
}

- (NSDictionary *)changedFieldsForObject:(NSManagedObject *)object {
  NSEntityDescription *entity = object.entity;
  NSDictionary *changedValues = object.changedValues;
  NSMutableDictionary *changedFields = [[NSMutableDictionary alloc] initWithCapacity:changedValues.count];
  
  [changedValues enumerateKeysAndObjectsUsingBlock:^(NSString *name, id value, BOOL *stop) {
    NSPropertyDescription *property = entity.propertiesByName[name];
    
    if ([property isKindOfClass:[NSAttributeDescription class]]) {
      NSAttributeDescription *attribute = (NSAttributeDescription *)property;
      NSString *fieldName = [self fieldNameForAttribute:attribute];
      changedFields[fieldName] = value;
    } else if ([property isKindOfClass:[NSRelationshipDescription class]]) {
      NSRelationshipDescription *relationship = (NSRelationshipDescription *)property;
      if (![self isReferenceStoredInSourceDocumentForRelationship:relationship]) return;
      
      NSString *fieldName = [self fieldNameForRelationship:relationship];
      if ([relationship isToMany]) {
        NSSet *destinationObjects = (NSSet *)value;
        if (destinationObjects.count < 1) {
          changedFields[fieldName] = [NSNull null];
        } else {
          NSMutableArray *destinationDocumentIDs = [[NSMutableArray alloc] initWithCapacity:destinationObjects.count];
          for (NSManagedObject *destinationObject in destinationObjects) {
            id destinationDocumentID = [self documentKeyForObjectID:destinationObject.objectID].documentID;
            [destinationDocumentIDs addObject:destinationDocumentID];
          }
          changedFields[fieldName] = destinationDocumentIDs;
        }
      } else {
        if (value == [NSNull null]) {
          changedFields[fieldName] = [NSNull null];
        } else {
          NSManagedObject *destinationObject = (NSManagedObject *)value;
          id destinationDocumentID = [self documentKeyForObjectID:destinationObject.objectID].documentID;
          changedFields[fieldName] = destinationDocumentID;
        }
      }
    }
  }];
  
  return changedFields;
}

#pragma mark - Mapping Objects To and From Documents

- (void)initializeMapping {
  NSArray *entities = self.persistentStoreCoordinator.managedObjectModel.entities;
  
  _entityNamesByCollectionName = [[NSMutableDictionary alloc] initWithCapacity:entities.count];
  _collectionNamesByEntityName = [[NSMutableDictionary alloc] initWithCapacity:entities.count];
  
  for (NSEntityDescription *entity in entities) {
    NSString *entityName = entity.name;
    NSString *collectionName = entity.userInfo[@"collectionName"] ?: [[entityName pluralizedString] lowercaseString];

    _entityNamesByCollectionName[collectionName] = entityName;
    _collectionNamesByEntityName[entityName] = collectionName;
  }
}

- (NSString *)collectionNameForEntity:(NSEntityDescription *)entity {
  NSParameterAssert(entity);
  return _collectionNamesByEntityName[entity.name];
}

- (METCollection *)collectionForEntity:(NSEntityDescription *)entity {
  NSString *collectionName = [self collectionNameForEntity:entity];
  NSAssert(collectionName != nil, @"Could not find collection name for entity name: %@", entity.name);
  return [_client.database collectionWithName:collectionName];
}

- (NSEntityDescription *)entityForCollectionName:(NSString *)collectionName {
  NSParameterAssert(collectionName);
  NSString *entityName = _entityNamesByCollectionName[collectionName];
  return [self entityForName:entityName] ?: nil;
}

- (NSManagedObjectID *)objectIDForDocument:(METDocument *)document {
  return [self objectIDForDocumentKey:document.key];
}

- (NSManagedObjectID *)objectIDForDocumentKey:(METDocumentKey *)documentKey {
  NSParameterAssert(documentKey);
  NSEntityDescription *entity = [self entityForCollectionName:documentKey.collectionName];
  if (!entity) {
    return nil;
  }
  return [self newObjectIDForEntity:entity referenceObject:documentKey.documentID];
}

- (NSManagedObjectID *)objectIDForEntity:(NSEntityDescription *)entity documentID:(id)documentID {
  return [self objectIDForDocumentKey:[METDocumentKey keyWithCollectionName:[self collectionNameForEntity:entity] documentID:documentID]];
}

- (METDocumentKey *)documentKeyForObjectID:(NSManagedObjectID *)objectID {
  NSParameterAssert(objectID);
  NSString *collectionName = [self collectionNameForEntity:objectID.entity];
  id documentID = [self referenceObjectForObjectID:objectID];
  return [METDocumentKey keyWithCollectionName:collectionName documentID:documentID];
}

- (METDocument *)documentForObjectWithID:(NSManagedObjectID *)objectID {
  return [_client.database documentWithKey:[self documentKeyForObjectID:objectID]];
}

- (NSString *)fieldNameForRelationship:(NSRelationshipDescription *)relationship {
  NSString *customFieldName = relationship.userInfo[@"fieldName"];
  
  if (customFieldName) {
    return customFieldName;
  }
  
  if ([relationship isToMany]) {
    return [[relationship.name singularizedString] stringByAppendingString:@"Ids"];
  } else {
    return [[relationship.name singularizedString] stringByAppendingString:@"Id"];
  }
}

- (NSString *)fieldNameForAttribute:(NSAttributeDescription *)attribute {
  return attribute.userInfo[@"fieldName"] ?: attribute.name;
}

#pragma mark - Change Notifications

- (void)databaseDidChange:(NSNotification *)notification {
  METDatabaseChanges *databaseChanges = notification.userInfo[METDatabaseChangesKey];
  
  NSMutableSet *insertedObjects = [[NSMutableSet alloc] init];
  NSMutableSet *updatedObjects = [[NSMutableSet alloc] init];
  NSMutableSet *deletedObjects = [[NSMutableSet alloc] init];
  
  [databaseChanges enumerateDocumentChangeDetailsUsingBlock:^(METDocumentChangeDetails *documentChangeDetails, BOOL *stop) {
    NSManagedObjectID *objectID = [self objectIDForDocumentKey:documentChangeDetails.documentKey];
    if (!objectID) {
      return;
    }
    switch (documentChangeDetails.changeType) {
      case METDocumentChangeTypeAdd:
        [insertedObjects addObject:objectID];
        break;
      case METDocumentChangeTypeUpdate:
        [updatedObjects addObject:objectID];
        break;
      case METDocumentChangeTypeRemove:
        [deletedObjects addObject:objectID];
        break;
    }
    
    // Report objects involved in relationships affected by the changed fields as updated
    NSEntityDescription *entity = [self entityForCollectionName:documentChangeDetails.documentKey.collectionName];
    NSDictionary *changedFields = documentChangeDetails.changedFields;
    for (NSPropertyDescription *property in entity) {
      if ([property isKindOfClass:[NSRelationshipDescription class]]) {
        NSRelationshipDescription *relationship = (NSRelationshipDescription *)property;
        if ([self isReferenceStoredInSourceDocumentForRelationship:relationship]) {
          NSString *fieldName = [self fieldNameForRelationship:relationship];
          METCollection *destinationCollection = [self collectionForEntity:relationship.destinationEntity];
          if ([relationship isToMany]) {
            NSArray *destinationDocumentIDs = changedFields[fieldName];
            if (destinationDocumentIDs && destinationDocumentIDs != (id)[NSNull null]) {
              for (id destinationDocumentID in destinationDocumentIDs) {
                if ([destinationCollection documentWithID:destinationDocumentID]) {
                  NSManagedObjectID *destinationObjectID = [self objectIDForEntity:relationship.destinationEntity documentID:destinationDocumentID];
                  [updatedObjects addObject:destinationObjectID];
                }
              }
            }
          } else {
            id destinationDocumentID = changedFields[fieldName];
            if (destinationDocumentID && destinationDocumentID != [NSNull null]) {
              if ([destinationCollection documentWithID:destinationDocumentID]) {
                NSManagedObjectID *destinationObjectID = [self objectIDForEntity:relationship.destinationEntity documentID:destinationDocumentID];
                [updatedObjects addObject:destinationObjectID];
              }
            }
          }
        }
      }
    }
  }];
  
  // Inserted or deleted objects should not also be reported as updated
  [updatedObjects minusSet:insertedObjects];
  [updatedObjects minusSet:deletedObjects];
  
  if (insertedObjects.count > 0 || updatedObjects.count > 0 || deletedObjects.count > 0) {
    NSNotification *notification = [NSNotification notificationWithName:METIncrementalStoreObjectsDidChangeNotification object:self userInfo:@{NSInsertedObjectsKey: [insertedObjects copy], NSUpdatedObjectsKey: [updatedObjects copy], NSDeletedObjectsKey: [deletedObjects copy]}];
    [[NSNotificationCenter defaultCenter] postNotification:notification];
  }
}

#pragma mark - Node Cache

- (NSIncrementalStoreNode *)nodeWithObjectID:(NSManagedObjectID *)objectID withValues:(NSDictionary *)values version:(uint64_t)version {
  NSIncrementalStoreNode *node = _nodesByObjectID[objectID];
  if (node) {
    [node updateWithValues:values version:version];
  } else {
    node = [[NSIncrementalStoreNode alloc] initWithObjectID:objectID withValues:values version:version];
    _nodesByObjectID[objectID] = node;
  }
  return node;
}

- (NSUInteger)numberOfCachedNodes {
  return _nodesByObjectID.count;
}

#pragma mark - Helper Methods

- (NSEntityDescription *)entityForName:(NSString *)entityName {
  return [_managedObjectModel entitiesByName][entityName];
}

- (NSError *)errorWithCode:(NSInteger)code localizedDescription:(NSString *)localizedDescription {
  NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
  userInfo[NSLocalizedDescriptionKey] = localizedDescription;
  return [NSError errorWithDomain:METIncrementalStoreErrorDomain code:code userInfo:userInfo];
}

@end
