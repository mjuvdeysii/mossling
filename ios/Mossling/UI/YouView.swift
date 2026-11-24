import SwiftUI
import LocalAuthentication

/// Concise visual-first tags for companions on `YouView`.
enum YouStudioCopy {
    static func companionBadge(_ kind: Kind) -> String {
        switch kind {
        case .moss: L10n.t("爱探索", "Explorer")
        case .otto: L10n.t("点暖灯", "Lamp Keeper")
        }
    }
}

/// Unified crisp circular vector icon badge across `YouView` (replaces mixed 3D/flat icon styles).
private struct StudioBadge: View {
    let symbol: String
    let color: Color
    var active: Bool = true
    var dark: Bool = false
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(active ? (dark ? 0.28 : 0.16) : (dark ? 0.12 : 0.09)))
                .overlay(
                    Circle()
                        .strokeBorder(color.opacity(active ? 0.42 : 0.20), lineWidth: 0.85)
                )
            Image(systemName: symbol)
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundStyle(active ? (dark ? color : Crayon.ink(color)) : Palette.secondaryText)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Me: Family Studio card, visual Growth Book keepsake vault, full-width living Appearance & Language deck,
/// tactile 2×2 visual control tiles, and compact Local Data / About dock.
struct YouView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.dynamicTypeSize) private var type
    @Binding var path: NavigationPath
    @State private var editing = false
    @State private var message: String?

    var body: some View {
        @Bindable var app = app
        let dark = lamp || scheme == .dark
        let face = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) || app.lock

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                FamilyCard { if app.mayKeep() { editing = true } }

                if app.birth != nil { GrowthBookCard() }

                ThemeLanguageCard(dark: dark)

                PreferenceStudioCard(app: app, face: face, dark: dark)

                FooterStudioDock(dark: dark)
            }
            .padding(.top, 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.lilac)
        .navigationTitle(L10n.t("我的", "Me"))
        .sheet(isPresented: $editing) { ProfileSheet() }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button(L10n.t("好", "OK")) {} }
    }
}

/// Visual-first Family Studio header: portrait halo, baby age, concise land/day badges, and compact companion stage cards.
private struct FamilyCard: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var night
    let edit: () -> Void
    @State private var giggles = 0

    var body: some View {
        let dark = night || scheme == .dark
        let baby = app.babyMonth ?? 0

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                BabyPortrait(month: baby, sex: app.sex, giggle: giggles)
                    .frame(width: type.isAccessibilitySize ? 78 : 88, height: type.isAccessibilitySize ? 78 : 88)
                    .contentShape(Circle())
                    .onTapGesture { giggles += 1 }
                    .sensoryFeedback(.impact(weight: .light), trigger: giggles)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .center, spacing: 6) {
                        Text(app.nickname.isEmpty ? L10n.t("宝宝", "Baby") : app.nickname)
                            .font(.title3.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        Button(action: edit) {
                            Label(L10n.t("编辑", "Edit"), systemImage: "pencil")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Palette.accentFill))
                                .contentShape(Capsule().inset(by: -8))
                        }
                        .buttonStyle(.toy)
                        .accessibilityLabel(L10n.t("编辑宝宝信息", "Edit baby profile"))
                    }

                    if let a = app.age {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Ticking(text: "\(a.months)").font(Typeface.numerals(24, relativeTo: .title2, weight: .bold))
                            Text(L10n.t("个月", "m")).font(.subheadline.weight(.semibold)).fixedSize()
                            if a.days > 0 {
                                Ticking(text: "\(a.days)").font(Typeface.numerals(18, relativeTo: .headline, weight: .bold)).padding(.leading, 4)
                                Text(L10n.t("天", "d")).font(.subheadline.weight(.semibold)).fixedSize()
                            }
                        }
                        .fixedSize()
                        .foregroundStyle(Palette.accent)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(L10n.ageText(a))
                        .accessibilityAddTraits(.isStaticText)
                    }

                    if !type.isAccessibilitySize {
                        conciseBadges(baby: baby, dark: dark)
                    }
                }
            }

            if type.isAccessibilitySize {
                conciseBadges(baby: baby, dark: dark)
            }

            Divider().opacity(0.45)

            CompanionPicker()
        }
        .padding(14)
        .printCard(radius: Radius.card)
    }

    private func conciseBadges(baby: Int, dark: Bool) -> some View {
        let land = Land.of(baby)
        let stretch = L10n.stretchName(for: baby)
        return FlowRow(spacing: 6, lineSpacing: 5) {
            if let a = app.age {
                badgePill(
                    text: L10n.livedDays(a.lived),
                    symbol: "sun.max.fill",
                    color: Palette.bead,
                    dark: dark
                )
                badgePill(
                    text: "\(land.name) · \(stretch)",
                    symbol: land.symbol,
                    color: land.crayon,
                    dark: dark
                )
                if app.sex == nil {
                    Button(action: edit) {
                        badgePill(text: L10n.t("+ 性别", "+ Sex"), symbol: "figure.child", color: Palette.accent, dark: dark)
                    }
                    .buttonStyle(.toy)
                }
            } else {
                Button(action: edit) {
                    badgePill(text: L10n.t("填写出生日期", "Add birthday"), symbol: "calendar.badge.plus", color: Palette.accent, dark: dark)
                }
                .buttonStyle(.toy)
            }
        }
    }

    private func badgePill(text: String, symbol: String, color: Color, dark: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .accessibilityHidden(true)
            Text(text)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(dark ? color : Crayon.ink(color))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(dark ? 0.20 : 0.14)))
    }
}

/// Clean circular baby stage portrait with luminous girl/boy/gold framing (no overlapping corner sticker).
private struct BabyPortrait: View {
    let month: Int, sex: String?, giggle: Int
    @Environment(\.lamp) private var lamp
    var body: some View {
        let girl = sex == "girl", boy = sex == "boy"
        let tone = girl ? Crayon.pink : boy ? Crayon.sky : Crayon.sunflower
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                Circle().fill(RadialGradient(colors: [tone.opacity(lamp ? 0.50 : 0.34), tone.opacity(lamp ? 0.20 : 0.12)], center: UnitPoint(x: 0.5, y: 0.35), startRadius: 0, endRadius: s * 0.6))
                GrowingChild(month: month, giggle: giggle)
                    .frame(width: s * 1.15, height: s * 1.15)
                    .offset(y: s * 0.12)
                    .frame(width: s, height: s)
                    .clipShape(Circle())
                Circle().strokeBorder(tone.opacity(lamp ? 0.55 : 0.45), lineWidth: 2.2)
                Circle().strokeBorder(Color.white.opacity(lamp ? 0.22 : 0.85), lineWidth: 1.5).padding(2)
            }
            .frame(width: s, height: s)
        }
        .accessibilityElement().accessibilityAddTraits(.isImage)
        .accessibilityLabel(sex == "girl" ? L10n.t("女宝宝", "Baby girl") : sex == "boy" ? L10n.t("男宝宝", "Baby boy") : L10n.t("宝宝", "Baby"))
    }
}

/// Side-by-side companion switcher with concise 2–4 word visual identity tags instead of prose walls.
private struct CompanionPicker: View {
    @Environment(AppModel.self) private var app
    @Environment(\.lamp) private var lamp
    @Environment(\.colorScheme) private var scheme
    @State private var cheer = 0
    @Environment(\.dynamicTypeSize) private var type

