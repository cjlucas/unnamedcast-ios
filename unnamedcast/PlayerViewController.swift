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
  let db = try! DB()
 
  private var player: PlayerController
  private weak var playerView: PlayerView?
  private weak var timeSlider: UISlider?
  private weak var curTimeLabel: UILabel?
  private weak var remTimeLabel: UILabel?
  private weak var titleLabel: UILabel?
  private weak var authorLabel: UILabel?
  private weak var sleepTimerButton: UIButton?
  
  var playerLayer: AVPlayerLayer? {
    didSet {
      guard let view = playerView,
        let layer = playerLayer,
        item = player.currentItem where item.hasVideo() else { return }
      view.setPlayer(layer)
    }
  }
  
  var image: UIImage? {
    didSet {
      guard let view = playerView,
        let image = image,
        item = player.currentItem where !item.hasVideo() else { return }
      view.setImage(image)
    }
  }
  
  private var timer: NSTimer?
  
  var currentItem: Item? {
    guard let item = player.currentItem else { return nil }
    return db.itemWithID(item.id)
  }
  
  var sleepTimerDuration: Int {
    get {
      return player.timerDuration
    }
    set(duration) {
      player.timerDuration = duration
      update()
    }
  }
  
  init(player: PlayerController,
       playerView: PlayerView,
       timeSlider: UISlider,
       curTimeLabel: UILabel,
       remTimeLabel: UILabel,
       titleLabel: UILabel? = nil,
       authorLabel: UILabel? = nil,
       sleepTimerButton: UIButton? = nil) {
    self.player = player
    self.playerView = playerView
    self.timeSlider = timeSlider
    self.curTimeLabel = curTimeLabel
    self.remTimeLabel = remTimeLabel
    self.titleLabel = titleLabel
    self.authorLabel = authorLabel
    self.sleepTimerButton = sleepTimerButton
    
    update()
    
    guard let imageURL = currentItem?.feed?.imageUrl,
      let url = NSURL(string: imageURL) else { return }
    
    SDWebImageManager
      .sharedManager()
      .downloadImageWithURL(url, options: SDWebImageOptions.HighPriority, progress: nil) { img, _, _, _, _ in
        if img == nil { return }
        dispatch_async(dispatch_get_main_queue()) {
          self.image = img
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
    guard let item = currentItem,
      value = timeSlider?.value else { return }
    
    let time = Double(value) * Double(item.duration)
    player.seekToTime(time)
  }
  
  private func timeString(seconds: Double) -> String {
    guard seconds.isNormal else { return "00:00" }
    
    var secs = Int(seconds)
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

    let curTime = player.currentTime
    let duration = Double(item.duration)
    timeSlider?.value = Float(curTime / duration)
    curTimeLabel?.text = timeString(curTime)
    remTimeLabel?.text = "-\(timeString(duration - curTime))"
   
    titleLabel?.text = item.title
    authorLabel?.text = item.author
  
    if let btn = self.sleepTimerButton {
      let time = self.player.timerDuration
      let title = time == 0
        ? "Sleep"
        : "Sleep \(timeString(Double(time)))"
      
      btn.setTitle(title, forState: .Normal)
    }
  }
}

class StandardPlayerContentViewController: UIViewController {
  var player: PlayerController!
  var layerProvider: AVPlayerLayerProvider!
  
  private var viewModel: PlayerContentViewModel!
  
  @IBOutlet weak var playerView: PlayerView!
  @IBOutlet weak var curTimeLabel: UILabel!
  @IBOutlet weak var timeSlider: UISlider!
  @IBOutlet weak var remTimeLabel: UILabel!
  
  @IBOutlet weak var titleLabel: UILabel!
  @IBOutlet weak var authorLabel: UILabel!
  
  @IBOutlet weak var sleepTimerButton: UIButton!
  override func viewDidLoad() {
    super.viewDidLoad()
    
    viewModel = PlayerContentViewModel(player: player,
                                       playerView: playerView,
                                       timeSlider: timeSlider,
                                       curTimeLabel: curTimeLabel,
                                       remTimeLabel: remTimeLabel,
                                       titleLabel: titleLabel,
                                       authorLabel: authorLabel,
                                       sleepTimerButton: sleepTimerButton)
  }
 
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    viewModel.startRefreshTimer()
  }
  
  override func viewDidDisappear(animated: Bool) {
    super.viewDidDisappear(animated)
    viewModel.stopRefreshTimer()
  }
  
  override func didMoveToParentViewController(parent: UIViewController?) {
    super.didMoveToParentViewController(parent)

    viewModel.startRefreshTimer()
    
    layerProvider.register(String(self.dynamicType)) { layer in
      self.viewModel.playerLayer = layer
    }
  }
  
  override func removeFromParentViewController() {
    super.removeFromParentViewController()
    
    viewModel.stopRefreshTimer()
    layerProvider.unregister(String(self.dynamicType))
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
    player.seekToTime(player.currentTime - 30)
  }
  
  @IBAction func playPauseButtonPressed(sender: AnyObject) {
    player.isPlaying ? player.pause() : player.play()
  }
  
  @IBAction func forwardButtonPressed(sender: AnyObject) {
    player.seekToTime(player.currentTime + 30)
  }
  
  @IBAction func sleepButtonPressed(sender: AnyObject) {
    let durations = [5 * 60, 15 * 60, 30 * 60, 60 * 60]
    let time = viewModel.sleepTimerDuration
    
    // iterate through available durations, if the current timer
    // is strictly less than the proposed duration, update the timer to that,
    // otherwise stop the timer.
    // timeout to allow rapid clicks.
    let toggleTimeout = 2
    for d in durations {
      if time + toggleTimeout < d {
        viewModel.sleepTimerDuration = d
        return
      }
    }
   
    viewModel.sleepTimerDuration = 0
  }
}

