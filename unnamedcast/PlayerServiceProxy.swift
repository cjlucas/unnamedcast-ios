//
//  PlayerServiceProxy.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 6/6/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import MediaPlayer

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
  
  var timerDuration: Int {
    get {
      return player.timerDuration
    }
    set(duration) {
      player.timerDuration = duration
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
    player.playItem(item)
  }
  
  func queueItem(item: PlayerItem) {
    player.queueItem(item)
  }
  
  func registerForEvents(handler: PlayerEventHandler) {
    player.registerEventHandler(handler)
  }
}