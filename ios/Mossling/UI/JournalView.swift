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
                ForEach(j.timers, id: \.type) { TimerCard(timer: $0) }
                StickerSheet(running: Set(j.timers.map(\.type)), last: { j.last($0) }, tap: tap)
                WeekStrip(today: app.today, day: $day)
                DayPage(day: day, today: app.today, logs: j.logs(on: day), timers: j.timers, edit: { editing = $0 }, delete: { j.delete($0) })
                HStack(spacing: 12) {
                    NavigationLink(value: JournalRoute.stats) { tile("最近七天", "chart.bar.fill", Crayon.lilac) }.buttonStyle(.plain)
                    NavigationLink(value: JournalRoute.growth) { tile("生长曲线", "chart.line.uptrend.xyaxis", Crayon.tangerine) }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle("手帐")
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
        if j.timers.contains(where: { $0.type == t }) { j.stop(t); return }
        if t == LogType.sleep { j.start(t); return }
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
                Text(running ? "结束" : LogType.name(type)).font(.caption.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                Text(running ? "进行中" : since ?? "—").font(.caption2).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: running)
        .accessibilityLabel(running ? "\(LogType.name(type))进行中，结束" : LogType.name(type))
        .accessibilityValue(since ?? "")
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
                .buttonStyle(.plain)
                .accessibilityLabel("\(d.md) \(d.weekday)")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
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
            Totals(logs: logs)
            DayRibbon(day: day, logs: logs, timers: timers)
            if logs.isEmpty {
                Text("这一页还空着").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(logs.enumerated()), id: \.element.id) { i, e in
                        if i > 0 { Divider().padding(.leading, 100) }
                        EntryRow(entry: e)
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
    var body: some View {
        let feeds = logs.filter { $0.type == LogType.nurse || $0.type == LogType.bottle }.count
        let ml = logs.filter { $0.type == LogType.bottle }.reduce(0) { $0 + ($1.amount ?? 0) }
        let sleep = logs.filter { $0.type == LogType.sleep && $0.end != nil }.reduce(0.0) { $0 + ($1.end! - $1.start) } / 1000
        let diapers = logs.filter { $0.type == LogType.diaper }.count
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
    /// The value, right-aligned in its column: an amount, a length of time, a temperature, the kind of nappy.
    var value: String {
        switch type {
        case LogType.nurse, LogType.sleep: return end.map { durationValue(($0 - start) / 1000) } ?? "进行中"
        case LogType.bottle: return "\(amount ?? 0) 毫升"
        case LogType.temp: return amount.map { String(format: "%.1f °C", Double($0) / 10) } ?? ""
        case LogType.diaper: return ["wet": "湿", "dirty": "便", "both": "湿 + 便"][detail ?? ""] ?? ""
        default: return ""
        }
    }
    /// The details, on the second line: the side, the time span, what was eaten or noted.
    var meta: String {
        var bits: [String] = []
        if type == LogType.nurse, let s = side { bits.append(s == "l" ? "左侧" : "右侧") }
        if let e = endDate { bits.append("\(hm(startDate))–\(hm(e))") }
        if [LogType.solid, LogType.medicine, LogType.note, LogType.play].contains(type), let d = detail, !d.isEmpty { bits.append(d) }
        return bits.joined(separator: " · ")
    }
}

/// One entry, in the journal's columns: the time in a fixed column, the sticker, the kind with its details below,
/// the value right-aligned.
private struct EntryRow: View {
    let entry: LogEntry
    @ScaledMetric private var timeWidth: CGFloat = 50
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(hm(entry.startDate)).font(Typeface.numerals(16, relativeTo: .body, weight: .semibold))
                .frame(width: timeWidth, alignment: .leading)
            IconTile(symbol: LogType.symbol(entry.type), color: LogType.color(entry.type), size: 26, round: true)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
            VStack(alignment: .leading, spacing: 2) {
                Text(LogType.name(entry.type)).font(.body)
                if !entry.meta.isEmpty { Text(entry.meta).font(.footnote).foregroundStyle(.secondary).monospacedDigit().lineLimit(1) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.value).font(Typeface.numerals(16, relativeTo: .body, weight: .semibold)).foregroundStyle(.primary).fixedSize()
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

/// A feed or a sleep in progress: the time running large, end, pause, change side; the start time and less common
/// actions in a menu.
struct TimerCard: View {
    @Environment(JournalStore.self) private var j
    let timer: RunningTimer
    @State private var picking = false
    var body: some View {
        let c = LogType.color(timer.type), paused = timer.pausedAt != nil
        Card(title: LogType.name(timer.type) + (timer.side == "l" ? " · 左边" : timer.side == "r" ? " · 右边" : ""), symbol: LogType.symbol(timer.type), color: c,
             detail: (paused ? "已暂停 · " : "") + whenLabel(Date(timeIntervalSince1970: timer.start / 1000)) + " 开始") {
            TimelineView(.periodic(from: .now, by: 1)) { tl in
                Text(clock(timer.elapsed(tl.date.timeIntervalSince1970 * 1000))).font(Typeface.numerals(52, relativeTo: .largeTitle, weight: .bold)).monospacedDigit()
                    .foregroundStyle(paused ? Color.secondary : Color.primary)
                    .contentTransition(.numericText())
            }
            HStack(spacing: 10) {
                Button { j.stop(timer.type) } label: { Label("结束", systemImage: "stop.fill").fixedSize() }.buttonStyle(.glassProminent).tint(c).controlSize(.large)
                Button { j.togglePause(timer.type) } label: { Image(systemName: paused ? "play.fill" : "pause.fill").frame(width: 24, height: 24) }
                    .buttonStyle(.glass).controlSize(.large).accessibilityLabel(paused ? "继续" : "暂停")
                if timer.type == LogType.nurse {
                    Button { j.switchSide(timer.type) } label: { Image(systemName: "arrow.left.arrow.right").frame(width: 24, height: 24) }
                        .buttonStyle(.glass).controlSize(.large).accessibilityLabel(timer.side == "r" ? "换到左侧" : "换到右侧")
                }
                Spacer(minLength: 0)
                Menu {
                    Button("开始时间…", systemImage: "clock") { picking = true }
                    Button("提前 5 分钟", systemImage: "gobackward.5") { j.shift(timer.type, to: Date(timeIntervalSince1970: timer.start / 1000 - 300)) }
                    Button("提前 15 分钟", systemImage: "gobackward.15") { j.shift(timer.type, to: Date(timeIntervalSince1970: timer.start / 1000 - 900)) }
                    Divider()
                    Button("不记这一次", systemImage: "xmark", role: .destructive) { j.discard(timer.type) }
                } label: { Image(systemName: "ellipsis").frame(width: 24, height: 24) }
                    .buttonStyle(.glass).controlSize(.large).accessibilityLabel("更多")
            }
        }
        .sheet(isPresented: $picking) {
            TimeSheet(title: "开始时间", initial: Date(timeIntervalSince1970: timer.start / 1000)) { j.shift(timer.type, to: $0) }
        }
    }
}

/// The running timer, small, above the tab bar on every tab.
struct TimerAccessory: View {
    @Environment(JournalStore.self) private var j
    let timer: RunningTimer
    var body: some View {
        let c = LogType.color(timer.type)
        HStack(spacing: 12) {
            Image(systemName: LogType.symbol(timer.type)).foregroundStyle(.white).font(.footnote.weight(.semibold))
                .frame(width: 30, height: 30).background(c.gradient, in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text(LogType.name(timer.type) + (timer.side == "l" ? " · 左" : timer.side == "r" ? " · 右" : "")).font(.footnote.weight(.semibold))
                TimelineView(.periodic(from: .now, by: 1)) { tl in
                    Text(clock(timer.elapsed(tl.date.timeIntervalSince1970 * 1000))).font(Typeface.numerals(13, relativeTo: .footnote)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
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
