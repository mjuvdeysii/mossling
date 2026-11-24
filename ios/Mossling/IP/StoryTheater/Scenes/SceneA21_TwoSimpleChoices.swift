import SwiftUI

/// A21 (Two Simple Choices · 3 Steps):
/// Balanced dual birch presentation trays side-by-side holding two calm choices:
/// Left tray holds a teal wooden ring; Right tray holds a honey-ochre knitted ball:
/// Step 0: Both trays present calmly side-by-side in balanced warm light ->
/// Step 1: Soft alternating golden halos highlight Left then Right paired with a gentle question ribbon ->
/// Step 2: Moss leans happily toward the chosen left tray as the wooden ring lifts subtly with golden sparkles.
struct SceneA21_TwoSimpleChoices: View {
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
            let groundY = h * 0.86

            let ottoX = w * 0.22
            let mossX = w * 0.78
            let leftTrayPos = CGPoint(x: w * 0.42, y: groundY - s * 0.03)
            let rightTrayPos = CGPoint(x: w * 0.60, y: groundY - s * 0.03)

            let scanX: Double = {
                switch step {
                case 0: return -0.75
                case 1: return p.raw < 0.5 ? -0.90 : -0.52
                default: return -0.88
                }
            }()

            let mossHopLift: CGFloat = (step == 2 && p.raw >= 0.48)
                ? CGFloat(max(0.0, sin((p.raw - 0.48) / 0.34 * .pi))) * ms * 0.09
                : 0
            let ottoLean: Double = step == 0 ? 6.0 * p.action : (step == 1 ? 4.5 : 3.5)
            let mossLean: Double = step == 2 ? -9.5 * p.action : -3.5

