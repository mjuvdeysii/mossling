import UIKit
import Observation

/// Strictly local, offline transparent PNG cutout storage for bespoke First Foods stickers
/// under `Application Support/food_stickers/{foodId}.png`. Never uploaded or synced externally.
enum FoodStickerStore {
    static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("food_stickers", isDirectory: true)
    }

    nonisolated(unsafe) private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 64
        return c
    }()

    private static func isSafeFoodID(_ raw: String) -> Bool {
        !raw.isEmpty && raw.count <= 64 && raw.unicodeScalars.allSatisfy { s in
            ("a"..."z").contains(s) || ("A"..."Z").contains(s) || ("0"..."9").contains(s) || s == "_" || s == "-"
        }
    }

    static func url(for foodId: String, in dir: URL = folder) -> URL? {
        guard isSafeFoodID(foodId) else { return nil }
        let base = dir.standardizedFileURL
        let candidate = base.appendingPathComponent("\(foodId).png").standardizedFileURL
        let basePath = base.path.hasSuffix("/") ? base.path : base.path + "/"
        guard candidate.path.hasPrefix(basePath) else { return nil }
        return candidate
    }

    static func exists(for foodId: String, in dir: URL = folder) -> Bool {
        guard let target = url(for: foodId, in: dir) else { return false }
        return FileManager.default.fileExists(atPath: target.path)
    }

    @discardableResult
    static func save(_ image: UIImage, for foodId: String, maxDimension: CGFloat = 512, in dir: URL = folder) -> Bool {
        guard let target = url(for: foodId, in: dir) else { return false }
        let resized = downscalePreservingAlpha(image, maxDimension: maxDimension)
        guard let data = resized.pngData() else { return false }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try data.write(to: target, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            if dir == folder {
                cache.setObject(resized, forKey: foodId as NSString)
                Task { @MainActor in FoodStickerVersion.shared.bump() }
            }
            return true
        } catch {
            return false
        }
    }

    static func load(for foodId: String, in dir: URL = folder) -> UIImage? {
        guard let target = url(for: foodId, in: dir) else { return nil }
        if dir == folder, let hit = cache.object(forKey: foodId as NSString) {
            return hit
        }
        guard let data = try? Data(contentsOf: target), let img = UIImage(data: data) else { return nil }
        if dir == folder {
            cache.setObject(img, forKey: foodId as NSString)
        }
        return img
    }

    static func delete(for foodId: String, in dir: URL = folder) {
        guard let target = url(for: foodId, in: dir) else { return }
        try? FileManager.default.removeItem(at: target)
        if dir == folder {
            cache.removeObject(forKey: foodId as NSString)
            Task { @MainActor in FoodStickerVersion.shared.bump() }
        }
    }

    static func restoreRaw(_ data: Data, for foodId: String, in dir: URL = folder) {
        guard let target = url(for: foodId, in: dir) else { return }
        try? data.write(to: target, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        if dir == folder {
            if let img = UIImage(data: data) {
                cache.setObject(img, forKey: foodId as NSString)
            } else {
                cache.removeObject(forKey: foodId as NSString)
            }
            Task { @MainActor in FoodStickerVersion.shared.bump() }
        }
    }

    static func stickerCount(in dir: URL = folder) -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return 0
        }
        return files.filter { $0.pathExtension.lowercased() == "png" }.count
    }

    static func prune(keeping validFoodIDs: Set<String>, in dir: URL = folder) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for f in files where f.pathExtension.lowercased() == "png" {
            let foodId = f.deletingPathExtension().lastPathComponent
            if !validFoodIDs.contains(foodId) {
                try? FileManager.default.removeItem(at: f)
                if dir == folder { cache.removeObject(forKey: foodId as NSString) }
            }
        }
        if dir == folder {
            Task { @MainActor in FoodStickerVersion.shared.bump() }
        }
    }

    static func clearAll(in dir: URL = folder) {
        try? FileManager.default.removeItem(at: dir)
        if dir == folder {
            cache.removeAllObjects()
            Task { @MainActor in FoodStickerVersion.shared.bump() }
        }
    }

    private static func downscalePreservingAlpha(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let w = image.size.width * image.scale
        let h = image.size.height * image.scale
        let longest = max(w, h)
        guard longest > maxDimension, longest > 0 else { return image }
        let ratio = maxDimension / longest
        let targetSize = CGSize(width: floor(w * ratio), height: floor(h * ratio))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

/// Observable revision tick refreshing First Foods grid, greeting strip, and passports when custom stickers change.
@Observable
@MainActor
final class FoodStickerVersion {
    static let shared = FoodStickerVersion()
    private(set) var tick: Int = 0
    func bump() { tick &+= 1 }
}
