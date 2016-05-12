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

class DataStore {
  struct Configuration {
    let dbConfiguration: DB.Configuration?
    let endpointRequester: EndpointRequestable
  }
  
  static let defaultConfiguration = Configuration(dbConfiguration: nil,
                                                  endpointRequester: APIClient())
  
  let config: Configuration
  let ud = NSUserDefaults.standardUserDefaults()
  let backgroundQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)
  
  var requester: EndpointRequestable {
    return config.endpointRequester
  }
  
  private func newDB() throws -> DB {
    return try DB(configuration: config.dbConfiguration)
  }

  // TODO(clucas): Wrap NSUserDefaults in a class with these properties
  var userID: String {
    get { return ud.objectForKey("user_id") as! String }
    set(id) { ud.setObject(id, forKey: "user_id") }
  }
  
  var syncToken: String? {
    get { return ud.objectForKey("sync_token") as? String }
    set(id) { ud.setObject(id, forKey: "sync_token") }
  }
  
  required init(configuration: Configuration) {
    config = configuration
  }

  convenience init() {
    self.init(configuration: DataStore.defaultConfiguration)
  }
  
  // MARK: - User
  
  func fetchUserInfo() -> Promise<User> {
    let ep = GetUserEndpoint(id: userID)
    return requester.request(ep).then { _, _, user in return user }
  }
  
  func fetchUserStates() -> Promise<[ItemState]> {
    let ep = GetUserItemStates(userID: userID)
    return requester.request(ep).then { _, _, states in return states }
  }
  
  func saveUserStates(states: [ItemState]) throws {
    let start = NSDate()
    let db = try newDB()
    try db.write {
      // Reset state for all items
      for item in db.items {
        item.state = State.Played
      }
      
      print("here1: ", start.timeIntervalSinceNow)
      
      for state in states {
        guard let item = db.items
          .filter("guid = %@ AND feed.id = %@", state.itemGUID, state.feedID)
          .first else { continue }

        item.state = state.itemPos.isZero
          ? State.Unplayed
          : State.InProgress(position: state.itemPos)
      }
      
      print("here2: ", start.timeIntervalSinceNow)
    }
  }
  
  func uploadItemStates() -> Promise<Void> {
    return dispatch_promise(on: backgroundQueue) { () -> [ItemState] in
      let db = try self.newDB()
      
      return db.items
        .filter("playing != false")
        .map { ItemState(item: $0, pos: $0.position.value!) }
    }.then(on: backgroundQueue) { states -> Promise<(NSURLRequest, NSHTTPURLResponse)> in
      let ep = UpdateUserItemStatesEndpoint(userID: self.userID, states: states)
      return self.requester.request(ep)
    }.then { _, _ in return }
  }
  
  func syncItemStates() -> Promise<Void> {
    return firstly {
      return fetchUserStates()
    }.then(on: backgroundQueue) { states in
      try self.saveUserStates(states)
    }.then(on: backgroundQueue) {
      return self.uploadItemStates()
    }
  }
  
  // MARK: - Feeds
  
  func fetchFeed(feedID: String, itemsModifiedSince: NSDate?) -> Promise<(Feed, [Item])> {
    let p1 = requester.request(GetFeedEndpoint(id: feedID)).then { _, _, feed in
      return feed
    }
    let p2 = requester.request(GetFeedItemsEndpoint(id: feedID, modificationsSince: itemsModifiedSince)).then { _, _, items in
      return items
    }
    
    return when(p1, p2).then(on: backgroundQueue) { feed, items -> (Feed, [Item]) in
      print("Fetched feed successfully title=\(feed.title) numItems=\(items.count)")
      return (feed: feed, items: items)
    }
  }
  
  func fetchUserFeeds(feedIDs: [String]) -> Promise<[(Feed, [Item])]> {
    return dispatch_promise(on: backgroundQueue) { () -> [String: NSDate] in
      let db = try self.newDB()
      
      var feedIDsModifiedSinceMap = [String: NSDate]()
      for id in feedIDs {
        feedIDsModifiedSinceMap[id] = db.feedWithID(id)?.lastSyncedTime
      }
      
      return feedIDsModifiedSinceMap
    }.then(on: backgroundQueue) { m in
      return when(feedIDs.map { self.fetchFeed($0, itemsModifiedSince: m[$0]) })
    }
  }
  
  func saveUserFeeds(feeds: [(Feed, [Item])]) throws {
    let db = try newDB()
    try db.write {
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
    return fetchUserInfo()
    .then(on: backgroundQueue) { user in
      return self.fetchUserFeeds(user.feedIDs)
    }.then(on: backgroundQueue) { feeds in
      try self.saveUserFeeds(feeds)
    }
  }
  
  // MARK: -
  
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
    let db = try! newDB()
    let ep = GetUserItemStates(userID: userID)
    requester.request(ep).thenInBackground { req, res, states in
      try! db.write {
        item.playing = true
        item.state = .InProgress(position: progress)
        db.add(item, update: true)
      }
      
      self.uploadItemStates().then {
        onComplete()
      }
    }
  }
}
