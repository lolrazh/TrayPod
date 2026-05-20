import Combine
import Foundation

@MainActor
final class SpotifyLibraryManager: ObservableObject {
    static let shared = SpotifyLibraryManager()

    @Published private(set) var playlists: [SpotifyPlaylist] = []
    @Published private(set) var artists: [SpotifyArtist] = []
    @Published private(set) var albums: [SpotifyAlbum] = []
    @Published private(set) var savedTracks: [SpotifyTrack] = []
    @Published private(set) var playlistTracks: [String: [SpotifyTrack]] = [:]
    @Published private(set) var albumTracks: [String: [SpotifyTrack]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let apiClient = SpotifyAPIClient.shared
    private var hasLoadedLibrary = false

    private init() {}

    func loadLibraryIfNeeded() async {
        guard SpotifyAuthManager.shared.isSignedIn else {
            errorMessage = "Sign in to Spotify"
            return
        }

        guard !hasLoadedLibrary else { return }
        await reloadLibrary()
    }

    func reloadLibrary() async {
        guard SpotifyAuthManager.shared.isSignedIn else {
            errorMessage = "Sign in to Spotify"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let loadedPlaylists = apiClient.fetchPlaylists()
            async let loadedArtists = apiClient.fetchFollowedArtists()
            async let loadedAlbums = apiClient.fetchSavedAlbums()
            async let loadedTracks = apiClient.fetchSavedTracks()

            playlists = try await loadedPlaylists
            artists = try await loadedArtists
            albums = try await loadedAlbums
            savedTracks = try await loadedTracks
            hasLoadedLibrary = true
        } catch {
            errorMessage = "Could not load Spotify"
        }
    }

    func tracks(for playlist: SpotifyPlaylist) -> [SpotifyTrack] {
        playlistTracks[playlist.id] ?? []
    }

    func tracks(for album: SpotifyAlbum) -> [SpotifyTrack] {
        albumTracks[album.id] ?? []
    }

    func loadTracks(for playlist: SpotifyPlaylist) async {
        guard playlistTracks[playlist.id] == nil else { return }
        await loadTrackList {
            playlistTracks[playlist.id] = try await apiClient.fetchPlaylistTracks(playlistID: playlist.id)
        }
    }

    func loadTracks(for album: SpotifyAlbum) async {
        guard albumTracks[album.id] == nil else { return }
        await loadTrackList {
            albumTracks[album.id] = try await apiClient.fetchAlbumTracks(albumID: album.id)
        }
    }

    func reset() {
        playlists = []
        artists = []
        albums = []
        savedTracks = []
        playlistTracks = [:]
        albumTracks = [:]
        hasLoadedLibrary = false
        errorMessage = nil
    }

    private func loadTrackList(_ operation: () async throws -> Void) async {
        guard SpotifyAuthManager.shared.isSignedIn else {
            errorMessage = "Sign in to Spotify"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await operation()
        } catch {
            errorMessage = "Could not load tracks"
        }
    }
}
