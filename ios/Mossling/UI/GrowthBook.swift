import SwiftUI

/// 成长册: one page for every month the child has lived, the newest on top — the month's picture pinned like a photo,
/// the plays done in that month as small pictures with how many times, the last measurement of the month, the
/// month's care in daily averages (only from days with records), and the notes written then. Built from what is
/// already recorded; nothing to fill in. Pictures first, a few numbers, no charts.
struct GrowthBookView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    var body: some View {
        let pages = BookPage.all(app, j)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if pages.isEmpty {
                    ContentUnavailableView("填写出生日期后，成长册从出生那个月开始", systemImage: "book.closed")
                        .padding(.top, 60)
                } else {
                    BookTotals(pages: pages)
                    if (app.babyMonth ?? 0) >= 36 { StoryGoesOn(primary: app.companion) }
                    // months with nothing recorded are gathered into one strip of small photos, so the book is read in a
                    // few screens, not one screen a month
                    ForEach(Self.runs(pages), id: \.id) { r in
                        if r.pages.count == 1 && (!r.pages[0].empty || r.first) {
                            BookPageView(page: r.pages[0], current: r.first, tilt: r.index % 2 == 0 ? -2 : 1.6)
                        } else {
                            QuietMonths(pages: r.pages)
                        }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 40)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.caramel)
        .navigationTitle("成长册")
        .navigationSubtitle(subtitle)
    }

    /// The pages in order, with each run of empty months (other than this month) as one group.
    struct Run { let id: Int; let index: Int; let first: Bool; let pages: [BookPage] }
    static func runs(_ pages: [BookPage]) -> [Run] {
        var out: [Run] = [], quiet: [BookPage] = []
        func flush() { if !quiet.isEmpty { out.append(Run(id: -quiet[0].month - 1, index: out.count, first: false, pages: quiet)); quiet = [] } }
        for (i, p) in pages.enumerated() {
            if i > 0 && p.empty { quiet.append(p); continue }
            flush()
            out.append(Run(id: p.month, index: out.count, first: i == 0, pages: [p]))
        }
        flush()
        return out
    }

    private var subtitle: String {
        guard let b = app.birth else { return "" }
        return "从 \(b.y)年\(b.md) 开始"
    }
}

/// Months with nothing recorded, together: their pictures as a row of small photos (each opens its month) and one line.
private struct QuietMonths: View {
    let pages: [BookPage]
    @Environment(\.dynamicTypeSize) private var type
    var body: some View {
        let ms = pages.map(\.month)
        let lo = ms.min() ?? 0, hi = ms.max() ?? 0
        VStack(alignment: .leading, spacing: 10) {
            Text((lo == hi ? (lo == 0 ? "出生" : "满 \(lo) 个月") : (lo == 0 ? "出生–\(hi) 个月" : "满 \(lo)–\(hi) 个月")) + " · 没有留下记录")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondaryText)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: type.isAccessibilitySize ? 96 : 60), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(pages, id: \.month) { p in
                    NavigationLink(value: Route.month(min(p.month, 36))) {
                        VStack(spacing: 3) {
                            Group {
                                if let f = ArtIndex.shared.cover(min(p.month, 36)) { ArtView(name: f, label: "满 \(p.month) 个月", radius: 4) }
                                else { Color.clear.aspectRatio(4 / 3, contentMode: .fit) }
                            }
                            .padding(3)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white))
                            .shadow(color: Color(hex: 0x6B4A2B).opacity(0.14), radius: 3, y: 2)
                            Text("\(p.month)").font(Typeface.numerals(12, relativeTo: .caption, weight: .bold)).foregroundStyle(Palette.secondaryText)
                        }
                    }
                    .buttonStyle(.toy)
                    .accessibilityLabel("满 \(p.month) 个月，没有记录")
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .printCard(radius: 22)
    }
}

