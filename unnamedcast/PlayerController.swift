//
//  PlayerController.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 6/6/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

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