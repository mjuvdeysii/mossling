import SwiftUI

/// A07 (Rhymes & Gentle Fingerplay · 4 Steps):
/// Lattice bamboo veranda & woven reed mat with swaying silk wind-chime tassel:
/// Step 0: Steady pentatonic meter ribbons -> Step 1: Synchronized rhythmic sway with beat dots ->
/// Step 2: Musical rest pause halo awaiting smile -> Step 3: Warm returning golden-jade loop ribbon.
struct SceneA07_RhymesFingerplay: View {
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

            let ms = s * 0.35
            let os = ms * Kind.otto.scale
            let floorY = h * 0.845

            let swayCycle = sin(p.raw * .pi * 2.0)
            let ottoLean: Double = {
                switch step {
                case 0: return 4.0 + swayCycle * 3.5
                case 1: return 6.0 + swayCycle * 8.0
                case 2: return 2.5
                default: return 5.0 + swayCycle * 5.0
                }
            }()
            let mossLean: Double = {
                switch step {
                case 0: return -2.0 + swayCycle * 2.5
                case 1: return -3.0 + swayCycle * 9.5
                case 2: return p.raw >= 0.46 ? -5.5 : 0
                default: return -3.5 + swayCycle * 6.0
                }
            }()

            let mossHopLift: CGFloat = {
                if step == 1 {
                    return CGFloat(abs(sin(p.action * .pi * 2.0))) * ms * 0.06
                } else if step == 2 && p.raw >= 0.48 {
                    return CGFloat(max(0.0, sin((p.raw - 0.48) / 0.34 * .pi))) * ms * 0.09
                } else if step == 3 {
                    return CGFloat(max(0.0, sin(p.raw * .pi * 2.0))) * ms * 0.05
                }
                return 0
            }()

