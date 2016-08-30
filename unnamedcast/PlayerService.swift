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

private class Timer {
  enum State {
    case Started(expectedFireDate: NSDate)
    case Paused(timeRemaining: NSTimeInterval)
    case Invalidated
  }
  
  private let onTimerFired: () -> ()
  private var timer: NSTimer?
  private(set) var state: State
  
  var isValid: Bool {
    if case .Invalidated = state {
      return false
    }
    return true
  }
  
  init(duration: Int, onFire: () -> ()) {
    state = .Paused(timeRemaining: NSTimeInterval(duration))
    onTimerFired = onFire
  }
  
  deinit {
    invalidate()
  }
  
  func invalidate() {
    timer?.invalidate()
    state = .Invalidated
  }
  
  private func initTimer(ti: NSTimeInterval) {
    timer = NSTimer.scheduledTimerWithTimeInterval(ti,
                                                   target: self,
                                                   selector: #selector(timerDidFire),
                                                   userInfo: nil,
                                                   repeats: false)
    
    state = .Started(expectedFireDate: NSDate().dateByAddingTimeInterval(ti))
  }
  
  @objc func timerDidFire() {
    invalidate()
    onTimerFired()
  }
  
  func start() {
    if case .Paused(let timeRemaining) = state {
      initTimer(timeRemaining)
    }
  }
  
  func pause() {
    if case .Started(let expectedFireDate) = state {
      timer?.invalidate()
      state = .Paused(timeRemaining: expectedFireDate.timeIntervalSinceNow)
    }
  }
}

protocol PlayerEventHandler: class {
  func receivedPeriodicTimeUpdate(item: PlayerItem, time: Double)
  func itemDidBeginPlaying(item: PlayerItem)
  func itemDidFinishPlaying(item: PlayerItem, nextItem: PlayerItem?)
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

public class PlayerService: NSObject, PlayerController, NSCoding {
  lazy private(set) var player: AVPlayer = self.createPlayer()
  
  private(set) var playlist = Playlist()
  
  private let audioSession = AVAudioSession.sharedInstance()
  
  // TODO: GET COMMAND CENTER OUTTA HERE
  private let commandCenter = MPRemoteCommandCenter.sharedCommandCenter()
  private let eventHandlers = NSHashTable(options: .WeakMemory)
  var delegate: PlayerServiceDelegate?
  
  private var itemDidPlayNotificationToken: AnyObject?
  private var itemTimeJumpedNotificationToken: AnyObject?
  
  private var timeObserverToken: AnyObject?
  
  private var sleepTimer: Timer?
  
  var timerDuration: Int {
    get {
      guard let state = sleepTimer?.state else { return 0 }
      switch state {
      case .Started(let expectedFireDate):
        return Int(expectedFireDate.timeIntervalSinceNow)
      case .Paused(let timeRemaining):
        return Int(timeRemaining)
      case .Invalidated:
        return 0
      }
    }
    set(duration) {
      sleepTimer?.invalidate()
      if duration == 0 {
        return
      }
      
      sleepTimer = Timer(duration: duration) { [weak self] in
        self?.pause()
      }
      
      if isPlaying {
        sleepTimer?.start()
      }
    }
  }
  
  var currentItem: PlayerItem? {
    return playlist.currentItem
  }

  var queuedItems: [PlayerItem] {
    return playlist.queuedItems
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

  var isPlaying: Bool {
    return player.rate > 0 && playlist.count > 0 && player.error == nil
  }
  
  var isPaused: Bool {
    return player.rate == 0 && playlist.count > 0 && player.error == nil
  }

  var currentTime: Double {
    return player.currentTime().seconds
  }
  
  var position: Double {
    get {
      guard let item = player.currentItem else { return 0 }
      return currentTime / item.duration.seconds
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
      self.seekToTime(self.currentTime + Double(self.forwardSkipInterval))
      return .Success
    }
    
    cmd = commandCenter.skipBackwardCommand
    cmd.preferredIntervals = [backwardSkipInterval]
    cmd.addTargetWithHandler { handler in
      self.seekToTime(self.currentTime - Double(self.forwardSkipInterval))
      return .Success
    }
  }
  
  func createPlayer(item: PlayerItem? = nil) -> AVPlayer {
    if let token = timeObserverToken {
      self.player.removeTimeObserver(token)
    }
    
    var player: AVPlayer
    if let item = item?.avItem {
      player = AVPlayer(playerItem: item)
    } else {
      player = AVPlayer()
    }
    
    timeObserverToken = player.addPeriodicTimeObserverForInterval(
      CMTimeMakeWithSeconds(1.0, 1000),
      queue: dispatch_get_main_queue()) { [weak self] time in
        guard let item = self?.currentItem else { return }
        guard let handlers = self?.eventHandlers.allObjects else { return }
        
        for h in handlers {
          let h = h as! PlayerEventHandler
          h.receivedPeriodicTimeUpdate(item, time: time.seconds)
        }
    }
    
    return player
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
      guard let item = self.currentItem else { return }
      let time = self.player.currentTime().seconds
      for h in self.eventHandlers.allObjects {
        let h = h as! PlayerEventHandler
        h.receivedPeriodicTimeUpdate(item, time: time)
      }
    }
  }
  
  func play() {
    player.play()
    sleepTimer?.start()
  }
  
  func replaceCurrentItemWithItem(item: PlayerItem) {
    player.pause()
    player.replaceCurrentItemWithPlayerItem(nil)
    
    player = createPlayer(item)
    delegate?.backendPlayerDidChange(player)
    
    if !item.position.isZero {
      seekToTime(item.position)
    }
  }
  
  private func playNextItem() {
    guard let item = currentItem else { fatalError("playNextItem was called without current item") }
    
    replaceCurrentItemWithItem(item)
    play()
    
    for h in self.eventHandlers.allObjects {
      let h = h as! PlayerEventHandler
      h.itemDidBeginPlaying(item)
    }
   
    setNotificationForCurrentItem()
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
    sleepTimer?.pause()
  }

  func seekToTime(seconds: Double) {
    player.seekToTime(CMTimeMake(Int64(seconds), 1))
  }

  func registerForEvents(handler: PlayerEventHandler) {
    eventHandlers.addObject(handler)
  }
  
  // MARK: NSCoding
  
  required convenience public init?(coder d: NSCoder) {
    self.init()
    
    let decodedItems = d.decodeObjectForKey("items") as! [PlayerItem]
   
    for item in decodedItems {
      print("Queueing item", item)
      queueItem(item)
    }
  }
  
  public func encodeWithCoder(c: NSCoder) {
    playlist.currentItem?.position = currentTime
    c.encodeObject(playlist.items, forKey: "items")
  }
}
