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

class SingleFeedViewController: UITableViewController {
    var feedId: String?
    var realm = try! Realm()
    
    lazy var feed: Feed = {
        if let id = self.feedId {
            return self.realm.objects(Feed).filter("id == '\(id)'").first!
        }
        fatalError("Feed not set")
    }()
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let item = feed.items[indexPath.row]
        
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell")!
        cell.textLabel?.text = item.title
        return cell
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return feed.items.count
    }
}