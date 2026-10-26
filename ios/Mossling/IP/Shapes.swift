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
/// What the arms do: hidden at rest (as on the icon), one waving, or both up.
/// `hug`: one long arm reaching out to the left, round whatever stands there (the baby's picture).
enum Arms { case rest, wave, cheer, hug }

/// Geometry in a 100 × 100 box, shared with Android (ui/ip/Creatures.kt).
enum Shapes {
    static let mossStem = SVGPath.parse("M49 36 C48 30 49.2 23 50 17.6")
    static let mintA = SVGPath.parse("M49.80 24.00 Q52.61 27.00 54.92 26.72 L59.05 26.80 Q59.05 25.74 59.20 25.58 L62.47 24.24 Q62.40 23.06 62.52 22.84 L65.12 20.40 Q65.11 19.32 65.21 19.07 L67.19 15.60 Q67.33 14.76 67.42 14.51 Q67.86 13.39 68.00 13.00 Q67.59 12.94 66.40 12.81 Q66.13 12.78 65.32 12.51 L61.33 12.65 Q61.06 12.62 60.11 12.11 L56.74 13.28 Q56.49 13.28 55.48 12.67 L52.77 14.94 Q52.56 15.00 51.62 14.51 L49.78 18.20 Q48.45 20.12 49.80 24.00Z")
    static let mintB = SVGPath.parse("M48.80 26.00 Q49.48 22.34 48.07 20.84 L45.98 17.84 Q45.22 18.42 45.03 18.40 L42.38 16.79 Q41.57 17.49 41.36 17.53 L38.27 17.00 Q37.50 17.60 37.27 17.66 L33.77 18.16 Q33.10 18.52 32.87 18.59 Q31.85 18.89 31.50 19.00 Q31.67 19.32 32.20 20.25 Q32.32 20.46 32.55 21.19 L34.72 23.98 Q34.84 24.18 34.97 25.14 L37.56 26.91 Q37.69 27.09 37.78 28.15 L40.80 28.84 Q40.96 28.96 41.10 29.90 L44.69 29.20 Q46.74 29.10 48.80 26.00Z")
    static let mintC = SVGPath.parse("M50.40 17.80 Q52.30 18.17 53.12 17.39 L55.35 14.61 Q55.06 13.89 55.07 13.67 L55.09 9.92 Q54.83 9.22 54.77 8.96 Q54.65 8.39 54.60 8.20 Q54.42 8.29 53.92 8.59 Q53.70 8.72 53.00 9.01 L50.27 11.57 Q50.11 11.72 49.38 12.00 L48.85 15.52 Q48.84 16.66 50.40 17.80Z")
    static let mintD = SVGPath.parse("M49.60 18.00 Q50.87 16.72 50.70 15.69 L49.72 12.60 Q49.01 12.46 48.84 12.35 L45.98 10.48 Q45.30 10.33 45.07 10.24 Q44.57 10.06 44.40 10.00 Q44.38 10.18 44.35 10.72 Q44.33 10.95 44.20 11.63 L44.74 15.01 Q44.78 15.22 44.61 15.92 L47.05 18.07 Q47.92 18.64 49.60 18.00Z")
    static let mintVeins = SVGPath.parse("M49.80 24.00 L65.45 14.54 M55.26 20.70 L59.82 22.48 M55.26 20.70 L55.80 15.84 M59.26 18.28 L63.34 19.26 M59.26 18.28 L60.29 14.22 M62.90 16.08 L66.18 15.74 M62.90 16.08 L64.73 13.34 M48.80 26.00 L33.92 19.98 M43.61 23.90 L42.51 19.66 M43.61 23.90 L39.87 26.18 M39.80 22.36 L38.38 18.90 M39.80 22.36 L36.38 23.86 M36.34 20.96 L34.40 18.80 M36.34 20.96 L33.44 21.16 M50.40 17.80 L54.01 9.54 M49.60 18.00 L45.13 11.12")
    static let mintFleck = SVGPath.parse("M0 3 C1.6 1.2 4 0.6 6 0.8 C5.6 3 4 4.6 0 3Z")
    static let mossBody = SVGPath.parse("M22 82 C15 77 13 66 16 56 C19 45 28 36 41 34 C53 32 63 33 72 38 C82 44 88 55 87 67 C86 77 80 84 70 86 C56 88 33 89 22 82Z")
    /// Little lighter tufts of moss on Moss's back (as in the picture book, tools/illustrate.py).
    static let mossTufts = SVGPath.parse("M24 52 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M64 44 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M70 72 c3 -3 7 -3 9 0 c-3 2 -6 2 -9 0Z M28 72 c2 -2 5 -2 7 0 c-2 1.6 -5 1.6 -7 0Z")
    static let ottoStem = SVGPath.parse("M53 17 C54 12 57 8 61 6")
    /// The icon's rod (tools/ios_icon.py bead.svg): from the top of the head, forward, the bead hanging at its end.
    static let ottoRod = SVGPath.parse("M50 16.5 C45 4 30 1 21 8 L20 11.5")
    /// Moss's flat darker underside, the counterpart of Otto's dip.
    static let mossUnder = SVGPath.parse("M14 68 C30 76 70 76 88 66 C88 76 80 84 70 86 C56 88 33 89 22 82 C17 78 14 74 14 68Z")
    static let ottoBody = SVGPath.parse("M30 84 C25 74 24 58 26 44 C28 28 38 16 52 16 C65 17 74 28 75 44 C76 60 74 75 70 84 C60 88 40 88 30 84Z")
    static let ottoDip = SVGPath.parse("M25.2 64 C35 68 64 68 75.4 63 C75 71 73 78 70 84 C60 88 40 88 30 84 C27.6 78 26 71 25.2 64Z")
}
