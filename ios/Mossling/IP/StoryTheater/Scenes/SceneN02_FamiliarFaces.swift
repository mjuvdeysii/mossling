import SwiftUI

/// N02: Window-seat two-shot with sunlit/moonlit casement window, sheer curtain, swaying birch branch,
/// gentle gaze tether in Step 0, and respectful pace slow-down when Moss looks away in Step 1.
struct SceneN02_FamiliarFaces: View {
    let ctx: BespokeSceneContext

    var body: some View {
        let step = min(max(0, ctx.stepIndex), 1)
        let p = ctx.phase
        let dark = ctx.dark
        let flat = ctx.flat

        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let h = max(1, geo.size.height)
            let s = min(w, h)

            let ms = s * 0.36
            let os = ms * Kind.otto.scale
            let groundOtto = h * 0.805
            let groundMoss = h * 0.845

            let ottoX = w * 0.295
            let mossX = w * 0.715

            // Step 1: Moss looks away toward outdoor swaying branch & Otto leans gently back to give room
            let awayT = step == 1 ? min(1.0, max(0.0, p.action * 1.15 - p.hold * 0.15)) : 0.0
            let mossLook = step == 0
                ? CGPoint(x: -0.78, y: -0.08)
                : CGPoint(x: -0.60 + awayT * 1.42, y: -0.10 - awayT * 0.28)
            let ottoLook = CGPoint(x: 0.80, y: 0.08)

            let ottoLean = step == 0
                ? 5.0 + sin(p.raw * .pi * 2.0) * 1.8
                : 4.5 - awayT * 7.5
            let mossLean = step == 0
                ? -2.5 * sin(p.raw * .pi)
                : awayT * 6.5

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundOtto, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundMoss, flat: flat)
            )
            let ottoMood: Mood = step == 0 ? .happy : .open
            let mossMood: Mood = step == 0 ? (p.action > 0.4 ? .happy : .open) : (awayT > 0.55 ? .open : .wow)
            let ottoLid: Double = step == 1 ? (dark ? 0.54 : 0.42) : (dark ? 0.42 : 0.26)

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: ottoLid, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )
            let targetWorld = CGPoint(x: mossCenter.x - ms * 0.10, y: mossCenter.y - ms * 0.04)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawWindowSet(in: &c, w: size.width, h: size.height, step: step, p: p, awayT: awayT, flat: flat, dark: dark)
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: targetWorld,
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
                    lid: ottoLid,
                    lean: ottoLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: -0.70, y: -0.70),
                    secondaryLagDegrees: -ottoLean * 0.28
                )
                .position(ottoCenter)

                StoryTheaterActorView(
                    kind: .moss,
                    size: ms,
                    mood: mossMood,
                    look: mossLook,
                    lid: dark ? 0.24 : 0,
                    lean: mossLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: -0.70, y: -0.70),
                    secondaryLagDegrees: -mossLean * 0.40
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: targetWorld,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawWindowSet(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        step: Int,
        p: LivingPhaseSample,
        awayT: Double,
        flat: Bool,
        dark: Bool
    ) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xFBF6E8),
            dayBottom: Color(hex: 0xEAE0CB),
            nightTop: Color(hex: 0x0A1224),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        // Arched wooden casement window spanning upper-left & center-right
        let winRect = CGRect(x: w * 0.11, y: h * 0.08, width: w * 0.78, height: h * 0.56)
        let winShape = Path(roundedRect: winRect, cornerRadius: min(w, h) * 0.06)
        ctx.fill(
            winShape,
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x121F3B) : Color(hex: 0xDDECF2),
                    dark ? Color(hex: 0x1B2D52) : Color(hex: 0xF5F1DF)
                ]),
                startPoint: CGPoint(x: winRect.midX, y: winRect.minY),
                endPoint: CGPoint(x: winRect.midX, y: winRect.maxY)
            )
        )

        // Outdoor swaying birch branch & leaves visible through upper-right pane
        var clippedWin = ctx
        clippedWin.clip(to: winShape)
        let branchSway = CGFloat(sin(p.raw * .pi * 2.0) * 6.0)
        var branch = Path()
        branch.move(to: CGPoint(x: winRect.maxX + 6, y: winRect.minY + winRect.height * 0.16))
        branch.addQuadCurve(
            to: CGPoint(x: winRect.midX + winRect.width * 0.08 + branchSway, y: winRect.minY + winRect.height * 0.44),
            control: CGPoint(x: winRect.maxX - winRect.width * 0.16, y: winRect.minY + winRect.height * 0.28)
        )
        clippedWin.stroke(branch, with: .color((dark ? Color(hex: 0x455880) : Color(hex: 0x8C7456)).opacity(0.65)), lineWidth: 2.4)

        let leafPositions: [(CGFloat, CGFloat, Double)] = [
            (0.76, 0.25, -24), (0.68, 0.36, -12), (0.83, 0.38, 18), (0.62, 0.43, -30)
        ]
        for (fx, fy, ang) in leafPositions {
            let center = CGPoint(x: winRect.minX + winRect.width * fx + branchSway * 0.8, y: winRect.minY + winRect.height * fy)
            var lc = clippedWin
            lc.translateBy(x: center.x, y: center.y)
            lc.rotate(by: .degrees(ang + Double(branchSway) * 0.8))
            let leafRect = CGRect(x: -9, y: -4.5, width: 18, height: 9)
            lc.fill(
                Path(ellipseIn: leafRect),
                with: .color((dark ? Color(hex: 0x2E4B49) : Color(hex: 0x91B883)).opacity(dark ? 0.72 : 0.86))
            )
        }

        // Translucent sheer gauzy linen curtain softening the left window edge
        let swayCur = CGFloat(sin(p.raw * .pi * 2.0) * 4.5)
        var curtain = Path()
        curtain.move(to: CGPoint(x: winRect.minX, y: winRect.minY))
        curtain.addLine(to: CGPoint(x: winRect.minX + winRect.width * 0.24, y: winRect.minY))
        curtain.addQuadCurve(
            to: CGPoint(x: winRect.minX + winRect.width * 0.16 + swayCur, y: winRect.maxY),
            control: CGPoint(x: winRect.minX + winRect.width * 0.26 - swayCur, y: winRect.midY)
        )
        curtain.addLine(to: CGPoint(x: winRect.minX, y: winRect.maxY))
        curtain.closeSubpath()
        clippedWin.fill(curtain, with: .color((dark ? Color(hex: 0x6277A8) : Color.white).opacity(dark ? 0.22 : 0.56)))

        // Casement window mullions & frame
        let woodTint = dark ? Color(hex: 0x354469) : Color(hex: 0xD9BC90)
        ctx.stroke(winShape, with: .color(woodTint), lineWidth: 5.5)
        var crossV = Path()
        crossV.move(to: CGPoint(x: winRect.midX, y: winRect.minY))
        crossV.addLine(to: CGPoint(x: winRect.midX, y: winRect.maxY))
        ctx.stroke(crossV, with: .color(woodTint.opacity(0.85)), lineWidth: 3.0)

        // Beechwood window seat bench & lower sunlit floor cushion
        let benchRect = CGRect(x: w * 0.06, y: h * 0.785, width: w * 0.44, height: h * 0.08)
        let benchPath = Path(roundedRect: benchRect, cornerRadius: 8)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: benchPath,
                bounds: benchRect,
                light: dark ? Color(hex: 0x5B4736) : Color(hex: 0xEAC895),
                rich: dark ? Color(hex: 0x3B2E24) : Color(hex: 0xC69A61),
                pencilOutline: (dark ? Color(hex: 0x8A7158) : Color(hex: 0x8C673B)).opacity(0.5),
                lineWidth: 1.1
            )
        } else {
            PixarDrawHelpers.drawBeechwood(in: &ctx, path: benchPath, bounds: benchRect, dark: dark, warmth: 0.7, grainLines: 2)
        }

        // Knit floor cushion on right for Moss
        let poufRect = CGRect(x: w * 0.55, y: h * 0.80, width: w * 0.33, height: h * 0.14)
        let poufPath = Path(ellipseIn: poufRect)
        ctx.fill(
            poufPath,
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x2F4754) : Color(hex: 0xDFEAE0),
                    dark ? Color(hex: 0x1E2F3D) : Color(hex: 0xBDCFC0)
                ]),
                startPoint: CGPoint(x: poufRect.midX, y: poufRect.minY),
                endPoint: CGPoint(x: poufRect.midX, y: poufRect.maxY)
            )
        )

        // Eye-line tether in Step 0, or gentle waiting rest ripple in Step 1
        let anchorA = CGPoint(x: w * 0.38, y: h * 0.48)
        let anchorB = CGPoint(x: w * 0.62, y: h * 0.54)
        if step == 0 {
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: anchorA,
                to: anchorB,
                progress: min(1.0, 0.35 + p.action * 0.65),
                waveOffset: p.raw * .pi * 2.0,
                color: Palette.amber,
                lineWidth: 2.2,
                dark: dark
            )
        } else {
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: w * 0.50, y: h * 0.50),
                baseRadius: min(w, h) * 0.10,
                progress: awayT,
                tint: dark ? Color(hex: 0x90DBA6) : Color(hex: 0x6AA87B),
                dark: dark
            )
        }
    }
}
