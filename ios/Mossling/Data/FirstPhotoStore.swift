import UIKit
import Observation

/// Strictly local, offline photo keepsake storage for "第一次 / Firsts" moments.
/// Photos chosen via SwiftUI's out-of-process `PhotosPicker` (requiring zero library permissions) are compressed
/// to max 1200px JPEG under `Application Support/first_photos/` and never leave the device.
enum FirstPhotoStore {
    static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("first_photos", isDirectory: true)
    }

    nonisolated(unsafe) private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 48
        return c
    }()

    static func url(for id: UUID, in dir: URL = folder) -> URL {
        dir.appendingPathComponent("\(id.uuidString).jpg")
    }

    static func exists(for id: UUID, in dir: URL = folder) -> Bool {
        FileManager.default.fileExists(atPath: url(for: id, in: dir).path)
    }

    /// Downscales `image` to at most `maxDimension` px on its longest side and saves as local JPEG.
    @discardableResult
    static func save(_ image: UIImage, for id: UUID, maxDimension: CGFloat = 1200, in dir: URL = folder) -> Bool {
        let resized = downscale(image, maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: 0.82) else { return false }
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let target = url(for: id, in: dir)
            try data.write(to: target, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            if dir == folder {
                cache.setObject(resized, forKey: id.uuidString as NSString)
                Task { @MainActor in FirstPhotoVersion.shared.bump() }
            }
            return true
        } catch {
            return false
        }
    }

    static func load(for id: UUID, in dir: URL = folder) -> UIImage? {
        if dir == folder, let hit = cache.object(forKey: id.uuidString as NSString) {
            return hit
        }
        let target = url(for: id, in: dir)
        guard let data = try? Data(contentsOf: target), let img = UIImage(data: data) else { return nil }
        if dir == folder {
            cache.setObject(img, forKey: id.uuidString as NSString)
        }
        return img
    }

    static func delete(for id: UUID, in dir: URL = folder) {
        try? FileManager.default.removeItem(at: url(for: id, in: dir))
        if dir == folder {
            cache.removeObject(forKey: id.uuidString as NSString)
            Task { @MainActor in FirstPhotoVersion.shared.bump() }
        }
    }

    static func restoreRaw(_ data: Data?, for id: UUID, in dir: URL = folder) {
        if let data {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: url(for: id, in: dir), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            if dir == folder {
                if let img = UIImage(data: data) {
                    cache.setObject(img, forKey: id.uuidString as NSString)
                } else {
                    cache.removeObject(forKey: id.uuidString as NSString)
                }
                Task { @MainActor in FirstPhotoVersion.shared.bump() }
            }
        } else {
            delete(for: id, in: dir)
        }
    }

    /// Removes orphaned photo files whose corresponding `First` entry was permanently deleted.
    static func prune(keeping validIDs: Set<UUID>, in dir: URL = folder) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for f in files where f.pathExtension.lowercased() == "jpg" {
            let stem = f.deletingPathExtension().lastPathComponent
            if let uid = UUID(uuidString: stem), !validIDs.contains(uid) {
                try? FileManager.default.removeItem(at: f)
                if dir == folder { cache.removeObject(forKey: stem as NSString) }
            }
        }
    }

    static func clearAll(in dir: URL = folder) {
        try? FileManager.default.removeItem(at: dir)
        if dir == folder {
            cache.removeAllObjects()
            Task { @MainActor in FirstPhotoVersion.shared.bump() }
        }
    }

    private static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let w = image.size.width * image.scale
        let h = image.size.height * image.scale
        let longest = max(w, h)
        guard longest > maxDimension, longest > 0 else { return image }
        let ratio = maxDimension / longest
        let targetSize = CGSize(width: floor(w * ratio), height: floor(h * ratio))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

/// Lightweight observable invalidation counter so Firsts rows, Growth Book, and Storybook refresh immediately when a photo changes.
@Observable
@MainActor
final class FirstPhotoVersion {
    static let shared = FirstPhotoVersion()
    private(set) var tick: Int = 0
    func bump() { tick &+= 1 }
}
