import SwiftUI

/// Depth layers allowing props like the peekaboo cloth (`A12`) to pass genuinely in front of actors
/// while play mats sit behind and rings/blocks sit cleanly between Otto and Moss.
enum PropLayer {
    case behindActors
    case betweenActors
    case inFrontOfActors
}

/// Handcrafted Montessori physical prop animator synced to `LivingPhaseSample` across 3D matte-vinyl and 2D flat modes.
struct MontessoriPropRig: View {
    let script: LivingStepScript
    let backdrop: LivingBackdropKind
    let phase: LivingPhaseSample
    let accent: Color
    let dark: Bool
    let flat: Bool
    let layer: PropLayer
    let tapBurstOrigin: CGPoint?
    let tapBurstStrength: Double

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let floorY = PictureBookBackdrop.floorLineY(for: backdrop, in: h)
            let unit = min(w, h)

            switch script.prop {
            case .woodenRing, .rattle:
                if layer == .betweenActors {
                    drawWoodenRingScene(in: &ctx, w: w, h: h, unit: unit, floorY: floorY)
                }
            case .peekCloth:
                if layer == .inFrontOfActors {
                    drawPeekClothScene(in: &ctx, w: w, h: h, unit: unit, floorY: floorY)
                }
            case .chunkyBlocks, .bridgeBlocks:
                if layer == .betweenActors {
                    drawChunkyBlocksScene(in: &ctx, w: w, h: h, unit: unit, floorY: floorY)
                }
            default:
                if layer == .betweenActors {
                    drawFallbackProp(in: &ctx, w: w, h: h, unit: unit, floorY: floorY)
                }
            }

