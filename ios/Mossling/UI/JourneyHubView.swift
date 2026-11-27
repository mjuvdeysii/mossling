import SwiftUI

/// Pure math helpers for the 37-station Montessori bead strip (`0...36` months across 3 Lands).
enum JourneyStripMetrics {
    static let totalStations = 37

    static func clampedMonth(_ month: Int) -> Int {
        max(0, min(totalStations - 1, month))
    }

    static func stationOrdinal(month: Int) -> Int {
        clampedMonth(month) + 1
    }

    static func normalizedPosition(month: Int) -> Double {
        Double(clampedMonth(month)) / Double(totalStations - 1)
    }

    static func monthProgressFraction(days: Int, toNext: Int) -> Double {
        let total = days + toNext
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(days) / Double(total)))
    }
}

/// Pure, testable keepsake shelf & Land progress calculations for Tab 3 (`JourneyHubView`).
enum JourneyKeepsakeMetrics {
    static func normalizedWeights(from measures: [Measure], limit: Int = 6) -> [Double] {
        let sorted = measures
            .compactMap { m -> (at: Double, weightG: Double)? in
                guard let g = m.weightG, g > 0 else { return nil }
                return (m.at, Double(g))
            }
            .sorted { $0.at < $1.at }
        let recent = Array(sorted.suffix(max(1, limit)))
        guard !recent.isEmpty else { return [] }
        if recent.count == 1 { return [0.55] }
        let weights = recent.map(\.weightG)
        guard let minW = weights.min(), let maxW = weights.max() else { return [] }
        let span = maxW - minW
        if span < 1.0 {
            return Array(repeating: 0.55, count: weights.count)
        }
        return weights.map { 0.15 + 0.70 * (($0 - minW) / span) }
    }

    static func latestWeightText(from measures: [Measure]) -> String? {
        let latest = measures
            .filter { ($0.weightG ?? 0) > 0 }
            .max { $0.at < $1.at }
        guard let g = latest?.weightG, g > 0 else { return nil }
        return String(format: "%.1f kg", Double(g) / 1000.0)
    }

    static func landProgress(land: Land, babyMonth: Int, hasBirth: Bool) -> (lived: Int, total: Int) {
        let range: ClosedRange<Int> = switch land {
        case .meadow: 0...11
        case .forest: 12...23
        case .river: 24...36
        }
        guard hasBirth else { return (0, range.count) }
        let m = JourneyStripMetrics.clampedMonth(babyMonth)
        let lived = range.filter { $0 <= m }.count
        return (lived, range.count)
    }
}

/// 4:3 Picture-Book Month Cover Postcard replacing the legacy square map vignette across Today & JourneyHub.
struct MonthPostcardArt: View {
    let month: Int
    var festive: Bool = false
    var night: Bool = false
    var width: CGFloat = 104
    var radius: CGFloat = 12

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let m = JourneyStripMetrics.clampedMonth(month)
        let dark = night || scheme == .dark
        let height = width * 0.75

        LivingMonthCoverStage(
            month: m,
            dark: dark,
            festive: festive,
            posterPhase: LivingMonthCoverCatalog.script(for: m).posterPhase,
            interactive: false,
            compact: true
        )
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: radius + 3, style: .continuous)
                .fill(dark ? Color(hex: 0x222B4E) : Color(hex: 0xFFFDF8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: radius + 3, style: .continuous)
                .strokeBorder(
                    night ? Palette.amber.opacity(0.34) : (dark ? .white.opacity(0.12) : Color(hex: 0xCBB799).opacity(0.45)),
                    lineWidth: 0.9
                )
        )
        .overlay(alignment: .topLeading) {
            if night {
                Image(systemName: "moon.stars.fill")
                    .font(Typeface.label(11, relativeTo: .caption2, weight: .bold))
                    .foregroundStyle(Palette.amber)
                    .padding(4)
                    .background(Circle().fill(Color(hex: 0x0E1430).opacity(0.75)))
                    .offset(x: 6, y: 6)
            }
        }
        .shadow(color: dark ? .black.opacity(0.28) : Color(hex: 0x7A5230).opacity(0.14), radius: 5, y: 2.5)
        .rotationEffect(.degrees(-1.2))
        .accessibilityHidden(true)
    }
}

/// Interactive-looking 37-station Montessori bead chain summarizing 0–3 years in a single glanceable visual strip.
struct MiniJourneyBeadStrip: View {
    let month: Int
    var monthFraction: Double = 0
    var hasBirth: Bool = true
    var countdownText: String? = nil
    var dark: Bool = false
    var night: Bool = false

    @Environment(\.dynamicTypeSize) private var type

