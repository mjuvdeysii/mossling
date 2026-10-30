import SwiftUI
import LocalAuthentication

/// Me: the family first (Moss the child and Otto the grown-up, and the child's details, edited in a sheet), the growth
/// book, then how the app looks, its features and the data. Nothing here repeats the home or the records.
struct YouView: View {
    @Environment(AppModel.self) private var app
    @Binding var path: NavigationPath
    @State private var editing = false
    @Environment(JournalStore.self) private var j
    @State private var message: String?

    var body: some View {
        @Bindable var app = app
        ScrollView {
            // the whole page in one screen, filling it down to the tab bar without crowding: the family, the book, then
            // one card of settings and one of data
            VStack(alignment: .leading, spacing: 14) {
                // the family: the child's own portrait and who the child is, then the companion (Moss or Otto) to choose
                FamilyCard { editing = true }

                // the growth book: a page for every month lived, from what is already recorded
                if app.birth != nil { GrowthBookCard() }

                // settings, as rows of one card: how the app looks (日光 / 夜灯 / 自动 as small living windows), the lamp
                // coming on by itself at night, and the two features
                let face = LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) || app.lock
                Group {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            IconTile(symbol: "paintpalette.fill", color: Crayon.lilac, size: 28, round: true)
                            Text("外观").font(.subheadline.weight(.semibold))
                            Spacer(minLength: 4)
                            HStack(spacing: 6) {
                                ForEach([ThemeMode.light, .dark, .system], id: \.self) { t in
                                    Swatch(mode: t, on: app.theme == t) { withAnimation(.snappy) { app.theme = t } }
                                        .frame(width: 58)
                                }
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        Divider().padding(.leading, 52)
                        SwitchRow(title: "晚上自动开夜灯", detail: "19:00–6:00", symbol: "moon.stars.fill", color: Palette.lampTint, on: $app.nightLight)
                        Divider().padding(.leading, 52)
                        SwitchRow(title: "记录", detail: "显示记录标签页", symbol: "list.bullet.clipboard.fill", color: Crayon.tangerine, on: $app.journal)
                        if face {
                            Divider().padding(.leading, 52)
                            SwitchRow(title: "面容 ID", detail: "打开时解锁", symbol: "faceid", color: Crayon.leaf, on: $app.lock)
                        }
                    }
                    .printCard(radius: 22)
                }

                // data and about, as two rows of one card (export, import and clearing are on the 数据 page)
                VStack(spacing: 0) {
                    NavigationLink(value: Route.data) { DataRow(title: "数据", detail: "导出 · 导入 · 清除；记录只存在这台手机上", symbol: "square.and.arrow.up.on.square", color: Crayon.sky) }
                    Divider().padding(.leading, 58)
                    NavigationLink(value: Route.about) { DataRow(title: "关于摸索台灯", detail: "内容来源 · 条款与隐私 · 反馈", symbol: "info", color: Crayon.pebble) }
                }
                .buttonStyle(.toy)
                .printCard(radius: 22)
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.lilac)
        .navigationTitle("我的")
        .sheet(isPresented: $editing) { ProfileSheet() }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("好") {} }
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
        VStack(alignment: .leading, spacing: 10) {
            // the scene beside who the child is, not over it (the growth map is the big picture of the hill)
            HStack(alignment: .top, spacing: 12) {
                BabyPortrait(month: baby, sex: app.sex, giggle: giggles)
                    .frame(width: type.isAccessibilitySize ? 84 : 96, height: type.isAccessibilitySize ? 84 : 96)
                    .contentShape(Circle())
                    .onTapGesture { giggles += 1 }
                    .sensoryFeedback(.impact(weight: .light), trigger: giggles)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(app.nickname.isEmpty ? "宝宝" : app.nickname).font(.title3.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
                        Spacer(minLength: 4)
                        Button(action: edit) {
                            Label("编辑", systemImage: "pencil").font(.caption.weight(.semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().fill(Palette.accentFill))
                                .contentShape(Capsule().inset(by: -8))
                        }
                        .buttonStyle(.toy)
                        .accessibilityLabel("编辑宝宝信息")
                    }
                    if let a = app.age {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Ticking(text: "\(a.months)").font(Typeface.numerals(24, relativeTo: .title2, weight: .bold))
                            Text("个月").font(.subheadline.weight(.semibold)).fixedSize()
                            if a.days > 0 {
                                Ticking(text: "\(a.days)").font(Typeface.numerals(18, relativeTo: .headline, weight: .bold)).padding(.leading, 4)
                                Text("天").font(.subheadline.weight(.semibold)).fixedSize()
                            }
                        }
                        .fixedSize()
                        .foregroundStyle(Palette.accent)
                    }
                    if !type.isAccessibilitySize { facts }
                }
            }
            if type.isAccessibilitySize { facts }
            Divider()
            // who keeps the child company in the app: Moss or Otto, chosen here (tap the chosen one and it answers)
            CompanionPicker()
        }
        .padding(14)
        .printCard(radius: 28)
    }

    /// The child's facts as small chips that wrap (never a line that scrolls sideways).
    private var facts: some View {
        let birth = app.birth.map { b in String(b.y) + "年" + b.md + "出生" }
        let lived = app.age.map { "第 \($0.lived) 天" }
        let sex = app.sex == "boy" ? "男孩" : app.sex == "girl" ? "女孩" : nil
        let stage = app.age.map { _ in "这一段：" + Self.stretch[GrowingChild.stage(app.babyMonth ?? 0)] }
        return FlowRow(spacing: 10, lineSpacing: 3) {
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
            Text(t).font(.caption2.weight(.semibold)).fixedSize()
        }
        .foregroundStyle(strong ? Palette.accent : Palette.secondaryText)
        .padding(.horizontal, strong ? 7 : 0).padding(.vertical, strong ? 3 : 1)
        .background(Capsule().fill(strong ? Palette.accent.opacity(0.12) : .clear))
    }

}

