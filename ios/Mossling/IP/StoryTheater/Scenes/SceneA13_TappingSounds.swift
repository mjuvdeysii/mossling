import SwiftUI

/// A13 (Tapping & Making Sounds · 4 Steps):
/// Grounded chamfered beechwood acoustic playboard on floor (`w * 0.29...0.71`, bottom at `groundY`):
/// Step 0: Blocks begin beside Otto; left block pivots cleanly on its bottom-right contact corner to tap right block (zero levitation) ->
/// Step 1: Shared listening stillness as calm teal acoustic rings expand ->
/// Step 2: Blocks placed within Moss's reach on the right; right block double-taps from grounded pivot ->
/// Step 3: Alternating small teal (soft/slow) & wide bold amber (loud/fast) ripples paired with Otto's voice ribbon.
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
            let boardTopY = groundY - 8

            let ottoX = w * 0.23
            let mossX = w * 0.74

            // Acoustic blocks shift smoothly from Otto's side (0-1) to Moss's workspace (2-3)
            let activeX: CGFloat = {
                switch step {
                case 0: return w * 0.39
                case 1: return w * 0.42
                case 2: return w * (0.46 + CGFloat(min(1.0, p.action * 1.1)) * 0.14)
                default: return w * 0.58
                }
            }()

            let gap: CGFloat = {
                switch step {
                case 0:
                    let wide = s * 0.058
                    let kiss = s * 0.044
                    if p.raw < 0.18 { return wide }
                    let t = LivingMotionClock.easeOutCubic(min(1.0, (p.raw - 0.18) / 0.28))
                    return wide - (wide - kiss) * CGFloat(t)
                case 1: return s * 0.060
                case 2:
                    let tapWave = abs(sin(p.raw * .pi * 2.0))
                    return s * 0.044 + CGFloat(tapWave) * s * 0.022
                default:
                    return s * 0.056
                }
            }()

            let leftPivotAngle: Double = {
                if step == 0 {
                    if p.raw < 0.18 { return -14.0 * p.anticipation }
                    if p.raw < 0.46 {
                        let t = LivingMotionClock.easeOutCubic((p.raw - 0.18) / 0.28)
                        return -14.0 * (1.0 - t)
                    }
                    return 0.0
                }
                return step == 3 ? sin(p.raw * .pi * 2.0) * 6.0 : 0.0
            }()

            let rightPivotAngle: Double = {
                if step == 2 {
                    return abs(sin(p.raw * .pi * 2.0)) * 12.0
                }
                return step == 3 ? -abs(sin(p.raw * .pi * 3.0)) * 10.0 : 0.0
            }()

            let mossHopLift: CGFloat = (step == 2 && p.raw >= 0.45)
                ? CGFloat(max(0.0, sin((p.raw - 0.45) / 0.34 * .pi))) * ms * 0.10
                : 0
            let ottoLean: Double = step == 0 ? 10.0 * p.action : (step == 1 ? 4.0 : 3.5)
            let mossLean: Double = step >= 2 ? -10.0 * p.action : -2.5

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
            let strikePoint = CGPoint(x: activeX, y: boardTopY - s * 0.045)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawAcousticStageAndBlocks(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        boardTopY: boardTopY,
                        activeX: activeX,
                        gap: gap,
                        leftPivotAngle: leftPivotAngle,
                        rightPivotAngle: rightPivotAngle,
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
        boardTopY: CGFloat,
        activeX: CGFloat,
        gap: CGFloat,
        leftPivotAngle: Double,
        rightPivotAngle: Double,
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

        // Grounded chamfered beechwood acoustic board across workspace
        let boardRect = CGRect(x: w * 0.29, y: boardTopY, width: w * 0.42, height: 10)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: boardRect.midX, y: groundY + 3), rx: boardRect.width * 0.48, ry: 4.5, dark: dark)
        PixarDrawHelpers.drawBeechwood(
            in: &ctx,
            path: Path(roundedRect: boardRect, cornerRadius: 4),
            bounds: boardRect,
            dark: dark,
            warmth: 0.55,
            grainLines: 2
        )

        let bw = min(w, h) * 0.088
        let bh = bw * 0.85
        let leftCenter = CGPoint(x: activeX - gap, y: boardTopY - bh * 0.5)
        let rightCenter = CGPoint(x: activeX + gap, y: boardTopY - bh * 0.5)

        // Draw left block pivoting around bottom-right corner & right block pivoting around bottom-left corner (always grounded)
        drawGroundedPivotedBlock(
            in: &ctx,
            center: leftCenter,
            bw: bw,
            bh: bh,
            boardTopY: boardTopY,
            bandCol: Color(hex: 0x7EB48B),
            pivotRight: true,
            angleDeg: leftPivotAngle,
            flat: flat,
            dark: dark
        )
        drawGroundedPivotedBlock(
            in: &ctx,
            center: rightCenter,
            bw: bw,
            bh: bh,
            boardTopY: boardTopY,
            bandCol: Palette.amber,
            pivotRight: false,
            angleDeg: rightPivotAngle,
            flat: flat,
            dark: dark
        )

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

    private func drawGroundedPivotedBlock(
        in ctx: inout GraphicsContext,
        center: CGPoint,
        bw: CGFloat,
        bh: CGFloat,
        boardTopY: CGFloat,
        bandCol: Color,
        pivotRight: Bool,
        angleDeg: Double,
        flat: Bool,
        dark: Bool
    ) {
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: center.x, y: boardTopY + 1), rx: bw * 0.54, ry: 3.2, dark: dark)
        let pivotX = pivotRight ? center.x + bw * 0.5 : center.x - bw * 0.5
        let pivotY = boardTopY

        var bCtx = ctx
        bCtx.translateBy(x: pivotX, y: pivotY)
        bCtx.rotate(by: .degrees(angleDeg))
        bCtx.translateBy(x: center.x - pivotX, y: center.y - pivotY)

        let rect = CGRect(x: -bw * 0.5, y: -bh * 0.5, width: bw, height: bh)
        let path = Path(roundedRect: rect, cornerRadius: 5)
        PixarDrawHelpers.drawBeechwood(in: &bCtx, path: path, bounds: rect, dark: dark, warmth: 0.7, grainLines: 2)
        let stripe = CGRect(x: -bw * 0.5, y: -bh * 0.14, width: bw, height: bh * 0.28)
        bCtx.fill(Path(stripe), with: .color(bandCol.opacity(0.75)))
        if flat {
            bCtx.stroke(path, with: .color(Color(hex: 0x5A442C).opacity(0.55)), lineWidth: 1.0)
        }
    }
}
