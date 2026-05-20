import SwiftUI
import Combine
import AppKit

@MainActor
class PlayerViewModel: ObservableObject {
    @Published var state: PlayerState = PlayerState(volume: PersistenceManager.shared.playerVolume)
    @Published var activeServiceName: String = "No Music App"
    @Published var isAdjustingVolume: Bool = false

    private var musicService: MusicServiceProtocol?
    private let spotifyService = SpotifyService()

    private var cancellables = Set<AnyCancellable>()
    private var progressTimer: Timer?
    private var volumeIdleTimer: Timer?

    /// How long to show volume bar after last adjustment
    private let volumeIdleTimeout: TimeInterval = 1.5

    init() {
        setupNotificationListener()
        setupApplicationLifecycleListener()
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
            state = PlayerState(volume: PersistenceManager.shared.playerVolume)
        }
    }

    private func setupApplicationLifecycleListener() {
        let notificationCenter = NSWorkspace.shared.notificationCenter

        notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .merge(with: notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshServiceAvailability()
            }
            .store(in: &cancellables)
    }

    private func refreshServiceAvailability() {
        spotifyService.refreshState()
        updateFromService()
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
        guard let musicService else {
            openPreferredPlayer()
            return
        }

        musicService.togglePlayPause()
        // Update state immediately for responsiveness
        state.isPlaying.toggle()
    }

    func play() {
        guard let musicService else {
            openPreferredPlayer()
            return
        }

        musicService.play()
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
        PersistenceManager.shared.playerVolume = newVolume

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
        PersistenceManager.shared.playerVolume = clampedVolume
    }

    func playSpotifyURI(_ uri: String, isContext: Bool) {
        Task { @MainActor [weak self] in
            guard let self else { return }

            if SpotifyAuthManager.shared.isSignedIn {
                do {
                    try await SpotifyAPIClient.shared.startPlayback(uri: uri, isContext: isContext)
                    return
                } catch {
                    // Fall back to desktop Spotify below.
                }
            }

            if spotifyService.isRunning {
                spotifyService.play(uri: uri)
                musicService = spotifyService
                activeServiceName = spotifyService.serviceName
            } else {
                openPreferredPlayer()
            }
        }
    }

    func openPreferredPlayer() {
        if let spotifyURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") {
            NSWorkspace.shared.open(spotifyURL)
        } else if let webURL = URL(string: "https://open.spotify.com") {
            NSWorkspace.shared.open(webURL)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshServiceAvailability()
        }
    }

    // MARK: - Helpers

    var hasActiveService: Bool {
        musicService != nil
    }

    var canControl: Bool {
        musicService?.isRunning ?? false
    }

    var idleInstruction: String {
        hasActiveService ? "Press Play to start" : "Press Play to open Spotify"
    }
}
