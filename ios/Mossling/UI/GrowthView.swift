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
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) { ForEach(Indicator.allCases) { tile($0) } }
                if app.sex == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择性别以对照 WHO 生长曲线").font(.subheadline)
                        HStack { Button("男孩") { app.sex = "boy" }; Button("女孩") { app.sex = "girl" } }.buttonStyle(.borderedProminent)
                    }
                    .card(Palette.cardLow)
                }
                chartCard
                Text("资料来源：世界卫生组织儿童生长标准（2006）。百分位表示同龄同性别儿童中的位置，不是评分；判断生长情况请以儿童保健医生的评估为准。")
                    .font(.caption).foregroundStyle(Palette.secondaryText).padding(.horizontal, 4)

                HStack {
                    Text("每一次测量").font(Typeface.serif(21))
                    Text(j.measures.isEmpty ? "还没有" : "\(j.measures.count) 次").font(.caption).foregroundStyle(Palette.secondaryText)
                    Spacer()
                }
                .padding(.top, 12)
                ForEach(Array(j.measures.reversed().enumerated()), id: \.element.id) { i, m in
                    let all = j.measures, idx = all.firstIndex(of: m) ?? 0, prev = idx > 0 ? all[idx - 1] : nil
                    Button { editing = m } label: { row(m, prev) }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .background(Palette.background)
        .safeAreaInset(edge: .bottom) {
            Button { editing = Measure(at: ms(Date())) } label: { Label("记一次测量", systemImage: "plus").frame(maxWidth: .infinity).padding(.vertical, 6) }
                .buttonStyle(.borderedProminent).controlSize(.large).padding(.horizontal, 16).padding(.vertical, 8).background(.bar)
        }
        .navigationTitle("生长").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { m in MeasureSheet(measure: m, isNew: !j.measures.contains { $0.id == m.id }) }
    }

    private func tile(_ x: Indicator) -> some View {
        let hist = j.measures.filter { value($0, x) != nil }
        let last = hist.last, prev = hist.dropLast().last
        let on = ind == x
        return Button { withAnimation(.snappy) { ind = x; picked = nil } } label: {
            VStack(alignment: .leading, spacing: 4) {
                Label(x.short, systemImage: x.symbol).font(.caption.weight(.semibold)).foregroundStyle(x.tint)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(last.flatMap { value($0, x) }.map { x.fmt($0) } ?? "—").font(Typeface.numerals(22)).monospacedDigit()
                    if last != nil { Text(x.unitShort).font(.caption2).foregroundStyle(Palette.secondaryText) }
                }
                if let l = last, let p = prev, let a = value(l, x), let b = value(p, x) {
                    Text((a >= b ? "+" : "−") + x.fmt(abs(a - b))).font(.caption.weight(.semibold)).foregroundStyle(x.tint).monospacedDigit()
                }
                if let l = last, let p = pct(l, x) { Text(pctText(p)).font(.caption2).foregroundStyle(Palette.secondaryText) }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(on ? x.tint.opacity(0.14) : Palette.cardLow, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(on ? x.tint : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private struct Band: Identifiable { let id = UUID(); let m: Double; let lo: Double; let hi: Double; let series: String }
    private struct Line: Identifiable { let id = UUID(); let m: Double; let v: Double; let p: Int }

    private var chartCard: some View {
        let g = app.growth, girl = app.girl
        let pts: [(Measure, Double, Double)] = j.measures.compactMap { m in months(m).flatMap { mo in value(m, ind).map { (m, mo, $0) } } }
        let now = app.age.map { Double($0.months) + Double($0.days) / 30.4375 }
        let span = min(36, max(6, max(now ?? 0, pts.map(\.1).max() ?? 0) + 3))
        let xs = stride(from: 0.0, through: span, by: 0.25).map { $0 }
        let mid = xs.dropLast().map { $0 + 0.125 }
        let outer = mid.map { m in Band(m: m - 0.125, lo: g.at(ind, girl: girl, months: m, percentile: 3), hi: g.at(ind, girl: girl, months: m, percentile: 97), series: "3–97") }
        let inner = mid.map { m in Band(m: m - 0.125, lo: g.at(ind, girl: girl, months: m, percentile: 15), hi: g.at(ind, girl: girl, months: m, percentile: 85), series: "15–85") }
        let lines = [3, 50, 97].flatMap { p in xs.map { Line(m: $0, v: g.at(ind, girl: girl, months: $0, percentile: p), p: p) } }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: ind.symbol).foregroundStyle(ind.tint).frame(width: 34, height: 34).background(ind.tint.opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(ind.label) · \(ind.unit)").font(.headline)
                    Text("WHO 儿童生长标准" + (app.sex == nil ? "" : girl ? " · 女孩" : " · 男孩")).font(.caption).foregroundStyle(Palette.secondaryText)
                }
            }
            Chart {
                // the bands, as thin slices (a quarter month each)
                ForEach(outer) { b in RectangleMark(xStart: .value("月龄", b.m), xEnd: .value("月龄", min(span, b.m + 0.25)), yStart: .value("低", b.lo), yEnd: .value("高", b.hi)).foregroundStyle(ind.tint.opacity(0.09)) }
                ForEach(inner) { b in RectangleMark(xStart: .value("月龄", b.m), xEnd: .value("月龄", min(span, b.m + 0.25)), yStart: .value("低", b.lo), yEnd: .value("高", b.hi)).foregroundStyle(ind.tint.opacity(0.13)) }
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
                                .padding(.horizontal, 8).padding(.vertical, 4).background(Palette.cardHigh, in: RoundedRectangle(cornerRadius: 8))
                        }
                }
            }
            .chartXScale(domain: 0...span)
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
            .frame(height: 300)
            .accessibilityLabel("\(ind.label)曲线，\(pts.count) 个测量点")
            WrapLayout(spacing: 14) {
                legend(AnyView(RoundedRectangle(cornerRadius: 3).fill(ind.tint.opacity(0.2)).frame(width: 20, height: 10)), "第 15–85 百分位")
                legend(AnyView(RoundedRectangle(cornerRadius: 3).fill(ind.tint.opacity(0.09)).frame(width: 20, height: 10)), "第 3–97 百分位")
                legend(AnyView(Rectangle().fill(Palette.secondaryText).frame(width: 20, height: 2)), "中位数")
                legend(AnyView(Circle().fill(ind.tint).frame(width: 8, height: 8)), "测量")
            }
        }
        .card(Palette.cardLow, radius: 26)
    }

    private func legend(_ v: AnyView, _ t: String) -> some View { HStack(spacing: 5) { v; Text(t).font(.caption2).foregroundStyle(Palette.secondaryText) } }

    private func row(_ m: Measure, _ prev: Measure?) -> some View {
        let d = Day(Date(timeIntervalSince1970: m.at / 1000))
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(d.y).\(d.m).\(d.d)").font(Typeface.numerals(17))
                if let b = app.birth { let a = Age.on(birth: b, today: d); Text(a.months == 0 ? "出生第 \(a.lived) 天" : a.days == 0 ? "满 \(a.months) 个月" : "\(a.months) 个月 \(a.days) 天").font(.caption).foregroundStyle(Palette.secondaryText) }
            }
            .frame(width: 104, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                WrapLayout(spacing: 10) {
                    ForEach(Indicator.allCases) { x in
                        if let v = value(m, x) {
                            HStack(spacing: 3) { Image(systemName: x.symbol).font(.caption).foregroundStyle(x.tint); Text(x.fmt(v)).font(Typeface.numerals(16)).monospacedDigit(); Text(x.unitShort).font(.caption2).foregroundStyle(Palette.secondaryText) }
                        }
                    }
                }
                let bits = [pct(m, ind).map { pctText($0) }, prev.flatMap { p in value(p, ind).flatMap { pv in value(m, ind).map { v in (v >= pv ? "比上次 +" : "比上次 −") + ind.fmt(abs(v - pv)) } } }].compactMap { $0 }
                if !bits.isEmpty { Text("\(ind.short) " + bits.joined(separator: " · ")).font(.caption.weight(.medium)).foregroundStyle(ind.tint) }
            }
            Spacer(minLength: 0)
        }
        .card(Palette.cardLow, radius: 18, padding: 12)
    }
}

