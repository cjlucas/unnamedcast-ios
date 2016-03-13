//
//  DataStore.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 3/5/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Alamofire
import Freddy
import RealmSwift

class DataStore {
  let realm = try! Realm()
  let ud = NSUserDefaults.standardUserDefaults()
  static let apiHost = "192.168.1.19"
  static let apiPort = 8080
  
  var userID: String {
    get {
      return ud.objectForKey("user_id") as! String
    }
    set(id) {
      ud.setObject(id, forKey: "user_id")
    }
  }
  
  func sync(onComplete: () -> Void) {
    let ep = APIEndpoint.GetUserFeeds(userID: userID, syncToken: nil)
    Alamofire.request(ep).response { resp in
      guard resp.3 == nil else {
        print("Error while syncing: \(resp.3)")
        return onComplete()
      }
      
      guard resp.1?.statusCode == 200 else {
        print("Error while syncing: Unexpected error code \(resp.1?.statusCode)")
        return onComplete()
      }
      
      let json = try! JSON(data: resp.2!)
      
      for feed in try! json.array().map(Feed.init) {
        try! self.realm.write {
          self.realm.add(feed, update: true)
        }
      }
      
      onComplete()
    }
  }
  
  func updateItemState(item: Item, progress: Double, onComplete: () -> Void) {
    // fetch latest state info
    let ep = APIEndpoint.GetUserItemStates(userID: userID)
    Alamofire.request(ep).response { resp in
      guard resp.3 == nil else {
        print("Error while syncing: \(resp.3)")
        return onComplete()
      }
      
      guard resp.1?.statusCode == 200 else {
        print("Error while syncing: Unexpected error code \(resp.1?.statusCode)")
        return onComplete()
      }
      
      let json = try! JSON(data: resp.2!)
      for state in try! json.array().map(ItemState.init) {
        var items = [Item](self.realm.objects(Item).filter("guid == %@", state.itemGUID))
        items = items.filter { (item) -> Bool in
          return item.feed.id == state.feedID
        }
       
        if let item = items.first {
          try! self.realm.write {
            item.playing = true
            item.position = state.itemPos
          }
        }
      }
      
      try! self.realm.write {
        item.playing = true
        item.position = progress
        self.realm.add(item, update: true)
      }
      
      let states = self.realm.objects(Item)
        .filter("playing == true")
        .map { ItemState(item: $0, pos: $0.position) }
      
      let ep2 = APIEndpoint.UpdateUserItemStates(userID: self.userID)
      Alamofire.upload(ep2, data: try! states.toJSON().serialize()).response { resp in
        onComplete()
      }
      
    }
  }
}