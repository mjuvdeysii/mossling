import SwiftUI

/// The three lands of the map, a year each, with their colours.
enum Land: Int, CaseIterable {
    case meadow, forest, river
    static func of(_ m: Int) -> Land { m < 12 ? .meadow : m < 24 ? .forest : .river }
    var name: String { switch self { case .meadow: L10n.t("草地", "Meadow"); case .forest: L10n.t("森林小丘", "Forest Hills"); case .river: L10n.t("小河村庄", "River Village") } }
    var years: String { switch self { case .meadow: L10n.t("0–1 岁", "0–1 yr"); case .forest: L10n.t("1–2 岁", "1–2 yrs"); case .river: L10n.t("2–3 岁", "2–3 yrs") } }
    var ground: Color { switch self { case .meadow: .dyn(0xE3F1CF, 0x1F2B1C); case .forest: .dyn(0xD5E8C0, 0x1B2719); case .river: .dyn(0xE6EFD9, 0x1E2620) } }
    var crayon: Color { switch self { case .meadow: Crayon.leaf; case .forest: Crayon.tangerine; case .river: Crayon.sky } }
    var symbol: String { switch self { case .meadow: "leaf.fill"; case .forest: "tree.fill"; case .river: "house.fill" } }
}

/// A bead with the month on it, like the beads of a Montessori bead chain: a glossy sphere in the land's colour for
/// months lived, a larger golden one for the child's month, a pale glass one for months ahead.
struct Bead: View {
    let month: Int, here: Bool, past: Bool
    var body: some View {
        let d: CGFloat = here ? 48 : 38
        let c = here ? Palette.bead : Land.of(month).crayon
        ZStack {
            if here || past {
                Circle().fill(RadialGradient(colors: [c.mix(with: .white, by: 0.22), c, c.mix(with: .black, by: 0.14)], center: UnitPoint(x: 0.32, y: 0.28), startRadius: 0, endRadius: d * 0.72))
            } else {
                Circle().fill(RadialGradient(colors: [.white.opacity(0.95), c.mix(with: .white, by: 0.7).opacity(0.9)], center: UnitPoint(x: 0.32, y: 0.28), startRadius: 0, endRadius: d * 0.72))
                Circle().strokeBorder(c.opacity(0.45), lineWidth: 1.5)
            }
            Text("\(month)").font(Typeface.numerals(here ? 19 : 15, relativeTo: .footnote, weight: .bold))
                .foregroundStyle(here ? Color(hex: 0x4A3300) : past ? Color.white : c.mix(with: .black, by: 0.35))
                .shadow(color: .black.opacity(past ? 0.25 : 0), radius: 0.5, y: 0.6)
        }
        .frame(width: d, height: d)
        .shadow(color: c.opacity(0.22), radius: here ? 5 : 3, y: here ? 3 : 2)
    }
}

/// One month as a chapter: the cover picture, then the month in order — points, plays, the month's parts, topics.
/// Other months are a step away: ‹ › at the top, or the month list from the title.
struct MonthView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.lamp) private var lamp
    @Environment(\.colorScheme) private var scheme
    @State private var month: Int
    init(month: Int) { _month = State(initialValue: month) }

    var body: some View {
        let mo = app.content.month(month), m = month
        let dark = lamp || scheme == .dark
        let chapterLabel = m == 0 ? L10n.t("出生：\(mo.title)", "Birth: \(mo.title)") : L10n.t("满 \(m) 个月：\(mo.title)", "Month \(m): \(mo.title)")
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // the month's living chapter stage beside its title (stacks cleanly on Accessibility text sizes)
                Group {
                    if type.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 10) {
                            LivingMonthCoverStage(
                                month: m,
                                dark: dark,
                                festive: m == 12 || m == 24 || m == 36,
                                interactive: true,
                                compact: false
                            )
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Land.of(m).crayon.opacity(dark ? 0.36 : 0.24), lineWidth: 1)
                            )
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(chapterLabel)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(mo.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                                if let b = app.birth {
                                    let d = b.plus(months: m)
                                    let dateStr = L10n.isEnglish ? "\(d.m)/\(d.d)" : d.md
                                    Label(dateStr + (app.babyMonth == m ? L10n.t(" · 宝宝在这一站", " · Current chapter") : ""), systemImage: "calendar")
                                        .font(.caption).foregroundStyle(Palette.secondaryText)
                                }
                            }
                        }
                    } else {
                        HStack(alignment: .center, spacing: 14) {
                            LivingMonthCoverStage(
                                month: m,
                                dark: dark,
                                festive: m == 12 || m == 24 || m == 36,
                                interactive: true,
                                compact: false
                            )
                            .frame(width: 156)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Land.of(m).crayon.opacity(dark ? 0.36 : 0.24), lineWidth: 1)
                            )
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(chapterLabel)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(mo.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                                if let b = app.birth {
                                    let d = b.plus(months: m)
                                    let dateStr = L10n.isEnglish ? "\(d.m)/\(d.d)" : d.md
                                    Label(dateStr + (app.babyMonth == m ? L10n.t(" · 宝宝在这一站", " · Current chapter") : ""), systemImage: "calendar")
                                        .font(.caption).foregroundStyle(Palette.secondaryText)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 4)
                MonthBody(month: m).padding(.horizontal, 16).padding(.top, 14)
            }
            .padding(.bottom, 40)
        }
        .calmWhileScrolling()
        .pageBackground()
        .navigationTitle(m == 0 ? L10n.t("出生", "Birth") : L10n.t("满 \(m) 个月", "Month \(m)"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(L10n.t("上个月", "Previous"), systemImage: "chevron.left") { withAnimation(.snappy) { month -= 1 } }.disabled(m <= 0)
                Menu {
                    ForEach(0...36, id: \.self) { k in
                        Button { withAnimation(.snappy) { month = k } } label: {
                            Text((k == 0 ? L10n.t("出生", "Birth") : L10n.t("满 \(k) 个月", "Month \(k)")) + (k == app.babyMonth ? L10n.t(" · 宝宝在这里", " · Now") : ""))
                        }
                    }
                } label: { Image(systemName: "calendar") }
                .accessibilityLabel(L10n.t("选一个月", "Choose month"))
                Button(L10n.t("下个月", "Next"), systemImage: "chevron.right") { withAnimation(.snappy) { month += 1 } }.disabled(m >= 36)
            }
        }
        .sensoryFeedback(.selection, trigger: month)
    }
}

