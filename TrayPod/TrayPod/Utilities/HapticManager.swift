import Foundation
import AppKit

// MARK: - Haptic Manager using NSHapticFeedbackManager
// iPod 5G feedback: scroll ticks get a single tap, button presses
// get a double-tap pattern to simulate the mechanical click of the
// rubber dome switch underneath the click wheel surface.

class HapticManager {
    static let shared = HapticManager()

    // Taptic Engine needs ~10ms to actuate + settle. Firing faster
    // than this causes the system to swallow some ticks silently.
    private var lastScrollHapticTime: CFAbsoluteTime = 0
    private let minScrollInterval: CFAbsoluteTime = 0.025

    private init() {}

    /// Scroll tick — levelChange tap (wheel rotation / volume step)
    /// Designed for discrete value stepping, feels like a light detent.
    /// Debounced at 25ms to stay within the Taptic Engine's reliable range.
    func scrollTick() {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastScrollHapticTime >= minScrollInterval else { return }
        lastScrollHapticTime = now

        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.levelChange, performanceTime: .now)
    }

    /// Button press — alignment snap (heavier than levelChange)
    /// Uses .alignment instead of a double-tap pattern because:
    /// - asyncAfter has ~1ms jitter making double-taps inconsistent
    /// - The Taptic Engine needs ~10ms recovery, so rapid taps coalesce
    /// - .alignment is a physically distinct, heavier actuator pattern
    ///   designed for "snapping to position" — feels like a mechanical click
    func buttonPress() {
        let performer = NSHapticFeedbackManager.defaultPerformer
        performer.perform(.alignment, performanceTime: .now)
    }
}
