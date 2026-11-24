import SwiftUI

/// A17 (Everyday Gestures & Signs · 3 Steps):
/// Sunlit doorway arch with soft fabric bunting pennant — strictly upholding docs/IP.md (Otto never grows hands):
/// Step 0: Otto models warm rhythmic nod & curved antenna wave-arcs leaving glowing golden cadence trails ->
/// Step 1: Moss echoes with lively mint-leaf waving & body lean; Otto responds with luminous warmth ->
/// Step 2: Moss expresses freely with a playful hop surrounded by open welcoming golden arcs.
struct SceneA17_EverydayGestures: View {
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

            let ms = s * 0.37
            let os = ms * Kind.otto.scale
            let groundY = h * 0.86

            let ottoX = w * 0.28
            let mossX = w * 0.70

            let ottoNodWave = sin(p.action * .pi * 2.0)
            let mossWave = sin(p.raw * .pi * 2.5)

            let ottoLean: Double = {
                switch step {
                case 0: return 4.0 + ottoNodWave * 6.5
                case 1: return 6.0 * p.followThrough
                default: return 4.0
                }
            }()
            let mossLean: Double = {
                switch step {
                case 0: return -2.0
                case 1: return -7.0 * p.action + mossWave * 4.0
                default: return -6.5 * p.action + mossWave * 5.0
                }
            }()
            let mossLeafLag: Double = step >= 1 ? mossWave * 16.0 : -mossLean * 0.35
            let ottoAntennaLag: Double = step == 0 ? ottoNodWave * 18.0 : -ottoLean * 0.32

            let mossHopLift: CGFloat = (step == 2 && p.raw >= 0.42)
                ? CGFloat(max(0.0, sin((p.raw - 0.42) / 0.38 * .pi))) * ms * 0.13
                : (step == 1 && p.raw >= 0.48 ? CGFloat(max(0.0, sin((p.raw - 0.48) / 0.32 * .pi))) * ms * 0.08 : 0)

            let ottoLook = CGPoint(x: 0.82, y: 0.08)
            let mossLook = CGPoint(x: -0.82, y: 0.04)

            let ottoMood: Mood = step >= 1 ? .happy : .open
            let mossMood: Mood = step == 0 ? .wow : .happy

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

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawDoorwayArchAndGestures(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        beadWorld: beadWorld,
                        ottoCenter: ottoCenter,
                        ottoSize: os,
                        mossCenter: mossCenter,
                        mossSize: ms,
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: mossCenter,
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
                    lightDirection: CGPoint(x: 0.74, y: -0.64),
                    secondaryLagDegrees: ottoAntennaLag
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
                    lightDirection: CGPoint(x: 0.74, y: -0.64),
                    secondaryLagDegrees: mossLeafLag
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: mossCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawDoorwayArchAndGestures(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        beadWorld: CGPoint,
        ottoCenter: CGPoint,
        ottoSize: CGFloat,
        mossCenter: CGPoint,
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
            dayTop: Color(hex: 0xFBF7EC),
            dayBottom: Color(hex: 0xECE3CE),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        // Arched sunlit doorway alcove framing the greeting stage
        let archRect = CGRect(x: w * 0.18, y: h * 0.08, width: w * 0.64, height: h * 0.68)
        let archPath = Path(roundedRect: archRect, cornerRadius: archRect.width * 0.5)
        let archTopCol = dark ? Color(hex: 0x1A2542) : Color(hex: 0xFFF9EA)
        let archBotCol = dark ? Color(hex: 0x141D35) : Color(hex: 0xF4EAD3)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: archPath,
                bounds: archRect,
                light: archTopCol,
                rich: archBotCol,
                pencilOutline: (dark ? Color(hex: 0x4A5E8A) : Color(hex: 0xCBB795)).opacity(0.55),
                lineWidth: 1.5
            )
        } else {
            ctx.fill(
                archPath,
                with: .linearGradient(
                    Gradient(colors: [archTopCol, archBotCol]),
                    startPoint: CGPoint(x: archRect.midX, y: archRect.minY),
                    endPoint: CGPoint(x: archRect.midX, y: archRect.maxY)
                )
            )
            ctx.stroke(archPath, with: .color((dark ? Color(hex: 0x4A5E8A) : Color(hex: 0xCBB795)).opacity(0.45)), lineWidth: 1.5)
            PixarDrawHelpers.drawForegroundBokeh(
                in: &ctx,
                points: [
                    (CGPoint(x: w * 0.34, y: h * 0.22), 14, Palette.amber),
                    (CGPoint(x: w * 0.66, y: h * 0.26), 11, Color(hex: 0xFFE6A3))
                ],
                dark: dark
            )
        }

