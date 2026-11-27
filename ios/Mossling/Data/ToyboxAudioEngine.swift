import Foundation
import Observation
import SwiftUI
import AVFoundation

/// Synthesized acoustic timbres for the Sensory Toybox keyboard (100% offline DSP, 0 KB assets).
enum ToyboxTimbre: String, CaseIterable, Identifiable, Sendable {
    case marimba, musicBox, kalimba
    var id: String { rawValue }

    var title: String {
        switch self {
        case .marimba: L10n.t("木琴", "Rosewood")
        case .musicBox: L10n.t("八音盒", "Music Box")
        case .kalimba: L10n.t("拇指琴", "Kalimba")
        }
    }

    var symbol: String {
        switch self {
        case .marimba: "rectangle.grid.1x2.fill"
        case .musicBox: "sparkles"
        case .kalimba: "hand.tap.fill"
        }
    }
}

/// Curated parent-baby nursery & folk melodies playable in Listen or Follow-the-Glow mode.
enum ToyboxMelody: String, CaseIterable, Identifiable, Sendable {
    case twinkle, jasmine, brahms, odeToJoy, maryLamb, rowBoat
    var id: String { rawValue }

    var title: String {
        switch self {
        case .twinkle: L10n.t("小星星", "Twinkle Star")
        case .jasmine: L10n.t("茉莉花", "Jasmine Flower")
        case .brahms: L10n.t("摇篮曲", "Brahms Lullaby")
        case .odeToJoy: L10n.t("欢乐颂", "Ode to Joy")
        case .maryLamb: L10n.t("小羊羔", "Little Lamb")
        case .rowBoat: L10n.t("划小船", "Row Your Boat")
        }
    }

    var subtitle: String {
        switch self {
        case .twinkle: L10n.t("轻柔睡前 · 14 音", "Bedtime classic · 14 notes")
        case .jasmine: L10n.t("五声民谣 · 37 音", "Pentatonic · 37 notes")
        case .brahms: L10n.t("温润安抚 · 27 音", "Warm soothe · 27 notes")
        case .odeToJoy: L10n.t("明快欢愉 · 15 音", "Bright rhythm · 15 notes")
        case .maryLamb: L10n.t("童谣慢拍 · 26 音", "Nursery beat · 26 notes")
        case .rowBoat: L10n.t("轻快摇摆 · 27 音", "Gentle sway · 27 notes")
        }
    }

    /// Pairs of `(scaleIndex 0..<8, durationSeconds)`.
    var notes: [(Int, Double)] {
        switch self {
        case .twinkle:
            return [
                (0, 0.42), (0, 0.42), (4, 0.42), (4, 0.42), (5, 0.42), (5, 0.42), (4, 0.82),
                (3, 0.42), (3, 0.42), (2, 0.42), (2, 0.42), (1, 0.42), (1, 0.42), (0, 0.85),
            ]
        case .jasmine:
            return [
                (2, 0.42), (2, 0.24), (4, 0.24), (5, 0.24), (7, 0.24), (7, 0.24), (5, 0.24), (4, 0.50),
                (4, 0.28), (5, 0.28), (4, 0.72),
                (2, 0.42), (2, 0.24), (4, 0.24), (5, 0.24), (7, 0.24), (7, 0.24), (5, 0.24), (4, 0.50),
                (4, 0.28), (5, 0.28), (4, 0.72),
                (4, 0.36), (4, 0.36), (4, 0.36), (2, 0.36), (4, 0.36), (5, 0.36), (5, 0.28), (4, 0.70),
                (2, 0.36), (1, 0.24), (2, 0.24), (4, 0.42), (2, 0.24), (1, 0.24), (0, 0.86),
            ]
        case .brahms:
            return [
                (2, 0.36), (2, 0.36), (4, 0.84),
                (2, 0.36), (2, 0.36), (4, 0.84),
                (2, 0.34), (4, 0.34), (7, 0.68), (6, 0.46), (5, 0.36), (5, 0.36), (4, 0.76),
                (1, 0.34), (2, 0.34), (3, 0.52), (1, 0.60),
                (1, 0.34), (2, 0.34), (3, 0.68),
                (1, 0.34), (3, 0.34), (6, 0.34), (5, 0.34), (4, 0.42), (6, 0.42), (7, 0.88),
            ]
        case .odeToJoy:
            return [
                (2, 0.38), (2, 0.38), (3, 0.38), (4, 0.38), (4, 0.38), (3, 0.38), (2, 0.38), (1, 0.38),
                (0, 0.38), (0, 0.38), (1, 0.38), (2, 0.38), (2, 0.54), (1, 0.26), (1, 0.82),
            ]
        case .maryLamb:
            return [
                (2, 0.38), (1, 0.38), (0, 0.38), (1, 0.38), (2, 0.38), (2, 0.38), (2, 0.72),
                (1, 0.38), (1, 0.38), (1, 0.72), (2, 0.38), (4, 0.38), (4, 0.72),
                (2, 0.38), (1, 0.38), (0, 0.38), (1, 0.38), (2, 0.38), (2, 0.38), (2, 0.38), (2, 0.38),
                (1, 0.38), (1, 0.38), (2, 0.38), (1, 0.38), (0, 0.84),
            ]
        case .rowBoat:
            return [
                (0, 0.46), (0, 0.46), (0, 0.34), (1, 0.22), (2, 0.50),
                (2, 0.34), (1, 0.22), (2, 0.34), (3, 0.22), (4, 0.72),
                (7, 0.24), (7, 0.24), (7, 0.24), (4, 0.24), (4, 0.24), (4, 0.24),
                (2, 0.24), (2, 0.24), (2, 0.24), (0, 0.24), (0, 0.24), (0, 0.24),
                (4, 0.34), (3, 0.22), (2, 0.34), (1, 0.22), (0, 0.84),
            ]
        }
    }
}

