import SwiftUI

/// A16 (Follow Their Gaze & Name · 4 Steps):
/// Sunlit nursery wall with a low birch display shelf holding a carved wooden songbird, terracotta cup, and sage bowl:
/// Step 0: Moss gazes up toward the wooden songbird while Otto follows Moss's exact sightline ->
/// Step 1: Otto names the bird in calm warmth (`drawSilkVoiceRibbon`) as the lamp illuminates it ->
/// Step 2: Quiet golden waiting pause halo for Moss to respond ->
/// Step 3: Bird gently rocks/lifts in shared action repetition with warm echo ribbon and joyful hop.
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

            let ms = s * 0.36
            let os = ms * Kind.otto.scale
            let groundY = h * 0.865

            let ottoX = w * 0.25
            let mossX = w * 0.70
            let birdAnchor = CGPoint(x: w * 0.44, y: h * 0.34)

            let birdRockDeg: Double = step == 3 ? sin(p.action * .pi * 2.0) * 10.0 : 0.0
            let birdLift: CGFloat = step == 3 ? CGFloat(max(0.0, sin(p.action * .pi))) * s * 0.045 : 0

            let mossHopLift: CGFloat = (step == 3 && p.raw >= 0.46)
                ? CGFloat(max(0.0, sin((p.raw - 0.46) / 0.34 * .pi))) * ms * 0.095
                : 0
            let ottoLean: Double = step == 1 ? 6.5 * p.action : (step == 3 ? 5.0 : 3.0)
            let mossLean: Double = step == 2 ? -5.0 * p.action : (step == 3 ? -7.5 * p.contact : -3.5)

            // Both look cleanly up toward the carved songbird on the birch shelf
            let ottoLook = CGPoint(x: 0.56, y: -0.58)
            let mossLook = CGPoint(x: -0.68, y: -0.62)

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
                    drawSightlineShelfStage(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        birdAnchor: CGPoint(x: birdAnchor.x, y: birdAnchor.y - birdLift),
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

    private func drawSightlineShelfStage(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        birdAnchor: CGPoint,
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

        // Low wall-mounted birch display shelf at top center
        let shelfY = h * 0.39
        let shelfRect = CGRect(x: w * 0.31, y: shelfY, width: w * 0.42, height: 10)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: shelfRect.midX, y: shelfRect.maxY + 3), rx: shelfRect.width * 0.46, ry: 4, dark: dark)
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(roundedRect: shelfRect, cornerRadius: 4), bounds: shelfRect, dark: dark, warmth: 0.6, grainLines: 2)

        // Secondary shelf items: sage bowl on right
        let bowlRect = CGRect(x: w * 0.60, y: shelfY - 14, width: 26, height: 14)
        var bowl = Path()
        bowl.addArc(center: CGPoint(x: bowlRect.midX, y: bowlRect.minY), radius: 13, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        bowl.closeSubpath()
        ctx.fill(bowl, with: .color(Crayon.teal.opacity(dark ? 0.72 : 0.85)))

        // Carved wooden songbird at birdAnchor (main joint-attention object)
        let birdS = min(w, h) * 0.11
        var bCtx = ctx
        bCtx.translateBy(x: birdAnchor.x, y: birdAnchor.y)
        bCtx.rotate(by: .degrees(birdRockDeg))
        bCtx.translateBy(x: -birdAnchor.x, y: -birdAnchor.y)

        let bodyRect = CGRect(x: birdAnchor.x - birdS * 0.45, y: birdAnchor.y - birdS * 0.25, width: birdS * 0.90, height: birdS * 0.62)
        var birdPath = Path(ellipseIn: bodyRect)
        // Wing tail wedge
        var tail = Path()
        tail.move(to: CGPoint(x: bodyRect.minX + 2, y: bodyRect.midY))
        tail.addLine(to: CGPoint(x: bodyRect.minX - birdS * 0.30, y: bodyRect.minY - birdS * 0.08))
        tail.addLine(to: CGPoint(x: bodyRect.minX + birdS * 0.15, y: bodyRect.midY + birdS * 0.16))
        tail.closeSubpath()
        birdPath.addPath(tail)

        let birdTint = Crayon.sunflower
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &bCtx,
                path: birdPath,
                bounds: bodyRect,
                light: birdTint.mix(with: .white, by: 0.25),
                rich: birdTint,
                pencilOutline: (dark ? Color(hex: 0xF5D26B) : Color(hex: 0x7A5410)).opacity(0.65),
                lineWidth: 1.1
            )
        } else {
            PixarDrawHelpers.drawBeechwood(in: &bCtx, path: birdPath, bounds: bodyRect, dark: dark, warmth: 0.9, grainLines: 1)
        }
        // Tiny warm beak & eye
        var beak = Path()
        beak.move(to: CGPoint(x: bodyRect.maxX - 2, y: bodyRect.midY - 3))
        beak.addLine(to: CGPoint(x: bodyRect.maxX + birdS * 0.22, y: bodyRect.midY))
        beak.addLine(to: CGPoint(x: bodyRect.maxX - 2, y: bodyRect.midY + 3))
        beak.closeSubpath()
        bCtx.fill(beak, with: .color(Crayon.tangerine))
        bCtx.fill(Path(ellipseIn: CGRect(x: bodyRect.maxX - birdS * 0.24, y: bodyRect.minY + birdS * 0.18, width: 3.2, height: 3.2)), with: .color(Color(hex: 0x222A38)))

        // Joint attention dotted gaze arc from Moss up to bird
        let mossEye = CGPoint(x: mossCenter.x - mossSize * 0.10, y: mossCenter.y - mossSize * 0.14)
        var gazeLine = Path()
        gazeLine.move(to: mossEye)
        gazeLine.addLine(to: CGPoint(x: birdAnchor.x + birdS * 0.15, y: birdAnchor.y + birdS * 0.32))
        ctx.stroke(
            gazeLine,
            with: .color(Palette.bead.opacity(step == 0 ? 0.55 * p.action + 0.25 : 0.35)),
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [4, 5])
        )

        // Focus ring around bird
        let focusR = birdS * (0.85 + 0.12 * CGFloat(p.contact))
        ctx.stroke(
            Path(ellipseIn: CGRect(x: birdAnchor.x - focusR, y: birdAnchor.y - focusR, width: focusR * 2, height: focusR * 2)),
            with: .color(Palette.amber.opacity(dark ? 0.45 : 0.35)),
            lineWidth: 1.6
        )

        // Step-specific cues
        let ottoVoice = CGPoint(x: ottoCenter.x + ottoSize * 0.16, y: ottoCenter.y - ottoSize * 0.12)
        let mossEar = CGPoint(x: mossCenter.x - mossSize * 0.18, y: mossCenter.y - mossSize * 0.08)

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
                lineWidth: 2.4,
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
                center: CGPoint(x: (ottoCenter.x + mossCenter.x) * 0.5, y: h * 0.62),
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
                lineWidth: 2.3,
                dark: dark
            )
            BespokeStageHelpers.drawContactSparkles(in: &ctx, center: birdAnchor, pulse: p.contact, radius: min(w, h) * 0.10, color: Palette.amber)
        }
    }
}
