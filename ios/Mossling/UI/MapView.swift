import SwiftUI

/// The growth map, drawn like a map in a picture book: a sandy path winds down through three lands — the meadow of the
/// first year, the wooded hills of the second, the river village of the third — with a stepping stone for every month
/// and a signpost beside it. The companions stand at the child's stone. Past the last stone the path goes on.
struct JourneyView: View {
    @Environment(AppModel.self) private var app
    @Binding var path: NavigationPath

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0...36, id: \.self) { m in
                        if m % 12 == 0 { LandGate(land: Land.of(m), first: m == 0) }
                        NavigationLink(value: Route.month(m)) { Stop(month: m) }
                            .buttonStyle(.toy).zoomSource(Route.month(m)).id(m)
                    }
                    Horizon(primary: app.companion)
                }
            }
            .background(Land.of(app.babyMonth ?? 0).ground)
            .navigationTitle("成长地图")
            .navigationSubtitle("0–36 个月 · 一个月一站")
            .toolbar {
                if let b = app.babyMonth {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("宝宝在这里", systemImage: "location.fill") { withAnimation(.snappy) { proxy.scrollTo(b, anchor: .center) } }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) { NavigationLink(value: Route.search) { Image(systemName: "magnifyingglass") }.accessibilityLabel("搜索") }
            }
            .onAppear { if let b = app.babyMonth { proxy.scrollTo(b, anchor: .center) } }
        }
    }
}

/// Where the stone of month m lies across the map: left and right in turn, the path swinging between them.
private func stoneX(_ m: Int) -> CGFloat { m % 2 == 0 ? 0.3 : 0.7 }

