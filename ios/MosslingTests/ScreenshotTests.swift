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
        m.consent = Consent.version
        m.toggle(6, TickKind.did, "A11", "双手物品传递机会")
        return m
    }

    private func shot<V: View>(_ name: String, dark: Bool = false, height: CGFloat = 852, width: CGFloat = 393, window whole: Bool = false, lamp: Bool = false, settle: Double = 1.2, _ view: V) {
        let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()
        // lamp: the phone in light mode with the lamp on — the app darkens its window then (RootView), so do the same
        let host = UIHostingController(rootView: view.environment(\.colorScheme, dark || lamp ? .dark : .light).preferredColorScheme(lamp ? .dark : nil))
        let size = CGSize(width: width, height: height)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.overrideUserInterfaceStyle = dark || lamp ? .dark : .light   // the app darkens its window under the lamp
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        // let images decode and tasks settle
        RunLoop.main.run(until: Date().addingTimeInterval(settle))
        let img = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 3; return f }()).image { _ in
            // the whole window includes a presented sheet, as on the phone
            if whole, let sheet = host.presentedViewController?.view {
                // the presented page, where it sits on the screen, over the page under it
                host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
                sheet.drawHierarchy(in: sheet.convert(sheet.bounds, to: nil), afterScreenUpdates: true)
            } else { host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true) }
        }
        // an empty picture is a failed shot, not a pass (a page taller than the renderer's 8192-pixel limit draws nothing)
        XCTAssertTrue(Self.drewSomething(img), "ios_\(name) came out empty")
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? img.pngData()?.write(to: URL(fileURLWithPath: dir).appendingPathComponent("ios_\(name).png"))
        window.isHidden = true
    }

    /// Whether any of a grid of sample points is not fully transparent.
    static func drewSomething(_ img: UIImage) -> Bool {
        guard let cg = img.cgImage else { return false }
        let w = 32, h = 32
        var px = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return stride(from: 3, to: px.count, by: 4).contains { px[$0] > 0 }
    }

    private func at(_ h: Int, _ mi: Int) -> Double { ms(Day.cal.date(bySettingHour: h, minute: mi, second: 0, of: Day(y: 2026, m: 10, d: 19).date)!) }
    private lazy var journal: JournalStore = {
        var b = JournalFile.Body()
        b.logs = [LogEntry(type: LogType.bottle, start: self.at(19, 40), amount: 120), LogEntry(type: LogType.diaper, start: self.at(18, 5), detail: "wet"),
                  LogEntry(type: LogType.nurse, start: self.at(16, 10), end: self.at(16, 28), side: "l"),
                  LogEntry(type: LogType.nurse, start: self.at(16, 28), end: self.at(16, 40), side: "r", detail: "paused:120000"), LogEntry(type: LogType.sleep, start: self.at(13, 0), end: self.at(14, 35)),
                  LogEntry(type: LogType.bath, start: self.at(10, 20)), LogEntry(type: LogType.solid, start: self.at(11, 30), detail: "米粉"),
                  LogEntry(type: LogType.sleep, start: self.at(0, 0) - 2 * 3_600_000, end: self.at(6, 30))]
        b.measures = [Measure(at: self.at(9, 0) - 200 * 86_400_000, weightG: 3300, lengthMm: 500, headMm: 340), Measure(at: self.at(9, 0) - 140 * 86_400_000, weightG: 5400, lengthMm: 580, headMm: 385),
                      Measure(at: self.at(9, 0) - 80 * 86_400_000, weightG: 6600, lengthMm: 625, headMm: 410), Measure(at: self.at(9, 0) - 10 * 86_400_000, weightG: 7400, lengthMm: 655, headMm: 425)]
        b.timers = [RunningTimer(type: LogType.nurse, start: ms(Date()) - 12 * 60_000, side: "l")]
        return JournalStore(preview: b)
    }()

    private func tabs(_ m: AppModel, _ tab: some View) -> some View {
        NavigationStack { tab }.environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded)
    }

    /// IP v1.3 first run: shot C, Otto chosen — the page says so, Otto looks down at 填写出生日期, Moss at Otto.
    func test01OnboardingChosen() {
        let m = model(companion: .otto, birth: nil); m.onboarded = false
        shot("01_onboarding_shot_c", settle: 6.5, OnboardingView().environment(m).tint(Palette.accent).fontDesign(.rounded))
    }
    /// The tab bar with the app's own icons: a mint sprig with a bud, Otto's lamp with its halo, Moss.
    func test38TabBar() {
        let m = model(); m.journal = true
        let v = TabView(selection: .constant(0)) {
            Tab("本月", image: "TabMonth", value: 0) { Palette.background }
            Tab("记录", image: "TabJournal", value: 2) { Palette.background }
            Tab("我的", image: "TabMe", value: 3) { Palette.background }
        }
        shot("38_tabbar", height: 300, v.environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded))
        shot("38_tabbar_dark", dark: true, height: 300, v.environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded))
    }
    /// 摸索台灯的故事: the name told (docs/IP.md).
    func test37Story() { let m = model(); shot("37_story", height: 1900, settle: 6, tabs(m, StoryView())) }
    /// The way into the paper world, held still: the wash spreading from the story picture, then drying back.
    func test37Wash() {
        let m = model()
        let pic = CGRect(x: 16, y: 120, width: 361, height: 180)
        for (n, t, light) in [("37_wash_spread", 0.32, false), ("37_wash_dry", 1.1, false), ("37_wash_light", 0.4, true)] {
            shot(n, settle: 0.8, ZStack { tabs(m, AboutView()); Wash(start: .now, frame: pic, impact: CGPoint(x: 0.4, y: 0.5), light: light, at: t).ignoresSafeArea() })
        }
    }
    /// The month's parts for the early months (fewer parts): rows spread evenly, no tile stretched alone.
    func test07MonthParts() {
        let m = model()
        let v = ScrollView { VStack(spacing: 24) { ForEach([0, 1, 2, 3], id: \.self) { k in MonthParts(month: k) } }.padding(16) }
        shot("07_month_parts_early", height: 1300, tabs(m, v))
    }
    func test01OnboardingOpening() {
        // the opening, mid-way: the lamp on, Moss reaching for the rings
        let m = model(birth: nil); m.onboarded = false
        shot("01_onboarding_opening", settle: 2.9, OnboardingView().environment(m).tint(Palette.accent).fontDesign(.rounded))
    }
    /// The guardian's choice on first run: two buttons of equal weight, the documents one tap away.
    func test01Consent() { let m = model(birth: nil); m.consent = ""; shot("01_consent", ConsentSheet().environment(m).tint(Palette.accent).fontDesign(.rounded)) }
    func test01Onboarding() { let m = model(birth: nil); m.onboarded = false; shot("01_onboarding", OnboardingView().environment(m).tint(Palette.accent).fontDesign(.rounded)) }
    func test39Firsts() {
        let m = model()
        let j = journal
        _ = j.saveFirst(First(at: at(10, 0) - 60 * 86_400_000, title: "第一次吃手"))
        _ = j.saveFirst(First(at: at(10, 0) - 20 * 86_400_000, title: "第一次翻身"))
        shot("39_firsts", height: 1500, tabs(m, FirstsView()))
    }
    func test39Firsts2D() {
        let m = model(); ArtStyle.current = .flat; defer { ArtStyle.current = .vinyl }
        shot("39_firsts_2d", height: 1500, tabs(m, FirstsView()))
    }
    /// The day the child turns another month: flags across the month card's sky.
    func test02TodayMonthday() { let m = model(birth: Day(y: 2026, m: 4, d: 19)); shot("02_today_monthday", height: 900, tabs(m, TodayView(path: .constant(NavigationPath())))) }
    func test02Today() { let m = model(); shot("02_today", height: 2500, tabs(m, TodayView(path: .constant(NavigationPath())))) }
    func test02Today2D() {
        let m = model(); ArtStyle.current = .flat; defer { ArtStyle.current = .vinyl }
        shot("02_today_2d", height: 2500, tabs(m, TodayView(path: .constant(NavigationPath()))))
    }
    func test06Play2D() {
        let m = model(); ArtStyle.current = .flat; defer { ArtStyle.current = .vinyl }
        shot("06_play_2d", height: 2000, tabs(m, PlayView(play: m.content.play("A11")!, month: 6)))
    }
    /// The 2D world under the lamp: fireflies over the page (behind the cards), and 2D by day for the drifting air.
    func test31Lamp2D() {
        let m = model(); m.journal = true; ArtStyle.current = .flat; defer { ArtStyle.current = .vinyl }
        shot("31_lamp_home_2d", height: 1200, lamp: true, tabs(m, TodayView(path: .constant(NavigationPath())).lamp(true).environment(\.night, true)))
        shot("31_lamp_journal_2d", height: 1200, lamp: true, tabs(m, JournalView(path: .constant(NavigationPath())).lamp(true)))
    }
    func test15Journal2D() {
        let m = model(); m.journal = true; ArtStyle.current = .flat; defer { ArtStyle.current = .vinyl }
        shot("15_journal_2d", height: 1700, tabs(m, JournalView(path: .constant(NavigationPath()))))
    }
    func test03TodayOtto() { let m = model(companion: .otto); shot("03_today_otto_dark", dark: true, height: 1500, tabs(m, TodayView(path: .constant(NavigationPath())))) }
    func test04TodayNoBirth() { let m = model(birth: nil); m.onboarded = true; shot("04_today_nobirth", tabs(m, TodayView(path: .constant(NavigationPath())))) }
    private func wheel(_ m: AppModel, _ month: Int, night: Bool = false) -> some View {
        GrowthMap(month: .constant(month), baby: 6) {}.padding(16).frame(maxHeight: .infinity, alignment: .top)
            .background(night ? Palette.lampPage : Palette.background).environment(m).environment(\.night, night).tint(Palette.accent).fontDesign(.rounded)
    }
    func test05Wheel() { let m = model(); shot("05_wheel", height: 1680, VStack(spacing: 0) { wheel(m, 1).frame(height: 560); wheel(m, 6).frame(height: 560); wheel(m, 30).frame(height: 560) }) }
    func test05WheelDark() { let m = model(companion: .otto); shot("05_wheel_dark", dark: true, height: 1120, VStack(spacing: 0) { wheel(m, 6, night: true).frame(height: 560); wheel(m, 20, night: true).frame(height: 560) }) }
    func test05Wheel2D() {
        let m = model(); ArtStyle.current = .flat; defer { ArtStyle.current = .vinyl }
        shot("05_wheel_2d", height: 1680, VStack(spacing: 0) { wheel(m, 1).frame(height: 560); wheel(m, 6).frame(height: 560); wheel(m, 6, night: true).frame(height: 560) })
    }
    func test06Play() { let m = model(); shot("06_play", height: 2000, tabs(m, PlayView(play: m.content.play("A11")!, month: 6))) }
    func test07Month() { let m = model(); shot("07_month", height: 2600, tabs(m, MonthView(month: 6))) }
    func test07MonthDark() { let m = model(); shot("07_month_dark", dark: true, height: 1400, tabs(m, MonthView(month: 6))) }
    func test21Search() { let m = model(); shot("21_search", tabs(m, SearchView(path: .constant(NavigationPath())))) }
    func test22Shelf() { let m = model(); shot("22_week_editor", ShelfEditor().environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded)) }
    /// 今天一起玩 when the records say the baby woke 40 minutes ago: the header says so (no card of its own).
    func test02TodayAwake() {
        let m = model(); m.journal = true
        var b = JournalFile.Body()
        let n = ms(Date())
        b.logs = [LogEntry(type: LogType.sleep, start: n - 160 * 60_000, end: n - 40 * 60_000),
                  LogEntry(type: LogType.nurse, start: n - 35 * 60_000, end: n - 22 * 60_000, side: "l"),
                  LogEntry(type: LogType.nurse, start: n - 21 * 60_000, end: n - 12 * 60_000, side: "r")]
        let j = JournalStore(preview: b)
        shot("02_today_awake", height: 1400, NavigationStack { TodayView(path: .constant(NavigationPath())) }.environment(m).environment(j).tint(Palette.accent).fontDesign(.rounded))
    }
    /// While a sleep is timed: the sleep card leads with the companions; 今天一起玩 says 醒来后一起玩, without them.
    func test02TodayAsleep() {
        let m = model(); m.journal = true
        var b = JournalFile.Body()
        b.timers = [RunningTimer(type: LogType.sleep, start: ms(Date()) - 50 * 60_000)]
        let j = JournalStore(preview: b)
        shot("02_today_asleep", height: 1400, NavigationStack { TodayView(path: .constant(NavigationPath())) }.environment(m).environment(j).tint(Palette.accent).fontDesign(.rounded))
    }
    /// The nursing page after a feed of two sides: the last line lists them in order (左侧 → 右侧).
    func test24ReadyNurseBothSides() {
        let m = model(); m.journal = true
        var b = JournalFile.Body()
        let n = ms(Date())
        b.logs = [LogEntry(type: LogType.nurse, start: n - 150 * 60_000, end: n - 132 * 60_000, side: "l"),
                  LogEntry(type: LogType.nurse, start: n - 131 * 60_000, end: n - 120 * 60_000, side: "r")]
        let j = JournalStore(preview: b)
        shot("24_ready_nurse_both", TimerScreen(type: LogType.nurse).environment(m).environment(j).tint(Palette.accent).fontDesign(.rounded))
    }
    func test23Timer() { let m = model(); shot("23_timer", TimerScreen(type: LogType.nurse).environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded)) }
    /// Tapping 亲喂 or 睡觉 opens the page not yet running: pick a side (the one not fed last time is suggested) and when
    /// it began; another clock still running is said here.
    func test24ReadyPages() {
        var b = JournalFile.Body(); let n = ms(Date())
        b.logs = [LogEntry(type: LogType.nurse, start: n - 150 * 60_000, end: n - 130 * 60_000, side: "l")]
        let quiet = JournalStore(preview: b)
        var b2 = b; b2.timers = [RunningTimer(type: LogType.sleep, start: n - 80 * 60_000)]
        let sleeping = JournalStore(preview: b2)
        let m = model()
        shot("24_ready_nurse", TimerScreen(type: LogType.nurse).environment(m).environment(quiet).tint(Palette.accent).fontDesign(.rounded))
        shot("24_ready_nurse_while_sleep", TimerScreen(type: LogType.nurse).environment(m).environment(sleeping).tint(Palette.accent).fontDesign(.rounded))
        shot("24_ready_sleep", TimerScreen(type: LogType.sleep).environment(m).environment(quiet).tint(Palette.accent).fontDesign(.rounded))
        shot("24_ready_sleep_lamp", lamp: true, TimerScreen(type: LogType.sleep).lamp(true).environment(m).environment(quiet).tint(Palette.accent).fontDesign(.rounded))
        // 2D under the lamp: the fireflies on the timer too, in the upper half where the eye falls
        ArtStyle.current = .flat; defer { ArtStyle.current = .vinyl }
        shot("24_ready_sleep_lamp_2d", lamp: true, TimerScreen(type: LogType.sleep).lamp(true).environment(m).environment(quiet).tint(Palette.accent).fontDesign(.rounded))
    }
    /// 余影, frozen: a second passing (12:04 → 12:05) and a minute turning over (12:59 → 13:00), at four moments of
    /// the afterimage, on the feed's pad colour and on paper.
    func test34Afterimage() {
        func frame(_ old: String, _ new: String, _ t: CGFloat, ink: Color, tint: Color) -> some View {
            let o = Array(old), n = Array(new)
            return HStack(spacing: 0) {
                ForEach(n.indices, id: \.self) { i in
                    let place = n[(i + 1)...].filter(\.isNumber).count
                    let p = CGFloat(min(place, 4))
                    ZStack {
                        if i < o.count, o[i] != n[i] {
                            Text(String(o[i])).modifier(Afterimage(fade: 0.45 + 0.55 * t, rise: (7 + 3 * p) * t, blur: (3.5 + p) * t, scale: 1 + (0.04 + 0.035 * p) * t, tint: tint))
                        }
                        Text(String(n[i])).foregroundStyle(ink)
                    }
                }
            }
            .font(Typeface.numerals(26, weight: .bold)).monospacedDigit()
        }
        let pink = Crayon.pink
        let page = VStack(spacing: 22) {
            ForEach([("12:04", "12:05"), ("12:59", "13:00")], id: \.0) { a, b in
                HStack(spacing: 8) {
                    ForEach([0.0, 0.3, 0.6, 0.9], id: \.self) { t in
                        frame(a, b, t, ink: .white, tint: .white).padding(.vertical, 18).frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Crayon.fill(pink, false)))
                    }
                }
                HStack(spacing: 8) {
                    ForEach([0.0, 0.3, 0.6, 0.9], id: \.self) { t in
                        frame(a, b, t, ink: .primary, tint: Crayon.ink(pink)).padding(.vertical, 18).frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Palette.card))
                    }
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 40).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).background(Palette.background)
        shot("34_afterimage", height: 560, page)
    }
    /// The App Store's 6.9-inch screenshots: 440 × 956 points at 3× = 1320 × 2868 pixels, the size App Store Connect
    /// asks for. The five screens a parent meets first.
    func test35StoreScreens() {
        // the same morning whenever CI runs: the clock read in a time zone where it is 11:00 now (the night sleep from 00:30), so the last
        // hours' records never cross midnight and the home says the same thing every time
        defer { Day.testZone = nil }
        let utc: Int = Int(Date().timeIntervalSince1970) % 86_400
        var offset: Int = (11 * 3600 - utc) % 86_400
        if offset > 14 * 3600 { offset -= 86_400 }
        if offset < -12 * 3600 { offset += 86_400 }
        Day.testZone = TimeZone(secondsFromGMT: offset)
        // a day as it is when the screenshots are taken: today, a baby of six and a half months, records of the last hours
        let m = model(birth: Day.today.plus(days: -200)); m.today = .today; m.journal = true
        let n = ms(Date()), h = 3_600_000.0
        var b = JournalFile.Body()
        b.logs = [LogEntry(type: LogType.sleep, start: n - 10.5 * h, end: n - 4 * h),
                  LogEntry(type: LogType.diaper, start: n - 3.9 * h, detail: "wet"),
                  LogEntry(type: LogType.nurse, start: n - 3.7 * h, end: n - 3.45 * h, side: "l"),
                  LogEntry(type: LogType.nurse, start: n - 3.45 * h, end: n - 3.3 * h, side: "r"),
                  LogEntry(type: LogType.solid, start: n - 2 * h, detail: "米粉"),
                  LogEntry(type: LogType.diaper, start: n - 1.2 * h, detail: "dirty"),
                  LogEntry(type: LogType.bottle, start: n - 0.6 * h, amount: 120, detail: "breastmilk")]
        let quiet = JournalStore(preview: b)
        var b2 = b; b2.timers = [RunningTimer(type: LogType.nurse, start: n - 9 * 60_000, side: "r")]
        let feeding = JournalStore(preview: b2)
        let big: (String, AnyView) -> Void = { name, v in self.shot("store_" + name, height: 874, width: 402, v) }   // 1206×2622: the iPhone App Store Connect asks for (6.3-inch, Dynamic Island)
        let month = m.babyMonth ?? 6
        func on<V: View>(_ j: JournalStore, _ v: V) -> AnyView { AnyView(NavigationStack { v }.environment(m).environment(j).tint(Palette.accent).fontDesign(.rounded)) }
        big("1_home", on(quiet, TodayView(path: .constant(NavigationPath()))))
        big("2_play", on(quiet, PlayView(play: m.content.play("A11")!, month: month)))
        big("3_month", on(quiet, MonthView(month: month)))
        big("4_journal", on(quiet, JournalView(path: .constant(NavigationPath()))))
        big("5_timer", AnyView(TimerScreen(type: LogType.nurse).environment(m).environment(feeding).tint(Palette.accent).fontDesign(.rounded)))
    }
    /// A clock that looks forgotten is asked about; a one-tap record is said back with 撤销.
    func test33ChecksAndToast() {
        var b = JournalFile.Body(); let n = ms(Date())
        b.timers = [RunningTimer(type: LogType.nurse, start: n - 75 * 60_000, side: "l")]
        let long = JournalStore(preview: b), m = model()
        shot("33_check_long_feed", TimerScreen(type: LogType.nurse).environment(m).environment(long).tint(Palette.accent).fontDesign(.rounded))
        let j = JournalStore(preview: JournalFile.Body())
        j.toast = Toast(type: LogType.diaper, text: "已记下 尿布 · 湿 · 14:05", restore: JournalFile.Body())
        m.journal = true
        shot("33_toast", height: 700, tabs(m, JournalView(path: .constant(NavigationPath()))).environment(j).toasts().environment(j))
    }
    func test07Care() { let m = model(); shot("07_care", tabs(m, CareView(month: 6))) }
    func test07Areas() { let m = model(); shot("07_areas", height: 1400, tabs(m, AreasView(month: 6))) }
    func test07Observe() { let m = model(); shot("07_observe", height: 1400, tabs(m, ObserveView(month: 6))) }
    func test06PlayDark() { let m = model(); shot("06_play_dark", dark: true, height: 1400, tabs(m, PlayView(play: m.content.play("A11")!, month: 6))) }
    func test15JournalDark() { let m = model(); m.journal = true; shot("15_journal_dark", dark: true, height: 1500, tabs(m, JournalView(path: .constant(NavigationPath())))) }
    func test20YouDark() { let m = model(); shot("20_you_dark", dark: true, height: 1300, tabs(m, YouView(path: .constant(NavigationPath())))) }
    func test08You() { let m = model(); shot("08_you", height: 1300, tabs(m, YouView(path: .constant(NavigationPath())))) }
    func test08You2D() {
        let m = model(); ArtStyle.current = .flat; defer { ArtStyle.current = .vinyl }
        shot("08_you_2d", height: 1300, tabs(m, YouView(path: .constant(NavigationPath()))))
    }
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
    func test12Characters() { shot("12_characters", height: 1100, settle: 3, characters) }
    func test12CharactersDark() { shot("12_characters_dark", dark: true, height: 1100, settle: 3, characters) }
    func test13Doc() { let m = model(); shot("13_terms", height: 1400, tabs(m, DocView(name: "TERMS"))) }
    /// One kind alone: tap 喂奶 and the day shows only feeds, with how many and the usual gap between them.
    func test15JournalOnlyFeeds() { let m = model(); m.journal = true; shot("15_journal_feeds", height: 1700, tabs(m, JournalView(path: .constant(NavigationPath()), only: "feed"))) }
    func test15Journal() { let m = model(); m.journal = true; shot("15_journal", height: 1700, tabs(m, JournalView(path: .constant(NavigationPath())))) }
    /// 成长册: a page for every month lived — plays as pictures with how many times, the month's measurement, care
    /// averages and notes — newest first; and its door in 我的.
    func test36GrowthBook() {
        let m = model(); m.journal = true
        let day = 86_400_000.0, n = at(10, 0)
        var b = JournalFile.Body()
        b.logs = [LogEntry(type: LogType.play, start: n - 1 * day, detail: "A11 双手物品传递机会"), LogEntry(type: LogType.play, start: n - 3 * day, detail: "A11 双手物品传递机会"),
                  LogEntry(type: LogType.note, start: n - 2 * day, detail: "第一次自己坐稳了一会儿，看着镜子笑。"),
                  LogEntry(type: LogType.sleep, start: n - 1 * day - 8 * 3_600_000, end: n - 1 * day - 2 * 3_600_000),
                  LogEntry(type: LogType.nurse, start: n - 1 * day, end: n - 1 * day + 600_000, side: "l"), LogEntry(type: LogType.nurse, start: n - 1 * day + 660_000, end: n - 1 * day + 1_200_000, side: "r"),
                  LogEntry(type: LogType.bottle, start: n - 1 * day + 4 * 3_600_000, amount: 120), LogEntry(type: LogType.diaper, start: n - 1 * day + 3_600_000, detail: "wet"),
                  LogEntry(type: LogType.play, start: n - 40 * day, detail: "A08 安全触感体验"), LogEntry(type: LogType.play, start: n - 75 * day, detail: "A03 清醒趴玩")]
        b.logs.sort { $0.start > $1.start }
        b.measures = [Measure(at: n - 140 * day, weightG: 5400, lengthMm: 580, headMm: 385), Measure(at: n - 10 * day, weightG: 7400, lengthMm: 655, headMm: 425)]
        let j = JournalStore(preview: b)
        shot("36_growth_book", height: 2600, NavigationStack { GrowthBookView() }.environment(m).environment(j).tint(Palette.accent).fontDesign(.rounded))
        shot("36_growth_book_dark", dark: true, height: 1400, NavigationStack { GrowthBookView() }.environment(m).environment(j).tint(Palette.accent).fontDesign(.rounded))
    }
    func test16Growth() { let m = model(); shot("16_growth", height: 1700, tabs(m, GrowthView())) }
    func test17Stats() { let m = model(); shot("17_stats", height: 1700, tabs(m, StatsView())) }
    func test18Ask() { let m = model(); shot("18_ask_bottle", tabs(m, AskSheet(type: LogType.bottle))) }
    func test19Entry() { let m = model(); shot("19_entry", tabs(m, EntrySheet(entry: LogEntry(type: LogType.nurse, start: at(16, 10), end: at(16, 28), side: "l"), isNew: false))) }
    // the largest everyday text size: nothing may run off the side or need sideways scrolling
    func test25BigTextHome() { let m = model(); shot("25_bigtext_home", height: 1800, settle: 3, tabs(m, TodayView(path: .constant(NavigationPath()))).dynamicTypeSize(.accessibility2)) }
    func test25BigTextJournal() { let m = model(); m.journal = true; shot("25_bigtext_journal", height: 2700, tabs(m, JournalView(path: .constant(NavigationPath()))).dynamicTypeSize(.accessibility2)) }
    func test25BigTextYou() { let m = model(); shot("25_bigtext_you", height: 1300, tabs(m, YouView(path: .constant(NavigationPath()))).dynamicTypeSize(.accessibility2)) }
    func test25BigTextTimer() { let m = model(); shot("25_bigtext_timer", TimerScreen(type: LogType.nurse).environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded).dynamicTypeSize(.accessibility2)) }
    // records on: the Now card (a feed is running in the test journal)
    func test26HomeNow() { let m = model(); m.journal = true; shot("26_home_now", height: 1500, tabs(m, TodayView(path: .constant(NavigationPath())))) }
    // night: Otto's lamp on the records and the timer; the home under the night sky
    func test27LampJournal() { let m = model(); m.journal = true; shot("27_lamp_journal", height: 1500, lamp: true, tabs(m, JournalView(path: .constant(NavigationPath())).lamp(true))) }
    func test27LampTimer() { let m = model(); shot("27_lamp_timer", lamp: true, TimerScreen(type: LogType.nurse).lamp(true).environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded)) }
    func test27LampAsk() { let m = model(); shot("27_lamp_ask", lamp: true, tabs(m, AskSheet(type: LogType.diaper).lamp(true))) }
    func test28TimerPausedAndSleep() {
        // mid-feed on the right after 8 minutes on the left, paused; and a sleep with a 3-minute wake
        var b = JournalFile.Body(); let n = ms(Date())
        b.logs = [LogEntry(type: LogType.nurse, start: n - 14 * 60_000, end: n - 5 * 60_000, side: "l", detail: "paused:60000")]
        b.timers = [RunningTimer(type: LogType.nurse, start: n - 5 * 60_000, side: "r", pausedAt: n - 30_000, carried: 8 * 60_000, carriedPause: 60_000),
                    RunningTimer(type: LogType.sleep, start: n - 52 * 60_000, pausedTotal: 3 * 60_000)]
        let j = JournalStore(preview: b), m = model()
        shot("28_timer_paused", TimerScreen(type: LogType.nurse).environment(m).environment(j).tint(Palette.accent).fontDesign(.rounded))
        shot("28_timer_sleep", TimerScreen(type: LogType.sleep).environment(m).environment(j).tint(Palette.accent).fontDesign(.rounded))
        shot("28_timer_sleep_lamp", lamp: true, TimerScreen(type: LogType.sleep).lamp(true).environment(m).environment(j).tint(Palette.accent).fontDesign(.rounded))
    }
    func test29Girl() {
        let m = model()
        shot("29_play_girl", height: 1800, tabs(m, PlayView(play: m.content.play("A35")!, month: 9)).environment(\.girlArt, true))
        m.look = "girl"
        shot("29_profile_girl", height: 1300, tabs(m, ProfileSheet()).environment(\.girlArt, true))
        shot("29_you_girl", height: 900, tabs(m, YouView(path: .constant(NavigationPath()))).environment(\.girlArt, true))
        shot("29_home_girl", height: 1500, tabs(m, TodayView(path: .constant(NavigationPath()))).environment(\.girlArt, true))
    }
    /// The night as it really happens: the phone in light mode, the lamp on, and a record page *presented* as a
    /// sheet from the records (build 156 showed black text and black date pickers there on a phone).
    func test30LampSheetsPresented() {
        let m = model(); m.journal = true
        for (name, type) in [("30_lamp_present_diaper", LogType.diaper), ("30_lamp_present_bottle", LogType.bottle)] {
            let host = Color.clear.sheet(isPresented: .constant(true)) { AskSheet(type: type).lampPresented() }.lamp(true)
            shot(name, window: true, lamp: true, tabs(m, host))
        }
    }
    /// One dark appearance: the lamp everywhere (build 160).
    func test31LampEverywhere() {
        let m = model()
        shot("31_lamp_home", height: 1600, lamp: true, tabs(m, TodayView(path: .constant(NavigationPath())).lamp(true).environment(\.night, true)))
        shot("31_lamp_you", height: 1500, lamp: true, tabs(m, YouView(path: .constant(NavigationPath())).lamp(true)))
        shot("31_lamp_play", height: 1400, lamp: true, tabs(m, PlayView(play: m.content.play("A11")!, month: 6).lamp(true)))
        shot("31_lamp_month", height: 1400, lamp: true, tabs(m, MonthView(month: 6).lamp(true)))
    }
    func test27NightHome() { let m = model(); shot("27_night_home", height: 1200, tabs(m, TodayView(path: .constant(NavigationPath())).environment(\.night, true))) }
    /// Night with the records on and nothing running: the last feed, waking and nappy lead the page.
    func test27NightFacts() {
        let m = model(); m.journal = true
        shot("27_night_facts", height: 1100, lamp: true, tabs(m, TodayView(path: .constant(NavigationPath())).lamp(true).environment(\.night, true)))
    }
    func test14Month36() { let m = model(); shot("14_month36", height: 2600, tabs(m, MonthView(month: 36))) }

    /// The widget and the Live Activity faces (ios/Shared/WidgetFaces.swift) at their Home Screen and Lock Screen
    /// sizes: idle and with a feed running, by day and under the lamp.
    func test32Widgets() {
        let day = Day(y: 2026, m: 10, d: 19)
        let now = day.date.addingTimeInterval(20 * 3600)
        let snap = Snapshot(birthEpochDay: Day(y: 2026, m: 4, d: 2).epochDay, nickname: "小满", companion: "Moss", journal: true, playCode: "A11", playName: "双手物品传递机会")
        var idle = JournalFile.Body()
        idle.logs = [LogEntry(type: LogType.nurse, start: ms(now) - 140 * 60_000, end: ms(now) - 120 * 60_000, side: "l"),
                     LogEntry(type: LogType.sleep, start: ms(now) - 300 * 60_000, end: ms(now) - 200 * 60_000),
                     LogEntry(type: LogType.diaper, start: ms(now) - 45 * 60_000, detail: "wet")]
        var feeding = idle
        feeding.timers = [RunningTimer(type: LogType.nurse, start: ms(now) - 9 * 60_000, side: "r", pausedAt: ms(now) - 60_000)]
        func tile(_ w: CGFloat, _ h: CGFloat, _ v: some View) -> some View {
            v.padding(16).frame(width: w, height: h).background(WidgetInk.paper).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        }
        let state = TimerAttributes.ContentState(start: now.addingTimeInterval(-9 * 60), pausedAt: now.addingTimeInterval(-60), side: "r", note: "距上一顿 2 小时 20 分")
        for dark in [false, true] {
            let page = VStack(spacing: 18) {
                HStack(spacing: 18) {
                    tile(170, 170, TodayFace(date: now, snap: snap, body: idle, size: .small))
                    tile(170, 170, TodayFace(date: now, snap: snap, body: feeding, size: .small))
                }
                tile(360, 170, TodayFace(date: now, snap: snap, body: idle, size: .medium))
                tile(360, 170, TodayFace(date: now, snap: snap, body: feeding, size: .medium))
                // the Lock Screen face is always under the lamp
                let lamp = Color(red: 0x0E / 255, green: 0x14 / 255, blue: 0x30 / 255)
                TimerFace(type: LogType.nurse, s: state).environment(\.colorScheme, .dark).frame(width: 360).background(lamp).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                TimerFace(type: LogType.sleep, s: TimerAttributes.ContentState(start: now.addingTimeInterval(-50 * 60), pausedAt: now, side: nil, note: "醒了 1 小时 35 分后入睡"))
                    .environment(\.colorScheme, .dark).frame(width: 360).background(lamp).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .padding(.vertical, 24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(dark ? Color(white: 0.08) : Color(red: 0.80, green: 0.86, blue: 0.92))
            .fontDesign(.rounded)
            shot(dark ? "32_widgets_dark" : "32_widgets", dark: dark, height: 1060, page)
        }
    }
}
