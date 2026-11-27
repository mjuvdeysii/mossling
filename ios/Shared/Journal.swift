import Foundation
import CoreFoundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Shared privacy consent version validated by both the main app and WidgetKit/AppIntents extensions.
enum SharedConsent {
    static let version = "2026-11-27"
}

/// Fail-closed privacy gate shared by WidgetKit timelines, views, Control Center, and AppIntents.
enum WidgetPrivacy {
    static func isLocked(snap: Snapshot?) -> Bool {
        snap?.appLocked == true
    }

    static func canShowRecords(snap: Snapshot?) -> Bool {
        guard let s = snap else { return false }
        guard s.consented == true else { return false }
        if s.appLocked == true { return false }
        guard s.consentVersion == SharedConsent.version else { return false }
        return true
    }
}

/// The kinds of entry, with the same identifiers as on Android (so record files move between the two).
enum LogType {
    static let nurse = "nurse", bottle = "bottle", sleep = "sleep", diaper = "diaper", solid = "solid", bath = "bath"
    static let temp = "temp", medicine = "med", note = "note", play = "play"
    static let growth = "growth" // not an entry: opens the measurement sheet
    static func name(_ t: String) -> String {
        if L10n.isEnglish {
            switch t { case nurse: return "Nursing"; case bottle: return "Bottle"; case sleep: return "Sleep"; case diaper: return "Diaper"
            case solid: return "Solids"; case bath: return "Bath"; case temp: return "Temp"; case medicine: return "Medicine"; case note: return "Note"
            case play: return "Play"; case growth: return "Growth"; default: return t }
        }
        return switch t { case nurse: "亲喂"; case bottle: "瓶喂"; case sleep: "睡觉"; case diaper: "尿布"; case solid: "辅食"; case bath: "洗澡"
        case temp: "体温"; case medicine: "用药"; case note: "备注"; case play: "一起玩"; case growth: "生长"; default: t }
    }
    static func symbol(_ t: String) -> String {
        switch t { case nurse: "heart.fill"; case bottle: "waterbottle.fill"; case sleep: "moon.zzz.fill"; case diaper: "circle.bottomhalf.filled"
        case solid: "fork.knife"; case bath: "bathtub.fill"; case temp: "thermometer.medium"; case medicine: "pills.fill"; case note: "pencil"
        case play: "puzzlepiece.fill"; case growth: "ruler.fill"; default: "circle" }
    }
    static let timed: Set<String> = [nurse, sleep]
    static let buttons = [nurse, bottle, sleep, diaper, solid, bath, temp, medicine, growth, note]
}

struct LogEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var type: String
    var start: Double            // ms since 1970, as on Android
    var end: Double? = nil
    var amount: Int? = nil       // ml for a bottle; tenths of a degree for a temperature
    var side: String? = nil      // "l" / "r"
    var detail: String? = nil
    var startDate: Date { Date(timeIntervalSince1970: start / 1000) }
    var endDate: Date? { end.map { Date(timeIntervalSince1970: $0 / 1000) } }

    enum CodingKeys: String, CodingKey { case id, type, start, end, amount, side, detail }

    init(id: UUID = UUID(), type: String, start: Double, end: Double? = nil, amount: Int? = nil, side: String? = nil, detail: String? = nil) {
        self.id = id
        self.type = type
        self.start = start.isFinite ? start : 0
        self.end = end.flatMap { $0.isFinite ? $0 : nil }
        self.amount = amount
        self.side = side
        self.detail = Self.sanitizedDetail(detail)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        type = try c.decode(String.self, forKey: .type)
        let rawStart = try c.decode(Double.self, forKey: .start)
        start = rawStart.isFinite ? rawStart : 0
        let rawEnd = try c.decodeIfPresent(Double.self, forKey: .end)
        end = rawEnd.flatMap { $0.isFinite ? $0 : nil }
        amount = try c.decodeIfPresent(Int.self, forKey: .amount)
        side = try c.decodeIfPresent(String.self, forKey: .side)
        detail = Self.sanitizedDetail(try c.decodeIfPresent(String.self, forKey: .detail))
    }

    private static func sanitizedDetail(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return raw }
        let parts = raw.split(separator: ";", omittingEmptySubsequences: false).map { part -> String in
            guard part.hasPrefix("paused:") else { return String(part) }
            let valStr = String(part.dropFirst(7))
            guard let ms = Double(valStr), ms.isFinite, ms > 0 else { return "paused:0" }
            let clamped = min(7.0 * 86_400_000.0, ms)
            return "paused:\(Int64(clamped.rounded()))"
        }
        return parts.joined(separator: ";")
    }

    var summary: String {
        if L10n.isEnglish {
            switch type {
            case LogType.nurse: return [side == "l" ? "Left" : side == "r" ? "Right" : nil, end.map { _ in minutesOf(activeSeconds) }].compactMap { $0 }.joined(separator: " · ")
            case LogType.sleep: return end.map { _ in minutesOf(activeSeconds) } ?? "In progress"
            case LogType.bottle: return [milk, L10n.volume(ml: amount ?? 0)].compactMap { $0 }.joined(separator: " · ")
            case LogType.diaper: return ["wet": "Wet", "dirty": "Dirty", "both": "Wet + dirty"][detail ?? ""] ?? ""
            case LogType.temp: return amount.map { L10n.temperature(tenthsC: $0) } ?? ""
            default: return detail ?? ""
            }
        }
        switch type {
        case LogType.nurse: return [side == "l" ? "左侧" : side == "r" ? "右侧" : nil, end.map { _ in minutesOf(activeSeconds) }].compactMap { $0 }.joined(separator: " · ")
        case LogType.sleep: return end.map { _ in minutesOf(activeSeconds) } ?? "进行中"
        case LogType.bottle: return [milk, "\(amount ?? 0) 毫升"].compactMap { $0 }.joined(separator: " ")
        case LogType.diaper: return ["wet": "湿", "dirty": "便", "both": "湿和便"][detail ?? ""] ?? ""
        case LogType.temp: return amount.map { String(format: "%.1f °C", Double($0) / 10) } ?? ""
        default: return detail ?? ""
        }
    }
}

