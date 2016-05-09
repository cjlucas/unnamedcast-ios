//
//  AppDelegate.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 1/28/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import UIKit
import Alamofire
import RealmSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  
  func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    let ud = NSUserDefaults.standardUserDefaults()
    
    if ud.stringForKey("user_id") == nil {
      let sb = UIStoryboard(name: "Main", bundle: nil)
      self.window?.rootViewController = sb.instantiateViewControllerWithIdentifier("login")
      self.window?.makeKeyAndVisible()
    } else {
      print("Updating user feeds")
      try! DataStore().sync {
        print("Updated user feeds")
      }
    }
    
    if let data = ud.objectForKey("player") as? NSData {
      Player.sharedPlayer = NSKeyedUnarchiver.unarchiveObjectWithData(data) as! Player
    }
    
    ud.removeObjectForKey("player")
  
    // Override point for customization after application launch.
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
    let data = NSKeyedArchiver.archivedDataWithRootObject(Player.sharedPlayer)
    NSUserDefaults.standardUserDefaults().setObject(data, forKey: "player")
    print("App will terminate. Archived", data.length, "worth of data")
  }
  
  
}
