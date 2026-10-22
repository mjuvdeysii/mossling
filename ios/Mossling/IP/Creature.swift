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
    // Painted wooden toys: a matte coat of paint lit from the upper left, a soft sheen of varnish, the bare wooden foot
    // below the paint line, painted eyes and rosy cheeks, a warm shadow on the floor.

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
        // the shadow stays on the floor and tightens while the toy is in the air
        let rx: CGFloat = (kind == .moss ? 32 : 21) * (1 - hop * 0.12)
        glow(&ctx, CGRect(x: 50 - rx, y: 84.5, width: rx * 2, height: 8), Color(hex: 0x6B4A2B).opacity(scheme == .dark ? 0.5 : 0.22), hold: 0.3)
        ctx.translateBy(x: 0, y: -hop * 7)
        // squash and stretch from the foot
        ctx.translateBy(x: 50, y: 88); ctx.scaleBy(x: 1 - b * amp * 0.5, y: 1 + b * amp); ctx.rotate(by: .degrees(leanNow)); ctx.translateBy(x: -50, y: -88)

        let rest = lid ?? (kind == .otto ? 0.15 : 0)
        let l = max(rest, still ? 0 : blinkValue(now))
        let e0 = lookValue(still ? .distantFuture : now), g = still ? .zero : glanceValue(now)
        let e = CGPoint(x: max(-1, min(1, e0.x + g.x)), y: max(-1, min(1, e0.y + g.y)))
        if kind == .moss { drawMoss(&ctx, e, l, sway: (b - 0.5) * 6 + leaf) } else { drawOtto(&ctx, e, l, bob: (b - 0.5) * 0.8 + leaf * 0.12) }

        // 小薄荷: a few mint leaves drifting up
        let f = now.timeIntervalSince(fleckAt) / 1.6
        if f > 0 && f < 1 {
            let a = f < 0.2 ? f / 0.2 : 1 - (f - 0.2) / 0.8
            for (x, dx, d) in [(36.0, -8.0, 0.0), (58, 6, 0.12), (47, -2, 0.24)] {
                let gg = max(0, min(1, (f - d) / (1 - d)))
                var c = ctx
                c.opacity = a
                c.translateBy(x: x + dx * gg, y: 16 - gg * 26)
                c.rotate(by: .degrees(gg * 120 + dx * 4 - 20))
                c.fill(Shapes.leaf(7, 2.4), with: .color(Paint.mint))
            }
        }
    }

    /// The paints.
    enum Paint {
        static let moss = Color(hex: 0x6FAE52), mossLight = Color(hex: 0xA3D47F), mossDeep = Color(hex: 0x3F7A34)
        static let rod = Color(hex: 0x4479D2), rodLight = Color(hex: 0x86AEEF), rodDeep = Color(hex: 0x2A54A3)
        static let wood = Color(hex: 0xEDCFA3), woodDeep = Color(hex: 0xC99A66)
        static let mint = Color(hex: 0x4FC08D), mintLight = Color(hex: 0x9BE3BE)
        static let gold = Color(hex: 0xF0B83A), goldLight = Color(hex: 0xFFE9A6), goldDeep = Color(hex: 0xA8710D)
        static let ink = Color(hex: 0x2B2420), cheek = Color(hex: 0xFF8E8E)
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

    /// A painted wooden body: the paint above the foot line, bare wood below it, matte light from the upper left and a
    /// soft sheen of varnish.
    private func painted(_ ctx: inout GraphicsContext, _ p: Path, light: Color, base: Color, deep: Color, foot: CGFloat) {
        let r = p.boundingRect
        var c = ctx
        c.clip(to: p)
        c.fill(Path(r), with: .linearGradient(Gradient(colors: [light, base, deep]), startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.maxX, y: r.maxY)))
        // the wooden foot, with a little grain and the line where the paint stops
        let w = CGRect(x: r.minX - 1, y: foot, width: r.width + 2, height: r.maxY - foot + 1)
        c.fill(Path(w), with: .linearGradient(Gradient(colors: [Paint.wood, Paint.woodDeep]), startPoint: CGPoint(x: r.minX, y: foot), endPoint: CGPoint(x: r.maxX, y: r.maxY)))
        for k in 0..<3 {
            var g = Path(); let y = foot + 2.2 + CGFloat(k) * 2.2
            g.move(to: CGPoint(x: r.minX + 6 + CGFloat(k) * 5, y: y)); g.addQuadCurve(to: CGPoint(x: r.maxX - 8, y: y + 0.6), control: CGPoint(x: r.midX, y: y - 1.2))
            c.stroke(g, with: .color(Paint.woodDeep.opacity(0.45)), lineWidth: 0.5)
        }
        c.fill(Path(CGRect(x: r.minX - 1, y: foot - 0.6, width: r.width + 2, height: 1.2)), with: .color(deep.opacity(0.35)))
        // varnish: a broad soft sheen and a small bright spot
        glow(&c, CGRect(x: r.minX + r.width * 0.1, y: r.minY + r.height * 0.04, width: r.width * 0.5, height: r.height * 0.32), .white.opacity(0.35), hold: 0.1)
        glow(&c, CGRect(x: r.minX + r.width * 0.2, y: r.minY + r.height * 0.1, width: r.width * 0.14, height: r.height * 0.07), .white.opacity(0.75), hold: 0.3)
        // a soft edge, so the toy reads as round
        c.stroke(p, with: .color(deep.opacity(0.35)), lineWidth: 3)
    }

    /// A polished golden bead.
    private func goldBead(_ ctx: inout GraphicsContext, _ c: CGPoint, _ r: CGFloat) {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r * 0.6, width: r * 2, height: r * 2)), with: .color(Paint.goldDeep.opacity(0.3)))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                 with: .radialGradient(Gradient(stops: [.init(color: Paint.goldLight, location: 0), .init(color: Paint.gold, location: 0.5), .init(color: Paint.goldDeep, location: 1)]),
                                       center: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.4), startRadius: 0, endRadius: r * 1.4))
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.6, y: c.y - r * 0.66, width: r * 0.48, height: r * 0.36)), with: .color(.white.opacity(0.85)))
    }

    /// A painted eye: a dark oval with a glint; closed it is a curve, happy it is an arch.
    private func paintedEye(_ ctx: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ look: CGPoint, _ lid: Double) {
        let w = rx * 1.05
        if mood == .sleep || lid > 0.92 {
            var p = Path(); p.move(to: CGPoint(x: cx - w, y: cy)); p.addQuadCurve(to: CGPoint(x: cx + w, y: cy), control: CGPoint(x: cx, y: cy + ry * 0.75))
            ctx.stroke(p, with: .color(Paint.ink), style: StrokeStyle(lineWidth: max(1.4, rx * 0.36), lineCap: .round)); return
        }
        if mood == .happy {
            var p = Path(); p.move(to: CGPoint(x: cx - w, y: cy + ry * 0.2)); p.addQuadCurve(to: CGPoint(x: cx + w, y: cy + ry * 0.2), control: CGPoint(x: cx, y: cy - ry * 0.9))
            ctx.stroke(p, with: .color(Paint.ink), style: StrokeStyle(lineWidth: max(1.4, rx * 0.36), lineCap: .round)); return
        }
        let k = mood == .wow ? 1.18 : 1.0
        let h = ry * 2 * k * (1 - lid)
        let x = cx + look.x * rx * 0.45, y = cy + look.y * ry * 0.3 + ry * k * lid
        let r = CGRect(x: x - rx * k, y: y - h / 2, width: rx * 2 * k, height: max(0.8, h))
        ctx.fill(Path(ellipseIn: r), with: .color(Paint.ink))
        if lid < 0.5 {
            ctx.fill(Path(ellipseIn: CGRect(x: x - rx * 0.55 * k, y: y - h * 0.36, width: rx * 0.62 * k, height: rx * 0.62 * k)), with: .color(.white.opacity(0.95)))
            ctx.fill(Path(ellipseIn: CGRect(x: x + rx * 0.2 * k, y: y + h * 0.12, width: rx * 0.28 * k, height: rx * 0.28 * k)), with: .color(.white.opacity(0.6)))
        }
    }

    private func smile(_ ctx: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat) {
        if mood == .wow {
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 2.2, y: cy - 2.2, width: 4.4, height: 5)), with: .color(Paint.ink)); return
        }
        var p = Path(); p.move(to: CGPoint(x: cx - w, y: cy)); p.addQuadCurve(to: CGPoint(x: cx + w, y: cy), control: CGPoint(x: cx, y: cy + w * (mood == .happy ? 1.1 : 0.7)))
        ctx.stroke(p, with: .color(Paint.ink), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
    }

    private func cheeks(_ ctx: inout GraphicsContext, _ a: CGPoint, _ b: CGPoint, _ r: CGFloat) {
        for c in [a, b] { glow(&ctx, CGRect(x: c.x - r, y: c.y - r * 0.6, width: r * 2, height: r * 1.2), Paint.cheek.opacity(mood == .happy ? 0.7 : 0.5), hold: 0.35) }
    }

    private func drawMoss(_ ctx: inout GraphicsContext, _ look: CGPoint, _ lid: Double, sway: Double) {
        // the mint sprout
        ctx.stroke(Shapes.mossStem, with: .color(Color(hex: 0x3F9A6E)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        var sprout = ctx
        sprout.translateBy(x: 50.6, y: 21); sprout.rotate(by: .degrees(sway)); sprout.translateBy(x: -50.6, y: -21)
        for (ang, len, wid) in [(-150.0, 14.0, 5.0), (-30.0, 15.5, 5.4)] {
            var c = sprout
            c.translateBy(x: 50.6, y: 21); c.rotate(by: .degrees(ang))
            let p = Shapes.leaf(len, wid)
            c.fill(p, with: .linearGradient(Gradient(colors: [Paint.mintLight, Paint.mint]), startPoint: CGPoint(x: 0, y: -wid), endPoint: CGPoint(x: 0, y: wid)))
            var v = Path(); v.move(to: CGPoint(x: 1.5, y: 0)); v.addLine(to: CGPoint(x: len * 0.8, y: 0))
            c.stroke(v, with: .color(.white.opacity(0.55)), lineWidth: 0.7)
        }
        painted(&ctx, Shapes.mossBody, light: Paint.mossLight, base: Paint.moss, deep: Paint.mossDeep, foot: 80)
        cheeks(&ctx, CGPoint(x: 30, y: 66), CGPoint(x: 70, y: 66), 6)
        paintedEye(&ctx, 40, 57, 4.2, 5.4, look, lid)
        paintedEye(&ctx, 60, 57, 4.2, 5.4, look, lid)
        smile(&ctx, 50, 67, 3.2)
    }

    private func drawOtto(_ ctx: inout GraphicsContext, _ look: CGPoint, _ lid: Double, bob: Double) {
        goldBead(&ctx, CGPoint(x: 50, y: 10.5 - bob), 5.4)
        painted(&ctx, Shapes.ottoBody, light: Paint.rodLight, base: Paint.rod, deep: Paint.rodDeep, foot: 81)
        // the big eye: a white painted disc with a dark pupil that follows
        let cx: CGFloat = 50, cy: CGFloat = 39, R: CGFloat = 11
        ctx.fill(Path(ellipseIn: CGRect(x: cx - R - 1.2, y: cy - R - 0.6, width: (R + 1.2) * 2, height: (R + 1.2) * 2)), with: .color(Paint.rodDeep.opacity(0.45)))
        if mood == .sleep || mood == .happy || lid > 0.92 {
            ctx.fill(Path(ellipseIn: CGRect(x: cx - R, y: cy - R, width: R * 2, height: R * 2)), with: .color(Paint.rodLight.opacity(0.35)))
            paintedEye(&ctx, cx, cy + 1, 7, 6, look, lid)
        } else {
            var c = ctx
            c.clip(to: Path(ellipseIn: CGRect(x: cx - R, y: cy - R, width: R * 2, height: R * 2)))
            c.fill(Path(CGRect(x: cx - R, y: cy - R, width: R * 2, height: R * 2)), with: .radialGradient(Gradient(colors: [.white, Color(hex: 0xF4EEE4)]), center: CGPoint(x: cx - 3, y: cy - 4), startRadius: 0, endRadius: R * 1.3))
            let pr: CGFloat = mood == .wow ? 4.6 : 5.6
            let px = cx + look.x * (R - pr - 1), py = cy + look.y * (R - pr - 1)
            c.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)), with: .color(Paint.ink))
            c.fill(Path(ellipseIn: CGRect(x: px - pr * 0.6, y: py - pr * 0.68, width: pr * 0.6, height: pr * 0.6)), with: .color(.white.opacity(0.95)))
            if lid > 0 {
                c.fill(Path(CGRect(x: cx - R - 1, y: cy - R - 1, width: R * 2 + 2, height: (R * 2 + 2) * lid)), with: .linearGradient(Gradient(colors: [Paint.rodLight, Paint.rod]), startPoint: CGPoint(x: cx, y: cy - R), endPoint: CGPoint(x: cx, y: cy + R)))
                var e = Path(); e.move(to: CGPoint(x: cx - R, y: cy - R - 1 + (R * 2 + 2) * lid)); e.addLine(to: CGPoint(x: cx + R, y: cy - R - 1 + (R * 2 + 2) * lid))
                c.stroke(e, with: .color(Paint.rodDeep), lineWidth: 1)
            }
        }
        cheeks(&ctx, CGPoint(x: 36, y: 53), CGPoint(x: 64, y: 53), 4.6)
        smile(&ctx, 50, 55, 2.6)
        // the string of golden beads
        let pts = Shapes.beadStrand
        var thread = Path(); thread.addLines(pts)
        ctx.stroke(thread, with: .color(Paint.goldDeep.opacity(0.7)), lineWidth: 0.8)
        for p in pts { goldBead(&ctx, p, 3.6) }
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
