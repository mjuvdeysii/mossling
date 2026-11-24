import SwiftUI
import TipKit

/// The home holds only what is needed every day, in that order: who the child is now (the month card — tapping it
/// opens the month's own page, where everything read once lives: its points, its parts, all its plays, the topics,
/// and the way to other months); what is due this month, only while something is; what is happening now, from the
/// records; and 今天一起玩, the everyday reason to open the app. It reads in about one screen.
struct TodayView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.night) private var night
    @Binding var path: NavigationPath
    @State private var askBirth = false
    @State private var arranging = false
    @State private var showingLamp = false
    @State private var showingStorybook = false
    @State private var soundscape = SoundscapeEngine.shared
    @State private var capsules = CapsuleStore.shared
    @State private var foods = FoodAtlasStore.shared
    private let shelfTip = ShelfTip()
    private let recordsTip = RecordsTip()

    var body: some View {
        let baby = app.babyMonth ?? 0
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if app.age == nil {
                    Button { if app.mayKeep() { askBirth = true } } label: { Label(L10n.t("填写出生日期，从宝宝这个月开始", "Add baby's birthday to begin"), systemImage: "calendar.badge.plus").frame(maxWidth: .infinity) }
                        .buttonStyle(.vinyl(Palette.accentFill, prominent: true, large: true))
                }
                // a feed or a sleep being timed is what matters most while it runs: it leads the page
                let running = !j.timers.isEmpty || night
                if running && app.journal && app.age != nil { NowCard(month: baby) }
                MonthCard(month: baby, baby: baby) { path.append(Route.journey) }
                    .zoomSource(Route.journey)
                if app.age != nil { DueCard(month: baby) }
                if !running && app.journal && app.age != nil { NowCard(month: baby) }
                if app.age != nil {
                    TipView(recordsTip) { action in
                        if action.id == "on" && app.mayKeep() { withAnimation(.snappy) { app.journal = true }; recordsTip.invalidate(reason: .actionPerformed) }
                    }
                }
                if app.age != nil { TipView(shelfTip) }
                // before the birth date is known too: the same 今天一起玩, from the first month's plays (the week is
                // chosen anew for the child's month once the date is given)
                TodayPlayCard(
                    month: baby,
                    arrange: { arranging = true }
                )
                let todayLogs = j.logs(on: app.today)
                let todaySleepCount = todayLogs.filter { $0.type == LogType.sleep && $0.end != nil }.count
                let todayFeedCount = todayLogs.feeds().count
                let bookMonths = app.birth != nil ? max(1, min(app.age?.bookMonth ?? 0, 36) + 1) : 0
                QuietInstrumentsDock(
                    soundscape: soundscape,
                    foods: foods,
                    todayLogs: todayLogs,
                    today: app.today,
                    currentMonth: min(baby, 36),
                    capsuleTotal: capsules.items.count,
                    capsuleReady: capsules.readyCount(on: app.today),
                    toyTodayCount: ToyboxUsage.todayCount(on: app.today),
                    todaySleepCount: app.journal ? todaySleepCount : 0,
                    todayFeedCount: app.journal ? todayFeedCount : 0,
                    bookMonths: bookMonths,
                    firstsCount: j.firsts.count,
                    openLamp: {
                        TactileEngine.shared.beadClick()
                        showingLamp = true
                    },
                    openStorybook: {
                        TactileEngine.shared.pageTurn()
                        if app.birth != nil {
                            showingStorybook = true
                        } else {
                            path.append(Route.book)
                        }
                    }
                )
                if baby >= 36 { StoryGoesOn(primary: app.companion) }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.sunflower)
        .onChange(of: app.journal, initial: true) { _, on in RecordsTip.recordsOff = !on }
        .navigationTitle(app.nickname.isEmpty ? L10n.appName : app.nickname)
        .navigationSubtitle(app.age == nil ? "\(app.today.md) \(app.today.weekday)" : "")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    TactileEngine.shared.beadClick()
                    showingLamp = true
                } label: {
                    Image(systemName: soundscape.isPlaying ? "lamp.desk.fill" : "lamp.desk")
                        .foregroundStyle(soundscape.isPlaying ? Palette.amber : Palette.lampTint)
                        .overlay(alignment: .topTrailing) {
                            if soundscape.isPlaying {
                                Circle()
                                    .fill(Palette.amber)
                                    .frame(width: 6, height: 6)
                                    .offset(x: 2, y: -1)
                            }
                        }
                }
                .accessibilityLabel(L10n.t("打开床头夜灯与助眠声景", "Open Bedside Lamp & Soundscapes"))

                NavigationLink(value: Route.search) { Image(systemName: "magnifyingglass") }.accessibilityLabel(L10n.t("搜索", "Search"))
            }
        }
        .fullScreenCover(isPresented: $showingLamp) { BedsideLampView() }
        .fullScreenCover(isPresented: $showingStorybook) { StorybookView().lampPresented(sheet: false) }
        .sheet(isPresented: $askBirth) { BirthSheet() }
        .sheet(isPresented: $arranging) { ShelfEditor() }
    }
}

/// Pure 24h circadian geometry helper for the Home Atelier Rhythm Dial preview.
enum AtelierDockMetrics {
    struct RhythmSlice: Equatable, Sendable {
        let startFrac: Double
        let endFrac: Double
    }

    static func sleepSlices(in logs: [LogEntry], on day: Day) -> [RhythmSlice] {
        let dayStart = day.date.timeIntervalSince1970 * 1000
        let dayEnd = day.plus(days: 1).date.timeIntervalSince1970 * 1000
        let dayLen = max(1.0, dayEnd - dayStart)
        return logs
            .filter { $0.type == LogType.sleep && $0.end != nil }
            .compactMap { entry -> RhythmSlice? in
                let end = entry.end ?? entry.start
                let clippedStart = max(dayStart, entry.start)
                let clippedEnd = min(dayEnd, end)
                guard clippedEnd > clippedStart else { return nil }
                let s = min(1.0, max(0.0, (clippedStart - dayStart) / dayLen))
                let e = min(1.0, max(0.0, (clippedEnd - dayStart) / dayLen))
                guard e > s else { return nil }
                return RhythmSlice(startFrac: s, endFrac: e)
            }
            .sorted { $0.startFrac < $1.startFrac }
    }

    static func feedFractions(in logs: [LogEntry], on day: Day) -> [Double] {
        let dayStart = day.date.timeIntervalSince1970 * 1000
        let dayEnd = day.plus(days: 1).date.timeIntervalSince1970 * 1000
        let dayLen = max(1.0, dayEnd - dayStart)
        return logs
            .feeds()
            .filter { $0.start >= dayStart && $0.start < dayEnd }
            .map { min(1.0, max(0.0, ($0.start - dayStart) / dayLen)) }
            .sorted()
    }
}

