import SwiftUI

/// Five WHO 24-hour movement, sleep, and screen-time developmental stages from birth through age 3+.
enum DailyRhythmStage: String, CaseIterable, Identifiable, Sendable {
    case newborn
    case infant
    case oneYear
    case twoYears
    case threeYears

    var id: String { rawValue }

    static func stage(for month: Int) -> DailyRhythmStage {
        switch month {
        case ...3: .newborn
        case 4...11: .infant
        case 12...23: .oneYear
        case 24...35: .twoYears
        default: .threeYears
        }
    }

    var representativeMonth: Int {
        switch self {
        case .newborn: 0
        case .infant: 6
        case .oneYear: 12
        case .twoYears: 24
        case .threeYears: 36
        }
    }

    var shortLabel: String {
        switch self {
        case .newborn: L10n.t("0–3月", "0–3m")
        case .infant: L10n.t("4–11月", "4–11m")
        case .oneYear: L10n.t("1 岁", "1 yr")
        case .twoYears: L10n.t("2 岁", "2 yrs")
        case .threeYears: L10n.t("3 岁+", "3+ yrs")
        }
    }

    var stageTitle: String {
        switch self {
        case .newborn: L10n.t("0–3 个月 · 昼夜初建", "0–3 Months · Finding Rhythm")
        case .infant: L10n.t("4–11 个月 · 清醒探索", "4–11 Months · Awake Explorer")
        case .oneYear: L10n.t("1 岁组 · 全天迈步", "1 Year · Active Mover")
        case .twoYears: L10n.t("2 岁组 · 奔跑与秩序", "2 Years · Busy Day")
        case .threeYears: L10n.t("3 岁+ · 精力充沛", "3+ Years · Full Play")
        }
    }

    var sleepMinHours: Int {
        switch self {
        case .newborn: 14
        case .infant: 12
        case .oneYear, .twoYears: 11
        case .threeYears: 10
        }
    }

    var sleepMaxHours: Int {
        switch self {
        case .newborn: 17
        case .infant: 16
        case .oneYear, .twoYears: 14
        case .threeYears: 13
        }
    }

    var sleepMidHours: Double {
        Double(sleepMinHours + sleepMaxHours) / 2.0
    }

    var sleepRangeText: String {
        L10n.t("\(sleepMinHours)–\(sleepMaxHours) 小时", "\(sleepMinHours)–\(sleepMaxHours) hrs")
    }

    var sleepNote: String {
        L10n.t("含夜间长睡与白天小睡", "Per 24h including naps")
    }

    /// Reference awake-play floor/movement minutes (30 min tummy time for infants; 180 min total activity from 1 yr+).
    var activityTargetMinutes: Int {
        switch self {
        case .newborn, .infant: 30
        case .oneYear, .twoYears, .threeYears: 180
        }
    }

    /// Vigorous-play subset for 3+ years (60 min moderate-to-vigorous out of 180 min total).
    var energeticMinutes: Int {
        self == .threeYears ? 60 : 0
    }

    var activityHeadline: String {
        switch self {
        case .newborn:
            L10n.t("趴玩累计 30 分钟+", "30+ min tummy time")
        case .infant:
            L10n.t("多次地面探索 · 趴玩 30m+", "Active floor play · 30m+ tummy")
        case .oneYear, .twoYears:
            L10n.t("全天累计 ≥ 180 分钟", "180+ min varied play")
        case .threeYears:
            L10n.t("≥ 180 分钟（含 60m 跑跳）", "180+ min (60m energetic)")
        }
    }

    var activityDetail: String {
        switch self {
        case .newborn:
            L10n.t("清醒且情绪好时分散俯卧，从几分钟慢慢适应、看世界。", "Spread short supervised tummy-time bursts across awake windows as tolerated.")
        case .infant:
            L10n.t("一天多次安全地面自由探索；尚未爬行前继续分散趴玩。", "Multiple safe floor-play sessions while awake; keep tummy time if not yet mobile.")
        case .oneYear:
            L10n.t("走路、推拉、爬坡、音乐与感官游戏分散在白天各个时段。", "Spread walking, pushing, climbing, music, and floor games throughout the day.")
        case .twoYears:
            L10n.t("户外奔跑、搭积木与生活参与自然穿插，减少长时间久坐束缚。", "Mix outdoor running, building, and daily tasks; break up long sitting time.")
        case .threeYears:
            L10n.t("全天 180 分钟多种活动里，包含至少 60 分钟心跳加快的畅快跑跳。", "Out of 180 daily active minutes, include at least 60 minutes of energetic play.")
        }
    }

