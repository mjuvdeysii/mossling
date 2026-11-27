import Foundation

/// Four progressive developmental gears guiding Tab 1 (`台灯 / Lamp`) from newborn survival tracking
/// to relaxed daytime co-play and keepsake capture.
enum CareGear: Int, CaseIterable, Codable, Sendable {
    case gear1Survival = 1
    case gear2Explore = 2
    case gear3Autonomy = 3
    case gear4Dialogue = 4

    var title: String {
        switch self {
        case .gear1Survival: L10n.t("一档 · 照护护航", "Gear 1 · Early Care")
        case .gear2Explore: L10n.t("二档 · 辅食与探索", "Gear 2 · First Foods & Play")
        case .gear3Autonomy: L10n.t("三档 · 自主与表达", "Gear 3 · Growing Independence")
        case .gear4Dialogue: L10n.t("四档 · 对话与回忆", "Gear 4 · Words & Keepsakes")
        }
    }

    var subtitle: String {
        switch self {
        case .gear1Survival: L10n.t("高频喂睡单手优先 · 夜灯按需展开", "One-tap care first · bedside lamp compact by day")
        case .gear2Explore: L10n.t("喂睡稳步退居轻条 · 主舞台让给辅食与共玩", "Care settles cleanly · solids & play move forward")
        case .gear3Autonomy: L10n.t("情绪翻译与安全边界 · 儿保前自动备好诊室快照", "Behavior cues & checkup snapshots at a glance")
        case .gear4Dialogue: L10n.t("童言对话、假扮故事与三岁回忆册", "Conversations, pretend play & keepsake stories")
        }
    }
}

enum CareGearEngine {
    static let diaperModule = "diaper"
    static let feedsModule = "feeds"
    static let sleepModule = "sleep"

    /// Resolves the active gear from developmental month and optional graduated modules.
    static func resolve(developmentalMonth: Int, graduatedModules: Set<String>) -> CareGear {
        let m = max(0, min(36, developmentalMonth))
        if m >= 24 { return .gear4Dialogue }
        if m >= 12 { return .gear3Autonomy }
        if m >= 6 || graduatedModules.contains(feedsModule) { return .gear2Explore }
        return .gear1Survival
    }

    struct GraduationHint: Equatable, Sendable {
        let moduleKey: String
        let title: String
        let message: String
        let confirmLabel: String
    }

    /// Gently suggests tucking a high-frequency tracking strip into the drawer when natural usage tapers off.
    static func suggestedGraduation(
        developmentalMonth: Int,
        logs: [LogEntry],
        graduatedModules: Set<String>,
        dismissedModules: Set<String>,
        today: Day
    ) -> GraduationHint? {
        let cutoffMs = today.plus(days: -7).date.timeIntervalSince1970 * 1000
        if developmentalMonth >= 2,
           !graduatedModules.contains(diaperModule),
           !dismissedModules.contains(diaperModule),
           !logs.isEmpty,
           !logs.contains(where: { $0.type == LogType.diaper && $0.start >= cutoffMs }) {
            return GraduationHint(
                moduleKey: diaperModule,
                title: L10n.t("排泄节奏已经稳定了", "Diaper Rhythm Settled"),
                message: L10n.t("最近 7 天没有高频记尿布。需要把尿布快捷按钮收进「更多照护」吗？随时可恢复。", "No diapers logged in 7 days. Tuck the diaper button into More Care?"),
                confirmLabel: L10n.t("先收进抽屉", "Tuck Away")
            )
        }
        if developmentalMonth >= 6,
           !graduatedModules.contains(feedsModule),
           !dismissedModules.contains(feedsModule),
           logs.contains(where: { $0.type == LogType.solid }) {
            return GraduationHint(
                moduleKey: feedsModule,
                title: L10n.t("进入半岁探索期了", "Six-Month Milestone"),
                message: L10n.t("宝宝开始吃辅食啦，需要把高频喂奶按钮收纳得更轻量，主屏留给今天照护一览与夜灯吗？", "First foods have begun. Make quick feed buttons lighter on this screen?"),
                confirmLabel: L10n.t("切换二档探索", "Graduate")
            )
        }
        return nil
    }
}

/// Recent 24-hour fever / medication watch snapshot surfacing proactive medical care cards across Explore & Lamp.
struct CareWatchSummary: Equatable, Sendable {
    let latestTemp: LogEntry?
    let latestMed: LogEntry?
    var hasFever: Bool { (latestTemp?.amount ?? 0) >= 380 }
    var hasActivity: Bool { latestTemp != nil || latestMed != nil }

    static func recent24h(in logs: [LogEntry], now: Date = Date()) -> CareWatchSummary {
        let endMs = now.timeIntervalSince1970 * 1000
        let startMs = endMs - 24.0 * 3600.0 * 1000.0
        let temp = logs
            .filter { $0.type == LogType.temp && $0.start >= startMs && $0.start <= endMs }
            .max { $0.start < $1.start }
        let med = logs
            .filter { $0.type == LogType.medicine && $0.start >= startMs && $0.start <= endMs }
            .max { $0.start < $1.start }
        return CareWatchSummary(latestTemp: temp, latestMed: med)
    }
}

/// Pure, tested category filter powering click-to-isolate standalone ledger columns in `LampHubView`.
enum LampHubFilter {
    static let feedKey = "feed"

    static func matches(_ entry: LogEntry, filter: String?) -> Bool {
        guard let filter, !filter.isEmpty else { return true }
        return JournalKinds.matches(entry.type, filter)
    }

    static func filter(_ logs: [LogEntry], by key: String?) -> [LogEntry] {
        guard let key, !key.isEmpty else { return logs }
        return logs.filter { matches($0, filter: key) }
    }

    static func categoryTitle(for key: String?) -> String {
        guard let key, !key.isEmpty else { return L10n.t("全部", "All") }
        return JournalKinds.name(key)
    }

    struct CategoryCount: Identifiable, Equatable {
        let key: String
        let title: String
        let count: Int
        var id: String { key }
    }

    /// Ordered standalone filter pills shown when reviewing a day's ledger.
    static func availableCategories(in logs: [LogEntry], on day: Day) -> [CategoryCount] {
        let own = logs.filter { !$0.carriedOver(into: day) }
        let startMs = day.date.timeIntervalSince1970 * 1000
        let feedCount = logs.feedCount(from: startMs)
        let sleepCount = logs.filter { $0.type == LogType.sleep }.count
        let diaperCount = own.filter { $0.type == LogType.diaper }.count

        var out: [CategoryCount] = []
        if feedCount > 0 { out.append(CategoryCount(key: feedKey, title: L10n.t("喂奶", "Feeds"), count: feedCount)) }
        if sleepCount > 0 { out.append(CategoryCount(key: LogType.sleep, title: L10n.t("睡眠", "Sleep"), count: sleepCount)) }
        if diaperCount > 0 { out.append(CategoryCount(key: LogType.diaper, title: L10n.t("尿布", "Diapers"), count: diaperCount)) }

        for extra in [LogType.solid, LogType.medicine, LogType.temp, LogType.bath, LogType.play, LogType.note] {
            let count = own.filter { $0.type == extra }.count
            if count > 0 {
                out.append(CategoryCount(key: extra, title: LogType.name(extra), count: count))
            }
        }
        return out
    }
}
