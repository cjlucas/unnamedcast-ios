//
//  DB.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 5/8/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Foundation
import RealmSwift
import PromiseKit

class DB {
  struct Configuration {
    let realmConfig: Realm.Configuration
  }
  
  private var realm: Realm
  
  lazy var feeds: Results<Feed> = self.realm.objects(Feed)
  lazy var items: Results<Item> = self.realm.objects(Item)
  
  func unplayedItemsForFeed(feed: Feed) -> Results<Item> {
    return feed.items.filter("playing == true AND position == nil")
  }

  func playedItemsForFeed(feed: Feed) -> Results<Item> {
    return feed.items.filter("playing == false")
  }
  
  func inProgressItemsForFeed(feed: Feed) -> Results<Item> {
    return feed.items.filter("playing == true && position > 0")
  }
  
  func feedWithID(id: String) -> Feed? {
    return realm.objectForPrimaryKey(Feed.self, key: id)
  }
  
  func itemWithID(id: String) -> Item? {
    return realm.objectForPrimaryKey(Item.self, key: id)
  }
  
  func add(obj: Object, update: Bool = false) {
    realm.add(obj, update: update)
  }
  
  func addNotificationBlockForFeedUpdate(feed: Feed, block: () -> ()) -> NotificationToken {
    return self.realm
      .objects(Feed.self)
      .filter("id = %@", feed.id)
      .addNotificationBlock { (res: RealmCollectionChange<Results<Feed>>) in
        block()
    }
  }
  
  required init(configuration: Configuration? = nil) throws {
    if let conf = configuration {
      realm = try Realm(configuration: conf.realmConfig)
    } else {
      realm = try Realm()
    }
  }
  
  func write(f: () -> Void) throws {
    try realm.write(f)
  }
  
  func deleteAll() throws {
    try write { self.realm.deleteAll() }
  }
}

struct ResultsCache<T: Object> {
  var results: Results<T>
  
  private var cache = [Int: T]()
  
  subscript(index: Int) -> T {
    mutating get {
      
      if let v = cache[index] {
        return v
      }
      
      return results[index]
    }
  }
}