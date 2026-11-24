import SwiftUI

// MARK: - Studio Ghibli Watercolor, Cold-Press Cotton Paper & Colored-Pencil Rig

/// Applies Studio Ghibli cold-press cotton paper tooth, wet-edge pigment pooling, Komorebi leaf dapple,
/// and warm atmospheric shadow lifting across a 2D picture-book stage.
struct GhibliStageGrade: ViewModifier {
    let stageSize: CGSize
    let time: Double
    let dark: Bool
    var komorebiStrength: Double = 0.85
    var enabled: Bool = true

    func body(content: Self.Content) -> some View {
        let active = enabled && stageSize.width >= 80 && stageSize.height >= 60
        return content
            .layerEffect(
                ShaderLibrary.ghibliWatercolorWash(
                    .float2(stageSize),
                    .float(Float(time)),
                    .float(Float(komorebiStrength)),
                    .float(Float(dark ? 1.0 : 0.0))
                ),
                maxSampleOffset: CGSize(width: 3, height: 3),
                isEnabled: active
            )
            .colorEffect(
                ShaderLibrary.ghibliPaperHighlightLift(
                    .float2(stageSize),
                    .float(Float(dark ? 1.0 : 0.0))
                ),
                isEnabled: active
            )
    }
}

/// Canonical 2D Moss & Otto built strictly from `Shapes.swift` (`9328e58` 1:1 paths)
/// rendered with multi-layer translucent Ghibli watercolor washes, organic colored-pencil contours,
/// cotton-paper dry-brush highlight reserves, and 120ms secondary leaf/antenna pendulum follow-through.
struct GhibliActorRenderer: View {
    let kind: Kind
    let size: CGFloat
    let mood: Mood
    let look: CGPoint
    var lid: Double? = nil
    var lean: Double = 0
    var hopLift: CGFloat = 0
    var breathTime: Double = 0
    var isStatic: Bool = true
    var dark: Bool = false
    var leafLagDegrees: Double = 0
    var glow: Bool = false
    var postureScale: CGSize = CGSize(width: 1, height: 1)

