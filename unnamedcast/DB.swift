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
  private let bgQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
  
  lazy var feeds: Results<Feed> = self.realm.objects(Feed)
  lazy var items: Results<Item> = self.realm.objects(Item)
  
  func feedWithID(id: String) -> Feed? {
    return realm.objectForPrimaryKey(Feed.self, key: id)
  }
  
  func itemWithID(id: String) -> Item? {
    return realm.objectForPrimaryKey(Item.self, key: id)
  }
  
  func add(obj: Object, update: Bool = false) {
    realm.add(obj, update: update)
  }
  
  required init(configuration: Configuration? = nil) throws {
    if let conf = configuration {
      realm = try Realm(configuration: conf.realmConfig)
    } else {
      realm = try Realm()
    }
  }
  
  func write(f: () -> Void) throws {
    realm.beginWrite()
    f()
    try realm.commitWrite()
  }
  
  func deleteAll() throws {
    try write { self.realm.deleteAll() }
  }
}