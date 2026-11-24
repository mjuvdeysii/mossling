import SwiftUI

/// A06 (One-Page Picture Reading · 5 Steps):
/// Cozy lap reading cushion with tilted foreground illustrated board book showing a sunny pear & ladybug spread:
/// Step 0: Book unfolds smoothly -> Step 1: Attention halo lights the painted ladybug ->
/// Step 2: Dual silk narration waves -> Step 3: Quiet pause halo awaiting Moss's gaze/coo ->
/// Step 4: Gentle unhurried cover closing when interest moves on.
struct SceneA06_OnePageReading: View {
    let ctx: BespokeSceneContext

    var body: some View {
        let step = min(max(0, ctx.stepIndex), 4)
        let p = ctx.phase
        let dark = ctx.dark
        let flat = ctx.flat

        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let h = max(1, geo.size.height)
            let s = min(w, h)

            let ms = s * 0.34
            let os = ms * Kind.otto.scale
            let cushionGround = h * 0.775

            let ottoX = w * 0.25
            let mossX = w * 0.74
            let bookCenter = CGPoint(x: w * 0.50, y: h * 0.76)

            // 0 = closed, 1 = wide open flat spread
            let bookOpenFrac: Double = {
                switch step {
                case 0: return p.action
                case 4: return max(0.06, 1.0 - p.action * 0.94)
                default: return 1.0
                }
            }()

            let bugTarget = CGPoint(x: bookCenter.x + w * 0.055, y: bookCenter.y - h * 0.015)

            let mossHopLift: CGFloat = (step == 3 && p.raw >= 0.48)
                ? CGFloat(max(0.0, sin((p.raw - 0.48) / 0.34 * .pi))) * ms * 0.085
                : 0

            let mossLean: Double = {
                switch step {
                case 0: return -3.0 * p.action
                case 1, 2: return -6.0
                case 3: return -4.0 + p.followThrough * 3.0
                default: return 2.5 * p.action
                }
            }()
            let ottoLean: Double = {
                switch step {
                case 0: return 5.0 * p.action
                case 1, 2: return 7.5
                case 3: return 4.0
                default: return 2.0 * (1.0 - p.action)
                }
            }()

            let mossLook: CGPoint = {
                switch step {
                case 4: return CGPoint(x: -0.25, y: 0.20)
                default: return CGPoint(x: -0.65, y: 0.48)
                }
            }()
            let ottoLook = CGPoint(x: 0.55, y: 0.48)

            let mossMood: Mood = {
                switch step {
                case 1: return .wow
                case 3: return p.raw >= 0.46 ? .happy : .wow
                case 4: return .open
                default: return .open
                }
            }()
            let ottoMood: Mood = step == 2 || (step == 3 && p.isContactWindow) ? .happy : .open

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: cushionGround, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: cushionGround, flat: flat, lift: mossHopLift)
            )

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.40 : 0.25, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawReadingCushionStage(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        cushionGround: cushionGround,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: bugTarget,
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
                    lid: dark ? 0.40 : 0.25,
                    lean: ottoLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.28, y: -0.78),
                    secondaryLagDegrees: -ottoLean * 0.28
                )
                .position(ottoCenter)

                StoryTheaterActorView(
                    kind: .moss,
                    size: ms,
                    mood: mossMood,
                    look: mossLook,
                    lid: dark ? 0.18 : 0,
                    lean: mossLean,
                    hopLift: mossHopLift / max(1, ms),
                    hopping: step == 3 && p.isContactWindow,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.28, y: -0.78),
                    secondaryLagDegrees: -mossLean * 0.42
                )
                .position(mossCenter)

                // Foreground oversized board book spread + interactive highlight/voice choreography
                Canvas(rendersAsynchronously: false) { c, size in
                    drawBoardBookSpread(
                        in: &c,
                        center: bookCenter,
                        w: size.width,
                        h: size.height,
                        openFrac: bookOpenFrac,
                        step: step,
                        p: p,
                        bugTarget: bugTarget,
                        ottoMouth: CGPoint(x: ottoCenter.x + os * 0.18, y: ottoCenter.y),
                        mossEar: CGPoint(x: mossCenter.x - ms * 0.16, y: mossCenter.y),
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: bugTarget,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawReadingCushionStage(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        cushionGround: CGFloat,
        flat: Bool,
        dark: Bool
    ) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xFAF6EB),
            dayBottom: Color(hex: 0xEAE2CE),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        // Quilted wool floor blanket horizon
        let blanketRect = CGRect(x: -8, y: cushionGround - 6, width: w + 16, height: h - cushionGround + 14)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: Path(blanketRect),
                bounds: blanketRect,
                light: dark ? Color(hex: 0x24334C) : Color(hex: 0xEFE6D4),
                rich: dark ? Color(hex: 0x162035) : Color(hex: 0xD6CAB0),
                pencilOutline: (dark ? Color(hex: 0x556D94) : Color(hex: 0x998C72)).opacity(0.45),
                lineWidth: 1.2
            )
        } else {
            ctx.fill(
                Path(blanketRect),
                with: .linearGradient(
                    Gradient(colors: [
                        dark ? Color(hex: 0x22304A) : Color(hex: 0xF3EBD8),
                        dark ? Color(hex: 0x141F32) : Color(hex: 0xDACFB7)
                    ]),
                    startPoint: CGPoint(x: w * 0.5, y: cushionGround - 6),
                    endPoint: CGPoint(x: w * 0.5, y: h)
                )
            )
        }
    }

    private func drawBoardBookSpread(
        in ctx: inout GraphicsContext,
        center: CGPoint,
        w: CGFloat,
        h: CGFloat,
        openFrac: Double,
        step: Int,
        p: LivingPhaseSample,
        bugTarget: CGPoint,
        ottoMouth: CGPoint,
        mossEar: CGPoint,
        flat: Bool,
        dark: Bool
    ) {
        let halfW = min(w, h) * 0.23
        let bookH = min(w, h) * 0.25
        let topY = center.y - bookH * 0.45
        let wingScale = max(0.06, CGFloat(openFrac))

        PixarDrawHelpers.drawContactAO(
            in: &ctx,
            center: CGPoint(x: center.x, y: center.y + bookH * 0.48),
            rx: halfW * (0.45 + 0.55 * wingScale),
            ry: bookH * 0.16,
            dark: dark,
            opacity: 0.88
        )

        let boardBg = dark ? Color(hex: 0x1E2B46) : Color(hex: 0xFBF7EC)
        let boardDeep = dark ? Color(hex: 0x172238) : Color(hex: 0xECE3CE)
        let coverTint = dark ? Color(hex: 0x2B4947) : Crayon.teal.mix(with: .white, by: 0.35)

        // Left board page (scales horizontally from spine)
        let leftRect = CGRect(x: center.x - halfW * wingScale, y: topY, width: halfW * wingScale, height: bookH)
        let rightRect = CGRect(x: center.x, y: topY, width: halfW, height: bookH)

        // Right page (base cover + paper spread)
        let rightPage = Path(roundedRect: rightRect, cornerRadius: 5)
        ctx.fill(rightPage, with: .color(boardBg))
        ctx.stroke(rightPage, with: .color(coverTint), lineWidth: 2.2)

        // Left page (rotates out smoothly)
        let leftPage = Path(roundedRect: leftRect, cornerRadius: 5)
        ctx.fill(leftPage, with: .color(openFrac > 0.22 ? boardBg : coverTint))
        ctx.stroke(leftPage, with: .color(coverTint), lineWidth: 2.2)

        if openFrac > 0.48 {
            // Left illustration: simple golden botanical pear & leaf
            let pearPos = CGPoint(x: center.x - halfW * 0.50 * wingScale, y: center.y + bookH * 0.04)
            let pr = bookH * 0.19
            ctx.fill(
                Path(ellipseIn: CGRect(x: pearPos.x - pr * 0.72 * wingScale, y: pearPos.y - pr * 0.65, width: pr * 1.44 * wingScale, height: pr * 1.4)),
                with: .color(Palette.amber.opacity(0.85))
            )
            ctx.fill(
                Path(ellipseIn: CGRect(x: pearPos.x - pr * 0.18 * wingScale, y: pearPos.y - pr * 1.12, width: pr * 0.55 * wingScale, height: pr * 0.45)),
                with: .color(Palette.moss.opacity(0.88))
            )

            // Right illustration: charming round red ladybug with dark dots
            let br = bookH * 0.15
            let bugRect = CGRect(x: bugTarget.x - br, y: bugTarget.y - br * 0.85, width: br * 2, height: br * 1.7)
            ctx.fill(Path(ellipseIn: bugRect), with: .color(Crayon.pink.mix(with: Color(hex: 0xD95C4B), by: 0.45)))
            ctx.fill(Path(ellipseIn: CGRect(x: bugTarget.x - br * 0.42, y: bugTarget.y - br * 0.25, width: 3.5, height: 3.5)), with: .color(Palette.ink))
            ctx.fill(Path(ellipseIn: CGRect(x: bugTarget.x + br * 0.16, y: bugTarget.y - br * 0.10, width: 3.5, height: 3.5)), with: .color(Palette.ink))
        }

        // Spine shadow crease
        ctx.stroke(
            Path { path in
                path.move(to: CGPoint(x: center.x, y: topY + 2))
                path.addLine(to: CGPoint(x: center.x, y: topY + bookH - 2))
            },
            with: .color(boardDeep.opacity(0.9)),
            lineWidth: 2.0
        )

        // Step-specific cues
        if step == 1 {
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: bugTarget,
                baseRadius: bookH * 0.34,
                progress: p.action,
                tint: Palette.amber,
                dark: dark
            )
        } else if step == 2 {
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoMouth,
                to: mossEar,
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Crayon.teal,
                lineWidth: 2.4,
                dark: dark
            )
        } else if step == 3 {
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: center.x, y: topY - bookH * 0.18),
                baseRadius: bookH * 0.42,
                progress: p.raw,
                tint: Palette.amber,
                dark: dark
            )
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: bugTarget,
                pulse: p.contact,
                radius: bookH * 0.42,
                color: Palette.amber
            )
        }
    }
}
