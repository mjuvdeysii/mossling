import SwiftUI

/// Schema for `IconsManifest.json` enabling custom 3D soft-vinyl or 2D paper slices to override the built-in
/// procedural botanical vector glyphs seamlessly by asset filename or food/tool ID.
struct IconsManifest: Codable, Sendable {
    let version: String
    let tools: [ToolIconSpec]
    let foods: [FoodIconSpec]
}

struct ToolIconSpec: Codable, Hashable, Sendable {
    let id: String
    let asset3D: String
    let asset2D: String
    let fallbackSymbol: String
    let accentHex: String
}

struct FoodIconSpec: Codable, Hashable, Sendable {
    let id: String
    let asset3D: String
    let asset2D: String
    let category: String
    let glyphKind: String
    let primaryHex: String
    let secondaryHex: String
    let detailHex: String
}

/// Centralized resolver mapping studio tools and the 60 First Foods to either bundled 3D/2D artwork or bespoke
/// procedural SwiftUI Montessori vector artwork (with zero system Emoji fallback).
final class IconAssetResolver: @unchecked Sendable {
    static let shared = IconAssetResolver()

    let manifest: IconsManifest?
    private let toolsById: [String: ToolIconSpec]
    private let foodsById: [String: FoodIconSpec]

    init(bundle: Bundle = .main) {
        if let url = bundle.url(forResource: "IconsManifest", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(IconsManifest.self, from: data) {
            self.manifest = decoded
            self.toolsById = Dictionary(uniqueKeysWithValues: decoded.tools.map { ($0.id, $0) })
            self.foodsById = Dictionary(uniqueKeysWithValues: decoded.foods.map { ($0.id, $0) })
        } else {
            self.manifest = nil
            self.toolsById = [:]
            self.foodsById = [:]
        }
    }

    func toolSpec(for id: String) -> ToolIconSpec? {
        toolsById[id]
    }

    func foodSpec(for id: String) -> FoodIconSpec? {
        foodsById[id]
    }

    /// Resolves an optional bundled raster override (`Art/art/*.webp` or `Assets.xcassets`) respecting current `ArtStyle`.
    func bundledImage(asset3D: String, asset2D: String, maxPixel: Int = 192) -> UIImage? {
        let preferred = ArtStyle.current == .flat ? asset2D : asset3D
        let stem = (preferred as NSString).deletingPathExtension
        if let ui = UIImage(named: preferred) ?? UIImage(named: stem) {
            return ui
        }
        return ArtCache.shared.image(preferred, maxPixel: maxPixel)
    }

    static func color(hex: String, fallback: Color) -> Color {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return fallback }
        return Color(hex: value)
    }
}
