import Foundation

struct PlayerState: Equatable {
    var isPlaying: Bool
    var currentTrack: Track?
    var playbackPosition: TimeInterval
    var volume: Float // 0.0 to 1.0

    init(isPlaying: Bool = false, currentTrack: Track? = nil, playbackPosition: TimeInterval = 0, volume: Float = 0.5) {
        self.isPlaying = isPlaying
        self.currentTrack = currentTrack
        self.playbackPosition = playbackPosition
        self.volume = volume
    }

    var progress: Double {
        guard let track = currentTrack, track.duration > 0 else { return 0 }
        return playbackPosition / track.duration
    }

    var remainingTime: TimeInterval {
        guard let track = currentTrack else { return 0 }
        return max(0, track.duration - playbackPosition)
    }
}
