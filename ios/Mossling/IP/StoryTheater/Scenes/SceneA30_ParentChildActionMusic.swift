import SwiftUI

/// A30 (Parent-Child Action & Music · 3 Steps):
/// Sunlit circular music rug with grounded birch music-box plinth (`w * 0.49`) & rhythmic step mats:
/// Step 0: Adult sings/sways a familiar rhythm (`drawSilkVoiceRibbon` + hand-drawn eighth-note motif) ->
/// Step 1: Alternating clap/step pads pulse in 4/4 beat as both sway cleanly together ->
/// Step 2: Child joins joyfully in motion (`p.raw < 0.60`), then freezes neatly in golden stillness pause (`p.raw >= 0.60`).
struct SceneA30_ParentChildActionMusic: View {
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
            let groundY = h * 0.86

            let isFrozenPause = (step == 2 && p.raw >= 0.60)
            let ottoX = w * 0.26
            let mossX = w * 0.72 + (step == 2 && !isFrozenPause ? CGFloat(sin(p.raw * .pi * 4.0) * 6.0) : 0)

            let beatWave = sin(p.raw * .pi * 4.0)
            let ottoHopLift: CGFloat = step == 1 ? CGFloat(max(0.0, sin(p.raw * .pi * 4.0))) * os * 0.08 : 0
            let mossHopLift: CGFloat = {
                if step == 2 && !isFrozenPause {
                    return CGFloat(abs(sin(p.raw * .pi * 4.0))) * ms * 0.12
                }
                if step == 1 {
                    return CGFloat(max(0.0, -beatWave)) * ms * 0.06
                }
                return 0
            }()

            let ottoLean: Double = step == 0 ? sin(p.raw * .pi * 2.0) * 5.0 + 3.0 : (step == 1 ? beatWave * 6.5 : 3.5)
            let mossLean: Double = isFrozenPause ? 0.0 : (step == 2 ? beatWave * 10.0 : (step == 1 ? -beatWave * 6.0 : -3.0))