/// The last seven days: feeds, sleep and nappies per day.
struct StatsView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    var body: some View {
        let days = (0..<7).reversed().map { app.today.plus(days: -$0) }
        let rows = days.map { d -> (Day, Int, Double, Int) in
            let l = j.logs(on: d)
            return (d, l.filter { $0.type == LogType.nurse || $0.type == LogType.bottle }.count,
                    l.filter { $0.type == LogType.sleep && $0.end != nil }.reduce(0.0) { $0 + ($1.end! - $1.start) } / 3_600_000,
                    l.filter { $0.type == LogType.diaper }.count)
        }
        ScrollView {
            VStack(spacing: 12) {
                chart("喂奶", "次", LogType.nurse, rows.map { ($0.0, Double($0.1)) })
                chart("睡眠", "小时", LogType.sleep, rows.map { ($0.0, $0.2) })
                chart("尿布", "片", LogType.diaper, rows.map { ($0.0, Double($0.3)) })
            }
            .padding(16)
        }
        .background(Palette.background)
        .navigationTitle("最近七天")
    }
    private func chart(_ t: String, _ unit: String, _ type: String, _ data: [(Day, Double)]) -> some View {
        let had = data.filter { $0.1 > 0 }
        let avg = had.isEmpty ? 0 : had.map(\.1).reduce(0, +) / Double(had.count)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label(t, systemImage: LogType.symbol(type)).font(.headline).foregroundStyle(LogType.color(type))
                Spacer()
                Text("有记录的日子平均 " + String(format: unit == "小时" ? "%.1f" : "%.0f", avg) + " " + unit).font(.caption).foregroundStyle(Palette.secondaryText)
            }
            Chart(data, id: \.0) { d in
                BarMark(x: .value("日", d.0 == app.today ? "今天" : "\(d.0.m)/\(d.0.d)"), y: .value(t, d.1)).foregroundStyle(LogType.color(type).gradient).cornerRadius(6)
            }
            .frame(height: 150)
        }
        .card(Palette.cardLow, radius: 22)
    }
}
