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

/// 这周一起玩: the three or four plays of the week, chosen for this month, turned by themselves when the week turns.
/// Here the parent changes them: takes one off, adds one this month suits, puts back one played last week, or asks
/// for a new week.
struct PlanView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.lamp) private var lamp
    @Environment(\.colorScheme) private var scheme
    @Binding var path: NavigationPath
    @State private var areaFilter: String? = nil
    @State private var unplayedOnly = false

    var body: some View {
        let dark = lamp || scheme == .dark
        let m = app.babyMonth ?? 0
        let current = app.weekShelf(m)
        let codes = current.plays.map(\.code)
        let full = codes.count >= Shelf.max
        // played last week (from the records) and not in this week: one tap puts it back
        let monday = app.today.monday.date, before = app.today.monday.plus(days: -7).date
        let lastWeek = app.content.activities.filter { p in !codes.contains(p.code) && j.plays(p.code).contains { $0.startDate >= before && $0.startDate < monday } }
        let more = Shelf.candidates(app.content, m).filter { p in !codes.contains(p.code) && !lastWeek.contains(p) }
        let availableAreas = ["A", "B", "C", "D", "E", "F"].filter { key in
            more.contains { Palette.areaKey(of: $0) == key }
        }
        let filteredMore = more.filter { p in
            let matchesArea = areaFilter == nil || Palette.areaKey(of: p) == areaFilter
            let matchesUnplayed = !unplayedOnly || app.record(p, j).count == 0
            return matchesArea && matchesUnplayed
        }

        List {
            Section {
                // changing the week is taking off and adding: each row says which, with its own button (no swipe to
                // find, no page pushed inside the sheet)
                ForEach(current.plays) { p in
                    HStack {
                        playLabel(p)
                        Spacer()
                        Button { withAnimation(.snappy) { app.setShelf(codes.filter { $0 != p.code }) } } label: {
                            Image(systemName: "minus.circle.fill").font(.title2).foregroundStyle(Palette.danger.opacity(0.85))
                        }
                        .buttonStyle(.plain).accessibilityLabel(L10n.t("从这周拿掉", "Remove from this week"))
                    }
                }
                Button(L10n.t("重新推荐", "Refresh picks"), systemImage: "arrow.triangle.2.circlepath") {
                    withAnimation(.snappy) { app.setShelf(Shelf.suggest(app.content, m, last: codes, played: { c in app.content.play(c).map { app.record($0, j).count } ?? 0 })) }
                }
            } header: { Text(L10n.t("这周 · \(codes.count) / \(Shelf.max) 个", "This Week · \(codes.count) / \(Shelf.max)")) } footer: { Text(L10n.t("观察、准备、示范、重复、轮换。每周三四个，孩子想重复就重复。", "Observe, prepare, show, repeat, rotate. Three or four a week — repeat as often as your child wants.")) }
            if !lastWeek.isEmpty {
                Section(L10n.t("上周玩过", "Played Last Week")) { ForEach(lastWeek) { p in addRow(p, codes: codes, full: full) } }
            }
            Section(L10n.t("这个月还可以玩 · \(filteredMore.count) 个", "More for This Month · \(filteredMore.count)")) {
                if more.count > 3 {
                    WrapLayout(spacing: 6) {
                        let allSelected = areaFilter == nil && !unplayedOnly
                        shelfChip(L10n.t("全部", "All"), selected: allSelected, color: nil, dark: dark) {
                            TactileEngine.shared.beadClick()
                            withAnimation(.snappy) { areaFilter = nil; unplayedOnly = false }
                        }
                        shelfChip(L10n.t("还没玩过", "Unplayed"), selected: unplayedOnly, color: Palette.bead, dark: dark) {
                            TactileEngine.shared.beadClick()
                            withAnimation(.snappy) { unplayedOnly.toggle() }
                        }
                        ForEach(availableAreas, id: \.self) { key in
                            let on = areaFilter == key
                            shelfChip(Palette.areaShortName(key), selected: on, color: Palette.area(key), dark: dark) {
                                TactileEngine.shared.beadClick()
                                withAnimation(.snappy) { areaFilter = on ? nil : key }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                }
                if filteredMore.isEmpty {
                    Text(L10n.t("当前筛选下没有更多玩法，换个分类看看", "No more picks in this filter"))
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(filteredMore) { p in addRow(p, codes: codes, full: full) }
                }
            }
        }
        .scrollContentBackground(.hidden).pageBackground()
        .navigationTitle(L10n.t("这周一起玩", "This Week"))
        .toolbar(.hidden, for: .tabBar)
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
    private func addRow(_ p: Play, codes: [String], full: Bool) -> some View {
        HStack {
            playLabel(p)
            Spacer()
            Button { withAnimation(.snappy) { app.setShelf(codes + [p.code]) } } label: { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Palette.accent) }.buttonStyle(.plain)
                .disabled(full).opacity(full ? 0.3 : 1).accessibilityLabel(L10n.t("加到这周", "Add to this week"))
        }
    }
    private func playLabel(_ p: Play) -> some View { PlayRowLabel(play: p) }
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
