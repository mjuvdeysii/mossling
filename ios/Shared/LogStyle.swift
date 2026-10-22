import SwiftUI

/// The crayon box: a warm rainbow, as on a kindergarten shelf — cherry, tangerine, sunflower, leaf, sky, lilac, with
/// rose, aqua and caramel between them. Each has a lighter value for dark mode. Used for categories (areas of
/// development, kinds of entry) and the beads; surfaces and text stay the system's own.
enum Crayon {
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color {
        func ui(_ h: UInt32) -> UIColor { UIColor(red: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255, blue: CGFloat(h & 0xFF) / 255, alpha: 1) }
        return Color(UIColor { $0.userInterfaceStyle == .dark ? ui(dark) : ui(light) })
    }
    static let cherry = dyn(0xEF5B4C, 0xFF7466)
    static let rose = dyn(0xEE6F9A, 0xFF8AB0)
    static let tangerine = dyn(0xF58A1F, 0xFFA03D)
    static let sunflower = dyn(0xF2B526, 0xFFC94A)
    static let leaf = dyn(0x4DAF4E, 0x66CC66)
    static let aqua = dyn(0x2DB3A6, 0x45CDBF)
    static let sky = dyn(0x3E9BE0, 0x5CB2F2)
    static let lilac = dyn(0x8E6FDB, 0xA98CF0)
    static let caramel = dyn(0xC98A4B, 0xDDA066)
    static let pebble = dyn(0x9A9289, 0xA9A29A)
    /// The order of the rainbow, for things that cycle.
    static let rainbow = [cherry, tangerine, sunflower, leaf, sky, lilac, rose, aqua]
    /// The glyph on a crayon: white, except dark on the light sunflower.
    static func glyph(on c: Color) -> Color { c == sunflower ? Color(red: 0.29, green: 0.2, blue: 0) : .white }
}

/// Each kind of entry has one crayon and one SF Symbol, the same in the app, the widget and the Live Activity. Feeding
/// is a rose heart, never a red drop.
extension LogType {
    static func color(_ t: String) -> Color {
        switch t {
        case nurse: Crayon.rose; case bottle: Crayon.tangerine; case sleep: Crayon.lilac; case diaper: Crayon.sky; case solid: Crayon.leaf
        case bath: Crayon.aqua; case temp: Crayon.cherry; case medicine: Crayon.sunflower; case growth: Crayon.caramel; case play: Crayon.leaf
        default: Crayon.pebble
        }
    }
}
