import SwiftUI

/// Showcase 2 (A04): Macro sunlit grasping playmat with hand-stitched diamond seams,
/// soft-bokeh background wood rattle, 3-bead beechwood grasping ring on parabolic presentation arc,
/// breathing patience halo, and tactile palm-contact golden sparkle lift.
struct SceneA04_WatchHandsReach: View {
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

            // 1:1 shared spatial coordinates across Pixar 3D & Ghibli 2D
            let ms = s * 0.37
            let os = ms * Kind.otto.scale
            let groundMoss = h * 0.845
            let groundOtto = h * 0.845

            // Parabolic ring trajectory & floor rest across the 3 steps
            let ringPos: CGPoint = {
                let start = CGPoint(x: w * 0.67, y: h * 0.65)
                let offerSpot = CGPoint(x: w * 0.535, y: h * 0.765)
                let closeSpot = CGPoint(x: w * 0.405, y: h * 0.770)
                let liftSpot = CGPoint(x: w * 0.345, y: h * 0.585)

                switch step {
                case 0:
                    let t = CGFloat(p.action)
                    let x = start.x + (offerSpot.x - start.x) * t
                    let baseY = start.y + (offerSpot.y - start.y) * t
                    let arc = sin(Double(t) * .pi) * h * 0.14
                    return CGPoint(x: x, y: baseY - CGFloat(arc))
                case 1:
                    let bob = sin(p.raw * .pi * 2.0) * 2.2
                    return CGPoint(x: offerSpot.x, y: offerSpot.y + CGFloat(bob))
                default:
                    if p.raw < 0.46 {
                        let t = CGFloat(p.action)
                        return CGPoint(
                            x: offerSpot.x + (closeSpot.x - offerSpot.x) * t,
                            y: offerSpot.y + (closeSpot.y - offerSpot.y) * t - CGFloat(sin(Double(t) * .pi) * 6.0)
                        )
                    } else {
                        let liftT = CGFloat(p.followThrough)
                        return CGPoint(
                            x: closeSpot.x + (liftSpot.x - closeSpot.x) * liftT,
                            y: closeSpot.y + (liftSpot.y - closeSpot.y) * liftT
                        )
                    }
                }
            }()

            let ringAngle: Double = {
                switch step {
                case 0: return -14.0 * (1.0 - p.action) + sin(p.followThrough * .pi) * 6.0
                case 1: return sin(p.raw * .pi * 2.0) * 3.0
                default: return -12.0 * p.followThrough
                }
            }()

            let mossHopLift: CGFloat = step == 2
                ? CGFloat(max(0.0, sin((p.raw - 0.46) / 0.34 * .pi))) * ms * 0.12
                : 0
            let mossLean: Double = {
                switch step {
                case 0: return 4.0 + p.action * 5.0
                case 1: return 8.0 + p.anticipation * 3.0
                default: return p.raw >= 0.46 ? -5.0 + p.followThrough * 8.0 : 9.0
                }
            }()
            let ottoLean: Double = {
                switch step {
                case 0: return -10.0 * p.action
                case 1: return -3.0
                default: return -8.0 * p.action + p.followThrough * 4.0
                }
            }()

            let mossSquash: CGSize = {
                if step == 1 {
                    let sAmt = p.anticipation * 0.045
                    return CGSize(width: 1.0 + sAmt * 0.5, height: 1.0 - sAmt)
                } else if step == 2 && p.raw >= 0.44 && p.raw < 0.62 {
                    let sAmt = sin((p.raw - 0.44) / 0.18 * .pi) * 0.07
                    return CGSize(width: 1.0 + sAmt * 0.5, height: 1.0 - sAmt)
                }
                return CGSize(width: 1, height: 1)
            }()

            let mossX = w * (step == 2 && p.followThrough > 0.2 ? 0.255 : 0.24)
            let ottoX = w * 0.765

            let mossCenter = CGPoint(
                x: mossX,
                y: BespokeStageHelpers.actorCenterY(kind: .moss, size: ms, groundY: groundMoss, flat: flat, lift: mossHopLift)
            )
            let ottoCenter = CGPoint(
                x: ottoX,
                y: BespokeStageHelpers.actorCenterY(kind: .otto, size: os, groundY: groundOtto, flat: flat)
            )

            // Vector gaze: Moss tracks the moving beechwood ring dynamically
            let dx = max(-1.0, min(1.0, Double((ringPos.x - mossCenter.x) / max(1, w * 0.35))))
            let dy = max(-1.0, min(1.0, Double((ringPos.y - mossCenter.y) / max(1, h * 0.35))))
            let mossLook = CGPoint(x: dx, y: dy)
            let ottoLook = CGPoint(x: -0.78, y: 0.18)

