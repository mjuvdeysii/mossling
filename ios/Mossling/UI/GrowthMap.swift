import SwiftUI

/// The growth map: one landscape, one path. The three years are three hills one behind the other — 草地 (birth to 1)
/// in front, 森林小丘 (1 to 2) behind it, 小河村庄 (2 to 3) far away under the sky — and the path of 37 stepping
/// stones climbs from the meadow at the foot of the card to the village at the top: growing up is walking on, toward
/// the far hills. Moss stands on the month being looked at, at that month's size (his sprig grows with him); Otto
/// stands by the child's own month with his lamp. Run a finger along the path and Moss hops from stone to stone; the
/// page below follows when the finger lifts.
///
/// Two worlds, one map. 立体 (vinyl): the hills are soft lit forms with a rim of light along each crest and a soft
/// shadow under it, the path a raised road, the stones glossy beads. 平面 (paper): every hill is a sheet of cut paper
/// with a crisp darker edge under it, the path a stitched ribbon, the stones flat discs with a white rim, grain on all.
/// At night the hills go blue under the stars, the lived stones glow, and on the child's own month there is a small
/// house with a lit window: the child is home asleep, and Otto's lamp comes on for a moment and goes out.
enum MapGeo {
    static let height: CGFloat = 350
    static let rows: [CGFloat] = [296, 192, 88]          // the stones' line on each hill: year 1, 2, 3
    static let margin: CGFloat = 30
    static func row(_ m: Int) -> Int { m <= 12 ? 0 : m <= 24 ? 1 : 2 }
    static func col(_ m: Int) -> Int { m <= 12 ? m : m <= 24 ? 12 - (m - 13) : 1 + (m - 25) }
    static func point(_ m: Int, width w: CGFloat) -> CGPoint {
        let step = (w - 2 * margin) / 12
        return CGPoint(x: margin + CGFloat(col(m)) * step, y: rows[row(m)])
    }
    /// The stone nearest a touch (rows weigh more than columns, so a finger a little off the path stays on its row).
    static func month(near p: CGPoint, width w: CGFloat) -> Int {
        (0...36).min { a, b in
            let pa = point(a, width: w), pb = point(b, width: w)
            return hypot(pa.x - p.x, (pa.y - p.y) * 1.8) < hypot(pb.x - p.x, (pb.y - p.y) * 1.8)
        } ?? 0
    }
    /// Which way Moss walks on a row: on, then back, then on.
    static func facing(_ m: Int) -> CGFloat { row(m) == 1 ? -1 : 1 }
    /// Where each hill's crest runs (the line between one year's land and the next behind it).
    static func crest(_ band: Int) -> CGFloat { rows[band] - 62 }
    static let marks: [(Int, String)] = [(0, "出生"), (12, "1 岁"), (24, "2 岁"), (36, "3 岁")]
}

/// The palette of a hill, by day and by night, in either world.
private struct Hill {
    let top: Color, base: Color, edge: Color, road: Color
    static func of(_ band: Int, night: Bool) -> Hill {
        if night {
            switch band {
            case 0: return Hill(top: Color(hex: 0x23345A), base: Color(hex: 0x1A2747), edge: Color(hex: 0x111A33), road: Color(hex: 0x34446E))
            case 1: return Hill(top: Color(hex: 0x1E2D52), base: Color(hex: 0x172240), edge: Color(hex: 0x0F172E), road: Color(hex: 0x2F3E66))
            default: return Hill(top: Color(hex: 0x1B2849), base: Color(hex: 0x151F3B), edge: Color(hex: 0x0D152A), road: Color(hex: 0x2B395F))
            }
        }
        switch band {
        case 0: return Hill(top: Color(hex: 0xBFE6A6), base: Color(hex: 0x95CF7E), edge: Color(hex: 0x6FAE5C), road: Color(hex: 0xFFF6E2))
        case 1: return Hill(top: Color(hex: 0xF6DDAE), base: Color(hex: 0xEBC386), edge: Color(hex: 0xC99A5A), road: Color(hex: 0xFFF8EA))
        default: return Hill(top: Color(hex: 0xD3E9E4), base: Color(hex: 0xB6D9D3), edge: Color(hex: 0x86B5AE), road: Color(hex: 0xFBFBF4))
        }
    }
}

