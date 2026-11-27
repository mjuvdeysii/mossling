import SwiftUI

/// The crayon box (ios/DESIGN.md §3): teal leads, with pink, yellow and red, and blue and orange to complete the six
/// areas — bright, clean colours for a playroom, each with a lighter value for dark mode. These are fills for drawings,
/// stickers and marks; text in a colour uses `Crayon.ink(_:)`, which passes WCAG AA on paper and on cards.
enum Crayon {
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        func ui(_ h: UInt32) -> UIColor { UIColor(red: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255, blue: CGFloat(h & 0xFF) / 255, alpha: 1) }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
    // the six
    static let teal = dyn(0x1FB5A6, 0x4FD8CB)
    static let pink = dyn(0xFF6F91, 0xFF8FAA)
    static let sunflower = dyn(0xFFC23D, 0xFFD36B)
    static let cherry = dyn(0xF2554B, 0xFF7A70)
    static let sky = dyn(0x4C9BE8, 0x7DB8F2)
    static let tangerine = dyn(0xFF8A3D, 0xFFA066)
    // between them
    static let rose = pink
    static let aqua = teal
    static let mint = dyn(0x3CC9A0, 0x5FDDB8)
    static let leaf = dyn(0x4DB86A, 0x6ACF85)
    static let lilac = dyn(0x9B7BEA, 0xB39CF4)
    static let peach = dyn(0xFF9E7A, 0xFFB394)
    static let caramel = dyn(0xD9964F, 0xE8AD6E)
    static let pebble = dyn(0x9A9289, 0xA9A29A)
    /// The order of the rainbow, for things that cycle.
    static let rainbow = [teal, pink, sunflower, cherry, sky, tangerine, mint, lilac]
    /// The glyph on a crayon: white, except dark on the light sunflower.
    static func glyph(on c: Color) -> Color { c == sunflower ? Color(red: 0.42, green: 0.27, blue: 0) : .white }
    /// The same colour as a button fill under white text: the deep value in both modes (≥ 4.5:1 with white).
    static func buttonFill(_ c: Color) -> Color {
        switch c {
        case teal, aqua, mint: Color(red: 0x0B / 255, green: 0x7D / 255, blue: 0x74 / 255)
        case pink, rose: Color(red: 0xB8 / 255, green: 0x2D / 255, blue: 0x52 / 255)
        case sunflower: Color(red: 0x7D / 255, green: 0x51 / 255, blue: 0x00 / 255)
        case cherry: Color(red: 0xB5 / 255, green: 0x28 / 255, blue: 0x20 / 255)
        case leaf: Color(red: 0x1E / 255, green: 0x7B / 255, blue: 0x3A / 255)
        case sky: Color(red: 0x1F / 255, green: 0x6D / 255, blue: 0xB8 / 255)
        case tangerine, peach, caramel: Color(red: 0xA3 / 255, green: 0x48 / 255, blue: 0x06 / 255)
        case lilac: Color(red: 0x6A / 255, green: 0x48 / 255, blue: 0xC8 / 255)
        default: contrastSafeButtonFill(c)
        }
    }
    /// The same colour, deep enough for text (≥ 4.5:1 on paper, cards and the dark page).
    static func ink(_ c: Color) -> Color {
        switch c {
        case teal, aqua, mint: dyn(0x08675F, 0x4FD8CB)
        case pink, rose: dyn(0xB82D52, 0xFF8FAA)
        case sunflower: dyn(0x7D5100, 0xFFD36B)
        case cherry: dyn(0xB52820, 0xFF7A70)
        case leaf: dyn(0x1B6E33, 0x6ACF85)
        case sky: dyn(0x195FA3, 0x7DB8F2)
        case tangerine, peach, caramel: dyn(0xA34806, 0xFFA066)
        case lilac: dyn(0x5E3EB8, 0xB39CF4)
        case pebble: dyn(0x59524A, 0xD2CAC0)
        default: contrastSafeInk(c)
        }
    }

