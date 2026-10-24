import SwiftUI

/// The journal (optional): what is running, one-tap buttons, the week, then the day — its totals, its time line and
/// every entry in order.
struct JournalView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Binding var path: NavigationPath
    /// A kind to show alone when the page opens (screenshots); the page's own chips change it.
    var only: String? = nil
    @State private var day: Day = .today
    @State private var editing: LogEntry?
    @State private var measuring: Measure?
    @Environment(\.dynamicTypeSize) private var size

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StickerSheet(timers: j.timers, last: { j.last($0) }, tap: tap)
                WeekStrip(today: app.today, day: $day)
                DayPage(day: day, today: app.today, logs: j.logs(on: day), timers: j.timers, edit: { editing = $0 }, delete: { j.delete($0) }, only: only)
                let pair = size.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
                pair {
                    NavigationLink(value: JournalRoute.stats) { tile("最近七天", "chart.bar.fill", Crayon.lilac) }.buttonStyle(.toy)
                    NavigationLink(value: JournalRoute.growth) { tile("生长曲线", "chart.line.uptrend.xyaxis", Crayon.tangerine) }.buttonStyle(.toy)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .pageBackground(tone: Crayon.pink)
        .navigationTitle("记录")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("补记", systemImage: "plus") { editing = LogEntry(type: LogType.bottle, start: defaultTime(), amount: 120) }
            }
        }
        .sheet(item: Binding(get: { j.ask.map { Wrap(id: $0) } }, set: { j.ask = $0?.id })) { w in AskSheet(type: w.id).lampPresented() }
        .sheet(item: $editing) { e in EntrySheet(entry: e, isNew: !j.logs.contains { $0.id == e.id }).lampPresented() }
        .sheet(item: $measuring) { m in MeasureSheet(measure: m, isNew: !j.measures.contains { $0.id == m.id }).lampPresented() }
        .onChange(of: app.today) { _, t in day = t }
        .onAppear { day = app.today }
    }

    private func tile(_ t: String, _ sym: String, _ c: Color) -> some View {
        HStack(spacing: 10) {
            IconTile(symbol: sym, color: c)
            Text(t).font(.body.weight(.semibold)).foregroundStyle(.primary)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(14).printCard(radius: 20)
    }

    private func tap(_ t: String) {
        if t == LogType.growth { measuring = Measure(at: Date().timeIntervalSince1970 * 1000); return }
        // a feed or a sleep has its own page: it opens, and starts only from there
        if LogType.timed.contains(t) { j.focus = t; return }
        // a bath is one tap: recorded now, said back with 撤销
        if t == LogType.bath { j.record(LogEntry(type: t, start: JournalFile.now())); return }
        j.ask = t
    }
    private func defaultTime() -> Double { day == app.today ? JournalFile.now() : day.date.addingTimeInterval(12 * 3600).timeIntervalSince1970 * 1000 }
}

enum JournalRoute: Hashable { case stats, growth }
struct Wrap: Identifiable { let id: String }

/// "刚刚", "25 分钟前", "1 小时 20 分前".
func ago(_ then: Date, _ now: Date = Date()) -> String {
    let m = Int(now.timeIntervalSince(then) / 60)
    if m < 2 { return "刚刚" }
    if m < 60 { return "\(m) 分钟前" }
    if m < 600 && m % 60 != 0 { return "\(m / 60) 小时 \(m % 60) 分前" }
    if m < 48 * 60 { return "\(m / 60) 小时前" }
    return "\(m / 1440) 天前"
}

/// "刚刚", "25 分前", "3 时前", "2 天前": always short, so every sticker reads the same.
func agoShort(_ then: Date, _ now: Date = Date()) -> String {
    let m = Int(now.timeIntervalSince(then) / 60)
    if m < 2 { return "刚刚" }
    if m < 60 { return "\(m) 分前" }
    if m < 48 * 60 { return "\(m / 60) 时前" }
    return "\(m / 1440) 天前"
}

