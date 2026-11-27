import Foundation
import SwiftUI
import AVFoundation
import Observation

/// Classification of current system output volume for infant hearing comfort.
enum EarSafeVolumeLevel: Equatable, Sendable {
    case muted
    case safe
    case loud

    /// Maps normalized hardware volume (`0.0...1.0`) to a clear infant-safe bucket.
    static func of(_ volume: Float) -> EarSafeVolumeLevel {
        if volume < 0.01 { return .muted }
        if volume <= 0.60 { return .safe }
        return .loud
    }
}

/// Interactive audio surfaces guarded by the smart ear-safe volume reminder.
enum SoundGuardContext: Sendable {
    case toybox
    case lamp
}

/// Non-nagging infant hearing comfort monitor powered offline by `AVAudioSession.outputVolume` KVO.
///
/// Design rules:
/// - **Toybox sound studios** (`xylophone`, `rainstick`, `fireflies`): remind automatically on the very first visit so
///   parents know where a gentle volume sits (`30%–50%`), OR on later visits only if the phone is loud (`> 60%`) or
///   muted (`0%`). Never appears on silent `contrast` cards, and once acknowledged stays quiet for that session.
/// - **Bedside Lamp soundscapes**: whispers only when a parent starts a soundscape at high volume (`> 60%`) so a 3 a.m.
///   session never accidentally blasts next to a sleeping baby.
@Observable
@MainActor
final class EarSafeVolumeMonitor {
    static let toyboxSeenKey = "mossling.earSafe.toyboxGuideSeen"

    var volume: Float
    var dismissedThisSession: Bool = false

    private let defaults: UserDefaults
    private let previewMode: Bool
    private let previewForceShow: Bool
    @ObservationIgnored nonisolated(unsafe) private var observation: NSKeyValueObservation?
    private var previousLevel: EarSafeVolumeLevel

    private static var isTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init(
        previewVolume: Float? = nil,
        previewForceShow: Bool = false,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        self.previewForceShow = previewForceShow
        if let pv = previewVolume {
            let clamped = max(0, min(1, pv))
            self.volume = clamped
            self.previewMode = true
            self.previousLevel = EarSafeVolumeLevel.of(clamped)
        } else {
            let live = Self.isTestHost ? Float(0.40) : AVAudioSession.sharedInstance().outputVolume
            self.volume = live
            self.previewMode = false
            self.previousLevel = EarSafeVolumeLevel.of(live)
        }
    }

    var level: EarSafeVolumeLevel {
        EarSafeVolumeLevel.of(volume)
    }

    var volumePercent: Int {
        Int((volume * 100).rounded())
    }

    var hasSeenToyboxGuide: Bool {
        get { defaults.bool(forKey: Self.toyboxSeenKey) }
        set { defaults.set(newValue, forKey: Self.toyboxSeenKey) }
    }

    /// Pure decision rule determining whether a reminder card should be displayed.
    nonisolated static func shouldPrompt(
        volume: Float,
        context: SoundGuardContext,
        hasSeenToyboxGuide: Bool,
        dismissedThisSession: Bool
    ) -> Bool {
        guard !dismissedThisSession else { return false }
        let lvl = EarSafeVolumeLevel.of(volume)
        switch context {
        case .toybox:
            if !hasSeenToyboxGuide { return true }
            return lvl == .loud || lvl == .muted
        case .lamp:
            return volume > 0.60
        }
    }

    func shouldShow(for context: SoundGuardContext) -> Bool {
        if previewForceShow && !dismissedThisSession {
            return true
        }
        return Self.shouldPrompt(
            volume: volume,
            context: context,
            hasSeenToyboxGuide: hasSeenToyboxGuide,
            dismissedThisSession: dismissedThisSession
        )
    }

    func acknowledge(context: SoundGuardContext) {
        dismissedThisSession = true
        if context == .toybox {
            hasSeenToyboxGuide = true
        }
    }

    private var hasObservedLevel = false
    private var activatedAmbientSession = false

