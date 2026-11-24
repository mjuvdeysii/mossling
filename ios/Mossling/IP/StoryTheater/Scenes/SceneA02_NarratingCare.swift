import SwiftUI

/// A02: Waffle-linen care bench closeup with folded cotton care cloths & willow basket:
/// verbal narration highlighting untouched cloth (Step 0) -> patient readiness cue (Step 1)
/// -> offered two-cloth choice & gentle billowing shared care (Step 2).
struct SceneA02_NarratingCare: View {
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
            let groundY = h * 0.845

            let ottoX = w * 0.255
            let mossX = w * 0.755

            let ottoLean = step == 0 ? 7.0 : (step == 1 ? 2.0 : 5.0 * sin(p.action * .pi))
            let mossLean = step == 1 ? (-4.0 * p.action) : (step == 2 ? -5.0 * sin(p.followThrough * .pi) : 0)

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat)
            )

            let ottoLook = step == 0 ? CGPoint(x: 0.72, y: 0.30) : CGPoint(x: 0.76, y: 0.14)
            let mossLook = CGPoint(x: -0.70, y: step == 1 ? -0.05 : 0.20)
            let ottoMood: Mood = step == 0 ? .open : .happy
            let mossMood: Mood = {
                switch step {
                case 0: return .wow
                case 1: return p.action > 0.5 ? .happy : .open
                default: return .happy
                }
            }()

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.42 : 0.26, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )
            let clothSpot = CGPoint(x: w * 0.50, y: h * 0.78)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawCareBench(in: &c, w: size.width, h: size.height, clothSpot: clothSpot, step: step, p: p, flat: flat, dark: dark)
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: clothSpot,
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
                    lid: dark ? 0.42 : 0.26,
                    lean: ottoLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.74, y: -0.66),
                    secondaryLagDegrees: -ottoLean * 0.28
                )
                .position(ottoCenter)

                StoryTheaterActorView(
                    kind: .moss,
                    size: ms,
                    mood: mossMood,
                    look: mossLook,
                    lid: dark ? 0.22 : 0,
                    lean: mossLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.74, y: -0.66),
                    secondaryLagDegrees: step == 2 ? sin(p.followThrough * .pi) * 10.0 : -mossLean * 0.35
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: clothSpot,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawCareBench(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        clothSpot: CGPoint,
        step: Int,
        p: LivingPhaseSample,
        flat: Bool,
        dark: Bool
    ) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xFAF6EB),
            dayBottom: Color(hex: 0xECE1CB),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        // Waffle-linen changing bench & willow supply basket in back
        let benchRect = CGRect(x: 0, y: h * 0.67, width: w, height: h * 0.33)
        ctx.fill(
            Path(benchRect),
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x22304C) : Color(hex: 0xF7F1E2),
                    dark ? Color(hex: 0x162036) : Color(hex: 0xE5D9C3)
                ]),
                startPoint: CGPoint(x: w * 0.5, y: benchRect.minY),
                endPoint: CGPoint(x: w * 0.5, y: benchRect.maxY)
            )
        )
        // Subtle waffle weave lines
        for row in 1...3 {
            let y = benchRect.minY + benchRect.height * CGFloat(row) / 4.0
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: w, y: y))
            ctx.stroke(line, with: .color((dark ? Color(hex: 0x455B82) : Color(hex: 0xC6B79E)).opacity(0.26)), lineWidth: 1.0)
        }

        // Woven basket silhouette at back-center
        let basketRect = CGRect(x: w * 0.40, y: h * 0.52, width: w * 0.20, height: h * 0.14)
        let basketPath = Path(roundedRect: basketRect, cornerRadius: 10)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: basketPath,
                bounds: basketRect,
                light: dark ? Color(hex: 0x574331) : Color(hex: 0xDFBD8D),
                rich: dark ? Color(hex: 0x3A2B1F) : Color(hex: 0xBD925B),
                pencilOutline: (dark ? Color(hex: 0x8F7255) : Color(hex: 0x8A6338)).opacity(0.45),
                lineWidth: 1.0
            )
        } else {
            PixarDrawHelpers.drawBeechwood(in: &ctx, path: basketPath, bounds: basketRect, dark: dark, warmth: 0.65, grainLines: 3)
        }

        // Two care cloths: Sage (left-center) & Terracotta (right-center)
        let billowLift: CGFloat = step == 2 ? CGFloat(sin(p.action * .pi) * h * 0.08) : 0
        let spread: CGFloat = step == 2 ? CGFloat(p.action * w * 0.03) : 0
        let cloths: [(CGPoint, Color)] = [
            (CGPoint(x: clothSpot.x - w * 0.05 - spread, y: clothSpot.y - billowLift), dark ? Color(hex: 0x4E856A) : Color(hex: 0x8CB995)),
            (CGPoint(x: clothSpot.x + w * 0.05 + spread, y: clothSpot.y), dark ? Color(hex: 0x9C654B) : Color(hex: 0xDF9E7B))
        ]
        for (idx, item) in cloths.enumerated() {
            let rect = CGRect(x: item.0.x - w * 0.055, y: item.0.y - h * 0.035, width: w * 0.11, height: h * 0.07)
            PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: item.0.x, y: clothSpot.y + h * 0.04), rx: rect.width * 0.5, ry: 4, dark: dark, opacity: 0.7)
            ctx.fill(
                Path(roundedRect: rect, cornerRadius: 6),
                with: .linearGradient(
                    Gradient(colors: [item.1.mix(with: .white, by: 0.18), item.1]),
                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            )
            if idx == 0 && step == 0 {
                // Step 0 highlight halo around untouched cloth while narrating first
                ctx.stroke(
                    Path(roundedRect: rect.insetBy(dx: -3, dy: -3), cornerRadius: 8),
                    with: .color(Palette.amber.opacity(0.65 * (0.4 + 0.6 * sin(p.raw * .pi)))),
                    lineWidth: 1.8
                )
            }
        }

        if step == 0 {
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: CGPoint(x: w * 0.34, y: h * 0.56),
                to: CGPoint(x: clothSpot.x - w * 0.06, y: clothSpot.y - h * 0.06),
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Palette.amber,
                lineWidth: 2.3,
                dark: dark
            )
        } else if step == 1 {
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: w * 0.50, y: h * 0.50),
                baseRadius: min(w, h) * 0.10,
                progress: p.raw,
                tint: Palette.amber,
                dark: dark
            )
        } else {
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: CGPoint(x: clothSpot.x - w * 0.04, y: clothSpot.y - billowLift - 12),
                pulse: p.contact,
                radius: min(w, h) * 0.08,
                color: Palette.amber
            )
        }
    }
}
