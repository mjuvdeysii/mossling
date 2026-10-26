import SwiftUI

/// A companion as the studio made it: a matte soft-vinyl figure, rendered in Blender (tools/ip3d.py sprites) in each
/// of its states — idle, a look left, right, up and down, a blink, wide eyes, its one kind of smile, asleep, and its own
/// move (Moss hops, leaves up; Otto yawns). The view picks the state of the moment and moves the whole figure: it
/// breathes, blinks, glances, hops; a contact shadow stays on the floor; Otto's bead throws a little light.
///
/// Personalities (docs/IP.md): Moss is a small child — always charged, quick glances, a faster breath, a hop at any
/// excuse — with a deadpan face. Otto is a tired grown-up — heavy lids, slow breath, a glance only now and then, and
/// sometimes a long yawn — and still always holds the light. Neither smiles much; that is the joke.
///
/// `look` is where the eyes point (each axis −1…1, y down); `lid` ≥ 0.8 shuts the eyes. A tap makes it hop; a long
/// press is a pat — eyes close happily, a soft tap of haptics. Five quick taps on Moss send mint leaves drifting up.
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
    @State private var fleckAt = Date.distantPast
    @State private var glanceTo = CGPoint.zero
    @State private var glanceAt = Date.distantPast
    @State private var lookFrom = CGPoint.zero
    @State private var lookAt = Date.distantPast
    @State private var leanFrom = 0.0
    @State private var leanAt = Date.distantPast
    @State private var taps = 0
    @State private var lastTap = Date.distantPast
    @State private var pattedAt = Date.distantPast
    @State private var pats = 0
    @State private var yawnAt = Date.distantPast
    @State private var sprites: [String: UIImage] = [:]

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
        .task(id: kind) { await loadSprites() }
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
            // Moss can't keep still; Otto can barely be bothered
            try? await Task.sleep(for: kind == .moss ? .milliseconds(3200 + Int.random(in: 0...3800)) : .milliseconds(9000 + Int.random(in: 0...8000)))
            guard mood != .sleep else { continue }
            if kind == .otto && mood == .open && Int.random(in: 0..<4) == 0 { yawnAt = Date(); continue }
            if kind == .moss && mood == .open && Int.random(in: 0..<5) == 0 { hopSize = 0.45; hopAt = Date(); continue }
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

    /// Which of the rendered states (tools/ip3d.py sprites) shows this moment: the face first, then the look, quantised
    /// to five directions — a designer toy does not slide its pupils, it turns them.
    static func state(_ kind: Kind, face: Mood, look: CGPoint, lid: Double, hopping: Bool, yawning: Bool) -> String {
        if face == .sleep { return "sleep" }
        if face == .happy { return kind == .moss && hopping ? "hop" : "glee" }
        if lid >= 0.8 { return "blink" }
        if kind == .otto && yawning { return "yawn" }
        if face == .wow { return "wide" }
        if kind == .moss && hopping { return "hop" }
        if abs(look.x) >= 0.45 && abs(look.x) >= abs(look.y) { return look.x < 0 ? "left" : "right" }
        if look.y <= -0.45 { return "up" }
        if look.y >= 0.45 { return "down" }
        return "idle"
    }
    static let states: [Kind: [String]] = [
        .moss: ["idle", "left", "right", "up", "down", "blink", "wide", "glee", "sleep", "hop"],
        .otto: ["idle", "left", "right", "up", "down", "blink", "wide", "glee", "sleep", "yawn"],
    ]
    /// Where Otto's bead sits in each state (fraction of the square, from sprites.json), for the lamp's light.
    static let bead: [String: CGPoint] = Sprites.bead
    /// Feet line in the square (from the renders), where squash and stretch are anchored and the shadow sits.
    private var feet: CGFloat { kind == .moss ? Sprites.mossFeet : Sprites.ottoFeet }

    private func loadSprites() async {
        let prefix = kind == .moss ? "ip_moss_" : "ip_otto_"
        let names = Self.states[kind] ?? []
        let loaded: [String: UIImage] = await Task.detached(priority: .userInitiated) {
            var d: [String: UIImage] = [:]
            for s in names { if let i = ArtCache.shared.image(prefix + s + ".webp", maxPixel: 512) { d[s] = i } }
            return d
        }.value
        sprites = loaded
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ now: Date) {
        let s = min(size.width, size.height) / 100
        let t = now.timeIntervalSinceReferenceDate
        let period = mood == .sleep ? 4.2 : kind == .moss ? 2.6 : 3.8
        let b = still ? 0 : (1 - cos(t / period * 2 * .pi)) / 2
        let amp = mood == .sleep ? 0.022 : kind == .moss ? 0.016 : 0.01
        let hopT = now.timeIntervalSince(hopAt)
        let hop = still ? 0 : max(0, Self.bounce(hopT)) * hopSize
        let leanNow = leanFrom + (lean - leanFrom) * Self.ease(now.timeIntervalSince(leanAt) / 0.5)

        ctx.translateBy(x: (size.width - 100 * s) / 2, y: (size.height - 100 * s) / 2)
        ctx.scaleBy(x: s, y: s)
        shadow(&ctx, kind == .moss ? 30 : 22, lift: hop)
        ctx.translateBy(x: 0, y: -hop * 7)
        // squash and stretch from the feet
        ctx.translateBy(x: 50, y: feet); ctx.scaleBy(x: 1 - b * amp * 0.5, y: 1 + b * amp); ctx.rotate(by: .degrees(leanNow)); ctx.translateBy(x: -50, y: -feet)

        let patted = now.timeIntervalSince(pattedAt) < 1.6
        // the resting lids are part of the figures (Moss half-lidded, Otto heavier); only a real blink or a shut lid swaps
        let l = max(lid ?? 0, !still && blinkValue(now) >= 0.5 ? 1 : 0)
        let face: Mood = patted ? .happy : (arms == .cheer ? .happy : mood)
        let e0 = lookValue(still ? .distantFuture : now), g = still ? .zero : glanceValue(now)
        let e = CGPoint(x: e0.x + g.x, y: e0.y + g.y)
        let squeeze: Double = patted && !still ? 0.04 * sin(min(1.0, now.timeIntervalSince(pattedAt) / 0.3) * Double.pi) : 0
        if squeeze > 0 { ctx.translateBy(x: 50, y: feet); ctx.scaleBy(x: 1 + squeeze, y: 1 - squeeze); ctx.translateBy(x: -50, y: -feet) }
        let yawning = !still && now.timeIntervalSince(yawnAt) < 1.7
        let st = Self.state(kind, face: face, look: e, lid: patted ? 0 : l, hopping: hop > 0.15 || (arms == .cheer && !still), yawning: yawning)
        let box = CGRect(x: 0, y: 0, width: 100, height: 100)
        if let img = sprites[st] ?? sprites["idle"] {
            ctx.draw(Image(uiImage: img), in: box)
        }
        if kind == .otto { lamp(&ctx, Self.bead[st] ?? Self.bead["idle"] ?? CGPoint(x: 0.29, y: 0.34), now) }

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

    /// Otto's bead is always a lamp: a faint warm halo by day, a full soft glow at night (a drawing, not the screen).
    private func lamp(_ ctx: inout GraphicsContext, _ at: CGPoint, _ now: Date) {
        let c = CGPoint(x: at.x * 100, y: at.y * 100)
        let pulse = still || !glow ? 1 : 0.88 + 0.12 * sin(now.timeIntervalSinceReferenceDate * 2)
        let r = (glow ? 15 : 8) * pulse
        var g = ctx
        g.blendMode = .plusLighter
        g.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
               with: .radialGradient(Gradient(colors: [Palette.amber.opacity(glow ? 0.7 : 0.22), Palette.amber.opacity(0)]), center: c, startRadius: 1.5, endRadius: r))
    }

    private func shadow(_ ctx: inout GraphicsContext, _ rx: CGFloat, lift: Double) {
        // a soft contact shadow under the feet; it shrinks and fades while the body is in the air
        let k = 1 - min(0.5, lift * 0.6)
        var g = ctx; g.translateBy(x: 50, y: feet + 0.5); g.scaleBy(x: k, y: 0.2 * k)
        g.fill(Path(ellipseIn: CGRect(x: -rx * 1.1, y: -rx * 1.1, width: rx * 2.2, height: rx * 2.2)),
               with: .radialGradient(Gradient(colors: [Palette.ink.opacity(scheme == .dark ? 0.45 : 0.2), Palette.ink.opacity(0)]), center: .zero, startRadius: 0, endRadius: rx * 1.1))
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
