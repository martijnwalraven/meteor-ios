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

#import <XCTest/XCTest.h>
#import "XCTAsyncTestCase.h"

#import "METMethodInvocationCoordinator.h"
#import "METMethodInvocationCoordinator_Testing.h"

#import "METMethodInvocation.h"
#import "METMethodInvocation_Internal.h"
#import "METDatabaseChanges.h"
#import "METDatabaseChanges_Internal.h"
#import "METDocumentKey.h"
#import "METBufferedDocument.h"
#import "METDataUpdate.h"

@interface METMethodInvocationCoordinatorTests : XCTAsyncTestCase

@end

@implementation METMethodInvocationCoordinatorTests {
  METMethodInvocationCoordinator *_coordinator;
}

- (void)setUp {
  [super setUp];
  
  _coordinator = [[METMethodInvocationCoordinator alloc] initWithClient:nil];
}

- (void)tearDown {
  [super tearDown];
}

#pragma mark - Queuing Method Invocations

- (void)testDoesntExecuteMethodInvocationWhenSuspended {
  XCTAssertTrue(_coordinator.suspended);
  
  METMethodInvocation *methodInvocation = [[METMethodInvocation alloc] init];
  [_coordinator addMethodInvocation:methodInvocation];
  
  [self waitForTimeInterval:0.1];
  
  XCTAssertFalse(methodInvocation.isExecuting);
}

- (void)testExecutesQueuedMethodInvocationWhenNoLongerSuspended {
  METMethodInvocation *methodInvocation = [[METMethodInvocation alloc] init];
  [_coordinator addMethodInvocation:methodInvocation];
  
  [self keyValueObservingExpectationForObject:methodInvocation keyPath:@"isExecuting" expectedValue:[NSNumber numberWithBool:YES]];
  
  _coordinator.suspended = NO;
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testRemovesMethodInvocationWhenBothResultReceivedAndUpdatesAreFlushed {
  _coordinator.suspended = NO;
  
  METMethodInvocation *methodInvocation = [[METMethodInvocation alloc] init];
  [self keyValueObservingExpectationForObject:methodInvocation keyPath:@"isExecuting" expectedValue:[NSNumber numberWithBool:YES]];
  [_coordinator addMethodInvocation:methodInvocation];
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  [self keyValueObservingExpectationForObject:methodInvocation keyPath:@"isFinished" expectedValue:[NSNumber numberWithBool:YES]];
  
  [methodInvocation didReceiveResult:nil error:nil];
  [methodInvocation didFlushUpdates];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertFalse(methodInvocation.isExecuting);
  XCTAssertEqual(0, _coordinator.operationQueue.operationCount);
}

- (void)testMethodInvocationsAreExecutedConcurrently {
  _coordinator.suspended = NO;
  
  METMethodInvocation *methodInvocation1 = [[METMethodInvocation alloc] init];
  methodInvocation1.name = @"methodInvocation1";
  METMethodInvocation *methodInvocation2 = [[METMethodInvocation alloc] init];
  methodInvocation2.name = @"methodInvocation2";
  
  [self keyValueObservingExpectationForObject:methodInvocation1 keyPath:@"isExecuting" expectedValue:[NSNumber numberWithBool:YES]];
  [self keyValueObservingExpectationForObject:methodInvocation2 keyPath:@"isExecuting" expectedValue:[NSNumber numberWithBool:YES]];
  
  [_coordinator addMethodInvocation:methodInvocation1];
  [_coordinator addMethodInvocation:methodInvocation2];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testBarrierMethodInvocationsWaitForPreviousMethodInvocationsToFinish {
  _coordinator.suspended = NO;
  
  METMethodInvocation *methodInvocation1 = [[METMethodInvocation alloc] init];
  methodInvocation1.name = @"methodInvocation1";
  [_coordinator addMethodInvocation:methodInvocation1];
  METMethodInvocation *methodInvocation2 = [[METMethodInvocation alloc] init];
  methodInvocation2.name = @"methodInvocation2";
  [_coordinator addMethodInvocation:methodInvocation2];
  
  METMethodInvocation *barrierMethodInvocation = [[METMethodInvocation alloc] init];
  barrierMethodInvocation.name = @"barrierMethodInvocation";
  barrierMethodInvocation.barrier = YES;
  [_coordinator addMethodInvocation:barrierMethodInvocation];
  
  [self keyValueObservingExpectationForObject:barrierMethodInvocation keyPath:@"isExecuting" expectedValue:[NSNumber numberWithBool:YES]];
  
  [self finishMethodInvocation:methodInvocation1];
  [self finishMethodInvocation:methodInvocation2];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testBarrierMethodInvocationsBlockNextMethodInvocationsUntilFinished {
  _coordinator.suspended = NO;
  
  METMethodInvocation *barrierMethodInvocation = [[METMethodInvocation alloc] init];
  barrierMethodInvocation.name = @"barrierMethodInvocation";
  barrierMethodInvocation.barrier = YES;
  [_coordinator addMethodInvocation:barrierMethodInvocation];
  
  METMethodInvocation *methodInvocation1 = [[METMethodInvocation alloc] init];
  methodInvocation1.name = @"methodInvocation1";
  [_coordinator addMethodInvocation:methodInvocation1];
  METMethodInvocation *methodInvocation2 = [[METMethodInvocation alloc] init];
  methodInvocation2.name = @"methodInvocation2";
  [_coordinator addMethodInvocation:methodInvocation2];
  
  [self keyValueObservingExpectationForObject:methodInvocation1 keyPath:@"isExecuting" expectedValue:[NSNumber numberWithBool:YES]];
  [self keyValueObservingExpectationForObject:methodInvocation2 keyPath:@"isExecuting" expectedValue:[NSNumber numberWithBool:YES]];
  
  [self finishMethodInvocation:barrierMethodInvocation];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)testResettingAllowsBlockToAddMethodInvocationsToTheFrontOfTheQueue {
  _coordinator.suspended = NO;
  
  METMethodInvocation *methodInvocation1 = [[METMethodInvocation alloc] init];
  methodInvocation1.name = @"methodInvocation1";
  [_coordinator addMethodInvocation:methodInvocation1];
  
  METMethodInvocation *barrierMethodInvocation = [[METMethodInvocation alloc] init];
  barrierMethodInvocation.name = @"barrierMethodInvocation";
  barrierMethodInvocation.barrier = YES;
  
  [self keyValueObservingExpectationForObject:barrierMethodInvocation keyPath:@"isExecuting" expectedValue:[NSNumber numberWithBool:YES]];
  
  [_coordinator resetWhileAddingMethodInvocationsToTheFrontOfTheQueueUsingBlock:^{
    [_coordinator addMethodInvocation:barrierMethodInvocation];
  }];
  
  _coordinator.suspended = NO;
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertFalse([_coordinator methodInvocationWithName:@"methodInvocation1"].isExecuting);
}

#pragma mark - Buffering Documents Affected By Stubs

- (void)testAddingMethodInvocationsBuffersDocumentsAffectedByStubs {
  _coordinator.suspended = NO;
  
  METMethodInvocation *methodInvocation1 = [self methodInvocationWithChangesPerformedByStub:^(METDatabaseChanges *changes) {
    [changes willChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"lovelace"] fieldsBeforeChanges:@{@"name": @"Ada Lovelace", @"score": @25}];
  }];
  [self keyValueObservingExpectationForObject:methodInvocation1 keyPath:@"messageSent" expectedValue:[NSNumber numberWithBool:YES]];
  [_coordinator addMethodInvocation:methodInvocation1];
  
  METMethodInvocation *methodInvocation2 = [self methodInvocationWithChangesPerformedByStub:^(METDatabaseChanges *changes) {
    [changes willChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"lovelace"] fieldsBeforeChanges:@{@"name": @"Ada Lovelace", @"score": @20}];
  }];
  [self keyValueObservingExpectationForObject:methodInvocation2 keyPath:@"messageSent" expectedValue:[NSNumber numberWithBool:YES]];
  [_coordinator addMethodInvocation:methodInvocation2];
  
  [self waitForExpectationsWithTimeout:1.0 handler:nil];
  
  XCTAssertEqualObjects((@{@"name": @"Ada Lovelace", @"score": @25}), [_coordinator bufferedDocumentForKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"lovelace"]].fields);
  
  XCTAssertNotNil([_coordinator bufferedDocumentForKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"lovelace"]]);
  
  [_coordinator didReceiveUpdatesDoneForMethodID:methodInvocation1.methodID];
  
  XCTAssertNotNil([_coordinator bufferedDocumentForKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"lovelace"]]);
  
  [_coordinator didReceiveUpdatesDoneForMethodID:methodInvocation2.methodID];
  
  XCTAssertNil([_coordinator bufferedDocumentForKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"lovelace"]]);
}

