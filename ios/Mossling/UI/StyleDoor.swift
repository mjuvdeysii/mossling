import SwiftUI

// MARK: the hidden door between the two worlds
//
// 摸索台灯的故事 (关于摸索台灯 › 摸索台灯的故事) opens on a picture of the lamp and the two. Tap it quickly: from the fifth tap the glass cracks
// from where it was struck, each further tap spreads the cracks, and on the tenth it shatters: the picture of the two breaks into shards that fall away, a sheet of paper sweeps the screen, and the
// whole app is the 2D world of build 196 — the flat companions, the stickers, the pictures, the shelf, the tabs.
// In the 2D world, keep a finger moving on the picture for three seconds without lifting it: a ring of light fills
// round them, and when it closes a warm light blooms from them over the whole screen and the 3D world comes back.

/// What the overlay above the whole app is showing.
@Observable final class StyleShift {
    static let shared = StyleShift()
    enum Phase: Equatable { case idle, shatter(start: Date), bloom(start: Date) }
    var phase: Phase = .idle
    /// The picture that breaks, and where it was on screen.
    var image: UIImage?
    var frame: CGRect = .zero
    /// Where the glass was struck, as a fraction of the picture.
    var impact = CGPoint(x: 0.45, y: 0.5)
}

/// The story page's title picture, as the door.
///
/// A double tap does nothing you can see. Five quick taps and the glass takes a star of hairline cracks where the finger
/// struck; every further quick tap runs the cracks further out, rings them and branches them; the tenth breaks it.
/// Stop tapping and the cracks heal away.
struct StyleDoor<Content: View>: View {
    var radius: CGFloat = 28
    @ViewBuilder let content: Content
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var taps = 0
    @State private var lastTap = Date.distantPast
    /// Where the glass was first struck, as a fraction of the picture.
    @State private var impact = CGPoint(x: 0.45, y: 0.5)
    @State private var size: CGSize = .zero
    @State private var frame: CGRect = .zero
    // the way back: how long the finger has been moving, and when it last moved
    @State private var held: Date?
    @State private var lastMove = Date.distantPast
    @State private var progress = 0.0
    @State private var ticks = 0

    /// Taps before the first crack shows, and the tap that breaks the glass.
    static var crackAt: Int { 5 }
    static var breakAt: Int { 10 }
    private var flat: Bool { app.artStyle == .flat }
    private var level: Int { taps - Self.crackAt + 1 }

    var body: some View {
        content
            .overlay {
                if !flat && level >= 1 {
                    Cracks(level: level, impact: impact).allowsHitTesting(false).transition(.opacity)
                }
            }
            .overlay { if flat && progress > 0 { ProgressHalo(progress: progress, radius: radius).allowsHitTesting(false) } }
            .contentShape(Rectangle())
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0; size = $0.size }
            .onTapGesture(coordinateSpace: .local) { loc in if !flat { tapped(at: loc) } }
            .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in if flat { moved() } }.onEnded { _ in if flat { reset() } })
            .sensoryFeedback(trigger: taps) { old, new in
                guard new > old else { return nil }
                return new >= Self.crackAt ? .impact(weight: .heavy, intensity: min(1, 0.55 + Double(new - Self.crackAt) * 0.1)) : nil
            }
            .sensoryFeedback(.selection, trigger: ticks)
    }

    private func tapped(at loc: CGPoint) {
        let now = Date()
        // before the glass cracks the taps must come fast; once cracked it waits a little longer for the next
        let window: TimeInterval = taps >= Self.crackAt ? 0.8 : 0.42
        taps = now.timeIntervalSince(lastTap) < window ? taps + 1 : 1
        lastTap = now
        if taps == Self.crackAt, size.width > 1 {
            impact = CGPoint(x: min(0.92, max(0.08, loc.x / size.width)), y: min(0.92, max(0.08, loc.y / size.height)))
        }
        if taps >= Self.breakAt { taps = 0; shatter(); return }
        // left alone, the cracks heal
        let stamp = now
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            if lastTap == stamp && taps > 0 { withAnimation(.easeOut(duration: 0.6)) { taps = 0 } }
        }
    }

    private func shatter() {
        StyleShift.shared.image = Self.snapshot(frame)
        StyleShift.shared.frame = frame
        StyleShift.shared.impact = impact
        if reduce { app.artStyle = .flat; return }
        StyleShift.shared.phase = .shatter(start: Date())
        // the world changes under the sheet of paper, once the shards have begun to fall
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            app.artStyle = .flat
            try? await Task.sleep(for: .milliseconds(1250))
            StyleShift.shared.phase = .idle
        }
    }

    /// What is on screen inside `rect` right now, as one picture to break.
    static func snapshot(_ rect: CGRect) -> UIImage? {
        guard let w = UIApplication.shared.connectedScenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first, rect.width > 1 else { return nil }
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = w.screen.scale
        return UIGraphicsImageRenderer(size: rect.size, format: fmt).image { _ in
            w.drawHierarchy(in: CGRect(x: -rect.minX, y: -rect.minY, width: w.bounds.width, height: w.bounds.height), afterScreenUpdates: false)
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
        if reduce { app.artStyle = .vinyl; return }
        StyleShift.shared.phase = .bloom(start: Date())
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(480))
            app.artStyle = .vinyl
            try? await Task.sleep(for: .milliseconds(900))
            StyleShift.shared.phase = .idle
        }
    }
}