        // Subtle draped cotton bunting pennant near top of arch
        let buntingColors = [Crayon.teal, Palette.bead, Crayon.pink]
        for i in 0..<3 {
            let bx = w * (0.36 + CGFloat(i) * 0.14)
            let by = h * (0.14 + (i == 1 ? 0.025 : 0.0))
            var tri = Path()
            tri.move(to: CGPoint(x: bx - 12, y: by))
            tri.addLine(to: CGPoint(x: bx + 12, y: by))
            tri.addLine(to: CGPoint(x: bx, y: by + 16))
            tri.closeSubpath()
            ctx.fill(tri, with: .color(buntingColors[i].opacity(dark ? 0.65 : 0.80)))
        }

        // Woven entryway mat
        let matRect = CGRect(x: -6, y: h * 0.74, width: w + 12, height: h * 0.28)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: Path(matRect),
                bounds: matRect,
                light: dark ? Color(hex: 0x203048) : Color(hex: 0xF3EBDA),
                rich: dark ? Color(hex: 0x141F32) : Color(hex: 0xDDD1BA),
                pencilOutline: (dark ? Color(hex: 0x526A90) : Color(hex: 0x9C8F77)).opacity(0.40),
                lineWidth: 1.2
            )
        } else {
            ctx.fill(
                Path(matRect),
                with: .linearGradient(
                    Gradient(colors: [dark ? Color(hex: 0x22304A) : Color(hex: 0xF4ECDB), dark ? Color(hex: 0x141F32) : Color(hex: 0xDDD1BA)]),
                    startPoint: CGPoint(x: w * 0.5, y: h * 0.74),
                    endPoint: CGPoint(x: w * 0.5, y: h)
                )
            )
        }

        // Gesture rhythm arcs (golden bulb wave arcs for Otto, sprout wave arcs for Moss — zero hands!)
        let minDim = min(w, h)
        if step == 0 {
            for i in 0..<2 {
                let r = minDim * CGFloat(0.10 + Double(i) * 0.06)
                var arc = Path()
                arc.addArc(
                    center: beadWorld,
                    radius: r,
                    startAngle: .degrees(-55),
                    endAngle: .degrees(35),
                    clockwise: false
                )
                ctx.stroke(
                    arc,
                    with: .color(Palette.amber.opacity((0.70 - Double(i) * 0.22) * p.action)),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                )
            }
            BespokeStageHelpers.drawContactSparkles(in: &ctx, center: beadWorld, pulse: p.contact, radius: minDim * 0.09, color: Palette.amber)
        } else if step == 1 {
            // Mint-leaf gesture arcs beside Moss + warm voice ribbon response from Otto
            let leafTop = CGPoint(x: mossCenter.x, y: mossCenter.y - mossSize * 0.38)
            for side in [-1.0, 1.0] {
                var arc = Path()
                arc.addArc(
                    center: leafTop,
                    radius: minDim * 0.10,
                    startAngle: .degrees(side < 0 ? -155 : -55),
                    endAngle: .degrees(side < 0 ? -125 : -25),
                    clockwise: false
                )
                ctx.stroke(arc, with: .color(Crayon.teal.opacity(0.68 * p.action)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            }
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: CGPoint(x: ottoCenter.x + ottoSize * 0.18, y: ottoCenter.y - ottoSize * 0.04),
                to: CGPoint(x: mossCenter.x - mossSize * 0.18, y: mossCenter.y - mossSize * 0.04),
                progress: p.followThrough,
                waveOffset: p.raw * .pi * 2.0,
                color: Palette.amber,
                lineWidth: 2.4,
                dark: dark
            )
        } else {
            // Open welcoming shared golden cadence halo
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: mossCenter.x, y: mossCenter.y - mossSize * 0.25),
                baseRadius: minDim * 0.14,
                progress: p.action,
                tint: Palette.bead,
                dark: dark
            )
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: CGPoint(x: (ottoCenter.x + mossCenter.x) * 0.5, y: h * 0.48),
                pulse: p.contact,
                radius: minDim * 0.12,
                color: Palette.amber
            )
        }
    }
}
