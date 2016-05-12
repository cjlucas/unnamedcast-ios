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

class FeedSearchTableViewController: UITableViewController, UISearchBarDelegate {
  @IBOutlet weak var searchBar: UISearchBar!
  
  var results = [SearchResult]()
  let realm = try! Realm()
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    searchBar.delegate = self
    
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = false
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  // MARK: - Table view data source
  
  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return results.count
  }
  
  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)
    cell.textLabel?.text = results[indexPath.row].title
    
    return cell
  }
  
  override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    let feedId = results[indexPath.row].id
    var feedIds = realm.objects(Feed).map { $0.id }
    feedIds.append(feedId)
    
    let alert = UIAlertController(title: "Add Feed", message: "Do you want to add this feed?", preferredStyle: .Alert)
    
    let add = UIAlertAction(title: "Add", style: .Default) { action in
      let userID = NSUserDefaults.standardUserDefaults().stringForKey("user_id")!
      
      let ep = UpdateUserFeedsEndpoint(userID: userID, feedIDs: feedIds)
      APIClient().request(ep).then {_,_ in
        print("Your shit got updated yo")
      }
      
    }
    let cancel = UIAlertAction(title: "Cancel", style: .Default) { action in
      print("HERE2")
    }
    
    alert.addAction(add)
    alert.addAction(cancel)
    
    presentViewController(alert, animated: true, completion: nil)
  }
  
  /*
  // MARK: - Navigation
  
  // In a storyboard-based application, you will often want to do a little preparation before navigation
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
  // Get the new view controller using segue.destinationViewController.
  // Pass the selected object to the new view controller.
  }
  */
  @IBAction func closeButtonPressed(sender: UIBarButtonItem) {
    self.dismissViewControllerAnimated(true, completion: nil)
  }
  
  // MARK: - UISearchBarDelegate
  
  func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
    let ep = SearchFeedsEndpoint(query: searchText)
    APIClient().request(ep).then { _, resp, results -> Void in
      self.results = results
      self.tableView.reloadData()
    }
  }
}
