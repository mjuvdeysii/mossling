import SwiftUI

/// A small reader for SVG path data (M L H V C Q Z, absolute and relative): the companions are drawn from the same
/// path strings as on Android.
enum SVGPath {
    static func parse(_ d: String) -> Path {
        var p = Path()
        var tokens: [String] = []
        var cur = ""
        func flush() { if !cur.isEmpty { tokens.append(cur); cur = "" } }
        for ch in d {
            if ch.isLetter && ch != "e" { flush(); tokens.append(String(ch)) }
            else if ch == " " || ch == "," { flush() }
            else if ch == "-" { if let l = cur.last, l != "e" { flush() } ; cur.append(ch) }
            else if ch == "." && cur.contains(".") { flush(); cur.append(ch) }
            else { cur.append(ch) }
        }
        flush()
        var i = 0, cmd = "M"
        var pt = CGPoint.zero, start = CGPoint.zero
        func num() -> CGFloat { defer { i += 1 }; return CGFloat(Double(tokens[i]) ?? 0) }
        while i < tokens.count {
            if let c = tokens[i].first, c.isLetter { cmd = tokens[i]; i += 1; if cmd == "Z" || cmd == "z" { p.closeSubpath(); pt = start; continue } }
            let rel = cmd == cmd.lowercased()
            func abs(_ x: CGFloat, _ y: CGFloat) -> CGPoint { rel ? CGPoint(x: pt.x + x, y: pt.y + y) : CGPoint(x: x, y: y) }
            switch cmd.uppercased() {
            case "M": pt = abs(num(), num()); start = pt; p.move(to: pt); cmd = rel ? "l" : "L"
            case "L": pt = abs(num(), num()); p.addLine(to: pt)
            case "H": let x = num(); pt = CGPoint(x: rel ? pt.x + x : x, y: pt.y); p.addLine(to: pt)
            case "V": let y = num(); pt = CGPoint(x: pt.x, y: rel ? pt.y + y : y); p.addLine(to: pt)
            case "C": let a = abs(num(), num()), b = abs(num(), num()), e = abs(num(), num()); p.addCurve(to: e, control1: a, control2: b); pt = e
            case "Q": let a = abs(num(), num()), e = abs(num(), num()); p.addQuadCurve(to: e, control: a); pt = e
            default: i += 1
            }
        }
        return p
    }
}

enum Kind: String, CaseIterable, Codable { case moss = "Moss", otto = "Otto"
    var other: Kind { self == .moss ? .otto : .moss }
    var tint: Color { self == .moss ? Palette.moss : Palette.rod }
}
enum Mood { case open, happy, wow, sleep }

/// Geometry in a 100 × 100 box. The two are painted wooden toys, as on a Montessori shelf: Moss a round, egg-shaped
/// figure painted moss green with a mint sprout; Otto a tall peg painted rod blue, a golden bead on top and a string of
/// golden beads across him. The unpainted wooden foot shows at the bottom of each. The feet rest on y = 88.
enum Shapes {
    static let mossBody = SVGPath.parse("M50 30 C70 30 84 48 84 66 C84 80 72 88 50 88 C28 88 16 80 16 66 C16 48 30 30 50 30Z")
    static let mossStem = SVGPath.parse("M50 31 C49.5 27 49.8 23.5 50.6 20.5")
    static let ottoBody = SVGPath.parse("M30 36 C30 24 39 16 50 16 C61 16 70 24 70 36 L70 80 C70 85 66 88 61 88 L39 88 C34 88 30 85 30 80Z")
    /// The golden beads Otto wears, along a gentle curve.
    static let beadStrand: [CGPoint] = (0..<5).map { i in
        let t = Double(i) / 4
        return CGPoint(x: 34.5 + 31 * t, y: 63 + 5 * sin(t * .pi))
    }
    /// A mint leaf of length `l` pointing along +x from the origin.
    static func leaf(_ l: CGFloat, _ w: CGFloat) -> Path {
        var p = Path()
        p.move(to: .zero)
        p.addCurve(to: CGPoint(x: l, y: 0), control1: CGPoint(x: l * 0.25, y: -w * 1.15), control2: CGPoint(x: l * 0.72, y: -w * 0.9))
        p.addCurve(to: .zero, control1: CGPoint(x: l * 0.72, y: w * 0.9), control2: CGPoint(x: l * 0.25, y: w * 1.15))
        p.closeSubpath()
        return p
    }
    static let mintFleck = leaf(6.5, 2.2)
}
