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
    @State private var month: Int
    init(month: Int) { _month = State(initialValue: month) }

    var body: some View {
        let mo = app.content.month(month), m = month
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // the month's picture beside its title (stacks cleanly on Accessibility text sizes)
                Group {
                    if type.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: 10) {
                            if let f = ArtIndex.shared.cover(m) {
                                ArtView(name: f, label: L10n.t("满 \(m) 个月：\(mo.title)", "Month \(m): \(mo.title)"), radius: 18).frame(width: 148)
                            }
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
                            if let f = ArtIndex.shared.cover(m) {
                                ArtView(name: f, label: L10n.t("满 \(m) 个月：\(mo.title)", "Month \(m): \(mo.title)"), radius: 18).frame(width: 148)
                            }
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
        .toolbar(.hidden, for: .tabBar)
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
                    BoxRow(symbol: sym, color: col, title: h.kind, text: shut ? String(h.text.prefix(34)) + (h.text.count > 34 ? "…" : "") : h.text, last: i == points.count - 1)
                }
            }
            if folded {
                Button { withAnimation(.snappy) { open.toggle() } } label: { box }
                    .buttonStyle(.plain)
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
        let c = app.content, mo = c.month(month), m = month
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

/// The parts of a month, in two tiers (ios/DESIGN.md §3 · 版面): what is ticked off over the month — what to watch
/// for, vaccines and check-ups — as two large tiles with their progress; what is read when needed — the six areas,
/// notes, the day's rhythm, growth — as a compact row.
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
                        if let r = p.route {
                            NavigationLink(value: r) { card }.buttonStyle(.toy)
                        } else {
                            NavigationLink(value: JournalRoute.growth) { card }.buttonStyle(.toy)
                        }
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
                        if let r = p.route {
                            NavigationLink(value: r) { card }.buttonStyle(.toy)
                        } else {
                            NavigationLink(value: JournalRoute.growth) { card }.buttonStyle(.toy)
                        }
                    }
                }
            }
        }
    }
    /// A part of the month; `route` nil means the growth chart (a journal route).
    private struct Part { let symbol: String; let color: Color; let title: String; let note: String; var done = 0; var total = 0; let route: Route? }
    private func parts(_ mo: Month, _ m: Int) -> [Part] {
        var out: [Part] = []
        if !mo.observe.isEmpty {
            let total = mo.observe.reduce(0) { $0 + $1.items.count }, done = app.count(m, TickKind.observed)
            out.append(Part(symbol: "eye.fill", color: Crayon.sky, title: L10n.t("可以留意", "Things to Notice"), note: "\(done) / \(total)", done: done, total: total, route: Route.observe(m)))
        }
        if !mo.vaccines.isEmpty || !mo.checkups.isEmpty {
            let total = mo.vaccines.count + mo.checkups.count, done = app.count(m, TickKind.vaccine) + app.count(m, TickKind.checkup)
            out.append(Part(symbol: "syringe.fill", color: Crayon.pink, title: L10n.t("接种与儿保", "Vaccines & Check-ups"), note: "\(done) / \(total)", done: done, total: total, route: Route.care(m)))
        }
        out.append(Part(symbol: "circle.hexagongrid.fill", color: Crayon.teal, title: L10n.t("六个方面", "Six Areas"), note: L10n.t("这个月的样子", "This month's overview"), route: Route.areas(m)))
        if !mo.notes.isEmpty { out.append(Part(symbol: "lightbulb.fill", color: Crayon.sunflower, title: L10n.t("还要知道", "Good to Know"), note: L10n.t("\(mo.notes.count) 条", "\(mo.notes.count) notes"), route: Route.notes(m))) }
        if !mo.who.isEmpty { out.append(Part(symbol: "sun.and.horizon.fill", color: Crayon.tangerine, title: L10n.t("一天的节奏", "Daily Rhythm"), note: L10n.t("睡、玩、吃", "Sleep, play & feeds"), route: Route.rhythm(m))) }
        out.append(Part(symbol: "chart.line.uptrend.xyaxis", color: Crayon.leaf, title: L10n.t("生长曲线", "Growth Curves"), note: L10n.t("WHO 标准", "WHO Standards"), route: nil))
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

/// A play tile that opens its page with a zoom, and offers the common actions on a long press.
struct PlayTileLink: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.aloneInRow) private var alone
    let play: Play, month: Int
    var form: PlayTile.Form = .cell
    var body: some View {
        let route = Route.play(play.code, month)
        // alone across a row: the wide form (picture beside the words), not a tile pulled out of shape
        let f: PlayTile.Form = alone && (form == .cell || form == .mini) ? .row : form
        NavigationLink(value: route) { PlayTile(play: play, times: app.record(play, j).count, form: f) }
            .buttonStyle(.toy)
            .zoomSource(route)
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
        ShareLink(item: L10n.t("\(play.name)（\(play.code)）\n", "\(play.name) (\(play.code))\n") + play.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")) { Label(L10n.t("分享", "Share"), systemImage: "square.and.arrow.up") }
    }
}

