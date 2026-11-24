import SwiftUI

/// A topic page (sleep, safe sleep, feeding, teeth and screens, when to see a doctor).
struct TopicView: View {
    let topic: Topic
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BlocksView(blocks: topic.blocks)
                if !topic.sourceTitle.isEmpty {
                    Label(topic.sourceTitle, systemImage: "books.vertical").font(.footnote).foregroundStyle(Palette.secondaryText).padding(.top, 8)
                }
                Text(HealthNote.text).font(.footnote).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 40)
        }
        .pageBackground()
        .navigationTitle(topic.title).navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
    }
}

/// Search across plays, months and topics.
struct SearchView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.openURL) private var openURL
    @Binding var path: NavigationPath
    @State private var q = ""
    var body: some View {
        let c = app.content
        let t = q.trimmingCharacters(in: .whitespaces)
        let plays = t.isEmpty ? [] : c.activities.filter { $0.name.localizedCaseInsensitiveContains(t) || $0.code.localizedCaseInsensitiveContains(t) || $0.steps.contains { $0.localizedCaseInsensitiveContains(t) } || $0.domains.contains { $0.localizedCaseInsensitiveContains(t) } }
        let months = t.isEmpty ? [] : c.months.filter { m in m.title.localizedCaseInsensitiveContains(t) || m.domains.contains { $0.text.localizedCaseInsensitiveContains(t) } || m.observe.contains { $0.items.contains { $0.localizedCaseInsensitiveContains(t) } } || m.notes.contains { $0.text.localizedCaseInsensitiveContains(t) } }
        let topics = t.isEmpty ? [] : c.topics.filter { $0.title.localizedCaseInsensitiveContains(t) || $0.blocks.contains { ($0.text ?? "").localizedCaseInsensitiveContains(t) || ($0.items ?? []).contains { $0.localizedCaseInsensitiveContains(t) } } }
        let tools = t.isEmpty ? [] : QuietToolResult.all.filter { $0.matches(t) }
        let foods = t.isEmpty ? [] : FoodItem.catalog.filter { $0.zh.localizedCaseInsensitiveContains(t) || $0.en.localizedCaseInsensitiveContains(t) || $0.category.title.localizedCaseInsensitiveContains(t) }
        List {
            if !tools.isEmpty {
                Section(L10n.t("陪伴小器具", "Quiet Instruments")) {
                    ForEach(tools) { tool in
                        if let route = tool.route {
                            NavigationLink(value: route) {
                                Label { Text(tool.title) } icon: { IconTile(symbol: tool.symbol, color: tool.color) }
                            }
                        } else if let jRoute = tool.journalRoute {
                            NavigationLink(value: jRoute) {
                                Label { Text(tool.title) } icon: { IconTile(symbol: tool.symbol, color: tool.color) }
                            }
                        } else if let url = tool.url {
                            Button { openURL(url) } label: {
                                Label { Text(tool.title).foregroundStyle(.primary) } icon: { IconTile(symbol: tool.symbol, color: tool.color) }
                            }
                        }
                    }
                }
            }
            if !foods.isEmpty {
                Section(L10n.t("百味食盒", "First Foods")) {
                    ForEach(foods.prefix(6)) { food in
                        NavigationLink(value: Route.foodAtlas) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(food.name)
                                    Text(food.category.title + (food.isCommonAllergen ? L10n.t(" · 常见致敏", " · Common allergen") : ""))
                                        .font(.caption).foregroundStyle(Palette.secondaryText)
                                }
                            } icon: {
                                FoodGlyphView(food: food, size: 28)
                            }
                        }
                    }
                    if foods.count > 6 {
                        NavigationLink(value: Route.foodAtlas) {
                            Text(L10n.t("查看全部 \(foods.count) 项匹配食材…", "See all \(foods.count) matching foods…"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.accent)
                        }
                    }
                }
            }
            if !plays.isEmpty {
                Section(L10n.t("活动", "Activities")) { ForEach(plays) { p in NavigationLink(value: Route.play(p.code, app.babyMonth.map { max(p.from, min(p.to, $0)) } ?? p.from)) {
                    PlayRowLabel(play: p) } } }
            }
            if !months.isEmpty {
                Section(L10n.t("月份", "Months")) { ForEach(months, id: \.month) { m in NavigationLink(value: Route.month(m.month)) {
                    Label { VStack(alignment: .leading, spacing: 2) { Text(m.month == 0 ? L10n.t("出生", "Newborn") : L10n.t("满 \(m.month) 个月", m.month == 1 ? "1 month" : "\(m.month) months")); Text(m.title).font(.subheadline).foregroundStyle(Palette.secondaryText) } } icon: { Bead(month: m.month, here: false, past: true).scaleEffect(0.9) } } } }
            }
            if !topics.isEmpty {
                Section(L10n.t("专题", "Topics")) { ForEach(topics) { tp in NavigationLink(value: Route.topic(tp.id)) { topicLabel(tp) } } }
            }
            // before typing: what is on the shelf this week and the topics, so the page opens on something to read
            if t.isEmpty {
                let m = app.babyMonth ?? 0
                Section(L10n.t("这周一起玩", "This Week's Plays")) { ForEach(app.weekShelf(m).plays) { p in NavigationLink(value: Route.play(p.code, m)) { PlayRowLabel(play: p) } } }
                Section(L10n.t("专题", "Topics")) { ForEach(c.topics) { tp in NavigationLink(value: Route.topic(tp.id)) { topicLabel(tp) } } }
            }
            if !t.isEmpty && plays.isEmpty && months.isEmpty && topics.isEmpty && tools.isEmpty && foods.isEmpty {
                // nothing found: the companion looks this way and that for it
                VStack(spacing: 8) {
                    TimelineView(.periodic(from: .now, by: 1.3)) { tl in
                        let side: Double = Int(tl.date.timeIntervalSinceReferenceDate / 1.3) % 2 == 0 ? -0.9 : 0.9
                        Creature(kind: app.companion, look: CGPoint(x: side, y: 0.1), alive: true, lookSeconds: 0.5)
                            .frame(width: 64 * app.companion.scale, height: 64 * app.companion.scale)
                    }
                    .frame(height: 72).accessibilityHidden(true)
                    Text(L10n.t("没有找到「\(t)」", "No results for \"\(t)\"")).font(.headline)
                    Text(L10n.t("试试活动、月份、辅食或小器具", "Try an activity, month, food, or tool")).font(.subheadline).foregroundStyle(Palette.secondaryText)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 24)
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden).pageBackground()
        .searchable(text: $q, placement: .navigationBarDrawer(displayMode: .always), prompt: L10n.t("活动、月份、专题、辅食或小器具", "Activities, months, foods, or tools"))
        .navigationTitle(L10n.t("搜索", "Search"))
        .toolbar(.hidden, for: .tabBar)
    }
    /// A topic with its own mark, as on the month's page.
    private func topicLabel(_ tp: Topic) -> some View {
        let i = app.content.topics.firstIndex { $0.id == tp.id } ?? 0
        return Label { Text(tp.title) } icon: { IconTile(symbol: topicMarks[i % topicMarks.count].0, color: topicMarks[i % topicMarks.count].1) }
    }
}

