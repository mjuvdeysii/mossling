import SwiftUI

/// Flagship Month 6 Showcase Cover ("声响接龙、翻身空间与开始辅食" / "Sound Chains, Rolling Room & Starting Solids").
/// Built on 3 genuine atmospheric depth planes + sculpted sage-mint weaning bowl + rising warm pumpkin puree steam
/// + carved bamboo spoon + sunlit mirror/rattle + 1:1 3D/2D `StoryTheaterActorView` parity across Day and Lamp.
struct Month06ShowcaseCover: View {
    let dark: Bool
    let flat: Bool
    let phase: LivingPhaseSample
    let breathTime: Double
    let isStatic: Bool
    let compact: Bool
    let giggles: Int
    let tapBurst: Double

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let h = max(1, geo.size.height)
            let s = min(w, h)

            // Unified 1:1 spatial baseline for Pixar 3D & Ghibli 2D
            let ms = s * 0.38
            let os = ms * Kind.otto.scale
            let groundY = h * 0.855

            let bounce = sin(phase.raw * .pi * 2.0) * 0.5 + 0.5
            let mossLift = CGFloat(tapBurst > 0 ? sin(tapBurst * .pi) * ms * 0.08 : bounce * 2.5)
            let ottoLean = 4.0 + sin(phase.raw * .pi * 2.0) * 2.5
            let mossLean = -3.0 - sin(phase.raw * .pi * 2.0 + 0.5) * 3.0

