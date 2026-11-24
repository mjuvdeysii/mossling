import SwiftUI

/// A23 (Turning Pages & Pointing · 3 Steps):
/// Cozy floor reading cushion beside a front-facing Montessori board-book rack holding 3 chunky board books:
/// Step 0: Moss chooses the warm ochre sun board book from the shelf and brings it onto the cushion ->
/// Step 1: Golden spotlight ring traces the pointed illustration as Otto weaves a warm descriptive voice ribbon ->
/// Step 2: Thick rounded board pages turn playfully & settle calmly closed — honoring skipping or stopping anytime.
struct SceneA23_TurningPagesPointing: View {
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
            let groundY = h * 0.86

            let ottoX = w * 0.24
            let mossX = w * 0.74
            let bookSpot = CGPoint(x: w * 0.50, y: groundY - s * 0.045)

            let mossHopLift: CGFloat = (step == 0 && p.raw >= 0.48)
                ? CGFloat(max(0.0, sin((p.raw - 0.48) / 0.32 * .pi))) * ms * 0.08
                : 0
            let ottoLean: Double = step == 1 ? 6.5 * p.action : 3.5
            let mossLean: Double = step == 0 ? -8.5 * p.action : (step == 1 ? -6.5 * p.contactEnvelope : -3.5)

            let ottoLook = CGPoint(x: 0.78, y: 0.24)
            let mossLook = step == 0 ? CGPoint(x: -0.60, y: 0.08) : CGPoint(x: -0.82, y: 0.30)
            let ottoMood: Mood = step >= 1 ? .happy : .open
            let mossMood: Mood = step >= 1 ? .happy : (p.raw >= 0.44 ? .wow : .open)

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
                    drawBookNookAndPages(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        bookSpot: bookSpot,
                        ottoVoice: CGPoint(x: ottoCenter.x + os * 0.18, y: ottoCenter.y - os * 0.06),
                        mossEar: CGPoint(x: mossCenter.x - ms * 0.18, y: mossCenter.y - ms * 0.06),
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: bookSpot,
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
                    lightDirection: CGPoint(x: 0.28, y: -0.66),
                    secondaryLagDegrees: -ottoLean * 0.30
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
                    hopping: step == 0 && mossHopLift > ms * 0.03,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.28, y: -0.66),
                    secondaryLagDegrees: -mossLean * 0.42
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: bookSpot,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawBookNookAndPages(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        bookSpot: CGPoint,
        ottoVoice: CGPoint,
        mossEar: CGPoint,
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
            dayBottom: Color(hex: 0xECE3CE),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        let s = min(w, h)
        let floorRect = CGRect(x: -6, y: h * 0.74, width: w + 12, height: h * 0.28)
        ctx.fill(
            Path(floorRect),
            with: .linearGradient(
                Gradient(colors: [dark ? Color(hex: 0x1E2A44) : Color(hex: 0xEFE5D0), dark ? Color(hex: 0x131B2E) : Color(hex: 0xD8CCB4)]),
                startPoint: CGPoint(x: w * 0.5, y: h * 0.74),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Low front-facing wooden book rack in upper-center background
        let rackRect = CGRect(x: w * 0.36, y: h * 0.34, width: w * 0.28, height: h * 0.14)
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(roundedRect: rackRect, cornerRadius: 5), bounds: rackRect, dark: dark, warmth: 0.6, grainLines: 2)
        let covers: [(CGFloat, Color)] = [(-0.26, Crayon.teal), (0.0, Palette.bead), (0.26, Crayon.sky)]
        for (idx, (dx, col)) in covers.enumerated() {
            let picked = (idx == 1 && step >= 1) || (idx == 1 && step == 0 && p.action > 0.3)
            if !picked {
                let bk = CGRect(x: rackRect.midX + rackRect.width * dx - 12, y: rackRect.minY - 12, width: 24, height: 22)
                ctx.fill(Path(roundedRect: bk, cornerRadius: 3), with: .color(col))
            }
        }

        // Cozy oval reading mat on floor
        let rugRect = CGRect(x: w * 0.32, y: groundY - 6, width: w * 0.36, height: 15)
        let rugPath = Path(ellipseIn: rugRect)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: rugPath,
                bounds: rugRect,
                light: dark ? Color(hex: 0x2F4064) : Color(hex: 0xF8E9D5),
                rich: dark ? Color(hex: 0x212F4C) : Color(hex: 0xE7CBB0),
                pencilOutline: (dark ? Color(hex: 0x5C729C) : Color(hex: 0x9C7E62)).opacity(0.50),
                lineWidth: 1.0
            )
        } else {
            ctx.fill(rugPath, with: .color(dark ? Color(hex: 0x283656) : Color(hex: 0xF3DFC8)))
            PixarDrawHelpers.drawForegroundBokeh(
                in: &ctx,
                points: [
                    (CGPoint(x: w * 0.16, y: h * 0.20), 13, Palette.amber),
                    (CGPoint(x: w * 0.84, y: h * 0.24), 10, Color(hex: 0xFFE8AE))
                ],
                dark: dark
            )
        }

