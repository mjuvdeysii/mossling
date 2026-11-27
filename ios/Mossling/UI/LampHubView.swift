import SwiftUI

/// Tab 1: Otto's Bedside Lamp & Unified Care Sanctuary.
/// Combines Otto's interactive warm light & soundscapes, calm multi-day 24h rhythm overview
/// (`MiniRhythmDialCanvas` + read-only `DaySwimlaneCanvas` + inline day switching & Care Handover),
/// care quick-logging, and the unified collapsible ledger (eliminating the redundant split `JournalView`).
struct LampHubView: View {
    @Environment(AppModel.self) private var app
    @Environment(AppRouter.self) private var router: AppRouter?
    @Environment(JournalStore.self) private var j
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.night) private var night
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.scrolling) private var scrolling
    @Environment(\.scenePhase) private var scenePhase

    @Binding var path: NavigationPath

    @State private var soundscape = SoundscapeEngine.shared
    @State private var selectedDay: Day = .today
    @State private var pickingDay = false
    @State private var showingBedsideLamp = false
    @State private var showingHandover = false
    @State private var heroOnScreen = true
    @State private var ledgerExpanded = false
    @State private var expandedPeriods: Set<DayPeriod> = []
    @State private var touchedPeriods = false
    @State private var expandAllChapters = false
    @State private var editing: LogEntry?
    @State private var quickNight3AM: Bool
    @State private var ledgerFilter: String? = nil
    @State private var lampCardExpanded = false
    private let usesExternal3AMOverride: Bool

    init(
        path: Binding<NavigationPath>,
        initialDay: Day? = nil,
        initialLedgerExpanded: Bool = false,
        initialQuickNight3AM: Bool? = nil
    ) {
        _path = path
        _selectedDay = State(initialValue: initialDay ?? .today)
        _ledgerExpanded = State(initialValue: initialLedgerExpanded)
        usesExternal3AMOverride = initialLedgerExpanded || initialQuickNight3AM != nil
        _quickNight3AM = State(initialValue: initialLedgerExpanded ? false : (initialQuickNight3AM ?? CircadianDutyPhase.isLateNight3AM()))
    }

    private var warmth: LampWarmth {
        LampWarmth(rawValue: app.lampWarmthRaw) ?? .amber
    }

    private func openBedsideLamp() {
        TactileEngine.shared.vinylPop()
        if let router {
            router.openBedsideLamp()
        } else {
            showingBedsideLamp = true
        }
    }

    private func moveDay(to next: Day) {
        guard next != selectedDay else { return }
        TactileEngine.shared.pageTurn()
        withAnimation(reduce ? nil : .snappy) {
            selectedDay = next
            expandedPeriods = []
            touchedPeriods = false
            expandAllChapters = false
            ledgerFilter = nil
        }
    }

    private func toggleLedgerFilter(_ key: String?) {
        TactileEngine.shared.beadClick()
        withAnimation(reduce ? nil : .snappy) {
            if let key {
                if ledgerFilter == key {
                    ledgerFilter = nil
                } else {
                    ledgerFilter = key
                    ledgerExpanded = true
                }
            } else {
                ledgerFilter = nil
            }
        }
    }

    private var pastNoon: Date {
        Day.cal.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDay.date)
            ?? selectedDay.date.addingTimeInterval(12 * 3600)
    }

    private func defaultTimeForSelectedDay() -> Double {
        selectedDay == app.today ? JournalFile.now() : ms(pastNoon)
    }
    @State private var quick3AMMilkKind: String? = nil

    var body: some View {
        let dark = lamp || scheme == .dark
        let activeDay = selectedDay
        let isToday = activeDay == app.today
        let dayLogs = j.logs(on: activeDay)
        let own = dayLogs.filter { !$0.carriedOver(into: activeDay) }
        let startMs = activeDay.date.timeIntervalSince1970 * 1000
        let feedCount = dayLogs.feedCount(from: startMs)
        let sleepSec = dayLogs.filter { $0.type == LogType.sleep }.reduce(0.0) { $0 + $1.seconds(on: activeDay) }
        let diaperCount = own.filter { $0.type == LogType.diaper }.count
        let entryCount = dayLogs.rows().count

        let want3AM = usesExternal3AMOverride ? quickNight3AM : app.is3AMSanctuaryActive
        let is3AMOled = app.journal && want3AM && isToday
        let effectiveDark = dark || is3AMOled

        ScrollView {
            VStack(alignment: .leading, spacing: LayoutSpec.cardGap) {
                if is3AMOled {
                    midnightOneHandSanctuary(day: activeDay)
                } else {
                    if app.journal && !j.timers.isEmpty {
                        ForEach(j.timers, id: \.type) { t in
                            RunningRow(timer: t)
                        }
                    }

                    if app.journal {
                        quietCareStrip(day: activeDay, isToday: isToday, dark: effectiveDark)

                        rhythmCollectionCard(
                            day: activeDay,
                            isToday: isToday,
                            dayLogs: dayLogs,
                            feedCount: feedCount,
                            sleepSec: sleepSec,
                            diaperCount: diaperCount,
                            dark: effectiveDark
                        )

                        todayLedgerDrawer(
                            day: activeDay,
                            dayLogs: dayLogs,
                            entryCount: entryCount,
                            dark: effectiveDark
                        )

                        ottoLampSection(dark: effectiveDark)
                    } else {
                        ottoLampSection(dark: effectiveDark)
                        enableJournalInvitation(dark: effectiveDark)
                    }
                }
            }
            .padding(.horizontal, LayoutSpec.pageH)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .calmWhileScrolling()
        .background {
            if is3AMOled {
                Palette.oledBlack.ignoresSafeArea()
            } else {
                PageBackground(tone: night || dark ? Palette.amber : Crayon.caramel)
            }
        }
        .lamp(is3AMOled || lamp)
        .navigationTitle(is3AMOled ? L10n.t("夜灯极速", "3AM Lamp") : L10n.t("台灯", "Lamp"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if app.journal && isToday {
                    Button {
                        TactileEngine.shared.beadClick()
                        withAnimation(reduce ? nil : .snappy) {
                            if usesExternal3AMOverride {
                                quickNight3AM.toggle()
                            } else {
                                app.manual3AMOverride = !is3AMOled
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: is3AMOled ? "sun.max.fill" : "moon.stars.fill")
                                .font(.caption2.weight(.bold))
                            Text(is3AMOled ? L10n.t("日间台灯", "Full") : L10n.t("3AM 极速", "3AM"))
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(is3AMOled ? Palette.amber : Palette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(is3AMOled ? Color.white.opacity(0.10) : Palette.accent.opacity(0.12)))
                        .pillHitTarget()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(is3AMOled ? L10n.t("切换回完整台灯与节律视图", "Switch to full Lamp & rhythm view") : L10n.t("切换到凌晨三点极速护眼模式", "Switch to 3AM one-handed OLED mode"))
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                if app.journal {
                    Button {
                        TactileEngine.shared.beadClick()
                        pickingDay = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel(L10n.t("切换日期查看记录", "Choose day"))

                    Button {
                        guard app.mayKeep() else { return }
                        TactileEngine.shared.beadClick()
                        editing = LogEntry(type: LogType.bottle, start: defaultTimeForSelectedDay(), amount: 120)
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel(L10n.t("补记一条照护记录", "Add care entry"))
                }
            }
        }
        .fullScreenCover(isPresented: $showingBedsideLamp) { BedsideLampView() }
        .sheet(isPresented: $showingHandover) {
            HandoverSheet(day: activeDay).lampPresented(sheet: true, forceLamp: is3AMOled || lamp)
        }
        .sheet(isPresented: $pickingDay) {
            NavigationStack {
                let now = Date()
                let lower = min(app.birth?.date ?? .distantPast, now)
                DatePicker(
                    L10n.t("哪一天", "Date"),
                    selection: Binding(
                        get: { min(max(selectedDay.date, lower), now) },
                        set: { moveDay(to: Day($0)); pickingDay = false }
                    ),
                    in: lower...now,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, 16)
                .navigationTitle(L10n.t("看哪一天", "Choose Day"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.t("取消", "Cancel"), systemImage: "xmark") { pickingDay = false }
                    }
                }
            }
            .presentationDetents([.medium])
            .lampPresented(forceLamp: is3AMOled || lamp)
        }
        .sheet(item: Binding(get: { j.ask.map { LampAskWrap(id: $0) } }, set: { j.ask = $0?.id })) { w in
            AskSheet(type: w.id, on: isToday ? nil : pastNoon).lampPresented(forceLamp: is3AMOled || lamp)
        }
        .sheet(item: $editing) { e in
            EntrySheet(entry: e, isNew: !j.logs.contains { $0.id == e.id }, feed: j.feedEntries(containing: e.id)).lampPresented(forceLamp: is3AMOled || lamp)
        }
        .onChange(of: app.today) { old, t in if selectedDay == old { selectedDay = t } }
        .onChange(of: j.jumpToToday) { _, _ in selectedDay = app.today }
        .onChange(of: router?.expandLampLedgerToken ?? 0) { _, _ in
            withAnimation(reduce ? nil : CalmMotion.accordionSpring) {
                if usesExternal3AMOverride {
                    quickNight3AM = false
                } else {
                    app.manual3AMOverride = false
                }
                ledgerExpanded = true
            }
        }
    }

    // MARK: - Scene-Driven 3AM One-Handed OLED Speed Sanctuary

    @ViewBuilder
    private func midnightOneHandSanctuary(day: Day) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { tl in
            let now = tl.date
            let summary = MidnightCareSummary.build(logs: j.logs, timers: j.timers, now: now)
            let lastNurseSide = j.logs.filter { $0.type == LogType.nurse }.max { $0.start < $1.start }?.side
            let suggestedSide = lastNurseSide == "l" ? "r" : "l"
            let activeSleep = j.timers.first { $0.type == LogType.sleep }
            let activeNurse = j.timers.first { $0.type == LogType.nurse }
            let cols = type.isAccessibilitySize
                ? [GridItem(.flexible())]
                : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

            midnightOneHandBody(summary: summary, suggestedSide: suggestedSide, activeSleep: activeSleep, activeNurse: activeNurse, cols: cols)
        }
    }

    private func midnightOneHandBody(
        summary: MidnightCareSummary,
        suggestedSide: String,
        activeSleep: RunningTimer?,
        activeNurse: RunningTimer?,
        cols: [GridItem]
    ) -> some View {

        VStack(alignment: .leading, spacing: 12) {
            // 1. Minimalist OLED midnight facts banner + 1-tap Full Lamp / Handover actions
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(warmth.primaryGlow)
                        .frame(width: 8, height: 8)
                    Text(summary.nightStatusLine ?? L10n.t("凌晨照护极速模式 · 单手轻点即记", "3AM One-Hand Mode · Instant tap logging"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Palette.lampInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                }

                if !summary.facts.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(summary.facts) { item in
                            HStack(spacing: 4) {
                                Image(systemName: item.symbol)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(warmth.primaryGlow)
                                Text("\(item.label) \(item.agoText)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Palette.lampInk.opacity(0.84))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        openBedsideLamp()
                    } label: {
                        Label(L10n.t("全屏夜灯", "Bedside Lamp"), systemImage: "lamp.desk.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(warmth.onPrimaryInk)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Capsule().fill(warmth.primaryGlow))
                    }
                    .buttonStyle(.toy)

                    Button {
                        TactileEngine.shared.beadClick()
                        showingHandover = true
                    } label: {
                        Label(L10n.t("传灯交接", "Handover"), systemImage: "person.2.wave.2.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.lampInk)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.toy)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Palette.oledSurface))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(warmth.primaryGlow.opacity(0.28), lineWidth: 1))

            // 2. Active running timer deck (pause / switch side / finish right here without unlocking extra screens)
            ForEach(j.timers, id: \.type) { t in
                oledActiveTimerBar(t)
            }

            // 3. Thumb-zone 2x1 primary pads + stacked full-width bottle & diaper quick rows
            LazyVGrid(columns: cols, spacing: 10) {
                Button {
                    guard app.mayKeep() else { return }
                    TactileEngine.shared.beadClick()
                    if activeSleep != nil {
                        TactileEngine.shared.goldChime()
                        j.stop(LogType.sleep)
                    } else {
                        j.start(LogType.sleep, openFocus: false)
                    }
                } label: {
                    oledPadSurface(
                        symbol: LogType.symbol(LogType.sleep),
                        title: activeSleep != nil ? L10n.t("醒了 · 存睡眠", "Awake · Save Sleep") : L10n.t("开始睡觉", "Start Sleep"),
                        subtitle: activeSleep != nil ? L10n.t("计时运行中 · 点此结束", "Timer running · tap to finish") : L10n.t("单手一键夜灯计时", "One-tap night timer"),
                        tint: Crayon.lilac,
                        active: activeSleep != nil
                    )
                }
                .buttonStyle(.toy)

                Button {
                    guard app.mayKeep() else { return }
                    TactileEngine.shared.beadClick()
                    if activeNurse != nil {
                        j.switchSide(LogType.nurse)
                    } else {
                        j.start(LogType.nurse, side: suggestedSide, openFocus: false)
                    }
                } label: {
                    oledPadSurface(
                        symbol: LogType.symbol(LogType.nurse),
                        title: activeNurse != nil
                            ? (activeNurse?.side == "l" ? L10n.t("亲喂中 · 换右", "Nursing · Switch R") : L10n.t("亲喂中 · 换左", "Nursing · Switch L"))
                            : L10n.t("开始亲喂", "Start Nursing"),
                        subtitle: activeNurse != nil
                            ? L10n.t("轻点直接换侧", "Tap to switch side")
                            : (suggestedSide == "l" ? L10n.t("建议左侧 · 1 秒开始", "Left next · instant start") : L10n.t("建议右侧 · 1 秒开始", "Right next · instant start")),
                        tint: Crayon.pink,
                        active: activeNurse != nil
                    )
                }
                .buttonStyle(.toy)
            }

            VStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    let activeMilkKind = quick3AMMilkKind ?? summary.defaultMilkKind
                    HStack(spacing: 6) {
                        Image(systemName: LogType.symbol(LogType.bottle))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(warmth.primaryGlow)
                        Text(L10n.t("瓶喂速记", "Quick Bottle"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Palette.lampInk)
                        Spacer(minLength: 0)
                        Button {
                            TactileEngine.shared.beadClick()
                            quick3AMMilkKind = activeMilkKind == "breastmilk" ? "formula" : "breastmilk"
                        } label: {
                            Text(activeMilkKind == "breastmilk" ? L10n.t("母乳", "Milk") : L10n.t("配方", "Formula"))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Palette.lampInk.opacity(0.90))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.white.opacity(0.12)))
                                .pillHitTarget()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.t("切换母乳或配方奶", "Switch between breast milk and formula"))
                    }
                    HStack(spacing: 8) {
                        ForEach(summary.bottleSuggestions, id: \.self) { ml in
                            Button {
                                guard app.mayKeep() else { return }
                                TactileEngine.shared.beadClick()
                                _ = j.record(LogEntry(type: LogType.bottle, start: JournalFile.now(), amount: ml, detail: activeMilkKind))
                            } label: {
                                Text(L10n.volume(ml: ml))
                                    .font(Typeface.numerals(13, relativeTo: .caption, weight: .bold))
                                    .foregroundStyle(warmth.onPrimaryInk)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.78)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(Capsule().fill(warmth.primaryGlow.opacity(0.88)))
                            }
                            .buttonStyle(.toy)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Palette.oledSurface))
                .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: LogType.symbol(LogType.diaper))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Crayon.sky)
                        Text(L10n.t("尿布速记", "Quick Diaper"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Palette.lampInk)
                    }
                    HStack(spacing: 8) {
                        ForEach([("wet", L10n.t("湿", "Wet")), ("dirty", L10n.t("便", "Dirty")), ("both", L10n.t("都有", "Both"))], id: \.0) { kind, label in
                            Button {
                                guard app.mayKeep() else { return }
                                TactileEngine.shared.beadClick()
                                _ = j.record(LogEntry(type: LogType.diaper, start: JournalFile.now(), detail: kind))
                            } label: {
                                Text(label)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Palette.lampInk)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(Capsule().fill(Crayon.sky.opacity(0.24)))
                                    .overlay(Capsule().strokeBorder(Crayon.sky.opacity(0.55), lineWidth: 0.9))
                            }
                            .buttonStyle(.toy)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Palette.oledSurface))
                .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
            }

            let careWatch = CareWatchSummary.recent24h(in: j.logs)
            if careWatch.hasActivity || app.careModeActive {
                HStack(spacing: 8) {
                    Image(systemName: careWatch.hasFever ? "thermometer.high" : "cross.case.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(careWatch.hasFever ? Crayon.tangerine : warmth.primaryGlow)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(careWatch.latestTemp.map { L10n.t("24h 体温 \($0.summary)", "24h Temp \($0.summary)") } ?? L10n.t("24h 照护看护", "24h Care Watch"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.lampInk)
                        if let med = careWatch.latestMed {
                            let ms = med.summary.isEmpty ? LogType.name(LogType.medicine) : med.summary
                            Text(L10n.t("用药 \(hm(med.startDate)) · \(ms)", "Med \(hm(med.startDate)) · \(ms)"))
                                .font(.caption2)
                                .foregroundStyle(Palette.lampInk.opacity(0.75))
                        }
                    }
                    Spacer(minLength: 4)
                    Button(L10n.t("体温", "Temp")) {
                        if app.mayKeep() { j.ask = LogType.temp }
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(warmth.onPrimaryInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(warmth.primaryGlow))
                    .pillHitTarget()
                    .buttonStyle(.plain)
                    Button(L10n.t("用药", "Med")) {
                        if app.mayKeep() { j.ask = LogType.medicine }
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Palette.lampInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                    .pillHitTarget()
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Palette.oledSurface))
                .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder((careWatch.hasFever ? Crayon.tangerine : warmth.primaryGlow).opacity(0.35), lineWidth: 1))
            }

            Button {
                TactileEngine.shared.beadClick()
                withAnimation(reduce ? nil : .snappy) {
                    if usesExternal3AMOverride {
                        quickNight3AM = false
                    } else {
                        app.manual3AMOverride = false
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text(L10n.t("切回完整台灯 · 24h 节律盘与手账明细", "Switch to Full Lamp · 24h dial & entries"))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(warmth.primaryGlow.opacity(0.9))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(Palette.oledSurface))
            }
            .buttonStyle(.plain)
        }
    }

    private func oledActiveTimerBar(_ t: RunningTimer) -> some View {
        let paused = t.pausedAt != nil
        return TimelineView(.periodic(from: .now, by: 1)) { tl in
            let elapsed = t.total(tl.date.timeIntervalSince1970 * 1000)
            HStack(spacing: 10) {
                Image(systemName: LogType.symbol(t.type))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(warmth.primaryGlow)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.timerStatus(t.type, side: t.side, paused: paused))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.lampInk.opacity(0.84))
                    Text(clock(elapsed))
                        .font(Typeface.numerals(20, relativeTo: .title3, weight: .bold))
                        .foregroundStyle(warmth.primaryGlow)
                }
                Spacer(minLength: 4)
                Button {
                    guard app.mayKeep() else { return }
                    TactileEngine.shared.beadClick()
                    j.togglePause(t.type)
                } label: {
                    Image(systemName: paused ? "play.fill" : "pause.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.lampInk)
                        .frame(minWidth: 44, minHeight: 44)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(paused ? L10n.t("继续计时", "Resume timer") : L10n.t("暂停计时", "Pause timer"))

                Button {
                    guard app.mayKeep() else { return }
                    TactileEngine.shared.goldChime()
                    j.stop(t.type)
                } label: {
                    Text(t.type == LogType.sleep ? L10n.t("醒了", "Awake") : L10n.t("完成", "Done"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(warmth.onPrimaryInk)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(warmth.primaryGlow))
                }
                .buttonStyle(.toy)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Palette.oledSurface))
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(warmth.primaryGlow.opacity(0.45), lineWidth: 1.2))
        }
    }

    private func oledPadSurface(symbol: String, title: String, subtitle: String, tint: Color, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(active ? warmth.onPrimaryInk : tint)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(active ? warmth.primaryGlow : tint.opacity(0.20)))
                Spacer(minLength: 0)
            }
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Palette.lampInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(Palette.lampInk.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(Palette.oledSurface))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(active ? warmth.primaryGlow.opacity(0.72) : Color.white.opacity(0.10), lineWidth: active ? 1.4 : 1)
        )
    }

    // MARK: - Section 1: Context-Adaptive Otto Bedside Lamp Stage

    @ViewBuilder
    private func ottoLampSection(dark: Bool) -> some View {
        if dark || soundscape.isPlaying || lampCardExpanded {
            ottoLampHeroCard(dark: dark)
        } else {
            ottoCompactLampBar(dark: dark)
        }
    }

    private func ottoCompactLampBar(dark: Bool) -> some View {
        let brightness = max(0.15, min(1.0, app.lampBrightness))
        return HStack(spacing: 12) {
            ottoLivingStage(brightness: brightness, playing: false)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .onTapGesture { openBedsideLamp() }

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("Otto 床头夜灯 · 按需展开", "Otto's Bedside Lamp"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.lampInk)
                    .lineLimit(1)
                Text(L10n.t("\(warmth.label) \(Int(brightness * 100))% · 6 组离线助眠声景", "\(warmth.label) \(Int(brightness * 100))% · 6 offline soundscapes"))
                    .font(.caption)
                    .foregroundStyle(Palette.lampInk.opacity(0.75))
                    .lineLimit(1)
            }
            Spacer(minLength: 4)

            Button {
                openBedsideLamp()
            } label: {
                Image(systemName: "lamp.desk.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(warmth.onPrimaryInk)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(warmth.primaryGlow))
                    .pillHitTarget()
            }
            .buttonStyle(.toy)
            .accessibilityLabel(L10n.t("打开全屏夜灯", "Open fullscreen bedside lamp"))

            Button {
                TactileEngine.shared.beadClick()
                withAnimation(reduce ? nil : .snappy) { lampCardExpanded = true }
            } label: {
                Image(systemName: "chevron.down")
                    .font(Typeface.label(11, relativeTo: .caption2, weight: .bold))
                    .foregroundStyle(Palette.lampInk.opacity(0.85))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.14)))
                    .hitTarget(LayoutSpec.hitMin)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("展开夜灯与声景面板", "Expand bedside lamp controls"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x161E3B), Color(hex: 0x0D1328)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(warmth.primaryGlow.opacity(0.22), lineWidth: 0.8)
        )
        .onScrollVisibilityChange(threshold: 0.05) { heroOnScreen = $0 }
    }

    private func ottoLampHeroCard(dark: Bool) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { tl in
            let midnight = app.journal ? MidnightCareSummary.build(logs: j.logs, timers: j.timers, now: tl.date) : nil
            ottoLampHeroBody(midnight: midnight, dark: dark)
        }
    }

    private func ottoLampHeroBody(midnight: MidnightCareSummary?, dark: Bool) -> some View {
        let brightness = max(0.15, min(1.0, app.lampBrightness))
        let surfaceTop = Color(hex: 0x161E3B)
        let surfaceBottom = Color(hex: 0x0D1328)
        let playing = soundscape.isPlaying

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: LayoutSpec.iconTextGap) {
                ZStack {
                    RadialGradient(
                        colors: [warmth.primaryGlow.opacity(0.24), .clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: 42
                    )
                    .frame(width: 78, height: 78)
                    ottoLivingStage(brightness: brightness, playing: playing)
                        .frame(width: 68, height: 68)
                }
                .contentShape(Circle())
                    .onTapGesture {
                        openBedsideLamp()
                    }
                    .accessibilityLabel(L10n.t("轻点打开 Otto 全屏床头夜灯", "Tap to open fullscreen Otto Bedside Lamp"))

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t("Otto 的夜灯与助眠声景", "Otto's Bedside Lamp"))
                        .font(.headline.weight(.bold))
                        .tracking(LayoutSpec.titleTracking)
                        .foregroundStyle(Palette.lampInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(
                        midnight?.nightStatusLine
                            ?? soundscape.activeSummary
                            ?? L10n.t("柔暖滤光 · 六组纯离线声景", "Warm glow · 6 offline soundscapes")
                    )
                    .font(.footnote)
                    .foregroundStyle(Palette.lampInk.opacity(0.78))
                    .lineLimit(2)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Button {
                            openBedsideLamp()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "lamp.desk.fill")
                                    .font(.caption.weight(.bold))
                                Text(L10n.t("全屏夜灯", "Open Lamp"))
                                    .font(.footnote.weight(.semibold))
                                    .lineLimit(1)
                                    .fixedSize()
                            }
                            .foregroundStyle(warmth.onPrimaryInk)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 32)
                            .background(Capsule().fill(warmth.primaryGlow))
                            .pillHitTarget()
                        }
                        .buttonStyle(.toy)

                        if playing {
                            Button {
                                TactileEngine.shared.beadClick()
                                soundscape.stop()
                            } label: {
                                Label(L10n.t("暂停", "Pause"), systemImage: "pause.fill")
                                    .font(.footnote.weight(.semibold))
                                    .lineLimit(1)
                                    .fixedSize()
                                    .foregroundStyle(Palette.lampInk)
                                    .padding(.horizontal, 11)
                                    .frame(minHeight: 32)
                                    .background(Capsule().fill(Color.white.opacity(0.14)))
                                    .pillHitTarget()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
                if !dark && !soundscape.isPlaying && lampCardExpanded {
                    Button {
                        TactileEngine.shared.beadClick()
                        withAnimation(reduce ? nil : .snappy) { lampCardExpanded = false }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(Typeface.label(11, relativeTo: .caption2, weight: .bold))
                            .foregroundStyle(Palette.lampInk.opacity(0.78))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                            .hitTarget(LayoutSpec.hitMin)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("收起夜灯面板", "Collapse bedside lamp"))
                }
            }

            // Shared brightness & warmth tint controls synced directly with AppModel & BedsideLampView
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sun.min.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(warmth.primaryGlow)
                    Slider(
                        value: Binding(
                            get: { app.lampBrightness },
                            set: { app.lampBrightness = $0 }
                        ),
                        in: 0.15...1.0
                    )
                    .tint(warmth.primaryGlow)
                    .accessibilityLabel(L10n.t("床头灯亮度", "Bedside lamp brightness"))
                    Text("\(Int(brightness * 100))%")
                        .font(Typeface.numerals(12, relativeTo: .caption, weight: .semibold))
                        .foregroundStyle(Palette.lampInk.opacity(0.88))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 42, alignment: .trailing)
                }

                DSSegmentedControl(
                    items: LampWarmth.allCases,
                    selection: Binding(
                        get: { warmth },
                        set: { app.lampWarmthRaw = $0.rawValue }
                    ),
                    dark: true,
                    compact: false,
                    darkSurface: true,
                    title: { $0.label }
                )
            }

            Divider().overlay(Color.white.opacity(0.10))

            // Balanced 3x2 grid of 6 offline soundscapes (zero ragged 4+2 wrapping)
            let soundCols = type.isAccessibilitySize
                ? [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
                : Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
            LazyVGrid(columns: soundCols, spacing: 8) {
                ForEach(SoundscapeKind.allCases) { kind in
                    let isPrimary = soundscape.active == kind
                    let isSecondary = soundscape.secondary == kind
                    let active = isPrimary || isSecondary
                    Button {
                        TactileEngine.shared.beadClick()
                        soundscape.toggle(kind)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: kind.symbol)
                                .font(Typeface.label(12, relativeTo: .caption, weight: .semibold))
                                .foregroundStyle(active ? warmth.onPrimaryInk : warmth.primaryGlow.opacity(0.90))
                            Text(kind.title)
                                .font(.footnote.weight(active ? .semibold : .medium))
                                .foregroundStyle(active ? warmth.onPrimaryInk : Palette.lampInk.opacity(0.90))
                                .lineLimit(1)
                                .minimumScaleFactor(0.76)
                        }
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                                .fill(active ? warmth.primaryGlow : Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                                .strokeBorder(active ? warmth.primaryGlow : Color.white.opacity(0.10), lineWidth: 0.75)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).inset(by: -3))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
        }
        .padding(LayoutSpec.cardPadHero)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(LinearGradient(colors: [surfaceTop, surfaceBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(warmth.primaryGlow.opacity(0.24), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(dark ? 0.28 : 0.12), radius: 14, y: 6)
        .onScrollVisibilityChange(threshold: 0.05) { heroOnScreen = $0 }
    }

    @ViewBuilder
    private func ottoLivingStage(brightness: Double, playing: Bool) -> some View {
        let freezeMotion = reduce || Perf.still || scrolling.moving || !heroOnScreen || scenePhase != .active
        if freezeMotion {
            ottoLivingStageFrame(brightness: brightness, playing: playing, breathTime: 0, isStatic: true)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { tl in
                ottoLivingStageFrame(
                    brightness: brightness,
                    playing: playing,
                    breathTime: tl.date.timeIntervalSinceReferenceDate,
                    isStatic: false
                )
            }
        }
    }

    private func ottoLivingStageFrame(brightness: Double, playing: Bool, breathTime: Double, isStatic: Bool) -> some View {
        let wave = isStatic ? 0.35 : (0.5 - 0.5 * cos(breathTime / 3.8 * 2.0 * .pi))
        let ringScale = 0.88 + 0.16 * wave
        let glowRadius: CGFloat = 46 + CGFloat(wave * (playing ? 10 : 5))

        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            warmth.primaryGlow.opacity(0.26 + brightness * 0.42 + (playing ? 0.06 * wave : 0)),
                            warmth.secondaryTint.opacity(0.14),
                            .clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: glowRadius
                    )
                )
                .frame(width: 74, height: 74)

            if playing {
                Circle()
                    .strokeBorder(warmth.primaryGlow.opacity(0.32 * (1.0 - 0.45 * wave)), lineWidth: 1.1)
                    .frame(width: 62, height: 62)
                    .scaleEffect(ringScale)
            }

            StoryTheaterActorView(
                kind: .otto,
                size: 56,
                mood: playing ? .happy : .open,
                look: CGPoint(x: 0.28, y: 0.08),
                lid: 0.36,
                lean: playing ? (2.5 + (isStatic ? 0 : (wave - 0.5) * 2.2)) : 0,
                breathTime: breathTime,
                isStatic: isStatic,
                dark: true,
                flat: ArtStyle.current == .flat,
                compact: false
            )
        }
    }

    // MARK: - Section 2: Visual Rhythm Collection (Single-Source Unified Day Sanctuary)

    private func rhythmCollectionCard(
        day: Day,
        isToday: Bool,
        dayLogs: [LogEntry],
        feedCount: Int,
        sleepSec: Double,
        diaperCount: Int,
        dark: Bool
    ) -> some View {
        let baby = max(0, min(app.babyMonth ?? 0, 36))
        let sleepSlices = AtelierDockMetrics.sleepSlices(in: dayLogs, on: day)
        let feedFracs = AtelierDockMetrics.feedFractions(in: dayLogs, on: day)
        let prevDay = day.plus(days: -1)
        let nextDay = day.plus(days: 1)
        let canStepBack = app.birth.map { prevDay.epochDay >= $0.epochDay } ?? true
        let canStepForward = nextDay.epochDay <= app.today.epochDay
        let dayLabel = isToday ? L10n.t("今日", "Today") : (L10n.isEnglish ? "\(Day.enMonths[day.m - 1]) \(day.d)" : day.md)

        return VStack(alignment: .leading, spacing: 12) {
            let headerLayout = type.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: .center, spacing: LayoutSpec.iconTextGap))
            headerLayout {
                HStack(alignment: .center, spacing: LayoutSpec.iconTextGap) {
                    MiniRhythmDialCanvas(sleepSlices: sleepSlices, feedFractions: feedFracs, dark: dark)
                        .scaleEffect(0.86)
                        .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isToday ? L10n.t("今日照护一览", "Today at a Glance") : L10n.t("\(dayLabel) · 照护一览", "\(dayLabel) at a Glance"))
                            .font(.headline.weight(.semibold))
                            .tracking(LayoutSpec.titleTracking)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.t("睡眠 · 喂奶 · 尿布，一眼看清", "Feeds, sleep & diapers"))
                            .font(.footnote)
                            .foregroundStyle(Palette.secondaryText)
                            .lineLimit(type.isAccessibilitySize ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !type.isAccessibilitySize {
                    Spacer(minLength: 4)
                }

                HStack(spacing: 6) {
                    Button {
                        if canStepBack { moveDay(to: prevDay) }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption2.weight(.bold))
                            .frame(minWidth: 44, minHeight: 44)
                            .background(Circle().fill(Palette.fill))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canStepBack)
                    .opacity(canStepBack ? 1 : 0.35)
                    .accessibilityLabel(L10n.t("前一天", "Previous day"))

                    if !isToday {
                        Button {
                            moveDay(to: app.today)
                        } label: {
                            Text(L10n.t("回今天", "Today"))
                                .font(.caption2.weight(.bold))
                                .lineLimit(1)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 44)
                                .background(Capsule().fill(Palette.accentFill))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        if canStepForward { moveDay(to: nextDay) }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .frame(minWidth: 44, minHeight: 44)
                            .background(Circle().fill(Palette.fill))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canStepForward)
                    .opacity(canStepForward ? 1 : 0.35)
                    .accessibilityLabel(L10n.t("后一天", "Next day"))
                }
            }

            DaySummaryTiles(
                day: day,
                logs: dayLogs,
                feedCount: feedCount,
                sleepSec: sleepSec,
                diaperCount: diaperCount,
                dark: dark,
                selectedFilter: ledgerFilter,
                onSelectFilter: { toggleLedgerFilter($0) }
            )

            if isToday {
                TimelineView(.periodic(from: .now, by: 60)) { tl in
                    DaySwimlaneCanvas(day: day, logs: dayLogs, timers: j.timers, only: ledgerFilter, dark: dark, nowDate: tl.date)
                        .allowsHitTesting(false)
                }
            } else {
                DaySwimlaneCanvas(day: day, logs: dayLogs, timers: [], only: ledgerFilter, dark: dark)
                    .allowsHitTesting(false)
            }

            if type.isAccessibilitySize {
                VStack(spacing: 8) {
                    rhythmNavControls(baby: baby, dark: dark)
                }
            } else {
                HStack(spacing: 8) {
                    rhythmNavControls(baby: baby, dark: dark)
                }
            }
        }
        .padding(LayoutSpec.cardPad)
        .printCard(radius: Radius.card)
    }

    @ViewBuilder
    private func rhythmNavControls(baby: Int, dark: Bool) -> some View {
        NavigationLink(value: LampRoute.rhythm(baby)) {
            compactNavPill(symbol: "clock.arrow.circlepath", text: L10n.t("月龄作息", "Daily Guide"), color: Crayon.lilac, dark: dark)
        }
        .buttonStyle(.toy)

        NavigationLink(value: LampRoute.stats) {
            compactNavPill(symbol: "chart.bar.fill", text: L10n.t("节律与七日", "Dial & 7-Day"), color: Crayon.sky, dark: dark)
        }
        .buttonStyle(.toy)

        Button {
            TactileEngine.shared.beadClick()
            showingHandover = true
        } label: {
            compactNavPill(symbol: "person.2.wave.2.fill", text: L10n.t("传灯交接", "Handover"), color: Palette.amber, dark: dark)
        }
        .buttonStyle(.toy)
    }

    private func compactNavPill(symbol: String, text: String, color: Color, dark: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(dark ? color : Crayon.ink(color))
            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(type.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.84)
                .fixedSize(horizontal: false, vertical: type.isAccessibilitySize)
            if type.isAccessibilitySize {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .padding(.horizontal, type.isAccessibilitySize ? 12 : 8)
        .background(
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .fill(color.opacity(dark ? 0.18 : 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .strokeBorder(color.opacity(dark ? 0.28 : 0.22), lineWidth: 0.6)
        )
        .contentShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).inset(by: -4))
    }

    // MARK: - Section 3: Low-Priority Quiet Care Strip & Collapsible Ledger

    private func quietCareStrip(day: Day, isToday: Bool, dark: Bool) -> some View {
        let diaperGraduated = app.graduatedModules.contains(CareGearEngine.diaperModule) && !app.careModeActive
        let feedsGraduated = app.graduatedModules.contains(CareGearEngine.feedsModule) && !app.careModeActive
        let primaryTypes: [String] = {
            if app.careModeActive {
                return [LogType.nurse, LogType.bottle, LogType.sleep, LogType.diaper, LogType.temp, LogType.medicine]
            }
            var out: [String] = feedsGraduated ? [LogType.solid, LogType.sleep] : [LogType.nurse, LogType.bottle, LogType.sleep]
            if !diaperGraduated { out.append(LogType.diaper) }
            return out
        }()
        let careWatch = isToday ? CareWatchSummary.recent24h(in: j.logs) : nil
        let extraTypes = LogType.buttons.filter { !primaryTypes.contains($0) && $0 != LogType.growth }
        let hint = isToday
            ? CareGearEngine.suggestedGraduation(
                developmentalMonth: app.babyMonth ?? 0,
                logs: j.logs,
                graduatedModules: app.graduatedModules,
                dismissedModules: app.dismissedGraduations,
                today: app.today
            )
            : nil

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(isToday ? L10n.t("随手轻记", "Quiet Log") : L10n.t("补记 \(day.md)", "Log to \(day.md)"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Button {
                    TactileEngine.shared.beadClick()
                    withAnimation(reduce ? nil : .snappy) { app.careModeActive.toggle() }
                } label: {
                    Label(L10n.t("照护模式", "Care Mode"), systemImage: app.careModeActive ? "cross.case.fill" : "cross.case")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(app.careModeActive ? .white : Palette.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(app.careModeActive ? Crayon.buttonFill(Crayon.teal) : Palette.fill))
                }
                .buttonStyle(.plain)
                Spacer()
                Menu {
                    Text(app.currentGear.title)
                    Divider()
                    ForEach(extraTypes, id: \.self) { t in
                        Button(LogType.name(t), systemImage: LogType.symbol(t)) {
                            handleTap(t, day: day, isToday: isToday)
                        }
                    }
                    if !app.graduatedModules.isEmpty {
                        Divider()
                        Button(L10n.t("恢复全部快捷按钮", "Restore All Quick Buttons"), systemImage: "arrow.uturn.backward") {
                            app.graduatedModules = []
                            app.careModeActive = false
                        }
                    }
                } label: {
                    Label(L10n.t("更多照护", "More"), systemImage: "plus.circle")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Palette.accent)
                }
            }

            if let careWatch, careWatch.hasActivity {
                HStack(spacing: 8) {
                    Image(systemName: careWatch.hasFever ? "thermometer.high" : "cross.case.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(careWatch.hasFever ? Palette.danger : Crayon.ink(Crayon.teal))
                    Text([
                        careWatch.latestTemp.map { L10n.t("24h 体温 \($0.summary)", "24h Temp \($0.summary)") },
                        careWatch.latestMed.map { L10n.t("用药 \($0.summary.isEmpty ? LogType.name(LogType.medicine) : $0.summary)", "Med \($0.summary.isEmpty ? LogType.name(LogType.medicine) : $0.summary)") }
                    ].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(careWatch.hasFever ? Palette.danger : .primary)
                    .lineLimit(type.isAccessibilitySize ? nil : 1)
                    Spacer(minLength: 4)
                    if !app.careModeActive {
                        Button(L10n.t("展开", "Focus")) {
                            TactileEngine.shared.beadClick()
                            withAnimation(reduce ? nil : .snappy) { app.careModeActive = true }
                        }
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Crayon.ink(Crayon.teal))
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                        .fill((careWatch.hasFever ? Palette.danger : Crayon.teal).opacity(dark ? 0.18 : 0.10))
                )
            }

            let normalCols = primaryTypes.count > 4 ? 3 : max(1, primaryTypes.count)
            let cols = type.isAccessibilitySize
                ? [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
                : Array(repeating: GridItem(.flexible(), spacing: 10), count: normalCols)

            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(primaryTypes, id: \.self) { t in
                    let col = LogType.color(t)
                    Button {
                        TactileEngine.shared.beadClick()
                        handleTap(t, day: day, isToday: isToday)
                    } label: {
                        VStack(spacing: 5) {
                            IconTile(symbol: LogType.symbol(t), color: col, size: 28, round: true)
                            Text(LogType.name(t))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.84)
                        }
                        .frame(maxWidth: .infinity, minHeight: 62)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                                .fill(col.opacity(dark ? 0.16 : 0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                                .strokeBorder(col.opacity(dark ? 0.24 : 0.18), lineWidth: 0.6)
                        )
                    }
                    .buttonStyle(.toy)
                }
            }

            if let hint {
                VStack(alignment: .leading, spacing: 6) {
                    Text(hint.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(hint.message)
                        .font(.caption2)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Button(hint.confirmLabel) {
                            TactileEngine.shared.beadClick()
                            withAnimation(reduce ? nil : .snappy) {
                                _ = app.graduatedModules.insert(hint.moduleKey)
                            }
                        }
                        .buttonStyle(.vinyl(Crayon.teal))
                        Button(L10n.t("先留着", "Keep")) {
                            TactileEngine.shared.beadClick()
                            withAnimation(reduce ? nil : .snappy) {
                                _ = app.dismissedGraduations.insert(hint.moduleKey)
                            }
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Palette.secondaryText)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(Palette.fill.opacity(0.65)))
            }
        }
        .padding(LayoutSpec.cardPad)
        .printCard(radius: Radius.card)
    }

    private func todayLedgerDrawer(day: Day, dayLogs: [LogEntry], entryCount: Int, dark: Bool) -> some View {
        let isToday = day == app.today
        let categories = LampHubFilter.availableCategories(in: dayLogs, on: day)
        let activeFilter: String? = {
            guard let f = ledgerFilter else { return nil }
            return LampHubFilter.filter(dayLogs, by: f).isEmpty ? nil : f
        }()
        let filteredLogs = LampHubFilter.filter(dayLogs, by: activeFilter)
        let displayedCount = filteredLogs.rows().count

        return VStack(spacing: 0) {
            CalmAccordion(isExpanded: $ledgerExpanded, spacing: 10) { open in
                HStack(spacing: LayoutSpec.iconTextGap) {
                    IconTile(symbol: "list.bullet.clipboard.fill", color: Crayon.caramel, size: 28, round: true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isToday ? L10n.t("今日明细手账", "Today's Entries") : L10n.t("\(day.md) 明细手账", "\(day.md) Entries"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(
                            activeFilter.map {
                                L10n.t(
                                    "已单独显示「\(LampHubFilter.categoryTitle(for: $0))」· \(displayedCount) 条",
                                    "Showing \(LampHubFilter.categoryTitle(for: $0)) · \(displayedCount)"
                                )
                            } ?? (
                                entryCount == 0
                                    ? L10n.t("尚无条目，轻点展开或补记", "No entries yet · tap to add")
                                    : L10n.t("共 \(entryCount) 条 · 轻点展开或点上方卡片筛一列", "\(entryCount) entries · tap tile above to filter")
                            )
                        )
                        .font(.footnote)
                        .foregroundStyle(activeFilter == nil ? Palette.secondaryText : Palette.accent)
                        .lineLimit(type.isAccessibilitySize ? nil : 1)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
            } content: {
                VStack(alignment: .leading, spacing: 10) {
                    if !categories.isEmpty {
                        FlowRow(spacing: 6, lineSpacing: 6) {
                            let allOn = activeFilter == nil
                            Button {
                                toggleLedgerFilter(nil)
                            } label: {
                                Text(L10n.t("全部 \(entryCount)", "All \(entryCount)"))
                                    .font(.caption.weight(allOn ? .bold : .medium))
                                    .foregroundStyle(allOn ? .white : .primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(allOn ? Palette.accentFill : Palette.fill))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(allOn ? .isSelected : [])

                            ForEach(categories) { cat in
                                let on = (activeFilter == cat.key)
                                let tint = LogType.color(JournalKinds.type(cat.key))
                                Button {
                                    toggleLedgerFilter(cat.key)
                                } label: {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(on ? Color.white : tint)
                                            .frame(width: 6, height: 6)
                                        Text("\(cat.title) \(cat.count)")
                                            .font(.caption.weight(on ? .bold : .medium))
                                    }
                                    .foregroundStyle(on ? .white : .primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(on ? Crayon.fill(tint, dark) : tint.opacity(dark ? 0.16 : 0.10)))
                                    .pillHitTarget()
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }

                    if !filteredLogs.isEmpty {
                        DayChapterLedger(
                            day: day,
                            today: app.today,
                            logs: filteredLogs,
                            only: activeFilter,
                            expandedPeriods: $expandedPeriods,
                            touchedPeriods: $touchedPeriods,
                            expandAll: $expandAllChapters,
                            edit: { editing = $0 },
                            delete: { j.delete($0) }
                        )
                    }

                    HStack(spacing: 8) {
                        Button {
                            guard app.mayKeep() else { return }
                            TactileEngine.shared.beadClick()
                            editing = LogEntry(type: LogType.bottle, start: defaultTimeForSelectedDay(), amount: 120)
                        } label: {
                            Label(L10n.t("补记这一天", "Add Past Entry"), systemImage: "square.and.pencil")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Palette.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(Palette.accent.opacity(dark ? 0.16 : 0.09)))
                        }
                        .buttonStyle(.toy)

                        Button {
                            TactileEngine.shared.beadClick()
                            pickingDay = true
                        } label: {
                            Label(L10n.t("换一天查看", "Pick Day"), systemImage: "calendar")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(Palette.fill))
                        }
                        .buttonStyle(.toy)
                    }
                }
            }
            .padding(LayoutSpec.cardPad)
        }
        .printCard(radius: Radius.card)
    }

    private func enableJournalInvitation(dark: Bool) -> some View {
        HStack(spacing: 12) {
            IconTile(symbol: "list.bullet.clipboard", color: Crayon.caramel, size: 32, round: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("台灯下照护记录", "Care Log Under Lamp"))
                    .font(.subheadline.weight(.semibold))
                Text(L10n.t("需要时再开启喂养、睡眠与尿布节律追踪，所有数据只存在本机。", "Optional nursing, sleep & diaper tracking stored strictly on this iPhone."))
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button {
                if app.mayKeep() {
                    TactileEngine.shared.beadClick()
                    withAnimation(.snappy) { app.journal = true }
                }
            } label: {
                Text(L10n.t("开启", "Turn On"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Palette.accentFill))
            }
            .buttonStyle(.toy)
        }
        .padding(LayoutSpec.cardPad)
        .printCard(radius: Radius.card)
    }

    private func handleTap(_ t: String, day: Day, isToday: Bool) {
        guard app.mayKeep() else { return }
        if isToday && LogType.timed.contains(t) {
            j.focus = t
            return
        }
        if !isToday && LogType.timed.contains(t) {
            let endMs = defaultTimeForSelectedDay()
            let startMs = endMs - 20 * 60_000
            let nextSide: String? = t == LogType.nurse
                ? (j.logs.first(where: { $0.type == LogType.nurse })?.side == "l" ? "r" : "l")
                : nil
            editing = LogEntry(type: t, start: startMs, end: endMs, side: nextSide)
            return
        }
        if t == LogType.bath {
            _ = j.record(LogEntry(type: t, start: defaultTimeForSelectedDay()))
            return
        }
        j.ask = t
    }
}

private struct LampAskWrap: Identifiable { let id: String }

/// The day's four numbers a parent checks first — how long they slept, how many feeds and for how long in all, how
/// many diapers — set large, in three soft tiles (after "我喜欢很明显的看到他今天睡了多少个小时，喝了多少小时的奶，
/// 喝了多少次奶，换了多少次尿包"). Big rounded figures, one regular caption line each; nothing hidden in a footnote.
struct DaySummaryTiles: View {
    let day: Day
    let logs: [LogEntry]
    let feedCount: Int
    let sleepSec: Double
    let diaperCount: Int
    let dark: Bool
    var selectedFilter: String? = nil
    var onSelectFilter: ((String?) -> Void)? = nil
    @Environment(\.dynamicTypeSize) private var type

    var body: some View {
        let nurseSec = logs.filter { $0.type == LogType.nurse }.reduce(0) { $0 + $1.seconds(on: day) }
        let bottleMl = logs.filter { $0.type == LogType.bottle }.compactMap(\.amount).reduce(0, +)
        let longest = logs.filter { $0.type == LogType.sleep }.map { $0.seconds(on: day) }.max() ?? 0
        let wet = logs.filter { $0.type == LogType.diaper && ($0.detail == "wet" || $0.detail == "both") }.count
        let dirty = logs.filter { $0.type == LogType.diaper && ($0.detail == "dirty" || $0.detail == "both") }.count

        let feedLines: [String] = {
            var lines: [String] = []
            if nurseSec >= 60 {
                lines.append(L10n.t("亲喂 \(hoursValue(nurseSec))", "Nursed \(hoursValue(nurseSec))"))
            }
            if bottleMl > 0 {
                lines.append(L10n.t("瓶喂 \(bottleMl) ml", "Bottle \(bottleMl) ml"))
            }
            return lines.isEmpty ? [L10n.t("还没有记录", "None yet")] : lines
        }()

        let sleepLines: [String] = longest >= 60
            ? [L10n.t("最长 \(hoursValue(longest))", "Best \(hoursValue(longest))")]
            : [L10n.t("还没有记录", "None yet")]

        let diaperLines: [String] = diaperCount > 0
            ? [L10n.t("湿 \(wet) · 便 \(dirty)", "Wet \(wet) · Dirty \(dirty)")]
            : [L10n.t("还没有记录", "None yet")]

        let layout = type.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 10))
        layout {
            tile(filterKey: LampHubFilter.feedKey,
                 color: LogType.color(LogType.nurse), symbol: LogType.symbol(LogType.nurse),
                 title: L10n.t("喂奶", "Feeds"),
                 value: "\(feedCount)", unit: L10n.t("次", feedCount == 1 ? "feed" : "feeds"),
                 lines: feedLines)
            tile(filterKey: LogType.sleep,
                 color: LogType.color(LogType.sleep), symbol: LogType.symbol(LogType.sleep),
                 title: L10n.t("睡眠", "Sleep"),
                 value: hoursValue(sleepSec), unit: "",
                 lines: sleepLines)
            tile(filterKey: LogType.diaper,
                 color: LogType.color(LogType.diaper), symbol: LogType.symbol(LogType.diaper),
                 title: L10n.t("尿布", "Diapers"),
                 value: "\(diaperCount)", unit: L10n.t("片", ""),
                 lines: diaperLines)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// "12时41分" / "24分" — compact whole hours & minutes so sublines never wrap mid-unit.
    private func hoursValue(_ s: Double) -> String {
        let m = Int((max(0, s) / 60).rounded())
        let h = m / 60, r = m % 60
        if h == 0 { return L10n.t("\(r)分", "\(r)m") }
        if r == 0 { return L10n.t("\(h)小时", "\(h)h") }
        return L10n.t("\(h)时\(r)分", "\(h)h \(r)m")
    }

    @ViewBuilder
    private func tile(filterKey: String, color c: Color, symbol: String, title: String, value: String, unit: String, lines: [String]) -> some View {
        let isSelected = (selectedFilter == filterKey)
        let tintInk = dark ? c.mix(with: .white, by: 0.25) : Crayon.ink(c)
        let card = VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Label(title, systemImage: symbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tintInk)
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                if isSelected {
                    Spacer(minLength: 2)
                    Circle()
                        .fill(tintInk)
                        .frame(width: 6, height: 6)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(Typeface.numerals(20, relativeTo: .title3, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            Spacer(minLength: 2)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(lines.prefix(2).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(type.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(0.86)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 108, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .fill(c.opacity(isSelected ? (dark ? 0.28 : 0.22) : (dark ? 0.18 : 0.13)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .strokeBorder(isSelected ? tintInk : c.opacity(dark ? 0.30 : 0.22), lineWidth: isSelected ? 1.6 : 0.6)
        )

        if let onSelectFilter {
            Button {
                onSelectFilter(filterKey)
            } label: {
                card
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            card
        }
    }
}