/// One graduated wooden bar on Moss's Montessori Xylophone (C5 major octave).
struct ToyboxNote: Identifiable, Sendable {
    let index: Int
    let frequency: Double
    let solfege: String
    let numberLabel: String
    let pitchName: String
    let colorHex: UInt32
    /// Relative horizontal width fraction (longest bar for bass C5, shortest for treble C6).
    let widthRatio: CGFloat

    var id: Int { index }
    var color: Color { Color(hex: colorHex) }

    /// Ordered bottom-to-top from low C5 (index 0) to high C6 (index 7).
    static let scale: [ToyboxNote] = [
        ToyboxNote(index: 0, frequency: 523.25, solfege: "Do",  numberLabel: "1",  pitchName: "C5", colorHex: 0xD9534F, widthRatio: 1.00),
        ToyboxNote(index: 1, frequency: 587.33, solfege: "Re",  numberLabel: "2",  pitchName: "D5", colorHex: 0xEE8B2E, widthRatio: 0.94),
        ToyboxNote(index: 2, frequency: 659.25, solfege: "Mi",  numberLabel: "3",  pitchName: "E5", colorHex: 0xE5B82E, widthRatio: 0.88),
        ToyboxNote(index: 3, frequency: 698.46, solfege: "Fa",  numberLabel: "4",  pitchName: "F5", colorHex: 0x57A95A, widthRatio: 0.82),
        ToyboxNote(index: 4, frequency: 783.99, solfege: "Sol", numberLabel: "5",  pitchName: "G5", colorHex: 0x0E9A8E, widthRatio: 0.76),
        ToyboxNote(index: 5, frequency: 880.00, solfege: "La",  numberLabel: "6",  pitchName: "A5", colorHex: 0x3D8AD6, widthRatio: 0.70),
        ToyboxNote(index: 6, frequency: 987.77, solfege: "Ti",  numberLabel: "7",  pitchName: "B5", colorHex: 0x8F6AC8, widthRatio: 0.64),
        ToyboxNote(index: 7, frequency: 1046.50, solfege: "Do'", numberLabel: "1̇", pitchName: "C6", colorHex: 0xDC6B95, widthRatio: 0.58),
    ]

    /// Gentle traditional lullaby phrase (index into `scale`, pause after in seconds).
    static var lullabyPhrase: [(Int, Double)] { ToyboxMelody.twinkle.notes }
}

/// Zero-asset polyphonic wooden marimba, music-box, kalimba & rainstick bead synthesizer for the Sensory Toybox.
/// Synthesizes warm acoustic voices and soft beechwood bead clicks in real time via `AVAudioEngine`.
@Observable
@MainActor
final class ToyboxAudioEngine {
    static let shared = ToyboxAudioEngine()

    private(set) var routeStopGeneration: Int = 0
    private let sampleRate: Double = 44_100
    private var engine: AVAudioEngine?
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayerIndex = 0
    private var noteBuffers: [String: AVAudioPCMBuffer] = [:]
    private var beadBuffers: [AVAudioPCMBuffer] = []
    private var chimeBuffers: [AVAudioPCMBuffer] = []
    private var lastBeadSoundAt: TimeInterval = 0
    private var lastRainChimeAt: TimeInterval = 0
    private var lastChimeSoundAt: TimeInterval = 0
    private var arpeggioTask: Task<Void, Never>?
    private var observersRegistered = false

    var isPlaying: Bool { engine?.isRunning == true }

    private var isTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private init() {}

    /// Pure deterministic wooden marimba synthesis in `[-1, 1]` (rosewood fundamental + 4th harmonic + felt mallet tap).
    nonisolated static func synthesizeMarimbaSamples(frequency: Double, sampleRate: Double = 44_100, duration: Double = 0.72) -> [Float] {
        let count = max(1, Int(duration * sampleRate))
        var out = [Float](repeating: 0, count: count)
        var seed: UInt64 = UInt64(bitPattern: Int64(frequency * 1000)) ^ 0x9E3779B97F4A7C15
        let twoPi = 2.0 * Double.pi
        for i in 0..<count {
            let t = Double(i) / sampleRate
            // Smooth 2.5ms felt-mallet attack and 20ms tail fade so polyphonic notes never click
            let attack = min(1.0, t / 0.0025)
            let tail = t > duration - 0.02 ? max(0.0, (duration - t) / 0.02) : 1.0
            let fundamental = sin(twoPi * frequency * t) * exp(-t * 4.8)
            // Classic marimba bar overtone (~3.98x fundamental) decays quickly for woody warmth
            let overtone = sin(twoPi * frequency * 3.98 * t) * exp(-t * 26.0) * 0.24
            // Subtle warm body octave
            let body = sin(twoPi * frequency * 2.0 * t) * exp(-t * 14.0) * 0.11
            // Soft felt mallet transient (~3ms)
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let noise = Double(Int32(bitPattern: UInt32(truncatingIfNeeded: seed >> 32))) / Double(Int32.max)
            let mallet = noise * exp(-t * 420.0) * 0.09
            let s = (fundamental * 0.72 + overtone + body + mallet) * attack * tail * 0.58
            out[i] = Float(max(-0.95, min(0.95, s)))
        }
        return out
    }

