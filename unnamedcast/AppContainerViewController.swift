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
  
  var navigationViewController: UINavigationController! {
    return self.childViewControllers.first as? UINavigationController
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.navigationViewController.delegate = self
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
    }
  }
}