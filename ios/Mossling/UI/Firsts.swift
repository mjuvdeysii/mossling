import SwiftUI

// MARK: 第一次 — the child's firsts
//
// The first time the child sucked a hand, cooed, rolled over, sat, crawled, took a step: moments worth keeping. They
// are not a column of the day (they would be lost among feeds and nappies), and the recorder is not a button that is
// always there (it is needed a few dozen times in three years). It opens from the journal's + menu and from the
// growth book; what is kept goes onto the growth book's page of that month and onto one line of its own — 第一次 —
// that runs from birth to today and is never cut by dates, so every first can always be found.
// The list of common firsts orders the suggestions only: it is not a timetable, and nothing is compared.

enum Firsts {
    struct Kind: Identifiable { let id: String; let title: String; let symbol: String; let color: Color; let around: Int }
    static let all: [Kind] = [
        Kind(id: "smile", title: "第一次笑", symbol: "face.smiling.inverse", color: Crayon.sunflower, around: 1),
        Kind(id: "hand", title: "吃手", symbol: "hand.raised.fill", color: Crayon.peach, around: 2),
        Kind(id: "coo", title: "昂咕（发出咕咕声）", symbol: "bubble.left.fill", color: Crayon.sky, around: 2),
        Kind(id: "headup", title: "趴着抬起头", symbol: "arrow.up.circle.fill", color: Crayon.leaf, around: 2),
        Kind(id: "laugh", title: "笑出声", symbol: "face.smiling.inverse", color: Crayon.tangerine, around: 4),
        Kind(id: "roll", title: "翻身", symbol: "arrow.trianglehead.2.clockwise.rotate.90", color: Crayon.lilac, around: 4),
        Kind(id: "grasp", title: "抓住玩具", symbol: "hand.raised.fingers.spread.fill", color: Crayon.aqua, around: 4),
        Kind(id: "feet", title: "抓到自己的脚", symbol: "figure.child", color: Crayon.pink, around: 5),
        Kind(id: "sit", title: "坐", symbol: "chair.fill", color: Crayon.caramel, around: 6),
        Kind(id: "tooth", title: "长出第一颗牙", symbol: "mouth.fill", color: Crayon.pink, around: 6),
        Kind(id: "solid", title: "第一口辅食", symbol: "fork.knife", color: Crayon.leaf, around: 6),
        Kind(id: "babble", title: "咿咿呀呀连着发音", symbol: "waveform", color: Crayon.sky, around: 7),
        Kind(id: "crawl", title: "爬", symbol: "figure.walk", color: Crayon.tangerine, around: 8),
        Kind(id: "pull", title: "扶着站起来", symbol: "figure.stand", color: Crayon.aqua, around: 9),
        Kind(id: "clap", title: "拍手", symbol: "hands.clap.fill", color: Crayon.sunflower, around: 9),
        Kind(id: "wave", title: "挥手再见", symbol: "hand.wave.fill", color: Crayon.peach, around: 9),
        Kind(id: "mama", title: "叫爸爸 / 妈妈", symbol: "heart.text.square.fill", color: Crayon.pink, around: 10),
        Kind(id: "stand", title: "自己站稳", symbol: "figure.stand", color: Crayon.lilac, around: 11),
        Kind(id: "step", title: "迈出第一步", symbol: "shoeprints.fill", color: Crayon.leaf, around: 12),
        Kind(id: "cup", title: "用杯子喝水", symbol: "cup.and.saucer.fill", color: Crayon.sky, around: 12),
        Kind(id: "haircut", title: "第一次理发", symbol: "scissors", color: Crayon.caramel, around: 12),
        Kind(id: "spoon", title: "自己用勺吃饭", symbol: "fork.knife", color: Crayon.tangerine, around: 15),
        Kind(id: "run", title: "跑起来", symbol: "figure.run", color: Crayon.aqua, around: 18),
        Kind(id: "kick", title: "踢球", symbol: "soccerball", color: Crayon.leaf, around: 20),
        Kind(id: "jump", title: "双脚跳", symbol: "figure.jumprope", color: Crayon.lilac, around: 24),
        Kind(id: "sentence", title: "说出一句话", symbol: "quote.bubble.fill", color: Crayon.sky, around: 24),
        Kind(id: "draw", title: "画出一个圈", symbol: "scribble.variable", color: Crayon.pink, around: 30),
        Kind(id: "potty", title: "自己上厕所", symbol: "toilet.fill", color: Crayon.aqua, around: 30),
    ]
    static func kind(_ key: String?) -> Kind? { key.flatMap { k in all.first { $0.id == k } } }
    /// The common firsts in the order a parent of a child this age would look for them: those around now first,
    /// then the ones a little ahead, then the earlier ones.
    static func ordered(around month: Int?) -> [Kind] {
        guard let m = month else { return all }
        return all.sorted { a, b in
            func rank(_ k: Kind) -> Int { let d = k.around - m; return d >= -1 && d <= 3 ? abs(d) : d > 3 ? 10 + d : 40 - d }
            return rank(a) < rank(b)
        }
    }
    /// "出生第 5 天" / "4 个月 12 天" — the age on that day.
    static func age(from birth: Day, to day: Day) -> String {
        let a = Age.on(birth: birth, today: day)
        if day < birth { return "出生前" }
        if a.months == 0 { return "出生第 \(a.lived) 天" }
        return a.days == 0 ? "满 \(a.months) 个月" : "\(a.months) 个月 \(a.days) 天"
    }
    /// A first the parent named keeps the mark they picked for it, as "icon:<symbol>" in `key`.
    static let customIcons: [(String, Color)] = [("star.fill", Palette.bead), ("heart.fill", Crayon.pink), ("sun.max.fill", Crayon.sunflower),
        ("leaf.fill", Crayon.leaf), ("drop.fill", Crayon.sky), ("music.note", Crayon.lilac), ("airplane", Crayon.aqua), ("gift.fill", Crayon.tangerine),
        ("camera.fill", Crayon.caramel), ("pawprint.fill", Crayon.peach), ("water.waves", Crayon.sky), ("birthday.cake.fill", Crayon.pink)]
    static func customIcon(_ key: String?) -> String? { key.flatMap { $0.hasPrefix("icon:") ? String($0.dropFirst(5)) : nil } }
    static func symbol(_ f: First) -> String { kind(f.key)?.symbol ?? customIcon(f.key) ?? "star.fill" }
    static func color(_ f: First) -> Color {
        if let k = kind(f.key) { return k.color }
        if let i = customIcon(f.key), let c = customIcons.first(where: { $0.0 == i })?.1 { return c }
        return Palette.bead
    }
}

