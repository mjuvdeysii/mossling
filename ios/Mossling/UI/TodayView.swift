import SwiftUI
import TipKit

/// The home, in the order of how often it is needed (ios/DESIGN.md §5): the month as one compact card that opens into
/// the growth wheel in place; this week's shelf, the everyday reason to open the app; the month's other plays; the
/// month's parts and the topics as small tiles. Turning the wheel changes the month and everything below follows.
struct TodayView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Binding var path: NavigationPath
    @State private var askBirth = false
    @State private var arranging = false
    @State private var chosen: Int?
    @State private var wheel = false
    private let shelfTip = ShelfTip()
    private let recordsTip = RecordsTip()

    var body: some View {
        let baby = app.babyMonth ?? 0
        let m = chosen ?? baby
        ScrollView {
            // the order of the page: who the child is now (the month), what is happening now (records, when on), what to
            // play this week (the shelf, the heart), the month's other plays, the month's parts, the topics, the story
            VStack(alignment: .leading, spacing: 14) {
                if app.age == nil {
                    Button { askBirth = true } label: { Label("填写出生日期，从宝宝这个月开始", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity) }
                        .buttonStyle(.vinyl(Palette.accentFill, prominent: true, large: true))
                }
                if wheel {
                    GrowthMap(month: Binding(get: { m }, set: { chosen = $0 == baby ? nil : $0 }), baby: baby) { withAnimation(.snappy) { wheel = false } }
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                } else {
                    MonthCard(month: m, baby: baby) { withAnimation(.snappy) { wheel = true } }
                        .transition(.opacity)
                }
                if app.journal && app.age != nil { NowCard(month: baby) }
                if app.age != nil {
                    TipView(recordsTip) { action in
                        if action.id == "on" { withAnimation(.snappy) { app.journal = true }; recordsTip.invalidate(reason: .actionPerformed) }
                    }
                }
                if m >= 36 { StoryGoesOn(primary: app.companion) }
                if m == baby && app.age != nil {
                    TipView(shelfTip)
                    ShelfView(month: m) { arranging = true }
                }
                PlaysGrid(month: m, hideShelf: m == baby && app.age != nil)
                MonthParts(month: m)
                Topics()
                HomeFooter()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.sunflower)
        .onChange(of: app.journal, initial: true) { _, on in RecordsTip.recordsOff = !on }
        .navigationTitle(app.nickname.isEmpty ? "摸索台灯" : app.nickname)
        .navigationSubtitle(app.age == nil ? "\(app.today.md) \(app.today.weekday)" : "")
        .toolbar {
            if chosen != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("回到本月", systemImage: "arrow.uturn.backward") { withAnimation(.snappy) { chosen = nil } }
                }
            }
            ToolbarItem(placement: .topBarTrailing) { NavigationLink(value: Route.search) { Image(systemName: "magnifyingglass") }.accessibilityLabel("搜索") }
        }
        .sheet(isPresented: $askBirth) { BirthSheet() }
        .sheet(isPresented: $arranging) { ShelfEditor() }
        .onChange(of: app.babyMonth) { _, _ in chosen = nil }
    }
}

