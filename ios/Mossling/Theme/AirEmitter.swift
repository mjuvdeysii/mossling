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
        /// One emitter for a preview or the record stage; on a page, one down each margin.
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

        /// On a page the drifting things keep to the two margins (the 16-point strips beside the content where no
        /// word or picture stands), so nothing ever crosses a title or a picture: they pass behind the cards' edges
        /// at most. In the small previews (scale < 1) there is no text, so the whole width is theirs.
        private var page: Bool {
            if case .rise = kind { return false }
            return scale >= 1
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            let b = bounds
            guard b.width > 1, b.height > 1 else { return }
            if built && abs(builtSize.height - b.height) < 1 && abs(builtSize.width - b.width) < 1 { return }
            emitters.forEach { $0.removeFromSuperlayer() }
            emitters = []
            let strips: [(x: CGFloat, w: CGFloat)]
            if page {
                let g: CGFloat = 16
                strips = [(g / 2, g * 0.5), (b.width - g / 2, g * 0.5)]
            } else if case .rise = kind {
                strips = [(b.width * 0.67, b.width * 0.5)]
            } else {
                strips = [(b.midX, b.width * 1.15)]
            }
            for (i, st) in strips.enumerated() {
                let e = CAEmitterLayer()
                e.frame = b
                e.emitterShape = .line
                e.emitterSize = CGSize(width: st.w, height: 1)
                switch kind {
                case .day: e.emitterPosition = CGPoint(x: st.x, y: -20)
                case .night: e.emitterPosition = CGPoint(x: st.x, y: b.height + 16)
                case .rise: e.emitterPosition = CGPoint(x: st.x, y: b.height + 8)
                }
                build(e, height: b.height, side: i)
                layer.addSublayer(e); emitters.append(e)
            }
            built = true; builtSize = b.size
        }

        private func build(_ emitter: CAEmitterLayer, height h: CGFloat, side: Int) {
            let z = scale
            let preview = scale < 1
            let narrow = page
            var cells: [CAEmitterCell] = []
            switch kind {
            case .day(let tone):
                // fall speed in points a second: a page in about twelve seconds, brisk enough to read as air moving
                let v: CGFloat = (preview ? 18 : 62) * max(0.5, z)
                let life = Float((h + 60) / v * 1.05)
                func cell(_ img: UIImage, rate: Float, spin: CGFloat, size: CGFloat) -> CAEmitterCell {
                    let c = CAEmitterCell()
                    c.contents = img.cgImage
                    c.birthRate = rate * (preview ? 2.5 : 1)
                    c.lifetime = life; c.lifetimeRange = life * 0.1
                    c.velocity = v; c.velocityRange = v * 0.4
                    c.emissionLongitude = .pi / 2
                    // in a margin, straight down with the least sideways spread, so nothing wanders into the text
                    c.emissionRange = narrow ? 0.035 : .pi / 7
                    c.xAcceleration = narrow ? 0 : 0.12
                    c.spin = 0; c.spinRange = spin
                    c.scale = size * z / 3; c.scaleRange = c.scale * 0.25       // images are drawn at 3×
                    c.alphaRange = 0.2
                    c.alphaSpeed = -0.45 / life                                  // fade a little toward the foot
                    return c
                }
                // the margins are narrow, so the things in them are a little smaller and come more often
                let k: CGFloat = narrow ? 0.85 : 1
                cells = [
                    cell(Self.seed(), rate: narrow ? 0.34 : 0.11, spin: 0.9, size: k),
                    cell(Self.petal(tone), rate: narrow ? 0.3 : 0.09, spin: 2.2, size: k),
                    cell(Self.leaf(), rate: narrow ? 0.26 : 0.08, spin: 1.8, size: k),
                    cell(Self.pollen(), rate: narrow ? 0.3 : 0.1, spin: 0, size: k),
                ]
                emitter.renderMode = .unordered
            case .night:
                let v: CGFloat = (narrow ? 34 : 16) * max(0.5, z)
                let life = Float((h + 40) / v)
                let c = CAEmitterCell()
                c.contents = Self.mote().cgImage
                c.birthRate = preview ? 1.2 : 0.9
                c.lifetime = life; c.lifetimeRange = life * 0.15
                c.velocity = v; c.velocityRange = v * 0.45
                c.emissionLongitude = -.pi / 2; c.emissionRange = narrow ? 0.035 : .pi / 9
                c.scale = z / 3; c.scaleRange = z / 7
                c.alphaRange = 0.5
                c.alphaSpeed = -0.4 / life
                // a firefly breathes: a soft pulse in its own glow
                let pulse = CAEmitterCell()
                pulse.contents = Self.mote().cgImage
                pulse.birthRate = 0.6; pulse.lifetime = 1.6; pulse.lifetimeRange = 0.6
                pulse.velocity = 0; pulse.scale = z / 2.2; pulse.scaleSpeed = -z / 4
                pulse.alphaSpeed = -0.55
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
            // already in mid-air when the page appears, not starting from an empty sky; the two margins out of step
            emitter.beginTime = CACurrentMediaTime() - Double(cells.first?.lifetime ?? 30) * (0.9 + 0.05 * Double(side))
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