/// A small fixed-seed generator, so the same glass always cracks the same way and the shards follow the cracks.
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

/// A spider-web of hairline cracks from where the glass was struck: radial lines that run further out with each tap,
/// concentric arcs between them, small branches, and a crushed spot at the centre. Thin bright edges over a faint
/// dark line, with a few glints where the light catches a crack.
private struct Cracks: View {
    let level: Int
    let impact: CGPoint
    var body: some View {
        Canvas { ctx, size in Self.draw(&ctx, size, level, impact) }
    }

    private struct Seg { let path: Path; let stage: Int; let width: CGFloat; let glint: Bool }

    private static func web(_ size: CGSize, _ impact: CGPoint) -> [Seg] {
        var g = GlassRandom(0x51_A55)
        let w: CGFloat = size.width, h: CGFloat = size.height
        let c = CGPoint(x: impact.x * w, y: impact.y * h)
        let far: CGFloat = max(hypot(c.x, c.y), hypot(w - c.x, c.y), hypot(c.x, h - c.y), hypot(w - c.x, h - c.y))
        var out: [Seg] = []
        let k = 15
        var arms: [[CGPoint]] = []
        for i in 0..<k {
            let base: CGFloat = CGFloat(i) / CGFloat(k) * 2 * .pi + g.range(-0.14, 0.14)
            // the first arms show at the first crack, the rest join on later taps
            let first: Int = i % 3 == 0 ? 1 : (i % 3 == 1 ? 2 : 3)
            let reach: CGFloat = far * g.range(0.75, 1.05)
            var pts: [CGPoint] = [c]
            var a: CGFloat = base
            var r: CGFloat = 0
            while r < reach {
                r += g.range(0.035, 0.075) * far * (0.6 + r / far)
                a += g.range(-0.07, 0.07)
                pts.append(CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
            }
            arms.append(pts)
            for j in 1..<pts.count {
                let f: CGFloat = hypot(pts[j].x - c.x, pts[j].y - c.y) / far
                var p = Path(); p.move(to: pts[j - 1]); p.addLine(to: pts[j])
                let stage: Int = max(first, 1 + Int(f * 5.2))
                out.append(Seg(path: p, stage: stage, width: max(0.35, 0.95 - f * 0.7), glint: j == 2 && i % 4 == 0))
                // a short branch now and then
                if j > 1 && g.unit() < 0.32 {
                    let side: CGFloat = g.unit() < 0.5 ? -1 : 1
                    let ba: CGFloat = atan2(pts[j].y - c.y, pts[j].x - c.x) + side * g.range(0.35, 0.8)
                    let bl: CGFloat = far * g.range(0.03, 0.09)
                    let mid = CGPoint(x: pts[j].x + cos(ba) * bl * 0.55 + g.range(-1.5, 1.5), y: pts[j].y + sin(ba) * bl * 0.55 + g.range(-1.5, 1.5))
                    let end = CGPoint(x: pts[j].x + cos(ba + side * 0.15) * bl, y: pts[j].y + sin(ba + side * 0.15) * bl)
                    var b = Path(); b.move(to: pts[j]); b.addLine(to: mid); b.addLine(to: end)
                    out.append(Seg(path: b, stage: min(5, stage + 1), width: 0.35, glint: false))
                }
            }
        }
        // concentric arcs between neighbouring arms, sagging a little toward the centre
        let rings: [CGFloat] = [0.07, 0.14, 0.24, 0.37, 0.52]
        for (n, ring) in rings.enumerated() {
            for i in 0..<k where g.unit() < 0.72 {
                let a = arms[i], b = arms[(i + 1) % k]
                guard let p0 = nearest(a, c, ring * far), let p1 = nearest(b, c, ring * far * g.range(0.9, 1.1)) else { continue }
                let m = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
                let sag = CGPoint(x: m.x + (c.x - m.x) * 0.12, y: m.y + (c.y - m.y) * 0.12)
                var p = Path(); p.move(to: p0); p.addQuadCurve(to: p1, control: sag)
                out.append(Seg(path: p, stage: min(5, 2 + n), width: max(0.3, 0.6 - CGFloat(n) * 0.06), glint: n == 1 && i % 5 == 2))
            }
        }
        // the crushed spot where the finger struck
        for _ in 0..<14 {
            let a: CGFloat = g.range(0, 2 * .pi), r0: CGFloat = g.range(1.5, 4), r1: CGFloat = r0 + g.range(2, 6)
            var p = Path()
            p.move(to: CGPoint(x: c.x + cos(a) * r0, y: c.y + sin(a) * r0))
            p.addLine(to: CGPoint(x: c.x + cos(a + 0.3) * r1, y: c.y + sin(a + 0.3) * r1))
            out.append(Seg(path: p, stage: 1, width: 0.45, glint: false))
        }
        return out
    }

    private static func nearest(_ pts: [CGPoint], _ c: CGPoint, _ r: CGFloat) -> CGPoint? {
        var best: CGPoint?
        var miss: CGFloat = .infinity
        for p in pts.dropFirst() {
            let e: CGFloat = abs(hypot(p.x - c.x, p.y - c.y) - r)
            if e < miss { miss = e; best = p }
        }
        return best
    }

    private static func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ level: Int, _ impact: CGPoint) {
        let segs = web(size, impact).filter { $0.stage <= level }
        let c = CGPoint(x: impact.x * size.width, y: impact.y * size.height)
        // a faint frosting at the point of impact
        let fr: CGFloat = 10 + CGFloat(level) * 3
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - fr, y: c.y - fr, width: 2 * fr, height: 2 * fr)),
                 with: .radialGradient(Gradient(colors: [.white.opacity(0.55), .white.opacity(0)]), center: c, startRadius: 0, endRadius: fr))
        // the dark side of each crack, a hair below and right of its bright edge
        var shade = ctx
        shade.translateBy(x: 0.35, y: 0.45)
        for s in segs { shade.stroke(s.path, with: .color(.black.opacity(0.2)), style: StrokeStyle(lineWidth: s.width * 0.8, lineCap: .round, lineJoin: .round)) }
        for s in segs { ctx.stroke(s.path, with: .color(.white.opacity(0.88)), style: StrokeStyle(lineWidth: s.width, lineCap: .round, lineJoin: .round)) }
        // where the light catches
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 1.6))
            for s in segs where s.glint { l.stroke(s.path, with: .color(.white.opacity(0.95)), lineWidth: 2.2) }
        }
    }
}

