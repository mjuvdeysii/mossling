import SwiftUI
import LocalAuthentication

enum Route: Hashable {
    case play(String, Int), month(Int), observe(Int), areas(Int), care(Int), notes(Int), rhythm(Int), plan, topic(String), search, about, sources, licenses, doc(String), book
}

@main
struct MosslingApp: App {
    @State private var app = AppModel()
    @State private var journal = JournalStore()
    @State private var mascot = MascotDirector()
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

    private var tabView: some View {
        TabView(selection: $tab) {
            Tab("本月", systemImage: "leaf.fill", value: 0) {
                NavigationStack(path: $todayPath) { TodayView(path: $todayPath).routes(path: $todayPath) }.environment(\.zoomNS, zoomToday)
                    .environment(\.night, night || scheme == .dark)
            }
            if app.journal {
                Tab("记录", systemImage: "list.bullet.clipboard.fill", value: 2) {
                    NavigationStack(path: $journalPath) { JournalView(path: $journalPath).routes(path: $journalPath) }.environment(\.zoomNS, zoomJournal)
                }
            }
            Tab("我的", systemImage: "person.crop.circle.fill", value: 3) {
                NavigationStack(path: $youPath) { YouView(path: $youPath).routes(path: $youPath) }.environment(\.zoomNS, zoomYou)
            }
        }
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
        case .sources: SourcesView()
        case .licenses: LicensesView()
        case let .doc(n): DocView(name: n)
        case .book: GrowthBookView()
        }
    }
}

/// First run: the welcome page as it was (the two of them, the name, 填写出生日期 / 稍后再填), with three silent shots
/// played in place (IP v1.3 §11.2) — no words from the characters, every line on the page is plain UI:
///  A. the two rise and see each other (Moss two quick glances, Otto one slow look);
///  B. they turn to the parent; tapping either makes it the main companion — the page says which, and that it can be
///     changed in 我的 (the choice changes the performance only, never what the app can do);
///  C. the chosen one looks down at the real way in, 填写出生日期.
/// Nothing waits for the shots: the buttons work from the first frame, 稍后再填 skips everything, and a returning
/// user never sees this page. Under Reduce Motion the page is still, already at shot C.
struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var askBirth = false
    @State private var doc: String?
    @State private var rise = false
    /// 0 rising, 1 seeing each other, 2 facing the parent, 3 the chosen one looking at the way in.
    @State private var shot = 0
    @State private var chose = false
    /// Moss's glance comes in two quick steps.
    @State private var mossHalf = false
    var body: some View {
        let k = app.companion
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Sky()
                HStack(alignment: .bottom, spacing: -14) {
                    pick(.moss, size: 150, drop: 40)
                    pick(.otto, size: 132, drop: 60)
                }
                .opacity(rise ? 1 : 0)
                .padding(.bottom, 26)
            }
            .frame(maxHeight: .infinity)
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 8) {
                Text("摸索台灯").font(.largeTitle.weight(.bold))
                Text("跟着孩子，一个月一站").font(.title3).foregroundStyle(Palette.secondaryText)
                // shot B's words belong to the page, not to the characters
                Text(chose ? "主伙伴：\(k.rawValue) · 之后可在「我的」更换" : "点一位作为主伙伴，两位功能相同")
                    .font(.footnote).foregroundStyle(Palette.secondaryText)
                    .padding(.top, 2)
                    .contentTransition(.opacity)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 8).padding(.horizontal, 24)

            VStack(spacing: 10) {
                Button { askBirth = true } label: { Text("填写出生日期").frame(maxWidth: .infinity).padding(.vertical, 6) }
                    .buttonStyle(.glassProminent).tint(Palette.accentFill).controlSize(.large)
                Button { app.onboarded = true } label: { Text("稍后再填").frame(maxWidth: .infinity).padding(.vertical, 6) }
                    .buttonStyle(.glass).controlSize(.large)
                Text("继续使用即表示已阅读并同意以下文件。本应用提供家庭养育参考，不能替代医生的诊断和建议。")
                    .font(.caption).foregroundStyle(Palette.secondaryText).multilineTextAlignment(.center).padding(.top, 6)
                HStack(spacing: 16) {
                    ForEach([("使用条款", "TERMS"), ("隐私政策", "PRIVACY"), ("免责声明", "DISCLAIMER")], id: \.1) { t, f in
                        Button(t) { doc = f }.font(.caption.weight(.semibold))
                    }
                }
            }
            .padding(.horizontal, 24).padding(.top, 22).padding(.bottom, 12)
        }
        .pageBackground()
        .task { await play() }
        .sheet(isPresented: $askBirth) { BirthSheet() }
        .sheet(item: Binding(get: { doc.map { DocName(id: $0) } }, set: { doc = $0?.id })) { d in
            NavigationStack { DocView(name: d.id).toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成", systemImage: "checkmark") { doc = nil } } } }
        }
    }

    /// One of the two, as a button: tap to make it the main companion. The chosen one stands a little larger.
    private func pick(_ kind: Kind, size: CGFloat, drop: CGFloat) -> some View {
        let on = app.companion == kind
        return Button {
            withAnimation(reduce ? nil : .spring(response: 0.4, dampingFraction: 0.75)) { app.companion = kind; chose = true }
            if shot < 3 { shot = 3 }
        } label: {
            Creature(kind: kind, mood: shot == 2 && on ? .happy : .open, look: look(kind),
                     lean: shot == 1 ? (kind == .moss ? MascotStyle.moss.tiltDegrees : -MascotStyle.otto.tiltDegrees) : 0,
                     lookSeconds: Double(MascotStyle.of(kind).glanceMs) / 1000)
                .frame(width: size, height: size)
                .scaleEffect(chose && !on ? 0.88 : 1, anchor: .bottom)
        }
        .buttonStyle(.plain)
        .offset(y: rise ? 0 : drop)
        .accessibilityLabel("选择 \(kind.rawValue) 作为主伙伴，\(kind.trait)")
        .accessibilityAddTraits(on && chose ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: app.companion)
    }

    /// Where each one looks in each shot.
    private func look(_ kind: Kind) -> CGPoint {
        switch shot {
        case 1: return kind == .moss ? (mossHalf ? CGPoint(x: 0.45, y: -0.05) : CGPoint(x: 0.95, y: -0.15)) : CGPoint(x: -0.95, y: 0.05)   // at each other
        case 2: return CGPoint(x: kind == .moss ? 0.2 : -0.2, y: 0.15)                           // at the parent
        case 3: return kind == app.companion ? CGPoint(x: kind == .moss ? 0.35 : -0.35, y: 1)      // down at 填写出生日期
                                             : CGPoint(x: kind == .moss ? 0.9 : -0.9, y: 0.4)     // at the chosen one
        default: return CGPoint(x: kind == .moss ? 0.6 : -0.6, y: 0)
        }
    }

    private func play() async {
        if reduce { rise = true; shot = 3; return }
        withAnimation(.spring(duration: 0.9)) { rise = true }
        try? await Task.sleep(for: .milliseconds(900))
        if shot < 1 { mossHalf = true; shot = 1 }         // A: they see each other (Moss in two quick steps)
        try? await Task.sleep(for: .milliseconds(MascotStyle.moss.glanceMs + 60))
        mossHalf = false
        try? await Task.sleep(for: .milliseconds(1300))
        if shot < 2 { shot = 2 }                          // B: they turn to the parent
        try? await Task.sleep(for: .milliseconds(1400))
        if shot < 3 { shot = 3 }                          // C: the chosen one looks at the way in
    }
}

private struct DocName: Identifiable { let id: String }
