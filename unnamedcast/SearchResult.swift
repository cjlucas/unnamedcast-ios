//
//  File.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 5/11/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Freddy

struct SearchResult: JSONDecodable {
  var id: String
  var title: String
  
  init(json: JSON) throws {
    id = try json.string("id")
    title = try json.string("title")
  }
}
  
