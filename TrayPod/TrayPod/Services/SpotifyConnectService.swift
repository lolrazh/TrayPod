import Foundation
import Combine

/// Spotify playback control via Connect API — no Spotify.app required.
/// Replaces the AppleScript-based SpotifyService.
class SpotifyConnectService: MusicServiceProtocol {

    let serviceName = "Spotify"

    // MARK: - Auth & Session

    private let tokenManager = SpotifyTokenManager()
    private lazy var connectSession = SpotifyConnectSession(tokenManager: tokenManager)

    // MARK: - Constants

    private let connectStateBase = "https://gue1-spclient.spotify.com/connect-state/v1"
    private let clientVersion = "harmony:4.43.2-a61ecaf5"
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    private let pollInterval: TimeInterval = 3.0

    // MARK: - Cached State

    private var _isPlaying = false
    private var _currentTrack: Track?
    private var _playbackPosition: TimeInterval = 0
    private var _volume: Float = 0.5
    private var _activeDeviceId: String?
    private var _originDeviceId: String?
    private var _isAuthenticated = false
    private var lastUpdateTime = Date.distantPast

    // MARK: - Combine

    private let stateChangedSubject = PassthroughSubject<Void, Never>()
    var stateChanged: AnyPublisher<Void, Never> {
        stateChangedSubject.eraseToAnyPublisher()
    }

    // MARK: - Polling

    private var pollTimer: Timer?

    // MARK: - Protocol Properties

    var isRunning: Bool { _isAuthenticated }

    var isPlaying: Bool { _isPlaying }

    var currentTrack: Track? { _currentTrack }

    /// Interpolated playback position between polls
    var playbackPosition: TimeInterval {
        guard _isPlaying else { return _playbackPosition }
        let elapsed = Date().timeIntervalSince(lastUpdateTime)
        let duration = _currentTrack?.duration ?? .greatestFiniteMagnitude
        return min(_playbackPosition + elapsed, duration)
    }

    var volume: Float {
        get { _volume }
        set {
            let clamped = max(0, min(1, newValue))
            _volume = clamped
            Task { [weak self] in
                await self?.sendVolumeCommand(clamped)
            }
        }
    }

    // MARK: - Init

    init() {
        startPolling()
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Polling

    private func startPolling() {
        // Initial poll
        Task { [weak self] in
            await self?.poll()
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.poll()
            }
        }
    }

