import XCTest
import SwiftUI
import QuartzCore
@testable import Mossling

/// Renders each screen in the simulator and writes a PNG to $SNAPSHOT_DIR (set by CI) for review.
@MainActor
final class ScreenshotTests: XCTestCase {
    /// Chinese is the reference language of these tests; a test that wants English says so (the CI simulator is English).
    override func tearDown() {
        Self.sharedWindow?.rootViewController = nil
        Self.sharedWindow?.isHidden = true
        super.tearDown()
    }
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

    private static var sharedWindow: UIWindow?

    private func shot<V: View>(_ name: String, dark: Bool = false, height: CGFloat = 852, width: CGFloat = 393, window whole: Bool = false, lamp: Bool = false, settle: Double = 1.2, _ view: V) {
        let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] ?? NSTemporaryDirectory()
        // lamp: the phone in light mode with the lamp on — the app darkens its window then (RootView), so do the same
        let host = UIHostingController(rootView: view.environment(\.colorScheme, dark || lamp ? .dark : .light).preferredColorScheme(lamp ? .dark : nil))
        let size = CGSize(width: width, height: height)
        let window: UIWindow
        if let existing = Self.sharedWindow {
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
            Self.sharedWindow = created
            window = created
        }
        window.overrideUserInterfaceStyle = dark || lamp ? .dark : .light   // the app darkens its window under the lamp
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        // let images decode and tasks settle
        RunLoop.main.run(until: Date().addingTimeInterval(settle))
        CATransaction.flush()
        var drew = false
        autoreleasepool {
            let img = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 3; return f }()).image { _ in
                // the whole window includes a presented sheet, as on the phone
                if whole, let sheet = host.presentedViewController?.view {
                    // the presented page, where it sits on the screen, over the page under it
                    host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
                    sheet.drawHierarchy(in: sheet.convert(sheet.bounds, to: nil), afterScreenUpdates: true)
                } else { host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true) }
            }
            drew = Self.drewSomething(img)
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try? img.pngData()?.write(to: URL(fileURLWithPath: dir).appendingPathComponent("ios_\(name).png"))
        }
        // an empty picture is a failed shot, not a pass (a page taller than the renderer's 8192-pixel limit draws nothing)
        XCTAssertTrue(drew, "ios_\(name) came out empty")
        host.dismiss(animated: false)
        window.rootViewController = UIViewController()
        window.layoutIfNeeded()
        CATransaction.flush()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        window.rootViewController = nil
        window.isHidden = true
        CATransaction.flush()
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
    func test37Story() { let m = model(); shot("37_story", height: 920, settle: 3, tabs(m, StoryView())) }
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
    /// asks for. Ten bilingual (CN + EN) hero screens showcasing the complete v2.0 quiet Montessori studio.
    func test35StoreScreens() {
        defer { Day.testZone = nil }
        let utc: Int = Int(Date().timeIntervalSince1970) % 86_400
        var offset: Int = (11 * 3600 - utc) % 86_400
        if offset > 14 * 3600 { offset -= 86_400 }
        if offset < -12 * 3600 { offset += 86_400 }
        Day.testZone = TimeZone(secondsFromGMT: offset)

        let today = Day.today
        let birth = today.plus(days: -200)
        let n = ms(Date()), h = 3_600_000.0

        func buildJournal(english: Bool) -> (JournalStore, JournalStore, UUID) {
            var b = JournalFile.Body()
            for back in 0..<7 {
                let d = today.plus(days: -back)
                let dayStart = d.date
                func ts(_ hr: Double) -> Double { ms(dayStart.addingTimeInterval(hr * 3600)) }
                let jitter = Double(back % 3) * 0.25
                if back == 0 {
                    b.logs.append(LogEntry(type: LogType.sleep, start: n - 10.5 * h, end: n - 4.0 * h))
                    b.logs.append(LogEntry(type: LogType.diaper, start: n - 3.9 * h, detail: "wet"))
                    b.logs.append(LogEntry(type: LogType.nurse, start: n - 3.7 * h, end: n - 3.45 * h, side: "l"))
                    b.logs.append(LogEntry(type: LogType.nurse, start: n - 3.45 * h, end: n - 3.3 * h, side: "r"))
                    b.logs.append(LogEntry(type: LogType.solid, start: n - 2.0 * h, detail: english ? "Avocado mash" : "牛油果泥"))
                    b.logs.append(LogEntry(type: LogType.diaper, start: n - 1.2 * h, detail: "dirty"))
                    b.logs.append(LogEntry(type: LogType.bottle, start: n - 0.6 * h, amount: 130, detail: "breastmilk"))
                } else {
                    b.logs.append(LogEntry(type: LogType.sleep, start: ts(0.0), end: ts(6.2 + jitter)))
                    b.logs.append(LogEntry(type: LogType.sleep, start: ts(9.4 + jitter), end: ts(10.8 + jitter)))
                    b.logs.append(LogEntry(type: LogType.sleep, start: ts(13.2 + jitter), end: ts(14.9 + jitter)))
                    b.logs.append(LogEntry(type: LogType.sleep, start: ts(20.4 + jitter), end: ts(24.0)))
                    b.logs.append(LogEntry(type: LogType.nurse, start: ts(6.5 + jitter), end: ts(6.8 + jitter), side: "l"))
                    b.logs.append(LogEntry(type: LogType.nurse, start: ts(11.1 + jitter), end: ts(11.4 + jitter), side: "r"))
                    b.logs.append(LogEntry(type: LogType.bottle, start: ts(15.2 + jitter), amount: 130, detail: "breastmilk"))
                    b.logs.append(LogEntry(type: LogType.nurse, start: ts(19.6 + jitter), end: ts(19.9 + jitter), side: "l"))
                    if back % 2 == 0 {
                        b.logs.append(LogEntry(type: LogType.play, start: ts(16.2), detail: english ? "A11 Passing toys hand to hand" : "A11 双手物品传递机会"))
                    }
                }
            }
            b.measures = [Measure(at: ms(today.plus(days: -5).date), weightG: 7450, lengthMm: 660, headMm: 428)]
            let firstPhoto = First(
                at: ms(today.plus(days: -6).date),
                key: "sit",
                title: english ? "First Sit" : "坐",
                note: english ? "Sat steady by the warm cushion for ten bright seconds" : "靠着软垫自己坐稳了十几秒，举着木摇铃笑出声"
            )
            b.firsts = [
                First(at: ms(today.plus(days: -55).date), key: "roll", title: english ? "First Roll" : "翻身"),
                firstPhoto
            ]
            let quiet = JournalStore(preview: b)
            var sleepBody = b
            sleepBody.timers = [RunningTimer(type: LogType.sleep, start: n - 42 * 60_000)]
            let sleeping = JournalStore(preview: sleepBody)
            return (quiet, sleeping, firstPhoto.id)
        }

        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2
        let samplePhoto = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 240), format: fmt).image { ctx in
            let cg = ctx.cgContext
            UIColor(red: 0.96, green: 0.87, blue: 0.72, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: 240, height: 240))
            UIColor(red: 0.34, green: 0.65, blue: 0.56, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: 56, y: 74, width: 128, height: 128))
            UIColor(red: 0.95, green: 0.72, blue: 0.25, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: 150, y: 34, width: 46, height: 46))
        }

        let sampleFoods = FoodAtlasStore(preview: [
            FoodRecord(foodId: "pumpkin",     firstTastedEpochDay: today.plus(days: -18).epochDay, reaction: .loved),
            FoodRecord(foodId: "sweetpotato", firstTastedEpochDay: today.plus(days: -16).epochDay, reaction: .loved),
            FoodRecord(foodId: "carrot",      firstTastedEpochDay: today.plus(days: -14).epochDay, reaction: .tasted),
            FoodRecord(foodId: "avocado",     firstTastedEpochDay: today.plus(days: -11).epochDay, reaction: .loved),
            FoodRecord(foodId: "broccoli",    firstTastedEpochDay: today.plus(days: -9).epochDay,  reaction: .tryAgain, times: 3),
            FoodRecord(foodId: "banana",      firstTastedEpochDay: today.plus(days: -12).epochDay, reaction: .loved),
            FoodRecord(foodId: "apple",       firstTastedEpochDay: today.plus(days: -10).epochDay, reaction: .loved),
            FoodRecord(foodId: "blueberry",   firstTastedEpochDay: today.plus(days: -4).epochDay,  reaction: .tasted),
            FoodRecord(foodId: "ricecereal",  firstTastedEpochDay: today.plus(days: -20).epochDay, reaction: .loved),
            FoodRecord(foodId: "oatmeal",     firstTastedEpochDay: today.plus(days: -7).epochDay,  reaction: .tasted),
            FoodRecord(foodId: "eggyolk",     firstTastedEpochDay: today.plus(days: -6).epochDay,  reaction: .tasted, watchSkin: true),
            FoodRecord(foodId: "salmon",      firstTastedEpochDay: today.plus(days: -3).epochDay,  reaction: .loved),
            FoodRecord(foodId: "yogurt",      firstTastedEpochDay: today.plus(days: -2).epochDay,  reaction: .loved),
            FoodRecord(foodId: "oliveoil",    firstTastedEpochDay: today.plus(days: -1).epochDay,  reaction: .tasted),
        ])

        func renderGallery(prefix: String, english: Bool) {
            L10n.overrideEnglish = english
            let m = model(birth: birth)
            m.today = today
            m.journal = true
            m.nickname = english ? "Leo" : "小满"

            let (quiet, sleeping, photoId) = buildJournal(english: english)
            FirstPhotoStore.save(samplePhoto, for: photoId)
            defer { FirstPhotoStore.delete(for: photoId) }

            let caps = CapsuleStore(preview: [
                TimeCapsule(
                    title: english ? "Six Months Under Otto's Lamp" : "满半岁那天的灯下小记",
                    body: english ? "Tonight you sat steady by the soft cushion and giggled at your wooden rattle." : "小满，今天你靠着软垫自己坐稳了十几秒，举着木摇铃笑出声来。",
                    writtenAt: ms(today.plus(days: -17).date),
                    writtenAgeLabel: english ? "6 months" : "6 个月",
                    unlockEpochDay: today.epochDay,
                    openedAt: nil,
                    seal: .gold
                ),
                TimeCapsule(
                    title: english ? "To Leo on Your 1st Birthday" : "写给一岁生日的小满",
                    body: english ? "When you unseal this wax stamp, we will have walked through four seasons together." : "等你拆开这封信的时候，你已经走过一整年的四季啦。",
                    writtenAt: ms(today.plus(days: -2).date),
                    writtenAgeLabel: english ? "6 mo 15 d" : "6 个月 15 天",
                    unlockEpochDay: TimeCapsule.birthdayEpochDay(from: birth, years: 1),
                    openedAt: nil,
                    seal: .teal
                ),
                TimeCapsule(
                    title: english ? "Your 100th Bright Day" : "你出生的第一百天",
                    body: english ? "You smiled wide for the camera while we snapped twenty blurry photos we could never delete." : "今天你对着镜头咧嘴笑出了梨涡，爸爸妈妈拍了二十张糊照片却一张也舍不得删。",
                    writtenAt: ms(birth.plus(days: 100).date),
                    writtenAgeLabel: english ? "3 mo 9 d" : "3 个月 9 天",
                    unlockEpochDay: nil,
                    openedAt: ms(today.plus(days: -10).date),
                    seal: .pink
                )
            ])

            func nav<V: View>(_ j: JournalStore, _ v: V) -> AnyView {
                AnyView(NavigationStack { v }.environment(m).environment(j).tint(Palette.accent).fontDesign(.rounded))
            }

            // 1. Home + 2x3 Quiet Instruments Dock
            shot("store_\(prefix)1_home", height: 956, width: 440, nav(quiet, TodayView(path: .constant(NavigationPath()))))

            // 2. Bedside Lamp (4-6 Breathing Halo + Dual-Layer Soundscape Mix)
            SoundscapeEngine.shared.start(.rain)
            SoundscapeEngine.shared.toggleLayer(.lullaby)
            let nightClock = Day.cal.date(from: DateComponents(year: today.y, month: today.m, day: today.d, hour: 22, minute: 15)) ?? today.date.addingTimeInterval(22 * 3600 + 15 * 60)
            shot("store_\(prefix)2_lamp", dark: true, height: 956, width: 440,
                 BedsideLampView(initialBrightness: 0.80, initialBreathingGuide: true, previewClock: nightClock).environment(m).environment(sleeping).fontDesign(.rounded))
            SoundscapeEngine.shared.stop()

            // 3. Sensory Toybox (8-bar Wooden Xylophone with 4-studio picker)
            shot("store_\(prefix)3_toybox", height: 956, width: 440, nav(quiet, ToyboxView(initialMode: .xylophone)))

            // 4. First Foods Tasting Box (6-color botanical wreath + 14 stamped whole foods)
            shot("store_\(prefix)4_foods", height: 956, width: 440, nav(quiet, FoodAtlasView(store: sampleFoods)))

            // 5. 24h Polar Circadian Rhythm Dial
            shot("store_\(prefix)5_rhythm", height: 956, width: 440, nav(quiet, StatsView()))

            // 6. Keepsake Growth Storybook Spread with Polaroid Photo
            shot("store_\(prefix)6_storybook", height: 956, width: 440,
                 StorybookView(initialPage: 7, foodStore: sampleFoods).environment(m).environment(quiet).tint(Palette.accent).fontDesign(.rounded))

            // 7. Wax-Sealed Time Capsule Letters
            shot("store_\(prefix)7_capsules", height: 956, width: 440, nav(quiet, TimeCapsuleListView(store: caps)))

            // 8. Dot-Grid Care Journal with Stickers, Bead Ribbon & Handover Button
            shot("store_\(prefix)8_journal", height: 956, width: 440, nav(quiet, JournalView(path: .constant(NavigationPath()))))

            // 9. Kid's Book Kinetic Step Diagram Stage (4:3 Die-Cut Art & Page Folio)
            if let playA11 = m.content.play("A11") {
                shot("store_\(prefix)9_play", height: 956, width: 440, nav(quiet, PlayView(play: playA11, month: 6)))
            }

            // 10. Paper-Cut 3-Land Vertical Bead Journey & Keepsake Shelf
            shot("store_\(prefix)10_journey", height: 956, width: 440, nav(quiet, JourneyHubView()))
        }

        defer {
            L10n.overrideEnglish = false
            SoundscapeEngine.shared.stop()
        }
        renderGallery(prefix: "", english: false)
        renderGallery(prefix: "en_", english: true)
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

    func test33NewWidgets() {
        L10n.overrideEnglish = false; defer { L10n.overrideEnglish = nil }
        let day = Day(y: 2026, m: 10, d: 19)
        let now = day.date.addingTimeInterval(16 * 3600 + 20 * 60)
        let plays = [PlayRef(code: "A11", name: "双手物品传递机会"), PlayRef(code: "A12", name: "听声音找方向")]
        let snap = Snapshot(birthEpochDay: Day(y: 2026, m: 4, d: 2).epochDay, nickname: "小满", companion: "Moss", journal: true, playCode: "A11", playName: "双手物品传递机会", consented: true, weekPlays: plays)
        var idle = JournalFile.Body()
        idle.logs = [
            LogEntry(type: LogType.sleep, start: ms(day.date) + 1 * 3600_000, end: ms(day.date) + 6 * 3600_000),
            LogEntry(type: LogType.nurse, start: ms(day.date) + 7 * 3600_000, end: ms(day.date) + 7 * 3600_000 + 20 * 60_000, side: "l"),
            LogEntry(type: LogType.sleep, start: ms(day.date) + 10 * 3600_000, end: ms(day.date) + 11 * 3600_000 + 40 * 60_000),
            LogEntry(type: LogType.nurse, start: ms(now) - 140 * 60_000, end: ms(now) - 120 * 60_000, side: "r"),
            LogEntry(type: LogType.diaper, start: ms(now) - 90 * 60_000, detail: "wet"),
            // Just logged 3 seconds ago -> triggers live ✓ confirmation + Undo pill
            LogEntry(type: LogType.diaper, start: ms(now) - 3_000, detail: "wet"),
        ]
        var feeding = idle
        feeding.timers = [RunningTimer(type: LogType.nurse, start: ms(now) - 9 * 60_000, side: "r", pausedAt: ms(now) - 60_000)]
        func tile<BG: View>(_ w: CGFloat, _ h: CGFloat, bg: BG, _ v: some View) -> some View {
            v.padding(16).frame(width: w, height: h).background(bg).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        }
        for dark in [false, true] {
            let page = VStack(spacing: 18) {
                tile(360, 360, bg: WidgetInk.paper, TodayFace(date: now, snap: snap, body: idle, size: .large))
                HStack(spacing: 18) {
                    tile(170, 170, bg: WidgetInk.paper, QuickCareFace(date: now, snap: snap, body_: idle, isMedium: false))
                    tile(170, 170, bg: BedsideLampFace.backdrop, BedsideLampFace(date: now, snap: snap, body_: feeding, isMedium: false))
                }
                tile(360, 170, bg: WidgetInk.paper, QuickCareFace(date: now, snap: snap, body_: feeding, isMedium: true))
                tile(360, 170, bg: BedsideLampFace.backdrop, BedsideLampFace(date: now, snap: snap, body_: idle, isMedium: true))
            }
            .padding(.vertical, 24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(dark ? Color(white: 0.08) : Color(red: 0.80, green: 0.86, blue: 0.92))
            .fontDesign(.rounded)
            shot(dark ? "33_widgets_v12_dark" : "33_widgets_v12", dark: dark, height: 1020, page)
        }
    }

    func test34WidgetsEnglish() {
        L10n.overrideEnglish = true; defer { L10n.overrideEnglish = nil }
        let day = Day(y: 2026, m: 10, d: 19)
        let now = day.date.addingTimeInterval(16 * 3600 + 20 * 60)
        let plays = [PlayRef(code: "A11", name: "Hand-to-Hand Object Transfer"), PlayRef(code: "A12", name: "Follow the Gentle Sound")]
        let snap = Snapshot(birthEpochDay: Day(y: 2026, m: 4, d: 2).epochDay, nickname: "Leo", companion: "Moss", journal: true, playCode: "A11", playName: "Hand-to-Hand Object Transfer", consented: true, weekPlays: plays)
        var idle = JournalFile.Body()
        idle.logs = [
            LogEntry(type: LogType.sleep, start: ms(day.date) + 1 * 3600_000, end: ms(day.date) + 6 * 3600_000),
            LogEntry(type: LogType.nurse, start: ms(now) - 140 * 60_000, end: ms(now) - 120 * 60_000, side: "l"),
            LogEntry(type: LogType.diaper, start: ms(now) - 3_000, detail: "wet"),
        ]
        var feeding = idle
        feeding.timers = [RunningTimer(type: LogType.nurse, start: ms(now) - 9 * 60_000, side: "r", pausedAt: ms(now) - 60_000)]
        func tile<BG: View>(_ w: CGFloat, _ h: CGFloat, bg: BG, _ v: some View) -> some View {
            v.padding(16).frame(width: w, height: h).background(bg).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        }
        let page = VStack(spacing: 18) {
            tile(360, 360, bg: WidgetInk.paper, TodayFace(date: now, snap: snap, body: idle, size: .large))
            tile(360, 170, bg: WidgetInk.paper, StoryWindowFace(date: now, snap: snap, body_: idle, isMedium: true))
            tile(360, 170, bg: WidgetInk.paper, QuickCareFace(date: now, snap: snap, body_: feeding, isMedium: true))
            tile(360, 170, bg: BedsideLampFace.backdrop, BedsideLampFace(date: now, snap: snap, body_: idle, isMedium: true))
        }
        .padding(.vertical, 24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0.80, green: 0.86, blue: 0.92))
        .fontDesign(.rounded)
        shot("34_widgets_en", dark: false, height: 1010, page)
    }

    func test35StoryWindowAndEnglishApp() {
        let day = Day(y: 2026, m: 10, d: 19)
        let now = day.date.addingTimeInterval(16 * 3600 + 20 * 60)
        var idle = JournalFile.Body()
        idle.logs = [LogEntry(type: LogType.sleep, start: ms(now) - 105 * 60_000, end: ms(now) - 45 * 60_000)]
        func tile<BG: View>(_ w: CGFloat, _ h: CGFloat, bg: BG, _ v: some View) -> some View {
            v.padding(16).frame(width: w, height: h).background(bg).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        }
        L10n.overrideEnglish = false
        let snapZh = Snapshot(birthEpochDay: Day(y: 2026, m: 4, d: 2).epochDay, nickname: "小满", companion: "Moss", journal: true, playCode: "A11", playName: "双手物品传递机会", consented: true)
        let storyPage = VStack(spacing: 18) {
            HStack(spacing: 18) {
                tile(170, 170, bg: WidgetInk.paper, StoryWindowFace(date: now, snap: snapZh, body_: idle, isMedium: false))
                tile(170, 170, bg: WidgetInk.paper, StoryWindowFace(date: now, snap: snapZh, body_: idle, isMedium: false)).environment(\.colorScheme, .dark)
            }
            tile(360, 170, bg: WidgetInk.paper, StoryWindowFace(date: now, snap: snapZh, body_: idle, isMedium: true))
            tile(360, 170, bg: WidgetInk.paper, StoryWindowFace(date: now, snap: snapZh, body_: idle, isMedium: true)).environment(\.colorScheme, .dark)
        }
        .padding(.vertical, 24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(red: 0.80, green: 0.86, blue: 0.92))
        .fontDesign(.rounded)
        shot("35_story_window", dark: false, height: 640, storyPage)

        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let m = model(); m.nickname = "Leo"; m.journal = true
        shot("35_you_en", height: 960, tabs(m, YouView(path: .constant(NavigationPath()))))
        shot("36_today_en", height: 1100, tabs(m, TodayView(path: .constant(NavigationPath()))))
        if let p = m.content.play("A11") {
            shot("36_play_en", height: 1200, tabs(m, PlayView(play: p, month: 6)))
        }
        var jb = JournalFile.Body()
        let base = m.today.date
        jb.logs = [
            LogEntry(type: LogType.sleep, start: ms(base.addingTimeInterval(-3 * 3600)), end: ms(base.addingTimeInterval(11 * 3600 + 42 * 60))),
            LogEntry(type: LogType.sleep, start: ms(base.addingTimeInterval(13 * 3600)), end: ms(base.addingTimeInterval(16 * 3600))),
            LogEntry(type: LogType.nurse, start: ms(base.addingTimeInterval(12 * 3600)), end: ms(base.addingTimeInterval(12 * 3600 + 14 * 60)), side: "l"),
            LogEntry(type: LogType.diaper, start: ms(base.addingTimeInterval(12 * 3600 + 20 * 60)), detail: "wet"),
            LogEntry(type: LogType.bottle, start: ms(base.addingTimeInterval(15 * 3600)), amount: 120, detail: "breastmilk"),
            LogEntry(type: LogType.play, start: ms(base.addingTimeInterval(16 * 3600 + 10 * 60)), detail: "A11 Two-Handed Transfer"),
        ]
        jb.firsts = [First(at: ms(base.addingTimeInterval(-20 * 86_400)), key: "roll", title: "翻身")]
        let jEn = JournalStore(preview: jb)
        shot("37_journal_en", height: 1050, tabs(m, JournalView(path: .constant(NavigationPath())).environment(jEn)))
        shot("38_timer_en", height: 860, TimerScreen(type: LogType.nurse).environment(m).environment(jEn).fontDesign(.rounded))
        shot("39_growthbook_en", height: 1000, tabs(m, GrowthBookView().environment(jEn)))
        shot("40_story_en", height: 960, tabs(m, StoryView()))
        shot("41_sources_en", height: 960, tabs(m, SourcesView()))
    }

    /// Award-craft instruments: 24h Circadian Rhythm Dial, Otto's Bedside Lamp + Soundscapes, and Keepsake Growth Storybook.
    func test42AwardInstruments() {
        let m = model(); m.journal = true
        let today = m.today
        var b = JournalFile.Body()
        // Populate 7 realistic circadian days (night stretches, daytime naps, feeds, plays)
        for back in 0..<7 {
            let d = today.plus(days: -back)
            let dayStart = d.date
            func ts(_ h: Double) -> Double { ms(dayStart.addingTimeInterval(h * 3600)) }
            let jitter = Double(back % 3) * 0.25
            b.logs.append(LogEntry(type: LogType.sleep, start: ts(0.0), end: ts(6.2 + jitter)))
            b.logs.append(LogEntry(type: LogType.sleep, start: ts(9.5 + jitter), end: ts(10.8 + jitter)))
            b.logs.append(LogEntry(type: LogType.sleep, start: ts(13.2 + jitter), end: ts(14.9 + jitter)))
            b.logs.append(LogEntry(type: LogType.sleep, start: ts(20.5 + jitter), end: ts(24.0)))
            b.logs.append(LogEntry(type: LogType.nurse, start: ts(6.5 + jitter), end: ts(6.8 + jitter), side: "l"))
            b.logs.append(LogEntry(type: LogType.nurse, start: ts(11.1 + jitter), end: ts(11.4 + jitter), side: "r"))
            b.logs.append(LogEntry(type: LogType.bottle, start: ts(15.2 + jitter), amount: 130, detail: "breastmilk"))
            b.logs.append(LogEntry(type: LogType.nurse, start: ts(19.6 + jitter), end: ts(19.9 + jitter), side: "l"))
            if back % 2 == 0 {
                b.logs.append(LogEntry(type: LogType.play, start: ts(16.3), detail: "A11 双手物品传递机会"))
            }
        }
        b.logs.append(LogEntry(type: LogType.note, start: ms(today.date.addingTimeInterval(17 * 3600)), detail: "今天自己抓着木摇铃左右倒手玩了好久，一直咯咯笑。"))
        b.measures = [Measure(at: ms(today.plus(days: -5).date), weightG: 7450, lengthMm: 660, headMm: 428)]
        let firstWithPhoto = First(at: ms(today.plus(days: -6).date), key: "sit", title: "坐", note: "靠着软垫自己坐稳了十几秒")
        b.firsts = [
            First(at: ms(today.plus(days: -55).date), key: "roll", title: "翻身"),
            firstWithPhoto
        ]

        // Create a warm synthetic Polaroid photo keepsake for the Storybook & Firsts spread, cleaned up in defer
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2
        let samplePhoto = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 240), format: fmt).image { ctx in
            let cg = ctx.cgContext
            UIColor(red: 0.96, green: 0.87, blue: 0.72, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: 240, height: 240))
            UIColor(red: 0.34, green: 0.65, blue: 0.56, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: 56, y: 74, width: 128, height: 128))
            UIColor(red: 0.95, green: 0.72, blue: 0.25, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: 150, y: 34, width: 46, height: 46))
        }
        FirstPhotoStore.save(samplePhoto, for: firstWithPhoto.id)
        defer { FirstPhotoStore.delete(for: firstWithPhoto.id) }

        let richJournal = JournalStore(preview: b)
        let bookFoods = FoodAtlasStore(preview: [
            FoodRecord(foodId: "pumpkin",   firstTastedEpochDay: today.plus(days: -14).epochDay, reaction: .loved),
            FoodRecord(foodId: "avocado",   firstTastedEpochDay: today.plus(days: -10).epochDay, reaction: .loved),
            FoodRecord(foodId: "ricecereal",firstTastedEpochDay: today.plus(days: -16).epochDay, reaction: .tasted),
            FoodRecord(foodId: "eggyolk",   firstTastedEpochDay: today.plus(days: -6).epochDay,  reaction: .tasted, watchSkin: true),
            FoodRecord(foodId: "blueberry", firstTastedEpochDay: today.plus(days: -2).epochDay,  reaction: .loved),
        ])

        // 1. 24-Hour Circadian Rhythm Dial (CN Day, Scrubbed Spotlight 21:00, Night Lamp, EN Day)
        shot("42_rhythm_dial_zh", height: 1180, NavigationStack { StatsView() }.environment(m).environment(richJournal).tint(Palette.accent).fontDesign(.rounded))
        shot("42_rhythm_dial_scrub", height: 520,
             ScrollView { RhythmDialCard(nowHour: 15.5, initialInspectedHour: 21).padding(16) }
                .pageBackground().environment(m).environment(richJournal).tint(Palette.accent).fontDesign(.rounded))
        shot("42_rhythm_dial_lamp", height: 520, lamp: true,
             ScrollView { RhythmDialCard(nowHour: 22.4, initialInspectedHour: 21).padding(16) }
                .pageBackground().lamp(true).environment(m).environment(richJournal).tint(Palette.accent).fontDesign(.rounded))

        // 2. Otto's Living Bedside Lamp (CN with active sleep timer + Paper Rain soundscape)
        var sleepBody = b
        sleepBody.timers = [RunningTimer(type: LogType.sleep, start: ms(Date()) - 42 * 60_000)]
        let sleepJournal = JournalStore(preview: sleepBody)
        let nightClock = Day.cal.date(from: DateComponents(year: today.y, month: today.m, day: today.d, hour: 22, minute: 15)) ?? today.date.addingTimeInterval(22 * 3600 + 15 * 60)
        SoundscapeEngine.shared.start(.rain)
        defer { SoundscapeEngine.shared.stop() }
        shot("43_bedside_lamp_zh", dark: true, height: 852, BedsideLampView(initialBrightness: 0.78, previewClock: nightClock).environment(m).environment(sleepJournal).fontDesign(.rounded))

        // 3. Keepsake Growth Storybook (CN Cover + CN Month 6 Editorial Spread with Polaroid First Photo)
        shot("44_storybook_cover_zh", height: 852, StorybookView(initialPage: 0, foodStore: bookFoods).environment(m).environment(richJournal).tint(Palette.accent).fontDesign(.rounded))
        shot("44_storybook_spread_zh", height: 852, StorybookView(initialPage: 7, foodStore: bookFoods).environment(m).environment(richJournal).tint(Palette.accent).fontDesign(.rounded))

        // 4. English variants of all three new hero instruments
        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = true
        shot("42_rhythm_dial_en", height: 520,
             ScrollView { RhythmDialCard(nowHour: 15.5, initialInspectedHour: 21).padding(16) }
                .pageBackground().environment(mEn).environment(richJournal).tint(Palette.accent).fontDesign(.rounded))
        SoundscapeEngine.shared.start(.lullaby)
        shot("43_bedside_lamp_en", dark: true, height: 852, BedsideLampView(initialBrightness: 0.82, previewClock: nightClock).environment(mEn).environment(richJournal).fontDesign(.rounded))
        shot("44_storybook_spread_en", height: 852, StorybookView(initialPage: 7, foodStore: bookFoods).environment(mEn).environment(richJournal).tint(Palette.accent).fontDesign(.rounded))
    }

    /// Screen-1 Quiet Instruments dock, Sensory Toybox (3 studios), and Time Capsule Letters (CN + EN + Lamp).
    func test45QuietInstrumentsToyboxAndCapsules() {
        let m = model(); m.journal = true
        let today = m.today

        // 1. Home Screen with Quiet Instruments dock (Day + Night Lamp)
        shot("45_today_instruments_zh", height: 1260, tabs(m, TodayView(path: .constant(NavigationPath()))))
        shot("45_today_instruments_lamp", height: 1260, lamp: true, tabs(m, TodayView(path: .constant(NavigationPath())).lamp(true).environment(\.night, true)))

        // 2. Sensory Toybox studios (Chinese)
        shot("46_toybox_xylophone_zh", height: 852, tabs(m, ToyboxView(initialMode: .xylophone)))
        shot("46_toybox_playalong_zh", height: 852, tabs(m, ToyboxView(initialMode: .xylophone, previewPlayAlong: true)))
        shot("46_toybox_rainstick_zh", height: 852, tabs(m, ToyboxView(initialMode: .rainstick, initialRainstickLayout: .hourglass)))
        shot("46_toybox_contrast_zh", height: 852, tabs(m, ToyboxView(initialMode: .contrast, initialContrastIndex: 8)))

        // 3. Time Capsule Letters (Ready + Sealed + Opened envelopes + unfolded stationery)
        let birth = m.birth!
        let readyCap = TimeCapsule(
            title: "满半岁那天的灯下小记",
            body: "小满，今天你第一次靠着软垫自己坐稳了十几秒，举着木摇铃笑出声来。窗外下着细雨，床头灯暖暖地亮着，希望长大后的你，也一直记得被稳稳接住的感觉。",
            writtenAt: ms(today.plus(days: -17).date),
            writtenAgeLabel: "6 个月",
            unlockEpochDay: today.epochDay,
            openedAt: nil,
            seal: .gold
        )
        let sealedCap = TimeCapsule(
            title: "写给一岁生日的小满",
            body: "亲爱的小满，等你拆开这封信的时候，你已经走过一整年的四季啦。",
            writtenAt: ms(today.plus(days: -2).date),
            writtenAgeLabel: "6 个月 15 天",
            unlockEpochDay: TimeCapsule.birthdayEpochDay(from: birth, years: 1),
            openedAt: nil,
            seal: .teal
        )
        let openedCap = TimeCapsule(
            title: "你出生的第一百天",
            body: "今天你第一次对着镜头咧嘴笑出了梨涡，爸爸妈妈手忙脚乱拍了二十张糊掉的照片，却一张也舍不得删。",
            writtenAt: ms(birth.plus(days: 100).date),
            writtenAgeLabel: "3 个月 9 天",
            unlockEpochDay: nil,
            openedAt: ms(today.plus(days: -10).date),
            seal: .pink
        )
        let previewStore = CapsuleStore(preview: [readyCap, sealedCap, openedCap])
        shot("47_capsules_zh", height: 960, tabs(m, TimeCapsuleListView(store: previewStore)))
        shot("47_capsules_letter_zh", height: 852, CapsuleReadSheet(capsule: openedCap, store: previewStore).environment(m).tint(Palette.accent).fontDesign(.rounded))

        // 4. English variants
        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = true
        shot("45_today_instruments_en", height: 1260, tabs(mEn, TodayView(path: .constant(NavigationPath()))))
        shot("46_toybox_xylophone_en", height: 852, tabs(mEn, ToyboxView(initialMode: .xylophone)))
        let readyCapEn = TimeCapsule(
            title: "Six Months Under Otto's Lamp",
            body: "Leo, tonight you sat up all by yourself for ten bright seconds and giggled at your wooden rattle.",
            writtenAt: ms(today.plus(days: -17).date),
            writtenAgeLabel: "6 months",
            unlockEpochDay: today.epochDay,
            openedAt: nil,
            seal: .gold
        )
        let sealedCapEn = TimeCapsule(
            title: "To Leo on Your 1st Birthday",
            body: "When you unseal this wax stamp, we will have walked through four full seasons together.",
            writtenAt: ms(today.plus(days: -2).date),
            writtenAgeLabel: "6 mo 15 d",
            unlockEpochDay: TimeCapsule.birthdayEpochDay(from: birth, years: 1),
            openedAt: nil,
            seal: .teal
        )
        let previewStoreEn = CapsuleStore(preview: [readyCapEn, sealedCapEn])
        shot("47_capsules_en", height: 900, tabs(mEn, TimeCapsuleListView(store: previewStoreEn)))
    }

    /// Grand finale features: 2×3 Quiet Instruments dock, First Foods 60-item Atlas, Firefly Lantern Jar,
    /// Bedside Lamp 4–6 Calm Breathing Halo + Dual Soundscape Mix, and Visual Care Handover Studio (CN + EN + Lamp).
    func test48GrandFinaleFeatures() {
        let m = model(); m.journal = true
        let today = m.today

        let sampleFoods = FoodAtlasStore(preview: [
            FoodRecord(foodId: "pumpkin",     firstTastedEpochDay: today.plus(days: -18).epochDay, reaction: .loved),
            FoodRecord(foodId: "sweetpotato", firstTastedEpochDay: today.plus(days: -16).epochDay, reaction: .loved),
            FoodRecord(foodId: "carrot",      firstTastedEpochDay: today.plus(days: -14).epochDay, reaction: .tasted),
            FoodRecord(foodId: "avocado",     firstTastedEpochDay: today.plus(days: -11).epochDay, reaction: .loved),
            FoodRecord(foodId: "broccoli",    firstTastedEpochDay: today.plus(days: -9).epochDay,  reaction: .tryAgain, times: 3),
            FoodRecord(foodId: "banana",      firstTastedEpochDay: today.plus(days: -12).epochDay, reaction: .loved),
            FoodRecord(foodId: "apple",       firstTastedEpochDay: today.plus(days: -10).epochDay, reaction: .loved),
            FoodRecord(foodId: "blueberry",   firstTastedEpochDay: today.plus(days: -4).epochDay,  reaction: .tasted),
            FoodRecord(foodId: "ricecereal",  firstTastedEpochDay: today.plus(days: -20).epochDay, reaction: .loved),
            FoodRecord(foodId: "oatmeal",     firstTastedEpochDay: today.plus(days: -7).epochDay,  reaction: .tasted),
            FoodRecord(foodId: "eggyolk",     firstTastedEpochDay: today.plus(days: -6).epochDay,  reaction: .tasted, watchSkin: true),
            FoodRecord(foodId: "salmon",      firstTastedEpochDay: today.plus(days: -3).epochDay,  reaction: .loved),
            FoodRecord(foodId: "yogurt",      firstTastedEpochDay: today.plus(days: -2).epochDay,  reaction: .loved),
            FoodRecord(foodId: "oliveoil",    firstTastedEpochDay: today.plus(days: -1).epochDay,  reaction: .tasted),
        ])

        let nightClock = Day.cal.date(from: DateComponents(year: today.y, month: today.m, day: today.d, hour: 22, minute: 15)) ?? today.date.addingTimeInterval(22 * 3600 + 15 * 60)
        let handoverNow = Day.cal.date(from: DateComponents(year: today.y, month: today.m, day: today.d, hour: 20, minute: 15)) ?? today.date.addingTimeInterval(20 * 3600 + 15 * 60)

        var zhBody = JournalFile.Body()
        zhBody.logs = [
            LogEntry(type: LogType.bottle, start: self.at(19, 40), amount: 120),
            LogEntry(type: LogType.diaper, start: self.at(18, 5), detail: "wet"),
            LogEntry(type: LogType.nurse, start: self.at(16, 10), end: self.at(16, 28), side: "l"),
            LogEntry(type: LogType.nurse, start: self.at(16, 28), end: self.at(16, 40), side: "r", detail: "paused:120000"),
            LogEntry(type: LogType.sleep, start: self.at(13, 0), end: self.at(14, 35)),
            LogEntry(type: LogType.solid, start: self.at(11, 30), detail: "米粉"),
            LogEntry(type: LogType.sleep, start: self.at(0, 0) - 2 * 3_600_000, end: self.at(6, 30)),
        ]
        zhBody.timers = [RunningTimer(type: LogType.nurse, start: ms(handoverNow) - 12 * 60_000, side: "l")]
        let jZh = JournalStore(preview: zhBody)

        // 1. Home with balanced 2x3 Quiet Instruments dock (CN Day + Night Lamp)
        shot("48_today_6dock_zh", height: 1260, tabs(m, TodayView(path: .constant(NavigationPath()))))
        shot("48_today_6dock_lamp", height: 1260, lamp: true, tabs(m, TodayView(path: .constant(NavigationPath())).lamp(true).environment(\.night, true)))

        // 2. First Foods Tasting Box (CN Day + Night Lamp)
        shot("48_food_atlas_zh", height: 1120, tabs(m, FoodAtlasView(store: sampleFoods)))
        shot("48_food_atlas_lamp", height: 1120, lamp: true, tabs(m, FoodAtlasView(store: sampleFoods).lamp(true)))

        // 3. Sensory Toybox — Firefly Lantern Jar (CN Heart formation)
        shot("49_toybox_fireflies_zh", height: 852, tabs(m, ToyboxView(initialMode: .fireflies, initialFormation: .heart)))

        // 4. Bedside Lamp — 4-6 Breathing Halo ON + Dual-Layer Soundscape Mix (CN)
        SoundscapeEngine.shared.start(.rain)
        SoundscapeEngine.shared.toggleLayer(.lullaby)
        defer { SoundscapeEngine.shared.stop() }
        shot("49_lamp_breath_mix_zh", dark: true, height: 852,
             BedsideLampView(initialBrightness: 0.80, initialBreathingGuide: true, previewClock: nightClock).environment(m).environment(journal).fontDesign(.rounded))

        // 5. Visual Care Handover Studio Sheet (CN)
        shot("50_handover_card_zh", height: 852,
             HandoverSheet(day: today, previewNow: handoverNow).environment(m).environment(jZh).tint(Palette.accent).fontDesign(.rounded))

        // 6. English variants
        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = true
        var enBody = JournalFile.Body()
        enBody.logs = [
            LogEntry(type: LogType.bottle, start: self.at(19, 40), amount: 120),
            LogEntry(type: LogType.diaper, start: self.at(18, 5), detail: "wet"),
            LogEntry(type: LogType.nurse, start: self.at(16, 10), end: self.at(16, 28), side: "l"),
            LogEntry(type: LogType.nurse, start: self.at(16, 28), end: self.at(16, 40), side: "r", detail: "paused:120000"),
            LogEntry(type: LogType.sleep, start: self.at(13, 0), end: self.at(14, 35)),
            LogEntry(type: LogType.solid, start: self.at(11, 30), detail: "Oat cereal"),
            LogEntry(type: LogType.sleep, start: self.at(0, 0) - 2 * 3_600_000, end: self.at(6, 30)),
        ]
        enBody.timers = [RunningTimer(type: LogType.nurse, start: ms(handoverNow) - 12 * 60_000, side: "l")]
        let jEn = JournalStore(preview: enBody)

        shot("48_today_6dock_en", height: 1260, tabs(mEn, TodayView(path: .constant(NavigationPath()))))
        shot("48_food_atlas_en", height: 1120, tabs(mEn, FoodAtlasView(store: sampleFoods)))
        shot("49_toybox_fireflies_en", height: 852, tabs(mEn, ToyboxView(initialMode: .fireflies)))
        shot("49_lamp_breath_mix_en", dark: true, height: 852,
             BedsideLampView(initialBrightness: 0.80, initialBreathingGuide: true, previewClock: nightClock).environment(mEn).environment(journal).fontDesign(.rounded))
        shot("50_handover_card_en", height: 852,
             HandoverSheet(day: today, previewNow: handoverNow).environment(mEn).environment(jEn).tint(Palette.accent).fontDesign(.rounded))
    }

    /// v2.0 Batch 1 Showcase: Three-Halo Home (3D/2D/Lamp), Vertical Journey Hub, and 0-Emoji First Foods Atlas.
    func test49V2Batch1Showcase() {
        let m = model(); m.journal = true
        let today = m.today
        let sampleFoods = FoodAtlasStore(preview: [
            FoodRecord(foodId: "pumpkin",     firstTastedEpochDay: today.plus(days: -18).epochDay, reaction: .loved),
            FoodRecord(foodId: "sweetpotato", firstTastedEpochDay: today.plus(days: -16).epochDay, reaction: .loved),
            FoodRecord(foodId: "carrot",      firstTastedEpochDay: today.plus(days: -14).epochDay, reaction: .tasted),
            FoodRecord(foodId: "avocado",     firstTastedEpochDay: today.plus(days: -11).epochDay, reaction: .loved),
            FoodRecord(foodId: "broccoli",    firstTastedEpochDay: today.plus(days: -9).epochDay,  reaction: .tryAgain, times: 3),
            FoodRecord(foodId: "banana",      firstTastedEpochDay: today.plus(days: -12).epochDay, reaction: .loved),
            FoodRecord(foodId: "apple",       firstTastedEpochDay: today.plus(days: -10).epochDay, reaction: .loved),
            FoodRecord(foodId: "blueberry",   firstTastedEpochDay: today.plus(days: -4).epochDay,  reaction: .tasted),
            FoodRecord(foodId: "eggyolk",     firstTastedEpochDay: today.plus(days: -6).epochDay,  reaction: .tasted, watchSkin: true),
            FoodRecord(foodId: "salmon",      firstTastedEpochDay: today.plus(days: -3).epochDay,  reaction: .loved),
        ])

        shot("49_home_halo_zh", height: 1260, tabs(m, TodayView(path: .constant(NavigationPath()))))
        shot("49_home_halo_lamp", height: 1260, lamp: true, tabs(m, TodayView(path: .constant(NavigationPath())).lamp(true).environment(\.night, true)))

        let savedStyle = ArtStyle.current
        ArtStyle.current = .flat
        defer { ArtStyle.current = savedStyle }
        shot("49_home_halo_2d", height: 1260, tabs(m, TodayView(path: .constant(NavigationPath()))))
        ArtStyle.current = savedStyle

        shot("49_journey_hub_zh", height: 1320, tabs(m, JourneyHubView()))
        shot("49_foods_0emoji_zh", height: 1120, tabs(m, FoodAtlasView(store: sampleFoods)))
    }

    /// Batch 2A ADA Redesign Stress Test: Exact 37-entry newborn day (16 feeds, 11h25m sleep, 7 diapers, medicine, play),
    /// 3-track interactive swimlane scrubber, collapsed history bar, 0.6s inline bottle quick-tray, and 1-page DaySheetPoster!
    func test50JournalAdaRedesign() {
        let nov18 = Day(y: 2026, m: 11, d: 18)
        let nov17 = Day(y: 2026, m: 11, d: 17)
        let nov19 = Day(y: 2026, m: 11, d: 19)
        let m = model(birth: Day(y: 2026, m: 10, d: 1))
        m.today = nov19
        m.journal = true
        func tAt(_ d: Day, _ h: Int, _ mi: Int) -> Double {
            Day.cal.date(bySettingHour: h, minute: mi, second: 0, of: d.date)!.timeIntervalSince1970 * 1000
        }

        var body = JournalFile.Body()
        body.logs = [
            LogEntry(type: LogType.sleep, start: tAt(nov17, 23, 30), end: tAt(nov18, 1, 41)),
            LogEntry(type: LogType.nurse, start: tAt(nov18, 1, 36), end: tAt(nov18, 1, 43), side: "l", detail: "paused:60000"),
            LogEntry(type: LogType.diaper, start: tAt(nov18, 1, 41), detail: "wet"),
            LogEntry(type: LogType.sleep, start: tAt(nov18, 1, 41), end: tAt(nov18, 3, 47)),
            LogEntry(type: LogType.nurse, start: tAt(nov18, 3, 47), end: tAt(nov18, 3, 58), side: "l"),
            LogEntry(type: LogType.sleep, start: tAt(nov18, 3, 49), end: tAt(nov18, 6, 4)),
            LogEntry(type: LogType.diaper, start: tAt(nov18, 5, 10), detail: "wet"),
            LogEntry(type: LogType.nurse, start: tAt(nov18, 6, 4), end: tAt(nov18, 6, 8), side: "l"),
            LogEntry(type: LogType.nurse, start: tAt(nov18, 7, 52), end: tAt(nov18, 7, 54), side: "r"),
            LogEntry(type: LogType.sleep, start: tAt(nov18, 7, 53), end: tAt(nov18, 8, 0)),
            LogEntry(type: LogType.nurse, start: tAt(nov18, 8, 1), end: tAt(nov18, 8, 3), side: "l"),
            LogEntry(type: LogType.diaper, start: tAt(nov18, 8, 11), detail: "both"),
            LogEntry(type: LogType.medicine, start: tAt(nov18, 8, 31), detail: "维生素 AD"),
            LogEntry(type: LogType.nurse, start: tAt(nov18, 8, 41), end: tAt(nov18, 8, 45), side: "l"),
            LogEntry(type: LogType.play, start: tAt(nov18, 9, 20), detail: "A1 户外声音观察"),
            LogEntry(type: LogType.sleep, start: tAt(nov18, 9, 34), end: tAt(nov18, 10, 16)),
            LogEntry(type: LogType.diaper, start: tAt(nov18, 10, 50), detail: "wet"),
            LogEntry(type: LogType.nurse, start: tAt(nov18, 10, 56), end: tAt(nov18, 11, 2), side: "l"),
            LogEntry(type: LogType.sleep, start: tAt(nov18, 12, 22), end: tAt(nov18, 12, 32)),
            LogEntry(type: LogType.nurse, start: tAt(nov18, 12, 32), end: tAt(nov18, 12, 35), side: "l"),
            LogEntry(type: LogType.sleep, start: tAt(nov18, 12, 35), end: tAt(nov18, 14, 19)),
            LogEntry(type: LogType.nurse, start: tAt(nov18, 14, 19), end: tAt(nov18, 14, 39), side: "l", detail: "paused:240000"),
            LogEntry(type: LogType.sleep, start: tAt(nov18, 14, 19), end: tAt(nov18, 16, 18), detail: "paused:300000"),
            LogEntry(type: LogType.nurse, start: tAt(nov18, 15, 57), end: tAt(nov18, 16, 3), side: "l"),
            LogEntry(type: LogType.nurse, start: tAt(nov18, 16, 3) + 15_000, end: tAt(nov18, 16, 8), side: "r", detail: "paused:60000"),
            LogEntry(type: LogType.diaper, start: tAt(nov18, 16, 12), detail: "wet"),
            LogEntry(type: LogType.diaper, start: tAt(nov18, 16, 41), detail: "dirty"),
            LogEntry(type: LogType.nurse, start: tAt(nov18, 16, 47), end: tAt(nov18, 16, 51), side: "l"),
            LogEntry(type: LogType.bottle, start: tAt(nov18, 18, 25), amount: 20, detail: "breastmilk"),
            LogEntry(type: LogType.sleep, start: tAt(nov18, 19, 40), end: tAt(nov18, 20, 25)),
            LogEntry(type: LogType.bottle, start: tAt(nov18, 19, 51), amount: 30, detail: "breastmilk"),
            LogEntry(type: LogType.nurse, start: tAt(nov18, 21, 39), end: tAt(nov18, 21, 45), side: "l"),
            LogEntry(type: LogType.nurse, start: tAt(nov18, 21, 45) + 15_000, end: tAt(nov18, 21, 48), side: "r", detail: "paused:120000"),
            LogEntry(type: LogType.nurse, start: tAt(nov18, 22, 15), end: tAt(nov18, 22, 19), side: "l"),
            LogEntry(type: LogType.diaper, start: tAt(nov18, 23, 27), detail: "both"),
            LogEntry(type: LogType.nurse, start: tAt(nov18, 23, 30), end: tAt(nov18, 23, 36), side: "r"),
            // Today (Nov 19) sample entry
            LogEntry(type: LogType.bottle, start: tAt(nov19, 9, 10), amount: 30, detail: "breastmilk"),
        ]
        let denseStore = JournalStore(preview: body)

        shot("50_journal_newborn37_past_zh", height: 1100,
             NavigationStack { JournalView(path: .constant(NavigationPath()), initialDay: nov18) }
                 .environment(m).environment(denseStore).tint(Palette.accent).fontDesign(.rounded))
        shot("50_journal_today_quicktray_zh", height: 920,
             NavigationStack { JournalView(path: .constant(NavigationPath()), initialDay: nov19, initialQuickTray: LogType.bottle) }
                 .environment(m).environment(denseStore).tint(Palette.accent).fontDesign(.rounded))
        shot("50_journal_lamp", height: 1100, lamp: true,
             NavigationStack { JournalView(path: .constant(NavigationPath()), initialDay: nov18) }
                 .environment(m).environment(denseStore).lamp(true).tint(Palette.accent).fontDesign(.rounded))

        // 1-image complete DaySheetPoster (must fit all 37 entries on ONE single crisp sheet)
        let posterView = DaySheetPoster(babyName: m.nickname, ageText: "1个月18天", day: nov18, logs: denseStore.logs(on: nov18))
        shot("50_day_sheet_poster_zh", height: 1020, width: 420, posterView)

        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let mEn = model(birth: Day(y: 2026, m: 10, d: 1)); mEn.nickname = "Leo"; mEn.today = nov19; mEn.journal = true
        shot("50_journal_en", height: 1100,
             NavigationStack { JournalView(path: .constant(NavigationPath()), initialDay: nov18) }
                 .environment(mEn).environment(denseStore).tint(Palette.accent).fontDesign(.rounded))
    }

    /// Batch 2B Showcase: Smart Ear-Safe Volume Check (loud & safe), PlayView Living Motion Stage + Mat-Side Co-Play,
    /// Mochi × Otto Passing the Lantern Handover (sheet + 3× poster), and EN parity.
    func test51V2Batch2BShowcase() {
        let m = model(); m.journal = true
        let today = m.today

        // 1. Ear-Safe Volume Check in Toybox (Loud warning 78% + Safe comfort 38%)
        shot("51_toybox_volume_loud_zh", height: 852,
             tabs(m, ToyboxView(initialMode: .xylophone, previewVolume: 0.78, previewShowVolumeGuard: true)))
        shot("51_toybox_volume_safe_zh", height: 852,
             tabs(m, ToyboxView(initialMode: .rainstick, previewVolume: 0.38, previewShowVolumeGuard: true)))

        // 2. De-tasked PlayView Living Stage (A11 graspPass) & Mat-Side Focus Mode (A19 stackBuild)
        let playA11 = m.content.play("A11")!
        let playA19 = m.content.play("A19")!
        shot("51_play_living_stage_zh", height: 1320, tabs(m, PlayView(play: playA11, month: 6)))
        shot("51_play_matside_zh", height: 852,
             MatSideCoPlayView(play: playA19, month: 10, companion: .moss, currentStep: .constant(1), onSelectStep: { _ in })
                 .environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded))

        // 3. Mochi × Otto Passing the Lantern Handover (Live Sheet + 3× Poster)
        let handoverNow = Day.cal.date(from: DateComponents(year: today.y, month: today.m, day: today.d, hour: 20, minute: 15)) ?? today.date
        shot("51_handover_mochi_otto_zh", height: 852,
             HandoverSheet(day: today, previewNow: handoverNow, initialNote: "刚拍完嗝，准备小睡")
                 .environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded))
        let snap = HandoverSnapshot.build(app: m, journal: journal, day: today, now: handoverNow, extraNote: "刚拍完嗝，准备小睡")
        shot("51_handover_poster_3x_zh", height: 560, width: 393, HandoverPoster(snapshot: snap))

        // 4. Bedside Lamp High-Volume Midnight Safety Pill
        SoundscapeEngine.shared.start(.rain)
        defer { SoundscapeEngine.shared.stop() }
        let nightClock = Day.cal.date(from: DateComponents(year: today.y, month: today.m, day: today.d, hour: 22, minute: 45)) ?? today.date
        shot("51_lamp_volume_guard_zh", dark: true, height: 852,
             BedsideLampView(initialBrightness: 0.72, previewClock: nightClock, previewVolume: 0.80)
                 .environment(m).environment(journal).fontDesign(.rounded))

        // 5. English Parity (PlayView Living Stage + Loud Volume Check)
        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = true
        let playA11En = mEn.content.play("A11")!
        shot("51_play_living_stage_en", height: 1320, tabs(mEn, PlayView(play: playA11En, month: 6)))
        shot("51_toybox_volume_loud_en", height: 852,
             tabs(mEn, ToyboxView(initialMode: .xylophone, previewVolume: 0.78, previewShowVolumeGuard: true)))
    }

    /// Authentic Kid's Book Kinetic Art Overhaul: real per-step illustrations with animated crayon diagrams,
    /// die-cut sticker Mochi × Otto handover scene, paper-cut Land Journey hills, Storybook cover, and Capsules Desk.
    func test52PictureBookRenaissance() {
        let m = model(); m.journal = true
        let today = m.today

        shot("52_home_renaissance_zh", height: 1260, tabs(m, TodayView(path: .constant(NavigationPath()))))

        let playA11 = m.content.play("A11")!
        let playA19 = m.content.play("A19")!
        shot("52_play_storybook_zh", height: 1260, tabs(m, PlayView(play: playA11, month: 6)))
        shot(
            "52_play_steps_kinetic_zh",
            height: 980,
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("A11 · Step-by-Step Real Kid-Book Diagrams + Kinetic Cues")
                        .font(.headline.weight(.bold))
                        .padding(.horizontal, 4)
                    ForEach(0..<min(3, playA11.steps.count), id: \.self) { idx in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("第 \(idx + 1) 步：\(playA11.steps[idx])")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                            ActivityMotionStage(
                                play: playA11,
                                stepIndex: idx,
                                stepCount: playA11.steps.count,
                                stepText: playA11.steps[idx],
                                companion: .moss,
                                compact: true,
                                dark: false
                            )
                        }
                    }
                }
                .padding(16)
            }
            .background(Palette.paper)
            .environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded)
        )
        shot("52_play_matside_zh", height: 852,
             MatSideCoPlayView(play: playA19, month: 10, companion: .moss, currentStep: .constant(1), onSelectStep: { _ in })
                 .environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded))

        let handoverNow = Day.cal.date(from: DateComponents(year: today.y, month: today.m, day: today.d, hour: 20, minute: 15)) ?? today.date
        shot("52_handover_lantern_zh", height: 852,
             HandoverSheet(day: today, previewNow: handoverNow, initialNote: "刚拍完嗝，准备小睡")
                 .environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded))
        let snap = HandoverSnapshot.build(app: m, journal: journal, day: today, now: handoverNow, extraNote: "刚拍完嗝，准备小睡")
        shot("52_handover_poster_3x_zh", height: 670, width: 393, HandoverPoster(snapshot: snap))

        shot("52_journey_lands_zh", height: 1460, tabs(m, JourneyHubView()))
        shot("52_storybook_cover_zh", height: 852,
             StorybookView(initialPage: 0).environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded))
        shot("52_capsules_desk_zh", height: 852,
             tabs(m, TimeCapsuleListView(store: CapsuleStore(preview: []))))
    }

    /// Batch 3B: Zero-Touch StandBy Nursery Beacon (Full + Night Red Accented), Siri Cotton-Paper Status Snippet,
    /// Midnight CareTimer Cockpit (vinyl controls, 1-tap soundscape & high-volume guard, quick diaper),
    /// and Two-Tier Monthly Gallery (ZH + AX3 English Inclusivity).
    func test53Batch3BNurseryBeaconAndInclusivity() {
        let m = model(); m.journal = true
        let liveNow = Date()
        let liveMs = ms(liveNow)

        let snap = Snapshot(
            birthEpochDay: m.birth?.epochDay,
            nickname: "小苔",
            companion: "Otto",
            journal: true,
            playCode: "A11",
            playName: "左右手倒手",
            consented: true
        )
        var idle = JournalFile.Body()
        idle.logs = [
            LogEntry(type: LogType.sleep, start: liveMs - 14 * 3600_000, end: liveMs - 11 * 3600_000),
            LogEntry(type: LogType.nurse, start: liveMs - 10 * 3600_000, end: liveMs - 9 * 3600_000 - 40 * 60_000, side: "l"),
            LogEntry(type: LogType.sleep, start: liveMs - 6 * 3600_000, end: liveMs - 4 * 3600_000 - 15 * 60_000),
            LogEntry(type: LogType.bottle, start: liveMs - 95 * 60_000, amount: 110, detail: "breastmilk"),
            LogEntry(type: LogType.diaper, start: liveMs - 45 * 60_000, detail: "wet"),
        ]
        var timing = idle
        timing.timers = [RunningTimer(type: LogType.nurse, start: liveMs - 12 * 60_000, side: "r")]

        func widgetTile<BG: View>(_ w: CGFloat, _ h: CGFloat, bg: BG, _ content: some View) -> some View {
            content
                .padding(16)
                .frame(width: w, height: h)
                .background(bg)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }

        // 1. StandBy Full-Color Nursery Beacon
        shot("53_standby_beacon_full_zh", dark: true, height: 610,
             VStack(spacing: 16) {
                 HStack(spacing: 16) {
                     widgetTile(170, 170, bg: BedsideLampFace.backdrop,
                                BedsideLampFace(date: liveNow, snap: snap, body_: timing, isMedium: false))
                     widgetTile(170, 170, bg: BedsideLampFace.backdrop,
                                BedsideLampFace(date: liveNow, snap: snap, body_: idle, isMedium: false))
                 }
                 widgetTile(360, 170, bg: BedsideLampFace.backdrop,
                            BedsideLampFace(date: liveNow, snap: snap, body_: timing, isMedium: true))
                 widgetTile(360, 170, bg: BedsideLampFace.backdrop,
                            BedsideLampFace(date: liveNow, snap: snap, body_: idle, isMedium: true))
             }
             .padding(16)
             .frame(maxWidth: .infinity, maxHeight: .infinity)
             .background(Color(hex: 0x070A18))
             .fontDesign(.rounded))

        // 2. Siri Cotton-Paper Status Snippet
        let activeSummary = BabyCareStatusSummary.build(body: timing, snap: snap, now: liveNow)
        let idleSummary = BabyCareStatusSummary.build(body: idle, snap: snap, now: liveNow)
        shot("53_siri_status_snippet_zh", height: 480,
             VStack(spacing: 16) {
                 BabyCareStatusSnippetView(summary: activeSummary)
                 BabyCareStatusSnippetView(summary: idleSummary)
             }
             .padding(16)
             .frame(maxWidth: .infinity, maxHeight: .infinity)
             .background(Color(hex: 0xECE7DE))
             .fontDesign(.rounded))

        // 3. Midnight CareTimer Cockpit (vinyl buttons, 1-tap soundscape + high-volume guard, quick diaper)
        let timerJournal = JournalStore(preview: timing)
        SoundscapeEngine.shared.start(.lullaby)
        defer { SoundscapeEngine.shared.stop() }
        shot("53_care_timer_cockpit_lamp_zh", dark: true, height: 852, lamp: true,
             TimerScreen(type: LogType.nurse, previewVolume: 0.86)
                 .lampPresented(sheet: false)
                 .environment(m)
                 .environment(timerJournal)
                 .environment(MascotDirector())
                 .tint(Palette.accent)
                 .fontDesign(.rounded))

        // 4. Two-Tier Monthly Gallery (ZH Standard)
        shot("53_grow_month_gallery_zh", height: 1520, tabs(m, MonthView(month: 4)))

        // 5. StandBy Night Mode Red Accented + AX3 Monthly Gallery (English Parity)
        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let snapEn = Snapshot(
            birthEpochDay: m.birth?.epochDay,
            nickname: "Leo",
            companion: "Moss",
            journal: true,
            consented: true
        )
        shot("53_standby_beacon_accented_en", dark: true, height: 610,
             VStack(spacing: 16) {
                 HStack(spacing: 16) {
                     widgetTile(170, 170, bg: Color(hex: 0x090609),
                                BedsideLampFace(date: liveNow, snap: snapEn, body_: timing, isMedium: false, forceAccentedPreview: true))
                     widgetTile(170, 170, bg: Color(hex: 0x090609),
                                BedsideLampFace(date: liveNow, snap: snapEn, body_: idle, isMedium: false, forceAccentedPreview: true))
                 }
                 widgetTile(360, 170, bg: Color(hex: 0x090609),
                            BedsideLampFace(date: liveNow, snap: snapEn, body_: timing, isMedium: true, forceAccentedPreview: true))
                 widgetTile(360, 170, bg: Color(hex: 0x090609),
                            BedsideLampFace(date: liveNow, snap: snapEn, body_: idle, isMedium: true, forceAccentedPreview: true))
             }
             .padding(16)
             .frame(maxWidth: .infinity, maxHeight: .infinity)
             .background(Color.black)
             .fontDesign(.rounded))

        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = true
        shot("53_grow_month_ax3_en", height: 1560,
             tabs(mEn, MonthView(month: 4))
                 .environment(\.dynamicTypeSize, .accessibility3))
        shot("53_grow_parts_ax3_en", height: 1480,
             tabs(mEn, ScrollView { MonthParts(month: 4).padding(16) }.pageBackground())
                 .environment(\.dynamicTypeSize, .accessibility3))
    }

    /// Round 3 Creative Alchemy: Tactile Montessori Tabletop Renaissance — compact Ear-Safe Volume HUD,
    /// zero header overlap, hidden pushed TabBar headroom, rosewood Marimba, chamfered hardwood & glass Rainstick,
    /// apothecary collared Firefly Lantern Jar, and unified 3D sculpted Home studio instrument badges.
    func test54CreativeAlchemyTabletopRenaissance() {
        let m = model(); m.journal = true

        // 1. Pushed Marimba + compact Ear-Safe Volume HUD inside TabView+NavigationStack (verifies `<` back clearance, hidden TabBar & compact HUD)
        shot("54_toybox_marimba_compact_guard_zh", height: 852,
             TabView(selection: .constant(0)) {
                 Tab(value: 0) {
                     NavigationStack(path: .constant(["toy"])) {
                         Color.clear
                             .navigationDestination(for: String.self) { _ in
                                 ToyboxView(initialMode: .xylophone, previewVolume: 0.45, previewShowVolumeGuard: true)
                             }
                     }
                 } label: { Label(L10n.t("本月", "Today"), systemImage: "leaf.fill") }
             }
             .environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded))

        // 2. Turned beechwood & tempered-glass Rainstick Studio
        shot("54_toybox_rainstick_wood_zh", height: 852,
             NavigationStack {
                 ToyboxView(initialMode: .rainstick, previewVolume: 0.40)
             }
             .environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded))

        // 3. Integrated apothecary collar & curved blown-glass Firefly Jar (Heart constellation)
        shot("54_toybox_firefly_jar_zh", dark: true, height: 852,
             NavigationStack {
                 ToyboxView(initialMode: .fireflies, initialFormation: .heart, previewVolume: 0.35)
             }
             .environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded))

        // 4. Unified 3D Sculpted Home Studio Dock + Play Hero
        shot("54_home_studio_dock_3d_zh", height: 1460, tabs(m, TodayView(path: .constant(NavigationPath()))))

        // 5. English Parity (Marimba + compact HUD)
        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = true
        shot("54_toybox_marimba_en", height: 852,
             NavigationStack {
                 ToyboxView(initialMode: .xylophone, previewVolume: 0.45, previewShowVolumeGuard: true)
             }
             .environment(mEn).environment(journal).tint(Palette.accent).fontDesign(.rounded))
    }

    /// Round 4 Creative Alchemy (v2.0 RC): Kid's Book completion stamp keepsake card, clean v2.0 About page
    /// with locked `.warm` Otto bulb spring, and English 01/03 editorial folio + kinetic overlay.
    func test55V2ReleaseCandidatePolish() {
        let m = model(); m.journal = true
        let playA11 = m.content.play("A11")!

        shot("55_play_finished_keepsake_zh", height: 956,
             tabs(m, PlayView(play: playA11, month: 6, initialStep: playA11.steps.count)))

        shot("55_about_clean_2_0_zh", height: 956,
             tabs(m, AboutView()))

        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = true
        let playA11En = mEn.content.play("A11")!
        shot("55_play_folio_kinetic_en", height: 956,
             tabs(mEn, PlayView(play: playA11En, month: 6)))
    }

    /// Round 11 Three-Pillar Creative Alchemy (`v2.0 RC8 · Batch 11`):
    /// Interactive Montessori Tasting Cabinet (`FoodAtlasView`) in empty 0/60 state, with active thumb-zone
    /// Quick-Stamp Dock, in Night Lamp mode, plus warm `BirthSheet` greeting header.
    func test56FoodCabinetAndFixes() {
        let m = model(); m.journal = true
        let today = m.today

        let emptyFoods = FoodAtlasStore(preview: [])
        shot("56_food_cabinet_empty_zh", height: 956, tabs(m, FoodAtlasView(store: emptyFoods)))

        let sampleFoods = FoodAtlasStore(preview: [
            FoodRecord(foodId: "pumpkin",     firstTastedEpochDay: today.plus(days: -18).epochDay, reaction: .loved),
            FoodRecord(foodId: "sweetpotato", firstTastedEpochDay: today.plus(days: -16).epochDay, reaction: .loved),
            FoodRecord(foodId: "carrot",      firstTastedEpochDay: today.plus(days: -14).epochDay, reaction: .tasted),
            FoodRecord(foodId: "avocado",     firstTastedEpochDay: today.plus(days: -11).epochDay, reaction: .loved, times: 3),
            FoodRecord(foodId: "broccoli",    firstTastedEpochDay: today.plus(days: -9).epochDay,  reaction: .tryAgain, times: 2),
            FoodRecord(foodId: "banana",      firstTastedEpochDay: today.plus(days: -12).epochDay, reaction: .loved),
            FoodRecord(foodId: "apple",       firstTastedEpochDay: today.plus(days: -10).epochDay, reaction: .loved),
            FoodRecord(foodId: "ricecereal",  firstTastedEpochDay: today.plus(days: -20).epochDay, reaction: .loved),
            FoodRecord(foodId: "eggyolk",     firstTastedEpochDay: today.plus(days: -6).epochDay,  reaction: .tasted, watchSkin: true),
            FoodRecord(foodId: "salmon",      firstTastedEpochDay: today.plus(days: -3).epochDay,  reaction: .loved),
            FoodRecord(foodId: "yogurt",      firstTastedEpochDay: today.plus(days: -2).epochDay,  reaction: .loved),
            FoodRecord(foodId: "oliveoil",    firstTastedEpochDay: today.plus(days: -1).epochDay,  reaction: .tasted),
        ])
        shot("56_food_cabinet_stamp_dock_zh", height: 956,
             tabs(m, FoodAtlasView(store: sampleFoods, previewSelectedFoodId: "avocado")))
        shot("56_food_cabinet_lamp_zh", height: 956, lamp: true,
             tabs(m, FoodAtlasView(store: sampleFoods).lamp(true)))

        let mNew = model(birth: nil); mNew.onboarded = false
        shot("56_birth_sheet_zh", height: 852,
             BirthSheet().environment(mNew).tint(Palette.accent).fontDesign(.rounded))

        struct RealPlayTabHost: View {
            @Namespace private var zoomNS
            @State private var path = NavigationPath([Route.play("A11", 6)])
            var body: some View {
                TabView(selection: .constant(0)) {
                    Tab(value: 0) {
                        NavigationStack(path: $path) {
                            TodayView(path: $path).routes(path: $path)
                        }
                        .environment(\.zoomNS, zoomNS)
                    } label: {
                        Label(L10n.t("本月", "Today"), systemImage: "leaf.fill")
                    }
                }
            }
        }
        shot("56_play_real_tabview_zh", height: 852,
             RealPlayTabHost().environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded))
    }

    /// Round 12 Three-Pillar Creative Alchemy (`v2.0 RC9 · Batch 12`):
    /// Weekly Montessori Shelf Composer (`PlanView` + `ShelfEditor`), bidirectional Milestone Growth Ledger (`GrowthView`),
    /// balanced Time Capsule desk vignette (`TimeCapsuleListView`), and fixed Firsts summary wrap (`FirstsView`).
    func test57Round12AlchemyAndFixes() {
        let m = model(); m.journal = true
        let today = m.today
        let birth = m.birth!

        // 1. Weekly Montessori Shelf Composer (CN default, CN inline expanded drawer, Lamp, EN, and ShelfEditor sheet)
        shot("57_plan_composer_zh", height: 1180, tabs(m, PlanView(path: .constant(NavigationPath()))))
        let shelfCodes = Set(m.weekShelf(6).plays.map(\.code))
        let expandCode = Shelf.candidates(m.content, 6).first { !shelfCodes.contains($0.code) }?.code ?? "A08"
        shot("57_plan_composer_preview_zh", height: 1240,
             tabs(m, PlanView(path: .constant(NavigationPath()), previewExpandedCode: expandCode)))
        shot("57_plan_composer_lamp", height: 1180, lamp: true,
             tabs(m, PlanView(path: .constant(NavigationPath())).lamp(true)))
        shot("57_shelf_editor_sheet_zh", height: 852,
             ShelfEditor().environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded))

        // 2. GrowthView Bidirectional Milestone Growth Ledger (CN Day & Dark)
        shot("57_growth_ledger_zh", height: 1560, tabs(m, GrowthView()))
        shot("57_growth_ledger_dark", dark: true, height: 1560, tabs(m, GrowthView()))

        // 3. Rebalanced Time Capsule Desk Vignette (CN Day & Dark)
        let readyCap = TimeCapsule(
            title: "满半岁那天的灯下小记",
            body: "小满，今天你第一次靠着软垫自己坐稳了十几秒，举着木摇铃笑出声来。",
            writtenAt: ms(today.plus(days: -17).date),
            writtenAgeLabel: "6 个月",
            unlockEpochDay: today.epochDay,
            openedAt: nil,
            seal: .gold
        )
        let sealedCap = TimeCapsule(
            title: "写给一岁生日的小满",
            body: "亲爱的小满，等你拆开这封信的时候，你已经走过一整年的四季啦。",
            writtenAt: ms(today.plus(days: -2).date),
            writtenAgeLabel: "6 个月 15 天",
            unlockEpochDay: TimeCapsule.birthdayEpochDay(from: birth, years: 1),
            openedAt: nil,
            seal: .teal
        )
        let openedCap = TimeCapsule(
            title: "你出生的第一百天",
            body: "今天你第一次对着镜头咧嘴笑出了梨涡。",
            writtenAt: ms(birth.plus(days: 100).date),
            writtenAgeLabel: "3 个月 9 天",
            unlockEpochDay: nil,
            openedAt: ms(today.plus(days: -10).date),
            seal: .pink
        )
        let capStore = CapsuleStore(preview: [readyCap, sealedCap, openedCap])
        shot("57_capsules_hero_zh", height: 920, tabs(m, TimeCapsuleListView(store: capStore)))
        shot("57_capsules_hero_dark", dark: true, height: 920, tabs(m, TimeCapsuleListView(store: capStore)))

        // 4. FirstsView Fixed Summary Line (zero orphan leading dot)
        var fb = JournalFile.Body()
        fb.firsts = [
            First(at: at(10, 0) - 60 * 86_400_000, title: "第一次吃手"),
            First(at: at(10, 0) - 20 * 86_400_000, title: "第一次翻身"),
        ]
        let fj = JournalStore(preview: fb)
        shot("57_firsts_fixed_zh", height: 1100,
             NavigationStack { FirstsView() }.environment(m).environment(fj).tint(Palette.accent).fontDesign(.rounded))

        // 5. English Parity (PlanView Composer & GrowthView Ledger)
        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = true
        shot("57_plan_composer_en", height: 1180, tabs(mEn, PlanView(path: .constant(NavigationPath()))))
        shot("57_growth_ledger_en", height: 1560, tabs(mEn, GrowthView()))
    }

    /// Bedside Lamp Midnight Sanctuary Console: 2 a.m. factual whisper strip, inline bottle/diaper quick trays,
    /// and zero-glare lamp-matched Undo toast banner (CN + EN).
    func test58BedsideLampMidnightSanctuaryConsole() {
        let m = model(); m.journal = true
        let today = m.today
        let nightClock = Day.cal.date(bySettingHour: 2, minute: 35, second: 0, of: today.date)!
        let nightMs = nightClock.timeIntervalSince1970 * 1000

        var b = JournalFile.Body()
        b.logs = [
            LogEntry(type: LogType.bottle, start: nightMs - 155 * 60_000, amount: 150, detail: "breastmilk"),
            LogEntry(type: LogType.sleep, start: nightMs - 240 * 60_000, end: nightMs - 75 * 60_000),
            LogEntry(type: LogType.diaper, start: nightMs - 50 * 60_000, detail: "wet"),
        ]
        let idleJournal = JournalStore(preview: b)

        SoundscapeEngine.shared.start(.rain)
        defer { SoundscapeEngine.shared.stop() }

        shot("58_lamp_midnight_bottle_zh", dark: true, height: 852,
             BedsideLampView(
                 initialBrightness: 0.78,
                 initialWarmth: .amber,
                 initialQuickCare: .bottle,
                 previewClock: nightClock
             ).environment(m).environment(idleJournal).fontDesign(.rounded))

        var activeBody = b
        activeBody.timers = [RunningTimer(type: LogType.nurse, start: nightMs - 11 * 60_000, side: "l")]
        let activeJournal = JournalStore(preview: activeBody)
        activeJournal.toast = Toast(type: LogType.diaper, text: "已记下 尿布 · 湿 · 02:35", restore: b)
        shot("58_lamp_midnight_toast_diaper_zh", dark: true, height: 852,
             BedsideLampView(
                 initialBrightness: 0.72,
                 initialWarmth: .candle,
                 initialQuickCare: .diaper,
                 previewClock: nightClock
             ).environment(m).environment(activeJournal).fontDesign(.rounded))

        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = true
        let enJournal = JournalStore(preview: b)
        enJournal.toast = Toast(type: LogType.bottle, text: "Logged Bottle · 150 ml · 02:35", restore: b)
        shot("58_lamp_midnight_bottle_en", dark: true, height: 852,
             BedsideLampView(
                 initialBrightness: 0.78,
                 initialWarmth: .peach,
                 initialQuickCare: .bottle,
                 previewClock: nightClock
             ).environment(mEn).environment(enJournal).fontDesign(.rounded))
    }

    /// Round 13 Three-Pillar Creative Alchemy (`v2.0 RC10 · Batch 13`):
    /// Visual-first Home Screen Journey Passport (`MonthCard` + 37-station `MiniJourneyBeadStrip`), visual `DueCard`,
    /// unified `JourneyHubView` hero, and visual-first Family Studio `YouView` + `GrowthBookCard` across Day/Dark/Lamp/EN/AX2.
    func test59Round13HomeJourneyAndYouStudio() {
        let m = model(); m.journal = true

        // 1. Home Journey Passport & Visual DueCard / Dock (CN Day, Dark, Lamp, AX2)
        shot("59_today_journey_passport_zh", height: 1260, tabs(m, TodayView(path: .constant(NavigationPath()))))
        shot("59_today_journey_passport_dark", dark: true, height: 1260, tabs(m, TodayView(path: .constant(NavigationPath()))))
        shot("59_today_journey_passport_lamp", height: 1260, lamp: true,
             tabs(m, TodayView(path: .constant(NavigationPath())).lamp(true).environment(\.night, true)))
        shot("59_today_journey_passport_ax2", height: 1680,
             tabs(m, TodayView(path: .constant(NavigationPath()))).dynamicTypeSize(.accessibility2))

        // 2. Unified JourneyHubView Hero
        shot("59_journey_hub_unified_zh", height: 1120, tabs(m, JourneyHubView()))

        // 3. Visual-First Family Studio YouView & GrowthBookCard (CN Day, Dark, Lamp, AX2)
        shot("59_you_studio_zh", height: 1080, tabs(m, YouView(path: .constant(NavigationPath()))))
        shot("59_you_studio_dark", dark: true, height: 1080, tabs(m, YouView(path: .constant(NavigationPath()))))
        shot("59_you_studio_lamp", height: 1080, lamp: true,
             tabs(m, YouView(path: .constant(NavigationPath())).lamp(true)))
        shot("59_you_studio_ax2", height: 1520,
             tabs(m, YouView(path: .constant(NavigationPath()))).dynamicTypeSize(.accessibility2))

        // 4. English Parity
        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = true
        shot("59_today_journey_passport_en", height: 1260, tabs(mEn, TodayView(path: .constant(NavigationPath()))))
        shot("59_you_studio_en", height: 1080, tabs(mEn, YouView(path: .constant(NavigationPath()))))
    }

    /// Daily Rhythm Studio: 24-hour circadian bead loom, 5-stage 0–3 yr evolution rail,
    /// and gentle comparison with logged 7-day sleep across Day / Lamp / EN.
    func test60DailyRhythmStudio() {
        let m = model(); m.journal = true
        let today = m.today

        var body = JournalFile.Body()
        for back in 0..<5 {
            let d = today.plus(days: -back)
            let wakeMs = Day.cal.date(bySettingHour: 7, minute: 0, second: 0, of: d.date)!.timeIntervalSince1970 * 1000
            let napMs = Day.cal.date(bySettingHour: 13, minute: 15, second: 0, of: d.date)!.timeIntervalSince1970 * 1000
            body.logs.append(LogEntry(type: LogType.sleep, start: wakeMs - 11 * 3_600_000, end: wakeMs))
            body.logs.append(LogEntry(type: LogType.sleep, start: napMs, end: napMs + 105 * 60_000))
        }
        let playMs = Day.cal.date(bySettingHour: 10, minute: 30, second: 0, of: today.date)!.timeIntervalSince1970 * 1000
        body.logs.append(LogEntry(type: LogType.play, start: playMs, detail: "A11"))
        let liveJournal = JournalStore(preview: body)

        shot("60_daily_rhythm_infant_zh", height: 1460,
             NavigationStack { RhythmView(month: 6) }
                 .environment(m).environment(liveJournal).tint(Palette.accent).fontDesign(.rounded))

        shot("60_daily_rhythm_toddler_lamp_zh", dark: true, height: 1460, lamp: true,
             NavigationStack { RhythmView(month: 24, initialInspectedHour: 14) }
                 .environment(m).environment(liveJournal).lamp(true).tint(Palette.accent).fontDesign(.rounded))

        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = false
        shot("60_daily_rhythm_newborn_en", height: 1460,
             NavigationStack { RhythmView(month: 0) }
                 .environment(mEn).environment(journal).tint(Palette.accent).fontDesign(.rounded))
    }

    /// Round 14 Visual Discovery Search Compass, 6-Area Montessori Constellation Lens,
    /// Dual-Ring Care / 4-Domain Observe progress boards & Stage-Pill TopicView across Day/Dark/Lamp/EN/AX2.
    func test61Round14VisualDiscoveryAndMonthStudios() {
        let m = model(); m.journal = true

        // 1. Visual Discovery Search Compass (Idle Day/Dark/AX2 + Active Scope Ribbon)
        shot("61_search_compass_zh", height: 1120, tabs(m, SearchView(path: .constant(NavigationPath()))))
        shot("61_search_compass_dark", dark: true, height: 1120, tabs(m, SearchView(path: .constant(NavigationPath()))))
        shot("61_search_active_zh", height: 1120, tabs(m, SearchView(path: .constant(NavigationPath()), initialQuery: "睡")))
        shot("61_search_compass_ax2", height: 1480,
             tabs(m, SearchView(path: .constant(NavigationPath()))).dynamicTypeSize(.accessibility2))

        // 2. 6-Area Montessori Constellation Lens (CN Day & Dark)
        shot("61_areas_constellation_zh", height: 1180, tabs(m, AreasView(month: 6)))
        shot("61_areas_constellation_dark", dark: true, height: 1180, tabs(m, AreasView(month: 6)))

        // 3. Visual-First CareView (1 vaccine ticked + earlier overdue pill) & ObserveView
        let mc = model()
        if let firstVac = mc.content.month(6).vaccines.first {
            mc.toggle(6, TickKind.vaccine, "0", firstVac)
        }
        shot("61_care_visual_zh", height: 1100, tabs(mc, CareView(month: 6)))
        shot("61_care_visual_lamp", height: 1100, lamp: true, tabs(mc, CareView(month: 6).lamp(true)))
        shot("61_observe_visual_zh", height: 1180, tabs(mc, ObserveView(month: 6)))

        // 4. Stage-Pill TopicView (CN)
        shot("61_topic_stage_pills_zh", height: 960, tabs(m, TopicView(topic: m.content.topics[0])))

        // 5. English Parity
        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = true
        shot("61_search_compass_en", height: 1120, tabs(mEn, SearchView(path: .constant(NavigationPath()))))
        shot("61_areas_constellation_en", height: 1180, tabs(mEn, AreasView(month: 6, initialAreaKey: "D")))
        shot("61_topic_stage_pills_en", height: 960, tabs(mEn, TopicView(topic: mEn.content.topics[0])))
    }

    /// Round 15 Apple Design Award Craft & Real-Device Fixes (`v2.0 RC12 · Batch 15`) — Part A:
    /// Living Montessori Atelier Home Dock & Living CareTimer Companion Stage + AX2 Zero-Truncation Fix.
    func test62Round15AtelierAndTimer() {
        let m = model(); m.journal = true

        // 1. Living Montessori Atelier Home Dock (with active Bedside Lamp soundscape)
        SoundscapeEngine.shared.start(.rain)
        shot("62_today_atelier_zh", height: 1540, tabs(m, TodayView(path: .constant(NavigationPath()))))
        shot("62_today_atelier_dark", dark: true, height: 1540, tabs(m, TodayView(path: .constant(NavigationPath()))))
        shot("62_today_atelier_lamp", height: 1540, lamp: true,
             tabs(m, TodayView(path: .constant(NavigationPath())).lamp(true).environment(\.night, true)))
        shot("62_today_atelier_ax2", height: 1500,
             tabs(m, TodayView(path: .constant(NavigationPath()))).dynamicTypeSize(.accessibility2))

        // 2. Living CareTimer Companion Stage & AX2 Zero-Truncation Fix
        shot("62_timer_living_nurse_zh",
             TimerScreen(type: LogType.nurse).environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded))

        var sleepBody = JournalFile.Body()
        sleepBody.timers = [RunningTimer(type: LogType.sleep, start: ms(Date()) - 42 * 60_000)]
        let sleepJournal = JournalStore(preview: sleepBody)
        shot("62_timer_living_sleep_lamp_zh", lamp: true,
             TimerScreen(type: LogType.sleep).lamp(true).environment(m).environment(sleepJournal).tint(Palette.accent).fontDesign(.rounded))

        SoundscapeEngine.shared.stop()
        shot("62_timer_ax2_fixed_zh", height: 1280,
             TimerScreen(type: LogType.nurse).environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded).dynamicTypeSize(.accessibility2))

        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = true
        SoundscapeEngine.shared.start(.breeze)
        defer { SoundscapeEngine.shared.stop() }
        shot("62_today_atelier_en", height: 1540, tabs(mEn, TodayView(path: .constant(NavigationPath()))))
    }

    /// Round 15 (`v2.0 RC12 · Batch 15`) — Part B: 3-Act Interactive Story Micro-Theater.
    func test62Round15StoryTheater() {
        let m = model(); m.journal = true
        shot("62_story_theater_lamp_zh", height: 920, tabs(m, StoryView(initialAct: .lamp)))
        shot("62_story_theater_explore_zh", height: 920, tabs(m, StoryView(initialAct: .explore)))
        shot("62_story_theater_grow_zh", height: 980, tabs(m, StoryView(initialAct: .grow, initialMonth: 18)))
        shot("62_story_theater_dark", dark: true, height: 920, tabs(m, StoryView(initialAct: .lamp)))

        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = true
        shot("62_story_theater_en", height: 920, tabs(mEn, StoryView(initialAct: .grow, initialMonth: 18)))
    }

    /// Round 15 (`v2.0 RC12 · Batch 15`) — Part C: Compact Me Studio, Streamlined FoodAtlas & Fixed Storybook Spread.
    func test62Round15YouFoodsAndStorybook() {
        let m = model(); m.journal = true
        let sampleFoods = FoodAtlasStore(preview: [
            FoodRecord(foodId: "pumpkin", firstTastedEpochDay: m.today.plus(days: -12).epochDay, reaction: .loved, note: "蒸泥", watchSkin: false, times: 4),
            FoodRecord(foodId: "avocado", firstTastedEpochDay: m.today.plus(days: -9).epochDay, reaction: .loved, note: "", watchSkin: false, times: 3),
            FoodRecord(foodId: "broccoli", firstTastedEpochDay: m.today.plus(days: -6).epochDay, reaction: .tryAgain, note: "下次压碎", watchSkin: false, times: 1),
            FoodRecord(foodId: "eggyolk", firstTastedEpochDay: m.today.plus(days: -2).epochDay, reaction: .tasted, note: "1/4 个", watchSkin: true, times: 2),
        ])

        shot("62_you_compact_zh", height: 1020, tabs(m, YouView(path: .constant(NavigationPath()))))
        shot("62_you_compact_dark", dark: true, height: 1020, tabs(m, YouView(path: .constant(NavigationPath()))))
        shot("62_you_compact_ax2", height: 1460,
             tabs(m, YouView(path: .constant(NavigationPath()))).dynamicTypeSize(.accessibility2))

        shot("62_foods_clean_zh", height: 1060, tabs(m, FoodAtlasView(store: sampleFoods)))

        var bookBody = JournalFile.Body()
        bookBody.logs = journal.logs
        bookBody.logs.append(LogEntry(type: LogType.play, start: ms(m.today.date.addingTimeInterval(16 * 3600)), detail: "A11 双手物品传递机会"))
        bookBody.logs.append(LogEntry(type: LogType.note, start: ms(m.today.date.addingTimeInterval(17 * 3600)), detail: "今天自己抓着木摇铃左右倒手玩了好久，一直咯咯笑。"))
        bookBody.measures = journal.measures
        let sitAt = ms(m.today.plus(days: -6).date)
        bookBody.firsts = [First(at: sitAt, key: "sit", title: "坐", note: "靠着软垫自己坐稳了十几秒")]
        let bookJournal = JournalStore(preview: bookBody)
        shot("62_storybook_spread_fixed_zh", height: 852,
             StorybookView(initialPage: 7, foodStore: sampleFoods).environment(m).environment(bookJournal).tint(Palette.accent).fontDesign(.rounded))

        L10n.overrideEnglish = true
        defer { L10n.overrideEnglish = nil }
        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = true
        shot("62_foods_clean_en", height: 1060, tabs(mEn, FoodAtlasView(store: sampleFoods)))
    }

    /// Round 16 Apple Design Award Sprint — Living Picture-Book StoryTheater Phase 1 (A04 & A12 across Day/Lamp/2D/EN).
    func test63Round16LivingBookA04AndA12() {
        defer {
            ArtStyle.current = .vinyl
            L10n.overrideEnglish = nil
        }
        let m = model(); m.journal = true
        let playA04 = m.content.play("A04")!
        let playA12 = m.content.play("A12")!

        shot("63_living_a04_step1_day_zh", height: 960, tabs(m, PlayView(play: playA04, month: 4, initialStep: 0)))
        shot("63_living_a04_step3_day_zh", height: 960, tabs(m, PlayView(play: playA04, month: 4, initialStep: 2)))

        shot("63_living_a12_step1_day_zh", height: 960, tabs(m, PlayView(play: playA12, month: 9, initialStep: 0)))
        shot("63_living_a12_step3_day_zh", height: 960, tabs(m, PlayView(play: playA12, month: 9, initialStep: 2)))
        shot("63_living_a12_lamp_zh", height: 960, lamp: true, tabs(m, PlayView(play: playA12, month: 9, initialStep: 0).lamp(true)))

        ArtStyle.current = .flat
        shot("63_living_a12_2d_zh", height: 960, tabs(m, PlayView(play: playA12, month: 9, initialStep: 0)))
        ArtStyle.current = .vinyl

        L10n.overrideEnglish = true
        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = true
        let playA12En = mEn.content.play("A12")!
        shot("63_living_a12_en", height: 960, tabs(mEn, PlayView(play: playA12En, month: 9, initialStep: 0)))
    }

    /// Round 16 — Living Picture-Book StoryTheater Phase 1 (A19 3-step build/tumble, Dark, Mat Mode, AX2, & Triptych).
    func test63Round16LivingBookA19AndModes() {
        defer { L10n.overrideEnglish = nil }
        let m = model(); m.journal = true
        let playA19 = m.content.play("A19")!

        shot("63_living_a19_step1_day_zh", height: 960, tabs(m, PlayView(play: playA19, month: 14, initialStep: 0)))
        shot("63_living_a19_step2_day_zh", height: 960, tabs(m, PlayView(play: playA19, month: 14, initialStep: 1)))
        shot("63_living_a19_step3_tumble_zh", height: 960, tabs(m, PlayView(play: playA19, month: 14, initialStep: 2)))
        shot("63_living_a19_dark_zh", dark: true, height: 960, tabs(m, PlayView(play: playA19, month: 14, initialStep: 1)))
        shot("63_living_a19_matside_lamp_zh", height: 852, lamp: true,
             MatSideCoPlayView(play: playA19, month: 14, companion: .moss, currentStep: .constant(1), onSelectStep: { _ in })
                 .lamp(true).environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded))
        shot("63_living_a19_ax2_zh", height: 1240,
             tabs(m, PlayView(play: playA19, month: 14, initialStep: 1)).dynamicTypeSize(.accessibility2))

        L10n.overrideEnglish = true
        let s04 = LivingBookCatalog.script(for: "A04")!
        let s12 = LivingBookCatalog.script(for: "A12")!
        let s19 = LivingBookCatalog.script(for: "A19")!
        let triptych = ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Living StoryTheater · Daylight · Night Lamp · 2D Cut-Paper")
                    .font(.headline.weight(.bold))
                LivingBookStage(script: s04, stepIndex: 0, companion: .moss, dark: false, accent: Crayon.teal, posterPhase: s04.steps[0].posterPhase, interactive: false, forceFlat: false)
                LivingBookStage(script: s12, stepIndex: 0, companion: .moss, dark: true, accent: Crayon.pink, posterPhase: s12.steps[0].posterPhase, interactive: false, forceFlat: false)
                LivingBookStage(script: s19, stepIndex: 2, companion: .moss, dark: false, accent: Crayon.cherry, posterPhase: s19.steps[2].posterPhase, interactive: false, forceFlat: true)
            }
            .padding(16)
        }
        .background(Palette.paper)
        shot("63_living_triptych_modes_en", height: 960, triptych)
    }

    /// Round 16 — Dark Mode PageBackground fix, YouView AX2 Swatch fix, SearchView 4-pill balance & Finished/Legacy PlayView polish.
    func test63Round16FixesAndParity() {
        let m = model(); m.journal = true
        let playA19 = m.content.play("A19")!
        let playA11 = m.content.play("A11")!

        shot("63_fix_month_dark_zh", dark: true, height: 1280, tabs(m, MonthView(month: 6)))
        shot("63_fix_you_ax2_zh", height: 1460, tabs(m, YouView(path: .constant(NavigationPath()))).dynamicTypeSize(.accessibility2))
        shot("63_fix_search_4pills_zh", height: 1120, tabs(m, SearchView(path: .constant(NavigationPath()))))
        shot("63_fix_search_4pills_ax2", height: 1480, tabs(m, SearchView(path: .constant(NavigationPath()))).dynamicTypeSize(.accessibility2))
        shot("63_living_finished_a19_zh", height: 1020, tabs(m, PlayView(play: playA19, month: 14, initialStep: 3)))
        shot("63_fix_play_a11_clean_zh", height: 1160, tabs(m, PlayView(play: playA11, month: 6, initialStep: 0)))
    }

    /// Round 17 — Full Living StoryTheater Phase 2 across Newborn (N01) & Bespoke Montessori Props (Mirror/Ball/Crayon/Bridge/Stacker/Doll/Cup).
    func test64Round17LivingBookAllPropsAndNewborn() {
        let m = model(); m.journal = true
        let playN01 = m.content.play("N01")!
        let playA09 = m.content.play("A09")!
        let playA18 = m.content.play("A18")!
        let playA24 = m.content.play("A24")!
        let playA33 = m.content.play("A33")!
        let playA27 = m.content.play("A27")!
        let playA25 = m.content.play("A25")!
        let playA14 = m.content.play("A14")!

        shot("64_living_n01_newborn_zh", height: 960, tabs(m, PlayView(play: playN01, month: 0, initialStep: 0)))
        shot("64_living_a09_mirror_zh", height: 960, tabs(m, PlayView(play: playA09, month: 7, initialStep: 0)))
        shot("64_living_a18_ball_zh", height: 960, tabs(m, PlayView(play: playA18, month: 12, initialStep: 0)))
        shot("64_living_a24_crayon_zh", height: 960, tabs(m, PlayView(play: playA24, month: 19, initialStep: 2)))
        shot("64_living_a33_bridge_lamp_zh", height: 960, lamp: true, tabs(m, PlayView(play: playA33, month: 27, initialStep: 1).lamp(true)))
        shot("64_living_a27_stacker_zh", height: 960, tabs(m, PlayView(play: playA27, month: 22, initialStep: 0)))
        shot("64_living_a25_doll_zh", height: 960, tabs(m, PlayView(play: playA25, month: 20, initialStep: 0)))
        shot("64_living_a14_woodcup_zh", height: 960, tabs(m, PlayView(play: playA14, month: 10, initialStep: 0)))
    }

    /// Round 17 — Living Growth Chapter Covers Phase 3 across Meadow (0m/6m), Woodland (18m), Stream (24m/30m), 2D Flat, Storybook & JourneyHub.
    func test65Round17LivingMonthCoversAndParity() {
        defer { ArtStyle.current = .vinyl }
        let m = model(); m.journal = true
        let m18 = model(birth: Day(y: 2025, m: 4, d: 19)); m18.journal = true

        shot("65_today_living_cover_zh", height: 1260, tabs(m, TodayView(path: .constant(NavigationPath()))))
        shot("65_month_00_meadow_zh", height: 1040, tabs(m, MonthView(month: 0)))
        shot("65_month_06_dark_zh", dark: true, height: 1040, tabs(m, MonthView(month: 6)))
        shot("65_month_18_woodland_zh", height: 1040, tabs(m18, MonthView(month: 18)))
        shot("65_month_30_stream_lamp_zh", height: 1040, lamp: true, tabs(m18, MonthView(month: 30).lamp(true)))

        ArtStyle.current = .flat
        shot("65_month_24_2d_zh", height: 1040, tabs(m18, MonthView(month: 24)))
        ArtStyle.current = .vinyl

        shot("65_storybook_cover_living_zh", height: 852,
             StorybookView(initialPage: 0).environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded))
        shot("65_journey_hub_living_zh", height: 1120, tabs(m, JourneyHubView()))
    }

    /// Round 17 — Storybook Spread, PlayView Step 2 Replay + Unplayed Bead Fix, MonthView AX2 EN & YouView GrowthBook Card Fan.
    func test66Round17FixesAndStorybookSpread() {
        defer { L10n.overrideEnglish = nil }
        let m = model(); m.journal = true
        let playA19 = m.content.play("A19")!

        shot("66_storybook_spread_living_zh", height: 852,
             StorybookView(initialPage: 7).environment(m).environment(journal).tint(Palette.accent).fontDesign(.rounded))
        shot("66_play_a19_step2_replay_zh", height: 960, tabs(m, PlayView(play: playA19, month: 14, initialStep: 1)))
        shot("66_you_living_growthbook_zh", height: 1080, tabs(m, YouView(path: .constant(NavigationPath()))))

        L10n.overrideEnglish = true
        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = true
        shot("66_month_12_ax2_en", height: 1320, tabs(mEn, MonthView(month: 12)).dynamicTypeSize(.accessibility2))
    }

    /// Round 18 — Montessori Firsts Keepsake Studio (Empty Stage Invitation, Polaroid Garland, Night Lamp, AX2, & EN).
    func test67FirstsKeepsakeStudio() {
        defer { L10n.overrideEnglish = nil }
        let m = model(); m.journal = true
        shot("67_firsts_empty_zh", height: 1080, tabs(m, FirstsView()))

        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 2
        let sampleA = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 240), format: fmt).image { ctx in
            UIColor(red: 0.96, green: 0.88, blue: 0.72, alpha: 1).setFill()
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 240, height: 240))
            UIColor(red: 0.25, green: 0.62, blue: 0.54, alpha: 1).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 56, y: 74, width: 128, height: 128))
        }
        let sampleB = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 240), format: fmt).image { ctx in
            UIColor(red: 0.88, green: 0.93, blue: 0.97, alpha: 1).setFill()
            ctx.cgContext.fill(CGRect(x: 0, y: 0, width: 240, height: 240))
            UIColor(red: 0.90, green: 0.56, blue: 0.36, alpha: 1).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 64, y: 64, width: 112, height: 112))
        }

        let f1 = First(at: at(10, 0) - 90 * 86_400_000, key: "smile", title: "第一次笑", note: "醒来看到窗帘透进的光就咧嘴笑了")
        let f2 = First(at: at(10, 0) - 42 * 86_400_000, key: "roll", title: "翻身", note: "在软垫上自己翻过去了")
        let f3 = First(at: at(10, 0) - 8 * 86_400_000, key: "sit", title: "坐", note: "靠着抱枕稳稳坐住")
        FirstPhotoStore.save(sampleA, for: f3.id)
        FirstPhotoStore.save(sampleB, for: f1.id)
        defer {
            FirstPhotoStore.delete(for: f3.id)
            FirstPhotoStore.delete(for: f1.id)
        }

        var b = JournalFile.Body()
        b.firsts = [f3, f2, f1]
        let fj = JournalStore(preview: b)

        shot("67_firsts_gallery_zh", height: 1320,
             NavigationStack { FirstsView() }.environment(m).environment(fj).tint(Palette.accent).fontDesign(.rounded))
        shot("67_firsts_gallery_lamp_zh", height: 1320, lamp: true,
             NavigationStack { FirstsView() }.lamp(true).environment(m).environment(fj).tint(Palette.accent).fontDesign(.rounded))
        shot("67_firsts_gallery_ax2_zh", height: 1620,
             NavigationStack { FirstsView() }.environment(m).environment(fj).tint(Palette.accent).fontDesign(.rounded).dynamicTypeSize(.accessibility2))

        L10n.overrideEnglish = true
        let mEn = model(); mEn.nickname = "Leo"; mEn.journal = true
        shot("67_firsts_gallery_en", height: 1320,
             NavigationStack { FirstsView() }.environment(mEn).environment(fj).tint(Palette.accent).fontDesign(.rounded))
    }

    /// Round 18 — Pixar 3D x Ghibli 2D Flagship Showcases (N01, A04, Month 6), Read-Only DayLedger, & Restored Act 1 Lamp.
    func test68Round18PixarGhibliShowcaseAndP0() {
        defer { ArtStyle.current = .vinyl }
        let m = model(); m.journal = true

        if let n01 = LivingBookCatalog.script(for: "N01") {
            let n01Plate = showcase2x2(
                tl: LivingBookStage(script: n01, stepIndex: 0, companion: .moss, dark: false, posterPhase: 0.56, interactive: false, forceFlat: false),
                tr: LivingBookStage(script: n01, stepIndex: 2, companion: .moss, dark: true, posterPhase: 0.62, interactive: false, forceFlat: false),
                bl: LivingBookStage(script: n01, stepIndex: 0, companion: .moss, dark: false, posterPhase: 0.56, interactive: false, forceFlat: true),
                br: LivingBookStage(script: n01, stepIndex: 2, companion: .moss, dark: true, posterPhase: 0.62, interactive: false, forceFlat: true)
            )
            shot("68_showcase_n01_4modes", height: 520, n01Plate.environment(m).tint(Palette.accent).fontDesign(.rounded))
        }

        if let a04 = LivingBookCatalog.script(for: "A04") {
            let a04Plate = showcase2x2(
                tl: LivingBookStage(script: a04, stepIndex: 0, companion: .moss, dark: false, posterPhase: 0.54, interactive: false, forceFlat: false),
                tr: LivingBookStage(script: a04, stepIndex: 2, companion: .moss, dark: true, posterPhase: 0.60, interactive: false, forceFlat: false),
                bl: LivingBookStage(script: a04, stepIndex: 0, companion: .moss, dark: false, posterPhase: 0.54, interactive: false, forceFlat: true),
                br: LivingBookStage(script: a04, stepIndex: 2, companion: .moss, dark: true, posterPhase: 0.60, interactive: false, forceFlat: true)
            )
            shot("68_showcase_a04_4modes", height: 520, a04Plate.environment(m).tint(Palette.accent).fontDesign(.rounded))
        }

        let m06Plate = showcase2x2(
            tl: LivingMonthCoverStage(month: 6, dark: false, posterPhase: 0.56, interactive: false, forceFlat: false),
            tr: LivingMonthCoverStage(month: 6, dark: true, posterPhase: 0.56, interactive: false, forceFlat: false),
            bl: LivingMonthCoverStage(month: 6, dark: false, posterPhase: 0.56, interactive: false, forceFlat: true),
            br: LivingMonthCoverStage(month: 6, dark: true, posterPhase: 0.56, interactive: false, forceFlat: true)
        )
        shot("68_showcase_m06_4modes", height: 520, m06Plate.environment(m).tint(Palette.accent).fontDesign(.rounded))

        if let playN01 = m.content.play("N01") {
            shot("68_play_n01_bespoke_zh", height: 1120, tabs(m, PlayView(play: playN01, month: 0)))
        }
        shot("68_journal_readonly_swimlane_zh", height: 1200, tabs(m, JournalView(path: .constant(NavigationPath()))))
        shot("68_story_act1_lamp_zh", height: 920, settle: 2.0, tabs(m, StoryView()))
    }

    private func showcase2x2<TL: View, TR: View, BL: View, BR: View>(
        tl: TL, tr: TR, bl: BL, br: BR
    ) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) { tl; tr }
            HStack(spacing: 10) { bl; br }
        }
        .padding(14)
        .background(Palette.background)
    }
}
