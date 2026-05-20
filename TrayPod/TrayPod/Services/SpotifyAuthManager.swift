import AppKit
import Combine
import CryptoKit
import Foundation

@MainActor
final class SpotifyAuthManager: ObservableObject {
    static let shared = SpotifyAuthManager()

    @Published private(set) var isSignedIn = false
    @Published private(set) var userName: String?
    @Published private(set) var isAuthenticating = false
    @Published private(set) var authenticationError: String?

    private let clientId = "aea26d100ffd41a592847f9a5350a10d"
    private let redirectURI = "traypod://callback"
    private let authorizeURL = URL(string: "https://accounts.spotify.com/authorize")!
    private let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
    private let profileURL = URL(string: "https://api.spotify.com/v1/me")!
    private let scopes = [
        "user-library-read",
        "playlist-read-private",
        "playlist-read-collaborative",
        "user-follow-read",
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-read-currently-playing"
    ]

    private var codeVerifier: String?
    private var oauthState: String?

    private enum TokenKey {
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
        static let expiry = "token_expiry"
    }

    private struct TokenResponse: Decodable {
        let accessToken: String
        let refreshToken: String?
        let expiresIn: TimeInterval

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
        }
    }

    private struct SpotifyProfile: Decodable {
        let id: String
        let displayName: String?

        enum CodingKeys: String, CodingKey {
            case id
            case displayName = "display_name"
        }
    }

    private init() {
        restoreSession()
    }

    func signIn() {
        authenticationError = nil
        isAuthenticating = true

        let verifier = randomString(length: 128)
        let state = randomString(length: 32)
        codeVerifier = verifier
        oauthState = state

        var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: codeChallenge(for: verifier))
        ]

        guard let url = components?.url else {
            authenticationError = "Could not build Spotify sign-in URL."
            isAuthenticating = false
            return
        }

        NSWorkspace.shared.open(url)
    }

    func handleCallback(url: URL) async {
        guard url.scheme == "traypod", url.host == "callback" else { return }

        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let returnedState = queryItems.first { $0.name == "state" }?.value

        if let expectedState = oauthState, returnedState != expectedState {
            authenticationError = "Spotify sign-in state did not match."
            isAuthenticating = false
            return
        }

        if let error = queryItems.first(where: { $0.name == "error" })?.value {
            authenticationError = "Spotify sign-in failed: \(error)"
            isAuthenticating = false
            return
        }

        guard
            let code = queryItems.first(where: { $0.name == "code" })?.value,
            let verifier = codeVerifier
        else {
            authenticationError = "Spotify sign-in callback was missing a code."
            isAuthenticating = false
            return
        }

        do {
            let response = try await requestToken(formItems: [
                URLQueryItem(name: "grant_type", value: "authorization_code"),
                URLQueryItem(name: "code", value: code),
                URLQueryItem(name: "redirect_uri", value: redirectURI),
                URLQueryItem(name: "client_id", value: clientId),
                URLQueryItem(name: "code_verifier", value: verifier)
            ])

            saveTokenResponse(response)
            isSignedIn = true
            isAuthenticating = false
            codeVerifier = nil
            oauthState = nil
            await fetchUserProfile()
        } catch {
            authenticationError = "Could not finish Spotify sign-in."
            isAuthenticating = false
        }
    }

    func signOut() {
        KeychainHelper.delete(key: TokenKey.accessToken)
        KeychainHelper.delete(key: TokenKey.refreshToken)
        KeychainHelper.delete(key: TokenKey.expiry)

        isSignedIn = false
        isAuthenticating = false
        userName = nil
        authenticationError = nil
        codeVerifier = nil
        oauthState = nil
    }

    func getAccessToken() async -> String? {
        guard isSignedIn else { return nil }
        return await refreshTokenIfNeeded()
    }

    private func restoreSession() {
        if loadString(key: TokenKey.accessToken) != nil || loadString(key: TokenKey.refreshToken) != nil {
            isSignedIn = true
            Task { await fetchUserProfile() }
        }
    }

    private func refreshTokenIfNeeded() async -> String? {
        if let accessToken = loadString(key: TokenKey.accessToken),
           let expiry = loadExpiry(),
           expiry > Date().addingTimeInterval(60) {
            return accessToken
        }

        guard let refreshToken = loadString(key: TokenKey.refreshToken) else {
            signOut()
            return nil
        }

        do {
            let response = try await requestToken(formItems: [
                URLQueryItem(name: "grant_type", value: "refresh_token"),
                URLQueryItem(name: "refresh_token", value: refreshToken),
                URLQueryItem(name: "client_id", value: clientId)
            ])
            saveTokenResponse(response)
            return response.accessToken
        } catch {
            authenticationError = "Spotify session expired. Sign in again."
            signOut()
            return nil
        }
    }

    private func fetchUserProfile() async {
        guard let accessToken = await refreshTokenIfNeeded() else { return }

        var request = URLRequest(url: profileURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            let profile = try JSONDecoder().decode(SpotifyProfile.self, from: data)
            userName = profile.displayName?.isEmpty == false ? profile.displayName : profile.id
        } catch {
            userName = nil
        }
    }

    private func requestToken(formItems: [URLQueryItem]) async throws -> TokenResponse {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody(from: formItems)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.userAuthenticationRequired)
        }

        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func saveTokenResponse(_ response: TokenResponse) {
        saveString(response.accessToken, key: TokenKey.accessToken)
        if let refreshToken = response.refreshToken {
            saveString(refreshToken, key: TokenKey.refreshToken)
        }
        saveString(String(Date().addingTimeInterval(response.expiresIn).timeIntervalSince1970), key: TokenKey.expiry)
    }

    private func formBody(from items: [URLQueryItem]) -> Data? {
        var components = URLComponents()
        components.queryItems = items
        return components.percentEncodedQuery?.data(using: .utf8)
    }

    private func saveString(_ value: String, key: String) {
        KeychainHelper.save(key: key, data: Data(value.utf8))
    }

    private func loadString(key: String) -> String? {
        guard let data = KeychainHelper.load(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func loadExpiry() -> Date? {
        guard let value = loadString(key: TokenKey.expiry),
              let timestamp = TimeInterval(value) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    private func randomString(length: Int) -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return String(bytes.map { characters[Int($0) % characters.count] })
    }

    private func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