extension LogEntry {
    /// What was in the bottle: expressed breast milk or formula ("breastmilk" / "formula" in `detail`; older entries
    /// and entries from the Android app have none).
    var milk: String? {
        guard type == LogType.bottle else { return nil }
        if L10n.isEnglish { return detail == "breastmilk" ? "Breast milk" : detail == "formula" ? "Formula" : nil }
        return detail == "breastmilk" ? "母乳" : detail == "formula" ? "配方奶" : nil
    }
    /// Time the timer was paused, as written by both apps in `detail` ("paused:<ms>", optionally followed by ";new").
    var pausedSeconds: Double {
        guard let d = detail else { return 0 }
        for part in d.split(separator: ";") where part.hasPrefix("paused:") {
            if let ms = Double(part.dropFirst(7)), ms.isFinite, ms > 0 {
                return min(7 * 86_400, ms / 1000)
            }
        }
        return 0
    }
    /// Explicitly starts a fresh feed rather than auto-joining the previous feed within `Feed.join`.
    var startsSeparateFeed: Bool {
        detail?.split(separator: ";").contains("new") == true
    }
    /// How long it really lasted: from start to end, less any pause.
    var activeSeconds: Double {
        guard let e = end else { return 0 }
        return max(0, (e - start) / 1000 - pausedSeconds)
    }
    /// The part of the entry that falls on a day, in seconds, less pauses. A sleep across midnight counts on each day
    /// for its part. Where in the span a pause fell is not recorded, so a pause is shared out in proportion.
    func seconds(on day: Day) -> Double {
        guard let e = end, e > start else { return 0 }
        let a = day.date.timeIntervalSince1970 * 1000, b = day.plus(days: 1).date.timeIntervalSince1970 * 1000
        let part = max(0, min(e, b) - max(start, a)) / 1000
        return part * activeSeconds / ((e - start) / 1000)
    }
    /// Whether it began on the day before the given day.
    func carriedOver(into day: Day) -> Bool { start < day.date.timeIntervalSince1970 * 1000 }
}

/// One feed: a bottle, or a breast feed — one side, or one side then the other, each entry starting within two
/// minutes of the one before ending. The one definition of 「一顿」: every count, interval, last-feed line, side list and
/// widget reads feeds from here.
struct Feed: Hashable {
    /// How close the next side must follow for it to be the same feed.
    static let join: Double = 120_000
    /// The entries of the feed, oldest first (a bottle has one).
    var entries: [LogEntry]
    var start: Double { entries[0].start }
    var end: Double? { entries[entries.count - 1].end }
    var isBottle: Bool { entries[0].type == LogType.bottle }
    var first: LogEntry { entries[0] }
    /// The sides in the order fed, with their seconds (a side fed twice is listed twice, as it happened).
    var sides: [(side: String, seconds: Double)] {
        entries.filter { $0.type == LogType.nurse }.map { ($0.side ?? "l", $0.activeSeconds) }
    }
    var activeSeconds: Double { entries.reduce(0) { $0 + $1.activeSeconds } }
    var pausedSeconds: Double { entries.reduce(0) { $0 + $1.pausedSeconds } }
    var startDate: Date { Date(timeIntervalSince1970: start / 1000) }
}

extension Array where Element == LogEntry {
    /// The feeds among these entries, oldest first.
    func feeds() -> [Feed] {
        var out: [Feed] = []
        for e in filter({ $0.type == LogType.nurse || $0.type == LogType.bottle }).sorted(by: { $0.start < $1.start }) {
            if e.type == LogType.nurse, !e.startsSeparateFeed, let p = out.last?.entries.last, p.type == LogType.nurse, e.start - (p.end ?? p.start) <= Feed.join {
                out[out.count - 1].entries.append(e)
            } else {
                out.append(Feed(entries: [e]))
            }
        }
        return out
    }
    /// The rows of a time line: one per entry, except the sides of one breast feed, which make one row (one feed, one
    /// row — so the rows a parent counts are the feeds the summary counts). Each row's entries are oldest first.
    func rows() -> [[LogEntry]] {
        let joined = feeds().filter { $0.entries.count > 1 }
        let inFeed = Set(joined.flatMap { $0.entries.map(\.id) })
        return joined.map(\.entries) + filter { !inFeed.contains($0.id) }.map { [$0] }
    }
    /// The number of feeds. Pass `from` to count only feeds that began at or after it (a day's feeds: a feed begun
    /// before midnight and carried on after it belongs to the day before).
    func feedCount(from: Double = -.infinity) -> Int { feeds().filter { $0.start >= from }.count }
    /// The sides of the breast feed that ends where `start` begins (a timer carrying on that feed): seconds per side.
    func feedSides(before start: Double) -> [String: Double] {
        guard let f = feeds().last(where: { !$0.isBottle && $0.start < start && $0.end.map { abs($0 - start) <= Feed.join } == true }) else { return [:] }
        return f.sides.reduce(into: [:]) { $0[$1.side, default: 0] += $1.seconds }
    }
}

