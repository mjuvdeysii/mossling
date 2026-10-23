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

    /// Teal: links, tints and controls. Deep enough for text on paper (4.7:1) and for white on a filled button (5:1).
    static let accent = Color.dyn(0x0B7D74, 0x4FD8CB)
    /// The fill behind white text on prominent buttons, in both modes.
    static let accentFill = Color(hex: 0x0B7D74)
    /// Paper: the warm white of the picture book's pages (a warm charcoal in dark mode).
    static let background = Color.dyn(0xFBF7F0, 0x14120F)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let fill = Color.dyn(0xF2EBE0, 0x2A2723)
    static let text = Color.primary
    static let secondaryText = Color.secondary
    static let outline = Color(uiColor: .separator)
    static let danger = Crayon.cherry
    /// An area's colour deep enough for text.
    static func areaInk(_ key: String) -> Color { Crayon.ink(area(key)) }
    static let caution = Crayon.tangerine

    /// The six areas of development, each with a system colour and an SF Symbol.
    static func area(_ key: String) -> Color {
        // 语言 teal · 大运动 orange · 精细与认知 yellow · 社会情绪 pink · 生活与文化 blue · 照护与安全 red
        switch key.prefix(1) {
        case "A": Crayon.teal; case "B": Crayon.tangerine; case "C": Crayon.sunflower; case "D": Crayon.pink; case "E": Crayon.sky; default: Crayon.cherry
        }
    }
    static func areaSymbol(_ key: String) -> String {
        switch key.prefix(1) {
        case "A": "bubble.left.and.bubble.right.fill"; case "B": "figure.walk"; case "C": "hand.raised.fingers.spread.fill"
        case "D": "face.smiling.inverse"; case "E": "house.fill"; default: "cross.case.fill"
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

/// A category mark. Where the app has a drawing for it (tools/stickers.py — a small picture on a die-cut sticker,
/// named after the symbol it replaces) the drawing is shown; otherwise the symbol on a coloured tile with the pictures'
/// soft volume. The one way a category is marked across the app (ios/DESIGN.md §3: pictures, not symbols).
struct IconTile: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 30
    var round = false
    @ScaledMetric private var scale: CGFloat = 1

    static func sticker(_ symbol: String) -> String? {
        let n = "ic_" + symbol.replacingOccurrences(of: ".", with: "_") + ".webp"
        return ArtIndex.shared.size[n] == nil ? nil : n
    }

    var body: some View {
        let s = size * min(scale, 1.6)
        if let n = Self.sticker(symbol) {
            // the sticker's white edge makes it read smaller than a tile, so it is drawn a little larger
            Figure(name: n).frame(width: s * 1.22, height: s * 1.22).frame(width: s, height: s).accessibilityHidden(true)
        } else {
            let shape = RoundedRectangle(cornerRadius: round ? s / 2 : s * 0.3, style: .continuous)
            Image(systemName: symbol)
                .font(.system(size: s * 0.48, weight: .bold))
                .foregroundStyle(Crayon.glyph(on: color))
                .frame(width: s, height: s)
                .background {
                    shape.fill(LinearGradient(colors: [color.mix(with: .white, by: 0.22), color, color.mix(with: .black, by: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .shadow(color: color.opacity(0.22), radius: s * 0.08, y: s * 0.05)
                .accessibilityHidden(true)
        }
    }
}

// MARK: day and night

/// Moss keeps the day (play, the picture book); Otto keeps the night (care), his golden bead a small lamp. From 7 pm
/// to 6 am, with 夜灯 on, the records and the timer are lit by that lamp: deep blue, a warm amber glow, no bright white —
/// dim red and amber light disturbs a child's (and a parent's) night least (ios/DESIGN.md §1).
enum Daylight {
    static func isNight(_ d: Date = Date()) -> Bool { let h = Day.cal.component(.hour, from: d); return h >= 19 || h < 6 }
}
extension EnvironmentValues {
    @Entry var lamp: Bool = false
    /// Night (7 pm – 6 am): the sky on the home is the night sky and Otto's bead glows; the page itself stays as set.
    @Entry var night: Bool = false
}

/// Lights a part of the app with Otto's lamp when `on`: dark appearance, amber tint, the lamp page and cards.
struct LampScope: ViewModifier {
    let on: Bool
    func body(content: Self.Content) -> some View {
        if on {
            content.environment(\.lamp, true).environment(\.colorScheme, .dark)
                .toolbarColorScheme(.dark, for: .navigationBar, .tabBar).tint(Palette.lampTint)
        } else { content }
    }
}
extension View { func lamp(_ on: Bool) -> some View { modifier(LampScope(on: on)) } }

/// For the root of every sheet or cover presented from a lit part of the app. A presentation takes its appearance from
/// the system, not from the view that presented it: the environment's dark scheme does not reach it, so its text and
/// the system controls in it (date pickers, segmented controls) came out black on the lamp's blue (reported on
/// device, build 156). This lights the presentation itself — `preferredColorScheme` sets the sheet's own appearance,
/// which UIKit-backed controls follow — and changes nothing by day.
struct LampPresented: ViewModifier {
    @Environment(\.lamp) private var lamp
    func body(content: Self.Content) -> some View {
        content.modifier(LampScope(on: lamp)).preferredColorScheme(lamp ? .dark : nil)
    }
}
extension View { func lampPresented() -> some View { modifier(LampPresented()) } }

extension Palette {
    static let lampPage = Color(hex: 0x0E1430)
    static let lampCard = Color(hex: 0x19213F)
    static let amber = Color(hex: 0xFFB547)
    static let amberDeep = Color(hex: 0x9A5A00)
    /// The lamp's tint for controls. The glow (`amber`) is light only — under white text, as system controls draw a
    /// selected day or a prominent button, it gives 1.8:1. This deeper amber keeps ≥ 3:1 under white (large and bold
    /// text, controls) and ≥ 4.6:1 as text on every lamp surface (page 6.0, card 5.2, grouped cell 4.6).
    static let lampTint = Color(hex: 0xCF8420)
}

/// The page behind everything: plain paper. Colour belongs to the pictures and the materials, not the page
/// (ios/DESIGN.md §3); hierarchy comes from layout and grouping.
struct PageBackground: View {
    @Environment(\.lamp) private var lamp
    var body: some View {
        if lamp {
            // night: deep blue, warmed from the top by Otto's lamp
            ZStack {
                Palette.lampPage
                RadialGradient(colors: [Palette.amber.opacity(0.22), Palette.amber.opacity(0)], center: UnitPoint(x: 0.85, y: 0), startRadius: 0, endRadius: 420)
            }
            .ignoresSafeArea().accessibilityHidden(true)
        } else {
            Palette.background.ignoresSafeArea().accessibilityHidden(true)
        }
    }
}

extension View {
    /// The page's background: paper.
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
                Label(title, systemImage: symbol).font(.subheadline.weight(.semibold)).foregroundStyle(Crayon.ink(color))
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

/// A card of paper on the page: one flat colour and a soft shadow — no gloss, no light edge, no gradient
/// (ios/DESIGN.md §3). In dark mode a hairline replaces the shadow, which would not show.
struct PrintCard: ViewModifier {
    var radius: CGFloat = 24
    var fill: Color = Palette.card
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    func body(content: Self.Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(lamp ? Palette.lampCard : fill, in: shape)
            .clipShape(shape)
            .overlay { if scheme == .dark { shape.strokeBorder(.white.opacity(0.07), lineWidth: 1) } }
            .shadow(color: scheme == .dark ? .clear : Color(hex: 0x7A5230).opacity(0.09), radius: 10, y: 4)
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
