//
//  AppContainerViewController.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 2/3/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import UIKit

class AppContainerViewController: UIViewController, PlayerEventHandler, UINavigationControllerDelegate {
  @IBOutlet weak var miniPlayerView: UIView!
  @IBOutlet weak var miniPlayerHeightConstraint: NSLayoutConstraint!
  @IBOutlet weak var miniPlayerTitleLabel: UILabel!
  @IBOutlet weak var progressBarWidthConstraint: NSLayoutConstraint!
  
  let datastore = DataStore()
  var i: Double = 0
  
  var player: Player {
    get {
      return Player.sharedPlayer
    }
  }
  
  var timer: NSTimer?
  
  var navigationViewController: UINavigationController! {
    return self.childViewControllers.first as? UINavigationController
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.player.delegate = self
    
    timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: "updateMiniPlayer:", userInfo: nil, repeats: true)
    timer?.fire()
    
    self.navigationViewController.delegate = self
  }
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    //        toggleMiniPlayerView(animated: false)
    
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  func showMiniPlayerView(animated animated: Bool = false) {
    guard miniPlayerHeightConstraint.constant == 0 else { return }
    guard shouldShowMiniPlayer() else { return }
    
    toggleMiniPlayerView(animated: animated)
  }
  
  func hideMiniPlayerView(animated animated: Bool = false) {
    guard miniPlayerHeightConstraint.constant > 0 else { return }
    toggleMiniPlayerView(animated: animated)
  }
  
  func toggleMiniPlayerView(animated animated: Bool = false) {
    let miniPlayerHeight: CGFloat = 70
    miniPlayerHeightConstraint.constant = miniPlayerHeightConstraint.constant == 0
      ? miniPlayerHeight : 0
    
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
    guard (self.navigationViewController.topViewController as? PlayerViewController) == nil else { return false }
    return player.isPlaying() || player.isPaused()
  }
  
  /*
  // MARK: - Navigation
  
  // In a storyboard-based application, you will often want to do a little preparation before navigation
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
  // Get the new view controller using segue.destinationViewController.
  // Pass the selected object to the new view controller.
  }
  */
  
  func itemDidFinishPlaying(item: PlayerItem, nextItem: PlayerItem?) {
  }
  
  // MARK: MiniPlayer -
  
  func updateMiniPlayer(timer: NSTimer?) {
    if (shouldShowMiniPlayer() && miniPlayerHeightConstraint.constant == 0) ||
      (!shouldShowMiniPlayer() && miniPlayerHeightConstraint.constant > 0) {
        toggleMiniPlayerView()
    }
    

    guard let playerItem = player.currentItem() else { return }
    
    let items = datastore.realm.objects(Item).filter("key = %@", playerItem.key)
    guard let item = items.first else { return }
    
    if player.isPlaying() && player.position > 0 {
      updateProgressBar(player.position)
      datastore.updateItemState(item, progress: Double(player.position)) {}
    }
    
    miniPlayerTitleLabel.text = item.title
    
  }
  
  @IBAction func togglePlayPause(sender: AnyObject) {
    if player.isPlaying() {
      player.pause()
    } else {
      player.play()
    }
  }
  
  @IBAction func miniPlayerViewTapped(sender: UITapGestureRecognizer) {
    let sb = UIStoryboard(name: "Main", bundle: nil)
    let vc = sb.instantiateViewControllerWithIdentifier("PlayerViewController")
    self.navigationViewController.pushViewController(vc, animated: true)
  }
  
  // MARK: UINavigationControllerDelegate -
  
  func navigationController(navigationController: UINavigationController, willShowViewController viewController: UIViewController, animated: Bool) {
    if let _ = viewController as? PlayerViewController {
      print("MADE IT")
      hideMiniPlayerView()
    } else if shouldShowMiniPlayer() {
      showMiniPlayerView()
    }
  }
}
