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

class SingleFeedViewController: UITableViewController {
  var feedId: String?
  var realm = try! Realm()
  
  @IBOutlet weak var headerView: UIView!
  @IBOutlet weak var headerImageView: UIImageView!
  
  lazy var feed: Feed = {
    if let id = self.feedId {
      return self.realm.objects(Feed).filter("id == '\(id)'").first!
    }
    fatalError("Feed not set")
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.title = feed.title
    
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
    
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell")!
    cell.textLabel?.text = item.title
    
    if case .Played = item.state {
      cell.textLabel?.textColor = UIColor.grayColor()
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
