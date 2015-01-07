# Meteor for iOS

Meteor for iOS is work in progress, but aims to be a complete DDP client that includes full support for latency compensation and offers Core Data integration. It keeps as close as possible to the semantics of the original JavaScript code, but its design is more in line with Objective-C and Cocoa conventions (so expect many classes and really long method names 😀). It has been implemented with concurrent execution in mind and keeps all processing off the main thread, posting batched and consolidated change notifications that can be observed to update the UI. It includes over 200 unit tests and also has some server integration tests that run using a local Meteor test server.

It is in dire need of better documentation and more comprehensive examples, but is already fairly feature complete and seems to work pretty well (although I expect bugs to surface once other people start using it).

I'm still figuring out usage patterns and I'm actively improving the API. I'm mostly using it through Core Data in my own project, so I haven't gotten around implementing many convenience methods to manually deal with documents. Don't expect anything to be stable yet, but please do let me know what you think of it and what improvements you would like to see.

To give a quick taste of the current API (in Swift):
``` swift
let lists = Meteor.database.collectionWithName("lists")
let todos = Meteor.database.collectionWithName("todos")

// Makes sure only a single change notification is posted
Meteor.database.performUpdates {
  let listID: AnyObject = lists.insertDocumentWithFields(["name": "Favorite Scientists"])
  todos.insertDocumentWithFields(["text": "Ada Lovelace", "listId": listID])
  lists.updateDocumentWithID(listID, changedFields:["incompleteCount": 1])
  
  Meteor.addSubscriptionWithName("todos", parameters: [listID]) { (error) -> () in
    if error != nil {
      println("Encountered error subscribing to 'todos': \(error)")
    }
  }
}
```

With Core Data:
``` swift
let managedObjectContext = Meteor.mainQueueManagedObjectContext

let list = NSEntityDescription.insertNewObjectForEntityForName("List", inManagedObjectContext:managedObjectContext) as List
list.name = "Favorite Scientists"
let lovelace = NSEntityDescription.insertNewObjectForEntityForName("Todo", inManagedObjectContext:managedObjectContext) as Todo
lovelace.text = "Ada Lovelace"
lovelace.list = list
list.incompleteCount++

var error: NSError?
if !managedObjectContext.save(&error) {
  println("Encountered error saving objects: \(error)")
}

// Parameter 'list' is an NSManagedObject that is automatically converted to a documentID
Meteor.addSubscriptionWithName("todos", parameters: [list]) { (error) -> () in
  if error != nil {
    println("Encountered error subscribing to 'todos': \(error)")
  }
}
```

## Features
- Full support for latency compensation, faithfully (I hope) reproducing the semantics of the original JavaScript code. Modifications to documents are reflected immediately in the local cache and will be ammended by server changes only when the server completes sending data updates for the method (multiple methods concurrently modifying the same documents are handled correctly).
- Posting batched and consolidated change notifications at appropriate times, instead of relying on fine grained updates. This helps keep UI work on the main thread to a minimum without sacrificing responsiveness.
- Core Data integration using an `NSIncrementalStore` subclass. Mapping between documents and `NSManagedObject`s is performed automatically (but can be customized). All types of relationships are supported, both for fetching and saving. Modifications made to documents (possibly from other clients) will lead to the posting of an object change notification that can be used to update `NSManagedObjectContext`s.
- Correct handling of reconnection. Data updates on the new connection will be buffered until all subscriptions that were ready before have become ready again. Only then are updates applied and is a change notification posted (if anything actually changed).
- Subscriptions are shared and reused whenever possible. If a subscription is no longer in use, we don't actually unsubscribe until after a configurable timeout. This means data won't have to be removed and added again if it is needed again later.

### Swift

Meteor for iOS works well with Swift; I use it myself on a project. Especially with a new version of CocoaPods on the way (see below), it is as useable from Swift as any other Objective-C framework is. In the future however, I plan on updating the API to take better advantage of Swift language features (perhaps by adding extensions).

I had already started work on this project when Swift was announced. Although I'm impressed by Swift, I decided it was too soon to consider a rewrite. The language was and is evolving, and some potentially useful language features are still missing (in particular around generics and protocols). Performance can be unpredictable (especially when dealing with arrays and dictionaries) and tool support (Xcode) is not as stable as it is for Objective-C. Once the Swift language and implementation stabilize and language idioms become established, a complete or partial rewrite might be a viable option.

## Getting Started

###Examples
If you just want to have a look at the project, you should be able to open the Meteor workspace and run the examples. For now, I'll be focusing on improving the Todos example (written in Swift). It is rather barebones at the moment, but I plan on adding more functionality soon. It connects to a Meteor example app running at http://meteor-ios-todos.meteor.com.

