import AppKit

class HapticManager {
    static let shared = HapticManager()

    private init() {}

    func click() {
        // Triple burst for maximum intensity
        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.levelChange, performanceTime: .now)
        performer.perform(.levelChange, performanceTime: .now)
        performer.perform(.levelChange, performanceTime: .now)
    }
}
