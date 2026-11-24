import SwiftUI

/// A16 (Follow Their Gaze & Name · 4 Steps):
/// Natural side-by-side joint-attention alcove:
/// Otto (0.21) & Moss (0.44) stand together on the left floor looking RIGHT toward a grounded
/// birch Montessori display cabinet on the right (`x: 0.64..0.90`, legs anchored on `groundY`):
/// Step 0: Moss gazes up toward the carved songbird first -> Otto shifts sightline onto exact same object ->
/// Step 1: Otto names the bird in warm light (`drawSilkVoiceRibbon` + cone) ->
/// Step 2: Golden pause halo waiting patiently for response ->
/// Step 3: Bird rocks softly on its grounded wooden rocker arc (zero levitation) as Moss hops joyfully.
struct SceneA16_FollowGazeName: View {
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

            let ms = s * 0.35
            let os = ms * Kind.otto.scale
            let groundY = h * 0.865

            let ottoX = w * 0.21
            let mossX = w * 0.44

            let cabTopY = h * 0.54
            let birdS = s * 0.115
            let birdBaseY = cabTopY - 2
            let birdAnchor = CGPoint(x: w * 0.72, y: birdBaseY - birdS * 0.26)
            let birdRockDeg: Double = step == 3 ? sin(p.action * .pi * 2.0) * 10.5 : 0.0

            let mossHopLift: CGFloat = (step == 3 && p.raw >= 0.46)
                ? CGFloat(max(0.0, sin((p.raw - 0.46) / 0.34 * .pi))) * ms * 0.09
                : 0
            let ottoLean: Double = step == 1 ? 6.5 * p.action : (step == 3 ? 5.0 : 3.5)
            let mossLean: Double = step == 2 ? 5.0 * p.action : (step == 3 ? 7.0 * p.contact : 4.0)

            // Both share sightline RIGHT toward the songbird on the grounded cabinet; in step 0 Otto tracks from Moss to bird
            let ottoLookX = step == 0 ? 0.48 + 0.34 * p.action : 0.82
            let ottoLook = CGPoint(x: ottoLookX, y: -0.34)
            let mossLook = CGPoint(x: 0.78, y: -0.44)