/// The month at a glance — what to focus on, what to look out for — as one card. Folded (on 本月), each point shows
/// two lines and the card opens in place to the whole of them; a point that only names a play is left to the plays.
struct MonthPoints: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduce
    let month: Int
    var folded = true
    @State private var open = false
    var body: some View {
        let c = app.content, mo = c.month(month)
        let points = mo.highlights.filter { c.play($0.anchor ?? "") == nil }
        if !points.isEmpty {
            let shut = folded && !open
            let box = Box {
                ForEach(Array(points.enumerated()), id: \.offset) { i, h in
                    let k = h.kind.lowercased()
                    let (sym, col): (String, Color) = (h.kind.contains("留意") || k.contains("keep in mind") || k.contains("watch") || k.contains("safety")) ? ("exclamationmark.triangle.fill", Crayon.tangerine) : (h.kind.contains("先做") || k.contains("try first") || k.contains("first") || k.contains("care")) ? ("checklist", Crayon.sky) : ("eye.fill", Palette.accent)
                    BoxRow(symbol: sym, color: col, title: h.kind, text: shut ? String(h.text.prefix(34)) + (h.text.count > 34 ? "…" : "") : h.text, last: i == points.count - 1) {
                        if folded && i == 0 {
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                                .rotationEffect(.degrees(open ? 180 : 0))
                        }
                    }
                }
            }
            .clipped()
            .animation(reduce ? nil : CalmMotion.accordionSpring, value: open)

            if folded {
                Button {
                    TactileEngine.shared.beadClick()
                    withAnimation(reduce ? nil : CalmMotion.accordionSpring) { open.toggle() }
                } label: { box }
                    .buttonStyle(.plain)
                    .accessibilityValue(open ? L10n.t("已展开", "Expanded") : L10n.t("已折叠", "Collapsed"))
                    .accessibilityHint(open ? L10n.t("收起", "Collapse") : L10n.t("展开全文", "Expand"))
            } else {
                box
            }
        }
    }
}

private struct MonthBody: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    let month: Int
    var body: some View {
        let c = app.content, m = month
        VStack(alignment: .leading, spacing: 18) {
            MonthPoints(month: m, folded: false)

            let plays = c.plays(of: m)
            if !plays.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    // how many were played, not a list to complete: the four cards themselves show how many there are
                    // counted as the cards are: a card with its ×N is a play counted here
                    let done: Int = plays.filter { app.record($0, j).count > 0 }.count
                    SectionTitle(title: L10n.t("一起玩", "Play Together"), detail: done > 0 ? L10n.t("其中 \(done) 个玩过", "\(done) played") : nil)
                    PlaysLeadGrid(plays: plays, month: m)
                }
            }

            MonthParts(month: m)

            Topics()

            if m == 36 { StoryGoesOn(primary: app.companion) }
        }
    }
}

/// The parts of a month belonging strictly to Tab 2 (`留念 / Keepsakes`):
/// `可以留意` and `接种与儿保` as two trackable cards; `六个方面` and `还要知道` as compact reading tiles.
/// (`一天的节奏` lives on Tab 1 `台灯`, and `生长曲线` sits directly at the top of `留念`.)
struct MonthParts: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var type
    let month: Int
    var body: some View {
        let mo = app.content.month(month), m = month
        let all = parts(mo, m)
        let trackable = all.filter { $0.total > 0 }
        let reading = all.filter { $0.total == 0 }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: type.isAccessibilitySize ? 1 : 2)

        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: L10n.t("这个月", "This Month"))

            if !trackable.isEmpty {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(trackable.enumerated()), id: \.offset) { _, p in
                        let card = BigPart(symbol: p.symbol, color: p.color, title: p.title, done: p.done, total: p.total)
                        NavigationLink(value: p.route) { card }.buttonStyle(.toy)
                    }
                }
            }

            if !reading.isEmpty {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(reading.enumerated()), id: \.offset) { _, p in
                        let card = MonthTile(symbol: p.symbol, color: p.color, title: p.title, note: p.note) {
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        NavigationLink(value: p.route) { card }.buttonStyle(.toy)
                    }
                }
            }
        }
    }
    /// A keepsake-domain part of the month.
    private struct Part { let symbol: String; let color: Color; let title: String; let note: String; var done = 0; var total = 0; let route: KeepsakesRoute }
    private func parts(_ mo: Month, _ m: Int) -> [Part] {
        var out: [Part] = []
        if !mo.observe.isEmpty {
            let total = mo.observe.reduce(0) { $0 + $1.items.count }, done = app.count(m, TickKind.observed)
            out.append(Part(symbol: "eye.fill", color: Crayon.sky, title: L10n.t("可以留意", "Things to Notice"), note: "\(done) / \(total)", done: done, total: total, route: .observe(m)))
        }
        let careMonth = (m == app.babyMonth && app.isUsingCorrectedAge) ? (app.actualAge?.bookMonth ?? m) : m
        let careMo = careMonth == m ? mo : app.content.month(careMonth)
        let region = HealthRegion.defaultRegion()
        if region == .cn {
            if !careMo.vaccines.isEmpty || !careMo.checkups.isEmpty {
                let total = careMo.vaccines.count + careMo.checkups.count
                let done = app.count(careMonth, TickKind.vaccine) + app.count(careMonth, TickKind.checkup)
                out.append(Part(symbol: "syringe.fill", color: Crayon.pink, title: L10n.t("接种与儿保", "Vaccines & Check-ups"), note: "\(done) / \(total)", done: done, total: total, route: .care(careMonth)))
            }
        } else {
            let regItems = HealthRegion.schedule(for: region, month: careMonth)
            if !regItems.isEmpty || !careMo.vaccines.isEmpty || !careMo.checkups.isEmpty {
                let total = regItems.count
                let done = regItems.filter { item in
                    let kind = item.kind == "vaccine" ? TickKind.vaccine : TickKind.checkup
                    return app.ticked(careMonth, kind, "reg-\(region.rawValue)-\(item.id)")
                }.count
                out.append(Part(symbol: "syringe.fill", color: Crayon.pink, title: L10n.t("接种与儿保", "Vaccines & Check-ups"), note: total > 0 ? "\(done) / \(total)" : L10n.t("参考日程", "Schedule"), done: done, total: total, route: .care(careMonth)))
            }
        }
        out.append(Part(symbol: "circle.hexagongrid.fill", color: Crayon.teal, title: L10n.t("六个方面", "Six Areas"), note: L10n.t("这个月的样子", "This month's overview"), route: .areas(m)))
        if !mo.notes.isEmpty { out.append(Part(symbol: "lightbulb.fill", color: Crayon.sunflower, title: L10n.t("还要知道", "Good to Know"), note: L10n.t("\(mo.notes.count) 条", mo.notes.count == 1 ? "1 note" : "\(mo.notes.count) notes"), route: .notes(m))) }
        return out
    }
}

