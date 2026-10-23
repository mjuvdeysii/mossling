import SwiftUI

/// The page that follows a record button, made for each kind: a feed or a sleep is started now (then timed on its own
/// screen) or added afterwards with its exact start and end; a bottle, a nappy, a temperature, food or a note at an
/// exact time (now unless changed), then one tap.
struct AskSheet: View {
    @Environment(JournalStore.self) private var j
    @Environment(\.dismiss) private var dismiss
    let type: String
    @State private var when = Date()
    @State private var from = Date().addingTimeInterval(-15 * 60)
    @State private var ml = 120.0
    @State private var temp = 368
    @State private var text = ""
    @State private var finished = false
    @State private var side = "l"
    @FocusState private var typing: Bool

    private var at: Date { when }
    /// The side the last feed ended on (the next feed usually starts on the other).
    private var lastSide: String? { j.logs.filter { $0.type == LogType.nurse }.max { $0.start < $1.start }?.side }
    private var timed: Bool { type == LogType.nurse || type == LogType.sleep }

    var body: some View {
        let c = LogType.color(type)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if timed {
                        Picker("方式", selection: $finished) { Text("现在开始").tag(false); Text("补记").tag(true) }
                            .pickerStyle(.segmented)
                    }
                    if timed && finished {
                        VStack(spacing: 0) {
                            DatePicker("开始", selection: $from, in: ...when, displayedComponents: [.date, .hourAndMinute])
                                .padding(.horizontal, 16).padding(.vertical, 10)
                            Divider().padding(.leading, 16)
                            DatePicker("结束", selection: $when, in: from...Date(), displayedComponents: [.date, .hourAndMinute])
                                .padding(.horizontal, 16).padding(.vertical, 10)
                        }
                        .printCard(radius: 20)
                        HStack(alignment: .firstTextBaseline) {
                            Text("时长").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Text(durationValue(when.timeIntervalSince(from))).font(Typeface.numerals(28, weight: .bold)).monospacedDigit()
                        }
                    } else if !timed {
                        DatePicker("时间", selection: $when, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .printCard(radius: 20)
                    } else {
                        DatePicker("开始于", selection: $when, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .printCard(radius: 20)
                    }
                    content
                }
                .padding(20)
            }
            .navigationTitle(LogType.name(type)).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消", systemImage: "xmark") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        // the start must stay before the end, however the two were set
        .onChange(of: when) { _, w in if from >= w { from = w.addingTimeInterval(-15 * 60) } }
        .onChange(of: finished) { _, _ in if from >= when { from = when.addingTimeInterval(-15 * 60) } }
        .onAppear { if let l = lastSide { side = l == "l" ? "r" : "l" }; if type == LogType.bottle, let a = j.logs.first(where: { $0.type == LogType.bottle })?.amount { ml = Double(a) } }
    }

