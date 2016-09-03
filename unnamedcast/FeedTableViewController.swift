//
//  FeedTableViewController.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 9/3/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import UIKit

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
    tableView.rowHeight = 80
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