            // Interactive tap-to-replay starburst ripple (drawn in foreground layer only)
            if layer == .inFrontOfActors && tapBurstStrength > 0.01 {
                drawTapBurst(in: &ctx, w: w, h: h)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - A04 Wooden Ring & Secondary Rattle

    private func drawWoodenRingScene(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat, floorY: CGFloat) {
        // Optional wooden rattle resting peacefully on the quilted mat
        if script.secondaryProp == .rattle {
            let rx = w * 0.59
            let ry = floorY - unit * 0.028
            drawMiniRattle(in: &ctx, at: CGPoint(x: rx, y: ry), unit: unit)
        }

        let rOuter = unit * 0.10
        let rInner = rOuter * 0.54
        let cx: CGFloat
        let cy: CGFloat
        let tiltDeg: Double

        switch script.phrase {
        case .offerArc:
            let p0 = CGPoint(x: w * 0.60, y: floorY - unit * 0.44)
            let ctrl = CGPoint(x: w * 0.52, y: floorY - unit * 0.54)
            let p1 = CGPoint(x: w * 0.48, y: floorY - unit * 0.25)
            let t = CGFloat(phase.action)
            cx = (1 - t) * (1 - t) * p0.x + 2 * (1 - t) * t * ctrl.x + t * t * p1.x
            cy = (1 - t) * (1 - t) * p0.y + 2 * (1 - t) * t * ctrl.y + t * t * p1.y - CGFloat(phase.contact * Double(unit) * 0.025)
            tiltDeg = -14.0 * (1.0 - phase.action) + sin(phase.raw * .pi * 2.0) * 4.0

        case .pauseWatch:
            cx = w * 0.47
            cy = floorY - unit * 0.24 - CGFloat(sin(phase.raw * .pi * 2.0) * Double(unit) * 0.014)
            tiltDeg = sin(phase.raw * .pi * 2.0) * 5.0

            // Quiet calm anticipation rings around hovering wooden ring
            let ringR = rOuter * CGFloat(1.38 + 0.35 * sin(phase.raw * .pi * 2.0))
            ctx.stroke(
                Path(ellipseIn: CGRect(x: cx - ringR, y: cy - ringR, width: ringR * 2, height: ringR * 2)),
                with: .color((dark ? Palette.amber : Crayon.teal).opacity(0.28)),
                lineWidth: max(1.2, unit * 0.008)
            )

        case .graspContact:
            let p0 = CGPoint(x: w * 0.47, y: floorY - unit * 0.24)
            let p1 = CGPoint(x: w * 0.435, y: floorY - unit * 0.175)
            let t = CGFloat(phase.action)
            cx = p0.x + (p1.x - p0.x) * t
            cy = p0.y + (p1.y - p0.y) * t - CGFloat(phase.contact * Double(unit) * 0.02)
            tiltDeg = -8.0 * t + sin(phase.followThrough * .pi) * 6.0

            // Contact tactile celebration petals near Moss's side
            if phase.raw >= 0.46 && phase.raw <= 0.80 {
                let p = (phase.raw - 0.46) / 0.34
                let alpha = sin(p * .pi) * 0.90
                drawSparklePetals(in: &ctx, center: CGPoint(x: cx, y: cy - rOuter * 0.6), radius: unit * 0.14 * CGFloat(0.65 + 0.45 * p), alpha: alpha, unit: unit)
            }

        default:
            cx = w * 0.49
            cy = floorY - unit * 0.22
            tiltDeg = 0
        }

        // Dynamic contact shadow on floorY scaled by height
        let heightAboveFloor = max(0, floorY - (cy + rOuter))
        let shadowFactor = max(0.35, 1.0 - heightAboveFloor / (unit * 0.45))
        let sRx = rOuter * 1.15 * shadowFactor
        let sRy = max(2.5, unit * 0.018 * shadowFactor)
        ctx.fill(
            Path(ellipseIn: CGRect(x: cx - sRx, y: floorY - sRy * 0.5, width: sRx * 2, height: sRy * 1.4)),
            with: .color(Color.black.opacity((dark ? 0.34 : 0.15) * shadowFactor))
        )

        // Turned beechwood grasping ring with 3 sensory beads
        var ringCtx = ctx
        ringCtx.translateBy(x: cx, y: cy)
        ringCtx.rotate(by: .degrees(tiltDeg))

        var ringPath = Path()
        ringPath.addEllipse(in: CGRect(x: -rOuter, y: -rOuter, width: rOuter * 2, height: rOuter * 2))
        ringPath.addEllipse(in: CGRect(x: -rInner, y: -rInner, width: rInner * 2, height: rInner * 2))

        let woodTop = dark ? Color(hex: 0xDFB67C) : Color(hex: 0xF5D9A6)
        let woodMid = dark ? Color(hex: 0xBA894E) : Color(hex: 0xDFAF72)
        let woodBot = dark ? Color(hex: 0x8F622F) : Color(hex: 0xB88246)
        ringCtx.fill(
            ringPath,
            with: flat
                ? .color(woodMid)
                : .linearGradient(Gradient(colors: [woodTop, woodMid, woodBot]), startPoint: CGPoint(x: 0, y: -rOuter), endPoint: CGPoint(x: 0, y: rOuter)),
            style: FillStyle(eoFill: true)
        )
        ringCtx.stroke(
            Path(ellipseIn: CGRect(x: -rOuter, y: -rOuter, width: rOuter * 2, height: rOuter * 2)),
            with: .color(woodBot.opacity(0.65)),
            lineWidth: max(0.8, unit * 0.004)
        )

        // Three wooden colored grasp beads along lower rim of the ring
        let midR = (rOuter + rInner) * 0.5
        let beadR = (rOuter - rInner) * 0.56
        let beadColors = [Crayon.teal, Crayon.sunflower, Crayon.pink]
        let angles: [Double] = [1.05, .pi / 2.0, .pi - 1.05]
        for (idx, ang) in angles.enumerated() {
            let bx = CGFloat(cos(ang)) * midR
            let by = CGFloat(sin(ang)) * midR
            let rect = CGRect(x: bx - beadR, y: by - beadR, width: beadR * 2, height: beadR * 2)
            let c = beadColors[idx]
            ringCtx.fill(
                Path(ellipseIn: rect),
                with: flat
                    ? .color(c)
                    : .radialGradient(Gradient(colors: [c.mix(with: .white, by: 0.35), c, c.mix(with: .black, by: 0.16)]), center: CGPoint(x: bx - beadR * 0.3, y: by - beadR * 0.3), startRadius: 0, endRadius: beadR * 1.4)
            )
        }
    }

    private func drawMiniRattle(in ctx: inout GraphicsContext, at pt: CGPoint, unit: CGFloat) {
        let len = unit * 0.14
        var c = ctx
        c.translateBy(x: pt.x, y: pt.y)
        c.rotate(by: .degrees(-12))
        let stick = Path(roundedRect: CGRect(x: -len * 0.5, y: -unit * 0.012, width: len * 0.72, height: unit * 0.024), cornerRadius: unit * 0.012)
        c.fill(stick, with: .color(dark ? Color(hex: 0xAD7D46) : Color(hex: 0xD9A96C)))
        let headR = unit * 0.036
        let headRect = CGRect(x: len * 0.18, y: -headR, width: headR * 2, height: headR * 2)
        c.fill(Path(ellipseIn: headRect), with: .color(Crayon.lilac.opacity(dark ? 0.85 : 0.95)))
    }

    // MARK: - A12 Organic Muslin Peekaboo Cloth

    private func drawPeekClothScene(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat, floorY: CGFloat) {
        let ms = min(w * 0.255, h * 0.365)
        let os = ms * Kind.otto.scale

        let clothW: CGFloat
        let clothH: CGFloat
        let centerX: CGFloat
        let topY: CGFloat
        let tiltDeg: Double
        let foldScaleY: CGFloat

        switch script.phrase {
        case .peekReveal:
            if script.lead == .child {
                // Step 2: Cloth drapes over Moss during Anticipation, then sweeps down & aside beside Moss
                let mossX = w * script.mossAnchorX
                let raisedW = ms * 0.88
                let raisedH = ms * 0.48
                let raisedTop = floorY - ms * 0.50

                let droppedW = ms * 0.74
                let droppedH = ms * 0.26
                let droppedX = w * (script.mossAnchorX + 0.18)
                let droppedTop = floorY - droppedH + 3

                // Hold raised over Moss briefly until u=0.20, then reveal smoothly by u=0.46
                let dropP: Double = phase.raw < 0.20 ? 0.0 : LivingMotionClock.easeOutCubic(min(1.0, (phase.raw - 0.20) / 0.26))
                let settle = sin(phase.followThrough * .pi) * 0.04

                clothW = raisedW + (droppedW - raisedW) * CGFloat(dropP)
                clothH = raisedH + (droppedH - raisedH) * CGFloat(dropP)
                centerX = mossX + (droppedX - mossX) * CGFloat(dropP)
                topY = raisedTop + (droppedTop - raisedTop) * CGFloat(dropP)
                tiltDeg = 14.0 * dropP + 5.0 * sin(dropP * .pi)
                foldScaleY = CGFloat(1.0 - settle)

                if dropP > 0.25 && phase.raw < 0.72 {
                    let trailAlpha = sin(min(1.0, (phase.raw - 0.25) / 0.47) * .pi) * 0.55
                    drawClothSweepTrails(in: &ctx, origin: CGPoint(x: mossX + ms * 0.24, y: topY - unit * 0.04), flip: true, alpha: trailAlpha, unit: unit)
                }

                if phase.raw >= 0.40 && phase.raw <= 0.82 {
                    let p = (phase.raw - 0.40) / 0.42
                    drawSparklePetals(in: &ctx, center: CGPoint(x: mossX, y: floorY - ms * 0.72), radius: unit * 0.15 * CGFloat(0.6 + 0.4 * p), alpha: sin(p * .pi) * 0.90, unit: unit)
                }
            } else {
                // Step 0: Cloth rises over Otto's face (antenna & glowing bead peek over top!), then reveals smiling Otto
                let ottoX = w * script.ottoAnchorX
                let raisedW = os * 0.60
                let raisedH = os * 0.41
                let raisedTop = floorY - os * 0.46

                let droppedW = os * 0.52
                let droppedH = os * 0.25
                let droppedX = w * (script.ottoAnchorX - 0.16)
                let droppedTop = floorY - droppedH + 3

                let riseP = phase.raw < 0.16 ? LivingMotionClock.smoothstep(phase.raw / 0.16) : 1.0
                let dropP: Double = phase.raw < 0.22 ? 0.0 : LivingMotionClock.easeOutCubic(min(1.0, (phase.raw - 0.22) / 0.24))

                let startTop = floorY - os * 0.16
                let activeTop = startTop + (raisedTop - startTop) * CGFloat(riseP)

                clothW = raisedW + (droppedW - raisedW) * CGFloat(dropP)
                let raisedHeightNow = os * 0.16 + (raisedH - os * 0.16) * CGFloat(riseP)
                clothH = raisedHeightNow + (droppedH - raisedHeightNow) * CGFloat(dropP)
                centerX = ottoX + (droppedX - ottoX) * CGFloat(dropP)
                topY = activeTop + (droppedTop - activeTop) * CGFloat(dropP)
                tiltDeg = -14.0 * dropP - 5.0 * sin(dropP * .pi)
                foldScaleY = 1.0

                if dropP > 0.25 && phase.raw < 0.72 {
                    let trailAlpha = sin(min(1.0, (phase.raw - 0.25) / 0.47) * .pi) * 0.55
                    drawClothSweepTrails(in: &ctx, origin: CGPoint(x: ottoX - os * 0.22, y: topY - unit * 0.04), flip: false, alpha: trailAlpha, unit: unit)
                }

                if phase.raw >= 0.40 && phase.raw <= 0.82 {
                    let p = (phase.raw - 0.40) / 0.42
                    drawSparklePetals(in: &ctx, center: CGPoint(x: ottoX - os * 0.04, y: floorY - os * 0.68), radius: unit * 0.15 * CGFloat(0.6 + 0.4 * p), alpha: sin(p * .pi) * 0.90, unit: unit)
                }
            }

        case .gentleSway:
            // Step 1: Cloth floats softly beside Otto while warm vocal sound arcs ripple gently toward Moss
            let sway = sin(phase.raw * .pi * 2.0)
            clothW = os * 0.48
            clothH = os * 0.16
            centerX = w * (script.ottoAnchorX - 0.16) + CGFloat(sway * Double(unit) * 0.015)
            topY = floorY - clothH - CGFloat(max(0, sway) * Double(unit) * 0.018) + 2
            tiltDeg = sway * 5.0
            foldScaleY = 1.0

            // Delicate gentle vocal arcs between Otto and Moss
            let arcCenter = CGPoint(x: w * 0.51, y: floorY - os * 0.32)
            for i in 0..<2 {
                let p = (phase.raw + Double(i) * 0.45).truncatingRemainder(dividingBy: 1.0)
                let arcR = unit * CGFloat(0.08 + p * 0.14)
                var arc = Path()
                arc.addArc(center: arcCenter, radius: arcR, startAngle: .degrees(145), endAngle: .degrees(215), clockwise: false)
                ctx.stroke(
                    arc,
                    with: .color((dark ? Palette.amber : Crayon.pink).opacity((1.0 - p) * 0.55)),
                    style: StrokeStyle(lineWidth: max(1.4, unit * 0.008), lineCap: .round)
                )
            }

        default:
            return
        }

        drawMuslinCloth(
            in: &ctx,
            centerX: centerX,
            topY: topY,
            width: clothW,
            height: clothH,
            tiltDeg: tiltDeg,
            scaleY: foldScaleY,
            unit: unit
        )
    }

    private func drawMuslinCloth(
        in ctx: inout GraphicsContext,
        centerX: CGFloat,
        topY: CGFloat,
        width: CGFloat,
        height: CGFloat,
        tiltDeg: Double,
        scaleY: CGFloat,
        unit: CGFloat
    ) {
        var c = ctx
        c.translateBy(x: centerX, y: topY + height * 0.5)
        c.rotate(by: .degrees(tiltDeg))
        c.scaleBy(x: 1.0, y: scaleY)

        let hw = width * 0.5
        let hh = height * 0.5

        // Soft cast shadow beneath cloth
        if !flat {
            var shadow = Path()
            shadow.addRoundedRect(in: CGRect(x: -hw + 1, y: -hh + 3, width: width, height: height), cornerSize: CGSize(width: 8, height: 8))
            c.fill(shadow, with: .color(.black.opacity(dark ? 0.28 : 0.10)))
        }

        // Organic scalloped cloth silhouette
        var cloth = Path()
        cloth.move(to: CGPoint(x: -hw * 0.88, y: -hh))
        cloth.addQuadCurve(to: CGPoint(x: hw * 0.88, y: -hh), control: CGPoint(x: 0, y: -hh - height * 0.12))
        cloth.addQuadCurve(to: CGPoint(x: hw, y: hh * 0.86), control: CGPoint(x: hw * 1.06, y: 0))
        cloth.addQuadCurve(to: CGPoint(x: 0, y: hh * 0.92), control: CGPoint(x: hw * 0.48, y: hh * 1.15))
        cloth.addQuadCurve(to: CGPoint(x: -hw, y: hh * 0.86), control: CGPoint(x: -hw * 0.48, y: hh * 1.15))
        cloth.addQuadCurve(to: CGPoint(x: -hw * 0.88, y: -hh), control: CGPoint(x: -hw * 1.06, y: 0))
        cloth.closeSubpath()

        let base1 = dark ? Color(hex: 0xDDD0BC) : Color(hex: 0xFBF2E3)
        let base2 = dark ? Color(hex: 0xBEB09B) : Color(hex: 0xEEDEC6)
        c.fill(
            cloth,
            with: flat
                ? .color(base1)
                : .linearGradient(Gradient(colors: [base1, base2]), startPoint: CGPoint(x: 0, y: -hh), endPoint: CGPoint(x: 0, y: hh))
        )

        var clipped = c
        clipped.clip(to: cloth)
        let stripeColor = (dark ? Crayon.peach : Crayon.pink).opacity(dark ? 0.34 : 0.30)
        for offset in [-0.24, 0.24] as [CGFloat] {
            var stripe = Path()
            let sy = height * offset
            stripe.move(to: CGPoint(x: -hw * 1.1, y: sy))
            stripe.addQuadCurve(to: CGPoint(x: hw * 1.1, y: sy), control: CGPoint(x: 0, y: sy + height * 0.08))
            clipped.stroke(stripe, with: .color(stripeColor), lineWidth: max(1.5, unit * 0.012))
        }

        c.stroke(cloth, with: .color(dark ? Color.white.opacity(0.18) : Color(hex: 0xD1BD9F)), lineWidth: max(0.8, unit * 0.005))
    }

    private func drawClothSweepTrails(in ctx: inout GraphicsContext, origin: CGPoint, flip: Bool, alpha: Double, unit: CGFloat) {
        let dir: CGFloat = flip ? 1 : -1
        let trailColor = (dark ? Palette.amber : Crayon.pink).opacity(alpha)
        for i in 0..<2 {
            let dy = CGFloat(i) * unit * 0.045
            let dx = CGFloat(i) * dir * unit * 0.025
            var arc = Path()
            arc.move(to: CGPoint(x: origin.x + dx, y: origin.y - unit * 0.09 - dy))
            arc.addQuadCurve(
                to: CGPoint(x: origin.x + dx + dir * unit * 0.075, y: origin.y - dy),
                control: CGPoint(x: origin.x + dx + dir * unit * 0.065, y: origin.y - unit * 0.06 - dy)
            )
            ctx.stroke(arc, with: .color(trailColor), style: StrokeStyle(lineWidth: max(1.2, unit * 0.007), lineCap: .round))
        }
    }

    // MARK: - A19 Chunky Montessori Wooden Blocks

    private func drawChunkyBlocksScene(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat, floorY: CGFloat) {
        let blockSize = unit * 0.145
        let baseCenterX = w * 0.50
        let skyY = floorY - blockSize * 0.5

        switch script.phrase {
        case .liftStack:
            if script.lead == .child {
                // Step 1: Sky + Sunflower already stacked (Object Continuity); Cherry lifts from Moss's side onto top!
                drawBlock(in: &ctx, center: CGPoint(x: baseCenterX, y: skyY), size: blockSize, color: Crayon.sky, angle: 0, shadowFloorY: floorY)
                drawBlock(in: &ctx, center: CGPoint(x: baseCenterX, y: skyY - blockSize), size: blockSize, color: Crayon.sunflower, angle: 0, shadowFloorY: nil)

                let p0 = CGPoint(x: w * 0.38, y: floorY - blockSize * 0.55)
                let ctrl = CGPoint(x: w * 0.42, y: skyY - blockSize * 2.85)
                let p1 = CGPoint(x: baseCenterX, y: skyY - blockSize * 2.0)
                let t = CGFloat(phase.action)
                let cx = (1 - t) * (1 - t) * p0.x + 2 * (1 - t) * t * ctrl.x + t * t * p1.x
                let cy = (1 - t) * (1 - t) * p0.y + 2 * (1 - t) * t * ctrl.y + t * t * p1.y + CGFloat(phase.contact * Double(blockSize) * 0.08)
                let wobble = (1.0 - phase.contactEnvelope) * sin(phase.action * .pi * 2.0) * 6.0
                drawBlock(in: &ctx, center: CGPoint(x: cx, y: cy), size: blockSize, color: Crayon.cherry, angle: wobble, shadowFloorY: nil)

                if phase.raw >= 0.46 && phase.raw <= 0.72 {
                    let p = (phase.raw - 0.46) / 0.26
                    drawWoodTapRing(in: &ctx, at: CGPoint(x: baseCenterX, y: skyY - blockSize * 1.5), progress: p, unit: unit)
                }
            } else {
                // Step 0: Sky anchored; Sunflower lifts smoothly from Otto's side and lands on Sky block
                drawBlock(in: &ctx, center: CGPoint(x: baseCenterX, y: skyY), size: blockSize, color: Crayon.sky, angle: 0, shadowFloorY: floorY)

                let p0 = CGPoint(x: w * 0.62, y: floorY - blockSize * 0.55)
                let ctrl = CGPoint(x: w * 0.58, y: skyY - blockSize * 1.95)
                let p1 = CGPoint(x: baseCenterX, y: skyY - blockSize)
                let t = CGFloat(phase.action)
                let cx = (1 - t) * (1 - t) * p0.x + 2 * (1 - t) * t * ctrl.x + t * t * p1.x
                let cy = (1 - t) * (1 - t) * p0.y + 2 * (1 - t) * t * ctrl.y + t * t * p1.y + CGFloat(phase.contact * Double(blockSize) * 0.08)
                let tilt = -8.0 * (1.0 - phase.action)
                drawBlock(in: &ctx, center: CGPoint(x: cx, y: cy), size: blockSize, color: Crayon.sunflower, angle: tilt, shadowFloorY: nil)

                if phase.raw >= 0.46 && phase.raw <= 0.72 {
                    let p = (phase.raw - 0.46) / 0.26
                    drawWoodTapRing(in: &ctx, at: CGPoint(x: baseCenterX, y: skyY - blockSize * 0.5), progress: p, unit: unit)
                }
            }

        case .tumbleCheer:
            // Step 2: 3-block tower wobbles gently during Anticipation, tumbles cleanly during Action, sparks at Contact!
            let antSway = phase.raw < 0.16 ? sin(phase.anticipation * .pi * 3.0) : 0.0
            let act = phase.action
            let bounce = phase.contact * 0.10

            // Base Sky block settles firmly on floor
            let skyTilt = antSway * 2.0 - 4.0 * sin(act * .pi)
            drawBlock(in: &ctx, center: CGPoint(x: baseCenterX, y: skyY), size: blockSize, color: Crayon.sky, angle: skyTilt, shadowFloorY: floorY)

            // Sunflower middle block arcs cleanly leftwards to floorY
            let sunStart = CGPoint(x: baseCenterX, y: skyY - blockSize)
            let sunCtrl = CGPoint(x: w * 0.44, y: skyY - blockSize * 1.45)
            let sunEnd = CGPoint(x: w * 0.40, y: skyY)
            let st = CGFloat(act)
            let sunX = (1 - st) * (1 - st) * sunStart.x + 2 * (1 - st) * st * sunCtrl.x + st * st * sunEnd.x + CGFloat(antSway * 2.0)
            let sunY = (1 - st) * (1 - st) * sunStart.y + 2 * (1 - st) * st * sunCtrl.y + st * st * sunEnd.y - CGFloat(bounce * Double(blockSize))
            let sunAng = antSway * 4.0 - 24.0 * act
            drawBlock(in: &ctx, center: CGPoint(x: sunX, y: sunY), size: blockSize, color: Crayon.sunflower, angle: sunAng, shadowFloorY: act > 0.7 ? floorY : nil)

            // Cherry top block arcs cleanly rightwards to floorY
            let chStart = CGPoint(x: baseCenterX, y: skyY - blockSize * 2.0)
            let chCtrl = CGPoint(x: w * 0.57, y: skyY - blockSize * 2.25)
            let chEnd = CGPoint(x: w * 0.61, y: skyY)
            let chX = (1 - st) * (1 - st) * chStart.x + 2 * (1 - st) * st * chCtrl.x + st * st * chEnd.x + CGFloat(antSway * 4.5)
            let chY = (1 - st) * (1 - st) * chStart.y + 2 * (1 - st) * st * chCtrl.y + st * st * chEnd.y - CGFloat(bounce * Double(blockSize) * 1.4)
            let chAng = antSway * 8.0 + 38.0 * act
            drawBlock(in: &ctx, center: CGPoint(x: chX, y: chY), size: blockSize, color: Crayon.cherry, angle: chAng, shadowFloorY: act > 0.7 ? floorY : nil)

            if phase.raw >= 0.44 && phase.raw <= 0.84 {
                let p = (phase.raw - 0.44) / 0.40
                drawSparklePetals(in: &ctx, center: CGPoint(x: baseCenterX, y: skyY - blockSize * 1.2), radius: unit * 0.17 * CGFloat(0.6 + 0.45 * p), alpha: sin(p * .pi) * 0.92, unit: unit)
            }

        default:
            drawBlock(in: &ctx, center: CGPoint(x: baseCenterX, y: skyY), size: blockSize, color: Crayon.sky, angle: 0, shadowFloorY: floorY)
            drawBlock(in: &ctx, center: CGPoint(x: baseCenterX, y: skyY - blockSize), size: blockSize, color: Crayon.sunflower, angle: 0, shadowFloorY: nil)
        }
    }

    private func drawBlock(
        in ctx: inout GraphicsContext,
        center: CGPoint,
        size s: CGFloat,
        color: Color,
        angle: Double,
        shadowFloorY: CGFloat?
    ) {
        if let floorY = shadowFloorY {
            let sr = s * 0.62
            ctx.fill(
                Path(ellipseIn: CGRect(x: center.x - sr, y: floorY - 2, width: sr * 2, height: max(4, s * 0.18))),
                with: .color(Color.black.opacity(dark ? 0.34 : 0.14))
            )
        }

        var c = ctx
        c.translateBy(x: center.x, y: center.y)
        c.rotate(by: .degrees(angle))

        let rect = CGRect(x: -s * 0.5, y: -s * 0.5, width: s, height: s)
        let corner = s * 0.18
        let path = Path(roundedRect: rect, cornerRadius: corner)

        let topC = color.mix(with: .white, by: dark ? 0.10 : 0.22)
        let botC = color.mix(with: .black, by: dark ? 0.24 : 0.12)
        c.fill(
            path,
            with: flat
                ? .color(color)
                : .linearGradient(Gradient(colors: [topC, color, botC]), startPoint: CGPoint(x: -s * 0.3, y: -s * 0.5), endPoint: CGPoint(x: s * 0.4, y: s * 0.5))
        )

        if !flat {
            c.stroke(
                path,
                with: .linearGradient(Gradient(colors: [.white.opacity(dark ? 0.22 : 0.60), .clear]), startPoint: CGPoint(x: 0, y: -s * 0.5), endPoint: CGPoint(x: 0, y: s * 0.5)),
                lineWidth: max(0.8, s * 0.04)
            )
        }

        // Tactile warm birch peg dot on block center
        let dotR = s * 0.16
        c.fill(
            Path(ellipseIn: CGRect(x: -dotR, y: -dotR, width: dotR * 2, height: dotR * 2)),
            with: .color(Color(hex: dark ? 0xE6D3B1 : 0xFAF0DE).opacity(0.92))
        )
    }

    // MARK: - Fallback Props & Tactile Feedback

    private func drawFallbackProp(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat, floorY: CGFloat) {
        let cx = w * 0.50
        let r = unit * 0.08
        let cy = floorY - r - CGFloat(phase.contact * Double(unit) * 0.03)
        let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(accent))
    }

