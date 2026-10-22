import SwiftUI

/// The sheet that follows a log button: when (now, a few minutes ago, or an exact time), then what — one tap for most.
struct AskSheet: View {
    @Environment(JournalStore.self) private var j
    @Environment(\.dismiss) private var dismiss
    let type: String
    @State private var ago = 0
    @State private var exact: Date?
    @State private var choosing = false
    @State private var ml = 120.0
    @State private var temp = 368
    @State private var text = ""
    @FocusState private var typing: Bool

    private var at: Date { exact ?? Date().addingTimeInterval(-Double(ago) * 60) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(type == LogType.nurse ? "什么时候开始的" : "什么时候").font(.subheadline).foregroundStyle(Palette.secondaryText)
                    FlowChips(items: [(0, "现在"), (5, "5 分钟前"), (15, "15 分钟前"), (30, "半小时前"), (60, "1 小时前")], selected: exact == nil ? ago : nil) { ago = $0; exact = nil }
                    Button { choosing = true } label: {
                        Label(exact.map { whenLabel($0) } ?? "选择准确时间…", systemImage: "clock")
                            .font(.subheadline.weight(.semibold)).monospacedDigit()
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(exact == nil ? Palette.cardHigh : Palette.primaryContainer, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    Divider()
                    content
                }
                .padding(20)
            }
            .navigationTitle(LogType.name(type)).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
            .sheet(isPresented: $choosing) { TimeSheet(title: type == LogType.nurse ? "开始时间" : "时间", initial: at) { exact = $0 } }
        }
        .presentationDetents([.medium, .large])
        .onAppear { if type == LogType.bottle, let a = j.logs.first(where: { $0.type == LogType.bottle })?.amount { ml = Double(a) } }
    }

    @ViewBuilder private var content: some View {
        switch type {
        case LogType.nurse:
            Text("从哪边开始").font(Typeface.serif(20))
            HStack(spacing: 16) {
                ForEach([("l", "L", "左边"), ("r", "R", "右边")], id: \.0) { k, big, t in
                    Button { j.start(LogType.nurse, side: k, at: at); dismiss() } label: {
                        VStack { Text(big).font(Typeface.numerals(40)).foregroundStyle(LogType.color(LogType.nurse)); Text(t).font(.headline) }
                            .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                            .background(LogType.color(LogType.nurse).opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        case LogType.bottle:
            Text("喝了多少").font(Typeface.serif(20))
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(ml))").font(Typeface.numerals(48)).monospacedDigit(); Text("毫升").font(.headline)
                Spacer()
                Stepper("", value: $ml, in: 10...300, step: 10).labelsHidden()
            }
            Slider(value: $ml, in: 10...300, step: 10)
            FlowChips(items: [60, 90, 120, 150, 180].map { ($0, "\($0)") }, selected: Int(ml)) { ml = Double($0) }
            save { j.add(LogEntry(type: LogType.bottle, start: ms(at), amount: Int(ml))) }
        case LogType.diaper:
            Text("换尿布").font(Typeface.serif(20))
            HStack(spacing: 12) {
                ForEach([("wet", "湿", "drop"), ("dirty", "便", "circle.fill"), ("both", "都有", "circle.lefthalf.filled")], id: \.0) { k, t, s in
                    Button { j.add(LogEntry(type: LogType.diaper, start: ms(at), detail: k)); dismiss() } label: {
                        VStack(spacing: 6) { Image(systemName: s).font(.title2); Text(t).font(.headline) }
                            .frame(maxWidth: .infinity, minHeight: 92).foregroundStyle(Palette.onPrimaryContainer)
                            .background(Palette.primaryContainer, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        case LogType.temp:
            Text("体温").font(Typeface.serif(20))
            HStack {
                Text(String(format: "%.1f", Double(temp) / 10)).font(Typeface.numerals(48)).monospacedDigit().foregroundStyle(temp >= 380 ? Palette.danger : Palette.text)
                Text("°C").font(.headline)
                Spacer()
                Stepper("", value: $temp, in: 340...425).labelsHidden()
            }
            save { j.add(LogEntry(type: LogType.temp, start: ms(at), amount: temp)) }
        default:
            let (title, hint, chips): (String, String, [String]) = type == LogType.solid ? ("吃了什么", "食物和大概的量", ["米粉", "蔬菜泥", "水果泥", "肉泥", "蛋黄", "粥"])
                : type == LogType.medicine ? ("用了什么药", "药名与剂量，按医嘱或说明书", ["维生素 D", "维生素 AD"]) : ("备注", "发生了什么", [])
            Text(title).font(Typeface.serif(20))
            TextField(hint, text: $text, axis: .vertical).lineLimit(type == LogType.note ? 3...6 : 1...3).focused($typing)
                .padding(12).background(Palette.cardLow, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if !chips.isEmpty {
                FlowChips(items: chips.enumerated().map { ($0.offset, $0.element) }, selected: nil) { i in text = text.isEmpty ? chips[i] : text + "、" + chips[i] }
            }
            save(enabled: !text.trimmingCharacters(in: .whitespaces).isEmpty || type == LogType.solid) {
                typing = false
                j.add(LogEntry(type: type, start: ms(at), detail: text.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }
    }

    private func save(enabled: Bool = true, _ f: @escaping () -> Void) -> some View {
        Button { f(); dismiss() } label: { Text("记下来").frame(maxWidth: .infinity).padding(.vertical, 6) }
            .buttonStyle(.glassProminent).controlSize(.large).disabled(!enabled)
    }
}

func ms(_ d: Date) -> Double { d.timeIntervalSince1970 * 1000 }

/// Chips that wrap onto the next line rather than scroll sideways.
struct FlowChips<T: Hashable>: View {
    let items: [(T, String)]
    let selected: T?
    let pick: (T) -> Void
    var body: some View {
        WrapLayout(spacing: 8) {
            ForEach(items, id: \.0) { v, t in
                Button { pick(v) } label: {
                    Text(t).font(.subheadline).padding(.horizontal, 12).padding(.vertical, 7)
                        .foregroundStyle(selected == v ? Palette.paper : Palette.text)
                        .background(selected == v ? Palette.primary : Palette.cardHigh, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected == v ? .isSelected : [])
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
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(isNew ? "记下来" : "好") { if isNew { j.add(entry) } else { j.update(entry) }; dismiss() } }
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
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("好") {
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
    var tint: Color { switch self { case .weight: Color(hex: 0xB07D0C); case .length: Palette.rod; case .head: Palette.mint } }
    var symbol: String { switch self { case .weight: "scalemass.fill"; case .length: "ruler.fill"; case .head: "circle.dashed" } }
}
