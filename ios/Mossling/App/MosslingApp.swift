import SwiftUI
import LocalAuthentication
import TipKit

@main
struct MosslingApp: App {
    @State private var app = AppModel()
    @State private var journal = JournalStore()
    @State private var mascot = MascotDirector()
    @State private var router = AppRouter()
    init() { Guide.configure(); DataView.tidyDocuments(); ArtCache.shared.prewarmCommonStickers() }
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.girlArt, app.drawsGirl)
                .environment(app)
                .environment(journal)
                .environment(mascot)
                .environment(router)
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
    /// The tab open last time: the app comes back where the parent left it (a night of feeds opens on 台灯)
    @SceneStorage("tab") private var savedTab = 0
    @Environment(AppRouter.self) private var router
    @Environment(JournalStore.self) private var journal
    @Environment(MascotDirector.self) private var mascot
    @Environment(\.colorScheme) private var scheme
    @State private var locked = UserDefaults.standard.bool(forKey: "lock")
    @State private var lockRecoveryMessage: String? = nil
    @State private var unlocking = false
    @State private var unlockAttemptedForCurrentLock = false
    @State private var pendingURL: URL?
    @State private var handledInitialURL = false
    @Namespace private var zoomToday
    @Namespace private var zoomJourney
    @Namespace private var zoomJournal
    @Namespace private var zoomYou

    private var isLocked: Bool { app.lock && locked }

    /// Synchronizes TactileEngine's silent-night shield across dark theme, sleep timers, 3AM duty phase, and any Bedside Lamp cover.
    private func syncQuietNight() {
        let lateNight = app.is3AMSanctuaryActive || CircadianDutyPhase.isLateNight3AM()
        TactileEngine.shared.quietNight = scheme == .dark || lateNight || router.showingBedsideLamp || app.isBedsideLampOpen || journal.timers.contains { $0.type == LogType.sleep }
    }

    /// Turns the week when it has gone by, counting each play's times from the records.
    private func roll(fresh: Bool = false) {
        guard app.consented else { return }
        app.rollWeek(played: { c in app.content.play(c).map { app.record($0, journal).count } ?? 0 }, fresh: fresh)
    }
    /// What the widget shows changes with the settings and with each play recorded (today's play may follow).
    private var widgetKey: String { app.publishKey + "|" + String(journal.playLogCount) }

    /// The consent card: on the first run (and after 清除全部数据, or when the rules change), and whenever something that
    /// keeps the child's information is asked for before the guardian agreed.
    private var consentShown: Binding<Bool> {
        Binding(get: { !isLocked && app.consentHostStack.isEmpty && (app.consent.isEmpty || app.askConsent || (app.consent != "declined" && !app.consented)) },
                set: { if !$0 { app.askConsent = false } })
    }

    @ViewBuilder private var rootContent: some View {
        ZStack {
            Group {
                if !app.onboarded {
                    OnboardingView()
                } else {
                    // the system tab bar (Liquid Glass): it shrinks while reading; a running feed or
                    // sleep rides above it on every tab
                    tabs
                }
            }
            .allowsHitTesting(!isLocked)
            .accessibilityHidden(isLocked)

            if isLocked {
                LockView(
                    companion: app.companion,
                    lockRecoveryMessage: lockRecoveryMessage,
                    unlock: { unlock() },
                    onDisablePasscodeLock: lockRecoveryMessage == nil ? nil : { disablePasscodeLock() }
                )
                .transition(.opacity)
                .zIndex(100)
            }
        }
    }

    private var observedContent: some View {
        rootContent
            // the lock was just turned on after the owner confirmed: no second prompt until the app leaves the screen
            .onChange(of: app.lock) { _, _ in
                locked = false
                unlockAttemptedForCurrentLock = false
                lockRecoveryMessage = nil
                app.appLocked = isLocked
                app.appSheetLocked = isLocked
            }
            .onChange(of: locked) { _, stillLocked in
                if !stillLocked, let u = pendingURL { pendingURL = nil; open(u) }
            }
            .onChange(of: isLocked, initial: true) { _, nowLocked in
                app.appLocked = nowLocked
                app.appSheetLocked = nowLocked
                app.publish(journal)
                Task { await LiveTimers.sync() }
            }
            .onChange(of: phase) { _, p in
                if p == .active {
                    _ = Biometry.refresh()
                    app.today = .today
                    journal.reload()
                    app.syncWidgetPick()
                    roll()
                    app.appLocked = isLocked
                    app.appSheetLocked = isLocked
                    app.publish(journal)
                    Task { await LiveTimers.sync() }
                    mascot.timing = !journal.timers.isEmpty
                    mascot.send(.appActive)
                    if isLocked && !unlockAttemptedForCurrentLock { unlock() }
                } else if p == .inactive {
                    if app.lock {
                        app.appLocked = true
                        app.publish(journal)
                        final class BgTaskBox: @unchecked Sendable { var id: UIBackgroundTaskIdentifier = .invalid }
                        let box = BgTaskBox()
                        box.id = UIApplication.shared.beginBackgroundTask(withName: "SyncInactivePrivacy") {
                            let stale = box.id
                            box.id = .invalid
                            if stale != .invalid { UIApplication.shared.endBackgroundTask(stale) }
                        }
                        Task { @MainActor in
                            await LiveTimers.sync()
                            let done = box.id
                            box.id = .invalid
                            if done != .invalid { UIApplication.shared.endBackgroundTask(done) }
                        }
                    }
                } else if p == .background {
                    if app.lock {
                        locked = true
                        app.appLocked = true
                    }
                    app.publish(journal)
                    unlockAttemptedForCurrentLock = false
                    mascot.send(.appBackground)
                    final class BgTaskBox: @unchecked Sendable { var id: UIBackgroundTaskIdentifier = .invalid }
                    let box = BgTaskBox()
                    box.id = UIApplication.shared.beginBackgroundTask(withName: "SyncBackgroundLock") {
                        let stale = box.id
                        box.id = .invalid
                        if stale != .invalid { UIApplication.shared.endBackgroundTask(stale) }
                    }
                    Task { @MainActor in
                        await LiveTimers.sync()
                        let done = box.id
                        box.id = .invalid
                        if done != .invalid { UIApplication.shared.endBackgroundTask(done) }
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                if app.lock {
                    locked = true
                    app.appLocked = true
                    app.publish(journal)
                }
            }
            .background {
                let darkShield = app.theme == .light ? false : (app.is3AMSanctuaryActive || (app.theme == .dark) || (app.theme == .system && app.nightLight && night) || scheme == .dark)
                LockWindowShield(
                    isLocked: isLocked,
                    isPrivacyShieldActive: app.lock && phase == .inactive && !isLocked,
                    isDark: darkShield,
                    locale: Locale(identifier: L10n.isEnglish ? "en" : "zh-Hans"),
                    companion: app.companion,
                    lockRecoveryMessage: lockRecoveryMessage,
                    unlock: unlock,
                    onDisablePasscodeLock: lockRecoveryMessage == nil ? nil : { disablePasscodeLock() }
                )
            }
            .task {
                if !handledInitialURL && AppTab(rawValue: savedTab) != nil {
                    router.selectedTab = savedTab
                }
                if phase == .active && app.lock && !unlockAttemptedForCurrentLock { unlock() }
                roll()
                app.publish(journal)
                if let verified = JournalFile.loadExistingForPrune() {
                    journal.reload()
                    let validFirsts = Set(verified.firsts.map(\.id))
                    FirstPhotoStore.prune(keeping: validFirsts)
                    FirstVoiceStore.prune(keeping: validFirsts)
                }
            }
            // the IP event adapter: the journal reports confirmed events, the companions decide how to show them; nothing
            // flows back into the journal
            .task {
                mascot.companion = app.companion
                mascot.timing = !journal.timers.isEmpty
                TactileEngine.shared.soundEnabled = app.tactileSounds
                syncQuietNight()
                if scheme == .dark { mascot.send(.nightmodeEnabled) }
                journal.onEvent = { [mascot, weak journal] e in mascot.timing = !(journal?.timers.isEmpty ?? true); mascot.send(e) }
                journal.onExternalChange = { [app] in app.syncWidgetPick() }
            }
            .onChange(of: router.selectedTab) { _, next in savedTab = next }
            .onChange(of: scheme) { _, s in
                mascot.send(s == .dark ? .nightmodeEnabled : .nightmodeDisabled)
                syncQuietNight()
            }
            .onChange(of: router.showingBedsideLamp) { _, _ in syncQuietNight() }
            .onChange(of: app.isBedsideLampOpen) { _, _ in syncQuietNight() }
            .onChange(of: journal.timers) { _, _ in syncQuietNight() }
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
            // track day/night boundary and midnight date rollover once a minute while foregrounded
            .task(id: phase == .active) {
                guard phase == .active else { return }
                while !Task.isCancelled {
                    let nowDay = Day.today
                    if nowDay != app.today {
                        app.today = nowDay
                        roll()
                    }
                    let lateNightNow = CircadianDutyPhase.isLateNight3AM()
                    if lateNightNow != app.isLateNightWindow {
                        app.isLateNightWindow = lateNightNow
                        app.manual3AMOverride = nil
                    }
                    night = Daylight.isNight()
                    syncQuietNight()
                    try? await Task.sleep(for: .seconds(60))
                }
            }
            // a play recorded changes today's play (the least played comes next), so its count is part of the key
            // a birth date or gestational weeks just given: this week is written at once (not at the next time the app comes forward)
            .onChange(of: app.birth) { _, _ in roll(fresh: true) }
            .onChange(of: app.gestationalWeeks) { _, _ in roll(fresh: true) }
            .onChange(of: widgetKey) { _, _ in app.publish(journal) }
            // The appearance of the window. Under the lamp (night, 夜灯 on, on the records or the timer) the whole window
            // turns dark, not just the views: the navigation bar's title, the tab bar, date pickers and every sheet are
            // drawn by the system from the window's appearance, and stayed black on the lamp's blue when only the views
            // were dark (seen on a phone in light mode). Everywhere else, the chosen theme.
            // one dark appearance, the lamp, for the whole app: whenever it is dark (the 夜灯 theme, the system's dark mode,
            // or night with 晚上自动开夜灯) every page is lit like the records — and the window itself is dark, so the
            // system's own bars, pickers and sheets follow
            .toasts(suppressed: isLocked || app.isBedsideLampOpen || router.showingBedsideLamp)
            .sheet(isPresented: consentShown) { ConsentSheet().lampPresented() }
            // links from the widget: mossling://care/nurse opens a feed's page, mossling://log/diaper a nappy's
            .onOpenURL { url in open(url) }
            .modifier(LampScope(on: scheme == .dark))
            // 日光 and 夜灯 are what they say at any hour; only 自动 follows the night (when 晚上自动开夜灯 is on) or the phone; 3AM sanctuary keeps OLED dark when theme is automatic or dark
            .preferredColorScheme(app.theme == .light ? .light : ((app.is3AMSanctuaryActive || (app.theme == .system && app.nightLight && night)) ? .dark : app.theme.scheme))
    }

    /// Above the tab bar, a feed or sleep being timed, on every tab; it appears only while one runs.
    @ViewBuilder private var tabs: some View {
        let timerAccessoryActive = app.consented && app.journal && !journal.timers.isEmpty
        if #available(iOS 26.1, *) {
            tabView.tabViewBottomAccessory(isEnabled: timerAccessoryActive) {
                if let t = journal.timers.first { TimerAccessory(timer: t, also: journal.timers.dropFirst().first) }
            }
        } else {
            tabView.safeAreaInset(edge: .bottom, spacing: 0) {
                if timerAccessoryActive, let t = journal.timers.first {
                    TimerAccessory(timer: t, also: journal.timers.dropFirst().first)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(.regularMaterial)
                                .overlay(Capsule(style: .continuous).strokeBorder(Palette.outline.opacity(0.35), lineWidth: 0.75))
                                .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                }
            }
        }
    }

    /// Crisp unified SF Symbol mark for the 4-Screen Pure-Blood Narrative Tab Bar: 摸索 · 台灯 · 留念 · 工坊.
    private func tabLabel(_ title: String, symbol: String, selectedSymbol: String, value: Int) -> Label<Text, Image> {
        Label(title, systemImage: router.selectedTab == value ? selectedSymbol : symbol)
    }

    private var tabView: some View {
        @Bindable var r = router
        return TabView(selection: $r.selectedTab) {
            Tab(value: AppTab.explore.rawValue) {
                NavigationStack(path: $r.explorePath) {
                    TodayView(path: $r.explorePath).exploreRoutes(path: $r.explorePath)
                }
                .environment(\.zoomNS, zoomToday)
            } label: { tabLabel(L10n.t("摸索", "Explore"), symbol: "leaf", selectedSymbol: "leaf.fill", value: AppTab.explore.rawValue) }

            Tab(value: AppTab.lamp.rawValue) {
                NavigationStack(path: $r.lampPath) {
                    LampHubView(path: $r.lampPath).lampRoutes()
                }
                .environment(\.zoomNS, zoomJournal)
            } label: { tabLabel(L10n.t("台灯", "Lamp"), symbol: "lamp.desk", selectedSymbol: "lamp.desk.fill", value: AppTab.lamp.rawValue) }

            Tab(value: AppTab.keepsakes.rawValue) {
                NavigationStack(path: $r.keepsakesPath) {
                    JourneyHubView(isRootTab: true).keepsakesRoutes()
                }
                .environment(\.zoomNS, zoomJourney)
            } label: { tabLabel(L10n.t("留念", "Keepsakes"), symbol: "book.pages", selectedSymbol: "book.pages.fill", value: AppTab.keepsakes.rawValue) }

            Tab(value: AppTab.studio.rawValue) {
                NavigationStack(path: $r.studioPath) {
                    YouView(path: $r.studioPath).studioRoutes()
                }
                .environment(\.zoomNS, zoomYou)
            } label: { tabLabel(L10n.t("工坊", "Studio"), symbol: "square.grid.2x2", selectedSymbol: "square.grid.2x2.fill", value: AppTab.studio.rawValue) }
        }
        .environment(\.night, night || scheme == .dark)
        // a light tick as the chosen tab changes, like turning to a tabbed page
        .sensoryFeedback(.selection, trigger: router.selectedTab)
        // a change of drawing style or language redraws every view immediately
        .environment(\.locale, Locale(identifier: L10n.isEnglish ? "en" : "zh-Hans"))
        .id("\(app.artStyle.rawValue)-\(app.language.rawValue)")
        // the door between the two worlds (关于摸索台灯): the shards, the sheet of paper, the bloom of light
        .overlay { StyleShiftOverlay() }
        // a feed or sleep, once started (or opened from above the tab bar), has its own screen
        .fullScreenCover(item: Binding(get: { journal.focus.map { Wrap(id: $0) } },
                                       set: { journal.focus = $0?.id })) { w in
            TimerScreen(type: w.id).lampPresented(sheet: false)
        }
        .fullScreenCover(isPresented: $r.showingBedsideLamp) {
            BedsideLampView()
        }
        .fullScreenCover(isPresented: $r.showingStorybook) {
            StorybookView().lampPresented(sheet: false)
        }
    }

    private func open(_ url: URL) {
        guard url.scheme == "mossling" else { return }
        handledInitialURL = true
        if isLocked { pendingURL = url; return }
        guard app.onboarded else { return }
        // Always pull fresh writes from widgets / Control Center / Live Activities before routing
        journal.reload()
        app.syncWidgetPick()
        let arg = url.pathComponents.dropFirst().first
        if url.host() != "lamp" { router.showingBedsideLamp = false }
        if url.host() != "book" { router.showingStorybook = false }
        switch url.host() {
        case "lamp":
            journal.focus = nil
            journal.ask = nil
            router.openBedsideLamp()
        case "today":
            router.openExplore()
        case "settings":
            router.openStudio()
        case "play":
            let mo = app.babyMonth ?? 0
            if let raw = arg, let p = app.content.play(raw) ?? app.content.play(raw.uppercased()) {
                router.openExplore(.play(p.code, mo))
            } else {
                router.openExplore()
            }
        case "month":
            let mo = arg.flatMap(Int.init) ?? (app.babyMonth ?? 0)
            router.openKeepsakes(.month(max(0, min(mo, 36))))
        case "book":
            router.openStorybook()
        case "toybox":
            let mode = arg.flatMap(ToyboxMode.init(rawValue:)) ?? .xylophone
            router.openExplore(.toybox(mode))
        case "capsules":
            router.openKeepsakes(.capsules)
        case "foods":
            router.openExplore(.foodAtlas)
        case "journey":
            router.openKeepsakes()
        case "journal":
            guard app.mayKeep() else { return }
            journal.focus = nil
            journal.ask = nil
            journal.jumpToToday &+= 1
            router.openLamp(expandLedger: app.journal)
        case "care":
            guard let type = arg, LogType.timed.contains(type), app.mayKeep() else { return }
            guard app.journal else { router.openLamp(); return }
            let needsSwitch = router.selectedTab != AppTab.lamp.rawValue
            router.selectedTab = AppTab.lamp.rawValue
            journal.ask = nil
            journal.focus = nil
            Task { @MainActor in
                if needsSwitch { try? await Task.sleep(for: .milliseconds(120)) }
                else { await Task.yield() }
                journal.focus = type
            }
        case "log":
            guard let type = arg, LogType.buttons.contains(type), type != LogType.growth, app.mayKeep() else { return }
            guard app.journal else { router.openLamp(); return }
            let needsSwitch = router.selectedTab != AppTab.lamp.rawValue
            router.selectedTab = AppTab.lamp.rawValue
            journal.focus = nil
            journal.ask = nil
            journal.jumpToToday &+= 1
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
        unlockAttemptedForCurrentLock = true
        Task { @MainActor in
            defer { unlocking = false }
            let ctx = LAContext()
            var evalError: NSError?
            guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evalError) else {
                let code = (evalError as? LAError)?.code
                if code == .passcodeNotSet || code == .biometryNotEnrolled || code == .biometryNotAvailable || evalError != nil {
                    lockRecoveryMessage = L10n.t(
                        "系统当前未设置锁屏密码，无法进行面容或密码解锁。请前往系统设置开启密码，或先关闭应用锁以继续使用。",
                        "Device authentication is unavailable because the system passcode is turned off. Enable a device passcode in Settings or turn off App Lock to continue."
                    )
                }
                return
            }
            lockRecoveryMessage = nil
            if (try? await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: L10n.t("确认是你本人", "Confirm it's you"))) == true {
                locked = false
                unlockAttemptedForCurrentLock = false
                lockRecoveryMessage = nil
                app.appLocked = false
                app.publish(journal)
                await LiveTimers.sync()
            }
        }
    }

    private func disablePasscodeLock() {
        app.lock = false
        locked = false
        unlockAttemptedForCurrentLock = false
        lockRecoveryMessage = nil
        app.appLocked = false
        app.appSheetLocked = false
        app.publish(journal)
        Task { await LiveTimers.sync() }
    }
}

