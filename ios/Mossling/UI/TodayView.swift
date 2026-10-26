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
                    Button { askBirth = true } label: { Label("填写出生日期，从宝宝这个月开始", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity).padding(.vertical, 6) }
                        .buttonStyle(.borderedProminent).tint(Palette.accentFill).controlSize(.large)
                }
                if wheel {
                    GrowthWheel(month: Binding(get: { m }, set: { chosen = $0 == baby ? nil : $0 }), baby: baby)
                        .overlay(alignment: .topTrailing) {
                            Button { withAnimation(.snappy) { wheel = false } } label: {
                                Image(systemName: "chevron.up").font(.footnote.weight(.bold)).frame(width: 30, height: 30)
                                    .background(.white.opacity(0.85), in: Circle())
                            }
                            .foregroundStyle(Color(hex: 0x2E2418)).padding(12).accessibilityLabel("收起成长滚轮")
                        }
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
                // the child at this age, as in the pictures, standing in a small pool of light of the year's colour
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(colors: [Land.of(month).crayon.opacity(night ? 0.22 : 0.16), Land.of(month).crayon.opacity(night ? 0.10 : 0.06)], startPoint: .top, endPoint: .bottom))
                    Circle().fill(RadialGradient(colors: [Color(hex: 0xFFE39A).opacity(night ? 0.25 : 0.6), .clear], center: .center, startRadius: 0, endRadius: 40))
                        .frame(width: 80, height: 80).offset(x: 26, y: -58)
                    Ellipse().fill(Land.of(month).crayon.opacity(0.22)).frame(width: 78, height: 14).offset(y: -9)
                    GrowingChild(month: month).frame(width: 104, height: 104).offset(y: 6)
                }
                .frame(width: 104, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(month == 0 ? "出生" : "\(month)").font(Typeface.numerals(38, relativeTo: .largeTitle, weight: .bold))
                        if month > 0 { Text("个月").font(.subheadline.weight(.semibold)) }
                        if month == baby, let d = app.age?.days, d > 0 { Text("\(d)").font(Typeface.numerals(19, relativeTo: .headline, weight: .bold)).padding(.leading, 2); Text("天").font(.subheadline.weight(.semibold)) }
                        if month != baby { Text(month < baby ? "· 走过的一站" : "· 以后的一站").font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText) }
                    }
                    Text(app.content.month(month).title).font(.subheadline).foregroundStyle(Palette.secondaryText).lineLimit(type.isAccessibilitySize ? nil : 2).multilineTextAlignment(.leading)
                    // the way through this month to the next: a bead on a string, and how many days are left
                    if month == baby, let a = app.age, a.days + a.toNext > 0 {
                        let k = Double(a.days) / Double(a.days + a.toNext)
                        HStack(spacing: 8) {
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Palette.outline.opacity(0.5)).frame(height: 4)
                                    Capsule().fill(LinearGradient(colors: [Crayon.sunflower, Palette.accentFill], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: max(8, g.size.width * k), height: 4)
                                    Circle().fill(Palette.bead).frame(width: 10, height: 10)
                                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                                        .offset(x: max(0, g.size.width * k - 5))
                                }
                                .frame(maxHeight: .infinity)
                            }
                            .frame(height: 10)
                            Text("\(a.toNext) 天后满 \(month + 1) 个月").font(.caption2.weight(.semibold)).foregroundStyle(Palette.secondaryText).monospacedDigit().fixedSize()
                        }
                        .padding(.top, 2)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(a.toNext) 天后满 \(month + 1) 个月")
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
        .accessibilityHint("打开成长滚轮，选择月份")
    }
}

/// The month's plays as picture cards: the one done least (the natural next one) leads, full width.
struct PlaysLeadGrid: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    let plays: [Play], month: Int
    var body: some View {
        // a stable order: not yet done first, then the fewest times
        let ordered = plays.enumerated().sorted { a, b in
            let x = app.record(a.element, j).count, y = app.record(b.element, j).count
            return x != y ? x < y : a.offset < b.offset
        }.map(\.element)
        LeadGrid(items: ordered) { PlayTileLink(play: $0, month: month, form: .lead) }
            cell: { PlayTileLink(play: $0, month: month) }
            row: { PlayTileLink(play: $0, month: month, form: .row) }
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
                PlaysLeadGrid(plays: plays, month: month)
            }
        }
    }
}

/// The topics' marks: all five are care topics, so one colour (the care area's), told apart by their symbols.
let topicMarks: [(String, Color)] = ["moon.zzz.fill", "bed.double.fill", "fork.knife", "mouth.fill", "cross.case.fill"].map { ($0, Palette.area("F")) }