/// "刚刚", "25 分前", "3 小时前", "2 天前" — the one way the app and its widgets say how long ago. `precise` keeps the
/// minutes past the hour for the first ten hours ("2 小时 30 分前"), where a glance at a widget needs them. The clock is
/// passed in, never read here, so a test can say what time it is.
func ago(_ then: Date, now: Date, precise: Bool = false) -> String {
    let m = Int(now.timeIntervalSince(then) / 60)
    if L10n.isEnglish {
        if m < 2 { return "just now" }
        if m < 60 { return "\(m) min ago" }
        if precise && m < 600 && m % 60 != 0 { return "\(m / 60) hr \(m % 60) min ago" }
        if m < 48 * 60 { return "\(m / 60) hr ago" }
        return "\(m / 1440) days ago"
    }
    if m < 2 { return "刚刚" }
    if m < 60 { return "\(m) 分前" }
    if precise && m < 600 && m % 60 != 0 { return "\(m / 60) 小时 \(m % 60) 分前" }
    if m < 48 * 60 { return "\(m / 60) 小时前" }
    return "\(m / 1440) 天前"
}

/// The last time something was done, with what to say about it: a feed by when it began, a sleep by when the baby
/// woke, anything else by when it happened. Shared by the app and the widgets, so both say the same.
struct LastFact {
    let label: String
    let at: Date
    let note: String?

    static func of(_ type: String, in logs: [LogEntry], before: Double = .infinity) -> LastFact? {
        let older = logs.filter { $0.start < before }
        switch type {
        case LogType.nurse, LogType.bottle:
            guard let f = older.feeds().last else { return nil }
            if L10n.isEnglish {
                let note = f.isBottle ? "Bottle · " + L10n.volume(ml: f.first.amount ?? 0)
                    : "Nursing · " + f.sides.map { $0.side == "l" ? "Left" : "Right" }.joined(separator: " → ")
                return LastFact(label: "Last feed", at: f.startDate, note: note)
            }
            let note = f.isBottle ? "瓶喂 \(f.first.amount ?? 0) 毫升"
                : "亲喂 · " + f.sides.map { $0.side == "l" ? "左侧" : "右侧" }.joined(separator: " → ")
            return LastFact(label: "上次喂奶", at: f.startDate, note: note)
        case LogType.sleep:
            guard let s = older.filter({ $0.type == LogType.sleep && $0.end != nil }).max(by: { $0.start < $1.start }), let e = s.endDate else { return nil }
            if L10n.isEnglish { return LastFact(label: "Last woke", at: e, note: "Slept " + minutesOf(s.activeSeconds)) }
            return LastFact(label: "上次醒来", at: e, note: "睡了 " + minutesOf(s.activeSeconds))
        default:
            guard let e = older.filter({ $0.type == type }).max(by: { $0.start < $1.start }) else { return nil }
            if L10n.isEnglish {
                return LastFact(label: type == LogType.diaper ? "Last change" : "Last " + LogType.name(type).lowercased(), at: e.startDate, note: e.summary.isEmpty ? nil : e.summary)
            }
            return LastFact(label: type == LogType.diaper ? "上次换尿布" : "上次" + LogType.name(type), at: e.startDate, note: e.summary.isEmpty ? nil : e.summary)
        }
    }
    /// 「上次喂奶 25 分前」: the one sentence for the last time, wherever it is said.
    func phrase(now: Date, precise: Bool = false) -> String { label + " " + ago(at, now: now, precise: precise) }
}

/// A running timer's state, one way everywhere (widget, Live Activity, home, records): 「亲喂 · 右侧 · 已暂停」.
func timerState(_ type: String, side: String?, paused: Bool) -> String {
    if L10n.isEnglish { return LogType.name(type) + (side == "l" ? " · Left" : side == "r" ? " · Right" : "") + (paused ? " · Paused" : "") }
    return LogType.name(type) + (side == "l" ? " · 左侧" : side == "r" ? " · 右侧" : "") + (paused ? " · 已暂停" : "")
}

/// One way to write a length of time everywhere (app, widget, Live Activity): "18 分钟", "1 小时 5 分", "2 小时".
func minutesOf(_ s: Double) -> String {
    let m = Int((max(0, s) / 60).rounded(.down))
    if L10n.isEnglish {
        if m < 60 { return "\(m) min" }
        if m >= 48 * 60 { let h = m / 60; return h % 24 == 0 ? "\(h / 24) days" : "\(h / 24) d \(h % 24) hr" }
        return m % 60 == 0 ? "\(m / 60) hr" : "\(m / 60) hr \(m % 60) min"
    }
    if m < 60 { return "\(m) 分钟" }
    if m >= 48 * 60 { let h = m / 60; return h % 24 == 0 ? "\(h / 24) 天" : "\(h / 24) 天 \(h % 24) 小时" }
    return m % 60 == 0 ? "\(m / 60) 小时" : "\(m / 60) 小时 \(m % 60) 分"
}