    var body: some View {
        let m = JourneyStripMetrics.clampedMonth(month)
        let ordinal = JourneyStripMetrics.stationOrdinal(month: m)
        let frac = hasBirth && m < 36 ? max(0, min(1, monthFraction)) : 0
        let posStations = CGFloat(m) + CGFloat(frac)

        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let pad: CGFloat = 8
                let usable = max(1, geo.size.width - pad * 2)
                let xOf: (CGFloat) -> CGFloat = { station in pad + min(36, max(0, station)) / 36.0 * usable }
                let cy = geo.size.height / 2
                let liveX = xOf(posStations)
                let activeX = xOf(CGFloat(m))

                ZStack {
                    // Three contiguous land tracks: Meadow (0..12), Forest (12..24), River (24..36)
                    ForEach([(0, 12, Crayon.leaf), (12, 24, Crayon.tangerine), (24, 36, Crayon.sky)], id: \.0) { start, end, col in
                        let sx = xOf(CGFloat(start))
                        let ex = xOf(CGFloat(end))
                        Capsule()
                            .fill(col.opacity(dark ? 0.24 : 0.20))
                            .frame(width: max(2, ex - sx), height: 3.5)
                            .position(x: (sx + ex) / 2, y: cy)

                        if hasBirth && liveX > sx {
                            let fillEnd = min(ex, liveX)
                            Capsule()
                                .fill(col.opacity(dark ? 0.85 : 0.78))
                                .frame(width: max(2, fillEnd - sx), height: 3.5)
                                .position(x: (sx + fillEnd) / 2, y: cy)
                        }
                    }

                    // 37 bead markers (year landmarks 0, 12, 24, 36 slightly larger)
                    ForEach(0..<JourneyStripMetrics.totalStations, id: \.self) { i in
                        if i != m {
                            let isLandmark = i == 0 || i == 12 || i == 24 || i == 36
                            let past = hasBirth && i < m
                            let landCol = Land.of(min(i, 35)).crayon
                            let d: CGFloat = isLandmark ? 6.5 : 3.4
                            Circle()
                                .fill(past ? landCol : (dark ? Color.white.opacity(0.18) : Palette.outline.opacity(0.28)))
                                .frame(width: d, height: d)
                                .overlay {
                                    if isLandmark && !past {
                                        Circle().strokeBorder(landCol.opacity(0.65), lineWidth: 1.2)
                                    }
                                }
                                .position(x: xOf(CGFloat(i)), y: cy)
                        }
                    }

                    // Current station golden Montessori bead with subtle warm aura
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [(night ? Palette.amber : Palette.bead).opacity(0.45), .clear],
                                center: .center,
                                startRadius: 1,
                                endRadius: 11
                            )
                        )
                        .frame(width: 22, height: 22)
                        .position(x: activeX, y: cy)

                    GoldBead(size: 12)
                        .position(x: activeX, y: cy)
                }
            }
            .frame(height: 22)

            // Year anchor ticks aligned below 0, 1y, 2y, 3y
            HStack {
                Text(L10n.t("0", "0"))
                Spacer()
                Text(L10n.t("1岁", "1y"))
                Spacer()
                Text(L10n.t("2岁", "2y"))
                Spacer()
                Text(L10n.t("3岁", "3y"))
            }
            .font(Typeface.label(11, relativeTo: .caption2, weight: .semibold))
            .foregroundStyle(Palette.secondaryText.opacity(0.85))
            .monospacedDigit()
            .padding(.horizontal, 4)

            // Concise station counter + countdown status
            Group {
                if type.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 2) {
                        if let countdownText, !countdownText.isEmpty {
                            Text(countdownText)
                                .font(.caption)
                                .foregroundStyle(Palette.secondaryText)
                        }
                        stationPill(ordinal: ordinal)
                    }
                } else {
                    HStack(spacing: 6) {
                        if let countdownText, !countdownText.isEmpty {
                            Text(countdownText)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Palette.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        } else {
                            Text(L10n.t("37 站串珠小路", "37-Station Bead Path"))
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(Palette.secondaryText)
                        }
                        Spacer(minLength: 4)
                        stationPill(ordinal: ordinal)
                    }
                }
            }
            .padding(.top, 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t("第 \(ordinal) / 37 站", "Station \(ordinal) of 37") + (countdownText.map { "，\($0)" } ?? ""))
    }

    private func stationPill(ordinal: Int) -> some View {
        Text(L10n.t("第 \(ordinal) / 37 站", "\(ordinal) / 37"))
            .font(.footnote.weight(.bold))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(night || dark ? Palette.amber : Crayon.ink(Palette.bead))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Palette.bead.opacity(dark ? 0.24 : 0.16))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Palette.bead.opacity(dark ? 0.36 : 0.26), lineWidth: 0.75)
            )
    }
}

/// Halo 3: Unified Vertical 「串珠小路 · Journey」 combining the current age station, a 2×2 Keepsake Shelf
/// (Storybook, Polaroid Firsts, Wax-Sealed Capsules, WHO Growth Curves), and the 37-station vertical winding bead chain
/// across 草地 (0–1 yr), 森林小丘 (1–2 yrs), and 小河村庄 (2–3 yrs) — with zero horizontal scrolling.
struct JourneyHubView: View {
    var isRootTab: Bool = false
    var initialExpandedLands: Set<Land>? = nil