/// 「陪伴小器具 / Quiet Instruments」 — Living Montessori Atelier Dock on Home:
/// Row 1: Twilight Bedside Lamp with 1-tap Soundscape play/pause + Live 24h Circadian Rhythm Dial;
/// Row 2: Live 6-Petal First Foods Wreath + Handcrafted 5-Bar Xylophone Toybox;
/// Row 3: Fanned Polaroid Storybook Stack + Folded Wax-Seal Time Capsule Envelope.
private struct QuietInstrumentsDock: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.accessibilityReduceMotion) private var reduce

    let soundscape: SoundscapeEngine
    let foods: FoodAtlasStore
    let todayLogs: [LogEntry]
    let today: Day
    let currentMonth: Int
    let capsuleTotal: Int
    let capsuleReady: Int
    let toyTodayCount: Int
    let todaySleepCount: Int
    let todayFeedCount: Int
    let bookMonths: Int
    let firstsCount: Int
    let openLamp: () -> Void
    let openStorybook: () -> Void
    @State private var livePulse = false

    var body: some View {
        let dark = lamp || scheme == .dark
        let foodsTasted = foods.tastedCount
        let sleepSlices = AtelierDockMetrics.sleepSlices(in: todayLogs, on: today)
        let feedFractions = AtelierDockMetrics.feedFractions(in: todayLogs, on: today)
        let columns: [GridItem] = type.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: L10n.t("陪伴小器具", "Quiet Instruments"))
                .padding(.top, -10)

            LazyVGrid(columns: columns, spacing: 10) {
                bedsideLampConsoleCard(dark: dark)

                NavigationLink(value: JournalRoute.stats) {
                    atelierTile(
                        color: Crayon.lilac,
                        title: L10n.t("昼夜节律盘", "Rhythm Dial"),
                        subtitle: (todaySleepCount > 0 || todayFeedCount > 0)
                            ? L10n.t("\(todaySleepCount) 觉 · \(todayFeedCount) 喂", "\(todaySleepCount) sleep · \(todayFeedCount) feeds")
                            : L10n.t("24h 睡眠节律", "24h dial"),
                        badge: nil,
                        minHeight: 124,
                        dark: dark
                    ) {
                        MiniRhythmDialCanvas(sleepSlices: sleepSlices, feedFractions: feedFractions, dark: dark)
                    }
                }
                .buttonStyle(.toy)

                NavigationLink(value: Route.foodAtlas) {
                    atelierTile(
                        color: Crayon.leaf,
                        title: L10n.t("百味食盒", "First Foods"),
                        subtitle: foodsTasted > 0
                            ? L10n.t("已尝 \(foodsTasted) / \(FoodItem.catalog.count)", "\(foodsTasted) / \(FoodItem.catalog.count) tasted")
                            : L10n.t("60 种辅食图鉴", "60 foods atlas"),
                        badge: nil,
                        minHeight: 112,
                        dark: dark
                    ) {
                        MiniFoodsWreathCanvas(foods: foods, dark: dark)
                    }
                }
                .buttonStyle(.toy)

                NavigationLink(value: Route.toybox(.xylophone)) {
                    atelierTile(
                        color: Crayon.teal,
                        title: L10n.t("感官玩具盒", "Sensory Toybox"),
                        subtitle: toyTodayCount > 0
                            ? L10n.t("今日 \(toyTodayCount) 次 · 6 童谣", "\(toyTodayCount) today · 6 songs")
                            : L10n.t("木琴 · 雨棒 · 萤火", "4 tactile studios"),
                        badge: nil,
                        minHeight: 112,
                        dark: dark
                    ) {
                        MiniXylophoneArt(dark: dark)
                    }
                }
                .buttonStyle(.toy)

                Button(action: openStorybook) {
                    atelierTile(
                        color: Crayon.caramel,
                        title: L10n.t("成长绘本", "Storybook"),
                        subtitle: bookMonths > 0
                            ? L10n.t("\(bookMonths) 个月 · \(firstsCount) 第一次", "\(bookMonths) mo · \(firstsCount) firsts")
                            : L10n.t("翻页绘本 · 相纸", "Storybook"),
                        badge: nil,
                        minHeight: 102,
                        dark: dark
                    ) {
                        MiniStorybookStackArt(month: currentMonth, dark: dark)
                    }
                }
                .buttonStyle(.toy)

                NavigationLink(value: Route.capsules) {
                    capsuleEnvelopeTile(dark: dark)
                }
                .buttonStyle(.toy)
            }
        }
        .onAppear {
            guard soundscape.isPlaying, !reduce, !Perf.still else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                livePulse = true
            }
        }
        .onChange(of: soundscape.isPlaying) { _, playing in
            if playing && !reduce && !Perf.still {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    livePulse = true
                }
            } else {
                livePulse = false
            }
        }
    }

    private func bedsideLampConsoleCard(dark: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
        let cardFill = Color(hex: dark ? 0x19213F : 0x1D264A)
        let playing = soundscape.isPlaying

        return VStack(alignment: .leading, spacing: 8) {
            Button(action: openLamp) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top) {
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [Palette.amber.opacity(playing ? 0.55 : 0.25), .clear],
                                        center: .center,
                                        startRadius: 2,
                                        endRadius: 22
                                    )
                                )
                                .frame(width: 40, height: 40)
                            ToolArtBadge(toolId: "bedside_lamp", size: 34, active: playing)
                        }
                        Spacer(minLength: 4)
                        HStack(spacing: 5) {
                            if playing {
                                ZStack {
                                    if !reduce {
                                        Circle()
                                            .fill(Palette.amber.opacity(livePulse ? 0.38 : 0.14))
                                            .frame(width: livePulse ? 14 : 10, height: livePulse ? 14 : 10)
                                    }
                                    Circle()
                                        .fill(Palette.amber)
                                        .frame(width: 7, height: 7)
                                }
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Palette.lampInk.opacity(0.55))
                        }
                        .padding(.top, 2)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("床头夜灯", "Bedside Lamp"))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Palette.lampInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(soundscape.activeSummary ?? L10n.t("暖光 · 6 声景", "Warm light · 6 sounds"))
                            .font(.caption2)
                            .foregroundStyle(Palette.lampInk.opacity(0.76))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(L10n.t("打开床头夜灯与助眠声景", "Open Bedside Lamp & Soundscapes"))

            Button {
                TactileEngine.shared.beadClick()
                withAnimation(reduce ? nil : .snappy) {
                    soundscape.toggleQuick()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 9.5, weight: .bold))
                    Text(playing ? L10n.t("停声", "Pause") : soundscape.lastUsedKind.title)
                        .font(.caption2.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Spacer(minLength: 2)
                    if playing {
                        MiniAcousticBars(reduce: reduce)
                    }
                }
                .foregroundStyle(playing ? Color(hex: 0x3A2400) : Palette.lampInk)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(
                        playing ? Palette.amber : Color.white.opacity(0.13)
                    )
                )
            }
            .buttonStyle(.toy)
            .accessibilityLabel(
                playing
                    ? L10n.t("暂停助眠声景", "Pause soundscape")
                    : L10n.t("播放\(soundscape.lastUsedKind.title)", "Play \(soundscape.lastUsedKind.title)")
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .background {
            ZStack {
                shape.fill(cardFill)
                    .shadow(color: Color(hex: 0x0B1028).opacity(dark ? 0.34 : 0.20), radius: 8, y: 4)
                RadialGradient(
                    colors: [Palette.amber.opacity(playing ? 0.24 : 0.11), .clear],
                    center: UnitPoint(x: 0.25, y: 0.12),
                    startRadius: 2,
                    endRadius: 120
                )
                .clipShape(shape)
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Palette.amber.opacity(playing ? 0.48 : 0.22), .white.opacity(0.06), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.15
                )
            }
        }
    }

    private func atelierTile<Art: View>(
        color: Color,
        title: String,
        subtitle: String,
        badge: String?,
        minHeight: CGFloat,
        dark: Bool,
        @ViewBuilder art: () -> Art
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                art()
                Spacer(minLength: 4)
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color(hex: 0x4A3300))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Palette.bead))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [color.opacity(dark ? 0.14 : 0.13), color.opacity(dark ? 0.03 : 0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .printCard(radius: Radius.card)
    }

    private func capsuleEnvelopeTile(dark: Bool) -> some View {
        atelierTile(
            color: Palette.bead,
            title: L10n.t("时光胶囊", "Time Capsules"),
            subtitle: capsuleReady > 0
                ? L10n.t("火漆待拆封", "Ready to unseal")
                : (capsuleTotal > 0
                    ? L10n.t("已封存 \(capsuleTotal) 封", "\(capsuleTotal) sealed")
                    : L10n.t("火漆写给未来", "Wax letters")),
            badge: capsuleReady > 0 ? L10n.t("\(capsuleReady) 封可拆", "\(capsuleReady) ready") : nil,
            minHeight: 102,
            dark: dark
        ) {
            WaxSealBadge(seal: .gold, size: 38)
        }
        .overlay {
            // Delicate envelope V-flap crease geometry echoing cotton-paper keepsake letters
            Canvas { ctx, size in
                var flap = Path()
                flap.move(to: CGPoint(x: 8, y: 0))
                flap.addLine(to: CGPoint(x: size.width * 0.5, y: size.height * 0.42))
                flap.addLine(to: CGPoint(x: size.width - 8, y: 0))
                ctx.stroke(
                    flap,
                    with: .color((dark ? Palette.amber : Crayon.caramel).opacity(dark ? 0.20 : 0.24)),
                    style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round)
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

private struct MiniAcousticBars: View {
    let reduce: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.scrolling) private var scrolling

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: reduce || Perf.still || scenePhase != .active || scrolling.moving)) { tl in
            let t = (reduce || Perf.still) ? 0.5 : tl.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    let h = 4 + 5 * (0.5 + 0.5 * sin(t * 4.2 + Double(i) * 1.4))
                    Capsule()
                        .fill(Color(hex: 0x3A2400))
                        .frame(width: 2.2, height: h)
                }
            }
            .frame(height: 10)
        }
        .accessibilityHidden(true)
    }
}

