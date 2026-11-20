import WidgetKit
import SwiftUI
import AppIntents
import ActivityKit

@main
struct MosslingWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        QuickCareWidget()
        BedsideLampWidget()
        TimerLiveActivity()
        SleepControl()
        NurseControl()
        WetDiaperControl()
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
        TodayEntry(date: .now, snap: Snapshot(birthEpochDay: Day.today.plus(days: -200).epochDay, nickname: "", companion: "Moss", journal: true, playCode: "A11", playName: "双手物品传递机会"), body: .init())
    }
    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) { completion(entry(.now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        // refresh every half hour for "how long ago" (and so past midnight, when the age changes)
        let now = Date()
        let dates = (0..<12).map { now.addingTimeInterval(Double($0) * 1800) }
        completion(Timeline(entries: dates.map { entry($0) }, policy: .atEnd))
    }
    private func entry(_ d: Date) -> TodayEntry { TodayEntry(date: d, snap: JournalFile.snapshot(), body: JournalFile.read()) }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "today", provider: TodayProvider()) { e in
            TodayWidgetView(e: e).containerBackground(for: .widget) { WidgetInk.paper }
        }
        .configurationDisplayName("摸索台灯 · 今日")
        .description("月龄、今日活动与照护节奏；大号组件支持在桌面直接一键记录。")
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

/// Dedicated interactive one-tap care logging widget: start/stop nursing or sleep and log diapers right on Home Screen.
struct QuickCareWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "quick-care", provider: TodayProvider()) { e in
            QuickCareWidgetView(e: e).containerBackground(for: .widget) { WidgetInk.paper }
        }
        .configurationDisplayName("一键记录")
        .description("无需打开应用，在桌面轻点即可开始/结束亲喂与睡眠计时，或记下湿/便尿布。")
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
            BedsideLampWidgetView(e: e).containerBackground(for: .widget) {
                Color(red: 0x0B / 255, green: 0x10 / 255, blue: 0x28 / 255)
            }
        }
        .configurationDisplayName("床头台灯")
        .description("专为床头待机（StandBy）与夜间照护设计：暖琥珀微光，抬眼即看计时与上次喂奶。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct BedsideLampWidgetView: View {
    let e: TodayEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        BedsideLampFace(date: e.date, snap: e.snap, body_: e.body, isMedium: family == .systemMedium)
    }
}

// MARK: Control Center, Lock Screen bottom buttons & Action Button controls

struct SleepControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "control.sleep") {
            ControlWidgetButton(action: ToggleCareTimerIntent(careType: .sleep)) {
                Label("睡觉计时", systemImage: "moon.zzz.fill")
            }
        }
        .displayName("睡觉计时")
        .description("在控制中心、锁屏或操作按钮一键开始/结束宝宝睡眠计时。")
    }
}

struct NurseControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "control.nurse") {
            ControlWidgetButton(action: ToggleCareTimerIntent(careType: .nurse)) {
                Label("亲喂计时", systemImage: "heart.circle.fill")
            }
        }
        .displayName("亲喂计时")
        .description("在控制中心、锁屏或操作按钮一键开始/结束亲喂计时。")
    }
}

struct WetDiaperControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "control.diaper.wet") {
            ControlWidgetButton(action: QuickLogDiaperIntent(kind: .wet)) {
                Label("记湿尿布", systemImage: "drop.fill")
            }
        }
        .displayName("记湿尿布")
        .description("在控制中心或锁屏一键记下一次湿尿布。")
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
                        Text(timerState(ctx.attributes.type, side: ctx.state.side, paused: ctx.state.pausedAt != nil)).font(.headline).foregroundStyle(c).lineLimit(1).minimumScaleFactor(0.7)
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
            .activityBackgroundTint(Color(red: 0x0E / 255, green: 0x14 / 255, blue: 0x30 / 255).opacity(dim ? 0.92 : 1))
            .activitySystemActionForegroundColor(.white)
    }
}
