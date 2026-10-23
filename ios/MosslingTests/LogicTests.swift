import XCTest
@testable import Mossling

final class LogicTests: XCTestCase {
    func testContentLoads() throws {
        let c = try Content.load()
        XCTAssertEqual(c.months.count, 37)
        XCTAssertEqual(c.activities.count, 46)
        XCTAssertNotNil(c.play("A11"))
        XCTAssertFalse(c.plays(of: 6).isEmpty)
        XCTAssertFalse(ArtIndex.shared.steps("A11").isEmpty)
    }

    func testEpochDayRoundTrip() {
        let d = Day(y: 2026, m: 4, d: 2)
        XCTAssertEqual(d.epochDay, 20545)   // java.time LocalDate.of(2026, 4, 2).toEpochDay()
        XCTAssertEqual(Day(epochDay: d.epochDay), d)
        XCTAssertEqual(Day(y: 1970, m: 1, d: 1).weekdayIndex, 3) // Thursday
        XCTAssertEqual(Day(y: 2026, m: 10, d: 22).monday, Day(y: 2026, m: 10, d: 19))
    }

    func testAgeCountsLikeTheContent() {
        let birth = Day(y: 2026, m: 4, d: 2)
        let a = Age.on(birth: birth, today: Day(y: 2026, m: 10, d: 19))
        XCTAssertEqual(a.months, 6); XCTAssertEqual(a.days, 17); XCTAssertEqual(a.toNext, 14); XCTAssertEqual(a.lived, 201)
        // born on the 31st: the month turns on the last day of a shorter month
        let b = Age.on(birth: Day(y: 2026, m: 1, d: 31), today: Day(y: 2026, m: 2, d: 28))
        XCTAssertEqual(b.months, 1); XCTAssertEqual(b.days, 0)
        XCTAssertEqual(Age.on(birth: birth, today: Day(y: 2029, m: 6, d: 1)).bookMonth, 36)
    }

    func testShelfFormatMatchesAndroid() throws {
        let c = try Content.load()
        let s = Shelf.format(Day(y: 2026, m: 10, d: 22), ["A11", "A08"])
        XCTAssertEqual(s, "\(Day(y: 2026, m: 10, d: 19).epochDay)|A11,A08")
        let cur = Shelf.current(c, 6, stored: s, today: Day(y: 2026, m: 10, d: 23))
        XCTAssertEqual(cur.plays.map(\.code), ["A11", "A08"]); XCTAssertFalse(cur.stale)
        XCTAssertTrue(Shelf.current(c, 6, stored: s, today: Day(y: 2026, m: 10, d: 27)).stale)
        XCTAssertEqual(Shelf.current(c, 6, stored: "", today: Day(y: 2026, m: 10, d: 23)).plays.count, 3)
    }

    func testGrowthMatchesWho() throws {
        let g = try Growth.load()
        // WHO girls weight-for-age, birth median 3.2322 kg; at 6 months median 7.2970 kg
        XCTAssertEqual(g.at(.weight, girl: true, months: 0, percentile: 50), 3.2322, accuracy: 0.01)
        XCTAssertEqual(g.at(.weight, girl: true, months: 6, percentile: 50), 7.297, accuracy: 0.02)
        XCTAssertEqual(g.percentile(.weight, girl: true, months: 6, value: g.at(.weight, girl: true, months: 6, percentile: 50)), 50, accuracy: 0.5)
        XCTAssertEqual(g.percentile(.weight, girl: true, months: 6, value: g.at(.weight, girl: true, months: 6, percentile: 97)), 97, accuracy: 0.5)
    }

    func testShapes() {
        XCTAssertFalse(Shapes.mossBody.isEmpty)
        let r = Shapes.mossBody.boundingRect
        XCTAssertEqual(r.minX, 14, accuracy: 2); XCTAssertEqual(r.maxX, 87.5, accuracy: 2)
        XCTAssertEqual(Shapes.mossTufts.boundingRect.minY, 41, accuracy: 3)
        XCTAssertFalse(Shapes.mintA.isEmpty)
    }

    // MARK: records — acceptance tests for the parents' feedback (midnight, pause, sides)

    private func t(_ d: Int, _ h: Int, _ mi: Int) -> Double {
        Day.cal.date(bySettingHour: h, minute: mi, second: 0, of: Day(y: 2026, m: 10, d: d).date)!.timeIntervalSince1970 * 1000
    }

    func testSleepAcrossMidnightCountsOnEachDay() {
        let s = LogEntry(type: LogType.sleep, start: t(18, 22, 0), end: t(19, 6, 30))
        XCTAssertEqual(s.seconds(on: Day(y: 2026, m: 10, d: 18)), 2 * 3600, accuracy: 1)
        XCTAssertEqual(s.seconds(on: Day(y: 2026, m: 10, d: 19)), 6.5 * 3600, accuracy: 1)
        XCTAssertEqual(s.seconds(on: Day(y: 2026, m: 10, d: 20)), 0)
        XCTAssertTrue(s.carriedOver(into: Day(y: 2026, m: 10, d: 19)))
        XCTAssertFalse(s.carriedOver(into: Day(y: 2026, m: 10, d: 18)))
    }

