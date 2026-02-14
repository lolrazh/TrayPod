import Foundation

/// Manages Spotify authentication tokens: extracts cookies from Chrome, generates TOTP,
/// exchanges for access + client tokens, and handles caching/refresh.
actor SpotifyTokenManager {

    // MARK: - Types

    struct Tokens {
        let accessToken: String
        let clientId: String
        let expiresAt: Date
        let clientToken: String?
        let clientTokenExpiresAt: Date?
    }

    enum AuthError: Error, LocalizedError {
        case noCookies
        case tokenExchangeFailed(String)
        case clientTokenFailed(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .noCookies: return "No Spotify cookies available"
            case .tokenExchangeFailed(let msg): return "Token exchange failed: \(msg)"
            case .clientTokenFailed(let msg): return "Client token failed: \(msg)"
            case .invalidResponse: return "Invalid server response"
            }
        }
    }

    // MARK: - State

    private var cachedTokens: Tokens?
    private var spDc: String?
    private var spT: String?

    /// Refresh 1 minute before actual expiry
    private let expiryBuffer: TimeInterval = 60

    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    // MARK: - Public API

    /// Get a valid access token, refreshing if needed
    func getAccessToken() async throws -> String {
        if let tokens = cachedTokens, tokens.expiresAt.timeIntervalSinceNow > expiryBuffer {
            return tokens.accessToken
        }

        let tokens = try await refreshTokens()
        return tokens.accessToken
    }

    /// Get both access token and client token
    func getTokens() async throws -> Tokens {
        if let tokens = cachedTokens, tokens.expiresAt.timeIntervalSinceNow > expiryBuffer {
            return tokens
        }

        return try await refreshTokens()
    }

    /// Get the client ID (available after first token exchange)
    func getClientId() async throws -> String {
        let tokens = try await getTokens()
        return tokens.clientId
    }

    /// Force refresh tokens
    @discardableResult
    func refreshTokens() async throws -> Tokens {
        try await ensureCookies()

        guard let spDc = spDc else {
            throw AuthError.noCookies
        }

        // Generate TOTP
        let totp = try await TOTPGenerator.generate()

        // Exchange for access token
        let (accessToken, clientId, expiresAt) = try await exchangeToken(spDc: spDc, totp: totp)

        // Get client token (non-fatal if it fails)
        let (clientToken, clientTokenExpiresAt) = await getClientToken(clientId: clientId)

        let tokens = Tokens(
            accessToken: accessToken,
            clientId: clientId,
            expiresAt: expiresAt,
            clientToken: clientToken,
            clientTokenExpiresAt: clientTokenExpiresAt
        )

        cachedTokens = tokens
        print("[SpotifyTokenManager] Tokens refreshed, expires at \(expiresAt)")

        return tokens
    }

    /// Clear cached tokens and cookies
    func clearTokens() {
        cachedTokens = nil
        spDc = nil
        spT = nil
    }

    /// Whether we have valid cached tokens
    var hasValidTokens: Bool {
        guard let tokens = cachedTokens else { return false }
        return tokens.expiresAt.timeIntervalSinceNow > expiryBuffer
    }

    // MARK: - Cookie Management

    private func ensureCookies() async throws {
        if spDc != nil { return }

        // Try loading persisted cookies first
        if let persisted = PersistenceManager.shared.loadSpotifyCookies() {
            spDc = persisted.spDc
            spT = persisted.spT
            print("[SpotifyTokenManager] Loaded persisted cookies")
            return
        }

        // Extract from Chrome
        print("[SpotifyTokenManager] Extracting cookies from Chrome...")
        let cookies = try ChromeCookieExtractor.extractCookies()
        spDc = cookies.spDc
        spT = cookies.spT

        // Persist for future launches
        PersistenceManager.shared.saveSpotifyCookies(spDc: cookies.spDc, spT: cookies.spT)
        print("[SpotifyTokenManager] Cookies extracted and persisted")
    }

    // MARK: - Token Exchange

    private func exchangeToken(spDc: String, totp: TOTPGenerator.TOTPResult) async throws -> (String, String, Date) {
        var components = URLComponents(string: "https://open.spotify.com/api/token")!
        components.queryItems = [
            URLQueryItem(name: "reason", value: "init"),
            URLQueryItem(name: "productType", value: "web-player"),
            URLQueryItem(name: "totp", value: totp.code),
            URLQueryItem(name: "totpVer", value: totp.version),
            URLQueryItem(name: "totpServer", value: totp.code),
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://open.spotify.com", forHTTPHeaderField: "Origin")
        request.setValue("https://open.spotify.com/", forHTTPHeaderField: "Referer")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("\"Chromium\";v=\"131\", \"Not_A Brand\";v=\"24\", \"Google Chrome\";v=\"131\"",
                         forHTTPHeaderField: "Sec-CH-UA")
        request.setValue("\"macOS\"", forHTTPHeaderField: "Sec-CH-UA-Platform")
        request.setValue("?0", forHTTPHeaderField: "Sec-CH-UA-Mobile")
        request.setValue("WebPlayer", forHTTPHeaderField: "app-platform")
        request.setValue("sp_dc=\(spDc)", forHTTPHeaderField: "Cookie")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            throw AuthError.tokenExchangeFailed("HTTP \(httpResponse.statusCode): \(body)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["accessToken"] as? String,
              let clientId = json["clientId"] as? String else {
            throw AuthError.tokenExchangeFailed("Invalid JSON response")
        }

        // Reject anonymous tokens (indicates invalid/expired sp_dc)
        if let isAnonymous = json["isAnonymous"] as? Bool, isAnonymous {
            // Clear stale cookies so next attempt re-extracts from Chrome
            PersistenceManager.shared.clearSpotifyCookies()
            self.spDc = nil
            self.spT = nil
            throw AuthError.tokenExchangeFailed("Got anonymous token — sp_dc cookie may be expired")
        }

        let expiresAt: Date
        if let expirationMs = json["accessTokenExpirationTimestampMs"] as? Int64 {
            expiresAt = Date(timeIntervalSince1970: TimeInterval(expirationMs) / 1000.0)
        } else if let expiresIn = json["expiresIn"] as? Int {
            expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))
        } else {
            expiresAt = Date().addingTimeInterval(3600)
        }

        print("[SpotifyTokenManager] Access token acquired (clientId: \(clientId.prefix(8))...)")

        return (accessToken, clientId, expiresAt)
    }

    // MARK: - Client Token

    private func getClientToken(clientId: String) async -> (String?, Date?) {
        let url = URL(string: "https://clienttoken.spotify.com/v1/clienttoken")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "client_data": [
                "client_version": "1.2.52.442.g3f7259c4",
                "client_id": clientId,
                "js_sdk_data": [
                    "device_brand": "Apple",
                    "device_model": "unknown",
                    "os": "macos",
                    "os_version": "10.15.7",
                    "device_id": "",
                    "device_type": "computer"
                ]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("[SpotifyTokenManager] Client token request failed")
                return (nil, nil)
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let grantedToken = json["granted_token"] as? [String: Any],
                  let token = grantedToken["token"] as? String else {
                print("[SpotifyTokenManager] Client token parse failed")
                return (nil, nil)
            }

            let expiresIn = grantedToken["expires_after_seconds"] as? Int ?? 7200
            let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn))

            print("[SpotifyTokenManager] Client token acquired")
            return (token, expiresAt)
        } catch {
            print("[SpotifyTokenManager] Client token error: \(error.localizedDescription)")
            return (nil, nil)
        }
    }
}
