import SwiftUI

/// A19 (Stacking Chunky Blocks · 3 Steps):
/// Swapped left/right orientation: Moss on LEFT (`0.24..0.28`), Otto illuminating from RIGHT (`0.76`):
/// Step 0: Adult models stacking honey middle block from right edge over a natural short arc onto grounded sage base ->
/// Step 1: Moss stacks coral top block from left side onto the tower with a joyful hop ->
/// Step 2: Top blocks sway and tumble under real quadratic gravity (`t*t`) onto felt mat as Otto encourages.
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

            let mossX = w * (step == 1 ? 0.28 : 0.24)
            let ottoX = w * 0.76
            let towerX = w * 0.49

            let mossHopLift: CGFloat = ((step == 1 || step == 2) && p.raw >= 0.46)
                ? CGFloat(max(0.0, sin((p.raw - 0.46) / 0.34 * .pi))) * ms * 0.11
                : 0
            let mossLean: Double = step == 1 ? 10.5 * p.action : (step == 2 ? 6.0 * p.contactEnvelope : 3.5)
            let ottoLean: Double = step == 0 ? -8.5 * p.action : (step == 2 ? -5.0 : -3.0)

            let mossLook = CGPoint(x: 0.82, y: step == 2 ? 0.22 : 0.06)
            let ottoLook = CGPoint(x: -0.80, y: 0.14)

            let ottoMood: Mood = (step == 2 && p.raw >= 0.46) || (step == 1 && p.raw >= 0.50) ? .happy : .open
            let mossMood: Mood = {
                switch step {
                case 0: return p.raw >= 0.45 ? .wow : .open
                case 1: return p.raw >= 0.44 ? .happy : .wow
                default: return p.raw >= 0.44 ? .happy : .wow
                }
            }()

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
            let towerCenter = CGPoint(x: towerX, y: groundY - s * 0.12)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawBlockStudio(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        towerX: towerX,
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
                    targetPoint: towerCenter,
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
                    hopping: (step == 1 || step == 2) && mossHopLift > ms * 0.03,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: -0.78, y: -0.62),
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
                    lightDirection: CGPoint(x: -0.78, y: -0.62),
                    secondaryLagDegrees: -ottoLean * 0.30
                )
                .position(ottoCenter)

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

        // Centered felt activity mat
        let feltRect = CGRect(x: towerX - s * 0.17, y: groundY - 4, width: s * 0.34, height: 10)
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

        // Grounded sage base block
        if !flat {
            PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: towerX, y: groundY + 1.5), rx: blkSize * 0.58, ry: 4.0, dark: dark)
        }
        drawBlock(in: &ctx, center: CGPoint(x: towerX, y: y0), size: blkSize, color: Crayon.teal, angleDeg: 0, flat: flat, dark: dark)

        switch step {
        case 0:
            // Honey middle block moves from right edge of felt mat onto base over natural low lift (no ceiling drop)
            let arcT = CGFloat(p.action)
            let start = CGPoint(x: towerX + blkSize * 1.25, y: y0)
            let end = CGPoint(x: towerX, y: y1)
            let hx = start.x + (end.x - start.x) * arcT
            let hy = start.y + (end.y - start.y) * arcT - CGFloat(sin(Double(arcT) * .pi)) * s * 0.075
            drawBlock(in: &ctx, center: CGPoint(x: hx, y: hy), size: blkSize, color: Palette.bead, angleDeg: (1.0 - Double(arcT)) * 6.0, flat: flat, dark: dark)

            // Spare coral block waiting grounded on Moss's left side of mat
            let spareX = towerX - blkSize * 1.32
            if !flat {
                PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: spareX, y: groundY + 1.5), rx: blkSize * 0.50, ry: 3.5, dark: dark)
            }
            drawBlock(in: &ctx, center: CGPoint(x: spareX, y: y0), size: blkSize * 0.94, color: Crayon.tangerine, angleDeg: 0, flat: flat, dark: dark)
            BespokeStageHelpers.drawContactSparkles(in: &ctx, center: CGPoint(x: towerX, y: y1), pulse: p.contact, radius: s * 0.09, color: Palette.amber)

        case 1:
            // Honey middle settled; Coral block lifts cleanly from Moss's left side onto top y2
            drawBlock(in: &ctx, center: CGPoint(x: towerX, y: y1), size: blkSize, color: Palette.bead, angleDeg: 0, flat: flat, dark: dark)
            let arcT = CGFloat(p.action)
            let start = CGPoint(x: towerX - blkSize * 1.32, y: y0)
            let end = CGPoint(x: towerX, y: y2)
            let cx = start.x + (end.x - start.x) * arcT
            let cy = start.y + (end.y - start.y) * arcT - CGFloat(sin(Double(arcT) * .pi)) * s * 0.085
            let wobble = p.raw >= 0.46 ? sin((p.raw - 0.46) * 20.0) * 5.0 * (1.0 - p.followThrough) : 0
            drawBlock(in: &ctx, center: CGPoint(x: cx, y: cy), size: blkSize * 0.94, color: Crayon.tangerine, angleDeg: wobble, flat: flat, dark: dark)
            BespokeStageHelpers.drawContactSparkles(in: &ctx, center: end, pulse: p.contact, radius: s * 0.10, color: Palette.amber)

        default:
            // True gravity tumble (drop = t*t) onto felt mat with contact AO + warm Otto encouragement ribbon
            let t = p.action
            let drop = CGFloat(t * t)
            let sway = p.raw < 0.20 ? sin(p.raw * 35.0) * 6.0 : 0.0
            let b1Center = CGPoint(
                x: towerX - CGFloat(t) * blkSize * 1.25,
                y: y1 + drop * (y0 - y1)
            )
            let b2Center = CGPoint(
                x: towerX + CGFloat(t) * blkSize * 1.30,
                y: y2 + drop * (y0 - y2)
            )
            if !flat && t > 0.35 {
                let aoAlpha = Double((t - 0.35) / 0.65)
                PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: b1Center.x, y: groundY + 1.5), rx: blkSize * 0.52, ry: 3.5, dark: dark, opacity: aoAlpha)
                PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: b2Center.x, y: groundY + 1.5), rx: blkSize * 0.48, ry: 3.5, dark: dark, opacity: aoAlpha)
            }
            drawBlock(in: &ctx, center: b1Center, size: blkSize, color: Palette.bead, angleDeg: sway - t * 78.0, flat: flat, dark: dark)
            drawBlock(in: &ctx, center: b2Center, size: blkSize * 0.94, color: Crayon.tangerine, angleDeg: sway + t * 104.0, flat: flat, dark: dark)

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
        let inner = rect.insetBy(dx: size * 0.18, dy: size * 0.18)
        bCtx.stroke(Path(roundedRect: inner, cornerRadius: size * 0.08), with: .color(Color.white.opacity(dark ? 0.18 : 0.32)), lineWidth: 0.9)
    }
}
