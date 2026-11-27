import SwiftUI
import UniformTypeIdentifiers

/// Lazily renders a high-resolution SwiftUI keepsake view to PNG only when the user actually taps Share,
/// keeping scrolling and interactive gestures completely hitch-free.
struct RenderedPoster: Transferable {
    var filename: String = "moss-otto-print"
    let render: @MainActor @Sendable () -> UIImage?

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .png) { item in
            guard let data = await MainActor.run(body: { item.render()?.pngData() }), !data.isEmpty else {
                throw CocoaError(.fileWriteUnknown)
            }
            let safeName = item.filename
                .replacingOccurrences(of: "/", with: "-")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent((safeName.isEmpty ? "moss-otto-print" : safeName) + "-" + UUID().uuidString.prefix(8))
                .appendingPathExtension("png")
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url, allowAccessingOriginalFile: false)
        }
    }
}

/// Selectable day window for the 24-hour rhythm dial.
private enum RhythmSpan: Int, CaseIterable, Identifiable {
    case week = 7
    case fortnight = 14
    var id: Int { rawValue }
    var title: String { L10n.t("\(rawValue)天", "\(rawValue)d") }
}

/// Which layer of daily life is highlighted on the 24-hour circadian dial.
enum RhythmFilter: String, CaseIterable, Identifiable {
    case all, sleep, feeds, play
    var id: String { rawValue }
    var label: String {
        switch self {
        case .all: L10n.t("全部", "All")
        case .sleep: L10n.t("睡眠", "Sleep")
        case .feeds: L10n.t("喂奶", "Feeds")
        case .play: L10n.t("玩耍", "Play")
        }
    }
    var tint: Color {
        switch self {
        case .all: Palette.accent
        case .sleep: LogType.color(LogType.sleep)
        case .feeds: LogType.color(LogType.nurse)
        case .play: LogType.color(LogType.play)
        }
    }
}

/// Pure, testable 24-hour circadian ring model built strictly from recorded logs (zero scores, zero predictions).
struct RhythmDialModel: Sendable {
    struct SleepSpan: Equatable, Sendable {
        let startHour: Double   // 0.0...24.0
        let endHour: Double     // 0.0...24.0
    }
    struct FeedDot: Equatable, Sendable {
        let hour: Double        // 0.0...24.0
        let isBottle: Bool
    }
    struct DayRing: Identifiable, Sendable {
        let day: Day
        let ringIndex: Int      // 0 = oldest (innermost), count - 1 = today (outermost)
        let sleepSpans: [SleepSpan]
        let feeds: [FeedDot]
        let plays: [Double]
        var id: Int { day.epochDay }
    }
    struct HourSummary: Equatable, Sendable {
        let hour: Int           // 0...23
        let sleepDays: Int
        let feedCount: Int
        let playCount: Int
        let totalDays: Int
    }
    struct RhythmSummary: Equatable, Sendable {
        let activeDays: Int
        let avgSleepHours: Double?
        let avgFeedsPerDay: Double?
        let longestSleepHours: Double?
        let typicalBedtimeHour: Int?
    }

    let rings: [DayRing]
    let totalLogs: Int
    let summary: RhythmSummary

