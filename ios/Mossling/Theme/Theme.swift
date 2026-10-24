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
                LampGlow()
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
                DayAir(tone: tone ?? Crayon.sunflower)
            }
            .ignoresSafeArea().accessibilityHidden(true)
        }
    }
}

/// The day's counterpart of the lamp's drifting motes: a garden morning behind the paper. Sunlight comes in from the
/// top right in a few soft beams that slowly breathe; dandelion seeds, petals in the tab's colour, small leaves and
/// specks of pollen drift across on the air; at the foot of the page a low hill of grass where a few flowers sway, a
/// wooden ring stacker and a ball resting in it. Everything is faint — the paper stays paper — and moves at ten frames
/// a second, slowly enough to be felt more than watched. Still under Reduce Motion.
struct DayAir: View {
    var tone: Color
    /// Only a few drifting things, fainter (drawn over the content).
    var sparse = false
    /// Size of everything, for small previews (the theme swatches).
    var scale: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduce
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15, paused: reduce)) { tl in
            Canvas { ctx, size in
                let t = reduce ? 0 : tl.date.timeIntervalSinceReferenceDate
                if !sparse {
                    sun(&ctx, size, t)
                    meadow(&ctx, size, t)
                }
                drift(&ctx, size, t)
            }
        }
        .allowsHitTesting(false)
    }

    private func sun(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let o = CGPoint(x: size.width * 0.96, y: -size.height * 0.02)
        let R = 320 * scale
        ctx.fill(Path(ellipseIn: CGRect(x: o.x - R, y: o.y - R, width: 2 * R, height: 2 * R)),
                 with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE39A).opacity(0.75), Color(hex: 0xFFE9A8).opacity(0.25), Color(hex: 0xFFE9A8).opacity(0)]), center: o, startRadius: 0, endRadius: R))
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

    private func drift(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let w = size.width, h = size.height
        let n = sparse ? 6 : 18, z = 1.7 * scale, fade = sparse ? 0.6 : 1.0
        for i in 0..<n {
            let s = Double(i) * 0.618 + (sparse ? 0.27 : 0)
            let period = 15.0 + Double(i % 5) * 4.5
            let f = (t / period + s).truncatingRemainder(dividingBy: 1)          // 0 … 1 across the page
            let x = -30 + (w + 60) * f
            let y0 = h * (0.06 + 0.62 * (s * 1.37).truncatingRemainder(dividingBy: 1))
            let y = y0 + f * 90 + Foundation.sin(t * 0.9 + Double(i) * 2.3) * 18 * scale
            let a = min(1, f * 6) * min(1, (1 - f) * 6) * fade                     // fade in and out at the edges
            let p = CGPoint(x: x, y: y)
            switch i % 4 {
            case 0:   // a dandelion seed: a fluff of fine rays on a short stalk
                let r = 6.0 * z
                for k in 0..<9 {
                    let q = Double(k) / 9 * .pi + .pi + Foundation.sin(t * 0.6 + Double(i)) * 0.2
                    var ray = Path(); ray.move(to: p); ray.addLine(to: CGPoint(x: p.x + Foundation.cos(q) * r, y: p.y + Foundation.sin(q) * r))
                    ctx.stroke(ray, with: .color(Color.white.opacity(0.9 * a)), lineWidth: 1)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x + Foundation.cos(q) * r - 1, y: p.y + Foundation.sin(q) * r - 1, width: 2, height: 2)), with: .color(Color.white.opacity(0.9 * a)))
                }
                var stalk = Path(); stalk.move(to: p); stalk.addLine(to: CGPoint(x: p.x, y: p.y + 7 * z))
                ctx.stroke(stalk, with: .color(Color(hex: 0xB8A070).opacity(0.75 * a)), lineWidth: 1)
            case 1:   // a petal in the tab's colour, turning
                var g = ctx; g.translateBy(x: p.x, y: p.y); g.rotate(by: .radians(t * 0.9 + Double(i))); g.scaleBy(x: z, y: z * (0.7 + 0.3 * Foundation.sin(t * 1.3 + Double(i))))
                g.fill(Path(ellipseIn: CGRect(x: -4.5, y: -2.4, width: 9, height: 4.8)), with: .color(tone.opacity(0.62 * a)))
            case 2:   // a small leaf
                var g = ctx; g.translateBy(x: p.x, y: p.y); g.rotate(by: .radians(Foundation.sin(t * 1.1 + Double(i)) * 1.1)); g.scaleBy(x: z, y: z)
                var leaf = Path(); leaf.move(to: CGPoint(x: -5, y: 0)); leaf.addQuadCurve(to: CGPoint(x: 5, y: 0), control: CGPoint(x: 0, y: -4)); leaf.addQuadCurve(to: CGPoint(x: -5, y: 0), control: CGPoint(x: 0, y: 4))
                g.fill(leaf, with: .color(Color(hex: 0x6ABF6E).opacity(0.55 * a)))
                var vein = Path(); vein.move(to: CGPoint(x: -4, y: 0)); vein.addLine(to: CGPoint(x: 4, y: 0))
                g.stroke(vein, with: .color(Color(hex: 0x3F8F4A).opacity(0.4 * a)), lineWidth: 0.6)
            default:  // a speck of pollen catching the light
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 6 * z, y: p.y - 6 * z, width: 12 * z, height: 12 * z)), with: .color(Color(hex: 0xFFD36B).opacity(0.18 * a)))
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.8 * z, y: p.y - 1.8 * z, width: 3.6 * z, height: 3.6 * z)), with: .color(Color(hex: 0xFFC23D).opacity(0.7 * a)))
            }
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
struct Motes: View {
    /// Fewer and fainter, for drifting over the content itself.
    var sparse = false
    var scale: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduce
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15, paused: reduce)) { tl in
            Canvas { ctx, size in
                let t = reduce ? 0 : tl.date.timeIntervalSinceReferenceDate
                let n = sparse ? 6 : 22
                for i in 0..<n {
                    let s = Double(i) * 0.618 + (sparse ? 0.31 : 0)
                    // they rise slowly through the lamp's light, swaying, and come round again
                    let period = 34.0 + Double(i % 4) * 9
                    let f = (t / period + s).truncatingRemainder(dividingBy: 1)
                    let x = size.width * (0.08 + 0.9 * (s * 1.3).truncatingRemainder(dividingBy: 1)) + Foundation.sin(t * 0.35 + Double(i)) * 26 * scale
                    let y = size.height * (1.02 - f * 1.05)
                    let edge = min(1, f * 6) * min(1, (1 - f) * 6)
                    let a = (0.3 + 0.4 * (0.5 + 0.5 * Foundation.sin(t * 1.1 + Double(i) * 1.3))) * edge * (sparse ? 0.55 : 1)
                    let r = (1.6 + Double(i % 4) * 0.9) * scale
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r * 4, y: y - r * 4, width: r * 8, height: r * 8)), with: .color(Palette.amber.opacity(a * 0.22)))
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Palette.amber.opacity(a)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Otto's lamp: a warm pool of amber from the top right that slowly brightens and dims like a flame behind paper,
/// and a fainter second pool low on the left, so the whole page is lit, not just its corner.
struct LampGlow: View {
    /// The reach of the light, for small previews.
    var scale: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduce
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 10, paused: reduce)) { tl in
            let t = reduce ? 0 : tl.date.timeIntervalSinceReferenceDate
            let k = 0.88 + 0.12 * Foundation.sin(t * 0.7) + 0.04 * Foundation.sin(t * 2.3)
            ZStack {
                RadialGradient(colors: [Palette.amber.opacity(0.42 * k), Palette.amber.opacity(0.12 * k), Palette.amber.opacity(0)], center: UnitPoint(x: 0.88, y: 0.02), startRadius: 0, endRadius: 560 * scale)
                RadialGradient(colors: [Palette.amber.opacity(0.14 * k), Palette.amber.opacity(0)], center: UnitPoint(x: 0.05, y: 0.92), startRadius: 0, endRadius: 420 * scale)
            }
        }
        .allowsHitTesting(false)
    }
}

/// A few of the page's drifting things over the content itself — seeds and petals by day, motes of lamplight at
/// night — so the air moves across the whole screen, not only between the cards. Sparse and faint; nothing to tap.
struct AmbientDrift: View {
    @Environment(\.lamp) private var lamp
    var body: some View {
        Group {
            if lamp { Motes(sparse: true) } else { DayAir(tone: Crayon.sunflower, sparse: true) }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