/// A timer that is running (at most one per kind). Survives the app being closed.
struct RunningTimer: Codable, Hashable {
    var type: String
    var start: Double
    var side: String? = nil
    var pausedAt: Double? = nil
    var pausedTotal: Double = 0
    /// Time already fed on earlier sides of this same feed (ms). Changing sides starts a new side, not a new feed:
    /// every clock shows the whole feed, so a side change never looks like a reset.
    var carried: Double = 0
    /// Pauses already taken on earlier sides of this feed (ms), so the screen can show the whole feed's pauses.
    var carriedPause: Double = 0
    /// Entry IDs written by earlier `switchingSide` calls within this active timer so `discard` removes them atomically.
    var sessionEntryIDs: [UUID] = []
    /// Explicit user boundary set after discarding an accidental timer so the next feed will not stitch onto an earlier feed.
    var detached: Bool = false
    /// This side so far, in seconds.
    func elapsed(_ now: Double) -> Double { max(0, ((pausedAt ?? now) - start - pausedTotal) / 1000) }
    /// The whole feed (or sleep) so far, in seconds.
    func total(_ now: Double) -> Double { elapsed(now) + carried / 1000 }
    /// The moment a clock counting the whole feed would have started at (for timers that count up from a date).
    var countsFrom: Date { Date(timeIntervalSince1970: (start + pausedTotal - carried) / 1000) }
    /// All the pauses of the whole feed (or sleep) so far, in seconds, the one under way included.
    func paused(_ now: Double) -> Double { (carriedPause + pausedTotal + (pausedAt.map { max(0, now - $0) } ?? 0)) / 1000 }

    enum CodingKeys: String, CodingKey { case type, start, side, pausedAt, pausedTotal, carried, carriedPause, sessionEntryIDs, detached }
    init(type: String, start: Double, side: String? = nil, pausedAt: Double? = nil, pausedTotal: Double = 0, carried: Double = 0, carriedPause: Double = 0, sessionEntryIDs: [UUID] = [], detached: Bool = false) {
        self.type = type
        self.start = start.isFinite ? start : 0
        self.side = side
        self.pausedAt = pausedAt.flatMap { $0.isFinite && $0 >= self.start ? $0 : nil }
        let maxSpan: Double = 7 * 86_400_000
        self.pausedTotal = pausedTotal.isFinite ? max(0, min(maxSpan, pausedTotal)) : 0
        self.carried = carried.isFinite ? max(0, min(maxSpan, carried)) : 0
        self.carriedPause = carriedPause.isFinite ? max(0, min(maxSpan, carriedPause)) : 0
        self.sessionEntryIDs = sessionEntryIDs
        self.detached = detached
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        let rawStart = try c.decode(Double.self, forKey: .start)
        let clampedStart = rawStart.isFinite ? max(-2_208_988_800_000, min(4_102_444_800_000, rawStart)) : 0
        start = clampedStart
        side = try c.decodeIfPresent(String.self, forKey: .side)
        let rawPausedAt = try c.decodeIfPresent(Double.self, forKey: .pausedAt)
        pausedAt = rawPausedAt.flatMap { $0.isFinite && $0 >= clampedStart && $0 <= 4_102_444_800_000 ? $0 : nil }
        let maxSpan: Double = 7 * 86_400_000
        let rawPausedTotal = try c.decodeIfPresent(Double.self, forKey: .pausedTotal) ?? 0
        pausedTotal = rawPausedTotal.isFinite ? max(0, min(maxSpan, rawPausedTotal)) : 0
        let rawCarried = try c.decodeIfPresent(Double.self, forKey: .carried) ?? 0
        carried = rawCarried.isFinite ? max(0, min(maxSpan, rawCarried)) : 0
        let rawCarriedPause = try c.decodeIfPresent(Double.self, forKey: .carriedPause) ?? 0
        carriedPause = rawCarriedPause.isFinite ? max(0, min(maxSpan, rawCarriedPause)) : 0
        sessionEntryIDs = try c.decodeIfPresent([UUID].self, forKey: .sessionEntryIDs) ?? []
        detached = try c.decodeIfPresent(Bool.self, forKey: .detached) ?? false
    }
}

struct Measure: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var at: Double
    var weightG: Int? = nil
    var lengthMm: Int? = nil
    var headMm: Int? = nil
}

/// A first (第一次): the first time the child did something worth keeping — sucked a hand, cooed, rolled over, sat,
/// crawled. `key` is one of the common firsts (Firsts.all) or nil for one the parent named.
struct First: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var at: Double                 // ms since 1970: the day it happened (noon, as measurements)
    var key: String? = nil
    var title: String
    var note: String? = nil
    var date: Date { Date(timeIntervalSince1970: at / 1000) }
}

/// What the widget needs to know without opening the content: written by the app whenever it changes.
struct PlayRef: Codable, Hashable {
    var code: String
    var name: String
}

