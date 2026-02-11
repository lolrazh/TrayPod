import SwiftUI
import Combine
import AppKit

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

    // Player state - forward changes to trigger view updates
    let playerViewModel = PlayerViewModel()
    let browseViewModel = BrowseViewModel()
    private var playerCancellable: AnyCancellable?
    private var authCancellable: AnyCancellable?
    private var browseCancellable: AnyCancellable?

    // Scroll accumulator for smooth scrolling
    private var scrollAccumulator: CGFloat = 0
    private let scrollThreshold: CGFloat = 25.0

    // Volume control on Now Playing
    private let volumeStep: Float = 0.05
    private let merchURLInfoKey = "TrayPodMerchURL"

    // MARK: - Menu Items (iPod 5G style - text only, no icons)

    var mainMenuItems: [MenuItem] {
        var items: [MenuItem] = []

        // Show Now Playing only when a track is active
        if playerViewModel.state.currentTrack != nil {
            items.append(MenuItem(title: "Now Playing", action: .navigate(.nowPlaying)))
        }

        if SpotifyAuthManager.shared.isSignedIn {
            items.append(MenuItem(title: "Playlists", action: .navigate(.playlists)))
            items.append(MenuItem(title: "Artists", action: .navigate(.artists)))
            items.append(MenuItem(title: "Songs", action: .navigate(.songs)))
        } else {
            items.append(MenuItem(title: "Music", action: .navigate(.nowPlaying)))
        }

        items.append(MenuItem(title: "Settings", action: .navigate(.settings)))
        items.append(MenuItem(title: "Shuffle Songs", action: .custom { [weak self] in
            self?.playerViewModel.togglePlayPause()
        }))

        return items
    }

    var settingsMenuItems: [MenuItem] {
        var items: [MenuItem] = [
            MenuItem(title: "Color", action: .navigate(.colorSelection)),
            MenuItem(title: "Sounds: \(soundEnabled ? "On" : "Off")", action: .custom { [weak self] in
                self?.soundEnabled.toggle()
            }),
            MenuItem(title: "Haptics: \(hapticEnabled ? "On" : "Off")", action: .custom { [weak self] in
                self?.hapticEnabled.toggle()
            })
        ]

        // Spotify sign in/out
        if SpotifyAuthManager.shared.isSignedIn {
            items.append(MenuItem(title: "Sign Out of Spotify", action: .custom {
                SpotifyAuthManager.shared.signOut()
            }))
        } else {
            items.append(MenuItem(title: "Sign In to Spotify", action: .custom {
                SpotifyAuthManager.shared.startSignIn()
            }))
        }

        return items
    }

    var currentMenuItems: [MenuItem] {
        switch currentScreen {
        case .main:
            return mainMenuItems
        case .settings:
            return settingsMenuItems
        case .playlists:
            return playlistMenuItems
        case .playlistDetail:
            return playlistDetailMenuItems
        case .artists:
            return artistMenuItems
        case .songs:
            return songMenuItems
        case .nowPlaying, .colorSelection:
            return []
        }
    }

    private var playlistMenuItems: [MenuItem] {
        guard case .loaded(let playlists) = browseViewModel.playlistsState else { return [] }
        return playlists.map { playlist in
            MenuItem(title: playlist.name, action: .navigate(.playlistDetail(id: playlist.id, name: playlist.name)))
        }
    }

    private var playlistDetailMenuItems: [MenuItem] {
        guard case .loaded(let tracks) = browseViewModel.playlistTracksState else { return [] }
        return tracks.map { track in
            MenuItem(title: track.title, action: .custom { [weak self] in
                self?.playTrack(track)
            })
        }
    }

    private var artistMenuItems: [MenuItem] {
        guard case .loaded(let artists) = browseViewModel.artistsState else { return [] }
        return artists.map { artist in
            MenuItem(title: artist.name, action: .none)
        }
    }

    private var songMenuItems: [MenuItem] {
        guard case .loaded(let tracks) = browseViewModel.songsState else { return [] }
        return tracks.map { track in
            MenuItem(title: track.title, action: .custom { [weak self] in
                self?.playTrack(track)
            })
        }
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

        // Forward playerViewModel changes to trigger view updates
        playerCancellable = playerViewModel.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Forward auth state changes to trigger settings menu update
        authCancellable = SpotifyAuthManager.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                // Clear browse cache on sign-out
                if !SpotifyAuthManager.shared.isSignedIn {
                    self?.browseViewModel.clearCache()
                }
            }

        // Forward browse state changes to trigger menu updates
        browseCancellable = browseViewModel.objectWillChange
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
        case .main, .settings, .playlists, .playlistDetail, .artists, .songs:
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
        case .main, .settings, .playlists, .playlistDetail, .artists, .songs:
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
                break
            }

        case .colorSelection:
            let colors = iPodColor.allCases
            guard selectedIndex < colors.count else { return }
            selectedColor = colors[selectedIndex]

        case .nowPlaying:
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

        // Trigger async data loading for browse screens
        switch screen {
        case .playlists:
            browseViewModel.loadPlaylists()
        case .playlistDetail(let id, _):
            browseViewModel.loadPlaylistTracks(id: id)
        case .artists:
            browseViewModel.loadArtists()
        case .songs:
            browseViewModel.loadSongs()
        default:
            break
        }

        withAnimation(iPodAnimation.standard) {
            currentScreen = screen
            selectedIndex = newIndex
        }
    }

    // MARK: - Play Track

    func playTrack(_ track: Track) {
        guard let uri = track.spotifyURI else { return }

        // Try AppleScript first (desktop app), fall back to Web API
        if playerViewModel.spotifyService.isRunning {
            let script = """
                tell application "Spotify"
                    play track "\(uri)"
                end tell
            """
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
        } else {
            Task {
                try? await SpotifyWebAPIClient.shared.play(trackURIs: [uri])
            }
        }

        navigateTo(.nowPlaying)
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

    private func openMerchURL() {
        guard
            let merchURLString = Bundle.main.object(forInfoDictionaryKey: merchURLInfoKey) as? String,
            let merchURL = URL(string: merchURLString)
        else { return }

        NSWorkspace.shared.open(merchURL)
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