/// A large month part: its picture, its name and how far along the month is, as a ring with the count.
private struct BigPart: View {
    let symbol: String, color: Color, title: String, done: Int, total: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                IconTile(symbol: symbol, color: color, size: 46)
                Spacer(minLength: 0)
                Ring(done: done, total: total, color: color, size: 34)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(done) / \(total)")
                    .font(Typeface.numerals(13, relativeTo: .footnote))
                    .foregroundStyle(Crayon.ink(color))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(color.opacity(0.12))
        .printCard(radius: Radius.card)
        .accessibilityElement(children: .combine)
    }
}

struct MonthTile<Accessory: View>: View {
    let symbol: String, color: Color, title: String
    var note: String? = nil
    @ViewBuilder let accessory: Accessory
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                IconTile(symbol: symbol, color: color, size: 36).frame(maxWidth: .infinity, alignment: .leading)
                accessory.scaleEffect(0.8)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(note ?? " ")
                    .font(.caption2)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .monospacedDigit()
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .printCard(radius: Radius.card)
        .accessibilityElement(children: .combine)
    }
}

/// A play tile that switches cleanly to its canonical Explore home (`Tab 0`) with context.
struct PlayTileLink: View {
    @Environment(AppModel.self) private var app
    @Environment(AppRouter.self) private var router: AppRouter?
    @Environment(JournalStore.self) private var j
    @Environment(\.aloneInRow) private var alone
    let play: Play, month: Int
    var form: PlayTile.Form = .cell
    var body: some View {
        // alone across a row: the wide form (picture beside the words), not a tile pulled out of shape
        let f: PlayTile.Form = alone && (form == .cell || form == .mini) ? .row : form
        Button {
            TactileEngine.shared.beadClick()
            router?.openExplore(.play(play.code, month))
        } label: {
            PlayTile(play: play, times: app.record(play, j).count, form: f)
        }
        .buttonStyle(.toy)
        .contextMenu { PlayActions(play: play, month: month) }
    }
}

/// The actions on a play, for its menus: done once more, take back the last time, on the shelf, share.
struct PlayActions: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    let play: Play, month: Int
    /// On the play's own page, which has 记一次 by its count: the menu does not record a second way.
    var inPage = false
    var body: some View {
        let rec = app.record(play, j)
        let shelf = app.weekShelf(app.babyMonth ?? month).plays.map(\.code)
        if !inPage { Button(rec.count == 0 ? L10n.t("玩过了", "Played") : L10n.t("又玩了一次", "Played again"), systemImage: "checkmark.circle") { if app.mayKeep() { app.didPlay(play, month: month, j) } } }
        if rec.count > 0 { Button(L10n.t("撤销最近一次", "Undo last play"), systemImage: "arrow.uturn.backward") { app.undoPlay(play, month: month, j) } }
        let m = app.babyMonth ?? month
        if app.todayPlay(m, j)?.code != play.code {
            Button(L10n.t("今天玩这个", "Play today"), systemImage: "sun.max") { withAnimation(.snappy) { app.playToday(play, m) } }
        }
        if shelf.contains(play.code) {
            Button(L10n.t("从这周拿掉", "Remove from this week"), systemImage: "minus.circle") { app.setShelf(shelf.filter { $0 != play.code }) }
        } else if shelf.count < Shelf.max {
            Button(L10n.t("加到这周", "Add to this week"), systemImage: "plus.circle") { app.setShelf(shelf + [play.code]) }
        }
        if let cardURL = CardWebCodec.encodeURL(from: play, babyName: app.nickname) {
            ShareLink(item: cardURL, message: Text(L10n.t("\(play.name)（\(play.code)）", "\(play.name) (\(play.code))"))) {
                Label(L10n.t("发给家人 H5 卡", "Share Family H5 Card"), systemImage: "rectangle.portrait.and.arrow.right")
            }
        }
        ShareLink(item: L10n.t("\(play.name)（\(play.code)）\n", "\(play.name) (\(play.code))\n") + play.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")) { Label(L10n.t("分享纯文本", "Share Text"), systemImage: "square.and.arrow.up") }
    }
}

/// Pure layout & cross-linking helpers for the 6-Area Montessori Constellation Lens.
enum AreasConstellationMetrics {
    static let canonicalKeys = ["A", "B", "C", "D", "E", "F"]

    static func normalizedKey(_ key: String) -> String {
        let p = String(key.prefix(1)).uppercased()
        return canonicalKeys.contains(p) ? p : "C"
    }

    static func orderedDomains(_ domains: [Area], focus: String?) -> [Area] {
        let fKey = focus.map(normalizedKey)
        let focusList = fKey.map { f in domains.filter { normalizedKey($0.key) == f } } ?? []
        let rest = canonicalKeys.filter { $0 != fKey }.flatMap { k in
            domains.filter { normalizedKey($0.key) == k }
        }
        return focusList + rest
    }

    static func matchingPlays(for domainKey: String, month: Int, in content: Content) -> [Play] {
        let target = normalizedKey(domainKey)
        var seen: Set<String> = []
        let pool = (content.plays(of: month) + Shelf.candidates(content, month)).filter { p in
            guard seen.insert(p.code).inserted else { return false }
            return Palette.areaKey(of: p) == target
        }
        return pool
    }

    static func vertex(index: Int, total: Int, radius: CGFloat, center: CGPoint) -> CGPoint {
        let count = max(1, total)
        let angle = -Double.pi / 2 + Double(index) / Double(count) * 2 * .pi
        return CGPoint(
            x: center.x + Foundation.cos(angle) * radius,
            y: center.y + Foundation.sin(angle) * radius
        )
    }
}

/// Filter modes for `CareView` checklist board.
enum CareFilterMode: String, CaseIterable, Identifiable {
    case all, pending, done
    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: L10n.t("全部", "All")
        case .pending: L10n.t("待完成", "To Do")
        case .done: L10n.t("已记", "Done")
        }
    }

    func matches(ticked: Bool) -> Bool {
        switch self {
        case .all: true
        case .pending: !ticked
        case .done: ticked
        }
    }
}