private struct MiniRhythmDialCanvas: View {
    let sleepSlices: [AtelierDockMetrics.RhythmSlice]
    let feedFractions: [Double]
    let dark: Bool

    var body: some View {
        ZStack {
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = min(size.width, size.height) / 2 - 4
                let track = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                ctx.stroke(track, with: .color(Crayon.lilac.opacity(dark ? 0.24 : 0.20)), lineWidth: 5)

                let arcs: [AtelierDockMetrics.RhythmSlice] = sleepSlices.isEmpty
                    ? [
                        .init(startFrac: 0.0, endFrac: 0.27),
                        .init(startFrac: 0.54, endFrac: 0.61),
                        .init(startFrac: 0.85, endFrac: 1.0)
                    ]
                    : sleepSlices
                let arcOpacity: Double = sleepSlices.isEmpty ? 0.34 : 0.92
                for s in arcs {
                    var p = Path()
                    p.addArc(
                        center: center,
                        radius: r,
                        startAngle: .degrees(-90 + s.startFrac * 360),
                        endAngle: .degrees(-90 + s.endFrac * 360),
                        clockwise: false
                    )
                    ctx.stroke(p, with: .color(Crayon.lilac.opacity(arcOpacity)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                }

                // Cardinal hour ticks (00, 06, 12, 18)
                for q in 0..<4 {
                    let a = CGFloat(q) * .pi / 2 - .pi / 2
                    let pt = CGPoint(x: center.x + cos(a) * (r - 6), y: center.y + sin(a) * (r - 6))
                    ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 1, y: pt.y - 1, width: 2, height: 2)), with: .color(Palette.secondaryText.opacity(0.45)))
                }

                // Feed event pips along inner track
                for f in feedFractions {
                    let a = CGFloat(f * 2 * .pi - .pi / 2)
                    let pt = CGPoint(x: center.x + cos(a) * (r - 6.5), y: center.y + sin(a) * (r - 6.5))
                    ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 2.3, y: pt.y - 2.3, width: 4.6, height: 4.6)), with: .color(Crayon.pink))
                }
            }
            Text("24h")
                .font(Typeface.numerals(10, relativeTo: .caption2, weight: .bold))
                .foregroundStyle(Palette.secondaryText)
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)
    }
}

private struct MiniFoodsWreathCanvas: View {
    let foods: FoodAtlasStore
    let dark: Bool

