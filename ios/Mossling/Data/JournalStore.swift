import SwiftUI
import Observation
import WidgetKit
import CoreFoundation

/// The journal as the app sees it: the shared file, reloaded when the app comes back (a Live Activity or the widget may
/// have changed it), saved after every change, with the Live Activities and widgets kept in step.
@Observable
final class JournalStore {
    private(set) var logs: [LogEntry] = []
    private(set) var timers: [RunningTimer] = []
    private(set) var measures: [Measure] = []
    /// The firsts, newest first.
    private(set) var firsts: [First] = []
    /// Precomputed O(1) read indexes rebuilt on data changes (keeps scrolling & timeline rendering O(1) per row).
    private(set) var allFeeds: [Feed] = []
    private(set) var feedIntervalByID: [UUID: Double] = [:]
    private(set) var lastByType: [String: Date] = [:]
    private(set) var playsByCode: [String: [LogEntry]] = [:]
    private(set) var playLogCount: Int = 0
    @ObservationIgnored private var logsByDayEpoch: [Int: [LogEntry]] = [:]
    @ObservationIgnored private var indexedTimeZone: TimeZone = Day.cal.timeZone
    @ObservationIgnored private var externalObserver: ExternalJournalObserver?
    /// The page of a feed or a sleep, shown full screen: the only place a timer starts (tap 亲喂 or 睡觉 anywhere and
    /// this page opens, not yet running), and where a running one is paused, changed and ended.
    var focus: String?
    /// A record page to open in the journal (from a link, e.g. the widget's nappy button).
    var ask: String?
    /// Incremented by deep links to bring JournalView back to today before opening a quick-log sheet.
    var jumpToToday = 0
    /// What was just recorded, said back for a few seconds with a way to take it back.
    var toast: Toast?
    /// Where confirmed events go for the companions (IP v1.3 event contract). Set by the app; the journal never
    /// waits for, or depends on, what the companions do with them.
    var onEvent: ((MascotEvent) -> Void)?
    /// Fired when another process (widget / Control Center / Live Activity) signals a shared-data change.
    @ObservationIgnored var onExternalChange: (() -> Void)?
    /// Counts the sleeps started, so Otto can answer one with his slow yawn (he knows that tiredness).
    private(set) var sleepsStarted = 0

    init(preview: JournalFile.Body? = nil) {
        if preview == nil {
            JournalFile.migrateIntoGroup()
            externalObserver = ExternalJournalObserver { [weak self] in
                self?.handleExternalChange()
            }
        }
        apply(preview ?? JournalFile.read())
    }

    private func handleExternalChange() {
        refreshIfChanged()
        onExternalChange?()
    }

