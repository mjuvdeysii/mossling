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
        case LogType.nurse: return [side == "l" ? "左边" : side == "r" ? "右边" : nil, end.map { minutesOf(($0 - start) / 1000) }].compactMap { $0 }.joined(separator: " · ")
        case LogType.sleep: return end.map { minutesOf(($0 - start) / 1000) } ?? "进行中"
        case LogType.bottle: return "\(amount ?? 0) 毫升"
        case LogType.diaper: return ["wet": "湿", "dirty": "便", "both": "湿和便"][detail ?? ""] ?? ""
        case LogType.temp: return amount.map { String(format: "%.1f °C", Double($0) / 10) } ?? ""
        default: return detail ?? ""
        }
    }
}

func minutesOf(_ s: Double) -> String { let m = Int(max(0, s) / 60); return m >= 60 ? "\(m / 60) 小时 \(m % 60) 分" : "\(m) 分钟" }

/// A timer that is running (at most one per kind). Survives the app being closed.
struct RunningTimer: Codable, Hashable {
    var type: String
    var start: Double
    var side: String? = nil
    var pausedAt: Double? = nil
    var pausedTotal: Double = 0
    func elapsed(_ now: Double) -> Double { ((pausedAt ?? now) - start - pausedTotal) / 1000 }
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
        var b = read(); let n = now()
        if let i = b.timers.firstIndex(where: { $0.type == type }) {
            if let p = b.timers[i].pausedAt { b.timers[i].pausedTotal += n - p; b.timers[i].pausedAt = nil } else { b.timers[i].pausedAt = n }
            write(b)
        }
        return b
    }
    @discardableResult static func switchSide(_ type: String) -> Body {
        var b = read(); if let i = b.timers.firstIndex(where: { $0.type == type }) { b.timers[i].side = b.timers[i].side == "l" ? "r" : "l"; write(b) }; return b
    }
    @discardableResult static func shift(_ type: String, to start: Double) -> Body {
        var b = read(); if let i = b.timers.firstIndex(where: { $0.type == type }) { b.timers[i].start = min(start, now()); write(b) }; return b
    }
    /// Ends the timer and writes the entry; nothing when it was not running.
    @discardableResult static func stop(_ type: String) -> Body {
        var b = read(); let n = now()
        guard let i = b.timers.firstIndex(where: { $0.type == type }) else { return b }
        let t = b.timers.remove(at: i)
        let paused = t.pausedTotal + (t.pausedAt.map { n - $0 } ?? 0)
        let end = t.pausedAt ?? n
        b.logs.append(LogEntry(type: type, start: t.start, end: max(t.start + 60_000, end), side: t.side, detail: paused > 0 ? "paused:\(Int(paused))" : nil))
        write(b); return b
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
    }
    var type: String
}
#endif
