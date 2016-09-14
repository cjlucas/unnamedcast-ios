//
//  PlaylistTableViewController.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 9/12/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import UIKit
import RealmSwift

protocol PlaylistNewName {
  var name: String { get }
  var comparator: (Item) -> Bool { get }
}

struct ShortPlaylist: PlaylistNewName {
  let name = "Short Listens"
  let comparator: (Item) -> Bool = { $0.duration < 30 * 60 }
}

struct AllUnplayedPlaylist: PlaylistNewName {
  let name = "All Unplayed"
  let comparator: (Item) -> Bool = { item in
    switch item.state {
    case .Unplayed(_):
      return true
    case .InProgress:
      return true
    default:
      return false
    }
  }
}

class PlaylistTableViewController: UITableViewController {
  let playlists: [PlaylistNewName] = [
    ShortPlaylist(), AllUnplayedPlaylist(),
    ]
  
  
  // MARK: - Table view data source
  
  override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    // #warning Incomplete implementation, return the number of sections
    return 1
  }
  
  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return playlists.count
  }
  
  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath)
    
    cell.textLabel?.text = playlists[indexPath.row].name
    
    return cell
  }
  
  /*
   // MARK: - Navigation
   
   // In a storyboard-based application, you will often want to do a little preparation before navigation
   override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
   // Get the new view controller using segue.destinationViewController.
   // Pass the selected object to the new view controller.
   }
   */
}
