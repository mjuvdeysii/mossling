import SwiftUI

/// A31 (Telling Small Stories of the Day · 3 Steps):
/// Cozy window bench (`groundY = h * 0.865`) beneath a wall-mounted beech dowel suspending a 3-panel
/// chronological story banner (Morning Sun/Leaf -> Midday Hill/Kite -> Evening Warm Mug & Leaf Sprout):
/// Step 0: Adult recalls one gentle moment of the day lighting Panel 1 + narrative ribbon ->
/// Step 1: Golden sequence thread links Panel 1 -> Panel 2 -> Panel 3 ("who / when / action") ->
/// Step 2: Adult pauses warmly while Child hops and adds a final teal response ribbon & glowing Panel 3 sprout.
struct SceneA31_TellingDayStories: View {
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
            let groundY = h * 0.865

            let ottoX = w * 0.24
            let mossX = w * 0.75

            let mossHopLift: CGFloat = (step == 2 && p.raw >= 0.44)
                ? CGFloat(max(0.0, sin((p.raw - 0.44) / 0.34 * .pi))) * ms * 0.095
                : 0
            let ottoLean: Double = step == 0 ? 7.5 * p.action : (step == 2 ? 4.0 : 5.5)
            let mossLean: Double = step == 2 ? -8.5 * p.action : -4.0

