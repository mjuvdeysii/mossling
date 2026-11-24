import SwiftUI

/// A32 (Parallel Play & Turn-Taking with Peers · 3 Steps):
/// Shared courtyard playroom floor with Moss on LEFT oval linen mat (`0.24`), calm supervising Otto centered slightly back (`0.50`),
/// and a serene wooden minimalist peg-peer seated on the RIGHT oval linen mat (`0.77`, zero blush, zero mouth dots):
/// Step 0: Moss & peer play comfortably side by side on their separate mats while Otto calmly watches ->
/// Step 1: Soft boundary rings illuminate as a grounded beechwood rolling car trades smoothly left <-> right ->
/// Step 2: Brief center tug resolves with a golden mediation halo and balanced dual ribbons helping both express turns.
struct SceneA32_ParallelPlayTurnTaking: View {
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

            let ms = s * 0.32
            let os = ms * Kind.otto.scale
            let groundY = h * 0.87
            let ottoGroundY = h * 0.785

            let mossX = w * (step == 2 && p.raw < 0.42 ? 0.28 : 0.23)
            let ottoX = w * 0.50
            let peerX = w * (step == 2 && p.raw < 0.42 ? 0.72 : 0.77)

            let mossHopLift: CGFloat = (step == 2 && p.raw >= 0.48)
                ? CGFloat(max(0.0, sin((p.raw - 0.48) / 0.34 * .pi))) * ms * 0.09
                : 0
            let mossLean: Double = step == 2 ? (p.raw < 0.42 ? 6.5 : 3.5) : 2.5
            let ottoLean: Double = step == 1 ? sin(p.raw * .pi * 2.0) * 4.5 : 0.0

