//
//  PlayerViewController.swift
//  
//
//  Created by Christopher Lucas on 1/30/16.
//
//

import UIKit
import AVFoundation
import MediaPlayer
import SDWebImage

import Alamofire

class PlayerViewController: UIViewController, PlayerEventHandler {
  let player = Player.sharedPlayer
  
  let db = try! DB()
  
  @IBOutlet weak var contentView: PlayerView!
  @IBOutlet weak var skipBackwardButton: UIButton!
  @IBOutlet weak var playPauseButton: UIButton!
  @IBOutlet weak var skipForwardButton: UIButton!
  @IBOutlet weak var curTimeLabel: UILabel!
  @IBOutlet weak var durationLabel: UILabel!
  @IBOutlet weak var positionSlider: UISlider!
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var authorLabel: UILabel!
  @IBOutlet weak var volumeView: MPVolumeView!
  
  // Wide screen video controls
  @IBOutlet weak var playerControls: UIStackView!
  @IBOutlet weak var wideScreenPositionSlider: UISlider!
  @IBOutlet weak var wideScreenCurTimeLabel: UILabel!
  @IBOutlet weak var wideScreenRemTimeLabel: UILabel!
  
  weak var currentPositionSlider: UISlider?
  weak var currentCurTimeLabel: UILabel?
  weak var currentRemTimeLabel: UILabel?
  
  var currentItem: Item? {
    guard let id = player.currentItem()?.id else { return nil }
    return db.itemWithID(id)
  }
  
  @IBAction func playerViewTapped(sender: AnyObject) {
    print("tapped", self.playerControls.alpha)
    UIView.animateWithDuration(0.2) {
      let alpha: CGFloat = self.playerControls.alpha.isZero ? 1 : 0
      self.playerControls.alpha = alpha
      self.wideScreenPositionSlider.alpha = alpha
      self.wideScreenRemTimeLabel.alpha = alpha
      self.wideScreenCurTimeLabel.alpha = alpha
    }
  }
  var timer: NSTimer?
  
  // MARK: Lifecycle -
  
