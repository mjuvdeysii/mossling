import SwiftUI
import CoreMotion

/// The four tactile Montessori co-play studios inside 「感官玩具盒 / Sensory Toybox」.
enum ToyboxMode: String, CaseIterable, Identifiable {
    case xylophone, rainstick, fireflies, contrast
    var id: String { rawValue }

    var title: String {
        switch self {
        case .xylophone: L10n.t("木琴", "Keys")
        case .rainstick: L10n.t("金珠", "Beads")
        case .fireflies: L10n.t("萤火", "Glow")
        case .contrast: L10n.t("视卡", "Cards")
        }
    }

    var symbol: String {
        switch self {
        case .xylophone: "music.note"
        case .rainstick: "circle.grid.3x3.fill"
        case .fireflies: "sparkles"
        case .contrast: "circle.lefthalf.filled"
        }
    }

    var tone: Color {
        switch self {
        case .xylophone: Crayon.teal
        case .rainstick: Crayon.sunflower
        case .fireflies: Crayon.lilac
        case .contrast: Crayon.caramel
        }
    }
}

/// 「感官玩具盒 / Sensory Toybox」 — An offline, tactile Montessori studio designed for parent-child co-play:
/// 1) 8-bar graduated wooden xylophone with real-time rosewood marimba DSP & glissando,
/// 2) 26-bead golden Montessori rainstick driven by gentle phone tilt or finger stir,
/// 3) 18-firefly twilight lantern jar with pentatonic wind-chime shimmer & finger attraction,
/// 4) 8 museum-grade newborn (0–4 mo) high-contrast visual cards.
struct ToyboxView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var mode: ToyboxMode
    @Namespace private var pillNS

    init(initialMode: ToyboxMode = .xylophone) {
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        VStack(spacing: 12) {
            coPlayReminder(dark: dark)
            modePicker(dark: dark)

            Group {
                switch mode {
                case .xylophone:
                    XylophoneStudio(dark: dark)
                case .rainstick:
                    RainstickStudio(dark: dark)
                case .fireflies:
                    FireflyJarStudio()
                case .contrast:
                    ContrastCardStudio(dark: dark)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .pageBackground(tone: mode.tone)
        .navigationTitle(L10n.t("感官玩具盒", "Sensory Toybox"))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            ToyboxAudioEngine.shared.stop()
        }
    }

    private func coPlayReminder(dark: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.raised.fingers.spread.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.accent)
            Text(L10n.t("和宝宝一起轻点共玩，不单独给宝宝看屏幕", "Co-play together — never solo screen time"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                .fill(dark ? Palette.lampCard.opacity(0.85) : Palette.card.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                .strokeBorder(Palette.outline.opacity(0.28), lineWidth: 0.75)
        )
    }

    private func modePicker(dark: Bool) -> some View {
        HStack(spacing: 6) {
            ForEach(ToyboxMode.allCases) { item in
                let selected = mode == item
                Button {
                    guard mode != item else { return }
                    TactileEngine.shared.beadClick()
                    withAnimation(reduce ? nil : .spring(response: 0.34, dampingFraction: 0.82)) {
                        mode = item
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: item.symbol)
                            .font(.caption.weight(.bold))
                        Text(item.title)
                            .font(.footnote.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selected ? .white : Palette.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if selected {
                            Capsule()
                                .fill(Palette.accentFill)
                                .matchedGeometryEffect(id: "toyboxModePill", in: pillNS)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(dark ? Palette.lampCard : Palette.card)
        )
        .overlay(
            Capsule()
                .strokeBorder(Palette.outline.opacity(0.3), lineWidth: 0.75)
        )
    }
}

// MARK: - Studio 1: Wooden Montessori Xylophone

private struct XylophoneStudio: View {
    let dark: Bool
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var activeBar: Int? = nil
    @State private var lastNote: ToyboxNote? = nil
    @State private var mossLook: CGPoint = CGPoint(x: 0, y: 0.45)
    @State private var mossMood: Mood = .open
    @State private var noteNotice: Int = 0
    @State private var isPlayingLullaby = false
    @State private var lullabyTask: Task<Void, Never>? = nil
    @State private var sparkleIndex: Int? = nil

    /// Displayed top-to-bottom from treble C6 down to bass C5 like a Montessori staircase.
    private var orderedNotes: [ToyboxNote] { Array(ToyboxNote.scale.reversed()) }

    var body: some View {
        VStack(spacing: 12) {
            // Moss perched above the wooden resonator, eyes tracking each struck bar
            HStack(spacing: 12) {
                Creature(kind: .moss, mood: mossMood, look: mossLook, alive: true, poke: true, notice: noteNotice)
                    .frame(width: 68, height: 68)

                VStack(alignment: .leading, spacing: 3) {
                    Text(lastNote.map { "\($0.numberLabel) · \($0.solfege) (\($0.pitchName))" } ?? L10n.t("轻敲或上下滑过木条", "Tap or glide across the wooden bars"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(L10n.t("真实木琴泛音实时合成 · 支持连滑和弦", "Warm rosewood marimba · tap or glide"))
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .printCard(radius: Radius.card)

            // Wooden xylophone board with tap & continuous glissando support
            GeometryReader { geo in
                let bars = orderedNotes
                let verticalInset: CGFloat = 14
                let spacing: CGFloat = 9
                let usableH = max(160, geo.size.height - verticalInset * 2)
                let barH = max(32, (usableH - spacing * CGFloat(bars.count - 1)) / CGFloat(bars.count))

                ZStack {
                    // Beechwood resonator rails behind the rainbow bars
                    HStack(spacing: geo.size.width * 0.24) {
                        woodRail(dark: dark)
                        woodRail(dark: dark)
                    }
                    .padding(.vertical, 10)

                    VStack(spacing: spacing) {
                        ForEach(bars) { note in
                            xylophoneBar(note: note, maxWidth: geo.size.width - 28, height: barH)
                        }
                    }
                    .padding(.vertical, verticalInset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .fill(dark ? Color(hex: 0x151D38) : Color(hex: 0xF5EFE3))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(dark ? Palette.amber.opacity(0.18) : Color(hex: 0xC69A6B).opacity(0.32), lineWidth: 1)
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
                                strike(hit)
                            }
                        }
                        .onEnded { _ in
                            withAnimation(reduce ? nil : .spring(response: 0.26, dampingFraction: 0.72)) {
                                activeBar = nil
                            }
                        }
                )
            }
            .frame(minHeight: 330)

            // Footer gentle lullaby demo button
            HStack(spacing: 12) {
                Button {
                    if isPlayingLullaby {
                        stopLullaby()
                    } else {
                        playLullaby()
                    }
                } label: {
                    Label(
                        isPlayingLullaby ? L10n.t("停下来", "Stop Melody") : L10n.t("轻奏一小段摇篮曲", "Play Gentle Lullaby"),
                        systemImage: isPlayingLullaby ? "stop.fill" : "music.quarternote.3"
                    )
                    .font(.subheadline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.vinyl(isPlayingLullaby ? Crayon.pink : Palette.accentFill, prominent: true))
            }
        }
        .onDisappear { stopLullaby() }
    }

    private func woodRail(dark: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                LinearGradient(
                    colors: dark
                        ? [Color(hex: 0x3D3028), Color(hex: 0x2B211B)]
                        : [Color(hex: 0xD8B489), Color(hex: 0xBC9062)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 14)
            .shadow(color: .black.opacity(dark ? 0.35 : 0.12), radius: 3, y: 2)
    }

    private func xylophoneBar(note: ToyboxNote, maxWidth: CGFloat, height: CGFloat) -> some View {
        let pressed = activeBar == note.index
        let glowing = sparkleIndex == note.index
        let barW = max(140, maxWidth * note.widthRatio)
        let shape = RoundedRectangle(cornerRadius: min(14, height * 0.36), style: .continuous)

        return ZStack {
            shape
                .fill(
                    LinearGradient(
                        colors: [
                            note.color.mix(with: .white, by: pressed ? 0.32 : (dark ? 0.08 : 0.20)),
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
                            colors: [.white.opacity(pressed ? 0.85 : (dark ? 0.25 : 0.65)), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: pressed ? 2 : 1
                    )
                )
                .shadow(color: note.color.opacity(pressed ? 0.42 : (dark ? 0.22 : 0.26)), radius: pressed ? 10 : 4, y: pressed ? 1 : 3)

            HStack {
                brassRivet
                Spacer()
                HStack(spacing: 6) {
                    Text(note.numberLabel)
                        .font(Typeface.numerals(15, relativeTo: .headline, weight: .bold))
                    Text(note.solfege)
                        .font(.footnote.weight(.bold))
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.22), radius: 1, y: 1)
                Spacer()
                brassRivet
            }
            .padding(.horizontal, 16)

            if glowing && !reduce {
                Circle()
                    .fill(.white.opacity(0.45))
                    .frame(width: height * 0.85, height: height * 0.85)
                    .blur(radius: 6)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: barW, height: height)
        .scaleEffect(pressed ? 0.96 : 1.0)
        .animation(reduce ? nil : .spring(response: 0.20, dampingFraction: 0.62), value: pressed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(note.solfege), \(note.pitchName)")
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            stopLullaby()
            strike(note)
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

    private func strike(_ note: ToyboxNote) {
        ToyboxAudioEngine.shared.playNote(note)
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred(intensity: 0.55 + Double(note.index) * 0.04)
        }
        withAnimation(reduce ? nil : .spring(response: 0.18, dampingFraction: 0.65)) {
            activeBar = note.index
            lastNote = note
            sparkleIndex = note.index
        }
        // Moss glances smoothly along the scale and cheers on C5/C6
        let normalizedX = (Double(note.index) / 7.0) * 1.4 - 0.7
        mossLook = CGPoint(x: normalizedX, y: 0.65)
        mossMood = (note.index == 0 || note.index == 7) ? .happy : .open
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
        lullabyTask = Task { @MainActor in
            for (noteIdx, pause) in ToyboxNote.lullabyPhrase {
                guard !Task.isCancelled else { break }
                if noteIdx >= 0 && noteIdx < ToyboxNote.scale.count {
                    strike(ToyboxNote.scale[noteIdx])
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
    var physics = RainstickPhysics.initial()
    var lastFrameDate: Date? = nil
    var touchPoint: CGPoint? = nil
    var flipped = false
    var motionGX: Double = 0
    var motionGY: Double = 1.0
    private var motionManager: CMMotionManager?
    private let haptic = UIImpactFeedbackGenerator(style: .soft)

    private var isTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
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
            ToyboxAudioEngine.shared.playBeadClick(intensity: intensity)
            if impacts >= 2 {
                haptic.impactOccurred(intensity: min(0.6, 0.25 + Double(impacts) * 0.08))
            }
        }
    }
}

private struct RainstickStudio: View {
    let dark: Bool
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var sim = RainstickSimulation()
    @State private var flipCount = 0

    private static let pastelBeads: [Color] = [
        Crayon.teal, Crayon.pink, Crayon.sky, Crayon.leaf, Crayon.lilac, Crayon.tangerine
    ]

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let boardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)
                ZStack {
                    // Warm wooden Montessori tray frame
                    boardShape
                        .fill(
                            LinearGradient(
                                colors: dark
                                    ? [Color(hex: 0x262038), Color(hex: 0x161A31)]
                                    : [Color(hex: 0xE7D5B8), Color(hex: 0xD3BA92)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(dark ? 0.38 : 0.14), radius: 10, y: 5)

                    // Inner felt / satin-wood tray recessed well
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: dark
                                    ? [Color(hex: 0x0F152D), Color(hex: 0x141C3A)]
                                    : [Color(hex: 0xFAF5EA), Color(hex: 0xF1E7D5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(dark ? Palette.amber.opacity(0.18) : Color(hex: 0xB89464).opacity(0.45), lineWidth: 1.5)
                                .padding(10)
                        )

                    TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduce || Perf.still)) { tl in
                        Canvas(rendersAsynchronously: false) { ctx, size in
                            if !reduce && !Perf.still {
                                sim.advance(to: tl.date)
                            }
                            drawBoard(ctx: &ctx, size: size)
                        }
                    }
                    .padding(14)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let w = max(1, geo.size.width - 28)
                                let h = max(1, geo.size.height - 28)
                                sim.touchPoint = CGPoint(
                                    x: max(0, min(1, value.location.x / w)),
                                    y: max(0, min(1, value.location.y / h))
                                )
                            }
                            .onEnded { _ in
                                sim.touchPoint = nil
                            }
                    )

                    // Subtle Otto watching calmly from the bottom-right rim
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Creature(kind: .otto, mood: .open, alive: false, glow: dark)
                                .frame(width: 44, height: 44)
                                .padding(18)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
            .frame(minHeight: 360)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("轻倾手机，或手指拨动金珠", "Tilt gently or stir the beads"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(L10n.t("26 颗蒙氏金珠与彩木珠 · 轻响雨声", "26 golden & pastel wooden beads · soft rain clicks"))
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                }
                Spacer(minLength: 8)
                Button {
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
            if !reduce { sim.startMotion() }
        }
        .onDisappear {
            sim.stopMotion()
        }
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

        // Turned oak wooden baffle pegs
        for peg in sim.physics.pegs {
            let cx = CGFloat(peg.x) * size.width
            let cy = CGFloat(peg.y) * size.height
            let r = CGFloat(peg.radius) * minSide
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

        // 26 luminous golden & pastel Montessori wooden beads
        for bead in sim.physics.beads {
            let cx = CGFloat(bead.x) * size.width
            let cy = CGFloat(bead.y) * size.height
            let r = CGFloat(bead.radius) * minSide

            let shadow = CGRect(x: cx - r * 0.92, y: cy - r * 0.8 + 2.2, width: r * 1.84, height: r * 1.84)
            ctx.fill(Path(ellipseIn: shadow), with: .color(.black.opacity(dark ? 0.40 : 0.16)))

            let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
            let base = bead.isGold ? Palette.bead : Self.pastelBeads[bead.colorIndex % Self.pastelBeads.count]
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
    var physics = FireflyPhysics.initial()
    var lastFrameDate: Date? = nil
    var touchPoint: CGPoint? = nil

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
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var sim = FireflySimulation()
    @State private var swirlCount = 0

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { geo in
                let jarShape = RoundedRectangle(cornerRadius: 34, style: .continuous)
                VStack(spacing: 0) {
                    // Warm brushed-brass lantern lid
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0xE5C17B), Color(hex: 0xB8893D), Color(hex: 0x8F6526)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: min(148, geo.size.width * 0.44), height: 18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(.white.opacity(0.38), lineWidth: 0.75)
                            )
                            .shadow(color: .black.opacity(0.28), radius: 4, y: 2)

                        // Subtle horizontal lathe groove on brass cap
                        Capsule()
                            .fill(.white.opacity(0.28))
                            .frame(width: min(124, geo.size.width * 0.36), height: 2)
                            .offset(y: -3)
                    }
                    .zIndex(2)
                    .padding(.bottom, -5)

                    // Twilight glass lantern jar
                    ZStack {
                        jarShape
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: 0x0B132B),
                                        Color(hex: 0x152246),
                                        Color(hex: 0x101A36)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: Color(hex: 0x0A1024).opacity(0.45), radius: 14, y: 6)

                        // Warm twilight horizon bloom along the glass base
                        jarShape
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Palette.amber.opacity(0.22),
                                        Color(hex: 0x4ECBA2).opacity(0.08),
                                        .clear
                                    ],
                                    center: UnitPoint(x: 0.5, y: 0.88),
                                    startRadius: 12,
                                    endRadius: max(180, geo.size.width * 0.65)
                                )
                            )

                        // 60fps glowing fireflies & fingertip lantern ripple
                        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduce || Perf.still)) { tl in
                            Canvas(rendersAsynchronously: false) { ctx, size in
                                if !reduce && !Perf.still {
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
                                    let w = max(1, geo.size.width)
                                    let h = max(1, geo.size.height - 14)
                                    let nx = max(0.08, min(0.92, value.location.x / w))
                                    let ny = max(0.10, min(0.90, value.location.y / h))
                                    sim.touchPoint = CGPoint(x: nx, y: ny)
                                    ToyboxAudioEngine.shared.playFireflyChime(normalizedY: ny)
                                }
                                .onEnded { _ in
                                    sim.touchPoint = nil
                                }
                        )

                        // Curved blown-glass reflections on left and right rims
                        HStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.24), .white.opacity(0.03)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 5)
                                .padding(.vertical, 34)
                                .padding(.leading, 14)
                            Spacer()
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.12), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 3)
                                .padding(.vertical, 52)
                                .padding(.trailing, 14)
                        }
                        .allowsHitTesting(false)

                        // Subtle glass rim bevel
                        jarShape
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.32), Palette.amber.opacity(0.22), .white.opacity(0.14)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                            .allowsHitTesting(false)

                        // Otto watching quietly from the twilight meadow sill
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Creature(kind: .otto, mood: .open, look: CGPoint(x: -0.45, y: -0.45), alive: false, glow: true)
                                    .frame(width: 48, height: 48)
                                    .padding(16)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
            }
            .frame(minHeight: 360)

            // Tactile studio footer card
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("轻触玻璃牵引萤火，或轻摇流光", "Touch to beckon fireflies, or swirl"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(L10n.t("18 只暖金与薄荷萤火 · 五声音阶风铃", "18 amber & mint fireflies · pentatonic chimes"))
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                Spacer(minLength: 8)
                Button {
                    TactileEngine.shared.beadClick()
                    sim.swirl()
                    swirlCount &+= 1
                    ToyboxAudioEngine.shared.playFireflyChime(normalizedY: 0.28)
                } label: {
                    Label(L10n.t("轻摇流光", "Swirl"), systemImage: "sparkles")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 14)
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

        // 18 glowing fireflies with triple-layer soft radial aura + ivory pearl core
        for fly in sim.physics.flies {
            let cx = CGFloat(fly.x) * size.width
            let cy = CGFloat(fly.y) * size.height
            let pulse = 0.62 + 0.38 * sin(time * 2.2 + fly.phase)
            let baseR = CGFloat(fly.size) * 4.8 * CGFloat(0.88 + 0.22 * pulse)

            let glowColor = fly.isMint ? Color(hex: 0x8CEBC5) : Color(hex: 0xFFD46B)
            let midColor = fly.isMint ? Color(hex: 0xCFFCE7) : Color(hex: 0xFFEAA6)

            // Outer soft lantern aura
            let outerR = baseR * 4.2
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2)),
                with: .radialGradient(
                    Gradient(colors: [glowColor.opacity(0.46 * pulse), glowColor.opacity(0.10 * pulse), .clear]),
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
                with: .color(Color(hex: 0xFFFDF5).opacity(0.85 + 0.15 * pulse))
            )
        }
    }
}

// MARK: - Studio 4: Newborn High-Contrast Visual Cards (0–4 mo)

enum ContrastCardKind: Int, CaseIterable, Identifiable {
    case rings, checkerboard, spiral, mossSilhouette, sun, crescent, waves, dots
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
        }
    }

    var ageHint: String {
        switch self {
        case .rings, .checkerboard, .spiral:
            L10n.t("0–2 个月 · 纯黑白强对比", "0–2 mo · Pure black & ivory")
        case .mossSilhouette:
            L10n.t("0–3 个月 · 脸部轮廓与眼神", "0–3 mo · Face & gentle eyes")
        case .sun, .crescent, .waves:
            L10n.t("1–4 个月 · 黑白配一抹暖红", "1–4 mo · Monochrome + vermilion")
        case .dots:
            L10n.t("2–4 个月 · 追视圆点节奏", "2–4 mo · Visual tracking dots")
        }
    }
}

