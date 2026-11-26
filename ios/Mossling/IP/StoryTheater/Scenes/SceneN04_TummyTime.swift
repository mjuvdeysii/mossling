import SwiftUI

/// N04: 3/4 Bird's-eye circular quilted tummy-time playmat with window sun-panes, swaying top-edge
/// leaf-and-bead mobile, gentle rim accompaniment, and Moss posture + gaze lift in Step 2.
struct SceneN04_TummyTime: View {
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
            let mossGround = h * 0.785
            let ottoGround = h * 0.615

            // Moss tummy-time posture scales gently up when encouraged in Step 2
            let headLift = step == 2 ? p.action : 0.0
            let mossScale = CGSize(
                width: 1.07 - headLift * 0.07,
                height: 0.90 + headLift * 0.12
            )
            let mossLift = CGFloat(headLift * sin(p.raw * .pi) * Double(ms * 0.04))

            let ottoX = w * (step == 1 ? 0.725 - CGFloat(sin(p.action * .pi) * 0.06) : 0.73)
            let mossX = w * 0.435

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: ottoGround, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: mossGround, flat: flat, lift: mossLift)
            )

            let mossLook: CGPoint = {
                switch step {
                case 0: return CGPoint(x: 0.35, y: 0.15)
                case 1: return CGPoint(x: 0.55 - sin(p.action * .pi) * 0.25, y: 0.02)
                default: return CGPoint(x: 0.30 + headLift * 0.52, y: 0.08 - headLift * 0.46)
                }
            }()
            let ottoLook = CGPoint(x: -0.68, y: 0.36)
            let ottoLean = step == 2 ? -8.0 : -4.0
            let mossLean = step == 2 ? -6.0 * headLift : 4.0

            let mossMood: Mood = step == 2 && p.action > 0.55 ? .happy : (step == 1 ? .open : .wow)
            let ottoMood: Mood = step == 2 && p.isContactWindow ? .happy : .open
            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.42 : 0.28, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawBirdsEyeMat(in: &c, w: size.width, h: size.height, step: step, p: p, flat: flat, dark: dark)
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
                    lid: dark ? 0.42 : 0.28,
                    lean: ottoLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.80, y: -0.60),
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
                    hopLift: mossLift / max(1, ms),
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.80, y: -0.60),
                    secondaryLagDegrees: step == 2 ? sin(p.followThrough * .pi) * 10.0 : 0,
                    postureScale: mossScale
                )
                .position(mossCenter)

                // Top-edge hanging mobile swaying gently above Moss's upturned gaze
                Canvas(rendersAsynchronously: false) { c, size in
                    drawOverheadMobile(in: &c, w: size.width, h: size.height, p: p, step: step, dark: dark, flat: flat)
                }
                .allowsHitTesting(false)

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

    private func drawBirdsEyeMat(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, step: Int, p: LivingPhaseSample, flat: Bool, dark: Bool) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xEDE3CF),
            dayBottom: Color(hex: 0xDFCFAF),
            nightTop: Color(hex: 0x0B1222),
            nightBottom: Color(hex: 0x15203A),
            dark: dark
        )

        // Warm nursery honey-oak floor planks in subtle perspective + soft miter joints
        let plankColor = (dark ? Color(hex: 0x263452) : Color(hex: 0xB8986D)).opacity(dark ? 0.36 : 0.28)
        for i in 1..<6 {
            let y = h * CGFloat(i) / 6.0
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: w, y: y + 4))
            ctx.stroke(line, with: .color(plankColor), lineWidth: 1.0)
            let jointX = w * (i.isMultiple(of: 2) ? 0.34 : 0.68)
            var joint = Path()
            joint.move(to: CGPoint(x: jointX, y: y + 1))
            joint.addLine(to: CGPoint(x: jointX - 6, y: y + h / 6.0))
            ctx.stroke(joint, with: .color(plankColor.opacity(0.65)), lineWidth: 0.9)
        }

        // Large 3/4 bird's-eye circular quilted playmat
        let matRect = CGRect(x: w * 0.11, y: h * 0.34, width: w * 0.78, height: h * 0.58)
        let matPath = Path(ellipseIn: matRect)
        PixarDrawHelpers.drawContactAO(
            in: &ctx,
            center: CGPoint(x: matRect.midX, y: matRect.maxY - 2),
            rx: matRect.width * 0.48,
            ry: 12,
            dark: dark,
            opacity: 0.75
        )
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: matPath,
                bounds: matRect,
                light: dark ? Color(hex: 0x2B4449) : Color(hex: 0xF7F2E3),
                rich: dark ? Color(hex: 0x1D303A) : Color(hex: 0xD9E3CE),
                pencilOutline: (dark ? Color(hex: 0x628A8C) : Color(hex: 0x8BA07F)).opacity(0.50),
                lineWidth: 1.2
            )
        } else {
            ctx.fill(
                matPath,
                with: .radialGradient(
                    Gradient(colors: [
                        dark ? Color(hex: 0x2D474D) : Color(hex: 0xFAF6E8),
                        dark ? Color(hex: 0x1D2F3B) : Color(hex: 0xD8E2CE)
                    ]),
                    center: CGPoint(x: matRect.midX, y: matRect.midY - matRect.height * 0.1),
                    startRadius: 8,
                    endRadius: matRect.width * 0.52
                )
            )
        }

        // Dual concentric linen quilting stitch rings & sunlit botanical window projection
        let outerTrimRect = matRect.insetBy(dx: 4, dy: 4)
        ctx.stroke(
            Path(ellipseIn: outerTrimRect),
            with: .color((dark ? Color(hex: 0x84B699) : Color(hex: 0x95AD86)).opacity(0.42)),
            lineWidth: 1.5
        )
        let innerRect = matRect.insetBy(dx: matRect.width * 0.11, dy: matRect.height * 0.11)
        ctx.stroke(
            Path(ellipseIn: innerRect),
            with: .color((dark ? Color(hex: 0x8AD5A0) : Color(hex: 0x7DA374)).opacity(step == 1 ? 0.58 : 0.36)),
            style: StrokeStyle(lineWidth: step == 1 ? 1.8 : 1.1, dash: [6, 5])
        )

        var clippedMat = ctx
        clippedMat.clip(to: matPath)
        if !dark {
            for col in 0..<2 {
                let px = w * (0.28 + CGFloat(col) * 0.19)
                var pane = Path()
                pane.move(to: CGPoint(x: px, y: matRect.minY + 12))
                pane.addLine(to: CGPoint(x: px + w * 0.14, y: matRect.minY + 12))
                pane.addLine(to: CGPoint(x: px + w * 0.08, y: matRect.maxY - 22))
                pane.addLine(to: CGPoint(x: px - w * 0.06, y: matRect.maxY - 22))
                pane.closeSubpath()
                clippedMat.fill(pane, with: .color(Color(hex: 0xFFF7D6).opacity(0.36)))
            }
        }

        if step == 2 {
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: CGPoint(x: w * 0.64, y: h * 0.50),
                to: CGPoint(x: w * 0.48, y: h * 0.62),
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Palette.amber,
                lineWidth: 2.3,
                dark: dark
            )
        }
    }

    private func drawOverheadMobile(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, p: LivingPhaseSample, step: Int, dark: Bool, flat: Bool) {
        let sway = CGFloat(sin(p.raw * .pi * 2.0) * (step == 2 ? 7.0 : 3.5))
        let items: [(CGFloat, CGFloat, Color)] = [
            (0.34, 0.14, dark ? Color(hex: 0x84C99A) : Color(hex: 0x7BB084)),
            (0.50, 0.21, Palette.amber),
            (0.65, 0.12, dark ? Color(hex: 0xE6C68C) : Color(hex: 0xDFB676))
        ]
        for (idx, item) in items.enumerated() {
            let x = w * item.0 + sway * CGFloat(idx == 1 ? 1.0 : 0.7)
            let y = h * item.1
            var string = Path()
            string.move(to: CGPoint(x: w * item.0, y: 0))
            string.addLine(to: CGPoint(x: x, y: y))
            ctx.stroke(string, with: .color((dark ? Color(hex: 0x8CA1CF) : Color(hex: 0x8F7652)).opacity(0.55)), lineWidth: 1.0)

            let r = min(w, h) * (idx == 1 ? 0.030 : 0.024)
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            ctx.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [item.2.mix(with: .white, by: flat ? 0.14 : 0.34), item.2]),
                    center: CGPoint(x: x - r * 0.25, y: y - r * 0.25),
                    startRadius: 0,
                    endRadius: r * 1.4
                )
            )
        }
    }
}