    /// Starts passive KVO on `AVAudioSession.sharedInstance().outputVolume` without disrupting active audio categories.
    func start() {
        guard !previewMode, !Self.isTestHost else { return }
        guard observation == nil else { return }
        let session = AVAudioSession.sharedInstance()
        let activePlaybackOrRecord = SoundscapeEngine.shared.ownsPlaybackSession
            || ToyboxAudioEngine.shared.isPlaying
            || FirstVoiceController.shared.isRecording
            || FirstVoiceController.shared.playingID != nil
        if !activePlaybackOrRecord {
            try? session.setCategory(.ambient, options: .mixWithOthers)
            try? session.setActive(true, options: [])
            activatedAmbientSession = true
        }
        let current = session.outputVolume
        let nextLevel = EarSafeVolumeLevel.of(current)
        if hasObservedLevel && previousLevel != nextLevel && (nextLevel == .loud || nextLevel == .muted) {
            dismissedThisSession = false
        }
        volume = current
        previousLevel = nextLevel
        hasObservedLevel = true
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshSessionAndLevel(reactivateIfIdle: true)
            }
        }
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshSessionAndLevel(reactivateIfIdle: false)
            }
        }
        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] session, _ in
            let next = session.outputVolume
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.volume = next
                let nextLevel = EarSafeVolumeLevel.of(next)
                if self.previousLevel != nextLevel && (nextLevel == .loud || nextLevel == .muted) {
                    // Re-arm safety guard when hardware volume transitions into loud or muted.
                    self.dismissedThisSession = false
                }
                if self.previousLevel == .loud && nextLevel == .safe {
                    TactileEngine.shared.beadClick()
                }
                self.previousLevel = nextLevel
                self.hasObservedLevel = true
            }
        }
    }

    private func refreshSessionAndLevel(reactivateIfIdle: Bool) {
        let session = AVAudioSession.sharedInstance()
        if reactivateIfIdle {
            let busy = SoundscapeEngine.shared.ownsPlaybackSession
                || ToyboxAudioEngine.shared.isPlaying
                || FirstVoiceController.shared.isRecording
                || FirstVoiceController.shared.playingID != nil
            if !busy {
                try? session.setCategory(.ambient, options: .mixWithOthers)
                try? session.setActive(true, options: [])
                activatedAmbientSession = true
            }
        }
        let current = session.outputVolume
        let nextLevel = EarSafeVolumeLevel.of(current)
        if hasObservedLevel && previousLevel != nextLevel && (nextLevel == .loud || nextLevel == .muted) {
            dismissedThisSession = false
        }
        volume = current
        previousLevel = nextLevel
        hasObservedLevel = true
    }

    @ObservationIgnored nonisolated(unsafe) private var foregroundObserver: NSObjectProtocol?
    @ObservationIgnored nonisolated(unsafe) private var routeObserver: NSObjectProtocol?

    deinit {
        observation?.invalidate()
        if let foregroundObserver { NotificationCenter.default.removeObserver(foregroundObserver) }
        if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) }
    }

    func stop() {
        observation?.invalidate()
        observation = nil
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
            self.foregroundObserver = nil
        }
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
            self.routeObserver = nil
        }
        if activatedAmbientSession {
            activatedAmbientSession = false
            let busy = SoundscapeEngine.shared.ownsPlaybackSession
                || ToyboxAudioEngine.shared.isPlaying
                || FirstVoiceController.shared.isRecording
                || FirstVoiceController.shared.playingID != nil
            if !busy {
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
    }
}

// MARK: - Tactile Ear-Safe Volume Check Card (Toybox)

/// Inline, warm Montessori hearing comfort banner displayed before playing sound toys when first opened or when volume is high/muted.
struct EarSafeVolumeCard: View {
    let monitor: EarSafeVolumeMonitor
    let dark: Bool
    let onAcknowledge: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduce

    private var tone: Color {
        switch monitor.level {
        case .loud: Crayon.tangerine
        case .muted: Crayon.sky
        case .safe: Crayon.leaf
        }
    }

    private var headline: String {
        let pct = monitor.volumePercent
        switch monitor.level {
        case .loud:
            return L10n.t("当前音量 \(pct)% 偏大 · 建议调轻护耳", "Volume \(pct)% · A bit loud for little ears")
        case .muted:
            return L10n.t("手机当前已静音 · 可按侧键调轻声", "Phone is muted · Press side button for soft sound")
        case .safe:
            return L10n.t("先看一眼音量 · 当前 \(pct)% 很温柔", "Quick Volume Check · \(pct)% Baby-Safe")
        }
    }

    private var bodyCopy: String {
        switch monitor.level {
        case .loud:
            return L10n.t("轻按手机侧边音量减键，把圆点调回绿色区（约 20%–60%），轻柔保护宝宝耳膜。",
                          "Tap the side volume-down button back into the green 20%–60% zone to protect baby's ears.")
        case .muted:
            return L10n.t("调至约两到三格（约 25%–45%）就能听见温润木声，也不会突然吓到宝宝。",
                          "Around 25%–45% gives a warm acoustic chime without startling your baby.")
        case .safe:
            return L10n.t("当前处于绿色护耳舒适带（20%–60%），随时可用手机侧键微调。",
                          "Currently right inside the green 20%–60% baby-safe acoustic comfort zone.")
        }
    }