    static func build(logs: [LogEntry], today: Day, days: Int = 7, excludeIncompleteToday: Bool = false) -> RhythmDialModel {
        let count = max(1, min(30, days))
        let allFeeds = logs.feeds()
        var built: [DayRing] = []
        built.reserveCapacity(count)
        var total = 0
        var sleepDaysCount = 0
        var totalSleepHours = 0.0
        var completedSleepDaysCount = 0
        var completedSleepHours = 0.0
        var feedDaysCount = 0
        var totalFeedsCount = 0
        var completedFeedDaysCount = 0
        var completedFeedsCount = 0
        var activeDays = 0

        for idx in 0..<count {
            let back = (count - 1) - idx
            let d = today.plus(days: -back)
            let dayStartMs = d.date.timeIntervalSince1970 * 1000
            let dayEndMs = d.plus(days: 1).date.timeIntervalSince1970 * 1000
            let dayLen = max(1, dayEndMs - dayStartMs)
            let isCompletedDay = idx < count - 1

            // Sleep spans clipped precisely to [dayStartMs, dayEndMs] (handles overnight carry-over accurately)
            var sleeps: [SleepSpan] = []
            for e in logs where e.type == LogType.sleep {
                guard let endMs = e.end, endMs > e.start else { continue }
                let s = max(e.start, dayStartMs)
                let en = min(endMs, dayEndMs)
                if en > s {
                    let sh = ((s - dayStartMs) / dayLen) * 24.0
                    let eh = ((en - dayStartMs) / dayLen) * 24.0
                    sleeps.append(SleepSpan(startHour: sh, endHour: eh))
                }
            }

            let daySleepHours = logs.filter { $0.type == LogType.sleep }.reduce(0.0) { $0 + $1.seconds(on: d) / 3600.0 }
            if daySleepHours > 0 || !sleeps.isEmpty {
                sleepDaysCount += 1
                totalSleepHours += daySleepHours
                if isCompletedDay {
                    completedSleepDaysCount += 1
                    completedSleepHours += daySleepHours
                }
            }

            // Feeds grouped via Feed (one bead per meal, never double-counting left/right sides)
            var feeds: [FeedDot] = []
            for f in allFeeds where f.start >= dayStartMs && f.start < dayEndMs {
                let hr = ((f.start - dayStartMs) / dayLen) * 24.0
                feeds.append(FeedDot(hour: hr, isBottle: f.isBottle))
            }
            if !feeds.isEmpty {
                feedDaysCount += 1
                totalFeedsCount += feeds.count
                if isCompletedDay {
                    completedFeedDaysCount += 1
                    completedFeedsCount += feeds.count
                }
            }

            // Play sessions started on this day
            var plays: [Double] = []
            for e in logs where e.type == LogType.play && e.start >= dayStartMs && e.start < dayEndMs {
                let hr = ((e.start - dayStartMs) / dayLen) * 24.0
                plays.append(hr)
            }

            if !sleeps.isEmpty || !feeds.isEmpty || !plays.isEmpty {
                activeDays += 1
            }

            total += sleeps.count + feeds.count + plays.count
            built.append(DayRing(day: d, ringIndex: idx, sleepSpans: sleeps, feeds: feeds, plays: plays))
        }

        let windowStartMs = built.first.map { $0.day.date.timeIntervalSince1970 * 1000 } ?? 0
        let windowEndMs = today.plus(days: 1).date.timeIntervalSince1970 * 1000

        var longestSleep: Double? = nil
        var bedtimeHours: [Double] = []
        for e in logs where e.type == LogType.sleep {
            guard let endMs = e.end, endMs > e.start, endMs > windowStartMs, e.start < windowEndMs else { continue }
            let hrs = e.activeSeconds / 3600.0
            if hrs > 0 {
                longestSleep = max(longestSleep ?? 0, hrs)
            }
            if e.start >= windowStartMs && e.start < windowEndMs && e.activeSeconds >= 3600 {
                let comp = Day.cal.dateComponents([.hour, .minute], from: e.startDate)
                let hr = Double(comp.hour ?? 12) + Double(comp.minute ?? 0) / 60.0
                if hr >= 18.0 || hr < 2.0 {
                    bedtimeHours.append(hr < 12.0 ? hr + 24.0 : hr)
                }
            }
        }

        let effSleepDays = (excludeIncompleteToday && count > 1 && completedSleepDaysCount > 0) ? completedSleepDaysCount : sleepDaysCount
        let effSleepHours = (excludeIncompleteToday && count > 1 && completedSleepDaysCount > 0) ? completedSleepHours : totalSleepHours
        let effFeedDays = (excludeIncompleteToday && count > 1 && completedFeedDaysCount > 0) ? completedFeedDaysCount : feedDaysCount
        let effFeedsCount = (excludeIncompleteToday && count > 1 && completedFeedDaysCount > 0) ? completedFeedsCount : totalFeedsCount
        let avgSleep = effSleepDays > 0 ? effSleepHours / Double(effSleepDays) : nil
        let avgFeeds = effFeedDays > 0 ? Double(effFeedsCount) / Double(effFeedDays) : nil
        let typicalBedtime: Int? = if bedtimeHours.count >= 2 {
            Int((bedtimeHours.reduce(0, +) / Double(bedtimeHours.count)).rounded()) % 24
        } else {
            nil
        }

        let summary = RhythmSummary(
            activeDays: activeDays,
            avgSleepHours: avgSleep,
            avgFeedsPerDay: avgFeeds,
            longestSleepHours: longestSleep,
            typicalBedtimeHour: typicalBedtime
        )
        return RhythmDialModel(rings: built, totalLogs: total, summary: summary)
    }

