import SwiftUI

/// Pure timeline decomposition math bridging continuous storybook spine scrubbing to discrete steps and contact detents.
enum PlayScrubMath {
    static func decompose(timelinePosition: Double, stepCount: Int) -> (stepIndex: Int, localPhase: Double) {
        let count = max(1, stepCount)
        let clamped = min(Double(count), max(0.0, timelinePosition))
        if clamped >= Double(count) {
            return (count - 1, 1.0)
        }
        let stepIndex = min(count - 1, max(0, Int(floor(clamped))))
        let localPhase = min(1.0, max(0.0, clamped - Double(stepIndex)))
        return (stepIndex, localPhase)
    }

    static func normalizedProgress(stepIndex: Int, localPhase: Double, stepCount: Int) -> Double {
        let count = max(1, stepCount)
        let clampedStep = min(max(0, stepIndex), count - 1)
        let clampedPhase = min(1.0, max(0.0, localPhase))
        return min(1.0, max(0.0, (Double(clampedStep) + clampedPhase) / Double(count)))
    }

    static func crossedStepBoundary(from oldPos: Double, to newPos: Double, stepCount: Int) -> Int? {
        let oldStep = decompose(timelinePosition: oldPos, stepCount: stepCount).stepIndex
        let newStep = decompose(timelinePosition: newPos, stepCount: stepCount).stepIndex
        return oldStep != newStep ? newStep : nil
    }

    static func crossedContactDetent(from oldPhase: Double, to newPhase: Double) -> Bool {
        let contactPoint = 0.48
        return (oldPhase < contactPoint && newPhase >= contactPoint)
            || (oldPhase >= contactPoint && newPhase < contactPoint)
    }
}

