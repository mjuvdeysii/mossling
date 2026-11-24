import SwiftUI

/// A14 (In and Out of a Basket · 3 Steps):
/// Warm parquet floor with a two-layer hand-woven low rattan treasure basket (back wall behind the ball,
/// front braided lip in front of the ball so dropping inside looks physically three-dimensional):
/// Step 0: Otto arcs chunky terracotta wooden ball IN ->
/// Step 1: Moss reaches into rim & pulls ball OUT ->
/// Step 2: Dotted trajectory curves & "in" / "out" silk narration ribbons.
struct SceneA14_BasketInOut: View {
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

            let ottoX = w * 0.22
            let mossX = w * 0.77
            let basketCenter = CGPoint(x: w * 0.50, y: groundY - s * 0.045)
            let insideRest = CGPoint(x: basketCenter.x, y: basketCenter.y + s * 0.015)
            let startOutsideLeft = CGPoint(x: w * 0.35, y: groundY - s * 0.04)
            let endOutsideRight = CGPoint(x: w * 0.635, y: groundY - s * 0.04)

            // Ball arc position & front/back layer depth inside woven basket
            let ballPos: CGPoint = {
                switch step {
                case 0:
                    let t = CGFloat(p.action)
                    let x = startOutsideLeft.x + (insideRest.x - startOutsideLeft.x) * t
                    let y = startOutsideLeft.y + (insideRest.y - startOutsideLeft.y) * t - CGFloat(sin(Double(t) * .pi)) * s * 0.22
                    return CGPoint(x: x, y: y)
                case 1:
                    let t = CGFloat(p.action)
                    let x = insideRest.x + (endOutsideRight.x - insideRest.x) * t
                    let y = insideRest.y + (endOutsideRight.y - insideRest.y) * t - CGFloat(sin(Double(t) * .pi)) * s * 0.21
                    return CGPoint(x: x, y: y)
                default:
                    let cycle = 0.5 - 0.5 * cos(p.raw * .pi * 2.0)
                    let x = insideRest.x + (endOutsideRight.x - insideRest.x) * CGFloat(cycle)
                    let y = insideRest.y - CGFloat(sin(cycle * .pi)) * s * 0.16
                    return CGPoint(x: x, y: y)
                }
            }()

            let mossHopLift: CGFloat = (step == 1 && p.raw >= 0.48)
                ? CGFloat(max(0.0, sin((p.raw - 0.48) / 0.34 * .pi))) * ms * 0.10
                : 0
            let ottoLean: Double = step == 0 ? 9.5 * p.action : 4.0
            let mossLean: Double = step == 1 ? -10.5 * p.action : -4.5