/// 6-Area Montessori Constellation Lens: interactive 6-petal selector, active domain spotlight
/// with linked plays for the month, and compact quick-peek rows for the other five areas.
struct AreasView: View {
    @Environment(AppModel.self) private var app
    @Environment(AppRouter.self) private var router: AppRouter?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.dynamicTypeSize) private var typeSize
    let month: Int
    var initialAreaKey: String? = nil
    @State private var selectedKey: String?

    init(month: Int, initialAreaKey: String? = nil) {
        self.month = month
        self.initialAreaKey = initialAreaKey
        self._selectedKey = State(initialValue: initialAreaKey.map(AreasConstellationMetrics.normalizedKey))
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        let mo = app.content.month(month)
        let ordered = AreasConstellationMetrics.orderedDomains(mo.domains, focus: mo.focus)
        let focusKey = mo.focus.map(AreasConstellationMetrics.normalizedKey)
        let activeKey = selectedKey ?? AreasConstellationMetrics.normalizedKey(ordered.first?.key ?? focusKey ?? "A")
        let activeDomain = ordered.first { AreasConstellationMetrics.normalizedKey($0.key) == activeKey } ?? ordered.first
        let others = ordered.filter { AreasConstellationMetrics.normalizedKey($0.key) != activeKey }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !ordered.isEmpty {
                    constellationCard(ordered: ordered, activeKey: activeKey, focusKey: focusKey, dark: dark)
                }

                if let activeDomain {
                    spotlightCard(activeDomain, focusKey: focusKey, dark: dark)
                }

                if !others.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(title: L10n.t("其余五个方面", "Other Five Areas"))
                        VStack(spacing: 0) {
                            ForEach(Array(others.enumerated()), id: \.offset) { idx, d in
                                let key = AreasConstellationMetrics.normalizedKey(d.key)
                                let col = Palette.area(d.key)
                                Button {
                                    withAnimation(.snappy) { selectedKey = key }
                                } label: {
                                    HStack(spacing: 12) {
                                        IconTile(symbol: Palette.areaSymbol(d.key), color: col, size: 30)
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 6) {
                                                Text(d.name)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(.primary)
                                                if key == focusKey {
                                                    Text(L10n.t("本月重点", "Focus"))
                                                        .font(.caption2.weight(.bold))
                                                        .foregroundStyle(Color(hex: 0x4A3300))
                                                        .padding(.horizontal, 6).padding(.vertical, 1)
                                                        .background(Capsule().fill(Palette.bead))
                                                }
                                            }
                                            Text(d.text)
                                                .font(.caption)
                                                .foregroundStyle(Palette.secondaryText)
                                                .lineLimit(1)
                                        }
                                        Spacer(minLength: 4)
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if idx < others.count - 1 {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        }
                        .printCard(radius: Radius.card)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .calmWhileScrolling()
        .pageBackground()
        .navigationTitle(L10n.t("六个方面", "Six Areas"))
        .navigationSubtitle(month == 0 ? L10n.t("出生", "Newborn") : L10n.t("满 \(month) 个月", month == 1 ? "1 month" : "\(month) months"))
    }

    @ViewBuilder
    private func constellationCard(ordered: [Area], activeKey: String, focusKey: String?, dark: Bool) -> some View {
        let chipColumns = Array(repeating: GridItem(.flexible(), spacing: 7), count: typeSize.isAccessibilitySize ? 1 : 2)
        let wheelSize: CGFloat = 118
        let center = CGPoint(x: wheelSize / 2, y: wheelSize / 2)
        let radius = wheelSize * 0.34
        let wheel = ZStack {
            Path { poly in
                for idx in 0..<ordered.count {
                    let pt = AreasConstellationMetrics.vertex(index: idx, total: ordered.count, radius: radius, center: center)
                    if idx == 0 { poly.move(to: pt) } else { poly.addLine(to: pt) }
                }
                poly.closeSubpath()
            }
            .stroke(Palette.outline.opacity(dark ? 0.30 : 0.20), lineWidth: 1.2)

            ForEach(Array(ordered.enumerated()), id: \.offset) { idx, d in
                let key = AreasConstellationMetrics.normalizedKey(d.key)
                let isSelected = (key == activeKey)
                let isFocus = (key == focusKey)
                let pt = AreasConstellationMetrics.vertex(index: idx, total: ordered.count, radius: radius, center: center)
                let col = Palette.area(d.key)
                let r: CGFloat = isSelected ? 12.5 : 8.5

                Path { ray in
                    ray.move(to: center)
                    ray.addLine(to: pt)
                }
                .stroke(col.opacity(isSelected ? 0.65 : 0.25), lineWidth: isSelected ? 2.4 : 1.2)

                if isSelected {
                    Circle()
                        .fill(col.opacity(dark ? 0.28 : 0.20))
                        .frame(width: 36, height: 36)
                        .position(pt)
                }

                Circle()
                    .fill(col.opacity(isSelected ? 1.0 : 0.72))
                    .frame(width: r * 2, height: r * 2)
                    .overlay {
                        if isFocus {
                            Circle()
                                .fill(Palette.bead)
                                .frame(width: 8, height: 8)
                        } else {
                            Circle()
                                .fill(.white.opacity(0.65))
                                .frame(width: r * 0.45, height: r * 0.40)
                                .offset(x: -r * 0.10, y: -r * 0.25)
                        }
                    }
                    .position(pt)
            }

            let centerCol = Palette.area(activeKey)
            Circle()
                .fill(centerCol.opacity(0.22))
                .frame(width: 26, height: 26)
                .position(center)
            Circle()
                .fill(Palette.bead)
                .frame(width: 14, height: 14)
                .position(center)
        }
        .frame(width: wheelSize, height: wheelSize)
        .animation(.snappy, value: activeKey)
        .accessibilityHidden(true)

        let chips = LazyVGrid(columns: chipColumns, spacing: 7) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, d in
                let key = AreasConstellationMetrics.normalizedKey(d.key)
                let col = Palette.area(d.key)
                let isSelected = (key == activeKey)
                Button {
                    withAnimation(.snappy) { selectedKey = key }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: Palette.areaSymbol(d.key))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(isSelected ? .white : (dark ? col : Crayon.ink(col)))
                        Text(Palette.areaShortName(d.key))
                            .font(.caption.weight(isSelected ? .bold : .semibold))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                            .fill(isSelected ? col : (dark ? Color.white.opacity(0.06) : col.opacity(0.11)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                            .strokeBorder(isSelected ? Color.clear : col.opacity(dark ? 0.30 : 0.22), lineWidth: 0.75)
                    )
                }
                .buttonStyle(.toy)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }

        Group {
            if typeSize.isAccessibilitySize {
                VStack(spacing: 12) { wheel; chips }
            } else {
                HStack(alignment: .center, spacing: 10) { wheel; chips }
            }
        }
        .padding(12)
        .printCard(radius: Radius.card)
    }

    @ViewBuilder
    private func spotlightCard(_ d: Area, focusKey: String?, dark: Bool) -> some View {
        let key = AreasConstellationMetrics.normalizedKey(d.key)
        let col = Palette.area(d.key)
        let isFocus = (key == focusKey)
        let linkedPlays = AreasConstellationMetrics.matchingPlays(for: d.key, month: month, in: app.content)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconTile(symbol: Palette.areaSymbol(d.key), color: col, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(d.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if isFocus {
                        Text(L10n.t("本月重点领域", "Focus this month"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color(hex: 0x4A3300))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(Palette.bead))
                    }
                }
                Spacer(minLength: 0)
            }

            Text(rich(d.text))
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !linkedPlays.isEmpty {
                Divider().opacity(0.6)
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("关联本月活动", "Linked Plays This Month"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(dark ? col : Crayon.ink(col))

                    ForEach(linkedPlays.prefix(2)) { p in
                        Button {
                            TactileEngine.shared.beadClick()
                            router?.openExplore(.play(p.code, month))
                        } label: {
                            HStack(spacing: 10) {
                                ActivityPreviewThumb(play: p, color: col, flat: ArtStyle.current == .flat)
                                    .frame(width: 44, height: 33)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(p.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                    Text(p.age)
                                        .font(.caption)
                                        .foregroundStyle(Palette.secondaryText)
                                }
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(col.opacity(dark ? 0.14 : 0.08)))
                        }
                        .buttonStyle(.toy)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(col.opacity(dark ? 0.10 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(col.opacity(dark ? 0.36 : 0.28), lineWidth: 1.2)
        )
        .printCard(radius: Radius.card)
    }
}

/// The month's vaccinations and check-ups, to tick off.
/// A vaccine or check-up not yet ticked, and the month it belongs to.
struct DueItem { let month: Int; let kind: String; let key: String; let text: String }

extension AppModel {
    /// The vaccines and check-ups of `month` not yet ticked.
    func duePending(in month: Int) -> [DueItem] {
        guard month >= 0 else { return [] }
        let mo = content.month(month)
        let v = mo.vaccines.enumerated().map { DueItem(month: month, kind: TickKind.vaccine, key: "\($0.offset)", text: $0.element) }
        let c = mo.checkups.enumerated().map { DueItem(month: month, kind: TickKind.checkup, key: "\($0.offset)", text: $0.element) }
        return (v + c).filter { !ticked(month, $0.kind, $0.key) }
    }
    /// What the two months before `month` left unticked (further back is history, not a reminder).
    func duePending(before month: Int) -> [DueItem] {
        guard month > 0 else { return [] }
        let months = (max(0, month - 2)..<month).filter { k in content.months.contains { $0.month == k } }
        return months.flatMap { duePending(in: $0) }
    }
}

struct CareView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.dynamicTypeSize) private var typeSize
    let month: Int
    @State private var filter: CareFilterMode = .all
    @State private var region: HealthRegion = HealthRegion.defaultRegion()
    @State private var showingClinicSnapshot = false

    var body: some View {
        let dark = lamp || scheme == .dark
        let mo = app.content.month(month), m = month
        let earlier = app.duePending(before: m)
        let vDone = mo.vaccines.indices.filter { app.ticked(m, TickKind.vaccine, "\($0)") }.count
        let cDone = mo.checkups.indices.filter { app.ticked(m, TickKind.checkup, "\($0)") }.count
        let monthDone = vDone + cDone
        let monthTotal = mo.vaccines.count + mo.checkups.count

        let filteredVaccines = mo.vaccines.enumerated().filter { filter.matches(ticked: app.ticked(m, TickKind.vaccine, "\($0.offset)")) }
        let filteredCheckups = mo.checkups.enumerated().filter { filter.matches(ticked: app.ticked(m, TickKind.checkup, "\($0.offset)")) }
        let filteredEarlier = earlier.filter { filter.matches(ticked: app.ticked($0.month, $0.kind, $0.key)) }
        let regionalEntries = HealthRegion.schedule(for: region, month: m)
        let regKey: (HealthRegion.ReferenceEntry) -> (kind: String, key: String) = { item in
            (item.kind == "vaccine" ? TickKind.vaccine : TickKind.checkup, "reg-\(region.rawValue)-\(item.id)")
        }
        let filteredRegional = regionalEntries.filter { item in
            let rk = regKey(item)
            return filter.matches(ticked: app.ticked(m, rk.kind, rk.key))
        }
        let regDoneCount = regionalEntries.filter { item in
            let rk = regKey(item)
            return app.ticked(m, rk.kind, rk.key)
        }.count

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FlowRow(spacing: 8, lineSpacing: 8) {
                    ForEach(HealthRegion.allCases) { r in
                        let on = region == r
                        Button {
                            TactileEngine.shared.beadClick()
                            withAnimation(.snappy) { region = r }
                        } label: {
                            Text(r.shortLabel)
                                .font(.caption.weight(on ? .bold : .semibold))
                                .foregroundStyle(on ? .white : .primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(on ? Palette.accentFill : (dark ? Palette.lampCard : Palette.card)))
                                .overlay(Capsule().strokeBorder(on ? .clear : Palette.outline.opacity(0.22), lineWidth: 0.75))
                        }
                        .buttonStyle(.toy)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }

                if region != .cn {
                    let regPendingCount = max(0, regionalEntries.count - regDoneCount)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            IconTile(symbol: "globe.americas.fill", color: Crayon.sky, size: 28, round: true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(region.authorityHeadline)
                                    .font(.subheadline.weight(.bold))
                                Text(L10n.t("国际地区参考（具体安排以当地诊所为准）", "Regional Reference — confirm clinic dates locally"))
                                    .font(.caption)
                                    .foregroundStyle(Palette.secondaryText)
                            }
                            Spacer(minLength: 4)
                            if !regionalEntries.isEmpty {
                                Text("\(regDoneCount) / \(regionalEntries.count)")
                                    .font(Typeface.numerals(14, relativeTo: .subheadline, weight: .bold))
                                    .foregroundStyle(.primary)
                            }
                        }

                        if !regionalEntries.isEmpty {
                            WrapLayout(spacing: 8) {
                                ForEach(CareFilterMode.allCases) { mode in
                                    let on = (filter == mode)
                                    let cnt = switch mode {
                                    case .all: regionalEntries.count
                                    case .pending: regPendingCount
                                    case .done: regDoneCount
                                    }
                                    Button {
                                        withAnimation(.snappy) { filter = mode }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(mode.label)
                                                .font(.caption.weight(on ? .bold : .semibold))
                                            Text("\(cnt)")
                                                .font(Typeface.numerals(11, relativeTo: .caption2, weight: .bold))
                                                .opacity(on ? 0.92 : 0.72)
                                        }
                                        .foregroundStyle(on ? .white : .primary)
                                        .padding(.horizontal, 11).padding(.vertical, 6)
                                        .background(Capsule().fill(on ? Palette.accentFill : (dark ? Color.white.opacity(0.08) : Palette.fill)))
                                        .pillHitTarget()
                                    }
                                    .buttonStyle(.toy)
                                    .accessibilityAddTraits(on ? .isSelected : [])
                                }
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .printCard(radius: Radius.card)

                    if regionalEntries.isEmpty {
                        Text(L10n.t("该月龄在本地区通常无常规新增项目，请以当地诊所医嘱为准。", "No routine milestone visits listed for this month in this region — confirm locally with your clinician."))
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondaryText)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .printCard(radius: Radius.card)
                    } else if filteredRegional.isEmpty {
                        Text(filter == .done
                             ? L10n.t("还没有勾完的项目，轻点上方状态切换到待完成查看。", "Nothing logged yet — switch filter to see items due.")
                             : L10n.t("本月参考项目均已记下。", "All items for this month are checked off."))
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondaryText)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .printCard(radius: Radius.card)
                    } else {
                        Box(title: region.shortLabel, detail: "\(regDoneCount) / \(regionalEntries.count)") {
                            ForEach(Array(filteredRegional.enumerated()), id: \.element.id) { idx, item in
                                let rk = regKey(item)
                                CheckRow(
                                    text: item.title,
                                    on: app.ticked(m, rk.kind, rk.key),
                                    accent: item.kind == "vaccine" ? Crayon.cherry : Crayon.teal,
                                    last: idx == filteredRegional.count - 1
                                ) {
                                    app.toggle(m, rk.kind, rk.key, item.title)
                                }
                            }
                        }
                    }
                }

                if region == .cn && (monthTotal > 0 || !earlier.isEmpty) {
                    dualGaugeHeader(vDone: vDone, vTotal: mo.vaccines.count, cDone: cDone, cTotal: mo.checkups.count,
                                    earlierCount: earlier.count, monthDone: monthDone, monthTotal: monthTotal, dark: dark)
                }

                if let cue = HealthRegion.screeningCue(for: region, month: m) {
                    HStack(alignment: .top, spacing: 10) {
                        IconTile(symbol: "stethoscope", color: Crayon.teal, size: 30, round: true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.t("本次儿保重点筛查", "Screening Focus This Visit"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(dark ? Crayon.teal : Crayon.ink(Crayon.teal))
                            Text(cue)
                                .font(.footnote)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button {
                                TactileEngine.shared.beadClick()
                                showingClinicSnapshot = true
                            } label: {
                                Label(L10n.t("带进诊室：生成一页摘要", "Generate 1-Page Clinic PDF"), systemImage: "doc.text.magnifyingglass")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(dark ? Palette.amber : Crayon.ink(Crayon.teal))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .frame(minHeight: 44)
                                    .background(Capsule().fill(Crayon.teal.opacity(dark ? 0.22 : 0.14)))
                            }
                            .buttonStyle(.toy)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .printCard(radius: Radius.card)
                }

                if region == .cn && !filteredEarlier.isEmpty {
                    Box(title: L10n.t("之前没勾的", "Earlier unchecked"), detail: L10n.t("\(filteredEarlier.count) 项", "\(filteredEarlier.count)")) {
                        ForEach(Array(filteredEarlier.enumerated()), id: \.offset) { i, d in
                            let moText = d.month == 0 ? L10n.t("出生", "Newborn") : L10n.t("满 \(d.month) 个月", d.month == 1 ? "1 month" : "\(d.month) months")
                            CheckRow(text: d.text, on: app.ticked(d.month, d.kind, d.key), tag: moText, accent: Crayon.tangerine, last: i == filteredEarlier.count - 1) {
                                app.toggle(d.month, d.kind, d.key, d.text)
                            }
                        }
                    }
                }

                if region == .cn && !filteredVaccines.isEmpty {
                    Box(title: L10n.t("接种", "Vaccines"), detail: "\(vDone) / \(mo.vaccines.count)") {
                        ForEach(Array(filteredVaccines.enumerated()), id: \.element.offset) { pos, pair in
                            let i = pair.offset; let t = pair.element
                            CheckRow(text: t, on: app.ticked(m, TickKind.vaccine, "\(i)"), accent: Crayon.cherry, last: pos == filteredVaccines.count - 1) {
                                app.toggle(m, TickKind.vaccine, "\(i)", t)
                            }
                        }
                    }
                }

                if region == .cn && !filteredCheckups.isEmpty {
                    Box(title: L10n.t("儿童保健", "Well-Child Visits"), detail: "\(cDone) / \(mo.checkups.count)") {
                        ForEach(Array(filteredCheckups.enumerated()), id: \.element.offset) { pos, pair in
                            let i = pair.offset; let t = pair.element
                            CheckRow(text: t, on: app.ticked(m, TickKind.checkup, "\(i)"), accent: Crayon.teal, last: pos == filteredCheckups.count - 1) {
                                app.toggle(m, TickKind.checkup, "\(i)", t)
                            }
                        }
                    }
                }

                if region == .cn && filteredEarlier.isEmpty && filteredVaccines.isEmpty && filteredCheckups.isEmpty {
                    Text(filter == .done
                         ? L10n.t("还没有勾完的项目，轻点下方状态切换到待完成查看。", "Nothing logged yet — switch filter to see items due.")
                         : L10n.t("本月项目均已记下。", "All items for this month are checked off."))
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryText)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .printCard(radius: Radius.card)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.secondaryText)
                        Text(L10n.t("数据依据与适用说明", "Schedule Reference & Scope"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.secondaryText)
                    }
                    Text(region.scopeNote)
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                        .fill(Palette.fill.opacity(dark ? 0.45 : 0.65))
                )
            }
            .padding(.horizontal, LayoutSpec.pageH).padding(.bottom, 48)
        }
        .calmWhileScrolling()
        .pageBackground()
        .navigationTitle(L10n.t("接种与儿保", "Care & Checkups"))
        .navigationSubtitle(app.birth.map {
            let moLabel = m == 0 ? L10n.t("出生", "Newborn") : L10n.t("满 \(m) 个月", m == 1 ? "1 month" : "\(m) months")
            return moLabel + " · " + $0.plus(months: m).md
        } ?? (m == 0 ? L10n.t("出生", "Newborn") : L10n.t("满 \(m) 个月", m == 1 ? "1 month" : "\(m) months")))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    TactileEngine.shared.beadClick()
                    showingClinicSnapshot = true
                } label: {
                    Label(L10n.t("诊室快照", "Clinic Snapshot"), systemImage: "doc.text.magnifyingglass")
                }
            }
        }
        .sheet(isPresented: $showingClinicSnapshot) {
            ClinicSnapshotSheet()
                .lampPresented()
        }
    }

    @ViewBuilder
    private func dualGaugeHeader(vDone: Int, vTotal: Int, cDone: Int, cTotal: Int, earlierCount: Int, monthDone: Int, monthTotal: Int, dark: Bool) -> some View {
        let gaugeRow: AnyLayout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                GoldBead(size: 10)
                Text(L10n.t("本月 \(monthDone) / \(monthTotal)", "\(monthDone) / \(monthTotal) this month"))
                    .font(.headline)
                Spacer(minLength: 4)
                if earlierCount > 0 {
                    Text(L10n.t("待补 \(earlierCount)", "+\(earlierCount) due"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(dark ? Palette.amber : Crayon.ink(Crayon.tangerine))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Crayon.tangerine.opacity(dark ? 0.22 : 0.16)))
                }
            }

            gaugeRow {
                if vTotal > 0 {
                    gaugeDial(title: L10n.t("接种", "Vaccines"), done: vDone, total: vTotal, color: Crayon.cherry, dark: dark)
                }
                if cTotal > 0 {
                    gaugeDial(title: L10n.t("儿保", "Check-ups"), done: cDone, total: cTotal, color: Crayon.teal, dark: dark)
                }
            }

            let allTotal = monthTotal + earlierCount
            let allDone = monthDone
            let allPending = max(0, allTotal - allDone)

            WrapLayout(spacing: 8) {
                ForEach(CareFilterMode.allCases) { mode in
                    let on = (filter == mode)
                    let cnt = switch mode {
                    case .all: allTotal
                    case .pending: allPending
                    case .done: allDone
                    }
                    Button {
                        withAnimation(.snappy) { filter = mode }
                    } label: {
                        HStack(spacing: 4) {
                            Text(mode.label)
                                .font(.caption.weight(on ? .bold : .semibold))
                            Text("\(cnt)")
                                .font(Typeface.numerals(11, relativeTo: .caption2, weight: .bold))
                                .opacity(on ? 0.92 : 0.72)
                        }
                        .foregroundStyle(on ? .white : .primary)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(Capsule().fill(on ? Palette.accentFill : (dark ? Color.white.opacity(0.08) : Palette.fill)))
                    }
                    .buttonStyle(.toy)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .printCard(radius: Radius.card)
    }

    @ViewBuilder
    private func gaugeDial(title: String, done: Int, total: Int, color: Color, dark: Bool) -> some View {
        HStack(spacing: 10) {
            Ring(done: done, total: total, color: color, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.secondaryText)
                Text("\(done) / \(total)")
                    .font(Typeface.numerals(16, relativeTo: .headline, weight: .bold))
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous).fill(color.opacity(dark ? 0.14 : 0.08)))
    }
}

