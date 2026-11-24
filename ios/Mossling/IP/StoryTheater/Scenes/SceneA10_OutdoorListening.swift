import SwiftUI

/// A10 (Listening to the Outdoors · 3 Steps):
/// Sunlit Ghibli/Pixar rolling meadow path & dappled canopy panorama:
/// Step 0: Stepping outdoors into comfortable shade ->
/// Step 1: Drifting breeze ribbons, tumbling translucent leaves & overhead gliding songbird as Moss looks skyward ->
/// Step 2: Golden late-afternoon deepening as both nestle calmly when baby is ready to head in.
struct SceneA10_OutdoorListening: View {
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
            let hillY = h * 0.855

            let ottoX = w * (step == 2 ? 0.31 : 0.27)
            let mossX = w * (step == 2 ? 0.61 : 0.65)

            let ottoLean: Double = step == 1 ? 5.0 : 2.5
            let mossLean: Double = {
                switch step {
                case 0: return -2.0
                case 1: return -7.0 * sin(p.action * .pi * 0.5)
                default: return 3.0 * p.action
                }
            }()

            let mossHopLift: CGFloat = (step == 1 && p.raw >= 0.44)
                ? CGFloat(max(0.0, sin((p.raw - 0.44) / 0.36 * .pi))) * ms * 0.08
                : 0

            let mossLook: CGPoint = {
                switch step {
                case 0: return CGPoint(x: -0.45, y: -0.18)
                case 1: return CGPoint(x: 0.15, y: -0.78)
                default: return CGPoint(x: -0.60, y: 0.06)
                }
            }()
            let ottoLook = step == 1 ? CGPoint(x: 0.45, y: -0.64) : CGPoint(x: 0.72, y: 0.08)

