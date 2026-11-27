import SwiftUI

/// Four intuitive daily rhythm chapters ordered newest-first for ledger review.
enum DayPeriod: String, CaseIterable, Identifiable, Sendable {
    case evening, afternoon, morning, overnight
    var id: String { rawValue }

    var title: String {
        switch self {
        case .evening: L10n.t("夜晚", "Evening")
        case .afternoon: L10n.t("下午", "Afternoon")
        case .morning: L10n.t("上午", "Morning")
        case .overnight: L10n.t("深夜", "Overnight")
        }
    }

    var spanLabel: String {
        switch self {
        case .evening: "18:00–24:00"
        case .afternoon: "12:00–18:00"
        case .morning: "06:00–12:00"
        case .overnight: "00:00–06:00"
        }
    }

    var axisHour: String {
        switch self {
        case .overnight: "00"
        case .morning: "06"
        case .afternoon: "12"
        case .evening: "18"
        }
    }

    var symbol: String {
        switch self {
        case .evening: "moon.stars.fill"
        case .afternoon: "sun.max.fill"
        case .morning: "sunrise.fill"
        case .overnight: "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .evening: Palette.rod
        case .afternoon: Crayon.tangerine
        case .morning: Crayon.sunflower
        case .overnight: Crayon.lilac
        }
    }

    static func of(timestampMs: Double, on day: Day) -> DayPeriod {
        let d0 = day.date.timeIntervalSince1970 * 1000
        let clamped = max(d0, timestampMs)
        let hour = Day.cal.component(.hour, from: Date(timeIntervalSince1970: clamped / 1000))
        switch hour {
        case 0..<6: return .overnight
        case 6..<12: return .morning
        case 12..<18: return .afternoon
        default: return .evening
        }
    }
}

/// One grouped ledger row (a single entry, or all sides of one contiguous breast feed).
struct DayRowGroup: Identifiable, Hashable {
    let parts: [LogEntry]
    let face: LogEntry
    let sortTime: Double

    var id: UUID { face.id }

    static func combinedFace(_ parts: [LogEntry]) -> LogEntry {
        guard parts.count > 1, let a = parts.first, let z = parts.last else { return parts[0] }
        let paused = parts.reduce(0.0) { $0 + $1.pausedSeconds }
        return LogEntry(
            id: a.id,
            type: a.type,
            start: a.start,
            end: z.end,
            detail: paused > 0 ? "paused:\(Int(paused * 1000))" : nil
        )
    }
}

/// One collapsible chapter on the Journal day ledger with factual per-period subtotals.
struct DayChapter: Identifiable {
    let period: DayPeriod
    let rows: [DayRowGroup]
    let feedCount: Int
    let sleepSeconds: Double
    let diaperCount: Int
    let extraCount: Int

    var id: DayPeriod { period }
    var rowCount: Int { rows.count }

    var summaryLine: String {
        var bits: [String] = []
        if feedCount > 0 {
            bits.append(L10n.t("\(feedCount) 喂", feedCount == 1 ? "1 feed" : "\(feedCount) feeds"))
        }
        if sleepSeconds >= 60 {
            bits.append(L10n.t("睡 ", "Sleep ") + durationValue(sleepSeconds))
        }
        if diaperCount > 0 {
            bits.append(L10n.t("\(diaperCount) 尿布", "\(diaperCount) dip"))
        }
        if extraCount > 0 {
            bits.append(L10n.t("\(extraCount) 照护", "\(extraCount) care"))
        }
        return bits.joined(separator: " · ")
    }

