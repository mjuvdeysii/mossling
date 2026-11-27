import SwiftUI
import CoreMotion

/// Color-temperature glow presets for Otto's Bedside Lamp (all melatonin-friendly warm wavelengths).
enum LampWarmth: String, CaseIterable, Identifiable {
    case amber, candle, peach
    var id: String { rawValue }

    var label: String {
        switch self {
        case .amber: L10n.t("琥珀光", "Amber")
        case .candle: L10n.t("深烛红", "Candle")
        case .peach: L10n.t("蜜桃暖", "Peach")
        }
    }

    var primaryGlow: Color {
        switch self {
        case .amber: Palette.amber
        case .candle: Color(hex: 0xE56547)
        case .peach: Color(hex: 0xFFD1A3)
        }
    }

    var secondaryTint: Color {
        switch self {
        case .amber: Palette.lampTint
        case .candle: Color(hex: 0x9E2F1B)
        case .peach: Color(hex: 0xE89B6C)
        }
    }

    var highlightCore: Color {
        switch self {
        case .amber: Color(hex: 0xFFE5A3)
        case .candle: Color(hex: 0xFF9F84)
        case .peach: Color(hex: 0xFFF0DB)
        }
    }

    var onPrimaryInk: Color {
        switch self {
        case .amber: Color(hex: 0x261700)
        case .candle: Color(hex: 0x1F0603)
        case .peach: Color(hex: 0x2B1608)
        }
    }

    var actionFill: Color {
        switch self {
        case .amber: Palette.lampTint
        case .candle: Color(hex: 0x9E2F1B)
        case .peach: Color(hex: 0xB86438)
        }
    }

    var actionInk: Color {
        switch self {
        case .amber: Palette.lampInk
        case .candle: Color(hex: 0xFFE8DF)
        case .peach: Color(hex: 0xFFF2E6)
        }
    }

    var secondaryBadgeFill: Color {
        switch self {
        case .amber: Palette.beadLight
        case .candle: Color(hex: 0xFFB8A6)
        case .peach: Color(hex: 0xFFE4CC)
        }
    }

    var dustCoreColor: Color {
        switch self {
        case .amber: Color(hex: 0xFFEBC0)
        case .candle: Color(hex: 0xFFB8A2)
        case .peach: Color(hex: 0xFFF2E0)
        }
    }
}

/// Compact nocturnal care quick-entry mode inside Otto's Bedside Lamp.
enum MidnightQuickCareMode: String, Equatable {
    case diaper
    case bottle
}

/// One factual 2 a.m. status chip ("Feed 2h ago", "Wake 1h ago", "Diaper 3h ago") shown softly inside the Bedside Lamp.
struct MidnightFactItem: Equatable, Identifiable {
    let id: String
    let symbol: String
    let label: String
    let agoText: String
}

/// Pure, testable midnight care snapshot reusing `LastFact` and `SmartBottleVolumes` with zero predictions.
struct MidnightCareSummary: Equatable {
    let facts: [MidnightFactItem]
    let bottleSuggestions: [Int]
    let defaultMilkKind: String
    let nightStatusLine: String?

    static func build(logs: [LogEntry], timers: [RunningTimer] = [], now: Date) -> MidnightCareSummary {
        let nowMs = now.timeIntervalSince1970 * 1000
        var items: [MidnightFactItem] = []
        if let feed = LastFact.of(LogType.nurse, in: logs) {
            items.append(MidnightFactItem(
                id: "feed",
                symbol: LogType.symbol(LogType.nurse),
                label: L10n.t("喂奶", "Feed"),
                agoText: L10n.agoText(feed.at, now: now)
            ))
        }
        if let activeSleep = timers.first(where: { $0.type == LogType.sleep }) {
            let sleepStart = Date(timeIntervalSince1970: activeSleep.start / 1000)
            items.append(MidnightFactItem(
                id: "sleep",
                symbol: LogType.symbol(LogType.sleep),
                label: L10n.t("入睡", "Asleep"),
                agoText: L10n.agoText(sleepStart, now: now)
            ))
        } else if let sleep = LastFact.of(LogType.sleep, in: logs) {
            items.append(MidnightFactItem(
                id: "wake",
                symbol: LogType.symbol(LogType.sleep),
                label: L10n.t("醒来", "Wake"),
                agoText: L10n.agoText(sleep.at, now: now)
            ))
        }
        if let diaper = LastFact.of(LogType.diaper, in: logs) {
            items.append(MidnightFactItem(
                id: "diaper",
                symbol: LogType.symbol(LogType.diaper),
                label: L10n.t("尿布", "Diaper"),
                agoText: L10n.agoText(diaper.at, now: now)
            ))
        }

        let lastBottle = logs
            .filter { $0.type == LogType.bottle }
            .max { $0.start < $1.start }
        let milkKind = lastBottle.flatMap { ["breastmilk", "formula"].contains($0.detail ?? "") ? $0.detail : nil } ?? "formula"

        let hour = Day.cal.component(.hour, from: now)
        let isDaytime = (9..<19).contains(hour)
        let windowStartMs = isDaytime
            ? Day(now).date.timeIntervalSince1970 * 1000
            : nightWindowStartMs(for: now)
        let windowFeeds = logs.filter { $0.start <= nowMs }.feedCount(from: windowStartMs)
        var windowSleepSec = logs.filter { $0.type == LogType.sleep }.reduce(0.0) { acc, entry in
            let entryEnd = min(entry.end ?? nowMs, nowMs)
            let s = max(entry.start, windowStartMs)
            guard entryEnd > s else { return acc }
            let rawSpan = max(1.0, (entryEnd - entry.start) / 1000.0)
            let ratio = entry.start < windowStartMs ? min(1.0, ((entryEnd - s) / 1000.0) / rawSpan) : 1.0
            return acc + min(entry.activeSeconds, rawSpan) * ratio
        }
        if let activeSleep = timers.first(where: { $0.type == LogType.sleep }) {
            let activeEnd = min(activeSleep.pausedAt ?? nowMs, nowMs)
            let activeStart = max(activeSleep.start, windowStartMs)
            if activeEnd > activeStart {
                let rawElapsed = activeSleep.total(nowMs)
                let fullSpan = max(1.0, (activeEnd - activeSleep.start) / 1000.0)
                let ratio = activeSleep.start < windowStartMs ? min(1.0, ((activeEnd - activeStart) / 1000.0) / fullSpan) : 1.0
                windowSleepSec += rawElapsed * ratio
            }
        }

        let statusLine: String?
        if let activeSleep = timers.first(where: { $0.type == LogType.sleep }) {
            let dur = L10n.duration(activeSleep.total(nowMs))
            if windowFeeds > 0 {
                statusLine = isDaytime
                    ? L10n.t("安睡中 \(dur) · 今日喂 \(windowFeeds) 次", "Asleep \(dur) · \(windowFeeds) \(windowFeeds == 1 ? "feed" : "feeds") today")
                    : L10n.t("安睡中 \(dur) · 今夜喂 \(windowFeeds) 次", "Asleep \(dur) · \(windowFeeds) night \(windowFeeds == 1 ? "feed" : "feeds")")
            } else {
                statusLine = L10n.t("安睡中 · 本觉已 \(dur)", "Asleep · \(dur)")
            }
        } else if let activeNurse = timers.first(where: { $0.type == LogType.nurse }) {
            let dur = L10n.duration(activeNurse.total(nowMs))
            let side = activeNurse.side == "r" ? L10n.t("右侧", "R") : L10n.t("左侧", "L")
            if windowSleepSec >= 60 {
                statusLine = isDaytime
                    ? L10n.t("亲喂\(side) \(dur) · 今日睡 \(L10n.duration(windowSleepSec))", "Nursing \(side) \(dur) · Today sleep \(L10n.duration(windowSleepSec))")
                    : L10n.t("亲喂\(side) \(dur) · 今夜已睡 \(L10n.duration(windowSleepSec))", "Nursing \(side) \(dur) · Night sleep \(L10n.duration(windowSleepSec))")
            } else {
                statusLine = L10n.t("亲喂\(side) · 已 \(dur)", "Nursing \(side) · \(dur)")
            }
        } else if let lastWake = LastFact.of(LogType.sleep, in: logs) {
            let awakeSec = now.timeIntervalSince(lastWake.at)
            if awakeSec >= 60 && awakeSec < 14 * 3600 {
                if windowSleepSec >= 60 {
                    statusLine = isDaytime
                        ? L10n.t("已醒 \(L10n.duration(awakeSec)) · 今日睡 \(L10n.duration(windowSleepSec))", "Awake \(L10n.duration(awakeSec)) · Today sleep \(L10n.duration(windowSleepSec))")
                        : L10n.t("已醒 \(L10n.duration(awakeSec)) · 今夜睡 \(L10n.duration(windowSleepSec))", "Awake \(L10n.duration(awakeSec)) · Night sleep \(L10n.duration(windowSleepSec))")
                } else {
                    statusLine = L10n.t("已醒 \(L10n.duration(awakeSec))", "Awake \(L10n.duration(awakeSec))")
                }
            } else {
                statusLine = windowSummaryFallback(sleepSec: windowSleepSec, feeds: windowFeeds, daytime: isDaytime)
            }
        } else {
            statusLine = windowSummaryFallback(sleepSec: windowSleepSec, feeds: windowFeeds, daytime: isDaytime)
        }

        return MidnightCareSummary(
            facts: items,
            bottleSuggestions: SmartBottleVolumes.suggestions(lastMl: lastBottle?.amount),
            defaultMilkKind: milkKind,
            nightStatusLine: statusLine
        )
    }

