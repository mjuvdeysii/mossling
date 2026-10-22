import SwiftUI
import LocalAuthentication

/// Me: the child, the companion in front, features, appearance, and about. Nothing here repeats Today or Grow.
struct YouView: View {
    @Environment(AppModel.self) private var app
    @Binding var path: NavigationPath
    @State private var askBirth = false
    @State private var clearing = false

    var body: some View {
        @Bindable var app = app
        List {
            Section {
                HStack(spacing: 14) {
                    Creature(kind: app.companion, mood: .happy).frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.nickname.isEmpty ? "宝宝" : app.nickname).font(Typeface.serif(20))
                        Text(app.birth.map { "\($0.y) 年 \($0.md) 出生" + (app.age.map { " · 第 \($0.lived) 天" } ?? "") } ?? "还没有填写出生日期")
                            .font(.footnote).foregroundStyle(Palette.secondaryText)
                    }
                }
                .padding(.vertical, 4)
                TextField("小名", text: Binding(get: { app.nickname }, set: { app.nickname = String($0.prefix(12)) }))
                Button { askBirth = true } label: { LabeledContent("出生日期", value: app.birth.map { "\($0.y)年\($0.md)" } ?? "填写") }.tint(Palette.text)
                Picker("性别", selection: Binding(get: { app.sex ?? "" }, set: { app.sex = $0.isEmpty ? nil : $0 })) {
                    Text("不填").tag(""); Text("男孩").tag("boy"); Text("女孩").tag("girl")
                }
            } header: { Text("宝宝") } footer: { Text("性别只用于选择 WHO 生长曲线。") }