    var body: some View {
        let count = foods.tastedCount
        ZStack {
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let r = min(size.width, size.height) / 2 - 4
                let cats = FoodCategory.allCases
                let span = 360.0 / Double(cats.count)
                let gap = 10.0
                for (i, cat) in cats.enumerated() {
                    let startDeg = -90.0 + Double(i) * span + gap / 2
                    let fullEnd = -90.0 + Double(i + 1) * span - gap / 2
                    var bg = Path()
                    bg.addArc(center: center, radius: r, startAngle: .degrees(startDeg), endAngle: .degrees(fullEnd), clockwise: false)
                    ctx.stroke(bg, with: .color(cat.color.opacity(dark ? 0.24 : 0.22)), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))

                    let done = foods.tastedCount(in: cat)
                    let total = max(1, foods.totalCount(in: cat))
                    if done > 0 {
                        let frac = min(1.0, Double(done) / Double(total))
                        let activeEnd = startDeg + (fullEnd - startDeg) * frac
                        var fg = Path()
                        fg.addArc(center: center, radius: r, startAngle: .degrees(startDeg), endAngle: .degrees(activeEnd), clockwise: false)
                        ctx.stroke(fg, with: .color(cat.color), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                    }
                }
            }
            Text("\(count)")
                .font(Typeface.numerals(13, relativeTo: .caption, weight: .bold))
                .foregroundStyle(.primary)
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)
    }
}

private struct MiniXylophoneArt: View {
    let dark: Bool

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            // Birch side rails
            let leftRail = Path(roundedRect: CGRect(x: 9, y: 4, width: 3.5, height: h - 8), cornerRadius: 1.5)
            let rightRail = Path(roundedRect: CGRect(x: w - 12.5, y: 4, width: 3.5, height: h - 8), cornerRadius: 1.5)
            let birch = Color(hex: dark ? 0xC69C6D : 0xD6AC7A)
            ctx.fill(leftRail, with: .color(birch))
            ctx.fill(rightRail, with: .color(birch))

            let colors: [Color] = [Crayon.pink, Crayon.lilac, Crayon.sky, Crayon.teal, Crayon.sunflower]
            let barH: CGFloat = 5.4
            let spacing: CGFloat = 2.0
            let totalH = CGFloat(colors.count) * barH + CGFloat(colors.count - 1) * spacing
            let startY = (h - totalH) / 2
            for (idx, c) in colors.enumerated() {
                let inset = CGFloat(colors.count - 1 - idx) * 2.1
                let rect = CGRect(x: 4 + inset, y: startY + CGFloat(idx) * (barH + spacing), width: w - 8 - inset * 2, height: barH)
                ctx.fill(Path(roundedRect: rect, cornerRadius: barH / 2), with: .color(c))
                // Tiny brass rivets
                let rivetColor = Palette.beadLight
                ctx.fill(Path(ellipseIn: CGRect(x: rect.minX + 4, y: rect.midY - 0.9, width: 1.8, height: 1.8)), with: .color(rivetColor))
                ctx.fill(Path(ellipseIn: CGRect(x: rect.maxX - 5.8, y: rect.midY - 0.9, width: 1.8, height: 1.8)), with: .color(rivetColor))
            }
        }
        .frame(width: 52, height: 42)
        .accessibilityHidden(true)
    }
}

private struct MiniStorybookStackArt: View {
    let month: Int
    let dark: Bool

    var body: some View {
        let cover = ArtIndex.shared.cover(min(max(month, 0), 36)).flatMap {
            Perf.noArt ? nil : (ArtCache.shared.cached($0, maxPixel: 256) ?? ArtCache.shared.image($0, maxPixel: 256))
        }
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(dark ? Color(hex: 0x29335C) : Color(hex: 0xF5EBDC))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Crayon.caramel.opacity(0.35), lineWidth: 0.8)
                )
                .frame(width: 44, height: 34)
                .rotationEffect(.degrees(5))
                .offset(x: 4, y: 2)

            ZStack {
                if let cover {
                    Image(uiImage: cover)
                        .resizable()
                        .scaledToFill()
                } else {
                    Crayon.caramel.opacity(0.35)
                }
            }
            .frame(width: 42, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            .padding(2.5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(dark ? Color(hex: 0xECE5D8) : .white)
                    .shadow(color: .black.opacity(0.14), radius: 2, y: 1)
            )
            .overlay(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Palette.bead)
                    .frame(width: 5, height: 9)
                    .offset(x: -5, y: -2)
            }
            .rotationEffect(.degrees(-4))
        }
        .frame(width: 50, height: 38)
        .accessibilityHidden(true)
    }
}

