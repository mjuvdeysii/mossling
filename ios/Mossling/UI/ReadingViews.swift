import SwiftUI

/// A topic page (sleep, safe sleep, feeding, teeth and screens, when to see a doctor).
struct TopicView: View {
    let topic: Topic
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BlocksView(blocks: topic.blocks)

                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        if !topic.sourceTitle.isEmpty {
                            Label(topic.sourceTitle, systemImage: "books.vertical")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(HealthNote.text)
                            .font(.footnote)
                            .foregroundStyle(Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)
                } label: {
                    Label(L10n.t("参考来源与医疗说明", "Sources & Medical Note"), systemImage: "books.vertical")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.secondaryText)
                }
                .tint(Palette.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(Palette.fill.opacity(0.65)))
            }
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 40)
        }
        .calmWhileScrolling()
        .pageBackground()
        .navigationTitle(topic.title).navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
    }
}

/// Search scope filter pills for `SearchView` results.
enum SearchScope: String, CaseIterable, Identifiable {
    case all, tools, foods, plays, months, topics
    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: L10n.t("全部", "All")
        case .tools: L10n.t("小器具", "Tools")
        case .foods: L10n.t("辅食", "Foods")
        case .plays: L10n.t("活动", "Plays")
        case .months: L10n.t("月份", "Months")
        case .topics: L10n.t("专题", "Topics")
        }
    }
}

struct SearchResults {
    let tools: [QuietToolResult]
    let foods: [FoodItem]
    let plays: [Play]
    let months: [Month]
    let topics: [Topic]

    var isEmpty: Bool {
        tools.isEmpty && foods.isEmpty && plays.isEmpty && months.isEmpty && topics.isEmpty
    }

    var totalCount: Int {
        tools.count + foods.count + plays.count + months.count + topics.count
    }

    func count(for scope: SearchScope) -> Int {
        switch scope {
        case .all: totalCount
        case .tools: tools.count
        case .foods: foods.count
        case .plays: plays.count
        case .months: months.count
        case .topics: topics.count
        }
    }
}

/// Pure testable search engine backing `SearchView` across tools, foods, plays, months, and topics.
enum SearchEngine {
    static func results(query raw: String, in content: Content) -> SearchResults {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else {
            return SearchResults(tools: [], foods: [], plays: [], months: [], topics: [])
        }
        let tools = QuietToolResult.all.filter { $0.matches(t) }
        let foods = FoodItem.catalog.filter {
            $0.zh.localizedCaseInsensitiveContains(t)
                || $0.en.localizedCaseInsensitiveContains(t)
                || $0.category.title.localizedCaseInsensitiveContains(t)
        }
        let plays = content.activities.filter {
            $0.name.localizedCaseInsensitiveContains(t)
                || $0.code.localizedCaseInsensitiveContains(t)
                || $0.steps.contains { $0.localizedCaseInsensitiveContains(t) }
                || $0.domains.contains { $0.localizedCaseInsensitiveContains(t) }
        }
        let months = content.months.filter { m in
            m.title.localizedCaseInsensitiveContains(t)
                || m.domains.contains { $0.text.localizedCaseInsensitiveContains(t) }
                || m.observe.contains { $0.items.contains { $0.localizedCaseInsensitiveContains(t) } }
                || m.notes.contains { $0.text.localizedCaseInsensitiveContains(t) }
        }
        let topics = content.topics.filter { tp in
            tp.title.localizedCaseInsensitiveContains(t)
                || tp.blocks.contains { ($0.text ?? "").localizedCaseInsensitiveContains(t) || ($0.items ?? []).contains { $0.localizedCaseInsensitiveContains(t) } }
        }
        return SearchResults(tools: tools, foods: foods, plays: plays, months: months, topics: topics)
    }

    static func quickQueries(for month: Int) -> [String] {
        switch month {
        case ...3:
            return L10n.isEnglish ? ["Sleep", "Tummy", "Lamp", "Feed", "Roll"] : ["睡眠", "俯卧", "夜灯", "喂养", "翻身"]
        case 4...8:
            return L10n.isEnglish ? ["Solids", "Sit", "Sleep", "Lamp", "Sound"] : ["辅食", "坐稳", "睡眠", "夜灯", "发声"]
        case 9...18:
            return L10n.isEnglish ? ["Stand", "Grasp", "Solids", "Sleep", "Lamp"] : ["站立", "抓握", "辅食", "睡眠", "夜灯"]
        default:
            return L10n.isEnglish ? ["Language", "Book", "Sleep", "Doctor", "Lamp"] : ["语言", "绘本", "睡眠", "医生", "夜灯"]
        }
    }
}