    private var layout: AnyLayout { type.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8)) }

    var body: some View {
        let dark = lamp || scheme == .dark
        layout {
            ForEach(Kind.allCases, id: \.self) { k in
                let on = app.companion == k
                Button {
                    if on { cheer += 1 } else { withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) { app.companion = k }; cheer += 1 }
                } label: {
                    HStack(alignment: .center, spacing: 6) {
                        Creature(kind: k, mood: on ? .happy : .open, look: CGPoint(x: k == .moss ? 0.6 : -0.6, y: 0.1), lid: k == .otto && lamp ? 0.5 : nil,
                                 alive: on, poke: false, arms: on && cheer % 2 == 1 ? .cheer : .rest, glow: k == .otto && lamp)
                            .frame(width: (on ? 40 : 34) * k.scale, height: (on ? 40 : 34) * k.scale)
                            .frame(width: 44, height: 42, alignment: .bottom)
                            .background(alignment: .bottom) {
                                if on {
                                    Ellipse()
                                        .fill(RadialGradient(colors: [(lamp ? Palette.amber : Palette.bead).opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: 22))
                                        .frame(width: 42, height: 9)
                                        .offset(y: 3)
                                }
                            }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(k.rawValue)
                                .font(.subheadline.weight(on ? .bold : .semibold))
                                .foregroundStyle(on ? .primary : Palette.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(YouStudioCopy.companionBadge(k))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(on ? Palette.accent : Palette.secondaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }

                        Spacer(minLength: 2)

                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(on ? Palette.accent : Palette.outline.opacity(0.35))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                            .fill(on ? Palette.accent.opacity(dark ? 0.20 : 0.10) : (dark ? Color.white.opacity(0.03) : Palette.fill.opacity(0.45)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                            .strokeBorder(on ? Palette.accent.opacity(dark ? 0.50 : 0.30) : Palette.outline.opacity(0.14), lineWidth: on ? 1.2 : 0.75)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                }
                .buttonStyle(.toy)
                .accessibilityLabel(L10n.t("陪伴伙伴 \(k.rawValue)，\(YouStudioCopy.companionBadge(k))", "Companion \(k.rawValue), \(YouStudioCopy.companionBadge(k))"))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: cheer)
    }
}

/// Full-width living Appearance windows (`日光 / 夜灯 / 自动`) + unified compact Language pill selector.
private struct ThemeLanguageCard: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var type
    let dark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    StudioBadge(symbol: "paintpalette.fill", color: Crayon.lilac, active: true, dark: dark)
                    Text(L10n.t("外观", "Theme"))
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 4)
                    Text(app.theme.label)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Palette.accent.opacity(dark ? 0.20 : 0.12)))
                }

                HStack(spacing: 8) {
                    ForEach([ThemeMode.light, .dark, .system], id: \.self) { mode in
                        Swatch(mode: mode, on: app.theme == mode) {
                            withAnimation(.snappy) { app.theme = mode }
                        }
                    }
                }
            }

            Divider().opacity(0.45)

            Group {
                if type.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) {
                        langLabel
                        langPills
                    }
                } else {
                    HStack(spacing: 10) {
                        langLabel
                        Spacer(minLength: 4)
                        langPills
                    }
                }
            }
        }
        .padding(14)
        .printCard(radius: Radius.card)
    }

    private var langLabel: some View {
        HStack(spacing: 10) {
            StudioBadge(symbol: "globe", color: Crayon.sky, active: true, dark: dark)
            Text(L10n.t("语言", "Language"))
                .font(.subheadline.weight(.semibold))
        }
    }

    private var langPills: some View {
        HStack(spacing: 6) {
            ForEach(AppLanguage.allCases, id: \.self) { lang in
                let on = app.language == lang
                Button {
                    withAnimation(.snappy) { app.language = lang }
                } label: {
                    Text(lang.label)
                        .font(.caption.weight(on ? .bold : .semibold))
                        .foregroundStyle(on ? .white : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(on ? Palette.accentFill : (dark ? Palette.lampCard : Palette.card)))
                        .overlay(Capsule().strokeBorder(on ? .clear : Palette.outline.opacity(0.25), lineWidth: 0.8))
                }
                .buttonStyle(.toy)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: app.language)
    }
}

/// One appearance to choose, as a generous living window (`日光` / `夜灯` / `自动`) with non-overlapping AX2 checkmark.
private struct Swatch: View {
    let mode: ThemeMode
    let on: Bool
    let pick: () -> Void
    @Environment(\.dynamicTypeSize) private var type

