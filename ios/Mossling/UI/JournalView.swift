import SwiftUI

/// The journal (optional): what is running, one-tap buttons, the week, then the day — its totals, its time line and
/// every entry in order.
struct JournalView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Binding var path: NavigationPath
    @State private var day: Day = .today
    @State private var ask: String?
    @State private var editing: LogEntry?
    @State private var measuring: Measure?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StickerSheet(running: Set(j.timers.map(\.type)), last: { j.last($0) }, tap: tap)
                WeekStrip(today: app.today, day: $day)
                DayPage(day: day, today: app.today, logs: j.logs(on: day), timers: j.timers, edit: { editing = $0 }, delete: { j.delete($0) })
                HStack(spacing: 12) {
                    NavigationLink(value: JournalRoute.stats) { tile("最近七天", "chart.bar.fill", Crayon.lilac) }.buttonStyle(.toy)
                    NavigationLink(value: JournalRoute.growth) { tile("生长曲线", "chart.line.uptrend.xyaxis", Crayon.tangerine) }.buttonStyle(.toy)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle("记录")
        .navigationSubtitle(day == app.today ? "今天 · \(day.md)" : "\(day.md) · \(day.weekday)")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("补记", systemImage: "plus") { editing = LogEntry(type: LogType.bottle, start: defaultTime(), amount: 120) }
            }
        }
        .sheet(item: Binding(get: { ask.map { Wrap(id: $0) } }, set: { ask = $0?.id })) { w in AskSheet(type: w.id) }
        .sheet(item: $editing) { e in EntrySheet(entry: e, isNew: !j.logs.contains { $0.id == e.id }) }
        .sheet(item: $measuring) { m in MeasureSheet(measure: m, isNew: !j.measures.contains { $0.id == m.id }) }
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
        if j.timers.contains(where: { $0.type == t }) { j.focus = t; return }
        if t == LogType.bath { j.add(LogEntry(type: t, start: JournalFile.now())); return }
        ask = t
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
    if m < 600 && m % 60 != 0 { return "\(m / 60) 时 \(m % 60) 分前" }
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
    let running: Set<String>
    let last: (String) -> Date?
    let tap: (String) -> Void
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { tl in
            Grid(horizontalSpacing: 4, verticalSpacing: 14) {
                ForEach(0..<2, id: \.self) { r in
                    GridRow {
                        ForEach(LogType.buttons[(r * 5)..<min(LogType.buttons.count, r * 5 + 5)], id: \.self) { t in
                            Sticker(type: t, running: running.contains(t), since: last(t).map { agoShort($0, tl.date) }) { tap(t) }
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
                IconTile(symbol: running ? "stop.fill" : LogType.symbol(type), color: c, size: 48, round: true)
                    .overlay(Circle().stroke(c.opacity(running ? 0.4 : 0), lineWidth: 4).padding(-5))
                Text(running ? "结束" : LogType.name(type)).font(.caption.weight(.semibold)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.7)
                Text(running ? "进行中" : since ?? "—").font(.caption2).foregroundStyle(.secondary).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.toy)
        .sensoryFeedback(.impact(weight: .light), trigger: running)
        .accessibilityLabel(running ? "\(LogType.name(type))进行中，结束" : LogType.name(type))
        .accessibilityValue(since ?? "")
        .accessibilityShowsLargeContentViewer { Label(LogType.name(type), systemImage: LogType.symbol(type)) }
    }
}

/// Seven days, as the tabs along a planner's edge.
private struct WeekStrip: View {
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
                    .foregroundStyle(on ? Color.white : isToday ? Crayon.pink : Color.primary)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? AnyShapeStyle(LinearGradient(colors: [Crayon.pink.mix(with: .white, by: 0.2), Crayon.pink], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Palette.card)))
                    .shadow(color: on ? Crayon.pink.opacity(0.35) : Color.black.opacity(0.06), radius: on ? 6 : 3, y: on ? 3 : 2)
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
    let day: Day, today: Day
    let logs: [LogEntry]
    let timers: [RunningTimer]
    let edit: (LogEntry) -> Void
    let delete: (LogEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Text("\(day.d)").font(Typeface.numerals(46, relativeTo: .largeTitle, weight: .bold))
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(day.m)月 \(day.weekday)").font(.headline)
                    Text(day == today ? "今天" : "\(today.epochDay - day.epochDay) 天前").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Creature(kind: app.companion, mood: logs.isEmpty ? .open : .happy, alive: false).frame(width: 48, height: 48)
            }
            Totals(logs: logs, day: day)
            DayRibbon(day: day, logs: logs, timers: timers)
            if logs.isEmpty {
                Text("这一页还空着").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 12)
            } else {
                DayTimeline(day: day, today: today, logs: logs, edit: edit, delete: delete)
            }
        }
        .padding(18)
        .background { DotPaper() }
        .printCard(radius: 26)
    }
}

