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

public class FetchedResultsDataSource: NSObject, NSFetchedResultsControllerDelegate, UIDataSourceModelAssociation {
  private(set) var fetchedResultsController: NSFetchedResultsController
  
  var managedObjectContext: NSManagedObjectContext {
    return fetchedResultsController.managedObjectContext
  }
  
  public init(fetchedResultsController: NSFetchedResultsController) {
    self.fetchedResultsController = fetchedResultsController
    super.init()
  }
  
  public func performFetch() {
    var error: NSError?
    do {
      try fetchedResultsController.performFetch()
      reloadData()
      fetchedResultsController.delegate = self
    } catch let error1 as NSError {
      error = error1
      if error != nil {
        didFailWithError(error!)
      }
    }
  }
  
  func didFailWithError(error: NSError) {
  }
  
  // MARK: - Accessing Results
  
  public var numberOfSections: Int {
    return fetchedResultsController.sections?.count ?? 0
  }
  
  public func numberOfItemsInSection(section: Int) -> Int {
    return fetchedResultsController.sections?[section].numberOfObjects ?? 0
  }
  
  public var objects: [NSManagedObject] {
    return fetchedResultsController.fetchedObjects as! [NSManagedObject]
  }
  
  public func objectAtIndexPath(indexPath: NSIndexPath) -> NSManagedObject {
    return fetchedResultsController.objectAtIndexPath(indexPath) as! NSManagedObject
  }
  
  public func indexPathForObject(object: NSManagedObject) -> NSIndexPath? {
    return fetchedResultsController.indexPathForObject(object)
  }
  
  // MARK: - Observing Changes

  enum ChangeDetail: CustomStringConvertible {
    case SectionInserted(Int)
    case SectionDeleted(Int)
    case ObjectInserted(NSIndexPath)
    case ObjectDeleted(NSIndexPath)
    case ObjectUpdated(NSIndexPath)
    case ObjectMoved(indexPath: NSIndexPath, newIndexPath: NSIndexPath)
    
    var description: String {
      switch self {
      case SectionInserted(let sectionIndex):
        return "SectionInserted(\(sectionIndex))"
      case SectionDeleted(let sectionIndex):
        return "SectionDeleted(\(sectionIndex))"
      case ObjectInserted(let indexPath):
        return "ObjectInserted(\(indexPath))"
      case ObjectDeleted(let indexPath):
        return "ObjectDeleted(\(indexPath))"
      case ObjectUpdated(let indexPath):
        return "ObjectUpdated(\(indexPath))"
      case let ObjectMoved(indexPath, newIndexPath):
        return "ObjectMoved(\(indexPath) -> \(newIndexPath))"
      }
    }
  }
  
  private var changes: [ChangeDetail]?

  // MARK: - NSFetchedResultsControllerDelegate

  public func controllerWillChangeContent(controller: NSFetchedResultsController) {
    changes = [ChangeDetail]()
  }
  
  public func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
    switch(type) {
    case .Insert:
      changes!.append(.SectionInserted(sectionIndex))
    case .Delete:
      changes!.append(.SectionDeleted(sectionIndex))
    default:
      break
    }
  }
  
  public func controller(controller: NSFetchedResultsController, didChangeObject object: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
    switch(type) {
    case .Insert:
      changes!.append(.ObjectInserted(newIndexPath!))
    case .Delete:
      changes!.append(.ObjectDeleted(indexPath!))
    case .Update:
      changes!.append(.ObjectUpdated(indexPath!))
    case .Move:
      changes!.append(.ObjectMoved(indexPath: indexPath!, newIndexPath: newIndexPath!))
    }
  }

  public func controllerDidChangeContent(controller: NSFetchedResultsController) {
    didChangeContent(changes!)
    changes = nil
  }
  
  // MARK: - Change Notification
  
  func reloadData() {
  }
  
  func didChangeContent(changes: [ChangeDetail]) {
  }

  // MARK: - UIDataSourceModelAssociation
  
  public func modelIdentifierForElementAtIndexPath(indexPath: NSIndexPath, inView view: UIView) -> String? {
    let object = objectAtIndexPath(indexPath)
    return object.objectID.URIRepresentation().absoluteString
  }
  
  public func indexPathForElementWithModelIdentifier(identifier: String, inView view: UIView) -> NSIndexPath? {
    let URIRepresentation = NSURL(string: identifier)!
    let objectID = managedObjectContext.persistentStoreCoordinator!.managedObjectIDForURIRepresentation(URIRepresentation)!
    let object = managedObjectContext.objectWithID(objectID)
    return indexPathForObject(object)
  }
}