struct Snapshot: Codable {
    var birthEpochDay: Int?
    var nickname: String
    var companion: String
    var journal: Bool
    var playCode: String?
    var playName: String?
    /// Whether the guardian has agreed to the current rules; nil in files written by v1.0.0.
    var consented: Bool? = nil
    /// Curated plays for this week/month so the Home Screen widget can cycle activities interactively.
    var weekPlays: [PlayRef]? = nil
    /// Epoch day when the user swapped today's play from a widget, so the main app adopts the pick on return.
    var playPickedEpochDay: Int? = nil
    /// Preterm gestational weeks at birth (22...36 when preterm; nil or >=37 otherwise) for dual-track Widget sync.
    var gestationalWeeks: Int? = nil
    /// Active adaptive care gear (1...4 from `CareGear`).
    var careGearRaw: Int? = nil
    /// Whether manual low-burden Care Mode is enabled (sick/growth-spurt days).
    var careModeActive: Bool? = nil
    /// Log/module keys gently graduated by parent (e.g. `"feeds"`, `"diaper"`).
    var graduatedModules: [String]? = nil
    /// Whether app lock is currently engaged or enabled so Siri / Shortcuts never speak child data while locked.
    var appLocked: Bool? = nil
    /// Privacy policy / consent version recorded alongside `consented`.
    var consentVersion: String? = nil
}

extension Snapshot {
    /// Resolves developmental age (preterm corrected under 24 chronological months, chronological otherwise).
    func developmentalAge(on today: Day) -> (age: Age, isCorrected: Bool)? {
        guard let birthEpochDay else { return nil }
        let birth = Day(epochDay: birthEpochDay)
        if let corrected = Age.corrected(birth: birth, gestationalWeeks: gestationalWeeks, today: today) {
            return (corrected, true)
        }
        return (Age.on(birth: birth, today: today), false)
    }

    /// Short bilingual badge summarizing Care Mode or Adaptive Gear for Home Screen & StandBy widgets.
    func careBadgeLabel() -> String? {
        if careModeActive == true {
            return L10n.t("减负照护", "Care Mode")
        }
        guard let careGearRaw else { return nil }
        switch careGearRaw {
        case 1: return L10n.t("一档·护航", "Gear 1")
        case 2: return L10n.t("二档·探索", "Gear 2")
        case 3: return L10n.t("三档·自主", "Gear 3")
        case 4: return L10n.t("四档·对话", "Gear 4")
        default: return nil
        }
    }

    var isFeedsGraduated: Bool { graduatedModules?.contains("feeds") == true }
    var isDiaperGraduated: Bool { graduatedModules?.contains("diaper") == true }
}

/// The journal file, shared with the widget and the Live Activity through the app group.
enum JournalFile {
    static let group = "group.app.mossling"
    static var groupDir: URL? {
        #if DEBUG
        if let t = testDir { return t }
        #endif
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
    }
    static var dir: URL {
        #if DEBUG
        if let t = testDir { return t }
        #endif
        return groupDir
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    #if DEBUG
    /// Tests write their journal here, a folder of their own — never the real one.
    nonisolated(unsafe) static var testDir: URL?
    /// A fresh, empty folder for a test's journal; call `endTest()` after.
    static func beginTest() {
        let u = FileManager.default.temporaryDirectory.appendingPathComponent("journal-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        testDir = u
    }
    static func endTest() {
        if let u = testDir { try? FileManager.default.removeItem(at: u) }
        testDir = nil; failWrites = false
    }
    #endif
    static var url: URL { dir.appendingPathComponent("journal.json") }
    static var snapshotURL: URL { dir.appendingPathComponent("snapshot.json") }
    static let darwinNotificationName = "app.mossling.journalChanged" as CFString
    /// Signals other processes (app ↔ widgets / Control Center / Live Activities) that shared data changed.
    static func notifyChanged() {
        #if DEBUG
        if testDir != nil { return }
        #endif
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(darwinNotificationName), nil, nil, true)
    }

    private struct AnyDecodableSkip: Decodable {
        init(from decoder: Decoder) throws {}
    }

    private struct LossyArray<Element: Decodable>: Decodable {
        let elements: [Element]
        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            var items: [Element] = []
            while !container.isAtEnd {
                if let item = try? container.decode(Element.self) {
                    items.append(item)
                } else {
                    _ = try? container.decode(AnyDecodableSkip.self)
                }
            }
            elements = items
        }
    }

