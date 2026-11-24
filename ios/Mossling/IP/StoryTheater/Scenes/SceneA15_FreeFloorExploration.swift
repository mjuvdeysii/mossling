import SwiftUI

/// A15 (Free Floor Exploration · 3 Steps):
/// Wide sunlit quilted floor-mat horizon with stitched edge border and side woven tidy bin:
/// Step 0: Stray small clutter items slide calmly off the quilt into the side shelf basket as Otto lights the open space ->
/// Step 1: Chamfered beech wooden ring + soft pastel ball rest a short curious reach ahead of Moss ->
/// Step 2: Moss scoots and pivots freely along a curved dotted exploration path across the open mat.
struct SceneA15_FreeFloorExploration: View {
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
            let groundY = h * 0.855

            let ottoX: CGFloat = step == 0 ? w * 0.22 : w * 0.19
            let mossX: CGFloat = {
                switch step {
                case 0: return w * 0.68
                case 1: return w * 0.72
                default: return w * (0.74 - 0.18 * CGFloat(p.action))
                }
            }()

            let mossHopLift: CGFloat = step == 2
                ? CGFloat(max(0.0, sin(p.action * .pi * 2.0))) * ms * 0.08
                : (step == 1 && p.raw >= 0.50 ? CGFloat(max(0.0, sin((p.raw - 0.50) / 0.30 * .pi))) * ms * 0.07 : 0)

            let ringTarget = CGPoint(x: w * 0.48, y: groundY - s * 0.03)
            let ringPos: CGPoint = {
                switch step {
                case 0:
                    return CGPoint(x: w * 0.10, y: groundY - s * 0.08)
                case 1:
                    let t = CGFloat(p.action)
                    let start = CGPoint(x: w * 0.34, y: groundY - s * 0.15)
                    let x = start.x + (ringTarget.x - start.x) * t
                    let y = start.y + (ringTarget.y - start.y) * t - CGFloat(sin(Double(t) * .pi)) * s * 0.10
                    return CGPoint(x: x, y: y)
                default:
                    return ringTarget
                }
            }()

            let ottoLean: Double = step == 0 ? 5.0 * p.action : 3.5
            let mossLean: Double = step == 2 ? -9.0 * sin(p.action * .pi) : (step == 1 ? -5.0 * p.contactEnvelope : -2.0)