    @Environment(AppModel.self) private var app
    @Environment(AppRouter.self) private var router: AppRouter?
    @Environment(JournalStore.self) private var j
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.dynamicTypeSize) private var type

    @State private var scope: StationScope = .all
    @State private var quietBeads = false
    @State private var showingStorybook = false
    @State private var expandedLandsOverride: Set<Land>? = nil
    @State private var capsules = CapsuleStore.shared
    @State private var photoVersion = FirstPhotoVersion.shared
    @State private var showingClinicSnapshot = false

    enum StationScope: String, CaseIterable, Identifiable {
        case all, lived
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: L10n.t("全部 37", "All 37")
            case .lived: L10n.t("已走过", "Lived")
            }
        }
    }

    private var baby: Int { max(0, min(app.babyMonth ?? 0, 36)) }
    private var dark: Bool { lamp || scheme == .dark }
    private var flat: Bool { ArtStyle.current == .flat }
    private var activeExpandedLands: Set<Land> {
        expandedLandsOverride ?? initialExpandedLands ?? []
    }

    private var visibleLands: [Land] {
        if scope == .lived && app.birth != nil {
            return Land.allCases.filter { landStart($0) <= baby }
        }
        return Land.allCases
    }

    private func landStart(_ land: Land) -> Int {
        switch land {
        case .meadow: 0
        case .forest: 12
        case .river: 24
        }
    }

    private func months(in land: Land) -> [Int] {
        let range: ClosedRange<Int> = switch land {
        case .meadow: 0...11
        case .forest: 12...23
        case .river: 24...36
        }
        if scope == .lived && app.birth != nil {
            return range.filter { $0 <= baby }
        }
        return Array(range)
    }

    var body: some View {
        let _ = photoVersion.tick
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: LayoutSpec.cardGap) {
                    currentStationHero()

                    keepsakeShelf

                    if app.age != nil {
                        DueCard(month: app.actualAge?.bookMonth ?? baby)
                        upcomingCheckupPrepBanner
                    }

                    // Compact Bead Journey header bar + inline filters (zero horizontal scrolling)
                    Group {
                        if type.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L10n.t("串珠小路 · 37 站", "Bead Journey · 37 Stations"))
                                    .font(.headline.weight(.bold))
                                    .tracking(LayoutSpec.sectionTracking)
                                    .foregroundStyle(.primary)
                                FlowRow(spacing: 6, lineSpacing: 6) { beadFilterPills }
                            }
                        } else {
                            HStack(spacing: 8) {
                                Text(L10n.t("串珠小路 · 37 站", "Bead Journey · 37"))
                                    .font(.headline.weight(.bold))
                                    .tracking(LayoutSpec.sectionTracking)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 4)
                                beadFilterPills
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                    .padding(.top, 6)

                    // Collapsible vertical winding Montessori bead chain grouped by the 3 Lands (all collapsed by default)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(visibleLands, id: \.rawValue) { land in
                            let list = months(in: land)
                            if !list.isEmpty {
                                landSection(land: land, months: list)
                            }
                        }
                    }

                    if baby >= 36 {
                        StoryGoesOn(primary: app.companion)
                    }
                }
                .padding(.horizontal, LayoutSpec.pageH)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .calmWhileScrolling()
            .pageBackground(tone: Land.of(baby).crayon)
            .navigationTitle(L10n.t("留念", "Keepsakes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        TactileEngine.shared.beadClick()
                        var next = activeExpandedLands
                        next.insert(Land.of(baby))
                        withAnimation(reduce ? nil : CalmMotion.accordionSpring) {
                            expandedLandsOverride = next
                        }
                        Task { @MainActor in
                            await Task.yield()
                            withAnimation(reduce ? nil : .spring(response: 0.48, dampingFraction: 0.82)) {
                                proxy.scrollTo("station-\(baby)", anchor: .center)
                            }
                        }
                    } label: {
                        Label(L10n.t("回到现在", "Now"), systemImage: "scope")
                    }
                    .accessibilityLabel(L10n.t("滚动到宝宝现在这一站", "Scroll to baby's current station"))
                }
            }
            .fullScreenCover(isPresented: $showingStorybook) {
                StorybookView().lampPresented(sheet: false)
            }
            .sheet(isPresented: $showingClinicSnapshot) {
                ClinicSnapshotSheet().lampPresented()
            }
        }
    }

    @ViewBuilder
    private var upcomingCheckupPrepBanner: some View {
        if let upcoming = HealthRegion.daysUntilNextCheckup(birth: app.birth, today: app.today),
           upcoming.daysRemaining <= 7 {
            let timing = upcoming.daysRemaining <= 0
                ? L10n.t("满 \(upcoming.month) 月龄儿保窗口就在这几天", "\(upcoming.month)-month well-child window is here")
                : L10n.t("还有 \(upcoming.daysRemaining) 天就是 \(upcoming.month) 月龄儿保", "\(upcoming.daysRemaining)d until \(upcoming.month)-month checkup")
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    IconTile(symbol: "stethoscope", color: Crayon.teal, size: 32, round: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timing)
                            .font(.subheadline.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                        if let cue = HealthRegion.screeningCue(for: HealthRegion.defaultRegion(), month: upcoming.month) {
                            Text(cue)
                                .font(.caption)
                                .foregroundStyle(Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                Button {
                    TactileEngine.shared.beadClick()
                    showingClinicSnapshot = true
                } label: {
                    Label(L10n.t("行前备忘：生成诊室一页摘要 PDF", "Prep Clinic Snapshot PDF"), systemImage: "doc.text.magnifyingglass")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(Crayon.teal))
                }
                .buttonStyle(.toy)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .printCard(radius: Radius.card, fill: dark ? Palette.lampCard : Palette.card)
        }
    }

    @ViewBuilder
    private var beadFilterPills: some View {
        if app.birth != nil {
            DSSegmentedControl(
                items: StationScope.allCases,
                selection: $scope,
                dark: dark,
                compact: true,
                title: { $0.title },
                onSelect: { item in
                    if item == .lived {
                        expandedLandsOverride = Set(Land.allCases)
                    }
                }
            )
        }

        Button {
            TactileEngine.shared.beadClick()
            withAnimation(reduce ? nil : .snappy) { quietBeads.toggle() }
        } label: {
            Label(
                L10n.t("静谧", "Quiet"),
                systemImage: quietBeads ? "circle.fill" : "circle.dotted"
            )
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(quietBeads ? (dark ? Palette.amber : Crayon.ink(Palette.bead)) : .primary)
            .padding(.horizontal, 11)
            .frame(minHeight: 34)
            .background(
                Capsule(style: .continuous)
                    .fill(quietBeads ? Palette.bead.opacity(dark ? 0.24 : 0.16) : DS.Surface.warmInset(dark: dark))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(quietBeads ? Palette.bead.opacity(0.42) : DS.Surface.hairline(dark: dark), lineWidth: 0.6)
            )
            .pillHitTarget(LayoutSpec.hitMin)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("静谧珠链", "Quiet Beads"))
        .accessibilityAddTraits(quietBeads ? .isSelected : [])
    }

    // MARK: - Section 1: Compact Current Station Hero

    private func currentStationHero() -> some View {
        let mo = app.content.month(baby)
        let land = Land.of(baby)
        let monthFrac = app.age.map { JourneyStripMetrics.monthProgressFraction(days: $0.days, toNext: $0.toNext) } ?? 0
        let countdown: String? = app.age.flatMap { a in
            a.toNext > 0 && baby < 36
                ? L10n.t("\(a.toNext) 天后满 \(baby + 1) 个月", "\(a.toNext)d to mo \(baby + 1)")
                : nil
        }
        let headerLayout = type.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))

        return VStack(alignment: .leading, spacing: 14) {
            headerLayout {
                MonthPostcardArt(
                    month: baby,
                    festive: app.age?.days == 0 && app.age != nil,
                    night: lamp,
                    width: type.isAccessibilitySize ? 82 : 66
                )

                VStack(alignment: .leading, spacing: 4) {
                    FlowRow(spacing: 6, lineSpacing: 4) {
                        Label(land.name, systemImage: land.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(dark ? land.crayon : Crayon.ink(land.crayon))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(land.crayon.opacity(dark ? 0.22 : 0.16)))
                            .fixedSize(horizontal: true, vertical: false)

                        if let a = app.age {
                            Text(L10n.livedDays(a.lived))
                                .font(.footnote)
                                .foregroundStyle(Palette.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(baby == 0 ? L10n.t("出生", "Birth") : "\(baby)")
                            .font(Typeface.numerals(24, relativeTo: .title2, weight: .bold))
                        if baby > 0 {
                            Text(L10n.t("个月", "mo"))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Palette.secondaryText)
                        }
                        if let d = app.age?.days, d > 0 {
                            Text("\(d)")
                                .font(Typeface.numerals(24, relativeTo: .title2, weight: .bold))
                                .padding(.leading, 3)
                            Text(L10n.t("天", "d"))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Palette.secondaryText)
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
                    monthGuidePill
                }
            }

            if type.isAccessibilitySize {
                monthGuidePill
            }

            MiniJourneyBeadStrip(
                month: baby,
                monthFraction: monthFrac,
                hasBirth: app.age != nil,
                countdownText: countdown,
                dark: dark,
                night: lamp
            )
        }
        .padding(LayoutSpec.cardPadHero)
        .background(
            LinearGradient(
                colors: [land.crayon.opacity(dark ? 0.16 : 0.13), Palette.bead.opacity(dark ? 0.08 : 0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .printCard(radius: Radius.card)
    }

    private var monthGuidePill: some View {
        NavigationLink(value: KeepsakesRoute.month(baby)) {
            HStack(spacing: 4) {
                Image(systemName: "book.closed.fill")
                    .font(Typeface.label(11, relativeTo: .caption2, weight: .semibold))
                Text(L10n.t("月龄指南", "Guide"))
                Image(systemName: "chevron.right")
                    .font(Typeface.label(11, relativeTo: .caption2, weight: .semibold))
            }
            .dsPill(.primary, height: 34, horizontalPadding: 12)
        }
        .buttonStyle(.toy)
        .accessibilityLabel(L10n.t("本月发育要点与活动", "This Month's Guide"))
    }

    // MARK: - Section 2: 2×2 Montessori Keepsake Cabinet (Zero Horizontal Scroll)

    private var keepsakeShelf: some View {
        let cols = type.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: LayoutSpec.gridGap), GridItem(.flexible(), spacing: LayoutSpec.gridGap)]
        let bookMonths = app.birth != nil ? max(1, min(app.age?.bookMonth ?? 0, 36) + 1) : 0
        let capsuleTotal = capsules.items.count
        let capsuleReady = capsules.readyCount(on: app.today)
        let latestSeal = capsules.items.first?.seal ?? .gold
        let weights = JourneyKeepsakeMetrics.normalizedWeights(from: j.measures)
        let latestWeight = JourneyKeepsakeMetrics.latestWeightText(from: j.measures)

        return LazyVGrid(columns: cols, spacing: LayoutSpec.gridGap) {
            Button {
                TactileEngine.shared.pageTurn()
                if let router {
                    router.openStorybook()
                } else {
                    showingStorybook = true
                }
            } label: {
                shelfTile(
                    title: L10n.t("成长绘本", "Storybook"),
                    detail: app.birth != nil
                        ? L10n.t("已收录 \(bookMonths) 个月", "\(bookMonths) mo collected")
                        : L10n.t("填生日开启", "Add birthday"),
                    tint: Crayon.caramel
                ) {
                    MiniStorybookArtifact(month: baby, dark: dark)
                        .scaleEffect(0.84)
                }
            }
            .buttonStyle(.toy)

            NavigationLink(value: KeepsakesRoute.firsts) {
                shelfTile(
                    title: L10n.t("第一次相纸", "Firsts"),
                    detail: j.firsts.isEmpty
                        ? L10n.t("记下珍贵瞬间", "Polaroid moments")
                        : L10n.t("已留存 \(j.firsts.count) 个", "\(j.firsts.count) captured"),
                    tint: Crayon.pink
                ) {
                    MiniPolaroidArtifact(latestFirst: j.firsts.first, dark: dark)
                        .scaleEffect(0.84)
                }
            }
            .buttonStyle(.toy)

            NavigationLink(value: KeepsakesRoute.capsules) {
                shelfTile(
                    title: L10n.t("时光胶囊", "Time Capsules"),
                    detail: capsuleReady > 0
                        ? L10n.t("\(capsuleReady) 封可拆封", "\(capsuleReady) ready now")
                        : (capsuleTotal > 0
                            ? L10n.t("已封存 \(capsuleTotal) 封", "\(capsuleTotal) sealed")
                            : L10n.t("火漆写给未来", "Wax-sealed")),
                    tint: Palette.bead
                ) {
                    MiniCapsuleEnvelopeArtifact(seal: latestSeal, readyCount: capsuleReady, dark: dark)
                        .scaleEffect(0.84)
                }
            }
            .buttonStyle(.toy)

            NavigationLink(value: KeepsakesRoute.growth) {
                shelfTile(
                    title: L10n.t("生长曲线", "Growth Curves"),
                    detail: latestWeight ?? L10n.t("WHO 百分位", "WHO curves"),
                    tint: Crayon.leaf
                ) {
                    MiniGrowthCurveArtifact(weights: weights, dark: dark)
                        .scaleEffect(0.84)
                }
            }
            .buttonStyle(.toy)
        }
    }

    private func shelfTile<Icon: View>(
        title: String,
        detail: String,
        tint: Color,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                icon()
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(Typeface.label(11, relativeTo: .caption2, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .tracking(LayoutSpec.titleTracking)
                    .foregroundStyle(.primary)
                    .lineLimit(type.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(type.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.86)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [tint.opacity(dark ? 0.20 : 0.14), tint.opacity(dark ? 0.05 : 0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .printCard(radius: Radius.card)
    }

    // MARK: - Section 3: Vertical Winding Bead Chain

    private func landCoverMonth(for land: Land) -> Int {
        switch land {
        case .meadow: 4
        case .forest: 16
        case .river: 28
        }
    }

    private func landTagline(for land: Land) -> String {
        switch land {
        case .meadow: L10n.t("轻抱与初视 · 从第一天起慢慢熟络", "Warm holds & first gazes · gentle beginnings")
        case .forest: L10n.t("指物与学步 · 用小手和脚步认识世界", "First steps & pointing · curious hands at work")
        case .river: L10n.t("假装与共读 · 语言和想象正悄悄发芽", "Pretend play & stories · language comes alive")
        }
    }

    private func landSection(land: Land, months: [Int]) -> some View {
        let isExpanded = activeExpandedLands.contains(land)
        let prog = JourneyKeepsakeMetrics.landProgress(land: land, babyMonth: baby, hasBirth: app.birth != nil)
        let countLabel: String = app.birth != nil
            ? L10n.t("\(prog.lived) / \(months.count) 站", "\(prog.lived) / \(months.count)")
            : L10n.t("\(months.count) 站", "\(months.count) stations")
        let headerLayout = type.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 12))

        return CalmAccordion(isExpanded: isExpanded, spacing: 8) {
            var next = activeExpandedLands
            if next.contains(land) {
                next.remove(land)
            } else {
                next.insert(land)
            }
            expandedLandsOverride = next
        } header: { open in
            ZStack {
                // Kid's book cut-paper rolling hills & stitched footpath backdrop
                Canvas(rendersAsynchronously: false) { ctx, size in
                    let skyTop = dark ? Color(hex: 0x241F1A) : Color(hex: 0xFFFBF2)
                    let skyBot = dark ? land.ground.opacity(0.65) : land.ground.opacity(0.85)
                    ctx.fill(
                        Path(CGRect(origin: .zero, size: size)),
                        with: .linearGradient(
                            Gradient(colors: [skyTop, skyBot]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: 0, y: size.height)
                        )
                    )

                    let orbCenter = CGPoint(x: size.width * 0.56, y: size.height * 0.30)
                    let orbRect = CGRect(x: orbCenter.x - 22, y: orbCenter.y - 22, width: 44, height: 44)
                    ctx.fill(
                        Path(ellipseIn: orbRect),
                        with: .color(dark ? Color(hex: 0xF5D26B).opacity(0.22) : Color(hex: 0xFFE9A8).opacity(0.85))
                    )

                    var backHill = Path()
                    backHill.move(to: CGPoint(x: 0, y: size.height * 0.70))
                    backHill.addQuadCurve(
                        to: CGPoint(x: size.width, y: size.height * 0.62),
                        control: CGPoint(x: size.width * 0.48, y: size.height * 0.44)
                    )
                    backHill.addLine(to: CGPoint(x: size.width, y: size.height))
                    backHill.addLine(to: CGPoint(x: 0, y: size.height))
                    backHill.closeSubpath()
                    ctx.fill(backHill, with: .color(land.crayon.opacity(dark ? 0.24 : 0.20)))

                    var frontHill = Path()
                    frontHill.move(to: CGPoint(x: 0, y: size.height * 0.84))
                    frontHill.addQuadCurve(
                        to: CGPoint(x: size.width, y: size.height * 0.78),
                        control: CGPoint(x: size.width * 0.56, y: size.height * 0.66)
                    )
                    frontHill.addLine(to: CGPoint(x: size.width, y: size.height))
                    frontHill.addLine(to: CGPoint(x: 0, y: size.height))
                    frontHill.closeSubpath()
                    ctx.fill(frontHill, with: .color(land.crayon.opacity(dark ? 0.34 : 0.30)))

                    var path = Path()
                    path.move(to: CGPoint(x: 16, y: size.height * 0.90))
                    path.addCurve(
                        to: CGPoint(x: size.width - 98, y: size.height * 0.84),
                        control1: CGPoint(x: size.width * 0.30, y: size.height * 0.76),
                        control2: CGPoint(x: size.width * 0.52, y: size.height * 0.95)
                    )
                    ctx.stroke(
                        path,
                        with: .color((dark ? Color.white : Color(hex: 0xFFF9EE)).opacity(0.75)),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5])
                    )
                }
                .allowsHitTesting(false)

                headerLayout {
                    HStack(spacing: 8) {
                        IconTile(symbol: land.symbol, color: land.crayon, size: 26, round: true)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(land.name)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(land.years)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(Palette.secondaryText)
                            }
                        }
                    }

                    if !type.isAccessibilitySize {
                        Spacer(minLength: 4)
                    }

                    HStack(spacing: 8) {
                        Text(countLabel)
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .fixedSize()
                            .foregroundStyle(dark ? land.crayon : Crayon.ink(land.crayon))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(dark ? Palette.lampCard.opacity(0.90) : Color.white.opacity(0.92))
                            )

                        let bannerMonth = landCoverMonth(for: land)
                        LivingMonthCoverStage(
                            month: bannerMonth,
                            dark: dark,
                            posterPhase: LivingMonthCoverCatalog.script(for: bannerMonth).posterPhase,
                            interactive: false,
                            compact: true
                        )
                        .frame(width: 52, height: 39)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Palette.outline.opacity(0.24), lineWidth: 0.75)
                        )
                        .accessibilityHidden(true)

                        Image(systemName: "chevron.down")
                            .font(Typeface.label(11, relativeTo: .caption2, weight: .bold))
                            .foregroundStyle(dark ? land.crayon : Crayon.ink(land.crayon))
                            .frame(width: 24, height: 24)
                            .background(
                                Circle().fill(dark ? Palette.lampCard.opacity(0.88) : Color.white.opacity(0.88))
                            )
                            .rotationEffect(.degrees(open ? 180 : 0))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
            }
            .frame(minHeight: 58)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(
                        land.crayon.opacity(dark ? 0.45 : 0.34),
                        style: StrokeStyle(lineWidth: 1.2, dash: [6, 4])
                    )
            )
        } content: {
            VStack(spacing: 0) {
                Text(landTagline(for: land))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ForEach(Array(months.enumerated()), id: \.element) { idx, m in
                    let isLast = idx == months.count - 1
                    stationRow(month: m, land: land, hasNext: !isLast)
                        .id("station-\(m)")
                }
            }
            .padding(.vertical, 6)
            .printCard(radius: Radius.card)
        }
        .id("land-\(land.rawValue)")
    }

    private func stationRow(month m: Int, land: Land, hasNext: Bool) -> some View {
        let here = m == baby
        let past = m < baby
        let mo = app.content.month(m)
        let playsCount = app.content.plays(of: m).count
        let waveOffset = CGFloat(sin(Double(m) * 0.72) * 11)

        return NavigationLink(value: KeepsakesRoute.month(m)) {
            HStack(alignment: .center, spacing: 12) {
                // Winding Montessori vertical bead slot
                stationBead(month: m, land: land, here: here, past: past)
                    .offset(x: waveOffset)
                    .frame(width: 54)
                    .frame(minHeight: 64)

                VStack(alignment: .leading, spacing: 3) {
                    let titleLabel = Text(m == 0 ? L10n.t("出生 · 第 0 站", "Birth · Start") : L10n.t("满 \(m) 个月", "Month \(m)"))
                        .font(.subheadline.weight(here ? .bold : .semibold))
                        .foregroundStyle(here || past ? .primary : Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    let nowBadge = here ? Text(L10n.t("现在", "Now"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color(hex: 0x4A3300))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Palette.bead)) : nil

                    if type.isAccessibilitySize {
                        FlowRow(spacing: 6, lineSpacing: 4) {
                            titleLabel
                            if let nowBadge { nowBadge }
                        }
                    } else {
                        HStack(spacing: 6) {
                            titleLabel
                            if let nowBadge { nowBadge }
                        }
                    }

                    Text(mo.title)
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(type.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)

                    if let birth = app.birth {
                        let d = birth.plus(months: m)
                        Text(L10n.t("\(d.mdOrYmd) · \(playsCount) 个活动", "\(d.mdOrYmd) · \(playsCount) plays"))
                            .font(.caption2)
                            .foregroundStyle(Palette.secondaryText.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(L10n.t("\(playsCount) 个适合的活动", "\(playsCount) activities"))
                            .font(.caption2)
                            .foregroundStyle(Palette.secondaryText.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 8)

                Spacer(minLength: 4)

                if here && !type.isAccessibilitySize {
                    Creature(kind: app.companion, mood: .open, look: CGPoint(x: -0.6, y: 0.1), alive: !reduce)
                        .frame(width: 36 * app.companion.scale, height: 36 * app.companion.scale)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .background(alignment: .leading) {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(m == 0 ? .clear : (past || here ? land.crayon.opacity(0.45) : Palette.outline.opacity(0.28)))
                        .frame(width: 2.5)
                    Rectangle()
                        .fill(!hasNext ? .clear : (past ? land.crayon.opacity(0.45) : Palette.outline.opacity(0.28)))
                        .frame(width: 2.5)
                }
                .frame(width: 54)
                .padding(.leading, 12)
            }
            .background(here ? Palette.bead.opacity(dark ? 0.12 : 0.10) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            TactileEngine.shared.beadClick()
        })
    }

    private func stationBead(month m: Int, land: Land, here: Bool, past: Bool) -> some View {
        let d: CGFloat = here ? 36 : 26
        let c = here ? Palette.bead : land.crayon
        let futureNumeralInk: Color = dark ? Palette.lampInk.opacity(0.88) : Crayon.ink(c)

        return ZStack {
            if here {
                Circle()
                    .fill(Palette.amber.opacity(0.32))
                    .frame(width: d + 10, height: d + 10)
            }
            if flat {
                Circle()
                    .fill(here || past ? c : (dark ? Palette.lampCard : Palette.background))
                    .frame(width: d, height: d)
                if !here && !past {
                    Circle()
                        .strokeBorder(c.opacity(dark ? 0.55 : 0.45), lineWidth: 1.5)
                        .frame(width: d, height: d)
                }
            } else {
                if here || past {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [c.mix(with: .white, by: 0.25), c, c.mix(with: .black, by: 0.14)],
                                center: UnitPoint(x: 0.32, y: 0.28),
                                startRadius: 0,
                                endRadius: d * 0.72
                            )
                        )
                        .frame(width: d, height: d)
                } else {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: dark
                                    ? [Palette.lampCard.mix(with: .white, by: 0.08), Palette.lampCard]
                                    : [.white.opacity(0.95), c.mix(with: .white, by: 0.75).opacity(0.85)],
                                center: UnitPoint(x: 0.32, y: 0.28),
                                startRadius: 0,
                                endRadius: d * 0.72
                            )
                        )
                        .frame(width: d, height: d)
                    Circle()
                        .strokeBorder(c.opacity(dark ? 0.55 : 0.45), lineWidth: 1.3)
                        .frame(width: d, height: d)
                }
            }

            if !quietBeads || here {
                Text("\(m)")
                    .font(Typeface.numerals(here ? 14 : 11, relativeTo: .caption2, weight: .bold))
                    .foregroundStyle(here ? Color(hex: 0x4A3300) : past ? .white : futureNumeralInk)
            }
        }
        .shadow(color: here ? Palette.amber.opacity(0.35) : .clear, radius: 5, y: 2)
    }
}

