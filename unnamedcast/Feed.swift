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
  let items = List<Item>()
  var modificationDate: NSDate!
  
  override static func primaryKey() -> String? {
    return "id"
  }

  override static func ignoredProperties() -> [String] {
    return ["modificationDate"]
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
    
    if let jsonItems = try? json.array("items") {
      for item in jsonItems {
        let item = try Item(json: item)
        item.key = "\(id)-\(item.guid)"
        items.append(item)
      }
    }
  }
}

enum State {
  case Played
  case Unplayed
  case InProgress(position: Double)
}

class Item: Object, JSONDecodable {
  
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
  let position = RealmOptional<Double>()
  dynamic var key: String = ""
  
  override static func primaryKey() -> String? {
    return "key"
  }
  
  var feed: Feed {
    return linkingObjects(Feed.self, forProperty: "items").first!
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
  }
}