    /// Pure deterministic celesta / wind-up brass music box synthesis in `[-1, 1]`.
    nonisolated static func synthesizeMusicBoxSamples(frequency: Double, sampleRate: Double = 44_100, duration: Double = 0.90) -> [Float] {
        let count = max(1, Int(duration * sampleRate))
        var out = [Float](repeating: 0, count: count)
        var seed: UInt64 = UInt64(bitPattern: Int64(frequency * 1337)) ^ 0x517CC1B727220A95
        let twoPi = 2.0 * Double.pi
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let attack = min(1.0, t / 0.0015)
            let tail = t > duration - 0.03 ? max(0.0, (duration - t) / 0.03) : 1.0
            let fundamental = sin(twoPi * frequency * t) * exp(-t * 3.2)
            let comb1 = sin(twoPi * frequency * 2.756 * t) * exp(-t * 12.0) * 0.30
            let comb2 = sin(twoPi * frequency * 5.404 * t) * exp(-t * 28.0) * 0.12
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let noise = Double(Int32(bitPattern: UInt32(truncatingIfNeeded: seed >> 32))) / Double(Int32.max)
            let pluck = noise * exp(-t * 720.0) * 0.07
            let s = (fundamental * 0.64 + comb1 + comb2 + pluck) * attack * tail * 0.52
            out[i] = Float(max(-0.95, min(0.95, s)))
        }
        return out
    }

    /// Pure deterministic African thumb-piano (kalimba) wooden resonator + metal tine synthesis in `[-1, 1]`.
    nonisolated static func synthesizeKalimbaSamples(frequency: Double, sampleRate: Double = 44_100, duration: Double = 0.80) -> [Float] {
        let count = max(1, Int(duration * sampleRate))
        var out = [Float](repeating: 0, count: count)
        let twoPi = 2.0 * Double.pi
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let attack = min(1.0, t / 0.003)
            let tail = t > duration - 0.025 ? max(0.0, (duration - t) / 0.025) : 1.0
            let fundamental = sin(twoPi * frequency * t) * exp(-t * 4.0)
            let warmOctave = sin(twoPi * frequency * 2.0 * t) * exp(-t * 9.5) * 0.22
            let tine = sin(twoPi * frequency * 6.20 * t) * exp(-t * 38.0) * 0.11
            // Soft hollow wooden soundbox thumb thump at onset
            let boxThump = sin(twoPi * 165.0 * t) * exp(-t * 95.0) * 0.18
            let s = (fundamental * 0.68 + warmOctave + tine + boxThump) * attack * tail * 0.56
            out[i] = Float(max(-0.95, min(0.95, s)))
        }
        return out
    }

    /// Pure deterministic wooden bead impact sound in `[-1, 1]` for the Montessori Rainstick.
    nonisolated static func synthesizeBeadClickSamples(pitchScale: Double, sampleRate: Double = 44_100) -> [Float] {
        let duration = 0.028
        let count = max(1, Int(duration * sampleRate))
        var out = [Float](repeating: 0, count: count)
        let f1 = 760.0 * max(0.6, min(1.6, pitchScale))
        let f2 = 1690.0 * max(0.6, min(1.6, pitchScale))
        let twoPi = 2.0 * Double.pi
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let attack = min(1.0, t / 0.0008)
            let env = exp(-t * 165.0)
            let wood = sin(twoPi * f1 * t) * 0.68 + sin(twoPi * f2 * t) * 0.32
            let s = wood * env * attack * 0.22
            out[i] = Float(max(-0.95, min(0.95, s)))
        }
        return out
    }

    /// Plays one xylophone bar in the selected timbre with polyphonic overlap (up to 6 simultaneous voices).
    func playNote(_ note: ToyboxNote, timbre: ToyboxTimbre = .marimba) {
        guard !isTestHost else { return }
        guard let player = nextPlayer(), let buf = buffer(for: note, timbre: timbre) else { return }
        player.stop()
        player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        player.play()
    }

    /// Plays a gentle wooden rainstick bead click, rate-limited so cascades sound silky and natural.
    func playBeadClick(intensity: Double = 0.7) {
        guard !isTestHost else { return }
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastBeadSoundAt >= 0.062 else { return }
        lastBeadSoundAt = now
        guard let player = nextPlayer(), let buf = randomBeadBuffer() else { return }
        player.volume = Float(max(0.25, min(0.85, intensity)))
        player.stop()
        player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        player.play()
    }

    /// Plays a soft height-mapped pentatonic rainstick peg chime when Chime sound mode is enabled.
    func playRainstickChime(normalizedY: Double, intensity: Double = 0.7) {
        guard !isTestHost else { return }
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastRainChimeAt >= 0.075 else { return }
        lastRainChimeAt = now
        guard let player = nextPlayer(), let buf = chimeBuffer(normalizedY: normalizedY) else { return }
        player.volume = Float(max(0.22, min(0.68, intensity * 0.75)))
        player.stop()
        player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        player.play()
    }

    /// Pure deterministic pentatonic wind-chime / celesta sparkle in `[-1, 1]` for the Firefly Lantern Jar.
    nonisolated static func synthesizeChimeSamples(frequency: Double, sampleRate: Double = 44_100, duration: Double = 0.65) -> [Float] {
        let count = max(1, Int(duration * sampleRate))
        var out = [Float](repeating: 0, count: count)
        let twoPi = 2.0 * Double.pi
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let attack = min(1.0, t / 0.008)
            let tail = t > duration - 0.04 ? max(0.0, (duration - t) / 0.04) : 1.0
            let f1 = sin(twoPi * frequency * t) * exp(-t * 4.5)
            let f2 = sin(twoPi * frequency * 2.0 * t) * exp(-t * 8.5) * 0.28
            let bell = sin(twoPi * frequency * 2.756 * t) * exp(-t * 16.0) * 0.14
            let s = (f1 * 0.68 + f2 + bell) * attack * tail * 0.34
            out[i] = Float(max(-0.95, min(0.95, s)))
        }
        return out
    }

    /// Plays a delicate pentatonic firefly wind-chime scaled smoothly by vertical height `normalizedY` (0 = top/high).
    func playFireflyChime(normalizedY: Double) {
        guard !isTestHost else { return }
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastChimeSoundAt >= 0.14 else { return }
        lastChimeSoundAt = now
        guard let player = nextPlayer(), let buf = chimeBuffer(normalizedY: normalizedY) else { return }
        player.volume = 0.72
        player.stop()
        player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
        player.play()
    }

    /// Plays a gentle 4-note cascading pentatonic arpeggio for Firefly swirls & formation shifts.
    func playFireflyArpeggio(ascending: Bool = true) {
        guard !isTestHost else { return }
        arpeggioTask?.cancel()
        let steps: [Double] = ascending ? [0.85, 0.62, 0.38, 0.14] : [0.14, 0.38, 0.62, 0.85]
        arpeggioTask = Task { @MainActor [weak self] in
            for y in steps {
                guard !Task.isCancelled, let self else { break }
                if let player = self.nextPlayer(), let buf = self.chimeBuffer(normalizedY: y) {
                    player.volume = 0.54
                    player.stop()
                    player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
                    player.play()
                }
                try? await Task.sleep(for: .milliseconds(85))
            }
        }
    }

    /// Stops and releases the toybox audio engine when leaving the studio.
    func stop() {
        let hadEngine = (engine != nil)
        arpeggioTask?.cancel()
        arpeggioTask = nil
        for p in players { p.stop() }
        engine?.stop()
        engine = nil
        players = []
        if hadEngine && !SoundscapeEngine.shared.hasActiveEngine && !FirstVoiceController.shared.isRecording && FirstVoiceController.shared.playingID == nil {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    // MARK: - Audio Engine Pool

    private func ensureEngine() -> Bool {
        guard !FirstVoiceController.shared.isRecording else { return false }
        if SoundscapeEngine.shared.hasActiveEngine {
            SoundscapeEngine.shared.stopImmediately(deactivateSession: false)
        }
        if FirstVoiceController.shared.playingID != nil {
            FirstVoiceController.shared.stopPlayback()
        }
        registerObserversIfNeeded()
        if let e = engine {
            if e.isRunning { return true }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default, options: [])
                try session.setActive(true, options: [])
                try e.start()
                if e.isRunning { return true }
            } catch {
                for p in players { p.stop() }
                e.stop()
                engine = nil
                players = []
            }
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true, options: [])
            let e = AVAudioEngine()
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return false }
            var pool: [AVAudioPlayerNode] = []
            for _ in 0..<6 {
                let node = AVAudioPlayerNode()
                e.attach(node)
                e.connect(node, to: e.mainMixerNode, format: format)
                pool.append(node)
            }
            e.mainMixerNode.outputVolume = 0.72
            try e.start()
            engine = e
            players = pool
            return true
        } catch {
            return false
        }
    }

    private func registerObserversIfNeeded() {
        guard !observersRegistered, !isTestHost else { return }
        observersRegistered = true
        let nc = NotificationCenter.default
        nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil) { [weak self] note in
            let typeVal = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optVal = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self, let typeVal, let type = AVAudioSession.InterruptionType(rawValue: typeVal) else { return }
                switch type {
                case .began:
                    self.arpeggioTask?.cancel()
                    self.arpeggioTask = nil
                    for p in self.players { p.stop() }
                    self.engine?.pause()
                case .ended:
                    let opts = optVal.map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
                    if opts.contains(.shouldResume), let e = self.engine, !FirstVoiceController.shared.isRecording, !SoundscapeEngine.shared.hasActiveEngine {
                        let session = AVAudioSession.sharedInstance()
                        try? session.setCategory(.playback, mode: .default, options: [])
                        try? session.setActive(true)
                        try? e.start()
                    }
                @unknown default:
                    break
                }
            }
        }
        nc.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: nil) { [weak self] note in
            let reasonVal = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self, let reasonVal, let reason = AVAudioSession.RouteChangeReason(rawValue: reasonVal) else { return }
                if reason == .oldDeviceUnavailable {
                    self.routeStopGeneration &+= 1
                    self.stop()
                }
            }
        }
        nc.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: nil) { [weak self] note in
            let senderID = note.object.map { ObjectIdentifier($0 as AnyObject) }
            Task { @MainActor [weak self] in
                guard let self, let eng = self.engine, senderID == ObjectIdentifier(eng) else { return }
                for p in self.players { p.stop() }
                eng.stop()
                self.engine = nil
                self.players = []
            }
        }
    }

    private func nextPlayer() -> AVAudioPlayerNode? {
        guard ensureEngine(), !players.isEmpty else { return nil }
        let node = players[nextPlayerIndex % players.count]
        nextPlayerIndex = (nextPlayerIndex + 1) % players.count
        node.volume = 1.0
        return node
    }

    private func buffer(for note: ToyboxNote, timbre: ToyboxTimbre) -> AVAudioPCMBuffer? {
        let key = "\(timbre.rawValue)-\(note.index)"
        if let cached = noteBuffers[key] { return cached }
        let samples: [Float] = switch timbre {
        case .marimba: Self.synthesizeMarimbaSamples(frequency: note.frequency, sampleRate: sampleRate)
        case .musicBox: Self.synthesizeMusicBoxSamples(frequency: note.frequency, sampleRate: sampleRate)
        case .kalimba: Self.synthesizeKalimbaSamples(frequency: note.frequency, sampleRate: sampleRate)
        }
        guard let buf = makeBuffer(from: samples) else { return nil }
        noteBuffers[key] = buf
        return buf
    }

    private func randomBeadBuffer() -> AVAudioPCMBuffer? {
        if beadBuffers.isEmpty {
            let scales: [Double] = [0.84, 0.92, 1.0, 1.08, 1.18, 1.26]
            beadBuffers = scales.compactMap { makeBuffer(from: Self.synthesizeBeadClickSamples(pitchScale: $0, sampleRate: sampleRate)) }
        }
        guard !beadBuffers.isEmpty else { return nil }
        return beadBuffers[Int.random(in: 0..<beadBuffers.count)]
    }

    private func chimeBuffer(normalizedY: Double) -> AVAudioPCMBuffer? {
        if chimeBuffers.isEmpty {
            // High airy C-major pentatonic shimmer (G5, A5, C6, D6, E6, G6)
            let freqs: [Double] = [783.99, 880.00, 1046.50, 1174.66, 1318.51, 1567.98]
            chimeBuffers = freqs.compactMap { makeBuffer(from: Self.synthesizeChimeSamples(frequency: $0, sampleRate: sampleRate)) }
        }
        guard !chimeBuffers.isEmpty else { return nil }
        let clamped = max(0.0, min(0.999, 1.0 - normalizedY))
        let idx = Int(clamped * Double(chimeBuffers.count))
        return chimeBuffers[max(0, min(chimeBuffers.count - 1, idx))]
    }

    private func makeBuffer(from samples: [Float]) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let dst = buf.floatChannelData?[0] else { return nil }
        buf.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            if let base = src.baseAddress {
                dst.update(from: base, count: samples.count)
            }
        }
        return buf
    }
}