    var body: some View {
        let period = kind == .moss ? 2.6 : 3.8
        let breath = isStatic ? 0 : (1.0 - cos(breathTime / period * 2.0 * .pi)) * 0.5
        let amp = kind == .moss ? 0.017 : 0.011
        let sx = (1.0 - breath * amp * 0.5) * Double(postureScale.width)
        let sy = (1.0 + breath * amp) * Double(postureScale.height)

        Canvas(rendersAsynchronously: false) { ctx, canvasSize in
            let s = min(canvasSize.width, canvasSize.height) / 100.0
            ctx.translateBy(x: (canvasSize.width - 100 * s) / 2, y: (canvasSize.height - 100 * s) / 2)
            ctx.scaleBy(x: s, y: s)

            // Organic watercolor ground puddle shadow
            let liftScale = max(0.58, 1.0 - hopLift * 0.35)
            let rx: CGFloat = (kind == .moss ? 31 : 23) * liftScale
            var sg = ctx
            sg.translateBy(x: 50, y: 90.2)
            sg.scaleBy(x: 1, y: 0.21)
            sg.fill(
                Path(ellipseIn: CGRect(x: -rx * 1.15, y: -rx * 1.15, width: rx * 2.3, height: rx * 2.3)),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(hex: dark ? 0x060A18 : 0x56644B).opacity(dark ? 0.42 : 0.20),
                        Color.clear
                    ]),
                    center: .zero,
                    startRadius: 0,
                    endRadius: rx * 1.15
                )
            )

            // Foot-anchored squash/stretch & gentle body lean
            ctx.translateBy(x: 50, y: 88)
            ctx.scaleBy(x: sx, y: sy)
            ctx.rotate(by: .degrees(lean))
            ctx.translateBy(x: -50, y: -88)

            let restLid = lid ?? (kind == .otto ? (dark ? 0.46 : 0.34) : (dark ? 0.35 : 0))
            if kind == .moss {
                drawGhibliMoss(
                    in: &ctx,
                    look: look,
                    lid: restLid,
                    mood: mood,
                    sway: (breath - 0.5) * 6.0 + leafLagDegrees
                )
            } else {
                drawGhibliOtto(
                    in: &ctx,
                    look: look,
                    lid: restLid,
                    mood: mood,
                    swing: (breath - 0.5) * 5.0 + leafLagDegrees * 0.65
                )
            }
        }
        .frame(width: size, height: size)
    }

    private func drawGhibliMoss(
        in ctx: inout GraphicsContext,
        look: CGPoint,
        lid: Double,
        mood: Mood,
        sway: Double
    ) {
        let pencilMoss = dark ? Color(hex: 0x99C488).opacity(0.62) : Color(hex: 0x2F4528).opacity(0.78)
        let pencilLeaf = dark ? Color(hex: 0x8EDBB0).opacity(0.65) : Color(hex: 0x24543B).opacity(0.80)

        // Stem + delayed mint leaves with watercolor wash + colored-pencil veins
        ctx.stroke(Shapes.mossStem, with: .color(pencilMoss), style: StrokeStyle(lineWidth: 2.3, lineCap: .round))

        var leaves = ctx
        leaves.translateBy(x: 49.6, y: 25)
        leaves.rotate(by: .degrees(sway))
        leaves.translateBy(x: -49.6, y: -25)

        fillWatercolorLeaf(in: &leaves, path: Shapes.mintB, base: Palette.mintLight, edge: Palette.mintVein, pencil: pencilLeaf)
        fillWatercolorLeaf(in: &leaves, path: Shapes.mintA, base: Palette.mint, edge: Palette.mintVein, pencil: pencilLeaf)
        fillWatercolorLeaf(in: &leaves, path: Shapes.mintD, base: Palette.mintPale, edge: Palette.mint, pencil: pencilLeaf)
        fillWatercolorLeaf(in: &leaves, path: Shapes.mintC, base: Palette.mintPale, edge: Palette.mint, pencil: pencilLeaf)
        leaves.stroke(Shapes.mintVeins, with: .color(pencilLeaf.opacity(0.55)), style: StrokeStyle(lineWidth: 0.75, lineCap: .round))

        // Short ink legs (soft deep olive-charcoal instead of harsh black)
        let legColor = Color(hex: dark ? 0x161D2C : 0x283226)
        ctx.fill(Path(roundedRect: CGRect(x: 33, y: 80, width: 6.5, height: 10), cornerRadius: 3.2), with: .color(legColor))
        ctx.fill(Path(roundedRect: CGRect(x: 59, y: 80, width: 6.5, height: 10), cornerRadius: 3.2), with: .color(legColor))

        // Main watercolor body wash + soft cotton-paper dry-brush crown light + wet-edge pencil outline
        drawWatercolorBody(
            in: &ctx,
            bodyPath: Shapes.mossBody,
            underPath: Shapes.mossUnder,
            base: Palette.moss,
            deep: Palette.mossDeep,
            pencil: pencilMoss
        )
        ctx.fill(Shapes.mossTufts, with: .color(Palette.mossLight.opacity(0.75)))

        drawWatercolorEye(in: &ctx, cx: 43, cy: 55, rx: 6.4, ry: 7.4, look: look, lid: lid, skin: Palette.moss, mood: mood)
        drawWatercolorEye(in: &ctx, cx: 58, cy: 55, rx: 6.4, ry: 7.4, look: look, lid: lid, skin: Palette.moss, mood: mood)
        drawWatercolorMouth(in: &ctx, at: CGPoint(x: 50.5, y: 68), mood: mood)
    }

    private func drawGhibliOtto(
        in ctx: inout GraphicsContext,
        look: CGPoint,
        lid: Double,
        mood: Mood,
        swing: Double
    ) {
        let pencilOtto = dark ? Color(hex: 0x8BA9E3).opacity(0.66) : Color(hex: 0x1A2B55).opacity(0.84)
        let isLit = glow || dark

        // Curved antenna with golden bead & watercolor amber wash halo
        var rod = ctx
        rod.translateBy(x: 50, y: 16.5)
        rod.rotate(by: .degrees(swing))
        rod.translateBy(x: -50, y: -16.5)
        rod.stroke(Shapes.ottoRod, with: .color(dark ? Color(hex: 0x859ED6) : Palette.rodDeep), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

        if isLit {
            let haloR: CGFloat = dark ? 16 : 11
            rod.fill(
                Path(ellipseIn: CGRect(x: 20 - haloR, y: 11.5 - haloR, width: haloR * 2, height: haloR * 2)),
                with: .radialGradient(
                    Gradient(colors: [Palette.amber.opacity(dark ? 0.72 : 0.34), Palette.amber.opacity(0)]),
                    center: CGPoint(x: 20, y: 11.5),
                    startRadius: 2,
                    endRadius: haloR
                )
            )
        }

        let beadRect = CGRect(x: 15, y: 6.5, width: 10, height: 10)
        rod.fill(
            Path(ellipseIn: beadRect),
            with: .radialGradient(
                Gradient(colors: [Palette.beadLight, isLit ? Palette.amber : Palette.bead, Color(hex: 0xA87612)]),
                center: CGPoint(x: 18.2, y: 9.6),
                startRadius: 0.5,
                endRadius: 6
            )
        )
        rod.stroke(Path(ellipseIn: beadRect), with: .color(Color(hex: 0x7A540C).opacity(0.55)), lineWidth: 0.8)
        rod.fill(Path(ellipseIn: CGRect(x: 17.2, y: 8.4, width: 2.8, height: 2.6)), with: .color(Color(hex: 0xFFFBF0).opacity(0.88)))

        let legColor = Color(hex: dark ? 0x121933 : 0x1A2546)
        ctx.fill(Path(roundedRect: CGRect(x: 38, y: 80, width: 6.5, height: 10), cornerRadius: 3.2), with: .color(legColor))
        ctx.fill(Path(roundedRect: CGRect(x: 56, y: 80, width: 6.5, height: 10), cornerRadius: 3.2), with: .color(legColor))

        drawWatercolorBody(
            in: &ctx,
            bodyPath: Shapes.ottoBody,
            underPath: Shapes.ottoDip,
            base: Palette.rod,
            deep: Palette.rodDeep,
            pencil: pencilOtto
        )

        drawWatercolorEye(in: &ctx, cx: 51, cy: 44, rx: 12.5, ry: 11.5, look: look, lid: mood == .wow ? 0 : lid, skin: Palette.rod, mood: mood)
        drawWatercolorMouth(in: &ctx, at: CGPoint(x: 51, y: 64), mood: mood)
    }

    private func fillWatercolorLeaf(
        in ctx: inout GraphicsContext,
        path: Path,
        base: Color,
        edge: Color,
        pencil: Color
    ) {
        let b = path.boundingRect
        ctx.fill(
            path,
            with: .linearGradient(
                Gradient(colors: [base.mix(with: .white, by: 0.22), base, base.mix(with: edge, by: 0.28)]),
                startPoint: CGPoint(x: b.minX, y: b.minY),
                endPoint: CGPoint(x: b.maxX, y: b.maxY)
            )
        )
        ctx.stroke(path, with: .color(pencil.opacity(0.55)), style: StrokeStyle(lineWidth: 0.85, lineJoin: .round))
    }

    private func drawWatercolorBody(
        in ctx: inout GraphicsContext,
        bodyPath: Path,
        underPath: Path,
        base: Color,
        deep: Color,
        pencil: Color
    ) {
        let b = bodyPath.boundingRect
        let sunLift = base.mix(with: Color(hex: 0xFFF7E2), by: dark ? 0.14 : 0.26)
        let poolTone = base.mix(with: deep, by: 0.52)

        // Multi-wash pigment fill
        ctx.fill(
            bodyPath,
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: sunLift, location: 0.0),
                    .init(color: base, location: 0.46),
                    .init(color: poolTone, location: 1.0)
                ]),
                startPoint: CGPoint(x: b.minX + b.width * 0.18, y: b.minY),
                endPoint: CGPoint(x: b.maxX * 0.85 + b.minX * 0.15, y: b.maxY)
            )
        )

        var clipped = ctx
        clipped.clip(to: bodyPath)

        // Wet-on-wet underside pigment bleed
        clipped.fill(underPath, with: .color(deep.opacity(0.46)))

        // Cotton paper dry-brush upper-left highlight reserve
        clipped.fill(
            Path(ellipseIn: CGRect(x: b.minX + b.width * 0.10, y: b.minY + b.height * 0.06, width: b.width * 0.52, height: b.height * 0.44)),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFFBF0).opacity(dark ? 0.12 : 0.24), Color.clear]),
                center: CGPoint(x: b.minX + b.width * 0.30, y: b.minY + b.height * 0.24),
                startRadius: 0,
                endRadius: b.width * 0.30
            )
        )

        // Warm horizon bounce along lower edge
        clipped.fill(
            Path(CGRect(x: b.minX, y: b.maxY - b.height * 0.15, width: b.width, height: b.height * 0.15)),
            with: .linearGradient(
                Gradient(colors: [Color.clear, Color(hex: 0xFFE9BA).opacity(dark ? 0.10 : 0.18)]),
                startPoint: CGPoint(x: 0, y: b.maxY - b.height * 0.15),
                endPoint: CGPoint(x: 0, y: b.maxY)
            )
        )

        // Subtle wet-edge rim inside shape before colored pencil stroke
        clipped.stroke(bodyPath, with: .color(deep.opacity(0.32)), lineWidth: 2.2)

        // Non-black colored-pencil outline
        ctx.stroke(bodyPath, with: .color(pencil), style: StrokeStyle(lineWidth: 1.45, lineCap: .round, lineJoin: .round))
    }

    private func drawWatercolorEye(
        in ctx: inout GraphicsContext,
        cx: CGFloat,
        cy: CGFloat,
        rx: CGFloat,
        ry: CGFloat,
        look: CGPoint,
        lid: Double,
        skin: Color,
        mood: Mood
    ) {
        let ink = Color(hex: 0x222A38)
        if mood == .sleep || (mood == .happy && lid >= 1) {
            var p = Path()
            p.move(to: CGPoint(x: cx - rx * 0.9, y: cy))
            p.addQuadCurve(
                to: CGPoint(x: cx + rx * 0.9, y: cy),
                control: CGPoint(x: cx, y: mood == .sleep ? cy + ry * 0.9 : cy - ry * 0.9)
            )
            ctx.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: max(1.8, ry * 0.34), lineCap: .round))
            return
        }

        let r = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
        var c = ctx
        c.clip(to: Path(ellipseIn: r))
        c.fill(Path(r), with: .color(Color(hex: 0xFCF8EE)))
        let pr = min(rx, ry) * (mood == .wow ? 0.5 : 0.62)
        let px = cx + max(-1, min(1, look.x)) * (rx - pr - 0.3)
        let py = cy + max(-1, min(1, look.y)) * (ry - pr - 0.3)
        c.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)), with: .color(ink))
        c.fill(Path(ellipseIn: CGRect(x: px - pr * 0.55, y: py - pr * 0.6, width: pr * 0.42, height: pr * 0.42)), with: .color(Color(hex: 0xFFFDF8).opacity(0.92)))

        if mood == .happy {
            c.fill(Path(ellipseIn: CGRect(x: cx - rx * 1.3, y: cy + ry * 0.2, width: rx * 2.6, height: ry * 2)), with: .color(skin))
        }
        if lid > 0 {
            c.fill(Path(CGRect(x: cx - rx - 0.6, y: cy - ry - 0.6, width: rx * 2 + 1.2, height: (ry * 2 + 1.2) * lid)), with: .color(skin))
        }
        ctx.stroke(Path(ellipseIn: r.insetBy(dx: -0.35, dy: -0.35)), with: .color(skin.mix(with: ink, by: 0.22)), lineWidth: 1.1)
    }

    private func drawWatercolorMouth(in ctx: inout GraphicsContext, at: CGPoint, mood: Mood) {
        let ink = Color(hex: 0x222A38)
        switch mood {
        case .wow:
            ctx.fill(Path(ellipseIn: CGRect(x: at.x - 2.2, y: at.y - 2.6, width: 4.4, height: 5.6)), with: .color(ink))
        case .happy:
            var p = Path()
            p.move(to: CGPoint(x: at.x - 4, y: at.y - 1))
            p.addQuadCurve(to: CGPoint(x: at.x + 4, y: at.y - 1), control: CGPoint(x: at.x, y: at.y + 4))
            ctx.stroke(p, with: .color(ink), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        default:
            break
        }
    }
}