    var body: some View {
        Button(action: pick) {
            Group {
                if type.isAccessibilitySize {
                    VStack(spacing: 5) {
                        swatchWindow
                        swatchLabel
                    }
                } else {
                    ZStack(alignment: .bottom) {
                        swatchWindow
                        swatchLabel
                            .padding(.bottom, 5)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.toy)
        .accessibilityLabel(mode.label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var swatchWindow: some View {
        preview
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                    .strokeBorder(on ? Palette.accent : Palette.outline.opacity(0.22), lineWidth: on ? 2.2 : 0.85)
            )
            .overlay(alignment: .topTrailing) {
                if on {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white, Palette.accentFill)
                        .padding(5)
                }
            }
    }

    private var swatchLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: mode == .light ? "sun.max.fill" : mode == .dark ? "lamp.desk.fill" : "circle.lefthalf.filled")
                .font(.system(size: 8.5, weight: .bold))
                .foregroundStyle(mode == .light ? Crayon.ink(Crayon.sunflower) : mode == .dark ? Palette.lampTint : Palette.secondaryText)
            Text(mode.label)
                .font(.caption2.weight(on ? .bold : .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Palette.card.opacity(0.94), in: Capsule())
    }

    @ViewBuilder private var preview: some View {
        switch mode {
        case .light: day
        case .dark: night
        case .system: HStack(spacing: 0) { day; night }
        }
    }

    private var day: some View {
        ZStack { Color(hex: 0xFBF7F0); DayAir(tone: Crayon.sunflower, scale: 0.45) }
    }

    private var night: some View {
        ZStack { Palette.lampPage; LampGlow(scale: 0.16); Motes(scale: 0.45) }
    }
}

/// Compact grouped Preference Deck replacing the oversized 2×2 toggle grid: sleek 50pt rows with tactile switches.
private struct PreferenceStudioCard: View {
    @Bindable var app: AppModel
    let face: Bool
    let dark: Bool
    @Environment(\.dynamicTypeSize) private var type

    var body: some View {
        let nightResting = app.theme != .system
        let nightStatus = nightResting ? L10n.t("需选自动", "Auto only") : "19:00–06:00"
        let soundStatus = app.tactileSounds ? L10n.t("已开启", "On") : L10n.t("静音", "Muted")
        let logStatus = app.journal ? L10n.t("已显示", "Shown") : L10n.t("已隐藏", "Hidden")
        let lockStatus = app.lock ? L10n.t("已锁定", "Locked") : L10n.t("未开启", "Off")

        VStack(spacing: 0) {
            preferenceRow(
                title: L10n.t("夜间自动灯", "Auto Lamp"),
                status: nightStatus,
                symbol: "moon.stars.fill",
                color: Palette.lampTint,
                isOn: app.nightLight,
                resting: nightResting
            ) {
                TactileEngine.shared.beadClick()
                withAnimation(.snappy) { app.nightLight.toggle() }
            }

            Divider().padding(.leading, 54).opacity(0.45)

            preferenceRow(
                title: L10n.t("手感音效", "Tactile Audio"),
                status: soundStatus,
                symbol: "hand.tap.fill",
                color: Crayon.teal,
                isOn: app.tactileSounds,
                resting: false
            ) {
                withAnimation(.snappy) { app.tactileSounds.toggle() }
                if app.tactileSounds { TactileEngine.shared.beadClick() }
            }

            Divider().padding(.leading, 54).opacity(0.45)

            preferenceRow(
                title: L10n.t("照护记录页", "Log Tab"),
                status: logStatus,
                symbol: "list.bullet.clipboard.fill",
                color: Crayon.tangerine,
                isOn: app.journal,
                resting: false
            ) {
                let next = !app.journal
                if !next || app.mayKeep() {
                    TactileEngine.shared.beadClick()
                    withAnimation(.snappy) { app.journal = next }
                }
            }

            if face {
                Divider().padding(.leading, 54).opacity(0.45)

                preferenceRow(
                    title: Biometry.name,
                    status: lockStatus,
                    symbol: Biometry.symbol,
                    color: Crayon.leaf,
                    isOn: app.lock,
                    resting: false
                ) {
                    TactileEngine.shared.beadClick()
                    Biometry.turn(!app.lock) { app.lock = $0 }
                }
            }
        }
        .printCard(radius: Radius.card)
    }

    private func preferenceRow(
        title: String,
        status: String,
        symbol: String,
        color: Color,
        isOn: Bool,
        resting: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let active = isOn && !resting
        let trackFill = active ? (dark ? color : Crayon.ink(color)) : Palette.outline.opacity(0.28)
        let ax = type.isAccessibilitySize

        return Button(action: action) {
            HStack(spacing: 12) {
                StudioBadge(symbol: symbol, color: color, active: active, dark: dark, size: 30)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(resting ? Palette.secondaryText : .primary)
                        .lineLimit(ax ? nil : 1)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(active ? (dark ? color : Crayon.ink(color)) : Palette.secondaryText)
                        .monospacedDigit()
                        .lineLimit(ax ? nil : 1)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                // Tactile miniature pill switch
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(trackFill)
                        .frame(width: 36, height: 22)
                    Circle()
                        .fill(.white)
                        .frame(width: 17, height: 17)
                        .padding(.horizontal, 2.5)
                        .shadow(color: .black.opacity(0.16), radius: 1, y: 0.5)
                }
                .opacity(resting ? 0.50 : 1.0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.toy)
        .disabled(resting)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/// Side-by-side Local Data & About footer dock aligned to the unified `StudioBadge` icon grammar.
private struct FooterStudioDock: View {
    let dark: Bool
    @Environment(\.dynamicTypeSize) private var type

    var body: some View {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
        let layout = type.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))

        layout {
            NavigationLink(value: Route.data) {
                footerTile(
                    symbol: "externaldrive.fill",
                    color: Crayon.sky,
                    title: L10n.t("离线数据", "Local Data"),
                    detail: L10n.t("仅存本机", "On-device")
                )
            }
            .buttonStyle(.toy)

            NavigationLink(value: Route.about) {
                footerTile(
                    symbol: "info.circle.fill",
                    color: Crayon.pebble,
                    title: L10n.t("关于摸索台灯", "About"),
                    detail: "v\(v)"
                )
            }
            .buttonStyle(.toy)
        }
    }

    private func footerTile(symbol: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            StudioBadge(symbol: symbol, color: color, active: true, dark: dark)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 2)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .printCard(radius: Radius.card)
    }
}

private struct DataRow: View {
    let title: String
    var detail: String? = nil
    let symbol: String
    let color: Color
    var body: some View {
        HStack(spacing: 10) {
            IconTile(symbol: symbol, color: color, size: 28, round: true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                if let detail, !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(Palette.secondaryText)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10).contentShape(Rectangle())
    }
}

/// The child: name, date of birth, sex — set once, edited here.
struct ProfileSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var date = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
    @State private var hasBirth = false
    var body: some View {
        NavigationStack {
            Form {
                // the child's own portrait at the head of the sheet, as on 我的
                Section {
                    HStack { Spacer(); BabyPortrait(month: app.babyMonth ?? 0, sex: app.sex, giggle: 0).frame(width: 92, height: 92); Spacer() }
                        .listRowBackground(Color.clear)
                }
                Section {
                    LabeledContent(L10n.t("小名", "Nickname")) {
                        TextField(L10n.t("小名", "Nickname"), text: Binding(get: { app.nickname }, set: { app.nickname = String($0.prefix(12)) })).multilineTextAlignment(.trailing)
                    }
                    DatePicker(L10n.t("出生日期", "Birthday"), selection: $date, in: Calendar.current.date(byAdding: .year, value: -4, to: Date())!...Date(), displayedComponents: .date)
                        .onChange(of: date) { _, _ in hasBirth = true }
                    Picker(L10n.t("性别", "Sex"), selection: Binding(get: { app.sex ?? "" }, set: { app.sex = $0.isEmpty ? nil : $0 })) {
                        Text(L10n.t("不填", "Not set")).tag(""); Text(L10n.t("男孩", "Boy")).tag("boy"); Text(L10n.t("女孩", "Girl")).tag("girl")
                    }
                } footer: { Text(L10n.t("性别只用于选择 WHO 生长曲线和称呼（她 / 他）。", "Used only for WHO growth curves.")) }
            }
            .scrollContentBackground(.hidden)
            .pageBackground(tone: Crayon.lilac)
            .navigationTitle(L10n.t("宝宝", "Baby")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.t("完成", "Done"), systemImage: "checkmark") { if hasBirth { app.birth = Day(date) }; dismiss() } } }
            .onAppear { if let b = app.birth { date = b.date } }
        }
        .presentationDetents([.large])
    }
}

private var stamp: String { let d = Day.today; return String(format: "%04d%02d%02d", d.y, d.m, d.d) }

/// About, in the same calm PrintCard language as 我的: hero header (tap the pair three times for their story),
/// content & documents, and help.
struct AboutView: View {
    @Environment(AppModel.self) private var app
    @State private var replay = false
    @State private var hops = 0
    @State private var lamp = false
    @State private var story = false
    var body: some View {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .bottom, spacing: 14) {
                    Duo(primary: app.companion, size: 64, cheer: hops, lit: lamp)
                        .storyKnock(hops: $hops, lamp: $lamp) { story = true }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.appName).font(.title2.weight(.bold))
                        Text(L10n.t("孩子摸索，大人点灯", "They explore. You hold the light.")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.accent)
                        Text(L10n.t("Moss & Otto · 版本 \(v)（\(b)）", "Version \(v) (\(b))")).font(.caption).foregroundStyle(Palette.secondaryText).monospacedDigit()
                    }
                    .padding(.bottom, 4)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4).padding(.top, 2)

                aboutGroup(L10n.t("内容与说明", "Content & Info")) {
                    row(Route.story, L10n.t("摸索台灯的故事", "Our Story"), "lamp.desk.fill", Palette.bead)
                    Divider().padding(.leading, 52).opacity(0.5)
                    row(Route.sources, L10n.t("内容来源", "Sources"), "books.vertical.fill", Crayon.caramel)
                    Divider().padding(.leading, 52).opacity(0.5)
                    row(Route.doc("CHANGELOG"), L10n.t("更新日志", "Release Notes"), "clock.arrow.circlepath", Crayon.lilac)
                    Divider().padding(.leading, 52).opacity(0.5)
                    row(Route.licenses, L10n.t("许可与致谢", "Licenses"), "checkmark.seal.fill", Crayon.aqua)
                }

                aboutGroup(L10n.t("条款与隐私", "Privacy & Terms")) {
                    row(Route.doc("TERMS"), L10n.t("使用条款", "Terms of Use"), "doc.text.fill", Crayon.pebble)
                    Divider().padding(.leading, 52).opacity(0.5)
                    row(Route.doc("PRIVACY"), L10n.t("隐私政策", "Privacy Policy"), "hand.raised.fill", Crayon.sky)
                    Divider().padding(.leading, 52).opacity(0.5)
                    row(Route.doc("DISCLAIMER"), L10n.t("免责声明", "Disclaimer"), "exclamationmark.shield.fill", Crayon.tangerine)
                }

                aboutGroup(L10n.t("帮助", "Help")) {
                    Button { Guide.replayNextLaunch(); replay = true } label: {
                        HStack(spacing: 10) {
                            IconTile(symbol: "lightbulb.fill", color: Crayon.sunflower, size: 28, round: true)
                            Text(replay ? L10n.t("下次打开时将重新显示提示", "Tips will appear on next launch") : L10n.t("重新显示使用提示", "Replay Tips"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(replay ? Palette.accent : .primary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 11).contentShape(Rectangle())
                    }
                    .buttonStyle(.toy).disabled(replay)
                    if let url = Owner.contactURL {
                        Divider().padding(.leading, 52).opacity(0.5)
                        Link(destination: url) {
                            DataRow(title: L10n.t("反馈问题", "Send Feedback"), symbol: "envelope.fill", color: Crayon.leaf)
                        }
                        .buttonStyle(.toy)
                    }
                }

                if let icp = Bundle.main.infoDictionary?["MosslingICP"] as? String, !icp.isEmpty {
                    Link(L10n.t("ICP备案号：\(icp)", "ICP Filing: \(icp)"), destination: URL(string: "https://beian.miit.gov.cn/")!)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 6)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10).padding(.bottom, 28)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.lilac)
        .navigationDestination(isPresented: $story) { StoryView() }
        .navigationTitle(L10n.t("关于摸索台灯", "About Moss & Otto")).navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func aboutGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText).padding(.leading, 6)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { content() }
                .buttonStyle(.toy)
                .printCard(radius: Radius.card)
        }
    }

    private func row(_ r: Route, _ t: String, _ sym: String, _ c: Color) -> some View {
        NavigationLink(value: r) { DataRow(title: t, symbol: sym, color: c) }
    }
}

