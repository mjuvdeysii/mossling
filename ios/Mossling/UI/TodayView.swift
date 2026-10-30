import SwiftUI
import TipKit

/// The home holds only what is needed every day, in that order: who the child is now (the month card — tapping it
/// opens the month's own page, where everything read once lives: its points, its parts, all its plays, the topics,
/// and the way to other months); what is due this month, only while something is; what is happening now, from the
/// records; and 今天一起玩, the everyday reason to open the app. It reads in about one screen.
struct TodayView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.night) private var night
    @Binding var path: NavigationPath
    @State private var askBirth = false
    @State private var arranging = false
    private let shelfTip = ShelfTip()
    private let recordsTip = RecordsTip()

    var body: some View {
        let baby = app.babyMonth ?? 0
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if app.age == nil {
                    Button { if app.mayKeep() { askBirth = true } } label: { Label("填写出生日期，从宝宝这个月开始", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity) }
                        .buttonStyle(.vinyl(Palette.accentFill, prominent: true, large: true))
                }
                // a feed or a sleep being timed is what matters most while it runs: it leads the page
                let running = !j.timers.isEmpty || night
                if running && app.journal && app.age != nil { NowCard(month: baby) }
                MonthCard(month: baby, baby: baby) { path.append(Route.month(baby)) }
                if app.age != nil { DueCard(month: baby) }
                if !running && app.journal && app.age != nil { NowCard(month: baby) }
                if app.age != nil {
                    TipView(recordsTip) { action in
                        if action.id == "on" && app.mayKeep() { withAnimation(.snappy) { app.journal = true }; recordsTip.invalidate(reason: .actionPerformed) }
                    }
                }
                if app.age != nil { TipView(shelfTip) }
                // before the birth date is known too: the same 今天一起玩, from the first month's plays (the week is
                // chosen anew for the child's month once the date is given)
                TodayPlayCard(month: baby) { arranging = true }
                if baby >= 36 { StoryGoesOn(primary: app.companion) }
                HomeFooter { path.append(Route.story) }
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
            ToolbarItem(placement: .topBarTrailing) { NavigationLink(value: Route.search) { Image(systemName: "magnifyingglass") }.accessibilityLabel("搜索") }
        }
        .sheet(isPresented: $askBirth) { BirthSheet() }
        .sheet(isPresented: $arranging) { ShelfEditor() }
    }
}

/// What is due this month and not yet done — vaccines and check-ups — as one line that opens them; shown only while
/// something is left, so the home is quiet when nothing is.
private struct DueCard: View {
    @Environment(AppModel.self) private var app
    let month: Int
    var body: some View {
        let mo = app.content.month(month)
        let total = mo.vaccines.count + mo.checkups.count
        let done = app.count(month, TickKind.vaccine) + app.count(month, TickKind.checkup)
        let earlier = app.duePending(before: month).count
        if total > done || earlier > 0 {
            NavigationLink(value: Route.care(month)) {
                HStack(spacing: 12) {
                    IconTile(symbol: "syringe.fill", color: Crayon.pink, size: 34)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("这个月的接种与儿保").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        Text("中国大陆程序").font(.caption2).foregroundStyle(Palette.secondaryText)
                        Text("本月 \(done) / \(total)" + (earlier > 0 ? " · 另有 \(earlier) 项之前没勾" : "")).font(.caption).foregroundStyle(Palette.secondaryText).monospacedDigit()
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                }
                .padding(12).printCard(radius: Radius.card)
            }
            .buttonStyle(.toy)
        }
    }
}

