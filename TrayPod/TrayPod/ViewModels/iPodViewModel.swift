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
    let playerViewModel = PlayerViewModel()
    private var playerCancellable: AnyCancellable?

    // Scroll accumulator for smooth scrolling
    private var scrollAccumulator: CGFloat = 0
    private let scrollThreshold: CGFloat = 25.0

    // Volume control on Now Playing
    private let volumeStep: Float = 0.05

    // MARK: - Menu Items (iPod 5G style - text only, no icons)

    var mainMenuItems: [MenuItem] {
        [
            MenuItem(title: "Music", action: .navigate(.nowPlaying)),
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
        case .settings:
            return settingsMenuItems
        case .nowPlaying, .colorSelection:
            return []
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
        case .main, .settings:
            let itemCount = currentMenuItems.count
            guard itemCount > 0 else { return }

            let newIndex = selectedIndex + offset
            let clampedIndex = max(0, min(itemCount - 1, newIndex))

            if clampedIndex != selectedIndex {
                selectedIndex = clampedIndex
                playFeedback()
            }

        case .colorSelection:
            let itemCount = colorCount
            guard itemCount > 0 else { return }

            let newIndex = selectedIndex + offset
            let clampedIndex = max(0, min(itemCount - 1, newIndex))

            if clampedIndex != selectedIndex {
                selectedIndex = clampedIndex
                playFeedback()
            }

        case .nowPlaying:
            // On now playing, wheel controls volume
            let volumeDelta = Float(offset) * volumeStep
            playerViewModel.adjustVolume(by: volumeDelta)
            playFeedback()
        }
    }

    func centerButtonPressed() {
        playFeedback()

        switch currentScreen {
        case .main, .settings:
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
        playFeedback()
        goBack()
    }

    func playPauseButtonPressed() {
        playFeedback()
        playerViewModel.togglePlayPause()
    }

    func nextButtonPressed() {
        playFeedback()
        playerViewModel.nextTrack()
    }

    func previousButtonPressed() {
        playFeedback()
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
        playFeedback()
    }

    // MARK: - Feedback

    private func playFeedback() {
        if soundEnabled {
            SoundManager.shared.playClick()
        }
        if hapticEnabled {
            HapticManager.shared.click()
        }
    }
}
