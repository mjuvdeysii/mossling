import Foundation
import SwiftUI
import AVFoundation
import MediaPlayer
import Observation
import os

/// Six handcrafted nursery soundscapes synthesized in real time via `AVAudioEngine` (zero audio files in bundle,
/// infinitely non-repeating, zero network). Tuned low and warm to protect infant ears.
enum SoundscapeKind: String, CaseIterable, Identifiable {
    case rain, breeze, heartbeat, lullaby, shush, waves
    var id: String { rawValue }

    var title: String {
        switch self {
        case .rain: L10n.t("雨落纸窗", "Paper Rain")
        case .breeze: L10n.t("草坡微风", "Meadow Breeze")
        case .heartbeat: L10n.t("温暖心跳", "Soft Heartbeat")
        case .lullaby: L10n.t("木琴摇篮", "Wood Lullaby")
        case .shush: L10n.t("轻声嘘拍", "Gentle Shush")
        case .waves: L10n.t("暖海潮汐", "Soft Tide")
        }
    }

    var subtitle: String {
        switch self {
        case .rain: L10n.t("细雨轻敲暖纸", "Rain on paper")
        case .breeze: L10n.t("随 Otto 慢呼吸", "Soft breath")
        case .heartbeat: L10n.t("舒缓低频轻拍", "64 BPM pulse")
        case .lullaby: L10n.t("五声音阶木琴", "Wood marimba")
        case .shush: L10n.t("妈妈轻嘘节律", "Soft shushing")
        case .waves: L10n.t("缓拍细沙海浪", "Slow ocean tide")
        }
    }

    var symbol: String {
        switch self {
        case .rain: "cloud.drizzle.fill"
        case .breeze: "wind"
        case .heartbeat: "waveform.path.ecg"
        case .lullaby: "music.note"
        case .shush: "waveform.path"
        case .waves: "water.waves"
        }
    }

    var tint: Color {
        switch self {
        case .rain: Crayon.sky
        case .breeze: Crayon.leaf
        case .heartbeat: Crayon.pink
        case .lullaby: Palette.amber
        case .shush: Crayon.lilac
        case .waves: Crayon.teal
        }
    }
}

/// Auto-fade duration options for the nursery soundscape (fades out gently over the final 20 seconds).
enum SoundscapeDuration: Int, CaseIterable, Identifiable {
    case m15 = 15, m30 = 30, m60 = 60, continuous = 0
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .m15: L10n.t("15 分钟", "15 min")
        case .m30: L10n.t("30 分钟", "30 min")
        case .m60: L10n.t("60 分钟", "60 min")
        case .continuous: L10n.t("一直播", "Continuous")
        }
    }
}

/// Thread-safe DSP synthesis state shared with the real-time audio render block.
final class SoundscapeDSPState: @unchecked Sendable {
    struct Controls: Sendable {
        var kindRaw: Int = 0
        var targetGain: Float = 0.0
        var userVolume: Float = 0.72
        var layerKindRaw: Int = -1
        var layerTargetMix: Float = 0.0
    }

    private let controlLock = OSAllocatedUnfairLock(initialState: Controls())

    var kindRaw: Int {
        get { controlLock.withLock { $0.kindRaw } }
        set { controlLock.withLock { $0.kindRaw = newValue } }
    }
    var targetGain: Float {
        get { controlLock.withLock { $0.targetGain } }
        set { controlLock.withLock { $0.targetGain = newValue } }
    }
    var userVolume: Float {
        get { controlLock.withLock { $0.userVolume } }
        set { controlLock.withLock { $0.userVolume = newValue } }
    }

    var currentGain: Float = 0.0

    // PRNG + pink noise filter banks
    var seed: UInt64 = 0x243F6A8885A308D3
    var b0: Float = 0, b1: Float = 0, b2: Float = 0, b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0
    var lp1: Float = 0, lp2: Float = 0

    // Rain droplet resonator
    var dropPhase: Double = 0
    var dropFreq: Double = 900
    var dropAmp: Float = 0

    // Breeze + Heartbeat clocks
    var sampleIndex: UInt64 = 0

