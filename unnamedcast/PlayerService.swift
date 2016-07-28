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
  private var state: State {
    didSet {
//      print("Sleep timer state did change \(state)")
    }
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
  
  func timeRemaining() -> Int {
    switch state {
    case .Started(let expectedFireDate):
      return Int(expectedFireDate.timeIntervalSinceNow)
    case .Paused(let timeRemaining):
      return Int(timeRemaining)
    case .Invalidated:
      fatalError("timeRemaining called on invalidated timer")
    }
  }
}

protocol PlayerEventHandler: class {
  func receivedPeriodicTimeUpdate(curTime: Double)
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

public class PlayerService: NSObject, NSCoding {
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
        guard let handlers = self?.eventHandlers.allObjects else { return }
        
        for h in handlers {
          let h = h as! PlayerEventHandler
          h.receivedPeriodicTimeUpdate(time.seconds)
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
      let time = self.player.currentTime().seconds
      for h in self.eventHandlers.allObjects {
        let h = h as! PlayerEventHandler
        h.receivedPeriodicTimeUpdate(time)
      }
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
    sleepTimer?.start()
  }
  
  func replaceCurrentItemWithItem(item: PlayerItem) {
    player.pause()
    player.replaceCurrentItemWithPlayerItem(nil)
    
    player = createPlayer(item)
    delegate?.backendPlayerDidChange(player)
    
    let time = item.initialTime
    if time.isValid && !time.seconds.isZero {
      seekToTime(item.initialTime)
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

  // TODO: deprecate in favor of a Double alternative
  func seekToTime(time: CMTime) {
    player.seekToTime(time)
  }

  // TODO: deprecate in favor of a Double alternative
  func currentTime() -> CMTime {
    return player.currentTime()
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
    playlist.currentItem?.initialTime = currentTime()
    c.encodeObject(playlist.items, forKey: "items")
  }
  
  // MARK: Event Handlers
  
  func registerEventHandler(handler: PlayerEventHandler) {
    eventHandlers.addObject(handler)
  }
  
  // MARK: Sleep Timer
  
  func setTimer(duration: Int) {
    sleepTimer?.invalidate()
    sleepTimer = Timer(duration: duration) { [weak self] in
      self?.pause()
    }
    sleepTimer?.start()
  }
  
  func timeRemaining() -> Int {
    return sleepTimer?.timeRemaining() ?? 0
  }
  
  func timerDidFire() {
    pause()
  }
}
