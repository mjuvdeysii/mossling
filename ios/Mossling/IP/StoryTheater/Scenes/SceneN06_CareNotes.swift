import SwiftUI

/// N06: Perspective birch evening study desk with open Starlight Journal & brass feather stylus
/// stamping communication, rest & caregiver cues (Step 0), blooming into a 7-bead weekly constellation (Step 1).
struct SceneN06_CareNotes: View {
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

            let ms = s * 0.30
            let os = s * 0.36
            let deskY = h * 0.68
            let ottoGround = h * 0.72
            let mossGround = h * 0.80

            let ottoX = w * 0.24
            let mossX = w * 0.79

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: ottoGround, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: mossGround, flat: flat)
            )

            let ottoLook = step == 0 ? CGPoint(x: 0.65, y: 0.42) : CGPoint(x: 0.55, y: -0.25)
            let mossLook = step == 0 ? CGPoint(x: -0.78, y: 0.22) : CGPoint(x: -0.72, y: -0.22)
            let ottoLean = step == 0 ? 7.5 : 3.0
            let mossLean = step == 0 ? -5.0 : -3.5
            let ottoLid: Double = dark ? 0.46 : 0.30

            let ottoState = Creature.state(.otto, face: step == 1 ? .happy : .open, look: ottoLook, lid: ottoLid, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )
            let journalCenter = CGPoint(x: w * 0.50, y: deskY + h * 0.08)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawStudyDeskAndJournal(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        deskY: deskY,
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: journalCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .floorPool
                )

                StoryTheaterActorView(
                    kind: .otto,
                    size: os,
                    mood: step == 1 ? .happy : .open,
                    look: ottoLook,
                    lid: ottoLid,
                    lean: ottoLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.35, y: -0.88),
                    secondaryLagDegrees: -ottoLean * 0.28
                )
                .position(ottoCenter)

                StoryTheaterActorView(
                    kind: .moss,
                    size: ms,
                    mood: step == 1 ? .happy : .wow,
                    look: mossLook,
                    lid: dark ? 0.20 : 0,
                    lean: mossLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.35, y: -0.88),
                    secondaryLagDegrees: -mossLean * 0.35
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: journalCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawStudyDeskAndJournal(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        deskY: CGFloat,
        step: Int,
        p: LivingPhaseSample,
        flat: Bool,
        dark: Bool
    ) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xFAF5E8),
            dayBottom: Color(hex: 0xEDE1CA),
            nightTop: Color(hex: 0x0A1122),
            nightBottom: Color(hex: 0x16223D),
            dark: dark
        )

        // Perspective birch study desk
        var desk = Path()
        desk.move(to: CGPoint(x: -8, y: deskY))
        desk.addLine(to: CGPoint(x: w + 8, y: deskY + h * 0.02))
        desk.addLine(to: CGPoint(x: w + 8, y: h + 8))
        desk.addLine(to: CGPoint(x: -8, y: h + 8))
        desk.closeSubpath()
        let deskBounds = CGRect(x: 0, y: deskY, width: w, height: h - deskY)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: desk,
                bounds: deskBounds,
                light: dark ? Color(hex: 0x392C22) : Color(hex: 0xE6C38E),
                rich: dark ? Color(hex: 0x261D17) : Color(hex: 0xC69A61),
                pencilOutline: (dark ? Color(hex: 0x6E5641) : Color(hex: 0x8F683B)).opacity(0.45),
                lineWidth: 1.1
            )
        } else {
            PixarDrawHelpers.drawBeechwood(in: &ctx, path: desk, bounds: deskBounds, dark: dark, warmth: 0.65, grainLines: 3)
        }

        // Open leather-and-linen Starlight Journal on desk center
        let jRect = CGRect(x: w * 0.27, y: deskY + h * 0.04, width: w * 0.46, height: h * 0.20)
        PixarDrawHelpers.drawContactAO(
            in: &ctx,
            center: CGPoint(x: jRect.midX, y: jRect.maxY + 2),
            rx: jRect.width * 0.52,
            ry: 7,
            dark: dark,
            opacity: 0.85
        )
        ctx.fill(
            Path(roundedRect: jRect.insetBy(dx: -3, dy: -2), cornerRadius: 7),
            with: .color(dark ? Color(hex: 0x2B4457) : Color(hex: 0x56776C))
        )
        let leftP = CGRect(x: jRect.minX, y: jRect.minY, width: jRect.width * 0.495, height: jRect.height)
        let rightP = CGRect(x: jRect.midX + 1, y: jRect.minY, width: jRect.width * 0.495, height: jRect.height)
        for pRect in [leftP, rightP] {
            ctx.fill(
                Path(roundedRect: pRect, cornerRadius: 4),
                with: .color(dark ? Color(hex: 0xE4D8B9) : Color(hex: 0xFFFDF5))
            )
            // Soft ruled lines
            for r in 1...3 {
                let ly = pRect.minY + pRect.height * CGFloat(r) / 4.0
                var line = Path()
                line.move(to: CGPoint(x: pRect.minX + 6, y: ly))
                line.addLine(to: CGPoint(x: pRect.maxX - 6, y: ly))
                ctx.stroke(line, with: .color(Color(hex: 0xBBA988).opacity(0.45)), lineWidth: 0.8)
            }
        }

        if step == 0 {
            // Feather stylus glides right stamping 3 observation cues
            let cueSpots: [(CGPoint, Color)] = [
                (CGPoint(x: leftP.minX + leftP.width * 0.36, y: leftP.midY - 8), Color(hex: 0x6AA87B)),
                (CGPoint(x: leftP.minX + leftP.width * 0.68, y: leftP.midY + 6), Color(hex: 0x8F8AC4)),
                (CGPoint(x: rightP.minX + rightP.width * 0.44, y: rightP.midY - 4), Palette.amber)
            ]
            for (idx, cue) in cueSpots.enumerated() {
                let appear = max(0, min(1, p.action * 1.4 - Double(idx) * 0.30))
                if appear > 0.05 {
                    let r = 4.0 * CGFloat(appear)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: cue.0.x - r, y: cue.0.y - r, width: r * 2, height: r * 2)),
                        with: .color(cue.1.opacity(appear))
                    )
                }
            }
            let penPos = CGPoint(
                x: jRect.minX + jRect.width * (0.20 + CGFloat(p.action) * 0.56),
                y: jRect.midY - 6 + CGFloat(sin(p.action * .pi * 3.0) * 5.0)
            )
            var quill = Path()
            quill.move(to: penPos)
            quill.addQuadCurve(
                to: CGPoint(x: penPos.x - 16, y: penPos.y - 34),
                control: CGPoint(x: penPos.x - 14, y: penPos.y - 16)
            )
            quill.addQuadCurve(
                to: penPos,
                control: CGPoint(x: penPos.x - 2, y: penPos.y - 18)
            )
            quill.closeSubpath()
            ctx.fill(quill, with: .color(dark ? Palette.amber : Color(hex: 0xD2974B)))
        } else {
            // Step 1: 7-bead weekly constellation arch blooms cleanly above spread
            var constellation = Path()
            let count = 7
            var pts: [CGPoint] = []
            for i in 0..<count {
                let frac = CGFloat(i) / CGFloat(count - 1)
                let x = w * (0.31 + frac * 0.38)
                let y = h * (0.43 - sin(frac * .pi) * 0.14)
                pts.append(CGPoint(x: x, y: y))
                if i == 0 { constellation.move(to: pts[0]) } else { constellation.addLine(to: pts[i]) }
            }
            ctx.stroke(
                constellation,
                with: .color((dark ? Palette.amber : Color(hex: 0xC6954B)).opacity(0.55 * min(1, p.action * 1.2))),
                style: StrokeStyle(lineWidth: 1.4, dash: [4, 4])
            )
            for (i, pt) in pts.enumerated() {
                let reveal = max(0, min(1, p.action * 1.4 - Double(i) * 0.12))
                if reveal > 0.05 {
                    let r: CGFloat = (i == 3 ? 6.0 : 4.4) * CGFloat(reveal)
                    let col = i % 2 == 0 ? Palette.amber : Color(hex: dark ? 0x8ED9A4 : 0x6EA77A)
                    ctx.fill(Path(ellipseIn: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)), with: .color(col))
                }
            }
        }
    }
}
