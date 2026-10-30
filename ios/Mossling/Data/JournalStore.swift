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
    /// The firsts, newest first.
    private(set) var firsts: [First] = []
    /// The page of a feed or a sleep, shown full screen: the only place a timer starts (tap 亲喂 or 睡觉 anywhere and
    /// this page opens, not yet running), and where a running one is paused, changed and ended.
    var focus: String?
    /// A record page to open in the journal (from a link, e.g. the widget's nappy button).
    var ask: String?
    /// What was just recorded, said back for a few seconds with a way to take it back.
    var toast: Toast?
    /// Where confirmed events go for the companions (IP v1.3 event contract). Set by the app; the journal never
    /// waits for, or depends on, what the companions do with them.
    var onEvent: ((MascotEvent) -> Void)?
    /// Counts the sleeps started, so Otto can answer one with his slow yawn (he knows that tiredness).
    private(set) var sleepsStarted = 0

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
        firsts = b.firsts.sorted { $0.at > $1.at }
    }
    private func changed(_ b: JournalFile.Body) {
        apply(b); seen = Self.stamp()
        Task { await LiveTimers.sync() }
        WidgetCenter.shared.reloadAllTimelines()
    }
    /// Applies a change and saves it. On a failed save nothing changes on screen, the failure is said in plain words
    /// (no undo, no success haptic), and the caller keeps what was typed.
    @discardableResult private func edit(_ f: (inout JournalFile.Body) -> Void) -> Bool {
        var b = JournalFile.read(); f(&b)
        guard JournalFile.write(b) else { failed(); return false }
        changed(b); return true
    }
    private func failed(_ what: String = "这条记录") {
        reload()
        toast = Toast(type: LogType.note, text: "没有保存成功：" + what + "未写入，请再试一次", restore: nil, failed: true)
        onEvent?(.recordPersistFailure)
    }

    func start(_ type: String, side: String? = nil, at: Date = Date()) {
        let before = JournalFile.read()
        let b = JournalFile.start(type, side: side, at: at.timeIntervalSince1970 * 1000)
        // confirmed only when the timer is really in the file (read back), never on the tap alone
        guard JournalFile.read().timers.contains(where: { $0.type == type }) else { failed("计时"); return }
        changed(b); focus = type
        if type == LogType.sleep { sleepsStarted &+= 1 }
        onEvent?(.recordStartConfirmed)
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
        // a second tap on 结束 (or one from the Lock Screen first) finds nothing running: no second entry, no reply
        guard before.timers.contains(where: { $0.type == type }) else { reload(); return }
        var b = before
        b = JournalFile.stopping(b, type, now: at.map { ms($0) } ?? JournalFile.now())
        guard JournalFile.write(b) else { failed("这次" + LogType.name(type)); return }
        changed(b)
        onEvent?(.recordPersistSuccess)
        if let e = b.logs.last, e.type == type { say(type, "已记下 " + LogType.name(type) + " · " + durationValue(e.activeSeconds) + "，到 " + hm(e.endDate ?? Date()), undo: before) }
    }
    /// Drops a running timer; said back with 撤销, like every change that loses something.
    func discard(_ type: String) {
        let before = JournalFile.read()
        // said only once it is really dropped (a failed save says so, with nothing to take back)
        guard edit({ $0.timers.removeAll { $0.type == type } }) else { return }
        onEvent?(.timerEnded)
        say(type, "没有记这一次" + LogType.name(type), undo: before)
    }

    @discardableResult func add(_ e: LogEntry) -> Bool { edit { $0.logs.append(e) } }
    /// Adds an entry and says so ("已记下 尿布 · 湿 · 14:05"), with 撤销 for a few seconds. False when it could not be
    /// saved: then the page that asked stays open with what was typed.
    @discardableResult func record(_ e: LogEntry) -> Bool {
        let before = JournalFile.read()
        guard add(e) else { return false }
        onEvent?(.recordPersistSuccess)
        let what = [LogType.name(e.type), e.summary].filter { !$0.isEmpty }.joined(separator: " · ")
        let when = Day(e.startDate) == Day.today ? hm(e.startDate) : whenLabel(e.startDate)
        say(e.type, "已记下 " + what + " · " + when, undo: before)
        return true
    }
    /// Takes back what the toast describes: the journal as it was just before.
    func undo(_ t: Toast) {
        guard let b = t.restore else { return }
        // 已撤销 only when it is really back in the file
        guard JournalFile.write(b) else { failed("撤销"); return }
        changed(b)
        toast = Toast(type: t.type, text: "已撤销", restore: nil)
    }
    private func say(_ type: String, _ text: String, undo: JournalFile.Body?) { toast = Toast(type: type, text: text, restore: undo) }
    @discardableResult func update(_ e: LogEntry) -> Bool { edit { b in if let i = b.logs.firstIndex(where: { $0.id == e.id }) { b.logs[i] = e } } }
    /// Several entries changed at once (the sides of one feed): one write — all or none — said back with 撤销.
    @discardableResult func update(_ es: [LogEntry]) -> Bool {
        guard let first = es.min(by: { $0.start < $1.start }) else { return true }
        let before = JournalFile.read()
        let ok = edit { b in
            for e in es { if let i = b.logs.firstIndex(where: { $0.id == e.id }) { b.logs[i] = e } }
        }
        let what: String = es.count > 1 ? "已修改这一顿" + LogType.name(first.type) : "已修改 " + LogType.name(first.type)
        if ok { say(first.type, what + " · " + hm(first.startDate), undo: before) }
        return ok
    }
    /// Deleting is one tap (no confirmation to tap through at night): it is said back with 撤销 instead.
    func delete(_ e: LogEntry) {
        let before = JournalFile.read()
        guard edit({ $0.logs.removeAll { $0.id == e.id } }) else { return }
        say(e.type, "已删除 " + LogType.name(e.type) + " · " + hm(e.startDate), undo: before)
    }
    /// A whole breast feed — its sides — at once: one change, one line said back, one 撤销.
    func delete(_ es: [LogEntry]) {
        guard let e = es.min(by: { $0.start < $1.start }) else { return }
        if es.count == 1 { delete(e); return }
        let before = JournalFile.read(), ids = Set(es.map(\.id))
        guard edit({ $0.logs.removeAll { ids.contains($0.id) } }) else { return }
        say(e.type, "已删除这一顿" + LogType.name(e.type) + " · " + hm(e.startDate), undo: before)
    }
    /// Keeps a measurement and says so, with 撤销; false when it could not be saved (the sheet keeps what was typed).
    @discardableResult func saveMeasure(_ m: Measure) -> Bool {
        let before = JournalFile.read()
        guard edit({ b in if let i = b.measures.firstIndex(where: { $0.id == m.id }) { b.measures[i] = m } else { b.measures.append(m) } }) else { return false }
        say(LogType.growth, "已记下测量 · " + Day(Date(timeIntervalSince1970: m.at / 1000)).md, undo: before)
        return true
    }
    func deleteMeasure(_ m: Measure) {
        let before = JournalFile.read()
        guard edit({ $0.measures.removeAll { $0.id == m.id } }) else { return }
        say(LogType.growth, "已删除这次测量 · " + Day(Date(timeIntervalSince1970: m.at / 1000)).md, undo: before)
    }
    /// Keeps a first (new or changed) and says so; false when it could not be saved.
    @discardableResult func saveFirst(_ f: First) -> Bool {
        let isNew = !firsts.contains { $0.id == f.id }
        let before = JournalFile.read()
        guard edit({ b in if let i = b.firsts.firstIndex(where: { $0.id == f.id }) { b.firsts[i] = f } else { b.firsts.append(f) } }) else { return false }
        onEvent?(.recordPersistSuccess)
        if isNew { toast = Toast(type: LogType.note, text: "记下了第一次：" + f.title + " · " + whenLabelDay(f.date), restore: before) }
        return true
    }
    func deleteFirst(_ f: First) {
        let before = JournalFile.read()
        guard edit({ $0.firsts.removeAll { $0.id == f.id } }) else { return }
        say(LogType.note, "已删除第一次：" + f.title, undo: before)
    }
    func replaceAll(_ body: JournalFile.Body) { JournalFile.write(body); changed(body) }

    /// When the last one was: a feed by when it began (feeds are counted start to start), anything else — a sleep
    /// above all — by when it ended (when the baby woke).
    func last(_ type: String) -> Date? {
        // a breast feed of two sides began with its first side
        if type == LogType.nurse || type == LogType.bottle { return logs.filter { $0.type == type }.feeds().last?.startDate }
        return logs.first { $0.type == type }.map { $0.endDate ?? $0.startDate }
    }
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
    /// A save that did not happen: said with a warning, never with the success haptic.
    var failed = false
}