        // Active ochre sun board book
        let spreadW = s * 0.22
        let spreadH = s * 0.11
        let activePos: CGPoint = step == 0
            ? CGPoint(
                x: rackRect.midX + (bookSpot.x - rackRect.midX) * CGFloat(p.action),
                y: rackRect.minY + (bookSpot.y - rackRect.minY) * CGFloat(p.action) - CGFloat(sin(p.action * .pi)) * s * 0.08
            )
            : bookSpot

        if !flat {
            PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: activePos.x, y: groundY + 2), rx: spreadW * 0.50, ry: 4.5, dark: dark)
        }

        let closeFrac = step == 2 ? max(0.0, (p.raw - 0.56) / 0.30) : 0.0
        let leftW = spreadW * 0.5 * CGFloat(max(0.15, 1.0 - min(1.0, closeFrac)))
        let rightW = spreadW * 0.5

        // Left page + right page of thick rounded board book
        let leftPage = CGRect(x: activePos.x - leftW, y: activePos.y - spreadH * 0.5, width: leftW, height: spreadH)
        let rightPage = CGRect(x: activePos.x, y: activePos.y - spreadH * 0.5, width: rightW, height: spreadH)
        let paperCol = dark ? Color(hex: 0x2B3759) : Color(hex: 0xFFFDF6)

        if closeFrac < 0.85 {
            let leftPath = Path(roundedRect: leftPage, cornerRadius: 4)
            if flat {
                GhibliDrawHelpers.fillWatercolor(
                    in: &ctx,
                    path: leftPath,
                    bounds: leftPage,
                    light: paperCol,
                    rich: paperCol.mix(with: Palette.bead, by: 0.10),
                    pencilOutline: Palette.bead.opacity(0.65),
                    lineWidth: 1.2
                )
            } else {
                ctx.fill(leftPath, with: .color(paperCol))
                ctx.stroke(leftPath, with: .color(Palette.bead.opacity(0.65)), lineWidth: 1.4)
            }
        }
        let rightPath = Path(roundedRect: rightPage, cornerRadius: 4)
        let rightFill = closeFrac >= 0.85 ? Palette.bead : paperCol
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: rightPath,
                bounds: rightPage,
                light: rightFill,
                rich: rightFill.mix(with: Palette.bead, by: 0.14),
                pencilOutline: Palette.bead.opacity(0.75),
                lineWidth: 1.2
            )
        } else {
            ctx.fill(rightPath, with: .color(rightFill))
            ctx.stroke(rightPath, with: .color(Palette.bead.opacity(0.75)), lineWidth: 1.4)
        }

        // Sun motif on right page + turning middle leaf flap
        if closeFrac < 0.80 {
            let sunPt = CGPoint(x: rightPage.midX, y: rightPage.midY)
            ctx.fill(Path(ellipseIn: CGRect(x: sunPt.x - 8, y: sunPt.y - 8, width: 16, height: 16)), with: .color(Palette.amber.opacity(0.85)))

            if step == 1 {
                let focusR = 13 + CGFloat(p.contact) * 3
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: sunPt.x - focusR, y: sunPt.y - focusR, width: focusR * 2, height: focusR * 2)),
                    with: .color(Crayon.teal.opacity(0.75)),
                    lineWidth: 1.8
                )
                BespokeStageHelpers.drawSilkVoiceRibbon(
                    in: &ctx,
                    from: ottoVoice,
                    to: mossEar,
                    progress: p.action,
                    waveOffset: p.raw * .pi * 2.0,
                    color: Palette.amber,
                    lineWidth: 2.3,
                    dark: dark
                )
            } else if step == 2 {
                // Turning board leaf sweeping smoothly right -> left
                let flip = sin(min(1.0, p.action) * .pi)
                let flapW = max(3, rightW * CGFloat(abs(cos(min(1.0, p.action) * .pi))))
                let flapX = p.action < 0.5 ? activePos.x : activePos.x - flapW
                let flapRect = CGRect(x: flapX, y: activePos.y - spreadH * 0.5 - CGFloat(flip) * 6, width: flapW, height: spreadH)
                ctx.fill(Path(roundedRect: flapRect, cornerRadius: 3), with: .color(paperCol.mix(with: Palette.bead, by: 0.16)))
                ctx.stroke(Path(roundedRect: flapRect, cornerRadius: 3), with: .color(Palette.bead.opacity(0.6)), lineWidth: 1.0)
            }
        }

        BespokeStageHelpers.drawContactSparkles(
            in: &ctx,
            center: activePos,
            pulse: p.contact,
            radius: s * 0.10,
            color: Palette.amber
        )
    }
}
