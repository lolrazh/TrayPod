import Foundation
import AppKit

// MARK: - Haptic Manager using NSHapticFeedbackManager
// Uses double-tap pattern with levelChange for stronger perceived feedback

class HapticManager {
    static let shared = HapticManager()

    enum HapticType {
        case weak      // Single light tap
        case medium    // Single strong tap
        case strong    // Double-tap pattern (feels more substantial)
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
            performer.perform(.levelChange, performanceTime: .now)

        case .strong:
            // Double-tap pattern: main tap + echo tap
            // Creates "thicker" perceived feedback
            performer.perform(.levelChange, performanceTime: .now)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.015) {
                performer.perform(.levelChange, performanceTime: .now)
            }
        }
    }
}
