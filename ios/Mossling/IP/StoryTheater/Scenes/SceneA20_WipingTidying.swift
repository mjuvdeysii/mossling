import SwiftUI

/// A20 (Wiping & Tidying Together · 3 Steps):
/// Wide low birch practical-life table cleanly bridged between Otto (left) and Moss (right):
/// Step 0: Grounded cream cotton cloth sweeps calmly across left tabletop clearing water droplets into sheen sparkles ->
/// Step 1: Child-sized mint washcloth glides smoothly ALONG the tabletop surface toward Moss (zero levitation) ->
/// Step 2: Moss wipes playful S-curves across right tabletop while the wooden cup slides neatly along tabletop into the side tidy basket.
struct SceneA20_WipingTidying: View {
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

            let ms = s * 0.34
            let os = ms * Kind.otto.scale
            let groundY = h * 0.875
            let tableTopY = h * 0.69

            let ottoX = w * 0.21
            let mossX = w * (step == 2 ? 0.75 : 0.79)

            let mossHopLift: CGFloat = (step == 2 && p.raw >= 0.46)
                ? CGFloat(max(0.0, sin((p.raw - 0.46) / 0.34 * .pi))) * ms * 0.08
                : 0
            let ottoLean: Double = step == 0 ? 11.0 * p.action : (step == 1 ? 7.5 * p.action : 3.0)
            let mossLean: Double = step == 2 ? -10.5 * p.action + sin(p.raw * .pi * 2.0) * 3.0 : (step == 1 ? -6.0 * p.contactEnvelope : -3.0)

            let ottoLook = CGPoint(x: 0.78, y: 0.28)
            let mossLook = CGPoint(x: -0.82, y: 0.26)

            let ottoMood: Mood = step == 2 ? .happy : .open
            let mossMood: Mood = step == 2 ? .happy : (step == 1 && p.raw >= 0.44 ? .wow : .open)

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
            let tableTarget = CGPoint(x: w * 0.50, y: tableTopY)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawPracticalLifeTable(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        tableTopY: tableTopY,
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: tableTarget,
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
                    lightDirection: CGPoint(x: 0.26, y: -0.68),
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
                    lightDirection: CGPoint(x: 0.26, y: -0.68),
                    secondaryLagDegrees: -mossLean * 0.42
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: tableTarget,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawPracticalLifeTable(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        tableTopY: CGFloat,
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
            dayBottom: Color(hex: 0xECE4D0),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        let floorRect = CGRect(x: -6, y: h * 0.76, width: w + 12, height: h * 0.26)
        ctx.fill(
            Path(floorRect),
            with: .linearGradient(
                Gradient(colors: [dark ? Color(hex: 0x1E2A44) : Color(hex: 0xEFE5D0), dark ? Color(hex: 0x131B2E) : Color(hex: 0xD8CCB4)]),
                startPoint: CGPoint(x: w * 0.5, y: h * 0.76),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Wide low birch Montessori practical-life table reaching close to both companions
        let tLeft = w * 0.27
        let tWidth = w * 0.46
        let legW: CGFloat = 8
        let legH = groundY - tableTopY
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: w * 0.50, y: groundY + 2), rx: tWidth * 0.52, ry: 5, dark: dark)

        for lx in [tLeft + 10, tLeft + tWidth - 18] {
            let legRect = CGRect(x: lx, y: tableTopY + 8, width: legW, height: max(4, legH - 6))
            PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(roundedRect: legRect, cornerRadius: 3), bounds: legRect, dark: dark, warmth: 0.45, grainLines: 1)
        }
        let topRect = CGRect(x: tLeft, y: tableTopY, width: tWidth, height: 12)
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(roundedRect: topRect, cornerRadius: 5), bounds: topRect, dark: dark, warmth: 0.7, grainLines: 3)

