import SwiftUI

/// A33 (Building Big Blocks Together · 3 Steps):
/// Expansive warm sunlit playroom mat with left & right beechwood block baskets:
/// Step 0: Moss & Otto each stand beside a block basket picking chamfered giant beech blocks ->
/// Step 1: Soft planning blueprint arc & amber bead pool glow over the center build zone as piers rise ->
/// Step 2: Moss places the arched keystone block on top cleanly while Otto shines calm encouragement from behind.
struct SceneA33_BuildingBigBlocks: View {
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
            let groundY = h * 0.87
            let ottoGroundY = h * 0.80

            let mossX = w * (step == 0 ? 0.25 : 0.30)
            let ottoX = w * 0.74
            let mossHop: CGFloat = (step == 2 && p.isContactWindow)
                ? CGFloat(sin(min(1, max(0, (p.raw - 0.35) / 0.45)) * .pi)) * ms * 0.10
                : 0
            let mossLean: Double = step == 2 ? 7.0 : (step == 1 ? 5.0 : 2.5)
            let ottoLean: Double = step == 1 ? -4.5 : -2.0

            let mossMood: Mood = step == 2 ? .happy : (step == 1 ? .open : .open)
            let ottoMood: Mood = step == 2 ? .happy : .open
            let mossLook = CGPoint(x: 0.72, y: step == 2 ? -0.22 : 0.22)
            let ottoLook = CGPoint(x: -0.82, y: step == 2 ? -0.18 : 0.24)

