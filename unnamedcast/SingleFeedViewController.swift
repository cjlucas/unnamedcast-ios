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

protocol SingleFeedViewModelDelegate {
  func didSelectItem(item: Item)
}

class SingleFeedViewModel: NSObject, UITableViewDataSource {
  private var delegate: SingleFeedViewModelDelegate?
  private var tableView: UITableView
  private var headerView: UIView // TODO: extract these two views into their own class
  private var headerImageView: UIImageView
  
  private let db = try! DB()
  private var feed: Feed!
  
  required init(feedID: String,
       tableView: UITableView,
       headerView: UIView,
       headerImageView: UIImageView,
       delegate: SingleFeedViewModelDelegate? = nil) {
    
    guard let feed = self.db.feedWithID(feedID) else {
      fatalError("Feed was not found")
    }

    self.feed = feed
    self.delegate = delegate
    self.tableView = tableView
    self.headerView = headerView
    self.headerImageView = headerImageView

    self.tableView.estimatedRowHeight = 44
    self.tableView.rowHeight = UITableViewAutomaticDimension

    Alamofire.request(.GET, feed.imageUrl).responseData { resp in
      if let data = resp.data {
        let image = UIImage(data: data)!
        
        let bgImageView = UIImageView(image: image)
        bgImageView.contentMode = .Center
        headerView.insertSubview(bgImageView, belowSubview: headerImageView)
        
        let effect = UIBlurEffect(style: .Dark)
        let ev = UIVisualEffectView(effect: effect)
        ev.frame = headerView.bounds
        headerView.insertSubview(ev, belowSubview: headerImageView)
        
        headerImageView.image = image
      }
    }

  }
  
  @objc func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let item = feed.items.sorted("pubDate", ascending: false)[indexPath.row]
    
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell")! as! SingleFeedTableViewCell
    cell.itemTitleLabel.text = item.title
    cell.itemSummaryLabel.text = item.summary
    
    var metadata = [String]()
    
    if let date = item.pubDate ?? item.modificationDate {
      let s = NSDateFormatter.localizedStringFromDate(date,
                                                      dateStyle: .MediumStyle,
                                                      timeStyle: .ShortStyle)
      metadata.append(s)
    }
    
    var duration = item.duration
    if case .InProgress(let pos) = item.state {
      duration -= Int(Double(duration) * pos)
    }
   
    let hours = duration / 3600
    duration %= 3600
    let minutes = duration / 60
    
    var durationStrArr: [String] = []
    if hours > 0 {
      durationStrArr.append("\(hours) hours")
    }
    
    durationStrArr.append("\(minutes) minutes")
    
    if case .InProgress(_) = item.state {
      durationStrArr.append("left")
    }
    
    metadata.append(durationStrArr.joinWithSeparator(" "))
    
    if item.size > 0 {
      metadata.append("\(item.size / 1024 / 1024) MB")
    }
    
    cell.itemMetadataLabel.text = metadata.joinWithSeparator(" \u{2022} ")
    
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
  
  @objc func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    let item = feed.items.sorted("pubDate", ascending: false)[indexPath.row]
    
    let p = Player.sharedPlayer
    p.playItem(PlayerItem(item))
    
    if case .InProgress(let position) = item.state {
      p.seekToPos(position)
    }
    
    delegate?.didSelectItem(item)
  }
  
  
  @objc func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return feed.items.count
  }
}

class SingleFeedTableViewCell: UITableViewCell {
  @IBOutlet weak var itemTitleLabel: UILabel!
  @IBOutlet weak var itemSummaryLabel: UILabel!
  @IBOutlet weak var itemMetadataLabel: UILabel!
}

class SingleFeedViewController: UITableViewController, SingleFeedViewModelDelegate {
  var feedID: String!
  
  @IBOutlet weak var headerView: UIView!
  @IBOutlet weak var headerImageView: UIImageView!
  
  private var viewModel: SingleFeedViewModel!
  
  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    guard let feedID = feedID else { fatalError("feedID was not set") }
    viewModel = SingleFeedViewModel(feedID: feedID,
                                    tableView: tableView,
                                    headerView: headerView,
                                    headerImageView: headerImageView,
                                    delegate: self)
    
  }

  // MARK: ViewModelDelegate
  
  func didSelectItem(item: Item) {
    self.performSegueWithIdentifier("ThePlayerSegue", sender: self)
  }
  
}
