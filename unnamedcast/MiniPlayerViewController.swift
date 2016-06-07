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
      print("MADE IT HERE?!", progressView)
      progressView?.progress = Float(currentTime) / Float(currentItem?.duration ?? 0)
    }
  }
  
  var currentPlayerItem: PlayerItem? {
    didSet {
      guard let playerItem = currentPlayerItem,
        item = db.itemWithID(playerItem.id) else { return }
      itemLabel?.text = item.title
    }
  }
  
  init(player: PlayerController, progressView: ProgressView, itemLabel: UILabel) {
    self.player = player
    self.progressView = progressView
    self.itemLabel = itemLabel
    
    self.currentTime = player.currentTime
    self.currentPlayerItem = player.currentItem
  }
  
  func receivedPeriodicTimeUpdate(curTime: Double) {
    print("RECEIVED PERIODIC TIME")
    currentTime = curTime
  }
  
  func itemDidFinishPlaying(item: PlayerItem, nextItem: PlayerItem?) {
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
