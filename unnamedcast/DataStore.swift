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
  
  
  func sync(onComplete: () -> Void) {
    let userID = ud.objectForKey("user_id") as! String
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
}