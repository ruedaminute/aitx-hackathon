//
//  SoundManager.swift
//  AppWarmr
//
//  Created by Michelle Rueda on 2/28/25.
//

import Foundation
import AVFoundation

struct SoundManager {
    static var audioPlayer: AVAudioPlayer?
    
    static func playSound(fileName: String) {
        do {
            // Configure and activate audio session
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            
            guard let path = Bundle.main.path(forResource: fileName, ofType: "m4a") else {
                print("Could not find sound file: \(fileName)")
                return
            }
            
            let url = URL(fileURLWithPath: path)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 1.0  // Ensure volume is up
            audioPlayer?.prepareToPlay()  // Buffer the audio
            audioPlayer?.play()
            // print("playing sound file: \(url.description)")
        } catch {
            print("Could not play sound file: \(error.localizedDescription)")
        }
    }
}