/// The landscape, the path and the stones: drawn once for a width, a world, a time of day and the child's month
/// (nothing in it moves; Moss, Otto and the chosen ring move over it).
struct MapLand: View, Equatable {
    let baby: Int
    let night: Bool
    let flat: Bool
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            sky(&ctx, size)
            for band in [2, 1, 0] { hill(&ctx, band, w, size.height) }
            decor(&ctx, w)
            road(&ctx, w)
            stones(&ctx, w)
            marks(&ctx, w)
        }
        .overlay { if flat { Grain(dark: night, strength: 0.9).blendMode(.multiply).allowsHitTesting(false) } }
        .accessibilityHidden(true)
    }

    // MARK: sky
    private func sky(_ ctx: inout GraphicsContext, _ s: CGSize) {
        let r = CGRect(origin: .zero, size: s)
        let top = night ? Color(hex: 0x0E1430) : Color(hex: 0xBFE2F6), low = night ? Color(hex: 0x1D2A55) : Color(hex: 0xEAF6F2)
        if flat { ctx.fill(Path(r), with: .color(top.mix(with: low, by: 0.45))) }
        else { ctx.fill(Path(r), with: .linearGradient(Gradient(colors: [top, low]), startPoint: .zero, endPoint: CGPoint(x: 0, y: 80))) }
        let sun = CGPoint(x: s.width - 46, y: 14)
        if night {
            // the moon and a few stars, high over the far village
            ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 11, y: sun.y - 9, width: 22, height: 22)), with: .color(Color(hex: 0xFFF1C9)))
            ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 4, y: sun.y - 13, width: 22, height: 22)), with: .color(top.mix(with: low, by: flat ? 0.45 : 0.1)))
            for (i, p) in [(0.12, 0.02), (0.3, 0.05), (0.47, 0.015), (0.63, 0.045), (0.8, 0.03), (0.22, 0.09), (0.55, 0.085)].enumerated() {
                let q = CGPoint(x: s.width * p.0, y: s.height * p.1 + 4), r: CGFloat = i % 3 == 0 ? 1.8 : 1.2
                ctx.fill(Path(ellipseIn: CGRect(x: q.x - r, y: q.y - r, width: 2 * r, height: 2 * r)), with: .color(.white.opacity(0.85)))
            }
        } else if flat {
            ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 13, y: sun.y - 13, width: 26, height: 26)), with: .color(Color(hex: 0xFFD45E)))
            for k in 0..<8 {
                let a = Double(k) / 8 * 2 * .pi
                var p = Path()
                p.move(to: CGPoint(x: sun.x + cos(a) * 17, y: sun.y + sin(a) * 17))
                p.addLine(to: CGPoint(x: sun.x + cos(a + 0.12) * 23, y: sun.y + sin(a + 0.12) * 23))
                p.addLine(to: CGPoint(x: sun.x + cos(a - 0.12) * 23, y: sun.y + sin(a - 0.12) * 23))
                ctx.fill(p, with: .color(Color(hex: 0xFFD45E).opacity(0.8)))
            }
        } else {
            ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 40, y: sun.y - 40, width: 80, height: 80)),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF2B8), Color(hex: 0xFFE7A0).opacity(0)]), center: sun, startRadius: 8, endRadius: 40))
            ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 13, y: sun.y - 13, width: 26, height: 26)),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF6CF), Color(hex: 0xFFCF4A)]), center: CGPoint(x: sun.x - 4, y: sun.y - 5), startRadius: 0, endRadius: 16))
        }
        // two small clouds by day
        if !night {
            for (cx, cy, k) in [(0.2, 16.0, 1.0), (0.58, 9.0, 0.8)] {
                let c = CGPoint(x: s.width * cx, y: cy)
                var p = Path()
                for (dx, dy, r) in [(-12.0, 3.0, 8.0), (0.0, -1.0, 11.0), (13.0, 3.0, 8.0)] {
                    p.addEllipse(in: CGRect(x: c.x + dx * k - r * k, y: c.y + dy * k - r * k, width: 2 * r * k, height: 2 * r * k))
                }
                p.addRoundedRect(in: CGRect(x: c.x - 20 * k, y: c.y, width: 40 * k, height: 10 * k), cornerSize: CGSize(width: 5 * k, height: 5 * k))
                ctx.fill(p, with: .color(.white.opacity(flat ? 1 : 0.92)))
            }
        }
    }

    // MARK: hills
    private func hillPath(_ band: Int, _ w: CGFloat, _ h: CGFloat) -> Path {
        let y0 = MapGeo.crest(band)
        // a slow rolling crest, different for each hill
        let a: CGFloat = [10, 13, 9][band], ph: CGFloat = [0.6, 2.1, 4.0][band]
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h))
        p.addLine(to: CGPoint(x: 0, y: y0 + a * CGFloat(Foundation.sin(Double(ph)))))
        let n = 24
        for i in 1...n {
            let x = w * CGFloat(i) / CGFloat(n)
            let y = y0 + a * CGFloat(Foundation.sin(Double(ph) + Double(i) / Double(n) * 2.6 * .pi * 0.5 + Double(band)))
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: w, y: h)); p.closeSubpath()
        return p
    }
    private func hill(_ ctx: inout GraphicsContext, _ band: Int, _ w: CGFloat, _ h: CGFloat) {
        let c = Hill.of(band, night: night)
        let p = hillPath(band, w, h)
        let y0 = MapGeo.crest(band)
        if flat {
            // a sheet of cut paper: its darker edge shows a little below it, then the sheet itself in one colour
            ctx.fill(p.offsetBy(dx: 0, dy: -3), with: .color(c.edge))
            ctx.fill(p, with: .color(c.top.mix(with: c.base, by: 0.35)))
        } else {
            // a soft lit form: a shadow cast on the hill behind, lit at the crest, deeper toward its foot
            var sh = ctx; sh.addFilter(.blur(radius: 7))
            sh.fill(p.offsetBy(dx: 0, dy: -5), with: .color(.black.opacity(night ? 0.3 : 0.12)))
            ctx.fill(p, with: .linearGradient(Gradient(colors: [c.top.mix(with: .white, by: night ? 0.04 : 0.28), c.top, c.base, c.base.mix(with: .black, by: night ? 0.1 : 0.06)]),
                                             startPoint: CGPoint(x: 0, y: y0 - 12), endPoint: CGPoint(x: 0, y: y0 + 108)))
            var rim = ctx; rim.clip(to: p)
            rim.stroke(p.offsetBy(dx: 0, dy: 1.5), with: .color(.white.opacity(night ? 0.12 : 0.6)), lineWidth: 2)
        }
    }

    // MARK: the things of each land, in the strip under its path (never where Moss stands)
    private func decor(_ ctx: inout GraphicsContext, _ w: CGFloat) {
        let step = (w - 2 * MapGeo.margin) / 12
        func free(_ x: CGFloat, _ band: Int) -> Bool {
            // keep clear of the year marks under the stones
            for (m, _) in MapGeo.marks where MapGeo.row(m) == band { if abs(MapGeo.point(m, width: w).x - x) < 26 { return false } }
            return x > 14 && x < w - 14
        }
        // 草地: tufts of grass and small flowers
        let y0 = MapGeo.rows[0] + 26
        for i in 0..<12 {
            let x = MapGeo.margin + step * (CGFloat(i) + 0.5)
            guard free(x, 0) else { continue }
            if i % 3 == 1 { flower(&ctx, CGPoint(x: x, y: y0 + CGFloat(i % 2) * 4), [Crayon.pink, Crayon.sunflower, Crayon.lilac][i % 3]) }
            else { tuft(&ctx, CGPoint(x: x, y: y0 + 6), Hill.of(0, night: night).edge) }
        }
        // 森林小丘: little round trees
        let y1 = MapGeo.rows[1] + 34
        for i in stride(from: 0, to: 12, by: 2) {
            let x = MapGeo.margin + step * (CGFloat(i) + 1.0)
            guard free(x, 1) else { continue }
            tree(&ctx, CGPoint(x: x, y: y1), i % 4 == 0 ? 1 : 0.85)
        }
        // 小河村庄: the river under the far path, and small houses along it
        let y2 = MapGeo.rows[2] + 24
        var river = Path()
        river.move(to: CGPoint(x: 0, y: y2 + 4))
        river.addCurve(to: CGPoint(x: w, y: y2 + 2), control1: CGPoint(x: w * 0.3, y: y2 - 8), control2: CGPoint(x: w * 0.65, y: y2 + 14))
        ctx.stroke(river, with: .color(night ? Color(hex: 0x3E5A8E) : Color(hex: 0x8FCBEA)), style: StrokeStyle(lineWidth: flat ? 7 : 8, lineCap: .round))
        if !flat { ctx.stroke(river.offsetBy(dx: 0, dy: -1.5), with: .color(.white.opacity(night ? 0.15 : 0.55)), lineWidth: 1.5) }
        for (i, f) in [0.18, 0.47, 0.76].enumerated() {
            let x = w * f
            guard free(x, 2) else { continue }
            house(&ctx, CGPoint(x: x, y: y2 + 22), [Crayon.cherry, Crayon.tangerine, Crayon.sky][i], lit: night, k: 0.62)
        }
    }
    private func tuft(_ ctx: inout GraphicsContext, _ p: CGPoint, _ c: Color) {
        var t = Path()
        for dx in [-4.0, 0.0, 4.0] {
            t.move(to: CGPoint(x: p.x + dx, y: p.y)); t.addQuadCurve(to: CGPoint(x: p.x + dx * 1.6, y: p.y - 8 + abs(dx)), control: CGPoint(x: p.x + dx * 0.4, y: p.y - 5))
        }
        ctx.stroke(t, with: .color(c.opacity(0.8)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }
    private func flower(_ ctx: inout GraphicsContext, _ p: CGPoint, _ c: Color) {
        var stem = Path(); stem.move(to: CGPoint(x: p.x, y: p.y + 6)); stem.addLine(to: CGPoint(x: p.x, y: p.y - 3))
        ctx.stroke(stem, with: .color(Hill.of(0, night: night).edge), lineWidth: 1.4)
        let col = night ? c.mix(with: Color(hex: 0x1A2747), by: 0.55) : c
        for k in 0..<5 {
            let a = Double(k) / 5 * 2 * .pi
            let q = CGPoint(x: p.x + cos(a) * 3.2, y: p.y - 5 + sin(a) * 3.2)
            ctx.fill(Path(ellipseIn: CGRect(x: q.x - 2.4, y: q.y - 2.4, width: 4.8, height: 4.8)), with: .color(col))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - 1.6, y: p.y - 6.6, width: 3.2, height: 3.2)), with: .color(night ? Color(hex: 0x8A7A3A) : Color(hex: 0xFFC23D)))
    }
    private func tree(_ ctx: inout GraphicsContext, _ base: CGPoint, _ k: CGFloat) {
        let trunk = CGRect(x: base.x - 2 * k, y: base.y - 9 * k, width: 4 * k, height: 9 * k)
        ctx.fill(Path(roundedRect: trunk, cornerRadius: 2), with: .color(night ? Color(hex: 0x2A2A40) : Color(hex: 0xA8754A)))
        let c = CGPoint(x: base.x, y: base.y - 17 * k), r = 10 * k
        let leaf = night ? Color(hex: 0x24395A) : Color(hex: 0x7CC27A)
        let crown = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        if flat {
            ctx.fill(crown.offsetBy(dx: 0, dy: 1.5), with: .color(leaf.mix(with: .black, by: 0.25)))
            ctx.fill(crown, with: .color(leaf))
        } else {
            ctx.fill(crown, with: .radialGradient(Gradient(colors: [leaf.mix(with: .white, by: 0.3), leaf, leaf.mix(with: .black, by: 0.2)]),
                                                  center: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.4), startRadius: 0, endRadius: r * 1.5))
        }
    }
    private func house(_ ctx: inout GraphicsContext, _ base: CGPoint, _ roof: Color, lit: Bool, k: CGFloat) {
        let wall = CGRect(x: base.x - 9 * k, y: base.y - 14 * k, width: 18 * k, height: 14 * k)
        let wallC = night ? Color(hex: 0x3A4670) : Color(hex: 0xFFF6E6)
        ctx.fill(Path(roundedRect: wall, cornerRadius: 2 * k), with: .color(wallC))
        var r = Path()
        r.move(to: CGPoint(x: base.x - 12 * k, y: base.y - 13 * k)); r.addLine(to: CGPoint(x: base.x, y: base.y - 24 * k))
        r.addLine(to: CGPoint(x: base.x + 12 * k, y: base.y - 13 * k)); r.closeSubpath()
        ctx.fill(r, with: .color(night ? roof.mix(with: Color(hex: 0x1A2747), by: 0.55) : roof))
        let win = CGRect(x: base.x - 3 * k, y: base.y - 10 * k, width: 6 * k, height: 6 * k)
        ctx.fill(Path(roundedRect: win, cornerRadius: 1.2 * k), with: .color(lit ? Palette.amber : Color(hex: 0x8FCBEA)))
    }

    // MARK: the path
    private func roadPath(_ w: CGFloat, from a: Int, to b: Int) -> Path {
        var p = Path()
        p.move(to: MapGeo.point(a, width: w))
        guard b > a else { return p }
        for m in a..<b {
            let pa = MapGeo.point(m, width: w), pb = MapGeo.point(m + 1, width: w)
            if pa.y == pb.y { p.addLine(to: pb) }
            else {
                let out: CGFloat = m == 12 ? 24 : -24
                p.addCurve(to: pb, control1: CGPoint(x: pa.x + out, y: pa.y), control2: CGPoint(x: pb.x + out, y: pb.y))
            }
        }
        return p
    }
    private func road(_ ctx: inout GraphicsContext, _ w: CGFloat) {
        let all = roadPath(w, from: 0, to: 36)
        let lived = roadPath(w, from: 0, to: max(0, baby))
        let roadC = night ? Hill.of(0, night: true).road : Color(hex: 0xFFF6E2)
        let livedC = night ? Palette.amber.opacity(0.55) : Color(hex: 0xFFE3A3)
        if flat {
            // a ribbon of paper with a stitch along it
            ctx.stroke(all.offsetBy(dx: 0, dy: 2), with: .color(.black.opacity(night ? 0.3 : 0.12)), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
            ctx.stroke(all, with: .color(roadC), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
            ctx.stroke(lived, with: .color(livedC), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
            ctx.stroke(all, with: .color(night ? Color.white.opacity(0.25) : Color(hex: 0xD9B98A)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [3, 4]))
        } else {
            // a raised soft road: its shadow, the road, a lit edge on top
            var sh = ctx; sh.addFilter(.blur(radius: 3))
            sh.stroke(all.offsetBy(dx: 0, dy: 3), with: .color(.black.opacity(night ? 0.35 : 0.14)), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
            ctx.stroke(all, with: .color(roadC), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
            ctx.stroke(lived, with: .color(livedC), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
            ctx.stroke(all.offsetBy(dx: 0, dy: -2.5), with: .color(.white.opacity(night ? 0.1 : 0.7)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        // after three years the path runs on, dotted (the story goes on)
        let end = MapGeo.point(36, width: w)
        var tail = Path(); tail.move(to: CGPoint(x: end.x + 10, y: end.y))
        tail.addQuadCurve(to: CGPoint(x: w - 4, y: end.y - 16), control: CGPoint(x: w - 6, y: end.y))
        ctx.stroke(tail, with: .color(night ? .white.opacity(0.4) : Color(hex: 0xC99A5A).opacity(0.8)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 5]))
    }

    // MARK: stones
    private func stones(_ ctx: inout GraphicsContext, _ w: CGFloat) {
        for m in 0...36 {
            let p = MapGeo.point(m, width: w)
            let here = m == baby, lived = m < baby
            let d: CGFloat = here ? 18 : (m % 12 == 0 ? 14 : 12)
            let r = CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)
            let c = here ? Palette.bead : Land.of(min(35, m)).crayon
            let fill = lived || here ? c : (night ? Color(hex: 0x2B385F) : .white)
            if night && (lived || here) {
                ctx.fill(Path(ellipseIn: r.insetBy(dx: -6, dy: -6)), with: .radialGradient(Gradient(colors: [Palette.amber.opacity(here ? 0.5 : 0.22), .clear]), center: p, startRadius: 0, endRadius: d))
            }
            if flat {
                ctx.fill(Path(ellipseIn: r.offsetBy(dx: 0, dy: 1.5)), with: .color(.black.opacity(night ? 0.35 : 0.16)))
                ctx.fill(Path(ellipseIn: r), with: .color(fill))
                ctx.stroke(Path(ellipseIn: r.insetBy(dx: 0.8, dy: 0.8)), with: .color(lived || here ? .white : c.opacity(0.75)), lineWidth: lived || here ? 1.6 : 1.4)
            } else {
                ctx.fill(Path(ellipseIn: r.offsetBy(dx: 0, dy: 2)), with: .color(.black.opacity(night ? 0.35 : 0.16)))
                if lived || here {
                    ctx.fill(Path(ellipseIn: r), with: .radialGradient(Gradient(colors: [c.mix(with: .white, by: 0.45), c, c.mix(with: .black, by: 0.18)]),
                                                                       center: CGPoint(x: r.minX + d * 0.34, y: r.minY + d * 0.3), startRadius: 0, endRadius: d * 0.78))
                } else {
                    ctx.fill(Path(ellipseIn: r), with: .radialGradient(Gradient(colors: [fill, fill.mix(with: c, by: 0.25)]),
                                                                       center: CGPoint(x: r.minX + d * 0.34, y: r.minY + d * 0.3), startRadius: 0, endRadius: d * 0.78))
                    ctx.stroke(Path(ellipseIn: r.insetBy(dx: 0.7, dy: 0.7)), with: .color(c.opacity(0.5)), lineWidth: 1.2)
                }
                ctx.fill(Path(ellipseIn: CGRect(x: r.minX + d * 0.24, y: r.minY + d * 0.16, width: d * 0.3, height: d * 0.22)), with: .color(.white.opacity(0.75)))
            }
        }
    }

    // MARK: the year marks, under their stones
    private func marks(_ ctx: inout GraphicsContext, _ w: CGFloat) {
        for (m, t) in MapGeo.marks {
            let p = MapGeo.point(m, width: w)
            let text = Text(t).font(.caption2.weight(.bold)).foregroundStyle(night ? Color.white.opacity(0.75) : Color(hex: 0x4A3B26))
            let r = ctx.resolve(text)
            let s = r.measure(in: CGSize(width: 80, height: 20))
            let box = CGRect(x: p.x - s.width / 2 - 6, y: p.y + 12, width: s.width + 12, height: s.height + 4)
            ctx.fill(Path(roundedRect: box, cornerRadius: box.height / 2), with: .color(night ? Color.black.opacity(0.25) : .white.opacity(flat ? 0.95 : 0.8)))
            ctx.draw(r, at: CGPoint(x: box.midX, y: box.midY))
        }
    }
}

/// The child's home at night: a small house with its window lit low, on the child's own stone.
struct MapHome: View {
    let flat: Bool
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let wall = CGRect(x: w * 0.2, y: h * 0.42, width: w * 0.6, height: h * 0.5)
            ctx.fill(Path(roundedRect: wall, cornerRadius: 3), with: flat ? .color(Color(hex: 0x3A4670)) : .linearGradient(Gradient(colors: [Color(hex: 0x4A5A8C), Color(hex: 0x2E3A64)]), startPoint: CGPoint(x: 0, y: wall.minY), endPoint: CGPoint(x: 0, y: wall.maxY)))
            var roof = Path()
            roof.move(to: CGPoint(x: w * 0.08, y: h * 0.47)); roof.addLine(to: CGPoint(x: w * 0.5, y: h * 0.1)); roof.addLine(to: CGPoint(x: w * 0.92, y: h * 0.47)); roof.closeSubpath()
            ctx.fill(roof, with: .color(Color(hex: 0x6E4A6A)))
            let win = CGRect(x: w * 0.38, y: h * 0.55, width: w * 0.24, height: h * 0.2)
            ctx.fill(Path(ellipseIn: win.insetBy(dx: -8, dy: -8)), with: .radialGradient(Gradient(colors: [Palette.amber.opacity(0.45), .clear]), center: CGPoint(x: win.midX, y: win.midY), startRadius: 0, endRadius: w * 0.3))
            ctx.fill(Path(roundedRect: win, cornerRadius: 2), with: .color(Palette.amber.opacity(0.9)))
            // Zz: the child asleep inside
            let z = ctx.resolve(Text("z").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(Color(hex: 0xC9D6F2)))
            ctx.draw(z, at: CGPoint(x: w * 0.86, y: h * 0.12))
            let z2 = ctx.resolve(Text("z").font(.system(size: 8, weight: .heavy, design: .rounded)).foregroundStyle(Color(hex: 0xC9D6F2)))
            ctx.draw(z2, at: CGPoint(x: w * 0.98, y: h * 0.0 + 2))
        }
        .accessibilityHidden(true)
    }
}

/// Moss at a month: the growing child (child_0…6, Moss at seven stages) at that month's size, facing the way the path
/// goes on that row.
private struct MapMoss: View {
    let month: Int
    var giggle = 0
    var body: some View {
        let st = GrowingChild.stage(month)
        let d: CGFloat = 76 + CGFloat(st) * 3
        GrowingChild(month: month, giggle: giggle)
            .frame(width: d, height: d)
            .scaleEffect(x: MapGeo.facing(month), y: 1)
            .animation(.snappy(duration: 0.25), value: MapGeo.facing(month))
    }
    /// The figure's frame is square with its ground 14/300 above the foot: where its centre goes so Moss stands on
    /// the stone at `p`.
    static func centre(_ month: Int, on p: CGPoint) -> CGPoint {
        let d: CGFloat = 76 + CGFloat(GrowingChild.stage(month)) * 3
        return CGPoint(x: p.x, y: p.y + 4 - d / 2 + d * 14 / 300)
    }
}

struct GrowthMap: View {
    @Environment(AppModel.self) private var app
    @Environment(\.night) private var nightTab
    @Environment(\.lamp) private var lamp
    @Environment(\.accessibilityReduceMotion) private var reduce
    private var night: Bool { nightTab || lamp }
    @Binding var month: Int
    let baby: Int
    var close: (() -> Void)? = nil
    @State private var preview: Int
    @State private var dragging = false
    @State private var giggles = 0
    @State private var arrived = 0

    init(month: Binding<Int>, baby: Int, close: (() -> Void)? = nil) {
        _month = month; self.baby = baby; self.close = close; _preview = State(initialValue: month.wrappedValue)
    }

    private var flat: Bool { ArtStyle.current == .flat }

    var body: some View {
        VStack(spacing: 0) {
            map
            info
        }
        .printCard(radius: 30)
        .onChange(of: month) { _, v in if preview != v { preview = v } }
        // a new month since the map was last opened: Moss is on last month's stone, and hops on to the new one
        .task {
            let seen = UserDefaults.standard.object(forKey: "mapSeenMonth") as? Int
            UserDefaults.standard.set(baby, forKey: "mapSeenMonth")
            guard let seen, seen < baby, month == baby, !reduce else { return }
            preview = max(0, baby - 1)
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(.spring(response: 0.55, dampingFraction: 0.6)) { preview = baby }
            arrived += 1
        }
        .sensoryFeedback(.selection, trigger: preview)
        // crossing into a new year (出生, 1 岁, 2 岁, 3 岁) is felt more than a month
        .sensoryFeedback(.impact(weight: .medium), trigger: MapGeo.row(preview))
        .sensoryFeedback(.success, trigger: arrived)
        .sensoryFeedback(.impact(weight: .light), trigger: giggles)
    }

    // MARK: the map
    private var map: some View {
        GeometryReader { g in
            let w = g.size.width
            let home = MapGeo.point(baby, width: w)
            let at = MapGeo.point(preview, width: w)
            let asleep = night && preview == baby
            ZStack(alignment: .topLeading) {
                MapLand(baby: baby, night: night, flat: flat).equatable()
                // Otto by the child's month, on the side away from Moss (behind it when Moss is there too), never off the
                // map's edge and never on Moss; his lamp pools on the stone
                let side: CGFloat = preview < baby && MapGeo.row(preview) == MapGeo.row(baby) ? MapGeo.facing(baby) : -MapGeo.facing(baby)
                let want = home.x + side * 54
                let ox = want < 20 || want > w - 20 ? home.x - side * 54 : want
                Ellipse().fill(RadialGradient(colors: [Palette.amber.opacity(night ? 0.42 : 0.2), .clear], center: .center, startRadius: 0, endRadius: 34))
                    .frame(width: 76, height: 30).position(x: home.x, y: home.y + 2)
                    .allowsHitTesting(false)
                Creature(kind: .otto, look: CGPoint(x: (home.x - ox) / 54 * 0.7, y: 0.3), lid: night ? 0.5 : nil, poke: true, glow: night, glowFor: night ? 4.5 : nil)
                    .frame(width: 48, height: 48)
                    .position(x: ox, y: home.y - 19)
                    .allowsHitTesting(false)
                if night {
                    MapHome(flat: flat).frame(width: 46, height: 46).position(x: home.x, y: home.y - 19).allowsHitTesting(false)
                }
                // the chosen month: a ring on its stone, and Moss on it
                if preview != baby {
                    Circle().strokeBorder(night ? Color.white.opacity(0.9) : Color(hex: 0x2E2418).opacity(0.8), lineWidth: 2.5)
                        .frame(width: 24, height: 24)
                        .position(at)
                        .animation(reduce ? nil : .spring(response: dragging ? 0.16 : 0.34, dampingFraction: 0.8), value: preview)
                        .allowsHitTesting(false)
                }
                if !asleep {
                    MapMoss(month: preview, giggle: giggles)
                        .position(MapMoss.centre(preview, on: at))
                        .animation(reduce ? nil : .spring(response: dragging ? 0.2 : 0.4, dampingFraction: 0.72), value: preview)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    dragging = true
                    let m = MapGeo.month(near: v.location, width: w)
                    if m != preview { preview = m }
                }
                .onEnded { v in
                    dragging = false
                    let m = MapGeo.month(near: v.location, width: w)
                    // a tap on Moss's own stone makes him giggle
                    if m == preview && hypot(v.translation.width, v.translation.height) < 6 { giggles += 1 }
                    preview = m
                    if m != month { month = m }
                    if m == baby { arrived += 1 }
                })
        }
        .frame(height: MapGeo.height)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 30, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 30, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("成长地图，37 个月")
        .accessibilityValue((preview == 0 ? "出生" : "满 \(preview) 个月") + (preview == baby ? "，宝宝在这里" : ""))
        .accessibilityAdjustableAction { d in
            switch d {
            case .increment: preview = min(36, preview + 1); month = preview
            case .decrement: preview = max(0, preview - 1); month = preview
            default: break
            }
        }
    }

    // MARK: the month, under the map
    private var info: some View {
        let m = preview
        let mo = app.content.month(m)
        let plays = app.content.plays(of: m)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(m == 0 ? "出生" : "\(m)").font(Typeface.numerals(m == 0 ? 30 : 40, relativeTo: .largeTitle, weight: .bold))
                    .contentTransition(.numericText(value: Double(m)))
                if m > 0 { Text("个月").font(.headline) }
                if m == baby, let d = app.age?.days, d > 0 {
                    Text("\(d)").font(Typeface.numerals(20, relativeTo: .headline, weight: .bold)).padding(.leading, 2)
                    Text("天").font(.headline)
                }
                Spacer(minLength: 8)
                Text(verbatim: status(m))
                    .font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(m == baby ? Palette.bead.opacity(0.18) : Palette.outline.opacity(0.35)))
                    .foregroundStyle(m == baby ? Palette.lampTint : Palette.secondaryText)
                if let close {
                    Button(action: close) {
                        Image(systemName: "chevron.up").font(.footnote.weight(.bold)).frame(width: 32, height: 32)
                            .background(Palette.outline.opacity(0.35), in: Circle())
                    }
                    .foregroundStyle(.primary)
                    .accessibilityLabel("收起成长地图")
                }
            }
            .animation(.snappy, value: m)
            // the month's own picture beside what it is about: the month at a glance, without opening it
            HStack(alignment: .top, spacing: 12) {
                if let f = ArtIndex.shared.cover(m) {
                    ArtView(name: f, label: m == 0 ? "出生" : "满 \(m) 个月", radius: 10)
                        .frame(width: 92)
                        .id(f)
                        .transition(.opacity)
                }
                Text(mo.title).font(.headline).lineLimit(4).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .animation(.easeOut(duration: 0.18), value: m)
            if m == baby, let a = app.age, a.days + a.toNext > 0 {
                MonthProgress(days: a.days, toNext: a.toNext, next: m + 1)
            }
            HStack(spacing: 6) {
                ForEach(Array(plays.prefix(5)), id: \.id) { p in
                    let k = Palette.areaKey(of: p)
                    IconTile(symbol: Palette.areaSymbol(k), color: Palette.area(k), size: 26)
                }
                Text("\(plays.count) 个教具").font(.footnote).foregroundStyle(Palette.secondaryText).padding(.leading, 4)
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 14)
    }

    private func status(_ m: Int) -> String {
        if m == baby { return night ? "宝宝在家睡觉" : "宝宝在这里" }
        if m < baby { return "走过的一站" }
        if let b = app.birth { let d = b.plus(months: m); return (d.y == Day.today.y ? d.md : "\(d.y)年\(d.md)") + " 到这一站" }
        return "以后的一站"
    }
}

/// The way through this month to the next: a short piece of the map's own path, with the stones of this month and
/// the next and Moss's golden bead between them, and how many days are left.
struct MonthProgress: View {
    let days: Int, toNext: Int, next: Int
    private var flat: Bool { ArtStyle.current == .flat }
    private var words: some View {
        Text("\(toNext) 天后满 \(next) 个月").font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText).monospacedDigit()
            .lineLimit(1).fixedSize()
    }
    private var wrappingWords: some View {
        Text("\(toNext) 天后满 \(next) 个月").font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText).monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
    }
    private func bar(_ k: Double) -> some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.outline.opacity(0.45)).frame(height: 6)
                Capsule().fill(flat ? AnyShapeStyle(Color(hex: 0xFFD27A)) : AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFFE3A3), Palette.bead], startPoint: .leading, endPoint: .trailing)))
                    .frame(width: max(10, w * k), height: 6)
                Circle().fill(Palette.bead).frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .shadow(color: flat ? .clear : .black.opacity(0.18), radius: 1.5, y: 1)
                    .offset(x: max(0, w * k - 6))
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: 12)
    }
    var body: some View {
        let k = Double(days) / Double(max(1, days + toNext))
        // the bar and the words side by side, or the words under the bar when there is no room (large text): the
        // card never grows wider than the page
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { bar(k).frame(minWidth: 60); words }
            VStack(alignment: .leading, spacing: 4) { bar(k); wrappingWords }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(toNext) 天后满 \(next) 个月")
    }
}

