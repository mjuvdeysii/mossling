import SwiftUI

/// Showcase 1 (N01): Intimate closeup feeding & cuddling alcove with curved oat-linen bolster,
/// sculpted beech molding, hanging wooden star mobile, flowing dual silk voice ribbons, and pause ring.
struct SceneN01_VoiceTurns: View {
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

            // 1:1 shared spatial coordinates across Pixar 3D & Ghibli 2D
            let ms = s * 0.44
            let os = ms * Kind.otto.scale
            let ottoGround = h * 0.885
            let mossGround = h * 0.855

            let ottoX: CGFloat = w * (step == 1 ? 0.305 : 0.285)
            let mossX: CGFloat = w * 0.695

            let speakBounce: CGFloat = step == 0 ? CGFloat(sin(p.action * .pi * 2.0) * 3.0) : 0
            let mossAnswerLift: CGFloat = step == 2
                ? CGFloat(max(0.0, sin((p.raw - 0.44) / 0.42 * .pi))) * ms * 0.085
                : 0
            let ottoLift: CGFloat = speakBounce * 0.35

            let ottoLean: Double = {
                switch step {
                case 0: return 4.0 + p.action * 4.5 - p.hold * 2.0
                case 1: return 8.5 + sin(p.raw * .pi) * 2.5
                default: return 6.0 - p.followThrough * 2.5
                }
            }()
            let mossLean: Double = {
                switch step {
                case 0: return -3.0 * p.contact
                case 1: return -2.0 + sin(p.action * .pi) * 3.5
                default: return -6.0 * sin(max(0.0, min(1.0, (p.raw - 0.42) / 0.58)) * .pi)
                }
            }()

            let ottoMood: Mood = {
                switch step {
                case 0: return .happy
                case 1: return .open
                default: return p.raw >= 0.48 ? .happy : .open
                }
            }()
            let mossMood: Mood = {
                switch step {
                case 0: return .open
                case 1: return p.action > 0.35 ? .happy : .wow
                default: return p.raw >= 0.44 ? .happy : .wow
                }
            }()