/// Three interactive theatrical chapters in 「摸索台灯的故事」.
enum StoryTheaterAct: Int, CaseIterable, Identifiable, Sendable {
    case lamp = 0
    case explore = 1
    case grow = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .lamp: L10n.t("点灯", "Light")
        case .explore: L10n.t("摸索", "Explore")
        case .grow: L10n.t("长大", "Grow")
        }
    }

    var symbol: String {
        switch self {
        case .lamp: "lamp.desk.fill"
        case .explore: "hand.point.up.left.fill"
        case .grow: "leaf.fill"
        }
    }

    static func clampedMonth(_ month: Int) -> Int {
        min(max(month, 0), 36)
    }

    static func land(for month: Int) -> Land {
        Land.of(clampedMonth(month))
    }

    static func stageCaption(for act: StoryTheaterAct, month: Int) -> String {
        let m = clampedMonth(month)
        switch act {
        case .lamp:
            return L10n.t("一盏温柔台灯先亮起，把夜晚与桌面照亮。", "A warm bedside lamp glows first, softly lighting the room.")
        case .explore:
            return L10n.t("孩子按自己的好奇伸手触碰，大人的目光稳稳跟上。", "Moss reaches out at its own curiosity; Otto keeps quiet watch.")
        case .grow:
            let landName = land(for: m).name
            let age = m == 0 ? L10n.t("出生", "Birth") : L10n.t("满 \(m) 个月", "Month \(m)")
            return L10n.t("\(landName) · \(age) — 一月一站，按自己的节奏长大。", "\(landName) · \(age) — one gentle station at their own pace.")
        }
    }
}