/// The child's own portrait: the child at this stage of growing, framed in a round of the child's colour — a rosy pink
/// with a small flower for a girl, a sky blue with a little boat for a boy, a warm gold when not said. (The growth map
/// is the landscape; this is the face.) Tapped, the child giggles.
private struct BabyPortrait: View {
    let month: Int, sex: String?, giggle: Int
    @Environment(\.lamp) private var lamp
    var body: some View {
        let girl = sex == "girl", boy = sex == "boy"
        let tone = girl ? Crayon.pink : boy ? Crayon.sky : Crayon.sunflower
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            ZStack {
                Circle().fill(RadialGradient(colors: [tone.opacity(lamp ? 0.5 : 0.32), tone.opacity(lamp ? 0.22 : 0.14)], center: UnitPoint(x: 0.5, y: 0.35), startRadius: 0, endRadius: s * 0.6))
                // the figures carry a margin: the child is drawn larger so it fills the round, sitting on its lower edge
                GrowingChild(month: month, giggle: giggle)
                    .frame(width: s * 1.15, height: s * 1.15)
                    .offset(y: s * 0.12)
                    .frame(width: s, height: s)
                    .clipShape(Circle())
                Circle().strokeBorder(Color.white.opacity(lamp ? 0.25 : 0.9), lineWidth: 2.5)
            }
            .frame(width: s, height: s)
            .overlay(alignment: .topTrailing) {
                if girl || boy {
                    Image(systemName: girl ? "camera.macro" : "sailboat.fill")
                        .font(.system(size: s * 0.14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: s * 0.3, height: s * 0.3)
                        .background(Circle().fill(tone))
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                        .offset(x: 2, y: -2)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityElement().accessibilityAddTraits(.isImage)
        .accessibilityLabel(sex == "girl" ? "女宝宝" : sex == "boy" ? "男宝宝" : "宝宝")
    }
}

/// The companion for the app — the one at the child's side on the pages, in the records and on the widgets: Moss or
/// Otto, side by side in one row, each with a word on their way of being. The chosen one stands on a spot of light;
/// tapping the other brings it forward, tapping the chosen one makes it answer.
private struct CompanionPicker: View {
    @Environment(AppModel.self) private var app
    @Environment(\.lamp) private var lamp
    @State private var cheer = 0
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Kind.allCases, id: \.self) { k in
                let on = app.companion == k
                Button {
                    if on { cheer += 1 } else { withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) { app.companion = k }; cheer += 1 }
                } label: {
                    HStack(alignment: .center, spacing: 6) {
                        Creature(kind: k, mood: on ? .happy : .open, look: CGPoint(x: k == .moss ? 0.6 : -0.6, y: 0.1), lid: k == .otto && lamp ? 0.5 : nil,
                                 alive: on, poke: false, arms: on && cheer % 2 == 1 ? .cheer : .rest, glow: k == .otto && lamp)
                            .frame(width: (on ? 40 : 32) * k.scale, height: (on ? 40 : 32) * k.scale)
                            .frame(width: 44, height: 44, alignment: .bottom)
                            .background(alignment: .bottom) {
                                if on { Ellipse().fill(RadialGradient(colors: [(lamp ? Palette.amber : Palette.bead).opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: 24)).frame(width: 46, height: 10).offset(y: 3) }
                            }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(k.rawValue).font(.subheadline.weight(on ? .bold : .semibold)).foregroundStyle(on ? Color.primary : Palette.secondaryText)
                            Text(k.trait).font(.caption2).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? Palette.accent.opacity(lamp ? 0.18 : 0.08) : .clear))
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.toy)
                .accessibilityLabel("陪伴伙伴 \(k.rawValue)，\(k.trait)").accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: cheer)
    }
}

