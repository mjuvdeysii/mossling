import SwiftUI

/// Codified Apple-HIG Design System tokens & primitives for Moss & Otto:
/// pairs warm storybook craft (sunlit paper, botanical washes, golden beads) with strict
/// proportional typography, zero-truncation pills, balanced CTA hierarchy, and 44pt+ touch zones.
enum DS {
    enum Surface {
        static func page(dark: Bool) -> Color {
            dark ? Palette.lampPage : Palette.background
        }

        static func card(dark: Bool) -> Color {
            dark ? Palette.lampCard : Palette.card
        }

        static func inset(dark: Bool) -> Color {
            dark ? Color.white.opacity(0.08) : Palette.fill.opacity(0.75)
        }

        static func warmInset(dark: Bool) -> Color {
            dark ? Color.white.opacity(0.09) : Color(hex: 0xF3EDE2)
        }

        static func hairline(dark: Bool) -> Color {
            dark ? Color.white.opacity(0.09) : Color.black.opacity(0.06)
        }
    }

    enum Spacing {
        static let pageH: CGFloat = LayoutSpec.pageH
        static let sectionGap: CGFloat = LayoutSpec.sectionGap
        static let cardGap: CGFloat = 16
        static let gridGap: CGFloat = 12
        static let cardPad: CGFloat = LayoutSpec.cardPad
        static let cardPadHero: CGFloat = LayoutSpec.cardPadHero
        static let innerPad: CGFloat = 14
        static let controlGap: CGFloat = 10
    }

    enum TypeScale {
        static let sectionHeader: Font = .title3.weight(.bold)
        static let cardTitle: Font = .headline.weight(.semibold)
        static let rowTitle: Font = .subheadline.weight(.semibold)
        static let body: Font = .subheadline
        static let meta: Font = .footnote
        static let micro: Font = Typeface.label(11, relativeTo: .caption2, weight: .medium)
    }
}

/// Visual/semantic button role enforcing clear hierarchy and warm storybook color.
enum DSButtonRole {
    case primary
    case secondary
    case tinted(Color)
    case warm(Color)
}

/// Unified Apple-HIG pill button style with proportional typography (16pt/15pt/13pt scaled to height),
/// zero forced wrapping, warm storybook fills, and invisible 44pt+ tap region expansion.
struct DSButtonStyle: ButtonStyle {
    let role: DSButtonRole
    var fullWidth: Bool = false
    var height: CGFloat = LayoutSpec.ctaSecondaryHeight

    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.dynamicTypeSize) private var type

    func makeBody(configuration: Configuration) -> some View {
        let dark = lamp || scheme == .dark
        let pressed = configuration.isPressed
        let visualH = max(32, height)
        let hitExpand = max(0, (LayoutSpec.hitMin - visualH) / 2)
        let labelFont: Font = visualH >= 48
            ? .callout.weight(.semibold)
            : (visualH >= 36 ? .subheadline.weight(.semibold) : .footnote.weight(.semibold))

        let bg: Color = switch role {
        case .primary: Palette.accentFill
        case .secondary: DS.Surface.warmInset(dark: dark)
        case .tinted(let c): c.opacity(dark ? 0.24 : 0.14)
        case .warm(let c): Crayon.fill(c, dark)
        }

        let fg: Color = switch role {
        case .primary, .warm: .white
        case .secondary: .primary
        case .tinted(let c): dark ? c.mix(with: .white, by: 0.28) : Crayon.ink(c)
        }

        let border: Color = switch role {
        case .primary, .warm: .clear
        case .secondary: Color(hex: 0xCBB799).opacity(dark ? 0.18 : 0.28)
        case .tinted(let c): c.opacity(dark ? 0.36 : 0.24)
        }

        let shadowColor: Color = switch role {
        case .primary: dark ? Color.black.opacity(0.32) : Palette.accentFill.opacity(0.24)
        case .warm(let c): dark ? Color.black.opacity(0.30) : c.opacity(0.26)
        case .secondary, .tinted: .clear
        }

        return configuration.label
            .font(labelFont)
            .lineLimit(type.isAccessibilitySize ? 2 : 1)
            .minimumScaleFactor(0.86)
            .fixedSize(horizontal: !fullWidth && !type.isAccessibilitySize, vertical: type.isAccessibilitySize)
            .foregroundStyle(fg)
            .padding(.horizontal, visualH >= 46 ? 18 : 14)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: visualH)
            .background {
                Capsule(style: .continuous)
                    .fill(bg)
                    .shadow(color: shadowColor, radius: pressed ? 2 : 6, y: pressed ? 1 : 2)
            }
            .overlay {
                if border != .clear {
                    Capsule(style: .continuous)
                        .strokeBorder(border, lineWidth: 0.6)
                }
            }
            .contentShape(Capsule(style: .continuous).inset(by: -hitExpand))
            .opacity(enabled ? (pressed ? 0.84 : 1.0) : 0.45)
            .scaleEffect(!reduce && pressed ? 0.975 : 1.0)
            .animation(reduce ? nil : .spring(response: 0.22, dampingFraction: 0.65), value: pressed)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.65), trigger: pressed) { _, new in new && !TactileEngine.shared.quietNight }
    }
}

