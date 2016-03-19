//
//  User.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 3/12/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import RealmSwift
import Freddy

class User: JSONDecodable {
  var id: String!
  var username: String!
  var feedIDs = [String]()
  var itemStates = [ItemState]()
  
  convenience required init(json: JSON) throws {
    self.init()
 
    id = try json.string("id")
    username = try json.string("username")
    
    if let ids = try? json.array("feeds").map(String.init) {
      feedIDs.appendContentsOf(ids)
    }
    
    if let states = try? json.array("states").map(ItemState.init) {
      itemStates.appendContentsOf(states)
    }
  }
}

class ItemState: JSONDecodable, JSONEncodable {
  var feedID: String!
  var itemGUID: String!
  var itemPos: Double!
  
  convenience init(item: Item, pos: Double) {
    self.init()
    
    feedID = item.feed.id
    itemGUID = item.guid
    itemPos = pos
  }
  
  convenience required init(json: JSON) throws {
    self.init()
    
    feedID = try json.string("feed_id")
    itemGUID = try json.string("item_guid")
    itemPos = try json.double("position")
  }
 
  func toJSON() -> JSON {
    return [
      "feed_id": feedID.toJSON(),
      "item_guid": itemGUID.toJSON(),
      "position": itemPos.toJSON()
    ]
  }
}