private struct LockView: View {
    var companion: Kind = .moss
    var lockRecoveryMessage: String? = nil
    let unlock: () -> Void
    var onDisablePasscodeLock: (() -> Void)? = nil
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    Duo(primary: companion, size: 110, mood: .sleep, poke: false)
                    Text(L10n.t("摸索台灯已锁定", "Moss & Otto is Locked"))
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                    if let lockRecoveryMessage {
                        Text(lockRecoveryMessage)
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondaryText)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 12)
                        if let onDisablePasscodeLock {
                            Button(L10n.t("关闭应用锁并继续", "Turn Off App Lock"), role: .destructive, action: onDisablePasscodeLock)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                        }
                    }
                    Button(L10n.t("解锁", "Unlock"), systemImage: Biometry.symbol, action: unlock)
                        .buttonStyle(.glassProminent)
                        .tint(Palette.accentFill)
                        .controlSize(.large)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .pageBackground()
    }
}

private final class ShieldAnchorView: UIView {
    var onMoveToWindow: (() -> Void)?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        onMoveToWindow?()
    }
}

/// Hosts an opaque window above all presented sheets and covers whenever app lock or inactive privacy shielding is active,
/// preserving the underlying SwiftUI navigation stacks and unsaved sheet drafts without leaks.
private struct LockWindowShield: UIViewRepresentable {
    let isLocked: Bool
    let isPrivacyShieldActive: Bool
    let isDark: Bool
    let locale: Locale
    let companion: Kind
    let lockRecoveryMessage: String?
    let unlock: () -> Void
    let onDisablePasscodeLock: (() -> Void)?

