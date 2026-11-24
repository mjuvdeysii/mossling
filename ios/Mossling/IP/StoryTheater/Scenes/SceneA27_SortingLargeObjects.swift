import SwiftUI

/// A27 (Sorting Large Objects · 3 Steps):
/// Sunlight Montessori floor studio with two shallow birch sorting trays & 4 chunky oversized objects
/// (terracotta sphere, sage sphere, sunflower cube, teal cube):
/// Step 0: Adult models grouping by shape (spheres slide low into left tray, cubes in right tray) ->
/// Step 1: Child slides the sunflower cube independently into the right tray ->
/// Step 2: Child switches freely to warm vs cool color sorting (both meaningful!), affirmed by Otto's warm halo.
struct SceneA27_SortingLargeObjects: View {
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
            let groundY = h * 0.87

            let mossX = w * (step == 1 ? 0.25 : 0.21)
            let ottoX = w * 0.79
            let centerSpot = CGPoint(x: w * 0.50, y: groundY - s * 0.04)

            let mossHopLift: CGFloat = (step == 1 && p.raw >= 0.46)
                ? CGFloat(max(0.0, sin((p.raw - 0.46) / 0.34 * .pi))) * ms * 0.095
                : 0
            let mossLean: Double = step == 1 ? 9.5 * p.action : (step == 2 ? 5.0 : 3.5)
            let ottoLean: Double = step == 0 ? -8.5 * p.action : (step == 2 ? -5.0 : -3.0)

