import SwiftUI
import StoreKit

/// 「百味食盒 / First Foods Tasting Box」 — Tactile Montessori tasting catalog of 60 whole foods across 6 botanical
/// trays. Zero scores, zero guilt, offline-only, with 3× Tasting Passport poster export and optional Journal logging.
struct FoodAtlasView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.accessibilityReduceMotion) private var reduce

    @State private var store: FoodAtlasStore
    @State private var filter: Filter = .all
    @State private var query = ""
    @State private var editingItem: FoodItem? = nil
    @State private var recentlyStampedId: String? = nil
    @State private var mossTapCount: Int = 0
    @State private var leafBurstTrigger: Int = 0

    enum Filter: Hashable, Identifiable {
        case all
        case category(FoodCategory)
        case allergen
        case untasted

        var id: String {
            switch self {
            case .all: "all"
            case .category(let c): "cat-\(c.rawValue)"
            case .allergen: "allergen"
            case .untasted: "untasted"
            }
        }

        var label: String {
            switch self {
            case .all: L10n.t("全部 60 种", "All 60")
            case .category(let c): c.title
            case .allergen: L10n.t("常见致敏", "Allergens")
            case .untasted: L10n.t("还未尝过", "To Try")
            }
        }
    }

    init(store: FoodAtlasStore = .shared) {
        _store = State(initialValue: store)
    }

    private var allFilters: [Filter] {
        [.all] + FoodCategory.allCases.map { .category($0) } + [.allergen, .untasted]
    }

    private var filteredItems: [FoodItem] {
        let base: [FoodItem] = switch filter {
        case .all: FoodItem.catalog
        case .category(let c): FoodItem.catalog.filter { $0.category == c }
        case .allergen: FoodItem.catalog.filter(\.isCommonAllergen)
        case .untasted: FoodItem.catalog.filter { store.record(for: $0.id) == nil }
        }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.zh.localizedCaseInsensitiveContains(q)
                || $0.en.localizedCaseInsensitiveContains(q)
                || $0.category.title.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        let who = app.nickname.isEmpty ? L10n.t("宝宝", "Baby") : app.nickname
        let snapshotRecords = store.records
        let ageLabel = app.age.map { L10n.ageText($0) } ?? ""
        let passportPoster = RenderedPoster {
            let card = FoodPassportPoster(babyName: who, ageLabel: ageLabel, records: snapshotRecords)
            let renderer = ImageRenderer(content: card)
            renderer.scale = 3.0
            return renderer.uiImage
        }

        let columns: [GridItem] = type.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
            : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                wreathHeroCard(dark: dark)

                // Wrapping Montessori filter tray (zero horizontal clipping)
                FlowRow(spacing: 7, lineSpacing: 7) {
                    ForEach(allFilters) { f in
                        let selected = filter == f
                        Button {
                            TactileEngine.shared.beadClick()
                            withAnimation(.snappy) { filter = f }
                        } label: {
                            Text(f.label)
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(selected ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(selected ? Palette.accentFill : (dark ? Palette.lampCard : Palette.card)))
                                .overlay(Capsule().strokeBorder(Palette.outline.opacity(selected ? 0 : 0.32), lineWidth: 0.75))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }

                if filter == .allergen {
                    let allergens = FoodItem.catalog.filter(\.isCommonAllergen)
                    let introduced = allergens.filter { store.record(for: $0.id) != nil }.count
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.lampTint)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("已尝 \(introduced) / \(allergens.count) 种常见致敏食材", "\(introduced) of \(allergens.count) common allergens introduced"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.primary)
                            Text(L10n.t("常见致敏食材建议白天首次少量尝试，观察皮肤与大便反应；有家族过敏史请先咨询儿科医生。", "Common allergens are best offered in tiny amounts earlier in the day while watching for skin or tummy changes. Ask your pediatrician if you have allergy concerns."))
                                .font(.caption)
                                .foregroundStyle(Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(Palette.amber.opacity(dark ? 0.12 : 0.14)))
                }

                if filteredItems.isEmpty {
                    VStack(spacing: 8) {
                        Creature(kind: .moss, mood: .open, look: CGPoint(x: 0.4, y: 0.2), alive: false)
                            .frame(width: 52, height: 52)
                        Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                             ? L10n.t("这一栏都尝遍啦", "Everything here has been tasted")
                             : L10n.t("没有找到「\(query)」", "No foods matching \"\(query)\""))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button(L10n.t("显示全部食材", "Show all 60 foods")) {
                                query = ""
                                filter = .all
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.accent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .printCard(radius: Radius.card)
                } else {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(filteredItems) { item in
                            let rec = store.record(for: item.id)
                            FoodStampTile(
                                item: item,
                                record: rec,
                                dark: dark,
                                justStamped: recentlyStampedId == item.id
                            ) {
                                if app.mayKeep() {
                                    TactileEngine.shared.beadClick()
                                    editingItem = item
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.leaf)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: L10n.t("搜索 60 种食材…", "Search 60 foods…"))
        .navigationTitle(L10n.t("百味食盒", "First Foods"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: passportPoster,
                    preview: SharePreview(L10n.t("\(who)的百味护照", "\(who)'s First Foods Passport"))
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(L10n.t("分享百味护照", "Share First Foods Passport"))
            }
        }
        .sheet(item: $editingItem) { item in
            FoodTasteSheet(item: item, existing: store.record(for: item.id), store: store) { savedId in
                withAnimation(reduce ? nil : .spring(response: 0.42, dampingFraction: 0.56)) {
                    recentlyStampedId = savedId
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1400))
                    if recentlyStampedId == savedId {
                        recentlyStampedId = nil
                    }
                }
            }
            .lampPresented(sheet: true)
        }
    }

    private func wreathHeroCard(dark: Bool) -> some View {
        HStack(spacing: 14) {
                ZStack {
                    FoodWreathCanvas(store: store, dark: dark)
                        .frame(width: 98, height: 98)
                    VStack(spacing: 0) {
                        Ticking(text: "\(store.tastedCount)")
                            .font(Typeface.numerals(26, relativeTo: .title2, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("/ \(FoodItem.catalog.count)")
                            .font(Typeface.numerals(11, relativeTo: .caption2, weight: .semibold))
                            .foregroundStyle(Palette.secondaryText)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(wreathAccessibilityLabel)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(L10n.t("初尝人间百味", "Tasting the Table"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    Button {
                        TactileEngine.shared.vinylPop()
                        mossTapCount += 1
                        if mossTapCount % 3 == 0 {
                            leafBurstTrigger += 1
                        }
                    } label: {
                        Creature(
                            kind: .moss,
                            mood: store.tastedCount > 0 || mossTapCount > 0 ? .happy : .open,
                            look: CGPoint(x: -0.6, y: 0.2),
                            alive: !reduce,
                            poke: true,
                            notice: mossTapCount
                        )
                        .frame(width: 38, height: 38)
                        .overlay { MintLeafBurst(trigger: leafBurstTrigger) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("摸一摸 Moss，轻点三次会飘出嫩芽", "Tap Moss gently — three taps drift out mint leaves"))
                }
                Text(
                    store.tastedCount == 0
                        ? L10n.t("轻点任意食材，记下宝宝第一次尝到它的样子与反应。", "Tap any food to stamp the day your baby first tasted it.")
                        : L10n.t("已尝过 \(store.tastedCount) 种味道，其中 \(store.lovedCount) 种很喜欢。慢慢尝，不赶进度。", "\(store.tastedCount) tastes explored · \(store.lovedCount) favorites. No rush, one bite at a time.")
                )
                .font(.caption)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                // Compact 6-category botanical dot summary
                HStack(spacing: 8) {
                    ForEach(FoodCategory.allCases) { cat in
                        let c = store.tastedCount(in: cat)
                        HStack(spacing: 3) {
                            Circle()
                                .fill(c > 0 ? cat.color : cat.color.opacity(0.28))
                                .frame(width: 7, height: 7)
                            Text("\(c)")
                                .font(Typeface.numerals(11, relativeTo: .caption2, weight: .bold))
                                .foregroundStyle(c > 0 ? .primary : Palette.secondaryText)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Crayon.leaf.opacity(dark ? 0.14 : 0.14), Crayon.sunflower.opacity(dark ? 0.05 : 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .printCard(radius: Radius.card)
    }

    private var wreathAccessibilityLabel: String {
        let nonEmpty = FoodCategory.allCases.compactMap { cat -> String? in
            let count = store.tastedCount(in: cat)
            return count > 0 ? "\(cat.title) \(count)" : nil
        }
        let catSummary = nonEmpty.isEmpty ? "" : (L10n.isEnglish ? ", including " : "，涵盖 ") + nonEmpty.joined(separator: L10n.isEnglish ? ", " : "、")
        return L10n.t(
            "百味花环进度：\(store.tastedCount) 除以 \(FoodItem.catalog.count) 种，最喜欢 \(store.lovedCount) 种\(catSummary)",
            "Tasting wreath: \(store.tastedCount) of \(FoodItem.catalog.count) foods explored, \(store.lovedCount) favorites\(catSummary)"
        )
    }
}

/// Six-segment Montessori tasting wreath drawn cleanly in Canvas.
private struct FoodWreathCanvas: View {
    let store: FoodAtlasStore
    let dark: Bool

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.42
            let lineW: CGFloat = 9.0
            let cats = FoodCategory.allCases
            let gap = 0.12 // radians
            let slice = (2.0 * .pi - gap * Double(cats.count)) / Double(cats.count)

            for (idx, cat) in cats.enumerated() {
                let start = -Double.pi / 2 + Double(idx) * (slice + gap) + gap / 2
                let end = start + slice
                var track = Path()
                track.addArc(center: center, radius: radius, startAngle: .radians(start), endAngle: .radians(end), clockwise: false)
                ctx.stroke(track, with: .color(cat.color.opacity(dark ? 0.22 : 0.18)), style: StrokeStyle(lineWidth: lineW, lineCap: .round))

                let done = store.tastedCount(in: cat)
                let total = max(1, store.totalCount(in: cat))
                if done > 0 {
                    let frac = min(1.0, Double(done) / Double(total))
                    var fill = Path()
                    fill.addArc(center: center, radius: radius, startAngle: .radians(start), endAngle: .radians(start + slice * frac), clockwise: false)
                    ctx.stroke(fill, with: .color(cat.color), style: StrokeStyle(lineWidth: lineW, lineCap: .round))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Botanical mint leaves fluttering upward when the user pokes Moss three times in the tasting box header.
private struct MintLeafBurst: View {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduce

    private static let leaves: [(dx: CGFloat, up: CGFloat, tilt: Double, col: Color)] = [
        (-18, 34, -28, Palette.mint),
        (0, 44, 12, Palette.mintLight),
        (16, 36, 32, Crayon.leaf),
        (-9, 28, -14, Palette.beadLight),
        (11, 30, 22, Palette.mintPale)
    ]

    var body: some View {
        if reduce { EmptyView() } else {
            Color.clear
                .overlay {
                    KeyframeAnimator(initialValue: 0.0, trigger: trigger) { t in
                        ZStack {
                            ForEach(Array(Self.leaves.enumerated()), id: \.offset) { _, lf in
                                Capsule(style: .continuous)
                                    .fill(lf.col)
                                    .frame(width: 8, height: 4.5)
                                    .rotationEffect(.degrees(lf.tilt * (0.4 + t)))
                                    .offset(x: lf.dx * t, y: -lf.up * t - 8)
                                    .opacity(t <= 0 || t >= 1 ? 0 : 1 - max(0, t - 0.65) / 0.35)
                            }
                        }
                    } keyframes: { _ in
                        LinearKeyframe(0.0, duration: 0.0)
                        LinearKeyframe(1.0, duration: 0.95)
                        LinearKeyframe(0.0, duration: 0.0)
                    }
                }
                .allowsHitTesting(false)
        }
    }
}

/// One tactile Montessori tasting dish tile inside the 60-food grid.
private struct FoodStampTile: View {
    let item: FoodItem
    let record: FoodRecord?
    let dark: Bool
    var justStamped: Bool = false
    let tap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        let tasted = record != nil
        let catColor = item.category.color
        let watch = record?.watchSkin == true
        let times = max(1, record?.times ?? 1)
        return Button(action: tap) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        if justStamped && !reduce {
                            Circle()
                                .strokeBorder(Palette.bead.opacity(0.68), lineWidth: 2.2)
                                .frame(width: 54, height: 54)
                                .transition(.scale.combined(with: .opacity))
                        }
                        Circle()
                            .fill(
                                tasted
                                    ? catColor.opacity(dark ? 0.26 : 0.18)
                                    : (dark ? Color.white.opacity(0.05) : Palette.fill.opacity(0.75))
                            )
                            .frame(width: 48, height: 48)
                        FoodGlyphView(food: item, size: 32)
                            .saturation(tasted ? 1.0 : 0.72)
                            .opacity(tasted ? 1.0 : 0.85)
                    }
                    .phaseAnimator(reduce ? [1.0] : [1.0, 1.16, 0.96, 1.03, 1.0], trigger: justStamped) { view, scale in
                        view.scaleEffect(scale)
                    }
                    .overlay(alignment: .topLeading) {
                        if watch {
                            Circle()
                                .fill(Palette.amber)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().strokeBorder(dark ? Palette.lampCard : .white, lineWidth: 1.4))
                                .offset(x: -1, y: -1)
                        }
                    }

                    if let rec = record {
                        Image(systemName: rec.reaction.symbol)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(rec.reaction.color))
                            .overlay(Circle().strokeBorder(dark ? Palette.lampCard : .white, lineWidth: 1.5))
                            .offset(x: 4, y: -3)
                    } else if item.isCommonAllergen {
                        Circle()
                            .fill(Palette.amber)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().strokeBorder(dark ? Palette.lampCard : .white, lineWidth: 1.2))
                            .offset(x: 1, y: 1)
                    }
                }

                Text(item.name)
                    .font(.caption.weight(tasted ? .bold : .semibold))
                    .foregroundStyle(tasted ? .primary : Palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                if let rec = record {
                    if watch {
                        Text(times >= 2 ? L10n.t("留意 · ×\(times)", "Watch · ×\(times)") : L10n.t("留意反应", "Watch"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(dark ? Palette.amber : Crayon.ink(Palette.amber))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else {
                        Text(times >= 2 ? "\(rec.firstTastedDay.md) · ×\(times)" : rec.firstTastedDay.md)
                            .font(.caption2)
                            .foregroundStyle(Palette.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                } else {
                    Text(item.isCommonAllergen ? L10n.t("致敏留意", "Allergen") : item.category.title)
                        .font(.caption2)
                        .foregroundStyle(item.isCommonAllergen ? (dark ? Palette.amber : Crayon.ink(Palette.amber)) : Palette.secondaryText.opacity(0.72))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                    .fill(tasted ? catColor.opacity(dark ? 0.14 : 0.08) : (dark ? Palette.lampCard : Palette.card))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                    .strokeBorder(tasted ? catColor.opacity(dark ? 0.55 : 0.45) : Palette.outline.opacity(0.22), lineWidth: tasted ? 1.4 : 0.75)
            )
        }
        .buttonStyle(.toy)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(record: record, times: times, watch: watch))
    }

    private func accessibilityText(record: FoodRecord?, times: Int, watch: Bool) -> String {
        var parts = [item.name]
        if item.isCommonAllergen { parts.append(L10n.t("常见致敏", "common allergen")) }
        if let rec = record {
            parts.append(rec.reaction.title)
            parts.append(rec.firstTastedDay.md)
            if times >= 2 { parts.append(L10n.t("尝过 \(times) 次", "\(times) times")) }
            if watch { parts.append(L10n.t("需留意反应", "watch skin or tummy")) }
        } else {
            parts.append(L10n.t("尚未尝过", "not tasted yet"))
        }
        return parts.joined(separator: ", ")
    }
}

/// Quick tactile stamp sheet for logging or updating a baby's first taste of a food.
private struct FoodTasteSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.requestReview) private var requestReview

    let item: FoodItem
    let existing: FoodRecord?
    let store: FoodAtlasStore
    let onSaved: (String) -> Void

    @State private var reaction: FoodReaction
    @State private var tastedDate: Date
    @State private var note: String
    @State private var watchSkin: Bool
    @State private var times: Int
    @State private var alsoLogJournal: Bool

    init(item: FoodItem, existing: FoodRecord?, store: FoodAtlasStore, onSaved: @escaping (String) -> Void = { _ in }) {
        self.item = item
        self.existing = existing
        self.store = store
        self.onSaved = onSaved
        _reaction = State(initialValue: existing?.reaction ?? .loved)
        _tastedDate = State(initialValue: existing?.firstTastedDay.date ?? Date())
        _note = State(initialValue: existing?.note ?? "")
        _watchSkin = State(initialValue: existing?.watchSkin ?? false)
        _times = State(initialValue: max(1, existing?.times ?? 1))
        _alsoLogJournal = State(initialValue: existing == nil)
    }

    private var prepChips: [String] {
        L10n.isEnglish
            ? ["Steamed mash", "Soft finger strip", "Mixed in cereal", "Tiny taste"]
            : ["蒸软压泥", "软手指条", "拌米粉粥", "少量初尝"]
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Dish emblem header
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(item.category.color.opacity(dark ? 0.28 : 0.18))
                                .frame(width: 62, height: 62)
                            FoodGlyphView(food: item, size: 42)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.title2.weight(.bold))
                            Text(item.category.title + (item.isCommonAllergen ? L10n.t(" · 常见致敏食材", " · Common allergen") : ""))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(item.isCommonAllergen ? (dark ? Palette.amber : Crayon.ink(Palette.amber)) : Palette.secondaryText)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .printCard(radius: Radius.card)

                    // Reaction stamp selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t("宝宝尝完的感觉", "How Baby Liked It"))
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Palette.secondaryText)
                        HStack(spacing: 10) {
                            ForEach(FoodReaction.allCases) { r in
                                let on = reaction == r
                                Button {
                                    TactileEngine.shared.beadClick()
                                    reaction = r
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: r.symbol)
                                            .font(.title3.weight(.bold))
                                            .foregroundStyle(on ? .white : r.color)
                                        Text(r.title)
                                            .font(.footnote.weight(.bold))
                                            .foregroundStyle(on ? .white : .primary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(on ? r.color : (dark ? Palette.lampCard : Palette.card)))
                                    .overlay(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).strokeBorder(on ? r.color : Palette.outline.opacity(0.28), lineWidth: 1))
                                }
                                .buttonStyle(.toy)
                            }
                        }
                    }

                    // Date & observation
                    VStack(spacing: 0) {
                        DatePicker(
                            L10n.t("初尝日期", "First tasted"),
                            selection: $tastedDate,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        Divider().padding(.leading, 14)

                        Toggle(isOn: $watchSkin) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(L10n.t("需留意皮肤或肠胃反应", "Watch for skin or tummy reaction"))
                                    .font(.subheadline.weight(.semibold))
                                Text(L10n.t("仅作日常观察标记，不适请咨询医生", "Personal note only — consult your doctor if concerned"))
                                    .font(.caption2)
                                    .foregroundStyle(Palette.secondaryText)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)

                        if existing != nil {
                            Divider().padding(.leading, 14)
                            HStack {
                                Text(L10n.t("尝过次数", "Times offered"))
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                HStack(spacing: 12) {
                                    Button {
                                        if times > 1 {
                                            TactileEngine.shared.beadClick()
                                            times -= 1
                                        }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(times > 1 ? Palette.accent : Palette.secondaryText.opacity(0.35))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(times <= 1)
                                    .accessibilityLabel(L10n.t("减少次数", "Decrease times"))

                                    Text("\(times)")
                                        .font(Typeface.numerals(17, relativeTo: .headline, weight: .bold))
                                        .frame(minWidth: 24)
                                        .multilineTextAlignment(.center)

                                    Button {
                                        TactileEngine.shared.beadClick()
                                        times += 1
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(Palette.accent)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(L10n.t("增加一次", "Increase times"))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }

                        if app.journal && existing == nil {
                            Divider().padding(.leading, 14)
                            Toggle(isOn: $alsoLogJournal) {
                                Text(L10n.t("同时记入今日「辅食」记录", "Also add to today's Care Journal"))
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                    }
                    .printCard(radius: Radius.card)

                    // How served note + quick chips
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t("做法与小记（可选）", "How Served & Note (Optional)"))
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Palette.secondaryText)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(prepChips, id: \.self) { chip in
                                Button {
                                    TactileEngine.shared.beadClick()
                                    note = note.isEmpty ? chip : "\(note)·\(chip)"
                                } label: {
                                    Text(chip)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(dark ? Palette.lampCard : Palette.card))
                                        .overlay(Capsule().strokeBorder(Palette.outline.opacity(0.3), lineWidth: 0.75))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        TextField(L10n.t("例如：蒸熟压泥拌了一勺母乳", "e.g. Steamed and mashed warm"), text: $note)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(dark ? Palette.lampCard : Palette.card))
                    }

                    if existing != nil {
                        Button(role: .destructive) {
                            store.remove(foodId: item.id)
                            dismiss()
                        } label: {
                            Text(L10n.t("清除这项初尝印章", "Remove Tasting Stamp"))
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                    }
                }
                .padding(16)
            }
            .pageBackground(tone: item.category.color)
            .navigationTitle(existing == nil ? L10n.t("盖下初尝印章", "Stamp First Taste") : L10n.t("编辑初尝记录", "Edit Taste"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("取消", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("盖章保存", "Save")) {
                        let rec = FoodRecord(
                            foodId: item.id,
                            firstTastedEpochDay: Day(tastedDate).epochDay,
                            reaction: reaction,
                            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                            watchSkin: watchSkin,
                            times: max(1, times)
                        )
                        store.save(rec)
                        if app.journal && existing == nil && alsoLogJournal {
                            let detail = rec.note.isEmpty ? item.name : "\(item.name) · \(rec.note)"
                            _ = j.record(LogEntry(type: LogType.solid, start: JournalFile.now(), detail: detail))
                        }
                        TactileEngine.shared.goldChime()
                        let keepsakes = store.tastedCount + CapsuleStore.shared.items.count
                        ReviewPromptGate.tryTrigger(
                            perform: { requestReview() },
                            isDarkMode: scheme == .dark,
                            isBedsideLamp: lamp,
                            keepsakeCount: keepsakes
                        )
                        onSaved(item.id)
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}

/// 3× cotton-paper First Foods Passport poster rendered lazily via `RenderedPoster`.
private struct FoodPassportPoster: View {
    let babyName: String
    let ageLabel: String
    let records: [String: FoodRecord]

    var body: some View {
        let paper = Color(hex: 0xFBF7F0)
        let ink = Color(hex: 0x241F1B)
        let teal = Color(hex: 0x0B7D74)
        let tasted = FoodItem.catalog.filter { records[$0.id] != nil }

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("\(babyName)的百味护照", "\(babyName)'s First Foods Passport"))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(ink)
                    Text(
                        ageLabel.isEmpty
                            ? L10n.t("已尝过 \(tasted.count) / \(FoodItem.catalog.count) 种味道", "\(tasted.count) of \(FoodItem.catalog.count) foods tasted")
                            : L10n.t("\(ageLabel) · 已尝过 \(tasted.count) / \(FoodItem.catalog.count) 种味道", "\(ageLabel) · \(tasted.count) of \(FoodItem.catalog.count) tasted")
                    )
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(teal)
                }
                Spacer()
            }

            // 6-category botanical summary dots
            HStack(spacing: 10) {
                ForEach(FoodCategory.allCases) { cat in
                    let count = tasted.filter { $0.category == cat }.count
                    HStack(spacing: 4) {
                        Circle()
                            .fill(count > 0 ? cat.color : cat.color.opacity(0.28))
                            .frame(width: 7, height: 7)
                        Text("\(count)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(count > 0 ? ink : ink.opacity(0.45))
                    }
                }
            }

            Divider().opacity(0.35)

            if tasted.isEmpty {
                Text(L10n.t("第一口辅食即将启程", "Ready for the very first bite"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(ink.opacity(0.6))
                    .padding(.vertical, 12)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 8) {
                    ForEach(tasted.prefix(24)) { item in
                        VStack(spacing: 3) {
                            FoodGlyphView(food: item, size: 26, flat: false)
                            Text(item.name)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(ink)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 10).fill(item.category.color.opacity(0.14)))
                    }
                }

                if tasted.count > 24 {
                    Text(L10n.t("+ \(tasted.count - 24) 种更多味道", "+\(tasted.count - 24) more tastes"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(teal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(teal.opacity(0.12)))
                }
            }

            Divider().opacity(0.3)

            Text(L10n.t("摸索台灯 · 孩子摸索，大人点灯", "Moss & Otto · They explore. You hold the light."))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(ink.opacity(0.5))
        }
        .padding(24)
        .frame(width: 360)
        .background(paper)
    }
}