            let ottoLook = step == 2 ? CGPoint(x: 0.78, y: -0.25) : CGPoint(x: 0.45 + 0.30 * p.action, y: -0.58)
            let mossLook = step == 1 ? CGPoint(x: -0.60 + 0.20 * p.action, y: -0.54) : CGPoint(x: -0.78, y: -0.34)
            let ottoMood: Mood = step >= 1 ? .happy : .open
            let mossMood: Mood = step == 2 ? .happy : (step == 1 ? .wow : .open)

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat, lift: mossHopLift)
            )

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.34 : 0.20, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )
            let storyTarget = CGPoint(x: w * 0.50, y: h * 0.36)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawStoryTriptychStage(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        ottoVoice: CGPoint(x: ottoCenter.x + os * 0.18, y: ottoCenter.y - os * 0.12),
                        mossEar: CGPoint(x: mossCenter.x - ms * 0.18, y: mossCenter.y - ms * 0.10),
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: storyTarget,
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
                    lid: dark ? 0.34 : 0.20,
                    lean: ottoLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.72, y: -0.66),
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
                    hopping: step == 2 && p.isContactWindow,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.72, y: -0.66),
                    secondaryLagDegrees: -mossLean * 0.42
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: storyTarget,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawStoryTriptychStage(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
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
            dayTop: Color(hex: 0xFAF7ED),
            dayBottom: Color(hex: 0xEDE4CF),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        if flat {
            GhibliDrawHelpers.drawKomorebiCanopy(in: &ctx, w: w, h: h, swayOffset: 0, dark: dark)
        }

        let s = min(w, h)
        let rugY = h * 0.75
        let rugRect = CGRect(x: -6, y: rugY, width: w + 12, height: h - rugY + 8)
        ctx.fill(
            Path(rugRect),
            with: .linearGradient(
                Gradient(colors: [dark ? Color(hex: 0x1E2A44) : Color(hex: 0xEFE5D0), dark ? Color(hex: 0x131B2E) : Color(hex: 0xD8CCB4)]),
                startPoint: CGPoint(x: w * 0.5, y: rugY),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )

        // Wall-mounted horizontal wooden dowel with 2 wall pegs supporting the 3 story panels
        let dowelY = h * 0.21
        let dowelRect = CGRect(x: w * 0.22, y: dowelY - 3, width: w * 0.56, height: 6)
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(roundedRect: dowelRect, cornerRadius: 3), bounds: dowelRect, dark: dark, warmth: 0.65, grainLines: 1)
        for pegX in [w * 0.24, w * 0.76] {
            ctx.fill(Path(ellipseIn: CGRect(x: pegX - 4, y: dowelY - 4, width: 8, height: 8)), with: .color(Crayon.caramel))
        }

        let panelXs = [w * 0.32, w * 0.50, w * 0.68]
        let cardW = s * 0.19
        let cardH = s * 0.22
        let cardTopY = dowelY + 12

        // Chronological sequence ribbon drawn across Step 1–2 connecting Panel 1 -> Panel 2 -> Panel 3
        if step >= 1 {
            let seqTrim: CGFloat = step == 1 ? min(1, max(0, CGFloat(p.action))) : 1.0
            var seq = Path()
            seq.move(to: CGPoint(x: panelXs[0], y: cardTopY + cardH * 0.5))
            seq.addLine(to: CGPoint(x: panelXs[1], y: cardTopY + cardH * 0.5))
            seq.addLine(to: CGPoint(x: panelXs[2], y: cardTopY + cardH * 0.5))
            ctx.stroke(
                seq.trimmedPath(from: 0, to: seqTrim),
                with: .color(Palette.amber.opacity(dark ? 0.78 : 0.70)),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [4, 4])
            )
        }

        for (idx, px) in panelXs.enumerated() {
            // Two short hanging linen strings tying each card to the wooden dowel
            for sx in [px - cardW * 0.24, px + cardW * 0.24] {
                var str = Path()
                str.move(to: CGPoint(x: sx, y: dowelY + 3))
                str.addLine(to: CGPoint(x: sx, y: cardTopY))
                ctx.stroke(str, with: .color(Crayon.caramel.opacity(0.60)), lineWidth: 1.1)
            }

            let cRect = CGRect(x: px - cardW * 0.5, y: cardTopY, width: cardW, height: cardH)
            let isLit = (step == 0 && idx == 0) || (step == 1 && p.action * 2.2 >= Double(idx)) || (step == 2 && idx == 2)
            let fillCol = dark ? Color(hex: isLit ? 0x2A3B62 : 0x1D2842) : Color(hex: isLit ? 0xFFFDF8 : 0xF5EEDF)
            PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: px, y: cRect.maxY + 2), rx: cardW * 0.45, ry: 2.5, dark: dark)
            ctx.fill(Path(roundedRect: cRect, cornerRadius: 6), with: .color(fillCol))
            ctx.stroke(
                Path(roundedRect: cRect, cornerRadius: 6),
                with: .color((isLit ? Palette.amber : Crayon.caramel).opacity(isLit ? 0.85 : 0.40)),
                lineWidth: isLit ? 1.8 : 1.0
            )

            // Icon motif per chapter (Sun -> Hill+Kite -> Star+Sprout)
            let mid = CGPoint(x: px, y: cRect.midY)
            if idx == 0 {
                ctx.fill(Path(ellipseIn: CGRect(x: mid.x - 9, y: mid.y - 9, width: 18, height: 18)), with: .color(Crayon.sunflower))
            } else if idx == 1 {
                var hill = Path()
                hill.move(to: CGPoint(x: cRect.minX + 6, y: cRect.maxY - 6))
                hill.addQuadCurve(to: CGPoint(x: cRect.maxX - 6, y: cRect.maxY - 6), control: CGPoint(x: mid.x, y: mid.y - 4))
                ctx.fill(hill, with: .color(Crayon.teal.opacity(0.75)))
                ctx.fill(Path(ellipseIn: CGRect(x: mid.x - 4, y: cRect.minY + 10, width: 8, height: 8)), with: .color(Crayon.tangerine))
            } else {
                // Warm evening cup silhouette + blooming leaf sprout added by Moss in Step 2!
                ctx.fill(Path(roundedRect: CGRect(x: mid.x - 8, y: mid.y, width: 16, height: 12), cornerRadius: 3), with: .color(Crayon.tangerine))
                if step == 2 {
                    let bloom = min(1.0, max(0.0, CGFloat(p.action)))
                    let r = 6.0 * bloom
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: mid.x - r, y: mid.y - 12 - r * 0.5, width: r * 2, height: r * 1.4)),
                        with: .color(Crayon.leaf.opacity(bloom))
                    )
                }
            }
        }

        switch step {
        case 0:
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoVoice,
                to: CGPoint(x: panelXs[0], y: cardTopY + cardH + 6),
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Palette.amber,
                lineWidth: 2.3,
                dark: dark
            )
        case 1:
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: CGPoint(x: panelXs[1], y: cardTopY + cardH * 0.5),
                pulse: p.contact,
                radius: s * 0.10,
                color: Palette.amber
            )
        default:
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: panelXs[2], y: cardTopY + cardH * 0.5),
                baseRadius: s * 0.12,
                progress: p.action,
                tint: Palette.amber,
                dark: dark
            )
            // Teal child reply ribbon travelling back from Moss to Otto!
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: mossEar,
                to: ottoVoice,
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Crayon.teal,
                lineWidth: 2.4,
                dark: dark
            )
        }
    }
}
