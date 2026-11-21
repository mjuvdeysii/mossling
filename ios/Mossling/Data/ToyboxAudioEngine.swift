import Foundation
import SwiftUI
import AVFoundation

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
    static let lullabyPhrase: [(Int, Double)] = [
        (0, 0.42), (0, 0.42), (4, 0.42), (4, 0.42), (5, 0.42), (5, 0.42), (4, 0.82),
        (3, 0.42), (3, 0.42), (2, 0.42), (2, 0.42), (1, 0.42), (1, 0.42), (0, 0.85),
    ]
}

/// Zero-asset polyphonic wooden marimba & rainstick bead click synthesizer for the Sensory Toybox.
/// Synthesizes warm rosewood marimba bars and soft beechwood bead clicks in real time via `AVAudioEngine`.
@MainActor
final class ToyboxAudioEngine {
    static let shared = ToyboxAudioEngine()

    private let sampleRate: Double = 44_100
    private var engine: AVAudioEngine?
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayerIndex = 0
    private var noteBuffers: [Int: AVAudioPCMBuffer] = [:]
    private var beadBuffers: [AVAudioPCMBuffer] = []
    private var lastBeadSoundAt: TimeInterval = 0

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

    /// Plays one wooden xylophone bar with polyphonic overlap (up to 6 simultaneous voices).
    func playNote(_ note: ToyboxNote) {
        guard !isTestHost else { return }
        guard let player = nextPlayer(), let buf = buffer(for: note) else { return }
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

    /// Stops and releases the toybox audio engine when leaving the studio.
    func stop() {
        for p in players { p.stop() }
        engine?.stop()
        engine = nil
        players = []
    }

    // MARK: - Audio Engine Pool

    private func ensureEngine() -> Bool {
        if let e = engine {
            if !e.isRunning { try? e.start() }
            return e.isRunning
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
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

    private func nextPlayer() -> AVAudioPlayerNode? {
        guard ensureEngine(), !players.isEmpty else { return nil }
        let node = players[nextPlayerIndex % players.count]
        nextPlayerIndex = (nextPlayerIndex + 1) % players.count
        node.volume = 1.0
        return node
    }

    private func buffer(for note: ToyboxNote) -> AVAudioPCMBuffer? {
        if let cached = noteBuffers[note.index] { return cached }
        let samples = Self.synthesizeMarimbaSamples(frequency: note.frequency, sampleRate: sampleRate)
        guard let buf = makeBuffer(from: samples) else { return nil }
        noteBuffers[note.index] = buf
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
    }

    struct Peg: Sendable {
        let x: Double
        let y: Double
        let radius: Double
    }

    var beads: [Bead]
    let pegs: [Peg]

    /// Creates a graceful starting arrangement of 26 golden & pastel wooden beads cascading across 11 staggered pegs.
    static func initial() -> RainstickPhysics {
        let pegs: [Peg] = [
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
        return RainstickPhysics(beads: beads, pegs: pegs)
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
            for peg in pegs {
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
                        if -vn > 0.22 { impacts += 1 }
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

        // Final strict boundary clamp after pair resolution
        for i in beads.indices {
            let r = beads[i].radius
            beads[i].x = max(r, min(1.0 - r, beads[i].x))
            beads[i].y = max(r, min(1.0 - r, beads[i].y))
        }

        return impacts
    }
}
