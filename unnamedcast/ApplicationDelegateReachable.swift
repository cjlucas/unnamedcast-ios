//
//  File.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 5/13/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import UIKit

protocol ApplicationDelegateReachable {
  var applicationDelegate: AppDelegate { get }
}

extension ApplicationDelegateReachable {
  var applicationDelegate: AppDelegate {
    return UIApplication.sharedApplication().delegate as! AppDelegate
  }
}