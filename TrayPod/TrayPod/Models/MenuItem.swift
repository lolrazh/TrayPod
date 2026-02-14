import Foundation

struct MenuItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let icon: String?
    let action: MenuAction

    // iPod 5G: Text-only menus, icon is optional and defaults to nil
    init(title: String, icon: String? = nil, action: MenuAction) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    static func == (lhs: MenuItem, rhs: MenuItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum MenuAction: Equatable {
    case navigate(MenuScreen)
    case togglePlayPause
    case custom(() -> Void)
    case none  // Placeholder for non-functional menu items

    static func == (lhs: MenuAction, rhs: MenuAction) -> Bool {
        switch (lhs, rhs) {
        case (.navigate(let a), .navigate(let b)):
            return a == b
        case (.togglePlayPause, .togglePlayPause):
            return true
        case (.none, .none):
            return true
        case (.custom, .custom):
            return false // Custom actions can't be compared
        default:
            return false
        }
    }
}

enum MenuScreen: Hashable {
    case main
    case nowPlaying
    case settings
    case colorSelection
    case musicMenu
    case playlists
    case playlistDetail(id: String, name: String)
    case albums
    case albumDetail(id: String, name: String)
    case songs
    case search
    case searchResults
}