/// Chips laid out in lines that wrap, left to right.
private struct FlowRow: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > w { y += line + lineSpacing; x = 0; line = 0 }
            x += s.width + spacing; line = max(line, s.height); widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + line)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, line: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > b.minX && x + s.width > b.maxX { y += line + lineSpacing; x = b.minX; line = 0 }
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
            ZStack(alignment: .bottom) {
                preview
                    .frame(height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(on ? Palette.accent : Color.secondary.opacity(0.2), lineWidth: on ? 2.5 : 1))
                    .overlay(alignment: .topTrailing) {
                        if on { Image(systemName: "checkmark.circle.fill").font(.caption2).foregroundStyle(.white, Palette.accentFill).padding(3) }
                    }
                // the name on the window itself, on a small plate that reads on day and night alike
                HStack(spacing: 2) {
                    Image(systemName: mode == .light ? "sun.max.fill" : mode == .dark ? "lamp.desk.fill" : "circle.lefthalf.filled")
                        .font(.system(size: 8, weight: .bold)).foregroundStyle(mode == .light ? Crayon.ink(Crayon.sunflower) : mode == .dark ? Palette.lampTint : Palette.secondaryText)
                    Text(mode.label).font(.caption2.weight(on ? .bold : .semibold)).foregroundStyle(.primary)
                }
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 3)
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

