//
//  PlayerView.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 3/26/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import UIKit
import AVFoundation

class PlayerView: UIView {
  var image: UIImage?
  var imageView: UIImageView?
  
  var playerLayer: AVPlayerLayer?
  var playerView: UIView?
  
//  override func updateConstraints() {
//    super.updateConstraints()
//  }
  
//  func setImage(image: UIImage) {
//  }
//
  
  func removeImage() {
    imageView?.removeFromSuperview()
    imageView = nil
    image = nil
  }
  
  func setPlayer(player: AVPlayer) {
    let view = UIView(frame: bounds)
    let layer = AVPlayerLayer(player: player)
    
    layer.frame = bounds
    layer.videoGravity = AVLayerVideoGravityResizeAspect
    
    playerView?.translatesAutoresizingMaskIntoConstraints = false
    view.layer.addSublayer(layer)
    addSubview(view)
    sendSubviewToBack(view)
    
    playerView = view
    playerLayer = layer
    
//    setNeedsUpdateConstraints()
  }
  
  func removePlayer() {
    playerLayer?.removeFromSuperlayer()
    playerView?.removeFromSuperview()
    playerLayer = nil
    playerView = nil
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    if let view = playerView,
      let layer = playerLayer {
      view.frame = bounds
      layer.frame = bounds
    }
  }
}
