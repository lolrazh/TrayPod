import SwiftUI
import Combine

@MainActor
class iPodViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var selectedColor: iPodColor {
        didSet {
            PersistenceManager.shared.selectedColor = selectedColor
        }
    }

    @Published var currentScreen: MenuScreen = .main
    @Published var selectedIndex: Int = 0
    @Published var navigationStack: [MenuScreen] = []
    @Published var transitionDirection: Edge = .trailing

    @Published var soundEnabled: Bool {
        didSet {
            PersistenceManager.shared.soundEnabled = soundEnabled
        }
    }

    @Published var hapticEnabled: Bool {
        didSet {
            PersistenceManager.shared.hapticEnabled = hapticEnabled
        }
    }

    @Published var autoLaunchEnabled: Bool

    // Player state - forward changes to trigger view updates
    let playerViewModel = PlayerViewModel()
    private let spotifyLibrary = SpotifyLibraryManager.shared
    private var playerCancellable: AnyCancellable?
    private var authCancellable: AnyCancellable?
    private var libraryCancellable: AnyCancellable?
    private var selectedPlaylist: SpotifyPlaylist?
    private var selectedAlbum: SpotifyAlbum?

    // Scroll accumulator for smooth scrolling
    private var scrollAccumulator: CGFloat = 0
    private let scrollThreshold: CGFloat = 25.0

    // Volume control on Now Playing
    private let volumeStep: Float = 0.05

    // MARK: - Menu Items (iPod 5G style - text only, no icons)

    var mainMenuItems: [MenuItem] {
        [
            MenuItem(title: "Music", action: .navigate(.music)),
            MenuItem(title: "Photos", action: .none),     // Placeholder - not functional
            MenuItem(title: "Videos", action: .none),     // Placeholder - not functional
            MenuItem(title: "Extras", action: .none),     // Placeholder - not functional
            MenuItem(title: "Settings", action: .navigate(.settings)),
            MenuItem(title: "Shuffle Songs", action: .custom { [weak self] in
                self?.playerViewModel.togglePlayPause()  // Just play for now
            })
        ]
    }

    var settingsMenuItems: [MenuItem] {
        let authManager = SpotifyAuthManager.shared

        return [
            MenuItem(title: "Color", action: .navigate(.colorSelection)),
            MenuItem(title: "Sounds: \(soundEnabled ? "On" : "Off")", action: .custom { [weak self] in
                self?.soundEnabled.toggle()
            }),
            MenuItem(title: "Haptics: \(hapticEnabled ? "On" : "Off")", action: .custom { [weak self] in
                self?.hapticEnabled.toggle()
            }),
            MenuItem(title: "Launch: \(autoLaunchEnabled ? "On" : "Off")", action: .custom { [weak self] in
                self?.toggleAutoLaunch()
            }),
            MenuItem(title: playerViewModel.hasActiveService ? "Show Spotify" : "Open Spotify", action: .custom { [weak self] in
                self?.playerViewModel.openPreferredPlayer()
            }),
            MenuItem(title: spotifyAuthTitle, action: .custom {
                if authManager.isSignedIn {
                    authManager.signOut()
                } else if !authManager.isAuthenticating {
                    authManager.signIn()
                }
            })
        ]
    }

    private var spotifyAuthTitle: String {
        let authManager = SpotifyAuthManager.shared
        if authManager.isAuthenticating {
            return "Spotify: Connecting"
        }
        if authManager.isSignedIn {
            return "Spotify: Sign Out"
        }
        return "Spotify: Sign In"
    }

    var currentMenuItems: [MenuItem] {
        switch currentScreen {
        case .main:
            return mainMenuItems
        case .music:
            return musicMenuItems
        case .settings:
            return settingsMenuItems
        case .playlists:
            return playlistMenuItems
        case .playlistTracks:
            return playlistTrackMenuItems
        case .artists:
            return artistMenuItems
        case .albums:
            return albumMenuItems
        case .albumTracks:
            return albumTrackMenuItems
        case .savedTracks:
            return savedTrackMenuItems
        case .nowPlaying, .colorSelection:
            return []
        }
    }

    private var musicMenuItems: [MenuItem] {
        var items = [
            MenuItem(title: "Now Playing", action: .navigate(.nowPlaying)),
            MenuItem(title: "Playlists", action: .navigate(.playlists)),
            MenuItem(title: "Artists", action: .navigate(.artists)),
            MenuItem(title: "Albums", action: .navigate(.albums)),
            MenuItem(title: "Songs", action: .navigate(.savedTracks))
        ]

        if !SpotifyAuthManager.shared.isSignedIn {
            items.append(MenuItem(title: "Spotify: Sign In", action: .custom {
                SpotifyAuthManager.shared.signIn()
            }))
        }

        return items
    }

    private var playlistMenuItems: [MenuItem] {
        spotifyCollectionItems(
            emptyTitle: "No Playlists",
            values: spotifyLibrary.playlists,
            title: { $0.name },
            action: { [weak self] playlist in
                self?.openPlaylist(playlist)
            }
        )
    }

    private var playlistTrackMenuItems: [MenuItem] {
        guard let selectedPlaylist else { return [MenuItem(title: "No Playlist", action: .none)] }
        let tracks = spotifyLibrary.tracks(for: selectedPlaylist)
        return spotifyTrackItems(emptyTitle: "No Songs", tracks: tracks)
    }

    private var artistMenuItems: [MenuItem] {
        spotifyCollectionItems(
            emptyTitle: "No Artists",
            values: spotifyLibrary.artists,
            title: { $0.displayName },
            action: { [weak self] artist in
                self?.playSpotifyURI(artist.uri, isContext: true)
            }
        )
    }

    private var albumMenuItems: [MenuItem] {
        spotifyCollectionItems(
            emptyTitle: "No Albums",
            values: spotifyLibrary.albums,
            title: { $0.name },
            action: { [weak self] album in
                self?.openAlbum(album)
            }
        )
    }

    private var albumTrackMenuItems: [MenuItem] {
        guard let selectedAlbum else { return [MenuItem(title: "No Album", action: .none)] }
        let tracks = spotifyLibrary.tracks(for: selectedAlbum)
        return spotifyTrackItems(emptyTitle: "No Songs", tracks: tracks)
    }

    private var savedTrackMenuItems: [MenuItem] {
        spotifyTrackItems(emptyTitle: "No Songs", tracks: spotifyLibrary.savedTracks)
    }

    // For color selection screen
    var colorCount: Int {
        iPodColor.allCases.count
    }

    // MARK: - Initialization

    init() {
        self.selectedColor = PersistenceManager.shared.selectedColor
        self.soundEnabled = PersistenceManager.shared.soundEnabled
        self.hapticEnabled = PersistenceManager.shared.hapticEnabled
        self.autoLaunchEnabled = LaunchAtLoginManager.shared.isEnabled

        // Forward playerViewModel changes to trigger view updates
        playerCancellable = playerViewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        authCancellable = SpotifyAuthManager.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        libraryCancellable = SpotifyLibraryManager.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    // MARK: - Click Wheel Actions

    func rotateWheel(delta: CGFloat) {
        // Each rotation "click" moves selection by 1
        let direction = delta > 0 ? 1 : -1
        moveSelection(by: direction)
    }

    func scroll(delta: CGFloat) {
        // Accumulate scroll for smoother trackpad experience
        scrollAccumulator += delta

        // Check if we've scrolled enough to trigger a selection change
        while abs(scrollAccumulator) >= scrollThreshold {
            let direction = scrollAccumulator > 0 ? -1 : 1 // Inverted for natural scrolling
            moveSelection(by: direction)
            scrollAccumulator -= (scrollAccumulator > 0 ? scrollThreshold : -scrollThreshold)
        }
    }

    private func moveSelection(by offset: Int) {
        switch currentScreen {
        case .main, .settings, .music, .playlists, .playlistTracks, .artists, .albums, .albumTracks, .savedTracks:
            let itemCount = currentMenuItems.count
            guard itemCount > 0 else { return }

            let newIndex = selectedIndex + offset
            let clampedIndex = max(0, min(itemCount - 1, newIndex))

            if clampedIndex != selectedIndex {
                selectedIndex = clampedIndex
                playScrollFeedback()
            }

        case .colorSelection:
            let itemCount = colorCount
            guard itemCount > 0 else { return }

            let newIndex = selectedIndex + offset
            let clampedIndex = max(0, min(itemCount - 1, newIndex))

            if clampedIndex != selectedIndex {
                selectedIndex = clampedIndex
                playScrollFeedback()
            }

        case .nowPlaying:
            // On now playing, wheel controls volume
            let volumeDelta = Float(offset) * volumeStep
            playerViewModel.adjustVolume(by: volumeDelta)
            playScrollFeedback()
        }
    }

    func centerButtonPressed() {
        playButtonFeedback()

        switch currentScreen {
        case .main, .settings, .music, .playlists, .playlistTracks, .artists, .albums, .albumTracks, .savedTracks:
            let items = currentMenuItems
            guard selectedIndex < items.count else { return }

            let item = items[selectedIndex]

            switch item.action {
            case .navigate(let screen):
                navigateTo(screen)
            case .togglePlayPause:
                playerViewModel.togglePlayPause()
            case .custom(let action):
                action()
            case .none:
                // Placeholder item - do nothing
                break
            }

        case .colorSelection:
            // Select the highlighted color
            let colors = iPodColor.allCases
            guard selectedIndex < colors.count else { return }
            selectedColor = colors[selectedIndex]

        case .nowPlaying:
            // Toggle play/pause
            playerViewModel.togglePlayPause()
        }
    }

    func menuButtonPressed() {
        playButtonFeedback()
        goBack()
    }

    func playPauseButtonPressed() {
        playButtonFeedback()
        playerViewModel.togglePlayPause()
    }

    func nextButtonPressed() {
        playButtonFeedback()
        playerViewModel.nextTrack()
    }

    func previousButtonPressed() {
        playButtonFeedback()
        playerViewModel.previousTrack()
    }

    // MARK: - Navigation

    private func navigateTo(_ screen: MenuScreen) {
        navigationStack.append(currentScreen)
        transitionDirection = .trailing // Push right when navigating forward

        let newIndex: Int
        if screen == .colorSelection,
           let colorIndex = iPodColor.allCases.firstIndex(of: selectedColor) {
            newIndex = colorIndex
        } else {
            newIndex = 0
        }

        withAnimation(iPodAnimation.standard) {
            currentScreen = screen
            selectedIndex = newIndex
        }

        loadContentIfNeeded(for: screen)
    }

    func goBack() {
        guard let previousScreen = navigationStack.popLast() else { return }
        transitionDirection = .leading // Push left when going back
        withAnimation(iPodAnimation.standard) {
            currentScreen = previousScreen
            selectedIndex = 0
        }
    }

    func selectColor(_ color: iPodColor) {
        selectedColor = color
        playButtonFeedback()
    }

    private func toggleAutoLaunch() {
        let newValue = !autoLaunchEnabled
        if LaunchAtLoginManager.shared.setEnabled(newValue) {
            autoLaunchEnabled = newValue
        }
    }

    private func loadContentIfNeeded(for screen: MenuScreen) {
        switch screen {
        case .playlists, .artists, .albums, .savedTracks:
            Task { await spotifyLibrary.loadLibraryIfNeeded() }
        default:
            break
        }
    }

    private func spotifyCollectionItems<T>(
        emptyTitle: String,
        values: [T],
        title: @escaping (T) -> String,
        action: @escaping (T) -> Void
    ) -> [MenuItem] {
        if let stateItems = spotifyStateItems(emptyTitle: emptyTitle), values.isEmpty {
            return stateItems
        }

        return values.map { value in
            MenuItem(title: title(value), action: .custom {
                action(value)
            })
        }
    }

    private func spotifyTrackItems(emptyTitle: String, tracks: [SpotifyTrack]) -> [MenuItem] {
        if let stateItems = spotifyStateItems(emptyTitle: emptyTitle), tracks.isEmpty {
            return stateItems
        }

        return tracks.map { track in
            MenuItem(title: track.name, action: .custom { [weak self] in
                self?.playSpotifyURI(track.uri, isContext: false)
            })
        }
    }

    private func spotifyStateItems(emptyTitle: String) -> [MenuItem]? {
        let authManager = SpotifyAuthManager.shared

        if !authManager.isSignedIn {
            return [MenuItem(title: "Spotify: Sign In", action: .custom {
                authManager.signIn()
            })]
        }

        if spotifyLibrary.isLoading {
            return [MenuItem(title: "Loading...", action: .none)]
        }

        if spotifyLibrary.errorMessage != nil {
            return [MenuItem(title: "Retry Spotify", action: .custom {
                Task { await self.spotifyLibrary.reloadLibrary() }
            })]
        }

        return [MenuItem(title: emptyTitle, action: .none)]
    }

    private func openPlaylist(_ playlist: SpotifyPlaylist) {
        selectedPlaylist = playlist
        navigateTo(.playlistTracks)
        Task { await spotifyLibrary.loadTracks(for: playlist) }
    }

    private func openAlbum(_ album: SpotifyAlbum) {
        selectedAlbum = album
        navigateTo(.albumTracks)
        Task { await spotifyLibrary.loadTracks(for: album) }
    }

    private func playSpotifyURI(_ uri: String, isContext: Bool) {
        playerViewModel.playSpotifyURI(uri, isContext: isContext)
        if currentScreen != .nowPlaying {
            navigateTo(.nowPlaying)
        }
    }

    // MARK: - Feedback
    // iPod 5G used one identical piezo click for all interactions.
    // The perceived difference: scroll ticks = piezo only (light haptic),
    // button presses = piezo + mechanical rubber dome (stronger haptic).
    // Fire haptic FIRST (higher latency ~5-15ms) then audio (~1-3ms)
    // to keep them perceptually synchronized.

    private func playScrollFeedback() {
        if hapticEnabled {
            HapticManager.shared.scrollTick()
        }
        if soundEnabled {
            SoundManager.shared.playClick()
        }
    }

    private func playButtonFeedback() {
        if hapticEnabled {
            HapticManager.shared.buttonPress()
        }
        if soundEnabled {
            SoundManager.shared.playClick()
        }
    }
}