/// Interactive 「摸索台灯的故事 / Our Story」 Micro-Theater:
/// 3-act playable desk theater (Hold the Light -> Let Them Explore -> Grow at Their Pace across 0–36m),
/// interactive TurnCards for Moss & Otto, and the three silent promises.
struct StoryView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var envLamp
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.accessibilityReduceMotion) private var reduce

    @State private var act: StoryTheaterAct
    @State private var customMonth: Int?
    @State private var lampLit = true
    @State private var bulbPullProgress: CGFloat = 0
    @State private var ringWobble: Double = 0
    @State private var exploreTaps = 0
    @State private var leafBurstTrigger = 0
    @Namespace private var actNS

    init(initialAct: StoryTheaterAct = .lamp, initialMonth: Int? = nil) {
        _act = State(initialValue: initialAct)
        _customMonth = State(initialValue: initialMonth.map(StoryTheaterAct.clampedMonth))
    }

    private var activeMonth: Int {
        StoryTheaterAct.clampedMonth(customMonth ?? app.babyMonth ?? 6)
    }

    var body: some View {
        let dark = envLamp || scheme == .dark
        let m = activeMonth

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Interactive Theater Stage wrapped in StyleDoor (10 taps -> 2D paper world; 3s finger loop -> 3D world)
                // Act 1 mounts Otto's tactile Golden Bulb pull-cord cleanly at top-trailing outside StyleDoor's gesture zone.
                ZStack(alignment: .topTrailing) {
                    StyleDoor(radius: Radius.card) {
                        StoryMicroTheaterStage(
                            act: act,
                            month: m,
                            lampLit: lampLit,
                            bulbPullProgress: bulbPullProgress,
                            ringWobble: ringWobble,
                            exploreTaps: exploreTaps,
                            leafBurstTrigger: leafBurstTrigger
                        )
                        .frame(height: 232)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    }

                    if act == .lamp {
                        OttoBulbControl(
                            soundscapeActive: lampLit,
                            pullProgress: $bulbPullProgress
                        ) {
                            withAnimation(reduce ? nil : CalmMotion.accordionSpring) {
                                lampLit.toggle()
                            }
                        }
                        .padding(.top, 2)
                        .padding(.trailing, 16)
                        .transition(.opacity)
                    }
                }
                .printCard(radius: Radius.card)

                // Chapter Bead Selector & Act-Coupled Prop Controls (placed cleanly outside StyleDoor to avoid gesture conflict)
                VStack(alignment: .leading, spacing: 10) {
                    actSelectorBar(dark: dark)

                    actPropControls(month: m, dark: dark)

                    Text(StoryTheaterAct.stageCaption(for: act, month: m))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .printCard(radius: Radius.card)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("孩子摸索，大人点灯", "They explore. You hold the light."))
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.t("轻点卡片翻看名字背后的一句话。", "Tap either card below to flip its story."))
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                }

                // Moss & Otto dual interactive TurnCards
                Group {
                    if type.isAccessibilitySize {
                        VStack(spacing: 10) {
                            companionCardSet
                        }
                    } else {
                        HStack(alignment: .top, spacing: 10) {
                            companionCardSet
                        }
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Three Silent Promises visual strip (replaces verbose prose + 3 stacked cards)
                promisesStrip(dark: dark)

                StoryGoesOn(primary: app.companion)
            }
            .padding(.top, 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.sunflower)
        .navigationTitle(L10n.t("摸索台灯的故事", "Our Story")).navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    @ViewBuilder
    private var companionCardSet: some View {
        pair(
            L10n.t("摸索", "Moss"),
            L10n.t("孩子", "the child"),
            L10n.t("用手、用嘴、用眼睛摸索世界", "Explores with hands, mouth, and eyes"),
            L10n.t("0–3 岁的孩子用手、用嘴、用眼睛摸索世界，每个月都会摸到一点新的东西。Moss 的名字取自「摸索」，头上的新芽一直在长。", "From 0 to 3, a child explores the world with hands, mouth, and eyes, discovering something new each month. Moss takes its name from exploring — its little sprout is always growing."),
            Palette.moss,
            .moss
        )
        pair(
            L10n.t("台灯", "Otto"),
            L10n.t("大人", "the grown-up"),
            L10n.t("不替人走路，只把桌面照亮", "Doesn't walk for them — just lights the table"),
            L10n.t("台灯不替人走路，只把桌面照亮，安静地陪在旁边。Otto 头顶的金色灯珠就是这盏灯。", "A desk lamp never walks for you; it simply lights the table and sits quietly beside you. The warm golden bead above Otto is that light."),
            Palette.rod,
            .otto
        )
    }

    private func actSelectorBar(dark: Bool) -> some View {
        let pills = ForEach(StoryTheaterAct.allCases) { item in
            let on = act == item
            Button {
                TactileEngine.shared.beadClick()
                withAnimation(reduce ? nil : .spring(response: 0.36, dampingFraction: 0.82)) {
                    act = item
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: item.symbol)
                        .font(.caption2.weight(.bold))
                    Text(item.title)
                        .font(.caption.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(on ? .white : .primary)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .frame(maxWidth: type.isAccessibilitySize ? nil : .infinity)
                .background {
                    if on {
                        Capsule()
                            .fill(Palette.accentFill)
                            .matchedGeometryEffect(id: "storyActPill", in: actNS)
                    } else {
                        Capsule()
                            .fill(dark ? Color.white.opacity(0.06) : Palette.fill.opacity(0.7))
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(on ? .isSelected : [])
        }

        return Group {
            if type.isAccessibilitySize {
                FlowRow(spacing: 8, lineSpacing: 8) { pills }
            } else {
                HStack(spacing: 6) { pills }
            }
        }
    }

    @ViewBuilder
    private func actPropControls(month: Int, dark: Bool) -> some View {
        switch act {
        case .lamp:
            HStack(spacing: 10) {
                Button {
                    TactileEngine.shared.beadClick()
                    withAnimation(reduce ? nil : .spring(response: 0.42, dampingFraction: 0.78)) {
                        lampLit.toggle()
                    }
                } label: {
                    Label(
                        lampLit ? L10n.t("轻拉灯绳 · 关灯", "Pull Cord · Dim") : L10n.t("轻拉灯绳 · 点亮", "Pull Cord · Light"),
                        systemImage: lampLit ? "lightbulb.fill" : "lightbulb.slash"
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                }
                .buttonStyle(.vinyl(lampLit ? Palette.lampTint : Palette.rod))

                Spacer(minLength: 4)

                Text(lampLit ? L10n.t("暖光已点亮", "Warm lamp on") : L10n.t("轻歇息中", "Resting dim"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(lampLit ? (dark ? Palette.amber : Crayon.ink(Palette.amberDeep)) : Palette.secondaryText)
            }

        case .explore:
            HStack(spacing: 10) {
                Button {
                    triggerStackerWobble()
                } label: {
                    Label(L10n.t("轻碰木套环", "Tap Ring Stacker"), systemImage: "hand.tap.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .buttonStyle(.vinyl(Crayon.teal, prominent: true))

                Spacer(minLength: 4)

                if exploreTaps > 0 {
                    Text(L10n.t("摸索了 \(exploreTaps) 次", "Explored \(exploreTaps)×"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                        .monospacedDigit()
                }
            }

        case .grow:
            let land = StoryTheaterAct.land(for: month)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Label(land.name, systemImage: land.symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(dark ? land.crayon : Crayon.ink(land.crayon))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(land.crayon.opacity(dark ? 0.22 : 0.14)))
                    Spacer()
                    Text(month == 0 ? L10n.t("出生 · 第 1 站", "Birth · Station 1") : L10n.t("满 \(month) 个月 · 第 \(month + 1) / 37 站", "Month \(month) · Station \(month + 1)/37"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.accent)
                        .monospacedDigit()
                }

                Slider(
                    value: Binding(
                        get: { Double(month) },
                        set: { next in
                            let val = StoryTheaterAct.clampedMonth(Int(next.rounded()))
                            if val != customMonth {
                                TactileEngine.shared.dimmerTick()
                                customMonth = val
                            }
                        }
                    ),
                    in: 0...36,
                    step: 1
                )
                .tint(Palette.bead)
                .accessibilityLabel(L10n.t("拖动预览 0 至 36 个月成长舞台", "Scrub 0 to 36 months growth stage"))

                HStack {
                    Text(L10n.t("出生", "0m"))
                    Spacer()
                    Text(L10n.t("1 岁", "1y"))
                    Spacer()
                    Text(L10n.t("2 岁", "2y"))
                    Spacer()
                    Text(L10n.t("3 岁", "3y"))
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Palette.secondaryText)
            }
        }
    }

    private func triggerStackerWobble() {
        TactileEngine.shared.vinylPop()
        exploreTaps += 1
        leafBurstTrigger += 1
        guard !reduce else { return }
        Task { @MainActor in
            for angle in [10.0, -7.0, 4.0, -2.0, 0.0] {
                withAnimation(.spring(response: 0.14, dampingFraction: 0.55)) {
                    ringWobble = angle
                }
                try? await Task.sleep(for: .milliseconds(75))
            }
        }
    }

    private func promisesStrip(dark: Bool) -> some View {
        let items: [(symbol: String, color: Color, title: String, detail: String)] = [
            ("heart.fill", Crayon.sunflower, L10n.t("不打分", "Zero Scores"), L10n.t("不比较不催促", "Pace to child")),
            ("lock.shield.fill", Crayon.leaf, L10n.t("只存本机", "Offline"), L10n.t("无账号零上传", "Stays private")),
            ("circle.grid.3x3.fill", Crayon.tangerine, L10n.t("一月一站", "37 Stations"), L10n.t("46 项分步共玩", "Step-by-step"))
        ]

        return Group {
            if type.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items, id: \.title) { it in
                        promiseTile(it, dark: dark)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(items, id: \.title) { it in
                        promiseTile(it, dark: dark)
                    }
                }
            }
        }
        .padding(12)
        .printCard(radius: Radius.card)
    }

    private func promiseTile(_ it: (symbol: String, color: Color, title: String, detail: String), dark: Bool) -> some View {
        HStack(spacing: 7) {
            StudioBadge(symbol: it.symbol, color: it.color, active: true, dark: dark, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(it.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(it.detail)
                    .font(.caption2)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pair(_ word: String, _ who: String, _ line: String, _ text: String, _ c: Color, _ k: Kind) -> some View {
        TurnCard(label: L10n.t("\(word)，属于\(who)。\(text)", "\(word), for \(who). \(text)")) {
            VStack(spacing: 6) {
                Creature(kind: k, look: CGPoint(x: k == .moss ? 0.6 : -0.6, y: 0.2), alive: true)
                    .frame(width: 56 * k.scale, height: 56 * k.scale).frame(height: 60, alignment: .bottom)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(word).font(.title3.weight(.bold)).foregroundStyle(c)
                    Text(L10n.t("属于" + who, "for " + who)).font(.caption).foregroundStyle(Palette.secondaryText)
                }
                Text(line).font(.footnote).foregroundStyle(.primary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        } back: {
            Text(text).font(.footnote).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Bespoke 3-act interactive desk theater canvas paired with live `Creature` & `GrowingChild` actors.
private struct StoryMicroTheaterStage: View {
    let act: StoryTheaterAct
    let month: Int
    let lampLit: Bool
    var bulbPullProgress: CGFloat = 0
    let ringWobble: Double
    let exploreTaps: Int
    let leafBurstTrigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.scrolling) private var scrolling

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let h = g.size.height
            let deskY = h * 0.74
            let ms = min(w * 0.29, h * 0.38)
            let os = ms * Kind.otto.scale
            let mossX = w * 0.29
            let ottoX = w * 0.72
            let toyX = w * 0.505
            let mossTop = deskY - ms * Sprites.mossFeet / 100
            let ottoTop = deskY - os * Sprites.ottoFeet / 100
            let b0 = Sprites.bead["idle"] ?? CGPoint(x: 0.29, y: 0.34)
            let bead = CGPoint(x: ottoX - os / 2 + os * b0.x, y: ottoTop + os * b0.y)
            let land = StoryTheaterAct.land(for: month)
            let isLit = act == .explore || lampLit

            ZStack(alignment: .topLeading) {
                if act == .grow {
                    growBackdrop(w: w, h: h, deskY: deskY, land: land)

                    GrowingChild(month: month, giggle: exploreTaps)
                        .frame(width: ms * 1.18, height: ms * 1.18)
                        .position(x: w * 0.34, y: deskY - ms * 0.45)

                    Creature(
                        kind: .otto,
                        mood: .happy,
                        look: CGPoint(x: -0.85, y: 0.25),
                        lean: -4,
                        alive: !reduce,
                        poke: false,
                        glow: month < 6
                    )
                    .frame(width: os, height: os)
                    .position(x: ottoX, y: ottoTop + os / 2)
                } else {
                    eveningRoomBackdrop(w: w, h: h, deskY: deskY)

                    if isLit {
                        warmConeLayer(w: w, h: h, deskY: deskY, bead: bead, toyX: toyX)
                    }

                    if act == .lamp && (lampLit || bulbPullProgress > 0.02) {
                        LampConeOverlay(
                            intensity: max(lampLit ? 0.38 : 0, bulbPullProgress),
                            night: true,
                            apexXFraction: 0.875
                        )
                    }

                    if isLit && !reduce && !Perf.still {
                        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: scenePhase != .active || scrolling.moving)) { tl in
                            Canvas { ctx, size in
                                let t = tl.date.timeIntervalSinceReferenceDate
                                for i in 0..<8 {
                                    let seed = Double(i) * 1.37
                                    let px = bead.x + CGFloat(sin(t * 0.5 + seed) * 34 - Double(i) * 8)
                                    let py = bead.y + 12 + CGFloat((t * 14 + seed * 19).truncatingRemainder(dividingBy: max(30, Double(deskY - bead.y))))
                                    let alpha = 0.25 + 0.35 * sin(t * 1.2 + seed)
                                    ctx.fill(
                                        Path(ellipseIn: CGRect(x: px, y: py, width: 2.8, height: 2.8)),
                                        with: .color(Palette.beadLight.opacity(max(0.08, alpha)))
                                    )
                                }
                            }
                        }
                        .allowsHitTesting(false)
                    }

                    ringStacker(at: CGPoint(x: toyX, y: deskY + 4), scale: ms / 140)

                    Creature(
                        kind: .moss,
                        mood: act == .explore && exploreTaps > 0 ? .happy : (isLit ? .open : .sleep),
                        look: act == .explore ? CGPoint(x: 0.9, y: 0.3) : CGPoint(x: 0.75, y: 0.1),
                        lean: act == .explore ? (exploreTaps > 0 ? 5 : 2.5) : 0,
                        alive: !reduce,
                        poke: false,
                        arms: act == .explore && exploreTaps > 0 ? .wave : .rest
                    )
                    .frame(width: ms, height: ms)
                    .overlay { MintLeafBurst(trigger: leafBurstTrigger) }
                    .environment(\.colorScheme, .dark)
                    .position(x: mossX, y: mossTop + ms / 2)

                    Creature(
                        kind: .otto,
                        mood: act == .explore && exploreTaps > 0 ? .happy : .open,
                        look: CGPoint(x: -0.9, y: act == .explore ? 0.35 : 0.25),
                        lid: (!isLit && act == .lamp) ? 0.72 : nil,
                        lean: act == .explore ? -4 : 0,
                        alive: !reduce,
                        poke: false,
                        glow: isLit
                    )
                    .frame(width: os, height: os)
                    .environment(\.colorScheme, .dark)
                    .position(x: ottoX, y: ottoTop + os / 2)
                }
            }
        }
        .clipped()
    }

    private func eveningRoomBackdrop(w: CGFloat, h: CGFloat, deskY: CGFloat) -> some View {
        Canvas { ctx, size in
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0x2A2742), Color(hex: 0x413652)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: deskY)
                )
            )
            let win = CGRect(x: w * 0.07, y: h * 0.10, width: w * 0.19, height: h * 0.27)
            ctx.fill(Path(roundedRect: win, cornerRadius: 6), with: .color(Color(hex: 0x1D2044)))
            ctx.stroke(Path(roundedRect: win, cornerRadius: 6), with: .color(Color(hex: 0x6B5A70)), lineWidth: 2.5)
            var cross = Path()
            cross.move(to: CGPoint(x: win.midX, y: win.minY)); cross.addLine(to: CGPoint(x: win.midX, y: win.maxY))
            cross.move(to: CGPoint(x: win.minX, y: win.midY)); cross.addLine(to: CGPoint(x: win.maxX, y: win.midY))
            ctx.stroke(cross, with: .color(Color(hex: 0x6B5A70)), lineWidth: 1.8)
            var moon = Path(ellipseIn: CGRect(x: win.minX + win.width * 0.56, y: win.minY + win.height * 0.12, width: 12, height: 12))
            moon = moon.subtracting(Path(ellipseIn: CGRect(x: win.minX + win.width * 0.56 + 4, y: win.minY + win.height * 0.12 - 3, width: 12, height: 12)))
            ctx.fill(moon, with: .color(Color(hex: 0xFFF1C4)))

            let top = CGRect(x: -10, y: deskY, width: w + 20, height: 14)
            ctx.fill(Path(top), with: .linearGradient(Gradient(colors: [Color(hex: 0xC99A62), Color(hex: 0xB78650)]), startPoint: CGPoint(x: 0, y: deskY), endPoint: CGPoint(x: 0, y: deskY + 14)))
            let front = CGRect(x: -10, y: deskY + 14, width: w + 20, height: h - deskY - 14)
            ctx.fill(Path(front), with: .linearGradient(Gradient(colors: [Color(hex: 0x9C6B3C), Color(hex: 0x7A522D)]), startPoint: CGPoint(x: 0, y: deskY + 14), endPoint: CGPoint(x: 0, y: h)))
            ctx.fill(Path(CGRect(x: -10, y: deskY + 13, width: w + 20, height: 1.5)), with: .color(Color(hex: 0xE2BC86).opacity(0.7)))
        }
        .accessibilityHidden(true)
    }

    private func warmConeLayer(w: CGFloat, h: CGFloat, deskY: CGFloat, bead: CGPoint, toyX: CGFloat) -> some View {
        Canvas { ctx, _ in
            ctx.fill(
                Path(ellipseIn: CGRect(x: bead.x - w * 0.45, y: bead.y - w * 0.45, width: w * 0.9, height: w * 0.9)),
                with: .radialGradient(Gradient(colors: [Palette.amber.opacity(0.32), Palette.amber.opacity(0)]), center: bead, startRadius: 0, endRadius: w * 0.45)
            )
            var cone = Path()
            cone.move(to: CGPoint(x: bead.x - 5, y: bead.y))
            cone.addLine(to: CGPoint(x: bead.x + 5, y: bead.y))
            cone.addLine(to: CGPoint(x: toyX + w * 0.22, y: deskY + 6))
            cone.addLine(to: CGPoint(x: toyX - w * 0.32, y: deskY + 6))
            cone.closeSubpath()
            ctx.fill(cone, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFD98A).opacity(0.35), Color(hex: 0xFFD98A).opacity(0.04)]), startPoint: bead, endPoint: CGPoint(x: bead.x, y: deskY)))
            ctx.fill(
                Path(ellipseIn: CGRect(x: toyX - w * 0.34, y: deskY - 2, width: w * 0.62, height: 20)),
                with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE2A6).opacity(0.55), Color(hex: 0xFFE2A6).opacity(0)]), center: CGPoint(x: toyX - w * 0.03, y: deskY + 8), startRadius: 0, endRadius: w * 0.31)
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func ringStacker(at p: CGPoint, scale k: CGFloat) -> some View {
        Canvas { ctx, size in
            let cx = size.width / 2, base = size.height - 4
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 30 * k, y: base - 3 * k, width: 60 * k, height: 8 * k)), with: .color(Color.black.opacity(0.22)))
            ctx.fill(Path(roundedRect: CGRect(x: cx - 26 * k, y: base - 9 * k, width: 52 * k, height: 9 * k), cornerRadius: 3 * k), with: .color(Color(hex: 0xE8C48C)))
            ctx.fill(Path(roundedRect: CGRect(x: cx - 2.5 * k, y: base - 58 * k, width: 5 * k, height: 50 * k), cornerRadius: 2.5 * k), with: .color(Color(hex: 0xE8C48C)))
            let rings: [(CGFloat, Color)] = [(44, Color(hex: 0x4FA3A0)), (34, Color(hex: 0xF2C14E)), (24, Color(hex: 0xE0644B))]
            var y = base - 9 * k
            for (i, (rw, c)) in rings.enumerated() {
                var r = ctx
                let rh = 11 * k
                if i == rings.count - 1 {
                    r.translateBy(x: cx, y: y)
                    r.rotate(by: .degrees(ringWobble))
                    r.translateBy(x: -cx, y: -y)
                }
                let rect = CGRect(x: cx - rw * k / 2, y: y - rh, width: rw * k, height: rh)
                r.fill(
                    Path(roundedRect: rect, cornerRadius: rh / 2),
                    with: .linearGradient(
                        Gradient(colors: [c.mix(with: .white, by: 0.25), c, c.mix(with: .black, by: 0.18)]),
                        startPoint: CGPoint(x: rect.minX, y: rect.minY),
                        endPoint: CGPoint(x: rect.minX, y: rect.maxY)
                    )
                )
                y -= rh - 1
            }
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 3.5 * k, y: base - 62 * k, width: 7 * k, height: 7 * k)), with: .color(Color(hex: 0xE8C48C)))
        }
        .frame(width: 70 * k, height: 72 * k)
        .position(x: p.x, y: p.y - 36 * k)
        .accessibilityHidden(true)
    }

    private func growBackdrop(w: CGFloat, h: CGFloat, deskY: CGFloat, land: Land) -> some View {
        let skyTop: Color = switch land {
        case .meadow: Color(hex: 0xDCF0E2)
        case .forest: Color(hex: 0xFBE9C8)
        case .river: Color(hex: 0xD8ECFA)
        }
        let skyBot: Color = switch land {
        case .meadow: Color(hex: 0xF4F7E6)
        case .forest: Color(hex: 0xFDF5E4)
        case .river: Color(hex: 0xEEF6FB)
        }
        let hillBack = land.crayon.opacity(0.32)
        let hillFront = land.crayon.opacity(0.50)

        return Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: [skyTop, skyBot]), startPoint: .zero, endPoint: CGPoint(x: 0, y: deskY)))
            // Warm sun
            let sunPt = CGPoint(x: w * 0.82, y: h * 0.18)
            ctx.fill(Path(ellipseIn: CGRect(x: sunPt.x - 24, y: sunPt.y - 24, width: 48, height: 48)), with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE39A), Color(hex: 0xFFE39A).opacity(0)]), center: sunPt, startRadius: 4, endRadius: 24))

            var back = Path()
            back.move(to: CGPoint(x: 0, y: deskY - 22))
            back.addQuadCurve(to: CGPoint(x: w, y: deskY - 12), control: CGPoint(x: w * 0.45, y: deskY - 56))
            back.addLine(to: CGPoint(x: w, y: h)); back.addLine(to: CGPoint(x: 0, y: h)); back.closeSubpath()
            ctx.fill(back, with: .color(hillBack))

            var front = Path()
            front.move(to: CGPoint(x: 0, y: deskY))
            front.addQuadCurve(to: CGPoint(x: w, y: deskY + 4), control: CGPoint(x: w * 0.6, y: deskY - 18))
            front.addLine(to: CGPoint(x: w, y: h)); front.addLine(to: CGPoint(x: 0, y: h)); front.closeSubpath()
            ctx.fill(front, with: .color(hillFront))

            // 37-station bead path across the meadow horizon with live month marker bead
            var dotPath = Path()
            dotPath.move(to: CGPoint(x: 20, y: deskY + 14))
            dotPath.addLine(to: CGPoint(x: w - 20, y: deskY + 14))
            ctx.stroke(dotPath, with: .color(Palette.bead.opacity(0.45)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
            let frac = CGFloat(StoryTheaterAct.clampedMonth(month)) / 36.0
            let bx = 20 + (w - 40) * frac
            let by = deskY + 14
            ctx.fill(Path(ellipseIn: CGRect(x: bx - 5, y: by - 5, width: 10, height: 10)), with: .color(Palette.bead))
            ctx.fill(Path(ellipseIn: CGRect(x: bx - 2.2, y: by - 2.5, width: 3.5, height: 3.5)), with: .color(Palette.beadLight))
        }
        .accessibilityHidden(true)
    }
}

