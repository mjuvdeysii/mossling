import SwiftUI

/// A40 (Family Stories & Traditions · 3 Steps):
/// Warm twilight quilted story mat with a low carved wooden tea tray & glowing festival paper lantern:
/// Step 0: Hanging coral lantern & Otto's warm bead softly bathe the family story mat ->
/// Step 1: Familiar folk-song silk ribbons & festive wooden pastry tray glow warmly between Otto and Moss ->
/// Step 2: Curious Moss leans forward toward the lantern leading the tradition through its own questions.
struct SceneA40_FamilyStoriesTraditions: View {
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

            let ottoX = w * 0.28
            let mossX = w * (step == 2 ? 0.68 : 0.73)
            let ottoMood: Mood = step == 0 ? .open : .happy
            let mossMood: Mood = step == 2 ? .wow : (step == 1 ? .happy : .open)
            let ottoLook = CGPoint(x: 0.78, y: 0.15)
            let mossLook = CGPoint(x: -0.75, y: step == 2 ? -0.30 : 0.15)

            let ottoCenter = CGPoint(x: ottoX, y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY * 0.96, flat: flat))
            let mossCenter = CGPoint(x: mossX, y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat))

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.28 : 0.16, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(ottoCenter: ottoCenter, ottoSize: os, ottoState: ottoState, leanDegrees: 3.5, flat: flat)
            let lanternTarget = CGPoint(x: w * 0.50, y: h * 0.38)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    BespokeStageHelpers.drawAtmosphereWash(
                        in: &c, w: size.width, h: size.height,
                        dayTop: Color(hex: 0xFDF4E6), dayBottom: Color(hex: 0xF3DFC2),
                        nightTop: Color(hex: 0x101530), nightBottom: Color(hex: 0x201E3A),
                        dark: dark
                    )
                    c.fill(Path(CGRect(x: 0, y: groundY, width: size.width, height: size.height - groundY)),
                           with: .color(dark ? Color(hex: 0x231E3A) : Color(hex: 0xE2C89F)))

                    // Hanging warm festival paper lantern swaying gently overhead
                    let lx = size.width * 0.50 + CGFloat(sin(p.raw * .pi * 2)) * 4
                    let ly = size.height * 0.25
                    var cord = Path()
                    cord.move(to: CGPoint(x: size.width * 0.50, y: 0))
                    cord.addLine(to: CGPoint(x: lx, y: ly - 16))
                    c.stroke(cord, with: .color(Palette.bead), lineWidth: 1.6)
                    let lRect = CGRect(x: lx - 18, y: ly - 16, width: 36, height: 30)
                    c.fill(Path(ellipseIn: CGRect(x: lx - 34, y: ly - 32, width: 68, height: 64)),
                           with: .radialGradient(Gradient(colors: [Palette.amber.opacity(0.38), .clear]), center: CGPoint(x: lx, y: ly), startRadius: 4, endRadius: 34))
                    c.fill(Path(roundedRect: lRect, cornerRadius: 12), with: .color(Crayon.pink))
                    c.fill(Path(roundedRect: CGRect(x: lx - 8, y: ly + 14, width: 16, height: 4), cornerRadius: 2), with: .color(Palette.bead))

                    // Low carved festival tea & pastry tray centered on the story mat
                    let trayRect = CGRect(x: size.width * 0.41, y: groundY - 12, width: size.width * 0.18, height: 10)
                    c.fill(Path(roundedRect: trayRect, cornerRadius: 4), with: .color(dark ? Color(hex: 0x6B4C33) : Color(hex: 0xB8824E)))
                    c.fill(Path(ellipseIn: CGRect(x: size.width * 0.46, y: groundY - 22, width: 12, height: 10)), with: .color(Crayon.sunflower))
                    c.fill(Path(ellipseIn: CGRect(x: size.width * 0.51, y: groundY - 20, width: 10, height: 8)), with: .color(Crayon.teal))

                    if step >= 1 {
                        BespokeStageHelpers.drawSilkVoiceRibbon(
                            in: &c,
                            from: CGPoint(x: ottoCenter.x + os * 0.22, y: ottoCenter.y - os * 0.05),
                            to: CGPoint(x: mossCenter.x - ms * 0.22, y: mossCenter.y - ms * 0.06),
                            progress: step == 1 ? p.raw : 1.0,
                            waveOffset: p.raw * 4.2,
                            color: Palette.amber,
                            lineWidth: 3.0,
                            dark: dark
                        )
                    }
                }

                LampLightRig(beadPos: beadWorld, targetPoint: lanternTarget, phase: p, dark: dark, flat: flat, layer: .floorPool)

                StoryTheaterActorView(kind: .otto, size: os, mood: ottoMood, look: ottoLook, lid: dark ? 0.28 : 0.16, lean: 3.5, breathTime: ctx.breathTime, isStatic: ctx.isStatic, dark: dark, flat: flat, compact: ctx.compact, lightDirection: CGPoint(x: 0.7, y: -0.7), secondaryLagDegrees: -1.5)
                    .position(ottoCenter)

                StoryTheaterActorView(kind: .moss, size: ms, mood: mossMood, look: mossLook, lid: dark ? 0.10 : 0, lean: step == 2 ? -6.5 : -2.5, breathTime: ctx.breathTime, isStatic: ctx.isStatic, dark: dark, flat: flat, compact: ctx.compact, lightDirection: CGPoint(x: -0.7, y: -0.7), secondaryLagDegrees: 2.0)
                    .position(mossCenter)

                LampLightRig(beadPos: beadWorld, targetPoint: lanternTarget, phase: p, dark: dark, flat: flat, layer: .airCone)
                    .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }
}
