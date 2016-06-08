//
//  DBPlayerMediator.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 6/7/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

class DBPlayerMediator: PlayerEventHandler {
  var db: DB
  var player: PlayerController
  
  init(db: DB, player: PlayerController) {
    self.db = db
    self.player = player
    self.player.registerForEvents(self)
  }
  
  func itemForPlayerItem(item: PlayerItem) -> Item? {
    return db.itemWithID(item.id)
  }
  
  func updateItemState(playerItem: PlayerItem, state: Item.State) {
    guard let item = itemForPlayerItem(playerItem) else { return }
    
    try! db.write {
      item.state = state
    }
  }
  
  func itemDidBeginPlaying(item: PlayerItem) {
    updateItemState(item, state: .InProgress(position: 0))
  }
  
  func itemDidFinishPlaying(item: PlayerItem, nextItem: PlayerItem?) {
    updateItemState(item, state: .Played)
  }
  
  func receivedPeriodicTimeUpdate(curTime: Double) {
    guard let item = player.currentItem else { return }
    
    let position = player.currentTime.isFinite
      ? player.currentTime / Double(itemForPlayerItem(item)?.duration ?? 0)
      : 0
    
    updateItemState(item, state: .InProgress(position: position))
  }
}