            let mossLook = CGPoint(x: 0.80, y: 0.26)
            let ottoLook = CGPoint(x: -0.78, y: 0.26)
            let mossMood: Mood = step == 1 ? (p.raw >= 0.44 ? .happy : .wow) : (step == 2 ? .happy : .open)
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
                    drawSortingTraysStage(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
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
                    targetPoint: centerSpot,
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
                    hopping: step == 1 && mossHopLift > ms * 0.03,
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
                    targetPoint: centerSpot,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawSortingTraysStage(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
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
            dayBottom: Color(hex: 0xECE4D0),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        if flat {
            GhibliDrawHelpers.drawKomorebiCanopy(in: &ctx, w: w, h: h, swayOffset: 0, dark: dark)
        }

        let s = min(w, h)
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

        let leftTrayCenter = CGPoint(x: w * 0.39, y: groundY - s * 0.015)
        let rightTrayCenter = CGPoint(x: w * 0.61, y: groundY - s * 0.015)
        let trayW = s * 0.19
        let trayH = s * 0.052

        for tc in [leftTrayCenter, rightTrayCenter] {
            let rect = CGRect(x: tc.x - trayW * 0.5, y: groundY - trayH + 2, width: trayW, height: trayH)
            PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: tc.x, y: groundY + 2), rx: trayW * 0.52, ry: 3.5, dark: dark)
            PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(roundedRect: rect, cornerRadius: 5), bounds: rect, dark: dark, warmth: 0.65, grainLines: 2)
        }

        let r = s * 0.036
        let blk = s * 0.064
        let restYBall = groundY - trayH * 0.68 - r
        let restYCube = groundY - trayH * 0.68 - blk * 0.5

        // Object positions evolve meaningfully per step:
        // Step 0: Shape grouping (Spheres left, Cubes right; sunflower cube staging in middle -> slides cleanly on Step 1)
        // Step 2: Color-warmth grouping (Terracotta sphere + Sunflower cube left, Sage sphere + Teal cube right)
        let terraPos: CGPoint
        let sagePos: CGPoint
        let sunPos: CGPoint
        let tealPos: CGPoint

        switch step {
        case 0:
            let slide = CGFloat(p.action)
            terraPos = CGPoint(x: w * 0.50 + (leftTrayCenter.x - s * 0.042 - w * 0.50) * slide, y: restYBall)
            sagePos = CGPoint(x: leftTrayCenter.x + s * 0.042, y: restYBall)
            sunPos = CGPoint(x: w * 0.50, y: groundY - blk * 0.5)
            tealPos = CGPoint(x: rightTrayCenter.x + s * 0.042, y: restYCube)
        case 1:
            let slide = CGFloat(p.action)
            terraPos = CGPoint(x: leftTrayCenter.x - s * 0.042, y: restYBall)
            sagePos = CGPoint(x: leftTrayCenter.x + s * 0.042, y: restYBall)
            sunPos = CGPoint(
                x: w * 0.50 + (rightTrayCenter.x - s * 0.042 - w * 0.50) * slide,
                y: (groundY - blk * 0.5) * (1.0 - slide) + restYCube * slide - CGFloat(sin(Double(slide) * .pi)) * s * 0.04
            )
            tealPos = CGPoint(x: rightTrayCenter.x + s * 0.042, y: restYCube)
        default:
            let swapT = CGFloat(p.action)
            terraPos = CGPoint(x: leftTrayCenter.x - s * 0.042, y: restYBall)
            let sStart = CGPoint(x: leftTrayCenter.x + s * 0.042, y: restYBall)
            let sEnd = CGPoint(x: rightTrayCenter.x - s * 0.042, y: restYBall)
            sagePos = CGPoint(
                x: sStart.x + (sEnd.x - sStart.x) * swapT,
                y: restYBall - CGFloat(sin(Double(swapT) * .pi)) * s * 0.055
            )
            let cStart = CGPoint(x: rightTrayCenter.x - s * 0.042, y: restYCube)
            let cEnd = CGPoint(x: leftTrayCenter.x + s * 0.042, y: restYCube)
            sunPos = CGPoint(
                x: cStart.x + (cEnd.x - cStart.x) * swapT,
                y: restYCube - CGFloat(sin(Double(swapT) * .pi)) * s * 0.035
            )
            tealPos = CGPoint(x: rightTrayCenter.x + s * 0.042, y: restYCube)
        }

        drawChunkySphere(in: &ctx, center: terraPos, r: r, col: Color(hex: 0xD97D54), flat: flat, dark: dark)
        drawChunkySphere(in: &ctx, center: sagePos, r: r, col: Color(hex: 0x7EB48B), flat: flat, dark: dark)
        drawChunkyCube(in: &ctx, center: sunPos, size: blk, col: Crayon.sunflower, flat: flat, dark: dark)
        drawChunkyCube(in: &ctx, center: tealPos, size: blk, col: Crayon.teal, flat: flat, dark: dark)

        if step == 2 {
            for tc in [leftTrayCenter, rightTrayCenter] {
                BespokeStageHelpers.drawPauseHalo(
                    in: &ctx,
                    center: CGPoint(x: tc.x, y: groundY - trayH - s * 0.02),
                    baseRadius: s * 0.10,
                    progress: p.action,
                    tint: Palette.amber,
                    dark: dark
                )
            }
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
        } else {
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: step == 0 ? leftTrayCenter : rightTrayCenter,
                pulse: p.contact,
                radius: s * 0.10,
                color: Palette.amber
            )
        }
    }

    private func drawChunkySphere(in ctx: inout GraphicsContext, center: CGPoint, r: CGFloat, col: Color, flat: Bool, dark: Bool) {
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: center.x, y: center.y + r), rx: r * 0.9, ry: r * 0.25, dark: dark)
        ctx.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [col.mix(with: .white, by: flat ? 0.14 : 0.34), col, col.mix(with: .black, by: 0.20)]),
                center: CGPoint(x: center.x - r * 0.28, y: center.y - r * 0.28),
                startRadius: 1,
                endRadius: r * 1.3
            )
        )
        if flat {
            ctx.stroke(Path(ellipseIn: rect), with: .color(col.mix(with: .black, by: 0.38).opacity(0.60)), lineWidth: 1.0)
        }
    }

    private func drawChunkyCube(in ctx: inout GraphicsContext, center: CGPoint, size: CGFloat, col: Color, flat: Bool, dark: Bool) {
        let rect = CGRect(x: center.x - size * 0.5, y: center.y - size * 0.5, width: size, height: size)
        let path = Path(roundedRect: rect, cornerRadius: size * 0.20)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: center.x, y: center.y + size * 0.5), rx: size * 0.52, ry: size * 0.18, dark: dark)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: path,
                bounds: rect,
                light: col.mix(with: .white, by: 0.22),
                rich: col,
                pencilOutline: col.mix(with: .black, by: 0.35).opacity(0.65),
                lineWidth: 1.05
            )
        } else {
            ctx.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: [col.mix(with: .white, by: 0.25), col, col.mix(with: .black, by: 0.16)]),
                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            )
        }
    }
}