/// The six areas of the month.
struct AreasView: View {
    @Environment(AppModel.self) private var app
    let month: Int
    var body: some View {
        let mo = app.content.month(month)
        ScrollView {
            VStack(spacing: 12) {
                // the month's focus first, then the rest in their usual order
                let ordered = mo.domains.filter { $0.key == mo.focus } + mo.domains.filter { $0.key != mo.focus }
                ForEach(Array(ordered.enumerated()), id: \.offset) { _, d in
                    let isFocus = d.key == mo.focus
                    let color = Palette.area(d.key)
                    Card(title: d.name, symbol: Palette.areaSymbol(d.key), color: color, detail: isFocus ? L10n.t("本月重点", "Focus") : nil) {
                        Text(rich(d.text)).font(.body).fixedSize(horizontal: false, vertical: true)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .strokeBorder(isFocus ? color.opacity(0.45) : .clear, lineWidth: 1.5)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .fill(isFocus ? color.opacity(0.06) : .clear)
                    )
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle(L10n.t("六个方面", "Six Areas"))
        .navigationSubtitle(month == 0 ? L10n.t("出生", "Newborn") : L10n.t("满 \(month) 个月", month == 1 ? "1 month" : "\(month) months"))
        .toolbar(.hidden, for: .tabBar)
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

private struct BeadJourneyRibbon: View {
    let title: String
    let subtitle: String
    let beads: [(filled: Bool, color: Color)]
    var pill: (text: String, color: Color)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                GoldBead(size: 10)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                if let pill {
                    Text(pill.text)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Crayon.ink(pill.color))
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(pill.color.opacity(0.14)))
                }
            }

            if !beads.isEmpty {
                WrapLayout(spacing: 6) {
                    ForEach(Array(beads.prefix(24).enumerated()), id: \.offset) { _, b in
                        Circle()
                            .fill(
                                b.filled
                                    ? AnyShapeStyle(RadialGradient(colors: [b.color.mix(with: .white, by: 0.35), b.color], center: UnitPoint(x: 0.32, y: 0.28), startRadius: 0, endRadius: 7))
                                    : AnyShapeStyle(Palette.secondaryText.opacity(0.18))
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(b.filled ? b.color.opacity(0.25) : b.color.opacity(0.35), lineWidth: 0.75)
                            )
                            .shadow(color: b.filled ? b.color.opacity(0.28) : .clear, radius: 2, y: 1)
                            .frame(width: 10, height: 10)
                    }
                }
                .accessibilityHidden(true)
            }

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .printCard(radius: Radius.card)
    }
}

struct CareView: View {
    @Environment(AppModel.self) private var app
    let month: Int
    var body: some View {
        let mo = app.content.month(month), m = month
        let earlier = app.duePending(before: m)
        let vDone = mo.vaccines.indices.filter { app.ticked(m, TickKind.vaccine, "\($0)") }.count
        let cDone = mo.checkups.indices.filter { app.ticked(m, TickKind.checkup, "\($0)") }.count
        let monthDone = vDone + cDone
        let monthTotal = mo.vaccines.count + mo.checkups.count
        let careBeads: [(filled: Bool, color: Color)] =
            mo.vaccines.indices.map { (app.ticked(m, TickKind.vaccine, "\($0)"), Crayon.cherry) }
            + mo.checkups.indices.map { (app.ticked(m, TickKind.checkup, "\($0)"), Crayon.teal) }

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if monthTotal > 0 || !earlier.isEmpty {
                    BeadJourneyRibbon(
                        title: L10n.t("本月已记 \(monthDone) / \(monthTotal)", "\(monthDone) / \(monthTotal) logged this month"),
                        subtitle: L10n.t("轻点记下已完成的接种与儿保，只为方便回看。", "Tap to keep a calm record of vaccines and well-child visits."),
                        beads: careBeads,
                        pill: earlier.isEmpty ? nil : (L10n.t("之前未勾 \(earlier.count) 项", "\(earlier.count) earlier"), Crayon.tangerine)
                    )
                }
                // first: what the two months before left unticked (overdue is the most pressing); ticked here,
                // it is kept under its own month
                if !earlier.isEmpty {
                    Box(title: L10n.t("之前没勾的", "Earlier unchecked"), detail: L10n.t("\(earlier.count) 项", "\(earlier.count)")) {
                        ForEach(Array(earlier.enumerated()), id: \.offset) { i, d in
                            let moText = d.month == 0 ? L10n.t("出生", "Newborn") : L10n.t("满 \(d.month) 个月", d.month == 1 ? "1 month" : "\(d.month) months")
                            CheckRow(text: d.text + " · " + moText, on: app.ticked(d.month, d.kind, d.key), accent: Crayon.tangerine, last: i == earlier.count - 1) { app.toggle(d.month, d.kind, d.key, d.text) }
                        }
                    }
                }
                if !mo.vaccines.isEmpty {
                    Box(title: L10n.t("接种", "Vaccines"), detail: "\(vDone) / \(mo.vaccines.count)") {
                        ForEach(Array(mo.vaccines.enumerated()), id: \.offset) { i, t in
                            CheckRow(text: t, on: app.ticked(m, TickKind.vaccine, "\(i)"), accent: Crayon.cherry, last: i == mo.vaccines.count - 1) { app.toggle(m, TickKind.vaccine, "\(i)", t) }
                        }
                    }
                }
                if !mo.checkups.isEmpty {
                    Box(title: L10n.t("儿童保健", "Well-Child Visits"), detail: "\(cDone) / \(mo.checkups.count)") {
                        ForEach(Array(mo.checkups.enumerated()), id: \.offset) { i, t in
                            CheckRow(text: t, on: app.ticked(m, TickKind.checkup, "\(i)"), accent: Crayon.teal, last: i == mo.checkups.count - 1) { app.toggle(m, TickKind.checkup, "\(i)", t) }
                        }
                    }
                }
                // whose schedule this is: China's; elsewhere, the local health authority's (1.4.1 — say where data applies)
                Text(L10n.t(
                    "按《国家免疫规划疫苗儿童免疫程序及说明（2026年版）》（国疾控卫免发〔2026〕16号）与国家基本公共卫生服务规范整理。其他国家和地区以当地卫生部门的程序为准；具体时间以当地接种门诊与儿童保健机构的安排为准。",
                    "Based on China's National Immunization Program (2026) and public child-health guidelines. Outside mainland China, follow your local health authority and pediatrician's schedule."
                ))
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                        .fill(Palette.fill.opacity(0.65))
                )
            }
            .padding(.horizontal, 16).padding(.bottom, 48)
        }
        .pageBackground()
        .navigationTitle(L10n.t("接种与儿保", "Care & Checkups"))
        .navigationSubtitle(app.birth.map {
            let moLabel = m == 0 ? L10n.t("出生", "Newborn") : L10n.t("满 \(m) 个月", m == 1 ? "1 month" : "\(m) months")
            return moLabel + " · " + $0.plus(months: m).md
        } ?? (m == 0 ? L10n.t("出生", "Newborn") : L10n.t("满 \(m) 个月", m == 1 ? "1 month" : "\(m) months")))
        .toolbar(.hidden, for: .tabBar)
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
        .toolbar(.hidden, for: .tabBar)
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
                        if let pic { ArtFill(name: pic).aspectRatio(1, contentMode: .fill) } else { Palette.fill }
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
                    Figure(name: "tray_\(play.code.lowercased()).webp").frame(width: 92, height: 69)
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

