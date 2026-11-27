import SwiftUI
import CoreMotion

/// The five tactile Montessori co-play studios inside 「感官玩具盒 / Sensory Toybox」.
enum ToyboxMode: String, CaseIterable, Identifiable {
    case xylophone, shadows, rainstick, fireflies, contrast
    var id: String { rawValue }

    var title: String {
        switch self {
        case .xylophone: L10n.t("木琴", "Keys")
        case .shadows: L10n.t("手影", "Shadow")
        case .rainstick: L10n.t("金珠", "Beads")
        case .fireflies: L10n.t("萤火", "Glow")
        case .contrast: L10n.t("视卡", "Cards")
        }
    }

    var symbol: String {
        switch self {
        case .xylophone: "music.note"
        case .shadows: "rays"
        case .rainstick: "circle.grid.3x3.fill"
        case .fireflies: "sparkles"
        case .contrast: "circle.lefthalf.filled"
        }
    }

    var hasSound: Bool { self != .contrast }

    var tone: Color {
        switch self {
        case .xylophone: Crayon.teal
        case .shadows: Palette.amber
        case .rainstick: Crayon.sunflower
        case .fireflies: Crayon.lilac
        case .contrast: Crayon.caramel
        }
    }
}

/// Lightweight daily co-play counter for Sensory Toybox so the Home dock reflects shared studio moments.
@MainActor
enum ToyboxUsage {
    private static let key = "mossling.toybox.daily"
    private static var isTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static func recordInteraction(on day: Day = .today, defaults: UserDefaults = .standard) {
        if defaults === UserDefaults.standard, isTestHost { return }
        let next = todayCount(on: day, defaults: defaults) + 1
        defaults.set("\(day.epochDay)|\(next)", forKey: key)
    }

    static func todayCount(on day: Day = .today, defaults: UserDefaults = .standard) -> Int {
        guard let raw = defaults.string(forKey: key) else { return 0 }
        let parts = raw.split(separator: "|", maxSplits: 1)
        guard parts.count == 2,
              let savedDay = Int(parts[0]), savedDay == day.epochDay,
              let count = Int(parts[1]) else {
            return 0
        }
        return max(0, count)
    }
}