/// Notes for the month.
struct NotesView: View {
    @Environment(AppModel.self) private var app
    let month: Int
    var body: some View {
        let mo = app.content.month(month)
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(mo.notes.enumerated()), id: \.offset) { _, n in
                    Card(title: n.topic, symbol: "lightbulb.fill", color: Crayon.sunflower) {
                        Text(rich(n.text)).font(.body).fixedSize(horizontal: false, vertical: true)
                    }
                }
                // health guidance is a summary of public guidance, never advice for one child
                Text(HealthNote.text).font(.footnote).foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle(L10n.t("还要知道", "Good to Know"))
        .navigationSubtitle(month == 0 ? L10n.t("出生", "Newborn") : L10n.t("满 \(month) 个月", month == 1 ? "1 month" : "\(month) months"))
    }
}

// RhythmView moved to DailyRhythmStudio.swift (24-hour tactile circadian loom & 5-stage evolution)

/// A play in the month's grid: its first picture, its name, its age.
struct PlayTile: View {
    enum Form { case lead, cell, row, mini }
    let play: Play
    let times: Int
    var form: Form = .cell
    var body: some View {
        let key = Palette.areaKey(of: play)
        let pic = ArtIndex.shared.steps(play.code).first
        Group {
            switch form {
            case .mini:
                // two to a row and short: its first picture small at the left, the words beside it (a month's plays
                // in a few lines of the page, not a screen of pictures)
                HStack(alignment: .top, spacing: 8) {
                    ZStack(alignment: .topTrailing) {
                        if BespokeActivitySceneRegistry.hasBespokeScene(for: play.code) {
                            ActivityPreviewThumb(play: play, color: Palette.area(key), flat: ArtStyle.current == .flat)
                                .aspectRatio(4 / 3, contentMode: .fill)
                        } else if let pic {
                            ArtFill(name: pic).aspectRatio(1, contentMode: .fill)
                        } else {
                            Palette.fill
                        }
                    }
                    .frame(width: 58, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                    .overlay(alignment: .bottomTrailing) { if times > 0 { badge.scaleEffect(0.8).offset(x: 6, y: 6) } }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            IconTile(symbol: Palette.areaSymbol(key), color: Palette.area(key), size: 14)
                            Text(play.domains.first ?? "").font(.caption2.weight(.semibold)).foregroundStyle(Palette.areaInk(key)).lineLimit(1)
                        }
                        // the name on one line: a grid that cannot hold every name whole gives way to a list
                        // (PlaysLeadGrid), never a name cut in the middle of a word
                        Text(play.name).font(.footnote.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                        Text(play.age).font(.caption2).foregroundStyle(Palette.secondaryText)
                    }
                    Spacer(minLength: 0)
                }
                .padding(8)
                .background(Palette.area(key).opacity(0.08))
            case .row:
                // compact: the tray of materials at the left, the words at the right
                HStack(spacing: 12) {
                    if BespokeActivitySceneRegistry.hasBespokeScene(for: play.code) {
                        ActivityPreviewThumb(play: play, color: Palette.area(key), flat: ArtStyle.current == .flat)
                            .frame(width: 92, height: 69)
                    } else {
                        Figure(name: "tray_\(play.code.lowercased()).webp").frame(width: 92, height: 69)
                    }
                    words(key, title: .subheadline)
                    Spacer(minLength: 0)
                    badge
                }
                .padding(10)
                .background(Palette.area(key).opacity(0.1))
            default:
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        if let pic { ArtFill(name: pic).aspectRatio(form == .lead ? 16 / 10 : 4 / 3, contentMode: .fit) }
                        else { Palette.fill.aspectRatio(4 / 3, contentMode: .fit) }
                        badge.padding(8)
                    }
                    words(key, title: form == .lead ? .title3 : .subheadline).padding(form == .lead ? 16 : 12)
                    Spacer(minLength: 0)
                }
                .background(Palette.area(key).opacity(form == .lead ? 0.16 : 0.08))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: form == .row ? nil : .infinity, alignment: .topLeading)
        .printCard(radius: form == .lead ? 26 : 22)
        .accessibilityElement(children: .combine)
    }
    @ViewBuilder private var badge: some View {
        if times > 0 {
            Ticking(text: "×\(times)").font(Typeface.numerals(13, relativeTo: .footnote, weight: .bold)).foregroundStyle(Color(hex: 0x4A3300))
                .padding(.horizontal, 8).frame(height: 24)
                .background(Capsule().fill(Palette.bead))
                .accessibilityLabel(L10n.t("玩过 \(times) 次", times == 1 ? "Played once" : "Played \(times) times"))
        }
    }
    private func words(_ key: String, title: Font) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                IconTile(symbol: Palette.areaSymbol(key), color: Palette.area(key), size: form == .lead ? 22 : 18)
                Text(play.domains.first ?? "").font(.caption.weight(.semibold)).foregroundStyle(Palette.areaInk(key)).lineLimit(1)
            }
            Text(play.name).font(title.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading)
            Text(form == .lead ? L10n.t("\(play.age) · \(play.steps.count) 步", "\(play.age) · \(play.steps.count) steps") : play.age).font(.caption).foregroundStyle(Palette.secondaryText)
        }
    }
}