/// What is due this month and not yet done — vaccines and check-ups — as one line that opens them; shown only while
/// something is left, so the home is quiet when nothing is.
private struct DueCard: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.dynamicTypeSize) private var type
    let month: Int
    var body: some View {
        let dark = lamp || scheme == .dark
        let mo = app.content.month(month)
        let total = mo.vaccines.count + mo.checkups.count
        let done = app.count(month, TickKind.vaccine) + app.count(month, TickKind.checkup)
        let earlier = app.duePending(before: month).count
        let dotsCount = max(1, min(total, 8))
        if total > done || earlier > 0 {
            NavigationLink(value: Route.care(month)) {
                HStack(spacing: 12) {
                    IconTile(symbol: "syringe.fill", color: Crayon.pink, size: 34)
                    VStack(alignment: .leading, spacing: 5) {
                        if type.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L10n.t("本月接种与儿保", "Vaccines & Check-ups"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if earlier > 0 {
                                    dueBadge(earlier, dark: dark)
                                }
                            }
                        } else {
                            HStack(spacing: 6) {
                                Text(L10n.t("本月接种与儿保", "Vaccines & Check-ups"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                if earlier > 0 {
                                    dueBadge(earlier, dark: dark)
                                }
                            }
                        }

                        HStack(spacing: 6) {
                            HStack(spacing: 4) {
                                ForEach(0..<dotsCount, id: \.self) { idx in
                                    Circle()
                                        .fill(idx < done ? Crayon.pink : Color.clear)
                                        .overlay(
                                            Circle().strokeBorder(Crayon.pink.opacity(idx < done ? 0 : 0.45), lineWidth: 1.2)
                                        )
                                        .frame(width: 7, height: 7)
                                }
                            }
                            Text("\(done) / \(total)")
                                .font(.caption2.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(Palette.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                }
                .padding(12)
                .printCard(radius: Radius.card)
            }
            .buttonStyle(.toy)
        }
    }

    @ViewBuilder
    private func dueBadge(_ earlier: Int, dark: Bool) -> some View {
        Text(L10n.t("待补 \(earlier)", "+\(earlier) due"))
            .font(.caption2.weight(.bold))
            .foregroundStyle(dark ? Palette.amber : Crayon.ink(Crayon.tangerine))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Crayon.tangerine.opacity(dark ? 0.22 : 0.16)))
    }
}

/// Now: what the baby is doing, from the parent's own records, and what that means for play — the one place where
/// the care log and the picture book meet. Asleep: the companions sleep too, and one tap says the baby woke. Feeding:
/// how long, and the timer. Awake: said in 今天一起玩's own header (醒了 40 分钟 · 一起玩), not in a card of its own.
/// At night, the last feed, waking and nappy. Only facts from the records; no predictions. Hidden when there is
/// nothing to say.
private struct NowCard: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.night) private var night
    @Environment(\.lamp) private var lamp
    let month: Int
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { tl in
            let now = tl.date.timeIntervalSince1970 * 1000
            if let sleep = j.timers.first(where: { $0.type == LogType.sleep }) {
                // waking is recorded on the sleep's own page (one place to start and end a timer)
                Button { j.focus = LogType.sleep } label: {
                    card(tint: Crayon.lilac) {
                        Duo(primary: app.companion, size: 44, mood: .sleep, night: true)
                        words(
                            sleep.pausedAt != nil ? L10n.timerStatus(LogType.sleep, side: nil, paused: true) : L10n.t("宝宝在睡觉", "Baby is sleeping"),
                            L10n.t("已经睡了 " + durationValue(sleep.total(now)) + " · 醒了点这里记下", "Asleep " + L10n.duration(sleep.total(now)) + " · Tap when awake")
                        )
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.toy)
            } else if let feed = j.timers.first(where: { $0.type == LogType.nurse }) {
                Button { j.focus = LogType.nurse } label: {
                    card(tint: Crayon.pink) {
                        IconTile(symbol: LogType.symbol(LogType.nurse), color: Crayon.pink, size: 40)
                        words(
                            feed.pausedAt != nil ? L10n.timerStatus(LogType.nurse, side: feed.side, paused: true) : L10n.t("正在亲喂" + (feed.side == "r" ? " · 右侧" : " · 左侧"), "Nursing" + (feed.side == "r" ? " · Right" : " · Left")),
                            L10n.t("已经 " + durationValue(feed.total(now)), L10n.duration(feed.total(now)) + " elapsed")
                        )
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.toy)
            } else if night && !j.logs.isEmpty {
                // at night, with nothing running: the three things asked at 2 a.m. — when the last feed was, when the
                // baby last woke, the last nappy — each one tap from recording the next
                HStack(spacing: 8) {
                    fact(LogType.nurse, "care/nurse", tl.date)
                    fact(LogType.sleep, "care/sleep", tl.date)
                    fact(LogType.diaper, "log/diaper", tl.date)
                }
            }
        }
    }
    @Environment(\.openURL) private var openURL
    private func fact(_ type: String, _ link: String, _ now: Date) -> some View {
        let f = LastLine.fact(type, in: j.logs)
        let c = LogType.color(type)
        let fallbackLabel = L10n.t("上次" + LogType.name(type), "Last " + L10n.logName(type).lowercased())
        return Button { if let u = URL(string: "mossling://" + link) { openURL(u) } } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    IconTile(symbol: LogType.symbol(type), color: c, size: 20, round: true)
                    Text(L10n.isEnglish ? fallbackLabel : (f?.label ?? fallbackLabel)).font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText).lineLimit(1).minimumScaleFactor(0.8)
                }
                Text(f.map { L10n.agoText($0.at, now: now) } ?? "—").font(Typeface.numerals(17, relativeTo: .headline, weight: .bold)).foregroundStyle(Crayon.ink(c))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(c.opacity(0.14)).printCard(radius: Radius.inner)
        }
        .buttonStyle(.toy)
        .accessibilityHint(L10n.t("记下一次" + LogType.name(type), "Log " + L10n.logName(type).lowercased()))
    }
    private func words(_ a: String, _ b: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(a).font(.headline).foregroundStyle(.primary)
            Text(b).font(.subheadline).foregroundStyle(Palette.secondaryText).lineLimit(2).multilineTextAlignment(.leading)
        }
    }
    private func card<C: View>(tint: Color, @ViewBuilder _ c: () -> C) -> some View {
        HStack(spacing: 12) { c() }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.16)).printCard(radius: Radius.card)
    }
}

/// 「蒙氏成长航线明信片 / Journey Passport Card」 — Picture-book 4:3 month postcard paired with the live 37-station bead chain.
private struct MonthCard: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var scheme
    @Environment(\.night) private var night
    @Environment(\.lamp) private var lamp
    @Environment(\.dynamicTypeSize) private var type
    let month: Int, baby: Int
    let open: () -> Void

    var body: some View {
        let dark = lamp || scheme == .dark
        let isNight = night || lamp
        let land = Land.of(month)
        let monthFrac = (month == baby) ? (app.age.map { JourneyStripMetrics.monthProgressFraction(days: $0.days, toNext: $0.toNext) } ?? 0) : 0
        let countdown: String? = (month == baby) ? app.age.flatMap { a in
            a.toNext > 0 && month < 36 ? L10n.t("\(a.toNext) 天后满 \(month + 1) 个月", "\(a.toNext)d to mo \(month + 1)") : nil
        } : nil
        let layout = type.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .center, spacing: 12))

        Button(action: open) {
            VStack(alignment: .leading, spacing: 11) {
                layout {
                    MonthPostcardArt(
                        month: month,
                        festive: month == baby && app.age?.days == 0 && app.age != nil,
                        night: isNight,
                        width: type.isAccessibilitySize ? 96 : 104
                    )

                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Label(land.name, systemImage: land.symbol)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(dark ? land.crayon : Crayon.ink(land.crayon))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(land.crayon.opacity(dark ? 0.22 : 0.16)))

                                if month != baby {
                                    Text(month < baby ? L10n.t("走过的一站", "Past") : L10n.t("以后的一站", "Ahead"))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Palette.secondaryText)
                                } else if let a = app.age {
                                    Text(L10n.livedDays(a.lived))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Palette.secondaryText)
                                        .monospacedDigit()
                                } else {
                                    Text(L10n.t("0–3 岁地图", "0–3y Map"))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Palette.secondaryText)
                                }
                            }

                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text(month == 0 ? L10n.t("出生", "Birth") : "\(month)")
                                    .font(Typeface.numerals(34, relativeTo: .largeTitle, weight: .bold))
                                if month > 0 {
                                    Text(L10n.t("个月", "mo")).font(.subheadline.weight(.semibold))
                                }
                                if month == baby, let d = app.age?.days, d > 0 {
                                    Text("\(d)")
                                        .font(Typeface.numerals(18, relativeTo: .headline, weight: .bold))
                                        .padding(.leading, 2)
                                    Text(L10n.t("天", "d")).font(.subheadline.weight(.semibold))
                                }
                            }

                            Text(app.content.month(month).title)
                                .font(.subheadline)
                                .foregroundStyle(Palette.secondaryText)
                                .lineLimit(type.isAccessibilitySize ? nil : 2)
                                .truncationMode(.tail)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)

                MiniJourneyBeadStrip(
                    month: month,
                    monthFraction: monthFrac,
                    hasBirth: app.age != nil,
                    countdownText: countdown,
                    dark: dark,
                    night: isNight
                )
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [land.crayon.opacity(dark ? 0.14 : 0.12), Crayon.sunflower.opacity(dark ? 0.03 : 0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .printCard(radius: Radius.card)
        }
        .buttonStyle(.toy)
        .accessibilityLabel("\(month == 0 ? L10n.t("出生", "Birth") : L10n.t("\(month) 个月", "\(month) months")), \(app.content.month(month).title)")
        .accessibilityHint(L10n.t("打开串珠旅程与本月指南", "Open 37-station Journey and month guide"))
    }
}

