import SwiftUI
import LocalAuthentication
import TipKit

enum Route: Hashable {
    case story, data, play(String, Int), month(Int), observe(Int), areas(Int), care(Int), notes(Int), rhythm(Int), plan, topic(String), search, about, sources, licenses, doc(String), book, toybox(ToyboxMode), capsules, foodAtlas
}

@main
struct MosslingApp: App {
    @State private var app = AppModel()
    @State private var journal = JournalStore()
    @State private var mascot = MascotDirector()
    init() { Guide.configure(); DataView.tidyDocuments(); ArtCache.shared.prewarmCommonStickers() }
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.girlArt, app.drawsGirl)
                .environment(app)
                .environment(journal)
                .environment(mascot)
                .tint(Palette.accent)
                .tipViewStyle(PaperTipStyle())
                .fontDesign(.rounded)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var phase
    /// Whether it is night now (7 pm – 6 am), checked every minute while the app is open.
    @State private var night = Daylight.isNight()
    /// The tab open last time: the app comes back where the parent left it (a night of feeds opens on 记录)
    @SceneStorage("tab") private var tab = 0
    @State private var todayPath = NavigationPath()
    @State private var youPath = NavigationPath()
    @State private var journalPath = NavigationPath()
    @Environment(JournalStore.self) private var journal
    @Environment(MascotDirector.self) private var mascot
    @Environment(\.colorScheme) private var scheme
    @State private var locked = true
    @State private var unlocking = false
    @State private var pendingURL: URL?
    @State private var showingBedsideLamp = false
    @Namespace private var zoomToday
    @Namespace private var zoomJourney
    @Namespace private var zoomJournal
    @Namespace private var zoomYou

    private var isLocked: Bool { app.lock && locked }

    /// Turns the week when it has gone by, counting each play's times from the records.
    private func roll(fresh: Bool = false) {
        app.rollWeek(played: { c in app.content.play(c).map { app.record($0, journal).count } ?? 0 }, fresh: fresh)
    }
    /// What the widget shows changes with the settings and with each play recorded (today's play may follow).
    private var widgetKey: String { app.publishKey + "|" + String(journal.playLogCount) }

    /// The consent card: on the first run (and after 清除全部数据, or when the rules change), and whenever something that
    /// keeps the child's information is asked for before the guardian agreed.
    private var consentShown: Binding<Bool> {
        Binding(get: { !isLocked && (app.consent.isEmpty || app.askConsent || (app.consent != "declined" && !app.consented)) },
                set: { if !$0 { app.askConsent = false } })
    }

    @ViewBuilder private var rootContent: some View {
        if isLocked {
            // replace the whole tree while locked so no .sheet or .fullScreenCover can sit above LockView
            LockView { unlock() }
        } else if !app.onboarded {
            OnboardingView()
        } else {
            // the system tab bar (Liquid Glass): it shrinks while reading; a running feed or
            // sleep rides above it on every tab
            tabs
        }
    }

    private var observedContent: some View {
        rootContent
            // a tab that is no longer there (记录 turned off) falls back to 本月
            .onChange(of: app.journal, initial: true) { _, on in if !on && tab == 2 { tab = 0 } }
            // the lock was just turned on after the owner confirmed: no second prompt until the app leaves the screen
            .onChange(of: app.lock) { _, on in if on { locked = false } }
            .onChange(of: locked) { _, stillLocked in
                if !stillLocked, let u = pendingURL { pendingURL = nil; open(u) }
            }
            .onChange(of: phase) { _, p in
                if p == .active { app.today = .today; journal.reload(); app.syncWidgetPick(); roll(); Task { await LiveTimers.sync() }; mascot.timing = !journal.timers.isEmpty; mascot.send(.appActive) }
                if p == .background { locked = true; mascot.send(.appBackground) }
            }
            .task {
                if app.lock { unlock() }
                roll()
                app.publish(journal)
                FirstPhotoStore.prune(keeping: Set(journal.firsts.map(\.id)))
            }
            // the IP event adapter: the journal reports confirmed events, the companions decide how to show them; nothing
            // flows back into the journal
            .task {
                mascot.companion = app.companion
                mascot.timing = !journal.timers.isEmpty
                TactileEngine.shared.soundEnabled = app.tactileSounds
                TactileEngine.shared.quietNight = scheme == .dark || journal.timers.contains { $0.type == LogType.sleep }
                if scheme == .dark { mascot.send(.nightmodeEnabled) }
                journal.onEvent = { [mascot, journal] e in mascot.timing = !journal.timers.isEmpty; mascot.send(e) }
                journal.onExternalChange = { [app] in app.syncWidgetPick() }
            }
            .onChange(of: scheme) { _, s in
                mascot.send(s == .dark ? .nightmodeEnabled : .nightmodeDisabled)
                TactileEngine.shared.quietNight = s == .dark || journal.timers.contains { $0.type == LogType.sleep }
            }
            .onChange(of: journal.timers) { _, timers in
                TactileEngine.shared.quietNight = scheme == .dark || timers.contains { $0.type == LogType.sleep }
            }
            .onChange(of: app.companion) { _, k in mascot.companion = k; mascot.send(.companionChanged) }
            .onChange(of: app.shelf) { _, _ in mascot.send(.activityRecommendationChanged) }
    }

    var body: some View {
        observedContent
            // Cross-process changes arrive immediately via Darwin notification; keep a gentle 10s safety fallback only while a timer runs
            .task(id: phase == .active && !journal.timers.isEmpty) {
                guard phase == .active, !journal.timers.isEmpty else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(10))
                    journal.refreshIfChanged()
                }
            }
            // track day/night boundary once a minute while foregrounded
            .task(id: phase == .active) {
                guard phase == .active else { return }
                while !Task.isCancelled {
                    night = Daylight.isNight()
                    try? await Task.sleep(for: .seconds(60))
                }
            }
            // a play recorded changes today's play (the least played comes next), so its count is part of the key
            // a birth date just given: this week is written at once (not at the next time the app comes forward)
            .onChange(of: app.birth) { _, _ in roll(fresh: true) }
            .onChange(of: widgetKey) { _, _ in app.publish(journal) }
            // The appearance of the window. Under the lamp (night, 夜灯 on, on the records or the timer) the whole window
            // turns dark, not just the views: the navigation bar's title, the tab bar, date pickers and every sheet are
            // drawn by the system from the window's appearance, and stayed black on the lamp's blue when only the views
            // were dark (seen on a phone in light mode). Everywhere else, the chosen theme.
            // one dark appearance, the lamp, for the whole app: whenever it is dark (the 夜灯 theme, the system's dark mode,
            // or night with 晚上自动开夜灯) every page is lit like the records — and the window itself is dark, so the
            // system's own bars, pickers and sheets follow
            .toasts()
            .sheet(isPresented: consentShown) { ConsentSheet() }
            // links from the widget: mossling://care/nurse opens a feed's page, mossling://log/diaper a nappy's
            .onOpenURL { url in open(url) }
            .modifier(LampScope(on: scheme == .dark))
            // 日光 and 夜灯 are what they say at any hour; only 自动 follows the night (when 晚上自动开夜灯 is on) or the phone
            .preferredColorScheme(app.theme == .system && app.nightLight && night ? .dark : app.theme.scheme)
    }

    /// Above the tab bar, a feed or sleep being timed, on every tab; it appears only while one runs.
    @ViewBuilder private var tabs: some View {
        if #available(iOS 26.2, *) {
            tabView.tabViewBottomAccessory(isEnabled: !journal.timers.isEmpty) {
                if let t = journal.timers.first { TimerAccessory(timer: t, also: journal.timers.dropFirst().first) }
            }
        } else {
            tabView
        }
    }

    /// The tab's mark: the vinyl icon — in full colour when chosen, quietened otherwise, so the chosen tab leads —
    /// or in the hidden 2D world (build 196) the system symbol it had then.
    private func tabLabel(_ t: String, _ image: String, _ symbol: String, _ value: Int) -> Label<Text, Image> {
        let name = ArtStyle.current == .flat ? image + "2D" : image
        return Label(t, image: tab == value ? name + "On" : name)
    }

    private var tabView: some View {
        TabView(selection: $tab) {
            Tab(value: 0) {
                NavigationStack(path: $todayPath) { TodayView(path: $todayPath).routes(path: $todayPath) }.environment(\.zoomNS, zoomToday)
                    .environment(\.night, night || scheme == .dark)
            } label: { tabLabel(L10n.t("本月", "Today"), "TabMonth", "leaf.fill", 0) }
            if app.journal {
                Tab(value: 2) {
                    NavigationStack(path: $journalPath) { JournalView(path: $journalPath).routes(path: $journalPath) }.environment(\.zoomNS, zoomJournal)
                } label: { tabLabel(L10n.t("记录", "Log"), "TabJournal", "list.bullet.clipboard.fill", 2) }
            }
            Tab(value: 3) {
                NavigationStack(path: $youPath) { YouView(path: $youPath).routes(path: $youPath) }.environment(\.zoomNS, zoomYou)
            } label: { tabLabel(L10n.t("我的", "Me"), "TabMe", "person.crop.circle.fill", 3) }
        }
        // a light tick as the chosen tab changes, like turning to a tabbed page
        .sensoryFeedback(.selection, trigger: tab)
        // a change of drawing style or language redraws every view immediately
        .id("\(app.artStyle.rawValue)-\(app.language.rawValue)")
        // the door between the two worlds (关于摸索台灯): the shards, the sheet of paper, the bloom of light
        .overlay { StyleShiftOverlay() }
        // a feed or sleep, once started (or opened from above the tab bar), has its own screen
        .fullScreenCover(item: Binding(get: { isLocked ? nil : journal.focus.map { Wrap(id: $0) } },
                                       set: { if !isLocked { journal.focus = $0?.id } })) { w in
            TimerScreen(type: w.id).lampPresented(sheet: false)
        }
        .fullScreenCover(isPresented: Binding(get: { !isLocked && showingBedsideLamp }, set: { showingBedsideLamp = $0 })) {
            BedsideLampView()
        }
    }

    private func open(_ url: URL) {
        guard url.scheme == "mossling" else { return }
        if isLocked { pendingURL = url; return }
        guard app.onboarded else { return }
        // Always pull fresh writes from widgets / Control Center / Live Activities before routing
        journal.reload()
        app.syncWidgetPick()
        let arg = url.pathComponents.dropFirst().first
        let pushToday: (Route) -> Void = { route in
            let needsSwitch = tab != 0
            tab = 0
            todayPath = NavigationPath()
            Task { @MainActor in
                if needsSwitch { try? await Task.sleep(for: .milliseconds(120)) }
                else { await Task.yield() }
                todayPath = NavigationPath([route])
            }
        }
        switch url.host() {
        case "lamp":
            journal.focus = nil
            journal.ask = nil
            showingBedsideLamp = true
        case "today":
            tab = 0
            todayPath = NavigationPath()
        case "settings":
            tab = 3
            youPath = NavigationPath()
        case "play":
            let mo = app.babyMonth ?? 0
            if let raw = arg, let p = app.content.play(raw) ?? app.content.play(raw.uppercased()) {
                pushToday(.play(p.code, mo))
            } else {
                tab = 0
                todayPath = NavigationPath()
            }
        case "month":
            let mo = arg.flatMap(Int.init) ?? (app.babyMonth ?? 0)
            pushToday(.month(max(0, min(mo, 36))))
        case "book":
            pushToday(.book)
        case "toybox":
            let mode = arg.flatMap(ToyboxMode.init(rawValue:)) ?? .xylophone
            pushToday(.toybox(mode))
        case "capsules":
            pushToday(.capsules)
        case "foods":
            pushToday(.foodAtlas)
        case "journal":
            guard app.mayKeep() else { return }
            journal.focus = nil
            journal.ask = nil
            journal.jumpToToday &+= 1
            tab = app.journal ? 2 : 3
            if app.journal { journalPath = NavigationPath() }
        case "care":
            guard let type = arg, LogType.timed.contains(type), app.mayKeep() else { return }
            guard app.journal else { tab = 3; return }
            let needsSwitch = tab != 2
            tab = 2
            journal.ask = nil
            journal.focus = nil
            Task { @MainActor in
                if needsSwitch { try? await Task.sleep(for: .milliseconds(120)) }
                else { await Task.yield() }
                journal.focus = type
            }
        case "log":
            guard let type = arg, LogType.buttons.contains(type), type != LogType.growth, app.mayKeep() else { return }
            guard app.journal else { tab = 3; return }
            let needsSwitch = tab != 2
            tab = 2
            journal.focus = nil
            journal.ask = nil
            journal.jumpToToday &+= 1
            // Defer assignment until JournalView has mounted so .sheet(item:) always observes nil → non-nil
            Task { @MainActor in
                if needsSwitch { try? await Task.sleep(for: .milliseconds(140)) }
                else { await Task.yield() }
                journal.ask = type
            }
        default: break
        }
    }

    private func unlock() {
        guard !unlocking else { return }
        unlocking = true
        Task { @MainActor in
            defer { unlocking = false }
            let ctx = LAContext()
            if (try? await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: L10n.t("确认是你本人", "Confirm it's you"))) == true {
                locked = false
            }
        }
    }
}

