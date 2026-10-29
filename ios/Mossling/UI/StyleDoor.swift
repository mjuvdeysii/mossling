import SwiftUI

// MARK: the hidden door between the two worlds
//
// The story itself has no door you can see: tap the two (on 关于摸索台灯, or at the foot of 今天) and they hop; on the third
// tap they take you into 摸索台灯的故事. It opens on a picture of the lamp and the two. Tap the picture quickly: from the fifth
// tap a drop of colour falls where the finger struck, each further tap lets another bleed into it, and on the tenth the
// colour runs: a watercolour wash spreads from that point over the whole screen, wet paper with its pigment pooling at
// the edge, the world turns to the 2D paper world under it, and the wash dries back toward the point it came from.
// In the 2D world, keep a finger moving on the picture for three seconds without lifting it: a soft line of light is
// drawn round them, and when it closes a warm light bleeds out from them the same way and the 3D world comes back.

/// What the overlay above the whole app is showing.
@Observable final class StyleShift {
    static let shared = StyleShift()
    enum Phase: Equatable { case idle, wash(start: Date), bloom(start: Date) }
    var phase: Phase = .idle
    /// Where the picture was on screen.
    var frame: CGRect = .zero
    /// Where the colour fell, as a fraction of the picture.
    var impact = CGPoint(x: 0.45, y: 0.5)
}

/// The story page's title picture, as the door.
///
/// A double tap does nothing you can see. Five quick taps and a drop of colour falls where the finger struck; every
/// further quick tap bleeds another into it; the tenth lets the colour run. Stop tapping and the drops dry away.
struct StyleDoor<Content: View>: View {
    var radius: CGFloat = 28
    @ViewBuilder let content: Content
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var taps = 0
    @State private var lastTap = Date.distantPast
    /// Where the first drop fell, as a fraction of the picture.
    @State private var impact = CGPoint(x: 0.45, y: 0.5)
    @State private var size: CGSize = .zero
    @State private var frame: CGRect = .zero
    // the way back: how long the finger has been moving, and when it last moved
    @State private var held: Date?
    @State private var lastMove = Date.distantPast
    @State private var progress = 0.0
    @State private var ticks = 0

    /// Taps before the first drop shows, and the tap that lets the colour run.
    static var crackAt: Int { 5 }
    static var breakAt: Int { 10 }
    private var flat: Bool { app.artStyle == .flat }
    private var level: Int { taps - Self.crackAt + 1 }

    var body: some View {
        content
            .overlay {
                if !flat && level >= 1 {
                    Drops(amount: CGFloat(level), impact: impact).allowsHitTesting(false).transition(.opacity)
                        .animation(.easeOut(duration: 0.55), value: level)
                }
            }
            .overlay { if flat && progress > 0 { ProgressHalo(progress: progress, radius: radius).allowsHitTesting(false) } }
            .contentShape(Rectangle())
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0; size = $0.size }
            .onTapGesture(coordinateSpace: .local) { loc in if !flat { tapped(at: loc) } }
            .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in if flat { moved() } }.onEnded { _ in if flat { reset() } })
            .sensoryFeedback(trigger: taps) { old, new in
                guard new > old else { return nil }
                return new >= Self.crackAt ? .impact(flexibility: .soft, intensity: min(1, 0.4 + Double(new - Self.crackAt) * 0.1)) : nil
            }
            .sensoryFeedback(.selection, trigger: ticks)
    }

    private func tapped(at loc: CGPoint) {
        let now = Date()
        // before the first drop the taps must come fast; once the colour is down it waits a little longer for the next
        let window: TimeInterval = taps >= Self.crackAt ? 0.8 : 0.42
        taps = now.timeIntervalSince(lastTap) < window ? taps + 1 : 1
        lastTap = now
        if taps == Self.crackAt, size.width > 1 {
            impact = CGPoint(x: min(0.92, max(0.08, loc.x / size.width)), y: min(0.92, max(0.08, loc.y / size.height)))
        }
        if taps >= Self.breakAt { taps = 0; run(); return }
        // left alone, the drops dry away
        let stamp = now
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            if lastTap == stamp && taps > 0 { withAnimation(.easeOut(duration: 0.6)) { taps = 0 } }
        }
    }

    private func run() {
        StyleShift.shared.frame = frame
        StyleShift.shared.impact = impact
        if reduce { app.artStyle = .flat; return }
        StyleShift.shared.phase = .wash(start: Date())
        // the world changes under the wash once it covers the screen
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(Wash.covered * 1000) + 20))
            app.artStyle = .flat
            try? await Task.sleep(for: .milliseconds(Int((Wash.length - Wash.covered) * 1000)))
            StyleShift.shared.phase = .idle
        }
    }

    private func moved() {
        let now = Date()
        if held == nil || now.timeIntervalSince(lastMove) > 0.45 { held = now }   // a pause starts it over
        lastMove = now
        guard let h = held else { return }
        let p = min(1, now.timeIntervalSince(h) / 3)
        if Int(p * 3) > Int(progress * 3) { ticks += 1 }
        progress = p
        if p >= 1 { held = nil; progress = 0; bloom() }
    }

    private func reset() { held = nil; withAnimation(.easeOut(duration: 0.25)) { progress = 0 } }

    private func bloom() {
        StyleShift.shared.frame = frame
        StyleShift.shared.impact = CGPoint(x: 0.5, y: 0.55)
        if reduce { app.artStyle = .vinyl; return }
        StyleShift.shared.phase = .bloom(start: Date())
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(Wash.covered * 1000) + 20))
            app.artStyle = .vinyl
            try? await Task.sleep(for: .milliseconds(Int((Wash.length - Wash.covered) * 1000)))
            StyleShift.shared.phase = .idle
        }
    }
}

