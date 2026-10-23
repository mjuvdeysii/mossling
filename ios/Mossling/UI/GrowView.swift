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
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 14)
                MonthBody(month: m).padding(.horizontal, 16).padding(.top, 8)
            }
            .padding(.bottom, 40)
        }
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
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(plays) { p in PlayTileLink(play: p, month: m) }
                    }
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

/// The parts of a month as tiles: a picture, a word, and how much is recorded; each opens its own page.
struct MonthParts: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var type
    let month: Int
    var body: some View {
        let mo = app.content.month(month), m = month
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "这个月")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: type.isAccessibilitySize ? 2 : 3), spacing: 10) {
                    NavigationLink(value: Route.areas(m)) {
                        MonthTile(symbol: "circle.hexagongrid.fill", color: Crayon.lilac, title: "六个方面", note: mo.domains.first { $0.key == mo.focus }.map { "重点 \($0.name.prefix(4))" }) { EmptyView() }
                    }.buttonStyle(.toy)
                    if !mo.observe.isEmpty {
                        let total = mo.observe.reduce(0) { $0 + $1.items.count }
                        NavigationLink(value: Route.observe(m)) {
                            MonthTile(symbol: "eye.fill", color: Crayon.sky, title: "可以留意", note: "\(app.count(m, TickKind.observed)) / \(total)") { Ring(done: app.count(m, TickKind.observed), total: total, color: Crayon.sky) }
                        }.buttonStyle(.toy)
                    }
                    if !mo.vaccines.isEmpty || !mo.checkups.isEmpty {
                        let total = mo.vaccines.count + mo.checkups.count
                        let done = app.count(m, TickKind.vaccine) + app.count(m, TickKind.checkup)
                        NavigationLink(value: Route.care(m)) {
                            MonthTile(symbol: "syringe.fill", color: Crayon.pink, title: "接种与儿保", note: "\(done) / \(total)") { Ring(done: done, total: total, color: Crayon.pink) }
                        }.buttonStyle(.toy)
                    }
                    if !mo.notes.isEmpty {
                        NavigationLink(value: Route.notes(m)) {
                            MonthTile(symbol: "lightbulb.fill", color: Crayon.sunflower, title: "还要知道", note: "\(mo.notes.count) 条") { EmptyView() }
                        }.buttonStyle(.toy)
                    }
                    if !mo.who.isEmpty {
                        NavigationLink(value: Route.rhythm(m)) {
                            MonthTile(symbol: "sun.and.horizon.fill", color: Crayon.peach, title: "一天的节奏", note: "睡眠 活动") { EmptyView() }
                        }.buttonStyle(.toy)
                    }
                    NavigationLink(value: JournalRoute.growth) {
                        MonthTile(symbol: "chart.line.uptrend.xyaxis", color: Crayon.leaf, title: "生长曲线", note: "WHO") { EmptyView() }
                    }.buttonStyle(.toy)
                }
            }
    }
}

/// One part of the month as a tile: its icon large, its name, a short note, and a ring when there is something to tick.
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
                Text(note ?? " ").font(.caption2).foregroundStyle(.secondary).lineLimit(2).monospacedDigit()
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
    var body: some View {
        let route = Route.play(play.code, month)
        NavigationLink(value: route) { PlayTile(play: play, times: app.record(play, j).count) }
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
                Text("具体时间以当地接种门诊与儿童保健机构的安排为准。").font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16)
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
                Text("依据世界卫生组织《5 岁以下儿童身体活动、久坐行为和睡眠指南》（2019）。").font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16)
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
    let play: Play
    let times: Int
    var body: some View {
        let key = Palette.areaKey(of: play)
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                if let f = ArtIndex.shared.steps(play.code).first { ArtFill(name: f).aspectRatio(4 / 3, contentMode: .fit) }
                else { Palette.fill.aspectRatio(4 / 3, contentMode: .fit) }
                if times > 0 {
                    Text("×\(times)").font(Typeface.numerals(13, relativeTo: .footnote, weight: .bold)).foregroundStyle(Color(hex: 0x4A3300))
                        .padding(.horizontal, 8).frame(height: 24)
                        .background(Capsule().fill(LinearGradient(colors: [Palette.beadLight, Palette.bead], startPoint: .top, endPoint: .bottom)))
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        .padding(8)
                        .accessibilityLabel("做过 \(times) 次")
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    IconTile(symbol: Palette.areaSymbol(key), color: Palette.area(key), size: 18)
                    Text(play.domains.first ?? "").font(.caption.weight(.semibold)).foregroundStyle(Palette.areaInk(key)).lineLimit(1)
                }
                Text(play.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading)
                Text(play.age).font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.area(key).opacity(0.1))
        .printCard(radius: 22)
        .accessibilityElement(children: .combine)
    }
}

/// What to look out for this month, by area: tick what has been seen.
struct ObserveView: View {
    @Environment(AppModel.self) private var app
    let month: Int
    var body: some View {
        let mo = app.content.month(month)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(mo.observe.enumerated()), id: \.offset) { gi, g in
                    Box(title: g.area) {
                        ForEach(Array(g.items.enumerated()), id: \.offset) { ii, t in
                            CheckRow(text: t, on: app.ticked(month, TickKind.observed, "\(gi)-\(ii)"), last: ii == g.items.count - 1) {
                                app.toggle(month, TickKind.observed, "\(gi)-\(ii)", t)
                            }
                        }
                    }
                }
                Text("每个孩子有自己的节奏。没看到的项目不代表落后；如有疑虑，请咨询儿童保健医生。").font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16)
            }
            .padding(.horizontal, 16).padding(.bottom, 40)
        }
        .pageBackground()
        .navigationTitle("可以留意")
        .navigationSubtitle(month == 0 ? "出生" : "满 \(month) 个月")
    }
}
