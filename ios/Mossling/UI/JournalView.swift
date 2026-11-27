import SwiftUI

struct Wrap: Identifiable { let id: String }

/// The kinds a day can be looked at by: feeds (breast and bottle), sleep, nappies, and each other kind by itself.
enum JournalKinds {
    static func matches(_ type: String, _ key: String) -> Bool {
        key == "feed" ? (type == LogType.nurse || type == LogType.bottle) : type == key
    }
    static func name(_ key: String) -> String { key == "feed" ? L10n.t("喂奶", "Feeds") : LogType.name(key) }
    static func type(_ key: String) -> String { key == "feed" ? LogType.nurse : key }
}

/// A feed or sleep still running, at the top of today's line: its start, how long so far; a tap opens its timer.
struct RunningRow: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    let timer: RunningTimer
    var body: some View {
        let c = LogType.color(timer.type)
        Button {
            guard app.mayKeep() else { return }
            j.focus = timer.type
        } label: {
            TimelineView(.periodic(from: .now, by: 30)) { tl in
                let state = (timer.pausedAt != nil ? L10n.t("已暂停 ", "Paused ") : L10n.t("进行中 ", "Active ")) + durationValue(timer.total(tl.date.timeIntervalSince1970 * 1000))
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        Text(hm(Date(timeIntervalSince1970: timer.start / 1000))).font(Typeface.numerals(16, relativeTo: .body, weight: .semibold))
                        IconTile(symbol: LogType.symbol(timer.type), color: c, size: 28, round: true)
                        Text(LogType.name(timer.type)).font(.body).fixedSize()
                        Spacer(minLength: 8)
                        Ticking(text: state, tint: Crayon.ink(c))
                            .font(Typeface.numerals(15, relativeTo: .body, weight: .semibold)).foregroundStyle(Crayon.ink(c))
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    // large text: the kind and its state one under the other
                    HStack(spacing: 10) {
                        IconTile(symbol: LogType.symbol(timer.type), color: c, size: 28, round: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LogType.name(timer.type) + " · " + hm(Date(timeIntervalSince1970: timer.start / 1000))).font(.body)
                            Text(state).font(.body.weight(.semibold)).foregroundStyle(Crayon.ink(c))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(c.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
            }
        }
        .buttonStyle(.toy)
        .accessibilityLabel(L10n.t("\(LogType.name(timer.type))进行中，打开计时", "\(LogType.name(timer.type)) active, open timer"))
    }
}

/// A short phrase that must not break across lines ("共 8 小时 30 分", "到 06:30"): its spaces become no-break spaces
/// and its characters are joined with word joiners. A long free text (a note) is left to wrap as usual.
/// Pieces of a line separated by dots (subviews alternate: piece, dot, piece, …): pieces wrap as whole words, and a
/// dot is drawn only between two pieces on the same line — never at a line's end or start.
struct DotFlow: Layout {
    var spacing: CGFloat = 4, lineSpacing: CGFloat = 1
    private func lines(_ subviews: Subviews, width: CGFloat) -> [[(index: Int, size: CGSize)]] {
        var out: [[(index: Int, size: CGSize)]] = [[]], x: CGFloat = 0
        var i = 0
        while i < subviews.count {
            let piece = subviews[i].sizeThatFits(ProposedViewSize(width: width, height: nil))
            if i == 0 { out[0].append((i, piece)); x = piece.width; i += 1; continue }
            // a dot (i) and the piece after it (i + 1)
            let dot = subviews[i].sizeThatFits(.unspecified)
            guard i + 1 < subviews.count else { break }
            let next = subviews[i + 1].sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x + spacing + dot.width + spacing + next.width <= width {
                out[out.count - 1].append((i, dot)); out[out.count - 1].append((i + 1, next))
                x += spacing + dot.width + spacing + next.width
            } else {
                out.append([(i + 1, next)]); x = next.width
            }
            i += 2
        }
        return out
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        let ls = lines(subviews, width: w)
        let h = ls.map { $0.map(\.size.height).max() ?? 0 }.reduce(0, +) + lineSpacing * CGFloat(max(0, ls.count - 1))
        let used = ls.map { l in l.map(\.size.width).reduce(0, +) + spacing * CGFloat(max(0, l.count - 1)) }.max() ?? 0
        return CGSize(width: proposal.width ?? used, height: h)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let ls = lines(subviews, width: bounds.width)
        var shown = Set<Int>(), y = bounds.minY
        for l in ls {
            var x = bounds.minX
            let h = l.map(\.size.height).max() ?? 0
            for (i, size) in l {
                subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                shown.insert(i); x += size.width + spacing
            }
            y += h + lineSpacing
        }
        // dots that fell at a line break are not drawn
        for i in subviews.indices where !shown.contains(i) { subviews[i].place(at: CGPoint(x: -10_000, y: -10_000), proposal: .zero) }
    }
}

/// "3 小时 50 分" → each number stays with its unit; a line may still break between "3 小时" and "50 分".
func keepUnits(_ s: String) -> String {
    let t: [String] = s.split(separator: " ").map(String.init)
    var pairs: [String] = []
    var i = 0
    while i < t.count {
        if i + 1 < t.count { pairs.append(glue(t[i] + "\u{00A0}" + t[i + 1])) } else { pairs.append(glue(t[i])) }
        i += 2
    }
    return pairs.joined(separator: " ")
}

/// A run of text that never breaks inside (Chinese may otherwise break between any two characters).
func glue(_ s: String) -> String { s.map(String.init).joined(separator: "\u{2060}") }

/// 「距上一顿 3 小时 30 分」: the label stays with the first number, each number with its unit; a line may break only
/// between "3 小时" and "30 分".
func labeled(_ label: String, _ duration: String) -> String { glue(label) + "\u{00A0}" + keepUnits(duration) }

func unbroken(_ s: String) -> String {
    guard s.count <= 14 else { return s }
    return s.map { $0 == " " ? "\u{00A0}" : String($0) }.joined(separator: "\u{2060}")
}

/// A length of time as number–unit pairs, for a large number with a small unit: [("8", "小时"), ("5", "分")].
func durationParts(_ seconds: Double) -> [(String, String)] {
    let m = Int((max(0, seconds) / 60).rounded())
    if m < 60 { return [("\(m)", L10n.t("分钟", "m"))] }
    if m >= 48 * 60 {
        let h = m / 60
        return h % 24 == 0 ? [("\(h / 24)", L10n.t("天", "d"))] : [("\(h / 24)", L10n.t("天", "d")), ("\(h % 24)", L10n.t("时", "h"))]
    }
    return m % 60 == 0 ? [("\(m / 60)", L10n.t("小时", "h"))] : [("\(m / 60)", L10n.t("时", "h")), ("\(m % 60)", L10n.t("分", "m"))]
}

/// A length of time, rounded to the minute, in the one form used everywhere (minutesOf).
func durationValue(_ seconds: Double) -> String { minutesOf((max(0, seconds) / 60).rounded() * 60) }

extension LogEntry {
    /// The value, right-aligned in its column: an amount, a length of time (the part on this day), a temperature, the
    /// kind of nappy.
    func value(on day: Day) -> String {
        switch type {
        case LogType.nurse, LogType.sleep: return end == nil ? L10n.t("进行中", "Active") : durationValue(seconds(on: day))
        case LogType.bottle: return L10n.volume(ml: amount ?? 0)
        case LogType.temp: return amount.map { L10n.temperature(tenthsC: $0) } ?? ""
        case LogType.diaper:
            return L10n.isEnglish
                ? (["wet": "Wet", "dirty": "Dirty", "both": "Wet + dirty"][detail ?? ""] ?? "")
                : (["wet": "湿", "dirty": "便", "both": "湿 + 便"][detail ?? ""] ?? "")
        default: return ""
        }
    }
    /// The details, on the second line, without repeating the start time shown in the first column: the side, when it
    /// ended (or began, if the day before), the whole length when it crosses midnight, what was eaten or noted.
    func meta(on day: Day, endShown: Bool = false) -> String {
        var bits: [String] = []
        if type == LogType.nurse, let s = side { bits.append(s == "l" ? L10n.t("左侧", "Left") : L10n.t("右侧", "Right")) }
        if let m = milk { bits.append(m) }
        if let e = endDate {
            let endsLater = Day(e) > day
            if carriedOver(into: day) {
                bits.append(L10n.t("接昨天 \(hm(startDate)) · 到 \(hm(e))", "From yesterday \(hm(startDate)) · until \(hm(e))"))
            } else if !endShown || endsLater {
                bits.append(L10n.isEnglish
                    ? "Until " + hm(e) + (endsLater ? " next day" : "")
                    : "到 " + (endsLater ? "次日 " : "") + hm(e))
            }
            if carriedOver(into: day) || endsLater { bits.append(L10n.t("共 ", "Total ") + durationValue(activeSeconds)) }
            if pausedSeconds >= 60 { bits.append(L10n.t("暂停 ", "Paused ") + durationValue(pausedSeconds)) }
        }
        if [LogType.solid, LogType.medicine, LogType.note, LogType.play].contains(type), let d = detail, !d.isEmpty {
            bits.append(type == LogType.play ? String(d.drop { $0 != " " }.dropFirst()) : d)
        }
        return bits.joined(separator: " · ")
    }
}

/// Four-Chapter Collapsible Day Ledger (`夜晚 / 下午 / 上午 / 深夜`) with smart default expansion so high-frequency
/// newborn days (35+ entries) scan effortlessly on one screen while preserving every entry and full metadata.
struct DayChapterLedger: View {
    let day: Day, today: Day
    let logs: [LogEntry]
    let only: String?
    @Binding var expandedPeriods: Set<DayPeriod>
    @Binding var touchedPeriods: Bool
    @Binding var expandAll: Bool
    let edit: (LogEntry) -> Void
    let delete: (LogEntry) -> Void

    @ScaledMetric private var timeWidth: CGFloat = 52
    @Environment(JournalStore.self) private var j
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.dynamicTypeSize) private var type
    @Environment(\.lamp) private var lamp

    private func isExpanded(_ chapter: DayChapter, index: Int, chapters: [DayChapter], totalRows: Int) -> Bool {
        if expandAll || only != nil || chapters.count <= 1 { return true }
        if !touchedPeriods { return totalRows <= 8 || index == 0 }
        return expandedPeriods.contains(chapter.period)
    }

    var body: some View {
        let d0 = day.date.timeIntervalSince1970 * 1000
        let chapters = DayChapter.build(day: day, logs: logs)
        let totalRows = chapters.reduce(0) { $0 + $1.rowCount }
        let gaps = (only == nil)

        TimelineView(.periodic(from: .now, by: 60)) { tl in
            VStack(alignment: .leading, spacing: 10) {
                if chapters.count > 1 && totalRows > 8 && only == nil {
                    HStack(spacing: 8) {
                        Text(L10n.isEnglish ? "By time of day · \(totalRows) entries" : "分时段手账 · 共 \(totalRows) 条")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Palette.secondaryText)
                        Spacer(minLength: 4)
                        Button {
                            TactileEngine.shared.beadClick()
                            withAnimation(reduce ? nil : CalmMotion.accordionSpring) {
                                expandAll.toggle()
                                if expandAll {
                                    touchedPeriods = true
                                    expandedPeriods = Set(chapters.map(\.period))
                                } else {
                                    touchedPeriods = true
                                    expandedPeriods = Set(chapters.prefix(1).map(\.period))
                                }
                            }
                        } label: {
                            Text(expandAll ? L10n.t("收起早先", "Collapse") : L10n.t("全部展开", "Expand All"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Palette.accent)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Palette.accent.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }

                ForEach(Array(chapters.enumerated()), id: \.element.id) { cIndex, chapter in
                    let expanded = isExpanded(chapter, index: cIndex, chapters: chapters, totalRows: totalRows)
                    VStack(alignment: .leading, spacing: 4) {
                        if chapters.count > 1 {
                            Button {
                                TactileEngine.shared.beadClick()
                                withAnimation(reduce ? nil : CalmMotion.accordionSpring) {
                                    if !touchedPeriods {
                                        touchedPeriods = true
                                        if let first = chapters.first {
                                            expandedPeriods = totalRows <= 8 ? Set(chapters.map(\.period)) : [first.period]
                                        }
                                    }
                                    if expandedPeriods.contains(chapter.period) {
                                        expandedPeriods.remove(chapter.period)
                                        expandAll = false
                                    } else {
                                        expandedPeriods.insert(chapter.period)
                                    }
                                }
                            } label: {
                                HStack(alignment: type.isAccessibilitySize ? .top : .center, spacing: 8) {
                                    Image(systemName: chapter.period.symbol)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(chapter.period.tint)
                                        .padding(.top, type.isAccessibilitySize ? 3 : 0)
                                    if type.isAccessibilitySize {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(chapter.period.title)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(.primary)
                                            Text(chapter.summaryLine)
                                                .font(.caption.weight(.medium))
                                                .foregroundStyle(Palette.secondaryText)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    } else {
                                        Text(chapter.period.title)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.primary)
                                        Text(chapter.summaryLine)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(Palette.secondaryText)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.75)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.down")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.tertiary)
                                        .rotationEffect(.degrees(expanded ? 180 : 0))
                                        .padding(.top, type.isAccessibilitySize ? 4 : 0)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                                        .fill(chapter.period.tint.opacity(lamp ? 0.14 : 0.09))
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityValue(expanded ? L10n.t("已展开", "Expanded") : L10n.t("已折叠", "Collapsed"))
                            .id("chapter-\(chapter.period.rawValue)")
                        }

                        if expanded {
                            let rows = chapter.rows
                            let reached: [Double] = {
                                var out = Array(repeating: 0.0, count: rows.count), m = -Double.infinity
                                for i in rows.indices.reversed() {
                                    m = Swift.max(m, rows[i].face.end ?? rows[i].face.start)
                                    out[i] = m
                                }
                                return out
                            }()

                            VStack(spacing: 0) {
                                ForEach(Array(rows.enumerated()), id: \.element.id) { i, group in
                                    let e = group.face
                                    let parts = group.parts
                                    if i > 0 {
                                        let newer = rows[i - 1].face
                                        let gap = (max(newer.start, d0) - reached[i]) / 1000
                                        if gaps && gap >= 3 * 3600 {
                                            GapRow(seconds: gap, timeWidth: timeWidth)
                                        }
                                    }
                                    CompactEntryRow(
                                        entry: e,
                                        parts: parts,
                                        day: day,
                                        isToday: day == today && cIndex == 0 && i == 0,
                                        now: tl.date,
                                        timeWidth: timeWidth,
                                        since: feedInterval(parts[0])
                                    )
                                    .transition(.opacity)
                                    .contentShape(Rectangle())
                                    .onTapGesture { edit(parts[0]) }
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityHint(L10n.t("修改这条记录", "Edit this entry"))
                                    .accessibilityAction(named: parts.count > 1 ? L10n.t("删除这一顿", "Delete feed") : L10n.t("删除", "Delete")) { remove(parts) }
                                    .contextMenu {
                                        if parts.count > 1 {
                                            ForEach(parts) { p in
                                                Button(L10n.t("修改" + (p.side == "r" ? "右侧" : "左侧"), "Edit " + (p.side == "r" ? "Right" : "Left")) + " · " + hm(p.startDate), systemImage: "pencil") { edit(p) }
                                            }
                                            Button(L10n.t("删除这一顿", "Delete feed"), systemImage: "trash", role: .destructive) { remove(parts) }
                                        } else {
                                            Button(L10n.t("修改", "Edit"), systemImage: "pencil") { edit(e) }
                                            Button(L10n.t("删除", "Delete"), systemImage: "trash", role: .destructive) { delete(e) }
                                        }
                                    }
                                    if i < rows.count - 1 {
                                        Divider().padding(.leading, timeWidth + 32).opacity(0.35)
                                    }
                                }
                            }
                            .padding(.top, 2)
                            .transition(reduce ? .opacity : .opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .clipped()
                    .animation(reduce ? nil : CalmMotion.accordionSpring, value: expanded)
                }
            }
        }
    }

    private func remove(_ parts: [LogEntry]) {
        if parts.count > 1 { withAnimation(.snappy) { j.delete(parts) } } else { delete(parts[0]) }
    }

    private func feedInterval(_ e: LogEntry) -> Double? {
        guard e.type == LogType.nurse || e.type == LogType.bottle else { return nil }
        return j.feedIntervalByID[e.id]
    }
}

/// A quiet stretch between two entries, written on a dashed rail.
private struct GapRow: View {
    let seconds: Double
    let timeWidth: CGFloat
    var body: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: timeWidth, height: 1)
            Line().stroke(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2, 5]))
                .frame(width: 24, height: 22)
            Text(labeled(L10n.t("相隔", "Quiet"), durationValue(seconds))).font(.caption.weight(.medium)).foregroundStyle(Palette.secondaryText).monospacedDigit()
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
    private struct Line: Shape { func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.midX, y: r.maxY)); return p } }
}

