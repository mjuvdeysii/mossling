import SwiftUI

// MARK: the hidden door between the two worlds
//
// 关于摸索台灯 shows Moss and Otto at the top. Tap them five times (each tap a little crack and a tap of haptics) and
// they shatter: the picture of the two breaks into shards that fall away, a sheet of paper sweeps the screen, and the
// whole app is the 2D world of build 196 — the flat companions, the stickers, the pictures, the shelf, the tabs.
// In the 2D world, keep a finger moving on the two for three seconds without lifting it: a ring of light fills
// round them, and when it closes a warm light blooms from them over the whole screen and the 3D world comes back.

/// What the overlay above the whole app is showing.
@Observable final class StyleShift {
    static let shared = StyleShift()
    enum Phase: Equatable { case idle, shatter(start: Date), bloom(start: Date) }
    var phase: Phase = .idle
    /// The picture that breaks, and where it was on screen.
    var image: UIImage?
    var frame: CGRect = .zero
}

/// Moss and Otto on the 关于 page, as the door.
struct StyleDoor: View {
    let primary: Kind
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.displayScale) private var scale
    @State private var taps = 0
    @State private var lastTap = Date.distantPast
    @State private var frame: CGRect = .zero
    // the way back: how long the finger has been moving, and when it last moved
    @State private var held: Date?
    @State private var lastMove = Date.distantPast
    @State private var progress = 0.0
    @State private var ticks = 0

    private var flat: Bool { app.artStyle == .flat }

    var body: some View {
        Duo(primary: primary, size: 96, poke: false)
            // each tap toward five shows a hairline crack
            .overlay { if !flat && taps >= 2 { Cracks(level: taps).allowsHitTesting(false) } }
            .overlay { if flat && progress > 0 { ProgressHalo(progress: progress).allowsHitTesting(false) } }
            .padding(10)
            .contentShape(Rectangle())
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .onTapGesture { if !flat { tapped() } }
            .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in if flat { moved() } }.onEnded { _ in if flat { reset() } })
            .sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: taps)
            .sensoryFeedback(.selection, trigger: ticks)
            .accessibilityLabel("Moss 和 Otto")
    }

    private func tapped() {
        let now = Date()
        taps = now.timeIntervalSince(lastTap) < 1.2 ? taps + 1 : 1
        lastTap = now
        guard taps >= 5 else { return }
        taps = 0
        shatter()
    }

    private func shatter() {
        StyleShift.shared.image = duoImage()
        StyleShift.shared.frame = frame
        if reduce { app.artStyle = .flat; return }
        StyleShift.shared.phase = .shatter(start: Date())
        // the world changes under the sheet of paper, once the shards have begun to fall
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            app.artStyle = .flat
            try? await Task.sleep(for: .milliseconds(1100))
            StyleShift.shared.phase = .idle
        }
    }

    /// The two as they stand on the page (the same layout as Duo), as one picture to break.
    private func duoImage() -> UIImage? {
        let size: CGFloat = 96, other = primary.other
        let small = Duo.behind(primary, size)
        let lift = size * (1 - Duo.feet(primary)) - small * (1 - Duo.feet(other)) + size * 0.03
        let w = Duo.apart(primary, size) + small, h = max(size, small + lift)
        func sprite(_ k: Kind) -> UIImage? { ArtCache.shared.image("ip_" + (k == .moss ? "moss" : "otto") + "_idle.webp", maxPixel: Int(size * scale)) }
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = scale
        return UIGraphicsImageRenderer(size: CGSize(width: w + 20, height: h + 20), format: fmt).image { _ in
            sprite(other)?.draw(in: CGRect(x: 10 + Duo.apart(primary, size), y: 10 + h - small - lift, width: small, height: small))
            sprite(primary)?.draw(in: CGRect(x: 10, y: 10 + h - size, width: size, height: size))
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

/// Hairline cracks across the two, more with each tap.
private struct Cracks: View {
    let level: Int
    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width * 0.42, y: size.height * 0.55)
            let n = min(9, (level - 1) * 3)
            for i in 0..<n {
                let a = Double(i) / Double(n) * 2 * .pi + 0.4
                var p = Path(); p.move(to: c)
                let m = CGPoint(x: c.x + cos(a) * size.width * 0.18, y: c.y + sin(a) * size.height * 0.16)
                p.addLine(to: m)
                p.addLine(to: CGPoint(x: m.x + cos(a + 0.5) * size.width * 0.14, y: m.y + sin(a + 0.5) * size.height * 0.12))
                ctx.stroke(p, with: .color(.white.opacity(0.9)), lineWidth: 1.2)
                ctx.stroke(p, with: .color(.black.opacity(0.18)), lineWidth: 0.5)
            }
        }
    }
}

/// The ring of light that fills while the finger keeps moving.
private struct ProgressHalo: View {
    let progress: Double
    var body: some View {
        ZStack {
            Circle().stroke(Palette.bead.opacity(0.2), lineWidth: 5)
            Circle().trim(from: 0, to: progress)
                .stroke(AngularGradient(colors: [Palette.beadLight, Palette.bead, Palette.beadLight], center: .center), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Palette.bead.opacity(0.6), radius: 6)
        }
        .padding(-6)
    }
}

