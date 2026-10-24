import SwiftUI
import LocalAuthentication

/// Me: the child in one compact line (set once, edited in a sheet), the companion in front, and the settings and the
/// data as tiles in a grid. Nothing here repeats the home or the records.
struct YouView: View {
    @Environment(AppModel.self) private var app
    @Binding var path: NavigationPath
    @State private var editing = false
    @State private var clearing = false
    @Environment(JournalStore.self) private var j
    @State private var exporting: DataFile?
    @State private var exportName = ""
    @State private var importing = false
    @State private var message: String?

    private let two = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        @Bindable var app = app
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // the child and the companion, one card: who the app is for, and who keeps it company
                VStack(spacing: 0) {
                    Button { editing = true } label: {
                        HStack(spacing: 16) {
                            // the child from the picture book, at the child's own stage, in the chosen companion's arms
                            HuggedAvatar(size: 86)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.nickname.isEmpty ? "宝宝" : app.nickname).font(.title2.weight(.bold)).foregroundStyle(.primary)
                                if let a = app.age {
                                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                                        Ticking(text: "\(a.months)").font(Typeface.numerals(22, relativeTo: .title3, weight: .bold))
                                        Text("个月").font(.footnote.weight(.semibold))
                                        if a.days > 0 { Ticking(text: "\(a.days)").font(Typeface.numerals(17, relativeTo: .headline, weight: .bold)).padding(.leading, 3); Text("天").font(.footnote.weight(.semibold)) }
                                    }
                                    .foregroundStyle(Palette.accent)
                                }
                                Text(app.birth.map { "\($0.y)年\($0.md)出生" + (app.age.map { " · 第 \($0.lived) 天" } ?? "") } ?? "填写出生日期")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.toy)
                    Divider().padding(.horizontal, 16)
                    // the companions: the chosen one in front; tap the other to bring it forward
                    CompanionStage()
                }
                .background(LinearGradient(colors: [Crayon.lilac.opacity(0.14), Crayon.sunflower.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .printCard(radius: 28)

                // how the app looks: three swatches to tap, and the lamp coming on by itself at night
                Section2(title: "外观") {
                    VStack(spacing: 14) {
                        HStack(spacing: 10) {
                            ForEach([ThemeMode.light, .dark, .system], id: \.self) { t in
                                Swatch(mode: t, on: app.theme == t) { withAnimation(.snappy) { app.theme = t } }
                            }
                        }
                        Divider()
                        Toggle(isOn: $app.nightLight) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("晚上自动开夜灯").font(.subheadline.weight(.semibold))
                                Text("晚 7 点到早 6 点，整个应用换成夜灯").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(14).printCard(radius: 22)
                }

                // features, in pairs
                let face = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) || app.lock
                Section2(title: "功能") {
                    LazyVGrid(columns: two, spacing: 12) {
                        SwitchTile(title: "记录", detail: "显示记录标签页", symbol: "list.bullet.clipboard.fill", color: Crayon.tangerine, on: $app.journal)
                        if face {
                            SwitchTile(title: "面容 ID", detail: "打开时解锁", symbol: "faceid", color: Crayon.leaf, on: $app.lock)
                        } else {
                            NavigationLink(value: Route.about) { Tile(title: "关于", detail: "来源 · 条款 · 反馈", symbol: "info", color: Crayon.sky) }
                                .buttonStyle(.toy)
                        }
                    }
                }

                // data
                // data: one card of rows, as Settings lists them; the destructive one last, in red, behind a confirmation
                Section2(title: "数据") {
                    VStack(spacing: 0) {
                        Menu {
                            Button("记录文件（与安卓通用）", systemImage: "doc") { exportName = "摸索台灯记录-\(stamp).json"; exporting = DataFile(data: RecordFile.json(app, JournalFile.read())) }
                            Button("表格（CSV）", systemImage: "tablecells") { exportName = "摸索台灯记录-\(stamp).csv"; exporting = DataFile(data: RecordFile.csv(JournalFile.read())) }
                        } label: { DataRow(title: "导出记录", detail: "记录文件或表格", symbol: "square.and.arrow.up", color: Crayon.sky) }
                        Divider().padding(.leading, 58)
                        Button { importing = true } label: { DataRow(title: "导入记录", detail: "从摸索台灯导出的记录文件", symbol: "square.and.arrow.down", color: Crayon.lilac) }
                        Divider().padding(.leading, 58)
                        Button(role: .destructive) { clearing = true } label: {
                            HStack { Text("清除全部数据").font(.subheadline.weight(.semibold)); Spacer() }
                                .foregroundStyle(Palette.danger).padding(.horizontal, 16).padding(.vertical, 14).contentShape(Rectangle())
                        }
                    }
                    .buttonStyle(.toy)
                    .printCard(radius: 22)
                    Text("所有记录只保存在这台手机上。").font(.caption).foregroundStyle(.secondary).padding(.leading, 4)
                }

                if face {
                    NavigationLink(value: Route.about) {
                        HStack(spacing: 12) {
                            IconTile(symbol: "info", color: Crayon.sky, size: 32)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("关于摸索台灯").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                Text("内容来源 · 条款与隐私 · 反馈").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                        .padding(12).printCard(radius: 20)
                    }
                    .buttonStyle(.toy)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .pageBackground(tone: Crayon.lilac)
        .navigationTitle("我的")
        .sheet(isPresented: $editing) { ProfileSheet() }
        .fileExporter(isPresented: Binding(get: { exporting != nil }, set: { if !$0 { exporting = nil } }), document: exporting, contentType: exportName.hasSuffix(".csv") ? .commaSeparatedText : .json, defaultFilename: exportName) { r in
            if case .success = r { message = "已导出" }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { r in
            guard case let .success(url) = r else { return }
            let ok = url.startAccessingSecurityScopedResource(); defer { if ok { url.stopAccessingSecurityScopedResource() } }
            do { try RecordFile.load(Data(contentsOf: url), into: app, journal: j); message = "已导入" }
            catch { message = error is RecordFile.Failure ? "这不是摸索台灯导出的记录文件" : "没有导入成功，文件可能已损坏" }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("好") {} }
        .confirmationDialog("清除这台手机上的全部记录和设置？", isPresented: $clearing, titleVisibility: .visible) {
            Button("全部清除", role: .destructive) { app.clearAll(); j.reload() }
        } message: { Text("清除后无法恢复。") }
    }
}

/// A titled group on the 我的 page: a small heading over its content.
private struct Section2<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 4)
            content
        }
    }
}

