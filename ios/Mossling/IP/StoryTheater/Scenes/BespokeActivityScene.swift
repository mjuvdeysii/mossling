import SwiftUI

// MARK: - Bespoke Independent Activity Scene Registry & Context

enum BespokeActivityID: String, CaseIterable, Sendable {
    case n01, n02, n03, n04, n05, n06
    case a01, a02, a03, a04

    var code: String {
        rawValue.uppercased()
    }
}

struct BespokeSceneContext: Sendable {
    let code: String
    let stepIndex: Int
    let phase: LivingPhaseSample
    let breathTime: Double
    let stageSize: CGSize
    let dark: Bool
    let flat: Bool
    let isStatic: Bool
    let compact: Bool
    let tapOrigin: CGPoint?
    let tapStrength: Double

    var shaderEnabled: Bool {
        !compact && stageSize.width >= 80 && stageSize.height >= 60
    }
}

struct BespokeSceneMetadata: Sendable {
    let id: BespokeActivityID
    let cameraGrammar: String
    let durations: [Double]
    let posterPhases: [Double]
    let audioAnchors: [LivingAudioAnchor]
    let lightKeyNormalized: CGPoint
    let komorebiStrength: Double
}

enum BespokeActivitySceneRegistry {
    static let registeredCodes: Set<String> = Set(BespokeActivityID.allCases.map(\.code))

    static func id(for code: String) -> BespokeActivityID? {
        BespokeActivityID(rawValue: code.lowercased())
    }

    static func hasBespokeScene(for code: String) -> Bool {
        id(for: code) != nil
    }

    static func metadata(for code: String) -> BespokeSceneMetadata? {
        guard let id = id(for: code) else { return nil }
        return metadata(for: id)
    }

    static func metadata(for id: BespokeActivityID) -> BespokeSceneMetadata {
        switch id {
        case .n01:
            return BespokeSceneMetadata(
                id: .n01,
                cameraGrammar: "closeup-feeding-alcove",
                durations: [4.6, 4.4, 4.8],
                posterPhases: [0.56, 0.54, 0.62],
                audioAnchors: [.softChime, .none, .softChime],
                lightKeyNormalized: CGPoint(x: 0.78, y: 0.16),
                komorebiStrength: 0.72
            )
        case .n02:
            return BespokeSceneMetadata(
                id: .n02,
                cameraGrammar: "window-seat-two-shot",
                durations: [4.5, 4.8],
                posterPhases: [0.55, 0.64],
                audioAnchors: [.softChime, .none],
                lightKeyNormalized: CGPoint(x: 0.22, y: 0.14),
                komorebiStrength: 0.85
            )
        case .n03:
            return BespokeSceneMetadata(
                id: .n03,
                cameraGrammar: "blanket-cocoon-cradle",
                durations: [4.4, 5.2],
                posterPhases: [0.52, 0.58],
                audioAnchors: [.clothSwish, .none],
                lightKeyNormalized: CGPoint(x: 0.70, y: 0.20),
                komorebiStrength: 0.52
            )
        case .n04:
            return BespokeSceneMetadata(
                id: .n04,
                cameraGrammar: "birds-eye-round-tummy-mat",
                durations: [4.6, 4.5, 4.8],
                posterPhases: [0.54, 0.56, 0.62],
                audioAnchors: [.clothSwish, .none, .softChime],
                lightKeyNormalized: CGPoint(x: 0.80, y: 0.12),
                komorebiStrength: 0.82
            )
        case .n05:
            return BespokeSceneMetadata(
                id: .n05,
                cameraGrammar: "foreground-open-book-spread",
                durations: [4.8, 4.6],
                posterPhases: [0.55, 0.64],
                audioAnchors: [.clothSwish, .none],
                lightKeyNormalized: CGPoint(x: 0.26, y: 0.18),
                komorebiStrength: 0.68
            )
        case .n06:
            return BespokeSceneMetadata(
                id: .n06,
                cameraGrammar: "evening-study-desk-journal",
                durations: [4.8, 5.0],
                posterPhases: [0.56, 0.64],
                audioAnchors: [.woodTap, .softChime],
                lightKeyNormalized: CGPoint(x: 0.24, y: 0.22),
                komorebiStrength: 0.58
            )
        case .a01:
            return BespokeSceneMetadata(
                id: .a01,
                cameraGrammar: "eye-level-musical-alcove",
                durations: [4.2, 4.6, 4.4, 4.8],
                posterPhases: [0.54, 0.52, 0.50, 0.60],
                audioAnchors: [.none, .softChime, .none, .softChime],
                lightKeyNormalized: CGPoint(x: 0.74, y: 0.16),
                komorebiStrength: 0.78
            )
        case .a02:
            return BespokeSceneMetadata(
                id: .a02,
                cameraGrammar: "linen-care-bench-closeup",
                durations: [4.4, 4.5, 4.8],
                posterPhases: [0.54, 0.56, 0.62],
                audioAnchors: [.softChime, .none, .clothSwish],
                lightKeyNormalized: CGPoint(x: 0.76, y: 0.18),
                komorebiStrength: 0.70
            )
        case .a03:
            return BespokeSceneMetadata(
                id: .a03,
                cameraGrammar: "wide-low-playroom-horizon",
                durations: [4.5, 4.6, 4.4, 4.8],
                posterPhases: [0.54, 0.52, 0.56, 0.60],
                audioAnchors: [.none, .clothSwish, .softChime, .woodTap],
                lightKeyNormalized: CGPoint(x: 0.80, y: 0.14),
                komorebiStrength: 0.86
            )
        case .a04:
            return BespokeSceneMetadata(
                id: .a04,
                cameraGrammar: "macro-sunlit-grasping-mat",
                durations: [4.4, 4.6, 4.6],
                posterPhases: [0.54, 0.52, 0.60],
                audioAnchors: [.woodTap, .none, .woodTap],
                lightKeyNormalized: CGPoint(x: 0.78, y: 0.14),
                komorebiStrength: 0.84
            )
        }
    }