            let mossLook = step == 0 ? CGPoint(x: 0.78, y: 0.08) : CGPoint(x: 0.78, y: 0.24)
            let ottoLook = step == 1 ? CGPoint(x: sin(p.raw * .pi * 2.0) * 0.55, y: 0.32) : CGPoint(x: 0.0, y: 0.35)
            let mossMood: Mood = step == 2 ? (p.raw < 0.42 ? .wow : .happy) : (step == 1 ? .happy : .open)
            let ottoMood: Mood = step == 0 ? .open : .happy

            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat, lift: mossHopLift)
            )
            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: ottoGroundY, flat: flat)
            )

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.34 : 0.20, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )
            let sharePoint = CGPoint(x: w * 0.50, y: groundY - s * 0.035)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawParallelPlayMatsAndPeerBackdrop(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        peerX: peerX,
                        ottoCenter: ottoCenter,
                        mossCenter: mossCenter,
                        ottoSize: os,
                        mossSize: ms,
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: sharePoint,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .floorPool
                )

                // Supervising Otto in midground plane behind active turn-taking lane
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
                    lightDirection: CGPoint(x: 0.0, y: -0.92),
                    secondaryLagDegrees: -ottoLean * 0.30
                )
                .position(ottoCenter)

                // Foreground actors + grounded shared rolling toy
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
                    lightDirection: CGPoint(x: 0.0, y: -0.92),
                    secondaryLagDegrees: -mossLean * 0.42
                )
                .position(mossCenter)

                Canvas(rendersAsynchronously: false) { c, size in
                    drawPeerToyAndMediationForeground(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        peerX: peerX,
                        ottoVoice: CGPoint(x: ottoCenter.x, y: ottoCenter.y + os * 0.06),
                        mossEar: CGPoint(x: mossCenter.x + ms * 0.18, y: mossCenter.y - ms * 0.04),
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: sharePoint,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawParallelPlayMatsAndPeerBackdrop(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        peerX: CGFloat,
        ottoCenter: CGPoint,
        mossCenter: CGPoint,
        ottoSize: CGFloat,
        mossSize: CGFloat,
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
        let floorRect = CGRect(x: -6, y: h * 0.72, width: w + 12, height: h * 0.30)
        ctx.fill(
            Path(floorRect),
            with: .linearGradient(
                Gradient(colors: [dark ? Color(hex: 0x1E2A44) : Color(hex: 0xEFE5D0), dark ? Color(hex: 0x131B2E) : Color(hex: 0xD8CCB4)]),
                startPoint: CGPoint(x: w * 0.5, y: h * 0.72),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Two distinct grounded oval linen play mats with subtle boundary border rings
        let matW = s * 0.30
        let matH = s * 0.115
        for (cx, col) in [(w * 0.24, Palette.mintPale), (w * 0.76, Crayon.caramel.opacity(0.28))] {
            let mRect = CGRect(x: cx - matW * 0.5, y: groundY - matH * 0.55, width: matW, height: matH)
            PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: cx, y: mRect.maxY + 1), rx: matW * 0.48, ry: 3.5, dark: dark)
            ctx.fill(Path(ellipseIn: mRect), with: .color(dark ? Color(hex: 0x22324C) : col))
            if step == 1 {
                ctx.stroke(
                    Path(ellipseIn: mRect.insetBy(dx: -3, dy: -2)),
                    with: .color(Palette.amber.opacity(dark ? 0.58 : 0.48)),
                    style: StrokeStyle(lineWidth: 1.6, dash: [5, 4])
                )
            }
        }
    }

    private func drawPeerToyAndMediationForeground(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        peerX: CGFloat,
        ottoVoice: CGPoint,
        mossEar: CGPoint,
        step: Int,
        p: LivingPhaseSample,
        flat: Bool,
        dark: Bool
    ) {
        let s = min(w, h)

        // Minimalist rounded beechwood peg-peer seated calmly on right mat (0 blush, 0 mouth dots)
        let pegH = s * 0.22
        let pegW = s * 0.13
        let peerBaseY = groundY + 2
        let peerTilt: Double = step == 2 && p.raw < 0.42 ? -7.0 : 0.0
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: peerX, y: peerBaseY + 1.5), rx: pegW * 0.56, ry: 4.0, dark: dark)

        var pCtx = ctx
        pCtx.translateBy(x: peerX, y: peerBaseY)
        pCtx.rotate(by: .degrees(peerTilt))

        let torsoRect = CGRect(x: -pegW * 0.48, y: -pegH * 0.62, width: pegW * 0.96, height: pegH * 0.62)
        pCtx.fill(
            Path(roundedRect: torsoRect, cornerRadius: pegW * 0.34),
            with: .color(dark ? Color(hex: 0x4F7D85) : Crayon.teal)
        )
        let headR = pegW * 0.40
        let headRect = CGRect(x: -headR, y: -pegH * 0.98, width: headR * 2, height: headR * 2)
        PixarDrawHelpers.drawBeechwood(in: &pCtx, path: Path(ellipseIn: headRect), bounds: headRect, dark: dark, warmth: 0.76, grainLines: 1)
        // Minimal calm eyes facing slightly left toward Moss/shared toy
        let eyeCol = dark ? Color(hex: 0x1D2538) : Color(hex: 0x3A2E24)
        for ex in [-headR * 0.48, -headR * 0.10] {
            pCtx.fill(Path(ellipseIn: CGRect(x: ex - 1.6, y: -pegH * 0.80, width: 3.2, height: 3.2)), with: .color(eyeCol))
        }

        // Parallel personal toys on Step 0 (wooden ring beside Moss, wood block beside Peer)
        if step == 0 {
            ctx.stroke(
                Path(ellipseIn: CGRect(x: w * 0.32 - 8, y: groundY - 11, width: 16, height: 10)),
                with: .color(Crayon.sunflower),
                lineWidth: 3.2
            )
            ctx.fill(
                Path(roundedRect: CGRect(x: w * 0.66 - 7, y: groundY - 13, width: 14, height: 13), cornerRadius: 3),
                with: .color(Crayon.tangerine)
            )
        }

        // Grounded chunky beechwood wheeled car sliding along center turn-taking lane
        let carW = s * 0.115
        let carH = s * 0.056
        let carX: CGFloat = {
            switch step {
            case 0: return w * 0.50
            case 1: return w * (0.38 + CGFloat(0.5 - 0.5 * cos(p.raw * .pi * 2.0)) * 0.24)
            default: return w * 0.50
            }
        }()
        let carRect = CGRect(x: carX - carW * 0.5, y: groundY - carH - 4, width: carW, height: carH)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: carX, y: groundY + 1.5), rx: carW * 0.52, ry: 3.2, dark: dark)
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(roundedRect: carRect, cornerRadius: 7), bounds: carRect, dark: dark, warmth: 0.74, grainLines: 1)
        for wx in [carRect.minX + 8, carRect.maxX - 8] {
            ctx.fill(Path(ellipseIn: CGRect(x: wx - 5, y: groundY - 7, width: 10, height: 10)), with: .color(dark ? Color(hex: 0x3D2E20) : Color(hex: 0x6A4E34)))
        }

        // Step 1–2 mediation cues
        if step == 1 {
            BespokeStageHelpers.drawContactSparkles(in: &ctx, center: CGPoint(x: carX, y: groundY - carH - 12), pulse: p.contact, radius: s * 0.09, color: Palette.amber)
        } else if step == 2 {
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: w * 0.50, y: groundY - s * 0.14),
                baseRadius: s * 0.14,
                progress: p.action,
                tint: Palette.amber,
                dark: dark
            )
            let peerEar = CGPoint(x: peerX - pegW * 0.35, y: groundY - pegH * 0.80)
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoVoice,
                to: mossEar,
                progress: p.followThrough,
                waveOffset: p.raw * .pi * 2.0,
                color: Palette.amber,
                lineWidth: 2.1,
                dark: dark
            )
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoVoice,
                to: peerEar,
                progress: p.followThrough,
                waveOffset: p.raw * .pi * 2.0 + 1.0,
                color: Crayon.teal,
                lineWidth: 2.1,
                dark: dark
            )
        }
    }
}
