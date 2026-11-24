import SwiftUI

/// A26 (Naming Everyday Emotions · 3 Steps):
/// Calm braided sitting sanctuary with a grounded beech stool holding a color-warming glass mood lantern
/// and a grounded terracotta squeeze-cushion beside Moss:
/// Step 0: Moss gazes gently downward as Otto names big feelings in short warm phrases ->
/// Step 1: Wide golden acceptance halo surrounds both as Otto steps closer & lantern softens from mist blue to amber ->
/// Step 2: Moss presses happily onto the safe squeeze-cushion within a soft grounded boundary ring.
struct SceneA26_NamingFeelings: View {
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

            let ottoX = w * (step >= 1 ? 0.31 : 0.25)
            let mossX = w * 0.73
            let lanternCenter = CGPoint(x: w * 0.49, y: groundY - s * 0.16)
            let cushionCenter = CGPoint(x: w * 0.59, y: groundY - s * 0.025)

            let mossHopLift: CGFloat = (step == 2 && p.raw >= 0.44)
                ? CGFloat(max(0.0, sin((p.raw - 0.44) / 0.34 * .pi))) * ms * 0.09
                : 0
            let ottoLean: Double = step == 0 ? 7.5 * p.action : (step == 1 ? 5.5 : 3.5)
            let mossLean: Double = step == 0 ? -3.5 : (step == 2 ? -8.5 * p.contact : -4.0)