  override func viewDidLoad() {
    guard let id = player.currentItem()?.id,
      let item = db.itemWithID(id) else {
      fatalError("no item is playing or item with id does not exist")
    }
    
    player.registerEventHandler(self)
    
    currentPositionSlider = positionSlider
    currentCurTimeLabel = curTimeLabel
    currentRemTimeLabel = durationLabel
    
    //        player.delegate = self
    
    titleLabel.text = item.title
    authorLabel.text = item.author
    
    volumeView.showsRouteButton = true
    volumeView.showsVolumeSlider = false
    
    var vc = self.parentViewController
    while vc != nil {
      guard let v = vc as? AppContainerViewController else {
        vc = vc?.parentViewController
        continue
      }
      
      print("YAYHERE")
      v.toggleMiniPlayerView()
      break
    }
    
    
    // hack to get airplay route button to adopt tint color
    for view in volumeView.subviews {
      if let btn = view as? UIButton {
        let temp = btn.currentImage?.imageWithRenderingMode(.AlwaysTemplate)
        volumeView.setRouteButtonImage(temp, forState: .Normal)
        break
      }
    }
    
    let sess = AVAudioSession.sharedInstance()
    for port in sess.currentRoute.outputs {
      print(port.portName)
    }

    if let item = player.currentItem() {
      if item.hasVideo() {
        showVideoView()
      } else {
        showArtworkView()
      }
    }
    
    updateUI(nil)
  }
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    startUpdateUITimer()
  }
  
  override func viewDidDisappear(animated: Bool) {
    timer?.invalidate()
    
    print("view did disappear")
    
    contentView.removePlayer()
    
    super.viewDidDisappear(animated)
  }
  
  override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
   
    // view.frame has not been updated yet, so expressions are inversed
    if view.frame.width < view.frame.height {
      currentPositionSlider = wideScreenPositionSlider
      currentCurTimeLabel = wideScreenCurTimeLabel
      currentRemTimeLabel = wideScreenRemTimeLabel
    } else {
      currentPositionSlider = positionSlider
      currentCurTimeLabel = curTimeLabel
      currentRemTimeLabel = durationLabel
    }
    
    updateUI(nil)
    
    coordinator.animateAlongsideTransition({ _ in
      let b = UIScreen.mainScreen().bounds
      self.navigationController?.navigationBarHidden = b.width > b.height
      self.contentView.layoutIfNeeded()
    }, completion: nil)
  }
  
  // MARK: UI -
  
  private func showArtworkView() {
    guard let item = currentItem else { return }
    guard let url = NSURL(string: item.imageURL) else { return }
   
    SDWebImageManager
      .sharedManager()
      .downloadImageWithURL(url, options: SDWebImageOptions.HighPriority, progress: nil) { img, _, _, _, _ in
        if img == nil { return }
        dispatch_async(dispatch_get_main_queue()) {
          self.setColors(img.getColors())
          self.contentView.setImage(img)
        }
    }
  }
  
  private func showVideoView() {
    contentView.setPlayer(player.player)
  }
  
  private func setColors(colors: UIImageColors) {
    // Go with the darkest
    var color = colors.primaryColor
    for c in [colors.secondaryColor, colors.detailColor] {
      if c.brightness < color.brightness {
        color = c
      }
    }
    
    for b in [skipBackwardButton, playPauseButton, skipForwardButton] {
      b.tintColor = color
    }
    
    navigationController?.navigationBar.tintColor = color
    
    positionSlider.minimumTrackTintColor = color
    positionSlider.maximumTrackTintColor = color
    positionSlider.thumbTintColor = color
    
    titleLabel.textColor = color
    authorLabel.textColor = color
    curTimeLabel.textColor = color
    durationLabel.textColor = color
    
    volumeView.tintColor = color
  }
  
  private func startUpdateUITimer() {
    timer?.invalidate()
    timer = NSTimer.init(timeInterval: 1,
                         target: self,
                         selector: #selector(PlayerViewController.updateUI(_:)),
                         userInfo: nil,
                         repeats: true)
    NSRunLoop.currentRunLoop().addTimer(timer!, forMode: NSDefaultRunLoopMode)
  }
  
  private func timeString(seconds: Int) -> String {
    var secs = seconds
    let hours = secs / 3600
    secs -= hours * 3600
    
    let minutes = secs / 60
    secs -= minutes * 60
    
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, secs)
    } else {
      return String(format: "%d:%02d", minutes, secs)
    }
  }
  
  func updateUI(timer: NSTimer?) {
    guard let item = currentItem else { return }
    
    currentPositionSlider?.value = Float(player.position)
    updateCurrentTimeLabel(player.currentTime())
    currentRemTimeLabel?.text = timeString(item.duration)
  }
  
  func updateCurrentTimeLabel(curTime: CMTime) {
    currentCurTimeLabel?.text = timeString(Int(curTime.seconds))
  }
  
  @IBAction func onPositionSliderValueChange(sender: UISlider) {
    guard let item = currentItem else { return }
    
    let time = Double(sender.value) * Double(item.duration)
    updateCurrentTimeLabel(CMTimeMakeWithSeconds(time, 1))
  }
  
  @IBAction func onPositionSliderTouchDown(sender: UISlider) {
    timer?.invalidate()
  }
  
  @IBAction func onPositionSliderTouchUp(sender: UISlider) {
    player.seekToPos(Double(sender.value))
    startUpdateUITimer()
  }
  
  @IBAction func onPlayPauseToggleTouchUp(sender: AnyObject) {
    player.isPlaying() ? player.pause() : player.play()
  }
  
  @IBAction func onAdvanceButtonTouchUp(sender: AnyObject) {
    player.seekToTime(CMTimeAdd(player.currentTime(), CMTime(seconds: 30, preferredTimescale: 1)))
  }
  
  @IBAction func onRewindButtonTouchUp(sender: AnyObject) {
    player.seekToTime(CMTimeSubtract(player.currentTime(), CMTime(seconds: 30, preferredTimescale: 1)))
  }
  
  // MARK: PlayerEventHandler
  
  func itemDidFinishPlaying(item: PlayerItem, nextItem: PlayerItem?) {
    if nextItem == nil {
      navigationController?.popViewControllerAnimated(true)
    }
  }
}
