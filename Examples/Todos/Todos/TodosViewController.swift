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

class TodosViewController: FetchedResultsTableViewController, UITextFieldDelegate {
  // MARK: - Lifecycle

  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(self)
  }
  
  // MARK: - Model Management
  
  override var managedObjectContext: NSManagedObjectContext! {
    willSet {
      if managedObjectContext != nil {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: NSManagedObjectContextObjectsDidChangeNotification, object: managedObjectContext)
      }
    }
    didSet {
      if managedObjectContext != nil {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "objectsDidChange:", name: NSManagedObjectContextObjectsDidChangeNotification, object: managedObjectContext)
      }
    }
  }
  
  var listID: NSManagedObjectID? {
    didSet {
      assert(managedObjectContext != nil)
      list = (listID != nil) ? managedObjectContext.objectWithID(listID!) as? List : nil
    }
  }
  
  private var list: List? {
    didSet {
      title = list?.name
      
      if list == nil {
        subscription = nil
        fetchedResults = nil
        contentLoadingState = .Initial
      }
      
      updateTableHeaderView()
    }
  }
  
  func objectsDidChange(notification: NSNotification) {
    if list == nil {
      return
    }
    
    // Check whether list has been deleted
    if let deletedObjects = notification.userInfo![NSDeletedObjectsKey]? as? NSSet {
      if deletedObjects.containsObject(list!) {
        list = nil
      }
    }
  }
  
  // MARK: - Content Loading
  
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
  
  // MARK: - View Management
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    addTaskContainerView.preservesSuperviewLayoutMargins = true
  }
  
  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    
    updateTableHeaderView()
  }
  
  func updateTableHeaderView() {
    if list == nil {
      tableView.tableHeaderView = nil
    } else {
      tableView.tableHeaderView = addTaskContainerView
    }
  }
  
  // MARK: - Table Cell Configuration
  
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
      saveManagedObjectContext()
    }
    return nil
  }
  
  override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    if editingStyle == .Delete {
      if let todo = fetchedResults.objectAtIndexPath(indexPath) as? Todo {
        managedObjectContext.deleteObject(todo)
        saveManagedObjectContext()
      }
    }
  }
  
  // MARK: - UITextFieldDelegate

  @IBOutlet var addTaskContainerView: UIView!
  @IBOutlet weak var addTaskTextField: UITextField!
  
  func textFieldShouldReturn(textField: UITextField) -> Bool {
    let text = addTaskTextField.text
    addTaskTextField.text = nil
    
    if text.isEmpty {
      addTaskTextField.resignFirstResponder()
      return false
    }
    
    let todo = NSEntityDescription.insertNewObjectForEntityForName("Todo", inManagedObjectContext: managedObjectContext) as Todo
    todo.creationDate = NSDate()
    todo.text = text
    todo.list = list
    list?.incompleteCount++
    saveManagedObjectContext()
    
    return true
  }
}