/// The two companions on a little stage. The chosen one stands in front, larger; tap the other and it hops forward
/// while the first steps back. Each has its job: Moss keeps the day and the play, Otto the night and the lamp.
private struct CompanionStage: View {
    @Environment(AppModel.self) private var app
    @Environment(\.lamp) private var lamp
    @State private var cheer = 0
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Kind.allCases, id: \.self) { k in
                let on = app.companion == k
                Button {
                    guard !on else { cheer += 1; return }
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { app.companion = k }
                    cheer += 1
                } label: {
                    VStack(spacing: 6) {
                        Creature(kind: k, mood: on ? .happy : .open, look: CGPoint(x: k == .moss ? 0.7 : -0.7, y: 0.1),
                                 poke: false, arms: on && cheer % 2 == 1 ? .cheer : .rest, glow: k == .otto && lamp)
                            .frame(width: on ? 76 : 52, height: on ? 76 : 52)
                            .frame(height: 80, alignment: .bottom)
                        Text(k.rawValue).font(.subheadline.weight(on ? .bold : .semibold)).foregroundStyle(on ? Color.primary : Color.secondary)
                        Text(k == .moss ? "白天陪玩" : "夜里点灯").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 124)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())   // the whole half of the stage is the button, not just the drawing
                }
                .buttonStyle(.toy)
                .accessibilityLabel("\(k.rawValue)，\(k == .moss ? "白天陪玩" : "夜里点灯")").accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .background(alignment: .bottom) {
            // the stage: a soft floor line under their feet, a spot of light under the one in front
            // by day a soft gold floor; under the lamp a pool of amber light (a flat fill read as a hole on the blue)
            Ellipse().fill(RadialGradient(colors: [(lamp ? Palette.amber : Palette.bead).opacity(lamp ? 0.4 : 0.22), .clear], center: .center, startRadius: 0, endRadius: 70))
                .frame(width: 150, height: 22)
                .offset(x: app.companion == .moss ? -80 : 80, y: -50)
                .animation(.spring(response: 0.45, dampingFraction: 0.7), value: app.companion)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: cheer)
    }
}

