import SwiftUI
import TipKit

/// The journal (optional): what is running, one-tap buttons, the week, then the day — its totals, its time line and
/// every entry in order.
struct JournalView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Binding var path: NavigationPath
    @State private var day: Day = .today
    @State private var dayDirection: CGFloat = 1
    @State private var only: String?
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var leftAt: Date?
    @State private var pickingDay = false
    @State private var opened = false
    @State private var editing: LogEntry?
    @State private var measuring: Measure?
    @State private var newFirst: First?
    @State private var showingLamp = false
    @State private var showingHandover = false
    @State private var soundscape = SoundscapeEngine.shared
    @State private var activeQuickTray: String? = nil
    @State private var quickTrayMilk: String = "formula"
    @State private var showSecondaryStickers = false
    @State private var showPastStickers = false
    @State private var expandedPeriods: Set<DayPeriod> = []
    @State private var touchedPeriods = false
    @State private var expandAllChapters = false
    @Environment(\.dynamicTypeSize) private var size

    init(path: Binding<NavigationPath>, only: String? = nil, initialDay: Day? = nil, initialQuickTray: String? = nil) {
        _path = path
        _only = State(initialValue: only)
        if let initialDay {
            _day = State(initialValue: initialDay)
            _opened = State(initialValue: true)
        }
        _activeQuickTray = State(initialValue: initialQuickTray)
    }

    private func move(to next: Day) {
        guard next != day else { return }
        dayDirection = next.epochDay > day.epochDay ? 1 : -1
        TactileEngine.shared.pageTurn()
        withAnimation(reduce ? nil : .spring(response: 0.36, dampingFraction: 0.86)) {
            day = next
            showPastStickers = false
            activeQuickTray = nil
            expandedPeriods = []
            touchedPeriods = false
            expandAllChapters = false
        }
    }

    var body: some View {
        let dayLogs = j.logs(on: day)
        let lastBottle = j.logs.first { $0.type == LogType.bottle }
        let defaultMilk = lastBottle.flatMap { ["breastmilk", "formula"].contains($0.detail ?? "") ? $0.detail : nil } ?? "formula"

        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TipView(StickerTip())
                    // what is running comes first on the page, above the stickers — at night it is what is looked for
                    ForEach(j.timers, id: \.type) { t in RunningRow(timer: t) }
                    QuickLogDock(
                        isToday: day == app.today,
                        day: day,
                        entryCount: dayLogs.rows().count,
                        timers: j.timers,
                        month: app.babyMonth,
                        last: { j.last($0) },
                        lastBottleMl: lastBottle?.amount,
                        activeQuickTray: $activeQuickTray,
                        quickTrayMilk: $quickTrayMilk,
                        showSecondary: $showSecondaryStickers,
                        showPastStickers: $showPastStickers,
                        jumpToToday: { move(to: app.today) },
                        tap: tap,
                        quickDiaper: { kind in
                            let t = day == app.today ? JournalFile.now() : ms(pastNoon)
                            if j.record(LogEntry(type: LogType.diaper, start: t, detail: kind)) {
                                TactileEngine.shared.beadClick()
                                withAnimation(reduce ? nil : .snappy) { activeQuickTray = nil }
                            }
                        },
                        quickBottle: { ml, milk in
                            let t = day == app.today ? JournalFile.now() : ms(pastNoon)
                            if j.record(LogEntry(type: LogType.bottle, start: t, amount: ml, detail: milk)) {
                                TactileEngine.shared.beadClick()
                                withAnimation(reduce ? nil : .snappy) { activeQuickTray = nil }
                            }
                        },
                        openDetailed: { type in
                            withAnimation(reduce ? nil : .snappy) { activeQuickTray = nil }
                            j.ask = type
                        }
                    )
                    WeekStrip(today: app.today, day: day, pick: move(to:))
                    // any day: tap its date for a calendar, or swipe the page sideways for the day before or after
                    ZStack {
                        DayPage(
                            day: day,
                            today: app.today,
                            logs: dayLogs,
                            timers: j.timers,
                            only: $only,
                            expandedPeriods: $expandedPeriods,
                            touchedPeriods: $touchedPeriods,
                            expandAllChapters: $expandAllChapters,
                            edit: { editing = $0 },
                            delete: { j.delete($0) },
                            pick: { pickingDay = true },
                            jumpToPeriod: { period in
                                withAnimation(reduce ? nil : CalmMotion.accordionSpring) {
                                    touchedPeriods = true
                                    expandedPeriods.insert(period)
                                }
                                withAnimation(reduce ? nil : .smooth.delay(0.08)) {
                                    scrollProxy.scrollTo("chapter-\(period.rawValue)", anchor: .top)
                                }
                            }
                        )
                        .id(day.epochDay)
                        .transition(reduce ? .opacity : .asymmetric(
                            insertion: .opacity.combined(with: .offset(x: dayDirection * 22)),
                            removal: .opacity.combined(with: .offset(x: -dayDirection * 22))
                        ))
                    }
                    .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { v in
                        let dx = v.translation.width, dy = v.translation.height
                        guard abs(dx) > 70, abs(dx) > abs(dy) * 2 else { return }
                        let next = day.plus(days: dx < 0 ? 1 : -1)
                        guard next.epochDay <= app.today.epochDay, app.birth.map({ next.epochDay >= $0.epochDay }) ?? true else { return }
                        move(to: next)
                    })
                    let pair = size.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                    pair {
                        NavigationLink(value: JournalRoute.stats) { tile(L10n.t("昼夜节律", "Rhythm & 7d"), "chart.bar.fill", Crayon.lilac) { WeekBars(today: app.today, count: { j.logs(on: $0).rows().count }) } }.buttonStyle(.toy)
                        NavigationLink(value: JournalRoute.growth) { tile(L10n.t("生长曲线", "Growth Curve"), "chart.line.uptrend.xyaxis", Crayon.tangerine) { LastMeasure(m: j.measures.max { $0.at < $1.at }) } }.buttonStyle(.toy)
                    }
                    // the two tiles side by side are one height: top and bottom edges line up
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16).padding(.bottom, 32)
            }
        }
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.pink)
        .sensoryFeedback(.selection, trigger: day)
        .navigationTitle(L10n.t("记录", "Journal"))
        .onAppear {
            if !opened { day = app.today; opened = true }
            quickTrayMilk = defaultMilk
        }
        .toolbar {
            if day != app.today {
                ToolbarItem(placement: .topBarLeading) { Button(L10n.t("今天", "Today")) { move(to: app.today) } }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    TactileEngine.shared.beadClick()
                    showingLamp = true
                } label: {
                    Image(systemName: soundscape.isPlaying ? "lamp.desk.fill" : "lamp.desk")
                        .foregroundStyle(soundscape.isPlaying ? Palette.amber : Palette.lampTint)
                }
                .accessibilityLabel(L10n.t("打开床头夜灯与助眠声景", "Open Bedside Lamp & Soundscapes"))

                Button {
                    TactileEngine.shared.beadClick()
                    showingHandover = true
                } label: {
                    Image(systemName: "person.2.wave.2")
                }
                .accessibilityLabel(L10n.t("打开家庭交接卡", "Open Care Handover Card"))
                // the rarer records live behind +, not on the page: an entry after the fact, a first, a measurement
                Menu {
                    Button(L10n.t("补记一条记录", "Add past entry"), systemImage: "square.and.pencil") { editing = LogEntry(type: LogType.bottle, start: defaultTime(), amount: 120) }
                    Button(L10n.t("记一个第一次", "Log a first"), systemImage: "star") { newFirst = First(at: ms(Date()), title: "") }
                    Button(L10n.t("记一次测量", "Log measurement"), systemImage: "ruler") { measuring = Measure(at: Date().timeIntervalSince1970 * 1000) }
                    Divider()
                    Button(L10n.t("第一次时间线", "Firsts timeline"), systemImage: "point.topleft.down.to.point.bottomright.curvepath") { path.append(JournalRoute.firsts) }
                } label: { Image(systemName: "plus") }
                .accessibilityLabel(L10n.t("补记、第一次、测量", "Add entry, first, or measurement"))
            }
        }
        .fullScreenCover(isPresented: $showingLamp) { BedsideLampView() }
        .sheet(isPresented: $showingHandover) {
            HandoverSheet(day: app.today).lampPresented(sheet: true)
        }
        .sheet(item: Binding(get: { j.ask.map { Wrap(id: $0) } }, set: { j.ask = $0?.id })) { w in AskSheet(type: w.id, on: day == app.today ? nil : pastNoon).lampPresented() }
        .sheet(isPresented: $pickingDay) {
            NavigationStack {
                let now = Date()
                let lower = min(app.birth?.date ?? .distantPast, now)
                DatePicker(L10n.t("哪一天", "Date"), selection: Binding(get: { min(max(day.date, lower), now) }, set: { move(to: Day($0)); pickingDay = false }),
                           in: lower...now, displayedComponents: .date)
                    .datePickerStyle(.graphical).padding(.horizontal, 16)
                    .navigationTitle(L10n.t("看哪一天", "Choose Day")).navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.t("取消", "Cancel"), systemImage: "xmark") { pickingDay = false } } }
            }
            .presentationDetents([.medium]).lampPresented()
        }
        // a side of a two-sided feed opens the whole feed (that side chosen)
        .sheet(item: $editing) { e in
            EntrySheet(entry: e, isNew: !j.logs.contains { $0.id == e.id },
                       feed: j.feedEntries(containing: e.id)).lampPresented()
        }
        .sheet(item: $newFirst) { f in FirstSheet(first: f, isNew: true).lampPresented() }
        .sheet(item: $measuring) { m in MeasureSheet(measure: m, isNew: !j.measures.contains { $0.id == m.id }).lampPresented() }
        // the day chosen stays chosen across the stats, the growth curve and the other tabs; it goes back to today
        // when the date turns, when a widget deep link asks to log today, or when the app comes back after a while away
        .onChange(of: app.today) { _, t in day = t }
        .onChange(of: j.jumpToToday) { _, _ in day = app.today }
        .onChange(of: phase) { _, p in
            if p == .background { leftAt = Date() }
            if p == .active, let l = leftAt, Date().timeIntervalSince(l) > 1800 { day = app.today; leftAt = nil }
        }
    }

    /// A way into a deeper page that already shows a glimpse of it: the week's bars, the last measurement.
    private func tile<P: View>(_ t: String, _ sym: String, _ c: Color, @ViewBuilder preview: () -> P) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                IconTile(symbol: sym, color: c, size: 34)
                Text(t).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            preview().frame(maxWidth: .infinity, minHeight: 40, alignment: .bottomLeading)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(14)
        .background(LinearGradient(colors: [c.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom))
        .printCard(radius: Radius.card)
    }

    private func tap(_ t: String) {
        if t == LogType.growth { measuring = Measure(at: Date().timeIntervalSince1970 * 1000); return }
        // a feed or a sleep has its own page: it opens, and starts only from there
        if LogType.timed.contains(t) { j.focus = t; return }
        // a bath is one tap: recorded now (or at noon of the past day on the page), said back with 撤销
        if t == LogType.bath { j.record(LogEntry(type: t, start: day == app.today ? JournalFile.now() : ms(pastNoon))); return }
        j.ask = t
    }
    /// Noon of the day on the page, for a record made while looking at a past day.
    private var pastNoon: Date { Day.cal.date(bySettingHour: 12, minute: 0, second: 0, of: day.date) ?? day.date.addingTimeInterval(12 * 3600) }
    private func defaultTime() -> Double { day == app.today ? JournalFile.now() : pastNoon.timeIntervalSince1970 * 1000 }
}