// MARK: - Montessori Bead Rainstick Physics (Pure & Deterministic)

/// Baffle peg layout inside the Montessori Rainstick wooden tray.
enum RainstickLayout: String, CaseIterable, Identifiable, Sendable {
    case cascade, hourglass, wreath
    var id: String { rawValue }

    var title: String {
        switch self {
        case .cascade: L10n.t("雨滴", "Cascade")
        case .hourglass: L10n.t("沙漏", "Hourglass")
        case .wreath: L10n.t("花环", "Wreath")
        }
    }
}

/// Pure 2D physics simulation for the Montessori Golden Bead Rainstick in normalized `[0, 1] × [0, 1]` board space.
struct RainstickPhysics: Sendable {
    struct Bead: Identifiable, Sendable {
        let id: Int
        var x: Double
        var y: Double
        var vx: Double
        var vy: Double
        let radius: Double
        let colorIndex: Int
        let isGold: Bool
        var trail: [(Double, Double)] = []
    }

    struct Peg: Sendable {
        let x: Double
        let y: Double
        let radius: Double
        var hitEnergy: Double = 0
    }

    var beads: [Bead]
    var pegs: [Peg]
    var layout: RainstickLayout = .cascade
    /// Normalized vertical position of the most recent wooden peg impact (used for Chime pitch mapping).
    var lastHitPegY: Double? = nil