    var screenLimitMinutes: Int {
        switch self {
        case .newborn, .infant, .oneYear: 0
        case .twoYears, .threeYears: 60
        }
    }

    var screenHeadline: String {
        switch self {
        case .newborn, .infant:
            L10n.t("不建议屏幕时间", "No screen time")
        case .oneYear:
            L10n.t("不建议久坐屏幕", "No sedentary screens")
        case .twoYears, .threeYears:
            L10n.t("至多 1 小时（越少越好）", "At most 1 hr (less is better)")
        }
    }

    var screenDetail: String {
        switch self {
        case .newborn, .infant, .oneYear:
            L10n.t("面对面的眼神、说话声与真实可抓握的玩具，比任何屏幕都更滋养大脑。", "Face-to-face voices, eye contact, and real tactile play nourish early growth far better.")
        case .twoYears, .threeYears:
            L10n.t("少让孩子独自盯着屏幕；若看短片，大人坐在旁边一起聊看到的画面。", "Keep sedentary screen time brief; co-watch and talk about what you see together.")
        }
    }
}

/// Factual 7-day and today comparison derived strictly from recorded logs (never scores or predictions).
struct DailyRhythmComparison: Sendable, Equatable {
    let avgSleepHours: Double?
    let longestSleepHours: Double?
    let activeSleepDays: Int
    let todaySleepHours: Double
    let todayPlayCount: Int

    var hasSleepBaseline: Bool {
        avgSleepHours != nil && activeSleepDays > 0
    }

    static func build(logs: [LogEntry], today: Day, journalEnabled: Bool) -> DailyRhythmComparison {
        guard journalEnabled else {
            return DailyRhythmComparison(
                avgSleepHours: nil,
                longestSleepHours: nil,
                activeSleepDays: 0,
                todaySleepHours: 0,
                todayPlayCount: 0
            )
        }
        let dial = RhythmDialModel.build(logs: logs, today: today, days: 7)
        let sleepDays = dial.rings.filter { !$0.sleepSpans.isEmpty }.count
        let todaySleep = logs
            .filter { $0.type == LogType.sleep }
            .reduce(0.0) { $0 + $1.seconds(on: today) / 3600.0 }
        let todayStartMs = today.date.timeIntervalSince1970 * 1000
        let tomorrowStartMs = today.plus(days: 1).date.timeIntervalSince1970 * 1000
        let todayPlays = logs.filter { $0.type == LogType.play && $0.start >= todayStartMs && $0.start < tomorrowStartMs }.count

        return DailyRhythmComparison(
            avgSleepHours: dial.summary.avgSleepHours,
            longestSleepHours: dial.summary.longestSleepHours,
            activeSleepDays: sleepDays,
            todaySleepHours: todaySleep,
            todayPlayCount: todayPlays
        )
    }

    /// Plain-language factual observation comparing 7-day average sleep with the selected stage band.
    func sleepComparisonLine(for stage: DailyRhythmStage) -> String? {
        guard let avg = avgSleepHours else { return nil }
        let avgText = String(format: "%.1f", avg)
        return L10n.t(
            "近 7 天日均睡 \(avgText) 小时 · 该阶段参考 \(stage.sleepMinHours)–\(stage.sleepMaxHours) 小时",
            "7-day avg \(avgText)h · stage reference \(stage.sleepMinHours)–\(stage.sleepMaxHours)h"
        )
    }
}

