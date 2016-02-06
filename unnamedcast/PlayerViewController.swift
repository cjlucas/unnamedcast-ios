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

import Alamofire

class PlayerViewController: UIViewController, PlayerEventHandler {
    let player = Player.sharedPlayer
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var skipBackwardButton: UIButton!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var skipForwardButton: UIButton!
    @IBOutlet weak var curTimeLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var positionSlider: UISlider!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var volumeView: MPVolumeView!
    
    var timer: NSTimer?
    
    // MARK: Lifecycle -
    
    override func viewDidLoad() {
        let item = player.currentItem()
        
        if item == nil {
            fatalError("PlayerViewController loaded without a current item")
        }
        
//        player.delegate = self
        
        titleLabel.text = item?.title
        authorLabel.text = item?.author
        
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
        
        updateUI(nil)
    }
    
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        startUpdateUITimer()
        
        if let item = player.currentItem() {
            if item.hasVideo() {
                showVideoView()
            } else {
                showArtworkView()
            }
        }
    }
    
    override func viewDidDisappear(animated: Bool) {
        timer?.invalidate()
        
        print("view did disappear")
       
        for view in contentView.subviews {
            guard let layers = view.layer.sublayers else { continue }
            for layer in layers {
                if let l = layer as? AVPlayerLayer {
                    print("Removed player from", layer)
                    l.player = nil
                }
            }
        }

        super.viewDidDisappear(animated)
    }
    
    // MARK: UI -
    
    private func showArtworkView() {
        guard let url = player.currentItem()?.imageUrl else { return }
        
        var frame = contentView.frame
        frame.origin.x = 0
        frame.origin.y = 0
        
        let view = UIImageView(frame: frame)
        contentView.addSubview(view)
        
        Alamofire.request(.GET, url).responseData { resp in
            if let data = resp.data, let image = UIImage(data: data) {
                view.image = image
                self.setColors(image.getColors())
            } else {
                print("Could not get data", resp)
            }
        }
    }
    
    private func showVideoView() {
        let frame = contentView.frame
        
        let view = UIView(frame: CGRectMake(0, 0, frame.width, frame.height))
        let layer = AVPlayerLayer(player: player.player)
        layer.frame = CGRectMake(0, 0, view.frame.width, view.frame.height)
        layer.videoGravity = AVLayerVideoGravityResizeAspect
        
        view.layer.addSublayer(layer)
        contentView.addSubview(view)
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
        timer = NSTimer.init(timeInterval: 1, target: self, selector: "updateUI:", userInfo: nil, repeats: true)
        NSRunLoop.currentRunLoop().addTimer(timer!, forMode: NSDefaultRunLoopMode)
    }
    
    private func timeString(var seconds: Int) -> String {
        let hours = seconds / 3600
        seconds -= hours * 3600
        
        let minutes = seconds / 60
        seconds -= minutes * 60
       
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    func updateUI(timer: NSTimer?) {
        positionSlider.value = player.position
        updateCurrentTimeLabel(player.currentTime())
        if let item = player.currentItem() {
            durationLabel.text = timeString(item.duration)
        }
    }
    
    func updateCurrentTimeLabel(curTime: CMTime) {
        curTimeLabel.text = timeString(Int(curTime.seconds))
    }
    
    @IBAction func onPositionSliderValueChange(sender: UISlider) {
        guard let item = player.currentItem() else { return }
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
    
    // MARK: -
    func itemDidFinishPlaying(item: PlayerItem, nextItem: PlayerItem?) {
        if nextItem == nil {
            navigationController?.popViewControllerAnimated(true)
        }
    }
}
