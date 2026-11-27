import SwiftUI
import Charts
import Accessibility

/// Weight, length and head circumference against the WHO Child Growth Standards: the latest of each (tap one to chart
/// it), the chart (3rd–97th and 15th–85th percentile bands, the median, today, the child's own line), every measurement.
struct GrowthView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.lamp) private var lamp
    @State private var ind: Indicator = .weight
    @State private var fullSpan = false
    @State private var picked: Measure?
    @State private var editing: Measure?
    @State private var scrubbingChart = false

    static func measureValue(_ m: Measure, _ i: Indicator) -> Double? {
        switch i {
        case .weight: m.weightG.map { Double($0) / 1000 }
        case .length: m.lengthMm.map { Double($0) / 10 }
        case .head: m.headMm.map { Double($0) / 10 }
        }
    }

    static func delta(for measure: Measure, in all: [Measure], indicator: Indicator) -> Double? {
        guard let cur = measureValue(measure, indicator) else { return nil }
        let chronological = all
            .filter { measureValue($0, indicator) != nil }
            .sorted { $0.at < $1.at }
        guard let idx = chronological.firstIndex(where: { $0.id == measure.id }),
              idx > 0,
              let prev = measureValue(chronological[idx - 1], indicator) else {
            return nil
        }
        return cur - prev
    }

    static func developmentalBirth(for measure: Measure, birth: Day?, gestationalWeeks: Int?) -> Day? {
        guard let birth else { return nil }
        let measureDay = Day(Date(timeIntervalSince1970: measure.at / 1000))
        let chronoAge = Age.on(birth: birth, today: measureDay)
        if let gw = gestationalWeeks, Age.isPreterm(gw), chronoAge.months < 24 {
            return Age.correctedBirth(birth: birth, gestationalWeeks: gw)
        }
        return birth
    }

    static func developmentalMonths(for measure: Measure, birth: Day?, gestationalWeeks: Int?) -> Double? {
        guard let refBirth = developmentalBirth(for: measure, birth: birth, gestationalWeeks: gestationalWeeks) else { return nil }
        let measureDay = Day(Date(timeIntervalSince1970: measure.at / 1000))
        return Double(refBirth.days(to: measureDay)) / 30.4375
    }

    private func value(_ m: Measure, _ i: Indicator) -> Double? { Self.measureValue(m, i) }
    private func months(_ m: Measure) -> Double? {
        Self.developmentalMonths(for: m, birth: app.birth, gestationalWeeks: app.gestationalWeeks)
    }
    private func pct(_ m: Measure, _ i: Indicator) -> Double? {
        guard app.sex != nil, let mo = months(m), mo >= 0, mo <= 36, let v = value(m, i), v > 0 else { return nil }
        let p = app.growth.percentile(i, girl: app.girl, months: mo, value: v)
        return p.isFinite ? p : nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker(L10n.t("指标", "Metric"), selection: $ind) { ForEach(Indicator.allCases) { Text($0.short).tag($0) } }
                    .pickerStyle(.segmented)
                    .onChange(of: ind) { _, _ in picked = nil }
                if app.sex == nil {
                    Card(title: L10n.t("生长曲线按性别区分", "Growth curves differ by sex"), symbol: "person.2.fill", color: Crayon.sky) {
                        HStack {
                            Button(L10n.t("男孩", "Boy")) { if app.mayKeep() { app.sex = "boy" } }.buttonStyle(.vinyl(Crayon.sky))
                            Button(L10n.t("女孩", "Girl")) { if app.mayKeep() { app.sex = "girl" } }.buttonStyle(.vinyl(Crayon.pink))
                        }
                    }
                }
                chartCard
                let all = j.measures
                let activeID = (picked ?? all.filter { value($0, ind) != nil }.last)?.id
                Box(
                    title: L10n.t("成长刻度手账", "Growth Ledger"),
                    detail: all.isEmpty ? nil : L10n.t("\(all.count) 次 · 点行定位曲线", "\(all.count) · Tap to inspect")
                ) {
                    if all.isEmpty {
                        Text(L10n.t("还没有测量记录", "No measurements yet"))
                            .font(.subheadline)
                            .foregroundStyle(Palette.secondaryText)
                            .padding(16)
                    }
                    ForEach(Array(all.reversed().enumerated()), id: \.element.id) { i, m in
                        row(m, all: all, active: m.id == activeID, last: i == all.count - 1)
                            .contextMenu {
                                Button(L10n.t("编辑", "Edit"), systemImage: "pencil") { if app.mayKeep() { editing = m } }
                                Button(L10n.t("删除", "Delete"), systemImage: "trash", role: .destructive) { j.deleteMeasure(m) }
                            }
                    }
                }
                Text(L10n.t(
                    "数据来源：世界卫生组织（WHO）儿童生长标准（2006）。百分位表示在同龄同性别儿童中的位置，不是评分；生长情况以儿童保健医生的评估为准。",
                    "Source: WHO Child Growth Standards (2006). Percentiles show where a measurement falls among peers of the same age and sex — never a score. Always follow your pediatrician's assessment."
                ))
                    .font(.footnote).foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                            .fill(Palette.fill.opacity(0.65))
                    )
            }
            .padding(.horizontal, LayoutSpec.pageH).padding(.bottom, 32)
        }
        .calmWhileScrolling()
        .pageBackground()
        .navigationTitle(L10n.t("生长曲线", "Growth Curve"))
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !j.measures.isEmpty {
                    let who = app.nickname.isEmpty ? L10n.t("宝宝", "Baby") : app.nickname
                    let ageStr = app.age.map { L10n.ageText($0) } ?? ""
                    let currentInd = ind
                    let pts: [(Measure, Double, Double)] = j.measures.compactMap { m in months(m).flatMap { mo in value(m, currentInd).map { (m, mo, $0) } } }
                    let nowMo = app.age.map { Double($0.months) + Double($0.days) / 30.4375 }
                    let autoSpan = min(36.0, max(6.0, max(nowMo ?? 0, pts.map(\.1).max() ?? 0) + 3))
                    let span = fullSpan ? 36.0 : autoSpan
                    let posterItem = RenderedPoster(filename: "moss-otto-growth-\(currentInd.rawValue)") {
                        let poster = GrowthPrintPoster(
                            babyName: who,
                            ageText: ageStr,
                            sex: app.sex,
                            indicator: currentInd,
                            spanMonths: span,
                            measures: j.measures,
                            birth: app.birth,
                            growth: app.growth,
                            gestationalWeeks: app.gestationalWeeks
                        )
                        let renderer = ImageRenderer(content: poster)
                        renderer.scale = 3.0
                        return renderer.uiImage
                    }
                    ShareLink(
                        item: posterItem,
                        preview: SharePreview(L10n.t("\(who) · 生长曲线印画", "\(who) · Growth Curve Print"))
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(L10n.t("分享生长曲线纪念印画", "Share growth curve print"))
                }
                Button(L10n.t("记一次测量", "Log measurement"), systemImage: "plus") {
                    if app.mayKeep() { editing = Measure(at: ms(Date())) }
                }
            }
        }
        .sheet(item: $editing) { m in MeasureSheet(measure: m, isNew: !j.measures.contains { $0.id == m.id }).lampPresented() }
        .sensoryFeedback(.selection, trigger: picked?.id)
        .sensoryFeedback(.selection, trigger: fullSpan)
    }

    private struct Band: Identifiable { var id: String { "\(series)-\(m)" }; let m: Double; let lo: Double; let hi: Double; let series: String }
    private struct Line: Identifiable { var id: String { "\(p)-\(m)" }; let m: Double; let v: Double; let p: Int }

    private var chartCard: some View {
        let g = app.growth, girl = app.girl
        let pts: [(Measure, Double, Double)] = j.measures.compactMap { m in months(m).flatMap { mo in value(m, ind).map { (m, mo, $0) } } }
        let now = app.age.map { Double($0.months) + Double($0.days) / 30.4375 }
        let autoSpan = min(36, max(6, max(now ?? 0, pts.map(\.1).max() ?? 0) + 3))
        let span: Double = fullSpan ? 36 : autoSpan
        let step: Double = span <= 12 ? 0.25 : 0.5
        var xs = stride(from: 0.0, through: span, by: step).map { $0 }
        if (xs.last ?? 0) < span { xs.append(span) }
        let outer = xs.map { Band(m: $0, lo: g.at(ind, girl: girl, months: $0, percentile: 3), hi: g.at(ind, girl: girl, months: $0, percentile: 97), series: "3–97") }
        let inner = xs.map { Band(m: $0, lo: g.at(ind, girl: girl, months: $0, percentile: 15), hi: g.at(ind, girl: girl, months: $0, percentile: 85), series: "15–85") }
        let lines = [3, 50, 97].flatMap { p in xs.map { Line(m: $0, v: g.at(ind, girl: girl, months: $0, percentile: p), p: p) } }
        let lastM = j.measures.filter { value($0, ind) != nil }.last
        return Card(title: ind.label + (app.sex == nil ? "" : girl ? L10n.t(" · 女孩", " · Girl") : L10n.t(" · 男孩", " · Boy")), symbol: ind.symbol, color: ind.tint,
                    detail: lastM.map { L10n.t("最近 ", "Latest ") + Day(Date(timeIntervalSince1970: $0.at / 1000)).md }) {
            HStack(alignment: .bottom, spacing: 8) {
                if let l = lastM, let v = value(l, ind) {
                    VStack(alignment: .leading, spacing: 2) {
                        ValueText(parts: [(ind.fmt(v), ind.unit)], size: 34)
                        if let p = pct(l, ind) {
                            HStack(spacing: 6) {
                                Text(pctText(p)).font(.subheadline).foregroundStyle(Palette.secondaryText)
                                if app.isUsingCorrectedAge {
                                    Text(L10n.t("已按矫正月龄校正", "Corrected age"))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Crayon.ink(Crayon.teal))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Crayon.teal.opacity(0.14)))
                                }
                            }
                        }
                    }
                } else {
                    Text(L10n.t("还没有\(ind.short)记录", "No \(ind.short.lowercased()) logged yet")).font(.subheadline).foregroundStyle(Palette.secondaryText)
                }
                Spacer(minLength: 4)
                if autoSpan < 35 { spanToggle }
            }
            growthChart(span: span, bands: outer + inner, outer: outer, lines: lines, pts: pts, now: now)
            if !pts.isEmpty, let active = picked ?? pts.last?.0, let idx = pts.firstIndex(where: { $0.0.id == active.id }) {
                pickedBar(pts: pts, index: idx)
            }
            WrapLayout(spacing: 14) {
                legend(AnyView(RoundedRectangle(cornerRadius: 3).fill(ind.tint.opacity(0.22)).frame(width: 20, height: 10)), L10n.t("第 15–85 百分位", "15th–85th %ile"))
                legend(AnyView(RoundedRectangle(cornerRadius: 3).fill(ind.tint.opacity(0.10)).frame(width: 20, height: 10)), L10n.t("第 3–97 百分位", "3rd–97th %ile"))
                legend(AnyView(Rectangle().fill(Palette.secondaryText).frame(width: 20, height: 2)), L10n.t("中位数", "Median"))
                legend(AnyView(Circle().fill(ind.tint).frame(width: 8, height: 8)), L10n.t("测量", "Measured"))
            }
        }
    }

    private var spanToggle: some View {
        HStack(spacing: 4) {
            spanChip(L10n.t("当前阶段", "Now"), on: !fullSpan) { withAnimation(.snappy) { fullSpan = false } }
            spanChip(L10n.t("0–36 月", "0–36 mo"), on: fullSpan) { withAnimation(.snappy) { fullSpan = true } }
        }
    }

    private func spanChip(_ title: String, on: Bool, tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(title).font(.caption.weight(on ? .semibold : .regular))
                .foregroundStyle(on ? .white : Palette.secondaryText)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .vinylSurface(on ? Crayon.fill(ind.tint, lamp) : Palette.stone, radius: Radius.chip, strong: on)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func growthChart(span: Double, bands: [Band], outer: [Band], lines: [Line], pts: [(Measure, Double, Double)], now: Double?) -> some View {
        let activeID = (picked ?? pts.last?.0)?.id
        return Chart {
            // smooth vector percentile bands (Catmull-Rom interpolation)
            ForEach(bands) { b in
                AreaMark(x: .value(L10n.t("月龄", "Age"), b.m), yStart: .value(L10n.t("低", "Low"), b.lo), yEnd: .value(L10n.t("高", "High"), b.hi))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value(L10n.t("区间", "Band"), b.series))
            }
            ForEach(lines) { l in
                LineMark(x: .value(L10n.t("月龄", "Age"), l.m), y: .value(L10n.t("值", "Value"), l.v), series: .value(L10n.t("百分位", "Percentile"), "p\(l.p)"))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(l.p == 50 ? Palette.secondaryText : Palette.secondaryText.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: l.p == 50 ? 1.6 : 1, dash: l.p == 50 ? [] : [4, 4]))
            }
            if let now, now <= span {
                RuleMark(x: .value(L10n.t("今天", "Today"), now)).foregroundStyle(ind.tint.opacity(0.6)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .annotation(position: .top, alignment: .center) { Text(L10n.t("今天", "Today")).font(.caption2).foregroundStyle(ind.tint) }
            }
            ForEach(Array(pts.filter { $0.1 >= 0 && $0.1 <= 36 }.enumerated()), id: \.offset) { _, p in
                LineMark(x: .value(L10n.t("月龄", "Age"), p.1), y: .value(L10n.t("值", "Value"), p.2), series: .value(L10n.t("百分位", "Percentile"), "child"))
                    .foregroundStyle(ind.tint).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                PointMark(x: .value(L10n.t("月龄", "Age"), p.1), y: .value(L10n.t("值", "Value"), p.2))
                    .foregroundStyle(ind.tint).symbolSize(activeID == p.0.id ? 120 : 56)
            }
            if let id = activeID, let p = pts.first(where: { $0.0.id == id && $0.1 >= 0 && $0.1 <= 36 }) {
                RuleMark(x: .value(L10n.t("选中", "Selected"), p.1))
                    .foregroundStyle(ind.tint.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [2, 3]))
                PointMark(x: .value(L10n.t("月龄", "Age"), p.1), y: .value(L10n.t("值", "Value"), p.2))
                    .foregroundStyle(.white).symbolSize(26)
            }
        }
        .chartPlotStyle { plotArea in
            plotArea.clipped()
        }
        .chartForegroundStyleScale(["3–97": ind.tint.opacity(0.09), "15–85": ind.tint.opacity(0.15)])
        .chartLegend(.hidden)
        .chartXScale(domain: 0...span)
        .chartYScale(domain: yDomain(outer.map(\.lo) + pts.map(\.2), outer.map(\.hi) + pts.map(\.2)))
        .chartXAxis { AxisMarks(values: .stride(by: span <= 12 ? 2 : 6)) { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text(L10n.t("\(Int(d)) 个月", "\(Int(d))m")) } } } }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { tap in
                                selectNearestPoint(atX: tap.location.x, proxy: proxy, geo: geo, pts: pts)
                            }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 10)
                            .onChanged { g in
                                if !scrubbingChart {
                                    guard abs(g.translation.width) >= abs(g.translation.height) * 0.9 else { return }
                                    scrubbingChart = true
                                }
                                selectNearestPoint(atX: g.location.x, proxy: proxy, geo: geo, pts: pts)
                            }
                            .onEnded { _ in
                                scrubbingChart = false
                            }
                    )
            }
        }
        .frame(height: 260)
        .padding(.top, 14)
        .accessibilityLabel(L10n.t("\(ind.label)曲线，\(pts.count) 个测量点", "\(ind.label) curve, \(pts.count) measurements"))
        .accessibilityChartDescriptor(GrowthAudioGraph(indicator: ind, pts: pts))
    }

    private func selectNearestPoint(atX locationX: CGFloat, proxy: ChartProxy, geo: GeometryProxy, pts: [(Measure, Double, Double)]) {
        guard !pts.isEmpty, let plot = proxy.plotFrame else { return }
        let x = locationX - geo[plot].origin.x
        if let mo: Double = proxy.value(atX: x),
           let nearest = pts.min(by: { abs($0.1 - mo) < abs($1.1 - mo) })?.0,
           picked?.id != nearest.id {
            picked = nearest
            TactileEngine.shared.beadClick()
        }
    }

    private func pickedBar(pts: [(Measure, Double, Double)], index: Int) -> some View {
        let item = pts[index]
        let m = item.0, val = item.2
        let d = Day(Date(timeIntervalSince1970: m.at / 1000))
        let delta: Double? = index > 0 ? val - pts[index - 1].2 : nil
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: d.ymd).font(.subheadline.weight(.semibold))
                if let b = Self.developmentalBirth(for: m, birth: app.birth, gestationalWeeks: app.gestationalWeeks) {
                    let days = b.days(to: d)
                    let ageStr = days >= 0 ? Firsts.age(from: b, to: d) : Firsts.age(from: app.birth ?? b, to: d)
                    Text(verbatim: b != app.birth ? "\(ageStr) · \(L10n.t("矫正", "Corrected"))" : ageStr)
                        .font(.caption).foregroundStyle(Palette.secondaryText)
                }
                Spacer(minLength: 4)
                Button(L10n.t("编辑", "Edit")) { if app.mayKeep() { editing = m } }.font(.caption.weight(.semibold)).foregroundStyle(Palette.accent)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(ind.fmt(val) + " " + ind.unit).font(Typeface.numerals(18, relativeTo: .headline, weight: .bold)).foregroundStyle(Crayon.ink(ind.tint))
                if let dv = delta {
                    Text((dv >= 0 ? "+" : "") + ind.fmt(dv))
                        .font(.caption.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(Crayon.ink(ind.tint))
                }
                if let p = pct(m, ind) {
                    Text("· " + pctText(p)).font(.caption).foregroundStyle(Palette.secondaryText).lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            if pts.count > 1 {
                HStack {
                    Button { picked = pts[max(0, index - 1)].0 } label: { Label(L10n.t("上一次", "Previous"), systemImage: "chevron.left").font(.caption.weight(.semibold)) }
                        .disabled(index == 0)
                    Spacer()
                    Text("\(index + 1) / \(pts.count)").font(.caption2).foregroundStyle(Palette.secondaryText).monospacedDigit()
                    Spacer()
                    Button { picked = pts[min(pts.count - 1, index + 1)].0 } label: {
                        HStack(spacing: 3) { Text(L10n.t("下一次", "Next")); Image(systemName: "chevron.right") }.font(.caption.weight(.semibold))
                    }
                    .disabled(index == pts.count - 1)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .vinylSurface(ind.tint, radius: Radius.inner)
    }

    private func yDomain(_ lo: [Double], _ hi: [Double]) -> ClosedRange<Double> {
        let a = lo.min() ?? 0, b = hi.max() ?? 1, pad = (b - a) * 0.04
        return (a - pad)...(b + pad)
    }

    private func legend(_ v: AnyView, _ t: String) -> some View { HStack(spacing: 5) { v; Text(t).font(.caption2).foregroundStyle(Palette.secondaryText) } }

    private func row(_ m: Measure, all: [Measure], active: Bool, last: Bool) -> some View {
        let d = Day(Date(timeIntervalSince1970: m.at / 1000))
        let others = Indicator.allCases.filter { $0 != ind && value(m, $0) != nil }
        let tintInk = lamp ? ind.tint : Crayon.ink(ind.tint)

        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                    // Header: date + age capsule (taps select on chart) + trailing Edit button
                    HStack(alignment: .center, spacing: 8) {
                        Button {
                            TactileEngine.shared.beadClick()
                            withAnimation(.snappy) { picked = m }
                        } label: {
                            HStack(alignment: .center, spacing: 8) {
                                Text(verbatim: d.ymd)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if let b = Self.developmentalBirth(for: m, birth: app.birth, gestationalWeeks: app.gestationalWeeks) {
                                    let days = b.days(to: d)
                                    let ageStr = days >= 0 ? Firsts.age(from: b, to: d) : Firsts.age(from: app.birth ?? b, to: d)
                                    Text(verbatim: b != app.birth ? "\(ageStr) · \(L10n.t("矫正", "Corrected"))" : ageStr)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Palette.secondaryText)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Palette.fill.opacity(0.8)))
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Button {
                            if app.mayKeep() {
                                TactileEngine.shared.beadClick()
                                editing = m
                            }
                        } label: {
                            Image(systemName: "pencil")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.accent)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Palette.accent.opacity(lamp ? 0.18 : 0.10)))
                        }
                        .buttonStyle(.toy)
                        .accessibilityLabel(L10n.t("编辑这次测量", "Edit measurement"))
                    }

                    // Active metric hero value + delta badge + percentile (taps select on chart)
                    Button {
                        TactileEngine.shared.beadClick()
                        withAnimation(.snappy) { picked = m }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            if let v = value(m, ind) {
                                Text(ind.fmt(v) + " " + ind.unitShort)
                                    .font(Typeface.numerals(20, relativeTo: .title3, weight: .bold))
                                    .foregroundStyle(tintInk)
                                if let dv = Self.delta(for: m, in: all, indicator: ind) {
                                    Text((dv >= 0 ? "+" : "") + ind.fmt(dv))
                                        .font(.caption.weight(.bold))
                                        .monospacedDigit()
                                        .foregroundStyle(tintInk)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(ind.tint.opacity(lamp ? 0.24 : 0.15)))
                                }
                                if let p = pct(m, ind) {
                                    Text(pctText(p))
                                        .font(.caption)
                                        .foregroundStyle(Palette.secondaryText)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            } else {
                                Text(L10n.t("未记录\(ind.short)", "No \(ind.short.lowercased())"))
                                    .font(.caption)
                                    .foregroundStyle(Palette.secondaryText)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    // Secondary metrics chips (tap to switch active curve AND focus this measurement)
                    if !others.isEmpty {
                        WrapLayout(spacing: 6) {
                            ForEach(others) { other in
                                if let ov = value(m, other) {
                                    Button {
                                        TactileEngine.shared.beadClick()
                                        withAnimation(.snappy) {
                                            ind = other
                                            picked = m
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Circle().fill(other.tint).frame(width: 6, height: 6)
                                            Text(other.short).foregroundStyle(Palette.secondaryText)
                                            Text(other.fmt(ov) + " " + other.unitShort)
                                                .fontWeight(.semibold)
                                                .monospacedDigit()
                                                .foregroundStyle(.primary)
                                        }
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(other.tint.opacity(lamp ? 0.14 : 0.09)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
            }
            .padding(.leading, 18)
            .padding(.trailing, 14)
            .padding(.vertical, 10)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(active ? ind.tint : .clear)
                    .frame(width: 3.5)
                    .padding(.vertical, 8)
                    .padding(.leading, 6)
            }
            .background(active ? ind.tint.opacity(lamp ? 0.14 : 0.08) : .clear)

            if !last { Divider().padding(.leading, 16) }
        }
    }
}

/// Circadian rhythm dial + the last seven days: feeds, sleep and nappies per day.
struct StatsView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.dynamicTypeSize) private var type
    var body: some View {
        let rows = week()
        ScrollView {
            // two small charts to a row (one at the largest text sizes): the week of every kind in one screen; when the
            // count is odd the last one takes the whole row, so no half row stands empty
            let charts = Self.charts(rows)
            // each chart the page's whole width: a week of days needs the width to name them
            let per = 1
            VStack(spacing: 14) {
                RhythmDialCard()
                ForEach(Array(stride(from: 0, to: charts.count, by: per)), id: \.self) { i in
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(i..<min(i + per, charts.count), id: \.self) { k in
                            chart(charts[k]).frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, LayoutSpec.pageH).padding(.bottom, 8)
            Text(L10n.t(
                "每格是一天，最右是今天；数字是有记录的整天的平均（今天还没过完，不算在内）。",
                "Each bar is one day, ending with today on the right. Daily averages use completed days with logs (today is still in progress)."
            )).font(.caption).foregroundStyle(Palette.secondaryText)
                .padding(.horizontal, 20).padding(.bottom, 32).frame(maxWidth: .infinity, alignment: .leading)
        }
        .calmWhileScrolling()
        .pageBackground()
        .navigationTitle(L10n.t("昼夜节律", "Rhythm & Week"))
    }
    /// Each of the last seven days: feeds, hours asleep, nappies, minutes at the breast (pauses left out), bottle ml.
    private func week() -> [(Day, Int, Double, Int, Double, Double)] {
        var out: [(Day, Int, Double, Int, Double, Double)] = []
        for back in stride(from: 6, through: 0, by: -1) {
            let d: Day = app.today.plus(days: -back)
            let l = j.logs(on: d)
            let feeds: Int = l.feedCount(from: d.date.timeIntervalSince1970 * 1000)
            let sleep: Double = l.filter { $0.type == LogType.sleep }.reduce(0.0) { $0 + $1.seconds(on: d) } / 3600
            let nappies: Int = l.filter { $0.type == LogType.diaper && !$0.carriedOver(into: d) }.count
            let nursed: Double = l.filter { $0.type == LogType.nurse && $0.end != nil }.reduce(0.0) { $0 + $1.seconds(on: d) } / 60
            let ml: Int = l.filter { $0.type == LogType.bottle && !$0.carriedOver(into: d) }.reduce(0) { $0 + ($1.amount ?? 0) }
            out.append((d, feeds, sleep, nappies, nursed, Double(ml)))
        }
        return out
    }
    fileprivate enum Scale { case count, minutes, hours }
    private struct Spec { let title: String; let unit: String; let scale: Scale; let type: String; let data: [(Day, Double)] }
    /// The charts there is something for: feeds, minutes at the breast and bottle millilitres when any were recorded,
    /// sleep, nappies.
    private static func charts(_ rows: [(Day, Int, Double, Int, Double, Double)]) -> [Spec] {
        var out: [Spec] = []
        out.append(Spec(title: L10n.t("喂奶", "Feeds"), unit: L10n.t("次", "feeds"), scale: .count, type: LogType.nurse, data: rows.map { ($0.0, Double($0.1)) }))
        if rows.contains(where: { $0.4 > 0 }) { out.append(Spec(title: L10n.t("亲喂时长", "Nursing Time"), unit: L10n.t("分钟", "min"), scale: .minutes, type: LogType.nurse, data: rows.map { ($0.0, $0.4) })) }
        if rows.contains(where: { $0.5 > 0 }) { out.append(Spec(title: L10n.t("瓶喂奶量", "Bottle Volume"), unit: L10n.t("毫升", "ml"), scale: .count, type: LogType.bottle, data: rows.map { ($0.0, $0.5) })) }
        out.append(Spec(title: L10n.t("睡眠", "Sleep"), unit: L10n.t("小时", "hr"), scale: .hours, type: LogType.sleep, data: rows.map { ($0.0, $0.2) }))
        out.append(Spec(title: L10n.t("尿布", "Diapers"), unit: L10n.t("片", "changes"), scale: .count, type: LogType.diaper, data: rows.map { ($0.0, Double($0.3)) }))
        return out
    }
    private func chart(_ spec: Spec) -> some View {
        let t = spec.title, unit = spec.unit, type = spec.type, data = spec.data
        // the average is of whole days: today, still going, is left out (unless it is the only day there is)
        let had = data.filter { $0.1 > 0 && $0.0 != app.today }
        let avg = had.isEmpty ? 0 : had.map(\.1).reduce(0, +) / Double(had.count)
        let cardTitle = L10n.isEnglish ? "\(t) (\(unit))" : "\(t)（\(unit)）"
        return Card(title: cardTitle, symbol: LogType.symbol(type), color: LogType.color(type)) {
            StatHead(unit: unit, scale: spec.scale, avg: avg, days: had.count, today: data.first { $0.0 == app.today }?.1 ?? 0)
            Chart(data, id: \.0) { d in
                BarMark(x: .value(L10n.t("日", "Day"), d.0 == app.today ? L10n.t("今天", "Today") : "\(d.0.m)/\(d.0.d)"), y: .value(t, d.1))
                    .foregroundStyle(LogType.color(type).opacity(d.0 == app.today ? 1 : 0.55).gradient).cornerRadius(4)
            }
            // the day under each bar (a week's bars read without counting along them); today named
            .chartXAxis { AxisMarks { v in AxisValueLabel { if let t = v.as(String.self) { Text(t).font(.caption2).lineLimit(1).minimumScaleFactor(0.75) } } } }
            .chartYAxis {
                // counts in whole numbers only (no "0.5 次")
                AxisMarks(position: .trailing) { v in
                    AxisGridLine()
                    if let d = v.as(Double.self), spec.scale == .hours || d == d.rounded() {
                        // minutes and millilitres are whole numbers already
                        AxisValueLabel { Text(spec.scale == .hours ? String(format: "%g", d) : "\(Int(d))") }
                    }
                }
            }
            .frame(height: 98)
        }
    }
}

/// A week's card head: the conclusion first — 「日均 2 小时」 over the whole days that have records (how many, said
/// under it) — and today's own figure beside it, never in its place. With no whole day yet, today's figure alone.
private struct StatHead: View {
    let unit: String
    let scale: StatsView.Scale
    let avg: Double
    let days: Int
    let today: Double
    private func value(_ v: Double) -> String {
        switch scale {
        case .hours: return durationValue(v * 3600)
        case .minutes: return durationValue(v * 60)
        case .count: return String(format: "%.0f", v) + " " + unit
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if days == 0 {
                Text(L10n.t("今天 ", "Today ") + value(today)).font(Typeface.numerals(18, relativeTo: .headline, weight: .bold))
                Text(L10n.t("满一整天后显示日均", "Daily average appears after a full day")).font(.caption2).foregroundStyle(Palette.secondaryText)
            } else {
                Text(L10n.t("日均 ", "Avg ") + value(avg)).font(Typeface.numerals(18, relativeTo: .headline, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(L10n.isEnglish
                     ? "Across \(days) logged \(days == 1 ? "day" : "days")" + (today > 0 ? " · Today " + value(today) : "")
                     : "按有记录的 \(days) 天" + (today > 0 ? " · 今天 " + value(today) : ""))
                    .font(.caption2).foregroundStyle(Palette.secondaryText).monospacedDigit()
            }
        }
    }
}

/// High-resolution offline 3× cotton-paper Growth Trajectory Keepsake Print rendered via ImageRenderer.
struct GrowthPrintPoster: View {
    let babyName: String
    let ageText: String
    let sex: String?
    let indicator: Indicator
    let spanMonths: Double
    let measures: [Measure]
    let birth: Day?
    let growth: Growth
    var gestationalWeeks: Int? = nil

    private func value(_ m: Measure, _ i: Indicator) -> Double? {
        MeasureParser.value(in: m, for: i)
    }

    private func latest(_ i: Indicator) -> (Measure, Double)? {
        for m in measures.reversed() {
            if let v = value(m, i) { return (m, v) }
        }
        return nil
    }

    var body: some View {
        let paper = Color(red: 0xFB / 255, green: 0xF7 / 255, blue: 0xF0 / 255)
        let ink = Color(red: 0x24 / 255, green: 0x1F / 255, blue: 0x1B / 255)
        let teal = Color(red: 0x0B / 255, green: 0x7D / 255, blue: 0x74 / 255)
        let girl = sex == "girl"
        let sexLabel = sex == nil ? "" : (girl ? L10n.t(" · 女孩", " · Girl") : L10n.t(" · 男孩", " · Boy"))

        let pts: [(Double, Double)] = measures.compactMap { m in
            guard let mo = GrowthView.developmentalMonths(for: m, birth: birth, gestationalWeeks: gestationalWeeks),
                  let v = value(m, indicator),
                  mo >= 0, mo <= spanMonths else { return nil }
            return (mo, v)
        }

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(babyName + (ageText.isEmpty ? "" : " · " + ageText) + sexLabel)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink.opacity(0.62))
                    Text(indicator.label + L10n.t("生长曲线", " Growth Curve"))
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(teal)
                }
                Spacer()
                Text(Day.today.md)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.5))
            }

            // Latest 3-metric strip
            HStack(spacing: 8) {
                ForEach(Indicator.allCases) { i in
                    let latestVal = latest(i)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(i.short)
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundStyle(ink.opacity(0.55))
                        if let (_, v) = latestVal {
                            Text("\(i.fmt(v)) \(i.unitShort)")
                                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                .foregroundStyle(i == indicator ? teal : ink)
                                .monospacedDigit()
                        } else {
                            Text("—")
                                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                .foregroundStyle(ink.opacity(0.35))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(i == indicator ? teal.opacity(0.35) : ink.opacity(0.06), lineWidth: 1))
                }
            }

            // Crisp vector WHO percentile bands + child trajectory
            Canvas { ctx, size in
                let padL: CGFloat = 32, padR: CGFloat = 10, padT: CGFloat = 10, padB: CGFloat = 22
                let w = max(1, size.width - padL - padR)
                let h = max(1, size.height - padT - padB)

                let steps = 48
                let xs = (0...steps).map { Double($0) / Double(steps) * spanMonths }
                let p3 = xs.map { growth.at(indicator, girl: girl, months: $0, percentile: 3) }
                let p15 = xs.map { growth.at(indicator, girl: girl, months: $0, percentile: 15) }
                let p50 = xs.map { growth.at(indicator, girl: girl, months: $0, percentile: 50) }
                let p85 = xs.map { growth.at(indicator, girl: girl, months: $0, percentile: 85) }
                let p97 = xs.map { growth.at(indicator, girl: girl, months: $0, percentile: 97) }

                let allY = p3 + p97 + pts.map(\.1)
                let lo = (allY.min() ?? 0)
                let hi = (allY.max() ?? 1)
                let yPad = max(0.2, (hi - lo) * 0.06)
                let yMin = lo - yPad
                let yMax = hi + yPad

                func pt(_ mo: Double, _ val: Double) -> CGPoint {
                    let x = padL + CGFloat(mo / max(1, spanMonths)) * w
                    let y = padT + h - CGFloat((val - yMin) / max(0.001, yMax - yMin)) * h
                    return CGPoint(x: x, y: y)
                }

                func bandPath(_ low: [Double], _ high: [Double]) -> Path {
                    var p = Path()
                    for (i, m) in xs.enumerated() {
                        let c = pt(m, high[i])
                        if i == 0 { p.move(to: c) } else { p.addLine(to: c) }
                    }
                    for (i, m) in xs.enumerated().reversed() {
                        p.addLine(to: pt(m, low[i]))
                    }
                    p.closeSubpath()
                    return p
                }

                // Gridlines
                let tickMo = spanMonths <= 12 ? 2.0 : 6.0
                var m = 0.0
                while m <= spanMonths + 1e-6 {
                    let x = pt(m, yMin).x
                    var gp = Path()
                    gp.move(to: CGPoint(x: x, y: padT))
                    gp.addLine(to: CGPoint(x: x, y: padT + h))
                    ctx.stroke(gp, with: .color(ink.opacity(0.07)), lineWidth: 0.75)
                    let label = ctx.resolve(Text(L10n.t("\(Int(m))m", "\(Int(m))m")).font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(ink.opacity(0.5)))
                    ctx.draw(label, at: CGPoint(x: x, y: padT + h + 11), anchor: .center)
                    m += tickMo
                }

                ctx.fill(bandPath(p3, p97), with: .color(indicator.tint.opacity(0.12)))
                ctx.fill(bandPath(p15, p85), with: .color(indicator.tint.opacity(0.18)))

                var med = Path()
                for (i, mo) in xs.enumerated() {
                    let c = pt(mo, p50[i])
                    if i == 0 { med.move(to: c) } else { med.addLine(to: c) }
                }
                ctx.stroke(med, with: .color(ink.opacity(0.45)), style: StrokeStyle(lineWidth: 1.4, dash: [4, 3]))

                if !pts.isEmpty {
                    var traj = Path()
                    for (i, item) in pts.enumerated() {
                        let c = pt(item.0, item.1)
                        if i == 0 { traj.move(to: c) } else { traj.addLine(to: c) }
                    }
                    ctx.stroke(traj, with: .color(indicator.tint), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    for item in pts {
                        let c = pt(item.0, item.1)
                        let r = CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)
                        ctx.fill(Path(ellipseIn: r), with: .color(indicator.tint))
                        ctx.stroke(Path(ellipseIn: r), with: .color(.white), lineWidth: 1.4)
                    }
                }

                let loLbl = ctx.resolve(Text(indicator.fmt(lo)).font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(ink.opacity(0.5)))
                let hiLbl = ctx.resolve(Text(indicator.fmt(hi)).font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(ink.opacity(0.5)))
                ctx.draw(loLbl, at: CGPoint(x: padL - 4, y: padT + h), anchor: .trailing)
                ctx.draw(hiLbl, at: CGPoint(x: padL - 4, y: padT + 4), anchor: .trailing)
            }
            .frame(width: 312, height: 196)
            .padding(8)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(L10n.t("参考标准：WHO（2006）第 3–97 / 15–85 百分位与中位数 · 仅作参考，不作评分", "Reference: WHO (2006) 3rd–97th & 15th–85th %ile bands and median · Never a score"))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(ink.opacity(0.56))

            Divider().opacity(0.3)

            HStack {
                Text(L10n.t("摸索台灯 · 孩子摸索，大人点灯", "Moss & Otto · They explore. You hold the light."))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.55))
                Spacer()
            }
        }
        .padding(24)
        .frame(width: 360)
        .background(paper)
    }
}

