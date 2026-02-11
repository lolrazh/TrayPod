import Foundation

// MARK: - Paging

struct SpotifyPagingObject<T: Decodable>: Decodable {
    let items: [T]
    let total: Int
    let next: String?
}

// MARK: - Playlist

struct SpotifyPlaylist: Decodable, Identifiable {
    let id: String
    let name: String
    let images: [SpotifyImage]
    let tracks: SpotifyPlaylistTracksRef

    struct SpotifyPlaylistTracksRef: Decodable {
        let total: Int
    }
}

struct SpotifyPlaylistItem: Decodable {
    let track: SpotifyTrack?
}

// MARK: - Track

struct SpotifyTrack: Decodable, Identifiable {
    let id: String?
    let name: String
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
    let durationMs: Int
    let uri: String

    enum CodingKeys: String, CodingKey {
        case id, name, artists, album, uri
        case durationMs = "duration_ms"
    }

    func toTrack() -> Track {
        Track(
            title: name,
            artist: artists.map(\.name).joined(separator: ", "),
            album: album.name,
            duration: TimeInterval(durationMs) / 1000.0,
            artworkURL: album.images.first.flatMap { URL(string: $0.url) },
            spotifyURI: uri
        )
    }
}

// MARK: - Artist

struct SpotifyArtist: Decodable, Identifiable {
    let id: String?
    let name: String
    let images: [SpotifyImage]?

    enum CodingKeys: String, CodingKey {
        case id, name, images
    }
}

// MARK: - Album

struct SpotifyAlbum: Decodable {
    let name: String
    let images: [SpotifyImage]
}

// MARK: - Image

struct SpotifyImage: Decodable {
    let url: String
    let height: Int?
    let width: Int?
}

// MARK: - Saved Track

struct SpotifySavedTrack: Decodable {
    let track: SpotifyTrack
}

// MARK: - Followed Artists

struct SpotifyFollowedArtists: Decodable {
    let artists: SpotifyArtistsCursorPaging
}

struct SpotifyArtistsCursorPaging: Decodable {
    let items: [SpotifyArtist]
    let total: Int
    let cursors: SpotifyCursor?
}

struct SpotifyCursor: Decodable {
    let after: String?
}
