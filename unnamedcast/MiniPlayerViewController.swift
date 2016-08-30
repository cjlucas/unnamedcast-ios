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
  
  init(player: PlayerController, progressView: ProgressView, itemLabel: UILabel) {
    self.player = player
    self.progressView = progressView
    self.itemLabel = itemLabel
    
    update()
  }
  
  func update() {
    guard let item = currentItem else { return }
    
    itemLabel?.text = item.title
    
    if player.currentTime.isFinite {
      progressView?.progress = Float(player.currentTime) / Float(item.duration)
    }
  }
  
  func receivedPeriodicTimeUpdate(item: PlayerItem, time: Double) {
    update()
  }
  
  func itemDidBeginPlaying(item: PlayerItem) {
    update()
  }
  
  func itemDidFinishPlaying(item: PlayerItem, nextItem: PlayerItem?) {
    update()
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
