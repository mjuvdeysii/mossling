import SwiftUI
import Observation

// Moss 与 Otto 的无言表演层（IP v1.3 第四章：状态机、事件合同与动作参数）。
//
// 规则：
// - 角色不说人类语言。这里没有任何台词、气泡或字幕字段；功能与状态文字一律由中立 UI（提示条、按钮、标题）给出。
// - 表演状态与业务状态分开：业务层只发事件（`MascotEvent`），表演层自己决定怎么动，永远不回写业务数据。
// - 回应只跟在已确认的事件之后：记录写入文件并读回成功才有 acknowledge；写入失败回到中性，不庆祝。
// - 主伙伴只改变谁站在前面、用谁的节奏表演，不改变任何功能；状态机本身与角色无关（两位走同一套状态）。
// - 夜里只减少演出（rest），不暗示改变了屏幕亮度；减弱动态效果时角色静止，装饰动画对旁白隐藏。

/// What the companions are doing, independent of what the app is doing.
enum MascotPresentationState: String, CaseIterable {
    /// The app is in the background; nothing plays.
    case dormant
    /// Mostly still: breathing, a rare blink.
    case idle
    /// A short look towards something that just changed (the week's plays).
    case observing
    /// A feed or a sleep is being timed: the companion watches, calmly, and does nothing else.
    case focusing
    /// One short reply after a record was really saved: at most once per save, at most 550 ms.
    case acknowledge
    /// Night: eyes half-closed, no extra movement.
    case rest
}

/// The events the app sends. The raw values are the names in the IP contract.
enum MascotEvent: String, CaseIterable {
    case recordStartConfirmed = "record.start.confirmed"
    case recordPersistSuccess = "record.persist.success"
    case recordPersistFailure = "record.persist.failure"
    case activityRecommendationChanged = "activity.recommendation.changed"
    case nightmodeEnabled = "nightmode.enabled"
    case nightmodeDisabled = "nightmode.disabled"
    case companionChanged = "companion.changed"
    case appBackground = "app.background"
    case appActive = "app.active"
    case timerEnded = "record.timer.ended"
    /// Internal: a short state has had its time.
    case settle = "presentation.settle"
}

/// The state machine, as a pure function, so it can be tested without any view.
enum MascotMachine {
    /// Where the companions come back to when nothing is happening.
    static func base(night: Bool) -> MascotPresentationState { night ? .rest : .idle }

    static func next(_ s: MascotPresentationState, _ e: MascotEvent, night: Bool, timing: Bool) -> MascotPresentationState {
        switch e {
        case .appBackground: return .dormant
        case .appActive: return timing ? .focusing : base(night: night)
        case .recordStartConfirmed: return .focusing
        case .recordPersistSuccess: return s == .dormant ? s : .acknowledge
        case .recordPersistFailure: return timing ? .focusing : base(night: night)
        case .timerEnded: return timing ? .focusing : base(night: night)
        case .activityRecommendationChanged:
            // a look only when nothing more important is going on, and not at night
            return s == .idle && !night ? .observing : s
        case .nightmodeEnabled: return s == .focusing || s == .dormant ? s : .rest
        case .nightmodeDisabled: return s == .rest ? .idle : s
        case .companionChanged: return s   // appearance only
        case .settle:
            switch s {
            case .acknowledge, .observing: return timing ? .focusing : base(night: night)
            default: return s
            }
        }
    }
}

/// Each companion's own rhythm (IP v1.3 §4.3, the project's proposed values, not Apple requirements). The fields are
/// motion only — there is deliberately no field for words of any kind.
struct MascotStyle: Equatable {
    /// How long one glance takes, in ms (Moss glances twice, quickly; Otto once, slowly).
    let glanceMs: Int
    let glanceStages: Int
    /// One blink, in ms.
    let blinkMs: Int
    /// How far the body tilts when it leans in, in degrees.
    let tiltDegrees: Double
    /// The single reply after a save, in ms (never more than 550).
    let acknowledgeMs: Int
    /// How far behind the body Moss's sprout follows, in ms (Otto has none: his lamp glows instead).
    let sproutLagMs: Int
    /// How long a look at something that changed is held, in ms.
    let observeMs: Int

    static let moss = MascotStyle(glanceMs: 180, glanceStages: 2, blinkMs: 90, tiltDegrees: 4, acknowledgeMs: 420, sproutLagMs: 120, observeMs: 900)
    static let otto = MascotStyle(glanceMs: 300, glanceStages: 1, blinkMs: 180, tiltDegrees: 2, acknowledgeMs: 550, sproutLagMs: 0, observeMs: 1200)
    static func of(_ k: Kind) -> MascotStyle { k == .moss ? .moss : .otto }
}

/// The one place the presentation state lives. Business code only calls `send`.
@Observable
final class MascotDirector {
    private(set) var state: MascotPresentationState = .idle
    /// Counts the acknowledgements, so a view can play its single reply when it changes.
    private(set) var acknowledgements = 0
    /// Counts the looks at something that changed.
    private(set) var observations = 0
    /// Counts the saves that failed: Moss, thwarted, flattens to "a stone again" for a moment (the character bible).
    private(set) var setbacks = 0
    private(set) var night = false
    /// Whether a feed or a sleep is being timed.
    var timing = false
    /// The companion in front: decides whose rhythm is used for the timings, nothing else.
    var companion: Kind = .moss
    /// The events received, newest last (for tests and the review log; kept short).
    private(set) var log: [MascotEvent] = []
    private var settleTask: Task<Void, Never>?

    func send(_ e: MascotEvent) {
        log.append(e); if log.count > 40 { log.removeFirst(log.count - 40) }
        if e == .nightmodeEnabled { night = true }
        if e == .nightmodeDisabled { night = false }
        let old = state
        state = MascotMachine.next(state, e, night: night, timing: timing)
        if state == .acknowledge && e == .recordPersistSuccess { acknowledgements &+= 1 }
        if state == .observing && old != .observing { observations &+= 1 }
        if e == .recordPersistFailure { setbacks &+= 1 }
        if state == .acknowledge || state == .observing {
            let style = MascotStyle.of(companion)
            let ms = state == .acknowledge ? style.acknowledgeMs : style.observeMs
            settleTask?.cancel()
            settleTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(ms))
                guard !Task.isCancelled else { return }
                self?.send(.settle)
            }
        }
    }

    /// The companions' mood for a state; the views add their own look and size.
    static func mood(_ s: MascotPresentationState, rest: Mood = .open) -> Mood {
        switch s {
        case .acknowledge: .happy
        case .rest: rest
        default: .open
        }
    }
    /// Half-closed eyes at night (resting, not asleep).
    static func lid(_ s: MascotPresentationState) -> Double? { s == .rest ? 0.5 : nil }
}

extension Kind {
    /// The character in a few words (a description for the picker, not something the character says).
    var trait: String { self == .moss ? "精力用不完，什么都要先看一眼" : "有点困，但灯一直亮着" }
}
