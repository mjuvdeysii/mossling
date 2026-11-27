import SwiftUI

/// Codified Apple-HIG Design System tokens & primitives for Moss & Otto:
/// enforces disciplined opaque card surfaces, restrained semantic color accents,
/// clear 5-role typographic hierarchy, paired Primary/Secondary button weights,
/// unified segmented tracks, uniform tabular metric tiles, and 44pt+ ergonomics.
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

/// Visual/semantic button role enforcing one clear primary CTA per card or stage.
enum DSButtonRole {
    case primary
    case secondary
    case tinted(Color)
}

/// Unified Apple-HIG pill button style with strict Primary / Secondary / Tinted hierarchy
/// and guaranteed 44pt+ tap ergonomics.
struct DSButtonStyle: ButtonStyle {
    let role: DSButtonRole
    var fullWidth: Bool = false
    var height: CGFloat = LayoutSpec.ctaSecondaryHeight

    @Environment(\.isEnabled) private var enabled
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.accessibilityReduceMotion) private var reduce

    func makeBody(configuration: Configuration) -> some View {
        let dark = lamp || scheme == .dark
        let pressed = configuration.isPressed
        let hitH = max(LayoutSpec.hitMin, height)
        let visualH = max(34, height)

        let bg: Color = switch role {
        case .primary: Palette.accentFill
        case .secondary: DS.Surface.inset(dark: dark)
        case .tinted(let c): c.opacity(dark ? 0.22 : 0.13)
        }

        let fg: Color = switch role {
        case .primary: .white
        case .secondary: .primary
        case .tinted(let c): dark ? c.mix(with: .white, by: 0.25) : Crayon.ink(c)
        }

        let border: Color = switch role {
        case .primary: .clear
        case .secondary: DS.Surface.hairline(dark: dark)
        case .tinted(let c): c.opacity(dark ? 0.34 : 0.22)
        }

        let shadowColor: Color = switch role {
        case .primary: dark ? Color.black.opacity(0.32) : Palette.accentFill.opacity(0.24)
        case .secondary, .tinted: .clear
        }

        return configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, 16)
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
            .frame(minHeight: hitH)
            .contentShape(Rectangle())
            .opacity(enabled ? (pressed ? 0.82 : 1.0) : 0.45)
            .scaleEffect(!reduce && pressed ? 0.975 : 1.0)
            .animation(reduce ? nil : .spring(response: 0.22, dampingFraction: 0.65), value: pressed)
            .sensoryFeedback(.impact(weight: .light, intensity: 0.65), trigger: pressed) { _, new in new }
    }
}

extension ButtonStyle where Self == DSButtonStyle {
    static func ds(_ role: DSButtonRole, fullWidth: Bool = false, height: CGFloat = LayoutSpec.ctaSecondaryHeight) -> DSButtonStyle {
        DSButtonStyle(role: role, fullWidth: fullWidth, height: height)
    }
}

/// Shared visual pill chrome for `NavigationLink`, `Menu`, or `ShareLink` labels matching `DSButtonStyle`.
struct DSPillLabel: ViewModifier {
    let role: DSButtonRole
    var height: CGFloat = 36
    var horizontalPadding: CGFloat = 12
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp

    func body(content: Self.Content) -> some View {
        let dark = lamp || scheme == .dark
        let bg: Color = switch role {
        case .primary: Palette.accentFill
        case .secondary: DS.Surface.inset(dark: dark)
        case .tinted(let c): c.opacity(dark ? 0.22 : 0.13)
        }
        let fg: Color = switch role {
        case .primary: .white
        case .secondary: .primary
        case .tinted(let c): dark ? c.mix(with: .white, by: 0.25) : Crayon.ink(c)
        }
        let border: Color = switch role {
        case .primary: .clear
        case .secondary: DS.Surface.hairline(dark: dark)
        case .tinted(let c): c.opacity(dark ? 0.34 : 0.22)
        }

        return content
            .font(.footnote.weight(.semibold))
            .foregroundStyle(fg)
            .padding(.horizontal, horizontalPadding)
            .frame(minHeight: height)
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
    func dsPill(_ role: DSButtonRole, height: CGFloat = 36, horizontalPadding: CGFloat = 12) -> some View {
        modifier(DSPillLabel(role: role, height: height, horizontalPadding: horizontalPadding))
    }
}

/// Apple-HIG segmented control with sliding opaque thumb on a neutral inset track,
/// automatically reflowing cleanly with `FlowRow` at Accessibility text sizes.
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
        let visualTrackH: CGFloat = compact ? 36 : 42
        let thumbH: CGFloat = visualTrackH - 6
        let corner: CGFloat = compact ? 999 : Radius.tile
        let trackFill: Color = darkSurface ? Color.white.opacity(0.09) : DS.Surface.inset(dark: dark)
        let activeFill: Color = darkSurface ? Palette.amber : (dark ? Palette.lampCard : .white)
        let activeInk: Color = darkSurface ? Color(hex: 0x261700) : .primary
        let inactiveInk: Color = darkSurface ? Palette.lampInk.opacity(0.76) : Palette.secondaryText