    func reload() {
        if let b = try? JournalFile.load() { apply(b) }
        seen = Self.stamp()
    }
    /// Reloads only if the file changed since the app last read or wrote it — the Live Activity buttons and the widget
    /// write the file from another process while the app may be open.
    func refreshIfChanged() { let s = Self.stamp(); if s != seen { reload() } }
    private var seen: Date? = nil
    private static func stamp() -> Date? { (try? FileManager.default.attributesOfItem(atPath: JournalFile.url.path))?[.modificationDate] as? Date }
    private func apply(_ b: JournalFile.Body) {
        let sortedLogs = b.logs.sorted { $0.start > $1.start }
        logs = sortedLogs; timers = b.timers; measures = b.measures.sorted { $0.at < $1.at }
        firsts = b.firsts.sorted { $0.at > $1.at }
        rebuildIndexes(sortedLogs)
    }
    private func rebuildIndexes(_ sortedLogs: [LogEntry]) {
        let feeds = sortedLogs.feeds()
        allFeeds = feeds
        var intervals: [UUID: Double] = [:]
        intervals.reserveCapacity(feeds.count)
        if feeds.count > 1 {
            for i in 1..<feeds.count {
                intervals[feeds[i].first.id] = (feeds[i].start - feeds[i - 1].start) / 1000
            }
        }
        feedIntervalByID = intervals

        var lastMap: [String: Date] = [:]
        var playsMap: [String: [LogEntry]] = [:]
        var byDay: [Int: [LogEntry]] = [:]
        var playCount = 0
        let tz = Day.cal.timeZone

        for e in sortedLogs {
            if e.type == LogType.bottle {
                if lastMap[LogType.bottle] == nil { lastMap[LogType.bottle] = e.startDate }
            } else if e.type != LogType.nurse && lastMap[e.type] == nil {
                lastMap[e.type] = e.endDate ?? e.startDate
            }
            if e.type == LogType.play {
                playCount += 1
                if let code = (e.detail ?? "").split(separator: " ").first.map(String.init), !code.isEmpty {
                    playsMap[code, default: []].append(e)
                }
            }
            let startDay = Day(e.startDate)
            byDay[startDay.epochDay, default: []].append(e)
            if let endMs = e.end, endMs > e.start {
                let endDay = Day(Date(timeIntervalSince1970: endMs / 1000))
                if endDay.epochDay > startDay.epochDay {
                    let limit = min(endDay.epochDay, startDay.epochDay + 30)
                    for ep in (startDay.epochDay + 1)...limit {
                        let midnightMs = Day(epochDay: ep).date.timeIntervalSince1970 * 1000
                        if endMs > midnightMs {
                            byDay[ep, default: []].append(e)
                        }
                    }
                }
            }
        }
        if let lastNurse = sortedLogs.filter({ $0.type == LogType.nurse }).feeds().last?.startDate {
            lastMap[LogType.nurse] = lastNurse
        }
        lastByType = lastMap
        playsByCode = playsMap
        playLogCount = playCount
        logsByDayEpoch = byDay
        indexedTimeZone = tz
    }
    private func changed(_ b: JournalFile.Body) {
        apply(b); seen = Self.stamp()
        Task { await LiveTimers.sync() }
        WidgetCenter.shared.reloadAllTimelines()
    }
    /// Applies a change and saves it under file coordination. Returns the pre-change body on success for 撤销.
    /// On a failed save nothing changes on screen, the failure is said in plain words (no undo, no success haptic),
    /// and the caller keeps what was typed.
    private func edit(_ f: (inout JournalFile.Body) -> Void) -> JournalFile.Body? {
        switch JournalFile.mutate({ b in f(&b); return true }) {
        case let .saved(before, after):
            changed(after)
            return before
        case .unchanged, .failed:
            failed()
            return nil
        }
    }
    private func mutateTimer(_ f: (inout JournalFile.Body) -> Bool) {
        switch JournalFile.mutate(f) {
        case let .saved(_, after): changed(after)
        case let .unchanged(b): apply(b)
        case .failed: failed(L10n.t("计时", "the timer"))
        }
    }
    private func failed(_ what: String = L10n.t("这条记录", "this entry")) {
        reload()
        toast = Toast(type: LogType.note, text: L10n.t("没有保存成功：" + what + "未写入，请再试一次", "Couldn't save: " + what + " wasn't saved. Please try again."), restore: nil, failed: true)
        onEvent?(.recordPersistFailure)
    }

    func start(_ type: String, side: String? = nil, at: Date = Date()) {
        switch JournalFile.mutate({ b in
            guard !b.timers.contains(where: { $0.type == type }) else { return false }
            b.timers.append(RunningTimer(type: type, start: at.timeIntervalSince1970 * 1000, side: side))
            return true
        }) {
        case let .saved(before, after):
            changed(after); focus = type
            if type == LogType.sleep { sleepsStarted &+= 1 }
            onEvent?(.recordStartConfirmed)
            let ago = Int(Date().timeIntervalSince(at) / 60)
            let sidePart = side == "l" ? L10n.t(" · 左侧", " · Left") : side == "r" ? L10n.t(" · 右侧", " · Right") : ""
            let agoPart = ago >= 1 ? L10n.t(" · 从 \(ago) 分钟前算起", " · from \(ago) min ago") : ""
            say(type, L10n.t(LogType.name(type) + "开始计时", LogType.name(type) + " started") + sidePart + agoPart, undo: before)
        case let .unchanged(b):
            apply(b); focus = type
        case .failed:
            failed(L10n.t("计时", "the timer"))
        }
    }
    func togglePause(_ type: String) {
        mutateTimer { b in
            guard b.timers.contains(where: { $0.type == type }) else { return false }
            b = JournalFile.pausing(b, type, now: JournalFile.now())
            return true
        }
    }
    func tapSide(_ type: String, _ side: String) {
        mutateTimer { b in
            guard b.timers.contains(where: { $0.type == type }) else { return false }
            b = JournalFile.tappingSide(b, type, side, now: JournalFile.now())
            return true
        }
    }
    func switchSide(_ type: String) {
        mutateTimer { b in
            guard b.timers.contains(where: { $0.type == type }) else { return false }
            b = JournalFile.switchingSide(b, type, now: JournalFile.now())
            return true
        }
    }
    func shift(_ type: String, to: Date) {
        mutateTimer { b in
            guard let i = b.timers.firstIndex(where: { $0.type == type }) else { return false }
            b.timers[i].start = min(to.timeIntervalSince1970 * 1000, JournalFile.now())
            return true
        }
    }
    /// Ends the timer now, or at the moment given (a feed found running long after it ended), and says what was kept.
    func stop(_ type: String, at: Date? = nil) {
        switch JournalFile.mutate({ b in
            // a second tap on 结束 (or one from the Lock Screen first) finds nothing running: no second entry, no reply
            guard b.timers.contains(where: { $0.type == type }) else { return false }
            b = JournalFile.stopping(b, type, now: at.map { ms($0) } ?? JournalFile.now())
            return true
        }) {
        case let .saved(before, after):
            changed(after)
            onEvent?(.recordPersistSuccess)
            if let e = after.logs.last, e.type == type {
                let durStr = durationValue(e.activeSeconds), endStr = hm(e.endDate ?? Date())
                say(type, L10n.t("已记下 " + LogType.name(type) + " · " + durStr + "，到 " + endStr, "Logged " + LogType.name(type) + " · " + durStr + ", ended " + endStr), undo: before)
            }
        case .unchanged:
            reload()
        case .failed:
            failed(L10n.t("这次" + LogType.name(type), LogType.name(type)))
        }
    }
    /// Drops a running timer; said back with 撤销, like every change that loses something.
    func discard(_ type: String) {
        // said only once it is really dropped (a failed save says so, with nothing to take back)
        guard let before = edit({ $0.timers.removeAll { $0.type == type } }) else { return }
        onEvent?(.timerEnded)
        say(type, L10n.t("没有记这一次" + LogType.name(type), "Discarded " + LogType.name(type)), undo: before)
    }

