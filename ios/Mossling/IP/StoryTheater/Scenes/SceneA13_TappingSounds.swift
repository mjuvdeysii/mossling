import SwiftUI

/// A13 (Tapping & Making Sounds · 4 Steps):
/// Resonant hardwood acoustic playmat with two chunky chamfered maple percussion blocks:
/// Step 0: Otto models gentle tap (anticipation pull-back -> crisp contact & sound rings) ->
/// Step 1: Shared listening stillness as ripples fade -> Step 2: Moss double-taps freely ->
/// Step 3: Alternating tiny teal (soft/slow) & wide warm amber (loud/fast) ripples paired with Otto's words.
struct SceneA13_TappingSounds: View {
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
            let groundY = h * 0.855

            let ottoX = w * 0.23
            let mossX = w * 0.74

            // Sound blocks migrate smoothly from Otto's side (0-1) to Moss's center floor (2-3)
            let activeX: CGFloat = {
                switch step {
                case 0: return w * 0.43
                case 1: return w * 0.46
                case 2: return w * (0.46 + CGFloat(min(1.0, p.action * 1.1)) * 0.10)
                default: return w * 0.56
                }
            }()

            // Gap between left and right wood blocks: snaps shut at contact window
            let blockGap: CGFloat = {
                let wide = s * 0.095
                let tight = s * 0.042
                switch step {
                case 0:
                    if p.raw < 0.16 {
                        return wide + s * 0.025 * CGFloat(p.anticipation)
                    } else if p.raw < 0.48 {
                        let slam = LivingMotionClock.easeOutCubic((p.raw - 0.16) / 0.32)
                        return (wide + s * 0.025) - (wide + s * 0.025 - tight) * CGFloat(slam)
                    } else {
                        return tight + s * 0.022 * CGFloat(p.followThrough)
                    }
                case 1:
                    return tight + s * 0.028
                case 2:
                    // Playful spontaneous bounce tap
                    let tapWave = abs(sin(p.raw * .pi * 2.0))
                    return tight + CGFloat(tapWave) * s * 0.055
                default:
                    return tight + CGFloat(0.5 + 0.5 * sin(p.raw * .pi * 3.0)) * s * 0.045
                }
            }()

            let leftBlockCenter = CGPoint(x: activeX - blockGap, y: groundY - s * 0.042)
            let rightBlockCenter = CGPoint(x: activeX + blockGap, y: groundY - s * 0.042)
            let strikePoint = CGPoint(x: activeX, y: groundY - s * 0.085)

            let mossHopLift: CGFloat = (step == 2 && p.raw >= 0.45)
                ? CGFloat(max(0.0, sin((p.raw - 0.45) / 0.34 * .pi))) * ms * 0.10
                : 0
            let ottoLean: Double = step == 0 ? 7.5 : (step == 1 ? 4.0 : 3.5)
            let mossLean: Double = step >= 2 ? -6.5 : -2.5

            let ottoLook = CGPoint(x: 0.72, y: 0.34)
            let mossLook = CGPoint(x: -0.72, y: 0.32)
            let ottoMood: Mood = step == 1 ? .open : .happy
            let mossMood: Mood = step == 2 ? (p.isContactWindow ? .happy : .wow) : (step == 3 ? .happy : .open)

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
                    drawAcousticStageAndBlocks(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        leftCenter: leftBlockCenter,
                        rightCenter: rightBlockCenter,
                        strikePoint: strikePoint,
                        ottoVoice: CGPoint(x: ottoCenter.x + os * 0.20, y: ottoCenter.y - os * 0.04),
                        mossEar: CGPoint(x: mossCenter.x - ms * 0.18, y: mossCenter.y - ms * 0.04),
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: strikePoint,
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
                    hopping: step == 2 && p.isContactWindow,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.78, y: -0.62),
                    secondaryLagDegrees: -mossLean * 0.42
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: strikePoint,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawAcousticStageAndBlocks(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        leftCenter: CGPoint,
        rightCenter: CGPoint,
        strikePoint: CGPoint,
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
            dayBottom: Color(hex: 0xECE5D1),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        let floorRect = CGRect(x: -6, y: h * 0.74, width: w + 12, height: h * 0.28)
        ctx.fill(
            Path(floorRect),
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x203048) : Color(hex: 0xF3EBD8),
                    dark ? Color(hex: 0x141F32) : Color(hex: 0xD9CEB6)
                ]),
                startPoint: CGPoint(x: w * 0.5, y: h * 0.74),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Draw chunky chamfered maple sound blocks with painted accent bands
        let bw = min(w, h) * 0.088
        let bh = bw * 0.85
        for (center, bandCol, tilt) in [
            (leftCenter, Color(hex: 0x7EB48B), step == 0 && p.raw < 0.46 ? 6.0 : -2.0),
            (rightCenter, Palette.amber, step == 0 && p.raw < 0.46 ? -6.0 : 2.0)
        ] {
            PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: center.x, y: groundY + 1), rx: bw * 0.58, ry: bw * 0.20, dark: dark)
            var bCtx = ctx
            bCtx.translateBy(x: center.x, y: center.y)
            bCtx.rotate(by: .degrees(tilt))
            let rect = CGRect(x: -bw * 0.5, y: -bh * 0.5, width: bw, height: bh)
            let path = Path(roundedRect: rect, cornerRadius: 5)
            PixarDrawHelpers.drawBeechwood(in: &bCtx, path: path, bounds: rect, dark: dark, warmth: 0.7, grainLines: 2)
            let stripe = CGRect(x: -bw * 0.5, y: -bh * 0.14, width: bw, height: bh * 0.28)
            bCtx.fill(Path(stripe), with: .color(bandCol.opacity(0.75)))
            if flat {
                bCtx.stroke(path, with: .color(Color(hex: 0x5A442C).opacity(0.55)), lineWidth: 1.0)
            }
        }

        // Acoustic ripples & tempo comparisons
        switch step {
        case 0:
            BespokeStageHelpers.drawContactSparkles(in: &ctx, center: strikePoint, pulse: p.contact, radius: min(w, h) * 0.11, color: Palette.amber)
            if p.raw >= 0.42 {
                BespokeStageHelpers.drawPauseHalo(
                    in: &ctx,
                    center: strikePoint,
                    baseRadius: min(w, h) * 0.13,
                    progress: min(1.0, (p.raw - 0.42) / 0.58),
                    tint: Palette.amber,
                    dark: dark
                )
            }
        case 1:
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: strikePoint,
                baseRadius: min(w, h) * 0.15,
                progress: p.raw,
                tint: Crayon.teal,
                dark: dark
            )
        case 2:
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: strikePoint,
                pulse: max(p.contact, abs(sin(p.raw * .pi * 2.0)) < 0.18 ? 0.8 : 0.0),
                radius: min(w, h) * 0.11,
                color: Palette.amber
            )
        default:
            // Alternating soft small teal ripple vs wide bold amber ripple + Otto words
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: leftCenter.x, y: strikePoint.y - 6),
                baseRadius: min(w, h) * 0.075,
                progress: p.raw,
                tint: Crayon.teal,
                dark: dark
            )
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: rightCenter.x, y: strikePoint.y - 12),
                baseRadius: min(w, h) * 0.145,
                progress: (p.raw + 0.35).truncatingRemainder(dividingBy: 1.0),
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
                lineWidth: 2.2,
                dark: dark
            )
        }
    }
}
