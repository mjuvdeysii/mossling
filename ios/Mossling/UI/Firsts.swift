import SwiftUI
import PhotosUI

// MARK: 第一次 — the child's firsts
//
// The first time the child sucked a hand, cooed, rolled over, sat, crawled, took a step: moments worth keeping. They
// are not a column of the day (they would be lost among feeds and nappies), and the recorder is not a button that is
// always there (it is needed a few dozen times in three years). It opens from the journal's + menu, JourneyHub, and
// the growth book; what is kept goes onto the growth book's page of that month and onto one line of its own — 第一次 —
// that runs from birth to today and is never cut by dates, so every first can always be found.
// The list of common firsts orders the suggestions only: it is not a timetable, and nothing is compared.

enum Firsts {
    struct Kind: Identifiable {
        let id: String; let zh: String; let en: String; let symbol: String; let color: Color; let around: Int
        var title: String { L10n.t(zh, en) }
    }
    static let all: [Kind] = [
        Kind(id: "smile", zh: "第一次笑", en: "First smile", symbol: "face.smiling.inverse", color: Crayon.sunflower, around: 1),
        Kind(id: "hand", zh: "吃手", en: "Found their hands", symbol: "hand.raised.fill", color: Crayon.peach, around: 2),
        Kind(id: "coo", zh: "昂咕（发出咕咕声）", en: "First coos", symbol: "bubble.left.fill", color: Crayon.sky, around: 2),
        Kind(id: "headup", zh: "趴着抬起头", en: "Held head up", symbol: "arrow.up.circle.fill", color: Crayon.leaf, around: 2),
        Kind(id: "laugh", zh: "笑出声", en: "Laughed out loud", symbol: "face.smiling.inverse", color: Crayon.tangerine, around: 4),
        Kind(id: "roll", zh: "翻身", en: "Rolled over", symbol: "arrow.trianglehead.2.clockwise.rotate.90", color: Crayon.lilac, around: 4),
        Kind(id: "grasp", zh: "抓住玩具", en: "Grabbed a toy", symbol: "hand.raised.fingers.spread.fill", color: Crayon.aqua, around: 4),
        Kind(id: "feet", zh: "抓到自己的脚", en: "Found their feet", symbol: "figure.child", color: Crayon.pink, around: 5),
        Kind(id: "sit", zh: "坐", en: "Sat up", symbol: "chair.fill", color: Crayon.caramel, around: 6),
        Kind(id: "tooth", zh: "长出第一颗牙", en: "First tooth", symbol: "mouth.fill", color: Crayon.pink, around: 6),
        Kind(id: "solid", zh: "第一口辅食", en: "First solid food", symbol: "fork.knife", color: Crayon.leaf, around: 6),
        Kind(id: "babble", zh: "咿咿呀呀连着发音", en: "Started babbling", symbol: "waveform", color: Crayon.sky, around: 7),
        Kind(id: "crawl", zh: "爬", en: "Crawled", symbol: "figure.walk", color: Crayon.tangerine, around: 8),
        Kind(id: "pull", zh: "扶着站起来", en: "Pulled up to stand", symbol: "figure.stand", color: Crayon.aqua, around: 9),
        Kind(id: "clap", zh: "拍手", en: "Clapped hands", symbol: "hands.clap.fill", color: Crayon.sunflower, around: 9),
        Kind(id: "wave", zh: "挥手再见", en: "Waved goodbye", symbol: "hand.wave.fill", color: Crayon.peach, around: 9),
        Kind(id: "mama", zh: "叫爸爸 / 妈妈", en: "Said Mama / Dada", symbol: "heart.text.square.fill", color: Crayon.pink, around: 10),
        Kind(id: "stand", zh: "自己站稳", en: "Stood on their own", symbol: "figure.stand", color: Crayon.lilac, around: 11),
        Kind(id: "step", zh: "迈出第一步", en: "First step", symbol: "shoeprints.fill", color: Crayon.leaf, around: 12),
        Kind(id: "cup", zh: "用杯子喝水", en: "Drank from a cup", symbol: "cup.and.saucer.fill", color: Crayon.sky, around: 12),
        Kind(id: "haircut", zh: "第一次理发", en: "First haircut", symbol: "scissors", color: Crayon.caramel, around: 12),
        Kind(id: "spoon", zh: "自己用勺吃饭", en: "Ate with a spoon", symbol: "fork.knife", color: Crayon.tangerine, around: 15),
        Kind(id: "run", zh: "跑起来", en: "Started running", symbol: "figure.run", color: Crayon.aqua, around: 18),
        Kind(id: "kick", zh: "踢球", en: "Kicked a ball", symbol: "soccerball", color: Crayon.leaf, around: 20),
        Kind(id: "jump", zh: "双脚跳", en: "Jumped with both feet", symbol: "figure.jumprope", color: Crayon.lilac, around: 24),
        Kind(id: "sentence", zh: "说出一句话", en: "First sentence", symbol: "quote.bubble.fill", color: Crayon.sky, around: 24),
        Kind(id: "draw", zh: "画出一个圈", en: "Drew a circle", symbol: "scribble.variable", color: Crayon.pink, around: 30),
        Kind(id: "potty", zh: "自己上厕所", en: "Used the potty", symbol: "toilet.fill", color: Crayon.aqua, around: 30),
    ]
    static func kind(_ key: String?) -> Kind? { key.flatMap { k in all.first { $0.id == k } } }
    /// Shows the built-in title in the current language when `key` matches a common first; custom titles stay as written.
    static func displayTitle(_ f: First) -> String { kind(f.key)?.title ?? f.title }
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
        if day < birth { return L10n.t("出生前", "Before birth") }
        if a.months == 0 { return L10n.t("出生第 \(a.lived) 天", "Day \(a.lived)") }
        return a.days == 0
            ? L10n.t("满 \(a.months) 个月", a.months == 1 ? "1 month" : "\(a.months) months")
            : L10n.t("\(a.months) 个月 \(a.days) 天", "\(a.months) mo \(a.days) d")
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

/// Pure helpers for Firsts summary metrics & stage-matched suggestions (unit-testable).
enum FirstsStudioMetrics {
    static func suggestedCharms(for firsts: [First], babyMonth: Int?, limit: Int = 6) -> [Firsts.Kind] {
        Array(
            Firsts.ordered(around: babyMonth).filter { k in
                !firsts.contains { f in
                    f.key == k.id || f.title.contains(k.zh) || f.title.localizedCaseInsensitiveContains(k.en)
                }
            }
            .prefix(max(0, limit))
        )
    }