/// 「一天的节奏 / Tactile 24h Rhythm Studio」 — Interactive 24-hour circadian bead loom,
/// 5-stage 0–3 yr developmental evolution rail, and gentle factual alignment with the child's own logs.
struct RhythmView: View {
    @Environment(AppModel.self) private var app
    @Environment(AppRouter.self) private var router: AppRouter?
    @Environment(JournalStore.self) private var j
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.openURL) private var openURL

    let month: Int
    @State private var selectedStage: DailyRhythmStage
    @State private var inspectedHour: Int?

    init(month: Int, initialInspectedHour: Int? = nil) {
        self.month = month
        _selectedStage = State(initialValue: DailyRhythmStage.stage(for: month))
        _inspectedHour = State(initialValue: initialInspectedHour)
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        let initialStage = DailyRhythmStage.stage(for: month)
        let babyStage = app.babyMonth.map { DailyRhythmStage.stage(for: $0) }
        let comparison = DailyRhythmComparison.build(logs: j.logs, today: app.today, journalEnabled: app.journal)
        let showLiveRing = comparison.hasSleepBaseline && (babyStage == nil || selectedStage == babyStage)
        let refMonth = selectedStage == initialStage ? month : selectedStage.representativeMonth
        let mo = app.content.month(refMonth)
        let sleepingNow = j.timers.contains { $0.type == LogType.sleep && $0.pausedAt == nil }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stageEvolutionRail(initialStage: initialStage, babyStage: babyStage, dark: dark)

                circadianLoomCard(
                    comparison: comparison,
                    showLiveRing: showLiveRing,
                    sleepingNow: sleepingNow,
                    dark: dark
                )

                sleepCard(comparison: comparison, showLive: showLiveRing, dark: dark)

                awakePlayCard(comparison: comparison, dark: dark)

                screenBoundaryCard(dark: dark)

                if !mo.who.isEmpty {
                    whoReferenceCard(rawText: mo.who, dark: dark)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 36)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.tangerine)
        .navigationTitle(L10n.t("一天的节奏", "Daily Rhythm"))
        .navigationSubtitle(month == 0 ? L10n.t("出生", "Newborn") : L10n.t("满 \(month) 个月", month == 1 ? "1 month" : "\(month) months"))
        .sensoryFeedback(.selection, trigger: selectedStage)
    }

    // MARK: - 1. 5-Stage Developmental Evolution Rail

    private func stageEvolutionRail(initialStage: DailyRhythmStage, babyStage: DailyRhythmStage?, dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                GoldBead(size: 9)
                Text(L10n.t("0–3 岁作息演进", "0–3 Year Rhythm Arc"))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.secondaryText)
                Spacer(minLength: 4)
                if selectedStage != initialStage {
                    Button {
                        TactileEngine.shared.beadClick()
                        withAnimation(reduce ? nil : .spring(response: 0.36, dampingFraction: 0.84)) {
                            selectedStage = initialStage
                            inspectedHour = nil
                        }
                    } label: {
                        Label(
                            month == 0 ? L10n.t("回出生月", "Back to Birth") : L10n.t("回第 \(month) 个月", "Back to Mo \(month)"),
                            systemImage: "arrow.uturn.backward"
                        )
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Palette.accent.opacity(dark ? 0.22 : 0.12)))
                        .pillHitTarget()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)

            FlowRow(spacing: 8, lineSpacing: 8) {
                ForEach(DailyRhythmStage.allCases) { st in
                    let on = st == selectedStage
                    let isBabyNow = st == babyStage
                    Button {
                        TactileEngine.shared.beadClick()
                        withAnimation(reduce ? nil : .spring(response: 0.36, dampingFraction: 0.84)) {
                            selectedStage = st
                            inspectedHour = nil
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if isBabyNow {
                                Circle()
                                    .fill(on ? Color.white : Palette.bead)
                                    .frame(width: 6, height: 6)
                            }
                            Text(st.shortLabel)
                                .font(.caption.weight(on ? .bold : .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(on ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .vinylSurface(on ? Palette.accentFill : (dark ? Palette.lampCard : Palette.card), radius: Radius.chip, strong: on)
                    }
                    .buttonStyle(.toy)
                    .accessibilityLabel(st.stageTitle + (isBabyNow ? L10n.t("，宝宝当前阶段", ", baby's current stage") : ""))
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - 2. Interactive 24h Circadian Bead Loom

    private func circadianLoomCard(
        comparison: DailyRhythmComparison,
        showLiveRing: Bool,
        sleepingNow: Bool,
        dark: Bool
    ) -> some View {
        let sleepColor = LogType.color(LogType.sleep)
        let playColor = Crayon.tangerine
        let avgSleep = showLiveRing ? comparison.avgSleepHours : nil

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedStage.stageTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.t("拨动 24 小时木珠环，查看昼夜与清醒分布", "Drag around the 24-bead ring to explore day & night"))
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                }
                Spacer(minLength: 4)
                if showLiveRing {
                    Text(L10n.t("含近 7 天实况", "With 7d logs"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(dark ? Palette.amber : Crayon.ink(Palette.bead))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Palette.bead.opacity(dark ? 0.24 : 0.18)))
                }
            }

            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height)
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

                ZStack {
                    CircadianLoomCanvas(
                        stage: selectedStage,
                        avgSleepHours: avgSleep,
                        inspectedHour: inspectedHour,
                        dark: dark
                    )

                    loomCenterMedallion(
                        sleepingNow: sleepingNow,
                        avgSleep: avgSleep,
                        dark: dark
                    )
                    .frame(width: side * 0.44, height: side * 0.44)
                }
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let dx = value.location.x - center.x
                            let dy = value.location.y - center.y
                            let dist = hypot(dx, dy)
                            if dist < side * 0.18 {
                                if inspectedHour != nil {
                                    withAnimation(reduce ? nil : .snappy) { inspectedHour = nil }
                                }
                                return
                            }
                            let h = RhythmDialModel.hour(forVector: dx, dy: dy)
                            if inspectedHour != h {
                                inspectedHour = h
                                TactileEngine.shared.dimmerTick()
                            }
                        }
                )
            }
            .frame(height: 276)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.t("24 小时昼夜节奏环，\(selectedStage.stageTitle)", "24-hour rhythm ring, \(selectedStage.stageTitle)"))
            .accessibilityValue(loomAccessibilityValue(avgSleep: avgSleep))
            .accessibilityAdjustableAction { dir in
                let cur = inspectedHour ?? 12
                switch dir {
                case .increment: inspectedHour = (cur + 1) % 24; TactileEngine.shared.dimmerTick()
                case .decrement: inspectedHour = (cur + 23) % 24; TactileEngine.shared.dimmerTick()
                default: break
                }
            }

            // Legend row
            FlowRow(spacing: 12, lineSpacing: 6) {
                legendDot(sleepColor, L10n.t("睡眠 \(selectedStage.sleepRangeText)", "Sleep \(selectedStage.sleepRangeText)"))
                legendDot(playColor, L10n.t("清醒与探索", "Awake & Play"))
                if let avgSleep {
                    legendDot(Palette.bead, L10n.t("近 7 天日均 \(String(format: "%.1f", avgSleep))h", "7d avg \(String(format: "%.1f", avgSleep))h"))
                }
            }
        }
        .padding(16)
        .printCard(radius: Radius.card)
    }

    @ViewBuilder
    private func loomCenterMedallion(sleepingNow: Bool, avgSleep: Double?, dark: Bool) -> some View {
        VStack(spacing: 4) {
            if let hour = inspectedHour {
                let info = hourInsight(hour: hour, stage: selectedStage)
                Text(String(format: "%02d:00", hour))
                    .font(Typeface.numerals(22, relativeTo: .title2, weight: .bold))
                    .foregroundStyle(Palette.accent)
                Text(info.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(info.detail)
                    .font(.caption2)
                    .foregroundStyle(Palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            } else {
                Duo(
                    primary: app.companion,
                    size: 46,
                    mood: sleepingNow || dark ? .sleep : .open,
                    look: CGPoint(x: 0, y: 0.4),
                    night: dark
                )
                Text(selectedStage.sleepRangeText)
                    .font(Typeface.numerals(17, relativeTo: .headline, weight: .bold))
                    .foregroundStyle(Crayon.ink(LogType.color(LogType.sleep)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(
                    avgSleep.map { L10n.t("实记 \(String(format: "%.1f", $0))h / 天", "Avg \(String(format: "%.1f", $0))h / day") }
                        ?? L10n.t("睡眠 · 含小睡", "Sleep w/ naps")
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Palette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
        }
        .padding(10)
    }

    private func hourInsight(hour: Int, stage: DailyRhythmStage) -> (title: String, detail: String) {
        let sleepSpanHalf = stage.sleepMidHours / 2.0
        let nightStart = 20.5
        let nightEnd = (nightStart + min(11.0, sleepSpanHalf * 1.45)).truncatingRemainder(dividingBy: 24.0)
        let h = Double(hour)
        let isNightSleep = h >= nightStart || h < nightEnd
        if isNightSleep {
            return (
                L10n.t("夜间睡眠", "Night Sleep"),
                L10n.t("低暗暖光 · 安静照护", "Dim amber light · calm care")
            )
        }
        if hour >= 12 && hour < 15 && stage != .threeYears {
            return (
                L10n.t("午间小睡窗", "Midday Nap"),
                L10n.t("计入 \(stage.sleepRangeText) 总睡", "In \(stage.sleepRangeText) total")
            )
        }
        if stage == .newborn || stage == .infant {
            return (
                L10n.t("清醒小段互动", "Awake Play Burst"),
                L10n.t("穿插短时趴玩与小睡", "Mix short tummy time & naps")
            )
        }
        return (
            L10n.t("清醒探索时段", "Active Exploration"),
            stage == .threeYears
                ? L10n.t("全天累计 180 分钟多类运动", "Build toward 180m daily play")
                : L10n.t("地面游戏 · 少久坐", "Floor play · limit sitting")
        )
    }

    private func loomAccessibilityValue(avgSleep: Double?) -> String {
        let base = "\(selectedStage.sleepRangeText) \(selectedStage.sleepNote); \(selectedStage.activityHeadline); \(selectedStage.screenHeadline)"
        if let avgSleep {
            return base + L10n.t("；近 7 天日均睡 \(String(format: "%.1f", avgSleep)) 小时", "; 7-day average sleep \(String(format: "%.1f", avgSleep)) hours")
        }
        return base
    }

    // MARK: - 3. Sleep Rhythm Dimension Card

    private func sleepCard(comparison: DailyRhythmComparison, showLive: Bool, dark: Bool) -> some View {
        let c = LogType.color(LogType.sleep)
        let ink = dark ? c : Crayon.ink(c)

        return VStack(alignment: .leading, spacing: 12) {
            cardHeader(
                symbol: LogType.symbol(LogType.sleep),
                color: c,
                title: L10n.t("睡眠时长", "Sleep"),
                badge: selectedStage.sleepRangeText
            )

            // 24h horizontal band scale showing WHO min..max + live 7-day average dot
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    let w = geo.size.width
                    let minX = CGFloat(selectedStage.sleepMinHours) / 24.0 * w
                    let maxX = CGFloat(selectedStage.sleepMaxHours) / 24.0 * w

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(c.opacity(dark ? 0.16 : 0.12))
                            .frame(height: 14)

                        // Recommended range pill
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [c.opacity(0.65), c],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(12, maxX - minX), height: 14)
                            .offset(x: minX)

                        // Live 7-day average marker when available
                        if showLive, let avg = comparison.avgSleepHours {
                            let clamped = min(23.5, max(0.5, avg))
                            let dotX = CGFloat(clamped) / 24.0 * w
                            Circle()
                                .fill(Palette.bead)
                                .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                                .shadow(color: Palette.bead.opacity(0.55), radius: 3)
                                .frame(width: 16, height: 16)
                                .offset(x: max(0, min(w - 16, dotX - 8)))
                        }
                    }
                }
                .frame(height: 16)

                HStack {
                    ForEach([0, 6, 12, 18, 24], id: \.self) { hr in
                        Text("\(hr)h")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Palette.secondaryText)
                            .monospacedDigit()
                        if hr < 24 { Spacer() }
                    }
                }
            }

            if showLive, let line = comparison.sleepComparisonLine(for: selectedStage) {
                HStack(spacing: 6) {
                    Circle().fill(Palette.bead).frame(width: 7, height: 7)
                    Text(line)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(dark ? Palette.amber : Crayon.ink(Palette.bead))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.bead.opacity(dark ? 0.16 : 0.12)))
            } else {
                Text(L10n.t("包含夜间主睡眠与白天所有小睡。每个孩子需要的睡眠天生有差异，区间只是温和的参考。", "Includes overnight sleep and daytime naps. Every child has natural variation; this range is a gentle guide."))
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Contextual bridge buttons
            FlowRow(spacing: 8, lineSpacing: 8) {
                if let router {
                    Button {
                        TactileEngine.shared.beadClick()
                        router.openBedsideLamp()
                    } label: {
                        Label(L10n.t("床头夜灯与声景", "Bedside Lamp"), systemImage: "lamp.desk.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(dark ? Palette.amber : Crayon.ink(Palette.amberDeep))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Palette.amber.opacity(dark ? 0.22 : 0.16)))
                            .pillHitTarget()
                    }
                    .buttonStyle(.toy)
                } else {
                    Button {
                        TactileEngine.shared.beadClick()
                        if let url = URL(string: "mossling://lamp") { openURL(url) }
                    } label: {
                        Label(L10n.t("床头夜灯与声景", "Bedside Lamp"), systemImage: "lamp.desk.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(dark ? Palette.amber : Crayon.ink(Palette.amberDeep))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Palette.amber.opacity(dark ? 0.22 : 0.16)))
                            .pillHitTarget()
                    }
                    .buttonStyle(.toy)
                }

                if app.journal {
                    NavigationLink(value: LampRoute.stats) {
                        Label(L10n.t("查看 7 天节律盘", "Open 7d Rhythm Dial"), systemImage: "dial.medium.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(c.opacity(dark ? 0.22 : 0.14)))
                            .pillHitTarget()
                    }
                    .buttonStyle(.toy)
                }
            }
        }
        .padding(LayoutSpec.cardPad)
        .printCard(radius: Radius.card)
    }

    // MARK: - 4. Awake & Active Play Card

    private func awakePlayCard(comparison: DailyRhythmComparison, dark: Bool) -> some View {
        let c = Crayon.tangerine
        let ink = dark ? c : Crayon.ink(c)

        return VStack(alignment: .leading, spacing: 12) {
            cardHeader(
                symbol: "figure.walk",
                color: c,
                title: L10n.t("清醒与活动", "Awake & Play"),
                badge: selectedStage.activityHeadline
            )

            // Tactile visual meter matching the exact stage
            if selectedStage == .newborn || selectedStage == .infant {
                // 6 x 5-minute tummy-time sun-beads = 30 min spread across the day
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { idx in
                        VStack(spacing: 3) {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [c.mix(with: .white, by: 0.35), c],
                                        center: UnitPoint(x: 0.35, y: 0.3),
                                        startRadius: 0,
                                        endRadius: 12
                                    )
                                )
                                .frame(width: 18, height: 18)
                                .shadow(color: c.opacity(0.28), radius: 2, y: 1)
                            Text("5m")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Palette.secondaryText)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                        if idx == 2 {
                            Divider().frame(height: 22)
                        }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(c.opacity(dark ? 0.14 : 0.08)))
            } else {
                // 6 x 30-min movement blocks = 180 min; for 3+ yrs, 2 blocks (60 min) highlighted as energetic
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        ForEach(0..<6, id: \.self) { idx in
                            let vigorous = selectedStage == .threeYears && idx >= 4
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(vigorous ? Crayon.cherry : c.opacity(0.85))
                                .frame(height: 14)
                                .overlay {
                                    if vigorous {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.45), lineWidth: 0.75)
                                    }
                                }
                        }
                    }
                    HStack {
                        Text(L10n.t("6 × 30 分钟分散全天 = 180 分钟", "6 × 30m spread across the day = 180m"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Palette.secondaryText)
                        Spacer(minLength: 4)
                        if selectedStage == .threeYears {
                            Text(L10n.t("含 60m 畅快跑跳", "60m energetic"))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(dark ? Crayon.cherry : Crayon.ink(Crayon.cherry))
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(c.opacity(dark ? 0.14 : 0.08)))
            }

            Text(selectedStage.activityDetail)
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            FlowRow(spacing: 8, lineSpacing: 8) {
                Button {
                    TactileEngine.shared.beadClick()
                    let mode: ToyboxMode = selectedStage == .newborn ? .contrast : .xylophone
                    if let router {
                        router.openExplore(.toybox(mode))
                    } else if let url = URL(string: "mossling://toybox/\(mode.rawValue)") {
                        openURL(url)
                    }
                } label: {
                    Label(
                        selectedStage == .newborn ? L10n.t("打开黑白视卡", "Open Contrast Cards") : L10n.t("打开感官玩具盒", "Open Sensory Toybox"),
                        systemImage: selectedStage == .newborn ? "circle.lefthalf.filled" : "music.note"
                    )
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(c.opacity(dark ? 0.22 : 0.14)))
                    .pillHitTarget()
                }
                .buttonStyle(.toy)

                if comparison.todayPlayCount > 0 {
                    Text(L10n.t("今日已记共玩 ×\(comparison.todayPlayCount)", "Today's plays ×\(comparison.todayPlayCount)"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(dark ? Palette.amber : Crayon.ink(Palette.bead))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Palette.bead.opacity(dark ? 0.20 : 0.16)))
                }
            }
        }
        .padding(16)
        .printCard(radius: Radius.card)
    }

    // MARK: - 5. Screen Boundary Card

    private func screenBoundaryCard(dark: Bool) -> some View {
        let zeroScreens = selectedStage.screenLimitMinutes == 0
        let c = zeroScreens ? Crayon.teal : Crayon.pebble

        return VStack(alignment: .leading, spacing: 10) {
            cardHeader(
                symbol: "iphone.slash",
                color: c,
                title: L10n.t("屏幕时间边界", "Screen Boundary"),
                badge: selectedStage.screenHeadline
            )

            // Visual 0–120m gauge
            HStack(spacing: 10) {
                if zeroScreens {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.wave.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Palette.accent)
                        Text(L10n.t("0 分钟 · 用声音、表情与玩具回应", "0 min · Voice, faces & real objects"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(c.opacity(dark ? 0.25 : 0.18))
                                .frame(height: 10)
                            Capsule()
                                .fill(Palette.accent)
                                .frame(width: geo.size.width * 0.5, height: 10)
                        }
                    }
                    .frame(height: 10)
                    Text("≤ 1h / 24h")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Palette.secondaryText)
                        .monospacedDigit()
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(c.opacity(dark ? 0.16 : 0.10)))

            Text(selectedStage.screenDetail)
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .printCard(radius: Radius.card)
    }

    // MARK: - 6. Intact WHO Citation Card (Never Corrupted by Mid-Sentence String Stripping)

    private func whoReferenceCard(rawText: String, dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "books.vertical.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.accent)
                Text(L10n.t("WHO 公开指南原文", "WHO Public Guideline Note"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.accent)
            }
            Text(rawText)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.t(
                "依据世界卫生组织《5 岁以下儿童身体活动、久坐行为和睡眠指南》（2019）。",
                "Based on WHO Guidelines on Physical Activity, Sedentary Behaviour and Sleep for Children Under 5 Years of Age (2019)."
            ))
            .font(.caption)
            .foregroundStyle(Palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                .fill(dark ? Palette.lampCard.opacity(0.85) : Palette.fill.opacity(0.75))
        )
    }

    // MARK: - Shared Helpers

    @ViewBuilder
    private func cardHeader(symbol: String, color: Color, title: String, badge: String) -> some View {
        let badgePill = Text(badge)
            .font(.caption.weight(.bold))
            .foregroundStyle(lamp ? Palette.lampInk : Crayon.ink(color))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(lamp || scheme == .dark ? 0.24 : 0.14)))
            .fixedSize(horizontal: false, vertical: true)

        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    IconTile(symbol: symbol, color: color, size: 28, round: true)
                    Text(title).font(.headline).foregroundStyle(.primary)
                }
                badgePill
            }
        } else {
            HStack(spacing: 8) {
                IconTile(symbol: symbol, color: color, size: 28, round: true)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                badgePill
            }
        }
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Palette.secondaryText)
        }
    }
}

