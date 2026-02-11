import Foundation

@MainActor
class BrowseViewModel: ObservableObject {

    // MARK: - Load State

    enum LoadState<T> {
        case idle
        case loading
        case loaded(T)
        case error(String)
    }

    // MARK: - Published State

    @Published var playlistsState: LoadState<[SpotifyPlaylist]> = .idle
    @Published var playlistTracksState: LoadState<[Track]> = .idle
    @Published var artistsState: LoadState<[SpotifyArtist]> = .idle
    @Published var songsState: LoadState<[Track]> = .idle

    // Cache loaded playlist ID to avoid redundant fetches
    private var loadedPlaylistID: String?

    private let api = SpotifyWebAPIClient.shared

    // MARK: - Load Playlists

    func loadPlaylists() {
        guard case .idle = playlistsState else { return }
        playlistsState = .loading

        Task {
            do {
                let result = try await api.getMyPlaylists()
                playlistsState = .loaded(result.items)
            } catch {
                playlistsState = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Load Playlist Tracks

    func loadPlaylistTracks(id: String) {
        if loadedPlaylistID == id, case .loaded = playlistTracksState { return }
        loadedPlaylistID = id
        playlistTracksState = .loading

        Task {
            do {
                let result = try await api.getPlaylistTracks(playlistID: id)
                let tracks = result.items.compactMap { $0.track?.toTrack() }
                playlistTracksState = .loaded(tracks)
            } catch {
                playlistTracksState = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Load Artists

    func loadArtists() {
        guard case .idle = artistsState else { return }
        artistsState = .loading

        Task {
            do {
                let result = try await api.getFollowedArtists()
                artistsState = .loaded(result.artists.items)
            } catch {
                artistsState = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Load Saved Songs

    func loadSongs() {
        guard case .idle = songsState else { return }
        songsState = .loading

        Task {
            do {
                let result = try await api.getSavedTracks()
                let tracks = result.items.map { $0.track.toTrack() }
                songsState = .loaded(tracks)
            } catch {
                songsState = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Clear Cache

    func clearCache() {
        playlistsState = .idle
        playlistTracksState = .idle
        artistsState = .idle
        songsState = .idle
        loadedPlaylistID = nil
    }
}
