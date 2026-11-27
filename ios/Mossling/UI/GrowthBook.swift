import SwiftUI

/// One month of the book, gathered from the records for `StorybookView`.
struct BookPage {
    let month: Int
    let from: Date, to: Date
    let plays: [(play: Play, times: Int)]
    let observed: Int
    let measure: Measure?
    /// Days in the month with any care record, and the averages over those days.
    let days: Int
    let sleepHours: Double?, feeds: Double?, diapers: Double?
    let notes: [LogEntry]
    /// The firsts of this month (第一次), oldest first.
    let firsts: [First]
    var empty: Bool { plays.isEmpty && observed == 0 && measure == nil && days == 0 && notes.isEmpty && firsts.isEmpty }

    static func all(_ app: AppModel, _ j: JournalStore) -> [BookPage] {
        guard let birth = app.birth, let maxMonth = app.actualAge?.bookMonth ?? app.babyMonth else { return [] }
        let now = Date()
        let endOfToday = app.today.plus(days: 1).date
        let cutoff = max(now, endOfToday)
        return (0...maxMonth).reversed().map { m in
            let from = birth.plus(months: m).date, to = min(birth.plus(months: m + 1).date, cutoff)
            let a = from.timeIntervalSince1970 * 1000, b = to.timeIntervalSince1970 * 1000
            let logs = j.logs.filter { $0.start >= a && $0.start < b }
            var times: [String: Int] = [:], order: [String] = []
            for l in logs.reversed() where l.type == LogType.play {
                guard let code = (l.detail ?? "").split(separator: " ").first.map(String.init) else { continue }
                if times[code] == nil { order.append(code) }
                times[code, default: 0] += 1
            }
            for t in app.ticks.values.sorted(by: { $0.at < $1.at }) where t.month == m && t.kind == TickKind.did {
                let code = String(t.key.split(separator: ":").last ?? "")
                if times[code] == nil && j.plays(code).isEmpty { times[code] = 1; order.append(code) }
            }
            let plays = order.compactMap { c in app.content.play(c).map { (play: $0, times: times[c] ?? 1) } }
            let care = logs.filter { [LogType.nurse, LogType.bottle, LogType.sleep, LogType.diaper].contains($0.type) }
            let days = Set(care.map { Day($0.startDate) }).count
            let feeds = care.feeds().count
            let completedSleeps = care.filter { $0.type == LogType.sleep && Day($0.startDate) < app.today }
            let sleepDays = Set(completedSleeps.map { Day($0.startDate) }).count
            let sleep = completedSleeps.reduce(0) { $0 + $1.activeSeconds }
            let diapers = care.filter { $0.type == LogType.diaper }.count
            let d = Double(max(days, 1))
            return BookPage(month: m, from: from, to: to, plays: plays, observed: app.count(m, TickKind.observed),
                            measure: j.measures.last { $0.at >= a && $0.at < b }, days: days,
                            sleepHours: (sleepDays > 0 && sleep > 0) ? sleep / 3600 / Double(sleepDays) : nil,
                            feeds: feeds > 0 ? Double(feeds) / d : nil,
                            diapers: diapers > 0 ? Double(diapers) / d : nil,
                            notes: Array(logs.filter { $0.type == LogType.note && !($0.detail ?? "").isEmpty }.prefix(3)),
                            firsts: j.firsts.filter { $0.at >= a && $0.at < b }.sorted { $0.at < $1.at })
        }
    }
}

/// Items laid out a few to a row, spread evenly over the rows they need: rows differ by at most one, the fuller
/// rows first (four in rows of three become two and two, five become three and two, seven three, two and two), and
/// each row's items share its width — so no row is a lone tile pulled across the page. When one must stand alone
/// (an odd count two to a row), it is told so through `aloneInRow`, and a cell that has a wide form uses it rather
/// than stretching the narrow one.
struct EvenRows<Item, ID: Hashable, Cell: View>: View {
    let items: [Item]
    let id: KeyPath<Item, ID>
    var per = 2
    var spacing: CGFloat = 8
    @ViewBuilder let cell: (Item) -> Cell
    /// Where each row starts and ends.
    static func rows(_ n: Int, per: Int) -> [Range<Int>] {
        guard n > 0 else { return [] }
        let p = max(1, per), r = (n + p - 1) / p, base = n / r, extra = n % r
        var out: [Range<Int>] = [], at = 0
        for k in 0..<r { let len = base + (k < extra ? 1 : 0); out.append(at..<(at + len)); at += len }
        return out
    }
    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Self.rows(items.count, per: per), id: \.lowerBound) { r in
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(items[r], id: id) { x in
                        cell(x).frame(maxWidth: .infinity).environment(\.aloneInRow, r.count == 1 && per > 1)
                    }
                }
            }
        }
    }
}

extension EnvironmentValues {
    /// This cell stands alone across a row meant for several: use a wide form if there is one.
    @Entry var aloneInRow: Bool = false
}
