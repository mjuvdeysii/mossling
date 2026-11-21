import SwiftUI

/// 「成长绘本」 — Full-screen horizontal-paging keepsake picture book built automatically from the child's lived months,
/// Firsts (with optional local Polaroid photos), Montessori play trays, measurements, and quiet notes.
struct StorybookView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.accessibilityReduceMotion) private var reduce

    @State private var pageIndex: Int
    @State private var photoVersion = FirstPhotoVersion.shared
    @Namespace private var trailNS

    /// `initialPage`: `0` = cover, `1...N` = chronological month spreads (birth -> current), `N + 1` = epilogue.
    init(initialPage: Int = 0) {
        _pageIndex = State(initialValue: max(0, initialPage))
    }

    /// Chronological order (Birth -> Today) so parents read their child's story forward like a real picture book.
    private var chronologicalPages: [BookPage] {
        Array(BookPage.all(app, j).reversed())
    }

    var body: some View {
        let pages = chronologicalPages
        let totalCount = pages.count + 2 // cover + months + epilogue
        let clampedIndex = max(0, min(pageIndex, totalCount - 1))
        let dark = lamp || scheme == .dark
        let _ = photoVersion.tick

        ZStack {
            PageBackground(tone: Crayon.caramel)

            VStack(spacing: 0) {
                topBar(pages: pages, index: clampedIndex, total: totalCount, dark: dark)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                TabView(selection: $pageIndex) {
                    StorybookCoverSpread(pages: pages)
                        .tag(0)

                    ForEach(Array(pages.enumerated()), id: \.element.month) { offset, page in
                        StorybookMonthSpread(page: page, spreadNumber: offset + 1, totalMonths: pages.count)
                            .tag(offset + 1)
                    }

                    StorybookEpilogueSpread(totalMonths: pages.count)
                        .tag(pages.count + 1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: pageIndex) { oldVal, newVal in
                    guard oldVal != newVal else { return }
                    TactileEngine.shared.pageTurn()
                }

                beadTrail(pages: pages, current: clampedIndex, total: totalCount, dark: dark)
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 12)
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Top Floating Header & Lazy Spread Print Share

    private func topBar(pages: [BookPage], index: Int, total: Int, dark: Bool) -> some View {
        let label: String = {
            if index == 0 { return L10n.t("封面", "Cover") }
            if index > pages.count { return L10n.t("尾声", "Epilogue") }
            let m = pages[index - 1].month
            return m == 0 ? L10n.t("出生", "Birth") : L10n.t("满 \(m) 个月", "Month \(m)")
        }()

        let who = app.nickname.isEmpty ? L10n.t("宝宝", "Baby") : app.nickname
        let birthYMD = app.birth?.ymd
        let ageLabel = app.age.map { L10n.ageText($0) + " · " + L10n.livedDays($0.lived) }
        let babyMonth = min(app.age?.bookMonth ?? 0, 36)
        let monthCount = pages.count
        let playCount = pages.reduce(0) { $0 + $1.plays.reduce(0) { $0 + $1.times } }
        let firstCount = pages.reduce(0) { $0 + $1.firsts.count }
        let currentPageData: BookPage? = (index >= 1 && index <= pages.count) ? pages[index - 1] : nil
        let pageMonth = currentPageData?.month
        let chapterTitle: String = currentPageData.map { app.content.month($0.month).title } ?? L10n.stretchName(for: app.babyMonth ?? 0)
        let firstLines: [String] = currentPageData?.firsts.prefix(3).map { "★ " + Firsts.displayTitle($0) + " · " + Day($0.date).md } ?? []
        let playNames: [String] = currentPageData?.plays.prefix(3).map(\.play.name) ?? []
        let firstIDs: [UUID] = currentPageData?.firsts.map(\.id) ?? []

        let exportPoster = RenderedPoster {
            let view: AnyView
            if let pageMonth {
                view = AnyView(
                    StorybookMonthPrintCard(
                        babyName: who,
                        month: pageMonth,
                        chapterTitle: chapterTitle,
                        firstLines: firstLines,
                        playNames: playNames,
                        coverImage: ArtIndex.shared.cover(min(pageMonth, 36)).flatMap { ArtCache.shared.image($0, maxPixel: 1024) },
                        firstPhoto: firstIDs.compactMap { FirstPhotoStore.load(for: $0) }.first
                    )
                )
            } else {
                view = AnyView(
                    StorybookCoverPrintCard(
                        babyName: who,
                        birthYMD: birthYMD,
                        ageLabel: ageLabel,
                        monthCount: monthCount,
                        playCount: playCount,
                        firstCount: firstCount,
                        coverImage: ArtIndex.shared.cover(babyMonth).flatMap { ArtCache.shared.image($0, maxPixel: 1024) }
                    )
                )
            }
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3.0
            return renderer.uiImage
        }

        return HStack(spacing: 10) {
            Button {
                TactileEngine.shared.beadClick()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(dark ? Palette.lampCard : Palette.card))
                    .shadow(color: dark ? .black.opacity(0.25) : Color(hex: 0x7A5230).opacity(0.10), radius: 4, y: 2)
            }
            .buttonStyle(.toy)
            .accessibilityLabel(L10n.t("合上绘本", "Close Storybook"))

            Spacer()

            VStack(spacing: 1) {
                Text(label)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text("\(index + 1) / \(total)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.secondaryText)
                    .monospacedDigit()
            }

            Spacer()

            ShareLink(
                item: exportPoster,
                preview: SharePreview(L10n.t("摸索台灯 · 成长绘本页", "Moss & Otto · Storybook Page"))
            ) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(dark ? Palette.lampCard : Palette.card))
                    .shadow(color: dark ? .black.opacity(0.25) : Color(hex: 0x7A5230).opacity(0.10), radius: 4, y: 2)
            }
            .buttonStyle(.toy)
            .accessibilityLabel(L10n.t("留存这一页", "Save this page"))
        }
    }

    // MARK: - Living Montessori Bead Trail

    private func beadTrail(pages: [BookPage], current: Int, total: Int, dark: Bool) -> some View {
        HStack(spacing: 8) {
            Button {
                guard current > 0 else { return }
                withAnimation(reduce ? nil : .spring(response: 0.36, dampingFraction: 0.84)) {
                    pageIndex = current - 1
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(current > 0 ? Palette.accent : Palette.secondaryText.opacity(0.35))
                    .frame(width: 32, height: 32)
            }
            .disabled(current == 0)
            .accessibilityLabel(L10n.t("上一页", "Previous page"))

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(0..<total, id: \.self) { idx in
                            let isCurrent = idx == current
                            let isPast = idx < current
                            Button {
                                withAnimation(reduce ? nil : .spring(response: 0.36, dampingFraction: 0.82)) {
                                    pageIndex = idx
                                }
                            } label: {
                                ZStack {
                                    if isCurrent {
                                        Capsule()
                                            .fill(dark ? Palette.amber : Palette.accent)
                                            .frame(width: 24, height: 10)
                                            .matchedGeometryEffect(id: "storyBead", in: trailNS)
                                    } else if isPast {
                                        Circle()
                                            .fill(Palette.bead)
                                            .frame(width: 8, height: 8)
                                    } else {
                                        Circle()
                                            .fill(Palette.stone.opacity(dark ? 0.45 : 0.7))
                                            .frame(width: 7, height: 7)
                                    }
                                }
                                .frame(minWidth: 16, minHeight: 28)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(idx)
                            .accessibilityLabel(
                                idx == 0 ? L10n.t("封面", "Cover")
                                : idx == total - 1 ? L10n.t("尾声", "Epilogue")
                                : L10n.t("第 \(pages[idx - 1].month) 个月", "Month \(pages[idx - 1].month)")
                            )
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .onChange(of: current) { _, target in
                    withAnimation(reduce ? nil : .easeInOut(duration: 0.25)) {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }

            Button {
                guard current < total - 1 else { return }
                withAnimation(reduce ? nil : .spring(response: 0.36, dampingFraction: 0.84)) {
                    pageIndex = current + 1
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(current < total - 1 ? Palette.accent : Palette.secondaryText.opacity(0.35))
                    .frame(width: 32, height: 32)
            }
            .disabled(current >= total - 1)
            .accessibilityLabel(L10n.t("下一页", "Next page"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .printCard(radius: Radius.card)
    }
}

// MARK: - Cover Spread

private struct StorybookCoverSpread: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    let pages: [BookPage]

    var body: some View {
        let dark = lamp || scheme == .dark
        let who = app.nickname.isEmpty ? L10n.t("宝宝", "Baby") : app.nickname
        let mo = min(app.babyMonth ?? 0, 36)
        let plays = pages.reduce(0) { $0 + $1.plays.reduce(0) { $0 + $1.times } }
        let firsts = pages.reduce(0) { $0 + $1.firsts.count }

        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 18) {
                    // Gold embossed colophon ribbon
                    HStack(spacing: 7) {
                        GoldBead(size: 8)
                        Text(L10n.t("成长绘本 · 0–3 岁", "GROWTH STORYBOOK · 0–3 YRS"))
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(dark ? Palette.amber : Crayon.ink(Palette.amberDeep))
                        GoldBead(size: 8)
                    }
                    .padding(.top, 6)

                    // Taped heirloom cover frame
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let f = ArtIndex.shared.cover(mo) {
                                ArtView(name: f, label: L10n.t("封面插画", "Cover illustration"), radius: 12)
                            } else {
                                ZStack { StagePlate(); GrowingChild(month: mo).padding(16) }
                                    .aspectRatio(4 / 3, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(dark ? Color(hex: 0xECE5D8) : Color.white))
                        .shadow(color: dark ? .black.opacity(0.34) : Color(hex: 0x6B4A2B).opacity(0.18), radius: 10, y: 5)
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Crayon.sunflower.opacity(dark ? 0.5 : 0.62))
                                .frame(width: 56, height: 15)
                                .rotationEffect(.degrees(-2.5))
                                .offset(y: -7)
                        }

                        Duo(primary: app.companion, size: 54, mood: .happy, poke: true, night: dark)
                            .offset(x: 6, y: 12)
                    }
                    .padding(.horizontal, 12)

                    VStack(spacing: 6) {
                        Text(L10n.t("\(who)的成长绘本", "\(who)'s Storybook"))
                            .font(.title.weight(.bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                        if let age = app.age {
                            Text(L10n.ageText(age) + " · " + L10n.livedDays(age.lived))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Palette.accent)
                        }
                        if let b = app.birth {
                            Text(L10n.t("始于 \(b.ymd)", "Beginning \(b.ymd)"))
                                .font(.caption)
                                .foregroundStyle(Palette.secondaryText)
                        }
                    }

                    Divider().padding(.horizontal, 12).opacity(0.45)

                    HStack(spacing: 0) {
                        coverStat("\(pages.count)", L10n.t("个月份", pages.count == 1 ? "month" : "months"))
                        Divider().frame(height: 28)
                        coverStat("\(plays)", L10n.t("次一起玩", plays == 1 ? "play" : "plays"))
                        Divider().frame(height: 28)
                        coverStat("\(firsts)", L10n.t("个第一次", firsts == 1 ? "first" : "firsts"))
                    }

                    HStack(spacing: 6) {
                        Text(L10n.t("向左轻翻，从出生那一页开始", "Swipe left to open from Month 0"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Palette.secondaryText)
                        Image(systemName: "arrow.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Palette.accent)
                    }
                    .padding(.top, 2)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Crayon.caramel.opacity(dark ? 0.14 : 0.16), Crayon.sunflower.opacity(dark ? 0.06 : 0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .printCard(radius: Radius.stage)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func coverStat(_ value: String, _ unit: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Typeface.numerals(22, relativeTo: .title2, weight: .bold))
                .foregroundStyle(Palette.accent)
            Text(unit)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Monthly Editorial Spread

private struct StorybookMonthSpread: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    let page: BookPage
    let spreadNumber: Int
    let totalMonths: Int

    var body: some View {
        let m = page.month
        let mo = app.content.month(m)
        let dark = lamp || scheme == .dark
        let firstPhoto: (First, UIImage)? = page.firsts.compactMap { f in
            FirstPhotoStore.load(for: f.id).map { (f, $0) }
        }.first

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Editorial Chapter Heading
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 6) {
                        GoldBead(size: 8)
                        Text(m == 0 ? L10n.t("出生 · 第 1 章", "BIRTH · CHAPTER 1") : L10n.t("满 \(m) 个月", "MONTH \(m)"))
                            .font(.caption.weight(.bold))
                            .tracking(0.6)
                            .foregroundStyle(dark ? Palette.amber : Crayon.ink(Palette.amberDeep))
                    }
                    Spacer()
                    Text(dateRange)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Palette.secondaryText)
                        .monospacedDigit()
                }

                Text(mo.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                // Framed Polaroid Cover (and optional pinned parent First photo tucked beside it!)
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let f = ArtIndex.shared.cover(min(m, 36)) {
                            ArtView(name: f, label: mo.title, radius: 10)
                        } else {
                            ZStack { StagePlate(); GrowingChild(month: m).padding(14) }
                                .aspectRatio(4 / 3, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(dark ? Color(hex: 0xECE5D8) : Color.white))
                    .shadow(color: dark ? .black.opacity(0.32) : Color(hex: 0x6B4A2B).opacity(0.16), radius: 8, y: 4)
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Crayon.sunflower.opacity(dark ? 0.48 : 0.6))
                            .frame(width: 46, height: 13)
                            .rotationEffect(.degrees(spreadNumber % 2 == 0 ? -2.2 : 2.2))
                            .offset(y: -6)
                    }

                    if let (firstItem, uiImg) = firstPhoto {
                        VStack(spacing: 3) {
                            Image(uiImage: uiImg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 82, height: 82)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            Text(Firsts.displayTitle(firstItem))
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: 0x3A2E24))
                                .lineLimit(1)
                                .frame(maxWidth: 82)
                        }
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white))
                        .shadow(color: .black.opacity(0.22), radius: 7, y: 4)
                        .rotationEffect(.degrees(4.5))
                        .offset(x: 4, y: 12)
                    }
                }
                .padding(.bottom, firstPhoto != nil ? 12 : 2)

                // Month's Firsts
                if !page.firsts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L10n.t("这个月的第一次", "Firsts This Month"), systemImage: "star.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(dark ? Palette.amber : Color(hex: 0x8A6400))

                        ForEach(page.firsts) { f in
                            HStack(alignment: .top, spacing: 10) {
                                IconTile(symbol: Firsts.symbol(f), color: Firsts.color(f), size: 28, round: true)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(Firsts.displayTitle(f))
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.primary)
                                        Text(Day(f.date).md)
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(Palette.secondaryText)
                                            .monospacedDigit()
                                    }
                                    if let note = f.note, !note.isEmpty {
                                        Text(note)
                                            .font(.caption)
                                            .foregroundStyle(Palette.secondaryText)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .vinylSurface(Palette.bead, radius: Radius.tile)
                        }
                    }
                }

                // Montessori Play Trays Shared
                if !page.plays.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L10n.t("一起玩过的托盘", "Play Trays Shared"), systemImage: "puzzlepiece.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.accent)

                        EvenRows(items: Array(page.plays.prefix(4)), id: \.play.code, per: 2) { item in
                            let c = Palette.area(Palette.areaKey(of: item.play))
                            HStack(spacing: 7) {
                                TrayTile(code: item.play.code, color: c, flat: ArtStyle.current == .flat)
                                    .frame(width: 40, height: 30)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.play.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    Text(L10n.t("\(item.times) 次", "\(item.times)×"))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Palette.secondaryText)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(7)
                            .background(c.opacity(dark ? 0.16 : 0.10), in: RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
                        }
                    }
                }

                // Quiet Factual Snapshot Row (weight/length/sleep/feeds)
                let snippets = snapshotLine
                if !snippets.isEmpty {
                    WrapLayout(spacing: 6) {
                        ForEach(snippets, id: \.self) { text in
                            Text(text)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.secondaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(dark ? Color.white.opacity(0.08) : Palette.fill))
                        }
                    }
                }

                // Parent Margin Notes
                if !page.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(page.notes) { n in
                            HStack(alignment: .top, spacing: 10) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Crayon.caramel.opacity(0.7))
                                    .frame(width: 3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(n.detail ?? "")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(Day(n.startDate).md)
                                        .font(.caption2)
                                        .foregroundStyle(Palette.secondaryText)
                                }
                            }
                        }
                    }
                }

                if page.empty {
                    Text(L10n.t("这一页静静留白着，记录下这一段成长安安静静走过的日子。", "A quiet page — holding space for the days that passed softly."))
                        .font(.subheadline)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .printCard(radius: Radius.stage)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var dateRange: String {
        let a = Day(page.from), b = Day(page.to.addingTimeInterval(-1))
        if page.to > Date() { return L10n.t("\(a.ymd) – 至今", "\(a.ymd) – present") }
        return a.y == b.y ? "\(a.md) – \(b.md)" : "\(a.ymd) – \(b.ymd)"
    }

    private var snapshotLine: [String] {
        var out: [String] = []
        if let w = page.measure?.weightG { out.append(L10n.t("体重 ", "Weight ") + String(format: "%.2f kg", Double(w) / 1000)) }
        if let l = page.measure?.lengthMm { out.append(L10n.t("身长 ", "Length ") + String(format: "%.1f cm", Double(l) / 10)) }
        if let s = page.sleepHours { out.append(L10n.t("日均睡眠 ", "Sleep ") + String(format: "%.1f h", s)) }
        if let f = page.feeds { out.append(L10n.t("日均喂奶 ", "Feeds ") + String(format: "%.0f", f.rounded()) + L10n.t(" 次", "/d")) }
        return out
    }
}

