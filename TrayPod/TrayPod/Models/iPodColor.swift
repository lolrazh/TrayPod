import SwiftUI

enum iPodColor: String, CaseIterable, Identifiable {
    case white = "White"
    case black = "Black"
    case u2 = "U2 Edition"  // Special edition with red wheel
    case silver = "Silver"
    case red = "Product Red"
    case blue = "Blue"
    case green = "Green"
    case pink = "Pink"

    var id: String { rawValue }

    // iPod 5G: Glossy polycarbonate body colors
    var bodyColor: Color {
        switch self {
        case .white:
            // Glossy white polycarbonate
            return Color(red: 0.97, green: 0.97, blue: 0.97)
        case .black, .u2:
            // Glossy black polycarbonate
            return Color(red: 0.1, green: 0.1, blue: 0.1)
        case .silver:
            return Color(red: 0.85, green: 0.85, blue: 0.87)
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
            return Color(red: 0.92, green: 0.92, blue: 0.92)
        case .black:
            return Color(red: 0.18, green: 0.18, blue: 0.18)
        case .u2:
            // U2 Edition: Signature red click wheel
            return Color(red: 0.75, green: 0.1, blue: 0.12)
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
        case .black, .u2:
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
        case .black, .u2, .red, .blue, .green:
            return Color(red: 0.85, green: 0.85, blue: 0.85)
        }
    }

    // Screen bezel color
    var bezelColor: Color {
        switch self {
        case .white, .silver, .pink:
            return Color(red: 0.5, green: 0.5, blue: 0.52)
        case .black, .u2, .red, .blue, .green:
            return Color(red: 0.1, green: 0.1, blue: 0.1)
        }
    }

    // iPod 5G: Whether this is a glossy polycarbonate finish (white/black)
    var isGlossyFinish: Bool {
        switch self {
        case .white, .black, .u2:
            return true
        default:
            return false
        }
    }
}