            let ottoLook = CGPoint(x: 0.76, y: 0.12)
            let mossLook = CGPoint(x: -0.78, y: isFrozenPause ? 0.0 : 0.14)
            let ottoMood: Mood = step >= 1 ? .happy : .open
            let mossMood: Mood = isFrozenPause ? .wow : (step >= 1 ? .happy : .open)

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY, flat: flat, lift: ottoHopLift)
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
            let musicTarget = CGPoint(x: w * 0.50, y: groundY - s * 0.08)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawMusicRhythmStage(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        ottoVoice: CGPoint(x: ottoCenter.x + os * 0.18, y: ottoCenter.y - os * 0.06),
                        mossEar: CGPoint(x: mossCenter.x - ms * 0.18, y: mossCenter.y - ms * 0.06),
                        mossCenter: mossCenter,
                        isFrozenPause: isFrozenPause,
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: musicTarget,
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
                    hopLift: ottoHopLift / max(1, os),
                    hopping: step == 1 && ottoHopLift > os * 0.03,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.74, y: -0.64),
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
                    hopping: step == 2 && !isFrozenPause && mossHopLift > ms * 0.03,
                    breathTime: isFrozenPause ? 0 : ctx.breathTime,
                    isStatic: ctx.isStatic || isFrozenPause,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.74, y: -0.64),
                    secondaryLagDegrees: isFrozenPause ? 0 : -mossLean * 0.42
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: musicTarget,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawMusicRhythmStage(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        ottoVoice: CGPoint,
        mossEar: CGPoint,
        mossCenter: CGPoint,
        isFrozenPause: Bool,
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
            dayBottom: Color(hex: 0xECE4CF),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        if flat {
            GhibliDrawHelpers.drawKomorebiCanopy(in: &ctx, w: w, h: h, swayOffset: 0, dark: dark)
        }

        let s = min(w, h)
        let floorRect = CGRect(x: -6, y: h * 0.74, width: w + 12, height: h * 0.28)
        ctx.fill(
            Path(floorRect),
            with: .linearGradient(
                Gradient(colors: [dark ? Color(hex: 0x1E2A44) : Color(hex: 0xEFE5D0), dark ? Color(hex: 0x131B2E) : Color(hex: 0xD8CCB4)]),
                startPoint: CGPoint(x: w * 0.5, y: h * 0.74),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Warm circular rhythm rug
        let rugRect = CGRect(x: w * 0.14, y: groundY - s * 0.055, width: w * 0.72, height: s * 0.12)
        ctx.fill(Path(ellipseIn: rugRect), with: .color(dark ? Color(hex: 0x243350) : Color(hex: 0xF5EEDD)))
        ctx.stroke(Path(ellipseIn: rugRect), with: .color((dark ? Palette.amber : Crayon.caramel).opacity(0.32)), lineWidth: 1.4)

        // Grounded birch music-box plinth centered at w * 0.49
        let boxX = w * 0.49
        let boxW = s * 0.14
        let boxH = s * 0.068
        let boxRect = CGRect(x: boxX - boxW * 0.5, y: groundY - boxH + 2, width: boxW, height: boxH)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: boxX, y: groundY + 2), rx: boxW * 0.54, ry: 3.5, dark: dark)
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(roundedRect: boxRect, cornerRadius: 6), bounds: boxRect, dark: dark, warmth: 0.72, grainLines: 2)
        // Brass acoustic horn cone mounted directly onto box top
        ctx.fill(
            Path(ellipseIn: CGRect(x: boxX - 8, y: boxRect.minY - 7, width: 16, height: 10)),
            with: .color(Palette.bead)
        )

        // Vector eighth notes hovering gently above music box during Steps 0–1 (or freeze pre-pause in Step 2)
        if !isFrozenPause {
            let sway = CGFloat(sin(p.raw * .pi * 2.0) * 4.0)
            drawVectorNote(in: &ctx, base: CGPoint(x: boxX - 10, y: boxRect.minY - 24 + sway), col: Palette.amber)
            drawVectorNote(in: &ctx, base: CGPoint(x: boxX + 12, y: boxRect.minY - 30 - sway), col: Crayon.teal)
        }

        switch step {
        case 0:
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: boxX, y: boxRect.minY - 12),
                baseRadius: s * 0.12,
                progress: p.raw,
                tint: Palette.amber,
                dark: dark
            )
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
        case 1:
            // Alternating left/right beat mats pulse with 4/4 rhythm
            let leftOn = sin(p.raw * .pi * 4.0) >= 0
            for (px, isOn, col) in [(w * 0.37, leftOn, Palette.amber), (w * 0.61, !leftOn, Crayon.teal)] {
                let disc = CGRect(x: px - s * 0.055, y: groundY - s * 0.015, width: s * 0.11, height: s * 0.032)
                ctx.fill(Path(ellipseIn: disc), with: .color(col.opacity(isOn ? 0.55 : 0.18)))
            }
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: CGPoint(x: boxX, y: groundY - s * 0.12),
                pulse: p.contact,
                radius: s * 0.10,
                color: Palette.amber
            )
        default:
            if isFrozenPause {
                BespokeStageHelpers.drawPauseHalo(
                    in: &ctx,
                    center: mossCenter,
                    baseRadius: s * 0.19,
                    progress: min(1.0, (p.raw - 0.60) / 0.38),
                    tint: Palette.amber,
                    dark: dark
                )
            } else {
                BespokeStageHelpers.drawContactSparkles(
                    in: &ctx,
                    center: CGPoint(x: mossCenter.x, y: groundY - s * 0.14),
                    pulse: 0.75,
                    radius: s * 0.11,
                    color: Palette.amber
                )
            }
        }
    }

    private func drawVectorNote(in ctx: inout GraphicsContext, base: CGPoint, col: Color) {
        ctx.fill(Path(ellipseIn: CGRect(x: base.x - 4, y: base.y - 3, width: 8, height: 6)), with: .color(col))
        var stem = Path()
        stem.move(to: CGPoint(x: base.x + 3.5, y: base.y))
        stem.addLine(to: CGPoint(x: base.x + 3.5, y: base.y - 13))
        stem.addQuadCurve(to: CGPoint(x: base.x + 9.5, y: base.y - 7), control: CGPoint(x: base.x + 9.5, y: base.y - 11))
        ctx.stroke(stem, with: .color(col), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
    }
}
