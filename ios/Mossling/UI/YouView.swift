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
                // the child, compact; tapping opens the sheet
                Button { editing = true } label: {
                    HStack(spacing: 12) {
                        Creature(kind: app.companion, mood: .happy).frame(width: 46, height: 46)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(app.nickname.isEmpty ? "宝宝" : app.nickname).font(.headline).foregroundStyle(.primary)
                            Text(app.birth.map { "\($0.y)年\($0.md)出生" + (app.age.map { " · 第 \($0.lived) 天" } ?? "") } ?? "填写出生日期")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(12).printCard(radius: 22)
                }
                .buttonStyle(.toy)

                // the companion in front
                LazyVGrid(columns: two, spacing: 12) {
                    ForEach(Kind.allCases, id: \.self) { k in
                        let on = app.companion == k
                        Button { withAnimation(.snappy) { app.companion = k } } label: {
                            HStack(spacing: 8) {
                                Creature(kind: k, mood: on ? .happy : .open, look: CGPoint(x: k == .moss ? 0.8 : -0.8, y: 0)).frame(width: 40, height: 40)
                                Text(k.rawValue).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                Spacer(minLength: 0)
                                Image(systemName: on ? "checkmark.circle.fill" : "circle").foregroundStyle(on ? Palette.accent : Color(uiColor: .tertiaryLabel))
                            }
                            .padding(10).printCard(radius: 20)
                        }
                        .buttonStyle(.toy)
                        .accessibilityLabel("\(k.rawValue) 站在前面").accessibilityAddTraits(on ? .isSelected : [])
                    }
                }

                // settings
                LazyVGrid(columns: two, spacing: 12) {
                    SwitchTile(title: "记录", detail: "喂养 睡眠 尿布 体温", symbol: "list.bullet.clipboard.fill", color: Crayon.tangerine, on: $app.journal)
                    if LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) || app.lock {
                        SwitchTile(title: "面容 ID", detail: "打开时解锁", symbol: "faceid", color: Crayon.leaf, on: $app.lock)
                    }
                    Menu {
                        Picker("外观", selection: $app.theme) { ForEach(ThemeMode.allCases, id: \.self) { Text($0.label).tag($0) } }
                    } label: { Tile(title: "外观", detail: app.theme.label, symbol: "circle.lefthalf.filled", color: Crayon.pebble) }
                    .buttonStyle(.toy)
                    NavigationLink(value: Route.about) { Tile(title: "关于", detail: "来源 条款 反馈", symbol: "info", color: Crayon.sky) }
                        .buttonStyle(.toy)
                }

                // data: one row of three
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Menu {
                            Button("记录文件（与安卓通用）", systemImage: "doc") { exportName = "芽芽月历记录-\(stamp).json"; exporting = DataFile(data: RecordFile.json(app, JournalFile.read())) }
                            Button("表格（CSV）", systemImage: "tablecells") { exportName = "芽芽月历记录-\(stamp).csv"; exporting = DataFile(data: RecordFile.csv(JournalFile.read())) }
                        } label: { DataKey(title: "导出", symbol: "square.and.arrow.up", color: Crayon.sky) }
                        Button { importing = true } label: { DataKey(title: "导入", symbol: "square.and.arrow.down", color: Crayon.lilac) }
                        Button { clearing = true } label: { DataKey(title: "清除", symbol: "trash.fill", color: Crayon.cherry) }
                    }
                    .buttonStyle(.toy)
                    Text("所有记录只保存在这台手机上。").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle("我的")
        .sheet(isPresented: $editing) { ProfileSheet() }
        .fileExporter(isPresented: Binding(get: { exporting != nil }, set: { if !$0 { exporting = nil } }), document: exporting, contentType: exportName.hasSuffix(".csv") ? .commaSeparatedText : .json, defaultFilename: exportName) { r in
            if case .success = r { message = "已导出" }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { r in
            guard case let .success(url) = r else { return }
            let ok = url.startAccessingSecurityScopedResource(); defer { if ok { url.stopAccessingSecurityScopedResource() } }
            do { try RecordFile.load(Data(contentsOf: url), into: app, journal: j); message = "已导入" }
            catch { message = error is RecordFile.Failure ? "这不是芽芽月历导出的记录文件" : "没有导入成功，文件可能已损坏" }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("好") {} }
        .confirmationDialog("清除这台手机上的全部记录和设置？", isPresented: $clearing, titleVisibility: .visible) {
            Button("全部清除", role: .destructive) { app.clearAll(); j.reload() }
        } message: { Text("清除后无法恢复。") }
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

/// A small data key: icon over a word.
private struct DataKey: View {
    let title: String, symbol: String, color: Color
    var body: some View {
        VStack(spacing: 6) {
            IconTile(symbol: symbol, color: color, size: 30, round: true)
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10).printCard(radius: 18)
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
                    TextField("小名", text: Binding(get: { app.nickname }, set: { app.nickname = String($0.prefix(12)) }))
                    DatePicker("出生日期", selection: $date, in: Calendar.current.date(byAdding: .year, value: -4, to: Date())!...Date(), displayedComponents: .date)
                        .onChange(of: date) { _, _ in hasBirth = true }
                    Picker("性别", selection: Binding(get: { app.sex ?? "" }, set: { app.sex = $0.isEmpty ? nil : $0 })) {
                        Text("不填").tag(""); Text("男孩").tag("boy"); Text("女孩").tag("girl")
                    }
                } footer: { Text("性别只用于选择 WHO 生长曲线。") }
            }
            .navigationTitle("宝宝").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成", systemImage: "checkmark") { if hasBirth { app.birth = Day(date) }; dismiss() } } }
            .onAppear { if let b = app.birth { date = b.date } }
        }
        .presentationDetents([.medium])
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
                    Text("芽芽月历").font(.title.weight(.bold)).padding(.top, 8)
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
