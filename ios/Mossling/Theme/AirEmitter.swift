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
                func cell(_ img: UIImage, rate: Float, spin: CGFloat, size: CGFloat) -> CAEmitterCell {
                    let c = CAEmitterCell()
                    c.contents = img.cgImage
                    c.birthRate = rate * share * (preview ? 2.2 : 1)
                    c.lifetime = life; c.lifetimeRange = life * 0.1
                    c.velocity = v; c.velocityRange = v * 0.32
                    c.emissionLongitude = 0.06; c.emissionRange = 0.16           // with the air, a little down
                    c.yAcceleration = preview ? 0.8 : 0.5
                    c.spin = 0; c.spinRange = spin
                    c.scale = size * z / 3; c.scaleRange = c.scale * 0.3          // images are drawn at 3×
                    c.alphaRange = 0.2
                    return c
                }
                // build 189's size (about 1.7 times the drawn particle) and a fuller air: some thirty in view at once
                cells = [
                    cell(Self.seed(), rate: 0.42, spin: 0.8, size: 1.6),
                    cell(Self.petal(tone), rate: 0.38, spin: 2.0, size: 1.6),
                    cell(Self.leaf(), rate: 0.32, spin: 1.6, size: 1.6),
                    cell(Self.pollen(), rate: 0.36, spin: 0, size: 1.5),
                ]
                emitter.renderMode = .unordered
            case .night:
                // up the page in thirty-five to fifty seconds, glowing and dimming as they go
                let v: CGFloat = (h + 40) / (preview ? 14 : 40)
                let life = Float((h + 60) / v)
                let c = CAEmitterCell()
                c.contents = Self.mote().cgImage
                c.birthRate = (preview ? 1.4 : 0.85) * share
                c.lifetime = life; c.lifetimeRange = life * 0.12
                c.velocity = v; c.velocityRange = v * 0.4
                c.emissionLongitude = -.pi / 2; c.emissionRange = .pi / 12
                c.scale = 1.35 * z / 3; c.scaleRange = 0.6 * z / 3
                c.alphaRange = 0.45
                // a firefly breathes: its glow swells and fades again and again on the way up
                let pulse = CAEmitterCell()
                pulse.contents = Self.mote().cgImage
                pulse.birthRate = 0.7; pulse.lifetime = 1.8; pulse.lifetimeRange = 0.6
                pulse.velocity = 0; pulse.scale = 1.9 * z / 3; pulse.scaleSpeed = -0.5 * z / 3
                pulse.alphaSpeed = -0.5
                c.emitterCells = [pulse]
                cells = [c]
                emitter.renderMode = .additive
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
        /// A dandelion seed: a fluff of fine rays on a short stalk, with a faint warm edge so it reads on paper.
        private static func seed() -> UIImage {
            draw(CGSize(width: 18, height: 20)) { c in
                let p = CGPoint(x: 9, y: 9)
                for (w, col) in [(CGFloat(1.6), UIColor(red: 0.62, green: 0.52, blue: 0.38, alpha: 0.35)), (CGFloat(0.9), UIColor.white)] {
                    c.setStrokeColor(col.cgColor); c.setLineWidth(w); c.setLineCap(.round)
                    for k in 0..<9 {
                        let q: CGFloat = CGFloat(k) / 8 * .pi + .pi
                        c.move(to: p); c.addLine(to: CGPoint(x: p.x + cos(q) * 7, y: p.y + sin(q) * 7))
                    }
                    c.strokePath()
                }
                c.setFillColor(UIColor.white.cgColor)
                for k in 0..<9 { let q: CGFloat = CGFloat(k) / 8 * .pi + .pi; c.fillEllipse(in: CGRect(x: p.x + cos(q) * 7 - 1.1, y: p.y + sin(q) * 7 - 1.1, width: 2.2, height: 2.2)) }
                c.setStrokeColor(UIColor(red: 0.72, green: 0.63, blue: 0.44, alpha: 0.85).cgColor); c.setLineWidth(1)
                c.move(to: p); c.addLine(to: CGPoint(x: p.x, y: p.y + 9)); c.strokePath()
            }
        }
        private static func petal(_ tone: UIColor) -> UIImage {
            draw(CGSize(width: 12, height: 8)) { c in
                c.setFillColor(tone.withAlphaComponent(0.6).cgColor)
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
                c.setFillColor(UIColor(red: 0.42, green: 0.75, blue: 0.43, alpha: 0.6).cgColor)
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