    private func drawWoodTapRing(in ctx: inout GraphicsContext, at pt: CGPoint, progress p: Double, unit: CGFloat) {
        let r = unit * CGFloat(0.06 + p * 0.10)
        ctx.stroke(
            Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r * 0.45, width: r * 2, height: r * 0.9)),
            with: .color(Palette.beadLight.opacity((1.0 - p) * 0.72)),
            lineWidth: max(1.2, unit * 0.008)
        )
    }

    private func drawSparklePetals(in ctx: inout GraphicsContext, center: CGPoint, radius: CGFloat, alpha: Double, unit: CGFloat) {
        let colors = [Palette.bead, Crayon.mint, Crayon.sunflower, Crayon.sky, Crayon.pink]
        let r = max(1.6, unit * 0.015)
        for i in 0..<5 {
            let ang = Double(i) * (.pi * 2.0 / 5.0) - .pi / 2.0
            let sx = center.x + CGFloat(cos(ang)) * radius
            let sy = center.y + CGFloat(sin(ang)) * radius * 0.72
            ctx.fill(
                Path(ellipseIn: CGRect(x: sx - r, y: sy - r, width: r * 2, height: r * 2)),
                with: .color(colors[i % colors.count].opacity(alpha))
            )
        }
    }

    private func drawTapBurst(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat) {
        let origin = tapBurstOrigin ?? CGPoint(x: 0.50, y: 0.52)
        let px = w * min(0.90, max(0.10, origin.x))
        let py = h * min(0.86, max(0.14, origin.y))
        let prog = 1.0 - tapBurstStrength
        let pr = min(w, h) * CGFloat(0.05 + prog * 0.16)
        ctx.stroke(
            Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
            with: .color(Palette.bead.opacity(tapBurstStrength * 0.80)),
            lineWidth: max(1.5, min(w, h) * 0.01)
        )
        let colors = [Palette.bead, Crayon.mint, Crayon.sky, Crayon.pink]
        let dist = min(w, h) * CGFloat(0.03 + prog * 0.11)
        let dotR = max(1.5, min(w, h) * 0.012 * CGFloat(tapBurstStrength + 0.2))
        for i in 0..<4 {
            let a = CGFloat(i) * (.pi * 0.5) - .pi * 0.25 + CGFloat(prog * 0.4)
            let bx = px + cos(a) * dist
            let by = py + sin(a) * dist
            ctx.fill(
                Path(ellipseIn: CGRect(x: bx - dotR, y: by - dotR, width: dotR * 2, height: dotR * 2)),
                with: .color(colors[i].opacity(tapBurstStrength * 0.90))
            )
        }
    }
}