/// The day from midnight to midnight: feeds and sleeps as bars of their length, everything else as a dot.
private struct DayRibbon: View {
    let day: Day, logs: [LogEntry], timers: [RunningTimer]
    var body: some View {
        let d0 = day.date.timeIntervalSince1970 * 1000, span = 86_400_000.0
        TimelineView(.periodic(from: .now, by: 60)) { tl in
            let now = tl.date.timeIntervalSince1970 * 1000
            VStack(spacing: 6) {
                Canvas { ctx, size in
                    let h = size.height
                    ctx.fill(Path(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: h), cornerRadius: h / 2), with: .color(Palette.fill))
                    func x(_ t: Double) -> CGFloat { CGFloat(max(0, min(1, (t - d0) / span))) * size.width }
                    for hr in [6.0, 12, 18] { ctx.fill(Path(CGRect(x: x(d0 + hr * 3_600_000), y: 4, width: 1, height: h - 8)), with: .color(Palette.outline)) }
                    let blocks = logs.compactMap { e in e.end.map { (e.type, e.start, $0) } } + timers.map { ($0.type, $0.start, now) }
                    for (t, a, b) in blocks where b > d0 && a < d0 + span {
                        let r = CGRect(x: x(a), y: 3, width: max(6, x(b) - x(a)), height: h - 6)
                        ctx.fill(Path(roundedRect: r, cornerRadius: (h - 6) / 2), with: .color(LogType.color(t)))
                    }
                    for e in logs where e.end == nil {
                        ctx.fill(Path(ellipseIn: CGRect(x: x(e.start) - 4, y: h / 2 - 4, width: 8, height: 8)), with: .color(LogType.color(e.type)))
                    }
                    if now > d0 && now < d0 + span { ctx.fill(Path(roundedRect: CGRect(x: x(now) - 1, y: 0, width: 2, height: h), cornerRadius: 1), with: .color(.primary)) }
                }
                .frame(height: 26)
                HStack { ForEach(["0:00", "6:00", "12:00", "18:00"], id: \.self) { Text($0).font(.caption2).foregroundStyle(.secondary).monospacedDigit().frame(maxWidth: .infinity, alignment: .leading) } }
            }
        }
        .accessibilityElement().accessibilityLabel("这一天的时间条：\(logs.count) 条记录")
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
    var body: some View {
        // counts are of what started on the day; sleep is the part of each sleep that falls on the day
        let own = logs.filter { !$0.carriedOver(into: day) }
        let feeds = logs.feedCount(from: day.date.timeIntervalSince1970 * 1000)
        let ml = own.filter { $0.type == LogType.bottle }.reduce(0) { $0 + ($1.amount ?? 0) }
        let sleep = logs.filter { $0.type == LogType.sleep }.reduce(0.0) { $0 + $1.seconds(on: day) }
        let diapers = own.filter { $0.type == LogType.diaper }.count
        HStack(spacing: 10) {
            stamp(LogType.nurse, "喂奶", "\(feeds)", "次", ml > 0 ? "瓶喂 \(ml) 毫升" : " ")
            stamp(LogType.sleep, "睡眠", durationValue(sleep), "", " ")
            stamp(LogType.diaper, "尿布", "\(diapers)", "片", " ")
        }
    }
    private func stamp(_ t: String, _ name: String, _ n: String, _ unit: String, _ sub: String) -> some View {
        let c = LogType.color(t)
        return VStack(alignment: .leading, spacing: 2) {
            Label(name, systemImage: LogType.symbol(t)).font(.caption.weight(.semibold)).foregroundStyle(c)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(n).font(Typeface.numerals(24, relativeTo: .title2, weight: .bold))
                if !unit.isEmpty { Text(unit).font(.caption.weight(.semibold)).foregroundStyle(.secondary) }
            }
            .lineLimit(1).minimumScaleFactor(0.7)
            Text(sub).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(c.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
        .accessibilityElement(children: .combine)
    }
}

/// "18 分", "1 时 05 分": one form for every length of time.
func durationValue(_ seconds: Double) -> String {
    let m = Int((max(0, seconds) / 60).rounded())
    return m >= 60 ? String(format: "%d 时 %02d 分", m / 60, m % 60) : "\(m) 分"
}

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
    func meta(on day: Day) -> String {
        var bits: [String] = []
        if type == LogType.nurse, let s = side { bits.append(s == "l" ? "左侧" : "右侧") }
        if let e = endDate {
            let endsLater = Day(e) > day
            if carriedOver(into: day) { bits.append("接昨天 \(hm(startDate)) · 到 \(hm(e))") }
            else { bits.append("到 " + (endsLater ? "次日 " : "") + hm(e)) }
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
    let edit: (LogEntry) -> Void
    let delete: (LogEntry) -> Void
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
                        let newer = sorted[i - 1]
                        let gap = (max(newer.start, d0) - reached[i]) / 1000
                        if gap >= 30 * 60 { GapRow(seconds: gap, timeWidth: timeWidth) }
                    }
                    TimelineRow(entry: e, day: day, isToday: day == today, now: tl.date, timeWidth: timeWidth)
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

    var body: some View {
        let c = LogType.color(entry.type)
        let span = entry.end != nil ? entry.seconds(on: day) : 0
        // a bar grows with the length: 1 pt for every 3 minutes, between 0 and 90 pt beyond the sticker
        let bar = entry.end != nil ? CGFloat(min(90, span / 180)) : 0
        let meta = entry.meta(on: day)
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

/// A feed or a sleep in progress, on its own screen: a dial like a toy clock — sixty beads round the edge, filling
/// minute by minute — with the time running in the middle; for a feed, the two sides as two big buttons; pause and
/// end; when it began, which can be moved earlier. The companions keep watch (asleep, for a sleep).
struct TimerScreen: View {
    @Environment(JournalStore.self) private var j
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let type: String
    @State private var picking = false

    var body: some View {
        let c = LogType.color(type)
        NavigationStack {
            if let t = j.timers.first(where: { $0.type == type }) {
                let paused = t.pausedAt != nil
                VStack(spacing: 22) {
                    TimelineView(.periodic(from: .now, by: 1)) { tl in
                        let secs = t.elapsed(tl.date.timeIntervalSince1970 * 1000)
                        ZStack {
                            Dial(seconds: secs, color: c)
                            VStack(spacing: 4) {
                                Text(clock(secs)).font(Typeface.numerals(54, relativeTo: .largeTitle, weight: .bold)).monospacedDigit()
                                    .contentTransition(.numericText()).foregroundStyle(paused ? Color.secondary : Color.primary)
                                Text(paused ? "已暂停" : (secs >= 3600 ? "\(Int(secs) / 3600) 小时以上" : "进行中"))
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(c)
                            }
                        }
                        .frame(maxWidth: 300).aspectRatio(1, contentMode: .fit)
                        .accessibilityElement(children: .combine)
                    }
                    .padding(.top, 8)

                    Button { picking = true } label: {
                        Label("开始于 " + whenLabel(Date(timeIntervalSince1970: t.start / 1000)), systemImage: "clock").monospacedDigit()
                    }
                    .buttonStyle(.glass)

                    if type == LogType.nurse {
                        HStack(spacing: 14) {
                            ForEach([("l", "L", "左侧"), ("r", "R", "右侧")], id: \.0) { k, big, name in
                                let on = (t.side ?? "l") == k
                                Button { if !on { withAnimation(.snappy) { j.switchSide(type) } } } label: {
                                    VStack(spacing: 2) {
                                        Text(big).font(Typeface.numerals(30, weight: .bold))
                                        Text(name).font(.caption.weight(.semibold))
                                        TimelineView(.periodic(from: .now, by: 1)) { tl in
                                            let done = j.logs.feedSides(before: t.start)[k] ?? 0
                                            let now = on ? t.elapsed(tl.date.timeIntervalSince1970 * 1000) : 0
                                            Text(done + now > 0 ? clock(done + now) : "—").font(Typeface.numerals(13, weight: .semibold)).monospacedDigit().opacity(0.85)
                                        }
                                    }
                                    .foregroundStyle(on ? .white : c)
                                    .frame(maxWidth: .infinity, minHeight: 86)
                                    .background {
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .fill(on ? AnyShapeStyle(LinearGradient(colors: [c.mix(with: .white, by: 0.25), c], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(c.opacity(0.12)))
                                    }
                                    .shadow(color: on ? c.opacity(0.35) : .clear, radius: 8, y: 4)
                                }
                                .buttonStyle(.toy)
                                .accessibilityAddTraits(on ? .isSelected : [])
                                .sensoryFeedback(.selection, trigger: on)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Duo(primary: app.companion, size: 70, mood: type == LogType.sleep && !paused ? .sleep : .open, look: CGPoint(x: 0, y: -0.6), poke: false)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    ZStack {
                        Palette.background
                        RadialGradient(colors: [c.opacity(0.28), c.opacity(0)], center: .top, startRadius: 0, endRadius: 520)
                    }
                    .ignoresSafeArea()
                }
                .navigationTitle(LogType.name(type))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("收起", systemImage: "chevron.down") { dismiss() } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("提前 5 分钟", systemImage: "gobackward.5") { j.shift(type, to: Date(timeIntervalSince1970: t.start / 1000 - 300)) }
                            Button("提前 15 分钟", systemImage: "gobackward.15") { j.shift(type, to: Date(timeIntervalSince1970: t.start / 1000 - 900)) }
                            Divider()
                            Button("不记这一次", systemImage: "xmark", role: .destructive) { j.discard(type); dismiss() }
                        } label: { Image(systemName: "ellipsis") }.accessibilityLabel("更多")
                    }
                }
                .safeAreaBar(edge: .bottom) {
                    HStack(spacing: 14) {
                        Button { withAnimation(.snappy) { j.togglePause(type) } } label: {
                            Image(systemName: paused ? "play.fill" : "pause.fill").font(.title2).frame(width: 44, height: 44)
                        }
                        .buttonStyle(.glass).controlSize(.large).accessibilityLabel(paused ? "继续" : "暂停")
                        Button { j.stop(type); dismiss() } label: {
                            Label("结束并记下", systemImage: "stop.fill").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        .buttonStyle(.glassProminent).tint(c).controlSize(.large)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 8)
                }
                .sheet(isPresented: $picking) {
                    TimeSheet(title: "开始时间", initial: Date(timeIntervalSince1970: t.start / 1000)) { j.shift(type, to: $0) }
                }
            } else {
                Color.clear.onAppear { dismiss() }
            }
        }
    }
}

/// The dial: sixty beads round a circle, one per minute; those already passed this hour are full and coloured, the
/// current one glows; whole hours show as a gold bead at the top.
private struct Dial: View {
    let seconds: Double
    let color: Color

    private func paint(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let r: CGFloat = min(size.width, size.height) / 2 - 12
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let minutes: Int = Int(seconds / 60)
        let inHour: Int = minutes % 60, hours: Int = minutes / 60
        let lit = Gradient(colors: [color.mix(with: .white, by: 0.45), color])
        for i in 0..<60 {
            let a: CGFloat = CGFloat(i) / 60 * 2 * .pi - .pi / 2
            let px: CGFloat = c.x + cos(a) * r, py: CGFloat = c.y + sin(a) * r
            let d: CGFloat = (i % 5 == 0 ? 11 : 8) + (i <= inHour ? 3 : 0)
            let rect = CGRect(x: px - d / 2, y: py - d / 2, width: d, height: d)
            if i <= inHour {
                let hi = CGPoint(x: rect.minX + d * 0.35, y: rect.minY + d * 0.3)
                ctx.fill(Path(ellipseIn: rect), with: .radialGradient(lit, center: hi, startRadius: 0, endRadius: d))
                if i == inHour { ctx.stroke(Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)), with: .color(color.opacity(0.4)), lineWidth: 2) }
            } else {
                ctx.fill(Path(ellipseIn: rect.insetBy(dx: 1.5, dy: 1.5)), with: .color(color.opacity(0.12)))
            }
        }
        let shown: Int = min(hours, 6)
        let gold = Gradient(colors: [Palette.beadLight, Palette.bead])
        for h in 0..<shown {
            let x: CGFloat = c.x - CGFloat(shown - 1) * 9 + CGFloat(h) * 18
            let rect = CGRect(x: x - 7, y: c.y - r * 0.62 - 7, width: 14, height: 14)
            ctx.fill(Path(ellipseIn: rect), with: .radialGradient(gold, center: CGPoint(x: rect.minX + 5, y: rect.minY + 4), startRadius: 0, endRadius: 12))
        }
    }
    var body: some View {
        Canvas { ctx, size in paint(&ctx, size) }
        .accessibilityHidden(true)
    }
}

/// The running timer, small, above the tab bar on every tab; tap to open it.
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
                            Text(clock(timer.elapsed(tl.date.timeIntervalSince1970 * 1000))).font(Typeface.numerals(13, relativeTo: .footnote)).foregroundStyle(.secondary)
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
            Button { j.stop(timer.type) } label: { Image(systemName: "stop.fill") }.accessibilityLabel("结束")
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
