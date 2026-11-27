import SwiftUI

/// Living 4:3 Picture-Book Growth Chapter Plate (Months 0–36) adhering 100% to `docs/IP.md`:
/// - Uses canonical `StoryTheaterSpritePool` (`ip_moss_*`, `ip_otto_*`) in 3D matte-vinyl and `FlatCreature` in 2D
///   (never legacy `child_*.webp`, zero pink blush cheeks, zero mouth dots).
/// - Progressive Moss scale (`0.78 -> 1.08`), 3 seasonal Nordic cut-paper Lands, 7 developmental ground anchors,
///   real-time `LampLightRig`, and 18 curated milestone props.
/// - Deterministic synchronous rendering when `posterPhase != nil || !interactive || Reduce Motion` so thumbnails,
///   `ScreenshotTests`, and `ImageRenderer` PDF/poster exports are crystal-clear on Frame 1.
struct LivingMonthCoverStage: View {
    let month: Int
    let dark: Bool
    var festive: Bool = false
    var posterPhase: Double? = nil
    var interactive: Bool = false
    var compact: Bool = false
    var forceFlat: Bool? = nil
    var exportSafe: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.scrolling) private var scrolling

    @State private var onScreen = true
    @State private var tapAt = Date.distantPast
    @State private var giggles = 0

    private var script: LivingMonthCoverScript {
        LivingMonthCoverCatalog.script(for: month)
    }

    private var permanentlyStatic: Bool {
        posterPhase != nil || !interactive || reduce || Perf.still || exportSafe
    }

    private var isStatic: Bool {
        permanentlyStatic || !onScreen || scrolling.moving || scenePhase != .active
    }

    var body: some View {
        let s = script
        let isFlat = forceFlat ?? (ArtStyle.current == .flat)

        Group {
            if permanentlyStatic {
                stageCanvas(script: s, now: Date.distantPast, u: posterPhase ?? s.posterPhase, isFlat: isFlat)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: isStatic)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    let u = isStatic ? (posterPhase ?? s.posterPhase) : LivingMotionClock.cyclicProgress(elapsed: t, duration: 5.2)
                    stageCanvas(script: s, now: isStatic ? Date.distantPast : tl.date, u: u, isFlat: isFlat)
                }
            }
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .onScrollVisibilityChange(threshold: 0.01) { onScreen = $0 }
    }

    @ViewBuilder
    private func stageCanvas(script s: LivingMonthCoverScript, now: Date, u: Double, isFlat: Bool) -> some View {
        let phase = LivingMotionClock.sample(u: u)
        let tapAge = tapAt == .distantPast ? 9.9 : max(0, now.timeIntervalSince(tapAt))
        let tapBurst: Double = (!isStatic && interactive && tapAge < 0.7) ? (1.0 - tapAge / 0.7) : 0
        let tapJump: CGFloat = (!isStatic && interactive && tapAge < 0.65)
            ? CGFloat(sin(tapAge / 0.65 * .pi)) * 0.95
            : 0
        let sway = isStatic ? 0 : sin(u * .pi * 2.0) * 1.8
        let breathTime = isStatic ? 0 : now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600.0)

        Group {
            if s.month == 6 {
                Month06ShowcaseCover(
                    dark: dark,
                    flat: isFlat,
                    phase: phase,
                    breathTime: breathTime,
                    isStatic: isStatic,
                    compact: compact || exportSafe,
                    giggles: giggles,
                    tapBurst: tapBurst
                )
            } else {
                GeometryReader { g in
                    let w = g.size.width
                    let h = g.size.height
                    let floorY = h * 0.77

                    let baseMs = min(w * 0.245, h * 0.355)
                    let ms = baseMs * s.mossScale
                    let os = baseMs * Kind.otto.scale

                    let mossFeetFrac: CGFloat = isFlat ? 0.88 : (Sprites.mossFeet / 100.0)
                    let ottoFeetFrac: CGFloat = isFlat ? 0.88 : (Sprites.ottoFeet / 100.0)

                    let mossCenter = CGPoint(
                        x: w * s.mossX,
                        y: floorY - ms * mossFeetFrac + ms * 0.5 - tapJump * ms * 0.08
                    )
                    let ottoCenter = CGPoint(
                        x: w * s.ottoX,
                        y: floorY - os * ottoFeetFrac + os * 0.5
                    )

                    let mossMoodNow: Mood = tapJump > 0.15 ? .happy : s.mossMood
                    let ottoLean = -2.8 - sway * 0.35
                    let ottoLid: Double = dark ? 0.45 : 0
                    let ottoState = Creature.state(.otto, face: .happy, look: CGPoint(x: -0.9, y: 0.25), lid: ottoLid, hopping: false, yawning: false)
                    let beadWorld = LampLightRig.beadWorldPosition(
                        ottoCenter: ottoCenter,
                        ottoSize: os,
                        ottoState: ottoState,
                        leanDegrees: ottoLean,
                        flat: isFlat
                    )
                    let targetWorld = CGPoint(x: w * 0.46, y: floorY + 2)
                    let shaderOn = !exportSafe && !compact && w >= 80 && h >= 60

                    ZStack {
                        MonthCoverBackdropCanvas(
                            script: s,
                            phase: phase,
                            dark: dark,
                            flat: isFlat,
                            compact: compact,
                            festive: festive || s.isBirthday
                        )

                        LampLightRig(
                            beadPos: beadWorld,
                            targetPoint: targetWorld,
                            phase: phase,
                            dark: dark,
                            flat: isFlat,
                            layer: .floorPool
                        )

                        MonthMilestonePropCanvas(
                            script: s,
                            phase: phase,
                            dark: dark,
                            flat: isFlat,
                            compact: compact,
                            tapBurstStrength: tapBurst
                        )

                        companionFigure(
                            kind: .otto,
                            mood: .happy,
                            look: CGPoint(x: -0.90, y: 0.25),
                            lid: dark ? 0.45 : nil,
                            lean: ottoLean,
                            hopping: false,
                            size: os,
                            now: now,
                            isFlat: isFlat
                        )
                        .position(ottoCenter)

                        companionFigure(
                            kind: .moss,
                            mood: mossMoodNow,
                            look: CGPoint(x: 0.85, y: -0.05),
                            lid: tapJump > 0.1 ? nil : s.mossLid,
                            lean: 2.0 + sway * 0.45,
                            hopping: tapJump > 0.35,
                            size: ms,
                            now: now,
                            isFlat: isFlat
                        )
                        .position(mossCenter)

                        LampLightRig(
                            beadPos: beadWorld,
                            targetPoint: targetWorld,
                            phase: phase,
                            dark: dark,
                            flat: isFlat,
                            layer: .airCone
                        )
                        .blendMode(dark ? .plusLighter : .normal)
                    }
                    .modifier(
                        GhibliStageGrade(
                            stageSize: g.size,
                            time: breathTime,
                            dark: dark,
                            komorebiStrength: 0.72,
                            enabled: isFlat && shaderOn
                        )
                    )
                    .modifier(
                        PixarStageGrade(
                            stageSize: g.size,
                            keyPos: CGPoint(x: w * 0.80, y: h * 0.14),
                            beadPos: beadWorld,
                            targetPos: targetWorld,
                            time: breathTime,
                            dark: dark,
                            keyIntensity: dark ? 0.90 : 0.96,
                            volumetricIntensity: dark ? 1.02 : 0.56,
                            enabled: !isFlat && shaderOn
                        )
                    )
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard interactive, !isStatic else { return }
            tapAt = Date()
            giggles += 1
            TactileEngine.shared.vinylPop()
        }
        .allowsHitTesting(interactive)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: giggles)
    }

    @ViewBuilder
    private func companionFigure(
        kind: Kind,
        mood: Mood,
        look: CGPoint,
        lid: Double?,
        lean: Double,
        hopping: Bool,
        size: CGFloat,
        now: Date,
        isFlat: Bool
    ) -> some View {
        StoryTheaterActorView(
            kind: kind,
            size: size,
            mood: mood,
            look: look,
            lid: lid,
            lean: lean,
            hopping: hopping,
            breathTime: isStatic ? 0 : now.timeIntervalSinceReferenceDate,
            isStatic: isStatic,
            dark: dark,
            flat: isFlat,
            compact: compact,
            lightDirection: CGPoint(x: 0.78, y: -0.62),
            secondaryLagDegrees: -lean * 0.35
        )
    }
}

