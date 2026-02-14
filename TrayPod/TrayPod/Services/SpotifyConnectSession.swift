import Foundation

/// Manages the Spotify Connect session: WebSocket connection ID retrieval,
/// virtual device registration, and session lifecycle (auto re-register before TTL).
class SpotifyConnectSession {

    // MARK: - Types

    enum ConnectError: Error, LocalizedError {
        case connectionIdNotFound
        case registrationFailed(String)
        case noTokens

        var errorDescription: String? {
            switch self {
            case .connectionIdNotFound: return "Failed to get Spotify connection ID from dealer"
            case .registrationFailed(let msg): return "Device registration failed: \(msg)"
            case .noTokens: return "No valid tokens for Connect session"
            }
        }
    }

    // MARK: - Constants

    private let dealerURL = "wss://dealer.spotify.com/"
    private let trackPlaybackBase = "https://gue1-spclient.spotify.com/track-playback/v1"
    private let clientVersion = "harmony:4.43.2-a61ecaf5"
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    /// Re-register 1 minute before the 10-minute TTL
    private let registrationTTL: TimeInterval = 9 * 60

    // MARK: - State

    let tokenManager: SpotifyTokenManager
    private(set) var connectionId: String?
    private var registrationTimestamp: Date?

    /// Persistent device ID (32-char hex, generated once)
    let deviceId: String

    // MARK: - Init

    init(tokenManager: SpotifyTokenManager) {
        self.tokenManager = tokenManager
        self.deviceId = Self.loadOrGenerateDeviceId()
    }

    /// Whether the current session registration is still valid
    var isSessionValid: Bool {
        guard connectionId != nil, let timestamp = registrationTimestamp else { return false }
        return Date().timeIntervalSince(timestamp) < registrationTTL
    }

    /// Ensure we have a valid registered session, re-registering if needed
    func ensureSession() async throws {
        if isSessionValid { return }
        try await registerDevice()
    }

    /// Force a new session (e.g., after token refresh)
    func refreshSession() async throws {
        connectionId = nil
        registrationTimestamp = nil
        try await registerDevice()
    }

    // MARK: - Connection ID (WebSocket)

    private func getConnectionId(accessToken: String) async throws -> String {
        let urlString = "\(dealerURL)?access_token=\(accessToken)"
        guard let url = URL(string: urlString) else {
            throw ConnectError.connectionIdNotFound
        }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let task = URLSession.shared.webSocketTask(with: request)
        task.resume()

        defer { task.cancel(with: .normalClosure, reason: nil) }

        // Read first message — contains connection ID in headers
        let message = try await task.receive()

        let data: Data
        switch message {
        case .string(let text):
            guard let d = text.data(using: .utf8) else { throw ConnectError.connectionIdNotFound }
            data = d
        case .data(let d):
            data = d
        @unknown default:
            throw ConnectError.connectionIdNotFound
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let headers = json["headers"] as? [String: Any] else {
            throw ConnectError.connectionIdNotFound
        }

        // Case-insensitive search for Spotify-Connection-Id (matches Spogo behavior)
        for (key, value) in headers {
            if key.lowercased() == "spotify-connection-id",
               let id = value as? String, !id.isEmpty {
                print("[ConnectSession] Got connection ID: \(id.prefix(20))...")
                return id
            }
        }

        throw ConnectError.connectionIdNotFound
    }

    // MARK: - Device Registration

    private func registerDevice() async throws {
        let tokens = try await tokenManager.getTokens()
        let connId = try await getConnectionId(accessToken: tokens.accessToken)

        let url = URL(string: "\(trackPlaybackBase)/devices")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("WebPlayer", forHTTPHeaderField: "app-platform")
        request.setValue(clientVersion, forHTTPHeaderField: "Spotify-App-Version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        // Include client token if available
        if let clientToken = tokens.clientToken {
            request.setValue(clientToken, forHTTPHeaderField: "Client-Token")
        }

        let body: [String: Any] = [
            "device": [
                "device_id": deviceId,
                "device_type": "computer",
                "brand": "spotify",
                "model": "web_player",
                "name": "TrayPod",
                "is_group": false,
                "metadata": [String: String](),
                "platform_identifier": "web_player darwin;TrayPod",
                "capabilities": [
                    "change_volume": true,
                    "supports_file_media_type": true,
                    "enable_play_token": true,
                    "play_token_lost_behavior": "pause",
                    "disable_connect": false,
                    "audio_podcasts": true,
                    "video_playback": true,
                    "manifest_formats": [
                        "file_ids_mp3",
                        "file_urls_mp3",
                        "file_ids_mp4",
                        "manifest_ids_video"
                    ]
                ] as [String: Any]
            ] as [String: Any],
            "outro_endcontent_snooping": false,
            "connection_id": connId,
            "client_version": clientVersion,
            "volume": 65535
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ConnectError.registrationFailed("No HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "no body"
            throw ConnectError.registrationFailed("HTTP \(httpResponse.statusCode): \(responseBody)")
        }

        connectionId = connId
        registrationTimestamp = Date()
        print("[ConnectSession] Device registered (id: \(deviceId.prefix(8))...)")
    }

    // MARK: - Device ID Persistence

    private static let deviceIdKey = "SpotifyConnectDeviceId"

    private static func loadOrGenerateDeviceId() -> String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey) {
            return existing
        }
        // Generate 32-char random hex string
        let newId = (0..<32).map { _ in
            String(format: "%x", Int.random(in: 0...15))
        }.joined()
        UserDefaults.standard.set(newId, forKey: deviceIdKey)
        print("[ConnectSession] Generated new device ID: \(newId)")
        return newId
    }
}