private struct QuietToolResult: Identifiable {
    let id: String
    let zh: String
    let en: String
    let keywords: [String]
    let symbol: String
    let color: Color
    var route: Route? = nil
    var journalRoute: JournalRoute? = nil
    var url: URL? = nil

    var title: String { L10n.t(zh, en) }

    func matches(_ q: String) -> Bool {
        zh.localizedCaseInsensitiveContains(q)
            || en.localizedCaseInsensitiveContains(q)
            || keywords.contains { $0.localizedCaseInsensitiveContains(q) }
    }

    static let all: [QuietToolResult] = [
        QuietToolResult(id: "lamp", zh: "床头夜灯", en: "Bedside Lamp", keywords: ["夜灯", "声景", "呼吸", "白噪音", "白噪声", "助眠", "sound", "sleep", "breath", "lamp"], symbol: "lamp.desk.fill", color: Palette.amber, url: URL(string: "mossling://lamp")),
        QuietToolResult(id: "toybox", zh: "感官玩具盒", en: "Sensory Toybox", keywords: ["木琴", "金珠", "雨棒", "萤火", "视卡", "黑白", "xylophone", "rainstick", "fireflies", "contrast"], symbol: "music.note", color: Crayon.teal, route: .toybox(.xylophone)),
        QuietToolResult(id: "foods", zh: "百味食盒", en: "First Foods", keywords: ["辅食", "食材", "致敏", "食盒", "味觉", "food", "allergen", "solids"], symbol: "carrot.fill", color: Crayon.leaf, route: .foodAtlas),
        QuietToolResult(id: "rhythm", zh: "昼夜节律盘", en: "Rhythm Dial", keywords: ["节律", "昼夜", "统计", "作息", "rhythm", "dial", "circadian"], symbol: "sun.and.horizon.fill", color: Crayon.lilac, journalRoute: .stats),
        QuietToolResult(id: "book", zh: "成长绘本", en: "Storybook", keywords: ["绘本", "成长册", "相纸", "book", "storybook"], symbol: "book.pages.fill", color: Crayon.caramel, route: .book),
        QuietToolResult(id: "capsules", zh: "时光胶囊信笺", en: "Time Capsules", keywords: ["胶囊", "信", "火漆", "capsule", "letter", "wax"], symbol: "envelope.badge.fill", color: Palette.bead, route: .capsules),
    ]
}

