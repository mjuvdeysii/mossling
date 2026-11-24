import SwiftUI

/// A24 (Free Scribbling with Chunky Crayons · 4 Steps):
/// Sunlit cotton-paper sketchpad desk with cream masking tape corners & ceramic cup holding chunky beeswax crayons:
/// Step 0: Masking tape corners press flat onto the cream cotton sheet ->
/// Step 1: Sunflower chunky crayon draws 1–2 relaxed demonstration arcs ->
/// Step 2: Moss hops joyfully as teal & terracotta crayons sweep lively organic free scribbles ->
/// Step 3: Warm spotlight rings celebrate the lines as Otto weaves a descriptive voice ribbon.
struct SceneA24_FreeScribblingCrayons: View {
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

            let ms = s * 0.34
            let os = ms * Kind.otto.scale
            let groundY = h * 0.87

            let ottoX = w * 0.21
            let mossX = w * 0.78
            let padCenter = CGPoint(x: w * 0.50, y: groundY - s * 0.08)

            let mossHopLift: CGFloat = (step == 2 && p.raw >= 0.44)
                ? CGFloat(max(0.0, sin((p.raw - 0.44) / 0.36 * .pi))) * ms * 0.11
                : 0
            let ottoLean: Double = step == 1 ? 8.0 * p.action : (step == 3 ? 5.0 : 3.0)
            let mossLean: Double = step == 2 ? -9.5 * p.action + sin(p.raw * .pi * 2.0) * 3.0 : -3.5

            let ottoLook = CGPoint(x: 0.78, y: 0.22)
            let mossLook = CGPoint(x: -0.82, y: 0.22)
            let ottoMood: Mood = step >= 2 ? .happy : .open
            let mossMood: Mood = step >= 2 ? .happy : (step == 1 ? .wow : .open)

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
                    drawCrayonSketchpadDesk(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        padCenter: padCenter,
                        ottoVoice: CGPoint(x: ottoCenter.x + os * 0.18, y: ottoCenter.y - os * 0.06),
                        mossEar: CGPoint(x: mossCenter.x - ms * 0.18, y: mossCenter.y - ms * 0.06),
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: padCenter,
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
                    lightDirection: CGPoint(x: 0.76, y: -0.64),
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
                    hopping: step == 2 && mossHopLift > ms * 0.03,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.76, y: -0.64),
                    secondaryLagDegrees: -mossLean * 0.42
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: padCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawCrayonSketchpadDesk(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        padCenter: CGPoint,
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
            dayTop: Color(hex: 0xFAF7EE),
            dayBottom: Color(hex: 0xECE3CF),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        if flat {
            GhibliDrawHelpers.drawKomorebiCanopy(in: &ctx, w: w, h: h, swayOffset: CGFloat(sin(p.raw * .pi * 2.0) * 3.0), dark: dark)
        }

        let s = min(w, h)
        let deskTopY = h * 0.72
        let deskRect = CGRect(x: -6, y: deskTopY, width: w + 12, height: h - deskTopY + 8)
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(deskRect), bounds: deskRect, dark: dark, warmth: 0.65, grainLines: 3)

