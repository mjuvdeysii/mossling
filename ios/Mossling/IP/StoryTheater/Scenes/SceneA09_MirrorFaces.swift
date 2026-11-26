import SwiftUI

/// A09 (Mirror Faces Together · 4 Steps):
/// Wall-mounted horizontal chamfered-beech Montessori safety mirror showing synchronized reflections
/// of Otto & Moss inside the silvered frame: Step 0: Side-by-side calm mirror gaze ->
/// Step 1: Smiles answered instantaneously in mirror -> Step 2: Lamp glow highlights reflected face ->
/// Step 3: Warm shared moment with zero self-recognition quizzing.
struct SceneA09_MirrorFaces: View {
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

            let ms = s * 0.34
            let os = ms * Kind.otto.scale
            let groundY = h * 0.875

            let ottoX = w * 0.28
            let mossX = w * 0.70

            let mossHopLift: CGFloat = (step == 1 && p.raw >= 0.44)
                ? CGFloat(max(0.0, sin((p.raw - 0.44) / 0.36 * .pi))) * ms * 0.09
                : 0
            let ottoLean: Double = {
                switch step {
                case 0: return 3.0
                case 1: return 6.0 * p.action
                case 2: return 4.5
                default: return 3.0
                }
            }()
            let mossLean: Double = {
                switch step {
                case 0: return -2.0
                case 1: return -6.5 * p.action
                case 2: return -3.0
                default: return -2.0
                }
            }()

            let mossMood: Mood = {
                switch step {
                case 0: return .open
                case 1: return p.raw >= 0.42 ? .happy : .wow
                case 2: return .happy
                default: return .happy
                }
            }()
            let ottoMood: Mood = step >= 1 ? .happy : .open

