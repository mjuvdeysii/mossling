import SwiftUI

/// A37 (Sharing Two Languages Naturally · 3 Steps):
/// Cozy woven circular rug featuring a wooden pear & picture book:
/// Step 0: Warm golden home-language silk wave flows gently from Otto while reading together ->
/// Step 1: A second seafoam teal musical cadence ribbon weaves naturally through book & song ->
/// Step 2: Moss leans in cheerfully responding in whichever cadence feels natural as dual ribbons meet.
struct SceneA37_TwoLanguagesNaturally: View {
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

            let ottoX = w * 0.27
            let mossX = w * 0.72
            let ottoMood: Mood = step == 2 ? .happy : .open
            let mossMood: Mood = step == 2 ? .happy : (step == 1 ? .wow : .open)
            let ottoLook = CGPoint(x: 0.76, y: 0.20)
            let mossLook = CGPoint(x: -0.78, y: 0.22)

            let ottoCenter = CGPoint(x: ottoX, y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY * 0.96, flat: flat))
            let mossCenter = CGPoint(x: mossX, y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat))

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.26 : 0.14, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(ottoCenter: ottoCenter, ottoSize: os, ottoState: ottoState, leanDegrees: 4.0, flat: flat)
            let bookPt = CGPoint(x: w * 0.50, y: groundY - s * 0.08)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    BespokeStageHelpers.drawAtmosphereWash(
                        in: &c, w: size.width, h: size.height,
                        dayTop: Color(hex: 0xFAF6EC), dayBottom: Color(hex: 0xECE4D2),
                        nightTop: Color(hex: 0x0C1327), nightBottom: Color(hex: 0x172441),
                        dark: dark
                    )
                    c.fill(Path(CGRect(x: 0, y: groundY, width: size.width, height: size.height - groundY)),
                           with: .color(dark ? Color(hex: 0x1A2542) : Color(hex: 0xE2D0B0)))
                    // Braided round story rug
                    c.fill(Path(ellipseIn: CGRect(x: size.width * 0.14, y: groundY - 8, width: size.width * 0.72, height: 18)),
                           with: .color(dark ? Color(hex: 0x28365A) : Color(hex: 0xEFE1C4)))

                    // Open picture book & wooden pear centered on the rug
                    let bookRect = CGRect(x: size.width * 0.41, y: groundY - s * 0.08, width: s * 0.18, height: s * 0.08)
                    c.fill(Path(roundedRect: bookRect, cornerRadius: 4), with: .color(Crayon.caramel))
                    c.fill(Path(roundedRect: bookRect.insetBy(dx: 3, dy: 2), cornerRadius: 3), with: .color(Color(hex: 0xFFFBF2)))
                    c.fill(Path(ellipseIn: CGRect(x: size.width * 0.48, y: groundY - s * 0.13, width: s * 0.055, height: s * 0.065)),
                           with: .color(Crayon.leaf))
                }

                LampLightRig(beadPos: beadWorld, targetPoint: bookPt, phase: p, dark: dark, flat: flat, layer: .floorPool)

                StoryTheaterActorView(kind: .otto, size: os, mood: ottoMood, look: ottoLook, lid: dark ? 0.26 : 0.14, lean: 4.0, breathTime: ctx.breathTime, isStatic: ctx.isStatic, dark: dark, flat: flat, compact: ctx.compact, lightDirection: CGPoint(x: 0.7, y: -0.7), secondaryLagDegrees: -1.5)
                    .position(ottoCenter)

                StoryTheaterActorView(kind: .moss, size: ms, mood: mossMood, look: mossLook, lid: dark ? 0.10 : 0, lean: step == 2 ? -5.0 : -2.5, breathTime: ctx.breathTime, isStatic: ctx.isStatic, dark: dark, flat: flat, compact: ctx.compact, lightDirection: CGPoint(x: -0.7, y: -0.7), secondaryLagDegrees: 1.8)
                    .position(mossCenter)

                Canvas(rendersAsynchronously: false) { c, size in
                    let voiceStart = CGPoint(x: ottoCenter.x + os * 0.22, y: ottoCenter.y - os * 0.04)
                    let voiceEnd = CGPoint(x: mossCenter.x - ms * 0.22, y: mossCenter.y - ms * 0.08)

                    BespokeStageHelpers.drawSilkVoiceRibbon(
                        in: &c,
                        from: voiceStart,
                        to: voiceEnd,
                        progress: step == 0 ? p.raw : 1.0,
                        waveOffset: p.raw * 4.0,
                        color: Palette.amber,
                        lineWidth: 3.2,
                        dark: dark
                    )

                    if step >= 1 {
                        BespokeStageHelpers.drawSilkVoiceRibbon(
                            in: &c,
                            from: CGPoint(x: voiceStart.x, y: voiceStart.y - 16),
                            to: CGPoint(x: voiceEnd.x, y: voiceEnd.y - 16),
                            progress: step == 1 ? p.raw : 1.0,
                            waveOffset: p.raw * 4.5 + 1.4,
                            color: Crayon.teal,
                            lineWidth: 2.8,
                            dark: dark
                        )
                    }

                    if step == 2 {
                        BespokeStageHelpers.drawSilkVoiceRibbon(
                            in: &c,
                            from: CGPoint(x: mossCenter.x - ms * 0.16, y: mossCenter.y + 4),
                            to: CGPoint(x: ottoCenter.x + os * 0.16, y: ottoCenter.y + 4),
                            progress: p.raw,
                            waveOffset: -p.raw * 4.0,
                            color: Crayon.sunflower,
                            lineWidth: 2.6,
                            dark: dark
                        )
                    }
                }
                .allowsHitTesting(false)

                LampLightRig(beadPos: beadWorld, targetPoint: bookPt, phase: p, dark: dark, flat: flat, layer: .airCone)
                    .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }
}
