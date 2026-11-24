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

    init(path: Binding<NavigationPath>, initialDay: Day? = nil, initialLedgerExpanded: Bool = false) {
        _path = path
        _selectedDay = State(initialValue: initialDay ?? .today)
        _ledgerExpanded = State(initialValue: initialLedgerExpanded)
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
        }
    }

    private var pastNoon: Date {
        Day.cal.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDay.date)
            ?? selectedDay.date.addingTimeInterval(12 * 3600)
    }

    private func defaultTimeForSelectedDay() -> Double {
        selectedDay == app.today ? JournalFile.now() : ms(pastNoon)
    }

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

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ottoLampHeroCard(dark: dark)

                if app.journal && !j.timers.isEmpty {
                    ForEach(j.timers, id: \.type) { t in
                        RunningRow(timer: t)
                    }
                }

                if app.journal {
                    rhythmCollectionCard(
                        day: activeDay,
                        isToday: isToday,
                        dayLogs: dayLogs,
                        feedCount: feedCount,
                        sleepSec: sleepSec,
                        diaperCount: diaperCount,
                        dark: dark
                    )

                    quietCareStrip(day: activeDay, isToday: isToday, dark: dark)

                    todayLedgerDrawer(
                        day: activeDay,
                        dayLogs: dayLogs,
                        entryCount: entryCount,
                        dark: dark
                    )
                } else {
                    enableJournalInvitation(dark: dark)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 32)
        }
        .calmWhileScrolling()
        .pageBackground(tone: night || dark ? Palette.amber : Crayon.caramel)
        .navigationTitle(L10n.t("台灯", "Lamp"))
        .toolbar {
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
            HandoverSheet(day: activeDay).lampPresented(sheet: true)
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
            .lampPresented()
        }
        .sheet(item: Binding(get: { j.ask.map { LampAskWrap(id: $0) } }, set: { j.ask = $0?.id })) { w in
            AskSheet(type: w.id, on: isToday ? nil : pastNoon).lampPresented()
        }
        .sheet(item: $editing) { e in
            EntrySheet(entry: e, isNew: !j.logs.contains { $0.id == e.id }, feed: j.feedEntries(containing: e.id)).lampPresented()
        }
        .onChange(of: app.today) { _, t in selectedDay = t }
        .onChange(of: j.jumpToToday) { _, _ in selectedDay = app.today }
        .onChange(of: router?.expandLampLedgerToken ?? 0) { _, _ in
            withAnimation(reduce ? nil : CalmMotion.accordionSpring) {
                ledgerExpanded = true
            }
        }
    }

    // MARK: - Section 1: Hero Otto Bedside Lamp Stage

    private func ottoLampHeroCard(dark: Bool) -> some View {
        let midnight = app.journal ? MidnightCareSummary.build(logs: j.logs, timers: j.timers, now: Date()) : nil
        let brightness = max(0.15, min(1.0, app.lampBrightness))
        let surfaceTop = Color(hex: 0x161E3B)
        let surfaceBottom = Color(hex: 0x0D1328)
        let playing = soundscape.isPlaying

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ottoLivingStage(brightness: brightness, playing: playing)
                    .frame(width: 82, height: 82)
                    .contentShape(Circle())
                    .onTapGesture {
                        openBedsideLamp()
                    }
                    .accessibilityLabel(L10n.t("轻点打开 Otto 全屏床头夜灯", "Tap to open fullscreen Otto Bedside Lamp"))

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t("Otto 的夜灯与助眠声景", "Otto's Bedside Lamp"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Palette.lampInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(
                        midnight?.nightStatusLine
                            ?? soundscape.activeSummary
                            ?? L10n.t("柔暖滤光 · 六组纯离线声景护耳播放", "Warm melatonin-friendly glow · 6 offline soundscapes")
                    )
                    .font(.caption)
                    .foregroundStyle(Palette.lampInk.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Button {
                            openBedsideLamp()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "lamp.desk.fill")
                                    .font(.caption.weight(.bold))
                                Text(L10n.t("全屏夜灯", "Open Lamp"))
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(warmth.onPrimaryInk)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(warmth.primaryGlow))
                        }
                        .buttonStyle(.toy)

                        if playing {
                            Button {
                                TactileEngine.shared.beadClick()
                                soundscape.stop()
                            } label: {
                                Label(L10n.t("暂停声景", "Pause"), systemImage: "pause.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Palette.lampInk)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.white.opacity(0.14)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }

            // Shared brightness & warmth tint controls synced directly with AppModel & BedsideLampView
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "sun.min.fill")
                        .font(.caption.weight(.bold))
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
                        .font(Typeface.numerals(12, relativeTo: .caption, weight: .bold))
                        .foregroundStyle(Palette.lampInk.opacity(0.84))
                        .frame(width: 38, alignment: .trailing)
                }

                FlowRow(spacing: 8, lineSpacing: 6) {
                    ForEach(LampWarmth.allCases) { preset in
                        let on = warmth == preset
                        Button {
                            TactileEngine.shared.beadClick()
                            app.lampWarmthRaw = preset.rawValue
                        } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(preset.primaryGlow)
                                    .frame(width: 9, height: 9)
                                Text(preset.label)
                                    .font(.caption2.weight(on ? .bold : .semibold))
                            }
                            .foregroundStyle(on ? preset.onPrimaryInk : Palette.lampInk.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(on ? preset.primaryGlow : Color.white.opacity(0.10)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }

            Divider().overlay(Color.white.opacity(0.12))

            // Zero-horizontal-scroll 6 soundscape quick triggers
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t("轻触声景伴随哄睡", "Bedside Soundscapes"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Palette.lampInk.opacity(0.72))

                FlowRow(spacing: 7, lineSpacing: 7) {
                    ForEach(SoundscapeKind.allCases) { kind in
                        let isPrimary = soundscape.active == kind
                        let isSecondary = soundscape.secondary == kind
                        let active = isPrimary || isSecondary
                        Button {
                            TactileEngine.shared.beadClick()
                            soundscape.toggle(kind)
                        } label: {
                            HStack(spacing: 5) {
                                if active {
                                    Circle()
                                        .fill(kind.tint)
                                        .frame(width: 5, height: 5)
                                }
                                Image(systemName: kind.symbol)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(active ? kind.tint.mix(with: .white, by: 0.35) : Palette.lampInk.opacity(0.86))
                                Text(kind.title)
                                    .font(.caption.weight(active ? .bold : .medium))
                                    .foregroundStyle(Palette.lampInk.opacity(active ? 1.0 : 0.88))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(active ? kind.tint.opacity(0.28) : Color.white.opacity(0.10)))
                            .overlay(
                                Capsule()
                                    .strokeBorder(active ? kind.tint.opacity(0.85) : Color.white.opacity(0.10), lineWidth: active ? 1.2 : 0.6)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(active ? .isSelected : [])
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(LinearGradient(colors: [surfaceTop, surfaceBottom], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(warmth.primaryGlow.opacity(0.28), lineWidth: 1.0)
        )
        .shadow(color: Color.black.opacity(dark ? 0.34 : 0.16), radius: 12, y: 5)
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
                .frame(width: 96, height: 96)

            if playing {
                Circle()
                    .strokeBorder(warmth.primaryGlow.opacity(0.32 * (1.0 - 0.45 * wave)), lineWidth: 1.1)
                    .frame(width: 78, height: 78)
                    .scaleEffect(ringScale)
            }

            StoryTheaterActorView(
                kind: .otto,
                size: 72,
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
            HStack(alignment: .center, spacing: 10) {
                MiniRhythmDialCanvas(sleepSlices: sleepSlices, feedFractions: feedFracs, dark: dark)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isToday ? L10n.t("今日节律可视化", "Today's Rhythm") : L10n.t("\(dayLabel) · 节律可视化", "\(dayLabel) Rhythm"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(
                        L10n.t(
                            "睡 \(durationValue(sleepSec)) · 喂 \(feedCount) 次 · 护 \(diaperCount) 次",
                            "Sleep \(durationValue(sleepSec)) · \(feedCount) feeds · \(diaperCount) diapers"
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(2)
                }
                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    Button {
                        if canStepBack { moveDay(to: prevDay) }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption2.weight(.bold))
                            .frame(width: 26, height: 26)
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
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Palette.accentFill))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            if canStepForward { moveDay(to: nextDay) }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(Palette.fill))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canStepForward)
                        .opacity(canStepForward ? 1 : 0.35)
                        .accessibilityLabel(L10n.t("后一天", "Next day"))
                    }
                }
            }

            DaySwimlaneCanvas(day: day, logs: dayLogs, timers: isToday ? j.timers : [], dark: dark)
                .allowsHitTesting(false)

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
        .padding(14)
        .printCard(radius: Radius.card)
    }

    @ViewBuilder
    private func rhythmNavControls(baby: Int, dark: Bool) -> some View {
        NavigationLink(value: LampRoute.rhythm(baby)) {
            compactNavPill(symbol: "clock.arrow.circlepath", text: L10n.t("24h 节律盘", "Rhythm Dial"), color: Crayon.lilac, dark: dark)
        }
        .buttonStyle(.toy)

        NavigationLink(value: LampRoute.stats) {
            compactNavPill(symbol: "chart.bar.fill", text: L10n.t("七日对比", "7-Day Stats"), color: Crayon.sky, dark: dark)
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
                .font(.caption2.weight(.bold))
                .foregroundStyle(dark ? color : Crayon.ink(color))
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(type.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: type.isAccessibilitySize)
            if type.isAccessibilitySize {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 34)
        .padding(.horizontal, type.isAccessibilitySize ? 12 : 8)
        .padding(.vertical, type.isAccessibilitySize ? 6 : 0)
        .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(color.opacity(dark ? 0.16 : 0.11)))
    }

    // MARK: - Section 3: Low-Priority Quiet Care Strip & Collapsible Ledger

    private func quietCareStrip(day: Day, isToday: Bool, dark: Bool) -> some View {
        let primaryTypes = [LogType.nurse, LogType.bottle, LogType.sleep, LogType.diaper]
        let extraTypes = LogType.buttons.filter { !primaryTypes.contains($0) && $0 != LogType.growth }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isToday ? L10n.t("随手轻记", "Quiet Log") : L10n.t("补记 \(day.md)", "Log to \(day.md)"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.secondaryText)
                Spacer()
                Menu {
                    ForEach(extraTypes, id: \.self) { t in
                        Button(LogType.name(t), systemImage: LogType.symbol(t)) {
                            handleTap(t, day: day, isToday: isToday)
                        }
                    }
                } label: {
                    Label(L10n.t("更多照护", "More"), systemImage: "plus.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                }
            }

            let cols = type.isAccessibilitySize
                ? [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
                : Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(primaryTypes, id: \.self) { t in
                    let col = LogType.color(t)
                    Button {
                        TactileEngine.shared.beadClick()
                        handleTap(t, day: day, isToday: isToday)
                    } label: {
                        VStack(spacing: 4) {
                            IconTile(symbol: LogType.symbol(t), color: col, size: 28, round: true)
                            Text(LogType.name(t))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(col.opacity(dark ? 0.14 : 0.09)))
                    }
                    .buttonStyle(.toy)
                }
            }
        }
        .padding(14)
        .printCard(radius: Radius.card)
    }

    private func todayLedgerDrawer(day: Day, dayLogs: [LogEntry], entryCount: Int, dark: Bool) -> some View {
        let isToday = day == app.today
        return VStack(spacing: 0) {
            CalmAccordion(isExpanded: $ledgerExpanded, spacing: 10) { open in
                HStack(spacing: 10) {
                    IconTile(symbol: "list.bullet.clipboard.fill", color: Crayon.caramel, size: 28, round: true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(isToday ? L10n.t("今日明细手账", "Today's Entries") : L10n.t("\(day.md) 明细手账", "\(day.md) Entries"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                        Text(entryCount == 0
                             ? L10n.t("这一天尚无条目，轻点展开或补记", "No entries yet for this day")
                             : L10n.t("共 \(entryCount) 条，平时折叠保持画面清爽", "\(entryCount) entries · collapsed for calm"))
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryText)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
            } content: {
                VStack(alignment: .leading, spacing: 10) {
                    if !dayLogs.isEmpty {
                        DayChapterLedger(
                            day: day,
                            today: app.today,
                            logs: dayLogs,
                            only: nil,
                            expandedPeriods: $expandedPeriods,
                            touchedPeriods: $touchedPeriods,
                            expandAll: $expandAllChapters,
                            edit: { editing = $0 },
                            delete: { j.delete($0) }
                        )
                    }

                    HStack(spacing: 8) {
                        Button {
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
            .padding(14)
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
        .padding(14)
        .printCard(radius: Radius.card)
    }

    private func handleTap(_ t: String, day: Day, isToday: Bool) {
        if isToday && LogType.timed.contains(t) {
            j.focus = t
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
