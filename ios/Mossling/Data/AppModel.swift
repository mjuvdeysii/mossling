import SwiftUI
import Observation
import WidgetKit

enum TickKind { static let observed = "c", did = "a", vaccine = "v", checkup = "k" }
func tickKey(_ month: Int, _ kind: String, _ id: String) -> String { "\(month):\(kind):\(id)" }

struct Tick: Codable, Hashable {
    let key: String, month: Int, kind: String, label: String, at: Double
}

enum ThemeMode: String, CaseIterable { case system, light, dark
    var label: String { switch self { case .system: "跟随系统"; case .light: "浅色"; case .dark: "深色" } }
    var scheme: ColorScheme? { switch self { case .system: nil; case .light: .light; case .dark: .dark } }
}

/// Settings and month records, kept on the phone (UserDefaults); the journal lives in its own store.
@Observable
final class AppModel {
    let content: Content
    let growth: Growth
    var today: Day = .today

    private let d: UserDefaults
    var birth: Day? { didSet { d.set(birth?.epochDay, forKey: "birth"); if birth != nil { onboarded = true } } }
    var companion: Kind { didSet { d.set(companion.rawValue, forKey: "companion") } }
    var theme: ThemeMode { didSet { d.set(theme.rawValue, forKey: "theme") } }
    var onboarded: Bool { didSet { d.set(onboarded, forKey: "onboarded") } }
    var skipDay: Int { didSet { d.set(skipDay, forKey: "skipDay") } }
    var pick: String { didSet { d.set(pick, forKey: "pick") } }
    var sex: String? { didSet { d.set(sex, forKey: "sex") } }
    var nickname: String { didSet { d.set(nickname, forKey: "nickname") } }
    var lock: Bool { didSet { d.set(lock, forKey: "lock") } }
    var shelf: String { didSet { d.set(shelf, forKey: "shelf") } }
    var journal: Bool { didSet { d.set(journal, forKey: "journal") } }
    /// 夜灯: from 7 pm to 6 am the records and the timer turn into Otto's lamp — dim warm light on deep blue.
    var nightLight: Bool { didSet { d.set(nightLight, forKey: "nightLight") } }
    /// A play started and not finished: "CODE|month|step". Shown above the tab bar until it is finished or put away.
    var session: String { didSet { d.set(session, forKey: "session") } }
    private(set) var ticks: [String: Tick] { didSet { d.set(try? JSONEncoder().encode(Array(ticks.values)), forKey: "ticks") } }

    init(defaults: UserDefaults = .standard, content: Content? = nil, growth: Growth? = nil) {
        d = defaults
        self.content = content ?? (try! Content.load())
        self.growth = growth ?? (try! Growth.load())
        birth = (d.object(forKey: "birth") as? Int).map { Day(epochDay: $0) }
        companion = Kind(rawValue: d.string(forKey: "companion") ?? "") ?? .moss
        theme = ThemeMode(rawValue: d.string(forKey: "theme") ?? "") ?? .system
        onboarded = d.bool(forKey: "onboarded")
        skipDay = (d.object(forKey: "skipDay") as? Int) ?? -1
        pick = d.string(forKey: "pick") ?? ""
        sex = d.string(forKey: "sex")
        nickname = d.string(forKey: "nickname") ?? ""
        lock = d.bool(forKey: "lock")
        shelf = d.string(forKey: "shelf") ?? ""
        journal = d.bool(forKey: "journal")
        nightLight = (d.object(forKey: "nightLight") as? Bool) ?? true
        session = d.string(forKey: "session") ?? ""
        let list = (d.data(forKey: "ticks")).flatMap { try? JSONDecoder().decode([Tick].self, from: $0) } ?? []
        ticks = Dictionary(list.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var age: Age? { birth.map { Age.on(birth: $0, today: today) } }
    var babyMonth: Int? { age?.bookMonth }
    var girl: Bool { sex == "girl" }

    func ticked(_ m: Int, _ kind: String, _ id: String) -> Bool { ticks[tickKey(m, kind, id)] != nil }
    func toggle(_ m: Int, _ kind: String, _ id: String, _ label: String) {
        let k = tickKey(m, kind, id)
        if ticks[k] != nil { ticks[k] = nil } else { ticks[k] = Tick(key: k, month: m, kind: kind, label: label, at: Date().timeIntervalSince1970 * 1000) }
    }
    func count(_ m: Int, _ kind: String) -> Int { ticks.values.filter { $0.month == m && $0.kind == kind }.count }

    /// This week's shelf for the child's month, and whether it is time to rotate.
    func weekShelf(_ m: Int) -> (plays: [Play], stale: Bool) { Shelf.current(content, m, stored: shelf, today: today) }
    func setShelf(_ codes: [String]) { shelf = Shelf.format(today, codes) }

    /// Today's play: from this week's shelf, or the month's own when the shelf is empty.
    func todaysPlays(_ m: Int) -> [Play] { let s = weekShelf(m).plays; return s.isEmpty ? content.plays(of: m) : s }
    var pickIndex: Int {
        let p = pick.split(separator: ":"); guard p.count == 2, Int(p[0]) == babyMonth else { return 0 }
        return Int(p[1]) ?? 0
    }
    func another() { if let m = babyMonth { pick = "\(m):\(pickIndex + 1)" } }
    var skippedToday: Bool { skipDay == today.epochDay }

    /// The play in progress, if any.
    var playing: (play: Play, month: Int, step: Int)? {
        let p = session.split(separator: "|")
        guard p.count == 3, let pl = content.play(String(p[0])), let m = Int(p[1]), let st = Int(p[2]) else { return nil }
        return (pl, m, min(st, pl.steps.count - 1))
    }
    func play(_ p: Play, month: Int, at step: Int) { session = "\(p.code)|\(month)|\(step)" }
    func finishPlaying() { session = "" }

    func replaceTicks(_ l: [Tick]) { ticks = Dictionary(l.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a }) }

    /// What the widget shows, written whenever it changes.
    func publish() {
        var code: String?, name: String?
        if let m = babyMonth, !skippedToday { let ps = todaysPlays(m); if !ps.isEmpty { let p = ps[pickIndex % ps.count]; code = p.code; name = p.name } }
        JournalFile.writeSnapshot(Snapshot(birthEpochDay: birth?.epochDay, nickname: nickname, companion: companion.rawValue, journal: journal, playCode: code, playName: name))
        WidgetCenter.shared.reloadAllTimelines()
    }
    var publishKey: String { "\(birth?.epochDay ?? -1)|\(nickname)|\(companion.rawValue)|\(journal)|\(pick)|\(shelf)|\(skipDay)|\(today.epochDay)" }

    func clearAll() {
        for k in ["birth", "companion", "theme", "onboarded", "skipDay", "pick", "sex", "nickname", "lock", "shelf", "journal", "ticks", "session"] { d.removeObject(forKey: k) }
        JournalFile.write(JournalFile.Body())
        birth = nil; sex = nil; nickname = ""; shelf = ""; pick = ""; skipDay = -1; ticks = [:]; session = ""; journal = false; lock = false; onboarded = false
    }
}