            let mossMood: Mood = step == 3 ? (p.raw >= 0.42 ? .happy : .wow) : (step == 2 ? .wow : .open)
            let ottoMood: Mood = step >= 1 ? .happy : .open

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
                    drawSightlineCabinetStage(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        cabTopY: cabTopY,
                        birdAnchor: birdAnchor,
                        birdBaseY: birdBaseY,
                        birdS: birdS,
                        birdRockDeg: birdRockDeg,
                        ottoCenter: ottoCenter,
                        ottoSize: os,
                        mossCenter: mossCenter,
                        mossSize: ms,
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: birdAnchor,
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
                    lightDirection: CGPoint(x: 0.72, y: -0.65),
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
                    hopping: step == 3 && p.isContactWindow,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.72, y: -0.65),
                    secondaryLagDegrees: -mossLean * 0.42
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: birdAnchor,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawSightlineCabinetStage(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        cabTopY: CGFloat,
        birdAnchor: CGPoint,
        birdBaseY: CGFloat,
        birdS: CGFloat,
        birdRockDeg: Double,
        ottoCenter: CGPoint,
        ottoSize: CGFloat,
        mossCenter: CGPoint,
        mossSize: CGFloat,
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
            dayBottom: Color(hex: 0xEDE4CF),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        if flat {
            GhibliDrawHelpers.drawKomorebiCanopy(in: &ctx, w: w, h: h, swayOffset: 0, dark: dark)
        }

        // Low floor horizon
        let floorRect = CGRect(x: -6, y: h * 0.75, width: w + 12, height: h * 0.27)
        ctx.fill(
            Path(floorRect),
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x1E2A44) : Color(hex: 0xEFE5D0),
                    dark ? Color(hex: 0x131B2E) : Color(hex: 0xD9CEB7)
                ]),
                startPoint: CGPoint(x: w * 0.5, y: h * 0.75),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Grounded low birch Montessori display cabinet on the right resting solidly on groundY
        let cabLeft = w * 0.62
        let cabWidth = w * 0.29
        let cabH = max(24, groundY - cabTopY)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: cabLeft + cabWidth * 0.5, y: groundY + 2), rx: cabWidth * 0.52, ry: 5, dark: dark)

        let bodyRect = CGRect(x: cabLeft + 6, y: cabTopY + 8, width: cabWidth - 12, height: cabH - 6)
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(roundedRect: bodyRect, cornerRadius: 5), bounds: bodyRect, dark: dark, warmth: 0.48, grainLines: 2)
        // Open lower cubby niche for authentic cabinet depth
        let cubbyRect = bodyRect.insetBy(dx: 8, dy: 9)
        ctx.fill(Path(roundedRect: cubbyRect, cornerRadius: 3), with: .color((dark ? Color(hex: 0x131D30) : Color(hex: 0xCBB187)).opacity(0.85)))

        // Cabinet top plank
        let topRect = CGRect(x: cabLeft, y: cabTopY, width: cabWidth, height: 10)
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(roundedRect: topRect, cornerRadius: 4), bounds: topRect, dark: dark, warmth: 0.68, grainLines: 2)

        // Secondary cabinet item: sage bowl resting cleanly at right side of cabinet top
        let bowlRect = CGRect(x: w * 0.81, y: cabTopY - 12, width: 22, height: 12)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: bowlRect.midX, y: cabTopY), rx: 10, ry: 2.0, dark: dark)
        var bowl = Path()
        bowl.addArc(center: CGPoint(x: bowlRect.midX, y: bowlRect.minY), radius: 11, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        bowl.closeSubpath()
        ctx.fill(bowl, with: .color(Crayon.teal.opacity(dark ? 0.72 : 0.85)))

        // Carved wooden songbird resting on curved rocker base grounded at birdBaseY (rocks cleanly in Step 3 without levitating)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: birdAnchor.x, y: birdBaseY + 1), rx: birdS * 0.45, ry: 2.6, dark: dark)
        var bCtx = ctx
        bCtx.translateBy(x: birdAnchor.x, y: birdBaseY)
        bCtx.rotate(by: .degrees(birdRockDeg))
        bCtx.translateBy(x: -birdAnchor.x, y: -birdBaseY)

        // Small wooden crescent rocker base at cabinet top
        let rockerRect = CGRect(x: birdAnchor.x - birdS * 0.34, y: birdBaseY - 4, width: birdS * 0.68, height: 4)
        bCtx.fill(Path(roundedRect: rockerRect, cornerRadius: 2), with: .color(Crayon.caramel))

        let bodyRectB = CGRect(x: birdAnchor.x - birdS * 0.44, y: birdAnchor.y - birdS * 0.32, width: birdS * 0.88, height: birdS * 0.60)
        var birdPath = Path(ellipseIn: bodyRectB)
        var tail = Path()
        tail.move(to: CGPoint(x: bodyRectB.maxX - 2, y: bodyRectB.midY))
        tail.addLine(to: CGPoint(x: bodyRectB.maxX + birdS * 0.28, y: bodyRectB.minY - birdS * 0.06))
        tail.addLine(to: CGPoint(x: bodyRectB.maxX - birdS * 0.14, y: bodyRectB.midY + birdS * 0.16))
        tail.closeSubpath()
        birdPath.addPath(tail)

        let birdTint = Crayon.sunflower
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &bCtx,
                path: birdPath,
                bounds: bodyRectB,
                light: birdTint.mix(with: .white, by: 0.25),
                rich: birdTint,
                pencilOutline: (dark ? Color(hex: 0xF5D26B) : Color(hex: 0x7A5410)).opacity(0.65),
                lineWidth: 1.1
            )
        } else {
            PixarDrawHelpers.drawBeechwood(in: &bCtx, path: birdPath, bounds: bodyRectB, dark: dark, warmth: 0.9, grainLines: 1)
        }
        // Tiny warm beak facing left toward Moss & Otto
        var beak = Path()
        beak.move(to: CGPoint(x: bodyRectB.minX + 2, y: bodyRectB.midY - 3))
        beak.addLine(to: CGPoint(x: bodyRectB.minX - birdS * 0.22, y: bodyRectB.midY))
        beak.addLine(to: CGPoint(x: bodyRectB.minX + 2, y: bodyRectB.midY + 3))
        beak.closeSubpath()
        bCtx.fill(beak, with: .color(Crayon.tangerine))
        bCtx.fill(Path(ellipseIn: CGRect(x: bodyRectB.minX + birdS * 0.20, y: bodyRectB.minY + birdS * 0.18, width: 3.2, height: 3.2)), with: .color(Color(hex: 0x222A38)))

        // Joint attention dotted sightline from Moss up-right to bird
        let mossEye = CGPoint(x: mossCenter.x + mossSize * 0.12, y: mossCenter.y - mossSize * 0.12)
        var gazeLine = Path()
        gazeLine.move(to: mossEye)
        gazeLine.addLine(to: CGPoint(x: birdAnchor.x - birdS * 0.26, y: birdAnchor.y + birdS * 0.08))
        ctx.stroke(
            gazeLine,
            with: .color(Palette.bead.opacity(step == 0 ? 0.55 * p.action + 0.25 : 0.35)),
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [4, 5])
        )

        // Focus ring around bird
        let focusR = birdS * (0.82 + 0.10 * CGFloat(p.contact))
        ctx.stroke(
            Path(ellipseIn: CGRect(x: birdAnchor.x - focusR, y: birdAnchor.y - focusR, width: focusR * 2, height: focusR * 2)),
            with: .color(Palette.amber.opacity(dark ? 0.45 : 0.35)),
            lineWidth: 1.6
        )

        let ottoVoice = CGPoint(x: ottoCenter.x + ottoSize * 0.16, y: ottoCenter.y - ottoSize * 0.10)
        let mossEar = CGPoint(x: mossCenter.x - mossSize * 0.16, y: mossCenter.y - mossSize * 0.08)

        switch step {
        case 0:
            BespokeStageHelpers.drawContactSparkles(in: &ctx, center: birdAnchor, pulse: p.contact, radius: min(w, h) * 0.09, color: Palette.amber)
        case 1:
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoVoice,
                to: birdAnchor,
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Palette.amber,
                lineWidth: 2.3,
                dark: dark
            )
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: birdAnchor,
                to: mossEar,
                progress: p.followThrough,
                waveOffset: p.raw * .pi * 2.0 + 1.0,
                color: Crayon.teal,
                lineWidth: 2.0,
                dark: dark
            )
        case 2:
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: (mossCenter.x + birdAnchor.x) * 0.5, y: h * 0.56),
                baseRadius: min(w, h) * 0.11,
                progress: p.raw * 1.3,
                tint: Palette.amber,
                dark: dark
            )
        default:
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoVoice,
                to: mossEar,
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Palette.amber,
                lineWidth: 2.2,
                dark: dark
            )
            BespokeStageHelpers.drawContactSparkles(in: &ctx, center: birdAnchor, pulse: p.contact, radius: min(w, h) * 0.10, color: Palette.amber)
        }
    }
}
