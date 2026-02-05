import SwiftUI

/// Global animation constants for consistent iPod-style transitions throughout the app
struct iPodAnimation {
    /// Standard animation for most transitions (menu navigation, bar swaps)
    static let standard = Animation.easeInOut(duration: 0.25)

    /// Quick animation for press feedback, selection changes
    static let quick = Animation.easeInOut(duration: 0.15)

    /// Instant snap for immediate feedback
    static let snap = Animation.easeInOut(duration: 0.08)
}

/// Global transitions for consistent slide behavior
struct iPodTransition {
    /// Slide in from left edge
    static let slideLeft = AnyTransition.move(edge: .leading)

    /// Slide in from right edge
    static let slideRight = AnyTransition.move(edge: .trailing)

    /// Menu push - content slides in from right (navigating forward)
    static let menuPush = AnyTransition.move(edge: .trailing)

    /// Menu pop - content slides in from left (going back)
    static let menuPop = AnyTransition.move(edge: .leading)

    /// Volume bar always slides from/to right; progress bar always slides from/to left
    static func barSwap(showingVolume: Bool) -> AnyTransition {
        .move(edge: showingVolume ? .trailing : .leading)
    }
}
