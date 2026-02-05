import SwiftUI
import Combine

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var state: PlayerState = PlayerState()
    @Published var activeServiceName: String = "No Music App"

    private var musicService: MusicServiceProtocol?
    private let spotifyService = SpotifyService()

    private var cancellables = Set<AnyCancellable>()
    private var progressTimer: Timer?

    init() {
        setupNotificationListener()
        startProgressTimer()
        checkInitialState()
    }

    deinit {
        progressTimer?.invalidate()
    }

    // MARK: - Real-time Notification Listener

    private func setupNotificationListener() {
        // Subscribe to Spotify's real-time state changes
        spotifyService.stateChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.updateFromService()
            }
            .store(in: &cancellables)
    }

    private func checkInitialState() {
        // Check if Spotify is running on launch
        if spotifyService.isRunning {
            updateFromService()
        }
    }

    /// Update state from service (called on notifications)
    private func updateFromService() {
        if spotifyService.isRunning {
            musicService = spotifyService
            activeServiceName = spotifyService.serviceName

            state = PlayerState(
                isPlaying: spotifyService.isPlaying,
                currentTrack: spotifyService.currentTrack,
                playbackPosition: spotifyService.playbackPosition,
                volume: state.volume // Keep current volume (don't query)
            )
        } else {
            musicService = nil
            activeServiceName = "No Music App"
            state = PlayerState()
        }
    }

    // MARK: - Progress Timer (lightweight, no AppleScript)

    private func startProgressTimer() {
        // Update progress bar every 0.5s by interpolating locally
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateProgress()
            }
        }
    }

    private func updateProgress() {
        guard musicService != nil, state.isPlaying else { return }
        // Get interpolated position (no AppleScript call)
        state.playbackPosition = spotifyService.playbackPosition
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
        // State will update via notification
    }

    func previousTrack() {
        musicService?.previousTrack()
        // State will update via notification
    }

    func seek(to position: TimeInterval) {
        musicService?.seek(to: position)
        state.playbackPosition = position
    }

    func adjustVolume(by delta: Float) {
        guard let service = musicService else { return }
        let newVolume = max(0, min(1, state.volume + delta))
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
