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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            FluidGaugeCanvas(
                vessel: vessel,
                animatedValue: value,
                range: range,
                marks: marks,
                label: label,
                tint: tint,
                alarm: alarm,
                liquid: liquid,
                dark: lamp || scheme == .dark
            )
            .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.80), value: value)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in set(g.location.y, size) }
            )
        }
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement()
        .accessibilityLabel(vessel == .bottle ? L10n.t("奶量", "Volume") : L10n.t("体温", "Temperature"))
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
    static func span(_ vessel: Vessel, _ size: CGSize) -> (CGFloat, CGFloat) {
        let h: CGFloat = size.height
        switch vessel {
        case .bottle: return (h * 0.27, h - 8)
        case .thermometer: return (h * 0.06, h - size.width * 0.3 - 4)
        }
    }

    private func set(_ py: CGFloat, _ size: CGSize) {
        let (top, bottom) = Self.span(vessel, size)
        let f: Double = Double(min(1, max(0, (bottom - py) / (bottom - top))))
        let raw: Double = range.lowerBound + f * (range.upperBound - range.lowerBound)
        let snapped: Double = (raw / step).rounded() * step
        let v: Double = min(range.upperBound, max(range.lowerBound, snapped))
        if v != value { value = v }
    }
}

/// Animatable Canvas wrapper so preset chips, nudge taps, and drags smoothly animate the liquid meniscus & mercury column.
private struct FluidGaugeCanvas: View, Animatable {
    let vessel: LevelGauge.Vessel
    var animatedValue: Double
    let range: ClosedRange<Double>
    let marks: [Double]
    let label: (Double) -> String
    let tint: Color
    let alarm: Double?
    let liquid: Color
    let dark: Bool

