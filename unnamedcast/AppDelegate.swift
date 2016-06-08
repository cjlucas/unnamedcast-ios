//
//  AppDelegate.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 1/28/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import AVFoundation
import UIKit
import Alamofire
import PromiseKit
import RealmSwift
import Swinject

typealias LayerChangeHandler = (AVPlayerLayer) -> ()
protocol AVPlayerLayerProvider {
  func register(identifier: String, layerChangeHandler: LayerChangeHandler)
  func unregister(identifier: String)
}

private class PlayerLayerProvider: AVPlayerLayerProvider {
  private var registrars = [String:LayerChangeHandler]()
  
  var playerLayer: AVPlayerLayer {
    didSet {
      print("notifiying registrars")
      for (_, handler) in registrars {
        handler(playerLayer)
      }
    }
  }
  
  init(playerLayer: AVPlayerLayer) {
    self.playerLayer = playerLayer
  }
  
  func register(identifier: String, layerChangeHandler: LayerChangeHandler) {
    registrars[identifier] = layerChangeHandler
    layerChangeHandler(playerLayer)
  }
  
  func unregister(identifier: String) {
    registrars.removeValueForKey(identifier)
  }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, PlayerDataSource, PlayerServiceDelegate {
  var window: UIWindow?
  
  let db = try! DB()
  let engine = SyncEngine()
  
  var player: PlayerService!
  private var layerProvider: PlayerLayerProvider!
  
  var dbPlayerMediator: DBPlayerMediator!
  
  func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    // Player deserialization
    let ud = NSUserDefaults.standardUserDefaults()
    if let data = ud.objectForKey("player") as? NSData {
      player = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! PlayerService
    } else {
      player = PlayerService()
    }
    
    ud.removeObjectForKey("player")
    player.dataSource = self
    player.delegate = self
    
    dbPlayerMediator = DBPlayerMediator(db: self.db,
                                        player: PlayerServiceProxy(player: self.player))
    
    
    let start = NSDate()
    
    // Dependency injection for player service
    let container = Container()
    let playerProxy = PlayerServiceProxy(player: player)
    layerProvider = PlayerLayerProvider(playerLayer: AVPlayerLayer(player: player.player))
    
    container.registerForStoryboard(StandardPlayerContentViewController.self, name: nil) { r, c in
      c.player = playerProxy
      c.layerProvider = self.layerProvider
    }
    
    container.registerForStoryboard(FullscreenPlayerContentViewController.self, name: nil) { r, c in
      c.player = playerProxy
      c.layerProvider = self.layerProvider
    }

    container.registerForStoryboard(SingleFeedViewController.self, name: nil) { r, c in
      c.player = playerProxy
    }

    container.registerForStoryboard(MiniPlayerViewController.self, name: nil) { r, c in
      c.player = playerProxy
    }

    container.registerForStoryboard(AppContainerViewController.self, name: nil) { r, c in
      c.player = playerProxy
    }
    
    print(-start.timeIntervalSinceNow * 1000)
    
    
    application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
    application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: .Alert, categories: nil))
    
    let sb = SwinjectStoryboard.create(name: "Main", bundle: nil, container: container)
    
    if ud.stringForKey("user_id") == nil {
      self.window?.rootViewController = sb.instantiateViewControllerWithIdentifier("login")
      self.window?.makeKeyAndVisible()
    } else {
      self.window?.rootViewController = sb.instantiateInitialViewController()
      print("Updating user feeds")
      // TODO: do some profiling with this method. it takes ~30 milliseconds to execute
      // Also, syncing here is unnecessary since we use performFetchWithCompletionHandler
      engine.sync().then {
        print("Updated user feeds")
      }
    }
    
    print(-start.timeIntervalSinceNow * 1000)
    
    return true
  }
  
  func applicationWillTerminate(application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    let data = NSKeyedArchiver.archivedDataWithRootObject(player)
    NSUserDefaults.standardUserDefaults().setObject(data, forKey: "player")
    print("App will terminate. Archived", data.length, "worth of data")
  }

  func application(application: UIApplication, performFetchWithCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
    firstly {
      return engine.sync()
    }.always {
      // TODO: determine whether there was new data or not
      completionHandler(.NewData)
    }.error { err -> () in
      completionHandler(.Failed)
    }
  }
  
  // MARK: PlayerDataSource
  func metadataForItem(item: PlayerItem) -> PlayerItem.Metadata? {
    let db = try! DB()
    if let item = db.itemWithID(item.id) {
      return PlayerItem.Metadata(title: item.title,
                                 artist: item.feed!.author,
                                 albumTitle: item.feed!.title,
                                 duration: Double(item.duration))
    }
    return nil
  }
  
  // MARK: PlayerServiceDelegate
  
  func backendPlayerDidChange(player: AVPlayer) {
    print("backendPlayerDidChange")
    layerProvider.playerLayer = AVPlayerLayer(player: player)
  }
}