    static func photoEntries(in firsts: [First], loader: (UUID) -> UIImage? = { FirstPhotoStore.load(for: $0) }) -> [(first: First, image: UIImage)] {
        firsts.compactMap { f in
            loader(f.id).map { (f, $0) }
        }
    }
}

/// "今天" / "昨天" / "10月20日" / "2025年10月20日" — a day, said as people say it.
func whenLabelDay(_ d: Date) -> String {
    let day = Day(d), today = Day.today
    if day == today { return L10n.t("今天", "Today") }
    if day == today.plus(days: -1) { return L10n.t("昨天", "Yesterday") }
    return day.mdOrYmd
}

/// Records a first, or changes one: what (one of the common firsts, or named), which day, an optional local Polaroid photo, and a line about it.
struct FirstSheet: View {
    @Environment(JournalStore.self) private var j
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lamp) private var lamp
    @Environment(\.colorScheme) private var scheme
    @State var first: First
    let isNew: Bool
    @State private var day = Date()
    @State private var named = false
    /// The mark of a first the parent names.
    @State private var mark = "star.fill"
    @State private var cheers = 0
    @State private var failed = false
    @State private var pickedPhoto: PhotosPickerItem? = nil
    @State private var photoImage: UIImage? = nil
    @State private var removeExistingPhoto = false
    @FocusState private var typing: Bool

    init(first: First, isNew: Bool) { _first = State(initialValue: first); self.isNew = isNew }

