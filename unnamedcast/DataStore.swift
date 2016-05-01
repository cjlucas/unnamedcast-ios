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

internal enum Error: ErrorType {
  case NetworkError(String)
  case APIError(String)
  case JSONError(String)
}

typealias JSONRequester = (req: URLRequestConvertible) -> Promise<JSONResponse>
typealias JSONResponse = (req: NSURLRequest, resp: NSHTTPURLResponse, json: JSON)

private func reqJSON(req: URLRequestConvertible) -> Promise<JSONResponse> {
  return Promise { fulfill, reject in
    Alamofire.request(req).response { resp in
      if let err = resp.3 {
        return reject(Error.NetworkError(err.description))
      }
     
      let json = try! JSON(data: resp.2!)
      return fulfill((req: resp.0!, resp: resp.1!, json: json))
    }
  }
}

class DataStore {
  struct Configuration {
    let realmConfig: Realm.Configuration?
    let requestJSON: JSONRequester
  }
  
  let realm: Realm
  let config: Configuration
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
  
  var feedSyncTimes: [String: NSDate] {
    get {
      let dct = ud.dictionaryForKey("feed_sync_times")
      if let d = dct {
        return d as! [String: NSDate]
      }
      return [String: NSDate]()
    }
    set(times) {
      ud.setObject(times, forKey: "feed_sync_times")
    }
  }
  
  lazy var feeds: Results<Feed> = self.realm.objects(Feed)
  lazy var items: Results<Item> = self.realm.objects(Item)
  
  required init(configuration: Configuration) {
    config = configuration
    if let conf = config.realmConfig {
      realm = try! Realm(configuration: conf)
    } else {
      realm = try! Realm()
    }
  }

  convenience init() {
    self.init(configuration: Configuration(realmConfig: nil, requestJSON: reqJSON))
  }
  
  private func findFeed(id: String) -> Feed? {
    return feeds.filter("id = %@", id).first
  }
  
  private func findItem(id: String) -> Item? {
    return items.filter("id = %@", id).first
  }
  
  func requestJSON(endpoint: APIEndpoint, expectedStatusCodes: [Int] = [200]) -> Promise<JSON> {
    return self.config.requestJSON(req: endpoint).then { resp -> JSON in
      let code = resp.resp.statusCode
      if !expectedStatusCodes.contains(code) {
        throw Error.APIError("Unexpected status code \(code)")
      }
      
      return resp.json
    }
  }
  
  func fetchUserInfo() -> Promise<User> {
    return requestJSON(.GetUserInfo(id: userID)).then { json -> User in
      return try User(json: json)
    }
  }
  
  func fetchUserStates() -> Promise<[ItemState]> {
    return requestJSON(.GetUserItemStates(userID: userID)).then { json in
      return try! json.array().map(ItemState.init)
    }
  }
  
  func saveUserStates(states: [ItemState]) {
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
  
  func uploadItemStates() -> Promise<Void> {
    return Promise { fulfill, reject in
      let states = self.realm.objects(Item)
        .filter("playing != false")
        .map { ItemState(item: $0, pos: $0.position.value!) }
      
      let ep = APIEndpoint.UpdateUserItemStates(userID: self.userID)
      let data = try! states.toJSON().serialize()
      Alamofire.upload(ep, data: data).response { resp in
        if let err = resp.3 {
          return reject(Error.NetworkError(err.description))
        }
        
        if let code = resp.1?.statusCode where code != 200 {
          return reject(Error.APIError("Unexpected status code \(code)"))
        }
        
        return fulfill()
      }
    }
  }
  
  func syncItemStates() -> Promise<Void> {
    return fetchUserStates().then { states in
      self.saveUserStates(states)
      return self.uploadItemStates()
    }
  }
  
  func fetchFeed(feedID: String, itemsModifiedSince: NSDate?) -> Promise<Feed> {
    let promises = [
      APIEndpoint.GetFeed(id: feedID),
      APIEndpoint.GetFeedItems(id: feedID, modificationsSince: itemsModifiedSince),
    ].map({ self.config.requestJSON(req: $0) })
    
    return when(promises).then { resps -> Feed in
      for resp in resps {
        let code = resp.resp.statusCode
        guard code == 200 else {
          throw Error.APIError("Unexpected status code \(code)")
        }
      }
      
      let feed = try Feed(json: resps[0].json)
      let items = try resps[1].json.array().map(Item.init)
      feed.items.appendContentsOf(items)
      return feed
    }
  }
  
  func fetchUserFeeds(feedIDs: [String]) -> Promise<[Feed]> {
    let syncTimes = feedSyncTimes
    return when(feedIDs.map({ self.fetchFeed($0, itemsModifiedSince: syncTimes[$0]) }))
  }
  
  func saveUserFeeds(feeds: [Feed]) {
    try! self.realm.write {
      for feed in feeds {
        print("Updating feed \(feed.title)")
        
        // If feed does not exist in store, add it to the store...
        guard let f = findFeed(feed.id) else {
          self.realm.add(feed)
          continue
        }
        
        // ...otherwise update all items
        for item in feed.items {
          print("Updating item", item)
          
          guard let oldItem = findItem(item.id) else {
            f.items.append(item)
            self.realm.add(f, update: true)
            continue
          }
          
          item.state = oldItem.state
          self.realm.add(item, update: true)
        }
      }
    }

    var syncTimes = feedSyncTimes
    
    for f in feeds {
      syncTimes[f.id] = f.modificationDate
    }
    
    feedSyncTimes = syncTimes
  }
  
  func syncUserFeeds() -> Promise<Void> {
    return fetchUserInfo().then { user in
      return self.fetchUserFeeds(user.feedIDs)
    }.then { feeds in
      self.saveUserFeeds(feeds)
    }
  }
  
  func sync(onComplete: () -> Void) {
    firstly {
      self.fetchUserInfo()
      return self.syncUserFeeds()
    }.then {
      return self.syncItemStates()
    }.then { () -> Void in
      print("Synced successfully")
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