/// The ring of light that fills round the picture while the finger keeps moving.
private struct ProgressHalo: View {
    let progress: Double
    var radius: CGFloat = 28
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius + 4, style: .continuous)
        ZStack {
            shape.stroke(Palette.bead.opacity(0.2), lineWidth: 5)
            shape.trim(from: 0, to: progress)
                .stroke(LinearGradient(colors: [Palette.beadLight, Palette.bead], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .shadow(color: Palette.bead.opacity(0.6), radius: 6)
        }
        .padding(-4)
    }
}

/// Above the whole app: the shards falling, the sheet of paper, or the bloom of light.
struct StyleShiftOverlay: View {
    @State private var shift = StyleShift.shared
    var body: some View {
        switch shift.phase {
        case .idle: EmptyView()
        case .shatter(let start): Shatter(start: start, image: shift.image, frame: shift.frame, impact: shift.impact).ignoresSafeArea().allowsHitTesting(false)
        case .bloom(let start): Bloom(start: start, frame: shift.frame).ignoresSafeArea().allowsHitTesting(false)
        }
    }
}

/// The picture breaks along a web of cracks into many small irregular shards, smallest where the glass was struck.
/// They burst outward from that point, tumble with gravity and catch the light as they turn; a little glitter of
/// glass dust follows. A sheet of warm paper sweeps the screen while the world changes beneath it, then lifts.
private struct Shatter: View {
    let start: Date
    let image: UIImage?
    let frame: CGRect
    private struct Shard { let poly: [CGPoint]; let c: CGPoint; let v: CGVector; let spin: CGFloat; let delay: CGFloat; let phase: CGFloat }
    private struct Dust { let p: CGPoint; let v: CGVector; let s: CGFloat; let phase: CGFloat }
    private let shards: [Shard]
    private let dust: [Dust]

