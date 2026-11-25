import SwiftUI

/// A35 (Socks & Putting Things Away · 4 Steps):
/// Cozy birch entryway bench beside woven shoe/clothing cubby basket:
/// Step 0: Otto shines a focused pool onto the first knitted sock cuff step ->
/// Step 1: Moss chooses to lean forward eagerly toward the coral knit sock ->
/// Step 2: Second sock glides smoothly along a helpful arc into the woven cubby ->
/// Step 3: Warm golden effort praise ripples gently around Moss for sticking with it.
struct SceneA35_SocksPuttingAway: View {
    let ctx: BespokeSceneContext

    var body: some View {
        let step = min(max(0, ctx.stepIndex), 3)
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

            let mossX = w * (step >= 1 ? 0.34 : 0.28)
            let ottoX = w * 0.78
            let mossLean: Double = step == 1 ? 8.0 : (step == 3 ? 2.5 : 4.5)
            let ottoLean: Double = step == 2 ? -6.0 : -3.0

            let mossMood: Mood = step == 3 ? .happy : (step == 1 ? .wow : .open)
            let ottoMood: Mood = step >= 2 ? .happy : .open
            let mossLook = CGPoint(x: 0.72, y: 0.30)
            let ottoLook = CGPoint(x: -0.84, y: 0.28)

            let mossCenter = CGPoint(x: mossX, y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat))
            let ottoCenter = CGPoint(x: ottoX, y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY * 0.96, flat: flat))

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.28 : 0.16, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(ottoCenter: ottoCenter, ottoSize: os, ottoState: ottoState, leanDegrees: ottoLean, flat: flat)
            let targetPt = CGPoint(x: w * (step >= 2 ? 0.58 : 0.48), y: groundY - s * 0.08)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    BespokeStageHelpers.drawAtmosphereWash(
                        in: &c, w: size.width, h: size.height,
                        dayTop: Color(hex: 0xFAF5EC), dayBottom: Color(hex: 0xEDE0CC),
                        nightTop: Color(hex: 0x0C1326), nightBottom: Color(hex: 0x17223D),
                        dark: dark
                    )
                    // Hardwood hallway floor
                    c.fill(Path(CGRect(x: 0, y: groundY, width: size.width, height: size.height - groundY)),
                           with: .color(dark ? Color(hex: 0x1E2845) : Color(hex: 0xDFC49C)))

                    // Woven cubby basket centered-right on the floor (Plane 2)
                    let basketRect = CGRect(x: size.width * 0.50, y: groundY - s * 0.14, width: s * 0.22, height: s * 0.14)
                    c.fill(Path(roundedRect: basketRect, cornerRadius: 8), with: .color(dark ? Color(hex: 0x5A4531) : Color(hex: 0xC89B6C)))

                    // Pair of cozy coral & sky knitted socks moving cleanly from floor to basket
                    let sock1Rect = CGRect(
                        x: step >= 1 ? size.width * 0.43 : size.width * 0.40,
                        y: groundY - 16,
                        width: 22, height: 12
                    )
                    c.fill(Path(roundedRect: sock1Rect, cornerRadius: 5), with: .color(Crayon.pink))

                    let sock2X = step >= 2 ? (size.width * 0.46 + CGFloat(step == 2 ? p.raw : 1.0) * size.width * 0.12) : size.width * 0.45
                    let sock2Y = step == 2 ? groundY - 22 - CGFloat(sin(p.raw * .pi)) * 22 : (step == 3 ? basketRect.minY + 4 : groundY - 12)
                    c.fill(Path(roundedRect: CGRect(x: sock2X, y: sock2Y, width: 22, height: 12), cornerRadius: 5), with: .color(Crayon.sky))
                }

                LampLightRig(beadPos: beadWorld, targetPoint: targetPt, phase: p, dark: dark, flat: flat, layer: .floorPool)

                StoryTheaterActorView(kind: .otto, size: os, mood: ottoMood, look: ottoLook, lid: dark ? 0.28 : 0.16, lean: ottoLean, breathTime: ctx.breathTime, isStatic: ctx.isStatic, dark: dark, flat: flat, compact: ctx.compact, lightDirection: CGPoint(x: -0.7, y: -0.7), secondaryLagDegrees: -ottoLean * 0.3)
                    .position(ottoCenter)

                StoryTheaterActorView(kind: .moss, size: ms, mood: mossMood, look: mossLook, lid: dark ? 0.12 : 0, lean: mossLean, breathTime: ctx.breathTime, isStatic: ctx.isStatic, dark: dark, flat: flat, compact: ctx.compact, lightDirection: CGPoint(x: 0.7, y: -0.7), secondaryLagDegrees: -mossLean * 0.4)
                    .position(mossCenter)

                if step == 3 {
                    Canvas(rendersAsynchronously: false) { c, _ in
                        BespokeStageHelpers.drawPauseHalo(
                            in: &c,
                            center: CGPoint(x: mossCenter.x, y: mossCenter.y - ms * 0.1),
                            baseRadius: ms * 0.48,
                            progress: p.raw,
                            tint: Palette.bead,
                            dark: dark
                        )
                    }
                    .allowsHitTesting(false)
                }

                LampLightRig(beadPos: beadWorld, targetPoint: targetPt, phase: p, dark: dark, flat: flat, layer: .airCone)
                    .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }
}
