import SwiftUI
import Combine

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var state: PlayerState = PlayerState()
    @Published var activeServiceName: String = "No Music App"
    @Published var isAdjustingVolume: Bool = false

    private var musicService: MusicServiceProtocol?
    private let spotifyService = SpotifyService()

    private var cancellables = Set<AnyCancellable>()
    private var progressTimer: Timer?
    private var volumeIdleTimer: Timer?
    private var progressSyncCounter = 0

    /// How long to show volume bar after last adjustment
    private let volumeIdleTimeout: TimeInterval = 1.5

    init() {
        setupNotificationListener()
        startProgressTimer()
        checkInitialState()
    }

    deinit {
        progressTimer?.invalidate()
        volumeIdleTimer?.invalidate()
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
        guard musicService != nil, state.isPlaying else {
            progressSyncCounter = 0
            return
        }

        progressSyncCounter += 1

        // Every 2 seconds (4 × 0.5s), verify position via AppleScript
        // to catch seeks in Spotify that don't fire a notification.
        if progressSyncCounter % 4 == 0 {
            if let actual = spotifyService.currentPlayerPosition() {
                let interpolated = spotifyService.playbackPosition
                if abs(actual - interpolated) > 2.0 {
                    spotifyService.correctPosition(to: actual)
                }
            }
        }

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

        // Show volume bar and reset idle timer
        showVolumeOverlay()
    }

    /// Show the volume bar overlay and schedule auto-hide
    private func showVolumeOverlay() {
        isAdjustingVolume = true
        resetVolumeIdleTimer()
    }

    /// Reset the timer that hides the volume bar after idle
    private func resetVolumeIdleTimer() {
        volumeIdleTimer?.invalidate()
        volumeIdleTimer = Timer.scheduledTimer(withTimeInterval: volumeIdleTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isAdjustingVolume = false
            }
        }
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
