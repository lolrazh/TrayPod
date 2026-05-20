import Foundation

final class SpotifyAPIClient {
    static let shared = SpotifyAPIClient()

    private let baseURL = URL(string: "https://api.spotify.com/v1")!

    private init() {}

    func fetchPlaylists(limit: Int = 50) async throws -> [SpotifyPlaylist] {
        let page: SpotifyPage<SpotifyPlaylist> = try await get("/me/playlists", queryItems: [
            URLQueryItem(name: "limit", value: String(limit))
        ])
        return page.items
    }

    func fetchSavedTracks(limit: Int = 50) async throws -> [SpotifyTrack] {
        let page: SpotifyPage<SpotifySavedTrackItem> = try await get("/me/tracks", queryItems: [
            URLQueryItem(name: "limit", value: String(limit))
        ])
        return page.items.map(\.track)
    }

    func fetchSavedAlbums(limit: Int = 50) async throws -> [SpotifyAlbum] {
        let page: SpotifyPage<SpotifySavedAlbumItem> = try await get("/me/albums", queryItems: [
            URLQueryItem(name: "limit", value: String(limit))
        ])
        return page.items.map(\.album)
    }

    func fetchFollowedArtists(limit: Int = 50) async throws -> [SpotifyArtist] {
        let response: SpotifyFollowedArtistsResponse = try await get("/me/following", queryItems: [
            URLQueryItem(name: "type", value: "artist"),
            URLQueryItem(name: "limit", value: String(limit))
        ])
        return response.artists.items
    }

    func fetchPlaylistTracks(playlistID: String, limit: Int = 50) async throws -> [SpotifyTrack] {
        let page: SpotifyPage<SpotifyPlaylistTrackItem> = try await get("/playlists/\(playlistID)/tracks", queryItems: [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "market", value: "from_token")
        ])
        return page.items.compactMap(\.track)
    }

    func fetchAlbumTracks(albumID: String, limit: Int = 50) async throws -> [SpotifyTrack] {
        let page: SpotifyPage<SpotifyTrack> = try await get("/albums/\(albumID)/tracks", queryItems: [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "market", value: "from_token")
        ])
        return page.items
    }

    func startPlayback(uri: String, isContext: Bool) async throws {
        let body: [String: Any] = isContext
            ? ["context_uri": uri]
            : ["uris": [uri]]

        _ = try await request(
            "/me/player/play",
            method: "PUT",
            body: try JSONSerialization.data(withJSONObject: body)
        ) as EmptyResponse
    }

    private func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        try await request(path, method: "GET", queryItems: queryItems)
    }

    private func request<T: Decodable>(
        _ path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> T {
        guard let token = await SpotifyAuthManager.shared.getAccessToken() else {
            throw URLError(.userAuthenticationRequired)
        }

        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var components = URLComponents(url: baseURL.appendingPathComponent(normalizedPath), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

        if statusCode == 204, T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }

        guard (200..<300).contains(statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct EmptyResponse: Decodable {}