// MARK: - Keepsake Cabinet Miniature Physical Artifacts (Zero TimelineView)

/// Cloth-bound Storybook artifact with stitched spine, live cover plate, and golden Ex Libris ribbon.
private struct MiniStorybookArtifact: View {
    let month: Int
    let dark: Bool

    var body: some View {
        let m = JourneyStripMetrics.clampedMonth(month)
        ZStack(alignment: .leading) {
            // Back page layer peeking slightly out
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(dark ? Color(hex: 0x263156) : Color(hex: 0xF5EBDC))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Crayon.caramel.opacity(0.35), lineWidth: 0.8)
                )
                .frame(width: 44, height: 34)
                .offset(x: 4, y: 2)

            ZStack(alignment: .leading) {
                LivingMonthCoverStage(
                    month: m,
                    dark: dark,
                    posterPhase: LivingMonthCoverCatalog.script(for: m).posterPhase,
                    interactive: false,
                    compact: true
                )
                .frame(width: 44, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                // Cloth-bound caramel spine band
                Rectangle()
                    .fill(Crayon.caramel.mix(with: .black, by: dark ? 0.15 : 0.05))
                    .frame(width: 6, height: 34)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 6,
                            bottomLeadingRadius: 6,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 0
                        )
                    )
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 7.5, style: .continuous)
                    .fill(dark ? Palette.lampCard : .white)
                    .shadow(color: .black.opacity(dark ? 0.28 : 0.12), radius: 2.5, y: 1.5)
            )
            .overlay(alignment: .topTrailing) {
                // Ex Libris golden ribbon marker
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Palette.bead)
                    .frame(width: 5, height: 10)
                    .offset(x: -5, y: -2)
            }
        }
        .frame(width: 48, height: 38)
        .accessibilityHidden(true)
    }
}