/// "今天" / "昨天" / "10月20日" / "2025年10月20日" — a day, said as people say it.
func whenLabelDay(_ d: Date) -> String {
    let day = Day(d), today = Day.today
    if day == today { return "今天" }
    if day == today.plus(days: -1) { return "昨天" }
    return day.y == today.y ? day.md : "\(day.y)年\(day.md)"
}

/// Records a first, or changes one: what (one of the common firsts, or named), which day, and a line about it.
struct FirstSheet: View {
    @Environment(JournalStore.self) private var j
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lamp) private var lamp
    @State var first: First
    let isNew: Bool
    @State private var day = Date()
    @State private var named = false
    /// The mark of a first the parent names.
    @State private var mark = "star.fill"
    @State private var cheers = 0
    @State private var failed = false
    @FocusState private var typing: Bool

    init(first: First, isNew: Bool) { _first = State(initialValue: first); self.isNew = isNew }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if failed { SaveFailed() }
                    own
                    if isNew { choices }
                    VStack(alignment: .leading, spacing: 0) {
                        DatePicker("哪一天", selection: $day, in: earliest...Date(), displayedComponents: .date)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                        if let b = app.birth {
                            Text(Firsts.age(from: b, to: Day(day))).font(.footnote.weight(.semibold)).foregroundStyle(Palette.secondaryText).monospacedDigit()
                                .padding(.horizontal, 16).padding(.bottom, 12)
                        }
                    }
                    .printCard(radius: Radius.card, fill: lamp ? Palette.lampCard : Palette.card)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("想留下的话（可选）").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                        TextField("当时的样子、在哪里、谁在身边", text: Binding(get: { first.note ?? "" }, set: { first.note = String($0.prefix(200)) }), axis: .vertical)
                            .lineLimit(2...6).padding(14).printCard(radius: Radius.inner, fill: lamp ? Palette.lampCard : Palette.card)
                    }
                    Button { save() } label: { Text(isNew ? "记下这个第一次" : "保存").frame(maxWidth: .infinity) }
                        .buttonStyle(.vinyl(Crayon.fill(Palette.bead, lamp), prominent: true, large: true))
                        .disabled(first.title.trimmingCharacters(in: .whitespaces).isEmpty)
                    if !isNew {
                        Button("删除这个第一次", role: .destructive) { j.deleteFirst(first); dismiss() }
                            .frame(maxWidth: .infinity)
                    }
                    Text("每个孩子的第一次都在自己的时间里到来，这里只记录，不比较。")
                        .font(.footnote).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { PageBackground(tone: Palette.bead) }
            .navigationTitle(isNew ? "记一个第一次" : "这个第一次").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消", systemImage: "xmark") { dismiss() } } }
        }
        .presentationDetents([.large])
        .sensoryFeedback(.success, trigger: cheers)
        .onAppear {
            day = isNew ? Date() : first.date; named = !isNew && Firsts.kind(first.key) == nil
            if let i = Firsts.customIcon(first.key) { mark = i }
        }
    }

    /// Any first at all, in the parent's own words, with a mark of their choosing — written here, or picked below.
    private var own: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isNew ? "自己写一个第一次" : "第一次做了什么").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondaryText)
            TextField("例如：第一次看海、第一次坐飞机", text: Binding(get: { first.title }, set: { v in
                first.title = String(v.prefix(40))
                // typing makes it the parent's own first (unless it is still exactly a common one's name)
                if let k = Firsts.kind(first.key) {
                    if k.title != first.title { first.key = "icon:" + mark; named = true }
                } else { first.key = "icon:" + mark; named = true }
            }))
                .font(.title3.weight(.semibold)).focused($typing).submitLabel(.done)
                .padding(14).printCard(radius: Radius.inner, fill: lamp ? Palette.lampCard : Palette.card)
            if Firsts.kind(first.key) == nil {
                // a mark for it, from a small set
                WrapLayout(spacing: 8) {
                    ForEach(Firsts.customIcons, id: \.0) { sym, c in
                        let on = mark == sym
                        Button { withAnimation(.snappy) { mark = sym; first.key = "icon:" + sym } } label: {
                            Image(systemName: sym).font(.body.weight(.semibold)).frame(width: 40, height: 40)
                                .foregroundStyle(on ? Color.white : Crayon.ink(c))
                                .background(Circle().fill(on ? c : c.opacity(0.16)))
                                .overlay(Circle().strokeBorder(on ? Crayon.ink(c) : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.toy)
                        .accessibilityLabel("标记").accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var earliest: Date { app.birth.map { $0.date } ?? Date.distantPast }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Duo(primary: app.companion, size: 64, mood: .open, look: CGPoint(x: 0.5, y: 0.3), poke: true, cheer: cheers, night: lamp)
            VStack(alignment: .leading, spacing: 4) {
                Text("第一次").font(.largeTitle.weight(.bold))
                Text("把值得记住的瞬间留在成长册里").font(.subheadline).foregroundStyle(Palette.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }

    /// The common firsts, around the child's age first; those already kept are marked and cannot be kept twice.
    private var choices: some View {
        let done = Set(j.firsts.compactMap(\.key))
        return VStack(alignment: .leading, spacing: 10) {
            Text("或者选一个常见的").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondaryText)
            WrapLayout(spacing: 8) {
                ForEach(Firsts.ordered(around: app.babyMonth)) { k in
                    let on = first.key == k.id
                    let kept = done.contains(k.id)
                    Button {
                        withAnimation(.snappy) { first.key = k.id; first.title = k.title; named = false; typing = false }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: kept ? "checkmark.circle.fill" : k.symbol).font(.subheadline.weight(.semibold))
                            Text(k.title)
                        }
                    }
                    .buttonStyle(.vinyl(on ? k.color : kept ? Color(hex: 0xB9AFA4) : Color(hex: 0x8A8279), prominent: on))
                    .fontWeight(on ? .semibold : .regular)
                    .disabled(kept)
                    .accessibilityLabel(k.title + (kept ? "，已经记下" : ""))
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private func save() {
        typing = false
        var f = first
        f.title = f.title.trimmingCharacters(in: .whitespacesAndNewlines)
        f.at = ms(Day.cal.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day)
        guard j.saveFirst(f) else { failed = true; return }
        cheers += 1
        Task { @MainActor in try? await Task.sleep(for: .milliseconds(650)); dismiss() }
    }
}

/// 第一次: one line from birth to today with every first on it, newest at the top — never broken into days, so the
/// earliest is always there to scroll down to. Tap one to change it.
struct FirstsView: View {
    @Environment(JournalStore.self) private var j
    @Environment(AppModel.self) private var app
    @Environment(\.lamp) private var lamp
    @State private var editing: First?
    @State private var adding = false
    /// The first just kept: its bead on the thread blooms like a drop of colour on wet paper, once.
    @State private var fresh: First.ID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summary
                if j.firsts.isEmpty {
                    Text("还没有记下第一次。吃手、昂咕、翻身、坐、爬……孩子第一次做到的时候，点上面的按钮记下来。")
                        .font(.subheadline).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
                VStack(spacing: 0) {
                    ForEach(j.firsts) { f in
                        Button { editing = f } label: { FirstRow(first: f, birth: app.birth, last: false, fresh: fresh == f.id) }
                            .buttonStyle(.toy)
                    }
                    if let b = app.birth { BirthRow(birth: b) }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 40)
        }
        .pageBackground(tone: Palette.bead)
        .navigationTitle("第一次")
        .onChange(of: j.firsts.map(\.id)) { old, new in
            guard let n = new.first(where: { !old.contains($0) }) else { return }
            fresh = n
            Task { @MainActor in try? await Task.sleep(for: .milliseconds(2200)); if fresh == n { fresh = nil } }
        }

        .sheet(item: $editing) { f in FirstSheet(first: f, isNew: false).lampPresented() }
        .sheet(isPresented: $adding) { FirstSheet(first: First(at: ms(Date()), title: ""), isNew: true).lampPresented() }
    }

    private var summary: some View {
        HStack(alignment: .center, spacing: 14) {
            Duo(primary: app.companion, size: 56, look: CGPoint(x: 0.6, y: 0.4), poke: true, night: lamp)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(j.firsts.count)").font(Typeface.numerals(34, relativeTo: .largeTitle, weight: .bold)).foregroundStyle(Palette.accent)
                    Text("个第一次").font(.headline)
                }
                Text(j.firsts.first.map { "最近：" + $0.title + " · " + whenLabelDay($0.date) } ?? "从出生那天起的一条线")
                    .font(.footnote).foregroundStyle(Palette.secondaryText).lineLimit(2)
            }
            Spacer(minLength: 0)
            Button { adding = true } label: { Image(systemName: "plus").font(.headline).frame(width: 44, height: 40) }
                .buttonStyle(.vinyl(Palette.bead, prominent: true))
                .accessibilityLabel("记一个第一次")
        }
        .padding(14)
        .printCard(radius: Radius.card, fill: lamp ? Palette.lampCard : Palette.card)
        .padding(.top, 4)
    }
}

/// One first on the line: a gold bead on the thread, and beside it the age, what it was, the day and the words kept.
private struct FirstRow: View {
    let first: First
    let birth: Day?
    let last: Bool
    var fresh = false
    @Environment(\.lamp) private var lamp
    var body: some View {
        let c = Firsts.color(first)
        HStack(alignment: .top, spacing: 12) {
            Thread(top: true, bottom: true) {
                IconTile(symbol: Firsts.symbol(first), color: c, size: 30, round: true)
                    .background { if fresh { InkBloom(color: c) } }
            }
            .frame(width: 40)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if let birth {
                        Text(Firsts.age(from: birth, to: Day(first.date))).font(.caption.weight(.bold)).monospacedDigit()
                            .foregroundStyle(Color(hex: 0x4A3300))
                            .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Palette.bead.opacity(0.85)))
                    }
                    Text(whenLabelDay(first.date)).font(.caption).foregroundStyle(Palette.secondaryText).monospacedDigit()
                }
                Text(first.title).font(.headline).foregroundStyle(.primary).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                if let n = first.note, !n.isEmpty {
                    Text(n).font(.subheadline).foregroundStyle(Palette.secondaryText).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .printCard(radius: Radius.card, fill: lamp ? Palette.lampCard : Palette.card)
            .padding(.bottom, 12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("改这个第一次")
    }
}

/// A drop of colour spreading on wet paper and fading as it goes: the soft edge wanders, the pigment gathers at the
/// rim. Once, when it appears; nothing under Reduce Motion.
struct InkBloom: View {
    let color: Color
    var size: CGFloat = 120
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var spread = false
    var body: some View {
        Canvas { ctx, sz in
            let c = CGPoint(x: sz.width / 2, y: sz.height / 2)
            let blob = Wash.blob(c, sz.width * 0.4, seed: 1.3, wobble: 0.12)
            ctx.fill(blob, with: .radialGradient(Gradient(colors: [color.opacity(0.18), color.opacity(0.42)]), center: c, startRadius: 0, endRadius: sz.width * 0.42))
            ctx.stroke(blob, with: .color(color.opacity(0.5)), lineWidth: 1.5)
        }
        .frame(width: size, height: size)
        .scaleEffect(spread ? 1 : 0.15)
        .opacity(reduce ? 0 : spread ? 0 : 0.9)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { withAnimation(.easeOut(duration: 1.6)) { spread = true } }
    }
}

/// The start of the line: the day the child was born.
private struct BirthRow: View {
    let birth: Day
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Thread(top: true, bottom: false) {
                Circle().fill(RadialGradient(colors: [Palette.beadLight, Palette.bead], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 14))
                    .frame(width: 18, height: 18).overlay(Circle().strokeBorder(.white, lineWidth: 2))
            }
            .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("出生").font(.headline)
                Text(verbatim: "\(birth.y)年\(birth.md)").font(.caption).foregroundStyle(Palette.secondaryText).monospacedDigit()
            }
            .padding(.top, 4)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The thread the beads are strung on, unbroken from row to row, with the row's bead on it.
private struct Thread<Bead: View>: View {
    let top: Bool, bottom: Bool
    @ViewBuilder let bead: Bead
    var body: some View {
        bead
            .padding(.top, 10)
            .frame(maxHeight: .infinity, alignment: .top)
            .background {
                GeometryReader { g in
                    let x = g.size.width / 2
                    Path { p in
                        p.move(to: CGPoint(x: x, y: top ? 0 : 20)); p.addLine(to: CGPoint(x: x, y: bottom ? g.size.height : 20))
                    }
                    .stroke(LinearGradient(colors: [Palette.bead.opacity(0.7), Palette.bead.opacity(0.35)], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                }
            }
    }
}

/// The firsts of one month, on its page of the growth book.
struct FirstStamps: View {
    let firsts: [First]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("第一次", systemImage: "star.fill").font(.caption.weight(.bold)).foregroundStyle(Color(hex: 0x8A6400))
            WrapLayout(spacing: 6) {
                ForEach(firsts) { f in
                    NavigationLink(value: JournalRoute.firsts) {
                        HStack(spacing: 5) {
                            Image(systemName: Firsts.symbol(f)).font(.caption.weight(.bold)).foregroundStyle(Crayon.ink(Firsts.color(f)))
                            Text(f.title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            Text(Day(f.date).md).font(.caption2).foregroundStyle(Palette.secondaryText).monospacedDigit()
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .vinylSurface(Palette.bead, radius: Radius.tile)
                    }
                    .buttonStyle(.toy)
                }
            }
        }
    }
}