/// Pure helper for computing the 6 Montessori developmental area coverage on a weekly shelf.
enum ShelfComposerMetrics {
    static let canonicalAreas = ["A", "B", "C", "D", "E", "F"]

    static func areaCounts(for plays: [Play]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for p in plays {
            counts[Palette.areaKey(of: p), default: 0] += 1
        }
        return counts
    }

    static func coveredAreaKeys(for plays: [Play]) -> [String] {
        let present = Set(plays.map { Palette.areaKey(of: $0) })
        return canonicalAreas.filter { present.contains($0) }
    }
}

/// 这周一起玩 — 「蒙氏本周玩具架编排台 / Weekly Montessori Shelf Composer」:
/// Interactive 2×2 wooden tray stage with live 6-domain balance ribbon, bidirectional domain filtering,
/// inline 1-tap prep & step-1 preview drawer, and one-tap shuffle/return controls.
struct PlanView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.lamp) private var lamp
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var path: NavigationPath
    var previewExpandedCode: String? = nil
    @State private var areaFilter: String? = nil
    @State private var unplayedOnly = false
    @State private var expandedCode: String?

    init(path: Binding<NavigationPath>, previewExpandedCode: String? = nil) {
        self._path = path
        self.previewExpandedCode = previewExpandedCode
        self._expandedCode = State(initialValue: previewExpandedCode)
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        let m = app.babyMonth ?? 0
        let current = app.weekShelf(m)
        let codes = current.plays.map(\.code)
        let full = codes.count >= Shelf.max
        let monday = app.today.monday.date
        let before = app.today.monday.plus(days: -7).date
        let lastWeek = app.content.activities.filter { p in
            !codes.contains(p.code) && j.plays(p.code).contains { $0.startDate >= before && $0.startDate < monday }
        }
        let more = Shelf.candidates(app.content, m).filter { p in
            !codes.contains(p.code) && !lastWeek.contains(p)
        }
        let availableAreas = Set((lastWeek + more).map { Palette.areaKey(of: $0) })
        let filteredMore = more.filter { p in
            let matchesArea = areaFilter == nil || Palette.areaKey(of: p) == areaFilter
            let matchesUnplayed = !unplayedOnly || app.record(p, j).count == 0
            return matchesArea && matchesUnplayed
        }

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                woodenShelfStage(
                    plays: current.plays,
                    codes: codes,
                    month: m,
                    availableAreas: availableAreas,
                    dark: dark
                )

                Text(L10n.t(
                    "观察、准备、示范、重复、轮换。每周三四个，孩子想重复就重复。",
                    "Observe, prepare, show, repeat, rotate. Three or four a week — repeat as often as your child wants."
                ))
                .font(.caption)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)

                if !lastWeek.isEmpty {
                    SectionTitle(
                        title: L10n.t("上周玩过", "Played Last Week"),
                        detail: L10n.t("轻点放回架上", "Tap to return")
                    )
                    VStack(spacing: 10) {
                        ForEach(lastWeek) { p in
                            candidateCard(p, month: m, codes: codes, full: full, dark: dark)
                        }
                    }
                }

                SectionTitle(
                    title: L10n.t("这个月还可以玩", "More for This Month"),
                    detail: L10n.t("\(filteredMore.count) 个", "\(filteredMore.count)")
                )

                quickFilterBar(dark: dark)

                if filteredMore.isEmpty {
                    VStack(spacing: 8) {
                        Text(L10n.t("当前筛选下没有更多玩法，换个分类看看", "No more picks in this filter"))
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondaryText)
                        if areaFilter != nil || unplayedOnly {
                            Button(L10n.t("显示全部", "Show All")) {
                                TactileEngine.shared.beadClick()
                                withAnimation(.snappy) {
                                    areaFilter = nil
                                    unplayedOnly = false
                                }
                            }
                            .font(.caption.weight(.bold))
                            .buttonStyle(.vinyl(Palette.accentFill))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .printCard(radius: Radius.card)
                } else {
                    VStack(spacing: 10) {
                        ForEach(filteredMore) { p in
                            candidateCard(p, month: m, codes: codes, full: full, dark: dark)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Palette.bead)
        .navigationTitle(L10n.t("这周一起玩", "This Week"))
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - Montessori Wooden Shelf Stage

    private func woodenShelfStage(
        plays: [Play],
        codes: [String],
        month: Int,
        availableAreas: Set<String>,
        dark: Bool
    ) -> some View {
        let woodTop = dark ? Color(hex: 0x1B2446) : Color(hex: 0xF8F0E2)
        let woodBot = dark ? Color(hex: 0x141C38) : Color(hex: 0xEFE1CA)
        let plankColor = dark ? Color(hex: 0x2C3866) : Color(hex: 0xD8BF98)
        let covered = ShelfComposerMetrics.coveredAreaKeys(for: plays)
        let counts = ShelfComposerMetrics.areaCounts(for: plays)

        return VStack(alignment: .leading, spacing: 12) {
            // Header: title + slot counter pill + Shuffle button
            HStack(alignment: .center, spacing: 8) {
                GoldBead(size: 9)
                Text(L10n.t("本周玩具架", "This Week's Shelf"))
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(codes.count) / \(Shelf.max)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(dark ? Palette.amber : Crayon.ink(Palette.bead))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Palette.bead.opacity(dark ? 0.22 : 0.18)))

                Spacer(minLength: 4)

                Button {
                    TactileEngine.shared.goldChime()
                    withAnimation(.snappy) {
                        let picks = Shelf.suggest(
                            app.content,
                            month,
                            last: codes,
                            played: { c in app.content.play(c).map { app.record($0, j).count } ?? 0 }
                        )
                        app.setShelf(picks)
                    }
                } label: {
                    Label(L10n.t("换一组", "Shuffle"), systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Palette.accent.opacity(dark ? 0.20 : 0.12)))
                        .overlay(Capsule().strokeBorder(Palette.accent.opacity(0.28), lineWidth: 0.75))
                }
                .buttonStyle(.toy)
                .accessibilityLabel(L10n.t("重新推荐这周玩法", "Shuffle this week's shelf"))
            }

            // 2×2 wooden tray compartments with horizontal shelf planks (collapses to 1-col at AX sizes)
            if typeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    ForEach(0..<Shelf.max, id: \.self) { idx in
                        shelfSlot(index: idx, plays: plays, codes: codes, dark: dark)
                    }
                }
            } else {
                VStack(spacing: 10) {
                    shelfRow(indices: [0, 1], plays: plays, codes: codes, plankColor: plankColor, dark: dark)
                    shelfRow(indices: [2, 3], plays: plays, codes: codes, plankColor: plankColor, dark: dark)
                }
            }

            // Inline preview when parent taps a play on the shelf itself
            if let exp = expandedCode, let activeOnShelf = plays.first(where: { $0.code == exp }) {
                inlinePreviewDrawer(for: activeOnShelf, month: month, dark: dark)
            }

            // Coupled 6-domain balance ribbon (shows live coverage & acts as one-tap filter)
            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.t(
                    "领域均衡 · 已覆盖 \(covered.count) 个领域（轻点筛选）",
                    "Domain balance · \(covered.count) covered (tap to filter)"
                ))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.secondaryText)

                WrapLayout(spacing: 6) {
                    ForEach(ShelfComposerMetrics.canonicalAreas, id: \.self) { key in
                        let isCovered = counts[key, default: 0] > 0
                        let isSelected = areaFilter == key
                        let hasCandidates = availableAreas.contains(key)
                        let col = Palette.area(key)
                        let ink = dark ? col : Crayon.ink(col)

                        Button {
                            TactileEngine.shared.beadClick()
                            withAnimation(.snappy) {
                                areaFilter = isSelected ? nil : key
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(isCovered ? col : Color.clear)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(col.opacity(isCovered ? 0 : 0.8), lineWidth: 1.5)
                                    )
                                    .frame(width: 8, height: 8)

                                Text(Palette.areaShortName(key))
                                    .lineLimit(1)

                                if let cnt = counts[key], cnt > 1 {
                                    Text("×\(cnt)")
                                        .font(.caption2.weight(.bold))
                                        .monospacedDigit()
                                        .foregroundStyle(ink.opacity(0.8))
                                }
                            }
                            .font(.caption.weight(isSelected || isCovered ? .bold : .medium))
                            .foregroundStyle(isSelected ? (dark ? .white : ink) : (isCovered ? .primary : Palette.secondaryText))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(
                                    isSelected
                                        ? col.opacity(dark ? 0.30 : 0.22)
                                        : (isCovered ? col.opacity(dark ? 0.16 : 0.12) : (dark ? Palette.lampCard.opacity(0.75) : Color.white.opacity(0.72)))
                                )
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    isSelected ? ink : (isCovered ? col.opacity(0.35) : Palette.outline.opacity(0.24)),
                                    lineWidth: isSelected ? 1.3 : 0.75
                                )
                            )
                            .opacity(hasCandidates || isCovered ? 1.0 : 0.45)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
        }
        .padding(14)
        .background(LinearGradient(colors: [woodTop, woodBot], startPoint: .top, endPoint: .bottom))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Palette.bead.opacity(dark ? 0.24 : 0.28), lineWidth: 1)
        )
        .printCard(radius: Radius.card)
    }

    private func shelfRow(
        indices: [Int],
        plays: [Play],
        codes: [String],
        plankColor: Color,
        dark: Bool
    ) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(indices, id: \.self) { idx in
                    shelfSlot(index: idx, plays: plays, codes: codes, dark: dark)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            // Tactile wooden shelf plank
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(plankColor)
                .frame(height: 5)
                .shadow(color: .black.opacity(dark ? 0.30 : 0.10), radius: 1.5, y: 1.5)
        }
    }

    @ViewBuilder
    private func shelfSlot(index: Int, plays: [Play], codes: [String], dark: Bool) -> some View {
        if index < plays.count {
            let play = plays[index]
            let key = Palette.areaKey(of: play)
            let col = Palette.area(key)
            let isExpanded = expandedCode == play.code

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 4) {
                    TrayTile(code: play.code, color: col, flat: ArtStyle.current == .flat)
                        .frame(width: 48, height: 36)
                    Spacer(minLength: 2)
                    Button {
                        TactileEngine.shared.beadClick()
                        withAnimation(.snappy) {
                            if expandedCode == play.code { expandedCode = nil }
                            app.setShelf(codes.filter { $0 != play.code })
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondaryText.opacity(0.70))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("从这周拿掉", "Remove from this week"))
                }

                HStack(spacing: 4) {
                    Circle().fill(col).frame(width: 6, height: 6)
                    Text(Palette.areaShortName(key))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(dark ? col : Crayon.ink(col))
                        .lineLimit(1)
                }

                Text(play.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 112, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                    .fill(dark ? Palette.lampCard : Color(hex: 0xFFFDF9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                    .strokeBorder(
                        isExpanded ? col : col.opacity(dark ? 0.30 : 0.22),
                        lineWidth: isExpanded ? 1.5 : 0.8
                    )
            )
            .shadow(color: .black.opacity(dark ? 0.22 : 0.06), radius: 3, y: 1.5)
            .contentShape(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
            .onTapGesture {
                TactileEngine.shared.beadClick()
                withAnimation(.snappy) {
                    expandedCode = isExpanded ? nil : play.code
                }
            }
        } else {
            VStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(dark ? Palette.amber.opacity(0.7) : Crayon.ink(Palette.bead).opacity(0.7))
                    .frame(width: 24, height: 24)
                    .background(
                        Circle().strokeBorder(
                            Palette.bead.opacity(dark ? 0.38 : 0.48),
                            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                        )
                    )
                Text(L10n.t("留白槽位", "Open slot"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.secondaryText)
                Text(L10n.t(codes.isEmpty ? "从下方轻点摆上" : "可再摆 1 个", codes.isEmpty ? "Tap below to add" : "Room for 1 more"))
                    .font(.caption2)
                    .foregroundStyle(Palette.secondaryText.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 112, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                    .fill(dark ? Color.white.opacity(0.03) : Color(hex: 0xE7D7BC).opacity(0.30))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                    .strokeBorder(Palette.bead.opacity(dark ? 0.35 : 0.45), style: StrokeStyle(lineWidth: 1.1, dash: [5, 4]))
            )
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Filter Bar & Expandable Candidates

    private func quickFilterBar(dark: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                let allSelected = areaFilter == nil && !unplayedOnly
                shelfChip(L10n.t("全部", "All"), selected: allSelected, color: nil, dark: dark) {
                    TactileEngine.shared.beadClick()
                    withAnimation(.snappy) {
                        areaFilter = nil
                        unplayedOnly = false
                    }
                }
                shelfChip(L10n.t("还没玩过", "Unplayed"), selected: unplayedOnly, color: Palette.bead, dark: dark) {
                    TactileEngine.shared.beadClick()
                    withAnimation(.snappy) {
                        unplayedOnly.toggle()
                    }
                }
                if let af = areaFilter {
                    let col = Palette.area(af)
                    Button {
                        TactileEngine.shared.beadClick()
                        withAnimation(.snappy) { areaFilter = nil }
                    } label: {
                        HStack(spacing: 5) {
                            Circle().fill(col).frame(width: 7, height: 7)
                            Text(Palette.areaShortName(af))
                            Image(systemName: "xmark")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(dark ? .white : Crayon.ink(col))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(col.opacity(dark ? 0.28 : 0.16)))
                        .overlay(Capsule().strokeBorder(Crayon.ink(col), lineWidth: 1.1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func candidateCard(_ p: Play, month: Int, codes: [String], full: Bool, dark: Bool) -> some View {
        let key = Palette.areaKey(of: p)
        let col = Palette.area(key)
        let ink = dark ? col : Crayon.ink(col)
        let count = app.record(p, j).count
        let isExpanded = expandedCode == p.code
        let ageBadge = p.from == p.to
            ? L10n.t("\(p.from) 月", "\(p.from) mo")
            : L10n.t("\(p.from)–\(p.to) 月", "\(p.from)–\(p.to) mo")

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Button {
                    TactileEngine.shared.beadClick()
                    withAnimation(.snappy) {
                        expandedCode = isExpanded ? nil : p.code
                    }
                } label: {
                    HStack(spacing: 12) {
                        TrayTile(code: p.code, color: col, flat: ArtStyle.current == .flat)
                            .frame(width: 56, height: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(p.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 5) {
                                Circle().fill(col).frame(width: 6, height: 6)
                                Text(Palette.areaShortName(key))
                                    .foregroundStyle(ink)
                                    .fontWeight(.semibold)
                                Text("·")
                                    .foregroundStyle(Palette.secondaryText)
                                Text(ageBadge)
                                    .foregroundStyle(Palette.secondaryText)
                                    .monospacedDigit()
                                Text("·")
                                    .foregroundStyle(Palette.secondaryText)
                                Text(count == 0 ? L10n.t("还没玩过", "New") : L10n.t("玩过 \(count) 次", "\(count)×"))
                                    .foregroundStyle(count == 0 ? (dark ? Palette.amber : Crayon.ink(Palette.bead)) : Palette.secondaryText)
                            }
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if full {
                    Text(L10n.t("已满", "Full"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Palette.secondaryText)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Palette.fill))
                        .accessibilityLabel(L10n.t("架上已满 4 个，可先从上方拿掉一个", "Shelf full (4/4), remove one above first"))
                } else {
                    Button {
                        TactileEngine.shared.beadClick()
                        withAnimation(.snappy) {
                            app.setShelf(codes + [p.code])
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Palette.accent)
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("加到这周", "Add to this week"))
                }
            }

            if isExpanded {
                inlinePreviewDrawer(for: p, month: month, dark: dark)
            }
        }
        .padding(12)
        .printCard(radius: Radius.card)
    }

    private func inlinePreviewDrawer(for p: Play, month: Int, dark: Bool) -> some View {
        let key = Palette.areaKey(of: p)
        let col = Palette.area(key)
        let ink = dark ? col : Crayon.ink(col)
        let targetMonth = max(p.from, min(p.to, month))

        return VStack(alignment: .leading, spacing: 8) {
            if !p.age.isEmpty {
                Text(L10n.t("适龄：\(p.age)", "Age: \(p.age)"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !p.prepare.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("准备", "Prepare"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(ink)
                    Text(p.prepare)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let firstStep = p.steps.first {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(L10n.t("第 1 / \(p.steps.count) 步", "Step 1 of \(p.steps.count)"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(ink)
                        Spacer()
                    }
                    Text(firstStep)
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            NavigationLink(value: Route.play(p.code, targetMonth)) {
                Label(L10n.t("打开完整图文步骤", "Open full step guide"), systemImage: "arrow.up.right.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.accent)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                .fill(col.opacity(dark ? 0.14 : 0.10))
        )
    }

    private func shelfChip(_ title: String, selected: Bool, color: Color?, dark: Bool, action: @escaping () -> Void) -> some View {
        let dotColor = color ?? Palette.accent
        return Button(action: action) {
            HStack(spacing: 5) {
                if let color {
                    Circle().fill(color).frame(width: 7, height: 7)
                }
                Text(title)
            }
            .font(.caption.weight(selected ? .bold : .semibold))
            .foregroundStyle(selected ? (color == nil ? .white : (dark ? .white : Crayon.ink(dotColor))) : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(
                    selected
                        ? (color == nil ? AnyShapeStyle(Palette.accentFill) : AnyShapeStyle(dotColor.opacity(dark ? 0.28 : 0.16)))
                        : AnyShapeStyle(dark ? Palette.lampCard : Palette.card)
                )
            )
            .overlay(
                Capsule().strokeBorder(
                    selected ? (color == nil ? Color.clear : Crayon.ink(dotColor)) : Palette.outline.opacity(0.28),
                    lineWidth: selected ? 1.25 : 0.75
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A play in a list: its own tray on its area's tile (as on the home page), the name and the age range.
struct PlayRowLabel: View {
    let play: Play
    @ScaledMetric(relativeTo: .body) private var w: CGFloat = 60
    var body: some View {
        HStack(spacing: 12) {
            TrayTile(code: play.code, color: Palette.area(Palette.areaKey(of: play)), flat: ArtStyle.current == .flat)
                .frame(width: min(w, 84), height: min(w, 84) * 0.75)
            VStack(alignment: .leading, spacing: 2) {
                Text(play.name)
                Text(play.age).font(.subheadline).foregroundStyle(Palette.secondaryText)
            }
        }
    }
}

/// Under health guidance (还要知道, 专题): what it is and what it is not.
enum HealthNote {
    static var text: String { L10n.t("以上为公开指南的摘要，不针对具体的孩子。药品和补充剂的品种、剂量请遵医嘱或药品说明书；孩子身体不适时，以医生的判断为准。", "Summary of public pediatric guidance, not advice for an individual child. Follow your doctor or label for medicines and supplements; always consult a doctor when your child is unwell.") }
}
