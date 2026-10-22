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

                TimelineView(.periodic(from: .now, by: 60)) { tl in
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 14) {
                        ForEach(LogType.buttons, id: \.self) { t in
                            LogButton(type: t, running: j.timers.contains { $0.type == t }, since: j.last(t).map { ago($0, tl.date) }) { tap(t) }
                        }
                    }
                    .padding(.vertical, 16).padding(.horizontal, 6)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                }

                WeekStrip(today: app.today, day: $day)

                let list = j.logs(on: day)
                Summary(logs: list)

                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(title: day == app.today ? "今天" : "\(day.md) \(day.weekday)", detail: list.isEmpty ? nil : "\(list.count) 条")
                    VStack(spacing: 0) {
                        DayRibbon(day: day, logs: list, timers: j.timers).padding(16)
                        if list.isEmpty {
                            Divider().padding(.leading, 16)
                            Text("这一天还没有记录").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(16)
                        }
                        ForEach(Array(list.enumerated()), id: \.element.id) { i, e in
                            Divider().padding(.leading, i == 0 ? 16 : 120)
                            Button { editing = e } label: { EntryRow(entry: e) }.buttonStyle(.plain)
                                .contextMenu { Button("删除", systemImage: "trash", role: .destructive) { j.delete(e) } }
                        }
                    }
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                }

                Box {
                    NavigationLink(value: JournalRoute.stats) { BoxRow(symbol: "chart.bar.fill", color: Crayon.lilac, title: "最近七天", opens: true) }.buttonStyle(.plain)
                    NavigationLink(value: JournalRoute.growth) { BoxRow(symbol: "chart.line.uptrend.xyaxis", color: Crayon.tangerine, title: "生长曲线", last: true, opens: true) }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .background(Palette.background)
        .navigationTitle("手帐")
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

/// A round button per kind: the symbol on its colour, the name, how long ago.
private struct LogButton: View {
    let type: String, running: Bool, since: String?
    let action: () -> Void
    @ScaledMetric private var d: CGFloat = 50
    var body: some View {
        let c = LogType.color(type)
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: running ? "stop.fill" : LogType.symbol(type))
                    .font(.system(size: d * 0.4, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: d, height: d)
                    .background(c.gradient, in: Circle())
                    .overlay(Circle().stroke(c.opacity(running ? 0.35 : 0), lineWidth: 4).padding(-5))
                    .contentTransition(.symbolEffect(.replace))
                Text(running ? "结束" : LogType.name(type)).font(.caption.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                Text(running ? "进行中" : since ?? " ").font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: running)
        .accessibilityLabel(running ? "\(LogType.name(type))进行中，结束" : LogType.name(type))
        .accessibilityValue(since ?? "")
    }
}

/// Seven days ending today (or around the chosen day), as in Calendar.
private struct WeekStrip: View {
    let today: Day
    @Binding var day: Day
    var body: some View {
        let end = min(day.plus(days: 3), today)
        HStack(spacing: 0) {
            ForEach((0...6).reversed(), id: \.self) { i in
                let d = end.plus(days: -i), on = d == day, isToday = d == today
                Button { withAnimation(.snappy) { day = d } } label: {
                    VStack(spacing: 6) {
                        Text(String(d.weekday.suffix(1))).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        Text("\(d.d)").font(Typeface.numerals(17, relativeTo: .body, weight: on ? .bold : .medium))
                            .foregroundStyle(on ? .white : isToday ? Palette.accent : .primary)
                            .frame(width: 36, height: 36)
                            .background(on ? (isToday ? Palette.accent : Color.primary) : .clear, in: Circle())
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(d.md) \(d.weekday)")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
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

/// The day's totals, side by side.
private struct Summary: View {
    let logs: [LogEntry]
    var body: some View {
        let feeds = logs.filter { $0.type == LogType.nurse || $0.type == LogType.bottle }.count
        let ml = logs.filter { $0.type == LogType.bottle }.reduce(0) { $0 + ($1.amount ?? 0) }
        let sleep = logs.filter { $0.type == LogType.sleep && $0.end != nil }.reduce(0.0) { $0 + ($1.end! - $1.start) } / 3_600_000
        let diapers = logs.filter { $0.type == LogType.diaper }.count
        HStack(spacing: 0) {
            fact(LogType.nurse, "喂奶", "\(feeds)", "次", ml > 0 ? "瓶喂 \(ml) 毫升" : nil)
            Divider().padding(.vertical, 14)
            fact(LogType.sleep, "睡眠", sleep > 0 ? String(format: "%.1f", sleep) : "0", "小时", nil)
            Divider().padding(.vertical, 14)
            fact(LogType.diaper, "尿布", "\(diapers)", "片", nil)
        }
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
    private func fact(_ t: String, _ name: String, _ n: String, _ unit: String, _ sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(name, systemImage: LogType.symbol(t)).font(.caption.weight(.semibold)).foregroundStyle(LogType.color(t))
            ValueText(parts: [(n, unit)], size: 26)
            Text(sub ?? " ").font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .accessibilityElement(children: .combine)
    }
}

/// One entry: the time, the kind on its colour, what it was.
private struct EntryRow: View {
    let entry: LogEntry
    var body: some View {
        HStack(spacing: 14) {
            Text(hm(entry.startDate)).font(Typeface.numerals(17, relativeTo: .body, weight: .semibold)).frame(width: 52, alignment: .leading)
            IconTile(symbol: LogType.symbol(entry.type), color: LogType.color(entry.type))
            VStack(alignment: .leading, spacing: 2) {
                Text(LogType.name(entry.type)).font(.body)
                let d = [entry.endDate.map { "\(hm(entry.startDate))–\(hm($0))" }, entry.summary.isEmpty ? nil : entry.summary].compactMap { $0 }.joined(separator: " · ")
                if !d.isEmpty { Text(d).font(.subheadline).foregroundStyle(.secondary).monospacedDigit() }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .contentShape(Rectangle())
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
                Button { j.stop(timer.type) } label: { Text("结束").padding(.horizontal, 6) }.buttonStyle(.glassProminent).tint(c).controlSize(.large)
                Button(paused ? "继续" : "暂停") { j.togglePause(timer.type) }.buttonStyle(.glass).controlSize(.large)
                if timer.type == LogType.nurse { Button(timer.side == "r" ? "换左边" : "换右边") { j.switchSide(timer.type) }.buttonStyle(.glass).controlSize(.large) }
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