    private func poll() async {
        do {
            try await connectSession.ensureSession()

            let tokens = try await tokenManager.getTokens()
            _isAuthenticated = true

            let state = try await fetchConnectState(tokens: tokens)
            await MainActor.run { [weak self] in
                self?.applyState(state)
            }
        } catch {
            if !_isAuthenticated {
                print("[ConnectService] Auth pending: \(error.localizedDescription)")
            } else {
                print("[ConnectService] Poll error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Connect State Fetch

    private struct ConnectState {
        var isPaused: Bool = true
        var positionMs: Int = 0
        var track: Track?
        var activeDeviceId: String?
        var originDeviceId: String?
        var volume: Float = 0.5
    }

    private func fetchConnectState(tokens: SpotifyTokenManager.Tokens) async throws -> ConnectState {
        let deviceId = connectSession.deviceId
        let url = URL(string: "\(connectStateBase)/devices/hobs_\(deviceId)")!

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("WebPlayer", forHTTPHeaderField: "app-platform")
        request.setValue(clientVersion, forHTTPHeaderField: "Spotify-App-Version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        if let clientToken = tokens.clientToken {
            request.setValue(clientToken, forHTTPHeaderField: "Client-Token")
        }
        if let connectionId = connectSession.connectionId {
            request.setValue(connectionId, forHTTPHeaderField: "x-spotify-connection-id")
        }

        let body: [String: Any] = [
            "member_type": "CONNECT_STATE",
            "device": [
                "device_info": [
                    "capabilities": [
                        "can_be_player": false,
                        "hidden": true,
                        "needs_full_player_state": true
                    ]
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "ConnectService", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "State fetch failed: HTTP \(statusCode)"])
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "ConnectService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        }

        return parseConnectState(json)
    }

    // MARK: - State Parsing

    private func parseConnectState(_ json: [String: Any]) -> ConnectState {
        var state = ConnectState()

        // Active device ID
        state.activeDeviceId = json["active_device_id"] as? String

        // Player state
        if let playerState = json["player_state"] as? [String: Any] {
            // Paused / playing
            if let isPaused = playerState["is_paused"] as? Bool {
                state.isPaused = isPaused
            } else if let isPlaying = playerState["is_playing"] as? Bool {
                state.isPaused = !isPlaying
            }

            // Position (milliseconds)
            if let pos = playerState["position_as_of_timestamp"] as? Int {
                state.positionMs = pos
            } else if let pos = playerState["position_ms"] as? Int {
                state.positionMs = pos
            }

            // Play origin device
            if let playOrigin = playerState["play_origin"] as? [String: Any],
               let originDevice = playOrigin["device_identifier"] as? String {
                state.originDeviceId = originDevice
            }

            // Track info — try "track", "item", or "current_track"
            let trackDict = playerState["track"] as? [String: Any]
                ?? playerState["item"] as? [String: Any]
                ?? playerState["current_track"] as? [String: Any]

            if let trackDict = trackDict {
                state.track = parseTrack(trackDict)
            }
        }

        // Volume from active device
        if let devices = json["devices"] as? [String: Any] {
            let activeVolume = findActiveDeviceVolume(devices: devices, activeId: state.activeDeviceId)
            if let vol = activeVolume {
                state.volume = vol
            }
        }

        return state
    }

    private func parseTrack(_ dict: [String: Any]) -> Track {
        let uri = dict["uri"] as? String ?? ""
        let name = dict["name"] as? String ?? "Unknown"

        // Artists: array of objects with "name"
        var artistName = ""
        if let artists = dict["artists"] as? [[String: Any]] {
            artistName = artists.compactMap { $0["name"] as? String }.joined(separator: ", ")
        }

        // Album: object with "name"
        var albumName = ""
        if let album = dict["album"] as? [String: Any] {
            albumName = album["name"] as? String ?? ""
        } else if let album = dict["albumOfTrack"] as? [String: Any] {
            albumName = album["name"] as? String ?? ""
        }

        // Duration in milliseconds
        var durationMs = 0
        if let d = dict["duration_ms"] as? Int {
            durationMs = d
        } else if let d = dict["durationMs"] as? Int {
            durationMs = d
        }

        return Track(
            id: uri,
            title: name,
            artist: artistName,
            album: albumName,
            duration: TimeInterval(durationMs) / 1000.0
        )
    }

    private func findActiveDeviceVolume(devices: [String: Any], activeId: String?) -> Float? {
        // Try active device first
        if let activeId = activeId, let device = devices[activeId] as? [String: Any] {
            return extractVolume(from: device)
        }

        // Fallback: find any active device
        for (_, deviceAny) in devices {
            guard let device = deviceAny as? [String: Any] else { continue }
            let isActive = (device["is_active"] as? Bool ?? false)
                || (device["is_active_device"] as? Bool ?? false)
                || (device["is_currently_playing"] as? Bool ?? false)
            if isActive, let vol = extractVolume(from: device) {
                return vol
            }
        }

        return nil
    }

    private func extractVolume(from device: [String: Any]) -> Float? {
        // volume is 0-65535
        if let vol = device["volume"] as? Int {
            return Float(vol) / 65535.0
        }
        // volume_percent is 0-100
        if let pct = device["volume_percent"] as? Int {
            return Float(pct) / 100.0
        }
        return nil
    }

    // MARK: - Apply State

    private func applyState(_ newState: ConnectState) {
        let trackChanged = _currentTrack?.id != newState.track?.id
        let playStateChanged = _isPlaying != !newState.isPaused

        _isPlaying = !newState.isPaused
        _playbackPosition = TimeInterval(newState.positionMs) / 1000.0
        _currentTrack = newState.track
        _activeDeviceId = newState.activeDeviceId
        _originDeviceId = newState.originDeviceId
        _volume = newState.volume
        lastUpdateTime = Date()

        if trackChanged || playStateChanged {
            stateChangedSubject.send()
        }
    }

    // MARK: - Playback Controls

    func play() {
        _isPlaying = true
        sendCommand("resume")
    }

    func pause() {
        _isPlaying = false
        sendCommand("pause")
    }

    func togglePlayPause() {
        if _isPlaying {
            pause()
        } else {
            play()
        }
    }

    func nextTrack() {
        sendCommand("skip_next")
    }

    func previousTrack() {
        sendCommand("skip_prev")
    }

    func seek(to position: TimeInterval) {
        _playbackPosition = position
        lastUpdateTime = Date()
        let posMs = max(0, Int(position * 1000))
        sendCommand("seek_to", extraFields: ["value": posMs])
    }

    /// Play a specific track URI (protocol method)
    func playTrack(uri: String) {
        sendCommand("play", extraFields: [
            "options": ["skip_to": ["track_uri": uri]]
        ])
    }

    /// Play a context (album/playlist) URI (protocol method)
    func playContext(uri: String) {
        sendCommand("play", extraFields: [
            "context": ["uri": uri]
        ])
    }

    // MARK: - Command Sending

    private func sendCommand(_ endpoint: String, extraFields: [String: Any] = [:]) {
        Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.connectSession.ensureSession()
                let tokens = try await self.tokenManager.getTokens()

                let fromId = self._originDeviceId ?? self.connectSession.deviceId
                guard let toId = self._activeDeviceId else {
                    print("[ConnectService] No active device for command")
                    return
                }

                let url = URL(string: "\(self.connectStateBase)/player/command/from/\(fromId)/to/\(toId)")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("WebPlayer", forHTTPHeaderField: "app-platform")
                request.setValue(self.clientVersion, forHTTPHeaderField: "Spotify-App-Version")
                request.setValue(self.userAgent, forHTTPHeaderField: "User-Agent")
                if let clientToken = tokens.clientToken {
                    request.setValue(clientToken, forHTTPHeaderField: "Client-Token")
                }

                let commandId = Self.randomHex(32)
                var command: [String: Any] = [
                    "endpoint": endpoint,
                    "logging_params": ["command_id": commandId]
                ]
                for (key, value) in extraFields {
                    command[key] = value
                }

                let body: [String: Any] = ["command": command]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (_, response) = try await URLSession.shared.data(for: request)
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                if !(200...299).contains(statusCode) {
                    print("[ConnectService] Command '\(endpoint)' failed: HTTP \(statusCode)")
                }
            } catch {
                print("[ConnectService] Command '\(endpoint)' error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Volume Command

    private func sendVolumeCommand(_ value: Float) async {
        do {
            try await connectSession.ensureSession()
            let tokens = try await tokenManager.getTokens()

            let fromId = _originDeviceId ?? connectSession.deviceId
            guard let toId = _activeDeviceId else {
                print("[ConnectService] No active device for volume")
                return
            }

            let url = URL(string: "\(connectStateBase)/connect/volume/from/\(fromId)/to/\(toId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("WebPlayer", forHTTPHeaderField: "app-platform")
            request.setValue(clientVersion, forHTTPHeaderField: "Spotify-App-Version")
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            if let clientToken = tokens.clientToken {
                request.setValue(clientToken, forHTTPHeaderField: "Client-Token")
            }

            let apiVolume = Int(value * 65535)
            let body: [String: Any] = ["volume": apiVolume]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (_, response) = try await URLSession.shared.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            if !(200...299).contains(statusCode) {
                print("[ConnectService] Volume command failed: HTTP \(statusCode)")
            }
        } catch {
            print("[ConnectService] Volume error: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers

    private static func randomHex(_ length: Int) -> String {
        (0..<length).map { _ in String(format: "%x", Int.random(in: 0...15)) }.joined()
    }
}
