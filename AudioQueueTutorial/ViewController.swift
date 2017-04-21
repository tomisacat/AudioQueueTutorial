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

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let path = Bundle.main.path(forResource: "guitar", ofType: "m4a") else {
            return
        }
        
        let url = URL(fileURLWithPath: path)
        player = AudioQueuePlayer(url: url)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func playButtonClicked() {
        if player?.playing == true {
            player?.pause()
        } else {
            player?.play()
        }
    }
}