            let mossSquash: CGSize = {
                if step == 2 && p.raw >= 0.42 {
                    let t = min(1.0, (p.raw - 0.42) / 0.18)
                    let sq = sin(t * .pi) * 0.06
                    return CGSize(width: 1.0 + sq * 0.5, height: 1.0 - sq)
                }
                return CGSize(width: 1, height: 1)
            }()

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: ottoGround, flat: flat, lift: ottoLift)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: mossGround, flat: flat, lift: mossAnswerLift)
            )
            let ottoState = Creature.state(
                .otto,
                face: ottoMood,
                look: CGPoint(x: 0.72, y: 0.06),
                lid: step == 1 ? (dark ? 0.50 : 0.36) : (dark ? 0.42 : 0.26),
                hopping: false,
                yawning: false
            )
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )
            let targetWorld = CGPoint(x: mossCenter.x - ms * 0.06, y: mossCenter.y + ms * 0.05)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawBackdrop(in: &c, w: size.width, h: size.height, step: step, p: p, flat: flat)
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: targetWorld,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .floorPool
                )

                // Voice ribbons & stillness pause ring behind actors so lines frame cleanly
                Canvas(rendersAsynchronously: false) { c, size in
                    drawVoiceChoreography(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        ottoPos: CGPoint(x: ottoCenter.x + os * 0.22, y: ottoCenter.y - os * 0.06),
                        mossPos: CGPoint(x: mossCenter.x - ms * 0.22, y: mossCenter.y - ms * 0.04),
                        step: step,
                        p: p
                    )
                }

                StoryTheaterActorView(
                    kind: .otto,
                    size: os,
                    mood: ottoMood,
                    look: CGPoint(x: 0.72, y: 0.06),
                    lid: step == 1 ? (dark ? 0.50 : 0.36) : (dark ? 0.42 : 0.28),
                    lean: ottoLean,
                    hopLift: ottoLift / max(1, os),
                    hopping: false,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.78, y: -0.62),
                    secondaryLagDegrees: -ottoLean * 0.32
                )
                .position(ottoCenter)

                StoryTheaterActorView(
                    kind: .moss,
                    size: ms,
                    mood: mossMood,
                    look: CGPoint(x: -0.72, y: step == 1 ? -0.14 : -0.04),
                    lid: dark ? 0.24 : 0,
                    lean: mossLean,
                    hopLift: mossAnswerLift / max(1, ms),
                    hopping: step == 2 && p.isContactWindow,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.78, y: -0.62),
                    secondaryLagDegrees: step == 2 ? sin(p.followThrough * .pi) * 11.0 : -mossLean * 0.35,
                    postureScale: mossSquash
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

                // Soft-bokeh foreground warmth (3D Pixar cinema feel) & cozy linen edge
                if !ctx.compact {
                    Canvas(rendersAsynchronously: false) { c, size in
                        drawForegroundLayer(in: &c, w: size.width, h: size.height, p: p, flat: flat)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
    }

    private func drawBackdrop(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, step: Int, p: LivingPhaseSample, flat: Bool) {
        let dark = ctxDark

        // 1. Warm nursery alcove atmosphere
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xFDF9EE),
            dayBottom: Color(hex: 0xF1E5CF),
            nightTop: Color(hex: 0x0C1324),
            nightBottom: Color(hex: 0x16223D),
            dark: dark
        )

        // 2. Sculpted curved beechwood alcove wall molding (top-right sunlit / moonlit corner)
        let panTopY = h * 0.08
        var molding = Path()
        molding.move(to: CGPoint(x: 0, y: panTopY))
        molding.addQuadCurve(
            to: CGPoint(x: w, y: panTopY + h * 0.04),
            control: CGPoint(x: w * 0.52, y: panTopY - h * 0.03)
        )
        molding.addLine(to: CGPoint(x: w, y: panTopY + h * 0.09))
        molding.addQuadCurve(
            to: CGPoint(x: 0, y: panTopY + h * 0.05),
            control: CGPoint(x: w * 0.52, y: panTopY + h * 0.02)
        )
        molding.closeSubpath()

        let moldingBounds = CGRect(x: 0, y: panTopY - h * 0.03, width: w, height: h * 0.14)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: molding,
                bounds: moldingBounds,
                light: dark ? Color(hex: 0x3A476A) : Color(hex: 0xEDD2A4),
                rich: dark ? Color(hex: 0x293452) : Color(hex: 0xD3AC74),
                pencilOutline: dark ? Color(hex: 0x566898).opacity(0.45) : Color(hex: 0x9C7544).opacity(0.48),
                lineWidth: 1.0
            )
        } else {
            PixarDrawHelpers.drawBeechwood(in: &ctx, path: molding, bounds: moldingBounds, dark: dark, warmth: 0.72, grainLines: 2)
        }

        // 3. Soft diagonal sunlight / lantern wash sweeping from top-right molding toward Moss
        if !dark {
            var sunBeam = Path()
            sunBeam.move(to: CGPoint(x: w * 0.72, y: 0))
            sunBeam.addLine(to: CGPoint(x: w, y: 0))
            sunBeam.addLine(to: CGPoint(x: w * 0.90, y: h * 0.86))
            sunBeam.addLine(to: CGPoint(x: w * 0.42, y: h * 0.86))
            sunBeam.closeSubpath()
            ctx.fill(
                sunBeam,
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xFFF7D6).opacity(0.42), Color(hex: 0xFFF7D6).opacity(0.0)]),
                    startPoint: CGPoint(x: w * 0.86, y: 0),
                    endPoint: CGPoint(x: w * 0.54, y: h * 0.82)
                )
            )
        }

        // 4. Hanging sculpted wooden star mobile anchored to the alcove arch
        let starPivot = CGPoint(x: w * 0.50, y: panTopY + h * 0.04)
        let sway = sin(p.raw * .pi * 2.0 + Double(step) * 1.1) * 4.5
        let starCenter = CGPoint(x: starPivot.x + CGFloat(sway), y: panTopY + h * 0.21)
        var cord = Path()
        cord.move(to: starPivot)
        cord.addQuadCurve(to: starCenter, control: CGPoint(x: starPivot.x + CGFloat(sway) * 0.4, y: (starPivot.y + starCenter.y) * 0.5))
        ctx.stroke(cord, with: .color((dark ? Color(hex: 0x8BA0CF) : Color(hex: 0x9B7D56)).opacity(0.65)), lineWidth: 1.1)

        var starPath = Path()
        let rOuter = min(w, h) * 0.042
        let rInner = rOuter * 0.48
        for i in 0..<10 {
            let ang = Double(i) * .pi / 5.0 - .pi / 2.0 + sway * 0.03
            let rad = (i % 2 == 0) ? rOuter : rInner
            let pt = CGPoint(x: starCenter.x + cos(ang) * rad, y: starCenter.y + sin(ang) * rad)
            if i == 0 { starPath.move(to: pt) } else { starPath.addLine(to: pt) }
        }
        starPath.closeSubpath()
        let starRect = CGRect(x: starCenter.x - rOuter, y: starCenter.y - rOuter, width: rOuter * 2, height: rOuter * 2)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: starPath,
                bounds: starRect,
                light: dark ? Color(hex: 0xF3BE68) : Color(hex: 0xF6D17E),
                rich: dark ? Color(hex: 0xC68834) : Color(hex: 0xDB9E44),
                pencilOutline: (dark ? Color(hex: 0xFFE3A8) : Color(hex: 0x8E652B)).opacity(0.55),
                lineWidth: 1.0
            )
        } else {
            PixarDrawHelpers.drawBeechwood(in: &ctx, path: starPath, bounds: starRect, dark: dark, warmth: 0.9, grainLines: 1)
        }

        // 5. Curved oat-linen bolster & soft nursing nest sweeping across the foreground
        let horizonY = h * 0.615
        var bolster = Path()
        bolster.move(to: CGPoint(x: -10, y: horizonY + h * 0.05))
        bolster.addCurve(
            to: CGPoint(x: w + 10, y: horizonY),
            control1: CGPoint(x: w * 0.30, y: horizonY + h * 0.14),
            control2: CGPoint(x: w * 0.72, y: horizonY - h * 0.10)
        )
        bolster.addLine(to: CGPoint(x: w + 10, y: h + 10))
        bolster.addLine(to: CGPoint(x: -10, y: h + 10))
        bolster.closeSubpath()

        let bolsterBounds = CGRect(x: 0, y: horizonY - h * 0.08, width: w, height: h - horizonY + h * 0.10)
        let bolsterTop = dark ? Color(hex: 0x253253) : Color(hex: 0xFBF6EB)
        let bolsterBot = dark ? Color(hex: 0x162039) : Color(hex: 0xE7DBC4)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: bolster,
                bounds: bolsterBounds,
                light: bolsterTop,
                rich: bolsterBot,
                pencilOutline: (dark ? Color(hex: 0x5B70A2) : Color(hex: 0xAE9A7E)).opacity(0.45),
                lineWidth: 1.2
            )
        } else {
            ctx.fill(
                bolster,
                with: .linearGradient(
                    Gradient(colors: [bolsterTop, bolsterBot]),
                    startPoint: CGPoint(x: w * 0.5, y: horizonY - h * 0.04),
                    endPoint: CGPoint(x: w * 0.5, y: h)
                )
            )
            var rim = Path()
            rim.move(to: CGPoint(x: 0, y: horizonY + h * 0.048))
            rim.addCurve(
                to: CGPoint(x: w, y: horizonY),
                control1: CGPoint(x: w * 0.30, y: horizonY + h * 0.135),
                control2: CGPoint(x: w * 0.72, y: horizonY - h * 0.095)
            )
            ctx.stroke(rim, with: .color((dark ? Color(hex: 0x7A93CE) : Color.white).opacity(dark ? 0.24 : 0.70)), lineWidth: 2.0)
        }

        // Woven terracotta blanket piping seam & cozy sage nest ring under Moss
        var seam = Path()
        seam.move(to: CGPoint(x: w * 0.04, y: h * 0.78))
        seam.addQuadCurve(to: CGPoint(x: w * 0.96, y: h * 0.76), control: CGPoint(x: w * 0.48, y: h * 0.85))
        ctx.stroke(
            seam,
            with: .color((dark ? Color(hex: 0xE29E6E) : Color(hex: 0xC97D52)).opacity(dark ? 0.34 : 0.44)),
            style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [5, 5])
        )

        let nestRect = CGRect(x: w * 0.51, y: h * 0.785, width: w * 0.36, height: h * 0.125)
        ctx.fill(
            Path(ellipseIn: nestRect),
            with: .linearGradient(
                Gradient(colors: [
                    (dark ? Color(hex: 0x2F4C46) : Color(hex: 0xDCE8D9)),
                    (dark ? Color(hex: 0x1D3233) : Color(hex: 0xC1D4BE))
                ]),
                startPoint: CGPoint(x: nestRect.midX, y: nestRect.minY),
                endPoint: CGPoint(x: nestRect.midX, y: nestRect.maxY)
            )
        )
    }

    private func drawVoiceChoreography(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        ottoPos: CGPoint,
        mossPos: CGPoint,
        step: Int,
        p: LivingPhaseSample
    ) {
        let dark = ctxDark
        let mid = CGPoint(x: (ottoPos.x + mossPos.x) * 0.5, y: min(ottoPos.y, mossPos.y) - h * 0.04)

        switch step {
        case 0:
            // Flowing amber parent voice ribbons
            let travel = min(1.0, p.action * 1.12)
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: CGPoint(x: ottoPos.x, y: ottoPos.y - 6),
                to: CGPoint(x: mossPos.x, y: mossPos.y - 8),
                progress: travel,
                waveOffset: p.raw * .pi * 2.0,
                color: Palette.amber,
                lineWidth: 2.8,
                dark: dark
            )
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: CGPoint(x: ottoPos.x + 6, y: ottoPos.y + 8),
                to: CGPoint(x: mossPos.x - 4, y: mossPos.y + 6),
                progress: max(0.0, travel - 0.14),
                waveOffset: p.raw * .pi * 2.0 + 1.4,
                color: Color(hex: dark ? 0xF5D48E : 0xD89E54),
                lineWidth: 1.8,
                dark: dark
            )
        case 1:
            // Quiet observation: baby's gentle sage-mint coo sound-buds around crest
            let cooR = min(w, h) * 0.14
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: mossPos.x + w * 0.04, y: mossPos.y - h * 0.07),
                baseRadius: cooR,
                progress: p.action * 0.9 + p.contact * 0.1,
                tint: dark ? Color(hex: 0x8ED8A6) : Color(hex: 0x6AA87B),
                dark: dark
            )
        default:
            // First pause in quiet space, then child reply silk ribbon braiding back to Otto
            if p.raw < 0.54 {
                let pauseT = min(1.0, p.raw / 0.44)
                BespokeStageHelpers.drawPauseHalo(
                    in: &ctx,
                    center: mid,
                    baseRadius: min(w, h) * 0.12,
                    progress: pauseT,
                    tint: Palette.amber,
                    dark: dark
                )
            }
            if p.raw >= 0.40 {
                let replyT = min(1.0, (p.raw - 0.40) / 0.45)
                BespokeStageHelpers.drawSilkVoiceRibbon(
                    in: &ctx,
                    from: CGPoint(x: mossPos.x, y: mossPos.y - 6),
                    to: CGPoint(x: ottoPos.x, y: ottoPos.y - 6),
                    progress: replyT,
                    waveOffset: -p.raw * .pi * 2.2,
                    color: dark ? Color(hex: 0x90DBA6) : Color(hex: 0x6EA77A),
                    lineWidth: 3.0,
                    dark: dark
                )
                BespokeStageHelpers.drawContactSparkles(
                    in: &ctx,
                    center: mid,
                    pulse: p.contact,
                    radius: min(w, h) * 0.09,
                    color: Palette.amber
                )
            }
        }
    }

    private func drawForegroundLayer(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, p: LivingPhaseSample, flat: Bool) {
        let dark = ctxDark
        let drift = CGFloat(sin(p.raw * .pi * 2.0) * 6.0)
        if !flat {
            PixarDrawHelpers.drawForegroundBokeh(
                in: &ctx,
                points: [
                    (CGPoint(x: w * 0.08 + drift, y: h * 0.89), min(w, h) * 0.075, dark ? Palette.amber : Color.white),
                    (CGPoint(x: w * 0.92 - drift * 0.7, y: h * 0.16), min(w, h) * 0.062, dark ? Color(hex: 0x7FA8EE) : Color(hex: 0xFFE9AF)),
                    (CGPoint(x: w * 0.87 + drift * 0.5, y: h * 0.93), min(w, h) * 0.050, dark ? Palette.amber : Color(hex: 0xFFF4D4))
                ],
                dark: dark
            )
        }
    }

    private var ctxDark: Bool { ctx.dark }
}
