import SwiftUI
import UIKit

/// What drifts on the page's air, as Core Animation particles: rendered by the system at the display's full rate,
/// so they glide instead of stepping, and cost the app's main thread nothing while the page scrolls over them.
/// By day: dandelion seeds, petals in the tab's colour, small leaves and pollen, falling slowly over the whole width
/// and turning as they go. At night: specks of the lamp's amber light, rising.
struct AirEmitter: UIViewRepresentable {
    enum Kind: Equatable { case day(UIColor), night, rise([UIImage]) }
    let kind: Kind
    var scale: Double = 1

    func makeUIView(context: Context) -> AirView { AirView(kind: kind, scale: CGFloat(scale)) }
    func updateUIView(_ v: AirView, context: Context) { v.update(kind: kind) }

    final class AirView: UIView {
        /// The drifts: three on a page or a preview (each swaying on its own), one on the record stage.
        private var emitters: [CAEmitterLayer] = []
        private var kind: Kind
        private let scale: CGFloat
        private var built = false
        private var builtSize: CGSize = .zero

        init(kind: Kind, scale: CGFloat) {
            self.kind = kind; self.scale = scale
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            backgroundColor = .clear
        }
        required init?(coder: NSCoder) { fatalError() }

        func update(kind: Kind) {
            guard kind != self.kind else { return }
            self.kind = kind; built = false; setNeedsLayout()
        }

        /// Three drifts at once, each swaying on its own slow breath of air, so the things in them do not move in step.
        private static let drifts = 3

        override func layoutSubviews() {
            super.layoutSubviews()
            let b = bounds
            guard b.width > 1, b.height > 1 else { return }
            if built && abs(builtSize.height - b.height) < 1 && abs(builtSize.width - b.width) < 1 { return }
            emitters.forEach { $0.removeFromSuperlayer() }
            emitters = []
            let n: Int
            if case .rise = kind { n = 1 } else { n = Self.drifts }
            for i in 0..<n {
                let e = CAEmitterLayer()
                e.frame = b
                switch kind {
                case .day:
                    // the page's whole height down to the meadow, from just off its left edge: the air carries them
                    // across the page, left to right, behind the cards (build 189's drift)
                    e.emitterShape = .rectangle; e.emitterMode = .volume
                    e.emitterPosition = CGPoint(x: -26, y: b.height * 0.36)
                    e.emitterSize = CGSize(width: 1, height: b.height * 0.64)
                case .night:
                    // fireflies rise from the foot of the page over its whole width
                    e.emitterShape = .line
                    e.emitterPosition = CGPoint(x: b.midX, y: b.height + 18)
                    e.emitterSize = CGSize(width: b.width * 0.96, height: 1)
                case .rise:
                    e.emitterShape = .line
                    e.emitterPosition = CGPoint(x: b.width * 0.67, y: b.height + 8)
                    e.emitterSize = CGSize(width: b.width * 0.5, height: 1)
                }
                build(e, size: b.size, index: i, of: n)
                if n > 1 {
                    // the drift's own sway: the whole stream lifts and settles (day) or leans (night), run by the
                    // render server, so every particle in it wavers without any per-frame work
                    let sway = CABasicAnimation(keyPath: { if case .night = kind { return "position.x" } else { return "position.y" } }())
                    let base: CGFloat = { if case .night = kind { return b.midX } else { return b.midY } }()
                    let amp: CGFloat = (scale < 1 ? 6 : 14) * (i % 2 == 0 ? 1 : -1)
                    sway.fromValue = base - amp; sway.toValue = base + amp
                    sway.duration = 2.6 + Double(i) * 0.9
                    sway.autoreverses = true; sway.repeatCount = .infinity
                    sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    sway.timeOffset = Double(i) * 1.3
                    e.add(sway, forKey: "sway")
                }
                layer.addSublayer(e); emitters.append(e)
            }
            built = true; builtSize = b.size
        }

