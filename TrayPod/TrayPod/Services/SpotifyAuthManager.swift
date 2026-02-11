import Foundation
import CryptoKit
import AppKit

@MainActor
class SpotifyAuthManager: ObservableObject {
    static let shared = SpotifyAuthManager()

    // MARK: - Configuration

    // TODO: Replace with your Spotify Developer App Client ID
    // Create one at https://developer.spotify.com/dashboard
    // Set redirect URI to: traypod://callback
    private let clientID = "YOUR_CLIENT_ID_HERE"
    private let redirectURI = "traypod://callback"
    private let tokenURL = "https://accounts.spotify.com/api/token"
    private let authorizeURL = "https://accounts.spotify.com/authorize"

    private let scopes = [
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-read-currently-playing",
        "playlist-read-private",
        "playlist-read-collaborative",
        "user-library-read",
        "user-follow-read"
    ].joined(separator: " ")

    // MARK: - Published State

    @Published private(set) var isSignedIn: Bool = false

    // MARK: - PKCE State

    private var codeVerifier: String?
    private var stateToken: String?

    // MARK: - Init

    private init() {
        // Check if we have a stored token
        isSignedIn = KeychainHelper.load(.accessToken) != nil
    }

    // MARK: - Sign In

    func startSignIn() {
        let verifier = generateCodeVerifier()
        let challenge = generateCodeChallenge(from: verifier)
        let state = UUID().uuidString

        codeVerifier = verifier
        stateToken = state

        var components = URLComponents(string: authorizeURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge)
        ]

        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Handle Callback

    func handleCallback(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return }

        // Validate state
        let returnedState = queryItems.first(where: { $0.name == "state" })?.value
        guard returnedState == stateToken else {
            print("SpotifyAuth: State mismatch")
            return
        }

        // Check for error
        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            print("SpotifyAuth: Authorization error: \(error)")
            return
        }

        // Get authorization code
        guard let code = queryItems.first(where: { $0.name == "code" })?.value,
              let verifier = codeVerifier else {
            print("SpotifyAuth: Missing code or verifier")
            return
        }

        // Exchange code for tokens
        Task {
            await exchangeCodeForTokens(code: code, verifier: verifier)
        }
    }

    // MARK: - Token Exchange

    private func exchangeCodeForTokens(code: String, verifier: String) async {
        let body = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": clientID,
            "code_verifier": verifier
        ]

        guard let tokenData = await performTokenRequest(body: body) else { return }
        storeTokens(tokenData)

        // Clear PKCE state
        codeVerifier = nil
        stateToken = nil
    }

    // MARK: - Token Refresh

    private func refreshAccessToken() async -> Bool {
        guard let refreshToken = KeychainHelper.load(.refreshToken) else { return false }

        let body = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID
        ]

        guard let tokenData = await performTokenRequest(body: body) else { return false }
        storeTokens(tokenData)
        return true
    }

    // MARK: - Get Valid Token

    /// Returns a valid access token, refreshing if needed. Returns nil if not signed in or refresh fails.
    func validAccessToken() async -> String? {
        guard let token = KeychainHelper.load(.accessToken) else { return nil }

        // Check expiry
        if let expiryString = KeychainHelper.load(.tokenExpiry),
           let expiryTimestamp = Double(expiryString) {
            let expiryDate = Date(timeIntervalSince1970: expiryTimestamp)
            // Refresh 60 seconds before expiry
            if Date().addingTimeInterval(60) < expiryDate {
                return token
            }
        }

        // Token expired or no expiry info — try refresh
        if await refreshAccessToken() {
            return KeychainHelper.load(.accessToken)
        }

        // Refresh failed — sign out
        signOut()
        return nil
    }

    // MARK: - Sign Out

    func signOut() {
        KeychainHelper.deleteAll()
        isSignedIn = false
    }

    // MARK: - Private Helpers

    private func performTokenRequest(body: [String: String]) async -> TokenResponse? {
        guard let url = URL(string: tokenURL) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("SpotifyAuth: Token request failed")
                return nil
            }

            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            print("SpotifyAuth: Token request error: \(error)")
            return nil
        }
    }

    private func storeTokens(_ response: TokenResponse) {
        KeychainHelper.save(response.accessToken, for: .accessToken)

        if let refreshToken = response.refreshToken {
            KeychainHelper.save(refreshToken, for: .refreshToken)
        }

        let expiry = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        KeychainHelper.save(String(expiry.timeIntervalSince1970), for: .tokenExpiry)

        isSignedIn = true
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncoded()
    }
}

// MARK: - Token Response

private struct TokenResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}

// MARK: - Base64URL Encoding

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
