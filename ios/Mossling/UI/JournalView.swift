import SwiftUI

extension LogType {
    static func color(_ t: String) -> Color { Color(hex: tint(t)) }
}

/// The journal (optional): what is running first, one-tap buttons, the week, the day as a strip, the day's entries.
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
            VStack(alignment: .leading, spacing: 0) {
                if !j.timers.isEmpty {
                    VStack(spacing: 8) { ForEach(j.timers, id: \.type) { TimerCard(timer: $0) } }.padding(.horizontal, 16).padding(.top, 12)
                }

                TimelineView(.periodic(from: .now, by: 60)) { tl in
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(LogType.buttons, id: \.self) { t in
                            LogButton(type: t, running: j.timers.contains { $0.type == t }, since: j.last(t).map { ago($0, tl.date) }) { tap(t) }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 12)

                WeekStrip(today: app.today, day: $day).padding(.horizontal, 12).padding(.top, 14)
                DayRibbon(day: day, logs: j.logs(on: day), timers: j.timers).padding(.horizontal, 16).padding(.top, 6)
                Summary(logs: j.logs(on: day)).padding(.horizontal, 16).padding(.top, 12)

                let list = j.logs(on: day)
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 1) {
                        if !list.isEmpty { Text("\(list.count) 条").font(.caption).foregroundStyle(Palette.secondaryText) }
                        Text(list.isEmpty ? "这一天还没有记录" : "这一天").font(Typeface.serif(21))
                    }
                    Spacer()
                    Button { editing = LogEntry(type: LogType.bottle, start: defaultTime(), amount: 120) } label: { Label("补记", systemImage: "plus") }
                }
                .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 4)
                ForEach(Array(list.enumerated()), id: \.element.id) { i, e in
                    EntryRow(entry: e, first: i == 0, last: i == list.count - 1).onTapGesture { editing = e }
                }

                HStack(spacing: 8) {
                    link("统计", "chart.bar.fill") { path.append(JournalRoute.stats) }
                    link("生长曲线", "chart.line.uptrend.xyaxis") { path.append(JournalRoute.growth) }
                }
                .padding(.horizontal, 16).padding(.top, 24)
            }
            .padding(.bottom, 32)
        }
        .background(Palette.background)
        .navigationTitle("手帐")
        .navigationSubtitle(day == app.today ? "今天 · \(day.md)" : "\(day.md) · \(day.weekday)")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Duo(primary: app.companion, size: 34, mood: j.timers.contains { $0.type == LogType.sleep } ? .sleep : .open, look: CGPoint(x: 0.2, y: 0.7), poke: false)
            }
            .sharedBackgroundVisibility(.hidden)
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

    private func link(_ t: String, _ s: String, _ f: @escaping () -> Void) -> some View {
        Button(action: f) {
            HStack(spacing: 10) {
                Image(systemName: s).foregroundStyle(Palette.primary).frame(width: 34, height: 34).background(Palette.primary.opacity(0.12), in: Circle())
                Text(t).font(.subheadline.weight(.semibold)); Spacer(minLength: 0)
            }
            .card(Palette.cardLow, radius: 20, padding: 12)
        }
        .buttonStyle(.plain)
    }
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

private struct LogButton: View {
    let type: String, running: Bool, since: String?
    let action: () -> Void
    var body: some View {
        let c = LogType.color(type)
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: LogType.symbol(type)).font(.title3).foregroundStyle(running ? .white : c)
                Text(running ? "进行中" : LogType.name(type)).font(.footnote.weight(.semibold)).foregroundStyle(running ? .white : Palette.text)
                if let since, !running { Text(since).font(.caption2).foregroundStyle(Palette.secondaryText).multilineTextAlignment(.center) }
            }
            .frame(maxWidth: .infinity, minHeight: 84).padding(.vertical, 6).padding(.horizontal, 2)
            .background(running ? c : c.opacity(0.11), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: running)
        .accessibilityLabel(running ? "\(LogType.name(type))进行中，点一下结束" : LogType.name(type))
    }
}