/// A small fixed-seed generator, so the same drops and paper grain fall the same way every time.
struct GlassRandom: RandomNumberGenerator {
    var state: UInt64
    init(_ seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> CGFloat { CGFloat(Double(next() >> 11) / Double(1 << 53)) }
    mutating func range(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * unit() }
}

/// The soft line of light drawn round the picture while the finger keeps moving: a blurred under-glow and a fine
/// line over it, its tip a little brighter, like a brush of light going round.
private struct ProgressHalo: View {
    let progress: Double
    var radius: CGFloat = 28
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius + 4, style: .continuous)
        ZStack {
            shape.trim(from: 0, to: progress)
                .stroke(Palette.bead.opacity(0.55), style: StrokeStyle(lineWidth: 9, lineCap: .round)).blur(radius: 6)
            shape.trim(from: 0, to: progress)
                .stroke(LinearGradient(colors: [Palette.beadLight.opacity(0.5), Palette.beadLight], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
        .padding(-4)
    }
}

/// Drops of watercolour where the picture was tapped: one for each tap past the fourth, each bleeding into the last,
/// soft in the middle and darker at the rim where the pigment gathers as it dries.
private struct Drops: View, Animatable {
    var amount: CGFloat
    let impact: CGPoint
    var animatableData: CGFloat { get { amount } set { amount = newValue } }
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: impact.x * size.width, y: impact.y * size.height)
            var g = GlassRandom(0xD_80B5)
            let n = Int(amount.rounded(.up))
            ctx.blendMode = .multiply
            for i in 0..<max(0, n) {
                let grow: CGFloat = min(1, amount - CGFloat(i))
                guard grow > 0 else { continue }
                let off = i == 0 ? CGPoint.zero : CGPoint(x: g.range(-1, 1) * 14 * CGFloat(i), y: g.range(-1, 1) * 10 * CGFloat(i))
                let r: CGFloat = (12 + CGFloat(i) * 7) * (0.35 + 0.65 * grow)
                let tint = Wash.pigments[i % Wash.pigments.count]
                let blob = Wash.blob(CGPoint(x: c.x + off.x, y: c.y + off.y), r, seed: CGFloat(i) * 1.7, wobble: 0.12)
                ctx.fill(blob, with: .radialGradient(Gradient(colors: [tint.opacity(0.10), tint.opacity(0.24)]),
                                                     center: CGPoint(x: c.x + off.x, y: c.y + off.y), startRadius: 0, endRadius: r))
                ctx.stroke(blob, with: .color(tint.opacity(0.32)), lineWidth: 1.1)
            }
        }
    }
}

