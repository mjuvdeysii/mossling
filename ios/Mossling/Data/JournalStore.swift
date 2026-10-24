import SwiftUI
import Observation
import WidgetKit

/// The journal as the app sees it: the shared file, reloaded when the app comes back (a Live Activity or the widget may
/// have changed it), saved after every change, with the Live Activities and widgets kept in step.
@Observable
final class JournalStore {
    private(set) var logs: [LogEntry] = []
    private(set) var timers: [RunningTimer] = []
    private(set) var measures: [Measure] = []
    /// The page of a feed or a sleep, shown full screen: the only place a timer starts (tap 亲喂 or 睡觉 anywhere and
    /// this page opens, not yet running), and where a running one is paused, changed and ended.
    var focus: String?
    /// A record page to open in the journal (from a link, e.g. the widget's nappy button).
    var ask: String?
    /// What was just recorded, said back for a few seconds with a way to take it back.
    var toast: Toast?

    init(preview: JournalFile.Body? = nil) {
        if preview == nil { JournalFile.migrateIntoGroup() }
        apply(preview ?? JournalFile.read())
    }

    func reload() { apply(JournalFile.read()); seen = Self.stamp() }
    /// Reloads only if the file changed since the app last read or wrote it — the Live Activity buttons and the widget
    /// write the file from another process while the app may be open.
    func refreshIfChanged() { let s = Self.stamp(); if s != seen { reload() } }
    private var seen: Date? = nil
    private static func stamp() -> Date? { (try? FileManager.default.attributesOfItem(atPath: JournalFile.url.path))?[.modificationDate] as? Date }
    private func apply(_ b: JournalFile.Body) {
        logs = b.logs.sorted { $0.start > $1.start }; timers = b.timers; measures = b.measures.sorted { $0.at < $1.at }
    }
    private func changed(_ b: JournalFile.Body) {
        apply(b); seen = Self.stamp()
        Task { await LiveTimers.sync() }
        WidgetCenter.shared.reloadAllTimelines()
    }
    private func edit(_ f: (inout JournalFile.Body) -> Void) { var b = JournalFile.read(); f(&b); JournalFile.write(b); changed(b) }

    func start(_ type: String, side: String? = nil, at: Date = Date()) {
        let before = JournalFile.read()
        changed(JournalFile.start(type, side: side, at: at.timeIntervalSince1970 * 1000)); focus = type
        let ago = Int(Date().timeIntervalSince(at) / 60)
        say(type, LogType.name(type) + "开始计时" + (side == "l" ? " · 左侧" : side == "r" ? " · 右侧" : "") + (ago >= 1 ? " · 从 \(ago) 分钟前算起" : ""), undo: before)
    }
    func togglePause(_ type: String) { changed(JournalFile.togglePause(type)) }
    func tapSide(_ type: String, _ side: String) { changed(JournalFile.tapSide(type, side)) }
    func switchSide(_ type: String) { changed(JournalFile.switchSide(type)) }
    func shift(_ type: String, to: Date) { changed(JournalFile.shift(type, to: to.timeIntervalSince1970 * 1000)) }
    /// Ends the timer now, or at the moment given (a feed found running long after it ended), and says what was kept.
    func stop(_ type: String, at: Date? = nil) {
        let before = JournalFile.read()
        var b = before
        b = JournalFile.stopping(b, type, now: at.map { ms($0) } ?? JournalFile.now())
        JournalFile.write(b); changed(b)
        if let e = b.logs.last, e.type == type { say(type, "已记下 " + LogType.name(type) + " · " + durationValue(e.activeSeconds) + "，到 " + hm(e.endDate ?? Date()), undo: before) }
    }
    func discard(_ type: String) { changed(JournalFile.discard(type)) }

    func add(_ e: LogEntry) { edit { $0.logs.append(e) } }
    /// Adds an entry and says so ("已记下 尿布 · 湿 · 14:05"), with 撤销 for a few seconds.
    func record(_ e: LogEntry) {
        let before = JournalFile.read()
        add(e)
        let what = [LogType.name(e.type), e.summary].filter { !$0.isEmpty }.joined(separator: " · ")
        let when = Day(e.startDate) == Day.today ? hm(e.startDate) : whenLabel(e.startDate)
        say(e.type, "已记下 " + what + " · " + when, undo: before)
    }
    /// Takes back what the toast describes: the journal as it was just before.
    func undo(_ t: Toast) {
        guard let b = t.restore else { return }
        JournalFile.write(b); changed(b)
        toast = Toast(type: t.type, text: "已撤销", restore: nil)
    }
    private func say(_ type: String, _ text: String, undo: JournalFile.Body?) { toast = Toast(type: type, text: text, restore: undo) }
    func update(_ e: LogEntry) { edit { b in if let i = b.logs.firstIndex(where: { $0.id == e.id }) { b.logs[i] = e } } }
    func delete(_ e: LogEntry) { edit { $0.logs.removeAll { $0.id == e.id } } }
    func saveMeasure(_ m: Measure) { edit { b in if let i = b.measures.firstIndex(where: { $0.id == m.id }) { b.measures[i] = m } else { b.measures.append(m) } } }
    func deleteMeasure(_ m: Measure) { edit { $0.measures.removeAll { $0.id == m.id } } }
    func replaceAll(_ body: JournalFile.Body) { JournalFile.write(body); changed(body) }

    func last(_ type: String) -> Date? { logs.first { $0.type == type }.map { $0.endDate ?? $0.startDate } }
    /// The entries of a day: those that start on it, and those that run into it from the day before (a night's sleep
    /// belongs to both days, each counting its own part).
    func logs(on day: Day) -> [LogEntry] {
        let a = day.date.timeIntervalSince1970 * 1000, b = day.plus(days: 1).date.timeIntervalSince1970 * 1000
        return logs.filter { e in (e.start >= a && e.start < b) || (e.start < a && (e.end ?? e.start) > a) }
    }
}

/// A short note of what just happened, shown at the top for a few seconds.
struct Toast: Identifiable {
    let id = UUID()
    let type: String
    let text: String
    let restore: JournalFile.Body?
}
