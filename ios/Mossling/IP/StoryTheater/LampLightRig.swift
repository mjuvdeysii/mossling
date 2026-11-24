import SwiftUI

/// Renders Otto's real-time golden lamp beam tracked directly from `Sprites.bead` / `FlatCreature` coordinates,
/// casting a warm directional amber cone and floor pool onto the active Montessori prop.
struct LampLightRig: View {
    enum Layer {
        case floorPool
        case airCone
    }

    let beadPos: CGPoint
    let targetPoint: CGPoint
    let phase: LivingPhaseSample
    let dark: Bool
    let flat: Bool
    let layer: Layer

    /// Computes exact world coordinates of Otto's golden lamp bead accounting for sprite frame & foot-anchored lean.
    static func beadWorldPosition(
        ottoCenter: CGPoint,
        ottoSize: CGFloat,
        ottoState: String,
        leanDegrees: Double,
        flat: Bool
    ) -> CGPoint {
        let feetFrac: CGFloat = flat ? 0.88 : (Sprites.ottoFeet / 100.0)
        let beadFrac: CGPoint = flat
            ? CGPoint(x: 0.20, y: 0.115)
            : (Sprites.bead[ottoState] ?? Sprites.bead["idle"] ?? CGPoint(x: 0.247, y: 0.4317))

        let dx = (beadFrac.x - 0.5) * ottoSize
        let dy = (beadFrac.y - feetFrac) * ottoSize
        let rad = leanDegrees * .pi / 180.0
        let cosA = CGFloat(Foundation.cos(rad))
        let sinA = CGFloat(Foundation.sin(rad))

        let rx = dx * cosA - dy * sinA
        let ry = dx * sinA + dy * cosA

        let pivotX = ottoCenter.x
        let pivotY = ottoCenter.y + (feetFrac - 0.5) * ottoSize
        return CGPoint(x: pivotX + rx, y: pivotY + ry)
    }

    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let poolRx = w * 0.25
            let poolRy: CGFloat = max(10, size.height * 0.055)
            let breath = 0.94 + 0.06 * sin(phase.raw * .pi * 2.0)

            switch layer {
            case .floorPool:
                let poolRect = CGRect(
                    x: targetPoint.x - poolRx,
                    y: targetPoint.y - poolRy * 0.65,
                    width: poolRx * 2,
                    height: poolRy * 1.3
                )
                let alpha: Double = dark ? (flat ? 0.36 : 0.44 * breath) : (flat ? 0.14 : 0.20 * breath)
                ctx.fill(
                    Path(ellipseIn: poolRect),
                    with: .radialGradient(
                        Gradient(colors: [Color(hex: 0xFFE3A3).opacity(alpha), Color(hex: 0xFFE3A3).opacity(0)]),
                        center: CGPoint(x: poolRect.midX, y: poolRect.midY),
                        startRadius: 2,
                        endRadius: poolRx
                    )
                )

            case .airCone:
                let haloR = w * (dark ? 0.30 : 0.16)
                let haloAlpha: Double = dark ? 0.28 * breath : 0.11 * breath
                ctx.fill(
                    Path(ellipseIn: CGRect(x: beadPos.x - haloR, y: beadPos.y - haloR, width: haloR * 2, height: haloR * 2)),
                    with: .radialGradient(
                        Gradient(colors: [Palette.amber.opacity(haloAlpha), Palette.amber.opacity(0)]),
                        center: beadPos,
                        startRadius: 1,
                        endRadius: haloR
                    )
                )

                var cone = Path()
                cone.move(to: CGPoint(x: beadPos.x - 4, y: beadPos.y))
                cone.addLine(to: CGPoint(x: beadPos.x + 4, y: beadPos.y))
                cone.addLine(to: CGPoint(x: targetPoint.x + poolRx * 0.92, y: targetPoint.y))
                cone.addLine(to: CGPoint(x: targetPoint.x - poolRx * 0.92, y: targetPoint.y))
                cone.closeSubpath()

                let topAlpha: Double = dark ? (flat ? 0.22 : 0.28 * breath) : (flat ? 0.07 : 0.10 * breath)
                let botAlpha: Double = dark ? 0.03 : 0.01
                ctx.fill(
                    cone,
                    with: .linearGradient(
                        Gradient(colors: [Color(hex: 0xFFD98A).opacity(topAlpha), Color(hex: 0xFFD98A).opacity(botAlpha)]),
                        startPoint: beadPos,
                        endPoint: targetPoint
                    )
                )

                if dark && !flat {
                    for i in 0..<5 {
                        let frac = 0.22 + Double(i) * 0.15
                        let drift = CGFloat(sin(phase.raw * .pi * 2.0 + Double(i) * 1.4) * 8.0)
                        let px = beadPos.x + (targetPoint.x - beadPos.x) * CGFloat(frac) + drift
                        let py = beadPos.y + (targetPoint.y - beadPos.y) * CGFloat(frac)
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: px - 1.4, y: py - 1.4, width: 2.8, height: 2.8)),
                            with: .color(Color(hex: 0xFFF2C8).opacity(0.32 + 0.18 * sin(Double(i) + phase.raw * 6.28)))
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
