import Foundation
import SwiftUI
import Observation

/// Wax seal colors and motifs available when sealing a Time Capsule letter.
enum CapsuleSeal: String, CaseIterable, Codable, Identifiable, Sendable {
    case gold, teal, pink, lilac
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .gold: Palette.bead
        case .teal: Crayon.teal
        case .pink: Crayon.pink
        case .lilac: Crayon.lilac
        }
    }

    var symbol: String {
        switch self {
        case .gold: "sparkles"
        case .teal: "leaf.fill"
        case .pink: "heart.fill"
        case .lilac: "moon.stars.fill"
        }
    }

    var title: String {
        switch self {
        case .gold: L10n.t("暖金火漆", "Warm Gold")
        case .teal: L10n.t("苔绿火漆", "Moss Teal")
        case .pink: L10n.t("晚霞火漆", "Sunset Rose")
        case .lilac: L10n.t("夜灯紫漆", "Lamp Indigo")
        }
    }
}

/// A private, offline Time Capsule letter written by parents for their child's future birthday or quiet milestone.
struct TimeCapsule: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var title: String
    var body: String
    var writtenAt: Double
    var writtenAgeLabel: String
    /// Epoch day when the wax seal is ready to be broken; `nil` means open anytime.
    var unlockEpochDay: Int?
    /// Epoch ms when the wax seal was actually opened; `nil` while still sealed.
    var openedAt: Double?
    var seal: CapsuleSeal = .gold

    var writtenDay: Day {
        Day(Date(timeIntervalSince1970: writtenAt / 1000))
    }

    var unlockDay: Day? {
        unlockEpochDay.map { Day(epochDay: $0) }
    }

    var openedDay: Day? {
        openedAt.map { Day(Date(timeIntervalSince1970: $0 / 1000)) }
    }

    /// Number of calendar days elapsed between sealing and opening (or `referenceDay` if not yet opened).
    func sealedDays(on referenceDay: Day) -> Int {
        let endDay = openedDay ?? referenceDay
        return max(0, endDay.epochDay - writtenDay.epochDay)
    }

    func isLocked(on today: Day) -> Bool {
        if openedAt != nil { return false }
        guard let target = unlockEpochDay else { return false }
        return today.epochDay < target
    }

    func daysUntilUnlock(on today: Day) -> Int {
        guard let target = unlockEpochDay else { return 0 }
        return max(0, target - today.epochDay)
    }

    func isReadyToOpen(on today: Day) -> Bool {
        openedAt == nil && !isLocked(on: today)
    }

    /// Computes the exact epoch day of the child's N-th birthday safely across leap years.
    static func birthdayEpochDay(from birth: Day, years: Int) -> Int {
        birth.plus(months: max(1, years) * 12).epochDay
    }
}

/// Strictly local JSON persistence for Time Capsule letters under `Application Support/time_capsules.json`.
/// Never leaves the device and is wiped cleanly on `AppModel.clearAll()`.
@Observable
@MainActor
final class CapsuleStore {
    static let shared = CapsuleStore()

    private(set) var items: [TimeCapsule] = []
    private(set) var loadFailed = false
    private let fileURL: URL?

    nonisolated static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("time_capsules.json")
    }

    init(fileURL: URL? = CapsuleStore.defaultURL) {
        self.fileURL = fileURL
        reload()
    }

    /// In-memory store for deterministic previews and screenshot tests (never reads or writes disk).
    init(preview items: [TimeCapsule]) {
        self.fileURL = nil
        self.items = items.sorted { $0.writtenAt > $1.writtenAt }
    }

    func reload() {
        guard let url = fileURL else { return }
        guard FileManager.default.fileExists(atPath: url.path) else {
            loadFailed = false
            items = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([TimeCapsule].self, from: data)
            items = decoded.sorted { $0.writtenAt > $1.writtenAt }
            loadFailed = false
        } catch {
            loadFailed = true
        }
    }

    @discardableResult
    func save(_ capsule: TimeCapsule) -> Bool {
        guard !loadFailed else { return false }
        let prevItems = items
        if let idx = items.firstIndex(where: { $0.id == capsule.id }) {
            items[idx] = capsule
        } else {
            items.append(capsule)
        }
        items.sort { $0.writtenAt > $1.writtenAt }
        if persist() { return true }
        items = prevItems
        return false
    }

    @discardableResult
    func open(id: UUID, now: Double = Date().timeIntervalSince1970 * 1000) -> Bool {
        guard !loadFailed, let idx = items.firstIndex(where: { $0.id == id }) else { return false }
        if items[idx].openedAt == nil {
            let prev = items[idx]
            items[idx].openedAt = now
            if persist() { return true }
            items[idx] = prev
            return false
        }
        return true
    }

    @discardableResult
    func delete(id: UUID) -> Bool {
        guard !loadFailed else { return false }
        let prev = items
        items.removeAll { $0.id == id }
        if persist() { return true }
        items = prev
        return false
    }

    func clearAll() {
        loadFailed = false
        items = []
        if let url = fileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    @discardableResult
    func replaceAll(_ list: [TimeCapsule]) -> Bool {
        let prevItems = items
        let prevFailed = loadFailed
        loadFailed = false
        items = list.sorted { $0.writtenAt > $1.writtenAt }
        if persist() { return true }
        items = prevItems
        loadFailed = prevFailed
        return false
    }

    func readyCount(on today: Day) -> Int {
        items.filter { $0.isReadyToOpen(on: today) }.count
    }

    @discardableResult
    private func persist() -> Bool {
        guard !loadFailed, let url = fileURL else { return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(items)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }
}
