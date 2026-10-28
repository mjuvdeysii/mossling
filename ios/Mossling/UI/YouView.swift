import SwiftUI
import LocalAuthentication

/// Me: the family first (Moss the child and Otto the grown-up, and the child's details, edited in a sheet), the growth
/// book, then how the app looks, its features and the data. Nothing here repeats the home or the records.
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
                // the family: the child (Moss) and the grown-up (Otto) at home on the child's own hill, then who the child is
                FamilyCard { editing = true }

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
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.lilac)
        .navigationTitle("我的")
        .sheet(isPresented: $editing) { ProfileSheet() }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("好") {} }
        .confirmationDialog("清除这台手机上的全部记录和设置？", isPresented: $clearing, titleVisibility: .visible) {
            Button("全部清除", role: .destructive) { app.clearAll(); j.reload() }
        } message: { Text("清除后无法恢复。") }
    }

}

/// The family, at the top of 我的: who the app is for and who it is from. The child is Moss — at the child's own stage
/// (asleep in a leaf nest, sitting up, stepping along…), on the stone of the child's own month, on the hill of the
/// child's own year, as on the growth map — and the grown-up beside him is Otto with his lamp: 孩子摸索，大人点灯. By
/// night the child is home asleep and Otto's lamp comes on for a moment. Under the scene, the child: name, age, the day
/// count, the sex (for the WHO curves) and what this stretch of growing is about; then the two, each with their way of
/// being. Tap Moss and he giggles; 编辑 opens the child's details.
private struct FamilyCard: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.lamp) private var night
    let edit: () -> Void
    @State private var giggles = 0

    private static let stretch = ["躺着看世界", "趴着抬起头", "坐起来看", "往前爬", "站起来", "迈开步子", "跑起来"]

    var body: some View {
        let baby = app.babyMonth ?? 0
        VStack(alignment: .leading, spacing: 0) {
            MapVignette(month: baby, baby: baby, otto: true, giggle: giggles)
                .frame(height: 176)
                .contentShape(Rectangle())
                .onTapGesture { giggles += 1 }
                .sensoryFeedback(.impact(weight: .light), trigger: giggles)
                .accessibilityElement().accessibilityLabel("Moss 和 Otto 在家").accessibilityAddTraits(.isImage)
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(app.nickname.isEmpty ? "宝宝" : app.nickname).font(.title2.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Button(action: edit) {
                        Label("编辑", systemImage: "pencil").font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.vinyl(Palette.accentFill, prominent: true))
                    .accessibilityLabel("编辑宝宝信息")
                }
                if let a = app.age {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Ticking(text: "\(a.months)").font(Typeface.numerals(28, relativeTo: .title2, weight: .bold))
                        Text("个月").font(.subheadline.weight(.semibold)).fixedSize()
                        if a.days > 0 {
                            Ticking(text: "\(a.days)").font(Typeface.numerals(20, relativeTo: .headline, weight: .bold)).padding(.leading, 4)
                            Text("天").font(.subheadline.weight(.semibold)).fixedSize()
                        }
                    }
                    .fixedSize()
                    .foregroundStyle(Palette.accent)
                }
                facts
                Divider()
                // the two side by side (one column at the largest text sizes)
                let roles = type.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10)) : AnyLayout(HStackLayout(alignment: .top, spacing: 10))
                roles {
                    role(.moss, "宝宝", Kind.moss.trait)
                    role(.otto, "大人", Kind.otto.trait)
                }
            }
            .padding(16)
        }
        .printCard(radius: 28)
    }

    /// The child's facts as small chips that wrap (never a line that scrolls sideways).
    private var facts: some View {
        let birth = app.birth.map { b in String(b.y) + "年" + b.md + "出生" }
        let lived = app.age.map { "第 \($0.lived) 天" }
        let sex = app.sex == "boy" ? "男孩" : app.sex == "girl" ? "女孩" : nil
        let stage = app.age.map { _ in "这一段：" + Self.stretch[GrowingChild.stage(app.babyMonth ?? 0)] }
        return FlowRow(spacing: 6) {
            if let birth { chip(birth, "calendar") } else {
                Button(action: edit) { chip("填写出生日期", "calendar.badge.plus", strong: true) }.buttonStyle(.toy)
            }
            if let lived { chip(lived, "sun.max") }
            if let sex { chip(sex, "figure.child") } else {
                Button(action: edit) { chip("填写性别", "plus", strong: true) }.buttonStyle(.toy)
            }
            if let stage { chip(stage, "leaf") }
        }
    }

    private func chip(_ t: String, _ symbol: String, strong: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).font(.caption2.weight(.bold))
            Text(t).font(.caption.weight(.semibold)).fixedSize()
        }
        .foregroundStyle(strong ? Palette.accent : Palette.secondaryText)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(strong ? Palette.accent.opacity(0.12) : Palette.outline.opacity(0.3)))
    }

    private func role(_ k: Kind, _ who: String, _ trait: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Creature(kind: k, look: CGPoint(x: k == .moss ? 0.6 : -0.6, y: 0.1), lid: k == .otto && night ? 0.5 : nil, alive: true, poke: true, glow: k == .otto && night)
                .frame(width: 34 * k.scale, height: 34 * k.scale)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(k.rawValue).font(.subheadline.weight(.bold))
                    Text(who).font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().strokeBorder(Palette.outline, lineWidth: 1))
                }
                Text(trait).font(.caption).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Chips laid out in lines that wrap, left to right.
private struct FlowRow: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > w { y += line + spacing; x = 0; line = 0 }
            x += s.width + spacing; line = max(line, s.height); widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + line)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, line: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > b.minX && x + s.width > b.maxX { y += line + spacing; x = b.minX; line = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; line = max(line, s.height)
        }
    }
}

/// A titled group on the 我的 page: a small heading over its content.
private struct Section2<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                GoldBead(size: 7)
                Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Palette.secondaryText)
            }
            .padding(.leading, 4).accessibilityAddTraits(.isHeader)
            content
        }
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
                // the hidden door between the two worlds: tap this picture five times and it shatters into the 2D
                // world of build 196; in it, keep a finger moving on the picture for three seconds to come back
                StyleDoor {
                    LampScene(play: true)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                Text("孩子摸索，大人点灯").font(.title.weight(.bold))
                pair("摸索", "孩子", "0–3 岁的孩子用手、用嘴、用眼睛摸索世界，每个月都会摸到一点新的东西。Moss 的名字取自「摸索」，头上的新芽一直在长。", Palette.moss, .moss)
                pair("台灯", "大人", "台灯不替人走路，只把桌面照亮，安静地陪在旁边。Otto 头顶的金色灯珠就是这盏灯。", Palette.rod, .otto)
                VStack(alignment: .leading, spacing: 12) {
                    Text("在这里做的三件事").font(.headline)
                    thing("square.grid.2x2.fill", Crayon.sunflower, "一起玩", "本周的架子上放着这个月可以摸索的教具，点开就是一步步的图。")
                    thing("leaf.fill", Crayon.leaf, "看他长大", "0–36 个月，一个月一站，共 37 站；成长地图和成长册留下每一站的样子。")
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