enum JournalRoute: Hashable { case stats, growth, firsts }

/// Seven small soft bars, one per day ending today: how many things were recorded. Today's bar is the full colour.
private struct WeekBars: View {
    let today: Day
    let count: (Day) -> Int
    var body: some View {
        let days = (0...6).reversed().map { today.plus(days: -$0) }
        let n = days.map(count), top = max(n.max() ?? 0, 1)
        // the bars compare; one line says the numbers: today against the days before it that have records
        let before = n.dropLast().filter { $0 > 0 }
        let mean = before.isEmpty ? nil : Int((Double(before.reduce(0, +)) / Double(before.count)).rounded())
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                    VStack(spacing: 3) {
                        Capsule().fill(i == 6 ? Crayon.lilac : Crayon.lilac.opacity(0.35))
                            .frame(height: max(5, 26 * CGFloat(n[i]) / CGFloat(top)))
                        Text(d.weekdayInitial).font(.caption2.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text(L10n.isEnglish
                 ? "Today \(n[6])" + (mean.map { " · Avg \($0)/d" } ?? "")
                 : "今天 \(n[6]) 条" + (mean.map { " · 日均 \($0) 条" } ?? ""))
                .font(.caption2).foregroundStyle(Palette.secondaryText).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .accessibilityElement().accessibilityLabel(L10n.isEnglish
            ? "Last 7 days: \(n.reduce(0, +)) entries, today \(n[6])" + (mean.map { ", daily average \($0)" } ?? "")
            : "最近七天共记录 \(n.reduce(0, +)) 条，今天 \(n[6]) 条" + (mean.map { "，日均 \($0) 条" } ?? ""))
    }
}

/// The last measurement, or a line saying there is none yet.
private struct LastMeasure: View {
    let m: Measure?
    var body: some View {
        if let m, m.weightG != nil || m.lengthMm != nil || m.headMm != nil {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    if let w = m.weightG {
                        Text(String(format: "%.2f", Double(w) / 1000)).font(Typeface.numerals(22, relativeTo: .title3, weight: .bold)).foregroundStyle(Crayon.ink(Crayon.tangerine))
                        Text(L10n.t("千克", "kg")).font(.caption.weight(.semibold))
                        if let l = m.lengthMm { Text("· " + String(format: "%.1f", Double(l) / 10) + L10n.t(" 厘米", " cm")).font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText).padding(.leading, 2) }
                    } else if let l = m.lengthMm {
                        Text(String(format: "%.1f", Double(l) / 10)).font(Typeface.numerals(22, relativeTo: .title3, weight: .bold)).foregroundStyle(Crayon.ink(Crayon.tangerine))
                        Text(L10n.t("厘米 · 身长", "cm · Length")).font(.caption.weight(.semibold))
                    } else if let h = m.headMm {
                        Text(String(format: "%.1f", Double(h) / 10)).font(Typeface.numerals(22, relativeTo: .title3, weight: .bold)).foregroundStyle(Crayon.ink(Crayon.tangerine))
                        Text(L10n.t("厘米 · 头围", "cm · Head")).font(.caption.weight(.semibold))
                    }
                }
                .lineLimit(1).minimumScaleFactor(0.8)
                let d = Date(timeIntervalSince1970: m.at / 1000)
                Text(L10n.t("最近一次 ", "Latest ") + Day(d).md).font(.caption2).foregroundStyle(Palette.secondaryText)
            }
        } else {
            Text(L10n.t("还没有量过，点进去记下第一次", "No measurements yet — tap to log")).font(.caption).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
        }
    }
}
struct Wrap: Identifiable { let id: String }


/// Context-aware quick log dock:
/// - When viewing history: collapses into a serene 1-line summary + Back to Today pill, giving 90% of the screen to review.
/// - When viewing Today: primary stickers with 0.6s inline Diaper & Smart-Bottle trays, plus a quiet expandable secondary tray.
private struct QuickLogDock: View {
    let isToday: Bool
    let day: Day
    let entryCount: Int
    let timers: [RunningTimer]
    let month: Int?
    let last: (String) -> Date?
    let lastBottleMl: Int?
    @Binding var activeQuickTray: String?
    @Binding var quickTrayMilk: String
    @Binding var showSecondary: Bool
    @Binding var showPastStickers: Bool
    let jumpToToday: () -> Void
    let tap: (String) -> Void
    let quickDiaper: (String) -> Void
    let quickBottle: (Int, String) -> Void
    let openDetailed: (String) -> Void

