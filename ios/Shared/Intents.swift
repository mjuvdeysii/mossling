import AppIntents
import SwiftUI
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
        snapshot.map { ($0.consented ?? $0.journal) && $0.journal } ?? false
    }
    func perform() async throws -> some IntentResult {
        guard Self.canRecord(snapshot: JournalFile.snapshot()) else {
            await LiveTimers.sync()
            WidgetCenter.shared.reloadAllTimelines()
            return .result()
        }
        switch action {
        case "start": JournalFile.startSmart(type)
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
            return .result(dialog: "\(L10n.t("请先在摸索台灯里开启记录并同意本地保存。", "Enable logging and local storage in Moss & Otto first."))")
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
            return .result(dialog: "\(L10n.t("请先在摸索台灯里开启记录并同意本地保存。", "Enable logging and local storage in Moss & Otto first."))")
        }
        let type = careType == .nurse ? LogType.nurse : LogType.sleep
        let running = (try? JournalFile.load())?.timers.contains(where: { $0.type == type }) ?? false
        if running {
            JournalFile.stop(type)
        } else {
            JournalFile.startSmart(type)
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
            JournalFile.startSmart(type)
        } else {
            JournalFile.stop(type)
        }
        await LiveTimers.sync()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// Bottle milk choices exposed to Siri / Shortcuts.
enum BottleMilkAppEnum: String, AppEnum {
    case formula, breastmilk
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "奶类"
    static var caseDisplayRepresentations: [BottleMilkAppEnum: DisplayRepresentation] = [
        .formula: "配方奶",
        .breastmilk: "母乳",
    ]
}

/// Hands-free bottle logging via Siri or Shortcuts without opening the app.
struct QuickLogBottleIntent: AppIntent {
    static var title: LocalizedStringResource = "记一次瓶喂"
    static var description = IntentDescription("无需打开应用，直接记下瓶喂奶量与母乳或配方奶。")
    @Parameter(title: "奶量（毫升）", default: 90, inclusiveRange: (10, 360)) var amountMl: Int
    @Parameter(title: "种类", default: .formula) var milk: BottleMilkAppEnum

    init() { self.amountMl = 90; self.milk = .formula }
    init(amountMl: Int, milk: BottleMilkAppEnum = .formula) {
        self.amountMl = amountMl
        self.milk = milk
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard TimerIntent.canRecord(snapshot: JournalFile.snapshot()) else {
            return .result(dialog: "\(L10n.t("请先在摸索台灯里开启记录并同意本地保存。", "Enable logging and local storage in Moss & Otto first."))")
        }
        let clamped = max(10, min(360, amountMl))
        JournalFile.quickLog(type: LogType.bottle, detail: milk.rawValue, amount: clamped)
        WidgetCenter.shared.reloadAllTimelines()
        let milkLabel = milk == .breastmilk ? L10n.t("母乳", "breast milk") : L10n.t("配方奶", "formula")
        let vol = L10n.volume(ml: clamped)
        return .result(dialog: "\(L10n.t("已记下瓶喂：\(milkLabel) \(vol)。", "Logged bottle: \(vol) of \(milkLabel)."))")
    }
}

/// Hands-free first-food logging via Siri or Shortcuts without opening the app.
struct QuickLogSolidIntent: AppIntent {
    static var title: LocalizedStringResource = "记一次辅食"
    static var description = IntentDescription("无需打开应用，直接记下宝宝今天吃的辅食或初尝食材。")
    @Parameter(title: "食材名称", default: "") var foodName: String

    init() { self.foodName = "" }
    init(foodName: String = "") { self.foodName = foodName }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard TimerIntent.canRecord(snapshot: JournalFile.snapshot()) else {
            return .result(dialog: "\(L10n.t("请先在摸索台灯里开启记录并同意本地保存。", "Enable logging and local storage in Moss & Otto first."))")
        }
        let trimmed = foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = trimmed.isEmpty ? nil : String(trimmed.prefix(40))
        JournalFile.quickLog(type: LogType.solid, detail: detail)
        WidgetCenter.shared.reloadAllTimelines()
        let spoken = detail ?? L10n.t("辅食", "first food")
        return .result(dialog: "\(L10n.t("已记下辅食：\(spoken)。", "Logged first food: \(spoken)."))")
    }
}

/// Pure testable care status summary shared between `BabyCareStatusIntent` and Siri snippet UI.
struct BabyCareStatusSummary: Equatable {
    let babyName: String
    let activeTimerLabel: String?
    let activeTimerDuration: String?
    let lastFeedPhrase: String
    let lastFeedNote: String?
    let lastWakePhrase: String
    let lastWakeNote: String?
    let todayWetDiapers: Int
    let todayDirtyDiapers: Int
    let dialogText: String

