import Foundation

/// Calendar days, as the content counts them (no time of day, no time zone surprises).
struct Day: Hashable, Comparable, Codable {
    let y: Int, m: Int, d: Int
    static var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = .current; return c }
    init(y: Int, m: Int, d: Int) { self.y = y; self.m = m; self.d = d }
    init(_ date: Date) { let c = Day.cal.dateComponents([.year, .month, .day], from: date); self.init(y: c.year!, m: c.month!, d: c.day!) }
    static var today: Day { Day(Date()) }
    var date: Date { Day.cal.date(from: DateComponents(year: y, month: m, day: d))! }
    /// days since 1970-01-01, as Android's LocalDate.toEpochDay
    var epochDay: Int {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
        let t = c.date(from: DateComponents(year: y, month: m, day: d))!
        return Int((t.timeIntervalSince1970 / 86400).rounded())
    }
    init(epochDay: Int) {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!
        let k = c.dateComponents([.year, .month, .day], from: Date(timeIntervalSince1970: Double(epochDay) * 86400))
        y = k.year!; m = k.month!; d = k.day!
    }
    func plus(days n: Int) -> Day { Day(epochDay: epochDay + n) }
    /// The same day of the month n months on (the last day of a shorter month), as java.time plusMonths.
    func plus(months n: Int) -> Day {
        let total = (y * 12 + (m - 1)) + n
        let ny = total / 12, nm = total % 12 + 1
        let last = Day.daysIn(ny, nm)
        return Day(y: ny, m: nm, d: min(d, last))
    }
    static func daysIn(_ y: Int, _ m: Int) -> Int {
        switch m { case 2: return (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31 }
    }
    func days(to o: Day) -> Int { o.epochDay - epochDay }
    static func < (a: Day, b: Day) -> Bool { a.epochDay < b.epochDay }
    /// Monday of this day's week
    var monday: Day { let wd = (epochDay + 3) % 7; return plus(days: -((wd + 7) % 7)) } // 1970-01-01 was a Thursday
    var weekdayIndex: Int { ((epochDay + 3) % 7 + 7) % 7 } // 0 = Monday
    var md: String { "\(m)月\(d)日" }
    var weekday: String { ["周一", "周二", "周三", "周四", "周五", "周六", "周日"][weekdayIndex] }
}

/// Age the way the content counts it: "满 m 个月" from the day of the month the child was born on.
struct Age: Equatable {
    let months: Int, days: Int, toNext: Int, lived: Int
    var bookMonth: Int { max(0, min(36, months)) }

    static func on(birth: Day, today: Day) -> Age {
        if today < birth { return Age(months: 0, days: 0, toNext: today.days(to: birth), lived: 0) }
        var m = max(0, (today.y - birth.y) * 12 + today.m - birth.m)
        if today < birth.plus(months: m) { m -= 1 }
        let start = birth.plus(months: m), next = birth.plus(months: m + 1)
        return Age(months: m, days: start.days(to: today), toNext: today.days(to: next), lived: birth.days(to: today) + 1)
    }
}