/// What to look out for this month, by area: visual 4-domain progress board & instant domain filter.
struct ObserveView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    let month: Int
    @State private var selectedGroupIndex: Int? = nil
    @State private var showingClinicSnapshot = false

    private func observeColor(for area: String) -> Color {
        let low = area.lowercased()
        if area.contains("社会") || area.contains("情绪") || low.contains("social") || low.contains("emotion") { return Crayon.pink }
        if area.contains("语言") || area.contains("沟通") || low.contains("language") || low.contains("comm") { return Crayon.teal }
        if area.contains("认知") || low.contains("cognitive") { return Crayon.sunflower }
        if area.contains("运动") || low.contains("motor") || low.contains("move") { return Crayon.tangerine }
        return Palette.accent
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        let mo = app.content.month(month)
        let obsTotal = mo.observe.reduce(0) { $0 + $1.items.count }
        let obsDone = mo.observe.enumerated().reduce(0) { acc, pair in
            acc + pair.element.items.indices.filter { app.observationState(month, "\(pair.offset)-\($0)") == .observed }.count
        }
        let shownIndices: [Int] = if let s = selectedGroupIndex, mo.observe.indices.contains(s) {
            [s]
        } else {
            Array(mo.observe.indices)
        }

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if obsTotal > 0 {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Ring(done: obsDone, total: obsTotal, color: Palette.accent, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.t("本月可留意", "Things to Notice"))
                                    .font(.headline)
                                Text(L10n.t("已留意 \(obsDone) / \(obsTotal)", "\(obsDone) / \(obsTotal) noticed"))
                                    .font(Typeface.numerals(13, relativeTo: .footnote, weight: .semibold))
                                    .foregroundStyle(Palette.secondaryText)
                            }
                            Spacer(minLength: 0)
                        }

                        WrapLayout(spacing: 7) {
                            let allOn = (selectedGroupIndex == nil)
                            Button {
                                withAnimation(.snappy) { selectedGroupIndex = nil }
                            } label: {
                                Text(L10n.t("全部 \(obsDone)/\(obsTotal)", "All \(obsDone)/\(obsTotal)"))
                                    .font(.caption.weight(allOn ? .bold : .semibold))
                                    .foregroundStyle(allOn ? .white : .primary)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Capsule().fill(allOn ? Palette.accentFill : (dark ? Color.white.opacity(0.08) : Palette.fill)))
                            }
                            .buttonStyle(.toy)
                            .accessibilityAddTraits(allOn ? .isSelected : [])

                            ForEach(Array(mo.observe.enumerated()), id: \.offset) { gi, g in
                                let col = observeColor(for: g.area)
                                let gDone = g.items.indices.filter { app.observationState(month, "\(gi)-\($0)") == .observed }.count
                                let on = (selectedGroupIndex == gi)
                                Button {
                                    withAnimation(.snappy) { selectedGroupIndex = (on ? nil : gi) }
                                } label: {
                                    HStack(spacing: 5) {
                                        Circle()
                                            .fill(on ? Color.white : col)
                                            .frame(width: 7, height: 7)
                                        Text(g.area)
                                            .font(.caption.weight(on ? .bold : .semibold))
                                        Text("\(gDone)/\(g.items.count)")
                                            .font(Typeface.numerals(11, relativeTo: .caption2, weight: .bold))
                                            .opacity(on ? 0.9 : 0.72)
                                    }
                                    .foregroundStyle(on ? .white : .primary)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Capsule().fill(on ? col : col.opacity(dark ? 0.16 : 0.12)))
                                }
                                .buttonStyle(.toy)
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .printCard(radius: Radius.card)
                }

                WHOMotorSpectrumCard(
                    currentMonth: app.age.map { Double($0.months) + Double($0.days) / 30.4375 },
                    dark: dark
                )

                // each area a list of ticks, as 接种与儿保: three-state gentle observation rows
                ForEach(shownIndices, id: \.self) { gi in
                    let g = mo.observe[gi]
                    let color = observeColor(for: g.area)
                    let groupDone = g.items.indices.filter { app.observationState(month, "\(gi)-\($0)") == .observed }.count
                    Box(title: g.area, detail: "\(groupDone) / \(g.items.count)") {
                        ForEach(Array(g.items.enumerated()), id: \.offset) { ii, t in
                            let st = app.observationState(month, "\(gi)-\(ii)")
                            ObservationStateRow(
                                text: t,
                                state: st,
                                accent: color,
                                dark: dark,
                                last: ii == g.items.count - 1
                            ) { nextState in
                                app.setObservationState(month, "\(gi)-\(ii)", t, to: nextState)
                            }
                            .sensoryFeedback(.selection, trigger: st)
                        }
                    }
                }

                CalmDisclosureNote(
                    title: L10n.t("关于发育节奏说明", "About developmental pace"),
                    symbol: "info.circle"
                ) {
                    Text(L10n.t(
                        "这些是多数孩子在这个月前后会出现的表现。还没看到的，下次儿保时可以和医生聊一聊；每个孩子有自己的节奏。",
                        "These are signs many children show around this age. If you haven't noticed one yet, mention it at your next well-child visit — every child moves at their own pace."
                    ))
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 40)
        }
        .calmWhileScrolling()
        .pageBackground()
        .navigationTitle(L10n.t("可以留意", "What to Notice"))
        .navigationSubtitle(month == 0 ? L10n.t("出生", "Newborn") : L10n.t("满 \(month) 个月", month == 1 ? "1 month" : "\(month) months"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    TactileEngine.shared.beadClick()
                    showingClinicSnapshot = true
                } label: {
                    Label(L10n.t("诊室快照", "Clinic Snapshot"), systemImage: "doc.text.magnifyingglass")
                }
            }
        }
        .sheet(isPresented: $showingClinicSnapshot) {
            ClinicSnapshotSheet()
                .lampPresented()
        }
    }
}