    static func build(body: JournalFile.Body, snap: Snapshot?, now: Date = Date()) -> BabyCareStatusSummary {
        let name = (snap?.nickname.isEmpty == false ? snap?.nickname : nil) ?? L10n.appName
        let nowMs = now.timeIntervalSince1970 * 1000
        let activeTimer = body.timers.first
        let timerLabel = activeTimer.map { L10n.timerStatus($0.type, side: $0.side, paused: $0.pausedAt != nil) }
        let timerDur = activeTimer.map { L10n.duration($0.total($0.pausedAt ?? nowMs)) }

        let feedFact = LastFact.of(LogType.nurse, in: body.logs)
        let wakeFact = LastFact.of(LogType.sleep, in: body.logs)
        let feedPhrase = feedFact?.phrase(now: now, precise: true) ?? L10n.t("今天还没记喂奶", "No feeds logged yet")
        let wakePhrase = wakeFact?.phrase(now: now, precise: true) ?? L10n.t("暂无醒来记录", "No wake time yet")

        let todayDay = Day(now)
        var wetCount = 0
        var dirtyCount = 0
        for e in body.logs where e.type == LogType.diaper && Day(e.startDate) == todayDay {
            let d = e.detail ?? "wet"
            if d == "wet" || d == "both" { wetCount += 1 }
            if d == "dirty" || d == "both" { dirtyCount += 1 }
        }

        var parts: [String] = []
        if let timerLabel, let timerDur {
            parts.append(L10n.t("\(name)正在\(timerLabel)，已\(timerDur)", "\(name): \(timerLabel) for \(timerDur)"))
        }
        parts.append(feedPhrase)
        if wakeFact != nil {
            parts.append(wakePhrase)
        }
        if wetCount + dirtyCount > 0 {
            parts.append(L10n.t("今日尿布：湿 \(wetCount) 便 \(dirtyCount)", "Today's diapers: \(wetCount) wet, \(dirtyCount) dirty"))
        }
        let sep = L10n.isEnglish ? ". " : "；"
        let end = L10n.isEnglish ? "." : "。"
        return BabyCareStatusSummary(
            babyName: name,
            activeTimerLabel: timerLabel,
            activeTimerDuration: timerDur,
            lastFeedPhrase: feedPhrase,
            lastFeedNote: feedFact?.note,
            lastWakePhrase: wakePhrase,
            lastWakeNote: wakeFact?.note,
            todayWetDiapers: wetCount,
            todayDirtyDiapers: dirtyCount,
            dialogText: parts.joined(separator: sep) + end
        )
    }
}

/// Cotton-paper keepsake snippet rendered directly inside Siri / Spotlight after asking for baby status.
struct BabyCareStatusSnippetView: View {
    let summary: BabyCareStatusSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(BedsideLampFace.amber)
                    .frame(width: 9, height: 9)
                Text(summary.babyName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                ArtImage(name: WidgetArt.pair)
                    .frame(width: 28, height: 28)
            }

            if let label = summary.activeTimerLabel, let dur = summary.activeTimerDuration {
                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(WidgetInk.accent)
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 4)
                    Text(dur)
                        .font(WidgetInk.numerals(17))
                        .foregroundStyle(WidgetInk.accent)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(WidgetInk.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Crayon.ink(LogType.color(LogType.nurse)))
                    Text(summary.lastFeedPhrase)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let note = summary.lastFeedNote, !note.isEmpty {
                        Spacer(minLength: 4)
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 8) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Crayon.ink(LogType.color(LogType.sleep)))
                    Text(summary.lastWakePhrase)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer(minLength: 4)
                    Text(L10n.t("尿布 湿\(summary.todayWetDiapers) 便\(summary.todayDirtyDiapers)", "Diapers \(summary.todayWetDiapers)W \(summary.todayDirtyDiapers)D"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(12)
            .background(WidgetInk.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(14)
        .background(WidgetInk.paper, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Hands-free Siri summary: reads out active timer, last feed, last wake, and today's diaper count with a cotton-paper snippet.
struct BabyCareStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "查看宝宝近况"
    static var description = IntentDescription("查看并播报当前计时、上次喂奶与醒来时间，以及今日尿布次数。")

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let body = JournalFile.read()
        let snap = JournalFile.snapshot()
        let summary = BabyCareStatusSummary.build(body: body, snap: snap, now: Date())
        return .result(dialog: "\(summary.dialogText)") {
            BabyCareStatusSnippetView(summary: summary)
        }
    }
}

/// Opens Otto's calm red-shifted Bedside Lamp sanctuary from Control Center, Action Button, or Siri.
struct OpenBedsideLampIntent: AppIntent {
    static var title: LocalizedStringResource = "打开床头夜灯"
    static var description = IntentDescription("立即打开暖琥珀床头夜灯与舒缓声景，夜里不刺眼。")
    static var openAppWhenRun: Bool = true

    init() {}

    func perform() async throws -> some IntentResult & OpensIntent {
        return .result(opensIntent: OpenURLIntent(WidgetLinks.lamp))
    }
}