            let dx = max(-1.0, min(1.0, Double((ballPos.x - w * mossX / max(1, w)) / max(1, w * 0.35))))
            let mossLook = CGPoint(x: dx, y: 0.28)
            let ottoLook = CGPoint(x: 0.75, y: 0.28)
            let ottoMood: Mood = step == 2 ? .happy : .open
            let mossMood: Mood = step == 1 ? (p.raw >= 0.46 ? .happy : .wow) : (step == 2 ? .happy : .open)

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat, lift: mossHopLift)
            )

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.38 : 0.24, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawParquetFloor(in: &c, w: size.width, h: size.height, flat: flat, dark: dark)
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: basketCenter,
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
                    lid: dark ? 0.38 : 0.24,
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
                    hopLift: mossHopLift / max(1, ms),
                    hopping: step == 1 && p.isContactWindow,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.78, y: -0.62),
                    secondaryLagDegrees: -mossLean * 0.44
                )
                .position(mossCenter)

                // Back basket cavity -> wooden sphere -> front woven basket lip (3D containment occlusion!)
                Canvas(rendersAsynchronously: false) { c, size in
                    drawLayeredBasketAndBall(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        basketCenter: basketCenter,
                        groundY: groundY,
                        ballPos: ballPos,
                        startOutsideLeft: startOutsideLeft,
                        endOutsideRight: endOutsideRight,
                        insideRest: insideRest,
                        ottoVoice: CGPoint(x: ottoCenter.x + os * 0.18, y: ottoCenter.y - os * 0.05),
                        mossEar: CGPoint(x: mossCenter.x - ms * 0.18, y: mossCenter.y - ms * 0.05),
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: basketCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawParquetFloor(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, flat: Bool, dark: Bool) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xFAF7ED),
            dayBottom: Color(hex: 0xECE4D0),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        let horizonY = h * 0.74
        let rugRect = CGRect(x: -6, y: horizonY, width: w + 12, height: h - horizonY + 8)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: Path(rugRect),
                bounds: rugRect,
                light: dark ? Color(hex: 0x203048) : Color(hex: 0xF3EBD8),
                rich: dark ? Color(hex: 0x141F32) : Color(hex: 0xDAD0B8),
                pencilOutline: (dark ? Color(hex: 0x526A90) : Color(hex: 0x9C8F77)).opacity(0.42),
                lineWidth: 1.2
            )
        } else {
            ctx.fill(
                Path(rugRect),
                with: .linearGradient(
                    Gradient(colors: [
                        dark ? Color(hex: 0x22304A) : Color(hex: 0xF5EEDD),
                        dark ? Color(hex: 0x141F32) : Color(hex: 0xDBD0B8)
                    ]),
                    startPoint: CGPoint(x: w * 0.5, y: horizonY),
                    endPoint: CGPoint(x: w * 0.5, y: h)
                )
            )
        }
    }

    private func drawLayeredBasketAndBall(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        basketCenter: CGPoint,
        groundY: CGFloat,
        ballPos: CGPoint,
        startOutsideLeft: CGPoint,
        endOutsideRight: CGPoint,
        insideRest: CGPoint,
        ottoVoice: CGPoint,
        mossEar: CGPoint,
        step: Int,
        p: LivingPhaseSample,
        flat: Bool,
        dark: Bool
    ) {
        let bw = min(w, h) * 0.25
        let bh = min(w, h) * 0.13
        let rimY = basketCenter.y - bh * 0.35

        PixarDrawHelpers.drawContactAO(
            in: &ctx,
            center: CGPoint(x: basketCenter.x, y: groundY + 2),
            rx: bw * 0.55,
            ry: bh * 0.25,
            dark: dark
        )

        // Dashed movement guide arc in Step 2 ("in" / "out")
        if step == 2 {
            var arc = Path()
            arc.move(to: insideRest)
            arc.addQuadCurve(
                to: endOutsideRight,
                control: CGPoint(x: (insideRest.x + endOutsideRight.x) * 0.5, y: insideRest.y - min(w, h) * 0.24)
            )
            ctx.stroke(arc, with: .color(Palette.amber.opacity(0.46)), style: StrokeStyle(lineWidth: 1.7, dash: [4, 4]))
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoVoice,
                to: mossEar,
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Crayon.teal,
                lineWidth: 2.2,
                dark: dark
            )
        }

        // Layer 1 (Back cavity inside rim)
        let mouthRect = CGRect(x: basketCenter.x - bw * 0.5, y: rimY - bh * 0.22, width: bw, height: bh * 0.44)
        ctx.fill(
            Path(ellipseIn: mouthRect),
            with: .color(dark ? Color(hex: 0x3D2614) : Color(hex: 0x7A5430))
        )

        // Layer 2 (Terracotta hardwood sphere)
        let ballR = min(w, h) * 0.052
        if ballPos.y >= rimY && abs(ballPos.x - basketCenter.x) > bw * 0.42 {
            PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: ballPos.x, y: groundY + 2), rx: ballR, ry: ballR * 0.26, dark: dark)
        }
        let bRect = CGRect(x: ballPos.x - ballR, y: ballPos.y - ballR, width: ballR * 2, height: ballR * 2)
        let sphereCol = Color(hex: 0xD97D54)
        ctx.fill(
            Path(ellipseIn: bRect),
            with: .radialGradient(
                Gradient(colors: [sphereCol.mix(with: .white, by: flat ? 0.14 : 0.36), sphereCol, Color(hex: 0x9F4A2B)]),
                center: CGPoint(x: ballPos.x - ballR * 0.28, y: ballPos.y - ballR * 0.28),
                startRadius: 1,
                endRadius: ballR * 1.35
            )
        )
        if flat {
            ctx.stroke(Path(ellipseIn: bRect), with: .color(Color(hex: 0x612F1A).opacity(0.6)), lineWidth: 1.0)
        }

        // Layer 3 (Front woven basket bowl overlapping bottom of ball when resting inside!)
        var frontBowl = Path()
        frontBowl.move(to: CGPoint(x: basketCenter.x - bw * 0.50, y: rimY))
        frontBowl.addQuadCurve(
            to: CGPoint(x: basketCenter.x - bw * 0.36, y: groundY + 1),
            control: CGPoint(x: basketCenter.x - bw * 0.48, y: basketCenter.y + bh * 0.35)
        )
        frontBowl.addQuadCurve(
            to: CGPoint(x: basketCenter.x + bw * 0.36, y: groundY + 1),
            control: CGPoint(x: basketCenter.x, y: groundY + 7)
        )
        frontBowl.addQuadCurve(
            to: CGPoint(x: basketCenter.x + bw * 0.50, y: rimY),
            control: CGPoint(x: basketCenter.x + bw * 0.48, y: basketCenter.y + bh * 0.35)
        )
        frontBowl.addQuadCurve(
            to: CGPoint(x: basketCenter.x - bw * 0.50, y: rimY),
            control: CGPoint(x: basketCenter.x, y: rimY + bh * 0.26)
        )
        frontBowl.closeSubpath()

        let bowlBounds = CGRect(x: basketCenter.x - bw * 0.5, y: rimY, width: bw, height: groundY - rimY + 6)
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: frontBowl, bounds: bowlBounds, dark: dark, warmth: 0.72, grainLines: 3)

        // Front braided top rim arc + vertical weave ribs
        var lip = Path()
        lip.move(to: CGPoint(x: basketCenter.x - bw * 0.50, y: rimY))
        lip.addQuadCurve(
            to: CGPoint(x: basketCenter.x + bw * 0.50, y: rimY),
            control: CGPoint(x: basketCenter.x, y: rimY + bh * 0.26)
        )
        ctx.stroke(lip, with: .color(dark ? Color(hex: 0xDFB174) : Color(hex: 0xC18A4D)), style: StrokeStyle(lineWidth: 3.4, lineCap: .round))

        for rib in -2...2 {
            let rx = basketCenter.x + CGFloat(rib) * bw * 0.16
            var wRib = Path()
            wRib.move(to: CGPoint(x: rx, y: rimY + bh * 0.14))
            wRib.addLine(to: CGPoint(x: rx * 0.92 + basketCenter.x * 0.08, y: groundY - 2))
            ctx.stroke(wRib, with: .color((dark ? Color(hex: 0x5C3A1C) : Color(hex: 0x8F5E2F)).opacity(0.45)), lineWidth: 1.1)
        }

        if step == 0 || step == 1 {
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: step == 0 ? insideRest : endOutsideRight,
                pulse: p.contact,
                radius: min(w, h) * 0.095,
                color: Palette.amber
            )
        }
    }
}