    static func pegs(for layout: RainstickLayout) -> [Peg] {
        switch layout {
        case .cascade:
            return [
                // Row 1 (3 pegs)
                Peg(x: 0.24, y: 0.26, radius: 0.036),
                Peg(x: 0.50, y: 0.24, radius: 0.036),
                Peg(x: 0.76, y: 0.26, radius: 0.036),
                // Row 2 (4 staggered pegs)
                Peg(x: 0.16, y: 0.48, radius: 0.036),
                Peg(x: 0.39, y: 0.46, radius: 0.036),
                Peg(x: 0.61, y: 0.46, radius: 0.036),
                Peg(x: 0.84, y: 0.48, radius: 0.036),
                // Row 3 (4 staggered pegs)
                Peg(x: 0.24, y: 0.70, radius: 0.036),
                Peg(x: 0.48, y: 0.68, radius: 0.036),
                Peg(x: 0.72, y: 0.70, radius: 0.036),
                Peg(x: 0.50, y: 0.84, radius: 0.032),
            ]
        case .hourglass:
            return [
                // Top wide funnel (4 pegs)
                Peg(x: 0.18, y: 0.24, radius: 0.035),
                Peg(x: 0.36, y: 0.31, radius: 0.035),
                Peg(x: 0.64, y: 0.31, radius: 0.035),
                Peg(x: 0.82, y: 0.24, radius: 0.035),
                // Narrow golden waist (4 pegs guiding single-file stream through center)
                Peg(x: 0.31, y: 0.45, radius: 0.034),
                Peg(x: 0.69, y: 0.45, radius: 0.034),
                Peg(x: 0.42, y: 0.55, radius: 0.032),
                Peg(x: 0.58, y: 0.55, radius: 0.032),
                // Lower bell scatter (4 pegs)
                Peg(x: 0.22, y: 0.72, radius: 0.035),
                Peg(x: 0.50, y: 0.70, radius: 0.034),
                Peg(x: 0.78, y: 0.72, radius: 0.035),
                Peg(x: 0.50, y: 0.85, radius: 0.031),
            ]
        case .wreath:
            var out: [Peg] = []
            let count = 10
            for i in 0..<count {
                let a = (Double(i) / Double(count)) * 2.0 * .pi - (.pi / 2.0)
                out.append(Peg(
                    x: 0.50 + cos(a) * 0.28,
                    y: 0.50 + sin(a) * 0.28,
                    radius: 0.034
                ))
            }
            out.append(Peg(x: 0.50, y: 0.50, radius: 0.044))
            return out
        }
    }

