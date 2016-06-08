//
//  ProgressView.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 6/6/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import UIKit

class ProgressView: UIView {
  @IBInspectable
  var foregroundColor: UIColor!
  
  private var progressBarView: UIView
  
  var progress: Float = 0 {
    didSet {
      let width = CGFloat(progress) * frame.width
      let height = frame.height
      progressBarView.frame = CGRectMake(0, 0, width, height)
      setNeedsLayout()
    }
  }
  
  required override init(frame: CGRect) {
    progressBarView = UIView(frame: CGRectMake(0, 0, 0, 2))
    progressBarView.backgroundColor = UIColor.redColor()

    super.init(frame: frame)
    addSubview(progressBarView)
  }
  
  required init?(coder aDecoder: NSCoder) {
    progressBarView = UIView(frame: CGRectMake(0, 0, 0, 2))
    progressBarView.backgroundColor = UIColor.redColor()
    
    super.init(coder: aDecoder)
    addSubview(progressBarView)
  }
}