            // Actors gaze slightly up toward the wall mirror reflection
            let mossLook = CGPoint(x: -0.22, y: -0.58)
            let ottoLook = CGPoint(x: 0.22, y: -0.56)

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
            let mirrorFrame = CGRect(x: w * 0.16, y: h * 0.10, width: w * 0.68, height: h * 0.40)
            let mirrorMossFace = CGPoint(x: mirrorFrame.minX + mirrorFrame.width * 0.68, y: mirrorFrame.midY + mirrorFrame.height * 0.04)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawMirrorRoomAndReflections(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        mirrorFrame: mirrorFrame,
                        groundY: groundY,
                        step: step,
                        p: p,
                        mossMood: mossMood,
                        ottoMood: ottoMood,
                        mossHop: mossHopLift / max(1, ms),
                        mirrorMossFace: mirrorMossFace,
                        ottoMouth: CGPoint(x: ottoCenter.x + os * 0.18, y: ottoCenter.y - os * 0.10),
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: mirrorMossFace,
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
                    lightDirection: CGPoint(x: 0.5, y: -0.78),
                    secondaryLagDegrees: -ottoLean * 0.28
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
                    hopping: step == 1 && p.isContactWindow,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.5, y: -0.78),
                    secondaryLagDegrees: -mossLean * 0.42
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: mirrorMossFace,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawMirrorRoomAndReflections(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        mirrorFrame: CGRect,
        groundY: CGFloat,
        step: Int,
        p: LivingPhaseSample,
        mossMood: Mood,
        ottoMood: Mood,
        mossHop: CGFloat,
        mirrorMossFace: CGPoint,
        ottoMouth: CGPoint,
        flat: Bool,
        dark: Bool
    ) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xFAF7EE),
            dayBottom: Color(hex: 0xECE5D2),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        // Floor playmat strip
        let floorRect = CGRect(x: -6, y: h * 0.74, width: w + 12, height: h * 0.28)
        ctx.fill(
            Path(floorRect),
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x203048) : Color(hex: 0xF3EBDA),
                    dark ? Color(hex: 0x141F32) : Color(hex: 0xD9CEB8)
                ]),
                startPoint: CGPoint(x: w * 0.5, y: h * 0.74),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Outer beechwood Montessori mirror bezel
        let bezelRect = mirrorFrame.insetBy(dx: -8, dy: -8)
        let bezelPath = Path(roundedRect: bezelRect, cornerRadius: 14)
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: bezelPath, bounds: bezelRect, dark: dark, warmth: 0.75, grainLines: 3)

        // Silvered inner safety mirror glass
        let glassPath = Path(roundedRect: mirrorFrame, cornerRadius: 8)
        ctx.fill(
            glassPath,
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x213252) : Color(hex: 0xEEF5F7),
                    dark ? Color(hex: 0x16223A) : Color(hex: 0xD5E4EA)
                ]),
                startPoint: CGPoint(x: mirrorFrame.minX, y: mirrorFrame.minY),
                endPoint: CGPoint(x: mirrorFrame.maxX, y: mirrorFrame.maxY)
            )
        )

        // Clipped mirrored reflections of Otto & Moss inside mirror glass
        var glassCtx = ctx
        glassCtx.clip(to: glassPath)

        // Reflected Otto dome & smiling eye
        let rOttoX = mirrorFrame.minX + mirrorFrame.width * 0.30
        let rOttoY = mirrorFrame.maxY - mirrorFrame.height * 0.14
        let roR = mirrorFrame.height * 0.28
        let rOttoBody = CGRect(x: rOttoX - roR, y: rOttoY - roR * 1.15, width: roR * 2, height: roR * 2.1)
        glassCtx.fill(Path(ellipseIn: rOttoBody), with: .color(Palette.rod.opacity(dark ? 0.70 : 0.58)))
        glassCtx.fill(
            Path(ellipseIn: CGRect(x: rOttoX - roR * 0.28, y: rOttoY - roR * 0.55, width: roR * 0.56, height: roR * 0.50)),
            with: .color(Color(hex: 0xFCF8EE).opacity(0.85))
        )
        if ottoMood == .happy {
            var sm = Path()
            sm.move(to: CGPoint(x: rOttoX - 4, y: rOttoY - roR * 0.08))
            sm.addQuadCurve(to: CGPoint(x: rOttoX + 4, y: rOttoY - roR * 0.08), control: CGPoint(x: rOttoX, y: rOttoY - roR * 0.02))
            glassCtx.stroke(sm, with: .color(Color(hex: 0x1E2638).opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }

        // Reflected Moss pebble & twin mirror eyes + sprout leaves
        let rMossX = mirrorMossFace.x
        let rMossY = mirrorFrame.maxY - mirrorFrame.height * 0.12 - mossHop * mirrorFrame.height * 0.22
        let rmR = mirrorFrame.height * 0.26
        glassCtx.fill(
            Path(ellipseIn: CGRect(x: rMossX - rmR * 1.05, y: rMossY - rmR * 0.9, width: rmR * 2.1, height: rmR * 1.75)),
            with: .color(Palette.moss.opacity(dark ? 0.72 : 0.62))
        )
        // Reflected tiny sprout leaf pair
        glassCtx.fill(
            Path(ellipseIn: CGRect(x: rMossX - rmR * 0.50, y: rMossY - rmR * 1.32, width: rmR * 0.52, height: rmR * 0.28)),
            with: .color(Palette.mint.opacity(0.70))
        )
        glassCtx.fill(
            Path(ellipseIn: CGRect(x: rMossX + rmR * 0.04, y: rMossY - rmR * 1.32, width: rmR * 0.52, height: rmR * 0.28)),
            with: .color(Palette.mintLight.opacity(0.70))
        )
        // Mirror eyes
        let eyeCol = Color(hex: 0x222A38).opacity(0.78)
        if mossMood == .happy {
            for ex in [rMossX - rmR * 0.30, rMossX + rmR * 0.30] {
                var arc = Path()
                arc.move(to: CGPoint(x: ex - 4, y: rMossY - rmR * 0.18))
                arc.addQuadCurve(to: CGPoint(x: ex + 4, y: rMossY - rmR * 0.18), control: CGPoint(x: ex, y: rMossY - rmR * 0.30))
                glassCtx.stroke(arc, with: .color(eyeCol), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
        } else {
            glassCtx.fill(Path(ellipseIn: CGRect(x: rMossX - rmR * 0.36, y: rMossY - rmR * 0.28, width: 5, height: 6)), with: .color(eyeCol))
            glassCtx.fill(Path(ellipseIn: CGRect(x: rMossX + rmR * 0.16, y: rMossY - rmR * 0.28, width: 5, height: 6)), with: .color(eyeCol))
        }

        // Heirloom brass inner mirror beading + diagonal reflection highlight streaks + skylight bokeh
        let innerTrim = mirrorFrame.insetBy(dx: 4, dy: 4)
        glassCtx.stroke(
            Path(roundedRect: innerTrim, cornerRadius: 5),
            with: .color((dark ? Palette.amber : Color(hex: 0xD2A966)).opacity(dark ? 0.26 : 0.34)),
            lineWidth: 1.0
        )

        var streak = Path()
        streak.move(to: CGPoint(x: mirrorFrame.minX + mirrorFrame.width * 0.11, y: mirrorFrame.maxY))
        streak.addLine(to: CGPoint(x: mirrorFrame.minX + mirrorFrame.width * 0.29, y: mirrorFrame.minY))
        streak.addLine(to: CGPoint(x: mirrorFrame.minX + mirrorFrame.width * 0.37, y: mirrorFrame.minY))
        streak.addLine(to: CGPoint(x: mirrorFrame.minX + mirrorFrame.width * 0.19, y: mirrorFrame.maxY))
        streak.closeSubpath()
        glassCtx.fill(streak, with: .color(Color.white.opacity(dark ? 0.08 : 0.28)))

        var narrowStreak = Path()
        narrowStreak.move(to: CGPoint(x: mirrorFrame.minX + mirrorFrame.width * 0.42, y: mirrorFrame.maxY))
        narrowStreak.addLine(to: CGPoint(x: mirrorFrame.minX + mirrorFrame.width * 0.56, y: mirrorFrame.minY))
        narrowStreak.addLine(to: CGPoint(x: mirrorFrame.minX + mirrorFrame.width * 0.59, y: mirrorFrame.minY))
        narrowStreak.addLine(to: CGPoint(x: mirrorFrame.minX + mirrorFrame.width * 0.45, y: mirrorFrame.maxY))
        narrowStreak.closeSubpath()
        glassCtx.fill(narrowStreak, with: .color(Color.white.opacity(dark ? 0.05 : 0.16)))

        let bokehCenter = CGPoint(x: mirrorFrame.maxX - mirrorFrame.width * 0.15, y: mirrorFrame.minY + mirrorFrame.height * 0.24)
        glassCtx.fill(
            Path(ellipseIn: CGRect(x: bokehCenter.x - 10, y: bokehCenter.y - 10, width: 20, height: 20)),
            with: .radialGradient(
                Gradient(colors: [(dark ? Palette.amber : Color.white).opacity(dark ? 0.16 : 0.26), .clear]),
                center: bokehCenter,
                startRadius: 1,
                endRadius: 11
            )
        )

        // Step highlights
        if step == 1 {
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: CGPoint(x: mirrorFrame.midX, y: mirrorFrame.midY - mirrorFrame.height * 0.12),
                pulse: p.contact,
                radius: min(w, h) * 0.11,
                color: Palette.amber
            )
        } else if step == 2 {
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: mirrorMossFace,
                baseRadius: min(w, h) * 0.10,
                progress: p.action,
                tint: Palette.amber,
                dark: dark
            )
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoMouth,
                to: mirrorMossFace,
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Crayon.teal,
                lineWidth: 2.2,
                dark: dark
            )
        } else if step == 3 {
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: mirrorFrame.midX, y: mirrorFrame.midY),
                baseRadius: min(w, h) * 0.13,
                progress: p.raw,
                tint: Crayon.sky,
                dark: dark
            )
        }
    }
}
