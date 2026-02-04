import Foundation
import AppKit

class SpotifyService: MusicServiceProtocol {
    let serviceName = "Spotify"

    var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.spotify.client"
        }
    }

    var isPlaying: Bool {
        guard isRunning else { return false }
        let script = """
            tell application "Spotify"
                return player state is playing
            end tell
        """
        return executeAppleScript(script) == "true"
    }

    var currentTrack: Track? {
        guard isRunning else { return nil }
        let script = """
            tell application "Spotify"
                if player state is stopped then
                    return ""
                end if
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set trackDuration to duration of current track
                return trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & trackDuration
            end tell
        """

        guard let result = executeAppleScript(script), !result.isEmpty else {
            return nil
        }

        let components = result.components(separatedBy: "|||")
        guard components.count >= 4 else { return nil }

        let title = components[0]
        let artist = components[1]
        let album = components[2]
        // Spotify duration is in milliseconds
        let durationMs = Double(components[3]) ?? 0
        let duration = durationMs / 1000.0

        return Track(title: title, artist: artist, album: album, duration: duration)
    }

    var playbackPosition: TimeInterval {
        guard isRunning else { return 0 }
        let script = """
            tell application "Spotify"
                return player position
            end tell
        """
        guard let result = executeAppleScript(script) else { return 0 }
        return Double(result) ?? 0
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
