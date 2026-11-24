import SwiftUI

/// A19 (Stacking Chunky Blocks · 3 Steps):
/// Upgrades A19 to a bespoke sculpted beech-block studio table with chamfered hardwood blocks (sage base,
/// honey-beech middle, coral-terracotta top):
/// Step 0: Otto models calmly lowering the honey block onto the sage base ->
/// Step 1: Moss stacks the coral top block cleanly with joyful celebratory hop ->
/// Step 2: Top blocks sway and playfully tumble onto the felt mat as Otto sends warm encouragement.
struct SceneA19_StackingChunkyBlocks: View {
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

            let ottoX = w * 0.23
            let mossX = w * 0.77
            let towerX = w * 0.50

            let mossHopLift: CGFloat = ((step == 1 || step == 2) && p.raw >= 0.46)
                ? CGFloat(max(0.0, sin((p.raw - 0.46) / 0.34 * .pi))) * ms * 0.11
                : 0
            let ottoLean: Double = step == 0 ? 8.5 * p.action : (step == 2 ? 5.0 : 3.0)
            let mossLean: Double = step == 1 ? -9.5 * p.action : (step == 2 ? -6.5 * p.contactEnvelope : -3.0)

            let ottoLook = CGPoint(x: 0.80, y: 0.12)
            let mossLook = CGPoint(x: -0.82, y: step == 2 ? 0.22 : 0.05)

            let ottoMood: Mood = (step == 2 && p.raw >= 0.46) || (step == 1 && p.raw >= 0.50) ? .happy : .open
            let mossMood: Mood = {
                switch step {
                case 0: return p.raw >= 0.45 ? .wow : .open
                case 1: return p.raw >= 0.44 ? .happy : .wow
                default: return p.raw >= 0.44 ? .happy : .wow
                }
            }()

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
            let towerCenter = CGPoint(x: towerX, y: groundY - s * 0.12)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawBlockStudio(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        towerX: towerX,
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
                    targetPoint: towerCenter,
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
                    hopping: (step == 1 || step == 2) && mossHopLift > ms * 0.03,
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
                    targetPoint: towerCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawBlockStudio(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        towerX: CGFloat,
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

        let s = min(w, h)
        let floorRect = CGRect(x: -6, y: h * 0.75, width: w + 12, height: h * 0.27)
        ctx.fill(
            Path(floorRect),
            with: .linearGradient(
                Gradient(colors: [dark ? Color(hex: 0x1E2A44) : Color(hex: 0xEFE5D0), dark ? Color(hex: 0x131B2E) : Color(hex: 0xD8CCB4)]),
                startPoint: CGPoint(x: w * 0.5, y: h * 0.75),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Felt activity mat centered between Otto and Moss
        let feltRect = CGRect(x: towerX - s * 0.16, y: groundY - 4, width: s * 0.32, height: 10)
        let feltPath = Path(roundedRect: feltRect, cornerRadius: 5)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: feltPath,
                bounds: feltRect,
                light: dark ? Color(hex: 0x2B415B) : Color(hex: 0xE6EFE2),
                rich: dark ? Color(hex: 0x1E2F44) : Color(hex: 0xC8D8C2),
                pencilOutline: (dark ? Color(hex: 0x5B7B9C) : Color(hex: 0x6F8C6A)).opacity(0.50),
                lineWidth: 1.0
            )
        } else {
            PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: towerX, y: groundY + 4), rx: feltRect.width * 0.48, ry: 4.5, dark: dark)
            ctx.fill(feltPath, with: .color(dark ? Color(hex: 0x263A52) : Color(hex: 0xDCE8D6)))
        }

        let blkSize = s * 0.088
        let y0 = groundY - blkSize * 0.5
        let y1 = y0 - blkSize + 1
        let y2 = y1 - blkSize + 1