/// Draws the ground of one strip of the map: the land's colour, a few things growing or standing in it, the path.
private struct Ground: View {
    let land: Land
    let seed: Int
    /// The path's x at the top, the middle and the bottom of the strip, as fractions of the width.
    let top: CGFloat, mid: CGFloat, bottom: CGFloat
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas { ctx, size in paint(&ctx, size) }
            .accessibilityHidden(true)
    }

    private func printed(_ ctx: inout GraphicsContext, _ p: Path, _ fill: Color, _ deep: Color) {
        ctx.fill(p.offsetBy(dx: 1.6, dy: 2), with: .color(deep)); ctx.fill(p, with: .color(fill))
    }

    /// A ball lit from the upper left, for canopies and flower hearts.
    private func ball(_ ctx: inout GraphicsContext, _ r: CGRect, _ c: Color) {
        ctx.fill(Path(ellipseIn: r), with: .radialGradient(Gradient(colors: [c.mix(with: .white, by: 0.35), c, c.mix(with: .black, by: 0.25)]),
                                                           center: CGPoint(x: r.minX + r.width * 0.32, y: r.minY + r.height * 0.28), startRadius: 0, endRadius: r.width * 0.75))
    }
    private func softShadow(_ ctx: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat) {
        ctx.fill(Path(ellipseIn: CGRect(x: x - w / 2, y: y - 2.5, width: w, height: 5)), with: .color(Color.black.opacity(0.12)))
    }
    private func flower(_ ctx: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ c: Color, _ dark: Bool, small: Bool = false) {
        let k: CGFloat = small ? 0.7 : 1
        var stem = Path(); stem.move(to: CGPoint(x: x, y: y + 2)); stem.addLine(to: CGPoint(x: x, y: y + 12 * k))
        ctx.stroke(stem, with: .color(Color(hex: 0x5C9A4A)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        for a in stride(from: CGFloat(0), to: 360, by: 72) {
            let r: CGFloat = a * .pi / 180
            let px: CGFloat = x + cos(r) * 4.2 * k, py: CGFloat = y + sin(r) * 4.2 * k
            ball(&ctx, CGRect(x: px - 3.4 * k, y: py - 3.4 * k, width: 6.8 * k, height: 6.8 * k), c.opacity(dark ? 0.8 : 1))
        }
        ball(&ctx, CGRect(x: x - 2.4 * k, y: y - 2.4 * k, width: 4.8 * k, height: 4.8 * k), Crayon.sunflower)
    }
    private func tree(_ ctx: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ dark: Bool, k: CGFloat) {
        softShadow(&ctx, x, y + 14 * k, 28 * k)
        ctx.fill(Path(roundedRect: CGRect(x: x - 2.5 * k, y: y - 2 * k, width: 5 * k, height: 16 * k), cornerRadius: 2), with: .linearGradient(Gradient(colors: [Color(hex: 0xB98A55), Color(hex: 0x8A6236)]), startPoint: CGPoint(x: x - 3, y: y), endPoint: CGPoint(x: x + 3, y: y)))
        let leaf = dark ? Color(hex: 0x4E8A55) : Color(hex: 0x6DBA5E)
        ball(&ctx, CGRect(x: x - 15 * k, y: y - 16 * k, width: 20 * k, height: 20 * k), leaf.mix(with: .black, by: 0.08))
        ball(&ctx, CGRect(x: x - 4 * k, y: y - 14 * k, width: 19 * k, height: 19 * k), leaf.mix(with: .black, by: 0.04))
        ball(&ctx, CGRect(x: x - 11 * k, y: y - 28 * k, width: 22 * k, height: 22 * k), leaf)
    }
    /// A little wooden toy house: a pastel body, a crisp roof with eaves, a chimney, a lit window with its cross, a door.
    private func house(_ ctx: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ dark: Bool, roof: Color) {
        softShadow(&ctx, x, y + 11, 36)
        let wallColor = roof.mix(with: .white, by: dark ? 0.55 : 0.78)
        let wall = CGRect(x: x - 12, y: y - 8, width: 24, height: 19)
        ctx.fill(Path(roundedRect: wall, cornerRadius: 2.5), with: .linearGradient(Gradient(colors: [wallColor, wallColor.mix(with: .black, by: 0.08)]), startPoint: CGPoint(x: wall.minX, y: wall.minY), endPoint: CGPoint(x: wall.maxX, y: wall.maxY)))
        // chimney behind the roof
        ctx.fill(Path(roundedRect: CGRect(x: x + 5, y: y - 21, width: 5, height: 9), cornerRadius: 1), with: .color(Color(hex: 0xB97A55)))
        var r = Path()
        r.move(to: CGPoint(x: x - 16, y: y - 7)); r.addLine(to: CGPoint(x: x, y: y - 21)); r.addLine(to: CGPoint(x: x + 16, y: y - 7)); r.closeSubpath()
        ctx.fill(r, with: .linearGradient(Gradient(colors: [roof.mix(with: .white, by: 0.2), roof, roof.mix(with: .black, by: 0.2)]), startPoint: CGPoint(x: x - 12, y: y - 20), endPoint: CGPoint(x: x + 14, y: y - 6)))
        var eave = Path(); eave.move(to: CGPoint(x: x - 16, y: y - 7)); eave.addLine(to: CGPoint(x: x + 16, y: y - 7))
        ctx.stroke(eave, with: .color(roof.mix(with: .black, by: 0.3)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        let win = CGRect(x: x - 8.5, y: y - 3, width: 7, height: 7)
        ctx.fill(Path(roundedRect: win, cornerRadius: 1.5), with: .color(Color(hex: 0xFFE08A)))
        var cross = Path(); cross.move(to: CGPoint(x: win.midX, y: win.minY)); cross.addLine(to: CGPoint(x: win.midX, y: win.maxY))
        cross.move(to: CGPoint(x: win.minX, y: win.midY)); cross.addLine(to: CGPoint(x: win.maxX, y: win.midY))
        ctx.stroke(cross, with: .color(.white.opacity(0.9)), lineWidth: 0.9)
        ctx.stroke(Path(roundedRect: win, cornerRadius: 1.5), with: .color(.white), lineWidth: 1)
        var door = Path(roundedRect: CGRect(x: x + 2.5, y: y + 0.5, width: 6.5, height: 10.5), cornerRadii: RectangleCornerRadii(topLeading: 3.2, bottomLeading: 0, bottomTrailing: 0, topTrailing: 3.2))
        door = door.offsetBy(dx: 0, dy: 0)
        ctx.fill(door, with: .linearGradient(Gradient(colors: [roof.mix(with: .black, by: 0.05), roof.mix(with: .black, by: 0.3)]), startPoint: CGPoint(x: x + 3, y: y), endPoint: CGPoint(x: x + 9, y: y + 11)))
    }

    private func paint(_ ctx: inout GraphicsContext, _ size: CGSize) {
            let w: CGFloat = size.width, h: CGFloat = size.height
            let dark: Bool = scheme == .dark
            // things in the land, kept to the edges and away from the path
            var rng = SplitMix(seed: UInt64(seed * 7919 + 13))
            let away: CGFloat = mid < 0.5 ? 0.08 : 0.92
            for k in 0..<3 {
                let fx: CGFloat = k == 0 ? away : rng.next(0.04...0.96)
                let x: CGFloat = w * fx
                let y: CGFloat = h * rng.next(0.15...0.9)
                let nearPath: Bool = abs(fx - mid) < 0.22
                let nearSign: Bool = k > 0 && abs(fx - (1 - mid)) < 0.18
                if nearPath || nearSign { continue }
                switch land {
                case .meadow:
                    let pick: Int = Int(rng.next(0...3.99))
                    let petals: Color = [Crayon.pink, Crayon.sunflower, Crayon.peach, Crayon.sky][pick]
                    flower(&ctx, x, y, petals, dark)
                    flower(&ctx, x + 12, y + 6, [Crayon.lilac, Crayon.pink, Crayon.sunflower, Crayon.mint][pick], dark, small: true)
                case .forest:
                    tree(&ctx, x, y, dark, k: rng.next(0.8...1.15))
                case .river:
                    house(&ctx, x, y, dark, roof: [Crayon.cherry, Crayon.sky, Crayon.peach, Crayon.lilac][Int(rng.next(0...3.99))])
                }
            }
            if land == .river && seed % 6 == 3 {
                // the stream crosses under a little bridge
                var river = Path()
                river.move(to: CGPoint(x: 0, y: h * 0.62)); river.addCurve(to: CGPoint(x: w, y: h * 0.7), control1: CGPoint(x: w * 0.35, y: h * 0.45), control2: CGPoint(x: w * 0.65, y: h * 0.9))
                ctx.stroke(river, with: .color(Crayon.sky.opacity(dark ? 0.5 : 0.55)), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                ctx.stroke(river, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [8, 10]))
            }
            // the path
            var road = Path()
            road.move(to: CGPoint(x: w * top, y: 0))
            road.addCurve(to: CGPoint(x: w * mid, y: h / 2), control1: CGPoint(x: w * top, y: h * 0.25), control2: CGPoint(x: w * mid, y: h * 0.25))
            road.addCurve(to: CGPoint(x: w * bottom, y: h), control1: CGPoint(x: w * mid, y: h * 0.75), control2: CGPoint(x: w * bottom, y: h * 0.75))
            ctx.stroke(road.offsetBy(dx: 0, dy: 3), with: .color(Color.black.opacity(dark ? 0.3 : 0.08)), style: StrokeStyle(lineWidth: 24, lineCap: .round))
            ctx.stroke(road, with: .color(dark ? Color(hex: 0x6B5B45) : Color(hex: 0xEBD3A2)), style: StrokeStyle(lineWidth: 24, lineCap: .round))
            ctx.stroke(road.offsetBy(dx: -1, dy: -1.5), with: .color(dark ? Color(hex: 0x7C6A52) : Color(hex: 0xF8E8C6)), style: StrokeStyle(lineWidth: 16, lineCap: .round))
            ctx.stroke(road, with: .color(dark ? Color.white.opacity(0.25) : Color.white.opacity(0.8)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 9]))
    }
}

/// A deterministic random number generator, so the map looks the same every time.
private struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func nextUInt() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    mutating func next(_ r: ClosedRange<Double>) -> CGFloat { CGFloat(r.lowerBound + (r.upperBound - r.lowerBound) * Double(nextUInt() % 10_000) / 10_000) }
}

/// One month on the map: its stone on the path and its signpost on the other side.
private struct Stop: View {
    @Environment(AppModel.self) private var app
    let month: Int
    @ScaledMetric private var height: CGFloat = 132

    var body: some View {
        let mo = app.content.month(month)
        let land = Land.of(month)
        let here = app.babyMonth == month, past = (app.babyMonth ?? -1) > month
        let x = stoneX(month)
        let done = app.count(month, TickKind.did)
        let care = !mo.vaccines.isEmpty || !mo.checkups.isEmpty
        GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .topLeading) {
                Ground(land: land, seed: month, top: 0.5, mid: x, bottom: 0.5)
                Bead(month: month, here: here, past: past)
                    .position(x: w * x, y: g.size.height / 2)
                if here {
                    Duo(primary: app.companion, size: 58, look: CGPoint(x: x < 0.5 ? 0.8 : -0.8, y: 0.2))
                        .position(x: w * x + (x < 0.5 ? -46 : 46), y: g.size.height / 2 - 26)
                }
                // the signpost
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(month == 0 ? "出生" : "满 \(month) 个月").font(.subheadline.weight(.bold))
                        if month == 12 || month == 24 || month == 36 { Image(systemName: "birthday.cake.fill").font(.caption).foregroundStyle(Crayon.rose) }
                    }
                    Text(mo.title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    if done > 0 || care {
                        HStack(spacing: 6) {
                            if done > 0 { IconTile(symbol: "puzzlepiece.fill", color: Crayon.leaf, size: 18); Text("\(done)").font(.caption2.weight(.bold)).monospacedDigit() }
                            if care { IconTile(symbol: "syringe.fill", color: Crayon.pink, size: 18) }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .frame(width: w * 0.46, alignment: .leading)
                .printCard(radius: 16, fill: here ? Color.dyn(0xFFF4D6, 0x3A3018) : Palette.card)
                .position(x: x < 0.5 ? w * 0.74 : w * 0.26, y: g.size.height / 2)
            }
        }
        .frame(height: height)
        .background(land.ground)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((month == 0 ? "出生" : "满 \(month) 个月") + "，\(mo.title)" + (here ? "，宝宝在这里" : "") + (done > 0 ? "，做过 \(done) 个活动" : ""))
        .accessibilityAddTraits(.isButton)
    }
}

/// Where one land begins: the path runs on straight past a wooden sign with the land's name and the year.
private struct LandGate: View {
    let land: Land
    let first: Bool
    var body: some View {
        ZStack {
            Ground(land: land, seed: 100 + land.rawValue, top: 0.5, mid: 0.5, bottom: 0.5)
                .mask(LinearGradient(colors: first ? [.clear, .black] : [.black, .black], startPoint: .top, endPoint: .center))
            HStack(spacing: 8) {
                Image(systemName: land.symbol).foregroundStyle(land.crayon)
                Text(land.name).font(.headline)
                Text(land.years).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .printCard(radius: 18, fill: Color.dyn(0xF5E9D6, 0x2B241C))
            .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
        }
        .frame(height: 92)
        .background(land.ground)
    }
}

/// Past the last stone: the path goes on to the horizon, and the two walk on along it.
private struct Horizon: View {
    let primary: Kind
    var body: some View {
        VStack(spacing: 0) {
            Ground(land: .river, seed: 99, top: 0.5, mid: 0.5, bottom: 0.5)
                .frame(height: 70)
                .mask(LinearGradient(colors: [.black, .black.opacity(0.2)], startPoint: .top, endPoint: .bottom))
            StoryGoesOn(primary: primary).padding(.horizontal, 16).padding(.bottom, 40)
        }
        .background(Land.river.ground)
    }
}