    @discardableResult func add(_ e: LogEntry) -> Bool { edit { $0.logs.append(e) } != nil }
    /// Adds an entry and says so ("已记下 尿布 · 湿 · 14:05"), with 撤销 for a few seconds. False when it could not be
    /// saved: then the page that asked stays open with what was typed.
    @discardableResult func record(_ e: LogEntry) -> Bool {
        guard let before = edit({ $0.logs.append(e) }) else { return false }
        onEvent?(.recordPersistSuccess)
        let what = [LogType.name(e.type), e.summary].filter { !$0.isEmpty }.joined(separator: " · ")
        let when = Day(e.startDate) == Day.today ? hm(e.startDate) : whenLabel(e.startDate)
        say(e.type, L10n.t("已记下 ", "Logged ") + what + " · " + when, undo: before)
        return true
    }
    /// Takes back what the toast describes: the journal as it was just before.
    func undo(_ t: Toast) {
        guard let b = t.restore else { return }
        // 已撤销 only when it is really back in the file
        guard JournalFile.write(b) else {
            // not written: said so, and 撤销 stays on the toast to try again
            reload()
            toast = Toast(type: t.type, text: L10n.t("没有撤销成功，点「撤销」再试一次", "Couldn't undo. Tap \"Undo\" to try again."), restore: b, failed: true)
            onEvent?(.recordPersistFailure)
            return
        }
        changed(b)
        toast = Toast(type: t.type, text: L10n.t("已撤销", "Undone"), restore: nil)
    }
    private func say(_ type: String, _ text: String, undo: JournalFile.Body?) { toast = Toast(type: type, text: text, restore: undo) }
    @discardableResult func update(_ e: LogEntry) -> Bool { edit { b in if let i = b.logs.firstIndex(where: { $0.id == e.id }) { b.logs[i] = e } } != nil }
    /// Several entries changed at once (the sides of one feed): one write — all or none — said back with 撤销.
    @discardableResult func update(_ es: [LogEntry], feed: Bool = false) -> Bool {
        guard let first = es.min(by: { $0.start < $1.start }) else { return true }
        guard let before = edit({ b in
            for e in es { if let i = b.logs.firstIndex(where: { $0.id == e.id }) { b.logs[i] = e } }
        }) else { return false }
        let what: String = feed || es.count > 1 ? L10n.t("已修改这一顿" + LogType.name(first.type), "Updated " + LogType.name(first.type)) : L10n.t("已修改 " + LogType.name(first.type), "Updated " + LogType.name(first.type))
        say(first.type, what + " · " + hm(first.startDate), undo: before)
        return true
    }
    /// Deleting is one tap (no confirmation to tap through at night): it is said back with 撤销 instead.
    func delete(_ e: LogEntry) {
        guard let before = edit({ $0.logs.removeAll { $0.id == e.id } }) else { return }
        say(e.type, L10n.t("已删除 ", "Deleted ") + LogType.name(e.type) + " · " + hm(e.startDate), undo: before)
    }
    /// A whole breast feed — its sides — at once: one change, one line said back, one 撤销.
    func delete(_ es: [LogEntry]) {
        guard let e = es.min(by: { $0.start < $1.start }) else { return }
        if es.count == 1 { delete(e); return }
        let ids = Set(es.map(\.id))
        guard let before = edit({ $0.logs.removeAll { ids.contains($0.id) } }) else { return }
        say(e.type, L10n.t("已删除这一顿" + LogType.name(e.type), "Deleted " + LogType.name(e.type)) + " · " + hm(e.startDate), undo: before)
    }
    /// Keeps a measurement and says so, with 撤销; false when it could not be saved (the sheet keeps what was typed).
    @discardableResult func saveMeasure(_ m: Measure) -> Bool {
        guard let before = edit({ b in if let i = b.measures.firstIndex(where: { $0.id == m.id }) { b.measures[i] = m } else { b.measures.append(m) } }) else { return false }
        say(LogType.growth, L10n.t("已记下测量 · ", "Logged measurement · ") + Day(Date(timeIntervalSince1970: m.at / 1000)).md, undo: before)
        return true
    }
    func deleteMeasure(_ m: Measure) {
        guard let before = edit({ $0.measures.removeAll { $0.id == m.id } }) else { return }
        say(LogType.growth, L10n.t("已删除这次测量 · ", "Deleted measurement · ") + Day(Date(timeIntervalSince1970: m.at / 1000)).md, undo: before)
    }
    /// Keeps a first (new or changed) and says so; false when it could not be saved.
    @discardableResult func saveFirst(_ f: First) -> Bool {
        let isNew = !firsts.contains { $0.id == f.id }
        guard let before = edit({ b in if let i = b.firsts.firstIndex(where: { $0.id == f.id }) { b.firsts[i] = f } else { b.firsts.append(f) } }) else { return false }
        onEvent?(.recordPersistSuccess)
        if isNew { toast = Toast(type: LogType.note, text: L10n.t("记下了第一次：", "Logged first: ") + f.title + " · " + whenLabelDay(f.date), restore: before) }
        return true
    }
    func deleteFirst(_ f: First) {
        guard let before = edit({ $0.firsts.removeAll { $0.id == f.id } }) else { return }
        say(LogType.note, L10n.t("已删除第一次：", "Deleted first: ") + f.title, undo: before)
    }
    @discardableResult func replaceAll(_ body: JournalFile.Body) -> Bool {
        guard JournalFile.write(body) else { failed(L10n.t("备份数据", "backup data")); return false }
        changed(body)
        return true
    }

