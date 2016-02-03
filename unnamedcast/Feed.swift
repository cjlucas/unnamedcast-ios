//
//  Feed.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 1/28/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Foundation
import RealmSwift
import SwiftyJSON

class Feed: Object {
    dynamic var id: String = ""
    dynamic var title: String = ""
    dynamic var author: String = ""
    dynamic var imageUrl: String = ""
    let items = List<Item>()

    override static func primaryKey() -> String? {
        return "id"
    }

    convenience init(json: JSON) {
        self.init()

        id = json["id"].stringValue
        title = json["title"].stringValue
        author = json["author"].stringValue
        imageUrl = json["image_url"].stringValue

        for (_, item):(String, JSON) in json["items"] {
            items.append(Item(json: item))
        }
    }
}



class Item: Object {
    dynamic var guid: String = ""
    dynamic var link: String = ""
    dynamic var title: String = ""
    dynamic var author: String = ""
    dynamic var desc: String = ""
    dynamic var duration: Int = 0
    dynamic var size: Int = 0
    dynamic var pubDate: String = ""
    dynamic var audioUrl: String = ""
    dynamic var imageUrl: String = ""
    
    var feed: Feed {
        return linkingObjects(Feed.self, forProperty: "items").first!
    }

    override static func primaryKey() -> String? {
        return "guid"
    }

    convenience init(json: JSON) {
        self.init()

        guid = json["guid"].stringValue
        link = json["link"].stringValue
        title = json["title"].stringValue
        author = json["author"].stringValue
        desc = json["description"].stringValue
        duration = json["duration"].intValue
        size = json["size"].intValue
        pubDate = json["publication_time"].stringValue
        audioUrl = json["url"].stringValue
        imageUrl = json["image_url"].stringValue
    }
}
