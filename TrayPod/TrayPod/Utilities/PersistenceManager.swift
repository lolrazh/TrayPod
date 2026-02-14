import Foundation

class PersistenceManager {
    static let shared = PersistenceManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let selectedColor = "selectedColor"
        static let soundEnabled = "soundEnabled"
        static let hapticEnabled = "hapticEnabled"
        static let autoLaunchEnabled = "autoLaunchEnabled"
    }

    private init() {}

    var selectedColor: iPodColor {
        get {
            guard let rawValue = defaults.string(forKey: Keys.selectedColor),
                  let color = iPodColor(rawValue: rawValue) else {
                return .white
            }
            return color
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.selectedColor)
        }
    }

    var soundEnabled: Bool {
        get { defaults.object(forKey: Keys.soundEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.soundEnabled) }
    }

    var hapticEnabled: Bool {
        get { defaults.object(forKey: Keys.hapticEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.hapticEnabled) }
    }

    var autoLaunchEnabled: Bool {
        get { defaults.object(forKey: Keys.autoLaunchEnabled) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Keys.autoLaunchEnabled) }
    }

    // MARK: - Spotify Cookie Storage

    struct SpotifyCookies: Codable {
        let spDc: String
        let spT: String?
    }

    func saveSpotifyCookies(spDc: String, spT: String?) {
        let cookies = SpotifyCookies(spDc: spDc, spT: spT)
        let url = cookieStoragePath()
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? JSONEncoder().encode(cookies).write(to: url)
    }

    func loadSpotifyCookies() -> SpotifyCookies? {
        let url = cookieStoragePath()
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SpotifyCookies.self, from: data)
    }

    func clearSpotifyCookies() {
        try? FileManager.default.removeItem(at: cookieStoragePath())
    }

    private func cookieStoragePath() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("TrayPod/cookies.json")
    }
}
