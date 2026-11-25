import SwiftUI
import StoreKit
import PhotosUI

/// 「百味食盒 / First Foods Tasting Cabinet」 — Interactive Montessori bento cabinet of 60 whole foods across 6 collapsible
/// botanical drawers with dual category + state rails, smart Next-Bite shuffle bench, thumb-zone Quick-Stamp Dock, and
/// 3× Tasting Passport poster export. Zero scores, zero guilt, offline-only.
struct FoodAtlasView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.requestReview) private var requestReview

    @State private var store: FoodAtlasStore
    @State private var selectedCategory: FoodCategory? = nil
    @State private var stateFilter: StateFilter = .all
    @State private var collapsedCategories: Set<FoodCategory> = []
    @State private var selectedFoodId: String? = nil
    @State private var suggestionOffset: Int = 0
    @State private var query = ""
    @State private var editingItem: FoodItem? = nil
    @State private var recentlyStampedId: String? = nil
    @State private var mossTapCount: Int = 0
    @State private var leafBurstTrigger: Int = 0

    enum StateFilter: String, CaseIterable, Identifiable {
        case all, untasted, allergen, loved, tryAgain
        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: L10n.t("全部", "All")
            case .untasted: L10n.t("未尝", "To Try")
            case .allergen: L10n.t("常见致敏", "Allergens")
            case .loved: L10n.t("很喜欢", "Loved")
            case .tryAgain: L10n.t("再试试", "Retry")
            }
        }

        func matches(_ item: FoodItem, record: FoodRecord?) -> Bool {
            switch self {
            case .all: true
            case .untasted: record == nil
            case .allergen: item.isCommonAllergen
            case .loved: record?.reaction == .loved
            case .tryAgain: record?.reaction == .tryAgain
            }
        }
    }

    @MainActor
    init(store: FoodAtlasStore? = nil, previewSelectedFoodId: String? = nil) {
        _store = State(initialValue: store ?? .shared)
        _selectedFoodId = State(initialValue: previewSelectedFoodId)
    }

    private func matchingItems(in category: FoodCategory? = nil) -> [FoodItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return FoodItem.catalog.filter { item in
            if let category, item.category != category { return false }
            let rec = store.record(for: item.id)
            guard stateFilter.matches(item, record: rec) else { return false }
            guard !q.isEmpty else { return true }
            return item.zh.localizedCaseInsensitiveContains(q)
                || item.en.localizedCaseInsensitiveContains(q)
                || item.category.title.localizedCaseInsensitiveContains(q)
        }
    }

    private func performQuickStamp(food: FoodItem, reaction: FoodReaction) {
        guard app.mayKeep() else { return }
        let wasUntasted = store.record(for: food.id) == nil
        _ = store.quickStamp(foodId: food.id, reaction: reaction, today: app.today)
        if wasUntasted && app.journal {
            _ = j.record(LogEntry(type: LogType.solid, start: JournalFile.now(), detail: food.name))
        }
        TactileEngine.shared.goldChime()
        triggerStampBounce(for: food.id)
        let keepsakes = store.tastedCount + CapsuleStore.shared.items.count
        ReviewPromptGate.tryTrigger(
            perform: { requestReview() },
            isDarkMode: scheme == .dark,
            isBedsideLamp: lamp,
            keepsakeCount: keepsakes
        )
    }

    private func triggerStampBounce(for foodId: String) {
        withAnimation(reduce ? nil : .spring(response: 0.42, dampingFraction: 0.56)) {
            recentlyStampedId = foodId
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1400))
            if recentlyStampedId == foodId {
                recentlyStampedId = nil
            }
        }
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        let who = app.nickname.isEmpty ? L10n.t("宝宝", "Baby") : app.nickname
        let snapshotRecords = store.records
        let ageLabel = app.age.map { L10n.ageText($0) } ?? ""
        let passportPoster = RenderedPoster {
            let stickers = FoodItem.catalog.reduce(into: [String: UIImage]()) { out, item in
                if let sticker = FoodStickerStore.load(for: item.id) {
                    out[item.id] = sticker
                }
            }
            let card = FoodPassportPoster(babyName: who, ageLabel: ageLabel, records: snapshotRecords, stickers: stickers)
            let renderer = ImageRenderer(content: card)
            renderer.scale = 3.0
            return renderer.uiImage
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = store.suggestedBiteCandidates()
        let nextCandidate = candidates.isEmpty ? nil : candidates[suggestionOffset % candidates.count]
        let columns: [GridItem] = type.isAccessibilitySize
            ? Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
            : Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

        let directItems = matchingItems(in: selectedCategory)
        let activeDrawers = FoodCategory.allCases.filter { !matchingItems(in: $0).isEmpty }

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                wreathHeroCard(dark: dark)

                if trimmedQuery.isEmpty, let candidate = nextCandidate {
                    nextBiteBench(candidate: candidate, dark: dark)
                }

                filterRails(dark: dark)

                if stateFilter == .allergen {
                    allergenCallout(dark: dark)
                }

                if selectedCategory == nil && trimmedQuery.isEmpty {
                    if activeDrawers.isEmpty {
                        emptyStateCard
                    } else {
                        ForEach(activeDrawers) { cat in
                            botanicalDrawer(
                                category: cat,
                                items: matchingItems(in: cat),
                                columns: columns,
                                dark: dark
                            )
                        }
                    }
                } else {
                    if directItems.isEmpty {
                        emptyStateCard
                    } else {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(directItems) { item in
                                specimenCell(item: item, dark: dark)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, selectedFoodId == nil ? 36 : 118)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.leaf)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: L10n.t("搜索 60 种食材…", "Search 60 foods…"))
        .navigationTitle(L10n.t("百味食盒", "First Foods"))
        .navigationBarTitleDisplayMode(.large)
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
        .safeAreaInset(edge: .bottom) {
            if let id = selectedFoodId, let activeItem = FoodItem.item(id: id) {
                quickStampDock(item: activeItem, dark: dark)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 6)
                    .transition(reduce ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $editingItem) { item in
            FoodTasteSheet(item: item, existing: store.record(for: item.id), store: store) { savedId in
                triggerStampBounce(for: savedId)
            }
            .lampPresented(sheet: true)
        }
    }

    // MARK: - Compact Interactive Hero

    private func wreathHeroCard(dark: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                FoodWreathCanvas(store: store, dark: dark)
                    .frame(width: 82, height: 82)
                VStack(spacing: 0) {
                    Ticking(text: "\(store.tastedCount)")
                        .font(Typeface.numerals(23, relativeTo: .title2, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("/ \(FoodItem.catalog.count)")
                        .font(Typeface.numerals(10, relativeTo: .caption2, weight: .semibold))
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
                        .frame(width: 34, height: 34)
                        .overlay { MintLeafBurst(trigger: leafBurstTrigger) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("摸一摸 Moss，轻点三次会飘出嫩芽", "Tap Moss gently — three taps drift out mint leaves"))
                }

                Text(
                    store.tastedCount == 0
                        ? L10n.t("轻点任意食材原地盖章。", "Tap any food below to quick-stamp.")
                        : L10n.t("已尝 \(store.tastedCount) 种 · \(store.lovedCount) 种很喜欢。", "\(store.tastedCount) explored · \(store.lovedCount) loved.")
                )
                .font(.caption)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

                // Self-explanatory 6-category icon + count micro-pills
                let catPills = ForEach(FoodCategory.allCases) { cat in
                    let c = store.tastedCount(in: cat)
                    let active = selectedCategory == cat
                    Button {
                        TactileEngine.shared.beadClick()
                        withAnimation(reduce ? nil : .snappy) {
                            selectedCategory = active ? nil : cat
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: cat.symbol)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(dark ? cat.color : Crayon.ink(cat.color))
                            Text("\(c)")
                                .font(Typeface.numerals(11, relativeTo: .caption2, weight: .bold))
                                .foregroundStyle(active ? Palette.accent : (c > 0 ? .primary : Palette.secondaryText))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule().fill(
                                active
                                    ? cat.color.opacity(dark ? 0.28 : 0.20)
                                    : cat.color.opacity(dark ? 0.12 : 0.10)
                            )
                        )
                        .overlay(
                            Capsule().strokeBorder(active ? cat.color.opacity(0.65) : .clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("\(cat.title)，已尝 \(c) / \(store.totalCount(in: cat))", "\(cat.title), \(c) of \(store.totalCount(in: cat)) tasted"))
                }

                Group {
                    if type.isAccessibilitySize {
                        FlowRow(spacing: 5, lineSpacing: 5) { catPills }
                    } else {
                        HStack(spacing: 4) { catPills }
                    }
                }
                .padding(.top, 1)
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Crayon.leaf.opacity(dark ? 0.14 : 0.14), Crayon.sunflower.opacity(dark ? 0.05 : 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .printCard(radius: Radius.card)
    }

    // MARK: - Next Bite Inspiration Bench

    private func nextBiteBench(candidate: FoodItem, dark: Bool) -> some View {
        let existing = store.record(for: candidate.id)
        let isRetry = existing?.reaction == .tryAgain
        let color = candidate.category.color
        let subtitle: String = if let existing, isRetry {
            L10n.t("温柔再试 · 已试过 \(max(1, existing.times)) 次", "Gentle retry · tried ×\(max(1, existing.times))")
        } else if candidate.isCommonAllergen {
            L10n.t("\(candidate.category.title) · 常见致敏建议白天试", "\(candidate.category.title) · offer earlier in the day")
        } else {
            L10n.t("今日试味灵感 · \(candidate.category.title)", "Next bite idea · \(candidate.category.title)")
        }

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.opacity(dark ? 0.28 : 0.18))
                    .frame(width: 42, height: 42)
                FoodEmblemArt(food: candidate, size: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(subtitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isRetry ? Crayon.ink(Crayon.sunflower) : (candidate.isCommonAllergen ? (dark ? Palette.amber : Crayon.ink(Palette.amber)) : Palette.secondaryText))
                    .lineLimit(1)
                Text(candidate.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                TactileEngine.shared.beadClick()
                withAnimation(reduce ? nil : .snappy) {
                    selectedFoodId = candidate.id
                }
            }

            Spacer(minLength: 4)

            Button {
                TactileEngine.shared.beadClick()
                withAnimation(reduce ? nil : .snappy) {
                    suggestionOffset += 1
                }
            } label: {
                Image(systemName: "arrow.trianglehead.2.clockwise")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.secondaryText)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(dark ? Color.white.opacity(0.08) : Palette.fill))
            }
            .buttonStyle(.toy)
            .accessibilityLabel(L10n.t("换一种推荐食材", "Shuffle next food idea"))

            Button {
                performQuickStamp(food: candidate, reaction: .tasted)
                withAnimation(reduce ? nil : .snappy) {
                    selectedFoodId = candidate.id
                }
            } label: {
                Text(isRetry ? L10n.t("再尝一次", "Retried") : L10n.t("尝到了", "Stamped"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Palette.accentFill))
            }
            .buttonStyle(.toy)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(color.opacity(dark ? 0.10 : 0.07))
        )
        .printCard(radius: Radius.card)
    }

    // MARK: - Unified Single-Row Filter & Drawer Control Strip

    private func filterRails(dark: Bool) -> some View {
        let isDrawerMode = selectedCategory == nil && query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let allCollapsed = collapsedCategories.count == FoodCategory.allCases.count

        return HStack(alignment: .top, spacing: 6) {
            FlowRow(spacing: 5, lineSpacing: 5) {
                if let activeCat = selectedCategory {
                    Button {
                        TactileEngine.shared.beadClick()
                        withAnimation(reduce ? nil : .snappy) {
                            selectedCategory = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: activeCat.symbol)
                                .font(.system(size: 10, weight: .bold))
                            Text(activeCat.title)
                                .font(.caption.weight(.bold))
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Palette.accentFill))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("清除分类筛选 \(activeCat.title)", "Clear category filter \(activeCat.title)"))
                }

                ForEach(StateFilter.allCases) { sf in
                    let on = stateFilter == sf
                    let label: String = switch sf {
                    case .allergen: L10n.t("致敏 \(store.allergenIntroducedCount)/\(store.allergenTotalCount)", "Allergens \(store.allergenIntroducedCount)/\(store.allergenTotalCount)")
                    case .loved where store.lovedCount > 0: "\(sf.label) \(store.lovedCount)"
                    case .tryAgain where store.tryAgainCount > 0: "\(sf.label) \(store.tryAgainCount)"
                    default: sf.label
                    }
                    Button {
                        TactileEngine.shared.beadClick()
                        withAnimation(reduce ? nil : .snappy) {
                            stateFilter = sf
                        }
                    } label: {
                        Text(label)
                            .font(.caption.weight(on ? .bold : .semibold))
                            .foregroundStyle(on ? Crayon.ink(Palette.accent) : Palette.secondaryText)
                            .padding(.horizontal, 8.5)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(on ? Palette.accent.opacity(dark ? 0.22 : 0.14) : (dark ? Color.white.opacity(0.06) : Palette.fill.opacity(0.8))))
                            .overlay(Capsule().strokeBorder(on ? Palette.accent.opacity(0.45) : .clear, lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 1)

            if isDrawerMode {
                Button {
                    TactileEngine.shared.beadClick()
                    withAnimation(reduce ? nil : CalmMotion.accordionSpring) {
                        collapsedCategories = allCollapsed ? [] : Set(FoodCategory.allCases)
                    }
                } label: {
                    Image(systemName: allCollapsed ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.secondaryText)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(dark ? Color.white.opacity(0.08) : Palette.fill.opacity(0.85)))
                }
                .buttonStyle(.toy)
                .accessibilityLabel(allCollapsed ? L10n.t("展开全部抽屉", "Expand all drawers") : L10n.t("收起全部抽屉", "Collapse all drawers"))
            }
        }
    }

    private func allergenCallout(dark: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Palette.lampTint)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("已尝 \(store.allergenIntroducedCount) / \(store.allergenTotalCount) 种常见致敏食材", "\(store.allergenIntroducedCount) of \(store.allergenTotalCount) common allergens introduced"))
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

    // MARK: - Collapsible Botanical Bento Drawers & Specimen Grid

    private func botanicalDrawer(category: FoodCategory, items: [FoodItem], columns: [GridItem], dark: Bool) -> some View {
        let expanded = !collapsedCategories.contains(category)
        let done = store.tastedCount(in: category)
        let total = max(1, store.totalCount(in: category))
        let frac = min(1.0, Double(done) / Double(total))

        return CalmAccordion(
            isExpanded: expanded,
            spacing: 10,
            onToggle: {
                if expanded {
                    collapsedCategories.insert(category)
                } else {
                    collapsedCategories.remove(category)
                }
            }
        ) { isOpen in
            HStack(spacing: 8) {
                IconTile(symbol: category.symbol, color: category.color, size: 24, round: true)
                Text(category.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(category.color.opacity(dark ? 0.20 : 0.16))
                        .frame(width: 44, height: 5)
                    Capsule()
                        .fill(category.color)
                        .frame(width: max(done > 0 ? 5 : 0, 44 * frac), height: 5)
                }
                Text("\(done)/\(total)")
                    .font(Typeface.numerals(11, relativeTo: .caption2, weight: .bold))
                    .foregroundStyle(Palette.secondaryText)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isOpen ? 0 : -90))
            }
            .frame(minHeight: 36)
        } content: {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(items) { item in
                    specimenCell(item: item, dark: dark)
                }
            }
        }
        .padding(12)
        .printCard(radius: Radius.card)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func specimenCell(item: FoodItem, dark: Bool) -> some View {
        let rec = store.record(for: item.id)
        return FoodSpecimenChip(
            item: item,
            record: rec,
            dark: dark,
            isSelected: selectedFoodId == item.id,
            justStamped: recentlyStampedId == item.id
        ) {
            TactileEngine.shared.beadClick()
            withAnimation(reduce ? nil : .snappy) {
                selectedFoodId = (selectedFoodId == item.id) ? nil : item.id
            }
        }
        .contextMenu {
            ForEach(FoodReaction.allCases) { r in
                Button(r.title, systemImage: r.symbol) {
                    performQuickStamp(food: item, reaction: r)
                    selectedFoodId = item.id
                }
            }
            Divider()
            Button(L10n.t("详细记录与做法…", "Edit date & notes…"), systemImage: "square.and.pencil") {
                if app.mayKeep() {
                    editingItem = item
                }
            }
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 8) {
            Creature(kind: .moss, mood: .open, look: CGPoint(x: 0.4, y: 0.2), alive: false)
                .frame(width: 52, height: 52)
            Text(!query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                 ? L10n.t("没有找到「\(query)」", "No foods matching \"\(query)\"")
                 : L10n.t("这一筛选暂时没有食材", "No foods match this filter"))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
            Button(L10n.t("显示全部 60 种", "Show all 60 foods")) {
                withAnimation(reduce ? nil : .snappy) {
                    query = ""
                    selectedCategory = nil
                    stateFilter = .all
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Palette.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .printCard(radius: Radius.card)
    }

    // MARK: - Inline Thumb-Zone Quick-Stamp Dock

    private func quickStampDock(item: FoodItem, dark: Bool) -> some View {
        let rec = store.record(for: item.id)
        let color = item.category.color
        let statusLine: String = if let rec {
            L10n.t("\(rec.firstTastedDay.md) · 已试 \(max(1, rec.times)) 次", "\(rec.firstTastedDay.md) · tried ×\(max(1, rec.times))")
        } else {
            L10n.t("轻点下方表情即刻盖章", "Tap a stamp below to log right here")
        }

        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.opacity(dark ? 0.28 : 0.18))
                        .frame(width: 36, height: 36)
                    FoodEmblemArt(food: item, size: 24)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(statusLine)
                        .font(.caption2)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                if rec != nil {
                    Button {
                        TactileEngine.shared.beadClick()
                        _ = store.incrementTimes(foodId: item.id)
                        triggerStampBounce(for: item.id)
                    } label: {
                        Text("+1")
                            .font(Typeface.numerals(12, relativeTo: .caption, weight: .bold))
                            .foregroundStyle(Crayon.ink(color))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(color.opacity(dark ? 0.22 : 0.14)))
                    }
                    .buttonStyle(.toy)
                    .accessibilityLabel(L10n.t("尝过次数加一", "Add one tasting"))
                }
                Button {
                    if app.mayKeep() {
                        TactileEngine.shared.beadClick()
                        editingItem = item
                    }
                } label: {
                    Text(L10n.t("详情", "Edit"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Palette.accent.opacity(dark ? 0.20 : 0.12)))
                }
                .buttonStyle(.toy)
                Button {
                    TactileEngine.shared.beadClick()
                    withAnimation(reduce ? nil : .snappy) {
                        selectedFoodId = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Palette.secondaryText)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(dark ? Color.white.opacity(0.08) : Palette.fill))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.t("收起快捷盖章栏", "Close quick-stamp dock"))
            }

            HStack(spacing: 8) {
                ForEach(FoodReaction.allCases) { r in
                    let on = rec?.reaction == r
                    Button {
                        performQuickStamp(food: item, reaction: r)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: r.symbol)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(on ? .white : r.color)
                            Text(r.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(on ? .white : .primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(on ? r.color : (dark ? Color.white.opacity(0.07) : Palette.fill.opacity(0.75))))
                    }
                    .buttonStyle(.toy)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(dark ? Palette.lampCard : Palette.card)
                .shadow(color: .black.opacity(dark ? 0.42 : 0.14), radius: 14, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(color.opacity(dark ? 0.38 : 0.28), lineWidth: 1)
        )
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
            let lineW: CGFloat = 8.0
            let cats = FoodCategory.allCases
            let gap = 0.12
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

/// Botanical mint leaves fluttering upward when the user pokes Moss three times in the tasting box header or story theater.
struct MintLeafBurst: View {
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

/// Compact 4-column specimen chip inside each botanical drawer: zero redundant category repetition.
private struct FoodSpecimenChip: View {
    let item: FoodItem
    let record: FoodRecord?
    let dark: Bool
    var isSelected: Bool = false
    var justStamped: Bool = false
    let tap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        let tasted = record != nil
        let catColor = item.category.color
        let watch = record?.watchSkin == true
        let times = max(1, record?.times ?? 1)

        return Button(action: tap) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        if justStamped && !reduce {
                            Circle()
                                .strokeBorder(Palette.bead.opacity(0.68), lineWidth: 2)
                                .frame(width: 44, height: 44)
                                .transition(.scale.combined(with: .opacity))
                        }
                        Circle()
                            .fill(
                                tasted
                                    ? catColor.opacity(dark ? 0.26 : 0.18)
                                    : (dark ? Color.white.opacity(0.05) : Palette.fill.opacity(0.72))
                            )
                            .frame(width: 38, height: 38)
                        FoodEmblemArt(food: item, size: 26)
                            .saturation(tasted ? 1.0 : 0.78)
                            .opacity(tasted ? 1.0 : 0.88)
                    }
                    .phaseAnimator(reduce ? [1.0] : [1.0, 1.16, 0.96, 1.03, 1.0], trigger: justStamped) { view, scale in
                        view.scaleEffect(scale)
                    }
                    .overlay(alignment: .topLeading) {
                        if watch {
                            Circle()
                                .fill(Palette.amber)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().strokeBorder(dark ? Palette.lampCard : .white, lineWidth: 1.2))
                                .offset(x: -1, y: -1)
                        }
                    }

                    if let rec = record {
                        Image(systemName: rec.reaction.symbol)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(rec.reaction.color))
                            .overlay(Circle().strokeBorder(dark ? Palette.lampCard : .white, lineWidth: 1.2))
                            .offset(x: 3, y: -2)
                    } else if item.isCommonAllergen {
                        Circle()
                            .fill(Palette.amber)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().strokeBorder(dark ? Palette.lampCard : .white, lineWidth: 1.1))
                            .offset(x: 1, y: 1)
                    }
                }

                Text(item.name)
                    .font(.caption.weight(tasted ? .bold : .semibold))
                    .foregroundStyle(tasted ? .primary : Palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                if let rec = record {
                    if watch {
                        Text(times >= 2 ? L10n.t("留意·×\(times)", "Watch·×\(times)") : L10n.t("留意", "Watch"))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(dark ? Palette.amber : Crayon.ink(Palette.amber))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else {
                        Text(times >= 2 ? "×\(times)" : rec.firstTastedDay.md)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(Palette.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                } else if item.isCommonAllergen {
                    Text(L10n.t("致敏", "Allergen"))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(dark ? Palette.amber : Crayon.ink(Palette.amber))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 76, maxHeight: .infinity, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                    .fill(
                        isSelected
                            ? catColor.opacity(dark ? 0.22 : 0.14)
                            : (tasted ? catColor.opacity(dark ? 0.12 : 0.08) : (dark ? Color.white.opacity(0.04) : Palette.background.opacity(0.72)))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                    .strokeBorder(
                        isSelected
                            ? Palette.accent
                            : (tasted ? catColor.opacity(dark ? 0.50 : 0.40) : Palette.outline.opacity(0.18)),
                        lineWidth: isSelected ? 1.8 : (tasted ? 1.2 : 0.65)
                    )
            )
            .scaleEffect(isSelected && !reduce ? 1.03 : 1.0)
        }
        .buttonStyle(.toy)
        .frame(maxHeight: .infinity)
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

/// Renders an offline Vision die-cut food sticker when captured for `food`, falling back to handcrafted artwork.
struct FoodEmblemArt: View {
    let food: FoodItem
    var size: CGFloat = 32
    var flat: Bool = (ArtStyle.current == .flat)
    var overrideSticker: UIImage? = nil

    private var stickerVersion: FoodStickerVersion { FoodStickerVersion.shared }

    var body: some View {
        let _ = stickerVersion.tick
        if let sticker = overrideSticker ?? FoodStickerStore.load(for: food.id) {
            Image(uiImage: sticker)
                .resizable()
                .scaledToFit()
                .frame(width: size * 1.18, height: size * 1.18)
                .accessibilityHidden(true)
        } else {
            FoodGlyphView(food: food, size: size, flat: flat)
        }
    }
}

/// Quick tactile stamp sheet for logging or updating a baby's first taste of a food.
private struct FoodTasteSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.accessibilityReduceMotion) private var reduce
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
    @State private var pickedPhotoItem: PhotosPickerItem? = nil
    @State private var cuttingSticker = false
    @State private var customSticker: UIImage? = nil

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
                    // Dish emblem header with offline Vision subject cutout sticker picker
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(item.category.color.opacity(dark ? 0.28 : 0.18))
                                .frame(width: 62, height: 62)
                            if cuttingSticker {
                                Circle()
                                    .strokeBorder(Palette.amber.opacity(0.85), lineWidth: 2.2)
                                    .frame(width: 62, height: 62)
                            }
                            FoodEmblemArt(food: item, size: 42, overrideSticker: customSticker)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.title2.weight(.bold))
                            Text(
                                cuttingSticker
                                    ? L10n.t("正在本机抠出贴纸…", "Cutting sticker locally…")
                                    : (item.category.title + (item.isCommonAllergen ? L10n.t(" · 常见致敏", " · Allergen") : ""))
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(cuttingSticker ? Palette.accent : (item.isCommonAllergen ? (dark ? Palette.amber : Crayon.ink(Palette.amber)) : Palette.secondaryText))

                            if customSticker != nil {
                                Button {
                                    TactileEngine.shared.beadClick()
                                    FoodStickerStore.delete(for: item.id)
                                    withAnimation(reduce ? nil : .snappy) {
                                        customSticker = nil
                                    }
                                } label: {
                                    Text(L10n.t("恢复手绘图标", "Restore drawn icon"))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Palette.secondaryText)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Spacer(minLength: 4)

                        PhotosPicker(selection: $pickedPhotoItem, matching: .images, photoLibrary: .shared()) {
                            HStack(spacing: 4) {
                                Image(systemName: customSticker == nil ? "sparkles" : "arrow.trianglehead.2.clockwise")
                                    .font(.caption2.weight(.bold))
                                Text(customSticker == nil ? L10n.t("拍成贴纸", "Sticker") : L10n.t("换贴纸", "Replace"))
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Palette.accentFill))
                        }
                        .buttonStyle(.toy)
                        .disabled(cuttingSticker)
                        .accessibilityLabel(L10n.t("选一张实物照片本机抠成辅食贴纸", "Pick a food photo to cut into an offline sticker"))
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
            .onAppear {
                customSticker = FoodStickerStore.load(for: item.id)
            }
            .onChange(of: pickedPhotoItem) { _, newItem in
                guard let newItem else { return }
                cuttingSticker = true
                let targetId = item.id
                Task { @MainActor in
                    defer {
                        cuttingSticker = false
                        pickedPhotoItem = nil
                    }
                    guard let data = try? await newItem.loadTransferable(type: Data.self),
                          let rawImage = UIImage(data: data) else {
                        return
                    }
                    let sticker = await VisionSubjectCutout.extractDieCutSticker(from: rawImage)
                    if FoodStickerStore.save(sticker, for: targetId) {
                        withAnimation(reduce ? nil : .spring(response: 0.42, dampingFraction: 0.62)) {
                            customSticker = sticker
                        }
                        TactileEngine.shared.goldChime()
                    }
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
    var stickers: [String: UIImage] = [:]

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
                            FoodEmblemArt(food: item, size: 26, flat: false, overrideSticker: stickers[item.id])
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
