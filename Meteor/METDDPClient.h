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

#import <Foundation/Foundation.h>

#import "METSubscription.h"

@class METDDPConnection;
@class METDatabase;
@protocol METDDPClientDelegate;
@class METAccount;

extern NSString * const METDDPErrorDomain;
typedef NS_ENUM(NSInteger, METDDPErrorType) {
  METDDPServerError = 0,
  METDDPVersionError,
};

typedef NS_ENUM(NSInteger, METDDPConnectionStatus) {
  METDDPConnectionStatusOffline = 0,
  METDDPConnectionStatusConnecting,
  METDDPConnectionStatusFailed,
  METDDPConnectionStatusWaiting,
  METDDPConnectionStatusConnected
};

extern NSString * const METDDPClientDidChangeConnectionStatusNotification;
extern NSString * const METDDPClientDidChangeAccountNotification;

typedef id (^METMethodStub)(NSArray *parameters);
typedef void (^METMethodCompletionHandler)(id result, NSError *error);

typedef void (^METLogInCompletionHandler)(NSError *error);
typedef void (^METLogOutCompletionHandler)(NSError *error);

@interface METDDPClient : NSObject

- (instancetype)initWithConnection:(METDDPConnection *)connection;
- (instancetype)initWithServerURL:(NSURL *)serverURL;

@property(weak, nonatomic) id<METDDPClientDelegate> delegate;

- (void)connect;
- (void)disconnect;

@property (assign, nonatomic, readonly, getter=isConnected) BOOL connected;
@property (assign, nonatomic, readonly) METDDPConnectionStatus connectionStatus;

@property (strong, nonatomic, readonly) METDatabase *database;

- (METSubscription *)addSubscriptionWithName:(NSString *)name;
- (METSubscription *)addSubscriptionWithName:(NSString *)name completionHandler:(METSubscriptionCompletionHandler)completionHandler;
- (METSubscription *)addSubscriptionWithName:(NSString *)name parameters:(NSArray *)parameters;
- (METSubscription *)addSubscriptionWithName:(NSString *)name parameters:(NSArray *)parameters completionHandler:(METSubscriptionCompletionHandler)completionHandler;
- (void)removeSubscription:(METSubscription *)subscription;

- (void)defineStubForMethodWithName:(NSString *)methodName usingBlock:(METMethodStub)block;
- (id)callMethodWithName:(NSString *)methodName parameters:(NSArray *)parameters completionHandler:(METMethodCompletionHandler)completionHandler;
- (id)callMethodWithName:(NSString *)methodName parameters:(NSArray *)parameters;

@property (assign, nonatomic, readonly, getter=isLoggingIn) BOOL loggingIn;
@property (copy, nonatomic, readonly) NSString *userID;

- (void)logoutWithCompletionHandler:(METLogOutCompletionHandler)completionHandler;

@end

@protocol METDDPClientDelegate <NSObject>

@optional

- (void)clientDidEstablishConnection:(METDDPClient *)client;
- (void)client:(METDDPClient *)client didFailWithError:(NSError *)error;

@end
