import AppIntents
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Keeps one Live Activity per running timer: started when a timer starts, updated on pause or change of side, ended
/// when the timer ends. Serialized via an actor so concurrent sync calls never request duplicate activities.
actor LiveTimers {
    private static let shared = LiveTimers()
    private var syncing = false
    private var pending = false

    static func sync() async {
        await shared.enqueue()
    }

    private func enqueue() async {
        if syncing { pending = true; return }
        syncing = true
        defer { syncing = false }
        repeat {
            pending = false
            await syncNow()
        } while pending
    }

    private func syncNow() async {
        #if canImport(ActivityKit)
        guard let body = try? JournalFile.load() else { return }
        let timers = body.timers
        let running = Activity<TimerAttributes>.activities
        var kept: Set<String> = []
        for a in running {
            let t = a.attributes.type
            if !timers.contains(where: { $0.type == t }) || !kept.insert(t).inserted {
                await a.end(nil, dismissalPolicy: .immediate)
            }
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let active = Activity<TimerAttributes>.activities
        for t in timers {
            let state = TimerAttributes.ContentState(start: t.countsFrom,
                                                     pausedAt: t.pausedAt.map { Date(timeIntervalSince1970: $0 / 1000) }, side: t.side,
                                                     note: JournalFile.note(for: t, in: body.logs))
            if let a = active.first(where: { $0.attributes.type == t.type }) {
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
    static func canRecord(snapshot: Snapshot?) -> Bool {
        snapshot.map { $0.consented ?? $0.journal } ?? false
    }
    func perform() async throws -> some IntentResult {
        guard Self.canRecord(snapshot: JournalFile.snapshot()) else {
            await LiveTimers.sync()
            WidgetCenter.shared.reloadAllTimelines()
            return .result()
        }
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