        // Base block 1 (Sage)
        if !flat {
            PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: towerX, y: groundY + 1.5), rx: blkSize * 0.58, ry: 4.0, dark: dark)
        }
        drawBlock(in: &ctx, center: CGPoint(x: towerX, y: y0), size: blkSize, color: Crayon.teal, angleDeg: 0, flat: flat, dark: dark)

        switch step {
        case 0:
            // Honey middle block lowers smoothly onto sage base
            let lift = CGFloat(1.0 - p.action) * s * 0.18
            drawBlock(in: &ctx, center: CGPoint(x: towerX, y: y1 - lift), size: blkSize, color: Palette.bead, angleDeg: (1.0 - p.action) * -6.0, flat: flat, dark: dark)
            // Spare coral block waiting gently beside base
            if !flat {
                PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: towerX + blkSize * 1.35, y: groundY + 1.5), rx: blkSize * 0.50, ry: 3.5, dark: dark)
            }
            drawBlock(in: &ctx, center: CGPoint(x: towerX + blkSize * 1.35, y: y0), size: blkSize * 0.94, color: Crayon.tangerine, angleDeg: 0, flat: flat, dark: dark)
            BespokeStageHelpers.drawContactSparkles(in: &ctx, center: CGPoint(x: towerX, y: y1), pulse: p.contact, radius: s * 0.09, color: Palette.amber)

        case 1:
            // Honey middle already settled; Coral top block rises from right & lands cleanly
            drawBlock(in: &ctx, center: CGPoint(x: towerX, y: y1), size: blkSize, color: Palette.bead, angleDeg: 0, flat: flat, dark: dark)
            let arcT = CGFloat(p.action)
            let start = CGPoint(x: towerX + blkSize * 1.35, y: y0)
            let end = CGPoint(x: towerX, y: y2)
            let cx = start.x + (end.x - start.x) * arcT
            let cy = start.y + (end.y - start.y) * arcT - CGFloat(sin(Double(arcT) * .pi)) * s * 0.14
            let wobble = p.raw >= 0.46 ? sin((p.raw - 0.46) * 20.0) * 5.0 * (1.0 - p.followThrough) : 0
            drawBlock(in: &ctx, center: CGPoint(x: cx, y: cy), size: blkSize * 0.94, color: Crayon.tangerine, angleDeg: wobble, flat: flat, dark: dark)
            BespokeStageHelpers.drawContactSparkles(in: &ctx, center: end, pulse: p.contact, radius: s * 0.10, color: Palette.amber)

        default:
            // Step 2: Top two blocks sway playfully, then tumble onto the mat with warm voice invitation
            let tumble = p.action
            let sway = p.raw < 0.20 ? sin(p.raw * 35.0) * 6.0 : 0.0
            let b1Center = CGPoint(
                x: towerX - CGFloat(tumble) * blkSize * 1.25,
                y: y1 + CGFloat(tumble) * (y0 - y1)
            )
            let b2Center = CGPoint(
                x: towerX + CGFloat(tumble) * blkSize * 1.30,
                y: y2 + CGFloat(tumble) * (y0 - y2)
            )
            if !flat && tumble > 0.35 {
                let aoAlpha = Double((tumble - 0.35) / 0.65)
                PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: b1Center.x, y: groundY + 1.5), rx: blkSize * 0.52, ry: 3.5, dark: dark, opacity: aoAlpha)
                PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: b2Center.x, y: groundY + 1.5), rx: blkSize * 0.48, ry: 3.5, dark: dark, opacity: aoAlpha)
            }
            drawBlock(in: &ctx, center: b1Center, size: blkSize, color: Palette.bead, angleDeg: sway - tumble * 76.0, flat: flat, dark: dark)
            drawBlock(in: &ctx, center: b2Center, size: blkSize * 0.94, color: Crayon.tangerine, angleDeg: sway + tumble * 108.0, flat: flat, dark: dark)

            BespokeStageHelpers.drawContactSparkles(in: &ctx, center: CGPoint(x: towerX, y: y1), pulse: p.contact, radius: s * 0.11, color: Palette.amber)
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoVoice,
                to: mossEar,
                progress: p.followThrough,
                waveOffset: p.raw * .pi * 2.0,
                color: Palette.amber,
                lineWidth: 2.3,
                dark: dark
            )
        }
    }

    private func drawBlock(
        in ctx: inout GraphicsContext,
        center: CGPoint,
        size: CGFloat,
        color: Color,
        angleDeg: Double,
        flat: Bool,
        dark: Bool
    ) {
        var bCtx = ctx
        bCtx.translateBy(x: center.x, y: center.y)
        bCtx.rotate(by: .degrees(angleDeg))
        let rect = CGRect(x: -size * 0.5, y: -size * 0.5, width: size, height: size)
        let path = Path(roundedRect: rect, cornerRadius: size * 0.18)

        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &bCtx,
                path: path,
                bounds: rect,
                light: color.mix(with: .white, by: 0.24),
                rich: color,
                pencilOutline: (dark ? color.mix(with: .white, by: 0.45) : color.mix(with: .black, by: 0.35)).opacity(0.68),
                lineWidth: 1.15
            )
        } else {
            bCtx.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: [color.mix(with: .white, by: 0.28), color, color.mix(with: .black, by: 0.18)]),
                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            )
            bCtx.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [Color.white.opacity(0.55), Color.clear]),
                    startPoint: CGPoint(x: rect.midX, y: rect.minY),
                    endPoint: CGPoint(x: rect.midX, y: rect.maxY)
                ),
                lineWidth: 1.1
            )
        }
        // Subtle chamfered inner bevel square
        let inner = rect.insetBy(dx: size * 0.18, dy: size * 0.18)
        bCtx.stroke(Path(roundedRect: inner, cornerRadius: size * 0.08), with: .color(Color.white.opacity(dark ? 0.18 : 0.32)), lineWidth: 0.9)
    }
}
