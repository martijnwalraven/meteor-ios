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

class ListsViewController: FetchedResultsTableViewController {
  override func loadContent() {
    super.loadContent()
    
    subscription = Meteor.addSubscriptionWithName("publicLists")
  }
  
  override func subscriptionDidBecomeReady() {
    let fetchRequest = NSFetchRequest(entityName: "List")
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
    
    fetchedResults = FetchedResults(managedObjectContext: managedObjectContext, fetchRequest: fetchRequest)
    fetchedResults.registerChangeObserver(self)
    fetchedResults.performFetch()
  }
  
  override func configureCell(cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
    let list = fetchedResults.objectAtIndexPath(indexPath) as List
    cell.textLabel!.text = list.name
    cell.detailTextLabel!.text = "\(list.incompleteCount)"
  }
  
  // MARK: - Segues
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if segue.identifier == "showDetail" {
      if let indexPath = tableView.indexPathForSelectedRow() {
        let selectedList = fetchedResults.objectAtIndexPath(indexPath) as List
        if let todosViewcontroller = (segue.destinationViewController as? UINavigationController)?.topViewController as? TodosViewController {
          todosViewcontroller.managedObjectContext = managedObjectContext
          todosViewcontroller.listID = selectedList.objectID
        }
      }
    }
  }
}
