import SwiftUI

/// A05 (Following Gentle Sounds · 2 Steps):
/// Curved sunlit bay-window alcove with hanging brass-and-beech handbell at upper-left emitting
/// concentric golden acoustic arcs across Moss's visual field (Step 0: gentle natural head turn ->
/// Step 1: bell settles peacefully as Otto echoes warmth without testing).
struct SceneA05_SoundDirection: View {
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

            let ms = s * 0.38
            let os = ms * Kind.otto.scale
            let groundMoss = h * 0.855
            let groundOtto = h * 0.855

            let bellPivot = CGPoint(x: w * 0.24, y: h * 0.08)
            let bellPendulumAngle: Double = step == 0
                ? sin(p.action * .pi * 3.0) * 18.0 * (1.0 - p.hold * 0.75)
                : sin(p.raw * .pi * 2.0) * 3.5 * (1.0 - p.action * 0.7)
            let chordLen = h * 0.24
            let bellTip = CGPoint(
                x: bellPivot.x + CGFloat(sin(bellPendulumAngle * .pi / 180.0)) * chordLen,
                y: bellPivot.y + CGFloat(cos(bellPendulumAngle * .pi / 180.0)) * chordLen
            )

            let mossX = w * 0.56
            let ottoX = w * 0.22
            let turnProgress = step == 0 ? p.action : 1.0 - p.followThrough * 0.25

            let mossLean: Double = step == 0
                ? -8.5 * turnProgress
                : -4.0 + p.followThrough * 3.0
            let ottoLean: Double = step == 0
                ? 4.0 + p.action * 3.5
                : 6.5 - p.hold * 2.0

            let mossHopLift: CGFloat = step == 1 && p.raw >= 0.44
                ? CGFloat(max(0.0, sin((p.raw - 0.44) / 0.36 * .pi))) * ms * 0.09
                : 0

            let mossLook = step == 0
                ? CGPoint(x: -0.78 * turnProgress, y: -0.58 * turnProgress)
                : CGPoint(x: -0.58, y: -0.18)
            let ottoLook = CGPoint(x: 0.78, y: 0.08)

