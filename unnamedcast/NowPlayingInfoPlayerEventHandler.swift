//
//  NowPlayingInfoPlayerEventHandler.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 6/8/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Foundation
import MediaPlayer
import SDWebImage

class NowPlayingInfoPlayerEventHandler: PlayerEventHandler {
  let db = try! DB()
  let infoCenter = MPNowPlayingInfoCenter.defaultCenter()
  let imageManager = SDWebImageManager.sharedManager()
  
  private var fetchImageOperation: SDWebImageOperation?
  
  private func itemForPlayerItem(item: PlayerItem) -> Item? {
    return db.itemWithID(item.id)
  }
  
  private func updateInfoCenter(info: [String: AnyObject], merge: Bool = true) {
    var newInfo = merge
      ? infoCenter.nowPlayingInfo ?? [:]
      : [:]
    
    for (k, v) in info {
      newInfo[k] = v
    }
    
    infoCenter.nowPlayingInfo = newInfo
  }
  
  private func updateInfoCenterWithItem(playerItem: PlayerItem) {
    guard let item = itemForPlayerItem(playerItem) else { return }
    guard let feed = item.feed else { fatalError("item.feed is nil") }
    
    updateInfoCenter([
      MPMediaItemPropertyTitle:  item.title,
      MPMediaItemPropertyArtist:  feed.author,
      MPMediaItemPropertyAlbumTitle:  feed.title,
      MPMediaItemPropertyPlaybackDuration:  item.duration,
    ], merge: false)
    
    if let imageURL = item.feed?.imageUrl,
      let url = NSURL(string: imageURL) {
      fetchImageOperation?.cancel()
      
      fetchImageOperation = imageManager
        .downloadImageWithURL(url, options: .LowPriority, progress: nil) { img, _, _, _, _ in
          guard let img = img else { return }
          dispatch_async(dispatch_get_main_queue()) {
            self.updateInfoCenter([
              MPMediaItemPropertyArtwork: MPMediaItemArtwork(image: img)
            ])
          }
      }
    }
  }
  
  func itemDidBeginPlaying(item: PlayerItem) {
    updateInfoCenterWithItem(item)
  }
  
  func itemDidFinishPlaying(item: PlayerItem, nextItem: PlayerItem?) {
    if let item = nextItem {
      updateInfoCenterWithItem(item)
    }
  }
  
  func receivedPeriodicTimeUpdate(item: PlayerItem, time: Double) {
    updateInfoCenter([MPNowPlayingInfoPropertyElapsedPlaybackTime: time])
  }
}