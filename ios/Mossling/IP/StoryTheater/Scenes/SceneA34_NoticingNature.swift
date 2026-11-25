import SwiftUI

/// A34 (Noticing Nature Together · 3 Steps):
/// Sunlit garden stepping-stone trail flanked by wind-dappled foliage and drifting cumulus clouds:
/// Step 0: Moss & Otto walk/hop along a familiar curving flagstone path spotting floating clouds and canopy leaves ->
/// Step 1: Soft wind sweeps drifting clouds & fluttering leaves as Otto illuminates a gliding meadow bird ->
/// Step 2: Moss pauses enthusiastically beside a blooming golden dandelion on the path edge while Otto stays calmly beside.
struct SceneA34_NoticingNature: View {
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

            let progressShift = step == 0 ? CGFloat(p.raw) * w * 0.05 : (step == 1 ? w * 0.06 : w * 0.10)
            let mossX = w * 0.28 + progressShift
            let ottoX = w * 0.72 - progressShift * 0.35
            let mossLook = step == 2 ? CGPoint(x: 0.35, y: 0.55) : CGPoint(x: 0.45, y: -0.65)
            let ottoLook = step == 2 ? CGPoint(x: -0.78, y: 0.48) : CGPoint(x: -0.45, y: -0.58)
            let mossMood: Mood = step == 2 ? .happy : (step == 1 ? .wow : .open)
            let ottoMood: Mood = step == 0 ? .open : .happy

            let mossCenter = CGPoint(x: mossX, y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat))
            let ottoCenter = CGPoint(x: ottoX, y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY * 0.97, flat: flat))

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.28 : 0.14, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(ottoCenter: ottoCenter, ottoSize: os, ottoState: ottoState, leanDegrees: -3.0, flat: flat)
            let focusTarget = step == 2 ? CGPoint(x: mossX + s * 0.16, y: groundY - s * 0.08) : CGPoint(x: w * 0.48, y: h * 0.24)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    BespokeStageHelpers.drawAtmosphereWash(
                        in: &c, w: size.width, h: size.height,
                        dayTop: Color(hex: 0xE2F3EA), dayBottom: Color(hex: 0xF5F6E4),
                        nightTop: Color(hex: 0x0B1528), nightBottom: Color(hex: 0x16293B),
                        dark: dark
                    )

                    // Soft rolling meadow hills
                    var hill = Path()
                    hill.move(to: CGPoint(x: 0, y: groundY * 0.88))
                    hill.addQuadCurve(to: CGPoint(x: size.width, y: groundY * 0.84), control: CGPoint(x: size.width * 0.52, y: groundY * 0.72))
                    hill.addLine(to: CGPoint(x: size.width, y: size.height))
                    hill.addLine(to: CGPoint(x: 0, y: size.height))
                    hill.closeSubpath()
                    c.fill(hill, with: .color(Crayon.leaf.opacity(dark ? 0.28 : 0.36)))

                    // Winding garden stone footpath
                    var path = Path()
                    path.move(to: CGPoint(x: size.width * 0.08, y: size.height))
                    path.addQuadCurve(to: CGPoint(x: size.width * 0.88, y: groundY * 0.90), control: CGPoint(x: size.width * 0.44, y: groundY * 0.88))
                    c.stroke(path, with: .color(dark ? Color(hex: 0x35445E) : Color(hex: 0xEFE2C8)), style: StrokeStyle(lineWidth: 26, lineCap: .round))

                    // Drifting clouds & gliding songbird in Step 0-1 sky
                    let cloudShift = CGFloat(p.raw) * 18.0
                    for (cx, cy, cw) in [(size.width * 0.24 + cloudShift, size.height * 0.18, 52.0), (size.width * 0.72 - cloudShift * 0.6, size.height * 0.24, 44.0)] {
                        c.fill(Path(roundedRect: CGRect(x: cx - cw / 2, y: cy, width: cw, height: 18), cornerRadius: 9),
                               with: .color((dark ? Color(hex: 0x6F88B0) : .white).opacity(dark ? 0.26 : 0.82)))
                    }

                    if step >= 1 {
                        let birdX = size.width * (0.28 + CGFloat(p.raw) * 0.36)
                        let birdY = size.height * (0.22 - CGFloat(sin(p.raw * .pi)) * 0.05)
                        var wing = Path()
                        wing.move(to: CGPoint(x: birdX - 10, y: birdY))
                        wing.addQuadCurve(to: CGPoint(x: birdX, y: birdY + 3), control: CGPoint(x: birdX - 5, y: birdY - 6))
                        wing.addQuadCurve(to: CGPoint(x: birdX + 10, y: birdY), control: CGPoint(x: birdX + 5, y: birdY - 6))
                        c.stroke(wing, with: .color(dark ? Palette.lampInk : Color(hex: 0x3B4D54)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    }

                    // Swirling emerald leaves drifting cleanly through air in Step 1
                    for idx in 0..<4 {
                        let lx = size.width * (0.22 + CGFloat(idx) * 0.18) + CGFloat(sin(p.raw * .pi * 2 + Double(idx))) * 10
                        let ly = size.height * (0.28 + CGFloat(idx % 2) * 0.10) + CGFloat(p.raw) * (step == 1 ? 26 : 8)
                        c.fill(Path(ellipseIn: CGRect(x: lx, y: ly, width: 9, height: 5)), with: .color(Crayon.leaf.opacity(dark ? 0.65 : 0.85)))
                    }

                    // Golden meadow flower where Moss lingers in Step 2
                    let fx = mossX + s * 0.18
                    let fy = groundY - 12
                    var stem = Path()
                    stem.move(to: CGPoint(x: fx, y: groundY + 4))
                    stem.addLine(to: CGPoint(x: fx, y: fy))
                    c.stroke(stem, with: .color(Crayon.leaf), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    c.fill(Path(ellipseIn: CGRect(x: fx - 9, y: fy - 9, width: 18, height: 18)),
                           with: .color(Palette.bead.opacity(step == 2 ? 0.95 : 0.72)))
                }

                LampLightRig(beadPos: beadWorld, targetPoint: focusTarget, phase: p, dark: dark, flat: flat, layer: .floorPool)

                StoryTheaterActorView(kind: .otto, size: os, mood: ottoMood, look: ottoLook, lid: dark ? 0.28 : 0.14, lean: -3.0, breathTime: ctx.breathTime, isStatic: ctx.isStatic, dark: dark, flat: flat, compact: ctx.compact, lightDirection: CGPoint(x: -0.4, y: -0.9), secondaryLagDegrees: 1.5)
                    .position(ottoCenter)

                StoryTheaterActorView(kind: .moss, size: ms, mood: mossMood, look: mossLook, lid: dark ? 0.10 : 0, lean: step == 2 ? 5.5 : 2.0, breathTime: ctx.breathTime, isStatic: ctx.isStatic, dark: dark, flat: flat, compact: ctx.compact, lightDirection: CGPoint(x: 0.4, y: -0.9), secondaryLagDegrees: -1.8)
                    .position(mossCenter)

                LampLightRig(beadPos: beadWorld, targetPoint: focusTarget, phase: p, dark: dark, flat: flat, layer: .airCone)
                    .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }
}