private struct LockView: View {
    @Environment(AppModel.self) private var app
    let unlock: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Duo(primary: app.companion, size: 110, mood: .sleep, poke: false)
            Text(L10n.t("摸索台灯已锁定", "Moss & Otto is Locked")).font(.title2.weight(.bold))
            Button(L10n.t("解锁", "Unlock"), systemImage: Biometry.symbol, action: unlock).buttonStyle(.glassProminent).tint(Palette.accentFill).controlSize(.large)
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
                switch r { case .stats: StatsView(); case .growth: GrowthView(); case .firsts: FirstsView() }
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
        case .book: GrowthBookView().zoomDestination(route)
        case let .toybox(mode): ToyboxView(initialMode: mode)
        case .capsules: TimeCapsuleListView()
        case .foodAtlas: FoodAtlasView()
        }
    }
}

/// First run, told by the two of them (docs/IP.md): the evening table, Otto's lamp coming on, Moss exploring in its
/// light (LampScene, about four seconds, once), then the name and what it means in plain words — 孩子摸索，大人点灯.
/// Then the IP v1.3 shots in place: tap either of them and they answer (Moss is the child, Otto the grown-up), and Moss
/// looks down at the way in, 填写出生日期.
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
        VStack(spacing: 0) {
            // tap either of them: they answer (Moss is the child, Otto the grown-up — nothing to choose)
            LampScene(play: true, chosen: nil, lookDown: lookDown) { _ in
                withAnimation(reduce ? nil : .spring(response: 0.4, dampingFraction: 0.8)) { chose = true }
                lookDown = true
            }
            .frame(maxHeight: .infinity)
            .ignoresSafeArea(edges: .top)
            .sensoryFeedback(.selection, trigger: chose)

            VStack(spacing: 6) {
                Text(L10n.appName).font(.largeTitle.weight(.bold))
                Text(L10n.t("孩子摸索，大人点灯", "They explore. You hold the light.")).font(.title3.weight(.semibold)).foregroundStyle(Palette.accent)
                Text(L10n.t("陪 0–3 岁的孩子一起玩，看着一个月一个月长大，把每一天记下来。", "Play alongside your 0–3 year old, watch them grow month by month, and keep each day's quiet notes."))
                    .font(.subheadline).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                // who the two are, in one line (their parts as child and grown-up are for the pictures only)
                Text(L10n.t("Moss 和 Otto 会一直陪在旁边，在「我的」里选一个做伙伴", "Moss and Otto are always nearby — choose your companion in Me."))
                    .font(.footnote).foregroundStyle(Palette.secondaryText)
                    .padding(.top, 4)
            }
            .multilineTextAlignment(.center)
            .padding(.top, 14).padding(.horizontal, 24)

            VStack(spacing: 10) {
                Button { if app.mayKeep() { askBirth = true } } label: { Text(L10n.t("填写出生日期", "Add Birthday")).frame(maxWidth: .infinity).padding(.vertical, 6) }
                    .buttonStyle(.glassProminent).tint(Palette.accentFill).controlSize(.large)
                Button { app.onboarded = true } label: { Text(L10n.t("稍后再填", "Later")).frame(maxWidth: .infinity).padding(.vertical, 6) }
                    .buttonStyle(.glass).controlSize(.large)
                // the small print on its own piece of paper, so the meadow at the foot of the page never runs behind it
                VStack(spacing: 6) {
                    Text(L10n.t("本应用陪伴家庭养育，不能替代医生的诊断和建议。", "A quiet companion for home parenting — not a substitute for medical advice."))
                        .font(.caption).foregroundStyle(Palette.secondaryText).multilineTextAlignment(.center)
                    HStack(spacing: 16) {
                        ForEach([(L10n.t("使用条款", "Terms"), "TERMS"), (L10n.t("隐私政策", "Privacy"), "PRIVACY"), (L10n.t("免责声明", "Disclaimer"), "DISCLAIMER")], id: \.1) { t, f in
                            Button(t) { doc = f }.font(.caption.weight(.semibold))
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Palette.background.opacity(0.92), in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                .padding(.top, 4)
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
            NavigationStack { DocView(name: d.id).toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.t("完成", "Done"), systemImage: "checkmark") { doc = nil } } } }
        }
    }
}

private struct DocName: Identifiable { let id: String }