/// The sheet of stickers: one round sticker per kind, stuck on with a print shadow; tap to record. How long ago the
/// last one was sits under each, always in the same short form.
private struct StickerSheet: View {
    let timers: [RunningTimer]
    let last: (String) -> Date?
    let tap: (String) -> Void
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { tl in
            Grid(horizontalSpacing: 4, verticalSpacing: 14) {
                ForEach(0..<2, id: \.self) { r in
                    GridRow {
                        ForEach(LogType.buttons[(r * 5)..<min(LogType.buttons.count, r * 5 + 5)], id: \.self) { t in
                            let run = timers.first { $0.type == t }
                            Sticker(type: t, running: run != nil,
                                    since: run.map { durationValue($0.total(tl.date.timeIntervalSince1970 * 1000)) } ?? last(t).map { agoShort($0, tl.date) }) { tap(t) }
                        }
                    }
                }
            }
            .padding(.vertical, 16).padding(.horizontal, 8)
            .printCard(radius: 26)
        }
        // five across must fit the narrowest phone: past the largest standard size the stickers stop growing and a
        // long press shows the large-content viewer instead
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

private struct Sticker: View {
    let type: String, running: Bool, since: String?
    let action: () -> Void
    var body: some View {
        let c = LogType.color(type)
        Button(action: action) {
            VStack(spacing: 4) {
                IconTile(symbol: LogType.symbol(type), color: c, size: 48, round: true)
                    .overlay(Circle().stroke(c.opacity(running ? 0.4 : 0), lineWidth: 4).padding(-5))
                Text(LogType.name(type)).font(.caption.weight(.semibold)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.7)
                Ticking(text: running ? (since ?? "进行中") : since ?? "—", tint: Crayon.ink(c)).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.toy)
        .sensoryFeedback(.impact(weight: .light), trigger: running)
        .accessibilityLabel(running ? "\(LogType.name(type))进行中，打开计时" : LogType.name(type))
        .accessibilityHint(running ? "" : LogType.timed.contains(type) ? "打开计时页" : type == LogType.bath ? "点按即记下一次" : "")
        .accessibilityValue(since ?? "")
        .accessibilityShowsLargeContentViewer { Label(LogType.name(type), systemImage: LogType.symbol(type)) }
    }
}

/// Seven days, as the tabs along a planner's edge.
private struct WeekStrip: View {
    @Environment(\.lamp) private var lamp
    let today: Day
    @Binding var day: Day
    var body: some View {
        let end = min(day.plus(days: 3), today)
        HStack(spacing: 6) {
            ForEach((0...6).reversed(), id: \.self) { i in
                let d = end.plus(days: -i), on = d == day, isToday = d == today
                Button { withAnimation(.snappy) { day = d } } label: {
                    VStack(spacing: 2) {
                        Text(String(d.weekday.suffix(1))).font(.caption2.weight(.semibold))
                        Text("\(d.d)").font(Typeface.numerals(17, relativeTo: .body, weight: .bold))
                    }
                    .foregroundStyle(on ? Color.white : isToday ? Crayon.ink(Crayon.pink) : Color.primary)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? AnyShapeStyle(LinearGradient(colors: [Crayon.fill(Crayon.pink, lamp).mix(with: Crayon.pink, by: lamp ? 0.06 : 0.15), Crayon.fill(Crayon.pink, lamp)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Palette.card)))
                    .shadow(color: on && !lamp ? Crayon.pink.opacity(0.35) : Color.black.opacity(lamp ? 0 : 0.06), radius: on ? 6 : 3, y: on ? 3 : 2)
                }
                .buttonStyle(.toy)
                .accessibilityLabel("\(d.md) \(d.weekday)")
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityShowsLargeContentViewer { Text("\(d.md) \(d.weekday)") }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)   // seven across must fit
    }
}

/// A page of the journal: dotted paper, the date written large, the day's three totals as stamps, the day's strip,
/// and every entry in fixed columns — time, sticker, kind, value — with the details on a second line.
private struct DayPage: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.lamp) private var lamp
    let day: Day, today: Day
    let logs: [LogEntry]
    let timers: [RunningTimer]
    let edit: (LogEntry) -> Void
    let delete: (LogEntry) -> Void
    /// One kind to look at alone ("feed" = breast and bottle together), or nil for the whole day.
    @State private var only: String?
    init(day: Day, today: Day, logs: [LogEntry], timers: [RunningTimer], edit: @escaping (LogEntry) -> Void, delete: @escaping (LogEntry) -> Void, only: String? = nil) {
        self.day = day; self.today = today; self.logs = logs; self.timers = timers; self.edit = edit; self.delete = delete
        _only = State(initialValue: only)
    }