    private static func nightWindowStartMs(for now: Date) -> Double {
        let cal = Day.cal
        let hour = cal.component(.hour, from: now)
        let baseDay = hour >= 19 ? now : (cal.date(byAdding: .day, value: -1, to: now) ?? now)
        let anchor = cal.date(bySettingHour: 19, minute: 0, second: 0, of: baseDay) ?? baseDay
        return anchor.timeIntervalSince1970 * 1000
    }

    private static func windowSummaryFallback(sleepSec: Double, feeds: Int, daytime: Bool) -> String? {
        if sleepSec >= 60 {
            return daytime
                ? L10n.t("今日睡 \(L10n.duration(sleepSec))", "Today sleep \(L10n.duration(sleepSec))")
                : L10n.t("今夜已睡 \(L10n.duration(sleepSec))", "Night sleep \(L10n.duration(sleepSec))")
        }
        if feeds > 0 {
            return daytime
                ? L10n.t("今日已喂 \(feeds) 次", "\(feeds) \(feeds == 1 ? "feed" : "feeds") today")
                : L10n.t("今夜已喂 \(feeds) 次", "\(feeds) night \(feeds == 1 ? "feed" : "feeds")")
        }
        return nil
    }
}

/// Soothing palm-pat tempo presets matching relaxed resting heart-rate rhythms.
enum PalmPatPreset: Int, CaseIterable, Identifiable, Sendable {
    case awake60 = 60
    case settling54 = 54
    case deep48 = 48

    var id: Int { rawValue }
    var bpm: Double { Double(rawValue) }

    var label: String {
        switch self {
        case .awake60: L10n.t("轻抚 60", "Calm 60")
        case .settling54: L10n.t("渐缓 54", "Settle 54")
        case .deep48: L10n.t("深睡 48", "Deep 48")
        }
    }
}

/// Pure, testable silent palm-pat cadence math (automatic gradual deceleration toward 48 BPM + tap-tempo extraction).
enum PalmPatRhythm {
    static func intervalSeconds(bpm: Double) -> Double {
        let clamped = max(42.0, min(72.0, bpm))
        return 60.0 / clamped
    }

    static func effectiveBPM(startBPM: Double, elapsedSeconds: Double, autoSlow: Bool) -> Double {
        let base = max(46.0, min(72.0, startBPM))
        guard autoSlow, base > 48.0, elapsedSeconds > 0 else { return base }
        let progress = min(1.0, elapsedSeconds / 300.0)
        return max(46.0, base - (base - 48.0) * progress)
    }

    /// Exact continuous analytical integral of `bpm(u)/60` over `0...elapsedSeconds`, preventing
    /// epoch-multiplication strobe jumps when `autoSlow` gradually lowers BPM.
    static func phaseFraction(startBPM: Double, elapsedSeconds: Double, autoSlow: Bool) -> Double {
        let t = max(0.0, elapsedSeconds)
        let base = max(46.0, min(72.0, startBPM))
        let cycles: Double
        if !autoSlow || base <= 48.0 || t <= 0 {
            cycles = t * base / 60.0
        } else {
            let ramp = min(t, 300.0)
            let endRampBPM = base - (base - 48.0) * (ramp / 300.0)
            let avgRampBPM = 0.5 * (base + endRampBPM)
            let rampCycles = ramp * avgRampBPM / 60.0
            let tailCycles = max(0.0, t - 300.0) * (48.0 / 60.0)
            cycles = rampCycles + tailCycles
        }
        return cycles.truncatingRemainder(dividingBy: 1.0)
    }

    static func bpmFromTapTimestamps(_ timestamps: [TimeInterval]) -> Double? {
        guard timestamps.count >= 3 else { return nil }
        let recent = Array(timestamps.suffix(5))
        var intervals: [Double] = []
        for idx in 1..<recent.count {
            let dt = recent[idx] - recent[idx - 1]
            if dt >= 0.45 && dt <= 2.4 {
                intervals.append(dt)
            }
        }
        guard !intervals.isEmpty else { return nil }
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        guard mean > 0 else { return nil }
        return max(42.0, min(72.0, (60.0 / mean).rounded()))
    }
}