    // Wood lullaby polyphonic 2-voice marimba
    var noteCountdown: Int = 18_000
    var voice1Phase: Double = 0, voice1Freq: Double = 261.63, voice1Amp: Float = 0
    var voice2Phase: Double = 0, voice2Freq: Double = 392.00, voice2Amp: Float = 0
    var lastNoteIdx: Int = 0
    var useVoice1: Bool = true

    private static let pentatonic: [Double] = [261.63, 293.66, 329.63, 392.00, 440.00, 523.25, 587.33, 659.25]

    @inline(__always)
    private func nextWhite() -> Float {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return Float(Int32(bitPattern: UInt32(truncatingIfNeeded: seed >> 32))) / Float(Int32.max)
    }

    @inline(__always)
    private func nextPink() -> Float {
        let w = nextWhite()
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        let out = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.11
        b6 = w * 0.115926
        return out
    }

    /// Secondary ambient harmony layer (`-1` = off, `0...5` = SoundscapeKind index).
    var layerKindRaw: Int {
        get { controlLock.withLock { $0.layerKindRaw } }
        set { controlLock.withLock { $0.layerKindRaw = newValue } }
    }
    var layerTargetMix: Float {
        get { controlLock.withLock { $0.layerTargetMix } }
        set { controlLock.withLock { $0.layerTargetMix = newValue } }
    }
    var layerCurrentMix: Float = 0.0
    private var lastRenderLayerKind: Int = -1
    private var lastControls = Controls()
    // Independent low-pass state for secondary layer so filters never cross-contaminate
    var sLp1: Float = 0, sLp2: Float = 0

    func renderBuffer(into abl: UnsafeMutableAudioBufferListPointer, frameCount: Int, sampleRate sr: Double) {
        var snap = lastControls
        if let locked = controlLock.withLockIfAvailable({ $0 }) {
            snap = locked
            lastControls = locked
        }
        var didClearLayer = false
        for frame in 0..<frameCount {
            let s = synthesizeSample(sampleRate: sr, controls: snap, didClearLayer: &didClearLayer)
            for buf in abl {
                if let ptr = buf.mData?.assumingMemoryBound(to: Float.self) {
                    ptr[frame] = s
                }
            }
        }
        if didClearLayer {
            _ = controlLock.withLockIfAvailable { c in
                if c.layerKindRaw == snap.layerKindRaw && c.layerTargetMix <= 0.0001 {
                    c.layerKindRaw = -1
                    lastControls.layerKindRaw = -1
                }
            }
        }
    }

    /// Generates one stereo-compatible mono sample in `[-1, 1]` with smooth gain ramping and optional dual-layer mix.
    func nextSample(sampleRate sr: Double) -> Float {
        let snap = controlLock.withLock { $0 }
        var didClearLayer = false
        let sample = synthesizeSample(sampleRate: sr, controls: snap, didClearLayer: &didClearLayer)
        if didClearLayer {
            controlLock.withLock { c in
                if c.layerKindRaw == snap.layerKindRaw && c.layerTargetMix <= 0.0001 {
                    c.layerKindRaw = -1
                }
            }
        }
        return sample
    }

    private func synthesizeSample(sampleRate sr: Double, controls: Controls, didClearLayer: inout Bool) -> Float {
        let t = Double(sampleIndex) / sr
        sampleIndex &+= 1

        let activeLayerKind = controls.layerKindRaw
        if activeLayerKind != lastRenderLayerKind {
            let wasActive = lastRenderLayerKind >= 0
            lastRenderLayerKind = activeLayerKind
            sLp1 = 0
            sLp2 = 0
            if wasActive {
                layerCurrentMix = 0
            }
        }

        // Smooth gain ramps (~250ms glide so start/stop/volume/layer transitions never click)
        let desired = controls.targetGain * controls.userVolume
        currentGain += (desired - currentGain) * 0.00018
        layerCurrentMix += (controls.layerTargetMix - layerCurrentMix) * 0.00018
        if controls.layerTargetMix <= 0.0001 && layerCurrentMix <= 0.0005 && activeLayerKind >= 0 {
            layerCurrentMix = 0
            lastRenderLayerKind = -1
            sLp1 = 0
            sLp2 = 0
            didClearLayer = true
        }

        let primary = synthesizeLayer(kind: controls.kindRaw, t: t, sr: sr, useSecondaryFilter: false)
        var combined = primary
        if activeLayerKind >= 0 && activeLayerKind != controls.kindRaw && layerCurrentMix > 0.0005 {
            let secondary = synthesizeLayer(kind: activeLayerKind, t: t, sr: sr, useSecondaryFilter: true)
            combined = primary * 0.80 + secondary * (0.58 * layerCurrentMix)
        }
        return tanh(combined * currentGain * 1.42)
    }

