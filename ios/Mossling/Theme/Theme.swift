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
    /// Secondary text. The system's secondary label is 60 % of the primary, about 3.4:1 on white and under 3:1 on the
    /// tinted cards — below WCAG's 4.5:1 for the small captions that carry it here (the accessibility audit flagged
    /// them). A solid grey instead: 6.3:1 on white, ≥ 5.3:1 on every tinted card; by lamplight ≥ 6.8:1.
    static let secondaryText = Color.dyn(0x5E5F66, 0xAEB4CC)
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
    /// The text styles at their default (Large) sizes.
    private static let styleSizes: [(Font.TextStyle, CGFloat)] = [(.largeTitle, 34), (.title, 28), (.title2, 22), (.title3, 20), (.headline, 17), (.body, 17),
                                                                  (.callout, 16), (.subheadline, 15), (.footnote, 13), (.caption, 12), (.caption2, 11)]
    static func numerals(_ size: CGFloat, relativeTo style: Font.TextStyle = .body, weight: Font.Weight = .semibold) -> Font {
        // a size that is a text style's own is that text style — fully Dynamic Type, as the accessibility audit and
        // VoiceOver's large content expect; display sizes in between scale with the given style
        if let match = styleSizes.first(where: { $0.0 == style && $0.1 == size }) ?? styleSizes.first(where: { $0.1 == size }) {
            return .system(match.0, design: .rounded, weight: weight).monospacedDigit()
        }
        return .system(size: scaled(size, style), weight: weight, design: .rounded).monospacedDigit()
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
        // a few marks share one object (export and import in one row are still the parcel going out)
        let alias = ["square.and.arrow.up.on.square": "square.and.arrow.up", "list.bullet.clipboard": "list.bullet.clipboard.fill"]
        let n = "ic_" + (alias[symbol] ?? symbol).replacingOccurrences(of: ".", with: "_") + ".webp"
        // in the hidden 2D world, only the stickers build 196 had; the rest are drawn as symbol tiles, as then
        if ArtStyle.current == .flat { return ArtIndex.shared.size["2d_" + n] == nil ? nil : n }
        return ArtIndex.shared.size[n] == nil ? nil : n
    }

    var body: some View {
        let s = size * min(scale, 1.6)
        if let n = Self.sticker(symbol) {
            // the sticker's white edge makes it read smaller than a tile, so it is drawn a little larger
            // (the 3D stickers are framed with room for the token's shadow, so they are drawn larger still)
            let k: CGFloat = ArtStyle.current == .flat ? 1.22 : 1.42
            Figure(name: n).frame(width: s * k, height: s * k).frame(width: s, height: s).accessibilityHidden(true)
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
    /// The page is being scrolled: the companions hold still for that moment, so the scroll has the frame budget to
    /// itself (their breathing and glances resume the instant it settles).
    @Entry var scrolling: Bool = false
}

/// Marks a page's scroll view so the living things on it rest while it moves (see `scrolling`).
struct CalmScroll: ViewModifier {
    @State private var moving = false
    func body(content: Content) -> some View {
        content
            .onScrollPhaseChange { _, phase in
                let m = phase != .idle
                if m != moving { moving = m }
            }
            .environment(\.scrolling, moving)
    }
}
extension View { func calmWhileScrolling() -> some View { modifier(CalmScroll()) } }

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
    /// Reduce Transparency: the page becomes plain and opaque — no drifting seeds, motes or grain behind the cards;
    /// only the solid paper (or the lamp's blue) and the still wash of light remain.
    @Environment(\.accessibilityReduceTransparency) private var solid
    /// A faint wash of the tab's colour from the top (今天 sunflower, 记录 pink, 我的 lilac): the page stays paper,
    /// but each place has its own light, like a room lit by a different window.
    var tone: Color? = nil
    var body: some View {
        if lamp {
            // night: deep blue, warmed from the top by Otto's lamp
            ZStack {
                Palette.lampPage
                LampGlow()
                if !solid { Grain(dark: true); Motes() }
            }
            .ignoresSafeArea().accessibilityHidden(true)
        } else {
            ZStack {
                Palette.background
                if let tone {
                    LinearGradient(stops: [.init(color: tone.opacity(0.16), location: 0), .init(color: tone.opacity(0.05), location: 0.28), .init(color: tone.opacity(0), location: 0.55)], startPoint: .top, endPoint: .bottom)
                    RadialGradient(colors: [tone.opacity(0.14), tone.opacity(0)], center: UnitPoint(x: 0.9, y: 0), startRadius: 0, endRadius: 360)
                }
                if !solid { Grain(dark: false); DayAir(tone: tone ?? Crayon.sunflower) }
            }
            .ignoresSafeArea().accessibilityHidden(true)
        }
    }
}

