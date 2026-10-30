import XCTest
@testable import Mossling

/// The IP v1.3 contract for Moss and Otto: events in, presentation states out, no words, no reply to a failure, and
/// the same behaviour whichever companion is in front.
@MainActor
final class MascotTests: XCTestCase {
    override func tearDown() { JournalFile.failWrites = false; super.tearDown() }

    func testEventContract() {
        let m = MascotMachine.self
        XCTAssertEqual(m.next(.idle, .recordStartConfirmed, night: false, timing: true), .focusing)
        XCTAssertEqual(m.next(.idle, .recordPersistSuccess, night: false, timing: false), .acknowledge)
        XCTAssertEqual(m.next(.focusing, .recordPersistFailure, night: false, timing: true), .focusing)
        XCTAssertEqual(m.next(.idle, .recordPersistFailure, night: false, timing: false), .idle)
        XCTAssertEqual(m.next(.idle, .activityRecommendationChanged, night: false, timing: false), .observing)
        XCTAssertEqual(m.next(.idle, .nightmodeEnabled, night: true, timing: false), .rest)
        XCTAssertEqual(m.next(.rest, .nightmodeDisabled, night: false, timing: false), .idle)
        for s in MascotPresentationState.allCases {
            XCTAssertEqual(m.next(s, .companionChanged, night: false, timing: false), s, "companion.changed is appearance only")
        }
        XCTAssertEqual(m.next(.focusing, .appBackground, night: false, timing: true), .dormant)
        XCTAssertEqual(m.next(.dormant, .appActive, night: false, timing: false), .idle, "back from the background: neutral")
        XCTAssertEqual(m.next(.dormant, .recordPersistSuccess, night: false, timing: false), .dormant, "nothing plays in the background")
    }

    func testAFailureIsNeverCelebrated() {
        for s in MascotPresentationState.allCases {
            for night in [false, true] {
                XCTAssertNotEqual(MascotMachine.next(s, .recordPersistFailure, night: night, timing: false), .acknowledge)
            }
        }
        let d = MascotDirector()
        d.send(.recordPersistFailure)
        XCTAssertEqual(d.acknowledgements, 0)
        XCTAssertEqual(d.state, .idle)
    }

    func testNightRestsAndDoesNotPerformForRecommendations() {
        let d = MascotDirector()
        d.send(.nightmodeEnabled)
        XCTAssertEqual(d.state, .rest)
        d.send(.activityRecommendationChanged)
        XCTAssertEqual(d.state, .rest)
        XCTAssertEqual(d.observations, 0)
    }

    func testBothCompanionsRunTheSameStates() {
        let events: [MascotEvent] = [.recordStartConfirmed, .recordPersistFailure, .timerEnded, .recordPersistSuccess, .settle,
                                     .activityRecommendationChanged, .settle, .nightmodeEnabled, .recordPersistSuccess, .settle, .nightmodeDisabled]
        func run(_ k: Kind) -> [MascotPresentationState] {
            let d = MascotDirector(); d.companion = k
            return events.map { e in d.timing = e == .recordStartConfirmed; d.send(e); return d.state }
        }
        XCTAssertEqual(run(.moss), run(.otto))
    }

    func testTimingsAndNoWords() {
        for k in Kind.allCases {
            let s = MascotStyle.of(k)
            XCTAssertLessThanOrEqual(s.acknowledgeMs, 550); XCTAssertGreaterThanOrEqual(s.acknowledgeMs, 300)
            XCTAssertTrue((180...300).contains(s.glanceMs)); XCTAssertTrue((90...180).contains(s.blinkMs))
            XCTAssertTrue((2...5).contains(s.tiltDegrees))
            let fields = Mirror(reflecting: s).children.compactMap { $0.label?.lowercased() }
            for banned in ["speech", "dialogue", "bubble", "text", "line", "say"] {
                XCTAssertFalse(fields.contains { $0.contains(banned) }, "\(k) style has a field for words: \(banned)")
            }
        }
        XCTAssertEqual(MascotStyle.moss.glanceStages, 2); XCTAssertEqual(MascotStyle.otto.glanceStages, 1)
        XCTAssertGreaterThan(MascotStyle.otto.glanceMs, MascotStyle.moss.glanceMs, "Otto looks slowly, Moss quickly")
    }