    final class Coordinator {
        var shieldWindow: UIWindow?
        var syncBlock: (() -> Void)?
        deinit {
            let win = shieldWindow
            shieldWindow = nil
            if let win {
                DispatchQueue.main.async {
                    win.resignKey()
                    win.isHidden = true
                    win.rootViewController = nil
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = ShieldAnchorView(frame: .zero)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        view.onMoveToWindow = { [weak coordinator = context.coordinator] in
            coordinator?.syncBlock?()
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let coordinator = context.coordinator
        let locked = isLocked
        let privacy = isPrivacyShieldActive
        let dark = isDark
        let loc = locale
        let comp = companion
        let recMsg = lockRecoveryMessage
        let unlockFn = unlock
        let disableFn = onDisablePasscodeLock
        coordinator.syncBlock = { [weak coordinator, weak uiView] in
            guard let coordinator, let uiView else { return }
            Self.syncShield(
                uiView: uiView,
                coordinator: coordinator,
                isLocked: locked,
                isPrivacyShieldActive: privacy,
                isDark: dark,
                locale: loc,
                companion: comp,
                lockRecoveryMessage: recMsg,
                unlock: unlockFn,
                onDisablePasscodeLock: disableFn
            )
        }
        Self.syncShield(
            uiView: uiView,
            coordinator: coordinator,
            isLocked: locked,
            isPrivacyShieldActive: privacy,
            isDark: dark,
            locale: loc,
            companion: comp,
            lockRecoveryMessage: recMsg,
            unlock: unlockFn,
            onDisablePasscodeLock: disableFn
        )
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.syncBlock = nil
        if let anchor = uiView as? ShieldAnchorView {
            anchor.onMoveToWindow = nil
        }
        coordinator.shieldWindow?.resignKey()
        coordinator.shieldWindow?.isHidden = true
        coordinator.shieldWindow?.rootViewController = nil
        coordinator.shieldWindow = nil
    }

    private static func syncShield(
        uiView: UIView,
        coordinator: Coordinator,
        isLocked: Bool,
        isPrivacyShieldActive: Bool,
        isDark: Bool,
        locale: Locale,
        companion: Kind,
        lockRecoveryMessage: String?,
        unlock: @escaping () -> Void,
        onDisablePasscodeLock: (() -> Void)?
    ) {
        let shouldShow = isLocked || isPrivacyShieldActive
        if !shouldShow {
            let wasShowing = coordinator.shieldWindow != nil
            coordinator.shieldWindow?.resignKey()
            coordinator.shieldWindow?.isHidden = true
            coordinator.shieldWindow?.rootViewController = nil
            coordinator.shieldWindow = nil
            if wasShowing { uiView.window?.makeKey() }
            return
        }
        guard let scene = uiView.window?.windowScene else { return }
        let window: UIWindow
        if let existing = coordinator.shieldWindow, existing.windowScene === scene {
            window = existing
        } else {
            let created = UIWindow(windowScene: scene)
            created.windowLevel = .alert + 1
            created.backgroundColor = .clear
            coordinator.shieldWindow = created
            window = created
        }
        window.overrideUserInterfaceStyle = isDark ? .dark : .light
        window.accessibilityViewIsModal = true

        let baseView: AnyView = isLocked
            ? AnyView(
                LockView(
                    companion: companion,
                    lockRecoveryMessage: lockRecoveryMessage,
                    unlock: unlock,
                    onDisablePasscodeLock: onDisablePasscodeLock
                )
            )
            : AnyView(
                ZStack {
                    Palette.background
                    Duo(primary: companion, size: 88, mood: .sleep, poke: false).opacity(0.65)
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            )
        let themed = AnyView(
            baseView
                .lamp(isDark)
                .preferredColorScheme(isDark ? .dark : .light)
                .environment(\.locale, locale)
                .fontDesign(.rounded)
        )
        if let host = window.rootViewController as? UIHostingController<AnyView> {
            host.rootView = themed
            host.overrideUserInterfaceStyle = isDark ? .dark : .light
        } else {
            let host = UIHostingController(rootView: themed)
            host.view.backgroundColor = .clear
            host.overrideUserInterfaceStyle = isDark ? .dark : .light
            window.rootViewController = host
        }
        if isLocked {
            window.makeKeyAndVisible()
        } else {
            window.isHidden = false
        }
    }
}

extension View {
    /// Tab 0 (`摸索`) scoped navigation destinations.
    func exploreRoutes(path: Binding<NavigationPath>) -> some View {
        navigationDestination(for: ExploreRoute.self) { route in
            ExploreRouteDestinationView(route: route, path: path)
        }
    }

    /// Tab 1 (`台灯`) scoped navigation destinations.
    func lampRoutes() -> some View {
        navigationDestination(for: LampRoute.self) { route in
            switch route {
            case let .rhythm(month): RhythmView(month: month)
            case .stats: StatsView()
            }
        }
    }

    /// Tab 2 (`留念`) scoped navigation destinations.
    func keepsakesRoutes() -> some View {
        navigationDestination(for: KeepsakesRoute.self) { route in
            KeepsakesRouteDestinationView(route: route)
        }
    }

    /// Tab 3 (`工坊`) scoped navigation destinations.
    func studioRoutes() -> some View {
        navigationDestination(for: StudioRoute.self) { route in
            switch route {
            case .story: StoryView()
            case .sources: SourcesView()
            case .releaseNotes: ReleaseNotesView()
            case .data: DataView()
            case let .doc(name): DocView(name: name)
            case .licenses: LicensesView()
            }
        }
    }
}

private struct ExploreRouteDestinationView: View {
    @Environment(AppModel.self) private var app
    let route: ExploreRoute
    @Binding var path: NavigationPath

    var body: some View {
        switch route {
        case let .play(code, month):
            if let play = app.content.play(code) {
                PlayView(play: play, month: month).zoomDestination(route)
            } else {
                ContentUnavailableView(L10n.t("找不到这个玩法", "Activity Not Found"), systemImage: "leaf")
            }
        case .plan:
            PlanView(path: $path)
        case let .toybox(mode):
            ToyboxView(initialMode: mode)
        case .foodAtlas:
            FoodAtlasView()
        case .search:
            SearchView(path: $path)
        }
    }
}

private struct KeepsakesRouteDestinationView: View {
    @Environment(AppModel.self) private var app
    let route: KeepsakesRoute

    var body: some View {
        switch route {
        case let .month(month):
            MonthView(month: month).zoomDestination(route)
        case let .observe(month):
            ObserveView(month: month)
        case let .areas(month):
            AreasView(month: month)
        case let .care(month):
            CareView(month: month)
        case let .notes(month):
            NotesView(month: month)
        case let .topic(id):
            if let topic = app.content.topics.first(where: { $0.id == id }) {
                TopicView(topic: topic)
            } else {
                ContentUnavailableView(L10n.t("找不到这篇内容", "Guide Not Found"), systemImage: "book.closed")
            }
        case .firsts:
            FirstsView()
        case .growth:
            GrowthView()
        case .capsules:
            TimeCapsuleListView()
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
    @State private var pendingBirthAfterConsent = false
    @State private var doc: String?
    @State private var chose = false
    @State private var lookDown = false
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // tap either of them: they answer (Moss is the child, Otto the grown-up — nothing to choose)
                LampScene(play: !app.consent.isEmpty, chosen: nil, lookDown: lookDown) { _ in
                    withAnimation(reduce ? nil : .spring(response: 0.4, dampingFraction: 0.8)) { chose = true }
                    lookDown = true
                }
                .frame(minHeight: 220, idealHeight: 330, maxHeight: 420)
                .ignoresSafeArea(edges: .top)
                .sensoryFeedback(.selection, trigger: chose)

                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Text(L10n.appName).font(.largeTitle.weight(.bold))
                        Text(L10n.t("孩子摸索，大人点灯", "They explore. You hold the light.")).font(.title3.weight(.semibold)).foregroundStyle(Palette.accent)
                        Text(L10n.t("陪 0–3 岁的孩子一起玩，看着一个月一个月长大，把每一天记下来。", "Play alongside your 0–3 year old, watch them grow month by month, and keep each day's quiet notes."))
                            .font(.subheadline).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                        // who the two are, in one line (their parts as child and grown-up are for the pictures only)
                        Text(L10n.t("Moss 和 Otto 会一直陪在旁边，在「工坊」里选一个做伙伴", "Moss and Otto are always nearby — choose your companion in Studio."))
                            .font(.footnote).foregroundStyle(Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.top, 20).padding(.horizontal, 24)

                    VStack(spacing: 10) {
                        Button {
                            if app.mayKeep() {
                                askBirth = true
                            } else {
                                pendingBirthAfterConsent = true
                            }
                        } label: { Text(L10n.t("填写出生日期", "Add Birthday")).frame(maxWidth: .infinity).padding(.vertical, 6) }
                            .buttonStyle(.glassProminent).tint(Palette.accentFill).controlSize(.large)
                        Button { app.onboarded = true } label: { Text(L10n.t("稍后再填", "Later")).frame(maxWidth: .infinity).padding(.vertical, 6) }
                            .buttonStyle(.glass).controlSize(.large)
                        // the small print on its own piece of paper, so the meadow at the foot of the page never runs behind it
                        VStack(spacing: 6) {
                            Text(L10n.t("本应用陪伴家庭养育，不能替代医生的诊断和建议。", "A quiet companion for home parenting — not a substitute for medical advice."))
                                .font(.caption).foregroundStyle(Palette.secondaryText).multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            FlowRow(spacing: 16, lineSpacing: 4) {
                                ForEach([(L10n.t("使用条款", "Terms"), "TERMS"), (L10n.t("隐私政策", "Privacy"), "PRIVACY"), (L10n.t("免责声明", "Disclaimer"), "DISCLAIMER")], id: \.1) { t, f in
                                    Button(t) { doc = f }
                                        .font(.caption.weight(.semibold))
                                        .frame(minHeight: 44)
                                        .contentShape(Rectangle())
                                }
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Palette.background.opacity(0.92), in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 28, style: .continuous)
                        .fill(LinearGradient(colors: [Palette.background, Palette.background.opacity(0.96), .clear], startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(0.16), radius: 12, y: -4)
                )
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 28, style: .continuous)
                        .strokeBorder(Color(hex: 0xEADAC2).opacity(0.55), lineWidth: 0.75)
                        .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.14)))
                }
                .padding(.top, -22)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .pageBackground()
        .task(id: !app.consent.isEmpty) {
            guard !app.consent.isEmpty else { return }
            // shot C after the opening: the main one looks at the way in
            if !reduce { try? await Task.sleep(for: .milliseconds(5200)) }
            lookDown = true
        }
        .sheet(isPresented: $askBirth) { BirthSheet().lampPresented() }
        .onChange(of: app.consent) { _, next in
            guard pendingBirthAfterConsent else { return }
            if next == Consent.version {
                pendingBirthAfterConsent = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    guard app.consented else { return }
                    askBirth = true
                }
            } else if !next.isEmpty {
                pendingBirthAfterConsent = false
            }
        }
        .onChange(of: app.askConsent) { _, shown in
            if !shown && pendingBirthAfterConsent && !app.consented {
                pendingBirthAfterConsent = false
            }
        }
        .sheet(item: Binding(get: { doc.map { DocName(id: $0) } }, set: { doc = $0?.id })) { d in
            NavigationStack { DocView(name: d.id).toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.t("关闭", "Close"), systemImage: "xmark") { doc = nil } } } }
                .lampPresented()
        }
    }
}

private struct DocName: Identifiable { let id: String }