    @ViewBuilder private var content: some View {
        let c = LogType.color(type)
        switch type {
        case LogType.nurse:
            Text(finished ? "哪一侧" : "从哪一侧开始").font(.headline)
            HStack(spacing: 14) {
                ForEach([("l", "L", "左侧"), ("r", "R", "右侧")], id: \.0) { k, big, t in
                    let on = !finished || side == k
                    Button {
                        if finished { side = k } else { j.start(LogType.nurse, side: k, at: at); dismiss() }
                    } label: {
                        VStack(spacing: 4) { Text(big).font(Typeface.numerals(40, weight: .bold)); Text(t).font(.subheadline.weight(.semibold)) }
                            .foregroundStyle(finished && on ? .white : c).frame(maxWidth: .infinity, minHeight: 104)
                            .overlay(alignment: .topTrailing) {
                                if lastSide == k {
                                    Text("上次").font(.caption2.weight(.bold)).padding(.horizontal, 7).padding(.vertical, 3)
                                        .background(Capsule().fill(.white.opacity(0.85))).foregroundStyle(c).padding(8)
                                }
                            }
                            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(finished && on ? AnyShapeStyle(LinearGradient(colors: [c.mix(with: .white, by: 0.25), c], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(c.opacity(0.12))))
                    }
                    .buttonStyle(.toy)
                    .accessibilityAddTraits(finished && on ? .isSelected : [])
                    .accessibilityValue(lastSide == k ? "上次喂的一侧" : "")
                }
            }
            if finished {
                save(enabled: from < when) { j.add(LogEntry(type: LogType.nurse, start: ms(from), end: ms(when), side: side)) }
            }
        case LogType.sleep:
            if finished {
                save(enabled: from < when) { j.add(LogEntry(type: LogType.sleep, start: ms(from), end: ms(when))) }
            } else {
                Button { j.start(LogType.sleep, at: at); dismiss() } label: {
                    Label("开始睡觉", systemImage: "moon.zzz.fill").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent).tint(c).controlSize(.large)
            }
        case LogType.bottle:
            HStack(alignment: .firstTextBaseline) {
                ValueText(parts: [("\(Int(ml))", "毫升")], size: 44)
                Spacer()
                Stepper("奶量", value: $ml, in: 10...300, step: 10).labelsHidden()
            }
            Slider(value: $ml, in: 10...300, step: 10).tint(c)
            FlowChips(items: [60, 90, 120, 150, 180].map { ($0, "\($0)") }, selected: Int(ml), tint: c) { ml = Double($0) }
            save { j.add(LogEntry(type: LogType.bottle, start: ms(at), amount: Int(ml))) }
        case LogType.diaper:
            HStack(spacing: 12) {
                ForEach([("wet", "湿", "drop.halffull"), ("dirty", "便", "circle.fill"), ("both", "都有", "circle.lefthalf.filled")], id: \.0) { k, t, sym in
                    Button { j.add(LogEntry(type: LogType.diaper, start: ms(at), detail: k)); dismiss() } label: {
                        VStack(spacing: 8) { Image(systemName: sym).font(.title2); Text(t).font(.subheadline.weight(.semibold)) }
                            .frame(maxWidth: .infinity, minHeight: 96).foregroundStyle(c)
                            .background(c.opacity(0.12), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        case LogType.temp:
            HStack(alignment: .firstTextBaseline) {
                ValueText(parts: [(String(format: "%.1f", Double(temp) / 10), "°C")], size: 44).foregroundStyle(temp >= 380 ? Palette.danger : .primary)
                Spacer()
                Stepper("体温", value: $temp, in: 340...425).labelsHidden()
            }
            save { j.add(LogEntry(type: LogType.temp, start: ms(at), amount: temp)) }
        default:
            let (title, hint, chips): (String, String, [String]) = type == LogType.solid ? ("吃了什么", "食物和大概的量", ["米粉", "蔬菜泥", "水果泥", "肉泥", "蛋黄", "粥"])
                : type == LogType.medicine ? ("用了什么药", "药名与剂量，按医嘱或说明书", ["维生素 D", "维生素 AD"]) : ("备注", "发生了什么", [])
            Text(title).font(.headline)
            TextField(hint, text: $text, axis: .vertical).lineLimit(type == LogType.note ? 3...6 : 1...3).focused($typing)
                .padding(14).background(Palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if !chips.isEmpty {
                FlowChips(items: chips.enumerated().map { ($0.offset, $0.element) }, selected: nil, tint: c) { i in text = text.isEmpty ? chips[i] : text + "、" + chips[i] }
            }
            save(enabled: !text.trimmingCharacters(in: .whitespaces).isEmpty || type == LogType.solid) {
                typing = false
                j.add(LogEntry(type: type, start: ms(at), detail: text.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }
    }

    private func save(enabled: Bool = true, _ f: @escaping () -> Void) -> some View {
        Button { f(); dismiss() } label: { Text("记下").frame(maxWidth: .infinity).padding(.vertical, 6) }
            .buttonStyle(.borderedProminent).tint(LogType.color(type)).controlSize(.large).disabled(!enabled)
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
                    .buttonStyle(.bordered).buttonBorderShape(.capsule)
                    .tint(on ? tint : .secondary)
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
    let isNew: Bool
    init(entry: LogEntry, isNew: Bool) { _entry = State(initialValue: entry); self.isNew = isNew }

    var body: some View {
        NavigationStack {
            Form {
                if isNew {
                    Picker("类型", selection: $entry.type) {
                        ForEach(LogType.buttons.filter { $0 != LogType.growth }, id: \.self) { Text(LogType.name($0)).tag($0) }
                    }
                    .onChange(of: entry.type) { _, t in
                        if LogType.timed.contains(t) && entry.end == nil { entry.end = min(JournalFile.now(), entry.start + 20 * 60_000) }
                        if !LogType.timed.contains(t) { entry.end = nil }
                    }
                }
                Section {
                    DatePicker(entry.end != nil ? "开始" : "时间", selection: Binding(get: { entry.startDate }, set: { d in
                        let delta = ms(d) - entry.start; entry.start = ms(d); if let e = entry.end { entry.end = e + delta }
                    }), in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    if let e = entry.endDate {
                        DatePicker("结束", selection: Binding(get: { e }, set: { entry.end = max(entry.start + 60_000, ms($0)) }), in: entry.startDate...Date(), displayedComponents: [.date, .hourAndMinute])
                        LabeledContent("时长", value: minutesOf((entry.end! - entry.start) / 1000))
                    }
                } footer: { Text(whenLabel(entry.startDate) + (entry.endDate.map { " – " + whenLabel($0) } ?? "")).monospacedDigit() }
                Section { fields }
                if !isNew {
                    Section { Button("删除这条", role: .destructive) { j.delete(entry); dismiss() } }
                }
            }
            .navigationTitle((isNew ? "补记 · " : "") + LogType.name(entry.type)).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消", systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("完成", systemImage: "checkmark") { if isNew { j.add(entry) } else { j.update(entry) }; dismiss() } }
            }
        }
    }

    @ViewBuilder private var fields: some View {
        switch entry.type {
        case LogType.bottle:
            Stepper(value: Binding(get: { entry.amount ?? 120 }, set: { entry.amount = $0 }), in: 10...300, step: 10) { LabeledContent("奶量", value: "\(entry.amount ?? 120) 毫升") }
        case LogType.nurse:
            Picker("哪边", selection: Binding(get: { entry.side ?? "l" }, set: { entry.side = $0 })) { Text("左边").tag("l"); Text("右边").tag("r") }.pickerStyle(.segmented)
        case LogType.diaper:
            Picker("尿布", selection: Binding(get: { entry.detail ?? "wet" }, set: { entry.detail = $0 })) { Text("湿").tag("wet"); Text("便").tag("dirty"); Text("都有").tag("both") }.pickerStyle(.segmented)
        case LogType.temp:
            Stepper(value: Binding(get: { entry.amount ?? 368 }, set: { entry.amount = $0 }), in: 340...425) { LabeledContent("体温", value: String(format: "%.1f °C", Double(entry.amount ?? 368) / 10)) }
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
        let wg = Double(w).flatMap { (1...30).contains($0) ? Int(($0 * 1000).rounded()) : nil }
        let lm = Double(l).flatMap { (35...120).contains($0) ? Int(($0 * 10).rounded()) : nil }
        let hm = Double(h).flatMap { (25...60).contains($0) ? Int(($0 * 10).rounded()) : nil }
        NavigationStack {
            Form {
                DatePicker("日期", selection: $day, in: ...Date(), displayedComponents: .date)
                Section { field("体重", "千克", $w, "scalemass.fill", Indicator.weight) } footer: { Text("精确到 0.01 千克，如 7.85") }
                Section { field("身长 / 身高", "厘米", $l, "ruler.fill", Indicator.length) } footer: { Text("精确到 0.1 厘米；2 岁前躺着量身长") }
                Section { field("头围", "厘米", $h, "circle.dashed", Indicator.head) } footer: { Text("精确到 0.1 厘米，经眉上缘与后脑最突出处") }
                if !isNew { Section { Button("删除这次测量", role: .destructive) { j.deleteMeasure(measure); dismiss() } } }
            }
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

    private func field(_ t: String, _ unit: String, _ v: Binding<String>, _ s: String, _ i: Indicator) -> some View {
        HStack {
            Image(systemName: s).foregroundStyle(i.tint).frame(width: 24)
            Text(t)
            TextField("—", text: v).keyboardType(.decimalPad).multilineTextAlignment(.trailing).monospacedDigit()
            Text(unit).foregroundStyle(Palette.secondaryText)
        }
    }
}

extension Indicator {
    var tint: Color { switch self { case .weight: Crayon.tangerine; case .length: Crayon.sky; case .head: Crayon.aqua } }
    var symbol: String { switch self { case .weight: "scalemass.fill"; case .length: "ruler.fill"; case .head: "circle.dashed" } }
}