    @Environment(\.dynamicTypeSize) private var size
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.lamp) private var lamp

    @ViewBuilder private func row<C: View>(_ spacing: CGFloat, @ViewBuilder _ content: () -> C) -> some View {
        if size.isAccessibilitySize {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4, alignment: .top), count: 3), spacing: 10, content: content)
        } else {
            HStack(alignment: .top, spacing: spacing, content: content)
        }
    }

    var body: some View {
        let eating = (month ?? 0) >= 6
        let often = [LogType.nurse, LogType.bottle, LogType.sleep, LogType.diaper] + (eating ? [LogType.solid] : [])
        let rarely = LogType.buttons.filter { !often.contains($0) }

        if !isToday && !showPastStickers {
            // Historical review mode: 1 compact contextual strip (reclaims ~165pt for reading logs)
            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.accent)
                Text(L10n.isEnglish ? "Reviewing \(day.md) · \(entryCount)" : "正在回看 \(day.md) · \(entryCount) 条")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Button {
                    TactileEngine.shared.beadClick()
                    withAnimation(reduce ? nil : .snappy) { showPastStickers = true }
                } label: {
                    Label(L10n.t("补记", "Add"), systemImage: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Palette.accent.opacity(0.12)))
                }
                .buttonStyle(.plain)

                Button(action: jumpToToday) {
                    Text(L10n.t("回今天", "Today"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Palette.accentFill))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .printCard(radius: Radius.card)
        } else {
            TimelineView(.periodic(from: .now, by: 60)) { tl in
                VStack(spacing: 10) {
                    if !isToday {
                        HStack {
                            Text(L10n.t("补记到 \(day.md)", "Log to \(day.md)"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Palette.accent)
                            Spacer()
                            Button {
                                withAnimation(reduce ? nil : .snappy) {
                                    showPastStickers = false
                                    activeQuickTray = nil
                                }
                            } label: {
                                Label(L10n.t("收起", "Hide"), systemImage: "chevron.up")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Palette.secondaryText)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6)
                    }

                    row(4) {
                        ForEach(often, id: \.self) { t in
                            let run = timers.first { $0.type == t }
                            let isTrayOpen = activeQuickTray == t
                            Sticker(
                                type: t,
                                running: run != nil,
                                selected: isTrayOpen,
                                paused: run?.pausedAt != nil,
                                since: run.map { L10n.duration($0.total(tl.date.timeIntervalSince1970 * 1000)) } ?? last(t).map { L10n.agoText($0, now: tl.date) },
                                size: often.count > 4 ? 50 : 54
                            ) {
                                if t == LogType.diaper || t == LogType.bottle {
                                    TactileEngine.shared.beadClick()
                                    withAnimation(reduce ? nil : CalmMotion.accordionSpring) {
                                        activeQuickTray = (activeQuickTray == t) ? nil : t
                                    }
                                } else {
                                    activeQuickTray = nil
                                    tap(t)
                                }
                            }
                        }
                    }

                    // 0.6s inline Diaper quick-save tray
                    if activeQuickTray == LogType.diaper {
                        inlineDiaperTray
                    } else if activeQuickTray == LogType.bottle {
                        inlineBottleTray
                    }

                    Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 1).padding(.horizontal, 6)

                    if showSecondary {
                        VStack(spacing: 8) {
                            row(2) {
                                ForEach(rarely, id: \.self) { t in
                                    SmallSticker(type: t) {
                                        withAnimation(reduce ? nil : CalmMotion.accordionSpring) { showSecondary = false }
                                        tap(t)
                                    }
                                }
                            }
                            Button {
                                TactileEngine.shared.beadClick()
                                withAnimation(reduce ? nil : CalmMotion.accordionSpring) { showSecondary = false }
                            } label: {
                                Label(L10n.t("收起更多贴纸", "Collapse More"), systemImage: "chevron.up")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Palette.secondaryText)
                                    .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        }
                        .transition(reduce ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    } else {
                        Button {
                            TactileEngine.shared.beadClick()
                            withAnimation(reduce ? nil : CalmMotion.accordionSpring) { showSecondary = true }
                        } label: {
                            HStack(spacing: 6) {
                                Text(L10n.t("更多记录：", "More:"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Palette.secondaryText)
                                Text(rarely.map { LogType.name($0) }.joined(separator: " · "))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.down")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12).padding(.bottom, 10).padding(.horizontal, 8)
                .clipped()
                .printCard(radius: Radius.card)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .animation(reduce ? nil : CalmMotion.accordionSpring, value: activeQuickTray)
                .animation(reduce ? nil : CalmMotion.accordionSpring, value: showSecondary)
            }
        }
    }

    private var inlineDiaperTray: some View {
        let c = LogType.color(LogType.diaper)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.t("点一下直接记下尿布（当前时间）", "1-tap instant diaper log"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Crayon.ink(c))
                Spacer()
                Button(L10n.t("改时间…", "Time…")) { openDetailed(LogType.diaper) }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.accent)
            }
            FlowRow(spacing: 8, lineSpacing: 8) {
                ForEach([("wet", L10n.t("湿", "Wet")), ("dirty", L10n.t("便", "Dirty")), ("both", L10n.t("都有", "Both"))], id: \.0) { code, label in
                    Button { quickDiaper(code) } label: {
                        Text(label)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Crayon.fill(c, lamp)))
                    }
                    .buttonStyle(.toy)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(c.opacity(lamp ? 0.14 : 0.10)))
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
    }

    private var inlineBottleTray: some View {
        let c = LogType.color(LogType.bottle)
        let suggestions = SmartBottleVolumes.suggestions(lastMl: lastBottleMl)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach([("formula", L10n.t("配方奶", "Formula")), ("breastmilk", L10n.t("母乳", "Breast milk"))], id: \.0) { code, title in
                    let on = quickTrayMilk == code
                    Button {
                        TactileEngine.shared.beadClick()
                        quickTrayMilk = code
                    } label: {
                        Text(title)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(on ? .white : .primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(on ? Palette.accentFill : (lamp ? Palette.lampCard : Palette.card)))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 4)
                Button(L10n.t("刻度与时间…", "Detail…")) { openDetailed(LogType.bottle) }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.accent)
            }
            FlowRow(spacing: 8, lineSpacing: 8) {
                ForEach(suggestions, id: \.self) { ml in
                    Button { quickBottle(ml, quickTrayMilk) } label: {
                        Text("\(ml) ml")
                            .font(Typeface.numerals(14, relativeTo: .subheadline, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Crayon.fill(c, lamp)))
                    }
                    .buttonStyle(.toy)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(c.opacity(lamp ? 0.14 : 0.10)))
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
    }
}

/// A sticker of the second tier: small, named, no time.
private struct SmallSticker: View {
    let type: String
    let action: () -> Void
    @State private var pops = 0
    var body: some View {
        let c = LogType.color(type)
        Button { pops += 1; action() } label: {
            VStack(spacing: 3) {
                IconTile(symbol: LogType.symbol(type), color: c, size: 30, round: true)
                    .phaseAnimator([1.0, 0.86, 1.0], trigger: pops) { v, k in v.scaleEffect(k, anchor: .bottom) } animation: { _ in .snappy(duration: 0.14) }
                Text(L10n.logName(type)).font(.caption2.weight(.semibold)).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.toy)
        .accessibilityLabel(L10n.logName(type))
        .accessibilityHint(type == LogType.bath ? L10n.t("点按即记下一次", "Tap to log") : "")
        .accessibilityShowsLargeContentViewer { Label(L10n.logName(type), systemImage: LogType.symbol(type)) }
    }
}

private struct Sticker: View {
    let type: String, running: Bool
    var selected = false
    var paused = false
    let since: String?
    var size: CGFloat = 48
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var pops = 0
    var body: some View {
        let c = LogType.color(type)
        let on = !reduce
        let name = L10n.logName(type)
        Button { pops += 1; action() } label: {
            VStack(spacing: 4) {
                IconTile(symbol: LogType.symbol(type), color: c, size: size, round: true)
                    .overlay(Circle().stroke(c.opacity(running || selected ? 0.45 : 0), lineWidth: 4).padding(-5))
                    // 3D: the sticker squashes into the page and springs back up, like a soft toy pressed
                    .keyframeAnimator(initialValue: CGFloat(1), trigger: pops) { v, k in
                        v.scaleEffect(x: 2 - k, y: k, anchor: .bottom)
                    } keyframes: { _ in
                        CubicKeyframe(on ? 0.84 : 1, duration: 0.08)
                        SpringKeyframe(on ? 1.08 : 1, duration: 0.16, spring: .snappy)
                        SpringKeyframe(1, duration: 0.3, spring: .bouncy)
                    }
                Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.85)
                Ticking(text: running ? (paused ? L10n.t("已暂停", "Paused") : L10n.t("进行中", "Active")) : since ?? L10n.t("未记", "—"), tint: Crayon.ink(c)).font(.caption2).foregroundStyle(Palette.secondaryText).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.toy)
        .sensoryFeedback(.impact(weight: .light), trigger: running)
        .accessibilityLabel(running ? L10n.t("\(name)进行中，打开计时", "\(name) active, open timer") : name)
        .accessibilityHint(running ? "" : LogType.timed.contains(type) ? L10n.t("打开计时页", "Open timer") : type == LogType.bath ? L10n.t("点按即记下一次", "Tap to log") : "")
        .accessibilityValue(running ? (paused ? L10n.t("已暂停 ", "Paused ") : "") + (since ?? "") : since ?? L10n.t("未记", "None"))
        .accessibilityShowsLargeContentViewer { Label(name, systemImage: LogType.symbol(type)) }
    }
}

/// Seven days, as the tabs along a planner's edge.
private struct WeekStrip: View {
    @Environment(\.lamp) private var lamp
    let today: Day
    let day: Day
    let pick: (Day) -> Void
    private static let enWeekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    var body: some View {
        let end = min(day.plus(days: 3), today)
        strip {
            ForEach((0...6).reversed(), id: \.self) { i in
                let d = end.plus(days: -i), on = d == day, isToday = d == today
                let wdIdx = max(0, min(6, Day.cal.component(.weekday, from: d.date) - 1))
                let wdLabel = L10n.isEnglish ? Self.enWeekdays[wdIdx] : String(d.weekday.suffix(1))
                Button { pick(d) } label: {
                    VStack(spacing: 2) {
                        Text(wdLabel).font(.caption2.weight(.semibold))
                        Text("\(d.d)").font(Typeface.numerals(17, relativeTo: .body, weight: .bold))
                    }
                    .foregroundStyle(on ? Color.white : isToday ? Crayon.ink(Crayon.pink) : Color.primary)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background { if !on { RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(lamp ? Palette.lampCard : Palette.card) } }
                    .vinylSurface(on ? Crayon.fill(Crayon.pink, lamp) : .white, strong: on)
                }
                .buttonStyle(.toy)
                .accessibilityLabel(L10n.isEnglish ? "\(wdLabel) \(d.m)/\(d.d)" : "\(d.md) \(d.weekday)")
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityShowsLargeContentViewer { Text(L10n.isEnglish ? "\(wdLabel) \(d.m)/\(d.d)" : "\(d.md) \(d.weekday)") }
            }
        }
    }
    @Environment(\.dynamicTypeSize) private var typeSize
    /// Seven across at the standard sizes; at the accessibility sizes four to a row, so the days keep their size.
    @ViewBuilder private func strip<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        if typeSize.isAccessibilitySize {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6, content: content)
        } else {
            HStack(spacing: 6, content: content)
        }
    }
}

