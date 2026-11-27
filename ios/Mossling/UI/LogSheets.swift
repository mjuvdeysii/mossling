import SwiftUI

/// Pure suggestion & time-nudge helpers shared by `AskSheet` and `EntrySheet`.
enum CareEntryHelpers {
    /// Merges recently tasted & loved foods from `FoodAtlasStore` ahead of fallback staples without duplicates.
    static func solidChips(from records: [String: FoodRecord], staples: [String], limit: Int = 6) -> [String] {
        let ranked = records.values
            .sorted { lhs, rhs in
                let lScore = lhs.reaction == .loved ? 2 : (lhs.reaction == .tasted ? 1 : 0)
                let rScore = rhs.reaction == .loved ? 2 : (rhs.reaction == .tasted ? 1 : 0)
                if lScore != rScore { return lScore > rScore }
                if lhs.firstTastedEpochDay != rhs.firstTastedEpochDay {
                    return lhs.firstTastedEpochDay > rhs.firstTastedEpochDay
                }
                return lhs.times > rhs.times
            }
            .compactMap { FoodItem.item(id: $0.foodId)?.name }

        var seen = Set<String>()
        var result: [String] = []
        for name in ranked + staples where !name.isEmpty {
            if seen.insert(name).inserted {
                result.append(name)
                if result.count >= limit + staples.count { break }
            }
        }
        return Array(result.prefix(max(staples.count, 8)))
    }

    /// Shifts an entry start (and preserves its timed duration when `end != nil`), clamping safely to `<= now`.
    static func shiftStart(startMs: Double, endMs: Double?, byMinutes deltaMin: Int, nowMs: Double) -> (start: Double, end: Double?) {
        let deltaMs = Double(deltaMin) * 60_000
        let clampedStart = min(nowMs, max(0, startMs + deltaMs))
        guard let endMs else { return (clampedStart, nil) }
        let dur = max(60_000, endMs - startMs)
        let clampedEnd = min(nowMs, max(clampedStart + 60_000, clampedStart + dur))
        return (clampedStart, clampedEnd)
    }

    static func temperatureStatus(tenthsC: Int) -> (label: String, tint: Color, isFever: Bool) {
        if tenthsC >= 380 {
            return (L10n.t("发热警戒 · ≥38.0°C", "Fever alert · ≥38.0 °C"), Palette.danger, true)
        }
        if tenthsC >= 375 {
            return (L10n.t("偏高 · 留意复测", "Slightly warm · recheck"), Crayon.tangerine, false)
        }
        return (L10n.t("体温平稳", "Normal range"), Crayon.leaf, false)
    }
}

