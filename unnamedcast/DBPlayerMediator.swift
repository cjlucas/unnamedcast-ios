//
//  DBPlayerMediator.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 6/7/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

class DBPlayerMediator: PlayerEventHandler {
  private let db: DB
  
  init(db: DB) {
    self.db = db
  }
  
  func itemForPlayerItem(item: PlayerItem) -> Item? {
    return db.itemWithID(item.id)
  }
  
  func updateItemState(item: Item, state: Item.State) {
    try! db.write {
      item.state = state
    }
  }
  
  func itemDidBeginPlaying(playerItem: PlayerItem) {
    guard let item = itemForPlayerItem(playerItem) else {
      fatalError("no item for given player item, this should never happen")
    }
    updateItemState(item, state: .InProgress(position: 0))
  }
  
  func itemDidFinishPlaying(item: PlayerItem, nextItem: PlayerItem?) {
    print("itemDidFinishPlaying", item)
    guard let item = itemForPlayerItem(item) else {
      fatalError("no item for given player item, this should never happen")
    }
    updateItemState(item, state: .Played)
  }
  
  func receivedPeriodicTimeUpdate(item: PlayerItem, time: Double) {
    print("receivedPeriodicTimeUpdate", item)
    guard let item = itemForPlayerItem(item) else {
      fatalError("no item for given player item, this should never happen")
    }

    let time = time.isFinite ? time : 0
    
    // HACK: Considered played if < 1 second remaining
    // This is due to a bug (somewhere) that causes receivedPeriodicTimeUpdate
    // to be called after itemDidFinishPlaying on the same item.
    // Its probably an issue in AudioService
    if Double(item.duration) - time < 0 /* 1 */ {
      updateItemState(item, state: .Played)
      return
    }
    
    let position = time / Double(item.duration)
    updateItemState(item, state: .InProgress(position: position))
  }
}