    @ViewBuilder
    static func stageView(id: BespokeActivityID, context: BespokeSceneContext) -> some View {
        let meta = metadata(for: id)
        let w = context.stageSize.width
        let h = context.stageSize.height
        let keyPt = CGPoint(x: w * meta.lightKeyNormalized.x, y: h * meta.lightKeyNormalized.y)
        let beadDefault = CGPoint(x: w * 0.30, y: h * 0.44)
        let targetDefault = CGPoint(x: w * 0.66, y: h * 0.64)

        ZStack {
            rawScene(id: id, context: context)

            if context.tapStrength > 0.01, let tap = context.tapOrigin, !context.isStatic {
                TapReactionChimeLayer(origin: tap, strength: context.tapStrength, dark: context.dark, size: context.stageSize)
            }
        }
        .modifier(
            GhibliStageGrade(
                stageSize: context.stageSize,
                time: context.breathTime,
                dark: context.dark,
                komorebiStrength: meta.komorebiStrength,
                enabled: context.flat && context.shaderEnabled
            )
        )
        .modifier(
            PixarStageGrade(
                stageSize: context.stageSize,
                keyPos: keyPt,
                beadPos: beadDefault,
                targetPos: targetDefault,
                time: context.breathTime,
                dark: context.dark,
                keyIntensity: context.dark ? 0.92 : 1.0,
                volumetricIntensity: context.dark ? 1.05 : 0.62,
                enabled: !context.flat && context.shaderEnabled
            )
        )
    }

    @ViewBuilder
    private static func rawScene(id: BespokeActivityID, context: BespokeSceneContext) -> some View {
        switch id {
        case .n01: SceneN01_VoiceTurns(ctx: context)
        case .n02: SceneN02_FamiliarFaces(ctx: context)
        case .n03: SceneN03_GentleHolding(ctx: context)
        case .n04: SceneN04_TummyTime(ctx: context)
        case .n05: SceneN05_ShortReads(ctx: context)
        case .n06: SceneN06_CareNotes(ctx: context)
        case .a01: SceneA01_FaceSoundTurns(ctx: context)
        case .a02: SceneA02_NarratingCare(ctx: context)
        case .a03: SceneA03_AwakeTummyPlay(ctx: context)
        case .a04: SceneA04_WatchHandsReach(ctx: context)
        }
    }
}

// MARK: - Bespoke Shared Spatial & Graphic Helpers (Zero IP Violation)

enum BespokeStageHelpers {
    /// Identical foot baseline positioning for 3D soft-vinyl & 2D Ghibli actors.
    static func actorCenterY(kind: Kind, size: CGFloat, groundY: CGFloat, flat: Bool, lift: CGFloat = 0) -> CGFloat {
        let feetFrac: CGFloat = flat ? 0.88 : ((kind == .moss ? Sprites.mossFeet : Sprites.ottoFeet) / 100.0)
        return groundY - size * feetFrac + size * 0.5 - lift
    }

