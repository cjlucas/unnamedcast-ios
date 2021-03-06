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

extension NSDate {
  var year: Int {
    var year: Int = 0
    NSCalendar.currentCalendar().getEra(nil, year: &year, month: nil, day: nil, fromDate: self)
    return year
  }
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
  
  private let db = try! DB()
  private var feed: Feed
  
  var feedUpdateNotificationToken: NotificationToken
 
  private lazy var sections: [TableSection] = {
    return [
      TableSection(name: "In Progress", results: self.db.inProgressItemsForFeed(self.feed).sorted("pubDate", ascending: false)),
      TableSection(name: "Unplayed", results: self.db.unplayedItemsForFeed(self.feed).sorted("pubDate", ascending: false)),
      TableSection(name: "Played", results: self.db.playedItemsForFeed(self.feed).sorted("pubDate", ascending: false)),
    ]
  }()
  
  private var activeSections: [TableSection] {
    return sections.filter { section in section.results.count > 0 }
  }
  
  var items: Results<Item> {
    return self.feed.items.sorted("pubDate", ascending: false)
  }
  
  required init(feedID: String, tableView: UITableView, titleView: NavigationItemFeedInfoTitleView) {
    guard let feed = self.db.feedWithID(feedID) else {
      fatalError("Feed was not found")
    }
   
    self.feed = feed
    self.tableView = tableView
    titleView.primaryLabel.text = feed.title
    titleView.secondaryLabel.text = feed.author

    self.tableView?.estimatedRowHeight = 140
    self.tableView?.rowHeight = UITableViewAutomaticDimension

    weak var weakTableView = tableView
    feedUpdateNotificationToken = self.db.addNotificationBlockForFeedUpdate(feed) {
      weakTableView?.beginUpdates()
      weakTableView?.reloadData()
      weakTableView?.endUpdates()
    }
  }
  
  deinit {
    feedUpdateNotificationToken.stop()
  }

  private func itemAtIndexPath(path: NSIndexPath) -> Item! {
    return activeSections[path.section].results[path.row]
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
    let date = item.pubDate ?? item.modificationDate ?? NSDate()
    
    guard let locale = NSLocale.preferredLanguages().first else {
      fatalError("Didn't expect preferredLanguages() to be empty")
    }
    
    let df = NSDateFormatter()
    df.dateFormat = NSDateFormatter.dateFormatFromTemplate(
      date.year == NSDate().year ? "MMM dd" : "MMM dd y",
      options: 0,
      locale: NSLocale(localeIdentifier: locale)
    )
    
    metadata.append(df.stringFromDate(date))
    
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
      textColor = UIColor(red: 146/255.0, green: 146/255.0, blue: 146/255.0, alpha: 1)
    } else {
      textColor = UIColor.blackColor()
    }
    
    for lbl in [cell.itemTitleLabel, cell.itemSummaryLabel] {
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

class NavigationItemFeedInfoTitleView: UIView {
  let primaryLabel = UILabel()
  let secondaryLabel = UILabel()
  private let stackView: UIStackView
  
  override init(frame: CGRect) {
    stackView = UIStackView(frame: frame)
  
    let desc = primaryLabel.font.fontDescriptor().fontDescriptorWithSymbolicTraits(UIFontDescriptorSymbolicTraits([.TraitBold, .TraitCondensed]))
    primaryLabel.font = UIFont(descriptor: desc, size: 18)
    primaryLabel.numberOfLines = 1
    primaryLabel.adjustsFontSizeToFitWidth = true
    
    secondaryLabel.font = UIFont.boldSystemFontOfSize(10)
    secondaryLabel.textColor = UIColor(red: 146/255.0, green: 146/255.0, blue: 146/255.0, alpha: 1)
    
    stackView.axis = .Vertical
    stackView.alignment = .Center
    stackView.distribution = .FillProportionally
    
    stackView.addArrangedSubview(primaryLabel)
    stackView.addArrangedSubview(secondaryLabel)
    
    super.init(frame: frame)
    addSubview(stackView)
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

class SingleFeedViewController: UITableViewController {
  var feedID: String!
  
  private var viewModel: SingleFeedViewModel!
  
  var player: PlayerController!
  
  var cellHeightCache = [NSIndexPath: CGFloat]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    guard let feedID = feedID else { fatalError("feedID was not set") }
   
    let titleView = NavigationItemFeedInfoTitleView(frame: CGRect(x: 0, y: 0, width: 200, height: 36))
    navigationItem.titleView = titleView
    
    viewModel = SingleFeedViewModel(feedID: feedID, tableView: tableView, titleView: titleView)
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