/// 「感官玩具盒 / Sensory Toybox」 — An offline, tactile Montessori studio designed for parent-child co-play:
/// 1) 8-bar graduated xylophone with 3 acoustic DSP timbres, 6 melodies, ripple particles & Follow-the-Glow mode,
/// 2) 26-bead Montessori rainstick with 3 baffle layouts, wood/chime modes, peg impact glow & bead trails,
/// 3) 18-firefly twilight lantern jar with 4 constellation formations, comet trails & touch ripples,
/// 4) 12 newborn (0–4 mo) high-contrast visual cards with slow-motion, monochrome invert & fullscreen focus mode.
struct ToyboxView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.dynamicTypeSize) private var type
    @State private var mode: ToyboxMode
    @State private var recordedSession = false
    @State private var volumeMonitor: EarSafeVolumeMonitor
    @State private var manualShowVolumeCard = false

    private let previewPlayAlong: Bool
    private let initialShadowPuppet: ShadowPuppetKind
    private let initialFormation: FireflyFormation
    private let initialRainstickLayout: RainstickLayout
    private let initialContrastIndex: Int

    init(
        initialMode: ToyboxMode = .xylophone,
        previewPlayAlong: Bool = false,
        initialShadowPuppet: ShadowPuppetKind = .rabbit,
        initialFormation: FireflyFormation = .drift,
        initialRainstickLayout: RainstickLayout = .cascade,
        initialContrastIndex: Int = 0,
        previewVolume: Float? = nil,
        previewShowVolumeGuard: Bool = false
    ) {
        _mode = State(initialValue: initialMode)
        _volumeMonitor = State(initialValue: EarSafeVolumeMonitor(previewVolume: previewVolume, previewForceShow: previewShowVolumeGuard))
        self.previewPlayAlong = previewPlayAlong
        self.initialShadowPuppet = initialShadowPuppet
        self.initialFormation = initialFormation
        self.initialRainstickLayout = initialRainstickLayout
        self.initialContrastIndex = initialContrastIndex
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        VStack(spacing: 10) {
            modePicker(dark: dark)

            if mode.hasSound && (manualShowVolumeCard || volumeMonitor.shouldShow(for: .toybox)) {
                EarSafeVolumeCard(monitor: volumeMonitor, dark: dark) {
                    withAnimation(reduce ? nil : .spring(response: 0.34, dampingFraction: 0.84)) {
                        manualShowVolumeCard = false
                        volumeMonitor.acknowledge(context: .toybox)
                    }
                }
                .transition(reduce ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }

            Group {
                switch mode {
                case .xylophone:
                    XylophoneStudio(
                        dark: dark,
                        initialPlayAlong: previewPlayAlong,
                        onInteract: markCoPlay
                    )
                case .shadows:
                    ShadowWallStudio(
                        dark: dark,
                        initialPuppet: initialShadowPuppet,
                        onInteract: markCoPlay
                    )
                case .rainstick:
                    RainstickStudio(
                        dark: dark,
                        initialLayout: initialRainstickLayout,
                        onInteract: markCoPlay
                    )
                case .fireflies:
                    FireflyJarStudio(
                        initialFormation: initialFormation,
                        onInteract: markCoPlay
                    )
                case .contrast:
                    ContrastCardStudio(
                        dark: dark,
                        initialIndex: initialContrastIndex,
                        onInteract: markCoPlay
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, LayoutSpec.pageH)
        .padding(.top, 8)
        .padding(.bottom, 14)
        .pageBackground(tone: mode.tone)
        .navigationTitle(L10n.t("感官玩具盒", "Sensory Toybox"))
        .navigationSubtitle(L10n.t("亲子轻点共玩 · 不单独看屏", "Co-play together · No solo screen"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if mode.hasSound {
                ToolbarItem(placement: .topBarTrailing) {
                    let levelColor: Color = volumeMonitor.level == .loud ? Crayon.tangerine : (volumeMonitor.level == .muted ? Crayon.sky : Crayon.leaf)
                    let sym = volumeMonitor.level == .muted ? "speaker.slash.fill" : (volumeMonitor.level == .loud ? "ear.trianglebadge.exclamationmark" : "ear.and.waveform")
                    Button {
                        TactileEngine.shared.beadClick()
                        withAnimation(reduce ? nil : .spring(response: 0.34, dampingFraction: 0.84)) {
                            manualShowVolumeCard.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(levelColor)
                                .frame(width: 6, height: 6)
                            Image(systemName: sym)
                                .font(.caption.weight(.bold))
                            Text("\(volumeMonitor.volumePercent)%")
                                .font(Typeface.numerals(11, relativeTo: .caption2, weight: .bold))
                        }
                        .foregroundStyle(Crayon.ink(levelColor))
                    }
                    .accessibilityLabel(L10n.t("音量护耳监测：\(volumeMonitor.volumePercent)%", "Ear-safe volume monitor: \(volumeMonitor.volumePercent)%"))
                }
            }
        }
        .onAppear {
            volumeMonitor.start()
        }
        .onDisappear {
            ToyboxAudioEngine.shared.stop()
            volumeMonitor.stop()
        }
    }

    private func markCoPlay() {
        guard !recordedSession else { return }
        recordedSession = true
        ToyboxUsage.recordInteraction()
    }

    private func modePicker(dark: Bool) -> some View {
        DSSegmentedControl(
            items: ToyboxMode.allCases,
            selection: $mode,
            dark: dark,
            compact: false,
            title: { $0.title },
            symbol: { $0.symbol }
        )
    }
}

// MARK: - Studio 1: Wooden Montessori Xylophone

@MainActor
private final class XylophoneFX {
    struct WaveRing {
        let id = UUID()
        let nx: Double
        let ny: Double
        let color: Color
        let born: TimeInterval
        let maxRadius: Double
    }

    struct FloatNote {
        enum ParticleShape { case eighthNote, star }
        let id = UUID()
        let x: Double
        let y: Double
        let vx: Double
        let vy: Double
        let shape: ParticleShape
        let color: Color
        let born: TimeInterval
    }

    var rings: [WaveRing] = []
    var particles: [FloatNote] = []

    func spawnStrike(nx: Double, ny: Double, color: Color, goldCelebration: Bool = false) {
        let now = Date().timeIntervalSinceReferenceDate
        rings.removeAll { now - $0.born > 0.75 }
        particles.removeAll { now - $0.born > 0.95 }
        rings.append(WaveRing(nx: nx, ny: ny, color: color, born: now, maxRadius: goldCelebration ? 0.42 : 0.28))

        let shapes: [FloatNote.ParticleShape] = [.eighthNote, .eighthNote, .star]
        let count = goldCelebration ? 8 : 3
        for i in 0..<count {
            let spread = Double(i - count / 2)
            let pColor = goldCelebration ? Palette.bead : (i == 2 ? Palette.bead : color)
            let pShape = goldCelebration ? (i % 2 == 0 ? FloatNote.ParticleShape.star : .eighthNote) : shapes[i % shapes.count]
            particles.append(FloatNote(
                x: nx + spread * 0.035,
                y: ny,
                vx: spread * (goldCelebration ? 0.14 : 0.06),
                vy: -(0.16 + Double(i % 3) * 0.05),
                shape: pShape,
                color: pColor,
                born: now
            ))
        }
        if rings.count > 12 { rings.removeFirst(rings.count - 12) }
        if particles.count > 28 { particles.removeFirst(particles.count - 28) }
    }
}

private struct XylophoneStudio: View {
    let dark: Bool
    let onInteract: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var activeBar: Int? = nil
    @State private var lastNote: ToyboxNote? = nil
    @State private var mossLook: CGPoint = CGPoint(x: 0, y: 0.45)
    @State private var mossMood: Mood = .open
    @State private var noteNotice: Int = 0
    @State private var isPlayingLullaby = false
    @State private var lullabyTask: Task<Void, Never>? = nil
    @State private var sparkleIndex: Int? = nil
    @State private var timbre: ToyboxTimbre = .marimba
    @State private var melody: ToyboxMelody = .twinkle
    @State private var playAlong: Bool
    @State private var playAlongStep: Int = 0
    @State private var completedCount: Int = 0
    @State private var fx = XylophoneFX()
    @State private var fxActive = false
    @State private var fxIdleTask: Task<Void, Never>? = nil

    init(dark: Bool, initialPlayAlong: Bool = false, onInteract: @escaping () -> Void) {
        self.dark = dark
        self.onInteract = onInteract
        _playAlong = State(initialValue: initialPlayAlong)
    }

    /// Displayed top-to-bottom from treble C6 down to bass C5 like a Montessori staircase.
    private var orderedNotes: [ToyboxNote] { Array(ToyboxNote.scale.reversed()) }

    private var targetNoteIndex: Int? {
        guard playAlong, !melody.notes.isEmpty else { return nil }
        return melody.notes[playAlongStep % melody.notes.count].0
    }

    private var mossTargetLook: CGPoint {
        if let idx = targetNoteIndex {
            let nx = (Double(idx) / 7.0) * 1.4 - 0.7
            return CGPoint(x: nx, y: 0.65)
        }
        return mossLook
    }

    var body: some View {
        let stepCount = max(1, melody.notes.count)
        let targetNote = targetNoteIndex.flatMap { idx in ToyboxNote.scale.first { $0.index == idx } }

        VStack(spacing: 10) {
            // Top Companion Card + 6-Melody Menu + 3-Timbre Switcher
            VStack(spacing: 7) {
                HStack(spacing: 10) {
                    Creature(kind: .moss, mood: mossMood, look: mossTargetLook, alive: true, poke: true, notice: noteNotice)
                        .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 2) {
                        if playAlong, let targetNote {
                            HStack(spacing: 5) {
                                Text("\(melody.title) · \(playAlongStep + 1)/\(stepCount)")
                                if completedCount > 0 {
                                    HStack(spacing: 2) {
                                        Text("· \(completedCount)")
                                        Image(systemName: "star.fill").font(.caption2)
                                    }
                                    .foregroundStyle(Palette.bead)
                                }
                            }
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            Text(L10n.t("轻点发光的「\(targetNote.numberLabel) \(targetNote.solfege)」", "Tap glowing \(targetNote.numberLabel) · \(targetNote.solfege)"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        } else {
                            Text(lastNote.map { "\($0.numberLabel) · \($0.solfege) (\($0.pitchName))" } ?? L10n.t("轻敲或上下滑过木条", "Tap or glide bars"))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.76)
                            Text(L10n.t("\(timbre.title)离线合成 · \(melody.title)", "\(timbre.title) · \(melody.title)"))
                                .font(.caption)
                                .foregroundStyle(Palette.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    Spacer(minLength: 4)

                    Menu {
                        ForEach(ToyboxMelody.allCases) { song in
                            Button {
                                TactileEngine.shared.beadClick()
                                stopLullaby()
                                melody = song
                                playAlongStep = 0
                            } label: {
                                HStack {
                                    Text("\(song.title)（\(song.subtitle)）")
                                    if melody == song {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "music.note.list")
                                .font(.caption2.weight(.bold))
                            Text(melody.title)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Palette.accent.opacity(dark ? 0.22 : 0.12)))
                        .fixedSize(horizontal: true, vertical: false)
                        .pillHitTarget()
                    }
                    .accessibilityLabel(L10n.t("选择童谣曲目", "Choose melody"))
                }

                // Compact 3-Timbre Segmented Switcher
                DSSegmentedControl(
                    items: ToyboxTimbre.allCases,
                    selection: $timbre,
                    dark: dark,
                    compact: true,
                    title: { $0.title },
                    symbol: { $0.symbol }
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .printCard(radius: Radius.card)

            // Rosewood resonator marimba with satin beveled tone bars, brushed brass studs & ripple acoustics
            GeometryReader { geo in
                let bars = orderedNotes
                let verticalInset: CGFloat = 12
                let spacing: CGFloat = 8
                let usableH = max(160, geo.size.height - verticalInset * 2)
                let barH = max(28, (usableH - spacing * CGFloat(bars.count - 1)) / CGFloat(bars.count))

                ZStack {
                    // Subtle warm horizontal beechwood grain across acoustic soundboard
                    VStack(spacing: geo.size.height / 9) {
                        ForEach(0..<8, id: \.self) { idx in
                            Rectangle()
                                .fill((dark ? Color.white : Color(hex: 0x8F6B3E)).opacity(idx.isMultiple(of: 2) ? 0.045 : 0.02))
                                .frame(height: 1)
                        }
                    }
                    .padding(.horizontal, 14)

                    // Twin sculpted walnut/beechwood resonator rails behind the rainbow tone bars
                    HStack(spacing: geo.size.width * 0.24) {
                        woodRail(dark: dark)
                        woodRail(dark: dark)
                    }
                    .padding(.vertical, 10)

                    VStack(spacing: spacing) {
                        ForEach(Array(bars.enumerated()), id: \.element.id) { row, note in
                            let centerY = Double(verticalInset + CGFloat(row) * (barH + spacing) + barH * 0.5) / Double(max(1, geo.size.height))
                            xylophoneBar(
                                note: note,
                                maxWidth: geo.size.width - 28,
                                height: barH,
                                normalizedY: centerY,
                                isTarget: targetNoteIndex == note.index
                            )
                        }
                    }
                    .padding(.vertical, verticalInset)

                    // Acoustic wave rings & drifting note particles (strictly read-only inside Canvas draw)
                    if !reduce && !Perf.still {
                        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !fxActive)) { tl in
                            Canvas { ctx, size in
                                let now = tl.date.timeIntervalSinceReferenceDate
                                for ring in fx.rings {
                                    let age = now - ring.born
                                    guard age >= 0, age <= 0.72 else { continue }
                                    let prog = min(1.0, max(0.0, age / 0.72))
                                    let r = CGFloat(prog * ring.maxRadius) * min(size.width, size.height)
                                    let cx = CGFloat(ring.nx) * size.width
                                    let cy = CGFloat(ring.ny) * size.height
                                    let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                                    ctx.stroke(
                                        Path(ellipseIn: rect),
                                        with: .color(ring.color.opacity((1.0 - prog) * 0.65)),
                                        lineWidth: CGFloat(2.4 * (1.0 - prog * 0.6))
                                    )
                                }
                                for p in fx.particles {
                                    let age = now - p.born
                                    guard age >= 0, age <= 0.92 else { continue }
                                    let prog = min(1.0, max(0.0, age / 0.92))
                                    let px = (p.x + p.vx * age) * Double(size.width)
                                    let py = (p.y + p.vy * age) * Double(size.height)
                                    let alpha = (1.0 - prog) * (prog < 0.15 ? prog / 0.15 : 1.0)
                                    let tint = p.color.opacity(alpha)
                                    switch p.shape {
                                    case .eighthNote:
                                        ctx.fill(Path(ellipseIn: CGRect(x: px - 4.5, y: py + 1.5, width: 7.5, height: 5.5)), with: .color(tint))
                                        var stem = Path()
                                        stem.move(to: CGPoint(x: px + 2, y: py + 4))
                                        stem.addLine(to: CGPoint(x: px + 2, y: py - 8))
                                        stem.addQuadCurve(to: CGPoint(x: px + 7.5, y: py - 3.5), control: CGPoint(x: px + 6.5, y: py - 7))
                                        ctx.stroke(stem, with: .color(tint), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                                    case .star:
                                        var star = Path()
                                        let r: Double = 6.5
                                        star.move(to: CGPoint(x: px, y: py - r))
                                        star.addQuadCurve(to: CGPoint(x: px + r, y: py), control: CGPoint(x: px + 1.5, y: py - 1.5))
                                        star.addQuadCurve(to: CGPoint(x: px, y: py + r), control: CGPoint(x: px + 1.5, y: py + 1.5))
                                        star.addQuadCurve(to: CGPoint(x: px - r, y: py), control: CGPoint(x: px - 1.5, y: py + 1.5))
                                        star.addQuadCurve(to: CGPoint(x: px, y: py - r), control: CGPoint(x: px - 1.5, y: py - 1.5))
                                        star.closeSubpath()
                                        ctx.fill(star, with: .color(tint))
                                    }
                                }
                            }
                        }
                        .allowsHitTesting(false)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: dark
                                    ? [Color(hex: 0x19203A), Color(hex: 0x11172D)]
                                    : [Color(hex: 0xF5ECDC), Color(hex: 0xEAD9BE)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(dark ? 0.30 : 0.10), radius: 8, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(dark ? Palette.amber.opacity(0.22) : Color(hex: 0xB89060).opacity(0.45), lineWidth: 1.5)
                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let y = value.location.y - verticalInset
                            let stride = barH + spacing
                            let row = Int(floor(y / stride))
                            guard row >= 0, row < bars.count else { return }
                            let hit = bars[row]
                            if activeBar != hit.index {
                                stopLullaby()
                                let nx = max(0.15, min(0.85, Double(value.location.x / max(1, geo.size.width))))
                                let ny = Double(verticalInset + CGFloat(row) * stride + barH * 0.5) / Double(max(1, geo.size.height))
                                strike(hit, normalizedX: nx, normalizedY: ny)
                            }
                        }
                        .onEnded { _ in
                            withAnimation(reduce ? nil : .spring(response: 0.26, dampingFraction: 0.72)) {
                                activeBar = nil
                            }
                        }
                )
            }
            .frame(minHeight: 290)

            // Footer Dual Controls: Secondary Listen + Primary Follow-the-Glow Play Along
            HStack(spacing: 10) {
                Button {
                    if isPlayingLullaby {
                        stopLullaby()
                    } else {
                        playLullaby()
                    }
                } label: {
                    Label(
                        isPlayingLullaby ? L10n.t("停下来", "Stop") : L10n.t("试听旋律", "Listen"),
                        systemImage: isPlayingLullaby ? "stop.fill" : "play.fill"
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                }
                .buttonStyle(.ds(isPlayingLullaby ? .tinted(Crayon.pink) : .secondary, fullWidth: true, height: 50))

                Button {
                    TactileEngine.shared.beadClick()
                    stopLullaby()
                    withAnimation(reduce ? nil : .spring(response: 0.32, dampingFraction: 0.8)) {
                        playAlong.toggle()
                        playAlongStep = 0
                    }
                } label: {
                    Label(
                        playAlong ? L10n.t("退出跟弹", "Exit Guide") : L10n.t("跟光弹", "Play Along"),
                        systemImage: playAlong ? "xmark.circle.fill" : "sparkles"
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                }
                .buttonStyle(.ds(.primary, fullWidth: true, height: 50))
            }
        }
        .onDisappear {
            fxIdleTask?.cancel()
            fxIdleTask = nil
            fxActive = false
            stopLullaby()
        }
    }

    private func woodRail(dark: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: dark
                            ? [Color(hex: 0x4A3A2E), Color(hex: 0x2B211B)]
                            : [Color(hex: 0xE1BE92), Color(hex: 0xBC8F5E)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(dark ? 0.14 : 0.45), lineWidth: 0.75)
        }
        .frame(width: 16)
        .shadow(color: .black.opacity(dark ? 0.38 : 0.16), radius: 3, y: 2)
    }

    private func xylophoneBar(note: ToyboxNote, maxWidth: CGFloat, height: CGFloat, normalizedY: Double, isTarget: Bool) -> some View {
        let pressed = activeBar == note.index
        let glowing = sparkleIndex == note.index
        let barW = max(140, maxWidth * note.widthRatio)
        let shape = RoundedRectangle(cornerRadius: min(14, height * 0.36), style: .continuous)

        return ZStack {
            if isTarget {
                shape
                    .strokeBorder(Palette.beadLight.opacity(0.95), lineWidth: 3)
                    .shadow(color: Palette.amber.opacity(0.75), radius: 8)
                    .frame(width: barW + 6, height: height + 6)
            }

            shape
                .fill(
                    LinearGradient(
                        colors: [
                            note.color.mix(with: .white, by: pressed ? 0.32 : (isTarget ? 0.28 : (dark ? 0.08 : 0.20))),
                            note.color.mix(with: .black, by: dark ? 0.18 : 0.02),
                            note.color.mix(with: .black, by: dark ? 0.32 : 0.14)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(pressed || isTarget ? 0.88 : (dark ? 0.25 : 0.65)), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: pressed || isTarget ? 2 : 1
                    )
                )
                .shadow(color: note.color.opacity(pressed || isTarget ? 0.45 : (dark ? 0.22 : 0.26)), radius: pressed || isTarget ? 10 : 4, y: pressed ? 1 : 3)
                .frame(width: barW, height: height)

            HStack {
                brassRivet
                Spacer()
                HStack(spacing: 6) {
                    Text(note.numberLabel)
                        .font(Typeface.numerals(15, relativeTo: .headline, weight: .bold))
                    Text(note.solfege)
                        .font(.footnote.weight(.bold))
                    if isTarget {
                        Image(systemName: "sparkle")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color(hex: 0xFFF7D6))
                    }
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.24), radius: 1, y: 1)
                Spacer()
                brassRivet
            }
            .padding(.horizontal, 16)
            .frame(width: barW, height: height)

            if glowing && !reduce {
                Circle()
                    .fill(.white.opacity(0.45))
                    .frame(width: height * 0.85, height: height * 0.85)
                    .blur(radius: 6)
                    .allowsHitTesting(false)
            }
        }
        .scaleEffect(pressed ? 0.96 : (isTarget ? 1.025 : 1.0))
        .animation(reduce ? nil : .spring(response: 0.22, dampingFraction: 0.65), value: pressed)
        .animation(reduce ? nil : .spring(response: 0.26, dampingFraction: 0.7), value: isTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(note.solfege), \(note.pitchName)" + (isTarget ? L10n.t("，下一个音", ", next note") : ""))
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            stopLullaby()
            strike(note, normalizedX: 0.5, normalizedY: normalizedY)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(160))
                if activeBar == note.index {
                    withAnimation(reduce ? nil : .spring(response: 0.26, dampingFraction: 0.72)) {
                        activeBar = nil
                    }
                }
            }
        }
    }

    private var brassRivet: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Palette.beadLight, Palette.bead, Color(hex: 0x7A570C)],
                    center: UnitPoint(x: 0.35, y: 0.3),
                    startRadius: 0,
                    endRadius: 5
                )
            )
            .frame(width: 8, height: 8)
            .overlay(Circle().strokeBorder(.black.opacity(0.18), lineWidth: 0.5))
    }

    private func strike(_ note: ToyboxNote, normalizedX: Double, normalizedY: Double, countForGuide: Bool = true) {
        onInteract()
        ToyboxAudioEngine.shared.playNote(note, timbre: timbre)
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred(intensity: 0.55 + Double(note.index) * 0.04)
        }

        var finishedSong = false
        if countForGuide, playAlong, !melody.notes.isEmpty {
            let cur = playAlongStep % melody.notes.count
            if note.index == melody.notes[cur].0 {
                if cur + 1 >= melody.notes.count {
                    finishedSong = true
                    completedCount &+= 1
                    playAlongStep = 0
                    TactileEngine.shared.goldChime()
                } else {
                    playAlongStep = cur + 1
                }
            }
        }

        fx.spawnStrike(nx: normalizedX, ny: normalizedY, color: note.color, goldCelebration: finishedSong)
        fxActive = true
        fxIdleTask?.cancel()
        fxIdleTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1050))
            if !Task.isCancelled {
                fxActive = false
            }
        }

        withAnimation(reduce ? nil : .spring(response: 0.18, dampingFraction: 0.65)) {
            activeBar = note.index
            lastNote = note
            sparkleIndex = note.index
        }
        // Moss glances smoothly along the scale and cheers on C5/C6 or song completion
        let lookX = (Double(note.index) / 7.0) * 1.4 - 0.7
        mossLook = CGPoint(x: lookX, y: 0.65)
        mossMood = (finishedSong || note.index == 0 || note.index == 7) ? .happy : .open
        noteNotice &+= 1
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            if sparkleIndex == note.index {
                withAnimation(reduce ? nil : .easeOut(duration: 0.22)) {
                    sparkleIndex = nil
                }
            }
        }
    }

    private func playLullaby() {
        stopLullaby()
        isPlayingLullaby = true
        let phrase = melody.notes
        let count = max(1, orderedNotes.count)
        lullabyTask = Task { @MainActor in
            for (noteIdx, pause) in phrase {
                guard !Task.isCancelled else { break }
                if noteIdx >= 0 && noteIdx < ToyboxNote.scale.count {
                    let row = (ToyboxNote.scale.count - 1) - noteIdx
                    let ny = (Double(row) + 0.5) / Double(count)
                    strike(ToyboxNote.scale[noteIdx], normalizedX: 0.5, normalizedY: ny, countForGuide: false)
                }
                try? await Task.sleep(for: .milliseconds(Int(pause * 1000)))
            }
            activeBar = nil
            isPlayingLullaby = false
            lullabyTask = nil
        }
    }

    private func stopLullaby() {
        lullabyTask?.cancel()
        lullabyTask = nil
        isPlayingLullaby = false
        activeBar = nil
    }
}