/// Otto's Living Bedside Lamp (床头夜灯): a full-screen zero-glare midnight sanctuary for 3 a.m. feeds and settling.
/// Features a vertical thumb-slide warm dimmer & double-tap quick-dim, 3 warmth color presets, gyroscope pendulum glow,
/// six zero-asset real-time soothing soundscapes with dual-layer mixing & auto-fade, and midnight care controls.
struct BedsideLampView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Initial brightness (0.15...1.0), configurable for previews and deterministic screenshots.
    @State private var brightness: Double
    @State private var warmth: LampWarmth
    @State private var dragStartBrightness: Double? = nil
    @State private var lastDetentStep: Int = -1
    @State private var showingDimmerHint = true
    @State private var breathingGuide: Bool
    @State private var breathingHaptics = false
    @State private var palmPatActive: Bool
    @State private var palmPatBPM: Double = 60
    @State private var palmPatAutoSlow: Bool = true
    @State private var palmPatStartedAt: Date = Date()
    @State private var palmPatTapLog: [TimeInterval] = []
    @State private var palmPatWaveTick: Int = 0
    @State private var soundscape = SoundscapeEngine.shared
    @State private var motion = LampTiltObserver()
    @State private var pulse = false
    @State private var volumeMonitor: EarSafeVolumeMonitor
    @State private var countedPresentation = false
    @State private var savedScreenBrightness: CGFloat? = nil
    @State private var emberResting = false
    @State private var quickCareMode: MidnightQuickCareMode?
    @State private var bottleMilkKind: String = "formula"
    private let previewClock: Date?
    private let persistsToAppModel: Bool

    init(
        initialBrightness: Double? = nil,
        initialBreathingGuide: Bool? = nil,
        initialPalmPat: Bool? = nil,
        initialWarmth: LampWarmth? = nil,
        initialQuickCare: MidnightQuickCareMode? = nil,
        previewClock: Date? = nil,
        previewVolume: Float? = nil
    ) {
        let clamped = max(0.15, min(1.0, initialBrightness ?? 0.72))
        _brightness = State(initialValue: clamped)
        _breathingGuide = State(initialValue: initialBreathingGuide ?? false)
        _palmPatActive = State(initialValue: initialPalmPat ?? false)
        _warmth = State(initialValue: initialWarmth ?? .amber)
        _quickCareMode = State(initialValue: initialQuickCare)
        _volumeMonitor = State(initialValue: EarSafeVolumeMonitor(previewVolume: previewVolume))
        self.previewClock = previewClock
        self.persistsToAppModel = initialBrightness == nil
            && initialBreathingGuide == nil
            && initialPalmPat == nil
            && initialWarmth == nil
            && initialQuickCare == nil
            && previewClock == nil
    }

    /// Computes live lamp brightness coupled with any finite soundscape auto-fade envelope and post-fade ember rest.
    nonisolated static func effectiveBrightness(
        baseBrightness: Double,
        remainingSeconds: Int?,
        isFinitePlaying: Bool,
        emberResting: Bool
    ) -> Double {
        let clampedBase = max(0.15, min(1.0, baseBrightness))
        if emberResting {
            return 0.10
        }
        guard isFinitePlaying, let rem = remainingSeconds, rem <= 20 else {
            return clampedBase
        }
        let fade = Double(SoundscapeEngine.fadeMultiplier(remaining: Double(rem), fadeDuration: 20))
        return 0.12 + (clampedBase - 0.12) * fade
    }

    private var isFiniteSoundscapePlaying: Bool {
        soundscape.isPlaying && soundscape.duration != .continuous
    }

    private var displayedBrightness: Double {
        Self.effectiveBrightness(
            baseBrightness: brightness,
            remainingSeconds: soundscape.remainingSeconds,
            isFinitePlaying: isFiniteSoundscapePlaying,
            emberResting: emberResting
        )
    }

    /// Maps the Bedside Lamp dimmer (0.15...1.0) to a gentle physical screen ceiling without ever raising user brightness.
    nonisolated static func targetScreenBrightness(lampBrightness: Double, savedSystemBrightness: Double) -> Double {
        let clampedSaved = max(0.0, min(1.0, savedSystemBrightness))
        let norm = max(0.0, min(1.0, (lampBrightness - 0.15) / 0.85))
        let ceiling = 0.06 + norm * 0.44
        return min(clampedSaved, ceiling)
    }

    private var activeTimer: RunningTimer? { j.timers.first }
    private var isSleeping: Bool { j.timers.contains { $0.type == LogType.sleep && $0.pausedAt == nil } }
    private var lastNurseSide: String? { j.logs.filter { $0.type == LogType.nurse }.max { $0.start < $1.start }?.side }
    private var suggestedSide: String { lastNurseSide == "l" ? "r" : "l" }

    /// Computes smooth 4s inhale / 6s exhale breathing halo progress (0...1) and phase text for calm soothing.
    nonisolated static func breathingState(at time: TimeInterval) -> (progress: Double, inhaling: Bool, secondsLeft: Int) {
        let cycle = 10.0
        let pos = time.truncatingRemainder(dividingBy: cycle)
        let p = pos < 0 ? pos + cycle : pos
        if p < 4.0 {
            let x = p / 4.0
            let smooth = 0.5 - 0.5 * cos(.pi * x)
            return (smooth, true, max(1, Int(ceil(4.0 - p))))
        } else {
            let x = (p - 4.0) / 6.0
            let smooth = 0.5 + 0.5 * cos(.pi * x)
            return (smooth, false, max(1, Int(ceil(10.0 - p))))
        }
    }

    /// Computes exact remaining seconds until the next 4-6 breathing boundary (`0s` inhale or `4s` exhale).
    nonisolated static func nextBreathingBoundary(at time: TimeInterval) -> (delay: TimeInterval, nextInhaling: Bool) {
        let cycle = 10.0
        let pos = time.truncatingRemainder(dividingBy: cycle)
        let p = pos < 0 ? pos + cycle : pos
        if p < 4.0 {
            return (max(0.05, 4.0 - p), false)
        } else {
            return (max(0.05, 10.0 - p), true)
        }
    }

    private var breathingHapticsActive: Bool {
        breathingGuide && breathingHaptics && !emberResting && scenePhase == .active && !Perf.still && previewClock == nil
    }

    private var palmPatTaskKey: String {
        "\(palmPatActive && !emberResting && scenePhase == .active && !Perf.still && previewClock == nil)-\(Int(palmPatBPM))-\(palmPatAutoSlow)-\(palmPatWaveTick)"
    }

    private var livePalmPatBPM: Double {
        let elapsed = max(0, Date().timeIntervalSince(palmPatStartedAt))
        return PalmPatRhythm.effectiveBPM(startBPM: palmPatBPM, elapsedSeconds: elapsed, autoSlow: palmPatAutoSlow)
    }

    private func recordPalmPatTap() {
        rekindleFromEmber()
        let now = Date().timeIntervalSinceReferenceDate
        palmPatTapLog = palmPatTapLog.filter { now - $0 <= 3.0 } + [now]
        if let detected = PalmPatRhythm.bpmFromTapTimestamps(palmPatTapLog) {
            palmPatBPM = detected
            palmPatStartedAt = Date()
        }
        TactileEngine.shared.palmPatPulse(intensity: 0.60)
        palmPatWaveTick += 1
    }

    var body: some View {
        ZStack {
            backdrop
            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        topBar
                            .padding(.horizontal, 20)
                            .padding(.top, 10)

                        Spacer(minLength: 10)

                        lanternCenterpiece
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .trailing) {
                                dimmerRail
                                    .padding(.trailing, 10)
                            }

                        Spacer(minLength: 6)

                        VStack(spacing: 12) {
                            if soundscape.isPlaying && volumeMonitor.shouldShow(for: .lamp) {
                                LampHighVolumePill(volumePercent: volumeMonitor.volumePercent) {
                                    withAnimation(.snappy) {
                                        volumeMonitor.acknowledge(context: .lamp)
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                            soundscapeDeck
                            if app.journal {
                                careDock
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                    }
                    .frame(minHeight: geo.size.height)
                }
            }
            .overlay(alignment: .top) {
                if let toast = j.toast {
                    lampToastBanner(toast)
                        .padding(.top, 58)
                        .padding(.horizontal, 18)
                        .transition(reduce ? .opacity : .move(edge: .top).combined(with: .opacity))
                        .id(toast.id)
                }
            }
            .animation(reduce ? nil : .snappy, value: j.toast?.id)
        }
        .lamp(true)
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
        .gesture(dimmerGesture)
        .onAppear {
            bottleMilkKind = MidnightCareSummary.build(logs: j.logs, now: previewClock ?? Date()).defaultMilkKind
            if !countedPresentation {
                countedPresentation = true
                app.bedsideLampPresentedCount += 1
            }
            if persistsToAppModel {
                brightness = app.lampBrightness
                warmth = LampWarmth(rawValue: app.lampWarmthRaw) ?? .amber
                breathingGuide = app.lampBreathingGuide
            }
            if soundscape.didFinishAutoFade && !soundscape.isPlaying && persistsToAppModel {
                emberResting = true
                UIApplication.shared.isIdleTimerDisabled = false
            } else {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            volumeMonitor.start()
            if scenePhase == .active {
                applyScreenDimmerIfAllowed()
            }
            if !reduce {
                motion.start()
                withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
        .onChange(of: soundscape.didFinishAutoFade) { _, finished in
            guard finished, !soundscape.isPlaying else { return }
            withAnimation(reduce ? nil : .easeOut(duration: 0.9)) {
                emberResting = true
            }
            UIApplication.shared.isIdleTimerDisabled = false
            applyScreenDimmerIfAllowed()
        }
        .onChange(of: soundscape.isPlaying) { _, playing in
            if playing {
                rekindleFromEmber()
            }
        }
        .onChange(of: soundscape.remainingSeconds) { _, rem in
            guard isFiniteSoundscapePlaying, let rem, rem <= 20, scenePhase == .active else { return }
            applyScreenDimmerIfAllowed()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                applyScreenDimmerIfAllowed()
                if !reduce { motion.start() }
            } else {
                restoreScreenBrightness()
                motion.stop()
            }
        }
        .onDisappear {
            if countedPresentation {
                countedPresentation = false
                app.bedsideLampPresentedCount = max(0, app.bedsideLampPresentedCount - 1)
            }
            restoreScreenBrightness()
            soundscape.clearAutoFadeNotice()
            UIApplication.shared.isIdleTimerDisabled = false
            volumeMonitor.stop()
            motion.stop()
        }
        .task(id: breathingHapticsActive) {
            guard breathingHapticsActive else { return }
            while !Task.isCancelled {
                let step = Self.nextBreathingBoundary(at: Date().timeIntervalSinceReferenceDate)
                try? await Task.sleep(for: .seconds(step.delay))
                guard !Task.isCancelled, breathingHapticsActive else { return }
                TactileEngine.shared.breathCue(inhaling: step.nextInhaling)
            }
        }
        .task(id: palmPatTaskKey) {
            guard palmPatActive, !emberResting, scenePhase == .active, !Perf.still, previewClock == nil else { return }
            while !Task.isCancelled {
                let interval = PalmPatRhythm.intervalSeconds(bpm: livePalmPatBPM)
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled, palmPatActive, !emberResting, scenePhase == .active else { return }
                TactileEngine.shared.palmPatPulse(intensity: 0.56)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func rekindleFromEmber() {
        soundscape.clearAutoFadeNotice()
        guard emberResting else { return }
        withAnimation(reduce ? nil : .easeOut(duration: 0.35)) {
            emberResting = false
        }
        UIApplication.shared.isIdleTimerDisabled = true
        applyScreenDimmerIfAllowed()
    }

    private var canAdjustHardwareScreen: Bool {
        previewClock == nil
            && !Perf.still
            && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    }

    private var activeScreen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?.screen
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.screen
    }

    private func applyScreenDimmerIfAllowed() {
        guard canAdjustHardwareScreen, let screen = activeScreen else { return }
        if savedScreenBrightness == nil {
            savedScreenBrightness = screen.brightness
        }
        let baseline = Double(savedScreenBrightness ?? screen.brightness)
        let target = CGFloat(Self.targetScreenBrightness(lampBrightness: displayedBrightness, savedSystemBrightness: baseline))
        if abs(screen.brightness - target) > 0.01 {
            screen.brightness = target
        }
    }

    private func restoreScreenBrightness() {
        guard let saved = savedScreenBrightness else { return }
        savedScreenBrightness = nil
        guard canAdjustHardwareScreen, let screen = activeScreen else { return }
        screen.brightness = saved
    }

    private func commitLampPreferences() {
        guard persistsToAppModel else { return }
        app.lampBrightness = brightness
        app.lampWarmthRaw = warmth.rawValue
        app.lampBreathingGuide = breathingGuide
    }

    // MARK: - Living Midnight Backdrop & Gyro Pendulum Light

    private var backdrop: some View {
        let swayX = reduce ? 0 : motion.roll * 26
        let swayY = reduce ? 0 : motion.pitch * 18
        let b = displayedBrightness
        return ZStack {
            // Deep OLED-friendly midnight indigo sinking smoothly to near-black when dimmed
            LinearGradient(
                colors: [
                    Color(hex: 0x0D1430).mix(with: Color(hex: 0x04060E), by: (1 - b) * 0.78),
                    Color(hex: 0x070B1C).mix(with: Color(hex: 0x020308), by: (1 - b) * 0.85)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Warm overhead lamp cone that sways gently like a hanging lantern as you hold the phone
            RadialGradient(
                colors: [
                    warmth.primaryGlow.opacity(0.42 * b * (pulse ? 1.0 : 0.88)),
                    warmth.secondaryTint.opacity(0.22 * b),
                    Color(hex: 0x5E2E04).opacity(0.08 * b),
                    .clear
                ],
                center: UnitPoint(x: 0.5 + swayX / 600, y: 0.34 + swayY / 800),
                startRadius: 12,
                endRadius: 340 + 130 * b
            )
            .offset(x: swayX, y: swayY)

            // Soft secondary candle reflection at foot of the nursery table
            RadialGradient(
                colors: [
                    warmth.primaryGlow.opacity(0.14 * b),
                    .clear
                ],
                center: UnitPoint(x: 0.5 - swayX / 900, y: 0.88),
                startRadius: 0,
                endRadius: 280
            )

            // Whisper-soft warm dust motes rising in Otto's beam
            if !reduce && !Perf.still {
                LampDustCanvas(brightness: b, glowColor: warmth.primaryGlow, coreColor: warmth.dustCoreColor)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .center) {
            Button {
                TactileEngine.shared.beadClick()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Palette.lampInk.opacity(0.86))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color(hex: 0x1A2346).opacity(0.75)))
                    .overlay(Circle().strokeBorder(warmth.primaryGlow.opacity(0.22), lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(.toy)
            .accessibilityLabel(L10n.t("关闭夜灯", "Close Bedside Lamp"))

            Spacer()

            TimelineView(.periodic(from: .now, by: 30)) { tl in
                VStack(spacing: 2) {
                    Text(hm(previewClock ?? tl.date))
                        .font(Typeface.numerals(20, relativeTo: .title3, weight: .bold))
                        .foregroundStyle(Palette.lampInk.opacity(0.55 + 0.4 * displayedBrightness))
                    Text(
                        dragStartBrightness != nil
                            ? L10n.t("暖光 \(Int((brightness * 100).rounded()))%", "Warmth \(Int((brightness * 100).rounded()))%")
                            : (emberResting
                                ? L10n.t("声景已随夜色轻褪", "Ember rest · sound faded")
                                : (soundscape.activeSummary ?? L10n.t("Otto 的床头夜灯", "Otto's Bedside Lamp")))
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(warmth.primaryGlow.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .contentTransition(.opacity)
                }
            }

            Spacer()

            // Right soothing controls: Silent Palm-Pat & 4-6 Calm Breathing Halo
            HStack(spacing: 6) {
                Button {
                    TactileEngine.shared.beadClick()
                    rekindleFromEmber()
                    withAnimation(reduce ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                        palmPatActive.toggle()
                        if palmPatActive {
                            breathingGuide = false
                            palmPatStartedAt = Date()
                            palmPatTapLog = []
                        }
                    }
                    if palmPatActive {
                        TactileEngine.shared.palmPatPulse(intensity: 0.54)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: palmPatActive ? "hand.tap.fill" : "hand.tap")
                            .font(.footnote.weight(.semibold))
                        Text(L10n.t("轻拍", "Pat"))
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundStyle(palmPatActive ? warmth.onPrimaryInk : warmth.primaryGlow.opacity(0.92))
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background(Capsule().fill(palmPatActive ? warmth.primaryGlow : Color(hex: 0x1A2346).opacity(0.75)))
                    .overlay(Capsule().strokeBorder(warmth.primaryGlow.opacity(palmPatActive ? 0.85 : 0.28), lineWidth: 1))
                    .pillHitTarget()
                }
                .buttonStyle(.toy)
                .accessibilityLabel(L10n.t(palmPatActive ? "关闭无声掌心轻拍安抚" : "开启无声掌心轻拍安抚", palmPatActive ? "Turn off silent palm-pat soother" : "Turn on silent palm-pat soother"))

                Button {
                    TactileEngine.shared.beadClick()
                    rekindleFromEmber()
                    withAnimation(reduce ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                        breathingGuide.toggle()
                        if breathingGuide {
                            palmPatActive = false
                        }
                    }
                    commitLampPreferences()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: breathingGuide ? "circle.circle.fill" : "circle.circle")
                            .font(.footnote.weight(.semibold))
                        Text(L10n.t("4–6 呼吸", "4–6"))
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .foregroundStyle(breathingGuide ? warmth.onPrimaryInk : warmth.primaryGlow.opacity(0.92))
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .frame(minWidth: 44)
                    .background(Capsule().fill(breathingGuide ? warmth.primaryGlow : Color(hex: 0x1A2346).opacity(0.75)))
                    .overlay(Capsule().strokeBorder(warmth.primaryGlow.opacity(breathingGuide ? 0.85 : 0.28), lineWidth: 1))
                    .pillHitTarget()
                }
                .buttonStyle(.toy)
                .accessibilityLabel(L10n.t(breathingGuide ? "关闭 4–6 慢呼吸光晕" : "开启 4–6 哄睡慢呼吸光晕", breathingGuide ? "Turn off calm breathing halo" : "Start 4–6 calm breathing halo"))
            }
        }
    }

    // MARK: - Living Otto Centerpiece

    private var lanternCenterpiece: some View {
        let swayX = reduce ? 0 : motion.roll * 10
        let b = displayedBrightness
        let resting = emberResting || isSleeping
        return VStack(spacing: 8) {
            ZStack {
                Color.clear
                    .contentShape(Circle())
                    .onTapGesture {
                        if emberResting {
                            TactileEngine.shared.beadClick()
                            rekindleFromEmber()
                        } else if palmPatActive {
                            recordPalmPatTap()
                        }
                    }
                    .onTapGesture(count: 2) {
                        guard !palmPatActive else { return }
                        TactileEngine.shared.dimmerTick()
                        showingDimmerHint = false
                        rekindleFromEmber()
                        withAnimation(reduce ? nil : .easeInOut(duration: 0.28)) {
                            brightness = brightness <= 0.35 ? 0.78 : 0.22
                        }
                        applyScreenDimmerIfAllowed()
                        commitLampPreferences()
                    }

                if palmPatActive && !emberResting {
                    TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduce || Perf.still || scenePhase != .active)) { tl in
                        let elapsed = (reduce || Perf.still) ? 0.28 : max(0, tl.date.timeIntervalSince(palmPatStartedAt))
                        let phase = PalmPatRhythm.phaseFraction(startBPM: palmPatBPM, elapsedSeconds: elapsed, autoSlow: palmPatAutoSlow)
                        let pulseWave = exp(-phase * 3.4)
                        let ringSize: CGFloat = 132 + CGFloat(phase) * 56

                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            warmth.highlightCore.opacity((0.36 + 0.34 * pulseWave) * b),
                                            warmth.primaryGlow.opacity((0.16 + 0.18 * pulseWave) * b),
                                            .clear
                                        ],
                                        center: .center,
                                        startRadius: 12,
                                        endRadius: 108
                                    )
                                )
                                .frame(width: 212, height: 212)

                            Circle()
                                .strokeBorder(warmth.primaryGlow.opacity(max(0.08, (1.0 - phase) * 0.68 * b)), lineWidth: 2.0)
                                .frame(width: ringSize, height: ringSize)
                        }
                    }
                    .allowsHitTesting(false)
                } else if breathingGuide && !emberResting {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduce || Perf.still || scenePhase != .active)) { tl in
                        let st = Self.breathingState(at: (reduce || Perf.still) ? 2.8 : tl.date.timeIntervalSinceReferenceDate)
                        let ringSize: CGFloat = 132 + CGFloat(st.progress) * 56
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            warmth.highlightCore.opacity((0.28 + 0.30 * st.progress) * b),
                                            warmth.primaryGlow.opacity((0.14 + 0.16 * st.progress) * b),
                                            .clear
                                        ],
                                        center: .center,
                                        startRadius: 18,
                                        endRadius: ringSize * 0.62
                                    )
                                )
                                .frame(width: ringSize + 36, height: ringSize + 36)

                            Circle()
                                .strokeBorder(warmth.primaryGlow.opacity((0.40 + 0.44 * st.progress) * b), lineWidth: 2.0)
                                .frame(width: ringSize, height: ringSize)

                            Circle()
                                .strokeBorder(warmth.highlightCore.opacity((0.18 + 0.22 * st.progress) * b), lineWidth: 1.0)
                                .frame(width: ringSize + 20, height: ringSize + 20)
                        }
                    }
                    .allowsHitTesting(false)
                } else if soundscape.isPlaying && !emberResting {
                    // Acoustic-luminous envelope coupled to the real DSP cadence of the active soundscape(s)
                    TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduce || Perf.still || scenePhase != .active)) { tl in
                        let t = (reduce || Perf.still) ? 0.35 : tl.date.timeIntervalSinceReferenceDate
                        let env = SoundscapeRhythmEnvelope.compositePulse(
                            primary: soundscape.active,
                            secondary: soundscape.secondary,
                            at: t
                        )
                        ZStack {
                            ForEach(0..<3, id: \.self) { idx in
                                let ringWave = max(0.0, min(1.0, env - Double(idx) * 0.08))
                                let diam = 136 + CGFloat(idx) * 36 + CGFloat(ringWave) * 18
                                Circle()
                                    .strokeBorder(
                                        warmth.primaryGlow.opacity((0.12 + 0.22 * ringWave - Double(idx) * 0.04) * b),
                                        lineWidth: 1.2 + CGFloat(ringWave) * 0.5
                                    )
                                    .frame(width: diam, height: diam)
                            }

                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            warmth.highlightCore.opacity((0.40 + 0.32 * env) * b),
                                            warmth.primaryGlow.opacity((0.18 + 0.22 * env) * b),
                                            .clear
                                        ],
                                        center: .center,
                                        startRadius: 4,
                                        endRadius: 96 + CGFloat(env) * 20
                                    )
                                )
                                .frame(width: 212, height: 212)
                                .offset(x: swayX * 0.6, y: -12)
                        }
                    }
                    .allowsHitTesting(false)
                } else {
                    // Warm glow right behind Otto's golden bead
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    warmth.highlightCore.opacity(0.55 * b),
                                    warmth.primaryGlow.opacity(0.28 * b),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 4,
                                endRadius: 102
                            )
                        )
                        .frame(width: 204, height: 204)
                        .offset(x: swayX * 0.6, y: -12)
                        .allowsHitTesting(false)
                }

                Creature(
                    kind: .otto,
                    mood: resting ? .sleep : .open,
                    look: CGPoint(x: 0, y: 0.2),
                    lid: emberResting ? 0.92 : (isSleeping ? 0.9 : 0.52),
                    lean: reduce ? 0 : motion.roll * 5.0,
                    alive: !emberResting,
                    poke: false,
                    label: L10n.t("Otto 提着床头夜灯陪着你们", "Otto holding the warm bedside lamp"),
                    glow: true
                )
                .frame(width: 136, height: 136)
                .opacity(0.55 + 0.45 * b)
            }
            .frame(minHeight: 142, idealHeight: 176, maxHeight: 186)
            .layoutPriority(-1)

            let modeControls = HStack(spacing: 8) {
                if emberResting {
                    Button {
                        TactileEngine.shared.beadClick()
                        rekindleFromEmber()
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(warmth.primaryGlow.opacity(0.75))
                                .frame(width: 6, height: 6)
                            Text(L10n.t("余烬 · 重燃", "Ember · Relight"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(warmth.primaryGlow.opacity(0.92))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(warmth.primaryGlow.opacity(0.14)))
                        .pillHitTarget()
                    }
                    .buttonStyle(.plain)

                    Button {
                        TactileEngine.shared.beadClick()
                        soundscape.duration = .m15
                        soundscape.start(soundscape.lastUsedKind)
                        rekindleFromEmber()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.caption2.weight(.bold))
                            Text(L10n.t("续播 15m", "15m Encore"))
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .foregroundStyle(warmth.onPrimaryInk)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(warmth.primaryGlow.opacity(0.88)))
                        .pillHitTarget()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("续播 15 分钟安抚声景", "Play 15-minute soundscape encore"))
                } else if palmPatActive {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(warmth.primaryGlow)
                            .frame(width: 6, height: 6)
                        Text(L10n.t("无声轻拍 \(Int(livePalmPatBPM.rounded())) · 点灯定拍", "Silent Pat \(Int(livePalmPatBPM.rounded()))"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(warmth.primaryGlow.opacity(0.95))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(warmth.primaryGlow.opacity(0.15)))

                    ForEach(PalmPatPreset.allCases) { preset in
                        let on = Int(palmPatBPM.rounded()) == preset.rawValue
                        Button {
                            TactileEngine.shared.beadClick()
                            palmPatBPM = preset.bpm
                            palmPatStartedAt = Date()
                            TactileEngine.shared.palmPatPulse(intensity: 0.54)
                        } label: {
                            Text("\(preset.rawValue)")
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(on ? warmth.onPrimaryInk : warmth.primaryGlow.opacity(0.9))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(on ? warmth.primaryGlow : Color(hex: 0x161E3B).opacity(0.76)))
                                .pillHitTarget()
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        TactileEngine.shared.beadClick()
                        palmPatAutoSlow.toggle()
                        palmPatStartedAt = Date()
                    } label: {
                        Text(L10n.t("渐缓", "Slow"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palmPatAutoSlow ? warmth.onPrimaryInk : warmth.primaryGlow.opacity(0.86))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(palmPatAutoSlow ? warmth.primaryGlow : Color(hex: 0x161E3B).opacity(0.76)))
                            .pillHitTarget()
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(palmPatAutoSlow ? .isSelected : [])
                } else if breathingGuide {
                    TimelineView(.animation(minimumInterval: 0.25, paused: reduce || Perf.still || scenePhase != .active)) { tl in
                        let st = Self.breathingState(at: (reduce || Perf.still) ? 2.8 : tl.date.timeIntervalSinceReferenceDate)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(warmth.primaryGlow.opacity(st.inhaling ? 0.95 : 0.55))
                                .frame(width: 7, height: 7)
                            Text(
                                st.inhaling
                                    ? L10n.t("吸气 · \(st.secondsLeft)s", "Inhale · \(st.secondsLeft)s")
                                    : L10n.t("呼气 · \(st.secondsLeft)s", "Exhale · \(st.secondsLeft)s")
                            )
                            .font(.caption.weight(.bold))
                            .foregroundStyle(warmth.primaryGlow.opacity(0.95))
                            .monospacedDigit()
                            .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(warmth.primaryGlow.opacity(0.15)))
                    }

                    Button {
                        withAnimation(reduce ? nil : .snappy) {
                            breathingHaptics.toggle()
                        }
                        if breathingHaptics {
                            let nowState = Self.breathingState(at: Date().timeIntervalSinceReferenceDate)
                            TactileEngine.shared.breathCue(inhaling: nowState.inhaling)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: breathingHaptics ? "hand.tap.fill" : "hand.tap")
                                .font(.caption2.weight(.bold))
                            Text(L10n.t("手心轻振", "Pulse"))
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .foregroundStyle(breathingHaptics ? warmth.onPrimaryInk : warmth.primaryGlow.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(breathingHaptics ? warmth.primaryGlow : Color(hex: 0x161E3B).opacity(0.76)))
                        .pillHitTarget()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t(breathingHaptics ? "关闭闭眼手心呼吸轻振" : "开启闭眼手心呼吸轻振", breathingHaptics ? "Turn off silent palm breathing pulse" : "Turn on silent palm breathing pulse"))
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.and.down")
                            .font(.caption2.weight(.bold))
                        Text(L10n.t("上下滑动调光 · 双击轻暗", "Slide to dim · 2× tap low"))
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(Palette.lampInk.opacity(showingDimmerHint ? 0.56 : 0.32))
                    .accessibilityHidden(true)
                }
            }

            let warmthSwatches = HStack(spacing: 2) {
                ForEach(LampWarmth.allCases) { preset in
                    let on = warmth == preset
                    Button {
                        TactileEngine.shared.beadClick()
                        rekindleFromEmber()
                        withAnimation(reduce ? nil : .easeInOut(duration: 0.26)) {
                            warmth = preset
                        }
                        commitLampPreferences()
                    } label: {
                        Circle()
                            .fill(preset.primaryGlow)
                            .frame(width: on ? 16 : 13, height: on ? 16 : 13)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(on ? 0.92 : 0.28), lineWidth: on ? 1.8 : 0.8)
                            )
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.label)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.horizontal, 6)
            .frame(minHeight: 36)
            .background(Capsule().fill(Color(hex: 0x161E3B).opacity(0.76)))
            .pillHitTarget(LayoutSpec.hitMin)

            if palmPatActive || breathingGuide || typeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    modeControls
                    warmthSwatches
                }
            } else {
                HStack(spacing: 8) {
                    modeControls
                    warmthSwatches
                }
            }
        }
    }

    // MARK: - Vertical Brass Dimmer Rail & Gesture

    private var dimmerGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard abs(value.translation.height) > abs(value.translation.width) * 1.15 else { return }
                if dragStartBrightness == nil {
                    rekindleFromEmber()
                    dragStartBrightness = brightness
                    showingDimmerHint = false
                }
                let start = dragStartBrightness ?? brightness
                // Dragging up increases warmth/brightness; dragging down dims to whisper ember
                let delta = -Double(value.translation.height) / 340.0
                let clamped = max(0.15, min(1.0, start + delta))
                brightness = clamped
                applyScreenDimmerIfAllowed()
                let step = Int((clamped * 20).rounded()) // 5% mechanical brass detents
                if step != lastDetentStep {
                    lastDetentStep = step
                    TactileEngine.shared.dimmerTick()
                }
            }
            .onEnded { _ in
                commitLampPreferences()
                withAnimation(.easeOut(duration: 0.25)) {
                    dragStartBrightness = nil
                }
            }
    }

    private var dimmerRail: some View {
        let active = dragStartBrightness != nil
        let b = displayedBrightness
        return VStack(spacing: 6) {
            Image(systemName: "sun.max.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(warmth.primaryGlow.opacity(active ? 0.9 : 0.42))

            GeometryReader { g in
                let h = g.size.height
                let normalized = max(0.0, min(1.0, (b - 0.15) / 0.85))
                let fillH = max(8, h * normalized)
                ZStack(alignment: .bottom) {
                    Capsule()
                        .fill(Color.white.opacity(active ? 0.14 : 0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [warmth.highlightCore, warmth.secondaryTint],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: fillH)
                }
            }
            .frame(width: active ? 8 : 5, height: 124)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: active)

            Image(systemName: "moon.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Palette.lampInk.opacity(active ? 0.72 : 0.36))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t("夜灯亮度", "Lamp brightness"))
        .accessibilityValue("\(Int((b * 100).rounded()))%")
        .accessibilityAdjustableAction { dir in
            rekindleFromEmber()
            switch dir {
            case .increment:
                brightness = min(1.0, brightness + 0.1)
                applyScreenDimmerIfAllowed()
                commitLampPreferences()
                TactileEngine.shared.dimmerTick()
            case .decrement:
                brightness = max(0.15, brightness - 0.1)
                applyScreenDimmerIfAllowed()
                commitLampPreferences()
                TactileEngine.shared.dimmerTick()
            default: break
            }
        }
    }

    // MARK: - Nursery Soundscape Deck

    private var soundscapeDeck: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(warmth.primaryGlow.opacity(0.85))
                Text(soundscape.isPlaying ? L10n.t("声景混音 · 点 + 可叠一层", "Soundscapes · Tap + to layer") : L10n.t("舒缓声景", "Soothing Soundscapes"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.lampInk.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                if let rem = soundscape.remainingSeconds {
                    Text(L10n.t("渐弱 ", "Fades ") + clock(Double(rem)))
                        .font(Typeface.numerals(12, relativeTo: .caption, weight: .semibold))
                        .foregroundStyle(warmth.primaryGlow.opacity(0.90))
                } else if soundscape.isPlaying {
                    Text(L10n.t("持续轻播", "Continuous"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(warmth.primaryGlow.opacity(0.78))
                } else {
                    Text(L10n.t("离线实时合成", "Offline DSP"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Palette.lampInk.opacity(0.45))
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 7), GridItem(.flexible(), spacing: 7)], spacing: 7) {
                ForEach(SoundscapeKind.allCases) { kind in
                    let isPrimary = soundscape.active == kind
                    let isSecondary = soundscape.secondary == kind
                    let on = isPrimary || isSecondary
                    HStack(spacing: 4) {
                        Button {
                            TactileEngine.shared.beadClick()
                            rekindleFromEmber()
                            withAnimation(reduce ? nil : .spring(response: 0.32, dampingFraction: 0.8)) {
                                soundscape.toggle(kind)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: kind.symbol)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(on ? warmth.onPrimaryInk : warmth.primaryGlow.opacity(0.90))
                                    .frame(width: 24, height: 24)
                                    .background(
                                        Circle().fill(isPrimary ? warmth.primaryGlow : (isSecondary ? warmth.secondaryBadgeFill : warmth.primaryGlow.opacity(0.14)))
                                    )
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(kind.title)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(on ? Palette.lampInk : Palette.lampInk.opacity(0.88))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                    Text(isSecondary ? L10n.t("已叠第二层", "Layer 2 on") : kind.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(on ? warmth.primaryGlow.opacity(0.94) : Palette.lampInk.opacity(0.56))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.70)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: 40)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if soundscape.isPlaying && !isPrimary {
                            Button {
                                TactileEngine.shared.beadClick()
                                rekindleFromEmber()
                                withAnimation(reduce ? nil : .spring(response: 0.28, dampingFraction: 0.8)) {
                                    soundscape.toggleLayer(kind)
                                }
                            } label: {
                                Image(systemName: isSecondary ? "checkmark" : "plus")
                                    .font(Typeface.label(11, relativeTo: .caption2, weight: .bold))
                                    .foregroundStyle(isSecondary ? warmth.onPrimaryInk : warmth.primaryGlow.opacity(0.9))
                                    .frame(width: 24, height: 24)
                                    .background(Circle().fill(isSecondary ? warmth.secondaryBadgeFill : warmth.primaryGlow.opacity(0.18)))
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isSecondary ? L10n.t("移除叠层\(kind.title)", "Remove \(kind.title) layer") : L10n.t("叠加\(kind.title)", "Blend \(kind.title)"))
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                            .fill(isPrimary ? warmth.primaryGlow.opacity(0.22) : (isSecondary ? warmth.primaryGlow.opacity(0.14) : Color(hex: 0x161E3B).opacity(0.75)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                            .strokeBorder(
                                isPrimary ? warmth.primaryGlow.opacity(0.72) : (isSecondary ? warmth.secondaryBadgeFill.opacity(0.55) : warmth.primaryGlow.opacity(0.14)),
                                lineWidth: on ? 1.3 : 0.9
                            )
                    )
                    .accessibilityElement(children: .contain)
                }
            }

            if soundscape.isPlaying {
                VStack(spacing: 8) {
                    // Auto-fade timer pills
                    HStack(spacing: 6) {
                        ForEach(SoundscapeDuration.allCases) { d in
                            let sel = soundscape.duration == d
                            Button {
                                TactileEngine.shared.beadClick()
                                withAnimation(.snappy) { soundscape.duration = d }
                            } label: {
                                Text(d.label)
                                    .font(.footnote.weight(sel ? .semibold : .medium))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                                    .foregroundStyle(sel ? warmth.onPrimaryInk : Palette.lampInk.opacity(0.80))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule().fill(sel ? warmth.primaryGlow : Color(hex: 0x1B2547).opacity(0.82))
                                    )
                                    .pillHitTarget()
                            }
                            .buttonStyle(.toy)
                            .accessibilityAddTraits(sel ? .isSelected : [])
                        }
                    }

                    // Zero-glare warm brass volume scrubber (no stark white slider knob in a dark room)
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.wave.1.fill")
                            .font(.caption)
                            .foregroundStyle(Palette.lampInk.opacity(0.58))
                        GeometryReader { geo in
                            let w = max(1, geo.size.width)
                            let norm = max(0, min(1, (soundscape.volume - 0.1) / 0.9))
                            let thumbX = norm * (w - 18) + 9
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                                    .frame(height: 6)
                                Capsule()
                                    .fill(LinearGradient(colors: [warmth.secondaryTint, warmth.primaryGlow], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(6, thumbX), height: 6)
                                Circle()
                                    .fill(RadialGradient(colors: [warmth.highlightCore, warmth.primaryGlow], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 11))
                                    .frame(width: 18, height: 18)
                                    .overlay(Circle().strokeBorder(warmth.onPrimaryInk.opacity(0.45), lineWidth: 1))
                                    .offset(x: thumbX - 9)
                            }
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { v in
                                        let ratio = max(0, min(1, v.location.x / w))
                                        soundscape.volume = 0.1 + ratio * 0.9
                                    }
                            )
                        }
                        .frame(height: 24)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(L10n.t("声景音量", "Soundscape volume"))
                        .accessibilityValue("\(Int((soundscape.volume * 100).rounded()))%")
                        .accessibilityAdjustableAction { dir in
                            switch dir {
                            case .increment: soundscape.volume = min(1.0, soundscape.volume + 0.1)
                            case .decrement: soundscape.volume = max(0.1, soundscape.volume - 0.1)
                            default: break
                            }
                        }
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.caption)
                            .foregroundStyle(Palette.lampInk.opacity(0.58))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Color(hex: 0x121933).opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(warmth.primaryGlow.opacity(0.16), lineWidth: 0.9)
        )
    }

    // MARK: - Zero-Glare Lamp Toast & Bottom Care Dock

    private func lampToastBanner(_ toast: Toast) -> some View {
        HStack(spacing: 10) {
            Image(systemName: toast.failed ? "exclamationmark.triangle.fill" : LogType.symbol(toast.type))
                .font(.caption.weight(.bold))
                .foregroundStyle(toast.failed ? Crayon.tangerine : warmth.onPrimaryInk)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(toast.failed ? Crayon.tangerine.opacity(0.22) : warmth.primaryGlow)
                )

            Text(toast.text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.lampInk)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            if toast.restore != nil {
                Button(L10n.t("撤销", "Undo")) {
                    TactileEngine.shared.beadClick()
                    rekindleFromEmber()
                    withAnimation(reduce ? nil : .snappy) {
                        j.undo(toast)
                    }
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(warmth.onPrimaryInk)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(warmth.primaryGlow))
                .pillHitTarget()
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(hex: 0x151D3B).opacity(0.94))
        )
        .overlay(
            Capsule()
                .strokeBorder((toast.failed ? Crayon.tangerine : warmth.primaryGlow).opacity(0.42), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        .onTapGesture {
            withAnimation(reduce ? nil : .snappy) { j.toast = nil }
        }
        .task(id: toast.id) {
            UIAccessibility.post(notification: .announcement, argument: toast.text)
            try? await Task.sleep(for: .seconds(toast.failed ? 6 : toast.restore == nil ? 2.5 : 5))
            if j.toast?.id == toast.id {
                withAnimation(reduce ? nil : .snappy) { j.toast = nil }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var careDock: some View {
        TimelineView(.periodic(from: .now, by: 60)) { tl in
            let summary = MidnightCareSummary.build(logs: j.logs, timers: j.timers, now: previewClock ?? tl.date)
            VStack(spacing: 8) {
                if !summary.facts.isEmpty || summary.nightStatusLine != nil {
                    midnightFactsStrip(summary)
                }

                if let t = activeTimer {
                    if let previewClock {
                        activeTimerCard(t, now: previewClock.timeIntervalSince1970 * 1000, summary: summary)
                    } else {
                        TimelineView(.periodic(from: .now, by: 1)) { liveTl in
                            activeTimerCard(t, now: liveTl.date.timeIntervalSince1970 * 1000, summary: summary)
                        }
                    }
                } else {
                    idleCarePanel(summary: summary)
                }
            }
        }
    }

    private func midnightFactsStrip(_ summary: MidnightCareSummary) -> some View {
        VStack(spacing: 5) {
            if let statusLine = summary.nightStatusLine {
                HStack(spacing: 6) {
                    Circle()
                        .fill(warmth.primaryGlow.opacity(0.9))
                        .frame(width: 5.5, height: 5.5)
                    Text(statusLine)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(warmth.primaryGlow.opacity(0.94))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            if !summary.facts.isEmpty {
                HStack(spacing: 10) {
                    ForEach(summary.facts) { item in
                        HStack(spacing: 4) {
                            Image(systemName: item.symbol)
                                .font(Typeface.label(11, relativeTo: .caption2, weight: .bold))
                                .foregroundStyle(warmth.primaryGlow.opacity(0.88))
                            Text("\(item.label) \(item.agoText)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Palette.lampInk.opacity(0.76))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, summary.nightStatusLine != nil && !summary.facts.isEmpty ? 7 : 6)
        .background(
            RoundedRectangle(cornerRadius: summary.nightStatusLine != nil && !summary.facts.isEmpty ? 14 : 999, style: .continuous)
                .fill(Color(hex: 0x121933).opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: summary.nightStatusLine != nil && !summary.facts.isEmpty ? 14 : 999, style: .continuous)
                .strokeBorder(warmth.primaryGlow.opacity(0.16), lineWidth: 0.75)
        )
        .accessibilityElement(children: .combine)
    }

    private func activeTimerCard(_ t: RunningTimer, now: Double, summary: MidnightCareSummary) -> some View {
        let paused = t.pausedAt != nil
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: LogType.symbol(t.type))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(warmth.primaryGlow)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(warmth.primaryGlow.opacity(0.16)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.timerStatus(t.type, side: t.side, paused: paused))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.lampInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(clock(t.total(now)))
                        .font(Typeface.numerals(22, relativeTo: .title2, weight: .bold))
                        .foregroundStyle(warmth.primaryGlow)
                }
                Spacer(minLength: 4)

                Button {
                    TactileEngine.shared.beadClick()
                    rekindleFromEmber()
                    withAnimation(reduce ? nil : .snappy) {
                        quickCareMode = quickCareMode == .diaper ? nil : .diaper
                    }
                } label: {
                    Image(systemName: LogType.symbol(LogType.diaper))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(quickCareMode == .diaper ? warmth.onPrimaryInk : warmth.primaryGlow)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(quickCareMode == .diaper ? warmth.primaryGlow : Color(hex: 0x222D54)))
                        .hitTarget(LayoutSpec.hitMin)
                }
                .buttonStyle(.toy)
                .accessibilityLabel(L10n.t("顺手记尿布", "Quick log diaper"))

                if t.type == LogType.sleep {
                    Button {
                        TactileEngine.shared.beadClick()
                        rekindleFromEmber()
                        bottleMilkKind = summary.defaultMilkKind
                        withAnimation(reduce ? nil : .snappy) {
                            quickCareMode = quickCareMode == .bottle ? nil : .bottle
                        }
                    } label: {
                        Image(systemName: LogType.symbol(LogType.bottle))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(quickCareMode == .bottle ? warmth.onPrimaryInk : warmth.primaryGlow)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(quickCareMode == .bottle ? warmth.primaryGlow : Color(hex: 0x222D54)))
                            .hitTarget(LayoutSpec.hitMin)
                    }
                    .buttonStyle(.toy)
                    .accessibilityLabel(L10n.t("顺手记瓶喂", "Quick log bottle"))
                }

                if t.type == LogType.nurse {
                    Button {
                        TactileEngine.shared.beadClick()
                        rekindleFromEmber()
                        withAnimation(.snappy) { j.switchSide(t.type) }
                    } label: {
                        Label(t.side == "l" ? L10n.t("换右", "Right") : L10n.t("换左", "Left"), systemImage: "arrow.left.arrow.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.lampInk)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 36)
                            .background(Capsule().fill(Color(hex: 0x222D54)))
                            .pillHitTarget(LayoutSpec.hitMin)
                    }
                    .buttonStyle(.toy)
                }

                Button {
                    TactileEngine.shared.beadClick()
                    rekindleFromEmber()
                    withAnimation(.snappy) { j.togglePause(t.type) }
                } label: {
                    Image(systemName: paused ? "play.fill" : "pause.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Palette.lampInk)
                        .frame(width: 38, height: 36)
                        .background(Capsule().fill(Color(hex: 0x222D54)))
                        .hitTarget(LayoutSpec.hitMin)
                }
                .buttonStyle(.toy)
                .accessibilityLabel(paused ? L10n.t("继续计时", "Resume timer") : L10n.t("暂停计时", "Pause timer"))
            }

            if quickCareMode == .diaper {
                diaperQuickTray
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            } else if quickCareMode == .bottle {
                bottleQuickTray(suggestions: summary.bottleSuggestions)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }

            Button {
                TactileEngine.shared.goldChime()
                rekindleFromEmber()
                withAnimation(.snappy) { j.stop(t.type) }
            } label: {
                Label(
                    t.type == LogType.sleep ? L10n.t("醒了，记下这次睡眠", "Awake — Save Sleep") : L10n.t("喂完了，记下这次亲喂", "Done — Save Feed"),
                    systemImage: "checkmark"
                )
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.88)
                .foregroundStyle(warmth.actionInk)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(
                    Capsule().fill(warmth.actionFill.opacity(0.92))
                )
            }
            .buttonStyle(.toy)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Color(hex: 0x151D3B).opacity(0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(warmth.primaryGlow.opacity(0.20), lineWidth: 0.9)
        )
    }

    private func idleCarePanel(summary: MidnightCareSummary) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                bedsideAction(
                    title: L10n.t("开始睡觉", "Start Sleep"),
                    detail: L10n.t("夜灯计时", "Night timer"),
                    symbol: LogType.symbol(LogType.sleep)
                ) {
                    guard app.mayKeep() else { return }
                    TactileEngine.shared.beadClick()
                    rekindleFromEmber()
                    withAnimation(.snappy) {
                        quickCareMode = nil
                        j.start(LogType.sleep, openFocus: false)
                    }
                }

                bedsideAction(
                    title: L10n.t("开始亲喂", "Start Nursing"),
                    detail: suggestedSide == "l" ? L10n.t("建议左侧", "Left next") : L10n.t("建议右侧", "Right next"),
                    symbol: LogType.symbol(LogType.nurse)
                ) {
                    guard app.mayKeep() else { return }
                    TactileEngine.shared.beadClick()
                    rekindleFromEmber()
                    withAnimation(.snappy) {
                        quickCareMode = nil
                        j.start(LogType.nurse, side: suggestedSide, openFocus: false)
                    }
                }
            }

            if quickCareMode == .diaper {
                diaperQuickTray
                    .padding(9)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .fill(Color(hex: 0x151D3B).opacity(0.84))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .strokeBorder(warmth.primaryGlow.opacity(0.22), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .bottom)))
            } else if quickCareMode == .bottle {
                bottleQuickTray(suggestions: summary.bottleSuggestions)
                    .padding(9)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .fill(Color(hex: 0x151D3B).opacity(0.84))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .strokeBorder(warmth.primaryGlow.opacity(0.22), lineWidth: 1)
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .bottom)))
            } else {
                HStack(spacing: 8) {
                    quickCarePill(
                        title: L10n.t("记尿布", "Log Diaper"),
                        symbol: LogType.symbol(LogType.diaper)
                    ) {
                        guard app.mayKeep() else { return }
                        TactileEngine.shared.beadClick()
                        rekindleFromEmber()
                        withAnimation(reduce ? nil : .snappy) { quickCareMode = .diaper }
                    }

                    quickCarePill(
                        title: L10n.t("记瓶喂", "Log Bottle"),
                        symbol: LogType.symbol(LogType.bottle)
                    ) {
                        guard app.mayKeep() else { return }
                        TactileEngine.shared.beadClick()
                        rekindleFromEmber()
                        bottleMilkKind = summary.defaultMilkKind
                        withAnimation(reduce ? nil : .snappy) { quickCareMode = .bottle }
                    }
                }
            }
        }
    }

    private func quickCarePill(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(warmth.primaryGlow)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.lampInk.opacity(0.90))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color(hex: 0x151D3B).opacity(0.76))
            )
            .overlay(
                Capsule().strokeBorder(warmth.primaryGlow.opacity(0.20), lineWidth: 1)
            )
        }
        .buttonStyle(.toy)
    }

    private var diaperQuickTray: some View {
        HStack(spacing: 7) {
            Image(systemName: LogType.symbol(LogType.diaper))
                .font(.caption.weight(.bold))
                .foregroundStyle(warmth.primaryGlow)

            ForEach([("wet", L10n.t("湿", "Wet")), ("dirty", L10n.t("便", "Dirty")), ("both", L10n.t("都有", "Both"))], id: \.0) { kind, label in
                Button {
                    guard app.mayKeep() else { return }
                    TactileEngine.shared.beadClick()
                    rekindleFromEmber()
                    let entry = LogEntry(type: LogType.diaper, start: JournalFile.now(), detail: kind)
                    if j.record(entry) {
                        withAnimation(reduce ? nil : .snappy) { quickCareMode = nil }
                    }
                } label: {
                    Text(label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(warmth.onPrimaryInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(warmth.primaryGlow.opacity(0.92)))
                        .pillHitTarget()
                }
                .buttonStyle(.toy)
            }

            Button {
                TactileEngine.shared.beadClick()
                withAnimation(reduce ? nil : .snappy) { quickCareMode = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Palette.lampInk.opacity(0.75))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color(hex: 0x222D54)))
                    .hitTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("收起尿布选项", "Close diaper options"))
        }
    }

    private func bottleQuickTray(suggestions: [Int]) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach([("formula", L10n.t("配方奶", "Formula")), ("breastmilk", L10n.t("母乳", "Breast milk"))], id: \.0) { code, title in
                    let on = bottleMilkKind == code
                    Button {
                        TactileEngine.shared.beadClick()
                        bottleMilkKind = code
                    } label: {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(on ? warmth.onPrimaryInk : Palette.lampInk.opacity(0.78))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(on ? warmth.primaryGlow : Color(hex: 0x222D54)))
                        .pillHitTarget()
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 4)

            Button {
                TactileEngine.shared.beadClick()
                withAnimation(reduce ? nil : .snappy) { quickCareMode = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Palette.lampInk.opacity(0.75))
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color(hex: 0x222D54)))
                    .hitTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("收起瓶喂选项", "Close bottle options"))
        }

        HStack(spacing: 6) {
            ForEach(suggestions, id: \.self) { ml in
                Button {
                    guard app.mayKeep() else { return }
                    TactileEngine.shared.beadClick()
                    rekindleFromEmber()
                    let entry = LogEntry(type: LogType.bottle, start: JournalFile.now(), amount: ml, detail: bottleMilkKind)
                    if j.record(entry) {
                        withAnimation(reduce ? nil : .snappy) { quickCareMode = nil }
                    }
                } label: {
                    Text(L10n.volume(ml: ml))
                        .font(Typeface.numerals(13, relativeTo: .footnote, weight: .bold))
                        .foregroundStyle(warmth.onPrimaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(warmth.primaryGlow.opacity(0.92)))
                        .pillHitTarget()
                }
                .buttonStyle(.toy)
            }
        }
    }
}

