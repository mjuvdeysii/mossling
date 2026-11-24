import SwiftUI

/// Tab 2: Otto's Bedside Lamp & Calm Rhythm Sanctuary.
/// Places Otto's interactive warm light & soundscapes front and center, backed by a calm visual circadian overview
/// (`MiniRhythmDialCanvas` + read-only `DaySwimlaneCanvas` + Care Handover) and a quiet, collapsible daily log drawer.
struct LampHubView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.night) private var night
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.dynamicTypeSize) private var type

    @Binding var path: NavigationPath

    @State private var soundscape = SoundscapeEngine.shared
    @State private var showingBedsideLamp = false
    @State private var showingHandover = false
    @State private var ledgerExpanded = false
    @State private var expandedPeriods: Set<DayPeriod> = []
    @State private var touchedPeriods = false
    @State private var expandAllChapters = false
    @State private var editing: LogEntry?
    @State private var newFirst: First?
    @State private var measuring: Measure?

    private var warmth: LampWarmth {
        LampWarmth(rawValue: app.lampWarmthRaw) ?? .amber
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        let today = app.today
        let dayLogs = j.logs(on: today)
        let own = dayLogs.filter { !$0.carriedOver(into: today) }
        let startMs = today.date.timeIntervalSince1970 * 1000
        let feedCount = dayLogs.feedCount(from: startMs)
        let sleepSec = dayLogs.filter { $0.type == LogType.sleep }.reduce(0.0) { $0 + $1.seconds(on: today) }
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
                        today: today,
                        dayLogs: dayLogs,
                        feedCount: feedCount,
                        sleepSec: sleepSec,
                        diaperCount: diaperCount,
                        dark: dark
                    )

                    quietCareStrip(dark: dark)

                    todayLedgerDrawer(
                        today: today,
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
                        showingHandover = true
                    } label: {
                        Image(systemName: "person.2.wave.2")
                    }
                    .accessibilityLabel(L10n.t("打开家庭交接卡", "Open Care Handover Card"))

                    NavigationLink(value: Route.fullJournal) {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel(L10n.t("完整多日手账", "Full Multi-Day Journal"))
                }
            }
        }
        .fullScreenCover(isPresented: $showingBedsideLamp) { BedsideLampView() }
        .sheet(isPresented: $showingHandover) {
            HandoverSheet(day: app.today).lampPresented(sheet: true)
        }
        .sheet(item: Binding(get: { j.ask.map { LampAskWrap(id: $0) } }, set: { j.ask = $0?.id })) { w in
            AskSheet(type: w.id, on: nil).lampPresented()
        }
        .sheet(item: $editing) { e in
            EntrySheet(entry: e, isNew: !j.logs.contains { $0.id == e.id }, feed: j.feedEntries(containing: e.id)).lampPresented()
        }
        .sheet(item: $newFirst) { f in FirstSheet(first: f, isNew: true).lampPresented() }
        .sheet(item: $measuring) { m in MeasureSheet(measure: m, isNew: !j.measures.contains { $0.id == m.id }).lampPresented() }
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
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    warmth.primaryGlow.opacity(0.28 + brightness * 0.42),
                                    warmth.secondaryTint.opacity(0.14),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 4,
                                endRadius: 50
                            )
                        )
                        .frame(width: 96, height: 96)

                    StoryTheaterActorView(
                        kind: .otto,
                        size: 72,
                        mood: playing ? .happy : .open,
                        look: CGPoint(x: 0.28, y: 0.08),
                        lid: 0.36,
                        lean: playing ? 2.5 : 0,
                        breathTime: 0,
                        isStatic: true,
                        dark: true,
                        flat: ArtStyle.current == .flat,
                        compact: false
                    )
                }
                .frame(width: 82, height: 82)
                .contentShape(Circle())
                .onTapGesture {
                    TactileEngine.shared.vinylPop()
                    showingBedsideLamp = true
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
                            TactileEngine.shared.beadClick()
                            showingBedsideLamp = true
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
                                Image(systemName: kind.symbol)
                                    .font(.caption2.weight(.bold))
                                Text(kind.title)
                                    .font(.caption.weight(active ? .bold : .medium))
                            }
                            .foregroundStyle(active ? warmth.onPrimaryInk : Palette.lampInk.opacity(0.90))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(active ? kind.tint : Color.white.opacity(0.10)))
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
    }

    // MARK: - Section 2: Visual Rhythm Collection

    private func rhythmCollectionCard(
        today: Day,
        dayLogs: [LogEntry],
        feedCount: Int,
        sleepSec: Double,
        diaperCount: Int,
        dark: Bool
    ) -> some View {
        let baby = max(0, min(app.babyMonth ?? 0, 36))
        let sleepSlices = AtelierDockMetrics.sleepSlices(in: dayLogs, on: today)
        let feedFracs = AtelierDockMetrics.feedFractions(in: dayLogs, on: today)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                NavigationLink(value: Route.rhythm(baby)) {
                    HStack(spacing: 10) {
                        MiniRhythmDialCanvas(sleepSlices: sleepSlices, feedFractions: feedFracs, dark: dark)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("今日节律可视化", "Today's Rhythm"))
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
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            DaySwimlaneCanvas(day: today, logs: dayLogs, timers: j.timers, dark: dark)
                .allowsHitTesting(false)

            HStack(spacing: 8) {
                NavigationLink(value: Route.rhythm(baby)) {
                    compactNavPill(symbol: "clock.arrow.circlepath", text: L10n.t("24h 节律盘", "Rhythm Dial"), color: Crayon.lilac, dark: dark)
                }
                .buttonStyle(.toy)

                NavigationLink(value: JournalRoute.stats) {
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
        }
        .padding(14)
        .printCard(radius: Radius.card)
    }

    private func compactNavPill(symbol: String, text: String, color: Color, dark: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.caption2.weight(.bold))
                .foregroundStyle(dark ? color : Crayon.ink(color))
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, minHeight: 34)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(color.opacity(dark ? 0.16 : 0.11)))
    }

    // MARK: - Section 3: Low-Priority Quiet Care Strip & Collapsible Ledger

    private func quietCareStrip(dark: Bool) -> some View {
        let primaryTypes = [LogType.nurse, LogType.bottle, LogType.sleep, LogType.diaper]
        let extraTypes = LogType.buttons.filter { !primaryTypes.contains($0) }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.t("随手轻记", "Quiet Log"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.secondaryText)
                Spacer()
                Menu {
                    ForEach(extraTypes, id: \.self) { t in
                        Button(LogType.name(t), systemImage: LogType.symbol(t)) {
                            handleTap(t)
                        }
                    }
                    Divider()
                    Button(L10n.t("记一个第一次", "Log a first"), systemImage: "star") {
                        newFirst = First(at: ms(Date()), title: "")
                    }
                    Button(L10n.t("记一次测量", "Log measurement"), systemImage: "ruler") {
                        measuring = Measure(at: Date().timeIntervalSince1970 * 1000)
                    }
                } label: {
                    Label(L10n.t("更多", "More"), systemImage: "plus.circle")
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
                        handleTap(t)
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

    private func todayLedgerDrawer(today: Day, dayLogs: [LogEntry], entryCount: Int, dark: Bool) -> some View {
        VStack(spacing: 0) {
            CalmAccordion(isExpanded: $ledgerExpanded, spacing: 10) { open in
                HStack(spacing: 10) {
                    IconTile(symbol: "list.bullet.clipboard.fill", color: Crayon.caramel, size: 28, round: true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.t("今日明细手账", "Today's Entries"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                        Text(entryCount == 0
                             ? L10n.t("今日尚无条目，轻点展开或前往多日记录", "No entries yet today")
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
                            day: today,
                            today: today,
                            logs: dayLogs,
                            only: nil,
                            expandedPeriods: $expandedPeriods,
                            touchedPeriods: $touchedPeriods,
                            expandAll: $expandAllChapters,
                            edit: { editing = $0 },
                            delete: { j.delete($0) }
                        )
                    }

                    NavigationLink(value: Route.fullJournal) {
                        HStack {
                            Text(L10n.t("查看多日完整手账与补记", "Open Full Multi-Day Journal"))
                                .font(.footnote.weight(.bold))
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(Palette.accent.opacity(dark ? 0.16 : 0.09)))
                    }
                    .buttonStyle(.toy)
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

    private func handleTap(_ t: String) {
        if t == LogType.growth {
            measuring = Measure(at: Date().timeIntervalSince1970 * 1000)
            return
        }
        if LogType.timed.contains(t) {
            j.focus = t
            return
        }
        if t == LogType.bath {
            _ = j.record(LogEntry(type: t, start: JournalFile.now()))
            return
        }
        j.ask = t
    }
}

private struct LampAskWrap: Identifiable { let id: String }