/// Fanned Polaroid stack topped with washi tape, displaying the latest First photo or bespoke charm badge.
private struct MiniPolaroidArtifact: View {
    let latestFirst: First?
    let dark: Bool

    var body: some View {
        let photo = latestFirst.flatMap { FirstPhotoStore.load(for: $0.id) }
        let paperBg = dark ? Color(hex: 0x242D4E) : Color(hex: 0xFFFDF8)
        let borderCol = dark ? Color.white.opacity(0.14) : Palette.outline.opacity(0.22)

        ZStack {
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .fill(paperBg)
                .overlay(RoundedRectangle(cornerRadius: 4.5, style: .continuous).strokeBorder(borderCol, lineWidth: 0.7))
                .frame(width: 30, height: 34)
                .rotationEffect(.degrees(-8))
                .offset(x: -6, y: 1)

            VStack(spacing: 2) {
                Group {
                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Crayon.pink.opacity(dark ? 0.24 : 0.16))
                            FirstCharmBadge(key: latestFirst?.key ?? "smile", color: Crayon.pink, size: 19)
                        }
                    }
                }
                .frame(width: 24, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))

                Capsule()
                    .fill(Palette.secondaryText.opacity(0.24))
                    .frame(width: 14, height: 2)
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                    .fill(paperBg)
                    .overlay(RoundedRectangle(cornerRadius: 4.5, style: .continuous).strokeBorder(borderCol, lineWidth: 0.75))
                    .shadow(color: .black.opacity(dark ? 0.28 : 0.12), radius: 2, y: 1)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color(hex: 0xEFE1B8).opacity(0.90))
                    .frame(width: 14, height: 4.5)
                    .offset(y: -2)
            }
            .rotationEffect(.degrees(5))
            .offset(x: 4, y: 0)
        }
        .frame(width: 48, height: 38)
        .accessibilityHidden(true)
    }
}

