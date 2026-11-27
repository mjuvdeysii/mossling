import XCTest
import SwiftUI
import UIKit
import QuartzCore
@testable import Mossling

final class LogicTests: XCTestCase {
    @MainActor private static var hostedWindow: UIWindow?

    @MainActor
    private func renderHostedSnapshot<V: View>(
        _ view: V,
        width: CGFloat = 393,
        height: CGFloat = 852,
        dark: Bool = false
    ) -> UIImage {
        let size = CGSize(width: width, height: height)
        let host = UIHostingController(
            rootView: view
                .frame(width: width, height: height)
                .environment(\.colorScheme, dark ? .dark : .light)
        )
        let window: UIWindow
        if let existing = Self.hostedWindow {
            existing.isHidden = false
            existing.frame = CGRect(origin: .zero, size: size)
            window = existing
        } else {
            let created: UIWindow
            if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
                created = UIWindow(windowScene: scene)
                created.frame = CGRect(origin: .zero, size: size)
            } else {
                created = UIWindow(frame: CGRect(origin: .zero, size: size))
            }
            Self.hostedWindow = created
            window = created
        }
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        CATransaction.flush()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let img = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        window.rootViewController = UIViewController()
        window.layoutIfNeeded()
        CATransaction.flush()
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        window.rootViewController = nil
        window.isHidden = true
        CATransaction.flush()
        return img
    }

    /// Chinese is the reference language of these tests; a test that wants English says so (the CI simulator is English).
    override func setUp() { super.setUp(); L10n.overrideEnglish = false }
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
        app.consent = Consent.version   // a guardian who agreed: ticks are kept only with consent
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
        // App Store: a privacy manifest in the app; legal documents shown in the app; internal changelogs excluded; export compliance declared
        XCTAssertNotNil(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"), "PrivacyInfo.xcprivacy is not in the app bundle")
        for d in ["PRIVACY", "TERMS", "DISCLAIMER"] { XCTAssertNotNil(Bundle.main.url(forResource: d, withExtension: "md"), d) }
        for internalDoc in ["CHANGELOG", "CHANGELOG_EN", "TESTFLIGHT_NOTES", "TESTFLIGHT_NOTES_EN"] {
            XCTAssertNil(Bundle.main.url(forResource: internalDoc, withExtension: "md"), "\(internalDoc).md must not ship inside app bundle")
        }
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

    func testTheShelfCountsOneWeekOneWay() {
        let monday = Date(timeIntervalSince1970: 1_760_918_400)   // a Monday 00:00 UTC
        let times = [monday.addingTimeInterval(-60), monday, monday.addingTimeInterval(3_600 * 30)]
        XCTAssertEqual(Shelf.week(times, since: monday), 2, "last Sunday does not count; Monday at midnight does")
        XCTAssertEqual(Shelf.week([], since: monday), 0)
        // 先玩这件: fewest this week, then fewest in all, then shelf order
        let week = ["A": 1, "B": 0, "C": 0], total = ["A": 1, "B": 5, "C": 2]
        XCTAssertEqual(Shelf.first(["A", "B", "C"], week: { week[$0]! }, total: { total[$0]! }), "C")
        XCTAssertEqual(Shelf.first(["A", "B"], week: { _ in 0 }, total: { _ in 0 }), "A")
        XCTAssertNil(Shelf.first([], week: { _ in 0 }, total: { _ in 0 }))
    }

    func testHowLongAgoIsSaidOneWay() {
        let now = Date(timeIntervalSince1970: 1_760_990_000)
        XCTAssertEqual(ago(now.addingTimeInterval(-30), now: now), "刚刚")
        XCTAssertEqual(ago(now.addingTimeInterval(-25 * 60), now: now), "25 分前")
        XCTAssertEqual(ago(now.addingTimeInterval(-(3 * 60 + 20) * 60), now: now), "3 小时前")
        XCTAssertEqual(ago(now.addingTimeInterval(-23 * 3600), now: now), "23 小时前", "earlier today is never 天前")
        XCTAssertEqual(ago(now.addingTimeInterval(-50 * 3600), now: now), "2 天前")
        // the last-time sentence names what was done, the same on the stage, the timer and the night card
        let logs = [LogEntry(type: LogType.diaper, start: (now.timeIntervalSince1970 - 600) * 1000, detail: "wet")]
        XCTAssertEqual(LastLine.phrase(LogType.diaper, in: logs, now: now), "上次换尿布 10 分前")
        XCTAssertNil(LastLine.phrase(LogType.sleep, in: logs, now: now))
    }

    func testOneFeedIsDefinedOnce() {
        // 16:10–16:28 left, 16:28–16:40 right: one feed, begun at 16:10, one row on the time line
        let l = LogEntry(type: LogType.nurse, start: t(19, 16, 10), end: t(19, 16, 28), side: "l")
        let r = LogEntry(type: LogType.nurse, start: t(19, 16, 28), end: t(19, 16, 40), side: "r")
        let bottle = LogEntry(type: LogType.bottle, start: t(19, 19, 40), amount: 120)
        let nursed = LogEntry(type: LogType.nurse, start: t(19, 19, 41), end: t(19, 19, 50), side: "l")
        let nappy = LogEntry(type: LogType.diaper, start: t(19, 18, 5), detail: "wet")
        let logs = [r, nappy, l, bottle, nursed]
        let feeds = logs.feeds()
        XCTAssertEqual(feeds.count, 3, "a breast feed a minute after a bottle is a feed of its own")
        XCTAssertEqual(feeds[0].start, t(19, 16, 10))
        XCTAssertEqual(feeds[0].sides.map(\.side), ["l", "r"])
        XCTAssertEqual(feeds[0].sides[0].seconds, 18 * 60, accuracy: 0.5)
        XCTAssertEqual(feeds[0].sides[1].seconds, 12 * 60, accuracy: 0.5)
        XCTAssertEqual(logs.feedCount(), 3)
        XCTAssertEqual(logs.rows().count, 4, "five entries, four rows: the two sides are one row")
        XCTAssertEqual(logs.rows().filter { $0.count == 2 }.first?.map(\.id), [l.id, r.id])
        // the last breast feed began with its first side, and says its sides in order
        let early = [l, r]
        XCTAssertEqual(LastFact.of(LogType.nurse, in: early)?.at, l.startDate)
        XCTAssertEqual(LastFact.of(LogType.nurse, in: early)?.note, "亲喂 · 左侧 → 右侧")
        XCTAssertEqual(early.feedSides(before: t(19, 16, 41))["r"] ?? 0, 12 * 60, accuracy: 0.5)
        XCTAssertEqual(ago(Date(timeIntervalSince1970: t(19, 16, 10) / 1000), now: Date(timeIntervalSince1970: t(19, 18, 40) / 1000), precise: true), "2 小时 30 分前")
    }

    func testTheWeekTurnsByItselfAndSpreadsItsAreas() throws {
        let c = try Content.load()
        // three plays from three areas: 6 months is not two of a kind; at 0 months 趴卧 (N04) is among them
        let six = Shelf.suggest(c, 6, last: [])
        XCTAssertEqual(six, ["A11", "A09", "A15"])
        XCTAssertEqual(Set(six.compactMap { c.play($0) }.map { Palette.areaKey(of: $0) }).count, 3)
        XCTAssertTrue(Shelf.suggest(c, 0, last: []).contains("N04"))
        // not yet played comes before played
        XCTAssertFalse(Shelf.suggest(c, 6, last: [], played: { $0 == "A11" ? 2 : 0 }).first == "A11")
        // a new week: none of last week's, the stored form unchanged
        let mon = Day(y: 2026, m: 10, d: 19), next = Day(y: 2026, m: 10, d: 27)
        let stored = Shelf.format(mon, six)
        XCTAssertNil(Shelf.roll(c, 6, stored: stored, today: Day(y: 2026, m: 10, d: 22)), "the same week stands")
        let rolled = try XCTUnwrap(Shelf.roll(c, 6, stored: stored, today: next))
        let st = try XCTUnwrap(Shelf.parse(rolled))
        XCTAssertEqual(st.week, next.monday)
        XCTAssertTrue(Set(st.codes).isDisjoint(with: six))
        XCTAssertTrue(rolled.hasPrefix("\(next.monday.epochDay)|"))
        // the child turns 13 months mid-week: A11 (6–12 months) is replaced, the rest stays
        let outgrown = try XCTUnwrap(Shelf.roll(c, 13, stored: Shelf.format(mon, ["A11", "A15"]), today: Day(y: 2026, m: 10, d: 21)))
        let codes = try XCTUnwrap(Shelf.parse(outgrown)).codes
        XCTAssertFalse(codes.contains("A11")); XCTAssertTrue(codes.contains("A15")); XCTAssertEqual(codes.count, 3)
    }

    func testTodaysPickLastsTheDay() {
        let d = Day(y: 2026, m: 10, d: 21)
        let s = Shelf.formatPick("A09", today: d)
        XCTAssertEqual(Shelf.pick(s, today: d), "A09")
        XCTAssertNil(Shelf.pick(s, today: d.plus(days: 1)))
        XCTAssertNil(Shelf.pick("6:1", today: d), "the old form is ignored")
    }

    func testTodaysPlayStaysTodaysOncePlayed() {
        let d = UserDefaults(suiteName: "today-\(UUID().uuidString)")!
        let m = AppModel(defaults: d)
        m.consent = Consent.version   // a guardian who agreed: ticks are kept only with consent
        m.today = Day(y: 2026, m: 10, d: 21)
        m.birth = Day(y: 2026, m: 4, d: 2)
        m.setShelf(["A11", "A09", "A15"])
        let at = { (day: Day, h: Double) in LogEntry(type: LogType.play, start: (day.date.timeIntervalSince1970 + h * 3600) * 1000, detail: "A11 双手物品传递机会") }
        // A11 played on Monday: today's is the least played this week before today — A09
        let monday = JournalStore(preview: { var b = JournalFile.Body(); b.logs = [at(Day(y: 2026, m: 10, d: 19), 10)]; return b }())
        XCTAssertEqual(m.todayPlay(6, monday)?.code, "A09")
        // A09 played this morning: it is still today's (it does not jump to the next one)
        var b = JournalFile.Body()
        b.logs = [LogEntry(type: LogType.play, start: (m.today.date.timeIntervalSince1970 + 9 * 3600) * 1000, detail: "A09 安全镜面表情互动"), at(Day(y: 2026, m: 10, d: 19), 10)]
        XCTAssertEqual(m.todayPlay(6, JournalStore(preview: b))?.code, "A09")
        // 换一个 moves on, and holds for the day
        m.anotherToday(6, JournalStore(preview: b))
        XCTAssertEqual(m.todayPlay(6, JournalStore(preview: b))?.code, "A15")
        // a play chosen from another month is today's, even with a full week; the week is not cut
        m.setShelf(["A11", "A09", "A15", "A08"])
        m.playToday(m.content.play("N04")!, 6)
        XCTAssertEqual(m.todayPlay(6, JournalStore(preview: b))?.code, "N04")
        XCTAssertEqual(m.weekShelf(6).plays.count, 4)
    }

    func testAPlayIsCountedFromTheRecordsOnly() {
        let d = UserDefaults(suiteName: "played-\(UUID().uuidString)")!
        let m = AppModel(defaults: d)
        m.consent = Consent.version   // a guardian who agreed: ticks are kept only with consent
        m.today = Day(y: 2026, m: 10, d: 21)
        m.birth = Day(y: 2026, m: 4, d: 2)
        let in6 = (Day(y: 2026, m: 10, d: 10).date.timeIntervalSince1970 + 3600) * 1000
        let j = JournalStore(preview: { var b = JournalFile.Body(); b.logs = [LogEntry(type: LogType.play, start: in6, detail: "A09 安全镜面表情互动")]; return b }())
        XCTAssertEqual(m.played(in: 6, j), ["A09"])
        XCTAssertEqual(m.played(in: 5, j), [], "a play counts in the child's month of its date")
        // an entry taken back leaves nothing behind: no mark keeps it counted
        let none = JournalStore(preview: JournalFile.Body())
        XCTAssertEqual(m.played(in: 6, none), [])
        XCTAssertEqual(m.record(m.content.play("A09")!, none).count, 0)
        // a mark from before plays were dated still counts, for a play with no entries
        m.toggle(6, TickKind.did, "A11", "双手物品传递机会")
        XCTAssertEqual(m.played(in: 6, j), ["A09", "A11"])
    }

    func testDidPlayWritesOnlyTheRecordsAndUndoLeavesNothing() throws {
        JournalFile.beginTest(); defer { JournalFile.endTest() }
        let m = AppModel(defaults: UserDefaults(suiteName: "didplay-\(UUID().uuidString)")!)
        m.consent = Consent.version   // a guardian who agreed: ticks are kept only with consent
        m.birth = Day(y: 2026, m: 4, d: 2)
        let j = JournalStore(preview: JournalFile.Body())
        let p = try XCTUnwrap(m.content.play("A09"))
        XCTAssertTrue(m.didPlay(p, month: 6, j))
        XCTAssertEqual(j.plays("A09").count, 1)
        XCTAssertFalse(m.ticks.values.contains { $0.kind == TickKind.did }, "a play is an entry in the records, no mark beside it")
        let t = try XCTUnwrap(j.toast)
        j.undo(t)
        XCTAssertEqual(m.record(p, j).count, 0)
        XCTAssertTrue((0...36).allSatisfy { m.played(in: $0, j).isEmpty })
    }

    func testTwoSidesAreChangedTogetherOrNotAtAll() throws {
        JournalFile.beginTest(); defer { JournalFile.endTest() }
        let l = LogEntry(type: LogType.nurse, start: t(19, 16, 10), end: t(19, 16, 28), side: "l")
        let r = LogEntry(type: LogType.nurse, start: t(19, 16, 28), end: t(19, 16, 40), side: "r")
        var b = JournalFile.Body(); b.logs = [l, r]
        JournalFile.write(b)
        let j = JournalStore(preview: b)
        var l2 = l, r2 = r
        l2.end = t(19, 16, 25); r2.start = t(19, 16, 26)
        JournalFile.failWrites = true
        XCTAssertFalse(j.update([l2, r2]))
        XCTAssertEqual(JournalFile.read().logs.first { $0.id == l.id }?.end, l.end, "nothing half-written")
        JournalFile.failWrites = false
        XCTAssertTrue(j.update([l2, r2]))
        XCTAssertEqual(JournalFile.read().logs.first { $0.id == r.id }?.start, t(19, 16, 26))
        XCTAssertNotNil(j.toast?.restore, "one 撤销 for the change")
    }

    func testANewBirthDateChoosesTheWeekAnew() throws {
        let c = try Content.load()
        let d = Day(y: 2026, m: 10, d: 21)
        let old = Shelf.format(d, ["A11", "A09", "A15"])           // a 6-month week
        let next = try XCTUnwrap(Shelf.roll(c, 2, stored: old, today: d, fresh: true))
        let plays = try XCTUnwrap(Shelf.parse(next)).codes.compactMap { c.play($0) }
        XCTAssertFalse(plays.isEmpty)
        XCTAssertTrue(plays.allSatisfy { $0.from <= 2 && 2 <= $0.to }, "nothing the child has not reached yet")
        // a week that suits the month (one brought by a record file) stays as it is
        XCTAssertNil(Shelf.roll(c, 6, stored: old, today: d, fresh: true))
    }

    func testANewBirthDateKeepsWhatSuitsAndTurnsAnOldWeek() throws {
        let c = try Content.load()
        let d = Day(y: 2026, m: 10, d: 21)
        // A15 (6–18) suits 13 months; A11 (6–12) and A09 (4–12) do not: A15 stays, two others join it
        let mixed = try XCTUnwrap(Shelf.roll(c, 13, stored: Shelf.format(d, ["A11", "A09", "A15"]), today: d, fresh: true))
        let codes = try XCTUnwrap(Shelf.parse(mixed)).codes
        XCTAssertTrue(codes.contains("A15")); XCTAssertEqual(codes.count, 3)
        XCTAssertTrue(codes.compactMap { c.play($0) }.allSatisfy { $0.from <= 13 && 13 <= $0.to })
        // a week that suits but is last week's turns into this week's
        let last = Shelf.format(d.plus(days: -7), ["A11", "A09", "A15"])
        let turned = try XCTUnwrap(Shelf.roll(c, 6, stored: last, today: d, fresh: true))
        XCTAssertEqual(Shelf.parse(turned)?.week, d.monday)
    }

    func testDurationsKeepTheirUnits() {
        let s = labeled("距上一顿", "3 小时 30 分")
        // the only ordinary space is between the two pairs
        XCTAssertEqual(s.filter { $0 == " " }.count, 1)
        XCTAssertTrue(s.contains("\u{2060}"))
        XCTAssertEqual(s.replacingOccurrences(of: "\u{2060}", with: "").replacingOccurrences(of: "\u{00A0}", with: " "), "距上一顿 3 小时 30 分")
    }

    func testAFailedUndoSaysSo() throws {
        JournalFile.beginTest(); defer { JournalFile.endTest() }
        let j = JournalStore(preview: JournalFile.Body())
        XCTAssertTrue(j.record(LogEntry(type: LogType.diaper, start: 1_760_000_000_000, detail: "wet")))
        let t = try XCTUnwrap(j.toast)
        JournalFile.failWrites = true
        j.undo(t)
        XCTAssertEqual(j.toast?.failed, true)
        XCTAssertFalse(j.toast?.text.contains("已撤销") ?? true)
        XCTAssertEqual(j.logs.count, 1, "the entry is still there, as the file says")
        // a measurement that cannot be saved says false (the sheet stays open)
        XCTAssertFalse(j.saveMeasure(Measure(at: 1_760_000_000_000, weightG: 7400, lengthMm: nil, headMm: nil)))
    }

    func testATickIsKeptOnlyWithConsentAndCanAlwaysBeTakenOff() {
        let m = AppModel(defaults: UserDefaults(suiteName: "tick-\(UUID().uuidString)")!)
        m.consent = "declined"
        m.toggle(2, TickKind.vaccine, "0", "百白破疫苗第1剂")
        XCTAssertTrue(m.ticks.isEmpty, "declined: a vaccine given is the child's health information and is not kept")
        XCTAssertTrue(m.askConsent, "the consent card is offered again instead")
        m.consent = Consent.version; m.askConsent = false
        m.toggle(2, TickKind.vaccine, "0", "百白破疫苗第1剂")
        XCTAssertEqual(m.ticks.count, 1)
        m.consent = "declined"
        m.toggle(2, TickKind.vaccine, "0", "百白破疫苗第1剂")
        XCTAssertTrue(m.ticks.isEmpty, "taking a tick off needs no consent")
    }

    func testClearingRemovesTheChildAndTheExports() throws {
        JournalFile.beginTest(); defer { JournalFile.endTest() }
        let m = AppModel(defaults: UserDefaults(suiteName: "clear-\(UUID().uuidString)")!)
        m.consent = Consent.version
        m.birth = Day(y: 2026, m: 4, d: 2); m.nickname = "小满"
        m.toggle(2, TickKind.vaccine, "0", "百白破疫苗第1剂")
        let dir = DataView.exportFolder
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: dir.appendingPathComponent("test-export.md"))
        m.clearAll()
        XCTAssertNil(m.birth); XCTAssertEqual(m.nickname, ""); XCTAssertTrue(m.ticks.isEmpty); XCTAssertEqual(m.consent, "")
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path), "exports in the Files app hold the child's records: cleared too")
    }

    func testCorruptJournalFileIsNeverOverwritten() throws {
        JournalFile.beginTest(); defer { JournalFile.endTest() }
        let raw = Data("{corrupt".utf8)
        try raw.write(to: JournalFile.url)
        XCTAssertThrowsError(try JournalFile.load())
        let j = JournalStore(preview: JournalFile.Body())
        XCTAssertFalse(j.record(LogEntry(type: LogType.diaper, start: JournalFile.now(), detail: "wet")))
        XCTAssertEqual(j.toast?.failed, true)
        XCTAssertEqual(try Data(contentsOf: JournalFile.url), raw, "a corrupt journal must never be overwritten with an empty body")
    }

    func testTimerMutationsReportWriteFailures() {
        JournalFile.beginTest(); defer { JournalFile.endTest() }
        let j = JournalStore(preview: JournalFile.Body())
        j.start(LogType.nurse, side: "l", at: Date().addingTimeInterval(-300))
        XCTAssertEqual(j.timers.count, 1)
        JournalFile.failWrites = true
        j.togglePause(LogType.nurse)
        XCTAssertEqual(j.toast?.failed, true)
        XCTAssertNil(j.timers.first?.pausedAt, "failed pause must not stick in memory")
        j.switchSide(LogType.nurse)
        XCTAssertEqual(j.toast?.failed, true)
        XCTAssertEqual(j.timers.first?.side, "l")
    }

    func testGrowthGuardsNonPositiveValuesAndNaN() throws {
        let g = try Growth.load()
        XCTAssertTrue(g.z(.weight, girl: true, months: 6, value: 0).isNaN)
        XCTAssertTrue(g.z(.weight, girl: true, months: 6, value: -3).isNaN)
        XCTAssertTrue(g.percentile(.weight, girl: true, months: 6, value: 0).isNaN)
        XCTAssertEqual(pctText(.nan), "")
        XCTAssertEqual(pctText(.infinity), "")
    }

    func testTimerIntentRequiresConsent() {
        XCTAssertFalse(TimerIntent.canRecord(snapshot: nil))
        let declined = Snapshot(birthEpochDay: nil, nickname: "", companion: "Moss", journal: true, playCode: nil, playName: nil, consented: false)
        XCTAssertFalse(TimerIntent.canRecord(snapshot: declined))
        let journalOff = Snapshot(birthEpochDay: nil, nickname: "", companion: "Moss", journal: false, playCode: nil, playName: nil, consented: true, consentVersion: SharedConsent.version)
        XCTAssertFalse(TimerIntent.canRecord(snapshot: journalOff), "widgets must not record when journal is turned off")
        let agreed = Snapshot(birthEpochDay: nil, nickname: "", companion: "Moss", journal: true, playCode: nil, playName: nil, consented: true, consentVersion: SharedConsent.version)
        XCTAssertTrue(TimerIntent.canRecord(snapshot: agreed))
        let missingVersion = Snapshot(birthEpochDay: nil, nickname: "", companion: "Moss", journal: true, playCode: nil, playName: nil, consented: true)
        XCTAssertFalse(TimerIntent.canRecord(snapshot: missingVersion), "widgets must fail closed without explicit current consentVersion")
        let legacyOn = Snapshot(birthEpochDay: nil, nickname: "", companion: "Moss", journal: true, playCode: nil, playName: nil)
        XCTAssertFalse(TimerIntent.canRecord(snapshot: legacyOn), "legacy snapshot with nil consented must fail closed")
        let legacyOff = Snapshot(birthEpochDay: nil, nickname: "", companion: "Moss", journal: false, playCode: nil, playName: nil)
        XCTAssertFalse(TimerIntent.canRecord(snapshot: legacyOff))
    }

    func testSuggestedNurseSideAlternatesAndStartSmart() {
        JournalFile.beginTest(); defer { JournalFile.endTest() }
        XCTAssertEqual(JournalFile.suggestedNurseSide(in: []), "l")
        let afterLeft = [LogEntry(type: LogType.nurse, start: t(19, 8, 0), end: t(19, 8, 12), side: "l")]
        XCTAssertEqual(JournalFile.suggestedNurseSide(in: afterLeft), "r")
        let afterRight = afterLeft + [LogEntry(type: LogType.nurse, start: t(19, 11, 0), end: t(19, 11, 10), side: "r")]
        XCTAssertEqual(JournalFile.suggestedNurseSide(in: afterRight), "l")

        var b = JournalFile.Body()
        b.logs = afterLeft
        XCTAssertTrue(JournalFile.write(b))
        let startedNurse = JournalFile.startSmart(LogType.nurse, at: t(19, 11, 0))
        XCTAssertEqual(startedNurse.timers.first(where: { $0.type == LogType.nurse })?.side, "r")
        let startedSleep = JournalFile.startSmart(LogType.sleep, at: t(19, 12, 0))
        XCTAssertNil(startedSleep.timers.first(where: { $0.type == LogType.sleep })?.side)
    }

    func testJournalStoreIndexedLookupsMatchSemantics() {
        let d18 = Day(y: 2026, m: 10, d: 18), d19 = Day(y: 2026, m: 10, d: 19), d20 = Day(y: 2026, m: 10, d: 20)
        let f1 = LogEntry(type: LogType.nurse, start: t(18, 22, 0), end: t(18, 22, 10), side: "l")
        let f2a = LogEntry(type: LogType.nurse, start: t(19, 1, 0), end: t(19, 1, 8), side: "r")
        let f2b = LogEntry(type: LogType.nurse, start: t(19, 1, 8), end: t(19, 1, 15), side: "l")
        let overnight = LogEntry(type: LogType.sleep, start: t(18, 23, 0), end: t(19, 6, 0))
        let endsAtMidnight = LogEntry(type: LogType.sleep, start: t(19, 22, 0), end: t(20, 0, 0))
        let playEntry = LogEntry(type: LogType.play, start: t(19, 10, 0), detail: "A11 听摇铃")

        var body = JournalFile.Body()
        body.logs = [f1, f2a, f2b, overnight, endsAtMidnight, playEntry]
        let j = JournalStore(preview: body)

        // O(1) feed interval lookup: second feed starts 3h after first; continuation side has no interval
        XCTAssertEqual(j.feedIntervalByID[f2a.id] ?? -1, 3 * 3600, accuracy: 1)
        XCTAssertNil(j.feedIntervalByID[f2b.id])
        XCTAssertNil(j.feedIntervalByID[f1.id])
        // Last nursing feed begins at its first side (f2a), not its second side (f2b)
        XCTAssertEqual(j.last(LogType.nurse), f2a.startDate)
        XCTAssertEqual(j.last(LogType.sleep), endsAtMidnight.endDate)
        // Day indexing includes f1 on d18, overnight carryover on d19, excludes sleep ending at exact 00:00 of d20
        XCTAssertTrue(j.logs(on: d18).contains { $0.id == f1.id })
        XCTAssertTrue(j.logs(on: d19).contains { $0.id == overnight.id })
        XCTAssertFalse(j.logs(on: d20).contains { $0.id == endsAtMidnight.id })
        // O(1) play lookup and count
        XCTAssertEqual(j.plays("A11").count, 1)
        XCTAssertEqual(j.playLogCount, 1)
        XCTAssertEqual(j.feedEntries(containing: f2b.id).count, 2)
    }

    func testClearAllResetsArtStyleAndPlayingClampsNegativeStep() {
        JournalFile.beginTest(); defer { JournalFile.endTest() }
        let m = AppModel(defaults: UserDefaults(suiteName: "style-\(UUID().uuidString)")!)
        m.session = "A11|6|-3"
        XCTAssertEqual(m.playing?.step, 0)
        m.artStyle = .flat
        XCTAssertEqual(ArtStyle.current, .flat)
        m.tactileSounds = false
        m.clearAll()
        XCTAssertEqual(m.artStyle, .vinyl)
        XCTAssertEqual(ArtStyle.current, .vinyl)
        XCTAssertTrue(m.tactileSounds)
        XCTAssertEqual(JournalFile.snapshot()?.consented, false)
    }

    func testSoundscapeDSPProducesBoundedFiniteSamples() {
        for kindIndex in 0..<SoundscapeKind.allCases.count {
            let dsp = SoundscapeDSPState()
            dsp.kindRaw = kindIndex
            dsp.targetGain = 1.0
            dsp.currentGain = 0.8
            dsp.userVolume = 0.8
            dsp.noteCountdown = 10 // trigger wood lullaby note immediately
            var maxAbs: Float = 0
            for _ in 0..<2048 {
                let s = dsp.nextSample(sampleRate: 44_100)
                XCTAssertTrue(s.isFinite, "Soundscape kind \(kindIndex) produced non-finite sample")
                XCTAssertLessThanOrEqual(abs(s), 1.0, "Soundscape kind \(kindIndex) exceeded [-1, 1]")
                maxAbs = max(maxAbs, abs(s))
            }
            XCTAssertGreaterThan(maxAbs, 0.001, "Soundscape kind \(kindIndex) was silent")
        }
    }

    func testSoundscapeFadeMultiplierCurve() {
        XCTAssertEqual(SoundscapeEngine.fadeMultiplier(remaining: 25, fadeDuration: 20), 1.0, accuracy: 0.0001)
        XCTAssertEqual(SoundscapeEngine.fadeMultiplier(remaining: 20, fadeDuration: 20), 1.0, accuracy: 0.0001)
        XCTAssertEqual(SoundscapeEngine.fadeMultiplier(remaining: 10, fadeDuration: 20), 0.5, accuracy: 0.001)
        XCTAssertEqual(SoundscapeEngine.fadeMultiplier(remaining: 0, fadeDuration: 20), 0.0, accuracy: 0.0001)
        XCTAssertEqual(SoundscapeEngine.fadeMultiplier(remaining: -3, fadeDuration: 20), 0.0, accuracy: 0.0001)
        XCTAssertLessThan(SoundscapeEngine.fadeMultiplier(remaining: 4, fadeDuration: 20), SoundscapeEngine.fadeMultiplier(remaining: 15, fadeDuration: 20))
    }

    func testRhythmDialModelBucketsOvernightSleepAndGeometry() {
        let today = Day(y: 2026, m: 10, d: 19)
        let overnight = LogEntry(type: LogType.sleep, start: t(18, 22, 0), end: t(19, 6, 30))
        let nap = LogEntry(type: LogType.sleep, start: t(19, 13, 0), end: t(19, 14, 30))
        // Two-sided nursing session within Feed.join counts as 1 feed bead, not 2
        let nurseL = LogEntry(type: LogType.nurse, start: t(19, 8, 10), end: t(19, 8, 22), side: "l")
        let nurseR = LogEntry(type: LogType.nurse, start: t(19, 8, 22), end: t(19, 8, 34), side: "r")
        let play = LogEntry(type: LogType.play, start: t(19, 10, 15), detail: "A11 听摇铃")

        let model = RhythmDialModel.build(logs: [overnight, nap, nurseL, nurseR, play], today: today, days: 7)
        XCTAssertEqual(model.rings.count, 7)
        XCTAssertEqual(model.rings.first?.day, today.plus(days: -6))
        XCTAssertEqual(model.rings.last?.day, today)

        let prevRing = model.rings[5] // Oct 18
        let todayRing = model.rings[6] // Oct 19
        XCTAssertEqual(prevRing.sleepSpans.count, 1)
        XCTAssertEqual(prevRing.sleepSpans[0].startHour, 22.0, accuracy: 0.05)
        XCTAssertEqual(prevRing.sleepSpans[0].endHour, 24.0, accuracy: 0.05)
        XCTAssertEqual(todayRing.sleepSpans.count, 2)
        XCTAssertEqual(todayRing.feeds.count, 1)
        XCTAssertEqual(todayRing.plays.count, 1)

        XCTAssertEqual(model.inspect(hour: 2).sleepDays, 1)
        XCTAssertEqual(model.inspect(hour: 8).feedCount, 1)
        XCTAssertEqual(model.inspect(hour: 10).playCount, 1)
        XCTAssertEqual(model.inspect(hour: 16).sleepDays, 0)

        // Verify angle <-> vector round-trip at all 4 cardinal hours (12 = top, 18 = right, 0 = bottom, 6 = left)
        for cardinal in [0, 6, 12, 18] {
            let a = RhythmDialModel.angle(forHour: Double(cardinal) + 0.5)
            let h = RhythmDialModel.hour(forVector: CGFloat(cos(a)), dy: CGFloat(sin(a)))
            XCTAssertEqual(h, cardinal, "Cardinal hour \(cardinal) failed geometry round-trip")
        }
    }

    func testFirstPhotoStoreSaveDownscalePruneAndClear() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("first-photos-test-\(UUID().uuidString)", isDirectory: true)
        defer { FirstPhotoStore.clearAll(in: dir) }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let big = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1600), format: format).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 2400, height: 1600))
        }
        let id1 = UUID(), id2 = UUID()
        XCTAssertTrue(FirstPhotoStore.save(big, for: id1, maxDimension: 1200, in: dir))
        XCTAssertTrue(FirstPhotoStore.save(big, for: id2, maxDimension: 1200, in: dir))
        XCTAssertTrue(FirstPhotoStore.exists(for: id1, in: dir))
        XCTAssertTrue(FirstPhotoStore.exists(for: id2, in: dir))

        let loaded = FirstPhotoStore.load(for: id1, in: dir)
        XCTAssertNotNil(loaded)
        if let loaded {
            XCTAssertLessThanOrEqual(max(loaded.size.width * loaded.scale, loaded.size.height * loaded.scale), 1201)
        }

        FirstPhotoStore.prune(keeping: [id1], in: dir)
        XCTAssertTrue(FirstPhotoStore.exists(for: id1, in: dir))
        XCTAssertFalse(FirstPhotoStore.exists(for: id2, in: dir))

        FirstPhotoStore.clearAll(in: dir)
        XCTAssertFalse(FirstPhotoStore.exists(for: id1, in: dir))
    }

    func testToyboxMarimbaAndBeadDSPProduceBoundedFiniteSamples() {
        for note in ToyboxNote.scale {
            let samples = ToyboxAudioEngine.synthesizeMarimbaSamples(frequency: note.frequency, sampleRate: 44_100, duration: 0.25)
            XCTAssertGreaterThan(samples.count, 1000)
            var peak: Float = 0
            for s in samples {
                XCTAssertTrue(s.isFinite, "Marimba note \(note.pitchName) produced non-finite sample")
                XCTAssertLessThanOrEqual(abs(s), 1.0, "Marimba note \(note.pitchName) exceeded [-1, 1]")
                peak = max(peak, abs(s))
            }
            XCTAssertGreaterThan(peak, 0.05, "Marimba note \(note.pitchName) was silent")
        }
        let click = ToyboxAudioEngine.synthesizeBeadClickSamples(pitchScale: 1.08, sampleRate: 44_100)
        XCTAssertTrue(click.allSatisfy { $0.isFinite && abs($0) <= 1.0 })
        XCTAssertGreaterThan(click.map { abs($0) }.max() ?? 0, 0.01)
    }

    func testRainstickPhysicsGravityAndStrictBounds() {
        var sim = RainstickPhysics.initial()
        XCTAssertEqual(sim.beads.count, 26)
        XCTAssertEqual(sim.pegs.count, 11)
        let avgYBefore = sim.beads.map(\.y).reduce(0, +) / Double(sim.beads.count)
        for _ in 0..<45 {
            sim.step(dt: 1.0 / 60.0, gx: 0.15, gy: 1.0, touch: CGPoint(x: 0.5, y: 0.5))
        }
        let avgYAfter = sim.beads.map(\.y).reduce(0, +) / Double(sim.beads.count)
        XCTAssertGreaterThan(avgYAfter, avgYBefore, "Positive Y gravity should roll beads downward")
        for b in sim.beads {
            XCTAssertTrue(b.x.isFinite && b.y.isFinite && b.vx.isFinite && b.vy.isFinite)
            XCTAssertGreaterThanOrEqual(b.x, b.radius - 0.0001)
            XCTAssertLessThanOrEqual(b.x, 1.0 - b.radius + 0.0001)
            XCTAssertGreaterThanOrEqual(b.y, b.radius - 0.0001)
            XCTAssertLessThanOrEqual(b.y, 1.0 - b.radius + 0.0001)
        }
    }

    @MainActor
    func testCapsuleStorePersistenceAndUnlockLogic() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("capsules-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let birth = Day(y: 2026, m: 4, d: 2)
        let today = Day(y: 2026, m: 10, d: 19)
        let firstBday = TimeCapsule.birthdayEpochDay(from: birth, years: 1)
        XCTAssertEqual(Day(epochDay: firstBday), Day(y: 2027, m: 4, d: 2))

        let futureCap = TimeCapsule(title: "1岁信", body: "生日快乐", writtenAt: t(19, 21, 0), writtenAgeLabel: "6 个月 17 天", unlockEpochDay: firstBday, openedAt: nil, seal: .gold)
        let readyCap = TimeCapsule(title: "随时读", body: "今晚很安静", writtenAt: t(18, 22, 0), writtenAgeLabel: "6 个月 16 天", unlockEpochDay: today.epochDay, openedAt: nil, seal: .teal)

        XCTAssertTrue(futureCap.isLocked(on: today))
        XCTAssertGreaterThan(futureCap.daysUntilUnlock(on: today), 100)
        XCTAssertFalse(futureCap.isReadyToOpen(on: today))
        XCTAssertTrue(readyCap.isReadyToOpen(on: today))

        let store = CapsuleStore(fileURL: url)
        store.save(futureCap)
        store.save(readyCap)
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.readyCount(on: today), 1)

        // Reload from disk verifies atomic JSON round-trip
        let reloaded = CapsuleStore(fileURL: url)
        XCTAssertEqual(reloaded.items.count, 2)
        reloaded.open(id: readyCap.id, now: t(19, 22, 0))
        XCTAssertEqual(reloaded.readyCount(on: today), 0)
        XCTAssertNotNil(reloaded.items.first(where: { $0.id == readyCap.id })?.openedAt)

        reloaded.clearAll()
        XCTAssertTrue(reloaded.items.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    @MainActor
    func testSoundscapeDualLayerMixingAndToggle() {
        XCTAssertEqual(SoundscapeKind.allCases.count, 6)
        let pairs: [(Int, Int)] = [(0, 3), (1, 2), (2, 0), (3, 1), (4, 0), (5, 3), (0, 4), (3, 5)]
        for (primary, secondary) in pairs {
            let dsp = SoundscapeDSPState()
            dsp.kindRaw = primary
            dsp.layerKindRaw = secondary
            dsp.targetGain = 1.0
            dsp.currentGain = 0.85
            dsp.layerTargetMix = 0.48
            dsp.layerCurrentMix = 0.48
            dsp.userVolume = 0.85
            dsp.noteCountdown = 12
            var maxAbs: Float = 0
            for _ in 0..<2048 {
                let s = dsp.nextSample(sampleRate: 44_100)
                XCTAssertTrue(s.isFinite, "Dual layer (\(primary)+\(secondary)) produced non-finite sample")
                XCTAssertLessThanOrEqual(abs(s), 1.0, "Dual layer (\(primary)+\(secondary)) clipped beyond [-1, 1]")
                maxAbs = max(maxAbs, abs(s))
            }
            XCTAssertGreaterThan(maxAbs, 0.001, "Dual layer (\(primary)+\(secondary)) was silent")
        }

        let eng = SoundscapeEngine.shared
        defer { eng.stop() }
        eng.duration = .m30
        eng.start(.rain)
        XCTAssertEqual(eng.active, .rain)
        XCTAssertNil(eng.secondary)
        let initialRem = eng.remainingSeconds
        eng.toggleLayer(.rain) // primary cannot also be secondary
        XCTAssertNil(eng.secondary)
        eng.toggleLayer(.lullaby)
        XCTAssertEqual(eng.secondary, .lullaby)
        XCTAssertTrue(eng.activeSummary?.contains("+") == true)
        eng.toggleLayer(.lullaby) // toggles back off smoothly
        XCTAssertNil(eng.secondary)

        // Promoting secondary to primary preserves remaining countdown instead of resetting timer
        eng.toggleLayer(.breeze)
        XCTAssertEqual(eng.secondary, .breeze)
        eng.toggle(.rain)
        XCTAssertEqual(eng.active, .breeze)
        XCTAssertNil(eng.secondary)
        XCTAssertEqual(eng.remainingSeconds, initialRem)

        // DSP fades layerCurrentMix smoothly down to 0 and then clears layerKindRaw
        let fadeState = SoundscapeDSPState()
        fadeState.kindRaw = 0
        fadeState.layerKindRaw = 3
        fadeState.targetGain = 1.0
        fadeState.currentGain = 0.8
        fadeState.layerTargetMix = 0.0
        fadeState.layerCurrentMix = 0.01
        for _ in 0..<20_000 {
            _ = fadeState.nextSample(sampleRate: 44_100)
        }
        XCTAssertEqual(fadeState.layerKindRaw, -1)
        XCTAssertEqual(fadeState.layerCurrentMix, 0.0)

        eng.stop()
        XCTAssertNil(eng.active)
        XCTAssertNil(eng.secondary)
    }

    func testBedsideLampBreathingGuideCurve() {
        let s0 = BedsideLampView.breathingState(at: 0.0)
        XCTAssertTrue(s0.inhaling)
        XCTAssertEqual(s0.progress, 0.0, accuracy: 0.001)
        XCTAssertEqual(s0.secondsLeft, 4)

        let s2 = BedsideLampView.breathingState(at: 2.0)
        XCTAssertTrue(s2.inhaling)
        XCTAssertEqual(s2.progress, 0.5, accuracy: 0.01)
        XCTAssertEqual(s2.secondsLeft, 2)

        let s39 = BedsideLampView.breathingState(at: 3.9)
        XCTAssertTrue(s39.inhaling)
        XCTAssertGreaterThan(s39.progress, 0.95)
        XCTAssertEqual(s39.secondsLeft, 1)

        let s4 = BedsideLampView.breathingState(at: 4.0)
        XCTAssertFalse(s4.inhaling)
        XCTAssertEqual(s4.progress, 1.0, accuracy: 0.001)
        XCTAssertEqual(s4.secondsLeft, 6)

        let s7 = BedsideLampView.breathingState(at: 7.0)
        XCTAssertFalse(s7.inhaling)
        XCTAssertEqual(s7.progress, 0.5, accuracy: 0.01)
        XCTAssertEqual(s7.secondsLeft, 3)

        let sNeg = BedsideLampView.breathingState(at: -2.0) // wraps to 8.0s (exhaling)
        XCTAssertFalse(sNeg.inhaling)
        XCTAssertEqual(sNeg.secondsLeft, 2)
    }

    func testFireflyChimeAndPhysicsBounds() {
        let chime = ToyboxAudioEngine.synthesizeChimeSamples(frequency: 1046.50, sampleRate: 44_100, duration: 0.25)
        XCTAssertGreaterThan(chime.count, 1000)
        XCTAssertTrue(chime.allSatisfy { $0.isFinite && abs($0) <= 1.0 })
        XCTAssertGreaterThan(chime.map { abs($0) }.max() ?? 0, 0.02)

        var sim = FireflyPhysics.initial()
        XCTAssertEqual(sim.flies.count, 18)
        sim.swirl()
        for i in 0..<60 {
            let target: CGPoint? = i < 30 ? CGPoint(x: 0.35, y: 0.42) : nil
            sim.step(dt: 1.0 / 60.0, target: target)
        }
        XCTAssertGreaterThan(sim.time, 0.9)
        for f in sim.flies {
            XCTAssertTrue(f.x.isFinite && f.y.isFinite && f.vx.isFinite && f.vy.isFinite)
            XCTAssertGreaterThanOrEqual(f.x, 0.089)
            XCTAssertLessThanOrEqual(f.x, 0.911)
            XCTAssertGreaterThanOrEqual(f.y, 0.109)
            XCTAssertLessThanOrEqual(f.y, 0.891)
        }
    }

    @MainActor
    func testFoodAtlasCatalogAndPersistence() {
        XCTAssertEqual(FoodItem.catalog.count, 60)
        XCTAssertEqual(Set(FoodItem.catalog.map(\.id)).count, 60, "All 60 food catalog IDs must be unique")
        for cat in FoodCategory.allCases {
            XCTAssertGreaterThan(FoodItem.catalog.filter { $0.category == cat }.count, 0, "Category \(cat) must not be empty")
        }
        XCTAssertGreaterThanOrEqual(FoodItem.catalog.filter(\.isCommonAllergen).count, 8)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("foods-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = FoodAtlasStore(fileURL: url)
        let today = Day(y: 2026, m: 10, d: 19)
        store.save(FoodRecord(foodId: "avocado", firstTastedEpochDay: today.epochDay, reaction: .loved, note: "压泥", watchSkin: false, times: 1))
        store.save(FoodRecord(foodId: "eggyolk", firstTastedEpochDay: today.epochDay, reaction: .tasted, note: "1/4 蛋黄", watchSkin: true, times: 1))
        XCTAssertEqual(store.tastedCount, 2)
        XCTAssertEqual(store.lovedCount, 1)

        let reloaded = FoodAtlasStore(fileURL: url)
        XCTAssertEqual(reloaded.tastedCount, 2)
        XCTAssertEqual(reloaded.record(for: "eggyolk")?.watchSkin, true)

        reloaded.remove(foodId: "avocado")
        XCTAssertEqual(reloaded.tastedCount, 1)
        reloaded.clearAll()
        XCTAssertEqual(reloaded.tastedCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    @MainActor
    func testHandoverSnapshotBuildsCompleteSummary() {
        let d = UserDefaults(suiteName: "handover-\(UUID().uuidString)")!
        let m = AppModel(defaults: d)
        let today = Day(y: 2026, m: 10, d: 19)
        m.today = today
        m.birth = Day(y: 2026, m: 4, d: 2)
        m.nickname = "小满"

        var body = JournalFile.Body()
        let now = Day.cal.date(bySettingHour: 15, minute: 30, second: 0, of: today.date)!
        body.logs = [
            LogEntry(type: LogType.sleep, start: t(19, 12, 30), end: t(19, 14, 0)),
            LogEntry(type: LogType.bottle, start: t(19, 14, 15), amount: 130, detail: "breastmilk"),
            LogEntry(type: LogType.diaper, start: t(19, 14, 40), detail: "wet"),
        ]
        body.timers = [RunningTimer(type: LogType.sleep, start: ms(now) - 18 * 60_000)]
        let j = JournalStore(preview: body)

        let snap = HandoverSnapshot.build(app: m, journal: j, day: today, now: now, extraNote: "  刚拍完嗝  ")
        XCTAssertEqual(snap.babyName, "小满")
        XCTAssertNotNil(snap.activeTimerLine)
        XCTAssertNotEqual(snap.lastFeedHeadline, "—")
        XCTAssertNotEqual(snap.lastSleepHeadline, "—")
        XCTAssertNotEqual(snap.lastDiaperHeadline, "—")
        XCTAssertEqual(snap.extraNote, "刚拍完嗝")
        XCTAssertTrue(snap.plainText.contains(snap.lastFeedHeadline))
        XCTAssertTrue(snap.plainText.contains("刚拍完嗝"))
        XCTAssertTrue(snap.plainText.contains("130"))

        // Nursing continuation feed uses feed startDate consistently with LastFact
        var nurseBody = JournalFile.Body()
        nurseBody.logs = [
            LogEntry(type: LogType.nurse, start: t(19, 13, 0), end: t(19, 13, 10), side: "l"),
            LogEntry(type: LogType.nurse, start: t(19, 13, 10), end: t(19, 13, 20), side: "r")
        ]
        let nurseSnap = HandoverSnapshot.build(app: m, journal: JournalStore(preview: nurseBody), day: today, now: now)
        XCTAssertTrue(nurseSnap.lastFeedDetail.contains("13:00"))
    }

    func testToyboxThreeTimbresAndSixMelodies() {
        XCTAssertEqual(ToyboxTimbre.allCases.count, 3)
        XCTAssertEqual(ToyboxMelody.allCases.count, 6)

        for note in ToyboxNote.scale {
            let synthRuns: [[Float]] = [
                ToyboxAudioEngine.synthesizeMarimbaSamples(frequency: note.frequency, sampleRate: 44_100, duration: 0.25),
                ToyboxAudioEngine.synthesizeMusicBoxSamples(frequency: note.frequency, sampleRate: 44_100, duration: 0.25),
                ToyboxAudioEngine.synthesizeKalimbaSamples(frequency: note.frequency, sampleRate: 44_100, duration: 0.25),
            ]
            for samples in synthRuns {
                XCTAssertGreaterThan(samples.count, 1000)
                XCTAssertTrue(samples.allSatisfy { $0.isFinite && abs($0) <= 1.0 })
                XCTAssertGreaterThan(samples.map { abs($0) }.max() ?? 0, 0.03)
            }
        }

        for song in ToyboxMelody.allCases {
            XCTAssertFalse(song.title.isEmpty)
            XCTAssertFalse(song.subtitle.isEmpty)
            XCTAssertGreaterThanOrEqual(song.notes.count, 12)
            for (idx, dur) in song.notes {
                XCTAssertTrue((0..<ToyboxNote.scale.count).contains(idx), "Melody \(song.rawValue) has out-of-range note index \(idx)")
                XCTAssertGreaterThan(dur, 0.05)
            }
        }
    }

    func testRainstickLayoutsPegGlowAndTrails() {
        for layout in RainstickLayout.allCases {
            var sim = RainstickPhysics.initial(layout: layout)
            XCTAssertEqual(sim.layout, layout)
            XCTAssertEqual(sim.beads.count, 26)
            XCTAssertGreaterThanOrEqual(sim.pegs.count, 10)
            for _ in 0..<75 {
                sim.step(dt: 1.0 / 60.0, gx: 0.1, gy: 1.0, touch: CGPoint(x: 0.5, y: 0.3))
            }
            for b in sim.beads {
                XCTAssertTrue(b.x.isFinite && b.y.isFinite && b.vx.isFinite && b.vy.isFinite)
                XCTAssertGreaterThanOrEqual(b.x, b.radius - 0.0001)
                XCTAssertLessThanOrEqual(b.x, 1.0 - b.radius + 0.0001)
                XCTAssertGreaterThanOrEqual(b.y, b.radius - 0.0001)
                XCTAssertLessThanOrEqual(b.y, 1.0 - b.radius + 0.0001)
                XCTAssertLessThanOrEqual(b.trail.count, 5)
            }
        }

        // Direct peg hit triggers hitEnergy > 0, sets lastHitPegY, and subsequently decays cleanly
        var hitSim = RainstickPhysics.initial(layout: .cascade)
        let targetPeg = hitSim.pegs[0]
        hitSim.beads[0].x = targetPeg.x
        hitSim.beads[0].y = targetPeg.y - targetPeg.radius - hitSim.beads[0].radius + 0.002
        hitSim.beads[0].vx = 0
        hitSim.beads[0].vy = 0.85
        let hits = hitSim.step(dt: 1.0 / 60.0, gx: 0, gy: 1.0)
        XCTAssertGreaterThan(hits, 0)
        XCTAssertGreaterThan(hitSim.pegs[0].hitEnergy, 0)
        XCTAssertNotNil(hitSim.lastHitPegY)
        let peakEnergy = hitSim.pegs[0].hitEnergy
        hitSim.beads[0].x = 0.9
        hitSim.beads[0].y = 0.9
        hitSim.step(dt: 1.0 / 30.0, gx: 0, gy: 0)
        XCTAssertLessThan(hitSim.pegs[0].hitEnergy, peakEnergy)
    }

    func testFireflyFormationsTrailsAndRipples() {
        XCTAssertEqual(FireflyFormation.allCases.count, 4)
        for formation in FireflyFormation.allCases {
            var sim = FireflyPhysics.initial(formation: formation)
            XCTAssertEqual(sim.flies.count, 18)
            sim.spawnRipple(at: CGPoint(x: 0.4, y: 0.5), gold: false)
            XCTAssertEqual(sim.ripples.count, 1)
            for idx in 0..<sim.flies.count {
                if let goal = FireflyPhysics.formationTarget(index: idx, count: sim.flies.count, formation: formation, time: 0.5) {
                    XCTAssertGreaterThanOrEqual(goal.0, 0.13)
                    XCTAssertLessThanOrEqual(goal.0, 0.87)
                    XCTAssertGreaterThanOrEqual(goal.1, 0.13)
                    XCTAssertLessThanOrEqual(goal.1, 0.87)
                }
            }
            for _ in 0..<25 {
                sim.step(dt: 1.0 / 60.0, target: nil)
            }
            XCTAssertTrue(sim.flies.allSatisfy { $0.trail.count <= 6 && $0.x.isFinite && $0.y.isFinite })
            // Advance 2 seconds so the initial ripple expires naturally
            for _ in 0..<60 {
                sim.step(dt: 1.0 / 30.0, target: nil)
            }
            XCTAssertTrue(sim.ripples.isEmpty)
        }
    }

    func testContrastCardExpandedCatalog() {
        XCTAssertEqual(ContrastCardKind.allCases.count, 12)
        defer { L10n.overrideEnglish = nil }
        for isEn in [false, true] {
            L10n.overrideEnglish = isEn
            for card in ContrastCardKind.allCases {
                XCTAssertFalse(card.title.isEmpty, "ContrastCard \(card.rawValue) title empty (en=\(isEn))")
                XCTAssertFalse(card.ageHint.isEmpty, "ContrastCard \(card.rawValue) ageHint empty (en=\(isEn))")
            }
        }
    }

    func testRhythmDialFactualSummary() {
        let d17 = Day(y: 2026, m: 10, d: 17)
        let d19 = Day(y: 2026, m: 10, d: 19)

        let overnight1 = LogEntry(type: LogType.sleep, start: t(17, 21, 0), end: t(18, 6, 30)) // 9.5h crossing midnight, bedtime 21:00
        let nap18 = LogEntry(type: LogType.sleep, start: t(18, 13, 0), end: t(18, 14, 30))       // 1.5h
        let overnight2 = LogEntry(type: LogType.sleep, start: t(18, 22, 0), end: t(19, 6, 0))  // 8.0h crossing midnight, bedtime 22:00
        let feed1 = LogEntry(type: LogType.bottle, start: t(18, 8, 0), amount: 120)
        let feed2 = LogEntry(type: LogType.bottle, start: t(18, 12, 0), amount: 120)
        let feed3 = LogEntry(type: LogType.nurse, start: t(19, 7, 0), end: t(19, 7, 15), side: "l")

        let model = RhythmDialModel.build(
            logs: [overnight1, nap18, overnight2, feed1, feed2, feed3],
            today: d19,
            days: 3
        )
        XCTAssertEqual(model.rings.first?.day, d17)
        XCTAssertEqual(model.rings.last?.day, d19)
        XCTAssertEqual(model.summary.activeDays, 3)
        XCTAssertEqual(model.summary.longestSleepHours ?? 0, 9.5, accuracy: 0.05)
        XCTAssertEqual(model.summary.avgFeedsPerDay ?? 0, 1.5, accuracy: 0.05) // 2 on d18, 1 on d19
        XCTAssertNotNil(model.summary.avgSleepHours)
        // Bedtimes 21:00 and 22:00 round to 22 (21.5 -> 22)
        XCTAssertTrue([21, 22].contains(model.summary.typicalBedtimeHour ?? -1))
    }

    func testIconsManifestCompletenessAndResolution() {
        let resolver = IconAssetResolver(bundle: Bundle(for: LogicTests.self))
        let resolved = resolver.manifest != nil ? resolver : IconAssetResolver.shared
        guard let manifest = resolved.manifest else {
            XCTFail("IconsManifest.json failed to decode from bundle")
            return
        }
        XCTAssertEqual(manifest.foods.count, 60)
        XCTAssertEqual(Set(manifest.foods.map(\.id)), Set(FoodItem.catalog.map(\.id)), "Every FoodItem must have a manifest entry")

        let requiredTools = ["bedside_lamp", "sensory_toybox", "first_foods", "rhythm_dial", "storybook", "time_capsules", "journey"]
        XCTAssertEqual(Set(manifest.tools.map(\.id)), Set(requiredTools))
        for spec in manifest.foods {
            XCTAssertFalse(spec.glyphKind.isEmpty)
            XCTAssertEqual(spec.primaryHex.count, 6)
            XCTAssertEqual(spec.secondaryHex.count, 6)
            XCTAssertEqual(spec.detailHex.count, 6)
        }
    }

    func testFoodCatalogHasZeroEmoji() {
        XCTAssertEqual(FoodItem.catalog.count, 60)
        let mirror = Mirror(reflecting: FoodItem.catalog[0])
        let labels = mirror.children.compactMap(\.label)
        XCTAssertFalse(labels.contains("icon"), "FoodItem must not expose an emoji icon field")
    }

    @MainActor
    func testBulbSpringPresetsAndPersistence() {
        XCTAssertEqual(BulbSpringPreset.locked, .warm)
        for preset in BulbSpringPreset.allCases {
            XCTAssertGreaterThan(preset.response, 0.2)
            XCTAssertGreaterThan(preset.dampingFraction, 0.4)
            XCTAssertGreaterThan(preset.triggerThreshold, 15)
        }
        let d = UserDefaults(suiteName: "bulb-preset-\(UUID().uuidString)")!
        d.set(BulbSpringPreset.airy.rawValue, forKey: "bulbSpringPreset")
        let m1 = AppModel(defaults: d)
        XCTAssertEqual(m1.bulbPreset, .warm)
    }

    func testDayChapterPartitioningAndSummaries() {
        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let day = Day(y: 2026, m: 11, d: 18)
        let prev = Day(y: 2026, m: 11, d: 17)
        func msAt(_ d: Day, _ h: Int, _ m: Int) -> Double {
            Day.cal.date(bySettingHour: h, minute: m, second: 0, of: d.date)!.timeIntervalSince1970 * 1000
        }

        let logs: [LogEntry] = [
            // Overnight carried over + morning/afternoon/evening
            LogEntry(type: LogType.sleep, start: msAt(prev, 23, 30), end: msAt(day, 1, 41)),
            LogEntry(type: LogType.nurse, start: msAt(day, 1, 36), end: msAt(day, 1, 42), side: "l"),
            LogEntry(type: LogType.diaper, start: msAt(day, 1, 41), detail: "wet"),
            LogEntry(type: LogType.nurse, start: msAt(day, 8, 1), end: msAt(day, 8, 5), side: "l"),
            LogEntry(type: LogType.medicine, start: msAt(day, 8, 31), detail: "Vitamin AD"),
            LogEntry(type: LogType.sleep, start: msAt(day, 12, 35), end: msAt(day, 14, 19)),
            // Two-sided contiguous nursing feed within 120s join window (must group into 1 feed row!)
            LogEntry(type: LogType.nurse, start: msAt(day, 15, 57), end: msAt(day, 16, 3), side: "l"),
            LogEntry(type: LogType.nurse, start: msAt(day, 16, 3) + 20_000, end: msAt(day, 16, 8), side: "r"),
            LogEntry(type: LogType.diaper, start: msAt(day, 16, 41), detail: "dirty"),
            LogEntry(type: LogType.bottle, start: msAt(day, 19, 51), amount: 30, detail: "breastmilk"),
            LogEntry(type: LogType.sleep, start: msAt(day, 19, 40), end: msAt(day, 20, 25)),
        ]

        let chapters = DayChapter.build(day: day, logs: logs)
        XCTAssertEqual(chapters.map(\.period), [.evening, .afternoon, .morning, .overnight])
        // Total grouped rows: 10 (two-sided 15:57 nursing collapsed into 1 row!)
        XCTAssertEqual(chapters.reduce(0) { $0 + $1.rowCount }, 10)
        // Overnight includes carried-over sleep (23:30..01:41 -> clamped to 00:00..01:41 on Nov 18 = 101 min)
        let overnight = chapters.last!
        XCTAssertEqual(overnight.feedCount, 1)
        XCTAssertEqual(overnight.diaperCount, 1)
        XCTAssertEqual(overnight.sleepSeconds, 101 * 60, accuracy: 2.0)
        // Afternoon combined two-sided feed counts as 1 feed
        let afternoon = chapters[1]
        XCTAssertEqual(afternoon.feedCount, 1)
        XCTAssertEqual(afternoon.diaperCount, 1)
        XCTAssertEqual(DayPeriod.of(timestampMs: msAt(prev, 23, 30), on: day), .overnight)
    }

    func testSmartBottleVolumeSuggestions() {
        XCTAssertEqual(SmartBottleVolumes.suggestions(lastMl: nil), [60, 90, 120, 150])
        XCTAssertEqual(SmartBottleVolumes.suggestions(lastMl: 30), [20, 30, 45, 60])
        XCTAssertEqual(SmartBottleVolumes.suggestions(lastMl: 120), [90, 120, 150, 180])
        let big = SmartBottleVolumes.suggestions(lastMl: 290)
        XCTAssertEqual(big, big.sorted())
        XCTAssertTrue(big.allSatisfy { (10...300).contains($0) })
        XCTAssertEqual(Set(big).count, big.count)
    }

    func testActivityMotionSpecsCoverAll46Plays() throws {
        let content = try Content.load()
        XCTAssertEqual(content.activities.count, 46)
        let specs = ActivityMotionIndex.specsByCode
        XCTAssertEqual(specs.count, 46, "Every activity must be registered in ActivityMotionSpecs.json")

        for play in content.activities {
            let spec = try XCTUnwrap(specs[play.code], "Missing motion spec for \(play.code)")
            XCTAssertFalse(spec.prop.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(spec.zhCue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(spec.enCue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            let hasEmoji = (spec.zhCue + spec.enCue).unicodeScalars.contains { $0.properties.isEmojiPresentation }
            XCTAssertFalse(hasEmoji, "Motion cues must contain zero Emoji: \(play.code)")
        }
    }

    func testEarSafeVolumeGuardThresholdsAndCadence() {
        XCTAssertEqual(EarSafeVolumeLevel.of(0.0), .muted)
        XCTAssertEqual(EarSafeVolumeLevel.of(0.35), .safe)
        XCTAssertEqual(EarSafeVolumeLevel.of(0.60), .safe)
        XCTAssertEqual(EarSafeVolumeLevel.of(0.61), .loud)
        XCTAssertEqual(EarSafeVolumeLevel.of(0.95), .loud)

        // First-ever Toybox sound visit: always shows helpful comfort meter
        XCTAssertTrue(EarSafeVolumeMonitor.shouldPrompt(volume: 0.35, context: .toybox, hasSeenToyboxGuide: false, dismissedThisSession: false))

        // Repeat Toybox visits: stay quiet when volume is comfortably inside baby-safe zone (1%...60%)
        XCTAssertFalse(EarSafeVolumeMonitor.shouldPrompt(volume: 0.38, context: .toybox, hasSeenToyboxGuide: true, dismissedThisSession: false))
        // Repeat Toybox visits: softly re-surface only if volume is too loud (>60%) or muted (<1%)
        XCTAssertTrue(EarSafeVolumeMonitor.shouldPrompt(volume: 0.78, context: .toybox, hasSeenToyboxGuide: true, dismissedThisSession: false))
        XCTAssertTrue(EarSafeVolumeMonitor.shouldPrompt(volume: 0.0, context: .toybox, hasSeenToyboxGuide: true, dismissedThisSession: false))
        // Respect dismissal within the same session
        XCTAssertFalse(EarSafeVolumeMonitor.shouldPrompt(volume: 0.85, context: .toybox, hasSeenToyboxGuide: true, dismissedThisSession: true))

        // Bedside Lamp: whispers only when high volume (>62%)
        XCTAssertFalse(EarSafeVolumeMonitor.shouldPrompt(volume: 0.50, context: .lamp, hasSeenToyboxGuide: false, dismissedThisSession: false))
        XCTAssertTrue(EarSafeVolumeMonitor.shouldPrompt(volume: 0.74, context: .lamp, hasSeenToyboxGuide: true, dismissedThisSession: false))
    }

    @MainActor func testAll46PlaysResolveStepIllustrationsAndKineticActions() throws {
        let content = try Content.load()
        XCTAssertEqual(content.activities.count, 46)

        let originalStyle = ArtStyle.current
        defer { ArtStyle.current = originalStyle }

        for play in content.activities {
            let steps = ArtIndex.shared.steps(play.code)
            XCTAssertFalse(steps.isEmpty, "Missing step diagram array for \(play.code)")
            let spec = ActivityMotionIndex.spec(for: play)

            for (idx, stepName) in steps.enumerated() {
                ArtStyle.current = .vinyl
                XCTAssertNotNil(ArtCache.shared.image(stepName, maxPixel: 480), "Missing 3D step image \(stepName) for \(play.code)[\(idx)]")
                ArtStyle.current = .flat
                XCTAssertNotNil(ArtCache.shared.image(stepName, maxPixel: 480), "Missing 2D step image for \(stepName) (\(play.code)[\(idx)])")

                let text = idx < play.steps.count ? play.steps[idx] : spec.cue
                let action = StepKineticAction.infer(stepText: text, stepIndex: idx, stepCount: play.steps.count, template: spec.template)
                XCTAssertFalse(action.label.isEmpty)
                XCTAssertFalse(action.symbol.isEmpty)
            }
        }

        // Bilingual kinetic cue inference checks
        XCTAssertEqual(StepKineticAction.infer(stepText: "停下来等一等宝宝的回应", stepIndex: 1, stepCount: 3, template: .soundWave), .pauseWatch)
        XCTAssertEqual(StepKineticAction.infer(stepText: "Wait and watch for a response", stepIndex: 1, stepCount: 3, template: .soundWave), .pauseWatch)
        XCTAssertEqual(StepKineticAction.infer(stepText: "左右慢慢移动让眼睛追视", stepIndex: 0, stepCount: 3, template: .graspPass), .sideSweep)
        XCTAssertEqual(StepKineticAction.infer(stepText: "Sweep side to side slowly", stepIndex: 0, stepCount: 3, template: .graspPass), .sideSweep)
        XCTAssertEqual(StepKineticAction.infer(stepText: "轻轻摇响铃铛", stepIndex: 0, stepCount: 3, template: .soundWave), .soundRipple)
        XCTAssertEqual(StepKineticAction.infer(stepText: "把积木往上叠高", stepIndex: 1, stepCount: 3, template: .stackBuild), .liftStack)
        XCTAssertEqual(StepKineticAction.infer(stepText: "把环轻轻递到手中", stepIndex: 0, stepCount: 3, template: .graspPass), .offerArc)
        XCTAssertEqual(StepKineticAction.infer(stepText: "抱着宝宝温柔对笑", stepIndex: 0, stepCount: 3, template: .gentleHold), .gentleSway)
    }

    func testActivityMotionStageStepProgressAndPropSymbols() throws {
        XCTAssertEqual(ActivityMotionStage.stepProgress(stepIndex: 0, stepCount: 1), 0, accuracy: 0.001)
        XCTAssertEqual(ActivityMotionStage.stepProgress(stepIndex: 0, stepCount: 4), 0, accuracy: 0.001)
        XCTAssertEqual(ActivityMotionStage.stepProgress(stepIndex: 1, stepCount: 3), 0.5, accuracy: 0.001)
        XCTAssertEqual(ActivityMotionStage.stepProgress(stepIndex: 9, stepCount: 3), 1.0, accuracy: 0.001)

        XCTAssertEqual(ActivityMotionStage.propSymbol(for: "bell", fallback: .soundWave), "bell.and.waves.left.and.right.fill")
        XCTAssertEqual(ActivityMotionStage.propSymbol(for: "unknownProp", fallback: .stackBuild), "square.stack.3d.up.fill")

        let content = try Content.load()
        for play in content.activities {
            let spec = ActivityMotionIndex.spec(for: play)
            XCTAssertFalse(ActivityMotionStage.propSymbol(for: spec.prop, fallback: spec.template).isEmpty)
        }
    }

    func testQuickLogBottleAndBabyCareStatusSummary() {
        let day = Day(y: 2026, m: 10, d: 19)
        let now = day.date.addingTimeInterval(15 * 3600 + 30 * 60)
        let nowMs = now.timeIntervalSince1970 * 1000
        let snap = Snapshot(
            birthEpochDay: Day(y: 2026, m: 4, d: 2).epochDay,
            nickname: "小苔",
            companion: "Otto",
            journal: true,
            consented: true,
            consentVersion: SharedConsent.version
        )
        var body = JournalFile.Body()
        body.logs = [
            LogEntry(type: LogType.sleep, start: nowMs - 4 * 3600_000, end: nowMs - 2 * 3600_000),
            LogEntry(type: LogType.bottle, start: nowMs - 90 * 60_000, amount: 110, detail: "breastmilk"),
            LogEntry(type: LogType.diaper, start: nowMs - 70 * 60_000, detail: "wet"),
            LogEntry(type: LogType.diaper, start: nowMs - 30 * 60_000, detail: "both"),
        ]
        body.timers = [
            RunningTimer(type: LogType.nurse, start: nowMs - 14 * 60_000, side: "l")
        ]

        L10n.overrideEnglish = false
        let zh = BabyCareStatusSummary.build(body: body, snap: snap, now: now)
        XCTAssertEqual(zh.babyName, "小苔")
        XCTAssertNotNil(zh.activeTimerLabel)
        XCTAssertEqual(zh.todayWetDiapers, 2)
        XCTAssertEqual(zh.todayDirtyDiapers, 1)
        XCTAssertTrue(zh.dialogText.contains("小苔"))
        XCTAssertTrue(zh.dialogText.contains("湿 2 便 1"))

        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let en = BabyCareStatusSummary.build(body: body, snap: snap, now: now)
        XCTAssertNotNil(en.activeTimerLabel)
        XCTAssertEqual(en.todayWetDiapers, 2)
        XCTAssertEqual(en.todayDirtyDiapers, 1)
        XCTAssertTrue(en.dialogText.contains("2 wet, 1 dirty"))
        XCTAssertTrue(en.lastFeedNote?.contains("Bottle") == true)
    }

    func testReviewPromptGateDaytimeAndCadence() {
        let dayNoon = Day.cal.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 14, minute: 30))!
        let night = Day.cal.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 21, minute: 45))!
        let early = Day.cal.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 6, minute: 45))!
        let oldDate = Day.cal.date(byAdding: .day, value: -75, to: dayNoon)!
        let recentDate = Day.cal.date(byAdding: .day, value: -20, to: dayNoon)!

        XCTAssertTrue(ReviewPromptGate.shouldRequestReview(
            now: dayNoon, isDarkMode: false, isBedsideLamp: false, keepsakeCount: 3,
            currentVersion: "1.3.2", lastPromptedVersion: nil, lastPromptedAt: nil
        ))
        // Blocks night hours, dark mode, and bedside lamp mode
        XCTAssertFalse(ReviewPromptGate.shouldRequestReview(
            now: night, isDarkMode: false, isBedsideLamp: false, keepsakeCount: 5,
            currentVersion: "1.3.2", lastPromptedVersion: nil, lastPromptedAt: nil
        ))
        XCTAssertFalse(ReviewPromptGate.shouldRequestReview(
            now: early, isDarkMode: false, isBedsideLamp: false, keepsakeCount: 5,
            currentVersion: "1.3.2", lastPromptedVersion: nil, lastPromptedAt: nil
        ))
        XCTAssertFalse(ReviewPromptGate.shouldRequestReview(
            now: dayNoon, isDarkMode: true, isBedsideLamp: false, keepsakeCount: 5,
            currentVersion: "1.3.2", lastPromptedVersion: nil, lastPromptedAt: nil
        ))
        XCTAssertFalse(ReviewPromptGate.shouldRequestReview(
            now: dayNoon, isDarkMode: false, isBedsideLamp: true, keepsakeCount: 5,
            currentVersion: "1.3.2", lastPromptedVersion: nil, lastPromptedAt: nil
        ))
        // Blocks fewer than 3 keepsakes, same version, and within 60 days
        XCTAssertFalse(ReviewPromptGate.shouldRequestReview(
            now: dayNoon, isDarkMode: false, isBedsideLamp: false, keepsakeCount: 2,
            currentVersion: "1.3.2", lastPromptedVersion: nil, lastPromptedAt: nil
        ))
        XCTAssertFalse(ReviewPromptGate.shouldRequestReview(
            now: dayNoon, isDarkMode: false, isBedsideLamp: false, keepsakeCount: 5,
            currentVersion: "1.3.2", lastPromptedVersion: "1.3.2", lastPromptedAt: oldDate
        ))
        XCTAssertFalse(ReviewPromptGate.shouldRequestReview(
            now: dayNoon, isDarkMode: false, isBedsideLamp: false, keepsakeCount: 5,
            currentVersion: "2.0", lastPromptedVersion: "1.3.2", lastPromptedAt: recentDate
        ))
        XCTAssertTrue(ReviewPromptGate.shouldRequestReview(
            now: dayNoon, isDarkMode: false, isBedsideLamp: false, keepsakeCount: 5,
            currentVersion: "2.0", lastPromptedVersion: "1.3.2", lastPromptedAt: oldDate
        ))
    }

    @MainActor
    func testBedsideLampPreferencesPersistAndClear() {
        let suiteName = "app.mossling.tests.lamp.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let model = AppModel(defaults: defaults)
        XCTAssertEqual(model.lampBrightness, 0.72, accuracy: 0.001)
        XCTAssertEqual(model.lampWarmthRaw, "amber")
        XCTAssertFalse(model.lampBreathingGuide)
        XCTAssertFalse(model.isBedsideLampOpen)

        model.lampBrightness = 0.05 // clamps to 0.15 floor
        XCTAssertEqual(model.lampBrightness, 0.15, accuracy: 0.001)
        model.lampBrightness = 0.24
        model.lampWarmthRaw = LampWarmth.candle.rawValue
        model.lampBreathingGuide = true
        model.bedsideLampPresentedCount = 1
        XCTAssertTrue(model.isBedsideLampOpen)

        let reloaded = AppModel(defaults: defaults)
        XCTAssertEqual(reloaded.lampBrightness, 0.24, accuracy: 0.001)
        XCTAssertEqual(reloaded.lampWarmthRaw, "candle")
        XCTAssertTrue(reloaded.lampBreathingGuide)

        reloaded.clearAll()
        XCTAssertEqual(reloaded.lampBrightness, 0.72, accuracy: 0.001)
        XCTAssertEqual(reloaded.lampWarmthRaw, "amber")
        XCTAssertFalse(reloaded.lampBreathingGuide)
    }

    func testBedsideLampScreenBrightnessCeilingNeverExceedsSystemBaseline() {
        // Dimming down in a bright room lowers the ceiling monotonically
        let minDim = BedsideLampView.targetScreenBrightness(lampBrightness: 0.15, savedSystemBrightness: 0.90)
        let midDim = BedsideLampView.targetScreenBrightness(lampBrightness: 0.50, savedSystemBrightness: 0.90)
        let maxDim = BedsideLampView.targetScreenBrightness(lampBrightness: 1.00, savedSystemBrightness: 0.90)
        XCTAssertEqual(minDim, 0.06, accuracy: 0.001)
        XCTAssertLessThan(minDim, midDim)
        XCTAssertLessThan(midDim, maxDim)
        XCTAssertEqual(maxDim, 0.50, accuracy: 0.001)

        // Never raises brightness if the user's phone is already darker than the lamp ceiling
        XCTAssertEqual(BedsideLampView.targetScreenBrightness(lampBrightness: 1.0, savedSystemBrightness: 0.12), 0.12, accuracy: 0.001)
    }

    @MainActor func testBedsideLampEmberFadeCouplingAndWarmthTokens() {
        // Above 20s remaining (or continuous): preserves user's chosen brightness untouched
        XCTAssertEqual(
            BedsideLampView.effectiveBrightness(baseBrightness: 0.80, remainingSeconds: 45, isFinitePlaying: true, emberResting: false),
            0.80,
            accuracy: 0.001
        )
        XCTAssertEqual(
            BedsideLampView.effectiveBrightness(baseBrightness: 0.80, remainingSeconds: 5, isFinitePlaying: false, emberResting: false),
            0.80,
            accuracy: 0.001
        )

        // During final 20s auto-fade: tapers smoothly along SoundscapeEngine's cosine envelope toward 0.12
        let at20 = BedsideLampView.effectiveBrightness(baseBrightness: 0.80, remainingSeconds: 20, isFinitePlaying: true, emberResting: false)
        let at10 = BedsideLampView.effectiveBrightness(baseBrightness: 0.80, remainingSeconds: 10, isFinitePlaying: true, emberResting: false)
        let at0 = BedsideLampView.effectiveBrightness(baseBrightness: 0.80, remainingSeconds: 0, isFinitePlaying: true, emberResting: false)
        XCTAssertEqual(at20, 0.80, accuracy: 0.001)
        XCTAssertEqual(at10, 0.46, accuracy: 0.001)
        XCTAssertEqual(at0, 0.12, accuracy: 0.001)

        // Post-fade ember rest settles quietly to 0.10 regardless of prior base brightness
        XCTAssertEqual(
            BedsideLampView.effectiveBrightness(baseBrightness: 0.90, remainingSeconds: nil, isFinitePlaying: false, emberResting: true),
            0.10,
            accuracy: 0.001
        )

        // All warmth presets expose distinct labels and non-empty semantic tokens
        XCTAssertEqual(Set(LampWarmth.allCases.map(\.id)).count, 3)

        // SoundscapeEngine manual stop never flags natural auto-fade ember rest
        let engine = SoundscapeEngine.shared
        engine.duration = .m15
        engine.start(.rain)
        XCTAssertFalse(engine.didFinishAutoFade)
        engine.stop()
        XCTAssertFalse(engine.didFinishAutoFade)
        engine.clearAutoFadeNotice()
        XCTAssertFalse(engine.didFinishAutoFade)
    }

    func testTimeCapsuleSealedDaysSpan() {
        let written = Day(y: 2026, m: 4, d: 2)
        let writtenMs = written.date.timeIntervalSince1970 * 1000 + 12 * 3600 * 1000
        let openDay = Day(y: 2026, m: 10, d: 19)
        let openMs = openDay.date.timeIntervalSince1970 * 1000 + 18 * 3600 * 1000

        // While still sealed: measures span against today's reference day
        let sealed = TimeCapsule(
            title: "给秋天的信",
            body: "愿你慢慢长大",
            writtenAt: writtenMs,
            writtenAgeLabel: "出生",
            unlockEpochDay: openDay.epochDay,
            openedAt: nil,
            seal: .gold
        )
        XCTAssertNil(sealed.openedDay)
        XCTAssertEqual(sealed.sealedDays(on: openDay), openDay.epochDay - written.epochDay)
        // Clamped to zero even if reference day is earlier than written day
        XCTAssertEqual(sealed.sealedDays(on: written.plus(days: -3)), 0)

        // Once opened: freezes span on the exact day the wax seal was broken
        var opened = sealed
        opened.openedAt = openMs
        XCTAssertEqual(opened.openedDay, openDay)
        XCTAssertEqual(opened.sealedDays(on: openDay.plus(days: 30)), openDay.epochDay - written.epochDay)
    }

    @MainActor
    func testFoodAtlasQuickStampIncrementAndSuggestions() {
        let day = Day(y: 2026, m: 10, d: 20)
        let store = FoodAtlasStore(preview: [
            FoodRecord(foodId: "pumpkin", firstTastedEpochDay: day.plus(days: -5).epochDay, reaction: .loved, times: 1),
            FoodRecord(foodId: "broccoli", firstTastedEpochDay: day.plus(days: -3).epochDay, reaction: .tryAgain, times: 2),
        ])

        XCTAssertEqual(store.tryAgainCount, 1)
        XCTAssertGreaterThan(store.allergenTotalCount, 10)
        XCTAssertEqual(store.allergenIntroducedCount, 0)

        // Gentle retry foods appear first in suggestedBiteCandidates before starter untried foods
        let candidates = store.suggestedBiteCandidates()
        XCTAssertEqual(candidates.first?.id, "broccoli")
        XCTAssertTrue(candidates.dropFirst().contains { $0.id == "ricecereal" })

        // Quick stamping an untried allergen records first taste and updates allergen count
        let egg = store.quickStamp(foodId: "eggyolk", reaction: .tasted, today: day)
        XCTAssertEqual(egg.firstTastedEpochDay, day.epochDay)
        XCTAssertEqual(egg.reaction, .tasted)
        XCTAssertEqual(egg.times, 1)
        XCTAssertEqual(store.allergenIntroducedCount, 1)

        // Updating reaction via quickStamp preserves original first taste day and times
        let updated = store.quickStamp(foodId: "broccoli", reaction: .loved, today: day.plus(days: 4))
        XCTAssertEqual(updated.firstTastedEpochDay, day.plus(days: -3).epochDay)
        XCTAssertEqual(updated.times, 2)
        XCTAssertEqual(updated.reaction, .loved)
        XCTAssertEqual(store.tryAgainCount, 0)

        // Incrementing tasting exposure count preserves everything else
        let incremented = store.incrementTimes(foodId: "pumpkin")
        XCTAssertEqual(incremented?.times, 2)
    }

    @MainActor
    func testMeasureParserAndGrowthPrintPoster() throws {
        // Weight in kg, gram auto-conversion, locale comma decimal, and strict bounds
        XCTAssertEqual(MeasureParser.parseWeightGrams("7.85"), .init(grams: 7850, convertedFromGrams: false, invalid: false))
        XCTAssertEqual(MeasureParser.parseWeightGrams("7,85"), .init(grams: 7850, convertedFromGrams: false, invalid: false))
        XCTAssertEqual(MeasureParser.parseWeightGrams("7850"), .init(grams: 7850, convertedFromGrams: true, invalid: false))
        XCTAssertEqual(MeasureParser.parseWeightGrams("0.5"), .init(grams: nil, convertedFromGrams: false, invalid: true))
        XCTAssertEqual(MeasureParser.parseWeightGrams(" "), .init(grams: nil, convertedFromGrams: false, invalid: false))

        // Length & head circumference bounds
        XCTAssertEqual(MeasureParser.parseLengthMm("68.4"), .init(mm: 684, invalid: false))
        XCTAssertEqual(MeasureParser.parseLengthMm("20"), .init(mm: nil, invalid: true))
        XCTAssertEqual(MeasureParser.parseHeadMm("43.5"), .init(mm: 435, invalid: false))
        XCTAssertEqual(MeasureParser.parseHeadMm("75"), .init(mm: nil, invalid: true))

        // Previous value, delta formatting, and WHO typical range & percentile
        let birth = Day(y: 2026, m: 4, d: 1)
        let m1 = Measure(at: Day(y: 2026, m: 7, d: 1).date.timeIntervalSince1970 * 1000, weightG: 6200, lengthMm: 615, headMm: 405)
        let m2 = Measure(at: Day(y: 2026, m: 10, d: 1).date.timeIntervalSince1970 * 1000, weightG: 7550, lengthMm: 672, headMm: 432)
        let prev = MeasureParser.previousValue(for: .weight, excluding: m2.id, before: m2.at, in: [m1, m2])
        XCTAssertEqual(prev ?? 0, 6.20, accuracy: 0.001)
        XCTAssertEqual(MeasureParser.deltaLabel(current: 7.55, previous: prev, indicator: .weight), "较上次 +1.35 kg")

        let g = try Growth.load()
        let oct1 = Day(y: 2026, m: 10, d: 1).date
        let band = MeasureParser.typicalRange(for: .weight, date: oct1, birth: birth, sex: "girl", growth: g)
        XCTAssertNotNil(band)
        XCTAssertLessThan(band!.lowerBound, band!.upperBound)
        let pct = MeasureParser.percentileLabel(for: .weight, value: 7.55, date: oct1, birth: birth, sex: "girl", growth: g)
        XCTAssertNotNil(pct)

        // 3x offline cotton-paper GrowthPrintPoster renders cleanly
        let poster = GrowthPrintPoster(
            babyName: "小苔",
            ageText: "6 个月",
            sex: "girl",
            indicator: .weight,
            spanMonths: 12,
            measures: [m1, m2],
            birth: birth,
            growth: g
        )
        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3.0
        let img = renderer.uiImage
        XCTAssertNotNil(img)
        XCTAssertGreaterThan(img?.size.width ?? 0, 300)
        XCTAssertGreaterThan(img?.size.height ?? 0, 300)
    }

    func testGrowthLedgerDelta() {
        let day = 86_400_000.0
        let base = Day(y: 2026, m: 4, d: 2).date.timeIntervalSince1970 * 1000
        let m1 = Measure(at: base, weightG: 3300, lengthMm: 500, headMm: 340)
        let m2 = Measure(at: base + 60 * day, weightG: 5400, lengthMm: nil, headMm: 385)
        let m3 = Measure(at: base + 120 * day, weightG: 6600, lengthMm: 625, headMm: 410)
        let m4 = Measure(at: base + 190 * day, weightG: 7400, lengthMm: 655, headMm: 425)
        // Pass unsorted to verify chronological delta ordering
        let all = [m4, m2, m1, m3]

        XCTAssertNil(GrowthView.delta(for: m1, in: all, indicator: .weight))
        XCTAssertEqual(GrowthView.delta(for: m2, in: all, indicator: .weight) ?? 0, 2.10, accuracy: 0.001)
        XCTAssertEqual(GrowthView.delta(for: m3, in: all, indicator: .weight) ?? 0, 1.20, accuracy: 0.001)
        XCTAssertEqual(GrowthView.delta(for: m4, in: all, indicator: .weight) ?? 0, 0.80, accuracy: 0.001)

        // Missing length on m2 skips cleanly back to m1 (50.0 cm -> 62.5 cm = +12.5 cm)
        XCTAssertNil(GrowthView.delta(for: m2, in: all, indicator: .length))
        XCTAssertEqual(GrowthView.delta(for: m3, in: all, indicator: .length) ?? 0, 12.5, accuracy: 0.001)
        XCTAssertEqual(GrowthView.delta(for: m4, in: all, indicator: .length) ?? 0, 3.0, accuracy: 0.001)
        XCTAssertEqual(GrowthView.delta(for: m4, in: all, indicator: .head) ?? 0, 1.5, accuracy: 0.001)
    }

    func testShelfComposerCoveredAreas() throws {
        let c = try Content.load()
        XCTAssertEqual(ShelfComposerMetrics.coveredAreaKeys(for: []), [])
        XCTAssertEqual(ShelfComposerMetrics.areaCounts(for: []), [:])

        let all = c.activities
        // Pick distinct plays covering different areas
        let lang = all.first { Palette.areaKey(of: $0) == "A" }!
        let motor = all.first { Palette.areaKey(of: $0) == "B" }!
        let fine = all.first { Palette.areaKey(of: $0) == "C" }!
        let social = all.first { Palette.areaKey(of: $0) == "D" }!

        XCTAssertEqual(ShelfComposerMetrics.coveredAreaKeys(for: [lang, lang]), ["A"])
        XCTAssertEqual(ShelfComposerMetrics.areaCounts(for: [lang, lang]), ["A": 2])

        let four = [social, lang, fine, motor]
        XCTAssertEqual(ShelfComposerMetrics.coveredAreaKeys(for: four), ["A", "B", "C", "D"])
        XCTAssertEqual(ShelfComposerMetrics.areaCounts(for: four), ["A": 1, "B": 1, "C": 1, "D": 1])
    }

    @MainActor
    func testStudioArtCacheRendersSyncImages() {
        let pumpkin = FoodItem.catalog.first { $0.id == "pumpkin" }!
        let avocado = FoodItem.catalog.first { $0.id == "avocado" }!

        for scheme in [ColorScheme.light, ColorScheme.dark] {
            for flat in [false, true] {
                let isDark = scheme == .dark ? 1 : 0
                let isFlat = flat ? 1 : 0

                for food in [pumpkin, avocado] {
                    let r = ImageRenderer(
                        content: FoodGlyphView(food: food, size: 42, flat: flat)
                            .environment(\.colorScheme, scheme)
                    )
                    r.scale = 3.0
                    let img = r.uiImage
                    XCTAssertNotNil(img, "FoodGlyphView failed for \(food.id)")
                    XCTAssertGreaterThan(img?.size.width ?? 0, 30)
                    XCTAssertTrue(ScreenshotTests.drewSomething(img!), "FoodGlyphView drew blank for \(food.id)")

                    // Verify StudioArtCache cached the vector raster under expected key when not bundled
                    if IconAssetResolver.shared.bundledImage(asset3D: "", asset2D: "", maxPixel: 126) == nil {
                        let key = "food|\(food.id)|42|\(isFlat)|\(isDark)"
                        let cached = StudioArtCache.shared.image(key: key, size: 42, colorScheme: scheme) { Color.clear }
                        XCTAssertNotNil(cached)
                    }
                }

                for toolId in ["bedside_lamp", "sensory_toybox"] {
                    let r = ImageRenderer(
                        content: ToolArtBadge(toolId: toolId, size: 36, active: true, flat: flat)
                            .environment(\.colorScheme, scheme)
                    )
                    r.scale = 3.0
                    let img = r.uiImage
                    XCTAssertNotNil(img, "ToolArtBadge failed for \(toolId)")
                    XCTAssertGreaterThan(img?.size.width ?? 0, 30)
                    XCTAssertTrue(ScreenshotTests.drewSomething(img!), "ToolArtBadge drew blank for \(toolId)")
                }
            }
        }
    }

    func testMidnightCareSummaryBuildsFactsAndBottleDefaults() {
        let now = Day.cal.date(bySettingHour: 2, minute: 30, second: 0, of: Day(y: 2026, m: 10, d: 20).date)!
        let nowMs = now.timeIntervalSince1970 * 1000

        // Empty logs produce zero facts and fallback bottle suggestions
        let empty = MidnightCareSummary.build(logs: [], now: now)
        XCTAssertTrue(empty.facts.isEmpty)
        XCTAssertEqual(empty.bottleSuggestions, SmartBottleVolumes.suggestions(lastMl: nil))
        XCTAssertEqual(empty.defaultMilkKind, "formula")

        // Unsorted logs: newest bottle dictates volume suggestions & milk kind; feed/wake/diaper populate in order
        let logs = [
            LogEntry(type: LogType.bottle, start: nowMs - 5 * 3_600_000, amount: 90, detail: "formula"),
            LogEntry(type: LogType.sleep, start: nowMs - 6 * 3_600_000, end: nowMs - 90 * 60_000),
            LogEntry(type: LogType.diaper, start: nowMs - 45 * 60_000, detail: "wet"),
            LogEntry(type: LogType.bottle, start: nowMs - 2 * 3_600_000, amount: 150, detail: "breastmilk"),
        ]
        let summary = MidnightCareSummary.build(logs: logs, now: now)
        XCTAssertEqual(summary.facts.map(\.id), ["feed", "wake", "diaper"])
        XCTAssertEqual(summary.defaultMilkKind, "breastmilk")
        XCTAssertEqual(summary.bottleSuggestions, SmartBottleVolumes.suggestions(lastMl: 150))
        XCTAssertTrue(summary.facts[0].agoText.contains("2"))
        XCTAssertTrue(summary.facts[2].agoText.contains("45"))

        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = false }
        let enSummary = MidnightCareSummary.build(logs: logs, now: now)
        XCTAssertEqual(enSummary.facts.map(\.label), ["Feed", "Wake", "Diaper"])
        XCTAssertEqual(enSummary.facts[0].agoText, "2h ago")
        XCTAssertEqual(enSummary.facts[2].agoText, "45m ago")
        XCTAssertNotNil(enSummary.nightStatusLine)
        XCTAssertTrue(enSummary.nightStatusLine?.contains("Awake") == true)
        XCTAssertTrue(enSummary.nightStatusLine?.contains("Night sleep") == true)
    }

    func testMidnightCareSummaryLiveTimersAndSoundscapeEnvelope() {
        let now = Day.cal.date(bySettingHour: 3, minute: 0, second: 0, of: Day(y: 2026, m: 10, d: 20).date)!
        let nowMs = now.timeIntervalSince1970 * 1000
        let logs = [
            LogEntry(type: LogType.bottle, start: nowMs - 2 * 3_600_000, amount: 120, detail: "formula"),
        ]
        let sleepTimer = RunningTimer(type: LogType.sleep, start: nowMs - 45 * 60_000, side: nil, pausedAt: nil, pausedTotal: 0)
        let sleepingSummary = MidnightCareSummary.build(logs: logs, timers: [sleepTimer], now: now)
        XCTAssertEqual(sleepingSummary.facts.map(\.id), ["feed", "sleep"])
        XCTAssertTrue(sleepingSummary.nightStatusLine?.contains("45") == true)

        let nurseTimer = RunningTimer(type: LogType.nurse, start: nowMs - 12 * 60_000, side: "r", pausedAt: nil, pausedTotal: 0)
        let nursingSummary = MidnightCareSummary.build(logs: logs, timers: [nurseTimer], now: now)
        XCTAssertTrue(nursingSummary.nightStatusLine?.contains("右") == true)

        // Breathing haptic boundary timing (4s inhale -> 6s exhale)
        let b1 = BedsideLampView.nextBreathingBoundary(at: 1.5)
        XCTAssertEqual(b1.delay, 2.5, accuracy: 0.001)
        XCTAssertFalse(b1.nextInhaling)
        let b2 = BedsideLampView.nextBreathingBoundary(at: 6.2)
        XCTAssertEqual(b2.delay, 3.8, accuracy: 0.001)
        XCTAssertTrue(b2.nextInhaling)

        // Soundscape acoustic-luminous rhythm envelope invariants across all 6 kinds
        for kind in SoundscapeKind.allCases {
            for t in stride(from: 0.0, through: 9.0, by: 0.15) {
                let p = SoundscapeRhythmEnvelope.pulse(for: kind, at: t)
                XCTAssertGreaterThanOrEqual(p, 0.0)
                XCTAssertLessThanOrEqual(p, 1.0)
            }
        }
        // Heartbeat lub-dub double peak > inter-beat rest
        let hbLub = SoundscapeRhythmEnvelope.pulse(for: .heartbeat, at: 0.04)
        let hbDub = SoundscapeRhythmEnvelope.pulse(for: .heartbeat, at: 0.27)
        let hbRest = SoundscapeRhythmEnvelope.pulse(for: .heartbeat, at: 0.70)
        XCTAssertGreaterThan(hbLub, hbDub)
        XCTAssertGreaterThan(hbDub, hbRest)
        // Shush active during first 1.15s and quiet during rest
        let shushPeak = SoundscapeRhythmEnvelope.pulse(for: .shush, at: 0.575)
        let shushRest = SoundscapeRhythmEnvelope.pulse(for: .shush, at: 1.8)
        XCTAssertGreaterThan(shushPeak, 0.85)
        XCTAssertLessThan(shushRest, 0.2)
        // Dual-layer blend remains bounded
        let blend = SoundscapeRhythmEnvelope.compositePulse(primary: .waves, secondary: .heartbeat, at: 2.0)
        XCTAssertGreaterThanOrEqual(blend, 0.0)
        XCTAssertLessThanOrEqual(blend, 1.0)
    }

    func testJourneyStripMetrics() {
        XCTAssertEqual(JourneyStripMetrics.totalStations, 37)
        XCTAssertEqual(JourneyStripMetrics.clampedMonth(-2), 0)
        XCTAssertEqual(JourneyStripMetrics.clampedMonth(6), 6)
        XCTAssertEqual(JourneyStripMetrics.clampedMonth(42), 36)

        XCTAssertEqual(JourneyStripMetrics.stationOrdinal(month: -1), 1)
        XCTAssertEqual(JourneyStripMetrics.stationOrdinal(month: 0), 1)
        XCTAssertEqual(JourneyStripMetrics.stationOrdinal(month: 6), 7)
        XCTAssertEqual(JourneyStripMetrics.stationOrdinal(month: 36), 37)

        XCTAssertEqual(JourneyStripMetrics.normalizedPosition(month: 0), 0.0, accuracy: 0.0001)
        XCTAssertEqual(JourneyStripMetrics.normalizedPosition(month: 18), 0.5, accuracy: 0.0001)
        XCTAssertEqual(JourneyStripMetrics.normalizedPosition(month: 36), 1.0, accuracy: 0.0001)

        XCTAssertEqual(JourneyStripMetrics.monthProgressFraction(days: 0, toNext: 0), 0.0, accuracy: 0.0001)
        XCTAssertEqual(JourneyStripMetrics.monthProgressFraction(days: 15, toNext: 15), 0.5, accuracy: 0.0001)
        XCTAssertEqual(JourneyStripMetrics.monthProgressFraction(days: 35, toNext: 0), 1.0, accuracy: 0.0001)
    }

    func testYouStudioCompanionTags() {
        L10n.overrideEnglish = false
        XCTAssertEqual(YouStudioCopy.companionBadge(.moss), "爱探索")
        XCTAssertEqual(YouStudioCopy.companionBadge(.otto), "点暖灯")

        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        XCTAssertEqual(YouStudioCopy.companionBadge(.moss), "Explorer")
        XCTAssertEqual(YouStudioCopy.companionBadge(.otto), "Lamp Keeper")
    }

    func testDailyRhythmStageAndLiveComparison() throws {
        // 1. Exact WHO age-band boundaries across 0–36+ months
        XCTAssertEqual(DailyRhythmStage.stage(for: 0), .newborn)
        XCTAssertEqual(DailyRhythmStage.stage(for: 3), .newborn)
        XCTAssertEqual(DailyRhythmStage.stage(for: 4), .infant)
        XCTAssertEqual(DailyRhythmStage.stage(for: 11), .infant)
        XCTAssertEqual(DailyRhythmStage.stage(for: 12), .oneYear)
        XCTAssertEqual(DailyRhythmStage.stage(for: 23), .oneYear)
        XCTAssertEqual(DailyRhythmStage.stage(for: 24), .twoYears)
        XCTAssertEqual(DailyRhythmStage.stage(for: 35), .twoYears)
        XCTAssertEqual(DailyRhythmStage.stage(for: 36), .threeYears)
        XCTAssertEqual(DailyRhythmStage.stage(for: 42), .threeYears)

        // 2. Sleep, movement, and screen bounds per WHO 2019 guidelines
        XCTAssertEqual(DailyRhythmStage.newborn.sleepMinHours, 14)
        XCTAssertEqual(DailyRhythmStage.newborn.sleepMaxHours, 17)
        XCTAssertEqual(DailyRhythmStage.infant.sleepMinHours, 12)
        XCTAssertEqual(DailyRhythmStage.infant.sleepMaxHours, 16)
        XCTAssertEqual(DailyRhythmStage.oneYear.sleepMinHours, 11)
        XCTAssertEqual(DailyRhythmStage.oneYear.sleepMaxHours, 14)
        XCTAssertEqual(DailyRhythmStage.twoYears.sleepMinHours, 11)
        XCTAssertEqual(DailyRhythmStage.twoYears.sleepMaxHours, 14)
        XCTAssertEqual(DailyRhythmStage.threeYears.sleepMinHours, 10)
        XCTAssertEqual(DailyRhythmStage.threeYears.sleepMaxHours, 13)

        XCTAssertEqual(DailyRhythmStage.newborn.activityTargetMinutes, 30)
        XCTAssertEqual(DailyRhythmStage.infant.activityTargetMinutes, 30)
        XCTAssertEqual(DailyRhythmStage.oneYear.activityTargetMinutes, 180)
        XCTAssertEqual(DailyRhythmStage.threeYears.energeticMinutes, 60)
        XCTAssertEqual(DailyRhythmStage.twoYears.energeticMinutes, 0)
        XCTAssertEqual(DailyRhythmStage.oneYear.screenLimitMinutes, 0)
        XCTAssertEqual(DailyRhythmStage.twoYears.screenLimitMinutes, 60)

        // 3. Factual comparison respects journalEnabled toggle and computes accurate 7-day + today metrics
        let today = Day(y: 2026, m: 10, d: 19)
        let morningMs = Day.cal.date(bySettingHour: 7, minute: 0, second: 0, of: today.date)!.timeIntervalSince1970 * 1000
        let napStartMs = Day.cal.date(bySettingHour: 13, minute: 0, second: 0, of: today.date)!.timeIntervalSince1970 * 1000
        let logs = [
            // 10h overnight sleep ending at 07:00 today + 2h afternoon nap + 1 play entry today
            LogEntry(type: LogType.sleep, start: morningMs - 10 * 3_600_000, end: morningMs),
            LogEntry(type: LogType.sleep, start: napStartMs, end: napStartMs + 2 * 3_600_000),
            LogEntry(type: LogType.play, start: napStartMs - 2 * 3_600_000, detail: "A11"),
        ]

        let disabled = DailyRhythmComparison.build(logs: logs, today: today, journalEnabled: false)
        XCTAssertFalse(disabled.hasSleepBaseline)
        XCTAssertNil(disabled.avgSleepHours)
        XCTAssertEqual(disabled.todayPlayCount, 0)

        let enabled = DailyRhythmComparison.build(logs: logs, today: today, journalEnabled: true)
        XCTAssertTrue(enabled.hasSleepBaseline)
        XCTAssertEqual(enabled.todayPlayCount, 1)
        XCTAssertEqual(enabled.todaySleepHours, 9.0, accuracy: 0.05) // 00:00..07:00 (7h) + 13:00..15:00 (2h)
        XCTAssertNotNil(enabled.avgSleepHours)

        L10n.overrideEnglish = false
        let zhLine = enabled.sleepComparisonLine(for: .infant) ?? ""
        XCTAssertTrue(zhLine.contains("12–16"))
        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let enLine = enabled.sleepComparisonLine(for: .infant) ?? ""
        XCTAssertTrue(enLine.contains("12–16h"))

        // 4. Intact WHO guideline text across representative months in EN
        let enContent = try Content.load()
        for m in [0, 4, 12, 24, 36] {
            XCTAssertTrue(enContent.month(m).who.contains("WHO"), "Month \(m) EN WHO text missing WHO")
        }
    }

    func testSearchEngineScopesAndQuickQueries() throws {
        defer { L10n.overrideEnglish = nil }

        L10n.overrideEnglish = false
        let zhContent = try Content.load()
        XCTAssertTrue(SearchEngine.results(query: "   ", in: zhContent).isEmpty)

        let sleepZh = SearchEngine.results(query: "睡", in: zhContent)
        XCTAssertFalse(sleepZh.isEmpty)
        XCTAssertEqual(
            sleepZh.totalCount,
            sleepZh.count(for: .tools) + sleepZh.count(for: .foods) + sleepZh.count(for: .plays) + sleepZh.count(for: .months) + sleepZh.count(for: .topics)
        )
        XCTAssertFalse(sleepZh.topics.isEmpty)

        for month in [0, 6, 12, 24] {
            let qs = SearchEngine.quickQueries(for: month)
            XCTAssertEqual(qs.count, 4)
            for term in qs {
                XCTAssertFalse(SearchEngine.results(query: term, in: zhContent).isEmpty, "ZH quickQuery \(term) returned empty")
            }
        }

        L10n.overrideEnglish = true
        let enContent = try Content.load()
        XCTAssertFalse(SearchEngine.results(query: "pumpkin", in: enContent).foods.isEmpty)
        for month in [0, 6, 12, 24] {
            let qs = SearchEngine.quickQueries(for: month)
            XCTAssertEqual(qs.count, 4)
            for term in qs {
                XCTAssertFalse(SearchEngine.results(query: term, in: enContent).isEmpty, "EN quickQuery \(term) returned empty")
            }
        }
    }

    func testAreasConstellationMetricsAndCareFilter() throws {
        L10n.overrideEnglish = false
        defer { L10n.overrideEnglish = nil }
        let content = try Content.load()
        let m6 = content.month(6)
        let ordered = AreasConstellationMetrics.orderedDomains(m6.domains, focus: m6.focus)
        XCTAssertEqual(ordered.count, 6)
        if let f = m6.focus {
            XCTAssertEqual(AreasConstellationMetrics.normalizedKey(ordered[0].key), AreasConstellationMetrics.normalizedKey(f))
        }
        XCTAssertEqual(Set(ordered.map { AreasConstellationMetrics.normalizedKey($0.key) }), Set(AreasConstellationMetrics.canonicalKeys))

        let topVertex = AreasConstellationMetrics.vertex(index: 0, total: 6, radius: 40, center: CGPoint(x: 50, y: 50))
        XCTAssertEqual(topVertex.x, 50, accuracy: 0.001)
        XCTAssertEqual(topVertex.y, 10, accuracy: 0.001)
        XCTAssertFalse(AreasConstellationMetrics.matchingPlays(for: "A", month: 6, in: content).isEmpty)
        XCTAssertFalse(AreasConstellationMetrics.matchingPlays(for: "D", month: 6, in: content).isEmpty)

        XCTAssertTrue(CareFilterMode.all.matches(ticked: true))
        XCTAssertTrue(CareFilterMode.all.matches(ticked: false))
        XCTAssertTrue(CareFilterMode.pending.matches(ticked: false))
        XCTAssertFalse(CareFilterMode.pending.matches(ticked: true))
        XCTAssertTrue(CareFilterMode.done.matches(ticked: true))
        XCTAssertFalse(CareFilterMode.done.matches(ticked: false))
    }

    func testCareSessionRhythmComputesBalanceAndSleepContext() {
        let day = Day(y: 2026, m: 10, d: 19)
        let morningNurseStart = t(19, 7, 0)
        let morningNurseEnd = t(19, 7, 16)
        let firstSideStart = t(19, 10, 0)
        let switchedAt = t(19, 10, 12)
        let nowMs = t(19, 10, 18)

        let logs = [
            // Earlier completed feed today (16 min)
            LogEntry(type: LogType.nurse, start: morningNurseStart, end: morningNurseEnd, side: "l"),
            // Bottle feed earlier today
            LogEntry(type: LogType.bottle, start: t(19, 8, 30), amount: 110),
            // Left side (12 min) of current ongoing feed
            LogEntry(type: LogType.nurse, start: firstSideStart, end: switchedAt, side: "l"),
            // Overnight sleep 22:00 yesterday -> 06:30 today (6.5h today)
            LogEntry(type: LogType.sleep, start: t(18, 22, 0), end: t(19, 6, 30)),
        ]

        // Active nursing timer on right side for 6 min (total 18m: 12m L, 6m R -> 2/3 L)
        let nurseTimer = RunningTimer(type: LogType.nurse, start: switchedAt, side: "r", carried: 12 * 60_000)
        let nurseRhythm = CareSessionRhythm.build(timer: nurseTimer, logs: logs, day: day, nowMs: nowMs)
        XCTAssertEqual(nurseRhythm.leftSeconds, 12 * 60, accuracy: 0.5)
        XCTAssertEqual(nurseRhythm.rightSeconds, 6 * 60, accuracy: 0.5)
        XCTAssertEqual(nurseRhythm.leftFraction, 12.0 / 18.0, accuracy: 0.001)
        XCTAssertEqual(nurseRhythm.todayFeedIndex, 3) // morning nurse + bottle + current ongoing nurse
        XCTAssertEqual(nurseRhythm.previousFeedSeconds ?? 0, 16 * 60, accuracy: 0.5)

        // Zero-duration nursing timer should stay centered at 0.5
        let zeroNurse = RunningTimer(type: LogType.nurse, start: nowMs, side: "l")
        let zeroRhythm = CareSessionRhythm.build(timer: zeroNurse, logs: [], day: day, nowMs: nowMs)
        XCTAssertEqual(zeroRhythm.leftFraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(zeroRhythm.todayFeedIndex, 1)
        XCTAssertNil(zeroRhythm.previousFeedSeconds)

        // Active sleep timer started at 08:30 (2h awake after 06:30), currently 09:30 with 5m paused
        let sleepTimer = RunningTimer(type: LogType.sleep, start: t(19, 8, 30), pausedTotal: 5 * 60_000)
        let sleepRhythm = CareSessionRhythm.build(timer: sleepTimer, logs: logs, day: day, nowMs: t(19, 9, 30))
        // 6.5h (overnight portion today) + 55m (current active nap) = 7h 25m
        XCTAssertEqual(sleepRhythm.todaySleepSeconds, 6.5 * 3600 + 55 * 60, accuracy: 1.0)
        XCTAssertEqual(sleepRhythm.awakeBeforeSleepSeconds ?? 0, 2 * 3600, accuracy: 1.0)

        // Stale prior sleep > 16h earlier should not report awake-before gap
        let staleSleep = RunningTimer(type: LogType.sleep, start: t(20, 12, 0))
        let staleRhythm = CareSessionRhythm.build(timer: staleSleep, logs: logs, day: Day(y: 2026, m: 10, d: 20), nowMs: t(20, 12, 30))
        XCTAssertNil(staleRhythm.awakeBeforeSleepSeconds)
    }

    func testAtelierDockMetricsComputes24hArcsAndFeedPips() {
        let day = Day(y: 2026, m: 10, d: 19)
        let logs = [
            // Overnight sleep 22:00 yesterday -> 06:30 today (should clip to 0.0 ... 6.5/24)
            LogEntry(type: LogType.sleep, start: t(18, 22, 0), end: t(19, 6, 30)),
            // Nap 12:00 -> 13:30 today (0.50 ... 13.5/24)
            LogEntry(type: LogType.sleep, start: t(19, 12, 0), end: t(19, 13, 30)),
            // Feeds at 08:00 and 18:00 today
            LogEntry(type: LogType.nurse, start: t(19, 8, 0), end: t(19, 8, 15), side: "l"),
            LogEntry(type: LogType.bottle, start: t(19, 18, 0), amount: 120),
        ]

        let slices = AtelierDockMetrics.sleepSlices(in: logs, on: day)
        XCTAssertEqual(slices.count, 2)
        XCTAssertEqual(slices[0].startFrac, 0.0, accuracy: 0.001)
        XCTAssertEqual(slices[0].endFrac, 6.5 / 24.0, accuracy: 0.002)
        XCTAssertEqual(slices[1].startFrac, 0.5, accuracy: 0.002)
        XCTAssertEqual(slices[1].endFrac, 13.5 / 24.0, accuracy: 0.002)

        let pips = AtelierDockMetrics.feedFractions(in: logs, on: day)
        XCTAssertEqual(pips.count, 2)
        XCTAssertEqual(pips[0], 8.0 / 24.0, accuracy: 0.002)
        XCTAssertEqual(pips[1], 18.0 / 24.0, accuracy: 0.002)

        XCTAssertTrue(AtelierDockMetrics.sleepSlices(in: [], on: day).isEmpty)
        XCTAssertTrue(AtelierDockMetrics.feedFractions(in: [], on: day).isEmpty)
    }

    func testStoryTheaterActsAndMonthClamping() {
        defer { L10n.overrideEnglish = nil }

        XCTAssertEqual(StoryTheaterAct.allCases.count, 3)
        XCTAssertEqual(StoryTheaterAct.clampedMonth(-4), 0)
        XCTAssertEqual(StoryTheaterAct.clampedMonth(12), 12)
        XCTAssertEqual(StoryTheaterAct.clampedMonth(50), 36)

        XCTAssertEqual(StoryTheaterAct.land(for: 0), .meadow)
        XCTAssertEqual(StoryTheaterAct.land(for: 6), .meadow)
        XCTAssertEqual(StoryTheaterAct.land(for: 18), .forest)
        XCTAssertEqual(StoryTheaterAct.land(for: 36), .river)

        L10n.overrideEnglish = false
        XCTAssertTrue(StoryTheaterAct.stageCaption(for: .grow, month: 6).contains("草地"))
        XCTAssertFalse(StoryTheaterAct.lamp.title.isEmpty)

        L10n.overrideEnglish = true
        XCTAssertTrue(StoryTheaterAct.stageCaption(for: .grow, month: 18).contains("Forest Hills"))
        XCTAssertEqual(StoryTheaterAct.explore.title, "Explore")
    }

    func testCareCompanionPoseCouplesTimerAndSoundscape() {
        let leftPose = CareCompanionPose.resolve(type: LogType.nurse, side: "l", paused: false, soundscapePlaying: false, lamp: false)
        XCTAssertLessThan(leftPose.look.x, 0)
        XCTAssertLessThan(leftPose.haloBiasX, 0)
        XCTAssertFalse(leftPose.acousticRings)

        let rightPose = CareCompanionPose.resolve(type: LogType.nurse, side: "r", paused: false, soundscapePlaying: true, lamp: true)
        XCTAssertGreaterThan(rightPose.look.x, 0)
        XCTAssertGreaterThan(rightPose.haloBiasX, 0)
        XCTAssertTrue(rightPose.acousticRings)
        XCTAssertGreaterThan(rightPose.lampGlow, leftPose.lampGlow)

        let pausedNurse = CareCompanionPose.resolve(type: LogType.nurse, side: "l", paused: true, soundscapePlaying: false, lamp: false)
        XCTAssertEqual(pausedNurse.haloBiasX, 0)
        XCTAssertNotNil(pausedNurse.lid)

        let sleepPose = CareCompanionPose.resolve(type: LogType.sleep, side: nil, paused: false, soundscapePlaying: true, lamp: true)
        XCTAssertEqual(sleepPose.mood, .sleep)
        XCTAssertTrue(sleepPose.acousticRings)
    }

    func testCareEntryHelpersSolidSuggestionsTimeShiftAndTempStatus() {
        defer { L10n.overrideEnglish = nil }
        L10n.overrideEnglish = false

        let records: [String: FoodRecord] = [
            "pumpkin": FoodRecord(foodId: "pumpkin", firstTastedEpochDay: 20_000, reaction: .tasted, times: 2),
            "avocado": FoodRecord(foodId: "avocado", firstTastedEpochDay: 20_005, reaction: .loved, times: 3),
            "banana": FoodRecord(foodId: "banana", firstTastedEpochDay: 20_002, reaction: .tryAgain, times: 1),
        ]
        let chips = CareEntryHelpers.solidChips(from: records, staples: ["米粉", "南瓜", "蔬菜泥"])
        // Loved food appears first, no duplicate "南瓜", staples remain available
        XCTAssertEqual(chips.first, "牛油果")
        XCTAssertEqual(chips.filter { $0 == "南瓜" }.count, 1)
        XCTAssertTrue(chips.contains("米粉"))

        // Time shifting preserves timed duration and clamps end <= nowMs
        let nowMs = 1_700_000_000_000.0
        let startMs = nowMs - 25 * 60_000
        let endMs = nowMs - 10 * 60_000
        let back = CareEntryHelpers.shiftStart(startMs: startMs, endMs: endMs, byMinutes: -15, nowMs: nowMs)
        XCTAssertEqual(back.start, startMs - 15 * 60_000, accuracy: 0.1)
        XCTAssertEqual(back.end! - back.start, 15 * 60_000, accuracy: 0.1)

        let forward = CareEntryHelpers.shiftStart(startMs: startMs, endMs: endMs, byMinutes: 20, nowMs: nowMs)
        XCTAssertEqual(forward.end!, nowMs, accuracy: 0.1)
        XCTAssertGreaterThanOrEqual(forward.end! - forward.start, 60_000)

        // Temperature status bands
        XCTAssertFalse(CareEntryHelpers.temperatureStatus(tenthsC: 368).isFever)
        XCTAssertFalse(CareEntryHelpers.temperatureStatus(tenthsC: 376).isFever)
        XCTAssertTrue(CareEntryHelpers.temperatureStatus(tenthsC: 380).isFever)
    }

    @MainActor
    func testLivingBookPhaseClockAndCatalogPhase1() throws {
        // 1. Verify 5-phase OpenMotion temporal clock over [0, 1] and out-of-range clamping
        let sStart = LivingMotionClock.sample(u: -0.2)
        XCTAssertEqual(sStart.raw, 0.0, accuracy: 0.001)
        XCTAssertEqual(sStart.anticipation, 0.0, accuracy: 0.001)
        XCTAssertEqual(sStart.action, 0.0, accuracy: 0.001)
        XCTAssertFalse(sStart.isContactWindow)

        let sAnt = LivingMotionClock.sample(u: 0.08)
        XCTAssertGreaterThan(sAnt.anticipation, 0.0)
        XCTAssertLessThan(sAnt.anticipation, 1.0)
        XCTAssertEqual(sAnt.action, 0.0, accuracy: 0.001)

        let sAct = LivingMotionClock.sample(u: 0.31)
        XCTAssertEqual(sAct.anticipation, 1.0, accuracy: 0.001)
        XCTAssertGreaterThan(sAct.action, 0.0)
        XCTAssertLessThan(sAct.action, 1.0)
        XCTAssertEqual(sAct.contact, 0.0, accuracy: 0.001)

        let sContact = LivingMotionClock.sample(u: 0.52)
        XCTAssertTrue(sContact.isContactWindow)
        XCTAssertEqual(sContact.action, 1.0, accuracy: 0.001)
        XCTAssertGreaterThan(sContact.contact, 0.1)
        XCTAssertEqual(sContact.followThrough, 0.0, accuracy: 0.001)

        let sFollow = LivingMotionClock.sample(u: 0.70)
        XCTAssertFalse(sFollow.isContactWindow)
        XCTAssertEqual(sFollow.contact, 0.0, accuracy: 0.001)
        XCTAssertGreaterThan(sFollow.followThrough, 0.0)
        XCTAssertLessThan(sFollow.followThrough, 1.0)

        let sHold = LivingMotionClock.sample(u: 0.90)
        XCTAssertEqual(sHold.followThrough, 1.0, accuracy: 0.001)
        XCTAssertGreaterThan(sHold.hold, 0.0)

        let sEnd = LivingMotionClock.sample(u: 1.5)
        XCTAssertEqual(sEnd.raw, 1.0, accuracy: 0.001)
        XCTAssertEqual(sEnd.hold, 1.0, accuracy: 0.001)

        // 2. Verify full catalog covers all 46 authoritative activities (N01–N06, A01–A40) with exact step counts
        let content = try Content.load()
        let allAuthoritativeCodes = content.activities.map(\.code).sorted()
        XCTAssertEqual(LivingBookCatalog.supportedCodes, allAuthoritativeCodes)
        XCTAssertEqual(LivingBookCatalog.supportedCodes.count, 46)
        for play in content.activities {
            XCTAssertTrue(LivingBookCatalog.hasScript(for: play.code), "Missing LivingBook script for \(play.code)")
            let script = try XCTUnwrap(LivingBookCatalog.script(for: play.code))
            XCTAssertEqual(script.steps.count, play.steps.count, "Step count mismatch for \(play.code)")
            for (idx, step) in script.steps.enumerated() {
                XCTAssertEqual(step.stepIndex, idx)
                XCTAssertGreaterThan(step.posterPhase, 0.0)
                XCTAssertLessThan(step.posterPhase, 1.0)
                XCTAssertGreaterThan(step.duration, 0.5)
            }
            XCTAssertEqual(LivingBookCatalog.stepScript(for: play.code, stepIndex: -5)?.stepIndex, 0)
            XCTAssertEqual(LivingBookCatalog.stepScript(for: play.code, stepIndex: 99)?.stepIndex, script.steps.count - 1)
        }

        // 2b. Verify every LivingPropKind is covered by at least one activity and renders deterministically in 3D & 2D
        let usedProps = Set(LivingBookCatalog.scriptsByCode.values.flatMap { $0.steps.map(\.prop) })
        for kind in LivingPropKind.allCases {
            XCTAssertTrue(usedProps.contains(kind), "Unused LivingPropKind: \(kind)")
            let sampleStep = LivingStepScript(
                stepIndex: 0,
                phrase: kind == .peekCloth ? .peekReveal : (kind == .chunkyBlocks ? .tumbleCheer : .offerArc),
                lead: .together,
                prop: kind,
                secondaryProp: nil,
                posterPhase: 0.56,
                duration: 3.4,
                audioAnchor: .woodTap,
                mossAnchorX: 0.27,
                ottoAnchorX: 0.74,
                lampTargetX: 0.50,
                lampTargetY: 0.58
            )
            let propScript = LivingActivityScript(code: "PROP_\(kind.rawValue)", backdrop: .cozyCorner, steps: [sampleStep])
            for (dark, flat) in [(false, false), (true, true)] {
                let stage = LivingBookStage(
                    script: propScript,
                    stepIndex: 0,
                    companion: .moss,
                    dark: dark,
                    accent: Crayon.teal,
                    posterPhase: 0.56,
                    interactive: false,
                    forceFlat: flat
                )
                .frame(width: 240, height: 180)
                let propRenderer = ImageRenderer(content: stage)
                propRenderer.scale = 1.0
                XCTAssertNotNil(propRenderer.uiImage, "Failed rendering prop \(kind) dark=\(dark) flat=\(flat)")
            }
        }

        // 3. Verify LampLightRig bead coordinates stay finite and track Otto's lean in 3D & 2D
        let center = CGPoint(x: 240, y: 120)
        let bead3DIdle = LampLightRig.beadWorldPosition(ottoCenter: center, ottoSize: 120, ottoState: "idle", leanDegrees: 0, flat: false)
        let bead3DLean = LampLightRig.beadWorldPosition(ottoCenter: center, ottoSize: 120, ottoState: "idle", leanDegrees: -8, flat: false)
        XCTAssertLessThan(bead3DLean.x, bead3DIdle.x)
        let bead2D = LampLightRig.beadWorldPosition(ottoCenter: center, ottoSize: 120, ottoState: "idle", leanDegrees: -4, flat: true)
        XCTAssertTrue(bead2D.x.isFinite && bead2D.y.isFinite)

        // 4. Verify choreography differentiation across steps (A12 adult vs child lead, A19 tumbleCheer hop)
        let a12Step0 = try XCTUnwrap(LivingBookCatalog.stepScript(for: "A12", stepIndex: 0))
        let a12Step2 = try XCTUnwrap(LivingBookCatalog.stepScript(for: "A12", stepIndex: 2))
        XCTAssertEqual(a12Step0.lead, .adult)
        XCTAssertEqual(a12Step2.lead, .child)

        let a19Step2 = try XCTUnwrap(LivingBookCatalog.stepScript(for: "A19", stepIndex: 2))
        let a19Actors = a19Step2.actors(at: sContact, dark: false)
        XCTAssertEqual(a19Actors.moss.mood, .happy)
        XCTAssertTrue(a19Actors.moss.hopping)
        XCTAssertEqual(a19Actors.otto.mood, .happy)

        // 5. Verify deterministic posterPhase snapshot rendering via ImageRenderer
        let a19Script = try XCTUnwrap(LivingBookCatalog.script(for: "A19"))
        let view = LivingBookStage(
            script: a19Script,
            stepIndex: 1,
            companion: .moss,
            dark: false,
            accent: Crayon.cherry,
            posterPhase: 0.56,
            interactive: false
        )
        .frame(width: 320, height: 240)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        let img = renderer.uiImage
        XCTAssertNotNil(img)
        XCTAssertGreaterThan(img?.size.width ?? 0, 200)
    }

    @MainActor
    func testLivingMonthCoverCatalogAll37MonthsAndRender() {
        let scripts = LivingMonthCoverCatalog.allScripts
        XCTAssertEqual(scripts.count, 37)
        XCTAssertEqual(scripts.map(\.month), Array(0...36))

        var usedProps: Set<MonthMilestoneProp> = []
        for idx in scripts.indices {
            let s = scripts[idx]
            if s.month < 12 {
                XCTAssertEqual(s.land, .meadow)
            } else if s.month < 24 {
                XCTAssertEqual(s.land, .woodland)
            } else {
                XCTAssertEqual(s.land, .stream)
            }
            XCTAssertEqual(s.growthStage, GrowingChild.stage(s.month))
            if idx > 0 {
                let prev = scripts[idx - 1]
                XCTAssertGreaterThanOrEqual(s.growthStage, prev.growthStage)
                XCTAssertGreaterThan(s.mossScale, prev.mossScale)
                XCTAssertFalse(s.prop == prev.prop && s.secondaryProp == prev.secondaryProp, "Adjacent cover prop pair repeated at month \(s.month)")
            }
            usedProps.insert(s.prop)
        }
        for prop in MonthMilestoneProp.allCases {
            XCTAssertTrue(usedProps.contains(prop), "Unused MonthMilestoneProp: \(prop)")
        }

        // Clamping safety
        XCTAssertEqual(LivingMonthCoverCatalog.script(for: -4).month, 0)
        XCTAssertEqual(LivingMonthCoverCatalog.script(for: 99).month, 36)

        // Deterministic ImageRenderer verification across all 3 lands, 3D/2D, and light/dark modes
        for m in [0, 6, 12, 18, 24, 36] {
            for (dark, flat) in [(false, false), (true, true)] {
                let stage = LivingMonthCoverStage(
                    month: m,
                    dark: dark,
                    festive: m == 12 || m == 24 || m == 36,
                    posterPhase: LivingMonthCoverCatalog.script(for: m).posterPhase,
                    interactive: false,
                    compact: false,
                    forceFlat: flat
                )
                .frame(width: 240, height: 180)
                let renderer = ImageRenderer(content: stage)
                renderer.scale = 1.0
                XCTAssertNotNil(renderer.uiImage, "Failed rendering living cover month=\(m) dark=\(dark) flat=\(flat)")
            }
        }
    }

    @MainActor
    func testFirstsCharmMotifStudioMetricsAndPrintPoster() {
        // Every built-in Firsts.Kind maps cleanly to a crafted motif (not falling back unintentionally)
        XCTAssertEqual(Firsts.all.count, 29)
        for kind in Firsts.all {
            let motif = FirstCharmMotif.of(key: kind.id)
            XCTAssertNotEqual(motif, .starCharm, "Built-in kind \(kind.id) should have a bespoke charm motif")
        }
        // Every custom icon key maps cleanly to its corresponding motif
        for (sym, _) in Firsts.customIcons {
            let motif = FirstCharmMotif.of(key: "icon:" + sym)
            if sym != "star.fill" {
                XCTAssertNotEqual(motif, .starCharm, "Custom icon \(sym) should resolve to its dedicated motif")
            } else {
                XCTAssertEqual(motif, .starCharm)
            }
        }

        // Stage suggestion filtering excludes already recorded keys & matching titles
        let birth = Day(y: 2026, m: 4, d: 19)
        let logged = [
            First(at: birth.plus(days: 40).date.timeIntervalSince1970 * 1000, key: "smile", title: "第一次笑"),
            First(at: birth.plus(days: 120).date.timeIntervalSince1970 * 1000, key: nil, title: "翻身"),
        ]
        let suggestions = FirstsStudioMetrics.suggestedCharms(for: logged, babyMonth: 6, limit: 6)
        XCTAssertEqual(suggestions.count, 6)
        XCTAssertFalse(suggestions.contains { $0.id == "smile" || $0.id == "roll" })

        // Photo entries helper & deterministic FirstsPrintPoster render
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let sampleImg = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 80), format: fmt).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 80, height: 80))
        }
        let photoEntries = FirstsStudioMetrics.photoEntries(in: logged) { id in
            id == logged[0].id ? sampleImg : nil
        }
        XCTAssertEqual(photoEntries.count, 1)
        XCTAssertEqual(photoEntries.first?.first.id, logged[0].id)

        let poster = FirstsPrintPoster(
            babyName: "小满",
            ageText: "6 个月",
            birth: birth,
            firsts: logged,
            photos: [logged[0].id: sampleImg]
        )
        let renderer = ImageRenderer(content: poster)
        renderer.scale = 2.0
        let rendered = renderer.uiImage
        XCTAssertNotNil(rendered)
        XCTAssertEqual(rendered?.size.width ?? 0, 360, accuracy: 2)
    }

    @MainActor
    func testRound18BespokeBatchAScenesAndDualRenderers() throws {
        let expectedBatchACodes: Set<String> = ["N01", "N02", "N03", "N04", "N05", "N06", "A01", "A02", "A03", "A04"]
        XCTAssertTrue(BespokeActivitySceneRegistry.registeredCodes.isSuperset(of: expectedBatchACodes))

        let content = try Content.load()
        var cameraGrammars: Set<String> = []

        for id in BespokeActivityID.allCases {
            let meta = BespokeActivitySceneRegistry.metadata(for: id)
            cameraGrammars.insert(meta.cameraGrammar)
            let play = try XCTUnwrap(content.play(id.code), "Missing play for \(id.code)")
            let expectedSteps = play.steps.count
            XCTAssertEqual(meta.durations.count, expectedSteps, "Durations count mismatch for \(id.code)")
            XCTAssertEqual(meta.posterPhases.count, expectedSteps, "PosterPhases count mismatch for \(id.code)")
            XCTAssertEqual(meta.audioAnchors.count, expectedSteps, "AudioAnchors count mismatch for \(id.code)")

            if expectedBatchACodes.contains(id.code) {
                let script = try XCTUnwrap(LivingBookCatalog.script(for: id.code))
                for (dark, flat) in [(false, false), (true, false), (false, true), (true, true)] {
                    let stage = LivingBookStage(
                        script: script,
                        stepIndex: 0,
                        companion: .moss,
                        dark: dark,
                        accent: Crayon.teal,
                        posterPhase: meta.posterPhases.first ?? 0.56,
                        interactive: false,
                        forceFlat: flat
                    )
                    .frame(width: 280, height: 210)
                    let renderer = ImageRenderer(content: stage)
                    renderer.scale = 1.0
                    let img = renderer.uiImage
                    XCTAssertNotNil(img, "ImageRenderer returned nil for \(id.code) dark=\(dark) flat=\(flat)")
                    XCTAssertGreaterThan(img?.size.width ?? 0, 100)
                }
            }
        }

        XCTAssertEqual(cameraGrammars.count, BespokeActivityID.allCases.count, "Each bespoke scene must own a unique cameraGrammar")
        XCTAssertFalse(Firsts.customIconLabel("star.fill").isEmpty)

        // Month 6 flagship showcase cover renders cleanly in all 4 modalities (3D Day, 3D Lamp, 2D Day, 2D Lamp)
        for (dark, flat) in [(false, false), (true, false), (false, true), (true, true)] {
            let cover = LivingMonthCoverStage(
                month: 6,
                dark: dark,
                posterPhase: 0.56,
                interactive: false,
                compact: false,
                forceFlat: flat
            )
            .frame(width: 320, height: 240)
            let renderer = ImageRenderer(content: cover)
            renderer.scale = 1.0
            let img = renderer.uiImage
            XCTAssertNotNil(img, "Month 6 showcase cover failed dark=\(dark) flat=\(flat)")
            XCTAssertGreaterThan(img?.size.width ?? 0, 100)
        }
    }

    @MainActor
    func testRound19FourTabArchitectureSourcesAndHealthRegions() throws {
        let content = try Content.load()

        // 1. SourceCitationClassifier extracts clean hostnames (no scheme) & org badges across all sources
        XCTAssertGreaterThanOrEqual(content.sources.count, 35)
        var categoriesSeen: Set<SourceCategory> = []
        for (idx, src) in content.sources.enumerated() {
            let cat = SourceCitationClassifier.category(for: src.org)
            categoriesSeen.insert(cat)
            XCTAssertFalse(SourceCitationClassifier.orgBadge(for: src.org).isEmpty)
            if let host = SourceCitationClassifier.displayHost(from: src.url) {
                XCTAssertFalse(host.contains("http://"))
                XCTAssertFalse(host.contains("https://"))
                XCTAssertFalse(host.hasPrefix("www."))
            }
            let formatted = SourceCitationClassifier.formattedCitation(index: idx + 1, source: src)
            XCTAssertTrue(formatted.hasPrefix("[\(idx + 1)]"))
        }
        XCTAssertGreaterThanOrEqual(categoriesSeen.count, 3)

        // 2. Regional health schedule rules cover US / UK / AU while preserving CN authoritative baseline
        for region in [HealthRegion.us, .uk, .au] {
            let m12 = HealthRegion.schedule(for: region, month: 12)
            XCTAssertFalse(m12.isEmpty, "Missing 12-month schedule for \(region.rawValue)")
            XCTAssertFalse(region.authorityHeadline.isEmpty)
            XCTAssertFalse(region.scopeNote.isEmpty)
        }
        XCTAssertTrue(HealthRegion.schedule(for: .uk, month: 6).isEmpty, "UK NHS has no routine 6-month visit/vaccine slot")
        XCTAssertEqual(HealthRegion.defaultRegion(isEnglish: false, locale: Locale(identifier: "zh_CN")), .cn)
        XCTAssertEqual(HealthRegion.defaultRegion(isEnglish: true, locale: Locale(identifier: "en_GB")), .uk)
        XCTAssertEqual(HealthRegion.defaultRegion(isEnglish: true, locale: Locale(identifier: "en_AU")), .au)
        XCTAssertEqual(HealthRegion.defaultRegion(isEnglish: true, locale: Locale(identifier: "en_US")), .us)

        // 3. Deterministic ImageRenderer pass on Tab 2 (LampHubView) & Editorial Docs
        let envApp = AppModel(defaults: UserDefaults(suiteName: "round19-\(UUID().uuidString)")!)
        envApp.birth = Day(y: 2026, m: 4, d: 2)
        envApp.today = Day(y: 2026, m: 10, d: 19)
        envApp.journal = true
        let envJournal = JournalStore(preview: JournalFile.Body())

        let lampView = LampHubView(path: .constant(NavigationPath()))
            .frame(width: 393, height: 820)
            .environment(envApp)
            .environment(envJournal)
        let lampImg = ImageRenderer(content: lampView).uiImage
        XCTAssertNotNil(lampImg)

        let relImg = ImageRenderer(content: ReleaseNotesView().frame(width: 393, height: 820)).uiImage
        XCTAssertNotNil(relImg)

        let docImg = ImageRenderer(content: DocView(name: "PRIVACY").frame(width: 393, height: 820)).uiImage
        XCTAssertNotNil(docImg)
    }

    @MainActor
    func testRound20BespokeBatchBScenesAndLampHub() throws {
        let expectedAll: Set<String> = [
            "N01", "N02", "N03", "N04", "N05", "N06",
            "A01", "A02", "A03", "A04",
            "A05", "A06", "A07", "A08", "A09", "A10", "A11", "A12", "A13", "A14"
        ]
        XCTAssertTrue(BespokeActivitySceneRegistry.registeredCodes.isSuperset(of: expectedAll))

        let batchBCodes: [BespokeActivityID] = [.a05, .a06, .a07, .a08, .a09, .a10, .a11, .a12, .a13, .a14]
        let allGrammars = Set(BespokeActivityID.allCases.map { BespokeActivitySceneRegistry.metadata(for: $0).cameraGrammar })
        XCTAssertEqual(allGrammars.count, BespokeActivityID.allCases.count)

        let content = try Content.load()
        for id in batchBCodes {
            let meta = BespokeActivitySceneRegistry.metadata(for: id)
            let play = try XCTUnwrap(content.play(id.code), "Missing play for \(id.code)")
            let steps = play.steps.count
            XCTAssertEqual(meta.durations.count, steps, "Durations count mismatch for \(id.code)")
            XCTAssertEqual(meta.posterPhases.count, steps, "PosterPhases count mismatch for \(id.code)")
            XCTAssertEqual(meta.audioAnchors.count, steps, "AudioAnchors count mismatch for \(id.code)")

            let script = try XCTUnwrap(LivingBookCatalog.script(for: id.code))
            for step in [0, max(0, steps - 1)] {
                for (dark, flat) in [(false, false), (true, false), (false, true), (true, true)] {
                    let stage = LivingBookStage(
                        script: script,
                        stepIndex: step,
                        companion: .moss,
                        dark: dark,
                        accent: Crayon.teal,
                        posterPhase: meta.posterPhases[step],
                        interactive: false,
                        forceFlat: flat
                    )
                    .frame(width: 280, height: 210)
                    let img = ImageRenderer(content: stage).uiImage
                    XCTAssertNotNil(img, "ImageRenderer returned nil for \(id.code) step=\(step) dark=\(dark) flat=\(flat)")
                    XCTAssertGreaterThan(img?.size.width ?? 0, 100)
                }
            }
        }

        // AX2 accessibility sizing pass on Tab 2 LampHubView
        let envApp = AppModel(defaults: UserDefaults(suiteName: "round20-\(UUID().uuidString)")!)
        envApp.birth = Day(y: 2026, m: 4, d: 2)
        envApp.today = Day(y: 2026, m: 10, d: 19)
        envApp.journal = true
        let envJournal = JournalStore(preview: JournalFile.Body())
        let lampAx2 = LampHubView(path: .constant(NavigationPath()))
            .frame(width: 393, height: 960)
            .environment(envApp)
            .environment(envJournal)
            .dynamicTypeSize(.accessibility2)
        XCTAssertNotNil(ImageRenderer(content: lampAx2).uiImage)
    }

    @MainActor
    func testRound21BespokeBatchCScenesAndKeepsakeTab() throws {
        let expectedAll: Set<String> = [
            "N01", "N02", "N03", "N04", "N05", "N06",
            "A01", "A02", "A03", "A04",
            "A05", "A06", "A07", "A08", "A09", "A10", "A11", "A12", "A13", "A14",
            "A15", "A16", "A17", "A18", "A19", "A20", "A21", "A22", "A23", "A24"
        ]
        XCTAssertTrue(BespokeActivitySceneRegistry.registeredCodes.isSuperset(of: expectedAll))
        XCTAssertGreaterThanOrEqual(BespokeActivityID.allCases.count, 30)

        let allGrammars = Set(BespokeActivityID.allCases.map { BespokeActivitySceneRegistry.metadata(for: $0).cameraGrammar })
        XCTAssertEqual(allGrammars.count, BespokeActivityID.allCases.count, "Each bespoke scene must own a unique cameraGrammar")

        let batchCCodes: [BespokeActivityID] = [.a15, .a16, .a17, .a18, .a19, .a20, .a21, .a22, .a23, .a24]
        let content = try Content.load()
        for id in batchCCodes {
            let meta = BespokeActivitySceneRegistry.metadata(for: id)
            let play = try XCTUnwrap(content.play(id.code), "Missing play for \(id.code)")
            let steps = play.steps.count
            XCTAssertEqual(meta.durations.count, steps, "Durations count mismatch for \(id.code)")
            XCTAssertEqual(meta.posterPhases.count, steps, "PosterPhases count mismatch for \(id.code)")
            XCTAssertEqual(meta.audioAnchors.count, steps, "AudioAnchors count mismatch for \(id.code)")

            let script = try XCTUnwrap(LivingBookCatalog.script(for: id.code))
            for step in [0, max(0, steps - 1)] {
                for (dark, flat) in [(false, false), (true, false), (false, true), (true, true)] {
                    let stage = LivingBookStage(
                        script: script,
                        stepIndex: step,
                        companion: .moss,
                        dark: dark,
                        accent: Crayon.teal,
                        posterPhase: meta.posterPhases[step],
                        interactive: false,
                        forceFlat: flat
                    )
                    .frame(width: 280, height: 210)
                    let img = ImageRenderer(content: stage).uiImage
                    XCTAssertNotNil(img, "ImageRenderer returned nil for \(id.code) step=\(step) dark=\(dark) flat=\(flat)")
                    XCTAssertGreaterThan(img?.size.width ?? 0, 100)
                }
            }
        }

        // Pure JourneyKeepsakeMetrics validation
        XCTAssertTrue(JourneyKeepsakeMetrics.normalizedWeights(from: []).isEmpty)
        XCTAssertNil(JourneyKeepsakeMetrics.latestWeightText(from: []))

        let samples = [
            Measure(at: 1000, weightG: 3400),
            Measure(at: 2000, weightG: 5200),
            Measure(at: 3000, weightG: 7400)
        ]
        let normed = JourneyKeepsakeMetrics.normalizedWeights(from: samples)
        XCTAssertEqual(normed.count, 3)
        XCTAssertEqual(normed.first ?? -1, 0.15, accuracy: 0.001)
        XCTAssertEqual(normed.last ?? -1, 0.85, accuracy: 0.001)
        XCTAssertEqual(JourneyKeepsakeMetrics.latestWeightText(from: samples), "7.4 kg")

        let pMeadow = JourneyKeepsakeMetrics.landProgress(land: .meadow, babyMonth: 6, hasBirth: true)
        XCTAssertEqual(pMeadow.lived, 7)
        XCTAssertEqual(pMeadow.total, 12)
        let pRiver = JourneyKeepsakeMetrics.landProgress(land: .river, babyMonth: 6, hasBirth: true)
        XCTAssertEqual(pRiver.lived, 0)
        XCTAssertEqual(pRiver.total, 13)

        // Render Tab 3 (Day, Night, AX2), Tab 4 (AX2), and Privacy DocView (AX2) cleanly
        let envApp = AppModel(defaults: UserDefaults(suiteName: "round21-\(UUID().uuidString)")!)
        envApp.birth = Day(y: 2026, m: 4, d: 2)
        envApp.today = Day(y: 2026, m: 10, d: 19)
        envApp.journal = true
        var body = JournalFile.Body()
        body.measures = samples
        body.firsts = [First(at: 2000, key: "smile", title: "第一次微笑")]
        let envJournal = JournalStore(preview: body)

        let tab3Day = JourneyHubView(isRootTab: true)
            .frame(width: 393, height: 960)
            .environment(envApp)
            .environment(envJournal)
        XCTAssertNotNil(ImageRenderer(content: tab3Day).uiImage)

        let tab3Night = JourneyHubView(isRootTab: true)
            .frame(width: 393, height: 960)
            .lamp(true)
            .environment(\.colorScheme, .dark)
            .environment(envApp)
            .environment(envJournal)
        XCTAssertNotNil(ImageRenderer(content: tab3Night).uiImage)

        let tab3Ax2 = JourneyHubView(isRootTab: true)
            .frame(width: 393, height: 1120)
            .environment(envApp)
            .environment(envJournal)
            .dynamicTypeSize(.accessibility2)
        XCTAssertNotNil(ImageRenderer(content: tab3Ax2).uiImage)

        let tab4Ax2 = YouView(path: .constant(NavigationPath()))
            .frame(width: 393, height: 1120)
            .environment(envApp)
            .environment(envJournal)
            .dynamicTypeSize(.accessibility2)
        XCTAssertNotNil(ImageRenderer(content: tab4Ax2).uiImage)

        let docAx2 = DocView(name: "PRIVACY")
            .frame(width: 393, height: 960)
            .dynamicTypeSize(.accessibility2)
        XCTAssertNotNil(ImageRenderer(content: docAx2).uiImage)
    }

    @MainActor
    func testRound22SingleSourceOfTruthIAAndScenePhysics() async throws {
        // 1. Strict 4-tab disjoint feature ownership (0 retired keys, 0 cross-tab duplicates)
        XCTAssertEqual(CanonicalDestination.ownedFeatureKeysByTab.count, 4)
        let retiredKeys: Set<String> = ["about", "growthBook", "journalSplit", "fullJournal"]
        var unionKeys = Set<String>()
        for tab in AppTab.allCases {
            let owned = CanonicalDestination.ownedFeatureKeysByTab[tab] ?? []
            XCTAssertFalse(owned.isEmpty, "Tab \(tab) must own canonical features")
            XCTAssertTrue(owned.isDisjoint(with: retiredKeys), "Tab \(tab) must not contain retired keys")
            XCTAssertTrue(unionKeys.isDisjoint(with: owned), "Duplicate feature ownership detected on \(tab)")
            unionKeys.formUnion(owned)
        }
        XCTAssertEqual(CanonicalDestination.owner(of: .bedsideLamp), .lamp)
        XCTAssertEqual(CanonicalDestination.owner(of: .storybook), .keepsakes)
        XCTAssertEqual(CanonicalDestination.owner(of: .toybox(.xylophone)), .explore)
        XCTAssertEqual(CanonicalDestination.owner(of: .stats), .lamp)
        XCTAssertEqual(CanonicalDestination.owner(of: .capsules), .keepsakes)
        XCTAssertEqual(CanonicalDestination.owner(of: .story), .studio)

        // 2. AppRouter Single-Source-of-Truth destination transitions
        let router = AppRouter()
        router.open(.toybox(.xylophone))
        XCTAssertEqual(router.selectedTab, AppTab.explore.rawValue)
        XCTAssertFalse(router.explorePath.isEmpty)

        router.open(.bedsideLamp)
        XCTAssertEqual(router.selectedTab, AppTab.lamp.rawValue)
        XCTAssertTrue(router.showingBedsideLamp)
        router.showingBedsideLamp = false

        router.open(.stats)
        XCTAssertEqual(router.selectedTab, AppTab.lamp.rawValue)
        XCTAssertFalse(router.lampPath.isEmpty)

        router.open(.storybook)
        XCTAssertEqual(router.selectedTab, AppTab.keepsakes.rawValue)
        XCTAssertTrue(router.showingStorybook)
        router.showingStorybook = false

        router.open(.capsules)
        XCTAssertEqual(router.selectedTab, AppTab.keepsakes.rawValue)
        XCTAssertFalse(router.keepsakesPath.isEmpty)

        router.open(.story)
        XCTAssertEqual(router.selectedTab, AppTab.studio.rawValue)
        for _ in 0..<60 where router.studioPath.isEmpty {
            try? await Task.sleep(for: .milliseconds(25))
        }
        XCTAssertFalse(router.studioPath.isEmpty)

        let beforeToken = router.expandLampLedgerToken
        router.open(.lampLedger)
        XCTAssertEqual(router.selectedTab, AppTab.lamp.rawValue)
        XCTAssertEqual(router.expandLampLedgerToken, beforeToken + 1)

        // 3. All 30 bespoke scenes have valid dynamic Otto bead & prop target normalized anchors
        let rightSideOttoScenes: Set<BespokeActivityID> = [.n04, .a04, .a11, .a19, .a24]
        let sampleSize = CGSize(width: 280, height: 210)
        for id in BespokeActivityID.allCases {
            let meta = BespokeActivitySceneRegistry.metadata(for: id)
            XCTAssertTrue((0.05...0.95).contains(meta.ottoBeadNormalized.x), "\(id.code) bead x out of range")
            XCTAssertTrue((0.05...0.95).contains(meta.ottoBeadNormalized.y), "\(id.code) bead y out of range")
            XCTAssertTrue((0.05...0.95).contains(meta.propTargetNormalized.x), "\(id.code) target x out of range")
            XCTAssertTrue((0.05...0.95).contains(meta.propTargetNormalized.y), "\(id.code) target y out of range")
            if rightSideOttoScenes.contains(id) {
                XCTAssertGreaterThan(meta.ottoBeadNormalized.x, 0.60, "\(id.code) Otto placed on right must emit bead lighting from right")
            }
            let anchors = BespokeActivitySceneRegistry.lightAnchors(for: id, step: 0, stageSize: sampleSize)
            XCTAssertTrue(anchors.bead.x.isFinite && anchors.bead.y.isFinite)
            XCTAssertTrue(anchors.target.x.isFinite && anchors.target.y.isFinite)
            XCTAssertGreaterThanOrEqual(anchors.target.x, 0)
            XCTAssertLessThanOrEqual(anchors.target.x, sampleSize.width)
        }

        // 4. Render refactored IA destinations + unified StorybookView (with/without birth)
        let envApp = AppModel(defaults: UserDefaults(suiteName: "round22-\(UUID().uuidString)")!)
        envApp.birth = Day(y: 2026, m: 4, d: 2)
        envApp.today = Day(y: 2026, m: 10, d: 19)
        envApp.journal = true
        let envJournal = JournalStore(preview: JournalFile.Body())

        for view in [
            AnyView(TodayView(path: .constant(NavigationPath()))),
            AnyView(LampHubView(path: .constant(NavigationPath()))),
            AnyView(JourneyHubView(isRootTab: true)),
            AnyView(YouView(path: .constant(NavigationPath()))),
            AnyView(StorybookView())
        ] {
            let img = ImageRenderer(
                content: view
                    .frame(width: 393, height: 852)
                    .environment(envApp)
                    .environment(envJournal)
                    .environment(router)
            ).uiImage
            XCTAssertNotNil(img)
            XCTAssertGreaterThan(img?.size.width ?? 0, 100)
        }

        let noBirthApp = AppModel(defaults: UserDefaults(suiteName: "round22-nb-\(UUID().uuidString)")!)
        noBirthApp.birth = nil
        noBirthApp.onboarded = true
        let noBirthBook = ImageRenderer(
            content: StorybookView()
                .frame(width: 393, height: 852)
                .environment(noBirthApp)
                .environment(envJournal)
                .environment(router)
        ).uiImage
        XCTAssertNotNil(noBirthBook)
        XCTAssertGreaterThan(noBirthBook?.size.width ?? 0, 100)

        // 5. Render all 8 physically re-architected scenes in both 3D & 2D
        let content = try Content.load()
        for id: BespokeActivityID in [.n06, .a11, .a13, .a14, .a16, .a19, .a20, .a24] {
            let meta = BespokeActivitySceneRegistry.metadata(for: id)
            let script = try XCTUnwrap(LivingBookCatalog.script(for: id.code))
            XCTAssertNotNil(content.play(id.code))
            for flat in [false, true] {
                let stage = LivingBookStage(
                    script: script,
                    stepIndex: 0,
                    companion: .moss,
                    dark: false,
                    accent: Crayon.teal,
                    posterPhase: meta.posterPhases[0],
                    interactive: false,
                    forceFlat: flat
                )
                .frame(width: 280, height: 210)
                let img = ImageRenderer(content: stage).uiImage
                XCTAssertNotNil(img, "Repaired scene \(id.code) flat=\(flat) returned nil image")
                XCTAssertGreaterThan(img?.size.width ?? 0, 100)
            }
        }
    }

    @MainActor
    func testRound23ContinuousPlayScrubberAndBatchDScenes() throws {
        // 1. PlayScrubMath boundary & contact detent behavior
        let d0 = PlayScrubMath.decompose(timelinePosition: 0.0, stepCount: 3)
        XCTAssertEqual(d0.stepIndex, 0)
        XCTAssertEqual(d0.localPhase, 0.0, accuracy: 0.001)

        let dMid = PlayScrubMath.decompose(timelinePosition: 1.25, stepCount: 3)
        XCTAssertEqual(dMid.stepIndex, 1)
        XCTAssertEqual(dMid.localPhase, 0.25, accuracy: 0.001)

        let dEnd = PlayScrubMath.decompose(timelinePosition: 3.5, stepCount: 3)
        XCTAssertEqual(dEnd.stepIndex, 2)
        XCTAssertEqual(dEnd.localPhase, 1.0, accuracy: 0.001)

        XCTAssertEqual(PlayScrubMath.normalizedProgress(stepIndex: 1, localPhase: 0.5, stepCount: 3), 0.5, accuracy: 0.001)
        XCTAssertEqual(PlayScrubMath.crossedStepBoundary(from: 0.9, to: 1.1, stepCount: 3), 1)
        XCTAssertNil(PlayScrubMath.crossedStepBoundary(from: 0.2, to: 0.4, stepCount: 3))
        XCTAssertTrue(PlayScrubMath.crossedContactDetent(from: 0.45, to: 0.51))
        XCTAssertFalse(PlayScrubMath.crossedContactDetent(from: 0.10, to: 0.30))

        // 2. Registry & Batch D (>= 38 bespoke scenes)
        let expectedBatchD: Set<String> = ["A25", "A26", "A27", "A28", "A29", "A30", "A31", "A32"]
        XCTAssertTrue(BespokeActivitySceneRegistry.registeredCodes.isSuperset(of: expectedBatchD))
        XCTAssertGreaterThanOrEqual(BespokeActivityID.allCases.count, 38)
        let grammars = Set(BespokeActivityID.allCases.map { BespokeActivitySceneRegistry.metadata(for: $0).cameraGrammar })
        XCTAssertEqual(grammars.count, BespokeActivityID.allCases.count, "All bespoke scenes must own unique cameraGrammar values")

        let content = try Content.load()
        let batchDIds: [BespokeActivityID] = [.a25, .a26, .a27, .a28, .a29, .a30, .a31, .a32]
        for id in batchDIds {
            let meta = BespokeActivitySceneRegistry.metadata(for: id)
            let play = try XCTUnwrap(content.play(id.code))
            XCTAssertEqual(meta.durations.count, play.steps.count, "Durations count mismatch for \(id.code)")
            XCTAssertEqual(meta.posterPhases.count, play.steps.count, "PosterPhases count mismatch for \(id.code)")
            XCTAssertEqual(meta.audioAnchors.count, play.steps.count, "AudioAnchors count mismatch for \(id.code)")
        }

        let sampleSize = CGSize(width: 280, height: 210)
        for id in BespokeActivityID.allCases {
            let meta = BespokeActivitySceneRegistry.metadata(for: id)
            XCTAssertTrue((0.05...0.95).contains(meta.ottoBeadNormalized.x))
            XCTAssertTrue((0.05...0.95).contains(meta.ottoBeadNormalized.y))
            XCTAssertTrue((0.05...0.95).contains(meta.propTargetNormalized.x))
            XCTAssertTrue((0.05...0.95).contains(meta.propTargetNormalized.y))
            let a = BespokeActivitySceneRegistry.lightAnchors(for: id, step: 0, stageSize: sampleSize)
            XCTAssertTrue(a.bead.x.isFinite && a.bead.y.isFinite && a.target.x.isFinite && a.target.y.isFinite)
        }
        for rightID: BespokeActivityID in [.a25, .a27, .a28] {
            XCTAssertGreaterThan(BespokeActivitySceneRegistry.metadata(for: rightID).ottoBeadNormalized.x, 0.60)
        }
        let a29Step0 = BespokeActivitySceneRegistry.lightAnchors(for: .a29, step: 0, stageSize: CGSize(width: 100, height: 100))
        let a29Step3 = BespokeActivitySceneRegistry.lightAnchors(for: .a29, step: 3, stageSize: CGSize(width: 100, height: 100))
        XCTAssertLessThan(a29Step0.bead.x, 30)
        XCTAssertGreaterThan(a29Step3.bead.x, 50)

        // 3. Lean ImageRenderer pass (~20 renders): PlayView Day + AX2, MatSideCoPlayView, scrubPhase stage, Batch D 3D & 2D
        let envApp = AppModel(defaults: UserDefaults(suiteName: "round23-\(UUID().uuidString)")!)
        envApp.birth = Day(y: 2024, m: 7, d: 1)
        envApp.today = Day(y: 2026, m: 10, d: 19)
        envApp.journal = true
        let envJournal = JournalStore(preview: JournalFile.Body())
        let router = AppRouter()
        let playA28 = try XCTUnwrap(content.play("A28"))

        for sizing in [DynamicTypeSize.large, DynamicTypeSize.accessibility2] {
            let pv = PlayView(play: playA28, month: 26, initialStep: 1)
                .frame(width: 393, height: 852)
                .environment(envApp)
                .environment(envJournal)
                .environment(router)
                .dynamicTypeSize(sizing)
            XCTAssertNotNil(ImageRenderer(content: pv).uiImage)
        }

        let matView = MatSideCoPlayView(play: playA28, month: 26, companion: .moss, currentStep: .constant(1), onSelectStep: { _ in })
            .frame(width: 393, height: 852)
        XCTAssertNotNil(ImageRenderer(content: matView).uiImage)

        let scriptA28 = try XCTUnwrap(LivingBookCatalog.script(for: "A28"))
        let scrubStage = LivingBookStage(
            script: scriptA28,
            stepIndex: 1,
            companion: .moss,
            dark: false,
            accent: Crayon.teal,
            scrubPhase: 0.48,
            interactive: false,
            forceFlat: false
        )
        .frame(width: 280, height: 210)
        XCTAssertNotNil(ImageRenderer(content: scrubStage).uiImage)

        for id in batchDIds {
            let meta = BespokeActivitySceneRegistry.metadata(for: id)
            let script = try XCTUnwrap(LivingBookCatalog.script(for: id.code))
            for flat in [false, true] {
                let stage = LivingBookStage(
                    script: script,
                    stepIndex: 0,
                    companion: .moss,
                    dark: false,
                    accent: Crayon.teal,
                    posterPhase: meta.posterPhases[0],
                    interactive: false,
                    forceFlat: flat
                )
                .frame(width: 280, height: 210)
                let img = ImageRenderer(content: stage).uiImage
                XCTAssertNotNil(img, "Batch D scene \(id.code) flat=\(flat) returned nil")
                XCTAssertGreaterThan(img?.size.width ?? 0, 100)
            }
        }
    }

    @MainActor
    func testRound24ViewportFirstStudioAndFourTabs() {
        defer { L10n.overrideEnglish = nil }

        // 1. Viewport-First Studio cockpit contract & bilingual companion tags
        XCTAssertEqual(YouViewportSpec.primaryPortalCount, 4)
        XCTAssertEqual(YouViewportSpec.preferenceTileCount, 4)
        XCTAssertLessThanOrEqual(YouViewportSpec.maxSingleViewportHeight, 660)

        L10n.overrideEnglish = false
        XCTAssertEqual(YouStudioCopy.companionBadge(.moss), "爱探索")
        XCTAssertEqual(YouStudioCopy.companionBadge(.otto), "点暖灯")
        L10n.overrideEnglish = true
        XCTAssertEqual(YouStudioCopy.companionBadge(.moss), "Explorer")
        XCTAssertEqual(YouStudioCopy.companionBadge(.otto), "Lamp Keeper")
        L10n.overrideEnglish = nil

        // 2. Single-viewport 393×852 render verification across all 4 root tabs + StudioLegalSheet
        let envApp = AppModel(defaults: UserDefaults(suiteName: "round24-\(UUID().uuidString)")!)
        envApp.birth = Day(y: 2026, m: 4, d: 2)
        envApp.today = Day(y: 2026, m: 10, d: 19)
        envApp.nickname = "小满"
        envApp.journal = true
        let envJournal = JournalStore(preview: JournalFile.Body())
        let router = AppRouter()

        let rootTabs: [AnyView] = [
            AnyView(NavigationStack { TodayView(path: .constant(NavigationPath())) }),
            AnyView(NavigationStack { LampHubView(path: .constant(NavigationPath())) }),
            AnyView(NavigationStack { JourneyHubView(isRootTab: true) }),
            AnyView(NavigationStack { YouView(path: .constant(NavigationPath())) }),
            AnyView(StudioLegalSheet(dark: false))
        ]

        for view in rootTabs {
            let img = renderHostedSnapshot(
                view
                    .environment(envApp)
                    .environment(envJournal)
                    .environment(router)
            )
            XCTAssertNotNil(img.cgImage)
            XCTAssertGreaterThan(img.size.width, 100)
        }

        // 3. Night Lamp, EN & AX2 Studio variants at single-viewport width
        for (en, lamp, size) in [
            (false, true, DynamicTypeSize.large),
            (true, false, DynamicTypeSize.large),
            (false, false, DynamicTypeSize.accessibility2)
        ] {
            L10n.overrideEnglish = en
            let studio = NavigationStack { YouView(path: .constant(NavigationPath())) }
                .environment(envApp)
                .environment(envJournal)
                .environment(router)
                .environment(\.lamp, lamp)
                .dynamicTypeSize(size)
            let img = renderHostedSnapshot(studio, dark: lamp)
            XCTAssertNotNil(img.cgImage)
            XCTAssertGreaterThan(img.size.width, 100)
        }
    }

    @MainActor
    func testRound25CreativeAlchemyShadowWallPalmPatAndLanternPass() {
        defer { L10n.overrideEnglish = nil }

        // 1. Otto Shadow Wall inverse-distance optics & Moss eye tracking
        XCTAssertEqual(ShadowPuppetKind.allCases.count, 5)
        let nearLamp = ShadowWallPhysics.project(puppetNorm: CGPoint(x: 0.52, y: 0.78))
        let farWall = ShadowWallPhysics.project(puppetNorm: CGPoint(x: 0.70, y: 0.36))
        XCTAssertGreaterThan(nearLamp.shadowScale, farWall.shadowScale)
        XCTAssertGreaterThan(nearLamp.penumbraBlur, farWall.penumbraBlur)
        let leftShadow = ShadowWallPhysics.project(puppetNorm: CGPoint(x: 0.24, y: 0.50))
        let rightShadow = ShadowWallPhysics.project(puppetNorm: CGPoint(x: 0.80, y: 0.50))
        XCTAssertLessThan(leftShadow.mossLook.x, rightShadow.mossLook.x)

        // 2. Silent Palm-Pat rhythmic deceleration & tap-tempo cadence math
        XCTAssertEqual(PalmPatRhythm.intervalSeconds(bpm: 60), 1.0, accuracy: 0.001)
        let bpmStart = PalmPatRhythm.effectiveBPM(startBPM: 60, elapsedSeconds: 0, autoSlow: true)
        let bpmMid = PalmPatRhythm.effectiveBPM(startBPM: 60, elapsedSeconds: 150, autoSlow: true)
        let bpmEnd = PalmPatRhythm.effectiveBPM(startBPM: 60, elapsedSeconds: 300, autoSlow: true)
        XCTAssertEqual(bpmStart, 60.0, accuracy: 0.01)
        XCTAssertEqual(bpmMid, 54.0, accuracy: 0.01)
        XCTAssertEqual(bpmEnd, 48.0, accuracy: 0.01)
        XCTAssertNil(PalmPatRhythm.bpmFromTapTimestamps([1.0, 2.0]))
        let tappedBPM = PalmPatRhythm.bpmFromTapTimestamps([10.0, 11.2, 12.4, 13.6])
        XCTAssertEqual(tappedBPM ?? 0, 50.0, accuracy: 0.5)

        // 3. Swipe-to-Pass Lantern Handover Bezier trajectory & detent completion threshold
        let s = CGPoint(x: 40, y: 50), c = CGPoint(x: 150, y: 10), e = CGPoint(x: 260, y: 60)
        let p0 = LanternPassMath.quadBezierPoint(t: 0.0, start: s, control: c, end: e)
        let p1 = LanternPassMath.quadBezierPoint(t: 1.0, start: s, control: c, end: e)
        let pMid = LanternPassMath.quadBezierPoint(t: 0.5, start: s, control: c, end: e)
        XCTAssertEqual(p0.x, s.x, accuracy: 0.01)
        XCTAssertEqual(p1.x, e.x, accuracy: 0.01)
        XCTAssertLessThan(pMid.y, min(s.y, e.y))
        XCTAssertFalse(LanternPassMath.isPassed(0.87))
        XCTAssertTrue(LanternPassMath.isPassed(0.88))
        XCTAssertEqual(LanternPassMath.detentStep(for: 0.50), 2)

        // 4. Deterministic ImageRenderer verification of all 3 Creative Alchemy studios
        let envApp = AppModel(defaults: UserDefaults(suiteName: "round25-\(UUID().uuidString)")!)
        envApp.birth = Day(y: 2026, m: 4, d: 2)
        envApp.today = Day(y: 2026, m: 10, d: 19)
        envApp.nickname = "小满"
        envApp.journal = true
        let envJournal = JournalStore(preview: JournalFile.Body())

        for renderView in [
            AnyView(ToyboxView(initialMode: .shadows, initialShadowPuppet: .rabbit)),
            AnyView(ShadowWallStudio(dark: true, initialPuppet: .butterfly, onInteract: {})),
            AnyView(BedsideLampView(initialBrightness: 0.78, initialPalmPat: true, previewClock: envApp.today.date)),
            AnyView(HandoverSheet(day: envApp.today, previewNow: envApp.today.date, initialPassProgress: 0.92))
        ] {
            let img = renderHostedSnapshot(
                renderView
                    .environment(envApp)
                    .environment(envJournal)
            )
            XCTAssertNotNil(img.cgImage)
            XCTAssertGreaterThan(img.size.width, 100)
        }
    }

    @MainActor
    func testRound26BatchEComplete46Of46Scenes() throws {
        // 1. 46 / 46 complete bespoke coverage (N01-N06 + A01-A40) with unique cameraGrammar
        XCTAssertEqual(BespokeActivityID.allCases.count, 46)
        XCTAssertEqual(BespokeActivitySceneRegistry.registeredCodes.count, 46)
        for n in 1...6 {
            let code = String(format: "N%02d", n)
            XCTAssertTrue(BespokeActivitySceneRegistry.hasBespokeScene(for: code), "Missing bespoke scene for \(code)")
        }
        for a in 1...40 {
            let code = String(format: "A%02d", a)
            XCTAssertTrue(BespokeActivitySceneRegistry.hasBespokeScene(for: code), "Missing bespoke scene for \(code)")
        }
        let grammars = Set(BespokeActivityID.allCases.map { BespokeActivitySceneRegistry.metadata(for: $0).cameraGrammar })
        XCTAssertEqual(grammars.count, 46, "All 46 bespoke scenes must own unique cameraGrammar values")

        // 2. Batch E (A33-A40) metadata & finite light anchors
        let content = try Content.load()
        let batchEIds: [BespokeActivityID] = [.a33, .a34, .a35, .a36, .a37, .a38, .a39, .a40]
        let expectedSteps: [BespokeActivityID: Int] = [
            .a33: 3, .a34: 3, .a35: 4, .a36: 3,
            .a37: 3, .a38: 3, .a39: 3, .a40: 3
        ]
        let sampleSize = CGSize(width: 280, height: 210)
        for id in batchEIds {
            let meta = BespokeActivitySceneRegistry.metadata(for: id)
            let play = try XCTUnwrap(content.play(id.code))
            XCTAssertEqual(play.steps.count, expectedSteps[id])
            XCTAssertEqual(meta.durations.count, play.steps.count, "Durations count mismatch for \(id.code)")
            XCTAssertEqual(meta.posterPhases.count, play.steps.count, "PosterPhases count mismatch for \(id.code)")
            XCTAssertEqual(meta.audioAnchors.count, play.steps.count, "AudioAnchors count mismatch for \(id.code)")
            XCTAssertTrue((0.05...0.95).contains(meta.ottoBeadNormalized.x))
            XCTAssertTrue((0.05...0.95).contains(meta.ottoBeadNormalized.y))
            XCTAssertTrue((0.05...0.95).contains(meta.propTargetNormalized.x))
            XCTAssertTrue((0.05...0.95).contains(meta.propTargetNormalized.y))
            for step in 0..<play.steps.count {
                let anchors = BespokeActivitySceneRegistry.lightAnchors(for: id, step: step, stageSize: sampleSize)
                XCTAssertTrue(anchors.bead.x.isFinite && anchors.bead.y.isFinite && anchors.target.x.isFinite && anchors.target.y.isFinite)
            }
        }

        // 3. Dual-mode ImageRenderer verification across all Batch E scenes (3D Pixar & 2D Ghibli)
        for id in batchEIds {
            let meta = BespokeActivitySceneRegistry.metadata(for: id)
            let script = try XCTUnwrap(LivingBookCatalog.script(for: id.code))
            let midStep = min(1, max(0, meta.posterPhases.count - 1))
            for flat in [false, true] {
                let stage = LivingBookStage(
                    script: script,
                    stepIndex: midStep,
                    companion: .moss,
                    dark: false,
                    accent: Crayon.teal,
                    posterPhase: meta.posterPhases[midStep],
                    interactive: false,
                    forceFlat: flat
                )
                .frame(width: 280, height: 210)
                let img = ImageRenderer(content: stage).uiImage
                XCTAssertNotNil(img, "Batch E scene \(id.code) flat=\(flat) returned nil")
                XCTAssertGreaterThan(img?.size.width ?? 0, 100)
            }
        }
    }

    @MainActor
    func testRound27OfficialWebsiteAndCommercialMetadata() {
        XCTAssertEqual(Owner.developer, "")
        XCTAssertEqual(
            Owner.developerName,
            L10n.t("本应用 App Store 页面上显示的开发者", "the developer listed on the App Store page")
        )
        XCTAssertEqual(Owner.email, "lbuiuiysdeyzxl@yeah.net")
        XCTAssertEqual(Owner.website, "https://mossotto.pages.dev/")
        XCTAssertEqual(Owner.websiteURL?.absoluteString, "https://mossotto.pages.dev/")
        XCTAssertEqual(Owner.supportURL?.absoluteString, "https://mossotto.pages.dev/support.html")
        XCTAssertEqual(Owner.privacyURL?.absoluteString, "https://mossotto.pages.dev/privacy.html")
        XCTAssertEqual(Owner.termsURL?.absoluteString, "https://mossotto.pages.dev/terms.html")
        XCTAssertEqual(Owner.licensesURL?.absoluteString, "https://mossotto.pages.dev/licenses.html")

        let filled = Owner.fill("{{DEVELOPER}}|{{WEBSITE}}")
        XCTAssertTrue(filled.contains(Owner.developerName))
        XCTAssertTrue(filled.contains("https://mossotto.pages.dev/"))
        XCTAssertFalse(filled.contains("{{DEVELOPER}}"))
        XCTAssertFalse(filled.contains("{{WEBSITE}}"))

        let envApp = AppModel(defaults: UserDefaults(suiteName: "round27-\(UUID().uuidString)")!)
        let envJournal = JournalStore(preview: JournalFile.Body())
        let sheet = StudioLegalSheet(dark: false)
            .environment(envApp)
            .environment(envJournal)
            .environment(AppRouter())
        let img = renderHostedSnapshot(sheet, width: 393, height: 640)
        XCTAssertNotNil(img.cgImage)
        XCTAssertGreaterThan(img.size.width, 100)
    }

    @MainActor
    func testRound27Edition2P0AndWebHandover() throws {
        // 1. Circadian 3AM window boundary checks (00:00–04:59 deep night)
        let baseDay = Day(y: 2026, m: 10, d: 19).date
        func at(_ hour: Int, _ minute: Int) -> Date {
            Day.cal.date(bySettingHour: hour, minute: minute, second: 0, of: baseDay)!
        }
        XCTAssertFalse(CircadianDutyPhase.isLateNight3AM(at(20, 59)))
        XCTAssertFalse(CircadianDutyPhase.isLateNight3AM(at(21, 0)))
        XCTAssertFalse(CircadianDutyPhase.isLateNight3AM(at(23, 59)))
        XCTAssertTrue(CircadianDutyPhase.isLateNight3AM(at(0, 0)))
        XCTAssertTrue(CircadianDutyPhase.isLateNight3AM(at(3, 15)))
        XCTAssertTrue(CircadianDutyPhase.isLateNight3AM(at(4, 59)))
        XCTAssertFalse(CircadianDutyPhase.isLateNight3AM(at(5, 0)))
        XCTAssertFalse(CircadianDutyPhase.isLateNight3AM(at(6, 0)))

        // 2. Fallback round die-cut sticker & isolated FoodStickerStore lifecycle
        let sampleFormat = UIGraphicsImageRendererFormat()
        sampleFormat.scale = 1
        let sampleImg = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120), format: sampleFormat).image { ctx in
            UIColor(red: 0.92, green: 0.56, blue: 0.34, alpha: 1.0).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
        }
        let sticker = VisionSubjectCutout.makeFallbackRoundSticker(from: sampleImg, maxDimension: 128)
        XCTAssertEqual(sticker.size.width, 128, accuracy: 0.5)
        XCTAssertEqual(sticker.size.height, 128, accuracy: 0.5)

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("food-sticker-tests-\(UUID().uuidString)", isDirectory: true)
        defer { FoodStickerStore.clearAll(in: tmpDir) }
        XCTAssertEqual(FoodStickerStore.stickerCount(in: tmpDir), 0)
        XCTAssertTrue(FoodStickerStore.save(sticker, for: "pumpkin", maxDimension: 128, in: tmpDir))
        XCTAssertTrue(FoodStickerStore.exists(for: "pumpkin", in: tmpDir))
        XCTAssertEqual(FoodStickerStore.stickerCount(in: tmpDir), 1)
        XCTAssertNotNil(FoodStickerStore.load(for: "pumpkin", in: tmpDir))

        FoodStickerStore.delete(for: "pumpkin", in: tmpDir)
        XCTAssertFalse(FoodStickerStore.exists(for: "pumpkin", in: tmpDir))
        XCTAssertEqual(FoodStickerStore.stickerCount(in: tmpDir), 0)

        XCTAssertTrue(FoodStickerStore.save(sticker, for: "avocado", maxDimension: 128, in: tmpDir))
        XCTAssertEqual(FoodStickerStore.stickerCount(in: tmpDir), 1)
        FoodStickerStore.clearAll(in: tmpDir)
        XCTAssertEqual(FoodStickerStore.stickerCount(in: tmpDir), 0)

        // 3. Zero-server HandoverWebCodec fragment encode/decode round-trip (ZH & EN)
        let snap = HandoverSnapshot(
            babyName: "小满",
            ageText: "6个月17天",
            dateLabel: "10月19日 周一",
            timeLabel: "21:30",
            activeTimerLine: "睡着中 · 已睡 42 分",
            lastFeedHeadline: "2 小时前喝奶 120 ml",
            lastFeedDetail: "今日奶量 640 ml · 辅食 1 次",
            lastSleepHeadline: "睡前清醒 2 小时 10 分",
            lastSleepDetail: "今日小睡 2 段",
            lastDiaperHeadline: "45 分钟前 · 湿尿片",
            lastDiaperDetail: "今日湿 5 · 便 1",
            todayHeadline: "今日陪玩 2 项",
            todayDetail: "双手物品传递机会",
            extraNote: "睡前已吃维生素 D"
        )
        let zhURL = try XCTUnwrap(
            HandoverWebCodec.encodeURL(from: snap, now: at(21, 30), isEnglish: false, baseURLString: "https://mossotto.pages.dev/")
        )
        XCTAssertNil(zhURL.query)
        XCTAssertEqual(zhURL.path, "/handover")
        XCTAssertTrue(zhURL.fragment?.hasPrefix("d=") ?? false)
        let decodedZH = try XCTUnwrap(HandoverWebCodec.decode(from: zhURL))
        XCTAssertEqual(decodedZH.l, "zh")
        XCTAssertEqual(decodedZH.n, "小满")
        XCTAssertEqual(decodedZH.ac, "睡着中 · 已睡 42 分")
        XCTAssertEqual(decodedZH.no, "睡前已吃维生素 D")

        let enURL = try XCTUnwrap(
            HandoverWebCodec.encodeURL(from: snap, now: at(21, 30), isEnglish: true, baseURLString: "https://mossotto.pages.dev/")
        )
        let decodedEN = try XCTUnwrap(HandoverWebCodec.decode(from: enURL))
        XCTAssertEqual(decodedEN.l, "en")
        XCTAssertNil(HandoverWebCodec.decode(from: URL(string: "https://mossotto.pages.dev/handover")!))
        XCTAssertNil(HandoverWebCodec.decode(from: URL(string: "https://mossotto.pages.dev/handover#d=!!!")!))

        // 4. Siri Intent & safety gate
        let solidIntent = QuickLogSolidIntent(foodName: "南瓜")
        XCTAssertEqual(solidIntent.foodName, "南瓜")
        XCTAssertFalse(TimerIntent.canRecord(snapshot: nil))

        // 5. Render smoke checks across Round 27 views
        let envApp = AppModel(defaults: UserDefaults(suiteName: "round27-ed2-\(UUID().uuidString)")!)
        envApp.birth = Day(y: 2026, m: 4, d: 2)
        envApp.today = Day(y: 2026, m: 10, d: 19)
        envApp.nickname = "小满"
        envApp.journal = true
        envApp.consent = Consent.version
        let envJournal = JournalStore(preview: JournalFile.Body())
        let envRouter = AppRouter()

        func assertRenders<V: View>(_ view: V) {
            let img = renderHostedSnapshot(
                view
                    .environment(envApp)
                    .environment(envJournal)
                    .environment(envRouter)
            )
            XCTAssertNotNil(img.cgImage)
            XCTAssertGreaterThan(img.size.width, 100)
        }

        assertRenders(LampHubView(path: .constant(NavigationPath()), initialQuickNight3AM: true))
        assertRenders(FoodAtlasView())
        assertRenders(HandoverSheet(day: Day(y: 2026, m: 10, d: 19)))
        assertRenders(TodayView(path: .constant(NavigationPath())))
    }

    @MainActor
    func testV40UnifiedP0AndEvidenceSuite() throws {
        // 1. P0-1: Discard cleanly clears side-switched logs & detaches immediate retry within Feed.join
        var b = JournalFile.Body()
        let prevFeedEnd = t(19, 10, 10)
        b.logs.append(LogEntry(type: LogType.nurse, start: t(19, 10, 0), end: prevFeedEnd, side: "l"))
        // Start mistaken feed 30s later (within 2-minute Feed.join), switch side to create session entry, then discard
        let misStart = prevFeedEnd + 30_000
        b.timers.append(RunningTimer(type: LogType.nurse, start: misStart, side: "l"))
        b = JournalFile.switchingSide(b, LogType.nurse, now: misStart + 45_000)
        XCTAssertEqual(b.logs.count, 2)
        XCTAssertEqual(b.timers[0].sessionEntryIDs.count, 1)
        b = JournalFile.discarding(b, LogType.nurse)
        XCTAssertEqual(b.timers.count, 0)
        XCTAssertEqual(b.logs.count, 1, "Discarding mid-session nurse must remove switched-side drafts")

        // Retry with detached = true within Feed.join and stop; must NOT merge with earlier finished feed
        let retryStart = prevFeedEnd + 60_000
        b.timers.append(RunningTimer(type: LogType.nurse, start: retryStart, side: "r", detached: true))
        let retryRhythm = CareSessionRhythm.build(timer: b.timers[0], logs: b.logs, day: Day(y: 2026, m: 10, d: 19), nowMs: retryStart + 30_000)
        XCTAssertEqual(retryRhythm.leftSeconds, 0, accuracy: 0.5, "Detached retry must not inherit left side from earlier feed")
        XCTAssertEqual(retryRhythm.rightSeconds, 30, accuracy: 0.5)
        b = JournalFile.stopping(b, LogType.nurse, now: retryStart + 120_000)
        XCTAssertEqual(b.logs.count, 2)
        XCTAssertEqual(b.logs.feeds().count, 2, "Detached nurse entry stays a standalone feed")

        // JournalStore discard + immediate start flow + detached retry
        let savedFile = JournalFile.read()
        defer { _ = JournalFile.write(savedFile) }
        let store = JournalStore()
        var initBody = JournalFile.Body()
        initBody.logs = [LogEntry(type: LogType.nurse, start: t(19, 8, 0), end: t(19, 8, 10), side: "l")]
        XCTAssertTrue(store.replaceAll(initBody))
        store.start(LogType.nurse, at: Date(timeIntervalSince1970: t(19, 8, 11) / 1000))
        XCTAssertEqual(store.timers.count, 1)
        store.discard(LogType.nurse)
        XCTAssertEqual(store.timers.count, 0)
        store.start(LogType.nurse, at: Date(timeIntervalSince1970: (t(19, 8, 11) + 5_000) / 1000))
        XCTAssertTrue(store.timers.first?.detached == true)
        store.stop(LogType.nurse, at: Date(timeIntervalSince1970: (t(19, 8, 11) + 65_000) / 1000))
        XCTAssertEqual(store.logs.feeds().count, 2)

        // 2. P0-3: LampHubFilter standalone column isolation
        let day19 = Day(y: 2026, m: 10, d: 19)
        let mixedLogs = [
            LogEntry(type: LogType.nurse, start: t(19, 7, 0), end: t(19, 7, 10), side: "l"),
            LogEntry(type: LogType.bottle, start: t(19, 9, 0), amount: 90),
            LogEntry(type: LogType.sleep, start: t(19, 10, 0), end: t(19, 11, 0)),
            LogEntry(type: LogType.diaper, start: t(19, 11, 30), detail: "wet")
        ]
        XCTAssertEqual(LampHubFilter.filter(mixedLogs, by: LampHubFilter.feedKey).count, 2)
        XCTAssertEqual(LampHubFilter.filter(mixedLogs, by: LogType.diaper).count, 1)
        XCTAssertEqual(LampHubFilter.filter(mixedLogs, by: LogType.sleep).count, 1)
        let cats = LampHubFilter.availableCategories(in: mixedLogs, on: day19)
        XCTAssertEqual(cats.map(\.key), [LampHubFilter.feedKey, LogType.sleep, LogType.diaper])

        // 3. Preterm corrected age dual-track & AppModel/RecordFile round-trip
        let app = AppModel(defaults: UserDefaults(suiteName: "v40-app-\(UUID().uuidString)")!)
        app.today = Day(y: 2026, m: 10, d: 19)
        app.birth = app.today.plus(days: -16 * 7) // 16 actual weeks (~3.7 months)
        XCTAssertFalse(app.isUsingCorrectedAge)
        XCTAssertNil(app.correctedAge)
        app.gestationalWeeks = 39
        XCTAssertFalse(app.isUsingCorrectedAge)
        XCTAssertNil(app.correctedAge)
        app.gestationalWeeks = 32 // 8 weeks early -> ~8 corrected weeks (~1.8 months)
        XCTAssertTrue(app.isUsingCorrectedAge)
        XCTAssertEqual(app.actualAge?.months ?? -1, 3)
        XCTAssertEqual(app.correctedAge?.months ?? -1, 1)
        XCTAssertEqual(app.developmentalBirth, Age.correctedBirth(birth: app.birth!, gestationalWeeks: 32))

        // Over 24 months -> corrected age stops applying
        app.birth = app.today.plus(months: -26)
        XCTAssertFalse(app.isUsingCorrectedAge)

        app.birth = app.today.plus(months: -4)
        app.consent = Consent.version
        app.graduatedModules = [CareGearEngine.diaperModule]
        app.careModeActive = true
        app.setObservationState(4, "0-0", "Roll test", to: .askDoctor)
        let exported = RecordFile.json(app, JournalFile.Body())
        let reloaded = AppModel(defaults: UserDefaults(suiteName: "v40-reload-\(UUID().uuidString)")!)
        let emptyStore = JournalStore(preview: JournalFile.Body())
        try RecordFile.load(exported, into: reloaded, journal: emptyStore)
        XCTAssertEqual(reloaded.gestationalWeeks, 32)
        XCTAssertEqual(reloaded.graduatedModules, [CareGearEngine.diaperModule])
        XCTAssertTrue(reloaded.careModeActive)
        XCTAssertEqual(reloaded.observationState(4, "0-0"), .askDoctor)

        // 4. Four-Gear progression & graduation hint
        XCTAssertEqual(CareGearEngine.resolve(developmentalMonth: 2, graduatedModules: []), .gear1Survival)
        XCTAssertEqual(CareGearEngine.resolve(developmentalMonth: 7, graduatedModules: []), .gear2Explore)
        XCTAssertEqual(CareGearEngine.resolve(developmentalMonth: 15, graduatedModules: []), .gear3Autonomy)
        XCTAssertEqual(CareGearEngine.resolve(developmentalMonth: 28, graduatedModules: []), .gear4Dialogue)
        let diaperHint = CareGearEngine.suggestedGraduation(
            developmentalMonth: 4,
            logs: [LogEntry(type: LogType.diaper, start: app.today.plus(days: -10).date.timeIntervalSince1970 * 1000, detail: "wet")],
            graduatedModules: [],
            dismissedModules: [],
            today: app.today
        )
        XCTAssertEqual(diaperHint?.moduleKey, CareGearEngine.diaperModule)

        // 5. Evidence catalog: WHO 6 motor bands + 9-stage L1/L2/L3 catalog + Clinic PDF
        XCTAssertEqual(WHOMotorWindow.all.count, 6)
        XCTAssertTrue(WHOMotorWindow.all.allSatisfy { $0.startMonth < $0.endMonth })
        XCTAssertEqual(WHOMotorWindow.all.first(where: { $0.id == "crawl" })?.variableOrder, true)

        XCTAssertEqual(Set(LampCardCatalog.all.map(\.stageIndex)), Set(0...8))
        for card in LampCardCatalog.all {
            XCTAssertFalse(card.headlineZh.isEmpty)
            XCTAssertLessThanOrEqual(card.headlineZh.count, 32)
            XCTAssertFalse(card.headlineEn.isEmpty)
            XCTAssertFalse(card.translation.isEmpty)
            XCTAssertFalse(card.grandparentNote.isEmpty)
            XCTAssertFalse(card.clinicalTerms.isEmpty)
            XCTAssertFalse(card.redFlag.isEmpty)
            XCTAssertFalse(card.meta.sources.isEmpty)
            XCTAssertFalse(card.shareMessage().isEmpty)
        }

        let pdfData = ClinicSnapshotPDF.render(app: reloaded, logs: store.logs, measures: store.measures, questions: ["Night waking trend?"], days: 7)
        XCTAssertGreaterThan(pdfData.count, 500)
        XCTAssertEqual(String(decoding: pdfData.prefix(5), as: UTF8.self), "%PDF-")

        // 6. Smoke renders for updated / new v4.0 views
        func assertV40Renders<V: View>(_ view: V) {
            let img = renderHostedSnapshot(
                view
                    .environment(reloaded)
                    .environment(store)
                    .environment(AppRouter())
            )
            XCTAssertNotNil(img.cgImage)
            XCTAssertGreaterThan(img.size.width, 100)
        }
        assertV40Renders(ObserveView(month: 6))
        assertV40Renders(ClinicSnapshotSheet())
        assertV40Renders(LampCardDetailSheet(card: LampCardCatalog.spotlight(forMonth: 6, day: app.today)))
        assertV40Renders(LampHubView(path: .constant(NavigationPath()), initialQuickNight3AM: false))
    }

    @MainActor
    func testEditionIIIToVUltimateSuite() throws {
        let suite = "edition3to5-\(UUID().uuidString)"
        let app = AppModel(defaults: UserDefaults(suiteName: suite)!)
        app.consent = Consent.version
        app.nickname = "小满"
        app.sex = "girl"
        app.birth = app.today.plus(months: -9)

        let nowMs = app.today.date.timeIntervalSince1970 * 1000
        var body = JournalFile.Body()
        body.logs = [
            LogEntry(type: LogType.nurse, start: nowMs - 7_200_000, end: nowMs - 6_600_000, side: "l"),
            LogEntry(type: LogType.sleep, start: nowMs - 14_400_000, end: nowMs - 10_800_000),
            LogEntry(type: LogType.temp, start: nowMs - 3_600_000, amount: 378),
            LogEntry(type: LogType.medicine, start: nowMs - 1_800_000, detail: "Vitamin D3 400 IU")
        ]
        body.measures = [Measure(at: nowMs, weightG: 8650, lengthMm: 712, headMm: 446)]
        let firstVoiceID = UUID()
        body.firsts = [First(id: firstVoiceID, at: nowMs - 86_400_000, key: "quote", title: "会喊妈妈啦", note: "晨光里醒来轻轻喊")]
        let store = JournalStore(preview: body)

        // 1. Edition III: Zero-server Grandparent H5 Card Codec
        let spotlight = LampCardCatalog.spotlight(forMonth: 6, day: app.today)
        let lampURL = try XCTUnwrap(CardWebCodec.encodeURL(from: spotlight, babyName: app.nickname, month: 6, note: "少放学步车多放地垫"))
        let lampComps = try XCTUnwrap(URLComponents(url: lampURL, resolvingAgainstBaseURL: false))
        XCTAssertTrue(lampComps.path.hasSuffix("/card"))
        XCTAssertNil(lampComps.query)
        let decodedLamp = try XCTUnwrap(CardWebCodec.decode(from: lampURL))
        XCTAssertEqual(decodedLamp.k, "lamp")
        XCTAssertEqual(decodedLamp.b, "小满")
        XCTAssertEqual(decodedLamp.n, "少放学步车多放地垫")
        XCTAssertEqual(decodedLamp.gp, spotlight.grandparentNoteZh)

        let play = try XCTUnwrap(app.content.play("A11"))
        let playURL = try XCTUnwrap(CardWebCodec.encodeURL(from: play, babyName: app.nickname))
        let decodedPlay = try XCTUnwrap(CardWebCodec.decode(from: playURL))
        XCTAssertEqual(decodedPlay.k, "play")
        XCTAssertEqual(decodedPlay.ti, play.name)
        XCTAssertEqual(decodedPlay.steps, Array(play.steps.prefix(4)))

        // 2. Edition III: Baby-voice .m4a Waveform Store lifecycle on temp dir
        let bars = FirstVoiceWaveform.normalize([0.1, 0.5, 1.0, 0.2], targetCount: 24)
        XCTAssertEqual(bars.count, 24)
        XCTAssertTrue(bars.allSatisfy { $0 >= 0.08 && $0 <= 1.0 })
        XCTAssertEqual(FirstVoiceStore.formatDuration(4.2), "5s")
        XCTAssertEqual(FirstVoiceStore.formatDuration(65), "1:05")

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("voice-suite-\(UUID().uuidString)", isDirectory: true)
        defer { FirstVoiceStore.clearAll(in: tempDir) }
        let orphanID = UUID()
        XCTAssertNotNil(FirstVoiceStore.saveSample(audioData: Data([0x01, 0x02, 0x03]), peaks: [0.2, 0.9, 0.5], duration: 6.4, for: firstVoiceID, in: tempDir))
        XCTAssertNotNil(FirstVoiceStore.saveSample(audioData: Data([0x04, 0x05]), peaks: [0.4, 0.6], duration: 2.1, for: orphanID, in: tempDir))
        XCTAssertTrue(FirstVoiceStore.exists(for: firstVoiceID, in: tempDir))
        XCTAssertEqual(FirstVoiceStore.count(in: [firstVoiceID, orphanID], dir: tempDir), 2)
        FirstVoiceStore.prune(keeping: [firstVoiceID], in: tempDir)
        XCTAssertFalse(FirstVoiceStore.exists(for: orphanID, in: tempDir))
        XCTAssertNotNil(FirstVoiceStore.loadMeta(for: firstVoiceID, in: tempDir))

        // 3. Edition III: Well-Child Screening Cue, Pre-checkup Countdown & Clinic PDF with Foods/Temp
        XCTAssertNotNil(HealthRegion.screeningCue(for: .cn, month: 6))
        XCTAssertNotNil(HealthRegion.screeningCue(for: .us, month: 18))
        let sixMonthBirth = app.today.plus(days: 3).plus(months: -6)
        let upcoming = HealthRegion.daysUntilNextCheckup(birth: sixMonthBirth, today: app.today)
        XCTAssertEqual(upcoming?.month, 6)
        XCTAssertEqual(upcoming?.daysRemaining, 3)

        let foods: [FoodRecord] = [
            FoodRecord(foodId: "peanut", firstTastedEpochDay: app.today.epochDay, reaction: .loved, watchSkin: true, times: 2),
            FoodRecord(foodId: "broccoli", firstTastedEpochDay: app.today.epochDay, reaction: .tasted, watchSkin: false, times: 1)
        ]
        let clinicSections = ClinicSnapshotPDF.summaryLines(app: app, logs: store.logs, measures: store.measures, questions: ["Need iron check?"], foods: foods, region: .cn)
        let flatClinic = clinicSections.flatMap(\.lines).joined(separator: "\n")
        XCTAssertTrue(flatClinic.contains("Vitamin D3"))
        XCTAssertTrue(flatClinic.contains("37.8"))
        XCTAssertTrue(flatClinic.contains("花生酱") || flatClinic.lowercased().contains("peanut"))
        let clinicPdf = ClinicSnapshotPDF.render(app: app, logs: store.logs, measures: store.measures, questions: ["Need iron check?"], foods: foods, region: .cn)
        XCTAssertEqual(String(decoding: clinicPdf.prefix(5), as: UTF8.self), "%PDF-")

        // 4. Edition III: 3AM unified midnight boundary (00:00-04:59)
        let threeAm = try XCTUnwrap(Day.cal.date(bySettingHour: 3, minute: 20, second: 0, of: app.today.date))
        let ninePm = try XCTUnwrap(Day.cal.date(bySettingHour: 21, minute: 0, second: 0, of: app.today.date))
        let fiveAm = try XCTUnwrap(Day.cal.date(bySettingHour: 5, minute: 0, second: 0, of: app.today.date))
        XCTAssertTrue(CircadianDutyPhase.isLateNight3AM(threeAm))
        XCTAssertFalse(CircadianDutyPhase.isLateNight3AM(ninePm))
        XCTAssertFalse(CircadianDutyPhase.isLateNight3AM(fiveAm))

        // 5. Edition IV: Dual-Track Preterm / Gear Snapshot Widget Sync
        let pretermBirth = app.today.plus(months: -4)
        let snap = Snapshot(
            birthEpochDay: pretermBirth.epochDay,
            nickname: "小满",
            companion: Kind.moss.rawValue,
            journal: true,
            playCode: "A11",
            playName: play.name,
            consented: true,
            gestationalWeeks: 32,
            careGearRaw: CareGear.gear2Explore.rawValue,
            careModeActive: true,
            graduatedModules: [CareGearEngine.diaperModule],
            consentVersion: SharedConsent.version
        )
        let snapData = try JSONEncoder().encode(snap)
        let decodedSnap = try JSONDecoder().decode(Snapshot.self, from: snapData)
        let resolvedPreterm = try XCTUnwrap(decodedSnap.developmentalAge(on: app.today))
        XCTAssertTrue(resolvedPreterm.isCorrected)
        XCTAssertLessThan(resolvedPreterm.age.months, 4)
        XCTAssertEqual(decodedSnap.careBadgeLabel(), "减负照护")
        XCTAssertTrue(decodedSnap.isDiaperGraduated)

        var overTwoYears = decodedSnap
        overTwoYears.birthEpochDay = app.today.plus(months: -26).epochDay
        let resolvedOver24 = try XCTUnwrap(overTwoYears.developmentalAge(on: app.today))
        XCTAssertFalse(resolvedOver24.isCorrected)

        // 6. Edition V: Multi-page Growth Yearbook PDF + Locked Future Time Capsule Secrecy
        let futureBodySecret = "TOP_SECRET_FUTURE_BODY_DO_NOT_LEAK"
        let openBodyToken = "UNLOCKED_VISIBLE_LETTER_BODY"
        let lockedCap = TimeCapsule(
            title: "Three Years Birthday",
            body: futureBodySecret,
            writtenAt: nowMs,
            writtenAgeLabel: "9个月",
            unlockEpochDay: app.today.plus(days: 500).epochDay,
            openedAt: nil,
            seal: .gold
        )
        let unlockedCap = TimeCapsule(
            title: "Nine Months Tonight",
            body: openBodyToken,
            writtenAt: nowMs,
            writtenAgeLabel: "9个月",
            unlockEpochDay: nil,
            openedAt: nil,
            seal: .teal
        )
        let yearbookSections = GrowthYearbookPDF.buildSections(app: app, j: store, foods: foods, capsules: [lockedCap, unlockedCap])
        let joinedYearbook = yearbookSections.map { "\($0.title)\n\($0.lines.joined(separator: "\n"))" }.joined(separator: "\n")
        XCTAssertTrue(joinedYearbook.contains(openBodyToken))
        XCTAssertFalse(joinedYearbook.contains(futureBodySecret), "Locked future capsule body must NEVER leak into Growth Yearbook PDF")
        let yearbookPdf = GrowthYearbookPDF.render(app: app, j: store, foods: foods, capsules: [lockedCap, unlockedCap])
        XCTAssertEqual(String(decoding: yearbookPdf.prefix(5), as: UTF8.self), "%PDF-")
        let provider = try XCTUnwrap(CGDataProvider(data: yearbookPdf as CFData))
        let cgPdf = try XCTUnwrap(CGPDFDocument(provider))
        XCTAssertGreaterThanOrEqual(cgPdf.numberOfPages, 1)

        // 7. Edition IV & V: Widget & AX5 Accessibility Smoke Renders
        let widgetToday = renderHostedSnapshot(TodayFace(date: app.today.date, snap: decodedSnap, body: body, size: .medium))
        XCTAssertNotNil(widgetToday.cgImage)
        let widgetLamp = renderHostedSnapshot(BedsideLampFace(date: threeAm, snap: decodedSnap, body_: body, isMedium: true))
        XCTAssertNotNil(widgetLamp.cgImage)
        let widgetStory = renderHostedSnapshot(StoryWindowFace(date: app.today.date, snap: decodedSnap, body_: body, isMedium: true))
        XCTAssertNotNil(widgetStory.cgImage)

        func assertAX5Renders<V: View>(_ view: V) {
            let img = renderHostedSnapshot(
                view
                    .environment(app)
                    .environment(store)
                    .environment(AppRouter())
                    .environment(\.dynamicTypeSize, .accessibility5)
            )
            XCTAssertNotNil(img.cgImage)
            XCTAssertGreaterThan(img.size.width, 100)
        }
        assertAX5Renders(TodayView(path: .constant(NavigationPath())))
        assertAX5Renders(JourneyHubView())
        assertAX5Renders(CareView(month: 6))
        assertAX5Renders(FirstsView())
        assertAX5Renders(StorybookView())
        assertAX5Renders(YouView(path: .constant(NavigationPath())))
        assertAX5Renders(DataView())
    }

    @MainActor
    func testWallpaperAtelierIllustrationUpgradeSuite() {
        // 1. All 46 bespoke scenes map to a valid biome and cover all 5 biomes
        let mappedBiomes = Set(BespokeActivityID.allCases.map { BespokeActivitySceneRegistry.wallpaperBiome(for: $0) })
        XCTAssertEqual(BespokeActivityID.allCases.count, 46)
        XCTAssertEqual(mappedBiomes.count, WallpaperBiome.allCases.count)

        // 2. All 6 collector wallpaper plates exist in bundle Art/art/ and match code lookup
        XCTAssertEqual(ActivityWallpaperPlate.all.count, 6)
        for plate in ActivityWallpaperPlate.all {
            let loaded = ArtCache.shared.image(plate.filename, maxPixel: 512)
            XCTAssertNotNil(loaded, "Missing bundled collector wallpaper plate: \(plate.filename)")
            XCTAssertEqual(ActivityWallpaperPlate.plate(matching: plate.code).id, plate.id)
        }
        let fallbackPlate = ActivityWallpaperPlate.plate(matching: "A99")
        XCTAssertTrue(ActivityWallpaperPlate.all.contains { $0.id == fallbackPlate.id })

        // 3. Daylight Lock Screen, 4:3 Collector Print, Twilight Glaze & Sheet render cleanly
        let sample = ActivityWallpaperPlate.all[0]
        let lockImg = renderHostedSnapshot(
            ActivityWallpaperPoster(
                plate: sample,
                format: .lockScreen,
                eveningWarmth: false,
                showMuseumPlaque: false,
                targetSize: ActivityWallpaperFormat.lockScreen.previewSize,
                maxPixel: 512
            )
        )
        XCTAssertNotNil(lockImg.cgImage)

        let printImg = renderHostedSnapshot(
            ActivityWallpaperPoster(
                plate: ActivityWallpaperPlate.all[4],
                format: .galleryPrint,
                eveningWarmth: true,
                showMuseumPlaque: true,
                targetSize: ActivityWallpaperFormat.galleryPrint.previewSize,
                maxPixel: 512
            )
        )
        XCTAssertNotNil(printImg.cgImage)

        let sheetImg = renderHostedSnapshot(
            ActivityWallpaperSheet(initialCode: "A19")
                .environment(\.dynamicTypeSize, .accessibility3)
        )
        XCTAssertNotNil(sheetImg.cgImage)
    }

    @MainActor
    func testBatch33TypographyHitTargetsAndLayoutSpec() {
        // 1. Design tokens satisfy Apple HIG ergonomics & monotonic hierarchy
        XCTAssertGreaterThanOrEqual(LayoutSpec.hitMin, 44)
        XCTAssertGreaterThanOrEqual(LayoutSpec.ctaPrimaryHeight, 48)
        XCTAssertGreaterThanOrEqual(LayoutSpec.ctaSecondaryHeight, 44)
        XCTAssertEqual(LayoutSpec.pageH, 20)
        XCTAssertEqual(LayoutSpec.cardPad, 18)
        XCTAssertTrue(
            Radius.stage > Radius.card &&
            Radius.card > Radius.inner &&
            Radius.inner > Radius.tile &&
            Radius.tile > Radius.chip
        )

        // 2. Dynamic Type label floor & numerals resolution
        let flooredFont = Typeface.label(9, relativeTo: .caption2, weight: .bold)
        let numericFont = Typeface.numerals(16, relativeTo: .body, weight: .semibold)
        XCTAssertNotNil(flooredFont)
        XCTAssertNotNil(numericFont)

        // 3. Core shared typography & row primitives render cleanly at default & AX3 sizes
        let suiteName = "batch33-\(UUID().uuidString)"
        let envApp = AppModel(defaults: UserDefaults(suiteName: suiteName)!)
        envApp.birth = Day(y: 2026, m: 4, d: 2)
        envApp.today = Day(y: 2026, m: 10, d: 19)
        envApp.nickname = "小满"
        envApp.journal = true
        let envJournal = JournalStore(preview: JournalFile.Body())
        let envRouter = AppRouter()

        let primitives = VStack(alignment: .leading, spacing: LayoutSpec.cardGap) {
            SectionTitle(title: "排版与热区检查", detail: "Day & Lamp")
            Box {
                BoxRow(symbol: "sun.max.fill", title: "标准行条目", text: "说明文字对齐", last: false, opens: true)
                CheckRow(text: "交互勾选行", on: true, tag: "已记录", last: true) {}
            }
            CalmDisclosureNote(title: "折叠说明", symbol: "info.circle") {
                Text("细节文案").font(.footnote)
            }
            Button("主按钮") {}
                .buttonStyle(.vinyl(Palette.accent, prominent: true, large: true))
        }
        .padding(.horizontal, LayoutSpec.pageH)

        for dt in [DynamicTypeSize.large, .accessibility3] {
            let img = renderHostedSnapshot(
                primitives
                    .environment(envApp)
                    .environment(envJournal)
                    .environment(\.dynamicTypeSize, dt)
            )
            XCTAssertNotNil(img.cgImage)
            XCTAssertGreaterThan(img.size.width, 100)
        }

        // 4. Upgraded interactive views render cleanly across AX3 without truncation/layout traps
        for view in [
            AnyView(BedsideLampView(initialBrightness: 0.78, initialPalmPat: true, previewClock: envApp.today.date)),
            AnyView(FoodAtlasView()),
            AnyView(ToyboxView(initialMode: .shadows, initialShadowPuppet: .rabbit))
        ] {
            let img = renderHostedSnapshot(
                view
                    .environment(envApp)
                    .environment(envJournal)
                    .environment(envRouter)
                    .environment(\.dynamicTypeSize, .accessibility3)
            )
            XCTAssertNotNil(img.cgImage)
            XCTAssertGreaterThan(img.size.width, 100)
        }
    }

    @MainActor
    func testBatch34DesignSystemAndVisualHierarchy() {
        // 1. DS tokens align with LayoutSpec & Apple HIG 44pt+ / 11pt+ constraints
        XCTAssertEqual(DS.Spacing.pageH, LayoutSpec.pageH)
        XCTAssertEqual(DS.Spacing.cardPad, LayoutSpec.cardPad)
        XCTAssertEqual(DS.Spacing.cardPadHero, LayoutSpec.cardPadHero)
        XCTAssertGreaterThanOrEqual(LayoutSpec.hitMin, 44)
        XCTAssertNotNil(Typeface.numerals(8, relativeTo: .caption2, weight: .bold))

        // 2. Render Design System primitives across Light, Dark & AX3
        let suiteName = "batch34-\(UUID().uuidString)"
        let envApp = AppModel(defaults: UserDefaults(suiteName: suiteName)!)
        envApp.birth = Day(y: 2026, m: 4, d: 2)
        envApp.today = Day(y: 2026, m: 10, d: 19)
        envApp.nickname = "小满"
        envApp.journal = true
        let envJournal = JournalStore(preview: JournalFile.Body())
        let envRouter = AppRouter()

        let dsShowcase = VStack(alignment: .leading, spacing: DS.Spacing.cardGap) {
            SectionTitle(title: "设计系统规范", detail: "Apple HIG")
            DSSegmentedControl(
                items: RhythmFilter.allCases,
                selection: .constant(RhythmFilter.sleep),
                dark: false,
                title: { $0.label },
                dotColor: { $0 == .all ? nil : $0.tint }
            )
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                spacing: 8
            ) {
                DSMetricCell(label: "日均睡眠", value: "12.4", unit: "h", accent: Crayon.lilac, dark: false)
                DSMetricCell(label: "日均喂奶", value: "5.2", unit: "次", accent: Crayon.pink, dark: false)
            }
            HStack(spacing: 10) {
                Button("试听旋律") {}
                    .buttonStyle(.ds(.secondary, fullWidth: true, height: 48))
                Button("完成并盖印") {}
                    .buttonStyle(.ds(.primary, fullWidth: true, height: 48))
            }
            HStack(spacing: 8) {
                DSIconButton(symbol: "arrow.trianglehead.2.clockwise", accessibilityLabel: "换一个") {}
                DSFilterChip(title: "全部", selected: true) {}
                DSFilterChip(title: "未尝", selected: false) {}
            }
        }
        .padding(.horizontal, DS.Spacing.pageH)

        for scheme in [ColorScheme.light, .dark] {
            for dt in [DynamicTypeSize.large, .accessibility3] {
                let img = renderHostedSnapshot(
                    dsShowcase
                        .environment(envApp)
                        .environment(envJournal)
                        .environment(\.colorScheme, scheme)
                        .environment(\.dynamicTypeSize, dt)
                )
                XCTAssertNotNil(img.cgImage)
                XCTAssertGreaterThan(img.size.width, 100)
            }
        }

        // 3. Render all upgraded core screens cleanly without nil captures
        let views: [AnyView] = [
            AnyView(TodayView(path: .constant(NavigationPath()))),
            AnyView(LampHubView(path: .constant(NavigationPath()))),
            AnyView(JourneyHubView(isRootTab: true)),
            AnyView(YouView(path: .constant(NavigationPath()))),
            AnyView(RhythmDialCard(nowHour: 14.5)),
            AnyView(FoodAtlasView()),
            AnyView(ToyboxView(initialMode: .xylophone)),
            AnyView(BedsideLampView(initialBrightness: 0.72, previewClock: envApp.today.date)),
        ]
        for v in views {
            let img = renderHostedSnapshot(
                v
                    .environment(envApp)
                    .environment(envJournal)
                    .environment(envRouter)
            )
            XCTAssertNotNil(img.cgImage)
            XCTAssertGreaterThan(img.size.width, 100)
        }
    }

    @MainActor
    func testBatch35WarmColorPaletteAndZeroTruncationMetrics() {
        let prevLang = L10n.preference
        let prevOverride = L10n.overrideEnglish
        defer {
            L10n.overrideEnglish = prevOverride
            L10n.preference = prevLang
        }

        enum WarmThemeProbe: String, Identifiable, CaseIterable {
            case day, lamp, auto
            var id: String { rawValue }
            var title: String {
                switch self {
                case .day: "Day"
                case .lamp: "Lamp"
                case .auto: "Auto"
                }
            }
        }

        // 1. Setup real-device studio profile parity state ("Meadow · Day 149" / "Lamp Keeper")
        let suiteName = "batch35-\(UUID().uuidString)"
        let envApp = AppModel(defaults: UserDefaults(suiteName: suiteName)!)
        envApp.birth = Day(y: 2026, m: 6, d: 30)
        envApp.today = Day(y: 2026, m: 11, d: 25)
        envApp.nickname = "小薄荷"
        envApp.theme = .light
        L10n.overrideEnglish = true
        envApp.language = .en
        envApp.journal = true
        let envJournal = JournalStore(preview: JournalFile.Body())
        let envRouter = AppRouter()

        XCTAssertGreaterThanOrEqual(LayoutSpec.hitMin, 44)
        XCTAssertEqual(YouStudioCopy.companionBadge(.otto), "Lamp Keeper")
        XCTAssertEqual(YouStudioCopy.companionBadge(.moss), "Explorer")

        // 2. Render warm inset trays, warm gradient buttons, segmented tracks & proportional pills
        let warmShowcase = VStack(spacing: 12) {
            DSSegmentedControl(
                items: WarmThemeProbe.allCases,
                selection: .constant(WarmThemeProbe.day),
                dark: false,
                compact: true,
                title: { $0.title },
                dotColor: { $0 == .day ? Palette.amber : Palette.bead }
            )
            HStack(spacing: 10) {
                Button("Listen") {}
                    .buttonStyle(.ds(.primary, fullWidth: true, height: 50))
                Button("Play Along") {}
                    .buttonStyle(.ds(.warm(Crayon.caramel), fullWidth: true, height: 50))
            }
            HStack(spacing: 8) {
                Label("Story", systemImage: "book.closed.fill")
                    .dsPill(.warm(Palette.bead), height: 32)
                Label("Edit", systemImage: "pencil")
                    .dsPill(.primary, height: 32)
                Button("Legal & Help") {}
                    .buttonStyle(.ds(.secondary, height: 34))
            }
        }
        .padding(DS.Spacing.pageH)
        .background(DS.Surface.warmInset(dark: false))

        for scheme in [ColorScheme.light, .dark] {
            for dt in [DynamicTypeSize.large, .accessibility3] {
                let img = renderHostedSnapshot(
                    warmShowcase
                        .environment(envApp)
                        .environment(envJournal)
                        .environment(\.colorScheme, scheme)
                        .environment(\.dynamicTypeSize, dt)
                )
                XCTAssertNotNil(img.cgImage)
                XCTAssertGreaterThan(img.size.width, 100)
            }
        }

        // 3. Verify core views across EN & ZH and standard/AX3 dynamic type
        let views: [AnyView] = [
            AnyView(YouView(path: .constant(NavigationPath()))),
            AnyView(TodayView(path: .constant(NavigationPath()))),
            AnyView(LampHubView(path: .constant(NavigationPath()))),
            AnyView(JourneyHubView(isRootTab: true)),
            AnyView(RhythmDialCard(nowHour: 14.5)),
            AnyView(FoodAtlasView()),
            AnyView(ToyboxView(initialMode: .xylophone)),
            AnyView(BedsideLampView(initialBrightness: 0.72, previewClock: envApp.today.date)),
        ]
        for lang in [AppLanguage.en, .zh] {
            L10n.overrideEnglish = (lang == .en)
            envApp.language = lang
            for dt in [DynamicTypeSize.large, .accessibility3] {
                for v in views {
                    let img = renderHostedSnapshot(
                        v
                            .environment(envApp)
                            .environment(envJournal)
                            .environment(envRouter)
                            .environment(\.dynamicTypeSize, dt)
                    )
                    XCTAssertNotNil(img.cgImage)
                    XCTAssertGreaterThan(img.size.width, 100)
                }
            }
        }
    }

    @MainActor
    func testThirdPartyAuditWave1Remediations() throws {
        let prevLang = L10n.overrideEnglish
        defer { L10n.overrideEnglish = prevLang }

        // 1. WCAG contrast tokens: forest-green leaf fill, deep cherry danger, and warm accent/bead normalization
        func linearizeSRGB(_ v: CGFloat) -> Double {
            let x = max(0, min(1, Double(v)))
            return x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
        }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(UIColor(Crayon.buttonFill(Crayon.leaf)).getRed(&r, green: &g, blue: &b, alpha: &a))
        let leafRelLum = 0.2126 * linearizeSRGB(r) + 0.7152 * linearizeSRGB(g) + 0.0722 * linearizeSRGB(b)
        XCTAssertLessThan(leafRelLum, 0.183)
        XCTAssertGreaterThanOrEqual(1.05 / (leafRelLum + 0.05), 4.5)
        XCTAssertTrue(UIColor(Crayon.fill(Palette.accent, false)).getRed(&r, green: &g, blue: &b, alpha: &a))
        XCTAssertTrue(UIColor(Crayon.fill(Palette.bead, false)).getRed(&r, green: &g, blue: &b, alpha: &a))
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        XCTAssertEqual(
            UIColor(Palette.danger).resolvedColor(with: lightTraits),
            UIColor(Crayon.ink(Crayon.cherry)).resolvedColor(with: lightTraits)
        )
        XCTAssertEqual(
            UIColor(Palette.danger).resolvedColor(with: darkTraits),
            UIColor(Crayon.ink(Crayon.cherry)).resolvedColor(with: darkTraits)
        )

        // 2. Preterm Age.corrected preserves chronological lived days monotonically across due date & Euclidean month math
        let pretermBirth = Day(y: 2026, m: 8, d: 1)
        let preDue = pretermBirth.plus(days: 20)
        let preDueAge = try XCTUnwrap(Age.corrected(birth: pretermBirth, gestationalWeeks: 32, today: preDue))
        XCTAssertEqual(preDueAge.months, 0)
        XCTAssertEqual(preDueAge.days, 0)
        XCTAssertEqual(preDueAge.lived, 21)

        let postDue = pretermBirth.plus(days: 60)
        let postDueAge = try XCTUnwrap(Age.corrected(birth: pretermBirth, gestationalWeeks: 32, today: postDue))
        XCTAssertEqual(postDueAge.lived, 61)
        XCTAssertEqual(postDueAge.lived, Age.on(birth: pretermBirth, today: postDue).lived)

        let futureAge = try XCTUnwrap(Age.corrected(birth: pretermBirth, gestationalWeeks: 32, today: pretermBirth.plus(days: -2)))
        XCTAssertEqual(futureAge.lived, 0)
        XCTAssertEqual(Day(y: 2026, m: 1, d: 15).plus(months: -13), Day(y: 2024, m: 12, d: 15))

        // 3. RecordFile preserves First.id UUID across export -> reload
        let suiteApp = AppModel(defaults: UserDefaults(suiteName: "wave1-rec-\(UUID().uuidString)")!)
        suiteApp.consent = Consent.version
        suiteApp.today = Day(y: 2026, m: 10, d: 20)
        suiteApp.birth = Day(y: 2026, m: 6, d: 1)
        let fid = UUID()
        var srcBody = JournalFile.Body()
        srcBody.firsts = [First(id: fid, at: suiteApp.today.date.timeIntervalSince1970 * 1000, key: "smile", title: "First Smile")]
        let exportedData = RecordFile.json(suiteApp, srcBody)
        let jsonObj = try XCTUnwrap(JSONSerialization.jsonObject(with: exportedData) as? [String: Any])
        let jsonMossling = try XCTUnwrap(jsonObj["mossling"] as? [String: Any])
        let jsonFirsts = try XCTUnwrap(jsonMossling["firsts"] as? [[String: Any]])
        XCTAssertEqual(jsonFirsts.first?["id"] as? String, fid.uuidString)

        JournalFile.beginTest(); defer { JournalFile.endTest() }
        let reloadedApp = AppModel(defaults: UserDefaults(suiteName: "wave1-rec2-\(UUID().uuidString)")!)
        let reloadedStore = JournalStore(preview: JournalFile.Body())
        try RecordFile.load(exportedData, into: reloadedApp, journal: reloadedStore)
        XCTAssertEqual(reloadedStore.firsts.first?.id, fid)

        // 4. LampCard.shareMessage() is cleanly localized in English
        L10n.overrideEnglish = true
        let sampleCard = try XCTUnwrap(LampCardCatalog.all.first)
        let enShare = sampleCard.shareMessage()
        XCTAssertTrue(enShare.contains("[Moss & Otto"))
        XCTAssertTrue(enShare.contains("Sources:"))
        XCTAssertFalse(enShare.contains("【摸索台灯"))

        // 5. MidnightCareSummary pairs multi-side L/R nursing segments into 1 feed session
        let nightNow = try XCTUnwrap(Day.cal.date(bySettingHour: 3, minute: 0, second: 0, of: Day(y: 2026, m: 10, d: 20).date))
        let nightNowMs = nightNow.timeIntervalSince1970 * 1000
        let nightLogs = [
            LogEntry(type: LogType.nurse, start: nightNowMs - 150 * 60_000, end: nightNowMs - 140 * 60_000, side: "l"),
            LogEntry(type: LogType.nurse, start: nightNowMs - 139 * 60_000, end: nightNowMs - 129 * 60_000, side: "r")
        ]
        let nightSleepTimer = RunningTimer(type: LogType.sleep, start: nightNowMs - 45 * 60_000, side: nil, pausedAt: nil, pausedTotal: 0)
        let midSummary = MidnightCareSummary.build(logs: nightLogs, timers: [nightSleepTimer], now: nightNow)
        XCTAssertTrue(midSummary.nightStatusLine?.contains("1 night feed") == true)
        XCTAssertFalse(midSummary.nightStatusLine?.contains("2 night feeds") == true)

        // 6. BookPage.all expands to actual chronological month for preterm infants
        let pretermApp = AppModel(defaults: UserDefaults(suiteName: "wave1-book-\(UUID().uuidString)")!)
        pretermApp.today = Day(y: 2026, m: 10, d: 20)
        pretermApp.birth = pretermApp.today.plus(days: -16 * 7) // 3 actual months, 1 corrected month
        pretermApp.gestationalWeeks = 32
        XCTAssertEqual(pretermApp.actualAge?.bookMonth, 3)
        XCTAssertEqual(pretermApp.correctedAge?.bookMonth, 1)
        let bookPages = BookPage.all(pretermApp, JournalStore(preview: JournalFile.Body()))
        XCTAssertEqual(bookPages.count, 4)

        // 7. FoodAtlasStore handles duplicate foodId records without Dictionary key collisions
        let tempFoodURL = FileManager.default.temporaryDirectory.appendingPathComponent("food-dup-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempFoodURL) }
        let r1 = FoodRecord(foodId: "avocado", firstTastedEpochDay: 20000, reaction: .tasted, times: 1)
        let r2 = FoodRecord(foodId: "avocado", firstTastedEpochDay: 20002, reaction: .tryAgain, times: 4)
        let encodedDup = try JSONEncoder().encode([r1, r2])
        try encodedDup.write(to: tempFoodURL, options: .atomic)
        let foodStore = FoodAtlasStore(fileURL: tempFoodURL)
        XCTAssertEqual(foodStore.record(for: "avocado")?.times, 4)
        foodStore.replaceAll([r1, r2])
        XCTAssertEqual(foodStore.record(for: "avocado")?.times, 4)

        // 8. ClinicSnapshotPDF paginates multi-page output cleanly when questions overflow page 1
        let pdfData = ClinicSnapshotPDF.render(
            app: suiteApp,
            logs: [],
            measures: [],
            questions: (1...35).map { "Clinic follow-up question #\($0) with extra notes for pagination verification" }
        )
        let pdfProvider = try XCTUnwrap(CGDataProvider(data: pdfData as CFData))
        let pdfDoc = try XCTUnwrap(CGPDFDocument(pdfProvider))
        XCTAssertGreaterThanOrEqual(pdfDoc.numberOfPages, 2)

        // 9. ActivityWallpaperPoster(isExport: true) renders full-bleed unclipped snapshot
        let wallpaperImg = renderHostedSnapshot(
            ActivityWallpaperPoster(
                plate: ActivityWallpaperPlate.all[0],
                format: .lockScreen,
                eveningWarmth: false,
                showMuseumPlaque: false,
                targetSize: CGSize(width: 240, height: 520),
                maxPixel: 600,
                isExport: true
            ),
            width: 240,
            height: 520
        )
        XCTAssertNotNil(wallpaperImg.cgImage)
        XCTAssertGreaterThan(wallpaperImg.size.width, 100)

        // 10. App and Widget privacy manifests both declare CA92.1 & 1C8F.1 UserDefaults reasons
        let iosDir = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let appManifest = iosDir.appendingPathComponent("Mossling/Resources/PrivacyInfo.xcprivacy")
        let widgetManifest = iosDir.appendingPathComponent("Widget/PrivacyInfo.xcprivacy")
        for manifestURL in [appManifest, widgetManifest] where FileManager.default.fileExists(atPath: manifestURL.path) {
            let text = try String(contentsOf: manifestURL, encoding: .utf8)
            XCTAssertTrue(text.contains("CA92.1"), "Missing CA92.1 in \(manifestURL.lastPathComponent)")
            XCTAssertTrue(text.contains("1C8F.1"), "Missing 1C8F.1 in \(manifestURL.lastPathComponent)")
        }
    }

    @MainActor
    func testAuditWave2And3Remediations() throws {
        let prevEnglish = L10n.overrideEnglish
        defer { L10n.overrideEnglish = prevEnglish }

        // 1. PalmPatRhythm continuous phase continuity under autoSlow
        var prevPhase = PalmPatRhythm.phaseFraction(startBPM: 60, elapsedSeconds: 0, autoSlow: true)
        for step in 1...6000 {
            let tSec = Double(step) * 0.05
            let cur = PalmPatRhythm.phaseFraction(startBPM: 60, elapsedSeconds: tSec, autoSlow: true)
            var delta = cur - prevPhase
            if delta < 0 { delta += 1.0 }
            XCTAssertLessThan(delta, 0.08, "Phase continuity jump at t=\(tSec)")
            prevPhase = cur
        }

        // 2. MidnightCareSummary daytime vs night wording (ZH & EN)
        let refDay = Day(y: 2026, m: 11, d: 20)
        let day14 = try XCTUnwrap(Day.cal.date(bySettingHour: 14, minute: 0, second: 0, of: refDay.date))
        let day14Ms = day14.timeIntervalSince1970 * 1000
        let daytimeFeed = [LogEntry(type: LogType.nurse, start: day14Ms - 3_600_000, end: day14Ms - 3_000_000, side: "l")]
        let daytimeSleepTimer = RunningTimer(type: LogType.sleep, start: day14Ms - 1_200_000, side: nil, pausedAt: nil, pausedTotal: 0)
        L10n.overrideEnglish = true
        let daySummaryEN = MidnightCareSummary.build(logs: daytimeFeed, timers: [daytimeSleepTimer], now: day14)
        XCTAssertTrue(daySummaryEN.nightStatusLine?.contains("today") == true)
        XCTAssertFalse(daySummaryEN.nightStatusLine?.contains("night") == true)
        L10n.overrideEnglish = false
        let daySummaryZH = MidnightCareSummary.build(logs: daytimeFeed, timers: [daytimeSleepTimer], now: day14)
        XCTAssertTrue(daySummaryZH.nightStatusLine?.contains("今日") == true)
        XCTAssertFalse(daySummaryZH.nightStatusLine?.contains("今夜") == true)

        // 3. HandoverSnapshot preserves temp + medication alongside solids, while HandoverWebCodec strips sensitive vitals from #d=
        L10n.overrideEnglish = true
        let handoverNow = try XCTUnwrap(Day.cal.date(bySettingHour: 20, minute: 30, second: 0, of: refDay.date))
        let hMs = handoverNow.timeIntervalSince1970 * 1000
        let hApp = AppModel(defaults: UserDefaults(suiteName: "wave2-handover-\(UUID().uuidString)")!)
        hApp.consent = Consent.version
        hApp.nickname = "Milo"
        hApp.today = refDay
        var hBody = JournalFile.Body()
        hBody.logs = [
            LogEntry(type: LogType.bottle, start: hMs - 5_400_000, amount: 120, detail: "breastmilk"),
            LogEntry(type: LogType.sleep, start: hMs - 9_000_000, end: hMs - 3_600_000),
            LogEntry(type: LogType.diaper, start: hMs - 2_400_000, detail: "wet"),
            LogEntry(type: LogType.temp, start: hMs - 1_800_000, amount: 379),
            LogEntry(type: LogType.medicine, start: hMs - 900_000, detail: "Vitamin D3"),
            LogEntry(type: LogType.solid, start: hMs - 600_000, detail: "Avocado")
        ]
        let hStore = JournalStore(preview: hBody)
        let hSnap = HandoverSnapshot.build(app: hApp, journal: hStore, day: refDay, now: handoverNow)
        XCTAssertEqual(hSnap.careAlerts.count, 2)
        XCTAssertTrue(hSnap.todayDetail.contains("Avocado"))
        XCTAssertNotNil(hSnap.feedTimestampSec)
        XCTAssertNotNil(hSnap.sleepTimestampSec)
        XCTAssertNotNil(hSnap.diaperTimestampSec)

        let rawTempSnap = HandoverSnapshot(
            babyName: "Milo", ageText: "6m", dateLabel: "Nov 20", timeLabel: "20:30",
            activeTimerLine: nil, lastFeedHeadline: "1h ago", lastFeedDetail: "120 ml",
            lastSleepHeadline: "1h ago", lastSleepDetail: "Today total 2h",
            lastDiaperHeadline: "40m ago", lastDiaperDetail: "1 wet",
            todayHeadline: "1 feed · 1 diaper", todayDetail: "Temp · 37.9 °C",
            extraNote: "", careAlerts: ["Temp: 37.9 °C"],
            feedTimestampSec: hSnap.feedTimestampSec, sleepTimestampSec: hSnap.sleepTimestampSec, diaperTimestampSec: hSnap.diaperTimestampSec
        )
        let beaconURL = try XCTUnwrap(HandoverWebCodec.encodeURL(from: rawTempSnap, now: handoverNow, isEnglish: true))
        let decodedBeacon = try XCTUnwrap(HandoverWebCodec.decode(from: beaconURL))
        XCTAssertFalse(decodedBeacon.r2.contains("37.9"))
        XCTAssertFalse(decodedBeacon.r2.contains("Temp"))
        XCTAssertEqual(decodedBeacon.fts, hSnap.feedTimestampSec)

        // 4. Crayon contrast-safe ink/fill fallback for non-Crayon Palette colors
        let lightTraits = UITraitCollection(userInterfaceStyle: .light)
        let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
        func linearize(_ v: CGFloat) -> Double {
            let x = max(0, min(1, Double(v)))
            return x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
        }
        for paletteColor in [Palette.rod, Palette.bead, Palette.amber] {
            let lightInk = UIColor(Crayon.ink(paletteColor)).resolvedColor(with: lightTraits)
            let darkInk = UIColor(Crayon.ink(paletteColor)).resolvedColor(with: darkTraits)
            let fill = UIColor(Crayon.buttonFill(paletteColor)).resolvedColor(with: lightTraits)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            XCTAssertTrue(lightInk.getRed(&r, green: &g, blue: &b, alpha: &a))
            XCTAssertTrue(darkInk.getRed(&r, green: &g, blue: &b, alpha: &a))
            XCTAssertTrue(fill.getRed(&r, green: &g, blue: &b, alpha: &a))
            let lum = 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
            let whiteContrast = 1.05 / (lum + 0.05)
            XCTAssertGreaterThanOrEqual(whiteContrast, 4.5)
        }

        // 5. TimerIntent.canRecord gates on appLocked & consentVersion
        let okSnap = Snapshot(birthEpochDay: nil, nickname: "", companion: "Moss", journal: true, playCode: nil, playName: nil, consented: true, appLocked: false, consentVersion: SharedConsent.version)
        let lockedSnap = Snapshot(birthEpochDay: nil, nickname: "", companion: "Moss", journal: true, playCode: nil, playName: nil, consented: true, appLocked: true, consentVersion: SharedConsent.version)
        let staleConsentSnap = Snapshot(birthEpochDay: nil, nickname: "", companion: "Moss", journal: true, playCode: nil, playName: nil, consented: true, appLocked: false, consentVersion: "2020-01-01")
        XCTAssertTrue(TimerIntent.canRecord(snapshot: okSnap))
        XCTAssertFalse(TimerIntent.canRecord(snapshot: lockedSnap))
        XCTAssertFalse(TimerIntent.canRecord(snapshot: staleConsentSnap))

        // 6. RecordFile.load bounds & per-measurement preterm growth logic
        JournalFile.beginTest(); defer { JournalFile.endTest() }
        let importApp = AppModel(defaults: UserDefaults(suiteName: "wave2-import-\(UUID().uuidString)")!)
        importApp.consent = Consent.version
        let importStore = JournalStore()
        let importPayload: [String: Any] = [
            "app": "mossling",
            "version": 1,
            "mossling": [
                "settings": ["consent": Consent.version],
                "logs": [
                    ["type": LogType.diaper, "start": -5_000_000_000_000.0, "detail": "wet"],
                    ["type": LogType.diaper, "start": 9_999_999_999_999.0, "detail": "wet"],
                    ["type": LogType.diaper, "start": day14Ms, "detail": "wet"]
                ],
                "measures": [
                    ["at": day14Ms, "weightG": 99_999],
                    ["at": day14Ms, "weightG": 6400]
                ]
            ]
        ]
        let importData = try JSONSerialization.data(withJSONObject: importPayload)
        try RecordFile.load(importData, into: importApp, journal: importStore)
        XCTAssertEqual(importStore.logs.count, 1)
        XCTAssertEqual(importStore.measures.count, 1)
        XCTAssertEqual(importStore.measures.first?.weightG, 6400)

        let pretermBirth = Day(y: 2024, m: 1, d: 1)
        let earlyMeasureDay = Day(y: 2024, m: 7, d: 1)
        let lateMeasureDay = Day(y: 2026, m: 3, d: 1)
        let earlyM = Measure(at: earlyMeasureDay.date.timeIntervalSince1970 * 1000, weightG: 6500)
        let lateM = Measure(at: lateMeasureDay.date.timeIntervalSince1970 * 1000, weightG: 12500)
        let earlyMo = try XCTUnwrap(GrowthView.developmentalMonths(for: earlyM, birth: pretermBirth, gestationalWeeks: 32))
        let lateMo = try XCTUnwrap(GrowthView.developmentalMonths(for: lateM, birth: pretermBirth, gestationalWeeks: 32))
        XCTAssertLessThan(earlyMo, 5.0)
        XCTAssertGreaterThan(lateMo, 25.0)

        // 7. Entry-level delta undo preserves concurrent external additions
        XCTAssertTrue(JournalFile.write(JournalFile.Body()))
        let deltaStore = JournalStore()
        let undoneId = UUID()
        XCTAssertTrue(deltaStore.record(LogEntry(id: undoneId, type: LogType.diaper, start: day14Ms, detail: "wet")))
        let undoToast = try XCTUnwrap(deltaStore.toast)
        let concurrentId = UUID()
        _ = JournalFile.mutate { body in
            body.logs.append(LogEntry(id: concurrentId, type: LogType.sleep, start: day14Ms + 60_000, end: day14Ms + 300_000))
            return true
        }
        deltaStore.undo(undoToast)
        XCTAssertFalse(deltaStore.logs.contains { $0.id == undoneId })
        XCTAssertTrue(deltaStore.logs.contains { $0.id == concurrentId })

        // 8. EarSafeVolumeMonitor aligned at 0.60 threshold
        XCTAssertEqual(EarSafeVolumeLevel.of(0.60), .safe)
        XCTAssertEqual(EarSafeVolumeLevel.of(0.61), .loud)
        XCTAssertFalse(EarSafeVolumeMonitor.shouldPrompt(volume: 0.60, context: .lamp, hasSeenToyboxGuide: true, dismissedThisSession: false))
        XCTAssertTrue(EarSafeVolumeMonitor.shouldPrompt(volume: 0.61, context: .lamp, hasSeenToyboxGuide: true, dismissedThisSession: false))
    }

    @MainActor
    func testAuditWave4AndCreativeAlchemy() throws {
        L10n.overrideEnglish = false; defer { L10n.overrideEnglish = nil }
        JournalFile.beginTest(); defer { JournalFile.endTest() }

        // 1. WidgetPrivacy & AppModel.publish redaction
        let validSnap = Snapshot(birthEpochDay: Day(y: 2026, m: 4, d: 2).epochDay, nickname: "小满", companion: "Moss", journal: true, playCode: "A11", playName: "抓握", consented: true, appLocked: false, consentVersion: SharedConsent.version)
        let lockedSnap = Snapshot(birthEpochDay: validSnap.birthEpochDay, nickname: "小满", companion: "Moss", journal: true, playCode: "A11", playName: "抓握", consented: true, appLocked: true, consentVersion: SharedConsent.version)
        let declinedSnap = Snapshot(birthEpochDay: validSnap.birthEpochDay, nickname: "小满", companion: "Moss", journal: true, playCode: nil, playName: nil, consented: false, appLocked: false, consentVersion: SharedConsent.version)
        let staleSnap = Snapshot(birthEpochDay: validSnap.birthEpochDay, nickname: "小满", companion: "Moss", journal: true, playCode: nil, playName: nil, consented: true, appLocked: false, consentVersion: "1999-01-01")
        XCTAssertTrue(WidgetPrivacy.canShowRecords(snap: validSnap))
        XCTAssertFalse(WidgetPrivacy.canShowRecords(snap: lockedSnap))
        XCTAssertFalse(WidgetPrivacy.canShowRecords(snap: declinedSnap))
        XCTAssertFalse(WidgetPrivacy.canShowRecords(snap: staleSnap))
        XCTAssertFalse(WidgetPrivacy.canShowRecords(snap: nil))

        let redactApp = AppModel(defaults: UserDefaults(suiteName: "wave4-redact-\(UUID().uuidString)")!)
        redactApp.birth = Day(y: 2026, m: 4, d: 2)
        redactApp.nickname = "小满"
        redactApp.consent = "declined"
        redactApp.publish(JournalStore(preview: JournalFile.Body()))
        let publishedRedacted = try XCTUnwrap(JournalFile.snapshot())
        XCTAssertNil(publishedRedacted.birthEpochDay)
        XCTAssertEqual(publishedRedacted.nickname, "")
        XCTAssertEqual(publishedRedacted.consented, false)

        // 2. RecordFile round-trip (healthRegion, CFBoolean rejection, dedupe, askDoctor) + Yearbook sealed capsule redaction
        let srcApp = AppModel(defaults: UserDefaults(suiteName: "wave4-rec-src-\(UUID().uuidString)")!)
        srcApp.consent = Consent.version
        srcApp.today = Day(y: 2026, m: 10, d: 19)
        srcApp.birth = Day(y: 2026, m: 4, d: 2)
        srcApp.healthRegion = .uk
        srcApp.setObservationState(6, "0-0", "抬手", to: .askDoctor)
        let srcBody = JournalFile.Body()
        let exported = RecordFile.json(srcApp, srcBody)
        let dstApp = AppModel(defaults: UserDefaults(suiteName: "wave4-rec-dst-\(UUID().uuidString)")!)
        let dstStore = JournalStore(preview: JournalFile.Body())
        try RecordFile.load(exported, into: dstApp, journal: dstStore)
        XCTAssertEqual(dstApp.healthRegion, .uk)
        XCTAssertEqual(dstApp.observationState(6, "0-0"), .askDoctor)

        let dupId = UUID()
        let dayMs = Day(y: 2026, m: 10, d: 18).date.timeIntervalSince1970 * 1000
        let cfBoolPayload: [String: Any] = [
            "app": "mossling",
            "version": 1,
            "mossling": [
                "settings": [
                    "consent": Consent.version,
                    "birth": true
                ],
                "firsts": [
                    ["id": dupId.uuidString, "title": "A", "at": dayMs],
                    ["id": dupId.uuidString, "title": "B", "at": dayMs + 1000]
                ],
                "logs": [
                    ["type": LogType.diaper, "start": true, "detail": "wet"],
                    ["type": LogType.diaper, "start": dayMs, "detail": "wet"]
                ]
            ]
        ]
        let cfBoolData = try JSONSerialization.data(withJSONObject: cfBoolPayload)
        let cfDstApp = AppModel(defaults: UserDefaults(suiteName: "wave4-cf-\(UUID().uuidString)")!)
        let cfStore = JournalStore(preview: JournalFile.Body())
        try RecordFile.load(cfBoolData, into: cfDstApp, journal: cfStore)
        XCTAssertNil(cfDstApp.birth, "CFBoolean birth must not decode as epochDay 1")
        XCTAssertEqual(cfStore.firsts.count, 1)
        XCTAssertEqual(cfStore.logs.count, 1)

        let secretCap = TimeCapsule(
            title: "未来之信",
            body: "SECRET_UNOPENED_BODY_TOKEN",
            writtenAt: dayMs,
            writtenAgeLabel: "6m",
            unlockEpochDay: srcApp.today.plus(days: -5).epochDay,
            openedAt: nil,
            seal: .gold
        )
        let ybSections = GrowthYearbookPDF.buildSections(app: srcApp, j: dstStore, foods: [], capsules: [secretCap])
        let joinedYb = ybSections.flatMap(\.lines).joined(separator: "\n")
        XCTAssertFalse(joinedYb.contains("SECRET_UNOPENED_BODY_TOKEN"))

        // 3. LocalizedHealthSchedule accuracy
        XCTAssertFalse(HealthRegion.schedule(for: .us, month: 1).isEmpty)
        let us24 = HealthRegion.schedule(for: .us, month: 24).map(\.title).joined(separator: " ")
        XCTAssertFalse(us24.localizedCaseInsensitiveContains("blood pressure"))
        XCTAssertFalse(us24.contains("血压"))
        XCTAssertTrue(HealthRegion.schedule(for: .uk, month: 6).isEmpty)
        XCTAssertFalse(HealthRegion.schedule(for: .uk, month: 3).isEmpty)
        XCTAssertFalse(HealthRegion.schedule(for: .uk, month: 4).isEmpty)
        XCTAssertFalse(HealthRegion.schedule(for: .uk, month: 18).isEmpty)
        let ukNext = HealthRegion.daysUntilNextCheckup(birth: Day(y: 2026, m: 8, d: 1), today: Day(y: 2026, m: 10, d: 10), region: .uk)
        let cnNext = HealthRegion.daysUntilNextCheckup(birth: Day(y: 2026, m: 8, d: 1), today: Day(y: 2026, m: 10, d: 10), region: .cn)
        XCTAssertNotNil(ukNext)
        XCTAssertNotNil(cnNext)

        // 4. WCAG contrast >= 4.5 across Palette + Crayons in light & dark modes
        let paper = Color(hex: 0xFBF7F0)
        let darkCard = Color(hex: 0x19213F)
        let white = Color.white
        func lin(_ v: CGFloat) -> Double {
            let x = max(0, min(1, Double(v)))
            return x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)
        }
        func cr(_ a: Color, _ b: Color, _ style: UIUserInterfaceStyle) -> Double {
            let tr = UITraitCollection(userInterfaceStyle: style)
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
            UIColor(a).resolvedColor(with: tr).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            UIColor(b).resolvedColor(with: tr).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
            let l1 = 0.2126 * lin(r1) + 0.7152 * lin(g1) + 0.0722 * lin(b1)
            let l2 = 0.2126 * lin(r2) + 0.7152 * lin(g2) + 0.0722 * lin(b2)
            return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
        }
        let paletteAuditColors = [Palette.accent, Palette.danger, Palette.caution, Palette.rod, Palette.bead, Palette.amber, Crayon.teal, Crayon.cherry, Crayon.sky, Crayon.tangerine, Crayon.lilac, Crayon.pink, Crayon.leaf, Crayon.sunflower, Crayon.peach, Crayon.aqua, Crayon.caramel]
        for col in paletteAuditColors {
            XCTAssertGreaterThanOrEqual(cr(Crayon.ink(col), paper, .light), 4.5)
            XCTAssertGreaterThanOrEqual(cr(Crayon.ink(col), darkCard, .dark), 4.5)
            XCTAssertGreaterThanOrEqual(cr(Crayon.buttonFill(col), white, .light), 4.5)
            XCTAssertGreaterThanOrEqual(cr(Crayon.buttonFill(col), white, .dark), 4.5)
        }

        // 5. Handover 24h cross-midnight retention (23:30 yesterday -> 01:15 today)
        let dYest = Day(y: 2026, m: 10, d: 18)
        let dToday = Day(y: 2026, m: 10, d: 19)
        let tempTime = try XCTUnwrap(Day.cal.date(bySettingHour: 23, minute: 30, second: 0, of: dYest.date))
        let medTime = try XCTUnwrap(Day.cal.date(bySettingHour: 23, minute: 45, second: 0, of: dYest.date))
        let nowAfterMidnight = try XCTUnwrap(Day.cal.date(bySettingHour: 1, minute: 15, second: 0, of: dToday.date))
        var midnightBody = JournalFile.Body()
        midnightBody.logs = [
            LogEntry(type: LogType.temp, start: tempTime.timeIntervalSince1970 * 1000, amount: 385),
            LogEntry(type: LogType.medicine, start: medTime.timeIntervalSince1970 * 1000, detail: "布洛芬")
        ]
        let handover = HandoverSnapshot.build(app: srcApp, journal: JournalStore(preview: midnightBody), day: dToday, now: nowAfterMidnight)
        XCTAssertEqual(handover.careAlerts.count, 2)
        XCTAssertTrue(handover.careAlerts.joined(separator: " ").contains("38.5"))
        XCTAssertTrue(handover.careAlerts.joined(separator: " ").contains("布洛芬"))

        // 6. PalmPatRhythm & MidnightCareSummary 06:00 daytime boundary
        XCTAssertEqual(PalmPatRhythm.bpmFromTapTimestamps([0.0, 2.0, 4.0]), 46.0)
        XCTAssertEqual(PalmPatRhythm.bpmFromTapTimestamps([0.0, 0.5, 1.0]), 72.0)
        let morning630 = try XCTUnwrap(Day.cal.date(bySettingHour: 6, minute: 30, second: 0, of: dToday.date))
        let bottle610 = try XCTUnwrap(Day.cal.date(bySettingHour: 6, minute: 10, second: 0, of: dToday.date))
        let morningSummary = MidnightCareSummary.build(
            logs: [LogEntry(type: LogType.bottle, start: bottle610.timeIntervalSince1970 * 1000, amount: 120)],
            now: morning630
        )
        XCTAssertTrue(morningSummary.nightStatusLine?.contains("今日") == true)

        // 7. RhythmDialModel incomplete today exclusion
        let d2 = Day(y: 2026, m: 10, d: 18)
        let d3 = Day(y: 2026, m: 10, d: 19)
        let sCompleted = LogEntry(type: LogType.sleep, start: Day.cal.date(bySettingHour: 10, minute: 0, second: 0, of: d2.date)!.timeIntervalSince1970 * 1000, end: Day.cal.date(bySettingHour: 20, minute: 0, second: 0, of: d2.date)!.timeIntervalSince1970 * 1000)
        let sPartialToday = LogEntry(type: LogType.sleep, start: Day.cal.date(bySettingHour: 1, minute: 0, second: 0, of: d3.date)!.timeIntervalSince1970 * 1000, end: Day.cal.date(bySettingHour: 2, minute: 0, second: 0, of: d3.date)!.timeIntervalSince1970 * 1000)
        let inclDial = RhythmDialModel.build(logs: [sCompleted, sPartialToday], today: d3, days: 2, excludeIncompleteToday: false)
        let exclDial = RhythmDialModel.build(logs: [sCompleted, sPartialToday], today: d3, days: 2, excludeIncompleteToday: true)
        XCTAssertEqual(inclDial.summary.avgSleepHours ?? 0, 5.5, accuracy: 0.05)
        XCTAssertEqual(exclDial.summary.avgSleepHours ?? 0, 10.0, accuracy: 0.05)

        // 8. CareWatchSummary, is3AMSanctuaryActive, consentHostStack, & non-destructive AppRouter
        let watch = CareWatchSummary.recent24h(in: midnightBody.logs, now: nowAfterMidnight)
        XCTAssertTrue(watch.hasFever)
        XCTAssertTrue(watch.hasActivity)
        let hostA = UUID(), hostB = UUID()
        srcApp.consentHostStack = [hostA, hostB]
        XCTAssertEqual(srcApp.consentHostStack.last, hostB)
        srcApp.isLateNightWindow = true
        srcApp.manual3AMOverride = nil
        XCTAssertTrue(srcApp.is3AMSanctuaryActive)
        srcApp.manual3AMOverride = false
        XCTAssertFalse(srcApp.is3AMSanctuaryActive)

        let router = AppRouter()
        router.selectedTab = AppTab.lamp.rawValue
        router.openLamp(.stats)
        XCTAssertFalse(router.lampPath.isEmpty)
        router.openBedsideLamp()
        XCTAssertEqual(router.selectedTab, AppTab.lamp.rawValue)
        XCTAssertTrue(router.showingBedsideLamp)
        XCTAssertFalse(router.lampPath.isEmpty)
        router.selectedTab = AppTab.studio.rawValue
        router.openStorybook()
        XCTAssertEqual(router.selectedTab, AppTab.studio.rawValue)
        XCTAssertTrue(router.showingStorybook)

        // 9. Clinical term localization covers every catalog item
        for card in LampCardCatalog.all {
            for term in card.clinicalTerms {
                XCTAssertNotEqual(LampCard.localizedClinicalTerm(term), term, "Missing Chinese localization for clinical term '\(term)'")
            }
        }
    }
}
