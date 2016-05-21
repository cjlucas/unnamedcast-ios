//
//  NSDate.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 5/20/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import Foundation

func <(lhs: NSDate, rhs: NSDate) -> Bool {
  return lhs.compare(rhs) == .OrderedAscending
}

func >(lhs: NSDate, rhs: NSDate) -> Bool {
  return lhs.compare(rhs) == .OrderedDescending
}

func ==(lhs: NSDate, rhs: NSDate) -> Bool {
  return lhs.compare(rhs) == .OrderedSame
}