            let mossMood: Mood = step == 0
                ? (p.action > 0.3 ? .wow : .open)
                : (p.raw >= 0.40 ? .happy : .open)
            let ottoMood: Mood = step == 1 ? .happy : .open

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundOtto, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundMoss, flat: flat, lift: mossHopLift)
            )

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.42 : 0.26, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawBayWindowRoom(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        bellPivot: bellPivot,
                        bellTip: bellTip,
                        bellAngle: bellPendulumAngle,
                        step: step,
                        p: p,
                        mossEar: CGPoint(x: mossCenter.x - ms * 0.16, y: mossCenter.y - ms * 0.12),
                        ottoVoice: CGPoint(x: ottoCenter.x + os * 0.22, y: ottoCenter.y - os * 0.05),
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: step == 0 ? bellTip : mossCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .floorPool
                )

                StoryTheaterActorView(
                    kind: .otto,
                    size: os,
                    mood: ottoMood,
                    look: ottoLook,
                    lid: dark ? 0.42 : 0.26,
                    lean: ottoLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.72, y: -0.66),
                    secondaryLagDegrees: -ottoLean * 0.32
                )
                .position(ottoCenter)

                StoryTheaterActorView(
                    kind: .moss,
                    size: ms,
                    mood: mossMood,
                    look: mossLook,
                    lid: dark ? 0.18 : 0,
                    lean: mossLean,
                    hopLift: mossHopLift / max(1, ms),
                    hopping: step == 1 && p.isContactWindow,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.72, y: -0.66),
                    secondaryLagDegrees: -mossLean * 0.45
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: step == 0 ? bellTip : mossCenter,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawBayWindowRoom(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        bellPivot: CGPoint,
        bellTip: CGPoint,
        bellAngle: Double,
        step: Int,
        p: LivingPhaseSample,
        mossEar: CGPoint,
        ottoVoice: CGPoint,
        flat: Bool,
        dark: Bool
    ) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xFBF8EE),
            dayBottom: Color(hex: 0xECE5D1),
            nightTop: Color(hex: 0x0A1224),
            nightBottom: Color(hex: 0x16233E),
            dark: dark
        )

        // Arched sunlit bay window recess
        let winRect = CGRect(x: w * 0.12, y: h * 0.06, width: w * 0.56, height: h * 0.58)
        let winPath = Path(roundedRect: winRect, cornerRadius: winRect.width * 0.42)
        ctx.fill(
            winPath,
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x162445) : Color(hex: 0xFDF9EA),
                    dark ? Color(hex: 0x20325A) : Color(hex: 0xE7F0DF)
                ]),
                startPoint: CGPoint(x: winRect.midX, y: winRect.minY),
                endPoint: CGPoint(x: winRect.midX, y: winRect.maxY)
            )
        )
        ctx.stroke(winPath, with: .color((dark ? Color(hex: 0x425A8A) : Color(hex: 0xCFBF9F)).opacity(0.65)), lineWidth: 2.0)

        // Window mullion lines
        var vBar = Path()
        vBar.move(to: CGPoint(x: winRect.midX, y: winRect.minY + 12))
        vBar.addLine(to: CGPoint(x: winRect.midX, y: winRect.maxY))
        ctx.stroke(vBar, with: .color((dark ? Color(hex: 0x3A4F7B) : Color(hex: 0xD8C9AA)).opacity(0.55)), lineWidth: 1.5)

        // Cushioned floor bolster / window seat rug
        let horizonY = h * 0.74
        let rugRect = CGRect(x: -6, y: horizonY, width: w + 12, height: h - horizonY + 8)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: Path(rugRect),
                bounds: rugRect,
                light: dark ? Color(hex: 0x213046) : Color(hex: 0xF3EBDA),
                rich: dark ? Color(hex: 0x162135) : Color(hex: 0xD9CFBA),
                pencilOutline: (dark ? Color(hex: 0x526A8E) : Color(hex: 0x9B8E76)).opacity(0.45),
                lineWidth: 1.2
            )
        } else {
            ctx.fill(
                Path(rugRect),
                with: .linearGradient(
                    Gradient(colors: [
                        dark ? Color(hex: 0x22304A) : Color(hex: 0xF5EEDD),
                        dark ? Color(hex: 0x152035) : Color(hex: 0xDDD3BE)
                    ]),
                    startPoint: CGPoint(x: w * 0.5, y: horizonY),
                    endPoint: CGPoint(x: w * 0.5, y: h)
                )
            )
        }

        // Hanging cord & brass-and-beech handbell
        var cord = Path()
        cord.move(to: bellPivot)
        cord.addLine(to: bellTip)
        ctx.stroke(cord, with: .color((dark ? Color(hex: 0x8EA5CC) : Color(hex: 0x9E8762)).opacity(0.8)), lineWidth: 1.6)

        var bellCtx = ctx
        bellCtx.translateBy(x: bellTip.x, y: bellTip.y)
        bellCtx.rotate(by: .degrees(bellAngle))
        let bellSize = min(w, h) * 0.085
        let dome = Path { path in
            path.move(to: CGPoint(x: -bellSize * 0.52, y: bellSize * 0.45))
            path.addQuadCurve(to: CGPoint(x: 0, y: -bellSize * 0.25), control: CGPoint(x: -bellSize * 0.42, y: -bellSize * 0.22))
            path.addQuadCurve(to: CGPoint(x: bellSize * 0.52, y: bellSize * 0.45), control: CGPoint(x: bellSize * 0.42, y: -bellSize * 0.22))
            path.closeSubpath()
        }
        let bellBounds = CGRect(x: -bellSize * 0.6, y: -bellSize * 0.3, width: bellSize * 1.2, height: bellSize * 0.85)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &bellCtx,
                path: dome,
                bounds: bellBounds,
                light: Palette.amber.mix(with: .white, by: 0.25),
                rich: Color(hex: 0xC68B2D),
                pencilOutline: (dark ? Color(hex: 0xFFE3A3) : Color(hex: 0x7A5316)).opacity(0.65),
                lineWidth: 1.1
            )
        } else {
            PixarDrawHelpers.drawBeechwood(
                in: &bellCtx,
                path: dome,
                bounds: bellBounds,
                dark: dark,
                warmth: 0.9,
                grainLines: 2
            )
        }
        // Beech handle knob
        let knobRect = CGRect(x: -bellSize * 0.16, y: -bellSize * 0.46, width: bellSize * 0.32, height: bellSize * 0.24)
        bellCtx.fill(Path(ellipseIn: knobRect), with: .color(Color(hex: dark ? 0xC9985A : 0xD8AA6C)))

        // Concentric acoustic bell arcs traveling gently toward Moss
        if step == 0 {
            for wave in 0..<3 {
                let local = max(0.0, min(1.0, p.action - Double(wave) * 0.16))
                guard local > 0.05 else { continue }
                let radius = min(w, h) * CGFloat(0.11 + 0.16 * local + Double(wave) * 0.03)
                var arc = Path()
                arc.addArc(center: bellTip, radius: radius, startAngle: .degrees(-18), endAngle: .degrees(54), clockwise: false)
                ctx.stroke(
                    arc,
                    with: .color(Palette.amber.opacity((1.0 - local * 0.6) * (dark ? 0.72 : 0.62))),
                    style: StrokeStyle(lineWidth: 2.2 - CGFloat(wave) * 0.4, lineCap: .round)
                )
            }
        } else {
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoVoice,
                to: mossEar,
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Palette.amber,
                lineWidth: 2.4,
                dark: dark
            )
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: CGPoint(x: mossEar.x + min(w, h) * 0.08, y: mossEar.y - min(w, h) * 0.05),
                pulse: p.contact,
                radius: min(w, h) * 0.085,
                color: Palette.amber
            )
        }
    }
}
