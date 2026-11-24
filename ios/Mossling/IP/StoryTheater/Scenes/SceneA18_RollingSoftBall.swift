import SwiftUI

/// A18 (Rolling a Soft Ball · 3 Steps):
/// Low-angle woven runner corridor between Otto and Moss with a 6-panel stitched cloth Montessori ball
/// rotating physically along the floor (`angle = dx / r`) with dynamic moving Contact AO:
/// Step 0: Short gentle roll from Otto toward Moss ->
/// Step 1: Quiet wait pause halo, then Moss touches & nudges ball back ->
/// Step 2: Wider floor separation with continuous back-and-forth rolling turns.
struct SceneA18_RollingSoftBall: View {
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

            let ms = s * 0.35
            let os = ms * Kind.otto.scale
            let groundY = h * 0.855

            let ottoX: CGFloat = step == 2 ? w * 0.17 : w * 0.25
            let mossX: CGFloat = step == 2 ? w * 0.83 : w * 0.75

            let ballR = s * 0.072
            let leftStop = ottoX + os * 0.42
            let rightStop = mossX - ms * 0.42

            let ballFrac: CGFloat = {
                switch step {
                case 0:
                    return CGFloat(p.action)
                case 1:
                    if p.raw < 0.28 { return 1.0 }
                    let back = (p.raw - 0.28) / 0.52
                    return 1.0 - CGFloat(LivingMotionClock.easeOutCubic(min(1.0, max(0.0, back))))
                default:
                    return CGFloat(0.5 - 0.5 * cos(p.raw * .pi * 2.0))
                }
            }()

            let ballX = leftStop + (rightStop - leftStop) * ballFrac
            let ballPos = CGPoint(x: ballX, y: groundY - ballR + 2)
            let ballSpinRadians = Double((ballX - leftStop) / max(1, ballR))

            let mossHopLift: CGFloat = (step == 1 && p.raw >= 0.44 && p.raw < 0.78)
                ? CGFloat(max(0.0, sin((p.raw - 0.44) / 0.34 * .pi))) * ms * 0.09
                : 0
            let ottoLean: Double = step == 0 ? 7.5 * p.action : (step == 2 ? 4.5 : 2.5)
            let mossLean: Double = step == 1 ? -8.5 * p.contactEnvelope : (step == 2 ? -5.0 : -3.5)

            // Both characters' eyes smoothly track the rolling cloth ball across the runner
            let ottoDx = max(-0.9, min(0.9, Double((ballX - ottoX) / max(1, w * 0.45))))
            let mossDx = max(-0.9, min(0.9, Double((ballX - mossX) / max(1, w * 0.45))))
            let ottoLook = CGPoint(x: ottoDx, y: 0.38)
            let mossLook = CGPoint(x: mossDx, y: 0.38)

