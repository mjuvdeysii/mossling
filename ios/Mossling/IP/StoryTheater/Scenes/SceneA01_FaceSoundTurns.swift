import SwiftUI

/// A01: Symmetric eye-level felt pouf alcove framing clean musical turn-taking:
/// awake gaze anchor (Step 0) -> staggered amber Otto sound bubbles (Step 1)
/// -> crisp quiet breathing pause ring in empty space (Step 2) -> Moss mint answer duet (Step 3).
struct SceneA01_FaceSoundTurns: View {
    let ctx: BespokeSceneContext

    var body: some View {
        let step = min(max(0, ctx.stepIndex), 3)
        let p = ctx.phase
        let dark = ctx.dark
        let flat = ctx.flat

        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let h = max(1, geo.size.height)
            let s = min(w, h)

            let ms = s * 0.36
            let os = ms * Kind.otto.scale
            let groundY = h * 0.825

            let ottoX = w * 0.255
            let mossX = w * 0.745

            let mossHopLift: CGFloat = step == 3
                ? CGFloat(max(0.0, sin((p.raw - 0.30) / 0.42 * .pi))) * ms * 0.10
                : 0
            let ottoLean = step == 1 ? (5.0 + sin(p.action * .pi) * 3.0) : (step == 3 ? 4.0 : 2.0)
            let mossLean = step == 3 ? (-6.0 * sin(p.action * .pi)) : -2.0

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat, lift: mossHopLift)
            )

            let ottoLook = CGPoint(x: 0.78, y: 0.04)
            let mossLook = CGPoint(x: -0.78, y: -0.02)
            let ottoMood: Mood = (step == 1 || step == 3) ? .happy : .open
            let mossMood: Mood = {
                switch step {
                case 0: return .open
                case 1: return .wow
                case 2: return .open
                default: return p.action > 0.25 ? .happy : .wow
                }
            }()
            let ottoLid: Double = step == 2 ? (dark ? 0.48 : 0.32) : (dark ? 0.40 : 0.24)
            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: ottoLid, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )
            let midCenter = CGPoint(x: w * 0.50, y: h * 0.52)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawMusicalAlcove(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        ottoPos: CGPoint(x: ottoCenter.x + os * 0.24, y: ottoCenter.y - os * 0.06),
                        mossPos: CGPoint(x: mossCenter.x - ms * 0.24, y: mossCenter.y - ms * 0.06),
                        mid: midCenter,
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: mossCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .floorPool
                )

                StoryTheaterActorView(
                    kind: .otto,
                    size: os,
                    mood: ottoMood,
                    look: ottoLook,
                    lid: ottoLid,
                    lean: ottoLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.72, y: -0.68),
                    secondaryLagDegrees: -ottoLean * 0.28
                )
                .position(ottoCenter)

                StoryTheaterActorView(
                    kind: .moss,
                    size: ms,
                    mood: mossMood,
                    look: mossLook,
                    lid: dark ? 0.20 : 0,
                    lean: mossLean,
                    hopLift: mossHopLift / max(1, ms),
                    hopping: step == 3 && p.isContactWindow,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.72, y: -0.68),
                    secondaryLagDegrees: step == 3 ? sin(p.followThrough * .pi) * 12.0 : -mossLean * 0.35
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: mossCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawMusicalAlcove(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        ottoPos: CGPoint,
        mossPos: CGPoint,
        mid: CGPoint,
        step: Int,
        p: LivingPhaseSample,
        flat: Bool,
        dark: Bool
    ) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xFAF6EC),
            dayBottom: Color(hex: 0xEDE3CE),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x17243F),
            dark: dark
        )

        // Soft symmetrical arched wall niche centered behind dialogue zone
        let archRect = CGRect(x: w * 0.20, y: h * 0.14, width: w * 0.60, height: h * 0.68)
        let archPath = Path(roundedRect: archRect, cornerRadius: archRect.width * 0.5)
        ctx.fill(
            archPath,
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x1E2D4D) : Color(hex: 0xF1EBDC),
                    dark ? Color(hex: 0x15223B) : Color(hex: 0xE5DCC8)
                ]),
                startPoint: CGPoint(x: archRect.midX, y: archRect.minY),
                endPoint: CGPoint(x: archRect.midX, y: archRect.maxY)
            )
        )

        // Two circular low eye-level felt pouf rugs anchoring left and right
        for cx in [w * 0.255, w * 0.745] {
            let rug = CGRect(x: cx - w * 0.14, y: h * 0.80, width: w * 0.28, height: h * 0.11)
            ctx.fill(
                Path(ellipseIn: rug),
                with: .color((dark ? Color(hex: 0x2B414D) : Color(hex: 0xD8E3CF)).opacity(0.90))
            )
        }

        switch step {
        case 0:
            // Eye-level calm sightline tether
            var tether = Path()
            tether.move(to: ottoPos)
            tether.addQuadCurve(to: mossPos, control: CGPoint(x: mid.x, y: mid.y - 10))
            ctx.stroke(
                tether,
                with: .color(Palette.amber.opacity(0.32 + 0.18 * sin(p.raw * .pi * 2.0))),
                style: StrokeStyle(lineWidth: 1.5, dash: [4, 5])
            )
        case 1:
            // Otto emits 3 staggered amber translucent sound bubbles drifting toward Moss
            for b in 0..<3 {
                let bt = max(0, min(1, p.action * 1.25 - Double(b) * 0.20))
                guard bt > 0.04 else { continue }
                let bx = ottoPos.x + (mossPos.x - ottoPos.x) * CGFloat(bt * 0.75)
                let by = ottoPos.y - sin(CGFloat(bt) * .pi) * h * 0.10 + CGFloat(b % 2 == 0 ? -4 : 6)
                let r = min(w, h) * CGFloat(0.022 + Double(b) * 0.008)
                let rect = CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2)
                ctx.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [Palette.amber.mix(with: .white, by: flat ? 0.16 : 0.38), Palette.amber]),
                        center: CGPoint(x: bx - r * 0.2, y: by - r * 0.2),
                        startRadius: 0,
                        endRadius: r * 1.4
                    )
                )
            }
        case 2:
            // Explicit quiet pause ring — empty center air
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: mid,
                baseRadius: min(w, h) * 0.13,
                progress: p.raw,
                tint: Palette.amber,
                dark: dark
            )
        default:
            // Moss responds with mint coo bubbles braiding with Otto's amber chime
            for b in 0..<3 {
                let bt = max(0, min(1, p.action * 1.2 - Double(b) * 0.18))
                guard bt > 0.04 else { continue }
                let bx = mossPos.x - (mossPos.x - ottoPos.x) * CGFloat(bt * 0.78)
                let by = mossPos.y - sin(CGFloat(bt) * .pi) * h * 0.11 + CGFloat(b == 1 ? -6 : 4)
                let r = min(w, h) * CGFloat(0.024 + Double(b) * 0.006)
                let col = dark ? Color(hex: 0x8CD9A3) : Color(hex: 0x6BA97B)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: bx - r, y: by - r, width: r * 2, height: r * 2)),
                    with: .color(col.opacity(0.84))
                )
            }
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: mid,
                pulse: p.contact,
                radius: min(w, h) * 0.09,
                color: Palette.amber
            )
        }
    }
}
