import SwiftUI

/// N03: Enveloping knitted blanket cocoon cradle with zero flat horizon line — curved wool drape
/// sways in tight 3.8s synchronization across Day & Lamp, with quiet sensory dim & sleep settling in Step 1.
struct SceneN03_GentleHolding: View {
    let ctx: BespokeSceneContext

    var body: some View {
        let step = min(max(0, ctx.stepIndex), 1)
        let p = ctx.phase
        let dark = ctx.dark
        let flat = ctx.flat

        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let h = max(1, geo.size.height)
            let s = min(w, h)

            // Unified slow cradle swing across blanket + both companions
            let cradleSwing = sin(p.raw * .pi * 2.0)
            let cradleY = CGFloat(cradleSwing) * h * 0.016
            let cradleDeg = cradleSwing * (step == 0 ? 2.4 : 1.8)

            let ms = s * 0.36
            let os = ms * Kind.otto.scale
            let groundY = h * 0.825 + cradleY

            let ottoX = w * (step == 0 ? 0.345 + CGFloat(p.action * 0.03) : 0.375)
            let mossX = w * 0.635

            let ottoLean = step == 0 ? (6.0 + p.action * 4.5 + cradleDeg) : (7.5 + cradleDeg)
            let mossLean = step == 0 ? (-3.0 + cradleDeg) : (-4.5 + cradleDeg)

            let mossMood: Mood = step == 0 ? (p.raw < 0.30 ? .wow : .open) : .sleep
            let mossLid: Double = step == 1 ? 0.88 : (p.raw < 0.30 ? 0.05 : 0.35)
            let ottoLid: Double = step == 1 ? (dark ? 0.62 : 0.50) : (dark ? 0.44 : 0.32)

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY + h * 0.015, flat: flat)
            )

            let ottoLook = CGPoint(x: 0.72, y: 0.16)
            let mossLook = CGPoint(x: -0.68, y: step == 1 ? 0.20 : 0.04)
            let ottoState = Creature.state(.otto, face: step == 0 ? .happy : .open, look: ottoLook, lid: ottoLid, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )
            let targetWorld = mossCenter

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawCradleAtmosphere(in: &c, w: size.width, h: size.height, cradleY: cradleY, cradleDeg: cradleDeg, step: step, p: p, flat: flat, dark: dark)
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: targetWorld,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .floorPool
                )
                .opacity(step == 1 ? 0.78 : 1.0)

                StoryTheaterActorView(
                    kind: .otto,
                    size: os,
                    mood: step == 0 ? .happy : .open,
                    look: ottoLook,
                    lid: ottoLid,
                    lean: ottoLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.72, y: -0.68),
                    secondaryLagDegrees: -ottoLean * 0.25
                )
                .position(ottoCenter)

                StoryTheaterActorView(
                    kind: .moss,
                    size: ms,
                    mood: mossMood,
                    look: mossLook,
                    lid: mossLid,
                    lean: mossLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.72, y: -0.68),
                    secondaryLagDegrees: -mossLean * 0.30
                )
                .position(mossCenter)

                // Front overlapping blanket lip tucking actors warmly inside the cradle
                Canvas(rendersAsynchronously: false) { c, size in
                    drawFrontBlanketLip(in: &c, w: size.width, h: size.height, cradleY: cradleY, cradleDeg: cradleDeg, step: step, dark: dark, flat: flat)
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: targetWorld,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .opacity(step == 1 ? 0.76 : 1.0)
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawCradleAtmosphere(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        cradleY: CGFloat,
        cradleDeg: Double,
        step: Int,
        p: LivingPhaseSample,
        flat: Bool,
        dark: Bool
    ) {
        let calmDim = step == 1 ? 0.14 : 0.0
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xF8F2E4).mix(with: Color(hex: 0xDFD5C2), by: calmDim),
            dayBottom: Color(hex: 0xE7DBC7).mix(with: Color(hex: 0xCFC1AA), by: calmDim),
            nightTop: Color(hex: 0x0A1020),
            nightBottom: Color(hex: 0x151E37),
            dark: dark
        )

        // Concentric warm soothing halo wrapping both companions inside the cocoon
        let haloCenter = CGPoint(x: w * 0.50, y: h * 0.56 + cradleY)
        for ring in 0..<3 {
            let radius = min(w, h) * CGFloat(0.28 + Double(ring) * 0.11 + sin(p.raw * .pi * 2.0) * 0.015)
            ctx.fill(
                Path(ellipseIn: CGRect(x: haloCenter.x - radius, y: haloCenter.y - radius * 0.85, width: radius * 2, height: radius * 1.7)),
                with: .color((dark ? Palette.amber : Color(hex: 0xFFF3D4)).opacity((step == 0 ? 0.14 : 0.09) / Double(ring + 1)))
            )
        }

        // Back curved wool cocoon cradle sweep (zero flat ground horizon)
        var rotCtx = ctx
        rotCtx.translateBy(x: w * 0.5, y: h * 0.72 + cradleY)
        rotCtx.rotate(by: .degrees(cradleDeg))

        var backShawl = Path()
        backShawl.move(to: CGPoint(x: -w * 0.55, y: -h * 0.20))
        backShawl.addCurve(
            to: CGPoint(x: w * 0.55, y: -h * 0.16),
            control1: CGPoint(x: -w * 0.18, y: h * 0.08),
            control2: CGPoint(x: w * 0.18, y: h * 0.08)
        )
        backShawl.addLine(to: CGPoint(x: w * 0.55, y: h * 0.42))
        backShawl.addLine(to: CGPoint(x: -w * 0.55, y: h * 0.42))
        backShawl.closeSubpath()

        let shawlBounds = CGRect(x: -w * 0.55, y: -h * 0.20, width: w * 1.1, height: h * 0.62)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &rotCtx,
                path: backShawl,
                bounds: shawlBounds,
                light: dark ? Color(hex: 0x2B3B5E) : Color(hex: 0xEFE4CE),
                rich: dark ? Color(hex: 0x1D2843) : Color(hex: 0xD8C7AD),
                pencilOutline: (dark ? Color(hex: 0x5E74A6) : Color(hex: 0x9C8870)).opacity(0.45),
                lineWidth: 1.2
            )
        } else {
            rotCtx.fill(
                backShawl,
                with: .linearGradient(
                    Gradient(colors: [
                        dark ? Color(hex: 0x2B3A5C) : Color(hex: 0xF5ECDA),
                        dark ? Color(hex: 0x1A253F) : Color(hex: 0xD7C8B1)
                    ]),
                    startPoint: CGPoint(x: 0, y: -h * 0.15),
                    endPoint: CGPoint(x: 0, y: h * 0.35)
                )
            )
        }

        // Gentle responsive soothing rings around Otto -> Moss during Step 0
        if step == 0 {
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: w * 0.54, y: h * 0.48 + cradleY),
                baseRadius: min(w, h) * 0.12,
                progress: p.action,
                tint: Palette.amber,
                dark: dark
            )
        }
    }

    private func drawFrontBlanketLip(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        cradleY: CGFloat,
        cradleDeg: Double,
        step: Int,
        dark: Bool,
        flat: Bool
    ) {
        var rotCtx = ctx
        rotCtx.translateBy(x: w * 0.5, y: h * 0.72 + cradleY)
        rotCtx.rotate(by: .degrees(cradleDeg))

        var lip = Path()
        lip.move(to: CGPoint(x: -w * 0.55, y: h * 0.08))
        lip.addQuadCurve(to: CGPoint(x: w * 0.55, y: h * 0.08), control: CGPoint(x: 0, y: h * 0.21))
        lip.addLine(to: CGPoint(x: w * 0.55, y: h * 0.42))
        lip.addLine(to: CGPoint(x: -w * 0.55, y: h * 0.42))
        lip.closeSubpath()

        let lipColorTop = dark ? Color(hex: 0x274046) : Color(hex: 0xDDE6D5)
        let lipColorBot = dark ? Color(hex: 0x1A2B36) : Color(hex: 0xB8C9B1)
        rotCtx.fill(
            lip,
            with: .linearGradient(
                Gradient(colors: [lipColorTop, lipColorBot]),
                startPoint: CGPoint(x: 0, y: h * 0.08),
                endPoint: CGPoint(x: 0, y: h * 0.36)
            )
        )

        var stitch = Path()
        stitch.move(to: CGPoint(x: -w * 0.52, y: h * 0.115))
        stitch.addQuadCurve(to: CGPoint(x: w * 0.52, y: h * 0.115), control: CGPoint(x: 0, y: h * 0.24))
        rotCtx.stroke(
            stitch,
            with: .color((dark ? Color(hex: 0x8CD9A3) : Color(hex: 0x7A9C72)).opacity(step == 1 ? 0.28 : 0.42)),
            style: StrokeStyle(lineWidth: flat ? 1.5 : 1.2, dash: [6, 5])
        )
    }
}
