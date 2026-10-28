import SwiftUI

/// The three lands of the map, a year each, with their colours.
enum Land: Int, CaseIterable {
    case meadow, forest, river
    static func of(_ m: Int) -> Land { m < 12 ? .meadow : m < 24 ? .forest : .river }
    var name: String { switch self { case .meadow: "草地"; case .forest: "森林小丘"; case .river: "小河村庄" } }
    var years: String { switch self { case .meadow: "0–1 岁"; case .forest: "1–2 岁"; case .river: "2–3 岁" } }
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
struct MonthView: View {
    @Environment(AppModel.self) private var app
    let month: Int

    var body: some View {
        let mo = app.content.month(month), m = month
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let f = ArtIndex.shared.cover(m) {
                    ArtView(name: f, label: "满 \(m) 个月：\(mo.title)", radius: 26).padding(.horizontal, 16).padding(.top, 4)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(mo.title).font(.title2.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                    if let b = app.birth {
                        Label(b.plus(months: m).md + (app.babyMonth == m ? " · 宝宝在这一站" : ""), systemImage: "calendar")
                            .font(.subheadline).foregroundStyle(Palette.secondaryText)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 14)
                MonthBody(month: m).padding(.horizontal, 16).padding(.top, 8)
            }
            .padding(.bottom, 40)
        }
        .calmWhileScrolling()
        .pageBackground()
        .navigationTitle(m == 0 ? "出生" : "满 \(m) 个月")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct MonthBody: View {
    @Environment(AppModel.self) private var app
    let month: Int
    var body: some View {
        let c = app.content, mo = c.month(month), m = month
        VStack(alignment: .leading, spacing: 18) {
            // the month at a glance; a point that only names a play is already among the plays below
            let points = mo.highlights.filter { c.play($0.anchor ?? "") == nil }
            if !points.isEmpty {
                Box {
                    ForEach(Array(points.enumerated()), id: \.offset) { i, h in
                        let (sym, col): (String, Color) = h.kind.contains("留意") ? ("exclamationmark.triangle.fill", Crayon.tangerine) : h.kind.contains("先做") ? ("checklist", Crayon.sky) : ("eye.fill", Palette.accent)
                        BoxRow(symbol: sym, color: col, title: h.kind, text: h.text, last: i == points.count - 1)
                    }
                }
            }

            let plays = c.plays(of: m)
            if !plays.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(title: "一起玩", detail: "做过 \(app.count(m, TickKind.did)) / \(plays.count)")
                    PlaysLeadGrid(plays: plays, month: m)
                }
            }

            MonthParts(month: m)

            Box(title: "专题") {
                ForEach(Array(c.topics.enumerated()), id: \.offset) { i, t in
                    NavigationLink(value: Route.topic(t.id)) { BoxRow(symbol: topicMarks[i % topicMarks.count].0, color: topicMarks[i % topicMarks.count].1, title: t.title, last: i == c.topics.count - 1, opens: true) }.buttonStyle(.toy)
                }
            }

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
        let parts = parts(mo, m)
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "这个月")
            // one kind of tile, two to a row (one at the largest text sizes): the same shape for every part
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: type.isAccessibilitySize ? 1 : 2), spacing: 10) {
                ForEach(parts, id: \.title) { p in
                    let label = HStack(spacing: 10) {
                        IconTile(symbol: p.symbol, color: p.color, size: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                            Text(p.note).font(.caption).foregroundStyle(p.total > 0 ? Crayon.ink(p.color) : Palette.secondaryText).monospacedDigit()
                        }
                        Spacer(minLength: 0)
                        if p.total > 0 { Ring(done: p.done, total: p.total, color: p.color, size: 24) }
                    }
                    .padding(12).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .printCard(radius: 20)
                    .accessibilityElement(children: .combine)
                    if let r = p.route { NavigationLink(value: r) { label }.buttonStyle(.toy) }
                    else { NavigationLink(value: JournalRoute.growth) { label }.buttonStyle(.toy) }
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
            out.append(Part(symbol: "eye.fill", color: Crayon.sky, title: "可以留意", note: "\(done) / \(total)", done: done, total: total, route: Route.observe(m)))
        }
        if !mo.vaccines.isEmpty || !mo.checkups.isEmpty {
            let total = mo.vaccines.count + mo.checkups.count, done = app.count(m, TickKind.vaccine) + app.count(m, TickKind.checkup)
            out.append(Part(symbol: "syringe.fill", color: Crayon.pink, title: "接种与儿保", note: "\(done) / \(total)", done: done, total: total, route: Route.care(m)))
        }
        out.append(Part(symbol: "circle.hexagongrid.fill", color: Crayon.teal, title: "六个方面", note: "这个月的样子", route: Route.areas(m)))
        if !mo.notes.isEmpty { out.append(Part(symbol: "lightbulb.fill", color: Crayon.sunflower, title: "还要知道", note: "\(mo.notes.count) 条", route: Route.notes(m))) }
        if !mo.who.isEmpty { out.append(Part(symbol: "sun.and.horizon.fill", color: Crayon.tangerine, title: "一天的节奏", note: "睡、玩、吃", route: Route.rhythm(m))) }
        out.append(Part(symbol: "chart.line.uptrend.xyaxis", color: Crayon.leaf, title: "生长曲线", note: "WHO 标准", route: nil))
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
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.headline).foregroundStyle(.primary)
                Text("\(done) / \(total)").font(Typeface.numerals(13, relativeTo: .footnote)).foregroundStyle(Crayon.ink(color))
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12)).printCard(radius: 22)
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
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).lineLimit(2).minimumScaleFactor(0.8)
                Text(note ?? " ").font(.caption2).foregroundStyle(Palette.secondaryText).lineLimit(2).monospacedDigit()
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .printCard(radius: 20)
        .accessibilityElement(children: .combine)
    }
}

