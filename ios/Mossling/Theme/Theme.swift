import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: alpha)
    }
    /// A colour with its own dark-mode value.
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light)) })
    }
}

/// Montessori materials: moss green, number-rod blue, golden beads, wood, chalk paper, ink. The same as Android.
enum Palette {
    static let ink = Color(hex: 0x1C1D19)
    static let paper = Color(hex: 0xFBF9F3)
    static let chalk = Color(hex: 0xF4F2EC)
    static let moss = Color(hex: 0x55704A)
    static let mossDeep = Color(hex: 0x3D5434)
    static let mossLight = Color(hex: 0x88A06C)
    static let mint = Color(hex: 0x4FAE7F)
    static let mintLight = Color(hex: 0x7FCBA0)
    static let mintPale = Color(hex: 0xA9E0C0)
    static let mintVein = Color(hex: 0x2B6A4A)
    static let rod = Color(hex: 0x2D4A8C)
    static let rodDeep = Color(hex: 0x1F3566)
    static let bead = Color(hex: 0xD4A21C)
    static let beadLight = Color(hex: 0xEDCB6A)
    static let wood = Color(hex: 0xC99B63)
    static let red = Color(hex: 0xB8382B)
    static let stone = Color(hex: 0xD9D4C7)

    // surfaces and text, light / dark
    static let background = Color.dyn(0xF4F2EC, 0x121411)
    static let card = Color.dyn(0xFBF9F3, 0x1B1E19)
    static let cardLow = Color.dyn(0xF0EDE5, 0x1E211B)
    static let cardHigh = Color.dyn(0xE6E2D8, 0x2A2D26)
    static let primary = Color.dyn(0x3D5434, 0xB3CB9F)
    static let primaryContainer = Color.dyn(0xD7E3C9, 0x34472C)
    static let onPrimaryContainer = Color.dyn(0x1E2C17, 0xD7E3C9)
    static let tertiary = Color.dyn(0x8A6508, 0xE9C860)
    static let tertiaryContainer = Color.dyn(0xF6E4AE, 0x5A4300)
    static let onTertiaryContainer = Color.dyn(0x3A2A00, 0xF6E4AE)
    static let secondaryContainer = Color.dyn(0xD9E0F2, 0x2A3D6B)
    static let onSecondaryContainer = Color.dyn(0x15254A, 0xD9E0F2)
    static let text = Color.dyn(0x1C1D19, 0xE4E3DC)
    static let secondaryText = Color.dyn(0x4A4C43, 0xC5C7BA)
    static let outline = Color.dyn(0xD9D4C7, 0x44473F)
    static let danger = Color.dyn(0xB8382B, 0xF0A094)

    /// The six areas of development, each with its own colour and SF Symbol.
    static func area(_ key: String) -> Color {
        switch key.prefix(1) {
        case "A": return rod; case "B": return moss; case "C": return Color(hex: 0x8A6508)
        case "D": return red; case "E": return Color(hex: 0x6B4E8C); default: return Color(hex: 0x2F7A6B)
        }
    }
    static func areaSymbol(_ key: String) -> String {
        switch key.prefix(1) {
        case "A": return "bubble.left.and.bubble.right.fill"; case "B": return "figure.walk"; case "C": return "hand.raised.fill"
        case "D": return "heart.fill"; case "E": return "house.fill"; default: return "cross.case.fill"
        }
    }
}

/// Numerals and Latin display: Young Serif. Chinese headings: Noto Serif SC. Interface text: the system font (PingFang).
enum Typeface {
    static func numerals(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font { .custom("YoungSerif-Regular", size: size, relativeTo: style) }
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .title3) -> Font { .custom("NotoSerifSCExtraLight-SemiBold", size: size, relativeTo: style) }
}

extension View {
    /// A rounded card on the page.
    func card(_ color: Color = Palette.cardLow, radius: CGFloat = 22, padding: CGFloat = 16) -> some View {
        self.padding(padding).frame(maxWidth: .infinity, alignment: .leading).background(color, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
