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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  
  let db = try! DB()
  let engine = SyncEngine()
  
  var player: PlayerService!
  
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
    
    let start = NSDate()
    
    // Dependency injection for player service
    let container = Container()
    let playerProxy = PlayerServiceProxy(player: player)
//    let playerLayer = AVPlayerLayer(player: player.player)
    
    container.registerForStoryboard(StandardPlayerContentViewController.self, name: nil) { r, c in
      c.player = playerProxy
      c.playerLayer = AVPlayerLayer(player: self.player.player)
    }
    
    container.registerForStoryboard(FullscreenPlayerContentViewController.self, name: nil) { r, c in
      c.player = playerProxy
      c.playerLayer = AVPlayerLayer(player: self.player.player)
    }

    container.registerForStoryboard(MasterPlayerViewController.self, name: nil) { r, c in
      c.player = playerProxy
    }

    container.registerForStoryboard(AppContainerViewController.self, name: nil) { r, c in
      c.player = playerProxy
    }

    container.registerForStoryboard(SingleFeedViewController.self, name: nil) { r, c in
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
  
  func applicationWillResignActive(application: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
  }
  
  func applicationDidEnterBackground(application: UIApplication) {
    // Use this methoa to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
  }
  
  func applicationWillEnterForeground(application: UIApplication) {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
  }
  
  func applicationDidBecomeActive(application: UIApplication) {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
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
}

extension AppDelegate: PlayerDataSource {
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
}