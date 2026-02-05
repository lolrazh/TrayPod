import Foundation

protocol MusicServiceProtocol: AnyObject {
    var serviceName: String { get }
    var isRunning: Bool { get }
    var isPlaying: Bool { get }
    var currentTrack: Track? { get }
    var playbackPosition: TimeInterval { get }
    var volume: Float { get set }

    func play()
    func pause()
    func togglePlayPause()
    func nextTrack()
    func previousTrack()
    func seek(to position: TimeInterval)
}

extension MusicServiceProtocol {
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
}
