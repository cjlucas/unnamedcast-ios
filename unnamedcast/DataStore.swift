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

internal enum Error: ErrorType {
  case NetworkError(String)
  case APIError(String)
  case JSONError(String)
}

typealias JSONRequester = (req: URLRequestConvertible) -> Promise<JSONResponse>
typealias JSONResponse = (req: NSURLRequest, resp: NSHTTPURLResponse, json: JSON)

private func reqJSON(req: URLRequestConvertible) -> Promise<JSONResponse> {
  print(req.URLRequest.URL)
  
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
    let dbConfiguration: DB.Configuration?
    let requestJSON: JSONRequester
  }
  
  static let defaultConfiguration = Configuration(dbConfiguration: nil, requestJSON: reqJSON)
  
  let db: DB
  let config: Configuration
  let ud = NSUserDefaults.standardUserDefaults()

  // TODO(clucas): Wrap NSUserDefaults in a class with these properties
  var userID: String {
    get { return ud.objectForKey("user_id") as! String }
    set(id) { ud.setObject(id, forKey: "user_id") }
  }
  
  var syncToken: String? {
    get { return ud.objectForKey("sync_token") as? String }
    set(id) { ud.setObject(id, forKey: "sync_token") }
  }
  
  required init(configuration: Configuration) throws {
    config = configuration
    db = try DB(configuration: config.dbConfiguration)
  }

  convenience init() throws {
    try self.init(configuration: DataStore.defaultConfiguration)
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
  
  func saveUserStates(states: [ItemState]) -> Promise<Void> {
    let start = NSDate()
   
    return db.write { db in
      // Reset state for all items
      for item in db.items {
        item.state = State.Played
      }
      
      print("here1: ", NSDate().timeIntervalSinceDate(start))
      
      for state in states {
        guard let item = db.items
          .filter("guid = %@ AND feed.id = %@", state.itemGUID, state.feedID)
          .first else { continue }

        item.state = state.itemPos.isZero
          ? State.Unplayed
          : State.InProgress(position: state.itemPos)
      }
      
      print("here2: ", NSDate().timeIntervalSinceDate(start))
    }
  }
  
  func uploadItemStates() -> Promise<Void> {
    return Promise { fulfill, reject in
      let states = db.items
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
    return firstly {
      return fetchUserStates()
    }.then { states in
      return self.saveUserStates(states)
    }.then {
      return self.uploadItemStates()
    }
  }
  
  func fetchFeed(feedID: String, itemsModifiedSince: NSDate?) -> Promise<(Feed, [Item])> {
    let promises = [
      APIEndpoint.GetFeed(id: feedID),
      APIEndpoint.GetFeedItems(id: feedID, modificationsSince: itemsModifiedSince),
    ].map({ self.config.requestJSON(req: $0) })
    
    return when(promises).then { resps -> (Feed, [Item]) in
      for resp in resps {
        let code = resp.resp.statusCode
        guard code == 200 else {
          throw Error.APIError("Unexpected status code \(code)")
        }
      }
      
      let feed = try Feed(json: resps[0].json)
      var items = [Item]()
      if let arr = try? resps[1].json.array().map(Item.init) {
        items = arr
      }
    
      print("Fetched feed successfully title=\(feed.title) numItems=\(items.count)")
      return (feed: feed, items: items)
    }
  }
  
  func fetchUserFeeds(feedIDs: [String]) -> Promise<[(Feed, [Item])]> {
    var feedIDsModifiedSinceMap = [String: NSDate]()
    for id in feedIDs {
      feedIDsModifiedSinceMap[id] = db.feedWithID(id)?.lastSyncedTime
    }
    return when(feedIDs.map({ self.fetchFeed($0, itemsModifiedSince: feedIDsModifiedSinceMap[$0]) }))
  }
  
  func saveUserFeeds(feeds: [(Feed, [Item])]) -> Promise<Void> {
    return db.write { db in
      for (feed, items) in feeds {
        if db.feedWithID(feed.id) == nil {
          db.add(feed)
        }
        
        for item in items {
          item.feed = feed
          if let oldItem = db.itemWithID(item.id) {
            item.state = oldItem.state
          }
          
          db.add(item, update: true)
        }
      }
    }
  }
  
  func syncUserFeeds() -> Promise<Void> {
    return fetchUserInfo().then { user in
      return self.fetchUserFeeds(user.feedIDs)
    }.then { feeds in
      return self.saveUserFeeds(feeds)
    }
  }
  
  func sync(onComplete: () -> Void) {
    firstly {
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
      self.db.write { db in
        item.playing = true
        item.state = .InProgress(position: progress)
        db.add(item, update: true)
      }.then {
        self.uploadItemStates()
      }.then {
        onComplete()
      }
    }
  }
}
