import Foundation

actor SpotifyWebAPIClient {
    static let shared = SpotifyWebAPIClient()

    private let baseURL = "https://api.spotify.com/v1"
    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private init() {}

    // MARK: - Playlists

    func getMyPlaylists(limit: Int = 50, offset: Int = 0) async throws -> SpotifyPagingObject<SpotifyPlaylist> {
        try await request("/me/playlists?limit=\(limit)&offset=\(offset)")
    }

    func getPlaylistTracks(playlistID: String, limit: Int = 50, offset: Int = 0) async throws -> SpotifyPagingObject<SpotifyPlaylistItem> {
        try await request("/playlists/\(playlistID)/tracks?limit=\(limit)&offset=\(offset)")
    }

    // MARK: - Library

    func getSavedTracks(limit: Int = 50, offset: Int = 0) async throws -> SpotifyPagingObject<SpotifySavedTrack> {
        try await request("/me/tracks?limit=\(limit)&offset=\(offset)")
    }

    func getFollowedArtists(limit: Int = 50, after: String? = nil) async throws -> SpotifyFollowedArtists {
        var url = "/me/following?type=artist&limit=\(limit)"
        if let after { url += "&after=\(after)" }
        return try await request(url)
    }

    // MARK: - Playback (Web API fallback)

    func play(contextURI: String? = nil, trackURIs: [String]? = nil, offset: Int? = nil) async throws {
        var body: [String: Any] = [:]
        if let contextURI { body["context_uri"] = contextURI }
        if let trackURIs { body["uris"] = trackURIs }
        if let offset { body["offset"] = ["position": offset] }

        let bodyData = try JSONSerialization.data(withJSONObject: body)
        try await requestNoContent("/me/player/play", method: "PUT", body: bodyData)
    }

    // MARK: - Generic Request

    private func request<T: Decodable>(_ path: String) async throws -> T {
        guard let token = await SpotifyAuthManager.shared.validAccessToken() else {
            throw SpotifyAPIError.notAuthenticated
        }

        var urlRequest = URLRequest(url: URL(string: baseURL + path)!)
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyAPIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            // Try refreshing token once
            guard let newToken = await SpotifyAuthManager.shared.validAccessToken() else {
                throw SpotifyAPIError.notAuthenticated
            }
            urlRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await session.data(for: urlRequest)

            guard let retryHTTP = retryResponse as? HTTPURLResponse, retryHTTP.statusCode == 200 else {
                throw SpotifyAPIError.httpError((retryResponse as? HTTPURLResponse)?.statusCode ?? 0)
            }
            return try decoder.decode(T.self, from: retryData)
        }

        guard httpResponse.statusCode == 200 else {
            throw SpotifyAPIError.httpError(httpResponse.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }

    private func requestNoContent(_ path: String, method: String, body: Data?) async throws {
        guard let token = await SpotifyAuthManager.shared.validAccessToken() else {
            throw SpotifyAPIError.notAuthenticated
        }

        var urlRequest = URLRequest(url: URL(string: baseURL + path)!)
        urlRequest.httpMethod = method
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = body

        let (_, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyAPIError.invalidResponse
        }

        // 204 No Content or 200 OK are both success
        guard (200...204).contains(httpResponse.statusCode) else {
            throw SpotifyAPIError.httpError(httpResponse.statusCode)
        }
    }
}

// MARK: - Errors

enum SpotifyAPIError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not signed in to Spotify"
        case .invalidResponse: return "Invalid response from Spotify"
        case .httpError(let code): return "Spotify API error (\(code))"
        }
    }
}
