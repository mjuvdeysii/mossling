import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// The kinds of entry, with the same identifiers as on Android (so record files move between the two).
enum LogType {
    static let nurse = "nurse", bottle = "bottle", sleep = "sleep", diaper = "diaper", solid = "solid", bath = "bath"
    static let temp = "temp", medicine = "med", note = "note", play = "play"
    static let growth = "growth" // not an entry: opens the measurement sheet
    static func name(_ t: String) -> String {
        switch t { case nurse: "亲喂"; case bottle: "瓶喂"; case sleep: "睡觉"; case diaper: "尿布"; case solid: "辅食"; case bath: "洗澡"
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

    var summary: String {
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
        return detail == "breastmilk" ? "母乳" : detail == "formula" ? "配方奶" : nil
    }
    /// Time the timer was paused, as written by both apps in `detail` ("paused:<ms>").
    var pausedSeconds: Double {
        guard let d = detail, d.hasPrefix("paused:"), let ms = Double(d.dropFirst(7)) else { return 0 }
        return max(0, ms / 1000)
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
            if e.type == LogType.nurse, let p = out.last?.entries.last, p.type == LogType.nurse, e.start - (p.end ?? p.start) <= Feed.join {
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
            let note = f.isBottle ? "瓶喂 \(f.first.amount ?? 0) 毫升"
                : "亲喂 · " + f.sides.map { $0.side == "l" ? "左侧" : "右侧" }.joined(separator: " → ")
            return LastFact(label: "上次喂奶", at: f.startDate, note: note)
        case LogType.sleep:
            guard let s = older.filter({ $0.type == LogType.sleep && $0.end != nil }).max(by: { $0.start < $1.start }), let e = s.endDate else { return nil }
            return LastFact(label: "上次醒来", at: e, note: "睡了 " + minutesOf(s.activeSeconds))
        default:
            guard let e = older.filter({ $0.type == type }).max(by: { $0.start < $1.start }) else { return nil }
            return LastFact(label: type == LogType.diaper ? "上次换尿布" : "上次" + LogType.name(type), at: e.startDate, note: e.summary.isEmpty ? nil : e.summary)
        }
    }
    /// 「上次喂奶 25 分前」: the one sentence for the last time, wherever it is said.
    func phrase(now: Date, precise: Bool = false) -> String { label + " " + ago(at, now: now, precise: precise) }
}

/// A running timer's state, one way everywhere (widget, Live Activity, home, records): 「亲喂 · 右侧 · 已暂停」.
func timerState(_ type: String, side: String?, paused: Bool) -> String {
    LogType.name(type) + (side == "l" ? " · 左侧" : side == "r" ? " · 右侧" : "") + (paused ? " · 已暂停" : "")
}

/// One way to write a length of time everywhere (app, widget, Live Activity): "18 分钟", "1 小时 5 分", "2 小时".
func minutesOf(_ s: Double) -> String {
    let m = Int((max(0, s) / 60).rounded(.down))
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
    /// This side so far, in seconds.
    func elapsed(_ now: Double) -> Double { ((pausedAt ?? now) - start - pausedTotal) / 1000 }
    /// The whole feed (or sleep) so far, in seconds.
    func total(_ now: Double) -> Double { elapsed(now) + carried / 1000 }
    /// The moment a clock counting the whole feed would have started at (for timers that count up from a date).
    var countsFrom: Date { Date(timeIntervalSince1970: (start + pausedTotal - carried) / 1000) }
    /// All the pauses of the whole feed (or sleep) so far, in seconds, the one under way included.
    func paused(_ now: Double) -> Double { (carriedPause + pausedTotal + (pausedAt.map { now - $0 } ?? 0)) / 1000 }

    enum CodingKeys: String, CodingKey { case type, start, side, pausedAt, pausedTotal, carried, carriedPause }
    init(type: String, start: Double, side: String? = nil, pausedAt: Double? = nil, pausedTotal: Double = 0, carried: Double = 0, carriedPause: Double = 0) {
        self.type = type; self.start = start; self.side = side; self.pausedAt = pausedAt; self.pausedTotal = pausedTotal; self.carried = carried
        self.carriedPause = carriedPause
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type); start = try c.decode(Double.self, forKey: .start)
        side = try c.decodeIfPresent(String.self, forKey: .side); pausedAt = try c.decodeIfPresent(Double.self, forKey: .pausedAt)
        pausedTotal = try c.decodeIfPresent(Double.self, forKey: .pausedTotal) ?? 0
        carried = try c.decodeIfPresent(Double.self, forKey: .carried) ?? 0   // files written before this field
        carriedPause = try c.decodeIfPresent(Double.self, forKey: .carriedPause) ?? 0
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
struct Snapshot: Codable {
    var birthEpochDay: Int?
    var nickname: String
    var companion: String
    var journal: Bool
    var playCode: String?
    var playName: String?
}

/// The journal file, shared with the widget and the Live Activity through the app group.
enum JournalFile {
    static let group = "group.app.mossling"
    static var dir: URL {
        #if DEBUG
        if let t = testDir { return t }
        #endif
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
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

    struct Body: Codable {
        var logs: [LogEntry] = []; var timers: [RunningTimer] = []; var measures: [Measure] = []
        /// The child's firsts (第一次), a line of their own that is never cut by dates.
        var firsts: [First] = []
        init() {}
        // every field may be missing in a file written by an earlier build: read what is there, never fail the whole
        // file (a failed read would show an empty journal)
        init(from d: Decoder) throws {
            let c = try d.container(keyedBy: CodingKeys.self)
            logs = try c.decodeIfPresent([LogEntry].self, forKey: .logs) ?? []
            timers = try c.decodeIfPresent([RunningTimer].self, forKey: .timers) ?? []
            measures = try c.decodeIfPresent([Measure].self, forKey: .measures) ?? []
            firsts = try c.decodeIfPresent([First].self, forKey: .firsts) ?? []
        }
    }

    /// Builds signed before the app group was set up kept the journal in the app's own Documents folder. Once the
    /// group exists, move it there (once), so nothing recorded earlier is lost and the widget sees it too.
    static func migrateIntoGroup() {
        guard let g = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else { return }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for name in ["journal.json", "snapshot.json"] {
            let old = docs.appendingPathComponent(name), new = g.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: old.path) else { continue }
            if !FileManager.default.fileExists(atPath: new.path) { try? FileManager.default.copyItem(at: old, to: new) }
            try? FileManager.default.moveItem(at: old, to: docs.appendingPathComponent(name + ".moved"))
        }
    }

    static func read() -> Body { (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Body.self, from: $0) } ?? Body() }
    /// Writes the journal; false when it could not be saved (the caller says so and keeps what was typed).
    @discardableResult static func write(_ b: Body) -> Bool {
        #if DEBUG
        if failWrites { return false }
        #endif
        guard let data = try? JSONEncoder().encode(b) else { return false }
        do { try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]); return true } catch { return false }
    }
    #if DEBUG
    /// Tests only: every write fails, to check that nothing celebrates a save that did not happen.
    nonisolated(unsafe) static var failWrites = false
    #endif
    static func snapshot() -> Snapshot? { (try? Data(contentsOf: snapshotURL)).flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) } }
    static func writeSnapshot(_ s: Snapshot) { try? JSONEncoder().encode(s).write(to: snapshotURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }

    // Timer operations, shared by the app, the Live Activity buttons and the widget.
    static func now() -> Double { Date().timeIntervalSince1970 * 1000 }
    @discardableResult static func start(_ type: String, side: String? = nil, at: Double = now()) -> Body {
        var b = read(); if !b.timers.contains(where: { $0.type == type }) { b.timers.append(RunningTimer(type: type, start: at, side: side)); write(b) }; return b
    }
    @discardableResult static func togglePause(_ type: String) -> Body {
        var b = read(); b = pausing(b, type, now: now()); write(b); return b
    }
    static func pausing(_ b0: Body, _ type: String, now n: Double) -> Body {
        var b = b0
        if let i = b.timers.firstIndex(where: { $0.type == type }) {
            if let p = b.timers[i].pausedAt { b.timers[i].pausedTotal += n - p; b.timers[i].pausedAt = nil } else { b.timers[i].pausedAt = n }
        }
        return b
    }
    /// A tap on one side of a feed, the one gesture of the feeding screen: on the side being fed it pauses (or goes
    /// on); on the other side it changes sides and runs.
    @discardableResult static func tapSide(_ type: String, _ side: String) -> Body {
        var b = read(); b = tappingSide(b, type, side, now: now()); write(b); return b
    }
    static func tappingSide(_ b: Body, _ type: String, _ side: String, now n: Double) -> Body {
        guard let t = b.timers.first(where: { $0.type == type }) else { return b }
        return (t.side ?? "l") == side ? pausing(b, type, now: n) : switchingSide(b, type, now: n)
    }
    /// Changing sides during a feed: the side so far is written as its own entry and the timer goes on for the other
    /// side from now (and runs again if it was paused). A side of under 30 seconds is not worth an entry: the side is
    /// just changed. Each side stays a plain nurse entry, so the file reads the same in the Android app.
    @discardableResult static func switchSide(_ type: String) -> Body {
        var b = read(); b = switchingSide(b, type, now: now()); write(b); return b
    }
    static func switchingSide(_ b0: Body, _ type: String, now n: Double) -> Body {
        var b = b0
        guard let i = b.timers.firstIndex(where: { $0.type == type }) else { return b }
        let t = b.timers[i]
        let other = t.side == "r" ? "l" : "r"
        let paused = t.pausedTotal + (t.pausedAt.map { n - $0 } ?? 0)
        if t.elapsed(n) < 30 {
            // too short for an entry: just the other side, and running
            b.timers[i].side = other
            if let p = t.pausedAt { b.timers[i].pausedTotal += n - p; b.timers[i].pausedAt = nil }
            return b
        }
        b.logs.append(LogEntry(type: type, start: t.start, end: n, side: t.side ?? "l", detail: paused > 0 ? "paused:\(Int(paused))" : nil))
        b.timers[i] = RunningTimer(type: type, start: n, side: other, carried: t.carried + t.elapsed(n) * 1000, carriedPause: t.carriedPause + paused)
        return b
    }
    @discardableResult static func shift(_ type: String, to start: Double) -> Body {
        var b = read(); if let i = b.timers.firstIndex(where: { $0.type == type }) { b.timers[i].start = min(start, now()); write(b) }; return b
    }
    /// Ends the timer and writes the entry; nothing when it was not running.
    @discardableResult static func stop(_ type: String) -> Body {
        var b = read(); b = stopping(b, type, now: now()); write(b); return b
    }
    static func stopping(_ b0: Body, _ type: String, now n: Double) -> Body {
        var b = b0
        guard let i = b.timers.firstIndex(where: { $0.type == type }) else { return b }
        let t = b.timers.remove(at: i)
        // the end is now, or a time chosen afterwards; ended while paused, the entry ends where the pause began
        let paused = t.pausedTotal
        let end = min(t.pausedAt ?? n, n)
        b.logs.append(LogEntry(type: type, start: t.start, end: max(t.start + 60_000, end), side: t.side, detail: paused > 0 ? "paused:\(Int(paused))" : nil))
        return b
    }
    /// For a timer: how it stands against the one before — a feed against the start of the previous feed (breast or
    /// bottle, its first side), a sleep against the last waking — as a short line, or nil when there is none.
    static func note(for t: RunningTimer, in logs: [LogEntry]) -> String? {
        let begun = t.start - t.carried - t.carriedPause
        if t.type == LogType.nurse {
            guard let f = logs.filter({ $0.start < begun }).feeds().last else { return nil }
            return "距上一顿 " + minutesOf((begun - f.start) / 1000)
        }
        if t.type == LogType.sleep, let e = logs.filter({ $0.type == LogType.sleep && ($0.end ?? .infinity) <= begun }).compactMap(\.end).max() {
            return "醒了 " + minutesOf((begun - e) / 1000) + "后入睡"
        }
        return nil
    }
    @discardableResult static func discard(_ type: String) -> Body { var b = read(); b.timers.removeAll { $0.type == type }; write(b); return b }
    @discardableResult static func add(_ e: LogEntry) -> Body { var b = read(); b.logs.append(e); write(b); return b }
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
