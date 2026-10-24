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

/// The Lock Screen face with a background in fixed colours for the appearance (paper by day, the lamp's blue at
/// night): a colour that adapts by itself was drawn as an odd gold on a phone's Lock Screen.
private struct LockScreenTimer: View {
    let type: String
    let s: TimerAttributes.ContentState
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        let dark = scheme == .dark
        TimerFace(type: type, s: s)
            .environment(\.colorScheme, scheme)
            .activityBackgroundTint(dark ? Color(red: 0x0E / 255, green: 0x14 / 255, blue: 0x30 / 255) : Color(red: 0xFB / 255, green: 0xF7 / 255, blue: 0xF0 / 255))
            .activitySystemActionForegroundColor(Crayon.ink(LogType.color(type)))
    }
}