    var body: some View {
        let pct = monitor.volumePercent
        let v = CGFloat(max(0, min(1, monitor.volume)))
        let tintInk = dark ? tone.mix(with: .white, by: 0.28) : Crayon.ink(tone)

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(tone.opacity(dark ? 0.24 : 0.16))
                        .frame(width: 26, height: 26)
                    Image(systemName: monitor.level == .muted ? "speaker.slash.fill" : (monitor.level == .loud ? "ear.trianglebadge.exclamationmark" : "ear.and.waveform"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(tintInk)
                }

                Text(headline)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.80)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 4)

                Button {
                    TactileEngine.shared.beadClick()
                    onAcknowledge()
                } label: {
                    Label(
                        monitor.level == .loud
                            ? L10n.t("已调轻", "Lowered")
                            : L10n.t("合适 · 开玩", "Safe · Play"),
                        systemImage: "checkmark"
                    )
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(monitor.level == .loud ? Crayon.buttonFill(Crayon.tangerine) : Palette.accentFill))
                    .pillHitTarget(LayoutSpec.hitMin)
                }
                .buttonStyle(.toy)
            }

            // Compact live 3-zone hardware volume bar (~8pt height) keeping 20%–60% baby-safe band crisp
            VStack(spacing: 3) {
                GeometryReader { g in
                    let w = g.size.width
                    let markerX = max(6, min(w - 6, w * v))
                    let safeColor = dark ? Crayon.leaf.mix(with: .white, by: 0.2) : Crayon.ink(Crayon.leaf)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(dark ? Color.white.opacity(0.08) : Palette.fill)
                            .frame(height: 8)

                        Capsule()
                            .fill(Crayon.tangerine.opacity(dark ? 0.26 : 0.20))
                            .frame(width: w * 0.40, height: 8)
                            .offset(x: w * 0.60)

                        Capsule()
                            .fill(tone.opacity(monitor.level == .loud ? 0.72 : 0.90))
                            .frame(width: max(8, w * v), height: 8)

                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Crayon.leaf.opacity(dark ? 0.28 : 0.22))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(safeColor.opacity(0.85), lineWidth: 1.4)
                            )
                            .frame(width: w * 0.40, height: 10)
                            .offset(x: w * 0.20)

                        Circle()
                            .fill(.white)
                            .frame(width: 13, height: 13)
                            .overlay(Circle().strokeBorder(tone, lineWidth: 2.2))
                            .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                            .position(x: markerX, y: g.size.height / 2)
                    }
                    .animation(reduce ? nil : .spring(response: 0.24, dampingFraction: 0.8), value: v)
                }
                .frame(height: 13)

                HStack {
                    Text(L10n.t("绿色护耳带 20%–60%", "Baby-Safe 20%–60%"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(dark ? Crayon.leaf.mix(with: .white, by: 0.25) : Crayon.ink(Crayon.leaf))
                    Spacer()
                    Text(L10n.t("侧键微调 · \(pct)%", "Side keys · \(pct)%"))
                        .font(Typeface.numerals(11, relativeTo: .caption2, weight: .semibold))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(dark ? Palette.lampCard : Palette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(tone.opacity(dark ? 0.45 : 0.34), lineWidth: 1.0)
        )
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Midnight High-Volume Whisper Pill (Bedside Lamp)

/// Ultra-subtle high-volume whisper pill shown above the Bedside Lamp soundscape deck only if volume > 60%.
struct LampHighVolumePill: View {
    let volumePercent: Int
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "ear.trianglebadge.exclamationmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(Palette.amber)
            Text(L10n.t("当前音量 \(volumePercent)% 偏大，建议侧键调轻护耳", "Volume \(volumePercent)% is loud — lower side buttons for baby"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.lampInk.opacity(0.92))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 4)
            Button {
                TactileEngine.shared.beadClick()
                onDismiss()
            } label: {
                Text(L10n.t("知道了", "OK"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(hex: 0x261700))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Palette.amber))
                    .pillHitTarget(LayoutSpec.hitMin)
            }
            .buttonStyle(.toy)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                .fill(Color(hex: 0x1E2647).opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                .strokeBorder(Palette.amber.opacity(0.5), lineWidth: 1)
        )
    }
}
