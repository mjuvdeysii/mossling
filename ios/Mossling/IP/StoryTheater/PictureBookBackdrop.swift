import SwiftUI

/// Five Nordic cut-paper picture-book stage sets supporting Daylight 3D, Dark/Lamp 3D, and 2D Flat styles.
struct PictureBookBackdrop: View {
    let kind: LivingBackdropKind
    let accent: Color
    let dark: Bool
    let flat: Bool

    static func floorLineY(for kind: LivingBackdropKind, in height: CGFloat) -> CGFloat {
        switch kind {
        case .woodenDesk: return height * 0.75
        default: return height * 0.78
        }
    }

    var body: some View {
        ZStack {
            Canvas(rendersAsynchronously: false) { ctx, size in
                let w = size.width
                let h = size.height
                let floorY = Self.floorLineY(for: kind, in: h)

                drawWall(in: &ctx, w: w, h: h, floorY: floorY)
                drawCutPaperArch(in: &ctx, w: w, h: h, floorY: floorY)

                switch kind {
                case .playMat:
                    drawNurseryFloor(in: &ctx, w: w, h: h, floorY: floorY)
                    drawPlayMat(in: &ctx, w: w, h: h, floorY: floorY)
                case .cozyCorner:
                    drawWindow(in: &ctx, x: w * 0.06, y: h * 0.08, width: w * 0.19, height: h * 0.28)
                    drawNurseryFloor(in: &ctx, w: w, h: h, floorY: floorY)
                    drawCozyRug(in: &ctx, w: w, h: h, floorY: floorY)
                case .woodenDesk:
                    drawWindow(in: &ctx, x: w * 0.06, y: h * 0.08, width: w * 0.19, height: h * 0.28)
                    drawWoodenDesk(in: &ctx, w: w, h: h, deskY: floorY)
                case .windowSun:
                    drawWindow(in: &ctx, x: w * 0.08, y: h * 0.08, width: w * 0.24, height: h * 0.34)
                    drawNurseryFloor(in: &ctx, w: w, h: h, floorY: floorY)
                case .meadowPath:
                    drawMeadowHills(in: &ctx, w: w, h: h, floorY: floorY)
                }
            }

            if !flat {
                Grain(dark: dark, strength: dark ? 0.42 : 0.36)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawWall(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, floorY: CGFloat) {
        let rect = Path(CGRect(x: 0, y: 0, width: w, height: h))
        if dark {
            let top = Color(hex: 0x161D3A)
            let bot = Color(hex: 0x242A4C)
            if flat {
                ctx.fill(rect, with: .color(top))
            } else {
                ctx.fill(rect, with: .linearGradient(Gradient(colors: [top, bot]), startPoint: .zero, endPoint: CGPoint(x: 0, y: floorY)))
            }
        } else {
            let top = Color(hex: 0xFBF6EC)
            let bot = Color(hex: 0xF5ECDC)
            if flat {
                ctx.fill(rect, with: .color(top))
            } else {
                ctx.fill(rect, with: .linearGradient(Gradient(colors: [top, bot]), startPoint: .zero, endPoint: CGPoint(x: 0, y: floorY)))
            }
        }
    }

    private func drawCutPaperArch(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, floorY: CGFloat) {
        let archW = w * 0.56
        let archH = floorY * 0.78
        let archX = (w - archW) * 0.5
        let archY = floorY - archH + 10
        let archRect = CGRect(x: archX, y: archY, width: archW, height: archH)
        let arch = Path(roundedRect: archRect, cornerRadius: archW * 0.48)

        if !flat && !dark {
            ctx.fill(arch.offsetBy(dx: 0, dy: 2.5), with: .color(Color(hex: 0x8A6F4E).opacity(0.08)))
        }
        let tint: Color = dark
            ? accent.mix(with: Color(hex: 0x222B52), by: 0.72).opacity(0.68)
            : accent.mix(with: Color(hex: 0xFFFBF2), by: 0.76)
        ctx.fill(arch, with: .color(tint))

        if !flat {
            ctx.stroke(
                arch,
                with: .color(dark ? .white.opacity(0.06) : .white.opacity(0.75)),
                lineWidth: 1.0
            )
        }
    }

    private func drawWindow(in ctx: inout GraphicsContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        let win = CGRect(x: x, y: y, width: width, height: height)
        let pane = Path(roundedRect: win, cornerRadius: 6)
        let skyColor = dark ? Color(hex: 0x101633) : Color(hex: 0xD8EFFB)
        let frameColor = dark ? Color(hex: 0x524968) : Color(hex: 0xE6D3B3)

        ctx.fill(pane, with: .color(skyColor))

        if dark {
            let r: CGFloat = max(8, width * 0.16)
            let mx = win.minX + width * 0.62
            let my = win.minY + height * 0.22
            var moon = Path(ellipseIn: CGRect(x: mx, y: my, width: r, height: r))
            moon = moon.subtracting(Path(ellipseIn: CGRect(x: mx + r * 0.34, y: my - r * 0.24, width: r, height: r)))
            ctx.fill(moon, with: .color(Color(hex: 0xFFF1C4)))
            for (sx, sy) in [(0.24, 0.34), (0.36, 0.72), (0.76, 0.68)] as [(CGFloat, CGFloat)] {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: win.minX + width * sx, y: win.minY + height * sy, width: 2.2, height: 2.2)),
                    with: .color(.white.opacity(0.72))
                )
            }
        } else {
            let sunR = width * 0.16
            ctx.fill(
                Path(ellipseIn: CGRect(x: win.minX + width * 0.62, y: win.minY + height * 0.18, width: sunR * 2, height: sunR * 2)),
                with: .color(Color(hex: 0xFFE082).opacity(0.9))
            )
            // Soft cloud cut-out
            let cx = win.minX + width * 0.34
            let cy = win.minY + height * 0.56
            var cloud = Path()
            cloud.addEllipse(in: CGRect(x: cx - 10, y: cy, width: 22, height: 10))
            cloud.addEllipse(in: CGRect(x: cx - 4, y: cy - 5, width: 12, height: 12))
            ctx.fill(cloud, with: .color(.white.opacity(0.92)))
        }

        ctx.stroke(pane, with: .color(frameColor), lineWidth: flat ? 2.0 : 2.6)
        var cross = Path()
        cross.move(to: CGPoint(x: win.midX, y: win.minY))
        cross.addLine(to: CGPoint(x: win.midX, y: win.maxY))
        cross.move(to: CGPoint(x: win.minX, y: win.midY))
        cross.addLine(to: CGPoint(x: win.maxX, y: win.midY))
        ctx.stroke(cross, with: .color(frameColor), lineWidth: 1.6)
    }