        // Low tidy basket resting cleanly on right edge of tabletop
        let basketRect = CGRect(x: tLeft + tWidth - 38, y: tableTopY - 14, width: 32, height: 14)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: basketRect.midX, y: tableTopY + 0.5), rx: 16, ry: 2.5, dark: dark)

        let cupStartX = tLeft + tWidth * 0.48
        let cupEndX = basketRect.midX - 7
        let cupX = step == 2 ? cupStartX + (cupEndX - cupStartX) * CGFloat(p.action) : cupStartX
        let cupRect = CGRect(x: cupX, y: tableTopY - 14, width: 14, height: 14)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: cupRect.midX, y: tableTopY + 0.5), rx: 8, ry: 2.2, dark: dark)
        ctx.fill(Path(roundedRect: cupRect, cornerRadius: 3), with: .color(Crayon.teal))
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(roundedRect: basketRect, cornerRadius: 4), bounds: basketRect, dark: dark, warmth: 0.5, grainLines: 2)

        let clothW = min(w, h) * 0.105
        let clothH = clothW * 0.54
        let sweepT = p.action
        let clothCenter: CGPoint
        let clothTint: Color
        let clothAngle: Double

        switch step {
        case 0:
            let sweepX = tLeft + tWidth * (0.14 + 0.34 * CGFloat(sin(sweepT * .pi)))
            clothCenter = CGPoint(x: sweepX, y: tableTopY - clothH * 0.42)
            clothTint = Color(hex: 0xF7EFE0)
            clothAngle = sin(sweepT * .pi * 2.0) * 5.0
        case 1:
            let slideT = CGFloat(p.action)
            let startX = tLeft + tWidth * 0.34
            let endX = tLeft + tWidth * 0.70
            clothCenter = CGPoint(x: startX + (endX - startX) * slideT, y: tableTopY - clothH * 0.42)
            clothTint = Palette.mintPale
            clothAngle = (1.0 - Double(slideT)) * -6.0
        default:
            let wiggle = CGFloat(sin(p.raw * .pi * 3.0))
            clothCenter = CGPoint(x: tLeft + tWidth * 0.56 + wiggle * tWidth * 0.14, y: tableTopY - clothH * 0.42)
            clothTint = Palette.mintPale
            clothAngle = Double(wiggle) * 6.0
        }

        // Water droplets on tabletop in Step 0 cleared synchronously when cloth leading edge passes
        if step == 0 {
            let leadingEdge = clothCenter.x + clothW * 0.42
            for idx in 0..<3 {
                let dx = tLeft + tWidth * (0.18 + CGFloat(idx) * 0.11)
                if leadingEdge < dx {
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: dx - 3, y: tableTopY - 3, width: 6, height: 4)),
                        with: .color(Crayon.sky.opacity(0.82))
                    )
                }
            }
        }

        // Crisp tabletop contact AO beneath folded cloth
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: clothCenter.x, y: tableTopY + 0.5), rx: clothW * 0.48, ry: 2.5, dark: dark)

        var cCtx = ctx
        cCtx.translateBy(x: clothCenter.x, y: clothCenter.y)
        cCtx.rotate(by: .degrees(clothAngle))
        let clothRect = CGRect(x: -clothW * 0.5, y: -clothH * 0.5, width: clothW, height: clothH)
        let clothPath = Path(roundedRect: clothRect, cornerRadius: 5)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &cCtx,
                path: clothPath,
                bounds: clothRect,
                light: clothTint.mix(with: .white, by: 0.25),
                rich: clothTint.mix(with: Crayon.caramel, by: 0.18),
                pencilOutline: (dark ? Color.white : Color(hex: 0x7A6548)).opacity(0.55),
                lineWidth: 1.0
            )
        } else {
            cCtx.fill(clothPath, with: .color(clothTint))
            cCtx.stroke(clothPath, with: .color(Color.white.opacity(0.45)), lineWidth: 1.0)
        }

        // Clean sheen sparkles along wiped surface
        BespokeStageHelpers.drawContactSparkles(
            in: &ctx,
            center: CGPoint(x: tLeft + tWidth * (step == 0 ? 0.34 : 0.62), y: tableTopY - 10),
            pulse: p.contact,
            radius: min(w, h) * 0.10,
            color: Palette.amber
        )
    }
}