/// Now: what the baby is doing, from the parent's own records, and what that means for play — the one place where
/// the care log and the picture book meet. Asleep: the companions sleep too, and one tap says the baby woke. Feeding:
/// how long, and the timer. Awake (after a recorded sleep): how long awake, and the shelf's next play to do now, while
/// the baby is awake and calm. Only facts from the records; no predictions. Hidden when there is nothing to say.
private struct NowCard: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.night) private var night
    @Environment(\.lamp) private var lamp
    let month: Int
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { tl in
            let now = tl.date.timeIntervalSince1970 * 1000
            if let sleep = j.timers.first(where: { $0.type == LogType.sleep }) {
                // waking is recorded on the sleep's own page (one place to start and end a timer)
                Button { j.focus = LogType.sleep } label: {
                    card(tint: Crayon.lilac) {
                        Duo(primary: app.companion, size: 44, mood: .sleep, night: true)
                        words(sleep.pausedAt != nil ? "睡眠 · 已暂停" : "宝宝在睡觉", "已经睡了 " + durationValue(sleep.total(now)) + " · 醒了点这里记下")
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.toy)
            } else if let feed = j.timers.first(where: { $0.type == LogType.nurse }) {
                Button { j.focus = LogType.nurse } label: {
                    card(tint: Crayon.pink) {
                        IconTile(symbol: LogType.symbol(LogType.nurse), color: Crayon.pink, size: 40)
                        words(feed.pausedAt != nil ? "亲喂 · 已暂停" : "正在亲喂" + (feed.side == "r" ? " · 右侧" : " · 左侧"), "已经 " + durationValue(feed.total(now)))
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.toy)
            } else if let woke = j.logs.first(where: { $0.type == LogType.sleep && $0.end != nil })?.end, now - woke < 6 * 3_600_000, !night {
                let play = app.weekShelf(month).plays.min { app.record($0, j).count < app.record($1, j).count }
                NavigationLink(value: play.map { Route.play($0.code, month) } ?? Route.month(month)) {
                    card(tint: Crayon.sunflower) {
                        if let p = play { Figure(name: "tray_\(p.code.lowercased()).webp").frame(width: 72, height: 54) }
                        else { Duo(primary: app.companion, size: 44) }
                        words("醒了 " + durationValue((now - woke) / 1000), play.map { "现在玩：" + $0.name } ?? "醒着的时候，一起玩一会儿")
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.toy)
            }
        }
    }
    private func words(_ a: String, _ b: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(a).font(.headline).foregroundStyle(.primary)
            Text(b).font(.subheadline).foregroundStyle(Palette.secondaryText).lineLimit(2).multilineTextAlignment(.leading)
        }
    }
    private func card<C: View>(tint: Color, @ViewBuilder _ c: () -> C) -> some View {
        HStack(spacing: 12) { c() }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.16)).printCard(radius: 22)
    }
}

/// The month, folded: the child at this age on a small patch of sky, the month and its title. Tapping it opens the
/// growth wheel in place.
private struct MonthCard: View {
    @Environment(AppModel.self) private var app
    @Environment(\.night) private var night
    @Environment(\.dynamicTypeSize) private var type
    let month: Int, baby: Int
    let open: () -> Void
    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                // the map in small: the child's hill and path, Moss on his stone (by night, home asleep)
                MapVignette(month: month, baby: baby)
                .frame(width: 104, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(month == 0 ? "出生" : "\(month)").font(Typeface.numerals(38, relativeTo: .largeTitle, weight: .bold))
                        if month > 0 { Text("个月").font(.subheadline.weight(.semibold)) }
                        if month == baby, let d = app.age?.days, d > 0 { Text("\(d)").font(Typeface.numerals(19, relativeTo: .headline, weight: .bold)).padding(.leading, 2); Text("天").font(.subheadline.weight(.semibold)) }
                        if month != baby { Text(month < baby ? "· 走过的一站" : "· 以后的一站").font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText) }
                    }
                    Text(app.content.month(month).title).font(.subheadline).foregroundStyle(Palette.secondaryText).lineLimit(type.isAccessibilitySize ? nil : 2).multilineTextAlignment(.leading)
                    // the way through this month to the next, and how many days are left
                    if month == baby, let a = app.age, a.days + a.toNext > 0 {
                        MonthProgress(days: a.days, toNext: a.toNext, next: month + 1).padding(.top, 2)
                    }
                }
                .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(10).padding(.trailing, 6)
            .background(LinearGradient(colors: [Crayon.sunflower.opacity(night ? 0.06 : 0.12), Crayon.sky.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .printCard(radius: 26)
        }
        .buttonStyle(.toy)
        .accessibilityLabel("\(month == 0 ? "出生" : "\(month) 个月")，\(app.content.month(month).title)")
        .accessibilityHint("打开成长地图，选择月份")
    }
}