/// The day's counterpart of the lamp's drifting motes: a garden morning behind the paper. Sunlight comes in from the
/// top right in a few soft beams that slowly breathe; dandelion seeds, petals in the tab's colour, small leaves and
/// specks of pollen drift across on the air; at the foot of the page a low hill of grass where a few flowers sway, a
/// wooden ring stacker and a ball resting in it. Everything is faint — the paper stays paper. The drifting things are
/// Core Animation particles (smooth at the display's own rate, no main-thread work); the rest is drawn once. Still
/// under Reduce Motion.
struct DayAir: View {
    var tone: Color
    /// Size of everything, for small previews (the theme swatches).
    var scale: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var breath = false
    var body: some View {
        ZStack {
            // the sun, its hill and flowers: drawn once (nothing in them moves per frame)
            Canvas { ctx, size in sunDisc(&ctx, size) }
            // the meadow at the foot of the page: low and quiet, so text that reaches the bottom of a short page stays
            // easy to read over it
            Canvas { ctx, size in meadow(&ctx, size, 0) }
                .opacity(0.5).offset(y: 16 * scale)
            // the beams breathe as one slow change of opacity, run by the system compositor, not redrawn
            Canvas { ctx, size in beams(&ctx, size, 0) }
                .opacity(breath ? 1 : 0.55)
            // seeds, petals, leaves and pollen drifting down over the whole page, animated by Core Animation off the
            // main thread at the display's full frame rate
            // only in the flat (2D) world: the vinyl world's page is still air
            if !reduce && ArtStyle.current == .flat { AirEmitter(kind: .day(UIColor(tone)), scale: scale) }
        }
        .allowsHitTesting(false)
        .onAppear { if !reduce { withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) { breath = true } } }
    }

    private func sunDisc(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let o = CGPoint(x: size.width * 0.96, y: -size.height * 0.02)
        let R = 320 * scale
        ctx.fill(Path(ellipseIn: CGRect(x: o.x - R, y: o.y - R, width: 2 * R, height: 2 * R)),
                 with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE39A).opacity(0.75), Color(hex: 0xFFE9A8).opacity(0.25), Color(hex: 0xFFE9A8).opacity(0)]), center: o, startRadius: 0, endRadius: R))
    }

    private func beams(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let o = CGPoint(x: size.width * 0.96, y: -size.height * 0.02)
        // three beams fanning down to the left, each breathing on its own slow cycle
        for i in 0..<3 {
            let a = (128.0 + Double(i) * 13 + Foundation.sin(t * 0.05 + Double(i)) * 2) * .pi / 180
            let len = size.height * 0.95, w = (54.0 + Double(i) * 22) * scale
            let dir = CGPoint(x: Foundation.cos(a), y: Foundation.sin(a)), nrm = CGPoint(x: -dir.y, y: dir.x)
            var p = Path()
            p.move(to: CGPoint(x: o.x + nrm.x * 6, y: o.y + nrm.y * 6))
            p.addLine(to: CGPoint(x: o.x + dir.x * len + nrm.x * w, y: o.y + dir.y * len + nrm.y * w))
            p.addLine(to: CGPoint(x: o.x + dir.x * len - nrm.x * w, y: o.y + dir.y * len - nrm.y * w))
            p.addLine(to: CGPoint(x: o.x - nrm.x * 6, y: o.y - nrm.y * 6))
            let k = 0.11 + 0.07 * (0.5 + 0.5 * Foundation.sin(t * 0.5 + Double(i) * 2.1))
            ctx.fill(p, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFF3C4).opacity(k), Color(hex: 0xFFF3C4).opacity(0)]), startPoint: o,
                                             endPoint: CGPoint(x: o.x + dir.x * len, y: o.y + dir.y * len)))
        }
    }


    private func meadow(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = size.width, h = size.height, base = h - 44 * scale
        // two soft hills
        var back = Path()
        back.move(to: CGPoint(x: 0, y: base - 10))
        back.addCurve(to: CGPoint(x: w, y: base - 26 * scale), control1: CGPoint(x: w * 0.3, y: base - 62 * scale), control2: CGPoint(x: w * 0.62, y: base + 6 * scale))
        back.addLine(to: CGPoint(x: w, y: h)); back.addLine(to: CGPoint(x: 0, y: h)); back.closeSubpath()
        ctx.fill(back, with: .color(Color(hex: 0xBFE3B4).opacity(0.45)))
        var front = Path()
        front.move(to: CGPoint(x: 0, y: base + 14 * scale))
        front.addCurve(to: CGPoint(x: w, y: base + 4 * scale), control1: CGPoint(x: w * 0.4, y: base - 22 * scale), control2: CGPoint(x: w * 0.7, y: base + 30 * scale))
        front.addLine(to: CGPoint(x: w, y: h)); front.addLine(to: CGPoint(x: 0, y: h)); front.closeSubpath()
        ctx.fill(front, with: .color(Color(hex: 0x9FD39A).opacity(0.42)))
        // flowers on the hill, swaying from the stem
        let petals = [Color(hex: 0xFF8FAA), Color(hex: 0xFFD36B), Color(hex: 0xB39CF4), tone]
        for i in 0..<6 {
            let x = w * (0.08 + 0.17 * Double(i)) + Double(i % 2) * 9
            let y = base + (12 - Foundation.sin(Double(i) * 1.7) * 8) * scale
            let sway = Foundation.sin(t * 1.4 + Double(i) * 1.3) * 6 * scale
            let top = CGPoint(x: x + sway, y: y - (26 + Double(i % 3) * 6) * scale)
            var stem = Path(); stem.move(to: CGPoint(x: x, y: y)); stem.addQuadCurve(to: top, control: CGPoint(x: x + sway * 0.2, y: y - 9))
            ctx.stroke(stem, with: .color(Color(hex: 0x6ABF6E).opacity(0.6)), lineWidth: 1.8 * scale)
            let c = petals[i % petals.count].opacity(0.72)
            let pr = 5.4 * scale, pd = 8.0 * scale
            for k in 0..<5 {
                let a = Double(k) / 5 * 2 * .pi + t * 0.15
                ctx.fill(Path(ellipseIn: CGRect(x: top.x + Foundation.cos(a) * pr - pd / 2, y: top.y + Foundation.sin(a) * pr - pd / 2, width: pd, height: pd)), with: .color(c))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: top.x - 2.6 * scale, y: top.y - 2.6 * scale, width: 5.2 * scale, height: 5.2 * scale)), with: .color(Color(hex: 0xFFC23D).opacity(0.85)))
        }
        // a wooden ring stacker and a ball resting in the grass on the right
        let q = 1.35 * scale, sx = w * 0.84, sy = base + 6 * scale
        ctx.fill(Path(roundedRect: CGRect(x: sx - 16 * q, y: sy - 4 * q, width: 32 * q, height: 6 * q), cornerRadius: 3 * q), with: .color(Color(hex: 0xD9A56C).opacity(0.55)))
        ctx.fill(Path(roundedRect: CGRect(x: sx - 1.5 * q, y: sy - 34 * q, width: 3 * q, height: 30 * q), cornerRadius: 1.5 * q), with: .color(Color(hex: 0xC98F5E).opacity(0.55)))
        for (k, c) in [Color(hex: 0x4C9BE8), Color(hex: 0x1FB5A6), Color(hex: 0xFFC23D), Color(hex: 0xFF6F91)].enumerated() {
            let rw = (26.0 - Double(k) * 5) * q
            ctx.fill(Path(roundedRect: CGRect(x: sx - rw / 2, y: sy - (10 + Double(k) * 6.5) * q, width: rw, height: 6.5 * q), cornerRadius: 3.2 * q), with: .color(c.opacity(0.48)))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: sx - 46 * q, y: sy - 12 * q, width: 14 * q, height: 14 * q)), with: .color(Color(hex: 0xF2554B).opacity(0.45)))
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

