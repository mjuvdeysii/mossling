import SwiftUI
import TipKit

/// Pure Moss Exploration Home (`摸索 / Explore`):
/// Holds strictly what helps parent and child explore together right now:
/// 1) Serene compact `ExploreGreetingStrip` (with cross-tab switch to `留念` Journey when desired),
/// 2) `TodayPlayCard` (Play together today with live 3D soft-vinyl × 2D watercolor stage + 4 weekly plays),
/// 3) Two-card `SensoryDiscoveryDock` (Sensory Toybox + First Foods Atlas).
/// Sleep/feeds/lamp/rhythm live on `台灯 (Lamp)`, keepsakes/month guide/growth/due checkups live on `留念 (Keepsakes)`.
struct TodayView: View {
    @Environment(AppModel.self) private var app
    @Environment(AppRouter.self) private var router: AppRouter?
    @Environment(JournalStore.self) private var j
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.night) private var night
    @Environment(\.dynamicTypeSize) private var type
    @Binding var path: NavigationPath
    @State private var askBirth = false
    @State private var arranging = false
    @State private var foods = FoodAtlasStore.shared
    private let shelfTip = ShelfTip()

    var body: some View {
        let baby = app.babyMonth ?? 0
        let dark = lamp || scheme == .dark
        let careWatch = app.journal ? CareWatchSummary.recent24h(in: j.logs) : nil

        ScrollView {
            VStack(alignment: .leading, spacing: LayoutSpec.cardGap) {
                if app.age == nil {
                    Button { if app.mayKeep() { askBirth = true } } label: { Label(L10n.t("填写出生日期，从宝宝这个月开始", "Add baby's birthday to begin"), systemImage: "calendar.badge.plus").frame(maxWidth: .infinity) }
                        .buttonStyle(.vinyl(Palette.accentFill, prominent: true, large: true))
                }
                ExploreGreetingStrip(month: baby, baby: baby, isNight: night || lamp) {
                    TactileEngine.shared.beadClick()
                    router?.openKeepsakes(.month(baby))
                }
                if let careWatch, app.careModeActive || careWatch.hasFever || careWatch.latestMed != nil {
                    careSanctuaryCard(watch: careWatch, dark: dark)
                }
                if app.age != nil { TipView(shelfTip) }
                TodayPlayCard(
                    month: baby,
                    arrange: { arranging = true }
                )
                sensoryDiscoveryDock(dark: dark)
                LampCardSpotlightCard(card: LampCardCatalog.spotlight(forMonth: baby, day: app.today), dark: dark)
                if baby >= 36 { StoryGoesOn(primary: app.companion) }
            }
            .padding(.top, 8)
            .padding(.horizontal, LayoutSpec.pageH)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.sunflower)
        .navigationTitle(app.nickname.isEmpty ? L10n.t("摸索", "Explore") : app.nickname)
        .navigationBarTitleDisplayMode(.inline)
        .navigationSubtitle(app.age == nil ? "\(app.today.md) \(app.today.weekday)" : "")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: ExploreRoute.search) { Image(systemName: "magnifyingglass") }
                    .accessibilityLabel(L10n.t("搜索", "Search"))
            }
        }
        .sheet(isPresented: $askBirth) { BirthSheet().lampPresented() }
        .sheet(isPresented: $arranging) { ShelfEditor().lampPresented() }
    }

    @ViewBuilder
    private func careSanctuaryCard(watch: CareWatchSummary, dark: Bool) -> some View {
        let alertColor: Color = watch.hasFever ? Palette.danger : Crayon.teal
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                IconTile(symbol: watch.hasFever ? "thermometer.high" : "cross.case.fill", color: alertColor, size: 28, round: true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(watch.hasFever ? L10n.t("24h 体温与照护看护", "24h Fever & Care Watch") : L10n.t("柔和照护模式", "Care Sanctuary Mode"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(L10n.t("近期有体温或用药记录，随时单手补记", "Recent fever or medicine logged — quick 1-tap follow-up"))
                        .font(.caption2)
                        .foregroundStyle(Palette.secondaryText)
                }
                Spacer(minLength: 4)
                if app.careModeActive {
                    Button(L10n.t("收起", "Done")) {
                        TactileEngine.shared.beadClick()
                        withAnimation(.snappy) { app.careModeActive = false }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Crayon.ink(Crayon.teal))
                    .buttonStyle(.plain)
                }
            }

            if let temp = watch.latestTemp {
                HStack(spacing: 6) {
                    Circle().fill(watch.hasFever ? Palette.danger : Crayon.tangerine).frame(width: 7, height: 7)
                    Text(L10n.t("体温 \(hm(temp.startDate)) · \(temp.summary)", "Temp \(hm(temp.startDate)) · \(temp.summary)"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(watch.hasFever ? Palette.danger : .primary)
                }
            }
            if let med = watch.latestMed {
                let medText = med.summary.isEmpty ? LogType.name(LogType.medicine) : med.summary
                HStack(spacing: 6) {
                    Circle().fill(Crayon.teal).frame(width: 7, height: 7)
                    Text(L10n.t("用药 \(hm(med.startDate)) · \(medText)", "Med \(hm(med.startDate)) · \(medText)"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }

            WrapLayout(spacing: 8) {
                Button {
                    guard app.mayKeep() else { return }
                    TactileEngine.shared.beadClick()
                    router?.openLamp(nil)
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(110))
                        j.ask = LogType.temp
                    }
                } label: {
                    Label(L10n.t("记体温", "Log Temp"), systemImage: LogType.symbol(LogType.temp))
                        .dsPill(.tinted(watch.hasFever ? Crayon.cherry : Crayon.tangerine), height: 34)
                }
                .buttonStyle(.toy)

                Button {
                    guard app.mayKeep() else { return }
                    TactileEngine.shared.beadClick()
                    router?.openLamp(nil)
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(110))
                        j.ask = LogType.medicine
                    }
                } label: {
                    Label(L10n.t("记用药", "Log Med"), systemImage: LogType.symbol(LogType.medicine))
                        .dsPill(.tinted(Crayon.teal), height: 34)
                }
                .buttonStyle(.toy)
            }
        }
        .padding(LayoutSpec.cardPad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .printCard(radius: Radius.card, fill: alertColor.opacity(dark ? 0.16 : 0.08))
    }

    @ViewBuilder
    private func sensoryDiscoveryDock(dark: Bool) -> some View {
        let cols = type.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: LayoutSpec.gridGap), GridItem(.flexible(), spacing: LayoutSpec.gridGap)]
        let foodsTasted = foods.tastedCount
        let toyTodayCount = ToyboxUsage.todayCount(on: app.today)

        LazyVGrid(columns: cols, spacing: LayoutSpec.gridGap) {
            NavigationLink(value: ExploreRoute.toybox(.xylophone)) {
                discoveryTile(
                    color: Crayon.teal,
                    title: L10n.t("感官玩具盒", "Toybox"),
                    subtitle: toyTodayCount > 0
                        ? L10n.t("今日玩了 \(toyTodayCount) 次", "\(toyTodayCount) today")
                        : L10n.t("5 种感官玩具", "5 sensory toys"),
                    dark: dark
                ) {
                    MiniXylophoneArt(dark: dark)
                        .scaleEffect(0.76)
                        .frame(width: 40, height: 34)
                }
            }
            .buttonStyle(.toy)

            NavigationLink(value: ExploreRoute.foodAtlas) {
                discoveryTile(
                    color: Crayon.leaf,
                    title: L10n.t("百味食盒", "First Foods"),
                    subtitle: foodsTasted > 0
                        ? L10n.t("已尝 \(foodsTasted) / \(FoodItem.catalog.count)", "\(foodsTasted) / \(FoodItem.catalog.count) tasted")
                        : L10n.t("60 种辅食图鉴", "60 foods atlas"),
                    dark: dark
                ) {
                    MiniFoodsWreathCanvas(foods: foods, dark: dark)
                        .scaleEffect(0.76)
                        .frame(width: 38, height: 38)
                }
            }
            .buttonStyle(.toy)
        }
    }

    private func discoveryTile<Art: View>(
        color: Color,
        title: String,
        subtitle: String,
        dark: Bool,
        @ViewBuilder art: () -> Art
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(dark ? 0.22 : 0.12))
                    art()
                }
                .frame(width: 44, height: 44)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(Typeface.label(11, relativeTo: .caption2, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .tracking(LayoutSpec.titleTracking)
                    .foregroundStyle(.primary)
                    .lineLimit(type.isAccessibilitySize ? nil : 2)
                    .minimumScaleFactor(type.isAccessibilitySize ? 1.0 : 0.88)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(type.isAccessibilitySize ? nil : 2)
                    .minimumScaleFactor(type.isAccessibilitySize ? 1.0 : 0.88)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [color.opacity(dark ? 0.20 : 0.14), color.opacity(dark ? 0.05 : 0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .printCard(radius: Radius.card)
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

/// Compact greeting strip at the top of `Explore` linking cleanly across tabs to `留念 (Keepsakes)` without cloning `MonthView` on Tab 0.
struct ExploreGreetingStrip: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.dynamicTypeSize) private var type
    let month: Int
    let baby: Int
    let isNight: Bool
    let openKeepsakes: () -> Void

    private var foods: FoodAtlasStore { FoodAtlasStore.shared }
    private var stickerVersion: FoodStickerVersion { FoodStickerVersion.shared }

    private func todayTastedFoods() -> [FoodItem] {
        let todayEpoch = app.today.epochDay
        return FoodItem.catalog.filter { item in
            foods.record(for: item.id)?.firstTastedEpochDay == todayEpoch
        }
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        let land = Land.of(month)
        let mo = app.content.month(month)
        let _ = stickerVersion.tick
        let todayFoods = !isNight ? Array(todayTastedFoods().prefix(2)) : []
        let hasPlayToday = !isNight && j.logs(on: app.today).contains(where: { $0.type == LogType.play })

        Button(action: openKeepsakes) {
            let layout = type.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: .center, spacing: LayoutSpec.iconTextGap))
            layout {
                MonthPostcardArt(
                    month: month,
                    festive: month == baby && app.age?.days == 0 && app.age != nil,
                    night: isNight,
                    width: type.isAccessibilitySize ? 58 : 48
                )

                VStack(alignment: .leading, spacing: 5) {
                    FlowRow(spacing: 6, lineSpacing: 4) {
                        Label(land.name, systemImage: land.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(dark ? land.crayon : Crayon.ink(land.crayon))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(land.crayon.opacity(dark ? 0.22 : 0.16)))
                            .fixedSize(horizontal: true, vertical: false)

                        if let a = app.age {
                            Text(L10n.ageText(a))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.primary)
                                .monospacedDigit()
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        } else {
                            Text(L10n.t("0–3 岁旅程", "0–3y Journey"))
                                .font(.footnote)
                                .foregroundStyle(Palette.secondaryText)
                                .lineLimit(1)
                        }

                        if !todayFoods.isEmpty || hasPlayToday {
                            HStack(spacing: -4) {
                                ForEach(todayFoods) { food in
                                    FoodEmblemArt(food: food, size: 15)
                                        .frame(width: 17, height: 17)
                                        .background(Circle().fill(dark ? Palette.lampCard : .white))
                                        .overlay(Circle().strokeBorder(food.category.color.opacity(0.45), lineWidth: 0.8))
                                }
                                if hasPlayToday {
                                    GoldBead(size: 10)
                                        .frame(width: 17, height: 17)
                                        .background(Circle().fill(dark ? Palette.lampCard : .white))
                                        .overlay(Circle().strokeBorder(Palette.amber.opacity(0.45), lineWidth: 0.8))
                                }
                            }
                            .accessibilityHidden(true)
                        }
                    }

                    Text(mo.title)
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(type.isAccessibilitySize ? nil : 2)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !type.isAccessibilitySize {
                    Spacer(minLength: 4)
                }

                HStack(spacing: 3) {
                    Text(L10n.t("旅程", "Journey"))
                    Image(systemName: "chevron.right")
                        .font(Typeface.label(11, relativeTo: .caption2, weight: .semibold))
                }
                .dsPill(.tinted(Palette.accent), height: 30, horizontalPadding: 10)
            }
            .padding(.horizontal, LayoutSpec.cardPad)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [land.crayon.opacity(dark ? 0.14 : 0.10), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .printCard(radius: Radius.card)
        }
        .buttonStyle(.toy)
        .accessibilityLabel(L10n.t("当前月龄第 \(month) 站，\(mo.title)，前往留念查看月龄指南与成长足迹", "Station \(month), \(mo.title), switch to Keepsakes tab"))
    }
}

struct MiniRhythmDialCanvas: View {
    let sleepSlices: [AtelierDockMetrics.RhythmSlice]
    let feedFractions: [Double]
    let dark: Bool

    var body: some View {
        ZStack {
            Canvas(rendersAsynchronously: false) { ctx, size in
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
                .font(Typeface.numerals(11, relativeTo: .caption2, weight: .bold))
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
            Canvas(rendersAsynchronously: false) { ctx, size in
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
        Canvas(rendersAsynchronously: false) { ctx, size in
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

/// What is due this month and not yet done — vaccines and check-ups — as one line that opens them; shown only while
/// something is left, so the home is quiet when nothing is.
struct DueCard: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.dynamicTypeSize) private var type
    let month: Int
    var body: some View {
        let dark = lamp || scheme == .dark
        let region = app.healthRegion
        let mo = app.content.month(month)
        let regItems = region == .cn ? [] : HealthRegion.schedule(for: region, month: month)
        let total = region == .cn ? (mo.vaccines.count + mo.checkups.count) : regItems.count
        let done = region == .cn
            ? (app.count(month, TickKind.vaccine) + app.count(month, TickKind.checkup))
            : regItems.filter { item in
                let kind = item.kind == "vaccine" ? TickKind.vaccine : TickKind.checkup
                return app.ticked(month, kind, "reg-\(region.rawValue)-\(item.id)")
            }.count
        let earlier = region == .cn ? app.duePending(before: month).count : 0
        let dotsCount = max(1, min(total, 8))
        if total > done || earlier > 0 {
            NavigationLink(value: KeepsakesRoute.care(month)) {
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
                    NavigationLink(value: KeepsakesRoute.topic(x.t.id)) {
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
                VStack(alignment: .leading, spacing: LayoutSpec.sectionHeaderGap) {
                    HStack(alignment: .center, spacing: 8) {
                        GoldBead(size: 9)
                        Text(title(asleep: asleep, now: tl.date))
                            .font(DS.TypeScale.sectionHeader)
                            .tracking(LayoutSpec.sectionTracking)
                            .accessibilityAddTraits(.isHeader)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        if week.count > 1 {
                            Button {
                                withAnimation(reduce ? nil : .spring(response: 0.38, dampingFraction: 0.84)) {
                                    app.anotherToday(month, j)
                                }
                            } label: {
                                Text(L10n.t("换一个", "Swap"))
                                    .dsPill(.tinted(Palette.accent), height: 30, horizontalPadding: 11)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(L10n.t("在这周的几个活动里换一个", "Swap to another play this week"))
                        }
                    }
                    .padding(.horizontal, 2).padding(.top, 2)
                    VStack(spacing: 0) {
                        lead(p)
                            .id(p.code)
                            .transition(reduce ? .identity : .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.97)).combined(with: .offset(y: 6)),
                                removal: .opacity.combined(with: .scale(scale: 0.985))
                            ))
                        if !rest.isEmpty {
                            Divider().padding(.horizontal, LayoutSpec.cardPadHero)
                            HStack(alignment: .center) {
                                Text(L10n.t("这周还有", "Also this week"))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Palette.secondaryText)
                                    .accessibilityAddTraits(.isHeader)
                                Spacer(minLength: 4)
                                Button(action: arrange) {
                                    Text(L10n.t("调整", "Edit"))
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Palette.accent)
                                        .lineLimit(1)
                                        .fixedSize()
                                        .padding(.horizontal, 10)
                                        .frame(minHeight: 30)
                                        .pillHitTarget()
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint(L10n.t("换这周的活动", "Adjust this week's plays"))
                            }
                            .padding(.horizontal, LayoutSpec.cardPadHero)
                            .padding(.top, 10)
                            .padding(.bottom, 2)

                            VStack(spacing: 0) {
                                ForEach(Array(rest.enumerated()), id: \.element.id) { idx, item in
                                    other(item, isLast: idx == rest.count - 1)
                                }
                            }
                            .padding(.bottom, 6)
                        } else {
                            Button(action: arrange) {
                                Text(L10n.t("调整这周的活动", "Adjust this week's plays"))
                                    .font(.footnote.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: LayoutSpec.hitMin)
                                    .contentShape(Rectangle())
                            }
                        }
                    }
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

    private func route(_ p: Play) -> ExploreRoute { ExploreRoute.play(p.code, month) }

    /// Today's play — clean crisp 4:3 picture-book hero stage with bold title & Step 1 cue below (zero stray floating orbs).
    private func lead(_ p: Play) -> some View {
        let big = size.isAccessibilitySize
        let times: Int = app.thisWeek(p, j)
        let last: String = lastPlayed(p)
        let label: String = L10n.t("今天一起玩", "Today's Play") + ", " + p.name + ", " + (p.domains.first ?? "") + ", " + L10n.t("\(p.steps.count) 步", "\(p.steps.count) steps") + ", " + last
        return NavigationLink(value: route(p)) {
            VStack(alignment: .leading, spacing: 0) {
                leadArt(p, big: big)
                leadWords(p, last: last, times: times, big: big)
                    .padding(.horizontal, LayoutSpec.cardPadHero)
                    .padding(.top, 16)
                    .padding(.bottom, 18)
            }
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
                compact: false,
                edgeToEdge: true
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
            .clipped()
            .zoomSource(route(p))
        }
    }

    private func leadWords(_ p: Play, last: String, times: Int, big: Bool) -> some View {
        let key = Palette.areaKey(of: p)
        let area: String = (p.domains.first ?? "") + " · " + L10n.t("\(p.steps.count) 步", "\(p.steps.count) steps")
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                IconTile(symbol: Palette.areaSymbol(key), color: Palette.area(key), size: 16)
                Text(area)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Palette.areaInk(key))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(last)
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
                if times > 0 { BeadCount(times: times) }
            }
            Text(p.name)
                .font(.title3.weight(.bold))
                .tracking(LayoutSpec.titleTracking)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            if let step = p.steps.first {
                Text(L10n.t("第 1 步 · ", "Step 1 · ") + step)
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
                    .lineSpacing(3)
                    .lineLimit(big ? 4 : 2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One of the week's others: clean hairline list row with artwork thumb, title, domain metadata & gold beads.
    private func other(_ p: Play, isLast: Bool = false) -> some View {
        let key = Palette.areaKey(of: p), times = app.thisWeek(p, j)
        return VStack(spacing: 0) {
            NavigationLink(value: route(p)) {
                HStack(spacing: 12) {
                    ActivityPreviewThumb(play: p, color: Palette.area(key), flat: flat, cornerRadius: Radius.chip)
                        .frame(width: 52, height: 39)
                        .zoomSource(route(p))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(size.isAccessibilitySize ? 2 : 1)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if let d = p.domains.first {
                            Text(d)
                                .font(.footnote)
                                .foregroundStyle(Palette.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 4)

                    if times > 0 { BeadCount(times: times) }

                    Image(systemName: "chevron.right")
                        .font(Typeface.label(11, relativeTo: .caption2, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, LayoutSpec.cardPadHero)
                .padding(.vertical, 10)
                .frame(minHeight: 60)
                .contentShape(Rectangle())
            }
            .buttonStyle(.toy)
            .contextMenu { PlayActions(play: p, month: month) }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(otherLabel(p, times))

            if !isLast {
                Divider()
                    .padding(.leading, LayoutSpec.cardPadHero + 64)
                    .padding(.trailing, LayoutSpec.cardPadHero)
            }
        }
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
                Text(L10n.t("\(times) 次", "\(times)x")).font(Typeface.numerals(11, relativeTo: .caption2, weight: .semibold)).foregroundStyle(Crayon.ink(Palette.bead)).padding(.leading, 2)
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
                .exploreRoutes(path: $sheetPath)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.t("完成", "Done"), systemImage: "checkmark") { dismiss() } } }
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .localConsentSheet()
    }
}

/// The child's date of birth.
struct BirthSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var date = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
    /// Asked the first time only: whether to keep the day's records too (under 台灯), so a parent of a newborn has
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
                    } footer: { Text(L10n.t("打开后会在「台灯」下方显示喂睡与尿布轻记；以后在「工坊」里随时可以开关。", "Enables feeding, sleep & diaper quick logs under Lamp; toggle anytime in Studio.")) }
                }
            }
            .scrollContentBackground(.hidden)
            .pageBackground(tone: Palette.bead)
            .navigationTitle(L10n.t("出生日期", "Birthday")).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.t("取消", "Cancel"), systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(L10n.t("完成", "Done"), systemImage: "checkmark") { guard app.mayKeep() else { return }; if first { app.journal = records }; app.birth = Day(date); dismiss() } }
            }
            .onAppear { if let b = app.birth { date = b.date }; first = !app.onboarded && app.birth == nil }
        }
        .presentationDetents([.large])
        .localConsentSheet()
    }
}
