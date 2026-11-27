import Foundation
import AVFoundation
import CoreHaptics
import UIKit

/// Handcrafted Montessori tactile feedback: subtle wooden/vinyl micro-acoustics paired with custom CoreHaptics
/// textures. Automatically obeys the hardware Silent Switch, and stays completely quiet whenever Night Lamp or a
/// sleep timer is active so a late-night tap never wakes a sleeping baby.
@MainActor
final class TactileEngine {
    static let shared = TactileEngine()

    /// User preference ("轻柔手感音效 / Tactile Sounds"), synced from `AppModel`.
    var soundEnabled: Bool = true
    /// Automatically set when Night Lamp is active or a sleep timer is running: haptics remain gentle, sounds mute.
    var quietNight: Bool = false

    enum Cue {
        case beadClick     // crisp Montessori wooden bead tap (GrowthMap, StepBeadBar, RhythmDial)
        case dimmerTick    // fine mechanical brass detent (Bedside Lamp dimmer)
        case vinylPop      // soft cushioned vinyl squish (poking Moss/Otto, stamping a sticker)
        case pageTurn      // feather-soft paper brush (day flip, Storybook page turn)
        case goldChime     // warm 2-note wooden marimba fifth (finishing a play, logging a First)
        case breathInhale  // silent 4-6 inhale boundary cue for eyes-closed bedside soothing
        case breathExhale  // silent 4-6 exhale boundary cue for eyes-closed bedside soothing
        case palmPat       // strictly silent rhythmic palm-pat comfort pulse for Bedside Lamp soothing
    }