            let ottoLook = CGPoint(x: 0.74, y: 0.26)
            let mossLook = CGPoint(x: scanX, y: 0.28)
            let ottoMood: Mood = step == 2 ? .happy : .open
            let mossMood: Mood = step == 2 ? (p.raw >= 0.42 ? .happy : .wow) : (step == 1 ? .wow : .open)

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
            let lampTarget = step == 2 ? leftTrayPos : CGPoint(x: (leftTrayPos.x + rightTrayPos.x) * 0.5, y: groundY - s * 0.04)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawDualChoiceTrays(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        leftTray: leftTrayPos,
                        rightTray: rightTrayPos,
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
                    targetPoint: lampTarget,
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
                    lightDirection: CGPoint(x: 0.50, y: -0.68),
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
                    hopping: step == 2 && mossHopLift > ms * 0.03,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.50, y: -0.68),
                    secondaryLagDegrees: -mossLean * 0.42
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: lampTarget,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawDualChoiceTrays(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        leftTray: CGPoint,
        rightTray: CGPoint,
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
            dayBottom: Color(hex: 0xEDE4CF),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        let s = min(w, h)
        let floorRect = CGRect(x: -6, y: h * 0.74, width: w + 12, height: h * 0.28)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: Path(floorRect),
                bounds: floorRect,
                light: dark ? Color(hex: 0x1E2A44) : Color(hex: 0xEFE5D0),
                rich: dark ? Color(hex: 0x131B2E) : Color(hex: 0xD8CCB4),
                pencilOutline: (dark ? Color(hex: 0x526A90) : Color(hex: 0x9C8F77)).opacity(0.38),
                lineWidth: 1.1
            )
        } else {
            ctx.fill(
                Path(floorRect),
                with: .linearGradient(
                    Gradient(colors: [dark ? Color(hex: 0x1E2A44) : Color(hex: 0xEFE5D0), dark ? Color(hex: 0x131B2E) : Color(hex: 0xD8CCB4)]),
                    startPoint: CGPoint(x: w * 0.5, y: h * 0.74),
                    endPoint: CGPoint(x: w * 0.5, y: h)
                )
            )
        }

        let trayW = s * 0.16
        let trayH = s * 0.045
        let slideIn = step == 0 ? CGFloat(1.0 - p.action) * s * 0.06 : 0

        // Left & Right carved birch trays
        for (pos, accent) in [(leftTray, Crayon.teal), (rightTray, Palette.bead)] {
            let pAdjusted = CGPoint(x: pos.x, y: pos.y + slideIn * 0.3)
            let rect = CGRect(x: pAdjusted.x - trayW * 0.5, y: pAdjusted.y, width: trayW, height: trayH)
            let trayPath = Path(roundedRect: rect, cornerRadius: 5)
            if flat {
                GhibliDrawHelpers.fillWatercolor(
                    in: &ctx,
                    path: trayPath,
                    bounds: rect,
                    light: dark ? Color(hex: 0x9B6E3E) : Color(hex: 0xF0CA92),
                    rich: dark ? Color(hex: 0x6E4B27) : Color(hex: 0xCE975A),
                    pencilOutline: (dark ? Color(hex: 0xD8AE76) : Color(hex: 0x6F4B24)).opacity(0.55),
                    lineWidth: 1.0
                )
            } else {
                PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: pAdjusted.x, y: groundY + 2), rx: trayW * 0.52, ry: 4.5, dark: dark)
                PixarDrawHelpers.drawBeechwood(in: &ctx, path: trayPath, bounds: rect, dark: dark, warmth: 0.7, grainLines: 2)
            }
            // Soft felt tray liner
            let liner = CGRect(x: rect.minX + 4, y: rect.minY + 1, width: rect.width - 8, height: 3)
            ctx.fill(Path(roundedRect: liner, cornerRadius: 1.5), with: .color(accent.opacity(0.45)))
        }

        // Left choice: Teal wooden ring (lifts subtly when selected in Step 2)
        let ringLift = step == 2 ? CGFloat(p.action) * s * 0.045 : 0
        let ringC = CGPoint(x: leftTray.x, y: leftTray.y - s * 0.036 - ringLift + slideIn * 0.3)
        let ringR = s * 0.042
        let outerR = CGRect(x: ringC.x - ringR, y: ringC.y - ringR, width: ringR * 2, height: ringR * 2)
        let innerR = outerR.insetBy(dx: ringR * 0.44, dy: ringR * 0.44)
        var ringPath = Path(ellipseIn: outerR)
        ringPath.addEllipse(in: innerR)
        ctx.fill(ringPath, with: .color(Crayon.teal), style: FillStyle(eoFill: true))
        if flat {
            ctx.stroke(Path(ellipseIn: outerR), with: .color(Color(hex: 0x164D4A).opacity(0.65)), lineWidth: 1.0)
        }

        // Right choice: Honey-ochre knitted ball
        let ballC = CGPoint(x: rightTray.x, y: rightTray.y - s * 0.034 + slideIn * 0.3)
        let ballR = s * 0.040
        let ballRect = CGRect(x: ballC.x - ballR, y: ballC.y - ballR, width: ballR * 2, height: ballR * 2)
        ctx.fill(
            Path(ellipseIn: ballRect),
            with: .radialGradient(
                Gradient(colors: [Palette.beadLight, Palette.bead, Color(hex: 0xA87414)]),
                center: CGPoint(x: ballC.x - ballR * 0.25, y: ballC.y - ballR * 0.25),
                startRadius: 1,
                endRadius: ballR * 1.35
            )
        )
        if flat {
            ctx.stroke(Path(ellipseIn: ballRect), with: .color(Color(hex: 0x7A540D).opacity(0.65)), lineWidth: 1.0)
        }

        // Alternating choice highlight rings in Step 1 + short question ribbon
        if step == 1 {
            let leftActive = p.raw < 0.5
            let activePt = leftActive ? ringC : ballC
            let activeTint = leftActive ? Crayon.teal : Palette.bead
            let ringR2 = s * 0.072
            ctx.stroke(
                Path(ellipseIn: CGRect(x: activePt.x - ringR2, y: activePt.y - ringR2, width: ringR2 * 2, height: ringR2 * 2)),
                with: .color(activeTint.opacity(0.75)),
                style: StrokeStyle(lineWidth: 2.0, dash: [3, 3])
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
        } else if step == 2 {
            // Choice made -> golden bloom around chosen left option
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: ringC,
                baseRadius: s * 0.085,
                progress: p.action,
                tint: Crayon.teal,
                dark: dark
            )
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: ringC,
                pulse: p.contact,
                radius: s * 0.095,
                color: Palette.amber
            )
        }
    }
}