// MARK: - Unified 3D/2D Actor Switcher (Zero Spatial Jump)

/// Renders Moss or Otto at identical screen coordinates across Pixar 3D and Ghibli 2D modes so switching
/// between 3D soft-vinyl and 2D watercolor never shifts character placement or ground contact.
struct StoryTheaterActorView: View {
    let kind: Kind
    let size: CGFloat
    let mood: Mood
    let look: CGPoint
    var lid: Double? = nil
    var lean: Double = 0
    var hopLift: CGFloat = 0
    var hopping: Bool = false
    var breathTime: Double = 0
    var isStatic: Bool = true
    var dark: Bool = false
    var flat: Bool = false
    var compact: Bool = false
    var lightDirection: CGPoint = CGPoint(x: 0.75, y: -0.65)
    var secondaryLagDegrees: Double = 0
    var postureScale: CGSize = CGSize(width: 1, height: 1)

    var body: some View {
        if flat {
            GhibliActorRenderer(
                kind: kind,
                size: size,
                mood: mood,
                look: look,
                lid: lid,
                lean: lean,
                hopLift: hopLift,
                breathTime: breathTime,
                isStatic: isStatic,
                dark: dark,
                leafLagDegrees: secondaryLagDegrees,
                glow: kind == .otto && dark,
                postureScale: postureScale
            )
        } else {
            PixarActorRenderer(
                kind: kind,
                size: size,
                mood: mood,
                look: look,
                lid: lid,
                lean: lean,
                hopLift: hopLift,
                hopping: hopping,
                breathTime: breathTime,
                isStatic: isStatic,
                dark: dark,
                lightDirection: lightDirection,
                compact: compact,
                postureScale: postureScale
            )
        }
    }
}

