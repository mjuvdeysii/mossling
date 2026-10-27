import SwiftUI
import LocalAuthentication

enum Route: Hashable {
    case story, data, play(String, Int), month(Int), observe(Int), areas(Int), care(Int), notes(Int), rhythm(Int), plan, topic(String), search, about, sources, licenses, doc(String), book
}

@main
struct MosslingApp: App {
    @State private var app = AppModel()
    @State private var journal = JournalStore()
    @State private var mascot = MascotDirector()
    init() { Guide.configure(); DataView.tidyDocuments() }
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.girlArt, app.drawsGirl)
                .environment(app)
                .environment(journal)
                .environment(mascot)
                .tint(Palette.accent)
                .fontDesign(.rounded)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var phase
    /// Whether it is night now (7 pm – 6 am), checked every minute while the app is open.
    @State private var night = Daylight.isNight()
    @State private var tab = 0
    @State private var todayPath = NavigationPath()
    @State private var growPath = NavigationPath()
    @State private var youPath = NavigationPath()
    @State private var journalPath = NavigationPath()
    @State private var searchPath = NavigationPath()
    @Environment(JournalStore.self) private var journal
    @Environment(MascotDirector.self) private var mascot
    @Environment(\.colorScheme) private var scheme
    @State private var locked = true
    @Namespace private var zoomToday
    @Namespace private var zoomJourney
    @Namespace private var zoomJournal
    @Namespace private var zoomYou

    var body: some View {
        ZStack {
            if !app.onboarded {
                OnboardingView()
            } else {
                // the system tab bar (Liquid Glass): it shrinks while reading; search is its own tab; a running feed or
                // sleep rides above it on every tab
                tabs
            }
            if app.lock && locked { LockView { unlock() } }
        }
        .onChange(of: phase) { _, p in
            if p == .active { app.today = .today; journal.reload(); Task { await LiveTimers.sync() }; mascot.timing = !journal.timers.isEmpty; mascot.send(.appActive) }
            if p == .background { locked = true; mascot.send(.appBackground) }
        }
        .task { if app.lock { unlock() }; app.publish() }
        // the IP event adapter: the journal reports confirmed events, the companions decide how to show them; nothing
        // flows back into the journal
        .task {
            mascot.companion = app.companion
            mascot.timing = !journal.timers.isEmpty
            if scheme == .dark { mascot.send(.nightmodeEnabled) }
            journal.onEvent = { [mascot, journal] e in mascot.timing = !journal.timers.isEmpty; mascot.send(e) }
        }
        .onChange(of: scheme) { _, s in mascot.send(s == .dark ? .nightmodeEnabled : .nightmodeDisabled) }
        .onChange(of: app.companion) { _, k in mascot.companion = k; mascot.send(.companionChanged) }
        .onChange(of: app.shelf) { _, _ in mascot.send(.activityRecommendationChanged) }
        // while open, pick up what the Live Activity or the widget changed (a side change from the Lock Screen)
        .task(id: phase) {
            guard phase == .active else { return }
            var n = 0
            while !Task.isCancelled {
                journal.refreshIfChanged()
                n += 1; if n % 30 == 1 { night = Daylight.isNight() }
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .onChange(of: app.publishKey) { _, _ in app.publish() }
        // The appearance of the window. Under the lamp (night, 夜灯 on, on the records or the timer) the whole window
        // turns dark, not just the views: the navigation bar's title, the tab bar, date pickers and every sheet are
        // drawn by the system from the window's appearance, and stayed black on the lamp's blue when only the views
        // were dark (seen on a phone in light mode). Everywhere else, the chosen theme.
        // one dark appearance, the lamp, for the whole app: whenever it is dark (the 夜灯 theme, the system's dark mode,
        // or night with 晚上自动开夜灯) every page is lit like the records — and the window itself is dark, so the
        // system's own bars, pickers and sheets follow
        .toasts()
        // links from the widget: mossling://care/nurse opens a feed's page, mossling://log/diaper a nappy's
        .onOpenURL { url in open(url) }
        .modifier(LampScope(on: scheme == .dark))
        .preferredColorScheme(app.nightLight && night ? .dark : app.theme.scheme)
    }

    /// Above the tab bar, a feed or sleep being timed, on every tab; it appears only while one runs.
    @ViewBuilder private var tabs: some View {
        if #available(iOS 26.2, *) {
            tabView.tabViewBottomAccessory(isEnabled: !journal.timers.isEmpty) {
                if let t = journal.timers.first { TimerAccessory(timer: t) }
            }
        } else {
            tabView
        }
    }

    /// The tab's mark: the vinyl icon, or in the hidden 2D world (build 196) the system symbol it had then.
    private func tabLabel(_ t: String, _ image: String, _ symbol: String) -> Label<Text, Image> {
        ArtStyle.current == .flat ? Label(t, systemImage: symbol) : Label(t, image: image)
    }

    private var tabView: some View {
        TabView(selection: $tab) {
            Tab(value: 0) {
                NavigationStack(path: $todayPath) { TodayView(path: $todayPath).routes(path: $todayPath) }.environment(\.zoomNS, zoomToday)
                    .environment(\.night, night || scheme == .dark)
            } label: { tabLabel("本月", "TabMonth", "leaf.fill") }
            if app.journal {
                Tab(value: 2) {
                    NavigationStack(path: $journalPath) { JournalView(path: $journalPath).routes(path: $journalPath) }.environment(\.zoomNS, zoomJournal)
                } label: { tabLabel("记录", "TabJournal", "list.bullet.clipboard.fill") }
            }
            Tab(value: 3) {
                NavigationStack(path: $youPath) { YouView(path: $youPath).routes(path: $youPath) }.environment(\.zoomNS, zoomYou)
            } label: { tabLabel("我的", "TabMe", "person.crop.circle.fill") }
        }
        // a change of drawing style redraws every picture and icon at once
        .id(app.artStyle)
        // the door between the two worlds (关于摸索台灯): the shards, the sheet of paper, the bloom of light
        .overlay { StyleShiftOverlay() }
        // a feed or sleep, once started (or opened from above the tab bar), has its own screen
        .fullScreenCover(item: Binding(get: { journal.focus.map { Wrap(id: $0) } }, set: { journal.focus = $0?.id })) { w in
            TimerScreen(type: w.id).lampPresented()
        }
    }

    private func open(_ url: URL) {
        guard url.scheme == "mossling", let type = url.pathComponents.dropFirst().first else { return }
        guard app.journal else { tab = 3; return }
        tab = 2
        switch url.host() {
        case "care" where LogType.timed.contains(type): journal.focus = type
        case "log": journal.focus = nil; journal.ask = type
        default: break
        }
    }

    private func unlock() {
        let ctx = LAContext()
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "确认是你本人") { ok, _ in
            DispatchQueue.main.async { if ok { locked = false } }
        }
    }
}