/// Folded cotton-paper envelope with delicate V-flap geometry, matching wax seal, and amber ready dot.
private struct MiniCapsuleEnvelopeArtifact: View {
    let seal: CapsuleSeal
    let readyCount: Int
    let dark: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(dark ? Color(hex: 0x222B4C) : Color(hex: 0xFAF3E3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder((dark ? Palette.amber : Crayon.caramel).opacity(dark ? 0.30 : 0.34), lineWidth: 0.85)
                    )

                Canvas(rendersAsynchronously: false) { ctx, size in
                    var flap = Path()
                    flap.move(to: CGPoint(x: 3, y: 2))
                    flap.addLine(to: CGPoint(x: size.width * 0.5, y: size.height * 0.54))
                    flap.addLine(to: CGPoint(x: size.width - 3, y: 2))
                    ctx.stroke(
                        flap,
                        with: .color((dark ? Palette.amber : Crayon.caramel).opacity(dark ? 0.36 : 0.42)),
                        style: StrokeStyle(lineWidth: 1.0, lineCap: .round, lineJoin: .round)
                    )
                }

                WaxSealBadge(seal: seal, size: 22)
                    .offset(y: 3)
            }
            .frame(width: 44, height: 34)
            .shadow(color: .black.opacity(dark ? 0.24 : 0.08), radius: 2, y: 1)

