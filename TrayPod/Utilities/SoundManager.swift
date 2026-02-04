import AppKit
import AVFoundation

class SoundManager {
    static let shared = SoundManager()

    private var clickPlayer: AVAudioPlayer?

    private init() {
        setupClickSound()
    }

    private func setupClickSound() {
        // Try to load custom click sound, fallback to system sound
        if let soundURL = Bundle.main.url(forResource: "click", withExtension: "aiff") {
            do {
                clickPlayer = try AVAudioPlayer(contentsOf: soundURL)
                clickPlayer?.prepareToPlay()
                clickPlayer?.volume = 0.3
            } catch {
                print("Failed to load click sound: \(error)")
            }
        }
    }

    func playClick() {
        if let player = clickPlayer {
            // Reset to beginning if already playing
            player.currentTime = 0
            player.play()
        } else {
            // Fallback to system sound
            NSSound.beep()
        }
    }
}
