import SwiftUI

/// The journey: 0 to 36 months as one string of golden beads running down the page, a bead per month. Months already
/// lived are gold, the child's month is larger with the two companions beside it, the months ahead are open rings.
/// Past the last bead the string runs on. Each bead opens its month.
struct JourneyView: View {
    @Environment(AppModel.self) private var app
    @Binding var path: NavigationPath
    private let stages: [Int: String] = [0: "0–3 个月", 3: "3–6 个月", 6: "6–9 个月", 9: "9–12 个月", 12: "1 岁 · 12–18 个月", 18: "18–24 个月", 24: "2 岁 · 24–30 个月", 30: "30–36 个月"]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(0...36, id: \.self) { m in
                        if let s = stages[m] {
                            HStack(spacing: 8) {
                                Circle().fill(stageColor(m)).frame(width: 10, height: 10)
                                Text(s).font(.title3.weight(.bold))
                            }
                            .padding(.leading, 20).padding(.top, m == 0 ? 8 : 26).padding(.bottom, 4)
                            .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
                        }
                        NavigationLink(value: Route.month(m)) { Station(month: m, first: m == 0) }
                            .buttonStyle(.plain).id(m)
                    }
                    Trail().frame(height: 90)
                    StoryGoesOn(primary: app.companion).padding(.horizontal, 16).padding(.top, 4)
                }
                .padding(.bottom, 40)
            }
            .background(Palette.background)
            .navigationTitle("旅程")
            .navigationSubtitle("一个月一站 · 0–36 个月")
            .toolbar {
                if let b = app.babyMonth {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("满 \(b) 个月", systemImage: "location.fill") { withAnimation(.snappy) { proxy.scrollTo(b, anchor: .center) } }
                    }
                }
            }
            .onAppear { if let b = app.babyMonth { proxy.scrollTo(b, anchor: .center) } }
        }
    }
}

/// Each stretch of months has its own crayon; the beads of lived months take it, like a bead stair.
func stageColor(_ m: Int) -> Color {
    let i = [0, 3, 6, 9, 12, 18, 24, 30].lastIndex { $0 <= m } ?? 0
    return Crayon.rainbow[i % Crayon.rainbow.count]
}

/// Where the bead of month m sits across the page: a gentle wave near the leading edge.
private func beadX(_ m: Int) -> CGFloat { 44 + 16 * CGFloat(sin(Double(m) * 0.85)) }

private struct Station: View {
    @Environment(AppModel.self) private var app
    let month: Int
    var first = false

    var body: some View {
        let mo = app.content.month(month)
        let baby = app.babyMonth
        let here = baby == month, past = (baby ?? -1) > month
        let care = !mo.vaccines.isEmpty || !mo.checkups.isEmpty
        let careDone = care && mo.vaccines.indices.allSatisfy { app.ticked(month, TickKind.vaccine, "\($0)") } && mo.checkups.indices.allSatisfy { app.ticked(month, TickKind.checkup, "\($0)") }
        HStack(alignment: .center, spacing: 0) {
            Color.clear.frame(width: 92)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(month == 0 ? "出生" : "满 \(month) 个月").font(here ? .headline : .body.weight(.semibold))
                    if let b = app.birth { Text(b.plus(months: month).md).font(.footnote).foregroundStyle(.secondary).monospacedDigit() }
                }
                Text(mo.title).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading).lineLimit(2)
                if care {
                    HStack(spacing: 8) {
                        if !mo.vaccines.isEmpty { Image(systemName: "syringe.fill").foregroundStyle(Crayon.sky) }
                        if !mo.checkups.isEmpty { Image(systemName: "stethoscope").foregroundStyle(Crayon.aqua) }
                        if careDone { Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.accent) }
                    }
                    .font(.caption).padding(.top, 2)
                    .accessibilityElement().accessibilityLabel(careDone ? "接种与儿保已记下" : "有接种或儿保")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if here {
                Duo(primary: app.companion, size: 54, look: CGPoint(x: -0.9, y: 0.3)).padding(.trailing, 12)
            } else {
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).padding(.trailing, 20)
            }
        }
        .padding(.vertical, here ? 18 : 12)
        .frame(minHeight: here ? 104 : 78)
        .background(alignment: .leading) { StringAndBead(month: month, here: here, past: past, first: first) }
        .background {
            if here { RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Palette.card).padding(.horizontal, 12) }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel((month == 0 ? "出生" : "满 \(month) 个月") + "，\(mo.title)" + (here ? "，宝宝在这里" : ""))
    }
}