###Installation with CocoaPods
The easiest way to use Meteor for iOS in your own project is through CocoaPods. Until recently, there was no convenient way to use CocoaPods with Swift. The release of CocoaPods 0.36 promises to change this however, by supporting frameworks (see http://blog.cocoapods.org/Pod-Authors-Guide-to-CocoaPods-Frameworks/). As frameworks are only supported on iOS 8 or higher, this means iOS 7 users are out of luck for now. It should be possible to support both building as a framework and as a static library, but I don't know enough about CocoaPods to get this to work reliably. Input is very welcome!

Because CocoaPods 0.36 has not been officially released, you'll have to install a prerelease version using `gem install cocoapods --pre`.

You can then write a `Podfile` referencing the project on GitHub (I will add it to the CocoaPods repo once it is more stable):
```
platform :ios, '8.0'
use_frameworks!
pod 'Meteor', git: 'https://github.com/martijnwalraven/meteor-ios.git' 
```

Meteor for iOS will then be built as a framework and is made available as a Clang module that can easily be imported without further configuration (you may need to build the project first before the module is recognized):

In Objective-C:
``` objective-c
@import Meteor;
```

In Swift:
``` swift
import Meteor
```

## Usage

Connecting to a Meteor server is done through a WebSocket URL that needs to be specified when creating an `METDDPClient`:

``` objective-c
METDDPClient *client = [[METDDPClient alloc] initWithServerURL:[NSURL URLWithString:@"ws://localhost:3000/websocket"]];
[client connect];
```

A client can then be used to subscribe to sets of documents:
``` objective-c
METSubscription *subscription = [client addSubscriptionWithName:@"playersWithMinimumScore" parameters:@[@20] completionHandler:^(NSError *error) {
}];
```

The client keeps a local cache of documents sent by the server. These can be accessed through the `METDatabase` and `METCollection` classes. Documents are represented by `METDocument`s and identified by a `METDocumentKey`. (Keys encapsulate a `collectionName` and `documentID`). 

A document stored in the local cache can be accessed using `METDatabase#documentWithKey:`. Alternatively, documents can be accessed by documentID through the collection:
``` objective-c
METCollection *players = [database collectionWithName:@"players"];
METDocument *lovelace = [players documentWithID:@"lovelace"];
````

All documents in a collection can be accessed as an NSArray:
``` objective-c
METCollection *players = [database collectionWithName:@"players"];
NSArray *allPlayers = [players allDocuments];
````

(More complex fetches will be supported by passing a `METFetchRequest` to `METDatabase#executeFetchRequest:`, but this has not been implemented yet.)

`METDocument`s are immutable and data can only be modified through method invocations. Collections are used to encapsulate modification method invocations:

``` objective-c
METCollection *players = [database collectionWithName:@"players"];
id documentID = [players insertDocumentWithFields:@{@"name": @"Ada Lovelace", @"score": @25}];
[players updateDocumentWithID:documentID changedFields:@{@"score": @30, @"color": [NSNull null]}];
[players removeDocumentWithID:@"gauss"];
````

Under the hood, the above code calls three methods on the server, modifying the local cache through a predefined stub in the process.

Unless specified explicitly, document IDs are randomly generated on the client and a shared `randomSeed` is included with the `method` DDP message to keep generated IDs synchronized between client and server even in complex scenarios (such as method stubs recursively calling other stubs).

Data access and modification should be thread safe. The local cache supports concurrent reads and blocking writes. (Note that using Core Data will not allow you to take advantage of concurrent reads however, because `NSPersistentStoreCoordinator` serializes access.)

### Change Notifications

``` objective-c
- (void)databaseDidChange:(NSNotification *)notification {
  METDatabaseChanges *databaseChanges = notification.userInfo[METDatabaseChangesKey];
  [databaseChanges enumerateDocumentChangeDetailsUsingBlock:^(METDocumentChangeDetails *documentChangeDetails, BOOL *stop) {
    ...
  }];
}
```

A `METDatabaseDidChangeNotification` contains a `METDatabaseChanges` object that can be asked for information about the changes that occurred. Information about changes to an individual document is encapsulated in a `METDocumentChangeDetails`. (This mechanism is modeled somewhat after the `PHChange` and `PHObjectChangeDetails` classes used by the iOS 8 Photos framework.)

A `METDocumentChangeDetails` knows its `fieldsBeforeChanges` and `fieldsAfterChanges`, and can also be asked for the `changedFields`. It reflects the changes to a document since the last notification. Changes are consolidated and a `METDocumentChangeDetails` is only included if the fields before and after are actually different. If a document is first added and then removed, or if a field is changed back to its original value, before the notification is posted, no `METDocumentChangeDetails` is created and a `METDatabaseDidChangeNotification` may not be posted.

Data updates from the server are buffered and applied in batches. Buffering uses a GCD dispatch source to coalesce events, meaning data updates that arrive before the buffer has had a chance to be flushed will be applied together.

Method invocations that change documents will also post a `METDatabaseDidChangeNotification`. If a stub has been defined, changes to the local cache are posted first and another notification will only be posted when server updates have been flushed (and if the effects are different from that of the stub).

`METDatabase#performUpdates:` can be used to group batches of updates to only post a single `METDatabaseDidChangeNotification` (or none if no net changes have occured, like below):
``` objective-c
[database performUpdates:^{
  id documentID = [collection insertDocumentWithFields:@{@"name": @"Ada Lovelace", @"score": @25}];
  [collection updateDocumentWithID:documentID changedFields:@{@"score": @30, @"color": [NSNull null]}];
  [collection removeDocumentWithID:documentID];
}];
```

### Custom methods

Methods are called on `METDDPClient` and an optional `completionHandler` can be specified to receive a result:
``` objective-c
[client callMethodWithName:@"doSomething" parameters:@[@"someParameter"] completionHandler:^(id result, NSError *error) {
  ...
}];
```

If a stub has been defined, it will be executed first and could call more methods in the process (and so on). If at any point a data modification method is called, it will make changes to the local cache and participate in latency compensation:
``` objective-c
[client defineStubForMethodWithName:@"doSomething" usingBlock:^id(NSArray *parameters) {
  [[client.database collectionWithName:@"players"] updateDocumentWithID:@"lovelace" changedFields:@{@"score": @20}];
  return nil;
}];
```

### Core Data

The easiest way to use Core Data is through `METCoreDataDDPClient`, a `METDDPClient` subclass that encapsulates the Core Data stack and adds some additional functionality. It allows you to pass parameters of type `NSManagedObject` or `NSManagedObjectID` to `addSubscriptionWithName:parameters:` or `callMethodWithName:parameters:`, and will convert them to a document ID.

`METIncrementalStore` is an `NSIncrementalStore` subclass that handles Core Data fetch and save requests by delegating these to Meteor. A managed object model is mapped automatically to a document model (although a different `fieldName` can be specified in the `userInfo` of a property in Xcode). All types of relationships – one-to-one, one-to-many and many-to-many – are supported.

Currently, all relationships are expected to be defined on both sides, and documents on both sides should contain relationship details and be kept in sync.

In `players` collection:
``` json
{ "_id": "lovelace", "name": "Ada Lovelace", "sentMessageIds": ["message1", "message2"], "receivedMessageIds": ["message3", "message4"]}
{ "_id": "gauss", "name": "Carl Friedrich Gauss", "sentMessageIds": ["message3"], "receivedMessageIds": ["message1", "message2"]}
```

In `messages` collection:
``` json
{ "_id": "message1", "body": "Hello!", "senderId": "lovelace", "receiverIds": ["gauss", "shannon"] }
{ "_id": "message2", "body": "Hello!", "senderId": "lovelace", "receiverIds": ["gauss", "turing"] }
{ "_id": "message3", "body": "Hello!", "senderId": "gauss", "receiverIds": ["lovelace", "crick"] }
```

Using Core Data to save objects will take care of this automatically. If you change one side of a many-to-many relationship for instance, changes will also be made to all other documents participating in the relationship. This probably has to be revisited based on practical usage scenarios, but seems to work well as a default at the moment.

`METIncrementalStore` observes `METDatabaseDidChangeNotification` and will post `METIncrementalStoreObjectsDidChangeNotification` if a database change leads to changes to objects. The `userInfo` of the notification contains values for `NSInsertedObjectsKey`, `NSUpdatedObjectsKey` and `NSDeletedObjectsKey`. Although these contain `NSManagedObjectID`s instead of the `NSManagedObject`s `NSManagedObjectContextObjectsDidChangeNotification` contains, a little trick allows us to still use `mergeChangesFromContextDidSaveNotification` on a context. The trick is to translate the notification to `NSPersistentStoreDidImportUbiquitousContentChangesNotification`, which is used by iCloud for the same purpose:

``` objective-c
- (void)objectsDidChange:(NSNotification *)notification {
  [_mainQueueManagedObjectContext performBlock:^{
    // Use NSPersistentStoreDidImportUbiquitousContentChangesNotification to allow object IDs in the userInfo for mergeChangesFromContextDidSaveNotification
    [_mainQueueManagedObjectContext mergeChangesFromContextDidSaveNotification:[[NSNotification alloc] initWithName:NSPersistentStoreDidImportUbiquitousContentChangesNotification object:notification.object userInfo:notification.userInfo]];
  }];
}
```

The way Core Data fetching has been implemented is fairly naive and really inefficient. All documents in a given collection are instantiated as `NSManagedObject`s before a `predicate` and `sortDescriptors` are applied. At least some of this work should be offloaded to the local cache, so we only have to perform further processing on a subset of documents.

### Accounts

Support for accounts is very basic at the moment and will be improved soon. Only logging with email/password has been implemented so far:

``` objective-c
[client loginWithEmail:@"martijn@martijnwalraven.com" password:@"correct" completionHandler:^(NSError *error) {
  ...
}];
```

This calls the login method (which acts as a barrier so no other methods can execute concurrently) and sets the `account` property on `METDDPClient`. A `METAccount` encapsulates a `userID`, `resumeToken` and `expiryDate`. This information is used to log in automatically on reconnection (the login method is sent before other in-progress methods). In the future, accounts should survive app restarts and will be stored in the Keychain. Services like Facebook and Twitter should also be supported and preferrably integrate with iOS `ACAccount`s so users don't have to supply login credentials but only have to give permission to link the account.

## Author

- [Martijn Walraven](http://github.com/martijnwalraven) ([@martijnwalraven](https://twitter.com/martijnwalraven))

## License

Meteor for iOS is available under the MIT license. See the LICENSE file for more info.