/// The month's plays as picture cards: the one done least (the natural next one) leads, full width.
struct PlaysLeadGrid: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.dynamicTypeSize) private var type
    let plays: [Play], month: Int
    var body: some View {
        // a stable order: not yet done first, then the fewest times
        let ordered = plays.enumerated().sorted { a, b in
            let x = app.record(a.element, j).count, y = app.record(b.element, j).count
            return x != y ? x < y : a.offset < b.offset
        }.map(\.element)
        // two to a row, all alike (no full-width lead picture): a month's plays read in one screen
        if type.isAccessibilitySize {
            VStack(spacing: 10) { ForEach(ordered) { PlayTileLink(play: $0, month: month, form: .row) } }
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(ordered) { PlayTileLink(play: $0, month: month) }
            }
        }
    }
}

/// The month's plays as picture cards, two by two; this month's shelf is shown above, so its plays are not repeated.
private struct PlaysGrid: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var type
    let month: Int
    let hideShelf: Bool
    var body: some View {
        let shelf = hideShelf ? app.weekShelf(month).plays.map(\.code) : []
        let plays = app.content.plays(of: month).filter { !shelf.contains($0.code) }
        if !plays.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: hideShelf ? "这个月还能玩" : "这个月的教具", detail: "\(plays.count) 个")
                if plays.count <= 2 || type.isAccessibilitySize {
                    VStack(spacing: 10) { ForEach(plays) { PlayTileLink(play: $0, month: month, form: .row) } }
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(plays) { PlayTileLink(play: $0, month: month) }
                    }
                }
            }
        }
    }
}

/// The topics' marks: all five are care topics, so one colour (the care area's), told apart by their symbols.
let topicMarks: [(String, Color)] = ["moon.zzz.fill", "bed.double.fill", "fork.knife", "mouth.fill", "cross.case.fill"].map { ($0, Palette.area("F")) }

/// The topics, as one card of rows: a mark, the title, where it comes from, a chevron.
struct Topics: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var type
    var body: some View {
        let items = app.content.topics.enumerated().map { TopicItem(i: $0.offset, t: $0.element) }
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "专题", detail: "照护参考")
            // two to a row: the five topics in three short rows
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: type.isAccessibilitySize ? 1 : 2), spacing: 10) {
                ForEach(items) { x in
                    NavigationLink(value: Route.topic(x.t.id)) {
                        HStack(spacing: 10) {
                            IconTile(symbol: topicMarks[x.i % topicMarks.count].0, color: topicMarks[x.i % topicMarks.count].1, size: 28)
                            Text(x.t.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                .multilineTextAlignment(.leading).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        .printCard(radius: 18)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.toy)
                }
            }
        }
    }
}

/// The end of the page: the two of them and the line the app is named for, a way into its story.
private struct HomeFooter: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        NavigationLink(value: Route.story) {
            VStack(spacing: 6) {
                Duo(primary: app.companion, size: 40, poke: false)
                Text("孩子摸索，大人点灯").font(.footnote.weight(.semibold)).foregroundStyle(Palette.secondaryText)
            }
            .frame(maxWidth: .infinity).padding(.top, 24).padding(.bottom, 8)
        }
        .buttonStyle(.toy)
        .accessibilityLabel("摸索台灯的故事")
    }
}
private struct TopicItem: Identifiable { let i: Int; let t: Topic; var id: String { t.id } }

