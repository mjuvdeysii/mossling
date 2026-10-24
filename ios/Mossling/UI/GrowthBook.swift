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
                    ForEach(Array(pages.enumerated()), id: \.element.month) { i, p in
                        BookPageView(page: p, current: i == 0, tilt: i % 2 == 0 ? -2 : 1.6)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 40)
        }
        .pageBackground(tone: Crayon.caramel)
        .navigationTitle("成长册")
        .navigationSubtitle(app.birth.map { "从 " + String($0.y) + "年" + $0.md + " 开始" } ?? "")
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
    var empty: Bool { plays.isEmpty && observed == 0 && measure == nil && days == 0 && notes.isEmpty }

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
                            notes: Array(logs.filter { $0.type == LogType.note && !($0.detail ?? "").isEmpty }.prefix(3)))
        }
    }
}

/// The whole book in three numbers.
private struct BookTotals: View {
    let pages: [BookPage]
    var body: some View {
        let plays = pages.reduce(0) { $0 + $1.plays.reduce(0) { $0 + $1.times } }
        let kinds = Set(pages.flatMap { $0.plays.map(\.play.code) }).count
        HStack(spacing: 0) {
            item("\(pages.count)", "个月")
            Divider().frame(height: 30)
            item("\(plays)", "次玩耍")
            Divider().frame(height: 30)
            item("\(kinds)", "种教具")
        }
        .padding(.vertical, 12)
        .background(LinearGradient(colors: [Crayon.caramel.opacity(0.14), Crayon.sunflower.opacity(0.08)], startPoint: .leading, endPoint: .trailing))
        .printCard(radius: 22)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }
    private func item(_ n: String, _ unit: String) -> some View {
        VStack(spacing: 1) {
            Text(n).font(Typeface.numerals(24, relativeTo: .title2, weight: .bold)).foregroundStyle(Palette.accent)
            Text(unit).font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct BookPageView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var type
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: type.isAccessibilitySize ? 140 : 92), spacing: 10, alignment: .top)], alignment: .leading, spacing: 12) {
                    ForEach(page.plays, id: \.play.code) { x in
                        NavigationLink(value: Route.play(x.play.code, min(m, 36))) { PlayStamp(play: x.play, times: x.times) }
                            .buttonStyle(.toy)
                    }
                }
            }

            let facts = self.facts
            if !facts.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: type.isAccessibilitySize ? 220 : 140), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(facts, id: \.label) { f in FactChip(fact: f) }
                }
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

            if page.empty {
                Text(current ? "这个月的记录会出现在这里：玩过的教具、测量和照护。" : "这一站没有留下记录。")
                    .font(.footnote).foregroundStyle(Palette.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .topTrailing) {
            // a faint page number in the corner, like a printed album
            Text(m == 0 ? "0" : "\(m)").font(Typeface.numerals(64, relativeTo: .largeTitle, weight: .heavy))
                .foregroundStyle(Crayon.caramel.opacity(0.09)).padding(.trailing, 14).padding(.top, 2)
                .accessibilityHidden(true)
        }
        .printCard(radius: 26)
    }

    /// The month's picture pinned like a photograph: a white border, a slight tilt, a strip of tape.
    private func photo(_ m: Int) -> some View {
        Group {
            if let f = ArtIndex.shared.cover(min(m, 36)) { ArtView(name: f, label: "满 \(m) 个月", radius: 6) }
            else { ZStack { Sky(hour: 12); GrowingChild(month: m).padding(10) }.aspectRatio(4 / 3, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 6)) }
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

    private var range: String {
        let a = Day(page.from), b = Day(page.to.addingTimeInterval(-1))
        return a.y == b.y ? "\(a.y)年\(a.md) – \(b.md)" : "\(a.y)年\(a.md) – \(b.y)年\(b.md)"
    }

    private var facts: [Fact] {
        var f: [Fact] = []
        if let w = page.measure?.weightG { f.append(Fact(symbol: "scalemass.fill", color: Crayon.leaf, value: String(format: "%.1f", Double(w) / 1000), unit: "千克", label: "体重")) }
        if let l = page.measure?.lengthMm { f.append(Fact(symbol: "ruler.fill", color: Crayon.aqua, value: String(format: "%.1f", Double(l) / 10), unit: "厘米", label: "身长")) }
        if let h = page.measure?.headMm { f.append(Fact(symbol: "circle.dashed", color: Crayon.sky, value: String(format: "%.1f", Double(h) / 10), unit: "厘米", label: "头围")) }
        if let s = page.sleepHours { f.append(Fact(symbol: LogType.symbol(LogType.sleep), color: LogType.color(LogType.sleep), value: String(format: "%.1f", s), unit: "小时", label: "每天睡眠")) }
        if let x = page.feeds { f.append(Fact(symbol: LogType.symbol(LogType.nurse), color: LogType.color(LogType.nurse), value: String(format: "%.1f", x), unit: "次", label: "每天喂奶")) }
        if let x = page.diapers { f.append(Fact(symbol: LogType.symbol(LogType.diaper), color: LogType.color(LogType.diaper), value: String(format: "%.1f", x), unit: "片", label: "每天尿布")) }
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

/// A play in the book: its picture, how many times, its name.
private struct PlayStamp: View {
    let play: Play
    let times: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Figure(name: "tray_\(play.code.lowercased()).webp").aspectRatio(4 / 3, contentMode: .fit)
                    .padding(6)
                    .background(Palette.area(Palette.areaKey(of: play)).opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                if times > 1 {
                    Text("×\(times)").font(Typeface.numerals(11, relativeTo: .caption, weight: .bold)).foregroundStyle(Color(hex: 0x4A3300))
                        .padding(.horizontal, 6).frame(height: 18).background(Capsule().fill(Palette.bead)).padding(4)
                }
            }
            Text(play.name).font(.caption.weight(.semibold)).foregroundStyle(.primary).lineLimit(2, reservesSpace: true).multilineTextAlignment(.leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(play.name + (times > 1 ? "，\(times) 次" : ""))
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
                        .frame(width: 64).padding(3)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white))
                        .shadow(color: Color(hex: 0x6B4A2B).opacity(0.18), radius: 3, y: 2)
                        .rotationEffect(.degrees(Double(i) * 7 - 4))
                        .offset(x: Double(i) * 9, y: Double(i) * -2)
                    }
                }
                .frame(width: 92, height: 72)
                VStack(alignment: .leading, spacing: 3) {
                    Text("成长册").font(.headline).foregroundStyle(.primary)
                    Text(pages.isEmpty ? "每个月一页，从出生开始" : "\(pages.count) 个月 · 玩过 \(plays) 次").font(.subheadline).foregroundStyle(Palette.secondaryText)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(LinearGradient(colors: [Crayon.caramel.opacity(0.14), Crayon.sunflower.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .printCard(radius: 24)
        }
        .buttonStyle(.toy)
        .accessibilityLabel("成长册")
    }
}