/// Now: what the baby is doing, from the parent's own records, and what that means for play — the one place where
/// the care log and the picture book meet. Asleep: the companions sleep too, and one tap says the baby woke. Feeding:
/// how long, and the timer. Awake: said in 今天一起玩's own header (醒了 40 分钟 · 一起玩), not in a card of its own.
/// At night, the last feed, waking and nappy. Only facts from the records; no predictions. Hidden when there is
/// nothing to say.
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
                        words(sleep.pausedAt != nil ? timerState(LogType.sleep, side: nil, paused: true) : "宝宝在睡觉", "已经睡了 " + durationValue(sleep.total(now)) + " · 醒了点这里记下")
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.toy)
            } else if let feed = j.timers.first(where: { $0.type == LogType.nurse }) {
                Button { j.focus = LogType.nurse } label: {
                    card(tint: Crayon.pink) {
                        IconTile(symbol: LogType.symbol(LogType.nurse), color: Crayon.pink, size: 40)
                        words(feed.pausedAt != nil ? timerState(LogType.nurse, side: feed.side, paused: true) : "正在亲喂" + (feed.side == "r" ? " · 右侧" : " · 左侧"), "已经 " + durationValue(feed.total(now)))
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.toy)
            } else if night && !j.logs.isEmpty {
                // at night, with nothing running: the three things asked at 2 a.m. — when the last feed was, when the
                // baby last woke, the last nappy — each one tap from recording the next
                HStack(spacing: 8) {
                    fact(LogType.nurse, "care/nurse", tl.date)
                    fact(LogType.sleep, "care/sleep", tl.date)
                    fact(LogType.diaper, "log/diaper", tl.date)
                }
            }
        }
    }
    @Environment(\.openURL) private var openURL
    private func fact(_ type: String, _ link: String, _ now: Date) -> some View {
        let f = LastLine.fact(type, in: j.logs)
        let c = LogType.color(type)
        return Button { if let u = URL(string: "mossling://" + link) { openURL(u) } } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    IconTile(symbol: LogType.symbol(type), color: c, size: 20, round: true)
                    Text(f?.label ?? ("上次" + LogType.name(type))).font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText).lineLimit(1).minimumScaleFactor(0.8)
                }
                Text(f.map { ago($0.at, now: now) } ?? "—").font(Typeface.numerals(17, relativeTo: .headline, weight: .bold)).foregroundStyle(Crayon.ink(c))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(c.opacity(0.14)).printCard(radius: Radius.inner)
        }
        .buttonStyle(.toy)
        .accessibilityHint("记下一次" + LogType.name(type))
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
            .background(tint.opacity(0.16)).printCard(radius: Radius.card)
    }
}

/// The month: the child at this age on a small patch of sky, the month and its title, the way to the next. Tapping it
/// opens the month's own page.
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
                MapVignette(month: month, baby: baby, festive: month == baby && app.age?.days == 0 && app.age != nil)
                .frame(width: 104, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
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
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(10).padding(.trailing, 6)
            .background(LinearGradient(colors: [Crayon.sunflower.opacity(night ? 0.06 : 0.12), Crayon.sky.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .printCard(radius: Radius.card)
        }
        .buttonStyle(.toy)
        .accessibilityLabel("\(month == 0 ? "出生" : "\(month) 个月")，\(app.content.month(month).title)")
        .accessibilityHint("打开这个月的全部内容")
    }
}

/// The month's plays as picture cards: the one done least (the natural next one) leads, full width.
/// Two to a row, each cell half the width (a lone last cell the whole width). Its ideal width is twice the widest
/// cell's: inside ViewThatFits it is chosen only when every cell — every name — fits whole in its half.
struct PairGrid: Layout {
    var spacing: CGFloat = 10
    private func widest(_ subviews: Subviews) -> CGFloat { subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0 }
    private func cellWidths(_ n: Int, _ width: CGFloat) -> [CGFloat] {
        let half: CGFloat = (width - spacing) / 2
        return (0..<n).map { i in (i == n - 1 && n % 2 == 1) ? width : half }
    }
    private func rowHeights(_ subviews: Subviews, _ width: CGFloat) -> [CGFloat] {
        let w = cellWidths(subviews.count, width)
        var out: [CGFloat] = []
        var i = 0
        while i < subviews.count {
            let pair: Bool = i + 1 < subviews.count
            var h: CGFloat = subviews[i].sizeThatFits(ProposedViewSize(width: w[i], height: nil)).height
            if pair { h = max(h, subviews[i + 1].sizeThatFits(ProposedViewSize(width: w[i + 1], height: nil)).height) }
            out.append(h)
            i += pair ? 2 : 1
        }
        return out
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideal: CGFloat = widest(subviews) * 2 + spacing
        let width: CGFloat = proposal.width.map { $0.isFinite ? $0 : ideal } ?? ideal
        let hs = rowHeights(subviews, width)
        return CGSize(width: width, height: hs.reduce(0, +) + spacing * CGFloat(max(0, hs.count - 1)))
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let w = cellWidths(subviews.count, bounds.width), hs = rowHeights(subviews, bounds.width)
        var y = bounds.minY, i = 0, r = 0
        while i < subviews.count {
            let pair = i + 1 < subviews.count
            subviews[i].place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: w[i], height: hs[r]))
            if pair { subviews[i + 1].place(at: CGPoint(x: bounds.minX + w[i] + spacing, y: y), proposal: ProposedViewSize(width: w[i + 1], height: hs[r])) }
            y += hs[r] + spacing; i += pair ? 2 : 1; r += 1
        }
    }
}

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
        // two to a row when every name fits whole on its line; otherwise one under the other (a Chinese name broken
        // in the middle of a word reads wrong, and the phone's width decides, not the content)
        let list = VStack(spacing: 10) { ForEach(ordered) { PlayTileLink(play: $0, month: month, form: .row) } }
        if type.isAccessibilitySize {
            list
        } else {
            ViewThatFits(in: .horizontal) {
                PairGrid(spacing: 10) { ForEach(ordered) { PlayTileLink(play: $0, month: month, form: .mini) } }
                list
            }
        }
    }
}