// MARK: - Studio 2: Montessori Golden Bead Rainstick

@MainActor
private final class RainstickSimulation {
    var physics: RainstickPhysics
    var lastFrameDate: Date? = nil
    var touchPoint: CGPoint? = nil
    var flipped = false
    var motionGX: Double = 0
    var motionGY: Double = 1.0
    var chimeMode: Bool = false
    private var motionManager: CMMotionManager?
    private let haptic = UIImpactFeedbackGenerator(style: .soft)

    init(layout: RainstickLayout = .cascade) {
        self.physics = RainstickPhysics.initial(layout: layout)
    }

    private var isTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func setLayout(_ layout: RainstickLayout) {
        physics.applyLayout(layout)
    }

    func startMotion() {
        guard !isTestHost, motionManager == nil else { return }
        let mgr = CMMotionManager()
        guard mgr.isDeviceMotionAvailable else { return }
        mgr.deviceMotionUpdateInterval = 1.0 / 45.0
        mgr.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let g = data?.gravity else { return }
            let gx = max(-1.2, min(1.2, g.x * 1.45))
            let gy = max(-1.2, min(1.2, -g.y * 1.45))
            // Keep gentle fallback gravity if phone is lying completely flat on a table
            if abs(gx) < 0.12 && abs(gy) < 0.12 {
                self.motionGX = 0
                self.motionGY = self.flipped ? -0.95 : 0.95
            } else {
                self.motionGX = self.flipped ? -gx : gx
                self.motionGY = self.flipped ? -gy : gy
            }
        }
        motionManager = mgr
    }

    func stopMotion() {
        motionManager?.stopDeviceMotionUpdates()
        motionManager = nil
    }

    func flip() {
        flipped.toggle()
        motionGY = flipped ? -1.05 : 1.05
        // Give beads a tiny upward shimmer so they unstick gracefully
        for i in physics.beads.indices {
            physics.beads[i].vx += Double((i % 5) - 2) * 0.08
            physics.beads[i].vy += flipped ? -0.25 : 0.25
        }
    }

    var ottoLook: CGPoint {
        let fx: Double
        let fy: Double
        if let t = touchPoint {
            fx = Double(t.x)
            fy = Double(t.y)
        } else if !physics.beads.isEmpty {
            let sumX = physics.beads.reduce(0.0) { $0 + $1.x }
            let sumY = physics.beads.reduce(0.0) { $0 + $1.y }
            fx = sumX / Double(physics.beads.count)
            fy = sumY / Double(physics.beads.count)
        } else {
            return CGPoint(x: -0.45, y: -0.45)
        }
        return CGPoint(
            x: max(-0.85, min(0.85, (fx - 0.85) * 1.4)),
            y: max(-0.85, min(0.85, (fy - 0.85) * 1.4))
        )
    }

    func advance(to now: Date) {
        let dt: Double
        if let prev = lastFrameDate {
            dt = min(1.0 / 30.0, max(0.004, now.timeIntervalSince(prev)))
        } else {
            dt = 1.0 / 60.0
        }
        lastFrameDate = now

        let impacts = physics.step(dt: dt, gx: motionGX, gy: motionGY, touch: touchPoint)
        if impacts > 0 && !isTestHost {
            let intensity = min(0.85, 0.35 + Double(impacts) * 0.12)
            if chimeMode {
                ToyboxAudioEngine.shared.playRainstickChime(normalizedY: physics.lastHitPegY ?? 0.5, intensity: intensity)
            } else {
                ToyboxAudioEngine.shared.playBeadClick(intensity: intensity)
            }
            if impacts >= 2 {
                haptic.impactOccurred(intensity: min(0.6, 0.25 + Double(impacts) * 0.08))
            }
        }
    }
}

