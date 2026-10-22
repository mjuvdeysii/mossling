import SwiftUI

/// A companion. `look` is where the pupils point (each axis −1…1); `lid` closes the eye (0 open, 1 shut), nil uses the
/// character's own rest (Otto rests under a heavy lid). It breathes, blinks now and then, glances away and back, hops
/// once when it becomes happy; Moss's mint leaves sway. Five quick taps on Moss send a few mint leaves drifting up.
/// Everything is computed from time, so it stays still when Reduce Motion is on.
struct Creature: View {
    let kind: Kind
    var mood: Mood = .open
    var look: CGPoint = .zero
    var lid: Double? = nil
    var lean: Double = 0
    var alive: Bool = true
    var poke: Bool = false
    var label: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.colorScheme) private var scheme
    @State private var blinkAt = Date.distantPast
    @State private var doubleBlink = false
    @State private var hopAt = Date.distantPast
    @State private var hopSize = 1.0
    @State private var leafAt = Date.distantPast
    @State private var fleckAt = Date.distantPast
    @State private var glanceTo = CGPoint.zero
    @State private var glanceAt = Date.distantPast
    @State private var lookFrom = CGPoint.zero
    @State private var lookAt = Date.distantPast
    @State private var leanFrom = 0.0
    @State private var leanAt = Date.distantPast
    @State private var taps = 0
    @State private var lastTap = Date.distantPast

    private var still: Bool { !alive || reduce }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: still)) { tl in
            Canvas { ctx, size in draw(&ctx, size, still ? Date.distantPast : tl.date) }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(label ?? "")
        .accessibilityHidden(label == nil)
        .contentShape(Rectangle())
        .onTapGesture { if poke && !still { tapped() } }
        .allowsHitTesting(poke)
        .task(id: still) { await blinks() }
        .task(id: still) { await glances() }
        .onChange(of: mood) { old, new in if new == .happy && old != .happy && !still { hopSize = 1; hopAt = Date() } }
        .onChange(of: look) { old, _ in lookFrom = old; lookAt = Date() }
        .onChange(of: lean) { old, _ in leanFrom = old; leanAt = Date() }
    }

    private func tapped() {
        let now = Date()
        taps = now.timeIntervalSince(lastTap) < 0.9 ? taps + 1 : 1
        lastTap = now
        blinkAt = now; doubleBlink = false
        hopSize = 0.7; hopAt = now
        leafAt = now
        if taps >= 5 { taps = 0; fleckAt = now }   // 小薄荷
    }

    /// Irregular blinks, sometimes two.
    private func blinks() async {
        guard !still else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(2600 + Int.random(in: 0...4200)))
            if mood == .open || mood == .wow { doubleBlink = Int.random(in: 0..<5) == 0; blinkAt = Date() }
        }
    }
    /// A glance away now and then, held, and back.
    private func glances() async {
        guard !still else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(7000 + Int.random(in: 0...7000)))
            guard mood != .sleep else { continue }
            glanceTo = CGPoint(x: Double.random(in: -0.6...0.6) - look.x * 0.6, y: Double.random(in: -0.5...0.3) - look.y * 0.6)
            glanceAt = Date()
        }
    }

    // MARK: curves

    private static func ease(_ x: Double) -> Double { let t = max(0, min(1, x)); return t * t * (3 - 2 * t) }
    /// A damped bounce: 0 → up → settles, over about 0.7 s.
    private static func bounce(_ t: Double) -> Double { t < 0 || t > 1.2 ? 0 : exp(-5 * t) * sin(t * 11) }

    private func blinkValue(_ now: Date) -> Double {
        let t = now.timeIntervalSince(blinkAt)
        func one(_ t: Double) -> Double { t < 0 ? 0 : t < 0.07 ? t / 0.07 : t < 0.2 ? 1 - (t - 0.07) / 0.13 : 0 }
        return max(one(t), doubleBlink ? one(t - 0.36) : 0)
    }
    private func glanceValue(_ now: Date) -> CGPoint {
        let t = now.timeIntervalSince(glanceAt)
        let k: Double = t < 0.38 ? Self.ease(t / 0.38) : t < 1.5 ? 1 : 1 - Self.ease((t - 1.5) / 0.52)
        return CGPoint(x: glanceTo.x * k, y: glanceTo.y * k)
    }
    private func lookValue(_ now: Date) -> CGPoint {
        let k = Self.ease(now.timeIntervalSince(lookAt) / 0.42)
        return CGPoint(x: lookFrom.x + (look.x - lookFrom.x) * k, y: lookFrom.y + (look.y - lookFrom.y) * k)
    }

    // MARK: drawing
    //
    // The two are content, not controls, so they are not made of the system's Liquid Glass material (which HIG keeps
    // for the navigation layer). Instead they are drawn as small polished glass objects in the same spirit: light passes
    // through the body and gathers low inside it, the colour deepens toward the thick edges, a crisp specular highlight
    // follows the upper-left curve, a thin rim catches the light, and the shadow on the ground carries the body's tint.

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ now: Date) {
        let s = min(size.width, size.height) / 100
        let t = now.timeIntervalSinceReferenceDate
        let period = mood == .sleep ? 4.2 : 3.2
        let b = still ? 0 : (1 - cos(t / period * 2 * .pi)) / 2
        let amp = mood == .sleep ? 0.022 : 0.012
        let hop = still ? 0 : max(0, Self.bounce(now.timeIntervalSince(hopAt))) * hopSize
        let leaf = still ? 0 : 14 * Self.bounce(now.timeIntervalSince(leafAt) * 0.6)
        let leanNow = leanFrom + (lean - leanFrom) * Self.ease(now.timeIntervalSince(leanAt) / 0.5)

        ctx.translateBy(x: (size.width - 100 * s) / 2, y: (size.height - 100 * s) / 2)
        ctx.scaleBy(x: s, y: s)
        // the shadow stays on the ground and tightens while the body is in the air
        groundShadow(&ctx, (kind == .moss ? 33 : 25) * (1 - hop * 0.12), kind == .moss ? Tone.moss.base : Tone.otto.base)
        ctx.translateBy(x: 0, y: -hop * 7)
        // squash and stretch from the feet
        ctx.translateBy(x: 50, y: 88); ctx.scaleBy(x: 1 - b * amp * 0.5, y: 1 + b * amp); ctx.rotate(by: .degrees(leanNow)); ctx.translateBy(x: -50, y: -88)

        let rest = lid ?? (kind == .otto ? 0.2 : 0)
        let l = max(rest, still ? 0 : blinkValue(now))
        let e0 = lookValue(still ? .distantFuture : now), g = still ? .zero : glanceValue(now)
        let e = CGPoint(x: e0.x + g.x, y: e0.y + g.y)
        if kind == .moss { drawMoss(&ctx, e, l, sway: (b - 0.5) * 6 + leaf) } else { drawOtto(&ctx, e, l, swing: (b - 0.5) * 5 + leaf) }

        // 小薄荷: a few mint leaves drifting up
        let f = now.timeIntervalSince(fleckAt) / 1.6
        if f > 0 && f < 1 {
            let a = f < 0.2 ? f / 0.2 : 1 - (f - 0.2) / 0.8
            for (x, dx, d) in [(36.0, -8.0, 0.0), (58, 6, 0.12), (47, -2, 0.24)] {
                let gg = max(0, min(1, (f - d) / (1 - d)))
                var c = ctx
                c.opacity = a
                c.translateBy(x: x + dx * gg, y: 14 - gg * 26)
                c.rotate(by: .degrees(gg * 120 + dx * 4 - 20))
                leafGlass(&c, .zero, 0, 7, 2.4, Tone.mint)
            }
        }
    }

    /// The three tones of a coloured glass: where light comes through, the body colour, and the thick edge.
    struct Tone {
        let light: Color, base: Color, deep: Color
        static let moss = Tone(light: Color(hex: 0xB4D98E), base: Color(hex: 0x5E8E4C), deep: Color(hex: 0x2A4727))
        static let otto = Tone(light: Color(hex: 0x8DB2F5), base: Color(hex: 0x3361BC), deep: Color(hex: 0x162C63))
        static let mint = Tone(light: Color(hex: 0xC4F2D6), base: Color(hex: 0x4DB883), deep: Color(hex: 0x23704C))
        static let gold = Tone(light: Color(hex: 0xFFEBB0), base: Color(hex: 0xE2AF2E), deep: Color(hex: 0x8A6206))
    }

    /// A soft spot of light or shade: an ellipse whose colour fades out toward its edge.
    private func glow(_ ctx: inout GraphicsContext, _ r: CGRect, _ color: Color, hold: Double = 0.15) {
        guard r.width > 0, r.height > 0 else { return }
        var c = ctx
        c.translateBy(x: r.midX, y: r.midY); c.scaleBy(x: 1, y: r.height / r.width)
        let rad = r.width / 2
        c.fill(Path(ellipseIn: CGRect(x: -rad, y: -rad, width: rad * 2, height: rad * 2)),
               with: .radialGradient(Gradient(stops: [.init(color: color, location: 0), .init(color: color, location: hold), .init(color: color.opacity(0), location: 1)]),
                                     center: .zero, startRadius: 0, endRadius: rad))
    }

    /// The tinted shadow of light passing through the body, and a firmer contact shadow under it.
    private func groundShadow(_ ctx: inout GraphicsContext, _ rx: CGFloat, _ tint: Color) {
        let dark = scheme == .dark
        glow(&ctx, CGRect(x: 50 - rx * 1.12, y: 83.5, width: rx * 2.24, height: 11), tint.opacity(dark ? 0.42 : 0.3), hold: 0.25)
        glow(&ctx, CGRect(x: 50 - rx * 0.86, y: 86.2, width: rx * 1.72, height: 5), Color.black.opacity(dark ? 0.5 : 0.2), hold: 0.3)
    }

    /// The body's colour: lit through from the upper left, gathering low inside, deepening toward the thick edges.
    private static func shade(_ p: Path, _ tone: Tone) -> GraphicsContext.Shading {
        let r = p.boundingRect
        return .radialGradient(Gradient(stops: [.init(color: tone.light, location: 0), .init(color: tone.base, location: 0.52), .init(color: tone.deep, location: 1)]),
                               center: CGPoint(x: r.minX + r.width * 0.56, y: r.minY + r.height * 0.64), startRadius: 0, endRadius: max(r.width, r.height) * 0.68)
    }

    /// A glass body.
    private func glass(_ ctx: inout GraphicsContext, _ p: Path, _ tone: Tone) {
        let r = p.boundingRect
        ctx.fill(p, with: Self.shade(p, tone))
        var c = ctx
        c.clip(to: p)
        // the thick edge absorbs more light
        c.stroke(p, with: .color(tone.deep.opacity(0.32)), lineWidth: 6)
        c.stroke(p, with: .color(tone.deep.opacity(0.28)), lineWidth: 2.2)
        // light focused through the body onto its lower inside
        glow(&c, CGRect(x: r.minX + r.width * 0.2, y: r.maxY - r.height * 0.3, width: r.width * 0.62, height: r.height * 0.24), tone.light.mix(with: .white, by: 0.45).opacity(0.62))
        // a broad sheen on the upper half
        glow(&c, CGRect(x: r.minX + r.width * 0.06, y: r.minY - r.height * 0.02, width: r.width * 0.66, height: r.height * 0.4), .white.opacity(0.3), hold: 0.05)
        // the crisp highlight along the upper-left curve, and a small one after it
        var hc = c
        hc.translateBy(x: r.midX, y: r.midY + r.height * 0.04); hc.scaleBy(x: 1, y: r.height / r.width)
        let rad = r.width * 0.39
        var arc = Path(); arc.addArc(center: .zero, radius: rad, startAngle: .degrees(196), endAngle: .degrees(236), clockwise: false)
        hc.stroke(arc, with: .color(.white.opacity(0.88)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        let dot = CGPoint(x: rad * cos(250 * .pi / 180), y: rad * sin(250 * .pi / 180))
        hc.fill(Path(ellipseIn: CGRect(x: dot.x - 1.2, y: dot.y - 1.2, width: 2.4, height: 2.4)), with: .color(.white.opacity(0.8)))
        // a rim of light: bright at the top left, faint at the side, picked up again at the lower right
        c.stroke(p, with: .linearGradient(Gradient(stops: [.init(color: .white.opacity(0.75), location: 0), .init(color: .white.opacity(0.05), location: 0.5), .init(color: .white.opacity(0.4), location: 1)]),
                                          startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.maxX, y: r.maxY)), lineWidth: 1.3)
    }

    /// A glass mint leaf.
    private func leafGlass(_ ctx: inout GraphicsContext, _ at: CGPoint, _ angle: Double, _ l: CGFloat, _ w: CGFloat, _ tone: Tone) {
        var c = ctx
        c.translateBy(x: at.x, y: at.y); c.rotate(by: .degrees(angle))
        let p = Shapes.leaf(l, w)
        c.fill(p, with: .linearGradient(Gradient(colors: [tone.light, tone.base, tone.deep]), startPoint: CGPoint(x: l * 0.3, y: -w), endPoint: CGPoint(x: l * 0.6, y: w)))
        var m = Path(); m.move(to: CGPoint(x: l * 0.06, y: 0)); m.addQuadCurve(to: CGPoint(x: l * 0.86, y: -w * 0.08), control: CGPoint(x: l * 0.5, y: w * 0.12))
        c.stroke(m, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: max(0.4, w * 0.11), lineCap: .round))
        var k = c
        k.clip(to: p)
        glow(&k, CGRect(x: l * 0.18, y: -w * 1.0, width: l * 0.55, height: w * 0.9), .white.opacity(0.45), hold: 0.1)
        k.stroke(p, with: .color(.white.opacity(0.4)), lineWidth: 0.8)
    }

    /// A golden bead: a polished sphere.
    private func goldBead(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: CGFloat) {
        let g = Tone.gold
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.7, width: r * 2, height: r * 2)), with: .color(g.deep.opacity(0.3)))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                 with: .radialGradient(Gradient(stops: [.init(color: g.light, location: 0), .init(color: g.base, location: 0.5), .init(color: g.deep, location: 1)]),
                                       center: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.4), startRadius: 0, endRadius: r * 1.45))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.62, y: c.y - r * 0.68, width: r * 0.5, height: r * 0.4)), with: .color(.white.opacity(0.9)))
    }

    /// A glass eye: a white dome set into the body.
    private func eye(_ ctx: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ look: CGPoint, _ lid: Double, _ tone: Tone, _ bodyPath: Path) {
        if mood == .sleep {
            let w = min(rx, 8)
            var p = Path(); p.move(to: CGPoint(x: cx - w, y: cy)); p.addQuadCurve(to: CGPoint(x: cx + w, y: cy), control: CGPoint(x: cx, y: cy + w * 0.8))
            ctx.stroke(p, with: .color(Palette.ink), style: StrokeStyle(lineWidth: max(1.6, ry * 0.3), lineCap: .round)); return
        }
        let r = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
        // where the eye sits into the body
        ctx.fill(Path(ellipseIn: r.insetBy(dx: -1.2, dy: -1.2).offsetBy(dx: 0, dy: -0.3)), with: .color(tone.deep.opacity(0.4)))
        var c = ctx
        c.clip(to: Path(ellipseIn: r))
        c.fill(Path(r), with: .radialGradient(Gradient(colors: [.white, Palette.paper, Color(hex: 0xD5D7CF)]),
                                              center: CGPoint(x: cx - rx * 0.2, y: cy - ry * 0.25), startRadius: 0, endRadius: max(rx, ry) * 1.25))
        let pr = min(rx, ry) * (mood == .wow ? 0.48 : 0.6)
        let px = cx + max(-1, min(1, look.x)) * (rx - pr - 0.4), py = cy + max(-1, min(1, look.y)) * (ry - pr - 0.4)
        c.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
               with: .radialGradient(Gradient(colors: [Color(hex: 0x3B3F38), Palette.ink]), center: CGPoint(x: px - pr * 0.3, y: py - pr * 0.3), startRadius: 0, endRadius: pr))
        c.fill(Path(ellipseIn: CGRect(x: px - pr * 0.62, y: py - pr * 0.7, width: pr * 0.56, height: pr * 0.56)), with: .color(.white.opacity(0.92)))
        c.fill(Path(ellipseIn: CGRect(x: px + pr * 0.25, y: py + pr * 0.25, width: pr * 0.26, height: pr * 0.26)), with: .color(.white.opacity(0.6)))
        // the dome's own reflection
        glow(&c, CGRect(x: cx - rx * 0.75, y: cy - ry * 1.05, width: rx * 1.3, height: ry * 0.75), .white.opacity(0.55), hold: 0.1)
        let skin = Self.shade(bodyPath, tone)
        if mood == .happy {
            let cheek = Path(ellipseIn: CGRect(x: cx - rx * 1.3, y: cy + ry * 0.12, width: rx * 2.6, height: ry * 2))
            c.fill(cheek, with: skin)
            c.stroke(cheek, with: .color(tone.deep.opacity(0.5)), lineWidth: 0.9)
        }
        if lid > 0 {
            let h = (ry * 2 + 1.2) * lid
            c.fill(Path(CGRect(x: cx - rx - 0.6, y: cy - ry - 0.6, width: rx * 2 + 1.2, height: h)), with: skin)
            if lid > 0.04 && lid < 0.96 {
                var e = Path(); e.move(to: CGPoint(x: cx - rx, y: cy - ry - 0.6 + h)); e.addLine(to: CGPoint(x: cx + rx, y: cy - ry - 0.6 + h))
                c.stroke(e, with: .color(tone.deep.opacity(0.55)), lineWidth: 0.9)
            }
        }
    }

    private func mouth(_ ctx: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat) {
        ctx.fill(Path(ellipseIn: CGRect(x: cx - 2.1, y: cy - 2.7, width: 4.2, height: 5.4)), with: .color(Palette.ink))
    }

    private func drawMoss(_ ctx: inout GraphicsContext, _ look: CGPoint, _ lid: Double, sway: Double) {
        ctx.stroke(Shapes.mossStem, with: .color(Tone.mint.deep), style: StrokeStyle(lineWidth: 2.1, lineCap: .round))
        var leaves = ctx
        leaves.translateBy(x: 50.4, y: 25.5); leaves.rotate(by: .degrees(sway)); leaves.translateBy(x: -50.4, y: -25.5)
        let tip = CGPoint(x: 50.4, y: 25)
        leafGlass(&leaves, tip, -96, 11, 3.8, Tone.mint)
        leafGlass(&leaves, tip, -154, 16, 5.6, Tone.mint)
        leafGlass(&leaves, tip, -24, 18, 6.2, Tone.mint)
        glass(&ctx, Shapes.mossBody, Tone.moss)
        // a few bubbles caught in the glass
        for (x, y, r) in [(29.0, 62.0, 1.5), (74, 57, 1.0), (68, 79, 1.3), (33, 77, 0.8)] {
            let b = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: b), with: .color(.white.opacity(0.16)))
            ctx.stroke(Path(ellipseIn: b), with: .color(.white.opacity(0.4)), lineWidth: 0.4)
        }
        eye(&ctx, 41.5, 59, 6.4, 7.4, look, lid, Tone.moss, Shapes.mossBody)
        eye(&ctx, 58.5, 59, 6.4, 7.4, look, lid, Tone.moss, Shapes.mossBody)
        if mood == .wow { mouth(&ctx, 50, 73) }
    }

    private func drawOtto(_ ctx: inout GraphicsContext, _ look: CGPoint, _ lid: Double, swing: Double) {
        var rod = ctx
        rod.translateBy(x: 51.5, y: 14); rod.rotate(by: .degrees(swing)); rod.translateBy(x: -51.5, y: -14)
        rod.stroke(Shapes.ottoStem, with: .color(Tone.otto.deep), style: StrokeStyle(lineWidth: 2.1, lineCap: .round))
        goldBead(&rod, CGPoint(x: 61.5, y: 4.4), 3.4)
        glass(&ctx, Shapes.ottoBody, Tone.otto)
        eye(&ctx, 51, 41, 13, 12, look, mood == .wow ? 0 : lid, Tone.otto, Shapes.ottoBody)
        if mood == .wow { mouth(&ctx, 51, 58.5) }
        // the string of golden beads
        let pts = Shapes.beadStrand
        var thread = Path(); thread.addLines(pts)
        ctx.stroke(thread, with: .color(Tone.gold.deep.opacity(0.7)), lineWidth: 0.8)
        for p in pts { goldBead(&ctx, p, 3.3) }
    }
}