private struct WeekStrip: View {
    let today: Day
    @Binding var day: Day
    var body: some View {
        let end = min(day.plus(days: 3), today)
        HStack(spacing: 4) {
            ForEach((0...6).reversed(), id: \.self) { i in
                let d = end.plus(days: -i), on = d == day
                Button { withAnimation(.snappy) { day = d } } label: {
                    VStack(spacing: 2) {
                        Text(String(d.weekday.suffix(1))).font(.caption2)
                        Text("\(d.d)").font(Typeface.numerals(19))
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .foregroundStyle(on ? Palette.paper : Palette.text)
                    .background(on ? Palette.primary : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(d.md) \(d.weekday)")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// The day from midnight to midnight: sleeps and feeds as blocks of their length, everything else as a mark.
private struct DayRibbon: View {
    let day: Day, logs: [LogEntry], timers: [RunningTimer]
    var body: some View {
        let d0 = day.date.timeIntervalSince1970 * 1000, span = 86_400_000.0
        TimelineView(.periodic(from: .now, by: 60)) { tl in
            let now = tl.date.timeIntervalSince1970 * 1000
            VStack(spacing: 4) {
                Canvas { ctx, size in
                    let track = Path(roundedRect: CGRect(x: 0, y: 6, width: size.width, height: size.height - 12), cornerRadius: (size.height - 12) / 2)
                    ctx.fill(track, with: .color(Palette.cardHigh))
                    func x(_ t: Double) -> CGFloat { CGFloat(max(0, min(1, (t - d0) / span))) * size.width }
                    for h in [6.0, 12, 18] { ctx.fill(Path(CGRect(x: x(d0 + h * 3_600_000), y: 6, width: 1, height: size.height - 12)), with: .color(Palette.outline)) }
                    let blocks = logs.compactMap { e in e.end.map { (e.type, e.start, $0) } } + timers.map { ($0.type, $0.start, now) }
                    for (t, a, b) in blocks where b > d0 && a < d0 + span {
                        let r = CGRect(x: x(a), y: 4, width: max(4, x(b) - x(a)), height: size.height - 8)
                        ctx.fill(Path(roundedRect: r, cornerRadius: 6), with: .color(LogType.color(t)))
                    }
                    for e in logs where e.end == nil {
                        ctx.fill(Path(ellipseIn: CGRect(x: x(e.start) - 4, y: size.height / 2 - 4, width: 8, height: 8)), with: .color(LogType.color(e.type)))
                    }
                    if now > d0 && now < d0 + span { ctx.fill(Path(CGRect(x: x(now) - 1, y: 0, width: 2, height: size.height)), with: .color(Palette.primary)) }
                }
                .frame(height: 40)
                HStack { ForEach(["0 点", "6 点", "12 点", "18 点"], id: \.self) { Text($0).font(.caption2).foregroundStyle(Palette.secondaryText).frame(maxWidth: .infinity, alignment: .leading) } }
            }
            .card(Palette.cardLow, radius: 20, padding: 12)
        }
        .accessibilityElement().accessibilityLabel("这一天的时间条：\(logs.count) 条记录")
    }
}

private struct Summary: View {
    let logs: [LogEntry]
    var body: some View {
        let feeds = logs.filter { $0.type == LogType.nurse || $0.type == LogType.bottle }.count
        let ml = logs.filter { $0.type == LogType.bottle }.reduce(0) { $0 + ($1.amount ?? 0) }
        let sleep = logs.filter { $0.type == LogType.sleep && $0.end != nil }.reduce(0.0) { $0 + ($1.end! - $1.start) } / 3_600_000
        let diapers = logs.filter { $0.type == LogType.diaper }.count
        HStack(spacing: 8) {
            fact("\(feeds)", "次喂奶", ml > 0 ? "瓶喂 \(ml) 毫升" : nil)
            fact(sleep > 0 ? String(format: "%.1f", sleep) : "0", "小时睡眠", nil)
            fact("\(diapers)", "片尿布", nil)
        }
    }
    private func fact(_ n: String, _ l: String, _ sub: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(n).font(Typeface.numerals(32))
            Text(l).font(.caption).foregroundStyle(Palette.secondaryText)
            if let sub { Text(sub).font(.caption2).foregroundStyle(Palette.primary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading).card(Palette.cardLow, radius: 20, padding: 12)
    }
}

private struct EntryRow: View {
    let entry: LogEntry, first: Bool, last: Bool
    var body: some View {
        let c = LogType.color(entry.type)
        HStack(spacing: 10) {
            Text(hm(entry.startDate)).font(Typeface.numerals(19)).frame(minWidth: 58, alignment: .leading)
            ZStack {
                VStack(spacing: 0) {
                    Rectangle().fill(first ? .clear : Palette.outline).frame(width: 2)
                    Rectangle().fill(last ? .clear : Palette.outline).frame(width: 2)
                }
                Image(systemName: LogType.symbol(entry.type)).font(.subheadline).foregroundStyle(c)
                    .frame(width: 36, height: 36).background(Palette.background).background(c.opacity(0.14), in: Circle()).clipShape(Circle())
            }
            .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(LogType.name(entry.type)).font(.subheadline.weight(.semibold))
                let d = [entry.endDate.map { "\(hm(entry.startDate))–\(hm($0))" }, entry.summary.isEmpty ? nil : entry.summary].compactMap { $0 }.joined(separator: " · ")
                if !d.isEmpty { Text(d).font(.caption).foregroundStyle(Palette.secondaryText) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20).frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A feed or a sleep in progress: since when (tap to set the exact minute), the time running, pause, change side, finish.
struct TimerCard: View {
    @Environment(JournalStore.self) private var j
    let timer: RunningTimer
    @State private var picking = false
    var body: some View {
        let c = LogType.color(timer.type), paused = timer.pausedAt != nil
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: LogType.symbol(timer.type))
                Text(LogType.name(timer.type) + (timer.side == "l" ? " · 左边" : timer.side == "r" ? " · 右边" : "") + (paused ? " · 暂停中" : "")).font(.headline)
                Spacer()
            }
            Button { picking = true } label: {
                Text(whenLabel(Date(timeIntervalSince1970: timer.start / 1000)) + " 开始").font(.footnote.weight(.semibold)).monospacedDigit()
                    .padding(.horizontal, 10).padding(.vertical, 5).background(.white.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)
            TimelineView(.periodic(from: .now, by: 1)) { tl in
                Text(clock(timer.elapsed(tl.date.timeIntervalSince1970 * 1000))).font(Typeface.numerals(48)).monospacedDigit()
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { buttons }
                VStack(alignment: .leading, spacing: 8) { buttons }
            }
            HStack {
                Text("提前").font(.caption)
                ForEach([5, 15], id: \.self) { m in Button("\(m) 分钟") { j.shift(timer.type, to: Date(timeIntervalSince1970: timer.start / 1000 - Double(m) * 60)) }.font(.caption.weight(.semibold)) }
                Spacer()
                Button("不记了") { j.discard(timer.type) }.font(.caption)
            }
        }
        .foregroundStyle(.white).tint(.white)
        .padding(18)
        .background(paused ? c.opacity(0.75) : c, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .sheet(isPresented: $picking) {
            TimeSheet(title: "开始时间", initial: Date(timeIntervalSince1970: timer.start / 1000)) { j.shift(timer.type, to: $0) }
        }
    }
    @ViewBuilder private var buttons: some View {
        Button { j.stop(timer.type) } label: { Text("结束并记下").padding(.horizontal, 4) }.buttonStyle(.glassProminent).tint(.white).foregroundStyle(LogType.color(timer.type))
        Button(timer.pausedAt == nil ? "暂停" : "继续") { j.togglePause(timer.type) }.buttonStyle(.glass)
        if timer.type == LogType.nurse { Button(timer.side == "r" ? "换到左边" : "换到右边") { j.switchSide(timer.type) }.buttonStyle(.glass) }
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
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("好") { pick(date); dismiss() } }
            }
        }
        .onAppear { date = initial }
        .presentationDetents([.large])
    }
}
