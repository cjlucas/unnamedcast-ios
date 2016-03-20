//
//  Player.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 1/29/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer

class PlayerItem: NSObject, NSCoding {
  var url: String!
  var link: String!
  var title: String!
  var subtitle: String!
  var desc: String!
  var feedTitle: String!
  var duration: Int!
  var imageUrl: String!
  var author: String!
  var key: String!
  // TODO: delegation
  
  lazy var avItem: AVPlayerItem = {
    return AVPlayerItem(URL: NSURL(string: self.url)!)
  }()
  
  func hasVideo() -> Bool {
    return avItem.tracks
      .filter({$0.assetTrack.mediaType == AVMediaTypeVideo})
      .count > 0
  }
  
  init(_ item: Item) {
    url = item.audioURL
    title = item.title
    link = item.link
    subtitle = ""
    desc = ""
    duration = item.duration
    imageUrl = item.imageURL
    author = item.author
    key = item.key
    
    feedTitle = item.feed.title
  }
  
  // MARK: NSCoding
  
  required init?(coder d: NSCoder) {
    url = d.decodeObjectForKey("url") as! String
    link = d.decodeObjectForKey("link") as! String
    title = d.decodeObjectForKey("title") as! String
    subtitle = d.decodeObjectForKey("subtitle") as! String
    desc = d.decodeObjectForKey("description") as! String
    feedTitle = d.decodeObjectForKey("feed_title") as! String
    duration = d.decodeIntegerForKey("duration")
    imageUrl = d.decodeObjectForKey("image_url") as! String
    author = d.decodeObjectForKey("author") as! String
    feedTitle = d.decodeObjectForKey("feed_title") as! String
    key = d.decodeObjectForKey("key") as! String
  }
  
  func encodeWithCoder(c: NSCoder) {
    c.encodeObject(url, forKey: "url")
    c.encodeObject(link, forKey: "link")
    c.encodeObject(title, forKey: "title")
    c.encodeObject(subtitle, forKey: "subtitle")
    c.encodeObject(description, forKey: "description")
    c.encodeInteger(duration, forKey: "duration")
    c.encodeObject(imageUrl, forKey: "image_url")
    c.encodeObject(author, forKey: "author")
    c.encodeObject(feedTitle, forKey: "feed_title")
    c.encodeObject(key, forKey: "key")
  }
}

protocol PlayerEventHandler: class {
  func itemDidFinishPlaying(item: PlayerItem, nextItem: PlayerItem?)
}

class Player: NSObject, NSCoding {
  static var sharedPlayer = Player()
  
  let player = AVPlayer()
  
  private let audioSession = AVAudioSession.sharedInstance()
  private let commandCenter = MPRemoteCommandCenter.sharedCommandCenter()
  private let eventHandlers = NSHashTable(options: .WeakMemory)
  
  // Array of all items, items.first is always the currently playing item
  private var items = [PlayerItem]()
  
  var forwardSkipInterval: Int = 30 {
    didSet {
      commandCenter.skipForwardCommand.preferredIntervals = [forwardSkipInterval]
    }
  }
  
  var backwardSkipInterval: Int = 30 {
    didSet {
      commandCenter.skipForwardCommand.preferredIntervals = [backwardSkipInterval]
    }
  }
  
  var volume: Float {
    get {
      return player.volume
    }
    
    set(v) {
      player.volume = v
    }
  }
  
  var muted: Bool {
    get {
      return player.muted
    }
  }
  
  var rate: Float {
    get {
      return player.rate
    }
    
    set(newRate) {
      player.rate = rate
    }
  }
  
  var position: Float {
    get {
      let pos = currentTime().seconds
      return Float(pos / (player.currentItem?.duration.seconds)!)
    }
  }
  
  override init() {
    super.init()
    
    try! audioSession.setCategory(AVAudioSessionCategoryPlayback)
    
    commandCenter.playCommand.addTargetWithHandler { handler in
      self.play()
      return .Success
    }
    
    commandCenter.pauseCommand.addTargetWithHandler { handler in
      self.pause()
      return .Success
    }
    
    var cmd = commandCenter.skipForwardCommand
    cmd.preferredIntervals = [forwardSkipInterval]
    cmd.addTargetWithHandler { handler in
      let newTime = CMTimeAdd(self.currentTime(), CMTimeMake(Int64(self.forwardSkipInterval), 1))
      self.seekToTime(newTime)
      return .Success
    }
    
    cmd = commandCenter.skipBackwardCommand
    cmd.preferredIntervals = [backwardSkipInterval]
    cmd.addTargetWithHandler { handler in
      let newTime = CMTimeSubtract(self.currentTime(), CMTimeMake(Int64(self.backwardSkipInterval), 1))
      self.seekToTime(newTime)
      return .Success
    }
  }
  