    static func build(day: Day, logs: [LogEntry]) -> [DayChapter] {
        let d0 = day.date.timeIntervalSince1970 * 1000
        let grouped = logs.rows()
            .map { parts -> DayRowGroup in
                let face = DayRowGroup.combinedFace(parts)
                return DayRowGroup(parts: parts, face: face, sortTime: max(parts[0].start, d0))
            }
            .sorted { $0.sortTime > $1.sortTime }

        let byPeriod = Dictionary(grouping: grouped) { DayPeriod.of(timestampMs: $0.sortTime, on: day) }

        return DayPeriod.allCases.compactMap { period in
            guard let list = byPeriod[period], !list.isEmpty else { return nil }
            let feeds = list.filter { $0.face.type == LogType.nurse || $0.face.type == LogType.bottle }.count
            let sleepSec = list.filter { $0.face.type == LogType.sleep }.reduce(0.0) { total, row in
                total + row.parts.reduce(0.0) { $0 + $1.seconds(on: day) }
            }
            let diapers = list.filter { $0.face.type == LogType.diaper }.count
            let extras = list.count - feeds - list.filter { $0.face.type == LogType.sleep }.count - diapers
            return DayChapter(
                period: period,
                rows: list,
                feedCount: feeds,
                sleepSeconds: sleepSec,
                diaperCount: diapers,
                extraCount: extras
            )
        }
    }
}

/// Pure contextual quick-volume suggestions for 0.6s inline bottle logging.
enum SmartBottleVolumes {
    static func suggestions(lastMl: Int?) -> [Int] {
        guard let last = lastMl, last > 0 else { return [60, 90, 120, 150] }
        let raw: [Int]
        if last <= 50 {
            raw = [max(10, last - 10), last, last + 15, last + 30]
        } else if last <= 110 {
            raw = [max(20, last - 20), last, last + 20, last + 40]
        } else {
            raw = [max(30, last - 30), last, min(260, last + 30), min(300, last + 60)]
        }
        var seen = Set<Int>()
        return raw.map { min(300, max(10, $0)) }.filter { seen.insert($0).inserted }.sorted()
    }
}

/// Three-track 24h circadian swimlane canvas (Sleep / Feeds / Care) rendered purely read-only in Canvas
/// for both Journal timeline overview and 3× cotton-paper `DaySheetPoster` exports.
struct DaySwimlaneCanvas: View {
    let day: Day
    let logs: [LogEntry]
    let timers: [RunningTimer]
    var only: String? = nil
    var dark: Bool = false
    var nowDate: Date = Date()