private struct RainstickStudio: View {
    let dark: Bool
    let onInteract: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.scenePhase) private var scenePhase
    @State private var sim: RainstickSimulation
    @State private var layout: RainstickLayout
    @State private var chimeMode = false
    @State private var flipCount = 0

    init(dark: Bool, initialLayout: RainstickLayout = .cascade, onInteract: @escaping () -> Void) {
        self.dark = dark
        self.onInteract = onInteract
        _layout = State(initialValue: initialLayout)
        _sim = State(initialValue: RainstickSimulation(layout: initialLayout))
    }

    private static let pastelBeads: [Color] = [
        Crayon.teal, Crayon.pink, Crayon.sky, Crayon.leaf, Crayon.lilac, Crayon.tangerine
    ]

    var body: some View {
        VStack(spacing: 10) {
            // Compact Baffle Layout & Acoustic Voice Bar (Cascade/Hourglass/Wreath + Wood/Chime)
            HStack(spacing: 6) {
                ForEach(RainstickLayout.allCases) { item in
                    let on = layout == item
                    Button {
                        guard layout != item else { return }
                        onInteract()
                        TactileEngine.shared.beadClick()
                        layout = item
                        sim.setLayout(item)
                    } label: {
                        Text(item.title)
                            .font(.caption.weight(on ? .bold : .semibold))
                            .foregroundStyle(on ? .white : Palette.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(on ? AnyShapeStyle(Palette.accentFill) : AnyShapeStyle(dark ? Palette.lampCard : Palette.card)))
                            .overlay(Capsule().strokeBorder(Palette.outline.opacity(on ? 0 : 0.26), lineWidth: 0.75))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }

                Button {
                    onInteract()
                    TactileEngine.shared.beadClick()
                    chimeMode.toggle()
                    sim.chimeMode = chimeMode
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: chimeMode ? "sparkles" : "circle.grid.2x2.fill")
                            .font(.caption2.weight(.bold))
                        Text(chimeMode ? L10n.t("风铃", "Chime") : L10n.t("木珠", "Wood"))
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(chimeMode ? Color(hex: 0x3A2700) : Palette.accent)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(chimeMode ? Palette.beadLight : Palette.accent.opacity(dark ? 0.22 : 0.12)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(chimeMode ? L10n.t("音色：风铃，点击切换木珠", "Sound: Chime, tap for Wood") : L10n.t("音色：木珠，点击切换风铃", "Sound: Wood, tap for Chime"))
            }

            GeometryReader { geo in
                let boardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)
                let innerShape = RoundedRectangle(cornerRadius: 20, style: .continuous)
                ZStack {
                    // Turned & chamfered beechwood Montessori box outer frame
                    boardShape
                        .fill(
                            LinearGradient(
                                colors: dark
                                    ? [Color(hex: 0x2E263D), Color(hex: 0x191D33)]
                                    : [Color(hex: 0xEAD7B7), Color(hex: 0xCBAE81)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            boardShape
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(dark ? 0.18 : 0.55), .black.opacity(0.16)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: .black.opacity(dark ? 0.40 : 0.16), radius: 12, y: 6)

                    // Inner felt & satin-wood shaker well with recessed bevel shadow
                    innerShape
                        .fill(
                            LinearGradient(
                                colors: dark
                                    ? [Color(hex: 0x0E142B), Color(hex: 0x151E3C)]
                                    : [Color(hex: 0xFAF4E8), Color(hex: 0xEFE4D0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(11)
                        .overlay(
                            innerShape
                                .strokeBorder(dark ? Palette.amber.opacity(0.24) : Color(hex: 0xA88250).opacity(0.55), lineWidth: 1.5)
                                .padding(11)
                        )

                    TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduce || Perf.still || scenePhase != .active)) { tl in
                        Canvas(rendersAsynchronously: false) { ctx, size in
                            if !reduce && !Perf.still && scenePhase == .active {
                                sim.advance(to: tl.date)
                            }
                            drawBoard(ctx: &ctx, size: size)
                        }
                    }
                    .padding(15)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                onInteract()
                                let w = max(1, geo.size.width - 30)
                                let h = max(1, geo.size.height - 30)
                                sim.touchPoint = CGPoint(
                                    x: max(0, min(1, value.location.x / w)),
                                    y: max(0, min(1, value.location.y / h))
                                )
                            }
                            .onEnded { _ in
                                sim.touchPoint = nil
                            }
                    )

                    // Tempered acrylic cover sheen across shaker window
                    innerShape
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(dark ? 0.08 : 0.24), .clear, .white.opacity(dark ? 0.03 : 0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(11)
                        .allowsHitTesting(false)

                    // Four tiny brass cabinet corner dowels anchoring the glass top
                    VStack {
                        HStack { brassCornerStud; Spacer(); brassCornerStud }
                        Spacer()
                        HStack { brassCornerStud; Spacer(); brassCornerStud }
                    }
                    .padding(17)
                    .allowsHitTesting(false)

                    // Subtle Otto tracking beads calmly from the bottom-right rim
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Creature(kind: .otto, mood: .open, look: sim.ottoLook, alive: false, glow: dark)
                                .frame(width: 44, height: 44)
                                .padding(18)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
            .frame(minHeight: 330)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("轻倾手机，或手指拨动金珠", "Tilt gently or stir the beads"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(chimeMode
                        ? L10n.t("26 颗彩珠 · 撞柱五声音阶风铃", "26 beads · pentatonic peg chimes")
                        : L10n.t("26 颗蒙氏金珠与彩木珠 · 轻响雨声", "26 golden & pastel wooden beads · soft rain clicks"))
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                Spacer(minLength: 8)
                Button {
                    onInteract()
                    TactileEngine.shared.beadClick()
                    sim.flip()
                    flipCount &+= 1
                } label: {
                    Label(L10n.t("翻转", "Flip"), systemImage: "arrow.up.arrow.down")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.vinyl(Palette.accentFill, prominent: true))
            }
            .padding(12)
            .printCard(radius: Radius.card)
        }
        .onAppear {
            if !reduce && scenePhase == .active { sim.startMotion() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !reduce {
                sim.startMotion()
            } else {
                sim.stopMotion()
            }
        }
        .onDisappear {
            sim.stopMotion()
        }
    }

    private var brassCornerStud: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Palette.beadLight, Palette.bead, Color(hex: 0x7A570C)],
                    center: UnitPoint(x: 0.35, y: 0.3),
                    startRadius: 0,
                    endRadius: 4
                )
            )
            .frame(width: 7, height: 7)
            .overlay(Circle().strokeBorder(.black.opacity(0.22), lineWidth: 0.5))
    }

    private func drawBoard(ctx: inout GraphicsContext, size: CGSize) {
        let minSide = min(size.width, size.height)

        // Subtle wooden rainstick grain lines
        let lineColor = dark ? Color.white.opacity(0.03) : Color(hex: 0x8F6B3E).opacity(0.06)
        for i in 1..<8 {
            let y = size.height * CGFloat(i) / 8.0
            var path = Path()
            path.move(to: CGPoint(x: 8, y: y))
            path.addLine(to: CGPoint(x: size.width - 8, y: y))
            ctx.stroke(path, with: .color(lineColor), lineWidth: 1)
        }

        // Turned oak wooden baffle pegs + warm collision glow rings
        for peg in sim.physics.pegs {
            let cx = CGFloat(peg.x) * size.width
            let cy = CGFloat(peg.y) * size.height
            let r = CGFloat(peg.radius) * minSide

            if peg.hitEnergy > 0.02 {
                let glowR = r * (1.5 + CGFloat(peg.hitEnergy) * 0.9)
                let glowColor = chimeMode ? Crayon.teal : Palette.amber
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - glowR, y: cy - glowR, width: glowR * 2, height: glowR * 2)),
                    with: .radialGradient(
                        Gradient(colors: [glowColor.opacity(0.42 * peg.hitEnergy), .clear]),
                        center: CGPoint(x: cx, y: cy),
                        startRadius: r * 0.5,
                        endRadius: glowR
                    )
                )
            }

            let shadowRect = CGRect(x: cx - r, y: cy - r + 2.5, width: r * 2, height: r * 2)
            ctx.fill(Path(ellipseIn: shadowRect), with: .color(.black.opacity(dark ? 0.35 : 0.14)))

            let pegRect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
            let grad = Gradient(colors: dark
                ? [Color(hex: 0x6F5741), Color(hex: 0x453528)]
                : [Color(hex: 0xDEC097), Color(hex: 0xAE8353)])
            ctx.fill(
                Path(ellipseIn: pegRect),
                with: .radialGradient(grad, center: CGPoint(x: cx - r * 0.28, y: cy - r * 0.28), startRadius: 1, endRadius: r * 1.4)
            )
            // Center wood dowel grain ring
            let inner = CGRect(x: cx - r * 0.45, y: cy - r * 0.45, width: r * 0.9, height: r * 0.9)
            ctx.stroke(Path(ellipseIn: inner), with: .color(.white.opacity(dark ? 0.12 : 0.35)), lineWidth: 1)
        }

        // Soft finger stir wave halo when parent/baby stirs the tray
        if let pt = sim.touchPoint {
            let tx = pt.x * size.width
            let ty = pt.y * size.height
            let haloR: CGFloat = 34
            ctx.stroke(
                Path(ellipseIn: CGRect(x: tx - haloR, y: ty - haloR, width: haloR * 2, height: haloR * 2)),
                with: .color(Palette.accent.opacity(0.32)),
                lineWidth: 2
            )
        }

        // Silky tapering motion trails + 26 luminous golden & pastel wooden beads
        for bead in sim.physics.beads {
            let cx = CGFloat(bead.x) * size.width
            let cy = CGFloat(bead.y) * size.height
            let r = CGFloat(bead.radius) * minSide
            let base = bead.isGold ? Palette.bead : Self.pastelBeads[bead.colorIndex % Self.pastelBeads.count]

            if bead.trail.count > 1 {
                let tc = bead.trail.count
                for idx in 0..<(tc - 1) {
                    let frac = Double(idx + 1) / Double(tc)
                    let px = CGFloat(bead.trail[idx].0) * size.width
                    let py = CGFloat(bead.trail[idx].1) * size.height
                    let tr = r * CGFloat(0.28 + 0.44 * frac)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - tr, y: py - tr, width: tr * 2, height: tr * 2)),
                        with: .color(base.opacity(0.18 * frac))
                    )
                }
            }

            let shadow = CGRect(x: cx - r * 0.92, y: cy - r * 0.8 + 2.2, width: r * 1.84, height: r * 1.84)
            ctx.fill(Path(ellipseIn: shadow), with: .color(.black.opacity(dark ? 0.40 : 0.16)))

            let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
            let hi = bead.isGold ? Color(hex: 0xFFF2BC) : base.mix(with: .white, by: 0.48)
            let lo = bead.isGold ? Color(hex: 0x9C6E0B) : base.mix(with: .black, by: 0.24)
            ctx.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [hi, base, lo]),
                    center: CGPoint(x: cx - r * 0.30, y: cy - r * 0.32),
                    startRadius: 0.5,
                    endRadius: r * 1.35
                )
            )
        }
    }
}

