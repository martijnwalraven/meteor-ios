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

class ListsViewController: FetchedResultsTableViewController {
  @IBOutlet weak var userBarButtonItem: UIBarButtonItem!
  
  // MARK: - View Lifecycle
  
  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    
    NSNotificationCenter.defaultCenter().addObserver(self, selector: "accountDidChange", name: METDDPClientDidChangeAccountNotification, object: Meteor)
  }
  
  override func viewWillDisappear(animated: Bool) {
    super.viewWillDisappear(animated)
    
    NSNotificationCenter.defaultCenter().removeObserver(self, name: "accountDidChange", object: Meteor)
  }
  
  // MARK: - Content Loading
  
  override func configureSubscriptionLoader(subscriptionLoader: SubscriptionLoader) {
    subscriptionLoader.addSubscriptionWithName("lists")
  }
  
  override func createFetchedResultsController() -> NSFetchedResultsController? {
    let fetchRequest = NSFetchRequest(entityName: "List")
    fetchRequest.sortDescriptors = [ NSSortDescriptor(key: "name", ascending: true)]
    
    let ovo = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: "name", cacheName: nil)
    return ovo
  }
  
  // MARK: - FetchedResultsTableViewDataSourceDelegate
  
  func dataSource(dataSource: FetchedResultsTableViewDataSource, configureCell cell: UITableViewCell, forObject object: NSManagedObject, atIndexPath indexPath: NSIndexPath) {
    if let list = object as? List {
        cell.textLabel!.text = list.name
    }
  }
  
  func dataSource(dataSource: FetchedResultsTableViewDataSource, deleteObject object: NSManagedObject, atIndexPath indexPath: NSIndexPath) {
    if let list = object as? List {
      managedObjectContext.deleteObject(list)
      saveManagedObjectContext()
    }
  }
  
  // MARK: - Adding List
  
  @IBAction func addList() {
    let alertController = UIAlertController(title: nil, message: "Add List", preferredStyle: .Alert)
    
    let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { (action) in
    }
    alertController.addAction(cancelAction)
    
    let addAction = UIAlertAction(title: "Add", style: .Default) { (action) in
      let nameTextField = alertController.textFields![0] as! UITextField
      let name = nameTextField.text
      if name.isEmpty {
        return
      }
      
      let list = NSEntityDescription.insertNewObjectForEntityForName("List", inManagedObjectContext: self.managedObjectContext) as! List
      list.name = name
      self.saveManagedObjectContext()
    }
    alertController.addAction(addAction)
    
    alertController.addTextFieldWithConfigurationHandler { (textField) in
      textField.placeholder = "Name"
      textField.autocapitalizationType = .Words
      textField.returnKeyType = .Done
      textField.enablesReturnKeyAutomatically = true
    }
    
    presentViewController(alertController, animated: true, completion: nil)
  }
}
