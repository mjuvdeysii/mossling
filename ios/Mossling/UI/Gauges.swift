import SwiftUI

// MARK: the record pages' own instruments (3D world)
//
// A bottle is set on a bottle: the milk rises to where the finger is, in 5 ml steps, with a tick under the finger for
// each. A temperature is set on a thermometer the same way, in 0.1 °C. A time is chosen as "now / 5 / 15 / 30 minutes
// / an hour ago", or exactly. A kind (a nappy, the milk, the side) is one of a few large tiles, each with its own
// object. The hidden 2D world keeps the plain controls of build 196.

/// A vessel that is filled by touch: tap or drag anywhere on it and the level follows the finger.
struct LevelGauge: View {
    enum Vessel { case bottle, thermometer }
    let vessel: Vessel
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    /// Values marked on the vessel, with their labels.
    let marks: [Double]
    let label: (Double) -> String
    let tint: Color
    /// From this value up the fill turns to the warning colour (a fever).
    var alarm: Double? = nil
    var liquid: Color = Color(hex: 0xFFF1D2)
    @Environment(\.lamp) private var lamp
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, s in draw(&ctx, s) }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { g in set(g.location.y, size) })
        }
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement()
        .accessibilityLabel(vessel == .bottle ? "奶量" : "体温")
        .accessibilityValue(label(value))
        .accessibilityAdjustableAction { d in
            switch d {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }

    /// The part of the height that holds the fill: (top, bottom) in points.
    private func span(_ size: CGSize) -> (CGFloat, CGFloat) {
        let h: CGFloat = size.height
        switch vessel {
        case .bottle: return (h * 0.27, h - 8)
        case .thermometer: return (h * 0.06, h - size.width * 0.3 - 4)
        }
    }

    private func y(of v: Double, _ size: CGSize) -> CGFloat {
        let (top, bottom) = span(size)
        let f: CGFloat = CGFloat((v - range.lowerBound) / (range.upperBound - range.lowerBound))
        return bottom - (bottom - top) * f
    }

    private func set(_ py: CGFloat, _ size: CGSize) {
        let (top, bottom) = span(size)
        let f: Double = Double(min(1, max(0, (bottom - py) / (bottom - top))))
        let raw: Double = range.lowerBound + f * (range.upperBound - range.lowerBound)
        let snapped: Double = (raw / step).rounded() * step
        let v: Double = min(range.upperBound, max(range.lowerBound, snapped))
        if v != value { value = v }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let dark = lamp || scheme == .dark
        let glass = Color.white.opacity(dark ? 0.08 : 0.72)
        let rim = tint.mix(with: .black, by: dark ? 0 : 0.15).opacity(dark ? 0.6 : 0.55)
        let hot: Bool = alarm.map { value >= $0 } ?? false
        let fill: Color = hot ? Palette.danger : (vessel == .bottle ? liquid : tint)
        let level: CGFloat = y(of: value, size)
        let w: CGFloat = size.width, h: CGFloat = size.height
        let shell: Path
        switch vessel {
        case .bottle:
            let bw: CGFloat = w * 0.66
            let body = CGRect(x: (w - bw) / 2, y: h * 0.24, width: bw, height: h * 0.76 - 2)
            shell = Path(roundedRect: body, cornerRadius: bw * 0.26, style: .continuous)
            // the teat and the collar, above the glass
            let teat = Path(roundedRect: CGRect(x: w / 2 - bw * 0.17, y: h * 0.02, width: bw * 0.34, height: h * 0.15), cornerRadius: bw * 0.17, style: .continuous)
            ctx.fill(teat, with: .linearGradient(Gradient(colors: [Color(hex: 0xF8D8A8), Color(hex: 0xE9B477)]), startPoint: CGPoint(x: w / 2 - bw * 0.17, y: 0), endPoint: CGPoint(x: w / 2 + bw * 0.17, y: 0)))
            let collar = Path(roundedRect: CGRect(x: (w - bw * 1.08) / 2, y: h * 0.14, width: bw * 1.08, height: h * 0.11), cornerRadius: 8, style: .continuous)
            ctx.fill(collar, with: .linearGradient(Gradient(colors: [tint.mix(with: .white, by: 0.25), tint]), startPoint: CGPoint(x: 0, y: h * 0.14), endPoint: CGPoint(x: 0, y: h * 0.25)))
            ctx.fill(Path(roundedRect: CGRect(x: (w - bw * 1.08) / 2 + 6, y: h * 0.155, width: bw * 1.08 - 12, height: 3), cornerRadius: 1.5), with: .color(.white.opacity(0.45)))
        case .thermometer:
            let tw: CGFloat = w * 0.3
            let r: CGFloat = w * 0.3
            var p = Path(roundedRect: CGRect(x: (w - tw) / 2, y: h * 0.03, width: tw, height: h - r - h * 0.03), cornerRadius: tw / 2, style: .continuous)
            p.addEllipse(in: CGRect(x: w / 2 - r, y: h - 2 * r, width: 2 * r, height: 2 * r))
            shell = p
        }
        // a soft shadow on the page, then the glass
        var under = ctx
        under.addFilter(.shadow(color: Color(hex: 0x7A5230).opacity(dark ? 0 : 0.16), radius: 6, x: 0, y: 4))
        under.fill(shell, with: .color(glass))
        // the fill, up to the level
        var inner = ctx
        inner.clip(to: shell)
        let liquidRect = CGRect(x: 0, y: level, width: w, height: h - level)
        let shade: Color = fill.mix(with: .black, by: hot || vessel == .thermometer ? 0.12 : 0.06)
        inner.fill(Path(liquidRect), with: .linearGradient(Gradient(colors: [fill.mix(with: .white, by: 0.15), shade]), startPoint: CGPoint(x: w * 0.2, y: 0), endPoint: CGPoint(x: w * 0.85, y: 0)))
        if vessel == .bottle {
            // the surface of the milk, a little lighter
            inner.fill(Path(ellipseIn: CGRect(x: 0, y: level - 3, width: w, height: 6)), with: .color(.white.opacity(0.55)))
        }
        // the marks, inside the glass on the right
        for m in marks {
            let my: CGFloat = y(of: m, size)
            let x1: CGFloat = vessel == .bottle ? w * 0.5 + w * 0.33 - 4 : w / 2 + w * 0.15 - 1
            var line = Path(); line.move(to: CGPoint(x: x1 - (vessel == .bottle ? 12 : 7), y: my)); line.addLine(to: CGPoint(x: x1, y: my))
            inner.stroke(line, with: .color(rim.opacity(0.9)), lineWidth: 1.2)
        }
        // the glass catching the light: a long highlight down the left, the rim round it
        let hl = CGRect(x: vessel == .bottle ? w * 0.24 : w / 2 - w * 0.09, y: vessel == .bottle ? h * 0.3 : h * 0.07, width: vessel == .bottle ? 5 : 3.5, height: vessel == .bottle ? h * 0.52 : h * 0.6)
        inner.fill(Path(roundedRect: hl, cornerRadius: 3), with: .color(.white.opacity(dark ? 0.18 : 0.75)))
        ctx.stroke(shell, with: .color(rim), lineWidth: 1.5)
        // the labels of the marks, outside on the right (bottle) or left (thermometer)
        for m in marks {
            let my: CGFloat = y(of: m, size)
            let t = Text(label(m)).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(Palette.secondaryText)
            if vessel == .bottle {
                ctx.draw(t, at: CGPoint(x: w * 0.5 + w * 0.33 - 18, y: my), anchor: .trailing)
            } else {
                ctx.draw(t, at: CGPoint(x: w / 2 - w * 0.15 - 6, y: my), anchor: .trailing)
            }
        }
        // where the finger sets it: a small bead at the level
        let bx: CGFloat = vessel == .bottle ? w * 0.5 + w * 0.33 + 7 : w / 2 + w * 0.15 + 9
        let bead = CGRect(x: bx - 6, y: level - 6, width: 12, height: 12)
        ctx.fill(Path(ellipseIn: bead), with: .radialGradient(Gradient(colors: [Palette.beadLight, Palette.bead]), center: CGPoint(x: bead.minX + 4, y: bead.minY + 4), startRadius: 0, endRadius: 10))
    }
}