/// This week's shelf — the heart of the app when nothing is recorded (docs/IP.md §3): the three or four materials
/// out this week, in the app's own language — one card on the paper (soft vinyl in 3D, cut paper in 2D), each
/// material a tray on a tile of its area's colour, with what the parent needs to begin: the area, the name, how many
/// steps and the first one, and gold beads for the times it was played (a count, never a score). The least-played one
/// carries 「先玩这件」. The week's progress is a short path of stones, as on the growth map. Moss and Otto sit on the
/// card's top edge; at night Otto's lamp throws a warm pool over it.
struct ShelfView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.night) private var night
    @Environment(\.dynamicTypeSize) private var size
    @Environment(JournalStore.self) private var j
    let month: Int
    let arrange: () -> Void
    private var flat: Bool { ArtStyle.current == .flat }
    var body: some View {
        let s = app.weekShelf(month)
        let since = app.today.monday.date
        let played = s.plays.filter { (app.record($0, j).last ?? .distantPast) >= since }.count
        let first = s.plays.min { app.record($0, j).count < app.record($1, j).count }?.code
        let left = Shelf.candidates(app.content, month).filter { c in !s.plays.contains { $0.code == c.code } }.count
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                GoldBead(size: 10)
                Text("本周的架子").font(.title3.weight(.bold)).accessibilityAddTraits(.isHeader)
                if !s.plays.isEmpty && !s.stale { WeekStones(played: played, total: s.plays.count) }
                Spacer(minLength: 4)
                Button(action: arrange) {
                    // the words stay small; the place to tap is a full 44 points (HIG: hit targets)
                    Text(s.stale ? "换上新的一周" : "整理").padding(.horizontal, 8).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .font(.subheadline.weight(.semibold)).padding(.vertical, -12).padding(.trailing, -8)
            }
            .padding(.horizontal, 4).padding(.top, 20)
            if s.stale || s.plays.isEmpty {
                Text(s.stale ? "上周的教具还在架子上，可以换上这个月新的几件。" : "架子还空着。点「整理」，从这个月的 \(left) 件里挑三四件放上来。")
                    .font(.subheadline).foregroundStyle(Palette.secondaryText).padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 0) {
                ForEach(Array(s.plays.enumerated()), id: \.element.code) { i, p in
                    if i > 0 { Divider().padding(.leading, size.isAccessibilitySize ? 16 : 102) }
                    compartment(p, first: p.code == first && s.plays.count > 1)
                }
                if s.plays.count < Shelf.max {
                    if !s.plays.isEmpty { Divider().padding(.leading, size.isAccessibilitySize ? 16 : 102) }
                    Button(action: arrange) { empty(room: Shelf.max - s.plays.count, left: left) }
                        .buttonStyle(.toy).accessibilityLabel("放一件教具").accessibilityHint("这个月还有 \(left) 件可选")
                }
            }
            .padding(.vertical, 4)
            .background(alignment: .top) { if night { LampPool() } }
            .printCard(radius: 24)
            .overlay(alignment: .topTrailing) {
                // the two of them, sitting on the card's top edge
                Duo(primary: app.companion, size: 44, look: CGPoint(x: -0.6, y: 0.6), night: night, reacts: true)
                    .offset(x: -16, y: -40)
            }
            .padding(.top, 30)
        }
    }

    private func route(_ p: Play) -> Route { Route.play(p.code, month) }

    /// One material: its tray on a tile of its area's colour, and beside it what to know before starting.
    private func compartment(_ p: Play, first: Bool) -> some View {
        let times = app.record(p, j).count, key = Palette.areaKey(of: p)
        let big = size.isAccessibilitySize
        let layout = big ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return NavigationLink(value: route(p)) {
            layout {
                TrayTile(code: p.code, color: Palette.area(key), flat: flat)
                    .frame(width: big ? 180 : 76, height: big ? 135 : 60)
                    .zoomSource(route(p))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        IconTile(symbol: Palette.areaSymbol(key), color: Palette.area(key), size: 16)
                        Text(p.domains.first ?? "").font(.caption.weight(.semibold)).foregroundStyle(Palette.areaInk(key)).lineLimit(1)
                        if first {
                            Text("先玩这件").font(.caption2.weight(.bold)).foregroundStyle(.white)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .vinylSurface(Palette.accentFill, radius: 10, strong: true).fixedSize()
                        }
                    }
                    Text(p.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        .lineLimit(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    if let step = p.steps.first {
                        Text("共 \(p.steps.count) 步 · " + step).font(.caption).foregroundStyle(Palette.secondaryText)
                            .lineLimit(big ? 3 : 1).multilineTextAlignment(.leading)
                    }
                    BeadCount(times: times).padding(.top, 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                    .opacity(big ? 0 : 1)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.toy)
        .contextMenu { PlayActions(play: p, month: month) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(p.name + (first ? "，先玩这件" : "") + (times > 0 ? "，玩过 \(times) 次" : "，还没玩过"))
        .accessibilityHint((p.domains.first ?? "") + "，\(p.steps.count) 步")
    }

    /// The one free place: a dashed tile and how much room is left.
    private func empty(room: Int, left: Int) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Palette.outline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                .overlay(Image(systemName: "plus").font(.headline.weight(.semibold)).foregroundStyle(Palette.accent))
                .frame(width: 76, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("放一件").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text("还能放 \(room) 件 · 这个月有 \(left) 件可选").font(.caption).foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

/// A tray on a tile of its area's colour: in 3D a soft lit vinyl tile (lighter at the top, a fine lit rim), in 2D one
/// flat colour of paper with a crisp edge below.
struct TrayTile: View {
    let code: String
    let color: Color
    let flat: Bool
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let dark = scheme == .dark
        ZStack {
            if flat {
                shape.fill(color.mix(with: dark ? Palette.lampCard : .white, by: dark ? 0.68 : 0.78))
                    .background(shape.fill(color.opacity(dark ? 0.35 : 0.3)).offset(y: 2))
            } else {
                shape.fill(LinearGradient(colors: [color.mix(with: dark ? Palette.lampCard : .white, by: dark ? 0.62 : 0.86), color.mix(with: dark ? Palette.lampCard : .white, by: dark ? 0.75 : 0.7)],
                                          startPoint: .top, endPoint: .bottom))
                    .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(dark ? 0.15 : 0.9), .white.opacity(0)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                    .shadow(color: color.opacity(dark ? 0 : 0.18), radius: 4, y: 2)
            }
            Figure(name: "tray_\(code.lowercased()).webp").aspectRatio(4 / 3, contentMode: .fit).padding(4)
        }
        .accessibilityHidden(true)
    }
}

/// The week's progress as a short path of stones, like the growth map's: gold for the materials played this week.
private struct WeekStones: View {
    let played: Int, total: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                ZStack {
                    if i < played {
                        Circle().fill(RadialGradient(colors: [Palette.beadLight, Palette.bead], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 6))
                    } else {
                        Circle().fill(Palette.card)
                        Circle().strokeBorder(Palette.bead.opacity(0.55), lineWidth: 1.5)
                    }
                }
                .frame(width: 10, height: 10)
            }
            Text("\(played)/\(total)").font(Typeface.numerals(12, relativeTo: .footnote, weight: .semibold)).foregroundStyle(Palette.secondaryText)
                .padding(.leading, 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("本周玩过 \(played) / \(total)")
    }
}

/// Times played, as gold beads on a short string (Montessori's golden bead): up to five, then the number.
private struct BeadCount: View {
    let times: Int
    var body: some View {
        HStack(spacing: 3) {
            if times == 0 {
                Text("还没玩过").font(.caption2).foregroundStyle(Palette.secondaryText)
            } else {
                ForEach(0..<min(times, 5), id: \.self) { _ in
                    Circle().fill(RadialGradient(colors: [Palette.beadLight, Palette.bead], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 6))
                        .frame(width: 9, height: 9)
                }
                Text("\(times) 次").font(Typeface.numerals(11, relativeTo: .caption2, weight: .semibold)).foregroundStyle(Palette.lampTint).padding(.leading, 2)
            }
        }
        .accessibilityHidden(true)
    }
}

/// At night, Otto's lamp on the card's edge throws a warm pool down over the trays (a drawing of light only).
private struct LampPool: View {
    var body: some View {
        RadialGradient(colors: [Palette.amber.opacity(0.28), Palette.amber.opacity(0)], center: UnitPoint(x: 0.82, y: 0), startRadius: 0, endRadius: 320)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Arranging the shelf, as a sheet.
struct ShelfEditor: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            PlanView(path: .constant(NavigationPath()))
                .routes(path: .constant(NavigationPath()))
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成", systemImage: "checkmark") { dismiss() } } }
                .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

/// The child's date of birth.
struct BirthSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var date = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("出生日期", selection: $date, in: Calendar.current.date(byAdding: .year, value: -4, to: Date())!...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }
            .navigationTitle("出生日期").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("完成", systemImage: "checkmark") { app.birth = Day(date); dismiss() } }
            }
            .onAppear { if let b = app.birth { date = b.date } }
        }
        .presentationDetents([.large])
    }
}
