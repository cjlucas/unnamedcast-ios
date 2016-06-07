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
  // Defines the vertical spacing between the bottom of the mini player view
  // and the top of the superview's bottom layout. This is used to show/hide
  // the mini player view. Showing it requires setting the constant to 0,
  // hiding it requires the constant to be set to miniPlayerView.frame.height
  @IBOutlet weak var stackViewVerticalSpacingConstraint: NSLayoutConstraint!
  
  var origMiniPlayerHeight: CGFloat!
  
  var miniPlayerHidden: Bool {
    get {
      return stackViewVerticalSpacingConstraint != 0
    }
  }
  
  func setMiniPlayerHidden(hidden: Bool, animated: Bool) {
    stackViewVerticalSpacingConstraint.constant = hidden ? -origMiniPlayerHeight : 0
    
    if animated {
      UIView.animateWithDuration(0.2) {
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
    self.navigationViewController.delegate = self
    origMiniPlayerHeight = 70
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
  
  // MARK: UINavigationControllerDelegate -
  
  func navigationController(navigationController: UINavigationController, willShowViewController viewController: UIViewController, animated: Bool) {
    if let _ = viewController as? MasterPlayerViewController {
      print("MADE IT")
      setMiniPlayerHidden(true, animated: true)
    } else if miniPlayerHidden {
      setMiniPlayerHidden(false, animated: true)
    }
  }
}