        private func build(_ emitter: CAEmitterLayer, size: CGSize, index: Int, of n: Int) {
            let h = size.height, w = size.width
            let z = scale
            let preview = scale < 1
            let share = 1 / Float(n)
            var cells: [CAEmitterCell] = []
            switch kind {
            case .day(let tone):
                // across the page in fifteen to twenty-five seconds, sinking about a hundred points on the way
                let v: CGFloat = (w + 60) / (preview ? 9 : 19)
                let life = Float((w + 70) / v * 1.25)
                func cell(_ img: UIImage, rate: Float, spin: CGFloat, size: CGFloat, alpha: Float) -> CAEmitterCell {
                    let c = CAEmitterCell()
                    c.contents = img.cgImage
                    c.birthRate = rate * share * (preview ? 2.2 : 1)
                    c.lifetime = life; c.lifetimeRange = life * 0.1
                    c.velocity = v; c.velocityRange = v * 0.32
                    c.emissionLongitude = 0.06; c.emissionRange = 0.16           // with the air, a little down
                    c.yAcceleration = preview ? 0.8 : 0.5
                    c.spin = 0; c.spinRange = spin
                    c.scale = size * z / 3; c.scaleRange = c.scale * 0.25         // images are drawn at 3×
                    c.color = UIColor(white: 1, alpha: CGFloat(alpha)).cgColor     // light: the paper shows through
                    c.alphaRange = 0.12
                    return c
                }
                // a light air, not a busy one: a dozen things in view at once, small and half see-through. The seeds
                // float upright as dandelion seeds do — fluff up, seed hanging below — only rocking a little; the
                // leaves turn slowly; a few petals in the tab's colour; a little pollen
                cells = [
                    cell(Self.seed(), rate: 0.16, spin: 0.1, size: 1.0, alpha: 0.75),
                    cell(Self.petal(tone), rate: 0.14, spin: 1.2, size: 1.0, alpha: 0.6),
                    cell(Self.leaf(), rate: 0.08, spin: 0.9, size: 0.95, alpha: 0.55),
                    cell(Self.pollen(), rate: 0.18, spin: 0, size: 1.0, alpha: 0.6),
                ]
                emitter.renderMode = .unordered
            case .night:
                // up the page in thirty-five to fifty seconds, glowing and dimming as they go
                let v: CGFloat = (h + 40) / (preview ? 14 : 40)
                let life = Float((h + 60) / v)
                // fireflies, as the lamp's first night had them: a bright warm core in a wide soft halo, some twenty-five
                // in view, wandering up as they glow and fade
                let c = CAEmitterCell()
                c.contents = Self.firefly().cgImage
                c.birthRate = (preview ? 1.6 : 1.0) * share
                c.lifetime = life; c.lifetimeRange = life * 0.12
                c.velocity = v; c.velocityRange = v * 0.45
                c.emissionLongitude = -.pi / 2; c.emissionRange = .pi / 9
                c.scale = 0.26 * z; c.scaleRange = 0.12 * z      // a 120-pixel drawing: some 17 to 45 points of glow across
                c.alphaRange = 0.5
                // a firefly breathes: its halo swells bright and fades again and again on the way up
                let pulse = CAEmitterCell()
                pulse.contents = Self.firefly().cgImage
                pulse.birthRate = 0.55; pulse.lifetime = 2.2; pulse.lifetimeRange = 0.8
                pulse.velocity = 0; pulse.scale = 0.42 * z; pulse.scaleSpeed = -0.14 * z
                pulse.alphaRange = 0.1; pulse.alphaSpeed = -0.42
                c.emitterCells = [pulse]
                cells = [c]
                emitter.renderMode = .unordered   // the glow is in the drawing; additive layers also never reach a snapshot
            case .rise(let images):
                let v: CGFloat = max(12, h / 8)
                let life = Float((h + 20) / v)
                cells = images.map { img in
                    let c = CAEmitterCell()
                    c.contents = img.cgImage
                    c.birthRate = 1.0 / Float(max(1, images.count))
                    c.lifetime = life; c.lifetimeRange = life * 0.15
                    c.velocity = v; c.velocityRange = v * 0.25
                    c.emissionLongitude = -.pi / 2; c.emissionRange = .pi / 14
                    c.spin = 0; c.spinRange = 0.6
                    c.scale = 1.0 / 3; c.scaleRange = 0.1
                    c.alphaRange = 0.2
                    c.alphaSpeed = -0.8 / life
                    return c
                }
                emitter.renderMode = .unordered
            }
            emitter.emitterCells = cells
            // already in mid-air when the page appears, not starting from an empty sky; each drift out of step
            emitter.beginTime = CACurrentMediaTime() - Double(cells.first?.lifetime ?? 30) * (0.92 + 0.03 * Double(index))
        }

        // MARK: the particles, drawn once at 3×

