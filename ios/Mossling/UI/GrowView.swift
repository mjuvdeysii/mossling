import SwiftUI

/// Grow: any month, 0 to 36, read in full. The bead chain stays at the top; the month's cover, points, plays, the six
/// areas, what to look out for, vaccinations and check-ups, notes, the day's rhythm.
struct GrowView: View {
    @Environment(AppModel.self) private var app
    @Binding var path: NavigationPath
    @State private var month: Int? = nil

    var body: some View {
        let m = month ?? app.babyMonth ?? 0
        ScrollViewReader { proxy in
            ScrollView {
                MonthContent(month: m, path: $path).id("top")
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack(spacing: 6) {
                    Button { path.append(Route.search) } label: { Image(systemName: "magnifyingglass").font(.title3).frame(width: 40, height: 40) }
                        .accessibilityLabel("搜索")
                    BeadChain(month: m, baby: app.babyMonth) { k in withAnimation(.snappy) { month = k; proxy.scrollTo("top", anchor: .top) } }
                    Button { path.append(Route.map) } label: {
                        VStack(spacing: 0) { GrowingChild().frame(width: 34, height: 34); Text("地图").font(.caption2) }
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Palette.secondaryContainer, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .foregroundStyle(Palette.onSecondaryContainer)
                    .accessibilityLabel("成长地图")
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(.bar)
            }
        }
        .background(Palette.background)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: app.babyMonth) { _, _ in month = nil }
    }
}

/// One month, as a page. Used by Grow and when a month is opened from elsewhere.
struct MonthContent: View {
    @Environment(AppModel.self) private var app
    let month: Int
    @Binding var path: NavigationPath

    var body: some View {
        let c = app.content, mo = c.month(month), m = month
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                if let f = ArtIndex.shared.cover(m) { ArtView(name: f, label: "满 \(m) 个月：\(mo.title)", radius: 30) }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(m)").font(Typeface.numerals(40, relativeTo: .largeTitle)).foregroundStyle(Palette.primary)
                    Text("个月").font(.headline)
                    if let b = app.babyMonth, b != m { Text(m < b ? " · 以前的月份" : " · 以后的月份").font(.subheadline).foregroundStyle(Palette.secondaryText) }
                }
                .padding(.top, 8)
                Text(mo.title).font(Typeface.serif(22, relativeTo: .title2)).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16).padding(.top, 8)
            .id(m)
            .transition(.opacity)

            // the month at a glance; a point that only names a play is already among the plays below
            VStack(spacing: 8) {
                ForEach(Array(mo.highlights.filter { c.play($0.anchor ?? "") == nil }.enumerated()), id: \.offset) { i, h in
                    let even = i % 2 == 0
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: even ? "eye.fill" : "exclamationmark.shield.fill").font(.body)
                            .frame(width: 36, height: 36).background((even ? Palette.onPrimaryContainer : Palette.onTertiaryContainer).opacity(0.1), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text(h.kind).font(.subheadline.weight(.semibold))
                            Text(h.text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(even ? Palette.onPrimaryContainer : Palette.onTertiaryContainer)
                    .card(even ? Palette.primaryContainer : Palette.tertiaryContainer, radius: 22, padding: 14)
                }
            }
            .padding(.horizontal, 16).padding(.top, 16)

            let plays = c.plays(of: m)
            if !plays.isEmpty {
                SectionHeader(title: "这个月玩什么", kicker: "\(plays.count) 个活动", symbol: "puzzlepiece.fill")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(plays) { p in
                        Button { path.append(Route.play(p.code, m)) } label: { PlayCard(play: p, did: app.ticked(m, TickKind.did, p.code)) }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            SectionHeader(title: "六个方面", kicker: "家里可以这样做", symbol: "circle.hexagongrid.fill")
            VStack(spacing: 8) {
                ForEach(mo.domains, id: \.key) { d in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: Palette.areaSymbol(d.key)).font(.subheadline).foregroundStyle(Palette.area(d.key))
                                .frame(width: 34, height: 34).background(Palette.area(d.key).opacity(0.13), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            Text(d.name).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.area(d.key))
                            if d.key == mo.focus { Text("本月重点").font(.caption2.weight(.semibold)).foregroundStyle(Palette.tertiary)
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Palette.tertiaryContainer, in: Capsule()) }
                        }
                        Text(d.text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    }
                    .card(Palette.cardLow, radius: 20, padding: 14)
                }
            }
            .padding(.horizontal, 16)

