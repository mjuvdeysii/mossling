import SwiftUI

/// A38 (Family Photos & Names · 3 Steps):
/// Cozy linen floor cushion alcove with open cloth-bound family photo album:
/// Step 0: Warm spotlight lands on the open photo album pages showing stylized family silhouettes (zero blush/dots) ->
/// Step 1: Golden connecting wave bridges the album portrait to a glowing framed call/visit frame on the wall ->
/// Step 2: Moss leans in excitedly turning the thick board page with pointing delight.
struct SceneA38_FamilyPhotosNames: View {
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

            let mossX = w * 0.30
            let ottoX = w * 0.74
            let mossMood: Mood = step == 2 ? .happy : (step == 1 ? .open : .open)
            let ottoMood: Mood = step >= 1 ? .happy : .open
            let mossLook = CGPoint(x: 0.75, y: 0.35)
            let ottoLook = CGPoint(x: -0.82, y: 0.30)

            let mossCenter = CGPoint(x: mossX, y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat))
            let ottoCenter = CGPoint(x: ottoX, y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY * 0.96, flat: flat))

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.28 : 0.14, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(ottoCenter: ottoCenter, ottoSize: os, ottoState: ottoState, leanDegrees: -4.0, flat: flat)
            let albumTarget = CGPoint(x: w * 0.50, y: groundY - s * 0.08)

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    BespokeStageHelpers.drawAtmosphereWash(
                        in: &c, w: size.width, h: size.height,
                        dayTop: Color(hex: 0xFAF5EA), dayBottom: Color(hex: 0xEDE2CF),
                        nightTop: Color(hex: 0x0C1327), nightBottom: Color(hex: 0x18233E),
                        dark: dark
                    )
                    c.fill(Path(CGRect(x: 0, y: groundY, width: size.width, height: size.height - groundY)),
                           with: .color(dark ? Color(hex: 0x1B2642) : Color(hex: 0xE2CFAF)))

                    // Framed sunlit memory snapshot on wall (illuminates softly in Step 1 linking calls & visits)
                    let wallFrame = CGRect(x: size.width * 0.42, y: size.height * 0.20, width: s * 0.22, height: s * 0.17)
                    c.fill(Path(roundedRect: wallFrame, cornerRadius: 7), with: .color(dark ? Color(hex: 0x5E4A36) : Color(hex: 0xC89F72)))
                    c.fill(Path(roundedRect: wallFrame.insetBy(dx: 4, dy: 4), cornerRadius: 4),
                           with: .color(dark ? Color(hex: 0x253255) : Color(hex: 0xFFFBF2)))
                    // Minimal geometric stylized family circles (zero blush/dots)
                    c.fill(Path(ellipseIn: CGRect(x: wallFrame.midX - 11, y: wallFrame.midY - 8, width: 10, height: 10)), with: .color(Crayon.caramel))
                    c.fill(Path(ellipseIn: CGRect(x: wallFrame.midX + 1, y: wallFrame.midY - 8, width: 10, height: 10)), with: .color(Crayon.teal))

                    if step >= 1 {
                        var bridge = Path()
                        bridge.move(to: CGPoint(x: wallFrame.midX, y: wallFrame.maxY + 4))
                        bridge.addQuadCurve(to: albumTarget, control: CGPoint(x: size.width * 0.56, y: size.height * 0.54))
                        c.stroke(bridge, with: .color(Palette.bead.opacity(step == 1 ? (0.4 + 0.5 * p.raw) : 0.75)),
                                 style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [5, 5]))
                    }

                    // Open cloth photo album on quilted floor mat
                    let albumRect = CGRect(x: size.width * 0.39, y: groundY - s * 0.10, width: s * 0.24, height: s * 0.10)
                    c.fill(Path(roundedRect: albumRect, cornerRadius: 5), with: .color(Crayon.lilac))
                    let pageL = CGRect(x: albumRect.minX + 4, y: albumRect.minY + 3, width: albumRect.width * 0.45, height: albumRect.height - 6)
                    let pageR = CGRect(x: albumRect.midX + 2, y: albumRect.minY + 3, width: albumRect.width * 0.45, height: albumRect.height - 6)
                    c.fill(Path(roundedRect: pageL, cornerRadius: 3), with: .color(Color(hex: 0xFFFDF7)))
                    c.fill(Path(roundedRect: pageR, cornerRadius: 3), with: .color(Color(hex: 0xFFFDF7)))
                    c.fill(Path(roundedRect: pageL.insetBy(dx: 4, dy: 4), cornerRadius: 2), with: .color(Crayon.pink.opacity(0.65)))
                    c.fill(Path(roundedRect: pageR.insetBy(dx: 4, dy: 4), cornerRadius: 2), with: .color(Crayon.sky.opacity(0.65)))

                    if step == 2 {
                        let flipW = pageR.width * max(0.15, 1.0 - CGFloat(p.raw) * 1.4)
                        let turning = CGRect(x: albumRect.midX - (p.raw > 0.5 ? flipW : 0), y: pageR.minY - CGFloat(sin(p.raw * .pi)) * 8, width: abs(flipW), height: pageR.height)
                        c.fill(Path(roundedRect: turning, cornerRadius: 2), with: .color(Palette.beadLight.opacity(0.9)))
                    }
                }

                LampLightRig(beadPos: beadWorld, targetPoint: albumTarget, phase: p, dark: dark, flat: flat, layer: .floorPool)

                StoryTheaterActorView(kind: .otto, size: os, mood: ottoMood, look: ottoLook, lid: dark ? 0.28 : 0.14, lean: -4.0, breathTime: ctx.breathTime, isStatic: ctx.isStatic, dark: dark, flat: flat, compact: ctx.compact, lightDirection: CGPoint(x: -0.7, y: -0.7), secondaryLagDegrees: 1.5)
                    .position(ottoCenter)

                StoryTheaterActorView(kind: .moss, size: ms, mood: mossMood, look: mossLook, lid: dark ? 0.10 : 0, lean: step == 2 ? 7.5 : 3.5, breathTime: ctx.breathTime, isStatic: ctx.isStatic, dark: dark, flat: flat, compact: ctx.compact, lightDirection: CGPoint(x: 0.7, y: -0.7), secondaryLagDegrees: -2.2)
                    .position(mossCenter)

                LampLightRig(beadPos: beadWorld, targetPoint: albumTarget, phase: p, dark: dark, flat: flat, layer: .airCone)
                    .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }
}
