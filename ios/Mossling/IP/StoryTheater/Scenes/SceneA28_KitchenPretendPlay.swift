import SwiftUI

/// A28 (Kitchen Pretend Play · 4 Steps):
/// Grounded low wooden play-kitchen counter (`w * 0.31...0.69`, sides flush on `groundY = h * 0.875`),
/// Moss on left (`0.24..0.28`), Otto customer on right (`0.78`):
/// Step 0: Picture menu tokens illuminate on stand-up wooden card ->
/// Step 1: Otto leans politely as customer placing a golden spoken order ->
/// Step 2: Moss stirs chunky wooden saucepan as gentle steam curls rise + joyful hop ->
/// Step 3: Warm soup bowl slides smoothly ALONG `counterTopY` to Otto with alternating polite turn-taking dialogue ribbons.
struct SceneA28_KitchenPretendPlay: View {
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
            let groundY = h * 0.875
            let counterTopY = h * 0.665

            let mossX = w * (step == 2 ? 0.28 : 0.24)
            let ottoX = w * 0.78
            let counterTarget = CGPoint(x: w * 0.50, y: counterTopY)

            let mossHopLift: CGFloat = (step == 2 && p.raw >= 0.46)
                ? CGFloat(max(0.0, sin((p.raw - 0.46) / 0.34 * .pi))) * ms * 0.09
                : 0
            let mossLean: Double = step == 2 ? 9.5 * p.action : (step == 3 ? 6.0 : 3.0)
            let ottoLean: Double = step == 1 ? -8.5 * p.action : (step == 3 ? -6.5 * p.contact : -3.0)

            let mossLook = CGPoint(x: 0.80, y: 0.22)
            let ottoLook = CGPoint(x: -0.80, y: 0.20)
            let mossMood: Mood = step >= 2 ? .happy : (step == 1 ? .wow : .open)
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
                    drawPlayKitchenCounter(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        counterTopY: counterTopY,
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
                    targetPoint: counterTarget,
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
                    hopping: step == 2 && p.isContactWindow,
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
                    targetPoint: counterTarget,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawPlayKitchenCounter(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        counterTopY: CGFloat,
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
            dayTop: Color(hex: 0xFAF7ED),
            dayBottom: Color(hex: 0xECE3CF),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        if flat {
            GhibliDrawHelpers.drawKomorebiCanopy(in: &ctx, w: w, h: h, swayOffset: 0, dark: dark)
        }

        let s = min(w, h)
        let floorRect = CGRect(x: -6, y: h * 0.755, width: w + 12, height: h * 0.265)
        ctx.fill(
            Path(floorRect),
            with: .linearGradient(
                Gradient(colors: [dark ? Color(hex: 0x1E2A44) : Color(hex: 0xEFE5D0), dark ? Color(hex: 0x131B2E) : Color(hex: 0xD8CCB4)]),
                startPoint: CGPoint(x: w * 0.5, y: h * 0.755),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Low beech play-kitchen counter grounded cleanly on floor
        let cLeft = w * 0.31
        let cWidth = w * 0.38
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: w * 0.50, y: groundY + 2), rx: cWidth * 0.52, ry: 5, dark: dark)

        let bodyRect = CGRect(x: cLeft + 8, y: counterTopY + 8, width: cWidth - 16, height: max(18, groundY - counterTopY - 6))
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(roundedRect: bodyRect, cornerRadius: 5), bounds: bodyRect, dark: dark, warmth: 0.48, grainLines: 2)
        // Two playful wooden stove knobs on counter apron
        for kx in [bodyRect.minX + bodyRect.width * 0.28, bodyRect.minX + bodyRect.width * 0.52] {
            ctx.fill(
                Path(ellipseIn: CGRect(x: kx - 4.5, y: bodyRect.minY + 10, width: 9, height: 9)),
                with: .color(Crayon.caramel)
            )
        }
        let topRect = CGRect(x: cLeft, y: counterTopY, width: cWidth, height: 10)
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(roundedRect: topRect, cornerRadius: 4), bounds: topRect, dark: dark, warmth: 0.70, grainLines: 2)

