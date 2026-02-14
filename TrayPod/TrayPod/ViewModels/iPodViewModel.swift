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

    // Player state - forward changes to trigger view updates
    let playerViewModel: PlayerViewModel
    private let connectService: SpotifyConnectService
    private var playerCancellable: AnyCancellable?

    // Scroll accumulator for smooth scrolling
    private var scrollAccumulator: CGFloat = 0
    private let scrollThreshold: CGFloat = 25.0

    // Volume control on Now Playing
    private let volumeStep: Float = 0.05

    // MARK: - Library Data

    @Published var playlistItems: [Playlist] = []
    @Published var albumItems: [Album] = []
    @Published var songItems: [Track] = []
    @Published var detailTracks: [Track] = []
    @Published var searchQuery: String = ""
    @Published var searchResults: SearchResults = SearchResults(tracks: [], albums: [], playlists: [])
    @Published var isLoadingData: Bool = false

    // MARK: - Menu Items (iPod 5G style - text only, no icons)

    var mainMenuItems: [MenuItem] {
        [
            MenuItem(title: "Music", action: .navigate(.musicMenu)),
            MenuItem(title: "Photos", action: .none),     // Placeholder - not functional
            MenuItem(title: "Videos", action: .none),     // Placeholder - not functional
            MenuItem(title: "Extras", action: .none),     // Placeholder - not functional
            MenuItem(title: "Settings", action: .navigate(.settings)),
            MenuItem(title: "Shuffle Songs", action: .custom { [weak self] in
                self?.playerViewModel.togglePlayPause()  // Just play for now
            })
        ]
    }

    var musicMenuItems: [MenuItem] {
        [
            MenuItem(title: "Playlists", action: .navigate(.playlists)),
            MenuItem(title: "Albums", action: .navigate(.albums)),
            MenuItem(title: "Songs", action: .navigate(.songs)),
            MenuItem(title: "Now Playing", action: .navigate(.nowPlaying)),
        ]
    }

    var settingsMenuItems: [MenuItem] {
        [
            MenuItem(title: "Color", action: .navigate(.colorSelection)),
            MenuItem(title: "Sounds: \(soundEnabled ? "On" : "Off")", action: .custom { [weak self] in
                self?.soundEnabled.toggle()
            }),
            MenuItem(title: "Haptics: \(hapticEnabled ? "On" : "Off")", action: .custom { [weak self] in
                self?.hapticEnabled.toggle()
            })
        ]
    }

    var currentMenuItems: [MenuItem] {
        switch currentScreen {
        case .main:
            return mainMenuItems
        case .musicMenu:
            return musicMenuItems
        case .settings:
            return settingsMenuItems
        case .playlists:
            if isLoadingData { return [MenuItem(title: "Loading...", action: .none)] }
            return playlistItems.map { p in
                MenuItem(title: p.name, action: .navigate(.playlistDetail(id: p.id, name: p.name)))
            }
        case .albums:
            if isLoadingData { return [MenuItem(title: "Loading...", action: .none)] }
            return albumItems.map { a in
                MenuItem(title: a.name, action: .navigate(.albumDetail(id: a.id, name: a.name)))
            }
        case .songs:
            if isLoadingData { return [MenuItem(title: "Loading...", action: .none)] }
            return songItems.map { t in
                MenuItem(title: "\(t.title) - \(t.artist)", action: .custom { [weak self] in
                    self?.connectService.playTrack(uri: t.id)
                    self?.navigateTo(.nowPlaying)
                })
            }
        case .playlistDetail, .albumDetail:
            if isLoadingData { return [MenuItem(title: "Loading...", action: .none)] }
            return detailTracks.map { t in
                MenuItem(title: "\(t.title) - \(t.artist)", action: .custom { [weak self] in
                    self?.connectService.playTrack(uri: t.id)
                    self?.navigateTo(.nowPlaying)
                })
            }
        case .searchResults:
            return searchResultMenuItems
        case .nowPlaying, .colorSelection, .search:
            return []
        }
    }

    private var searchResultMenuItems: [MenuItem] {
        var items: [MenuItem] = []
        if !searchResults.tracks.isEmpty {
            items.append(MenuItem(title: "-- Songs --", action: .none))
            for t in searchResults.tracks.prefix(5) {
                items.append(MenuItem(title: "\(t.title) - \(t.artist)", action: .custom { [weak self] in
                    self?.connectService.playTrack(uri: t.id)
                    self?.navigateTo(.nowPlaying)
                }))
            }
        }
        if !searchResults.albums.isEmpty {
            items.append(MenuItem(title: "-- Albums --", action: .none))
            for a in searchResults.albums.prefix(5) {
                items.append(MenuItem(title: a.name, action: .navigate(.albumDetail(id: a.id, name: a.name))))
            }
        }
        if !searchResults.playlists.isEmpty {
            items.append(MenuItem(title: "-- Playlists --", action: .none))
            for p in searchResults.playlists.prefix(5) {
                items.append(MenuItem(title: p.name, action: .navigate(.playlistDetail(id: p.id, name: p.name))))
            }
        }
        if items.isEmpty {
            items.append(MenuItem(title: "No results", action: .none))
        }
        return items
    }

    // For color selection screen
    var colorCount: Int {
        iPodColor.allCases.count
    }

    // MARK: - Initialization

    init() {
        let service = SpotifyConnectService()
        self.connectService = service
        self.playerViewModel = PlayerViewModel(connectService: service)
        self.selectedColor = PersistenceManager.shared.selectedColor
        self.soundEnabled = PersistenceManager.shared.soundEnabled
        self.hapticEnabled = PersistenceManager.shared.hapticEnabled

        // Forward playerViewModel changes to trigger view updates
        playerCancellable = playerViewModel.objectWillChange
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
        case .main, .settings, .musicMenu, .playlists, .albums, .songs,
             .playlistDetail, .albumDetail, .searchResults:
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

        case .search:
            // Scroll cycles through characters in SearchInputView
            let chars = searchCharacters
            guard !chars.isEmpty else { return }
            searchCharIndex = (searchCharIndex + offset + chars.count) % chars.count
            playScrollFeedback()

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
        case .main, .settings, .musicMenu, .playlists, .albums, .songs,
             .playlistDetail, .albumDetail, .searchResults:
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

        case .search:
            // Center button confirms the current character
            let chars = searchCharacters
            guard searchCharIndex < chars.count else { return }
            searchQuery.append(chars[searchCharIndex])
            searchCharIndex = 0

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
        if currentScreen == .search && !searchQuery.isEmpty {
            submitSearch()
        } else {
            goBack()
        }
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
        if currentScreen == .search {
            deleteSearchChar()
        } else {
            playerViewModel.previousTrack()
        }
    }

    // MARK: - Search Input

    @Published var searchCharIndex: Int = 0
    let searchCharacters: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ")

    // MARK: - Navigation

    func navigateTo(_ screen: MenuScreen) {
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

        // Trigger data loading for library screens
        switch screen {
        case .playlists:
            loadPlaylists()
        case .albums:
            loadAlbums()
        case .songs:
            loadSongs()
        case .playlistDetail(let id, _):
            loadPlaylistTracks(id: id)
        case .albumDetail(let id, _):
            loadAlbumTracks(id: id)
        case .search:
            searchQuery = ""
            searchCharIndex = 0
        default:
            break
        }
    }

    func goBack() {
        guard let previousScreen = navigationStack.popLast() else { return }
        transitionDirection = .leading // Push left when going back
        withAnimation(iPodAnimation.standard) {
            currentScreen = previousScreen
            selectedIndex = 0
        }
    }

    // MARK: - Search

    func submitSearch() {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        isLoadingData = true
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let results = try await self.connectService.search(query: query)
                await MainActor.run {
                    self.searchResults = results
                    self.isLoadingData = false
                    self.navigateTo(.searchResults)
                }
            } catch {
                print("[iPodVM] Search error: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingData = false
                }
            }
        }
    }

    func deleteSearchChar() {
        if !searchQuery.isEmpty {
            searchQuery.removeLast()
        }
    }

    // MARK: - Data Loading

    private func loadPlaylists() {
        isLoadingData = true
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let playlists = try await self.connectService.getPlaylists()
                await MainActor.run {
                    self.playlistItems = playlists
                    self.isLoadingData = false
                }
            } catch {
                print("[iPodVM] Load playlists error: \(error.localizedDescription)")
                await MainActor.run { self.isLoadingData = false }
            }
        }
    }

    private func loadAlbums() {
        isLoadingData = true
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let albums = try await self.connectService.getSavedAlbums()
                await MainActor.run {
                    self.albumItems = albums
                    self.isLoadingData = false
                }
            } catch {
                print("[iPodVM] Load albums error: \(error.localizedDescription)")
                await MainActor.run { self.isLoadingData = false }
            }
        }
    }

    private func loadSongs() {
        isLoadingData = true
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let tracks = try await self.connectService.getSavedTracks(offset: 0, limit: 50)
                await MainActor.run {
                    self.songItems = tracks
                    self.isLoadingData = false
                }
            } catch {
                print("[iPodVM] Load songs error: \(error.localizedDescription)")
                await MainActor.run { self.isLoadingData = false }
            }
        }
    }

    private func loadPlaylistTracks(id: String) {
        isLoadingData = true
        detailTracks = []
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let tracks = try await self.connectService.getPlaylistTracks(id: id)
                await MainActor.run {
                    self.detailTracks = tracks
                    self.isLoadingData = false
                }
            } catch {
                print("[iPodVM] Load playlist tracks error: \(error.localizedDescription)")
                await MainActor.run { self.isLoadingData = false }
            }
        }
    }

    private func loadAlbumTracks(id: String) {
        isLoadingData = true
        detailTracks = []
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let tracks = try await self.connectService.getAlbumTracks(id: id)
                await MainActor.run {
                    self.detailTracks = tracks
                    self.isLoadingData = false
                }
            } catch {
                print("[iPodVM] Load album tracks error: \(error.localizedDescription)")
                await MainActor.run { self.isLoadingData = false }
            }
        }
    }

    func selectColor(_ color: iPodColor) {
        selectedColor = color
        playButtonFeedback()
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