// MARK: - Studio Ghibli Watercolor Canvas Helpers

enum GhibliDrawHelpers {
    /// Fills a shape with translucent Ghibli pigment wash and draws a subtle darker wet-edge pigment ring.
    static func fillWatercolor(
        in ctx: inout GraphicsContext,
        path: Path,
        bounds: CGRect,
        light: Color,
        rich: Color,
        pencilOutline: Color? = nil,
        lineWidth: CGFloat = 1.2
    ) {
        ctx.fill(
            path,
            with: .linearGradient(
                Gradient(colors: [light, rich]),
                startPoint: CGPoint(x: bounds.minX + bounds.width * 0.2, y: bounds.minY),
                endPoint: CGPoint(x: bounds.maxX * 0.8 + bounds.minX * 0.2, y: bounds.maxY)
            )
        )
        var clipped = ctx
        clipped.clip(to: path)
        clipped.stroke(path, with: .color(rich.mix(with: Color(hex: 0x243025), by: 0.22).opacity(0.32)), lineWidth: lineWidth * 1.9)
        if let pencilOutline {
            ctx.stroke(path, with: .color(pencilOutline), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
    }

    /// Hand-painted Ghibli cumulus cloud layered with warm sun rim and lavender-sage under-shadow.
    static func drawPaintedCloud(
        in ctx: inout GraphicsContext,
        center: CGPoint,
        width: CGFloat,
        dark: Bool
    ) {
        let h = width * 0.38
        var p = Path()
        p.addRoundedRect(in: CGRect(x: center.x - width * 0.5, y: center.y, width: width, height: h * 0.62), cornerSize: CGSize(width: h * 0.31, height: h * 0.31))
        p.addEllipse(in: CGRect(x: center.x - width * 0.34, y: center.y - h * 0.42, width: width * 0.44, height: h * 0.82))
        p.addEllipse(in: CGRect(x: center.x - width * 0.04, y: center.y - h * 0.28, width: width * 0.38, height: h * 0.72))

        let top = dark ? Color(hex: 0x3D4C74).opacity(0.60) : Color(hex: 0xFFFDF6).opacity(0.92)
        let bot = dark ? Color(hex: 0x283457).opacity(0.60) : Color(hex: 0xDFEBDC).opacity(0.85)
        fillWatercolor(
            in: &ctx,
            path: p,
            bounds: CGRect(x: center.x - width * 0.5, y: center.y - h * 0.42, width: width, height: h * 1.05),
            light: top,
            rich: bot,
            pencilOutline: (dark ? Color(hex: 0x6275A8) : Color(hex: 0x9BB09D)).opacity(0.35),
            lineWidth: 0.9
        )
    }

    /// Overhead komorebi (木漏日) dappled leaf canopy framing top corners without obscuring actors.
    static func drawKomorebiCanopy(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        swayOffset: CGFloat,
        dark: Bool
    ) {
        let leafClusters: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
            (0.06, 0.03, 0.22, 0.14, dark ? Color(hex: 0x1E333E) : Color(hex: 0x8CB77F)),
            (0.16, -0.01, 0.18, 0.11, dark ? Color(hex: 0x264147) : Color(hex: 0xAED098)),
            (0.88, 0.02, 0.20, 0.13, dark ? Color(hex: 0x1E333E) : Color(hex: 0x99C186)),
        ]
        for (fx, fy, fw, fh, col) in leafClusters {
            let rect = CGRect(
                x: w * fx - w * fw * 0.5 + swayOffset,
                y: h * fy - h * fh * 0.35,
                width: w * fw,
                height: h * fh
            )
            ctx.fill(Path(ellipseIn: rect), with: .color(col.opacity(dark ? 0.55 : 0.45)))
        }
    }
}