/// The page that follows a record button, made for each kind: a bottle, a nappy, a temperature, food or a note at an
/// exact time (now unless changed), then one tap — said back at the top with 撤销. (A feed or a sleep has its own
/// page, TimerScreen.)
struct AskSheet: View {
    @Environment(JournalStore.self) private var j
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lamp) private var lamp
    @Environment(\.colorScheme) private var scheme
    let type: String
    /// Opened from a past day's page: the time starts on that day (noon), not now.
    var on: Date? = nil
    @State private var when = Date()
    @State private var ml = 120.0
    @State private var temp = 368
    @State private var text = ""
    @State private var milk = "formula"
    @State private var failed = false
    /// 3D world: minutes before saving (nil when an exact time was chosen), and the exact time.
    @State private var ago: Int? = 0
    @State private var chosen: String?
    @State private var saved = 0
    @FocusState private var typing: Bool

    private var at: Date { ago.map { Date().addingTimeInterval(-Double($0) * 60) } ?? when }
    private var tempC: Binding<Double> { Binding(get: { Double(temp) / 10 }, set: { temp = Int(($0 * 10).rounded()) }) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    CareStage(type: type)
                    LastLine(type: type)
                    // what is being recorded first (the amount, the temperature, the food), when second — it is
                    // 现在 almost always; a nappy is saved by its choice, so its time comes before it
                    if type == LogType.diaper { when_; content } else { content; when_ }
                    if failed { SaveFailed() }
                }
                .padding(20)
            }
            .safeAreaBar(edge: .bottom) { saveBar }
            .navigationBarTitleDisplayMode(.inline)   // the name is on the stage
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.t("取消", "Cancel"), systemImage: "xmark") { dismiss() } } }
            .background { PageBackground(tone: LogType.color(type)) }
        }
        .presentationDetents([.large])
        .localConsentSheet()
        .sensoryFeedback(.success, trigger: saved)
        .onAppear { if let on { ago = nil; when = on } }
        .onAppear { if type == LogType.bottle, let b = j.logs.first(where: { $0.type == LogType.bottle }) { if let a = b.amount { ml = Double(a) }; if let d = b.detail, ["breastmilk", "formula"].contains(d) { milk = d } } }
    }

    @ViewBuilder private var when_: some View {
        WhenChips(ago: $ago, exact: $when, tint: LogType.color(type))
    }

    @ViewBuilder private var content: some View {
        let c = LogType.color(type)
        let dark = lamp || scheme == .dark
        switch type {
        case LogType.bottle:
            HStack(spacing: 12) {
                ChoiceTile(sticker: "ic_heart_fill.webp", symbol: "heart.fill", title: L10n.t("母乳", "Breast milk"), on: milk == "breastmilk", tint: Crayon.pink, height: 78) { withAnimation(.snappy) { milk = "breastmilk" } }
                ChoiceTile(sticker: "ic_waterbottle_fill.webp", symbol: "waterbottle.fill", title: L10n.t("配方奶", "Formula"), on: milk == "formula", tint: Crayon.peach, height: 78) { withAnimation(.snappy) { milk = "formula" } }
            }
            HStack(alignment: .center, spacing: 16) {
                LevelGauge(vessel: .bottle, value: $ml, range: 5...300, step: 5, marks: [60, 120, 180, 240, 300], label: { "\(Int($0))" },
                           tint: c, liquid: milk == "breastmilk" ? Color(hex: 0xFFF6E2) : Color(hex: 0xF6E2BC))
                    .frame(width: 112, height: 252)
                VStack(alignment: .leading, spacing: 12) {
                    ValueText(parts: [("\(Int(ml))", L10n.t("毫升", "ml"))], size: 52).foregroundStyle(lamp ? Palette.lampInk : Color.primary)
                    Text(L10n.t("点按或上下拖动奶瓶", "Tap or drag the bottle")).font(.footnote).foregroundStyle(Palette.secondaryText)
                    FlowChips(items: [60, 90, 120, 150, 180].map { ($0, "\($0)") }, selected: Int(ml), tint: c) { v in
                        TactileEngine.shared.beadClick()
                        withAnimation(.snappy) { ml = Double(v) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .printCard(radius: Radius.card, fill: dark ? Palette.lampCard : Palette.card)
        case LogType.diaper:
            Text(L10n.t("点一下即记下", "Tap one to log")).font(.subheadline).foregroundStyle(Palette.secondaryText)
            HStack(spacing: 10) {
                ForEach([("wet", L10n.t("湿", "Wet"), "drop.halffull", "ic_drop_halffull.webp"), ("dirty", L10n.t("便", "Dirty"), "circle.fill", "ic_diaper_dirty.webp"), ("both", L10n.t("都有", "Both"), "circle.lefthalf.filled", "ic_diaper_both.webp")], id: \.0) { k, t, sym, art in
                    ChoiceTile(sticker: art, symbol: sym, title: t, on: chosen == k, tint: c, height: 116) {
                        guard app.mayKeep(), chosen == nil else { return }
                        withAnimation(.snappy) { chosen = k }
                        if j.record(LogEntry(type: LogType.diaper, start: ms(at), detail: k)) {
                            saved += 1
                            Task { @MainActor in try? await Task.sleep(for: .milliseconds(320)); dismiss() }
                        } else { chosen = nil; failed = true }
                    }
                }
            }
        case LogType.temp:
            let status = CareEntryHelpers.temperatureStatus(tenthsC: temp)
            HStack(alignment: .center, spacing: 16) {
                LevelGauge(vessel: .thermometer, value: tempC, range: 34...42.5, step: 0.1, marks: [35, 36, 37, 38, 39, 40, 41, 42], label: { "\(Int($0))" },
                           tint: Crayon.tangerine, alarm: 38)
                    .frame(width: 96, height: 268)
                VStack(alignment: .leading, spacing: 12) {
                    Text(status.label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Crayon.ink(status.tint))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(status.tint.opacity(dark ? 0.20 : 0.13)))
                    ValueText(parts: [(String(format: "%.1f", Double(temp) / 10), "°C")], size: 52)
                        .foregroundStyle(temp >= 380 ? Palette.danger : lamp ? Palette.lampInk : .primary)
                    Text(L10n.t("点按或上下拖动体温计", "Tap or drag the thermometer")).font(.footnote).foregroundStyle(Palette.secondaryText)
                    // a fever is not only a red number: what to do is said under it, in the sourced words of 发热就医
                    // (AAP, checked 2026-10-17), and the doctor has the last word
                    if temp >= 380 {
                        let feverNote = app.content.health.first { $0.topic == "发热就医" || $0.topic.localizedCaseInsensitiveContains("fever") }?.text
                            ?? L10n.t("未满3个月体温达到或超过38.0°C，应立即联系医生或就医。", "Under 3 months, a temperature of 38.0 °C (100.4 °F) or higher calls for prompt medical advice.")
                        Text(feverNote + L10n.t("以医生的判断为准。", " Always follow your doctor's advice."))
                            .font(.footnote.weight(.semibold)).foregroundStyle(Palette.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    NudgeButtons(value: tempC, range: 34...42.5, step: 0.1, tint: temp >= 380 ? Palette.danger : c)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .printCard(radius: Radius.card, fill: dark ? Palette.lampCard : Palette.card)
        default:
            let stapleFoods = L10n.isEnglish
                ? ["Cereal", "Veggie purée", "Fruit purée", "Meat purée", "Egg yolk", "Oatmeal"]
                : ["米粉", "蔬菜泥", "水果泥", "肉泥", "蛋黄", "粥"]
            let solidQuick = CareEntryHelpers.solidChips(from: FoodAtlasStore.shared.records, staples: stapleFoods)
            let (title, hint, chips): (String, String, [String]) = type == LogType.solid
                ? (L10n.t("吃了什么", "What did they eat?"), L10n.t("食物和大概的量", "Food and rough amount"), solidQuick)
                : type == LogType.medicine
                ? (L10n.t("用了什么药", "Medicine"), L10n.t("药名与剂量，按医嘱或说明书", "Name and dose, per doctor or label"),
                   L10n.isEnglish ? ["Vitamin D", "Vitamin AD", "Saline drops"] : ["维生素 D", "维生素 AD", "生理盐水"])
                : (L10n.t("备注", "Note"), L10n.t("发生了什么", "What happened?"), [])
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title).font(.headline)
                    Spacer(minLength: 8)
                    if type == LogType.solid && !FoodAtlasStore.shared.records.isEmpty {
                        Text(L10n.t("含百味食盒最近食材", "Includes First Foods"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Palette.secondaryText)
                    }
                }
                TextField(hint, text: $text, axis: .vertical)
                    .lineLimit(type == LogType.note ? 3...6 : 1...3)
                    .focused($typing)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                            .fill(dark ? Palette.lampCard : Palette.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                            .strokeBorder(Palette.outline.opacity(dark ? 0.25 : 0.20), lineWidth: 0.75)
                    )
                if !chips.isEmpty {
                    let sep = L10n.t("、", ", ")
                    FlowChips(items: chips.enumerated().map { ($0.offset, $0.element) }, selected: nil, tint: c) { i in
                        TactileEngine.shared.beadClick()
                        text = text.isEmpty ? chips[i] : text + sep + chips[i]
                    }
                }
            }
        }
    }

    /// What 记下 saves for this kind, and whether it can yet (a nappy saves on its own choice, so has none).
    private var submit: (enabled: Bool, run: () -> Bool)? {
        switch type {
        case LogType.diaper: return nil
        case LogType.bottle: return (true, { j.record(LogEntry(type: LogType.bottle, start: ms(at), amount: Int(ml), detail: milk)) })
        case LogType.temp: return (true, { j.record(LogEntry(type: LogType.temp, start: ms(at), amount: temp)) })
        default:
            return (!text.trimmingCharacters(in: .whitespaces).isEmpty || type == LogType.solid, {
                typing = false
                return j.record(LogEntry(type: type, start: ms(at), detail: text.trimmingCharacters(in: .whitespacesAndNewlines)))
            })
        }
    }

    /// Saves and closes; if the save fails the page stays open with everything as typed, and says so. It stays in
    /// view at the foot of the sheet whatever is above it — a one-handed parent never scrolls to find it.
    @ViewBuilder private var saveBar: some View {
        if let s = submit {
            Button {
                guard app.mayKeep() else { return }
                if s.run() { saved += 1; dismiss() } else { failed = true }
            } label: { Text(L10n.t("记下", "Save")).frame(maxWidth: .infinity) }
                .buttonStyle(.vinyl(LogType.color(type), prominent: true, large: true)).disabled(!s.enabled)
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 6)
        }
    }
}

func ms(_ d: Date) -> Double { d.timeIntervalSince1970 * 1000 }

/// Choices that wrap onto the next line rather than scroll sideways.
struct FlowChips<T: Hashable>: View {
    let items: [(T, String)]
    let selected: T?
    var tint: Color = Palette.accent
    let pick: (T) -> Void
    var body: some View {
        WrapLayout(spacing: 8) {
            ForEach(items, id: \.0) { v, t in
                let on = selected == v
                Button { pick(v) } label: { Text(t).monospacedDigit() }
                    .buttonStyle(.vinyl(on ? tint : Crayon.pebble))
                    .fontWeight(on ? .semibold : .regular)
                    .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// Lays children out in rows, wrapping to the next row when a row is full.
struct WrapLayout: Layout {
    var spacing: CGFloat = 8
    private func fittedSize(for s: LayoutSubview, maxWidth: CGFloat?) -> CGSize {
        let natural = s.sizeThatFits(.unspecified)
        guard let maxWidth, maxWidth.isFinite, maxWidth > 0, natural.width > maxWidth else {
            return natural
        }
        let constrained = s.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
        return CGSize(width: min(constrained.width, maxWidth), height: constrained.height)
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let finiteWidth = proposal.width.flatMap { ($0.isFinite && $0 > 0) ? $0 : nil }
        let w = finiteWidth ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let z = fittedSize(for: s, maxWidth: finiteWidth)
            if x > 0 && x + z.width > w { x = 0; y += row + spacing; row = 0 }
            x += z.width + spacing; row = max(row, z.height); maxX = max(maxX, x - spacing)
        }
        return CGSize(width: finiteWidth ?? maxX, height: y + row)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth: CGFloat? = b.width > 0 ? b.width : proposal.width.flatMap { ($0.isFinite && $0 > 0) ? $0 : nil }
        var x = b.minX, y = b.minY, row: CGFloat = 0
        for s in subviews {
            let z = fittedSize(for: s, maxWidth: maxWidth)
            if x > b.minX && x + z.width > b.maxX { x = b.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(z))
            x += z.width + spacing; row = max(row, z.height)
        }
    }
}

/// One entry, to change or to add after the fact: exact start (and end), the amount, side or kind, the text.
struct EntrySheet: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lamp) private var lamp
    @Environment(\.colorScheme) private var scheme
    @State var entry: LogEntry
    @State private var failed = false
    @State private var saved = 0
    let isNew: Bool
    /// A breast feed of two sides is opened whole: its sides, oldest first, one of them being edited (`entry`).
    @State private var parts: [LogEntry]
    @State private var sel: Int
    private let original: [LogEntry]
    init(entry: LogEntry, isNew: Bool, feed: [LogEntry] = []) {
        let ps = feed.count > 1 ? feed : [entry]
        _entry = State(initialValue: entry); self.isNew = isNew
        _parts = State(initialValue: ps); original = ps
        _sel = State(initialValue: ps.firstIndex { $0.id == entry.id } ?? 0)
    }
    private var whole: Bool { parts.count > 1 }
    /// The sides as they stand now, the one being edited included.
    private var current: [LogEntry] { var p = parts; if p.indices.contains(sel) { p[sel] = entry }; return p }
    private func choose(_ i: Int) {
        TactileEngine.shared.beadClick()
        var p = parts; p[sel] = entry; parts = p; sel = i; entry = p[i]
    }
    private func save() -> Bool {
        if isNew { return j.record(entry) }
        // nothing changed: nothing written, nothing said
        if !whole { return entry == original.first ? true : j.update([entry]) }
        // the sides of one feed are written together: all or none, with one 撤销
        let changed: [LogEntry] = zip(current, original).filter { $0.0 != $0.1 }.map(\.0)
        return changed.isEmpty ? true : j.update(changed, feed: true)
    }

    var body: some View {
        let c = LogType.color(entry.type)
        let dark = lamp || scheme == .dark
        let cardFill = dark ? Palette.lampCard : Palette.card
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if failed { SaveFailed() }

                    // Tactile summary header card
                    HStack(spacing: 14) {
                        IconTile(symbol: LogType.symbol(entry.type), color: c, size: 52, round: true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(LogType.name(entry.type)).font(.title3.weight(.bold))
                            if whole {
                                let cur = current
                                Text(hm(cur[0].startDate) + " · " + durationValue(cur.reduce(0) { $0 + $1.activeSeconds }))
                                    .font(.subheadline).foregroundStyle(Palette.secondaryText).monospacedDigit()
                                Text(cur.map { ($0.side == "r" ? L10n.t("右侧 ", "Right ") : L10n.t("左侧 ", "Left ")) + durationValue($0.activeSeconds) }.joined(separator: " · "))
                                    .font(.footnote).foregroundStyle(Palette.secondaryText).monospacedDigit()
                            } else {
                                let valueText = entry.value(on: Day(entry.startDate))
                                Text(valueText.isEmpty ? hm(entry.startDate) : hm(entry.startDate) + " · " + valueText)
                                    .font(.subheadline).foregroundStyle(Palette.secondaryText).monospacedDigit()
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .printCard(radius: Radius.card, fill: c.opacity(dark ? 0.22 : 0.16))

                    if isNew {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.t("记录类型", "Kind"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.secondaryText)
                            let kinds = LogType.buttons.filter { $0 != LogType.growth }
                            FlowChips(items: kinds.map { ($0, LogType.name($0)) }, selected: entry.type, tint: c) { t in
                                switchKind(to: t)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .printCard(radius: Radius.card, fill: cardFill)
                    }

                    if whole {
                        HStack(spacing: 10) {
                            ForEach(parts.indices, id: \.self) { i in
                                let part = current[i]
                                let active = sel == i
                                let sideLabel = part.side == "r" ? L10n.t("右侧", "Right") : L10n.t("左侧", "Left")
                                Button {
                                    withAnimation(.snappy) { choose(i) }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(active ? c : Palette.secondaryText.opacity(0.35))
                                                .frame(width: 8, height: 8)
                                            Text(L10n.t("第 \(i + 1) 段 · \(sideLabel)", "Part \(i + 1) · \(sideLabel)"))
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.primary)
                                        }
                                        Text(hm(part.startDate) + " · " + durationValue(part.activeSeconds))
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(Palette.secondaryText)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                                            .fill(active ? c.opacity(dark ? 0.22 : 0.14) : cardFill)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                                            .strokeBorder(active ? c : Palette.outline.opacity(0.22), lineWidth: active ? 1.5 : 0.75)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(active ? .isSelected : [])
                            }
                        }
                    }

                    timeCard(color: c, cardFill: cardFill, dark: dark)

                    fieldsCard(color: c, cardFill: cardFill, dark: dark)

                    if !isNew {
                        Button(role: .destructive) {
                            if whole { j.delete(original) } else { j.delete(entry) }
                            dismiss()
                        } label: {
                            Label(whole ? L10n.t("删除这一顿", "Delete feed") : L10n.t("删除这条", "Delete entry"), systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.danger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .printCard(radius: Radius.card, fill: cardFill)
                    }
                }
                .padding(16)
            }
            .safeAreaBar(edge: .bottom) {
                Button {
                    guard app.mayKeep() else { return }
                    if save() { saved += 1; dismiss() } else { failed = true }
                } label: {
                    Text(L10n.t("保存", "Save")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.vinyl(c, prominent: true, large: true))
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 6)
            }
            .pageBackground(tone: c)
            .navigationTitle((isNew ? L10n.t("补记 · ", "Add · ") : "") + LogType.name(entry.type))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.t("取消", "Cancel"), systemImage: "xmark") { dismiss() } }
            }
        }
        .localConsentSheet()
        .sensoryFeedback(.success, trigger: saved)
    }

    @ViewBuilder private func timeCard(color: Color, cardFill: Color, dark: Bool) -> some View {
        let now = Date()
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.t("时间", "Time")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                Spacer(minLength: 8)
                if entry.end != nil {
                    Text(minutesOf(entry.activeSeconds))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(Crayon.ink(color))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(color.opacity(dark ? 0.22 : 0.14)))
                }
            }

            DatePicker(entry.end != nil ? L10n.t("开始", "Start") : L10n.t("时刻", "At"), selection: Binding(get: { min(entry.startDate, now) }, set: { d in
                let delta = ms(d) - entry.start
                entry.start = ms(d)
                if let e = entry.end { entry.end = min(ms(Date()), max(entry.start + 60_000, e + delta)) }
            }), in: ...now, displayedComponents: [.date, .hourAndMinute])

            if let e = entry.endDate {
                let endLower = min(entry.startDate, now)
                DatePicker(L10n.t("结束", "End"), selection: Binding(get: { min(max(e, endLower), now) }, set: { entry.end = max(entry.start + 60_000, ms($0)) }),
                           in: endLower...now, displayedComponents: [.date, .hourAndMinute])
            }

            HStack(spacing: 8) {
                ForEach([(-15, L10n.t("-15 分钟", "-15m")), (-5, L10n.t("-5 分钟", "-5m")), (5, L10n.t("+5 分钟", "+5m"))], id: \.0) { delta, label in
                    Button {
                        TactileEngine.shared.beadClick()
                        let shifted = CareEntryHelpers.shiftStart(startMs: entry.start, endMs: entry.end, byMinutes: delta, nowMs: ms(Date()))
                        withAnimation(.snappy) {
                            entry.start = shifted.start
                            entry.end = shifted.end
                        }
                    } label: {
                        Text(label)
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.vinyl(color))
                }
            }
        }
        .padding(16)
        .printCard(radius: Radius.card, fill: cardFill)
    }

    @ViewBuilder private func fieldsCard(color: Color, cardFill: Color, dark: Bool) -> some View {
        switch entry.type {
        case LogType.bottle:
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ChoiceTile(sticker: "ic_heart_fill.webp", symbol: "heart.fill", title: L10n.t("母乳", "Breast milk"), on: entry.detail == "breastmilk", tint: Crayon.pink, height: 74) {
                        TactileEngine.shared.beadClick()
                        withAnimation(.snappy) { entry.detail = entry.detail == "breastmilk" ? nil : "breastmilk" }
                    }
                    ChoiceTile(sticker: "ic_waterbottle_fill.webp", symbol: "waterbottle.fill", title: L10n.t("配方奶", "Formula"), on: entry.detail == "formula", tint: Crayon.peach, height: 74) {
                        TactileEngine.shared.beadClick()
                        withAnimation(.snappy) { entry.detail = entry.detail == "formula" ? nil : "formula" }
                    }
                }
                let amount = Binding<Double>(get: { Double(entry.amount ?? 120) }, set: { entry.amount = Int($0) })
                HStack(spacing: 16) {
                    LevelGauge(vessel: .bottle, value: amount, range: 5...300, step: 5, marks: [60, 120, 180, 240, 300], label: { "\(Int($0))" },
                               tint: color, liquid: entry.detail == "breastmilk" ? Color(hex: 0xFFF6E2) : Color(hex: 0xF6E2BC))
                        .frame(width: 96, height: 210)
                    VStack(alignment: .leading, spacing: 12) {
                        ValueText(parts: [("\(entry.amount ?? 120)", L10n.t("毫升", "ml"))], size: 42)
                        NudgeButtons(value: amount, range: 5...300, step: 5, tint: color)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .printCard(radius: Radius.card, fill: cardFill)
        case LogType.nurse:
            HStack(spacing: 10) {
                ForEach([("l", L10n.t("左侧", "Left")), ("r", L10n.t("右侧", "Right"))], id: \.0) { k, t in
                    ChoiceTile(sticker: nil, symbol: k == "l" ? "arrow.left.circle.fill" : "arrow.right.circle.fill", title: t, on: (entry.side ?? "l") == k, tint: color, height: 78) {
                        TactileEngine.shared.beadClick()
                        withAnimation(.snappy) { entry.side = k }
                    }
                    .accessibilityLabel(t)
                }
            }
        case LogType.diaper:
            HStack(spacing: 10) {
                ForEach([("wet", L10n.t("湿", "Wet"), "drop.halffull", "ic_drop_halffull.webp"), ("dirty", L10n.t("便", "Dirty"), "circle.fill", "ic_diaper_dirty.webp"), ("both", L10n.t("都有", "Both"), "circle.lefthalf.filled", "ic_diaper_both.webp")], id: \.0) { k, t, sym, art in
                    ChoiceTile(sticker: art, symbol: sym, title: t, on: (entry.detail ?? "wet") == k, tint: color, height: 98) {
                        TactileEngine.shared.beadClick()
                        withAnimation(.snappy) { entry.detail = k }
                    }
                }
            }
        case LogType.temp:
            let tenths = entry.amount ?? 368
            let t = Binding<Double>(get: { Double(tenths) / 10 }, set: { entry.amount = Int(($0 * 10).rounded()) })
            let status = CareEntryHelpers.temperatureStatus(tenthsC: tenths)
            HStack(spacing: 16) {
                LevelGauge(vessel: .thermometer, value: t, range: 34...42.5, step: 0.1, marks: [35, 36, 37, 38, 39, 40, 41, 42], label: { "\(Int($0))" }, tint: Crayon.tangerine, alarm: 38)
                    .frame(width: 88, height: 224)
                VStack(alignment: .leading, spacing: 10) {
                    Text(status.label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(status.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(status.tint.opacity(dark ? 0.20 : 0.13)))
                    ValueText(parts: [(String(format: "%.1f", Double(tenths) / 10), "°C")], size: 42)
                        .foregroundStyle(tenths >= 380 ? Palette.danger : .primary)
                    NudgeButtons(value: t, range: 34...42.5, step: 0.1, tint: tenths >= 380 ? Palette.danger : color)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .printCard(radius: Radius.card, fill: cardFill)
        case LogType.solid, LogType.medicine, LogType.note:
            let hint = entry.type == LogType.solid
                ? L10n.t("食物和大概的量", "Food and rough amount")
                : entry.type == LogType.medicine
                ? L10n.t("药名与剂量", "Name and dose")
                : L10n.t("发生了什么", "What happened?")
            VStack(alignment: .leading, spacing: 10) {
                Text(LogType.name(entry.type)).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                TextField(hint, text: Binding(get: { entry.detail ?? "" }, set: { entry.detail = String($0.prefix(120)) }), axis: .vertical)
                    .lineLimit(entry.type == LogType.note ? 3...6 : 1...3)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(dark ? Palette.lampPage : Palette.paper))
                    .overlay(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).strokeBorder(Palette.outline.opacity(0.20), lineWidth: 0.75))
            }
            .padding(16)
            .printCard(radius: Radius.card, fill: cardFill)
        default: EmptyView()
        }
    }

    private func switchKind(to t: String) {
        guard t != entry.type else { return }
        TactileEngine.shared.beadClick()
        withAnimation(.snappy) {
            entry.type = t
            entry.amount = nil
            entry.detail = nil
            entry.side = nil
            if LogType.timed.contains(t) {
                if entry.end == nil {
                    entry.end = min(JournalFile.now(), entry.start + 20 * 60_000)
                }
                if t == LogType.nurse {
                    entry.side = "l"
                }
            } else {
                entry.end = nil
                if t == LogType.bottle {
                    entry.amount = 120
                    entry.detail = "formula"
                } else if t == LogType.diaper {
                    entry.detail = "wet"
                } else if t == LogType.temp {
                    entry.amount = 368
                }
            }
        }
    }
}

/// Pure parsing, gram-to-kg conversion, previous-delta formatting, and WHO reference range helpers for `MeasureSheet`.
enum MeasureParser {
    struct WeightParse: Equatable {
        let grams: Int?
        let convertedFromGrams: Bool
        let invalid: Bool
    }

    struct MetricParse: Equatable {
        let mm: Int?
        let invalid: Bool
    }

    private static func normalizedDouble(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "，", with: ".")
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }

    static func parseWeightGrams(_ raw: String) -> WeightParse {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return WeightParse(grams: nil, convertedFromGrams: false, invalid: false) }
        guard let v = normalizedDouble(trimmed), v.isFinite else {
            return WeightParse(grams: nil, convertedFromGrams: false, invalid: true)
        }
        let converted = v > 300
        let kg = converted ? v / 1000.0 : v
        guard (1.0...30.0).contains(kg) else {
            return WeightParse(grams: nil, convertedFromGrams: false, invalid: true)
        }
        return WeightParse(grams: Int((kg * 1000.0).rounded()), convertedFromGrams: converted, invalid: false)
    }

    static func parseLengthMm(_ raw: String) -> MetricParse {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return MetricParse(mm: nil, invalid: false) }
        guard let v = normalizedDouble(trimmed), v.isFinite, (35.0...120.0).contains(v) else {
            return MetricParse(mm: nil, invalid: true)
        }
        return MetricParse(mm: Int((v * 10.0).rounded()), invalid: false)
    }

    static func parseHeadMm(_ raw: String) -> MetricParse {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return MetricParse(mm: nil, invalid: false) }
        guard let v = normalizedDouble(trimmed), v.isFinite, (25.0...60.0).contains(v) else {
            return MetricParse(mm: nil, invalid: true)
        }
        return MetricParse(mm: Int((v * 10.0).rounded()), invalid: false)
    }

    static func value(in m: Measure, for indicator: Indicator) -> Double? {
        switch indicator {
        case .weight: return m.weightG.map { Double($0) / 1000.0 }
        case .length: return m.lengthMm.map { Double($0) / 10.0 }
        case .head: return m.headMm.map { Double($0) / 10.0 }
        }
    }

    static func previousValue(for indicator: Indicator, excluding id: UUID, before timestampMs: Double, in measures: [Measure]) -> Double? {
        measures
            .filter { $0.id != id && $0.at < timestampMs }
            .sorted { $0.at < $1.at }
            .compactMap { value(in: $0, for: indicator) }
            .last
    }

    static func deltaLabel(current: Double, previous: Double?, indicator: Indicator) -> String? {
        guard let previous else { return nil }
        let diff = current - previous
        let sign = diff >= 0 ? "+" : "-"
        let mag = abs(diff)
        let formatted = indicator.fmt(mag)
        let unit = indicator == .weight ? "kg" : "cm"
        return L10n.t("较上次 \(sign)\(formatted) \(unit)", "\(sign)\(formatted) \(unit) vs last")
    }

    static func ageMonths(on date: Date, birth: Day?) -> Double? {
        guard let birth else { return nil }
        let months = Double(birth.days(to: Day(date))) / 30.4375
        return (0.0...36.0).contains(months) ? months : nil
    }

    static func typicalRange(for indicator: Indicator, date: Date, birth: Day?, sex: String?, growth: Growth) -> ClosedRange<Double>? {
        guard let sex, let months = ageMonths(on: date, birth: birth) else { return nil }
        let girl = sex == "girl"
        let lo = growth.at(indicator, girl: girl, months: months, percentile: 15)
        let hi = growth.at(indicator, girl: girl, months: months, percentile: 85)
        guard lo.isFinite, hi.isFinite, lo < hi else { return nil }
        return lo...hi
    }

    static func percentileLabel(for indicator: Indicator, value: Double, date: Date, birth: Day?, sex: String?, growth: Growth) -> String? {
        guard let sex, let months = ageMonths(on: date, birth: birth), value > 0 else { return nil }
        let p = growth.percentile(indicator, girl: sex == "girl", months: months, value: value)
        guard p.isFinite else { return nil }
        return pctText(p)
    }
}