            let ottoMood: Mood = step == 2 && p.isContactWindow ? .happy : .open
            let mossMood: Mood = {
                switch step {
                case 0: return .wow
                case 1: return .open
                default: return p.raw >= 0.46 ? .happy : .wow
                }
            }()

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
                    drawMacroPlaymat(in: &c, w: size.width, h: size.height, flat: flat, dark: dark)
                }

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: ringPos,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .floorPool
                )

                // Patience halo (Step 1) or contact sparkle burst (Step 2)
                Canvas(rendersAsynchronously: false) { c, size in
                    if step == 1 {
                        BespokeStageHelpers.drawPauseHalo(
                            in: &c,
                            center: ringPos,
                            baseRadius: min(size.width, size.height) * 0.115,
                            progress: p.raw,
                            tint: Palette.amber,
                            dark: dark
                        )
                    } else if step == 2 {
                        BespokeStageHelpers.drawContactSparkles(
                            in: &c,
                            center: CGPoint(x: mossCenter.x + ms * 0.25, y: mossCenter.y + ms * 0.08),
                            pulse: p.contact,
                            radius: min(size.width, size.height) * 0.10,
                            color: Palette.amber
                        )
                    }
                    drawGraspingRing(
                        in: &c,
                        center: ringPos,
                        groundY: groundMoss + 2,
                        radius: min(size.width, size.height) * 0.068,
                        angleDegrees: ringAngle,
                        flat: flat,
                        dark: dark
                    )
                }

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
                    lightDirection: CGPoint(x: 0.78, y: -0.62),
                    secondaryLagDegrees: -ottoLean * 0.30
                )
                .position(ottoCenter)

                StoryTheaterActorView(
                    kind: .moss,
                    size: ms,
                    mood: mossMood,
                    look: mossLook,
                    lid: dark ? 0.20 : 0,
                    lean: mossLean,
                    hopLift: mossHopLift / max(1, ms),
                    hopping: step == 2 && p.isContactWindow,
                    breathTime: ctx.breathTime,
                    isStatic: ctx.isStatic,
                    dark: dark,
                    flat: flat,
                    compact: ctx.compact,
                    lightDirection: CGPoint(x: 0.78, y: -0.62),
                    secondaryLagDegrees: step == 2 ? sin(p.followThrough * .pi) * 14.0 : -mossLean * 0.45,
                    postureScale: mossSquash
                )
                .position(mossCenter)

                LampLightRig(
                    beadPos: beadWorld,
                    targetPoint: ringPos,
                    phase: p,
                    dark: dark,
                    flat: flat,
                    layer: .airCone
                )
                .blendMode(dark ? .plusLighter : .normal)
            }
        }
    }

    private func drawMacroPlaymat(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, flat: Bool, dark: Bool) {
        BespokeStageHelpers.drawAtmosphereWash(
            in: &ctx,
            w: w,
            h: h,
            dayTop: Color(hex: 0xFAF7ED),
            dayBottom: Color(hex: 0xECE5D1),
            nightTop: Color(hex: 0x0B1325),
            nightBottom: Color(hex: 0x17243F),
            dark: dark
        )

        // Diagonal morning sun-pane / cozy nursery glow across grasping area
        var lightWash = Path()
        lightWash.move(to: CGPoint(x: w * 0.30, y: 0))
        lightWash.addLine(to: CGPoint(x: w * 0.88, y: 0))
        lightWash.addLine(to: CGPoint(x: w * 0.68, y: h * 0.90))
        lightWash.addLine(to: CGPoint(x: w * 0.14, y: h * 0.90))
        lightWash.closeSubpath()
        ctx.fill(
            lightWash,
            with: .linearGradient(
                Gradient(colors: [
                    (dark ? Color(hex: 0x263963) : Color(hex: 0xFFF7D8)).opacity(dark ? 0.22 : 0.45),
                    Color.clear
                ]),
                startPoint: CGPoint(x: w * 0.65, y: 0),
                endPoint: CGPoint(x: w * 0.40, y: h * 0.88)
            )
        )

        // Soft out-of-focus background cylinder block at left-mid depth for cinema parallax
        let bgBlock = CGRect(x: w * 0.11, y: h * 0.50, width: w * 0.08, height: h * 0.11)
        ctx.fill(
            Path(roundedRect: bgBlock, cornerRadius: 6),
            with: .color((dark ? Color(hex: 0x2A3B5E) : Color(hex: 0xDFC7A1)).opacity(flat ? 0.55 : 0.42))
        )

        // Quilted sage-and-oatmeal macro mat
        let matY = h * 0.62
        var mat = Path()
        mat.move(to: CGPoint(x: -8, y: matY + h * 0.03))
        mat.addQuadCurve(to: CGPoint(x: w + 8, y: matY), control: CGPoint(x: w * 0.48, y: matY - h * 0.04))
        mat.addLine(to: CGPoint(x: w + 8, y: h + 8))
        mat.addLine(to: CGPoint(x: -8, y: h + 8))
        mat.closeSubpath()

        let matBounds = CGRect(x: 0, y: matY - h * 0.03, width: w, height: h - matY + h * 0.05)
        if flat {
            GhibliDrawHelpers.fillWatercolor(
                in: &ctx,
                path: mat,
                bounds: matBounds,
                light: dark ? Color(hex: 0x243448) : Color(hex: 0xF3ECDC),
                rich: dark ? Color(hex: 0x1A2639) : Color(hex: 0xDCE1CF),
                pencilOutline: (dark ? Color(hex: 0x5B769C) : Color(hex: 0x8E9E84)).opacity(0.45),
                lineWidth: 1.2
            )
        } else {
            ctx.fill(
                mat,
                with: .linearGradient(
                    Gradient(colors: [
                        dark ? Color(hex: 0x22304B) : Color(hex: 0xF8F2E4),
                        dark ? Color(hex: 0x152035) : Color(hex: 0xE2DFCC)
                    ]),
                    startPoint: CGPoint(x: w * 0.5, y: matY),
                    endPoint: CGPoint(x: w * 0.5, y: h)
                )
            )
        }

        // Quilted diamond stitch lines in shallow perspective
        let stitchColor = (dark ? Color(hex: 0x5C789E) : Color(hex: 0x99AD8F)).opacity(dark ? 0.25 : 0.34)
        for i in 0..<5 {
            let xStart = w * (0.08 + CGFloat(i) * 0.21)
            var d = Path()
            d.move(to: CGPoint(x: xStart, y: matY + h * 0.02))
            d.addLine(to: CGPoint(x: xStart - w * 0.14, y: h))
            ctx.stroke(d, with: .color(stitchColor), style: StrokeStyle(lineWidth: 1.0, dash: [4, 5]))
        }
    }

    private func drawGraspingRing(
        in ctx: inout GraphicsContext,
        center: CGPoint,
        groundY: CGFloat,
        radius: CGFloat,
        angleDegrees: Double,
        flat: Bool,
        dark: Bool
    ) {
        let heightAboveGround = max(0, groundY - center.y)
        let shadowScale = max(0.45, 1.0 - Double(heightAboveGround / max(1, groundY)) * 0.65)
        PixarDrawHelpers.drawContactAO(
            in: &ctx,
            center: CGPoint(x: center.x, y: groundY),
            rx: radius * 0.95 * CGFloat(shadowScale),
            ry: radius * 0.24 * CGFloat(shadowScale),
            dark: dark,
            opacity: shadowScale * 0.85
        )

        var ringCtx = ctx
        ringCtx.translateBy(x: center.x, y: center.y)
        ringCtx.rotate(by: .degrees(angleDegrees))

        let outer = radius
        let inner = radius * 0.54
        var ringPath = Path()
        ringPath.addEllipse(in: CGRect(x: -outer, y: -outer, width: outer * 2, height: outer * 2))
        ringPath.addEllipse(in: CGRect(x: -inner, y: -inner, width: inner * 2, height: inner * 2))

        let bounds = CGRect(x: -outer, y: -outer, width: outer * 2, height: outer * 2)
        if flat {
            ringCtx.fill(
                ringPath,
                with: .linearGradient(
                    Gradient(colors: [
                        dark ? Color(hex: 0xBA864E) : Color(hex: 0xECC48A),
                        dark ? Color(hex: 0x875B2E) : Color(hex: 0xC68E4D)
                    ]),
                    startPoint: CGPoint(x: -outer, y: -outer),
                    endPoint: CGPoint(x: outer, y: outer)
                ),
                style: FillStyle(eoFill: true)
            )
            ringCtx.stroke(
                Path(ellipseIn: bounds),
                with: .color((dark ? Color(hex: 0xE2BA82) : Color(hex: 0x7A5328)).opacity(0.60)),
                lineWidth: 1.2
            )
        } else {
            var clipped = ringCtx
            clipped.clip(to: ringPath, style: FillStyle(eoFill: true))
            PixarDrawHelpers.drawBeechwood(
                in: &clipped,
                path: Path(ellipseIn: bounds),
                bounds: bounds,
                dark: dark,
                warmth: 0.8,
                grainLines: 3
            )
            ringCtx.stroke(
                Path(ellipseIn: CGRect(x: -inner, y: -inner, width: inner * 2, height: inner * 2)),
                with: .color(Color.black.opacity(dark ? 0.35 : 0.16)),
                lineWidth: 1.2
            )
        }

        // 3 tactile colored beads threaded around top arc of grasping ring (sage, amber, cream)
        let beads: [(Double, Color)] = [
            (-1.95, Color(hex: dark ? 0x67A87C : 0x7EB48B)),
            (-1.20, Palette.amber),
            (-0.45, Color(hex: dark ? 0xE5CCA4 : 0xF5DFB6))
        ]
        let orbitR = (outer + inner) * 0.5
        let beadR = radius * 0.25
        for (theta, tint) in beads {
            let bx = cos(theta) * orbitR
            let by = sin(theta) * orbitR
            let bRect = CGRect(x: bx - beadR, y: by - beadR, width: beadR * 2, height: beadR * 2)
            ringCtx.fill(
                Path(ellipseIn: bRect),
                with: .radialGradient(
                    Gradient(colors: [tint.mix(with: .white, by: flat ? 0.15 : 0.34), tint]),
                    center: CGPoint(x: bx - beadR * 0.3, y: by - beadR * 0.3),
                    startRadius: 0,
                    endRadius: beadR * 1.3
                )
            )
            if flat {
                ringCtx.stroke(Path(ellipseIn: bRect), with: .color(Color(hex: 0x5C4D3A).opacity(0.45)), lineWidth: 0.9)
            }
        }
    }
}