/// The month's plays as picture cards: the one done least (the natural next one) leads, full width.
/// Two to a row, each cell half the width (a lone last cell the whole width). Its ideal width is twice the widest
/// cell's: inside ViewThatFits it is chosen only when every cell — every name — fits whole in its half.
struct PairGrid: Layout {
    var spacing: CGFloat = 10
    private func widest(_ subviews: Subviews) -> CGFloat { subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0 }
    private func cellWidths(_ n: Int, _ width: CGFloat) -> [CGFloat] {
        let half: CGFloat = (width - spacing) / 2
        return (0..<n).map { i in (i == n - 1 && n % 2 == 1) ? width : half }
    }
    private func rowHeights(_ subviews: Subviews, _ width: CGFloat) -> [CGFloat] {
        let w = cellWidths(subviews.count, width)
        var out: [CGFloat] = []
        var i = 0
        while i < subviews.count {
            let pair: Bool = i + 1 < subviews.count
            var h: CGFloat = subviews[i].sizeThatFits(ProposedViewSize(width: w[i], height: nil)).height
            if pair { h = max(h, subviews[i + 1].sizeThatFits(ProposedViewSize(width: w[i + 1], height: nil)).height) }
            out.append(h)
            i += pair ? 2 : 1
        }
        return out
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideal: CGFloat = widest(subviews) * 2 + spacing
        let width: CGFloat = proposal.width.map { $0.isFinite ? $0 : ideal } ?? ideal
        let hs = rowHeights(subviews, width)
        return CGSize(width: width, height: hs.reduce(0, +) + spacing * CGFloat(max(0, hs.count - 1)))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let w = cellWidths(subviews.count, bounds.width), hs = rowHeights(subviews, bounds.width)
        var y = bounds.minY, i = 0, r = 0
        while i < subviews.count {
            let pair = i + 1 < subviews.count
            subviews[i].place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: w[i], height: hs[r]))
            if pair { subviews[i + 1].place(at: CGPoint(x: bounds.minX + w[i] + spacing, y: y), proposal: ProposedViewSize(width: w[i + 1], height: hs[r])) }
            y += hs[r] + spacing; i += pair ? 2 : 1; r += 1
        }
    }
}

struct PlaysLeadGrid: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.dynamicTypeSize) private var type
    let plays: [Play], month: Int
    var body: some View {
        // a stable order: not yet done first, then the fewest times
        let ordered = plays.enumerated().sorted { a, b in
            let x = app.record(a.element, j).count, y = app.record(b.element, j).count
            return x != y ? x < y : a.offset < b.offset
        }.map(\.element)
        // two to a row, all alike (no full-width lead picture): a month's plays read in one screen
        // two to a row when every name fits whole on its line; otherwise one under the other (a Chinese name broken
        // in the middle of a word reads wrong, and the phone's width decides, not the content)
        let list = VStack(spacing: 10) { ForEach(ordered) { PlayTileLink(play: $0, month: month, form: .row) } }
        if type.isAccessibilitySize {
            list
        } else {
            ViewThatFits(in: .horizontal) {
                PairGrid(spacing: 10) { ForEach(ordered) { PlayTileLink(play: $0, month: month, form: .mini) } }
                list
            }
        }
    }
}


/// The topics' marks: all five are care topics, so one colour (the care area's), told apart by their symbols.
let topicMarks: [(String, Color)] = ["moon.zzz.fill", "bed.double.fill", "fork.knife", "mouth.fill", "cross.case.fill"].map { ($0, Palette.area("F")) }