private func bedsideAction(title: String, detail: String, symbol: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.callout.weight(.bold))
                .foregroundStyle(warmth.primaryGlow)
                .frame(width: 34, height: 34)
                .background(Circle().fill(warmth.primaryGlow.opacity(0.15)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Palette.lampInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(Palette.lampInk.opacity(0.58))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .fill(Color(hex: 0x151D3B).opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(warmth.primaryGlow.opacity(0.20), lineWidth: 1)
            )
        }
        .buttonStyle(.toy)
    }
}

/// Subtle warm dust specks rising gently inside Otto's lantern beam.
private struct LampDustCanvas: View {
    let brightness: Double
    var glowColor: Color = Palette.amber
    var coreColor: Color = Color(hex: 0xFFEBC0)
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduce || Perf.still || scenePhase != .active || brightness < 0.08)) { tl in
            Canvas(rendersAsynchronously: true) { ctx, size in
                let t = tl.date.timeIntervalSinceReferenceDate
                for i in 0..<18 {
                    let k = Double(i)
                    let seed = (k * 0.6180339).truncatingRemainder(dividingBy: 1)
                    let period = 24.0 + Double(i % 4) * 7.0
                    let prog = (t / period + seed).truncatingRemainder(dividingBy: 1)
                    let x = size.width * (0.14 + 0.72 * ((seed * 1.9).truncatingRemainder(dividingBy: 1))) + sin(t * 0.45 + k * 1.7) * 18
                    let y = size.height * (0.78 - prog * 0.68)
                    let fade = min(1, prog * 5) * min(1, (1 - prog) * 5)
                    let r = 1.4 + Double(i % 3) * 0.85
                    let a = fade * (0.28 + 0.42 * brightness)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - r * 3.5, y: y - r * 3.5, width: r * 7, height: r * 7)),
                        with: .radialGradient(Gradient(colors: [glowColor.opacity(a * 0.45), .clear]), center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 3.5)
                    )
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                        with: .color(coreColor.opacity(a))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Low-power CoreMotion device tilt observer for Otto's pendulum lantern glow (no motion permission prompt required).
@Observable
@MainActor
private final class LampTiltObserver {
    var roll: Double = 0
    var pitch: Double = 0

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var isRunning = false

    func start() {
        guard !isRunning,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              manager.isDeviceMotionAvailable else { return }
        isRunning = true
        manager.deviceMotionUpdateInterval = 1.0 / 15.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let g = data?.gravity else { return }
            // Low-pass smooth gravity tilt in [-1, 1] with deadband to avoid unnecessary SwiftUI invalidations on a nightstand
            let targetRoll = max(-0.8, min(0.8, g.x))
            let targetPitch = max(-0.8, min(0.8, g.y + 0.55))
            let nextRoll = self.roll + (targetRoll - self.roll) * 0.14
            let nextPitch = self.pitch + (targetPitch - self.pitch) * 0.14
            guard abs(nextRoll - self.roll) > 0.008 || abs(nextPitch - self.pitch) > 0.008 else { return }
            self.roll = nextRoll
            self.pitch = nextPitch
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        manager.stopDeviceMotionUpdates()
    }
}