// MARK: - Studio 3: Firefly Lantern Jar

@MainActor
private final class FireflySimulation {
    var physics: FireflyPhysics
    var lastFrameDate: Date? = nil
    var touchPoint: CGPoint? = nil
    private var lastRippleAt: TimeInterval = 0

    init(formation: FireflyFormation = .drift) {
        self.physics = FireflyPhysics.initial(formation: formation)
    }

    func setFormation(_ formation: FireflyFormation) {
        physics.formation = formation
        physics.spawnRipple(at: CGPoint(x: 0.5, y: 0.5), gold: true)
    }

    func spawnTouchRipple(at pt: CGPoint) {
        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastRippleAt >= 0.18 else { return }
        lastRippleAt = now
        physics.spawnRipple(at: pt, gold: false)
    }

    var ottoLook: CGPoint {
        let fx: Double
        let fy: Double
        if let t = touchPoint {
            fx = Double(t.x)
            fy = Double(t.y)
        } else if !physics.flies.isEmpty {
            let sumX = physics.flies.reduce(0.0) { $0 + $1.x }
            let sumY = physics.flies.reduce(0.0) { $0 + $1.y }
            fx = sumX / Double(physics.flies.count)
            fy = sumY / Double(physics.flies.count)
        } else {
            return CGPoint(x: -0.45, y: -0.45)
        }
        return CGPoint(
            x: max(-0.85, min(0.85, (fx - 0.85) * 1.4)),
            y: max(-0.85, min(0.85, (fy - 0.85) * 1.4))
        )
    }

    func advance(to now: Date) {
        let dt: Double
        if let prev = lastFrameDate {
            dt = min(1.0 / 30.0, max(0.004, now.timeIntervalSince(prev)))
        } else {
            dt = 1.0 / 60.0
        }
        lastFrameDate = now
        physics.step(dt: dt, target: touchPoint)
    }

    func swirl() {
        physics.swirl()
    }
}

