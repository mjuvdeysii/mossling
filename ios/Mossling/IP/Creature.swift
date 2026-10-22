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

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ now: Date) {
        let s = min(size.width, size.height) / 100
        let t = now.timeIntervalSinceReferenceDate
        let period = mood == .sleep ? 4.2 : 3.2
        let b = still ? 0 : (1 - cos(t / period * 2 * .pi)) / 2
        let amp = mood == .sleep ? 0.022 : 0.012
        let hop = still ? 0 : max(0, Self.bounce(now.timeIntervalSince(hopAt))) * hopSize
        let leaf = still ? 0 : 14 * Self.bounce(now.timeIntervalSince(leafAt) * 0.6)
        let leanNow = leanFrom + (lean - leanFrom) * Self.ease(now.timeIntervalSince(leanAt) / 0.5)

        ctx.translateBy(x: (size.width - 100 * s) / 2, y: (size.height - 100 * s) / 2 - hop * 7 * s)
        ctx.scaleBy(x: s, y: s)
        // squash and stretch from the feet
        ctx.translateBy(x: 50, y: 88); ctx.scaleBy(x: 1 - b * amp * 0.5, y: 1 + b * amp); ctx.rotate(by: .degrees(leanNow)); ctx.translateBy(x: -50, y: -88)

        let rest = lid ?? (kind == .otto ? 0.34 : 0)
        let l = max(rest, still ? 0 : blinkValue(now))
        let e0 = lookValue(still ? .distantFuture : now), g = still ? .zero : glanceValue(now)
        let e = CGPoint(x: e0.x + g.x, y: e0.y + g.y)
        if kind == .moss { drawMoss(&ctx, e, l, sway: (b - 0.5) * 6 + leaf) } else { drawOtto(&ctx, e, l, swing: (b - 0.5) * 5 + leaf) }

        // the mint leaves drifting up
        let f = now.timeIntervalSince(fleckAt) / 1.6
        if f > 0 && f < 1 {
            let a = f < 0.2 ? f / 0.2 : 1 - (f - 0.2) / 0.8
            for (x, dx, d) in [(36.0, -8.0, 0.0), (58, 6, 0.12), (47, -2, 0.24)] {
                let gg = max(0, min(1, (f - d) / (1 - d)))
                var c = ctx
                c.translateBy(x: x + dx * gg, y: 14 - gg * 26)
                c.translateBy(x: 3, y: 2); c.rotate(by: .degrees(gg * 120 + dx * 4)); c.translateBy(x: -3, y: -2)
                c.fill(Shapes.mintFleck, with: .color(Palette.mint.opacity(a)))
            }
        }
    }

    private func shadow(_ ctx: inout GraphicsContext, _ rx: CGFloat) {
        ctx.fill(Path(ellipseIn: CGRect(x: 50 - rx, y: 87.5, width: rx * 2, height: 6)), with: .color(Palette.ink.opacity(0.09)))
    }
    private func leg(_ ctx: inout GraphicsContext, _ x: CGFloat) {
        ctx.fill(Path(roundedRect: CGRect(x: x, y: 80, width: 6.5, height: 10), cornerRadius: 3.2), with: .color(Palette.ink))
    }
    private func body(_ ctx: inout GraphicsContext, _ p: Path, _ fill: Color, _ deep: Color) {
        // a glassy body: the colour lit from above, a soft highlight along the top edge, a rim of light, depth below
        let r = p.boundingRect
        ctx.fill(p.offsetBy(dx: 0, dy: 1.6), with: .color(deep.opacity(0.55)))
        ctx.fill(p, with: .linearGradient(Gradient(colors: [fill.mix(with: .white, by: 0.18), fill, fill.mix(with: deep, by: 0.45)]),
                                          startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.minX + r.width * 0.25, y: r.maxY)))
        var c = ctx
        c.clip(to: p)
        c.fill(Path(ellipseIn: CGRect(x: r.minX + r.width * 0.12, y: r.minY + r.height * 0.04, width: r.width * 0.62, height: r.height * 0.32)),
               with: .linearGradient(Gradient(colors: [.white.opacity(0.42), .white.opacity(0)]), startPoint: CGPoint(x: r.midX, y: r.minY), endPoint: CGPoint(x: r.midX, y: r.minY + r.height * 0.36)))
        c.stroke(p, with: .linearGradient(Gradient(colors: [.white.opacity(0.55), .white.opacity(0.05), .white.opacity(0.25)]),
                                          startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.maxX, y: r.maxY)), lineWidth: 1.6)
    }
    private func eye(_ ctx: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ look: CGPoint, _ lid: Double, _ skin: Color) {
        if mood == .sleep {
            var p = Path(); p.move(to: CGPoint(x: cx - rx, y: cy)); p.addQuadCurve(to: CGPoint(x: cx + rx, y: cy), control: CGPoint(x: cx, y: cy + ry * 0.9))
            ctx.stroke(p, with: .color(Palette.ink), style: StrokeStyle(lineWidth: max(1.6, ry * 0.32), lineCap: .round)); return
        }
        let r = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
        var c = ctx
        c.clip(to: Path(ellipseIn: r))
        c.fill(Path(r), with: .color(Palette.paper))
        let pr = min(rx, ry) * (mood == .wow ? 0.5 : 0.62)
        let px = cx + max(-1, min(1, look.x)) * (rx - pr - 0.3), py = cy + max(-1, min(1, look.y)) * (ry - pr - 0.3)
        c.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)), with: .color(Palette.ink))
        // a glint on the eye
        c.fill(Path(ellipseIn: CGRect(x: px - pr * 0.55, y: py - pr * 0.65, width: pr * 0.5, height: pr * 0.5)), with: .color(.white.opacity(0.85)))
        if mood == .happy { c.fill(Path(ellipseIn: CGRect(x: cx - rx * 1.3, y: cy + ry * 0.12, width: rx * 2.6, height: ry * 2)), with: .color(skin)) }
        if lid > 0 { c.fill(Path(CGRect(x: cx - rx - 0.6, y: cy - ry - 0.6, width: rx * 2 + 1.2, height: (ry * 2 + 1.2) * lid)), with: .color(skin)) }
    }

    private func drawMoss(_ ctx: inout GraphicsContext, _ look: CGPoint, _ lid: Double, sway: Double) {
        shadow(&ctx, 31)
        ctx.stroke(Shapes.mossStem, with: .color(Palette.mossDeep), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        var leaves = ctx
        leaves.translateBy(x: 49.6, y: 25); leaves.rotate(by: .degrees(sway)); leaves.translateBy(x: -49.6, y: -25)
        leaves.fill(Shapes.mintB, with: .color(Palette.mintLight))
        leaves.fill(Shapes.mintA, with: .color(Palette.mint))
        leaves.fill(Shapes.mintD, with: .color(Palette.mintPale))
        leaves.fill(Shapes.mintC, with: .color(Palette.mintPale))
        leaves.stroke(Shapes.mintVeins, with: .color(Palette.mintVein.opacity(0.45)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
        leg(&ctx, 33); leg(&ctx, 59)
        body(&ctx, Shapes.mossBody, Palette.moss, Palette.mossDeep)
        ctx.fill(Shapes.mossTufts, with: .color(Palette.mossLight.opacity(0.7)))
        eye(&ctx, 43, 55, 6.4, 7.4, look, lid, Palette.moss)
        eye(&ctx, 58, 55, 6.4, 7.4, look, lid, Palette.moss)
        if mood == .wow { ctx.fill(Path(ellipseIn: CGRect(x: 48.3, y: 65.2, width: 4.4, height: 5.6)), with: .color(Palette.ink)) }
    }

    private func drawOtto(_ ctx: inout GraphicsContext, _ look: CGPoint, _ lid: Double, swing: Double) {
        shadow(&ctx, 23)
        var rod = ctx
        rod.translateBy(x: 53, y: 17); rod.rotate(by: .degrees(swing)); rod.translateBy(x: -53, y: -17)
        rod.stroke(Shapes.ottoStem, with: .color(Palette.rodDeep), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        rod.fill(Path(ellipseIn: CGRect(x: 58.8, y: 2.6, width: 6.4, height: 6.4)), with: .color(Palette.bead))
        leg(&ctx, 38); leg(&ctx, 56)
        body(&ctx, Shapes.ottoBody, Palette.rod, Palette.rodDeep)
        ctx.fill(Shapes.ottoDip, with: .color(Palette.rodDeep.opacity(0.55)))
        eye(&ctx, 51, 44, 12.5, 11.5, look, mood == .wow ? 0 : lid, Palette.rod)
        ctx.fill(Path(ellipseIn: CGRect(x: 67.8, y: 63.8, width: 12.4, height: 12.4)), with: .color(Palette.bead))
        ctx.fill(Path(ellipseIn: CGRect(x: 70.4, y: 66.2, width: 3.6, height: 3.6)), with: .color(Palette.beadLight))
        if mood == .wow { ctx.fill(Path(ellipseIn: CGRect(x: 48.8, y: 61.2, width: 4.4, height: 5.6)), with: .color(Palette.ink)) }
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
