import SwiftUI

// MARK: - Theme Manager

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var isCandyTheme: Bool {
        didSet { UserDefaults.standard.set(isCandyTheme, forKey: "isCandyTheme") }
    }

    private init() {
        self.isCandyTheme = UserDefaults.standard.bool(forKey: "isCandyTheme")
    }

    func toggle() {
        isCandyTheme.toggle()
    }
}

// MARK: - Layout

enum RemindersLayout {
    static let panelHorizontalInset: CGFloat = 16
    static let listVerticalInset: CGFloat = 10
    static let listRowSpacing: CGFloat = 6
}

// MARK: - Palette

@MainActor
enum RemindersPalette {
    private static var candy: Bool { ThemeManager.shared.isCandyTheme }

    // Backgrounds
    static var canvas: Color { candy ? Color(hex: 0xEEE7DA) : Color(hex: 0x131313) }
    static var panel: Color { candy ? Color(hex: 0xF6F0E6) : Color(hex: 0x1C1C1E) }
    static var card: Color { candy ? Color(hex: 0xECE4D6) : Color(hex: 0x2C2C2E) }
    static var field: Color { candy ? Color(hex: 0xE6DECE) : Color(hex: 0x252528) }
    static var elevated: Color { candy ? Color(hex: 0xDBD1C1) : Color(hex: 0x3A3A3C) }

    // Candy-specific backgrounds
    static var candyFieldBlue: Color { Color(hex: 0xE8EEF5) }
    static var candyCardYellow: Color { Color(hex: 0xF2EADA) }

    // Text
    static var primaryText: Color { candy ? Color(hex: 0x28322D) : .white }
    static var secondaryText: Color { candy ? Color(hex: 0x66736A) : Color(hex: 0x8E8E93) }
    static var tertiaryText: Color { candy ? Color(hex: 0x98A197) : Color(hex: 0x636366) }

    // Borders
    static var border: Color { candy ? Color(hex: 0xD2C8BA) : Color(hex: 0x38383A) }
    static var borderLight: Color { candy ? Color(hex: 0xE1D8C8) : Color(hex: 0x48484A) }

    // Accents
    static var accentBlue: Color { candy ? Color(hex: 0x5A82AF) : Color(hex: 0x0A84FF) }
    static var accentRed: Color { candy ? Color(hex: 0xC26C72) : Color(hex: 0xFF453A) }
    static var accentGreen: Color { candy ? Color(hex: 0x5C8570) : Color(hex: 0x30D158) }
    static var accentOrange: Color { candy ? Color(hex: 0xB27744) : Color(hex: 0xFF9F0A) }
    static var accentPink: Color { candy ? Color(hex: 0xB98798) : Color(hex: 0xFF6B8A) }
    static var accentPurple: Color { candy ? Color(hex: 0x8873AF) : Color(hex: 0x7B5EF0) }
    static var accentYellow: Color { candy ? Color(hex: 0xB89D55) : Color(hex: 0xFFD60A) }

    // Shadows
    static var shadow: Color { candy ? Color(hex: 0x89725A, opacity: 0.10) : Color.black.opacity(0.35) }

    // Theme helpers
    static var validationBg: Color { candy ? Color(hex: 0xF4E7DF) : Color(hex: 0x341A1A) }
    static var overlayDim: Color { candy ? Color.black.opacity(0.06) : Color.black.opacity(0.18) }
    static var dividerDash: Color { candy ? Color(hex: 0x5C8570, opacity: 0.24) : border }
    static var menuBarBadgeBackground: Color { candy ? Color(hex: 0xE9DDC9, opacity: 0.98) : Color(hex: 0x242428, opacity: 0.92) }
    static var menuBarBadgeBorder: Color { candy ? Color(hex: 0xBCA98B, opacity: 0.92) : Color.white.opacity(0.14) }
    static var menuBarBadgeText: Color { candy ? Color(hex: 0x284F3A) : Color(hex: 0xD9FFE9) }

    // Legacy aliases
    static var lightPrimaryText: Color { primaryText }
    static var darkPrimaryText: Color { primaryText }
    static var lightSecondaryText: Color { secondaryText }
    static var darkSecondaryText: Color { secondaryText }
    static var darkPrimaryText2: Color { primaryText }
    static var accentBlueLight: Color { accentBlue }
    static var accentBlueDark: Color { accentBlue }
    static var accentRedLight: Color { accentRed }
    static var accentRedDark: Color { accentRed }
    static var accentPinkDark: Color { accentPink }
    static var accentGreenDark: Color { accentGreen }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex & 0xFF0000) >> 16) / 255
        let green = Double((hex & 0x00FF00) >> 8) / 255
        let blue = Double(hex & 0x0000FF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
