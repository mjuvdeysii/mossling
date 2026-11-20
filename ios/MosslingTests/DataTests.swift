import XCTest
@testable import Mossling

/// The export holds everything recorded, reads back the same, and the readable record says what was recorded.
@MainActor
final class DataTests: XCTestCase {
    private func model() -> AppModel {
        let m = AppModel(defaults: UserDefaults(suiteName: "data-\(UUID().uuidString)")!)
        m.consent = Consent.version   // a guardian who agreed: ticks are kept only with consent
        m.today = Day(y: 2026, m: 10, d: 19)
        m.birth = Day(y: 2026, m: 4, d: 2); m.sex = "girl"; m.nickname = "小满"; m.companion = .otto
        m.shelf = "6|2026-10-13|A11,A08"; m.theme = .dark; m.look = "girl"
        m.toggle(6, TickKind.observed, "o1", "会翻身"); m.toggle(6, TickKind.vaccine, "v1", "脊灰疫苗")
        return m
    }
    private func body() -> JournalFile.Body {
        var b = JournalFile.Body()
        let t0 = Day(y: 2026, m: 10, d: 18).date.timeIntervalSince1970 * 1000
        b.logs = [LogEntry(type: LogType.nurse, start: t0 + 3_600_000, end: t0 + 3_600_000 + 15 * 60_000, side: "l"),
                  LogEntry(type: LogType.bottle, start: t0 + 7_200_000, amount: 125, detail: "formula"),
                  LogEntry(type: LogType.diaper, start: t0 + 9_000_000, detail: "both")]
        b.measures = [Measure(at: t0, weightG: 7400, lengthMm: 655, headMm: 425)]
        b.timers = [RunningTimer(type: LogType.sleep, start: t0 + 20_000_000, pausedTotal: 60_000)]
        return b
    }

    func testBackupHoldsEverythingAndReadsBack() throws {
        let a = model(), data = RecordFile.json(a, body())
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let m = try XCTUnwrap(root["mossling"] as? [String: Any]), s = try XCTUnwrap(m["settings"] as? [String: Any])
        XCTAssertEqual(s["shelf"] as? String, "6|2026-10-13|A11,A08"); XCTAssertEqual(s["theme"] as? String, "dark"); XCTAssertEqual(s["look"] as? String, "girl")
        XCTAssertEqual((m["timers"] as? [Any])?.count, 1)
        XCTAssertEqual((m["logs"] as? [Any])?.count, 3); XCTAssertEqual((m["ticks"] as? [Any])?.count, 2)

        JournalFile.beginTest(); defer { JournalFile.endTest() }
        let b = model(); b.shelf = ""; b.theme = .system
        let j = JournalStore(preview: JournalFile.Body())
        try RecordFile.load(data, into: b, journal: j)
        XCTAssertEqual(b.shelf, a.shelf); XCTAssertEqual(b.theme, .dark); XCTAssertEqual(b.companion, .otto)
        XCTAssertEqual(j.logs.count, 3); XCTAssertEqual(j.timers.count, 1); XCTAssertEqual(j.timers.first?.pausedTotal, 60_000)
        XCTAssertEqual(j.measures.first?.weightG, 7400)
    }

    func testReadableRecordForDoctorOrAI() throws {
        let text = try XCTUnwrap(String(data: RecordFile.summary(model(), body()), encoding: .utf8))
        for part in ["# 摸索台灯 · 成长与照护记录", "小满", "2026-04-02", "## 生长测量", "7.40", "百分位", "## 每天汇总", "125 毫升", "## 每个月记下的事", "会翻身", "脊灰疫苗", "## 全部记录", "左侧", "正在计时"] {
            XCTAssertTrue(text.contains(part), "missing: \(part)")
        }
        XCTAssertFalse(text.contains("诊断为"), "the record makes no assessment")
    }

    func testCsvDeductsPausedDuration() throws {
        var b = JournalFile.Body()
        let start = Day(y: 2026, m: 10, d: 18).date.timeIntervalSince1970 * 1000 + 3_600_000
        // 20 minutes elapsed, 5 minutes paused -> 15 active minutes
        b.logs = [LogEntry(type: LogType.nurse, start: start, end: start + 20 * 60_000, side: "l", detail: "paused:300000")]
        let csv = try XCTUnwrap(String(data: RecordFile.csv(b), encoding: .utf8))
        let rows = csv.split(separator: "\n")
        XCTAssertEqual(rows.count, 2)
        let cols = rows[1].split(separator: ",", omittingEmptySubsequences: false)
        XCTAssertEqual(cols[3], "15", "CSV duration must exclude paused minutes")
    }

