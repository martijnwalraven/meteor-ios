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
  var list: List? {
    didSet {
      if oldValue != list {
        if subscription != nil {
          Meteor.removeSubscription(subscription!)
        }
        
        if list != nil {
          subscription = Meteor.addSubscriptionWithName("todos", parameters: [list!]) { (error) -> () in
            if error == nil {
              self.setUpFetchedResultsController()
            } else {
              println("Encountered error subscribing to 'todos': \(error)")
            }
          }
        }
        
        title = list!.name
      }
    }
  }
  
  var subscription: METSubscription?
  
  deinit {
    if subscription != nil {
      Meteor.removeSubscription(subscription!)
    }
  }
  
  func setUpFetchedResultsController() {
    let fetchRequest = NSFetchRequest(entityName: "Todo")
    fetchRequest.predicate = NSPredicate(format: "list == %@", list!)
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: list!.managedObjectContext!, sectionNameKeyPath: nil, cacheName: nil)
  }
  
  override func configureCell(cell: UITableViewCell, withObject object: NSManagedObject) {
    if let todo = object as? Todo {
      cell.textLabel!.text = todo.text
      cell.accessoryType = todo.checked ? .Checkmark : .None
    }
  }
  
  // MARK: - UITableViewDelegate
  
  override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
    if let todo = objectAtIndexPath(indexPath) as? Todo {
      todo.checked = !todo.checked
      if (todo.checked) {
        todo.list.incompleteCount--
      } else {
        todo.list.incompleteCount++
      }
      var error: NSError?
      if !todo.managedObjectContext!.save(&error) {
        println("Encountered error saving todo: \(error)")
      }
    }
    return nil
  }
}
