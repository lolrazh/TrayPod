import Foundation
import AppKit

// MARK: - Haptic Manager using NSHapticFeedbackManager
// iPod 5G feedback: scroll ticks get a single tap, button presses
// get a double-tap pattern to simulate the mechanical click of the
// rubber dome switch underneath the click wheel surface.

class HapticManager {
    static let shared = HapticManager()

    private init() {}

    /// Scroll tick — single levelChange tap (wheel rotation / volume step)
    func scrollTick() {
        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.levelChange, performanceTime: .now)
    }

    /// Button press — double-tap pattern simulating mechanical click
    /// The 15ms-spaced taps blur into one "thicker" perceived click,
    /// matching how the real iPod's piezo + rubber dome felt together.
    func buttonPress() {
        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.levelChange, performanceTime: .now)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.015) {
            performer.perform(.levelChange, performanceTime: .now)
        }
    }
}