            let mossMood: Mood = {
                switch step {
                case 0: return .open
                case 1: return p.raw >= 0.48 ? .happy : .wow
                default: return .happy
                }
            }()
            let ottoMood: Mood = step == 2 ? .happy : .open

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: hillY, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: hillY, flat: flat, lift: mossHopLift)
            )

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.42 : 0.24, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )
            let birdPoint = CGPoint(
                x: w * (step == 1 ? (0.28 + CGFloat(p.action) * 0.46) : 0.72),
                y: h * (step == 1 ? (0.24 - CGFloat(sin(p.action * .pi) * 0.06)) : 0.22)
            )

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawOutdoorParkScene(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        hillY: hillY,
                        birdPoint: birdPoint,
                        ottoAnchor: CGPoint(x: ottoCenter.x + os * 0.20, y: ottoCenter.y - os * 0.06),
                        mossAnchor: CGPoint(x: mossCenter.x - ms * 0.18, y: mossCenter.y - ms * 0.04),
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: step == 1 ? birdPoint : mossCenter,
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
                    lid: dark ? 0.42 : 0.24,
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
                    lid: dark ? 0.18 : 0,
                    lean: mossLean,
                    hopLift: mossHopLift / max(1, ms),
                    hopping: step == 1 && p.isContactWindow,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.78, y: -0.62),
                    secondaryLagDegrees: sin(p.raw * .pi * 2.0) * 8.0
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: step == 1 ? birdPoint : mossCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawOutdoorParkScene(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        hillY: CGFloat,
        birdPoint: CGPoint,
        ottoAnchor: CGPoint,
        mossAnchor: CGPoint,
        step: Int,
        p: LivingPhaseSample,
        flat: Bool,
        dark: Bool
    ) {
        let dayTop = step == 2 ? Color(hex: 0xF5E7CE) : Color(hex: 0xE7F3EC)
        let dayBot = step == 2 ? Color(hex: 0xEFE1C6) : Color(hex: 0xFAF6E8)
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: dayTop,
            dayBottom: dayBot,
            nightTop: Color(hex: 0x0A1328),
            nightBottom: Color(hex: 0x162441),
            dark: dark
        )

        GhibliDrawHelpers.drawPaintedCloud(
            in: &ctx,
            center: CGPoint(x: w * 0.34 + CGFloat(p.raw * 10), y: h * 0.22),
            width: w * 0.28,
            dark: dark
        )
        GhibliDrawHelpers.drawKomorebiCanopy(
            in: &ctx,
            w: w,
            h: h,
            swayOffset: CGFloat(sin(p.raw * .pi * 2.0) * 5.0),
            dark: dark
        )

        // Rolling distant & foreground green meadow hillsides
        var hill = Path()
        hill.move(to: CGPoint(x: -10, y: h * 0.74))
        hill.addQuadCurve(to: CGPoint(x: w + 10, y: h * 0.72), control: CGPoint(x: w * 0.45, y: h * 0.64))
        hill.addLine(to: CGPoint(x: w + 10, y: h + 10))
        hill.addLine(to: CGPoint(x: -10, y: h + 10))
        hill.closeSubpath()
        let hillRect = CGRect(x: 0, y: h * 0.65, width: w, height: h * 0.36)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: hill,
                bounds: hillRect,
                light: dark ? Color(hex: 0x1B3135) : Color(hex: 0xB8D8AE),
                rich: dark ? Color(hex: 0x122229) : Color(hex: 0x8DBA84),
                pencilOutline: (dark ? Color(hex: 0x52807A) : Color(hex: 0x557B4C)).opacity(0.42),
                lineWidth: 1.2
            )
        } else {
            ctx.fill(
                hill,
                with: .linearGradient(
                    Gradient(colors: [
                        dark ? Color(hex: 0x1C3238) : Color(hex: 0xBEE0B4),
                        dark ? Color(hex: 0x112028) : Color(hex: 0x8EB985)
                    ]),
                    startPoint: CGPoint(x: w * 0.5, y: h * 0.68),
                    endPoint: CGPoint(x: w * 0.5, y: h)
                )
            )
        }

        // Gliding little songbird silhouette in upper meadow air
        let bw = min(w, h) * 0.055
        var bird = Path()
        let wingLift = step == 1 ? CGFloat(sin(p.raw * .pi * 6.0) * 4.5) : -2.0
        bird.move(to: CGPoint(x: birdPoint.x - bw, y: birdPoint.y + wingLift))
        bird.addQuadCurve(to: birdPoint, control: CGPoint(x: birdPoint.x - bw * 0.5, y: birdPoint.y - bw * 0.55))
        bird.addQuadCurve(to: CGPoint(x: birdPoint.x + bw, y: birdPoint.y + wingLift), control: CGPoint(x: birdPoint.x + bw * 0.5, y: birdPoint.y - bw * 0.55))
        ctx.stroke(
            bird,
            with: .color((dark ? Color(hex: 0xFFE3A3) : Color(hex: 0x39584A)).opacity(0.85)),
            style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
        )

        if step == 1 {
            // Two soft bird-song rings + 3 tumbling sunlit autumn-sage leaves
            BespokeStageHelpers.drawPauseHalo(in: &ctx, center: birdPoint, baseRadius: min(w, h) * 0.08, progress: p.action, tint: Crayon.sky, dark: dark)
            for idx in 0..<3 {
                let lx = w * (0.20 + CGFloat(idx) * 0.28) + CGFloat(sin(p.raw * .pi * 2.0 + Double(idx)) * 12.0)
                let ly = h * (0.24 + CGFloat(p.action) * 0.34 + CGFloat(idx) * 0.05)
                var lc = ctx
                lc.translateBy(x: lx, y: ly)
                lc.rotate(by: .degrees(p.raw * 140 + Double(idx) * 45))
                lc.fill(Path(ellipseIn: CGRect(x: -7, y: -3.5, width: 14, height: 7)), with: .color(Palette.mint.opacity(0.75)))
            }
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoAnchor,
                to: mossAnchor,
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Palette.amber,
                lineWidth: 2.2,
                dark: dark
            )
        } else if step == 2 {
            // Soft settling breeze ribbon leading gently home
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: (ottoAnchor.x + mossAnchor.x) * 0.5, y: hillY - min(w, h) * 0.16),
                baseRadius: min(w, h) * 0.12,
                progress: p.raw,
                tint: Palette.amber,
                dark: dark
            )
        }
    }
}
