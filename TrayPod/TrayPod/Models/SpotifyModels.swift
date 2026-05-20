import Foundation

struct SpotifyPage<T: Decodable>: Decodable {
    let items: [T]
    let total: Int?
    let next: String?
}

struct SpotifyImage: Decodable, Equatable {
    let url: URL
    let height: Int?
    let width: Int?
}

struct SpotifyArtist: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let uri: String
    let images: [SpotifyImage]?

    var displayName: String { name }
}

struct SpotifyAlbum: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let uri: String
    let artists: [SpotifyArtist]
    let images: [SpotifyImage]?
    let totalTracks: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case uri
        case artists
        case images
        case totalTracks = "total_tracks"
    }

    var artistText: String {
        artists.map(\.name).joined(separator: ", ")
    }

    var artworkURL: URL? {
        images?.first?.url
    }
}

struct SpotifyTrack: Decodable, Identifiable, Equatable {
    let spotifyId: String?
    let name: String
    let uri: String
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum?
    let durationMs: Int

    enum CodingKeys: String, CodingKey {
        case spotifyId = "id"
        case name
        case uri
        case artists
        case album
        case durationMs = "duration_ms"
    }

    var id: String { uri }

    var artistText: String {
        artists.map(\.name).joined(separator: ", ")
    }

    var duration: TimeInterval {
        TimeInterval(durationMs) / 1000
    }
}

struct SpotifyPlaylist: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let uri: String
    let images: [SpotifyImage]?
    let tracks: TrackSummary

    struct TrackSummary: Decodable, Equatable {
        let total: Int
    }

    var artworkURL: URL? {
        images?.first?.url
    }
}

struct SpotifySavedTrackItem: Decodable {
    let track: SpotifyTrack
}

struct SpotifyPlaylistTrackItem: Decodable {
    let track: SpotifyTrack?
}

struct SpotifySavedAlbumItem: Decodable {
    let album: SpotifyAlbum
}

struct SpotifyFollowedArtistsResponse: Decodable {
    let artists: SpotifyPage<SpotifyArtist>
}