/// Audio Graph accessibility descriptor so VoiceOver users can explore growth curves audibly by month & value.
private struct GrowthAudioGraph: AXChartDescriptorRepresentable {
    let indicator: Indicator
    let pts: [(Measure, Double, Double)]

    func makeChartDescriptor() -> AXChartDescriptor {
        let maxMonth = max(6.0, (pts.map(\.1).max() ?? 6.0).rounded(.up))
        let vals = pts.map(\.2)
        let lo = max(0.0, (vals.min() ?? 0.0) - 0.5)
        let hi = max(lo + 1.0, (vals.max() ?? 10.0) + 0.5)

        let xAxis = AXNumericDataAxisDescriptor(
            title: L10n.t("月龄（月）", "Age (months)"),
            range: 0...maxMonth,
            gridlinePositions: []
        ) { mo in
            L10n.t(String(format: "%.1f 个月", mo), String(format: "%.1f mo", mo))
        }

        let yAxis = AXNumericDataAxisDescriptor(
            title: "\(indicator.label) (\(indicator.unit))",
            range: lo...hi,
            gridlinePositions: []
        ) { val in
            "\(indicator.fmt(val)) \(indicator.unit)"
        }

        let dataPoints = pts.map { _, mo, val in
            AXDataPoint(
                x: mo,
                y: val,
                label: L10n.t(
                    String(format: "%.1f 个月，%@ %@", mo, indicator.fmt(val), indicator.unit),
                    String(format: "%.1f mo, %@ %@", mo, indicator.fmt(val), indicator.unit)
                )
            )
        }

        let series = AXDataSeriesDescriptor(
            name: indicator.label,
            isContinuous: pts.count > 1,
            dataPoints: dataPoints
        )

        return AXChartDescriptor(
            title: indicator.label + L10n.t("生长曲线", " Growth Curve"),
            summary: L10n.t("共 \(pts.count) 次测量记录", "\(pts.count) measurements recorded"),
            xAxis: xAxis,
            yAxis: yAxis,
            series: [series]
        )
    }
}