/// High-craft compact ledger row preserving every timestamp, duration, pause, feeding side & interval metadata.
private struct CompactEntryRow: View {
    let entry: LogEntry
    var parts: [LogEntry] = []
    let day: Day
    let isToday: Bool
    let now: Date
    let timeWidth: CGFloat
    var since: Double? = nil

    var body: some View {
        let c = LogType.color(entry.type)
        let joined = parts.count > 1
        let value = joined ? durationValue(parts.reduce(0) { $0 + $1.seconds(on: day) }) : entry.value(on: day)
        let sides = joined ? parts.map { ($0.side == "r" ? L10n.t("右侧 ", "Right ") : L10n.t("左侧 ", "Left ")) + durationValue($0.seconds(on: day)) }.joined(separator: " · ") : nil
        let showEnd = entry.endDate != nil && entry.seconds(on: day) >= 1800
        let meta: [String] = [sides, entry.meta(on: day, endShown: showEnd), since.map { labeled(L10n.t("距上一顿", "Gap"), durationValue($0)) }].compactMap { $0 }.filter { !$0.isEmpty }
            .joined(separator: " · ").components(separatedBy: " · ").filter { !$0.isEmpty }

        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.carriedOver(into: day) ? "00:00" : hm(entry.startDate))
                    .font(Typeface.numerals(15, relativeTo: .subheadline, weight: .semibold))
                if let e = entry.endDate, showEnd {
                    Text(Day(e) > day ? "24:00" : hm(e))
                        .font(Typeface.numerals(11, relativeTo: .caption2, weight: .medium))
                        .foregroundStyle(Palette.secondaryText)
                } else if isToday {
                    let ref = entry.endDate ?? entry.startDate
                    if abs(now.timeIntervalSince(ref)) < 18 * 3600 {
                        Text(ago(ref, now: now))
                            .font(.caption2)
                            .foregroundStyle(Palette.secondaryText)
                    }
                }
            }
            .frame(width: timeWidth, alignment: .topLeading)

            HStack(spacing: 4) {
                Capsule()
                    .fill(c)
                    .frame(width: 3, height: entry.end != nil ? 22 : 14)
                IconTile(symbol: LogType.symbol(entry.type), color: c, size: 22, round: true)
            }
            .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(LogType.name(entry.type)).font(.subheadline.weight(.semibold))
                        Spacer(minLength: 8)
                        Text(value).font(Typeface.numerals(15, relativeTo: .subheadline, weight: .semibold)).foregroundStyle(Crayon.ink(c)).fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(LogType.name(entry.type)).font(.subheadline.weight(.semibold))
                        Text(value).font(Typeface.numerals(15, relativeTo: .subheadline, weight: .semibold)).foregroundStyle(Crayon.ink(c))
                    }
                }
                if !meta.isEmpty {
                    DotFlow {
                        ForEach(Array(meta.enumerated()), id: \.offset) { i, piece in
                            if i > 0 { Text("·") }
                            Text(piece.contains("\u{00A0}") ? piece : unbroken(piece)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .font(.caption).foregroundStyle(Palette.secondaryText).monospacedDigit()
                    .accessibilityElement(children: .ignore).accessibilityLabel(meta.joined(separator: L10n.t("，", ", ")))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

/// The running timer, small, above the tab bar on every tab; tap to open it. Only pause sits here: ending is done on
/// the timer screen, in its own band, never a few points from pause (a mis-tap would end a feed).
struct TimerAccessory: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.accessibilityReduceMotion) private var reduce
    let timer: RunningTimer
    /// A second clock running at once (a feed during a nap): its mark and time beside the first, one tap to open it.
    var also: RunningTimer? = nil
    @State private var pulse = false

    var body: some View {
        let c = LogType.color(timer.type)
        let isPaused = timer.pausedAt != nil
        HStack(spacing: 12) {
            Button {
                guard app.mayKeep() else { return }
                TactileEngine.shared.beadClick()
                j.focus = timer.type
            } label: {
                HStack(spacing: 10) {
                    IconTile(symbol: LogType.symbol(timer.type), color: c, size: 30, round: true)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(isPaused ? Color.clear : c)
                                .overlay(Circle().strokeBorder(c, lineWidth: isPaused ? 1.5 : 0))
                                .frame(width: 6.5, height: 6.5)
                                .scaleEffect(!isPaused && pulse && !reduce && !Perf.still ? 1.28 : 1.0)
                            Text(LogType.name(timer.type) + (timer.side == "l" ? L10n.t(" · 左侧", " · Left") : timer.side == "r" ? L10n.t(" · 右侧", " · Right") : ""))
                                .font(.footnote.weight(.semibold))
                        }
                        TimelineView(.periodic(from: .now, by: 1)) { tl in
                            let elapsed = span(timer.total(tl.date.timeIntervalSince1970 * 1000))
                            HStack(spacing: 4) {
                                Ticking(text: elapsed, tint: Crayon.ink(c))
                                    .font(Typeface.numerals(13, relativeTo: .footnote))
                                    .foregroundStyle(Palette.secondaryText)
                                if isPaused {
                                    Text(L10n.t("· 已暂停", "· Paused"))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Crayon.ink(c))
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.toy)
            .accessibilityLabel(L10n.t("打开\(LogType.name(timer.type))计时", "Open \(LogType.name(timer.type)) timer"))
            if let o = also {
                Button {
                    guard app.mayKeep() else { return }
                    TactileEngine.shared.beadClick()
                    j.focus = o.type
                } label: {
                    HStack(spacing: 6) {
                        IconTile(symbol: LogType.symbol(o.type), color: LogType.color(o.type), size: 24, round: true)
                        TimelineView(.periodic(from: .now, by: 1)) { tl in
                            Text(span(o.total(tl.date.timeIntervalSince1970 * 1000))).font(Typeface.numerals(13, relativeTo: .footnote)).monospacedDigit()
                        }
                    }
                }
                .buttonStyle(.toy)
                .accessibilityLabel(L10n.t("打开\(LogType.name(o.type))计时", "Open \(LogType.name(o.type)) timer"))
            }
            Button {
                guard app.mayKeep() else { return }
                TactileEngine.shared.dimmerTick()
                j.togglePause(timer.type)
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .hitTarget()
                    .contentShape(Circle())
            }
            .accessibilityLabel(isPaused ? L10n.t("继续", "Resume") : L10n.t("暂停", "Pause"))
        }
        .font(.body)
        .padding(.horizontal, 14)
        .tint(.primary)
        .onAppear {
            guard !isPaused, !reduce, !Perf.still else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onChange(of: isPaused) { _, paused in
            if !paused && !reduce && !Perf.still {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            } else {
                pulse = false
            }
        }
    }
}

/// "今天 14:05" / "昨天 23:40" / "10月20日 08:15" — the whole time, never shortened.
func whenLabel(_ d: Date) -> String {
    let day = Day(d), today = Day.today
    let name = day == today ? L10n.t("今天", "Today") : day == today.plus(days: -1) ? L10n.t("昨天", "Yesterday") : day == today.plus(days: -2) ? L10n.t("前天", "2 days ago") : day.md
    return "\(name) \(hm(d))"
}

/// An exact day and minute, never later than now.
struct TimeSheet: View {
    let title: String
    let initial: Date
    var notBefore: Date? = nil
    let pick: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    var body: some View {
        let now = Date()
        let lower = min(notBefore ?? Date.distantPast, now)
        NavigationStack {
            Form {
                Section {
                    DatePicker(title, selection: $date, in: lower...now, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                } footer: { Text(whenLabel(date)).font(.headline).monospacedDigit() }
            }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.t("取消", "Cancel"), systemImage: "xmark") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(L10n.t("完成", "Done"), systemImage: "checkmark") { pick(date); dismiss() } }
            }
        }
        .onAppear {
            let now = Date()
            let lower = min(notBefore ?? Date.distantPast, now)
            date = min(max(initial, lower), now)
        }
        .presentationDetents([.large])
    }
}
