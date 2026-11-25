import SwiftUI

/// A39 (Stop, Look & Hold Hands · 3 Steps):
/// Safe indoor playroom floor mat printed with painted beech crosswalk stripes & miniature stop-sign post:
/// Step 0: Otto pauses steadfastly behind the crosswalk edge modeling "stop, look, steady" ->
/// Step 1: Bright painted wooden toy cars roll briskly across the mat track while both wait behind the curb ->
/// Step 2: Protective amber guardian pool wraps Otto & Moss as they glide serenely across the clear crosswalk together.
struct SceneA39_RoadSafetyPractice: View {
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

            let ms = s * 0.32
            let os = ms * Kind.otto.scale
            let groundY = h * 0.87

            let crossAdvance = step == 2 ? CGFloat(p.raw) * w * 0.28 : 0
            let ottoX = w * 0.26 + crossAdvance
            let mossX = w * 0.40 + crossAdvance

            let ottoLook = step == 1 ? CGPoint(x: sin(p.raw * .pi * 2) * 0.65, y: 0.24) : CGPoint(x: 0.65, y: 0.25)
            let mossLook = step == 1 ? CGPoint(x: sin(p.raw * .pi * 2) * 0.65, y: 0.28) : CGPoint(x: 0.65, y: 0.20)
            let mossMood: Mood = step == 2 ? .happy : (step == 1 ? .wow : .open)
            let ottoMood: Mood = step == 2 ? .happy : .open

            let mossCenter = CGPoint(x: mossX, y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat))
            let ottoCenter = CGPoint(x: ottoX, y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY * 0.97, flat: flat))

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.26 : 0.14, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(ottoCenter: ottoCenter, ottoSize: os, ottoState: ottoState, leanDegrees: 2.0, flat: flat)
            let matTarget = CGPoint(x: w * 0.62, y: groundY - s * 0.04)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    BespokeStageHelpers.drawAtmosphereWash(
                        in: &c, w: size.width, h: size.height,
                        dayTop: Color(hex: 0xFAF6EE), dayBottom: Color(hex: 0xEAE3D3),
                        nightTop: Color(hex: 0x0C1427), nightBottom: Color(hex: 0x182542),
                        dark: dark
                    )
                    // Play-mat road strip + crisp painted white zebra crosswalk stripes
                    c.fill(Path(CGRect(x: 0, y: groundY - 8, width: size.width, height: size.height - groundY + 8)),
                           with: .color(dark ? Color(hex: 0x222E4E) : Color(hex: 0xD7D1C5)))
                    for i in 0..<4 {
                        let stripe = CGRect(x: size.width * (0.48 + CGFloat(i) * 0.06), y: groundY - 4, width: 12, height: 6)
                        c.fill(Path(roundedRect: stripe, cornerRadius: 2), with: .color(.white.opacity(dark ? 0.65 : 0.92)))
                    }

                    // Miniature red wooden Stop-sign post on safe sidewalk edge
                    let postX = size.width * 0.45
                    c.fill(Path(CGRect(x: postX - 2, y: groundY - s * 0.26, width: 4, height: s * 0.26)), with: .color(Color(hex: 0xC69A6B)))
                    let signR = s * 0.055
                    c.fill(Path(ellipseIn: CGRect(x: postX - signR, y: groundY - s * 0.26 - signR, width: signR * 2, height: signR * 2)),
                           with: .color(Crayon.pink))

                    // Rolling beechwood toy car gliding smoothly in Step 1 (resting safely off to right in Step 2)
                    let carX: CGFloat = step == 1 ? (size.width * 0.90 - CGFloat(p.raw) * size.width * 0.44) : (step == 0 ? size.width * 0.84 : size.width * 0.86)
                    let carRect = CGRect(x: carX - 18, y: groundY - 18, width: 36, height: 14)
                    c.fill(Path(roundedRect: carRect, cornerRadius: 5), with: .color(step == 1 ? Crayon.tangerine : Crayon.sky))
                    c.fill(Path(ellipseIn: CGRect(x: carX - 13, y: groundY - 6, width: 8, height: 8)), with: .color(Color(hex: 0x3D2E20)))
                    c.fill(Path(ellipseIn: CGRect(x: carX + 5, y: groundY - 6, width: 8, height: 8)), with: .color(Color(hex: 0x3D2E20)))

                    if step == 2 {
                        BespokeStageHelpers.drawPauseHalo(
                            in: &c,
                            center: CGPoint(x: (ottoCenter.x + mossCenter.x) / 2, y: groundY - ms * 0.35),
                            baseRadius: ms * 0.85,
                            progress: p.raw,
                            tint: Palette.amber,
                            dark: dark
                        )
                    }
                }

                LampLightRig(beadPos: beadWorld, targetPoint: matTarget, phase: p, dark: dark, flat: flat, layer: .floorPool)

                StoryTheaterActorView(kind: .otto, size: os, mood: ottoMood, look: ottoLook, lid: dark ? 0.26 : 0.14, lean: 2.0, breathTime: ctx.breathTime, isStatic: ctx.isStatic, dark: dark, flat: flat, compact: ctx.compact, lightDirection: CGPoint(x: 0.7, y: -0.7), secondaryLagDegrees: -1.0)
                    .position(ottoCenter)

                StoryTheaterActorView(kind: .moss, size: ms, mood: mossMood, look: mossLook, lid: dark ? 0.10 : 0, lean: step == 2 ? 3.5 : 0, breathTime: ctx.breathTime, isStatic: ctx.isStatic, dark: dark, flat: flat, compact: ctx.compact, lightDirection: CGPoint(x: 0.7, y: -0.7), secondaryLagDegrees: -1.5)
                    .position(mossCenter)

                LampLightRig(beadPos: beadWorld, targetPoint: matTarget, phase: p, dark: dark, flat: flat, layer: .airCone)
                    .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }
}
