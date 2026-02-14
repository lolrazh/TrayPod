import Foundation

protocol MusicServiceProtocol: AnyObject {
    var serviceName: String { get }
    var isRunning: Bool { get }
    var isPlaying: Bool { get }
    var currentTrack: Track? { get }
    var playbackPosition: TimeInterval { get }
    var volume: Float { get set }

    func play()
    func pause()
    func togglePlayPause()
    func nextTrack()
    func previousTrack()
    func seek(to position: TimeInterval)

    // Library & Search
    func search(query: String) async throws -> SearchResults
    func getPlaylists() async throws -> [Playlist]
    func getPlaylistTracks(id: String) async throws -> [Track]
    func getSavedAlbums() async throws -> [Album]
    func getAlbumTracks(id: String) async throws -> [Track]
    func getSavedTracks(offset: Int, limit: Int) async throws -> [Track]
    func playTrack(uri: String)
    func playContext(uri: String)
}

extension MusicServiceProtocol {
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    // Default empty implementations for library/search
    func search(query: String) async throws -> SearchResults {
        SearchResults(tracks: [], albums: [], playlists: [])
    }
    func getPlaylists() async throws -> [Playlist] { [] }
    func getPlaylistTracks(id: String) async throws -> [Track] { [] }
    func getSavedAlbums() async throws -> [Album] { [] }
    func getAlbumTracks(id: String) async throws -> [Track] { [] }
    func getSavedTracks(offset: Int, limit: Int) async throws -> [Track] { [] }
    func playTrack(uri: String) {}
    func playContext(uri: String) {}
}