/// Weight, length and head circumference on one day, framed as a tactile Montessori Measuring Tray.
struct MeasureSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lamp) private var lamp
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduce

    let measure: Measure
    let isNew: Bool
    @State private var day = Date()
    @State private var w = ""
    @State private var l = ""
    @State private var h = ""
    @State private var failed = false
    @FocusState private var focused: Indicator?

    private var dayNoonMs: Double {
        ms(Day.cal.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day)
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        let refBirth = GrowthView.developmentalBirth(for: Measure(at: dayNoonMs), birth: app.birth, gestationalWeeks: app.gestationalWeeks)
        let weightParsed = MeasureParser.parseWeightGrams(w)
        let lengthParsed = MeasureParser.parseLengthMm(l)
        let headParsed = MeasureParser.parseHeadMm(h)
        let wg = weightParsed.grams
        let lm = lengthParsed.mm
        let hm = headParsed.mm
        let hasInvalid = weightParsed.invalid || lengthParsed.invalid || headParsed.invalid
        let canSave = (wg != nil || lm != nil || hm != nil) && !hasInvalid

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if failed { SaveFailed() }

                    dateTray(dark: dark)

                    MeasureScaleCard(
                        indicator: .weight,
                        text: $w,
                        parsedValue: wg.map { Double($0) / 1000.0 },
                        range: 1.0...30.0,
                        nudgeStep: 0.05,
                        rulerStep: 0.05,
                        majorTick: 5.0,
                        minorTick: 1.0,
                        noteText: weightParsed.invalid
                            ? L10n.t("体重请在 1–30 千克之间", "Weight must be between 1 and 30 kg")
                            : (weightParsed.convertedFromGrams && wg != nil
                                ? L10n.t("已按克换算为 ", "Converted from grams: ") + String(format: "%.2f", Double(wg!) / 1000.0) + L10n.t(" 千克", " kg")
                                : L10n.t("拖动标尺粗调，或点数字精确输入（如 7.85）", "Drag the wooden ruler or tap numerals for exact input (e.g. 7.85)")),
                        isError: weightParsed.invalid,
                        previousValue: MeasureParser.previousValue(for: .weight, excluding: measure.id, before: dayNoonMs, in: j.measures),
                        typicalRange: MeasureParser.typicalRange(for: .weight, date: day, birth: refBirth, sex: app.sex, growth: app.growth),
                        percentileText: wg.flatMap { MeasureParser.percentileLabel(for: .weight, value: Double($0) / 1000.0, date: day, birth: refBirth, sex: app.sex, growth: app.growth) },
                        dark: dark,
                        focused: $focused
                    )

                    MeasureScaleCard(
                        indicator: .length,
                        text: $l,
                        parsedValue: lm.map { Double($0) / 10.0 },
                        range: 35.0...120.0,
                        nudgeStep: 0.1,
                        rulerStep: 0.5,
                        majorTick: 10.0,
                        minorTick: 2.0,
                        noteText: lengthParsed.invalid
                            ? L10n.t("身长请在 35–120 厘米之间", "Length must be between 35 and 120 cm")
                            : L10n.t("精确到 0.1 厘米；2 岁前躺着量身长", "To 0.1 cm; measure lying down under age 2"),
                        isError: lengthParsed.invalid,
                        previousValue: MeasureParser.previousValue(for: .length, excluding: measure.id, before: dayNoonMs, in: j.measures),
                        typicalRange: MeasureParser.typicalRange(for: .length, date: day, birth: refBirth, sex: app.sex, growth: app.growth),
                        percentileText: lm.flatMap { MeasureParser.percentileLabel(for: .length, value: Double($0) / 10.0, date: day, birth: refBirth, sex: app.sex, growth: app.growth) },
                        dark: dark,
                        focused: $focused
                    )

                    MeasureScaleCard(
                        indicator: .head,
                        text: $h,
                        parsedValue: hm.map { Double($0) / 10.0 },
                        range: 25.0...60.0,
                        nudgeStep: 0.1,
                        rulerStep: 0.2,
                        majorTick: 5.0,
                        minorTick: 1.0,
                        noteText: headParsed.invalid
                            ? L10n.t("头围请在 25–60 厘米之间", "Head circumference must be between 25 and 60 cm")
                            : L10n.t("经眉上缘与后脑最突出处绕量", "Above eyebrows around the widest back of head"),
                        isError: headParsed.invalid,
                        previousValue: MeasureParser.previousValue(for: .head, excluding: measure.id, before: dayNoonMs, in: j.measures),
                        typicalRange: MeasureParser.typicalRange(for: .head, date: day, birth: refBirth, sex: app.sex, growth: app.growth),
                        percentileText: hm.flatMap { MeasureParser.percentileLabel(for: .head, value: Double($0) / 10.0, date: day, birth: refBirth, sex: app.sex, growth: app.growth) },
                        dark: dark,
                        focused: $focused
                    )

                    if !isNew {
                        Button(role: .destructive) {
                            j.deleteMeasure(measure)
                            dismiss()
                        } label: {
                            Label(L10n.t("删除这次测量", "Delete measurement"), systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.danger)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                        .printCard(radius: Radius.card, fill: dark ? Palette.lampCard : Palette.card)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .pageBackground(tone: Crayon.tangerine)
            .navigationTitle(isNew ? L10n.t("记一次测量", "Log Measurement") : L10n.t("这次测量", "Measurement"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaBar(edge: .bottom) {
                Button {
                    focused = nil
                    guard app.mayKeep() else { return }
                    var m = measure
                    m.at = dayNoonMs
                    m.weightG = wg
                    m.lengthMm = lm
                    m.headMm = hm
                    if j.saveMeasure(m) {
                        TactileEngine.shared.beadClick()
                        dismiss()
                    } else {
                        failed = true
                    }
                } label: {
                    Label(isNew ? L10n.t("记下这次测量", "Save Measurement") : L10n.t("保存修改", "Save Changes"), systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.vinyl(Crayon.tangerine, prominent: true, large: true))
                .disabled(!canSave)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 6)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("取消", "Cancel"), systemImage: "xmark") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L10n.t("完成", "Done")) { focused = nil }
                        .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            day = Date(timeIntervalSince1970: measure.at / 1000)
            w = measure.weightG.map { String(format: "%.2f", Double($0) / 1000) } ?? ""
            l = measure.lengthMm.map { String(format: "%.1f", Double($0) / 10) } ?? ""
            h = measure.headMm.map { String(format: "%.1f", Double($0) / 10) } ?? ""
        }
        .localConsentSheet()
    }

    private func dateTray(dark: Bool) -> some View {
        let measuredDay = Day(day)
        let ageLabel = app.birth.map { Firsts.age(from: $0, to: measuredDay) }
        return HStack(spacing: 12) {
            IconTile(symbol: "calendar", color: Crayon.tangerine, size: 34, round: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("测量日期", "Measurement Date"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let ageLabel {
                    Text(ageLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Crayon.ink(Crayon.tangerine))
                }
            }
            Spacer(minLength: 8)
            let now = Date()
            let lower = min(app.birth?.date ?? .distantPast, now)
            DatePicker(L10n.t("日期", "Date"), selection: $day, in: lower...now, displayedComponents: .date)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .printCard(radius: Radius.card, fill: dark ? Palette.lampCard : Palette.card)
    }
}

/// Tactile Montessori wooden-ruler card for one growth metric (direct keyboard entry + fine +/- nudge + scrubbable ruler).
private struct MeasureScaleCard: View {
    let indicator: Indicator
    @Binding var text: String
    let parsedValue: Double?
    let range: ClosedRange<Double>
    let nudgeStep: Double
    let rulerStep: Double
    let majorTick: Double
    let minorTick: Double
    let noteText: String
    let isError: Bool
    let previousValue: Double?
    let typicalRange: ClosedRange<Double>?
    let percentileText: String?
    let dark: Bool
    var focused: FocusState<Indicator?>.Binding

    @Environment(\.dynamicTypeSize) private var typeSize

    private var defaultSeedValue: Double {
        if let previousValue, range.contains(previousValue) { return previousValue }
        if let typicalRange {
            let mid = (typicalRange.lowerBound + typicalRange.upperBound) / 2.0
            return min(range.upperBound, max(range.lowerBound, mid))
        }
        return (range.lowerBound + range.upperBound) / 2.0
    }

    private func writeValue(_ val: Double) {
        let clamped = min(range.upperBound, max(range.lowerBound, val))
        text = indicator.fmt(clamped)
    }

    private func nudge(_ delta: Double) {
        let base = parsedValue ?? defaultSeedValue
        let next = min(range.upperBound, max(range.lowerBound, ((base + delta) / nudgeStep).rounded() * nudgeStep))
        writeValue(next)
        TactileEngine.shared.beadClick()
    }

    var body: some View {
        let tint = indicator.tint
        let deltaStr = parsedValue.flatMap { MeasureParser.deltaLabel(current: $0, previous: previousValue, indicator: indicator) }

        VStack(alignment: .leading, spacing: 10) {
            // Header + Live Delta & Percentile Badges
            HStack(alignment: .center, spacing: 10) {
                IconTile(symbol: indicator.symbol, color: tint, size: 32, round: true)
                Text(indicator.label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                if !text.isEmpty {
                    Button {
                        text = ""
                        TactileEngine.shared.beadClick()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondaryText.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("清空\(indicator.short)", "Clear \(indicator.short)"))
                }
            }

            // Direct Numeral Input + Nudge Controls
            HStack(alignment: .center, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    TextField("—", text: $text)
                        .keyboardType(.decimalPad)
                        .focused(focused, equals: indicator)
                        .font(Typeface.numerals(30, relativeTo: .title, weight: .bold))
                        .foregroundStyle(isError ? Palette.danger : (parsedValue != nil ? (dark ? Palette.lampInk : Crayon.ink(tint)) : Palette.secondaryText))
                        .multilineTextAlignment(.leading)
                        .frame(minWidth: 74, maxWidth: 112)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                                .fill(tint.opacity(dark ? 0.14 : 0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                                .strokeBorder(focused.wrappedValue == indicator ? tint : tint.opacity(0.24), lineWidth: focused.wrappedValue == indicator ? 1.5 : 1)
                        )
                    Text(indicator.unit)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize()
                }

                Spacer(minLength: 4)

                HStack(spacing: 8) {
                    nudgeButton("minus", -nudgeStep)
                        .accessibilityLabel(L10n.t("减少\(indicator.short)", "Decrease \(indicator.short)"))
                    nudgeButton("plus", nudgeStep)
                        .accessibilityLabel(L10n.t("增加\(indicator.short)", "Increase \(indicator.short)"))
                }
            }

            // Live State Badges (Previous Delta & WHO Percentile)
            if deltaStr != nil || percentileText != nil {
                FlowRow(spacing: 6, lineSpacing: 6) {
                    if let deltaStr {
                        pillBadge(deltaStr, color: tint)
                    }
                    if let percentileText {
                        pillBadge(percentileText, color: Crayon.teal)
                    }
                }
            }

            // Interactive Montessori Wooden Ruler Scrubber
            WoodenRulerScrubber(
                value: Binding(
                    get: { parsedValue },
                    set: { next in
                        if let next { writeValue(next) }
                    }
                ),
                defaultValue: defaultSeedValue,
                range: range,
                step: rulerStep,
                majorTick: majorTick,
                minorTick: minorTick,
                tint: tint,
                previousValue: previousValue,
                typicalRange: typicalRange,
                dark: dark
            )
            .frame(height: 44)
            .accessibilityLabel(indicator.label)
            .accessibilityValue(parsedValue.map { "\(indicator.fmt($0)) \(indicator.unit)" } ?? L10n.t("未填写", "Not set"))
            .accessibilityAdjustableAction { dir in
                switch dir {
                case .increment: nudge(nudgeStep)
                case .decrement: nudge(-nudgeStep)
                @unknown default: break
                }
            }

            // Helper / Validation Note
            Text(noteText)
                .font(.caption)
                .foregroundStyle(isError ? Palette.danger : Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .printCard(radius: Radius.card, fill: dark ? Palette.lampCard : Palette.card)
    }

    private func nudgeButton(_ symbol: String, _ delta: Double) -> some View {
        let cur = parsedValue ?? defaultSeedValue
        let disabled = delta < 0 ? cur <= range.lowerBound : cur >= range.upperBound
        return Button {
            focused.wrappedValue = nil
            nudge(delta)
        } label: {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .frame(width: 40, height: 36)
        }
        .buttonStyle(.vinyl(indicator.tint))
        .buttonRepeatBehavior(.enabled)
        .disabled(disabled)
    }

    private func pillBadge(_ label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(dark ? Palette.lampInk : Crayon.ink(color))
                .monospacedDigit()
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(dark ? 0.22 : 0.12)))
    }
}

/// Scrubbable birch-and-paper ruler track with optional WHO 15–85th reference band and previous measurement marker.
private struct WoodenRulerScrubber: View {
    @Binding var value: Double?
    let defaultValue: Double
    let range: ClosedRange<Double>
    let step: Double
    let majorTick: Double
    let minorTick: Double
    let tint: Color
    let previousValue: Double?
    let typicalRange: ClosedRange<Double>?
    let dark: Bool

    @GestureState private var draggingHorizontal = false

    private func x(for val: Double, width: CGFloat) -> CGFloat {
        let pad: CGFloat = 10
        let span = max(1, width - pad * 2)
        let frac = CGFloat((val - range.lowerBound) / (range.upperBound - range.lowerBound))
        return pad + min(1, max(0, frac)) * span
    }

    private func value(at px: CGFloat, width: CGFloat) -> Double {
        let pad: CGFloat = 10
        let span = max(1, width - pad * 2)
        let frac = Double(min(1, max(0, (px - pad) / span)))
        let raw = range.lowerBound + frac * (range.upperBound - range.lowerBound)
        let snapped = (raw / step).rounded() * step
        return min(range.upperBound, max(range.lowerBound, snapped))
    }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            Canvas { ctx, s in
                let trackRect = CGRect(x: 0, y: 6, width: s.width, height: s.height - 12)
                let wood = dark ? Color(hex: 0x262C4A) : Color(hex: 0xF3EADB)
                let border = dark ? Color.white.opacity(0.12) : Color(hex: 0xDFD2BC)
                ctx.fill(Path(roundedRect: trackRect, cornerRadius: 10, style: .continuous), with: .color(wood))
                ctx.stroke(Path(roundedRect: trackRect, cornerRadius: 10, style: .continuous), with: .color(border), lineWidth: 1)

                // WHO 15th–85th percentile soft reference band for child's age/sex
                if let typicalRange {
                    let x0 = x(for: max(range.lowerBound, typicalRange.lowerBound), width: s.width)
                    let x1 = x(for: min(range.upperBound, typicalRange.upperBound), width: s.width)
                    if x1 > x0 {
                        let bandRect = CGRect(x: x0, y: trackRect.minY + 3, width: x1 - x0, height: trackRect.height - 6)
                        ctx.fill(Path(roundedRect: bandRect, cornerRadius: 6), with: .color(tint.opacity(dark ? 0.24 : 0.16)))
                    }
                }

                // Graduated ruler ticks
                let tickColor = (dark ? Palette.lampInk : Color(hex: 0x6B5A48)).opacity(0.45)
                var tickVal = (range.lowerBound / minorTick).rounded(.up) * minorTick
                while tickVal <= range.upperBound + 1e-6 {
                    let tx = x(for: tickVal, width: s.width)
                    let isMajor = abs((tickVal / majorTick).rounded() * majorTick - tickVal) < 1e-4
                    let h: CGFloat = isMajor ? 12 : 6
                    var p = Path()
                    p.move(to: CGPoint(x: tx, y: trackRect.maxY - h))
                    p.addLine(to: CGPoint(x: tx, y: trackRect.maxY))
                    ctx.stroke(p, with: .color(tickColor.opacity(isMajor ? 0.8 : 0.45)), lineWidth: isMajor ? 1.3 : 0.9)
                    tickVal += minorTick
                }

                // Ghost marker for previous measurement
                if let previousValue, range.contains(previousValue) {
                    let px = x(for: previousValue, width: s.width)
                    var gp = Path()
                    gp.move(to: CGPoint(x: px, y: trackRect.minY + 4))
                    gp.addLine(to: CGPoint(x: px, y: trackRect.maxY - 4))
                    ctx.stroke(gp, with: .color(tint.opacity(0.55)), style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2.5]))
                }

                // Active sliding cursor bead
                let active = value ?? defaultValue
                let cx = x(for: min(range.upperBound, max(range.lowerBound, active)), width: s.width)
                let hasValue = value != nil
                var needle = Path()
                needle.move(to: CGPoint(x: cx, y: trackRect.minY + 1))
                needle.addLine(to: CGPoint(x: cx, y: trackRect.maxY - 1))
                ctx.stroke(needle, with: .color(hasValue ? tint : tint.opacity(0.45)), lineWidth: 2.2)

                let beadSize: CGFloat = hasValue ? 15 : 11
                let beadRect = CGRect(x: cx - beadSize / 2, y: s.height / 2 - beadSize / 2, width: beadSize, height: beadSize)
                ctx.fill(
                    Path(ellipseIn: beadRect),
                    with: .radialGradient(
                        Gradient(colors: [hasValue ? tint.mix(with: .white, by: 0.35) : Palette.stone, hasValue ? tint : Palette.stone.opacity(0.8)]),
                        center: CGPoint(x: beadRect.minX + beadSize * 0.35, y: beadRect.minY + beadSize * 0.3),
                        startRadius: 0,
                        endRadius: beadSize
                    )
                )
                ctx.stroke(Path(ellipseIn: beadRect), with: .color(.white.opacity(0.9)), lineWidth: 1.5)
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { tap in
                        let next = value(at: tap.location.x, width: size.width)
                        if value != next {
                            value = next
                            TactileEngine.shared.beadClick()
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .updating($draggingHorizontal) { g, state, _ in
                        if !state && abs(g.translation.width) >= abs(g.translation.height) * 0.85 {
                            state = true
                        }
                    }
                    .onChanged { g in
                        guard draggingHorizontal || abs(g.translation.width) >= abs(g.translation.height) * 0.85 else { return }
                        let next = value(at: g.location.x, width: size.width)
                        if value != next {
                            value = next
                            TactileEngine.shared.beadClick()
                        }
                    }
            )
        }
    }
}

extension Indicator {
    var tint: Color { switch self { case .weight: Crayon.tangerine; case .length: Crayon.sky; case .head: Crayon.aqua } }
    var symbol: String { switch self { case .weight: "scalemass.fill"; case .length: "ruler.fill"; case .head: "circle.dashed" } }
}

/// Said in the page when a save did not happen: what to do, in plain words. The companions do nothing (no reply to a
/// failure); what was typed stays.
struct SaveFailed: View {
    var body: some View {
        Label { Text(L10n.t("没有保存成功，填写的内容还在，请再点一次。如果反复出现，请检查 iPhone 的存储空间。", "Could not save — your entry is still here. Try again, or check available iPhone storage if this keeps happening.")).fixedSize(horizontal: false, vertical: true) }
            icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.danger) }
            .font(.subheadline)
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
            .accessibilityElement(children: .combine)
    }
}