/// When it happened: now, a few minutes ago, an hour ago, or an exact time — the chosen one said in full above.
struct WhenChips: View {
    /// Minutes before the moment of saving; nil when an exact time was chosen.
    @Binding var ago: Int?
    @Binding var exact: Date
    let tint: Color
    @Environment(\.lamp) private var lamp
    @State private var picking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("时间").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                Spacer(minLength: 8)
                TimelineView(.periodic(from: .now, by: 30)) { tl in
                    Text(whenLabel(ago.map { tl.date.addingTimeInterval(-Double($0) * 60) } ?? exact))
                        .font(.headline).monospacedDigit().contentTransition(.numericText())
                }
            }
            WrapLayout(spacing: 8) {
                ForEach([0, 5, 10, 15, 30, 60], id: \.self) { m in
                    let on = ago == m
                    Button(m == 0 ? "现在" : m == 60 ? "1 小时前" : "\(m) 分钟前") { withAnimation(.snappy) { ago = m } }
                        .buttonStyle(.vinyl(on ? tint : Color(hex: 0x8A8279)))
                        .fontWeight(on ? .semibold : .regular).accessibilityAddTraits(on ? .isSelected : [])
                }
                Button(ago == nil ? "其他时间 ✓" : "其他时间…") { picking = true }
                    .buttonStyle(.vinyl(ago == nil ? tint : Color(hex: 0x8A8279)))
                    .fontWeight(ago == nil ? .semibold : .regular)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .printCard(radius: Radius.card, fill: lamp ? Palette.lampCard : Palette.card)
        .sensoryFeedback(.selection, trigger: ago)
        .sheet(isPresented: $picking) {
            TimeSheet(title: "时间", initial: ago.map { Date().addingTimeInterval(-Double($0) * 60) } ?? exact) { d in exact = d; withAnimation(.snappy) { ago = nil } }
                .lampPresented()
        }
    }
}

