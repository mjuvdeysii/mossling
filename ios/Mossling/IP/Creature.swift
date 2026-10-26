import SwiftUI

/// A companion, drawn as on the app icon (tools/ios_icon.py): the same silhouettes, colours and eyes, in flat colour
/// with a flat darker underside — no gloss, no sheen, no glass (ios/DESIGN.md §3). Beyond the icon it has a face that
/// changes (a mouth, pink cheeks) and two small arms that appear only to wave or cheer, so at rest it is the icon.
///
/// `look` is where the pupils point (each axis −1…1); `lid` closes the eye (0 open, 1 shut), nil uses the character's
/// own rest (Otto rests under a heavy lid). It breathes, blinks now and then, glances away and back, hops once when it
/// becomes happy; Moss's mint leaves sway and Otto's bead swings on its rod. A tap makes it hop (Otto's bead swings
/// wide); a long press is a pat — eyes close happily, cheeks go pink, a soft tap of haptics. Five quick taps on Moss
/// send mint leaves drifting up. Everything is computed from time, so it stays still when Reduce Motion is on.
struct Creature: View {
    let kind: Kind
    var mood: Mood = .open
    var look: CGPoint = .zero
    var lid: Double? = nil
    var lean: Double = 0
    var alive: Bool = true
    var poke: Bool = false
    var label: String? = nil
    var arms: Arms = .rest
    /// Otto's bead lit as a lamp (at night).
    var glow: Bool = false
    /// How long a change of `look` takes (MascotStyle.glanceMs: Moss quick, Otto slow).
    var lookSeconds: Double = 0.42

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
    @State private var swingAt = Date.distantPast
    @State private var pattedAt = Date.distantPast
    @State private var pats = 0

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
        .onTapGesture { if poke { tapped() } }
        .onLongPressGesture(minimumDuration: 0.35) { if poke { pattedAt = Date(); pats += 1 } }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: taps)
        .sensoryFeedback(.success, trigger: pats)
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
        leafAt = now; swingAt = now
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
        let k = Self.ease(now.timeIntervalSince(lookAt) / max(0.05, lookSeconds))
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

        let patted = now.timeIntervalSince(pattedAt) < 1.6
        let rest = lid ?? (kind == .otto ? 0.34 : 0)
        let l = max(rest, still ? 0 : blinkValue(now))
        let face: Mood = patted ? .happy : mood
        let wave: Double = still ? 0 : sin(t * 9) * 16
        let swingK = still ? 0 : Self.bounce(now.timeIntervalSince(swingAt) * 0.45) * 26
        let e0 = lookValue(still ? .distantFuture : now), g = still ? .zero : glanceValue(now)
        let e = CGPoint(x: e0.x + g.x, y: e0.y + g.y)
        let squeeze: Double = patted && !still ? 0.04 * sin(min(1.0, now.timeIntervalSince(pattedAt) / 0.3) * Double.pi) : 0
        if squeeze > 0 { ctx.translateBy(x: 50, y: 88); ctx.scaleBy(x: 1 + squeeze, y: 1 - squeeze); ctx.translateBy(x: -50, y: -88) }
        let pose: Arms = patted ? .rest : arms
        if kind == .moss { drawMoss(&ctx, e, patted ? 1 : l, face, pose, wave, sway: (b - 0.5) * 6 + leaf) }
        else { drawOtto(&ctx, e, patted ? 1 : l, face, pose, wave, swing: (b - 0.5) * 5 + leaf * 0.4 + swingK) }

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
        // a soft contact shadow, darkest right under the feet, as under the figures in the pictures
        var g = ctx; g.translateBy(x: 50, y: 90.5); g.scaleBy(x: 1, y: 0.2)
        g.fill(Path(ellipseIn: CGRect(x: -rx * 1.1, y: -rx * 1.1, width: rx * 2.2, height: rx * 2.2)),
               with: .radialGradient(Gradient(colors: [Palette.ink.opacity(0.2), Palette.ink.opacity(0)]), center: .zero, startRadius: 0, endRadius: rx * 1.1))
    }
    private func leg(_ ctx: inout GraphicsContext, _ x: CGFloat) {
        ctx.fill(Path(roundedRect: CGRect(x: x, y: 80, width: 6.5, height: 10), cornerRadius: 3.2), with: .color(Palette.ink))
    }
    /// The icon's body: one flat colour, and the underside in a flat deeper colour (as Otto's dip on the icon).
    private func body(_ ctx: inout GraphicsContext, _ p: Path, _ fill: Color, under: Path, _ deep: Color) {
        // on the dark page a thin lighter rim keeps the silhouette (navy Otto would sink into black); no gloss
        if scheme == .dark { ctx.stroke(p, with: .color(fill.mix(with: .white, by: 0.35)), lineWidth: 2.4) }
        // matte volume, lit from the top left as in the picture book: a soft light side and a soft shade side, the
        // icon's flat underside, then a little bounce light from the floor along the bottom edge — clay, not glass:
        // no specular highlight, no reflection
        let b = p.boundingRect
        ctx.fill(p, with: .linearGradient(Gradient(stops: [.init(color: fill.mix(with: .white, by: 0.2), location: 0),
                                                           .init(color: fill, location: 0.45),
                                                           .init(color: fill.mix(with: deep, by: 0.45), location: 1)]),
                                          startPoint: CGPoint(x: b.minX + b.width * 0.15, y: b.minY), endPoint: CGPoint(x: b.maxX, y: b.maxY)))
        var c = ctx; c.clip(to: p)
        c.fill(under, with: .color(deep.opacity(0.5)))
        c.fill(Path(ellipseIn: CGRect(x: b.minX + b.width * 0.08, y: b.minY + b.height * 0.05, width: b.width * 0.55, height: b.height * 0.5)),
               with: .radialGradient(Gradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0)]),
                                     center: CGPoint(x: b.minX + b.width * 0.32, y: b.minY + b.height * 0.25), startRadius: 0, endRadius: b.width * 0.32))
        c.fill(Path(CGRect(x: b.minX, y: b.maxY - b.height * 0.14, width: b.width, height: b.height * 0.14)),
               with: .linearGradient(Gradient(colors: [Color(hex: 0xFFE7B8).opacity(0), Color(hex: 0xFFE7B8).opacity(0.14)]),
                                     startPoint: CGPoint(x: 0, y: b.maxY - b.height * 0.14), endPoint: CGPoint(x: 0, y: b.maxY)))
    }
    private func eye(_ ctx: inout GraphicsContext, _ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ look: CGPoint, _ lid: Double, _ skin: Color, _ face: Mood) {
        if face == .sleep || (face == .happy && lid >= 1) {
            // closed: asleep (a gentle downward curve) or delighted (an upward arch)
            var p = Path(); p.move(to: CGPoint(x: cx - rx * 0.9, y: cy))
            p.addQuadCurve(to: CGPoint(x: cx + rx * 0.9, y: cy), control: CGPoint(x: cx, y: face == .sleep ? cy + ry * 0.9 : cy - ry * 0.9))
            ctx.stroke(p, with: .color(Palette.ink), style: StrokeStyle(lineWidth: max(1.8, ry * 0.34), lineCap: .round)); return
        }
        let r = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
        var c = ctx
        c.clip(to: Path(ellipseIn: r))
        c.fill(Path(r), with: .color(Palette.paper))
        let pr = min(rx, ry) * (face == .wow ? 0.5 : 0.62)
        let px = cx + max(-1, min(1, look.x)) * (rx - pr - 0.3), py = cy + max(-1, min(1, look.y)) * (ry - pr - 0.3)
        c.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)), with: .color(Palette.ink))
        c.fill(Path(ellipseIn: CGRect(x: px - pr * 0.55, y: py - pr * 0.6, width: pr * 0.4, height: pr * 0.4)), with: .color(.white.opacity(0.9)))
        if face == .happy { c.fill(Path(ellipseIn: CGRect(x: cx - rx * 1.3, y: cy + ry * 0.2, width: rx * 2.6, height: ry * 2)), with: .color(skin)) }
        if lid > 0 { c.fill(Path(CGRect(x: cx - rx - 0.6, y: cy - ry - 0.6, width: rx * 2 + 1.2, height: (ry * 2 + 1.2) * lid)), with: .color(skin)) }
        // the anti-aliased edge of the white would leave a pale ring under the lid: cover it with the skin
        if lid > 0 { ctx.stroke(Path(ellipseIn: r.insetBy(dx: -0.4, dy: -0.4)), with: .color(skin), lineWidth: 1.2) }
    }
    private func cheeks(_ ctx: inout GraphicsContext, _ pts: [CGPoint], _ face: Mood) {
        guard face == .happy || face == .wow else { return }
        for p in pts { ctx.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 2.4, width: 8, height: 4.8)), with: .color(Crayon.pink.opacity(0.75))) }
    }
    private func mouth(_ ctx: inout GraphicsContext, _ at: CGPoint, _ face: Mood) {
        switch face {
        case .wow: ctx.fill(Path(ellipseIn: CGRect(x: at.x - 2.2, y: at.y - 2.6, width: 4.4, height: 5.6)), with: .color(Palette.ink))
        case .happy:
            var p = Path(); p.move(to: CGPoint(x: at.x - 4, y: at.y - 1)); p.addQuadCurve(to: CGPoint(x: at.x + 4, y: at.y - 1), control: CGPoint(x: at.x, y: at.y + 4))
            ctx.stroke(p, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        default: break
        }
    }
    /// Small round arms, only when waving or cheering; `left`/`right` are the shoulders.
    private func armsDraw(_ ctx: inout GraphicsContext, _ pose: Arms, left: CGPoint, right: CGPoint, _ c: Color, _ wave: Double) {
        func arm(_ from: CGPoint, _ deg: Double, _ L: CGFloat = 13) {
            let r = CGFloat(deg * .pi / 180)
            var p = Path(); p.move(to: from); p.addLine(to: CGPoint(x: from.x + CGFloat(Foundation.sin(Double(r))) * L, y: from.y - CGFloat(Foundation.cos(Double(r))) * L))
            ctx.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        }
        switch pose {
        case .rest: break
        case .wave: arm(right, 30 + wave)
        case .cheer: arm(left, -38 - wave * 0.4); arm(right, 38 + wave * 0.4)
        case .hug: arm(left, -112 + wave * 0.12, 24)
        }
    }

    private func drawMoss(_ ctx: inout GraphicsContext, _ look: CGPoint, _ lid: Double, _ face: Mood, _ pose: Arms, _ wave: Double, sway: Double) {
        shadow(&ctx, 31)
        ctx.stroke(Shapes.mossStem, with: .color(Palette.mossDeep), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        var leaves = ctx
        leaves.translateBy(x: 49.6, y: 25); leaves.rotate(by: .degrees(sway)); leaves.translateBy(x: -49.6, y: -25)
        leaves.fill(Shapes.mintB, with: .color(Palette.mintLight))
        leaves.fill(Shapes.mintA, with: .color(Palette.mint))
        leaves.fill(Shapes.mintD, with: .color(Palette.mintPale))
        leaves.fill(Shapes.mintC, with: .color(Palette.mintPale))
        leg(&ctx, 33); leg(&ctx, 59)
        armsDraw(&ctx, pose, left: CGPoint(x: 19, y: 62), right: CGPoint(x: 83, y: 60), Palette.mossDeep, wave)
        body(&ctx, Shapes.mossBody, Palette.moss, under: Shapes.mossUnder, Palette.mossDeep)
        // the moss itself: a few lighter tufts on the back, so he reads as a little mossy stone, not a green blob
        var tufts = ctx; tufts.clip(to: Shapes.mossBody)
        tufts.fill(Shapes.mossTufts, with: .color(Palette.mossLight.opacity(0.42)))
        cheeks(&ctx, [CGPoint(x: 35, y: 64), CGPoint(x: 66, y: 64)], face)
        eye(&ctx, 43, 55, 6.4, 7.4, look, lid, Palette.moss, face)
        eye(&ctx, 58, 55, 6.4, 7.4, look, lid, Palette.moss, face)
        mouth(&ctx, CGPoint(x: 50.5, y: 68), face)
    }

    private func drawOtto(_ ctx: inout GraphicsContext, _ look: CGPoint, _ lid: Double, _ face: Mood, _ pose: Arms, _ wave: Double, swing: Double) {
        shadow(&ctx, 23)
        // the rod curves forward and the golden bead hangs from it, as on the icon
        var rod = ctx
        rod.translateBy(x: 50, y: 16.5); rod.rotate(by: .degrees(swing)); rod.translateBy(x: -50, y: -16.5)
        rod.stroke(Shapes.ottoRod, with: .color(Palette.rodDeep), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        // the lamp is always a lamp: a faint warm halo round the bead by day, a full glow at night (a drawing only)
        if !glow {
            rod.fill(Path(ellipseIn: CGRect(x: 11, y: 2.5, width: 18, height: 18)),
                     with: .radialGradient(Gradient(colors: [Palette.amber.opacity(0.32), Palette.amber.opacity(0)]), center: CGPoint(x: 20, y: 11.5), startRadius: 3, endRadius: 9))
        }
        if glow {
            let pulse = still ? 1 : 0.85 + 0.15 * sin(Date().timeIntervalSinceReferenceDate * 2)
            rod.fill(Path(ellipseIn: CGRect(x: 20 - 14 * pulse, y: 11.5 - 14 * pulse, width: 28 * pulse, height: 28 * pulse)),
                     with: .radialGradient(Gradient(colors: [Palette.amber.opacity(0.75), Palette.amber.opacity(0)]), center: CGPoint(x: 20, y: 11.5), startRadius: 2, endRadius: 14 * pulse))
        }
        rod.fill(Path(ellipseIn: CGRect(x: 15, y: 6.5, width: 10, height: 10)), with: .color(glow ? Palette.amber : Palette.bead))
        rod.fill(Path(ellipseIn: CGRect(x: 17, y: 8.3, width: 3.2, height: 3.2)), with: .color(Palette.beadLight))
        leg(&ctx, 38); leg(&ctx, 56)
        armsDraw(&ctx, pose, left: CGPoint(x: 29, y: 60), right: CGPoint(x: 72, y: 58), Palette.rodDeep, wave)
        body(&ctx, Shapes.ottoBody, Palette.rod, under: Shapes.ottoDip, Palette.rodDeep)
        cheeks(&ctx, [CGPoint(x: 64, y: 58)], face)
        eye(&ctx, 51, 44, 12.5, 11.5, look, face == .wow ? 0 : lid, Palette.rod, face)
        mouth(&ctx, CGPoint(x: 51, y: 64), face)
    }
}

/// Moss and Otto together: the chosen one in front, the other a step behind and smaller. Now and then (every quarter
/// minute or so — mostly still) the one behind leans in, the one in front turns to it, and both brighten.
///
/// The chosen one stays in front by day and by night (the choice changes the performance, never the function). At night
/// the two rest: half-closed eyes, no leaning in, Otto's bead glows softly — a drawing of a lamp, not the screen.
/// With `reacts`, the pair answers a confirmed save (MascotDirector.acknowledgements) once, within 550 ms.
/// Decorative: hidden from VoiceOver unless given a label.
struct Duo: View {
    let primary: Kind
    var size: CGFloat = 112
    var mood: Mood = .open
    var look: CGPoint = CGPoint(x: -0.6, y: 0.2)
    var lid: Double? = nil
    var poke = true
    var together = true
    /// Change it to make both cheer (arms up, a hop) for a moment.
    var cheer = 0
    /// Night: the pair rests; Otto's bead glows.
    var night = false
    /// Answer confirmed saves (the IP event contract), once each.
    var reacts = false
    /// Read by VoiceOver only when it says something the page does not.
    var label: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(MascotDirector.self) private var mascot: MascotDirector?
    @State private var beat = 0
    @State private var cheering = false
    @State private var observing = false

    var body: some View {
        let small = size * 0.72
        let asleep = mood == .sleep
        ZStack(alignment: .bottomLeading) {
            Creature(kind: primary.other, mood: asleep ? .sleep : cheering || beat == 2 ? .happy : .open,
                     look: beat >= 1 ? CGPoint(x: -0.9, y: 0.5) : CGPoint(x: -0.7, y: 0.1), lid: night && !cheering ? 0.5 : nil,
                     lean: beat == 1 ? -MascotStyle.of(primary.other).tiltDegrees : 0, alive: !reduce, poke: poke,
                     arms: cheering ? .cheer : .rest, glow: night && primary.other == .otto)
                .frame(width: small, height: small)
                .offset(x: size - small * 0.38, y: -2)
            Creature(kind: primary, mood: cheering ? .happy : beat == 2 && mood == .open ? .happy : mood,
                     look: observing ? CGPoint(x: -0.3, y: 1) : beat >= 1 ? CGPoint(x: 0.95, y: -0.35) : look, lid: beat >= 1 ? nil : lid ?? (night && !cheering && mood != .sleep ? 0.5 : nil), poke: poke,
                     label: label, arms: cheering ? .cheer : .rest, glow: night && primary == .otto)
                .frame(width: size, height: size)
        }
        .frame(width: size + small * 0.62, height: size, alignment: .bottomLeading)
        .accessibilityElement(children: label == nil ? .ignore : .combine)
        .accessibilityLabel(label ?? "")
        .accessibilityHidden(label == nil)
        .onChange(of: cheer) { _, _ in answer() }
        .onChange(of: mascot?.acknowledgements ?? 0) { _, _ in if reacts { answer() } }
        // observing: a look down at what changed (the week's plays), held for the companion's own time, then back
        .onChange(of: mascot?.observations ?? 0) { _, _ in
            guard reacts, !reduce else { return }
            observing = true
            let ms = MascotStyle.of(primary).observeMs
            Task { try? await Task.sleep(for: .milliseconds(ms)); observing = false }
        }
        .task(id: "\(reduce)\(asleep)\(together)\(night)") {
            beat = 0
            guard !reduce, !asleep, together, !night else { return }
            try? await Task.sleep(for: .milliseconds(4000 + Int.random(in: 0...4000)))
            while !Task.isCancelled {
                beat = 1; try? await Task.sleep(for: .milliseconds(900))
                beat = 2; try? await Task.sleep(for: .milliseconds(1200))
                beat = 0; try? await Task.sleep(for: .milliseconds(14000 + Int.random(in: 0...10000)))
            }
        }
    }

    /// The single reply: arms up and a hop, for the companion's own short time (≤ 550 ms); nothing under Reduce Motion.
    private func answer() {
        guard !reduce else { return }
        cheering = true
        let ms = MascotStyle.of(primary).acknowledgeMs
        Task { try? await Task.sleep(for: .milliseconds(ms)); cheering = false }
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
            Text("36 个月以后，路还很长，每一天都有新的样子。").font(.subheadline).foregroundStyle(Palette.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
