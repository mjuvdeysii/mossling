import SwiftUI

/// A08 (Safe Texture Discovery · 4 Steps):
/// Montessori discovery tray holding two distinct swatches: quilted cream-sage muslin puff
/// and fluted birch wood sensory disc. Step 0: Offer pieces -> Step 1: Baby tactile touch ->
/// Step 2: Contrasting sensation curves ("soft" vs "bumpy") -> Step 3: Calm watch pause.
struct SceneA08_TextureDiscovery: View {
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

            let ms = s * 0.35
            let os = ms * Kind.otto.scale
            let groundY = h * 0.85

            let traySlideOffset: CGFloat = step == 0 ? CGFloat((1.0 - p.action) * w * 0.08) : 0
            let softSwatchPos = CGPoint(x: w * 0.43 - traySlideOffset, y: groundY - s * 0.04)
            let woodSwatchPos = CGPoint(x: w * 0.58 - traySlideOffset, y: groundY - s * 0.04)

            let mossX = w * 0.72
            let ottoX = w * 0.24

            let mossLean: Double = {
                switch step {
                case 0: return -3.0
                case 1: return -9.5 * p.action
                case 2: return -5.5
                default: return -4.0 + p.followThrough * 2.5
                }
            }()
            let ottoLean: Double = {
                switch step {
                case 0: return 9.0 * p.action
                case 1, 2: return 5.0
                default: return 2.0
                }
            }()

            let mossLook: CGPoint = {
                switch step {
                case 0, 1: return CGPoint(x: -0.72, y: 0.42)
                case 2: return CGPoint(x: -0.60, y: 0.28)
                default: return CGPoint(x: -0.45, y: 0.30)
                }
            }()
            let ottoLook = CGPoint(x: 0.65, y: 0.24)

