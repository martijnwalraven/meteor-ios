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
  
  // MARK: - Content Loading
  
  override func loadContent() {
    super.loadContent()
    
    subscriptionLoader.addSubscriptionWithName("publicLists")
    subscriptionLoader.addSubscriptionWithName("privateLists")
    
    subscriptionLoader.whenReady {
      if self.fetchedResults == nil {
        let fetchRequest = NSFetchRequest(entityName: "List")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        self.fetchedResults = FetchedResults(managedObjectContext: self.managedObjectContext, fetchRequest: fetchRequest)
        self.fetchedResults.registerChangeObserver(self)
        self.fetchedResults.performFetch()
      }
      
      if self.isViewLoaded() {
        self.selectFirstTableViewRowIfNoRowIsCurrentlySelected()
      }
    }
    
    if !subscriptionLoader.isReady {
      if Meteor.connectionStatus == .Offline {
        contentLoadingState = .Offline
      } else {
        contentLoadingState = .Loading
      }
    }
  }
  
  // MARK: - View Management
  
  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    
    NSNotificationCenter.defaultCenter().addObserver(self, selector: "accountDidChange", name: METDDPClientDidChangeAccountNotification, object: Meteor)
    
    updateUserBarButtonItem()
    
    if isContentLoaded {
      selectFirstTableViewRowIfNoRowIsCurrentlySelected()
    }
  }
  
  override func viewWillDisappear(animated: Bool) {
    super.viewWillDisappear(animated)
    
    NSNotificationCenter.defaultCenter().removeObserver(self, name: "accountDidChange", object: Meteor)
  }
  
  func selectFirstTableViewRowIfNoRowIsCurrentlySelected() {
    if tableView.indexPathForSelectedRow() == nil && !splitViewController!.collapsed {
      if fetchedResults.numberOfSections > 0 && fetchedResults.numberOfItemsInSection(0) > 0 {
        tableView.selectRowAtIndexPath(NSIndexPath(forRow: 0, inSection: 0), animated: false, scrollPosition: .Top)
        performSegueWithIdentifier("showDetail", sender: nil)
      }
    }
  }
  
  func accountDidChange() {
    dispatch_async(dispatch_get_main_queue()) {
      self.updateUserBarButtonItem()
    }
  }
  
  func updateUserBarButtonItem() {
    if Meteor.account == nil {
      userBarButtonItem.image = UIImage(named: "user_icon")
    } else {
      userBarButtonItem.image = UIImage(named: "user_icon_selected")
    }
  }
  
  // MARK: - Table Cell Configuration
  
  override func configureCell(cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
    let list = fetchedResults.objectAtIndexPath(indexPath) as List
    cell.textLabel!.text = list.name
    cell.detailTextLabel!.text = "\(list.incompleteCount)"
  }
  
  // MARK: - IBActions
  
  @IBAction func userButtonPressed() {
    if Meteor.account == nil {
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
  
  @IBAction func addList() {
    let list = NSEntityDescription.insertNewObjectForEntityForName("List", inManagedObjectContext: managedObjectContext) as List
    list.name = nextAvailableDefaultListName
    list.incompleteCount = 0
    saveManagedObjectContext()
  }
  
  // MARK: - List Names
  
  var nextAvailableDefaultListName: String {
    return nextAvailableListNameWithBase("List ", alphabet.startIndex)
  }
  
  func nextAvailableListNameWithBase(base: String, _ nextLetter: CUnsignedChar) -> String {
    for letter in alphabet {
      let nextName = base + String(UnicodeScalar(letter))
      if !listNameExists(nextName) {
        return nextName
      }
    }
    return nextAvailableListNameWithBase(base + String(UnicodeScalar(nextLetter)), nextLetter+1)
  }
  
  let alphabet = CUnsignedChar("A")...CUnsignedChar("Z")
  
  func listNameExists(name: String) -> Bool {
    return (fetchedResults.objects as [List]).filter({$0.name == name}).count > 0
  }
  
  // MARK: - UITableViewDelegate
  
  override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    if editingStyle == .Delete {
      if let list = fetchedResults.objectAtIndexPath(indexPath) as? List {
        managedObjectContext.deleteObject(list)
        saveManagedObjectContext()
      }
    }
  }
  
  // MARK: - Segues
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if segue.identifier == "showDetail" {
      if let indexPath = tableView.indexPathForSelectedRow() {
        let selectedList = fetchedResults.objectAtIndexPath(indexPath) as List
        selectedObject = selectedList
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
