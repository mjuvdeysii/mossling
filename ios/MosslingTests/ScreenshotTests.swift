import XCTest
import SwiftUI
@testable import Mossling

/// Renders each screen in the simulator and writes a PNG to $SNAPSHOT_DIR (set by CI) for review.
@MainActor
final class ScreenshotTests: XCTestCase {
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

    private func tabs(_ m: AppModel, _ tab: some View) -> some View {
        NavigationStack { tab }.environment(m).tint(Palette.primary)
    }

    func test01Onboarding() { let m = model(birth: nil); m.onboarded = false; shot("01_onboarding", OnboardingView().environment(m)) }
    func test02Today() { let m = model(); shot("02_today", tabs(m, TodayView(path: .constant(NavigationPath())))) }
    func test03TodayOtto() { let m = model(companion: .otto); shot("03_today_otto_dark", dark: true, tabs(m, TodayView(path: .constant(NavigationPath())))) }
    func test04TodayNoBirth() { let m = model(birth: nil); m.onboarded = true; shot("04_today_nobirth", tabs(m, TodayView(path: .constant(NavigationPath())))) }
    func test05Grow() { let m = model(); shot("05_grow", height: 2400, tabs(m, ScrollView { MonthContent(month: 6, path: .constant(NavigationPath())) }.background(Palette.background))) }
    func test06Play() { let m = model(); shot("06_play", height: 2000, tabs(m, PlayView(play: m.content.play("A11")!, month: 6))) }
    func test07Map() { let m = model(); shot("07_map", tabs(m, MapView(path: .constant(NavigationPath())))) }
    func test08You() { let m = model(); shot("08_you", height: 1300, tabs(m, YouView(path: .constant(NavigationPath())))) }
    func test09About() { let m = model(); shot("09_about", tabs(m, AboutView())) }
    func test10Topic() { let m = model(); shot("10_topic", height: 1600, tabs(m, TopicView(topic: m.content.topics[0]))) }
    func test11Plan() { let m = model(); shot("11_plan", tabs(m, PlanView(path: .constant(NavigationPath())))) }
    func test12Characters() {
        shot("12_characters", height: 700, VStack(spacing: 20) {
            HStack { Creature(kind: .moss).frame(width: 150); Creature(kind: .otto).frame(width: 150) }
            Duo(primary: .moss, size: 120)
            Duo(primary: .otto, size: 120, mood: .sleep)
            StoryGoesOn(primary: .moss).padding(.horizontal)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.background))
    }
    func test13Doc() { let m = model(); shot("13_terms", height: 1400, tabs(m, DocView(name: "TERMS"))) }
    func test14Month36() { let m = model(); shot("14_month36", height: 2600, tabs(m, ScrollView { MonthContent(month: 36, path: .constant(NavigationPath())) }.background(Palette.background))) }
}