/// The topics' marks: all five are care topics, so one colour (the care area's), told apart by their symbols.
let topicMarks: [(String, Color)] = ["moon.zzz.fill", "bed.double.fill", "fork.knife", "mouth.fill", "cross.case.fill"].map { ($0, Palette.area("F")) }

/// The topics, as one card of rows: a mark, the title, where it comes from, a chevron.
struct Topics: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        let items = app.content.topics.enumerated().map { TopicItem(i: $0.offset, t: $0.element) }
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "专题", detail: "照护参考")
            // one card of rows: each title whole on its line, nothing wrapped mid-word, no row half filled
            Box {
                ForEach(items) { x in
                    NavigationLink(value: Route.topic(x.t.id)) {
                        BoxRow(symbol: topicMarks[x.i % topicMarks.count].0, color: topicMarks[x.i % topicMarks.count].1, title: x.t.title, last: x.i == items.count - 1, opens: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// The end of the page: the two of them and the line the app is named for. Nothing says there is more: tap them and
/// they hop; keep tapping and on the third they take you into their story.
private struct HomeFooter: View {
    @Environment(AppModel.self) private var app
    let open: () -> Void
    @State private var hops = 0
    @State private var lamp = false
    var body: some View {
        VStack(spacing: 6) {
            Duo(primary: app.companion, size: 40, poke: false, cheer: hops, lit: lamp)
                .storyKnock(hops: $hops, lamp: $lamp, open: open)
            Text("孩子摸索，大人点灯").font(.footnote.weight(.semibold)).foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity).padding(.top, 24).padding(.bottom, 8)
    }
}
private struct TopicItem: Identifiable { let i: Int; let t: Topic; var id: String { t.id } }

/// 今天一起玩 — the heart of the app when nothing is recorded (docs/IP.md §3). The header is the answer: one play for
/// today, large — the picture of its first step, its area and how many steps, its name, the first step, when it was
/// last played — and under it the week's others (「这周还有」), each a tray and its gold beads for the times played
/// this week (a count, never a score). The week turns by itself; 换一个 takes the next of the week for the rest of the
/// day; 调整 changes the week. When the records say the baby is awake the header says so — 醒了 40 分钟 · 一起玩 — and
/// while a sleep is being timed, 醒来后一起玩: facts from the records, no predictions. Moss and Otto sit on the card's
/// top edge (not while the sleep card above already has them); at night Otto's lamp throws a warm pool over it.
struct TodayPlayCard: View {
    @Environment(AppModel.self) private var app
    @Environment(\.night) private var night
    @Environment(\.dynamicTypeSize) private var size
    @Environment(JournalStore.self) private var j
    let month: Int
    let arrange: () -> Void
    private var flat: Bool { ArtStyle.current == .flat }

    var body: some View {
        let week = app.weekShelf(month).plays
        let today = app.todayPlay(month, j)
        let rest = week.filter { $0.code != today?.code }
        let asleep = j.timers.contains { $0.type == LogType.sleep }
        if let p = today {
            let noticed: Int = (week.firstIndex(of: p) ?? 0) + week.count * 10
            TimelineView(.periodic(from: .now, by: 60)) { tl in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 8) {
                        GoldBead(size: 10)
                        Text(title(asleep: asleep, now: tl.date)).font(.title3.weight(.bold)).accessibilityAddTraits(.isHeader)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        if week.count > 1 {
                            Button { withAnimation(.snappy) { app.anotherToday(month, j) } } label: {
                                // the words stay small; the place to tap is a full 44 points (HIG: hit targets)
                                Text("换一个").padding(.horizontal, 8).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                            }
                            .font(.subheadline.weight(.semibold)).padding(.vertical, -12).padding(.trailing, -8)
                            .accessibilityHint("在这周的几个活动里换一个")
                        }
                    }
                    .padding(.horizontal, 4).padding(.top, 20)
                    VStack(spacing: 0) {
                        lead(p)
                        if !rest.isEmpty {
                            Divider().padding(.horizontal, 14)
                            HStack {
                                Text("这周还有").font(.footnote.weight(.semibold)).foregroundStyle(Palette.secondaryText).accessibilityAddTraits(.isHeader)
                                Spacer(minLength: 4)
                                Button(action: arrange) { Text("调整").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
                                    .font(.footnote.weight(.semibold)).padding(.vertical, -12)
                                    .accessibilityHint("换这周的活动")
                            }
                            .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 2)
                            ForEach(rest) { other($0) }
                        } else {
                            Button(action: arrange) { Text("调整这周的活动").font(.footnote.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44) }
                        }
                    }
                    .padding(.bottom, 4)
                    .background(alignment: .top) { if night { LampPool() } }
                    .printCard(radius: Radius.card)
                    .overlay(alignment: .topTrailing) {
                        // the two of them on the card's top edge; when today's play changes (换一个, a new week)
                        // Moss blinks twice and looks at it — the change said without a word. One pair to a screen:
                        // while the sleep card above has them, they are not here.
                        if !asleep {
                            Duo(primary: app.companion, size: 44, look: CGPoint(x: -0.6, y: 0.6), night: night, reacts: true,
                                notice: noticed)
                                .offset(x: -16, y: -40)
                        }
                    }
                    // room above the card for the pair on its edge; while they are on the sleep card, none
                    .padding(.top, asleep ? 0 : 30)
                }
            }
        }
    }

    /// 今天一起玩; 醒了 40 分钟 · 一起玩 while the records say the baby woke within six hours (by day, records on);
    /// 醒来后一起玩 while a sleep is being timed.
    private func title(asleep: Bool, now: Date) -> String {
        guard app.journal else { return "今天一起玩" }
        if asleep { return "醒来后一起玩" }
        if !night, let woke = j.logs.first(where: { $0.type == LogType.sleep && $0.end != nil })?.end {
            let s = (now.timeIntervalSince1970 * 1000 - woke) / 1000
            if s >= 0 && s < 6 * 3600 { return "醒了 " + durationValue(s) + " · 一起玩" }
        }
        return "今天一起玩"
    }

    private func route(_ p: Play) -> Route { Route.play(p.code, month) }

    /// Today's play: the picture of its first step, and what to know before starting.
    private func lead(_ p: Play) -> some View {
        let big = size.isAccessibilitySize
        let times: Int = app.thisWeek(p, j)
        let last: String = lastPlayed(p)
        let label: String = "今天一起玩，" + p.name + "，" + (p.domains.first ?? "") + "，\(p.steps.count) 步，" + last + (times > 0 ? "，这周玩过 \(times) 次" : "")
        let layout = big ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        return NavigationLink(value: route(p)) {
            layout {
                leadArt(p, big: big)
                leadWords(p, last: last, times: times, big: big)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.toy)
        .contextMenu { PlayActions(play: p, month: month) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityHint("打开，一步步跟着图玩")
    }

    private func lastPlayed(_ p: Play) -> String {
        let rec = app.record(p, j)
        // a play ticked done before plays were dated: played, but when is not known
        guard let d = rec.last else { return rec.count > 0 ? "玩过" : "第一次玩" }
        return Day(d) == app.today ? "今天玩过" : "上次 " + Day(d).md
    }

    @ViewBuilder private func leadArt(_ p: Play, big: Bool) -> some View {
        let key = Palette.areaKey(of: p)
        Group {
            if let art = ArtIndex.shared.steps(p.code).first {
                ArtView(name: art, radius: Radius.tile).aspectRatio(4 / 3, contentMode: .fit)
            } else {
                TrayTile(code: p.code, color: Palette.area(key), flat: flat)
            }
        }
        .frame(width: big ? 200 : 112, height: big ? 150 : 84)
        .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .zoomSource(route(p))
    }

    private func leadWords(_ p: Play, last: String, times: Int, big: Bool) -> some View {
        let key = Palette.areaKey(of: p)
        let area: String = (p.domains.first ?? "") + " · \(p.steps.count) 步"
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                IconTile(symbol: Palette.areaSymbol(key), color: Palette.area(key), size: 16)
                Text(area).font(.caption.weight(.semibold)).foregroundStyle(Palette.areaInk(key)).lineLimit(1)
            }
            Text(p.name).font(.headline).foregroundStyle(.primary)
                .lineLimit(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            if let step = p.steps.first {
                Text("第 1 步 · " + step).font(.caption).foregroundStyle(Palette.secondaryText)
                    .lineLimit(big ? 4 : 2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                Text(last).font(.caption2.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                if times > 0 { BeadCount(times: times) }
            }
            .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One of the week's others: its tray, its name, its beads this week (nothing while there are none).
    private func other(_ p: Play) -> some View {
        let key = Palette.areaKey(of: p), times = app.thisWeek(p, j)
        return NavigationLink(value: route(p)) {
            HStack(spacing: 12) {
                TrayTile(code: p.code, color: Palette.area(key), flat: flat)
                    .frame(width: 44, height: 33)
                    .zoomSource(route(p))
                Text(p.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                    .lineLimit(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if times > 0 { BeadCount(times: times) }
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.toy)
        .contextMenu { PlayActions(play: p, month: month) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(otherLabel(p, times))
    }
    private func otherLabel(_ p: Play, _ times: Int) -> String {
        let area: String = p.domains.first ?? ""
        return p.name + "，" + area + (times > 0 ? "，这周玩过 \(times) 次" : "")
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
        let shape = RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
        let dark = scheme == .dark
        ZStack {
            if flat {
                shape.fill(color.mix(with: dark ? Palette.lampCard : .white, by: dark ? 0.68 : 0.78))
                    .background(shape.fill(color.opacity(dark ? 0.35 : 0.3)).offset(y: 2))
            } else {
                shape.fill(LinearGradient(colors: [color.mix(with: dark ? Palette.lampCard : .white, by: dark ? 0.62 : 0.86), color.mix(with: dark ? Palette.lampCard : .white, by: dark ? 0.75 : 0.7)],
                                          startPoint: .top, endPoint: .bottom))
                    .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(dark ? 0.15 : 0.9), .white.opacity(0)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
            }
            Figure(name: "tray_\(code.lowercased()).webp").aspectRatio(4 / 3, contentMode: .fit).padding(4)
        }
        .accessibilityHidden(true)
    }
}

/// Times played, as gold beads on a short string (Montessori's golden bead): up to five, then the number.
private struct BeadCount: View {
    let times: Int
    var body: some View {
        HStack(spacing: 3) {
            if times > 0 {
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
    /// Asked the first time only: whether to keep the day's records too (the 记录 tab), so a parent of a newborn has
    /// the feeds, sleeps and nappies from the start rather than finding them later behind a switch.
    @State private var first = false
    @State private var records = true
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("出生日期", selection: $date, in: Calendar.current.date(byAdding: .year, value: -4, to: Date())!...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                if first {
                    Section {
                        Toggle("也记录喂奶、睡眠、尿布", isOn: $records)
                    } footer: { Text("打开后多一个「记录」页；以后在「我的」里随时可以开关。") }
                }
            }
            .navigationTitle("出生日期").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("完成", systemImage: "checkmark") { if first { app.journal = records }; app.birth = Day(date); dismiss() } }
            }
            .onAppear { if let b = app.birth { date = b.date }; first = !app.onboarded && app.birth == nil }
        }
        .presentationDetents([.large])
    }
}