            let ottoLook = CGPoint(x: 0.80, y: 0.12)
            let mossLook: CGPoint = {
                switch step {
                case 0: return CGPoint(x: -0.58, y: 0.46)
                case 1: return CGPoint(x: -0.78, y: 0.10)
                default: return CGPoint(x: -0.80, y: 0.22)
                }
            }()
            let mossLid: Double = step == 0 ? 0.42 : (dark ? 0.18 : 0.0)
            let mossMood: Mood = step == 2 ? .happy : (step == 1 ? .wow : .open)
            let ottoMood: Mood = step >= 1 ? .happy : .open

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat, lift: mossHopLift)
            )

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.34 : 0.20, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawEmotionSanctuary(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        lanternCenter: lanternCenter,
                        cushionCenter: cushionCenter,
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
                    targetPoint: step == 2 ? cushionCenter : lanternCenter,
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
                    lid: dark ? 0.34 : 0.20,
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
                    lid: mossLid,
                    lean: mossLean,
                    hopLift: mossHopLift / max(1, ms),
                    hopping: step == 2 && p.isContactWindow,
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
                    targetPoint: step == 2 ? cushionCenter : lanternCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawEmotionSanctuary(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        lanternCenter: CGPoint,
        cushionCenter: CGPoint,
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
        let floorRect = CGRect(x: -6, y: h * 0.745, width: w + 12, height: h * 0.275)
        ctx.fill(
            Path(floorRect),
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x1D2A44) : Color(hex: 0xEFE5D0),
                    dark ? Color(hex: 0x131B2E) : Color(hex: 0xD8CCB4)
                ]),
                startPoint: CGPoint(x: w * 0.5, y: h * 0.745),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Braided circular sitting rug anchoring emotional workspace
        let rugRect = CGRect(x: w * 0.12, y: groundY - s * 0.06, width: w * 0.76, height: s * 0.13)
        ctx.fill(Path(ellipseIn: rugRect), with: .color(dark ? Color(hex: 0x243350) : Color(hex: 0xF5ECDA)))
        ctx.stroke(Path(ellipseIn: rugRect), with: .color((dark ? Palette.amber : Crayon.caramel).opacity(0.32)), lineWidth: 1.4)

        // Low beechwood stool grounded at lanternCenter.x holding the mood glass lantern
        let stoolW = s * 0.14
        let stoolTopY = lanternCenter.y + s * 0.062
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: lanternCenter.x, y: groundY + 2), rx: stoolW * 0.50, ry: 3.5, dark: dark)
        for dx in [-stoolW * 0.30, stoolW * 0.30] {
            let legRect = CGRect(x: lanternCenter.x + dx - 3, y: stoolTopY + 5, width: 6, height: max(4, groundY - stoolTopY - 4))
            PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(roundedRect: legRect, cornerRadius: 2), bounds: legRect, dark: dark, warmth: 0.45, grainLines: 1)
        }
        let stoolTopRect = CGRect(x: lanternCenter.x - stoolW * 0.5, y: stoolTopY, width: stoolW, height: 8)
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(roundedRect: stoolTopRect, cornerRadius: 3), bounds: stoolTopRect, dark: dark, warmth: 0.68, grainLines: 2)

        // Mood glass lantern: cool misty slate -> soft amber warmth across acceptance & comfort
        let warmMix: Double = step == 0 ? p.action * 0.45 : (step == 1 ? 0.55 + p.action * 0.35 : 0.95)
        let globeCol = Color(hex: 0x7A93BC).mix(with: Palette.amber, by: warmMix)
        let globeR = s * 0.056
        let globeRect = CGRect(x: lanternCenter.x - globeR, y: stoolTopY - globeR * 1.95, width: globeR * 2, height: globeR * 2)
        ctx.fill(
            Path(ellipseIn: globeRect),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFF9E8).opacity(0.95), globeCol, globeCol.opacity(0.75)]),
                center: CGPoint(x: lanternCenter.x - globeR * 0.25, y: globeRect.midY - globeR * 0.25),
                startRadius: 1,
                endRadius: globeR * 1.35
            )
        )
        ctx.stroke(Path(ellipseIn: globeRect), with: .color(Color.white.opacity(dark ? 0.35 : 0.65)), lineWidth: 1.0)

        // Grounded terracotta safe squeeze-cushion beside Moss
        let squidge: CGFloat = (step == 2 && p.contact > 0.2) ? CGFloat(p.contact) * 3.5 : 0
        let cushW = s * 0.135 + squidge * 2
        let cushH = s * 0.068 - squidge * 0.6
        let cushRect = CGRect(x: cushionCenter.x - cushW * 0.5, y: groundY - cushH + 2, width: cushW, height: cushH)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: cushionCenter.x, y: groundY + 2), rx: cushW * 0.52, ry: 3.5, dark: dark)
        let cushCol = Crayon.tangerine
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: Path(roundedRect: cushRect, cornerRadius: cushH * 0.45),
                bounds: cushRect,
                light: cushCol.mix(with: .white, by: 0.22),
                rich: cushCol,
                pencilOutline: Color(hex: 0x7D4226).opacity(0.55),
                lineWidth: 1.0
            )
        } else {
            ctx.fill(Path(roundedRect: cushRect, cornerRadius: cushH * 0.45), with: .color(cushCol))
        }

        // Step-specific cues
        switch step {
        case 0:
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoVoice,
                to: mossEar,
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Palette.amber,
                lineWidth: 2.4,
                dark: dark
            )
        case 1:
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: w * 0.52, y: h * 0.64),
                baseRadius: s * 0.21,
                progress: p.action,
                tint: Palette.amber,
                dark: dark
            )
        default:
            // Clear gentle safety boundary arc encircling Moss + squeeze cushion
            let safeRect = CGRect(x: cushionCenter.x - s * 0.16, y: groundY - s * 0.055, width: s * 0.36, height: s * 0.105)
            ctx.stroke(
                Path(ellipseIn: safeRect),
                with: .color(Crayon.teal.opacity(dark ? 0.58 : 0.48)),
                style: StrokeStyle(lineWidth: 2.0, dash: [6, 4])
            )
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: CGPoint(x: cushionCenter.x, y: groundY - s * 0.08),
                pulse: p.contact,
                radius: s * 0.10,
                color: Palette.amber
            )
        }
    }
}