private struct LockView: View {
    @Environment(AppModel.self) private var app
    let unlock: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Duo(primary: app.companion, size: 110, mood: .sleep, poke: false)
            Text("摸索台灯已锁定").font(.title2.weight(.bold))
            Button("解锁", systemImage: "faceid", action: unlock).buttonStyle(.glassProminent).tint(Palette.accentFill).controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pageBackground()
    }
}

extension View {
    /// Every page that can be opened from a tab.
    func routes(path: Binding<NavigationPath>) -> some View {
        navigationDestination(for: Route.self) { r in RouteView(route: r, path: path) }
            .navigationDestination(for: JournalRoute.self) { r in
                switch r { case .stats: StatsView(); case .growth: GrowthView() }
            }
    }
}

private struct RouteView: View {
    @Environment(AppModel.self) private var app
    let route: Route
    @Binding var path: NavigationPath
    var body: some View {
        switch route {
        case let .play(code, m): if let p = app.content.play(code) { PlayView(play: p, month: m).zoomDestination(route) }
        case let .month(m): MonthView(month: m).zoomDestination(route)
        case let .areas(m): AreasView(month: m)
        case let .care(m): CareView(month: m)
        case let .notes(m): NotesView(month: m)
        case let .rhythm(m): RhythmView(month: m)
        case let .observe(m): ObserveView(month: m)
        case .plan: PlanView(path: $path)
        case let .topic(id): if let t = app.content.topics.first(where: { $0.id == id }) { TopicView(topic: t) }
        case .search: SearchView(path: $path)
        case .about: AboutView()
        case .story: StoryView()
        case .data: DataView()
        case .sources: SourcesView()
        case .licenses: LicensesView()
        case let .doc(n): DocView(name: n)
        case .book: GrowthBookView()
        }
    }
}