/// The topics, as one card of rows: a mark, the title, where it comes from, a chevron.
private struct Topics: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        let items = app.content.topics.enumerated().map { TopicItem(i: $0.offset, t: $0.element) }
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "专题", detail: "照护参考")
            VStack(spacing: 0) {
                ForEach(items) { x in
                    if x.i > 0 { Divider().padding(.leading, 60) }
                    NavigationLink(value: Route.topic(x.t.id)) {
                        HStack(spacing: 12) {
                            IconTile(symbol: topicMarks[x.i % topicMarks.count].0, color: topicMarks[x.i % topicMarks.count].1, size: 34)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(x.t.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading)
                                Text(x.t.sourceTitle).font(.caption).foregroundStyle(Palette.secondaryText).lineLimit(2).multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.toy)
                }
            }
            .printCard(radius: 22)
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

/// This week's shelf — the heart of the app when nothing is recorded (docs/IP.md §3). Built like the low open shelf of
/// a Montessori room, but compact: one compartment per material, each a wooden board with the tray standing on it and,
/// beside it, what the parent needs to begin — the area, the name, how many steps and the first one, and the gold beads
/// for every time it was played (a count, never a score). The least-played one carries 「先玩这件」. A single dashed
/// place invites one more while the shelf has room. Moss and Otto sit on top of the cabinet; at night Otto's lamp throws
/// a warm pool of light down over the trays.
struct ShelfView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.night) private var night
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var size
    @Environment(JournalStore.self) private var j
    let month: Int
    let arrange: () -> Void
    var body: some View {
        let s = app.weekShelf(month)
        let dark = scheme == .dark
        let since = app.today.monday.date
        let played = s.plays.filter { (app.record($0, j).last ?? .distantPast) >= since }.count
        let first = s.plays.min { app.record($0, j).count < app.record($1, j).count }?.code
        let left = Shelf.candidates(app.content, month).filter { c in !s.plays.contains { $0.code == c.code } }.count
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("本周的架子").font(.title3.weight(.bold)).accessibilityAddTraits(.isHeader)
                if !s.plays.isEmpty && !s.stale {
                    Text("玩过 \(played) / \(s.plays.count)").font(Typeface.numerals(13, relativeTo: .footnote, weight: .semibold))
                        .foregroundStyle(Palette.accent).padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(Palette.accent.opacity(0.12))).fixedSize()
                }
                Spacer()
                Button(action: arrange) {
                    // the words stay small; the place to tap is a full 44 points (HIG: hit targets)
                    Text(s.stale ? "换上新的一周" : "整理").padding(.horizontal, 8).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .font(.subheadline.weight(.semibold)).padding(.vertical, -12).padding(.trailing, -8)
            }
            .padding(.horizontal, 4).padding(.top, 20)
            Text(s.stale ? "上周的教具还在架子上，可以换上这个月新的几件。"
                 : s.plays.isEmpty ? "架子还空着。点「整理」，从这个月的 \(left) 件里挑三四件放上来。"
                 : "从标着「先玩这件」的开始；点开一件，跟着图一步步玩。每周三四件，孩子想重复就重复。")
                .font(.subheadline).foregroundStyle(Palette.secondaryText).padding(.horizontal, 4)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                ShelfBoard(dark: dark).frame(height: 12)   // the top of the cabinet
                ForEach(s.plays) { p in
                    compartment(p, first: p.code == first && s.plays.count > 1, dark: dark)
                    ShelfBoard(dark: dark).frame(height: 12)
                }
                if s.plays.count < Shelf.max {
                    Button(action: arrange) { empty(room: Shelf.max - s.plays.count, left: left, dark: dark) }
                        .buttonStyle(.toy).accessibilityLabel("放一件教具").accessibilityHint("这个月还有 \(left) 件可选")
                    ShelfBoard(dark: dark).frame(height: 12)
                }
            }
            .background { ShelfBack(dark: dark) }
            .overlay { if night { LampPool() } }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color(hex: 0x6B4A2B).opacity(dark ? 0 : 0.18), radius: 10, y: 6)
            .overlay(alignment: .topTrailing) {
                // the two of them, sitting on top of the cabinet
                Duo(primary: app.companion, size: 54, look: CGPoint(x: -0.6, y: 0.6), night: night, reacts: true)
                    .offset(x: -18, y: -48)
            }
            .padding(.top, 34)
        }
    }

    private func route(_ p: Play) -> Route { Route.play(p.code, month) }
    private func ink(_ dark: Bool) -> Color { dark ? Color(hex: 0xF3E6D6) : Color(hex: 0x3A2C1E) }
    private func soft(_ dark: Bool) -> Color { dark ? Color(hex: 0xCBB9A5) : Color(hex: 0x7A6650) }

    /// One compartment: the tray on its board, and beside it what to know before starting.
    private func compartment(_ p: Play, first: Bool, dark: Bool) -> some View {
        let times = app.record(p, j).count, key = Palette.areaKey(of: p)
        let big = size.isAccessibilitySize
        let layout = big ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .center, spacing: 12))
        return NavigationLink(value: route(p)) {
            layout {
                Figure(name: "tray_\(p.code.lowercased()).webp").aspectRatio(4 / 3, contentMode: .fit)
                    .frame(width: big ? 200 : 118)
                    .zoomSource(route(p))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        IconTile(symbol: Palette.areaSymbol(key), color: Palette.area(key), size: 16)
                        Text(p.domains.first ?? "").font(.caption.weight(.semibold)).foregroundStyle(Palette.areaInk(key)).lineLimit(1)
                        if first {
                            Text("先玩这件").font(.caption2.weight(.bold)).foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Palette.accent)).fixedSize()
                        }
                    }
                    Text(p.name).font(.subheadline.weight(.semibold)).foregroundStyle(ink(dark))
                        .lineLimit(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    if let step = p.steps.first {
                        Text("共 \(p.steps.count) 步 · " + step).font(.caption).foregroundStyle(soft(dark))
                            .lineLimit(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    }
                    BeadCount(times: times, dark: dark).padding(.top, 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(soft(dark).opacity(0.7))
                    .opacity(big ? 0 : 1)
            }
            .padding(.leading, 18).padding(.trailing, 20).padding(.top, 8).padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.toy)
        .contextMenu { PlayActions(play: p, month: month) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(p.name + (first ? "，先玩这件" : "") + (times > 0 ? "，玩过 \(times) 次" : "，还没玩过"))
        .accessibilityHint((p.domains.first ?? "") + "，\(p.steps.count) 步")
    }

    /// The one free place on the shelf: a dashed tray and how much room is left.
    private func empty(room: Int, left: Int, dark: Bool) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(hex: 0xB98A5A).opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(dark ? 0.05 : 0.25)))
                .overlay(Image(systemName: "plus").font(.headline.weight(.semibold)).foregroundStyle(Color(hex: 0x8A6440)))
                .frame(width: 118, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("放一件").font(.subheadline.weight(.semibold)).foregroundStyle(ink(dark))
                Text("还能放 \(room) 件 · 这个月有 \(left) 件可选").font(.caption).foregroundStyle(soft(dark))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.leading, 18).padding(.trailing, 20).padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// Times played, as gold beads on a short string (Montessori's golden bead): up to five, then the number.
