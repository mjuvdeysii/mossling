import XCTest
import SwiftUI
@testable import Mossling

/// Renders each screen in the simulator and writes a PNG to $SNAPSHOT_DIR (set by CI) for review.
@MainActor
final class ScreenshotTests: XCTestCase {
    // the journal in these shots is in memory; nothing is written
    private func model(companion: Kind = .moss, birth: Day? = Day(y: 2026, m: 4, d: 2)) -> AppModel {
        let d = UserDefaults(suiteName: "shots-\(UUID().uuidString)")!
        let m = AppModel(defaults: d)
        m.today = Day(y: 2026, m: 10, d: 19)
        m.birth = birth
        m.companion = companion
        m.nickname = "小满"
        m.sex = "girl"
        m.toggle(6, TickKind.did, "A11", "双手物品传递机会")
        return m
    }

    private func shot<V: View>(_ name: String, dark: Bool = false, height: CGFloat = 852, _ view: V) {
        let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()
        let host = UIHostingController(rootView: view.environment(\.colorScheme, dark ? .dark : .light))
        let size = CGSize(width: 393, height: height)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        // let images decode and tasks settle
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        let img = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 3; return f }()).image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? img.pngData()?.write(to: URL(fileURLWithPath: dir).appendingPathComponent("ios_\(name).png"))
        window.isHidden = true
    }

    private func at(_ h: Int, _ mi: Int) -> Double { ms(Day.cal.date(bySettingHour: h, minute: mi, second: 0, of: Day(y: 2026, m: 10, d: 19).date)!) }
    private lazy var journal: JournalStore = {
        var b = JournalFile.Body()
        b.logs = [LogEntry(type: LogType.bottle, start: self.at(19, 40), amount: 120), LogEntry(type: LogType.diaper, start: self.at(18, 5), detail: "wet"),
                  LogEntry(type: LogType.nurse, start: self.at(16, 10), end: self.at(16, 28), side: "l"), LogEntry(type: LogType.sleep, start: self.at(13, 0), end: self.at(14, 35)),
                  LogEntry(type: LogType.bath, start: self.at(10, 20)), LogEntry(type: LogType.solid, start: self.at(11, 30), detail: "米粉")]
        b.measures = [Measure(at: self.at(9, 0) - 200 * 86_400_000, weightG: 3300, lengthMm: 500, headMm: 340), Measure(at: self.at(9, 0) - 140 * 86_400_000, weightG: 5400, lengthMm: 580, headMm: 385),
                      Measure(at: self.at(9, 0) - 80 * 86_400_000, weightG: 6600, lengthMm: 625, headMm: 410), Measure(at: self.at(9, 0) - 10 * 86_400_000, weightG: 7400, lengthMm: 655, headMm: 425)]
        b.timers = [RunningTimer(type: LogType.nurse, start: ms(Date()) - 12 * 60_000, side: "l")]
        return JournalStore(preview: b)
    }()

    private func tabs(_ m: AppModel, _ tab: some View) -> some View {
        NavigationStack { tab }.environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded)
    }

    func test01Onboarding() { let m = model(birth: nil); m.onboarded = false; shot("01_onboarding", OnboardingView().environment(m).tint(Palette.accent).fontDesign(.rounded)) }
    func test02Today() { let m = model(); shot("02_today", height: 1500, tabs(m, TodayView(path: .constant(NavigationPath())))) }
    func test03TodayOtto() { let m = model(companion: .otto); shot("03_today_otto_dark", dark: true, height: 1500, tabs(m, TodayView(path: .constant(NavigationPath())))) }
    func test04TodayNoBirth() { let m = model(birth: nil); m.onboarded = true; shot("04_today_nobirth", tabs(m, TodayView(path: .constant(NavigationPath())))) }
    func test05Journey() { let m = model(); shot("05_journey", height: 1600, tabs(m, JourneyView(path: .constant(NavigationPath())))) }
    func test05JourneyDark() { let m = model(companion: .otto); shot("05_journey_dark", dark: true, tabs(m, JourneyView(path: .constant(NavigationPath())))) }
    func test06Play() { let m = model(); shot("06_play", height: 2000, tabs(m, PlayView(play: m.content.play("A11")!, month: 6))) }
    func test07Month() { let m = model(); shot("07_month", height: 3200, tabs(m, MonthView(month: 6))) }
    func test07MonthDark() { let m = model(); shot("07_month_dark", dark: true, height: 1400, tabs(m, MonthView(month: 6))) }
    func test07Observe() { let m = model(); shot("07_observe", height: 1400, tabs(m, ObserveView(month: 6))) }
    func test06PlayDark() { let m = model(); shot("06_play_dark", dark: true, height: 1400, tabs(m, PlayView(play: m.content.play("A11")!, month: 6))) }
    func test15JournalDark() { let m = model(); m.journal = true; shot("15_journal_dark", dark: true, height: 1500, tabs(m, JournalView(path: .constant(NavigationPath())))) }
    func test20Search() { let m = model(); shot("20_you_dark", dark: true, height: 1300, tabs(m, YouView(path: .constant(NavigationPath())))) }
    func test08You() { let m = model(); shot("08_you", height: 1300, tabs(m, YouView(path: .constant(NavigationPath())))) }
    func test09About() { let m = model(); shot("09_about", tabs(m, AboutView())) }
    func test10Topic() { let m = model(); shot("10_topic", height: 1600, tabs(m, TopicView(topic: m.content.topics[0]))) }
    func test11Plan() { let m = model(); shot("11_plan", tabs(m, PlanView(path: .constant(NavigationPath())))) }
    private var characters: some View {
        VStack(spacing: 20) {
            HStack { Creature(kind: .moss).frame(width: 170); Creature(kind: .otto, mood: .happy).frame(width: 170) }
            HStack { Creature(kind: .moss, mood: .wow, look: CGPoint(x: 0.8, y: -0.4)).frame(width: 110); Creature(kind: .otto, look: CGPoint(x: -0.9, y: 0.4), lid: 0.5).frame(width: 110); Creature(kind: .moss, mood: .sleep).frame(width: 110) }
            Duo(primary: .moss, size: 120)
            Duo(primary: .otto, size: 120, mood: .sleep)
            StoryGoesOn(primary: .moss).padding(.horizontal)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.background)
    }
    func test12Characters() { shot("12_characters", height: 1100, characters) }
    func test12CharactersDark() { shot("12_characters_dark", dark: true, height: 1100, characters) }
    func test13Doc() { let m = model(); shot("13_terms", height: 1400, tabs(m, DocView(name: "TERMS"))) }
    func test15Journal() { let m = model(); m.journal = true; shot("15_journal", height: 1700, tabs(m, JournalView(path: .constant(NavigationPath())))) }
    func test16Growth() { let m = model(); shot("16_growth", height: 1700, tabs(m, GrowthView())) }
    func test17Stats() { let m = model(); shot("17_stats", height: 900, tabs(m, StatsView())) }
    func test18Ask() { let m = model(); shot("18_ask_bottle", tabs(m, AskSheet(type: LogType.bottle))) }
    func test19Entry() { let m = model(); shot("19_entry", tabs(m, EntrySheet(entry: LogEntry(type: LogType.nurse, start: at(16, 10), end: at(16, 28), side: "l"), isNew: false))) }
    func test14Month36() { let m = model(); shot("14_month36", height: 3400, tabs(m, MonthView(month: 36))) }
}