class FullscreenPlayerContentViewController: UIViewController {
  var player: PlayerController!
  var layerProvider: AVPlayerLayerProvider!
  
  private var viewModel: PlayerContentViewModel!
  
  @IBOutlet weak var playerView: PlayerView!
  
  @IBOutlet weak var playerControls: UIStackView!
  @IBOutlet weak var curTimeLabel: UILabel!
  @IBOutlet weak var timeSlider: UISlider!
  @IBOutlet weak var remTimeLabel: UILabel!
  
  var controlsHidden: Bool {
    get {
      return self.playerControls.alpha.isZero
    }
    set(hidden) {
      let alpha: CGFloat = hidden ? 0 : 1
      for view in [self.playerControls,
                   self.curTimeLabel,
                   self.timeSlider,
                   self.remTimeLabel] {
        view.alpha = alpha
      }
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    controlsHidden = true
    
    viewModel = PlayerContentViewModel(player: player,
                                       playerView: playerView,
                                       timeSlider: timeSlider,
                                       curTimeLabel: curTimeLabel,
                                       remTimeLabel: remTimeLabel)
  }
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    viewModel.startRefreshTimer()
  }
  
  override func viewDidDisappear(animated: Bool) {
    super.viewDidDisappear(animated)
    viewModel.stopRefreshTimer()
  }
  
  override func didMoveToParentViewController(parent: UIViewController?) {
    super.didMoveToParentViewController(parent)
    
    viewModel.startRefreshTimer()
    
    layerProvider.register(String(self.dynamicType)) { layer in
      self.viewModel.playerLayer = layer
    }
  }
  
  override func removeFromParentViewController() {
    super.removeFromParentViewController()
    
    viewModel.stopRefreshTimer()
    layerProvider.unregister(String(self.dynamicType))
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
    player.seekToTime(player.currentTime - 30)
  }
  
  @IBAction func playPauseButtonPressed(sender: AnyObject) {
    player.isPlaying ? player.pause() : player.play()
  }
  
  @IBAction func forwardButtonPressed(sender: AnyObject) {
    player.seekToTime(player.currentTime + 30)
  }
  
  @IBAction func playerViewTapped(sender: AnyObject) {
    let wasHidden = controlsHidden

    UIView.animateWithDuration(0.2) {
      self.controlsHidden = !wasHidden
    }
    
    if wasHidden {
      viewModel.startRefreshTimer()
    } else {
      viewModel.stopRefreshTimer()
    }
  }
}

class PlayerContentViewSegue: UIStoryboardSegue {
  // Noop. Transition is handled by container view controller
  override func perform() {
  }
}

class PlayerContainerViewController: UIViewController {
  enum Segue: String {
    case standardPlayer = "standardPlayer"
    case fullscreenPlayer = "fullscreenPlayer"
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    performSegue(.standardPlayer, sender: self)
  }
  
  override func viewWillDisappear(animated: Bool) {
    self.navigationController?.navigationBarHidden = false
    super.viewWillDisappear(animated)
  }
  
  private func performSegue(segue: Segue, sender: AnyObject?) {
    performSegueWithIdentifier(segue.rawValue, sender: sender)
  }
  
  override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
    let segue: Segue = size.height > size.width ? .standardPlayer : .fullscreenPlayer
    performSegue(segue, sender: self)
  }
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    guard let id = segue.identifier else {
      fatalError("No identifier for segue")
    }
    
    let segueID = Segue(rawValue: id)
    
    childViewControllers.first?.removeFromParentViewController()
    
    segue.destinationViewController.willMoveToParentViewController(self)
    addChildViewController(segue.destinationViewController)
    segue.destinationViewController.view.frame = view.bounds
    view.addSubview(segue.destinationViewController.view)
    segue.destinationViewController.didMoveToParentViewController(self)
    
    self.navigationController?.navigationBarHidden = (segueID == Segue.fullscreenPlayer)
  }
}

class MasterPlayerViewController: UIViewController {
}
