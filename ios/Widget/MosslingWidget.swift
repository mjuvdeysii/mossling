import WidgetKit
import SwiftUI
import AppIntents
import ActivityKit

@main
struct MosslingWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        TimerLiveActivity()
    }
}

private extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255) }
    static let moss = Color(hex: 0x3D5434), bead = Color(hex: 0xD4A21C)
}
private func serif(_ s: CGFloat) -> Font { .custom("YoungSerif-Regular", size: s) }

// MARK: Home Screen and Lock Screen widget

struct TodayEntry: TimelineEntry {
    let date: Date
    let snap: Snapshot?
    let body: JournalFile.Body
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snap: Snapshot(birthEpochDay: Day.today.plus(days: -200).epochDay, nickname: "", companion: "Moss", journal: true, playCode: "A11", playName: "双手物品传递机会"), body: .init())
    }
    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) { completion(entry(.now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        // refresh at the next midnight (the age changes) and every half hour for "how long ago"
        let now = Date()
        let dates = (0..<12).map { now.addingTimeInterval(Double($0) * 1800) }
        completion(Timeline(entries: dates.map { entry($0) }, policy: .atEnd))
    }
    private func entry(_ d: Date) -> TodayEntry { TodayEntry(date: d, snap: JournalFile.snapshot(), body: JournalFile.read()) }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "today", provider: TodayProvider()) { e in TodayWidgetView(e: e).containerBackground(for: .widget) { Color(hex: 0xF4F2EC) } }
            .configurationDisplayName("芽芽月历")
            .description("月龄、今天的活动；打开手帐后可以直接计时和记一笔。")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

private struct TodayWidgetView: View {
    let e: TodayEntry
    @Environment(\.widgetFamily) private var family

    private var age: Age? { e.snap?.birthEpochDay.map { Age.on(birth: Day(epochDay: $0), today: Day(e.date)) } }
    private var ageText: String { age.map { $0.days > 0 ? "\($0.months) 个月 \($0.days) 天" : "满 \($0.months) 个月" } ?? "填写出生日期" }
    private func last(_ t: String) -> Date? { e.body.logs.filter { $0.type == t }.max { $0.start < $1.start }.map { Date(timeIntervalSince1970: ($0.end ?? $0.start) / 1000) } }
    private func agoText(_ d: Date) -> String {
        let m = Int(e.date.timeIntervalSince(d) / 60)
        return m < 2 ? "刚刚" : m < 60 ? "\(m) 分钟前" : m < 48 * 60 ? "\(m / 60) 小时\(m % 60 > 0 && m < 600 ? " \(m % 60) 分" : "")前" : "\(m / 1440) 天前"
    }

    var body: some View {
        switch family {
        case .accessoryInline: Text("\(ageText)" + (e.snap?.playName.map { " · \($0)" } ?? ""))
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(ageText).font(.headline)
                if let p = e.snap?.playName { Text("今天：\(p)").font(.caption) }
                if e.snap?.journal == true, let f = [last(LogType.nurse), last(LogType.bottle)].compactMap({ $0 }).max() { Text("喂奶 \(agoText(f))").font(.caption) }
            }
        case .systemMedium: medium
        default: small
        }
    }

    private var head: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                if let n = e.snap?.nickname, !n.isEmpty { Text(n).font(.caption2).foregroundStyle(.secondary) }
                if let a = age {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(a.months)").font(serif(30)).foregroundStyle(Color.moss)
                        Text("个月").font(.caption)
                        if a.days > 0 { Text("\(a.days)").font(serif(18)).foregroundStyle(Color.moss); Text("天").font(.caption) }
                    }
                } else { Text("芽芽月历").font(.headline) }
            }
            Spacer(minLength: 0)
            Image("Pair").resizable().scaledToFit().frame(width: 44)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            head
            Spacer(minLength: 0)
            if let t = e.body.timers.first {
                timerLine(t)
            } else if let p = e.snap?.playName {
                Text("今天一起玩").font(.caption2).foregroundStyle(Color.moss)
                Text(p).font(.footnote.weight(.semibold)).lineLimit(2)
            }
        }
        .foregroundStyle(Color(hex: 0x1C1D19))
    }

    private var medium: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                head
                Spacer(minLength: 0)
                if let p = e.snap?.playName { Text("今天一起玩").font(.caption2).foregroundStyle(Color.moss); Text(p).font(.footnote.weight(.semibold)).lineLimit(2) }
            }
            if e.snap?.journal == true {
                VStack(spacing: 6) {
                    if let t = e.body.timers.first { timerLine(t) }
                    HStack(spacing: 6) {
                        quick(LogType.nurse, running: e.body.timers.contains { $0.type == LogType.nurse }, intent: TimerIntent(type: LogType.nurse, action: e.body.timers.contains { $0.type == LogType.nurse } ? "stop" : "start"))
                        quick(LogType.sleep, running: e.body.timers.contains { $0.type == LogType.sleep }, intent: TimerIntent(type: LogType.sleep, action: e.body.timers.contains { $0.type == LogType.sleep } ? "stop" : "start"))
                        quickLog
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(Color(hex: 0x1C1D19))
    }

    private func timerLine(_ t: RunningTimer) -> some View {
        let c = Color(hex: LogType.tint(t.type))
        return HStack(spacing: 6) {
            Image(systemName: LogType.symbol(t.type)).foregroundStyle(c)
            if t.pausedAt != nil { Text(minutesOf(t.elapsed(t.pausedAt!) )).font(.footnote.weight(.semibold)) }
            else { Text(Date(timeIntervalSince1970: (t.start + t.pausedTotal) / 1000), style: .timer).font(serif(18)).monospacedDigit() }
        }
    }

    private func quick(_ type: String, running: Bool, intent: TimerIntent) -> some View {
        let c = Color(hex: LogType.tint(type))
        return Button(intent: intent) {
            VStack(spacing: 2) {
                Image(systemName: LogType.symbol(type)).font(.body)
                Text(running ? "结束" : LogType.name(type)).font(.caption2.weight(.semibold))
                if !running, let d = last(type) { Text(agoText(d)).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.center) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(running ? .white : c)
            .background(running ? c : c.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var quickLog: some View {
        let c = Color(hex: LogType.tint(LogType.diaper))
        return Button(intent: QuickLogIntent(type: LogType.diaper, detail: "wet")) {
            VStack(spacing: 2) {
                Image(systemName: LogType.symbol(LogType.diaper)).font(.body)
                Text("尿布").font(.caption2.weight(.semibold))
                if let d = last(LogType.diaper) { Text(agoText(d)).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.center) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity).foregroundStyle(c)
            .background(c.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: Live Activity: a running feed or sleep on the Lock Screen and in the Dynamic Island

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { ctx in
            LockScreenTimer(type: ctx.attributes.type, s: ctx.state)
                .activityBackgroundTint(Color(hex: 0xF4F2EC)).activitySystemActionForegroundColor(Color(hex: LogType.tint(ctx.attributes.type)))
        } dynamicIsland: { ctx in
            let c = Color(hex: LogType.tint(ctx.attributes.type))
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(LogType.name(ctx.attributes.type) + side(ctx.state.side), systemImage: LogType.symbol(ctx.attributes.type)).foregroundStyle(c).font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) { elapsed(ctx.state).font(serif(24)).monospacedDigit().foregroundStyle(.white) }
                DynamicIslandExpandedRegion(.bottom) { TimerButtons(type: ctx.attributes.type, s: ctx.state, light: true) }
            } compactLeading: {
                Image(systemName: LogType.symbol(ctx.attributes.type)).foregroundStyle(c)
            } compactTrailing: {
                elapsed(ctx.state).monospacedDigit().frame(maxWidth: 52).foregroundStyle(c)
            } minimal: {
                Image(systemName: LogType.symbol(ctx.attributes.type)).foregroundStyle(c)
            }
        }
    }
}

private func side(_ s: String?) -> String { s == "l" ? " · 左边" : s == "r" ? " · 右边" : "" }

@ViewBuilder private func elapsed(_ s: TimerAttributes.ContentState) -> some View {
    if let p = s.pausedAt { Text(minutesOf(p.timeIntervalSince(s.start))) }
    else { Text(timerInterval: s.start...Date.distantFuture, countsDown: false) }
}

private struct LockScreenTimer: View {
    let type: String
    let s: TimerAttributes.ContentState
    var body: some View {
        let c = Color(hex: LogType.tint(type))
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(LogType.name(type) + side(s.side) + (s.pausedAt != nil ? " · 暂停中" : ""), systemImage: LogType.symbol(type)).font(.headline).foregroundStyle(c)
                Spacer()
                Image("Pair").resizable().scaledToFit().frame(height: 30)
            }
            elapsed(s).font(serif(40)).monospacedDigit().foregroundStyle(Color(hex: 0x1C1D19))
            TimerButtons(type: type, s: s, light: false)
        }
        .padding(16)
    }
}

private struct TimerButtons: View {
    let type: String
    let s: TimerAttributes.ContentState
    let light: Bool
    var body: some View {
        let c = Color(hex: LogType.tint(type))
        HStack(spacing: 8) {
            Button(intent: TimerIntent(type: type, action: "stop")) { Text("结束").frame(maxWidth: .infinity) }.tint(c)
            Button(intent: TimerIntent(type: type, action: "pause")) { Text(s.pausedAt == nil ? "暂停" : "继续").frame(maxWidth: .infinity) }.tint(light ? .white : .gray)
            if type == LogType.nurse {
                Button(intent: TimerIntent(type: type, action: "side")) { Text(s.side == "r" ? "换左边" : "换右边").frame(maxWidth: .infinity) }.tint(light ? .white : .gray)
            }
        }
        .buttonStyle(.borderedProminent)
        .font(.subheadline.weight(.semibold))
    }
}
