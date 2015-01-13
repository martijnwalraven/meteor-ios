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
  @IBOutlet weak var userBarButtonItem: UIBarButtonItem!
  
  // MARK: - View Lifecycle
  
  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    
    NSNotificationCenter.defaultCenter().addObserver(self, selector: "accountDidChange", name: METDDPClientDidChangeAccountNotification, object: Meteor)
    
    updateUserBarButtonItem()
  }
  
  override func viewWillDisappear(animated: Bool) {
    super.viewWillDisappear(animated)
    
    NSNotificationCenter.defaultCenter().removeObserver(self, name: "accountDidChange", object: Meteor)
  }
  
  // MARK: - Content Loading
  
  override func configureSubscriptionLoader(subscriptionLoader: SubscriptionLoader) {
    subscriptionLoader.addSubscriptionWithName("publicLists")
    subscriptionLoader.addSubscriptionWithName("privateLists")
  }
  
  override func createFetchedResultsController() -> NSFetchedResultsController? {
    let fetchRequest = NSFetchRequest(entityName: "List")
    fetchRequest.sortDescriptors = [NSSortDescriptor(key: "isPrivate", ascending: true), NSSortDescriptor(key: "name", ascending: true)]
    
    return NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: managedObjectContext, sectionNameKeyPath: "isPrivate", cacheName: nil)
  }
  
  // MARK: - FetchedResultsTableViewDataSourceDelegate
  
  func dataSource(dataSource: FetchedResultsTableViewDataSource, configureCell cell: UITableViewCell, forObject object: NSManagedObject, atIndexPath indexPath: NSIndexPath) {
    if let list = object as? List {
      cell.textLabel!.text = list.name
      cell.detailTextLabel!.text = "\(list.incompleteCount)"
      cell.imageView!.image = (list.user != nil) ? UIImage(named: "locked_icon") : nil
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
      let nameTextField = alertController.textFields![0] as UITextField
      let name = nameTextField.text
      if name.isEmpty {
        return
      }
      
      let list = NSEntityDescription.insertNewObjectForEntityForName("List", inManagedObjectContext: self.managedObjectContext) as List
      list.name = name
      list.incompleteCount = 0
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
  
  // MARK: - Signing In and Out
  
  func accountDidChange() {
    dispatch_async(dispatch_get_main_queue()) {
      self.updateUserBarButtonItem()
    }
  }
  
  func updateUserBarButtonItem() {
    if Meteor.userID == nil {
      userBarButtonItem.image = UIImage(named: "user_icon")
    } else {
      userBarButtonItem.image = UIImage(named: "user_icon_selected")
    }
  }
  
  @IBAction func userButtonPressed() {
    if Meteor.userID == nil {
      performSegueWithIdentifier("SignIn", sender: nil)
    } else {
      showUserAlertSheet()
    }
  }
  
  func showUserAlertSheet() {
    let currentUser = self.currentUser
    
    let emailAddress = currentUser?.emailAddress
    let message = emailAddress != nil ? "Signed in as \(emailAddress!)." : "Signed in."
    
    let alertController = UIAlertController(title: nil, message: message, preferredStyle: .ActionSheet)
    
    let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { (action) in
    }
    alertController.addAction(cancelAction)
    
    let signOutAction = UIAlertAction(title: "Sign Out", style: .Destructive) { (action) in
      Meteor.logoutWithCompletionHandler(nil)
    }
    alertController.addAction(signOutAction)
    
    if let popoverPresentationController = alertController.popoverPresentationController {
      popoverPresentationController.barButtonItem = userBarButtonItem
    }
    
    presentViewController(alertController, animated: true, completion: nil)
  }
  
  // MARK: - Segues
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if segue.identifier == "showDetail" {
      if let selectedList = dataSource.selectedObject as? List {
        if let todosViewcontroller = (segue.destinationViewController as? UINavigationController)?.topViewController as? TodosViewController {
          todosViewcontroller.managedObjectContext = managedObjectContext
          todosViewcontroller.listID = selectedList.objectID
        }
      }
    }
  }
  
  @IBAction func unwindFromSignIn(segue: UIStoryboardSegue) {
    // Shouldn't be needed, but without it the modal view controller isn't dismissed on the iPad
    dismissViewControllerAnimated(true, completion: nil)
  }
}
