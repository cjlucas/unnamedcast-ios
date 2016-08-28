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

private typealias RGBA = (
  red: CGFloat,
  green: CGFloat,
  blue: CGFloat,
  alpha: CGFloat
)

private func getRGB(color: UIColor) -> RGBA {
  var r: CGFloat = 0
  var g: CGFloat = 0
  var b: CGFloat = 0
  var a: CGFloat = 0
  color.getRed(&r, green: &g, blue: &b, alpha: &a)
  return (red: r, green: g, blue: b, alpha: a)
}

private func getGradientForImage(colors: [UIColor]) -> [CGColor] {
  guard colors.count > 0 else { return [UIColor.blackColor().CGColor, UIColor.blackColor().CGColor] }
 
  // fall back to first color
  var color = colors.first!
  for c in colors {
    // Nothing too bright or too dark
    if CGFloat(c.brightness) > 1.0 - 0.2 || CGFloat(c.brightness) < 0.2 {
      continue
    }
    
    // Ghetto brightness test
    let (r, g, b, _) = getRGB(c)
    
    // reject neutral colors
    let rgb = [r,g,b].sort()
    let diff2 = rgb[2] - rgb[0]
    if diff2 < 0.1 {
      continue
    }
    
    color = c
    break
  }
  
  print("Picked \(color) \(color.brightness) \(color.isDarkColor)")

  let multiplier: CGFloat = 0.05 // number of times lighter
  
  let (r, g, b, _) = getRGB(color)
  let start = UIColor(red: r + multiplier, green: g + multiplier, blue: b + multiplier, alpha: 1)
  let end = UIColor(red: r - multiplier, green: g - multiplier, blue: b - multiplier, alpha: 1)
  
  return [start, end].map { $0.CGColor }
}


class SingleFeedViewModel: NSObject, UITableViewDataSource {
  private struct TableSection {
    let name: String
    let results: Results<Item>
  }
  
  private typealias CellData = (
    title: String,
    description: String,
    metadata: String,
    itemState: Item.State
  )
  
  private weak var tableView: UITableView?
  private weak var headerView: SingleFeedTableHeaderView? // TODO: extract these two views into their own class
  
  private let db = try! DB()
  private var feed: Feed!
  
  var feedUpdateNotificationToken: NotificationToken
 
  private lazy var sections: [TableSection] = {
    return [
      TableSection(name: "In Progress", results: self.db.inProgressItemsForFeed(self.feed)),
      TableSection(name: "Unplayed", results: self.db.unplayedItemsForFeed(self.feed)),
      TableSection(name: "Played", results: self.db.playedItemsForFeed(self.feed)),
    ]
  }()
  
  private var activeSections: [TableSection] {
    return sections.filter { section in section.results.count > 0 }
  }
  
  var items: Results<Item> {
    return self.feed.items.sorted("pubDate", ascending: false)
  }
  
  required init(feedID: String,
       tableView: UITableView,
       headerView: SingleFeedTableHeaderView,
       onColorChange: (UIColor) -> ()
    ) {
    guard let feed = self.db.feedWithID(feedID) else {
      fatalError("Feed was not found")
    }
   
    self.feed = feed
    self.tableView = tableView
    self.headerView = headerView

    self.tableView?.estimatedRowHeight = 140
    self.tableView?.rowHeight = UITableViewAutomaticDimension
    
    headerView.titleLabel.text = feed.title

    weak var weakTableView = tableView
    feedUpdateNotificationToken = self.db.addNotificationBlockForFeedUpdate(feed) {
      weakTableView?.beginUpdates()
      weakTableView?.reloadData()
      weakTableView?.endUpdates()
    }
    
    Alamofire.request(.GET, feed.imageUrl).responseData { resp in
      
      if let data = resp.data {
        let image = UIImage(data: data)!

        let layer = CAGradientLayer()
        layer.frame = headerView.bounds
        let colors = getGradientForImage(feed.colors.map {
          return UIColor(
            red: CGFloat($0.red) / 255.0,
            green: CGFloat($0.green) / 255.0,
            blue: CGFloat($0.blue) / 255.0,
            alpha: 1
          )
        })
        layer.colors = colors
        onColorChange(colors.map(UIColor.init).first!)
        headerView.layer.insertSublayer(layer, atIndex: 0)
        
//        let bgImageView = UIImageView(image: image)
//        bgImageView.contentMode = .Center
//        headerView.insertSubview(bgImageView, belowSubview: headerImageView)
        
//        let effect = UIBlurEffect(style: .Dark)
//        let ev = UIVisualEffectView(effect: effect)
//        ev.frame = headerView.bounds
//        headerView.insertSubview(ev, belowSubview: headerImageView)
        
        
        headerView.imageView.image = image
      }
    }
  }
  
