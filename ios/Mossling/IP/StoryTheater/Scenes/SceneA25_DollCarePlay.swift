import SwiftUI

/// A25 (Doll Daily Care Play · 3 Steps):
/// Cozy nursery rug with grounded beechwood doll cradle & knitted plush bear + miniature wooden feeding bowl/spoon:
/// Step 0: Adult models gently drawing a soft quilted blanket up over the doll inside the cradle ->
/// Step 1: Child chooses either feeding with miniature spoon or soothing cradle rock ->
/// Step 2: Adult expands care narrative with warm silk voice ribbon and gentle care halo.
struct SceneA25_DollCarePlay: View {
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
            let groundY = h * 0.865

            let mossX = w * (step == 1 ? 0.28 : 0.24)
            let ottoX = w * 0.77
            let cradleCenter = CGPoint(x: w * 0.49, y: groundY - s * 0.068)

            let mossHopLift: CGFloat = (step == 1 && p.raw >= 0.46)
                ? CGFloat(max(0.0, sin((p.raw - 0.46) / 0.34 * .pi))) * ms * 0.095
                : 0
            let mossLean: Double = step == 1 ? 9.5 * p.action : 3.5
            let ottoLean: Double = step == 0 ? -8.5 * p.action : (step == 2 ? -5.5 : -3.0)