private struct BeadCount: View {
    let times: Int
    var dark = false
    var body: some View {
        HStack(spacing: 3) {
            if times == 0 {
                Text("还没玩过").font(.caption2).foregroundStyle(dark ? Color(hex: 0xCBB9A5) : Color(hex: 0x7A6650))
            } else {
                ForEach(0..<min(times, 5), id: \.self) { _ in
                    Circle().fill(RadialGradient(colors: [Palette.beadLight, Palette.bead], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 6))
                        .frame(width: 9, height: 9)
                }
                Text("\(times) 次").font(Typeface.numerals(11, relativeTo: .caption2, weight: .semibold)).foregroundStyle(dark ? Palette.beadLight : Color(hex: 0x7A5A10)).padding(.leading, 2)
            }
        }
        .accessibilityHidden(true)
    }
}

/// One shelf board seen a little from above: a lit top face, a front edge with a fine highlight, wood grain.
private struct ShelfBoard: View {
    let dark: Bool
    var body: some View {
        Canvas { ctx, size in
            let top = size.height * 0.42
            ctx.fill(Path(CGRect(x: 0, y: 0, width: size.width, height: top)),
                     with: .linearGradient(Gradient(colors: dark ? [Color(hex: 0x8A6A4E), Color(hex: 0x76583F)] : [Color(hex: 0xF3D3A6), Color(hex: 0xE2B47E)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: top)))
            ctx.fill(Path(CGRect(x: 0, y: top, width: size.width, height: size.height - top)),
                     with: .linearGradient(Gradient(colors: dark ? [Color(hex: 0x6A4E37), Color(hex: 0x553E2B)] : [Color(hex: 0xC98F5E), Color(hex: 0xA9733F)]), startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: size.height)))
            ctx.fill(Path(CGRect(x: 0, y: top, width: size.width, height: 1)), with: .color(.white.opacity(dark ? 0.15 : 0.4)))
            for (x0, x1, y) in [(0.06, 0.34, 0.6), (0.44, 0.8, 0.75), (0.62, 0.95, 0.58)] as [(CGFloat, CGFloat, CGFloat)] {
                var g = Path(); let gy = size.height * y
                g.move(to: CGPoint(x: size.width * x0, y: gy)); g.addQuadCurve(to: CGPoint(x: size.width * x1, y: gy + 1), control: CGPoint(x: size.width * (x0 + x1) / 2, y: gy - 1.5))
                ctx.stroke(g, with: .color(Color(hex: 0x6A4526).opacity(0.25)), lineWidth: 0.8)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The cabinet behind the trays: a warm back panel, darker towards the bottom of each shelf, and two side posts.
private struct ShelfBack: View {
    let dark: Bool
    var body: some View {
        ZStack {
            LinearGradient(colors: dark ? [Color(hex: 0x3E3346), Color(hex: 0x332A3A)] : [Color(hex: 0xFBEBD2), Color(hex: 0xF2DCBA)], startPoint: .top, endPoint: .bottom)
            HStack {
                post; Spacer(); post
            }
        }
        .accessibilityHidden(true)
    }
    private var post: some View {
        LinearGradient(colors: dark ? [Color(hex: 0x7A5C43), Color(hex: 0x5E4532)] : [Color(hex: 0xE8BF8A), Color(hex: 0xC99560)], startPoint: .leading, endPoint: .trailing)
            .frame(width: 10)
    }
}

/// At night, Otto's lamp on top of the cabinet throws a warm pool down over the trays (a drawing of light only).
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
