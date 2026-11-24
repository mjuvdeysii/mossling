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

/// 4:3 Picture-Book Month Cover Postcard replacing the legacy square map vignette across Today & JourneyHub.
struct MonthPostcardArt: View {
    let month: Int
    var festive: Bool = false
    var night: Bool = false
    var width: CGFloat = 104
    var radius: CGFloat = 12

    @Environment(\.girlArt) private var girl
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let m = JourneyStripMetrics.clampedMonth(month)
        let dark = night || scheme == .dark
        let height = width * 0.75
        let coverName = ArtIndex.shared.cover(m).map { ArtIndex.variant($0, girl: girl) }
        let coverImage = coverName.flatMap { name in
            Perf.noArt ? nil : (ArtCache.shared.cached(name, maxPixel: Int(width * 3)) ?? ArtCache.shared.image(name, maxPixel: Int(width * 3)))
        }

        ZStack {
            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Land.of(m).crayon.opacity(0.35), Palette.bead.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            if night {
                Color(hex: 0x0E1430).opacity(0.34)
                RadialGradient(
                    colors: [Palette.amber.opacity(0.24), .clear],
                    center: UnitPoint(x: 0.78, y: 0.25),
                    startRadius: 2,
                    endRadius: width * 0.55
                )
            }

            if festive {
                buntingOverlay
            }
        }
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
                    .font(.system(size: 10, weight: .bold))
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

    private var buntingOverlay: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            let y0 = size.height * 0.08
            let sag = size.height * 0.14
            var line = Path()
            line.move(to: CGPoint(x: -2, y: y0))
            line.addQuadCurve(to: CGPoint(x: size.width + 2, y: y0), control: CGPoint(x: size.width / 2, y: y0 + sag * 2))
            ctx.stroke(line, with: .color(Color(hex: 0x7A5C3D).opacity(0.65)), lineWidth: 1)
            let tones: [Color] = [Crayon.pink, Palette.bead, Crayon.teal, Crayon.sky]
            let count = 6
            for i in 0..<count {
                let t = (Double(i) + 0.5) / Double(count)
                let x = size.width * t
                let y = y0 + sag * 4 * t * (1 - t)
                var flag = Path()
                flag.move(to: CGPoint(x: x - 4, y: y))
                flag.addLine(to: CGPoint(x: x + 4, y: y))
                flag.addLine(to: CGPoint(x: x, y: y + 7.5))
                flag.closeSubpath()
                ctx.fill(flag, with: .color(tones[i % tones.count]))
            }
        }
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
            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
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
            .font(.caption2.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(night || dark ? Palette.amber : Crayon.ink(Palette.bead))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(Palette.bead.opacity(dark ? 0.22 : 0.16)))
    }
}