/// What to look out for this month, by area: tick what has been seen.
struct ObserveView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var type
    let month: Int

    private func observeColor(for area: String) -> Color {
        let low = area.lowercased()
        if area.contains("社会") || area.contains("情绪") || low.contains("social") || low.contains("emotion") { return Crayon.pink }
        if area.contains("语言") || area.contains("沟通") || low.contains("language") || low.contains("comm") { return Crayon.teal }
        if area.contains("认知") || low.contains("cognitive") { return Crayon.sunflower }
        if area.contains("运动") || low.contains("motor") || low.contains("move") { return Crayon.tangerine }
        return Palette.accent
    }

    var body: some View {
        let mo = app.content.month(month)
        let obsBeads: [(filled: Bool, color: Color)] = mo.observe.enumerated().flatMap { gi, g in
            let col = observeColor(for: g.area)
            return g.items.indices.map { ii in (app.ticked(month, TickKind.observed, "\(gi)-\(ii)"), col) }
        }
        let obsTotal = obsBeads.count
        let obsDone = obsBeads.filter(\.filled).count

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if obsTotal > 0 {
                    BeadJourneyRibbon(
                        title: L10n.t("已留意 \(obsDone) / \(obsTotal)", "\(obsDone) / \(obsTotal) noticed"),
                        subtitle: L10n.t("记下已经看到的小瞬间，每个孩子都有自己的节奏。", "Mark moments you've spotted — every child moves at their own pace."),
                        beads: obsBeads
                    )
                }
                // each area a list of ticks, as 接种与儿保: one line each, no tile stretched round a short line
                ForEach(Array(mo.observe.enumerated()), id: \.offset) { gi, g in
                    let color = observeColor(for: g.area)
                    let groupDone = g.items.indices.filter { app.ticked(month, TickKind.observed, "\(gi)-\($0)") }.count
                    Box(title: g.area, detail: "\(groupDone) / \(g.items.count)") {
                        ForEach(Array(g.items.enumerated()), id: \.offset) { ii, t in
                            let on = app.ticked(month, TickKind.observed, "\(gi)-\(ii)")
                            CheckRow(text: t, on: on, accent: color, last: ii == g.items.count - 1) { app.toggle(month, TickKind.observed, "\(gi)-\(ii)", t) }
                                .sensoryFeedback(.selection, trigger: on)
                        }
                    }
                }
                Text(L10n.t(
                    "这些是多数孩子在这个月前后会出现的表现。还没看到的，下次儿保时可以和医生聊一聊；每个孩子有自己的节奏。",
                    "These are signs many children show around this age. If you haven't noticed one yet, mention it at your next well-child visit — every child moves at their own pace."
                ))
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                        .fill(Palette.fill.opacity(0.65))
                )
            }
            .padding(.horizontal, 16).padding(.bottom, 40)
        }
        .pageBackground()
        .navigationTitle(L10n.t("可以留意", "What to Notice"))
        .navigationSubtitle(month == 0 ? L10n.t("出生", "Newborn") : L10n.t("满 \(month) 个月", month == 1 ? "1 month" : "\(month) months"))
        .toolbar(.hidden, for: .tabBar)
    }
}
