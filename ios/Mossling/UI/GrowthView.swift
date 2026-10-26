import SwiftUI
import Charts

/// Weight, length and head circumference against the WHO Child Growth Standards: the latest of each (tap one to chart
/// it), the chart (3rd–97th and 15th–85th percentile bands, the median, today, the child's own line), every measurement.
struct GrowthView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @State private var ind: Indicator = .weight
    @State private var picked: Measure?
    @State private var editing: Measure?

    private func value(_ m: Measure, _ i: Indicator) -> Double? {
        switch i { case .weight: m.weightG.map { Double($0) / 1000 }; case .length: m.lengthMm.map { Double($0) / 10 }; case .head: m.headMm.map { Double($0) / 10 } }
    }
    private func months(_ m: Measure) -> Double? { app.birth.map { Double($0.days(to: Day(Date(timeIntervalSince1970: m.at / 1000)))) / 30.4375 } }
    private func pct(_ m: Measure, _ i: Indicator) -> Double? {
        guard app.sex != nil, let mo = months(m), let v = value(m, i) else { return nil }
        return app.growth.percentile(i, girl: app.girl, months: mo, value: v)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("指标", selection: $ind) { ForEach(Indicator.allCases) { Text($0.short).tag($0) } }
                    .pickerStyle(.segmented)
                    .onChange(of: ind) { _, _ in picked = nil }
                if app.sex == nil {
                    Card(title: "生长曲线按性别区分", symbol: "person.2.fill", color: Crayon.sky) {
                        HStack { Button("男孩") { app.sex = "boy" }; Button("女孩") { app.sex = "girl" } }.buttonStyle(.bordered)
                    }
                }
                chartCard
                Box(title: "每一次测量", detail: j.measures.isEmpty ? nil : "\(j.measures.count) 次") {
                    let all = j.measures
                    if all.isEmpty { Text("还没有测量记录").font(.subheadline).foregroundStyle(Palette.secondaryText).padding(16) }
                    ForEach(Array(all.reversed().enumerated()), id: \.element.id) { i, m in
                        Button { editing = m } label: { row(m, last: i == all.count - 1) }.buttonStyle(.plain)
                            .contextMenu { Button("删除", systemImage: "trash", role: .destructive) { j.deleteMeasure(m) } }
                    }
                }
                Text("数据来源：世界卫生组织（WHO）儿童生长标准（2006）。百分位表示在同龄同性别儿童中的位置，不是评分；生长情况以儿童保健医生的评估为准。")
                    .font(.footnote).foregroundStyle(Palette.secondaryText).padding(.horizontal, 16)
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle("生长曲线")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("记一次测量", systemImage: "plus") { editing = Measure(at: ms(Date())) } }
        }
        .sheet(item: $editing) { m in MeasureSheet(measure: m, isNew: !j.measures.contains { $0.id == m.id }).lampPresented() }
    }

    private struct Band: Identifiable { let id = UUID(); let m: Double; let lo: Double; let hi: Double; let series: String }
    private struct Line: Identifiable { let id = UUID(); let m: Double; let v: Double; let p: Int }

    private var chartCard: some View {
        let g = app.growth, girl = app.girl
        let pts: [(Measure, Double, Double)] = j.measures.compactMap { m in months(m).flatMap { mo in value(m, ind).map { (m, mo, $0) } } }
        let now = app.age.map { Double($0.months) + Double($0.days) / 30.4375 }
        let span = min(36, max(6, max(now ?? 0, pts.map(\.1).max() ?? 0) + 3))
        let xs = stride(from: 0.0, through: span, by: 0.1).map { $0 }
        let mid = xs.dropLast().map { $0 + 0.05 }
        let outer = mid.map { m in Band(m: m - 0.05, lo: g.at(ind, girl: girl, months: m, percentile: 3), hi: g.at(ind, girl: girl, months: m, percentile: 97), series: "3–97") }
        let inner = mid.map { m in Band(m: m - 0.05, lo: g.at(ind, girl: girl, months: m, percentile: 15), hi: g.at(ind, girl: girl, months: m, percentile: 85), series: "15–85") }
        let lines = [3, 50, 97].flatMap { p in xs.map { Line(m: $0, v: g.at(ind, girl: girl, months: $0, percentile: p), p: p) } }
        let lastM = j.measures.filter { value($0, ind) != nil }.last
        return Card(title: ind.label + (app.sex == nil ? "" : girl ? " · 女孩" : " · 男孩"), symbol: ind.symbol, color: ind.tint,
                    detail: lastM.map { "最近 " + Day(Date(timeIntervalSince1970: $0.at / 1000)).md }) {
            if let l = lastM, let v = value(l, ind) {
                VStack(alignment: .leading, spacing: 2) {
                    ValueText(parts: [(ind.fmt(v), ind.unit)], size: 34)
                    if let p = pct(l, ind) { Text(pctText(p)).font(.subheadline).foregroundStyle(Palette.secondaryText) }
                }
            } else {
                Text("还没有\(ind.short)记录").font(.subheadline).foregroundStyle(Palette.secondaryText)
            }
            Chart {
                // the bands, as thin slices (a tenth of a month each)
                ForEach(outer) { b in RectangleMark(xStart: .value("月龄", b.m), xEnd: .value("月龄", min(span, b.m + 0.1)), yStart: .value("低", b.lo), yEnd: .value("高", b.hi)).foregroundStyle(ind.tint.opacity(0.09)) }
                ForEach(inner) { b in RectangleMark(xStart: .value("月龄", b.m), xEnd: .value("月龄", min(span, b.m + 0.1)), yStart: .value("低", b.lo), yEnd: .value("高", b.hi)).foregroundStyle(ind.tint.opacity(0.13)) }
                ForEach(lines) { l in
                    LineMark(x: .value("月龄", l.m), y: .value("值", l.v), series: .value("百分位", "p\(l.p)"))
                        .foregroundStyle(l.p == 50 ? Palette.secondaryText : Palette.secondaryText.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: l.p == 50 ? 1.6 : 1, dash: l.p == 50 ? [] : [4, 4]))
                }
                if let now, now <= span {
                    RuleMark(x: .value("今天", now)).foregroundStyle(ind.tint.opacity(0.6)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .annotation(position: .top, alignment: .center) { Text("今天").font(.caption2).foregroundStyle(ind.tint) }
                }
                ForEach(Array(pts.enumerated()), id: \.offset) { _, p in
                    LineMark(x: .value("月龄", p.1), y: .value("值", p.2), series: .value("百分位", "child")).foregroundStyle(ind.tint).lineStyle(StrokeStyle(lineWidth: 2.4))
                    PointMark(x: .value("月龄", p.1), y: .value("值", p.2)).foregroundStyle(ind.tint).symbolSize(picked?.id == p.0.id ? 140 : 60)
                }
                if let m = picked, let p = pts.first(where: { $0.0.id == m.id }) {
                    PointMark(x: .value("月龄", p.1), y: .value("值", p.2)).foregroundStyle(.clear)
                        .annotation(position: .top) {
                            Text("\(Day(Date(timeIntervalSince1970: m.at / 1000)).md) · \(ind.fmt(p.2)) \(ind.unit)").font(.caption.weight(.semibold)).monospacedDigit()
                                .padding(.horizontal, 8).padding(.vertical, 4).background(.regularMaterial, in: Capsule())
                        }
                }
            }
            .chartXScale(domain: 0...span)
            .chartYScale(domain: yDomain(outer.map(\.lo) + pts.map(\.2), outer.map(\.hi) + pts.map(\.2)))
            .chartXAxis { AxisMarks(values: .stride(by: span <= 12 ? 2 : 6)) { v in AxisGridLine(); AxisValueLabel { if let d = v.as(Double.self) { Text("\(Int(d))月") } } } }
            .chartYAxis { AxisMarks(position: .leading) }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle().fill(.clear).contentShape(Rectangle()).onTapGesture { loc in
                        guard let plot = proxy.plotFrame else { return }
                        let x = loc.x - geo[plot].origin.x
                        if let mo: Double = proxy.value(atX: x) { picked = pts.min(by: { abs($0.1 - mo) < abs($1.1 - mo) })?.0 }
                    }
                }
            }
            .frame(height: 260)
            .accessibilityLabel("\(ind.label)曲线，\(pts.count) 个测量点")
            WrapLayout(spacing: 14) {
                legend(AnyView(RoundedRectangle(cornerRadius: 3).fill(ind.tint.opacity(0.2)).frame(width: 20, height: 10)), "第 15–85 百分位")
                legend(AnyView(RoundedRectangle(cornerRadius: 3).fill(ind.tint.opacity(0.09)).frame(width: 20, height: 10)), "第 3–97 百分位")
                legend(AnyView(Rectangle().fill(Palette.secondaryText).frame(width: 20, height: 2)), "中位数")
                legend(AnyView(Circle().fill(ind.tint).frame(width: 8, height: 8)), "测量")
            }
        }
    }

    private func yDomain(_ lo: [Double], _ hi: [Double]) -> ClosedRange<Double> {
        let a = lo.min() ?? 0, b = hi.max() ?? 1, pad = (b - a) * 0.04
        return (a - pad)...(b + pad)
    }

    private func legend(_ v: AnyView, _ t: String) -> some View { HStack(spacing: 5) { v; Text(t).font(.caption2).foregroundStyle(Palette.secondaryText) } }

    private func row(_ m: Measure, last: Bool) -> some View {
        let d = Day(Date(timeIntervalSince1970: m.at / 1000))
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "\(d.y)年\(d.md)").font(.body)
                    if let b = app.birth { let a = Age.on(birth: b, today: d); Text(verbatim: a.months == 0 ? "出生第 \(a.lived) 天" : a.days == 0 ? "满 \(a.months) 个月" : "\(a.months) 个月 \(a.days) 天").font(.subheadline).foregroundStyle(Palette.secondaryText) }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    ForEach(Indicator.allCases) { x in
                        if let v = value(m, x) {
                            HStack(spacing: 3) { Text(x.fmt(v)).font(Typeface.numerals(16, weight: x == ind ? .bold : .regular)); Text(x.unitShort).font(.caption).foregroundStyle(Palette.secondaryText) }
                                .foregroundStyle(x == ind ? x.tint : .primary)
                        }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .contentShape(Rectangle())
            if !last { Divider().padding(.leading, 16) }
        }
    }
}

