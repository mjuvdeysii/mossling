import XCTest
import SwiftUI
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

    func testAFeedAcrossMidnightCountsOnTheDayItBegan() {
        let logs = [LogEntry(type: LogType.nurse, start: t(18, 23, 55), end: t(19, 0, 5), side: "l"),
                    LogEntry(type: LogType.nurse, start: t(19, 0, 5), end: t(19, 0, 12), side: "r")]
        XCTAssertEqual(logs.feedCount(from: Day(y: 2026, m: 10, d: 19).date.timeIntervalSince1970 * 1000), 0)
        XCTAssertEqual(logs.feedCount(from: Day(y: 2026, m: 10, d: 18).date.timeIntervalSince1970 * 1000), 1)
    }

    func testReleaseRequirementsAreInTheBundle() {
        // App Store: a privacy manifest in the app; the legal documents shown in the app; export compliance declared
        XCTAssertNotNil(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"), "PrivacyInfo.xcprivacy is not in the app bundle")
        for d in ["PRIVACY", "TERMS", "DISCLAIMER", "CHANGELOG"] { XCTAssertNotNil(Bundle.main.url(forResource: d, withExtension: "md"), d) }
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool, false)
        XCTAssertNotNil(Bundle.main.object(forInfoDictionaryKey: "NSFaceIDUsageDescription"))
    }

    func testEveryPlayHasItsTrayAndEveryAreaItsSticker() {
        let c = try! Content.load()
        for p in c.activities { XCTAssertNotNil(ArtIndex.shared.size["tray_\(p.code.lowercased()).webp"], p.code) }
        for k in ["A", "B", "C", "D", "E", "F"] { XCTAssertNotNil(IconTile.sticker(Palette.areaSymbol(k)), k) }
        for t in LogType.buttons { XCTAssertNotNil(IconTile.sticker(LogType.symbol(t)), t) }
    }

    func testChangingSidesNeverLooksLikeAReset() {
        // reported: changing sides from the widget set the clock back to 0:00 — every clock must show the whole feed
        var b = JournalFile.Body()
        b.timers = [RunningTimer(type: LogType.nurse, start: t(19, 10, 0), side: "l", pausedTotal: 60_000)]
        let before = b.timers[0].total(t(19, 10, 8))                      // 8 min less a 1-min pause = 7 min
        b = JournalFile.switchingSide(b, LogType.nurse, now: t(19, 10, 8))
        let after = b.timers[0].total(t(19, 10, 8))
        XCTAssertEqual(before, 420, accuracy: 0.5)
        XCTAssertEqual(after, before, accuracy: 0.5, "the clock jumped when the side changed")
        XCTAssertEqual(b.timers[0].total(t(19, 10, 10)), 540, accuracy: 0.5)   // and keeps counting the whole feed
        XCTAssertEqual(b.timers[0].elapsed(t(19, 10, 10)), 120, accuracy: 0.5) // while the side counts from its change
        // a Live Activity counting up from countsFrom shows the same total
        XCTAssertEqual(Date(timeIntervalSince1970: t(19, 10, 10) / 1000).timeIntervalSince(b.timers[0].countsFrom), 540, accuracy: 0.5)
        // a file written before `carried` existed still reads
        let old = #"{"type":"nurse","start":1000,"side":"l","pausedTotal":0}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(RunningTimer.self, from: old).carried, 0)
    }

    /// The bead chain: every month has its own place, a touch on a bead picks that bead, and the years wind (the end of
    /// one year sits right above the start of the next).
    func testShortPhrasesNeverBreak() {
        let u = unbroken("共 8 小时 30 分")
        XCTAssertFalse(u.contains(" "))
        XCTAssertEqual(u.replacingOccurrences(of: "\u{2060}", with: "").replacingOccurrences(of: "\u{00A0}", with: " "), "共 8 小时 30 分")
        let long = String(repeating: "很长的备注", count: 5)
        XCTAssertEqual(unbroken(long), long)
    }

    func testTheGrowthPathWinds() {
        let w: CGFloat = 329
        var seen = Set<String>()
        for m in 0...36 {
            let p = MapGeo.point(m, width: w)
            XCTAssertTrue(seen.insert("\(Int(p.x))-\(Int(p.y))").inserted, "two months share a place")
            XCTAssertEqual(MapGeo.month(near: p, width: w), m)
            XCTAssertEqual(MapGeo.month(near: CGPoint(x: p.x + 4, y: p.y - 6), width: w), m, "a touch a little off still picks it")
            XCTAssertTrue(p.x >= 0 && p.x <= w)
        }
        XCTAssertEqual(MapGeo.point(12, width: w).x, MapGeo.point(13, width: w).x, accuracy: 0.01)
        XCTAssertEqual(MapGeo.point(24, width: w).x, MapGeo.point(25, width: w).x, accuracy: 0.01)
        // growing up is walking on up the hills: birth at the foot, three years at the top
        XCTAssertGreaterThan(MapGeo.point(0, width: w).y, MapGeo.point(36, width: w).y)
        // Moss (up to 66 points) stands on any stone without leaving the map
        for m in 0...36 { XCTAssertGreaterThanOrEqual(MapGeo.point(m, width: w).y - 66, 0) }
    }

    /// Night mode is where contrast breaks first (a bright fill under white text, a dark ink on the lamp page), so
    /// every colour role is checked against every surface it is drawn on, in both appearances (WCAG 2.2: 4.5:1 for
    /// text, 3:1 for large or bold text and controls).
    func testEveryColourRoleReadsByDayAndAtNight() {
        func lum(_ c: Color, _ scheme: ColorScheme) -> Double {
            var env = EnvironmentValues(); env.colorScheme = scheme
            let r = c.resolve(in: env)   // linear components
            return 0.2126 * Double(r.linearRed) + 0.7152 * Double(r.linearGreen) + 0.0722 * Double(r.linearBlue)
        }
        func ratio(_ a: Color, _ b: Color, _ s: ColorScheme) -> Double {
            let x = lum(a, s), y = lum(b, s); return (max(x, y) + 0.05) / (min(x, y) + 0.05)
        }
        let crayons: [(String, Color)] = [("teal", Crayon.teal), ("pink", Crayon.pink), ("sunflower", Crayon.sunflower), ("cherry", Crayon.cherry),
                                          ("sky", Crayon.sky), ("tangerine", Crayon.tangerine), ("lilac", Crayon.lilac), ("peach", Crayon.peach)]
        let paper = Color(hex: 0xFBF7F0), white = Color.white
        let darkSurfaces: [(String, Color)] = [("dark page", Palette.background), ("lamp page", Palette.lampPage), ("lamp card", Palette.lampCard), ("grouped cell", Color(hex: 0x2C2C2E)),
                                               ("dark card", Palette.card), ("dark fill", Palette.fill)]
        for (n, c) in crayons {
            XCTAssertGreaterThanOrEqual(ratio(Crayon.ink(c), paper, .light), 4.5, "\(n) ink on paper")
            XCTAssertGreaterThanOrEqual(ratio(Crayon.ink(c), white, .light), 4.5, "\(n) ink on a white card")
            for (sn, s) in darkSurfaces { XCTAssertGreaterThanOrEqual(ratio(Crayon.ink(c), s, .dark), 4.5, "\(n) ink on the \(sn)") }
            for scheme in [ColorScheme.light, .dark] {
                XCTAssertGreaterThanOrEqual(ratio(Crayon.buttonFill(c), white, scheme), 4.5, "white text on \(n) button fill")
                XCTAssertGreaterThanOrEqual(ratio(Crayon.fill(c, true), white, scheme), 4.5, "white text on \(n) fill under the lamp")
            }
        }
        for (sn, s) in darkSurfaces.dropFirst() { XCTAssertGreaterThanOrEqual(ratio(Palette.lampTint, s, .dark), 4.5, "lamp tint on the \(sn)") }
        XCTAssertGreaterThanOrEqual(ratio(Palette.lampTint, white, .dark), 3, "white on the lamp tint (selected day, prominent button)")
        XCTAssertGreaterThanOrEqual(ratio(Palette.accent, paper, .light), 4.5)
        // secondary text on paper, a white card, the fill, and the faintly tinted cards (lilac, peach, sunflower washes)
        for (sn, s) in [("paper", paper), ("white", white), ("fill", Color(hex: 0xF2EBE0)), ("lilac card", Color(hex: 0xF1ECF8)), ("peach card", Color(hex: 0xFCEBDD))] {
            XCTAssertGreaterThanOrEqual(ratio(Palette.secondaryText, s, .light), 4.5, "secondary text on \(sn)")
        }
        for (sn, s) in darkSurfaces.dropFirst() { XCTAssertGreaterThanOrEqual(ratio(Palette.secondaryText, s, .dark), 4.5, "secondary text on the \(sn)") }
        XCTAssertGreaterThanOrEqual(ratio(Palette.accent, Palette.background, .dark), 4.5)
        XCTAssertGreaterThanOrEqual(ratio(Palette.accentFill, white, .dark), 4.5)
    }

    func testOneTapOnASidePausesOrChangesSides() {
        // the feeding screen has one gesture: tap the side being fed to pause or go on, tap the other side to change
        var b = JournalFile.Body()
        b.timers = [RunningTimer(type: LogType.nurse, start: t(19, 10, 0), side: "l")]
        b = JournalFile.tappingSide(b, LogType.nurse, "l", now: t(19, 10, 5))          // pause on the left
        XCTAssertEqual(b.timers[0].pausedAt, t(19, 10, 5))
        b = JournalFile.tappingSide(b, LogType.nurse, "l", now: t(19, 10, 7))          // go on
        XCTAssertNil(b.timers[0].pausedAt)
        XCTAssertEqual(b.timers[0].paused(t(19, 10, 7)), 120, accuracy: 0.5)
        b = JournalFile.tappingSide(b, LogType.nurse, "l", now: t(19, 10, 9))          // pause again …
        b = JournalFile.tappingSide(b, LogType.nurse, "r", now: t(19, 10, 10))         // … and change sides while paused
        XCTAssertNil(b.timers[0].pausedAt, "changing sides runs the clock")
        XCTAssertEqual(b.timers[0].side, "r")
        XCTAssertEqual(b.logs.count, 1); XCTAssertEqual(b.logs[0].activeSeconds, 7 * 60, accuracy: 0.5)
        // the whole feed: 7 min fed, 3 min of pauses, and both carried over to the right side
        XCTAssertEqual(b.timers[0].total(t(19, 10, 10)), 420, accuracy: 0.5)
        XCTAssertEqual(b.timers[0].paused(t(19, 10, 10)), 180, accuracy: 0.5)
        // a quick tap back while paused within 30 s just changes the side, running
        b = JournalFile.tappingSide(b, LogType.nurse, "r", now: t(19, 10, 10) + 5_000)
        b = JournalFile.tappingSide(b, LogType.nurse, "l", now: t(19, 10, 10) + 15_000)
        XCTAssertEqual(b.timers[0].side, "l"); XCTAssertNil(b.timers[0].pausedAt); XCTAssertEqual(b.logs.count, 1)
    }
}
