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

import UIKit
import CoreData
import Meteor

enum ContentLoadingState : Printable{
  case Initial
  case Loading
  case Loaded
  case Error(NSError)
  
  var description: String {
    switch self {
    case Initial:
      return "Initial"
    case Loading:
      return "Loading"
    case Loaded:
      return "Loaded"
    case Error(let error):
      return "Error(\(error))"
    }
  }
}

class FetchedResultsTableViewController: UITableViewController, FetchedResultsChangeObserver {
  // MARK: - Lifecycle
  
  deinit {
    if subscription != nil {
      Meteor.removeSubscription(subscription)
    }
  }
  
  // MARK: - Model Management
  
  var managedObjectContext: NSManagedObjectContext!
  var fetchedResults: FetchedResults! {
    didSet {
      tableView?.reloadData()
    }
  }
  
  func saveManagedObjectContext() {
    var error: NSError?
    if !managedObjectContext!.save(&error) {
      println("Encountered error saving todo: \(error)")
    }
  }
  
  // MARK: - Content Loading
  
  var contentLoadingState: ContentLoadingState = .Initial  {
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
  
  func loadContent() {
  }

  var subscription: METSubscription? {
    willSet {
      if subscription != nil {
        Meteor.removeSubscription(subscription)
      }
    }
    didSet {
      if subscription != nil {
        contentLoadingState = .Loading
        subscription!.completionHandler = { [weak self] (error) -> () in
          if error == nil {
            // Make sure changes are merged with the managed object context
            self?.managedObjectContext.performBlock() {
              // Context may be on a private queue, so make sure subscriptionDidBecomeRead is called on the main thread
              dispatch_async(dispatch_get_main_queue()) {
                self?.subscriptionDidBecomeReady()
                return
              }
            }
          } else {
            dispatch_async(dispatch_get_main_queue()) {
              self?.contentLoadingState = .Error(error)
              return
            }
          }
        }
      }
    }
  }
  
  func subscriptionDidBecomeReady() {
  }
  
  // MARK: - View Management
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    updatePlaceholderView()
  }
  
  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    
    if !isContentLoaded {
      loadContent()
    }
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    placeholderView?.frame = tableView.bounds
  }
  
  // MARK: Placeholder View
  
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
    case .Error(let error):
      placeholderView?.showTitle(error.localizedDescription, message: error.localizedFailureReason)
    default:
      break
    }
  }
  
  // MARK: - UITableViewDataSource
  
  override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return fetchedResults?.numberOfSections ?? 0
  }
  
  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return fetchedResults?.numberOfItemsInSection(section) ?? 0
  }
  
  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let reuseIdentifier = cellReuseIdentifierForRowAtIndexPath(indexPath)
    let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath: indexPath) as UITableViewCell
    configureCell(cell, forRowAtIndexPath: indexPath)
    return cell
  }
  
  // MARK: - Table Cell Configuration
  
  func cellReuseIdentifierForRowAtIndexPath(indexPath: NSIndexPath) -> String {
    return "Cell"
  }
  
  func configureCell(cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
  }
  
  // MARK: - FetchedResultsChangeObserver
  
  func fetchedResultsDidLoad(fetchedResult: FetchedResults) {
    self.contentLoadingState = .Loaded
    tableView.reloadData()
  }
  
  func fetchedResults(fetchedResult: FetchedResults, didFailWithError error: NSError) {
    contentLoadingState = .Error(error)
  }
  
  func fetchedResults(fetchedResult: FetchedResults, didChange changes: FetchedResultsChanges) {
    // Don't perform incremental updates when the table view is not currently visible
    if tableView.window == nil {
      tableView.reloadData()
      return;
    }
    
    tableView.beginUpdates()
    
    for change in changes.changeDetails {
      switch(change) {
      case .SectionInserted(let sectionIndex):
        tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Automatic)
      case .SectionDeleted(let sectionIndex):
        tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Automatic)
      case .ObjectInserted(let newIndexPath):
        tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Automatic)
      case .ObjectDeleted(let indexPath):
        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
      case .ObjectUpdated(let indexPath):
        if let cell = tableView.cellForRowAtIndexPath(indexPath) {
          configureCell(cell, forRowAtIndexPath: indexPath)
        }
      case .ObjectMoved(let indexPath, let newIndexPath):
        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
        tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Automatic)
      }
    }
    
    tableView.endUpdates()
  }
}