  private func setNotificationForCurrentItem() {
    guard let item = items.first else { fatalError() }
    
    let nc = NSNotificationCenter.defaultCenter()
    nc.addObserverForName(AVPlayerItemDidPlayToEndTimeNotification, object: item.avItem, queue: NSOperationQueue.mainQueue()) { notification in
      let item = self.items.removeFirst()
      let next = self.items.first
      print("Finished playing \(item), next is \(next)")
      
      if next != nil {
        self.playNextItem()
      }
      
      for handler in self.eventHandlers.allObjects {
        let handler = handler as! PlayerEventHandler
        handler.itemDidFinishPlaying(item, nextItem: next)
      }
    }
    
    nc.addObserverForName(AVPlayerItemTimeJumpedNotification,
      object: item.avItem,
      queue: NSOperationQueue.mainQueue()) { notification in
        self.updateNowPlayingInfo([
          MPNowPlayingInfoPropertyElapsedPlaybackTime: self.currentTime().seconds
        ])
    }
  }
  
  func isPlaying() -> Bool {
    return player.rate > 0 && items.count > 0 && player.error == nil
  }
  
  func isPaused() -> Bool {
    return player.rate == 0 && items.count > 0 && player.error == nil
  }
  
  func play() {
    player.play()
    print(player.currentItem)
  }
  
  func currentItem() -> PlayerItem? {
    return items.first
  }
  
  func queuedItems() -> [PlayerItem] {
    guard items.count > 1 else { return [] }
    return Array(items[1..<items.count])
  }
  
  func playItem(item: PlayerItem) {
    items.removeAll()
    items.append(item)
    playNextItem()
  }
  
  func playNextItem() {
    guard let item = items.first else { fatalError() }
    
    player.replaceCurrentItemWithPlayerItem(item.avItem)
    play()
    setNotificationForCurrentItem()
    setNowPlayingInfoForCurrentItem()
  }
  
  // queueItem purposfully does not begin playing a track if it's
  func queueItem(item: PlayerItem) {
    items.append(item)
    if items.count == 1 {
      player.replaceCurrentItemWithPlayerItem(item.avItem)
    }
  }
  
  func pause() {
    player.pause()
  }
  
  func seekToTime(time: CMTime) {
    player.seekToTime(time)
  }
  
  // pos is a float between 0 and 1
  func seekToPos(pos: Double) {
    if let curItem = currentItem() {
      let time = pos * Double(curItem.duration)
      seekToTime(CMTimeMakeWithSeconds(time, 1))
    }
  }
  
  func currentTime() -> CMTime {
    return player.currentTime()
  }
  
  private func setNowPlayingInfoForCurrentItem() {
    guard let item = items.first else { return }
    updateNowPlayingInfo([
      MPMediaItemPropertyTitle: item.title,
      MPMediaItemPropertyPlaybackDuration: item.duration
    ])
  }
  
  private func updateNowPlayingInfo(info: [String: AnyObject]) {
    dispatch_async(dispatch_get_main_queue()) {
      let infoCenter = MPNowPlayingInfoCenter.defaultCenter()
      
      if var oldInfo = infoCenter.nowPlayingInfo {
        for (k,v) in info {
          oldInfo[k] = v
        }
        
        infoCenter.nowPlayingInfo = oldInfo
      } else {
        infoCenter.nowPlayingInfo = info
      }
    }
  }
  
  // MARK: NSCoding
  
  required convenience init?(coder d: NSCoder) {
    self.init()
    
    let decodedItems = d.decodeObjectForKey("items") as! [PlayerItem]
    
    for item in decodedItems {
      print("Queueing item", item)
      queueItem(item)
    }
    
    let itemPos = d.decodeCMTimeForKey("item_pos")
    player.seekToTime(itemPos)
    setNowPlayingInfoForCurrentItem()
  }
  
  func encodeWithCoder(c: NSCoder) {
    c.encodeObject(items, forKey: "items")
    c.encodeCMTime(currentTime(), forKey: "item_pos")
  }
  
  // MARK: Event Handlers
  
  func registerEventHandler(handler: PlayerEventHandler) {
    eventHandlers.addObject(handler)
  }
}