        // Cream cotton paper pad pinned squarely on tabletop
        let padW = s * 0.34
        let padH = s * 0.22
        let padRect = CGRect(x: padCenter.x - padW * 0.5, y: padCenter.y - padH * 0.5, width: padW, height: padH)
        let padPath = Path(roundedRect: padRect, cornerRadius: 5)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: padPath,
                bounds: padRect,
                light: dark ? Color(hex: 0x28365A) : Color(hex: 0xFFFDF8),
                rich: dark ? Color(hex: 0x1E2945) : Color(hex: 0xF5EEDF),
                pencilOutline: (dark ? Color(hex: 0x4E6494) : Color(hex: 0xCEBF9E)).opacity(0.72),
                lineWidth: 1.15
            )
        } else {
            PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: padRect.midX, y: padRect.maxY + 2), rx: padW * 0.48, ry: 4.5, dark: dark)
            ctx.fill(padPath, with: .color(dark ? Color(hex: 0x263354) : Color(hex: 0xFFFDF8)))
            ctx.stroke(padPath, with: .color((dark ? Color(hex: 0x4E6494) : Color(hex: 0xCEBF9E)).opacity(0.65)), lineWidth: 1.1)
        }

        // Corner masking tapes (Step 0 presses flat)
        let tapeDrop = step == 0 ? CGFloat(1.0 - p.action) * 8 : 0
        for (cx, ang) in [(padRect.minX + 6, -32.0), (padRect.maxX - 6, 32.0)] {
            var tCtx = ctx
            tCtx.translateBy(x: cx, y: padRect.minY + 3 - tapeDrop)
            tCtx.rotate(by: .degrees(ang))
            tCtx.fill(
                Path(roundedRect: CGRect(x: -10, y: -4, width: 20, height: 8), cornerRadius: 1.5),
                with: .color(Color(hex: 0xEFE1B8).opacity(dark ? 0.78 : 0.92))
            )
        }

        // Progressive wax crayon marks drawn on the sheet
        let stroke1Progress: CGFloat = step == 0 ? 0 : (step == 1 ? CGFloat(p.action) : 1.0)
        if stroke1Progress > 0.02 {
            var s1 = Path()
            s1.move(to: CGPoint(x: padRect.minX + padW * 0.16, y: padRect.midY + 6))
            s1.addQuadCurve(
                to: CGPoint(x: padRect.minX + padW * 0.48, y: padRect.minY + padH * 0.34),
                control: CGPoint(x: padRect.minX + padW * 0.28, y: padRect.minY + padH * 0.18)
            )
            ctx.stroke(
                s1.trimmedPath(from: 0, to: min(1, max(0, stroke1Progress))),
                with: .color(Crayon.sunflower),
                style: StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round)
            )
        }

        let scribbleProgress: CGFloat = step < 2 ? 0 : (step == 2 ? CGFloat(p.action) : 1.0)
        if scribbleProgress > 0.02 {
            var tealLoop = Path()
            tealLoop.move(to: CGPoint(x: padRect.minX + padW * 0.42, y: padRect.maxY - padH * 0.24))
            tealLoop.addCurve(
                to: CGPoint(x: padRect.minX + padW * 0.78, y: padRect.minY + padH * 0.36),
                control1: CGPoint(x: padRect.minX + padW * 0.46, y: padRect.minY + padH * 0.18),
                control2: CGPoint(x: padRect.minX + padW * 0.76, y: padRect.maxY - padH * 0.18)
            )
            ctx.stroke(
                tealLoop.trimmedPath(from: 0, to: min(1, max(0, scribbleProgress))),
                with: .color(Crayon.teal),
                style: StrokeStyle(lineWidth: 3.8, lineCap: .round, lineJoin: .round)
            )

            var coralWave = Path()
            coralWave.move(to: CGPoint(x: padRect.minX + padW * 0.22, y: padRect.maxY - padH * 0.20))
            coralWave.addQuadCurve(
                to: CGPoint(x: padRect.minX + padW * 0.66, y: padRect.maxY - padH * 0.28),
                control: CGPoint(x: padRect.midX, y: padRect.midY + 10)
            )
            ctx.stroke(
                coralWave.trimmedPath(from: 0, to: min(1, max(0, (scribbleProgress - 0.15) / 0.85))),
                with: .color(Crayon.tangerine),
                style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
            )
        }

        // Chunky toddler beeswax crayon resting/gliding beside the paper
        let crayonColor: Color = step == 1 ? Crayon.sunflower : (step >= 2 ? Crayon.teal : Crayon.tangerine)
        let crayonPos: CGPoint = {
            switch step {
            case 0: return CGPoint(x: padRect.maxX + 16, y: padRect.maxY - 10)
            case 1: return CGPoint(x: padRect.minX + padW * (0.18 + 0.28 * CGFloat(p.action)), y: padRect.midY - 8)
            case 2: return CGPoint(x: padRect.minX + padW * (0.44 + 0.32 * CGFloat(sin(p.action * .pi))), y: padRect.midY - 10)
            default: return CGPoint(x: padRect.maxX + 16, y: padRect.maxY - 10)
            }
        }()
        var crCtx = ctx
        crCtx.translateBy(x: crayonPos.x, y: crayonPos.y)
        crCtx.rotate(by: .degrees(step == 1 || step == 2 ? -28.0 : -10.0))
        let crRect = CGRect(x: -5, y: -14, width: 10, height: 24)
        crCtx.fill(Path(roundedRect: crRect, cornerRadius: 3), with: .color(crayonColor))
        var tip = Path()
        tip.move(to: CGPoint(x: -4, y: -14))
        tip.addLine(to: CGPoint(x: 0, y: -21))
        tip.addLine(to: CGPoint(x: 4, y: -14))
        tip.closeSubpath()
        crCtx.fill(tip, with: .color(crayonColor))
        crCtx.fill(Path(CGRect(x: -5, y: -4, width: 10, height: 6)), with: .color(Color(hex: 0xFFFDF8).opacity(0.65)))

        if step == 3 {
            let spotPt = CGPoint(x: padRect.minX + padW * 0.62, y: padRect.midY)
            BespokeStageHelpers.drawPauseHalo(in: &ctx, center: spotPt, baseRadius: s * 0.085, progress: p.action, tint: Crayon.teal, dark: dark)
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
        BespokeStageHelpers.drawContactSparkles(
            in: &ctx,
            center: padCenter,
            pulse: p.contact,
            radius: s * 0.11,
            color: Palette.amber
        )
    }
}