    private var hapticEngine: CHHapticEngine?
    private var audioEngine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]
    private let sampleRate: Double = 44_100
    private var isTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private init() {}

    /// Plays the tactile haptic + (when appropriate) wooden micro-acoustic for `cue`.
    func play(_ cue: Cue) {
        guard !isTestHost else { return }
        fireHaptic(cue)
        switch cue {
        case .breathInhale, .breathExhale, .palmPat:
            return
        default:
            break
        }
        guard soundEnabled, !quietNight, !SoundscapeEngine.shared.isPlaying, !FirstVoiceController.shared.isRecording else { return }
        fireSound(cue)
    }

    /// Convenience shortcuts matching Moss & Otto's physical world.
    func beadClick() { play(.beadClick) }
    func dimmerTick() { play(.dimmerTick) }
    func vinylPop() { play(.vinylPop) }
    func pageTurn() { play(.pageTurn) }
    func goldChime() { play(.goldChime) }

    /// Silent fingertip cadence cue for Bedside Lamp 4-6 breathing (never emits audio).
    func breathCue(inhaling: Bool) {
        guard !isTestHost else { return }
        fireHaptic(inhaling ? .breathInhale : .breathExhale)
    }

    /// Strictly silent rhythmic palm-pat pulse (low-sharpness cushioned waveform, never emits sound).
    func palmPatPulse(intensity: Float = 0.56) {
        guard !isTestHost else { return }
        let clamped = max(0.20, min(0.85, intensity))
        if let engine = ensureHaptics() {
            let events = [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: clamped),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.14)
                ], relativeTime: 0, duration: 0.085),
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: clamped * 0.44),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.10)
                ], relativeTime: 0.095, duration: 0.045)
            ]
            if let pattern = try? CHHapticPattern(events: events, parameters: []) {
                do {
                    try engine.start()
                    let p = try engine.makePlayer(with: pattern)
                    try p.start(atTime: CHHapticTimeImmediate)
                    return
                } catch {
                    // Fall through to soft UIImpactFeedbackGenerator
                }
            }
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: CGFloat(clamped))
    }

    // MARK: - CoreHaptics

    private func ensureHaptics() -> CHHapticEngine? {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        if let e = hapticEngine { return e }
        do {
            let e = try CHHapticEngine()
            e.isAutoShutdownEnabled = true
            e.resetHandler = { [weak self] in
                Task { @MainActor in self?.hapticEngine = nil }
            }
            e.stoppedHandler = { [weak self] _ in
                Task { @MainActor in self?.hapticEngine = nil }
            }
            try e.start()
            hapticEngine = e
            return e
        } catch {
            return nil
        }
    }

    private func fireHaptic(_ cue: Cue) {
        if let engine = ensureHaptics(), let pattern = hapticPattern(for: cue) {
            do {
                try engine.start()
                let p = try engine.makePlayer(with: pattern)
                try p.start(atTime: CHHapticTimeImmediate)
                return
            } catch {
                // Fall through to UIKit feedback generator
            }
        }
        switch cue {
        case .beadClick, .dimmerTick, .pageTurn:
            UISelectionFeedbackGenerator().selectionChanged()
        case .vinylPop:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
        case .goldChime:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .breathInhale:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.45)
        case .breathExhale:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.28)
        case .palmPat:
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.56)
        }
    }

    private func hapticPattern(for cue: Cue) -> CHHapticPattern? {
        let events: [CHHapticEvent]
        switch cue {
        case .beadClick:
            // Crisp wooden tap: tight transient with warm sharpness
            events = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.55),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.68)
                ], relativeTime: 0)
            ]
        case .dimmerTick:
            // Ultra-fine brass dial detent
            events = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.34),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.85)
                ], relativeTime: 0)
            ]
        case .vinylPop:
            // Soft matte-vinyl give + light rebound
            events = [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.42),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.20)
                ], relativeTime: 0, duration: 0.055),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.30)
                ], relativeTime: 0.075)
            ]
        case .pageTurn:
            // Feather-soft paper brush
            events = [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.22),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.35)
                ], relativeTime: 0, duration: 0.045)
            ]
        case .goldChime:
            // Three cascading golden beads landing on a wooden tray
            events = [
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.50),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.55)
                ], relativeTime: 0),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.65),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.65)
                ], relativeTime: 0.085),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.40),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.78)
                ], relativeTime: 0.17)
            ]
        case .breathInhale:
            // Gentle double-soft pulse marking start of 4s inhale
            events = [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.28),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.18)
                ], relativeTime: 0, duration: 0.12),
                CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.36),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.28)
                ], relativeTime: 0.13)
            ]
        case .breathExhale:
            // Feather-soft long settling release marking start of 6s exhale
            events = [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.22),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.12)
                ], relativeTime: 0, duration: 0.16)
            ]
        case .palmPat:
            events = [
                CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.56),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.14)
                ], relativeTime: 0, duration: 0.085)
            ]
        }
        return try? CHHapticPattern(events: events, parameters: [])
    }

    // MARK: - Procedural Micro-Acoustics (0 KB bundled audio)

    private func teardownAudio() {
        player?.stop()
        audioEngine?.stop()
        player = nil
        audioEngine = nil
    }

    private func ensureAudio() -> AVAudioPlayerNode? {
        guard !FirstVoiceController.shared.isRecording,
              FirstVoiceController.shared.playingID == nil,
              !SoundscapeEngine.shared.isPlaying else { return nil }
        if let p = player, let e = audioEngine {
            if !e.isRunning {
                do { try e.start() } catch { teardownAudio(); return nil }
            }
            guard e.isRunning else { teardownAudio(); return nil }
            if !p.isPlaying { p.play() }
            return p
        }
        do {
            let session = AVAudioSession.sharedInstance()
            // Preserve .playback or .playAndRecord when already active (e.g., Toybox or SpeechReader) so Silent mode doesn't drop
            if session.category != .playback && session.category != .playAndRecord {
                try session.setCategory(.ambient, options: [.mixWithOthers])
            }
            try session.setActive(true, options: [])
            let engine = AVAudioEngine()
            let node = AVAudioPlayerNode()
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return nil }
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = 0.55
            try engine.start()
            guard engine.isRunning else { teardownAudio(); return nil }
            node.play()
            audioEngine = engine
            player = node
            return node
        } catch {
            teardownAudio()
            return nil
        }
    }

    private func fireSound(_ cue: Cue) {
        guard let node = ensureAudio(), let buf = buffer(for: cue) else { return }
        node.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
    }

    private func buffer(for cue: Cue) -> AVAudioPCMBuffer? {
        if let existing = buffers[cue] { return existing }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return nil }
        let dur: Double = switch cue {
        case .beadClick: 0.032
        case .dimmerTick: 0.016
        case .vinylPop: 0.055
        case .pageTurn: 0.065
        case .goldChime: 0.44
        case .breathInhale, .breathExhale, .palmPat: 0.01
        }
        let frames = AVAudioFrameCount(dur * sampleRate)
        guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let ptr = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = frames

        var seed: UInt64 = 0x517CC1B727220A95
        func nextWhite() -> Float {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Float(Int32(bitPattern: UInt32(truncatingIfNeeded: seed >> 32))) / Float(Int32.max)
        }

        var lp: Float = 0
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let sample: Float
            switch cue {
            case .beadClick:
                // Warm wooden Montessori bead click (840 Hz + harmonic + soft transient)
                let env = Float(exp(-t * 145))
                let attack = Float(min(1, t / 0.0012))
                let wood = Float(sin(2 * .pi * 840 * t) * 0.72 + sin(2 * .pi * 1790 * t) * 0.28)
                let click = nextWhite() * Float(exp(-t * 600)) * 0.18
                sample = (wood + click) * env * attack * 0.24
            case .dimmerTick:
                // Crisp subtle brass detent
                let env = Float(exp(-t * 280))
                let tone = Float(sin(2 * .pi * 1240 * t))
                sample = tone * env * 0.14
            case .vinylPop:
                // Cushioned matte-vinyl pitch sweep (220 Hz -> 320 Hz)
                let p = t / dur
                let freq = 220 + 100 * p
                let env = Float(sin(.pi * p)) * Float(exp(-t * 30))
                sample = Float(sin(2 * .pi * freq * t)) * env * 0.22
            case .pageTurn:
                // Feather-soft filtered paper brush
                let p = t / dur
                let env = Float(sin(.pi * p))
                let w = nextWhite()
                lp = lp * 0.72 + w * 0.28
                let hp = w - lp * 0.6
                sample = hp * env * 0.09
            case .goldChime:
                // Delicate 2-note wooden marimba fifth (C6 + G6 at +90ms)
                let env1 = Float(exp(-t * 9.5)) * Float(min(1, t / 0.003))
                let n1 = Float(sin(2 * .pi * 1046.5 * t) + 0.18 * sin(2 * .pi * 3139.5 * t) * exp(-t * 30)) * env1
                let t2 = max(0, t - 0.09)
                let env2: Float = t >= 0.09 ? Float(exp(-t2 * 8.5)) * Float(min(1, t2 / 0.003)) : 0
                let n2 = Float(sin(2 * .pi * 1567.98 * t2) + 0.15 * sin(2 * .pi * 4703.9 * t2) * exp(-t2 * 32)) * env2
                sample = (n1 * 0.55 + n2 * 0.55) * 0.18
            case .breathInhale, .breathExhale, .palmPat:
                sample = 0
            }
            ptr[i] = max(-0.95, min(0.95, sample))
        }
        buffers[cue] = buf
        return buf
    }
}