            let ottoMood: Mood = step == 2 ? .happy : .open
            let mossMood: Mood = step == 0 ? (p.raw >= 0.45 ? .wow : .open) : .happy

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat, lift: mossHopLift)
            )

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.36 : 0.22, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawRunnerAndBall(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        leftStop: leftStop,
                        rightStop: rightStop,
                        ballPos: ballPos,
                        ballR: ballR,
                        spinRad: ballSpinRadians,
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: ballPos,
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
                    lid: dark ? 0.36 : 0.22,
                    lean: ottoLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.72, y: -0.66),
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
                    hopLift: mossHopLift / max(1, ms),
                    hopping: step == 1 && mossHopLift > ms * 0.03,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.72, y: -0.66),
                    secondaryLagDegrees: -mossLean * 0.42
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: ballPos,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawRunnerAndBall(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        leftStop: CGFloat,
        rightStop: CGFloat,
        ballPos: CGPoint,
        ballR: CGFloat,
        spinRad: Double,
        step: Int,
        p: LivingPhaseSample,
        flat: Bool,
        dark: Bool
    ) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xFAF6EB),
            dayBottom: Color(hex: 0xEDE4CE),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        // Corridor floor & long woven striped rug runner
        let floorRect = CGRect(x: -6, y: h * 0.74, width: w + 12, height: h * 0.28)
        ctx.fill(
            Path(floorRect),
            with: .linearGradient(
                Gradient(colors: [dark ? Color(hex: 0x1E2A44) : Color(hex: 0xEFE6D1), dark ? Color(hex: 0x131B2E) : Color(hex: 0xD8CCB4)]),
                startPoint: CGPoint(x: w * 0.5, y: h * 0.74),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        let runnerRect = CGRect(x: w * 0.09, y: groundY - 5, width: w * 0.82, height: 18)
        let runnerPath = Path(roundedRect: runnerRect, cornerRadius: 8)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: runnerPath,
                bounds: runnerRect,
                light: dark ? Color(hex: 0x283B55) : Color(hex: 0xE6EFE0),
                rich: dark ? Color(hex: 0x1C2B40) : Color(hex: 0xC6D8BE),
                pencilOutline: (dark ? Color(hex: 0x5A7B9E) : Color(hex: 0x6F8C6A)).opacity(0.55),
                lineWidth: 1.2
            )
        } else {
            ctx.fill(runnerPath, with: .color(dark ? Color(hex: 0x263852) : Color(hex: 0xD5E3CE)))
        }

        // Dotted floor roll line connecting Otto & Moss
        var track = Path()
        track.move(to: CGPoint(x: leftStop, y: groundY - 1))
        track.addLine(to: CGPoint(x: rightStop, y: groundY - 1))
        ctx.stroke(track, with: .color(Palette.bead.opacity(0.45)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [4, 5]))

        if step == 1 && p.raw < 0.30 {
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: rightStop - 4, y: ballPos.y - ballR * 0.3),
                baseRadius: min(w, h) * 0.10,
                progress: p.raw / 0.30,
                tint: Palette.amber,
                dark: dark
            )
        }

        // 6-panel stitched cloth Montessori ball with live rolling spin
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: ballPos.x, y: groundY + 2.5), rx: ballR * 0.92, ry: ballR * 0.26, dark: dark)

        let bRect = CGRect(x: ballPos.x - ballR, y: ballPos.y - ballR, width: ballR * 2, height: ballR * 2)
        var bCtx = ctx
        bCtx.clip(to: Path(ellipseIn: bRect))
        bCtx.fill(
            Path(ellipseIn: bRect),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFF2D0), Crayon.tangerine, Color(hex: 0xB85934)]),
                center: CGPoint(x: ballPos.x - ballR * 0.3, y: ballPos.y - ballR * 0.3),
                startRadius: 1,
                endRadius: ballR * 1.35
            )
        )

        // Rotating sewn fabric wedge panels
        bCtx.translateBy(x: ballPos.x, y: ballPos.y)
        bCtx.rotate(by: .radians(spinRad))
        for k in 0..<3 {
            let ang = Double(k) * .pi / 3.0
            let dx = CGFloat(cos(ang)) * ballR
            let dy = CGFloat(sin(ang)) * ballR
            var seam = Path()
            seam.move(to: CGPoint(x: -dx, y: -dy))
            seam.addQuadCurve(
                to: CGPoint(x: dx, y: dy),
                control: CGPoint(x: -dy * 0.45, y: dx * 0.45)
            )
            bCtx.stroke(seam, with: .color(Color(hex: 0xFFF8E8).opacity(0.70)), style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2.5]))
        }
        bCtx.fill(Path(ellipseIn: CGRect(x: -ballR * 0.22, y: -ballR * 0.22, width: ballR * 0.44, height: ballR * 0.44)), with: .color(Crayon.teal.opacity(0.88)))

        if flat {
            ctx.stroke(Path(ellipseIn: bRect), with: .color(Color(hex: 0x7A3D22).opacity(0.62)), lineWidth: 1.1)
        }

        if step >= 1 {
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: ballPos,
                pulse: p.contact * 0.85,
                radius: ballR * 1.4,
                color: Palette.amber
            )
        }
    }
}
