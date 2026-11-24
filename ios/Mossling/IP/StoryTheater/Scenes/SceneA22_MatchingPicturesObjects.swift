import SwiftUI

/// A22 (Matching Pictures & Objects · 3 Steps):
/// Botanical matching tabletop flatlay with one cream illustrated pear card and one sculpted wooden pear:
/// Step 0: Single card on left, sculpted wooden pear on right under warm pool ->
/// Step 1: Gentle dotted alignment curve guides the wooden pear sliding beside its matching card ->
/// Step 2: Moss leans in curiously and places the wooden pear into alignment, blooming golden match rings.
struct SceneA22_MatchingPicturesObjects: View {
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
            let groundY = h * 0.86

            let ottoX = w * 0.21
            let mossX = w * 0.78

            let cardCenter = CGPoint(x: w * 0.43, y: groundY - s * 0.04)
            let targetPearPos = CGPoint(x: w * 0.54, y: groundY - s * 0.03)
            let startPearPos = CGPoint(x: w * 0.63, y: groundY - s * 0.03)

            let pearPos: CGPoint = {
                switch step {
                case 0: return startPearPos
                case 1:
                    let t = CGFloat(p.action)
                    return CGPoint(
                        x: startPearPos.x + (targetPearPos.x - startPearPos.x) * t,
                        y: startPearPos.y - CGFloat(sin(Double(t) * .pi)) * s * 0.06
                    )
                default:
                    let t = CGFloat(p.action)
                    return CGPoint(
                        x: startPearPos.x + (targetPearPos.x - startPearPos.x) * t,
                        y: startPearPos.y - CGFloat(sin(Double(t) * .pi)) * s * 0.045
                    )
                }
            }()

            let mossHopLift: CGFloat = (step == 2 && p.raw >= 0.48)
                ? CGFloat(max(0.0, sin((p.raw - 0.48) / 0.34 * .pi))) * ms * 0.08
                : 0
            let ottoLean: Double = step == 1 ? 7.5 * p.action : 3.5
            let mossLean: Double = step == 2 ? -9.5 * p.action : -4.0

            let ottoLook = CGPoint(x: 0.78, y: 0.26)
            let mossLook = CGPoint(x: -0.82, y: 0.30)
            let ottoMood: Mood = step == 2 ? .happy : .open
            let mossMood: Mood = step == 2 ? (p.raw >= 0.44 ? .happy : .wow) : (step == 1 ? .wow : .open)

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
                    drawMatchingTable(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        cardCenter: cardCenter,
                        pearPos: pearPos,
                        targetPearPos: targetPearPos,
                        startPearPos: startPearPos,
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: cardCenter,
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
                    lightDirection: CGPoint(x: 0.72, y: -0.64),
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
                    hopping: step == 2 && mossHopLift > ms * 0.03,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.72, y: -0.64),
                    secondaryLagDegrees: -mossLean * 0.42
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: cardCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawMatchingTable(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        cardCenter: CGPoint,
        pearPos: CGPoint,
        targetPearPos: CGPoint,
        startPearPos: CGPoint,
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
            dayBottom: Color(hex: 0xECE4D0),
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

        // Cream botanical linen matching mat
        let matRect = CGRect(x: w * 0.33, y: groundY - 5, width: w * 0.35, height: 14)
        ctx.fill(
            Path(roundedRect: matRect, cornerRadius: 5),
            with: .color(dark ? Color(hex: 0x263552) : Color(hex: 0xE7DFCA))
        )

        // Botanical picture card on left
        let cardW = s * 0.12
        let cardH = s * 0.14
        let cardRect = CGRect(x: cardCenter.x - cardW * 0.5, y: cardCenter.y - cardH * 0.6, width: cardW, height: cardH)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: cardCenter.x, y: groundY + 2), rx: cardW * 0.5, ry: 4, dark: dark)
        let cardPath = Path(roundedRect: cardRect, cornerRadius: 6)
        ctx.fill(cardPath, with: .color(dark ? Color(hex: 0x2C3859) : Color(hex: 0xFFFDF8)))
        ctx.stroke(cardPath, with: .color(Crayon.leaf.opacity(0.65)), lineWidth: 1.4)

        // Painted golden pear illustration on card
        drawPearShape(
            in: &ctx,
            center: CGPoint(x: cardRect.midX, y: cardRect.midY + 2),
            scale: s * 0.042,
            color: Crayon.sunflower,
            flat: flat,
            dark: dark
        )

        // Subtle dotted alignment path between card & wooden pear
        if step >= 1 {
            var arc = Path()
            arc.move(to: CGPoint(x: startPearPos.x, y: groundY - s * 0.02))
            arc.addQuadCurve(
                to: CGPoint(x: targetPearPos.x, y: groundY - s * 0.02),
                control: CGPoint(x: (startPearPos.x + targetPearPos.x) * 0.5, y: groundY - s * 0.12)
            )
            ctx.stroke(arc, with: .color(Palette.bead.opacity(0.58)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, dash: [3, 4]))
        }

        // Physical sculpted wooden pear object on right
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: pearPos.x, y: groundY + 2), rx: s * 0.045, ry: 4, dark: dark)
        drawPearShape(
            in: &ctx,
            center: pearPos,
            scale: s * 0.052,
            color: Crayon.sunflower,
            flat: flat,
            dark: dark
        )

        if step >= 1 {
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: (cardCenter.x + targetPearPos.x) * 0.5, y: groundY - s * 0.06),
                baseRadius: s * 0.10,
                progress: p.contactEnvelope,
                tint: Crayon.leaf,
                dark: dark
            )
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: targetPearPos,
                pulse: p.contact,
                radius: s * 0.09,
                color: Palette.amber
            )
        }
    }

    private func drawPearShape(
        in ctx: inout GraphicsContext,
        center: CGPoint,
        scale: CGFloat,
        color: Color,
        flat: Bool,
        dark: Bool
    ) {
        var pear = Path()
        pear.addEllipse(in: CGRect(x: center.x - scale * 0.56, y: center.y - scale * 0.25, width: scale * 1.12, height: scale * 0.92))
        pear.addEllipse(in: CGRect(x: center.x - scale * 0.36, y: center.y - scale * 0.68, width: scale * 0.72, height: scale * 0.66))

        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: pear,
                bounds: CGRect(x: center.x - scale, y: center.y - scale, width: scale * 2, height: scale * 2),
                light: color.mix(with: .white, by: 0.22),
                rich: color,
                pencilOutline: (dark ? Color(hex: 0xF5D26B) : Color(hex: 0x6E5512)).opacity(0.65),
                lineWidth: 1.0
            )
        } else {
            ctx.fill(
                pear,
                with: .radialGradient(
                    Gradient(colors: [color.mix(with: .white, by: 0.32), color, color.mix(with: .black, by: 0.18)]),
                    center: CGPoint(x: center.x - scale * 0.2, y: center.y - scale * 0.2),
                    startRadius: 1,
                    endRadius: scale * 1.1
                )
            )
        }
        // Stem & tiny mint leaf
        var stem = Path()
        stem.move(to: CGPoint(x: center.x, y: center.y - scale * 0.64))
        stem.addLine(to: CGPoint(x: center.x + scale * 0.08, y: center.y - scale * 0.90))
        ctx.stroke(stem, with: .color(Color(hex: 0x6D4A27)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        ctx.fill(Path(ellipseIn: CGRect(x: center.x + scale * 0.08, y: center.y - scale * 0.92, width: scale * 0.38, height: scale * 0.22)), with: .color(Crayon.leaf))
    }
}