/// A card that turns over when tapped: a picture and a line on its face, the whole of it on the back — the page says
/// little until it is touched. Both faces take the size of the larger; under Reduce Motion it simply changes face.
struct TurnCard<Front: View, Back: View>: View {
    let label: String
    var radius: CGFloat = 22
    var padding: CGFloat = 14
    @ViewBuilder let front: Front
    @ViewBuilder let back: Back
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var turned = false
    var body: some View {
        ZStack {
            front.opacity(turned ? 0 : 1)
            back.opacity(turned ? 1 : 0).rotation3DEffect(.degrees(reduce ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(padding)
        .printCard(radius: radius)
        .rotation3DEffect(.degrees(turned && !reduce ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(reduce ? nil : .spring(duration: 0.55, bounce: 0.2)) { turned.toggle() } }
        .sensoryFeedback(.selection, trigger: turned)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityHint(L10n.t("点一下翻面", "Tap to flip"))
    }
}

/// A Markdown document from the repository (terms, privacy, disclaimer, changelog), set as a document.
struct DocView: View {
    let name: String
    var body: some View {
        let resURL = (L10n.isEnglish ? Bundle.main.url(forResource: name + "_EN", withExtension: "md") : nil)
            ?? Bundle.main.url(forResource: name, withExtension: "md")
        let raw = (resURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? L10n.t("读取不到这份文件。", "This document could not be loaded."))
            .replacingOccurrences(of: "安卓应用", with: "应用")
        let lines = Owner.fill(raw).components(separatedBy: "\n")
        // a table's first row (the one followed by |---|) names the columns; it is not an entry
        let heads = Set(lines.indices.filter { i in i + 1 < lines.count && lines[i].hasPrefix("|") && lines[i + 1].replacingOccurrences(of: " ", with: "").hasPrefix("|---") })
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { i, l in if !heads.contains(i) { docLine(l) } }
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func docLine(_ l: String) -> some View {
        if l.hasPrefix("# ") { Text(l.dropFirst(2)).font(.largeTitle.weight(.bold)).padding(.bottom, 8) }
        else if l.hasPrefix("## ") { Text(l.dropFirst(3)).font(.title3.weight(.bold)).padding(.top, 18) }
        else if l.hasPrefix("- ") { HStack(alignment: .firstTextBaseline, spacing: 8) { Text("•").foregroundStyle(Palette.secondaryText); Text(rich(String(l.dropFirst(2)))).font(.body) } }
        else if let r = l.range(of: #"^\d+\. "#, options: .regularExpression) {
            HStack(alignment: .firstTextBaseline, spacing: 8) { Text(l[r].trimmingCharacters(in: .whitespaces)).font(.body.monospacedDigit()).foregroundStyle(Palette.secondaryText).frame(width: 24, alignment: .leading); Text(rich(String(l[r.upperBound...]))).font(.body) }
        }
        else if l.hasPrefix("|") {
            let cells = l.trimmingCharacters(in: CharacterSet(charactersIn: "|")).components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            if !cells.allSatisfy({ $0.hasPrefix("---") }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rich(cells.first ?? "")).font(.headline)
                    ForEach(Array(cells.dropFirst().enumerated()), id: \.offset) { _, c in Text(rich(c)).font(.subheadline).foregroundStyle(Palette.secondaryText) }
                }
                .card(Palette.card, radius: 18, padding: 14)
            }
        }
        else if l.hasPrefix("适用于") || l.hasPrefix("生效日期") || l.hasPrefix("Applies to") || l.hasPrefix("Effective") { Text(l).font(.footnote).foregroundStyle(Palette.secondaryText) }
        else if l.isEmpty { Color.clear.frame(height: 2) }
        else { Text(rich(l)).font(.body) }
    }
}

/// Every source the content draws on, numbered, plus a collapsible WHO 0–36m daily rhythm reference.
struct SourcesView: View {
    @Environment(AppModel.self) private var app
    @State private var showWHO = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !app.content.who.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Button { withAnimation(.snappy) { showWHO.toggle() } } label: {
                            HStack(spacing: 10) {
                                IconTile(symbol: "clock.badge.checkmark.fill", color: Crayon.aqua, size: 28, round: true)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(L10n.t("WHO 每天的节奏参考", "WHO Daily Rhythm Reference")).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                    Text(L10n.t("0–3 岁活动、睡眠与屏幕建议（2019）", "0–3 yr activity, sleep & screen guide (2019)")).font(.caption).foregroundStyle(Palette.secondaryText)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.down")
                                    .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                                    .rotationEffect(.degrees(showWHO ? 180 : 0))
                            }
                            .padding(14).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if showWHO {
                            Divider().padding(.horizontal, 14).opacity(0.5)
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(app.content.who.enumerated()), id: \.offset) { idx, row in
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(row.age).font(.subheadline.weight(.bold)).foregroundStyle(Palette.accent)
                                        whoLine(L10n.t("活动", "Activity"), row.act)
                                        whoLine(L10n.t("睡眠", "Sleep"), row.sleep)
                                        whoLine(L10n.t("屏幕", "Screens"), row.screen)
                                        whoLine(L10n.t("久坐", "Restraint"), row.restrain)
                                    }
                                    if idx < app.content.who.count - 1 { Divider().opacity(0.4) }
                                }
                            }
                            .padding(14)
                        }
                    }
                    .printCard(radius: Radius.card)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.t("参考文献 · \(app.content.sources.count + 1) 项", "References · \(app.content.sources.count + 1)"))
                        .font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText).padding(.leading, 6)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        ForEach(Array(app.content.sources.enumerated()), id: \.offset) { i, s in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("\(i + 1)").font(.footnote.monospacedDigit()).foregroundStyle(Palette.secondaryText).frame(minWidth: 20, alignment: .leading)
                                    Text(s.org).font(.subheadline.weight(.semibold))
                                }
                                Text(s.title).font(.footnote).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                                let meta = [s.date, s.checked].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "；")
                                if !meta.isEmpty { Text(meta).font(.caption).foregroundStyle(Palette.secondaryText) }
                                if let u = s.url, let url = URL(string: u), !u.isEmpty { Link(u, destination: url).font(.caption).lineLimit(1) }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            Divider().padding(.leading, 14).opacity(0.45)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("\(app.content.sources.count + 1)").font(.footnote.monospacedDigit()).foregroundStyle(Palette.secondaryText).frame(minWidth: 20, alignment: .leading)
                                Text("World Health Organization").font(.subheadline.weight(.semibold))
                            }
                            Text(L10n.t("WHO Child Growth Standards：体重、身长 / 身高、头围的年龄别标准", "WHO Child Growth Standards: weight, length/height, and head circumference for age")).font(.footnote)
                            Text("2006").font(.caption).foregroundStyle(Palette.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                    }
                    .printCard(radius: Radius.card)
                    Text(L10n.t("育儿内容整理自公开发布的机构资料，每一条都注明来源。", "Guidance is summarized from published public health and pediatric references, each cited above."))
                        .font(.caption).foregroundStyle(Palette.secondaryText).padding(.horizontal, 6).padding(.top, 2)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10).padding(.bottom, 28)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.lilac)
        .navigationTitle(L10n.t("内容来源", "Sources")).navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func whoLine(_ label: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText).frame(width: L10n.isEnglish ? 64 : 28, alignment: .leading)
            Text(text).font(.caption).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct LicensesView: View {
    var body: some View {
        List {
            Section(L10n.t("制作", "Craft")) {
                row(L10n.appName,
                    L10n.t("由独立创作者构思与持续打磨，专注安静、离线、以孩子节奏为本的家庭陪伴体验。",
                           "Independently designed and crafted as a quiet, offline companion paced to your child."),
                    "Moss & Otto")
            }
            Section(L10n.t("数据", "Data")) {
                row("WHO Child Growth Standards",
                    L10n.t("按世界卫生组织的使用条款引用", "Used under World Health Organization terms"),
                    "© World Health Organization")
            }
            Section(L10n.t("系统框架", "Frameworks")) {
                row("SwiftUI · Swift Charts · WidgetKit · ActivityKit", "Apple SDK", "© Apple Inc.")
            }
        }
        .scrollContentBackground(.hidden).pageBackground()
        .navigationTitle(L10n.t("许可与致谢", "Licenses & Credits"))
        .toolbar(.hidden, for: .tabBar)
    }
    private func row(_ a: String, _ b: String, _ c: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(a).font(.subheadline.weight(.semibold)); Text(b).font(.footnote); Text(c).font(.caption).foregroundStyle(Palette.secondaryText) }
    }
}

