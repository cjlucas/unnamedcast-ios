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
class AppDelegate: UIResponder, UIApplicationDelegate, PlayerServiceDelegate {
  var window: UIWindow?
  
  let db = try! DB()
  let engine = SyncEngine()
  let userDefaults = NSUserDefaults.standardUserDefaults()
  
  lazy var player: PlayerService = {
    if let data = self.userDefaults.objectForKey("player") as? NSData {
      let player = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! PlayerService
      self.userDefaults.removeObjectForKey("player")
      return player
    }
    
    return PlayerService()
  }()
  
  private var layerProvider: PlayerLayerProvider!
 
  lazy var dbPlayerMediator: DBPlayerMediator = {
    return DBPlayerMediator(db: self.db)
  }()
  
  lazy var nowPlayingInfoHandler = NowPlayingInfoPlayerEventHandler()
  
  func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    
    // Override point for customization after application launch.
    // Sets background to a blank/empty image
    // Removes the line from the navbar
    UINavigationBar.appearance().setBackgroundImage(UIImage(), forBarMetrics: .Default)
    // Sets shadow (line below the bar) to a blank image
    UINavigationBar.appearance().shadowImage = UIImage()
//    // Sets the translucent background color
//    UINavigationBar.appearance().backgroundColor = UIColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
    // Set translucent. (Default value is already true, so this can be removed if desired.)
    UINavigationBar.appearance().translucent = false
    
    
    player.delegate = self
    
    player.registerForEvents(nowPlayingInfoHandler)
    player.registerForEvents(dbPlayerMediator)
    
    let start = NSDate()
    
    // Dependency injection for player service
    let container = Container()
    layerProvider = PlayerLayerProvider(playerLayer: AVPlayerLayer(player: player.player))
    
    container.registerForStoryboard(StandardPlayerContentViewController.self, name: nil) { r, c in
      c.player = self.player
      c.layerProvider = self.layerProvider
    }
    
    container.registerForStoryboard(FullscreenPlayerContentViewController.self, name: nil) { r, c in
      c.player = self.player
      c.layerProvider = self.layerProvider
    }

    container.registerForStoryboard(SingleFeedViewController.self, name: nil) { r, c in
      c.player = self.player
    }

    container.registerForStoryboard(MiniPlayerViewController.self, name: nil) { r, c in
      c.player = self.player
    }

    container.registerForStoryboard(AppContainerViewController.self, name: nil) { r, c in
      c.player = self.player
    }
    
    print(-start.timeIntervalSinceNow * 1000)
    
    
    application.setMinimumBackgroundFetchInterval(UIApplicationBackgroundFetchIntervalMinimum)
    application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: .Alert, categories: nil))
    
    let sb = SwinjectStoryboard.create(name: "Main", bundle: nil, container: container)
    if userDefaults.stringForKey("user_id") == nil {
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
  
  // MARK: PlayerServiceDelegate
  
  func backendPlayerDidChange(player: AVPlayer) {
    print("backendPlayerDidChange")
    layerProvider.playerLayer = AVPlayerLayer(player: player)
  }
}
