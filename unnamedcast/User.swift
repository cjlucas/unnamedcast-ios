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

struct ItemState: JSONDecodable, JSONEncodable {
  var itemID: String
  var state: Item.State
  var modificationTime: NSDate
  
  init(itemID: String, state: Item.State, modificationTime: NSDate) {
    self.itemID = itemID
    self.state = state
    self.modificationTime = modificationTime
  }

  init(json: JSON) throws {
    itemID = try json.string("item_id")
    let itemPos = try json.double("position")
   
    let code = try json.int("state")
    switch code {
    case 0:
      state = .Unplayed
    case 1:
      state = .InProgress(position: itemPos)
    case 2:
      state = .Played
    default:
      fatalError("unexpected state \(code)")
    }
    
    let modTime = try json.string("modification_time")
    if let d = parseDate(modTime) {
      modificationTime = d
    } else {
      throw JSON.Error.ValueNotConvertible(value: JSON.String(modTime), to: NSDate.self)
    }
  }
 
  func toJSON() -> JSON {
    var state = 0
    var position = 0.0
    
    switch self.state {
    case .Unplayed:
      state = 0
    case .InProgress(let pos):
      state = 1
      position = pos
    case .Played:
      state = 2
    }
    
    return [
      "item_id": itemID.toJSON(),
      "state": state.toJSON(),
      "position": position.toJSON(),
      "modification_time": rfc3339Formatter.stringFromDate(modificationTime).toJSON()
    ]
  }
}