extension ButtonStyle where Self == DSButtonStyle {
    static func ds(_ role: DSButtonRole, fullWidth: Bool = false, height: CGFloat = LayoutSpec.ctaSecondaryHeight) -> DSButtonStyle {
        DSButtonStyle(role: role, fullWidth: fullWidth, height: height)
    }
}

/// Shared visual pill chrome for `NavigationLink`, `Menu`, or `ShareLink` labels:
/// enforces single-line non-wrapping text, tailored height, and invisible touch expansion.
struct DSPillLabel: ViewModifier {
    let role: DSButtonRole
    var height: CGFloat = 32
    var horizontalPadding: CGFloat = 12
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.dynamicTypeSize) private var type

    func body(content: Self.Content) -> some View {
        let dark = lamp || scheme == .dark
        let visualH = max(30, height)
        let labelFont: Font = visualH >= 36 ? .subheadline.weight(.semibold) : .footnote.weight(.semibold)

        let bg: Color = switch role {
        case .primary: Palette.accentFill
        case .secondary: DS.Surface.warmInset(dark: dark)
        case .tinted(let c): c.opacity(dark ? 0.24 : 0.14)
        case .warm(let c): Crayon.fill(c, dark)
        }
        let fg: Color = switch role {
        case .primary, .warm: .white
        case .secondary: .primary
        case .tinted(let c): dark ? c.mix(with: .white, by: 0.28) : Crayon.ink(c)
        }
        let border: Color = switch role {
        case .primary, .warm: .clear
        case .secondary: Color(hex: 0xCBB799).opacity(dark ? 0.18 : 0.28)
        case .tinted(let c): c.opacity(dark ? 0.36 : 0.24)
        }

        return content
            .font(labelFont)
            .lineLimit(type.isAccessibilitySize ? 2 : 1)
            .minimumScaleFactor(0.86)
            .fixedSize(horizontal: !type.isAccessibilitySize, vertical: type.isAccessibilitySize)
            .foregroundStyle(fg)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: visualH)
            .background(Capsule(style: .continuous).fill(bg))
            .overlay {
                if border != .clear {
                    Capsule(style: .continuous).strokeBorder(border, lineWidth: 0.6)
                }
            }
            .pillHitTarget(LayoutSpec.hitMin)
    }
}

extension View {
    func dsPill(_ role: DSButtonRole, height: CGFloat = 32, horizontalPadding: CGFloat = 12) -> some View {
        modifier(DSPillLabel(role: role, height: height, horizontalPadding: horizontalPadding))
    }
}

/// Brand-tinted segmented control with crisp sliding pill thumb over a warm tray track,
/// tailored `36–40pt` height, proportional `13–15pt` text, zero truncation on compact labels, and AX `FlowRow` reflow.
struct DSSegmentedControl<Item: Identifiable & Equatable>: View {
    let items: [Item]
    @Binding var selection: Item
    let dark: Bool
    var compact: Bool = false
    var darkSurface: Bool = false
    let title: (Item) -> String
    var symbol: ((Item) -> String?)? = nil
    var dotColor: ((Item) -> Color?)? = nil
    var onSelect: ((Item) -> Void)? = nil

    @Namespace private var segNS
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        let thumbH: CGFloat = compact ? 34 : 36
        let corner: CGFloat = compact ? 999 : Radius.tile
        let trackFill: Color = darkSurface ? Color.white.opacity(0.09) : DS.Surface.warmInset(dark: dark)
        let activeFill: Color = darkSurface ? Palette.amber : Palette.accentFill
        let activeInk: Color = darkSurface ? Color(hex: 0x261700) : .white
        let inactiveInk: Color = darkSurface ? Palette.lampInk.opacity(0.80) : .primary

