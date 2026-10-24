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
    // dark is the lamp (build 160: one dark appearance, Otto's — deep blue, amber light), wherever it shows
    static let background = Color.dyn(0xFBF7F0, 0x0E1430)
    static let card = Color.dyn(0xFFFFFF, 0x19213F)
    static let fill = Color.dyn(0xF2EBE0, 0x212A4C)
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

extension Crayon {
    /// A fill under white text. Under the lamp the bright kind colours would be the brightest things in a dark room —
    /// the light shone at a waking baby — so there they sink into the lamp's blue (still ≥ 4.5:1 under white, and
    /// darker, so higher) and leave the colour to rings and text.
    static func fill(_ c: Color, _ lamp: Bool) -> Color {
        lamp ? buttonFill(c).mix(with: Palette.lampCard, by: 0.5) : buttonFill(c)
    }
}

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
    /// A faint wash of the tab's colour from the top (今天 sunflower, 记录 pink, 我的 lilac): the page stays paper,
    /// but each place has its own light, like a room lit by a different window.
    var tone: Color? = nil
    var body: some View {
        if lamp {
            // night: deep blue, warmed from the top by Otto's lamp
            ZStack {
                Palette.lampPage
                RadialGradient(colors: [Palette.amber.opacity(0.22), Palette.amber.opacity(0)], center: UnitPoint(x: 0.85, y: 0), startRadius: 0, endRadius: 420)
                Grain(dark: true)
                Motes()
            }
            .ignoresSafeArea().accessibilityHidden(true)
        } else {
            ZStack {
                Palette.background
                if let tone {
                    LinearGradient(stops: [.init(color: tone.opacity(0.16), location: 0), .init(color: tone.opacity(0.05), location: 0.28), .init(color: tone.opacity(0), location: 0.55)], startPoint: .top, endPoint: .bottom)
                    RadialGradient(colors: [tone.opacity(0.14), tone.opacity(0)], center: UnitPoint(x: 0.9, y: 0), startRadius: 0, endRadius: 360)
                }
                Grain(dark: false)
            }
            .ignoresSafeArea().accessibilityHidden(true)
        }
    }
}

/// The tooth of the paper the pictures are printed on: fine fibres and specks, tiled, too faint to see as a pattern
/// but enough that the page and the cards read as paper like the pictures' grounds, not as flat screen colour. One
/// small tile drawn once (deterministic), repeated. On the lamp's blue the specks are light.
struct Grain: View {
    var dark: Bool
    var strength: Double = 1
    private static let light = Grain.tile(dark: false)
    private static let night = Grain.tile(dark: true)
    var body: some View {
        Image(uiImage: dark ? Self.night : Self.light)
            .resizable(resizingMode: .tile)
            .opacity(strength)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
    private static func tile(dark: Bool) -> UIImage {
        let n = 96
        let format = UIGraphicsImageRendererFormat(); format.scale = 2; format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: n, height: n), format: format).image { ctx in
            var seed: UInt64 = 0x9E3779B97F4A7C15
            func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }
            let ink = dark ? UIColor(white: 1, alpha: 1) : UIColor(red: 0.45, green: 0.32, blue: 0.2, alpha: 1)
            for _ in 0..<260 {   // specks
                let x = rnd() * Double(n), y = rnd() * Double(n), r = 0.25 + rnd() * 0.55
                ink.withAlphaComponent(dark ? 0.035 + rnd() * 0.04 : 0.03 + rnd() * 0.05).setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r * 2))
            }
            for _ in 0..<26 {    // short fibres
                let x = rnd() * Double(n), y = rnd() * Double(n), a = rnd() * .pi, l = 3 + rnd() * 6
                let p = UIBezierPath(); p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x + cos(a) * l, y: y + sin(a) * l))
                p.lineWidth = 0.4
                ink.withAlphaComponent(dark ? 0.03 : 0.045).setStroke(); p.stroke()
            }
        }
    }
}

/// Specks of Otto's lamplight drifting slowly in the dark, as dust in a lamp's beam: a dozen, faint, near the lamp at
/// the top. Ten frames a second is enough for something this slow; still under Reduce Motion.
private struct Motes: View {
    @Environment(\.accessibilityReduceMotion) private var reduce
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: reduce)) { tl in
            Canvas { ctx, size in
                let t = reduce ? 0 : tl.date.timeIntervalSinceReferenceDate
                for i in 0..<12 {
                    let s = Double(i) * 0.618
                    let x = size.width * (0.35 + 0.65 * s.truncatingRemainder(dividingBy: 1)) + Foundation.sin(t * 0.21 + Double(i)) * 18
                    let y = size.height * 0.42 * (0.1 + (s * 1.7).truncatingRemainder(dividingBy: 1)) + Foundation.cos(t * 0.17 + Double(i) * 2) * 14
                    let a = 0.18 + 0.22 * (0.5 + 0.5 * Foundation.sin(t * 0.8 + Double(i) * 1.3))
                    let r = 1.2 + Double(i % 3) * 0.7
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r * 3, y: y - r * 3, width: r * 6, height: r * 6)), with: .color(Palette.amber.opacity(a * 0.25)))
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Palette.amber.opacity(a)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// The page's background: paper.
    func pageBackground(tone: Color? = nil) -> some View { background { PageBackground(tone: tone) } }
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
                Ticking(text: p.0).font(Typeface.numerals(size, relativeTo: .title, weight: .bold))
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
            .background {
                ZStack {
                    lamp ? Palette.lampCard : fill
                    Grain(dark: lamp || scheme == .dark, strength: 0.6)
                }
                .clipShape(shape)
            }
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
