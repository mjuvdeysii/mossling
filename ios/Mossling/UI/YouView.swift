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
                                    .font(.caption).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
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

                // the growth book: a page for every month lived, from what is already recorded
                if app.birth != nil { GrowthBookCard() }

                // how the app looks: 日光 or 夜灯 as small living windows, and the lamp coming on by itself at night
                Section2(title: "外观") {
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            ForEach([ThemeMode.light, .dark, .system], id: \.self) { t in
                                Swatch(mode: t, on: app.theme == t) { withAnimation(.snappy) { app.theme = t } }
                            }
                        }
                        Divider()
                        Toggle(isOn: $app.nightLight) {
                            HStack(spacing: 8) {
                                Image(systemName: "moon.stars.fill").font(.footnote).foregroundStyle(Palette.lampTint)
                                Text("晚上自动开夜灯").font(.subheadline.weight(.semibold))
                                Text("19:00–6:00").font(.caption).foregroundStyle(Palette.secondaryText).monospacedDigit()
                            }
                        }
                        .tint(Palette.accent)
                    }
                    .padding(12).printCard(radius: 22)
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
                        // export and import have their own page (no menu popping out of a card)
                        NavigationLink(value: Route.data) { DataRow(title: "导出与导入", detail: "给医生或 AI 看的记录 · 完整备份 · 表格", symbol: "square.and.arrow.up.on.square", color: Crayon.sky) }
                        Divider().padding(.leading, 58)
                        Button(role: .destructive) { clearing = true } label: {
                            HStack { Text("清除全部数据").font(.subheadline.weight(.semibold)); Spacer() }
                                .foregroundStyle(Palette.danger).padding(.horizontal, 16).padding(.vertical, 14).contentShape(Rectangle())
                        }
                    }
                    .buttonStyle(.toy)
                    .printCard(radius: 22)
                    Text("所有记录只保存在这台手机上。").font(.caption).foregroundStyle(Palette.secondaryText).padding(.leading, 4)
                }

                if face {
                    NavigationLink(value: Route.about) {
                        HStack(spacing: 12) {
                            IconTile(symbol: "info", color: Crayon.sky, size: 32)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("关于摸索台灯").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                Text("内容来源 · 条款与隐私 · 反馈").font(.caption).foregroundStyle(Palette.secondaryText)
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
            Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Palette.secondaryText).padding(.leading, 4)
            content
        }
    }
}

/// The two companions on a little stage. The chosen one stands in front, larger; tap the other and it hops forward
/// while the first steps back. The choice changes who stands in front and how they move, never what the app can do:
/// Moss is curious (quick double glances, leaning in), Otto is focused (one slow look, a slow blink, the lamp on his head).
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
                            .frame(width: (on ? 76 : 54) * k.scale, height: (on ? 76 : 54) * k.scale)
                            .frame(height: 92, alignment: .bottom)
                        Text(k.rawValue).font(.subheadline.weight(on ? .bold : .semibold)).foregroundStyle(on ? Color.primary : Palette.secondaryText)
                        Text(k.trait).font(.caption2).foregroundStyle(Palette.secondaryText).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 124)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())   // the whole half of the stage is the button, not just the drawing
                }
                .buttonStyle(.toy)
                .accessibilityLabel("主伙伴 \(k.rawValue)，\(k.trait)").accessibilityAddTraits(on ? .isSelected : [])
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