/// Halo 3: Unified Vertical 「串珠小路 · Journey」 combining the current age station, a 2×2 Keepsake Shelf
/// (Storybook, Polaroid Firsts, Wax-Sealed Capsules, WHO Growth Curves), and the 37-station vertical winding bead chain
/// across 草地 (0–1 yr), 森林小丘 (1–2 yrs), and 小河村庄 (2–3 yrs) — with zero horizontal scrolling.
struct JourneyHubView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.dynamicTypeSize) private var type

    @State private var scope: StationScope = .all
    @State private var quietBeads = false
    @State private var showingStorybook = false
    @State private var capsules = CapsuleStore.shared

    enum StationScope: String, CaseIterable, Identifiable {
        case all, lived
        var id: String { rawValue }
        var title: String {
            switch self {
            case .all: L10n.t("全部 37 站", "All 37 Stations")
            case .lived: L10n.t("走过的路", "Lived So Far")
            }
        }
    }

    private var baby: Int { max(0, min(app.babyMonth ?? 0, 36)) }
    private var dark: Bool { lamp || scheme == .dark }
    private var flat: Bool { ArtStyle.current == .flat }

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
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    currentStationHero

                    keepsakeShelf

                    // Filter & serene bead toggle bar (wrapping FlowRow, zero horizontal scrolling)
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(
                            title: L10n.t("串珠小路", "Bead Journey"),
                            detail: L10n.t("出生 – 36 个月 · 37 站", "Birth – 36 mo · 37 stations")
                        )

                        FlowRow(spacing: 8, lineSpacing: 8) {
                            if app.birth != nil {
                                ForEach(StationScope.allCases) { item in
                                    let on = scope == item
                                    Button {
                                        TactileEngine.shared.beadClick()
                                        withAnimation(reduce ? nil : .snappy) { scope = item }
                                    } label: {
                                        Text(item.title)
                                            .font(.footnote.weight(.bold))
                                            .foregroundStyle(on ? .white : .primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(Capsule().fill(on ? Palette.accentFill : (dark ? Palette.lampCard : Palette.card)))
                                            .overlay(Capsule().strokeBorder(Palette.outline.opacity(on ? 0 : 0.3), lineWidth: 0.75))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(on ? .isSelected : [])
                                }
                            }

                            Button {
                                TactileEngine.shared.beadClick()
                                withAnimation(reduce ? nil : .snappy) { quietBeads.toggle() }
                            } label: {
                                Label(
                                    L10n.t("静谧珠链", "Quiet Beads"),
                                    systemImage: quietBeads ? "circle.fill" : "circle.dotted"
                                )
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(quietBeads ? Color(hex: 0x4A3300) : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(quietBeads ? Palette.bead : (dark ? Palette.lampCard : Palette.card)))
                                .overlay(Capsule().strokeBorder(Palette.outline.opacity(quietBeads ? 0 : 0.3), lineWidth: 0.75))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(quietBeads ? .isSelected : [])
                        }
                    }

                    // Pure vertical winding Montessori bead chain grouped by the 3 Lands
                    VStack(alignment: .leading, spacing: 20) {
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
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .calmWhileScrolling()
            .pageBackground(tone: Land.of(baby).crayon)
            .navigationTitle(L10n.t("串珠旅程", "Journey"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        TactileEngine.shared.beadClick()
                        withAnimation(reduce ? nil : .spring(response: 0.48, dampingFraction: 0.82)) {
                            proxy.scrollTo("station-\(baby)", anchor: .center)
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
        }
    }

    // MARK: - Section 1: Current Station Hero

    private var currentStationHero: some View {
        let mo = app.content.month(baby)
        let land = Land.of(baby)
        let monthFrac = app.age.map { JourneyStripMetrics.monthProgressFraction(days: $0.days, toNext: $0.toNext) } ?? 0
        let countdown: String? = app.age.flatMap { a in
            a.toNext > 0 && baby < 36
                ? L10n.t("\(a.toNext) 天后满 \(baby + 1) 个月", "\(a.toNext)d to mo \(baby + 1)")
                : nil
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                MonthPostcardArt(
                    month: baby,
                    festive: app.age?.days == 0 && app.age != nil,
                    night: lamp,
                    width: type.isAccessibilitySize ? 92 : 104
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Label(land.name, systemImage: land.symbol)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(dark ? land.crayon : Crayon.ink(land.crayon))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(land.crayon.opacity(dark ? 0.22 : 0.16)))

                        if let a = app.age {
                            Text(L10n.livedDays(a.lived))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Palette.secondaryText)
                        }
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(baby == 0 ? L10n.t("出生", "Birth") : "\(baby)")
                            .font(Typeface.numerals(34, relativeTo: .largeTitle, weight: .bold))
                        if baby > 0 {
                            Text(L10n.t("个月", "mo")).font(.subheadline.weight(.semibold))
                        }
                        if let d = app.age?.days, d > 0 {
                            Text("\(d)").font(Typeface.numerals(18, relativeTo: .headline, weight: .bold)).padding(.leading, 3)
                            Text(L10n.t("天", "d")).font(.subheadline.weight(.semibold))
                        }
                    }

                    Text(mo.title)
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(type.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            MiniJourneyBeadStrip(
                month: baby,
                monthFraction: monthFrac,
                hasBirth: app.age != nil,
                countdownText: countdown,
                dark: dark,
                night: lamp
            )

            NavigationLink(value: Route.month(baby)) {
                HStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .font(.subheadline.weight(.bold))
                    Text(L10n.t("本月发育要点与活动", "This Month's Guide"))
                        .font(.subheadline.weight(.bold))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(Palette.accentFill))
            }
            .buttonStyle(.toy)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [land.crayon.opacity(dark ? 0.14 : 0.12), Palette.bead.opacity(dark ? 0.06 : 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .printCard(radius: Radius.card)
    }

    // MARK: - Section 2: 2×2 Keepsake Shelf (Zero Horizontal Scroll)

    private var keepsakeShelf: some View {
        let cols = type.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        let bookMonths = app.birth != nil ? max(1, min(app.age?.bookMonth ?? 0, 36) + 1) : 0
        let capsuleTotal = capsules.items.count
        let capsuleReady = capsules.readyCount(on: app.today)

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: L10n.t("纪念书架", "Keepsake Shelf"))

            LazyVGrid(columns: cols, spacing: 10) {
                if app.birth != nil {
                    Button {
                        TactileEngine.shared.pageTurn()
                        showingStorybook = true
                    } label: {
                        shelfTile(
                            title: L10n.t("成长绘本", "Storybook"),
                            detail: L10n.t("已收录 \(bookMonths) 个月", "\(bookMonths) mo collected"),
                            tint: Crayon.caramel
                        ) {
                            ToolArtBadge(toolId: "storybook", size: 32)
                        }
                    }
                    .buttonStyle(.toy)
                } else {
                    NavigationLink(value: Route.book) {
                        shelfTile(
                            title: L10n.t("成长册", "Growth Book"),
                            detail: L10n.t("每一站留影", "Month keepsakes"),
                            tint: Crayon.caramel
                        ) {
                            ToolArtBadge(toolId: "storybook", size: 32)
                        }
                    }
                    .buttonStyle(.toy)
                }

                NavigationLink(value: JournalRoute.firsts) {
                    shelfTile(
                        title: L10n.t("第一次相纸", "Firsts"),
                        detail: j.firsts.isEmpty
                            ? L10n.t("记下珍贵瞬间", "Polaroid moments")
                            : L10n.t("已留存 \(j.firsts.count) 个第一次", "\(j.firsts.count) captured"),
                        tint: Crayon.pink
                    ) {
                        IconTile(symbol: "camera.macro", color: Crayon.pink, size: 32)
                    }
                }
                .buttonStyle(.toy)

                NavigationLink(value: Route.capsules) {
                    shelfTile(
                        title: L10n.t("时光胶囊", "Time Capsules"),
                        detail: capsuleReady > 0
                            ? L10n.t("\(capsuleReady) 封可拆封", "\(capsuleReady) ready now")
                            : (capsuleTotal > 0
                                ? L10n.t("已封存 \(capsuleTotal) 封信", "\(capsuleTotal) sealed")
                                : L10n.t("火漆写给未来", "Wax-sealed letters")),
                        tint: Palette.bead
                    ) {
                        WaxSealBadge(seal: .gold, size: 32)
                    }
                }
                .buttonStyle(.toy)

                NavigationLink(value: JournalRoute.growth) {
                    shelfTile(
                        title: L10n.t("生长曲线", "Growth Curves"),
                        detail: L10n.t("WHO 百分位参考", "WHO standards"),
                        tint: Crayon.leaf
                    ) {
                        IconTile(symbol: "chart.line.uptrend.xyaxis", color: Crayon.leaf, size: 32)
                    }
                }
                .buttonStyle(.toy)
            }
        }
    }

    private func shelfTile<Icon: View>(
        title: String,
        detail: String,
        tint: Color,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                icon()
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [tint.opacity(dark ? 0.14 : 0.11), tint.opacity(0.02)],
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
        return VStack(alignment: .leading, spacing: 10) {
            ZStack {
                // Kid's book cut-paper rolling hills & stitched footpath backdrop
                Canvas { ctx, size in
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

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            IconTile(symbol: land.symbol, color: land.crayon, size: 28, round: true)
                            Text(land.name)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)
                        }

                        HStack(spacing: 6) {
                            Text(land.years)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Palette.secondaryText)

                            Text(L10n.t("\(months.count) 站", "\(months.count) stations"))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(land.crayon.mix(with: .black, by: dark ? 0.0 : 0.28))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(dark ? Palette.lampCard.opacity(0.85) : Color.white.opacity(0.85))
                                )
                        }

                        Text(landTagline(for: land))
                            .font(.caption2)
                            .foregroundStyle(Palette.secondaryText)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 4)

                    if let coverName = ArtIndex.shared.cover(landCoverMonth(for: land)) {
                        ZStack(alignment: .top) {
                            ArtView(name: coverName, label: land.name, radius: 13)
                                .frame(width: 88, height: 66)
                                .padding(4)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(dark ? Palette.lampCard : Color(hex: 0xFFFDF8))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Palette.outline.opacity(0.28), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(dark ? 0.22 : 0.09), radius: 5, y: 3)
                                .rotationEffect(.degrees(3))

                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Color(hex: 0xEFE1B8).opacity(0.88))
                                .frame(width: 24, height: 8)
                                .offset(y: -4)
                                .rotationEffect(.degrees(-2))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .frame(minHeight: 112)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(
                        land.crayon.opacity(dark ? 0.45 : 0.34),
                        style: StrokeStyle(lineWidth: 1.2, dash: [6, 4])
                    )
            )

            VStack(spacing: 0) {
                ForEach(Array(months.enumerated()), id: \.element) { idx, m in
                    let isLast = idx == months.count - 1
                    stationRow(month: m, land: land, hasNext: !isLast)
                        .id("station-\(m)")
                }
            }
            .padding(.vertical, 6)
            .printCard(radius: Radius.card)
        }
    }

    private func stationRow(month m: Int, land: Land, hasNext: Bool) -> some View {
        let here = m == baby
        let past = m < baby
        let mo = app.content.month(m)
        let playsCount = app.content.plays(of: m).count
        let waveOffset = CGFloat(sin(Double(m) * 0.72) * 11)

        return NavigationLink(value: Route.month(m)) {
            HStack(alignment: .center, spacing: 12) {
                // Winding Montessori vertical bead column
                ZStack {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(m == 0 ? .clear : (past || here ? land.crayon.opacity(0.45) : Palette.outline.opacity(0.28)))
                            .frame(width: 2.5, height: 22)
                        Rectangle()
                            .fill(!hasNext ? .clear : (past ? land.crayon.opacity(0.45) : Palette.outline.opacity(0.28)))
                            .frame(width: 2.5, height: 22)
                    }
                    stationBead(month: m, land: land, here: here, past: past)
                        .offset(x: waveOffset)
                }
                .frame(width: 58, height: 64)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(m == 0 ? L10n.t("出生 · 第 0 站", "Birth · Start") : L10n.t("满 \(m) 个月", "Month \(m)"))
                            .font(.subheadline.weight(here ? .bold : .semibold))
                            .foregroundStyle(here || past ? .primary : Palette.secondaryText)

                        if here {
                            Text(L10n.t("现在", "Now"))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color(hex: 0x4A3300))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Palette.bead))
                        }
                    }

                    Text(mo.title)
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if let birth = app.birth {
                        let d = birth.plus(months: m)
                        Text(L10n.t("\(d.mdOrYmd) · \(playsCount) 个活动", "\(d.mdOrYmd) · \(playsCount) plays"))
                            .font(.caption2)
                            .foregroundStyle(Palette.secondaryText.opacity(0.85))
                    } else {
                        Text(L10n.t("\(playsCount) 个适合的活动", "\(playsCount) activities"))
                            .font(.caption2)
                            .foregroundStyle(Palette.secondaryText.opacity(0.85))
                    }
                }

                Spacer(minLength: 4)

                if here {
                    Creature(kind: app.companion, mood: .open, look: CGPoint(x: -0.6, y: 0.1), alive: !reduce)
                        .frame(width: 36 * app.companion.scale, height: 36 * app.companion.scale)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
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

        return ZStack {
            if here {
                Circle()
                    .fill(Palette.amber.opacity(0.32))
                    .frame(width: d + 10, height: d + 10)
            }
            if flat {
                Circle()
                    .fill(here || past ? c : Palette.background)
                    .frame(width: d, height: d)
                if !here && !past {
                    Circle()
                        .strokeBorder(c.opacity(0.45), lineWidth: 1.5)
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
                                colors: [.white.opacity(0.95), c.mix(with: .white, by: 0.75).opacity(0.85)],
                                center: UnitPoint(x: 0.32, y: 0.28),
                                startRadius: 0,
                                endRadius: d * 0.72
                            )
                        )
                        .frame(width: d, height: d)
                    Circle()
                        .strokeBorder(c.opacity(0.45), lineWidth: 1.3)
                        .frame(width: d, height: d)
                }
            }

            if !quietBeads || here {
                Text("\(m)")
                    .font(Typeface.numerals(here ? 14 : 11, relativeTo: .caption2, weight: .bold))
                    .foregroundStyle(here ? Color(hex: 0x4A3300) : past ? .white : c.mix(with: .black, by: 0.35))
            }
        }
        .shadow(color: here ? Palette.amber.opacity(0.35) : .clear, radius: 5, y: 2)
    }
}
