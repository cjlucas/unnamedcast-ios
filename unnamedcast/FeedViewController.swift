//
//  FeedViewController.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 1/28/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Foundation
import UIKit
import RealmSwift
import Alamofire
import SDWebImage

class FeedCollectionViewModel: NSObject, UICollectionViewDataSource {
  let db = try! DB()
  var feedsUpdatedToken: NotificationToken!
  
  private var feeds: Results<Feed> {
    return db.feeds
  }
  
  init(collectionView: UICollectionView) {
    feedsUpdatedToken = db.feeds.addNotificationBlock { (_: RealmCollectionChange<Results<Feed>>) in
      collectionView.reloadData()
    }
  }
  
  deinit {
    feedsUpdatedToken.stop()
  }
  
  func feedIDAtIndexPath(path: NSIndexPath) -> String {
    return self.feeds[path.row].id
  }
  
  // MARK: UICollectionViewDataSource
  
  func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return feeds.count
  }
  
  func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
    let feed = feeds[indexPath.row]
    
    let cell = collectionView.dequeueReusableCellWithReuseIdentifier("FeedCollectionViewCell",
                                                                     forIndexPath: indexPath) as! FeedCollectionViewCell
    
    if let url = NSURL(string: feed.imageUrl) {
      cell.imageView.sd_setImageWithURL(url)
    }
    
    return cell
  }
}

class FeedCollectionViewCell: UICollectionViewCell {
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var titleView: UILabel!
  @IBOutlet weak var detailView: UILabel!
}

class FeedViewController: UICollectionViewController {
  var selectedFeedId: String!
  var viewModel: FeedCollectionViewModel!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    viewModel = FeedCollectionViewModel(collectionView: collectionView!)
    collectionView?.dataSource = viewModel
  }
  
  override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
    selectedFeedId = viewModel.feedIDAtIndexPath(indexPath)
    performSegueWithIdentifier("TheSegue", sender: self)
  }
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if let vc = segue.destinationViewController as? SingleFeedViewController {
      vc.feedID = selectedFeedId
    }
  }
}