    func testAcknowledgeIsShortAndOnce() async throws {
        let d = MascotDirector(); d.companion = .otto
        d.send(.recordPersistSuccess)
        XCTAssertEqual(d.state, .acknowledge); XCTAssertEqual(d.acknowledgements, 1)
        try await Task.sleep(for: .milliseconds(800))
        XCTAssertEqual(d.state, .idle)
        XCTAssertEqual(d.acknowledgements, 1, "one reply per save")
    }

    // MARK: the journal only reports what really happened

    private func store() -> (JournalStore, Box) {
        let j = JournalStore(preview: JournalFile.Body())
        let box = Box()
        j.onEvent = { box.events.append($0) }
        return (j, box)
    }
    final class Box { var events: [MascotEvent] = [] }

    func testAFailedSaveSaysSoAndKeepsQuiet() {
        let (j, box) = store()
        JournalFile.failWrites = true
        let before = j.logs.count
        XCTAssertFalse(j.record(LogEntry(type: LogType.diaper, start: JournalFile.now(), detail: "wet")))
        XCTAssertEqual(j.logs.count, before, "nothing shown that was not saved")
        XCTAssertEqual(box.events, [.recordPersistFailure])
        XCTAssertEqual(j.toast?.failed, true)
        XCTAssertNil(j.toast?.restore, "no undo for something that did not happen")
        XCTAssertTrue(j.toast?.text.hasPrefix("没有保存成功") ?? false)
    }

    func testATimerStartsOnlyWhenItIsInTheFile() {
        JournalFile.beginTest(); defer { JournalFile.endTest() }
        let (j, box) = store()
        JournalFile.failWrites = true
        j.start(LogType.sleep)
        XCTAssertFalse(box.events.contains(.recordStartConfirmed))
        XCTAssertEqual(box.events.last, .recordPersistFailure)
        XCTAssertNil(j.focus)
    }

    func testEndingTwiceKeepsOneEntryAndOneReply() {
        JournalFile.beginTest(); defer { JournalFile.endTest() }
        let (j, box) = store()
        j.reload()
        j.start(LogType.sleep, at: Date().addingTimeInterval(-600))
        XCTAssertEqual(box.events, [.recordStartConfirmed])
        j.stop(LogType.sleep); j.stop(LogType.sleep)
        XCTAssertEqual(j.logs.filter { $0.type == LogType.sleep }.count, 1)
        XCTAssertEqual(box.events.filter { $0 == .recordPersistSuccess }.count, 1)
    }

    /// The figures are rendered states; the view picks one from the face and the look, and every state has its picture.
    func testSpriteStates() {
        let st = Creature.state
        XCTAssertEqual(st(.moss, .open, CGPoint(x: -0.9, y: 0), 0, false, false), "left")
        XCTAssertEqual(st(.moss, .open, CGPoint(x: 0.7, y: 0.2), 0, false, false), "right")
        XCTAssertEqual(st(.otto, .open, CGPoint(x: 0, y: -0.8), 0, false, false), "up")
        XCTAssertEqual(st(.otto, .open, CGPoint(x: 0.1, y: 1), 0, false, false), "down")
        XCTAssertEqual(st(.moss, .open, .zero, 1, false, false), "blink")
        XCTAssertEqual(st(.otto, .open, .zero, 0, false, true), "yawn")
        XCTAssertEqual(st(.moss, .open, .zero, 0, false, true), "idle", "only Otto yawns")
        XCTAssertEqual(st(.moss, .happy, .zero, 0, true, false), "hop")
        XCTAssertEqual(st(.otto, .sleep, .zero, 0, false, false), "sleep")
        for (kind, names) in Creature.states {
            for n in names {
                let file = "ip_\(kind == .moss ? "moss" : "otto")_\(n).webp"
                XCTAssertNotNil(ArtCache.shared.image(file, maxPixel: 256), "missing \(file)")
            }
        }
        XCTAssertNotNil(Sprites.bead["idle"])
    }
}