            let ottoX = w * 0.255
            let mossX = w * 0.745
            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat, lift: mossLift)
            )

            let ottoLook = CGPoint(x: 0.74, y: 0.14)
            let mossLook = CGPoint(x: -0.70, y: 0.10)
            let ottoState = Creature.state(.otto, face: .happy, look: ottoLook, lid: dark ? 0.40 : 0.24, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )
            let bowlCenter = CGPoint(x: w * 0.50, y: h * 0.775)
            let shaderOn = !compact && w >= 80 && h >= 60

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawCoverWorld(in: &c, w: size.width, h: size.height, bowlCenter: bowlCenter)
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: bowlCenter,
                    phase: phase,
                    dark: dark,
                    flat: flat,
                    layer: .floorPool
                )

                StoryTheaterActorView(
                    kind: .otto,
                    size: os,
                    mood: .happy,
                    look: ottoLook,
                    lid: dark ? 0.40 : 0.24,
                    lean: ottoLean,
                    breathTime: breathTime,
                    isStatic: isStatic,
                    dark: dark,
                    flat: flat,
                    compact: compact,
                    lightDirection: CGPoint(x: 0.76, y: -0.64),
                    secondaryLagDegrees: -ottoLean * 0.30
                )
                .position(ottoCenter)

                StoryTheaterActorView(
                    kind: .moss,
                    size: ms,
                    mood: giggles > 0 && tapBurst > 0.1 ? .happy : .happy,
                    look: mossLook,
                    lid: dark ? 0.22 : 0,
                    lean: mossLean,
                    hopLift: mossLift / max(1, ms),
                    hopping: tapBurst > 0.25,
                    breathTime: breathTime,
                    isStatic: isStatic,
                    dark: dark,
                    flat: flat,
                    compact: compact,
                    lightDirection: CGPoint(x: 0.76, y: -0.64),
                    secondaryLagDegrees: -mossLean * 0.45 + (tapBurst > 0 ? sin(tapBurst * .pi) * 10.0 : 0)
                )
                .position(mossCenter)

                // Hero weaning bowl, steaming pumpkin puree, spoon, mirror/rattle & sound chains
                Canvas(rendersAsynchronously: false) { c, size in
                    drawForegroundPropsAndSoundChain(in: &c, w: size.width, h: size.height, bowlCenter: bowlCenter)
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: bowlCenter,
                    phase: phase,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
            .modifier(
                GhibliStageGrade(
                    stageSize: geo.size,
                    time: breathTime,
                    dark: dark,
                    komorebiStrength: 0.88,
                    enabled: flat && shaderOn
                )
            )
            .modifier(
                PixarStageGrade(
                    stageSize: geo.size,
                    keyPos: CGPoint(x: w * 0.78, y: h * 0.14),
                    beadPos: beadWorld,
                    targetPos: bowlCenter,
                    time: breathTime,
                    dark: dark,
                    keyIntensity: dark ? 0.94 : 1.0,
                    volumetricIntensity: dark ? 1.08 : 0.68,
                    enabled: !flat && shaderOn
                )
            )
        }
    }

    private func drawCoverWorld(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, bowlCenter: CGPoint) {
        let sway = CGFloat(sin(phase.raw * .pi * 2.0) * 5.0)

        // PLANE 1: Far Sky, Clouds (Day) / Crescent Moon & Stars (Lamp)
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xEAF3F0),
            dayBottom: Color(hex: 0xF8F1DA),
            nightTop: Color(hex: 0x091022),
            nightBottom: Color(hex: 0x182544),
            dark: dark,
            biome: .gardenMeadowSky
        )

        if dark {
            // Crescent moon & quiet stars
            let moonCenter = CGPoint(x: w * 0.80, y: h * 0.18)
            let moonR = min(w, h) * 0.055
            var moon = Path()
            moon.addEllipse(in: CGRect(x: moonCenter.x - moonR, y: moonCenter.y - moonR, width: moonR * 2, height: moonR * 2))
            ctx.fill(moon, with: .color(Color(hex: 0xF7DF9D).opacity(0.90)))
            ctx.fill(
                Path(ellipseIn: CGRect(x: moonCenter.x - moonR * 0.55, y: moonCenter.y - moonR * 1.15, width: moonR * 1.8, height: moonR * 1.8)),
                with: .color(Color(hex: 0x0C152B))
            )
            let stars: [(CGFloat, CGFloat, CGFloat)] = [
                (0.16, 0.16, 1.8), (0.31, 0.11, 1.4), (0.48, 0.20, 2.0), (0.64, 0.13, 1.5), (0.89, 0.29, 1.6)
            ]
            for (sx, sy, sr) in stars {
                let tw = 0.55 + 0.45 * sin(phase.raw * .pi * 2.0 + Double(sx * 10))
                ctx.fill(
                    Path(ellipseIn: CGRect(x: w * sx - sr, y: h * sy - sr, width: sr * 2, height: sr * 2)),
                    with: .color(Color(hex: 0xFFF2C8).opacity(tw))
                )
            }
        } else {
            GhibliDrawHelpers.drawPaintedCloud(in: &ctx, center: CGPoint(x: w * 0.26 + sway * 0.3, y: h * 0.18), width: w * 0.26, dark: false)
            GhibliDrawHelpers.drawPaintedCloud(in: &ctx, center: CGPoint(x: w * 0.74 - sway * 0.25, y: h * 0.22), width: w * 0.21, dark: false)
        }

        // Far misty rolling meadow hills
        var farHill = Path()
        farHill.move(to: CGPoint(x: 0, y: h * 0.54))
        farHill.addQuadCurve(to: CGPoint(x: w, y: h * 0.51), control: CGPoint(x: w * 0.46, y: h * 0.40))
        farHill.addLine(to: CGPoint(x: w, y: h))
        farHill.addLine(to: CGPoint(x: 0, y: h))
        farHill.closeSubpath()
        ctx.fill(
            farHill,
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x1B2B49) : Color(hex: 0xC9DFC2),
                    dark ? Color(hex: 0x132037) : Color(hex: 0xB3CFA9)
                ]),
                startPoint: CGPoint(x: w * 0.5, y: h * 0.42),
                endPoint: CGPoint(x: w * 0.5, y: h * 0.72)
            )
        )

        // PLANE 2: Mid sunlit meadow knoll + swaying eucalyptus arch
        var midHill = Path()
        midHill.move(to: CGPoint(x: 0, y: h * 0.61))
        midHill.addCurve(
            to: CGPoint(x: w, y: h * 0.62),
            control1: CGPoint(x: w * 0.32, y: h * 0.54),
            control2: CGPoint(x: w * 0.70, y: h * 0.56)
        )
        midHill.addLine(to: CGPoint(x: w, y: h))
        midHill.addLine(to: CGPoint(x: 0, y: h))
        midHill.closeSubpath()

        let midBounds = CGRect(x: 0, y: h * 0.54, width: w, height: h * 0.46)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: midHill,
                bounds: midBounds,
                light: dark ? Color(hex: 0x1C303D) : Color(hex: 0xD7E6BE),
                rich: dark ? Color(hex: 0x12222F) : Color(hex: 0xACC995),
                pencilOutline: (dark ? Color(hex: 0x3D5B69) : Color(hex: 0x7A9C6B)).opacity(0.45),
                lineWidth: 1.0
            )
        } else {
            ctx.fill(
                midHill,
                with: .linearGradient(
                    Gradient(colors: [
                        dark ? Color(hex: 0x1D303F) : Color(hex: 0xD9E8C0),
                        dark ? Color(hex: 0x111E2D) : Color(hex: 0xB0CE99)
                    ]),
                    startPoint: CGPoint(x: w * 0.5, y: h * 0.55),
                    endPoint: CGPoint(x: w * 0.5, y: h)
                )
            )
        }

        // Overhead leafy Komorebi canopy
        GhibliDrawHelpers.drawKomorebiCanopy(in: &ctx, w: w, h: h, swayOffset: sway * 0.5, dark: dark)

        // PLANE 3: Oatmeal & terracotta stitched picnic rolling blanket
        let blanketRect = CGRect(x: w * 0.11, y: h * 0.69, width: w * 0.78, height: h * 0.25)
        var blanket = Path()
        blanket.addRoundedRect(in: blanketRect, cornerSize: CGSize(width: 24, height: 18))

        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: blanket,
                bounds: blanketRect,
                light: dark ? Color(hex: 0x2B3857) : Color(hex: 0xFCF7EC),
                rich: dark ? Color(hex: 0x1E2943) : Color(hex: 0xEAE0CA),
                pencilOutline: (dark ? Color(hex: 0x6277A8) : Color(hex: 0xA89578)).opacity(0.55),
                lineWidth: 1.2
            )
        } else {
            PixarDrawHelpers.drawContactAO(
                in: &ctx,
                center: CGPoint(x: blanketRect.midX, y: blanketRect.maxY + 2),
                rx: blanketRect.width * 0.46,
                ry: 10,
                dark: dark,
                opacity: 0.7
            )
            ctx.fill(
                blanket,
                with: .linearGradient(
                    Gradient(colors: [
                        dark ? Color(hex: 0x293756) : Color(hex: 0xFDF9EF),
                        dark ? Color(hex: 0x1C263E) : Color(hex: 0xE7DBC4)
                    ]),
                    startPoint: CGPoint(x: blanketRect.midX, y: blanketRect.minY),
                    endPoint: CGPoint(x: blanketRect.midX, y: blanketRect.maxY)
                )
            )
        }

        // Terracotta blanket perimeter stitch
        let stitchRect = blanketRect.insetBy(dx: 8, dy: 7)
        ctx.stroke(
            Path(roundedRect: stitchRect, cornerRadius: 18),
            with: .color((dark ? Color(hex: 0xE49E70) : Color(hex: 0xC87A50)).opacity(dark ? 0.36 : 0.48)),
            style: StrokeStyle(lineWidth: 1.3, dash: [5, 4])
        )
    }

    private func drawForegroundPropsAndSoundChain(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, bowlCenter: CGPoint) {
        let s = min(w, h)

        // 1. Floating Month 6 sound-chain musical pearls arching between Otto & Moss
        let chainColorAmber = Palette.amber
        let chainColorMint = Color(hex: dark ? 0x8CD9A3 : 0x6AA87B)
        for i in 0..<5 {
            let t = Double(i) / 4.0
            let bx = w * (0.36 + CGFloat(t) * 0.28)
            let bounce = sin(phase.raw * .pi * 2.0 + Double(i) * 0.85) * 4.5
            let by = h * 0.34 - sin(CGFloat(t) * .pi) * h * 0.06 + CGFloat(bounce)
            let br = s * (i % 2 == 0 ? 0.020 : 0.014)
            let col = i % 2 == 0 ? chainColorAmber : chainColorMint
            ctx.fill(
                Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2)),
                with: .radialGradient(
                    Gradient(colors: [col.mix(with: .white, by: 0.35), col]),
                    center: CGPoint(x: bx - br * 0.25, y: by - br * 0.25),
                    startRadius: 0,
                    endRadius: br * 1.4
                )
            )
        }

        // 2. Sculpted beechwood sound rattle resting right of the bowl (rolling room & sound cue)
        let rattlePos = CGPoint(x: w * 0.625, y: h * 0.825)
        let rattleR = s * 0.028
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: rattlePos.x, y: rattlePos.y + rattleR * 0.8), rx: rattleR * 1.4, ry: rattleR * 0.35, dark: dark, opacity: 0.75)
        let barRect = CGRect(x: rattlePos.x - rattleR * 1.1, y: rattlePos.y - rattleR * 0.22, width: rattleR * 2.2, height: rattleR * 0.44)
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: Path(roundedRect: barRect, cornerRadius: 3), bounds: barRect, dark: dark, warmth: 0.65, grainLines: 1)
        for endX in [rattlePos.x - rattleR, rattlePos.x + rattleR] {
            let knob = CGRect(x: endX - rattleR * 0.55, y: rattlePos.y - rattleR * 0.55, width: rattleR * 1.1, height: rattleR * 1.1)
            ctx.fill(Path(ellipseIn: knob), with: .color(dark ? Color(hex: 0xD2A064) : Color(hex: 0xE5BA7D)))
        }

        // 3. Center hero sculpted sage-mint ceramic weaning bowl + golden pumpkin puree + rising steam wisps
        let bowlW = s * 0.22
        let bowlH = s * 0.105
        PixarDrawHelpers.drawContactAO(
            in: &ctx,
            center: CGPoint(x: bowlCenter.x, y: bowlCenter.y + bowlH * 0.52),
            rx: bowlW * 0.48,
            ry: bowlH * 0.22,
            dark: dark,
            opacity: 0.9
        )

        var bowlBody = Path()
        bowlBody.move(to: CGPoint(x: bowlCenter.x - bowlW * 0.48, y: bowlCenter.y - bowlH * 0.22))
        bowlBody.addCurve(
            to: CGPoint(x: bowlCenter.x + bowlW * 0.48, y: bowlCenter.y - bowlH * 0.22),
            control1: CGPoint(x: bowlCenter.x - bowlW * 0.34, y: bowlCenter.y + bowlH * 0.75),
            control2: CGPoint(x: bowlCenter.x + bowlW * 0.34, y: bowlCenter.y + bowlH * 0.75)
        )
        bowlBody.closeSubpath()

        let bowlBounds = CGRect(x: bowlCenter.x - bowlW * 0.5, y: bowlCenter.y - bowlH * 0.3, width: bowlW, height: bowlH * 0.95)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: bowlBody,
                bounds: bowlBounds,
                light: dark ? Color(hex: 0x4E7C69) : Color(hex: 0xA3C9AE),
                rich: dark ? Color(hex: 0x35594C) : Color(hex: 0x7BA68A),
                pencilOutline: (dark ? Color(hex: 0x89BA9A) : Color(hex: 0x4F705A)).opacity(0.60),
                lineWidth: 1.2
            )
        } else {
            ctx.fill(
                bowlBody,
                with: .linearGradient(
                    Gradient(colors: [
                        dark ? Color(hex: 0x568470) : Color(hex: 0xAED2B8),
                        dark ? Color(hex: 0x345549) : Color(hex: 0x79A388)
                    ]),
                    startPoint: CGPoint(x: bowlCenter.x - bowlW * 0.3, y: bowlCenter.y - bowlH * 0.2),
                    endPoint: CGPoint(x: bowlCenter.x + bowlW * 0.2, y: bowlCenter.y + bowlH * 0.6)
                )
            )
        }

        // Bowl rim & warm pumpkin puree interior
        let rimRect = CGRect(x: bowlCenter.x - bowlW * 0.48, y: bowlCenter.y - bowlH * 0.38, width: bowlW * 0.96, height: bowlH * 0.36)
        ctx.fill(Path(ellipseIn: rimRect), with: .color(dark ? Color(hex: 0x6A9A83) : Color(hex: 0xC6E0CB)))
        let pureeRect = rimRect.insetBy(dx: 4, dy: 2.5)
        ctx.fill(
            Path(ellipseIn: pureeRect),
            with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFB85C), Color(hex: 0xE28634)]),
                center: CGPoint(x: pureeRect.midX - 4, y: pureeRect.midY - 1),
                startRadius: 1,
                endRadius: pureeRect.width * 0.55
            )
        )

        // Carved bamboo baby spoon resting softly into the puree
        var spoon = ctx
        let spoonAnchor = CGPoint(x: bowlCenter.x + bowlW * 0.20, y: bowlCenter.y - bowlH * 0.22)
        spoon.translateBy(x: spoonAnchor.x, y: spoonAnchor.y)
        spoon.rotate(by: .degrees(-28 + sin(phase.raw * .pi * 2.0) * 3.0))
        let handle = CGRect(x: 0, y: -3, width: bowlW * 0.58, height: 5.2)
        PixarDrawHelpers.drawBeechwood(in: &spoon, path: Path(roundedRect: handle, cornerRadius: 2.6), bounds: handle, dark: dark, warmth: 0.7, grainLines: 1)

        // 2 delicate curling steam wisps rising gently above the warm puree
        for i in 0..<2 {
            let phaseShift = Double(i) * 1.6 + phase.raw * .pi * 2.0
            let baseX = bowlCenter.x + CGFloat(i == 0 ? -bowlW * 0.14 : bowlW * 0.08)
            let baseY = bowlCenter.y - bowlH * 0.35
            var steam = Path()
            steam.move(to: CGPoint(x: baseX, y: baseY))
            steam.addCurve(
                to: CGPoint(x: baseX + CGFloat(sin(phaseShift) * 6), y: baseY - bowlH * 0.85),
                control1: CGPoint(x: baseX - 5, y: baseY - bowlH * 0.30),
                control2: CGPoint(x: baseX + 6, y: baseY - bowlH * 0.60)
            )
            ctx.stroke(
                steam,
                with: .color((dark ? Color(hex: 0xFFE6BD) : Color.white).opacity(dark ? 0.38 : 0.68)),
                style: StrokeStyle(lineWidth: 1.8, lineCap: .round)
            )
        }
    }
}
