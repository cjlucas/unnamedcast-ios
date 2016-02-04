//
//  AppContainerViewController.swift
//  unnamedcast
//
//  Created by Christopher Lucas on 2/3/16.
//  Copyright © 2016 Christopher Lucas. All rights reserved.
//

import UIKit

class AppContainerViewController: UIViewController, PlayerEventHandler {
    let player = Player.sharedPlayer

    @IBOutlet weak var miniPlayerView: UIView!
    @IBOutlet weak var miniPlayerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var miniPlayerTitleLabel: UILabel!
    @IBOutlet weak var progressBarWidthConstraint: NSLayoutConstraint!
    
    var timer: NSTimer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.player.delegate = self
        
        timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: "updateMiniPlayer:", userInfo: nil, repeats: true)
        timer?.fire()
        
        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
//        toggleMiniPlayerView(animated: false)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func toggleMiniPlayerView(animated animated: Bool = false) {
        let miniPlayerHeight: CGFloat = 70
        miniPlayerHeightConstraint.constant = miniPlayerHeightConstraint.constant == 0
            ? miniPlayerHeight : 0
        
        if animated {
            UIView.animateWithDuration(0.2) {
                self.view.layoutIfNeeded()
            }
        } else {
            self.view.layoutIfNeeded()
        }
    }
    
    func updateProgressBar(progress: Float) {
        self.progressBarWidthConstraint.constant = self.miniPlayerView.frame.width * CGFloat(progress)
        self.view.layoutIfNeeded()
    }
    
    private func shouldShowMiniPlayer() -> Bool {
        return player.isPlaying() || player.isPaused()
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    func itemDidFinishPlaying(item: PlayerItem, nextItem: PlayerItem?) {
    }
    
    // MARK: MiniPlayer -
    
    func updateMiniPlayer(timer: NSTimer?) {
        print("update mini player")
        if (shouldShowMiniPlayer() && miniPlayerHeightConstraint.constant == 0) ||
            (!shouldShowMiniPlayer() && miniPlayerHeightConstraint.constant > 0) {
            toggleMiniPlayerView()
        }
        
        if player.isPlaying() && player.position > 0 {
            updateProgressBar(player.position)
        }
        
        miniPlayerTitleLabel.text = player.currentItem()?.title
    }
    
    @IBAction func togglePlayPause(sender: AnyObject) {
        if player.isPlaying() {
            player.pause()
        } else {
            player.play()
        }
    }
}