/// The map in small, for the folded month card: the child's own hill and path, Moss on his stone (by night the
/// house with its lit window and Otto's lamp), in the same world as the map.
struct MapVignette: View {
    let month: Int, baby: Int
    /// The grown-up beside the child by day too (the family on 我的), not only by night.
    var otto = false
    var giggle = 0
    @Environment(\.night) private var nightTab
    @Environment(\.lamp) private var lamp
    /// Night by the home tab's clock or under the lamp (夜灯) on any page.
    private var night: Bool { nightTab || lamp }
    private var flat: Bool { ArtStyle.current == .flat }
    var body: some View {
        let band = MapGeo.row(month)
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Canvas { ctx, size in
                    let c = Hill.of(band, night: night)
                    let top = night ? Color(hex: 0x0E1430) : Color(hex: 0xBFE2F6), low = night ? Color(hex: 0x1D2A55) : Color(hex: 0xEAF6F2)
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: flat ? .color(top.mix(with: low, by: 0.45)) : .linearGradient(Gradient(colors: [top, low]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.6)))
                    // the sky's things: the sun and two clouds, or the moon and a few stars
                    let sun = CGPoint(x: size.width * 0.86, y: size.height * 0.2)
                    if night {
                        ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 10, y: sun.y - 10, width: 20, height: 20)), with: .color(Color(hex: 0xFFF1C9)))
                        ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 4, y: sun.y - 14, width: 20, height: 20)), with: .color(top.mix(with: low, by: flat ? 0.45 : 0.15)))
                        for (fx, fy) in [(0.12, 0.12), (0.3, 0.26), (0.5, 0.08), (0.66, 0.3)] {
                            let q = CGPoint(x: size.width * fx, y: size.height * fy)
                            ctx.fill(Path(ellipseIn: CGRect(x: q.x - 1.4, y: q.y - 1.4, width: 2.8, height: 2.8)), with: .color(.white.opacity(0.85)))
                        }
                    } else {
                        if flat { ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 14, y: sun.y - 14, width: 28, height: 28)), with: .color(Color(hex: 0xFFD45E))) }
                        else {
                            ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 40, y: sun.y - 40, width: 80, height: 80)), with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF2B8), Color(hex: 0xFFE7A0).opacity(0)]), center: sun, startRadius: 8, endRadius: 40))
                            ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 14, y: sun.y - 14, width: 28, height: 28)), with: .radialGradient(Gradient(colors: [Color(hex: 0xFFF6CF), Color(hex: 0xFFCF4A)]), center: CGPoint(x: sun.x - 4, y: sun.y - 5), startRadius: 0, endRadius: 17))
                        }
                        for (fx, fy, k) in [(0.16, 0.18, 1.0), (0.56, 0.1, 0.75)] {
                            let cc = CGPoint(x: size.width * fx, y: size.height * fy)
                            var cl = Path()
                            for (dx, dy, r) in [(-12.0, 3.0, 8.0), (0.0, -1.0, 11.0), (13.0, 3.0, 8.0)] { cl.addEllipse(in: CGRect(x: cc.x + dx * k - r * k, y: cc.y + dy * k - r * k, width: 2 * r * k, height: 2 * r * k)) }
                            cl.addRoundedRect(in: CGRect(x: cc.x - 20 * k, y: cc.y, width: 40 * k, height: 10 * k), cornerSize: CGSize(width: 5 * k, height: 5 * k))
                            ctx.fill(cl, with: .color(.white.opacity(flat ? 1 : 0.92)))
                        }
                    }
                    // the next year's hill, far behind
                    let far = Hill.of(min(2, band + 1), night: night)
                    var back = Path()
                    let yb = size.height * 0.5
                    back.move(to: CGPoint(x: 0, y: size.height)); back.addLine(to: CGPoint(x: 0, y: yb - 4))
                    back.addQuadCurve(to: CGPoint(x: size.width, y: yb + 8), control: CGPoint(x: size.width * 0.3, y: yb - 24))
                    back.addLine(to: CGPoint(x: size.width, y: size.height)); back.closeSubpath()
                    ctx.fill(back, with: .color(flat ? far.top.mix(with: far.base, by: 0.35) : far.top))
                    var hill = Path()
                    let y0 = size.height * 0.62
                    hill.move(to: CGPoint(x: 0, y: size.height)); hill.addLine(to: CGPoint(x: 0, y: y0 + 6))
                    hill.addQuadCurve(to: CGPoint(x: size.width, y: y0 - 2), control: CGPoint(x: size.width * 0.5, y: y0 - 16))
                    hill.addLine(to: CGPoint(x: size.width, y: size.height)); hill.closeSubpath()
                    if flat {
                        ctx.fill(hill.offsetBy(dx: 0, dy: -3), with: .color(c.edge)); ctx.fill(hill, with: .color(c.top.mix(with: c.base, by: 0.35)))
                    } else {
                        ctx.fill(hill, with: .linearGradient(Gradient(colors: [c.top, c.base]), startPoint: CGPoint(x: 0, y: y0 - 10), endPoint: CGPoint(x: 0, y: size.height)))
                        var rim = ctx; rim.clip(to: hill)
                        rim.stroke(hill.offsetBy(dx: 0, dy: 1.5), with: .color(.white.opacity(night ? 0.12 : 0.6)), lineWidth: 2)
                    }
                    // a piece of the path, with the stone Moss stands on
                    var road = Path(); road.move(to: CGPoint(x: -6, y: size.height * 0.84)); road.addLine(to: CGPoint(x: size.width + 6, y: size.height * 0.84))
                    ctx.stroke(road, with: .color(night ? c.road : Color(hex: 0xFFF6E2)), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    let s = CGRect(x: size.width * (otto ? 0.38 : 0.5) - 8, y: size.height * 0.84 - 8, width: 16, height: 16)
                    ctx.fill(Path(ellipseIn: s.offsetBy(dx: 0, dy: 1.5)), with: .color(.black.opacity(0.15)))
                    ctx.fill(Path(ellipseIn: s), with: .color(Palette.bead))
                }
                .overlay { if flat { Grain(dark: night, strength: 0.9).blendMode(.multiply) } }
                // the child's stone: in the middle, or a little left of it when Otto stands beside
                let stone = CGPoint(x: otto ? w * 0.38 : w / 2, y: h * 0.84)
                let ottoAt = CGPoint(x: min(w - h * 0.36, stone.x + h * 0.92), y: stone.y)
                if night && month == baby {
                    let hs = otto ? h * 0.56 : 52
                    MapHome(flat: flat).frame(width: hs, height: hs).position(x: stone.x - 6, y: stone.y - hs * 0.42)
                    Creature(kind: .otto, look: CGPoint(x: -0.8, y: 0.4), lid: 0.5, alive: true, glow: true, glowFor: 4.5)
                        .frame(width: otto ? h * 0.78 : 36, height: otto ? h * 0.78 : 36)
                        .position(x: otto ? ottoAt.x : w - 18, y: stone.y - (otto ? h * 0.33 : 14))
                } else {
                    let d: CGFloat = otto ? h * 0.7 : 78
                    if otto {
                        // Otto leans toward the child, his lamp pooling light on the stone
                        Ellipse().fill(RadialGradient(colors: [Palette.amber.opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: h * 0.4))
                            .frame(width: h * 0.9, height: h * 0.22).position(x: stone.x, y: stone.y)
                        Creature(kind: .otto, look: CGPoint(x: -0.8, y: 0.45), lean: -8, poke: true, glow: false)
                            .frame(width: h * 0.88, height: h * 0.88)
                            .position(x: ottoAt.x, y: stone.y - h * 0.38)
                    }
                    GrowingChild(month: month, giggle: giggle).frame(width: d, height: d)
                        .position(x: stone.x, y: stone.y + 3 - d / 2 + d * 14 / 300)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
