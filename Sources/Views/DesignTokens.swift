import SwiftUI

enum RemindersLayout {
    static let panelHorizontalInset: CGFloat = 16
    static let listVerticalInset: CGFloat = 10
    static let listRowSpacing: CGFloat = 6
}

enum RemindersPalette {
    // Backgrounds
    static let canvas = Color(hex: 0x131313)
    static let panel = Color(hex: 0x1C1C1E)
    static let card = Color(hex: 0x2C2C2E)
    static let field = Color(hex: 0x252528)
    static let elevated = Color(hex: 0x3A3A3C)

    // Text
    static let primaryText = Color.white
    static let secondaryText = Color(hex: 0x8E8E93)
    static let tertiaryText = Color(hex: 0x636366)

    // Borders
    static let border = Color(hex: 0x38383A)
    static let borderLight = Color(hex: 0x48484A)

    // Accents
    static let accentBlue = Color(hex: 0x0A84FF)
    static let accentRed = Color(hex: 0xFF453A)
    static let accentGreen = Color(hex: 0x30D158)
    static let accentOrange = Color(hex: 0xFF9F0A)

    // Shadows
    static let shadow = Color.black.opacity(0.35)

    // Legacy aliases used by MenuBarController status icon
    static let lightPrimaryText = primaryText
    static let darkPrimaryText = primaryText
    static let lightSecondaryText = secondaryText
    static let darkSecondaryText = secondaryText
    static let darkPrimaryText2 = primaryText
    static let accentBlueLight = accentBlue
    static let accentBlueDark = accentBlue
    static let accentRedLight = accentRed
    static let accentRedDark = accentRed
    static let accentPinkDark = accentRed
    static let accentGreenDark = accentGreen
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex & 0xFF0000) >> 16) / 255
        let green = Double((hex & 0x00FF00) >> 8) / 255
        let blue = Double(hex & 0x0000FF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