// MARK: - Seasonal Cut-Paper Land Backdrops (Meadow / Woodland / Stream)

private struct MonthCoverBackdropCanvas: View {
    let script: LivingMonthCoverScript
    let phase: LivingPhaseSample
    let dark: Bool
    let flat: Bool
    let compact: Bool
    let festive: Bool

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            let w = size.width
            let h = size.height
            let floorY = h * 0.77
            let unit = min(w, h)

            drawSky(in: &ctx, w: w, h: h, floorY: floorY)
            drawHorizonGlow(in: &ctx, w: w, h: h, floorY: floorY)

            switch script.land {
            case .meadow:
                drawMeadowSet(in: &ctx, w: w, h: h, floorY: floorY, unit: unit)
            case .woodland:
                drawWoodlandSet(in: &ctx, w: w, h: h, floorY: floorY, unit: unit)
            case .stream:
                drawStreamSet(in: &ctx, w: w, h: h, floorY: floorY, unit: unit)
            }

            drawStageAnchor(in: &ctx, w: w, h: h, floorY: floorY, unit: unit)

            if festive {
                drawBunting(in: &ctx, w: w, h: h, unit: unit)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawSky(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, floorY: CGFloat) {
        let rect = Path(CGRect(x: 0, y: 0, width: w, height: h))
        if dark {
            let top = Color(hex: 0x121936)
            let bot = Color(hex: 0x22294D)
            ctx.fill(rect, with: flat ? .color(top) : .linearGradient(Gradient(colors: [top, bot]), startPoint: .zero, endPoint: CGPoint(x: 0, y: floorY)))
            // Crescent moon + subtle stars
            let mr = max(8, w * 0.055)
            let mx = w * 0.80
            let my = h * 0.14
            var moon = Path(ellipseIn: CGRect(x: mx, y: my, width: mr, height: mr))
            moon = moon.subtracting(Path(ellipseIn: CGRect(x: mx + mr * 0.34, y: my - mr * 0.20, width: mr, height: mr)))
            ctx.fill(moon, with: .color(Color(hex: 0xFFF0BE)))
            if !compact {
                for (sx, sy) in [(0.14, 0.14), (0.28, 0.22), (0.58, 0.11), (0.68, 0.25), (0.90, 0.28)] as [(CGFloat, CGFloat)] {
                    ctx.fill(Path(ellipseIn: CGRect(x: w * sx, y: h * sy, width: 2.2, height: 2.2)), with: .color(.white.opacity(0.68)))
                }
            }
        } else {
            let top: Color
            let bot: Color
            switch script.land {
            case .meadow:
                top = Color(hex: 0xFCF7EA)
                bot = Color(hex: 0xEDF4DF)
            case .woodland:
                top = Color(hex: 0xFAF2E1)
                bot = Color(hex: 0xEFE2CA)
            case .stream:
                top = Color(hex: 0xF5F8F4)
                bot = Color(hex: 0xE1EFF0)
            }
            ctx.fill(rect, with: flat ? .color(top) : .linearGradient(Gradient(colors: [top, bot]), startPoint: .zero, endPoint: CGPoint(x: 0, y: floorY)))
        }
    }

    private func drawHorizonGlow(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, floorY: CGFloat) {
        let archW = w * 0.62
        let archH = floorY * 0.74
        let archRect = CGRect(x: (w - archW) * 0.5, y: floorY - archH + 12, width: archW, height: archH)
        let arch = Path(roundedRect: archRect, cornerRadius: archW * 0.48)
        let landTint = script.land.accentColor
        let fill: Color = dark
            ? landTint.mix(with: Color(hex: 0x1D264A), by: 0.78).opacity(0.60)
            : landTint.mix(with: Color(hex: 0xFFFBF2), by: 0.74)
        ctx.fill(arch, with: .color(fill))
    }

    private func drawMeadowSet(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, floorY: CGFloat, unit: CGFloat) {
        if !dark {
            // Soft warm paper sun + drifting cloud on top-left
            let sunR = unit * 0.085
            let sunPos = CGPoint(x: w * 0.16, y: h * 0.18)
            ctx.fill(Path(ellipseIn: CGRect(x: sunPos.x - sunR, y: sunPos.y - sunR, width: sunR * 2, height: sunR * 2)), with: .color(Color(hex: 0xFFE394).opacity(0.65)))
            if !compact {
                let dx = CGFloat(sin(phase.raw * .pi * 2.0) * 6.0)
                let cx = w * 0.24 + dx
                let cy = h * 0.22
                var cloud = Path()
                cloud.addRoundedRect(in: CGRect(x: cx - unit * 0.09, y: cy, width: unit * 0.18, height: unit * 0.055), cornerSize: CGSize(width: unit * 0.028, height: unit * 0.028))
                cloud.addEllipse(in: CGRect(x: cx - unit * 0.055, y: cy - unit * 0.03, width: unit * 0.09, height: unit * 0.075))
                ctx.fill(cloud, with: .color(.white.opacity(0.84)))
            }
        }

        // Far hill
        var back = Path()
        back.move(to: CGPoint(x: -4, y: floorY - unit * 0.06))
        back.addCurve(to: CGPoint(x: w + 4, y: floorY - unit * 0.08), control1: CGPoint(x: w * 0.32, y: floorY - unit * 0.20), control2: CGPoint(x: w * 0.68, y: floorY - unit * 0.01))
        back.addLine(to: CGPoint(x: w + 4, y: h + 4))
        back.addLine(to: CGPoint(x: -4, y: h + 4))
        back.closeSubpath()
        ctx.fill(back, with: .color(dark ? Color(hex: 0x243839) : Color(hex: 0xD3E8C4)))

        // Foreground meadow lawn
        var front = Path()
        front.move(to: CGPoint(x: -4, y: floorY + 2))
        front.addCurve(to: CGPoint(x: w + 4, y: floorY - 2), control1: CGPoint(x: w * 0.35, y: floorY - 12), control2: CGPoint(x: w * 0.72, y: floorY + 10))
        front.addLine(to: CGPoint(x: w + 4, y: h + 4))
        front.addLine(to: CGPoint(x: -4, y: h + 4))
        front.closeSubpath()
        ctx.fill(front, with: .color(dark ? Color(hex: 0x1B2B2F) : Color(hex: 0xB8D8A6)))

        if !compact {
            let bloomColor = dark ? Palette.amber.opacity(0.45) : Color(hex: 0xFFFDF5).opacity(0.88)
            for (fx, fy) in [(0.14, 0.87), (0.22, 0.91), (0.81, 0.86), (0.89, 0.91)] as [(CGFloat, CGFloat)] {
                let r = max(2.2, unit * 0.013)
                ctx.fill(Path(ellipseIn: CGRect(x: w * fx - r, y: h * fy - r, width: r * 2, height: r * 2)), with: .color(bloomColor))
            }
        }
    }

    private func drawWoodlandSet(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, floorY: CGFloat, unit: CGFloat) {
        // Distant sunlit canopy hill
        var far = Path()
        far.move(to: CGPoint(x: -4, y: floorY - unit * 0.04))
        far.addQuadCurve(to: CGPoint(x: w + 4, y: floorY - unit * 0.06), control: CGPoint(x: w * 0.50, y: floorY - unit * 0.16))
        far.addLine(to: CGPoint(x: w + 4, y: h + 4))
        far.addLine(to: CGPoint(x: -4, y: h + 4))
        far.closeSubpath()
        ctx.fill(far, with: .color(dark ? Color(hex: 0x263242) : Color(hex: 0xE4D8BA)))

        // Framing Scandinavian birch trunks & leaf crowns on sides
        let trunkW = unit * 0.055
        let trunkColor = dark ? Color(hex: 0x454D6E) : Color(hex: 0xF5ECDC)
        let canopyColor = dark ? Color(hex: 0x283A43) : Color(hex: 0xC6D8A8)
        let ochreCanopy = dark ? Color(hex: 0x3D3944) : Color(hex: 0xEED39C).opacity(0.88)

        for tx in [w * 0.07, w * 0.90] {
            let trunkRect = CGRect(x: tx - trunkW * 0.5, y: 0, width: trunkW, height: floorY + 8)
            ctx.fill(Path(trunkRect), with: .color(trunkColor))
            if !compact {
                let bark = dark ? Color(hex: 0x2A304A) : Color(hex: 0xB8A68B)
                for by in [0.22, 0.38, 0.54] as [CGFloat] {
                    ctx.fill(Path(roundedRect: CGRect(x: tx - trunkW * 0.34, y: h * by, width: trunkW * 0.5, height: max(1.5, unit * 0.008)), cornerRadius: 1), with: .color(bark.opacity(0.65)))
                }
            }
        }

        // Layered cut-paper leaf crowns
        ctx.fill(Path(ellipseIn: CGRect(x: -w * 0.06, y: -h * 0.10, width: w * 0.34, height: h * 0.32)), with: .color(canopyColor))
        ctx.fill(Path(ellipseIn: CGRect(x: w * 0.72, y: -h * 0.08, width: w * 0.34, height: h * 0.30)), with: .color(ochreCanopy))

        // Woodland floor
        let ground = Path(CGRect(x: -4, y: floorY, width: w + 8, height: h - floorY + 8))
        ctx.fill(ground, with: .color(dark ? Color(hex: 0x1F273B) : Color(hex: 0xDFC496)))
        ctx.fill(Path(CGRect(x: -4, y: floorY, width: w + 8, height: 1.5)), with: .color(dark ? Color.white.opacity(0.08) : Color.white.opacity(0.6)))
    }

    private func drawStreamSet(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, floorY: CGFloat, unit: CGFloat) {
        // Distant reed hills
        var hill = Path()
        hill.move(to: CGPoint(x: -4, y: floorY - unit * 0.04))
        hill.addCurve(to: CGPoint(x: w + 4, y: floorY - unit * 0.07), control1: CGPoint(x: w * 0.36, y: floorY - unit * 0.17), control2: CGPoint(x: w * 0.68, y: floorY - unit * 0.02))
        hill.addLine(to: CGPoint(x: w + 4, y: h + 4))
        hill.addLine(to: CGPoint(x: -4, y: h + 4))
        hill.closeSubpath()
        ctx.fill(hill, with: .color(dark ? Color(hex: 0x223845) : Color(hex: 0xCBE2DF)))

        // Mossy shore foreground
        let bank = Path(CGRect(x: -4, y: floorY - 2, width: w + 8, height: h - floorY + 8))
        ctx.fill(bank, with: .color(dark ? Color(hex: 0x1B2B3A) : Color(hex: 0xBFE0CC)))

        // Winding shimmering creek ribbon near lower foreground (`h * 0.85...1.0`)
        let brookY = h * 0.85
        var brook = Path()
        brook.move(to: CGPoint(x: -4, y: brookY))
        brook.addCurve(to: CGPoint(x: w + 4, y: brookY + 4), control1: CGPoint(x: w * 0.35, y: brookY - 8), control2: CGPoint(x: w * 0.68, y: brookY + 12))
        brook.addLine(to: CGPoint(x: w + 4, y: h + 4))
        brook.addLine(to: CGPoint(x: -4, y: h + 4))
        brook.closeSubpath()
        let water1 = dark ? Color(hex: 0x1B4A62) : Color(hex: 0x89C8D9)
        let water2 = dark ? Color(hex: 0x133349) : Color(hex: 0x62B0C6)
        ctx.fill(brook, with: flat ? .color(water1) : .linearGradient(Gradient(colors: [water1, water2]), startPoint: CGPoint(x: 0, y: brookY), endPoint: CGPoint(x: 0, y: h)))

        if !compact {
            let drift = CGFloat(sin(phase.raw * .pi * 2.0) * 5.0)
            for (rx, ry, rw) in [(0.22, 0.90, 0.14), (0.56, 0.93, 0.16), (0.78, 0.89, 0.11)] as [(CGFloat, CGFloat, CGFloat)] {
                var rPath = Path()
                rPath.move(to: CGPoint(x: w * rx + drift, y: h * ry))
                rPath.addLine(to: CGPoint(x: w * (rx + rw) + drift, y: h * ry))
                ctx.stroke(rPath, with: .color(Color.white.opacity(dark ? 0.25 : 0.60)), style: StrokeStyle(lineWidth: max(1.2, unit * 0.007), lineCap: .round))
            }
        }
    }

    private func drawStageAnchor(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, floorY: CGFloat, unit: CGFloat) {
        let rugW = w * 0.66
        let rugH: CGFloat = compact ? 10 : 14
        let rect = CGRect(x: (w - rugW) * 0.5, y: floorY - rugH * 0.35, width: rugW, height: rugH)
        let fill: Color
        switch script.growthStage {
        case 0, 1:
            fill = dark ? Color(hex: 0x2B3858) : Color(hex: 0xEDE5F7)
        case 2, 3:
            fill = dark ? Color(hex: 0x333252) : Color(hex: 0xF8E4DB)
        case 4, 5:
            fill = dark ? Color(hex: 0x3A3346) : Color(hex: 0xF5E7C6)
        default:
            fill = dark ? Color(hex: 0x283A4E) : Color(hex: 0xDDF0EC)
        }
        let path = Path(roundedRect: rect, cornerRadius: rugH * 0.5)
        ctx.fill(path, with: .color(fill.opacity(dark ? 0.78 : 0.88)))
        if !compact {
            ctx.stroke(
                path,
                with: .color(script.land.accentColor.opacity(dark ? 0.35 : 0.45)),
                style: StrokeStyle(lineWidth: 1.0, dash: [4, 4])
            )
        }
    }

    private func drawBunting(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, unit: CGFloat) {
        let y0 = h * 0.07
        let sag = h * 0.12
        var cord = Path()
        cord.move(to: CGPoint(x: -2, y: y0))
        cord.addQuadCurve(to: CGPoint(x: w + 2, y: y0), control: CGPoint(x: w * 0.5, y: y0 + sag * 2))
        ctx.stroke(cord, with: .color(Color(hex: dark ? 0xD8BE8B : 0x8A663F).opacity(0.65)), lineWidth: compact ? 0.9 : 1.2)

        let colors = [Crayon.pink, Palette.bead, Crayon.teal, Crayon.sky, Crayon.sunflower]
        let count = compact ? 5 : 7
        let flagHalfW: CGFloat = compact ? 3.5 : max(4.5, unit * 0.024)
        let flagH: CGFloat = compact ? 6.5 : max(8.5, unit * 0.045)
        for i in 0..<count {
            let t = (Double(i) + 0.5) / Double(count)
            let x = w * t
            let y = y0 + sag * 4 * t * (1 - t)
            var flag = Path()
            flag.move(to: CGPoint(x: x - flagHalfW, y: y))
            flag.addLine(to: CGPoint(x: x + flagHalfW, y: y))
            flag.addLine(to: CGPoint(x: x, y: y + flagH))
            flag.closeSubpath()
            ctx.fill(flag, with: .color(colors[i % colors.count]))
        }
    }
}

// MARK: - 18 Curated Milestone Props

private struct MonthMilestonePropCanvas: View {
    let script: LivingMonthCoverScript
    let phase: LivingPhaseSample
    let dark: Bool
    let flat: Bool
    let compact: Bool
    let tapBurstStrength: Double

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            let w = size.width
            let h = size.height
            let floorY = h * 0.77
            let unit = min(w, h)
            let px = w * 0.50