            if readyCount > 0 {
                Circle()
                    .fill(Palette.amber)
                    .frame(width: 8.5, height: 8.5)
                    .overlay(Circle().strokeBorder(dark ? Palette.lampCard : .white, lineWidth: 1.2))
                    .offset(x: 3, y: -3)
            }
        }
        .frame(width: 48, height: 38)
        .accessibilityHidden(true)
    }
}

/// Live WHO P15-P85 river & baby measurement weight sparkline (`Canvas`, zero TimelineView).
private struct MiniGrowthCurveArtifact: View {
    let weights: [Double]
    let dark: Bool

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            let padX: CGFloat = 4
            let padY: CGFloat = 4
            let w = size.width - padX * 2
            let h = size.height - padY * 2

            // Soft sage WHO P15-P85 reference band
            var band = Path()
            band.move(to: CGPoint(x: padX, y: padY + h * 0.78))
            band.addCurve(
                to: CGPoint(x: padX + w, y: padY + h * 0.14),
                control1: CGPoint(x: padX + w * 0.35, y: padY + h * 0.42),
                control2: CGPoint(x: padX + w * 0.68, y: padY + h * 0.22)
            )
            band.addLine(to: CGPoint(x: padX + w, y: padY + h * 0.46))
            band.addCurve(
                to: CGPoint(x: padX, y: padY + h * 0.94),
                control1: CGPoint(x: padX + w * 0.68, y: padY + h * 0.56),
                control2: CGPoint(x: padX + w * 0.35, y: padY + h * 0.72)
            )
            band.closeSubpath()
            ctx.fill(band, with: .color(Crayon.leaf.opacity(dark ? 0.24 : 0.20)))

