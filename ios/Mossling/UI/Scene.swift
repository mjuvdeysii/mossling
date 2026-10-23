import SwiftUI

/// The little scene the companions live in, drawn like a page of a picture book: a flat sky whose colour follows the
/// hour (dawn, day, dusk, night), a sun or moon, two clouds or a few stars, and grassy hills. Every shape sits on an
/// offset deeper copy of itself, as the companions do.
struct Sky: View {
    var hour: Int = Day.cal.component(.hour, from: Date())
    @Environment(\.colorScheme) private var scheme

    enum Phase { case dawn, day, dusk, night }
    static func phase(_ h: Int) -> Phase { h >= 5 && h < 9 ? .dawn : h >= 9 && h < 17 ? .day : h >= 17 && h < 20 ? .dusk : .night }

    private var sky: Color {
        let dark = scheme == .dark
        switch Self.phase(hour) {
        case .dawn: return dark ? Color(hex: 0x3B3150) : Color(hex: 0xFFDCC2)
        case .day: return dark ? Color(hex: 0x23405E) : Color(hex: 0xBFE3F7)
        case .dusk: return dark ? Color(hex: 0x3C2A48) : Color(hex: 0xF9C3A6)
        case .night: return Color(hex: 0x1E2148)
        }
    }
    /// Text on the sky: dark ink by day in light mode, white otherwise.
    static func ink(_ hour: Int, _ scheme: ColorScheme) -> Color {
        scheme == .light && phase(hour) != .night ? Color(hex: 0x2E2418) : .white
    }

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let p = Self.phase(hour)
            let night = p == .night
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(sky))
            func printed(_ path: Path, _ fill: Color, _ deep: Color) {
                ctx.fill(path.offsetBy(dx: 2, dy: 2), with: .color(deep))
                ctx.fill(path, with: .color(fill))
            }
            // sun or moon
            let c = CGPoint(x: w * 0.8, y: h * 0.26)
            if night {
                var moon = Path(ellipseIn: CGRect(x: c.x - 16, y: c.y - 16, width: 32, height: 32))
                moon = moon.subtracting(Path(ellipseIn: CGRect(x: c.x - 8, y: c.y - 22, width: 32, height: 32)))
                printed(moon, Color(hex: 0xFFF1C4), Color(hex: 0xC9A955))
                for (x, y) in [(0.1, 0.18), (0.28, 0.1), (0.5, 0.22), (0.62, 0.08), (0.4, 0.4), (0.92, 0.5)] {
                    var star = Path(); let sx = w * x, sy = h * y
                    star.move(to: CGPoint(x: sx, y: sy - 3)); star.addLine(to: CGPoint(x: sx + 1, y: sy - 1)); star.addLine(to: CGPoint(x: sx + 3, y: sy))
                    star.addLine(to: CGPoint(x: sx + 1, y: sy + 1)); star.addLine(to: CGPoint(x: sx, y: sy + 3)); star.addLine(to: CGPoint(x: sx - 1, y: sy + 1))
                    star.addLine(to: CGPoint(x: sx - 3, y: sy)); star.addLine(to: CGPoint(x: sx - 1, y: sy - 1)); star.closeSubpath()
                    ctx.fill(star, with: .color(Color(hex: 0xFFF1C4).opacity(0.9)))
                }
            } else {
                printed(Path(ellipseIn: CGRect(x: c.x - 18, y: c.y - 18, width: 36, height: 36)), p == .day ? Color(hex: 0xFFD45C) : Color(hex: 0xFFB36B), Color(hex: 0xE09A2B))
                for (x, y, k) in [(0.16, 0.2, 1.0), (0.52, 0.12, 0.75)] {
                    var cl = Path()
                    let cx = w * x, cy = h * y, r = 9 * k
                    cl.addEllipse(in: CGRect(x: cx - r * 2.2, y: cy - r * 0.2, width: r * 4.4, height: r * 1.6))
                    cl.addEllipse(in: CGRect(x: cx - r * 1.2, y: cy - r, width: r * 2, height: r * 2))
                    cl.addEllipse(in: CGRect(x: cx, y: cy - r * 0.6, width: r * 1.6, height: r * 1.6))
                    printed(cl, Color.white.opacity(scheme == .dark ? 0.75 : 0.95), sky.mix(with: .black, by: 0.12))
                }
            }
            // far hill and near hill
            var far = Path()
            far.move(to: CGPoint(x: 0, y: h * 0.7))
            far.addCurve(to: CGPoint(x: w, y: h * 0.62), control1: CGPoint(x: w * 0.3, y: h * 0.5), control2: CGPoint(x: w * 0.7, y: h * 0.74))
            far.addLine(to: CGPoint(x: w, y: h)); far.addLine(to: CGPoint(x: 0, y: h)); far.closeSubpath()
            printed(far, night ? Color(hex: 0x3D5A45) : Color(hex: 0xA9D18E), night ? Color(hex: 0x2B4232) : Color(hex: 0x7FAF68))
            var near = Path()
            near.move(to: CGPoint(x: 0, y: h * 0.86))
            near.addCurve(to: CGPoint(x: w, y: h * 0.8), control1: CGPoint(x: w * 0.35, y: h * 0.74), control2: CGPoint(x: w * 0.7, y: h * 0.9))
            near.addLine(to: CGPoint(x: w, y: h)); near.addLine(to: CGPoint(x: 0, y: h)); near.closeSubpath()
            printed(near, night ? Color(hex: 0x4E7356) : Color(hex: 0x86C06E), night ? Color(hex: 0x36523D) : Color(hex: 0x5E9A4C))
            // a few sprouts in the grass
            for x in [0.08, 0.3, 0.46] {
                var sp = Path(); let sx = w * x, sy = h * 0.92
                sp.move(to: CGPoint(x: sx, y: sy)); sp.addQuadCurve(to: CGPoint(x: sx - 6, y: sy - 8), control: CGPoint(x: sx - 6, y: sy - 2))
                sp.move(to: CGPoint(x: sx, y: sy)); sp.addQuadCurve(to: CGPoint(x: sx + 6, y: sy - 9), control: CGPoint(x: sx + 6, y: sy - 2))
                ctx.stroke(sp, with: .color(night ? Color(hex: 0x6E9A72) : Color(hex: 0x4E8A3C)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
        .accessibilityHidden(true)
    }
}