// MARK: - Epilogue Spread

private struct StorybookEpilogueSpread: View {
    @Environment(AppModel.self) private var app
    @Environment(\.lamp) private var lamp
    let totalMonths: Int

    var body: some View {
        VStack {
            Spacer(minLength: 16)
            VStack(spacing: 16) {
                Duo(primary: app.companion, size: 108, mood: .happy, poke: true, night: lamp)
                Text(L10n.t("故事仍在继续", "The Story Goes On"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                Text(L10n.t(
                    "这本绘本已经收录了 \(totalMonths) 个月份。以后每一个新玩的托盘、每一次小发现，都会自己长成下一页。",
                    "This keepsake holds \(totalMonths) \(totalMonths == 1 ? "month" : "months") so far. Every new play tray and tiny discovery will gently become the next page."
                ))
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    GoldBead(size: 7)
                    Text(L10n.t("孩子摸索，大人点灯", "They explore. You hold the light."))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                    GoldBead(size: 7)
                }
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .printCard(radius: Radius.stage)
            .padding(.horizontal, 20)
            Spacer(minLength: 16)
        }
    }
}

// MARK: - 3x Print Export Cards (Rendered Lazily via ImageRenderer)

private struct StorybookCoverPrintCard: View {
    let babyName: String
    let birthYMD: String?
    let ageLabel: String?
    let monthCount: Int
    let playCount: Int
    let firstCount: Int
    let coverImage: UIImage?

    var body: some View {
        let paper = Color(red: 0xFB / 255, green: 0xF7 / 255, blue: 0xF0 / 255)
        let ink = Color(red: 0x24 / 255, green: 0x1F / 255, blue: 0x1B / 255)
        let teal = Color(red: 0x0B / 255, green: 0x7D / 255, blue: 0x74 / 255)
        let bead = Color(red: 0xD4 / 255, green: 0xA2 / 255, blue: 0x1C / 255)

        VStack(spacing: 16) {
            HStack(spacing: 6) {
                Circle().fill(bead).frame(width: 7, height: 7)
                Text(L10n.t("成长绘本", "GROWTH STORYBOOK"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(teal)
                Circle().fill(bead).frame(width: 7, height: 7)
            }

            if let coverImage {
                Image(uiImage: coverImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 312, height: 224)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(6)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            }

            VStack(spacing: 4) {
                Text(L10n.t("\(babyName)的成长绘本", "\(babyName)'s Storybook"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                if let ageLabel {
                    Text(ageLabel)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(teal)
                }
                if let birthYMD {
                    Text(L10n.t("始于 \(birthYMD)", "Since \(birthYMD)"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(ink.opacity(0.55))
                }
            }

            HStack(spacing: 16) {
                Text(L10n.t("\(monthCount) 个月", "\(monthCount) mo"))
                Text("·")
                Text(L10n.t("\(playCount) 次玩过", "\(playCount) plays"))
                Text("·")
                Text(L10n.t("\(firstCount) 个第一次", "\(firstCount) firsts"))
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(ink.opacity(0.7))

            Divider().opacity(0.3)

            Text(L10n.t("摸索台灯 · 孩子摸索，大人点灯", "Moss & Otto · They explore. You hold the light."))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(ink.opacity(0.55))
        }
        .padding(24)
        .frame(width: 360)
        .background(paper)
    }
}

private struct StorybookMonthPrintCard: View {
    let babyName: String
    let month: Int
    let chapterTitle: String
    let firstLines: [String]
    let playNames: [String]
    let coverImage: UIImage?
    let firstPhoto: UIImage?

    var body: some View {
        let paper = Color(red: 0xFB / 255, green: 0xF7 / 255, blue: 0xF0 / 255)
        let ink = Color(red: 0x24 / 255, green: 0x1F / 255, blue: 0x1B / 255)
        let teal = Color(red: 0x0B / 255, green: 0x7D / 255, blue: 0x74 / 255)
        let bead = Color(red: 0xD4 / 255, green: 0xA2 / 255, blue: 0x1C / 255)

        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(bead).frame(width: 7, height: 7)
                    Text(month == 0 ? L10n.t("出生", "Birth") : L10n.t("满 \(month) 个月", "Month \(month)"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(teal)
                }
                Spacer()
                Text(babyName)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.55))
            }

            Text(chapterTitle)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(ink)

            ZStack(alignment: .bottomTrailing) {
                if let coverImage {
                    Image(uiImage: coverImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 312, height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(5)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if let firstPhoto {
                    Image(uiImage: firstPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .padding(4)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                        .offset(x: 4, y: 10)
                }
            }
            .padding(.bottom, firstPhoto != nil ? 10 : 0)

            if !firstLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(firstLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(ink.opacity(0.85))
                    }
                }
            }

            if !playNames.isEmpty {
                Text(L10n.t("一起玩过：", "Played: ") + playNames.joined(separator: " · "))
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(ink.opacity(0.7))
            }

            Divider().opacity(0.3)

            Text(L10n.t("摸索台灯 · 孩子摸索，大人点灯", "Moss & Otto · They explore. You hold the light."))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(ink.opacity(0.55))
        }
        .padding(24)
        .frame(width: 360)
        .background(paper)
    }
}