/// One play, presented around a continuous scrubbable Montessori picture-book theater rather than repeated button-mashing:
/// - **Continuous Spine Scrubber**: Glide across every step notch with brass-detent CoreHaptics at step boundaries & `0.48` contact peaks,
///   or tap `连播全步 / Play Story` for hands-free storytelling across steps, and tap `完成并盖印 / Done & Stamp` from any moment.
/// - **Mat-Side Co-Play Focus Mode** (`MatSideCoPlayView`): 1-tap full-screen distraction-free card designed to rest
///   beside the baby's play mat with continuous spine scrubbing, swipe gestures, thumb-sized controls, and screen-awake lock.
/// - **Authoritative Prep & Safety Drawers**: `prepare`, `safety`, `observe`, and `pause` remain intact and clear.
struct PlayView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.accessibilityReduceMotion) private var reduce

    let play: Play
    let month: Int
    var initialMatMode: Bool = false
    var initialStep: Int = 0

    @State private var scrolled = false
    @State private var cheer = 0
    @State private var open: Int
    @State private var scrubPhase: Double? = nil
    @State private var isAutoPlaying = false
    @State private var autoPlayTask: Task<Void, Never>? = nil

    init(play: Play, month: Int, initialMatMode: Bool = false, initialStep: Int = 0) {
        self.play = play
        self.month = month
        self.initialMatMode = initialMatMode
        self.initialStep = initialStep
        _open = State(initialValue: min(max(0, initialStep), play.steps.count))
    }
    @State private var before = false
    /// What to watch for and when to stop is safety: open from the start, not folded away.
    @State private var during = true
    @State private var matMode = false
    /// The count when the page was opened: a count above it means this visit already recorded a time (by 记一次,
    /// the menu, or the last step) — derived from the records, not kept beside them.
    @State private var base: Int?

    var body: some View {
        let dark = lamp || scheme == .dark
        let rec = app.record(play, j)

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PlayHeader(play: play, record: rec, cheer: cheer, onLog: { record() }, onMatMode: { openMatMode() })
                        .onScrollVisibilityChange(threshold: 0.2) { v in
                            withAnimation(.easeOut(duration: 0.2)) { scrolled = !v }
                        }

                    // 1. Unified Continuous Scrubbable Picture-Book Theater or Completion Keepsake
                    if open < play.steps.count {
                        PlayLivingHeroCard(
                            play: play,
                            stepIndex: open,
                            stepText: play.steps[open],
                            companion: app.companion,
                            dark: dark,
                            scrubPhase: $scrubPhase,
                            isAutoPlaying: isAutoPlaying,
                            onToggleAutoPlay: { toggleAutoPlay(proxy) },
                            onComplete: { completeAndScroll(proxy) },
                            onPrev: open > 0 ? { manualJump(open - 1, proxy) } : nil,
                            onNext: { manualJump(open + 1, proxy) },
                            onJump: { manualJump($0, proxy, scroll: false) }
                        )
                        .id("stage")
                    } else {
                        FinishedCard(
                            play: play,
                            companion: app.companion,
                            count: rec.count,
                            cheer: cheer,
                            dark: dark,
                            onReplay: { manualJump(0, proxy) }
                        )
                        .transition(reduce ? .opacity : .scale(scale: 0.94).combined(with: .opacity))
                        .id("finished")

                        if play.steps.count > 1 {
                            StorybookSpineScrubber(
                                total: play.steps.count,
                                current: open,
                                scrubPhase: $scrubPhase,
                                dark: dark
                            ) { manualJump($0, proxy) }
                        }
                    }

                    // 3. Prep & Safety Drawer (folded only after first play unless opened)
                    if !play.prepare.isEmpty || !play.safety.isEmpty {
                        Fold(
                            title: L10n.t("开始之前", "Before You Start"),
                            summary: [play.prepare.isEmpty ? nil : L10n.t("准备", "Prepare"), play.safety.isEmpty ? nil : L10n.t("安全", "Safety")].compactMap { $0 }.joined(separator: " · "),
                            symbol: "tray.full.fill",
                            color: Crayon.caramel,
                            open: $before
                        ) {
                            if !play.prepare.isEmpty {
                                BoxRow(symbol: "tray.full.fill", color: Crayon.caramel, title: L10n.t("准备", "Prepare"), text: play.prepare, last: play.safety.isEmpty)
                            }
                            if !play.safety.isEmpty {
                                BoxRow(symbol: "exclamationmark.triangle.fill", color: Crayon.tangerine, title: L10n.t("安全", "Safety"), text: play.safety, last: true)
                            }
                        }
                    }

                    // 4. Clean Scannable Steps Outline (1-tap jump, zero duplicate mini-stage overdraw)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t("共玩步骤", "Play Rhythm"))
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Palette.secondaryText)
                            .padding(.horizontal, 4)

                        VStack(spacing: 8) {
                            ForEach(Array(play.steps.enumerated()), id: \.offset) { i, s in
                                CompactStepOutlineRow(
                                    n: i + 1,
                                    text: s,
                                    active: i == open,
                                    done: i < open,
                                    dark: dark
                                ) {
                                    manualJump(i, proxy)
                                }
                                .id(i)
                            }
                        }
                    }

                    // 5. While Playing Guidance & Stop Signals (safety-first: expanded by default)
                    if !play.observe.isEmpty || !play.pause.isEmpty {
                        Fold(
                            title: L10n.t("做的时候", "While Playing"),
                            summary: [play.observe.isEmpty ? nil : L10n.t("看什么", "Observe"), play.pause.isEmpty ? nil : L10n.t("停下来", "Pause")].compactMap { $0 }.joined(separator: " · "),
                            symbol: "eye.fill",
                            color: Crayon.sky,
                            open: $during
                        ) {
                            if !play.observe.isEmpty {
                                BoxRow(symbol: "eye.fill", color: Crayon.sky, title: L10n.t("看什么", "Observe"), text: play.observe, last: play.pause.isEmpty)
                            }
                            if !play.pause.isEmpty {
                                BoxRow(symbol: "hand.raised.fill", color: Crayon.lilac, title: L10n.t("停下来", "When to Pause"), text: play.pause, last: true)
                            }
                        }
                        .id("during")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .calmWhileScrolling()
        .pageBackground(tone: Palette.area(Palette.areaKey(of: play)))
        .sensoryFeedback(.success, trigger: cheer)
        .sensoryFeedback(.selection, trigger: open)
        .onAppear {
            if let p = app.playing, p.play.code == play.code { open = p.step }
            before = rec.count == 0
            if base == nil { base = j.plays(play.code).count }
            if initialMatMode { matMode = true }
            keepAwake(open < play.steps.count || matMode)
        }
        .onDisappear {
            stopAutoPlay()
            keepAwake(false)
        }
        .onChange(of: open) { _, o in keepAwake(o < play.steps.count || matMode) }
        .onChange(of: matMode) { _, active in
            if active { stopAutoPlay() }
            keepAwake(active || open < play.steps.count)
        }
        .onChange(of: scrubPhase) { _, phase in
            if phase != nil { stopAutoPlay() }
        }
        // A time taken back (撤销): the finished card goes and the last step opens again, to be finished anew
        .onChange(of: j.plays(play.code).count) { old, new in countChanged(old, new) }
        .navigationTitle(play.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(play.name)
                    .font(.headline)
                    .lineLimit(1)
                    .opacity(scrolled ? 1 : 0)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    PlayActions(play: play, month: month, inPage: true)
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel(L10n.t("更多", "More"))
            }
        }
        .fullScreenCover(isPresented: $matMode) {
            MatSideCoPlayView(
                play: play,
                month: month,
                companion: app.companion,
                currentStep: $open,
                cheerCount: rec.count,
                cheerTrigger: cheer,
                onSelectStep: { step in
                    if step >= play.steps.count {
                        completeSessionFromAnyMode()
                    } else {
                        TactileEngine.shared.beadClick()
                        withAnimation(reduce ? nil : .snappy) { open = step }
                        app.play(play, month: month, at: step)
                    }
                }
            )
            .lampPresented()
        }
    }

    private func openMatMode() {
        TactileEngine.shared.beadClick()
        if open >= play.steps.count {
            open = 0
        }
        matMode = true
    }

    private func record() {
        guard app.mayKeep() else { return }
        withAnimation(.snappy) {
            if app.didPlay(play, month: month, j) {
                app.finishPlaying()
                TactileEngine.shared.goldChime()
                cheer += 1
            }
        }
    }

    /// Whether this visit has recorded a time (the count is above what it was when the page opened).
    private var recordedHere: Bool { j.plays(play.code).count > (base ?? Int.max) }
    private func keepAwake(_ on: Bool) { UIApplication.shared.isIdleTimerDisabled = on }

    private func countChanged(_ old: Int, _ new: Int) {
        guard new < old else { return }
        base = min(base ?? Int.max, j.plays(play.code).count)
        if open >= play.steps.count {
            withAnimation(.snappy) { open = max(0, play.steps.count - 1) }
        }
    }

    private func completeSessionFromAnyMode() {
        stopAutoPlay()
        if recordedHere {
            TactileEngine.shared.goldChime()
            cheer += 1
        } else if app.mayKeep(), app.didPlay(play, month: month, j) {
            app.finishPlaying()
            TactileEngine.shared.goldChime()
            cheer += 1
        } else {
            return
        }
        withAnimation(reduce ? nil : .snappy) {
            open = play.steps.count
        }
    }

    private func completeAndScroll(_ proxy: ScrollViewProxy) {
        scrubPhase = nil
        completeSessionFromAnyMode()
        withAnimation(.smooth.delay(0.15)) {
            proxy.scrollTo("finished", anchor: .center)
        }
    }

    private func stepDuration(at idx: Int) -> Double {
        if let meta = BespokeActivitySceneRegistry.metadata(for: play.code), idx < meta.durations.count {
            return meta.durations[idx]
        }
        if let script = LivingBookCatalog.script(for: play.code), idx < script.steps.count {
            return script.steps[idx].duration
        }
        return 4.2
    }

    private func stopAutoPlay() {
        autoPlayTask?.cancel()
        autoPlayTask = nil
        if isAutoPlaying { isAutoPlaying = false }
    }

    private func toggleAutoPlay(_ proxy: ScrollViewProxy) {
        if isAutoPlaying {
            TactileEngine.shared.beadClick()
            stopAutoPlay()
            return
        }
        guard !reduce else {
            manualJump(min(play.steps.count - 1, open + 1), proxy)
            return
        }
        TactileEngine.shared.beadClick()
        scrubPhase = nil
        if open >= play.steps.count {
            open = 0
            app.play(play, month: month, at: 0)
        }
        isAutoPlaying = true
        autoPlayTask = Task { @MainActor in
            while isAutoPlaying && !Task.isCancelled && open < play.steps.count - 1 {
                let dur = stepDuration(at: open)
                try? await Task.sleep(for: .milliseconds(Int(dur * 1000)))
                guard isAutoPlaying && !Task.isCancelled && scrubPhase == nil else { break }
                let next = min(play.steps.count - 1, open + 1)
                TactileEngine.shared.pageTurn()
                withAnimation(.snappy) { open = next }
                app.play(play, month: month, at: next)
            }
            if isAutoPlaying && !Task.isCancelled && open == play.steps.count - 1 {
                let lastDur = stepDuration(at: open)
                try? await Task.sleep(for: .milliseconds(Int(lastDur * 1000)))
            }
            isAutoPlaying = false
            autoPlayTask = nil
        }
    }

    private func manualJump(_ i: Int, _ proxy: ScrollViewProxy, scroll: Bool = true) {
        stopAutoPlay()
        go(i, proxy, scroll: scroll)
    }

    private func go(_ i: Int, _ proxy: ScrollViewProxy, scroll: Bool = true) {
        if i >= play.steps.count {
            completeAndScroll(proxy)
            return
        }
        TactileEngine.shared.beadClick()
        withAnimation(reduce ? nil : .snappy) { open = i }
        app.play(play, month: month, at: i)
        if scroll {
            withAnimation(.smooth.delay(0.12)) {
                proxy.scrollTo("stage", anchor: .top)
            }
        }
    }
}