            let mossLook = CGPoint(x: 0.80, y: 0.26)
            let ottoLook = CGPoint(x: -0.78, y: 0.24)
            let mossMood: Mood = step == 1 ? (p.raw >= 0.44 ? .happy : .wow) : (step == 2 ? .happy : .open)
            let ottoMood: Mood = step >= 1 ? .happy : .open

            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat, lift: mossHopLift)
            )
            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY, flat: flat)
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
                    drawCradleAndDollStage(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        cradleCenter: cradleCenter,
                        mossX: mossX,
                        ottoVoice: CGPoint(x: ottoCenter.x - os * 0.18, y: ottoCenter.y - os * 0.06),
                        mossEar: CGPoint(x: mossCenter.x + ms * 0.18, y: mossCenter.y - ms * 0.06),
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: cradleCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .floorPool
                )

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
                    lightDirection: CGPoint(x: -0.76, y: -0.64),
                    secondaryLagDegrees: -mossLean * 0.42
                )
                .position(mossCenter)

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
                    lightDirection: CGPoint(x: -0.76, y: -0.64),
                    secondaryLagDegrees: -ottoLean * 0.30
                )
                .position(ottoCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: cradleCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawCradleAndDollStage(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        cradleCenter: CGPoint,
        mossX: CGFloat,
        ottoVoice: CGPoint,
        mossEar: CGPoint,
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
            dayBottom: Color(hex: 0xEDE2CD),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        if flat {
            GhibliDrawHelpers.drawKomorebiCanopy(in: &ctx, w: w, h: h, swayOffset: 0, dark: dark)
        }

        let s = min(w, h)
        let rugY = h * 0.745
        let rugRect = CGRect(x: -6, y: rugY, width: w + 12, height: h - rugY + 8)
        ctx.fill(
            Path(rugRect),
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x1D2A42) : Color(hex: 0xEFE5D0),
                    dark ? Color(hex: 0x131B2E) : Color(hex: 0xD8CCB4)
                ]),
                startPoint: CGPoint(x: w * 0.5, y: rugY),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Grounded miniature feeding bowl & spoon beside Moss's right edge
        let bowlCenter = CGPoint(x: w * 0.35, y: groundY - s * 0.018)
        let bowlW = s * 0.085
        let bowlH = s * 0.040
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: bowlCenter.x, y: groundY + 1.5), rx: bowlW * 0.52, ry: 3.0, dark: dark)
        let bowlRect = CGRect(x: bowlCenter.x - bowlW * 0.5, y: bowlCenter.y - bowlH * 0.5, width: bowlW, height: bowlH)
        var bowlPath = Path()
        bowlPath.addArc(center: CGPoint(x: bowlRect.midX, y: bowlRect.minY + 4), radius: bowlW * 0.48, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        bowlPath.closeSubpath()
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: bowlPath, bounds: bowlRect, dark: dark, warmth: 0.72, grainLines: 1)

        // Cradle rocker base & low wooden crib grounded on rug
        let crW = s * 0.28
        let crH = s * 0.125
        let crRockDeg: Double = step == 1 ? sin(p.raw * .pi * 2.0) * 3.0 : (step == 0 ? 1.5 * sin(p.action * .pi) : 0)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: cradleCenter.x, y: groundY + 2), rx: crW * 0.52, ry: 4.5, dark: dark)

        var crCtx = ctx
        crCtx.translateBy(x: cradleCenter.x, y: groundY)
        crCtx.rotate(by: .degrees(crRockDeg))
        crCtx.translateBy(x: -cradleCenter.x, y: -groundY)

        // Curved rocker rails seated on groundY
        var rail = Path()
        rail.move(to: CGPoint(x: cradleCenter.x - crW * 0.48, y: groundY - 4))
        rail.addQuadCurve(
            to: CGPoint(x: cradleCenter.x + crW * 0.48, y: groundY - 4),
            control: CGPoint(x: cradleCenter.x, y: groundY + 2)
        )
        crCtx.stroke(rail, with: .color(dark ? Color(hex: 0xCFA066) : Crayon.caramel), style: StrokeStyle(lineWidth: 4.0, lineCap: .round))

        let cribRect = CGRect(x: cradleCenter.x - crW * 0.46, y: groundY - crH - 2, width: crW * 0.92, height: crH)
        let cribPath = Path(roundedRect: cribRect, cornerRadius: 8)
        // Interior warm linen cushion behind plush doll
        crCtx.fill(cribPath, with: .color(dark ? Color(hex: 0x263451) : Color(hex: 0xFBF4E4)))

        // Oat-brown knitted plush bear doll resting snugly at left/head end of cradle (strictly 0 blush/mouth dots)
        let dollHeadCenter = CGPoint(x: cribRect.minX + crW * 0.26, y: cribRect.midY - crH * 0.06)
        let headR = s * 0.044
        let bearCol = dark ? Color(hex: 0xA8825E) : Color(hex: 0xC99F76)
        for ex in [-headR * 0.65, headR * 0.65] {
            crCtx.fill(
                Path(ellipseIn: CGRect(x: dollHeadCenter.x + ex - 4.5, y: dollHeadCenter.y - headR * 0.92 - 3, width: 9, height: 9)),
                with: .color(bearCol)
            )
        }
        // Soft plush torso extending right under blanket zone
        crCtx.fill(
            Path(roundedRect: CGRect(x: dollHeadCenter.x + headR * 0.35, y: dollHeadCenter.y - headR * 0.55, width: crW * 0.38, height: headR * 1.15), cornerRadius: 10),
            with: .color(bearCol.mix(with: .white, by: 0.12))
        )
        crCtx.fill(
            Path(ellipseIn: CGRect(x: dollHeadCenter.x - headR, y: dollHeadCenter.y - headR, width: headR * 2, height: headR * 2)),
            with: .color(bearCol)
        )
        // Calm minimal button eyes + tiny stitched nose bridge
        let eyeCol = dark ? Color(hex: 0x1D2538) : Color(hex: 0x3A2E24)
        for ey in [-3.2, 3.2] {
            crCtx.fill(Path(ellipseIn: CGRect(x: dollHeadCenter.x - 1.5, y: dollHeadCenter.y + ey - 1.5, width: 3.0, height: 3.0)), with: .color(eyeCol))
        }

        // Quilted soft blanket sliding along crib rail over doll torso (Step 0 animates tuck-in, Steps 1–2 tucked)
        let tuckT: CGFloat = step == 0 ? CGFloat(p.action) : 1.0
        let blanketWidth = crW * (0.28 + 0.32 * tuckT)
        let blanketRect = CGRect(
            x: cribRect.maxX - blanketWidth - 4,
            y: cribRect.minY + 4,
            width: blanketWidth,
            height: crH - 8
        )
        let blanketPath = Path(roundedRect: blanketRect, cornerRadius: 6)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &crCtx,
                path: blanketPath,
                bounds: blanketRect,
                light: Palette.mintPale.mix(with: .white, by: 0.18),
                rich: Crayon.teal.opacity(0.85),
                pencilOutline: Color(hex: 0x4E7D70).opacity(0.50),
                lineWidth: 1.0
            )
        } else {
            crCtx.fill(blanketPath, with: .color(Palette.mintPale))
            crCtx.stroke(blanketPath, with: .color(Crayon.teal.opacity(0.42)), lineWidth: 1.0)
        }

        // Foreground beechwood cradle side frame
        crCtx.stroke(
            cribPath,
            with: .color(dark ? Color(hex: 0xDFB174) : Crayon.caramel),
            style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round)
        )

        // Small wooden spoon rests inside bowl normally, arcs smoothly to doll head during Step 1 feeding play
        let spoonPos: CGPoint
        let spoonAngle: Double
        if step == 1 {
            let arc = CGFloat(sin(p.action * .pi))
            let targetFeed = CGPoint(x: dollHeadCenter.x - 4, y: dollHeadCenter.y + 4)
            spoonPos = CGPoint(
                x: bowlCenter.x + (targetFeed.x - bowlCenter.x) * CGFloat(p.action),
                y: bowlCenter.y - 6 + (targetFeed.y - (bowlCenter.y - 6)) * CGFloat(p.action) - arc * s * 0.045
            )
            spoonAngle = -18.0 + 28.0 * p.action
        } else {
            spoonPos = CGPoint(x: bowlCenter.x - 4, y: bowlCenter.y - 6)
            spoonAngle = -24.0
        }
        var spCtx = ctx
        spCtx.translateBy(x: spoonPos.x, y: spoonPos.y)
        spCtx.rotate(by: .degrees(spoonAngle))
        spCtx.fill(Path(roundedRect: CGRect(x: -10, y: -1.8, width: 16, height: 3.6), cornerRadius: 1.8), with: .color(Crayon.caramel))
        spCtx.fill(Path(ellipseIn: CGRect(x: 4, y: -3.4, width: 7, height: 6.8)), with: .color(Crayon.caramel.mix(with: .white, by: 0.16)))

        // Step cues
        switch step {
        case 0:
            BespokeStageHelpers.drawContactSparkles(in: &ctx, center: CGPoint(x: blanketRect.minX + 6, y: cradleCenter.y - 8), pulse: p.contact, radius: s * 0.09, color: Palette.amber)
        case 1:
            BespokeStageHelpers.drawContactSparkles(in: &ctx, center: dollHeadCenter, pulse: p.contact, radius: s * 0.095, color: Palette.amber)
        default:
            BespokeStageHelpers.drawPauseHalo(in: &ctx, center: cradleCenter, baseRadius: s * 0.14, progress: p.action, tint: Palette.amber, dark: dark)
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
        }
    }
}