  deinit {
    feedUpdateNotificationToken.stop()
  }

  private func itemAtIndexPath(path: NSIndexPath) -> Item! {
    return activeSections[path.section].results
      .sorted("pubDate", ascending: false)[path.row]
  }
  
  func playerItemAtIndexPath(path: NSIndexPath) -> PlayerItem {
    let item = itemAtIndexPath(path)
    var position = 0.0
    if case .InProgress(let pos) = item.state {
      position = pos * Double(item.duration)
    }
    
    return PlayerItem(id: item.id,
                      url: NSURL(string: item.audioURL)!,
                      position: position)
  }
  
  private func cellDataAtIndexPath(indexPath: NSIndexPath) -> CellData {
    let item = itemAtIndexPath(indexPath)
    
    var metadata = [String]()
    let date = NSDateFormatter.localizedStringFromDate(item.pubDate ?? item.modificationDate ?? NSDate(),
                                                       dateStyle: .MediumStyle,
                                                       timeStyle: .ShortStyle)
    metadata.append(date)
    
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
   
    return (title: item.title,
            description: item.summary,
            metadata: metadata.joinWithSeparator(" \u{2022} "),
            itemState: item.state)
  }
  
  private func configureCell(cell: SingleFeedTableViewCell, data: CellData) {
    cell.itemTitleLabel.text = data.title
    cell.itemSummaryLabel.text = data.description
    cell.itemMetadataLabel.text = data.metadata
    
    var textColor: UIColor
    if case .Played = data.itemState {
      textColor = UIColor.grayColor()
    } else {
      textColor = UIColor.blackColor()
    }
    
    for lbl in [cell.itemTitleLabel, cell.itemSummaryLabel, cell.itemMetadataLabel] {
      lbl.textColor = textColor
    }
  }
  
  // MARK: UITableViewDataSource
  
  @objc func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("Cell")! as! SingleFeedTableViewCell
    let data = cellDataAtIndexPath(indexPath)
    
    configureCell(cell, data: data)
    
    return cell
  }
  
  @objc func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return activeSections[section].results.count
  }
  
  @objc func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return activeSections.count
  }
  
  func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return activeSections[section].name
  }
}

class SingleFeedTableViewCell: UITableViewCell {
  @IBOutlet weak var itemTitleLabel: UILabel!
  @IBOutlet weak var itemSummaryLabel: UILabel!
  @IBOutlet weak var itemMetadataLabel: UILabel!
}

class SingleFeedTableHeaderView: UIView {
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var titleLabel: UILabel!
}

class SingleFeedViewController: UITableViewController {
  var feedID: String!
  
  @IBOutlet weak var headerView: SingleFeedTableHeaderView!
  
  private var viewModel: SingleFeedViewModel!
  
  var player: PlayerController!
  
  var cellHeightCache = [NSIndexPath: CGFloat]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    guard let feedID = feedID else { fatalError("feedID was not set") }
    
    let layer = headerView.imageView.layer
    layer.shadowOffset = CGSize(width: 0, height: 1) // orig height was 2
    layer.shadowRadius = 3; // orig value was 5 (intended for player view)
    layer.shadowOpacity = 0.5;
    
    print(navigationController?.navigationBar.frame)
   
    viewModel = SingleFeedViewModel(feedID: feedID,
                                    tableView: tableView,
                                    headerView: headerView) { color in self.view.backgroundColor = color }
    
    tableView.dataSource = viewModel
  }
  
  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    tableView.reloadData()
  }
  
  // MARK: UITableViewDelegate
  
  override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    player.playItem(viewModel.playerItemAtIndexPath(indexPath))
    print(player.currentItem, player.queuedItems)
    performSegueWithIdentifier("ThePlayerSegue", sender: self)
  }
  
  override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
    cellHeightCache[indexPath] = cell.frame.height
  }
  
  override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
    return cellHeightCache[indexPath] ?? UITableViewAutomaticDimension
  }
}
