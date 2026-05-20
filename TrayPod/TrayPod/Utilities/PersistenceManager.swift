import Foundation

class PersistenceManager {
    static let shared = PersistenceManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let selectedColor = "selectedColor"
        static let soundEnabled = "soundEnabled"
        static let hapticEnabled = "hapticEnabled"
        static let autoLaunchEnabled = "autoLaunchEnabled"
        static let playerVolume = "playerVolume"
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

    var playerVolume: Float {
        get {
            guard defaults.object(forKey: Keys.playerVolume) != nil else { return 0.5 }
            return max(0, min(1, defaults.float(forKey: Keys.playerVolume)))
        }
        set {
            defaults.set(max(0, min(1, newValue)), forKey: Keys.playerVolume)
        }
    }
}