/// One month of the book, gathered from the records.
struct BookPage {
    let month: Int
    let from: Date, to: Date
    let plays: [(play: Play, times: Int)]
    let observed: Int
    let measure: Measure?
    /// Days in the month with any care record, and the averages over those days.
    let days: Int
    let sleepHours: Double?, feeds: Double?, diapers: Double?
    let notes: [LogEntry]
    /// The firsts of this month (第一次), oldest first.
    let firsts: [First]
    var empty: Bool { plays.isEmpty && observed == 0 && measure == nil && days == 0 && notes.isEmpty && firsts.isEmpty }

    static func all(_ app: AppModel, _ j: JournalStore) -> [BookPage] {
        guard let birth = app.birth, let baby = app.babyMonth else { return [] }
        let now = Date()
        return (0...baby).reversed().map { m in
            let from = birth.plus(months: m).date, to = min(birth.plus(months: m + 1).date, now)
            let a = from.timeIntervalSince1970 * 1000, b = to.timeIntervalSince1970 * 1000
            let logs = j.logs.filter { $0.start >= a && $0.start < b }
            // plays: what was recorded in these weeks, and plays marked done for this month before plays were logged
            var times: [String: Int] = [:], order: [String] = []
            for l in logs.reversed() where l.type == LogType.play {
                guard let code = (l.detail ?? "").split(separator: " ").first.map(String.init) else { continue }
                if times[code] == nil { order.append(code) }
                times[code, default: 0] += 1
            }
            for t in app.ticks.values.sorted(by: { $0.at < $1.at }) where t.month == m && t.kind == TickKind.did {
                let code = String(t.key.split(separator: ":").last ?? "")
                if times[code] == nil && j.plays(code).isEmpty { times[code] = 1; order.append(code) }
            }
            let plays = order.compactMap { c in app.content.play(c).map { (play: $0, times: times[c] ?? 1) } }
            // care, as daily averages over the days that have records
            let care = logs.filter { [LogType.nurse, LogType.bottle, LogType.sleep, LogType.diaper].contains($0.type) }
            let days = Set(care.map { Day($0.startDate) }).count
            var feeds = 0, lastNurseEnd: Double = -.infinity
            for l in care.reversed() where l.type == LogType.nurse || l.type == LogType.bottle {
                // the two sides of one feed are two entries; count them once
                if l.type == LogType.nurse, l.start - lastNurseEnd < 5 * 60_000 { lastNurseEnd = l.end ?? l.start; continue }
                feeds += 1
                if l.type == LogType.nurse { lastNurseEnd = l.end ?? l.start }
            }
            let sleep = care.filter { $0.type == LogType.sleep }.reduce(0) { $0 + $1.activeSeconds }
            let diapers = care.filter { $0.type == LogType.diaper }.count
            let d = Double(max(days, 1))
            return BookPage(month: m, from: from, to: to, plays: plays, observed: app.count(m, TickKind.observed),
                            measure: j.measures.last { $0.at >= a && $0.at < b }, days: days,
                            sleepHours: sleep > 0 ? sleep / 3600 / d : nil, feeds: feeds > 0 ? Double(feeds) / d : nil,
                            diapers: diapers > 0 ? Double(diapers) / d : nil,
                            notes: Array(logs.filter { $0.type == LogType.note && !($0.detail ?? "").isEmpty }.prefix(3)),
                            firsts: j.firsts.filter { $0.at >= a && $0.at < b }.sorted { $0.at < $1.at })
        }
    }
}