    var body: some View {
        let dark = lamp || scheme == .dark
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if failed { SaveFailed() }
                    own(dark: dark)
                    if isNew { choices(dark: dark) }
                    photoSection
                    VStack(alignment: .leading, spacing: 0) {
                        let now = Date()
                        DatePicker(L10n.t("哪一天", "Date"), selection: $day, in: min(earliest, now)...now, displayedComponents: .date)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                        if let b = app.birth {
                            Text(Firsts.age(from: b, to: Day(day))).font(.footnote.weight(.semibold)).foregroundStyle(Palette.secondaryText).monospacedDigit()
                                .padding(.horizontal, 16).padding(.bottom, 12)
                        }
                    }
                    .printCard(radius: Radius.card, fill: lamp ? Palette.lampCard : Palette.card)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.t("想留下的话（可选）", "A note to keep (optional)")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                        TextField(L10n.t("当时的样子、在哪里、谁在身边", "Where you were, who was there, how it felt"), text: Binding(get: { first.note ?? "" }, set: { first.note = String($0.prefix(200)) }), axis: .vertical)
                            .lineLimit(2...6).padding(14).printCard(radius: Radius.inner, fill: lamp ? Palette.lampCard : Palette.card)
                    }
                    Button { save() } label: { Text(isNew ? L10n.t("记下这个第一次", "Save This First") : L10n.t("保存", "Save")).frame(maxWidth: .infinity) }
                        .buttonStyle(.vinyl(Crayon.fill(Palette.bead, lamp), prominent: true, large: true))
                        .disabled(first.title.trimmingCharacters(in: .whitespaces).isEmpty)
                    if !isNew {
                        Button(L10n.t("删除这个第一次", "Delete this first"), role: .destructive) {
                            FirstPhotoStore.delete(for: first.id)
                            j.deleteFirst(first)
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    Text(L10n.t("每个孩子的第一次都在自己的时间里到来，这里只记录，不比较。", "Every child reaches their firsts in their own time — this is just a keepsake, never a comparison."))
                        .font(.footnote).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { PageBackground(tone: Palette.bead) }
            .navigationTitle(isNew ? L10n.t("记一个第一次", "Log a First") : L10n.t("这个第一次", "First")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.t("取消", "Cancel"), systemImage: "xmark") { dismiss() } } }
        }
        .presentationDetents([.large])
        .sensoryFeedback(.success, trigger: cheers)
        .onAppear {
            day = isNew ? Date() : first.date; named = !isNew && Firsts.kind(first.key) == nil
            if let i = Firsts.customIcon(first.key) { mark = i }
            if !isNew && photoImage == nil && !removeExistingPhoto {
                photoImage = FirstPhotoStore.load(for: first.id)
            }
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        withAnimation(.snappy) {
                            photoImage = img
                            removeExistingPhoto = false
                        }
                        TactileEngine.shared.beadClick()
                    }
                }
            }
        }
    }

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.t("留一张照片（可选 · 仅存本机）", "Attach a photo (optional · on-device only)"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.secondaryText)
                Spacer()
                if photoImage != nil {
                    Button(L10n.t("移除", "Remove"), role: .destructive) {
                        withAnimation(.snappy) {
                            photoImage = nil
                            pickedPhoto = nil
                            removeExistingPhoto = true
                        }
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            if let img = photoImage {
                HStack(spacing: 14) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 92, height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
                        .shadow(color: Color(hex: 0x6B4A2B).opacity(0.18), radius: 5, y: 3)
                        .rotationEffect(.degrees(-2))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t("会收进成长绘本与纪念相纸墙", "Pinned into your Storybook & Polaroid line"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        PhotosPicker(selection: $pickedPhoto, matching: .images) {
                            Label(L10n.t("换一张照片", "Change Photo"), systemImage: "photo")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.vinyl(Palette.bead))
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .printCard(radius: Radius.card, fill: lamp ? Palette.lampCard : Palette.card)
            } else {
                PhotosPicker(selection: $pickedPhoto, matching: .images) {
                    HStack(spacing: 10) {
                        FirstCharmBadge(key: "icon:camera.fill", color: Crayon.caramel, size: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.t("选一张纪念照片", "Choose a keepsake photo"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(L10n.t("不用授予相册权限，只存放在这台手机里", "No library permission needed · stored locally"))
                                .font(.caption2)
                                .foregroundStyle(Palette.secondaryText)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Palette.accent)
                    }
                    .padding(12)
                    .printCard(radius: Radius.card, fill: lamp ? Palette.lampCard : Palette.card)
                }
                .buttonStyle(.toy)
            }
        }
    }

    /// Any first at all, in the parent's own words, with a hand-crafted charm mark of their choosing — written here, or picked below.
    private func own(dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isNew ? L10n.t("自己写一个第一次", "Write your own") : L10n.t("第一次做了什么", "What happened?")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondaryText)
            HStack(spacing: 10) {
                FirstCharmBadge(key: first.key ?? ("icon:" + mark), color: Firsts.color(first), size: 36, active: !first.title.isEmpty)
                TextField(L10n.t("例如：第一次看海、第一次坐飞机", "e.g. First beach trip, first plane ride"), text: Binding(get: { first.title }, set: { v in
                    first.title = String(v.prefix(40))
                    // typing makes it the parent's own first (unless it is still exactly a common one's name)
                    if let k = Firsts.kind(first.key) {
                        if k.title != first.title { first.key = "icon:" + mark; named = true }
                    } else { first.key = "icon:" + mark; named = true }
                }))
                    .font(.title3.weight(.semibold)).focused($typing).submitLabel(.done)
            }
            .padding(12)
            .printCard(radius: Radius.inner, fill: lamp ? Palette.lampCard : Palette.card)

            if Firsts.kind(first.key) == nil {
                WrapLayout(spacing: 8) {
                    ForEach(Firsts.customIcons, id: \.0) { sym, c in
                        let on = mark == sym
                        Button {
                            TactileEngine.shared.beadClick()
                            withAnimation(.snappy) { mark = sym; first.key = "icon:" + sym }
                        } label: {
                            FirstCharmBadge(key: "icon:" + sym, color: c, size: 40, active: on)
                                .overlay(Circle().strokeBorder(on ? (dark ? Palette.amber : Crayon.ink(c)) : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.toy)
                        .accessibilityLabel(L10n.t("纪念印章", "Keepsake charm")).accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var earliest: Date { app.birth.map { $0.date } ?? Date.distantPast }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Duo(primary: app.companion, size: 64, mood: cheers > 0 ? .happy : .open, look: CGPoint(x: 0.5, y: 0.3), poke: true, cheer: cheers, night: lamp)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("第一次", "Firsts")).font(.largeTitle.weight(.bold))
                Text(L10n.t("把值得记住的瞬间留在成长册里", "Keep the moments worth remembering in the Growth Book")).font(.subheadline).foregroundStyle(Palette.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }

    /// The common firsts, around the child's age first; those already kept are marked and cannot be kept twice.
    private func choices(dark: Bool) -> some View {
        let done = Set(j.firsts.compactMap(\.key))
        return VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("或者选一个常见的", "Or pick a common one")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondaryText)
            WrapLayout(spacing: 8) {
                ForEach(Firsts.ordered(around: app.babyMonth)) { k in
                    let on = first.key == k.id
                    let kept = done.contains(k.id)
                    Button {
                        TactileEngine.shared.beadClick()
                        withAnimation(.snappy) { first.key = k.id; first.title = k.title; named = false; typing = false }
                    } label: {
                        HStack(spacing: 7) {
                            if kept {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Palette.secondaryText)
                            } else {
                                FirstCharmBadge(key: k.id, color: k.color, size: 24, active: on)
                            }
                            Text(k.title)
                                .font(.subheadline.weight(on ? .bold : .semibold))
                                .foregroundStyle(on ? .white : (kept ? Palette.secondaryText : .primary))
                        }
                        .padding(.leading, 7)
                        .padding(.trailing, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(
                                on ? k.color : (kept ? Palette.fill.opacity(0.6) : (dark ? Palette.lampCard : Palette.card))
                            )
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                on ? Crayon.ink(k.color) : Palette.outline.opacity(kept ? 0.14 : 0.28),
                                lineWidth: on ? 1.2 : 0.75
                            )
                        )
                        .opacity(kept ? 0.62 : 1)
                    }
                    .buttonStyle(.toy)
                    .disabled(kept)
                    .accessibilityLabel(k.title + (kept ? L10n.t("，已经记下", ", already logged") : ""))
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private func save() {
        typing = false
        guard app.mayKeep() else { return }
        var f = first
        f.title = f.title.trimmingCharacters(in: .whitespacesAndNewlines)
        f.at = ms(Day.cal.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day)
        guard j.saveFirst(f) else { failed = true; return }
        if removeExistingPhoto {
            FirstPhotoStore.delete(for: f.id)
        } else if let img = photoImage {
            FirstPhotoStore.save(img, for: f.id)
        }
        TactileEngine.shared.goldChime()
        cheers += 1
        Task { @MainActor in try? await Task.sleep(for: .milliseconds(650)); dismiss() }
    }
}

/// 第一次: Montessori Keepsake Studio — a living companion stage, a Polaroid twine gallery when photos exist,
/// hand-crafted picture-book charms strung along one continuous golden thread from birth to today,
/// and 3× cotton-paper print export.
struct FirstsView: View {
    @Environment(JournalStore.self) private var j
    @Environment(AppModel.self) private var app
    @Environment(\.lamp) private var lamp
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var editing: First?
    @State private var draftNew: First?
    @State private var viewingPhoto: First?
    @State private var photoVersion = FirstPhotoVersion.shared
    @State private var celebCheers = 0
    /// The first just kept: its bead on the thread blooms like a drop of colour on wet paper, once.
    @State private var fresh: First.ID?

    var body: some View {
        let _ = photoVersion.tick
        let dark = lamp || scheme == .dark
        let charms = FirstsStudioMetrics.suggestedCharms(for: j.firsts, babyMonth: app.babyMonth, limit: 6)
        let photoEntries = FirstsStudioMetrics.photoEntries(in: j.firsts)
        let who = app.nickname.isEmpty ? L10n.t("宝宝", "Baby") : app.nickname
        let ageStr = app.age.map { L10n.ageText($0) } ?? ""
        let photoMap = Dictionary(uniqueKeysWithValues: photoEntries.map { ($0.first.id, $0.image) })
        let posterItem = RenderedPoster {
            let poster = FirstsPrintPoster(
                babyName: who,
                ageText: ageStr,
                birth: app.birth,
                firsts: j.firsts,
                photos: photoMap
            )
            let renderer = ImageRenderer(content: poster)
            renderer.scale = 3.0
            return renderer.uiImage
        }

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                summary(photoCount: photoEntries.count, dark: dark)

                if !photoEntries.isEmpty {
                    polaroidGarland(entries: photoEntries, dark: dark)
                }

                if j.firsts.isEmpty {
                    emptyStageCard(charms: charms, dark: dark)
                }

                VStack(spacing: 0) {
                    ForEach(j.firsts) { f in
                        FirstRow(
                            first: f,
                            birth: app.birth,
                            fresh: fresh == f.id,
                            onEdit: { editing = f },
                            onViewPhoto: { viewingPhoto = f },
                            onDelete: {
                                TactileEngine.shared.beadClick()
                                FirstPhotoStore.delete(for: f.id)
                                j.deleteFirst(f)
                            }
                        )
                    }
                    if let b = app.birth { BirthRow(birth: b) }
                }

                if !j.firsts.isEmpty && !charms.isEmpty {
                    stageCharmsTray(charms: charms, dark: dark)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Palette.bead)
        .navigationTitle(L10n.t("第一次", "Firsts"))
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if !j.firsts.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: posterItem,
                        preview: SharePreview(L10n.t("\(who) · 第一次纪念手账", "\(who) · Firsts Keepsake"))
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(L10n.t("分享第一次纪念长卷", "Share Firsts keepsake print"))
                }
            }
        }
        .onChange(of: j.firsts.map(\.id)) { old, new in
            guard let n = new.first(where: { !old.contains($0) }) else { return }
            fresh = n
            celebCheers += 1
            Task { @MainActor in try? await Task.sleep(for: .milliseconds(2200)); if fresh == n { fresh = nil } }
        }
        .sheet(item: $editing) { f in FirstSheet(first: f, isNew: false).lampPresented() }
        .sheet(item: $draftNew) { f in FirstSheet(first: f, isNew: true).lampPresented() }
        .fullScreenCover(item: $viewingPhoto) { f in
            FirstPhotoLightbox(
                first: f,
                birth: app.birth,
                onEdit: {
                    viewingPhoto = nil
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(220))
                        editing = f
                    }
                }
            )
            .lampPresented(sheet: false)
        }
    }

    private func summary(photoCount: Int, dark: Bool) -> some View {
        let duo = Duo(
            primary: app.companion,
            size: 60,
            mood: celebCheers > 0 ? .happy : .open,
            look: CGPoint(x: 0.65, y: 0.35),
            poke: true,
            cheer: celebCheers,
            night: lamp
        )
        let addBtn = Button {
            TactileEngine.shared.beadClick()
            draftNew = First(at: ms(Date()), title: "")
        } label: {
            Image(systemName: "plus")
                .font(.headline)
                .frame(width: 44, height: 40)
        }
        .buttonStyle(.vinyl(Palette.bead, prominent: true))
        .accessibilityLabel(L10n.t("记一个第一次", "Log a first"))

        let statsBlock = VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(j.firsts.count)")
                    .font(Typeface.numerals(34, relativeTo: .largeTitle, weight: .bold))
                    .foregroundStyle(Palette.accent)
                    .fixedSize(horizontal: true, vertical: false)
                Text(L10n.t("个第一次", j.firsts.count == 1 ? "first" : "firsts"))
                    .font(.headline)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            if photoCount > 0 {
                Label(
                    L10n.t("\(photoCount) 张相纸", "\(photoCount) \(photoCount == 1 ? "photo" : "photos")"),
                    systemImage: "photo.fill"
                )
                .font(.caption2.weight(.bold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(dark ? Palette.amber : Crayon.ink(Palette.bead))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Palette.bead.opacity(dark ? 0.22 : 0.18)))
            }
            if let latest = j.firsts.first {
                let prefix = L10n.t("最近：", "Latest: ")
                let title = Firsts.displayTitle(latest)
                let dayText = whenLabelDay(latest.date)
                ViewThatFits(in: .horizontal) {
                    Text(prefix + title + " · " + dayText)
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(prefix + title)
                            .font(.footnote)
                            .foregroundStyle(Palette.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text(dayText)
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryText.opacity(0.85))
                            .monospacedDigit()
                    }
                }
            } else {
                Text(L10n.t("从出生那天起的一条金色丝线", "One quiet golden thread from the day they arrived"))
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        return Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center) {
                        duo
                        Spacer(minLength: 8)
                        addBtn
                    }
                    statsBlock
                }
            } else {
                HStack(alignment: .center, spacing: 14) {
                    duo
                    statsBlock
                    Spacer(minLength: 0)
                    addBtn
                }
            }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Palette.bead.opacity(dark ? 0.14 : 0.12), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .printCard(radius: Radius.card, fill: dark ? Palette.lampCard : Palette.card)
        .padding(.top, 4)
    }

    private func polaroidGarland(entries: [(first: First, image: UIImage)], dark: Bool) -> some View {
        let shown = Array(entries.prefix(6))
        let colCount = min(max(1, shown.count), typeSize.isAccessibilitySize ? 2 : 3)
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: colCount)

        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(
                title: L10n.t("拍立得相纸墙", "Polaroid Keepsake Line"),
                detail: L10n.t("轻点相纸可放大细看", "Tap any photo to admire")
            )

            ZStack(alignment: .top) {
                // Gentle draped golden twine behind the top row of taped Polaroids
                Canvas(rendersAsynchronously: false) { ctx, size in
                    var line = Path()
                    line.move(to: CGPoint(x: 8, y: 12))
                    line.addQuadCurve(
                        to: CGPoint(x: size.width - 8, y: 12),
                        control: CGPoint(x: size.width * 0.5, y: 24)
                    )
                    ctx.stroke(
                        line,
                        with: .color(Palette.bead.opacity(dark ? 0.45 : 0.55)),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 3])
                    )
                }
                .frame(height: 28)
                .allowsHitTesting(false)

                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(Array(shown.enumerated()), id: \.element.first.id) { idx, item in
                        let tilt: Double = reduce ? 0 : (idx % 2 == 0 ? -2.2 : 2.0)
                        let ageTag = app.birth.map { Firsts.age(from: $0, to: Day(item.first.date)) } ?? Day(item.first.date).md
                        Button {
                            TactileEngine.shared.pageTurn()
                            viewingPhoto = item.first
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Image(uiImage: item.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                                Text(Firsts.displayTitle(item.first))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color(hex: 0x241F1B))
                                    .lineLimit(1)
                                Text(ageTag)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(hex: 0x6B5A45))
                                    .lineLimit(1)
                            }
                            .padding(6)
                            .padding(.bottom, 2)
                            .frame(maxWidth: colCount == 1 ? 180 : .infinity)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(dark ? Color(hex: 0xF5EFE4) : .white))
                            .shadow(color: Color(hex: 0x6B4A2B).opacity(dark ? 0.34 : 0.16), radius: 5, y: 3)
                            .overlay(alignment: .top) {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Firsts.color(item.first).opacity(0.68))
                                    .frame(width: 28, height: 8)
                                    .offset(y: -4)
                            }
                            .rotationEffect(.degrees(tilt))
                        }
                        .buttonStyle(.toy)
                        .accessibilityLabel(Firsts.displayTitle(item.first) + "，" + ageTag)
                        .accessibilityHint(L10n.t("打开相纸大图", "Open full-size Polaroid"))
                    }
                }
                .padding(.top, 8)
            }
            .padding(12)
            .printCard(radius: Radius.card, fill: dark ? Palette.lampCard : Palette.card)
        }
    }

    private func emptyStageCard(charms: [Firsts.Kind], dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                FirstCharmBadge(key: "smile", color: Crayon.sunflower, size: 36, active: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("第一颗纪念珠正等着被串起", "Ready for your very first keepsake bead"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(L10n.t("选下面此刻容易遇见的瞬间，或点右上角 + 写自己的话。", "Pick a stage moment below or tap + to write your own."))
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !charms.isEmpty {
                stageCharmsGrid(charms: charms, dark: dark)
            }

            Text(L10n.t("每个孩子都在自己的节奏里长大；这些只是温柔的灵感，不是进度表。", "Every child unfolds in their own time — gentle prompts only, never a checklist."))
                .font(.caption2)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .printCard(radius: Radius.card, fill: dark ? Palette.lampCard : Palette.card)
    }

    private func stageCharmsTray(charms: [Firsts.Kind], dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(
                title: L10n.t("这段时间常遇见的第一次", "Moments Around This Stage"),
                detail: L10n.t("轻点直接记下", "Tap to keep")
            )
            VStack(alignment: .leading, spacing: 12) {
                stageCharmsGrid(charms: charms, dark: dark)
                Text(L10n.t("只是温柔的灵感提示，从不是进度表；随时也可以点右上角 + 自定义。", "Gentle inspiration only — never a checklist. Tap + anytime to write your own."))
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .printCard(radius: Radius.card, fill: dark ? Palette.lampCard : Palette.card)
        }
    }

    private func stageCharmsGrid(charms: [Firsts.Kind], dark: Bool) -> some View {
        WrapLayout(spacing: 8) {
            ForEach(charms) { k in
                Button {
                    TactileEngine.shared.beadClick()
                    draftNew = First(at: ms(Date()), key: k.id, title: k.title)
                } label: {
                    HStack(spacing: 7) {
                        FirstCharmBadge(key: k.id, color: k.color, size: 24)
                        Text(k.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 11)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(k.color.opacity(dark ? 0.20 : 0.11)))
                    .overlay(Capsule().strokeBorder(k.color.opacity(dark ? 0.38 : 0.25), lineWidth: 0.85))
                }
                .buttonStyle(.toy)
            }
        }
    }
}

/// One first on the line: a crafted keepsake charm on the golden thread, and beside it the age, what it was,
/// the day, an optional tappable Polaroid keepsake photo, and the words kept.
private struct FirstRow: View {
    let first: First
    let birth: Day?
    var fresh = false
    let onEdit: () -> Void
    let onViewPhoto: () -> Void
    let onDelete: () -> Void

    @Environment(\.lamp) private var lamp
    @Environment(\.colorScheme) private var scheme
    @State private var photoVersion = FirstPhotoVersion.shared

    var body: some View {
        let _ = photoVersion.tick
        let dark = lamp || scheme == .dark
        let c = Firsts.color(first)
        let photo = FirstPhotoStore.load(for: first.id)

        HStack(alignment: .top, spacing: 12) {
            Thread(top: true, bottom: true) {
                FirstCharmBadge(key: first.key, color: c, size: 34)
                    .background { if fresh { InkBloom(color: c) } }
            }
            .frame(width: 40)

            HStack(alignment: .top, spacing: 10) {
                Button(action: onEdit) {
                    VStack(alignment: .leading, spacing: 6) {
                        WrapLayout(spacing: 6) {
                            if let birth {
                                Text(Firsts.age(from: birth, to: Day(first.date)))
                                    .font(.caption.weight(.bold))
                                    .monospacedDigit()
                                    .fixedSize(horizontal: true, vertical: false)
                                    .foregroundStyle(Color(hex: 0x4A3300))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Palette.bead.opacity(0.88)))
                            }
                            Text(whenLabelDay(first.date))
                                .font(.caption)
                                .foregroundStyle(Palette.secondaryText)
                                .monospacedDigit()
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        Text(Firsts.displayTitle(first))
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if let n = first.note, !n.isEmpty {
                            Text(n)
                                .font(.subheadline)
                                .foregroundStyle(Palette.secondaryText)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if let photo {
                    Button {
                        TactileEngine.shared.pageTurn()
                        onViewPhoto()
                    } label: {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .padding(3.5)
                            .background(RoundedRectangle(cornerRadius: 9.5, style: .continuous).fill(dark ? Color(hex: 0xF5EFE4) : .white))
                            .shadow(color: Color(hex: 0x6B4A2B).opacity(dark ? 0.34 : 0.18), radius: 3, y: 2)
                            .rotationEffect(.degrees(2.5))
                    }
                    .buttonStyle(.toy)
                    .accessibilityLabel(L10n.t("查看拍立得照片", "View Polaroid photo"))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .printCard(radius: Radius.card, fill: dark ? Palette.lampCard : Palette.card)
            .padding(.bottom, 12)
            .contextMenu {
                if photo != nil {
                    Button(L10n.t("查看纪念照片", "View Polaroid"), systemImage: "photo") { onViewPhoto() }
                }
                Button(L10n.t("编辑", "Edit"), systemImage: "pencil") { onEdit() }
                Button(L10n.t("删除", "Delete"), systemImage: "trash", role: .destructive) { onDelete() }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Full-screen Polaroid keepsake viewer so parents can admire saved milestone photos up close without opening edit mode.
private struct FirstPhotoLightbox: View {
    let first: First
    let birth: Day?
    let onEdit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.lamp) private var lamp
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = lamp || scheme == .dark
        let photo = FirstPhotoStore.load(for: first.id)
        let color = Firsts.color(first)

        ZStack {
            PageBackground(tone: color)

            VStack(spacing: 16) {
                HStack {
                    Button {
                        TactileEngine.shared.beadClick()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(dark ? Palette.lampCard : Palette.card))
                    }
                    .buttonStyle(.toy)
                    .accessibilityLabel(L10n.t("关闭", "Close"))

                    Spacer()

                    Button(action: onEdit) {
                        Label(L10n.t("编辑", "Edit"), systemImage: "pencil")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Palette.accentFill))
                    }
                    .buttonStyle(.toy)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 14) {
                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 380)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    HStack(alignment: .center, spacing: 10) {
                        FirstCharmBadge(key: first.key, color: color, size: 36, active: true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Firsts.displayTitle(first))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color(hex: 0x241F1B))
                            HStack(spacing: 6) {
                                if let birth {
                                    Text(Firsts.age(from: birth, to: Day(first.date)))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color(hex: 0x4A3300))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Palette.bead.opacity(0.28)))
                                }
                                Text(Day(first.date).ymd)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Color(hex: 0x5E5F66))
                                    .monospacedDigit()
                            }
                        }
                        Spacer(minLength: 0)
                    }

                    if let note = first.note, !note.isEmpty {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: 0x453E36))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(dark ? Color(hex: 0xF5EFE4) : .white))
                .shadow(color: .black.opacity(dark ? 0.36 : 0.16), radius: 14, y: 8)
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.65))
                        .frame(width: 58, height: 14)
                        .offset(y: -7)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
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
                Text(L10n.t("出生", "Born")).font(.headline)
                Text(verbatim: birth.ymd).font(.caption).foregroundStyle(Palette.secondaryText).monospacedDigit()
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
    @State private var photoVersion = FirstPhotoVersion.shared
    var body: some View {
        let _ = photoVersion.tick
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.t("第一次", "Firsts"), systemImage: "star.fill").font(.caption.weight(.bold)).foregroundStyle(Color(hex: 0x8A6400))
            WrapLayout(spacing: 6) {
                ForEach(firsts) { f in
                    NavigationLink(value: JournalRoute.firsts) {
                        HStack(spacing: 6) {
                            FirstCharmBadge(key: f.key, color: Firsts.color(f), size: 20)
                            Text(Firsts.displayTitle(f)).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                            if FirstPhotoStore.exists(for: f.id) {
                                Image(systemName: "photo.fill").font(.caption2).foregroundStyle(Palette.accent)
                            }
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