/// One appearance to choose, drawn as a small page of it: paper by day, the lamp's blue with its amber light, or half
/// and half for following the system.
private struct Swatch: View {
    let mode: ThemeMode
    let on: Bool
    let pick: () -> Void
    var body: some View {
        Button(action: pick) {
            VStack(spacing: 6) {
                ZStack {
                    switch mode {
                    case .light: RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0xFBF7F0))
                    case .dark: lampPage
                    case .system:
                        HStack(spacing: 0) { Color(hex: 0xFBF7F0); lampPage }
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    // a card on the page
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(mode == .light ? Color.white : mode == .dark ? Palette.lampCard : Color.white.opacity(0.0))
                        .frame(width: 40, height: 14).offset(y: 10)
                    if mode != .light { Circle().fill(Palette.amber).frame(width: 7, height: 7).shadow(color: Palette.amber, radius: 4).offset(x: 22, y: -14) }
                }
                .frame(height: 64)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? Palette.accent : Color.secondary.opacity(0.25), lineWidth: on ? 2.5 : 1))
                Text(mode == .light ? "白天" : mode == .dark ? "夜灯" : "跟随系统").font(.caption.weight(on ? .bold : .medium))
                    .foregroundStyle(on ? Color.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.toy)
        .accessibilityLabel(mode == .light ? "白天" : mode == .dark ? "夜灯" : "跟随系统")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
    private var lampPage: some View {
        ZStack {
            Palette.lampPage
            RadialGradient(colors: [Palette.amber.opacity(0.3), .clear], center: .topTrailing, startRadius: 0, endRadius: 60)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// A square-ish settings tile: icon, title, a word of state.
private struct Tile: View {
    let title: String, detail: String, symbol: String, color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            IconTile(symbol: symbol, color: color, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading).printCard(radius: 20)
    }
}

/// A tile with a switch in its corner.
private struct SwitchTile: View {
    let title: String, detail: String, symbol: String, color: Color
    @Binding var on: Bool
    var body: some View {
        Tile(title: title, detail: detail, symbol: symbol, color: color)
            .overlay(alignment: .topTrailing) { Toggle(title, isOn: $on).labelsHidden().scaleEffect(0.8).padding(8) }
            .accessibilityElement(children: .combine)
    }
}

/// One row of the data card: its sticker, what it does, a word on what it takes.
private struct DataRow: View {
    let title: String, detail: String, symbol: String, color: Color
    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, color: color, size: 30, round: true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 11).contentShape(Rectangle())
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
                Section {
                    HuggedAvatar(size: 96).frame(maxWidth: .infinity).padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                }
                Section {
                    TextField("小名", text: Binding(get: { app.nickname }, set: { app.nickname = String($0.prefix(12)) }))
                    DatePicker("出生日期", selection: $date, in: Calendar.current.date(byAdding: .year, value: -4, to: Date())!...Date(), displayedComponents: .date)
                        .onChange(of: date) { _, _ in hasBirth = true }
                    Picker("性别", selection: Binding(get: { app.sex ?? "" }, set: { app.sex = $0.isEmpty ? nil : $0 })) {
                        Text("不填").tag(""); Text("男孩").tag("boy"); Text("女孩").tag("girl")
                    }
                } footer: { Text("性别只用于选择 WHO 生长曲线。") }
                Section {
                    HStack(spacing: 12) {
                        ForEach(["boy", "girl"], id: \.self) { k in
                            let on = app.drawsGirl == (k == "girl")
                            Button { withAnimation(.snappy) { app.look = k } } label: {
                                VStack(spacing: 6) {
                                    Figure(name: "child_\(GrowingChild.stage(app.babyMonth ?? 0)).webp")
                                        .environment(\.girlArt, k == "girl")
                                        .scaleEffect(1.7, anchor: .bottom)   // the figure carries a margin
                                        .frame(height: 96).clipped()
                                    Text(k == "girl" ? "女宝" : "男宝").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(on ? Palette.accent.opacity(0.12) : Palette.fill))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(on ? Palette.accent : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.toy)
                            .accessibilityLabel(k == "girl" ? "女宝" : "男宝").accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                } header: { Text("图里的宝宝") } footer: { Text("只改变插画里宝宝的样子，与伙伴无关；没选时跟随性别。") }
            }
            .navigationTitle("宝宝").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成", systemImage: "checkmark") { if hasBirth { app.birth = Day(date) }; dismiss() } } }
            .onAppear { if let b = app.birth { date = b.date } }
        }
        .presentationDetents([.large])
    }
}

private var stamp: String { let d = Day.today; return String(format: "%04d%02d%02d", d.y, d.m, d.d) }

/// About: name, version, the documents, sources and licences, a short disclaimer.
struct AboutView: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        List {
            Section {
                VStack(spacing: 6) {
                    Duo(primary: app.companion, size: 96)
                    Text("摸索台灯").font(.title.weight(.bold)).padding(.top, 8)
                    Text("Mossling · 0–3 岁早教活动规划").font(.subheadline).foregroundStyle(.secondary)
                    Text("版本 \(v)（\(b)）").font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }
            Section {
                NavigationLink(value: Route.doc("TERMS")) { Label { Text("使用条款") } icon: { IconTile(symbol: "doc.text.fill", color: Crayon.pebble) } }
                NavigationLink(value: Route.doc("PRIVACY")) { Label { Text("隐私政策") } icon: { IconTile(symbol: "hand.raised.fill", color: Crayon.sky) } }
                NavigationLink(value: Route.doc("DISCLAIMER")) { Label { Text("免责声明") } icon: { IconTile(symbol: "exclamationmark.bubble.fill", color: Crayon.tangerine) } }
            }
            Section {
                NavigationLink(value: Route.sources) { Label { Text("内容来源") } icon: { IconTile(symbol: "books.vertical.fill", color: Crayon.caramel) } }
                NavigationLink(value: Route.licenses) { Label { Text("许可与致谢") } icon: { IconTile(symbol: "checkmark.seal.fill", color: Crayon.aqua) } }
                NavigationLink(value: Route.doc("CHANGELOG")) { Label { Text("更新日志") } icon: { IconTile(symbol: "clock.arrow.circlepath", color: Crayon.lilac) } }
                Link(destination: URL(string: "https://github.com/mjuvdeysii/mossling/issues")!) { Label { Text("反馈问题") } icon: { IconTile(symbol: "envelope.fill", color: Crayon.leaf) } }
                    .tint(.primary)
            } footer: {
                Text("本应用内容仅供家庭养育参考，不构成医疗诊断或治疗建议。如对儿童健康或发育有疑虑，请咨询儿科医生或当地妇幼保健机构。").padding(.top, 8)
            }
        }
        .scrollContentBackground(.hidden).pageBackground()
        .navigationTitle("关于").navigationBarTitleDisplayMode(.inline)
    }
}