/// The whole book in three numbers.
private struct BookTotals: View {
    let pages: [BookPage]
    var body: some View {
        let plays = pages.reduce(0) { $0 + $1.plays.reduce(0) { $0 + $1.times } }
        let kinds = Set(pages.flatMap { $0.plays.map(\.play.code) }).count
        let firsts = pages.reduce(0) { $0 + $1.firsts.count }
        HStack(spacing: 0) {
            item("\(pages.count)", "页")
            Divider().frame(height: 30)
            item("\(plays)", "次玩过")
            Divider().frame(height: 30)
            item("\(kinds)", "种教具")
            Divider().frame(height: 30)
            // the firsts open from their own count: the timeline of every 第一次, and a new one kept there
            NavigationLink(value: JournalRoute.firsts) {
                VStack(spacing: 1) {
                    Text("\(firsts)").font(Typeface.numerals(24, relativeTo: .title2, weight: .bold)).foregroundStyle(Palette.bead.mix(with: .black, by: 0.18))
                    HStack(spacing: 2) {
                        Text("个第一次").font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity).contentShape(Rectangle())
            }
            .buttonStyle(.toy)
            .accessibilityLabel("\(firsts) 个第一次，打开第一次时间线")
        }
        .padding(.vertical, 12)
        .background(LinearGradient(colors: [Crayon.caramel.opacity(0.14), Crayon.sunflower.opacity(0.08)], startPoint: .leading, endPoint: .trailing))
        .printCard(radius: 22)
        .padding(.top, 4)
    }
    private func item(_ n: String, _ unit: String) -> some View {
        VStack(spacing: 1) {
            Text(n).font(Typeface.numerals(24, relativeTo: .title2, weight: .bold)).foregroundStyle(Palette.accent)
            Text(unit).font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity).accessibilityElement(children: .combine)
    }
}

private struct BookPageView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var type
    @State private var newFirst: First?
    let page: BookPage
    let current: Bool
    let tilt: Double
    var body: some View {
        let m = page.month, mo = app.content.month(m)
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink(value: Route.month(min(m, 36))) {
                HStack(alignment: .center, spacing: 16) {
                    photo(m)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(m == 0 ? "出生" : "满 \(m) 个月").font(.title3.weight(.bold)).foregroundStyle(.primary)
                            if current {
                                Text("这个月").font(.caption2.weight(.bold)).foregroundStyle(Color(hex: 0x4A3300))
                                    .padding(.horizontal, 7).padding(.vertical, 2).background(Capsule().fill(Palette.bead))
                            }
                        }
                        Text(mo.title).font(.subheadline).foregroundStyle(Palette.secondaryText).lineLimit(type.isAccessibilitySize ? nil : 2).multilineTextAlignment(.leading)
                        Text(range).font(.caption).foregroundStyle(.tertiary).monospacedDigit()
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.toy)

            if !page.plays.isEmpty {
                // two to a row; an odd last one takes the whole row rather than leave half of it empty
                EvenRows(items: page.plays, id: \.play.code, per: type.isAccessibilitySize ? 1 : 2) { x in
                    NavigationLink(value: Route.play(x.play.code, min(m, 36))) { PlayStamp(play: x.play, times: x.times) }
                        .buttonStyle(.toy)
                }
            }

            if !page.firsts.isEmpty { FirstStamps(firsts: page.firsts) }

            let facts = self.facts
            if !facts.isEmpty {
                EvenRows(items: facts, id: \.label, per: type.isAccessibilitySize ? 1 : 2) { f in FactChip(fact: f) }
                if page.days > 0 {
                    Text("照护为有记录的 \(page.days) 天的每日平均").font(.caption2).foregroundStyle(.tertiary).padding(.leading, 2)
                }
            }

            ForEach(page.notes) { n in
                HStack(alignment: .top, spacing: 10) {
                    RoundedRectangle(cornerRadius: 2).fill(Crayon.caramel.opacity(0.6)).frame(width: 3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(n.detail ?? "").font(.subheadline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                        Text(Day(n.startDate).md).font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            // this month's page: a first can be kept right here, onto this page
            if current {
                Button { newFirst = First(at: ms(Date()), title: "") } label: {
                    Label(page.firsts.isEmpty ? "记下这个月的第一次" : "再记一个第一次", systemImage: "star.fill").font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.vinyl(Palette.bead))
                .sheet(item: $newFirst) { f in FirstSheet(first: f, isNew: true).lampPresented() }
            }

            if page.empty {
                Text(current ? "这个月的记录会出现在这里：玩过的教具、测量和照护。" : "这一站没有留下记录。")
                    .font(.footnote).foregroundStyle(Palette.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .printCard(radius: 26)
    }

    /// The month's picture pinned like a photograph: a white border, a slight tilt, a strip of tape.
    private func photo(_ m: Int) -> some View {
        Group {
            if let f = ArtIndex.shared.cover(min(m, 36)) { ArtView(name: f, label: "满 \(m) 个月", radius: 6) }
            else { ZStack { StagePlate(); GrowingChild(month: m).padding(10) }.aspectRatio(4 / 3, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 6)) }
        }
        .frame(width: type.isAccessibilitySize ? 96 : 112)
        .padding(5)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.white))
        .shadow(color: Color(hex: 0x6B4A2B).opacity(0.18), radius: 5, y: 3)
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 2).fill(Crayon.sunflower.opacity(0.55)).frame(width: 34, height: 12)
                .rotationEffect(.degrees(-tilt * 2)).offset(y: -6)
        }
        .rotationEffect(.degrees(tilt))
        .padding(.vertical, 6).padding(.leading, 2)
    }

    /// The days the page covers; the month still being lived runs to 至今 (not to a day that has not come).
    private var range: String {
        let a = Day(page.from), b = Day(page.to.addingTimeInterval(-1))
        if page.to > Date() { return "\(a.y)年\(a.md) – 至今" }
        return a.y == b.y ? "\(a.y)年\(a.md) – \(b.md)" : "\(a.y)年\(a.md) – \(b.y)年\(b.md)"
    }

    private var facts: [Fact] {
        var f: [Fact] = []
        if let w = page.measure?.weightG { f.append(Fact(symbol: "scalemass.fill", color: Crayon.leaf, value: String(format: "%.1f", Double(w) / 1000), unit: "千克", label: "体重")) }
        if let l = page.measure?.lengthMm { f.append(Fact(symbol: "ruler.fill", color: Crayon.aqua, value: String(format: "%.1f", Double(l) / 10), unit: "厘米", label: "身长")) }
        if let h = page.measure?.headMm { f.append(Fact(symbol: "circle.dashed", color: Crayon.sky, value: String(format: "%.1f", Double(h) / 10), unit: "厘米", label: "头围")) }
        if let s = page.sleepHours { f.append(Fact(symbol: LogType.symbol(LogType.sleep), color: LogType.color(LogType.sleep), value: String(format: "%.1f", s), unit: "小时", label: "每天睡眠")) }
        if let x = page.feeds { f.append(Fact(symbol: LogType.symbol(LogType.nurse), color: LogType.color(LogType.nurse), value: String(format: "%.0f", x.rounded()), unit: "次", label: "每天喂奶")) }
        if let x = page.diapers { f.append(Fact(symbol: LogType.symbol(LogType.diaper), color: LogType.color(LogType.diaper), value: String(format: "%.0f", x.rounded()), unit: "片", label: "每天尿布")) }
        if page.observed > 0 { f.append(Fact(symbol: "eye.fill", color: Crayon.tangerine, value: "\(page.observed)", unit: "项", label: "留意到")) }
        return f
    }
}

private struct Fact { let symbol: String; let color: Color; let value: String; let unit: String; let label: String }

private struct FactChip: View {
    let fact: Fact
    var body: some View {
        HStack(spacing: 8) {
            IconTile(symbol: fact.symbol, color: fact.color, size: 30)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(fact.value).font(Typeface.numerals(17, relativeTo: .headline, weight: .bold)).foregroundStyle(.primary)
                    Text(fact.unit).font(.caption2.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                }
                .lineLimit(1).fixedSize()
                Text(fact.label).font(.caption2).foregroundStyle(Palette.secondaryText).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).padding(.vertical, 7)
        .background(fact.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Items laid out a few to a row, spread evenly over the rows they need: rows differ by at most one, the fuller
/// rows first (four in rows of three become two and two, five become three and two, seven three, two and two), and
/// each row's items share its width — so no row is a lone tile pulled across the page. When one must stand alone
/// (an odd count two to a row), it is told so through `aloneInRow`, and a cell that has a wide form uses it rather
/// than stretching the narrow one.
struct EvenRows<Item, ID: Hashable, Cell: View>: View {
    let items: [Item]
    let id: KeyPath<Item, ID>
    var per = 2
    var spacing: CGFloat = 8
    @ViewBuilder let cell: (Item) -> Cell
    /// Where each row starts and ends.
    static func rows(_ n: Int, per: Int) -> [Range<Int>] {
        guard n > 0 else { return [] }
        let p = max(1, per), r = (n + p - 1) / p, base = n / r, extra = n % r
        var out: [Range<Int>] = [], at = 0
        for k in 0..<r { let len = base + (k < extra ? 1 : 0); out.append(at..<(at + len)); at += len }
        return out
    }
    var body: some View {
        VStack(spacing: spacing) {
            ForEach(Self.rows(items.count, per: per), id: \.lowerBound) { r in
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(items[r], id: id) { x in
                        cell(x).frame(maxWidth: .infinity).environment(\.aloneInRow, r.count == 1 && per > 1)
                    }
                }
            }
        }
    }
}

extension EnvironmentValues {
    /// This cell stands alone across a row meant for several: use a wide form if there is one.
    @Entry var aloneInRow: Bool = false
}

/// A play in the book, as a chip beside the month's facts: its own tray on its area's tile, its name, how many times.
private struct PlayStamp: View {
    let play: Play
    let times: Int
    @ScaledMetric(relativeTo: .caption) private var w: CGFloat = 48
    var body: some View {
        let c = Palette.area(Palette.areaKey(of: play))
        HStack(spacing: 8) {
            TrayTile(code: play.code, color: c, flat: ArtStyle.current == .flat)
                .frame(width: min(w, 80), height: min(w, 80) * 0.75)
            VStack(alignment: .leading, spacing: 1) {
                Text(play.name).font(.caption.weight(.semibold)).foregroundStyle(.primary).lineLimit(2).multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("玩过 \(times) 次").font(Typeface.numerals(11, relativeTo: .caption2, weight: .semibold)).foregroundStyle(Palette.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(6)
        .background(c.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(play.name + "，玩过 \(times) 次")
    }
}

/// The book's door in 我的: the last three months' pictures fanned like photos, and what the book holds.
struct GrowthBookCard: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    var body: some View {
        let baby = app.babyMonth ?? 0
        let shown = Array((max(0, baby - 2)...baby).reversed())
        let pages = BookPage.all(app, j)
        let plays = pages.reduce(0) { $0 + $1.plays.reduce(0) { $0 + $1.times } }
        NavigationLink(value: Route.book) {
            HStack(spacing: 14) {
                ZStack {
                    ForEach(Array(shown.enumerated().reversed()), id: \.element) { i, m in
                        Group {
                            if let f = ArtIndex.shared.cover(min(m, 36)) { ArtView(name: f, radius: 4) } else { Palette.fill }
                        }
                        .frame(width: 46).padding(2.5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
                        .shadow(color: Color(hex: 0x6B4A2B).opacity(0.18), radius: 3, y: 2)
                        .rotationEffect(.degrees(Double(i) * 7 - 4))
                        .offset(x: Double(i) * 7, y: Double(i) * -2)
                    }
                }
                .frame(width: 70, height: 50)
                VStack(alignment: .leading, spacing: 1) {
                    Text("成长册").font(.headline).foregroundStyle(.primary)
                    Text(pages.isEmpty ? "每个月一页，从出生开始" : "\(pages.count) 页 · 玩过 \(plays) 次").font(.subheadline).foregroundStyle(Palette.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(LinearGradient(colors: [Crayon.caramel.opacity(0.14), Crayon.sunflower.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .printCard(radius: 24)
        }
        .buttonStyle(.toy)
        .accessibilityLabel("成长册")
    }
}
