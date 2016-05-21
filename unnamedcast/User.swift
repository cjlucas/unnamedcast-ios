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
  var itemID: String!
  var itemPos: Double!
  var modificationTime: NSDate!

  convenience init(itemID: String, pos: Double, modificationTime: NSDate) {
    self.init()
    
    self.itemID = itemID
    itemPos = pos
    self.modificationTime = modificationTime
  }
  
  convenience required init(json: JSON) throws {
    self.init()
    
    itemID = try json.string("item_id")
    itemPos = try json.double("position")
    
    let modTime = try json.string("modification_time")
    if let d = parseDate(modTime) {
      modificationTime = d
    } else {
      throw JSON.Error.ValueNotConvertible(value: JSON.String(modTime), to: NSDate.self)
    }
  }
 
  func toJSON() -> JSON {
    return [
      "item_id": itemID.toJSON(),
      "position": itemPos.toJSON(),
      "modification_time": rfc3339Formatter.stringFromDate(modificationTime).toJSON()
    ]
  }
}