/// Specks of Otto's lamplight rising slowly through the dark, as dust in a lamp's beam, over the whole page. Off
/// under Reduce Motion.
struct Motes: View {
    var scale: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduce
    var body: some View {
        // risen by Core Animation at the display's full frame rate, off the main thread
        if !reduce && ArtStyle.current == .flat { AirEmitter(kind: .night, scale: scale).allowsHitTesting(false) }
    }
}

/// Otto's lamp: a warm pool of amber from the top right that slowly brightens and dims like a flame behind paper,
/// and a fainter second pool low on the left, so the whole page is lit, not just its corner.
struct LampGlow: View {
    /// The reach of the light, for small previews.
    var scale: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var bright = false
    var body: some View {
        ZStack {
            RadialGradient(colors: [Palette.amber.opacity(0.46), Palette.amber.opacity(0.13), Palette.amber.opacity(0)], center: UnitPoint(x: 0.88, y: 0.02), startRadius: 0, endRadius: 560 * scale)
            RadialGradient(colors: [Palette.amber.opacity(0.15), Palette.amber.opacity(0)], center: UnitPoint(x: 0.05, y: 0.92), startRadius: 0, endRadius: 420 * scale)
        }
        // the flame's slow breath: one change of opacity, composited by the system, nothing redrawn
        .opacity(bright ? 1 : 0.8)
        .onAppear { if !reduce { withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) { bright = true } } }
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
                if let detail { Text(detail).font(.footnote).foregroundStyle(Palette.secondaryText).monospacedDigit() }
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
                Text(p.1).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondaryText).padding(.trailing, i < parts.count - 1 ? 4 : 0)
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
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // every section starts at a golden bead, the same bead as the counts and the growth chain
            GoldBead(size: 10).alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
            Text(title).font(.title3.weight(.bold))
            Spacer()
            if let detail { Text(detail).font(.footnote).foregroundStyle(Palette.secondaryText) }
        }
        .padding(.horizontal, 4).padding(.top, 20)
        .accessibilityAddTraits(.isHeader)
    }
}