    func testImportSanitizesResetsMissingFieldsAndFailsAtomically() throws {
        JournalFile.beginTest(); defer { JournalFile.endTest() }
        let payload: [String: Any] = [
            "app": "mossling",
            "mossling": [
                "settings": ["birth": "2026-02-30"],
                "measures": [
                    ["at": 1_760_000_000_000.0, "weightG": 0, "lengthMm": -10],
                    ["at": 1_760_086_400_000.0, "weightG": 7500, "headMm": -5]
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let app = model()
        let j = JournalStore(preview: JournalFile.Body())

        // disk failure leaves existing settings untouched
        JournalFile.failWrites = true
        XCTAssertThrowsError(try RecordFile.load(data, into: app, journal: j))
        XCTAssertEqual(app.nickname, "小满", "failed journal write must not mutate AppModel settings")
        JournalFile.failWrites = false

        try RecordFile.load(data, into: app, journal: j)
        XCTAssertNil(app.birth, "invalid birth date is ignored and previous birth is cleared")
        XCTAssertNil(app.look, "absent look resets previous value")
        XCTAssertEqual(app.shelf, "", "absent shelf resets previous value")
        XCTAssertEqual(j.measures.count, 1)
        XCTAssertEqual(j.measures.first?.weightG, 7500)
        XCTAssertNil(j.measures.first?.headMm)
    }

    func testSummaryPreGroupingHandlesOvernightCarryover() throws {
        let app = model()
        let today = Day.today
        let yesterday = today.plus(days: -1)
        // Sleep from yesterday 23:00 to today 01:00 (1 hour on each day)
        let start = (yesterday.date.timeIntervalSince1970 + 23 * 3600) * 1000
        let end = (today.date.timeIntervalSince1970 + 1 * 3600) * 1000
        var b = JournalFile.Body()
        b.logs = [LogEntry(type: LogType.sleep, start: start, end: end)]
        let md = try XCTUnwrap(String(data: RecordFile.summary(app, b), encoding: .utf8))
        let yRow = String(format: "| %04d-%02d-%02d ", yesterday.y, yesterday.m, yesterday.d)
        let tRow = String(format: "| %04d-%02d-%02d ", today.y, today.m, today.d)
        XCTAssertTrue(md.contains(yRow), "summary must include start day row")
        XCTAssertTrue(md.contains(tRow), "summary must include overnight carryover day row")
    }

    func testQuickLogDiaperPersistsUnderCoordination() throws {
        JournalFile.beginTest(); defer { JournalFile.endTest() }
        let after = JournalFile.quickLog(type: LogType.diaper, detail: "wet", at: 1_760_000_000_000)
        XCTAssertEqual(after.logs.count, 1)
        XCTAssertEqual(after.logs.first?.type, LogType.diaper)
        XCTAssertEqual(after.logs.first?.detail, "wet")
        let reloaded = try JournalFile.load()
        XCTAssertEqual(reloaded.logs.count, 1)
    }

    func testUndoRecentDiaperAndCycleWidgetPlay() throws {
        JournalFile.beginTest(); defer { JournalFile.endTest() }
        let now: Double = 1_760_000_000_000
        _ = JournalFile.quickLog(type: LogType.diaper, detail: "wet", at: now - 5_000)
        XCTAssertTrue(JournalFile.undoRecent(type: LogType.diaper, withinSeconds: 30, now: now))
        XCTAssertEqual(try JournalFile.load().logs.count, 0)

        // Entries older than the undo window are preserved
        _ = JournalFile.quickLog(type: LogType.diaper, detail: "dirty", at: now - 120_000)
        XCTAssertFalse(JournalFile.undoRecent(type: LogType.diaper, withinSeconds: 30, now: now))
        XCTAssertEqual(try JournalFile.load().logs.count, 1)

        // Cycling widget play rotates cleanly through weekPlays
        let pool = [PlayRef(code: "A01", name: "一"), PlayRef(code: "A02", name: "二"), PlayRef(code: "A03", name: "三")]
        JournalFile.writeSnapshot(Snapshot(birthEpochDay: nil, nickname: "", companion: "Moss", journal: true, playCode: "A01", playName: "一", consented: true, weekPlays: pool))
        let next = JournalFile.cycleWidgetPlay()
        XCTAssertEqual(next?.playCode, "A02")
        XCTAssertEqual(JournalFile.cycleWidgetPlay()?.playCode, "A03")
        XCTAssertEqual(JournalFile.cycleWidgetPlay()?.playCode, "A01")

        L10n.overrideEnglish = true; defer { L10n.overrideEnglish = nil }
        XCTAssertEqual(L10n.logName(LogType.nurse), "Nurse")
        XCTAssertEqual(L10n.duration(5400), "1h 30m")
    }
}