    func testPauseIsTakenOff() {
        // 20 minutes on the clock, 5 of them paused
        let e = LogEntry(type: LogType.nurse, start: t(19, 10, 0), end: t(19, 10, 20), side: "l", detail: "paused:300000")
        XCTAssertEqual(e.pausedSeconds, 300)
        XCTAssertEqual(e.activeSeconds, 900, accuracy: 0.5)
        XCTAssertEqual(e.seconds(on: Day(y: 2026, m: 10, d: 19)), 900, accuracy: 0.5)
        // a pause across midnight is shared out in proportion to each day's part
        let s = LogEntry(type: LogType.sleep, start: t(18, 23, 0), end: t(19, 1, 0), detail: "paused:1200000")
        XCTAssertEqual(s.seconds(on: Day(y: 2026, m: 10, d: 18)) + s.seconds(on: Day(y: 2026, m: 10, d: 19)), 100 * 60, accuracy: 1)
        // other text in detail is not a pause
        XCTAssertEqual(LogEntry(type: LogType.solid, start: 0, detail: "米粉").pausedSeconds, 0)
    }

    func testStoppingWhilePausedDoesNotTakeThePauseOffTwice() {
        var b = JournalFile.Body()
        // started 10:00, paused 10:05–10:07, paused again at 10:15, stopped at 10:20
        b.timers = [RunningTimer(type: LogType.nurse, start: t(19, 10, 0), side: "l", pausedAt: t(19, 10, 15), pausedTotal: 120_000)]
        let out = JournalFile.stopping(b, LogType.nurse, now: t(19, 10, 20))
        XCTAssertTrue(out.timers.isEmpty)
        let e = out.logs[0]
        XCTAssertEqual(e.end, t(19, 10, 15))
        XCTAssertEqual(e.activeSeconds, 13 * 60, accuracy: 0.5)    // 15 minutes less the 2-minute pause
    }

    func testSwitchingSidesKeepsEachSide() {
        var b = JournalFile.Body()
        b.timers = [RunningTimer(type: LogType.nurse, start: t(19, 10, 0), side: "l")]
        b = JournalFile.switchingSide(b, LogType.nurse, now: t(19, 10, 8))
        XCTAssertEqual(b.logs.count, 1)
        XCTAssertEqual(b.logs[0].side, "l"); XCTAssertEqual(b.logs[0].activeSeconds, 480, accuracy: 0.5)
        XCTAssertEqual(b.timers[0].side, "r"); XCTAssertEqual(b.timers[0].start, t(19, 10, 8))
        b = JournalFile.stopping(b, LogType.nurse, now: t(19, 10, 15))
        XCTAssertEqual(b.logs.count, 2)
        XCTAssertEqual(b.logs[1].side, "r"); XCTAssertEqual(b.logs[1].activeSeconds, 420, accuracy: 0.5)
        // one feed, both sides, as the timer screen shows them
        XCTAssertEqual(b.logs.feedCount(), 1)
        let sides = b.logs.feedSides(before: b.logs[1].end!)
        XCTAssertEqual(sides["l"] ?? 0, 480, accuracy: 0.5)
        XCTAssertEqual(sides["r"] ?? 0, 420, accuracy: 0.5)
        // a feed two hours later is a second feed; a bottle is a feed of its own
        let more = b.logs + [LogEntry(type: LogType.nurse, start: t(19, 12, 15), end: t(19, 12, 30), side: "l"), LogEntry(type: LogType.bottle, start: t(19, 15, 0), amount: 90)]
        XCTAssertEqual(more.feedCount(), 3)
    }

    func testATapOnTheOtherSideRightAwayIsNotAnEntry() {
        var b = JournalFile.Body()
        b.timers = [RunningTimer(type: LogType.nurse, start: t(19, 10, 0), side: "l")]
        b = JournalFile.switchingSide(b, LogType.nurse, now: t(19, 10, 0) + 10_000)
        XCTAssertTrue(b.logs.isEmpty)
        XCTAssertEqual(b.timers[0].side, "r"); XCTAssertEqual(b.timers[0].start, t(19, 10, 0))
    }

    @MainActor func testSideEntriesExportInTheAndroidFormat() throws {
        // the entries a side change writes go out through the shared record file with only Android's fields
        var b = JournalFile.Body()
        b.timers = [RunningTimer(type: LogType.nurse, start: t(19, 10, 0), side: "l", pausedTotal: 60_000)]
        b = JournalFile.switchingSide(b, LogType.nurse, now: t(19, 10, 8))
        let app = AppModel(defaults: UserDefaults(suiteName: "export-\(UUID().uuidString)")!)
        let root = try JSONSerialization.jsonObject(with: RecordFile.json(app, b)) as! [String: Any]
        let logs = (root["mossling"] as! [String: Any])["logs"] as! [[String: Any]]
        XCTAssertEqual(logs.count, 1)
        XCTAssertTrue(Set(logs[0].keys).isSubset(of: ["type", "start", "end", "amount", "side", "detail"]), "\(logs[0].keys)")
        XCTAssertEqual(logs[0]["side"] as? String, "l")
        XCTAssertEqual(logs[0]["detail"] as? String, "paused:60000")
        XCTAssertEqual((logs[0]["end"] as? NSNumber)?.int64Value, Int64(t(19, 10, 8)))
    }
}
