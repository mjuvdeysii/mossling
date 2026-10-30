import Foundation

/// Plays done together are kept in the journal as entries of the kind "play" whose detail is "CODE name" — the same as
/// on Android — so each time counts, and the record file carries them.
extension JournalStore {
    func plays(_ code: String) -> [LogEntry] {
        logs.filter { $0.type == LogType.play && ($0.detail ?? "").split(separator: " ").first.map(String.init) == code }
    }
}

struct PlayRecord {
    let count: Int
    let last: Date?
}

extension AppModel {
    /// How many times a play has been done, and when last. A month marked done before counts once.
    func record(_ p: Play, _ j: JournalStore) -> PlayRecord {
        let l = j.plays(p.code)
        let legacy = l.isEmpty && ticks.values.contains { $0.kind == TickKind.did && $0.key.hasSuffix(":\(TickKind.did):\(p.code)") }
        return PlayRecord(count: legacy ? 1 : l.count, last: l.first?.startDate)
    }
    /// Times this play was done this week (the shelf's one weekly count).
    func thisWeek(_ p: Play, _ j: JournalStore) -> Int { Shelf.week(j.plays(p.code).map(\.startDate), since: today.monday.date) }
    /// 今天一起玩: the one play for today — the one chosen today (换一个, 今天玩这个), else the week's least played this
    /// week (then least played in all, then the week's order), counted up to the start of today: so playing it does
    /// not swap it for another — it stays today's, and says 今天玩过. The home page, its header and the widget all read
    /// this.
    func todayPlay(_ month: Int, _ j: JournalStore) -> Play? {
        let s = weekShelf(month).plays
        if let c = Shelf.pick(pick, today: today), let p = content.play(c) { return p }
        let start = today.date
        let before = { (p: Play) in j.plays(p.code).map(\.startDate).filter { $0 < start } }
        let code = Shelf.first(s.map(\.code),
                               week: { c in s.first { $0.code == c }.map { Shelf.week(before($0), since: self.today.monday.date) } ?? 0 },
                               total: { c in s.first { $0.code == c }.map { p in before(p).count + (self.record(p, j).count > 0 && before(p).isEmpty && j.plays(p.code).isEmpty ? 1 : 0) } ?? 0 })
        return s.first { $0.code == code }
    }
    /// 换一个: the next of the week's plays after today's, for the rest of the day.
    func anotherToday(_ month: Int, _ j: JournalStore) {
        let s = weekShelf(month).plays
        guard s.count > 1, let now = todayPlay(month, j) else { return }
        let i = s.firstIndex(of: now) ?? -1
        pick = Shelf.formatPick(s[(i + 1) % s.count].code, today: today)
    }
    /// Choose a play for today (from its page's menu). It joins the week when there is room; when the week is full it
    /// is today's all the same, and the week stays as it is (nothing taken off without asking).
    func playToday(_ p: Play, _ month: Int) {
        let codes = weekShelf(month).plays.map(\.code)
        if !codes.contains(p.code) && codes.count < Shelf.max { setShelf(codes + [p.code]) }
        pick = Shelf.formatPick(p.code, today: today)
    }
    /// The plays done in the child's month `m` (by the dates of their entries — the records are the one source; a
    /// mark from before plays were dated counts only for a play that has no entries at all), in the order first done.
    func played(in m: Int, _ j: JournalStore) -> [String] {
        var out: [String] = []
        if let b = birth {
            let a = b.plus(months: m).date, z = b.plus(months: m + 1).date
            for l in j.logs.reversed() where l.type == LogType.play && l.startDate >= a && l.startDate < z {
                if let c = (l.detail ?? "").split(separator: " ").first.map(String.init), !out.contains(c) { out.append(c) }
            }
        }
        for t in ticks.values.sorted(by: { $0.at < $1.at }) where t.month == m && t.kind == TickKind.did {
            let c = String(t.key.split(separator: ":").last ?? "")
            if !out.contains(c) && j.plays(c).isEmpty { out.append(c) }
        }
        return out
    }
    /// Records one time played (an entry in the records — the only place a play is counted); false when it could
    /// not be saved.
    @discardableResult func didPlay(_ p: Play, month: Int, _ j: JournalStore) -> Bool {
        // said back like every record, with 撤销
        guard j.record(LogEntry(type: LogType.play, start: JournalFile.now(), detail: "\(p.code) \(p.name)")) else { return false }
        return true
    }
    func undoPlay(_ p: Play, month: Int, _ j: JournalStore) {
        if let e = j.plays(p.code).first { j.delete(e); return }
        // a play marked done before plays were dated has no entry to take back: its mark goes instead
        if ticked(month, TickKind.did, p.code) { toggle(month, TickKind.did, p.code, p.name) }
    }
}
