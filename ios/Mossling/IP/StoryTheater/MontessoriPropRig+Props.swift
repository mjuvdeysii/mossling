import SwiftUI

/// Bespoke tactile Montessori physical prop renderers completing all 16 `LivingPropKind` scenes
/// across Daylight 3D matte-vinyl, Dark/Lamp 3D, and 2D flat cut-paper modes.
extension MontessoriPropRig {

    // MARK: - Shared Mini & Tactile Shapes

    func drawStitchedBall(in ctx: inout GraphicsContext, center: CGPoint, radius r: CGFloat, angleDeg: Double, shadowFloorY: CGFloat?) {
        if let floorY = shadowFloorY {
            let heightAbove = max(0, floorY - (center.y + r))
            let factor = max(0.35, 1.0 - heightAbove / (r * 3.5))
            drawFloorShadow(in: &ctx, x: center.x, floorY: floorY, rx: r * 1.05, ry: r * 0.25, factor: factor)
        }

        var c = ctx
        c.translateBy(x: center.x, y: center.y)
        c.rotate(by: .degrees(angleDeg))

        let circle = Path(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2))
        let base = Crayon.teal
        c.fill(
            circle,
            with: flat
                ? .color(base)
                : .radialGradient(
                    Gradient(colors: [base.mix(with: .white, by: 0.30), base, base.mix(with: .black, by: 0.18)]),
                    center: CGPoint(x: -r * 0.30, y: -r * 0.32),
                    startRadius: 1,
                    endRadius: r * 1.35
                )
        )

        var clipped = c
        clipped.clip(to: circle)
        // Contrasting warm coral & sunflower cloth patches
        let patchA = Path(ellipseIn: CGRect(x: -r * 1.15, y: -r * 0.55, width: r * 0.95, height: r * 1.10))
        let patchB = Path(ellipseIn: CGRect(x: r * 0.22, y: -r * 0.55, width: r * 0.95, height: r * 1.10))
        clipped.fill(patchA, with: .color(Crayon.peach.opacity(dark ? 0.85 : 0.94)))
        clipped.fill(patchB, with: .color(Crayon.sunflower.opacity(dark ? 0.82 : 0.92)))

        // Delicate stitched seam arcs
        let seamColor = Color(hex: dark ? 0xFFF4DF : 0x6E5233).opacity(0.45)
        for dx in [-r * 0.26, r * 0.26] {
            var seam = Path()
            seam.move(to: CGPoint(x: dx, y: -r))
            seam.addQuadCurve(to: CGPoint(x: dx, y: r), control: CGPoint(x: dx * 1.65, y: 0))
            clipped.stroke(seam, with: .color(seamColor), style: StrokeStyle(lineWidth: max(0.8, r * 0.08), dash: [2.5, 2.5]))
        }

