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

protocol PlayerItemProtocol {
    func receivedItemNotification(item: PlayerItem, notification: String, userInfo: [NSObject: AnyObject]?)
}

class PlayerItem {
    var url: String!
    var link: String!
    var title: String!
    var subtitle: String!
    var description: String!
    var feedTitle: String!
    var duration: Int!
    // TODO: delegation
    
    lazy var avItem: AVPlayerItem = {
        return AVPlayerItem(URL: NSURL(string: self.url)!)
    }()
    
    init(_ item: Item) {
        self.url = item.audioUrl
        self.title = item.title
        self.link = item.link
        self.subtitle = ""
        self.description = ""
        self.duration = item.duration
        
        self.feedTitle = item.feed.title
    }
}

protocol PlayerEventHandler: class {
    func itemDidFinishPlaying(item: PlayerItem, nextItem: PlayerItem?)
}

class Player {
    static let sharedPlayer = Player()
    
    let player = AVPlayer()
    
    private let audioSession = AVAudioSession.sharedInstance()
    private let infoCenter = MPNowPlayingInfoCenter.defaultCenter()
    private let commandCenter = MPRemoteCommandCenter.sharedCommandCenter()
   
    // Array of all items, items.first is always the currently playing item
    private var items = [PlayerItem]()
    
    weak var delegate: PlayerEventHandler?
    
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
    
    var position: Float {
        get {
            let pos = currentTime().seconds
            return Float(pos / (player.currentItem?.duration.seconds)!)
        }
    }
    
    init() {
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
            
            self.updateNowPlayingInfo([
                MPNowPlayingInfoPropertyElapsedPlaybackTime: self.currentTime().seconds
            ])
            
            return .Success
        }
        
        cmd = commandCenter.skipBackwardCommand
        cmd.preferredIntervals = [backwardSkipInterval]
        cmd.addTargetWithHandler { handler in
            let newTime = CMTimeSubtract(self.currentTime(), CMTimeMake(Int64(self.backwardSkipInterval), 1))
            self.seekToTime(newTime)
            print(self.currentTime())
            
            self.updateNowPlayingInfo([
                MPNowPlayingInfoPropertyElapsedPlaybackTime: self.currentTime().seconds
            ])
            
            return .Success
        }
    }
    
    private func setNotificationForCurrentItem() {
        guard let item = items.first else { fatalError() }
        
        let nc = NSNotificationCenter.defaultCenter()
        nc.addObserverForName(AVPlayerItemDidPlayToEndTimeNotification, object: item.avItem, queue: NSOperationQueue.mainQueue()) { notification in
            let item = self.items.removeFirst()
            let next = self.items.first
            print("Finished playing \(item), next is \(next)")
            
            if next != nil {
                self.playNextItem()
            }

            self.delegate?.itemDidFinishPlaying(item, nextItem: next)
        }
    }
    
    func isPlaying() -> Bool {
        return player.rate > 0 && player.error == nil
    }
    
    func play() {
        player.play()
        print(player.currentItem)
    }
    
    func currentItem() -> PlayerItem? {
        return items.first
    }
    
    func queuedItems() -> [PlayerItem] {
        guard items.count > 1 else { return [] }
        return Array(items[1..<items.count])
    }
    
    func playItem(item: PlayerItem) {
        items.removeAll()
        items.append(item)
        playNextItem()
    }
    
    func playNextItem() {
        guard let item = items.first else { fatalError() }

        player.replaceCurrentItemWithPlayerItem(item.avItem)
        infoCenter.nowPlayingInfo = [
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyPlaybackDuration: item.duration
        ]
        play()
        setNotificationForCurrentItem()
    }
 
    // queueItem purposfully does not begin playing a track if it's
    func queueItem(item: PlayerItem) {
        items.append(item)
    }
    
    func pause() {
        player.pause()
    }
    
    func seekToTime(time: CMTime) {
        player.seekToTime(time)
    }
    
    // pos is a float between 0 and 1
    func seekToPos(pos: Double) {
        if let curItem = player.currentItem {
            let time = pos * curItem.duration.seconds
            seekToTime(CMTimeMakeWithSeconds(time, 1))
        }
    }
    
    func currentTime() -> CMTime {
        return player.currentTime()
    }
    
    private func updateNowPlayingInfo(info: [String: AnyObject]) {
        var oldInfo = infoCenter.nowPlayingInfo!
        for (k,v) in info {
            oldInfo[k] = v
        }
        
        infoCenter.nowPlayingInfo = oldInfo
    }
}