    /// When the last one was: a feed by when it began (feeds are counted start to start), anything else — a sleep
    /// above all — by when it ended (when the baby woke).
    func last(_ type: String) -> Date? {
        lastByType[type]
    }
    /// The entries of a day: those that start on it, and those that run into it from the day before (a night's sleep
    /// belongs to both days, each counting its own part).
    func logs(on day: Day) -> [LogEntry] {
        guard !logs.isEmpty else { return [] }
        if Day.cal.timeZone == indexedTimeZone {
            return logsByDayEpoch[day.epochDay] ?? []
        }
        let a = day.date.timeIntervalSince1970 * 1000, b = day.plus(days: 1).date.timeIntervalSince1970 * 1000
        return logs.filter { e in (e.start >= a && e.start < b) || (e.start < a && (e.end ?? e.start) > a) }
    }
    /// Returns all entries belonging to the same feed as `id`, or `[]` if not part of a feed.
    func feedEntries(containing id: UUID) -> [LogEntry] {
        allFeeds.first { f in f.entries.contains { $0.id == id } }?.entries ?? []
    }
}

/// Observes cross-process Darwin notifications posted by widgets, Control Center, and Live Activities.
private final class ExternalJournalObserver: @unchecked Sendable {
    private let onChange: () -> Void
    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let box = Unmanaged<ExternalJournalObserver>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { box.onChange() }
            },
            JournalFile.darwinNotificationName,
            nil,
            .deliverImmediately
        )
    }
    deinit {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            CFNotificationName(JournalFile.darwinNotificationName),
            nil
        )
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
