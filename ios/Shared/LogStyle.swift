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
        case pink, rose: Color(red: 0xC7 / 255, green: 0x36 / 255, blue: 0x5C / 255)
        case sunflower: Color(red: 0x8A / 255, green: 0x5A / 255, blue: 0x00 / 255)
        case cherry: Color(red: 0xC2 / 255, green: 0x30 / 255, blue: 0x28 / 255)
        case sky: Color(red: 0x1F / 255, green: 0x6D / 255, blue: 0xB8 / 255)
        case tangerine, peach, caramel: Color(red: 0xB8 / 255, green: 0x55 / 255, blue: 0x0C / 255)
        case lilac: Color(red: 0x6A / 255, green: 0x48 / 255, blue: 0xC8 / 255)
        default: Color(red: 0x5A / 255, green: 0x54 / 255, blue: 0x4E / 255)
        }
    }
    /// The same colour, deep enough for text (≥ 4.5:1 on paper, cards and the dark page).
    static func ink(_ c: Color) -> Color {
        switch c {
        case teal, aqua, mint: dyn(0x0B7D74, 0x4FD8CB)
        case pink, rose: dyn(0xC7365C, 0xFF8FAA)
        case sunflower: dyn(0x8A5A00, 0xFFD36B)
        case cherry: dyn(0xC23028, 0xFF7A70)
        case sky: dyn(0x1F6DB8, 0x7DB8F2)
        case tangerine, peach, caramel: dyn(0xB8550C, 0xFFA066)
        case lilac: dyn(0x6A48C8, 0xB39CF4)
        default: c
        }
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
