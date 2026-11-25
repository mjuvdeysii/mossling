import WidgetKit
import SwiftUI
import AppIntents
import ActivityKit

@main
struct MosslingWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        StoryWindowWidget()
        QuickCareWidget()
        BedsideLampWidget()
        TimerLiveActivity()
        SleepControl()
        NurseControl()
        WetDiaperControl()
        BedsideLampControl()
    }
}

// MARK: Home Screen and Lock Screen widgets (faces in Shared/WidgetFaces.swift)

struct TodayEntry: TimelineEntry {
    let date: Date
    let snap: Snapshot?
    let body: JournalFile.Body
}

struct TodayProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayEntry {
        TodayEntry(date: .now, snap: Snapshot(birthEpochDay: Day.today.plus(days: -200).epochDay, nickname: "", companion: "Moss", journal: true, playCode: "A11", playName: L10n.t("双手物品传递机会", "Hand-to-Hand Transfer")), body: .init())
    }
    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) { completion(entry(.now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let now = Date()
        let snap = JournalFile.snapshot()
        let body = JournalFile.read()
        var dates: [Date] = [now]
        // If a diaper was just logged on the widget, schedule a clean transition back to normal right after the 12s confirm window
        if let recent = QuickCareFace.recentDiaper(in: body.logs, now: now) {
            let settle = recent.startDate.addingTimeInterval(QuickCareFace.confirmWindowSeconds + 0.5)
            if settle > now { dates.append(settle) }
        }
        // Dense 5-minute ticks for the first hour so "X min ago" and Otto's golden bead feel alive,
        // then 15-minute ticks for hours 1–4, then 30-minute ticks for hours 4–8.
        dates.append(contentsOf: (1...12).map { now.addingTimeInterval(Double($0) * 300) })
        dates.append(contentsOf: (5...16).map { now.addingTimeInterval(Double($0) * 900) })
        dates.append(contentsOf: (9...16).map { now.addingTimeInterval(Double($0) * 1800) })
        completion(Timeline(entries: dates.map { TodayEntry(date: $0, snap: snap, body: body) }, policy: .atEnd))
    }
    private func entry(_ d: Date) -> TodayEntry { TodayEntry(date: d, snap: JournalFile.snapshot(), body: JournalFile.read()) }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "today", provider: TodayProvider()) { e in
            TodayWidgetView(e: e).fontDesign(.rounded).containerBackground(for: .widget) { WidgetInk.paper }
        }
        .configurationDisplayName(L10n.t("摸索台灯 · 今日", "Moss & Otto · Today"))
        .description(L10n.t("月龄、今日活动与蒙氏 24 小时串珠节奏；点击各区块直达活动绘本与手帐。", "Age, today's play, 24h bead rhythm, and direct links into play & journal."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

private struct TodayWidgetView: View {
    let e: TodayEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        let size: TodaySize = switch family {
        case .accessoryInline: .inline
        case .accessoryCircular: .circular
        case .accessoryRectangular: .rectangular
        case .systemLarge: .large
        case .systemMedium: .medium
        default: .small
        }
        TodayFace(date: e.date, snap: e.snap, body: e.body, size: size)
    }
}

/// Story Window (成长故事窗): 37-bead Montessori growth chapter keepsake linking directly into Growth Book & Month view.
struct StoryWindowWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "story-window", provider: TodayProvider()) { e in
            StoryWindowWidgetView(e: e).fontDesign(.rounded).containerBackground(for: .widget) { WidgetInk.paper }
        }
        .configurationDisplayName(L10n.t("成长故事窗", "Story Window"))
        .description(L10n.t("37 颗蒙氏成长珠进度与当下成长章节，轻点直达成长册与本月主页。", "Your baby's 37-bead Montessori chapter & keepsake window into Growth Book."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct StoryWindowWidgetView: View {
    let e: TodayEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        StoryWindowFace(date: e.date, snap: e.snap, body_: e.body, isMedium: family == .systemMedium)
    }
}

/// Dedicated interactive one-tap care logging widget: start/stop nursing or sleep and log diapers right on Home Screen.
struct QuickCareWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "quick-care", provider: TodayProvider()) { e in
            QuickCareWidgetView(e: e).fontDesign(.rounded).containerBackground(for: .widget) { WidgetInk.paper }
        }
        .configurationDisplayName(L10n.t("一键记录", "Quick Log"))
        .description(L10n.t("无需打开应用，轻点即可启停亲喂与睡眠计时，或记下湿/便尿布并即时确认。", "Start or stop timers and log wet or dirty diapers right from your Home Screen."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct QuickCareWidgetView: View {
    let e: TodayEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        QuickCareFace(date: e.date, snap: e.snap, body_: e.body, isMedium: family == .systemMedium)
    }
}

/// StandBy & bedside night-lamp widget: Otto's deep-blue & warm-amber glow with live timer and last feed/wake.
struct BedsideLampWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "bedside-lamp", provider: TodayProvider()) { e in
            BedsideLampWidgetView(e: e).fontDesign(.rounded).containerBackground(for: .widget) {
                BedsideLampContainerBackground()
            }
        }
        .configurationDisplayName(L10n.t("床头台灯", "Bedside Lamp"))
        .description(L10n.t("专为床头待机（StandBy）与夜间照护设计：暖琥珀微光，轻点直达计时或夜间手帐。", "Warm amber StandBy lamp with live timer and direct tap to timer or night log."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct BedsideLampContainerBackground: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    var body: some View {
        if renderingMode == .fullColor {
            BedsideLampFace.backdrop
        } else {
            Color.clear
        }
    }
}

private struct BedsideLampWidgetView: View {
    let e: TodayEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        BedsideLampFace(date: e.date, snap: e.snap, body_: e.body, isMedium: family == .systemMedium)
    }
}

// MARK: Stateful Control Center, Lock Screen bottom buttons & Action Button controls

struct SleepControlProvider: ControlValueProvider {
    var previewValue: Bool { false }
    func currentValue() async throws -> Bool {
        JournalFile.read().timers.contains { $0.type == LogType.sleep }
    }
}

struct NurseControlProvider: ControlValueProvider {
    var previewValue: Bool { false }
    func currentValue() async throws -> Bool {
        JournalFile.read().timers.contains { $0.type == LogType.nurse }
    }
}

struct SleepControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "control.sleep", provider: SleepControlProvider()) { isRunning in
            ControlWidgetToggle(
                L10n.t("睡觉计时", "Sleep Timer"),
                isOn: isRunning,
                action: SetCareTimerIntent(careType: .sleep)
            ) { running in
                Label(running ? L10n.t("睡觉中", "Sleeping") : L10n.t("睡觉", "Sleep"), systemImage: "moon.zzz.fill")
            }
            .tint(LogType.color(LogType.sleep))
        }
        .displayName(L10n.res("睡觉计时", "Sleep Timer"))
        .description(L10n.res("在控制中心、锁屏或操作按钮一键切换宝宝睡眠计时，实时显示开关状态。", "Toggle baby's sleep timer with live on/off state in Control Center or Lock Screen."))
    }
}

