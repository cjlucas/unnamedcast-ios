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

class PlayerContentViewModel {
  let player = Player.sharedPlayer
  let db = try! DB()
  
  private var playerView: PlayerView
  private var timeSlider: UISlider
  private var curTimeLabel: UILabel
  private var remTimeLabel: UILabel
  private var titleLabel: UILabel?
  private var authorLabel: UILabel?
  
  private var timer: NSTimer?
  
  var currentItem: Item? {
    guard let item = player.currentItem else { return nil }
    return db.itemWithID(item.id)
  }
  
  init(playerView: PlayerView,
       timeSlider: UISlider,
       curTimeLabel: UILabel,
       remTimeLabel: UILabel,
       titleLabel: UILabel? = nil,
       authorLabel: UILabel? = nil) {
    self.playerView = playerView
    self.timeSlider = timeSlider
    self.curTimeLabel = curTimeLabel
    self.remTimeLabel = remTimeLabel
    self.titleLabel = titleLabel
    self.authorLabel = authorLabel
    
    update()
    
    if let item = player.currentItem where item.hasVideo() {
      playerView.setPlayer(player.player)
    } else {
      guard let imageURL = currentItem?.feed?.imageUrl,
        let url = NSURL(string: imageURL) else { return }
      
      SDWebImageManager
        .sharedManager()
        .downloadImageWithURL(url, options: SDWebImageOptions.HighPriority, progress: nil) { img, _, _, _, _ in
          if img == nil { return }
          dispatch_async(dispatch_get_main_queue()) {
            self.playerView.setImage(img)
          }
      }
    }
  }
  
  func startRefreshTimer() {
    if let timer = timer where timer.valid {
      return
    }
    
    stopRefreshTimer()
    timer = NSTimer.scheduledTimerWithTimeInterval(1,
                                                   target: self,
                                                   selector: #selector(update),
                                                   userInfo: nil,
                                                   repeats: true)
    timer?.fire()
  }
  
  func stopRefreshTimer() {
    timer?.invalidate()
  }
  
  func timeSliderValueDidChange() {
    guard let item = currentItem else { return }
    
    let time = Double(timeSlider.value) * Double(item.duration)
    player.seekToTime(CMTimeMakeWithSeconds(time, 1000))
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
  
  @objc func update() {
    guard let item = currentItem else { return }
    
    let time = player.currentTime().seconds
    
    self.timeSlider.value = Float(player.position)
    self.curTimeLabel.text = timeString(Int(time))
    self.remTimeLabel.text = "-\(timeString(item.duration - Int(time)))"
    
    if let label = titleLabel {
      label.text = item.title
    }
    
    if let label = authorLabel {
      label.text = item.author
    }
  }
}

class StandardPlayerContentViewController: UIViewController {
  let player = Player.sharedPlayer
  
  private var viewModel: PlayerContentViewModel!
  
  @IBOutlet weak var playerView: PlayerView!
  @IBOutlet weak var curTimeLabel: UILabel!
  @IBOutlet weak var timeSlider: UISlider!
  @IBOutlet weak var remTimeLabel: UILabel!
  
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var authorLabel: UILabel!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    print("viewDidLoad (standard)")
    
    viewModel = PlayerContentViewModel(playerView: playerView,
                                       timeSlider: timeSlider,
                                       curTimeLabel: curTimeLabel,
                                       remTimeLabel: remTimeLabel,
                                       titleLabel: titleLabel,
                                       authorLabel: authorLabel)
    viewModel.startRefreshTimer()
  }
  
  // MARK: Actions
  
  @IBAction func timeSliderTouchedDown(sender: AnyObject) {
    viewModel.stopRefreshTimer()
  }
  
  @IBAction func timeSliderTouchedUp(sender: AnyObject) {
    viewModel.timeSliderValueDidChange()
    viewModel.startRefreshTimer()
  }
  
  @IBAction func rewindButtonPressed(sender: AnyObject) {
    player.seekToTime(CMTimeSubtract(player.currentTime(), CMTime(seconds: 30, preferredTimescale: 1)))
  }
  
  @IBAction func playPauseButtonPressed(sender: AnyObject) {
    player.isPlaying() ? player.pause() : player.play()
  }
  
  @IBAction func forwardButtonPressed(sender: AnyObject) {
    player.seekToTime(CMTimeAdd(player.currentTime(), CMTime(seconds: 30, preferredTimescale: 1)))
  }
}

class FullscreenPlayerContentViewController: UIViewController {
  let player = Player.sharedPlayer

  private var viewModel: PlayerContentViewModel!
  
  @IBOutlet weak var playerView: PlayerView!
  