        if type.isAccessibilitySize {
            pillsFlow(activeFill: activeFill, trackFill: trackFill, activeInk: activeInk, inactiveInk: inactiveInk)
        } else if compact {
            ViewThatFits(in: .horizontal) {
                horizontalTrack(thumbH: thumbH, corner: corner, trackFill: trackFill, activeFill: activeFill, activeInk: activeInk, inactiveInk: inactiveInk)
                pillsFlow(activeFill: activeFill, trackFill: trackFill, activeInk: activeInk, inactiveInk: inactiveInk)
            }
        } else {
            horizontalTrack(thumbH: thumbH, corner: corner, trackFill: trackFill, activeFill: activeFill, activeInk: activeInk, inactiveInk: inactiveInk)
        }
    }

    private func pillsFlow(activeFill: Color, trackFill: Color, activeInk: Color, inactiveInk: Color) -> some View {
        FlowRow(spacing: 6, lineSpacing: 6) {
            ForEach(items) { item in
                let on = selection == item
                Button {
                    selectItem(item)
                } label: {
                    segmentLabel(item, on: on, activeInk: activeInk, inactiveInk: inactiveInk, fixedHoriz: true)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule(style: .continuous).fill(on ? activeFill : trackFill))
                        .pillHitTarget(LayoutSpec.hitMin)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private func horizontalTrack(thumbH: CGFloat, corner: CGFloat, trackFill: Color, activeFill: Color, activeInk: Color, inactiveInk: Color) -> some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                let on = selection == item
                Button {
                    selectItem(item)
                } label: {
                    segmentLabel(item, on: on, activeInk: activeInk, inactiveInk: inactiveInk, fixedHoriz: compact)
                        .padding(.horizontal, compact ? 11 : 8)
                        .frame(maxWidth: compact ? nil : .infinity, minHeight: thumbH)
                        .background {
                            if on {
                                RoundedRectangle(cornerRadius: compact ? 999 : max(9, corner - 3), style: .continuous)
                                    .fill(activeFill)
                                    .shadow(color: (darkSurface ? Color.black : Palette.accentFill).opacity(0.22), radius: 3, y: 1)
                                    .matchedGeometryEffect(id: "dsSegThumb", in: segNS)
                            }
                        }
                        .contentShape(Rectangle().inset(by: -4))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(trackFill)
                .overlay(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .strokeBorder(darkSurface ? Color.white.opacity(0.08) : Color(hex: 0xCBB799).opacity(dark ? 0.16 : 0.24), lineWidth: 0.5)
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous).inset(by: -4))
    }

    private func selectItem(_ item: Item) {
        TactileEngine.shared.beadClick()
        withAnimation(reduce ? nil : .spring(response: 0.30, dampingFraction: 0.82)) {
            selection = item
        }
        onSelect?(item)
    }

    private func segmentLabel(_ item: Item, on: Bool, activeInk: Color, inactiveInk: Color, fixedHoriz: Bool) -> some View {
        HStack(spacing: 4) {
            if let dot = dotColor?(item) {
                Circle()
                    .fill(on ? activeInk.opacity(0.92) : dot)
                    .frame(width: 6, height: 6)
            }
            if let sym = symbol?(item) {
                Image(systemName: sym)
                    .font(Typeface.label(compact ? 11 : 12, relativeTo: .caption, weight: .semibold))
            }
            Text(title(item))
                .font((compact ? Font.footnote : Font.subheadline).weight(on ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(fixedHoriz ? 1.0 : 0.86)
                .fixedSize(horizontal: fixedHoriz, vertical: false)
        }
        .foregroundStyle(on ? activeInk : inactiveInk)
    }
}

/// Uniform warm-tinted metric cell replacing wrapped multi-color pill soup across summary views.
struct DSMetricCell: View {
    let label: String
    let value: String
    var unit: String = ""
    var accent: Color? = nil
    var dark: Bool = false

    var body: some View {
        let fillColor = accent.map { $0.opacity(dark ? 0.18 : 0.10) } ?? DS.Surface.warmInset(dark: dark)
        let strokeColor = accent.map { $0.opacity(dark ? 0.30 : 0.22) } ?? DS.Surface.hairline(dark: dark)
        let labelInk: Color = accent.map { dark ? $0.mix(with: .white, by: 0.24) : Crayon.ink($0) } ?? Palette.secondaryText

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if let accent {
                    Circle()
                        .fill(accent)
                        .frame(width: 7, height: 7)
                }
                Text(label)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(labelInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(Typeface.numerals(20, relativeTo: .title3, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .fill(fillColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .strokeBorder(strokeColor, lineWidth: 0.6)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Circular compact icon button visually sized to `visualSize` with warm optional tint and invisible 44pt tap expansion.
struct DSIconButton: View {
    let symbol: String
    let accessibilityLabel: String
    var visualSize: CGFloat = 34
    var dark: Bool = false
    var tint: Color = Palette.secondaryText
    var tintBg: Color? = nil
    let action: () -> Void

    var body: some View {
        let expand = max(0, (LayoutSpec.hitMin - visualSize) / 2)
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: visualSize, height: visualSize)
                .background(Circle().fill(tintBg ?? DS.Surface.warmInset(dark: dark)))
                .overlay(Circle().strokeBorder(DS.Surface.hairline(dark: dark), lineWidth: 0.5))
                .contentShape(Circle().inset(by: -expand))
        }
        .buttonStyle(.toy)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Uniform filter pill with warm neutral inactive state, vibrant accent active state, and zero wrapping/truncation.
struct DSFilterChip: View {
    let title: String
    let selected: Bool
    var dark: Bool = false
    var symbol: String? = nil
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var type

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(Typeface.label(11, relativeTo: .caption2, weight: .semibold))
                }
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(type.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.86)
                    .fixedSize(horizontal: !type.isAccessibilitySize, vertical: type.isAccessibilitySize)
            }
            .foregroundStyle(selected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(selected ? Palette.accentFill : DS.Surface.warmInset(dark: dark)))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(selected ? .clear : Color(hex: 0xCBB799).opacity(dark ? 0.16 : 0.24), lineWidth: 0.5)
            )
            .pillHitTarget(LayoutSpec.hitMin)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