    init(start: Date, image: UIImage?, frame: CGRect, impact: CGPoint) {
        self.start = start; self.image = image; self.frame = frame
        var g = GlassRandom(0x51_A55 ^ 0xB0)
        let w: CGFloat = frame.width, h: CGFloat = frame.height
        let c = CGPoint(x: impact.x * w, y: impact.y * h)
        let far: CGFloat = max(hypot(c.x, c.y), hypot(w - c.x, c.y), hypot(c.x, h - c.y), hypot(w - c.x, h - c.y)) + 4
        // a web of vertices shared by neighbouring cells, so the shards tile the picture exactly
        let k = 16
        let rings: [CGFloat] = [0, 0.045, 0.1, 0.17, 0.26, 0.37, 0.5, 0.66, 0.84, 1.06]
        var v: [[CGPoint]] = []
        let angles: [CGFloat] = (0..<k).map { CGFloat($0) / CGFloat(k) * 2 * .pi }
        var jitter: [CGFloat] = []
        for _ in 0..<k { jitter.append(g.range(-0.11, 0.11)) }
        for (n, ring) in rings.enumerated() {
            var row: [CGPoint] = []
            for i in 0..<k {
                let a: CGFloat = angles[i] + jitter[i] + (n == 0 ? 0 : g.range(-0.06, 0.06))
                let r: CGFloat = ring * far * (n == 0 ? 0 : g.range(0.88, 1.12))
                row.append(CGPoint(x: min(w, max(0, c.x + cos(a) * r)), y: min(h, max(0, c.y + sin(a) * r))))
            }
            v.append(row)
        }
        var out: [Shard] = []
        func add(_ poly: [CGPoint]) {
            let cx: CGFloat = poly.map(\.x).reduce(0, +) / CGFloat(poly.count)
            let cy: CGFloat = poly.map(\.y).reduce(0, +) / CGFloat(poly.count)
            // skip cells squeezed flat against the edge of the picture
            var area: CGFloat = 0
            for i in 0..<poly.count { let p = poly[i], q = poly[(i + 1) % poly.count]; area += p.x * q.y - q.x * p.y }
            guard abs(area) > 6 else { return }
            let dx: CGFloat = cx - c.x, dy: CGFloat = cy - c.y
            let d: CGFloat = max(1, hypot(dx, dy))
            let near: CGFloat = max(0, 1 - d / far)
            let push: CGFloat = 90 + 300 * near + g.range(0, 80)
            let vel = CGVector(dx: dx / d * push + g.range(-30, 30), dy: dy / d * push * 0.6 - g.range(60, 220))
            let small: CGFloat = 1 / max(0.4, sqrt(abs(area)) / 40)
            out.append(Shard(poly: poly, c: CGPoint(x: cx, y: cy), v: vel, spin: g.range(-3, 3) * min(3, small),
                             delay: d / far * 0.14 + g.range(0, 0.03), phase: g.range(0, 2 * .pi)))
        }
        for n in 0..<(rings.count - 1) {
            for i in 0..<k {
                let j = (i + 1) % k
                if n == 0 { add([v[0][i], v[1][i], v[1][j]]); continue }
                let quad = [v[n][i], v[n][j], v[n + 1][j], v[n + 1][i]]
                // further out, break some cells again on a diagonal so no two shards look alike
                if n >= 3 && g.unit() < 0.55 {
                    if g.unit() < 0.5 { add([quad[0], quad[1], quad[2]]); add([quad[0], quad[2], quad[3]]) }
                    else { add([quad[0], quad[1], quad[3]]); add([quad[1], quad[2], quad[3]]) }
                } else { add(quad) }
            }
        }
        shards = out
        var specks: [Dust] = []
        for _ in 0..<46 {
            let a: CGFloat = g.range(0, 2 * .pi), sp: CGFloat = g.range(80, 380)
            specks.append(Dust(p: CGPoint(x: c.x + g.range(-6, 6), y: c.y + g.range(-6, 6)),
                               v: CGVector(dx: cos(a) * sp, dy: sin(a) * sp * 0.7 - 120), s: g.range(0.8, 2.2), phase: g.range(0, 2 * .pi)))
        }
        dust = specks
    }

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSince(start)
            Canvas { ctx, size in draw(&ctx, size, CGFloat(t)) }
        }
        .drawingGroup()
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: CGFloat) {
        // the sheet of paper: in by 0.42 s, out by 1.6 s
        let sheet: CGFloat = t < 0.42 ? t / 0.42 : max(0, 1 - (t - 0.7) / 0.9)
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xFBF7F0).opacity(Double(sheet) * 0.96)))
        guard let image, t < 1.6 else { return }
        let img = ctx.resolve(Image(uiImage: image))
        var world = ctx
        world.translateBy(x: frame.minX, y: frame.minY)
        for s in shards { piece(&world, s, img, t) }
        for d in dust {
            let u: CGFloat = max(0, t - 0.02)
            let x: CGFloat = d.p.x + d.v.dx * u
            let y: CGFloat = d.p.y + d.v.dy * u + 700 * u * u
            let tw: Double = Double(0.5 + 0.5 * sin(d.phase + u * 26))
            let o: Double = Double(max(0, 1 - u / 1.0)) * (0.35 + 0.65 * tw)
            world.fill(Path(CGRect(x: x - d.s / 2, y: y - d.s / 2, width: d.s, height: d.s)), with: .color(.white.opacity(o)))
        }
    }

    private func piece(_ ctx: inout GraphicsContext, _ s: Shard, _ img: GraphicsContext.ResolvedImage, _ t: CGFloat) {
        let u: CGFloat = max(0, t - s.delay)
        let k: CGFloat = min(1, u / 1.15)
        guard k < 1 else { return }
        var g = ctx
        g.opacity = Double(1 - k * k)
        g.translateBy(x: s.c.x + s.v.dx * u, y: s.c.y + s.v.dy * u + 1100 * u * u)
        g.rotate(by: .radians(Double(s.spin * u)))
        // tumbling toward the eye: a shard narrows as it turns edge-on
        let turn: CGFloat = cos(s.phase + s.spin * u * 1.4)
        g.scaleBy(x: 1, y: max(0.25, abs(turn)) * (1 - 0.15 * k))
        g.translateBy(x: -s.c.x, y: -s.c.y)
        var p = Path()
        p.move(to: s.poly[0])
        for q in s.poly.dropFirst() { p.addLine(to: q) }
        p.closeSubpath()
        var inner = g
        inner.clip(to: p)
        inner.draw(img, in: CGRect(origin: .zero, size: frame.size))
        // the light running over the face of the glass as it turns
        let glint: Double = Double(max(0, sin(s.phase * 2 + s.spin * u * 2.2))) * 0.38
        if glint > 0.02 { inner.fill(p, with: .color(.white.opacity(glint))) }
        g.stroke(p, with: .color(.white.opacity(0.75)), lineWidth: 0.5)
        g.stroke(p, with: .color(.black.opacity(0.12)), lineWidth: 0.25)
    }
}