            if !mo.observe.isEmpty {
                SectionHeader(title: "可以留意", kicker: "看到了就勾上，不是考核", symbol: "eye.fill", tint: Palette.rod)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(mo.observe.enumerated()), id: \.offset) { gi, g in
                        Text(g.area).font(.footnote.weight(.semibold)).foregroundStyle(Palette.secondaryText).padding(.horizontal, 16).padding(.top, gi == 0 ? 6 : 12)
                        ForEach(Array(g.items.enumerated()), id: \.offset) { ii, t in
                            CheckRow(text: t, on: app.ticked(m, TickKind.observed, "\(gi)-\(ii)")) { app.toggle(m, TickKind.observed, "\(gi)-\(ii)", t) }
                        }
                    }
                }
                .background(Palette.cardLow, in: RoundedRectangle(cornerRadius: 22, style: .continuous)).padding(.horizontal, 16)
            }

            if !mo.vaccines.isEmpty || !mo.checkups.isEmpty {
                SectionHeader(title: "接种与儿保", symbol: "syringe.fill", tint: Palette.red)
                VStack(spacing: 0) {
                    ForEach(Array(mo.vaccines.enumerated()), id: \.offset) { i, t in
                        CheckRow(text: t, on: app.ticked(m, TickKind.vaccine, "\(i)"), tag: "接种") { app.toggle(m, TickKind.vaccine, "\(i)", t) }
                    }
                    ForEach(Array(mo.checkups.enumerated()), id: \.offset) { i, t in
                        CheckRow(text: t, on: app.ticked(m, TickKind.checkup, "\(i)"), tag: "儿保") { app.toggle(m, TickKind.checkup, "\(i)", t) }
                    }
                }
                .background(Palette.cardLow, in: RoundedRectangle(cornerRadius: 22, style: .continuous)).padding(.horizontal, 16)
            }

            if !mo.notes.isEmpty {
                SectionHeader(title: "这个月还要知道", symbol: "lightbulb.fill", tint: Palette.tertiary)
                VStack(spacing: 8) {
                    ForEach(Array(mo.notes.enumerated()), id: \.offset) { _, n in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(n.topic).font(.subheadline.weight(.semibold))
                            Text(rich(n.text)).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        }
                        .card(Palette.cardLow, radius: 20, padding: 14)
                    }
                }
                .padding(.horizontal, 16)
            }

            if !mo.who.isEmpty {
                SectionHeader(title: "一天的节奏", kicker: "睡眠、活动与屏幕", symbol: "sun.max.fill", tint: Palette.tertiary)
                let parts = mo.who.replacingOccurrences(of: "WHO", with: "").split(whereSeparator: { $0 == "；" || $0 == ";" })
                    .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "。")) }.filter { !$0.isEmpty }
                VStack(spacing: 8) {
                    ForEach(parts, id: \.self) { t in
                        let (sym, col): (String, Color) = t.contains("睡") ? ("moon.fill", Palette.rod) : t.contains("屏幕") ? ("iphone", Palette.red)
                            : (t.contains("活动") || t.contains("趴") || t.contains("坐") || t.contains("久")) ? ("figure.walk", Palette.moss) : ("clock.fill", Palette.bead)
                        HStack(spacing: 12) {
                            Image(systemName: sym).foregroundStyle(col).frame(width: 36, height: 36).background(col.opacity(0.13), in: Circle())
                            Text(t).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .card(Palette.cardLow, radius: 20, padding: 12)
                    }
                }
                .padding(.horizontal, 16)
            }

            Button { path.append(JournalRoute.growth) } label: {
                HStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis").foregroundStyle(Palette.onSecondaryContainer).frame(width: 36, height: 36).background(Palette.onSecondaryContainer.opacity(0.1), in: Circle())
                    VStack(alignment: .leading, spacing: 1) { Text("生长曲线").font(.subheadline.weight(.semibold)); Text("体重 · 身长 · 头围").font(.caption) }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                }
                .foregroundStyle(Palette.onSecondaryContainer)
                .card(Palette.secondaryContainer, radius: 20, padding: 12)
            }
            .buttonStyle(.plain).padding(.horizontal, 16).padding(.top, 8)

            if m == 36 { StoryGoesOn(primary: app.companion).padding(.horizontal, 16).padding(.top, 20) }

            if !c.topics.isEmpty {
                SectionHeader(title: "专题", symbol: "book.closed.fill", tint: Palette.tertiary)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(c.topics) { t in
                        Button { path.append(Route.topic(t.id)) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: "book.pages.fill").foregroundStyle(Palette.tertiary)
                                Text(t.title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
                            .card(Palette.cardLow, radius: 20, padding: 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 40)
        .foregroundStyle(Palette.text)
    }
}

struct PlayCard: View {
    @Environment(AppModel.self) private var app
    let play: Play
    let did: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let f = ArtIndex.shared.steps(play.code).first { ArtView(name: f, radius: 14) }
            HStack {
                CodeTile(code: play.code, tint: app.companion.tint, size: 15)
                Spacer()
                if did { Label("做过", systemImage: "checkmark").font(.caption2.weight(.semibold)).foregroundStyle(Palette.primary) }
            }
            Text(play.name).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            Text(play.age).font(.caption).foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .card(Palette.card, radius: 20, padding: 10)
    }
}

