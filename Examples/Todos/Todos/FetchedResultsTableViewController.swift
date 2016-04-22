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

import UIKit
import CoreData
import Meteor

class FetchedResultsTableViewController: UITableViewController, ContentLoading, SubscriptionLoaderDelegate, FetchedResultsTableViewDataSourceDelegate {
  // MARK: - Lifecycle
  
  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(self)
  }
  
  // MARK: - Model
  
  var managedObjectContext: NSManagedObjectContext!
  
  func saveManagedObjectContext() {
    var error: NSError?
    do {
      try managedObjectContext!.save()
    } catch let error1 as NSError {
      error = error1
      print("Encountered error saving managed object context: \(error)")
    }
  }
  
  // MARK: - View Lifecyle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    updatePlaceholderView()
  }
  
  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    
    loadContentIfNeeded()
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    placeholderView?.frame = tableView.bounds
  }
  
  // MARK: - Content Loading
  
  private(set) var contentLoadingState: ContentLoadingState = .Initial  {
    didSet {
      if isViewLoaded() {
        updatePlaceholderView()
      }
    }
  }
  
  var isContentLoaded: Bool {
    switch contentLoadingState {
    case .Loaded:
      return true
    default:
      return false
    }
  }
  
  private(set) var needsLoadContent: Bool = true
  
  func setNeedsLoadContent() {
    needsLoadContent = true
    if isViewLoaded() {
      loadContentIfNeeded()
    }
  }
  
  func loadContentIfNeeded() {
    if needsLoadContent {
      loadContent()
    }
  }
  
  func loadContent() {
    needsLoadContent = false
    
    subscriptionLoader = SubscriptionLoader()
    subscriptionLoader!.delegate = self

    configureSubscriptionLoader(subscriptionLoader!)
    
    subscriptionLoader!.whenReady { [weak self] in
      self?.setUpDataSource()
      self?.contentLoadingState = .Loaded
    }
    
    if !subscriptionLoader!.isReady {
      if Meteor.connectionStatus == .Offline {
        contentLoadingState = .Offline
      } else {
        contentLoadingState = .Loading
      }
    }
  }
  
  func resetContent() {
    dataSource = nil
    tableView.dataSource = nil
    tableView.reloadData()
    subscriptionLoader = nil
    contentLoadingState = .Initial
  }
  
  private var subscriptionLoader: SubscriptionLoader?
  
  func configureSubscriptionLoader(subscriptionLoader: SubscriptionLoader) {
  }
  
  var dataSource: FetchedResultsTableViewDataSource!
  
  func setUpDataSource() {
    if let fetchedResultsController = createFetchedResultsController() {
      dataSource = FetchedResultsTableViewDataSource(tableView: tableView, fetchedResultsController: fetchedResultsController)
      dataSource.delegate = self
      tableView.dataSource = dataSource
      dataSource.performFetch()
    }
  }
  
  func createFetchedResultsController() -> NSFetchedResultsController? {
    return nil
  }
  
  // MARK: SubscriptionLoaderDelegate
  
  func subscriptionLoader(subscriptionLoader: SubscriptionLoader, subscription: METSubscription, didFailWithError error: NSError) {
    contentLoadingState = .Error(error)
  }
  
  // MARK: Connection Status Notification
  
  func connectionStatusDidChange() {
    if !isContentLoaded && Meteor.connectionStatus == .Offline {
      contentLoadingState = .Offline
    }
  }
  
  // MARK: - User
  
  var currentUser: User? {
    if let userID = Meteor.userID {
      let userObjectID = Meteor.objectIDForDocumentKey(METDocumentKey(collectionName: "users", documentID: userID))
      return (try? managedObjectContext.existingObjectWithID(userObjectID)) as? User
    }
    return nil;
  }
  
  // MARK: - Placeholder View
  
  private var placeholderView: PlaceholderView?
  private var savedCellSeparatorStyle: UITableViewCellSeparatorStyle = .None
  
  func updatePlaceholderView() {
    if isContentLoaded {
      if placeholderView != nil {
        placeholderView?.removeFromSuperview()
        placeholderView = nil
        swap(&savedCellSeparatorStyle, &tableView.separatorStyle)
      }
    } else {
      if placeholderView == nil {
        placeholderView = PlaceholderView()
        tableView.addSubview(placeholderView!)
        swap(&savedCellSeparatorStyle, &tableView.separatorStyle)
      }
    }
    
    switch contentLoadingState {
    case .Loading:
      placeholderView?.showLoadingIndicator()
    case .Offline:
      placeholderView?.showTitle("Could not establish connection to server", message: nil)
    case .Error(let error):
      placeholderView?.showTitle(error.localizedDescription, message: error.localizedFailureReason)
    default:
      break
    }
  }
  
  // MARK: - FetchedResultsTableViewDataSourceDelegate
  
  func dataSource(dataSource: FetchedResultsTableViewDataSource, didFailWithError error: NSError) {
    print("Data source encountered error: \(error)")
  }
}