    private func drawNurseryFloor(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, floorY: CGFloat) {
        let floorRect = CGRect(x: -8, y: floorY, width: w + 16, height: h - floorY + 8)
        let floorPath = Path(floorRect)
        if dark {
            let c1 = Color(hex: 0x1E2546)
            let c2 = Color(hex: 0x141A36)
            ctx.fill(floorPath, with: flat ? .color(c1) : .linearGradient(Gradient(colors: [c1, c2]), startPoint: CGPoint(x: 0, y: floorY), endPoint: CGPoint(x: 0, y: h)))
            ctx.fill(Path(CGRect(x: -8, y: floorY, width: w + 16, height: 1.5)), with: .color(Color(hex: 0x3D4978).opacity(0.65)))
        } else {
            let c1 = Color(hex: 0xF3DFBC)
            let c2 = Color(hex: 0xE7CB9E)
            ctx.fill(floorPath, with: flat ? .color(c1) : .linearGradient(Gradient(colors: [c1, c2]), startPoint: CGPoint(x: 0, y: floorY), endPoint: CGPoint(x: 0, y: h)))
            ctx.fill(Path(CGRect(x: -8, y: floorY, width: w + 16, height: 1.5)), with: .color(.white.opacity(0.65)))
        }
    }

    private func drawPlayMat(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, floorY: CGFloat) {
        let matRect = CGRect(x: w * 0.14, y: floorY - 5, width: w * 0.72, height: 18)
        let matPath = Path(roundedRect: matRect, cornerRadius: 9)
        let fill = dark ? Color(hex: 0x2B3460) : Color(hex: 0xEAE2F6)
        let edge = dark ? Color(hex: 0x3F4B82) : Color(hex: 0xC9BBE6)

        if !flat {
            ctx.fill(matPath.offsetBy(dx: 0, dy: 2.5), with: .color(.black.opacity(dark ? 0.30 : 0.10)))
        }
        ctx.fill(matPath, with: .color(fill))
        ctx.stroke(matPath, with: .color(edge), lineWidth: 1.2)

        let innerRect = matRect.insetBy(dx: 5, dy: 4)
        ctx.stroke(
            Path(roundedRect: innerRect, cornerRadius: 5),
            with: .color(edge.opacity(0.65)),
            style: StrokeStyle(lineWidth: 1.0, dash: [4, 4])
        )
    }