    var body: some View {
        let d0 = day.date.timeIntervalSince1970 * 1000
        let d1 = day.plus(days: 1).date.timeIntervalSince1970 * 1000
        let span = max(1.0, d1 - d0)
        let now = nowDate.timeIntervalSince1970 * 1000

        HStack(spacing: 6) {
            // Compact fixed track icon rail (20pt, zero overlap with bars)
            VStack(spacing: 0) {
                trackIcon("moon.fill", tint: Crayon.lilac, label: L10n.t("睡", "Z"))
                trackIcon("heart.fill", tint: Crayon.pink, label: L10n.t("喂", "F"))
                trackIcon("sparkles", tint: Crayon.sky, label: L10n.t("护", "C"))
            }
            .frame(width: 18, height: 66)

            Canvas(rendersAsynchronously: false) { ctx, size in
                let w = size.width
                let h = size.height
                let laneH = h / 3

                func x(_ t: Double) -> CGFloat {
                    CGFloat(max(0, min(1, (t - d0) / span))) * w
                }
                func active(_ t: String) -> Bool {
                    only.map { JournalKinds.matches(t, $0) } ?? true
                }

                // Soft 4-phase sky backdrop (00–06, 06–12, 12–18, 18–24)
                let bandColors: [Color] = [
                    Crayon.lilac.opacity(dark ? 0.14 : 0.10),
                    Crayon.sunflower.opacity(dark ? 0.08 : 0.10),
                    Crayon.tangerine.opacity(dark ? 0.08 : 0.08),
                    Palette.rod.opacity(dark ? 0.16 : 0.08),
                ]
                for i in 0..<4 {
                    let bx = w * CGFloat(i) / 4
                    ctx.fill(Path(CGRect(x: bx, y: 0, width: w / 4, height: h)), with: .color(bandColors[i]))
                }

                // Hairline lane guides & 6-hour dividers
                for row in 1..<3 {
                    var line = Path()
                    let ly = CGFloat(row) * laneH
                    line.move(to: CGPoint(x: 0, y: ly))
                    line.addLine(to: CGPoint(x: w, y: ly))
                    ctx.stroke(line, with: .color(Palette.outline.opacity(dark ? 0.25 : 0.22)), lineWidth: 0.75)
                }
                for col in 1..<4 {
                    var vline = Path()
                    let vx = w * CGFloat(col) / 4
                    vline.move(to: CGPoint(x: vx, y: 0))
                    vline.addLine(to: CGPoint(x: vx, y: h))
                    ctx.stroke(vline, with: .color(Palette.outline.opacity(dark ? 0.25 : 0.22)), style: StrokeStyle(lineWidth: 0.75, dash: [2, 3]))
                }

                // Lane 0: Sleep spans + active sleep timer
                for e in logs where e.type == LogType.sleep {
                    let endT = e.end ?? e.start
                    guard endT > d0, e.start < d0 + span else { continue }
                    let x0 = x(e.start), x1 = max(x0 + 5, x(endT))
                    let bar = RoundedRectangle(cornerRadius: 4).path(in: CGRect(x: x0, y: 4, width: x1 - x0, height: laneH - 8))
                    let alpha = active(e.type) ? 0.92 : 0.18
                    ctx.fill(bar, with: .color(Crayon.lilac.opacity(alpha)))
                }
                for t in timers where t.type == LogType.sleep {
                    guard now > d0, t.start < d0 + span else { continue }
                    let x0 = x(t.start), x1 = max(x0 + 6, x(now))
                    let bar = RoundedRectangle(cornerRadius: 4).path(in: CGRect(x: x0, y: 4, width: x1 - x0, height: laneH - 8))
                    ctx.fill(bar, with: .color(Crayon.lilac))
                }

                // Lane 1: Feeds (nursing + bottle pills, clearly separated from sleep)
                let feedY = laneH + 4
                let feedH = laneH - 8
                for e in logs where e.type == LogType.nurse || e.type == LogType.bottle {
                    let endT = e.end ?? e.start
                    guard endT >= d0, e.start < d0 + span else { continue }
                    let x0 = x(e.start)
                    let width = e.type == LogType.nurse ? max(4.5, x(endT) - x0) : 5.5
                    let pill = RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: x0, y: feedY, width: width, height: feedH))
                    let baseColor = e.type == LogType.bottle ? Crayon.tangerine : Crayon.pink
                    let alpha = active(e.type) ? 0.94 : 0.18
                    ctx.fill(pill, with: .color(baseColor.opacity(alpha)))
                }
                for t in timers where t.type == LogType.nurse {
                    guard now > d0, t.start < d0 + span else { continue }
                    let x0 = x(t.start), x1 = max(x0 + 5, x(now))
                    let pill = RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: x0, y: feedY, width: x1 - x0, height: feedH))
                    ctx.fill(pill, with: .color(Crayon.pink))
                }

                // Lane 2: Diapers & Other care events (solids, bath, temp, medicine, play, note)
                let careMid = laneH * 2.5
                for e in logs where e.type != LogType.sleep && e.type != LogType.nurse && e.type != LogType.bottle {
                    guard e.start >= d0, e.start < d0 + span else { continue }
                    let cx = max(4, min(w - 4, x(e.start)))
                    let r: CGFloat = e.type == LogType.diaper ? 3.8 : 4.3
                    let alpha = active(e.type) ? 0.94 : 0.18
                    let c = LogType.color(e.type)
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: careMid - r, width: r * 2, height: r * 2)), with: .color(c.opacity(alpha)))
                }

                // Current moment needle (only when viewing today)
                if now > d0 && now < d0 + span {
                    let nx = x(now)
                    var needle = Path()
                    needle.move(to: CGPoint(x: nx, y: 0))
                    needle.addLine(to: CGPoint(x: nx, y: h))
                    ctx.stroke(needle, with: .color(Palette.bead.opacity(0.85)), lineWidth: 1.5)
                    ctx.fill(Path(ellipseIn: CGRect(x: nx - 3, y: h - 5, width: 6, height: 6)), with: .color(Palette.bead))
                }
            }
            .frame(height: 66)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.outline.opacity(0.24), lineWidth: 0.75))
        }
    }

    private func trackIcon(_ symbol: String, tint: Color, label: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Crayon.ink(tint))
            .frame(width: 18, height: 22)
            .accessibilityLabel(label)
    }
}