/// A page of the journal: dotted paper, the date written large, the day's three totals as stamps, the day's strip,
/// and every entry in fixed columns — time, sticker, kind, value — with the details on a second line.
/// The companion beside the day's date: the chosen one, still. After a record is really saved (the IP event
/// record.persist.success) it answers once — a happy face and a hop within its own short time; never after a failed
/// save. Under the lamp it rests (half-closed eyes; Otto's bead glows). Decorative, so hidden from VoiceOver.
private struct DayCompanion: View {
    @Environment(AppModel.self) private var app
    @Environment(MascotDirector.self) private var mascot: MascotDirector?
    let lamp: Bool
    let empty: Bool
    /// The baby is asleep (a sleep is being timed): the companion dozes too, eyes shut, keeping quiet.
    var hush = false
    @State private var answering = false
    @Environment(\.accessibilityReduceMotion) private var reduce
    var body: some View {
        let k = app.companion
        Creature(kind: k, mood: answering ? .happy : hush ? .sleep : .open, look: CGPoint(x: -0.6, y: 0.3),
                 lid: lamp && !answering && !hush ? 0.5 : nil, alive: answering || lamp || hush, glow: lamp && k == .otto && !hush)
            .frame(width: 50, height: 50)
            .accessibilityHidden(true)
            .onChange(of: mascot?.acknowledgements ?? 0) { _, _ in
                guard !reduce else { return }
                answering = true
                Task { try? await Task.sleep(for: .milliseconds(MascotStyle.of(k).acknowledgeMs)); answering = false }
            }
            // the baby wakes: the companion, dozing with him, wakes too — bright for a moment
            .onChange(of: hush) { was, now in
                guard was, !now, !reduce else { return }
                answering = true
                Task { try? await Task.sleep(for: .milliseconds(900)); answering = false }
            }
    }
}

private struct DayPage: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.lamp) private var lamp
    let day: Day, today: Day
    let logs: [LogEntry]
    let timers: [RunningTimer]
    /// One kind to look at alone ("feed" = breast and bottle together), or nil for the whole day.
    @Binding var only: String?
    @Binding var expandedPeriods: Set<DayPeriod>
    @Binding var touchedPeriods: Bool
    @Binding var expandAllChapters: Bool
    let edit: (LogEntry) -> Void
    let delete: (LogEntry) -> Void
    var pick: () -> Void = {}
    var jumpToPeriod: (DayPeriod) -> Void = { _ in }

    var body: some View {
        let shown = only.map { k in logs.filter { JournalKinds.matches($0.type, k) } } ?? logs
        let who = app.nickname.isEmpty ? L10n.t("宝宝", "Baby") : app.nickname
        let ageStr = app.age.map { L10n.ageText($0) } ?? ""
        let dayPoster = RenderedPoster {
            let view = DaySheetPoster(babyName: who, ageText: ageStr, day: day, logs: logs)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3.0
            return renderer.uiImage
        }

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Button(action: pick) {
                    HStack(alignment: .center, spacing: 12) {
                        Text("\(day.d)").font(Typeface.numerals(36, relativeTo: .largeTitle, weight: .bold))
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 4) {
                                Text(L10n.isEnglish ? "\(Day.enMonths[day.m - 1]) · \(day.weekday)" : "\(day.m)月 \(day.weekday)").font(.headline)
                                Image(systemName: "chevron.down").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                            }
                            let diff = today.epochDay - day.epochDay
                            Text(day == today ? L10n.t("今天", "Today")
                                 : diff == 1 ? L10n.t("1 天前", "Yesterday")
                                 : L10n.t("\(diff) 天前", "\(diff) days ago"))
                                .font(.subheadline).foregroundStyle(Palette.secondaryText)
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.toy)
                .accessibilityHint(L10n.t("选另一天", "Choose another day"))
                Spacer()
                if !logs.isEmpty {
                    ShareLink(
                        item: dayPoster,
                        preview: SharePreview(L10n.t("\(who)\(day.md)手账长图", "\(who)'s Day Sheet · \(day.md)"))
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Palette.accent)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Palette.accent.opacity(0.12)))
                    }
                    .buttonStyle(.toy)
                    .accessibilityLabel(L10n.t("导出本日完整一张长图", "Export full-day sheet image"))
                }
                DayCompanion(lamp: lamp, empty: logs.isEmpty, hush: day == today && timers.contains { $0.type == LogType.sleep && $0.pausedAt == nil })
            }
            // every number on the page is a way in: tap a total (or one of the other kinds) to see only that kind
            Totals(logs: logs, day: day, only: only) { k in withAnimation(.snappy) { only = only == k ? nil : k } }
            OtherKinds(logs: logs, only: only) { k in withAnimation(.snappy) { only = only == k ? nil : k } }
            if let k = only { FocusLine(kind: k, logs: shown, all: j.logs, day: day) { withAnimation(.snappy) { only = nil } } }
            DaySwimlaneChart(
                day: day,
                logs: logs,
                timers: timers,
                only: $only,
                onSelectPeriod: jumpToPeriod
            )
            if logs.isEmpty && (day != today || timers.isEmpty) {
                // an empty day: the two dozing beside one line, not a stage of its own
                HStack(spacing: 10) {
                    Duo(primary: app.companion, size: 40, mood: lamp ? .open : .sleep, night: lamp)
                    Text(L10n.t("这一页还空着，点上面的贴纸就能记下", "Nothing logged yet — tap a sticker above")).font(.subheadline).foregroundStyle(Palette.secondaryText)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)
            } else if !logs.isEmpty {
                DayFilterRail(logs: logs, day: day, only: only) { k in
                    TactileEngine.shared.beadClick()
                    withAnimation(.snappy) { only = k }
                }
                DayChapterLedger(
                    day: day,
                    today: today,
                    logs: shown,
                    only: only,
                    expandedPeriods: $expandedPeriods,
                    touchedPeriods: $touchedPeriods,
                    expandAll: $expandAllChapters,
                    edit: edit,
                    delete: delete
                )
            }
        }
        .padding(16)
        .background { DotPaper() }
        .printCard(radius: Radius.card)
        // the chosen kind stays when the day changes: flip through the week and compare feeds day by day
        .sensoryFeedback(.selection, trigger: only)
    }
}

/// The kinds a day can be looked at by: feeds (breast and bottle), sleep, nappies, and each other kind by itself.
enum JournalKinds {
    static func matches(_ type: String, _ key: String) -> Bool {
        key == "feed" ? (type == LogType.nurse || type == LogType.bottle) : type == key
    }
    static func name(_ key: String) -> String { key == "feed" ? L10n.t("喂奶", "Feeds") : LogType.name(key) }
    static func type(_ key: String) -> String { key == "feed" ? LogType.nurse : key }
}

/// Instant one-tap category filter rail above day ledger entries so dense newborn days (30+ rows) scan without clutter.
private struct DayFilterRail: View {
    let logs: [LogEntry]
    let day: Day
    let only: String?
    let pick: (String?) -> Void

    @Environment(\.lamp) private var lamp
    @Environment(\.colorScheme) private var scheme