  @IBOutlet weak var playerControls: UIStackView!
  @IBOutlet weak var curTimeLabel: UILabel!
  @IBOutlet weak var timeSlider: UISlider!
  @IBOutlet weak var remTimeLabel: UILabel!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    print("viewDidLoad (fullscreen)")
    
    viewModel = PlayerContentViewModel(playerView: playerView,
                                       timeSlider: timeSlider,
                                       curTimeLabel: curTimeLabel,
                                       remTimeLabel: remTimeLabel)
    viewModel.startRefreshTimer()
  }
  
  // MARK: Actions
  
  @IBAction func timeSliderTouchedDown(sender: AnyObject) {
    viewModel.stopRefreshTimer()
  }
  
  @IBAction func timeSliderTouchedUp(sender: AnyObject) {
    viewModel.timeSliderValueDidChange()
    viewModel.startRefreshTimer()
  }
  
  @IBAction func rewindButtonPressed(sender: AnyObject) {
    player.seekToTime(CMTimeSubtract(player.currentTime(), CMTime(seconds: 30, preferredTimescale: 1)))
  }
  
  @IBAction func playPauseButtonPressed(sender: AnyObject) {
    player.isPlaying() ? player.pause() : player.play()
  }
  
  @IBAction func forwardButtonPressed(sender: AnyObject) {
    player.seekToTime(CMTimeAdd(player.currentTime(), CMTime(seconds: 30, preferredTimescale: 1)))
  }
  
  @IBAction func playerViewTapped(sender: AnyObject) {
    let alpha: CGFloat = self.playerControls.alpha.isZero ? 1 : 0
    
    if alpha == 1 {
      viewModel.startRefreshTimer()
    } else {
      viewModel.stopRefreshTimer()
    }
    
    UIView.animateWithDuration(0.2) {
      for view in [self.playerControls, self.curTimeLabel, self.timeSlider, self.remTimeLabel] {
        view.alpha = alpha
      }
    }
  }
}

class PlayerContentViewSegue: UIStoryboardSegue {
  // Noop. Transition is handled by container view controller
  override func perform() {
  }
}

class PlayerContainerViewController: UIViewController {
  enum Segue {
    case Standard
    case Fullscreen
  }
  
  var standardViewController: StandardPlayerContentViewController!
  var fullscreenViewController: FullscreenPlayerContentViewController!
  
  var currentSegueIdentifier: String! {
    didSet {
      performSegueWithIdentifier(currentSegueIdentifier, sender: self)
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    currentSegueIdentifier = "standardPlayer"
  }
  
  override func showViewController(vc: UIViewController, sender: AnyObject?) {
    print("GOT A showViewController from \(sender)")
  }
  
  override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
    print("view will transition")
    currentSegueIdentifier = currentSegueIdentifier == "standardPlayer" ? "fullscreenPlayer" : "standardPlayer"
  }
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    guard let id = segue.identifier else {
      fatalError("No identifier for segue")
    }
    
    print("PREPARE FOR SEGUE \(id) \(self.view.bounds)")
    
    childViewControllers.first?.removeFromParentViewController()
    
    segue.destinationViewController.willMoveToParentViewController(self)
    addChildViewController(segue.destinationViewController)
    segue.destinationViewController.view.frame = view.bounds
    view.addSubview(segue.destinationViewController.view)
    segue.destinationViewController.didMoveToParentViewController(self)
    
    
    
    switch id {
    case "standardPlayer":
      standardViewController = segue.destinationViewController as! StandardPlayerContentViewController
    case "fullscreenPlayer":
      fullscreenViewController = segue.destinationViewController as! FullscreenPlayerContentViewController
    default:
      fatalError("Unknown segue: \(id)")
    }

    self.navigationController?.navigationBarHidden
      = segue.destinationViewController == fullscreenViewController
  }
}

class MasterPlayerViewController: UIViewController {
  weak var containerViewController: PlayerContainerViewController!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    print("viewDidLoad (master)")
    toggleMiniPlayerView()
  }
  
  func toggleMiniPlayerView() {
    // hide mini player
    var vc = self.parentViewController
    while vc != nil {
      guard let v = vc as? AppContainerViewController else {
        vc = vc?.parentViewController
        continue
      }
      
      print("hithere")
      v.miniPlayerHidden = true
//      v.toggleMiniPlayerView()
      break
    }
  }
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    print("HITHERE")
    guard let id = segue.identifier where id == "PlayerViewEmbedded" else {
      fatalError("Unexpected segue")
    }
  
    containerViewController = segue.destinationViewController as! PlayerContainerViewController
  }
}