            Section("伙伴 · 选一位站在前面") {
                HStack(spacing: 12) {
                    ForEach(Kind.allCases, id: \.self) { k in
                        let on = app.companion == k
                        Button { withAnimation(.snappy) { app.companion = k } } label: {
                            VStack(spacing: 4) {
                                Creature(kind: k, mood: on ? .happy : .open, look: CGPoint(x: k == .moss ? 0.8 : -0.8, y: 0)).frame(width: 84, height: 84)
                                Text(k.rawValue).font(Typeface.numerals(20))
                                Text(k == .moss ? "长着薄荷芽，安静地看" : "带着金珠，专心一件事").font(.caption).foregroundStyle(Palette.secondaryText)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(on ? k.tint.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(on ? k.tint : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }

            Section("功能") {
                if LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) || app.lock {
                    Toggle(isOn: $app.lock) { Label("应用锁", systemImage: "faceid") }
                }
            }

            Section("显示") {
                Picker(selection: $app.theme) { ForEach(ThemeMode.allCases, id: \.self) { Text($0.label).tag($0) } } label: { Label("外观", systemImage: "circle.lefthalf.filled") }
            }

            Section("记录") {
                Button(role: .destructive) { clearing = true } label: { Label("清除全部数据", systemImage: "trash") }
            }

            Section {
                NavigationLink(value: Route.about) { Label("关于芽芽月历", systemImage: "info.circle") }
            }
        }
        .navigationTitle("我的")
        .sheet(isPresented: $askBirth) { BirthSheet() }
        .confirmationDialog("清除这台手机上的全部记录和设置？", isPresented: $clearing, titleVisibility: .visible) {
            Button("全部清除", role: .destructive) { app.clearAll() }
        } message: { Text("清除后无法恢复。") }
    }
}

/// About: name, version, the documents, sources and licences, a short disclaimer.
struct AboutView: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        List {
            Section {
                VStack(spacing: 6) {
                    Duo(primary: app.companion, size: 84)
                    Text("芽芽月历").font(Typeface.serif(26)).foregroundStyle(Palette.primary).padding(.top, 6)
                    Text("Mossling · 0–3 岁早教活动规划").font(.subheadline)
                    Text("跟着孩子，一个月一站。").font(.footnote).foregroundStyle(Palette.secondaryText).padding(.top, 4)
                    Text("版本 \(v) · 构建 \(b)").font(.caption).foregroundStyle(Palette.secondaryText)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }
            Section("条款与声明") {
                NavigationLink(value: Route.doc("TERMS")) { Label("使用条款", systemImage: "checkmark.seal") }
                NavigationLink(value: Route.doc("PRIVACY")) { Label("隐私政策", systemImage: "hand.raised") }
                NavigationLink(value: Route.doc("DISCLAIMER")) { Label("免责声明", systemImage: "exclamationmark.bubble") }
            }
            Section("资料") {
                NavigationLink(value: Route.sources) { Label("内容来源", systemImage: "books.vertical") }
                NavigationLink(value: Route.licenses) { Label("开源许可", systemImage: "doc.text") }
                NavigationLink(value: Route.doc("CHANGELOG")) { Label("更新日志", systemImage: "clock.arrow.circlepath") }
                Link(destination: URL(string: "https://github.com/mjuvdeysii/mossling/issues")!) { Label("反馈问题", systemImage: "envelope") }
            }
            Section {
                Text("本应用内容仅供家庭养育参考，不构成医疗诊断或治疗建议。如对儿童健康或发育有疑虑，请咨询儿科医生或当地妇幼保健机构。")
                    .font(.footnote).foregroundStyle(Palette.secondaryText)
            } header: { Text("免责声明") }
        }
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
        .background(Palette.background)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func docLine(_ l: String) -> some View {
        if l.hasPrefix("# ") { Text(l.dropFirst(2)).font(Typeface.serif(26, relativeTo: .largeTitle)).padding(.bottom, 8) }
        else if l.hasPrefix("## ") { VStack(alignment: .leading, spacing: 10) { Divider(); Text(l.dropFirst(3)).font(Typeface.serif(19, relativeTo: .title3)) }.padding(.top, 14) }
        else if l.hasPrefix("- ") { HStack(alignment: .firstTextBaseline, spacing: 8) { Text("•").foregroundStyle(Palette.primary); Text(rich(String(l.dropFirst(2)))).font(.subheadline) } }
        else if let r = l.range(of: #"^\d+\. "#, options: .regularExpression) {
            HStack(alignment: .firstTextBaseline, spacing: 8) { Text(l[r].trimmingCharacters(in: .whitespaces)).font(Typeface.numerals(15)).foregroundStyle(Palette.primary).frame(width: 22, alignment: .leading); Text(rich(String(l[r.upperBound...]))).font(.subheadline) }
        }
        else if l.hasPrefix("|") {
            let cells = l.trimmingCharacters(in: CharacterSet(charactersIn: "|")).components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            if !cells.allSatisfy({ $0.hasPrefix("---") }) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rich(cells.first ?? "")).font(.subheadline.weight(.semibold))
                    ForEach(Array(cells.dropFirst().enumerated()), id: \.offset) { _, c in Text(rich(c)).font(.subheadline).foregroundStyle(Palette.secondaryText) }
                }
                .card(Palette.cardLow, radius: 12, padding: 10)
            }
        }
        else if l.hasPrefix("适用于") || l.hasPrefix("生效日期") { Text(l).font(.footnote).foregroundStyle(Palette.secondaryText) }
        else if l.isEmpty { Color.clear.frame(height: 2) }
        else { Text(rich(l)).font(.subheadline) }
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
                        HStack(alignment: .firstTextBaseline) { Text("[\(i + 1)]").font(Typeface.numerals(14)).foregroundStyle(Palette.primary); Text(s.org).font(.subheadline.weight(.semibold)) }
                        Text(s.title).font(.subheadline)
                        Text([s.date, s.checked].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "；")).font(.caption).foregroundStyle(Palette.secondaryText)
                        if let u = s.url, let url = URL(string: u), !u.isEmpty { Link(u, destination: url).font(.caption).lineLimit(2) }
                    }
                    .padding(.vertical, 2)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) { Text("[\(app.content.sources.count + 1)]").font(Typeface.numerals(14)).foregroundStyle(Palette.primary); Text("World Health Organization").font(.subheadline.weight(.semibold)) }
                    Text("WHO Child Growth Standards：体重、身长 / 身高、头围的年龄别标准").font(.subheadline)
                    Text("2006").font(.caption).foregroundStyle(Palette.secondaryText)
                }
            } header: { Text("参考文献 · \(app.content.sources.count + 1) 项") }
        }
        .navigationTitle("内容来源")
    }
}

struct LicensesView: View {
    var body: some View {
        List {
            Section("字体") {
                row("Young Serif", "SIL Open Font License 1.1", "© The Young Serif Project Authors")
                row("Noto Serif SC", "SIL Open Font License 1.1", "© Google LLC")
            }
            Section("数据") {
                row("WHO Child Growth Standards", "按世界卫生组织的使用条款引用", "© World Health Organization")
            }
            Section("系统框架") {
                row("SwiftUI · WidgetKit · ActivityKit", "Apple SDK", "© Apple Inc.")
            }
        }
        .navigationTitle("开源许可")
    }
    private func row(_ a: String, _ b: String, _ c: String) -> some View {
        VStack(alignment: .leading, spacing: 2) { Text(a).font(.subheadline.weight(.semibold)); Text(b).font(.footnote); Text(c).font(.caption).foregroundStyle(Palette.secondaryText) }
    }
}
