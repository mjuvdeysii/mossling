import SwiftUI

/// A36 (Picture Story Sequence · 3 Steps):
/// Low birch card rail displaying 3 thick cotton story cards (Sprout, Sun, Flower):
/// Step 0: Otto illuminates cards 1 -> 2 -> 3 left-to-right while telling the true chronological tale ->
/// Step 1: Moss reaches eagerly to slide & reorder cards playfully along the wooden groove ->
/// Step 2: Golden warmth radiates around Moss's unexpected sequence welcoming creative expression.
struct SceneA36_PictureStorySequence: View {
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

            let ms = s * 0.33
            let os = ms * Kind.otto.scale
            let groundY = h * 0.87

            let mossX = w * 0.25
            let ottoX = w * 0.77
            let focusCardIdx = step == 0 ? min(2, Int(p.raw * 3.0)) : (step == 1 ? 1 : 2)
            let cardTargetX = w * (0.37 + CGFloat(focusCardIdx) * 0.13)

            let mossMood: Mood = step == 2 ? .happy : (step == 1 ? .wow : .open)
            let ottoMood: Mood = step == 0 ? .open : .happy
            let mossLook = CGPoint(x: 0.78, y: 0.10)
            let ottoLook = CGPoint(x: -0.82, y: 0.12)

            let mossCenter = CGPoint(x: mossX, y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat))
            let ottoCenter = CGPoint(x: ottoX, y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY * 0.96, flat: flat))

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.28 : 0.16, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(ottoCenter: ottoCenter, ottoSize: os, ottoState: ottoState, leanDegrees: -4.0, flat: flat)
            let targetPt = CGPoint(x: cardTargetX, y: h * 0.56)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    BespokeStageHelpers.drawAtmosphereWash(
                        in: &c, w: size.width, h: size.height,
                        dayTop: Color(hex: 0xFAF6EE), dayBottom: Color(hex: 0xEFE5D2),
                        nightTop: Color(hex: 0x0C1327), nightBottom: Color(hex: 0x172442),
                        dark: dark
                    )
                    c.fill(Path(CGRect(x: 0, y: groundY, width: size.width, height: size.height - groundY)),
                           with: .color(dark ? Color(hex: 0x1A2542) : Color(hex: 0xE3CFAF)))

                    // Low beechwood groove ledge holding the 3 chronological picture cards
                    let railY = h * 0.66
                    let railRect = CGRect(x: size.width * 0.30, y: railY, width: size.width * 0.40, height: 10)
                    c.fill(Path(roundedRect: railRect, cornerRadius: 4), with: .color(dark ? Color(hex: 0x6D5236) : Color(hex: 0xD2AA7A)))

                    let tones: [Color] = step == 2 ? [Crayon.tangerine, Crayon.leaf, Crayon.sunflower] : [Crayon.leaf, Crayon.sunflower, Crayon.pink]
                    for i in 0..<3 {
                        let lift: CGFloat = (i == focusCardIdx && p.isContactWindow) ? 8 : 0
                        let cx = size.width * (0.37 + CGFloat(i) * 0.13)
                        let cardRect = CGRect(x: cx - s * 0.055, y: railY - s * 0.15 - lift, width: s * 0.11, height: s * 0.15)
                        c.fill(Path(roundedRect: cardRect, cornerRadius: 6), with: .color(dark ? Color(hex: 0x263256) : Color(hex: 0xFFFDF8)))
                        c.stroke(Path(roundedRect: cardRect, cornerRadius: 6),
                                 with: .color(i == focusCardIdx ? Palette.bead : Palette.outline.opacity(0.28)),
                                 lineWidth: i == focusCardIdx ? 2.2 : 1.0)
                        c.fill(Path(ellipseIn: CGRect(x: cardRect.midX - 7, y: cardRect.midY - 7, width: 14, height: 14)),
                               with: .color(tones[i]))
                    }
                }

                LampLightRig(beadPos: beadWorld, targetPoint: targetPt, phase: p, dark: dark, flat: flat, layer: .floorPool)

                StoryTheaterActorView(kind: .otto, size: os, mood: ottoMood, look: ottoLook, lid: dark ? 0.28 : 0.16, lean: -4.0, breathTime: ctx.breathTime, isStatic: ctx.isStatic, dark: dark, flat: flat, compact: ctx.compact, lightDirection: CGPoint(x: -0.7, y: -0.7), secondaryLagDegrees: 1.5)
                    .position(ottoCenter)

                StoryTheaterActorView(kind: .moss, size: ms, mood: mossMood, look: mossLook, lid: dark ? 0.10 : 0, lean: step == 1 ? 6.0 : 2.5, breathTime: ctx.breathTime, isStatic: ctx.isStatic, dark: dark, flat: flat, compact: ctx.compact, lightDirection: CGPoint(x: 0.7, y: -0.7), secondaryLagDegrees: -2.0)
                    .position(mossCenter)

                LampLightRig(beadPos: beadWorld, targetPoint: targetPt, phase: p, dark: dark, flat: flat, layer: .airCone)
                    .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }
}