    struct Body: Codable {
        var logs: [LogEntry] = []; var timers: [RunningTimer] = []; var measures: [Measure] = []
        /// The child's firsts (第一次), a line of their own that is never cut by dates.
        var firsts: [First] = []
        init() {}
        // every field may be missing in a file written by an earlier build: read what is there, never fail the whole
        // file (a failed read would show an empty journal)
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            logs = (try? c.decodeIfPresent(LossyArray<LogEntry>.self, forKey: .logs))?.elements ?? []
            timers = (try? c.decodeIfPresent(LossyArray<RunningTimer>.self, forKey: .timers))?.elements ?? []
            measures = (try? c.decodeIfPresent(LossyArray<Measure>.self, forKey: .measures))?.elements ?? []
            firsts = (try? c.decodeIfPresent(LossyArray<First>.self, forKey: .firsts))?.elements ?? []
        }
    }

    enum MutationResult {
        case saved(before: Body, after: Body)
        case unchanged(Body)
        case failed
    }

    /// Builds signed before the app group was set up kept the journal in the app's own Documents folder. Once the
    /// group exists, move it there (once), so nothing recorded earlier is lost and the widget sees it too.
    static func migrateIntoGroup() {
        guard let g = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for name in ["journal.json", "snapshot.json"] {
            let old = docs.appendingPathComponent(name), new = g.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: old.path) else { continue }
            if !FileManager.default.fileExists(atPath: new.path) {
                do {
                    try FileManager.default.copyItem(at: old, to: new)
                    try? FileManager.default.moveItem(at: old, to: docs.appendingPathComponent(name + ".moved"))
                } catch {
                    // Preserve original file in Documents if copying into App Group fails
                }
            } else {
                try? FileManager.default.moveItem(at: old, to: docs.appendingPathComponent(name + ".moved"))
            }
        }
    }

    private static func readUnlocked(at u: URL) throws -> Body {
        guard FileManager.default.fileExists(atPath: u.path) else { return Body() }
        let data = try Data(contentsOf: u)
        return try JSONDecoder().decode(Body.self, from: data)
    }

    private static func writeUnlocked(_ b: Body, to u: URL) -> Bool {
        #if DEBUG
        if failWrites { return false }
        #endif
        guard let data = try? JSONEncoder().encode(b) else { return false }
        do { try data.write(to: u, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]); return true } catch { return false }
    }

    /// Reads the journal under file coordination. Returns an empty body only when the file does not exist yet; throws
    /// on I/O or decode errors so callers never overwrite an unreadable file with an empty one.
    static func load() throws -> Body {
        var coordError: NSError?
        var result: Result<Body, Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordError) { target in
            do { result = .success(try readUnlocked(at: target)) }
            catch { result = .failure(error) }
        }
        if let coordError { throw coordError }
        return try result.get()
    }

    static func read() -> Body { (try? load()) ?? Body() }

    /// Strictly reads an existing journal inside the App Group container (or `testDir` in DEBUG) for media pruning.
    /// Never falls back to Documents and returns `nil` when the container or file is missing or unreadable so startup
    /// pruning never deletes local photos or voice clips due to a transient container lookup failure.
    static func loadExistingForPrune() -> Body? {
        guard let container = groupDir else { return nil }
        let targetURL = container.appendingPathComponent("journal.json")
        guard FileManager.default.fileExists(atPath: targetURL.path) else { return nil }
        var coordError: NSError?
        var decoded: Body?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: targetURL, options: [], error: &coordError) { target in
            guard FileManager.default.fileExists(atPath: target.path),
                  let data = try? Data(contentsOf: target),
                  let body = try? JSONDecoder().decode(Body.self, from: data) else {
                return
            }
            decoded = body
        }
        return coordError == nil ? decoded : nil
    }

    /// Writes the journal under file coordination; false when it could not be saved (the caller says so and keeps what was typed).
    @discardableResult static func write(_ b: Body) -> Bool {
        #if DEBUG
        if failWrites { return false }
        #endif
        var coordError: NSError?
        var ok = false
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: [], error: &coordError) { target in
            ok = writeUnlocked(b, to: target)
        }
        let saved = coordError == nil && ok
        if saved { notifyChanged() }
        return saved
    }

    /// Coordinated read-modify-write across app and widget processes. If the existing file cannot be read or decoded,
    /// returns `.failed` without overwriting it.
    static func mutate(_ transform: (inout Body) -> Bool) -> MutationResult {
        var coordError: NSError?
        var outcome: MutationResult = .failed
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: [], error: &coordError) { target in
            guard let before = try? readUnlocked(at: target) else { outcome = .failed; return }
            var after = before
            guard transform(&after) else { outcome = .unchanged(before); return }
            outcome = writeUnlocked(after, to: target) ? .saved(before: before, after: after) : .failed
        }
        let finalOutcome = coordError == nil ? outcome : .failed
        if case .saved = finalOutcome { notifyChanged() }
        return finalOutcome
    }

    private static func applyMutation(_ transform: (inout Body) -> Bool) -> Body {
        switch mutate(transform) {
        case let .saved(_, after): return after
        case let .unchanged(b): return b
        case .failed: return read()
        }
    }

    #if DEBUG
    /// Tests only: every write fails, to check that nothing celebrates a save that did not happen.
    nonisolated(unsafe) static var failWrites = false
    #endif
    static func snapshot() -> Snapshot? {
        var coordError: NSError?
        var snap: Snapshot?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: snapshotURL, options: [], error: &coordError) { target in
            snap = (try? Data(contentsOf: target)).flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) }
        }
        return coordError == nil ? snap : nil
    }
    static func writeSnapshot(_ s: Snapshot) {
        guard let data = try? JSONEncoder().encode(s) else { return }
        var coordError: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: snapshotURL, options: [], error: &coordError) { target in
            try? data.write(to: target, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    // Timer operations, shared by the app, the Live Activity buttons and the widget.
    static func now() -> Double { Date().timeIntervalSince1970 * 1000 }
    /// Suggests the nursing side not fed last time (matches CareTimer's alternating recommendation).
    static func suggestedNurseSide(in logs: [LogEntry]) -> String {
        logs.filter { $0.type == LogType.nurse }.max { $0.start < $1.start }?.side == "l" ? "r" : "l"
    }
    @discardableResult static func start(_ type: String, side: String? = nil, at: Double = now()) -> Body {
        applyMutation { b in
            guard !b.timers.contains(where: { $0.type == type }) else { return false }
            b.timers.append(RunningTimer(type: type, start: at, side: side))
            return true
        }
    }
    /// Starts a timer from a widget / Control Center / Siri, picking the suggested opposite side for nursing.
    @discardableResult static func startSmart(_ type: String, at: Double = now()) -> Body {
        applyMutation { b in
            guard !b.timers.contains(where: { $0.type == type }) else { return false }
            let chosenSide = type == LogType.nurse ? suggestedNurseSide(in: b.logs) : nil
            b.timers.append(RunningTimer(type: type, start: at, side: chosenSide))
            return true
        }
    }
    /// Variant of `startSmart` reporting whether the coordinated write persisted to disk.
    static func tryStartSmart(_ type: String, at: Double = now()) -> Bool {
        switch mutate({ b in
            guard !b.timers.contains(where: { $0.type == type }) else { return false }
            let chosenSide = type == LogType.nurse ? suggestedNurseSide(in: b.logs) : nil
            b.timers.append(RunningTimer(type: type, start: at, side: chosenSide))
            return true
        }) {
        case .saved, .unchanged: return true
        case .failed: return false
        }
    }
    /// Appends a single instant entry (diaper, quick bottle, etc.) under file coordination from a widget or shortcut.
    @discardableResult static func quickLog(type: String, detail: String? = nil, amount: Int? = nil, at: Double = now()) -> Body {
        applyMutation { b in
            b.logs.append(LogEntry(type: type, start: at, amount: amount, detail: detail))
            return true
        }
    }
    /// Variant of `quickLog` reporting whether the coordinated write persisted to disk.
    static func tryQuickLog(type: String, detail: String? = nil, amount: Int? = nil, at: Double = now()) -> Bool {
        if case .saved = mutate({ b in
            b.logs.append(LogEntry(type: type, start: at, amount: amount, detail: detail))
            return true
        }) {
            return true
        }
        return false
    }
    /// Removes the most recent entry of `type` if logged within `withinSeconds`, enabling safe 1-tap widget undo.
    @discardableResult static func undoRecent(type: String, withinSeconds: Double = 30, now n: Double = now()) -> Bool {
        switch mutate({ b in
            guard let idx = b.logs.lastIndex(where: { $0.type == type && (n - $0.start) >= 0 && (n - $0.start) <= withinSeconds * 1000 }) else {
                return false
            }
            b.logs.remove(at: idx)
            return true
        }) {
        case .saved: return true
        case .unchanged, .failed: return false
        }
    }
    /// Atomically rotates `playCode` / `playName` in `snapshot.json` to the next play in `weekPlays` under file coordination.
    @discardableResult static func cycleWidgetPlay() -> Snapshot? {
        var coordError: NSError?
        var updated: Snapshot?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: snapshotURL, options: [], error: &coordError) { target in
            guard let data = try? Data(contentsOf: target),
                  var s = try? JSONDecoder().decode(Snapshot.self, from: data),
                  let pool = s.weekPlays, pool.count >= 2 else { return }
            let cur = pool.firstIndex { $0.code == s.playCode } ?? -1
            let next = pool[(cur + 1) % pool.count]
            s.playCode = next.code
            s.playName = next.name
            s.playPickedEpochDay = Day.today.epochDay
            guard let out = try? JSONEncoder().encode(s) else { return }
            do {
                try out.write(to: target, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                updated = s
            } catch {
                updated = nil
            }
        }
        guard coordError == nil, let result = updated else { return nil }
        notifyChanged()
        return result
    }
    @discardableResult static func togglePause(_ type: String) -> Body {
        applyMutation { b in
            guard b.timers.contains(where: { $0.type == type }) else { return false }
            b = pausing(b, type, now: now())
            return true
        }
    }
    static func pausing(_ b0: Body, _ type: String, now n: Double) -> Body {
        var b = b0
        if let i = b.timers.firstIndex(where: { $0.type == type }) {
            if let p = b.timers[i].pausedAt { b.timers[i].pausedTotal += max(0, n - p); b.timers[i].pausedAt = nil } else { b.timers[i].pausedAt = n }
        }
        return b
    }
    /// A tap on one side of a feed, the one gesture of the feeding screen: on the side being fed it pauses (or goes
    /// on); on the other side it changes sides and runs.
    @discardableResult static func tapSide(_ type: String, _ side: String) -> Body {
        applyMutation { b in
            guard b.timers.contains(where: { $0.type == type }) else { return false }
            b = tappingSide(b, type, side, now: now())
            return true
        }
    }
    static func tappingSide(_ b: Body, _ type: String, _ side: String, now n: Double) -> Body {
        guard let t = b.timers.first(where: { $0.type == type }) else { return b }
        return (t.side ?? "l") == side ? pausing(b, type, now: n) : switchingSide(b, type, now: n)
    }
    /// Changing sides during a feed: the side so far is written as its own entry and the timer goes on for the other
    /// side from now (and runs again if it was paused). A side of under 30 seconds is not worth an entry: the side is
    /// just changed. Each side stays a plain nurse entry, so the file reads the same in the Android app.
    @discardableResult static func switchSide(_ type: String) -> Body {
        applyMutation { b in
            guard b.timers.contains(where: { $0.type == type }) else { return false }
            b = switchingSide(b, type, now: now())
            return true
        }
    }
    private static func nurseDetail(pausedMs: Double, separate: Bool) -> String? {
        var tokens: [String] = []
        if pausedMs > 0 { tokens.append("paused:\(Int(pausedMs))") }
        if separate { tokens.append("new") }
        return tokens.isEmpty ? nil : tokens.joined(separator: ";")
    }
    static func switchingSide(_ b0: Body, _ type: String, now n: Double) -> Body {
        var b = b0
        guard let i = b.timers.firstIndex(where: { $0.type == type }) else { return b }
        let t = b.timers[i]
        let other = t.side == "r" ? "l" : "r"
        let paused = t.pausedTotal + (t.pausedAt.map { max(0, n - $0) } ?? 0)
        if t.elapsed(n) < 30 {
            // too short for an entry: just the other side, and running
            b.timers[i].side = other
            if let p = t.pausedAt { b.timers[i].pausedTotal += max(0, n - p); b.timers[i].pausedAt = nil }
            return b
        }
        let endMs = max(t.start, n)
        let detail = nurseDetail(pausedMs: paused, separate: t.detached && t.sessionEntryIDs.isEmpty)
        let entry = LogEntry(type: type, start: t.start, end: endMs, side: t.side ?? "l", detail: detail)
        b.logs.append(entry)
        b.timers[i] = RunningTimer(
            type: type,
            start: endMs,
            side: other,
            carried: t.carried + t.elapsed(endMs) * 1000,
            carriedPause: t.carriedPause + paused,
            sessionEntryIDs: t.sessionEntryIDs + [entry.id],
            detached: t.detached
        )
        return b
    }
    @discardableResult static func shift(_ type: String, to start: Double) -> Body {
        applyMutation { b in
            guard let i = b.timers.firstIndex(where: { $0.type == type }) else { return false }
            b.timers[i].start = min(start, now())
            return true
        }
    }
    /// Ends the timer and writes the entry; nothing when it was not running.
    @discardableResult static func stop(_ type: String) -> Body {
        applyMutation { b in
            guard b.timers.contains(where: { $0.type == type }) else { return false }
            b = stopping(b, type, now: now())
            return true
        }
    }
    /// Variant of `stop` reporting whether the coordinated write succeeded or timer was absent.
    static func tryStop(_ type: String) -> Bool {
        switch mutate({ b in
            guard b.timers.contains(where: { $0.type == type }) else { return false }
            b = stopping(b, type, now: now())
            return true
        }) {
        case .saved, .unchanged: return true
        case .failed: return false
        }
    }
    static func stopping(_ b0: Body, _ type: String, now n: Double) -> Body {
        var b = b0
        guard let i = b.timers.firstIndex(where: { $0.type == type }) else { return b }
        let t = b.timers.remove(at: i)
        // the end is now, or a time chosen afterwards; ended while paused, the entry ends where the pause began
        let paused = t.pausedTotal
        let end = min(t.pausedAt ?? n, n)
        let detail = t.type == LogType.nurse
            ? nurseDetail(pausedMs: paused, separate: t.detached && t.sessionEntryIDs.isEmpty)
            : (paused > 0 ? "paused:\(Int(paused))" : nil)
        b.logs.append(LogEntry(type: type, start: t.start, end: max(t.start + 60_000, end), side: t.side, detail: detail))
        return b
    }
    /// For a timer: how it stands against the one before — a feed against the start of the previous feed (breast or
    /// bottle, its first side), a sleep against the last waking — as a short line, or nil when there is none.
    static func note(for t: RunningTimer, in logs: [LogEntry]) -> String? {
        let begun = t.start - t.carried - t.carriedPause
        if t.type == LogType.nurse {
            guard let f = logs.filter({ $0.start < begun }).feeds().last else { return nil }
            return L10n.t("距上一顿 ", "Since last feed ") + minutesOf((begun - f.start) / 1000)
        }
        if t.type == LogType.sleep, let e = logs.filter({ $0.type == LogType.sleep && ($0.end ?? .infinity) <= begun }).compactMap(\.end).max() {
            return L10n.isEnglish ? "Fell asleep after " + minutesOf((begun - e) / 1000) + " awake" : "醒了 " + minutesOf((begun - e) / 1000) + "后入睡"
        }
        return nil
    }
    /// Drops a running timer AND any intermediate side entries already recorded inside that same active session.
    static func discarding(_ b0: Body, _ type: String) -> Body {
        var b = b0
        let ids = Set(b.timers.filter { $0.type == type }.flatMap(\.sessionEntryIDs))
        if !ids.isEmpty {
            b.logs.removeAll { ids.contains($0.id) }
        }
        b.timers.removeAll { $0.type == type }
        return b
    }
    @discardableResult static func discard(_ type: String) -> Body {
        applyMutation { b in
            guard b.timers.contains(where: { $0.type == type }) else { return false }
            b = discarding(b, type)
            return true
        }
    }
    @discardableResult static func add(_ e: LogEntry) -> Body {
        applyMutation { b in b.logs.append(e); return true }
    }
}

#if canImport(ActivityKit)
/// The Live Activity of a running feed or sleep.
struct TimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var start: Date        // the start, moved later by any pause, so a running timer can count from it
        var pausedAt: Date?
        var side: String?
        /// A line about the one before ("距上一顿 3 小时 20 分"), written by the app when it starts or updates the activity.
        var note: String? = nil
    }
    var type: String
}
#endif
