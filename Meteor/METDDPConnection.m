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

#import "METDDPConnection.h"

#import "METRetryStrategy.h"
#import "METTimer.h"
#import "METEJSONSerialization.h"

NS_INLINE BOOL METShouldLogDDPMessages() {
  return [[NSUserDefaults standardUserDefaults] boolForKey:@"METShouldLogDDPMessages"];
}

@interface METDDPConnection ()

@end

@implementation METDDPConnection {
  PSWebSocket *_webSocket;
  NSTimeInterval _timeoutInterval;
}

- (instancetype)initWithServerURL:(NSURL *)serverURL {
  self = [super init];
  if (self) {
    _serverURL = serverURL;
    _timeoutInterval = 5.0;
  }
  return self;
}

- (void)open {
  NSLog(@"Connecting to DDP server at URL: %@", _serverURL);
  
  NSURLRequest *request = [NSURLRequest requestWithURL:_serverURL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:_timeoutInterval];
  _webSocket = [PSWebSocket clientSocketWithRequest:request];
  _webSocket.delegate = self;
  [_webSocket open];
}

- (void)setDelegateQueue:(dispatch_queue_t)delegateQueue {
  _delegateQueue = delegateQueue;
  _webSocket.delegateQueue = delegateQueue;
}

- (void)close {
  [_webSocket close];
}

- (BOOL)isOpen {
  return _webSocket.readyState == PSWebSocketReadyStateOpen;
}

- (void)sendMessage:(NSDictionary *)message {
  NSAssert(self.open, @"Attempting to send message without an open connection");
  
  NSError *error;
  message = [message mutableCopy];
  [self convertTypesToEJSONForMessage:(NSMutableDictionary *)message];
  NSData *data = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
  if (data) {
    if (METShouldLogDDPMessages()) {
      NSLog(@"> %@", message);
    }
    [_webSocket send:data];
  } else {
    [_delegate connection:self didFailWithError:error];
  }
}

#pragma mark - PSWebSocketDelegate

- (void)webSocketDidOpen:(PSWebSocket *)webSocket {
  [_delegate connectionDidOpen:self];
}

- (void)webSocket:(PSWebSocket *)webSocket didReceiveMessage:(id)data {
  if ([data isKindOfClass:[NSString class]]) {
    data = [(NSString *)data dataUsingEncoding:NSUTF8StringEncoding];
  }
  NSError *error;
  NSMutableDictionary *message = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
  if (message) {
    [self convertTypesFromEJSONForMessage:message];
    if (METShouldLogDDPMessages()) {
      NSLog(@"< %@", message);
    }
    [_delegate connection:self didReceiveMessage:message];
  } else {
    [_delegate connection:self didFailWithError:error];
  }
}

- (void)webSocket:(PSWebSocket *)webSocket didFailWithError:(NSError *)error {
  [_delegate connection:self didFailWithError:error];
}

- (void)webSocket:(PSWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
  [_delegate connectionDidClose:self];
}

#pragma mark - EJSON

- (void)convertTypesFromEJSONForMessage:(NSMutableDictionary *)message {
  for (NSString *fieldName in @[@"fields", @"params", @"result"]) {
    id EJSONObject = message[fieldName];
    if (EJSONObject) {
      message[fieldName] = [METEJSONSerialization objectFromEJSONObject:EJSONObject error:nil];
    }
  }
}

- (void)convertTypesToEJSONForMessage:(NSMutableDictionary *)message {
  for (NSString *fieldName in @[@"fields", @"params", @"result"]) {
    id object = message[fieldName];
    if (object) {
      message[fieldName] = [METEJSONSerialization EJSONObjectFromObject:object error:nil];
    }
  }
}

@end