/// 0–36 months as golden beads on one string, fitted to the width: tap or drag to choose a month. Nothing scrolls.
struct BeadChain: View {
    let month: Int
    let baby: Int?
    let select: (Int) -> Void
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, gap = w / 37
            Canvas { ctx, size in
                let y = size.height * 0.4
                ctx.stroke(Path { p in p.move(to: CGPoint(x: gap / 2, y: y)); p.addLine(to: CGPoint(x: w - gap / 2, y: y)) }, with: .color(Palette.outline), lineWidth: 1)
                for i in 0...36 {
                    let x = gap * CGFloat(i) + gap / 2
                    let big = i % 12 == 0, sel = i == month
                    let r: CGFloat = sel ? min(gap * 0.7, 9) : big ? min(gap * 0.42, 5) : min(gap * 0.34, 3.6)
                    let col: Color = sel ? Palette.bead : (baby.map { i <= $0 } ?? false) ? Palette.primary : Palette.stone
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(col))
                    if sel { ctx.stroke(Path(ellipseIn: CGRect(x: x - r - 2, y: y - r - 2, width: r * 2 + 4, height: r * 2 + 4)), with: .color(Palette.bead.opacity(0.4)), lineWidth: 2) }
                }
                for (i, t) in [(0, "出生"), (12, "1岁"), (24, "2岁"), (36, "3岁")] {
                    let txt = ctx.resolve(Text(t).font(.system(size: 10)).foregroundStyle(Palette.secondaryText))
                    let x = gap * CGFloat(i) + gap / 2
                    ctx.draw(txt, at: CGPoint(x: min(max(x, 14), w - 14), y: size.height * 0.85))
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let k = max(0, min(36, Int(v.location.x / gap)))
                if k != month { select(k) }
            })
        }
        .frame(height: 40)
        .sensoryFeedback(.selection, trigger: month)
        .accessibilityElement()
        .accessibilityLabel("月份")
        .accessibilityValue("满 \(month) 个月")
        .accessibilityAdjustableAction { d in
            switch d { case .increment: select(min(36, month + 1)); case .decrement: select(max(0, month - 1)); default: break }
        }
    }
}

/// The way into the growth map: a peg child growing from lying down to walking, in a loop.
struct GrowingChild: View {
    @Environment(\.accessibilityReduceMotion) private var reduce
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduce)) { tl in
            Canvas { ctx, size in
                let s = min(size.width, size.height) / 48
                ctx.scaleBy(x: s, y: s)
                ctx.stroke(Path { p in p.move(to: CGPoint(x: 4, y: 42)); p.addLine(to: CGPoint(x: 44, y: 42)) }, with: .color(Palette.stone), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                let v = reduce ? 4.5 : (tl.date.timeIntervalSinceReferenceDate / 0.9).truncatingRemainder(dividingBy: 6)
                let stage = Int(v), f = v - Double(stage)
                let a = f < 0.12 ? 0.25 + 0.75 * f / 0.12 : f > 0.88 ? 0.25 + 0.75 * (1 - f) / 0.12 : 1
                let grow = 0.7 + 0.06 * Double(stage)
                ctx.opacity = reduce ? 1 : a
                let skin = Color(hex: 0xEAC9A1), bodyC = Palette.bead
                func head(_ x: Double, _ y: Double, _ r: Double) { ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(skin)) }
                func peg(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ rot: Double) {
                    var c = ctx; c.translateBy(x: x, y: y); c.rotate(by: .degrees(rot))
                    c.fill(Path(roundedRect: CGRect(x: -w / 2, y: -h, width: w, height: h), cornerRadius: w / 2), with: .color(bodyC))
                }
                switch stage {
                case 0: peg(24, 40, 7 * grow, 16 * grow, -90); head(31 * 1, 37, 5 * grow)            // lying
                case 1: peg(22, 41, 7 * grow, 16 * grow, -80); head(31, 33 - sin(f * .pi) * 2, 5 * grow) // tummy, head up
                case 2: peg(24, 42, 9 * grow, 16 * grow, 0); head(24, 42 - 16 * grow - 5, 5 * grow)  // sitting
                case 3: peg(20 + f * 6, 38, 7 * grow, 17 * grow, -70); head(32 + f * 6, 31, 5 * grow) // crawling
                case 4: peg(24, 42, 8 * grow, 24 * grow, 0); head(24, 42 - 24 * grow - 5, 5 * grow)  // standing
                default: let x = 14 + f * 20; peg(x, 42, 8 * grow, 26 * grow, sin(f * .pi * 6) * 5); head(x, 42 - 26 * grow - 5, 5 * grow) // walking
                }
            }
        }
        .accessibilityHidden(true)
    }
}
