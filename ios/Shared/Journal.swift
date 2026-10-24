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
        case LogType.nurse: return [side == "l" ? "左边" : side == "r" ? "右边" : nil, end.map { _ in minutesOf(activeSeconds) }].compactMap { $0 }.joined(separator: " · ")
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

extension Array where Element == LogEntry {
    /// The number of feeds: a bottle is one feed; nursing on one side then the other, entry right after entry (within
    /// two minutes), is one feed.
    /// Pass `from` to count only feeds that began at or after it (a day's feeds: a feed begun before midnight and
    /// carried on after it belongs to the day before).
    func feedCount(from: Double = -.infinity) -> Int {
        let nurses = filter { $0.type == LogType.nurse }.sorted { $0.start < $1.start }
        var n = filter { $0.type == LogType.bottle && $0.start >= from }.count
        var lastEnd: Double?
        for e in nurses {
            if let l = lastEnd, e.start - l <= 120_000 { } else if e.start >= from { n += 1 }
            lastEnd = e.end ?? e.start
        }
        return n
    }
    /// The sides of the feed that ends where `start` begins, walking back entry by entry: seconds per side.
    func feedSides(before start: Double) -> [String: Double] {
        var out: [String: Double] = [:]
        var t = start
        while let e = first(where: { $0.type == LogType.nurse && $0.end.map { abs($0 - t) <= 120_000 } == true && $0.start < t }) {
            out[e.side ?? "l", default: 0] += e.activeSeconds
            t = e.start
        }
        return out
    }
}

/// One way to write a length of time everywhere (app, widget, Live Activity): "18 分钟", "1 小时 5 分", "2 小时".
func minutesOf(_ s: Double) -> String {
    let m = Int((max(0, s) / 60).rounded(.down))
    if m < 60 { return "\(m) 分钟" }
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
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var url: URL { dir.appendingPathComponent("journal.json") }
    static var snapshotURL: URL { dir.appendingPathComponent("snapshot.json") }

    struct Body: Codable { var logs: [LogEntry] = []; var timers: [RunningTimer] = []; var measures: [Measure] = [] }

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
    static func write(_ b: Body) { try? JSONEncoder().encode(b).write(to: url, options: .atomic) }
    static func snapshot() -> Snapshot? { (try? Data(contentsOf: snapshotURL)).flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) } }
    static func writeSnapshot(_ s: Snapshot) { try? JSONEncoder().encode(s).write(to: snapshotURL, options: .atomic) }

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
            let feeds = logs.filter { ($0.type == LogType.nurse || $0.type == LogType.bottle) && $0.start < begun }.sorted { $0.start < $1.start }
            guard var i = feeds.indices.last else { return nil }
            while i > 0, feeds[i].type == LogType.nurse, feeds[i - 1].type == LogType.nurse, let pe = feeds[i - 1].end, feeds[i].start - pe <= 120_000 { i -= 1 }
            return "距上一顿 " + minutesOf((begun - feeds[i].start) / 1000)
        }
        if t.type == LogType.sleep, let e = logs.filter({ $0.type == LogType.sleep && ($0.end ?? .infinity) <= begun }).compactMap(\.end).max() {
            return "醒了 " + minutesOf((begun - e) / 1000) + " 后入睡"
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