private struct ContrastCardStudio: View {
    let dark: Bool
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var index = 0
    @State private var gentlePulse = false

    private let cards = ContrastCardKind.allCases

    var body: some View {
        let current = cards[max(0, min(index, cards.count - 1))]
        VStack(spacing: 12) {
            TabView(selection: $index) {
                ForEach(cards) { card in
                    ContrastCardArtwork(kind: card, pulse: gentlePulse && !reduce)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .tag(card.rawValue)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onChange(of: index) { oldVal, newVal in
                guard oldVal != newVal else { return }
                TactileEngine.shared.pageTurn()
            }

            // Montessori bead pagination & gentle newborn viewing guide
            VStack(spacing: 10) {
                HStack(spacing: 7) {
                    ForEach(cards) { c in
                        let active = c.rawValue == index
                        Circle()
                            .fill(active ? Palette.bead : Palette.secondaryText.opacity(0.28))
                            .frame(width: active ? 9 : 6, height: active ? 9 : 6)
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
                        .background(Capsule().fill(Palette.fill))
                }

                Text(L10n.t("距宝宝眼前约 20–30 cm 稳稳拿着，左右轻缓移动，看宝宝眼神追随。", "Hold 8–12 in from baby's eyes and glide slowly side to side as their gaze follows."))
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .printCard(radius: Radius.card)
        }
        .onAppear {
            guard !reduce && !Perf.still else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                gentlePulse = true
            }
        }
    }
}

/// Crisp vector museum board card drawn in warm ivory (#FBF7F0), deep charcoal (#191A17), and subtle vermilion (#D64234).
private struct ContrastCardArtwork: View {
    let kind: ContrastCardKind
    let pulse: Bool

    private let ivory = Color(hex: 0xFBF7F0)
    private let charcoal = Color(hex: 0x191A17)
    private let vermilion = Color(hex: 0xD64234)

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(ivory)
                    .shadow(color: .black.opacity(0.14), radius: 12, y: 6)

                Canvas { ctx, size in
                    draw(kind: kind, ctx: &ctx, size: size)
                }
                .scaleEffect(pulse ? 1.028 : 0.985)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(10)

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(charcoal.opacity(0.14), lineWidth: 1.5)
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.title)
    }

    private func draw(kind: ContrastCardKind, ctx: inout GraphicsContext, size: CGSize) {
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
                ctx.fill(Path(ellipseIn: rect), with: .color(step % 2 == 0 ? charcoal : ivory))
            }

        case .checkerboard:
            let n = 4
            let cellW = w / CGFloat(n)
            let cellH = h / CGFloat(n)
            for r in 0..<n {
                for c in 0..<n where (r + c) % 2 == 0 {
                    ctx.fill(Path(CGRect(x: CGFloat(c) * cellW, y: CGFloat(r) * cellH, width: cellW, height: cellH)), with: .color(charcoal))
                }
            }

        case .spiral:
            var path = Path()
            let turns = 3.5
            let steps = 260
            for i in 0...steps {
                let frac = Double(i) / Double(steps)
                let angle = frac * turns * 2.0 * .pi
                let r = Double(maxR) * frac
                let pt = CGPoint(x: cx + CGFloat(cos(angle) * r), y: cy + CGFloat(sin(angle) * r))
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            ctx.stroke(path, with: .color(charcoal), style: StrokeStyle(lineWidth: maxR * 0.14, lineCap: .round))

        case .mossSilhouette:
            // Rounded charcoal face/body silhouette inspired by Moss with two leaf ears and high-contrast eyes
            let bodyR = maxR * 0.78
            let bodyRect = CGRect(x: cx - bodyR, y: cy - bodyR * 0.72, width: bodyR * 2, height: bodyR * 1.72)
            ctx.fill(Path(ellipseIn: bodyRect), with: .color(charcoal))
            // Two leaf sprouts on top
            for dir in [-1.0, 1.0] {
                var leaf = Path()
                let base = CGPoint(x: cx + CGFloat(dir) * bodyR * 0.14, y: cy - bodyR * 0.68)
                let tip = CGPoint(x: cx + CGFloat(dir) * bodyR * 0.68, y: cy - bodyR * 1.24)
                let c1 = CGPoint(x: cx + CGFloat(dir) * bodyR * 0.05, y: cy - bodyR * 1.22)
                let c2 = CGPoint(x: cx + CGFloat(dir) * bodyR * 0.72, y: cy - bodyR * 0.78)
                leaf.move(to: base)
                leaf.addQuadCurve(to: tip, control: c1)
                leaf.addQuadCurve(to: base, control: c2)
                ctx.fill(leaf, with: .color(charcoal))
            }
            // Bright ivory eye whites + bold pupils for newborn face gaze
            let eyeR = bodyR * 0.24
            let eyeY = cy - bodyR * 0.06
            for dir in [-1.0, 1.0] {
                let ex = cx + CGFloat(dir) * bodyR * 0.34
                ctx.fill(Path(ellipseIn: CGRect(x: ex - eyeR, y: eyeY - eyeR, width: eyeR * 2, height: eyeR * 2)), with: .color(ivory))
                let pr = eyeR * 0.56
                ctx.fill(Path(ellipseIn: CGRect(x: ex - pr, y: eyeY - pr, width: pr * 2, height: pr * 2)), with: .color(charcoal))
                let glint = pr * 0.32
                ctx.fill(Path(ellipseIn: CGRect(x: ex - pr * 0.45, y: eyeY - pr * 0.48, width: glint * 2, height: glint * 2)), with: .color(ivory))
            }

        case .sun:
            let rays = 12
            for i in 0..<rays {
                let a1 = Double(i) * (2.0 * .pi / Double(rays))
                let a2 = a1 + (.pi / Double(rays))
                var tri = Path()
                tri.move(to: CGPoint(x: cx, y: cy))
                tri.addLine(to: CGPoint(x: cx + CGFloat(cos(a1)) * maxR * 1.05, y: cy + CGFloat(sin(a1)) * maxR * 1.05))
                tri.addLine(to: CGPoint(x: cx + CGFloat(cos(a2)) * maxR * 1.05, y: cy + CGFloat(sin(a2)) * maxR * 1.05))
                tri.closeSubpath()
                ctx.fill(tri, with: .color(charcoal))
            }
            let innerIvory = maxR * 0.48
            ctx.fill(Path(ellipseIn: CGRect(x: cx - innerIvory, y: cy - innerIvory, width: innerIvory * 2, height: innerIvory * 2)), with: .color(ivory))
            let coreRed = maxR * 0.30
            ctx.fill(Path(ellipseIn: CGRect(x: cx - coreRed, y: cy - coreRed, width: coreRed * 2, height: coreRed * 2)), with: .color(vermilion))

        case .crescent:
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(charcoal))
            let moonR = maxR * 0.66
            let moonCenter = CGPoint(x: cx - maxR * 0.08, y: cy)
            ctx.fill(Path(ellipseIn: CGRect(x: moonCenter.x - moonR, y: moonCenter.y - moonR, width: moonR * 2, height: moonR * 2)), with: .color(ivory))
            let cutCenter = CGPoint(x: moonCenter.x + moonR * 0.44, y: moonCenter.y - moonR * 0.14)
            ctx.fill(Path(ellipseIn: CGRect(x: cutCenter.x - moonR * 0.88, y: cutCenter.y - moonR * 0.88, width: moonR * 1.76, height: moonR * 1.76)), with: .color(charcoal))
            // Bold stars (one warm vermilion accent star)
            let stars: [(CGFloat, CGFloat, CGFloat, Color)] = [
                (cx + maxR * 0.46, cy - maxR * 0.36, maxR * 0.15, vermilion),
                (cx + maxR * 0.54, cy + maxR * 0.16, maxR * 0.11, ivory),
                (cx + maxR * 0.22, cy - maxR * 0.56, maxR * 0.09, ivory),
            ]
            for (sx, sy, sr, color) in stars {
                ctx.fill(starPath(center: CGPoint(x: sx, y: sy), radius: sr), with: .color(color))
            }

        case .waves:
            let bands = 5
            let bandH = h / CGFloat(bands)
            for b in 0..<bands where b % 2 == 0 {
                var wave = Path()
                let yTop = CGFloat(b) * bandH
                wave.move(to: CGPoint(x: 0, y: yTop))
                for x in stride(from: 0, through: Int(w), by: 8) {
                    let frac = Double(x) / Double(max(1, w))
                    let y = yTop + CGFloat(sin(frac * 4.0 * .pi)) * bandH * 0.26
                    wave.addLine(to: CGPoint(x: CGFloat(x), y: y))
                }
                for x in stride(from: Int(w), through: 0, by: -8) {
                    let frac = Double(x) / Double(max(1, w))
                    let y = yTop + bandH * 0.62 + CGFloat(sin(frac * 4.0 * .pi)) * bandH * 0.26
                    wave.addLine(to: CGPoint(x: CGFloat(x), y: y))
                }
                wave.closeSubpath()
                ctx.fill(wave, with: .color(b == 2 ? vermilion : charcoal))
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
                        with: .color(isCenter ? vermilion : charcoal)
                    )
                }
            }
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