/// Moss and Otto together: the chosen one in front, the other a step behind and smaller. Every few seconds the one
/// behind leans in, the one in front turns to it, and both brighten.
struct Duo: View {
    let primary: Kind
    var size: CGFloat = 112
    var mood: Mood = .open
    var look: CGPoint = CGPoint(x: -0.6, y: 0.2)
    var lid: Double? = nil
    var poke = true
    var together = true
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var beat = 0

    var body: some View {
        let small = size * 0.72
        let asleep = mood == .sleep
        ZStack(alignment: .bottomLeading) {
            Creature(kind: primary.other, mood: asleep ? .sleep : beat == 2 ? .happy : .open,
                     look: beat >= 1 ? CGPoint(x: -0.9, y: 0.5) : CGPoint(x: -0.7, y: 0.1), lean: beat == 1 ? -9 : 0, alive: !reduce, poke: poke)
                .frame(width: small, height: small)
                .offset(x: size - small * 0.38, y: -2)
            Creature(kind: primary, mood: beat == 2 && mood == .open ? .happy : mood,
                     look: beat >= 1 ? CGPoint(x: 0.95, y: -0.35) : look, lid: beat >= 1 ? nil : lid, poke: poke,
                     label: primary == .moss ? "Moss 和 Otto" : "Otto 和 Moss")
                .frame(width: size, height: size)
        }
        .frame(width: size + small * 0.62, height: size, alignment: .bottomLeading)
        .task(id: "\(reduce)\(asleep)\(together)") {
            beat = 0
            guard !reduce, !asleep, together else { return }
            try? await Task.sleep(for: .milliseconds(1800 + Int.random(in: 0...1600)))
            while !Task.isCancelled {
                beat = 1; try? await Task.sleep(for: .milliseconds(900))
                beat = 2; try? await Task.sleep(for: .milliseconds(1500))
                beat = 0; try? await Task.sleep(for: .milliseconds(6500 + Int.random(in: 0...5000)))
            }
        }
    }
}

/// The end of the journey is not the end: the string of beads runs on past the last one, and the two walk on along it.
struct StoryGoesOn: View {
    let primary: Kind
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .bottomLeading) {
                Canvas { ctx, size in
                    let y = size.height - 8, n = 16
                    var s = Path(); s.move(to: CGPoint(x: 0, y: y)); s.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(s, with: .linearGradient(Gradient(colors: [Palette.bead.opacity(0.6), Palette.bead.opacity(0)]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)), lineWidth: 1.5)
                    for i in 0..<n {
                        let x = size.width * (0.06 + 0.94 * Double(i) / Double(n - 1))
                        let a = max(0.08, 1 - Double(i) / Double(n))
                        let r: CGFloat = i % 4 == 3 ? 5.5 : 4
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Crayon.rainbow[i % Crayon.rainbow.count].opacity(a)))
                    }
                }
                Duo(primary: primary, size: 64, look: CGPoint(x: 0.9, y: -0.1)).padding(.leading, 18).padding(.bottom, 12)
            }
            .frame(height: 96)
            Text("故事仍在继续").font(.title2.weight(.bold)).padding(.top, 10)
            Text("36 个月以后，路还很长，每一天都有新的样子。").font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