    /// Creates a graceful starting arrangement of 26 golden & pastel wooden beads cascading across pegs.
    static func initial(layout: RainstickLayout = .cascade) -> RainstickPhysics {
        let pegs = pegs(for: layout)

        var beads: [Bead] = []
        let count = 26
        for i in 0..<count {
            let row = i / 6
            let col = i % 6
            let x = 0.14 + Double(col) * 0.14 + (row % 2 == 1 ? 0.045 : 0)
            let y = 0.10 + Double(row) * 0.14 + Double((i * 7) % 5) * 0.015
            let isGold = (i % 3 == 0)
            let r = isGold ? 0.033 : 0.029
            beads.append(Bead(
                id: i,
                x: min(0.88, max(0.12, x)),
                y: min(0.88, max(0.10, y)),
                vx: Double((i % 5) - 2) * 0.04,
                vy: 0.05,
                radius: r,
                colorIndex: (i - i / 3) % 6,
                isGold: isGold
            ))
        }
        return RainstickPhysics(beads: beads, pegs: pegs, layout: layout)
    }

    /// Switches peg baffle layout in place while giving settled beads a gentle puff to cascade through the new geometry.
    mutating func applyLayout(_ newLayout: RainstickLayout) {
        layout = newLayout
        pegs = Self.pegs(for: newLayout)
        lastHitPegY = nil
        for i in beads.indices {
            beads[i].vx += Double((i % 7) - 3) * 0.05
            beads[i].vy -= 0.14
        }
    }

    /// Advances bead positions by `dt` seconds under gravity `(gx, gy)` and an optional finger stir point.
    /// Returns the number of crisp wooden collisions (for micro-acoustics and subtle haptics).
    @discardableResult
    mutating func step(dt rawDt: Double, gx: Double, gy: Double, touch: CGPoint? = nil) -> Int {
        let dt = max(0.001, min(rawDt, 1.0 / 30.0))
        let gravityScale = 1.65
        let damping = 0.986
        let restitution = 0.56
        var impacts = 0
        lastHitPegY = nil

        // Gently decay glowing peg impact rings
        for p in pegs.indices where pegs[p].hitEnergy > 0 {
            pegs[p].hitEnergy = max(0, pegs[p].hitEnergy - dt * 2.6)
        }

        for i in beads.indices {
            beads[i].vx = (beads[i].vx + gx * gravityScale * dt) * damping
            beads[i].vy = (beads[i].vy + gy * gravityScale * dt) * damping

            // Gentle finger stir / ripple interaction
            if let touch {
                let dx = beads[i].x - Double(touch.x)
                let dy = beads[i].y - Double(touch.y)
                let distSq = dx * dx + dy * dy
                let reach = 0.18
                if distSq > 0.00001 && distSq < reach * reach {
                    let dist = sqrt(distSq)
                    let push = (1.0 - dist / reach) * 2.2 * dt
                    beads[i].vx += (dx / dist) * push
                    beads[i].vy += (dy / dist) * push
                }
            }

            // Cap maximum speed so beads always feel calm and wooden
            let speedSq = beads[i].vx * beads[i].vx + beads[i].vy * beads[i].vy
            if speedSq > 2.25 {
                let inv = 1.5 / sqrt(speedSq)
                beads[i].vx *= inv
                beads[i].vy *= inv
            }

            beads[i].x += beads[i].vx * dt
            beads[i].y += beads[i].vy * dt

            // Wall collisions (clamped cleanly inside wooden bezel)
            let r = beads[i].radius
            if beads[i].x < r {
                if abs(beads[i].vx) > 0.28 { impacts += 1 }
                beads[i].x = r
                beads[i].vx = abs(beads[i].vx) * restitution
            } else if beads[i].x > 1.0 - r {
                if abs(beads[i].vx) > 0.28 { impacts += 1 }
                beads[i].x = 1.0 - r
                beads[i].vx = -abs(beads[i].vx) * restitution
            }
            if beads[i].y < r {
                if abs(beads[i].vy) > 0.28 { impacts += 1 }
                beads[i].y = r
                beads[i].vy = abs(beads[i].vy) * restitution
            } else if beads[i].y > 1.0 - r {
                if abs(beads[i].vy) > 0.28 { impacts += 1 }
                beads[i].y = 1.0 - r
                beads[i].vy = -abs(beads[i].vy) * restitution
            }

            // Wooden peg collisions
            for p in pegs.indices {
                let peg = pegs[p]
                let dx = beads[i].x - peg.x
                let dy = beads[i].y - peg.y
                let minDist = r + peg.radius
                let d2 = dx * dx + dy * dy
                if d2 < minDist * minDist {
                    let dist = max(0.0001, sqrt(d2))
                    let nx = dx / dist
                    let ny = dy / dist
                    let overlap = minDist - dist
                    beads[i].x += nx * overlap
                    beads[i].y += ny * overlap
                    let vn = beads[i].vx * nx + beads[i].vy * ny
                    if vn < 0 {
                        if -vn > 0.20 {
                            impacts += 1
                            pegs[p].hitEnergy = min(1.0, max(pegs[p].hitEnergy, -vn * 1.4))
                            lastHitPegY = peg.y
                        }
                        beads[i].vx -= (1.0 + restitution) * vn * nx
                        beads[i].vy -= (1.0 + restitution) * vn * ny
                    }
                }
            }
        }

        // Bead-to-bead elastic collisions (N=26 -> 325 checks, < 0.03 ms)
        for i in 0..<beads.count {
            for j in (i + 1)..<beads.count {
                let dx = beads[j].x - beads[i].x
                let dy = beads[j].y - beads[i].y
                let minDist = beads[i].radius + beads[j].radius
                let d2 = dx * dx + dy * dy
                if d2 < minDist * minDist {
                    let dist = max(0.0001, sqrt(d2))
                    let nx = dx / dist
                    let ny = dy / dist
                    let overlap = (minDist - dist) * 0.5
                    beads[i].x -= nx * overlap
                    beads[i].y -= ny * overlap
                    beads[j].x += nx * overlap
                    beads[j].y += ny * overlap

                    let rvx = beads[j].vx - beads[i].vx
                    let rvy = beads[j].vy - beads[i].vy
                    let vn = rvx * nx + rvy * ny
                    if vn < 0 {
                        if -vn > 0.30 { impacts += 1 }
                        let imp = -(1.0 + 0.50) * vn * 0.5
                        beads[i].vx -= imp * nx
                        beads[i].vy -= imp * ny
                        beads[j].vx += imp * nx
                        beads[j].vy += imp * ny
                    }
                }
            }
        }

        // Final strict boundary clamp & silky motion trail update
        for i in beads.indices {
            let r = beads[i].radius
            beads[i].x = max(r, min(1.0 - r, beads[i].x))
            beads[i].y = max(r, min(1.0 - r, beads[i].y))

            let speedSq = beads[i].vx * beads[i].vx + beads[i].vy * beads[i].vy
            if speedSq > 0.015 {
                beads[i].trail.append((beads[i].x, beads[i].y))
                if beads[i].trail.count > 5 {
                    beads[i].trail.removeFirst(beads[i].trail.count - 5)
                }
            } else if !beads[i].trail.isEmpty {
                beads[i].trail.removeFirst()
            }
        }

        return impacts
    }
}