/// What the phone unlocks with, named as the phone names it: 面容 ID, 触控 ID, or the passcode.
enum Biometry {
    private static var type: LABiometryType {
        let c = LAContext()
        _ = c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return c.biometryType
    }
    static var name: String {
        switch type {
        case .faceID: L10n.t("面容 ID", "Face ID")
        case .touchID: L10n.t("触控 ID", "Touch ID")
        case .opticID: L10n.t("视控 ID", "Optic ID")
        default: L10n.t("密码", "Passcode")
        }
    }
    /// The lock is turned on only after the owner of the phone confirms once (Face ID is asked when it is first used,
    /// with its purpose in NSFaceIDUsageDescription); turning it off needs nothing.
    static func turn(_ on: Bool, _ set: @escaping @MainActor (Bool) -> Void) {
        guard on else { Task { @MainActor in set(false) }; return }
        Task { @MainActor in
            let ok = (try? await LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: L10n.t("打开应用锁", "Enable App Lock"))) ?? false
            set(ok)
        }
    }
    static var symbol: String {
        switch type { case .faceID: "faceid"; case .touchID: "touchid"; case .opticID: "opticid"; default: "lock.fill" }
    }
}

/// Who stands behind the app, from the build settings (MOSSLING_DEVELOPER, MOSSLING_EMAIL): named in the documents
/// and reached by 反馈问题. Until they are set, the documents point to what every App Store page has — the
/// developer's name and its 「App 支持」 link — never a placeholder, and never a site that needs an account.
enum Owner {
    private static func value(_ key: String) -> String {
        (Bundle.main.infoDictionary?[key] as? String ?? "").trimmingCharacters(in: .whitespaces)
    }
    static var developer: String { value("MosslingDeveloper") }
    static var email: String { value("MosslingEmail") }
    /// How to reach the developer, as the documents say it.
    static var contact: String { email.isEmpty ? L10n.t("本应用 App Store 页面上的「App 支持」链接", "the App Support link on the App Store page") : L10n.t("电子邮件 ", "email ") + email }
    /// 反馈问题 opens mail; with no address yet there is no button (the documents name the App Store page instead).
    static var contactURL: URL? { email.isEmpty ? nil : URL(string: "mailto:" + email) }
    static var developerName: String { developer.isEmpty ? L10n.t("本应用 App Store 页面上显示的开发者", "the developer listed on the App Store page") : developer }
    /// A document with the developer and the contact put in.
    static func fill(_ text: String) -> String {
        text.replacingOccurrences(of: "{{DEVELOPER}}", with: developerName).replacingOccurrences(of: "{{CONTACT}}", with: contact)
    }
}
