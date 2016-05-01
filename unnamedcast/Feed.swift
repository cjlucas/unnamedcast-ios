//
//  Feed.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 1/28/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import RealmSwift
import Freddy

class Feed: Object, JSONDecodable {
  dynamic var id: String = ""
  dynamic var title: String = ""
  dynamic var author: String = ""
  dynamic var imageUrl: String = ""
  var modificationDate: NSDate!
  var itemIds = [String]()
  
  let items = LinkingObjects(fromType: Item.self, property: "feed")
  
  var lastSyncedTime: NSDate {
    get{
      var date = NSDate.distantPast()
      for d in items.map ({ $0.modificationDate }) {
        // TODO: figure out why some modificationDates are nil
        guard d != nil else { continue }
        date = d.laterDate(date)
      }
     
      // TOOD(clucas): Hack to prevent pulling in unmodified items multiple times.
      // It appears that the milliseconds value of the date is not being
      // used when being converted to a string. This will have be revisted
      // in the future (whether the solution be either client or server side)
      return date.dateByAddingTimeInterval(1)
    }
  }
  
  override static func primaryKey() -> String? {
    return "id"
  }

  override static func ignoredProperties() -> [String] {
    return ["itemIds"]
  }
  
  convenience required init(json: JSON) throws {
    self.init()
    
    id = try json.string("id")
    title = try json.string("title")
    author = try json.string("author")
    imageUrl = try json.string("image_url")
    
    let modTime = try json.string("modification_time")
    if let modDate = rfc3339Formatter.dateFromString(modTime) {
      modificationDate = modDate
    } else {
      throw Error.JSONError("Failed to parse modification_time: \(modTime)")
    }
   
    if let ids = try? json.array("items").map(String.init) {
      itemIds.appendContentsOf(ids)
    }
  }
}

enum State {
  case Played
  case Unplayed
  case InProgress(position: Double)
}

class Item: Object, JSONDecodable {
  dynamic var id: String = ""
  dynamic var guid: String = ""
  dynamic var link: String = ""
  dynamic var title: String = ""
  dynamic var author: String = ""
  dynamic var desc: String = ""
  dynamic var duration: Int = 0
  dynamic var size: Int = 0
  dynamic var pubDate: String = ""
  dynamic var audioURL: String = ""
  dynamic var imageURL: String = ""
  dynamic var playing: Bool = false
  dynamic var feed: Feed?
  dynamic var modificationDate: NSDate!
  let position = RealmOptional<Double>()
  
  override static func primaryKey() -> String? {
    return "id"
  }

  var state: State {
    get {
      if playing {
        return position.value != nil
          ? State.InProgress(position: position.value!)
          : State.Unplayed
      }
      
      return .Played
    }
    set(newValue) {
      switch(newValue) {
      case .Unplayed:
        playing = true
        position.value = 0
      case .Played:
        playing = false
        position.value = 0
      case .InProgress(let position):
        playing = true
        self.position.value = position
      }
    }
  }
  
  convenience required init(json: JSON) throws {
    self.init()
   
    id = try json.string("id")
    guid = try json.string("guid")
    link = try json.string("link")
    title = try json.string("title")
    author = try json.string("author")
    desc = try json.string("description")
    duration = try json.int("duration")
    size = try json.int("size")
    pubDate = try json.string("publication_time")
    audioURL = try json.string("url")
    imageURL = try json.string("image_url")
    modificationDate = rfc3339Formatter.dateFromString(try json.string("modification_time"))
  }
}
