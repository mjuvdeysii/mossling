import SwiftUI

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
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                MapVignette(month: baby, baby: baby, otto: true, festive: app.age?.days == 0 && app.age != nil)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(land.name)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Crayon.ink(land.crayon))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(land.crayon.opacity(0.18)))

                        if let a = app.age {
                            Text(L10n.livedDays(a.lived))
                                .font(.caption.weight(.semibold))
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

            if let a = app.age, a.days + a.toNext > 0 {
                MonthProgress(days: a.days, toNext: a.toNext, next: baby + 1)
            }

            NavigationLink(value: Route.month(baby)) {
                HStack(spacing: 8) {
                    Image(systemName: "book.closed.fill")
                        .font(.subheadline.weight(.bold))
                    Text(L10n.t("进入本月指南 · 活动与发育要点", "Open This Month's Guide"))
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

    private func landSection(land: Land, months: [Int]) -> some View {
        let plate = StoryPlate.forLand(land)
        let hasPlate = StoryPlateLoader.image(for: plate) != nil

        return VStack(alignment: .leading, spacing: 10) {
            if hasPlate {
                ZStack(alignment: .bottomLeading) {
                    LivingStoryPlateView(plate: plate, dark: dark, alive: false)
                        .frame(height: 144)
                        .frame(maxWidth: .infinity)

                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.62)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 76)
                    .allowsHitTesting(false)

                    HStack(alignment: .bottom, spacing: 8) {
                        HStack(spacing: 8) {
                            IconTile(symbol: land.symbol, color: land.crayon, size: 26, round: true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(land.name)
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.white)
                                Text(land.years)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.86))
                            }
                        }
                        Spacer(minLength: 4)
                        Text(L10n.t("\(months.count) 站", "\(months.count) stations"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.black.opacity(0.38)))
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(land.crayon.opacity(dark ? 0.45 : 0.30), lineWidth: 1)
                )
            } else {
                HStack(spacing: 8) {
                    IconTile(symbol: land.symbol, color: land.crayon, size: 24, round: true)
                    Text(land.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(land.years)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.secondaryText)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
            }

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
