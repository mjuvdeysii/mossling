import Foundation
import SwiftUI
import AVFoundation
import Observation

/// Four handcrafted nursery soundscapes synthesized in real time via `AVAudioEngine` (zero audio files in bundle,
/// infinitely non-repeating, zero network). Tuned low and warm to protect infant ears.
enum SoundscapeKind: String, CaseIterable, Identifiable {
    case rain, breeze, heartbeat, lullaby
    var id: String { rawValue }

    var title: String {
        switch self {
        case .rain: L10n.t("雨落纸窗", "Paper Rain")
        case .breeze: L10n.t("草坡微风", "Meadow Breeze")
        case .heartbeat: L10n.t("温暖心跳", "Soft Heartbeat")
        case .lullaby: L10n.t("木琴摇篮", "Wood Lullaby")
        }
    }

    var subtitle: String {
        switch self {
        case .rain: L10n.t("细雨轻敲暖纸", "Rain on paper")
        case .breeze: L10n.t("随 Otto 慢呼吸", "Soft breath")
        case .heartbeat: L10n.t("舒缓低频轻拍", "64 BPM pulse")
        case .lullaby: L10n.t("五声音阶木琴", "Wood marimba")
        }
    }

    var symbol: String {
        switch self {
        case .rain: "cloud.drizzle.fill"
        case .breeze: "wind"
        case .heartbeat: "waveform.path.ecg"
        case .lullaby: "music.note"
        }
    }

    var tint: Color {
        switch self {
        case .rain: Crayon.sky
        case .breeze: Crayon.leaf
        case .heartbeat: Crayon.pink
        case .lullaby: Palette.amber
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

/// Pure lock-free DSP synthesis state shared with the real-time audio render block.
final class SoundscapeDSPState: @unchecked Sendable {
    var kindRaw: Int = 0
    var targetGain: Float = 0.0
    var currentGain: Float = 0.0
    var userVolume: Float = 0.72

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

    /// Secondary ambient harmony layer (`-1` = off, `0...3` = SoundscapeKind index).
    var layerKindRaw: Int = -1
    var layerTargetMix: Float = 0.0
    var layerCurrentMix: Float = 0.0
    // Independent low-pass state for secondary layer so filters never cross-contaminate
    var sLp1: Float = 0, sLp2: Float = 0

    /// Generates one stereo-compatible mono sample in `[-1, 1]` with smooth gain ramping and optional dual-layer mix.
    func nextSample(sampleRate sr: Double) -> Float {
        let t = Double(sampleIndex) / sr
        sampleIndex &+= 1

        // Smooth gain ramps (~250ms glide so start/stop/volume/layer transitions never click)
        let desired = targetGain * userVolume
        currentGain += (desired - currentGain) * 0.00018
        layerCurrentMix += (layerTargetMix - layerCurrentMix) * 0.00018

        let primary = synthesizeLayer(kind: kindRaw, t: t, sr: sr, useSecondaryFilter: false)
        var combined = primary
        if layerKindRaw >= 0 && layerKindRaw != kindRaw && layerCurrentMix > 0.0005 {
            let secondary = synthesizeLayer(kind: layerKindRaw, t: t, sr: sr, useSecondaryFilter: true)
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
        default: // Wood Lullaby: sparse C-major pentatonic soft marimba over whisper breeze
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
        }
    }
}

/// Manages real-time soothing nursery soundscapes (with optional dual-layer harmony mixing) for Otto's Bedside Lamp.
@Observable
@MainActor
final class SoundscapeEngine {
    static let shared = SoundscapeEngine()

    private(set) var active: SoundscapeKind? = nil
    /// Optional second soundscape blended softly underneath `active` (e.g., Paper Rain + Wood Lullaby).
    private(set) var secondary: SoundscapeKind? = nil
    var duration: SoundscapeDuration = .m30 {
        didSet { if active != nil { scheduleTimer() } }
    }
    var volume: Double = 0.72 {
        didSet { dsp.userVolume = Float(max(0.05, min(1.0, volume))) }
    }
    /// Remaining seconds when a finite auto-fade timer is active; nil for continuous or stopped.
    private(set) var remainingSeconds: Int? = nil

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
                // Promote secondary layer smoothly to primary instead of abrupt silence
                secondary = nil
                dsp.layerKindRaw = -1
                dsp.layerTargetMix = 0
                start(second)
            } else {
                stop()
            }
        } else if secondary == kind {
            secondary = nil
            dsp.layerKindRaw = -1
            dsp.layerTargetMix = 0
        } else {
            start(kind)
        }
    }

    /// Blends a second soundscape softly alongside the active one (or starts it if nothing is playing).
    func toggleLayer(_ kind: SoundscapeKind) {
        guard let current = active else {
            start(kind)
            return
        }
        if kind == current {
            return
        }
        if secondary == kind {
            secondary = nil
            dsp.layerKindRaw = -1
            dsp.layerTargetMix = 0
        } else {
            secondary = kind
            dsp.layerKindRaw = SoundscapeKind.allCases.firstIndex(of: kind) ?? -1
            dsp.layerTargetMix = 1.0
        }
    }

    func start(_ kind: SoundscapeKind) {
        if secondary == kind {
            secondary = nil
            dsp.layerKindRaw = -1
            dsp.layerTargetMix = 0
        }
        dsp.kindRaw = SoundscapeKind.allCases.firstIndex(of: kind) ?? 0
        dsp.userVolume = Float(max(0.05, min(1.0, volume)))
        dsp.targetGain = 1.0
        active = kind
        scheduleTimer()
        guard !isTestHost else { return }
        startAudioGraph()
    }

    func stop() {
        countdownTask?.cancel()
        countdownTask = nil
        remainingSeconds = nil
        active = nil
        secondary = nil
        dsp.targetGain = 0.0
        dsp.layerKindRaw = -1
        dsp.layerTargetMix = 0.0
        guard !isTestHost else { return }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(320))
            guard let self, self.active == nil else { return }
            self.teardownAudioGraph()
        }
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
                self?.stop()
            }
        }
    }

    private func startAudioGraph() {
        if let e = engine, e.isRunning { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            let eng = AVAudioEngine()
            let sr = session.sampleRate > 0 ? session.sampleRate : 44_100
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 2) else { return }
            let state = dsp
            let node = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
                let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
                for frame in 0..<Int(frameCount) {
                    let s = state.nextSample(sampleRate: sr)
                    for buf in abl {
                        if let ptr = buf.mData?.assumingMemoryBound(to: Float.self) {
                            ptr[frame] = s
                        }
                    }
                }
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

    private func teardownAudioGraph() {
        engine?.stop()
        if let n = sourceNode { engine?.detach(n) }
        sourceNode = nil
        engine = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
