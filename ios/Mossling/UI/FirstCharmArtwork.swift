import SwiftUI
import UIKit

/// Pure motif taxonomy for Montessori "第一次 / Firsts" keepsake charms.
/// Every built-in milestone and custom icon maps deterministically to a hand-crafted picture-book vector charm,
/// replacing raw system symbols with tactile keepsake badges across Firsts, Storybook, Growth Book, and Print Posters.
enum FirstCharmMotif: String, CaseIterable, Sendable {
    case smileSun
    case babyHand
    case voiceRipple
    case sproutLift
    case laughStar
    case rollArc
    case woodRing
    case tinyFeet
    case cushionSeat
    case milkTooth
    case tastingBowl
    case crawlTrack
    case blockStand
    case clapSpark
    case waveRibbon
    case familyHeart
    case firstShoe
    case weaningCup
    case curlRibbon
    case spoonCharm
    case fabricBall
    case jumpArc
    case crayonSpiral
    case morningClover
    case voiceQuote
    // Custom icon motifs
    case starCharm
    case dropletCharm
    case musicCharm
    case paperPlane
    case giftRibbon
    case cameraFrame
    case pawPrint
    case waterWaves
    case birthdayCake

    /// Deterministically resolves any built-in `Firsts.Kind.id` or `"icon:<symbol>"` key to its keepsake motif.
    static func of(key: String?) -> FirstCharmMotif {
        guard let key, !key.isEmpty else { return .starCharm }
        if key.hasPrefix("icon:") {
            let sym = String(key.dropFirst(5))
            switch sym {
            case "star.fill": return .starCharm
            case "heart.fill": return .familyHeart
            case "sun.max.fill": return .smileSun
            case "leaf.fill": return .sproutLift
            case "drop.fill": return .dropletCharm
            case "music.note": return .musicCharm
            case "airplane": return .paperPlane
            case "gift.fill": return .giftRibbon
            case "camera.fill": return .cameraFrame
            case "pawprint.fill": return .pawPrint
            case "water.waves": return .waterWaves
            case "birthday.cake.fill": return .birthdayCake
            default: return .starCharm
            }
        }
        switch key {
        case "smile": return .smileSun
        case "hand": return .babyHand
        case "coo", "babble": return .voiceRipple
        case "headup": return .sproutLift
        case "laugh": return .laughStar
        case "roll": return .rollArc
        case "grasp": return .woodRing
        case "feet": return .tinyFeet
        case "sit": return .cushionSeat
        case "tooth": return .milkTooth
        case "solid": return .tastingBowl
        case "crawl": return .crawlTrack
        case "pull", "stand": return .blockStand
        case "clap": return .clapSpark
        case "wave": return .waveRibbon
        case "mama": return .familyHeart
        case "step", "run": return .firstShoe
        case "cup": return .weaningCup
        case "haircut": return .curlRibbon
        case "spoon": return .spoonCharm
        case "kick": return .fabricBall
        case "jump": return .jumpArc
        case "sentence": return .voiceRipple
        case "quote": return .voiceQuote
        case "draw": return .crayonSpiral
        case "potty": return .morningClover
        default: return .starCharm
        }
    }
}

/// Tactile Montessori keepsake charm badge rendered synchronously with soft matte-vinyl / cut-paper vector art.
struct FirstCharmBadge: View {
    let key: String?
    let color: Color
    var size: CGFloat = 34
    var round: Bool = true
    var active: Bool = false

    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp

    var body: some View {
        let dark = lamp || scheme == .dark
        let flat = ArtStyle.current == .flat
        let motif = FirstCharmMotif.of(key: key)
        let shape = RoundedRectangle(cornerRadius: round ? size / 2 : size * 0.28, style: .continuous)

        let bgTop: Color = active
            ? color.mix(with: .white, by: dark ? 0.10 : 0.16)
            : color.mix(with: dark ? Palette.lampCard : .white, by: dark ? 0.56 : 0.72)
        let bgBot: Color = active
            ? color.mix(with: .black, by: 0.10)
            : color.mix(with: dark ? Palette.lampCard : .white, by: dark ? 0.68 : 0.56)
        let fg: Color = active
            ? .white
            : (dark ? color.mix(with: .white, by: 0.36) : Crayon.ink(color))
        let accentFg: Color = active ? Palette.beadLight : Palette.bead

        ZStack {
            if flat {
                shape.fill(active ? color : color.opacity(dark ? 0.28 : 0.18))
                shape.strokeBorder(active ? color.mix(with: .black, by: 0.15) : color.opacity(dark ? 0.45 : 0.35), lineWidth: 1)
            } else {
                shape.fill(LinearGradient(colors: [bgTop, bgBot], startPoint: .topLeading, endPoint: .bottomTrailing))
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(dark ? 0.18 : 0.65), color.opacity(dark ? 0.30 : 0.22)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.9
                )
            }

            Canvas(rendersAsynchronously: false) { ctx, canvasSize in
                drawMotif(motif, ctx: &ctx, size: canvasSize, fg: fg, accent: accentFg)
            }
            .padding(size * 0.21)
        }
        .frame(width: size, height: size)
        .shadow(color: active ? color.opacity(0.28) : (dark ? .black.opacity(0.24) : color.opacity(0.14)), radius: active ? 4 : 2, y: 1.5)
        .accessibilityHidden(true)
    }

    private func drawMotif(_ motif: FirstCharmMotif, ctx: inout GraphicsContext, size: CGSize, fg: Color, accent: Color) {
        let w = size.width
        let h = size.height
        let cx = w / 2
        let cy = h / 2
        let r = min(w, h) * 0.48
        let lw = max(1.3, min(w, h) * 0.115)

        switch motif {
        case .smileSun:
            // Warm sun disc with radiant dots & happy crescent arc
            let coreR = r * 0.66
            ctx.fill(Path(ellipseIn: CGRect(x: cx - coreR, y: cy - coreR, width: coreR * 2, height: coreR * 2)), with: .color(fg.opacity(0.22)))
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - coreR, y: cy - coreR, width: coreR * 2, height: coreR * 2)), with: .color(fg), lineWidth: lw)
            var smile = Path()
            smile.addArc(center: CGPoint(x: cx, y: cy - r * 0.05), radius: r * 0.34, startAngle: .degrees(24), endAngle: .degrees(156), clockwise: false)
            ctx.stroke(smile, with: .color(fg), style: StrokeStyle(lineWidth: lw, lineCap: .round))
            for i in 0..<8 {
                let a = Double(i) * .pi / 4
                let pt = CGPoint(x: cx + cos(a) * r * 0.94, y: cy + sin(a) * r * 0.94)
                let dr = max(1.1, lw * 0.58)
                ctx.fill(Path(ellipseIn: CGRect(x: pt.x - dr, y: pt.y - dr, width: dr * 2, height: dr * 2)), with: .color(i % 2 == 0 ? fg : accent))
            }

        case .babyHand:
            let palmR = r * 0.44
            ctx.fill(Path(ellipseIn: CGRect(x: cx - palmR, y: cy - palmR * 0.35, width: palmR * 2, height: palmR * 1.75)), with: .color(fg))
            let fingers: [(CGFloat, CGFloat, CGFloat)] = [(-0.56, 0.05, 0.16), (-0.34, -0.58, 0.16), (0.0, -0.72, 0.17), (0.34, -0.56, 0.16), (0.60, -0.26, 0.15)]
            for (fx, fy, fr) in fingers {
                let px = cx + fx * r, py = cy + fy * r, pr = fr * r
                ctx.fill(Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)), with: .color(fg))
            }

        case .voiceRipple:
            // Speech bubble with acoustic gentle ripple arcs
            let bubble = CGRect(x: cx - r * 0.85, y: cy - r * 0.72, width: r * 1.65, height: r * 1.25)
            ctx.fill(Path(roundedRect: bubble, cornerRadius: r * 0.48), with: .color(fg.opacity(0.22)))
            ctx.stroke(Path(roundedRect: bubble, cornerRadius: r * 0.48), with: .color(fg), lineWidth: lw)
            for k in 0..<2 {
                let rad = r * (0.28 + CGFloat(k) * 0.24)
                var arc = Path()
                arc.addArc(center: CGPoint(x: cx - r * 0.18, y: cy - r * 0.10), radius: rad, startAngle: .degrees(-42), endAngle: .degrees(42), clockwise: false)
                ctx.stroke(arc, with: .color(k == 1 ? accent : fg), style: StrokeStyle(lineWidth: lw * 0.9, lineCap: .round))
            }

        case .sproutLift:
            var stem = Path()
            stem.move(to: CGPoint(x: cx, y: cy + r * 0.78))
            stem.addLine(to: CGPoint(x: cx, y: cy - r * 0.08))
            ctx.stroke(stem, with: .color(fg), style: StrokeStyle(lineWidth: lw, lineCap: .round))
            for dir in [-1.0, 1.0] {
                var leaf = Path()
                let base = CGPoint(x: cx, y: cy - r * 0.04)
                let tip = CGPoint(x: cx + CGFloat(dir) * r * 0.76, y: cy - r * 0.56)
                leaf.move(to: base)
                leaf.addQuadCurve(to: tip, control: CGPoint(x: cx + CGFloat(dir) * r * 0.12, y: cy - r * 0.78))
                leaf.addQuadCurve(to: base, control: CGPoint(x: cx + CGFloat(dir) * r * 0.72, y: cy + r * 0.08))
                ctx.fill(leaf, with: .color(fg))
            }
            let hill = Path(roundedRect: CGRect(x: cx - r * 0.65, y: cy + r * 0.54, width: r * 1.3, height: lw * 1.15), cornerRadius: lw / 2)
            ctx.fill(hill, with: .color(fg.opacity(0.65)))

        case .laughStar:
            let star = starPath(center: CGPoint(x: cx, y: cy - r * 0.04), outer: r * 0.85, inner: r * 0.40, points: 5)
            ctx.fill(star, with: .color(fg.opacity(0.24)))
            ctx.stroke(star, with: .color(fg), style: StrokeStyle(lineWidth: lw, lineJoin: .round))
            let dotR = max(1.4, lw * 0.7)
            ctx.fill(Path(ellipseIn: CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)), with: .color(accent))

        case .rollArc:
            var arc = Path()
            arc.addArc(center: CGPoint(x: cx, y: cy + r * 0.08), radius: r * 0.68, startAngle: .degrees(200), endAngle: .degrees(350), clockwise: false)
            ctx.stroke(arc, with: .color(fg), style: StrokeStyle(lineWidth: lw, lineCap: .round))
            let tip = CGPoint(x: cx + cos(-10 * .pi / 180) * r * 0.68, y: cy + r * 0.08 + sin(-10 * .pi / 180) * r * 0.68)
            var arrow = Path()
            arrow.move(to: CGPoint(x: tip.x - r * 0.24, y: tip.y - r * 0.04))
            arrow.addLine(to: tip)
            arrow.addLine(to: CGPoint(x: tip.x - r * 0.04, y: tip.y - r * 0.24))
            ctx.stroke(arrow, with: .color(fg), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
            let beadR = r * 0.24
            ctx.fill(Path(ellipseIn: CGRect(x: cx - beadR, y: cy + r * 0.26 - beadR, width: beadR * 2, height: beadR * 2)), with: .color(accent))

        case .woodRing:
            let ringR = r * 0.66
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - ringR, y: cy - ringR, width: ringR * 2, height: ringR * 2)), with: .color(fg), lineWidth: lw * 1.45)
            let beadR = r * 0.24
            ctx.fill(Path(ellipseIn: CGRect(x: cx + ringR * 0.55 - beadR, y: cy - ringR * 0.55 - beadR, width: beadR * 2, height: beadR * 2)), with: .color(accent))

        case .tinyFeet, .crawlTrack, .firstShoe:
            for (dx, dy, tilt) in [(-0.34, 0.14, -0.18), (0.34, -0.12, 0.18)] {
                let fx = cx + CGFloat(dx) * r
                let fy = cy + CGFloat(dy) * r
                let foot = Path(ellipseIn: CGRect(x: fx - r * 0.23, y: fy - r * 0.34, width: r * 0.46, height: r * 0.68))
                let t = CGAffineTransform(translationX: fx, y: fy).rotated(by: CGFloat(tilt)).translatedBy(x: -fx, y: -fy)
                ctx.fill(foot.applying(t), with: .color(fg))
                for k in -1...1 {
                    let tr = r * 0.09
                    let tx = fx + CGFloat(k) * r * 0.14
                    let ty = fy - r * 0.44
                    let toe = Path(ellipseIn: CGRect(x: tx - tr, y: ty - tr, width: tr * 2, height: tr * 2))
                    ctx.fill(toe.applying(t), with: .color(motif == .firstShoe ? accent : fg))
                }
            }

        case .cushionSeat:
            let baseRect = CGRect(x: cx - r * 0.78, y: cy + r * 0.14, width: r * 1.56, height: r * 0.46)
            ctx.fill(Path(roundedRect: baseRect, cornerRadius: r * 0.22), with: .color(fg.opacity(0.28)))
            ctx.stroke(Path(roundedRect: baseRect, cornerRadius: r * 0.22), with: .color(fg), lineWidth: lw)
            let topBlock = CGRect(x: cx - r * 0.44, y: cy - r * 0.56, width: r * 0.88, height: r * 0.56)
            ctx.fill(Path(roundedRect: topBlock, cornerRadius: r * 0.16), with: .color(fg))

        case .milkTooth:
            var tooth = Path()
            tooth.move(to: CGPoint(x: cx - r * 0.56, y: cy - r * 0.22))
            tooth.addQuadCurve(to: CGPoint(x: cx, y: cy - r * 0.62), control: CGPoint(x: cx - r * 0.42, y: cy - r * 0.72))
            tooth.addQuadCurve(to: CGPoint(x: cx + r * 0.56, y: cy - r * 0.22), control: CGPoint(x: cx + r * 0.42, y: cy - r * 0.72))
            tooth.addQuadCurve(to: CGPoint(x: cx + r * 0.34, y: cy + r * 0.68), control: CGPoint(x: cx + r * 0.62, y: cy + r * 0.36))
            tooth.addQuadCurve(to: CGPoint(x: cx, y: cy + r * 0.28), control: CGPoint(x: cx + r * 0.16, y: cy + r * 0.62))
            tooth.addQuadCurve(to: CGPoint(x: cx - r * 0.34, y: cy + r * 0.68), control: CGPoint(x: cx - r * 0.16, y: cy + r * 0.62))
            tooth.addQuadCurve(to: CGPoint(x: cx - r * 0.56, y: cy - r * 0.22), control: CGPoint(x: cx - r * 0.62, y: cy + r * 0.36))
            tooth.closeSubpath()
            ctx.fill(tooth, with: .color(fg.opacity(0.22)))
            ctx.stroke(tooth, with: .color(fg), style: StrokeStyle(lineWidth: lw, lineJoin: .round))
            let sp = starPath(center: CGPoint(x: cx + r * 0.56, y: cy - r * 0.52), outer: r * 0.24, inner: r * 0.08, points: 4)
            ctx.fill(sp, with: .color(accent))

        case .tastingBowl, .spoonCharm:
            if motif == .tastingBowl {
                var bowl = Path()
                bowl.addArc(center: CGPoint(x: cx, y: cy - r * 0.06), radius: r * 0.74, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                bowl.closeSubpath()
                ctx.fill(bowl, with: .color(fg.opacity(0.26)))
                ctx.stroke(bowl, with: .color(fg), style: StrokeStyle(lineWidth: lw, lineJoin: .round))
                let dotR = r * 0.19
                ctx.fill(Path(ellipseIn: CGRect(x: cx - dotR, y: cy - r * 0.34 - dotR, width: dotR * 2, height: dotR * 2)), with: .color(accent))
            } else {
                let headR = r * 0.34
                ctx.fill(Path(ellipseIn: CGRect(x: cx - headR * 0.9, y: cy - r * 0.72, width: headR * 1.8, height: headR * 2.2)), with: .color(fg))
                var handle = Path()
                handle.move(to: CGPoint(x: cx, y: cy - r * 0.04))
                handle.addLine(to: CGPoint(x: cx, y: cy + r * 0.78))
                ctx.stroke(handle, with: .color(fg), style: StrokeStyle(lineWidth: lw * 1.15, lineCap: .round))
            }

        case .blockStand:
            let b1 = CGRect(x: cx - r * 0.68, y: cy + r * 0.06, width: r * 0.62, height: r * 0.62)
            let b2 = CGRect(x: cx + r * 0.06, y: cy + r * 0.06, width: r * 0.62, height: r * 0.62)
            let b3 = CGRect(x: cx - r * 0.31, y: cy - r * 0.64, width: r * 0.62, height: r * 0.62)
            for b in [b1, b2, b3] {
                ctx.fill(Path(roundedRect: b, cornerRadius: r * 0.14), with: .color(b == b3 ? accent : fg))
            }

        case .clapSpark, .jumpArc:
            for dir in [-1.0, 1.0] {
                var arc = Path()
                arc.addArc(center: CGPoint(x: cx + CGFloat(dir) * r * 0.35, y: cy + r * 0.25), radius: r * 0.45, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                ctx.stroke(arc, with: .color(fg), style: StrokeStyle(lineWidth: lw, lineCap: .round))
            }
            let sp = starPath(center: CGPoint(x: cx, y: cy - r * 0.46), outer: r * 0.32, inner: r * 0.12, points: 4)
            ctx.fill(sp, with: .color(accent))

        case .waveRibbon:
            var wave = Path()
            wave.move(to: CGPoint(x: cx - r * 0.78, y: cy + r * 0.18))
            wave.addCurve(
                to: CGPoint(x: cx + r * 0.78, y: cy - r * 0.18),
                control1: CGPoint(x: cx - r * 0.24, y: cy - r * 0.66),
                control2: CGPoint(x: cx + r * 0.24, y: cy + r * 0.66)
            )
            ctx.stroke(wave, with: .color(fg), style: StrokeStyle(lineWidth: lw * 1.15, lineCap: .round))
            let bead = r * 0.18
            ctx.fill(Path(ellipseIn: CGRect(x: cx + r * 0.66 - bead, y: cy - r * 0.34 - bead, width: bead * 2, height: bead * 2)), with: .color(accent))

        case .familyHeart:
            let heart = heartPath(center: CGPoint(x: cx, y: cy + r * 0.06), size: r * 1.55)
            ctx.fill(heart, with: .color(fg))
            let dotR = r * 0.18
            ctx.fill(Path(ellipseIn: CGRect(x: cx - dotR, y: cy - r * 0.12 - dotR, width: dotR * 2, height: dotR * 2)), with: .color(accent))

        case .weaningCup:
            let cupBody = CGRect(x: cx - r * 0.46, y: cy - r * 0.48, width: r * 0.92, height: r * 1.05)
            ctx.fill(Path(roundedRect: cupBody, cornerRadius: r * 0.24), with: .color(fg))
            for dir in [-1.0, 1.0] {
                let ear = CGRect(x: cx + CGFloat(dir) * r * 0.44 - r * 0.22, y: cy - r * 0.22, width: r * 0.44, height: r * 0.56)
                ctx.stroke(Path(ellipseIn: ear), with: .color(fg), lineWidth: lw)
            }

        case .curlRibbon:
            var curl = Path()
            curl.addArc(center: CGPoint(x: cx, y: cy), radius: r * 0.56, startAngle: .degrees(140), endAngle: .degrees(400), clockwise: false)
            ctx.stroke(curl, with: .color(fg), style: StrokeStyle(lineWidth: lw, lineCap: .round))
            let bowR = r * 0.22
            ctx.fill(Path(ellipseIn: CGRect(x: cx - bowR, y: cy + r * 0.36 - bowR, width: bowR * 2, height: bowR * 2)), with: .color(accent))

        case .fabricBall:
            let ballR = r * 0.72
            let rect = CGRect(x: cx - ballR, y: cy - ballR, width: ballR * 2, height: ballR * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(fg.opacity(0.20)))
            ctx.stroke(Path(ellipseIn: rect), with: .color(fg), lineWidth: lw)
            var seam = Path()
            seam.addArc(center: CGPoint(x: cx - ballR * 0.45, y: cy), radius: ballR * 0.92, startAngle: .degrees(-52), endAngle: .degrees(52), clockwise: false)
            ctx.stroke(seam, with: .color(accent), style: StrokeStyle(lineWidth: lw * 0.9, lineCap: .round))

        case .crayonSpiral:
            var spiral = Path()
            let steps = 42
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let a = t * 2.2 * 2 * .pi
                let rr = CGFloat(t) * r * 0.78
                let pt = CGPoint(x: cx + cos(a) * rr, y: cy + sin(a) * rr)
                if i == 0 { spiral.move(to: pt) } else { spiral.addLine(to: pt) }
            }
            ctx.stroke(spiral, with: .color(fg), style: StrokeStyle(lineWidth: lw, lineCap: .round))

        case .morningClover:
            for i in 0..<3 {
                let a = Double(i) * (2.0 * .pi / 3.0) - .pi / 2
                let lx = cx + cos(a) * r * 0.34
                let ly = cy + sin(a) * r * 0.34
                let pr = r * 0.34
                ctx.fill(Path(ellipseIn: CGRect(x: lx - pr, y: ly - pr, width: pr * 2, height: pr * 2)), with: .color(fg))
            }
            let coreR = r * 0.20
            ctx.fill(Path(ellipseIn: CGRect(x: cx - coreR, y: cy - coreR, width: coreR * 2, height: coreR * 2)), with: .color(accent))

        case .voiceQuote:
            let bubble = CGRect(x: cx - r * 0.72, y: cy - r * 0.56, width: r * 1.44, height: r * 1.04)
            ctx.stroke(
                Path(roundedRect: bubble, cornerRadius: r * 0.34),
                with: .color(fg),
                lineWidth: lw
            )
            let bars: [(CGFloat, CGFloat, Color)] = [
                (-r * 0.30, r * 0.36, accent),
                (0, r * 0.62, fg),
                (r * 0.30, r * 0.42, accent)
            ]
            for (dx, bh, col) in bars {
                var bar = Path()
                bar.move(to: CGPoint(x: cx + dx, y: cy - bh * 0.5 - r * 0.04))
                bar.addLine(to: CGPoint(x: cx + dx, y: cy + bh * 0.5 - r * 0.04))
                ctx.stroke(bar, with: .color(col), style: StrokeStyle(lineWidth: lw * 1.05, lineCap: .round))
            }

        case .starCharm:
            let star = starPath(center: CGPoint(x: cx, y: cy), outer: r * 0.84, inner: r * 0.38, points: 5)
            ctx.fill(star, with: .color(fg))

        case .dropletCharm:
            var drop = Path()
            drop.move(to: CGPoint(x: cx, y: cy - r * 0.82))
            drop.addCurve(to: CGPoint(x: cx, y: cy + r * 0.78), control1: CGPoint(x: cx + r * 0.74, y: cy + r * 0.08), control2: CGPoint(x: cx + r * 0.64, y: cy + r * 0.78))
            drop.addCurve(to: CGPoint(x: cx, y: cy - r * 0.82), control1: CGPoint(x: cx - r * 0.64, y: cy + r * 0.78), control2: CGPoint(x: cx - r * 0.74, y: cy + r * 0.08))
            ctx.fill(drop, with: .color(fg))

        case .musicCharm:
            let noteR = r * 0.28
            ctx.fill(Path(ellipseIn: CGRect(x: cx - r * 0.42, y: cy + r * 0.20, width: noteR * 2, height: noteR * 1.5)), with: .color(fg))
            var stem = Path()
            stem.move(to: CGPoint(x: cx - r * 0.42 + noteR * 1.7, y: cy + r * 0.36))
            stem.addLine(to: CGPoint(x: cx - r * 0.42 + noteR * 1.7, y: cy - r * 0.68))
            stem.addLine(to: CGPoint(x: cx + r * 0.56, y: cy - r * 0.42))
            ctx.stroke(stem, with: .color(fg), style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))

        case .paperPlane:
            var p = Path()
            p.move(to: CGPoint(x: cx + r * 0.82, y: cy - r * 0.46))
            p.addLine(to: CGPoint(x: cx - r * 0.78, y: cy - r * 0.02))
            p.addLine(to: CGPoint(x: cx - r * 0.14, y: cy + r * 0.22))
            p.addLine(to: CGPoint(x: cx + r * 0.10, y: cy + r * 0.74))
            p.closeSubpath()
            ctx.fill(p, with: .color(fg))

        case .giftRibbon:
            let box = CGRect(x: cx - r * 0.64, y: cy - r * 0.30, width: r * 1.28, height: r * 0.96)
            ctx.fill(Path(roundedRect: box, cornerRadius: r * 0.16), with: .color(fg.opacity(0.24)))
            ctx.stroke(Path(roundedRect: box, cornerRadius: r * 0.16), with: .color(fg), lineWidth: lw)
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: cx, y: cy - r * 0.30))
            ribbon.addLine(to: CGPoint(x: cx, y: cy + r * 0.66))
            ctx.stroke(ribbon, with: .color(accent), lineWidth: lw)
            let bow = CGRect(x: cx - r * 0.22, y: cy - r * 0.66, width: r * 0.44, height: r * 0.32)
            ctx.stroke(Path(ellipseIn: bow), with: .color(accent), lineWidth: lw * 0.9)

        case .cameraFrame:
            let frame = CGRect(x: cx - r * 0.76, y: cy - r * 0.50, width: r * 1.52, height: r * 1.10)
            ctx.fill(Path(roundedRect: frame, cornerRadius: r * 0.22), with: .color(fg))
            let lensR = r * 0.28
            ctx.fill(Path(ellipseIn: CGRect(x: cx - lensR, y: cy + r * 0.04 - lensR, width: lensR * 2, height: lensR * 2)), with: .color(accent))

        case .pawPrint:
            let mainR = r * 0.38
            ctx.fill(Path(ellipseIn: CGRect(x: cx - mainR, y: cy - mainR * 0.2, width: mainR * 2, height: mainR * 1.55)), with: .color(fg))
            for (dx, dy) in [(-0.56, -0.22), (-0.20, -0.58), (0.20, -0.58), (0.56, -0.22)] {
                let tr = r * 0.15
                ctx.fill(Path(ellipseIn: CGRect(x: cx + CGFloat(dx) * r - tr, y: cy + CGFloat(dy) * r - tr, width: tr * 2, height: tr * 2)), with: .color(fg))
            }

        case .waterWaves:
            for row in [-0.30, 0.24] {
                var wv = Path()
                let y0 = cy + CGFloat(row) * r
                wv.move(to: CGPoint(x: cx - r * 0.76, y: y0))
                wv.addQuadCurve(to: CGPoint(x: cx, y: y0), control: CGPoint(x: cx - r * 0.38, y: y0 - r * 0.32))
                wv.addQuadCurve(to: CGPoint(x: cx + r * 0.76, y: y0), control: CGPoint(x: cx + r * 0.38, y: y0 + r * 0.32))
                ctx.stroke(wv, with: .color(fg), style: StrokeStyle(lineWidth: lw, lineCap: .round))
            }

        case .birthdayCake:
            let base = CGRect(x: cx - r * 0.66, y: cy - r * 0.06, width: r * 1.32, height: r * 0.74)
            ctx.fill(Path(roundedRect: base, cornerRadius: r * 0.18), with: .color(fg))
            var candle = Path()
            candle.move(to: CGPoint(x: cx, y: cy - r * 0.08))
            candle.addLine(to: CGPoint(x: cx, y: cy - r * 0.50))
            ctx.stroke(candle, with: .color(fg), style: StrokeStyle(lineWidth: lw, lineCap: .round))
            let flameR = r * 0.14
            ctx.fill(Path(ellipseIn: CGRect(x: cx - flameR, y: cy - r * 0.72 - flameR, width: flameR * 2, height: flameR * 2.3)), with: .color(accent))
        }
    }

    private func starPath(center: CGPoint, outer: CGFloat, inner: CGFloat, points: Int) -> Path {
        var p = Path()
        let count = points * 2
        for i in 0..<count {
            let angle = Double(i) * .pi / Double(points) - .pi / 2
            let rad = i % 2 == 0 ? outer : inner
            let pt = CGPoint(x: center.x + cos(angle) * rad, y: center.y + sin(angle) * rad)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    private func heartPath(center: CGPoint, size: CGFloat) -> Path {
        let s = size * 0.5
        var p = Path()
        p.move(to: CGPoint(x: center.x, y: center.y + s * 0.85))
        p.addCurve(
            to: CGPoint(x: center.x - s, y: center.y - s * 0.2),
            control1: CGPoint(x: center.x - s * 0.7, y: center.y + s * 0.45),
            control2: CGPoint(x: center.x - s, y: center.y + s * 0.15)
        )
        p.addArc(center: CGPoint(x: center.x - s * 0.5, y: center.y - s * 0.25), radius: s * 0.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: center.x + s * 0.5, y: center.y - s * 0.25), radius: s * 0.5, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(
            to: CGPoint(x: center.x, y: center.y + s * 0.85),
            control1: CGPoint(x: center.x + s, y: center.y + s * 0.15),
            control2: CGPoint(x: center.x + s * 0.7, y: center.y + s * 0.45)
        )
        p.closeSubpath()
        return p
    }
}

/// High-resolution offline 3× cotton-paper Keepsake Print for "第一次 / Firsts" milestones (with Polaroid thumbnails).
struct FirstsPrintPoster: View {
    let babyName: String
    let ageText: String
    let birth: Day?
    let firsts: [First]
    let photos: [UUID: UIImage]

    var body: some View {
        let paper = Color(red: 0xFB / 255, green: 0xF7 / 255, blue: 0xF0 / 255)
        let ink = Color(red: 0x24 / 255, green: 0x1F / 255, blue: 0x1B / 255)
        let teal = Color(red: 0x0B / 255, green: 0x7D / 255, blue: 0x74 / 255)
        let gold = Color(red: 0xD4 / 255, green: 0xA2 / 255, blue: 0x1C / 255)
        let shown = Array(firsts.prefix(10))

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(babyName + (ageText.isEmpty ? "" : " · " + ageText))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink.opacity(0.62))
                    Text(L10n.t("第一次纪念线", "Firsts Keepsake Thread"))
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(teal)
                }
                Spacer()
                WaxSealBadge(seal: .gold, size: 36)
            }

            HStack(spacing: 8) {
                Text(L10n.t("共留存 \(firsts.count) 个第一次", "\(firsts.count) \(firsts.count == 1 ? "first" : "firsts") kept"))
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0x5C / 255, green: 0x41 / 255, blue: 0x00))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(gold.opacity(0.22), in: Capsule())

                if !photos.isEmpty {
                    Text(L10n.t("\(photos.count) 张拍立得相纸", "\(photos.count) \(photos.count == 1 ? "Polaroid" : "Polaroids")"))
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(teal.opacity(0.12), in: Capsule())
                }
                Spacer()
                Text(Day.today.md)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.48))
            }

            VStack(spacing: 8) {
                ForEach(shown) { f in
                    let color = Firsts.color(f)
                    HStack(alignment: .center, spacing: 10) {
                        FirstCharmBadge(key: f.key, color: color, size: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                if let birth {
                                    Text(Firsts.age(from: birth, to: Day(f.date)))
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color(red: 0x4A / 255, green: 0x33 / 255, blue: 0x00))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1.5)
                                        .background(gold.opacity(0.24), in: Capsule())
                                }
                                Text(Day(f.date).ymd)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundStyle(ink.opacity(0.55))
                            }
                            Text(Firsts.displayTitle(f))
                                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                .foregroundStyle(ink)
                            if let note = f.note, !note.isEmpty {
                                Text(note)
                                    .font(.system(size: 11, weight: .regular, design: .rounded))
                                    .foregroundStyle(ink.opacity(0.68))
                                    .lineLimit(2)
                            }
                        }
                        Spacer(minLength: 4)
                        if let img = photos[f.id] {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                .padding(3)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .shadow(color: ink.opacity(0.14), radius: 2, y: 1)
                        }
                    }
                    .padding(10)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if firsts.count > shown.count {
                    Text(L10n.t("以及更早的 \(firsts.count - shown.count) 个瞬间", "Plus \(firsts.count - shown.count) earlier moments"))
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink.opacity(0.52))
                }
            }

            if let birth {
                HStack(spacing: 8) {
                    Circle().fill(gold).frame(width: 10, height: 10)
                    Text(L10n.t("出生 · \(birth.ymd)", "Born · \(birth.ymd)"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink.opacity(0.65))
                }
                .padding(.top, 2)
            }

            Divider().opacity(0.28)

            Text(L10n.t("摸索台灯 · 孩子摸索，大人点灯", "Moss & Otto · They explore. You hold the light."))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(ink.opacity(0.55))
        }
        .padding(24)
        .frame(width: 360)
        .background(paper)
    }
}
