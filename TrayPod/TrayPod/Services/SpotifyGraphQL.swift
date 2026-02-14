import Foundation

/// Handles Spotify GraphQL search via the Pathfinder API.
/// Resolves the persisted query hash from Spotify's web player bundle,
/// then uses it for search queries. Falls back to REST API if GraphQL fails.
class SpotifyGraphQL {

    private let tokenManager: SpotifyTokenManager
    private var cachedHash: String?
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    init(tokenManager: SpotifyTokenManager) {
        self.tokenManager = tokenManager
    }

    // MARK: - Search

    func search(query: String, limit: Int = 10) async throws -> SearchResults {
        // Try GraphQL first, fall back to REST
        do {
            return try await searchGraphQL(query: query, limit: limit)
        } catch {
            print("[GraphQL] GraphQL search failed, falling back to REST: \(error.localizedDescription)")
            return try await searchREST(query: query, limit: limit)
        }
    }

    // MARK: - GraphQL Search

    private func searchGraphQL(query: String, limit: Int) async throws -> SearchResults {
        let hash = try await resolveHash()
        let tokens = try await tokenManager.getTokens()

        let variables: [String: Any] = [
            "searchTerm": query,
            "offset": 0,
            "limit": limit,
            "numberOfTopResults": 5,
            "includeAudiobooks": false,
            "includePreReleases": false,
            "includeGenericArtists": false
        ]

        let extensions: [String: Any] = [
            "persistedQuery": [
                "version": 1,
                "sha256Hash": hash
            ]
        ]

        let variablesJSON = try JSONSerialization.data(withJSONObject: variables)
        let extensionsJSON = try JSONSerialization.data(withJSONObject: extensions)

        var components = URLComponents(string: "https://api-partner.spotify.com/pathfinder/v1/query")!
        components.queryItems = [
            URLQueryItem(name: "operationName", value: "searchDesktop"),
            URLQueryItem(name: "variables", value: String(data: variablesJSON, encoding: .utf8)),
            URLQueryItem(name: "extensions", value: String(data: extensionsJSON, encoding: .utf8))
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if let clientToken = tokens.clientToken {
            request.setValue(clientToken, forHTTPHeaderField: "Client-Token")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        // If hash is stale, clear cache and retry once
        if statusCode == 400 || statusCode == 404 {
            cachedHash = nil
            throw NSError(domain: "GraphQL", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Stale hash, retry"])
        }

        guard (200...299).contains(statusCode) else {
            throw NSError(domain: "GraphQL", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Search failed: HTTP \(statusCode)"])
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let jsonData = json["data"] as? [String: Any],
              let searchV2 = jsonData["searchV2"] as? [String: Any] else {
            throw NSError(domain: "GraphQL", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid GraphQL response"])
        }

        return parseGraphQLResults(searchV2)
    }

    // MARK: - Hash Resolution

    private func resolveHash() async throws -> String {
        if let cached = cachedHash { return cached }

        // Fetch Spotify web player HTML
        let htmlURL = URL(string: "https://open.spotify.com/")!
        var htmlRequest = URLRequest(url: htmlURL)
        htmlRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (htmlData, _) = try await URLSession.shared.data(for: htmlRequest)
        let html = String(data: htmlData, encoding: .utf8) ?? ""

        // Find JS bundle URLs
        let scriptPattern = try NSRegularExpression(pattern: #"<script\s+src="([^"]*web-player[^"]*\.js)"#)
        let matches = scriptPattern.matches(in: html, range: NSRange(html.startIndex..., in: html))

        for match in matches {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            let jsURL = String(html[range])

            let fullURL: URL
            if jsURL.hasPrefix("http") {
                fullURL = URL(string: jsURL)!
            } else {
                fullURL = URL(string: "https://open.spotify.com\(jsURL)")!
            }

            // Fetch JS and search for hash
            var jsRequest = URLRequest(url: fullURL)
            jsRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")

            let (jsData, _) = try await URLSession.shared.data(for: jsRequest)
            let js = String(data: jsData, encoding: .utf8) ?? ""

            let hashPattern = try NSRegularExpression(pattern: #"searchDesktop.*?sha256Hash":"([a-f0-9]{64})"#)
            if let hashMatch = hashPattern.firstMatch(in: js, range: NSRange(js.startIndex..., in: js)),
               let hashRange = Range(hashMatch.range(at: 1), in: js) {
                let hash = String(js[hashRange])
                cachedHash = hash
                return hash
            }
        }

        throw NSError(domain: "GraphQL", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: "Could not resolve searchDesktop hash"])
    }

    // MARK: - GraphQL Response Parsing

    private func parseGraphQLResults(_ searchV2: [String: Any]) -> SearchResults {
        var tracks: [Track] = []
        var albums: [Album] = []
        var playlists: [Playlist] = []

        // Parse tracks
        if let tracksV2 = searchV2["tracksV2"] as? [String: Any],
           let items = tracksV2["items"] as? [[String: Any]] {
            for item in items {
                if let trackItem = item["item"] as? [String: Any],
                   let data = trackItem["data"] as? [String: Any] {
                    let uri = data["uri"] as? String ?? ""
                    let name = data["name"] as? String ?? ""

                    var artistName = ""
                    if let artists = data["artists"] as? [String: Any],
                       let artistItems = artists["items"] as? [[String: Any]] {
                        artistName = artistItems.compactMap { ($0["profile"] as? [String: Any])?["name"] as? String }.joined(separator: ", ")
                    }

                    var albumName = ""
                    if let albumData = data["albumOfTrack"] as? [String: Any] {
                        albumName = albumData["name"] as? String ?? ""
                    }

                    var durationMs = 0
                    if let duration = data["duration"] as? [String: Any],
                       let ms = duration["totalMilliseconds"] as? Int {
                        durationMs = ms
                    }

                    tracks.append(Track(
                        id: uri,
                        title: name,
                        artist: artistName,
                        album: albumName,
                        duration: TimeInterval(durationMs) / 1000.0
                    ))
                }
            }
        }

        // Parse albums
        if let albumsV2 = searchV2["albumsV2"] as? [String: Any],
           let items = albumsV2["items"] as? [[String: Any]] {
            for item in items {
                if let data = item["data"] as? [String: Any] {
                    let uri = data["uri"] as? String ?? ""
                    let name = data["name"] as? String ?? ""

                    var artistName = ""
                    if let artists = data["artists"] as? [String: Any],
                       let artistItems = artists["items"] as? [[String: Any]] {
                        artistName = artistItems.compactMap { ($0["profile"] as? [String: Any])?["name"] as? String }.joined(separator: ", ")
                    }

                    albums.append(Album(id: uri, name: name, artistName: artistName, trackCount: 0))
                }
            }
        }

        // Parse playlists
        if let playlistsData = searchV2["playlists"] as? [String: Any],
           let items = playlistsData["items"] as? [[String: Any]] {
            for item in items {
                if let data = item["data"] as? [String: Any] {
                    let uri = data["uri"] as? String ?? ""
                    let name = data["name"] as? String ?? ""
                    let owner = (data["owner"] as? [String: Any])?["name"] as? String ?? ""

                    playlists.append(Playlist(id: uri, name: name, trackCount: 0, ownerName: owner))
                }
            }
        }

        return SearchResults(tracks: tracks, albums: albums, playlists: playlists)
    }

    // MARK: - REST Fallback

    private func searchREST(query: String, limit: Int) async throws -> SearchResults {
        let tokens = try await tokenManager.getTokens()

        var components = URLComponents(string: "https://api.spotify.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "track,album,playlist"),
            URLQueryItem(name: "limit", value: String(limit))
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

        guard (200...299).contains(statusCode) else {
            throw NSError(domain: "SpotifyAPI", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "REST search failed: HTTP \(statusCode)"])
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "SpotifyAPI", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid REST response"])
        }

        return parseRESTResults(json)
    }

    private func parseRESTResults(_ json: [String: Any]) -> SearchResults {
        var tracks: [Track] = []
        var albums: [Album] = []
        var playlists: [Playlist] = []

        // Tracks
        if let tracksData = json["tracks"] as? [String: Any],
           let items = tracksData["items"] as? [[String: Any]] {
            for item in items {
                let uri = item["uri"] as? String ?? ""
                let name = item["name"] as? String ?? ""
                let artistName = (item["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: ", ") ?? ""
                let albumName = (item["album"] as? [String: Any])?["name"] as? String ?? ""
                let durationMs = item["duration_ms"] as? Int ?? 0

                tracks.append(Track(
                    id: uri,
                    title: name,
                    artist: artistName,
                    album: albumName,
                    duration: TimeInterval(durationMs) / 1000.0
                ))
            }
        }

        // Albums
        if let albumsData = json["albums"] as? [String: Any],
           let items = albumsData["items"] as? [[String: Any]] {
            for item in items {
                let uri = item["uri"] as? String ?? ""
                let name = item["name"] as? String ?? ""
                let artistName = (item["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: ", ") ?? ""
                let trackCount = item["total_tracks"] as? Int ?? 0
                albums.append(Album(id: uri, name: name, artistName: artistName, trackCount: trackCount))
            }
        }

        // Playlists
        if let playlistsData = json["playlists"] as? [String: Any],
           let items = playlistsData["items"] as? [[String: Any]] {
            for item in items {
                let uri = item["uri"] as? String ?? ""
                let name = item["name"] as? String ?? ""
                let owner = (item["owner"] as? [String: Any])?["display_name"] as? String ?? ""
                let trackCount = (item["tracks"] as? [String: Any])?["total"] as? Int ?? 0
                playlists.append(Playlist(id: uri, name: name, trackCount: trackCount, ownerName: owner))
            }
        }

        return SearchResults(tracks: tracks, albums: albums, playlists: playlists)
    }
}