/// A Markdown document from the repository (terms, privacy, disclaimer, changelog), set as a document.
struct DocView: View {
    let name: String
    var body: some View {
        let raw = (Bundle.main.url(forResource: name, withExtension: "md").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "读取不到这份文件。")
            .replacingOccurrences(of: "安卓应用", with: "应用")
        let lines = raw.components(separatedBy: "\n")
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, l in docLine(l) }
            }
            .padding(.horizontal, 20).padding(.bottom, 40)
        }
        .pageBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func docLine(_ l: String) -> some View {
        if l.hasPrefix("# ") { Text(l.dropFirst(2)).font(.largeTitle.weight(.bold)).padding(.bottom, 8) }
        else if l.hasPrefix("## ") { Text(l.dropFirst(3)).font(.title3.weight(.bold)).padding(.top, 18) }
        else if l.hasPrefix("- ") { HStack(alignment: .firstTextBaseline, spacing: 8) { Text("•").foregroundStyle(.secondary); Text(rich(String(l.dropFirst(2)))).font(.body) } }
        else if let r = l.range(of: #"^\d+\. "#, options: .regularExpression) {
            HStack(alignment: .firstTextBaseline, spacing: 8) { Text(l[r].trimmingCharacters(in: .whitespaces)).font(.body.monospacedDigit()).foregroundStyle(.secondary).frame(width: 24, alignment: .leading); Text(rich(String(l[r.upperBound...]))).font(.body) }
        }
        else if l.hasPrefix("|") {
            let cells = l.trimmingCharacters(in: CharacterSet(charactersIn: "|")).components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            if !cells.allSatisfy({ $0.hasPrefix("---") }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rich(cells.first ?? "")).font(.headline)
                    ForEach(Array(cells.dropFirst().enumerated()), id: \.offset) { _, c in Text(rich(c)).font(.subheadline).foregroundStyle(.secondary) }
                }
                .card(Palette.card, radius: 18, padding: 14)
            }
        }
        else if l.hasPrefix("适用于") || l.hasPrefix("生效日期") { Text(l).font(.footnote).foregroundStyle(Palette.secondaryText) }
        else if l.isEmpty { Color.clear.frame(height: 2) }
        else { Text(rich(l)).font(.body) }
    }
}