/// A play tile that opens its page with a zoom, and offers the common actions on a long press.
struct PlayTileLink: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    let play: Play, month: Int
    var form: PlayTile.Form = .cell
    var body: some View {
        let route = Route.play(play.code, month)
        NavigationLink(value: route) { PlayTile(play: play, times: app.record(play, j).count, form: form) }
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
    var body: some View {
        let rec = app.record(play, j)
        let shelf = app.weekShelf(app.babyMonth ?? month).plays.map(\.code)
        Button(rec.count == 0 ? "做过了" : "又做了一次", systemImage: "checkmark.circle") { app.didPlay(play, month: month, j) }
        if rec.count > 0 { Button("撤销最近一次", systemImage: "arrow.uturn.backward") { app.undoPlay(play, month: month, j) } }
        if shelf.contains(play.code) {
            Button("从架子上拿下", systemImage: "minus.circle") { app.setShelf(shelf.filter { $0 != play.code }) }
        } else if shelf.count < Shelf.max {
            Button("放上本周的架子", systemImage: "plus.circle") { app.setShelf(shelf + [play.code]) }
        }
        ShareLink(item: "\(play.name)（\(play.code)）\n" + play.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")) { Label("分享", systemImage: "square.and.arrow.up") }
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
                ForEach(Array(mo.domains.enumerated()), id: \.offset) { _, d in
                    Card(title: d.name, symbol: Palette.areaSymbol(d.key), color: Palette.area(d.key), detail: d.key == mo.focus ? "本月重点" : nil) {
                        Text(rich(d.text)).font(.body).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle("六个方面")
        .navigationSubtitle(month == 0 ? "出生" : "满 \(month) 个月")
    }
}

/// The month's vaccinations and check-ups, to tick off.
struct CareView: View {
    @Environment(AppModel.self) private var app
    let month: Int
    var body: some View {
        let mo = app.content.month(month), m = month
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !mo.vaccines.isEmpty {
                    Box(title: "接种") {
                        ForEach(Array(mo.vaccines.enumerated()), id: \.offset) { i, t in
                            CheckRow(text: t, on: app.ticked(m, TickKind.vaccine, "\(i)"), last: i == mo.vaccines.count - 1) { app.toggle(m, TickKind.vaccine, "\(i)", t) }
                        }
                    }
                }
                if !mo.checkups.isEmpty {
                    Box(title: "儿童保健") {
                        ForEach(Array(mo.checkups.enumerated()), id: \.offset) { i, t in
                            CheckRow(text: t, on: app.ticked(m, TickKind.checkup, "\(i)"), last: i == mo.checkups.count - 1) { app.toggle(m, TickKind.checkup, "\(i)", t) }
                        }
                    }
                }
                Text("具体时间以当地接种门诊与儿童保健机构的安排为准。").font(.footnote).foregroundStyle(Palette.secondaryText).padding(.horizontal, 16)
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle("接种与儿保")
        .navigationSubtitle(app.birth.map { "满 \(m) 个月 · \($0.plus(months: m).md)" } ?? "满 \(m) 个月")
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
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle("还要知道")
        .navigationSubtitle(month == 0 ? "出生" : "满 \(month) 个月")
    }
}

/// The day's rhythm: sleep, activity and screens, as the WHO guideline puts it for this age.
struct RhythmView: View {
    @Environment(AppModel.self) private var app
    let month: Int
    var body: some View {
        let mo = app.content.month(month)
        let parts = mo.who.replacingOccurrences(of: "WHO", with: "").split(whereSeparator: { $0 == "；" || $0 == ";" })
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "。")) }.filter { !$0.isEmpty }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, t in
                    let (sym, col, name): (String, Color, String) = t.contains("睡") ? ("moon.zzz.fill", Crayon.lilac, "睡眠") : t.contains("屏幕") ? ("iphone", Crayon.pebble, "屏幕")
                        : (t.contains("活动") || t.contains("趴") || t.contains("坐") || t.contains("久")) ? ("figure.walk", Crayon.tangerine, "活动") : ("clock.fill", Crayon.aqua, "节奏")
                    Card(title: name, symbol: sym, color: col) { Text(t).font(.body).fixedSize(horizontal: false, vertical: true) }
                }
                Text("依据世界卫生组织《5 岁以下儿童身体活动、久坐行为和睡眠指南》（2019）。").font(.footnote).foregroundStyle(Palette.secondaryText).padding(.horizontal, 16)
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle("一天的节奏")
        .navigationSubtitle(month == 0 ? "出生" : "满 \(month) 个月")
    }
}

