# Meteor for iOS

Meteor for iOS is work in progress, but aims to be a complete DDP client that includes full support for latency compensation and offers Core Data integration. It keeps as close as possible to the semantics of the original JavaScript code, but its design is more in line with Cocoa and Objective-C conventions (although it is perfectly usable from Swift). It has been implemented with concurrent execution in mind and keeps all processing off the main thread, posting batched and consolidated change notifications that can be observed to update the UI. It includes over 200 unit tests and also has some server integration tests that run using a local Meteor test server.

It is in dire need of better documentation, but is already fairly feature complete and seems to work pretty well. For now, the included Todos example (written in Swift, for both iPhone and iPad) is probably the best way to get an understanding of its abilities. If you want to try it out, you should be able to open the Meteor workspace and run the Todos scheme. It connects to a Meteor example app running at http://meteor-ios-todos.meteor.com. If you want to get a quick idea of what it's capable of you may want to have a look at this short screen recording:

[![Meteor for iOS — Todos example](http://img.youtube.com/vi/qWJ2bgg8xxo/0.jpg)](http://www.youtube.com/watch?v=qWJ2bgg8xxo)

## Features

- Full support for latency compensation, faithfully (I hope) reproducing the semantics of the original JavaScript code. Modifications to documents are reflected immediately in the local cache and will be ammended by server changes only when the server completes sending data updates for the method (multiple methods concurrently modifying the same documents are handled correctly).
- Posting batched and consolidated change notifications at appropriate times, instead of relying on fine grained updates. This helps keep UI work on the main thread to a minimum without sacrificing responsiveness.
- Core Data integration using an `NSIncrementalStore` subclass. Mapping between documents and `NSManagedObject`s is performed automatically (but can be customized). Different types of relationships are also supported, both for fetching and saving (with configurable storage). Modifications made to documents (possibly from other clients) will lead to the posting of an object change notification that is used to merge changes into `NSManagedObjectContext`s.
- Subscriptions are shared and reused whenever possible. If a subscription is no longer in use, we don't actually unsubscribe until after a configurable timeout. This means data won't have to be removed and added if it is needed again later.
- Correct handling of reconnection. Data updates on the new connection will be buffered until all subscriptions that were ready before have become ready again. Only then are updates applied and is a change notification posted (if anything actually changed).

### Swift

Although the framework has been written in Objective-C, it works well with Swift. In fact, both the Todos example and a larger project I work on myself exclusively use Swift. In the future, I plan on updating the API to take better advantage of Swift language features. I'm also planning on including (and documenting!) some utility code written in Swift extracted from the Todos example and my own project code.

I had already started work on this project when Swift was announced. Although I'm impressed by Swift, I decided it was too soon to consider a rewrite. The language was and is evolving, and some potentially useful language features are still missing (in particular around generics and protocols). Performance can be unpredictable (especially when dealing with arrays and dictionaries) and tool support (Xcode) is not as stable as it is for Objective-C. Once the Swift language and implementation stabilize and language idioms become established, a complete or partial rewrite might be a viable option.


## Overview

I'm still figuring out usage patterns and I'm actively improving the API. I'm using it with Swift and Core Data in my own projects, so that's what I'll mostly be describing here. You can also use the API at a lower level and deal with documents directly though. Don't expect anything to be stable yet, but please do let me know what you think of it and what improvements you would like to see.

Basic usage is actually pretty simple:

- Initialize a `METCoreDataDDPClient` with a WebSocket server URL and call its `connect` method. It is often convenient to set the client up as a singleton so you can access it from anywhere.
- Call `addSubscriptionWithName:parameters:` at any time to invoke a publish function on the server and receive a specific set of documents. (If you use `autopublish`, the Meteor server will publish all of its collections automatically, without the need to subscribe. It has serious downsides, but can be great to get started during development.)
- You'll need to set up a managed object model in Xcode, as you would normally do when using Core Data. Entities correspond to collections (with an automatic singular-plural name mapping a la Rails), and properties to fields. The default mapping will often work fine, but you can specify a different `collectionName` or `fieldName` as `userInfo` in the model editor. All types of relationships – one-to-one, one-to-many and many-to-many – are supported. By default, references are stored in documents on both sides ([two-way referencing](http://blog.mongodb.org/post/87892923503/6-rules-of-thumb-for-mongodb-schema-design-part-2)). But you can specify `storage = false` as `userInfo` for a relationship end in the model editor.
- You can now use normal Core Data methods to access and modify documents. The client keeps a `mainQueueManagedObjectContext` and automatically merges changes, which is often what you need, but more complex setups (e.g. background contexts, child contexts) are also possible.
- If you use `NSFetchedResultsController`, all changes that affect the specified fetch request will be propagated automatically, whether they were made from Core Data, directly to documents, or come from a different client and were sent by the server. You can use this to automatically update a `UITableView` or `UICollectionView` for instance (which  gives you some nifty animations for free). You can of course also observe `NSManagedObjectContextDidSaveNotification` notifications yourself and decide what to do with changes as they happen.
- Changes you make from your own code, either through Core Data or directly to documents, are immediately reflected in the local cache and a change notification is posted (so the UI can be updated). This is known as latency compensation because we don't have to wait for a server response. If a response from the server comes back later and it agrees with the changes, nothing more will happen. But if there are differences, the local cache will be ammended with the changes sent by the server and another change notification will be posted.
- If you call a custom method on the server, you normally have to wait for possible server changes to come back. But you can define your own method stubs (`defineStubForMethodWithName:usingBlock:`) that can make local changes and thus participate in latency compensation.
- If you log in a user (using `loginWithEmail:password:completionHandler` for example), publications on the server that depend on the `userID` will automatically run again and the server will send changes to the document set (if any). (The Todos example uses a `privateLists` publish function for instance, that automatically publishes lists owned by the currently logged in user.)

## Example code

The most convenient way to set up a `METDDPClient` or `METCoreDataDDPClient` in Swift is as a global variable (Swift uses `dispatch_once` under the hood for lazy and thread safe initialization):

``` swift
let Meteor = METCoreDataDDPClient(serverURL: NSURL(string: "wss://meteor-ios-todos.meteor.com/websocket"))

@UIApplicationMain
class AppDelegate: UIApplicationDelegate {
  func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {  
    Meteor.connect()
  }
}
```

### Waiting for subscriptions

The Todos example includes a `SubscriptionLoader` class that can be used used to wait for subscriptions to become ready (similar to the `waitOn` option in Iron Router). Using this in `viewWillAppear` makes it easy to avoid displaying partial data sets (and perhaps show a loading indicator, as in the Todos example). (Subscriptions are shared and reused, so there won't be any extra cost to calling `viewWillAppear` again, and if all subscriptions are loaded when it is called, `whenReady` will be synchronous.)

``` swift
subscriptionLoader.addSubscriptionWithName("publicLists")
subscriptionLoader.addSubscriptionWithName("privateLists")
// Parameter 'list' is an NSManagedObject that will be automatically converted to a documentID
subscriptionLoader.addSubscriptionWithName("todos", parameters: list)

subscriptionLoader.whenReady {
  self.fetchedResultsController.performFetch()
}
```

### Making changes

``` swift
// The managedObjectContext is preferably set as a property on a UIViewController and passed on to the next one to support child contexts
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
```

## Installation with CocoaPods

The easiest way to use Meteor for iOS in your own project is through CocoaPods. Until recently, there was no convenient way to use CocoaPods with Swift. The release of CocoaPods 0.36 promises to change this however, by supporting frameworks (see http://blog.cocoapods.org/Pod-Authors-Guide-to-CocoaPods-Frameworks/). As frameworks are only supported on iOS 8 or higher, this means iOS 7 users are out of luck for now. It should be possible to support both building as a framework and as a static library, but I don't know enough about CocoaPods to get this to work reliably. Input is very welcome!

Because CocoaPods 0.36 has not been officially released, you'll have to install a prerelease version using `gem install cocoapods --pre`.

You can then write a Podfile referencing the 'Meteor' pod:
```
platform :ios, '8.0'
use_frameworks!
pod 'Meteor' 
```

With this Podfile, Meteor for iOS will be built as a framework and is made available as a Clang module that can easily be imported without further configuration (you may need to build the project first before the module is recognized however):

In Objective-C:
``` objective-c
@import Meteor;
```

In Swift:
``` swift
import Meteor
```

## Some implementation details

- Data updates from the server are buffered and applied in batches. Buffering uses a GCD dispatch source to coalesce events, meaning data updates that arrive before the buffer has had a chance to be flushed will be applied together.
- Unless specified explicitly, document IDs are randomly generated on the client and a shared `randomSeed` is included with the `method` DDP message to keep generated IDs synchronized between client and server even in complex scenarios (such as method stubs recursively calling other stubs).
- Data access and modification should be thread safe. The local cache supports concurrent reads and blocking writes. (Note that using Core Data will not allow you to take advantage of concurrent reads however, because `NSPersistentStoreCoordinator` serializes access.)
- Calls to login methods act as a barrier so no other methods can execute concurrently. On reconnection, if logged in before, a login method with a resume token is sent before other in-progress methods. In the future, accounts should also survive app restarts and will be stored in the Keychain. Services like Facebook and Twitter should also be supported and preferrably integrate with iOS `ACAccount`s so users don't have to supply login credentials but only have to give permission to link the account.
- When the connection to the server is lost (detected either through connection close, network error or failed DDP heartbeat), the client automatically atempts to reconnect. If the reconnect isn't succesful, it is tried repeatedly using an exponential backoff (with a randomization factor). The client also listens for network reachability changes and doesn't reconnect repeatedly when the network isn't reachable. It attempts to reconnect immediately when the network seems to have become reachable again.
- When an app moves to the background, the connection isn't closed immediately but kept alive as long as possible (this is ultimately decided by the OS, but currently means 180 seconds). If the connection is lost while in the background, no attempts to reconnect are made. Moving the app to the foreground however, always immediately attempts to reconnect.
- Currently, all Core Data relationships are expected to be defined on both sides, and documents on both sides should contain relationship details and be kept in sync. Using Core Data to save objects will take care of this automatically. If you change one side of a many-to-many relationship for instance, changes will also be made to all other documents participating in the relationship. This probably has to be revisited based on practical usage scenarios, but seems to work well as a default at the moment.
- The way Core Data fetching has been implemented is fairly naive and although usable seems really inefficient. All documents in a given collection are instantiated as `NSManagedObject`s before a `predicate` and `sortDescriptors` are applied. At least some of this work should be offloaded to the local cache, so we only have to perform further processing on a subset of objects. This isn't easy however, if we want to support predicates referring to relationships at the model level.

## Author

- [Martijn Walraven](http://github.com/martijnwalraven) ([martijn@martijnwalraven.com](mailto:martijn@martijnwalraven.com), [@martijnwalraven](https://twitter.com/martijnwalraven))

## License

Meteor for iOS is available under the MIT license. See the LICENSE file for more info.

The Todos example contains icons provided by [Icons8](http://icons8.com) under the [Creative Commons Attribution-NoDerivs 3.0 Unported license](https://creativecommons.org/licenses/by-nd/3.0/).
