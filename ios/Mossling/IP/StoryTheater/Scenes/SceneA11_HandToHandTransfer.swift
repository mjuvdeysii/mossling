import SwiftUI

/// A11 (Passing Hand to Hand · 3 Steps):
/// Moss sits on the LEFT-CENTER on a real elliptical stitched woven cushion; Otto stands calmly on the RIGHT:
/// Step 0: Rattle slides smoothly along the cushion within easy reach from Otto's side ->
/// Step 1: Foreground hourglass maple rattle passes cleanly across Moss's chest midline ->
/// Step 2: Otto steps calmly back without urging as Moss freely tilts and explores the rattle.
struct SceneA11_HandToHandTransfer: View {
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

            let ms = s * 0.36
            let os = ms * Kind.otto.scale
            let groundY = h * 0.855

            let mossX = w * 0.35
            let ottoX = w * (step == 2 ? 0.80 : 0.75)

            // Foreground hourglass rattle: grounded slide -> chest midline transfer -> gentle free tilt
            let rattlePos: CGPoint = {
                let rightChest = CGPoint(x: mossX + w * 0.105, y: groundY - ms * 0.24)
                let leftChest = CGPoint(x: mossX - w * 0.105, y: groundY - ms * 0.24)
                let matRight = CGPoint(x: mossX + w * 0.24, y: groundY - s * 0.036)
                switch step {
                case 0:
                    let t = CGFloat(p.action)
                    return CGPoint(
                        x: matRight.x + (mossX + w * 0.10 - matRight.x) * t,
                        y: matRight.y - CGFloat(sin(Double(t) * .pi) * s * 0.025)
                    )
                case 1:
                    let arc = p.action
                    let x = rightChest.x + (leftChest.x - rightChest.x) * CGFloat(arc)
                    let y = rightChest.y - CGFloat(sin(arc * .pi)) * s * 0.045
                    return CGPoint(x: x, y: y)
                default:
                    let sway = CGFloat(sin(p.raw * .pi * 2.0) * 8.0)
                    return CGPoint(x: mossX + sway, y: groundY - s * 0.055)
                }
            }()

            let rattleAngle: Double = {
                switch step {
                case 0: return 18.0 * (1.0 - p.action)
                case 1: return 28.0 - 56.0 * p.action
                default: return sin(p.raw * .pi * 2.0) * 14.0
                }
            }()

            let ottoLean: Double = {
                switch step {
                case 0: return -9.0 * p.action
                case 1: return -2.5
                default: return 4.0
                }
            }()
            let mossLean: Double = {
                switch step {
                case 0: return 4.0 * p.action
                case 1: return 5.5 - 11.0 * p.action
                default: return sin(p.raw * .pi * 2.0) * 3.5
                }
            }()

            let dx = max(-1.0, min(1.0, Double((rattlePos.x - mossX) / max(1, w * 0.25))))
            let mossLook = CGPoint(x: dx, y: 0.34)
            let ottoLook = CGPoint(x: -0.78, y: 0.20)

