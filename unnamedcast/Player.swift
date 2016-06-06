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

protocol PlayerController {
  // Volume is from 0.0-1.0
  var volume: Float { get set }
  
  // In seconds
  var currentTime: Double { get }
  
  var currentItem: PlayerItem? { get }
  var queuedItems: [PlayerItem] { get }
  
  var isPlaying: Bool { get }
  var isPaused: Bool { get }
 
  // Controls
  func seekToTime(seconds: Double)
  func play()
  func pause()
  
  // Playlist management
  func playItem(item: PlayerItem)
  func queueItem(item: PlayerItem)
  
  func registerForEvents(handler: PlayerEventHandler)
}

public var sharedPlayerService = PlayerService()

struct PlayerServiceProxy: PlayerController {
  var player: PlayerService
  
  var volume: Float {
    get {
      return player.volume
    }
    set(val) {
      player.volume = val
    }
  }
  
  var currentTime: Double {
    return player.currentTime().seconds
  }
  
  var currentItem: PlayerItem? {
    return player.currentItem
  }
  
  var queuedItems: [PlayerItem] {
    return player.playlist.queuedItems
  }
  
  var isPlaying: Bool {
    return player.isPlaying()
  }
  
  var isPaused: Bool {
    return player.isPaused()
  }
  
  func seekToTime(seconds: Double) {
    player.seekToTime(CMTimeMakeWithSeconds(seconds, 1000))
  }
  
  func play() {
    player.play()
  }
  
  func pause() {
    player.pause()
  }
  
  func playItem(item: PlayerItem) {
    print("playItem (in \(player))")
    player.playItem(item)
    print("played item")
  }
  
  func queueItem(item: PlayerItem) {
    player.queueItem(item)
  }
  
  func registerForEvents(handler: PlayerEventHandler) {
    player.registerEventHandler(handler)
  }
}

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
    return AVPlayerItem(asset: self.asset)
  }()
  
  private lazy var asset: AVAsset = {
    return AVURLAsset(URL: self.url)
  }()

  init(id: String, url: NSURL, position: Double = 0) {
    self.id = id
    self.url = url
    self.initialTime = CMTimeMakeWithSeconds(position, 1000)
  }
  
  func hasVideo() -> Bool {
    return asset.tracks
      .filter { $0.mediaType == AVMediaTypeVideo }
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

// This is a necessary workaround thanks to (probably) bugs in AVPlayer.
// When attempting to play my troublesome vidfeeder videos that can take
// a long time to respond, the player will timeout eventually and fail
// with error "Cannot Complete Action". If this error occurs, any attempt
// to play another item will fail because the error will not clear.
//
// Multiple workarounds were attempted, including implementing the AVAsset
// loader delegate, but the same issues were seen in that case.
protocol PlayerServiceDelegate {
  func backendPlayerDidChange(player: AVPlayer)
}

public class PlayerService: NSObject, NSCoding {
  private(set) var player = AVPlayer()
  private(set) var playlist = Playlist()
  
  internal var dataSource: PlayerDataSource? = nil
  
  private let audioSession = AVAudioSession.sharedInstance()
  private let commandCenter = MPRemoteCommandCenter.sharedCommandCenter()
  private let eventHandlers = NSHashTable(options: .WeakMemory)
  var delegate: PlayerServiceDelegate?
  
  private var itemDidPlayNotificationToken: AnyObject?
  private var itemTimeJumpedNotificationToken: AnyObject?
  
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
    player.pause()
    player.replaceCurrentItemWithPlayerItem(nil)
    
    player = AVPlayer(playerItem: item.avItem)
    delegate?.backendPlayerDidChange(player)
    
    let time = item.initialTime
    if time.isValid && !time.seconds.isZero {
      seekToTime(item.initialTime)
    }
  }
  
  private func playNextItem() {
    guard let item = currentItem else {
      print("playNextItem was called with no current item. This is probably a bug.")
      return
    }
    print("thread: \(NSThread.isMainThread())")
    replaceCurrentItemWithItem(item)
//    play()
    
    setNotificationForCurrentItem()
    updateNowPlayingInfo()
  }
  
  func playItem(item: PlayerItem) {
    if let item = player.currentItem {
      item.asset.cancelLoading()
    }
    
    playlist.removeAll()
    playlist.queueItem(item)
    playNextItem()
    
    print("end of playItem")
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
    if let duration = dataSource?.metadataForItem(item)?.duration {
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
    
    if let data = dataSource?.metadataForItem(item) {
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
  
  required convenience public init?(coder d: NSCoder) {
    self.init()
    
    let decodedItems = d.decodeObjectForKey("items") as! [PlayerItem]
   
    for item in decodedItems {
      print("Queueing item", item)
      queueItem(item)
    }
    
    updateNowPlayingInfo()
  }
  
  public func encodeWithCoder(c: NSCoder) {
    playlist.currentItem?.initialTime = currentTime()
    c.encodeObject(playlist.items, forKey: "items")
  }
  
  // MARK: Event Handlers
  
  func registerEventHandler(handler: PlayerEventHandler) {
    eventHandlers.addObject(handler)
  }
}