/// Above the whole app: the watercolour wash going into the paper world, or the light coming back out of it.
struct StyleShiftOverlay: View {
    @State private var shift = StyleShift.shared
    var body: some View {
        switch shift.phase {
        case .idle: EmptyView()
        case .wash(let start): Wash(start: start, frame: shift.frame, impact: shift.impact, light: false).ignoresSafeArea().allowsHitTesting(false)
        case .bloom(let start): Wash(start: start, frame: shift.frame, impact: shift.impact, light: true).ignoresSafeArea().allowsHitTesting(false)
        }
    }
}

/// A wash of colour spreading over wet paper from one point, edge wandering as water does, pigment pooling at the rim,
/// a few blooms of other colours bleeding in behind it. Once it covers the screen the world changes underneath; then
/// it dries back toward where it began, leaving the new world, with a soft rim of colour on the retreating edge.
/// `light`: the way back — warm lamp light instead of pigment, the same movement, a few motes of light rising after.
struct Wash: View {
    let start: Date
    let frame: CGRect
    let impact: CGPoint
    let light: Bool
    /// A fixed moment to draw (for still pictures of it); nil runs it in time.
    var at: Double? = nil
    /// When the wash has covered the screen (the world changes then), and the whole length of it.
    static let covered: Double = 0.62
    static let length: Double = 1.55
    static let pigments: [Color] = [Color(hex: 0x8FB39A), Color(hex: 0xE3A48F), Color(hex: 0x9DBBD6), Color(hex: 0xE8C27A)]
    private static let paper = Color(hex: 0xF7F0E3)

    var body: some View {
        TimelineView(.animation) { tl in
            let t = at ?? tl.date.timeIntervalSince(start)
            Canvas { ctx, size in draw(&ctx, size, t) }
        }
    }

