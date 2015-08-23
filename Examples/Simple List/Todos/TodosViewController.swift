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

class TodosViewController: FetchedResultsTableViewController, UITextFieldDelegate {
  @IBOutlet weak var listLockStatusBarButtonItem: UIBarButtonItem!
  
  // MARK: - Model
  
  var listID: NSManagedObjectID? {
    didSet {
      assert(managedObjectContext != nil)
      
      if listID != nil {
        if listID != oldValue {
          list = managedObjectContext!.existingObjectWithID(self.listID!, error: nil) as? List
        }
      } else {
        list = nil
      }
    }
  }
  
  private var listObserver: ManagedObjectObserver?
  
  private var list: List? {
    didSet {
      if list != oldValue {
        if list != nil {
          listObserver = ManagedObjectObserver(list!) { (changeType) -> Void in
            switch changeType {
            case .Deleted, .Invalidated:
              self.list = nil
            case .Updated, .Refreshed:
              self.listDidChange()
            default:
              break
            }
          }
        } else {
          listObserver = nil
          resetContent()
        }
        
        listDidChange()
        setNeedsLoadContent()
      }
    }
  }
  
  func listDidChange() {
    title = list?.name
    
    if isViewLoaded() {
      updateViewWithModel()
    }
  }
  
  // MARK: - View Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    addTaskContainerView.preservesSuperviewLayoutMargins = true
  }
  
  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    
    updateViewWithModel()
  }

  // MARK: - Content Loading
  
  override func loadContent() {
    if list == nil {
      return
    }
    
    super.loadContent()
  }
  
  override func configureSubscriptionLoader(subscriptionLoader: SubscriptionLoader) {
    if list != nil {
      subscriptionLoader.addSubscriptionWithName("todos", parameters: list!)
    }
  }
  
  override func createFetchedResultsController() -> NSFetchedResultsController? {
    if list == nil {
      return nil
    }
    
    let fetchRequest = NSFetchRequest(entityName: "Todo")
    fetchRequest.predicate = NSPredicate(format: "list == %@", self.list!)
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    
    return NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
  }
  
  // MARK: - Updating View
  
  func updateViewWithModel() {
    if list == nil {
      tableView.tableHeaderView = nil
      listLockStatusBarButtonItem.image = nil
    } else {
      tableView.tableHeaderView = addTaskContainerView
    }
  }
  
  // MARK: - FetchedResultsTableViewDataSourceDelegate
  
  func dataSource(dataSource: FetchedResultsTableViewDataSource, configureCell cell: UITableViewCell, forObject object: NSManagedObject, atIndexPath indexPath: NSIndexPath) {
  }
  
  func dataSource(dataSource: FetchedResultsTableViewDataSource, deleteObject object: NSManagedObject, atIndexPath indexPath: NSIndexPath) {
  }
  
  // MARK: - UITableViewDelegate
  
  override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
    return nil
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
    
    saveManagedObjectContext()
    
    return true
  }
}