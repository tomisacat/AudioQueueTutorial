//
//  ViewController.swift
//  AudioQueueTutorial
//
//  Created by tomisacat on 19/04/2017.
//  Copyright © 2017 tomisacat. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var player: AudioQueuePlayer?
    var recorder: AudioQueueRecorder?

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let path = Bundle.main.path(forResource: "guitar", ofType: "m4a") else {
            return
        }
        
        let url = URL(fileURLWithPath: path)
        player = AudioQueuePlayer(url: url)
        
        recorder = AudioQueueRecorder()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func playButtonClicked(sender: UIButton) {
        if player?.playing == true {
            player?.pause()
            sender.setTitle("paused", for: .normal)
        } else {
            player?.play()
            sender.setTitle("playing", for: .normal)
        }
    }
    
    @IBAction func recordButtonClicked(sender: UIButton) {
        if recorder?.isRecording == true {
            recorder?.stop()
            sender.isHidden = true
            Swift.print(recorder?.outputUrl ?? "no output")
        } else {
            recorder?.start()
        }
    }
}