/// Above the whole app: the shards falling, the sheet of paper, or the bloom of light.
struct StyleShiftOverlay: View {
    @State private var shift = StyleShift.shared
    var body: some View {
        switch shift.phase {
        case .idle: EmptyView()
        case .shatter(let start): Shatter(start: start, image: shift.image, frame: shift.frame).ignoresSafeArea().allowsHitTesting(false)
        case .bloom(let start): Bloom(start: start, frame: shift.frame).ignoresSafeArea().allowsHitTesting(false)
        }
    }
}

/// The picture breaks into triangular shards that fall, spin and fade; a sheet of warm paper sweeps the screen while
/// the world changes beneath it, then lifts.
private struct Shatter: View {
    let start: Date
    let image: UIImage?
    let frame: CGRect
    private struct Shard { let tri: [CGPoint]; let c: CGPoint; let v: CGVector; let spin: Double }
    private let shards: [Shard]
    init(start: Date, image: UIImage?, frame: CGRect) {
        self.start = start; self.image = image; self.frame = frame
        var g = SystemRandomNumberGenerator(); var out: [Shard] = []
        let n = 6
        for i in 0..<n { for j in 0..<n {
            let x0 = Double(i) / Double(n), y0 = Double(j) / Double(n), d = 1 / Double(n)
            let quads = [CGPoint(x: x0, y: y0), CGPoint(x: x0 + d, y: y0), CGPoint(x: x0 + d, y: y0 + d), CGPoint(x: x0, y: y0 + d)]
            for tri in [[quads[0], quads[1], quads[2]], [quads[0], quads[2], quads[3]]] {
                let c = CGPoint(x: (tri[0].x + tri[1].x + tri[2].x) / 3, y: (tri[0].y + tri[1].y + tri[2].y) / 3)
                let v = CGVector(dx: (c.x - 0.5) * Double.random(in: 180...320, using: &g), dy: -Double.random(in: 60...240, using: &g))
                out.append(Shard(tri: tri, c: c, v: v, spin: Double.random(in: -4...4, using: &g)))
            }
        } }
        shards = out
    }
    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSince(start)
            Canvas { ctx, size in
                // the sheet of paper: in by 0.42 s, out by 1.3 s
                let sheet = t < 0.42 ? t / 0.42 : max(0, 1 - (t - 0.5) / 0.8)
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xFBF7F0).opacity(sheet * 0.96)))
                guard let image, t < 1.4 else { return }
                let img = ctx.resolve(Image(uiImage: image))
                for s in shards {
                    let k = min(1, t / 1.3)
                    let dx = s.v.dx * t, dy = s.v.dy * t + 900 * t * t
                    let cx = frame.minX + s.c.x * frame.width + dx, cy = frame.minY + s.c.y * frame.height + dy
                    var g = ctx
                    g.opacity = 1 - k
                    g.translateBy(x: cx, y: cy); g.rotate(by: .radians(s.spin * t)); g.translateBy(x: -s.c.x * frame.width, y: -s.c.y * frame.height)
                    var p = Path(); p.move(to: CGPoint(x: s.tri[0].x * frame.width, y: s.tri[0].y * frame.height))
                    p.addLine(to: CGPoint(x: s.tri[1].x * frame.width, y: s.tri[1].y * frame.height))
                    p.addLine(to: CGPoint(x: s.tri[2].x * frame.width, y: s.tri[2].y * frame.height)); p.closeSubpath()
                    g.clip(to: p)
                    g.draw(img, in: CGRect(origin: .zero, size: frame.size))
                    g.stroke(p, with: .color(.white.opacity(0.7)), lineWidth: 0.8)
                }
            }
        }
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
            Canvas { ctx, size in
                let c = CGPoint(x: frame.midX, y: frame.midY)
                let far = hypot(max(c.x, size.width - c.x), max(c.y, size.height - c.y))
                let grow = min(1, t / 0.48), fade = t < 0.5 ? 1 : max(0, 1 - (t - 0.5) / 0.8)
                let r = 40 + (far + 80) * grow * grow
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                         with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF3D6).opacity(fade), Color(hex: 0xFFE2A6).opacity(fade * 0.97), Color(hex: 0xFFD27A).opacity(fade * 0.9)]),
                                               center: c, startRadius: 0, endRadius: r))
                guard t > 0.5 else { return }
                for i in 0..<14 {
                    let a = Double(i) * 0.45, u = (t - 0.5) * (0.8 + Double(i % 4) * 0.15)
                    let p = CGPoint(x: c.x + cos(a * 3.1) * 40 * u * 3, y: c.y - 160 * u - Double(i % 3) * 12)
                    let o = max(0, 1 - u * 1.2)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)), with: .color(Palette.bead.opacity(o)))
                }
            }
        }
    }
}