/// One settings row with a switch: its sticker, what it is, a word on it, the switch.
private struct SwitchRow: View {
    let title: String, detail: String, symbol: String, color: Color
    @Binding var on: Bool
    var body: some View {
        Toggle(isOn: $on) {
            HStack(spacing: 10) {
                IconTile(symbol: symbol, color: color, size: 28, round: true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(detail).font(.caption).foregroundStyle(Palette.secondaryText).monospacedDigit()
                }
            }
        }
        .tint(Palette.accent)
        .padding(.horizontal, 14).padding(.vertical, 9)
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
    @State private var hops = 0
    @State private var lamp = false
    @State private var story = false
    var body: some View {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        List {
            // the two and the name in one row, the line about the app under them; tap the two and they hop, and on
            // the third tap they take you into their story (the page names no way in)
            Section {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .bottom, spacing: 14) {
                        Duo(primary: app.companion, size: 64, cheer: hops, lit: lamp)
                            .storyKnock(hops: $hops, lamp: $lamp) { story = true }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("摸索台灯").font(.title2.weight(.bold))
                            Text("孩子摸索，大人点灯").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.accent)
                            Text("Moss & Otto · 版本 \(v)（\(b)）").font(.caption).foregroundStyle(Palette.secondaryText).monospacedDigit()
                        }
                        .padding(.bottom, 4)
                        Spacer(minLength: 0)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 0, trailing: 4))
            }
            Section {
                row(Route.sources, "内容来源", "books.vertical.fill", Crayon.caramel)
                row(Route.licenses, "许可与致谢", "checkmark.seal.fill", Crayon.aqua)
            } header: { Text("制作") }
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
                // the page's small print lives where it belongs (who made it → 许可与致谢; where the content comes from →
                // 内容来源; that it is not medical advice → 免责声明 and the first launch); here only what answers a tap
                VStack(alignment: .leading, spacing: 6) {
                    if replay { Text("下次打开应用时，使用提示会重新出现。") }
                    // the App filing number, shown where the filing rules ask (设置 / 关于), once there is one
                    if let icp = Bundle.main.infoDictionary?["MosslingICP"] as? String, !icp.isEmpty {
                        Link("ICP备案号：\(icp)", destination: URL(string: "https://beian.miit.gov.cn/")!).font(.footnote.weight(.semibold))
                    }
                }
                .padding(.top, 4)
            }
        }
        .listSectionSpacing(.compact)
        .contentMargins(.top, 0, for: .scrollContent)
        .scrollContentBackground(.hidden).pageBackground()
        .navigationDestination(isPresented: $story) { StoryView() }
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
            VStack(alignment: .leading, spacing: 14) {
                // the hidden door between the two worlds: tap this picture ten times quickly and colour runs from it into the 2D
                // world of build 196; in it, keep a finger moving on the picture for three seconds to come back
                StyleDoor {
                    LampScene(play: true)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                Text("孩子摸索，大人点灯").font(.title2.weight(.bold))
                // the two names as two cards to turn over: each face shows who it is and a line; turned, the whole of it
                HStack(alignment: .top, spacing: 10) {
                    pair("摸索", "孩子", "用手、用嘴、用眼睛摸索世界", "0–3 岁的孩子用手、用嘴、用眼睛摸索世界，每个月都会摸到一点新的东西。Moss 的名字取自「摸索」，头上的新芽一直在长。", Palette.moss, .moss)
                    pair("台灯", "大人", "不替人走路，只把桌面照亮", "台灯不替人走路，只把桌面照亮，安静地陪在旁边。Otto 头顶的金色灯珠就是这盏灯。", Palette.rod, .otto)
                }
                .fixedSize(horizontal: false, vertical: true)   // both cards as tall as the taller
                // what is done here: three small cards, a line on the face, the whole of it on the back
                HStack(alignment: .top, spacing: 8) {
                    thing("square.grid.2x2.fill", Crayon.sunflower, "一起玩", "一步步的图", "本周的架子上放着这个月可以摸索的教具，点开就是一步步的图。")
                    thing("leaf.fill", Crayon.leaf, "看他长大", "一月一站", "0–36 个月，一个月一站，共 37 站；成长地图和成长册留下每一站的样子。")
                    thing("list.bullet.clipboard.fill", Crayon.tangerine, "记下来", "可选 · 只存本机", "喂奶、睡眠、尿布一点即记（可选），只保存在这部手机里。")
                }
                .fixedSize(horizontal: false, vertical: true)
                Text("陪 0–3 岁的孩子一起玩，看他一个月一个月长大，把每一天记下来。这里不打分，不比较，也不催促；每个孩子都按自己的节奏，一个月长出一点新的样子。")
                    .font(.subheadline).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                StoryGoesOn(primary: app.companion)
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle("摸索台灯的故事").navigationBarTitleDisplayMode(.inline)
    }

    private func pair(_ word: String, _ who: String, _ line: String, _ text: String, _ c: Color, _ k: Kind) -> some View {
        TurnCard(label: "\(word)，属于\(who)。\(text)") {
            VStack(spacing: 6) {
                Creature(kind: k, look: CGPoint(x: k == .moss ? 0.6 : -0.6, y: 0.2), alive: true)
                    .frame(width: 58 * k.scale, height: 58 * k.scale).frame(height: 64, alignment: .bottom)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(word).font(.title3.weight(.bold)).foregroundStyle(c)
                    Text("属于" + who).font(.caption).foregroundStyle(Palette.secondaryText)
                }
                Text(line).font(.footnote).foregroundStyle(.primary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        } back: {
            Text(text).font(.footnote).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func thing(_ sym: String, _ c: Color, _ t: String, _ line: String, _ d: String) -> some View {
        TurnCard(label: "\(t)。\(d)", radius: 18, padding: 10) {
            VStack(alignment: .leading, spacing: 6) {
                IconTile(symbol: sym, color: c, size: 30)
                Text(t).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                Text(line).font(.caption).foregroundStyle(Palette.secondaryText).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } back: {
            Text(d).font(.caption).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A card that turns over when tapped: a picture and a line on its face, the whole of it on the back — the page says
/// little until it is touched. Both faces take the size of the larger; under Reduce Motion it simply changes face.
struct TurnCard<Front: View, Back: View>: View {
    let label: String
    var radius: CGFloat = 22
    var padding: CGFloat = 14
    @ViewBuilder let front: Front
    @ViewBuilder let back: Back
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var turned = false
    var body: some View {
        ZStack {
            front.opacity(turned ? 0 : 1)
            back.opacity(turned ? 1 : 0).rotation3DEffect(.degrees(reduce ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .card(Palette.card, radius: radius, padding: padding)
        .rotation3DEffect(.degrees(turned && !reduce ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(reduce ? nil : .spring(duration: 0.55, bounce: 0.2)) { turned.toggle() } }
        .sensoryFeedback(.selection, trigger: turned)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
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
            } header: { Text("参考文献 · \(app.content.sources.count + 1) 项") } footer: {
                Text("育儿内容整理自公开发布的机构资料，每一条都注明来源。")
            }
        }
        .scrollContentBackground(.hidden).pageBackground()
        .navigationTitle("内容来源")
    }
}

struct LicensesView: View {
    var body: some View {
        List {
            Section("制作") {
                row("摸索台灯", "由创作者本人构思与主导，借助 AI（Anthropic 的 Claude）辅助完成产品设计、插画与代码。", "Moss & Otto")
            }
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