struct NurseControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "control.nurse", provider: NurseControlProvider()) { isRunning in
            ControlWidgetToggle(
                L10n.t("亲喂计时", "Nursing Timer"),
                isOn: isRunning,
                action: SetCareTimerIntent(careType: .nurse)
            ) { running in
                Label(running ? L10n.t("亲喂中", "Nursing") : L10n.t("亲喂", "Nurse"), systemImage: "heart.circle.fill")
            }
            .tint(LogType.color(LogType.nurse))
        }
        .displayName(L10n.res("亲喂计时", "Nursing Timer"))
        .description(L10n.res("在控制中心、锁屏或操作按钮一键切换亲喂计时，实时显示开关状态。", "Toggle nursing timer with live on/off state in Control Center or Lock Screen."))
    }
}

struct WetDiaperControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "control.diaper.wet") {
            ControlWidgetButton(action: QuickLogDiaperIntent(kind: .wet)) {
                Label(L10n.t("记湿尿布", "Wet Diaper"), systemImage: "drop.fill")
            }
            .tint(LogType.color(LogType.diaper))
        }
        .displayName(L10n.res("记湿尿布", "Log Wet Diaper"))
        .description(L10n.res("在控制中心或锁屏一键记下一次湿尿布。", "Log a wet diaper in one tap from Control Center or Lock Screen."))
    }
}

struct BedsideLampControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "control.lamp") {
            ControlWidgetButton(action: OpenBedsideLampIntent()) {
                Label(L10n.t("床头夜灯", "Bedside Lamp"), systemImage: "lamp.desk.fill")
            }
            .tint(BedsideLampFace.amber)
        }
        .displayName(L10n.res("床头夜灯", "Bedside Lamp"))
        .description(L10n.res("在控制中心或锁屏一键点亮暖琥珀床头夜灯与助眠声景。", "Open Otto's warm low-glare Bedside Lamp & soundscapes in one tap."))
    }
}

// MARK: Live Activity: a running feed or sleep on the Lock Screen and in the Dynamic Island

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerAttributes.self) { ctx in
            LockScreenTimer(type: ctx.attributes.type, s: ctx.state)
                .widgetURL(WidgetLinks.care(ctx.attributes.type))
        } dynamicIsland: { ctx in
            let c = LogType.color(ctx.attributes.type)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        ArtImage(name: WidgetArt.sticker(ctx.attributes.type)).frame(width: 30, height: 30)
                        Text(L10n.timerStatus(ctx.attributes.type, side: ctx.state.side, paused: ctx.state.pausedAt != nil)).font(.headline).foregroundStyle(c).lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) { TimerFace.elapsed(ctx.state).font(WidgetInk.numerals(24)).foregroundStyle(.white) }
                DynamicIslandExpandedRegion(.bottom) { TimerControls(type: ctx.attributes.type, s: ctx.state, light: true) }
            } compactLeading: {
                ArtImage(name: WidgetArt.sticker(ctx.attributes.type)).frame(width: 22, height: 22)
            } compactTrailing: {
                TimerFace.elapsed(ctx.state).frame(maxWidth: 52).foregroundStyle(c)
            } minimal: {
                ArtImage(name: WidgetArt.sticker(ctx.attributes.type)).frame(width: 22, height: 22)
            }
            .widgetURL(WidgetLinks.care(ctx.attributes.type))
        }
    }
}

/// The Lock Screen face: always under Otto's lamp — the lamp's deep blue, white numbers, the kind's colour — in
/// every appearance. A light face showed as gold on phones at night (a warm night filter over paper, and the system
/// sometimes drawing the light background under dark text), so it is never light. Dimmed further when the screen is
/// always on.
private struct LockScreenTimer: View {
    let type: String
    let s: TimerAttributes.ContentState
    @Environment(\.isLuminanceReduced) private var dim
    var body: some View {
        TimerFace(type: type, s: s)
            .environment(\.colorScheme, .dark)
            .opacity(dim ? 0.85 : 1)
            .activityBackgroundTint(Color(red: 0x07 / 255, green: 0x0B / 255, blue: 0x16 / 255).opacity(dim ? 0.96 : 1))
            .activitySystemActionForegroundColor(.white)
    }
}
