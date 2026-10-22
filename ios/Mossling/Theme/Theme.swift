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
    static let stone = Color(uiColor: .systemGray4)

    // surfaces and text: the system's own semantic colours, so the app sits naturally in light, dark and
    // increased-contrast modes; the brand colours are kept for the companions, the beads and accents
    static let background = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let cardLow = Color(uiColor: .secondarySystemGroupedBackground)
    static let cardHigh = Color(uiColor: .tertiarySystemFill)
    static let primary = Color.dyn(0x3B7A4B, 0x86CF95)
    static let primaryContainer = Color.dyn(0xE2F0E2, 0x1E3524)
    static let onPrimaryContainer = Color.dyn(0x1C3A24, 0xCDEBD1)
    static let tertiary = Color.dyn(0x9A6A06, 0xF2C14E)
    static let tertiaryContainer = Color.dyn(0xFBF1D4, 0x3A2F12)
    static let onTertiaryContainer = Color.dyn(0x4A3300, 0xF6E4AE)
    static let secondaryContainer = Color.dyn(0xE4EBFB, 0x1D2A4A)
    static let onSecondaryContainer = Color.dyn(0x15254A, 0xD9E0F2)
    static let text = Color.primary
    static let secondaryText = Color.secondary
    static let outline = Color(uiColor: .separator)
    static let danger = Color(uiColor: .systemRed)

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

/// Type: the system font throughout (SF Pro and PingFang), scaled with Dynamic Type. Headings are bold, numbers use
/// SF Pro Rounded with tabular digits.
enum Typeface {
    private static func scaled(_ size: CGFloat, _ style: Font.TextStyle) -> CGFloat {
        let ui: UIFont.TextStyle = switch style {
        case .largeTitle: .largeTitle; case .title: .title1; case .title2: .title2; case .title3: .title3
        case .headline: .headline; case .subheadline: .subheadline; case .caption: .caption1; case .footnote: .footnote
        default: .body }
        return UIFontMetrics(forTextStyle: ui).scaledValue(for: size)
    }
    static func numerals(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .system(size: scaled(size, style), weight: .semibold, design: .rounded).monospacedDigit()
    }
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .title3) -> Font {
        .system(size: scaled(size, style), weight: .bold)
    }
}

extension View {
    /// A rounded card on the page.
    func card(_ color: Color = Palette.cardLow, radius: CGFloat = 22, padding: CGFloat = 16) -> some View {
        self.padding(padding).frame(maxWidth: .infinity, alignment: .leading).background(color, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