    /// Factual count of recorded sleep days, feeds, and plays falling within hour `[hour, hour + 1)`.
    func inspect(hour rawHour: Int) -> HourSummary {
        let h = ((rawHour % 24) + 24) % 24
        let hStart = Double(h)
        let hEnd = Double(h + 1)
        var sleepDays = 0
        var feedCount = 0
        var playCount = 0
        for ring in rings {
            if ring.sleepSpans.contains(where: { $0.endHour > hStart && $0.startHour < hEnd }) {
                sleepDays += 1
            }
            feedCount += ring.feeds.filter { $0.hour >= hStart && $0.hour < hEnd }.count
            playCount += ring.plays.filter { $0 >= hStart && $0 < hEnd }.count
        }
        return HourSummary(hour: h, sleepDays: sleepDays, feedCount: feedCount, playCount: playCount, totalDays: rings.count)
    }

    /// Maps an hour `0.0...24.0` to canvas radians where 12:00 Noon sits at top (-π/2) and 00:00 Midnight sits at bottom (+π/2).
    static func angle(forHour h: Double) -> Double {
        ((h - 12.0) / 24.0) * 2.0 * .pi - .pi / 2.0
    }

    /// Inverse mapping from a touch vector `(dx, dy)` relative to dial center to integer hour `0...23`.
    static func hour(forVector dx: CGFloat, dy: CGFloat) -> Int {
        let theta = atan2(Double(dy), Double(dx)) // radians, 0 = right (18:00), -π/2 = top (12:00)
        var h = ((theta + .pi / 2.0) / (2.0 * .pi)) * 24.0 + 12.0
        h = h.truncatingRemainder(dividingBy: 24.0)
        if h < 0 { h += 24.0 }
        return Int(floor(h)) % 24
    }
}

