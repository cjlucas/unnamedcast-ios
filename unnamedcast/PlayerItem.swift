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
  
  var url: NSURL!
  var id: String!
  var initialTime: CMTime!
  // TODO: AVPlayerItemDelegate
  
  lazy var avItem: AVPlayerItem = {
    return AVPlayerItem(URL: self.url)
  }()
  
  init(id: String, url: NSURL, position: Double = 0) {
    self.id = id
    self.url = url
    self.initialTime = CMTimeMakeWithSeconds(position, 1000)
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
    initialTime = d.decodeCMTimeForKey("initialTime")
  }
  
  func encodeWithCoder(c: NSCoder) {
    c.encodeObject(url, forKey: "url")
    c.encodeObject(id, forKey: "id")
    c.encodeCMTime(initialTime, forKey: "initialTime")
  }
}
