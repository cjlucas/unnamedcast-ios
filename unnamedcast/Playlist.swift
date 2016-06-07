//
//  Playlist.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 6/6/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

struct Playlist {
  var items = [PlayerItem]()
  
  var isEmpty: Bool {
    return items.isEmpty
  }
  
  var currentItem: PlayerItem? {
    return items.first
  }
  
  var queuedItems: [PlayerItem] {
    guard items.count > 1 else { return [] }
    return Array(items[1..<items.count])
  }
  
  var count: Int {
    return items.count
  }
  
  mutating func queueItem(item: PlayerItem) {
    items.append(item)
  }
  
  mutating func removeAll() {
    items.removeAll()
  }
  
  mutating func pop() -> PlayerItem? {
    guard !isEmpty else { return nil }
    return items.removeFirst()
  }
}