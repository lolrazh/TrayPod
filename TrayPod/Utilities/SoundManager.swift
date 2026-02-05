import AppKit
import AVFoundation

enum SoundType: String, CaseIterable {
    case wheelClick = "Click"           // Wheel scroll tick
    case buttonClick = "ButtonClickDown" // Button press

    var filename: String { rawValue }
    var fileExtension: String { "mp3" }
}

class SoundManager {
    static let shared = SoundManager()

    // Pre-loaded audio players for low-latency playback
    private var players: [SoundType: AVAudioPlayer] = [:]

    // Volume control (0.0 to 1.0)
    var volume: Float = 0.7 {
        didSet {
            players.values.forEach { $0.volume = volume }
        }
    }

    private init() {
        preloadSounds()
    }

    // MARK: - Sound Loading

    private func preloadSounds() {
        for soundType in SoundType.allCases {
            if let player = loadSound(soundType) {
                players[soundType] = player
            }
        }
    }

    private func loadSound(_ type: SoundType) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(
            forResource: type.filename,
            withExtension: type.fileExtension
        ) else {
            print("SoundManager: Could not find sound file: \(type.filename).\(type.fileExtension)")
            return nil
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.volume = volume
            return player
        } catch {
            print("SoundManager: Failed to load sound \(type.filename): \(error)")
            return nil
        }
    }

    // MARK: - Playback

    func play(_ type: SoundType) {
        guard let player = players[type] else {
            // Try to reload the sound if not available
            if let newPlayer = loadSound(type) {
                players[type] = newPlayer
                newPlayer.play()
            }
            return
        }

        // Reset to beginning if already playing
        if player.isPlaying {
            player.currentTime = 0
        }
        player.play()
    }

    // Convenience methods
    func playClick() {
        play(.wheelClick)
    }

    func playButtonClick() {
        play(.buttonClick)
    }
}
