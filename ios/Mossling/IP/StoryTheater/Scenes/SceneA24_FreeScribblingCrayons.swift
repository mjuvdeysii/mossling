import SwiftUI

/// A24 (Free Scribbling with Chunky Crayons · 4 Steps):
/// Three-plane sunlit Montessori studio: Moss on left, Otto illuminating from right,
/// grounded low clipped beechwood drawing board resting squarely on woven rug + ceramic crayon cup:
/// Step 0: Masking tape corners press flat onto the cream cotton sheet ->
/// Step 1: Sunflower chunky crayon nib tracks 1:1 with gentle demonstration arc ->
/// Step 2: Moss leans warmly in from the left as teal & coral beeswax crayons trace organic loops ->
/// Step 3: Crayons rest grounded beside the paper as warm spotlight rings & Otto voice ribbon celebrate.
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

            let mossX = w * (step == 2 ? 0.27 : 0.23)
            let ottoX = w * 0.78
            let padCenter = CGPoint(x: w * 0.50, y: groundY - s * 0.105)

            let mossHopLift: CGFloat = (step == 2 && p.raw >= 0.44)
                ? CGFloat(max(0.0, sin((p.raw - 0.44) / 0.36 * .pi))) * ms * 0.10
                : 0
            let mossLean: Double = step == 2 ? 9.5 * p.action + sin(p.raw * .pi * 2.0) * 2.5 : 3.5
            let ottoLean: Double = step == 1 ? -8.5 * p.action : (step == 3 ? -5.0 : -3.0)

            let mossLook = CGPoint(x: 0.82, y: 0.24)
            let ottoLook = CGPoint(x: -0.78, y: 0.24)
            let mossMood: Mood = step >= 2 ? .happy : (step == 1 ? .wow : .open)
            let ottoMood: Mood = step >= 2 ? .happy : .open

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
                    drawCrayonSketchpadDesk(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        padCenter: padCenter,
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
                    targetPoint: padCenter,
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
                    hopping: step == 2 && mossHopLift > ms * 0.03,
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

    private func quadPoint(_ t: CGFloat, _ p0: CGPoint, _ c: CGPoint, _ p1: CGPoint) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * p0.x + 2 * u * t * c.x + t * t * p1.x,
            y: u * u * p0.y + 2 * u * t * c.y + t * t * p1.y
        )
    }

    private func cubicPoint(_ t: CGFloat, _ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p1: CGPoint) -> CGPoint {
        let u = 1 - t
        let uu = u * u
        let tt = t * t
        return CGPoint(
            x: uu * u * p0.x + 3 * uu * t * c1.x + 3 * u * tt * c2.x + tt * t * p1.x,
            y: uu * u * p0.y + 3 * uu * t * c1.y + 3 * u * tt * c2.y + tt * t * p1.y
        )
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
        // Warm woven play rug horizon below wall
        let rugY = h * 0.745
        let rugRect = CGRect(x: -6, y: rugY, width: w + 12, height: h - rugY + 8)
        ctx.fill(
            Path(rugRect),
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x1E2A44) : Color(hex: 0xEFE5D0),
                    dark ? Color(hex: 0x131B2E) : Color(hex: 0xD8CCB4)
                ]),
                startPoint: CGPoint(x: w * 0.5, y: rugY),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Low beechwood Montessori floor drawing board seated squarely on rug at groundY
        let boardW = s * 0.44
        let boardH = s * 0.25
        let boardRect = CGRect(x: padCenter.x - boardW * 0.5, y: groundY - boardH + 4, width: boardW, height: boardH)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: boardRect.midX, y: groundY + 3), rx: boardW * 0.52, ry: 5.5, dark: dark)
        PixarDrawHelpers.drawBeechwood(
            in: &ctx,
            path: Path(roundedRect: boardRect, cornerRadius: 8),
            bounds: boardRect,
            dark: dark,
            warmth: 0.68,
            grainLines: 3
        )

        // Grounded terracotta crayon cup tucked behind-right edge of board on the rug
        let cupW: CGFloat = 18
        let cupH: CGFloat = 20
        let cupRect = CGRect(x: boardRect.maxX + 6, y: groundY - cupH + 2, width: cupW, height: cupH)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: cupRect.midX, y: groundY + 2), rx: 11, ry: 3.5, dark: dark)
        ctx.fill(
            Path(roundedRect: cupRect, cornerRadius: 4),
            with: .color(dark ? Color(hex: 0x8F4D37) : Color(hex: 0xD6825F))
        )

        // Cream cotton paper sheet centered inside wooden board
        let padW = boardW * 0.80
        let padH = boardH * 0.78
        let padRect = CGRect(x: boardRect.midX - padW * 0.5, y: boardRect.midY - padH * 0.5, width: padW, height: padH)
        let padPath = Path(roundedRect: padRect, cornerRadius: 4)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: padPath,
                bounds: padRect,
                light: dark ? Color(hex: 0x28365A) : Color(hex: 0xFFFDF8),
                rich: dark ? Color(hex: 0x1E2945) : Color(hex: 0xF5EEDF),
                pencilOutline: (dark ? Color(hex: 0x4E6494) : Color(hex: 0xCEBF9E)).opacity(0.72),
                lineWidth: 1.1
            )
        } else {
            PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: padRect.midX, y: padRect.maxY + 1.5), rx: padW * 0.46, ry: 3.0, dark: dark)
            ctx.fill(padPath, with: .color(dark ? Color(hex: 0x263354) : Color(hex: 0xFFFDF8)))
            ctx.stroke(padPath, with: .color((dark ? Color(hex: 0x4E6494) : Color(hex: 0xCEBF9E)).opacity(0.65)), lineWidth: 1.0)
        }

        // Four corner masking tapes securing paper onto board (Step 0 presses flat)
        let tapeDrop = step == 0 ? CGFloat(1.0 - p.action) * 5.0 : 0
        for (cx, cy, ang) in [
            (padRect.minX + 5, padRect.minY + 3, -34.0),
            (padRect.maxX - 5, padRect.minY + 3, 34.0),
            (padRect.minX + 5, padRect.maxY - 3, 34.0),
            (padRect.maxX - 5, padRect.maxY - 3, -34.0)
        ] {
            var tCtx = ctx
            tCtx.translateBy(x: cx, y: cy - tapeDrop)
            tCtx.rotate(by: .degrees(ang))
            tCtx.fill(
                Path(roundedRect: CGRect(x: -9, y: -3.2, width: 18, height: 6.4), cornerRadius: 1.5),
                with: .color(Color(hex: 0xEFE1B8).opacity(dark ? 0.78 : 0.92))
            )
        }

        // Parametric stroke 1 (Sunflower arc right-to-left demo)
        let s1Start = CGPoint(x: padRect.maxX - padW * 0.16, y: padRect.midY + 6)
        let s1Ctrl = CGPoint(x: padRect.midX + padW * 0.08, y: padRect.minY + padH * 0.18)
        let s1End = CGPoint(x: padRect.minX + padW * 0.48, y: padRect.minY + padH * 0.36)
        let s1Progress = min(1.0, max(0.0, step == 0 ? 0.0 : (step == 1 ? CGFloat(p.action) : 1.0)))
        if s1Progress > 0.02 {
            var s1 = Path()
            s1.move(to: s1Start)
            s1.addQuadCurve(to: s1End, control: s1Ctrl)
            ctx.stroke(
                s1.trimmedPath(from: 0, to: s1Progress),
                with: .color(Crayon.sunflower),
                style: StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round)
            )
        }

        // Parametric stroke 2 (Moss's organic teal & coral scribble)
        let tStart = CGPoint(x: padRect.minX + padW * 0.22, y: padRect.maxY - padH * 0.24)
        let tC1 = CGPoint(x: padRect.minX + padW * 0.34, y: padRect.minY + padH * 0.16)
        let tC2 = CGPoint(x: padRect.minX + padW * 0.72, y: padRect.maxY - padH * 0.16)
        let tEnd = CGPoint(x: padRect.minX + padW * 0.76, y: padRect.minY + padH * 0.34)
        let scribbleProgress = min(1.0, max(0.0, step < 2 ? 0.0 : (step == 2 ? CGFloat(p.action) : 1.0)))
        if scribbleProgress > 0.02 {
            var tealLoop = Path()
            tealLoop.move(to: tStart)
            tealLoop.addCurve(to: tEnd, control1: tC1, control2: tC2)
            ctx.stroke(
                tealLoop.trimmedPath(from: 0, to: scribbleProgress),
                with: .color(Crayon.teal),
                style: StrokeStyle(lineWidth: 3.8, lineCap: .round, lineJoin: .round)
            )

            let coralTrim = min(1.0, max(0.0, (scribbleProgress - 0.18) / 0.82))
            if coralTrim > 0.02 {
                var coralWave = Path()
                coralWave.move(to: CGPoint(x: padRect.minX + padW * 0.20, y: padRect.maxY - padH * 0.18))
                coralWave.addQuadCurve(
                    to: CGPoint(x: padRect.minX + padW * 0.64, y: padRect.maxY - padH * 0.28),
                    control: CGPoint(x: padRect.midX, y: padRect.midY + 9)
                )
                ctx.stroke(
                    coralWave.trimmedPath(from: 0, to: coralTrim),
                    with: .color(Crayon.tangerine),
                    style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round)
                )
            }
        }

        // Chunky beeswax crayon: nib touches exact stroke tip while drawing, or rests flat on wood ledge when idle
        let crayonColor: Color = step == 1 ? Crayon.sunflower : (step >= 2 ? Crayon.teal : Crayon.tangerine)
        let nibPos: CGPoint
        let crayonAngle: Double
        switch step {
        case 0:
            nibPos = CGPoint(x: padRect.minX - 4, y: boardRect.maxY - 6)
            crayonAngle = 84.0
        case 1:
            nibPos = quadPoint(s1Progress, s1Start, s1Ctrl, s1End)
            crayonAngle = -26.0
        case 2:
            nibPos = cubicPoint(scribbleProgress, tStart, tC1, tC2, tEnd)
            crayonAngle = 24.0
        default:
            nibPos = CGPoint(x: padRect.maxX + 6, y: boardRect.maxY - 6)
            crayonAngle = 86.0
        }

        if step == 0 || step == 3 {
            PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: nibPos.x, y: boardRect.maxY - 3), rx: 12, ry: 2.5, dark: dark)
        }
        var crCtx = ctx
        crCtx.translateBy(x: nibPos.x, y: nibPos.y)
        crCtx.rotate(by: .degrees(crayonAngle))
        // Draw crayon extending UP from local nib origin (0, 0) so nib meets exact stroke endpoint
        let crRect = CGRect(x: -4.5, y: -28, width: 9, height: 22)
        crCtx.fill(Path(roundedRect: crRect, cornerRadius: 2.5), with: .color(crayonColor))
        var tip = Path()
        tip.move(to: CGPoint(x: -4, y: -6))
        tip.addLine(to: CGPoint(x: 0, y: 0))
        tip.addLine(to: CGPoint(x: 4, y: -6))
        tip.closeSubpath()
        crCtx.fill(tip, with: .color(crayonColor))
        crCtx.fill(Path(CGRect(x: -4.5, y: -21, width: 9, height: 5)), with: .color(Color(hex: 0xFFFDF8).opacity(0.68)))

        if step == 3 {
            let spotPt = CGPoint(x: padRect.minX + padW * 0.56, y: padRect.midY)
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
            center: CGPoint(x: padRect.midX, y: padRect.midY),
            pulse: p.contact,
            radius: s * 0.10,
            color: Palette.amber
        )
    }
}