            let mossMood: Mood = {
                switch step {
                case 1: return p.isContactWindow ? .wow : .open
                case 2: return .happy
                default: return .open
                }
            }()
            let ottoMood: Mood = step == 2 ? .happy : .open

            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundY, flat: flat)
            )
            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundY, flat: flat)
            )

            let ottoState = Creature.state(.otto, face: ottoMood, look: ottoLook, lid: dark ? 0.40 : 0.24, hopping: false, yawning: false)
            let beadWorld = LampLightRig.beadWorldPosition(
                ottoCenter: ottoCenter,
                ottoSize: os,
                ottoState: ottoState,
                leanDegrees: ottoLean,
                flat: flat
            )

            ZStack {
                Canvas(rendersAsynchronously: false) { c, size in
                    drawTextureMatStage(
                        in: &c,
                        w: size.width,
                        h: size.height,
                        groundY: groundY,
                        softPos: softSwatchPos,
                        woodPos: woodSwatchPos,
                        ottoPos: CGPoint(x: ottoCenter.x + os * 0.20, y: ottoCenter.y - os * 0.04),
                        mossPos: CGPoint(x: mossCenter.x - ms * 0.22, y: mossCenter.y + ms * 0.06),
                        step: step,
                        p: p,
                        flat: flat,
                        dark: dark
                    )
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: woodSwatchPos,
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
                    lid: dark ? 0.40 : 0.24,
                    lean: ottoLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.78, y: -0.62),
                    secondaryLagDegrees: -ottoLean * 0.30
                )
                .position(ottoCenter)

                StoryTheaterActorView(
                    kind: .moss,
                    size: ms,
                    mood: mossMood,
                    look: mossLook,
                    lid: dark ? 0.18 : 0,
                    lean: mossLean,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.78, y: -0.62),
                    secondaryLagDegrees: -mossLean * 0.42
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: woodSwatchPos,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawTextureMatStage(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        groundY: CGFloat,
        softPos: CGPoint,
        woodPos: CGPoint,
        ottoPos: CGPoint,
        mossPos: CGPoint,
        step: Int,
        p: LivingPhaseSample,
        flat: Bool,
        dark: Bool
    ) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xFAF7ED),
            dayBottom: Color(hex: 0xECE5D1),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x16223C),
            dark: dark
        )

        let horizonY = h * 0.74
        let matRect = CGRect(x: -6, y: horizonY, width: w + 12, height: h - horizonY + 8)
        ctx.fill(
            Path(matRect),
            with: .linearGradient(
                Gradient(colors: [
                    dark ? Color(hex: 0x22314A) : Color(hex: 0xF5EEDD),
                    dark ? Color(hex: 0x152035) : Color(hex: 0xDDD3BE)
                ]),
                startPoint: CGPoint(x: w * 0.5, y: horizonY),
                endPoint: CGPoint(x: w * 0.5, y: h)
            )
        )
        // Woven bouclé linen carpet border & subtle floorboard warmth
        var trim = Path()
        trim.move(to: CGPoint(x: 0, y: horizonY + 2))
        trim.addLine(to: CGPoint(x: w, y: horizonY + 2))
        ctx.stroke(
            trim,
            with: .color((dark ? Color(hex: 0x5B739E) : Color(hex: 0xB8A482)).opacity(dark ? 0.42 : 0.52)),
            style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])
        )

        // Swatch 1: Soft quilted sage muslin puff with linen piping & central tuft
        let puffR = min(w, h) * 0.072
        let puffSquash: CGFloat = (step == 1 && p.isContactWindow) ? CGFloat(p.contact * 0.14) : 0
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: softPos.x, y: groundY + 1), rx: puffR, ry: puffR * 0.25, dark: dark)
        let puffRect = CGRect(
            x: softPos.x - puffR * (1.0 + puffSquash * 0.4),
            y: softPos.y - puffR * 0.75 * (1.0 - puffSquash),
            width: puffR * 2.0 * (1.0 + puffSquash * 0.4),
            height: puffR * 1.5 * (1.0 - puffSquash)
        )
        let puffPath = Path(roundedRect: puffRect, cornerRadius: puffR * 0.65)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: puffPath,
                bounds: puffRect,
                light: dark ? Color(hex: 0x3D6257) : Color(hex: 0xD2E8D6),
                rich: dark ? Color(hex: 0x28473F) : Color(hex: 0x9DC7AA),
                pencilOutline: (dark ? Color(hex: 0x8CC4AC) : Color(hex: 0x568265)).opacity(0.6),
                lineWidth: 1.1
            )
        } else {
            ctx.fill(
                puffPath,
                with: .radialGradient(
                    Gradient(colors: [Color(hex: 0xCFE8D5), Color(hex: 0x89BA98)]),
                    center: CGPoint(x: softPos.x - puffR * 0.2, y: softPos.y - puffR * 0.2),
                    startRadius: 1,
                    endRadius: puffR * 1.4
                )
            )
            ctx.stroke(
                Path(roundedRect: puffRect.insetBy(dx: 1.5, dy: 1.5), cornerRadius: puffR * 0.60),
                with: .color(Color.white.opacity(dark ? 0.16 : 0.42)),
                lineWidth: 1.0
            )
        }
        // Diamond quilted seams & center linen button tuft
        for sign in [CGFloat(1.0), CGFloat(-1.0)] {
            ctx.stroke(
                Path { path in
                    path.move(to: CGPoint(x: softPos.x - puffR * 0.45, y: softPos.y - sign * puffR * 0.35))
                    path.addLine(to: CGPoint(x: softPos.x + puffR * 0.45, y: softPos.y + sign * puffR * 0.35))
                },
                with: .color((dark ? Color(hex: 0x9BD2B4) : Color(hex: 0x5C8569)).opacity(0.42)),
                style: StrokeStyle(lineWidth: 1.0, dash: [3, 3])
            )
        }
        ctx.fill(
            Path(ellipseIn: CGRect(x: softPos.x - 2.6, y: softPos.y - 2.2, width: 5.2, height: 4.4)),
            with: .color(dark ? Color(hex: 0xB8DEC6) : Color(hex: 0x568265))
        )

        // Swatch 2: Fluted beechwood sensory roller/disc
        let woodW = min(w, h) * 0.13
        let woodH = woodW * 0.62
        PixarDrawHelpers.drawContactAO(in: &ctx, center: CGPoint(x: woodPos.x, y: groundY + 1), rx: woodW * 0.52, ry: woodH * 0.28, dark: dark)
        let woodRect = CGRect(x: woodPos.x - woodW * 0.5, y: woodPos.y - woodH * 0.5, width: woodW, height: woodH)
        let woodPath = Path(roundedRect: woodRect, cornerRadius: woodH * 0.35)
        PixarDrawHelpers.drawBeechwood(in: &ctx, path: woodPath, bounds: woodRect, dark: dark, warmth: 0.75, grainLines: 3)
        // Tactile fluted ridges across top of disc
        for r in -1...1 {
            let rx = woodPos.x + CGFloat(r) * woodW * 0.22
            ctx.stroke(
                Path { path in
                    path.move(to: CGPoint(x: rx, y: woodRect.minY + 3))
                    path.addLine(to: CGPoint(x: rx, y: woodRect.maxY - 3))
                },
                with: .color((dark ? Color(hex: 0x4A2E14) : Color(hex: 0x8C5E2F)).opacity(0.45)),
                lineWidth: 1.3
            )
        }

        if step == 1 {
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: CGPoint(x: (softPos.x + mossPos.x) * 0.5, y: softPos.y - puffR),
                pulse: p.contact,
                radius: min(w, h) * 0.085,
                color: Palette.amber
            )
        } else if step == 2 {
            // Two contrasting sensation waveforms ("soft" smooth arc + "bumpy" scalloped wave)
            BespokeStageHelpers.drawSilkVoiceRibbon(
                in: &ctx,
                from: ottoPos,
                to: mossPos,
                progress: p.action,
                waveOffset: p.raw * .pi * 2.0,
                color: Crayon.teal,
                lineWidth: 2.3,
                dark: dark
            )
            var bumpy = Path()
            let bx0 = woodPos.x - woodW * 0.5
            for i in 0...16 {
                let t = CGFloat(i) / 16.0 * CGFloat(p.action)
                let pt = CGPoint(x: bx0 + woodW * t, y: woodPos.y - woodH * 1.1 - CGFloat(abs(sin(Double(i) * 0.9)) * 7.0))
                if i == 0 { bumpy.move(to: pt) } else { bumpy.addLine(to: pt) }
            }
            ctx.stroke(bumpy, with: .color(Palette.amber.opacity(0.8)), style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
        } else if step == 3 {
            BespokeStageHelpers.drawPauseHalo(
                in: &ctx,
                center: CGPoint(x: (softPos.x + woodPos.x) * 0.5, y: softPos.y - puffR * 1.2),
                baseRadius: min(w, h) * 0.11,
                progress: p.raw,
                tint: Crayon.teal,
                dark: dark
            )
        }
    }
}