            let mossMood: Mood = step == 1 ? (p.isContactWindow ? .happy : .wow) : (step == 2 ? .happy : .open)
            let ottoMood: Mood = step == 2 ? .open : .happy

            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat)
            )
            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY, flat: flat)
            )

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.40 : 0.24, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawCushionStageBackground(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        mossX: mossX,
                        groundY: groundY,
                        step: step,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: rattlePos,
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
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: -0.78, y: -0.62),
                    secondaryLagDegrees: -mossLean * 0.45
                )
                .position(mossCenter)

                StoryTheaterActorView(
                    kind: .otto,
                    size: os,
                    mood: ottoMood,
                    look: ottoLook,
                    lid: dark ? 0.40 : 0.24,
                    lean: ottoLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: -0.78, y: -0.62),
                    secondaryLagDegrees: -ottoLean * 0.30
                )
                .position(ottoCenter)

                // Foreground layer in front of Moss's torso so chest midline transfer occludes naturally
                Canvas(rendersAsynchronously: false) { c, size in
                    drawForegroundRattleAndCues(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        mossX: mossX,
                        groundY: groundY,
                        rattlePos: rattlePos,
                        rattleAngle: rattleAngle,
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: rattlePos,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawCushionStageBackground(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        mossX: CGFloat,
        groundY: CGFloat,
        step: Int,
        flat: Bool,
        dark: Bool
    ) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xFAF7ED),
            dayBottom: Color(hex: 0xECE5D1),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        let s = min(w, h)
        let floorRect = CGRect(x: -6, y: h * 0.73, width: w + 12, height: h * 0.29)
        ctx.fill(
            Path(floorRect),
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x1D2B42) : Color(hex: 0xEFE6D4),
                    dark ? Color(hex: 0x131D2E) : Color(hex: 0xD8CCB6)
                ]),
                startPoint: CGPoint(x: w * 0.5, y: h * 0.73),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Elliptical stitched circular woven cushion centered cleanly around Moss
        let cushionRect = CGRect(x: mossX - w * 0.24, y: groundY - s * 0.075, width: w * 0.48, height: s * 0.145)
        let cushionPath = Path(ellipseIn: cushionRect)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: mossX, y: cushionRect.maxY + 1), rx: cushionRect.width * 0.48, ry: 4.5, dark: dark)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: cushionPath,
                bounds: cushionRect,
                light: dark ? Color(hex: 0x2B415B) : Color(hex: 0xF7EFE0),
                rich: dark ? Color(hex: 0x1E2F44) : Color(hex: 0xE2D3B8),
                pencilOutline: (dark ? Color(hex: 0x5B7B9C) : Crayon.caramel).opacity(0.55),
                lineWidth: 1.1
            )
        } else {
            ctx.fill(cushionPath, with: .color(dark ? Color(hex: 0x263952) : Color(hex: 0xF4EAD6)))
            ctx.stroke(
                Path(ellipseIn: cushionRect.insetBy(dx: 4, dy: 3)),
                with: .color((dark ? Palette.amber : Crayon.caramel).opacity(0.45)),
                style: StrokeStyle(lineWidth: 1.2, dash: [4, 4])
            )
        }

        // Midline stitched axis right down Moss's center
        var seam = Path()
        seam.move(to: CGPoint(x: mossX, y: cushionRect.minY + 3))
        seam.addLine(to: CGPoint(x: mossX, y: cushionRect.maxY - 3))
        ctx.stroke(
            seam,
            with: .color((dark ? Palette.amber : Crayon.caramel).opacity(dark ? 0.42 : 0.46)),
            style: StrokeStyle(lineWidth: 1.3, dash: [3, 3])
        )
    }

    private func drawForegroundRattleAndCues(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        mossX: CGFloat,
        groundY: CGFloat,
        rattlePos: CGPoint,
        rattleAngle: Double,
        step: Int,
        p: LivingPhaseSample,
        flat: Bool,
        dark: Bool
    ) {
        let s = min(w, h)
        if step == 1 {
            var trail = Path()
            let rightX = mossX + w * 0.105
            let leftX = mossX - w * 0.105
            let baseY = groundY - s * 0.088
            let ctrl = CGPoint(x: mossX, y: baseY - s * 0.065)
            trail.move(to: CGPoint(x: rightX, y: baseY))
            trail.addQuadCurve(
                to: CGPoint(x: leftX, y: baseY),
                control: ctrl
            )
            ctx.stroke(
                trail,
                with: .color(Palette.amber.opacity(dark ? 0.48 : 0.42)),
                style: StrokeStyle(lineWidth: 1.8, dash: [4, 4])
            )
            // Luminous transfer pearl waypoints along midline crossing arc
            for t in [CGFloat(0.22), CGFloat(0.50), CGFloat(0.78)] {
                let u = 1.0 - t
                let bx = u * u * rightX + 2 * u * t * ctrl.x + t * t * leftX
                let by = u * u * baseY + 2 * u * t * ctrl.y + t * t * baseY
                let pulseR: CGFloat = t == 0.50 ? 3.2 : 2.2
                ctx.fill(
                    Path(ellipseIn: CGRect(x: bx - pulseR, y: by - pulseR, width: pulseR * 2, height: pulseR * 2)),
                    with: .color(Palette.amber.opacity(dark ? 0.65 : 0.72))
                )
            }
        }

        let len = s * 0.115
        let aoScale = step == 1 ? 0.55 : 0.90
        PixarDrawHelpers.drawContactAO(
            in: &ctx,
            center: CGPoint(x: rattlePos.x, y: groundY + 1),
            rx: len * 0.46 * aoScale,
            ry: len * 0.15 * aoScale,
            dark: dark
        )

        var rCtx = ctx
        rCtx.translateBy(x: rattlePos.x, y: rattlePos.y)
        rCtx.rotate(by: .degrees(rattleAngle))

        let stemRect = CGRect(x: -len * 0.44, y: -len * 0.11, width: len * 0.88, height: len * 0.22)
        PixarDrawHelpers.drawBeechwood(
            in: &rCtx,
            path: Path(roundedRect: stemRect, cornerRadius: len * 0.10),
            bounds: stemRect,
            dark: dark,
            warmth: 0.84,
            grainLines: 3
        )
        // Turned wooden lathe grip rings at center stem
        for gx in [-len * 0.08, len * 0.08] {
            var ring = Path()
            ring.move(to: CGPoint(x: gx, y: stemRect.minY + 1))
            ring.addLine(to: CGPoint(x: gx, y: stemRect.maxY - 1))
            rCtx.stroke(ring, with: .color(Color(hex: 0x7A512A).opacity(dark ? 0.40 : 0.34)), lineWidth: 1.0)
        }

        let capR = len * 0.26
        for (cx, col) in [(-len * 0.44, Color(hex: 0x7EB48B)), (len * 0.44, Palette.amber)] {
            let capRect = CGRect(x: cx - capR, y: -capR, width: capR * 2, height: capR * 2)
            rCtx.fill(
                Path(ellipseIn: capRect),
                with: .radialGradient(
                    Gradient(colors: [col.mix(with: .white, by: flat ? 0.18 : 0.38), col, col.mix(with: .black, by: 0.14)]),
                    center: CGPoint(x: cx - capR * 0.25, y: -capR * 0.25),
                    startRadius: 0,
                    endRadius: capR * 1.35
                )
            )
            // Delicate carved botanical seam ring inside rattle bulb
            let grooveRect = capRect.insetBy(dx: capR * 0.26, dy: capR * 0.26)
            rCtx.stroke(
                Path(ellipseIn: grooveRect),
                with: .color(Color.white.opacity(dark ? 0.18 : 0.38)),
                lineWidth: 0.9
            )
            if flat {
                rCtx.stroke(Path(ellipseIn: capRect), with: .color(Color(hex: 0x4E4234).opacity(0.45)), lineWidth: 0.9)
            }
        }

        if step == 1 {
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: CGPoint(x: mossX, y: groundY - s * 0.12),
                pulse: p.contact,
                radius: s * 0.095,
                color: Palette.amber
            )
        } else if step == 2 {
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: mossX, y: groundY - s * 0.06),
                baseRadius: s * 0.115,
                progress: p.raw,
                tint: Crayon.leaf,
                dark: dark
            )
        }
    }
}
