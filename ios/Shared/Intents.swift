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
        ControlCenter.shared.reloadAllControls()
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

/// Diaper state choices exposed to interactive widgets, Control Center, and Siri / Shortcuts.
enum DiaperKindAppEnum: String, AppEnum {
    case wet, dirty, both
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "尿布状态"
    static var caseDisplayRepresentations: [DiaperKindAppEnum: DisplayRepresentation] = [
        .wet: "湿尿布",
        .dirty: "便尿布",
        .both: "湿便都有",
    ]
}

/// Care timer kinds exposed to interactive widgets, Control Center, Action Button, and Siri / Shortcuts.
enum CareTimerAppEnum: String, AppEnum {
    case nurse, sleep
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "计时类型"
    static var caseDisplayRepresentations: [CareTimerAppEnum: DisplayRepresentation] = [
        .nurse: "亲喂",
        .sleep: "睡觉",
    ]
}

/// One-tap diaper logging from Home Screen widgets, Control Center, or Siri without opening the app.
struct QuickLogDiaperIntent: AppIntent {
    static var title: LocalizedStringResource = "记一次尿布"
    static var description = IntentDescription("无需打开应用，直接记下湿尿布、便尿布或湿便都有。")
    @Parameter(title: "状态", default: .wet) var kind: DiaperKindAppEnum

    init() { self.kind = .wet }
    init(kind: DiaperKindAppEnum) { self.kind = kind }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard TimerIntent.canRecord(snapshot: JournalFile.snapshot()) else {
            return .result(dialog: "\(L10n.t("请先在摸索台灯里开启记录并同意本地保存。", "Enable logging and local storage in Mossling first."))")
        }
        JournalFile.quickLog(type: LogType.diaper, detail: kind.rawValue)
        WidgetCenter.shared.reloadAllTimelines()
        let label = kind == .wet ? L10n.t("湿尿布", "Wet diaper") : kind == .dirty ? L10n.t("便尿布", "Dirty diaper") : L10n.t("湿便都有", "Wet & dirty diaper")
        return .result(dialog: "\(L10n.t("已记下：\(label)。", "Logged: \(label)."))")
    }
}

/// One-tap undo for a diaper just logged on a Home Screen widget (reverses accidental taps within 30 seconds).
struct UndoLastDiaperIntent: AppIntent {
    static var title: LocalizedStringResource = "撤销刚刚记下的尿布"
    static var isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        guard TimerIntent.canRecord(snapshot: JournalFile.snapshot()) else { return .result() }
        _ = JournalFile.undoRecent(type: LogType.diaper, withinSeconds: 30)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Cycles today's recommended play directly on the Home Screen widget through this week's curated plays.
struct CycleWidgetPlayIntent: AppIntent {
    static var title: LocalizedStringResource = "换一个今日活动"
    static var isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        _ = JournalFile.cycleWidgetPlay()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Starts or ends a nursing or sleep timer from interactive widgets, Action Button, or Siri.
struct ToggleCareTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "开始或结束计时"
    static var description = IntentDescription("开始或结束亲喂、睡觉计时，并同步到锁屏实时活动。")
    @Parameter(title: "类型", default: .sleep) var careType: CareTimerAppEnum

    init() { self.careType = .sleep }
    init(careType: CareTimerAppEnum) { self.careType = careType }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard TimerIntent.canRecord(snapshot: JournalFile.snapshot()) else {
            return .result(dialog: "\(L10n.t("请先在摸索台灯里开启记录并同意本地保存。", "Enable logging and local storage in Mossling first."))")
        }
        let type = careType == .nurse ? LogType.nurse : LogType.sleep
        let running = (try? JournalFile.load())?.timers.contains(where: { $0.type == type }) ?? false
        if running {
            JournalFile.stop(type)
        } else {
            JournalFile.start(type, side: type == LogType.nurse ? "l" : nil)
        }
        await LiveTimers.sync()
        WidgetCenter.shared.reloadAllTimelines()
        let name = L10n.logName(type)
        return .result(dialog: "\(running ? L10n.t("已结束\(name)计时。", "Ended \(name.lowercased()) timer.") : L10n.t("已开始\(name)计时。", "Started \(name.lowercased()) timer."))")
    }
}

/// Stateful Control Center / Lock Screen toggle intent for sleep and nursing timers.
struct SetCareTimerIntent: SetValueIntent {
    static var title: LocalizedStringResource = "切换照护计时"
    static var isDiscoverable = false
    @Parameter(title: "运行中") var value: Bool
    @Parameter(title: "类型") var careType: CareTimerAppEnum

    init() { self.value = false; self.careType = .sleep }
    init(careType: CareTimerAppEnum) { self.value = false; self.careType = careType }

    func perform() async throws -> some IntentResult {
        guard TimerIntent.canRecord(snapshot: JournalFile.snapshot()) else {
            ControlCenter.shared.reloadAllControls()
            return .result()
        }
        let type = careType == .nurse ? LogType.nurse : LogType.sleep
        if value {
            JournalFile.start(type, side: type == LogType.nurse ? "l" : nil)
        } else {
            JournalFile.stop(type)
        }
        await LiveTimers.sync()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}