    /// A closed, softly irregular round shape: the edge of water on paper.
    static func blob(_ c: CGPoint, _ r: CGFloat, seed: CGFloat, wobble: CGFloat = 0.07) -> Path {
        var p = Path()
        let n = 72
        for i in 0...n {
            let a: CGFloat = CGFloat(i) / CGFloat(n) * 2 * .pi
            let w1: CGFloat = sin(3 * a + seed) * 0.5
            let w2: CGFloat = sin(7 * a + seed * 2.3) * 0.32
            let w3: CGFloat = sin(13 * a + seed * 4.1) * 0.18
            let k: CGFloat = 1 + wobble * (w1 + w2 + w3)
            let q = CGPoint(x: c.x + cos(a) * r * k, y: c.y + sin(a) * r * k)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        return p
    }

    private static func ease(_ x: Double) -> CGFloat { let u = min(1, max(0, x)); return CGFloat(1 - pow(1 - u, 3)) }
    private static func easeIn(_ x: Double) -> CGFloat { let u = min(1, max(0, x)); return CGFloat(u * u * (3 - 2 * u)) }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let c = CGPoint(x: frame.minX + impact.x * frame.width, y: frame.minY + impact.y * frame.height)
        let far: CGFloat = hypot(max(c.x, size.width - c.x), max(c.y, size.height - c.y)) * 1.25
        let base: Color = light ? Color(hex: 0xFFF1D2) : Self.paper
        let rim: Color = light ? Color(hex: 0xFFD27A) : Self.pigments[0]
        // spreading: the wash runs out from the point, fast then slowing, its edge wandering as it goes
        let spread: CGFloat = Self.ease(t / Self.covered)
        let r: CGFloat = 8 + far * spread
        let seed: CGFloat = CGFloat(t) * 0.9
        let outer = Self.blob(c, r, seed: seed)
        // drying back: a hole opens from the same point and widens, so the new world shows from where it began
        let dry: CGFloat = Self.easeIn((t - Self.covered - 0.08) / (Self.length - Self.covered - 0.08))
        let hr: CGFloat = far * dry
        var shape = outer
        if hr > 1 { shape.addPath(Self.blob(c, hr, seed: seed + 1.3, wobble: 0.1)) }
        let fill = FillStyle(eoFill: true)
        if light {
            // lamp light: warmest where it comes from, paling toward its edge
            ctx.fill(shape, with: .radialGradient(Gradient(colors: [Color(hex: 0xFFDDA0), Color(hex: 0xFFE9C4), base]),
                                                  center: c, startRadius: 0, endRadius: max(40, r * 0.9)), style: fill)
        } else {
            ctx.fill(shape, with: .color(base), style: fill)
        }
        // pigment: blooms of colour bleeding in behind the edge, and the colour gathered at the rim
        var tint = ctx
        tint.clip(to: shape, style: fill)
        tint.blendMode = .normal
        let tints: [Color] = light ? [Color(hex: 0xF5B45F), Color(hex: 0xF2A07A), Color(hex: 0xFFD27A)] : Self.pigments
        for (i, col) in tints.enumerated() {
            let a: CGFloat = CGFloat(i) * 2.1 + 0.6
            let lag: CGFloat = Self.ease((t - 0.06 * Double(i + 1)) / Self.covered)
            let pr: CGFloat = far * 0.55 * lag
            guard pr > 2 else { continue }
            let pc = CGPoint(x: c.x + cos(a) * far * 0.28 * lag, y: c.y + sin(a) * far * 0.22 * lag)
            // each bloom pale in the middle and deeper at its edge, where watercolour pigment settles as it dries
            let bloom = Self.blob(pc, pr, seed: CGFloat(i) * 2 + seed, wobble: 0.14)
            tint.fill(bloom, with: .radialGradient(Gradient(colors: [col.opacity(0.07), col.opacity(0.16), col.opacity(0.30)]), center: pc, startRadius: 0, endRadius: pr * 1.05))
            tint.stroke(bloom, with: .color(col.opacity(0.38)), lineWidth: 1.4)
        }
        // paper grain, faint
        if !light {
            var g = GlassRandom(0x9A9E2)
            for _ in 0..<260 {
                let p = CGPoint(x: g.unit() * size.width, y: g.unit() * size.height)
                tint.fill(Path(ellipseIn: CGRect(x: p.x, y: p.y, width: 1.4, height: 1.4)), with: .color(.black.opacity(0.035)))
            }
        }
        // the rim where the pigment pools, on the spreading edge and the drying one
        if spread < 0.999 {
            ctx.stroke(outer, with: .color(rim.opacity(0.45)), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            ctx.drawLayer { l in l.addFilter(.blur(radius: 5)); l.stroke(outer, with: .color(rim.opacity(0.35)), lineWidth: 10) }
        }
        if hr > 1 {
            let inner = Self.blob(c, hr, seed: seed + 1.3, wobble: 0.1)
            let o: Double = Double(1 - dry) * 0.5
            ctx.stroke(inner, with: .color(rim.opacity(o)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            ctx.drawLayer { l in l.addFilter(.blur(radius: 6)); l.stroke(inner, with: .color(rim.opacity(o * 0.7)), lineWidth: 12) }
        }
        // coming back to the lamp-lit world: a few motes of light rise from where it began as it dries
        if light && t > Self.covered {
            for i in 0..<12 {
                let u: CGFloat = CGFloat(t - Self.covered) * (0.7 + CGFloat(i % 4) * 0.14)
                let x: CGFloat = c.x + sin(CGFloat(i) * 1.9) * 110 * u
                let y: CGFloat = c.y - 170 * u - CGFloat(i % 3) * 14
                let o: Double = Double(max(0, 1 - u * 1.1))
                ctx.fill(Path(ellipseIn: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)), with: .color(Palette.bead.opacity(o)))
            }
        }
    }
}

// MARK: the story's own door

extension View {
    /// Tap the two and they hop (`hops` goes up); the third quick tap opens what is behind them. VoiceOver users get
    /// the same way in as a named action, since they cannot find it by touch.
    func storyKnock(hops: Binding<Int>, open: @escaping () -> Void) -> some View {
        modifier(StoryKnock(hops: hops, open: open))
    }
}

private struct StoryKnock: ViewModifier {
    @Binding var hops: Int
    let open: () -> Void
    @State private var count = 0
    @State private var last = Date.distantPast
    func body(content: Self.Content) -> some View {
        content
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded {
                let now = Date()
                count = now.timeIntervalSince(last) < 1.1 ? count + 1 : 1
                last = now
                hops += 1
                if count >= 3 {
                    count = 0
                    Task { @MainActor in try? await Task.sleep(for: .milliseconds(380)); open() }
                }
            })
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.5), trigger: hops)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Moss 和 Otto")
            .accessibilityAction(named: "他们的故事") { open() }
    }
}