    private var items: [(key: String, count: Int)] {
        let d0 = day.date.timeIntervalSince1970 * 1000
        var result: [(String, Int)] = []
        let feeds = logs.feedCount(from: d0)
        if feeds > 0 { result.append(("feed", feeds)) }
        let order = [LogType.sleep, LogType.diaper, LogType.solid, LogType.bath, LogType.temp, LogType.medicine, LogType.play, LogType.note]
        for type in order {
            let n = logs.filter { $0.type == type }.count
            if n > 0 { result.append((type, n)) }
        }
        return result
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        let categories = items
        if categories.count >= 2 || only != nil {
            let total = categories.reduce(0) { $0 + $1.count }
            WrapLayout(spacing: 6) {
                Button { pick(nil) } label: {
                    let selected = only == nil
                    HStack(spacing: 4) {
                        Text(L10n.t("全部", "All"))
                        Text("\(total)")
                            .monospacedDigit()
                            .opacity(selected ? 0.9 : 0.72)
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(selected ? .white : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(selected ? Palette.accentFill : (dark ? Palette.lampCard : Palette.card)))
                    .overlay(Capsule().strokeBorder(Palette.outline.opacity(selected ? 0 : 0.28), lineWidth: 0.75))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(only == nil ? .isSelected : [])

                ForEach(categories, id: \.key) { item in
                    let on = only == item.key
                    let color = LogType.color(JournalKinds.type(item.key))
                    Button { pick(on ? nil : item.key) } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(color)
                                .frame(width: 7, height: 7)
                            Text(JournalKinds.name(item.key))
                            Text("\(item.count)")
                                .monospacedDigit()
                                .foregroundStyle(on ? Crayon.ink(color) : Palette.secondaryText)
                        }
                        .font(.caption.weight(on ? .bold : .semibold))
                        .foregroundStyle(on ? Crayon.ink(color) : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(on ? color.opacity(dark ? 0.28 : 0.16) : (dark ? Palette.lampCard : Palette.card)))
                        .overlay(Capsule().strokeBorder(on ? Crayon.ink(color) : Palette.outline.opacity(0.28), lineWidth: on ? 1.25 : 0.75))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }
}

/// The other kinds recorded on the day, as small chips with their counts; tap one to see only it.
private struct OtherKinds: View {
    let logs: [LogEntry]
    let only: String?
    let pick: (String) -> Void
    var body: some View {
        let kinds = [LogType.solid, LogType.bath, LogType.temp, LogType.medicine, LogType.play, LogType.note].filter { t in logs.contains { $0.type == t } }
        if !kinds.isEmpty {
            WrapLayout(spacing: 8) {
                ForEach(kinds, id: \.self) { t in
                    let c = LogType.color(t), on = only == t, n = logs.filter { $0.type == t }.count
                    Button { pick(t) } label: {
                        HStack(spacing: 6) {
                            IconTile(symbol: LogType.symbol(t), color: c, size: 20, round: true)
                            Text(LogType.name(t)).font(.footnote.weight(.semibold))
                            Ticking(text: "\(n)").font(Typeface.numerals(13, relativeTo: .footnote, weight: .bold)).foregroundStyle(Crayon.ink(c))
                        }
                        .padding(.leading, 6).padding(.trailing, 10).padding(.vertical, 5)
                        .vinylSurface(c, radius: Radius.tile)
                        .overlay(Capsule().strokeBorder(on ? Crayon.ink(c) : .clear, lineWidth: 1.5))
                        .opacity(only == nil || on ? 1 : 0.5)
                    }
                    .buttonStyle(.toy)
                    .accessibilityLabel(L10n.isEnglish ? "\(LogType.name(t)), \(n)" : "\(LogType.name(t)) \(n) 次")
                    .accessibilityHint(on ? L10n.t("显示全部", "Show all") : L10n.t("只看这一类", "Filter to this kind"))
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }
}

/// While one kind is shown alone: what it adds up to that day, said in one line, and a way back to everything.
private struct FocusLine: View {
    let kind: String
    let logs: [LogEntry]
    let all: [LogEntry]
    let day: Day
    let clear: () -> Void
    var body: some View {
        let c = LogType.color(JournalKinds.type(kind))
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill").foregroundStyle(Crayon.ink(c))
            Text(summary).font(.footnote.weight(.semibold)).foregroundStyle(.primary).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.75)
            Spacer(minLength: 6)
            Button(L10n.t("全部", "All"), action: clear).buttonStyle(.vinyl(c))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(c.opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    /// Facts only, from the day's records: how many, and for feeds the usual gap between them; for sleep how many
    /// times and how long in all.
    private var summary: String {
        let d0 = day.date.timeIntervalSince1970 * 1000
        switch kind {
        case "feed":
            let starts = feedStarts().filter { $0 >= d0 }
            let count = logs.feedCount(from: d0)
            var s = L10n.isEnglish ? "Feeds · \(count)" : "只看喂奶 · \(count) 次"
            if starts.count >= 2 {
                let gaps = zip(starts.dropFirst(), starts).map { ($0 - $1) / 1000 }
                s += " · " + labeled(L10n.t("平均间隔", "Avg gap"), durationValue(gaps.reduce(0, +) / Double(gaps.count)))
            }
            return s
        case LogType.sleep:
            let total = logs.reduce(0.0) { $0 + $1.seconds(on: day) }
            return L10n.isEnglish
                ? "Sleep · \(logs.count) \(logs.count == 1 ? "stretch" : "stretches") · " + durationValue(total)
                : "只看睡眠 · \(logs.count) 段 · 共 " + durationValue(total)
        case LogType.diaper:
            let wet = logs.filter { $0.detail == "wet" || $0.detail == "both" }.count, dirty = logs.filter { $0.detail == "dirty" || $0.detail == "both" }.count
            return L10n.isEnglish
                ? "Diapers · \(logs.count) · \(wet) wet · \(dirty) dirty"
                : "只看尿布 · \(logs.count) 片 · 湿 \(wet) · 便 \(dirty)"
        default:
            return L10n.isEnglish ? LogType.name(kind) + " · \(logs.count)" : "只看" + LogType.name(kind) + " · \(logs.count) 次"
        }
    }
    /// The start of each feed of the day (the second side of a breast feed is the same feed).
    private func feedStarts() -> [Double] { logs.feeds().map(\.start) }
}

/// A feed or sleep still running, at the top of today's line: its start, how long so far; a tap opens its timer.
struct RunningRow: View {
    @Environment(JournalStore.self) private var j
    let timer: RunningTimer
    var body: some View {
        let c = LogType.color(timer.type)
        Button { j.focus = timer.type } label: {
            TimelineView(.periodic(from: .now, by: 30)) { tl in
                let state = (timer.pausedAt != nil ? L10n.t("已暂停 ", "Paused ") : L10n.t("进行中 ", "Active ")) + durationValue(timer.total(tl.date.timeIntervalSince1970 * 1000))
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        Text(hm(Date(timeIntervalSince1970: timer.start / 1000))).font(Typeface.numerals(16, relativeTo: .body, weight: .semibold))
                        IconTile(symbol: LogType.symbol(timer.type), color: c, size: 28, round: true)
                        Text(LogType.name(timer.type)).font(.body).fixedSize()
                        Spacer(minLength: 8)
                        Ticking(text: state, tint: Crayon.ink(c))
                            .font(Typeface.numerals(15, relativeTo: .body, weight: .semibold)).foregroundStyle(Crayon.ink(c))
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    // large text: the kind and its state one under the other
                    HStack(spacing: 10) {
                        IconTile(symbol: LogType.symbol(timer.type), color: c, size: 28, round: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LogType.name(timer.type) + " · " + hm(Date(timeIntervalSince1970: timer.start / 1000))).font(.body)
                            Text(state).font(.body.weight(.semibold)).foregroundStyle(Crayon.ink(c))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(c.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
            }
        }
        .buttonStyle(.toy)
        .accessibilityLabel(L10n.t("\(LogType.name(timer.type))进行中，打开计时", "\(LogType.name(timer.type)) active, open timer"))
    }
}

// Replaced cleanly by DaySwimlaneCanvas + DaySwimlaneChart in DayLedger.swift


/// The paper of the journal: a faint dot grid rendered once as a 16 pt tile (avoids drawing thousands of Canvas circles per scroll/resize).
private struct DotPaper: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    private static let lightTile = DotPaper.makeTile(dark: false)
    private static let darkTile = DotPaper.makeTile(dark: true)

    var body: some View {
        let dark = lamp || scheme == .dark
        Image(uiImage: dark ? Self.darkTile : Self.lightTile)
            .resizable(resizingMode: .tile)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private static func makeTile(dark: Bool) -> UIImage {
        let g: CGFloat = 16
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: g, height: g), format: format).image { ctx in
            let ink = dark ? UIColor(white: 1, alpha: 0.1) : UIColor(white: 0, alpha: 0.1)
            ink.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: g - 0.9 - 8, y: g - 0.9 - 8, width: 1.8, height: 1.8))
        }
    }
}

/// The day's three totals, as stamps of equal width.
private struct Totals: View {
    let logs: [LogEntry]
    let day: Day
    var only: String? = nil
    var pick: (String) -> Void = { _ in }
    @Environment(\.dynamicTypeSize) private var size
    var body: some View {
        // counts are of what started on the day; sleep is the part of each sleep that falls on the day
        let own = logs.filter { !$0.carriedOver(into: day) }
        let feeds = logs.feedCount(from: day.date.timeIntervalSince1970 * 1000)
        let ml = own.filter { $0.type == LogType.bottle }.reduce(0) { $0 + ($1.amount ?? 0) }
        // breastfeeding as time on the breast that day (pauses left out), not only how many times
        let nursed = logs.filter { $0.type == LogType.nurse && $0.end != nil }.reduce(0.0) { $0 + $1.seconds(on: day) }
        let feedLine = [
            nursed >= 60 ? L10n.t("亲喂 ", "Nursed ") + durationValue(nursed) : nil,
            ml > 0 ? L10n.t("瓶喂 \(ml) 毫升", "Bottle " + L10n.volume(ml: ml)) : nil
        ].compactMap { $0 }
        let sleep = logs.filter { $0.type == LogType.sleep }.reduce(0.0) { $0 + $1.seconds(on: day) }
        let nappies = own.filter { $0.type == LogType.diaper }
        let wet = nappies.filter { $0.detail == "wet" || $0.detail == "both" }.count
        let dirty = nappies.filter { $0.detail == "dirty" || $0.detail == "both" }.count
        // the whole sleep, as on its line; when it began the day before, said so (it can be longer than the day's part)
        let longestSleep: LogEntry? = logs.filter { $0.type == LogType.sleep && $0.end != nil }.max { $0.activeSeconds < $1.activeSeconds }
        let longest: Double = longestSleep?.activeSeconds ?? 0
        let longestLine: [String] = longest >= 60
            ? [L10n.t("最长一觉", "Longest"), durationValue(longest)] + ((longestSleep?.carriedOver(into: day) ?? false) ? [L10n.t("（接昨天）", "(from yesterday)")] : [])
            : []
        // three across; at the largest text sizes, one under the other so nothing breaks a word
        let layout = size.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
        layout {
            tap("feed", stamp(LogType.nurse, L10n.t("喂奶", "Feeds"), [("\(feeds)", L10n.t("次", feeds == 1 ? "feed" : "feeds"))], feedLine))
            tap(LogType.sleep, stamp(LogType.sleep, L10n.t("睡眠", "Sleep"), durationParts(sleep), longestLine, " "))
            // what a doctor asks: how many wet, how many dirty
            tap(LogType.diaper, stamp(LogType.diaper, L10n.t("尿布", "Diapers"), [("\(nappies.count)", L10n.t("片", ""))], nappies.isEmpty ? [] : [L10n.t("湿 \(wet)", "Wet \(wet)"), L10n.t("便 \(dirty)", "Dirty \(dirty)")]))
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    /// A total as a button: tap to see only that kind on the day's string and line; the chosen one is ringed, the
    /// others step back.
    private func tap<V: View>(_ key: String, _ v: V) -> some View {
        let on = only == key, c = LogType.color(JournalKinds.type(key))
        return Button { pick(key) } label: {
            v.overlay(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).strokeBorder(on ? Crayon.ink(c) : .clear, lineWidth: 2))
                .opacity(only == nil || on ? 1 : 0.45)
                .scaleEffect(on ? 1.02 : 1)
        }
        .buttonStyle(.toy)
        .accessibilityHint(on ? L10n.t("显示全部", "Show all") : L10n.t("只看这一类", "Filter to this kind"))
        .accessibilityAddTraits(on ? .isSelected : [])
    }
    private func details(_ sub: [String], _ sep: String) -> some View {
        ViewThatFits(in: .horizontal) {
            Text(sub.joined(separator: sep)).fixedSize()
            VStack(alignment: .leading, spacing: 0) { ForEach(sub, id: \.self) { Text($0).lineLimit(1).minimumScaleFactor(0.85) } }
        }
    }
    private func stamp(_ t: String, _ name: String, _ parts: [(String, String)], _ sub: [String], _ sep: String = " · ") -> some View {
        let c = LogType.color(t)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                IconTile(symbol: LogType.symbol(t), color: c, size: 18, round: true)
                Text(name).font(.caption.weight(.semibold)).foregroundStyle(Crayon.ink(c))
            }
            // numbers large, units small: compact units + ViewThatFits/scale so "14时42分" / "14h 42m" never truncates to "…"
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, p in
                    Ticking(text: p.0, tint: Crayon.ink(c))
                        .font(Typeface.numerals(parts.count > 1 ? 21 : 24, relativeTo: .title2, weight: .bold))
                    if !p.1.isEmpty {
                        Text(p.1).font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                    }
                }
            }
            .lineLimit(1).minimumScaleFactor(0.55)
            // the details in full: on one line when they fit, otherwise one piece per line — never cut off with "…"
            // nothing to add: an invisible line keeps the three tiles the same height (hidden, so nothing is read or audited)
            Group {
                if sub.isEmpty { Text(verbatim: "0").hidden() } else { details(sub, sep) }
            }
            .font(.caption2).foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .vinylSurface(c)   // a solid chip: dashes mean an empty slot
        .accessibilityElement(children: .combine)
    }
}

/// A short phrase that must not break across lines ("共 8 小时 30 分", "到 06:30"): its spaces become no-break spaces
/// and its characters are joined with word joiners. A long free text (a note) is left to wrap as usual.
/// Pieces of a line separated by dots (subviews alternate: piece, dot, piece, …): pieces wrap as whole words, and a
/// dot is drawn only between two pieces on the same line — never at a line's end or start.
struct DotFlow: Layout {
    var spacing: CGFloat = 4, lineSpacing: CGFloat = 1
    private func lines(_ subviews: Subviews, width: CGFloat) -> [[(index: Int, size: CGSize)]] {
        var out: [[(index: Int, size: CGSize)]] = [[]], x: CGFloat = 0
        var i = 0
        while i < subviews.count {
            let piece = subviews[i].sizeThatFits(ProposedViewSize(width: width, height: nil))
            if i == 0 { out[0].append((i, piece)); x = piece.width; i += 1; continue }
            // a dot (i) and the piece after it (i + 1)
            let dot = subviews[i].sizeThatFits(.unspecified)
            guard i + 1 < subviews.count else { break }
            let next = subviews[i + 1].sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x + spacing + dot.width + spacing + next.width <= width {
                out[out.count - 1].append((i, dot)); out[out.count - 1].append((i + 1, next))
                x += spacing + dot.width + spacing + next.width
            } else {
                out.append([(i + 1, next)]); x = next.width
            }
            i += 2
        }
        return out
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        let ls = lines(subviews, width: w)
        let h = ls.map { $0.map(\.size.height).max() ?? 0 }.reduce(0, +) + lineSpacing * CGFloat(max(0, ls.count - 1))
        let used = ls.map { l in l.map(\.size.width).reduce(0, +) + spacing * CGFloat(max(0, l.count - 1)) }.max() ?? 0
        return CGSize(width: proposal.width ?? used, height: h)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let ls = lines(subviews, width: bounds.width)
        var shown = Set<Int>(), y = bounds.minY
        for l in ls {
            var x = bounds.minX
            let h = l.map(\.size.height).max() ?? 0
            for (i, size) in l {
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                shown.insert(i); x += size.width + spacing
            }
            y += h + lineSpacing
        }
        // dots that fell at a line break are not drawn
        for i in subviews.indices where !shown.contains(i) { subviews[i].place(at: CGPoint(x: -10_000, y: -10_000), proposal: .zero) }
    }
}

/// "3 小时 50 分" → each number stays with its unit; a line may still break between "3 小时" and "50 分".
func keepUnits(_ s: String) -> String {
    let t: [String] = s.split(separator: " ").map(String.init)
    var pairs: [String] = []
    var i = 0
    while i < t.count {
        if i + 1 < t.count { pairs.append(glue(t[i] + "\u{00A0}" + t[i + 1])) } else { pairs.append(glue(t[i])) }
        i += 2
    }
    return pairs.joined(separator: " ")
}

/// A run of text that never breaks inside (Chinese may otherwise break between any two characters).
func glue(_ s: String) -> String { s.map(String.init).joined(separator: "\u{2060}") }

/// 「距上一顿 3 小时 30 分」: the label stays with the first number, each number with its unit; a line may break only
/// between "3 小时" and "30 分".
func labeled(_ label: String, _ duration: String) -> String { glue(label) + "\u{00A0}" + keepUnits(duration) }

func unbroken(_ s: String) -> String {
    guard s.count <= 14 else { return s }
    return s.map { $0 == " " ? "\u{00A0}" : String($0) }.joined(separator: "\u{2060}")
}

/// A length of time as number–unit pairs, for a large number with a small unit: [("8", "小时"), ("5", "分")].
func durationParts(_ seconds: Double) -> [(String, String)] {
    let m = Int((max(0, seconds) / 60).rounded())
    if m < 60 { return [("\(m)", L10n.t("分钟", "m"))] }
    if m >= 48 * 60 {
        let h = m / 60
        return h % 24 == 0 ? [("\(h / 24)", L10n.t("天", "d"))] : [("\(h / 24)", L10n.t("天", "d")), ("\(h % 24)", L10n.t("时", "h"))]
    }
    return m % 60 == 0 ? [("\(m / 60)", L10n.t("小时", "h"))] : [("\(m / 60)", L10n.t("时", "h")), ("\(m % 60)", L10n.t("分", "m"))]
}

/// A length of time, rounded to the minute, in the one form used everywhere (minutesOf).
func durationValue(_ seconds: Double) -> String { minutesOf((max(0, seconds) / 60).rounded() * 60) }

extension LogEntry {
    /// The value, right-aligned in its column: an amount, a length of time (the part on this day), a temperature, the
    /// kind of nappy.
    func value(on day: Day) -> String {
        switch type {
        case LogType.nurse, LogType.sleep: return end == nil ? L10n.t("进行中", "Active") : durationValue(seconds(on: day))
        case LogType.bottle: return L10n.volume(ml: amount ?? 0)
        case LogType.temp: return amount.map { L10n.temperature(tenthsC: $0) } ?? ""
        case LogType.diaper:
            return L10n.isEnglish
                ? (["wet": "Wet", "dirty": "Dirty", "both": "Wet + dirty"][detail ?? ""] ?? "")
                : (["wet": "湿", "dirty": "便", "both": "湿 + 便"][detail ?? ""] ?? "")
        default: return ""
        }
    }
    /// The details, on the second line, without repeating the start time shown in the first column: the side, when it
    /// ended (or began, if the day before), the whole length when it crosses midnight, what was eaten or noted.
    func meta(on day: Day, endShown: Bool = false) -> String {
        var bits: [String] = []
        if type == LogType.nurse, let s = side { bits.append(s == "l" ? L10n.t("左侧", "Left") : L10n.t("右侧", "Right")) }
        if let m = milk { bits.append(m) }
        if let e = endDate {
            let endsLater = Day(e) > day
            if carriedOver(into: day) {
                bits.append(L10n.t("接昨天 \(hm(startDate)) · 到 \(hm(e))", "From yesterday \(hm(startDate)) · until \(hm(e))"))
            } else if !endShown || endsLater {
                bits.append(L10n.isEnglish
                    ? "Until " + hm(e) + (endsLater ? " next day" : "")
                    : "到 " + (endsLater ? "次日 " : "") + hm(e))
            }
            if carriedOver(into: day) || endsLater { bits.append(L10n.t("共 ", "Total ") + durationValue(activeSeconds)) }
            if pausedSeconds >= 60 { bits.append(L10n.t("暂停 ", "Paused ") + durationValue(pausedSeconds)) }
        }
        if [LogType.solid, LogType.medicine, LogType.note, LogType.play].contains(type), let d = detail, !d.isEmpty {
            bits.append(type == LogType.play ? String(d.drop { $0 != " " }.dropFirst()) : d)
        }
        return bits.joined(separator: " · ")
    }
}

/// Four-Chapter Collapsible Day Ledger (`夜晚 / 下午 / 上午 / 深夜`) with smart default expansion so high-frequency
/// newborn days (35+ entries) scan effortlessly on one screen while preserving every entry and full metadata.
struct DayChapterLedger: View {
    let day: Day, today: Day
    let logs: [LogEntry]
    let only: String?
    @Binding var expandedPeriods: Set<DayPeriod>
    @Binding var touchedPeriods: Bool
    @Binding var expandAll: Bool
    let edit: (LogEntry) -> Void
    let delete: (LogEntry) -> Void

    @ScaledMetric private var timeWidth: CGFloat = 52
    @Environment(JournalStore.self) private var j
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.lamp) private var lamp

    private func isExpanded(_ chapter: DayChapter, index: Int, chapters: [DayChapter], totalRows: Int) -> Bool {
        if expandAll || only != nil || chapters.count <= 1 || totalRows <= 8 { return true }
        if !touchedPeriods { return index == 0 }
        return expandedPeriods.contains(chapter.period)
    }

    var body: some View {
        let d0 = day.date.timeIntervalSince1970 * 1000
        let chapters = DayChapter.build(day: day, logs: logs)
        let totalRows = chapters.reduce(0) { $0 + $1.rowCount }
        let gaps = (only == nil)

        TimelineView(.periodic(from: .now, by: 60)) { tl in
            VStack(alignment: .leading, spacing: 10) {
                if chapters.count > 1 && totalRows > 8 && only == nil {
                    HStack(spacing: 8) {
                        Text(L10n.isEnglish ? "By time of day · \(totalRows) entries" : "分时段手账 · 共 \(totalRows) 条")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.secondaryText)
                        Spacer(minLength: 4)
                        Button {
                            TactileEngine.shared.beadClick()
                            withAnimation(reduce ? nil : CalmMotion.accordionSpring) {
                                expandAll.toggle()
                                if expandAll {
                                    touchedPeriods = true
                                    expandedPeriods = Set(chapters.map(\.period))
                                } else {
                                    touchedPeriods = true
                                    expandedPeriods = Set(chapters.prefix(1).map(\.period))
                                }
                            }
                        } label: {
                            Text(expandAll ? L10n.t("收起早先", "Collapse") : L10n.t("全部展开", "Expand All"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Palette.accent)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Palette.accent.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }

                ForEach(Array(chapters.enumerated()), id: \.element.id) { cIndex, chapter in
                    let expanded = isExpanded(chapter, index: cIndex, chapters: chapters, totalRows: totalRows)
                    VStack(alignment: .leading, spacing: 4) {
                        if chapters.count > 1 {
                            Button {
                                TactileEngine.shared.beadClick()
                                withAnimation(reduce ? nil : CalmMotion.accordionSpring) {
                                    if !touchedPeriods {
                                        touchedPeriods = true
                                        if let first = chapters.first {
                                            expandedPeriods = totalRows <= 8 ? Set(chapters.map(\.period)) : [first.period]
                                        }
                                    }
                                    if expandedPeriods.contains(chapter.period) {
                                        expandedPeriods.remove(chapter.period)
                                        expandAll = false
                                    } else {
                                        expandedPeriods.insert(chapter.period)
                                    }
                                }
                            } label: {
                                HStack(alignment: type.isAccessibilitySize ? .top : .center, spacing: 8) {
                                    Image(systemName: chapter.period.symbol)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(chapter.period.tint)
                                        .padding(.top, type.isAccessibilitySize ? 3 : 0)
                                    if type.isAccessibilitySize {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(chapter.period.title)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.primary)
                                            Text(chapter.summaryLine)
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(Palette.secondaryText)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    } else {
                                        Text(chapter.period.title)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.primary)
                                        Text(chapter.summaryLine)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(Palette.secondaryText)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.75)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.down")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.tertiary)
                                        .rotationEffect(.degrees(expanded ? 180 : 0))
                                        .padding(.top, type.isAccessibilitySize ? 4 : 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                                        .fill(chapter.period.tint.opacity(lamp ? 0.14 : 0.09))
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityValue(expanded ? L10n.t("已展开", "Expanded") : L10n.t("已折叠", "Collapsed"))
                            .id("chapter-\(chapter.period.rawValue)")
                        }

                        if expanded {
                            let rows = chapter.rows
                            let reached: [Double] = {
                                var out = Array(repeating: 0.0, count: rows.count), m = -Double.infinity
                                for i in rows.indices.reversed() {
                                    m = Swift.max(m, rows[i].face.end ?? rows[i].face.start)
                                    out[i] = m
                                }
                                return out
                            }()

                            VStack(spacing: 0) {
                                ForEach(Array(rows.enumerated()), id: \.element.id) { i, group in
                                    let e = group.face
                                    let parts = group.parts
                                    if i > 0 {
                                        let newer = rows[i - 1].face
                                        let gap = (max(newer.start, d0) - reached[i]) / 1000
                                        if gaps && gap >= 3 * 3600 {
                                            GapRow(seconds: gap, timeWidth: timeWidth)
                                        }
                                    }
                                    CompactEntryRow(
                                        entry: e,
                                        parts: parts,
                                        day: day,
                                        isToday: day == today && cIndex == 0 && i == 0,
                                        now: tl.date,
                                        timeWidth: timeWidth,
                                        since: feedInterval(parts[0])
                                    )
                                    .transition(.opacity)
                                    .contentShape(Rectangle())
                                    .onTapGesture { edit(parts[0]) }
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityHint(L10n.t("修改这条记录", "Edit this entry"))
                                    .accessibilityAction(named: parts.count > 1 ? L10n.t("删除这一顿", "Delete feed") : L10n.t("删除", "Delete")) { remove(parts) }
                                    .contextMenu {
                                        if parts.count > 1 {
                                            ForEach(parts) { p in
                                                Button(L10n.t("修改" + (p.side == "r" ? "右侧" : "左侧"), "Edit " + (p.side == "r" ? "Right" : "Left")) + " · " + hm(p.startDate), systemImage: "pencil") { edit(p) }
                                            }
                                            Button(L10n.t("删除这一顿", "Delete feed"), systemImage: "trash", role: .destructive) { remove(parts) }
                                        } else {
                                            Button(L10n.t("修改", "Edit"), systemImage: "pencil") { edit(e) }
                                            Button(L10n.t("删除", "Delete"), systemImage: "trash", role: .destructive) { delete(e) }
                                        }
                                    }
                                    if i < rows.count - 1 {
                                        Divider().padding(.leading, timeWidth + 32).opacity(0.35)
                                    }
                                }
                            }
                            .padding(.top, 2)
                            .transition(reduce ? .opacity : .opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .clipped()
                    .animation(reduce ? nil : CalmMotion.accordionSpring, value: expanded)
                }
            }
        }
    }

    private func remove(_ parts: [LogEntry]) {
        if parts.count > 1 { withAnimation(.snappy) { j.delete(parts) } } else { delete(parts[0]) }
    }

    private func feedInterval(_ e: LogEntry) -> Double? {
        guard e.type == LogType.nurse || e.type == LogType.bottle else { return nil }
        return j.feedIntervalByID[e.id]
    }
}

/// A quiet stretch between two entries, written on a dashed rail.
private struct GapRow: View {
    let seconds: Double
    let timeWidth: CGFloat
    var body: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: timeWidth, height: 1)
            Line().stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 5]))
                .frame(width: 24, height: 22)
            Text(labeled(L10n.t("相隔", "Quiet"), durationValue(seconds))).font(.caption.weight(.medium)).foregroundStyle(Palette.secondaryText).monospacedDigit()
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
    private struct Line: Shape { func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY)); return p } }
}

/// High-craft compact ledger row preserving every timestamp, duration, pause, feeding side & interval metadata.
private struct CompactEntryRow: View {
    let entry: LogEntry
    var parts: [LogEntry] = []
    let day: Day
    let isToday: Bool
    let now: Date
    let timeWidth: CGFloat
    var since: Double? = nil

    var body: some View {
        let c = LogType.color(entry.type)
        let joined = parts.count > 1
        let value = joined ? durationValue(parts.reduce(0) { $0 + $1.seconds(on: day) }) : entry.value(on: day)
        let sides = joined ? parts.map { ($0.side == "r" ? L10n.t("右侧 ", "Right ") : L10n.t("左侧 ", "Left ")) + durationValue($0.seconds(on: day)) }.joined(separator: " · ") : nil
        let showEnd = entry.endDate != nil && entry.seconds(on: day) >= 1800
        let meta: [String] = [sides, entry.meta(on: day, endShown: showEnd), since.map { labeled(L10n.t("距上一顿", "Gap"), durationValue($0)) }].compactMap { $0 }.filter { !$0.isEmpty }
            .joined(separator: " · ").components(separatedBy: " · ").filter { !$0.isEmpty }

        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.carriedOver(into: day) ? "00:00" : hm(entry.startDate))
                    .font(Typeface.numerals(15, relativeTo: .subheadline, weight: .semibold))
                if let e = entry.endDate, showEnd {
                    Text(Day(e) > day ? "24:00" : hm(e))
                        .font(Typeface.numerals(11, relativeTo: .caption2, weight: .medium))
                        .foregroundStyle(Palette.secondaryText)
                } else if isToday {
                    let ref = entry.endDate ?? entry.startDate
                    if abs(now.timeIntervalSince(ref)) < 18 * 3600 {
                        Text(ago(ref, now: now))
                            .font(.caption2)
                            .foregroundStyle(Palette.secondaryText)
                    }
                }
            }
            .frame(width: timeWidth, alignment: .topLeading)

            HStack(spacing: 4) {
                Capsule()
                    .fill(c)
                    .frame(width: 3, height: entry.end != nil ? 22 : 14)
                IconTile(symbol: LogType.symbol(entry.type), color: c, size: 22, round: true)
            }
            .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(LogType.name(entry.type)).font(.subheadline.weight(.semibold))
                        Spacer(minLength: 8)
                        Text(value).font(Typeface.numerals(15, relativeTo: .subheadline, weight: .semibold)).foregroundStyle(Crayon.ink(c)).fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(LogType.name(entry.type)).font(.subheadline.weight(.semibold))
                        Text(value).font(Typeface.numerals(15, relativeTo: .subheadline, weight: .semibold)).foregroundStyle(Crayon.ink(c))
                    }
                }
                if !meta.isEmpty {
                    DotFlow {
                        ForEach(Array(meta.enumerated()), id: \.offset) { i, piece in
                            if i > 0 { Text("·") }
                            Text(piece.contains("\u{00A0}") ? piece : unbroken(piece)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .font(.caption).foregroundStyle(Palette.secondaryText).monospacedDigit()
                    .accessibilityElement(children: .ignore).accessibilityLabel(meta.joined(separator: L10n.t("，", ", ")))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

/// The running timer, small, above the tab bar on every tab; tap to open it. Only pause sits here: ending is done on
/// the timer screen, in its own band, never a few points from pause (a mis-tap would end a feed).
struct TimerAccessory: View {
    @Environment(JournalStore.self) private var j
    @Environment(\.accessibilityReduceMotion) private var reduce
    let timer: RunningTimer
    /// A second clock running at once (a feed during a nap): its mark and time beside the first, one tap to open it.
    var also: RunningTimer? = nil
    @State private var pulse = false

    var body: some View {
        let c = LogType.color(timer.type)
        let isPaused = timer.pausedAt != nil
        HStack(spacing: 12) {
            Button {
                TactileEngine.shared.beadClick()
                j.focus = timer.type
            } label: {
                HStack(spacing: 10) {
                    IconTile(symbol: LogType.symbol(timer.type), color: c, size: 30, round: true)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(isPaused ? Color.clear : c)
                                .overlay(Circle().strokeBorder(c, lineWidth: isPaused ? 1.5 : 0))
                                .frame(width: 6.5, height: 6.5)
                                .scaleEffect(!isPaused && pulse && !reduce && !Perf.still ? 1.28 : 1.0)
                            Text(LogType.name(timer.type) + (timer.side == "l" ? L10n.t(" · 左侧", " · Left") : timer.side == "r" ? L10n.t(" · 右侧", " · Right") : ""))
                                .font(.footnote.weight(.semibold))
                        }
                        TimelineView(.periodic(from: .now, by: 1)) { tl in
                            let elapsed = span(timer.total(tl.date.timeIntervalSince1970 * 1000))
                            HStack(spacing: 4) {
                                Ticking(text: elapsed, tint: Crayon.ink(c))
                                    .font(Typeface.numerals(13, relativeTo: .footnote))
                                    .foregroundStyle(Palette.secondaryText)
                                if isPaused {
                                    Text(L10n.t("· 已暂停", "· Paused"))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Crayon.ink(c))
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.toy)
            .accessibilityLabel(L10n.t("打开\(LogType.name(timer.type))计时", "Open \(LogType.name(timer.type)) timer"))
            if let o = also {
                Button {
                    TactileEngine.shared.beadClick()
                    j.focus = o.type
                } label: {
                    HStack(spacing: 6) {
                        IconTile(symbol: LogType.symbol(o.type), color: LogType.color(o.type), size: 24, round: true)
                        TimelineView(.periodic(from: .now, by: 1)) { tl in
                            Text(span(o.total(tl.date.timeIntervalSince1970 * 1000))).font(Typeface.numerals(13, relativeTo: .footnote)).monospacedDigit()
                        }
                    }
                }
                .buttonStyle(.toy)
                .accessibilityLabel(L10n.t("打开\(LogType.name(o.type))计时", "Open \(LogType.name(o.type)) timer"))
            }
            Button {
                TactileEngine.shared.dimmerTick()
                j.togglePause(timer.type)
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .frame(minWidth: 32, minHeight: 32)
                    .contentShape(Circle())
            }
            .accessibilityLabel(isPaused ? L10n.t("继续", "Resume") : L10n.t("暂停", "Pause"))
        }
        .font(.body)
        .padding(.horizontal, 14)
        .tint(.primary)
        .onAppear {
            guard !isPaused, !reduce, !Perf.still else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onChange(of: isPaused) { _, paused in
            if !paused && !reduce && !Perf.still {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            } else {
                pulse = false
            }
        }
    }
}

/// "今天 14:05" / "昨天 23:40" / "10月20日 08:15" — the whole time, never shortened.
func whenLabel(_ d: Date) -> String {
    let day = Day(d), today = Day.today
    let name = day == today ? L10n.t("今天", "Today") : day == today.plus(days: -1) ? L10n.t("昨天", "Yesterday") : day == today.plus(days: -2) ? L10n.t("前天", "2 days ago") : day.md
    return "\(name) \(hm(d))"
}

/// An exact day and minute, never later than now.
struct TimeSheet: View {
    let title: String
    let initial: Date
    var notBefore: Date? = nil
    let pick: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    var body: some View {
        let now = Date()
        let lower = min(notBefore ?? Date.distantPast, now)
        NavigationStack {
            Form {
                Section {
                    DatePicker(title, selection: $date, in: lower...now, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                } footer: { Text(whenLabel(date)).font(.headline).monospacedDigit() }
            }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.t("取消", "Cancel"), systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(L10n.t("完成", "Done"), systemImage: "checkmark") { pick(date); dismiss() } }
            }
        }
        .onAppear {
            let now = Date()
            let lower = min(notBefore ?? Date.distantPast, now)
            date = min(max(initial, lower), now)
        }
        .presentationDetents([.large])
    }
}