/// A play in the month's grid: its first picture, its name, its age.
struct PlayTile: View {
    enum Form { case lead, cell, row }
    let play: Play
    let times: Int
    var form: Form = .cell
    var body: some View {
        let key = Palette.areaKey(of: play)
        let pic = ArtIndex.shared.steps(play.code).first
        Group {
            switch form {
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
                .accessibilityLabel("做过 \(times) 次")
        }
    }
    private func words(_ key: String, title: Font) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                IconTile(symbol: Palette.areaSymbol(key), color: Palette.area(key), size: form == .lead ? 22 : 18)
                Text(play.domains.first ?? "").font(.caption.weight(.semibold)).foregroundStyle(Palette.areaInk(key)).lineLimit(1)
            }
            Text(play.name).font(title.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading)
            Text(form == .lead ? "\(play.age) · \(play.steps.count) 步" : play.age).font(.caption).foregroundStyle(Palette.secondaryText)
        }
    }
}

/// What to look out for this month, by area: tick what has been seen.
struct ObserveView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var type
    let month: Int
    var body: some View {
        let mo = app.content.month(month)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(mo.observe.enumerated()), id: \.offset) { gi, g in
                    // each area's things as small tick tiles, two to a row: the month's whole list in one screen
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(title: g.area)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: type.isAccessibilitySize ? 1 : 2), spacing: 8) {
                            ForEach(Array(g.items.enumerated()), id: \.offset) { ii, t in
                                let on = app.ticked(month, TickKind.observed, "\(gi)-\(ii)")
                                Button { app.toggle(month, TickKind.observed, "\(gi)-\(ii)", t) } label: {
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.body)
                                            .foregroundStyle(on ? Palette.accent : Color(uiColor: .tertiaryLabel))
                                            .contentTransition(.symbolEffect(.replace))
                                        Text(t).font(.subheadline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Spacer(minLength: 0)
                                    }
                                    .padding(10).frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
                                    .printCard(radius: 16)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.toy)
                                .sensoryFeedback(.selection, trigger: on)
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }
                }
                Text("每个孩子有自己的节奏。没看到的项目不代表落后；如有疑虑，请咨询儿童保健医生。").font(.footnote).foregroundStyle(Palette.secondaryText).padding(.horizontal, 16)
            }
            .padding(.horizontal, 16).padding(.bottom, 40)
        }
        .pageBackground()
        .navigationTitle("可以留意")
        .navigationSubtitle(month == 0 ? "出生" : "满 \(month) 个月")
    }
}
