import SwiftUI

/// A03: Wide ultra-low playroom floor horizon (`0.80`) with uncluttered sunlit wainscoting:
/// safe awake surface (Step 0) -> Otto glides down to floor eye level (Step 1)
/// -> low vocal encouragement waves (Step 2) -> stitched Montessori Takane ball rolling into view (Step 3).
struct SceneA03_AwakeTummyPlay: View {
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
            let floorY = h * 0.855

            // Otto starts higher watching over, then glides smoothly to floor eye level in Step 1+
            let ottoGround: CGFloat = {
                switch step {
                case 0: return h * 0.775
                case 1: return h * (0.775 + CGFloat(p.action) * 0.080)
                default: return floorY
                }
            }()

            let ottoX = w * (step >= 1 ? 0.25 : 0.22)
            let mossX = w * 0.65

            let mossPosture = CGSize(
                width: 1.06 - (step >= 2 ? 0.05 * p.action : 0.0),
                height: 0.91 + (step >= 2 ? 0.07 * p.action : 0.0)
            )
            let ottoLean = step >= 1 ? 6.5 : 3.5
            let mossLean = step == 3 && p.isContactWindow ? -5.0 : 2.0

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: ottoGround, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: floorY, flat: flat)
            )

            let ottoLook = CGPoint(x: 0.78, y: step == 0 ? 0.24 : 0.05)
            let mossLook = step == 3 ? CGPoint(x: -0.45, y: 0.24) : CGPoint(x: -0.78, y: -0.02)
            let ottoMood: Mood = step >= 2 ? .happy : .open
            let mossMood: Mood = step == 3 ? (p.action > 0.4 ? .happy : .wow) : (step == 2 ? .happy : .open)

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.40 : 0.25, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )
            let ballPos = CGPoint(
                x: w * (step == 3 ? (0.34 + CGFloat(p.action) * 0.16) : 0.50),
                y: floorY - s * 0.045
            )

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawWideLowPlayroom(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        ottoPos: CGPoint(x: ottoCenter.x + os * 0.22, y: ottoCenter.y + os * 0.05),
                        mossPos: CGPoint(x: mossCenter.x - ms * 0.22, y: mossCenter.y + ms * 0.05),
                        ballPos: ballPos,
                        floorY: floorY,
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
                    lid: dark ? 0.40 : 0.25,
                    lean: ottoLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.78, y: -0.62),
                    secondaryLagDegrees: -ottoLean * 0.28
                )
                .position(ottoCenter)

                StoryTheaterActorView(
                    kind: .moss,
                    size: ms,
                    mood: mossMood,
                    look: mossLook,
                    lid: dark ? 0.18 : 0,
                    lean: mossLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.78, y: -0.62),
                    secondaryLagDegrees: step == 3 ? sin(p.followThrough * .pi) * 10.0 : -mossLean * 0.35,
                    postureScale: mossPosture
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

    private func drawWideLowPlayroom(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        ottoPos: CGPoint,
        mossPos: CGPoint,
        ballPos: CGPoint,
        floorY: CGFloat,
        step: Int,
        p: LivingPhaseSample,
        flat: Bool,
        dark: Bool
    ) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xFBF8EE),
            dayBottom: Color(hex: 0xEFE7D4),
            nightTop: Color(hex: 0x0A1223),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        // Subtle wainscoting paneling across lower back wall leaving wide open floor clear
        let wainscotTop = h * 0.56
        let wallLineColor = (dark ? Color(hex: 0x2F4168) : Color(hex: 0xD9CCB5)).opacity(0.60)
        var chairRail = Path()
        chairRail.move(to: CGPoint(x: 0, y: wainscotTop))
        chairRail.addLine(to: CGPoint(x: w, y: wainscotTop))
        ctx.stroke(chairRail, with: .color(wallLineColor), lineWidth: 2.2)

        for col in 1..<5 {
            let px = w * CGFloat(col) / 5.0
            let panel = CGRect(x: px - w * 0.06, y: wainscotTop + 10, width: w * 0.12, height: h * 0.16)
            ctx.stroke(Path(roundedRect: panel, cornerRadius: 3), with: .color(wallLineColor.opacity(0.45)), lineWidth: 1.0)
        }

        // Ultra-low woven floor mat below horizon (0.76 to 1.0)
        let horizonY = h * 0.77
        let matRect = CGRect(x: -4, y: horizonY, width: w + 8, height: h - horizonY + 8)
        let matPath = Path(matRect)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: matPath,
                bounds: matRect,
                light: dark ? Color(hex: 0x243449) : Color(hex: 0xEFE6D1),
                rich: dark ? Color(hex: 0x182334) : Color(hex: 0xD7CCB3),
                pencilOutline: (dark ? Color(hex: 0x526A8F) : Color(hex: 0x9C8F77)).opacity(0.45),
                lineWidth: 1.2
            )
        } else {
            ctx.fill(
                matPath,
                with: .linearGradient(
                    Gradient(colors: [
                        dark ? Color(hex: 0x24334A) : Color(hex: 0xF3EBD8),
                        dark ? Color(hex: 0x152033) : Color(hex: 0xD9CEB6)
                    ]),
                    startPoint: CGPoint(x: w * 0.5, y: horizonY),
                    endPoint: CGPoint(x: w * 0.5, y: h)
                )
            )
        }

        if step == 2 {
            // Low horizontal voice ribbons skimming along the woven floor plane
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoPos,
                to: mossPos,
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Palette.amber,
                lineWidth: 2.5,
                dark: dark
            )
        } else if step == 3 {
            // Rolling 6-panel stitched Montessori Takane fabric clutch ball
            let r = min(w, h) * 0.056
            PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: ballPos.x, y: floorY + 2), rx: r * 1.1, ry: r * 0.30, dark: dark, opacity: 0.85)
            var rot = ctx
            rot.translateBy(x: ballPos.x, y: ballPos.y)
            rot.rotate(by: .degrees(p.action * 195))
            let bRect = CGRect(x: -r, y: -r, width: r * 2, height: r * 2)
            rot.fill(
                Path(ellipseIn: bRect),
                with: .radialGradient(
                    Gradient(colors: [Color(hex: 0xF5E7CE), Color(hex: 0xC69A64)]),
                    center: CGPoint(x: -r * 0.25, y: -r * 0.25),
                    startRadius: 1,
                    endRadius: r * 1.4
                )
            )
            // Distinct Montessori wedge petals
            for petal in 0..<3 {
                var wc = rot
                wc.rotate(by: .degrees(Double(petal) * 60))
                let wedge = CGRect(x: -r * 0.36, y: -r * 0.92, width: r * 0.72, height: r * 1.84)
                let col = petal == 0 ? Color(hex: 0x7EB48B) : (petal == 1 ? Palette.amber : Color(hex: 0xD98B68))
                wc.fill(Path(ellipseIn: wedge), with: .color(col.opacity(0.68)))
            }
            rot.stroke(Path(ellipseIn: bRect), with: .color(Color(hex: 0x7A5E3E).opacity(0.45)), lineWidth: 1.0)
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: CGPoint(x: ballPos.x + r * 0.9, y: ballPos.y - r * 0.6),
                pulse: p.contact,
                radius: r * 1.3,
                color: Palette.amber
            )
        }
    }
}