            let ottoX = w * 0.29
            let mossX = w * 0.68

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: floorY, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: floorY, flat: flat, lift: mossHopLift)
            )

            let ottoLook = CGPoint(x: 0.72, y: 0.05)
            let mossLook = CGPoint(x: -0.70, y: -0.04)

            let ottoMood: Mood = step == 2 ? .open : .happy
            let mossMood: Mood = {
                switch step {
                case 0: return .open
                case 1: return .happy
                case 2: return p.raw >= 0.48 ? .happy : .wow
                default: return .happy
                }
            }()

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.38 : 0.24, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawVerandaStage(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        floorY: floorY,
                        ottoAnchor: CGPoint(x: ottoCenter.x + os * 0.16, y: ottoCenter.y - os * 0.12),
                        mossAnchor: CGPoint(x: mossCenter.x - ms * 0.16, y: mossCenter.y - ms * 0.10),
                        step: step,
                        p: p,
                        sway: swayCycle,
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
                    lid: dark ? 0.38 : 0.24,
                    lean: ottoLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.76, y: -0.64),
                    secondaryLagDegrees: -ottoLean * 0.35
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
                    hopping: mossHopLift > ms * 0.04,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.76, y: -0.64),
                    secondaryLagDegrees: swayCycle * 11.0
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

    private func drawVerandaStage(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        floorY: CGFloat,
        ottoAnchor: CGPoint,
        mossAnchor: CGPoint,
        step: Int,
        p: LivingPhaseSample,
        sway: Double,
        flat: Bool,
        dark: Bool
    ) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xFAF7EB),
            dayBottom: Color(hex: 0xEAE3CC),
            nightTop: Color(hex: 0x0A1222),
            nightBottom: Color(hex: 0x16233B),
            dark: dark
        )

        // Vertical bamboo/shoji lattice backdrop lines
        let latticeCol = (dark ? Color(hex: 0x33466E) : Color(hex: 0xD3C6AE)).opacity(0.45)
        for col in 1..<7 {
            let x = w * CGFloat(col) / 7.0
            var line = Path()
            line.move(to: CGPoint(x: x, y: h * 0.06))
            line.addLine(to: CGPoint(x: x, y: h * 0.68))
            ctx.stroke(line, with: .color(latticeCol), lineWidth: 1.2)
        }

        // Woven reed veranda floor horizon
        let horizonY = h * 0.73
        let matRect = CGRect(x: -6, y: horizonY, width: w + 12, height: h - horizonY + 10)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: Path(matRect),
                bounds: matRect,
                light: dark ? Color(hex: 0x203144) : Color(hex: 0xEFE6CC),
                rich: dark ? Color(hex: 0x162234) : Color(hex: 0xD5C9A8),
                pencilOutline: (dark ? Color(hex: 0x526A90) : Color(hex: 0x9B8E70)).opacity(0.42),
                lineWidth: 1.2
            )
        } else {
            ctx.fill(
                Path(matRect),
                with: .linearGradient(
                    Gradient(colors: [
                        dark ? Color(hex: 0x213046) : Color(hex: 0xF3EAD2),
                        dark ? Color(hex: 0x141F32) : Color(hex: 0xD8CCB0)
                    ]),
                    startPoint: CGPoint(x: w * 0.5, y: horizonY),
                    endPoint: CGPoint(x: w * 0.5, y: h)
                )
            )
        }

        // Hanging top-right wind chime tassel responding to rhyme meter
        let chimeBase = CGPoint(x: w * 0.84, y: 0)
        let chimeTip = CGPoint(x: w * 0.84 + CGFloat(sway * 8.0), y: h * 0.25)
        var chimeStem = Path()
        chimeStem.move(to: chimeBase)
        chimeStem.addLine(to: chimeTip)
        ctx.stroke(chimeStem, with: .color((dark ? Color(hex: 0x8BA3CC) : Color(hex: 0x8B7351)).opacity(0.75)), lineWidth: 1.4)
        let tagRect = CGRect(x: chimeTip.x - 6, y: chimeTip.y, width: 12, height: 22)
        ctx.fill(Path(roundedRect: tagRect, cornerRadius: 3), with: .color(Crayon.teal.opacity(dark ? 0.72 : 0.78)))

        // Step-specific rhyme rhythm visualization
        let midPt = CGPoint(x: (ottoAnchor.x + mossAnchor.x) * 0.5, y: min(ottoAnchor.y, mossAnchor.y) - h * 0.08)
        switch step {
        case 0:
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoAnchor,
                to: mossAnchor,
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Palette.amber,
                lineWidth: 2.5,
                dark: dark
            )
        case 1:
            // 4 luminous rhythmic meter beads arching in tempo
            for b in 0..<4 {
                let t = CGFloat(b) / 3.0
                let bx = ottoAnchor.x + (mossAnchor.x - ottoAnchor.x) * t
                let by = midPt.y - sin(t * .pi) * h * 0.07 + CGFloat(sin(p.raw * .pi * 4.0 + Double(b) * 0.8) * 4.0)
                let active = Int(p.raw * 4.0) % 4 == b
                let br: CGFloat = active ? 5.2 : 3.4
                ctx.fill(
                    Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2)),
                    with: .color((active ? Palette.amber : Crayon.teal).opacity(dark ? 0.90 : 0.82))
                )
            }
        case 2:
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: midPt,
                baseRadius: min(w, h) * 0.13,
                progress: p.raw,
                tint: Palette.amber,
                dark: dark
            )
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: CGPoint(x: mossAnchor.x - 6, y: mossAnchor.y - 10),
                pulse: p.contact,
                radius: min(w, h) * 0.09,
                color: Palette.amber
            )
        default:
            // Infinity warm figure-8 melody ribbon linking repeated daily tune
            var loop = Path()
            let rX = (mossAnchor.x - ottoAnchor.x) * 0.42
            let rY = h * 0.08
            for i in 0...32 {
                let u = Double(i) / 32.0 * p.action * 2.0 * .pi
                let pt = CGPoint(x: midPt.x + CGFloat(sin(u)) * rX, y: midPt.y + CGFloat(sin(u * 2.0)) * rY * 0.6)
                if i == 0 { loop.move(to: pt) } else { loop.addLine(to: pt) }
            }
            ctx.stroke(
                loop,
                with: .color(Palette.amber.opacity(dark ? 0.72 : 0.62)),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
            )
        }
    }
}
