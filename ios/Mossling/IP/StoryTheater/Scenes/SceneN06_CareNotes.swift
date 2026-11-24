import SwiftUI

/// N06 (Awake Activity Cues & Care Notes · 2 Steps):
/// True 3-plane evening nursery study:
/// Layer 1: Calm nursery backdrop & window frame ->
/// Layer 2: Otto & Moss seated BEHIND the foreground study desk (upper bodies ~72% visible above deskY) ->
/// Layer 3: Foreground birch study desk IN FRONT of actor lower bodies with open Starlight Journal & grounded wooden pencil:
/// Step 0: 3 visual observation medallions stamp cleanly onto the open page ->
/// Step 1: 7-bead weekly constellation blooms above spread + silk voice ribbon Otto <-> Moss.
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

            let ms = s * 0.31
            let os = s * 0.36
            let deskY = h * 0.67
            let ottoGround = deskY + os * 0.24
            let mossGround = deskY + ms * 0.24

            let ottoX = w * 0.24
            let mossX = w * 0.77

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: ottoGround, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: mossGround, flat: flat)
            )

            let ottoLook = step == 0 ? CGPoint(x: 0.65, y: 0.42) : CGPoint(x: 0.58, y: -0.22)
            let mossLook = step == 0 ? CGPoint(x: -0.78, y: 0.24) : CGPoint(x: -0.72, y: -0.22)
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
            let journalCenter = CGPoint(x: w * 0.50, y: deskY + h * 0.13)

            ZStack {
                // Plane 1: Calm nursery backdrop & window
                Canvas(rendersAsynchronously: false) { c, size in
                    drawNurseryBackdrop(in: &c, w: size.width, h: size.height, deskY: deskY, dark: dark, flat: flat)
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: journalCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .floorPool
                )

                // Plane 2: Actors seated BEHIND foreground desk
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

                // Plane 3: Foreground birch desk + open Starlight Journal + grounded pencil & constellation
                Canvas(rendersAsynchronously: false) { c, size in
                    drawForegroundDeskAndJournal(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        deskY: deskY,
                        ottoVoice: CGPoint(x: ottoCenter.x + os * 0.18, y: ottoCenter.y - os * 0.08),
                        mossEar: CGPoint(x: mossCenter.x - ms * 0.18, y: mossCenter.y - ms * 0.08),
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
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawNurseryBackdrop(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, deskY: CGFloat, dark: Bool, flat: Bool) {
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
        if flat {
            GhibliDrawHelpers.drawKomorebiCanopy(in: &ctx, w: w, h: h, swayOffset: 0, dark: dark)
        }
        // Subtle wainscot line just behind desk height
        let wainscot = Path(CGRect(x: 0, y: deskY - 12, width: w, height: 14))
        ctx.fill(wainscot, with: .color((dark ? Color(hex: 0x1D2944) : Color(hex: 0xE6DAC3)).opacity(0.65)))
    }

    private func drawForegroundDeskAndJournal(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        deskY: CGFloat,
        ottoVoice: CGPoint,
        mossEar: CGPoint,
        step: Int,
        p: LivingPhaseSample,
        flat: Bool,
        dark: Bool
    ) {
        // Level foreground birch study desk spanning across bottom front of scene
        let deskBounds = CGRect(x: -6, y: deskY, width: w + 12, height: h - deskY + 8)
        let desk = Path(deskBounds)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: desk,
                bounds: deskBounds,
                light: dark ? Color(hex: 0x392C22) : Color(hex: 0xE6C38E),
                rich: dark ? Color(hex: 0x261D17) : Color(hex: 0xC69A61),
                pencilOutline: (dark ? Color(hex: 0x6E5641) : Color(hex: 0x8F683B)).opacity(0.48),
                lineWidth: 1.15
            )
        } else {
            PixarDrawHelpers.drawBeechwood(in: &ctx, path: desk, bounds: deskBounds, dark: dark, warmth: 0.65, grainLines: 3)
        }

        // Desk top beveled rim shadow
        ctx.fill(
            Path(CGRect(x: 0, y: deskY, width: w, height: 3)),
            with: .color((dark ? Color.white : Color(hex: 0xFFF4DC)).opacity(dark ? 0.14 : 0.45))
        )

        // Open leather-and-linen Starlight Journal resting squarely on foreground desk
        let jRect = CGRect(x: w * 0.27, y: deskY + h * 0.04, width: w * 0.46, height: h * 0.21)
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
            for r in 1...3 {
                let ly = pRect.minY + pRect.height * CGFloat(r) / 4.0
                var line = Path()
                line.move(to: CGPoint(x: pRect.minX + 6, y: ly))
                line.addLine(to: CGPoint(x: pRect.maxX - 6, y: ly))
                ctx.stroke(line, with: .color(Color(hex: 0xBBA988).opacity(0.45)), lineWidth: 0.8)
            }
        }

        // Grounded beechwood pencil resting quietly beside right journal cover (no ghostly floating quill)
        let pencilCenter = CGPoint(x: jRect.maxX + 16, y: jRect.midY + 6)
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: pencilCenter.x + 1, y: pencilCenter.y + 12), rx: 4, ry: 2.5, dark: dark)
        var penCtx = ctx
        penCtx.translateBy(x: pencilCenter.x, y: pencilCenter.y)
        penCtx.rotate(by: .degrees(12))
        let barrel = CGRect(x: -3, y: -14, width: 6, height: 24)
        penCtx.fill(Path(roundedRect: barrel, cornerRadius: 2), with: .color(dark ? Palette.amber : Crayon.caramel))
        var tip = Path()
        tip.move(to: CGPoint(x: -2.8, y: -14))
        tip.addLine(to: CGPoint(x: 0, y: -20))
        tip.addLine(to: CGPoint(x: 2.8, y: -14))
        tip.closeSubpath()
        penCtx.fill(tip, with: .color(Color(hex: 0xEFE1C0)))

        if step == 0 {
            // 3 distinct Montessori cue stamps: sage active eye, lilac tired moon, amber caregiver bead
            let cueSpots: [(CGPoint, Color)] = [
                (CGPoint(x: leftP.minX + leftP.width * 0.36, y: leftP.midY - 8), Color(hex: 0x6AA87B)),
                (CGPoint(x: leftP.minX + leftP.width * 0.68, y: leftP.midY + 6), Color(hex: 0x8F8AC4)),
                (CGPoint(x: rightP.minX + rightP.width * 0.48, y: rightP.midY - 2), Palette.amber)
            ]
            for (idx, cue) in cueSpots.enumerated() {
                let appear = max(0, min(1, p.action * 1.4 - Double(idx) * 0.30))
                if appear > 0.05 {
                    let r = 4.6 * CGFloat(appear)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: cue.0.x - r, y: cue.0.y - r, width: r * 2, height: r * 2)),
                        with: .color(cue.1.opacity(appear))
                    )
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: cue.0.x - r * 1.45, y: cue.0.y - r * 1.45, width: r * 2.9, height: r * 2.9)),
                        with: .color(cue.1.opacity(appear * 0.45)),
                        lineWidth: 1.0
                    )
                }
            }
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: CGPoint(x: rightP.minX + rightP.width * 0.48, y: rightP.midY - 2),
                pulse: p.contact,
                radius: min(w, h) * 0.08,
                color: Palette.amber
            )
        } else {
            // Step 1: 7-bead weekly constellation arch blooms cleanly above spread + weekly discussion voice ribbon
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
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoVoice,
                to: mossEar,
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Palette.amber,
                lineWidth: 2.2,
                dark: dark
            )
        }
    }
}
