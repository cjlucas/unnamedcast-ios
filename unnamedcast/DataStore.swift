//
//  DataStore.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 3/5/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Alamofire
import PromiseKit
import Freddy
import RealmSwift

enum BlahError: ErrorType {
  case NetworkError(String)
  case APIError(String)
}

protocol NewDataStoreAPI {
  // Fetch step (networking)
  func fetchUserStates() -> [ItemState]
  // Merge step (db)
  func mergeUserStates(states: [ItemState])
  // Upload step (db/networking)
  func uploadUserStates()
  // Sync procedure would utilize the above functions
  func syncUserStates()
}

class DataStore {
  let realm = try! Realm()
  let ud = NSUserDefaults.standardUserDefaults()
  static let apiHost = "192.168.1.19"
  static let apiPort = 8080

  // TODO(clucas): Wrap NSUserDefaults in a class with these properties
  var userID: String {
    get { return ud.objectForKey("user_id") as! String }
    set(id) { ud.setObject(id, forKey: "user_id") }
  }
  
  var syncToken: String? {
    get { return ud.objectForKey("sync_token") as? String }
    set(id) { ud.setObject(id, forKey: "sync_token") }
  }
  
  lazy var feeds: Results<Feed> = self.realm.objects(Feed)
  lazy var items: Results<Item> = self.realm.objects(Item)
  
  private func fetchUserInfo() -> Promise<User> {
    return Promise { fulfill, reject in
    }
  }
  
  private func fetchUserStates() -> Promise<[ItemState]> {
    return Promise { fulfill, reject in
      let ep = APIEndpoint.GetUserItemStates(userID: userID)
      Alamofire.request(ep).response { resp in
        if let err = resp.3 {
          return reject(BlahError.NetworkError(err.description))
        }
        
        if let code = resp.1?.statusCode where code != 200 {
          return reject(BlahError.APIError("Unexpected status code \(code)"))
        }
        
        let json = try! JSON(data: resp.2!)
        return fulfill(try! json.array().map(ItemState.init))
      }
    }
  }
  
  private func saveUserStates(states: [ItemState]) {
    var statefulItems = [Item]()
    
    self.realm.beginWrite()
    
    for state in states {
      var items = [Item](self.realm.objects(Item).filter("guid == %@", state.itemGUID))
      items = items.filter { (item) -> Bool in
        return item.feed.id == state.feedID
      }
      
      statefulItems.appendContentsOf(items)
      
      if let item = items.first {
        item.state = state.itemPos.isZero
          ? State.Unplayed
          : State.InProgress(position: state.itemPos)
      }
    }
    
    for item in self.realm.objects(Item) {
      if !statefulItems.contains({$0.guid == item.guid}) {
        item.state = State.Played
      }
    }
    
    try! self.realm.commitWrite()
  }
  
  private func uploadItemStates() -> Promise<Void> {
    return Promise { fulfill, reject in
      let states = self.realm.objects(Item)
        .filter("playing != false")
        .map { ItemState(item: $0, pos: $0.position.value!) }
      
      let ep = APIEndpoint.UpdateUserItemStates(userID: self.userID)
      let data = try! states.toJSON().serialize()
      Alamofire.upload(ep, data: data).response { resp in
        if let err = resp.3 {
          return reject(BlahError.NetworkError(err.description))
        }
        
        if let code = resp.1?.statusCode where code != 200 {
          return reject(BlahError.APIError("Unexpected status code \(code)"))
        }
        
        return fulfill()
      }
    }
  }
  
  private func fetchUserFeeds() -> Promise<[Feed]> {
    return Promise { fulfill, reject in
      let ep = APIEndpoint.GetUserFeeds(userID: userID, syncToken: syncToken)
      Alamofire.request(ep).response { resp in
        if let err = resp.3 {
          return reject(BlahError.NetworkError(err.description))
        }
        
        if let code = resp.1?.statusCode where code != 200 {
          return reject(BlahError.APIError("Unexpected status code \(code)"))
        }
        
        self.syncToken = resp.1?.allHeaderFields["X-Sync-Token"] as? String
        
        let json = try! JSON(data: resp.2!)
        return fulfill(try! json.array().map(Feed.init))
      }
    }
  }
  
  private func saveUserFeeds(feeds: [Feed]) {
    try! self.realm.write {
      for feed in feeds {
        print("Updating feed \(feed.title)")
        
        // If feed does not exist in store, add it to the store...
        guard self.feeds.filter("id = %@", feed.id).first != nil else {
          self.realm.add(feed)
          continue
        }
        
        // ...otherwise update all items
        for item in feed.items {
          if let oldItem = self.items.filter("key = %@", item.key).first {
            item.state = oldItem.state
          }
          
          print("Updating item", item)
          self.realm.add(item, update: true)
        }
      }
    }
  }
  
  func sync(onComplete: () -> Void) {
    firstly {
      return fetchUserFeeds()
    }.then { (feeds: [Feed]) -> Promise<[ItemState]> in
      self.saveUserFeeds(feeds)
      return self.fetchUserStates()
    }.then { states in
      self.saveUserStates(states)
      return self.uploadItemStates()
    }.then {
      onComplete()
    }.error { err in
      print("Error while syncing:", err)
    }
  }
  
  func updateItemState(item: Item, progress: Double, onComplete: () -> Void) {
    let ep = APIEndpoint.GetUserItemStates(userID: userID)
    Alamofire.request(ep).response { resp in
      try! self.realm.write {
        item.playing = true
        item.state = .InProgress(position: progress)
        self.realm.add(item, update: true)
      }
      
      self.uploadItemStates().then { _ in onComplete() }
    }
  }
}