            let ottoLook = CGPoint(x: 0.76, y: 0.22)
            let mossLook = step == 0 ? CGPoint(x: -0.55, y: 0.10) : CGPoint(x: -0.86, y: 0.30)
            let ottoMood: Mood = step == 2 ? .happy : .open
            let mossMood: Mood = step == 2 ? .happy : (step == 1 && p.raw >= 0.42 ? .wow : .open)

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat, lift: mossHopLift)
            )

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
                    drawQuiltedFloor(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        ringTarget: ringTarget,
                        ringPos: ringPos,
                        mossX: mossX,
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: step == 0 ? CGPoint(x: w * 0.52, y: groundY) : ringTarget,
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
                    lightDirection: CGPoint(x: 0.76, y: -0.62),
                    secondaryLagDegrees: -ottoLean * 0.32
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
                    lightDirection: CGPoint(x: 0.76, y: -0.62),
                    secondaryLagDegrees: -mossLean * 0.42
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: step == 0 ? CGPoint(x: w * 0.52, y: groundY) : ringTarget,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawQuiltedFloor(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        ringTarget: CGPoint,
        ringPos: CGPoint,
        mossX: CGFloat,
        step: Int,
        p: LivingPhaseSample,
        flat: Bool,
        dark: Bool
    ) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xF9F6EC),
            dayBottom: Color(hex: 0xEAE3CF),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        if flat {
            GhibliDrawHelpers.drawKomorebiCanopy(in: &ctx, w: w, h: h, swayOffset: CGFloat(sin(p.raw * .pi * 2.0) * 3.0), dark: dark)
        }

        // Hardwood baseboard horizon
        let floorRect = CGRect(x: -6, y: h * 0.72, width: w + 12, height: h * 0.30)
        ctx.fill(
            Path(floorRect),
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x1D2842) : Color(hex: 0xEDE2CD),
                    dark ? Color(hex: 0x131B2E) : Color(hex: 0xD8CCB4)
                ]),
                startPoint: CGPoint(x: w * 0.5, y: h * 0.72),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Wide quilted organic exploration mat centered on the floor
        let quiltRect = CGRect(x: w * 0.14, y: groundY - h * 0.085, width: w * 0.74, height: h * 0.15)
        let quiltPath = Path(ellipseIn: quiltRect)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: quiltPath,
                bounds: quiltRect,
                light: dark ? Color(hex: 0x263A4E) : Color(hex: 0xE6F1E2),
                rich: dark ? Color(hex: 0x1A2B3D) : Color(hex: 0xC6DEC1),
                pencilOutline: (dark ? Color(hex: 0x628A88) : Color(hex: 0x6D9668)).opacity(0.60),
                lineWidth: 1.3
            )
        } else {
            PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: quiltRect.midX, y: quiltRect.maxY - 2), rx: quiltRect.width * 0.48, ry: 7, dark: dark, opacity: 0.7)
            ctx.fill(
                quiltPath,
                with: .radialGradient(
                    Gradient(colors: [
                        dark ? Color(hex: 0x2B4055) : Color(hex: 0xEAF4E6),
                        dark ? Color(hex: 0x1B2B3C) : Color(hex: 0xC6DEC0)
                    ]),
                    center: CGPoint(x: quiltRect.midX, y: quiltRect.midY),
                    startRadius: 4,
                    endRadius: quiltRect.width * 0.52
                )
            )
            ctx.stroke(Path(ellipseIn: quiltRect.insetBy(dx: 5, dy: 3)), with: .color((dark ? Color.white : Color(hex: 0x6E9567)).opacity(0.35)), style: StrokeStyle(lineWidth: 1.1, dash: [4, 4]))
        }

        // Far-left low tidy basket catching cleared clutter items in Step 0
        let binRect = CGRect(x: w * 0.03, y: groundY - min(w, h) * 0.11, width: min(w, h) * 0.14, height: min(w, h) * 0.11)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: binRect.midX, y: groundY + 2), rx: binRect.width * 0.5, ry: 4, dark: dark)
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(roundedRect: binRect, cornerRadius: 5), bounds: binRect, dark: dark, warmth: 0.5, grainLines: 2)

        if step == 0 {
            // Two small clutter blocks sliding safely out of the center quilt into the left bin
            let slide = CGFloat(p.action)
            let bx1 = w * 0.46 + (binRect.midX - w * 0.46) * slide
            let bx2 = w * 0.54 + (binRect.midX + 6 - w * 0.54) * slide
            let r1 = CGRect(x: bx1 - 7, y: groundY - 14 - CGFloat(sin(Double(slide) * .pi)) * 18, width: 14, height: 14)
            let r2 = CGRect(x: bx2 - 6, y: groundY - 12 - CGFloat(sin(Double(slide) * .pi)) * 12, width: 12, height: 12)
            ctx.fill(Path(roundedRect: r1, cornerRadius: 3), with: .color(Crayon.tangerine.opacity(1.0 - Double(slide) * 0.5)))
            ctx.fill(Path(ellipseIn: r2), with: .color(Crayon.lilac.opacity(1.0 - Double(slide) * 0.5)))

            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: quiltRect.midX, y: groundY - min(w, h) * 0.04),
                baseRadius: min(w, h) * 0.14,
                progress: p.action,
                tint: Crayon.teal,
                dark: dark
            )
        } else {
            // Chamfered beech wooden ring resting at close curious reach
            let ringR = min(w, h) * 0.056
            PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: ringPos.x, y: groundY + 2), rx: ringR * 0.9, ry: 4, dark: dark)
            let outer = CGRect(x: ringPos.x - ringR, y: ringPos.y - ringR, width: ringR * 2, height: ringR * 2)
            let inner = outer.insetBy(dx: ringR * 0.42, dy: ringR * 0.42)
            var ringPath = Path(ellipseIn: outer)
            ringPath.addEllipse(in: inner)
            let eo = FillStyle(eoFill: true)
            ctx.fill(
                ringPath,
                with: .linearGradient(
                    Gradient(colors: [
                        dark ? Color(hex: 0xC8965A) : Color(hex: 0xF1CE97),
                        dark ? Color(hex: 0x8F6334) : Color(hex: 0xCE9553)
                    ]),
                    startPoint: CGPoint(x: outer.minX, y: outer.minY),
                    endPoint: CGPoint(x: outer.maxX, y: outer.maxY)
                ),
                style: eo
            )
            if flat {
                ctx.stroke(Path(ellipseIn: outer), with: .color(Color(hex: 0x6E4822).opacity(0.6)), lineWidth: 1.0)
            }

            if step == 1 {
                BespokeStageHelpers.drawContactSparkles(
                    in: &ctx,
                    center: ringTarget,
                    pulse: p.contact,
                    radius: min(w, h) * 0.10,
                    color: Palette.amber
                )
            } else {
                // Dotted exploration trail curving gently beneath Moss toward the wooden ring
                var trail = Path()
                trail.move(to: CGPoint(x: w * 0.74, y: groundY - 6))
                trail.addQuadCurve(
                    to: CGPoint(x: mossX, y: groundY - 6),
                    control: CGPoint(x: (w * 0.74 + mossX) * 0.5, y: groundY - 18)
                )
                ctx.stroke(trail, with: .color(Palette.bead.opacity(0.68)), style: StrokeStyle(lineWidth: 2.0, lineCap: .round, dash: [4, 4]))

                BespokeStageHelpers.drawContactSparkles(
                    in: &ctx,
                    center: CGPoint(x: (mossX + ringTarget.x) * 0.5, y: groundY - min(w, h) * 0.10),
                    pulse: p.contact,
                    radius: min(w, h) * 0.10,
                    color: Palette.amber
                )
            }
        }
    }
}
