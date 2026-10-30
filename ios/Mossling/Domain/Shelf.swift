import Foundation

/// The week's plays (「这周一起玩」): three or four for the whole week, turned by themselves when the week turns; one of
/// them is today's (「今天一起玩」). Stored as "<epoch day of the week's Monday>|CODE,CODE" — the same as on Android
/// (where it is still called the shelf).
enum Shelf {
    static let max = 4
    struct State { let week: Day; let codes: [String] }

    static func parse(_ s: String) -> State? {
        let p = s.split(separator: "|", omittingEmptySubsequences: false)
        guard p.count == 2, let w = Int(p[0]) else { return nil }
        return State(week: Day(epochDay: w), codes: p[1].split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }
    static func format(_ week: Day, _ codes: [String]) -> String { "\(week.monday.epochDay)|" + codes.prefix(max).joined(separator: ",") }

    static func candidates(_ c: Content, _ m: Int) -> [Play] {
        let own = c.plays(of: m)
        let codes = Set(own.map(\.code))
        return own + c.activities.filter { (m >= $0.from && m <= $0.to) && !codes.contains($0.code) }
    }
    /// A new week's plays: three, from as many areas as the month offers, those not played before first, last
    /// week's last of all — so the week turns by itself and does not leave out a whole area (at 0 months 趴卧 is
    /// among them, not crowded out by two of a kind).
    static func suggest(_ c: Content, _ m: Int, last: [String], played: (String) -> Int = { _ in 0 }) -> [String] {
        let all = candidates(c, m)
        let fresh = all.filter { !last.contains($0.code) }, old = all.filter { last.contains($0.code) }
        // stable: the month's own first, then not yet played before played
        let order = fresh.filter { played($0.code) == 0 } + fresh.filter { played($0.code) > 0 } + old
        var out: [Play] = [], areas = Set<String>()
        for p in order where out.count < 3 && !areas.contains(Palette.areaKey(of: p)) { out.append(p); areas.insert(Palette.areaKey(of: p)) }
        for p in order where out.count < 3 && !out.contains(p) { out.append(p) }
        return out.map(\.code)
    }
    /// The week as it should stand today: last week's turned into a new one, and anything the child has outgrown
    /// (the month changed mid-week) replaced. Nil when it already stands right. The stored form never changes.
    static func roll(_ c: Content, _ m: Int, stored: String, today: Day, played: (String) -> Int = { _ in 0 }) -> String? {
        let st = parse(stored)
        let codes = (st?.codes ?? []).filter { c.play($0) != nil }
        if st == nil || codes.isEmpty || st!.week != today.monday {
            return format(today, suggest(c, m, last: codes, played: played))
        }
        // only what the child has outgrown goes (past its last month); a play the parent added from another month
        // stays for the week they put it there
        let kept = codes.filter { c.play($0).map { m <= $0.to } ?? false }
        if kept.count == codes.count { return nil }
        let more = suggest(c, m, last: codes, played: played).filter { !kept.contains($0) }
        return format(today, kept + more.prefix(Swift.max(0, 3 - kept.count)))
    }
    /// This week's plays (as stored; a week not yet rolled reads as the one it would become).
    static func current(_ c: Content, _ m: Int, stored: String, today: Day) -> (plays: [Play], stale: Bool) {
        let st = parse(stored)
        let codes = (st?.codes ?? []).filter { c.play($0) != nil }
        if codes.isEmpty { return (suggest(c, m, last: []).compactMap { c.play($0) }, false) }
        return (codes.compactMap { c.play($0) }, st!.week != today.monday)
    }
    /// Today's pick, stored as "<epoch day>|CODE": a choice made with 换一个 lasts the day it was made.
    static func pick(_ stored: String, today: Day) -> String? {
        let p = stored.split(separator: "|")
        guard p.count == 2, Int(p[0]) == today.epochDay else { return nil }
        return String(p[1])
    }
    static func formatPick(_ code: String, today: Day) -> String { "\(today.epochDay)|\(code)" }

    /// The one weekly count: how many of these times fall in the week that began at `since`. The shelf's beads, its
    /// stones and 先玩这件 all read this — never a second definition.
    static func week(_ times: [Date], since: Date) -> Int { times.filter { $0 >= since }.count }

    /// 先玩这件: the one played least this week; between equals, the one played least in all; then shelf order.
    static func first(_ codes: [String], week: (String) -> Int, total: (String) -> Int) -> String? {
        codes.enumerated().min { a, b in
            let x = (week(a.element), total(a.element), a.offset), y = (week(b.element), total(b.element), b.offset)
            return x < y
        }?.element
    }
}
