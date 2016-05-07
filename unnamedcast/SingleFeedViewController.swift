//
//  SingleFeedViewController.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 1/28/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Foundation
import UIKit
import RealmSwift
import AVFoundation
import Alamofire
import DateTools

class SingleFeedTableViewCell: UITableViewCell {
  @IBOutlet weak var itemTitleLabel: UILabel!
  @IBOutlet weak var itemSummaryLabel: UILabel!
  @IBOutlet weak var itemMetadataLabel: UILabel!
}

class SingleFeedViewController: UITableViewController {
  var feedId: String?
  var realm = try! Realm()
  var token: NotificationToken?
  
  @IBOutlet weak var headerView: UIView!
  @IBOutlet weak var headerImageView: UIImageView!
  
  
  lazy var feed: Feed = {
    guard let id = self.feedId else { fatalError("Feed not set") }
    return self.realm.objects(Feed).filter("id == '\(id)'").first!
  }()
  
  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
  
    self.tableView.estimatedRowHeight = 44
    self.tableView.rowHeight = UITableViewAutomaticDimension
    
    self.title = feed.title
    
//    token = feed.addNotificationBlock { items in
//      self.tableView.reloadData()
//    }
    
    Alamofire.request(.GET, feed.imageUrl).responseData { resp in
      if let data = resp.data {
        let image = UIImage(data: data)!
        
        let bgImageView = UIImageView(image: image)
        bgImageView.contentMode = .Center
        self.headerView.insertSubview(bgImageView, belowSubview: self.headerImageView)
        
        let effect = UIBlurEffect(style: .Dark)
        let ev = UIVisualEffectView(effect: effect)
        ev.frame = self.headerView.bounds
        self.headerView.insertSubview(ev, belowSubview: self.headerImageView)
        
        self.headerImageView.image = image
      }
    }
  }
  
  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let item = feed.items.sorted("pubDate", ascending: false)[indexPath.row]
    
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell")! as! SingleFeedTableViewCell
    cell.itemTitleLabel.text = item.title
    cell.itemSummaryLabel.text = item.summary
    print(item.pubDate)
    let pubDateStr = NSDateFormatter.localizedStringFromDate(item.pubDate!, dateStyle: .MediumStyle, timeStyle: .ShortStyle)
    cell.itemMetadataLabel.text = "Added \(pubDateStr). \(item.duration) seconds. \(item.size) bytes."

    var textColor: UIColor
    switch (item.state) {
    case .Played:
      textColor = UIColor.grayColor()
    default:
      textColor = UIColor.blackColor()
    }
    
    
    for lbl in [cell.itemTitleLabel, cell.itemSummaryLabel, cell.itemMetadataLabel] {
      lbl.textColor = textColor
    }
    
    return cell
  }
  
  override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    let item = feed.items.sorted("pubDate", ascending: false)[indexPath.row]
    
    let p = Player.sharedPlayer
    p.playItem(PlayerItem(item))
    
    if case .InProgress(let position) = item.state {
      p.seekToPos(position)
    }
    
    performSegueWithIdentifier("ThePlayerSegue", sender: self)
  }
  
  
  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return feed.items.count
  }
}
