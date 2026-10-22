import Foundation

/// The week's shelf: three or four materials for the whole week, rotated when the week turns.
/// Stored as "<epoch day of the week's Monday>|CODE,CODE" — the same as on Android.
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
    static func suggest(_ c: Content, _ m: Int, last: [String]) -> [String] {
        let all = candidates(c, m).map(\.code)
        return Array((all.filter { !last.contains($0) } + all.filter { last.contains($0) }).prefix(3))
    }
    /// This week's shelf, and whether it is last week's (time to rotate).
    static func current(_ c: Content, _ m: Int, stored: String, today: Day) -> (plays: [Play], stale: Bool) {
        let st = parse(stored)
        let codes = (st?.codes ?? []).filter { c.play($0) != nil }
        if codes.isEmpty { return (suggest(c, m, last: []).compactMap { c.play($0) }, false) }
        return (codes.compactMap { c.play($0) }, st!.week != today.monday)
    }
}
