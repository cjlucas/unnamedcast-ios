//
//  AppContainerViewController.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 2/3/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import UIKit
import Swinject

class AppContainerViewController: UIViewController, UINavigationControllerDelegate, PlayerEventHandler {
  // Injected properties
  var player: PlayerController!
  
  // Defines the vertical spacing between the bottom of the mini player view
  // and the top of the superview's bottom layout. This is used to show/hide
  // the mini player view. Showing it requires setting the constant to 0,
  // hiding it requires the constant to be set to miniPlayerView.frame.height
  @IBOutlet weak var stackViewVerticalSpacingConstraint: NSLayoutConstraint!
  @IBOutlet weak var miniPlayerContainerView: UIView!
  
  private var childNavigationController: UINavigationController!
  
  var miniPlayerTapGestureRecognizer: UITapGestureRecognizer!
  
  var miniPlayerHidden: Bool {
    get {
      return stackViewVerticalSpacingConstraint != 0
    }
  }
  
  func setMiniPlayerHidden(hidden: Bool, animated: Bool) {
    miniPlayerTapGestureRecognizer.enabled = !hidden
    stackViewVerticalSpacingConstraint.constant = hidden
      ? -miniPlayerContainerView.frame.height
      : 0
    
    if animated {
      UIView.animateWithDuration(0.15) {
        self.view.layoutIfNeeded()
      }
    } else {
      self.view.layoutIfNeeded()
    }
  }
  
  var navigationViewController: UINavigationController! {
    return self.childViewControllers.first as? UINavigationController
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    player.registerForEvents(self)
    self.navigationViewController.delegate = self
    
    miniPlayerTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(miniPlayerWasTapped))
    miniPlayerContainerView.addGestureRecognizer(miniPlayerTapGestureRecognizer)
  
    setMiniPlayerHidden(player.currentItem == nil, animated: true)
  }
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if let vc = segue.destinationViewController as? UINavigationController {
      childNavigationController = vc
    }
  }
  
  func miniPlayerWasTapped() {
    guard let sb = storyboard else { fatalError("storyboard was nil") }
    let vc = sb.instantiateViewControllerWithIdentifier("PlayerViewController")
    self.navigationViewController.pushViewController(vc, animated: true)
  }
  
  // MARK: UINavigationControllerDelegate
  
  func navigationController(navigationController: UINavigationController, willShowViewController viewController: UIViewController, animated: Bool) {
    let shouldHide = player.currentItem == nil || viewController is MasterPlayerViewController
    setMiniPlayerHidden(shouldHide, animated: true)
  }
  
  // MARK: PlayerEventHandler
  
  func itemDidBeginPlaying(item: PlayerItem) {
    if childNavigationController.visibleViewController is MasterPlayerViewController {
      return
    }
    
    setMiniPlayerHidden(false, animated: true)
  }
  
  func receivedPeriodicTimeUpdate(item: PlayerItem, time: Double) {
  }
  
  func itemDidFinishPlaying(item: PlayerItem, nextItem: PlayerItem?) {
    guard nextItem == nil else { return }
    
    setMiniPlayerHidden(true, animated: true)
    
    if childNavigationController.visibleViewController is MasterPlayerViewController {
      childNavigationController.popViewControllerAnimated(true)
    }
  }
}