- (void)testApplyingDataUpdatesChangesFieldsOfBufferedDocuments {
  _coordinator.suspended = NO;
  
  [_coordinator addMethodInvocation:[self methodInvocationWithChangesPerformedByStub:^(METDatabaseChanges *changes) {
    [changes willChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"lovelace"] fieldsBeforeChanges:nil];
    [changes willChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"gauss"] fieldsBeforeChanges:@{@"name": @"Carl Friedrich Gauss", @"score": @5, @"color": @"blue"}];
    [changes willChangeDocumentWithKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"shannon"] fieldsBeforeChanges:@{@"name": @"Claude Shannon", @"score": @10}];
  }]];
  
  [_coordinator applyDataUpdate:[[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeAdd documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"lovelace"] fields:@{@"name": @"Ada Lovelace", @"score": @25}]];
  [_coordinator applyDataUpdate:[[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeChange documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"gauss"] fields:@{@"score": @10, @"color": [NSNull null]}]];
  [_coordinator applyDataUpdate:[[METDataUpdate alloc] initWithUpdateType:METDataUpdateTypeRemove documentKey:[METDocumentKey keyWithCollectionName:@"players" documentID:@"shannon"] fields:nil]];
  
  XCTAssertEqualObjects((@{@"name": @"Ada Lovelace", @"score": @25}), [_coordinator bufferedDocumentForKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"lovelace"]].fields);
  XCTAssertEqualObjects((@{@"name": @"Carl Friedrich Gauss", @"score": @10}), [_coordinator bufferedDocumentForKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"gauss"]].fields);
  XCTAssertNil([_coordinator bufferedDocumentForKey:[METDocumentKey keyWithCollectionName:@"players" documentID: @"shannon"]].fields);
}

#pragma mark - Helper Methods

- (void)finishMethodInvocation:(METMethodInvocation *)methodInvocation {
  [methodInvocation didReceiveResult:nil error:nil];
  [methodInvocation didFlushUpdates];
}

- (METMethodInvocation *)methodInvocationWithChangesPerformedByStub:(void (^)(METDatabaseChanges *changes))block; {
  METDatabaseChanges *changes = [[METDatabaseChanges alloc] init];
  block(changes);
  METMethodInvocation *methodInvocation = [[METMethodInvocation alloc] init];
  methodInvocation.changesPerformedByStub = changes;
  return methodInvocation;
}

@end