/// 「昼夜节律盘」 — 24-Hour Circadian Bead Astrolabe card mounted at the crown of `StatsView`.
/// Concentric rings show recent days (inner = oldest, outer = today) with 12:00 sun at top and 00:00 moon at bottom.
/// Drag anywhere around the dial to aim Otto's amber beam and inspect pure factual patterns hour by hour.
struct RhythmDialCard: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.accessibilityReduceMotion) private var reduce

    @State private var spanDays: Int = 7
    @State private var filter: RhythmFilter = .all
    @State private var inspectedHour: Int?
    @State private var showAgeHalo = false
    @GestureState private var scrubbingRing = false

    /// Optional deterministic clock override for screenshot tests.
    let nowHour: Double?

    init(nowHour: Double? = nil, initialInspectedHour: Int? = nil) {
        self.nowHour = nowHour
        _inspectedHour = State(initialValue: initialInspectedHour)
    }

    private func clockHour(for date: Date) -> Double {
        if let nowHour { return nowHour }
        let c = Day.cal.dateComponents([.hour, .minute], from: date)
        return Double(c.hour ?? 12) + Double(c.minute ?? 0) / 60.0
    }

    private var currentHour: Double {
        clockHour(for: Date())
    }

    var body: some View {
        if nowHour != nil {
            dialBody(hr: currentHour)
        } else {
            TimelineView(.periodic(from: .now, by: 60)) { tl in
                dialBody(hr: clockHour(for: tl.date))
            }
        }
    }

    @ViewBuilder
    private func dialBody(hr: Double) -> some View {
        let model = RhythmDialModel.build(logs: j.logs, today: app.today, days: spanDays, excludeIncompleteToday: true)
        let dark = lamp || scheme == .dark
        let ageHaloStage: DailyRhythmStage? = showAgeHalo ? DailyRhythmStage.stage(for: app.babyMonth ?? 0) : nil
        let who = app.nickname.isEmpty ? L10n.t("宝宝", "Baby") : app.nickname
        let ageLabel = app.age.map { L10n.ageText($0) } ?? ""
        let daysCount = spanDays
        let exportItem = RenderedPoster(filename: "moss-otto-rhythm") {
            let poster = RhythmPrintPoster(
                name: who,
                ageLabel: ageLabel,
                spanDays: daysCount,
                model: model,
                nowHour: hr
            )
            let renderer = ImageRenderer(content: poster)
            renderer.scale = 3.0
            return renderer.uiImage
        }

        VStack(alignment: .leading, spacing: 14) {
            // Card Header + Segmented 7d/14d Toggle + Share Button
            HStack(alignment: .center, spacing: 8) {
                HStack(spacing: 6) {
                    GoldBead(size: 9)
                    Text(L10n.t("昼夜节律盘", "24h Rhythm Dial"))
                        .font(DS.TypeScale.cardTitle)
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 4)
                spanPicker(dark: dark)
                ShareLink(
                    item: exportItem,
                    preview: SharePreview(L10n.t("摸索台灯 · 昼夜节律印画", "Moss & Otto · Rhythm Print"))
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Palette.accent.opacity(dark ? 0.22 : 0.12)))
                        .overlay(Circle().strokeBorder(Palette.accent.opacity(dark ? 0.34 : 0.20), lineWidth: 0.5))
                        .contentShape(Circle().inset(by: -6))
                }
                .buttonStyle(.toy)
                .accessibilityLabel(L10n.t("分享昼夜节律印画", "Share Rhythm Print"))
            }

            // Interactive 24-Hour Astrolabe Canvas
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                ZStack {
                    RhythmDialCanvas(
                        model: model,
                        filter: filter,
                        inspectedHour: inspectedHour,
                        nowHour: hr,
                        dark: dark,
                        ageHaloStage: ageHaloStage
                    )
                    centerMedallion(model: model, dark: dark)
                        .frame(width: side * 0.405, height: side * 0.405)
                }
                .contentShape(Circle())
                .simultaneousGesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            let dx = value.location.x - center.x
                            let dy = value.location.y - center.y
                            let dist = hypot(dx, dy)
                            if dist < side * 0.16 {
                                if inspectedHour != nil {
                                    withAnimation(reduce ? nil : .snappy) { inspectedHour = nil }
                                }
                                return
                            }
                            let h = RhythmDialModel.hour(forVector: dx, dy: dy)
                            if inspectedHour != h {
                                inspectedHour = h
                                TactileEngine.shared.beadClick()
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10)
                        .updating($scrubbingRing) { value, state, _ in
                            guard !state else { return }
                            let sx = value.startLocation.x - center.x
                            let sy = value.startLocation.y - center.y
                            let startDist = hypot(sx, sy)
                            let outerR = side * 0.395
                            let rNorm = startDist / max(1, outerR)
                            guard rNorm >= 0.45, rNorm <= 1.28 else { return }
                            if abs(value.translation.width) >= abs(value.translation.height) * 0.85 {
                                state = true
                            }
                        }
                        .onChanged { value in
                            let sx = value.startLocation.x - center.x
                            let sy = value.startLocation.y - center.y
                            let startDist = hypot(sx, sy)
                            let outerR = side * 0.395
                            let rNorm = startDist / max(1, outerR)
                            guard rNorm >= 0.45, rNorm <= 1.28 else { return }
                            guard scrubbingRing || abs(value.translation.width) >= abs(value.translation.height) * 0.85 else { return }
                            let dx = value.location.x - center.x
                            let dy = value.location.y - center.y
                            guard hypot(dx, dy) >= side * 0.16 else { return }
                            let h = RhythmDialModel.hour(forVector: dx, dy: dy)
                            if inspectedHour != h {
                                inspectedHour = h
                                TactileEngine.shared.beadClick()
                            }
                        }
                )
            }
            .frame(height: 300)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.t("24 小时昼夜节律盘，过去 \(spanDays) 天", "24-hour circadian rhythm dial, last \(spanDays) days"))
            .accessibilityValue(accessibilitySummary(model: model))
            .accessibilityAdjustableAction { dir in
                let cur = inspectedHour ?? Int(hr)
                switch dir {
                case .increment: inspectedHour = (cur + 1) % 24; TactileEngine.shared.beadClick()
                case .decrement: inspectedHour = (cur + 23) % 24; TactileEngine.shared.beadClick()
                default: break
                }
            }

            // Segmented Filter Bar (All / Sleep / Feeds / Play)
            DSSegmentedControl(
                items: RhythmFilter.allCases,
                selection: $filter,
                dark: dark,
                title: { $0.label },
                dotColor: { $0 == .all ? nil : $0.tint }
            )

            // Uniform 2x2 Editorial Metrics Grid (zero ragged multi-color pill wrapping)
            let metrics = summaryMetrics(model.summary)
            if !metrics.isEmpty {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(Array(metrics.enumerated()), id: \.offset) { _, m in
                        DSMetricCell(
                            label: m.label,
                            value: m.value,
                            unit: m.unit,
                            accent: m.color,
                            dark: dark
                        )
                    }
                }
            }

            // Quiet legend + toggleable 同龄参考光晕 + ring orientation hint
            FlowRow(spacing: 10, lineSpacing: 6) {
                if model.totalLogs == 0 {
                    Text(L10n.t("记下几天睡眠与喂奶后，宝宝自己的昼夜节律会一圈一圈浮现出来。", "After a few days of sleep and feed logs, your baby's natural rhythm appears ring by ring."))
                        .font(.footnote)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    legendDot(LogType.color(LogType.sleep), L10n.t("睡眠弧", "Sleep"))
                    legendDot(LogType.color(LogType.nurse), L10n.t("喂奶珠", "Feed"))
                    legendDot(LogType.color(LogType.play), L10n.t("玩耍", "Play"))
                }
                Button {
                    TactileEngine.shared.beadClick()
                    withAnimation(reduce ? nil : .snappy) { showAgeHalo.toggle() }
                } label: {
                    Label(L10n.t("同龄参考光晕", "Age Halo"), systemImage: showAgeHalo ? "sparkles.rectangle.stack.fill" : "circle.dashed")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(showAgeHalo ? .white : Crayon.ink(Crayon.teal))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(showAgeHalo ? Crayon.buttonFill(Crayon.teal) : Crayon.teal.opacity(dark ? 0.22 : 0.12)))
                        .pillHitTarget()
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(showAgeHalo ? .isSelected : [])
            }
            if model.totalLogs > 0 {
                Text(L10n.t("外圈是今天", "Outer = Today"))
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .padding(16)
        .printCard(radius: Radius.card)
    }

    private func summaryMetrics(_ s: RhythmDialModel.RhythmSummary) -> [(label: String, value: String, unit: String, color: Color)] {
        var out: [(String, String, String, Color)] = []
        if let hrs = s.avgSleepHours {
            out.append((L10n.t("日均睡眠", "Avg Sleep"), String(format: "%.1f", hrs), "h", LogType.color(LogType.sleep)))
        }
        if let longest = s.longestSleepHours {
            out.append((L10n.t("最长一觉", "Longest"), String(format: "%.1f", longest), "h", Crayon.sky))
        }
        if let feeds = s.avgFeedsPerDay {
            out.append((L10n.t("日均喂奶", "Avg Feeds"), String(format: "%.1f", feeds), L10n.t("次", "/d"), LogType.color(LogType.nurse)))
        }
        if let bed = s.typicalBedtimeHour {
            out.append((L10n.t("常约入睡", "Bedtime"), String(format: "%02d:00", bed), "", Palette.amberDeep))
        }
        return out
    }

    private func spanPicker(dark: Bool) -> some View {
        DSSegmentedControl(
            items: RhythmSpan.allCases,
            selection: Binding(
                get: { RhythmSpan(rawValue: spanDays) ?? .week },
                set: { spanDays = $0.rawValue }
            ),
            dark: dark,
            compact: true,
            title: { $0.title }
        )
    }

    @ViewBuilder
    private func centerMedallion(model: RhythmDialModel, dark: Bool) -> some View {
        ZStack {
            Circle()
                .fill(dark ? Color(hex: 0x141C38) : Palette.card)
                .shadow(color: dark ? .black.opacity(0.32) : Color(hex: 0x7A5230).opacity(0.10), radius: 6, y: 2)
            Circle()
                .strokeBorder(
                    inspectedHour != nil ? Palette.amber.opacity(0.65) : Palette.outline.opacity(0.25),
                    lineWidth: inspectedHour != nil ? 1.5 : 1
                )

            if let h = inspectedHour {
                let info = model.inspect(hour: h)
                let nextH = (h + 1) % 24
                VStack(spacing: 3) {
                    Text(String(format: "%02d:00", h))
                        .font(Typeface.numerals(17, relativeTo: .headline, weight: .bold))
                        .foregroundStyle(dark ? Palette.amber : Crayon.ink(Palette.amberDeep))
                    Text(String(format: "– %02d:00", nextH))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Palette.secondaryText)
                        .monospacedDigit()

                    VStack(spacing: 2) {
                        if info.sleepDays > 0 {
                            Text(L10n.t("\(info.sleepDays)/\(info.totalDays) 天在睡", "Sleep \(info.sleepDays)/\(info.totalDays)d"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Crayon.ink(LogType.color(LogType.sleep)))
                        }
                        if info.feedCount > 0 {
                            Text(L10n.t("喂奶 \(info.feedCount) 次", "\(info.feedCount) \(info.feedCount == 1 ? "feed" : "feeds")"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Crayon.ink(LogType.color(LogType.nurse)))
                        }
                        if info.playCount > 0 {
                            Text(L10n.t("玩耍 \(info.playCount) 次", "\(info.playCount) \(info.playCount == 1 ? "play" : "plays")"))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Crayon.ink(LogType.color(LogType.play)))
                        }
                        if info.sleepDays == 0 && info.feedCount == 0 && info.playCount == 0 {
                            Text(L10n.t("这时段安静", "Quiet hour"))
                                .font(.caption2)
                                .foregroundStyle(Palette.secondaryText)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                }
                .padding(8)
                .multilineTextAlignment(.center)
                .onTapGesture {
                    withAnimation(reduce ? nil : .snappy) { inspectedHour = nil }
                }
            } else {
                VStack(spacing: 3) {
                    Image(systemName: currentHour >= 19 || currentHour < 6 ? "moon.stars.fill" : "sun.max.fill")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Palette.bead)
                    Text(L10n.t("近 \(spanDays) 天", "Last \(spanDays)d"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(L10n.t("滑动盘面查看", "Drag to inspect"))
                        .font(.caption2)
                        .foregroundStyle(Palette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(8)
                .multilineTextAlignment(.center)
            }
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2.weight(.medium)).foregroundStyle(Palette.secondaryText)
        }
    }

    private func accessibilitySummary(model: RhythmDialModel) -> String {
        guard let h = inspectedHour else {
            var pieces: [String] = []
            if let sleepH = model.summary.avgSleepHours {
                pieces.append(L10n.t(
                    String(format: "日均睡眠 %.1f 小时", sleepH),
                    String(format: "averaging %.1f hr sleep daily", sleepH)
                ))
            }
            if let feeds = model.summary.avgFeedsPerDay {
                pieces.append(L10n.t(
                    String(format: "日均喂奶 %.1f 次", feeds),
                    String(format: "%.1f feeds per day", feeds)
                ))
            }
            if let longestH = model.summary.longestSleepHours {
                pieces.append(L10n.t(
                    String(format: "最长连续小睡 %.1f 小时", longestH),
                    String(format: "longest stretch %.1f hr", longestH)
                ))
            }
            let detail = pieces.isEmpty ? "" : (L10n.isEnglish ? ": " : "，") + pieces.joined(separator: L10n.isEnglish ? ", " : "、")
            return L10n.t("共 \(model.totalLogs) 条记录\(detail)。上下滑动按小时查看", "\(model.totalLogs) entries\(detail). Swipe up or down to inspect by hour.")
        }
        let info = model.inspect(hour: h)
        return L10n.t(
            "\(h) 点到 \((h + 1) % 24) 点：\(info.sleepDays) 天在睡，喂奶 \(info.feedCount) 次，玩耍 \(info.playCount) 次",
            "\(h):00 to \((h + 1) % 24):00: asleep \(info.sleepDays) of \(info.totalDays) days, \(info.feedCount) feeds, \(info.playCount) plays"
        )
    }
}

/// Core 24-hour concentric bead astrolabe vector canvas (shared between live interactive view and 3x heirloom print).
struct RhythmDialCanvas: View {
    let model: RhythmDialModel
    let filter: RhythmFilter
    let inspectedHour: Int?
    let nowHour: Double
    let dark: Bool
    var ageHaloStage: DailyRhythmStage? = nil

    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerR = side * 0.395
            let innerR = side * 0.210
            let ringCount = max(1, model.rings.count)
            let ringBand = (outerR - innerR) / CGFloat(ringCount)

            // 1. Subtle Day (top hemisphere: 06:00–18:00) vs Night (bottom hemisphere: 18:00–06:00) tint
            var dayArch = Path()
            dayArch.move(to: c)
            dayArch.addArc(center: c, radius: outerR + 6, startAngle: .radians(.pi), endAngle: .radians(0), clockwise: false)
            dayArch.closeSubpath()
            ctx.fill(dayArch, with: .color(Crayon.sunflower.opacity(dark ? 0.055 : 0.09)))

            var nightArch = Path()
            nightArch.move(to: c)
            nightArch.addArc(center: c, radius: outerR + 6, startAngle: .radians(0), endAngle: .radians(.pi), clockwise: false)
            nightArch.closeSubpath()
            ctx.fill(nightArch, with: .color(Crayon.lilac.opacity(dark ? 0.14 : 0.08)))

            // 2. Radial 24-hour hairline spokes (major every 6 hours, minor every 3 hours)
            for h in stride(from: 0, to: 24, by: 3) {
                let a = RhythmDialModel.angle(forHour: Double(h))
                let isMajor = h % 6 == 0
                let p0 = CGPoint(x: c.x + cos(a) * (innerR - 4), y: c.y + sin(a) * (innerR - 4))
                let p1 = CGPoint(x: c.x + cos(a) * (outerR + (isMajor ? 6 : 2)), y: c.y + sin(a) * (outerR + (isMajor ? 6 : 2)))
                var spoke = Path()
                spoke.move(to: p0)
                spoke.addLine(to: p1)
                ctx.stroke(
                    spoke,
                    with: .color((dark ? Color.white : Color(hex: 0x6B5A48)).opacity(isMajor ? 0.20 : 0.09)),
                    lineWidth: isMajor ? 1.1 : 0.7
                )
            }

            // 2b. Optional 同龄参考光晕 (outer gentle sleep/nap band)
            if let ageHaloStage {
                let g = CircadianLoomCanvas.geometry(for: ageHaloStage)
                let haloR = outerR + 6
                let haloSleepColor = LogType.color(LogType.sleep).opacity(dark ? 0.34 : 0.28)
                func drawHaloArc(centerHour: Double, span: Double) {
                    guard span > 0.2 else { return }
                    let a0 = RhythmDialModel.angle(forHour: centerHour - span / 2.0)
                    let a1 = RhythmDialModel.angle(forHour: centerHour + span / 2.0)
                    var halo = Path()
                    halo.addArc(center: c, radius: haloR, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
                    ctx.stroke(halo, with: .color(haloSleepColor), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                }
                drawHaloArc(centerHour: g.nightCenter, span: g.nightMaxSpan)
                if g.napMaxSpan >= 0.8 {
                    drawHaloArc(centerHour: g.napCenter, span: g.napMaxSpan)
                }
            }

            // 3. Otto's warm amber lamp spotlight beam for the currently scrubbed hour
            if let h = inspectedHour {
                let a0 = RhythmDialModel.angle(forHour: Double(h))
                let a1 = RhythmDialModel.angle(forHour: Double(h + 1))
                var wedge = Path()
                wedge.move(to: c)
                wedge.addArc(center: c, radius: outerR + 8, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
                wedge.closeSubpath()
                ctx.fill(
                    wedge,
                    with: .radialGradient(
                        Gradient(colors: [Palette.amber.opacity(dark ? 0.36 : 0.28), Palette.amber.opacity(dark ? 0.12 : 0.09)]),
                        center: c,
                        startRadius: innerR * 0.85,
                        endRadius: outerR + 8
                    )
                )
                ctx.stroke(wedge, with: .color(Palette.amber.opacity(0.65)), lineWidth: 1.2)
            }

            // 4. Concentric Day Rings (inner = oldest, outer = today)
            let sleepColor = LogType.color(LogType.sleep)
            let nurseColor = LogType.color(LogType.nurse)
            let bottleColor = LogType.color(LogType.bottle)
            let playColor = LogType.color(LogType.play)

            for ring in model.rings {
                let frac = ringCount == 1 ? 1.0 : Double(ring.ringIndex) / Double(ringCount - 1)
                let r = innerR + (CGFloat(ring.ringIndex) + 0.5) * ringBand
                let isToday = ring.ringIndex == ringCount - 1
                let recencyAlpha = 0.38 + 0.62 * frac

                // Subtle ring track
                let trackRect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                ctx.stroke(
                    Path(ellipseIn: trackRect),
                    with: .color((dark ? Color.white : Color(hex: 0x7A5E42)).opacity(isToday ? 0.16 : 0.07)),
                    lineWidth: isToday ? 1.1 : 0.7
                )

                // Sleep arcs
                if filter == .all || filter == .sleep {
                    let arcW = max(3.0, min(8.5, ringBand * (isToday ? 0.68 : 0.54)))
                    for span in ring.sleepSpans {
                        let a0 = RhythmDialModel.angle(forHour: span.startHour)
                        let a1 = RhythmDialModel.angle(forHour: span.endHour)
                        var arc = Path()
                        arc.addArc(center: c, radius: r, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
                        ctx.stroke(
                            arc,
                            with: .color(sleepColor.opacity(recencyAlpha * (filter == .sleep ? 0.96 : 0.86))),
                            style: StrokeStyle(lineWidth: arcW, lineCap: .round)
                        )
                    }
                }

                // Feed beads
                if filter == .all || filter == .feeds {
                    let d = max(4.2, min(8.2, ringBand * (isToday ? 0.72 : 0.58)))
                    for feed in ring.feeds {
                        let a = RhythmDialModel.angle(forHour: feed.hour)
                        let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                        let col = feed.isBottle ? bottleColor : nurseColor
                        let rect = CGRect(x: pt.x - d / 2, y: pt.y - d / 2, width: d, height: d)
                        ctx.fill(Path(ellipseIn: rect), with: .color(col.opacity(recencyAlpha)))
                        if isToday {
                            ctx.stroke(Path(ellipseIn: rect), with: .color(Color.white.opacity(dark ? 0.45 : 0.85)), lineWidth: 0.9)
                        }
                    }
                }

                // Play beads
                if filter == .all || filter == .play {
                    let d = max(4.0, min(7.6, ringBand * (isToday ? 0.68 : 0.52)))
                    for hr in ring.plays {
                        let a = RhythmDialModel.angle(forHour: hr)
                        let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
                        let rect = CGRect(x: pt.x - d / 2, y: pt.y - d / 2, width: d, height: d)
                        ctx.fill(Path(ellipseIn: rect), with: .color(playColor.opacity(recencyAlpha)))
                    }
                }
            }

            // 5. Otto's Golden Bead marking "Now" on the outermost ring
            let nowAngle = RhythmDialModel.angle(forHour: nowHour)
            let outerCenterR = outerR - ringBand * 0.5
            let nowPt = CGPoint(x: c.x + cos(nowAngle) * outerCenterR, y: c.y + sin(nowAngle) * outerCenterR)
            ctx.fill(
                Path(ellipseIn: CGRect(x: nowPt.x - 10, y: nowPt.y - 10, width: 20, height: 20)),
                with: .radialGradient(Gradient(colors: [Palette.amber.opacity(0.65), .clear]), center: nowPt, startRadius: 1, endRadius: 10)
            )
            let beadRect = CGRect(x: nowPt.x - 4.8, y: nowPt.y - 4.8, width: 9.6, height: 9.6)
            ctx.fill(
                Path(ellipseIn: beadRect),
                with: .radialGradient(Gradient(colors: [Palette.beadLight, Palette.bead]), center: CGPoint(x: nowPt.x - 1.5, y: nowPt.y - 1.5), startRadius: 0, endRadius: 6)
            )
            ctx.stroke(Path(ellipseIn: beadRect), with: .color(.white.opacity(0.85)), lineWidth: 1)

            // 6. Cardinal Hour Labels (12:00 top, 18:00 right, 00:00 bottom, 06:00 left)
            let labelR = outerR + 17
            let labelColor = dark ? Palette.lampInk.opacity(0.76) : Color(hex: 0x5B5247)
            let cardinals: [(Double, String)] = [
                (12, "12:00"),
                (18, "18:00"),
                (0, "00:00"),
                (6, "06:00"),
            ]
            for (hr, text) in cardinals {
                let a = RhythmDialModel.angle(forHour: hr)
                let pt = CGPoint(x: c.x + cos(a) * labelR, y: c.y + sin(a) * labelR)
                let resolved = ctx.resolve(
                    Text(text)
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(labelColor)
                )
                ctx.draw(resolved, at: pt, anchor: .center)
            }
        }
    }
}

/// High-resolution museum-print Keepsake Poster of the baby's 24-hour rhythm, rendered offline via ImageRenderer.
private struct RhythmPrintPoster: View {
    let name: String
    let ageLabel: String
    let spanDays: Int
    let model: RhythmDialModel
    let nowHour: Double

    var body: some View {
        let paper = Color(red: 0xFB / 255, green: 0xF7 / 255, blue: 0xF0 / 255)
        let ink = Color(red: 0x24 / 255, green: 0x1F / 255, blue: 0x1B / 255)
        let teal = Color(red: 0x0B / 255, green: 0x7D / 255, blue: 0x74 / 255)

        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name + (ageLabel.isEmpty ? "" : " · " + ageLabel))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(ink.opacity(0.6))
                    Text(L10n.t("近 \(spanDays) 天昼夜节律", "\(spanDays)-Day Circadian Rhythm"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(teal)
                }
                Spacer()
                Text(Day.today.md)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.5))
            }

            RhythmDialCanvas(
                model: model,
                filter: .all,
                inspectedHour: nil,
                nowHour: nowHour,
                dark: false
            )
            .frame(width: 312, height: 312)

            HStack(spacing: 14) {
                dot(LogType.color(LogType.sleep), L10n.t("睡眠", "Sleep"))
                dot(LogType.color(LogType.nurse), L10n.t("喂奶", "Feeds"))
                dot(LogType.color(LogType.play), L10n.t("玩耍", "Play"))
                Spacer()
                Text(L10n.t("外圈为今天", "Outer = Today"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(ink.opacity(0.55))
            }

            let posterFacts: [String] = [
                model.summary.avgSleepHours.map { L10n.t("日均睡 \(String(format: "%.1f", $0))h", "Sleep \(String(format: "%.1f", $0))h/d") },
                model.summary.longestSleepHours.map { L10n.t("最长 \(String(format: "%.1f", $0))h", "Longest \(String(format: "%.1f", $0))h") },
                model.summary.avgFeedsPerDay.map { L10n.t("日均喂 \(String(format: "%.1f", $0)) 次", "\(String(format: "%.1f", $0)) feeds/d") }
            ].compactMap { $0 }
            if !posterFacts.isEmpty {
                Text(posterFacts.joined(separator: "  ·  "))
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.76))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

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

    private func dot(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(c).frame(width: 7, height: 7)
            Text(t)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0x24 / 255, green: 0x1F / 255, blue: 0x1B / 255).opacity(0.75))
        }
    }
}
