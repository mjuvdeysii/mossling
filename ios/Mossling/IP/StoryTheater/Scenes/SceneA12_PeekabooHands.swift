import SwiftUI

/// A12 (Peekaboo! · 3 Steps):
/// Intimate warm portrait framing with a pleated oatmeal-terracotta nursery linen veil in front of Otto
/// (strictly upholding docs/IP.md: Otto never grows hands).
/// Step 0: Linen veil lowers over Otto while Moss waits with curiosity, then lifts on the peek with joy ->
/// Step 1: Gentle rhythmic repeat with vocal wave -> Step 2: Moss leads the "more / all done" tempo.
struct SceneA12_PeekabooHands: View {
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

            let ms = s * 0.40
            let os = ms * Kind.otto.scale
            let groundY = h * 0.865

            let ottoX = w * 0.30
            let mossX = w * 0.69

            // Peekaboo cover fraction: 1.0 = covering Otto's face, 0.0 = pulled high/clear
            let coverFrac: Double = {
                switch step {
                case 0:
                    if p.raw < 0.38 {
                        return 0.92 * LivingMotionClock.smoothstep(p.raw / 0.22)
                    } else if p.raw < 0.52 {
                        let lift = (p.raw - 0.38) / 0.14
                        return 0.92 * (1.0 - LivingMotionClock.easeOutCubic(lift))
                    }
                    return 0.0
                case 1:
                    if p.raw < 0.32 {
                        return 0.88 * LivingMotionClock.smoothstep(p.raw / 0.18)
                    } else if p.raw < 0.48 {
                        return 0.88 * (1.0 - LivingMotionClock.easeOutCubic((p.raw - 0.32) / 0.16))
                    }
                    return 0.0
                default:
                    // Step 2: Moss controls tempo — playful light dip, then open calm finish
                    return max(0.0, sin(p.action * .pi) * 0.45 * (1.0 - p.followThrough))
                }
            }()

            let revealed = coverFrac < 0.35
            let mossHopLift: CGFloat = (step <= 1 && revealed && p.raw >= 0.46)
                ? CGFloat(max(0.0, sin((p.raw - 0.46) / 0.32 * .pi))) * ms * 0.12
                : 0

            let ottoLean: Double = coverFrac > 0.4 ? -2.0 : (revealed ? 8.0 * p.contact : 4.5)
            let mossLean: Double = {
                switch step {
                case 0, 1: return coverFrac > 0.4 ? -4.0 : -7.5 * p.followThrough
                default: return -6.5 * p.action + 3.5 * p.hold
                }
            }()

            let mossMood: Mood = coverFrac > 0.4 ? .wow : (step <= 1 ? (revealed ? .happy : .wow) : .happy)
            let ottoMood: Mood = revealed ? .happy : .open

