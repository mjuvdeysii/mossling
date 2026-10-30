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
    /// 今天一起玩: the one play for today — the one chosen with 换一个 today, else the week's least played this week
    /// (then least played in all, then the week's order). The home page, its header and the widget all read this.
    func todayPlay(_ month: Int, _ j: JournalStore) -> Play? {
        let s = weekShelf(month).plays
        if let c = Shelf.pick(pick, today: today), let p = s.first(where: { $0.code == c }) { return p }
        let code = Shelf.first(s.map(\.code), week: { c in s.first { $0.code == c }.map { thisWeek($0, j) } ?? 0 },
                               total: { c in s.first { $0.code == c }.map { record($0, j).count } ?? 0 })
        return s.first { $0.code == code }
    }
    /// 换一个: the next of the week's plays after today's, for the rest of the day.
    func anotherToday(_ month: Int, _ j: JournalStore) {
        let s = weekShelf(month).plays
        guard s.count > 1, let now = todayPlay(month, j), let i = s.firstIndex(of: now) else { return }
        pick = Shelf.formatPick(s[(i + 1) % s.count].code, today: today)
    }
    /// Choose a play for today (from its page's menu); it joins the week if it is not in it and there is room.
    func playToday(_ p: Play, _ month: Int) {
        let codes = weekShelf(month).plays.map(\.code)
        if !codes.contains(p.code) { setShelf(Array((codes.count < Shelf.max ? codes : Array(codes.dropLast())) + [p.code])) }
        pick = Shelf.formatPick(p.code, today: today)
    }
    /// Records one time played; false (and nothing ticked, nothing cheered) when it could not be saved.
    @discardableResult func didPlay(_ p: Play, month: Int, _ j: JournalStore) -> Bool {
        // said back like every record, with 撤销
        guard j.record(LogEntry(type: LogType.play, start: JournalFile.now(), detail: "\(p.code) \(p.name)")) else { return false }
        if !ticked(month, TickKind.did, p.code) { toggle(month, TickKind.did, p.code, p.name) }
        return true
    }
    func undoPlay(_ p: Play, month: Int, _ j: JournalStore) {
        if let e = j.plays(p.code).first { j.delete(e) }
        if j.plays(p.code).isEmpty && ticked(month, TickKind.did, p.code) { toggle(month, TickKind.did, p.code, p.name) }
    }
}