/// Every source the content draws on, numbered.
struct SourcesView: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        List {
            Section {
                ForEach(Array(app.content.sources.enumerated()), id: \.offset) { i, s in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline) { Text("\(i + 1)").font(.footnote.monospacedDigit()).foregroundStyle(.secondary).frame(minWidth: 20, alignment: .leading); Text(s.org).font(.headline) }
                        Text(s.title).font(.subheadline)
                        Text([s.date, s.checked].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "；")).font(.caption).foregroundStyle(Palette.secondaryText)
                        if let u = s.url, let url = URL(string: u), !u.isEmpty { Link(u, destination: url).font(.caption).lineLimit(2) }
                    }
                    .padding(.vertical, 2)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) { Text("\(app.content.sources.count + 1)").font(.footnote.monospacedDigit()).foregroundStyle(.secondary).frame(minWidth: 20, alignment: .leading); Text("World Health Organization").font(.headline) }
                    Text("WHO Child Growth Standards：体重、身长 / 身高、头围的年龄别标准").font(.subheadline)
                    Text("2006").font(.caption).foregroundStyle(Palette.secondaryText)
                }
            } header: { Text("参考文献 · \(app.content.sources.count + 1) 项") }
        }
        .scrollContentBackground(.hidden).pageBackground()
        .navigationTitle("内容来源")
    }
}

struct LicensesView: View {
    var body: some View {
        List {
            Section("数据") {
                row("WHO Child Growth Standards", "按世界卫生组织的使用条款引用", "© World Health Organization")
            }
            Section("系统框架") {
                row("SwiftUI · Swift Charts · WidgetKit · ActivityKit", "Apple SDK", "© Apple Inc.")
            }
        }
        .scrollContentBackground(.hidden).pageBackground()
        .navigationTitle("许可与致谢")
    }
    private func row(_ a: String, _ b: String, _ c: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(a).font(.subheadline.weight(.semibold)); Text(b).font(.footnote); Text(c).font(.caption).foregroundStyle(Palette.secondaryText) }
    }
}
