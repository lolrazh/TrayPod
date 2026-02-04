import SwiftUI
import Combine

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var state: PlayerState = PlayerState()
    @Published var activeServiceName: String = "No Music App"

    private var musicService: MusicServiceProtocol?
    private var updateTimer: Timer?
    private let spotifyService = SpotifyService()

    init() {
        startMonitoring()
    }

    deinit {
        updateTimer?.invalidate()
    }

    // MARK: - Monitoring

    func startMonitoring() {
        // Update immediately
        updateState()

        // Then update periodically
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateState()
            }
        }
    }

    func stopMonitoring() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func updateState() {
        // For MVP, just check Spotify
        if spotifyService.isRunning {
            musicService = spotifyService
            activeServiceName = spotifyService.serviceName

            state = PlayerState(
                isPlaying: spotifyService.isPlaying,
                currentTrack: spotifyService.currentTrack,
                playbackPosition: spotifyService.playbackPosition,
                volume: spotifyService.volume
            )
        } else {
            musicService = nil
            activeServiceName = "No Music App"
            state = PlayerState()
        }
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        musicService?.togglePlayPause()
        // Update state immediately for responsiveness
        state.isPlaying.toggle()
    }

    func play() {
        musicService?.play()
        state.isPlaying = true
    }

    func pause() {
        musicService?.pause()
        state.isPlaying = false
    }

    func nextTrack() {
        musicService?.nextTrack()
        // State will update on next timer tick
    }

    func previousTrack() {
        musicService?.previousTrack()
        // State will update on next timer tick
    }

    func seek(to position: TimeInterval) {
        musicService?.seek(to: position)
        state.playbackPosition = position
    }

    func adjustVolume(by delta: Float) {
        guard let service = musicService else { return }
        let newVolume = max(0, min(1, service.volume + delta))
        service.volume = newVolume
        state.volume = newVolume
    }

    func setVolume(_ volume: Float) {
        guard let service = musicService else { return }
        let clampedVolume = max(0, min(1, volume))
        service.volume = clampedVolume
        state.volume = clampedVolume
    }

    // MARK: - Helpers

    var hasActiveService: Bool {
        musicService != nil
    }

    var canControl: Bool {
        musicService?.isRunning ?? false
    }
}