    var body: some View {
        let shown = only.map { k in logs.filter { JournalKinds.matches($0.type, k) } } ?? logs
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Text("\(day.d)").font(Typeface.numerals(46, relativeTo: .largeTitle, weight: .bold))
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(day.m)月 \(day.weekday)").font(.headline)
                    Text(day == today ? "今天" : "\(today.epochDay - day.epochDay) 天前").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if lamp { Creature(kind: .otto, mood: .open, look: CGPoint(x: -0.6, y: 0.3), glow: true).frame(width: 52, height: 52) }
                else { Creature(kind: app.companion, mood: logs.isEmpty ? .open : .happy, alive: false).frame(width: 48, height: 48) }
            }
            // every number on the page is a way in: tap a total (or one of the other kinds) to see only that kind
            Totals(logs: logs, day: day, only: only) { k in withAnimation(.snappy) { only = only == k ? nil : k } }
            OtherKinds(logs: logs, only: only) { k in withAnimation(.snappy) { only = only == k ? nil : k } }
            if let k = only { FocusLine(kind: k, logs: shown, all: j.logs, day: day) { withAnimation(.snappy) { only = nil } } }
            DayRibbon(day: day, logs: logs, timers: timers, only: only)
            if day == today { ForEach(timers.filter { t in only.map { JournalKinds.matches(t.type, $0) } ?? true }, id: \.type) { t in RunningRow(timer: t) } }
            if logs.isEmpty && (day != today || timers.isEmpty) {
                VStack(spacing: 8) {
                    Duo(primary: lamp ? .otto : app.companion, size: 56, mood: lamp ? .open : .sleep, night: lamp)
                    Text("这一页还空着").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 12)
            } else if !logs.isEmpty {
                DayTimeline(day: day, today: today, logs: shown, all: j.logs, edit: edit, delete: delete, gaps: only == nil)
            }
        }
        .padding(18)
        .background { DotPaper() }
        .printCard(radius: 26)
        // the chosen kind stays when the day changes: flip through the week and compare feeds day by day
        .sensoryFeedback(.selection, trigger: only)
    }
}

/// The kinds a day can be looked at by: feeds (breast and bottle), sleep, nappies, and each other kind by itself.
enum JournalKinds {
    static func matches(_ type: String, _ key: String) -> Bool {
        key == "feed" ? (type == LogType.nurse || type == LogType.bottle) : type == key
    }
    static func name(_ key: String) -> String { key == "feed" ? "喂奶" : LogType.name(key) }
    static func type(_ key: String) -> String { key == "feed" ? LogType.nurse : key }
}

