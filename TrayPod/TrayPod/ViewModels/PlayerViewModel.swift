import SwiftUI
import Combine

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var state: PlayerState = PlayerState()
    @Published var activeServiceName: String = "No Music App"
    @Published var isAdjustingVolume: Bool = false

    private var musicService: MusicServiceProtocol?
    private let connectService = SpotifyConnectService()

    private var cancellables = Set<AnyCancellable>()
    private var progressTimer: Timer?
    private var volumeIdleTimer: Timer?

    /// How long to show volume bar after last adjustment
    private let volumeIdleTimeout: TimeInterval = 1.5

    init() {
        setupStateListener()
        startProgressTimer()
    }

    deinit {
        progressTimer?.invalidate()
        volumeIdleTimer?.invalidate()
    }

    // MARK: - State Listener

    private func setupStateListener() {
        // Subscribe to Connect service state changes (polling-based)
        connectService.stateChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.updateFromService()
            }
            .store(in: &cancellables)
    }

    /// Update state from Connect service
    private func updateFromService() {
        if connectService.isRunning {
            musicService = connectService
            activeServiceName = connectService.serviceName

            state = PlayerState(
                isPlaying: connectService.isPlaying,
                currentTrack: connectService.currentTrack,
                playbackPosition: connectService.playbackPosition,
                volume: connectService.volume
            )
        } else {
            musicService = nil
            activeServiceName = "Connecting..."
            state = PlayerState()
        }
    }

    // MARK: - Progress Timer

    private func startProgressTimer() {
        // Interpolate progress bar every 0.5s between polls
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateProgress()
            }
        }
    }

    private func updateProgress() {
        guard musicService != nil, state.isPlaying else { return }
        state.playbackPosition = connectService.playbackPosition
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        musicService?.togglePlayPause()
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
    }

    func previousTrack() {
        musicService?.previousTrack()
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