/// The last seven days: feeds, sleep and nappies per day.
struct StatsView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    var body: some View {
        let days = (0..<7).reversed().map { app.today.plus(days: -$0) }
        let rows = days.map { d -> (Day, Int, Double, Int, Double, Double) in
            let l = j.logs(on: d)
            return (d, l.feedCount(from: d.date.timeIntervalSince1970 * 1000),
                    l.filter { $0.type == LogType.sleep }.reduce(0.0) { $0 + $1.seconds(on: d) } / 3600,
                    l.filter { $0.type == LogType.diaper && !$0.carriedOver(into: d) }.count,
                    // minutes on the breast (pauses left out) and millilitres from the bottle
                    l.filter { $0.type == LogType.nurse && $0.end != nil }.reduce(0.0) { $0 + $1.seconds(on: d) } / 60,
                    Double(l.filter { $0.type == LogType.bottle && !$0.carriedOver(into: d) }.reduce(0) { $0 + ($1.amount ?? 0) }))
        }
        ScrollView {
            VStack(spacing: 14) {
                chart("喂奶", "次", LogType.nurse, rows.map { ($0.0, Double($0.1)) })
                if rows.contains(where: { $0.4 > 0 }) { chart("亲喂时长", "分钟", LogType.nurse, rows.map { ($0.0, $0.4) }) }
                if rows.contains(where: { $0.5 > 0 }) { chart("瓶喂奶量", "毫升", LogType.bottle, rows.map { ($0.0, $0.5) }) }
                chart("睡眠", "小时", LogType.sleep, rows.map { ($0.0, $0.2) })
                chart("尿布", "片", LogType.diaper, rows.map { ($0.0, Double($0.3)) })
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .pageBackground()
        .navigationTitle("最近七天")
    }
    private func chart(_ t: String, _ unit: String, _ type: String, _ data: [(Day, Double)]) -> some View {
        let had = data.filter { $0.1 > 0 }
        let avg = had.isEmpty ? 0 : had.map(\.1).reduce(0, +) / Double(had.count)
        return Card(title: t, symbol: LogType.symbol(type), color: LogType.color(type)) {
            VStack(alignment: .leading, spacing: 0) {
                Text("有记录的日子平均").font(.footnote).foregroundStyle(Palette.secondaryText)
                // sleep as a length of time ("13 小时 20 分"), counts as whole numbers
                if unit == "小时" || unit == "分钟" { Text(durationValue(avg * (unit == "小时" ? 3600 : 60))).font(Typeface.numerals(26, relativeTo: .title2, weight: .bold)) }
                else { ValueText(parts: [(String(format: "%.0f", avg), unit)], size: 30) }
            }
            Chart(data, id: \.0) { d in
                BarMark(x: .value("日", d.0 == app.today ? "今天" : "\(d.0.m)/\(d.0.d)"), y: .value(t, d.1)).foregroundStyle(LogType.color(type).gradient).cornerRadius(5)
            }
            .chartYAxis {
                // counts in whole numbers only (no "0.5 次")
                AxisMarks(position: .trailing) { v in
                    AxisGridLine()
                    if let d = v.as(Double.self), unit == "小时" || d == d.rounded() {
                        // minutes and millilitres are whole numbers already
                        AxisValueLabel { Text(unit == "小时" ? String(format: "%g", d) : "\(Int(d))") }
                    }
                }
            }
            .frame(height: 150)
        }
    }
}
