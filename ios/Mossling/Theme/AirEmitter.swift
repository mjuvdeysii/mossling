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
        private let emitter = CAEmitterLayer()
        private var kind: Kind
        private let scale: CGFloat
        private var built = false

        init(kind: Kind, scale: CGFloat) {
            self.kind = kind; self.scale = scale
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            backgroundColor = .clear
            layer.addSublayer(emitter)
        }
        required init?(coder: NSCoder) { fatalError() }

        func update(kind: Kind) {
            guard kind != self.kind else { return }
            self.kind = kind; built = false; setNeedsLayout()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            let b = bounds
            guard b.width > 1, b.height > 1 else { return }
            emitter.frame = b
            switch kind {
            case .day:
                emitter.emitterShape = .line
                emitter.emitterPosition = CGPoint(x: b.midX, y: -24)
                emitter.emitterSize = CGSize(width: b.width * 1.15, height: 1)
            case .night:
                emitter.emitterShape = .line
                emitter.emitterPosition = CGPoint(x: b.midX, y: b.height + 16)
                emitter.emitterSize = CGSize(width: b.width, height: 1)
            case .rise:
                // the record pages' stage: small things rising behind the right half, round the companion
                emitter.emitterShape = .line
                emitter.emitterPosition = CGPoint(x: b.width * 0.67, y: b.height + 8)
                emitter.emitterSize = CGSize(width: b.width * 0.5, height: 1)
            }
            if !built { build(height: b.height); built = true }
        }

        private func build(height h: CGFloat) {
            let z = scale
            let preview = scale < 1
            var cells: [CAEmitterCell] = []
            switch kind {
            case .day(let tone):
                // fall speed in points a second; a whole page takes the better part of a minute
                let v: CGFloat = (preview ? 14 : 24) * max(0.5, z)
                let life = Float((h + 60) / v * 1.1)
                func cell(_ img: UIImage, rate: Float, spin: CGFloat, size: CGFloat) -> CAEmitterCell {
                    let c = CAEmitterCell()
                    c.contents = img.cgImage
                    c.birthRate = rate * (preview ? 2.5 : 1)
                    c.lifetime = life; c.lifetimeRange = life * 0.15
                    c.velocity = v; c.velocityRange = v * 0.35
                    c.emissionLongitude = .pi / 2; c.emissionRange = .pi / 7   // mostly down, a little sideways
                    c.xAcceleration = 0.12                                       // a light breeze from the left
                    c.spin = 0; c.spinRange = spin
                    c.scale = size * z / 3; c.scaleRange = c.scale * 0.3         // images are drawn at 3×
                    c.alphaRange = 0.25
                    c.alphaSpeed = -0.6 / life                                   // fade a little toward the foot
                    return c
                }
                cells = [
                    cell(Self.seed(), rate: 0.11, spin: 0.5, size: 1.0),
                    cell(Self.petal(tone), rate: 0.09, spin: 1.6, size: 1.0),
                    cell(Self.leaf(), rate: 0.08, spin: 1.3, size: 1.0),
                    cell(Self.pollen(), rate: 0.1, spin: 0, size: 1.0),
                ]
                emitter.renderMode = .unordered
            case .night:
                let v: CGFloat = 16 * max(0.5, z)
                let life = Float((h + 40) / v)
                let c = CAEmitterCell()
                c.contents = Self.mote().cgImage
                c.birthRate = preview ? 1.2 : 0.55
                c.lifetime = life; c.lifetimeRange = life * 0.2
                c.velocity = v; c.velocityRange = v * 0.4
                c.emissionLongitude = -.pi / 2; c.emissionRange = .pi / 9
                c.scale = z / 3; c.scaleRange = z / 6
                c.alphaRange = 0.5
                c.alphaSpeed = -0.5 / life
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
            // already in mid-air when the page appears, not starting from an empty sky
            emitter.beginTime = CACurrentMediaTime() - Double(cells.first?.lifetime ?? 30) * 0.9
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