private struct FireflyJarStudio: View {
    let onInteract: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.scenePhase) private var scenePhase
    @State private var sim: FireflySimulation
    @State private var formation: FireflyFormation
    @State private var swirlCount = 0

    init(initialFormation: FireflyFormation = .drift, onInteract: @escaping () -> Void) {
        self.onInteract = onInteract
        _formation = State(initialValue: initialFormation)
        _sim = State(initialValue: FireflySimulation(formation: initialFormation))
    }

    var body: some View {
        VStack(spacing: 10) {
            // Compact 4-Formation Pill Switcher (Drift / Heart / Moon / Spiral)
            HStack(spacing: 6) {
                ForEach(FireflyFormation.allCases) { f in
                    let on = formation == f
                    Button {
                        guard formation != f else { return }
                        onInteract()
                        TactileEngine.shared.beadClick()
                        formation = f
                        sim.setFormation(f)
                        ToyboxAudioEngine.shared.playFireflyArpeggio(ascending: true)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: f.symbol)
                                .font(.caption2.weight(.bold))
                            Text(f.title)
                                .font(.caption.weight(on ? .bold : .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .foregroundStyle(on ? Color(hex: 0x241500) : Palette.lampInk.opacity(0.84))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(on ? Palette.amber : Color(hex: 0x162040)))
                        .overlay(Capsule().strokeBorder(Palette.amber.opacity(on ? 0.9 : 0.22), lineWidth: 0.75))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }

            GeometryReader { geo in
                let jarShape = RoundedRectangle(cornerRadius: 40, style: .continuous)
                let neckW = min(192, geo.size.width * 0.54)
                let capW = min(168, geo.size.width * 0.46)
                VStack(spacing: 0) {
                    // Integrated apothecary lantern collar + brushed brass lid seated cleanly onto the glass shoulder
                    VStack(spacing: -2) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: 0xE9CA88), Color(hex: 0xBC8C3F), Color(hex: 0x875D20)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: capW, height: 15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(.white.opacity(0.38), lineWidth: 0.75)
                                )
                            Capsule()
                                .fill(.white.opacity(0.32))
                                .frame(width: capW * 0.76, height: 2)
                                .offset(y: -3)
                        }
                        .zIndex(2)

                        // Threaded brass & smoky-glass lantern neck uniting cap to jar body with zero gap
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0x9C702F), Color(hex: 0x26355F)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: neckW, height: 11)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(.white.opacity(0.24), lineWidth: 1)
                            )
                            .zIndex(1)
                    }
                    .shadow(color: .black.opacity(0.32), radius: 5, y: 2)
                    .padding(.bottom, -5)

                    // Twilight curved blown-glass lantern jar
                    ZStack {
                        jarShape
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: 0x0A1228),
                                        Color(hex: 0x152246),
                                        Color(hex: 0x0F1934)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color(hex: 0x0A1024).opacity(0.45), radius: 14, y: 6)

                        // Warm twilight horizon bloom along the jar glass base
                        jarShape
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Palette.amber.opacity(0.24),
                                        Color(hex: 0x4ECBA2).opacity(0.10),
                                        .clear
                                    ],
                                    center: UnitPoint(x: 0.5, y: 0.88),
                                    startRadius: 12,
                                    endRadius: max(180, geo.size.width * 0.65)
                                )
                            )

                        // 60fps glowing fireflies, comet trails & fingertip lantern ripples
                        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduce || Perf.still || scenePhase != .active)) { tl in
                            Canvas(rendersAsynchronously: false) { ctx, size in
                                if !reduce && !Perf.still && scenePhase == .active {
                                    sim.advance(to: tl.date)
                                }
                                drawFireflies(ctx: &ctx, size: size)
                            }
                        }
                        .clipShape(jarShape)
                        .contentShape(jarShape)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    onInteract()
                                    let w = max(1, geo.size.width)
                                    let h = max(1, geo.size.height - 18)
                                    let nx = max(0.08, min(0.92, value.location.x / w))
                                    let ny = max(0.10, min(0.90, value.location.y / h))
                                    let pt = CGPoint(x: nx, y: ny)
                                    sim.touchPoint = pt
                                    sim.spawnTouchRipple(at: pt)
                                    ToyboxAudioEngine.shared.playFireflyChime(normalizedY: ny)
                                }
                                .onEnded { _ in
                                    sim.touchPoint = nil
                                }
                        )

                        // Curved blown-glass reflections on left, top shoulder & right rims
                        HStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.28), .white.opacity(0.03)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 5)
                                .padding(.vertical, 30)
                                .padding(.leading, 14)
                            Spacer()
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.14), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 3)
                                .padding(.vertical, 48)
                                .padding(.trailing, 14)
                        }
                        .allowsHitTesting(false)

                        // Double glass-wall refraction bevel
                        jarShape
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.36), Palette.amber.opacity(0.24), .white.opacity(0.16)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.75
                            )
                            .allowsHitTesting(false)

                        // Otto watching gently from the twilight meadow sill
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Creature(kind: .otto, mood: .open, look: sim.ottoLook, alive: false, glow: true)
                                    .frame(width: 48, height: 48)
                                    .padding(16)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
            }
            .frame(minHeight: 326)

            // Tactile studio footer card
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("轻触牵引萤火，或切换星光阵型", "Touch to beckon or pick a glow shape"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(L10n.t("18 只流光萤火 · 五声音阶琶音", "18 fireflies · pentatonic arpeggios"))
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                Spacer(minLength: 4)
                Button {
                    onInteract()
                    TactileEngine.shared.beadClick()
                    sim.swirl()
                    swirlCount &+= 1
                    ToyboxAudioEngine.shared.playFireflyArpeggio(ascending: true)
                } label: {
                    Label(L10n.t("轻摇", "Swirl"), systemImage: "sparkles")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.vinyl(Palette.accentFill, prominent: true))
            }
            .padding(12)
            .printCard(radius: Radius.card)
        }
    }

    private func drawFireflies(ctx: inout GraphicsContext, size: CGSize) {
        let time = sim.physics.time
        // Faint twilight meadow grass silhouettes along the jar floor
        var floor = Path()
        floor.move(to: CGPoint(x: 0, y: size.height))
        floor.addLine(to: CGPoint(x: 0, y: size.height * 0.89))
        floor.addQuadCurve(
            to: CGPoint(x: size.width, y: size.height * 0.90),
            control: CGPoint(x: size.width * 0.48, y: size.height * 0.83)
        )
        floor.addLine(to: CGPoint(x: size.width, y: size.height))
        floor.closeSubpath()
        ctx.fill(floor, with: .color(Color(hex: 0x091124).opacity(0.75)))

        // Tiny steady twilight starlight dust in upper glass
        for i in 0..<14 {
            let sx = size.width * CGFloat(((i * 37 + 13) % 88) + 6) / 100.0
            let sy = size.height * CGFloat(((i * 23 + 9) % 52) + 8) / 100.0
            let starR: CGFloat = i % 3 == 0 ? 1.5 : 1.0
            let twinkle = 0.20 + 0.20 * sin(time * 1.4 + Double(i))
            ctx.fill(
                Path(ellipseIn: CGRect(x: sx - starR, y: sy - starR, width: starR * 2, height: starR * 2)),
                with: .color(Color(hex: 0xFFF3D4).opacity(twinkle))
            )
        }

        // Expanding twilight ripples from touches, swirls, and formation switches
        for ripple in sim.physics.ripples {
            let prog = min(1.0, max(0.0, ripple.age / 1.15))
            let rx = ripple.x * Double(size.width)
            let ry = ripple.y * Double(size.height)
            let rad = CGFloat(12.0 + prog * 58.0)
            let ringColor = ripple.isGold ? Palette.amber : Color(hex: 0x8CEBC5)
            ctx.stroke(
                Path(ellipseIn: CGRect(x: CGFloat(rx) - rad, y: CGFloat(ry) - rad, width: rad * 2, height: rad * 2)),
                with: .color(ringColor.opacity((1.0 - prog) * 0.55)),
                lineWidth: CGFloat(2.0 * (1.0 - prog * 0.6))
            )
        }

        // Soft beckoning lantern ring while parent or baby's finger touches the glass
        if let pt = sim.touchPoint {
            let tx = pt.x * size.width
            let ty = pt.y * size.height
            let haloR: CGFloat = 46
            let ringRect = CGRect(x: tx - haloR, y: ty - haloR, width: haloR * 2, height: haloR * 2)
            ctx.fill(
                Path(ellipseIn: ringRect),
                with: .radialGradient(
                    Gradient(colors: [Palette.amber.opacity(0.28), Palette.amber.opacity(0.06), .clear]),
                    center: CGPoint(x: tx, y: ty),
                    startRadius: 2,
                    endRadius: haloR
                )
            )
        }

        // 18 glowing fireflies with tapering comet trails + triple-layer radial aura + ivory pearl core
        for fly in sim.physics.flies {
            let cx = CGFloat(fly.x) * size.width
            let cy = CGFloat(fly.y) * size.height
            let pulse = 0.62 + 0.38 * sin(time * 2.2 + fly.phase)
            let boost = 1.0 + CGFloat(fly.glowBoost) * 0.45
            let baseR = CGFloat(fly.size) * 4.8 * CGFloat(0.88 + 0.22 * pulse) * boost

            let glowColor = fly.isMint ? Color(hex: 0x8CEBC5) : Color(hex: 0xFFD46B)
            let midColor = fly.isMint ? Color(hex: 0xCFFCE7) : Color(hex: 0xFFEAA6)

            if fly.trail.count > 1 {
                let tc = fly.trail.count
                for idx in 0..<(tc - 1) {
                    let frac = Double(idx + 1) / Double(tc)
                    let px = CGFloat(fly.trail[idx].0) * size.width
                    let py = CGFloat(fly.trail[idx].1) * size.height
                    let tr = max(1.0, baseR * CGFloat(0.18 + 0.32 * frac))
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - tr, y: py - tr, width: tr * 2, height: tr * 2)),
                        with: .color(glowColor.opacity(0.26 * frac * pulse))
                    )
                }
            }

            // Outer soft lantern aura
            let outerR = baseR * 4.2
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2)),
                with: .radialGradient(
                    Gradient(colors: [glowColor.opacity(min(0.75, 0.46 * pulse * Double(boost))), glowColor.opacity(0.10 * pulse), .clear]),
                    center: CGPoint(x: cx, y: cy),
                    startRadius: 1,
                    endRadius: outerR
                )
            )

            // Middle warm corona
            let midR = baseR * 1.75
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - midR, y: cy - midR, width: midR * 2, height: midR * 2)),
                with: .radialGradient(
                    Gradient(colors: [midColor.opacity(0.85 * pulse), glowColor.opacity(0.25 * pulse), .clear]),
                    center: CGPoint(x: cx, y: cy),
                    startRadius: 0.5,
                    endRadius: midR
                )
            )

            // Luminous pearl core
            let coreR = max(2.2, baseR * 0.65)
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - coreR, y: cy - coreR, width: coreR * 2, height: coreR * 2)),
                with: .color(Color(hex: 0xFFFDF5).opacity(min(1.0, 0.85 + 0.15 * pulse)))
            )
        }
    }
}

// MARK: - Studio 4: Newborn High-Contrast Visual Cards (0–4 mo)

enum ContrastCardKind: Int, CaseIterable, Identifiable {
    case rings, checkerboard, spiral, mossSilhouette, sun, crescent, waves, dots, ottoLantern, butterfly, nestedSquares, botanicalLeaf
    var id: Int { rawValue }

    var title: String {
        switch self {
        case .rings: L10n.t("同心圆", "Concentric Rings")
        case .checkerboard: L10n.t("棋盘格", "Bold Checkerboard")
        case .spiral: L10n.t("蜗牛螺旋", "Gentle Spiral")
        case .mossSilhouette: L10n.t("Moss 剪影", "Moss Silhouette")
        case .sun: L10n.t("暖红太阳", "Radiating Sun")
        case .crescent: L10n.t("弯月星光", "Crescent & Stars")
        case .waves: L10n.t("波浪条纹", "Rolling Waves")
        case .dots: L10n.t("圆点韵律", "Montessori Dots")
        case .ottoLantern: L10n.t("Otto 小夜灯", "Otto's Lantern")
        case .butterfly: L10n.t("对称蝴蝶", "Bold Butterfly")
        case .nestedSquares: L10n.t("嵌套方框", "Nested Squares")
        case .botanicalLeaf: L10n.t("双叶嫩芽", "Twin Sprout")
        }
    }

    var ageHint: String {
        switch self {
        case .rings, .checkerboard, .spiral, .nestedSquares:
            L10n.t("0–2 个月 · 纯黑白强对比", "0–2 mo · Pure black & ivory")
        case .mossSilhouette, .ottoLantern:
            L10n.t("0–3 个月 · 脸部轮廓与一点暖红", "0–3 mo · Silhouette & warm focal")
        case .sun, .crescent, .waves, .butterfly:
            L10n.t("1–4 个月 · 黑白配一抹暖红", "1–4 mo · Monochrome + vermilion")
        case .dots, .botanicalLeaf:
            L10n.t("2–4 个月 · 追视细节节奏", "2–4 mo · Visual tracking detail")
        }
    }
}

private struct ContrastCardStudio: View {
    let dark: Bool
    let onInteract: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var index: Int
    @State private var inverted = false
    @State private var motionMode = true
    @State private var showingFocus = false

    init(dark: Bool, initialIndex: Int = 0, onInteract: @escaping () -> Void) {
        self.dark = dark
        self.onInteract = onInteract
        _index = State(initialValue: max(0, min(ContrastCardKind.allCases.count - 1, initialIndex)))
    }

    private let cards = ContrastCardKind.allCases