// MARK: - Hero Living Stage Card

private struct PlayLivingHeroCard: View {
    let play: Play
    let stepIndex: Int
    let stepText: String
    let companion: Kind
    let dark: Bool
    @Binding var scrubPhase: Double?
    let isAutoPlaying: Bool
    let onToggleAutoPlay: () -> Void
    let onComplete: () -> Void
    let onPrev: (() -> Void)?
    let onNext: () -> Void
    let onJump: (Int) -> Void

    @State private var replayTrigger = 0
    @Environment(\.dynamicTypeSize) private var type

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ActivityMotionStage(
                play: play,
                stepIndex: stepIndex,
                stepCount: play.steps.count,
                stepText: stepText,
                companion: companion,
                compact: false,
                dark: dark,
                replayTrigger: replayTrigger,
                scrubPhase: scrubPhase,
                showOverlays: false
            )
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .gesture(
                DragGesture(minimumDistance: 42)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) * 1.25 else { return }
                        if value.translation.width < -52 {
                            TactileEngine.shared.pageTurn()
                            onNext()
                        } else if value.translation.width > 52, let onPrev {
                            TactileEngine.shared.pageTurn()
                            onPrev()
                        }
                    }
            )

            StorybookSpineScrubber(
                total: play.steps.count,
                current: stepIndex,
                scrubPhase: $scrubPhase,
                inline: true,
                dark: dark,
                onReplay: {
                    TactileEngine.shared.beadClick()
                    replayTrigger += 1
                },
                pick: onJump
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 11) {
                    StepCircleBadge(number: stepIndex + 1, done: false)
                    Text(stepText)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Group {
                    if type.isAccessibilitySize {
                        VStack(spacing: 8) {
                            completeButton(fullWidth: true)
                            autoPlayButton(fullWidth: true)
                        }
                    } else {
                        HStack(spacing: 8) {
                            autoPlayButton(fullWidth: false)
                            Spacer(minLength: 4)
                            completeButton(fullWidth: false)
                        }
                    }
                }
            }
            .padding(16)
        }
        .printCard(radius: Radius.card)
    }

    private func autoPlayButton(fullWidth: Bool) -> some View {
        Button(action: onToggleAutoPlay) {
            Label(
                isAutoPlaying ? L10n.t("暂停连播", "Pause Story") : L10n.t("连播全步", "Play Story"),
                systemImage: isAutoPlaying ? "pause.fill" : "play.fill"
            )
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonStyle(.vinyl(Crayon.caramel))
        .accessibilityLabel(isAutoPlaying ? L10n.t("暂停连播全步动画", "Pause story playback") : L10n.t("连播全部步骤动画", "Play all steps continuously"))
    }

    private func completeButton(fullWidth: Bool) -> some View {
        Button(action: onComplete) {
            Label(L10n.t("完成并盖印", "Done & Stamp"), systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 4)
                .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .buttonStyle(.vinyl(Palette.accentFill, prominent: true))
    }
}

// MARK: - Clean Scannable Step Outline Row

private struct CompactStepOutlineRow: View {
    let n: Int
    let text: String
    let active: Bool
    let done: Bool
    let dark: Bool
    let tap: () -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: 12) {
                StepCircleBadge(number: n, done: done)

                VStack(alignment: .leading, spacing: 2) {
                    if active {
                        Text(L10n.t("正在看这一步", "Current Step"))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Palette.accent)
                    }
                    Text(text)
                        .font(.subheadline.weight(active ? .semibold : .medium))
                        .foregroundStyle(done ? Palette.secondaryText : .primary)
                        .lineLimit(active ? 3 : 2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: active ? "play.circle.fill" : "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(active ? Palette.accent : Palette.secondaryText.opacity(0.45))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.toy)
        .background(
            RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                .fill(active ? Palette.accent.opacity(dark ? 0.16 : 0.08) : (dark ? Palette.lampCard : Palette.card))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                .strokeBorder(active ? Palette.accent.opacity(0.45) : Palette.outline.opacity(0.20), lineWidth: active ? 1.3 : 0.75)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.t("第 \(n) 步，\(text)", "Step \(n), \(text)"))
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
    }
}

private struct StepCircleBadge: View {
    let number: Int
    let done: Bool

    var body: some View {
        ZStack {
            if done {
                Circle()
                    .fill(RadialGradient(colors: [Palette.beadLight, Palette.bead], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 16))
                Image(systemName: "checkmark")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Color(hex: 0x5A3D00))
            } else {
                Circle().fill(Palette.accentFill)
                Text("\(number)")
                    .font(Typeface.numerals(14, relativeTo: .headline, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 28, height: 28)
    }
}

// MARK: - Distraction-Free 1-Tap Mat-Side Co-Play Focus Mode

/// Dedicated calm full-screen card meant to rest beside the play mat: oversized controls, horizontal swipe navigation,
/// 1-tap Safety whisper sheet, interactive Montessori motion stage, and golden bead completion cheer.
struct MatSideCoPlayView: View {
    let play: Play
    let month: Int
    let companion: Kind
    @Binding var currentStep: Int
    var cheerCount: Int = 0
    var cheerTrigger: Int = 0
    let onSelectStep: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.accessibilityReduceMotion) private var reduce

    @State private var showSafetySheet = false
    @State private var scrubPhase: Double? = nil
    @State private var isAutoPlaying = false
    @State private var autoPlayTask: Task<Void, Never>? = nil

    private var hasGuidance: Bool {
        !play.prepare.isEmpty || !play.safety.isEmpty || !play.observe.isEmpty || !play.pause.isEmpty
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        let areaKey = Palette.areaKey(of: play)
        let areaColor = Palette.area(areaKey)
        let total = max(1, play.steps.count)
        let finished = currentStep >= play.steps.count

        VStack(spacing: 14) {
            // Top bar
            HStack(spacing: 10) {
                Button {
                    TactileEngine.shared.beadClick()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(dark ? Palette.lampCard : Palette.card))
                        .overlay(Circle().strokeBorder(Palette.outline.opacity(0.28), lineWidth: 0.75))
                }
                .buttonStyle(.toy)
                .accessibilityLabel(L10n.t("退出垫旁共玩", "Close Mat Mode"))

                VStack(alignment: .leading, spacing: 1) {
                    Text(play.name)
                        .font(.subheadline.weight(.bold))
                        .lineLimit(1)
                    Text(finished ? L10n.t("垫旁共玩 · 全部完成", "Mat Mode · All Done") : L10n.t("垫旁共玩 · 第 \(currentStep + 1) / \(total) 步", "Mat Mode · Step \(currentStep + 1) of \(total)"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.secondaryText)
                }

                Spacer(minLength: 4)

                if play.steps.count > 1 {
                    Button {
                        toggleMatAutoPlay()
                    } label: {
                        Image(systemName: isAutoPlaying ? "pause.fill" : "play.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(dark ? Palette.lampCard : Palette.card))
                            .overlay(Circle().strokeBorder(Palette.outline.opacity(0.28), lineWidth: 0.75))
                    }
                    .buttonStyle(.toy)
                    .accessibilityLabel(isAutoPlaying ? L10n.t("暂停连播", "Pause story") : L10n.t("连播全步", "Play story"))
                }

                if hasGuidance {
                    Button {
                        TactileEngine.shared.beadClick()
                        showSafetySheet = true
                    } label: {
                        Label(L10n.t("安全看护", "Safety"), systemImage: "exclamationmark.shield.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(dark ? Crayon.tangerine : Crayon.ink(Crayon.tangerine))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Crayon.tangerine.opacity(dark ? 0.24 : 0.16)))
                    }
                    .buttonStyle(.toy)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            StorybookSpineScrubber(
                total: play.steps.count,
                current: currentStep,
                scrubPhase: $scrubPhase,
                dark: dark
            ) { idx in
                stopMatAutoPlay()
                onSelectStep(idx)
            }
            .padding(.horizontal, 16)
            .onChange(of: scrubPhase) { _, p in
                if p != nil { stopMatAutoPlay() }
            }
            .onDisappear {
                stopMatAutoPlay()
            }

            ScrollView {
                VStack(spacing: 18) {
                    if finished {
                        FinishedCard(
                            play: play,
                            companion: companion,
                            count: max(1, cheerCount),
                            cheer: cheerTrigger,
                            dark: dark,
                            onReplay: { onSelectStep(0) }
                        )
                        .padding(.top, 12)
                    } else {
                        ActivityMotionStage(
                            play: play,
                            stepIndex: currentStep,
                            stepCount: play.steps.count,
                            stepText: play.steps[currentStep],
                            companion: companion,
                            compact: false,
                            dark: dark,
                            scrubPhase: scrubPhase,
                            showOverlays: false
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                StepCircleBadge(number: currentStep + 1, done: false)
                                Text(L10n.t("这一步这样做", "In This Moment"))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Palette.areaInk(areaKey))
                                Spacer(minLength: 0)
                            }

                            Text(play.steps[currentStep])
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .printCard(radius: Radius.card)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .gesture(
                DragGesture(minimumDistance: 36)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
                        if value.translation.width < -52, currentStep < play.steps.count {
                            onSelectStep(currentStep + 1)
                        } else if value.translation.width > 52, currentStep > 0 {
                            onSelectStep(currentStep - 1)
                        }
                    }
            )

            // Oversized one-handed thumb dock at the bottom
            HStack(spacing: 12) {
                if finished {
                    Button {
                        TactileEngine.shared.beadClick()
                        dismiss()
                    } label: {
                        Label(L10n.t("回到活动页", "Done"), systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.vinyl(Palette.accentFill, prominent: true, large: true))
                } else {
                    if currentStep > 0 {
                        Button {
                            onSelectStep(currentStep - 1)
                        } label: {
                            Label(L10n.t("上一步", "Back"), systemImage: "chevron.left")
                        }
                        .buttonStyle(.vinyl(Crayon.caramel, large: true))
                    }

                    let isLast = currentStep == play.steps.count - 1
                    Button {
                        onSelectStep(currentStep + 1)
                    } label: {
                        Label(
                            isLast ? L10n.t("玩完啦 · 记一次", "All Done · Log Play") : L10n.t("下一步", "Next Step"),
                            systemImage: isLast ? "checkmark.circle.fill" : "arrow.right"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.vinyl(Palette.accentFill, prominent: true, large: true))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .pageBackground(tone: areaColor)
        .sheet(isPresented: $showSafetySheet) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 0) {
                        if !play.safety.isEmpty {
                            BoxRow(symbol: "exclamationmark.triangle.fill", color: Crayon.tangerine, title: L10n.t("安全", "Safety"), text: play.safety, last: play.prepare.isEmpty && play.observe.isEmpty && play.pause.isEmpty)
                        }
                        if !play.prepare.isEmpty {
                            BoxRow(symbol: "tray.full.fill", color: Crayon.caramel, title: L10n.t("准备", "Prepare"), text: play.prepare, last: play.observe.isEmpty && play.pause.isEmpty)
                        }
                        if !play.observe.isEmpty {
                            BoxRow(symbol: "eye.fill", color: Crayon.sky, title: L10n.t("看什么", "Observe"), text: play.observe, last: play.pause.isEmpty)
                        }
                        if !play.pause.isEmpty {
                            BoxRow(symbol: "hand.raised.fill", color: Crayon.lilac, title: L10n.t("停下来", "When to Pause"), text: play.pause, last: true)
                        }
                    }
                    .printCard(radius: Radius.card)
                    .padding(16)
                }
                .pageBackground(tone: Crayon.tangerine)
                .navigationTitle(L10n.t("准备与安全观察", "Safety & Observation"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.t("好", "OK")) { showSafetySheet = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .lampPresented(sheet: true)
        }
    }

    private func matStepDuration(at idx: Int) -> Double {
        if let meta = BespokeActivitySceneRegistry.metadata(for: play.code), idx < meta.durations.count {
            return meta.durations[idx]
        }
        if let script = LivingBookCatalog.script(for: play.code), idx < script.steps.count {
            return script.steps[idx].duration
        }
        return 4.2
    }

    private func stopMatAutoPlay() {
        autoPlayTask?.cancel()
        autoPlayTask = nil
        if isAutoPlaying { isAutoPlaying = false }
    }

    private func toggleMatAutoPlay() {
        if isAutoPlaying {
            TactileEngine.shared.beadClick()
            stopMatAutoPlay()
            return
        }
        guard !reduce else {
            onSelectStep(min(play.steps.count - 1, currentStep + 1))
            return
        }
        TactileEngine.shared.beadClick()
        scrubPhase = nil
        if currentStep >= play.steps.count {
            onSelectStep(0)
        }
        isAutoPlaying = true
        autoPlayTask = Task { @MainActor in
            while isAutoPlaying && !Task.isCancelled && currentStep < play.steps.count - 1 {
                let dur = matStepDuration(at: currentStep)
                try? await Task.sleep(for: .milliseconds(Int(dur * 1000)))
                guard isAutoPlaying && !Task.isCancelled && scrubPhase == nil else { break }
                onSelectStep(min(play.steps.count - 1, currentStep + 1))
            }
            if isAutoPlaying && !Task.isCancelled && currentStep == play.steps.count - 1 {
                let lastDur = matStepDuration(at: currentStep)
                try? await Task.sleep(for: .milliseconds(Int(lastDur * 1000)))
            }
            isAutoPlaying = false
            autoPlayTask = nil
        }
    }
}

// MARK: - Shared Supporting Building Blocks (Kept Intact)

/// A folded section: one line (sticker, title, what is inside) that opens smoothly in place.
struct Fold<Content: View>: View {
    let title: String
    let summary: String
    let symbol: String
    let color: Color
    @Binding var open: Bool
    @ViewBuilder let content: Content
    @Environment(\.dynamicTypeSize) private var type

    var body: some View {
        CalmAccordion(isExpanded: $open, spacing: 0, showDivider: true, dividerHorizontalPadding: 16) { isOpen in
            HStack(spacing: 12) {
                IconTile(symbol: symbol, color: color, size: 30)
                if type.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.headline).foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        if !summary.isEmpty {
                            Text(summary).font(.subheadline).foregroundStyle(Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(summary).font(.subheadline).foregroundStyle(Palette.secondaryText).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").font(.footnote.weight(.bold)).foregroundStyle(Palette.secondaryText)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        } content: {
            VStack(spacing: 0) { content }
        }
        .printCard(radius: Radius.card)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

/// Continuous Montessori wooden spine scrubber: glide freely across step notches and `0.48` contact detents with CoreHaptics.
private struct StorybookSpineScrubber: View {
    let total: Int
    let current: Int
    @Binding var scrubPhase: Double?
    var inline: Bool = false
    var dark: Bool = false
    var onReplay: (() -> Void)? = nil
    let pick: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var isScrubbing = false
    @State private var lastTimelinePos: Double? = nil

    var body: some View {
        let count = max(1, total)
        let isFinished = current >= count
        let activeStep = min(max(0, current), count - 1)
        let visualLocalPhase = isFinished ? 1.0 : (scrubPhase ?? 0.5)
        let progress = isFinished ? 1.0 : PlayScrubMath.normalizedProgress(
            stepIndex: activeStep,
            localPhase: visualLocalPhase,
            stepCount: count
        )
        let label = isFinished
            ? L10n.t("全部 \(count) 步已完成", "All \(count) steps done")
            : L10n.t("第 \(activeStep + 1) 步，共 \(count) 步", "Step \(activeStep + 1) of \(count)")

        let container = VStack(spacing: 6) {
            GeometryReader { geo in
                let trackW = max(1, geo.size.width)
                let thumbX = min(max(10, trackW * CGFloat(progress)), max(10, trackW - 10))

                ZStack(alignment: .leading) {
                    // Recessed beechwood groove
                    Capsule()
                        .fill(dark ? Color.white.opacity(0.10) : Crayon.caramel.opacity(0.18))
                        .frame(height: 10)
                        .overlay(
                            Capsule()
                                .strokeBorder(Palette.outline.opacity(dark ? 0.25 : 0.20), lineWidth: 0.75)
                        )

                    // Active fill progress
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.bead, Palette.accentFill], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(12, thumbX), height: 10)

                    // Discrete step notch markers anchored at each step center
                    ForEach(0..<count, id: \.self) { i in
                        let notchPos = CGFloat((Double(i) + 0.5) / Double(count)) * trackW
                        Group {
                            if i < current {
                                GoldBead(size: 11)
                            } else if i == current {
                                Circle().fill(Color.white.opacity(0.85)).frame(width: 6, height: 6)
                            } else {
                                Circle().fill(Palette.stone.opacity(dark ? 0.65 : 0.85)).frame(width: 7, height: 7)
                            }
                        }
                        .position(x: notchPos, y: geo.size.height * 0.5)
                    }

                    // Continuous tactile brass/accent thumb bead
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Palette.beadLight, isScrubbing ? Palette.bead : Palette.accentFill],
                                center: UnitPoint(x: 0.34, y: 0.30),
                                startRadius: 0,
                                endRadius: 12
                            )
                        )
                        .frame(width: 20, height: 20)
                        .overlay(Circle().strokeBorder(.white.opacity(dark ? 0.45 : 0.82), lineWidth: 1.5))
                        .shadow(color: Palette.accent.opacity(isScrubbing ? 0.36 : 0.20), radius: isScrubbing ? 6 : 3, y: 1.5)
                        .scaleEffect(isScrubbing && !reduce ? 1.18 : 1.0)
                        .position(x: thumbX, y: geo.size.height * 0.5)
                }
                .frame(height: 44)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let u = min(0.9999, max(0.0, Double(value.location.x / trackW)))
                            let newTimelinePos = u * Double(count)
                            let decomp = PlayScrubMath.decompose(timelinePosition: newTimelinePos, stepCount: count)

                            if !isScrubbing {
                                isScrubbing = true
                            }
                            if let oldPos = lastTimelinePos {
                                if let newStep = PlayScrubMath.crossedStepBoundary(from: oldPos, to: newTimelinePos, stepCount: count) {
                                    TactileEngine.shared.beadClick()
                                    pick(newStep)
                                } else {
                                    let oldLocal = PlayScrubMath.decompose(timelinePosition: oldPos, stepCount: count).localPhase
                                    if PlayScrubMath.crossedContactDetent(from: oldLocal, to: decomp.localPhase) {
                                        TactileEngine.shared.dimmerTick()
                                    }
                                }
                            } else {
                                if decomp.stepIndex != current {
                                    TactileEngine.shared.beadClick()
                                    pick(decomp.stepIndex)
                                } else {
                                    TactileEngine.shared.dimmerTick()
                                }
                            }
                            lastTimelinePos = newTimelinePos
                            scrubPhase = decomp.localPhase
                        }
                        .onEnded { _ in
                            isScrubbing = false
                            lastTimelinePos = nil
                            scrubPhase = nil
                        }
                )
            }
            .frame(height: 44)

            HStack(spacing: 8) {
                Text(isFinished ? L10n.t("全部完成", "All Done") : L10n.t("第 \(activeStep + 1) / \(count) 步", "Step \(activeStep + 1) / \(count)"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(activeStep + 1)))

                Text("·")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.secondaryText)

                Text(isScrubbing
                     ? L10n.t("正在细调动作定格", "Scrubbing moment")
                     : L10n.t("轻滑木珠控帧", "Slide rail to scrub"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isScrubbing ? Palette.accent : Palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                if let onReplay {
                    Button(action: onReplay) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(dark ? Palette.amber : Crayon.ink(Crayon.caramel))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Crayon.caramel.opacity(dark ? 0.24 : 0.14)))
                            .overlay(Circle().strokeBorder(Crayon.caramel.opacity(dark ? 0.36 : 0.28), lineWidth: 0.75))
                            .contentShape(Circle().inset(by: -6))
                    }
                    .buttonStyle(.toy)
                    .accessibilityLabel(L10n.t("重播这一步示范动画", "Replay this step animation"))
                }
            }
        }
        .padding(.horizontal, inline ? 4 : 14)
        .padding(.vertical, inline ? 2 : 6)

        Group {
            if inline {
                container
            } else {
                container.printCard(radius: Radius.inner)
            }
        }
        .animation(reduce ? nil : .spring(response: 0.28, dampingFraction: 0.80), value: isScrubbing)
        .animation(reduce ? nil : .spring(response: 0.34, dampingFraction: 0.78), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t("绘本步骤控制轨", "Storybook step scrubber"))
        .accessibilityValue(label)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                let next = min(count - 1, activeStep + 1)
                if next != current { pick(next) }
            case .decrement:
                let prev = max(0, activeStep - 1)
                if prev != current { pick(prev) }
            @unknown default: break
            }
        }
    }
}

/// How many times, as beads on a string — one gold bead per time, up to five — the count, and when last.
struct DoneCount: View {
    let record: PlayRecord
    var cheer = 0
    @Environment(\.lamp) private var lamp
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = lamp || scheme == .dark
        HStack(spacing: 10) {
            HStack(spacing: -3) {
                ForEach(0..<max(1, min(record.count, 5)), id: \.self) { _ in
                    if record.count == 0 {
                        Circle()
                            .fill(dark ? Color.white.opacity(0.08) : Color(hex: 0xEDE4D3))
                            .overlay(
                                Circle()
                                    .strokeBorder(dark ? Color.white.opacity(0.32) : Crayon.caramel.opacity(0.55), lineWidth: 1.4)
                            )
                            .frame(width: 16, height: 16)
                    } else {
                        Circle()
                            .fill(RadialGradient(colors: [Palette.beadLight, Palette.bead, Color(hex: 0x9C6F08)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 11))
                            .frame(width: 16, height: 16)
                            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                    }
                }
            }
            .phaseAnimator([1.0, 1.25, 1.0], trigger: cheer) { v, s in v.scaleEffect(s) }
            VStack(alignment: .leading, spacing: 1) {
                if record.count == 0 {
                    Text(L10n.t("还没玩过", "Not played yet")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                } else {
                    HStack(spacing: 0) {
                        Text(L10n.t("玩过 ", "Played "))
                        Ticking(text: "\(record.count)", tint: Palette.bead)
                        Text(L10n.t(" 次", record.count == 1 ? " time" : " times"))
                    }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary).fixedSize()
                    if let last = record.last {
                        Text(L10n.t("上次 \(Day(last).md)", "Last \(Day(last).m)/\(Day(last).d)")).font(.caption).foregroundStyle(Palette.secondaryText)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Golden and rainbow beads that fly up out of a button and fall away, once each time `trigger` changes.
struct BeadBurst: View {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduce
    private static let beads: [(dx: Double, up: Double, r: Double, c: Color)] = [
        (-120, 150, 7, Palette.bead), (-80, 190, 6, Crayon.teal), (-40, 210, 8, Palette.bead), (0, 230, 6, Crayon.pink),
        (40, 205, 7, Palette.bead), (80, 185, 6, Crayon.sunflower), (120, 150, 8, Crayon.cherry), (-100, 120, 5, Crayon.sky), (100, 125, 5, Palette.bead)]
    var body: some View {
        if reduce { EmptyView() } else {
            Color.clear
                .overlay {
                    KeyframeAnimator(initialValue: 0.0, trigger: trigger) { t in
                        ZStack {
                            ForEach(Array(Self.beads.enumerated()), id: \.offset) { _, b in
                                let y = -b.up * (2 * t - t * t * 1.4)
                                Circle().fill(b.c).frame(width: b.r * 2, height: b.r * 2)
                                    .offset(x: b.dx * t, y: y)
                                    .opacity(t <= 0 || t >= 1 ? 0 : 1 - max(0, t - 0.7) / 0.3)
                            }
                        }
                    } keyframes: { _ in
                        LinearKeyframe(0.0, duration: 0.0)
                        LinearKeyframe(1.0, duration: 1.1)
                        LinearKeyframe(0.0, duration: 0.0)
                    }
                }
                .allowsHitTesting(false)
        }
    }
}

/// The play's head: its area and age, its name, how many times, and 记一次 + 垫旁共玩.
private struct PlayHeader: View {
    let play: Play
    let record: PlayRecord
    let cheer: Int
    let onLog: () -> Void
    let onMatMode: () -> Void

    var body: some View {
        let key: String = Palette.areaKey(of: play)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                IconTile(symbol: Palette.areaSymbol(key), color: Palette.area(key), size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(play.domains.joined(separator: L10n.isEnglish ? " · " : "、"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.areaInk(key))
                    Text(play.age)
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Button(action: onMatMode) {
                    Label(L10n.t("垫旁共玩", "Mat Mode"), systemImage: "rectangle.inset.filled.and.person.filled")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.areaInk(key))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Palette.area(key).opacity(0.16)))
                }
                .buttonStyle(.toy)
                .accessibilityLabel(L10n.t("进入垫旁共玩全屏卡片", "Enter distraction-free Mat Mode"))
            }

            Text(play.name)
                .font(.largeTitle.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                DoneCount(record: record, cheer: cheer)
                Spacer(minLength: 8)
                Button(action: onLog) {
                    Label(L10n.t("记一次", "Log Play"), systemImage: "plus")
                }
                .buttonStyle(.vinyl)
                .overlay { BeadBurst(trigger: cheer) }
                .accessibilityLabel(L10n.t("玩过了，记一次", "Log one play session"))
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 6)
    }
}

/// The steps finished: a Kid's Book Gold-Bead Stamp Keepsake Card with the final step miniature, wax seal, and cheering Duo.
private struct FinishedCard: View {
    let play: Play
    let companion: Kind
    let count: Int
    let cheer: Int
    let dark: Bool
    var onReplay: (() -> Void)? = nil

    @Environment(\.girlArt) private var girl

    var body: some View {
        let lastArt = ArtIndex.shared.steps(play.code).last
        let thumbImg = lastArt.flatMap { name -> UIImage? in
            let shown = ArtIndex.variant(name, girl: girl)
            return Perf.noArt ? nil : (ArtCache.shared.cached(shown, maxPixel: 240) ?? ArtCache.shared.image(shown, maxPixel: 240))
        }
        let line: String = count > 0
            ? L10n.t(
                "已盖下第 \(count) 枚金珠印章" + (count >= 3 ? " · 越来越默契" : ""),
                "Stamped session #\(count)" + (count >= 3 ? " — getting more natural" : "")
            )
            : L10n.t("已盖下今天这一页的金珠印章", "Gold wax stamp earned for this page")

        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                    .fill(dark ? Color(hex: 0x151D3B) : Color(hex: 0xFDF7EA))
                RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                    .strokeBorder(Palette.bead.opacity(dark ? 0.35 : 0.30), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))

                HStack(spacing: 12) {
                    if let livingScript = LivingBookCatalog.script(for: play.code) {
                        let lastIdx = max(0, livingScript.steps.count - 1)
                        ZStack(alignment: .top) {
                            LivingBookStage(
                                script: livingScript,
                                stepIndex: lastIdx,
                                companion: companion,
                                dark: dark,
                                accent: Palette.area(Palette.areaKey(of: play)),
                                posterPhase: livingScript.steps[lastIdx].posterPhase,
                                interactive: false,
                                compact: true
                            )
                            .frame(width: 76, height: 57)
                            .padding(3)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(dark ? Palette.lampCard : .white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Palette.outline.opacity(0.28), lineWidth: 0.75)
                            )
                            .shadow(color: .black.opacity(0.10), radius: 3, y: 2)
                            .rotationEffect(.degrees(-3))

                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Color(hex: 0xEFE1B8).opacity(0.88))
                                .frame(width: 22, height: 7)
                                .offset(y: -3)
                        }
                    } else if let thumbImg {
                        ZStack(alignment: .top) {
                            Image(uiImage: thumbImg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 76, height: 57)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .padding(3)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(dark ? Palette.lampCard : .white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Palette.outline.opacity(0.28), lineWidth: 0.75)
                                )
                                .shadow(color: .black.opacity(0.10), radius: 3, y: 2)
                                .rotationEffect(.degrees(-3))

                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Color(hex: 0xEFE1B8).opacity(0.88))
                                .frame(width: 22, height: 7)
                                .offset(y: -3)
                        }
                    }

                    Spacer(minLength: 4)

                    WaxSealBadge(seal: .gold, size: 42)

                    Spacer(minLength: 4)

                    Duo(primary: companion, size: 54, look: CGPoint(x: -0.4, y: -0.2), cheer: cheer)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .frame(height: 88)

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("这一页玩完啦", "Page Complete"))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if let onReplay {
                    Button(action: onReplay) {
                        Label(L10n.t("再玩一遍", "Play Again"), systemImage: "arrow.counterclockwise")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.vinyl(Crayon.caramel))
                }
            }
        }
        .padding(14)
        .printCard(radius: Radius.card)
        .overlay { BeadBurst(trigger: cheer) }
    }
}
