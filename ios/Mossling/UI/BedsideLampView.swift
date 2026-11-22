import SwiftUI
import CoreMotion

/// Otto's Living Bedside Lamp (床头夜灯): a full-screen zero-glare midnight sanctuary for 3 a.m. feeds and settling.
/// Features a vertical thumb-slide warm dimmer with fine brass CoreHaptics detents, subtle gyroscope pendulum glow,
/// four zero-asset real-time soothing soundscapes with auto-fade, and one-tap midnight care controls.
struct BedsideLampView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduce

    /// Initial brightness (0.15...1.0), configurable for previews and deterministic screenshots.
    @State private var brightness: Double
    @State private var dragStartBrightness: Double? = nil
    @State private var lastDetentStep: Int = -1
    @State private var showingDimmerHint = true
    @State private var breathingGuide: Bool
    @State private var soundscape = SoundscapeEngine.shared
    @State private var motion = LampTiltObserver()
    @State private var pulse = false

    init(initialBrightness: Double = 0.72, initialBreathingGuide: Bool = false) {
        _brightness = State(initialValue: max(0.15, min(1.0, initialBrightness)))
        _breathingGuide = State(initialValue: initialBreathingGuide)
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

    var body: some View {
        ZStack {
            backdrop
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

                Spacer(minLength: 10)

                VStack(spacing: 14) {
                    soundscapeDeck
                    if app.journal {
                        careDock
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
        .gesture(dimmerGesture)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if !reduce {
                motion.start()
                withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            motion.stop()
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Living Midnight Backdrop & Gyro Pendulum Light

    private var backdrop: some View {
        let swayX = reduce ? 0 : motion.roll * 26
        let swayY = reduce ? 0 : motion.pitch * 18
        let b = brightness
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
                    Palette.amber.opacity(0.42 * b * (pulse ? 1.0 : 0.88)),
                    Palette.lampTint.opacity(0.22 * b),
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
                    Palette.amber.opacity(0.14 * b),
                    .clear
                ],
                center: UnitPoint(x: 0.5 - swayX / 900, y: 0.88),
                startRadius: 0,
                endRadius: 280
            )

            // Whisper-soft warm dust motes rising in Otto's beam
            if !reduce && !Perf.still {
                LampDustCanvas(brightness: b)
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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.lampInk.opacity(0.86))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color(hex: 0x1A2346).opacity(0.75)))
                    .overlay(Circle().strokeBorder(Palette.amber.opacity(0.22), lineWidth: 1))
            }
            .buttonStyle(.toy)
            .accessibilityLabel(L10n.t("关闭夜灯", "Close Bedside Lamp"))

            Spacer()

            TimelineView(.periodic(from: .now, by: 30)) { tl in
                VStack(spacing: 2) {
                    Text(hm(tl.date))
                        .font(Typeface.numerals(20, relativeTo: .title3, weight: .bold))
                        .foregroundStyle(Palette.lampInk.opacity(0.65 + 0.3 * brightness))
                    Text(
                        dragStartBrightness != nil
                            ? L10n.t("暖光 \(Int((brightness * 100).rounded()))%", "Warmth \(Int((brightness * 100).rounded()))%")
                            : (soundscape.activeSummary ?? L10n.t("Otto 的床头夜灯", "Otto's Bedside Lamp"))
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.amber.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .contentTransition(.opacity)
                }
            }

            Spacer()

            // Calm 4-6 paced breathing guide toggle right on the top bar
            Button {
                TactileEngine.shared.beadClick()
                withAnimation(reduce ? nil : .spring(response: 0.35, dampingFraction: 0.82)) {
                    breathingGuide.toggle()
                }
            } label: {
                Image(systemName: breathingGuide ? "circle.circle.fill" : "circle.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(breathingGuide ? Color(hex: 0x261700) : Palette.amber.opacity(0.88))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(breathingGuide ? Palette.amber : Color(hex: 0x1A2346).opacity(0.75)))
                    .overlay(Circle().strokeBorder(Palette.amber.opacity(breathingGuide ? 0.85 : 0.28), lineWidth: 1))
            }
            .buttonStyle(.toy)
            .accessibilityLabel(L10n.t(breathingGuide ? "关闭 4–6 慢呼吸光晕" : "开启 4–6 哄睡慢呼吸光晕", breathingGuide ? "Turn off calm breathing halo" : "Start 4–6 calm breathing halo"))
        }
    }

    // MARK: - Living Otto Centerpiece

    private var lanternCenterpiece: some View {
        let swayX = reduce ? 0 : motion.roll * 10
        return VStack(spacing: 12) {
            ZStack {
                if breathingGuide {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduce || Perf.still)) { tl in
                        let st = Self.breathingState(at: (reduce || Perf.still) ? 2.8 : tl.date.timeIntervalSinceReferenceDate)
                        let ringSize: CGFloat = 154 + CGFloat(st.progress) * 76
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color(hex: 0xFFE5A3).opacity((0.28 + 0.30 * st.progress) * brightness),
                                            Palette.amber.opacity((0.14 + 0.16 * st.progress) * brightness),
                                            .clear
                                        ],
                                        center: .center,
                                        startRadius: 20,
                                        endRadius: ringSize * 0.62
                                    )
                                )
                                .frame(width: ringSize + 44, height: ringSize + 44)

                            Circle()
                                .strokeBorder(Palette.amber.opacity((0.38 + 0.44 * st.progress) * brightness), lineWidth: 2.0)
                                .frame(width: ringSize, height: ringSize)

                            Circle()
                                .strokeBorder(Palette.beadLight.opacity((0.18 + 0.22 * st.progress) * brightness), lineWidth: 1.0)
                                .frame(width: ringSize + 24, height: ringSize + 24)
                        }
                    }
                } else {
                    // Concentric gentle acoustic ripples when a nursery soundscape is playing
                    if soundscape.isPlaying {
                        ForEach(0..<3, id: \.self) { idx in
                            Circle()
                                .strokeBorder(
                                    Palette.amber.opacity((0.24 - Double(idx) * 0.06) * brightness),
                                    lineWidth: 1.2
                                )
                                .frame(
                                    width: 156 + CGFloat(idx) * 44 + (pulse ? 14 : 0),
                                    height: 156 + CGFloat(idx) * 44 + (pulse ? 14 : 0)
                                )
                                .scaleEffect(pulse ? 1.04 : 0.96)
                                .animation(
                                    reduce ? nil : .easeInOut(duration: 3.8).repeatForever(autoreverses: true).delay(Double(idx) * 0.45),
                                    value: pulse
                                )
                        }
                    }

                    // Warm amber halo right behind Otto's golden bead
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hex: 0xFFE5A3).opacity(0.55 * brightness),
                                    Palette.amber.opacity(0.28 * brightness),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 4,
                                endRadius: 118
                            )
                        )
                        .frame(width: 236, height: 236)
                        .offset(x: swayX * 0.6, y: -14)
                }

                Creature(
                    kind: .otto,
                    mood: isSleeping ? .sleep : .open,
                    look: CGPoint(x: 0, y: 0.2),
                    lid: isSleeping ? 0.9 : 0.52,
                    lean: reduce ? 0 : motion.roll * 5.0,
                    alive: true,
                    poke: true,
                    label: L10n.t("Otto 提着床头夜灯陪着你们", "Otto holding the warm bedside lamp"),
                    glow: true
                )
                .frame(width: 156, height: 156)
                .opacity(0.65 + 0.35 * brightness)
            }
            .frame(height: 224)

            if breathingGuide {
                TimelineView(.periodic(from: .now, by: 0.25)) { tl in
                    let st = Self.breathingState(at: (reduce || Perf.still) ? 2.8 : tl.date.timeIntervalSinceReferenceDate)
                    HStack(spacing: 7) {
                        Circle()
                            .fill(Palette.amber.opacity(st.inhaling ? 0.95 : 0.55))
                            .frame(width: 7, height: 7)
                        Text(
                            st.inhaling
                                ? L10n.t("跟着暖光慢慢吸气 · \(st.secondsLeft)s", "Breathe in slowly · \(st.secondsLeft)s")
                                : L10n.t("缓缓放松呼气 · \(st.secondsLeft)s", "Breathe out gently · \(st.secondsLeft)s")
                        )
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.amber.opacity(0.92))
                        .monospacedDigit()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Palette.amber.opacity(0.14)))
                }
            } else {
                // Quiet tactile affordance cue (non-intrusive, fades gently after first dim)
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.and.down")
                        .font(.caption2.weight(.bold))
                    Text(L10n.t("上下滑动调节暖光亮度", "Slide up or down to dim"))
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(Palette.lampInk.opacity(showingDimmerHint ? 0.56 : 0.28))
                .accessibilityHidden(true)
            }
        }
    }

    // MARK: - Vertical Brass Dimmer Rail & Gesture

    private var dimmerGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard abs(value.translation.height) > abs(value.translation.width) * 1.15 else { return }
                if dragStartBrightness == nil {
                    dragStartBrightness = brightness
                    showingDimmerHint = false
                }
                let start = dragStartBrightness ?? brightness
                // Dragging up increases warmth/brightness; dragging down dims to whisper ember
                let delta = -Double(value.translation.height) / 340.0
                let clamped = max(0.15, min(1.0, start + delta))
                brightness = clamped
                let step = Int((clamped * 20).rounded()) // 5% mechanical brass detents
                if step != lastDetentStep {
                    lastDetentStep = step
                    TactileEngine.shared.dimmerTick()
                }
            }
            .onEnded { _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    dragStartBrightness = nil
                }
            }
    }

    private var dimmerRail: some View {
        let active = dragStartBrightness != nil
        return VStack(spacing: 6) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Palette.amber.opacity(active ? 0.9 : 0.42))

            GeometryReader { g in
                let h = g.size.height
                let normalized = (brightness - 0.15) / 0.85
                let fillH = max(8, h * normalized)
                ZStack(alignment: .bottom) {
                    Capsule()
                        .fill(Color.white.opacity(active ? 0.14 : 0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0xFFE39E), Palette.lampTint],
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
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Palette.lampInk.opacity(active ? 0.72 : 0.36))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t("夜灯亮度", "Lamp brightness"))
        .accessibilityValue("\(Int((brightness * 100).rounded()))%")
        .accessibilityAdjustableAction { dir in
            switch dir {
            case .increment:
                brightness = min(1.0, brightness + 0.1)
                TactileEngine.shared.dimmerTick()
            case .decrement:
                brightness = max(0.15, brightness - 0.1)
                TactileEngine.shared.dimmerTick()
            default: break
            }
        }
    }

    // MARK: - Nursery Soundscape Deck

    private var soundscapeDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.amber.opacity(0.85))
                Text(soundscape.isPlaying ? L10n.t("声景混音 · 点 + 可叠一层", "Soundscapes · Tap + to layer") : L10n.t("舒缓声景", "Soothing Soundscapes"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.lampInk.opacity(0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                if let rem = soundscape.remainingSeconds {
                    Text(L10n.t("渐弱 ", "Fades ") + clock(Double(rem)))
                        .font(Typeface.numerals(12, relativeTo: .caption, weight: .semibold))
                        .foregroundStyle(Palette.amber.opacity(0.88))
                } else if soundscape.isPlaying {
                    Text(L10n.t("持续轻播", "Continuous"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.amber.opacity(0.75))
                } else {
                    Text(L10n.t("离线实时合成", "Offline DSP"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Palette.lampInk.opacity(0.45))
                }
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(SoundscapeKind.allCases) { kind in
                    let isPrimary = soundscape.active == kind
                    let isSecondary = soundscape.secondary == kind
                    let on = isPrimary || isSecondary
                    HStack(spacing: 6) {
                        Button {
                            TactileEngine.shared.beadClick()
                            withAnimation(reduce ? nil : .spring(response: 0.32, dampingFraction: 0.8)) {
                                soundscape.toggle(kind)
                            }
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: kind.symbol)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(on ? Color(hex: 0x261700) : Palette.amber.opacity(0.88))
                                    .frame(width: 28, height: 28)
                                    .background(
                                        Circle().fill(isPrimary ? Palette.amber : (isSecondary ? Palette.beadLight : Palette.amber.opacity(0.14)))
                                    )
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(kind.title)
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(on ? Palette.lampInk : Palette.lampInk.opacity(0.88))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                    Text(isSecondary ? L10n.t("已叠第二层", "Layer 2 on") : kind.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(on ? Palette.amber.opacity(0.92) : Palette.lampInk.opacity(0.52))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if soundscape.isPlaying && !isPrimary {
                            Button {
                                TactileEngine.shared.beadClick()
                                withAnimation(reduce ? nil : .spring(response: 0.28, dampingFraction: 0.8)) {
                                    soundscape.toggleLayer(kind)
                                }
                            } label: {
                                Image(systemName: isSecondary ? "checkmark" : "plus")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(isSecondary ? Color(hex: 0x261700) : Palette.amber.opacity(0.9))
                                    .frame(width: 22, height: 22)
                                    .background(Circle().fill(isSecondary ? Palette.beadLight : Palette.amber.opacity(0.18)))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(isSecondary ? L10n.t("移除叠层\(kind.title)", "Remove \(kind.title) layer") : L10n.t("叠加\(kind.title)", "Blend \(kind.title)"))
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                            .fill(isPrimary ? Palette.amber.opacity(0.22) : (isSecondary ? Palette.amber.opacity(0.14) : Color(hex: 0x161E3B).opacity(0.75)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                            .strokeBorder(
                                isPrimary ? Palette.amber.opacity(0.72) : (isSecondary ? Palette.beadLight.opacity(0.55) : Palette.amber.opacity(0.12)),
                                lineWidth: on ? 1.3 : 1.0
                            )
                    )
                    .accessibilityElement(children: .contain)
                }
            }

            if soundscape.isPlaying {
                VStack(spacing: 10) {
                    // Auto-fade timer pills
                    HStack(spacing: 6) {
                        ForEach(SoundscapeDuration.allCases) { d in
                            let sel = soundscape.duration == d
                            Button {
                                TactileEngine.shared.beadClick()
                                withAnimation(.snappy) { soundscape.duration = d }
                            } label: {
                                Text(d.label)
                                    .font(.caption.weight(sel ? .bold : .medium))
                                    .foregroundStyle(sel ? Color(hex: 0x241500) : Palette.lampInk.opacity(0.75))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule().fill(sel ? Palette.amber : Color(hex: 0x1B2547).opacity(0.8))
                                    )
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
                                    .fill(LinearGradient(colors: [Palette.lampTint, Palette.amber], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(6, thumbX), height: 6)
                                Circle()
                                    .fill(RadialGradient(colors: [Palette.beadLight, Palette.amber], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 11))
                                    .frame(width: 18, height: 18)
                                    .overlay(Circle().strokeBorder(Color(hex: 0x241500).opacity(0.45), lineWidth: 1))
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
                        .frame(height: 28)
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
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Color(hex: 0x121933).opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(Palette.amber.opacity(0.16), lineWidth: 1)
        )
    }

    // MARK: - Zero-Glare Bottom Care Dock

    @ViewBuilder
    private var careDock: some View {
        if let t = activeTimer {
            TimelineView(.periodic(from: .now, by: 1)) { tl in
                let now = tl.date.timeIntervalSince1970 * 1000
                let paused = t.pausedAt != nil
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: LogType.symbol(t.type))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Palette.amber)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Palette.amber.opacity(0.16)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.timerStatus(t.type, side: t.side, paused: paused))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.lampInk)
                            Text(clock(t.total(now)))
                                .font(Typeface.numerals(22, relativeTo: .title2, weight: .bold))
                                .foregroundStyle(Palette.amber)
                        }
                        Spacer(minLength: 4)

                        if t.type == LogType.nurse {
                            Button {
                                TactileEngine.shared.beadClick()
                                withAnimation(.snappy) { j.switchSide(t.type) }
                            } label: {
                                Label(t.side == "l" ? L10n.t("换右", "Right") : L10n.t("换左", "Left"), systemImage: "arrow.left.arrow.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Palette.lampInk)
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 38)
                                    .background(Capsule().fill(Color(hex: 0x222D54)))
                            }
                            .buttonStyle(.toy)
                        }

                        Button {
                            TactileEngine.shared.beadClick()
                            withAnimation(.snappy) { j.togglePause(t.type) }
                        } label: {
                            Image(systemName: paused ? "play.fill" : "pause.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Palette.lampInk)
                                .frame(width: 40, height: 38)
                                .background(Capsule().fill(Color(hex: 0x222D54)))
                        }
                        .buttonStyle(.toy)
                        .accessibilityLabel(paused ? L10n.t("继续计时", "Resume timer") : L10n.t("暂停计时", "Pause timer"))
                    }

                    Button {
                        TactileEngine.shared.goldChime()
                        withAnimation(.snappy) { j.stop(t.type) }
                    } label: {
                        Label(
                            t.type == LogType.sleep ? L10n.t("醒了，记下这次睡眠", "Awake — Save Sleep") : L10n.t("喂完了，记下这次亲喂", "Done — Save Feed"),
                            systemImage: "checkmark"
                        )
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Palette.lampInk)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(Palette.lampTint.opacity(0.86))
                        )
                    }
                    .buttonStyle(.toy)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .fill(Color(hex: 0x151D3B).opacity(0.84))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(Palette.amber.opacity(0.24), lineWidth: 1)
                )
            }
        } else {
            HStack(spacing: 10) {
                bedsideAction(
                    title: L10n.t("开始睡觉", "Start Sleep"),
                    detail: L10n.t("夜灯计时", "Night timer"),
                    symbol: LogType.symbol(LogType.sleep)
                ) {
                    guard app.mayKeep() else { return }
                    TactileEngine.shared.beadClick()
                    withAnimation(.snappy) { j.start(LogType.sleep, openFocus: false) }
                }

                bedsideAction(
                    title: L10n.t("开始亲喂", "Start Nursing"),
                    detail: suggestedSide == "l" ? L10n.t("建议左侧", "Left next") : L10n.t("建议右侧", "Right next"),
                    symbol: LogType.symbol(LogType.nurse)
                ) {
                    guard app.mayKeep() else { return }
                    TactileEngine.shared.beadClick()
                    withAnimation(.snappy) { j.start(LogType.nurse, side: suggestedSide, openFocus: false) }
                }
            }
        }
    }

    private func bedsideAction(title: String, detail: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.amber)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Palette.amber.opacity(0.15)))
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
                    .strokeBorder(Palette.amber.opacity(0.20), lineWidth: 1)
            )
        }
        .buttonStyle(.toy)
    }
}

/// Subtle warm dust specks rising gently inside Otto's lantern beam.
private struct LampDustCanvas: View {
    let brightness: Double
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24)) { tl in
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
                        with: .radialGradient(Gradient(colors: [Palette.amber.opacity(a * 0.45), .clear]), center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r * 3.5)
                    )
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                        with: .color(Color(hex: 0xFFEBC0).opacity(a))
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
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let g = data?.gravity else { return }
            // Low-pass smooth gravity tilt in [-1, 1]
            let targetRoll = max(-0.8, min(0.8, g.x))
            let targetPitch = max(-0.8, min(0.8, g.y + 0.55))
            self.roll += (targetRoll - self.roll) * 0.14
            self.pitch += (targetPitch - self.pitch) * 0.14
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        manager.stopDeviceMotionUpdates()
    }
}