    private func synthesizeLayer(kind: Int, t: Double, sr: Double, useSecondaryFilter: Bool) -> Float {
        switch kind {
        case 0: // Paper Rain: velvety low-passed pink noise + gentle raindrop plinks
            let p = nextPink()
            let filtered: Float
            if useSecondaryFilter {
                sLp1 += 0.14 * (p - sLp1)
                sLp2 += 0.24 * (sLp1 - sLp2)
                filtered = sLp2
            } else {
                lp1 += 0.14 * (p - lp1)
                lp2 += 0.24 * (lp1 - lp2)
                filtered = lp2
            }
            if dropAmp < 0.0008 && (seed & 0x3FFF) == 1 {
                dropFreq = 680 + Double((seed >> 16) % 520)
                dropAmp = 0.045 + Float((seed >> 24) % 35) * 0.001
                dropPhase = 0
            }
            var drop: Float = 0
            if dropAmp > 0.0001 {
                drop = Float(sin(dropPhase)) * dropAmp
                dropPhase += 2 * .pi * dropFreq / sr
                dropAmp *= 0.9982
            }
            return filtered * 0.52 + drop
        case 1: // Meadow Breeze: Otto's 3.8s slow breathing swell over warm brown/pink wind
            let p = nextPink()
            let breath = Float(0.5 + 0.5 * sin(2 * .pi * t / 3.8))
            let cutoff: Float = 0.028 + 0.068 * breath
            let filtered: Float
            if useSecondaryFilter {
                sLp1 += cutoff * (p - sLp1)
                sLp2 += (cutoff * 0.9) * (sLp1 - sLp2)
                filtered = sLp2
            } else {
                lp1 += cutoff * (p - lp1)
                lp2 += (cutoff * 0.9) * (lp1 - lp2)
                filtered = lp2
            }
            return filtered * (0.48 + 0.34 * breath)
        case 2: // Soft Heartbeat: warm 64 BPM muffled double-thump + gentle womb cushion
            let p = nextPink()
            let cushion: Float
            if useSecondaryFilter {
                sLp1 += 0.024 * (p - sLp1)
                cushion = sLp1
            } else {
                lp1 += 0.024 * (p - lp1)
                cushion = lp1
            }
            let period = 60.0 / 64.0
            let phase = t.truncatingRemainder(dividingBy: period)
            var beat: Double = 0
            if phase < 0.16 {
                let env = exp(-phase * 28) * min(1, phase / 0.012)
                beat += sin(2 * .pi * 54 * phase) * env * 0.72
            }
            let d = phase - 0.23
            if d >= 0 && d < 0.16 {
                let env = exp(-d * 30) * min(1, d / 0.012)
                beat += sin(2 * .pi * 46 * d) * env * 0.50
            }
            return cushion * 0.22 + Float(beat) * 0.58
        case 3: // Wood Lullaby: sparse C-major pentatonic soft marimba over whisper breeze
            let p = nextPink()
            let breeze: Float
            if useSecondaryFilter {
                sLp1 += 0.032 * (p - sLp1)
                breeze = sLp1
            } else {
                lp1 += 0.032 * (p - lp1)
                breeze = lp1
            }
            noteCountdown -= 1
            if noteCountdown <= 0 {
                let step = Int((seed >> 20) % 5) - 2
                let idx = max(0, min(Self.pentatonic.count - 1, lastNoteIdx + (step == 0 ? 1 : step)))
                lastNoteIdx = idx
                let freq = Self.pentatonic[idx]
                if useVoice1 {
                    voice1Freq = freq; voice1Phase = 0; voice1Amp = 0.24
                } else {
                    voice2Freq = freq; voice2Phase = 0; voice2Amp = 0.22
                }
                useVoice1.toggle()
                noteCountdown = Int(sr * (1.6 + Double((seed >> 12) % 1300) / 1000.0))
            }
            var notes: Float = 0
            if voice1Amp > 0.0001 {
                notes += Float(sin(voice1Phase) + 0.12 * sin(voice1Phase * 3.0) * Double(voice1Amp)) * voice1Amp
                voice1Phase += 2 * .pi * voice1Freq / sr
                voice1Amp *= 0.999925
            }
            if voice2Amp > 0.0001 {
                notes += Float(sin(voice2Phase) + 0.12 * sin(voice2Phase * 3.0) * Double(voice2Amp)) * voice2Amp
                voice2Phase += 2 * .pi * voice2Freq / sr
                voice2Amp *= 0.999925
            }
            return breeze * 0.14 + notes
        case 4: // Gentle Shush: velvety 2.4s raised-cosine parent shush cadence over soft warmth
            let p = nextPink()
            let band: Float
            let base: Float
            if useSecondaryFilter {
                sLp1 += 0.34 * (p - sLp1)
                sLp2 += 0.09 * (p - sLp2)
                band = sLp1 - sLp2
                base = sLp2
            } else {
                lp1 += 0.34 * (p - lp1)
                lp2 += 0.09 * (p - lp2)
                band = lp1 - lp2
                base = lp2
            }
            let pos = t.truncatingRemainder(dividingBy: 2.4)
            let shushEnv: Float = pos < 1.15 ? Float(0.5 - 0.5 * cos(2.0 * .pi * pos / 1.15)) : 0
            return base * 0.16 + band * (0.10 + 0.56 * shushEnv)
        default: // Soft Tide: slow 8.2s asymmetric shoreline swell with retiring fine foam
            let p = nextPink()
            let norm = t.truncatingRemainder(dividingBy: 8.2) / 8.2
            let swell: Double = norm < 0.38
                ? 0.5 - 0.5 * cos(.pi * norm / 0.38)
                : 0.5 + 0.5 * cos(.pi * (norm - 0.38) / 0.62)
            let cutoff: Float = 0.022 + 0.115 * Float(swell)
            let body: Float
            let foam: Float
            if useSecondaryFilter {
                sLp1 += 0.24 * (p - sLp1)
                sLp2 += cutoff * (sLp1 - sLp2)
                body = sLp2
                foam = sLp1 - sLp2
            } else {
                lp1 += 0.24 * (p - lp1)
                lp2 += cutoff * (lp1 - lp2)
                body = lp2
                foam = lp1 - lp2
            }
            return body * (0.42 + 0.36 * Float(swell)) + foam * (0.14 * Float(swell))
        }
    }
}

