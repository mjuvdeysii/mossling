import Foundation

/// Calendar days, as the content counts them (no time of day, no time zone surprises).
struct Day: Hashable, Comparable, Codable {
    let y: Int, m: Int, d: Int
    static var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        #if DEBUG
        if let z = testZone { c.timeZone = z }
        #endif
        return c
    }
    #if DEBUG
    /// Screenshots read the clock in a zone of their own (the same morning whenever they are made).
    nonisolated(unsafe) static var testZone: TimeZone?
    #endif
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
    /// "11月19日" / "Nov 19".
    var md: String { L10n.isEnglish ? "\(Day.enMonths[m - 1]) \(d)" : "\(m)月\(d)日" }
    /// "2026年11月19日" / "Nov 19, 2026".
    var ymd: String { L10n.isEnglish ? "\(Day.enMonths[m - 1]) \(d), \(y)" : "\(y)年\(m)月\(d)日" }
    /// The date, with the year only when it is not this year.
    var mdOrYmd: String { y == Day.today.y ? md : ymd }
    /// "周一" / "Mon".
    var weekday: String {
        L10n.isEnglish ? ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][weekdayIndex] : ["周一", "周二", "周三", "周四", "周五", "周六", "周日"][weekdayIndex]
    }
    /// One character for a week strip: "一" / "M".
    var weekdayInitial: String {
        L10n.isEnglish ? ["M", "T", "W", "T", "F", "S", "S"][weekdayIndex] : ["一", "二", "三", "四", "五", "六", "日"][weekdayIndex]
    }
    static let enMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
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

    static func isPreterm(_ gestationalWeeks: Int?) -> Bool {
        guard let w = gestationalWeeks else { return false }
        return (22...36).contains(w)
    }

    /// Shifts chronological birth forward to the 40-week expected due date for preterm babies (< 37 weeks).
    static func correctedBirth(birth: Day, gestationalWeeks: Int?) -> Day {
        guard let w = gestationalWeeks, isPreterm(w) else { return birth }
        return birth.plus(days: (40 - w) * 7)
    }

    /// Dual-track developmental corrected age used until 24 chronological months for preterm babies (< 37 weeks).
    static func corrected(birth: Day, gestationalWeeks: Int?, today: Day) -> Age? {
        guard isPreterm(gestationalWeeks) else { return nil }
        let actual = on(birth: birth, today: today)
        guard actual.months < 24 else { return nil }
        let cb = correctedBirth(birth: birth, gestationalWeeks: gestationalWeeks)
        if today.epochDay < cb.epochDay {
            return Age(months: 0, days: 0, toNext: max(1, today.days(to: cb)), lived: max(1, birth.days(to: today) + 1))
        }
        return on(birth: cb, today: today)
    }
}
