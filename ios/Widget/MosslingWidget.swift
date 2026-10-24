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

// MARK: Home Screen and Lock Screen widget (faces in Shared/WidgetFaces.swift)

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
        .configurationDisplayName("摸索台灯")
        .description("月龄与今天的活动；开启记录后，点按即可打开喂奶、睡眠和尿布的记录页。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

private struct TodayWidgetView: View {
    let e: TodayEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        let size: TodaySize = switch family {
        case .accessoryInline: .inline
        case .accessoryRectangular: .rectangular
        case .systemMedium: .medium
        default: .small
        }
        TodayFace(date: e.date, snap: e.snap, body: e.body, size: size)
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
                        Text(LogType.name(ctx.attributes.type) + TimerFace.side(ctx.state.side)).font(.headline).foregroundStyle(c)
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