/// Manages real-time soothing nursery soundscapes (with optional dual-layer harmony mixing) for Otto's Bedside Lamp.
@Observable
@MainActor
final class SoundscapeEngine {
    static let shared = SoundscapeEngine()

    private(set) var active: SoundscapeKind? = nil
    /// Remembers the most recently played soundscape for 1-tap resuming inside the timer cockpit.
    private(set) var lastUsedKind: SoundscapeKind = .rain
    /// Optional second soundscape blended softly underneath `active` (e.g., Paper Rain + Wood Lullaby).
    private(set) var secondary: SoundscapeKind? = nil
    var duration: SoundscapeDuration = .m30 {
        didSet {
            if active != nil {
                scheduleTimer()
                updateNowPlaying()
            }
        }
    }
    var volume: Double = 0.72 {
        didSet { dsp.userVolume = Float(max(0.05, min(1.0, volume))) }
    }
    /// Remaining seconds when a finite auto-fade timer is active; nil for continuous or stopped.
    private(set) var remainingSeconds: Int? = nil
    /// Becomes `true` only when a finite auto-fade timer reaches zero naturally (used to dim the Bedside Lamp into ember rest).
    private(set) var didFinishAutoFade: Bool = false

    var isPlaying: Bool { active != nil }

    /// Concise display label for the currently playing soundscape or dual mix.
    var activeSummary: String? {
        guard let a = active else { return nil }
        if let b = secondary {
            return "\(a.title) + \(b.title)"
        }
        return a.title
    }