            let ottoLook = CGPoint(x: 0.78, y: 0.04)
            let mossLook = CGPoint(x: -0.78, y: -0.04)

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
                    drawAtmosphereStage(in: &c, w: size.width, h: size.height, flat: flat, dark: dark)
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
                    lightDirection: CGPoint(x: 0.72, y: -0.65),
                    secondaryLagDegrees: -ottoLean * 0.30
                )
                .position(ottoCenter)

                // Soft nursery peekaboo linen veil rendered in front of Otto when covering
                Canvas(rendersAsynchronously: false) { c, size in
                    drawPeekabooVeilAndSparkles(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        ottoCenter: ottoCenter,
                        ottoSize: os,
                        mossCenter: mossCenter,
                        mossSize: ms,
                        coverFrac: coverFrac,
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                StoryTheaterActorView(
                    kind: .moss,
                    size: ms,
                    mood: mossMood,
                    look: mossLook,
                    lid: dark ? 0.16 : 0,
                    lean: mossLean,
                    hopLift: mossHopLift / max(1, ms),
                    hopping: step <= 1 && revealed && p.isContactWindow,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.72, y: -0.65),
                    secondaryLagDegrees: revealed ? sin(p.followThrough * .pi) * 12.0 : -mossLean * 0.4
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

    private func drawAtmosphereStage(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, flat: Bool, dark: Bool) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xFBF7EC),
            dayBottom: Color(hex: 0xECE4D0),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        let rugRect = CGRect(x: -6, y: h * 0.75, width: w + 12, height: h * 0.27)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: Path(rugRect),
                bounds: rugRect,
                light: dark ? Color(hex: 0x213048) : Color(hex: 0xF4ECE0),
                rich: dark ? Color(hex: 0x162134) : Color(hex: 0xDBD0BA),
                pencilOutline: (dark ? Color(hex: 0x526A90) : Color(hex: 0x9C8F77)).opacity(0.42),
                lineWidth: 1.2
            )
        } else {
            ctx.fill(
                Path(rugRect),
                with: .linearGradient(
                    Gradient(colors: [
                        dark ? Color(hex: 0x22304A) : Color(hex: 0xF5EEDD),
                        dark ? Color(hex: 0x141F32) : Color(hex: 0xDCD0B9)
                    ]),
                    startPoint: CGPoint(x: w * 0.5, y: h * 0.75),
                    endPoint: CGPoint(x: w * 0.5, y: h)
                )
            )
        }
    }

    private func drawPeekabooVeilAndSparkles(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        ottoCenter: CGPoint,
        ottoSize: CGFloat,
        mossCenter: CGPoint,
        mossSize: CGFloat,
        coverFrac: Double,
        step: Int,
        p: LivingPhaseSample,
        flat: Bool,
        dark: Bool
    ) {
        // Pleated nursery linen canopy veil descending smoothly over Otto's face
        let veilW = ottoSize * 0.96
        let maxVeilH = ottoSize * 0.78
        let veilH = max(ottoSize * 0.14, maxVeilH * CGFloat(coverFrac))
        let topY = ottoCenter.y - ottoSize * 0.44
        let veilRect = CGRect(x: ottoCenter.x - veilW * 0.45, y: topY, width: veilW, height: veilH)

        // Subtle overhead beech brass rod
        let rodRect = CGRect(x: veilRect.minX - 8, y: topY - 4, width: veilW + 16, height: 6)
        ctx.fill(Path(roundedRect: rodRect, cornerRadius: 3), with: .color(Color(hex: dark ? 0xA8804C : 0xC69C64)))

        if coverFrac > 0.04 {
            var cloth = Path()
            cloth.move(to: CGPoint(x: veilRect.minX, y: veilRect.minY))
            cloth.addLine(to: CGPoint(x: veilRect.maxX, y: veilRect.minY))
            cloth.addLine(to: CGPoint(x: veilRect.maxX, y: veilRect.maxY - 6))
            cloth.addQuadCurve(
                to: CGPoint(x: veilRect.midX, y: veilRect.maxY),
                control: CGPoint(x: veilRect.minX + veilW * 0.75, y: veilRect.maxY + 6)
            )
            cloth.addQuadCurve(
                to: CGPoint(x: veilRect.minX, y: veilRect.maxY - 6),
                control: CGPoint(x: veilRect.minX + veilW * 0.25, y: veilRect.maxY + 6)
            )
            cloth.closeSubpath()

            let clothLight = dark ? Color(hex: 0xC97D63).opacity(0.92) : Color(hex: 0xF1C5A8)
            let clothDeep = dark ? Color(hex: 0x9E5740).opacity(0.94) : Color(hex: 0xDF9E7B)
            if flat {
                GhibliDrawHelpers.fillWatercolor(
                    in: &ctx,
                    path: cloth,
                    bounds: veilRect,
                    light: clothLight,
                    rich: clothDeep,
                    pencilOutline: (dark ? Color(hex: 0xEAB49A) : Color(hex: 0x8F5A42)).opacity(0.65),
                    lineWidth: 1.2
                )
            } else {
                ctx.fill(
                    cloth,
                    with: .linearGradient(
                        Gradient(colors: [clothLight, clothDeep]),
                        startPoint: CGPoint(x: veilRect.midX, y: veilRect.minY),
                        endPoint: CGPoint(x: veilRect.midX, y: veilRect.maxY)
                    )
                )
            }
            // Pleated vertical fold seams
            for fold in 1...3 {
                let fx = veilRect.minX + veilW * CGFloat(fold) / 4.0
                var line = Path()
                line.move(to: CGPoint(x: fx, y: veilRect.minY + 3))
                line.addLine(to: CGPoint(x: fx, y: veilRect.maxY - 4))
                ctx.stroke(line, with: .color(Color.white.opacity(dark ? 0.16 : 0.34)), lineWidth: 1.0)
            }
        }

        // Curiosity wait halo while hidden, peek reveal sparkles when opened
        if coverFrac > 0.45 {
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: (ottoCenter.x + mossCenter.x) * 0.5, y: ottoCenter.y - ottoSize * 0.16),
                baseRadius: min(w, h) * 0.11,
                progress: p.raw * 1.4,
                tint: Palette.amber,
                dark: dark
            )
        } else {
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: CGPoint(x: ottoCenter.x + ottoSize * 0.28, y: ottoCenter.y - ottoSize * 0.22),
                pulse: step <= 1 ? p.contact : p.contact * 0.6,
                radius: min(w, h) * 0.11,
                color: Palette.amber
            )
            if step == 1 {
                BespokeStageHelpers.drawSilkVoiceRibbon(
                    in: &ctx,
                    from: CGPoint(x: ottoCenter.x + ottoSize * 0.20, y: ottoCenter.y),
                    to: CGPoint(x: mossCenter.x - mossSize * 0.20, y: mossCenter.y),
                    progress: p.action,
                    waveOffset: p.raw * .pi * 2.0,
                    color: Palette.amber,
                    lineWidth: 2.3,
                    dark: dark
                )
            }
        }
    }
}
