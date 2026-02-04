import SwiftUI

enum iPodColor: String, CaseIterable, Identifiable {
    case white = "White"
    case silver = "Silver"
    case black = "Black"
    case red = "Product Red"
    case blue = "Blue"
    case green = "Green"
    case pink = "Pink"

    var id: String { rawValue }

    // Main body color
    var bodyColor: Color {
        switch self {
        case .white:
            return Color(red: 0.95, green: 0.95, blue: 0.95)
        case .silver:
            return Color(red: 0.85, green: 0.85, blue: 0.87)
        case .black:
            return Color(red: 0.15, green: 0.15, blue: 0.15)
        case .red:
            return Color(red: 0.8, green: 0.1, blue: 0.15)
        case .blue:
            return Color(red: 0.2, green: 0.4, blue: 0.7)
        case .green:
            return Color(red: 0.2, green: 0.6, blue: 0.4)
        case .pink:
            return Color(red: 0.95, green: 0.6, blue: 0.7)
        }
    }

    // Click wheel color
    var wheelColor: Color {
        switch self {
        case .white, .silver, .pink:
            return Color(red: 0.9, green: 0.9, blue: 0.9)
        case .black:
            return Color(red: 0.2, green: 0.2, blue: 0.2)
        case .red:
            return Color(red: 0.7, green: 0.08, blue: 0.12)
        case .blue:
            return Color(red: 0.15, green: 0.3, blue: 0.6)
        case .green:
            return Color(red: 0.15, green: 0.5, blue: 0.35)
        }
    }

    // Center button color
    var centerButtonColor: Color {
        switch self {
        case .white, .silver:
            return Color(red: 0.95, green: 0.95, blue: 0.95)
        case .black:
            return Color(red: 0.12, green: 0.12, blue: 0.12)
        case .red:
            return Color(red: 0.9, green: 0.9, blue: 0.9)
        case .blue:
            return Color(red: 0.9, green: 0.9, blue: 0.9)
        case .green:
            return Color(red: 0.9, green: 0.9, blue: 0.9)
        case .pink:
            return Color(red: 0.98, green: 0.98, blue: 0.98)
        }
    }

    // Text color on wheel
    var wheelTextColor: Color {
        switch self {
        case .white, .silver, .pink:
            return Color(red: 0.4, green: 0.4, blue: 0.4)
        case .black, .red, .blue, .green:
            return Color(red: 0.8, green: 0.8, blue: 0.8)
        }
    }

    // Screen bezel color
    var bezelColor: Color {
        switch self {
        case .white, .silver, .pink:
            return Color(red: 0.5, green: 0.5, blue: 0.52)
        case .black, .red, .blue, .green:
            return Color(red: 0.1, green: 0.1, blue: 0.1)
        }
    }
}