        // Propped visual menu board on right side of counter (3 simple color food circles, zero tiny text)
        let menuRect = CGRect(x: cLeft + cWidth - 36, y: counterTopY - 30, width: 28, height: 30)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: menuRect.midX, y: counterTopY + 0.5), rx: 14, ry: 2.2, dark: dark)
        ctx.fill(Path(roundedRect: menuRect, cornerRadius: 4), with: .color(dark ? Color(hex: 0x243452) : Color(hex: 0xFFFDF8)))
        ctx.stroke(Path(roundedRect: menuRect, cornerRadius: 4), with: .color(Crayon.caramel.opacity(0.65)), lineWidth: 1.0)
        for (idx, col) in [Crayon.tangerine, Crayon.sunflower, Crayon.teal].enumerated() {
            let cy = menuRect.minY + 7 + CGFloat(idx) * 8
            let lit = step == 0 && abs(p.action * 2.4 - Double(idx)) < 0.7
            let rDot: CGFloat = lit ? 3.6 : 2.6
            ctx.fill(Path(ellipseIn: CGRect(x: menuRect.midX - rDot, y: cy - rDot, width: rDot * 2, height: rDot * 2)), with: .color(col))
        }

        // Chunky wooden saucepan seated flush on left burner of counterTopY
        let potX = cLeft + cWidth * 0.28
        let potW = s * 0.105
        let potH = s * 0.056
        let potRect = CGRect(x: potX - potW * 0.5, y: counterTopY - potH + 1, width: potW, height: potH)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: potX, y: counterTopY + 0.5), rx: potW * 0.52, ry: 2.5, dark: dark)
        // Saucepan wooden handle extending left toward Moss
        ctx.fill(Path(roundedRect: CGRect(x: potRect.minX - 12, y: potRect.minY + 3, width: 14, height: 4), cornerRadius: 2), with: .color(Crayon.caramel))
        ctx.fill(Path(roundedRect: potRect, cornerRadius: 5), with: .color(dark ? Color(hex: 0x3D6270) : Crayon.teal))

        // Beechwood stirring spoon inside saucepan rim (pivots smoothly in Step 2)
        let stirDx: CGFloat = step == 2 ? CGFloat(sin(p.raw * .pi * 4.0) * Double(potW * 0.20)) : 0
        let spoonAngle = step == 2 ? sin(p.raw * .pi * 4.0) * 14.0 : -14.0
        var spCtx = ctx
        spCtx.translateBy(x: potX + stirDx, y: potRect.minY + 2)
        spCtx.rotate(by: .degrees(spoonAngle))
        spCtx.fill(Path(roundedRect: CGRect(x: -2.2, y: -18, width: 4.4, height: 22), cornerRadius: 2), with: .color(Crayon.caramel))

        // Delicate rising steam curls in Step 2
        if step == 2 {
            for idx in 0..<2 {
                let offset = CGFloat(idx) * 10 - 5
                var steam = Path()
                let sy = potRect.minY - 6
                steam.move(to: CGPoint(x: potX + offset, y: sy))
                steam.addCurve(
                    to: CGPoint(x: potX + offset + 3, y: sy - 18),
                    control1: CGPoint(x: potX + offset - 5, y: sy - 7),
                    control2: CGPoint(x: potX + offset + 7, y: sy - 12)
                )
                ctx.stroke(
                    steam.trimmedPath(from: 0, to: min(1, max(0, CGFloat(p.action)))),
                    with: .color((dark ? Palette.amber : Color.white).opacity(0.65)),
                    style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
                )
            }
        }

        // Serving wooden bowl slides cleanly ALONG counterTopY in Step 3 toward Otto's side (zero midair jump)
        let bowlStartX = cLeft + cWidth * 0.56
        let bowlEndX = cLeft + cWidth * 0.76
        let bowlX = step == 3 ? bowlStartX + (bowlEndX - bowlStartX) * CGFloat(p.action) : bowlStartX
        let bowlW = s * 0.072
        let bowlRect = CGRect(x: bowlX - bowlW * 0.5, y: counterTopY - 12, width: bowlW, height: 12)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: bowlX, y: counterTopY + 0.5), rx: bowlW * 0.45, ry: 2.2, dark: dark)
        var bPath = Path()
        bPath.addArc(center: CGPoint(x: bowlRect.midX, y: bowlRect.minY + 1), radius: bowlW * 0.48, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        bPath.closeSubpath()
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: bPath, bounds: bowlRect, dark: dark, warmth: 0.78, grainLines: 1)

        // Step-specific cues
        switch step {
        case 0:
            BespokeStageHelpers.drawContactSparkles(in: &ctx, center: CGPoint(x: menuRect.midX, y: menuRect.midY), pulse: p.contact, radius: s * 0.08, color: Palette.amber)
        case 1:
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoVoice,
                to: CGPoint(x: menuRect.midX, y: menuRect.minY - 6),
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Palette.amber,
                lineWidth: 2.2,
                dark: dark
            )
        case 2:
            BespokeStageHelpers.drawContactSparkles(in: &ctx, center: CGPoint(x: potX, y: potRect.minY - 8), pulse: p.contact, radius: s * 0.09, color: Palette.amber)
        default:
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: mossEar,
                to: ottoVoice,
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Crayon.teal,
                lineWidth: 2.1,
                dark: dark
            )
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoVoice,
                to: mossEar,
                progress: p.followThrough,
                waveOffset: p.raw * .pi * 2.0 + 1.1,
                color: Palette.amber,
                lineWidth: 2.1,
                dark: dark
            )
        }
    }
}
