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
}
