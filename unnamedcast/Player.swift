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

protocol PlayerDataSource {
  func metadataForItem(item: PlayerItem) -> PlayerItem.Metadata?
}

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

protocol PlayerEventHandler: class {
  func itemDidFinishPlaying(item: PlayerItem, nextItem: PlayerItem?)
}

struct Playlist {
  private var items = [PlayerItem]()
  
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

class Player: NSObject, NSCoding {
  static var sharedPlayer = Player()
  
  let player = AVPlayer()
  private(set) var playlist = Playlist()
  
  internal var delegate: PlayerDataSource? = nil
  
  private let audioSession = AVAudioSession.sharedInstance()
  private let commandCenter = MPRemoteCommandCenter.sharedCommandCenter()
  private let eventHandlers = NSHashTable(options: .WeakMemory)
  
  private var itemDidPlayNotificationToken: AnyObject? = nil
  private var itemTimeJumpedNotificationToken: AnyObject? = nil
  
  var currentItem: PlayerItem? {
    return playlist.currentItem
  }
  
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
 
  var position: Double {
    get {
      guard let item = player.currentItem else { return 0 }
      return currentTime().seconds / item.duration.seconds
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
    guard let item = currentItem else { fatalError("item list is empty") }

    let nc = NSNotificationCenter.defaultCenter()
    
    for token in [itemDidPlayNotificationToken, itemTimeJumpedNotificationToken] {
      if let token = token { nc.removeObserver(token) }
    }
    
    itemDidPlayNotificationToken = nc.addObserverForName(AVPlayerItemDidPlayToEndTimeNotification,
                                                         object: item.avItem,
                                                         queue: NSOperationQueue.mainQueue()) { notification in
      guard let item = self.playlist.pop() else {
        fatalError("Received AVPlayerItemDidPlayToEndTimeNotification with empty playlist")
      }
                                                          
      let next = self.playlist.currentItem
      print("Finished playing \(item), next is \(next)")
      
      for handler in self.eventHandlers.allObjects {
        let handler = handler as! PlayerEventHandler
        handler.itemDidFinishPlaying(item, nextItem: next)
      }

      if next != nil {
        self.playNextItem()
      }
    }
    
    itemTimeJumpedNotificationToken = nc.addObserverForName(AVPlayerItemTimeJumpedNotification,
                                                            object: item.avItem,
                                                            queue: NSOperationQueue.mainQueue()) { notification in
      self.updateNowPlayingInfo([
        MPNowPlayingInfoPropertyElapsedPlaybackTime: self.currentTime().seconds
      ])
    }
  }
  
  func isPlaying() -> Bool {
    return player.rate > 0 && playlist.count > 0 && player.error == nil
  }
  
  func isPaused() -> Bool {
    return player.rate == 0 && playlist.count > 0 && player.error == nil
  }
  
  func play() {
    player.play()
  }
  
  func replaceCurrentItemWithItem(item: PlayerItem) {
    player.replaceCurrentItemWithPlayerItem(item.avItem)
    
    let time = item.initialTime
    if time.isValid && !time.seconds.isZero {
      seekToTime(item.initialTime)
    }
  }
  
  func playItem(item: PlayerItem) {
    playlist.removeAll()
    playlist.queueItem(item)
    playNextItem()
  }
  
  func playNextItem() {
    guard let item = currentItem else {
      print("playNextItem was called with no current item. This is probably a bug.")
      return
    }
   
    replaceCurrentItemWithItem(item)
    play()
    
    setNotificationForCurrentItem()
    updateNowPlayingInfo()
  }
  
  func queueItem(item: PlayerItem) {
    playlist.queueItem(item)
    
    if playlist.count == 1 {
      replaceCurrentItemWithItem(item)
    }
  }
  
  func pause() {
    player.pause()
  }

  // TODO: deprecate in favor of a Double alternative
  func seekToTime(time: CMTime) {
    player.seekToTime(time)
  }

  // pos is a float between 0 and 1
  func seekToPos(pos: Double) {
    guard let item = currentItem else { return }
    
    var time = pos * item.avItem.duration.seconds
    if let duration = delegate?.metadataForItem(item)?.duration {
      time = pos * Double(duration)
    }

    seekToTime(CMTimeMakeWithSeconds(time, 1000))
  }
 
  // TODO: deprecate in favor of a Double alternative
  func currentTime() -> CMTime {
    return player.currentTime()
  }
  
  private func updateNowPlayingInfo() {
    guard let item = currentItem else { return }
    
    var info: [String: AnyObject] = [
      MPMediaItemPropertyTitle: item.url
    ]
    
    if let data = delegate?.metadataForItem(item) {
      info[MPMediaItemPropertyTitle] = data.title
      info[MPMediaItemPropertyArtist] = data.artist
      info[MPMediaItemPropertyAlbumTitle] = data.albumTitle
      info[MPMediaItemPropertyPlaybackDuration] = data.duration
    }

    updateNowPlayingInfo(info)
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
    
    updateNowPlayingInfo()
  }
  
  func encodeWithCoder(c: NSCoder) {
    playlist.currentItem?.initialTime = currentTime()
    c.encodeObject(playlist.items, forKey: "items")
  }
  
  // MARK: Event Handlers
  
  func registerEventHandler(handler: PlayerEventHandler) {
    eventHandlers.addObject(handler)
  }
}
