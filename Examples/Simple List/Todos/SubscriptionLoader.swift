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

import Meteor

protocol SubscriptionLoaderDelegate: class {
  func subscriptionLoader(subscriptionLoader: SubscriptionLoader, subscription: METSubscription, didFailWithError error: NSError)
}

class SubscriptionLoader {
  weak var delegate: SubscriptionLoaderDelegate? = nil
  private var subscriptions: [METSubscription] = []
  
  deinit {
    removeAllSubscriptions()
  }
  
  func addSubscriptionWithName(name: String, parameters: AnyObject...) -> METSubscription {
    let subscription = Meteor.addSubscriptionWithName(name, parameters: parameters)
    subscription.whenDone { (error) -> Void in
      if let error = error {
        self.delegate?.subscriptionLoader(self, subscription: subscription, didFailWithError: error)
      }
    }
    subscriptions.append(subscription)
    return subscription
  }
  
  func removeAllSubscriptions() {
    for subscription in subscriptions {
      Meteor.removeSubscription(subscription)
    }
  }
  
  var isReady: Bool {
    return all(subscriptions, {$0.ready})
  }
  
  func whenReady(handler: () -> Void) {
    // Invoke completion handler synchronously if we're ready now
    if isReady {
      handler()
      return
    }
    
    let group = dispatch_group_create()
    for subscription in subscriptions {
      dispatch_group_enter(group)
      subscription.whenDone { (error) -> Void in
        dispatch_group_leave(group)
      }
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), handler)
  }
}
