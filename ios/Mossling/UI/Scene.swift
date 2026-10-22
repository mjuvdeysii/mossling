import SwiftUI

/// The sky over the companions: its colours follow the hour — dawn, day, dusk, night — and the ground rises out of the
/// page's own background, so the scene and the content below are one surface. Colour belongs to the content layer here;
/// the controls above it are the system's glass.
struct Sky: View {
    var hour: Int = Day.cal.component(.hour, from: Date())
    @Environment(\.colorScheme) private var scheme

    enum Phase { case dawn, day, dusk, night }
    static func phase(_ h: Int) -> Phase { h >= 5 && h < 9 ? .dawn : h >= 9 && h < 17 ? .day : h >= 17 && h < 20 ? .dusk : .night }

    private var colors: [Color] {
        let dark = scheme == .dark
        switch Self.phase(hour) {
        case .dawn: return dark ? [Color(hex: 0x2E2742), Color(hex: 0x6E4A55)] : [Color(hex: 0xFFCFB0), Color(hex: 0xFFF1DE)]
        case .day: return dark ? [Color(hex: 0x1B3550), Color(hex: 0x3D5468)] : [Color(hex: 0x9CD4F7), Color(hex: 0xFFF3E0)]
        case .dusk: return dark ? [Color(hex: 0x2B2140), Color(hex: 0x7A4650)] : [Color(hex: 0xF6A88A), Color(hex: 0xFFE2C4)]
        case .night: return [Color(hex: 0x14142E), Color(hex: 0x2E2A4E)]
        }
    }
    /// Text on the sky: dark by day in light mode, white otherwise.
    static func ink(_ hour: Int, _ scheme: ColorScheme) -> Color {
        let p = phase(hour)
        return scheme == .light && p != .night ? Color(hex: 0x3A2414) : .white
    }

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: colors), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            let p = Self.phase(hour)
            // the sun or the moon, a soft disc with a halo
            let c = CGPoint(x: size.width * 0.78, y: size.height * (p == .day ? 0.28 : 0.4))
            let isNight = p == .night || (scheme == .dark && p != .day)
            let disc: Color = isNight ? Color(hex: 0xF4F1E4) : p == .day ? Color(hex: 0xFFF6D6) : Color(hex: 0xFFD9A8)
            for (r, a) in [(70.0, 0.10), (46.0, 0.16)] {
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)), with: .color(disc.opacity(a)))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 22, y: c.y - 22, width: 44, height: 44)), with: .color(disc.opacity(isNight ? 0.95 : 0.9)))
            if isNight {
                // a few stars
                for (x, y, r) in [(0.12, 0.2, 1.2), (0.3, 0.12, 0.9), (0.46, 0.3, 1.1), (0.6, 0.16, 0.8), (0.2, 0.42, 0.8), (0.9, 0.12, 1.0)] {
                    ctx.fill(Path(ellipseIn: CGRect(x: size.width * x - r, y: size.height * y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.8)))
                }
            }
            // a soft rainbow by day
            if !isNight && p != .dusk {
                let rc = CGPoint(x: size.width * 0.3, y: size.height * 0.92)
                for (i, col) in Crayon.rainbow.prefix(6).enumerated() {
                    let r = size.width * 0.42 - CGFloat(i) * 7
                    var arc = Path(); arc.addArc(center: rc, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                    ctx.stroke(arc, with: .color(col.opacity(scheme == .dark ? 0.22 : 0.3)), lineWidth: 7)
                }
            }
            // two hills: a far one tinted by the sky, a near one that is the page itself
            var far = Path()
            far.move(to: CGPoint(x: 0, y: size.height * 0.78))
            far.addCurve(to: CGPoint(x: size.width, y: size.height * 0.7), control1: CGPoint(x: size.width * 0.35, y: size.height * 0.6), control2: CGPoint(x: size.width * 0.7, y: size.height * 0.82))
            far.addLine(to: CGPoint(x: size.width, y: size.height)); far.addLine(to: CGPoint(x: 0, y: size.height)); far.closeSubpath()
            ctx.fill(far, with: .color(Crayon.leaf.opacity(isNight ? 0.3 : 0.32)))
            var near = Path()
            near.move(to: CGPoint(x: 0, y: size.height * 0.9))
            near.addCurve(to: CGPoint(x: size.width, y: size.height * 0.84), control1: CGPoint(x: size.width * 0.4, y: size.height * 0.8), control2: CGPoint(x: size.width * 0.75, y: size.height * 0.9))
            near.addLine(to: CGPoint(x: size.width, y: size.height)); near.addLine(to: CGPoint(x: 0, y: size.height)); near.closeSubpath()
            ctx.fill(near, with: .color(Palette.background))
        }
        .accessibilityHidden(true)
    }
}