/// The topics, as one card of rows: a mark, the title, where it comes from, a chevron.
struct Topics: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        let items = app.content.topics.enumerated().map { TopicItem(i: $0.offset, t: $0.element) }
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: L10n.t("专题", "Guides"), detail: L10n.t("照护参考", "Care Reference"))
            // one card of rows: each title whole on its line, nothing wrapped mid-word, no row half filled
            Box {
                ForEach(items) { x in
                    NavigationLink(value: Route.topic(x.t.id)) {
                        BoxRow(symbol: topicMarks[x.i % topicMarks.count].0, color: topicMarks[x.i % topicMarks.count].1, title: x.t.title, last: x.i == items.count - 1, opens: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct TopicItem: Identifiable { let i: Int; let t: Topic; var id: String { t.id } }

/// 今天一起玩 — the heart of the app when nothing is recorded (docs/IP.md §3). The header is the answer: one play for
/// today, large — the picture of its first step, its area and how many steps, its name, the first step, when it was
/// last played — and under it the week's others (「这周还有」), each a tray and its gold beads for the times played
/// this week (a count, never a score). The week turns by itself; 换一个 takes the next of the week for the rest of the
/// day; 调整 changes the week. When the records say the baby is awake the header says so — 醒了 40 分钟 · 一起玩 — and
/// while a sleep is being timed, 醒来后一起玩: facts from the records, no predictions. At night Otto's lamp throws a
/// warm pool over the card cleanly without cluttering the artwork.
struct TodayPlayCard: View {
    @Environment(AppModel.self) private var app
    @Environment(\.night) private var night
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var envLamp
    @Environment(\.dynamicTypeSize) private var size
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(JournalStore.self) private var j
    let month: Int
    var soundscapeActive: Bool = false
    var openLamp: () -> Void = {}
    var story: () -> Void = {}
    let arrange: () -> Void
    private var flat: Bool { ArtStyle.current == .flat }

    var body: some View {
        let week = app.weekShelf(month).plays
        let today = app.todayPlay(month, j)
        let rest = week.filter { $0.code != today?.code }
        let asleep = j.timers.contains { $0.type == LogType.sleep }
        if let p = today {
            TimelineView(.periodic(from: .now, by: 60)) { tl in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 8) {
                        GoldBead(size: 10)
                        Text(title(asleep: asleep, now: tl.date)).font(.title3.weight(.bold)).accessibilityAddTraits(.isHeader)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        if week.count > 1 {
                            Button { withAnimation(reduce ? nil : .spring(response: 0.38, dampingFraction: 0.84)) { app.anotherToday(month, j) } } label: {
                                // the words stay small; the place to tap is a full 44 points (HIG: hit targets)
                                Text(L10n.t("换一个", "Swap")).padding(.horizontal, 8).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                            }
                            .font(.subheadline.weight(.semibold)).padding(.vertical, -12).padding(.trailing, -8)
                            .accessibilityHint(L10n.t("在这周的几个活动里换一个", "Swap to another play this week"))
                        }
                    }
                    .padding(.horizontal, 4).padding(.top, 6)
                    VStack(spacing: 0) {
                        lead(p)
                            .id(p.code)
                            .transition(reduce ? .identity : .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.97)).combined(with: .offset(y: 6)),
                                removal: .opacity.combined(with: .scale(scale: 0.985))
                            ))
                        if !rest.isEmpty {
                            Divider().padding(.horizontal, 14)
                            HStack {
                                Text(L10n.t("这周还有", "Also this week")).font(.footnote.weight(.semibold)).foregroundStyle(Palette.secondaryText).accessibilityAddTraits(.isHeader)
                                Spacer(minLength: 4)
                                Button(action: arrange) { Text(L10n.t("调整", "Edit")).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
                                    .font(.footnote.weight(.semibold)).padding(.vertical, -12)
                                    .accessibilityHint(L10n.t("换这周的活动", "Adjust this week's plays"))
                            }
                            .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 2)
                            ForEach(rest) { other($0) }
                        } else {
                            Button(action: arrange) { Text(L10n.t("调整这周的活动", "Adjust this week's plays")).font(.footnote.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44) }
                        }
                    }
                    .padding(.bottom, 4)
                    .background(alignment: .top) { if night { LampPool() } }
                    .printCard(radius: Radius.card)
                }
                .sensoryFeedback(.selection, trigger: p.code)
            }
        }
    }

    /// 今天一起玩; 醒了 40 分钟 · 一起玩 while the records say the baby woke within six hours (by day, records on);
    /// 醒来后一起玩 while a sleep is being timed.
    private func title(asleep: Bool, now: Date) -> String {
        guard app.journal else { return L10n.t("今天一起玩", "Today's Play") }
        if asleep { return L10n.t("醒来后一起玩", "Play After Nap") }
        if !night, let woke = j.logs.first(where: { $0.type == LogType.sleep && $0.end != nil })?.end {
            let s = (now.timeIntervalSince1970 * 1000 - woke) / 1000
            if s >= 0 && s < 6 * 3600 { return L10n.t("醒了 " + durationValue(s) + " · 一起玩", "Awake " + L10n.duration(s) + " · Play") }
        }
        return L10n.t("今天一起玩", "Today's Play")
    }

    private func route(_ p: Play) -> Route { Route.play(p.code, month) }

    /// Today's play — clean crisp 4:3 picture-book hero stage with bold title & Step 1 cue below (zero stray floating orbs).
    private func lead(_ p: Play) -> some View {
        let big = size.isAccessibilitySize
        let times: Int = app.thisWeek(p, j)
        let last: String = lastPlayed(p)
        let label: String = L10n.t("今天一起玩", "Today's Play") + ", " + p.name + ", " + (p.domains.first ?? "") + ", " + L10n.t("\(p.steps.count) 步", "\(p.steps.count) steps") + ", " + last
        return NavigationLink(value: route(p)) {
            VStack(alignment: .leading, spacing: 12) {
                leadArt(p, big: big)
                leadWords(p, last: last, times: times, big: big)
                    .padding(.horizontal, 4)
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.toy)
        .contextMenu { PlayActions(play: p, month: month) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityHint(L10n.t("打开，一步步跟着图玩", "Open step-by-step guide"))
    }

    private func lastPlayed(_ p: Play) -> String {
        let rec = app.record(p, j)
        // a play ticked done before plays were dated: played, but when is not known
        guard let d = rec.last else { return rec.count > 0 ? L10n.t("玩过", "Played") : L10n.t("第一次玩", "First time") }
        return Day(d) == app.today ? L10n.t("今天玩过", "Played today") : L10n.t("上次 " + Day(d).md, "Last \(Day(d).m)/\(Day(d).d)")
    }

    @ViewBuilder private func leadArt(_ p: Play, big: Bool) -> some View {
        let key = Palette.areaKey(of: p)
        let darkStage = night || envLamp || scheme == .dark
        let toneInk = darkStage ? Palette.area(key).mix(with: .white, by: 0.25) : Palette.areaInk(key)

        if let livingScript = LivingBookCatalog.script(for: p.code) {
            LivingBookStage(
                script: livingScript,
                stepIndex: 0,
                companion: app.companion,
                dark: darkStage,
                accent: Palette.area(key),
                posterPhase: nil,
                interactive: false,
                compact: false
            )
            .zoomSource(route(p))
        } else {
            let action = StepKineticAction.infer(
                stepText: p.steps.first ?? ActivityMotionIndex.spec(for: p).cue,
                stepIndex: 0,
                stepCount: p.steps.count,
                template: ActivityMotionIndex.spec(for: p).template
            )
            let firstStepArt = ArtIndex.shared.steps(p.code).first
            let shownName = firstStepArt.map { ArtIndex.variant($0, girl: app.drawsGirl) }
            let readyImg = shownName.flatMap { name in
                Perf.noArt ? nil : (ArtCache.shared.cached(name, maxPixel: 800) ?? ArtCache.shared.image(name, maxPixel: 800))
            }

            ZStack(alignment: .bottomLeading) {
                Color(hex: darkStage ? 0x161E3D : 0xFAF4E8)

                if let readyImg {
                    Image(uiImage: readyImg)
                        .resizable()
                        .scaledToFit()
                } else if let art = firstStepArt {
                    ArtFill(name: art, label: p.name)
                } else {
                    TrayTile(code: p.code, color: Palette.area(key), flat: flat)
                }

                if darkStage {
                    Color(hex: 0x0A1026).opacity(0.22)
                }

                StepKineticOverlay(
                    action: action,
                    accent: Palette.area(key),
                    dark: darkStage,
                    pulseAt: .distantPast,
                    pulseOrigin: nil,
                    reduce: reduce
                )
                .allowsHitTesting(false)

                HStack(spacing: 5) {
                    Image(systemName: action.symbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(toneInk)
                    Text(action.label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(darkStage ? Palette.lampInk : Palette.text)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill((darkStage ? Palette.lampCard : .white).opacity(0.90)))
                .overlay(Capsule().strokeBorder(Palette.area(key).opacity(darkStage ? 0.42 : 0.32), lineWidth: 0.75))
                .padding(10)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(firstStepArt.map { ArtIndex.shared.ratio($0) } ?? (4.0 / 3.0), contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .strokeBorder(Palette.area(key).opacity(darkStage ? 0.35 : 0.25), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
            )
            .zoomSource(route(p))
        }
    }

    private func leadWords(_ p: Play, last: String, times: Int, big: Bool) -> some View {
        let key = Palette.areaKey(of: p)
        let area: String = (p.domains.first ?? "") + " · " + L10n.t("\(p.steps.count) 步", "\(p.steps.count) steps")
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                IconTile(symbol: Palette.areaSymbol(key), color: Palette.area(key), size: 16)
                Text(area).font(.caption.weight(.semibold)).foregroundStyle(Palette.areaInk(key)).lineLimit(1)
            }
            Text(p.name).font(.headline).foregroundStyle(.primary)
                .lineLimit(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            if let step = p.steps.first {
                Text(L10n.t("第 1 步 · ", "Step 1 · ") + step).font(.caption).foregroundStyle(Palette.secondaryText)
                    .lineLimit(big ? 4 : 2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                Text(last).font(.caption2.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                if times > 0 { BeadCount(times: times) }
            }
            .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One of the week's others: its tray, its name, its beads this week (nothing while there are none).
    private func other(_ p: Play) -> some View {
        let key = Palette.areaKey(of: p), times = app.thisWeek(p, j)
        return NavigationLink(value: route(p)) {
            HStack(spacing: 12) {
                TrayTile(code: p.code, color: Palette.area(key), flat: flat)
                    .frame(width: 44, height: 33)
                    .zoomSource(route(p))
                Text(p.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    .lineLimit(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if times > 0 { BeadCount(times: times) }
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.toy)
        .contextMenu { PlayActions(play: p, month: month) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(otherLabel(p, times))
    }
    private func otherLabel(_ p: Play, _ times: Int) -> String {
        let area: String = p.domains.first ?? ""
        return p.name + ", " + area + (times > 0 ? L10n.t("，这周玩过 \(times) 次", ", \(times)x this week") : "")
    }
}

/// A tray on a tile of its area's colour: in 3D a soft lit vinyl tile (lighter at the top, a fine lit rim), in 2D one
/// flat colour of paper with a crisp edge below.
struct TrayTile: View {
    let code: String
    let color: Color
    let flat: Bool
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        let dark = scheme == .dark
        ZStack {
            if flat {
                shape.fill(color.mix(with: dark ? Palette.lampCard : .white, by: dark ? 0.68 : 0.78))
                    .background(shape.fill(color.opacity(dark ? 0.35 : 0.3)).offset(y: 2))
            } else {
                shape.fill(LinearGradient(colors: [color.mix(with: dark ? Palette.lampCard : .white, by: dark ? 0.62 : 0.86), color.mix(with: dark ? Palette.lampCard : .white, by: dark ? 0.75 : 0.7)],
                                          startPoint: .top, endPoint: .bottom))
                    .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(dark ? 0.15 : 0.9), .white.opacity(0)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
            }
            Figure(name: "tray_\(code.lowercased()).webp").aspectRatio(4 / 3, contentMode: .fit).padding(4)
        }
        .accessibilityHidden(true)
    }
}

/// Times played, as gold beads on a short string (Montessori's golden bead): up to five, then the number.
private struct BeadCount: View {
    let times: Int
    var body: some View {
        HStack(spacing: 3) {
            if times > 0 {
                ForEach(0..<min(times, 5), id: \.self) { _ in
                    Circle().fill(RadialGradient(colors: [Palette.beadLight, Palette.bead], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 6))
                        .frame(width: 9, height: 9)
                }
                Text(L10n.t("\(times) 次", "\(times)x")).font(Typeface.numerals(11, relativeTo: .caption2, weight: .semibold)).foregroundStyle(Palette.lampTint).padding(.leading, 2)
            }
        }
        .accessibilityHidden(true)
    }
}

/// At night, Otto's lamp on the card's edge throws a warm pool down over the trays (a drawing of light only).
private struct LampPool: View {
    var body: some View {
        RadialGradient(colors: [Palette.amber.opacity(0.28), Palette.amber.opacity(0)], center: UnitPoint(x: 0.82, y: 0), startRadius: 0, endRadius: 320)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Arranging the shelf, as a sheet.
struct ShelfEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sheetPath = NavigationPath()
    var body: some View {
        NavigationStack(path: $sheetPath) {
            PlanView(path: $sheetPath)
                .routes(path: $sheetPath)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.t("完成", "Done"), systemImage: "checkmark") { dismiss() } } }
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

/// The child's date of birth.
struct BirthSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var date = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
    /// Asked the first time only: whether to keep the day's records too (the 记录 tab), so a parent of a newborn has
    /// the feeds, sleeps and nappies from the start rather than finding them later behind a switch.
    @State private var first = false
    @State private var records = true
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        Duo(primary: app.companion, size: 46)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("孩子的第一天", "Baby's Day One"))
                                .font(.headline)
                            Text(L10n.t("我们从这一天开始，一月一站陪着长大。", "Your 37-month journey starts from this gentle date."))
                                .font(.caption)
                                .foregroundStyle(Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 2)
                    .listRowBackground(Color.clear)
                }
                Section {
                    DatePicker(L10n.t("出生日期", "Birthday"), selection: $date, in: Calendar.current.date(byAdding: .year, value: -4, to: Date())!...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
                if first {
                    Section {
                        Toggle(L10n.t("也记录喂奶、睡眠、尿布", "Also track feeds, sleep & diapers"), isOn: $records)
                    } footer: { Text(L10n.t("打开后多一个「记录」页；以后在「我的」里随时可以开关。", "Adds a Log tab; you can toggle it anytime in Me.")) }
                }
            }
            .scrollContentBackground(.hidden)
            .pageBackground(tone: Palette.bead)
            .navigationTitle(L10n.t("出生日期", "Birthday")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.t("取消", "Cancel"), systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(L10n.t("完成", "Done"), systemImage: "checkmark") { if first { app.journal = records }; app.birth = Day(date); dismiss() } }
            }
            .onAppear { if let b = app.birth { date = b.date }; first = !app.onboarded && app.birth == nil }
        }
        .presentationDetents([.large])
    }
}
