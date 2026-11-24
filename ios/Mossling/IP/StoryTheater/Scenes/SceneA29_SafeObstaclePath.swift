import SwiftUI

/// A29 (Safe Low Obstacle Path · 4 Steps):
/// Three wide low quilted stepping cushions grounded flush on the playroom rug (`0.46`, `0.61`, `0.75`):
/// Step 0: Adult lays out spaced cushions with a dotted floor route ->
/// Step 1: Otto models hopping/stepping cleanly onto the first cushion ->
/// Step 2: Child freely hops across the path with sparkling cushion landings ->
/// Step 3: Otto steps calmly beside the final cushion casting a steady golden support halo (zero hands on Otto).
struct SceneA29_SafeObstaclePath: View {
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

            let ms = s * 0.33
            let os = ms * Kind.otto.scale
            let groundY = h * 0.865
            let padH = s * 0.055

            let padXs = [w * 0.45, w * 0.60, w * 0.75]

            let ottoX: CGFloat = {
                switch step {
                case 0: return w * 0.19
                case 1: return w * (0.28 + 0.12 * CGFloat(p.action))
                case 2: return w * 0.21
                default: return w * 0.56
                }
            }()
            let ottoHopLift: CGFloat = step == 1
                ? CGFloat(max(0.0, sin(Double(p.action) * .pi))) * s * 0.08
                : 0

            let mossX: CGFloat = {
                switch step {
                case 0: return w * 0.31
                case 1: return w * 0.20
                case 2: return w * (0.34 + 0.38 * CGFloat(p.action))
                default: return padXs[2]
                }
            }()
            let mossHopLift: CGFloat = {
                if step == 2 {
                    return CGFloat(abs(sin(Double(p.action) * .pi * 2.0))) * ms * 0.16
                }
                if step == 3 {
                    return padH * 0.72
                }
                return 0
            }()

            let ottoLean: Double = step == 1 ? 8.5 * p.action : (step == 3 ? 5.0 : 3.0)
            let mossLean: Double = step == 2 ? 9.0 * p.action : (step == 3 ? -3.0 : 3.5)

            let ottoLook = step == 3 ? CGPoint(x: 0.78, y: 0.08) : CGPoint(x: 0.80, y: 0.22)
            let mossLook = step == 3 ? CGPoint(x: -0.78, y: 0.08) : CGPoint(x: 0.78, y: 0.24)
            let ottoMood: Mood = step >= 1 ? .happy : .open
            let mossMood: Mood = step >= 2 ? .happy : (step == 1 ? .wow : .open)

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY, flat: flat, lift: ottoHopLift)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat, lift: mossHopLift)
            )

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.34 : 0.20, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )
            let pathTarget = CGPoint(x: step == 3 ? padXs[2] : padXs[1], y: groundY - padH)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawObstaclePathStage(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        padXs: padXs,
                        padH: padH,
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
                    targetPoint: pathTarget,
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
                    hopping: (step == 2 && mossHopLift > ms * 0.04) || (step == 3 && p.contact > 0.4),
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.74, y: -0.64),
                    secondaryLagDegrees: -mossLean * 0.42
                )
                .position(mossCenter)

                StoryTheaterActorView(
                    kind: .otto,
                    size: os,
                    mood: ottoMood,
                    look: ottoLook,
                    lid: dark ? 0.34 : 0.20,
                    lean: ottoLean,
                    hopLift: ottoHopLift / max(1, os),
                    hopping: step == 1 && ottoHopLift > os * 0.03,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.74, y: -0.64),
                    secondaryLagDegrees: -ottoLean * 0.30
                )
                .position(ottoCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: pathTarget,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawObstaclePathStage(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        padXs: [CGFloat],
        padH: CGFloat,
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
            dayBottom: Color(hex: 0xECE3CF),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        if flat {
            GhibliDrawHelpers.drawKomorebiCanopy(in: &ctx, w: w, h: h, swayOffset: 0, dark: dark)
        }

        let s = min(w, h)
        let floorRect = CGRect(x: -6, y: h * 0.745, width: w + 12, height: h * 0.275)
        ctx.fill(
            Path(floorRect),
            with: .linearGradient(
                Gradient(colors: [dark ? Color(hex: 0x1E2A44) : Color(hex: 0xEFE5D0), dark ? Color(hex: 0x131B2E) : Color(hex: 0xD8CCB4)]),
                startPoint: CGPoint(x: w * 0.5, y: h * 0.745),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Dotted stepping route connecting the 3 low cushions
        var route = Path()
        route.move(to: CGPoint(x: padXs[0], y: groundY - padH * 0.5))
        route.addQuadCurve(to: CGPoint(x: padXs[1], y: groundY - padH * 0.5), control: CGPoint(x: (padXs[0] + padXs[1]) * 0.5, y: groundY - padH * 2.2))
        route.addQuadCurve(to: CGPoint(x: padXs[2], y: groundY - padH * 0.5), control: CGPoint(x: (padXs[1] + padXs[2]) * 0.5, y: groundY - padH * 2.2))
        ctx.stroke(
            route.trimmedPath(from: 0, to: step == 0 ? min(1, max(0, CGFloat(p.action))) : 1.0),
            with: .color(Palette.amber.opacity(dark ? 0.50 : 0.45)),
            style: StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [4, 5])
        )

        // 3 wide grounded low cushions on groundY
        let padColors = [Crayon.teal, Palette.bead, Crayon.tangerine]
        let padW = s * 0.155
        for (idx, px) in padXs.enumerated() {
            let drop: CGFloat = step == 0 ? max(0, CGFloat(1.0 - max(0, p.action * 1.3 - Double(idx) * 0.15))) * 10 : 0
            let rect = CGRect(x: px - padW * 0.5, y: groundY - padH + 2 - drop, width: padW, height: padH)
            PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: px, y: groundY + 2.5), rx: padW * 0.52, ry: 3.8, dark: dark)
            let path = Path(roundedRect: rect, cornerRadius: padH * 0.42)
            let col = padColors[idx]
            if flat {
                GhibliDrawHelpers.fillWatercolor(
                    in: &ctx,
                    path: path,
                    bounds: rect,
                    light: col.mix(with: .white, by: 0.24),
                    rich: col,
                    pencilOutline: col.mix(with: .black, by: 0.35).opacity(0.60),
                    lineWidth: 1.0
                )
            } else {
                ctx.fill(path, with: .color(col))
                ctx.stroke(path, with: .color(Color.white.opacity(0.35)), lineWidth: 1.0)
            }
        }

        switch step {
        case 0, 1:
            BespokeStageHelpers.drawContactSparkles(in: &ctx, center: CGPoint(x: padXs[0], y: groundY - padH - 6), pulse: p.contact, radius: s * 0.09, color: Palette.amber)
        case 2:
            BespokeStageHelpers.drawContactSparkles(in: &ctx, center: CGPoint(x: padXs[1], y: groundY - padH - 8), pulse: p.contact, radius: s * 0.10, color: Palette.amber)
        default:
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: (padXs[2] + w * 0.56) * 0.5, y: groundY - s * 0.12),
                baseRadius: s * 0.14,
                progress: p.action,
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
}
