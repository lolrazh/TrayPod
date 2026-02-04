import Foundation

struct MenuItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let icon: String?
    let action: MenuAction

    static func == (lhs: MenuItem, rhs: MenuItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum MenuAction: Equatable {
    case navigate(MenuScreen)
    case togglePlayPause
    case custom(() -> Void)

    static func == (lhs: MenuAction, rhs: MenuAction) -> Bool {
        switch (lhs, rhs) {
        case (.navigate(let a), .navigate(let b)):
            return a == b
        case (.togglePlayPause, .togglePlayPause):
            return true
        case (.custom, .custom):
            return false // Custom actions can't be compared
        default:
            return false
        }
    }
}

enum MenuScreen: Equatable {
    case main
    case nowPlaying
    case settings
    case colorSelection
}
