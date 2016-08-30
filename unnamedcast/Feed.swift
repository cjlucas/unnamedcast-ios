//
//  Feed.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 1/28/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import RealmSwift
import Freddy

class RGB: Object {
  dynamic var red: Int = 0
  dynamic var green: Int = 0
  dynamic var blue: Int = 0
  
  convenience init(red: Int, green: Int, blue: Int) {
    self.init()
    self.red = red
    self.green = green
    self.blue = blue
  }
}

class Feed: Object, JSONDecodable {
  dynamic var id: String = ""
  dynamic var title: String = ""
  dynamic var author: String = ""
  dynamic var imageUrl: String = ""
  var modificationDate: NSDate!
  var itemIds = [String]()
  
  let colors = List<RGB>()
  
  let items = LinkingObjects(fromType: Item.self, property: "feed")
  
  var lastSyncedTime: NSDate {
    get{
      var date = NSDate.distantPast()
      for d in items.map ({ $0.modificationDate }) {
        // TODO: figure out why some modificationDates are nil
        guard let d = d else { continue }
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
    
    modificationDate = parseDate(try json.string("modification_time"))
   
    if let ids = try? json.array("items").map(String.init) {
      itemIds.appendContentsOf(ids)
    }
   
    let colors = try? json.array("image_colors").map { color in
      return try! RGB(red: color.int("red"), green: color.int("green"), blue: color.int("blue"))
    }
    
    if let colors = colors {
      self.colors.appendContentsOf(colors)
      print("OMGCOLORS")
      print(colors)
    }
  }
}

class Item: Object, JSONDecodable {
  enum State {
    case Played
    case Unplayed
    case InProgress(position: Double)
  }
  
  dynamic var id: String = ""
  dynamic var guid: String = ""
  dynamic var link: String = ""
  dynamic var title: String = ""
  dynamic var author: String = ""
  dynamic var summary: String = ""
  dynamic var desc: String = ""
  dynamic var duration: Int = 0
  dynamic var size: Int = 0
  dynamic var pubDate: NSDate?
  dynamic var audioURL: String = ""
  dynamic var imageURL: String = ""
  dynamic var feed: Feed?
  dynamic var playing: Bool = false
  dynamic var position: Double = 0
  dynamic var modificationDate: NSDate?
  dynamic var stateModificationTime: NSDate?
  
  override static func primaryKey() -> String? {
    return "id"
  }
  
  override static func indexedProperties() -> [String] {
    return ["stateModificationTime"]
  }
  
  var state: State {
    get {
      if playing {
        return position.isZero
          ? State.Unplayed
          : State.InProgress(position: position)
      }
      
      return .Played
    }
    set(newValue) {
      print(newValue)
      switch(newValue) {
      case .Unplayed:
        playing = true
        position = 0
      case .Played:
        playing = false
        position = 0
      case .InProgress(let pos) where pos.isFinite:
        // Only store the position if the value is finite and non NaN
        playing = true
        position = pos
      default:
        return
      }
      
      self.stateModificationTime = NSDate()
    }
  }
  
  convenience required init(json: JSON) throws {
    self.init()
   
    id = try json.string("id")
    guid = try json.string("guid")
    link = try json.string("link")
    title = try json.string("title")
    author = try json.string("author")
    summary = try json.string("summary")
    desc = try json.string("description")
    duration = try json.int("duration")
    size = try json.int("size")
    pubDate = parseDate(try json.string("publication_time"))
    audioURL = try json.string("url")
    imageURL = try json.string("image_url")
    modificationDate = parseDate(try json.string("modification_time"))
  }
}