    private let dsp = SoundscapeDSPState()
    private var engine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var countdownTask: Task<Void, Never>?
    private var teardownTask: Task<Void, Never>?
    private var observersRegistered = false
    private var remoteCommandsConfigured = false
    private var isTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private init() {}

    /// Pure fade curve helper (smooth cosine taper over final `fadeDuration` seconds), verified by unit tests.
    nonisolated static func fadeMultiplier(remaining: Double, fadeDuration: Double = 20) -> Float {
        guard fadeDuration > 0 else { return remaining > 0 ? 1 : 0 }
        if remaining >= fadeDuration { return 1 }
        if remaining <= 0 { return 0 }
        let x = remaining / fadeDuration
        return Float(0.5 - 0.5 * cos(.pi * x))
    }

    func toggle(_ kind: SoundscapeKind) {
        if active == kind {
            if let second = secondary {
                // Promote secondary layer smoothly to primary without clicking or losing countdown
                secondary = nil
                dsp.layerTargetMix = 0
                start(second, preserveTimer: true)
            } else {
                stop()
            }
        } else if secondary == kind {
            secondary = nil
            dsp.layerTargetMix = 0
            updateNowPlaying()
        } else {
            start(kind, preserveTimer: active != nil)
        }
    }

    /// One-tap cockpit toggle: stops if currently playing, or resumes the last chosen nursery soundscape.
    func toggleQuick() {
        if isPlaying {
            stop()
        } else {
            start(lastUsedKind)
        }
    }

    func clearAutoFadeNotice() {
        didFinishAutoFade = false
    }

    /// Blends a second soundscape softly alongside the active one (or starts it if nothing is playing).
    func toggleLayer(_ kind: SoundscapeKind) {
        didFinishAutoFade = false
        guard let current = active else {
            start(kind)
            return
        }
        if kind == current {
            return
        }
        if secondary == kind {
            secondary = nil
            dsp.layerTargetMix = 0
        } else {
            let nextIdx = SoundscapeKind.allCases.firstIndex(of: kind) ?? -1
            dsp.layerTargetMix = 1.0
            dsp.layerKindRaw = nextIdx
            secondary = kind
        }
        updateNowPlaying()
    }

    func start(_ kind: SoundscapeKind, preserveTimer: Bool = false) {
        teardownTask?.cancel()
        teardownTask = nil
        didFinishAutoFade = false
        if secondary == kind {
            secondary = nil
            dsp.layerTargetMix = 0
        }
        dsp.kindRaw = SoundscapeKind.allCases.firstIndex(of: kind) ?? 0
        dsp.userVolume = Float(max(0.05, min(1.0, volume)))
        if let rem = remainingSeconds, preserveTimer {
            dsp.targetGain = Self.fadeMultiplier(remaining: Double(rem), fadeDuration: 20)
        } else {
            dsp.targetGain = 1.0
        }
        active = kind
        lastUsedKind = kind
        if !preserveTimer || (duration != .continuous && countdownTask == nil) {
            scheduleTimer()
        }
        guard !isTestHost else { return }
        startAudioGraph()
        registerSessionObserversIfNeeded()
        setupRemoteCommandsIfNeeded()
        updateNowPlaying()
    }