            let mossCenter = CGPoint(x: mossX, y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat, lift: mossHop))
            let ottoCenter = CGPoint(x: ottoX, y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: ottoGroundY, flat: flat))

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.30 : 0.16, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(ottoCenter: ottoCenter, ottoSize: os, ottoState: ottoState, leanDegrees: ottoLean, flat: flat)
            let buildTarget = CGPoint(x: w * 0.50, y: groundY - s * (step == 2 ? 0.24 : 0.12))

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    BespokeStageHelpers.drawAtmosphereWash(
                        in: &c, w: size.width, h: size.height,
                        dayTop: Color(hex: 0xFAF6EB), dayBottom: Color(hex: 0xECE2CC),
                        nightTop: Color(hex: 0x0C1327), nightBottom: Color(hex: 0x172340),
                        dark: dark
                    )
                    // Playroom wainscoting + soft quilted floor mat
                    c.fill(Path(CGRect(x: 0, y: groundY, width: size.width, height: size.height - groundY)),
                           with: .color(dark ? Color(hex: 0x1A2542) : Color(hex: 0xE2D0AF)))
                    let matRect = CGRect(x: size.width * 0.12, y: groundY - 6, width: size.width * 0.76, height: 14)
                    c.fill(Path(ellipseIn: matRect), with: .color(dark ? Color(hex: 0x263458) : Color(hex: 0xF5ECD8)))
                    // Twin side baskets holding reserve blocks
                    for bx in [size.width * 0.14, size.width * 0.86] {
                        let bRect = CGRect(x: bx - 18, y: groundY - 18, width: 36, height: 18)
                        c.fill(Path(roundedRect: bRect, cornerRadius: 5), with: .color(dark ? Color(hex: 0x4A3A2C) : Color(hex: 0xC69A6B)))
                    }
                }

                LampLightRig(beadPos: beadWorld, targetPoint: buildTarget, phase: p, dark: dark, flat: flat, layer: .floorPool)

                StoryTheaterActorView(kind: .otto, size: os, mood: ottoMood, look: ottoLook, lid: dark ? 0.30 : 0.16, lean: ottoLean, breathTime: ctx.breathTime, isStatic: ctx.isStatic, dark: dark, flat: flat, compact: ctx.compact, lightDirection: CGPoint(x: -0.65, y: -0.76), secondaryLagDegrees: -ottoLean * 0.3)
                    .position(ottoCenter)

                StoryTheaterActorView(kind: .moss, size: ms, mood: mossMood, look: mossLook, lid: dark ? 0.12 : 0, lean: mossLean, hopLift: mossHop / max(1, ms), hopping: step == 2 && p.isContactWindow, breathTime: ctx.breathTime, isStatic: ctx.isStatic, dark: dark, flat: flat, compact: ctx.compact, lightDirection: CGPoint(x: 0.65, y: -0.76), secondaryLagDegrees: -mossLean * 0.4)
                    .position(mossCenter)

                // Giant bevelled beechwood archway blocks progressing step 0 -> step 2
                Canvas(rendersAsynchronously: false) { c, size in
                    let cx = size.width * 0.50
                    let blockW: CGFloat = s * 0.11
                    let pierH: CGFloat = s * 0.15
                    let archSpan: CGFloat = s * 0.24
                    let pierColor = dark ? Color(hex: 0x9C7850) : Color(hex: 0xDEC092)
                    let accentBlock = step == 2 ? Crayon.teal : Crayon.sunflower

                    // Contact AO on mat under tower
                    c.fill(Path(ellipseIn: CGRect(x: cx - archSpan * 0.6, y: groundY - 4, width: archSpan * 1.2, height: 9)),
                           with: .color(.black.opacity(dark ? 0.35 : 0.13)))

                    if step >= 1 {
                        // Left & Right wooden bridge piers grounded firmly on mat
                        let dropOffset: CGFloat = step == 1 ? CGFloat(max(0.0, 1.0 - p.raw * 1.6)) * s * 0.08 : 0
                        let leftPier = CGRect(x: cx - archSpan * 0.46, y: groundY - pierH - dropOffset, width: blockW, height: pierH)
                        let rightPier = CGRect(x: cx + archSpan * 0.46 - blockW, y: groundY - pierH - dropOffset, width: blockW, height: pierH)
                        c.fill(Path(roundedRect: leftPier, cornerRadius: 5), with: .color(pierColor))
                        c.fill(Path(roundedRect: rightPier, cornerRadius: 5), with: .color(pierColor))

                        if step == 1 {
                            // Dotted planning guide arc linking pier tops
                            var guide = Path()
                            guide.move(to: CGPoint(x: leftPier.midX, y: leftPier.minY - 6))
                            guide.addQuadCurve(to: CGPoint(x: rightPier.midX, y: rightPier.minY - 6), control: CGPoint(x: cx, y: groundY - pierH - s * 0.14))
                            c.stroke(guide, with: .color(Palette.bead.opacity(0.65)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4]))
                        }
                    } else {
                        // Step 0: two loose blocks resting beside Moss & center waiting to be picked
                        let b1 = CGRect(x: cx - s * 0.14, y: groundY - blockW * 0.72, width: blockW, height: blockW * 0.72)
                        let b2 = CGRect(x: cx + s * 0.04, y: groundY - blockW * 0.72, width: blockW, height: blockW * 0.72)
                        c.fill(Path(roundedRect: b1, cornerRadius: 5), with: .color(pierColor))
                        c.fill(Path(roundedRect: b2, cornerRadius: 5), with: .color(Crayon.sunflower.opacity(0.85)))
                    }

                    if step == 2 {
                        // Top spanning beam + final triangular arch capstone lowering smoothly into place
                        let liftY: CGFloat = CGFloat(max(0.0, 1.0 - p.raw * 1.5)) * s * 0.14
                        let beamRect = CGRect(x: cx - archSpan * 0.52, y: groundY - pierH - s * 0.075, width: archSpan * 1.04, height: s * 0.075)
                        c.fill(Path(roundedRect: beamRect, cornerRadius: 6), with: .color(accentBlock))

                        let capRect = CGRect(x: cx - s * 0.075, y: beamRect.minY - s * 0.095 - liftY, width: s * 0.15, height: s * 0.095)
                        var tri = Path()
                        tri.move(to: CGPoint(x: capRect.midX, y: capRect.minY))
                        tri.addLine(to: CGPoint(x: capRect.maxX, y: capRect.maxY))
                        tri.addLine(to: CGPoint(x: capRect.minX, y: capRect.maxY))
                        tri.closeSubpath()
                        c.fill(tri, with: .color(Crayon.tangerine))

                        if p.raw > 0.55 {
                            BespokeStageHelpers.drawPauseHalo(
                                in: &c, center: CGPoint(x: cx, y: beamRect.midY),
                                baseRadius: s * 0.18, progress: (p.raw - 0.55) / 0.45,
                                tint: Palette.bead, dark: dark
                            )
                        }
                    }
                }
                .allowsHitTesting(false)

                LampLightRig(beadPos: beadWorld, targetPoint: buildTarget, phase: p, dark: dark, flat: flat, layer: .airCone)
                    .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }
}
