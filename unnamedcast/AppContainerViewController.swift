//
//  AppContainerViewController.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 2/3/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import UIKit
import Swinject

class AppContainerViewController: UIViewController, UINavigationControllerDelegate {
  @IBOutlet weak var miniPlayerView: UIView!
  
  // Defines the vertical spacing between the bottom of the mini player view
  // and the top of the superview's bottom layout. This is used to show/hide
  // the mini player view. Showing it requires setting the constant to 0,
  // hiding it requires the constant to be set to miniPlayerView.frame.height
  @IBOutlet weak var miniPlayerViewPositionConstraint: NSLayoutConstraint!
  
  @IBOutlet weak var miniPlayerTitleLabel: UILabel!
  
  @IBOutlet weak var progressBarWidthConstraint: NSLayoutConstraint!
  
  private(set) var miniPlayerHidden: Bool {
    get {
      return self.miniPlayerViewPositionConstraint.constant != 0
    }
    
    set(val) {
      self.miniPlayerViewPositionConstraint.constant = val
        ? miniPlayerView.frame.height
        : 0
    }
  }
  
  let db = try! DB(configuration: nil)
 
  var player: PlayerController!
  
  var timer: NSTimer? // TODO: rename me
  
  var navigationViewController: UINavigationController! {
    return self.childViewControllers.first as? UINavigationController
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
   
    player.registerForEvents(self)
    timer = NSTimer.scheduledTimerWithTimeInterval(1,
                                                   target: self,
                                                   selector: #selector(AppContainerViewController.updateMiniPlayer(_:)),
                                                   userInfo: nil,
                                                   repeats: true)
    timer?.fire()
    
    self.navigationViewController.delegate = self
  }
  
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
            toggleMiniPlayerView(animated: false)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  func showMiniPlayerView(animated animated: Bool = false) {
    guard miniPlayerHidden else { return }
    guard shouldShowMiniPlayer() else { return }
    
    toggleMiniPlayerView(animated: animated)
  }
  
  func hideMiniPlayerView(animated animated: Bool = false) {
    guard !miniPlayerHidden else { return }
    toggleMiniPlayerView(animated: animated)
  }
  
  func toggleMiniPlayerView(animated animated: Bool = false) {
    miniPlayerHidden = !miniPlayerHidden
    
    if animated {
      UIView.animateWithDuration(0.2) {
        self.view.layoutIfNeeded()
      }
    } else {
      self.view.layoutIfNeeded()
    }
    
    print("dun it", self.miniPlayerView.frame)
  }
  
  func updateProgressBar(progress: Float) {
    self.progressBarWidthConstraint.constant = self.miniPlayerView.frame.width * CGFloat(progress)
    self.view.layoutIfNeeded()
  }
  
  private func shouldShowMiniPlayer() -> Bool {
    guard (self.navigationViewController.topViewController as? MasterPlayerViewController) == nil else { return false }
    return player.isPlaying || player.isPaused
  }
  
  /*
  // MARK: - Navigation
  
  // In a storyboard-based application, you will often want to do a little preparation before navigation
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
  // Get the new view controller using segue.destinationViewController.
  // Pass the selected object to the new view controller.
  }
  */
  
  // MARK: MiniPlayer -
  
  func updateMiniPlayer(timer: NSTimer?) {
    if (shouldShowMiniPlayer() == miniPlayerHidden) {
        toggleMiniPlayerView()
    }
    

    guard let playerItem = player.currentItem else { return }
    guard let item = db.itemWithID(playerItem.id) else { return }
    
    let pos = player.currentTime / Double(item.duration)
    
    if player.isPlaying {
      try! self.db.write {
        item.state = .InProgress(position: pos)
      }
    }
    
    miniPlayerTitleLabel.text = item.title
  }
  
  @IBAction func togglePlayPause(sender: AnyObject) {
    if player.isPlaying {
      player.pause()
    } else {
      player.play()
    }
  }
  
  @IBAction func miniPlayerViewTapped(sender: UITapGestureRecognizer) {
    guard let sb = storyboard else { fatalError("storyboard is nil") }
    hideMiniPlayerView()
  
    let vc = sb.instantiateViewControllerWithIdentifier("PlayerViewController")
    self.navigationViewController.pushViewController(vc, animated: true)
  }
  
  // MARK: UINavigationControllerDelegate -
  
  func navigationController(navigationController: UINavigationController, willShowViewController viewController: UIViewController, animated: Bool) {
    if let _ = viewController as? MasterPlayerViewController {
      print("MADE IT")
      hideMiniPlayerView()
    } else if shouldShowMiniPlayer() {
      showMiniPlayerView()
    }
  }
}

extension AppContainerViewController: PlayerEventHandler {
  func itemDidFinishPlaying(item: PlayerItem, nextItem: PlayerItem?) {
    print("itemDidFinishPlaying", item, nextItem)
    // initializing a db here since this is not guaranteed to be called on the main thread
    let db = try! DB()
    try! db.write {
      if let item = db.itemWithID(item.id) {
        item.state = .Played
      }
      
      guard let nextItem = nextItem else { return }

      if let item = db.itemWithID(nextItem.id) {
        item.state = .InProgress(position: 0)
      }
    }
  }
}
