import Foundation
import AppKit

// MARK: - Haptic Manager using NSHapticFeedbackManager
// Based on working implementation from freewrite app

class HapticManager {
    static let shared = HapticManager()

    enum HapticType {
        case weak
        case medium
        case strong
    }

    private init() {}

    func click() {
        tap(type: .strong)
    }

    func tap(type: HapticType = .strong) {
        let performer = NSHapticFeedbackManager.defaultPerformer

        switch type {
        case .weak:
            performer.perform(.generic, performanceTime: .now)
        case .medium:
            performer.perform(.generic, performanceTime: .now)
        case .strong:
            performer.perform(.generic, performanceTime: .now)
        }
    }
}