// MARK: - 24-Hour Circadian Bead Loom Canvas

private struct CircadianLoomCanvas: View {
    let stage: DailyRhythmStage
    let avgSleepHours: Double?
    let inspectedHour: Int?
    let dark: Bool

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerR = side * 0.36
            let liveR = side * 0.27
            let beadR = side * 0.405

            let sleepColor = LogType.color(LogType.sleep)
            let playColor = Crayon.tangerine

            // Base 24h track represents Awake & Active time; Sleep arcs layer directly on top
            // so shrinking sleep across 0–3 yrs naturally reveals expanding daytime play!
            let trackRect = CGRect(x: center.x - outerR, y: center.y - outerR, width: outerR * 2, height: outerR * 2)
            ctx.stroke(Path(ellipseIn: trackRect), with: .color(playColor.opacity(dark ? 0.58 : 0.48)), lineWidth: 12)

            // Night sleep arc centered around 01:00 + representative daytime nap window
            let napFraction: Double = switch stage {
            case .newborn: 0.42
            case .infant: 0.30
            case .oneYear, .twoYears: 0.18
            case .threeYears: 0.10
            }

            let minNightHrs = Double(stage.sleepMinHours) * (1.0 - napFraction)
            let maxNightHrs = Double(stage.sleepMaxHours) * (1.0 - napFraction)
            let minNapHrs = Double(stage.sleepMinHours) * napFraction
            let maxNapHrs = Double(stage.sleepMaxHours) * napFraction

