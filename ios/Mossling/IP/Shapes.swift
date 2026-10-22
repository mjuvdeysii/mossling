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

/// Geometry in a 100 × 100 box, drawn for iOS: soft, rounded volumes that read as polished glass objects. The feet
/// rest on y = 88.
enum Shapes {
    /// Moss: a smooth pebble, a little wider at the base.
    static let mossBody = SVGPath.parse("M17 71 C15 53 30 37 50 36 C71 35 86 51 85 69 C84 83 70 89 50 89 C31 89 18 84 17 71Z")
    static let mossStem = SVGPath.parse("M50 37.5 C49.4 33 49.6 28.5 50.4 24.5")
    /// Otto: tall and rounded, one big eye.
    static let ottoBody = SVGPath.parse("M28 82 C24.5 66 24.5 48 26.5 35 C28.5 21 38.5 13 51 13 C63.5 13 73.5 21 75.5 35 C77.5 48 77.5 66 74 82 C67 89.5 35 89.5 28 82Z")
    static let ottoStem = SVGPath.parse("M51.5 13.5 C52.5 9 56 5.5 60.5 4.5")
    /// The string of golden beads Otto wears, as points along a gentle curve.
    static let beadStrand: [CGPoint] = (0..<6).map { i in
        let t = Double(i) / 5
        return CGPoint(x: 30.5 + 41 * t, y: 62 + 9 * t + 6 * t * (1 - t))
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
