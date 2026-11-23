import SwiftUI

/// One play, presented around a tactile Montessori living stage rather than a task checklist:
/// - **Living Play Stage** at the top: interactive `ActivityMotionStage` (3D/2D `Moss` & `Otto` + custom wood/linen props)
///   switchable with each step's original illustration (`ArtView`) so all 146 studio drawings remain one tap away.
/// - **Mat-Side Co-Play Focus Mode** (`MatSideCoPlayView`): 1-tap full-screen distraction-free card designed to rest
///   beside the baby's play mat with swipe gestures, thumb-sized controls, screen-awake lock, and instant safety notes.
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

    @State private var scrolled = false
    @State private var cheer = 0
    @State private var open = 0
    @State private var before = false
    /// What to watch for and when to stop is safety: open from the start, not folded away.
    @State private var during = true
    /// Toggles between the new interactive Montessori motion stage and the original step illustration (`ArtView`).
    @State private var showGuideArt = false
    @State private var matMode = false
    /// The count when the page was opened: a count above it means this visit already recorded a time (by 记一次,
    /// the menu, or the last step) — derived from the records, not kept beside them.
    @State private var base: Int?

    var body: some View {
        let dark = lamp || scheme == .dark
        let rec = app.record(play, j)
        let art = ArtIndex.shared.steps(play.code)

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PlayHeader(play: play, record: rec, cheer: cheer, onLog: { record() }, onMatMode: { openMatMode() })
                        .onScrollVisibilityChange(threshold: 0.2) { v in
                            withAnimation(.easeOut(duration: 0.2)) { scrolled = !v }
                        }

                    // 1. Unified Living Play Stage or Completion Celebration
                    if open < play.steps.count {
                        PlayLivingHeroCard(
                            play: play,
                            stepIndex: open,
                            stepText: play.steps[open],
                            artName: open < art.count ? art[open] : nil,
                            companion: app.companion,
                            dark: dark,
                            showGuideArt: $showGuideArt,
                            onPrev: open > 0 ? { go(open - 1, proxy) } : nil,
                            onNext: { go(open + 1, proxy) }
                        )
                        .id("stage")
                    } else {
                        FinishedCard(
                            companion: app.companion,
                            count: rec.count,
                            cheer: cheer,
                            onReplay: { go(0, proxy) }
                        )
                        .transition(reduce ? .opacity : .scale(scale: 0.94).combined(with: .opacity))
                        .id("finished")
                    }

                    // 2. Interactive Montessori Bead Bar
                    if play.steps.count > 1 {
                        StepBeadBar(total: play.steps.count, current: open) { go($0, proxy) }
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

                    // 4. Clean Scannable Steps Index (1-tap jump to any step, zero redundant giant stacking boxes)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L10n.t("共玩步骤", "Play Rhythm"))
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(Palette.secondaryText)
                            Spacer(minLength: 0)
                            if !art.isEmpty {
                                Text(L10n.t("轻点任意一步切换示范", "Tap any step to focus"))
                                    .font(.caption2)
                                    .foregroundStyle(Palette.secondaryText.opacity(0.85))
                            }
                        }
                        .padding(.horizontal, 4)

                        VStack(spacing: 8) {
                            ForEach(Array(play.steps.enumerated()), id: \.offset) { i, s in
                                CompactStepOutlineRow(
                                    n: i + 1,
                                    text: s,
                                    art: i < art.count ? art[i] : nil,
                                    active: i == open,
                                    done: i < open,
                                    dark: dark
                                ) {
                                    go(i, proxy)
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
        .onDisappear { keepAwake(false) }
        .onChange(of: open) { _, o in keepAwake(o < play.steps.count || matMode) }
        .onChange(of: matMode) { _, active in keepAwake(active || open < play.steps.count) }
        // A time taken back (撤销): the finished card goes and the last step opens again, to be finished anew
        .onChange(of: j.plays(play.code).count) { old, new in countChanged(old, new) }
        .navigationTitle(play.name)
        .navigationBarTitleDisplayMode(.inline)
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

    private func go(_ i: Int, _ proxy: ScrollViewProxy) {
        if i >= play.steps.count {
            completeSessionFromAnyMode()
            withAnimation(.smooth.delay(0.15)) {
                proxy.scrollTo("finished", anchor: .center)
            }
            return
        }
        TactileEngine.shared.beadClick()
        withAnimation(reduce ? nil : .snappy) { open = i }
        app.play(play, month: month, at: i)
        withAnimation(.smooth.delay(0.12)) {
            proxy.scrollTo("stage", anchor: .top)
        }
    }
}

// MARK: - Hero Living Stage Card

private struct PlayLivingHeroCard: View {
    let play: Play
    let stepIndex: Int
    let stepText: String
    let artName: String?
    let companion: Kind
    let dark: Bool
    @Binding var showGuideArt: Bool
    let onPrev: (() -> Void)?
    let onNext: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        let last = stepIndex == play.steps.count - 1
        let areaKey = Palette.areaKey(of: play)
        let areaColor = Palette.area(areaKey)

        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                if showGuideArt, let artName {
                    ArtView(name: artName, label: L10n.t("第 \(stepIndex + 1) 步的图示", "Illustration for step \(stepIndex + 1)"), radius: 0)
                        .frame(maxWidth: .infinity)
                        .frame(height: 210)
                        .clipped()
                } else {
                    ActivityMotionStage(
                        play: play,
                        stepIndex: stepIndex,
                        stepCount: play.steps.count,
                        companion: companion,
                        compact: false,
                        dark: dark
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                }

                // Visual switcher pill when this step also has an illustration in art/
                if artName != nil {
                    Button {
                        TactileEngine.shared.beadClick()
                        withAnimation(reduce ? nil : .snappy) {
                            showGuideArt.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showGuideArt ? "sparkles" : "photo")
                                .font(.caption2.weight(.bold))
                            Text(showGuideArt ? L10n.t("绘本场景", "Diorama") : L10n.t("步骤图示", "Guide Art"))
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(dark ? Palette.lampInk : Palette.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill((dark ? Palette.lampCard : .white).opacity(0.92)))
                        .overlay(Capsule().strokeBorder(areaColor.opacity(0.35), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    .padding(showGuideArt ? 10 : 18)
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 11) {
                    StepCircleBadge(number: stepIndex + 1, done: false)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("第 \(stepIndex + 1) 步 · 共 \(play.steps.count) 步", "Step \(stepIndex + 1) of \(play.steps.count)"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.areaInk(areaKey))
                        Text(stepText)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    if let onPrev {
                        Button(action: onPrev) {
                            Label(L10n.t("上一步", "Back"), systemImage: "chevron.left")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.vinyl(Crayon.caramel))
                    } else if !showGuideArt {
                        Text(L10n.t("轻点上方画面互动", "Tap stage to play"))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Palette.secondaryText)
                    }

                    Spacer(minLength: 4)

                    Button(action: onNext) {
                        Label(last ? L10n.t("做完了", "All Done") : L10n.t("下一步", "Next Step"), systemImage: last ? "checkmark" : "arrow.forward")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.vinyl(Palette.accentFill, prominent: true))
                }
            }
            .padding(16)
        }
        .printCard(radius: Radius.card)
    }
}

// MARK: - Compact Scannable Step Outline Row

private struct CompactStepOutlineRow: View {
    let n: Int
    let text: String
    let art: String?
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
                        Text(L10n.t("正在做这一步", "Current Step"))
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

                if let art {
                    ArtView(name: art, radius: 9)
                        .frame(width: 56, height: 42)
                        .opacity(done ? 0.58 : 1)
                }
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

    @State private var showGuideArt = false
    @State private var showSafetySheet = false

    private var hasGuidance: Bool {
        !play.prepare.isEmpty || !play.safety.isEmpty || !play.observe.isEmpty || !play.pause.isEmpty
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        let areaKey = Palette.areaKey(of: play)
        let areaColor = Palette.area(areaKey)
        let art = ArtIndex.shared.steps(play.code)
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

                if hasGuidance {
                    Button {
                        TactileEngine.shared.beadClick()
                        showSafetySheet = true
                    } label: {
                        Label(L10n.t("安全看护", "Safety"), systemImage: "exclamationmark.shield.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Crayon.ink(Crayon.tangerine))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Crayon.tangerine.opacity(dark ? 0.24 : 0.16)))
                    }
                    .buttonStyle(.toy)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            StepBeadBar(total: play.steps.count, current: currentStep) { idx in
                onSelectStep(idx)
            }
            .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 18) {
                    if finished {
                        FinishedCard(
                            companion: companion,
                            count: max(1, cheerCount),
                            cheer: cheerTrigger,
                            onReplay: { onSelectStep(0) }
                        )
                        .padding(.top, 12)
                    } else {
                        let artName = currentStep < art.count ? art[currentStep] : nil
                        ZStack(alignment: .topTrailing) {
                            if showGuideArt, let artName {
                                ArtView(name: artName, label: L10n.t("第 \(currentStep + 1) 步的图示", "Illustration for step \(currentStep + 1)"), radius: Radius.card)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 230)
                                    .clipped()
                            } else {
                                ActivityMotionStage(
                                    play: play,
                                    stepIndex: currentStep,
                                    stepCount: play.steps.count,
                                    companion: companion,
                                    compact: false,
                                    dark: dark
                                )
                            }

                            if artName != nil {
                                Button {
                                    TactileEngine.shared.beadClick()
                                    withAnimation(reduce ? nil : .snappy) {
                                        showGuideArt.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: showGuideArt ? "sparkles" : "photo")
                                            .font(.caption2.weight(.bold))
                                        Text(showGuideArt ? L10n.t("绘本场景", "Diorama") : L10n.t("步骤图示", "Guide Art"))
                                            .font(.caption2.weight(.bold))
                                    }
                                    .foregroundStyle(dark ? Palette.lampInk : Palette.text)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill((dark ? Palette.lampCard : .white).opacity(0.92)))
                                }
                                .buttonStyle(.plain)
                                .padding(10)
                            }
                        }

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

                            Text(L10n.t("轻点上方画面可与 Moss 互动 · 左右轻扫也能切步", "Tap the stage to play with Moss · Swipe left or right to step"))
                                .font(.caption)
                                .foregroundStyle(Palette.secondaryText)
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
}

// MARK: - Shared Supporting Building Blocks (Kept Intact)

/// A folded section: one line (sticker, title, what is inside) that opens in place.
struct Fold<Content: View>: View {
    let title: String
    let summary: String
    let symbol: String
    let color: Color
    @Binding var open: Bool
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.snappy) { open.toggle() } } label: {
                HStack(spacing: 12) {
                    IconTile(symbol: symbol, color: color, size: 30)
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(summary).font(.subheadline).foregroundStyle(Palette.secondaryText).lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.footnote.weight(.bold)).foregroundStyle(Palette.secondaryText)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.toy)
            .accessibilityValue(open ? L10n.t("已展开", "Expanded") : L10n.t("已折叠", "Collapsed"))
            if open {
                Divider().padding(.horizontal, 16)
                VStack(spacing: 0) { content }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .printCard(radius: Radius.card)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

/// A quiet Montessori bead progress bar for a play's steps: gold beads for finished steps, an active pill for the step
/// in hand, pale stone for the steps ahead. Tapping any bead opens that step.
private struct StepBeadBar: View {
    let total: Int
    let current: Int
    let pick: (Int) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Namespace private var beadNS

    var body: some View {
        let done = min(current, total)
        let label = current >= total ? L10n.t("全部 \(total) 步已完成", "All \(total) steps done") : L10n.t("第 \(current + 1) 步，共 \(total) 步", "Step \(current + 1) of \(total)")
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { i in
                    Button { pick(i) } label: {
                        ZStack {
                            if i < current {
                                GoldBead(size: 11)
                                    .transition(.scale.combined(with: .opacity))
                            } else if i == current {
                                Capsule()
                                    .fill(Palette.accent)
                                    .frame(width: 24, height: 11)
                                    .matchedGeometryEffect(id: "activeBead", in: beadNS)
                            } else {
                                Circle().fill(Palette.stone.opacity(0.75)).frame(width: 9, height: 9)
                            }
                        }
                        .frame(minWidth: 28, minHeight: 32)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("第 \(i + 1) 步", "Step \(i + 1)"))
                }
            }
            Spacer(minLength: 4)
            Text(current >= total ? L10n.t("全部完成", "All Done") : L10n.t("第 \(done + 1) / \(total) 步", "Step \(done + 1) / \(total)"))
                .font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText).monospacedDigit()
                .contentTransition(.numericText(value: Double(done + 1)))
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .printCard(radius: Radius.inner)
        .animation(reduce ? nil : .spring(response: 0.34, dampingFraction: 0.78), value: current)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

/// How many times, as beads on a string — one gold bead per time, up to five — the count, and when last.
struct DoneCount: View {
    let record: PlayRecord
    var cheer = 0
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: -3) {
                ForEach(0..<max(1, min(record.count, 5)), id: \.self) { _ in
                    Circle()
                        .fill(record.count == 0 ? AnyShapeStyle(Palette.fill) : AnyShapeStyle(RadialGradient(colors: [Palette.beadLight, Palette.bead, Color(hex: 0x9C6F08)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 11)))
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(record.count == 0 ? 0 : 0.18), radius: 1, y: 1)
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

/// The steps finished: the companions come out to cheer, here, in the page, with the count.
private struct FinishedCard: View {
    let companion: Kind
    let count: Int
    let cheer: Int
    var onReplay: (() -> Void)? = nil

    var body: some View {
        let line: String = L10n.t(
            "记下了第 \(count) 次" + (count >= 3 ? "，越来越熟练" : ""),
            "Logged session #\(count)" + (count >= 3 ? " — getting more natural" : "")
        )
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Duo(primary: companion, size: 58, look: CGPoint(x: 0.5, y: -0.3), cheer: cheer)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("做完了", "All Done"))
                        .font(.headline)
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryText)
                }
                Spacer(minLength: 0)
            }
            if let onReplay {
                HStack {
                    Spacer(minLength: 0)
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