    private static func rgbComponents(of color: Color, traits: UITraitCollection) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let resolved = UIColor(color).resolvedColor(with: traits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        if resolved.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (r, g, b, a)
        }
        if let srgb = CGColorSpace(name: CGColorSpace.sRGB),
           let converted = resolved.cgColor.converted(to: srgb, intent: .defaultIntent, options: nil),
           let c = converted.components, c.count >= 3 {
            return (c[0], c[1], c[2], c.count > 3 ? c[3] : 1)
        }
        return (0.2, 0.2, 0.2, 1)
    }

    private static func relativeLuminance(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> Double {
        func linearize(_ v: CGFloat) -> Double {
            let x = max(0, min(1, Double(v)))
            return x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
    }

    private static func contrastSafeButtonFill(_ c: Color) -> Color {
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let rgba = rgbComponents(of: c, traits: lightTraits)
        // Target luminance <= 0.168 ensures contrast >= 4.8:1 under white label text
        let targetLum = 0.168
        if relativeLuminance(rgba.r, rgba.g, rgba.b) <= targetLum { return c }
        var lo: CGFloat = 0, hi: CGFloat = 1
        for _ in 0..<12 {
            let mid = (lo + hi) * 0.5
            if relativeLuminance(rgba.r * mid, rgba.g * mid, rgba.b * mid) > targetLum {
                hi = mid
            } else {
                lo = mid
            }
        }
        return Color(UIColor(red: rgba.r * lo, green: rgba.g * lo, blue: rgba.b * lo, alpha: rgba.a))
    }

    private static func contrastSafeInk(_ c: Color) -> Color {
        Color(UIColor { traits in
            let rgba = rgbComponents(of: c, traits: traits)
            if traits.userInterfaceStyle == .dark {
                // Target luminance >= 0.275 achieves >= 4.8:1 on #19213F lamp card
                let targetLum = 0.275
                if relativeLuminance(rgba.r, rgba.g, rgba.b) >= targetLum {
                    return UIColor(red: rgba.r, green: rgba.g, blue: rgba.b, alpha: rgba.a)
                }
                var lo: CGFloat = 0, hi: CGFloat = 1
                for _ in 0..<12 {
                    let mid = (lo + hi) * 0.5
                    let mr = rgba.r + (0.96 - rgba.r) * mid
                    let mg = rgba.g + (0.94 - rgba.g) * mid
                    let mb = rgba.b + (0.90 - rgba.b) * mid
                    if relativeLuminance(mr, mg, mb) < targetLum {
                        lo = mid
                    } else {
                        hi = mid
                    }
                }
                let r = rgba.r + (0.96 - rgba.r) * hi
                let g = rgba.g + (0.94 - rgba.g) * hi
                let b = rgba.b + (0.90 - rgba.b) * hi
                return UIColor(red: r, green: g, blue: b, alpha: rgba.a)
            } else {
                // Target luminance <= 0.132 achieves >= 4.8:1 on warm paper and tinted light cards
                let targetLum = 0.132
                if relativeLuminance(rgba.r, rgba.g, rgba.b) <= targetLum {
                    return UIColor(red: rgba.r, green: rgba.g, blue: rgba.b, alpha: rgba.a)
                }
                var lo: CGFloat = 0, hi: CGFloat = 1
                for _ in 0..<12 {
                    let mid = (lo + hi) * 0.5
                    if relativeLuminance(rgba.r * mid, rgba.g * mid, rgba.b * mid) > targetLum {
                        hi = mid
                    } else {
                        lo = mid
                    }
                }
                return UIColor(red: rgba.r * lo, green: rgba.g * lo, blue: rgba.b * lo, alpha: rgba.a)
            }
        })
    }
}

/// Each kind of entry has one crayon and one SF Symbol, the same in the app, the widget and the Live Activity. Feeding
/// is a rose heart, never a red drop.
extension LogType {
    static func color(_ t: String) -> Color {
        switch t {
        case nurse: Crayon.pink; case bottle: Crayon.peach; case sleep: Crayon.lilac; case diaper: Crayon.sky; case solid: Crayon.leaf
        case bath: Crayon.teal; case temp: Crayon.cherry; case medicine: Crayon.sunflower; case growth: Crayon.tangerine; case play: Crayon.teal
        default: Crayon.pebble
        }
    }
}