/// Visual Discovery Search Compass across Quiet Instruments, First Foods, plays, months, and care topics.
struct SearchView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var path: NavigationPath
    var initialQuery: String = ""
    @State private var q: String
    @State private var scope: SearchScope = .all

    init(path: Binding<NavigationPath>, initialQuery: String = "") {
        self._path = path
        self.initialQuery = initialQuery
        self._q = State(initialValue: initialQuery)
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        let m = app.babyMonth ?? 0
        let t = q.trimmingCharacters(in: .whitespacesAndNewlines)
        let res = SearchEngine.results(query: t, in: app.content)
        let quick = SearchEngine.quickQueries(for: m)
        let activeScope: SearchScope = (scope == .all || res.count(for: scope) > 0) ? scope : .all
        let toolCols = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: typeSize.isAccessibilitySize ? 2 : 3)
        let topicCols = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: typeSize.isAccessibilitySize ? 1 : 2)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                searchField(dark: dark)

                if t.isEmpty {
                    // 1. Visual Quiet Instruments Portal Matrix (2×3)
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: L10n.t("陪伴小器具", "Quiet Instruments"))
                        LazyVGrid(columns: toolCols, spacing: 10) {
                            ForEach(QuietToolResult.all) { tool in
                                toolPortalTile(tool, dark: dark)
                            }
                        }
                    }

                    // 2. Age-Aware 1-Tap Quick Queries
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: L10n.t("一键探索", "Quick Explore"))
                        WrapLayout(spacing: 8) {
                            ForEach(quick, id: \.self) { term in
                                Button {
                                    withAnimation(.snappy) { q = term; scope = .all }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(Palette.accent)
                                        Text(term)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule().fill(dark ? Color.white.opacity(0.08) : Palette.card)
                                    )
                                    .overlay(
                                        Capsule().strokeBorder(Palette.outline.opacity(dark ? 0.25 : 0.16), lineWidth: 0.85)
                                    )
                                }
                                .buttonStyle(.toy)
                            }
                        }
                    }

                    // 3. This Week's Plays
                    let weekPlays = app.weekShelf(m).plays
                    if !weekPlays.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            SectionTitle(title: L10n.t("这周一起玩", "This Week's Plays"))
                            VStack(spacing: 0) {
                                ForEach(Array(weekPlays.enumerated()), id: \.element.code) { idx, p in
                                    NavigationLink(value: Route.play(p.code, m)) {
                                        searchRow(last: idx == weekPlays.count - 1) {
                                            PlayRowLabel(play: p)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .printCard(radius: Radius.card)
                        }
                    }

                    // 4. Care Topics Grid
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: L10n.t("专题", "Topics"))
                        LazyVGrid(columns: topicCols, spacing: 10) {
                            ForEach(app.content.topics) { tp in
                                let mark = topicMark(for: tp)
                                NavigationLink(value: Route.topic(tp.id)) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            IconTile(symbol: mark.0, color: mark.1, size: 30)
                                            Spacer(minLength: 4)
                                            Image(systemName: "chevron.right")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(.tertiary)
                                        }
                                        Text(tp.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(11)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    .printCard(radius: Radius.tile)
                                }
                                .buttonStyle(.toy)
                            }
                        }
                    }
                } else if res.isEmpty {
                    emptyView(query: t, quick: quick, dark: dark)
                } else {
                    // Live Scope Filter Ribbon
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SearchScope.allCases) { s in
                                let cnt = res.count(for: s)
                                if s == .all || cnt > 0 {
                                    let on = activeScope == s
                                    Button {
                                        withAnimation(.snappy) { scope = s }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Text(s.label)
                                                .font(.caption.weight(on ? .bold : .semibold))
                                            Text("\(cnt)")
                                                .font(Typeface.numerals(11, relativeTo: .caption2, weight: .bold))
                                                .foregroundStyle(on ? .white.opacity(0.92) : Palette.secondaryText)
                                        }
                                        .foregroundStyle(on ? .white : .primary)
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(on ? Palette.accentFill : (dark ? Color.white.opacity(0.08) : Palette.card)))
                                        .overlay(Capsule().strokeBorder(on ? Color.clear : Palette.outline.opacity(0.18), lineWidth: 0.75))
                                    }
                                    .buttonStyle(.toy)
                                }
                            }
                        }
                        .padding(.horizontal, 1)
                    }

                    if (activeScope == .all || activeScope == .tools), !res.tools.isEmpty {
                        resultSection(L10n.t("陪伴小器具", "Quiet Instruments")) {
                            ForEach(Array(res.tools.enumerated()), id: \.element.id) { idx, tool in
                                toolResultRow(tool, last: idx == res.tools.count - 1)
                            }
                        }
                    }

                    if (activeScope == .all || activeScope == .foods), !res.foods.isEmpty {
                        let slice = Array(res.foods.prefix(8))
                        resultSection(L10n.t("百味食盒", "First Foods")) {
                            ForEach(Array(slice.enumerated()), id: \.element.id) { idx, food in
                                NavigationLink(value: Route.foodAtlas) {
                                    searchRow(last: idx == slice.count - 1 && res.foods.count <= 8) {
                                        HStack(spacing: 12) {
                                            FoodGlyphView(food: food, size: 32)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(food.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                                                HStack(spacing: 6) {
                                                    Text(food.category.title)
                                                        .font(.caption).foregroundStyle(Palette.secondaryText)
                                                    if food.isCommonAllergen {
                                                        Text(L10n.t("常见致敏", "Allergen"))
                                                            .font(.caption2.weight(.bold))
                                                            .foregroundStyle(Crayon.ink(Crayon.tangerine))
                                                            .padding(.horizontal, 6).padding(.vertical, 1)
                                                            .background(Capsule().fill(Crayon.tangerine.opacity(dark ? 0.22 : 0.14)))
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            if res.foods.count > 8 {
                                NavigationLink(value: Route.foodAtlas) {
                                    searchRow(last: true) {
                                        Text(L10n.t("查看全部 \(res.foods.count) 项匹配食材", "See all \(res.foods.count) matching foods"))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Palette.accent)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if (activeScope == .all || activeScope == .plays), !res.plays.isEmpty {
                        resultSection(L10n.t("活动", "Activities")) {
                            ForEach(Array(res.plays.enumerated()), id: \.element.code) { idx, p in
                                let targetMonth = app.babyMonth.map { max(p.from, min(p.to, $0)) } ?? p.from
                                NavigationLink(value: Route.play(p.code, targetMonth)) {
                                    searchRow(last: idx == res.plays.count - 1) {
                                        PlayRowLabel(play: p)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if (activeScope == .all || activeScope == .months), !res.months.isEmpty {
                        resultSection(L10n.t("月份", "Months")) {
                            ForEach(Array(res.months.enumerated()), id: \.element.month) { idx, mo in
                                NavigationLink(value: Route.month(mo.month)) {
                                    searchRow(last: idx == res.months.count - 1) {
                                        HStack(spacing: 12) {
                                            Bead(month: mo.month, here: mo.month == m, past: mo.month <= m)
                                                .scaleEffect(0.88)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(mo.month == 0 ? L10n.t("出生", "Newborn") : L10n.t("满 \(mo.month) 个月", mo.month == 1 ? "1 month" : "\(mo.month) months"))
                                                    .font(.body.weight(.semibold)).foregroundStyle(.primary)
                                                Text(mo.title)
                                                    .font(.subheadline).foregroundStyle(Palette.secondaryText)
                                                    .multilineTextAlignment(.leading)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if (activeScope == .all || activeScope == .topics), !res.topics.isEmpty {
                        resultSection(L10n.t("专题", "Topics")) {
                            ForEach(Array(res.topics.enumerated()), id: \.element.id) { idx, tp in
                                NavigationLink(value: Route.topic(tp.id)) {
                                    searchRow(last: idx == res.topics.count - 1) {
                                        topicLabel(tp)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .calmWhileScrolling()
        .pageBackground()
        .navigationTitle(L10n.t("搜索", "Search"))
        .toolbar(.hidden, for: .tabBar)
    }

    @ViewBuilder
    private func searchField(dark: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.accent)
            TextField(L10n.t("活动、月份、辅食或小器具", "Activities, months, foods, or tools"), text: $q)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !q.isEmpty {
                Button {
                    withAnimation(.snappy) { q = ""; scope = .all }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.t("清空搜索", "Clear search"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .printCard(radius: Radius.card)
    }

    @ViewBuilder
    private func toolPortalTile(_ tool: QuietToolResult, dark: Bool) -> some View {
        let label = VStack(spacing: 7) {
            ToolArtBadge(toolId: tool.artId, size: 36, flat: ArtStyle.current == .flat)
            Text(tool.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .printCard(radius: Radius.tile)

        if let route = tool.route {
            NavigationLink(value: route) { label }.buttonStyle(.toy)
        } else if let jRoute = tool.journalRoute {
            NavigationLink(value: jRoute) { label }.buttonStyle(.toy)
        } else if let url = tool.url {
            Button { openURL(url) } label: { label }.buttonStyle(.toy)
        }
    }

    @ViewBuilder
    private func toolResultRow(_ tool: QuietToolResult, last: Bool) -> some View {
        let row = searchRow(last: last) {
            HStack(spacing: 12) {
                ToolArtBadge(toolId: tool.artId, size: 34, flat: ArtStyle.current == .flat)
                Text(tool.title).font(.body.weight(.medium)).foregroundStyle(.primary)
            }
        }
        if let route = tool.route {
            NavigationLink(value: route) { row }.buttonStyle(.plain)
        } else if let jRoute = tool.journalRoute {
            NavigationLink(value: jRoute) { row }.buttonStyle(.plain)
        } else if let url = tool.url {
            Button { openURL(url) } label: { row }.buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func resultSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: title)
            VStack(spacing: 0) { content() }
                .printCard(radius: Radius.card)
        }
    }

    @ViewBuilder
    private func searchRow<Content: View>(last: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                content()
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
            if !last { Divider().padding(.leading, 14) }
        }
    }

    @ViewBuilder
    private func emptyView(query: String, quick: [String], dark: Bool) -> some View {
        VStack(spacing: 10) {
            TimelineView(.periodic(from: .now, by: 1.3)) { tl in
                let side: Double = Int(tl.date.timeIntervalSinceReferenceDate / 1.3) % 2 == 0 ? -0.9 : 0.9
                Creature(kind: app.companion, look: CGPoint(x: side, y: 0.1), alive: true, lookSeconds: 0.5)
                    .frame(width: 64 * app.companion.scale, height: 64 * app.companion.scale)
            }
            .frame(height: 72).accessibilityHidden(true)
            Text(L10n.t("没有找到「\(query)」", "No results for \"\(query)\"")).font(.headline)
            Text(L10n.t("试试下方常用关键词", "Try a quick keyword below")).font(.subheadline).foregroundStyle(Palette.secondaryText)
            WrapLayout(spacing: 8) {
                ForEach(quick, id: \.self) { term in
                    Button {
                        withAnimation(.snappy) { q = term; scope = .all }
                    } label: {
                        Text(term)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(dark ? Color.white.opacity(0.08) : Palette.card))
                    }
                    .buttonStyle(.toy)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .printCard(radius: Radius.card)
    }

    private func topicMark(for tp: Topic) -> (String, Color) {
        let i = app.content.topics.firstIndex { $0.id == tp.id } ?? 0
        return topicMarks[i % topicMarks.count]
    }

    /// A topic with its own mark, as on the month's page.
    private func topicLabel(_ tp: Topic) -> some View {
        let mark = topicMark(for: tp)
        return Label { Text(tp.title).foregroundStyle(.primary) } icon: { IconTile(symbol: mark.0, color: mark.1) }
    }
}

struct QuietToolResult: Identifiable {
    let id: String
    let artId: String
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
        QuietToolResult(id: "lamp", artId: "bedside_lamp", zh: "床头夜灯", en: "Bedside Lamp", keywords: ["夜灯", "声景", "呼吸", "白噪音", "白噪声", "助眠", "sound", "sleep", "breath", "lamp"], symbol: "lamp.desk.fill", color: Palette.amber, url: URL(string: "mossling://lamp")),
        QuietToolResult(id: "toybox", artId: "sensory_toybox", zh: "感官玩具盒", en: "Sensory Toybox", keywords: ["木琴", "金珠", "雨棒", "萤火", "视卡", "黑白", "xylophone", "rainstick", "fireflies", "contrast"], symbol: "music.note", color: Crayon.teal, route: .toybox(.xylophone)),
        QuietToolResult(id: "foods", artId: "first_foods", zh: "百味食盒", en: "First Foods", keywords: ["辅食", "食材", "致敏", "食盒", "味觉", "food", "allergen", "solids"], symbol: "carrot.fill", color: Crayon.leaf, route: .foodAtlas),
        QuietToolResult(id: "rhythm", artId: "rhythm_dial", zh: "昼夜节律盘", en: "Rhythm Dial", keywords: ["节律", "昼夜", "统计", "作息", "rhythm", "dial", "circadian"], symbol: "sun.and.horizon.fill", color: Crayon.lilac, journalRoute: .stats),
        QuietToolResult(id: "book", artId: "storybook", zh: "成长绘本", en: "Storybook", keywords: ["绘本", "成长册", "相纸", "book", "storybook"], symbol: "book.pages.fill", color: Crayon.caramel, route: .book),
        QuietToolResult(id: "capsules", artId: "time_capsules", zh: "时光胶囊信笺", en: "Time Capsules", keywords: ["胶囊", "信", "火漆", "capsule", "letter", "wax"], symbol: "envelope.badge.fill", color: Palette.bead, route: .capsules),
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
