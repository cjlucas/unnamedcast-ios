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

class FeedViewController: UICollectionViewController {
    var realm = try! Realm()
    var selectedFeedId: String?
    var token: NotificationToken?

    override func viewDidAppear(animated: Bool) {
        print("RAWR")
        token = realm.addNotificationBlock { notification, realm in
            self.collectionView?.reloadData()
        }

        super.viewDidAppear(animated)
    }

    override func viewDidDisappear(animated: Bool) {
        if let token = self.token {
          token.stop()
        }

        super.viewDidDisappear(animated)
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print("num items", realm.objects(Feed).count)
        return realm.objects(Feed).count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let feed = realm.objects(Feed)[indexPath.row]
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("FeedCollectionViewCell", forIndexPath: indexPath) as! FeedCollectionViewCell
//        cell.titleView.text = feed.title
//        cell.detailView.text = feed.author
        
        Alamofire.request(.GET, feed.imageUrl).responseData { resp in
            if let data = resp.data {
                cell.imageView.image = UIImage(data: data)
            }
        }
        
        return cell
    }
    
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let feeds = realm.objects(Feed)
        selectedFeedId = feeds[indexPath.row].id

        performSegueWithIdentifier("TheSegue", sender: self)
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let vc = segue.destinationViewController as? SingleFeedViewController,
            let id = selectedFeedId {
            vc.feedId = id
        }
    }
}