            // Draw max range (translucent outer halo) then min range (solid sleep ribbon)
            drawSleepArc(&ctx, center: center, radius: outerR, centerHour: 1.0, spanHours: maxNightHrs, color: sleepColor.opacity(dark ? 0.40 : 0.32), width: 16)
            drawSleepArc(&ctx, center: center, radius: outerR, centerHour: 1.0, spanHours: minNightHrs, color: sleepColor, width: 14)

            if maxNapHrs >= 0.8 {
                drawSleepArc(&ctx, center: center, radius: outerR, centerHour: 13.5, spanHours: maxNapHrs, color: sleepColor.opacity(dark ? 0.38 : 0.30), width: 16)
                drawSleepArc(&ctx, center: center, radius: outerR, centerHour: 13.5, spanHours: minNapHrs, color: sleepColor.opacity(0.92), width: 14)
            }

            // Inner live 7-day average ring when recorded data is present
            let innerRect = CGRect(x: center.x - liveR, y: center.y - liveR, width: liveR * 2, height: liveR * 2)
            ctx.stroke(Path(ellipseIn: innerRect), with: .color(Palette.outline.opacity(dark ? 0.24 : 0.18)), lineWidth: 5)
            if let avgSleepHours, avgSleepHours > 0 {
                let avgClamped = min(24.0, avgSleepHours)
                let avgNight = avgClamped * (1.0 - napFraction)
                let avgNap = avgClamped * napFraction
                drawSleepArc(&ctx, center: center, radius: liveR, centerHour: 1.0, spanHours: avgNight, color: Palette.bead, width: 6)
                if avgNap >= 0.5 {
                    drawSleepArc(&ctx, center: center, radius: liveR, centerHour: 13.5, spanHours: avgNap, color: Palette.bead, width: 6)
                }
            }