    private func drawCozyRug(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, floorY: CGFloat) {
        let rugRect = CGRect(x: w * 0.16, y: floorY - 4, width: w * 0.68, height: 16)
        let rugPath = Path(roundedRect: rugRect, cornerRadius: 8)
        let fill = dark ? Color(hex: 0x2C2B52) : Color(hex: 0xF7E4EA)
        let stitch = dark ? Color(hex: 0x4A4375) : Color(hex: 0xDFB6C4)
        if !flat {
            ctx.fill(rugPath.offsetBy(dx: 0, dy: 2), with: .color(.black.opacity(dark ? 0.28 : 0.08)))
        }
        ctx.fill(rugPath, with: .color(fill))
        ctx.stroke(
            Path(roundedRect: rugRect.insetBy(dx: 5, dy: 3.5), cornerRadius: 5),
            with: .color(stitch),
            style: StrokeStyle(lineWidth: 1.0, dash: [5, 4])
        )
    }

    private func drawWoodenDesk(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, deskY: CGFloat) {
        let topRect = CGRect(x: -10, y: deskY, width: w + 20, height: 14)
        let frontRect = CGRect(x: -10, y: deskY + 14, width: w + 20, height: h - deskY - 10)
        if dark {
            let topC1 = Color(hex: 0x9C7247)
            let topC2 = Color(hex: 0x875F38)
            let frontC1 = Color(hex: 0x734E2D)
            let frontC2 = Color(hex: 0x52351C)
            ctx.fill(Path(topRect), with: flat ? .color(topC1) : .linearGradient(Gradient(colors: [topC1, topC2]), startPoint: CGPoint(x: 0, y: deskY), endPoint: CGPoint(x: 0, y: deskY + 14)))
            ctx.fill(Path(frontRect), with: flat ? .color(frontC1) : .linearGradient(Gradient(colors: [frontC1, frontC2]), startPoint: CGPoint(x: 0, y: deskY + 14), endPoint: CGPoint(x: 0, y: h)))
            ctx.fill(Path(CGRect(x: -10, y: deskY + 13, width: w + 20, height: 1.4)), with: .color(Color(hex: 0xC89B65).opacity(0.65)))
        } else {
            let topC1 = Color(hex: 0xE6C290)
            let topC2 = Color(hex: 0xD6AC76)
            let frontC1 = Color(hex: 0xC5955D)
            let frontC2 = Color(hex: 0xAA7842)
            ctx.fill(Path(topRect), with: flat ? .color(topC1) : .linearGradient(Gradient(colors: [topC1, topC2]), startPoint: CGPoint(x: 0, y: deskY), endPoint: CGPoint(x: 0, y: deskY + 14)))
            ctx.fill(Path(frontRect), with: flat ? .color(frontC1) : .linearGradient(Gradient(colors: [frontC1, frontC2]), startPoint: CGPoint(x: 0, y: deskY + 14), endPoint: CGPoint(x: 0, y: h)))
            ctx.fill(Path(CGRect(x: -10, y: deskY + 13, width: w + 20, height: 1.4)), with: .color(Color(hex: 0xF5D9AD).opacity(0.8)))
        }

        // Gentle wood grain strokes
        let grainColor = dark ? Color(hex: 0x452B16).opacity(0.50) : Color(hex: 0x8F6132).opacity(0.24)
        for (yf, x0, x1) in [(0.32, 0.08, 0.42), (0.62, 0.34, 0.88)] as [(CGFloat, CGFloat, CGFloat)] {
            var g = Path()
            let gy = deskY + 14 + max(6, (h - deskY - 14) * yf)
            g.move(to: CGPoint(x: w * x0, y: gy))
            g.addQuadCurve(to: CGPoint(x: w * x1, y: gy + 1.5), control: CGPoint(x: w * (x0 + x1) * 0.5, y: gy - 2.5))
            ctx.stroke(g, with: .color(grainColor), lineWidth: 1.0)
        }
    }

    private func drawMeadowHills(in ctx: inout GraphicsContext, w: CGFloat, h: CGFloat, floorY: CGFloat) {
        var back = Path()
        back.move(to: CGPoint(x: 0, y: floorY - 8))
        back.addCurve(to: CGPoint(x: w, y: floorY - 12), control1: CGPoint(x: w * 0.3, y: floorY - 30), control2: CGPoint(x: w * 0.7, y: floorY + 4))
        back.addLine(to: CGPoint(x: w, y: h))
        back.addLine(to: CGPoint(x: 0, y: h))
        back.closeSubpath()
        ctx.fill(back, with: .color(dark ? Color(hex: 0x263A38) : Color(hex: 0xCBE2BE)))

        var front = Path()
        front.move(to: CGPoint(x: 0, y: floorY + 4))
        front.addCurve(to: CGPoint(x: w, y: floorY), control1: CGPoint(x: w * 0.38, y: floorY - 8), control2: CGPoint(x: w * 0.68, y: floorY + 10))
        front.addLine(to: CGPoint(x: w, y: h))
        front.addLine(to: CGPoint(x: 0, y: h))
        front.closeSubpath()
        ctx.fill(front, with: .color(dark ? Color(hex: 0x1D2E32) : Color(hex: 0xB4D4A4)))
    }
}
