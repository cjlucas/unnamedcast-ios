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
  
  private var progressBarView: UIView = UIView()
  
  var progress: Float = 0 {
    didSet {
      setNeedsLayout()
    }
  }
  
  required override init(frame: CGRect) {
    super.init(frame: frame)
    addSubview(progressBarView)
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    addSubview(progressBarView)
  }
  
  override func awakeFromNib() {
    super.awakeFromNib()
    progressBarView.backgroundColor = foregroundColor
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    let width = CGFloat(progress) * frame.width
    let height = frame.height
    progressBarView.frame = CGRectMake(0, 0, width, height)
  }
}
