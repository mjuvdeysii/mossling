import SwiftUI

/// Single-page 3× cotton-paper visual ledger poster combining a full day's totals, 3-track circadian swimlane,
/// and all 4 time-of-day chapters into one clean, printable & shareable keepsake image (eliminating 5 screenshots).
struct DaySheetPoster: View {
    let babyName: String
    let ageText: String
    let day: Day
    let logs: [LogEntry]

    private var own: [LogEntry] { logs.filter { !$0.carriedOver(into: day) } }

    var body: some View {
        let paper = Color(hex: 0xFBF7F0)
        let cardBg = Color.white
        let ink = Color(hex: 0x1C1D19)
        let muted = Color(hex: 0x5B5C63)
        let teal = Color(hex: 0x08675F)

        let d0 = day.date.timeIntervalSince1970 * 1000
        let feedCount = logs.feedCount(from: d0)
        let nursedSec = logs.filter { $0.type == LogType.nurse && $0.end != nil }.reduce(0.0) { $0 + $1.seconds(on: day) }
        let bottleMl = own.filter { $0.type == LogType.bottle }.reduce(0) { $0 + ($1.amount ?? 0) }
        let sleepSec = logs.filter { $0.type == LogType.sleep }.reduce(0.0) { $0 + $1.seconds(on: day) }
        let longestSleepSec = logs.filter { $0.type == LogType.sleep && $0.end != nil }.map(\.activeSeconds).max() ?? 0
        let diapers = own.filter { $0.type == LogType.diaper }
        let wet = diapers.filter { $0.detail == "wet" || $0.detail == "both" }.count
        let dirty = diapers.filter { $0.detail == "dirty" || $0.detail == "both" }.count
        let extraCounts: [(String, Int)] = [LogType.solid, LogType.medicine, LogType.temp, LogType.bath, LogType.play, LogType.note]
            .compactMap { t in
                let c = own.filter { $0.type == t }.count
                return c > 0 ? (t, c) : nil
            }
        let chapters = DayChapter.build(day: day, logs: logs)
        let totalRows = chapters.reduce(0) { $0 + $1.rowCount }
        let twoColumns = totalRows > 10

        let feedDetailBits = [
            nursedSec >= 60 ? L10n.t("亲喂 ", "Nursed ") + durationValue(nursedSec) : nil,
            bottleMl > 0 ? L10n.t("瓶喂 \(bottleMl)ml", "Bottle \(bottleMl)ml") : nil,
        ].compactMap { $0 }

        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.isEnglish ? "\(babyName)'s Day Sheet" : "\(babyName)的每日照护手账")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(ink)
                    let dateStr = L10n.isEnglish
                        ? "\(Day.enMonths[day.m - 1]) \(day.d), \(day.y) · \(day.weekday)"
                        : "\(day.y)年\(day.m)月\(day.d)日 \(day.weekday)"
                    Text(ageText.isEmpty ? dateStr : "\(dateStr) · \(ageText)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(teal)
                }
                Spacer()
                Text(L10n.t("共 \(totalRows) 条", "\(totalRows) entries"))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(teal)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(teal.opacity(0.12)))
            }

            // Three summary cards
            HStack(spacing: 8) {
                posterTotalBox(
                    title: L10n.t("喂奶", "Feeds"),
                    value: L10n.t("\(feedCount) 次", "\(feedCount)"),
                    sub: feedDetailBits.joined(separator: " · "),
                    tint: Crayon.pink,
                    ink: ink,
                    muted: muted
                )
                posterTotalBox(
                    title: L10n.t("睡眠", "Sleep"),
                    value: durationValue(sleepSec),
                    sub: longestSleepSec >= 60 ? L10n.t("最长 ", "Max ") + durationValue(longestSleepSec) : "—",
                    tint: Crayon.lilac,
                    ink: ink,
                    muted: muted
                )
                posterTotalBox(
                    title: L10n.t("尿布", "Diapers"),
                    value: L10n.t("\(diapers.count) 片", "\(diapers.count)"),
                    sub: diapers.isEmpty ? "—" : L10n.t("湿 \(wet) · 便 \(dirty)", "\(wet) wet · \(dirty) dirty"),
                    tint: Crayon.sky,
                    ink: ink,
                    muted: muted
                )
            }

            if !extraCounts.isEmpty {
                HStack(spacing: 6) {
                    ForEach(extraCounts, id: \.0) { t, count in
                        HStack(spacing: 4) {
                            Circle().fill(LogType.color(t)).frame(width: 6, height: 6)
                            Text("\(LogType.name(t)) \(count)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(ink)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(LogType.color(t).opacity(0.14)))
                    }
                    Spacer()
                }
            }

            // 24h 3-track swimlane
            VStack(alignment: .leading, spacing: 3) {
                DaySwimlaneCanvas(day: day, logs: logs, timers: [], dark: false)
                HStack {
                    Color.clear.frame(width: 24, height: 1)
                    ForEach(["00:00", "06:00", "12:00", "18:00"], id: \.self) { label in
                        Text(label)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(cardBg))

            // All chapters rendered completely in dense high-legibility layout
            ForEach(chapters) { chapter in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Image(systemName: chapter.period.symbol)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(chapter.period.tint)
                        Text("\(chapter.period.title) (\(chapter.period.spanLabel))")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(ink)
                        Spacer()
                        Text(chapter.summaryLine)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(muted)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(chapter.period.tint.opacity(0.12)))

                    let cols = twoColumns
                        ? [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]
                        : [GridItem(.flexible())]
                    LazyVGrid(columns: cols, alignment: .leading, spacing: 4) {
                        ForEach(chapter.rows) { row in
                            posterRow(row, muted: muted, ink: ink)
                        }
                    }
                }
            }

            Divider().opacity(0.3)

            Text(L10n.t("摸索台灯 · 孩子摸索，大人点灯 · 本机离线生成", "Moss & Otto · They explore. You hold the light. · On-device offline export"))
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(muted.opacity(0.8))
        }
        .padding(18)
        .frame(width: 420)
        .background(paper)
    }

    private func posterTotalBox(title: String, value: String, sub: String, tint: Color, ink: Color, muted: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Crayon.ink(tint))
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(sub)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.14)))
    }

    private func posterRow(_ row: DayRowGroup, muted: Color, ink: Color) -> some View {
        let e = row.face
        let c = LogType.color(e.type)
        let timeStr = e.carriedOver(into: day) ? "00:00" : hm(e.startDate)
        let joined = row.parts.count > 1
        let val = joined ? durationValue(row.parts.reduce(0) { $0 + $1.seconds(on: day) }) : e.value(on: day)
        let noteBits: String = {
            if joined {
                return row.parts.map { ($0.side == "r" ? L10n.t("右", "R") : L10n.t("左", "L")) + durationValue($0.seconds(on: day)) }.joined(separator: "+")
            }
            if let s = e.side { return s == "r" ? L10n.t("右侧", "Right") : L10n.t("左侧", "Left") }
            if let d = e.detail, [LogType.solid, LogType.medicine, LogType.note, LogType.play].contains(e.type), !d.isEmpty {
                return e.type == LogType.play ? String(d.drop { $0 != " " }.dropFirst()) : d
            }
            if let m = e.milk { return m }
            return ""
        }()

        return HStack(spacing: 5) {
            Circle().fill(c).frame(width: 5.5, height: 5.5)
            Text(timeStr)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .monospacedDigit()
            Text(LogType.name(e.type))
                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                .foregroundStyle(ink)
                .lineLimit(1)
            if !noteBits.isEmpty {
                Text(noteBits)
                    .font(.system(size: 8.5, weight: .medium, design: .rounded))
                    .foregroundStyle(muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 2)
            if !val.isEmpty {
                Text(val)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(Crayon.ink(c))
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3.5)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.white))
    }
}