/// The golden bead (Montessori's golden bead): a small glossy sphere, lit from the upper left, on a hair of shadow.
struct GoldBead: View {
    var size: CGFloat = 10
    var body: some View {
        if ArtStyle.current != .flat { bead }
    }
    private var bead: some View {
        Circle()
            .fill(RadialGradient(colors: [Palette.beadLight, Palette.bead, Color(hex: 0x9C6F08)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.7))
            .overlay(Circle().fill(.white.opacity(0.7)).frame(width: size * 0.28, height: size * 0.28).offset(x: -size * 0.16, y: -size * 0.18))
            .frame(width: size, height: size)
            .shadow(color: Color(hex: 0x7A5230).opacity(0.25), radius: 1, y: 1)
            .accessibilityHidden(true)
    }
}

/// A card of paper on the page: one flat colour and a soft shadow — no gloss, no light edge, no gradient
/// (ios/DESIGN.md §3). In dark mode a hairline replaces the shadow, which would not show.
struct PrintCard: ViewModifier {
    var radius: CGFloat = 24
    var fill: Color = Palette.card
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    /// The card as a piece of the same soft vinyl as Moss and Otto: an even matte colour, lit from above (a breath
    /// lighter at the top, a soft lit edge along the top rim, the faintest shade toward the bottom), sitting on the
    /// page with a small contact shadow and a wide soft one — no gloss, no hard border. The shadows are cast by the
    /// card's own shape behind the content (not by the content), so scrolling never has to redraw them off-screen.
    @ViewBuilder
    func body(content: Self.Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let dark = lamp || scheme == .dark
        let base = lamp ? Palette.lampCard : fill
        if ArtStyle.current == .flat {
            // build 196: one flat colour of paper, a soft shadow
            content
                .background { ZStack { base; Grain(dark: dark, strength: 0.6) }.clipShape(shape) }
                .clipShape(shape)
                .overlay { if scheme == .dark { shape.strokeBorder(.white.opacity(0.07), lineWidth: 1) } }
                .shadow(color: scheme == .dark ? .clear : Color(hex: 0x7A5230).opacity(0.09), radius: 10, y: 4)
        } else {
        content
            .background {
                ZStack {
                    base
                    // lit from above: a plain gradient (a blend mode here cost every card an off-screen pass on each frame
                    // of a scroll)
                    LinearGradient(colors: [.white.opacity(dark ? 0.04 : 0.2), .white.opacity(0), Color(hex: 0x7A5230).opacity(dark ? 0 : 0.03)],
                                   startPoint: .top, endPoint: .bottom)
                    Grain(dark: dark, strength: 0.6)
                }
            }
            .clipShape(shape)
            .background {
                // one soft shadow (two blurred passes per card cost every frame of a scroll or a page transition)
                shape.fill(base)
                    .shadow(color: dark ? .black.opacity(0.22) : Color(hex: 0x7A5230).opacity(0.13), radius: 7, y: 4)
            }
            .overlay {
                // the lit rim: light along the top edge fading down the sides, as on a cast vinyl piece
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(dark ? 0.12 : 0.95), .white.opacity(dark ? 0.03 : 0.25), .white.opacity(0)],
                                                  startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
                    .allowsHitTesting(false)
            }
            .contentShape(shape)
        }
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

/// A small surface in the same vinyl as the cards and buttons — a chip, a stamp, a day in the week strip: the colour
/// as a soft tint (or the colour itself when `strong`), lit from above with a lit rim, on a hair of contact shadow.
struct VinylSurface: ViewModifier {
    var tint: Color
    var radius: CGFloat = 14
    var strong = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @ViewBuilder
    func body(content: Self.Content) -> some View {
        let dark = lamp || scheme == .dark
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if ArtStyle.current == .flat {
            content.background(shape.fill(strong ? tint : tint.opacity(dark ? 0.2 : 0.12)))
        } else {
        content.background {
            shape.fill(strong ? tint : tint.opacity(dark ? 0.22 : 0.14))
                .overlay(shape.fill(LinearGradient(colors: [.white.opacity(strong ? 0.26 : (dark ? 0.06 : 0.5)), .white.opacity(0)], startPoint: .top, endPoint: .center)))
                .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(dark ? 0.14 : 0.85), .white.opacity(0)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                .shadow(color: (strong ? tint : Color(hex: 0x7A5230)).opacity(dark ? 0 : (strong ? 0.3 : 0.08)), radius: strong ? 5 : 2, y: strong ? 3 : 1)
        }
        }
    }
}
extension View {
    func vinylSurface(_ tint: Color, radius: CGFloat = 14, strong: Bool = false) -> some View { modifier(VinylSurface(tint: tint, radius: radius, strong: strong)) }
}

/// A button made like the characters and the icons' tokens: a pill of matte soft vinyl. Soft (the default): a light
/// tint of the colour with the colour's own ink — for 下一步, 记一次 and the like. Prominent: the colour itself with
/// white type — for the one main action of a screen. Both are lit from above (a lighter top, a lit rim), stand on
/// the page with a small contact shadow, and squash a little when pressed, with a light tap.
struct VinylButton: ButtonStyle {
    var tint: Color = Palette.accent
    var prominent = false
    var large = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let dark = lamp || scheme == .dark
        let body = prominent ? tint : tint.opacity(dark ? 0.26 : 0.16)
        let ink: Color = prominent ? .white : Crayon.ink(tint)
        let shape = Capsule(style: .continuous)
        if ArtStyle.current == .flat {
            // build 196: the system's tinted capsule
            configuration.label
                .font((large ? Font.body : Font.subheadline).weight(.semibold))
                .foregroundStyle(ink)
                .padding(.horizontal, large ? 22 : 14).padding(.vertical, large ? 14 : 8)
                .frame(minHeight: 44)
                .background(shape.fill(prominent ? tint : tint.opacity(dark ? 0.22 : 0.14)))
                .contentShape(shape)
                .opacity(enabled ? (configuration.isPressed ? 0.6 : 1) : 0.45)
        } else {
        configuration.label
            .font((large ? Font.body : Font.subheadline).weight(.semibold))
            .foregroundStyle(ink)
            .padding(.horizontal, large ? 22 : 16).padding(.vertical, large ? 14 : 9)
            .frame(minHeight: 44)
            .background {
                shape.fill(body)
                    .overlay(shape.fill(LinearGradient(colors: [.white.opacity(prominent ? 0.28 : 0.45), .white.opacity(0)], startPoint: .top, endPoint: .center)))
                    .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(dark ? 0.18 : 0.8), .white.opacity(0)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                    .shadow(color: (prominent ? tint : Color(hex: 0x7A5230)).opacity(dark ? 0 : (prominent ? 0.28 : 0.10)), radius: prominent ? 6 : 3, y: prominent ? 3 : 2)
            }
            .contentShape(shape)
            .opacity(enabled ? 1 : 0.45)
            .scaleEffect(x: configuration.isPressed ? 1.03 : 1, y: configuration.isPressed ? 0.93 : 1, anchor: .bottom)
            .animation(.spring(response: 0.22, dampingFraction: 0.5), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: configuration.isPressed) { _, new in new }
        }
    }
}
extension ButtonStyle where Self == VinylButton {
    static var vinyl: VinylButton { VinylButton() }
    static func vinyl(_ tint: Color, prominent: Bool = false, large: Bool = false) -> VinylButton { VinylButton(tint: tint, prominent: prominent, large: large) }
}