/// One large choice: the object (its 3D sticker when there is one), its name, and a mark when chosen.
struct ChoiceTile: View {
    let sticker: String?
    let symbol: String
    let title: String
    var detail: String? = nil
    let on: Bool
    let tint: Color
    var height: CGFloat = 112
    let action: () -> Void
    @Environment(\.lamp) private var lamp

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if let sticker, ArtIndex.shared.size[ArtStyle.resolve(sticker)] != nil {
                    Figure(name: sticker).frame(width: 66, height: 66).frame(width: 52, height: 52)
                } else {
                    IconTile(symbol: symbol, color: tint, size: 46, round: true)
                }
                Text(title).font(.headline)
                if let detail { Text(detail).font(.caption).foregroundStyle(Palette.secondaryText).monospacedDigit() }
            }
            .foregroundStyle(on ? Crayon.ink(tint) : Color.primary)
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.vertical, 8)
            .vinylSurface(on ? tint : Color(hex: 0xB9AFA4), radius: Radius.card)
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(on ? Crayon.ink(tint) : .clear, lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                if on {
                    Image(systemName: "checkmark.circle.fill").font(.title3).symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Crayon.ink(tint)).padding(8).transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.toy)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The instruments' fine adjustment: − and + either side, held down to repeat.
struct NudgeButtons: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let tint: Color
    var body: some View {
        HStack(spacing: 10) {
            nudge("minus", -step).accessibilityLabel("减少")
            nudge("plus", step).accessibilityLabel("增加")
        }
    }
    private func nudge(_ sym: String, _ d: Double) -> some View {
        Button { value = min(range.upperBound, max(range.lowerBound, ((value + d) / step).rounded() * step)) } label: {
            Image(systemName: sym).font(.title3.weight(.bold)).frame(width: 52, height: 44)
        }
        .buttonStyle(.vinyl(tint))
        .buttonRepeatBehavior(.enabled)
        .disabled(d < 0 ? value <= range.lowerBound : value >= range.upperBound)
    }
}