            // 24 hourly Montessori beads around the rim
            for h in 0..<24 {
                let a = RhythmDialModel.angle(forHour: Double(h))
                let pt = CGPoint(x: center.x + cos(a) * beadR, y: center.y + sin(a) * beadR)
                let isMajor = h % 6 == 0
                let isInspected = inspectedHour == h
                let d: CGFloat = isInspected ? 11 : (isMajor ? 7.5 : 4.5)
                let r = CGRect(x: pt.x - d / 2, y: pt.y - d / 2, width: d, height: d)
                let col: Color = isInspected
                    ? Palette.accent
                    : (h == 12 ? Crayon.tangerine : (h == 0 ? sleepColor : Palette.secondaryText.opacity(isMajor ? 0.72 : 0.35)))
                ctx.fill(Path(ellipseIn: r), with: .color(col))
            }

            // Cardinal labels: 12 noon top, 00 midnight bottom
            let topPt = CGPoint(x: center.x, y: center.y - beadR - 13)
            let botPt = CGPoint(x: center.x, y: center.y + beadR + 13)
            let leftPt = CGPoint(x: center.x - beadR - 14, y: center.y)
            let rightPt = CGPoint(x: center.x + beadR + 14, y: center.y)
            ctx.draw(Text("12").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(Crayon.ink(Crayon.tangerine)), at: topPt)
            ctx.draw(Text("00").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(Crayon.ink(sleepColor)), at: botPt)
            ctx.draw(Text("06").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(Palette.secondaryText), at: leftPt)
            ctx.draw(Text("18").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(Palette.secondaryText), at: rightPt)

