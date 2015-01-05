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

class TodosViewController: FetchedResultsTableViewController {
  var listID: NSManagedObjectID? {
    didSet {
      assert(managedObjectContext != nil)
      list = (listID != nil) ? managedObjectContext.objectWithID(listID!) as? List : nil
    }
  }
  
  private var list: List? {
    didSet {
      title = list?.name
    }
  }
  
  override func loadContent() {
    if list != nil {
      subscription = Meteor.addSubscriptionWithName("todos", parameters: [list!])
    }
  }
  
  override func subscriptionDidBecomeReady() {
    let fetchRequest = NSFetchRequest(entityName: "Todo")
    fetchRequest.predicate = NSPredicate(format: "list == %@", list!)
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    
    fetchedResults = FetchedResults(managedObjectContext: managedObjectContext, fetchRequest: fetchRequest)
    fetchedResults.registerChangeObserver(self)
    fetchedResults.performFetch()
  }
  
  override func configureCell(cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
    let todo = fetchedResults.objectAtIndexPath(indexPath) as Todo
    cell.textLabel!.text = todo.text
    cell.accessoryType = todo.checked ? .Checkmark : .None
  }
  
  // MARK: - UITableViewDelegate
  
  override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
    if let todo = fetchedResults.objectAtIndexPath(indexPath) as? Todo {
      todo.checked = !todo.checked
      if (todo.checked) {
        todo.list.incompleteCount--
      } else {
        todo.list.incompleteCount++
      }
      var error: NSError?
      if !managedObjectContext!.save(&error) {
        println("Encountered error saving todo: \(error)")
      }
    }
    return nil
  }
}
