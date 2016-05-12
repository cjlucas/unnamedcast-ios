//
//  Array.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 5/11/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Freddy

extension Array where Element: JSONDecodable {
  public init(json: JSON) throws {
    self.init()
    for e in try json.array() {
      append(try Element(json: e))
    }
  }
}