        c.stroke(circle, with: .color(dark ? .white.opacity(0.18) : base.mix(with: .black, by: 0.22).opacity(0.45)), lineWidth: max(0.9, r * 0.06))
    }

    func drawMiniWoodenRing(in ctx: inout GraphicsContext, center: CGPoint, unit: CGFloat) {
        let rOut = unit * 0.055
        let rIn = rOut * 0.52
        var ring = Path()
        ring.addEllipse(in: CGRect(x: center.x - rOut, y: center.y - rOut, width: rOut * 2, height: rOut * 2))
        ring.addEllipse(in: CGRect(x: center.x - rIn, y: center.y - rIn, width: rIn * 2, height: rIn * 2))
        ctx.fill(ring, with: .color(dark ? Color(hex: 0xC6975B) : Color(hex: 0xE7B97E)), style: FillStyle(eoFill: true))
    }

    func drawMiniWoodBasket(in ctx: inout GraphicsContext, center: CGPoint, unit: CGFloat) {
        let w = unit * 0.15
        let h = unit * 0.075
        var bowl = Path()
        bowl.move(to: CGPoint(x: center.x - w * 0.5, y: center.y - h * 0.45))
        bowl.addLine(to: CGPoint(x: center.x + w * 0.5, y: center.y - h * 0.45))
        bowl.addQuadCurve(to: CGPoint(x: center.x + w * 0.34, y: center.y + h * 0.55), control: CGPoint(x: center.x + w * 0.52, y: center.y + h * 0.2))
        bowl.addLine(to: CGPoint(x: center.x - w * 0.34, y: center.y + h * 0.55))
        bowl.addQuadCurve(to: CGPoint(x: center.x - w * 0.5, y: center.y - h * 0.45), control: CGPoint(x: center.x - w * 0.52, y: center.y + h * 0.2))
        bowl.closeSubpath()
        ctx.fill(bowl, with: .color(dark ? Color(hex: 0xA87A45) : Color(hex: 0xD6A76C)))
    }

    // MARK: - 1. Wooden Rattle (A11 Hand-to-Hand Passing)

    func drawRattleScene(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat, floorY: CGFloat) {
        if script.secondaryProp == .woodenRing {
            drawMiniWoodenRing(in: &ctx, center: CGPoint(x: w * 0.61, y: floorY - unit * 0.048), unit: unit)
        }

        let cx: CGFloat
        let cy: CGFloat
        let tiltDeg: Double

        switch script.phrase {
        case .offerArc:
            let t = CGFloat(phase.action)
            let p0 = CGPoint(x: w * 0.60, y: floorY - unit * 0.34)
            let ctrl = CGPoint(x: w * 0.52, y: floorY - unit * 0.46)
            let p1 = CGPoint(x: w * 0.48, y: floorY - unit * 0.24)
            cx = (1 - t) * (1 - t) * p0.x + 2 * (1 - t) * t * ctrl.x + t * t * p1.x
            cy = (1 - t) * (1 - t) * p0.y + 2 * (1 - t) * t * ctrl.y + t * t * p1.y
            tiltDeg = -18.0 + sin(phase.raw * .pi * 4.0) * 10.0

        case .graspContact:
            // Crosses midline smoothly from right to left side
            let swing = sin(phase.action * .pi)
            cx = w * (0.54 - 0.12 * CGFloat(phase.action))
            cy = floorY - unit * 0.22 - CGFloat(swing * Double(unit) * 0.06)
            tiltDeg = -22.0 + sin(phase.raw * .pi * 6.0) * 14.0
            if phase.raw >= 0.42 && phase.raw <= 0.80 {
                let p = (phase.raw - 0.42) / 0.38
                drawSparklePetals(in: &ctx, center: CGPoint(x: cx, y: cy - unit * 0.08), radius: unit * 0.13 * CGFloat(0.6 + 0.4 * p), alpha: sin(p * .pi) * 0.85, unit: unit)
            }

        default:
            cx = w * 0.46
            cy = floorY - unit * 0.20 - CGFloat(sin(phase.raw * .pi * 2.0) * Double(unit) * 0.015)
            tiltDeg = -12.0 + sin(phase.raw * .pi * 4.0) * 7.0
        }

        drawFloorShadow(in: &ctx, x: cx, floorY: floorY, rx: unit * 0.09, ry: unit * 0.018, factor: 0.75)

        var c = ctx
        c.translateBy(x: cx, y: cy)
        c.rotate(by: .degrees(tiltDeg))

        // Turned birch handle
        let handle = Path(roundedRect: CGRect(x: -unit * 0.10, y: -unit * 0.016, width: unit * 0.14, height: unit * 0.032), cornerRadius: unit * 0.016)
        let woodTop = dark ? Color(hex: 0xDFB67C) : Color(hex: 0xF5D9A6)
        let woodBot = dark ? Color(hex: 0x996B35) : Color(hex: 0xC68E51)
        c.fill(handle, with: flat ? .color(woodTop) : .linearGradient(Gradient(colors: [woodTop, woodBot]), startPoint: CGPoint(x: 0, y: -unit * 0.02), endPoint: CGPoint(x: 0, y: unit * 0.02)))

        // Painted rattle head with 3 wood-bead spots
        let headR = unit * 0.056
        let headCenter = CGPoint(x: unit * 0.058, y: 0)
        let headRect = CGRect(x: headCenter.x - headR, y: headCenter.y - headR, width: headR * 2, height: headR * 2)
        c.fill(
            Path(ellipseIn: headRect),
            with: flat
                ? .color(Crayon.lilac)
                : .radialGradient(Gradient(colors: [Crayon.lilac.mix(with: .white, by: 0.32), Crayon.lilac, Crayon.lilac.mix(with: .black, by: 0.16)]), center: CGPoint(x: headCenter.x - headR * 0.3, y: -headR * 0.3), startRadius: 1, endRadius: headR * 1.4)
        )
        let dotR = headR * 0.20
        for (dx, dy, col) in [(-0.28, -0.22, Palette.beadLight), (0.28, -0.15, Crayon.mint), (0.04, 0.30, Crayon.peach)] as [(CGFloat, CGFloat, Color)] {
            c.fill(Path(ellipseIn: CGRect(x: headCenter.x + dx * headR - dotR, y: dy * headR - dotR, width: dotR * 2, height: dotR * 2)), with: .color(col))
        }
    }

    // MARK: - 2. Stitched Soft Cloth Ball (A03, A18, A32)

    func drawSoftBallScene(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat, floorY: CGFloat) {
        if script.secondaryProp == .mat {
            let cushion = Path(roundedRect: CGRect(x: w * 0.25, y: floorY - unit * 0.032, width: w * 0.20, height: unit * 0.035), cornerRadius: unit * 0.017)
            ctx.fill(cushion, with: .color((dark ? Crayon.lilac : Crayon.peach).opacity(0.42)))
        }

        let r = unit * 0.088
        let cx: CGFloat
        let cy: CGFloat
        let rollAngle: Double

        switch script.phrase {
        case .offerArc:
            let t = CGFloat(phase.action)
            cx = w * (0.61 - 0.16 * t)
            cy = floorY - r - CGFloat(sin(Double(t) * .pi) * Double(unit) * 0.018)
            rollAngle = -Double(t) * 160.0
        case .graspContact:
            // Ball rolls gently toward Moss and nudges back
            let osc = sin(phase.action * .pi)
            cx = w * (0.48 - 0.09 * CGFloat(osc))
            cy = floorY - r - CGFloat(phase.contact * Double(unit) * 0.025)
            rollAngle = -osc * 130.0
            if phase.raw >= 0.44 && phase.raw <= 0.78 {
                let p = (phase.raw - 0.44) / 0.34
                drawSparklePetals(in: &ctx, center: CGPoint(x: cx, y: cy - r * 1.25), radius: unit * 0.12 * CGFloat(0.6 + 0.4 * p), alpha: sin(p * .pi) * 0.85, unit: unit)
            }
        case .soundRipple:
            let rock = sin(phase.raw * .pi * 2.0)
            cx = w * 0.49 + CGFloat(rock * Double(unit) * 0.02)
            cy = floorY - r
            rollAngle = rock * 14.0
            drawSoundArcs(in: &ctx, origin: CGPoint(x: w * 0.54, y: floorY - unit * 0.26), facingLeft: true, unit: unit, tint: dark ? Palette.amber : Crayon.teal)
        default:
            let rock = sin(phase.raw * .pi * 2.0)
            cx = w * 0.48 + CGFloat(rock * Double(unit) * 0.012)
            cy = floorY - r
            rollAngle = rock * 10.0
        }

        drawStitchedBall(in: &ctx, center: CGPoint(x: cx, y: cy), radius: r, angleDeg: rollAngle, shadowFloorY: floorY)
    }

    // MARK: - 3. Beechwood Tabletop Mirror (N02, A09, A38)

    func drawMirrorScene(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat, floorY: CGFloat) {
        let mw = unit * 0.22
        let mh = unit * 0.27
        let sway = sin(phase.raw * .pi * 2.0) * 1.8
        let cx = w * 0.50
        let cy = floorY - mh * 0.52 - CGFloat(phase.contact * Double(unit) * 0.01)

        drawFloorShadow(in: &ctx, x: cx, floorY: floorY, rx: mw * 0.56, ry: unit * 0.020)

        // Easel wooden back support leg
        var leg = Path()
        leg.move(to: CGPoint(x: cx + mw * 0.16, y: cy))
        leg.addLine(to: CGPoint(x: cx + mw * 0.42, y: floorY - 1))
        ctx.stroke(leg, with: .color(dark ? Color(hex: 0x8F622F) : Color(hex: 0xBA8246)), style: StrokeStyle(lineWidth: max(3, unit * 0.018), lineCap: .round))

        var c = ctx
        c.translateBy(x: cx, y: cy)
        c.rotate(by: .degrees(sway))

        let frameRect = CGRect(x: -mw * 0.5, y: -mh * 0.5, width: mw, height: mh)
        let framePath = Path(roundedRect: frameRect, cornerSize: CGSize(width: mw * 0.48, height: mw * 0.48))
        let woodTop = dark ? Color(hex: 0xD8AE74) : Color(hex: 0xF2D19C)
        let woodBot = dark ? Color(hex: 0x996B35) : Color(hex: 0xC68E51)
        c.fill(framePath, with: flat ? .color(woodTop) : .linearGradient(Gradient(colors: [woodTop, woodBot]), startPoint: CGPoint(x: 0, y: -mh * 0.5), endPoint: CGPoint(x: 0, y: mh * 0.5)))

        let glassRect = frameRect.insetBy(dx: mw * 0.11, dy: mw * 0.11)
        let glassPath = Path(roundedRect: glassRect, cornerSize: CGSize(width: glassRect.width * 0.48, height: glassRect.width * 0.48))
        let g1 = dark ? Color(hex: 0x33477A) : Color(hex: 0xE2F3FB)
        let g2 = dark ? Color(hex: 0x202D56) : Color(hex: 0xC4E3F4)
        c.fill(glassPath, with: flat ? .color(g1) : .linearGradient(Gradient(colors: [g1, g2]), startPoint: CGPoint(x: -mw * 0.3, y: -mh * 0.4), endPoint: CGPoint(x: mw * 0.3, y: mh * 0.4)))

        var clipped = c
        clipped.clip(to: glassPath)
        // Diagonal specular sheen sweeping gently with phase
        let sheenShift = CGFloat((phase.action - 0.5) * Double(mw) * 0.45)
        var sheen = Path()
        sheen.move(to: CGPoint(x: -mw * 0.45 + sheenShift, y: mh * 0.55))
        sheen.addLine(to: CGPoint(x: mw * 0.25 + sheenShift, y: -mh * 0.55))
        sheen.addLine(to: CGPoint(x: mw * 0.45 + sheenShift, y: -mh * 0.55))
        sheen.addLine(to: CGPoint(x: -mw * 0.25 + sheenShift, y: mh * 0.55))
        sheen.closeSubpath()
        clipped.fill(sheen, with: .color(.white.opacity(dark ? 0.16 : 0.42)))

        // Two warm silhouette reflections inside mirror (Moss mint & Otto amber)
        let rMini = mw * 0.14
        clipped.fill(Path(ellipseIn: CGRect(x: -mw * 0.20, y: mh * 0.08, width: rMini * 1.7, height: rMini * 1.7)), with: .color(Palette.mint.opacity(0.65)))
        clipped.fill(Path(ellipseIn: CGRect(x: mw * 0.02, y: mh * 0.02, width: rMini * 1.9, height: rMini * 2.1)), with: .color(Palette.amber.opacity(0.55)))

        c.stroke(glassPath, with: .color(dark ? .white.opacity(0.20) : .white.opacity(0.75)), lineWidth: max(0.8, unit * 0.005))

        if script.secondaryProp == .pictureBook {
            drawMiniClosedBook(in: &ctx, center: CGPoint(x: w * 0.36, y: floorY - unit * 0.025), unit: unit)
        }
        if script.phrase == .soundRipple {
            drawSoundArcs(in: &ctx, origin: CGPoint(x: cx, y: cy - mh * 0.58), facingLeft: true, unit: unit, tint: dark ? Palette.amber : Crayon.sky)
        }
    }

    private func drawMiniClosedBook(in ctx: inout GraphicsContext, center: CGPoint, unit: CGFloat) {
        let bw = unit * 0.12
        let bh = unit * 0.036
        ctx.fill(Path(roundedRect: CGRect(x: center.x - bw * 0.5, y: center.y - bh * 0.5, width: bw, height: bh), cornerRadius: 4), with: .color(Crayon.caramel.opacity(0.85)))
    }

    // MARK: - 4. Birchwood Bowl & Beads (A14, A28)

    func drawWoodCupScene(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat, floorY: CGFloat) {
        let bowlX = w * 0.50
        let bowlW = unit * 0.22
        let bowlH = unit * 0.11
        let bowlY = floorY - bowlH * 0.52

        drawFloorShadow(in: &ctx, x: bowlX, floorY: floorY, rx: bowlW * 0.44, ry: unit * 0.018)

        let beadR = unit * 0.028
        switch script.phrase {
        case .liftStack:
            // Wooden bead arcs cleanly into the birchwood bowl (A14 / A28)
            let p0 = CGPoint(x: w * 0.62, y: floorY - unit * 0.28)
            let ctrl = CGPoint(x: w * 0.56, y: floorY - unit * 0.38)
            let p1 = CGPoint(x: bowlX, y: bowlY - bowlH * 0.18)
            let t = CGFloat(phase.action)
            let bx = (1 - t) * (1 - t) * p0.x + 2 * (1 - t) * t * ctrl.x + t * t * p1.x
            let by = (1 - t) * (1 - t) * p0.y + 2 * (1 - t) * t * ctrl.y + t * t * p1.y
            ctx.fill(Path(ellipseIn: CGRect(x: bx - beadR, y: by - beadR, width: beadR * 2, height: beadR * 2)), with: .color(Crayon.teal))
            if phase.raw >= 0.46 && phase.raw <= 0.72 {
                drawWoodTapRing(in: &ctx, at: CGPoint(x: bowlX, y: bowlY - bowlH * 0.35), progress: (phase.raw - 0.46) / 0.26, unit: unit)
            }
        case .graspContact:
            // Beads hop/pour out beside Moss
            let t = CGFloat(phase.action)
            let bx = bowlX - bowlW * 0.48 * t - unit * 0.03
            let by = floorY - beadR - CGFloat(sin(Double(t) * .pi) * Double(unit) * 0.08)
            ctx.fill(Path(ellipseIn: CGRect(x: bx - beadR, y: by - beadR, width: beadR * 2, height: beadR * 2)), with: .color(Crayon.cherry))
            ctx.fill(Path(ellipseIn: CGRect(x: bowlX - beadR * 1.4, y: bowlY - bowlH * 0.38, width: beadR * 1.8, height: beadR * 1.8)), with: .color(Crayon.sunflower))
        default:
            // Resting beads inside & beside bowl
            ctx.fill(Path(ellipseIn: CGRect(x: bowlX - beadR * 1.6, y: bowlY - bowlH * 0.40, width: beadR * 1.9, height: beadR * 1.9)), with: .color(Crayon.teal))
            ctx.fill(Path(ellipseIn: CGRect(x: bowlX + beadR * 0.2, y: bowlY - bowlH * 0.38, width: beadR * 1.9, height: beadR * 1.9)), with: .color(Crayon.sunflower))
            if script.phrase == .soundRipple {
                drawSoundArcs(in: &ctx, origin: CGPoint(x: bowlX, y: bowlY - bowlH * 0.75), facingLeft: true, unit: unit, tint: dark ? Palette.amber : Crayon.caramel)
            }
        }

        // Draw birchwood bowl body in front of resting beads
        let tilt = script.phrase == .graspContact ? -14.0 * sin(phase.action * .pi) : 0.0
        var c = ctx
        c.translateBy(x: bowlX, y: bowlY)
        c.rotate(by: .degrees(tilt))

        var bowl = Path()
        bowl.move(to: CGPoint(x: -bowlW * 0.5, y: -bowlH * 0.45))
        bowl.addLine(to: CGPoint(x: bowlW * 0.5, y: -bowlH * 0.45))
        bowl.addQuadCurve(to: CGPoint(x: bowlW * 0.32, y: bowlH * 0.52), control: CGPoint(x: bowlW * 0.50, y: bowlH * 0.24))
        bowl.addLine(to: CGPoint(x: -bowlW * 0.32, y: bowlH * 0.52))
        bowl.addQuadCurve(to: CGPoint(x: -bowlW * 0.5, y: -bowlH * 0.45), control: CGPoint(x: -bowlW * 0.50, y: bowlH * 0.24))
        bowl.closeSubpath()

        let w1 = dark ? Color(hex: 0xDCAD71) : Color(hex: 0xF3CF98)
        let w2 = dark ? Color(hex: 0x996B35) : Color(hex: 0xC68E51)
        c.fill(bowl, with: flat ? .color(w1) : .linearGradient(Gradient(colors: [w1, w2]), startPoint: CGPoint(x: -bowlW * 0.4, y: -bowlH * 0.4), endPoint: CGPoint(x: bowlW * 0.4, y: bowlH * 0.5)))
        c.stroke(Path(ellipseIn: CGRect(x: -bowlW * 0.5, y: -bowlH * 0.54, width: bowlW, height: bowlH * 0.22)), with: .color(w1.mix(with: .white, by: 0.25)), lineWidth: max(1.0, unit * 0.006))
    }

    // MARK: - 5. Nordic Brass & Birch Hand Bell (A05, A07, A13, A30)

    func drawBellScene(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat, floorY: CGFloat) {
        let cx = w * 0.51
        let bellSize = unit * 0.16
        let swingDeg = sin(phase.raw * .pi * 4.0) * (script.phrase == .soundRipple ? 15.0 : 5.0)
        let tapDip = (script.phrase == .liftStack || script.phrase == .graspContact) ? CGFloat(phase.contact * Double(unit) * 0.03) : 0
        let cy = floorY - bellSize * 0.58 + tapDip

        drawFloorShadow(in: &ctx, x: cx, floorY: floorY, rx: bellSize * 0.46, ry: unit * 0.018)

        var c = ctx
        c.translateBy(x: cx, y: cy - bellSize * 0.35)
        c.rotate(by: .degrees(swingDeg))

        // Birch handle
        let handle = Path(roundedRect: CGRect(x: -bellSize * 0.11, y: -bellSize * 0.32, width: bellSize * 0.22, height: bellSize * 0.42), cornerRadius: bellSize * 0.10)
        c.fill(handle, with: .color(dark ? Color(hex: 0xC6975B) : Color(hex: 0xE7B97E)))

        // Brass bell dome
        var dome = Path()
        dome.move(to: CGPoint(x: -bellSize * 0.26, y: bellSize * 0.06))
        dome.addQuadCurve(to: CGPoint(x: bellSize * 0.26, y: bellSize * 0.06), control: CGPoint(x: 0, y: -bellSize * 0.06))
        dome.addLine(to: CGPoint(x: bellSize * 0.42, y: bellSize * 0.62))
        dome.addQuadCurve(to: CGPoint(x: -bellSize * 0.42, y: bellSize * 0.62), control: CGPoint(x: 0, y: bellSize * 0.72))
        dome.closeSubpath()

        let b1 = Palette.beadLight
        let b2 = Palette.bead
        let b3 = Color(hex: 0x9E6F0C)
        c.fill(dome, with: flat ? .color(b2) : .linearGradient(Gradient(colors: [b1, b2, b3]), startPoint: CGPoint(x: -bellSize * 0.3, y: 0), endPoint: CGPoint(x: bellSize * 0.35, y: bellSize * 0.6)))
        c.fill(Path(ellipseIn: CGRect(x: -bellSize * 0.09, y: bellSize * 0.58, width: bellSize * 0.18, height: bellSize * 0.16)), with: .color(b3))

        if script.phrase == .soundRipple || phase.isContactWindow {
            drawSoundArcs(in: &ctx, origin: CGPoint(x: cx - bellSize * 0.46, y: cy), facingLeft: true, unit: unit, tint: dark ? Palette.amber : Crayon.sunflower)
        }
    }

    // MARK: - 6. Board Picture Book (N05, A06, A22, A23, A31, A36, A37)

    func drawPictureBookScene(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat, floorY: CGFloat) {
        if script.secondaryProp == .leaf {
            drawSingleLeaf(in: &ctx, center: CGPoint(x: w * 0.63, y: floorY - unit * 0.055), scale: unit * 0.085, angleDeg: 22)
        }

        let bw = unit * 0.30
        let bh = unit * 0.14
        let cx = w * 0.50
        let baseY = floorY - bh * 0.44

        drawFloorShadow(in: &ctx, x: cx, floorY: floorY, rx: bw * 0.52, ry: unit * 0.020)

        // Cover board base
        let coverRect = CGRect(x: cx - bw * 0.52, y: baseY - bh * 0.45, width: bw * 1.04, height: bh * 0.96)
        ctx.fill(Path(roundedRect: coverRect, cornerRadius: 6), with: .color(Crayon.caramel.mix(with: .black, by: dark ? 0.25 : 0.08)))

        // Open cotton-paper left & right pages
        let pageColor = dark ? Color(hex: 0xEAE0CE) : Color(hex: 0xFFFDF7)
        let leftPage = Path(roundedRect: CGRect(x: cx - bw * 0.48, y: baseY - bh * 0.52, width: bw * 0.47, height: bh * 0.90), cornerRadius: 4)
        let rightPage = Path(roundedRect: CGRect(x: cx + bw * 0.01, y: baseY - bh * 0.52, width: bw * 0.47, height: bh * 0.90), cornerRadius: 4)
        ctx.fill(leftPage, with: .color(pageColor))
        ctx.fill(rightPage, with: .color(pageColor.mix(with: .black, by: 0.04)))

        // Tiny illustration on left page (sun + mint hill)
        let sunR = unit * 0.022
        ctx.fill(Path(ellipseIn: CGRect(x: cx - bw * 0.33, y: baseY - bh * 0.32, width: sunR * 2, height: sunR * 2)), with: .color(Crayon.sunflower))
        ctx.fill(Path(roundedRect: CGRect(x: cx - bw * 0.40, y: baseY + bh * 0.02, width: bw * 0.30, height: bh * 0.18), cornerRadius: 3), with: .color(Crayon.leaf.opacity(0.85)))

        // Animated turning page flap driven by phase.action
        let flip = (script.phrase == .liftStack || script.phrase == .offerArc) ? phase.action : 0.25 + 0.10 * sin(phase.raw * .pi * 2.0)
        let flapW = max(4, bw * 0.45 * CGFloat(abs(cos(flip * .pi))))
        let flapX = flip < 0.5 ? cx : (cx - flapW)
        let liftY = CGFloat(sin(flip * .pi) * Double(unit) * 0.045)
        let flap = Path(roundedRect: CGRect(x: flapX, y: baseY - bh * 0.54 - liftY, width: flapW, height: bh * 0.88), cornerRadius: 3)
        ctx.fill(flap, with: .color(pageColor.mix(with: .white, by: 0.25)))
        ctx.stroke(flap, with: .color(Color(hex: 0xCBB799).opacity(0.55)), lineWidth: 0.8)

        if script.phrase == .soundRipple {
            drawSoundArcs(in: &ctx, origin: CGPoint(x: cx, y: baseY - bh * 0.72), facingLeft: true, unit: unit, tint: dark ? Palette.amber : Crayon.caramel)
        }
    }

    // MARK: - 7. Beeswax Crayon & Drawing Sheet (A24)

    func drawCrayonScene(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat, floorY: CGFloat) {
        let pw = unit * 0.32
        let ph = unit * 0.12
        let cx = w * 0.50
        let sheetY = floorY - ph * 0.46

        let sheet = Path(roundedRect: CGRect(x: cx - pw * 0.5, y: sheetY - ph * 0.5, width: pw, height: ph), cornerRadius: 4)
        ctx.fill(sheet, with: .color(dark ? Color(hex: 0xEAE0CE) : Color(hex: 0xFFFDF8)))
        ctx.stroke(sheet, with: .color(Color(hex: 0xCBB799).opacity(0.55)), lineWidth: 1.0)

        // Live growing crayon stroke across the sheet
        let strokeProg = script.phrase == .graspContact || script.phrase == .liftStack ? max(0.25, phase.action) : 0.85
        let x0 = cx - pw * 0.36
        let x1 = cx + pw * 0.34
        let curX = x0 + (x1 - x0) * CGFloat(strokeProg)
        let curY = sheetY + sin(CGFloat(strokeProg) * .pi * 2.0) * ph * 0.18

        var arc = Path()
        arc.move(to: CGPoint(x: x0, y: sheetY))
        let steps = 16
        for i in 1...steps {
            let f = CGFloat(i) / CGFloat(steps) * CGFloat(strokeProg)
            let sx = x0 + (x1 - x0) * f
            let sy = sheetY + sin(f * .pi * 2.0) * ph * 0.18
            arc.addLine(to: CGPoint(x: sx, y: sy))
        }
        ctx.stroke(arc, with: .color(Crayon.cherry.opacity(0.88)), style: StrokeStyle(lineWidth: max(2.2, unit * 0.015), lineCap: .round))

        // Chunky beeswax crayon poised at tip of stroke
        var c = ctx
        c.translateBy(x: curX, y: curY - unit * 0.06)
        c.rotate(by: .degrees(24))
        let body = Path(roundedRect: CGRect(x: -unit * 0.018, y: -unit * 0.06, width: unit * 0.036, height: unit * 0.10), cornerRadius: unit * 0.010)
        c.fill(body, with: .color(Crayon.cherry))
        c.fill(Path(roundedRect: CGRect(x: -unit * 0.018, y: -unit * 0.02, width: unit * 0.036, height: unit * 0.03), cornerRadius: 1), with: .color(Color(hex: 0xF5E7CE)))
    }

    // MARK: - 8. Soft Knitted Pocket Doll & Blanket (N03, A25)

    func drawDollScene(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat, floorY: CGFloat) {
        let cx = w * 0.50
        let sway = sin(phase.raw * .pi * 2.0) * 4.0
        let dollH = unit * 0.18
        let cy = floorY - dollH * 0.52

        drawFloorShadow(in: &ctx, x: cx, floorY: floorY, rx: unit * 0.09, ry: unit * 0.018)

        var c = ctx
        c.translateBy(x: cx, y: cy)
        c.rotate(by: .degrees(sway))

        // Cozy tunic body
        let body = Path(roundedRect: CGRect(x: -unit * 0.052, y: -unit * 0.02, width: unit * 0.104, height: unit * 0.105), cornerRadius: unit * 0.036)
        c.fill(body, with: .color(Crayon.peach))

        // Soft cotton head (zero blush/mouth clutter)
        let headR = unit * 0.044
        c.fill(Path(ellipseIn: CGRect(x: -headR, y: -unit * 0.088, width: headR * 2, height: headR * 2)), with: .color(Color(hex: dark ? 0xE6D3B5 : 0xFBF0DC)))

        // Tucked soft blanket over lower half during gentleSway / graspContact
        let tuckLift = CGFloat(phase.action) * unit * 0.015
        let blanket = Path(roundedRect: CGRect(x: -unit * 0.062, y: unit * 0.02 - tuckLift, width: unit * 0.124, height: unit * 0.068), cornerRadius: unit * 0.022)
        c.fill(blanket, with: .color(Crayon.sky.opacity(dark ? 0.85 : 0.94)))

        if script.secondaryProp == .lantern {
            drawLanternGlyph(in: &ctx, center: CGPoint(x: w * 0.60, y: floorY - unit * 0.075), unit: unit * 0.72)
        }
        if script.phrase == .soundRipple || phase.isContactWindow {
            drawSoundArcs(in: &ctx, origin: CGPoint(x: cx, y: cy - dollH * 0.65), facingLeft: true, unit: unit, tint: dark ? Palette.amber : Crayon.peach)
        }
    }

    // MARK: - 9. Botanical Outdoor Leaf (A10, A34)

    func drawLeafScene(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat, floorY: CGFloat) {
        let sway = sin(phase.raw * .pi * 2.0)
        let driftY = script.phrase == .offerArc ? CGFloat((1.0 - phase.action) * Double(unit) * 0.12) : CGFloat(abs(sway) * Double(unit) * 0.025)
        let cx = w * 0.49 + CGFloat(sway * Double(unit) * 0.03)
        let cy = floorY - unit * 0.12 - driftY

        drawFloorShadow(in: &ctx, x: cx, floorY: floorY, rx: unit * 0.08, ry: unit * 0.016, factor: 0.7)
        drawSingleLeaf(in: &ctx, center: CGPoint(x: cx, y: cy), scale: unit * 0.12, angleDeg: -16.0 + sway * 12.0)

        // Breeze lines across meadow
        let windColor = (dark ? Crayon.mint : Crayon.leaf).opacity(0.45)
        for i in 0..<2 {
            let wy = cy - unit * 0.06 + CGFloat(i) * unit * 0.045
            var wind = Path()
            wind.move(to: CGPoint(x: cx - unit * 0.16, y: wy))
            wind.addQuadCurve(to: CGPoint(x: cx + unit * 0.14, y: wy - 4), control: CGPoint(x: cx, y: wy - 10))
            ctx.stroke(wind, with: .color(windColor), style: StrokeStyle(lineWidth: max(1.1, unit * 0.006), lineCap: .round))
        }
    }

    private func drawSingleLeaf(in ctx: inout GraphicsContext, center: CGPoint, scale s: CGFloat, angleDeg: Double) {
        var c = ctx
        c.translateBy(x: center.x, y: center.y)
        c.rotate(by: .degrees(angleDeg))

        var leaf = Path()
        leaf.move(to: CGPoint(x: 0, y: -s * 0.85))
        leaf.addQuadCurve(to: CGPoint(x: 0, y: s * 0.72), control: CGPoint(x: s * 0.88, y: -s * 0.10))
        leaf.addQuadCurve(to: CGPoint(x: 0, y: -s * 0.85), control: CGPoint(x: -s * 0.88, y: -s * 0.10))
        leaf.closeSubpath()

        c.fill(leaf, with: .color(Crayon.leaf))
        var vein = Path()
        vein.move(to: CGPoint(x: 0, y: -s * 0.65))
        vein.addLine(to: CGPoint(x: 0, y: s * 0.92))
        c.stroke(vein, with: .color(Color(hex: 0xEEF8DC).opacity(0.85)), style: StrokeStyle(lineWidth: max(1.0, s * 0.08), lineCap: .round))
    }

    // MARK: - 10. Warm Paper Lantern (N01, N04, N06, A01, A16, A17, A26, A40)

    func drawLanternScene(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat, floorY: CGFloat) {
        if script.secondaryProp == .mat {
            let cushion = Path(roundedRect: CGRect(x: w * 0.24, y: floorY - unit * 0.032, width: w * 0.22, height: unit * 0.034), cornerRadius: unit * 0.017)
            ctx.fill(cushion, with: .color((dark ? Crayon.lilac : Crayon.peach).opacity(0.42)))
        } else if script.secondaryProp == .pictureBook {
            drawMiniClosedBook(in: &ctx, center: CGPoint(x: w * 0.62, y: floorY - unit * 0.025), unit: unit)
        } else if script.secondaryProp == .woodenRing {
            drawMiniWoodenRing(in: &ctx, center: CGPoint(x: w * 0.42, y: floorY - unit * 0.052), unit: unit)
        }

        let sway = sin(phase.raw * .pi * 2.0) * 3.5
        let cx = w * 0.50 + CGFloat(sway * 0.6)
        let cy = floorY - unit * 0.12 - CGFloat(phase.contact * Double(unit) * 0.018)

        drawFloorShadow(in: &ctx, x: cx, floorY: floorY, rx: unit * 0.085, ry: unit * 0.018)
        drawLanternGlyph(in: &ctx, center: CGPoint(x: cx, y: cy), unit: unit, tiltDeg: sway)

        if script.phrase == .soundRipple {
            let facingLeft = script.lead != .child
            let arcOrigin = CGPoint(x: cx + (facingLeft ? -unit * 0.08 : unit * 0.08), y: cy - unit * 0.04)
            drawSoundArcs(in: &ctx, origin: arcOrigin, facingLeft: facingLeft, unit: unit, tint: dark ? Palette.amber : Crayon.tangerine)
        } else if script.phrase == .pauseWatch {
            let r = unit * CGFloat(0.11 + 0.03 * sin(phase.raw * .pi * 2.0))
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), with: .color(Palette.amber.opacity(0.32)), lineWidth: max(1.2, unit * 0.007))
        }
    }

    private func drawLanternGlyph(in ctx: inout GraphicsContext, center: CGPoint, unit: CGFloat, tiltDeg: Double = 0) {
        let lw = unit * 0.13
        let lh = unit * 0.15
        let haloR = unit * (dark ? 0.17 : 0.12)
        ctx.fill(
            Path(ellipseIn: CGRect(x: center.x - haloR, y: center.y - haloR, width: haloR * 2, height: haloR * 2)),
            with: .radialGradient(Gradient(colors: [Palette.amber.opacity(dark ? 0.42 : 0.24), Palette.amber.opacity(0)]), center: center, startRadius: 2, endRadius: haloR)
        )

        var c = ctx
        c.translateBy(x: center.x, y: center.y)
        c.rotate(by: .degrees(tiltDeg))

        let body = Path(roundedRect: CGRect(x: -lw * 0.5, y: -lh * 0.5, width: lw, height: lh), cornerRadius: lw * 0.38)
        c.fill(
            body,
            with: flat
                ? .color(Palette.amber)
                : .radialGradient(Gradient(colors: [Color(hex: 0xFFF2C8), Palette.amber, Crayon.tangerine]), center: .zero, startRadius: 1, endRadius: lw * 0.72)
        )
        // Top & bottom birch caps
        let capH = lh * 0.13
        c.fill(Path(roundedRect: CGRect(x: -lw * 0.34, y: -lh * 0.56, width: lw * 0.68, height: capH), cornerRadius: 2), with: .color(Color(hex: 0x8F622F)))
        c.fill(Path(roundedRect: CGRect(x: -lw * 0.34, y: lh * 0.43, width: lw * 0.68, height: capH), cornerRadius: 2), with: .color(Color(hex: 0x8F622F)))
    }

    // MARK: - 11. Quilted Stepping Cushions / Mat Explore (A15, A29)

    func drawMatExploreScene(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat, floorY: CGFloat) {
        let p1 = Path(roundedRect: CGRect(x: w * 0.36, y: floorY - unit * 0.058, width: w * 0.13, height: unit * 0.058), cornerRadius: unit * 0.024)
        let p2 = Path(roundedRect: CGRect(x: w * 0.51, y: floorY - unit * 0.082, width: w * 0.13, height: unit * 0.082), cornerRadius: unit * 0.026)
        ctx.fill(p1, with: .color(Crayon.teal.opacity(dark ? 0.78 : 0.88)))
        ctx.fill(p2, with: .color(Crayon.peach.opacity(dark ? 0.78 : 0.88)))

        // Curved dotted stepping arc over cushions
        var trail = Path()
        trail.move(to: CGPoint(x: w * 0.34, y: floorY - unit * 0.07))
        trail.addQuadCurve(to: CGPoint(x: w * 0.66, y: floorY - unit * 0.09), control: CGPoint(x: w * 0.50, y: floorY - unit * 0.23))
        ctx.stroke(trail, with: .color((dark ? Palette.amber : Crayon.caramel).opacity(0.55)), style: StrokeStyle(lineWidth: max(1.4, unit * 0.008), lineCap: .round, dash: [4, 4]))

        if script.secondaryProp == .softBall || script.phrase == .graspContact {
            let ballX = w * (0.62 - 0.10 * CGFloat(phase.action))
            let ballY = floorY - unit * 0.082 - unit * 0.048
            drawStitchedBall(in: &ctx, center: CGPoint(x: ballX, y: ballY), radius: unit * 0.048, angleDeg: phase.action * 90, shadowFloorY: nil)
        }
    }

    // MARK: - 12. Montessori Ring Stacker (A27)

    func drawRingStackerScene(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat, floorY: CGFloat) {
        let cx = w * 0.50
        let baseW = unit * 0.22
        let baseH = unit * 0.032
        let pegH = unit * 0.21

        drawFloorShadow(in: &ctx, x: cx, floorY: floorY, rx: baseW * 0.52, ry: unit * 0.016)
        // Birchwood base + peg
        let wood = dark ? Color(hex: 0xBA894E) : Color(hex: 0xDFAF72)
        ctx.fill(Path(roundedRect: CGRect(x: cx - baseW * 0.5, y: floorY - baseH, width: baseW, height: baseH), cornerRadius: baseH * 0.4), with: .color(wood))
        ctx.fill(Path(roundedRect: CGRect(x: cx - unit * 0.016, y: floorY - baseH - pegH, width: unit * 0.032, height: pegH), cornerRadius: unit * 0.016), with: .color(wood.mix(with: .white, by: 0.12)))

        // Three graduated rings (bottom two anchored, top ring drops cleanly along peg)
        let ringH = unit * 0.040
        let specs: [(CGFloat, Color, CGFloat)] = [
            (unit * 0.19, Crayon.teal, floorY - baseH - ringH * 0.5),
            (unit * 0.15, Crayon.sunflower, floorY - baseH - ringH * 1.5),
        ]
        for (rw, col, ry) in specs {
            ctx.fill(Path(roundedRect: CGRect(x: cx - rw * 0.5, y: ry - ringH * 0.5, width: rw, height: ringH), cornerRadius: ringH * 0.5), with: .color(col))
        }
        let topDrop = CGFloat(phase.action)
        let topY = (floorY - baseH - pegH - unit * 0.02) + (pegH - ringH * 2.1) * topDrop
        let topW = unit * 0.115
        ctx.fill(Path(roundedRect: CGRect(x: cx - topW * 0.5, y: topY - ringH * 0.5, width: topW, height: ringH), cornerRadius: ringH * 0.5), with: .color(Crayon.cherry))

        if script.secondaryProp == .woodCup {
            drawMiniWoodBasket(in: &ctx, center: CGPoint(x: w * 0.64, y: floorY - unit * 0.05), unit: unit)
        }
    }

    // MARK: - 13. Cooperative Bridge Blocks (A33, A39)

    func drawBridgeBlocksScene(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat, floorY: CGFloat) {
        let blockSize = unit * 0.125
        let leftX = w * 0.43
        let rightX = w * 0.57
        let pillarY = floorY - blockSize * 0.5

        drawBlock(in: &ctx, center: CGPoint(x: leftX, y: pillarY), size: blockSize, color: Crayon.sky, angle: 0, shadowFloorY: floorY)
        drawBlock(in: &ctx, center: CGPoint(x: rightX, y: pillarY), size: blockSize, color: Crayon.teal, angle: 0, shadowFloorY: floorY)

        // Wooden bridge arch beam lowered smoothly across both pillars
        let t = script.phrase == .liftStack ? CGFloat(phase.action) : 1.0
        let beamW = (rightX - leftX) + blockSize * 1.15
        let beamH = blockSize * 0.52
        let startY = pillarY - blockSize * 1.9
        let endY = pillarY - blockSize * 0.5 - beamH * 0.5
        let beamY = startY + (endY - startY) * t
        let beamTilt = (1.0 - Double(t)) * -7.0

        var c = ctx
        c.translateBy(x: w * 0.50, y: beamY)
        c.rotate(by: .degrees(beamTilt))
        c.fill(Path(roundedRect: CGRect(x: -beamW * 0.5, y: -beamH * 0.5, width: beamW, height: beamH), cornerRadius: beamH * 0.35), with: .color(Crayon.cherry))

        if script.secondaryProp == .softBall {
            // Tiny wooden roller / traffic car waiting calmly beside zebra bridge (A39)
            let carX = w * (0.37 + 0.08 * CGFloat(phase.action))
            let carW = unit * 0.095
            let carH = unit * 0.050
            ctx.fill(Path(roundedRect: CGRect(x: carX - carW * 0.5, y: floorY - carH - unit * 0.018, width: carW, height: carH), cornerRadius: 6), with: .color(Crayon.sunflower))
            let wr = unit * 0.016
            ctx.fill(Path(ellipseIn: CGRect(x: carX - carW * 0.28 - wr, y: floorY - wr * 2, width: wr * 2, height: wr * 2)), with: .color(Color(hex: 0x3A342E)))
            ctx.fill(Path(ellipseIn: CGRect(x: carX + carW * 0.28 - wr, y: floorY - wr * 2, width: wr * 2, height: wr * 2)), with: .color(Color(hex: 0x3A342E)))
        }
    }
}
