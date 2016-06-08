//
//  MiniPlayerViewController.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 6/6/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import UIKit

class MiniPlayerViewModel: PlayerEventHandler {
  let db = try! DB()
 
  var player: PlayerController
  weak var progressView: ProgressView?
  weak var itemLabel: UILabel?
  
  var currentItem: Item? {
    guard let item = player.currentItem else { return nil }
    return db.itemWithID(item.id)
  }
  
  var currentTime: Double = 0 {
    didSet {
      if let duration = currentItem?.duration where currentTime.isFinite {
        progressView?.progress = Float(currentTime) / Float(duration)
      } else {
        progressView?.progress = 0
      }
    }
  }
  
  var currentPlayerItem: PlayerItem? {
    didSet {
      print("HERE100")
      guard let playerItem = currentPlayerItem,
        item = db.itemWithID(playerItem.id) else { return }
      print("HERE200", self.itemLabel)
      itemLabel?.text = item.title
    }
  }
  
  init(player: PlayerController, progressView: ProgressView, itemLabel: UILabel) {
    self.player = player
    self.progressView = progressView
    self.itemLabel = itemLabel
    
    print("in view model init", player.currentItem, player.currentTime)
   
    self.currentTime = player.currentTime
    self.currentPlayerItem = player.currentItem
  }
  
  func receivedPeriodicTimeUpdate(curTime: Double) {
    currentTime = curTime
  }
  
  func itemDidBeginPlaying(item: PlayerItem) {
    currentPlayerItem = item
  }
  
  func itemDidFinishPlaying(item: PlayerItem, nextItem: PlayerItem?) {
    currentTime = 0
    currentPlayerItem = nextItem
  }
}

class MiniPlayerViewController: UIViewController {
  // Injected properties
  var player: PlayerController!
  
  @IBOutlet weak var progressView: ProgressView!
  @IBOutlet weak var itemLabel: UILabel!
  
  lazy var viewModel: MiniPlayerViewModel = {
    return MiniPlayerViewModel(player: self.player,
                               progressView: self.progressView,
                               itemLabel: self.itemLabel)
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    player.registerForEvents(viewModel)
  }
  
  @IBAction func playPauseTogglePressed(sender: AnyObject) {
    player.isPlaying ? player.pause() : player.play()
  }
}