        static func draw(_ size: CGSize, _ f: (CGContext) -> Void) -> UIImage {
            let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 3; fmt.opaque = false
            return UIGraphicsImageRenderer(size: size, format: fmt).image { f($0.cgContext) }
        }
        /// A dandelion seed as it floats: a parasol of very fine rays opening upward from the top of a thin beak, each
        /// ray ending in a faint tuft, and the small brown seed hanging at the bottom — drawn upright, so it flies the
        /// right way up. Soft white with the faintest warm edge, so it reads on paper without standing out.
        private static func seed() -> UIImage {
            draw(CGSize(width: 22, height: 26)) { c in
                let hub = CGPoint(x: 11, y: 10)
                let warm = UIColor(red: 0.66, green: 0.57, blue: 0.43, alpha: 0.22)
                // the rays: a wide fan above the hub, gently curving outward, longest in the middle of the fan
                let rays = 15
                for pass in 0..<2 {
                    c.setStrokeColor((pass == 0 ? warm : UIColor.white.withAlphaComponent(0.92)).cgColor)
                    c.setLineWidth(pass == 0 ? 0.9 : 0.45); c.setLineCap(.round)
                    for k in 0..<rays {
                        let t = CGFloat(k) / CGFloat(rays - 1)
                        let a = .pi + 0.18 + t * (.pi - 0.36)                  // from left-up round to right-up
                        let len: CGFloat = 7.2 + 1.6 * sin(t * .pi)
                        let tip = CGPoint(x: hub.x + cos(a) * len, y: hub.y + sin(a) * len)
                        let mid = CGPoint(x: hub.x + cos(a - 0.08) * len * 0.55, y: hub.y + sin(a - 0.08) * len * 0.55)
                        c.move(to: hub); c.addQuadCurve(to: tip, control: mid)
                    }
                    c.strokePath()
                }
                // a faint tuft at each tip
                c.setFillColor(UIColor.white.withAlphaComponent(0.7).cgColor)
                for k in 0..<rays {
                    let t = CGFloat(k) / CGFloat(rays - 1)
                    let a = .pi + 0.18 + t * (.pi - 0.36)
                    let len: CGFloat = 7.2 + 1.6 * sin(t * .pi)
                    c.fillEllipse(in: CGRect(x: hub.x + cos(a) * len - 0.7, y: hub.y + sin(a) * len - 0.7, width: 1.4, height: 1.4))
                }
                // the beak, thin and pale, and the seed at its foot
                c.setStrokeColor(UIColor(red: 0.78, green: 0.71, blue: 0.56, alpha: 0.75).cgColor); c.setLineWidth(0.5)
                c.move(to: hub); c.addLine(to: CGPoint(x: hub.x, y: hub.y + 9)); c.strokePath()
                c.setFillColor(UIColor(red: 0.55, green: 0.42, blue: 0.28, alpha: 0.8).cgColor)
                c.fillEllipse(in: CGRect(x: hub.x - 0.9, y: hub.y + 8.6, width: 1.8, height: 4.2))
            }
        }
        private static func petal(_ tone: UIColor) -> UIImage {
            draw(CGSize(width: 12, height: 8)) { c in
                c.setFillColor(tone.withAlphaComponent(0.85).cgColor)
                c.fillEllipse(in: CGRect(x: 1, y: 1.4, width: 10, height: 5.2))
                c.setFillColor(UIColor.white.withAlphaComponent(0.35).cgColor)
                c.fillEllipse(in: CGRect(x: 3, y: 2.2, width: 4, height: 1.6))
            }
        }
        private static func leaf() -> UIImage {
            draw(CGSize(width: 13, height: 9)) { c in
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 1.5, y: 4.5))
                path.addQuadCurve(to: CGPoint(x: 11.5, y: 4.5), controlPoint: CGPoint(x: 6.5, y: 0))
                path.addQuadCurve(to: CGPoint(x: 1.5, y: 4.5), controlPoint: CGPoint(x: 6.5, y: 9))
                c.setFillColor(UIColor(red: 0.42, green: 0.75, blue: 0.43, alpha: 0.8).cgColor)
                c.addPath(path.cgPath); c.fillPath()
                c.setStrokeColor(UIColor(red: 0.25, green: 0.56, blue: 0.29, alpha: 0.45).cgColor); c.setLineWidth(0.6)
                c.move(to: CGPoint(x: 2.5, y: 4.5)); c.addLine(to: CGPoint(x: 10.5, y: 4.5)); c.strokePath()
            }
        }
        private static func pollen() -> UIImage {
            draw(CGSize(width: 14, height: 14)) { c in
                c.setFillColor(UIColor(red: 1, green: 0.83, blue: 0.42, alpha: 0.18).cgColor)
                c.fillEllipse(in: CGRect(x: 1, y: 1, width: 12, height: 12))
                c.setFillColor(UIColor(red: 1, green: 0.76, blue: 0.24, alpha: 0.75).cgColor)
                c.fillEllipse(in: CGRect(x: 5.2, y: 5.2, width: 3.6, height: 3.6))
            }
        }
        /// A firefly: a small near-white warm core, an amber glow round it and a wide faint halo.
        private static func firefly() -> UIImage {
            draw(CGSize(width: 40, height: 40)) { c in
                let amber = UIColor(Palette.amber), core = UIColor(red: 1, green: 0.95, blue: 0.78, alpha: 1)
                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: [core.cgColor, amber.withAlphaComponent(0.75).cgColor, amber.withAlphaComponent(0.22).cgColor, amber.withAlphaComponent(0.07).cgColor, amber.withAlphaComponent(0).cgColor] as CFArray,
                                   locations: [0, 0.09, 0.22, 0.55, 1])!
                c.drawRadialGradient(g, startCenter: CGPoint(x: 20, y: 20), startRadius: 0, endCenter: CGPoint(x: 20, y: 20), endRadius: 20, options: [])
            }
        }
        private static func mote() -> UIImage {
            draw(CGSize(width: 22, height: 22)) { c in
                let amber = UIColor(Palette.amber)
                let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: [amber.withAlphaComponent(0.85).cgColor, amber.withAlphaComponent(0.18).cgColor, amber.withAlphaComponent(0).cgColor] as CFArray,
                                   locations: [0, 0.25, 1])!
                c.drawRadialGradient(g, startCenter: CGPoint(x: 11, y: 11), startRadius: 0, endCenter: CGPoint(x: 11, y: 11), endRadius: 11, options: [])
            }
        }
    }
}