        if type.isAccessibilitySize {
            FlowRow(spacing: 6, lineSpacing: 6) {
                ForEach(items) { item in
                    let on = selection == item
                    Button {
                        selectItem(item)
                    } label: {
                        segmentLabel(item, on: on, activeInk: on ? .white : activeInk, inactiveInk: inactiveInk)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule(style: .continuous).fill(on ? Palette.accentFill : trackFill))
                            .pillHitTarget(LayoutSpec.hitMin)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        } else {
            HStack(spacing: 2) {
                ForEach(items) { item in
                    let on = selection == item
                    Button {
                        selectItem(item)
                    } label: {
                        segmentLabel(item, on: on, activeInk: activeInk, inactiveInk: inactiveInk)
                            .padding(.horizontal, compact ? 10 : 6)
                            .frame(maxWidth: compact ? nil : .infinity, minHeight: thumbH)
                            .background {
                                if on {
                                    RoundedRectangle(cornerRadius: compact ? 999 : max(8, corner - 3), style: .continuous)
                                        .fill(activeFill)
                                        .shadow(color: .black.opacity(dark || darkSurface ? 0.28 : 0.08), radius: 3, y: 1)
                                        .matchedGeometryEffect(id: "dsSegThumb", in: segNS)
                                }
                            }
                            .frame(minHeight: LayoutSpec.hitMin)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.horizontal, 3)
            .background {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(trackFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .strokeBorder(darkSurface ? Color.white.opacity(0.08) : DS.Surface.hairline(dark: dark), lineWidth: 0.5)
                    )
            }
        }
    }

    private func selectItem(_ item: Item) {
        TactileEngine.shared.beadClick()
        withAnimation(reduce ? nil : .spring(response: 0.30, dampingFraction: 0.82)) {
            selection = item
        }
        onSelect?(item)
    }

    private func segmentLabel(_ item: Item, on: Bool, activeInk: Color, inactiveInk: Color) -> some View {
        HStack(spacing: 4) {
            if let dot = dotColor?(item) {
                Circle()
                    .fill(dot)
                    .frame(width: 6, height: 6)
            }
            if let sym = symbol?(item) {
                Image(systemName: sym)
                    .font(Typeface.label(11, relativeTo: .caption2, weight: .semibold))
            }
            Text(title(item))
                .font((compact ? Font.caption : Font.footnote).weight(on ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .foregroundStyle(on ? activeInk : inactiveInk)
    }
}

/// Uniform Apple Health style editorial metric cell replacing wrapped multi-color stat capsules.
struct DSMetricCell: View {
    let label: String
    let value: String
    var unit: String = ""
    var accent: Color? = nil
    var dark: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                if let accent {
                    Circle()
                        .fill(accent)
                        .frame(width: 6, height: 6)
                }
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.84)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(Typeface.numerals(18, relativeTo: .headline, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption.weight(.medium))
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
                .fill(DS.Surface.inset(dark: dark))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .strokeBorder(DS.Surface.hairline(dark: dark), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Circular compact icon button visually sized to `visualSize` while strictly maintaining a `44x44pt` Apple HIG tap region.
struct DSIconButton: View {
    let symbol: String
    let accessibilityLabel: String
    var visualSize: CGFloat = 34
    var dark: Bool = false
    var tint: Color = Palette.secondaryText
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: visualSize, height: visualSize)
                .background(Circle().fill(DS.Surface.inset(dark: dark)))
                .overlay(Circle().strokeBorder(DS.Surface.hairline(dark: dark), lineWidth: 0.5))
                .hitTarget(LayoutSpec.hitMin)
        }
        .buttonStyle(.toy)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Uniform single-style filter pill with calm neutral inactive state, accent active state, and 44pt tap height.
struct DSFilterChip: View {
    let title: String
    let selected: Bool
    var dark: Bool = false
    var symbol: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(Typeface.label(11, relativeTo: .caption2, weight: .semibold))
                }
                Text(title)
                    .font(.footnote.weight(selected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(selected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule(style: .continuous).fill(selected ? Palette.accentFill : DS.Surface.inset(dark: dark)))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(selected ? .clear : DS.Surface.hairline(dark: dark), lineWidth: 0.5)
            )
            .pillHitTarget(LayoutSpec.hitMin)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
