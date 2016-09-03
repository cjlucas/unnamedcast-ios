//
//  FeedTableViewController.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 9/3/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import UIKit
import RealmSwift

class FeedTableViewCell: UITableViewCell {
  @IBOutlet weak var primaryLabel: UILabel!
  @IBOutlet weak var secondaryLabel: UILabel!
  @IBOutlet weak var feedImageView: UIImageView!
}

class FeedTableViewController: UITableViewController {
  private let db = try! DB()
  
  private func itemAt(indexPath: NSIndexPath) -> Feed {
    return db.feeds[indexPath.row]
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    print(tableView.frame)
    tableView.rowHeight = 80
    
    print(self.clearsSelectionOnViewWillAppear)
    
    // Uncomment the following line to preserve selection between presentations
    // self.clearsSelectionOnViewWillAppear = false
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  // MARK: - UITableViewDataSource
  
  override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return 1
  }
  
  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return db.feeds.count
  }
  
  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let feed = itemAt(indexPath)
    
    let cell = self.tableView.dequeueReusableCellWithIdentifier("FeedTableViewCell")! as! FeedTableViewCell
    cell.primaryLabel.text = feed.title
    cell.secondaryLabel.text = feed.author
    
    if let url = NSURL(string: feed.imageUrl) {
      cell.feedImageView.sd_setImageWithURL(url)
    }
//    let cnt = db.unplayedItemsForFeed(feed).count + db.inProgressItemsForFeed(feed).count
//    cell.detailTextLabel?.text = String(cnt)
    
    return cell
  }
  
  // MARK: - Navigation
  
  // In a storyboard-based application, you will often want to do a little preparation before navigation
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    guard let indexPath = tableView.indexPathForSelectedRow else {
      fatalError("indexPathForSeelctedRow is nil")
    }
    
    if let vc = segue.destinationViewController as? SingleFeedViewController {
      vc.feedID = itemAt(indexPath).id
    }
  }
}