    func stop() {
        didFinishAutoFade = false
        countdownTask?.cancel()
        countdownTask = nil
        remainingSeconds = nil
        active = nil
        secondary = nil
        dsp.targetGain = 0.0
        dsp.layerTargetMix = 0.0
        guard !isTestHost else { return }
        clearNowPlaying()
        teardownTask?.cancel()
        teardownTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled, let self, self.active == nil else { return }
            self.teardownAudioGraph()
        }
    }

    /// Synchronously halts audio graph without delayed session deactivation (used when handing off to voice recording).
    func stopImmediately(deactivateSession: Bool = false) {
        teardownTask?.cancel()
        teardownTask = nil
        didFinishAutoFade = false
        countdownTask?.cancel()
        countdownTask = nil
        remainingSeconds = nil
        active = nil
        secondary = nil
        dsp.targetGain = 0.0
        dsp.layerTargetMix = 0.0
        if !isTestHost {
            clearNowPlaying()
            teardownAudioGraph(deactivateSession: deactivateSession)
        }
        dsp.currentGain = 0.0
    }

    private func completeAutoFade() {
        stop()
        didFinishAutoFade = true
    }

    private func scheduleTimer() {
        countdownTask?.cancel()
        countdownTask = nil
        guard duration != .continuous else {
            remainingSeconds = nil
            dsp.targetGain = 1.0
            return
        }
        let total = duration.rawValue * 60
        remainingSeconds = total
        countdownTask = Task { @MainActor [weak self] in
            var left = total
            while left > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self, self.active != nil else { return }
                left -= 1
                self.remainingSeconds = left
                self.dsp.targetGain = Self.fadeMultiplier(remaining: Double(left), fadeDuration: 20)
            }
            if !Task.isCancelled {
                self?.completeAutoFade()
            }
        }
    }

    private func startAudioGraph() {
        if let e = engine, e.isRunning { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)

            let eng = AVAudioEngine()
            let sr = session.sampleRate > 0 ? session.sampleRate : 44_100
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2) else { return }
            let state = dsp
            let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
                let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
                state.renderBuffer(into: abl, frameCount: Int(frameCount), sampleRate: sr)
                return noErr
            }
            eng.attach(node)
            eng.connect(node, to: eng.mainMixerNode, format: format)
            try eng.start()
            engine = eng
            sourceNode = node
        } catch {
            // Gracefully degrade if audio hardware is unavailable
        }
    }

    private func teardownAudioGraph(deactivateSession: Bool = true) {
        engine?.stop()
        if let n = sourceNode { engine?.detach(n) }
        sourceNode = nil
        engine = nil
        if deactivateSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    private func registerSessionObserversIfNeeded() {
        guard !observersRegistered else { return }
        observersRegistered = true
        let nc = NotificationCenter.default
        nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil) { [weak self] note in
            let typeVal = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optVal = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleInterruption(typeVal: typeVal, optVal: optVal)
            }
        }
        nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil) { [weak self] note in
            let reasonVal = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor [weak self] in
                self?.handleRouteChange(reasonVal: reasonVal)
            }
        }
        nc.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleEngineConfigurationChange()
            }
        }
    }

    private func handleEngineConfigurationChange() {
        guard active != nil, !isTestHost, engine?.isRunning != true else { return }
        teardownAudioGraph(deactivateSession: false)
        startAudioGraph()
        updateNowPlaying()
    }

    private func handleInterruption(typeVal: UInt?, optVal: UInt?) {
        guard let typeVal, let type = AVAudioSession.InterruptionType(rawValue: typeVal) else { return }
        switch type {
        case .began:
            dsp.targetGain = 0
        case .ended:
            guard active != nil else { return }
            let opts = optVal.map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
            if opts.contains(.shouldResume) {
                try? AVAudioSession.sharedInstance().setActive(true)
                if engine?.isRunning != true {
                    teardownAudioGraph(deactivateSession: false)
                    startAudioGraph()
                }
                if let rem = remainingSeconds {
                    dsp.targetGain = Self.fadeMultiplier(remaining: Double(rem), fadeDuration: 20)
                } else {
                    dsp.targetGain = 1.0
                }
                updateNowPlaying()
            } else {
                stop()
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(reasonVal: UInt?) {
        guard active != nil, let reasonVal,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonVal) else { return }
        if reason == .oldDeviceUnavailable {
            // Unplugging headphones gently stops playback instead of startling a sleeping baby over speaker
            stop()
            return
        }
        if engine?.isRunning != true {
            teardownAudioGraph()
            startAudioGraph()
            updateNowPlaying()
        }
    }

    private func setupRemoteCommandsIfNeeded() {
        guard !remoteCommandsConfigured else { return }
        remoteCommandsConfigured = true
        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.isEnabled = true
        cc.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.resumeFromRemoteCommand() }
            return .success
        }
        cc.pauseCommand.isEnabled = true
        cc.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.stop() }
            return .success
        }
        cc.stopCommand.isEnabled = true
        cc.stopCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.stop() }
            return .success
        }
        cc.togglePlayPauseCommand.isEnabled = true
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.isPlaying {
                    self.stop()
                } else {
                    self.resumeFromRemoteCommand()
                }
            }
            return .success
        }
    }

    private func resumeFromRemoteCommand() {
        guard active == nil else { return }
        start(lastUsedKind, preserveTimer: remainingSeconds != nil)
    }

    private func updateNowPlaying() {
        guard !isTestHost, let title = activeSummary else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: L10n.t("Otto 的床头夜灯", "Otto's Bedside Lamp"),
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyIsLiveStream: duration == .continuous,
        ]
        if let rem = remainingSeconds, duration != .continuous {
            let total = Double(duration.rawValue * 60)
            info[MPMediaItemPropertyPlaybackDuration] = total
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(0, total - Double(rem))
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func clearNowPlaying() {
        guard !isTestHost else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}

/// Pure acoustic-luminous rhythm envelope matching the exact DSP synthesis cycles in `SoundscapeDSPState`.
/// Drives Otto's Bedside Lamp glow & acoustic rings in physical lockstep with the playing nursery soundscape.
enum SoundscapeRhythmEnvelope {
    /// Returns a normalized luminous pulse `0...1` for `kind` at `time` seconds.
    static func pulse(for kind: SoundscapeKind?, at time: TimeInterval) -> Double {
        guard let kind else { return 0.35 }
        let t = time < 0 ? 0 : time
        switch kind {
        case .rain:
            // Soft organic rain shimmer (4.4s gentle cycle)
            return 0.32 + 0.36 * (0.5 + 0.5 * sin(2.0 * .pi * t / 4.4))
        case .breeze:
            // Exact 3.8s slow breathing swell matching DSP breeze filter
            return 0.14 + 0.86 * (0.5 + 0.5 * sin(2.0 * .pi * t / 3.8))
        case .heartbeat:
            // Exact 64 BPM (0.9375s) maternal lub-dub double pulse matching DSP heartbeat
            let period = 60.0 / 64.0
            let phase = t.truncatingRemainder(dividingBy: period)
            let lub: Double = phase < 0.16 ? exp(-phase * 18.0) * min(1.0, phase / 0.018) : 0.0
            let d = phase - 0.23
            let dub: Double = (d >= 0 && d < 0.16) ? exp(-d * 20.0) * min(1.0, d / 0.018) * 0.70 : 0.0
            return min(1.0, max(0.08, 0.08 + max(lub, dub) * 0.92))
        case .lullaby:
            // Soft 2.4s pentatonic marimba bell bloom
            let pos = t.truncatingRemainder(dividingBy: 2.4)
            return min(1.0, max(0.16, 0.16 + 0.84 * exp(-pos * 2.1)))
        case .shush:
            // Exact 2.4s raised-cosine parent shush cadence
            let pos = t.truncatingRemainder(dividingBy: 2.4)
            let env = pos < 1.15 ? 0.5 - 0.5 * cos(2.0 * .pi * pos / 1.15) : 0.0
            return 0.10 + 0.90 * env
        case .waves:
            // Exact 8.2s asymmetric shoreline swell (rising 38%, receding 62%)
            let norm = t.truncatingRemainder(dividingBy: 8.2) / 8.2
            let swell = norm < 0.38
                ? 0.5 - 0.5 * cos(.pi * norm / 0.38)
                : 0.5 + 0.5 * cos(.pi * (norm - 0.38) / 0.62)
            return 0.12 + 0.88 * swell
        }
    }

    /// Blends primary and optional secondary soundscape envelopes cleanly when dual-layer mixing is active.
    static func compositePulse(primary: SoundscapeKind?, secondary: SoundscapeKind?, at time: TimeInterval) -> Double {
        let p = pulse(for: primary, at: time)
        guard let secondary, secondary != primary else { return p }
        let s = pulse(for: secondary, at: time)
        return min(1.0, max(0.0, p * 0.78 + s * 0.22))
    }
}
