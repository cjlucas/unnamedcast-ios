//
//  PlayerItem.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 6/6/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Foundation
import MediaPlayer

class PlayerItem: NSObject, NSCoding {
  struct Metadata {
    let title: String
    let artist: String
    let albumTitle: String
    let duration: Double
  }
  
  var url: NSURL
  var id: String
  var position: Double
  // TODO: AVPlayerItemDelegate
  
  lazy var avItem: AVPlayerItem = {
    return AVPlayerItem(URL: self.url)
  }()
  
  init(id: String, url: NSURL, position: Double = 0) {
    self.id = id
    self.url = url
    self.position = position
  }
  
  func hasVideo() -> Bool {
    return avItem.tracks
      .filter { $0.assetTrack.mediaType == AVMediaTypeVideo }
      .count > 0
  }
  
  // MARK: NSCoding
  
  required init?(coder d: NSCoder) {
    url = d.decodeObjectForKey("url") as! NSURL
    id = d.decodeObjectForKey("id") as! String
    position = d.decodeDoubleForKey("position")
  }
  
  func encodeWithCoder(c: NSCoder) {
    c.encodeObject(url, forKey: "url")
    c.encodeObject(id, forKey: "id")
    c.encodeDouble(position, forKey: "position")
  }
}
