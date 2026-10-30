import SwiftUI

/// The page that follows a record button, made for each kind: a bottle, a nappy, a temperature, food or a note at an
/// exact time (now unless changed), then one tap — said back at the top with 撤销. (A feed or a sleep has its own
/// page, TimerScreen.)
struct AskSheet: View {
    @Environment(JournalStore.self) private var j
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lamp) private var lamp
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
        let c = LogType.color(type)
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
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消", systemImage: "xmark") { dismiss() } } }
            .background { PageBackground(tone: LogType.color(type)) }
        }
        .presentationDetents([.large])
        .sensoryFeedback(.success, trigger: saved)
        .onAppear { if let on { ago = nil; when = on } }
        .onAppear { if type == LogType.bottle, let b = j.logs.first(where: { $0.type == LogType.bottle }) { if let a = b.amount { ml = Double(a) }; if let d = b.detail, ["breastmilk", "formula"].contains(d) { milk = d } } }
    }

    @ViewBuilder private var when_: some View {
        WhenChips(ago: $ago, exact: $when, tint: LogType.color(type))
    }

    @ViewBuilder private var content: some View {
        let c = LogType.color(type)
        switch type {
        case LogType.bottle:
            HStack(spacing: 12) {
                ChoiceTile(sticker: "ic_heart_fill.webp", symbol: "heart.fill", title: "母乳", on: milk == "breastmilk", tint: Crayon.pink, height: 78) { withAnimation(.snappy) { milk = "breastmilk" } }
                ChoiceTile(sticker: "ic_waterbottle_fill.webp", symbol: "waterbottle.fill", title: "配方奶", on: milk == "formula", tint: Crayon.peach, height: 78) { withAnimation(.snappy) { milk = "formula" } }
            }
            HStack(alignment: .center, spacing: 16) {
                LevelGauge(vessel: .bottle, value: $ml, range: 5...300, step: 5, marks: [60, 120, 180, 240, 300], label: { "\(Int($0))" },
                           tint: c, liquid: milk == "breastmilk" ? Color(hex: 0xFFF6E2) : Color(hex: 0xF6E2BC))
                    .frame(width: 112, height: 252)
                VStack(alignment: .leading, spacing: 12) {
                    ValueText(parts: [("\(Int(ml))", "毫升")], size: 52).foregroundStyle(lamp ? Palette.lampInk : Color.primary)
                    Text("点按或上下拖动奶瓶").font(.footnote).foregroundStyle(Palette.secondaryText)
                    FlowChips(items: [60, 90, 120, 150, 180].map { ($0, "\($0)") }, selected: Int(ml), tint: c) { v in withAnimation(.snappy) { ml = Double(v) } }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .printCard(radius: Radius.card, fill: lamp ? Palette.lampCard : Palette.card)
        case LogType.diaper:
            Text("点一下即记下").font(.subheadline).foregroundStyle(Palette.secondaryText)
            HStack(spacing: 10) {
                ForEach([("wet", "湿", "drop.halffull", "ic_drop_halffull.webp"), ("dirty", "便", "circle.fill", "ic_diaper_dirty.webp"), ("both", "都有", "circle.lefthalf.filled", "ic_diaper_both.webp")], id: \.0) { k, t, sym, art in
                    ChoiceTile(sticker: art, symbol: sym, title: t, on: chosen == k, tint: c, height: 116) {
                        guard chosen == nil else { return }
                        withAnimation(.snappy) { chosen = k }
                        if j.record(LogEntry(type: LogType.diaper, start: ms(at), detail: k)) {
                            saved += 1
                            Task { @MainActor in try? await Task.sleep(for: .milliseconds(320)); dismiss() }
                        } else { chosen = nil; failed = true }
                    }
                }
            }
        case LogType.temp:
            HStack(alignment: .center, spacing: 16) {
                LevelGauge(vessel: .thermometer, value: tempC, range: 34...42.5, step: 0.1, marks: [35, 36, 37, 38, 39, 40, 41, 42], label: { "\(Int($0))" },
                           tint: Crayon.tangerine, alarm: 38)
                    .frame(width: 96, height: 268)
                VStack(alignment: .leading, spacing: 12) {
                    ValueText(parts: [(String(format: "%.1f", Double(temp) / 10), "°C")], size: 52)
                        .foregroundStyle(temp >= 380 ? Palette.danger : lamp ? Palette.lampInk : .primary)
                    Text("点按或上下拖动体温计").font(.footnote).foregroundStyle(Palette.secondaryText)
                    NudgeButtons(value: tempC, range: 34...42.5, step: 0.1, tint: temp >= 380 ? Palette.danger : c)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .printCard(radius: Radius.card, fill: lamp ? Palette.lampCard : Palette.card)
        default:
            let (title, hint, chips): (String, String, [String]) = type == LogType.solid ? ("吃了什么", "食物和大概的量", ["米粉", "蔬菜泥", "水果泥", "肉泥", "蛋黄", "粥"])
                : type == LogType.medicine ? ("用了什么药", "药名与剂量，按医嘱或说明书", ["维生素 D", "维生素 AD"]) : ("备注", "发生了什么", [])
            Text(title).font(.headline)
            TextField(hint, text: $text, axis: .vertical).lineLimit(type == LogType.note ? 3...6 : 1...3).focused($typing)
                .padding(14).background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
            if !chips.isEmpty {
                FlowChips(items: chips.enumerated().map { ($0.offset, $0.element) }, selected: nil, tint: c) { i in text = text.isEmpty ? chips[i] : text + "、" + chips[i] }
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
            Button { if s.run() { saved += 1; dismiss() } else { failed = true } } label: { Text("记下").frame(maxWidth: .infinity) }
                .buttonStyle(.vinyl(Crayon.fill(LogType.color(type), lamp), prominent: true, large: true)).disabled(!s.enabled)
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
                    .buttonStyle(.vinyl(on ? tint : Color(hex: 0x8A8279)))
                    .fontWeight(on ? .semibold : .regular)
                    .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }
}

/// Lays children out in rows, wrapping to the next row when a row is full.
struct WrapLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x > 0 && x + z.width > w { x = 0; y += row + spacing; row = 0 }
            x += z.width + spacing; row = max(row, z.height); maxX = max(maxX, x - spacing)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + row)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, row: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x > b.minX && x + z.width > b.maxX { x = b.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(z))
            x += z.width + spacing; row = max(row, z.height)
        }
    }
}

/// One entry, to change or to add after the fact: exact start (and end), the amount, side or kind, the text.
struct EntrySheet: View {
    @Environment(JournalStore.self) private var j
    @Environment(\.dismiss) private var dismiss
    @State var entry: LogEntry
    @State private var failed = false
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
    private func choose(_ i: Int) { var p = parts; p[sel] = entry; parts = p; sel = i; entry = p[i] }
    private func save() -> Bool {
        if isNew { return j.record(entry) }
        for (e, o) in zip(current, original) where e != o { if !j.update(e) { return false } }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                if failed { Section { SaveFailed() } }
                // the kind, large, in its own vinyl: what this entry is, before any field
                Section {
                    HStack(spacing: 14) {
                        IconTile(symbol: LogType.symbol(entry.type), color: LogType.color(entry.type), size: 52, round: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LogType.name(entry.type)).font(.title3.weight(.bold))
                            if whole {
                                // the whole feed, as on the time line: its start and length, then each side
                                let c = current
                                Text(hm(c[0].startDate) + " · " + durationValue(c.reduce(0) { $0 + $1.activeSeconds }))
                                    .font(.subheadline).foregroundStyle(Palette.secondaryText).monospacedDigit()
                                Text(c.map { ($0.side == "r" ? "右侧 " : "左侧 ") + durationValue($0.activeSeconds) }.joined(separator: " · "))
                                    .font(.footnote).foregroundStyle(Palette.secondaryText).monospacedDigit()
                            } else {
                                Text(entry.value(on: Day(entry.startDate)).isEmpty ? hm(entry.startDate) : hm(entry.startDate) + " · " + entry.value(on: Day(entry.startDate)))
                                    .font(.subheadline).foregroundStyle(Palette.secondaryText).monospacedDigit()
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).fill(LogType.color(entry.type).opacity(0.16)))
                if isNew {
                    Picker("类型", selection: $entry.type) {
                        ForEach(LogType.buttons.filter { $0 != LogType.growth }, id: \.self) { Text(LogType.name($0)).tag($0) }
                    }
                    .onChange(of: entry.type) { _, t in
                        if LogType.timed.contains(t) && entry.end == nil { entry.end = min(JournalFile.now(), entry.start + 20 * 60_000) }
                        if !LogType.timed.contains(t) { entry.end = nil }
                    }
                }
                if whole {
                    // which side is being changed: each keeps its own times and side
                    Picker("修改", selection: Binding(get: { sel }, set: { choose($0) })) {
                        ForEach(parts.indices, id: \.self) { i in Text("第 \(i + 1) 段 · " + (current[i].side == "r" ? "右侧" : "左侧")).tag(i) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }
                Section {
                    DatePicker(entry.end != nil ? "开始" : "时间", selection: Binding(get: { entry.startDate }, set: { d in
                        let delta = ms(d) - entry.start; entry.start = ms(d); if let e = entry.end { entry.end = e + delta }
                    }), in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    if let e = entry.endDate {
                        DatePicker("结束", selection: Binding(get: { e }, set: { entry.end = max(entry.start + 60_000, ms($0)) }), in: entry.startDate...Date(), displayedComponents: [.date, .hourAndMinute])
                        LabeledContent("时长", value: minutesOf((entry.end! - entry.start) / 1000))
                    }
                }
                Section { fields }
                if !isNew {
                    // a feed of two sides goes whole: one change, one 撤销
                    Section { Button(whole ? "删除这一顿" : "删除这条", role: .destructive) { if whole { j.delete(original) } else { j.delete(entry) }; dismiss() } }
                }
            }
            .scrollContentBackground(.hidden)
            .pageBackground(tone: LogType.color(entry.type))
            .navigationTitle((isNew ? "补记 · " : "") + LogType.name(entry.type)).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("完成", systemImage: "checkmark") { if save() { dismiss() } else { failed = true } } }
            }
        }
    }

    @ViewBuilder private var fields: some View {
        let c = LogType.color(entry.type)
        switch entry.type {
        case LogType.bottle:
            Picker("奶", selection: Binding(get: { entry.detail ?? "" }, set: { entry.detail = $0.isEmpty ? nil : $0 })) {
                Text("未填").tag(""); Text("母乳").tag("breastmilk"); Text("配方奶").tag("formula")
            }
            let amount = Binding<Double>(get: { Double(entry.amount ?? 120) }, set: { entry.amount = Int($0) })
            HStack(spacing: 16) {
                LevelGauge(vessel: .bottle, value: amount, range: 5...300, step: 5, marks: [60, 120, 180, 240, 300], label: { "\(Int($0))" }, tint: c)
                    .frame(width: 92, height: 196)
                VStack(alignment: .leading, spacing: 12) {
                    ValueText(parts: [("\(entry.amount ?? 120)", "毫升")], size: 40)
                    NudgeButtons(value: amount, range: 5...300, step: 5, tint: c)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
        case LogType.nurse:
            HStack(spacing: 10) {
                // the sides read 左侧 / 右侧, never L / R; the arrow only points the way
                ForEach([("l", "左侧"), ("r", "右侧")], id: \.0) { k, t in
                    ChoiceTile(sticker: nil, symbol: k == "l" ? "arrow.left.circle.fill" : "arrow.right.circle.fill", title: t, on: (entry.side ?? "l") == k, tint: c, height: 76) { withAnimation(.snappy) { entry.side = k } }
                        .accessibilityLabel(t)
                }
            }
            .padding(.vertical, 4)
        case LogType.diaper:
            HStack(spacing: 10) {
                ForEach([("wet", "湿", "drop.halffull", "ic_drop_halffull.webp"), ("dirty", "便", "circle.fill", "ic_diaper_dirty.webp"), ("both", "都有", "circle.lefthalf.filled", "ic_diaper_both.webp")], id: \.0) { k, t, sym, art in
                    ChoiceTile(sticker: art, symbol: sym, title: t, on: (entry.detail ?? "wet") == k, tint: c, height: 96) { withAnimation(.snappy) { entry.detail = k } }
                }
            }
            .padding(.vertical, 4)
        case LogType.temp:
            let t = Binding<Double>(get: { Double(entry.amount ?? 368) / 10 }, set: { entry.amount = Int(($0 * 10).rounded()) })
            HStack(spacing: 16) {
                LevelGauge(vessel: .thermometer, value: t, range: 34...42.5, step: 0.1, marks: [35, 36, 37, 38, 39, 40, 41, 42], label: { "\(Int($0))" }, tint: Crayon.tangerine, alarm: 38)
                    .frame(width: 84, height: 220)
                VStack(alignment: .leading, spacing: 12) {
                    ValueText(parts: [(String(format: "%.1f", Double(entry.amount ?? 368) / 10), "°C")], size: 40)
                        .foregroundStyle((entry.amount ?? 368) >= 380 ? Palette.danger : .primary)
                    NudgeButtons(value: t, range: 34...42.5, step: 0.1, tint: c)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
        case LogType.solid, LogType.medicine, LogType.note:
            TextField(entry.type == LogType.solid ? "食物和大概的量" : entry.type == LogType.medicine ? "药名与剂量" : "发生了什么",
                      text: Binding(get: { entry.detail ?? "" }, set: { entry.detail = String($0.prefix(120)) }), axis: .vertical)
        default: EmptyView()
        }
    }
}

/// Weight, length and head circumference on one day.
struct MeasureSheet: View {
    @Environment(JournalStore.self) private var j
    @Environment(\.dismiss) private var dismiss
    let measure: Measure
    let isNew: Bool
    @State private var day = Date()
    @State private var w = ""
    @State private var l = ""
    @State private var h = ""

    var body: some View {
        // a weight typed in grams (7850) is read as grams and said so; anything else out of range is said under its field
        let wv = Double(w).map { $0 > 300 ? $0 / 1000 : $0 }
        let wg = wv.flatMap { (1...30).contains($0) ? Int(($0 * 1000).rounded()) : nil }
        let lm = Double(l).flatMap { (35...120).contains($0) ? Int(($0 * 10).rounded()) : nil }
        let hm = Double(h).flatMap { (25...60).contains($0) ? Int(($0 * 10).rounded()) : nil }
        NavigationStack {
            Form {
                DatePicker("日期", selection: $day, in: ...Date(), displayedComponents: .date)
                Section { field("体重", "千克", $w, "scalemass.fill", Indicator.weight) } footer: {
                    note(w, ok: wg != nil, base: "精确到 0.01 千克，如 7.85", bad: "体重请在 1–30 千克之间",
                         extra: (Double(w) ?? 0) > 300 && wg != nil ? "已按克换算为 " + String(format: "%.2f", Double(wg!) / 1000) + " 千克" : nil)
                }
                Section { field("身长 / 身高", "厘米", $l, "ruler.fill", Indicator.length) } footer: { note(l, ok: lm != nil, base: "精确到 0.1 厘米；2 岁前躺着量身长", bad: "身长请在 35–120 厘米之间") }
                Section { field("头围", "厘米", $h, "circle.dashed", Indicator.head) } footer: { note(h, ok: hm != nil, base: "精确到 0.1 厘米，经眉上缘与后脑最突出处", bad: "头围请在 25–60 厘米之间") }
                if !isNew { Section { Button("删除这次测量", role: .destructive) { j.deleteMeasure(measure); dismiss() } } }
            }
            .scrollContentBackground(.hidden)
            .pageBackground(tone: Crayon.tangerine)
            .navigationTitle(isNew ? "记一次测量" : "这次测量").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", systemImage: "checkmark") {
                        var m = measure; m.at = ms(Day.cal.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day); m.weightG = wg; m.lengthMm = lm; m.headMm = hm
                        j.saveMeasure(m); dismiss()
                    }
                    .disabled(wg == nil && lm == nil && hm == nil)
                }
            }
        }
        .onAppear {
            day = Date(timeIntervalSince1970: measure.at / 1000)
            w = measure.weightG.map { String(format: "%.2f", Double($0) / 1000) } ?? ""
            l = measure.lengthMm.map { String(format: "%.1f", Double($0) / 10) } ?? ""
            h = measure.headMm.map { String(format: "%.1f", Double($0) / 10) } ?? ""
        }
    }

    /// Under a field: how to measure; when what is typed cannot be kept, why, in the warning colour.
    @ViewBuilder private func note(_ v: String, ok: Bool, base: String, bad: String, extra: String? = nil) -> some View {
        if !v.trimmingCharacters(in: .whitespaces).isEmpty && !ok { Text(bad).foregroundStyle(Palette.danger) }
        else if let extra { Text(extra) }
        else { Text(base) }
    }
    private func field(_ t: String, _ unit: String, _ v: Binding<String>, _ s: String, _ i: Indicator) -> some View {
        HStack {
            IconTile(symbol: s, color: i.tint, size: 32, round: true)
            Text(t)
            TextField("—", text: v).keyboardType(.decimalPad).multilineTextAlignment(.trailing).monospacedDigit()
                .font(Typeface.numerals(22, relativeTo: .title3, weight: .bold))
            Text(unit).foregroundStyle(Palette.secondaryText)
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
        Label { Text("没有保存成功，填写的内容还在，请再点一次。如果反复出现，请检查 iPhone 的存储空间。").fixedSize(horizontal: false, vertical: true) }
            icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Palette.danger) }
            .font(.subheadline)
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
            .accessibilityElement(children: .combine)
    }
}
