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

/// Colour. A warm rainbow of crayons (see `Crayon`) marks every category — the six areas, each kind of entry, the
/// beads — so pages are colourful the way a kindergarten shelf is, while text and controls stay the system's own. The
/// page is a warm paper white in light mode and a warm near-black in dark; cards and rows are the system's grouped
/// surfaces. One accent, leaf green (a darker value in light mode so text in it stays legible).
enum Palette {
    // brand, for the companions and small details
    static let ink = Color(hex: 0x1C1D19)
    static let paper = Color(hex: 0xFBF9F3)
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
    static let stone = Color(uiColor: .systemGray4)

    static let accent = Color.dyn(0x2E8B3A, 0x66CC66)
    static let background = Color.dyn(0xFBF6EE, 0x0F0E0C)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let fill = Color.dyn(0xF2EBE0, 0x2A2723)
    static let text = Color.primary
    static let secondaryText = Color.secondary
    static let outline = Color(uiColor: .separator)
    static let danger = Crayon.cherry
    static let caution = Crayon.tangerine

    /// The six areas of development, each with a system colour and an SF Symbol.
    static func area(_ key: String) -> Color {
        switch key.prefix(1) {
        case "A": Crayon.sky; case "B": Crayon.tangerine; case "C": Crayon.lilac; case "D": Crayon.rose; case "E": Crayon.sunflower; default: Crayon.aqua
        }
    }
    static func areaSymbol(_ key: String) -> String {
        switch key.prefix(1) {
        case "A": "bubble.left.and.bubble.right.fill"; case "B": "figure.walk"; case "C": "hand.raised.fingers.spread.fill"
        case "D": "heart.fill"; case "E": "house.fill"; default: "cross.case.fill"
        }
    }
    /// The area a play belongs to, from its first domain.
    static func areaKey(of play: Play) -> String {
        let d = play.domains.first ?? ""
        let rules: [(String, [String])] = [
            ("F", ["安全", "照护", "调节"]),
            ("E", ["生活", "自理", "自主", "文化", "家庭"]),
            ("A", ["语言", "共读", "表达", "多语言"]),
            ("B", ["大运动", "运动"]),
            ("D", ["社会", "社交", "关系", "情绪", "合作", "轮流", "共同注意", "假装", "规则"]),
        ]
        return rules.first { _, words in words.contains { d.contains($0) } }?.0 ?? "C"
    }
}

/// Type: the system font through the text styles, so every size follows Dynamic Type, in its rounded design (SF Pro
/// Rounded, with PingFang for Chinese) for a friendly, playroom feel; values use tabular digits.
enum Typeface {
    private static func scaled(_ size: CGFloat, _ style: Font.TextStyle) -> CGFloat {
        let ui: UIFont.TextStyle = switch style {
        case .largeTitle: .largeTitle; case .title: .title1; case .title2: .title2; case .title3: .title3
        case .headline: .headline; case .subheadline: .subheadline; case .caption: .caption1; case .footnote: .footnote
        default: .body }
        return UIFontMetrics(forTextStyle: ui).scaledValue(for: size)
    }
    static func numerals(_ size: CGFloat, relativeTo style: Font.TextStyle = .body, weight: Font.Weight = .semibold) -> Font {
        .system(size: scaled(size, style), weight: weight, design: .rounded).monospacedDigit()
    }
}

// MARK: building blocks