/// One appearance to choose, as a small living window of it: 日光 with its sunlight, seeds and grassy hill moving,
/// 夜灯 with the lamp's glow breathing and motes rising, 自动 half of each. The chosen one is ringed and ticked.
private struct Swatch: View {
    let mode: ThemeMode
    let on: Bool
    let pick: () -> Void
    var body: some View {
        Button(action: pick) {
            VStack(spacing: 6) {
                preview
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? Palette.accent : Color.secondary.opacity(0.2), lineWidth: on ? 2.5 : 1))
                    .overlay(alignment: .topTrailing) {
                        if on { Image(systemName: "checkmark.circle.fill").font(.footnote).foregroundStyle(.white, Palette.accentFill).padding(5) }
                    }
                HStack(spacing: 4) {
                    Image(systemName: mode == .light ? "sun.max.fill" : mode == .dark ? "lamp.desk.fill" : "circle.lefthalf.filled")
                        .font(.caption2).foregroundStyle(mode == .light ? Crayon.ink(Crayon.sunflower) : mode == .dark ? Palette.lampTint : Palette.secondaryText)
                    Text(mode.label).font(.caption.weight(on ? .bold : .medium)).foregroundStyle(on ? Color.primary : Palette.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.toy)
        .accessibilityLabel(mode.label)
        .accessibilityAddTraits(on ? .isSelected : [])
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

/// A square-ish settings tile: icon, title, a word of state.
private struct Tile: View {
    let title: String, detail: String, symbol: String, color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            IconTile(symbol: symbol, color: color, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(detail).font(.caption).foregroundStyle(Palette.secondaryText).lineLimit(1)
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
                Text(detail).font(.caption).foregroundStyle(Palette.secondaryText)
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

/// About, in the order a parent asks: what this is (the name and its story), who made it and how (AI-assisted, with
/// the content's sources), the documents, help. Every row is the same shape: an icon tile, one name, a chevron.
struct AboutView: View {
    @Environment(AppModel.self) private var app
    @State private var replay = false
    var body: some View {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        List {
            Section {
                VStack(spacing: 6) {
                    Duo(primary: app.companion, size: 96)
                    Text("摸索台灯").font(.title.weight(.bold)).padding(.top, 8)
                    Text("孩子摸索，大人点灯").font(.headline).foregroundStyle(Palette.accent)
                    Text("Moss & Otto · 版本 \(v)（\(b)）").font(.footnote).foregroundStyle(Palette.secondaryText).monospacedDigit()
                }
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }
            Section {
                row(Route.story, "摸索台灯的故事", "lamp.desk.fill", Crayon.sunflower)
            } footer: {
                Text("陪 0–3 岁的孩子一起玩，看他一个月一个月长大，把每一天记下来。不打分，不比较，不催促。")
            }
            Section {
                row(Route.sources, "内容来源", "books.vertical.fill", Crayon.caramel)
                row(Route.licenses, "许可与致谢", "checkmark.seal.fill", Crayon.aqua)
            } header: { Text("制作") } footer: {
                Text("摸索台灯由创作者本人构思与主导，借助 AI（Anthropic 的 Claude）辅助完成产品设计、插画与代码。育儿内容整理自公开发布的机构资料，每一条都注明来源。")
            }
            Section("文件") {
                row(Route.doc("TERMS"), "使用条款", "doc.text.fill", Crayon.pebble)
                row(Route.doc("PRIVACY"), "隐私政策", "hand.raised.fill", Crayon.sky)
                row(Route.doc("DISCLAIMER"), "免责声明", "exclamationmark.shield.fill", Crayon.tangerine)
                row(Route.doc("CHANGELOG"), "更新日志", "clock.arrow.circlepath", Crayon.lilac)
            }
            Section {
                Button { Guide.replayNextLaunch(); replay = true } label: {
                    Label { Text("重新显示使用提示") } icon: { IconTile(symbol: "lightbulb.fill", color: Crayon.sunflower) }
                }
                .tint(.primary).disabled(replay)
                Link(destination: URL(string: "https://github.com/mjuvdeysii/mossling/issues")!) { Label { Text("反馈问题") } icon: { IconTile(symbol: "envelope.fill", color: Crayon.leaf) } }
                    .tint(.primary)
            } header: { Text("帮助") } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if replay { Text("下次打开应用时，使用提示会重新出现。") }
                    Text("本应用陪伴家庭养育，不构成医疗诊断或治疗建议。对孩子的健康或发育有疑虑，请咨询儿科医生或当地妇幼保健机构。")
                    // the App filing number, shown where the filing rules ask (设置 / 关于), once there is one
                    if let icp = Bundle.main.infoDictionary?["MosslingICP"] as? String, !icp.isEmpty {
                        Link("ICP备案号：\(icp)", destination: URL(string: "https://beian.miit.gov.cn/")!).font(.footnote.weight(.semibold))
                    }
                }
                .padding(.top, 4)
            }
        }
        .scrollContentBackground(.hidden).pageBackground()
        .navigationTitle("关于摸索台灯").navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ r: Route, _ t: String, _ sym: String, _ c: Color) -> some View {
        NavigationLink(value: r) { Label { Text(t) } icon: { IconTile(symbol: sym, color: c) } }
    }
}

/// The name, told: the opening scene still, then what 摸索 and 台灯 mean, what the app does and does not do, and that
/// the story goes on past 36 months (docs/IP.md).
struct StoryView: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LampScene(play: true)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                Text("孩子摸索，大人点灯").font(.title.weight(.bold))
                pair("摸索", "孩子", "0–3 岁的孩子用手、用嘴、用眼睛摸索世界，每个月都会摸到一点新的东西。Moss 的名字取自「摸索」，头上的新芽一直在长。", Palette.moss, .moss)
                pair("台灯", "大人", "台灯不替人走路，只把桌面照亮，安静地陪在旁边。Otto 头顶的金色灯珠就是这盏灯。", Palette.rod, .otto)
                VStack(alignment: .leading, spacing: 12) {
                    Text("在这里做的三件事").font(.headline)
                    thing("square.grid.2x2.fill", Crayon.sunflower, "一起玩", "本周的架子上放着这个月可以摸索的教具，点开就是一步步的图。")
                    thing("leaf.fill", Crayon.leaf, "看他长大", "0–36 个月，一个月一站，共 37 站；成长滚轮和成长册留下每一站的样子。")
                    thing("list.bullet.clipboard.fill", Crayon.tangerine, "记下来（可选）", "喂奶、睡眠、尿布一点即记，只保存在这部手机里。")
                }
                .card(Palette.card, radius: 24, padding: 18)
                Text("这里不打分，不比较，也不催促。每个孩子都按自己的节奏，一个月长出一点新的样子。")
                    .font(.body).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                StoryGoesOn(primary: app.companion)
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle("摸索台灯的故事").navigationBarTitleDisplayMode(.inline)
    }

    private func pair(_ word: String, _ who: String, _ text: String, _ c: Color, _ k: Kind) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Creature(kind: k, look: CGPoint(x: k == .moss ? 0.6 : -0.6, y: 0.2), alive: true).frame(width: 60 * k.scale, height: 60 * k.scale).frame(width: 72, height: 72, alignment: .bottom).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(word).font(.title2.weight(.bold)).foregroundStyle(c)
                    Text("属于" + who).font(.subheadline).foregroundStyle(Palette.secondaryText)
                }
                Text(text).font(.body).fixedSize(horizontal: false, vertical: true)
            }
        }
        .card(Palette.card, radius: 24, padding: 16)
        .accessibilityElement(children: .combine)
    }

    private func thing(_ sym: String, _ c: Color, _ t: String, _ d: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            IconTile(symbol: sym, color: c, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(.subheadline.weight(.semibold))
                Text(d).font(.subheadline).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A Markdown document from the repository (terms, privacy, disclaimer, changelog), set as a document.
struct DocView: View {
    let name: String
    var body: some View {
        let raw = (Bundle.main.url(forResource: name, withExtension: "md").flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "读取不到这份文件。")
            .replacingOccurrences(of: "安卓应用", with: "应用")
        let lines = raw.components(separatedBy: "\n")
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
                        HStack(alignment: .firstTextBaseline) { Text("\(i + 1)").font(.footnote.monospacedDigit()).foregroundStyle(Palette.secondaryText).frame(minWidth: 20, alignment: .leading); Text(s.org).font(.headline) }
                        Text(s.title).font(.subheadline)
                        Text([s.date, s.checked].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "；")).font(.caption).foregroundStyle(Palette.secondaryText)
                        if let u = s.url, let url = URL(string: u), !u.isEmpty { Link(u, destination: url).font(.caption).lineLimit(2) }
                    }
                    .padding(.vertical, 2)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) { Text("\(app.content.sources.count + 1)").font(.footnote.monospacedDigit()).foregroundStyle(Palette.secondaryText).frame(minWidth: 20, alignment: .leading); Text("World Health Organization").font(.headline) }
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
