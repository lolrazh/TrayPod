import Foundation
import AppKit
import Combine

class SpotifyService: MusicServiceProtocol {
    let serviceName = "Spotify"

    // MARK: - Real-time State (from notifications)

    private var _isPlaying: Bool = false
    private var _currentTrack: Track?
    private var _playbackPosition: TimeInterval = 0
    private var _duration: TimeInterval = 0
    private var lastUpdateTime: Date = .distantPast

    // Publisher for state changes
    private let stateChangedSubject = PassthroughSubject<Void, Never>()
    var stateChanged: AnyPublisher<Void, Never> {
        stateChangedSubject.eraseToAnyPublisher()
    }

    // MARK: - Protocol Properties

    var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.spotify.client"
        }
    }

    var isPlaying: Bool {
        _isPlaying
    }

    var currentTrack: Track? {
        _currentTrack
    }

    /// Returns interpolated playback position (no AppleScript call)
    var playbackPosition: TimeInterval {
        guard _isPlaying else { return _playbackPosition }
        let elapsed = Date().timeIntervalSince(lastUpdateTime)
        return min(_playbackPosition + elapsed, _duration)
    }

    var volume: Float {
        get {
            guard isRunning else { return 0.5 }
            let script = """
                tell application "Spotify"
                    return sound volume
                end tell
            """
            guard let result = executeAppleScript(script) else { return 0.5 }
            return Float(Double(result) ?? 50) / 100.0
        }
        set {
            guard isRunning else { return }
            let volumePercent = Int(newValue * 100)
            let script = """
                tell application "Spotify"
                    set sound volume to \(volumePercent)
                end tell
            """
            _ = executeAppleScript(script)
        }
    }

    // MARK: - Initialization

    init() {
        setupNotificationObserver()
        // Fetch initial state if Spotify is running
        if isRunning {
            fetchInitialState()
        }
    }

    private func setupNotificationObserver() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handlePlaybackStateChanged(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    @objc private func handlePlaybackStateChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }

        // Parse player state
        let playerState = userInfo["Player State"] as? String ?? "Unknown"
        _isPlaying = (playerState == "Playing")

        // Parse track info
        let trackName = userInfo["Name"] as? String
        let artist = userInfo["Artist"] as? String
        let album = userInfo["Album"] as? String

        // Duration comes in milliseconds
        let durationMs = userInfo["Duration"] as? Int ?? 0
        _duration = TimeInterval(durationMs) / 1000.0

        // Playback position comes in seconds (as Double or Int)
        if let position = userInfo["Playback Position"] as? Double {
            _playbackPosition = position
        } else if let position = userInfo["Playback Position"] as? Int {
            _playbackPosition = TimeInterval(position)
        }

        // Update track if we have a name
        if let name = trackName, !name.isEmpty {
            // Fetch artwork URL asynchronously (notifications don't include it)
            let artworkURL = fetchArtworkURL()
            _currentTrack = Track(
                title: name,
                artist: artist ?? "",
                album: album ?? "",
                duration: _duration,
                artworkURL: artworkURL
            )
        } else if playerState == "Stopped" {
            _currentTrack = nil
        }

        // Record update time for interpolation
        lastUpdateTime = Date()

        // Notify listeners
        stateChangedSubject.send()
    }

    /// Fetch initial state via AppleScript (only called once on init)
    private func fetchInitialState() {
        let script = """
            tell application "Spotify"
                if player state is stopped then
                    return "stopped|||||||0|||0"
                end if
                set playerState to player state as string
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set trackDuration to duration of current track
                set pos to player position
                return playerState & "|||" & trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & trackDuration & "|||" & pos
            end tell
        """

        guard let result = executeAppleScript(script), !result.isEmpty else { return }

        let components = result.components(separatedBy: "|||")
        guard components.count >= 6 else { return }

        let playerState = components[0]
        _isPlaying = playerState.contains("playing")

        let trackName = components[1]
        let artist = components[2]
        let album = components[3]
        let durationMs = Double(components[4]) ?? 0
        _duration = durationMs / 1000.0
        _playbackPosition = Double(components[5]) ?? 0

        if !trackName.isEmpty {
            let artworkURL = fetchArtworkURL()
            _currentTrack = Track(
                title: trackName,
                artist: artist,
                album: album,
                duration: _duration,
                artworkURL: artworkURL
            )
        }

        lastUpdateTime = Date()
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    // MARK: - Artwork

    /// Fetch artwork URL via AppleScript
    private func fetchArtworkURL() -> URL? {
        guard isRunning else { return nil }
        let script = """
            tell application "Spotify"
                return artwork url of current track
            end tell
        """
        guard let urlString = executeAppleScript(script), !urlString.isEmpty else { return nil }
        return URL(string: urlString)
    }

    // MARK: - Playback Controls (AppleScript)

    func play() {
        guard isRunning else { return }
        let script = """
            tell application "Spotify"
                play
            end tell
        """
        _ = executeAppleScript(script)
    }

    func pause() {
        guard isRunning else { return }
        let script = """
            tell application "Spotify"
                pause
            end tell
        """
        _ = executeAppleScript(script)
    }

    func togglePlayPause() {
        guard isRunning else { return }
        let script = """
            tell application "Spotify"
                playpause
            end tell
        """
        _ = executeAppleScript(script)
    }

    func nextTrack() {
        guard isRunning else { return }
        let script = """
            tell application "Spotify"
                next track
            end tell
        """
        _ = executeAppleScript(script)
    }

    func previousTrack() {
        guard isRunning else { return }
        let script = """
            tell application "Spotify"
                previous track
            end tell
        """
        _ = executeAppleScript(script)
    }

    func seek(to position: TimeInterval) {
        guard isRunning else { return }
        _playbackPosition = position
        lastUpdateTime = Date()
        let script = """
            tell application "Spotify"
                set player position to \(position)
            end tell
        """
        _ = executeAppleScript(script)
    }

    // MARK: - AppleScript Execution

    private func executeAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)

        if let error = error {
            print("AppleScript error: \(error)")
            return nil
        }

        return result.stringValue
    }
}
