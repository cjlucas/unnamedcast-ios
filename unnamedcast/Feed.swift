//
//  Feed.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 1/28/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Foundation
import RealmSwift
import Freddy

class Feed: Object, JSONDecodable {
    dynamic var id: String = ""
    dynamic var title: String = ""
    dynamic var author: String = ""
    dynamic var imageUrl: String = ""
    let items = List<Item>()

    override static func primaryKey() -> String? {
        return "id"
    }
    
    convenience required init(json: JSON) throws {
        self.init()
        
        id = try json.string("id")
        title = try json.string("title")
        author = try json.string("author")
        imageUrl = try json.string("image_url")
        
        for item in try json.array("items") {
            items.append(try Item(json: item))
        }
    }
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
    
    var feed: Feed {
        return linkingObjects(Feed.self, forProperty: "items").first!
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