/// The string through this month's row and the bead on it.
private struct StringAndBead: View {
    let month: Int, here: Bool, past: Bool, first: Bool
    var body: some View {
        Canvas { ctx, size in
            let x0 = (beadX(month - 1) + beadX(month)) / 2, x = beadX(month), x1 = (beadX(month) + beadX(month + 1)) / 2
            let y = size.height / 2
            var s = Path()
            s.move(to: CGPoint(x: first ? x : x0, y: first ? y : 0))
            if !first { s.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x0, y: y * 0.6)) }
            s.addQuadCurve(to: CGPoint(x: x1, y: size.height), control: CGPoint(x: x1, y: y + (size.height - y) * 0.4))
            ctx.stroke(s, with: .color(stageColor(month).opacity(0.45)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
        .frame(width: 100)
        .overlay(alignment: .topLeading) {
            GeometryReader { g in
                Bead(month: month, here: here, past: past).position(x: beadX(month), y: g.size.height / 2)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A golden bead: polished when the month has been lived, larger for the child's month, an open ring for months ahead.
struct Bead: View {
    let month: Int, here: Bool, past: Bool
    var body: some View {
        let d: CGFloat = here ? 44 : 32
        ZStack {
            let c = stageColor(month)
            if here {
                Circle().fill(RadialGradient(colors: [Palette.beadLight, Palette.bead, Color(hex: 0x8A6206)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: d * 0.75))
            } else if past {
                Circle().fill(c.gradient)
            } else {
                Circle().fill(Palette.card)
                Circle().strokeBorder(c.opacity(0.7), lineWidth: 2.5)
            }
            if here || past { Ellipse().fill(.white.opacity(0.7)).frame(width: d * 0.26, height: d * 0.16).offset(x: -d * 0.18, y: -d * 0.24) }
            Text("\(month)").font(Typeface.numerals(here ? 18 : 13, relativeTo: .footnote, weight: .bold))
                .foregroundStyle(here ? Color(hex: 0x4A3300) : past ? Crayon.glyph(on: c) : Color.secondary)
        }
        .frame(width: d, height: d)
        .shadow(color: here ? Palette.bead.opacity(0.5) : .clear, radius: 8)
    }
}

/// Past the last bead the string goes on, fading.
private struct Trail: View {
    var body: some View {
        Canvas { ctx, size in
            for i in 0..<5 {
                let m = 37 + i
                let y = 10 + CGFloat(i) * 18
                let r: CGFloat = 5 - CGFloat(i) * 0.7
                ctx.fill(Path(ellipseIn: CGRect(x: beadX(m) - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Crayon.rainbow[i].opacity(0.7 - Double(i) * 0.12)))
            }
        }
        .accessibilityHidden(true)
    }
}

/// One month as a page: the cover picture, then the month in order — points, plays, the six areas, what to look out
/// for, vaccinations and check-ups, notes, the day's rhythm, topics.
struct MonthView: View {
    @Environment(AppModel.self) private var app
    let month: Int
    @State private var scrolled = false

    var body: some View {
        let c = app.content, mo = c.month(month), m = month
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let f = ArtIndex.shared.cover(m) { StretchyArt(name: f, height: 300) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(m == 0 ? "出生" : "满 \(m) 个月").font(.largeTitle.weight(.bold))
                    Text(mo.title).font(.title3).foregroundStyle(.secondary)
                    if let b = app.birth { Text(b.plus(months: m).md + (app.babyMonth == m ? " · 宝宝在这一站" : "")).font(.subheadline).foregroundStyle(.secondary).padding(.top, 2) }
                }
                .padding(.horizontal, 20).padding(.top, 16)
                .onScrollVisibilityChange(threshold: 0.1) { v in withAnimation(.easeOut(duration: 0.2)) { scrolled = !v } }

                MonthBody(month: m).padding(.horizontal, 16).padding(.top, 8)
            }
            .padding(.bottom, 40)
        }
        .ignoresSafeArea(edges: .top)
        .background(Palette.background)
        .navigationTitle(m == 0 ? "出生" : "满 \(m) 个月")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Text(m == 0 ? "出生" : "满 \(m) 个月").font(.headline).opacity(scrolled ? 1 : 0) }
        }
    }
}

/// A picture across the top of a page that stretches when pulled down.
struct StretchyArt: View {
    let name: String
    var height: CGFloat = 300
    var body: some View {
        GeometryReader { g in
            let y = g.frame(in: .scrollView).minY
            ArtFill(name: name).frame(width: g.size.width, height: height + max(0, y)).offset(y: -max(0, y))
        }
        .frame(height: height)
    }
}

private struct MonthBody: View {
    @Environment(AppModel.self) private var app
    let month: Int
    var body: some View {
        let c = app.content, mo = c.month(month), m = month
        VStack(alignment: .leading, spacing: 18) {
            // the month at a glance; a point that only names a play is already among the plays below
            let points = mo.highlights.filter { c.play($0.anchor ?? "") == nil }
            if !points.isEmpty {
                Box {
                    ForEach(Array(points.enumerated()), id: \.offset) { i, h in
                        let (sym, col): (String, Color) = h.kind.contains("留意") ? ("exclamationmark.triangle.fill", Crayon.tangerine) : h.kind.contains("先做") ? ("checklist", Crayon.sky) : ("eye.fill", Palette.accent)
                        BoxRow(symbol: sym, color: col, title: h.kind, text: h.text, last: i == points.count - 1)
                    }
                }
            }

            let plays = c.plays(of: m)
            if !plays.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(title: "一起玩", detail: "\(plays.count) 个活动")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(plays) { p in
                            NavigationLink(value: Route.play(p.code, m)) { PlayTile(play: p, did: app.ticked(m, TickKind.did, p.code)) }.buttonStyle(.plain)
                        }
                    }
                }
            }

            Box(title: "六个方面") {
                ForEach(Array(mo.domains.enumerated()), id: \.offset) { i, d in
                    BoxRow(symbol: Palette.areaSymbol(d.key), color: Palette.area(d.key), title: d.name, text: d.text, last: i == mo.domains.count - 1) {
                        if d.key == mo.focus { Text("本月重点").font(.caption.weight(.semibold)).foregroundStyle(Palette.area(d.key)) }
                    }
                }
            }

            if !mo.observe.isEmpty {
                let total = mo.observe.reduce(0) { $0 + $1.items.count }
                Box {
                    NavigationLink(value: Route.observe(m)) {
                        BoxRow(symbol: "eye.fill", color: Crayon.lilac, title: "可以留意", text: "看到了就记下，不是考核", last: true, opens: true) {
                            Text("\(app.count(m, TickKind.observed)) / \(total)").font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if !mo.vaccines.isEmpty || !mo.checkups.isEmpty {
                let n = mo.vaccines.count + mo.checkups.count
                Box(title: "接种与儿保", footer: "以当地接种门诊与儿童保健机构的安排为准。") {
                    ForEach(Array(mo.vaccines.enumerated()), id: \.offset) { i, t in
                        CheckRow(text: t, on: app.ticked(m, TickKind.vaccine, "\(i)"), tag: "接种", last: i == n - 1) { app.toggle(m, TickKind.vaccine, "\(i)", t) }
                    }
                    ForEach(Array(mo.checkups.enumerated()), id: \.offset) { i, t in
                        CheckRow(text: t, on: app.ticked(m, TickKind.checkup, "\(i)"), tag: "儿保", last: mo.vaccines.count + i == n - 1) { app.toggle(m, TickKind.checkup, "\(i)", t) }
                    }
                }
            }

            if !mo.notes.isEmpty {
                Box(title: "还要知道") {
                    ForEach(Array(mo.notes.enumerated()), id: \.offset) { i, n in
                        BoxRow(symbol: "lightbulb.fill", color: Crayon.sunflower, title: n.topic, text: n.text, last: i == mo.notes.count - 1)
                    }
                }
            }

            if !mo.who.isEmpty {
                let parts = mo.who.replacingOccurrences(of: "WHO", with: "").split(whereSeparator: { $0 == "；" || $0 == ";" })
                    .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "。")) }.filter { !$0.isEmpty }
                Box(title: "一天的节奏", footer: "依据世界卫生组织《5 岁以下儿童身体活动、久坐行为和睡眠指南》。") {
                    ForEach(Array(parts.enumerated()), id: \.offset) { i, t in
                        let (sym, col): (String, Color) = t.contains("睡") ? ("moon.fill", Crayon.lilac) : t.contains("屏幕") ? ("iphone", Crayon.pebble)
                            : (t.contains("活动") || t.contains("趴") || t.contains("坐") || t.contains("久")) ? ("figure.walk", Crayon.tangerine) : ("clock.fill", Crayon.aqua)
                        BoxRow(symbol: sym, color: col, title: t, last: i == parts.count - 1)
                    }
                }
            }

            Box(title: "更多") {
                NavigationLink(value: JournalRoute.growth) { BoxRow(symbol: "chart.line.uptrend.xyaxis", color: Crayon.tangerine, title: "生长曲线", opens: true) }.buttonStyle(.plain)
                ForEach(Array(c.topics.enumerated()), id: \.offset) { i, t in
                    NavigationLink(value: Route.topic(t.id)) { BoxRow(symbol: "book.pages.fill", color: Crayon.caramel, title: t.title, last: i == c.topics.count - 1, opens: true) }.buttonStyle(.plain)
                }
            }

            if m == 36 { StoryGoesOn(primary: app.companion) }
        }
    }
}

/// A play in the month's grid: its first picture, its name, its age.
struct PlayTile: View {
    let play: Play
    let did: Bool
    var body: some View {
        let key = Palette.areaKey(of: play)
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                if let f = ArtIndex.shared.steps(play.code).first { ArtFill(name: f).aspectRatio(4 / 3, contentMode: .fit) }
                else { Palette.fill.aspectRatio(4 / 3, contentMode: .fit) }
                if did {
                    Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(.white)
                        .frame(width: 28, height: 28).background(Palette.accent, in: Circle()).padding(8)
                        .accessibilityLabel("这个月做过")
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Label(play.domains.first ?? "", systemImage: Palette.areaSymbol(key)).font(.caption.weight(.semibold)).foregroundStyle(Palette.area(key)).lineLimit(1)
                Text(play.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading).lineLimit(3)
                Text(play.age).font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.area(key).opacity(0.1))
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// What to look out for this month, by area: tick what has been seen.
struct ObserveView: View {
    @Environment(AppModel.self) private var app
    let month: Int
    var body: some View {
        let mo = app.content.month(month)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(mo.observe.enumerated()), id: \.offset) { gi, g in
                    Box(title: g.area) {
                        ForEach(Array(g.items.enumerated()), id: \.offset) { ii, t in
                            CheckRow(text: t, on: app.ticked(month, TickKind.observed, "\(gi)-\(ii)"), last: ii == g.items.count - 1) {
                                app.toggle(month, TickKind.observed, "\(gi)-\(ii)", t)
                            }
                        }
                    }
                }
                Text("每个孩子有自己的节奏。没看到的项目不代表落后；如有疑虑，请咨询儿童保健医生。").font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16)
            }
            .padding(.horizontal, 16).padding(.bottom, 40)
        }
        .background(Palette.background)
        .navigationTitle("可以留意")
        .navigationSubtitle(month == 0 ? "出生" : "满 \(month) 个月")
    }
}
