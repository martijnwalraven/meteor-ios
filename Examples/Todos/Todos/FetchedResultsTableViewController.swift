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

class FetchedResultsTableViewController: UITableViewController, NSFetchedResultsControllerDelegate {
  var fetchedResultsController: NSFetchedResultsController? {
    didSet {
      fetchedResultsController?.delegate = self
      performFetch()
    }
  }
  
  func performFetch() {
    var error: NSError?
    if fetchedResultsController!.performFetch(&error) {
      tableView.reloadData()
    } else if error != nil {
      println("Error performing fetch: \(error!)")
      abort()
    }
  }
  
  func objectAtIndexPath(indexPath: NSIndexPath) -> NSManagedObject {
    return fetchedResultsController?.objectAtIndexPath(indexPath) as NSManagedObject
  }
  
  func configureCell(cell: UITableViewCell, withObject object: NSManagedObject) {
  }
  
  // MARK: - UITableViewDataSource
  
  override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return fetchedResultsController?.sections?.count ?? 0
  }
  
  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    let sectionInfo = fetchedResultsController?.sections?[section] as NSFetchedResultsSectionInfo
    return sectionInfo.numberOfObjects
  }
  
  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) as UITableViewCell
    configureCell(cell, withObject: objectAtIndexPath(indexPath))
    return cell
  }
  
  // MARK: - NSFetchedResultsControllerDelegate
  
  func controllerWillChangeContent(controller: NSFetchedResultsController) {
    tableView.beginUpdates()
  }
  
  func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo!, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
    
    switch(type) {
    case .Insert:
      tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Automatic)
    case .Delete:
      tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Automatic)
    default:
      break
    }
  }
  
  func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject!, atIndexPath indexPath: NSIndexPath!, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath!) {
    
    switch(type) {
    case .Insert:
      tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Automatic)
    case .Delete:
      tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    case .Update:
      if let cell = tableView.cellForRowAtIndexPath(indexPath) {
        configureCell(cell, withObject: objectAtIndexPath(indexPath))
      }
    case .Move:
      tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
      tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Automatic)
    default:
      break
    }
  }
  
  func controllerDidChangeContent(controller: NSFetchedResultsController) {
    tableView.endUpdates()
  }
}
