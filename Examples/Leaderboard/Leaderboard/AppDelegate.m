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

#import "AppDelegate.h"

@import Meteor;
#import "PlayersTableViewController.h"

@implementation AppDelegate {
  METCoreDataDDPClient *_client;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
#if TARGET_IPHONE_SIMULATOR
  NSString *serverURLString = @"ws://localhost:3000/websocket";
#else
  NSString *serverURLString = @"ws://cultivate.ngrok.com/websocket";
#endif
  _client = [[METCoreDataDDPClient alloc] initWithServerURL:[NSURL URLWithString:serverURLString]];
  [_client connect];

  UINavigationController *navigationController = (UINavigationController *)self.window.rootViewController;
  PlayersTableViewController *playersTableViewController = (PlayersTableViewController *)navigationController.topViewController;
  playersTableViewController.managedObjectContext = _client.mainQueueManagedObjectContext;

  return YES;
}

@end