            drawProp(script.prop, in: &ctx, centerX: px, floorY: floorY, unit: unit, isSecondary: false)

            if !compact, let sec = script.secondaryProp {
                drawProp(sec, in: &ctx, centerX: w * 0.14, floorY: floorY, unit: unit * 0.56, isSecondary: true)
            }

            if tapBurstStrength > 0.01 {
                let r = unit * CGFloat(0.08 + (1.0 - tapBurstStrength) * 0.14)
                let center = CGPoint(x: w * script.mossX, y: floorY - unit * 0.28)
                for i in 0..<5 {
                    let a = Double(i) * (.pi * 2.0 / 5.0) - .pi / 2.0
                    let bx = center.x + CGFloat(cos(a)) * r
                    let by = center.y + CGFloat(sin(a)) * r
                    let dr = max(2.0, unit * 0.015)
                    ctx.fill(Path(ellipseIn: CGRect(x: bx - dr, y: by - dr, width: dr * 2, height: dr * 2)), with: .color(Palette.bead.opacity(tapBurstStrength * 0.85)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func shadow(in ctx: inout GraphicsContext, x: CGFloat, floorY: CGFloat, rx: CGFloat, unit: CGFloat) {
        guard !flat else { return }
        let ry = max(2.5, unit * 0.016)
        ctx.fill(
            Path(ellipseIn: CGRect(x: x - rx, y: floorY - ry * 0.4, width: rx * 2, height: ry * 1.4)),
            with: .color(Color.black.opacity(dark ? 0.34 : 0.14))
        )
    }

    private func drawProp(_ kind: MonthMilestoneProp, in ctx: inout GraphicsContext, centerX px: CGFloat, floorY: CGFloat, unit: CGFloat, isSecondary: Bool) {
        switch kind {
        case .leafNest:
            let w = unit * 0.24
            let h = unit * 0.085
            shadow(in: &ctx, x: px, floorY: floorY, rx: w * 0.52, unit: unit)
            let nest = Path(roundedRect: CGRect(x: px - w * 0.5, y: floorY - h, width: w, height: h), cornerRadius: h * 0.45)
            ctx.fill(nest, with: .color(dark ? Color(hex: 0x9C8356) : Color(hex: 0xDFCFA6)))
            let leafW = unit * 0.09
            let leafH = unit * 0.045
            ctx.fill(Path(ellipseIn: CGRect(x: px - w * 0.44, y: floorY - h * 0.85, width: leafW, height: leafH)), with: .color(Crayon.leaf.opacity(0.85)))
            ctx.fill(Path(ellipseIn: CGRect(x: px + w * 0.44 - leafW, y: floorY - h * 0.85, width: leafW, height: leafH)), with: .color(Crayon.mint.opacity(0.85)))

        case .sunMirror:
            let mw = unit * 0.19
            let mh = unit * 0.24
            let cy = floorY - mh * 0.52
            shadow(in: &ctx, x: px, floorY: floorY, rx: mw * 0.5, unit: unit)
            var leg = Path()
            leg.move(to: CGPoint(x: px + mw * 0.12, y: cy))
            leg.addLine(to: CGPoint(x: px + mw * 0.32, y: floorY - 1))
            ctx.stroke(leg, with: .color(Color(hex: 0xBA8246)), style: StrokeStyle(lineWidth: max(2.2, unit * 0.015), lineCap: .round))
            let frameRect = CGRect(x: px - mw * 0.5, y: cy - mh * 0.5, width: mw, height: mh)
            let frame = Path(roundedRect: frameRect, cornerSize: CGSize(width: mw * 0.48, height: mw * 0.48))
            ctx.fill(frame, with: .color(dark ? Color(hex: 0xD2A265) : Color(hex: 0xEEC487)))
            let glass = Path(roundedRect: frameRect.insetBy(dx: mw * 0.12, dy: mw * 0.12), cornerSize: CGSize(width: mw * 0.38, height: mw * 0.38))
            ctx.fill(glass, with: .color(dark ? Color(hex: 0x2F4474) : Color(hex: 0xDCEFF9)))
            let rDot = mw * 0.13
            ctx.fill(Path(ellipseIn: CGRect(x: px - rDot * 1.1, y: cy - rDot * 0.4, width: rDot * 1.8, height: rDot * 1.8)), with: .color(Palette.bead.opacity(0.85)))

        case .woodRing:
            let rOut = unit * 0.095
            let rIn = rOut * 0.52
            let cy = floorY - rOut - unit * 0.02
            shadow(in: &ctx, x: px, floorY: floorY, rx: rOut, unit: unit)
            var p = Path()
            p.addEllipse(in: CGRect(x: px - rOut, y: cy - rOut, width: rOut * 2, height: rOut * 2))
            p.addEllipse(in: CGRect(x: px - rIn, y: cy - rIn, width: rIn * 2, height: rIn * 2))
            ctx.fill(p, with: .color(dark ? Color(hex: 0xBA894E) : Color(hex: 0xE6BA7F)), style: FillStyle(eoFill: true))
            let midR = (rOut + rIn) * 0.5
            let br = (rOut - rIn) * 0.52
            for (i, c) in [Crayon.teal, Crayon.sunflower, Crayon.pink].enumerated() {
                let a = 1.0 + Double(i) * 0.57
                let bx = px + CGFloat(cos(a)) * midR
                let by = cy + CGFloat(sin(a)) * midR
                ctx.fill(Path(ellipseIn: CGRect(x: bx - br, y: by - br, width: br * 2, height: br * 2)), with: .color(c))
            }

        case .rattle:
            let cy = floorY - unit * 0.08
            shadow(in: &ctx, x: px, floorY: floorY, rx: unit * 0.09, unit: unit)
            var c = ctx
            c.translateBy(x: px, y: cy)
            c.rotate(by: .degrees(-18))
            c.fill(Path(roundedRect: CGRect(x: -unit * 0.09, y: -unit * 0.016, width: unit * 0.13, height: unit * 0.032), cornerRadius: unit * 0.016), with: .color(dark ? Color(hex: 0xC6975B) : Color(hex: 0xECC085)))
            let hr = unit * 0.052
            c.fill(Path(ellipseIn: CGRect(x: unit * 0.03, y: -hr, width: hr * 2, height: hr * 2)), with: .color(Crayon.lilac))

        case .firstFoodBowl:
            let bw = unit * 0.21
            let bh = unit * 0.095
            let cy = floorY - bh * 0.5
            shadow(in: &ctx, x: px, floorY: floorY, rx: bw * 0.45, unit: unit)
            // Mashed pumpkin puree mound visible atop rim
            ctx.fill(Path(ellipseIn: CGRect(x: px - bw * 0.36, y: cy - bh * 0.65, width: bw * 0.72, height: bh * 0.52)), with: .color(Crayon.tangerine))
            var bowl = Path()
            bowl.move(to: CGPoint(x: px - bw * 0.5, y: cy - bh * 0.4))
            bowl.addLine(to: CGPoint(x: px + bw * 0.5, y: cy - bh * 0.4))
            bowl.addQuadCurve(to: CGPoint(x: px + bw * 0.30, y: floorY), control: CGPoint(x: px + bw * 0.48, y: floorY - bh * 0.1))
            bowl.addLine(to: CGPoint(x: px - bw * 0.30, y: floorY))
            bowl.addQuadCurve(to: CGPoint(x: px - bw * 0.5, y: cy - bh * 0.4), control: CGPoint(x: px - bw * 0.48, y: floorY - bh * 0.1))
            bowl.closeSubpath()
            ctx.fill(bowl, with: .color(Crayon.mint))
            // Resting bamboo spoon on right rim
            var sp = ctx
            sp.translateBy(x: px + bw * 0.26, y: cy - bh * 0.48)
            sp.rotate(by: .degrees(24))
            sp.fill(Path(roundedRect: CGRect(x: -unit * 0.01, y: -unit * 0.07, width: unit * 0.02, height: unit * 0.09), cornerRadius: 2), with: .color(Color(hex: 0xDFB172)))

        case .peekScarf:
            let cw = unit * 0.24
            let ch = unit * 0.12
            shadow(in: &ctx, x: px, floorY: floorY, rx: cw * 0.48, unit: unit)
            let p = Path(roundedRect: CGRect(x: px - cw * 0.5, y: floorY - ch, width: cw, height: ch), cornerRadius: ch * 0.38)
            ctx.fill(p, with: .color(dark ? Color(hex: 0xDFCEBA) : Color(hex: 0xFAF0DF)))
            var clipped = ctx
            clipped.clip(to: p)
            clipped.fill(Path(CGRect(x: px - cw * 0.55, y: floorY - ch * 0.58, width: cw * 1.1, height: ch * 0.18)), with: .color(Crayon.pink.opacity(0.45)))

        case .boardBook:
            let bw = unit * 0.26
            let bh = unit * 0.12
            let baseY = floorY - bh * 0.44
            shadow(in: &ctx, x: px, floorY: floorY, rx: bw * 0.48, unit: unit)
            ctx.fill(Path(roundedRect: CGRect(x: px - bw * 0.52, y: baseY - bh * 0.44, width: bw * 1.04, height: bh * 0.92), cornerRadius: 5), with: .color(Crayon.caramel))
            let pg = dark ? Color(hex: 0xEAE0CE) : Color(hex: 0xFFFDF7)
            ctx.fill(Path(roundedRect: CGRect(x: px - bw * 0.47, y: baseY - bh * 0.50, width: bw * 0.46, height: bh * 0.86), cornerRadius: 3), with: .color(pg))
            ctx.fill(Path(roundedRect: CGRect(x: px + bw * 0.01, y: baseY - bh * 0.50, width: bw * 0.46, height: bh * 0.86), cornerRadius: 3), with: .color(pg.mix(with: .black, by: 0.04)))
            ctx.fill(Path(ellipseIn: CGRect(x: px - bw * 0.32, y: baseY - bh * 0.28, width: unit * 0.04, height: unit * 0.04)), with: .color(Crayon.sunflower))

        case .blockTower:
            let s = unit * 0.115
            let colors = [Crayon.sky, Crayon.sunflower, Crayon.cherry]
            shadow(in: &ctx, x: px, floorY: floorY, rx: s * 0.65, unit: unit)
            for (idx, col) in colors.enumerated() {
                let by = floorY - s * 0.5 - CGFloat(idx) * s
                let rect = CGRect(x: px - s * 0.5, y: by - s * 0.5, width: s, height: s)
                let p = Path(roundedRect: rect, cornerRadius: s * 0.18)
                ctx.fill(
                    p,
                    with: flat ? .color(col) : .linearGradient(Gradient(colors: [col.mix(with: .white, by: 0.20), col, col.mix(with: .black, by: 0.12)]), startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.maxX, y: rect.maxY))
                )
            }

        case .openCup:
            let cw = unit * 0.125
            let ch = unit * 0.12
            shadow(in: &ctx, x: px, floorY: floorY, rx: cw * 0.5, unit: unit)
            var cup = Path()
            cup.move(to: CGPoint(x: px - cw * 0.5, y: floorY - ch))
            cup.addLine(to: CGPoint(x: px + cw * 0.5, y: floorY - ch))
            cup.addLine(to: CGPoint(x: px + cw * 0.38, y: floorY))
            cup.addLine(to: CGPoint(x: px - cw * 0.38, y: floorY))
            cup.closeSubpath()
            ctx.fill(cup, with: .color(Crayon.teal))
            ctx.fill(Path(ellipseIn: CGRect(x: px - cw * 0.44, y: floorY - ch - unit * 0.012, width: cw * 0.88, height: unit * 0.024)), with: .color(Crayon.sky.opacity(0.85)))

        case .rollingBall:
            let r = unit * 0.085
            let cy = floorY - r
            shadow(in: &ctx, x: px, floorY: floorY, rx: r * 1.05, unit: unit)
            let circle = Path(ellipseIn: CGRect(x: px - r, y: cy - r, width: r * 2, height: r * 2))
            ctx.fill(circle, with: .color(Crayon.teal))
            var clipped = ctx
            clipped.clip(to: circle)
            clipped.fill(Path(ellipseIn: CGRect(x: px - r * 1.1, y: cy - r * 0.5, width: r * 0.9, height: r)), with: .color(Crayon.peach))
            clipped.fill(Path(ellipseIn: CGRect(x: px + r * 0.2, y: cy - r * 0.5, width: r * 0.9, height: r)), with: .color(Crayon.sunflower))

        case .beeswaxCrayon:
            let bw = unit * 0.26
            let bh = unit * 0.075
            let paper = Path(roundedRect: CGRect(x: px - bw * 0.5, y: floorY - bh, width: bw, height: bh), cornerRadius: 3)
            ctx.fill(paper, with: .color(dark ? Color(hex: 0xEAE0CE) : Color(hex: 0xFFFDF7)))
            var wave = Path()
            wave.move(to: CGPoint(x: px - bw * 0.35, y: floorY - bh * 0.45))
            wave.addQuadCurve(to: CGPoint(x: px + bw * 0.28, y: floorY - bh * 0.55), control: CGPoint(x: px, y: floorY - bh * 0.85))
            ctx.stroke(wave, with: .color(Crayon.cherry), style: StrokeStyle(lineWidth: max(1.8, unit * 0.012), lineCap: .round))
            var cr = ctx
            cr.translateBy(x: px + bw * 0.28, y: floorY - bh * 0.55)
            cr.rotate(by: .degrees(24))
            cr.fill(Path(roundedRect: CGRect(x: -unit * 0.016, y: -unit * 0.08, width: unit * 0.032, height: unit * 0.08), cornerRadius: 3), with: .color(Crayon.cherry))

        case .pocketDoll:
            shadow(in: &ctx, x: px, floorY: floorY, rx: unit * 0.08, unit: unit)
            ctx.fill(Path(roundedRect: CGRect(x: px - unit * 0.048, y: floorY - unit * 0.11, width: unit * 0.096, height: unit * 0.11), cornerRadius: unit * 0.03), with: .color(Crayon.peach))
            let hr = unit * 0.040
            ctx.fill(Path(ellipseIn: CGRect(x: px - hr, y: floorY - unit * 0.175, width: hr * 2, height: hr * 2)), with: .color(Color(hex: dark ? 0xE6D3B5 : 0xFAF0DC)))
            ctx.fill(Path(roundedRect: CGRect(x: px - unit * 0.056, y: floorY - unit * 0.065, width: unit * 0.112, height: unit * 0.065), cornerRadius: unit * 0.02), with: .color(Crayon.sky))

        case .ringStacker:
            let baseW = unit * 0.20
            let baseH = unit * 0.028
            let pegH = unit * 0.17
            shadow(in: &ctx, x: px, floorY: floorY, rx: baseW * 0.5, unit: unit)
            let wood = dark ? Color(hex: 0xBA894E) : Color(hex: 0xDFAF72)
            ctx.fill(Path(roundedRect: CGRect(x: px - baseW * 0.5, y: floorY - baseH, width: baseW, height: baseH), cornerRadius: 4), with: .color(wood))
            ctx.fill(Path(roundedRect: CGRect(x: px - unit * 0.014, y: floorY - baseH - pegH, width: unit * 0.028, height: pegH), cornerRadius: 4), with: .color(wood))
            let rh = unit * 0.036
            for (i, pair) in [(unit * 0.17, Crayon.teal), (unit * 0.135, Crayon.sunflower), (unit * 0.10, Crayon.cherry)].enumerated() {
                let ry = floorY - baseH - rh * (0.5 + CGFloat(i))
                ctx.fill(Path(roundedRect: CGRect(x: px - pair.0 * 0.5, y: ry - rh * 0.5, width: pair.0, height: rh), cornerRadius: rh * 0.5), with: .color(pair.1))
            }

        case .woodBridge:
            let bs = unit * 0.105
            shadow(in: &ctx, x: px, floorY: floorY, rx: bs * 1.4, unit: unit)
            ctx.fill(Path(roundedRect: CGRect(x: px - bs * 1.25, y: floorY - bs, width: bs, height: bs), cornerRadius: bs * 0.16), with: .color(Crayon.sky))
            ctx.fill(Path(roundedRect: CGRect(x: px + bs * 0.25, y: floorY - bs, width: bs, height: bs), cornerRadius: bs * 0.16), with: .color(Crayon.teal))
            ctx.fill(Path(roundedRect: CGRect(x: px - bs * 1.4, y: floorY - bs * 1.52, width: bs * 2.8, height: bs * 0.52), cornerRadius: bs * 0.18), with: .color(Crayon.cherry))

        case .botanicalLeaf:
            let s = unit * 0.11
            let cy = floorY - s * 0.72
            shadow(in: &ctx, x: px, floorY: floorY, rx: s * 0.8, unit: unit)
            var leaf = Path()
            leaf.move(to: CGPoint(x: px, y: cy - s * 0.75))
            leaf.addQuadCurve(to: CGPoint(x: px, y: cy + s * 0.75), control: CGPoint(x: px + s * 0.85, y: cy))
            leaf.addQuadCurve(to: CGPoint(x: px, y: cy - s * 0.75), control: CGPoint(x: px - s * 0.85, y: cy))
            leaf.closeSubpath()
            ctx.fill(leaf, with: .color(Crayon.leaf))
            var vein = Path()
            vein.move(to: CGPoint(x: px, y: cy - s * 0.55))
            vein.addLine(to: CGPoint(x: px, y: floorY))
            ctx.stroke(vein, with: .color(Color(hex: 0xEEF8DC)), style: StrokeStyle(lineWidth: max(1.2, unit * 0.008), lineCap: .round))

        case .paperBoat:
            let bw = unit * 0.22
            let bh = unit * 0.11
            let baseY = isSecondary ? floorY : (floorY + unit * 0.11)
            if !isSecondary {
                shadow(in: &ctx, x: px, floorY: baseY + 2, rx: bw * 0.5, unit: unit)
            }
            var hull = Path()
            hull.move(to: CGPoint(x: px - bw * 0.5, y: baseY - bh * 0.45))
            hull.addLine(to: CGPoint(x: px + bw * 0.5, y: baseY - bh * 0.45))
            hull.addLine(to: CGPoint(x: px + bw * 0.32, y: baseY))
            hull.addLine(to: CGPoint(x: px - bw * 0.32, y: baseY))
            hull.closeSubpath()
            ctx.fill(hull, with: .color(dark ? Color(hex: 0xE6DFCE) : Color(hex: 0xFFFDF8)))
            var sail = Path()
            sail.move(to: CGPoint(x: px - bw * 0.22, y: baseY - bh * 0.45))
            sail.addLine(to: CGPoint(x: px, y: baseY - bh))
            sail.addLine(to: CGPoint(x: px + bw * 0.22, y: baseY - bh * 0.45))
            sail.closeSubpath()
            ctx.fill(sail, with: .color(dark ? Color(hex: 0xD7CEBC) : Color(hex: 0xF5ECDC)))

        case .steppingStones:
            let stones: [(CGFloat, CGFloat, CGFloat, Color)] = [
                (-unit * 0.09, unit * 0.095, unit * 0.042, Color(hex: dark ? 0x5B697D : 0xB8C3BA)),
                (unit * 0.01, unit * 0.11, unit * 0.048, Color(hex: dark ? 0x67778D : 0xCAD4C9)),
                (unit * 0.105, unit * 0.085, unit * 0.038, Color(hex: dark ? 0x4E5C70 : 0xA8B5AC)),
            ]
            for (dx, sw, sh, col) in stones {
                shadow(in: &ctx, x: px + dx, floorY: floorY, rx: sw * 0.5, unit: unit)
                ctx.fill(Path(ellipseIn: CGRect(x: px + dx - sw * 0.5, y: floorY - sh, width: sw, height: sh)), with: .color(col))
            }

        case .birthdayLantern:
            let lw = unit * 0.125
            let lh = unit * 0.14
            let saucerH = unit * 0.018
            let cy = floorY - saucerH - lh * 0.5
            shadow(in: &ctx, x: px, floorY: floorY, rx: lw * 0.68, unit: unit)
            ctx.fill(
                Path(ellipseIn: CGRect(x: px - lw * 1.1, y: cy - lh * 0.85, width: lw * 2.2, height: lh * 1.7)),
                with: .radialGradient(Gradient(colors: [Palette.amber.opacity(dark ? 0.42 : 0.24), .clear]), center: CGPoint(x: px, y: cy), startRadius: 2, endRadius: lw * 1.1)
            )
            ctx.fill(Path(roundedRect: CGRect(x: px - lw * 0.58, y: floorY - saucerH, width: lw * 1.16, height: saucerH), cornerRadius: 4), with: .color(Color(hex: 0xBA894E)))
            let body = Path(roundedRect: CGRect(x: px - lw * 0.5, y: cy - lh * 0.5, width: lw, height: lh), cornerRadius: lw * 0.36)
            ctx.fill(body, with: flat ? .color(Palette.amber) : .radialGradient(Gradient(colors: [Color(hex: 0xFFF7DB), Palette.amber, Crayon.tangerine]), center: CGPoint(x: px, y: cy), startRadius: 1, endRadius: lw * 0.7))
            ctx.fill(Path(roundedRect: CGRect(x: px - lw * 0.34, y: cy - lh * 0.54, width: lw * 0.68, height: lh * 0.13), cornerRadius: 2), with: .color(Color(hex: 0x8F622F)))
            ctx.fill(Path(roundedRect: CGRect(x: px - lw * 0.34, y: cy + lh * 0.41, width: lw * 0.68, height: lh * 0.13), cornerRadius: 2), with: .color(Color(hex: 0x8F622F)))
        }
    }
}