            // Dashed P50 median curve
            var p50 = Path()
            p50.move(to: CGPoint(x: padX, y: padY + h * 0.86))
            p50.addCurve(
                to: CGPoint(x: padX + w, y: padY + h * 0.30),
                control1: CGPoint(x: padX + w * 0.35, y: padY + h * 0.57),
                control2: CGPoint(x: padX + w * 0.68, y: padY + h * 0.39)
            )
            ctx.stroke(
                p50,
                with: .color(Crayon.leaf.opacity(dark ? 0.75 : 0.65)),
                style: StrokeStyle(lineWidth: 1.1, lineCap: .round, dash: [2.5, 2.5])
            )

            // Actual baby weight sparkline & golden beads
            if !weights.isEmpty {
                let pts: [CGPoint] = weights.enumerated().map { idx, norm in
                    let fx: CGFloat = weights.count == 1 ? 0.65 : CGFloat(idx) / CGFloat(weights.count - 1)
                    let x = padX + w * (0.10 + fx * 0.82)
                    let y = padY + h * (1.0 - CGFloat(norm))
                    return CGPoint(x: x, y: y)
                }

                if pts.count >= 2 {
                    var line = Path()
                    line.move(to: pts[0])
                    for pt in pts.dropFirst() {
                        line.addLine(to: pt)
                    }
                    ctx.stroke(
                        line,
                        with: .color(Palette.bead),
                        style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
                    )
                }

                for (idx, pt) in pts.enumerated() {
                    let isLatest = idx == pts.count - 1
                    let r: CGFloat = isLatest ? 2.8 : 2.0
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                        with: .color(isLatest ? Palette.amber : Palette.bead)
                    )
                    if isLatest {
                        ctx.stroke(
                            Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                            with: .color(dark ? Palette.lampCard : .white),
                            lineWidth: 0.9
                        )
                    }
                }
            }
        }
        .frame(width: 48, height: 36)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(dark ? Color(hex: 0x1B263B) : Color(hex: 0xF4F8EF))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Crayon.leaf.opacity(dark ? 0.34 : 0.28), lineWidth: 0.75)
        )
        .accessibilityHidden(true)
    }
}
