import SwiftUI

/// Bespoke handcrafted Montessori botanical illustrations for all 60 whole foods (`FoodGlyphView`)
/// and all studio instruments (`ToolArtBadge`). Checks `IconAssetResolver` for custom bundled raster slices first,
/// then renders dual-style (3D matte-vinyl / 2D cut-paper) vector art with zero system Emoji.
struct FoodGlyphView: View {
    let food: FoodItem
    var size: CGFloat = 32
    var flat: Bool = (ArtStyle.current == .flat)

    var body: some View {
        let spec = IconAssetResolver.shared.foodSpec(for: food.id)
        if let spec, let custom = IconAssetResolver.shared.bundledImage(asset3D: spec.asset3D, asset2D: spec.asset2D, maxPixel: Int(size * 3)) {
            Image(uiImage: custom)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            let primary = IconAssetResolver.color(hex: spec?.primaryHex ?? "5B9A4B", fallback: food.category.color)
            let secondary = IconAssetResolver.color(hex: spec?.secondaryHex ?? "A9E0C0", fallback: food.category.color.opacity(0.6))
            let detail = IconAssetResolver.color(hex: spec?.detailHex ?? "3D5434", fallback: Palette.mossDeep)
            let kind = spec?.glyphKind ?? "seedDish"
            Canvas { ctx, sz in
                let s = min(sz.width, sz.height) / 100
                ctx.translateBy(x: (sz.width - 100 * s) / 2, y: (sz.height - 100 * s) / 2)
                ctx.scaleBy(x: s, y: s)
                drawFood(&ctx, kind: kind, p: primary, s: secondary, d: detail)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        }
    }

    private func fill(_ ctx: inout GraphicsContext, _ path: Path, _ c: Color, highlight: Color? = nil) {
        if flat {
            ctx.fill(path, with: .color(c))
            ctx.stroke(path, with: .color(Palette.ink.opacity(0.28)), style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
        } else {
            let b = path.boundingRect
            let top = highlight ?? c.mix(with: .white, by: 0.24)
            let bot = c.mix(with: .black, by: 0.14)
            ctx.fill(
                path,
                with: .linearGradient(
                    Gradient(stops: [.init(color: top, location: 0), .init(color: c, location: 0.5), .init(color: bot, location: 1)]),
                    startPoint: CGPoint(x: b.minX + b.width * 0.2, y: b.minY),
                    endPoint: CGPoint(x: b.maxX, y: b.maxY)
                )
            )
        }
    }

    private func leaf(_ ctx: inout GraphicsContext, at pt: CGPoint, angle: Double, scale: CGFloat, color: Color) {
        var c = ctx
        c.translateBy(x: pt.x, y: pt.y)
        c.rotate(by: .degrees(angle))
        c.scaleBy(x: scale, y: scale)
        var p = Path()
        p.move(to: .zero)
        p.addQuadCurve(to: CGPoint(x: 16, y: -4), control: CGPoint(x: 8, y: -11))
        p.addQuadCurve(to: .zero, control: CGPoint(x: 8, y: 4))
        p.closeSubpath()
        c.fill(p, with: .color(color))
    }

    private func stem(_ ctx: inout GraphicsContext, from: CGPoint, to: CGPoint, ctrl: CGPoint, color: Color, width: CGFloat = 4.5) {
        var p = Path()
        p.move(to: from)
        p.addQuadCurve(to: to, control: ctrl)
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private func drawFood(_ ctx: inout GraphicsContext, kind: String, p: Color, s: Color, d: Color) {
        // Subtle soft ground shadow under every ingredient
        if !flat {
            ctx.fill(Path(ellipseIn: CGRect(x: 20, y: 82, width: 60, height: 10)), with: .color(Palette.ink.opacity(0.08)))
        }
        switch kind {
        case "pumpkin":
            stem(&ctx, from: CGPoint(x: 50, y: 27), to: CGPoint(x: 56, y: 14), ctrl: CGPoint(x: 51, y: 18), color: d, width: 6)
            for dx in [-18.0, 18.0] {
                fill(&ctx, Path(ellipseIn: CGRect(x: 34 + dx, y: 28, width: 32, height: 54)), p.mix(with: .black, by: 0.08))
            }
            fill(&ctx, Path(ellipseIn: CGRect(x: 27, y: 27, width: 46, height: 56)), p, highlight: s)
            ctx.stroke(Path(ellipseIn: CGRect(x: 38, y: 28, width: 24, height: 54)), with: .color(s.opacity(0.45)), lineWidth: 1.5)

        case "sweetpotato":
            var body = Path()
            body.move(to: CGPoint(x: 15, y: 62))
            body.addCurve(to: CGPoint(x: 78, y: 34), control1: CGPoint(x: 24, y: 26), control2: CGPoint(x: 56, y: 20))
            body.addCurve(to: CGPoint(x: 15, y: 62), control1: CGPoint(x: 76, y: 66), control2: CGPoint(x: 34, y: 80))
            fill(&ctx, body, p, highlight: d)
            // Golden-flesh diagonal cut face at the right end
            var cut = Path(ellipseIn: CGRect(x: 56, y: 31, width: 25, height: 22))
            var c = ctx; c.translateBy(x: 68, y: 42); c.rotate(by: .degrees(32)); c.translateBy(x: -68, y: -42)
            c.fill(cut, with: .color(s))
            c.stroke(cut, with: .color(p.mix(with: .black, by: 0.15)), lineWidth: 1.5)

        case "carrot":
            stem(&ctx, from: CGPoint(x: 68, y: 31), to: CGPoint(x: 82, y: 14), ctrl: CGPoint(x: 74, y: 20), color: d, width: 4)
            leaf(&ctx, at: CGPoint(x: 68, y: 31), angle: -55, scale: 1.0, color: d)
            leaf(&ctx, at: CGPoint(x: 69, y: 31), angle: -25, scale: 0.9, color: d.mix(with: .white, by: 0.2))
            var body = Path()
            body.move(to: CGPoint(x: 62, y: 24))
            body.addCurve(to: CGPoint(x: 78, y: 40), control1: CGPoint(x: 76, y: 24), control2: CGPoint(x: 80, y: 34))
            body.addLine(to: CGPoint(x: 22, y: 84))
            body.addQuadCurve(to: CGPoint(x: 17, y: 78), control: CGPoint(x: 16, y: 85))
            body.closeSubpath()
            fill(&ctx, body, p, highlight: s)

        case "broccoli":
            var trunk = Path(roundedRect: CGRect(x: 42, y: 48, width: 16, height: 36), cornerRadius: 6)
            fill(&ctx, trunk, s)
            for (cx, cy, r) in [(32.0, 40.0, 17.0), (68.0, 42.0, 16.0), (50.0, 28.0, 20.0), (42.0, 42.0, 15.0), (58.0, 42.0, 15.0)] {
                fill(&ctx, Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), p, highlight: d)
            }

        case "avocado":
            var pear = Path()
            pear.move(to: CGPoint(x: 50, y: 14))
            pear.addCurve(to: CGPoint(x: 78, y: 62), control1: CGPoint(x: 70, y: 16), control2: CGPoint(x: 80, y: 42))
            pear.addCurve(to: CGPoint(x: 22, y: 62), control1: CGPoint(x: 76, y: 92), control2: CGPoint(x: 24, y: 92))
            pear.addCurve(to: CGPoint(x: 50, y: 14), control1: CGPoint(x: 20, y: 42), control2: CGPoint(x: 30, y: 16))
            fill(&ctx, pear, p)
            var inner = Path()
            inner.move(to: CGPoint(x: 50, y: 21))
            inner.addCurve(to: CGPoint(x: 71, y: 61), control1: CGPoint(x: 65, y: 22), control2: CGPoint(x: 73, y: 44))
            inner.addCurve(to: CGPoint(x: 29, y: 61), control1: CGPoint(x: 69, y: 84), control2: CGPoint(x: 31, y: 84))
            inner.addCurve(to: CGPoint(x: 50, y: 21), control1: CGPoint(x: 27, y: 44), control2: CGPoint(x: 35, y: 22))
            ctx.fill(inner, with: .color(s))
            fill(&ctx, Path(ellipseIn: CGRect(x: 38, y: 50, width: 24, height: 24)), d)

        case "leafy":
            stem(&ctx, from: CGPoint(x: 38, y: 84), to: CGPoint(x: 47, y: 52), ctrl: CGPoint(x: 42, y: 68), color: d, width: 3.5)
            stem(&ctx, from: CGPoint(x: 62, y: 84), to: CGPoint(x: 53, y: 52), ctrl: CGPoint(x: 58, y: 68), color: d, width: 3.5)
            for (cx, cy, rot, rx, ry) in [(35.0, 44.0, -28.0, 15.0, 21.0), (65.0, 44.0, 28.0, 15.0, 21.0), (50.0, 34.0, 0.0, 16.0, 22.0)] {
                var c = ctx
                c.translateBy(x: cx, y: cy)
                c.rotate(by: .degrees(rot))
                let lf = Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
                fill(&c, lf, cx == 50 ? s : p)
                var vein = Path(); vein.move(to: CGPoint(x: 0, y: ry * 0.7)); vein.addLine(to: CGPoint(x: 0, y: -ry * 0.6))
                c.stroke(vein, with: .color(d.opacity(0.45)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }

        case "tomato":
            fill(&ctx, Path(ellipseIn: CGRect(x: 18, y: 26, width: 64, height: 56)), p, highlight: s)
            leaf(&ctx, at: CGPoint(x: 50, y: 26), angle: -155, scale: 1.0, color: d)
            leaf(&ctx, at: CGPoint(x: 50, y: 26), angle: -25, scale: 1.0, color: d)
            stem(&ctx, from: CGPoint(x: 50, y: 26), to: CGPoint(x: 52, y: 15), ctrl: CGPoint(x: 50, y: 20), color: d, width: 4)

        case "peaPod":
            var pod = Path()
            pod.move(to: CGPoint(x: 16, y: 66))
            pod.addCurve(to: CGPoint(x: 84, y: 28), control1: CGPoint(x: 34, y: 26), control2: CGPoint(x: 68, y: 20))
            pod.addCurve(to: CGPoint(x: 16, y: 66), control1: CGPoint(x: 78, y: 68), control2: CGPoint(x: 36, y: 80))
            fill(&ctx, pod, p)
            for (cx, cy) in [(34.0, 56.0), (51.0, 48.0), (67.0, 39.0)] {
                fill(&ctx, Path(ellipseIn: CGRect(x: cx - 7.5, y: cy - 7.5, width: 15, height: 15)), s)
            }

        case "potato":
            var tuber = Path()
            tuber.move(to: CGPoint(x: 20, y: 58))
            tuber.addCurve(to: CGPoint(x: 58, y: 24), control1: CGPoint(x: 18, y: 30), control2: CGPoint(x: 38, y: 20))
            tuber.addCurve(to: CGPoint(x: 82, y: 56), control1: CGPoint(x: 78, y: 26), control2: CGPoint(x: 86, y: 42))
            tuber.addCurve(to: CGPoint(x: 20, y: 58), control1: CGPoint(x: 74, y: 84), control2: CGPoint(x: 24, y: 82))
            fill(&ctx, tuber, p, highlight: s)
            for (dx, dy) in [(42.0, 46.0), (62.0, 52.0), (50.0, 62.0)] {
                ctx.fill(Path(ellipseIn: CGRect(x: dx, y: dy, width: 3.5, height: 2.5)), with: .color(d.opacity(0.6)))
            }

        case "corn":
            fill(&ctx, Path(roundedRect: CGRect(x: 36, y: 16, width: 28, height: 64), cornerRadius: 14), p, highlight: s)
            for row in stride(from: 24.0, through: 56.0, by: 9.0) {
                for col in [42.0, 50.0, 58.0] {
                    ctx.fill(Path(ellipseIn: CGRect(x: col - 2.5, y: row - 2.5, width: 5, height: 5)), with: .color(s.opacity(0.65)))
                }
            }
            var hL = Path(); hL.move(to: CGPoint(x: 36, y: 44)); hL.addQuadCurve(to: CGPoint(x: 50, y: 84), control: CGPoint(x: 24, y: 76)); hL.addLine(to: CGPoint(x: 42, y: 84)); hL.closeSubpath()
            var hR = Path(); hR.move(to: CGPoint(x: 64, y: 44)); hR.addQuadCurve(to: CGPoint(x: 50, y: 84), control: CGPoint(x: 76, y: 76)); hR.addLine(to: CGPoint(x: 58, y: 84)); hR.closeSubpath()
            fill(&ctx, hL, d); fill(&ctx, hR, d)

        case "cucumber":
            var c = ctx
            c.translateBy(x: 50, y: 50); c.rotate(by: .degrees(-35)); c.translateBy(x: -50, y: -50)
            fill(&c, Path(roundedRect: CGRect(x: 16, y: 38, width: 68, height: 24), cornerRadius: 12), p)
            fill(&ctx, Path(ellipseIn: CGRect(x: 54, y: 54, width: 26, height: 26)), p)
            ctx.fill(Path(ellipseIn: CGRect(x: 58, y: 58, width: 18, height: 18)), with: .color(s))

        case "mushroom":
            fill(&ctx, Path(roundedRect: CGRect(x: 41, y: 46, width: 18, height: 34), cornerRadius: 8), s)
            var cap = Path()
            cap.move(to: CGPoint(x: 18, y: 52))
            cap.addCurve(to: CGPoint(x: 82, y: 52), control1: CGPoint(x: 20, y: 14), control2: CGPoint(x: 80, y: 14))
            cap.closeSubpath()
            fill(&ctx, cap, p)

        case "banana":
            var b = Path()
            b.move(to: CGPoint(x: 74, y: 20))
            b.addCurve(to: CGPoint(x: 20, y: 74), control1: CGPoint(x: 74, y: 60), control2: CGPoint(x: 50, y: 84))
            b.addCurve(to: CGPoint(x: 74, y: 20), control1: CGPoint(x: 34, y: 70), control2: CGPoint(x: 58, y: 48))
            var b2 = Path()
            b2.move(to: CGPoint(x: 76, y: 22))
            b2.addCurve(to: CGPoint(x: 20, y: 74), control1: CGPoint(x: 84, y: 66), control2: CGPoint(x: 48, y: 88))
            b2.addCurve(to: CGPoint(x: 76, y: 22), control1: CGPoint(x: 42, y: 70), control2: CGPoint(x: 64, y: 46))
            fill(&ctx, b2, p, highlight: s)
            ctx.fill(Path(roundedRect: CGRect(x: 73, y: 16, width: 6, height: 8), cornerRadius: 2), with: .color(d))

        case "apple":
            var a = Path()
            a.move(to: CGPoint(x: 50, y: 31))
            a.addCurve(to: CGPoint(x: 82, y: 54), control1: CGPoint(x: 68, y: 22), control2: CGPoint(x: 84, y: 34))
            a.addCurve(to: CGPoint(x: 50, y: 82), control1: CGPoint(x: 80, y: 76), control2: CGPoint(x: 62, y: 85))
            a.addCurve(to: CGPoint(x: 18, y: 54), control1: CGPoint(x: 38, y: 85), control2: CGPoint(x: 20, y: 76))
            a.addCurve(to: CGPoint(x: 50, y: 31), control1: CGPoint(x: 16, y: 34), control2: CGPoint(x: 32, y: 22))
            fill(&ctx, a, p, highlight: s)
            stem(&ctx, from: CGPoint(x: 50, y: 31), to: CGPoint(x: 52, y: 16), ctrl: CGPoint(x: 50, y: 22), color: Palette.ink.opacity(0.65), width: 3.5)
            leaf(&ctx, at: CGPoint(x: 51, y: 22), angle: -28, scale: 1.0, color: d)

        case "pear":
            var pr = Path()
            pr.move(to: CGPoint(x: 50, y: 22))
            pr.addCurve(to: CGPoint(x: 74, y: 64), control1: CGPoint(x: 64, y: 22), control2: CGPoint(x: 74, y: 44))
            pr.addCurve(to: CGPoint(x: 26, y: 64), control1: CGPoint(x: 74, y: 88), control2: CGPoint(x: 26, y: 88))
            pr.addCurve(to: CGPoint(x: 50, y: 22), control1: CGPoint(x: 26, y: 44), control2: CGPoint(x: 36, y: 22))
            fill(&ctx, pr, p, highlight: s)
            stem(&ctx, from: CGPoint(x: 50, y: 22), to: CGPoint(x: 53, y: 12), ctrl: CGPoint(x: 50, y: 16), color: d, width: 3.5)

        case "berries":
            for (cx, cy, r) in [(36.0, 56.0, 17.0), (64.0, 58.0, 16.0), (50.0, 38.0, 18.0)] {
                fill(&ctx, Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), p, highlight: s)
                ctx.fill(Path(ellipseIn: CGRect(x: cx - 3, y: cy - r + 2, width: 6, height: 3)), with: .color(d))
            }

        case "strawberry":
            var st = Path()
            st.move(to: CGPoint(x: 50, y: 84))
            st.addCurve(to: CGPoint(x: 22, y: 38), control1: CGPoint(x: 32, y: 78), control2: CGPoint(x: 18, y: 54))
            st.addCurve(to: CGPoint(x: 50, y: 28), control1: CGPoint(x: 26, y: 28), control2: CGPoint(x: 40, y: 28))
            st.addCurve(to: CGPoint(x: 78, y: 38), control1: CGPoint(x: 60, y: 28), control2: CGPoint(x: 74, y: 28))
            st.addCurve(to: CGPoint(x: 50, y: 84), control1: CGPoint(x: 82, y: 54), control2: CGPoint(x: 68, y: 78))
            fill(&ctx, st, p, highlight: s)
            leaf(&ctx, at: CGPoint(x: 50, y: 28), angle: -150, scale: 1.05, color: d)
            leaf(&ctx, at: CGPoint(x: 50, y: 28), angle: -30, scale: 1.05, color: d)
            for (sx, sy) in [(42.0, 46.0), (58.0, 46.0), (50.0, 58.0), (43.0, 66.0), (56.0, 66.0)] {
                ctx.fill(Path(ellipseIn: CGRect(x: sx - 1.5, y: sy - 2, width: 3, height: 4)), with: .color(Color(hex: 0xFFE89E)))
            }

        case "mango":
            var mg = Path()
            mg.move(to: CGPoint(x: 38, y: 20))
            mg.addCurve(to: CGPoint(x: 78, y: 52), control1: CGPoint(x: 66, y: 16), control2: CGPoint(x: 82, y: 32))
            mg.addCurve(to: CGPoint(x: 26, y: 78), control1: CGPoint(x: 74, y: 78), control2: CGPoint(x: 46, y: 88))
            mg.addCurve(to: CGPoint(x: 38, y: 20), control1: CGPoint(x: 14, y: 66), control2: CGPoint(x: 20, y: 26))
            fill(&ctx, mg, p, highlight: s)
            leaf(&ctx, at: CGPoint(x: 38, y: 20), angle: -140, scale: 0.9, color: d)

        case "peach":
            fill(&ctx, Path(ellipseIn: CGRect(x: 20, y: 26, width: 60, height: 56)), p, highlight: s)
            var crease = Path(); crease.move(to: CGPoint(x: 50, y: 27)); crease.addQuadCurve(to: CGPoint(x: 50, y: 72), control: CGPoint(x: 57, y: 48))
            ctx.stroke(crease, with: .color(p.mix(with: .black, by: 0.2).opacity(0.4)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            leaf(&ctx, at: CGPoint(x: 50, y: 26), angle: -30, scale: 1.0, color: d)

        case "kiwi":
            fill(&ctx, Path(ellipseIn: CGRect(x: 16, y: 20, width: 68, height: 60)), p)
            ctx.fill(Path(ellipseIn: CGRect(x: 21, y: 25, width: 58, height: 50)), with: .color(s))
            ctx.fill(Path(ellipseIn: CGRect(x: 41, y: 42, width: 18, height: 16)), with: .color(d))
            for k in 0..<8 {
                let a = Double(k) * .pi / 4
                ctx.fill(Path(ellipseIn: CGRect(x: 50 + cos(a) * 14 - 1.5, y: 50 + sin(a) * 12 - 1.5, width: 3, height: 3)), with: .color(Palette.ink.opacity(0.75)))
            }

        case "watermelon":
            var rind = Path()
            rind.move(to: CGPoint(x: 16, y: 46))
            rind.addCurve(to: CGPoint(x: 84, y: 46), control1: CGPoint(x: 28, y: 90), control2: CGPoint(x: 72, y: 90))
            rind.closeSubpath()
            fill(&ctx, rind, d)
            var flesh = Path()
            flesh.move(to: CGPoint(x: 22, y: 46))
            flesh.addCurve(to: CGPoint(x: 78, y: 46), control1: CGPoint(x: 32, y: 80), control2: CGPoint(x: 68, y: 80))
            flesh.closeSubpath()
            ctx.fill(flesh, with: .color(p))
            for (sx, sy) in [(40.0, 56.0), (50.0, 62.0), (60.0, 56.0)] {
                ctx.fill(Path(ellipseIn: CGRect(x: sx - 1.8, y: sy - 2.4, width: 3.6, height: 4.8)), with: .color(Palette.ink.opacity(0.75)))
            }

        case "citrus":
            fill(&ctx, Path(ellipseIn: CGRect(x: 18, y: 22, width: 64, height: 60)), p, highlight: s)
            leaf(&ctx, at: CGPoint(x: 52, y: 22), angle: -25, scale: 1.0, color: d)

        case "grapeCluster":
            stem(&ctx, from: CGPoint(x: 50, y: 26), to: CGPoint(x: 54, y: 12), ctrl: CGPoint(x: 50, y: 18), color: d, width: 4)
            for (cx, cy) in [(36.0, 38.0), (50.0, 36.0), (64.0, 38.0), (42.0, 52.0), (58.0, 52.0), (50.0, 66.0)] {
                fill(&ctx, Path(ellipseIn: CGRect(x: cx - 10, y: cy - 10, width: 20, height: 20)), p, highlight: s)
            }

        case "melonSlice":
            var outer = Path()
            outer.move(to: CGPoint(x: 18, y: 54))
            outer.addCurve(to: CGPoint(x: 82, y: 54), control1: CGPoint(x: 30, y: 88), control2: CGPoint(x: 70, y: 88))
            outer.closeSubpath()
            fill(&ctx, outer, d)
            var meat = Path()
            meat.move(to: CGPoint(x: 24, y: 54))
            meat.addCurve(to: CGPoint(x: 76, y: 54), control1: CGPoint(x: 34, y: 78), control2: CGPoint(x: 66, y: 78))
            meat.closeSubpath()
            ctx.fill(meat, with: .color(p))

        case "porridgeBowl", "riceBowl":
            if kind == "riceBowl" {
                fill(&ctx, Path(ellipseIn: CGRect(x: 22, y: 26, width: 56, height: 34)), p, highlight: s)
            }
            var bowl = Path()
            bowl.move(to: CGPoint(x: 16, y: 44))
            bowl.addLine(to: CGPoint(x: 84, y: 44))
            bowl.addCurve(to: CGPoint(x: 28, y: 78), control1: CGPoint(x: 82, y: 72), control2: CGPoint(x: 66, y: 80))
            bowl.addCurve(to: CGPoint(x: 16, y: 44), control1: CGPoint(x: 20, y: 70), control2: CGPoint(x: 16, y: 58))
            fill(&ctx, bowl, d)
            if kind == "porridgeBowl" {
                ctx.fill(Path(ellipseIn: CGRect(x: 20, y: 34, width: 60, height: 18)), with: .color(s))
                ctx.fill(Path(ellipseIn: CGRect(x: 24, y: 37, width: 52, height: 12)), with: .color(p))
            }

        case "noodleBowl":
            stem(&ctx, from: CGPoint(x: 56, y: 42), to: CGPoint(x: 84, y: 18), ctrl: CGPoint(x: 70, y: 30), color: d, width: 3.5)
            stem(&ctx, from: CGPoint(x: 62, y: 42), to: CGPoint(x: 88, y: 24), ctrl: CGPoint(x: 75, y: 33), color: d, width: 3.5)
            ctx.fill(Path(ellipseIn: CGRect(x: 22, y: 34, width: 56, height: 22)), with: .color(p))
            var bowl = Path()
            bowl.move(to: CGPoint(x: 16, y: 46))
            bowl.addLine(to: CGPoint(x: 84, y: 46))
            bowl.addCurve(to: CGPoint(x: 26, y: 78), control1: CGPoint(x: 82, y: 74), control2: CGPoint(x: 66, y: 80))
            bowl.closeSubpath()
            fill(&ctx, bowl, s)

        case "wheatSheaf":
            stem(&ctx, from: CGPoint(x: 34, y: 82), to: CGPoint(x: 68, y: 18), ctrl: CGPoint(x: 48, y: 50), color: d, width: 3.2)
            for t in [0.35, 0.55, 0.75] {
                let cx = 34 + (68 - 34) * t, cy = 82 + (18 - 82) * t
                fill(&ctx, Path(ellipseIn: CGRect(x: cx - 12, y: cy - 6, width: 12, height: 7)), p)
                fill(&ctx, Path(ellipseIn: CGRect(x: cx + 1, y: cy - 2, width: 12, height: 7)), s)
            }

        case "toast":
            var crust = Path(roundedRect: CGRect(x: 22, y: 24, width: 56, height: 54), cornerRadius: 12)
            fill(&ctx, crust, p)
            ctx.fill(Path(roundedRect: CGRect(x: 28, y: 30, width: 44, height: 42), cornerRadius: 8), with: .color(s))

        case "pastaSpiral":
            var sp = Path()
            sp.move(to: CGPoint(x: 24, y: 66))
            sp.addCurve(to: CGPoint(x: 76, y: 32), control1: CGPoint(x: 36, y: 28), control2: CGPoint(x: 62, y: 70))
            ctx.stroke(sp, with: .color(p), style: StrokeStyle(lineWidth: 16, lineCap: .round))
            ctx.stroke(sp, with: .color(s), style: StrokeStyle(lineWidth: 7, lineCap: .round))

        case "seedDish":
            fill(&ctx, Path(ellipseIn: CGRect(x: 16, y: 24, width: 68, height: 54)), d.opacity(0.28))
            for (dx, dy, col) in [(38.0, 42.0, p), (54.0, 40.0, s), (48.0, 56.0, p), (34.0, 56.0, s), (62.0, 54.0, d), (46.0, 44.0, s)] {
                fill(&ctx, Path(ellipseIn: CGRect(x: dx - 7, y: dy - 5.5, width: 14, height: 11)), col)
            }

        case "rootSlice":
            fill(&ctx, Path(ellipseIn: CGRect(x: 20, y: 22, width: 60, height: 56)), p)
            ctx.fill(Path(ellipseIn: CGRect(x: 25, y: 27, width: 50, height: 46)), with: .color(s))
            ctx.stroke(Path(ellipseIn: CGRect(x: 34, y: 35, width: 32, height: 30)), with: .color(d.opacity(0.28)), lineWidth: 1.5)

        case "eggYolk":
            var white = Path()
            white.move(to: CGPoint(x: 20, y: 54))
            white.addCurve(to: CGPoint(x: 74, y: 32), control1: CGPoint(x: 18, y: 24), control2: CGPoint(x: 56, y: 18))
            white.addCurve(to: CGPoint(x: 20, y: 54), control1: CGPoint(x: 90, y: 54), control2: CGPoint(x: 42, y: 88))
            fill(&ctx, white, s)
            fill(&ctx, Path(ellipseIn: CGRect(x: 36, y: 36, width: 28, height: 28)), p, highlight: d)

        case "wholeEgg":
            var egg = Path()
            egg.move(to: CGPoint(x: 50, y: 16))
            egg.addCurve(to: CGPoint(x: 76, y: 58), control1: CGPoint(x: 68, y: 16), control2: CGPoint(x: 76, y: 40))
            egg.addCurve(to: CGPoint(x: 24, y: 58), control1: CGPoint(x: 76, y: 84), control2: CGPoint(x: 24, y: 84))
            egg.addCurve(to: CGPoint(x: 50, y: 16), control1: CGPoint(x: 24, y: 40), control2: CGPoint(x: 32, y: 16))
            fill(&ctx, egg, p, highlight: s)

        case "fishFillet":
            var f = Path()
            f.move(to: CGPoint(x: 18, y: 56))
            f.addCurve(to: CGPoint(x: 82, y: 40), control1: CGPoint(x: 30, y: 26), control2: CGPoint(x: 70, y: 22))
            f.addCurve(to: CGPoint(x: 18, y: 56), control1: CGPoint(x: 86, y: 66), control2: CGPoint(x: 30, y: 78))
            fill(&ctx, f, p)
            for x in [36.0, 50.0, 64.0] {
                var stripe = Path(); stripe.move(to: CGPoint(x: x, y: 36)); stripe.addLine(to: CGPoint(x: x - 6, y: 62))
                ctx.stroke(stripe, with: .color(s), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }

        case "fish":
            var body = Path()
            body.move(to: CGPoint(x: 18, y: 50))
            body.addQuadCurve(to: CGPoint(x: 72, y: 50), control: CGPoint(x: 45, y: 22))
            body.addQuadCurve(to: CGPoint(x: 18, y: 50), control: CGPoint(x: 45, y: 78))
            var tail = Path()
            tail.move(to: CGPoint(x: 68, y: 50)); tail.addLine(to: CGPoint(x: 86, y: 36)); tail.addLine(to: CGPoint(x: 86, y: 64)); tail.closeSubpath()
            fill(&ctx, tail, d)
            fill(&ctx, body, p, highlight: s)
            ctx.fill(Path(ellipseIn: CGRect(x: 29, y: 45, width: 5, height: 5)), with: .color(Palette.ink))

        case "meatCut":
            var cut = Path()
            cut.move(to: CGPoint(x: 20, y: 52))
            cut.addCurve(to: CGPoint(x: 78, y: 34), control1: CGPoint(x: 22, y: 24), control2: CGPoint(x: 64, y: 22))
            cut.addCurve(to: CGPoint(x: 20, y: 52), control1: CGPoint(x: 88, y: 64), control2: CGPoint(x: 34, y: 84))
            fill(&ctx, cut, p)
            ctx.fill(Path(ellipseIn: CGRect(x: 38, y: 40, width: 22, height: 10)), with: .color(s.opacity(0.65)))

        case "poultry":
            fill(&ctx, Path(roundedRect: CGRect(x: 20, y: 56, width: 30, height: 12), cornerRadius: 6), s)
            fill(&ctx, Path(ellipseIn: CGRect(x: 34, y: 24, width: 46, height: 42)), p)

        case "shrimp":
            var arc = Path()
            arc.addArc(center: CGPoint(x: 52, y: 52), radius: 22, startAngle: .degrees(-130), endAngle: .degrees(100), clockwise: false)
            ctx.stroke(arc, with: .color(p), style: StrokeStyle(lineWidth: 20, lineCap: .round))
            ctx.stroke(arc, with: .color(s.opacity(0.65)), style: StrokeStyle(lineWidth: 7, lineCap: .round))

        case "tofuCube":
            var cube = Path(roundedRect: CGRect(x: 24, y: 32, width: 52, height: 46), cornerRadius: 8)
            fill(&ctx, cube, p, highlight: s)
            leaf(&ctx, at: CGPoint(x: 50, y: 32), angle: -30, scale: 0.75, color: d)

        case "spoonPowder":
            stem(&ctx, from: CGPoint(x: 48, y: 54), to: CGPoint(x: 82, y: 22), ctrl: CGPoint(x: 65, y: 38), color: s, width: 6)
            fill(&ctx, Path(ellipseIn: CGRect(x: 18, y: 46, width: 38, height: 28)), s)
            fill(&ctx, Path(ellipseIn: CGRect(x: 23, y: 42, width: 28, height: 20)), p)

        case "yogurtJar":
            fill(&ctx, Path(roundedRect: CGRect(x: 30, y: 30, width: 40, height: 50), cornerRadius: 12), p, highlight: s)
            fill(&ctx, Path(roundedRect: CGRect(x: 27, y: 22, width: 46, height: 12), cornerRadius: 5), d)

        case "cheeseWedge":
            var ch = Path()
            ch.move(to: CGPoint(x: 18, y: 66))
            ch.addLine(to: CGPoint(x: 82, y: 66))
            ch.addLine(to: CGPoint(x: 82, y: 40))
            ch.addLine(to: CGPoint(x: 32, y: 28))
            ch.closeSubpath()
            fill(&ctx, ch, p, highlight: s)
            ctx.fill(Path(ellipseIn: CGRect(x: 42, y: 46, width: 9, height: 9)), with: .color(d.opacity(0.45)))
            ctx.fill(Path(ellipseIn: CGRect(x: 60, y: 52, width: 7, height: 7)), with: .color(d.opacity(0.45)))

        case "peanut":
            fill(&ctx, Path(ellipseIn: CGRect(x: 26, y: 22, width: 28, height: 30)), p, highlight: s)
            fill(&ctx, Path(ellipseIn: CGRect(x: 42, y: 46, width: 32, height: 32)), p, highlight: s)

        case "walnut":
            fill(&ctx, Path(ellipseIn: CGRect(x: 22, y: 24, width: 56, height: 52)), p, highlight: s)
            var mid = Path(); mid.move(to: CGPoint(x: 50, y: 26)); mid.addLine(to: CGPoint(x: 50, y: 74))
            ctx.stroke(mid, with: .color(d), lineWidth: 3)

        case "almond":
            var al = Path()
            al.move(to: CGPoint(x: 50, y: 18))
            al.addCurve(to: CGPoint(x: 74, y: 56), control1: CGPoint(x: 70, y: 28), control2: CGPoint(x: 76, y: 42))
            al.addCurve(to: CGPoint(x: 26, y: 56), control1: CGPoint(x: 70, y: 84), control2: CGPoint(x: 30, y: 84))
            al.addCurve(to: CGPoint(x: 50, y: 18), control1: CGPoint(x: 24, y: 42), control2: CGPoint(x: 30, y: 28))
            fill(&ctx, al, p, highlight: s)

        case "butterPat":
            fill(&ctx, Path(roundedRect: CGRect(x: 18, y: 48, width: 64, height: 24), cornerRadius: 8), d.opacity(0.35))
            fill(&ctx, Path(roundedRect: CGRect(x: 26, y: 32, width: 48, height: 28), cornerRadius: 6), p, highlight: s)

        case "seaweedSheet":
            var c = ctx; c.translateBy(x: 50, y: 50); c.rotate(by: .degrees(-10)); c.translateBy(x: -50, y: -50)
            fill(&c, Path(roundedRect: CGRect(x: 24, y: 22, width: 52, height: 56), cornerRadius: 6), p, highlight: s)

        case "oilDrop":
            var drop = Path()
            drop.move(to: CGPoint(x: 50, y: 16))
            drop.addCurve(to: CGPoint(x: 74, y: 58), control1: CGPoint(x: 68, y: 38), control2: CGPoint(x: 74, y: 46))
            drop.addCurve(to: CGPoint(x: 26, y: 58), control1: CGPoint(x: 74, y: 86), control2: CGPoint(x: 26, y: 86))
            drop.addCurve(to: CGPoint(x: 50, y: 16), control1: CGPoint(x: 26, y: 46), control2: CGPoint(x: 32, y: 38))
            fill(&ctx, drop, p, highlight: s)

        case "dateFruit":
            var c = ctx; c.translateBy(x: 50, y: 50); c.rotate(by: .degrees(-24)); c.translateBy(x: -50, y: -50)
            fill(&c, Path(ellipseIn: CGRect(x: 26, y: 28, width: 48, height: 42)), p, highlight: s)

        case "lotusPetal":
            for rot in [-28.0, 28.0, 0.0] {
                var c = ctx; c.translateBy(x: 50, y: 66); c.rotate(by: .degrees(rot))
                var pt = Path()
                pt.move(to: .zero)
                pt.addQuadCurve(to: CGPoint(x: 0, y: -44), control: CGPoint(x: -16, y: -24))
                pt.addQuadCurve(to: .zero, control: CGPoint(x: 16, y: -24))
                fill(&c, pt, rot == 0 ? s : p)
            }
            ctx.fill(Path(ellipseIn: CGRect(x: 42, y: 58, width: 16, height: 10)), with: .color(d))

        case "snowFungus":
            for (cx, cy, r) in [(36.0, 52.0, 18.0), (64.0, 52.0, 18.0), (50.0, 38.0, 22.0), (50.0, 58.0, 18.0)] {
                fill(&ctx, Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), p, highlight: s)
            }

        case "gingerRoot":
            fill(&ctx, Path(roundedRect: CGRect(x: 22, y: 42, width: 52, height: 24), cornerRadius: 12), p, highlight: s)
            fill(&ctx, Path(roundedRect: CGRect(x: 44, y: 24, width: 20, height: 28), cornerRadius: 10), p, highlight: s)
            leaf(&ctx, at: CGPoint(x: 54, y: 24), angle: -35, scale: 0.75, color: d)

        default:
            fill(&ctx, Path(ellipseIn: CGRect(x: 22, y: 24, width: 56, height: 52)), p, highlight: s)
        }
    }
}

/// Bespoke dual-style Montessori studio instrument badges replacing generic SF Symbols across the dock and Journey hub.
struct ToolArtBadge: View {
    let toolId: String
    var size: CGFloat = 36
    var active: Bool = false
    var flat: Bool = (ArtStyle.current == .flat)

    var body: some View {
        let spec = IconAssetResolver.shared.toolSpec(for: toolId)
        if let spec, let custom = IconAssetResolver.shared.bundledImage(asset3D: spec.asset3D, asset2D: spec.asset2D, maxPixel: Int(size * 3)) {
            Image(uiImage: custom)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Canvas { ctx, sz in
                let s = min(sz.width, sz.height) / 100
                ctx.translateBy(x: (sz.width - 100 * s) / 2, y: (sz.height - 100 * s) / 2)
                ctx.scaleBy(x: s, y: s)
                drawTool(&ctx)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        }
    }

    private func drawCushion(_ ctx: inout GraphicsContext, tint: Color) {
        let rect = CGRect(x: 6, y: 6, width: 88, height: 88)
        let bg = RoundedRectangle(cornerRadius: 28, style: .continuous).path(in: rect)
        if flat {
            ctx.fill(bg, with: .color(tint.opacity(0.16)))
            ctx.stroke(bg, with: .color(Palette.ink.opacity(0.22)), lineWidth: 2)
        } else {
            ctx.fill(
                bg,
                with: .radialGradient(
                    Gradient(colors: [
                        tint.mix(with: .white, by: 0.72),
                        tint.mix(with: .white, by: 0.56),
                        tint.mix(with: .black, by: 0.04)
                    ]),
                    center: CGPoint(x: 32, y: 28),
                    startRadius: 4,
                    endRadius: 88
                )
            )
            ctx.stroke(
                bg,
                with: .linearGradient(
                    Gradient(colors: [.white.opacity(0.85), tint.opacity(0.22)]),
                    startPoint: CGPoint(x: 6, y: 6),
                    endPoint: CGPoint(x: 94, y: 94)
                ),
                lineWidth: 2.2
            )
        }
    }

    private func sculptShape(_ ctx: inout GraphicsContext, _ path: Path, _ color: Color, highlight: Color? = nil) {
        if flat {
            ctx.fill(path, with: .color(color))
            ctx.stroke(path, with: .color(Palette.ink.opacity(0.25)), lineWidth: 1.8)
            return
        }
        let b = path.boundingRect
        let top = highlight ?? color.mix(with: .white, by: 0.30)
        let bot = color.mix(with: .black, by: 0.20)
        ctx.fill(
            path,
            with: .radialGradient(
                Gradient(colors: [top, color, bot]),
                center: CGPoint(x: b.minX + b.width * 0.32, y: b.minY + b.height * 0.28),
                startRadius: 1,
                endRadius: max(b.width, b.height) * 0.85
            )
        )
    }

    private func drawTool(_ ctx: inout GraphicsContext) {
        switch toolId {
        case "bedside_lamp":
            let dusk = active ? Palette.amber : Palette.rod
            if flat {
                drawCushion(&ctx, tint: dusk)
            } else {
                let rect = CGRect(x: 6, y: 6, width: 88, height: 88)
                let bg = RoundedRectangle(cornerRadius: 28, style: .continuous).path(in: rect)
                ctx.fill(
                    bg,
                    with: .radialGradient(
                        Gradient(colors: [
                            active ? Color(hex: 0x3A345C) : Color(hex: 0x29335E),
                            Color(hex: 0x151D3B)
                        ]),
                        center: CGPoint(x: 34, y: 30),
                        startRadius: 4,
                        endRadius: 85
                    )
                )
                ctx.stroke(bg, with: .color(Palette.amber.opacity(active ? 0.55 : 0.28)), lineWidth: 2)
            }
            ctx.fill(Path(ellipseIn: CGRect(x: 34, y: 74, width: 42, height: 11)), with: .color(.black.opacity(0.32)))
            sculptShape(&ctx, Path(roundedRect: CGRect(x: 36, y: 71, width: 38, height: 11), cornerRadius: 5.5), Color(hex: 0x7A573B))
            var arc = Path()
            arc.move(to: CGPoint(x: 56, y: 72))
            arc.addCurve(to: CGPoint(x: 36, y: 40), control1: CGPoint(x: 64, y: 20), control2: CGPoint(x: 38, y: 16))
            ctx.stroke(arc, with: .color(Color(hex: 0x7B8EC2)), style: StrokeStyle(lineWidth: 7.5, lineCap: .round))
            ctx.fill(
                Path(ellipseIn: CGRect(x: 11, y: 19, width: 50, height: 50)),
                with: .radialGradient(
                    Gradient(colors: [Palette.amber.opacity(active ? 0.85 : 0.45), Palette.amber.opacity(0)]),
                    center: CGPoint(x: 36, y: 44),
                    startRadius: 2,
                    endRadius: 25
                )
            )
            sculptShape(&ctx, Path(ellipseIn: CGRect(x: 24, y: 33, width: 24, height: 24)), active ? Palette.amber : Palette.bead, highlight: Palette.beadLight)
            ctx.fill(Path(ellipseIn: CGRect(x: 29, y: 37, width: 7, height: 6)), with: .color(.white.opacity(0.75)))

        case "sensory_toybox":
            drawCushion(&ctx, tint: Crayon.teal)
            let bars: [(CGFloat, CGFloat, Color)] = [
                (23, 56, Crayon.cherry),
                (41, 49, Crayon.sunflower),
                (59, 42, Crayon.teal),
                (77, 36, Crayon.sky),
            ]
            // Twin horizontal maple resonator rails behind keys
            sculptShape(&ctx, Path(roundedRect: CGRect(x: 16, y: 58, width: 68, height: 10), cornerRadius: 4), Color(hex: 0xC69A6B))
            for (x, h, col) in bars {
                let y = 76 - h
                let shadow = RoundedRectangle(cornerRadius: 6).path(in: CGRect(x: x - 6.5, y: y + 3, width: 13, height: h))
                if !flat { ctx.fill(shadow, with: .color(.black.opacity(0.16))) }
                let bar = RoundedRectangle(cornerRadius: 6).path(in: CGRect(x: x - 6.5, y: y, width: 13, height: h))
                sculptShape(&ctx, bar, col)
                sculptShape(&ctx, Path(ellipseIn: CGRect(x: x - 2.3, y: y + 5, width: 4.6, height: 4.6)), Palette.bead, highlight: Palette.beadLight)
            }

        case "first_foods":
            drawCushion(&ctx, tint: Crayon.leaf)
            if !flat {
                ctx.fill(Path(ellipseIn: CGRect(x: 18, y: 23, width: 64, height: 61)), with: .color(Color(hex: 0x7A5E3B).opacity(0.22)))
            }
            let dish = Path(ellipseIn: CGRect(x: 17, y: 19, width: 66, height: 62))
            sculptShape(&ctx, dish, Color(hex: 0xFAF4E8), highlight: .white)
            ctx.stroke(dish, with: .color(Crayon.caramel.opacity(0.45)), lineWidth: 2.5)
            // Three glossy dimensional whole foods inside glazed bowl
            for (cx, cy, col) in [(36.0, 41.0, Crayon.tangerine), (62.0, 41.0, Crayon.leaf), (49.0, 61.0, Crayon.cherry)] {
                if !flat { ctx.fill(Path(ellipseIn: CGRect(x: cx - 10, y: cy - 7, width: 20, height: 20)), with: .color(.black.opacity(0.14))) }
                sculptShape(&ctx, Path(ellipseIn: CGRect(x: cx - 10, y: cy - 10, width: 20, height: 20)), col)
                ctx.fill(Path(ellipseIn: CGRect(x: cx - 5, y: cy - 6, width: 6, height: 4)), with: .color(.white.opacity(0.55)))
            }

        case "rhythm_dial":
            drawCushion(&ctx, tint: Crayon.lilac)
            if !flat {
                ctx.fill(Path(ellipseIn: CGRect(x: 20, y: 22, width: 60, height: 60)), with: .color(.black.opacity(0.12)))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: 21, y: 21, width: 58, height: 58)), with: .color(Color(hex: 0xFFFDF8).opacity(0.82)))
            var topArc = Path(); topArc.addArc(center: CGPoint(x: 50, y: 50), radius: 26, startAngle: .degrees(185), endAngle: .degrees(355), clockwise: false)
            ctx.stroke(topArc, with: .color(Crayon.sunflower), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            var botArc = Path(); botArc.addArc(center: CGPoint(x: 50, y: 50), radius: 26, startAngle: .degrees(5), endAngle: .degrees(175), clockwise: false)
            ctx.stroke(botArc, with: .color(Palette.rod), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            sculptShape(&ctx, Path(ellipseIn: CGRect(x: 41, y: 14, width: 18, height: 18)), Palette.bead, highlight: Palette.beadLight)

        case "storybook":
            drawCushion(&ctx, tint: Crayon.caramel)
            if !flat {
                ctx.fill(RoundedRectangle(cornerRadius: 10).path(in: CGRect(x: 15, y: 27, width: 70, height: 52)), with: .color(.black.opacity(0.18)))
            }
            let cover = RoundedRectangle(cornerRadius: 9).path(in: CGRect(x: 14, y: 23, width: 72, height: 54))
            sculptShape(&ctx, cover, Crayon.caramel)
            let leftPage = RoundedRectangle(cornerRadius: 4).path(in: CGRect(x: 19, y: 27, width: 30, height: 46))
            let rightPage = RoundedRectangle(cornerRadius: 4).path(in: CGRect(x: 51, y: 27, width: 30, height: 46))
            sculptShape(&ctx, leftPage, Palette.paper, highlight: .white)
            sculptShape(&ctx, rightPage, Color(hex: 0xF5EAD4), highlight: Palette.paper)
            sculptShape(&ctx, Path(ellipseIn: CGRect(x: 26, y: 38, width: 16, height: 16)), Crayon.leaf)
            var rib = Path()
            rib.move(to: CGPoint(x: 60, y: 27)); rib.addLine(to: CGPoint(x: 70, y: 27))
            rib.addLine(to: CGPoint(x: 70, y: 56)); rib.addLine(to: CGPoint(x: 65, y: 50))
            rib.addLine(to: CGPoint(x: 60, y: 56)); rib.closeSubpath()
            sculptShape(&ctx, rib, Palette.bead, highlight: Palette.beadLight)

        case "journey":
            drawCushion(&ctx, tint: Palette.bead)
            var road = Path()
            road.move(to: CGPoint(x: 32, y: 78))
            road.addCurve(to: CGPoint(x: 64, y: 22), control1: CGPoint(x: 72, y: 60), control2: CGPoint(x: 28, y: 40))
            ctx.stroke(road, with: .color(Crayon.leaf.opacity(0.75)), style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
            for (bx, by, br, col) in [(25.0, 69.0, 17.0, Crayon.leaf), (41.0, 41.0, 19.0, Palette.bead), (55.0, 16.0, 17.0, Crayon.sky)] {
                if !flat { ctx.fill(Path(ellipseIn: CGRect(x: bx, y: by + 2.5, width: br, height: br)), with: .color(.black.opacity(0.18))) }
                sculptShape(&ctx, Path(ellipseIn: CGRect(x: bx, y: by, width: br, height: br)), col)
                ctx.fill(Path(ellipseIn: CGRect(x: bx + br * 0.25, y: by + br * 0.2, width: br * 0.3, height: br * 0.22)), with: .color(.white.opacity(0.7)))
            }

        default:
            drawCushion(&ctx, tint: Palette.accent)
            let sym = IconAssetResolver.shared.toolSpec(for: toolId)?.fallbackSymbol ?? "sparkles"
            let resolved = ctx.resolve(Image(systemName: sym))
            ctx.draw(resolved, in: CGRect(x: 24, y: 24, width: 52, height: 52))
        }
    }
}
