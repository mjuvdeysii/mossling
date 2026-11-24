import SwiftUI

/// N05: Foreground open linen hardcover picture book spread with Moss & Otto tucked behind the gutter,
/// curved page-turn motion + floating rhyme beads in Step 0, and gentle cover closure on sleepy cue in Step 1.
struct SceneN05_ShortReads: View {
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

            let ms = s * 0.35
            let os = ms * Kind.otto.scale
            let groundY = h * 0.765

            let ottoX = w * 0.32
            let mossX = w * 0.67
            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat)
            )

            // Step 1: Moss gives sleepy cue, lid gently lowers & Otto pauses page turn softly
            let sleepyT = step == 1 ? min(1.0, p.action * 1.1) : 0.0
            let mossLid = step == 1 ? (0.18 + sleepyT * 0.62) : (dark ? 0.16 : 0.0)
            let mossMood: Mood = step == 1 && sleepyT > 0.65 ? .sleep : (step == 0 ? .happy : .open)
            let ottoLid = step == 1 ? (dark ? 0.56 : 0.42) : (dark ? 0.40 : 0.24)
            let ottoLook = step == 0 ? CGPoint(x: 0.45, y: 0.42) : CGPoint(x: 0.75, y: 0.18)
            let mossLook = step == 0 ? CGPoint(x: -0.35, y: 0.36) : CGPoint(x: -0.50, y: 0.28)
            let ottoLean = step == 0 ? 5.0 : 2.0 - sleepyT * 3.0
            let mossLean = step == 1 ? -4.0 * sleepyT : 2.0

            let ottoState = Creature.state(.otto, face: .open, look: ottoLook, lid: ottoLid, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )
            let bookSpineCenter = CGPoint(x: w * 0.50, y: h * 0.78)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    BespokeStageHelpers.drawAtmosphereWash(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        dayTop: Color(hex: 0xFBF6E9),
                        dayBottom: Color(hex: 0xECE1CA),
                        nightTop: Color(hex: 0x0A1224),
                        nightBottom: Color(hex: 0x16223C),
                        dark: dark
                    )
                    // Soft cozy reading lamp/sunlight glow behind actors
                    c.fill(
                        Path(ellipseIn: CGRect(x: w * 0.12, y: h * 0.14, width: w * 0.76, height: h * 0.62)),
                        with: .radialGradient(
                            Gradient(colors: [
                                (dark ? Color(hex: 0x253860) : Color(hex: 0xFFF7D6)).opacity(0.60),
                                Color.clear
                            ]),
                            center: CGPoint(x: w * 0.50, y: h * 0.45),
                            startRadius: 8,
                            endRadius: min(w, h) * 0.45
                        )
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: bookSpineCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .floorPool
                )

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
                    lightDirection: CGPoint(x: 0.25, y: -0.92),
                    secondaryLagDegrees: -ottoLean * 0.28
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
                    lightDirection: CGPoint(x: 0.25, y: -0.92),
                    secondaryLagDegrees: -mossLean * 0.35
                )
                .position(mossCenter)

                // Giant foreground linen picture book spread in front of actors
                Canvas(rendersAsynchronously: false) { c, size in
                    drawForegroundBoardBook(in: &c, w: size.width, h: size.height, step: step, p: p, sleepyT: sleepyT, flat: flat, dark: dark)
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: bookSpineCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawForegroundBoardBook(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        step: Int,
        p: LivingPhaseSample,
        sleepyT: Double,
        flat: Bool,
        dark: Bool
    ) {
        let bookRect = CGRect(x: w * 0.13, y: h * 0.635, width: w * 0.74, height: h * 0.285)
        let spineX = bookRect.midX

        PixarDrawHelpers.drawContactAO(
            in: &ctx,
            center: CGPoint(x: spineX, y: bookRect.maxY + 3),
            rx: bookRect.width * 0.50,
            ry: 10,
            dark: dark,
            opacity: 0.85
        )

        // Linen hardcover binding outer board
        let boardRect = bookRect.insetBy(dx: -5, dy: -3)
        let boardPath = Path(roundedRect: boardRect, cornerRadius: 10)
        ctx.fill(
            boardPath,
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x35514D) : Color(hex: 0x7BA489),
                    dark ? Color(hex: 0x22363A) : Color(hex: 0x5B836B)
                ]),
                startPoint: CGPoint(x: boardRect.minX, y: boardRect.minY),
                endPoint: CGPoint(x: boardRect.maxX, y: boardRect.maxY)
            )
        )

        // Right board folds gently toward center when sleepy cue triggers in Step 1
        let closeFrac = CGFloat(step == 1 ? sleepyT * 0.42 : 0.0)
        let leftSpread = CGRect(x: bookRect.minX, y: bookRect.minY, width: bookRect.width * 0.5 - 1, height: bookRect.height)
        let rightWidth = (bookRect.width * 0.5 - 1) * (1.0 - closeFrac * 0.65)
        let rightSpread = CGRect(x: spineX + 1, y: bookRect.minY, width: rightWidth, height: bookRect.height)

        for (idx, rect) in [leftSpread, rightSpread].enumerated() {
            let colLight = dark ? Color(hex: 0xE7DBBF) : Color(hex: 0xFFFDF5)
            let colDark = dark ? Color(hex: 0xCBB994) : Color(hex: 0xEFE4CC)
            let page = Path(roundedRect: rect, cornerRadius: 6)
            if flat {
                GhibliDrawHelpers.fillWatercolor(
                    in: &ctx,
                    path: page,
                    bounds: rect,
                    light: colLight,
                    rich: colDark,
                    pencilOutline: (dark ? Color(hex: 0x8F8066) : Color(hex: 0xB8A586)).opacity(0.6),
                    lineWidth: 1.0
                )
            } else {
                ctx.fill(
                    page,
                    with: .linearGradient(
                        Gradient(colors: idx == 0 ? [colLight, colDark] : [colDark, colLight]),
                        startPoint: CGPoint(x: rect.minX, y: rect.midY),
                        endPoint: CGPoint(x: rect.maxX, y: rect.midY)
                    )
                )
            }
        }

        // Mini illustrated hill & sun emblem printed on open spread
        ctx.fill(
            Path(ellipseIn: CGRect(x: leftSpread.midX - 10, y: leftSpread.midY - 8, width: 16, height: 16)),
            with: .color(Palette.amber.opacity(0.70))
        )

        // Step 0: Curved turning page lifting across gutter + floating rhythm rhyme beads
        if step == 0 {
            let turn = CGFloat(p.action)
            let edgeX = rightSpread.maxX - (rightSpread.width * 1.85 * turn)
            let liftY = sin(Double(turn) * .pi) * 18.0
            var sheet = Path()
            sheet.move(to: CGPoint(x: spineX, y: bookRect.minY + 2))
            sheet.addQuadCurve(
                to: CGPoint(x: edgeX, y: bookRect.minY + 4 - CGFloat(liftY)),
                control: CGPoint(x: (spineX + edgeX) * 0.5, y: bookRect.minY - CGFloat(liftY) * 0.9)
            )
            sheet.addLine(to: CGPoint(x: edgeX, y: bookRect.maxY - 4 - CGFloat(liftY) * 0.4))
            sheet.addQuadCurve(
                to: CGPoint(x: spineX, y: bookRect.maxY - 2),
                control: CGPoint(x: (spineX + edgeX) * 0.5, y: bookRect.maxY - CGFloat(liftY) * 0.5)
            )
            sheet.closeSubpath()
            ctx.fill(sheet, with: .color((dark ? Color(hex: 0xEFE4CC) : Color(hex: 0xFFFDF8)).opacity(0.92)))
            ctx.stroke(sheet, with: .color(Color(hex: 0xAE9A7E).opacity(0.42)), lineWidth: 1.0)

            // Rhythm rhyme beads drifting from open page toward Moss
            for b in 0..<3 {
                let bt = max(0, min(1, p.raw * 1.1 - Double(b) * 0.14))
                let bx = w * (0.44 + CGFloat(bt) * 0.16)
                let by = h * 0.56 - CGFloat(bt) * h * 0.16 - CGFloat(sin(bt * .pi) * 6)
                let br: CGFloat = b == 1 ? 4.2 : 3.0
                ctx.fill(
                    Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2)),
                    with: .color((b % 2 == 0 ? Palette.amber : Color(hex: 0x7EB48B)).opacity(0.75 * (1.0 - bt * 0.4)))
                )
            }
        }

        // Golden ribbon bookmark draped gracefully over bottom spine
        var ribbon = Path()
        ribbon.move(to: CGPoint(x: spineX - 2, y: bookRect.maxY - 4))
        ribbon.addLine(to: CGPoint(x: spineX + 3, y: bookRect.maxY - 4))
        ribbon.addLine(to: CGPoint(x: spineX + 4, y: bookRect.maxY + 14))
        ribbon.addLine(to: CGPoint(x: spineX, y: bookRect.maxY + 10))
        ribbon.addLine(to: CGPoint(x: spineX - 3, y: bookRect.maxY + 14))
        ribbon.closeSubpath()
        ctx.fill(ribbon, with: .color(Palette.amber.opacity(0.92)))
    }
}