/// Pure read-only 3-Track 24h Overview Swimlane with 4-Phase chapter jump buttons below.
/// Zero drag gestures and zero inline edit popups so vertical scrolling stays 100% responsive and accidental edits never happen.
struct DaySwimlaneChart: View {
    let day: Day
    let logs: [LogEntry]
    let timers: [RunningTimer]
    @Binding var only: String?
    let onSelectPeriod: (DayPeriod) -> Void

    @Environment(\.lamp) private var lamp
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = lamp || scheme == .dark
        let periodsChrono: [DayPeriod] = [.overnight, .morning, .afternoon, .evening]

        VStack(alignment: .leading, spacing: 6) {
            TimelineView(.periodic(from: .now, by: 60)) { tl in
                DaySwimlaneCanvas(
                    day: day,
                    logs: logs,
                    timers: timers,
                    only: only,
                    dark: dark,
                    nowDate: tl.date
                )
                .frame(height: 66)
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.t("24 小时睡眠、喂奶与照护时间轨", "24-hour Sleep, Feeds & Care tracks"))
                .accessibilityValue(swimlaneAccessibilityValue)
            }

            // Interactive 4-phase time axis buttons (jumps cleanly to that chapter below)
            HStack(spacing: 4) {
                Color.clear.frame(width: 20, height: 1)
                ForEach(periodsChrono) { period in
                    Button {
                        TactileEngine.shared.beadClick()
                        onSelectPeriod(period)
                    } label: {
                        Text("\(period.axisHour) \(period.title)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Palette.secondaryText)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(L10n.t("展开\(period.title)记录", "Jump to \(period.title) chapter"))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.t("24 小时睡眠、喂奶与照护三轨时间条", "24-hour Sleep, Feeds & Care 3-track swimlane"))
    }

    private var chronologicalDayLogs: [LogEntry] {
        let d0 = day.date.timeIntervalSince1970 * 1000
        let d1 = day.plus(days: 1).date.timeIntervalSince1970 * 1000
        return logs.filter { e in
            let matchesFilter = only.map { JournalKinds.matches(e.type, $0) } ?? true
            return matchesFilter && (e.end ?? e.start) >= d0 && e.start <= d1
        }.sorted { $0.start < $1.start }
    }

    private var swimlaneAccessibilityValue: String {
        let chrono = chronologicalDayLogs
        guard !chrono.isEmpty else {
            return L10n.t("今天暂无记录", "No entries recorded for this day")
        }
        let d0 = day.date.timeIntervalSince1970 * 1000
        let feeds = logs.feedCount(from: d0)
        let diapers = logs.filter { $0.type == LogType.diaper }.count
        let sleepSecs = logs.filter { $0.type == LogType.sleep }.reduce(0.0) { $0 + $1.seconds(on: day) }
        var parts: [String] = []
        if sleepSecs > 0 {
            parts.append(L10n.t("睡眠 \(minutesOf(sleepSecs))", "Sleep \(minutesOf(sleepSecs))"))
        }
        if feeds > 0 {
            parts.append(L10n.t("喂奶 \(feeds) 次", "\(feeds) feeds"))
        }
        if diapers > 0 {
            parts.append(L10n.t("尿布 \(diapers) 次", "\(diapers) diapers"))
        }
        return parts.isEmpty
            ? L10n.t("共 \(chrono.count) 条", "\(chrono.count) entries")
            : parts.joined(separator: L10n.isEnglish ? ", " : "、")
    }
}
