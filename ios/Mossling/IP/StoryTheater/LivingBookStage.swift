import SwiftUI

/// Synchronous soft-vinyl sprite resolver so Frame 1, thumbnails, `ScreenshotTests`, and `ImageRenderer`
/// exports render immediately with zero async blank-frame flash.
enum StoryTheaterSpritePool {
    nonisolated(unsafe) private static var cache: [String: UIImage] = [:]
    private static let lock = NSLock()
    private static let maxPixel = 384

    static func image(kind: Kind, state: String) -> UIImage? {
        let prefix = kind == .moss ? "ip_moss_" : "ip_otto_"
        let key = prefix + state
        lock.lock()
        if let hit = cache[key] {
            lock.unlock()
            return hit
        }
        lock.unlock()

        let loaded = ArtCache.shared.cached(key + ".webp", maxPixel: maxPixel)
            ?? ArtCache.shared.image(key + ".webp", maxPixel: maxPixel)
            ?? ArtCache.shared.cached(prefix + "idle.webp", maxPixel: maxPixel)
            ?? ArtCache.shared.image(prefix + "idle.webp", maxPixel: maxPixel)

        if let loaded {
            lock.lock()
            cache[key] = loaded
            lock.unlock()
        }
        return loaded
    }
}

/// Interactive Living Picture-Book Micro-Theater Stage:
/// - **5-Phase OpenMotion Clock** (`Anticipation -> Main Action -> Contact -> Follow-Through -> Hold`)
/// - **Cross-Step Object Continuity** (one persistent stage instance across steps 1 -> 2 -> 3)
/// - **True `docs/IP.md` Character Canon** (zero blush, zero mouth dots, canonical `Sprites.swift` scale & `Sprites.bead` tracking)
/// - **Deterministic `posterPhase: Double?`** for `Reduce Motion`, thumbnails, `ScreenshotTests`, and `ImageRenderer` PDF export.
struct LivingBookStage: View {
    let script: LivingActivityScript
    let stepIndex: Int
    let companion: Kind
    let dark: Bool
    var accent: Color = Palette.accent
    var posterPhase: Double? = nil
    var interactive: Bool = true
    var compact: Bool = false
    var replayTrigger: Int = 0
    var forceFlat: Bool? = nil

    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.scrolling) private var scrolling

    @State private var cycleStart = Date()
    @State private var onScreen = true
    @State private var tapBurstAt = Date.distantPast
    @State private var tapBurstOrigin: CGPoint? = nil
    @State private var audioTask: Task<Void, Never>? = nil

    private var activeStep: LivingStepScript {
        let clamped = min(max(0, stepIndex), max(0, script.steps.count - 1))
        return script.steps[clamped]
    }

    private var isStatic: Bool {
        posterPhase != nil || reduce || Perf.still || !onScreen || scrolling.moving || scenePhase != .active
    }

    var body: some View {
        let isFlat = forceFlat ?? (ArtStyle.current == .flat)
        let step = activeStep

        Group {
            if isStatic {
                stageFrame(now: Date(), step: step, staticProgress: posterPhase ?? step.posterPhase, isFlat: isFlat)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { tl in
                    let elapsed = max(0, tl.date.timeIntervalSince(cycleStart))
                    let u = LivingMotionClock.cyclicProgress(elapsed: elapsed, duration: step.duration)
                    stageFrame(now: tl.date, step: step, staticProgress: u, isFlat: isFlat)
                }
            }
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: compact ? 9 : Radius.tile, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 9 : Radius.tile, style: .continuous)
                .strokeBorder(accent.opacity(dark ? 0.28 : 0.18), lineWidth: compact ? 0.75 : 1.0)
        )
        .onScrollVisibilityChange(threshold: 0.01) { onScreen = $0 }
        .onChange(of: stepIndex) { _, _ in
            cycleStart = Date()
            audioTask?.cancel()
            audioTask = nil
        }
        .onChange(of: replayTrigger) { _, _ in
            triggerInteractiveReplay(origin: nil, withHaptic: true)
        }
        .onDisappear {
            audioTask?.cancel()
            audioTask = nil
        }
    }

    private func stageFrame(now: Date, step: LivingStepScript, staticProgress u: Double, isFlat: Bool) -> some View {
        let sample = LivingMotionClock.sample(u: u)
        let poses = step.actors(at: sample, dark: dark)
        let tapAge = tapBurstAt == .distantPast ? 9.9 : max(0, now.timeIntervalSince(tapBurstAt))
        let tapStrength = (interactive && !isStatic && tapAge < 0.75) ? (1.0 - tapAge / 0.75) : 0.0

        return GeometryReader { g in
            let w = g.size.width
            let h = g.size.height
            let floorY = PictureBookBackdrop.floorLineY(for: script.backdrop, in: h)
            let ms = min(w * 0.255, h * 0.365)
            let os = ms * Kind.otto.scale

            let mossFeetFrac: CGFloat = isFlat ? 0.88 : (Sprites.mossFeet / 100.0)
            let ottoFeetFrac: CGFloat = isFlat ? 0.88 : (Sprites.ottoFeet / 100.0)

            let mossCenter = CGPoint(
                x: w * poses.moss.x,
                y: floorY - ms * mossFeetFrac + ms * 0.5 - poses.moss.hopLift * (ms * 0.07)
            )
            let ottoCenter = CGPoint(
                x: w * poses.otto.x,
                y: floorY - os * ottoFeetFrac + os * 0.5 - poses.otto.hopLift * (os * 0.05)
            )

            let ottoState = Creature.state(.otto, face: poses.otto.mood, look: poses.otto.look, lid: poses.otto.lid ?? 0, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: poses.otto.lean,
                flat: isFlat
            )
            let targetWorld = CGPoint(x: w * step.lampTargetX, y: min(floorY + 3, h * step.lampTargetY + (floorY - h * step.lampTargetY) * 0.55))

            ZStack(alignment: .topLeading) {
                PictureBookBackdrop(kind: script.backdrop, accent: accent, dark: dark, flat: isFlat)

                MontessoriPropRig(
                    script: step,
                    backdrop: script.backdrop,
                    phase: sample,
                    accent: accent,
                    dark: dark,
                    flat: isFlat,
                    layer: .behindActors,
                    tapBurstOrigin: tapBurstOrigin,
                    tapBurstStrength: tapStrength
                )

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: targetWorld,
                    phase: sample,
                    dark: dark,
                    flat: isFlat,
                    layer: .floorPool
                )

                MontessoriPropRig(
                    script: step,
                    backdrop: script.backdrop,
                    phase: sample,
                    accent: accent,
                    dark: dark,
                    flat: isFlat,
                    layer: .betweenActors,
                    tapBurstOrigin: tapBurstOrigin,
                    tapBurstStrength: tapStrength
                )

                // Render non-primary companion slightly behind if desired, preserving canonical scale & floor alignment
                if companion == .otto {
                    actorView(kind: .moss, pose: poses.moss, size: ms, now: now, isFlat: isFlat)
                        .position(mossCenter)
                    actorView(kind: .otto, pose: poses.otto, size: os, now: now, isFlat: isFlat)
                        .position(ottoCenter)
                } else {
                    actorView(kind: .otto, pose: poses.otto, size: os, now: now, isFlat: isFlat)
                        .position(ottoCenter)
                    actorView(kind: .moss, pose: poses.moss, size: ms, now: now, isFlat: isFlat)
                        .position(mossCenter)
                }

                MontessoriPropRig(
                    script: step,
                    backdrop: script.backdrop,
                    phase: sample,
                    accent: accent,
                    dark: dark,
                    flat: isFlat,
                    layer: .inFrontOfActors,
                    tapBurstOrigin: tapBurstOrigin,
                    tapBurstStrength: tapStrength
                )

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: targetWorld,
                    phase: sample,
                    dark: dark,
                    flat: isFlat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
            .animation(reduce || isStatic ? nil : .spring(response: 0.42, dampingFraction: 0.80), value: stepIndex)
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard interactive else { return }
                        let nx = w > 0 ? value.location.x / w : 0.5
                        let ny = h > 0 ? value.location.y / h : 0.5
                        triggerInteractiveReplay(origin: CGPoint(x: nx, y: ny), withHaptic: true)
                    }
            )
            .allowsHitTesting(interactive)
        }
    }

    @ViewBuilder
    private func actorView(kind: Kind, pose: LivingActorPose, size: CGFloat, now: Date, isFlat: Bool) -> some View {
        let t = isStatic ? 0 : now.timeIntervalSinceReferenceDate
        let period = kind == .moss ? 2.6 : 3.8
        let breath = isStatic ? 0 : (1 - cos(t / period * 2 * .pi)) / 2
        let amp = kind == .moss ? 0.016 : 0.010
        let sx = 1.0 - breath * amp * 0.5
        let sy = 1.0 + breath * amp
        let feetFrac: CGFloat = isFlat ? 0.88 : ((kind == .moss ? Sprites.mossFeet : Sprites.ottoFeet) / 100.0)

        if isFlat {
            FlatCreature(
                kind: kind,
                mood: pose.mood,
                look: pose.look,
                lid: pose.lid,
                lean: 0,
                alive: false,
                poke: false,
                arms: .rest,
                glow: kind == .otto && dark
            )
            .frame(width: size, height: size)
            .environment(\.colorScheme, dark ? .dark : .light)
            .scaleEffect(x: sx, y: sy, anchor: UnitPoint(x: 0.5, y: feetFrac))
            .rotationEffect(.degrees(pose.lean), anchor: UnitPoint(x: 0.5, y: feetFrac))
        } else {
            let st = Creature.state(
                kind,
                face: pose.mood,
                look: pose.look,
                lid: pose.lid ?? 0,
                hopping: pose.hopping,
                yawning: false
            )
            let img = StoryTheaterSpritePool.image(kind: kind, state: st)
            let rx = (kind == .moss ? 0.30 : 0.22) * size * (1.0 - min(0.35, pose.hopLift * 0.4))
            let bPt = Sprites.bead[st] ?? Sprites.bead["idle"] ?? CGPoint(x: 0.247, y: 0.4317)
            let glowR = size * (dark ? 0.16 : 0.09)

            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Palette.ink.opacity(dark ? 0.42 : 0.19), Palette.ink.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: rx * 1.1
                        )
                    )
                    .frame(width: rx * 2.2, height: rx * 0.42)
                    .position(x: size * 0.5, y: size * feetFrac + 1)

                ZStack {
                    if let img {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: size, height: size)
                    }
                    if kind == .otto {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Palette.amber.opacity(dark ? 0.72 : 0.24), Palette.amber.opacity(0)],
                                    center: .center,
                                    startRadius: 1,
                                    endRadius: glowR
                                )
                            )
                            .frame(width: glowR * 2, height: glowR * 2)
                            .blendMode(.plusLighter)
                            .position(x: size * bPt.x, y: size * bPt.y)
                    }
                }
                .frame(width: size, height: size)
                .scaleEffect(x: sx, y: sy, anchor: UnitPoint(x: 0.5, y: feetFrac))
                .rotationEffect(.degrees(pose.lean), anchor: UnitPoint(x: 0.5, y: feetFrac))
            }
            .frame(width: size, height: size)
        }
    }

    private func triggerInteractiveReplay(origin: CGPoint?, withHaptic: Bool) {
        let now = Date()
        cycleStart = now
        if let origin {
            tapBurstOrigin = origin
            tapBurstAt = now
        }
        if withHaptic {
            TactileEngine.shared.vinylPop()
        }
        let step = activeStep
        guard !reduce, interactive, !compact, step.audioAnchor != .none else { return }

        audioTask?.cancel()
        let anchor = step.audioAnchor
        let delaySeconds = step.duration * 0.48
        audioTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(delaySeconds * 1000)))
            guard !Task.isCancelled else { return }
            switch anchor {
            case .none: break
            case .woodTap: TactileEngine.shared.beadClick()
            case .clothSwish: TactileEngine.shared.pageTurn()
            case .softChime: TactileEngine.shared.goldChime()
            case .vinylPop: TactileEngine.shared.vinylPop()
            }
        }
    }
}