// MARK: - Firefly Lantern Jar Physics (Pure & Deterministic)

/// Gentle twilight constellations that the fireflies gather into when no finger touches the glass.
enum FireflyFormation: String, CaseIterable, Identifiable, Sendable {
    case drift, heart, crescent, spiral
    var id: String { rawValue }

    var title: String {
        switch self {
        case .drift: L10n.t("漫游", "Drift")
        case .heart: L10n.t("爱心", "Heart")
        case .crescent: L10n.t("弯月", "Moon")
        case .spiral: L10n.t("银河", "Spiral")
        }
    }

    var symbol: String {
        switch self {
        case .drift: "wind"
        case .heart: "heart.fill"
        case .crescent: "moon.stars.fill"
        case .spiral: "hurricane"
        }
    }
}

/// Pure 2D physics simulation for 18 softly glowing amber & mint fireflies drifting inside Otto's twilight jar.
struct FireflyPhysics: Sendable {
    struct Firefly: Identifiable, Sendable {
        let id: Int
        var x: Double
        var y: Double
        var vx: Double
        var vy: Double
        let phase: Double
        let size: Double
        let isMint: Bool
        var trail: [(Double, Double)] = []
        var glowBoost: Double = 0
    }

    struct Ripple: Identifiable, Sendable {
        let id: Int
        var x: Double
        var y: Double
        var age: Double
        let isGold: Bool
    }

    var flies: [Firefly]
    var time: Double = 0
    var formation: FireflyFormation = .drift
    var ripples: [Ripple] = []
    private var nextRippleID: Int = 0

    static func initial(formation: FireflyFormation = .drift) -> FireflyPhysics {
        var list: [Firefly] = []
        let count = 18
        for i in 0..<count {
            let preset = formationTarget(index: i, count: count, formation: formation, time: 0)
            let angle = Double(i) * 2.39996 // golden angle distribution inside glass jar
            let dist = 0.14 + 0.30 * sqrt(Double(i + 1) / Double(count))
            let x = preset?.0 ?? (0.5 + cos(angle) * dist)
            let y = preset?.1 ?? (0.5 + sin(angle) * dist)
            list.append(Firefly(
                id: i,
                x: max(0.12, min(0.88, x)),
                y: max(0.14, min(0.86, y)),
                vx: cos(angle + 1.5) * 0.06,
                vy: sin(angle + 1.5) * 0.06,
                phase: Double(i) * 0.72,
                size: 0.75 + Double(i % 4) * 0.22,
                isMint: (i % 4 == 0)
            ))
        }
        return FireflyPhysics(flies: list, time: 0, formation: formation)
    }

    /// Parametric twilight constellation coordinates strictly inside `[0.14...0.86]` for calm gather formations.
    static func formationTarget(index: Int, count: Int, formation: FireflyFormation, time: Double) -> (Double, Double)? {
        guard count > 0 else { return nil }
        let frac = Double(index) / Double(count)
        switch formation {
        case .drift:
            return nil
        case .heart:
            let theta = frac * 2.0 * .pi
            let breathe = 1.0 + 0.055 * sin(time * 1.4)
            let hx = 16.0 * pow(sin(theta), 3)
            let hy = -(13.0 * cos(theta) - 5.0 * cos(2.0 * theta) - 2.0 * cos(3.0 * theta) - cos(4.0 * theta))
            let x = max(0.14, min(0.86, 0.50 + hx * 0.0175 * breathe))
            let y = max(0.16, min(0.84, 0.48 + hy * 0.0175 * breathe))
            return (x, y)
        case .crescent:
            if index < 3 {
                // Three little companion stars near the moon's embrace
                let offsets: [(Double, Double)] = [(0.66, 0.33), (0.72, 0.52), (0.60, 0.68)]
                let p = offsets[index]
                let bob = sin(time * 1.6 + Double(index)) * 0.014
                return (max(0.14, min(0.86, p.0)), max(0.14, min(0.86, p.1 + bob)))
            }
            let arcCount = max(1, count - 3)
            let k = Double(index - 3) / Double(arcCount - 1)
            let angle = (.pi * 0.32) + k * (.pi * 1.36)
            let r = 0.27 + (index % 2 == 0 ? 0.02 : -0.02)
            let x = max(0.14, min(0.86, 0.50 + cos(angle) * r))
            let y = max(0.14, min(0.86, 0.50 + sin(angle) * r))
            return (x, y)
        case .spiral:
            let arm = index % 2
            let rank = Double(index / 2) / Double(max(1, (count + 1) / 2 - 1))
            let spin = time * 0.48
            let theta = spin + Double(arm) * .pi + rank * (2.6 * .pi)
            let r = 0.05 + rank * 0.29
            let x = max(0.14, min(0.86, 0.50 + cos(theta) * r))
            let y = max(0.14, min(0.86, 0.50 + sin(theta) * r))
            return (x, y)
        }
    }

