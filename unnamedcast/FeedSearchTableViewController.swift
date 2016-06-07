//
//  FeedSearchTableViewController.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 2/19/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import UIKit
import Alamofire
import Freddy
import RealmSwift

class FeedSearchViewModel: NSObject, UITableViewDataSource {
  let db = try! DB()
  var results = [SearchResult]()
  
  private var apiClient: APIClient
  private weak var tableView: UITableView?
  
  init(apiClient: APIClient, tableView: UITableView) {
    self.apiClient = apiClient
    self.tableView = tableView
  }

  func queryDidChange(query: String) {
    let ep = SearchFeedsEndpoint(query: query)
    self.apiClient.request(ep).then { _, _, results -> () in
      self.results = results
      self.tableView?.reloadData()
    }
  }
  
  func feedIDAtIndexPath(indexPath: NSIndexPath) -> String {
    return results[indexPath.row].id
  }
  
  func addFeedWithID(id: String) {
    var feedIDs = db.feeds.map { $0.id }
    feedIDs.append(id)
   
    let userID = NSUserDefaults.standardUserDefaults().stringForKey("user_id")
    let ep = UpdateUserFeedsEndpoint(userID: userID!, feedIDs: feedIDs)
    self.apiClient.request(ep).then { _ in
      print("Updated user feeds")
    }
  }
 
  // Mark: UITableViewDataSource
  
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return results.count
  }
  
  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
    cell.textLabel?.text = results[indexPath.row].title
    
    return cell
  }
}

class FeedSearchTableViewController: UITableViewController, UISearchBarDelegate {
  @IBOutlet weak var searchBar: UISearchBar!
  
  lazy var viewModel: FeedSearchViewModel = {
    return FeedSearchViewModel(apiClient: APIClient(),
                               tableView: self.tableView)
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    searchBar.delegate = self
    tableView.dataSource = viewModel
  }
  
  // MARK: - UITableViewDelegate
  
  override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    let feedID = viewModel.feedIDAtIndexPath(indexPath)
    
    let alert = UIAlertController(title: "Add Feed", message: "Do you want to add this feed?", preferredStyle: .Alert)
    
    let add = UIAlertAction(title: "Add", style: .Default) { action in
      self.viewModel.addFeedWithID(feedID)
    }
    
    let cancel = UIAlertAction(title: "Cancel", style: .Default, handler: nil)
    
    alert.addAction(add)
    alert.addAction(cancel)
    
    presentViewController(alert, animated: true, completion: nil)
  }
  
  @IBAction func closeButtonPressed(sender: UIBarButtonItem) {
    self.dismissViewControllerAnimated(true, completion: nil)
  }
  
  // MARK: - UISearchBarDelegate
  
  func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
    viewModel.queryDidChange(searchText)
  }
}
