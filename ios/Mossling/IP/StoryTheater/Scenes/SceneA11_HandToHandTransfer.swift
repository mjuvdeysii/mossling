import SwiftUI

/// A11 (Passing Hand to Hand · 3 Steps):
/// Circular woven cushion viewed from 3/4 high angle with vertical stitched midline seam and an
/// hourglass-waisted maple & sage/amber transfer rattle: Step 0: Offer within reach ->
/// Step 1: Smooth figure-8 midline transfer arc (-38 deg <-> +38 deg) with sparkle contact ->
/// Step 2: Otto steps gently back so baby rotates freely without nudging.
struct SceneA11_HandToHandTransfer: View {
    let ctx: BespokeSceneContext

    var body: some View {
        let step = min(max(0, ctx.stepIndex), 2)
        let p = ctx.phase
        let dark = ctx.dark
        let flat = ctx.flat

        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let h = max(1, geo.size.height)
            let s = min(w, h)

            let ms = s * 0.36
            let os = ms * Kind.otto.scale
            let groundY = h * 0.855

            let ottoX = w * (step == 2 ? 0.21 : 0.23)
            let mossX = w * 0.65

            // Hourglass rattle traverses right across Moss's midline seam
            let rattlePos: CGPoint = {
                let leftSpot = CGPoint(x: mossX - w * 0.145, y: groundY - s * 0.08)
                let midSpot = CGPoint(x: mossX, y: groundY - s * 0.14)
                let rightSpot = CGPoint(x: mossX + w * 0.145, y: groundY - s * 0.08)
                switch step {
                case 0:
                    let t = CGFloat(p.action)
                    return CGPoint(
                        x: w * 0.37 + (leftSpot.x - w * 0.37) * t,
                        y: groundY - s * 0.04 - CGFloat(sin(Double(t) * .pi) * 14.0)
                    )
                case 1:
                    let arc = p.action
                    let x = leftSpot.x + (rightSpot.x - leftSpot.x) * CGFloat(arc)
                    let y = leftSpot.y - CGFloat(sin(arc * .pi)) * s * 0.11
                    return CGPoint(x: x, y: y)
                default:
                    let sway = CGFloat(sin(p.raw * .pi * 2.0) * 12.0)
                    return CGPoint(x: midSpot.x + sway, y: groundY - s * 0.075)
                }
            }()

            let rattleAngle: Double = {
                switch step {
                case 0: return -24.0 * (1.0 - p.action)
                case 1: return -38.0 + 76.0 * p.action
                default: return sin(p.raw * .pi * 2.0) * 28.0
                }
            }()

            let ottoLean: Double = {
                switch step {
                case 0: return 9.0 * p.action
                case 1: return 2.5
                default: return -3.5
                }
            }()
            let mossLean: Double = {
                switch step {
                case 0: return -4.0 * p.action
                case 1: return -6.0 + 12.0 * p.action
                default: return sin(p.raw * .pi * 2.0) * 4.0
                }
            }()

            let dx = max(-1.0, min(1.0, Double((rattlePos.x - w * mossX / max(1, w)) / max(1, w * 0.25))))
            let mossLook = CGPoint(x: dx, y: 0.38)
            let ottoLook = CGPoint(x: 0.78, y: 0.18)

            let mossMood: Mood = step == 1 ? (p.isContactWindow ? .happy : .wow) : (step == 2 ? .happy : .open)
            let ottoMood: Mood = step == 2 ? .open : .happy

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat)
            )

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.40 : 0.24, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawMidlineCushionAndRattle(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        mossX: mossX,
                        groundY: groundY,
                        rattlePos: rattlePos,
                        rattleAngle: rattleAngle,
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: rattlePos,
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
                    lid: dark ? 0.40 : 0.24,
                    lean: ottoLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.78, y: -0.62),
                    secondaryLagDegrees: -ottoLean * 0.30
                )
                .position(ottoCenter)

                StoryTheaterActorView(
                    kind: .moss,
                    size: ms,
                    mood: mossMood,
                    look: mossLook,
                    lid: dark ? 0.16 : 0,
                    lean: mossLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.78, y: -0.62),
                    secondaryLagDegrees: -mossLean * 0.48
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: rattlePos,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawMidlineCushionAndRattle(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        mossX: CGFloat,
        groundY: CGFloat,
        rattlePos: CGPoint,
        rattleAngle: Double,
        step: Int,
        p: LivingPhaseSample,
        flat: Bool,
        dark: Bool
    ) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xFAF7ED),
            dayBottom: Color(hex: 0xECE5D1),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        // Circular woven cushion centered around Moss's midline workspace
        let matRect = CGRect(x: -6, y: h * 0.73, width: w + 12, height: h * 0.29)
        ctx.fill(
            Path(matRect),
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x203048) : Color(hex: 0xF3EBDA),
                    dark ? Color(hex: 0x141F32) : Color(hex: 0xD9CEB8)
                ]),
                startPoint: CGPoint(x: w * 0.5, y: h * 0.73),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Subtle dashed midline axis in front of Moss
        var seam = Path()
        seam.move(to: CGPoint(x: mossX, y: h * 0.74))
        seam.addLine(to: CGPoint(x: mossX, y: groundY + 12))
        ctx.stroke(
            seam,
            with: .color((dark ? Palette.amber : Crayon.caramel).opacity(dark ? 0.35 : 0.40)),
            style: StrokeStyle(lineWidth: 1.4, dash: [4, 4])
        )

        // Step 1 transfer arc preview trail
        if step == 1 {
            var trail = Path()
            let leftX = mossX - w * 0.145
            let rightX = mossX + w * 0.145
            let baseY = groundY - min(w, h) * 0.08
            trail.move(to: CGPoint(x: leftX, y: baseY))
            trail.addQuadCurve(
                to: CGPoint(x: rightX, y: baseY),
                control: CGPoint(x: mossX, y: baseY - min(w, h) * 0.20)
            )
            ctx.stroke(
                trail,
                with: .color(Palette.amber.opacity(dark ? 0.45 : 0.38)),
                style: StrokeStyle(lineWidth: 1.8, dash: [5, 5])
            )
        }

        // Hourglass-waisted beechwood transfer rattle
        let len = min(w, h) * 0.115
        PixarDrawHelpers.drawContactAO(
            in: &ctx,
            center: CGPoint(x: rattlePos.x, y: groundY + 2),
            rx: len * 0.46,
            ry: len * 0.16,
            dark: dark
        )

        var rCtx = ctx
        rCtx.translateBy(x: rattlePos.x, y: rattlePos.y)
        rCtx.rotate(by: .degrees(rattleAngle))

        let stemRect = CGRect(x: -len * 0.44, y: -len * 0.11, width: len * 0.88, height: len * 0.22)
        PixarDrawHelpers.drawBeechwood(
            in: &rCtx,
            path: Path(roundedRect: stemRect, cornerRadius: len * 0.10),
            bounds: stemRect,
            dark: dark,
            warmth: 0.8,
            grainLines: 2
        )

        let capR = len * 0.25
        for (cx, col) in [(-len * 0.44, Color(hex: 0x7EB48B)), (len * 0.44, Palette.amber)] {
            let capRect = CGRect(x: cx - capR, y: -capR, width: capR * 2, height: capR * 2)
            rCtx.fill(
                Path(ellipseIn: capRect),
                with: .radialGradient(
                    Gradient(colors: [col.mix(with: .white, by: flat ? 0.15 : 0.32), col]),
                    center: CGPoint(x: cx - capR * 0.25, y: -capR * 0.25),
                    startRadius: 0,
                    endRadius: capR * 1.3
                )
            )
            if flat {
                rCtx.stroke(Path(ellipseIn: capRect), with: .color(Color(hex: 0x4E4234).opacity(0.45)), lineWidth: 0.9)
            }
        }

        if step == 1 {
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: CGPoint(x: mossX, y: groundY - min(w, h) * 0.15),
                pulse: p.contact,
                radius: min(w, h) * 0.095,
                color: Palette.amber
            )
        } else if step == 2 {
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: mossX, y: groundY - min(w, h) * 0.08),
                baseRadius: min(w, h) * 0.12,
                progress: p.raw,
                tint: Crayon.leaf,
                dark: dark
            )
        }
    }
}