            // Interactive probe beam when user touches/drags an hour
            if let h = inspectedHour {
                let a = RhythmDialModel.angle(forHour: Double(h) + 0.5)
                var beam = Path()
                beam.move(to: CGPoint(x: center.x + cos(a) * (side * 0.21), y: center.y + sin(a) * (side * 0.21)))
                beam.addLine(to: CGPoint(x: center.x + cos(a) * (beadR - 2), y: center.y + sin(a) * (beadR - 2)))
                ctx.stroke(beam, with: .color(Palette.accent), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        }
        .accessibilityHidden(true)
    }

    private func drawSleepArc(
        _ ctx: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        centerHour: Double,
        spanHours: Double,
        color: Color,
        width: CGFloat
    ) {
        let start = centerHour - spanHours / 2.0
        let end = centerHour + spanHours / 2.0
        drawHourArc(&ctx, center: center, radius: radius, startHour: start, endHour: end, color: color, width: width)
    }

    private func drawHourArc(
        _ ctx: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        startHour: Double,
        endHour: Double,
        color: Color,
        width: CGFloat
    ) {
        let a0 = RhythmDialModel.angle(forHour: startHour)
        let a1 = RhythmDialModel.angle(forHour: endHour)
        var p = Path()
        p.addArc(center: center, radius: radius, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
        ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
}