    /// Spawns an expanding twilight glass ripple at `pt` (keeping up to 6 concurrent ripples).
    mutating func spawnRipple(at pt: CGPoint, gold: Bool = false) {
        nextRippleID &+= 1
        ripples.append(Ripple(
            id: nextRippleID,
            x: max(0.08, min(0.92, Double(pt.x))),
            y: max(0.10, min(0.90, Double(pt.y))),
            age: 0,
            isGold: gold
        ))
        if ripples.count > 6 {
            ripples.removeFirst(ripples.count - 6)
        }
    }

    /// Sends all fireflies into a tranquil golden spiral swirl inside the jar.
    mutating func swirl() {
        spawnRipple(at: CGPoint(x: 0.5, y: 0.5), gold: true)
        for i in flies.indices {
            let dx = flies[i].x - 0.5
            let dy = flies[i].y - 0.5
            let d = max(0.05, sqrt(dx * dx + dy * dy))
            // Tangential swirl impulse + gentle inward lift
            flies[i].vx += (-dy / d) * 0.36 - dx * 0.15
            flies[i].vy += (dx / d) * 0.36 - dy * 0.15
            flies[i].glowBoost = 1.0
        }
    }

    /// Advances all fireflies by `dt` seconds with harmonic wander, constellation gathering, trails, and ripples.
    mutating func step(dt rawDt: Double, target: CGPoint? = nil) {
        let dt = max(0.001, min(rawDt, 1.0 / 30.0))
        time += dt

        // Advance and prune expanding twilight ripples
        for r in ripples.indices {
            ripples[r].age += dt
        }
        ripples.removeAll { $0.age >= 1.15 }

        let total = flies.count
        for i in flies.indices {
            let p = flies[i].phase
            // Organic lazy twilight drift
            var ax = sin(time * 0.85 + p) * 0.14
            var ay = cos(time * 0.72 + p * 1.3) * 0.14

            flies[i].glowBoost = max(0, flies[i].glowBoost - dt * 1.4)

            if let target {
                let tx = Double(target.x)
                let ty = Double(target.y)
                let dx = tx - flies[i].x
                let dy = ty - flies[i].y
                let dist = max(0.04, sqrt(dx * dx + dy * dy))
                // Gentle orbital attraction around fingertip so they dance like a lantern halo
                let pull = min(0.95, 0.42 / dist)
                ax += (dx / dist) * pull + (-dy / dist) * 0.24
                ay += (dy / dist) * pull + (dx / dist) * 0.24
                if dist < 0.24 {
                    flies[i].glowBoost = min(1.0, max(flies[i].glowBoost, (0.24 - dist) / 0.16))
                }
            } else if let goal = Self.formationTarget(index: i, count: total, formation: formation, time: time) {
                ax = sin(time * 0.85 + p) * 0.045 + (goal.0 - flies[i].x) * 2.2
                ay = cos(time * 0.72 + p * 1.3) * 0.045 + (goal.1 - flies[i].y) * 2.2
            } else {
                // Soft recentering inside the jar's warm middle
                ax += (0.5 - flies[i].x) * 0.18
                ay += (0.5 - flies[i].y) * 0.18
            }

            let damping = (target == nil && formation != .drift) ? 0.91 : 0.965
            flies[i].vx = (flies[i].vx + ax * dt) * damping
            flies[i].vy = (flies[i].vy + ay * dt) * damping

            let speedSq = flies[i].vx * flies[i].vx + flies[i].vy * flies[i].vy
            if speedSq > 0.36 {
                let inv = 0.60 / sqrt(speedSq)
                flies[i].vx *= inv
                flies[i].vy *= inv
            }

            flies[i].x += flies[i].vx * dt
            flies[i].y += flies[i].vy * dt

            // Soft glass wall margins
            if flies[i].x < 0.09 { flies[i].x = 0.09; flies[i].vx = abs(flies[i].vx) * 0.6 }
            if flies[i].x > 0.91 { flies[i].x = 0.91; flies[i].vx = -abs(flies[i].vx) * 0.6 }
            if flies[i].y < 0.11 { flies[i].y = 0.11; flies[i].vy = abs(flies[i].vy) * 0.6 }
            if flies[i].y > 0.89 { flies[i].y = 0.89; flies[i].vy = -abs(flies[i].vy) * 0.6 }

            flies[i].trail.append((flies[i].x, flies[i].y))
            if flies[i].trail.count > 6 {
                flies[i].trail.removeFirst(flies[i].trail.count - 6)
            }
        }
    }
}