    var animatableData: Double {
        get { animatedValue }
        set { animatedValue = newValue }
    }

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            draw(&ctx, size)
        }
    }

    private func y(of v: Double, _ size: CGSize) -> CGFloat {
        let (top, bottom) = LevelGauge.span(vessel, size)
        let clamped = min(range.upperBound, max(range.lowerBound, v))
        let f: CGFloat = CGFloat((clamped - range.lowerBound) / (range.upperBound - range.lowerBound))
        return bottom - (bottom - top) * f
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let glass = Color.white.opacity(dark ? 0.08 : 0.72)
        let rim = tint.mix(with: .black, by: dark ? 0 : 0.15).opacity(dark ? 0.62 : 0.55)
        let hot: Bool = alarm.map { animatedValue >= $0 - 0.05 } ?? false
        let warm: Bool = vessel == .thermometer && animatedValue >= 37.45 && !hot
        let fill: Color = hot ? Palette.danger : (warm ? Crayon.tangerine : (vessel == .bottle ? liquid : tint))
        let level: CGFloat = y(of: animatedValue, size)
        let w: CGFloat = size.width, h: CGFloat = size.height
        let shell: Path

        switch vessel {
        case .bottle:
            let bw: CGFloat = w * 0.66
            let body = CGRect(x: (w - bw) / 2, y: h * 0.24, width: bw, height: h * 0.76 - 2)
            shell = Path(roundedRect: body, cornerRadius: bw * 0.26, style: .continuous)
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

        // Fever bulb glow behind the glass shell when temperature crosses threshold
        if hot, vessel == .thermometer {
            let r: CGFloat = w * 0.34
            let bulbCenter = CGPoint(x: w / 2, y: h - w * 0.3)
            ctx.fill(
                Path(ellipseIn: CGRect(x: bulbCenter.x - r * 1.45, y: bulbCenter.y - r * 1.45, width: r * 2.9, height: r * 2.9)),
                with: .radialGradient(Gradient(colors: [Palette.danger.opacity(dark ? 0.36 : 0.24), .clear]), center: bulbCenter, startRadius: r * 0.3, endRadius: r * 1.45)
            )
        }

        // Soft shadow on the page, then the glass
        var under = ctx
        under.addFilter(.shadow(color: Color(hex: 0x7A5230).opacity(dark ? 0 : 0.16), radius: 6, x: 0, y: 4))
        under.fill(shell, with: .color(glass))

        var inner = ctx
        inner.clip(to: shell)

        // Subtle thermal reference zones along the thermometer channel
        if vessel == .thermometer {
            let feverY = y(of: 38.0, size)
            let warmY = y(of: 37.5, size)
            let normalLowY = y(of: 36.0, size)
            inner.fill(
                Path(CGRect(x: 0, y: 0, width: w, height: feverY)),
                with: .color(Palette.danger.opacity(dark ? 0.14 : 0.09))
            )
            inner.fill(
                Path(CGRect(x: 0, y: feverY, width: w, height: max(0, warmY - feverY))),
                with: .color(Crayon.tangerine.opacity(dark ? 0.13 : 0.09))
            )
            inner.fill(
                Path(CGRect(x: 0, y: warmY, width: w, height: max(0, normalLowY - warmY))),
                with: .color(Crayon.leaf.opacity(dark ? 0.10 : 0.07))
            )
        }

        // Liquid or mercury fill up to the animated level
        let liquidRect = CGRect(x: 0, y: level, width: w, height: h - level)
        let shade: Color = fill.mix(with: .black, by: hot || vessel == .thermometer ? 0.14 : 0.06)
        inner.fill(
            Path(liquidRect),
            with: .linearGradient(
                Gradient(colors: [fill.mix(with: .white, by: 0.18), shade]),
                startPoint: CGPoint(x: w * 0.2, y: 0),
                endPoint: CGPoint(x: w * 0.85, y: 0)
            )
        )
        if vessel == .bottle {
            // Curved milk meniscus rim
            inner.fill(Path(ellipseIn: CGRect(x: w * 0.14, y: level - 3.5, width: w * 0.72, height: 7)), with: .color(.white.opacity(dark ? 0.38 : 0.68)))
        } else {
            // Crisp mercury meniscus cap
            inner.fill(Path(CGRect(x: 0, y: level - 1, width: w, height: 2.5)), with: .color(.white.opacity(0.45)))
        }

        // Graduation ticks inside the glass on the right
        for m in marks {
            let my: CGFloat = y(of: m, size)
            let near = abs(my - level) < 6
            let x1: CGFloat = vessel == .bottle ? w * 0.5 + w * 0.33 - 4 : w / 2 + w * 0.15 - 1
            var line = Path()
            line.move(to: CGPoint(x: x1 - (vessel == .bottle ? 12 : 7), y: my))
            line.addLine(to: CGPoint(x: x1, y: my))
            let tickColor = (vessel == .thermometer && m >= 38) ? Palette.danger.opacity(0.92) : (near ? Palette.bead : rim.opacity(0.9))
            inner.stroke(line, with: .color(tickColor), lineWidth: near ? 2.0 : 1.2)
        }

        // Specular glass highlight down the left & crisp rim stroke
        let hl = CGRect(x: vessel == .bottle ? w * 0.24 : w / 2 - w * 0.09, y: vessel == .bottle ? h * 0.3 : h * 0.07, width: vessel == .bottle ? 5 : 3.5, height: vessel == .bottle ? h * 0.52 : h * 0.6)
        inner.fill(Path(roundedRect: hl, cornerRadius: 3), with: .color(.white.opacity(dark ? 0.18 : 0.75)))
        ctx.stroke(shell, with: .color(hot ? Palette.danger.opacity(0.75) : rim), lineWidth: 1.5)

        // Mark labels
        let labelColor = dark ? Palette.lampInk.opacity(0.68) : Palette.secondaryText
        for m in marks {
            let my: CGFloat = y(of: m, size)
            let isAlarmMark = vessel == .thermometer && m == 38
            let overMilk = vessel == .bottle && dark && my >= level
            let markInk: Color = isAlarmMark ? Palette.danger : (overMilk ? Color(hex: 0x36281A) : labelColor)
            let t = Text(label(m))
                .font(.system(size: 10, weight: isAlarmMark ? .bold : .semibold, design: .rounded))
                .foregroundStyle(markInk)
            if vessel == .bottle {
                ctx.draw(t, at: CGPoint(x: w * 0.5 + w * 0.33 - 18, y: my), anchor: .trailing)
            } else {
                ctx.draw(t, at: CGPoint(x: w / 2 - w * 0.15 - 6, y: my), anchor: .trailing)
            }
        }

        // Tactile bead thumb-pointer aligned to the level
        let bx: CGFloat = vessel == .bottle ? w * 0.5 + w * 0.33 + 7 : w / 2 + w * 0.15 + 9
        let bead = CGRect(x: bx - 6.5, y: level - 6.5, width: 13, height: 13)
        ctx.fill(
            Path(ellipseIn: bead.insetBy(dx: -3, dy: -3)),
            with: .color((hot ? Palette.danger : Palette.bead).opacity(0.20))
        )
        ctx.fill(
            Path(ellipseIn: bead),
            with: .radialGradient(
                Gradient(colors: [Palette.beadLight, hot ? Palette.danger : Palette.bead]),
                center: CGPoint(x: bead.minX + 4, y: bead.minY + 4),
                startRadius: 0,
                endRadius: 10
            )
        )
        ctx.stroke(Path(ellipseIn: bead), with: .color(.white.opacity(0.75)), lineWidth: 1)
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
                Text(L10n.t("时间", "Time")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                Spacer(minLength: 8)
                TimelineView(.periodic(from: .now, by: 30)) { tl in
                    Text(whenLabel(ago.map { tl.date.addingTimeInterval(-Double($0) * 60) } ?? exact))
                        .font(.headline).monospacedDigit().contentTransition(.numericText())
                }
            }
            WrapLayout(spacing: 8) {
                ForEach([0, 5, 10, 15, 30, 60], id: \.self) { m in
                    let on = ago == m
                    Button(m == 0 ? L10n.t("现在", "Now") : m == 60 ? L10n.t("1 小时前", "1 hr ago") : L10n.t("\(m) 分钟前", "\(m) min ago")) { withAnimation(.snappy) { ago = m } }
                        .buttonStyle(.vinyl(on ? tint : Crayon.pebble))
                        .fontWeight(on ? .semibold : .regular).accessibilityAddTraits(on ? .isSelected : [])
                }
                Button { picking = true } label: {
                    if ago == nil {
                        Label(L10n.t("其他时间", "Other"), systemImage: "checkmark")
                    } else {
                        Text(L10n.t("其他时间…", "Other…"))
                    }
                }
                .buttonStyle(.vinyl(ago == nil ? tint : Crayon.pebble))
                .fontWeight(ago == nil ? .semibold : .regular)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .printCard(radius: Radius.card, fill: lamp ? Palette.lampCard : Palette.card)
        .sensoryFeedback(.selection, trigger: ago)
        .sheet(isPresented: $picking) {
            TimeSheet(title: L10n.t("时间", "Time"), initial: ago.map { Date().addingTimeInterval(-Double($0) * 60) } ?? exact) { d in exact = d; withAnimation(.snappy) { ago = nil } }
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
                Text(title).font(.headline).lineLimit(1).minimumScaleFactor(0.8)
                if let detail { Text(detail).font(.caption).foregroundStyle(Palette.secondaryText).monospacedDigit() }
            }
            .foregroundStyle(on ? Crayon.ink(tint) : Color.primary)
            .frame(maxWidth: .infinity, minHeight: height)
            .padding(.vertical, 8)
            .vinylSurface(on ? tint : Color(hex: 0xB9AFA4), radius: Radius.card)
            .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(on ? Crayon.ink(tint) : .clear, lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                if on {
                    Image(systemName: "checkmark.circle.fill").font(.title3).symbolRenderingMode(.palette)
                        .foregroundStyle(.white, Crayon.ink(tint)).padding(8).transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
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
            nudge("minus", -step).accessibilityLabel(L10n.t("减少", "Decrease"))
            nudge("plus", step).accessibilityLabel(L10n.t("增加", "Increase"))
        }
    }
    private func nudge(_ sym: String, _ d: Double) -> some View {
        Button {
            TactileEngine.shared.beadClick()
            value = min(range.upperBound, max(range.lowerBound, ((value + d) / step).rounded() * step))
        } label: {
            Image(systemName: sym).font(.title3.weight(.bold)).frame(width: 52, height: 44)
        }
        .buttonStyle(.vinyl(tint))
        .buttonRepeatBehavior(.enabled)
        .disabled(d < 0 ? value <= range.lowerBound : value >= range.upperBound)
    }
}