/// A category mark: a white SF Symbol on a small rounded tile with depth — the colour lit from the upper left, a gloss
/// across the top, a fine light edge and a soft coloured shadow, like the icons on the Home Screen. The one way a
/// category is marked across the app.
struct IconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 30
    var round = false
    @ScaledMetric private var scale: CGFloat = 1
    var body: some View {
        let s = size * min(scale, 1.6)
        let shape = RoundedRectangle(cornerRadius: round ? s / 2 : s * 0.3, style: .continuous)
        Image(systemName: symbol)
            .font(.system(size: s * 0.48, weight: .bold))
            .foregroundStyle(Crayon.glyph(on: color))
            .shadow(color: .black.opacity(0.18), radius: 0.5, y: 0.6)
            .frame(width: s, height: s)
            .background {
                ZStack {
                    shape.fill(LinearGradient(colors: [color.mix(with: .white, by: 0.28), color, color.mix(with: .black, by: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    shape.fill(LinearGradient(colors: [.white.opacity(0.38), .white.opacity(0)], startPoint: .top, endPoint: .center)).padding(s * 0.06)
                    shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 0.8)
                }
            }
            .shadow(color: color.opacity(0.35), radius: s * 0.12, y: s * 0.08)
            .accessibilityHidden(true)
    }
}

/// The page behind everything: warm paper with large soft washes of colour. Each tab has its own hue — peach for
/// Today, mint for the map, glass pink for the journal, lilac for Me — and every page opened from a tab keeps it, so
/// the glass bars above pick up the same light.
enum Hue { case peach, mint, pink, lilac
    var colors: (Color, Color) {
        switch self {
        case .peach: (Crayon.peach, Crayon.sunflower)
        case .mint: (Crayon.mint, Crayon.sky)
        case .pink: (Crayon.pink, Crayon.lilac)
        case .lilac: (Crayon.lilac, Crayon.sky)
        }
    }
}
extension EnvironmentValues { @Entry var hue: Hue = .peach }

struct PageBackground: View {
    @Environment(\.hue) private var hue
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let (a, b) = hue.colors
        let k = scheme == .dark ? 0.22 : 0.3
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Palette.background
                RadialGradient(colors: [a.opacity(k), a.opacity(0)], center: .topLeading, startRadius: 0, endRadius: w * 0.95)
                RadialGradient(colors: [b.opacity(k * 0.8), b.opacity(0)], center: UnitPoint(x: 1, y: 0.35), startRadius: 0, endRadius: w * 0.8)
                RadialGradient(colors: [a.opacity(k * 0.6), a.opacity(0)], center: UnitPoint(x: 0.2, y: 1), startRadius: 0, endRadius: max(w, h) * 0.6)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

extension View {
    /// The page's background, in the hue of its tab.
    func pageBackground() -> some View { background { PageBackground() } }
}

/// A summary card, as in Health: a coloured label line (symbol, title, an optional detail and a chevron when it opens
/// something), then the content.
struct Card<Content: View>: View {
    let title: String
    let symbol: String
    var color: Color = Palette.accent
    var detail: String? = nil
    var opens = false
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Label(title, systemImage: symbol).font(.subheadline.weight(.semibold)).foregroundStyle(color)
                    .labelStyle(.titleAndIcon)
                Spacer(minLength: 8)
                if let detail { Text(detail).font(.footnote).foregroundStyle(.secondary).monospacedDigit() }
                if opens { Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary) }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .printCard(radius: 26)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

/// A value with its unit, as in Health: the number large and rounded, the unit small and secondary.
struct ValueText: View {
    let parts: [(String, String)]
    var size: CGFloat = 30
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            ForEach(Array(parts.enumerated()), id: \.offset) { i, p in
                Text(p.0).font(Typeface.numerals(size, relativeTo: .title, weight: .bold))
                Text(p.1).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).padding(.trailing, i < parts.count - 1 ? 4 : 0)
            }
        }
        .lineLimit(1).minimumScaleFactor(0.7)
    }
}

/// A heading between cards on a scrolling page.
struct SectionTitle: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title3.weight(.bold))
            Spacer()
            if let detail { Text(detail).font(.footnote).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 4).padding(.top, 20)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A surface with depth, the same everywhere: the card colour with a faint light falling from the top, a fine light
/// edge, and a soft warm shadow under it, so cards sit on the page like objects.
struct PrintCard: ViewModifier {
    var radius: CGFloat = 24
    var fill: Color = Palette.card
    @Environment(\.colorScheme) private var scheme
    func body(content: Self.Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                ZStack {
                    shape.fill(fill)
                    shape.fill(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.06 : 0.55), .white.opacity(0)], startPoint: .top, endPoint: .center))
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.14 : 0.9), .white.opacity(scheme == .dark ? 0.03 : 0.2)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
            .shadow(color: scheme == .dark ? .black.opacity(0.45) : Color(hex: 0x8A5A2B).opacity(0.12), radius: 14, y: 7)
    }
}

extension View {
    func printCard(radius: CGFloat = 24, fill: Color = Palette.card) -> some View { modifier(PrintCard(radius: radius, fill: fill)) }

    /// A plain rounded card on the page.
    func card(_ color: Color = Palette.card, radius: CGFloat = 26, padding: CGFloat = 16) -> some View {
        self.padding(padding).frame(maxWidth: .infinity, alignment: .leading).background(color, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// Pressing a card is like pressing a wooden toy: it gives a little and springs back, with a light tap.
struct ToyPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: configuration.isPressed) { _, new in new }
    }
}
extension ButtonStyle where Self == ToyPress { static var toy: ToyPress { ToyPress() } }