/// The other kinds recorded on the day, as small chips with their counts; tap one to see only it.
private struct OtherKinds: View {
    let logs: [LogEntry]
    let only: String?
    let pick: (String) -> Void
    var body: some View {
        let kinds = [LogType.solid, LogType.bath, LogType.temp, LogType.medicine, LogType.play, LogType.note].filter { t in logs.contains { $0.type == t } }
        if !kinds.isEmpty {
            WrapLayout(spacing: 8) {
                ForEach(kinds, id: \.self) { t in
                    let c = LogType.color(t), on = only == t, n = logs.filter { $0.type == t }.count
                    Button { pick(t) } label: {
                        HStack(spacing: 6) {
                            IconTile(symbol: LogType.symbol(t), color: c, size: 20, round: true)
                            Text(LogType.name(t)).font(.footnote.weight(.semibold))
                            Ticking(text: "\(n)").font(Typeface.numerals(13, relativeTo: .footnote, weight: .bold)).foregroundStyle(Crayon.ink(c))
                        }
                        .padding(.leading, 6).padding(.trailing, 10).padding(.vertical, 5)
                        .background(Capsule().fill(c.opacity(on ? 0.26 : 0.1)))
                        .overlay(Capsule().strokeBorder(on ? Crayon.ink(c) : .clear, lineWidth: 1.5))
                        .opacity(only == nil || on ? 1 : 0.5)
                    }
                    .buttonStyle(.toy)
                    .accessibilityLabel("\(LogType.name(t)) \(n) 次")
                    .accessibilityHint(on ? "显示全部" : "只看这一类")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }
}

/// While one kind is shown alone: what it adds up to that day, said in one line, and a way back to everything.
private struct FocusLine: View {
    let kind: String
    let logs: [LogEntry]
    let all: [LogEntry]
    let day: Day
    let clear: () -> Void
    var body: some View {
        let c = LogType.color(JournalKinds.type(kind))
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill").foregroundStyle(Crayon.ink(c))
            Text(summary).font(.footnote.weight(.semibold)).foregroundStyle(.primary).monospacedDigit()
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            Button("全部", action: clear).font(.footnote.weight(.bold)).buttonStyle(.bordered).buttonBorderShape(.capsule).tint(Crayon.ink(c))
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(c.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    /// Facts only, from the day's records: how many, and for feeds the usual gap between them; for sleep how many
    /// times and how long in all.
    private var summary: String {
        let d0 = day.date.timeIntervalSince1970 * 1000
        switch kind {
        case "feed":
            let starts = feedStarts().filter { $0 >= d0 }
            var s = "只看喂奶 · \(logs.feedCount(from: d0)) 次"
            if starts.count >= 2 {
                let gaps = zip(starts.dropFirst(), starts).map { ($0 - $1) / 1000 }
                s += " · 平均间隔 " + durationValue(gaps.reduce(0, +) / Double(gaps.count))
            }
            return s
        case LogType.sleep:
            let total = logs.reduce(0.0) { $0 + $1.seconds(on: day) }
            return "只看睡眠 · \(logs.count) 段 · 共 " + durationValue(total)
        case LogType.diaper:
            let wet = logs.filter { $0.detail == "wet" || $0.detail == "both" }.count, dirty = logs.filter { $0.detail == "dirty" || $0.detail == "both" }.count
            return "只看尿布 · \(logs.count) 片 · 湿 \(wet) · 便 \(dirty)"
        default:
            return "只看" + LogType.name(kind) + " · \(logs.count) 次"
        }
    }
    /// The start of each feed of the day (the second side of a breast feed is the same feed).
    private func feedStarts() -> [Double] {
        let feeds = logs.sorted { $0.start < $1.start }
        var out: [Double] = [], lastEnd: Double?
        for e in feeds {
            if e.type == LogType.nurse, let l = lastEnd, e.start - l <= 120_000 { lastEnd = e.end ?? e.start; continue }
            out.append(e.start); lastEnd = e.end ?? e.start
        }
        return out
    }
}

/// A feed or sleep still running, at the top of today's line: its start, how long so far; a tap opens its timer.
private struct RunningRow: View {
    @Environment(JournalStore.self) private var j
    let timer: RunningTimer
    var body: some View {
        let c = LogType.color(timer.type)
        Button { j.focus = timer.type } label: {
            TimelineView(.periodic(from: .now, by: 30)) { tl in
                HStack(spacing: 12) {
                    Text(hm(Date(timeIntervalSince1970: timer.start / 1000))).font(Typeface.numerals(16, relativeTo: .body, weight: .semibold))
                    IconTile(symbol: LogType.symbol(timer.type), color: c, size: 28, round: true)
                    Text(LogType.name(timer.type)).font(.body).fixedSize()
                    Spacer(minLength: 8)
                    Ticking(text: (timer.pausedAt != nil ? "已暂停 " : "进行中 ") + durationValue(timer.total(tl.date.timeIntervalSince1970 * 1000)), tint: Crayon.ink(c))
                        .font(Typeface.numerals(15, relativeTo: .body, weight: .semibold)).foregroundStyle(Crayon.ink(c))
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(c.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .buttonStyle(.toy)
        .accessibilityLabel("\(LogType.name(timer.type))进行中，打开计时")
    }
}

/// The day from midnight to midnight: feeds and sleeps as bars of their length, everything else as a dot.
private struct DayRibbon: View {
    let day: Day, logs: [LogEntry], timers: [RunningTimer]
    var only: String? = nil
    @Environment(\.lamp) private var lamp
    var body: some View {
        let d0 = day.date.timeIntervalSince1970 * 1000, span = 86_400_000.0
        TimelineView(.periodic(from: .now, by: 60)) { tl in
            let now = tl.date.timeIntervalSince1970 * 1000
            VStack(spacing: 6) {
                Canvas { ctx, size in paint(&ctx, size, d0: d0, span: span, now: now) }
                    .frame(height: 30)
                HStack { ForEach(["0:00", "6:00", "12:00", "18:00"], id: \.self) { Text($0).font(.caption2).foregroundStyle(.secondary).monospacedDigit().frame(maxWidth: .infinity, alignment: .leading) } }
            }
        }
        .accessibilityElement().accessibilityLabel("这一天的串珠：\(logs.count) 颗")
    }

    /// The day as a string of beads, like the Montessori bead chains: a cord from midnight to midnight, a bead for
    /// each entry in its colour, a long bead for each feed or sleep as long as it lasted, and the golden bead — Otto's —
    /// where the day has got to.
    /// The bead's colour: its kind's, or faded back when another kind is being looked at alone.
    private func shade(_ t: String) -> Color { only.map { JournalKinds.matches(t, $0) } ?? true ? LogType.color(t) : LogType.color(t).opacity(0.16) }
    private func paint(_ ctx: inout GraphicsContext, _ size: CGSize, d0: Double, span: Double, now: Double) {
        let w: CGFloat = size.width, mid: CGFloat = size.height / 2
        func x(_ t: Double) -> CGFloat { CGFloat(max(0, min(1, (t - d0) / span))) * w }
        var cord = Path(); cord.move(to: CGPoint(x: 0, y: mid)); cord.addLine(to: CGPoint(x: w, y: mid))
        ctx.stroke(cord, with: .color(Color.secondary.opacity(0.35)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        for hr in [6.0, 12, 18] {
            let hx = x(d0 + hr * 3_600_000)
            ctx.fill(Path(ellipseIn: CGRect(x: hx - 1.5, y: mid - 1.5, width: 3, height: 3)), with: .color(Color.secondary.opacity(0.5)))
        }
        func bead(_ r: CGRect, _ c: Color) {
            let p = Path(roundedRect: r, cornerRadius: r.height / 2)
            // flat beads, as the month's beads: colour and a soft darker rim, no gloss
            ctx.fill(p, with: .color(c))
            ctx.stroke(p, with: .color(c.mix(with: .black, by: 0.12)), lineWidth: 1)
        }
        let spans = logs.compactMap { e in e.end.map { (e.type, e.start, $0) } } + timers.map { ($0.type, $0.start, now) }
        for (t, a, b) in spans where b > d0 && a < d0 + span {
            let h: CGFloat = t == LogType.sleep ? 18 : 14
            bead(CGRect(x: x(a), y: mid - h / 2, width: max(h, x(b) - x(a)), height: h), shade(t))
        }
        for e in logs where e.end == nil {
            bead(CGRect(x: x(e.start) - 6, y: mid - 6, width: 12, height: 12), shade(e.type))
        }
        if now > d0 && now < d0 + span {
            let gx = x(now)
            if lamp { ctx.fill(Path(ellipseIn: CGRect(x: gx - 15, y: mid - 15, width: 30, height: 30)), with: .radialGradient(Gradient(colors: [Palette.amber.opacity(0.6), Palette.amber.opacity(0)]), center: CGPoint(x: gx, y: mid), startRadius: 2, endRadius: 15)) }
            bead(CGRect(x: gx - 8, y: mid - 8, width: 16, height: 16), lamp ? Palette.amber : Palette.bead)
        }
    }
}


/// The paper of the journal: a faint dot grid.
private struct DotPaper: View {
    var body: some View {
        Canvas { ctx, size in
            let g: CGFloat = 16
            var y: CGFloat = g
            while y < size.height {
                var x: CGFloat = g
                while x < size.width { ctx.fill(Path(ellipseIn: CGRect(x: x - 0.9, y: y - 0.9, width: 1.8, height: 1.8)), with: .color(Color.primary.opacity(0.1))); x += g }
                y += g
            }
        }
        .accessibilityHidden(true)
    }
}

/// The day's three totals, as stamps of equal width.
private struct Totals: View {
    let logs: [LogEntry]
    let day: Day
    var only: String? = nil
    var pick: (String) -> Void = { _ in }
    @Environment(\.dynamicTypeSize) private var size
    var body: some View {
        // counts are of what started on the day; sleep is the part of each sleep that falls on the day
        let own = logs.filter { !$0.carriedOver(into: day) }
        let feeds = logs.feedCount(from: day.date.timeIntervalSince1970 * 1000)
        let ml = own.filter { $0.type == LogType.bottle }.reduce(0) { $0 + ($1.amount ?? 0) }
        let sleep = logs.filter { $0.type == LogType.sleep }.reduce(0.0) { $0 + $1.seconds(on: day) }
        let nappies = own.filter { $0.type == LogType.diaper }
        let wet = nappies.filter { $0.detail == "wet" || $0.detail == "both" }.count
        let dirty = nappies.filter { $0.detail == "dirty" || $0.detail == "both" }.count
        let longest = logs.filter { $0.type == LogType.sleep && $0.end != nil }.map { $0.seconds(on: day) }.max() ?? 0
        // three across; at the largest text sizes, one under the other so nothing breaks a word
        let layout = size.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
        layout {
            tap("feed", stamp(LogType.nurse, "喂奶", [("\(feeds)", "次")], ml > 0 ? "瓶喂 \(ml) 毫升" : " "))
            tap(LogType.sleep, stamp(LogType.sleep, "睡眠", durationParts(sleep), longest >= 60 ? "最长一觉 " + durationValue(longest) : " "))
            // what a doctor asks: how many wet, how many dirty
            tap(LogType.diaper, stamp(LogType.diaper, "尿布", [("\(nappies.count)", "片")], nappies.isEmpty ? " " : "湿 \(wet) · 便 \(dirty)"))
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    /// A total as a button: tap to see only that kind on the day's string and line; the chosen one is ringed, the
    /// others step back.
    private func tap<V: View>(_ key: String, _ v: V) -> some View {
        let on = only == key, c = LogType.color(JournalKinds.type(key))
        return Button { pick(key) } label: {
            v.overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? Crayon.ink(c) : .clear, lineWidth: 2))
                .opacity(only == nil || on ? 1 : 0.45)
                .scaleEffect(on ? 1.02 : 1)
        }
        .buttonStyle(.toy)
        .accessibilityHint(on ? "显示全部" : "只看这一类")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
    private func stamp(_ t: String, _ name: String, _ parts: [(String, String)], _ sub: String) -> some View {
        let c = LogType.color(t)
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                IconTile(symbol: LogType.symbol(t), color: c, size: 18, round: true)
                Text(name).font(.caption.weight(.semibold)).foregroundStyle(Crayon.ink(c))
            }
            // numbers large, units small: "8 小时 5 分" fits a third of the width
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, p in
                    Ticking(text: p.0, tint: Crayon.ink(c)).font(Typeface.numerals(24, relativeTo: .title2, weight: .bold))
                    Text(p.1).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            .lineLimit(1).minimumScaleFactor(0.7)
            Text(sub).font(.caption2).foregroundStyle(.secondary).lineLimit(size.isAccessibilitySize ? nil : 1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(c.opacity(0.12)))   // a solid chip: dashes mean an empty slot
        .accessibilityElement(children: .combine)
    }
}

/// A length of time as number–unit pairs, for a large number with a small unit: [("8", "小时"), ("5", "分")].
func durationParts(_ seconds: Double) -> [(String, String)] {
    let m = Int((max(0, seconds) / 60).rounded())
    if m < 60 { return [("\(m)", "分钟")] }
    if m >= 48 * 60 { let h = m / 60; return h % 24 == 0 ? [("\(h / 24)", "天")] : [("\(h / 24)", "天"), ("\(h % 24)", "小时")] }
    return m % 60 == 0 ? [("\(m / 60)", "小时")] : [("\(m / 60)", "小时"), ("\(m % 60)", "分")]
}

/// A length of time, rounded to the minute, in the one form used everywhere (minutesOf).
func durationValue(_ seconds: Double) -> String { minutesOf((max(0, seconds) / 60).rounded() * 60) }

extension LogEntry {
    /// The value, right-aligned in its column: an amount, a length of time (the part on this day), a temperature, the
    /// kind of nappy.
    func value(on day: Day) -> String {
        switch type {
        case LogType.nurse, LogType.sleep: return end == nil ? "进行中" : durationValue(seconds(on: day))
        case LogType.bottle: return "\(amount ?? 0) 毫升"
        case LogType.temp: return amount.map { String(format: "%.1f °C", Double($0) / 10) } ?? ""
        case LogType.diaper: return ["wet": "湿", "dirty": "便", "both": "湿 + 便"][detail ?? ""] ?? ""
        default: return ""
        }
    }
    /// The details, on the second line, without repeating the start time shown in the first column: the side, when it
    /// ended (or began, if the day before), the whole length when it crosses midnight, what was eaten or noted.
    func meta(on day: Day, endShown: Bool = false) -> String {
        var bits: [String] = []
        if type == LogType.nurse, let s = side { bits.append(s == "l" ? "左侧" : "右侧") }
        if let m = milk { bits.append(m) }
        if let e = endDate {
            let endsLater = Day(e) > day
            if carriedOver(into: day) { bits.append("接昨天 \(hm(startDate)) · 到 \(hm(e))") }
            else if !endShown || endsLater { bits.append("到 " + (endsLater ? "次日 " : "") + hm(e)) }
            if carriedOver(into: day) || endsLater { bits.append("共 " + durationValue(activeSeconds)) }
            if pausedSeconds >= 60 { bits.append("暂停 " + durationValue(pausedSeconds)) }
        }
        if [LogType.solid, LogType.medicine, LogType.note, LogType.play].contains(type), let d = detail, !d.isEmpty {
            bits.append(type == LogType.play ? String(d.drop { $0 != " " }.dropFirst()) : d)
        }
        return bits.joined(separator: " · ")
    }
}

/// The day's entries on a time line, newest at the top: the clock time in the left column with how long ago under it
/// (today), a rail in the kind's colour — a feed or a sleep drawn as a bar as long as it lasted, everything else as a
/// bead — and, where the day was quiet for a while, the gap written on the rail.
private struct DayTimeline: View {
    let day: Day, today: Day
    let logs: [LogEntry]
    /// Every entry, for intervals that reach back to the day before.
    var all: [LogEntry] = []
    let edit: (LogEntry) -> Void
    let delete: (LogEntry) -> Void
    /// Quiet stretches are written only on the whole day; one kind alone shows its own intervals instead.
    var gaps = true
    @ScaledMetric private var timeWidth: CGFloat = 54

    var body: some View {
        let d0 = day.date.timeIntervalSince1970 * 1000
        let sorted = logs.sorted { max($0.start, d0) > max($1.start, d0) }
        // the latest moment anything older had reached: a quiet stretch is measured from there, not from the entry
        // just below (a long sleep can outlast a nappy changed during it)
        let reached: [Double] = {
            var out = Array(repeating: 0.0, count: sorted.count), m = -Double.infinity
            for i in sorted.indices.reversed() { m = Swift.max(m, sorted[i].end ?? sorted[i].start); out[i] = m }
            return out
        }()
        TimelineView(.periodic(from: .now, by: 60)) { tl in
            VStack(spacing: 0) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { i, e in
                    if i > 0 {
                        // a quiet stretch: only when nothing at all happened for a long while (3 hours or more);
                        // between two feeds the row itself says how long since the last one
                        let newer = sorted[i - 1]
                        let gap = (max(newer.start, d0) - reached[i]) / 1000
                        if gaps && gap >= 3 * 3600 { GapRow(seconds: gap, timeWidth: timeWidth) }
                    }
                    TimelineRow(entry: e, day: day, isToday: day == today, now: tl.date, timeWidth: timeWidth, since: feedInterval(e))
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                        .contentShape(Rectangle())
                        .onTapGesture { edit(e) }
                        .contextMenu {
                            Button("修改", systemImage: "pencil") { edit(e) }
                            Button("删除", systemImage: "trash", role: .destructive) { delete(e) }
                        }
                }
            }
        }
    }
}

extension DayTimeline {
    /// For a feed (a breast feed's first side, or a bottle): the time since the previous feed began, from all the
    /// records (the previous feed may be on the day before). The second side of the same feed gets none.
    func feedInterval(_ e: LogEntry) -> Double? {
        guard e.type == LogType.nurse || e.type == LogType.bottle else { return nil }
        let feeds = all.filter { $0.type == LogType.nurse || $0.type == LogType.bottle }.sorted { $0.start < $1.start }
        guard let i = feeds.firstIndex(where: { $0.id == e.id }), i > 0 else { return nil }
        // a side that continues the feed before it is not a new feed
        if e.type == LogType.nurse, let p = feeds[..<i].last, p.type == LogType.nurse, let pe = p.end, e.start - pe <= 120_000 { return nil }
        // the start of the previous feed: walk back over its sides
        var k = i - 1
        while k > 0, feeds[k].type == LogType.nurse, feeds[k - 1].type == LogType.nurse, let pe = feeds[k - 1].end, feeds[k].start - pe <= 120_000 { k -= 1 }
        return (e.start - feeds[k].start) / 1000
    }
}

/// A quiet stretch between two entries, written on a dashed rail.
private struct GapRow: View {
    let seconds: Double
    let timeWidth: CGFloat
    var body: some View {
        HStack(spacing: 12) {
            Color.clear.frame(width: timeWidth, height: 1)
            Line().stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 5]))
                .frame(width: 28, height: 28)
            Text("相隔 " + durationValue(seconds)).font(.caption.weight(.medium)).foregroundStyle(.secondary).monospacedDigit()
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
    private struct Line: Shape { func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY)); return p } }
}

/// One entry on the time line.
private struct TimelineRow: View {
    let entry: LogEntry
    let day: Day
    let isToday: Bool
    let now: Date
    let timeWidth: CGFloat
    /// For a feed: how long since the feed before it began (start to start, as a feeding interval is counted).
    var since: Double? = nil

    var body: some View {
        let c = LogType.color(entry.type)
        let span = entry.end != nil ? entry.seconds(on: day) : 0
        // a bar grows with the length: 1 pt for every 3 minutes, between 0 and 90 pt beyond the sticker
        let bar = entry.end != nil ? CGFloat(min(90, span / 180)) : 0
        let meta = [entry.meta(on: day, endShown: bar > 24), since.map { "距上一顿 " + durationValue($0) }].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.carriedOver(into: day) ? "0:00" : hm(entry.startDate)).font(Typeface.numerals(16, relativeTo: .body, weight: .semibold))
                if let e = entry.endDate, bar > 24 {
                    Spacer(minLength: 0)
                    Text(Day(e) > day ? "24:00" : hm(e)).font(Typeface.numerals(13, relativeTo: .footnote, weight: .medium)).foregroundStyle(.secondary)
                } else if isToday {
                    Text(agoShort(entry.endDate ?? entry.startDate, now)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: timeWidth, height: bar > 24 ? 24 + bar : nil, alignment: .topLeading)
            VStack(spacing: 0) {
                IconTile(symbol: LogType.symbol(entry.type), color: c, size: 28, round: true)
                if entry.end != nil {
                    Capsule().fill(LinearGradient(colors: [c.mix(with: .white, by: 0.3), c], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 8, height: max(6, bar)).padding(.top, -4)
                        .overlay(Capsule().fill(.white.opacity(0.45)).frame(width: 2).padding(.vertical, 3).offset(x: -1.5))
                }
            }
            .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(LogType.name(entry.type)).font(.body)
                    Spacer(minLength: 8)
                    Text(entry.value(on: day)).font(Typeface.numerals(16, relativeTo: .body, weight: .semibold)).fixedSize()
                }
                if !meta.isEmpty { Text(meta).font(.footnote).foregroundStyle(.secondary).monospacedDigit().lineLimit(2) }
            }
            .padding(.top, 3)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

/// The running timer, small, above the tab bar on every tab; tap to open it. Only pause sits here: ending is done on
/// the timer screen, in its own band, never a few points from pause (a mis-tap would end a feed).
struct TimerAccessory: View {
    @Environment(JournalStore.self) private var j
    let timer: RunningTimer
    var body: some View {
        let c = LogType.color(timer.type)
        HStack(spacing: 12) {
            Button { j.focus = timer.type } label: {
                HStack(spacing: 12) {
                    IconTile(symbol: LogType.symbol(timer.type), color: c, size: 30, round: true)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(LogType.name(timer.type) + (timer.side == "l" ? " · 左侧" : timer.side == "r" ? " · 右侧" : "")).font(.footnote.weight(.semibold))
                        TimelineView(.periodic(from: .now, by: 1)) { tl in
                            Ticking(text: clock(timer.total(tl.date.timeIntervalSince1970 * 1000)), tint: Crayon.ink(c)).font(Typeface.numerals(13, relativeTo: .footnote)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.toy)
            .accessibilityLabel("打开\(LogType.name(timer.type))计时")
            Button { j.togglePause(timer.type) } label: { Image(systemName: timer.pausedAt == nil ? "pause.fill" : "play.fill") }
                .accessibilityLabel(timer.pausedAt == nil ? "暂停" : "继续")
        }
        .font(.body)
        .padding(.horizontal, 14)
        .tint(.primary)
    }
}

/// "今天 14:05" / "昨天 23:40" / "10月20日 08:15" — the whole time, never shortened.
func whenLabel(_ d: Date) -> String {
    let day = Day(d), today = Day.today
    let name = day == today ? "今天" : day == today.plus(days: -1) ? "昨天" : day == today.plus(days: -2) ? "前天" : day.md
    return "\(name) \(hm(d))"
}

/// An exact day and minute, never later than now.
struct TimeSheet: View {
    let title: String
    let initial: Date
    var notBefore: Date? = nil
    let pick: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(title, selection: $date, in: (notBefore ?? Date.distantPast)...Date(), displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                } footer: { Text(whenLabel(date)).font(.headline).monospacedDigit() }
            }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("完成", systemImage: "checkmark") { pick(date); dismiss() } }
            }
        }
        .onAppear { date = initial }
        .presentationDetents([.large])
    }
}
