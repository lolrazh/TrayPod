import AppKit

class HapticManager {
    static let shared = HapticManager()

    private init() {}

    func click() {
        // Use alignment for stronger, more noticeable feedback
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .now
        )
    }

    func strong() {
        // Double tap for extra emphasis
        NSHapticFeedbackManager.defaultPerformer.perform(
            .levelChange,
            performanceTime: .now
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSHapticFeedbackManager.defaultPerformer.perform(
                .levelChange,
                performanceTime: .now
            )
        }
    }
}
