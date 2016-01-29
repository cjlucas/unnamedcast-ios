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

class FeedViewController: UITableViewController {
    var realm = try! Realm()
    var selectedFeedId: String?
    var token: NotificationToken?
    
    override func viewDidAppear(animated: Bool) {
        token = realm.addNotificationBlock { notification, realm in
            self.tableView.reloadData()
        }

        super.viewDidAppear(animated)
    }
    
    override func viewDidDisappear(animated: Bool) {
        if let token = self.token {
            self.realm.removeNotification(token)
        }
        
        super.viewDidDisappear(animated)
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let feeds = realm.objects(Feed)
       
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell")!
        cell.textLabel?.text = feeds[indexPath.row].title
        
        return cell
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let feeds = realm.objects(Feed)
        return feeds.count
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let feeds = realm.objects(Feed)
        selectedFeedId = feeds[indexPath.row].id
        
        performSegueWithIdentifier("TheSegue", sender: self)
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        let vc = segue.destinationViewController as! SingleFeedViewController
        if let id = selectedFeedId {
            vc.feedId = id
        }
    }
}