    /// Dual-layer sky + wall atmosphere backing shared cleanly across Day and Lamp.
    static func drawAtmosphereWash(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        dayTop: Color,
        dayBottom: Color,
        nightTop: Color,
        nightBottom: Color,
        dark: Bool
    ) {
        let top = dark ? nightTop : dayTop
        let bot = dark ? nightBottom : dayBottom
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: w, height: h)),
            with: .linearGradient(
                Gradient(colors: [top, bot]),
                startPoint: CGPoint(x: w * 0.25, y: 0),
                endPoint: CGPoint(x: w * 0.75, y: h)
            )
        )
    }

    /// Flowing multi-ribbon voice wave conveying gentle dialogue without speech bubbles or mouth dots.
    static func drawSilkVoiceRibbon(
        in ctx: inout GraphicsContext,
        from start: CGPoint,
        to end: CGPoint,
        progress: Double,
        waveOffset: Double,
        color: Color,
        lineWidth: CGFloat,
        dark: Bool
    ) {
        let clamped = max(0.0, min(1.0, progress))
        guard clamped > 0.02 else { return }

        var p = Path()
        let samples = 24
        for i in 0...samples {
            let t = Double(i) / Double(samples) * clamped
            let x = start.x + (end.x - start.x) * CGFloat(t)
            let baseY = start.y + (end.y - start.y) * CGFloat(t)
            let env = sin(t * .pi)
            let wave = sin(t * .pi * 3.0 + waveOffset) * 7.5 * env
            let pt = CGPoint(x: x, y: baseY + CGFloat(wave))
            if i == 0 {
                p.move(to: pt)
            } else {
                p.addLine(to: pt)
            }
        }
        ctx.stroke(
            p,
            with: .linearGradient(
                Gradient(colors: [
                    color.opacity(0.08),
                    color.opacity(dark ? 0.72 : 0.62),
                    color.opacity(dark ? 0.88 : 0.75)
                ]),
                startPoint: start,
                endPoint: end
            ),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }

    /// Golden stillness halo expanding softly in the pause space between turns.
    static func drawPauseHalo(
        in ctx: inout GraphicsContext,
        center: CGPoint,
        baseRadius: CGFloat,
        progress: Double,
        tint: Color,
        dark: Bool
    ) {
        let t = max(0.0, min(1.0, progress))
        guard t > 0.01 else { return }
        for ring in 0..<2 {
            let local = max(0.0, min(1.0, t - Double(ring) * 0.24))
            guard local > 0 else { continue }
            let r = baseRadius * (0.45 + 0.85 * CGFloat(local))
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            let alpha = (1.0 - local * 0.65) * (dark ? 0.48 : 0.36)
            ctx.stroke(
                Path(ellipseIn: rect),
                with: .color(tint.opacity(alpha)),
                style: StrokeStyle(lineWidth: ring == 0 ? 1.8 : 1.1, dash: ring == 1 ? [3, 4] : [])
            )
        }
    }

    /// Subtle sparkling bead cluster emitted on caregiver tactile contact.
    static func drawContactSparkles(
        in ctx: inout GraphicsContext,
        center: CGPoint,
        pulse: Double,
        radius: CGFloat,
        color: Color
    ) {
        guard pulse > 0.02 else { return }
        for i in 0..<5 {
            let ang = Double(i) * (2.0 * .pi / 5.0) - .pi / 2.0
            let dist = radius * CGFloat(0.45 + 0.75 * pulse)
            let pt = CGPoint(x: center.x + cos(ang) * dist, y: center.y + sin(ang) * dist)
            let dotR = max(1.4, 3.6 * CGFloat(pulse))
            ctx.fill(
                Path(ellipseIn: CGRect(x: pt.x - dotR, y: pt.y - dotR, width: dotR * 2, height: dotR * 2)),
                with: .color(color.opacity(min(1.0, pulse * 1.15)))
            )
        }
    }
}

private struct TapReactionChimeLayer: View {
    let origin: CGPoint
    let strength: Double
    let dark: Bool
    let size: CGSize

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, s in
            let center = CGPoint(x: origin.x * s.width, y: origin.y * s.height)
            let col = dark ? Palette.amber : Palette.accent
            let ringR = min(s.width, s.height) * CGFloat(0.06 + 0.14 * (1.0 - strength))
            let rect = CGRect(x: center.x - ringR, y: center.y - ringR, width: ringR * 2, height: ringR * 2)
            ctx.stroke(
                Path(ellipseIn: rect),
                with: .color(col.opacity(strength * 0.55)),
                lineWidth: 2.0
            )
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: center,
                pulse: strength,
                radius: min(s.width, s.height) * 0.09,
                color: Palette.amber.opacity(0.90)
            )
        }
        .allowsHitTesting(false)
    }
}
