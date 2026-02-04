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

    // MARK: - Menu Items

    var mainMenuItems: [MenuItem] {
        [
            MenuItem(title: "Now Playing", icon: "play.fill", action: .navigate(.nowPlaying)),
            MenuItem(title: "Settings", icon: "gearshape.fill", action: .navigate(.settings))
        ]
    }

    var settingsMenuItems: [MenuItem] {
        [
            MenuItem(title: "Color", icon: "paintpalette.fill", action: .navigate(.colorSelection)),
            MenuItem(title: "Sounds: \(soundEnabled ? "On" : "Off")", icon: "speaker.wave.2.fill", action: .custom { [weak self] in
                self?.soundEnabled.toggle()
            }),
            MenuItem(title: "Haptics: \(hapticEnabled ? "On" : "Off")", icon: "hand.tap.fill", action: .custom { [weak self] in
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

    // MARK: - Initialization

    init() {
        self.selectedColor = PersistenceManager.shared.selectedColor
        self.soundEnabled = PersistenceManager.shared.soundEnabled
        self.hapticEnabled = PersistenceManager.shared.hapticEnabled
    }

    // MARK: - Click Wheel Actions

    func rotateWheel(delta: CGFloat) {
        // Positive delta = clockwise = scroll down
        // Negative delta = counter-clockwise = scroll up
        let sensitivity: CGFloat = 0.15
        let steps = Int(delta / sensitivity)

        if steps != 0 {
            let newIndex = selectedIndex + steps
            let itemCount = currentMenuItems.count

            if itemCount > 0 {
                selectedIndex = max(0, min(itemCount - 1, newIndex))
                playFeedback()
            }
        }
    }

    func scroll(delta: CGFloat) {
        // Trackpad scroll - similar to wheel rotation
        let sensitivity: CGFloat = 30.0
        let steps = Int(delta / sensitivity)

        if steps != 0 {
            let newIndex = selectedIndex - steps // Inverted for natural scrolling
            let itemCount = currentMenuItems.count

            if itemCount > 0 {
                selectedIndex = max(0, min(itemCount - 1, newIndex))
                playFeedback()
            }
        }
    }

    func centerButtonPressed() {
        playFeedback()

        let items = currentMenuItems
        guard selectedIndex < items.count else { return }

        let item = items[selectedIndex]

        switch item.action {
        case .navigate(let screen):
            navigateTo(screen)
        case .togglePlayPause:
            // Will be implemented with PlayerViewModel
            break
        case .custom(let action):
            action()
        }
    }

    func menuButtonPressed() {
        playFeedback()
        goBack()
    }

    func playPauseButtonPressed() {
        playFeedback()
        // Will be implemented with PlayerViewModel
    }

    func nextButtonPressed() {
        playFeedback()
        // Will be implemented with PlayerViewModel
    }

    func previousButtonPressed() {
        playFeedback()
        // Will be implemented with PlayerViewModel
    }

    // MARK: - Navigation

    private func navigateTo(_ screen: MenuScreen) {
        navigationStack.append(currentScreen)
        currentScreen = screen
        selectedIndex = 0
    }

    func goBack() {
        if let previousScreen = navigationStack.popLast() {
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
