import AppIntents
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Keeps one Live Activity per running timer: started when a timer starts, updated on pause or change of side, ended
/// when the timer ends.
enum LiveTimers {
    static func sync() async {
        #if canImport(ActivityKit)
        let body = JournalFile.read(), timers = body.timers
        let running = Activity<TimerAttributes>.activities
        for a in running where !timers.contains(where: { $0.type == a.attributes.type }) {
            await a.end(nil, dismissalPolicy: .immediate)
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        for t in timers {
            let state = TimerAttributes.ContentState(start: t.countsFrom,
                                                     pausedAt: t.pausedAt.map { Date(timeIntervalSince1970: $0 / 1000) }, side: t.side,
                                                     note: JournalFile.note(for: t, in: body.logs))
            if let a = running.first(where: { $0.attributes.type == t.type }) {
                await a.update(ActivityContent(state: state, staleDate: nil))
            } else {
                _ = try? Activity.request(attributes: TimerAttributes(type: t.type), content: ActivityContent(state: state, staleDate: nil))
            }
        }
        #endif
    }
}

/// A timer button on the Lock Screen, in the Dynamic Island or on the widget: start, pause or resume, change side, end.
struct TimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "计时"
    static var isDiscoverable = false
    @Parameter(title: "类型") var type: String
    @Parameter(title: "动作") var action: String
    init() {}
    init(type: String, action: String) { self.type = type; self.action = action }
    func perform() async throws -> some IntentResult {
        switch action {
        case "start": JournalFile.start(type, side: type == LogType.nurse ? "l" : nil)
        case "pause": JournalFile.togglePause(type)
        case "side": JournalFile.switchSide(type)
        case "tap-l": JournalFile.tapSide(type, "l")
        case "tap-r": JournalFile.tapSide(type, "r")
        default: JournalFile.stop(type)
        }
        await LiveTimers.sync()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// A one-tap entry from the widget (a nappy).
struct QuickLogIntent: AppIntent {
    static var title: LocalizedStringResource = "记一笔"
    static var isDiscoverable = false
    @Parameter(title: "类型") var type: String
    @Parameter(title: "详情") var detail: String
    init() {}
    init(type: String, detail: String) { self.type = type; self.detail = detail }
    func perform() async throws -> some IntentResult {
        JournalFile.add(LogEntry(type: type, start: JournalFile.now(), detail: detail.isEmpty ? nil : detail))
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