    var body: some View {
        let current = cards[max(0, min(index, cards.count - 1))]
        VStack(spacing: 10) {
            TabView(selection: $index) {
                ForEach(cards) { card in
                    ContrastCardArtwork(
                        kind: card,
                        inverted: inverted,
                        motionMode: motionMode && !reduce
                    )
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .tag(card.rawValue)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: index) { oldVal, newVal in
                guard oldVal != newVal else { return }
                onInteract()
                TactileEngine.shared.pageTurn()
            }

            // Montessori bead pagination, controls (Motion / Invert / Focus) & newborn viewing guide
            VStack(spacing: 9) {
                HStack(spacing: 5.5) {
                    ForEach(cards) { c in
                        let active = c.rawValue == index
                        Circle()
                            .fill(active ? Palette.bead : Palette.secondaryText.opacity(0.28))
                            .frame(width: active ? 8.5 : 5.5, height: active ? 8.5 : 5.5)
                            .animation(reduce ? nil : .spring(response: 0.28, dampingFraction: 0.78), value: index)
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(current.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(current.ageHint)
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryText)
                    }
                    Spacer()
                    Text("\(index + 1) / \(cards.count)")
                        .font(Typeface.numerals(13, relativeTo: .footnote, weight: .bold))
                        .foregroundStyle(Palette.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(dark ? Color.white.opacity(0.10) : Palette.fill))
                }

                // 3 compact studio controls
                HStack(spacing: 6) {
                    Button {
                        onInteract()
                        TactileEngine.shared.beadClick()
                        motionMode.toggle()
                    } label: {
                        Label(
                            motionMode ? L10n.t("轻柔律动", "Motion") : L10n.t("静止卡", "Still"),
                            systemImage: motionMode ? "play.circle.fill" : "pause.circle"
                        )
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                    }
                    .foregroundStyle(motionMode ? .white : Palette.secondaryText)
                    .background(Capsule().fill(motionMode ? AnyShapeStyle(Palette.accentFill) : AnyShapeStyle(dark ? Color.white.opacity(0.08) : Palette.fill)))
                    .buttonStyle(.plain)

                    Button {
                        onInteract()
                        TactileEngine.shared.beadClick()
                        withAnimation(reduce ? nil : .easeInOut(duration: 0.22)) {
                            inverted.toggle()
                        }
                    } label: {
                        Label(L10n.t("黑白反色", "Invert"), systemImage: "circle.lefthalf.filled")
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                    }
                    .foregroundStyle(inverted ? Color(hex: 0x3A2700) : Palette.secondaryText)
                    .background(Capsule().fill(inverted ? Palette.beadLight : (dark ? Color.white.opacity(0.08) : Palette.fill)))
                    .buttonStyle(.plain)

                    Button {
                        onInteract()
                        TactileEngine.shared.beadClick()
                        showingFocus = true
                    } label: {
                        Label(L10n.t("全屏展示", "Focus"), systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                    }
                    .foregroundStyle(Palette.accent)
                    .background(Capsule().fill(Palette.accent.opacity(dark ? 0.22 : 0.12)))
                    .buttonStyle(.plain)
                }

                Text(L10n.t("距宝宝眼前约 20–30 cm 稳稳拿着，左右轻缓移动，看宝宝眼神追随。", "Hold 8–12 in from baby's eyes and glide slowly side to side as their gaze follows."))
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .printCard(radius: Radius.card)
        }
        .fullScreenCover(isPresented: $showingFocus) {
            ContrastFocusCover(
                cards: cards,
                index: $index,
                inverted: $inverted,
                motionMode: motionMode && !reduce
            )
        }
    }
}

private struct ContrastFocusCover: View {
    let cards: [ContrastCardKind]
    @Binding var index: Int
    @Binding var inverted: Bool
    let motionMode: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let bg = inverted ? Color(hex: 0x191A17) : Color(hex: 0xFBF7F0)
        let fg = inverted ? Color(hex: 0xFBF7F0) : Color(hex: 0x191A17)
        ZStack {
            bg.ignoresSafeArea()
            TabView(selection: $index) {
                ForEach(cards) { card in
                    ContrastCardArtwork(
                        kind: card,
                        inverted: inverted,
                        motionMode: motionMode,
                        frameless: true
                    )
                    .padding(16)
                    .tag(card.rawValue)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack {
                HStack {
                    Button {
                        TactileEngine.shared.beadClick()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(bg)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(fg.opacity(0.75)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.toy)
                    .accessibilityLabel(L10n.t("退出全屏", "Exit fullscreen"))

                    Spacer()

                    Button {
                        TactileEngine.shared.beadClick()
                        inverted.toggle()
                    } label: {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(bg)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(fg.opacity(0.75)))
                            .contentShape(Circle())
                    }
                    .buttonStyle(.toy)
                    .accessibilityLabel(L10n.t("黑白反色", "Invert card polarity"))
                }
                .padding(.horizontal, LayoutSpec.pageH)
                .padding(.top, 12)
                Spacer()
                Text("\(cards[max(0, min(index, cards.count - 1))].title) · \(index + 1)/\(cards.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(fg.opacity(0.55))
                    .padding(.bottom, 16)
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}

/// Crisp vector museum board card drawn in warm ivory (#FBF7F0), deep charcoal (#191A17), and subtle vermilion (#D64234).
private struct ContrastCardArtwork: View {
    let kind: ContrastCardKind
    var inverted: Bool = false
    var motionMode: Bool = false
    var frameless: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduce

    private let ivory = Color(hex: 0xFBF7F0)
    private let charcoal = Color(hex: 0x191A17)
    private let vermilion = Color(hex: 0xD64234)

    var body: some View {
        let bg = inverted ? charcoal : ivory
        let fg = inverted ? ivory : charcoal
        let activeMotion = motionMode && !reduce && !Perf.still

        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                if !frameless {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(bg)
                        .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
                }

                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !activeMotion)) { tl in
                    let phase = activeMotion ? tl.date.timeIntervalSinceReferenceDate : 0
                    let breathe = activeMotion && kind != .spiral && kind != .sun && kind != .waves
                        ? CGFloat(1.0 + 0.024 * (0.5 + 0.5 * sin(phase * 1.8)))
                        : 1.0
                    Canvas { ctx, size in
                        draw(kind: kind, ctx: &ctx, size: size, bg: bg, fg: fg, phase: phase)
                    }
                    .scaleEffect(breathe)
                }
                .clipShape(RoundedRectangle(cornerRadius: frameless ? 28 : 22, style: .continuous))
                .padding(frameless ? 0 : 10)

                if !frameless {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(fg.opacity(0.16), lineWidth: 1.5)
                }
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.title)
    }

    private func draw(kind: ContrastCardKind, ctx: inout GraphicsContext, size: CGSize, bg: Color, fg: Color, phase: Double) {
        let w = size.width
        let h = size.height
        let cx = w / 2
        let cy = h / 2
        let maxR = min(w, h) * 0.45

        switch kind {
        case .rings:
            for step in stride(from: 6, through: 1, by: -1) {
                let r = maxR * CGFloat(step) / 6.0
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(step % 2 == 0 ? fg : bg))
            }

        case .checkerboard:
            let n = 4
            let cellW = w / CGFloat(n)
            let cellH = h / CGFloat(n)
            for r in 0..<n {
                for c in 0..<n where (r + c) % 2 == 0 {
                    ctx.fill(Path(CGRect(x: CGFloat(c) * cellW, y: CGFloat(r) * cellH, width: cellW, height: cellH)), with: .color(fg))
                }
            }

        case .spiral:
            var path = Path()
            let turns = 3.5
            let steps = 260
            let spin = phase * 0.28
            for i in 0...steps {
                let frac = Double(i) / Double(steps)
                let angle = frac * turns * 2.0 * .pi + spin
                let r = Double(maxR) * frac
                let pt = CGPoint(x: cx + CGFloat(cos(angle) * r), y: cy + CGFloat(sin(angle) * r))
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            ctx.stroke(path, with: .color(fg), style: StrokeStyle(lineWidth: maxR * 0.14, lineCap: .round))

        case .mossSilhouette:
            let bodyR = maxR * 0.78
            let bodyRect = CGRect(x: cx - bodyR, y: cy - bodyR * 0.72, width: bodyR * 2, height: bodyR * 1.72)
            ctx.fill(Path(ellipseIn: bodyRect), with: .color(fg))
            for dir in [-1.0, 1.0] {
                var leaf = Path()
                let base = CGPoint(x: cx + CGFloat(dir) * bodyR * 0.14, y: cy - bodyR * 0.68)
                let tip = CGPoint(x: cx + CGFloat(dir) * bodyR * 0.68, y: cy - bodyR * 1.24)
                let c1 = CGPoint(x: cx + CGFloat(dir) * bodyR * 0.05, y: cy - bodyR * 1.22)
                let c2 = CGPoint(x: cx + CGFloat(dir) * bodyR * 0.72, y: cy - bodyR * 0.78)
                leaf.move(to: base)
                leaf.addQuadCurve(to: tip, control: c1)
                leaf.addQuadCurve(to: base, control: c2)
                ctx.fill(leaf, with: .color(fg))
            }
            let eyeR = bodyR * 0.24
            let eyeY = cy - bodyR * 0.06
            for dir in [-1.0, 1.0] {
                let ex = cx + CGFloat(dir) * bodyR * 0.34
                ctx.fill(Path(ellipseIn: CGRect(x: ex - eyeR, y: eyeY - eyeR, width: eyeR * 2, height: eyeR * 2)), with: .color(bg))
                let pr = eyeR * 0.56
                ctx.fill(Path(ellipseIn: CGRect(x: ex - pr, y: eyeY - pr, width: pr * 2, height: pr * 2)), with: .color(fg))
                let glint = pr * 0.32
                ctx.fill(Path(ellipseIn: CGRect(x: ex - pr * 0.45, y: eyeY - pr * 0.48, width: glint * 2, height: glint * 2)), with: .color(bg))
            }

        case .sun:
            let rays = 12
            let spin = phase * 0.18
            for i in 0..<rays {
                let a1 = Double(i) * (2.0 * .pi / Double(rays)) + spin
                let a2 = a1 + (.pi / Double(rays))
                var tri = Path()
                tri.move(to: CGPoint(x: cx, y: cy))
                tri.addLine(to: CGPoint(x: cx + CGFloat(cos(a1)) * maxR * 1.05, y: cy + CGFloat(sin(a1)) * maxR * 1.05))
                tri.addLine(to: CGPoint(x: cx + CGFloat(cos(a2)) * maxR * 1.05, y: cy + CGFloat(sin(a2)) * maxR * 1.05))
                tri.closeSubpath()
                ctx.fill(tri, with: .color(fg))
            }
            let innerBg = maxR * 0.48
            ctx.fill(Path(ellipseIn: CGRect(x: cx - innerBg, y: cy - innerBg, width: innerBg * 2, height: innerBg * 2)), with: .color(bg))
            let coreRed = maxR * 0.30
            ctx.fill(Path(ellipseIn: CGRect(x: cx - coreRed, y: cy - coreRed, width: coreRed * 2, height: coreRed * 2)), with: .color(vermilion))

        case .crescent:
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(fg))
            let moonR = maxR * 0.66
            let moonCenter = CGPoint(x: cx - maxR * 0.08, y: cy)
            ctx.fill(Path(ellipseIn: CGRect(x: moonCenter.x - moonR, y: moonCenter.y - moonR, width: moonR * 2, height: moonR * 2)), with: .color(bg))
            let cutCenter = CGPoint(x: moonCenter.x + moonR * 0.44, y: moonCenter.y - moonR * 0.14)
            ctx.fill(Path(ellipseIn: CGRect(x: cutCenter.x - moonR * 0.88, y: cutCenter.y - moonR * 0.88, width: moonR * 1.76, height: moonR * 1.76)), with: .color(fg))
            let stars: [(CGFloat, CGFloat, CGFloat, Color)] = [
                (cx + maxR * 0.46, cy - maxR * 0.36, maxR * 0.15, vermilion),
                (cx + maxR * 0.54, cy + maxR * 0.16, maxR * 0.11, bg),
                (cx + maxR * 0.22, cy - maxR * 0.56, maxR * 0.09, bg),
            ]
            for (sx, sy, sr, color) in stars {
                ctx.fill(starPath(center: CGPoint(x: sx, y: sy), radius: sr), with: .color(color))
            }

        case .waves:
            let bands = 5
            let bandH = h / CGFloat(bands)
            let drift = phase * 1.4
            for b in 0..<bands where b % 2 == 0 {
                var wave = Path()
                let yTop = CGFloat(b) * bandH
                wave.move(to: CGPoint(x: 0, y: yTop))
                for x in stride(from: 0, through: Int(w), by: 8) {
                    let frac = Double(x) / Double(max(1, w))
                    let y = yTop + CGFloat(sin(frac * 4.0 * .pi + drift)) * bandH * 0.26
                    wave.addLine(to: CGPoint(x: CGFloat(x), y: y))
                }
                for x in stride(from: Int(w), through: 0, by: -8) {
                    let frac = Double(x) / Double(max(1, w))
                    let y = yTop + bandH * 0.62 + CGFloat(sin(frac * 4.0 * .pi + drift)) * bandH * 0.26
                    wave.addLine(to: CGPoint(x: CGFloat(x), y: y))
                }
                wave.closeSubpath()
                ctx.fill(wave, with: .color(b == 2 ? vermilion : fg))
            }

        case .dots:
            let grid = 3
            let pad = w * 0.18
            let step = (w - pad * 2) / CGFloat(grid - 1)
            let r = w * 0.105
            for row in 0..<grid {
                for col in 0..<grid {
                    let x = pad + CGFloat(col) * step
                    let y = pad + CGFloat(row) * step
                    let isCenter = (row == 1 && col == 1)
                    let radius = isCenter ? r * 1.18 : r
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                        with: .color(isCenter ? vermilion : fg)
                    )
                }
            }

        case .ottoLantern:
            // Rounded Otto lantern silhouette with high arch handle and vermilion warm focal bulb
            let bodyR = maxR * 0.66
            let arch = Path { p in
                p.addArc(center: CGPoint(x: cx, y: cy - bodyR * 0.42), radius: bodyR * 0.56, startAngle: .degrees(190), endAngle: .degrees(350), clockwise: false)
            }
            ctx.stroke(arch, with: .color(fg), style: StrokeStyle(lineWidth: maxR * 0.11, lineCap: .round))
            let bodyRect = CGRect(x: cx - bodyR * 0.88, y: cy - bodyR * 0.36, width: bodyR * 1.76, height: bodyR * 1.38)
            ctx.fill(Path(roundedRect: bodyRect, cornerRadius: bodyR * 0.68), with: .color(fg))
            // Hanging vermilion glow bead inside arch + crisp expressive newborn eyes
            let bulbR = bodyR * 0.22
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - bulbR, y: cy - bodyR * 0.96 - bulbR, width: bulbR * 2, height: bulbR * 2)),
                with: .color(vermilion)
            )
            let eyeR = bodyR * 0.22
            let eyeY = cy + bodyR * 0.18
            for dir in [-1.0, 1.0] {
                let ex = cx + CGFloat(dir) * bodyR * 0.34
                ctx.fill(Path(ellipseIn: CGRect(x: ex - eyeR, y: eyeY - eyeR, width: eyeR * 2, height: eyeR * 2)), with: .color(bg))
                let pr = eyeR * 0.55
                ctx.fill(Path(ellipseIn: CGRect(x: ex - pr, y: eyeY - pr, width: pr * 2, height: pr * 2)), with: .color(fg))
            }

        case .butterfly:
            // Bold symmetrical geometric butterfly with vermilion wing eyespots
            for dir in [-1.0, 1.0] {
                let s = CGFloat(dir)
                let upper = CGRect(x: cx + (dir < 0 ? -maxR * 0.90 : maxR * 0.12), y: cy - maxR * 0.68, width: maxR * 0.78, height: maxR * 0.74)
                let lower = CGRect(x: cx + (dir < 0 ? -maxR * 0.68 : maxR * 0.12), y: cy + maxR * 0.08, width: maxR * 0.56, height: maxR * 0.58)
                ctx.fill(Path(ellipseIn: upper), with: .color(fg))
                ctx.fill(Path(ellipseIn: lower), with: .color(fg))
                let spotR = maxR * 0.17
                let sx = cx + s * maxR * 0.50
                let sy = cy - maxR * 0.31
                ctx.fill(Path(ellipseIn: CGRect(x: sx - spotR, y: sy - spotR, width: spotR * 2, height: spotR * 2)), with: .color(bg))
                let redR = spotR * 0.62
                ctx.fill(Path(ellipseIn: CGRect(x: sx - redR, y: sy - redR, width: redR * 2, height: redR * 2)), with: .color(vermilion))
            }
            let bodyW = maxR * 0.20
            let bodyH = maxR * 1.12
            ctx.fill(Path(roundedRect: CGRect(x: cx - bodyW / 2, y: cy - bodyH / 2, width: bodyW, height: bodyH), cornerRadius: bodyW / 2), with: .color(fg))

        case .nestedSquares:
            // 5 nested alternating contrast borders for sharp edge tracking
            let steps = 5
            for i in 0..<steps {
                let frac = 1.0 - CGFloat(i) / CGFloat(steps)
                let s = maxR * 1.92 * frac
                let rect = CGRect(x: cx - s / 2, y: cy - s / 2, width: s, height: s)
                let r = max(8, s * 0.12)
                ctx.fill(Path(roundedRect: rect, cornerRadius: r), with: .color(i % 2 == 0 ? fg : bg))
            }
            let dotR = maxR * 0.12
            ctx.fill(Path(ellipseIn: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)), with: .color(vermilion))

        case .botanicalLeaf:
            // Bold symmetrical twin sprout leaves with crisp contrast ribs & a vermilion dewdrop
            let stemW = maxR * 0.12
            ctx.fill(Path(roundedRect: CGRect(x: cx - stemW / 2, y: cy - maxR * 0.1, width: stemW, height: maxR * 0.95), cornerRadius: stemW / 2), with: .color(fg))
            for dir in [-1.0, 1.0] {
                var leaf = Path()
                let base = CGPoint(x: cx, y: cy + maxR * 0.08)
                let tip = CGPoint(x: cx + CGFloat(dir) * maxR * 0.86, y: cy - maxR * 0.56)
                let c1 = CGPoint(x: cx + CGFloat(dir) * maxR * 0.10, y: cy - maxR * 0.88)
                let c2 = CGPoint(x: cx + CGFloat(dir) * maxR * 0.92, y: cy + maxR * 0.24)
                leaf.move(to: base)
                leaf.addQuadCurve(to: tip, control: c1)
                leaf.addQuadCurve(to: base, control: c2)
                ctx.fill(leaf, with: .color(fg))
                var vein = Path()
                vein.move(to: CGPoint(x: cx + CGFloat(dir) * maxR * 0.08, y: cy + maxR * 0.02))
                vein.addLine(to: CGPoint(x: cx + CGFloat(dir) * maxR * 0.56, y: cy - maxR * 0.34))
                ctx.stroke(vein, with: .color(bg), style: StrokeStyle(lineWidth: maxR * 0.06, lineCap: .round))
            }
            let dewR = maxR * 0.14
            ctx.fill(Path(ellipseIn: CGRect(x: cx - dewR, y: cy - maxR * 0.62 - dewR, width: dewR * 2, height: dewR * 2)), with: .color(vermilion))
        }
    }

    private func starPath(center: CGPoint, radius: CGFloat) -> Path {
        var p = Path()
        for i in 0..<8 {
            let angle = Double(i) * (.pi / 4.0) - (.pi / 2.0)
            let r = i % 2 == 0 ? radius : radius * 0.36
            let pt = CGPoint(x: center.x + CGFloat(cos(angle)) * r, y: center.y + CGFloat(sin(angle)) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