/// First run, told by the two of them (docs/IP.md): the evening table, Otto's lamp coming on, Moss exploring in its
/// light (LampScene, about four seconds, once), then the name and what it means in plain words — 孩子摸索，大人点灯.
/// Then the IP v1.3 shots in place: tap either companion to make it the main one (the page says which, and that it can
/// be changed), and the main one looks down at the way in, 填写出生日期.
/// Nothing waits for the animation: the buttons work from the first frame, 稍后再填 skips everything, a returning user
/// never sees this page, and under Reduce Motion the scene is still.
struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var askBirth = false
    @State private var doc: String?
    @State private var chose = false
    @State private var lookDown = false
    var body: some View {
        let k = app.companion
        VStack(spacing: 0) {
            LampScene(play: true, chosen: chose ? k : nil, lookDown: lookDown) { kind in
                withAnimation(reduce ? nil : .spring(response: 0.4, dampingFraction: 0.8)) { app.companion = kind; chose = true }
                lookDown = true
            }
            .frame(maxHeight: .infinity)
            .ignoresSafeArea(edges: .top)
            .sensoryFeedback(.selection, trigger: app.companion)

            VStack(spacing: 6) {
                Text("摸索台灯").font(.largeTitle.weight(.bold))
                Text("孩子摸索，大人点灯").font(.title3.weight(.semibold)).foregroundStyle(Palette.accent)
                Text("陪 0–3 岁的孩子一起玩，看他一个月一个月长大，把每一天记下来。")
                    .font(.subheadline).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                // the choice belongs to the page, not to the characters
                Text(chose ? "主伙伴：\(k.rawValue) · 之后可在「我的」更换" : "点一位作为主伙伴，两位功能相同")
                    .font(.footnote).foregroundStyle(Palette.secondaryText)
                    .padding(.top, 4)
                    .contentTransition(.opacity)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 14).padding(.horizontal, 24)

            VStack(spacing: 10) {
                Button { askBirth = true } label: { Text("填写出生日期").frame(maxWidth: .infinity).padding(.vertical, 6) }
                    .buttonStyle(.glassProminent).tint(Palette.accentFill).controlSize(.large)
                Button { app.onboarded = true } label: { Text("稍后再填").frame(maxWidth: .infinity).padding(.vertical, 6) }
                    .buttonStyle(.glass).controlSize(.large)
                Text("继续使用即表示已阅读并同意以下文件。本应用陪伴家庭养育，不能替代医生的诊断和建议。")
                    .font(.caption).foregroundStyle(Palette.secondaryText).multilineTextAlignment(.center).padding(.top, 4)
                HStack(spacing: 16) {
                    ForEach([("使用条款", "TERMS"), ("隐私政策", "PRIVACY"), ("免责声明", "DISCLAIMER")], id: \.1) { t, f in
                        Button(t) { doc = f }.font(.caption.weight(.semibold))
                    }
                }
            }
            .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 12)
        }
        .pageBackground()
        .task {
            // shot C after the opening: the main one looks at the way in
            if !reduce { try? await Task.sleep(for: .milliseconds(5200)) }
            lookDown = true
        }
        .sheet(isPresented: $askBirth) { BirthSheet() }
        .sheet(item: Binding(get: { doc.map { DocName(id: $0) } }, set: { doc = $0?.id })) { d in
            NavigationStack { DocView(name: d.id).toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成", systemImage: "checkmark") { doc = nil } } } }
        }
    }
}

private struct DocName: Identifiable { let id: String }