/// A warm light blooms from the two over the whole screen; the 3D world comes back under it; it fades, leaving a few
/// sparks rising.
private struct Bloom: View {
    let start: Date
    let frame: CGRect
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSince(start)
            Canvas { ctx, size in draw(&ctx, size, CGFloat(t)) }
        }
    }
    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: CGFloat) {
        let c = CGPoint(x: frame.midX, y: frame.midY)
        let far: CGFloat = hypot(max(c.x, size.width - c.x), max(c.y, size.height - c.y))
        let grow: CGFloat = min(1, t / 0.48)
        let fade: Double = t < 0.5 ? 1 : Double(max(0, 1 - (t - 0.5) / 0.8))
        let r: CGFloat = 40 + (far + 80) * grow * grow
        let colors: [Color] = [Color(hex: 0xFFF3D6).opacity(fade), Color(hex: 0xFFE2A6).opacity(fade * 0.97), Color(hex: 0xFFD27A).opacity(fade * 0.9)]
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                 with: .radialGradient(Gradient(colors: colors), center: c, startRadius: 0, endRadius: r))
        guard t > 0.5 else { return }
        for i in 0..<14 {
            let a: CGFloat = CGFloat(i) * 0.45
            let u: CGFloat = (t - 0.5) * (0.8 + CGFloat(i % 4) * 0.15)
            let x: CGFloat = c.x + cos(a * 3.1) * 120 * u
            let y: CGFloat = c.y - 160 * u - CGFloat(i % 3) * 12
            let o: Double = Double(max(0, 1 - u * 1.2))
            ctx.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)), with: .color(Palette.bead.opacity(o)))
        }
    }
}
