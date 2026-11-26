import SwiftUI
import UIKit

/// Pure immutable snapshot of a child's current care shift for both the live preview and the 3× shareable Handover Poster.
struct HandoverSnapshot: Sendable {
    let babyName: String
    let ageText: String
    let dateLabel: String
    let timeLabel: String
    let activeTimerLine: String?
    let lastFeedHeadline: String
    let lastFeedDetail: String
    let lastSleepHeadline: String
    let lastSleepDetail: String
    let lastDiaperHeadline: String
    let lastDiaperDetail: String
    let todayHeadline: String
    let todayDetail: String
    let extraNote: String

    var plainText: String {
        let headerAge = ageText.isEmpty ? "" : " · \(ageText)"
        var lines: [String] = [
            L10n.t("【摸索台灯 · 照护交接】\(babyName)\(headerAge)（\(dateLabel) \(timeLabel)）",
                   "[Moss & Otto · Care Handover] \(babyName)\(headerAge) (\(dateLabel) \(timeLabel))")
        ]
        if let activeTimerLine {
            lines.append(activeTimerLine)
        }
        lines.append(L10n.t("上次喂奶：\(lastFeedHeadline)（\(lastFeedDetail)）", "Last feed: \(lastFeedHeadline) (\(lastFeedDetail))"))
        lines.append(L10n.t("上次醒来：\(lastSleepHeadline)（\(lastSleepDetail)）", "Last wake: \(lastSleepHeadline) (\(lastSleepDetail))"))
        lines.append(L10n.t("上次尿布：\(lastDiaperHeadline)（\(lastDiaperDetail)）", "Last diaper: \(lastDiaperHeadline) (\(lastDiaperDetail))"))
        lines.append(L10n.t("今日节奏：\(todayHeadline) · \(todayDetail)", "Today: \(todayHeadline) · \(todayDetail)"))
        if !extraNote.isEmpty {
            lines.append(L10n.t("交接备注：\(extraNote)", "Handover note: \(extraNote)"))
        }
        return lines.joined(separator: "\n")
    }

    @MainActor
    static func build(app: AppModel, journal: JournalStore, day: Day, now: Date = Date(), extraNote: String = "") -> HandoverSnapshot {
        let logs = journal.logs(on: day)
        let own = logs.filter { !$0.carriedOver(into: day) }
        let startMs = day.date.timeIntervalSince1970 * 1000
        let feeds = logs.feedCount(from: startMs)
        let sleepSec = logs.filter { $0.type == LogType.sleep }.reduce(0.0) { $0 + $1.seconds(on: day) }
        let diapers = own.filter { $0.type == LogType.diaper }
        let wet = diapers.filter { $0.detail == "wet" || $0.detail == "both" }.count
        let dirty = diapers.filter { $0.detail == "dirty" || $0.detail == "both" }.count

        let who = app.nickname.isEmpty ? L10n.t("宝宝", "Baby") : app.nickname
        let ageStr = app.age.map { L10n.ageText($0) } ?? ""
        let dateStr = L10n.isEnglish ? "\(Day.enMonths[day.m - 1]) \(day.d)" : day.md
        let clockStr = hm(now)

        let activeLine: String? = journal.timers.first.map { t in
            let status = L10n.timerStatus(t.type, side: t.side, paused: t.pausedAt != nil)
            let dur = L10n.duration(t.total(now.timeIntervalSince1970 * 1000))
            return L10n.t("进行中：\(status)（已 \(dur)）", "Active now: \(status) (\(dur))")
        }

        let lastFeedFact = LastFact.of(LogType.nurse, in: journal.logs)
        let lastFeedObj = journal.logs.feeds().last
        let lastFeedHead: String
        let lastFeedSub: String
        if let f = lastFeedObj {
            let at = lastFeedFact?.at ?? f.startDate
            lastFeedHead = L10n.agoText(at, now: now, precise: true)
            if f.isBottle, let ml = f.first.amount, ml > 0 {
                lastFeedSub = L10n.t("\(hm(at)) · 瓶喂 \(ml) 毫升", "\(hm(at)) · " + L10n.volume(ml: ml))
            } else {
                lastFeedSub = L10n.t("\(hm(at)) · 今日共 \(feeds) 次", "\(hm(at)) · \(feeds) today")
            }
        } else {
            lastFeedHead = "—"
            lastFeedSub = L10n.t("今日共 \(feeds) 次", "\(feeds) today")
        }

        let lastSleepDate = journal.last(LogType.sleep)
        let sleepStr = sleepSec > 0 ? L10n.duration(sleepSec) : "—"
        let lastSleepHead = lastSleepDate.map { L10n.agoText($0, now: now, precise: true) } ?? "—"
        let lastSleepSub = L10n.t("今日累计 \(sleepStr)", "Today total \(sleepStr)")

        let lastDiaperDate = journal.last(LogType.diaper)
        let lastDiaperHead = lastDiaperDate.map { L10n.agoText($0, now: now, precise: true) } ?? "—"
        let lastDiaperSub = L10n.t("湿 \(wet) · 便 \(dirty)", "\(wet) wet · \(dirty) dirty")

        let feedWord = feeds == 1 ? "feed" : "feeds"
        let diaperWord = diapers.count == 1 ? "diaper" : "diapers"
        let todayHead = L10n.t("喂 \(feeds) 次 · 尿布 \(diapers.count)", "\(feeds) \(feedWord) · \(diapers.count) \(diaperWord)")
        let latestSpecial = own.filter { $0.type == LogType.solid || $0.type == LogType.medicine || $0.type == LogType.temp }.max { $0.start < $1.start }
        let todaySub: String
        if let sp = latestSpecial {
            let detail = sp.detail?.isEmpty == false ? " · \(sp.detail!)" : ""
            todaySub = "\(LogType.name(sp.type))\(detail)"
        } else if let mo = app.babyMonth, let play = app.todayPlay(mo, journal) {
            todaySub = L10n.t("今日玩：\(play.name)", "Play: \(play.name)")
        } else {
            todaySub = L10n.t("节奏平稳 · 一切安好", "Calm rhythm today")
        }

        return HandoverSnapshot(
            babyName: who,
            ageText: ageStr,
            dateLabel: dateStr,
            timeLabel: clockStr,
            activeTimerLine: activeLine,
            lastFeedHeadline: lastFeedHead,
            lastFeedDetail: lastFeedSub,
            lastSleepHeadline: lastSleepHead,
            lastSleepDetail: lastSleepSub,
            lastDiaperHeadline: lastDiaperHead,
            lastDiaperDetail: lastDiaperSub,
            todayHeadline: todayHead,
            todayDetail: todaySub,
            extraNote: extraNote.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

/// Pure, testable geometry and haptic detent logic for the Swipe-to-Pass Lantern Handover ritual.
enum LanternPassMath {
    static let completionThreshold: Double = 0.88

    static func clampedProgress(_ raw: Double) -> Double {
        min(1.0, max(0.0, raw))
    }

    static func isPassed(_ progress: Double) -> Bool {
        clampedProgress(progress) >= completionThreshold
    }

    static func detentStep(for progress: Double) -> Int {
        min(4, max(0, Int((clampedProgress(progress) * 4.0).rounded())))
    }

    static func quadBezierPoint(t: Double, start: CGPoint, control: CGPoint, end: CGPoint) -> CGPoint {
        let u = 1.0 - clampedProgress(t)
        let s = clampedProgress(t)
        let x = u * u * Double(start.x) + 2.0 * u * s * Double(control.x) + s * s * Double(end.x)
        let y = u * u * Double(start.y) + 2.0 * u * s * Double(control.y) + s * s * Double(end.y)
        return CGPoint(x: x, y: y)
    }
}

/// 「家庭交接卡 / Care Handover Studio」 — Offline shift handover card for partners, grandparents, or nannies.
/// Renders a crisp 3× cotton-paper visual card image or copies clean plain text with zero cloud accounts required.
struct HandoverSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp

    let day: Day
    let previewNow: Date?

    @State private var note: String
    @State private var copied = false
    @State private var copiedWebLink = false
    @State private var passProgress: Double
    @State private var lanternPassed: Bool

    init(day: Day, previewNow: Date? = nil, initialNote: String = "", initialPassProgress: Double = 0.14) {
        self.day = day
        self.previewNow = previewNow
        _note = State(initialValue: initialNote)
        let clamped = LanternPassMath.clampedProgress(initialPassProgress)
        _passProgress = State(initialValue: clamped)
        _lanternPassed = State(initialValue: LanternPassMath.isPassed(clamped))
    }

    private var quickNotes: [String] {
        L10n.isEnglish
            ? ["Just burped · ready for nap", "Bottle warmed in kitchen", "Great appetite today", "Ready for play after wake"]
            : ["刚拍完嗝，准备小睡", "奶瓶已温好在厨房", "今天胃口很好", "醒来后可以一起玩"]
    }

    var body: some View {
        let dark = lamp || scheme == .dark

        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { tl in
                let currentNow = previewNow ?? tl.date
                let snap = HandoverSnapshot.build(app: app, journal: j, day: day, now: currentNow, extraNote: note)
                let webURL = HandoverWebCodec.encodeURL(from: snap, now: currentNow)
                let poster = RenderedPoster {
                    let card = HandoverPoster(snapshot: snap)
                    let renderer = ImageRenderer(content: card)
                    renderer.scale = 3.0
                    return renderer.uiImage
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // Live cotton-paper handover card preview with interactive Swipe-to-Pass Lantern Ritual
                        HandoverCardContent(
                            snapshot: snap,
                            companion: app.companion,
                            dark: dark,
                            passProgress: $passProgress,
                            lanternPassed: $lanternPassed
                        )
                        .printCard(radius: Radius.card)

                        // Optional handover note with 4 balanced quick chips
                        VStack(alignment: .leading, spacing: 7) {
                            Text(L10n.t("给下一位照护者留一句（可选）", "Quick note for next caregiver (optional)"))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.primary)

                            LazyVGrid(
                                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                                spacing: 7
                            ) {
                                ForEach(quickNotes, id: \.self) { chip in
                                    let active = note == chip
                                    Button {
                                        TactileEngine.shared.beadClick()
                                        note = active ? "" : chip
                                    } label: {
                                        Text(chip)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(active ? .white : .primary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                            .frame(maxWidth: .infinity)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .background(Capsule().fill(active ? Palette.accentFill : (dark ? Palette.lampCard : Palette.card)))
                                            .overlay(Capsule().strokeBorder(Palette.outline.opacity(active ? 0 : 0.3), lineWidth: 0.75))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            TextField(L10n.t("例如：半小时前刚吃过维生素 D", "e.g. Vitamin D given 30m ago"), text: $note)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(dark ? Palette.lampCard : Palette.card))
                                .overlay(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).strokeBorder(Palette.outline.opacity(0.28), lineWidth: 0.75))
                        }

                        // Compact Side-by-Side Share Visual Card & Copy Text Actions
                        HStack(spacing: 10) {
                            ShareLink(
                                item: poster,
                                preview: SharePreview(
                                    L10n.t("\(snap.babyName)的照护交接卡", "\(snap.babyName)'s Care Handover Card")
                                )
                            ) {
                                Label(L10n.t("分享交接卡", "Share Card"), systemImage: "square.and.arrow.up")
                                    .font(.subheadline.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                            }
                            .buttonStyle(.vinyl(Palette.accentFill, prominent: true))

                            Button {
                                UIPasteboard.general.string = snap.plainText
                                TactileEngine.shared.goldChime()
                                withAnimation(.snappy) { copied = true }
                                Task { @MainActor in
                                    try? await Task.sleep(for: .seconds(2))
                                    withAnimation(.snappy) { copied = false }
                                }
                            } label: {
                                Label(
                                    copied ? L10n.t("已复制", "Copied") : L10n.t("复制文字", "Copy Text"),
                                    systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc"
                                )
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                            }
                            .buttonStyle(.vinyl(copied ? Crayon.leaf : Crayon.caramel))
                        }

                        if let webURL {
                            HStack(spacing: 10) {
                                ShareLink(
                                    item: webURL,
                                    subject: Text(L10n.t("\(snap.babyName)的照护交接灯牌", "\(snap.babyName)'s Care Handover Beacon")),
                                    message: Text(L10n.t("不用下载 App，手机浏览器点开即看最新喂睡与尿布交接：", "View the latest handover right in your browser (no download needed):"))
                                ) {
                                    Label(L10n.t("发给安卓家人（免下载灯牌）", "Send Web Beacon (Android)"), systemImage: "safari.fill")
                                        .font(.subheadline.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                }
                                .buttonStyle(.vinyl(Palette.rod))

                                Button {
                                    UIPasteboard.general.url = webURL
                                    TactileEngine.shared.beadClick()
                                    withAnimation(.snappy) { copiedWebLink = true }
                                    Task { @MainActor in
                                        try? await Task.sleep(for: .seconds(2))
                                        withAnimation(.snappy) { copiedWebLink = false }
                                    }
                                } label: {
                                    Image(systemName: copiedWebLink ? "checkmark.circle.fill" : "link")
                                        .font(.subheadline.weight(.bold))
                                        .frame(width: 46, height: 42)
                                }
                                .buttonStyle(.vinyl(copiedWebLink ? Crayon.leaf : Palette.rod))
                                .accessibilityLabel(L10n.t("复制免下载网页交接链接", "Copy browser handover link"))
                            }
                        }

                        Text(L10n.t("图片、文字与网页灯牌链接均在本机即时生成，数据仅编码在网址 # 之后，不经过云端服务器；安卓手机点开即看。", "Generated on-device with zero server uploads — browser beacon data stays strictly inside the # URL anchor for Android & WeChat."))
                            .font(.caption2)
                            .foregroundStyle(Palette.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .pageBackground(tone: Crayon.sunflower)
            .navigationTitle(L10n.t("交接给下一位点灯人", "Passing the Lantern"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("完成", "Done")) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

/// Shared visual layout for the live preview inside `HandoverSheet`.
private struct HandoverCardContent: View {
    let snapshot: HandoverSnapshot
    let companion: Kind
    let dark: Bool
    @Binding var passProgress: Double
    @Binding var lanternPassed: Bool
    @State private var lastDetent = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottom) {
                GeometryReader { g in
                    let w = max(1, g.size.width)
                    PassingLanternArt(dark: dark, progress: passProgress, passed: lanternPassed)
                        .frame(width: g.size.width, height: g.size.height)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 2)
                                .onChanged { value in
                                    let normX = (value.location.x - w * 0.28) / (w * 0.44)
                                    let clamped = LanternPassMath.clampedProgress(Double(normX))
                                    passProgress = clamped
                                    let det = LanternPassMath.detentStep(for: clamped)
                                    if det != lastDetent {
                                        lastDetent = det
                                        TactileEngine.shared.dimmerTick()
                                    }
                                    if LanternPassMath.isPassed(clamped) && !lanternPassed {
                                        lanternPassed = true
                                        TactileEngine.shared.goldChime()
                                    } else if !LanternPassMath.isPassed(clamped) && lanternPassed {
                                        lanternPassed = false
                                    }
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                                        if LanternPassMath.isPassed(passProgress) {
                                            passProgress = 1.0
                                            lanternPassed = true
                                        }
                                    }
                                }
                        )
                }
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.t("交接传灯金珠滑块", "Handover lantern slider"))
                .accessibilityValue(
                    lanternPassed
                        ? L10n.t("已递出，100%", "Lantern passed, 100%")
                        : L10n.t("进度 \(Int(passProgress * 100))%", "\(Int(passProgress * 100)) percent")
                )
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        withAnimation(.snappy) {
                            passProgress = min(1.0, passProgress + 0.34)
                            TactileEngine.shared.dimmerTick()
                            if LanternPassMath.isPassed(passProgress) {
                                passProgress = 1.0
                                lanternPassed = true
                                TactileEngine.shared.goldChime()
                            }
                        }
                    case .decrement:
                        withAnimation(.snappy) {
                            passProgress = max(0.0, passProgress - 0.34)
                            lanternPassed = false
                            TactileEngine.shared.dimmerTick()
                        }
                    @unknown default:
                        break
                    }
                }

                HStack(spacing: 5) {
                    GoldBead(size: 7)
                    Text(
                        lanternPassed
                            ? L10n.t("暖灯已递给下一位点灯人", "Lantern passed to next keeper")
                            : L10n.t("向右滑金珠 · 把暖灯递给 Mochi", "Slide gold bead right to pass light")
                    )
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(lanternPassed ? Crayon.ink(Palette.bead) : (dark ? Palette.lampInk : Palette.text))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(lanternPassed ? Palette.beadLight.opacity(0.94) : (dark ? Color(hex: 0x1A2347).opacity(0.84) : .white.opacity(0.90)))
                )
                .overlay(Capsule().strokeBorder(Palette.amber.opacity(0.35), lineWidth: 0.75))
                .padding(.bottom, 6)
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                    .strokeBorder(Palette.amber.opacity(dark ? 0.25 : 0.30), lineWidth: 0.9)
            )

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("\(snapshot.babyName) · 照护交接卡", "\(snapshot.babyName) · Care Handover"))
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(
                        snapshot.ageText.isEmpty
                            ? "\(snapshot.dateLabel) · \(snapshot.timeLabel)"
                            : "\(snapshot.ageText) · \(snapshot.dateLabel) \(snapshot.timeLabel)"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.secondaryText)
                }
                Spacer(minLength: 4)
            }

            if let active = snapshot.activeTimerLine {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Palette.amber)
                        .frame(width: 8, height: 8)
                    Text(active)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(Palette.amber.opacity(dark ? 0.18 : 0.16)))
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                statBox(
                    symbol: LogType.symbol(LogType.nurse),
                    color: Crayon.pink,
                    title: L10n.t("上次喂奶", "Last Feed"),
                    value: snapshot.lastFeedHeadline,
                    detail: snapshot.lastFeedDetail,
                    dark: dark
                )
                statBox(
                    symbol: LogType.symbol(LogType.sleep),
                    color: Crayon.lilac,
                    title: L10n.t("上次醒来", "Last Wake"),
                    value: snapshot.lastSleepHeadline,
                    detail: snapshot.lastSleepDetail,
                    dark: dark
                )
                statBox(
                    symbol: LogType.symbol(LogType.diaper),
                    color: Crayon.sky,
                    title: L10n.t("上次尿布", "Last Diaper"),
                    value: snapshot.lastDiaperHeadline,
                    detail: snapshot.lastDiaperDetail,
                    dark: dark
                )
                statBox(
                    symbol: "sun.max.fill",
                    color: Crayon.leaf,
                    title: L10n.t("今日节奏", "Today's Rhythm"),
                    value: snapshot.todayHeadline,
                    detail: snapshot.todayDetail,
                    dark: dark
                )
            }

            if !snapshot.extraNote.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "quote.opening")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Palette.accent)
                        .padding(.top, 2)
                    Text(snapshot.extraNote)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(Palette.bead.opacity(dark ? 0.14 : 0.16)))
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Palette.bead.opacity(dark ? 0.08 : 0.09), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func statBox(symbol: String, color: Color, title: String, value: String, detail: String, dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                IconTile(symbol: symbol, color: color, size: 22, round: true)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
            }
            Text(value)
                .font(Typeface.numerals(17, relativeTo: .headline, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(Palette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(9)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                .fill(color.opacity(dark ? 0.14 : 0.11))
        )
    }
}

/// Synchronous Kid's Picture-Book die-cut sticker diorama showing canonical white-outlined Otto extending a
/// Scandinavian crayon-orange dashed passing arc & warm amber lantern beads toward white-outlined Mochi.
struct PassingLanternArt: View {
    let dark: Bool
    var progress: Double = 0.50
    var passed: Bool = false

    var body: some View {
        let t = LanternPassMath.clampedProgress(progress)
        let ottoImg = Perf.noArt ? nil : (ArtCache.shared.cached("ip_otto_idle.webp", maxPixel: 320) ?? ArtCache.shared.image("ip_otto_idle.webp", maxPixel: 320))
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let groundY = h * 0.80

            // Picture-book backdrop matching official 146 step illustrations
            let skyTop = dark ? Color(hex: 0x131B38) : Color(hex: 0xFFFDF8)
            let skyBot = dark ? Color(hex: 0x1A2347) : Color(hex: 0xFDF9EF)
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(Gradient(colors: [skyTop, skyBot]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h))
            )

            // Centered soft butter-cream sun disc halo
            let discR = min(w, h) * 0.44
            let discCenter = CGPoint(x: w * 0.50, y: h * 0.50)
            ctx.fill(
                Path(ellipseIn: CGRect(x: discCenter.x - discR, y: discCenter.y - discR, width: discR * 2, height: discR * 2)),
                with: .color(dark ? Palette.amber.opacity(0.08) : Color(hex: 0xFEF3D6))
            )

            // Soft Scandinavian butter-yellow ground band
            ctx.fill(
                Path(CGRect(x: 0, y: groundY, width: w, height: h - groundY)),
                with: .color(dark ? Color(hex: 0x1F2A52) : Color(hex: 0xFCE5AC))
            )

            // Paper mat plate bridging Otto and Mochi
            let matRect = CGRect(x: w * 0.16, y: groundY - 4, width: w * 0.68, height: 10)
            ctx.fill(
                RoundedRectangle(cornerRadius: 5, style: .continuous).path(in: matRect),
                with: .color(dark ? Color(hex: 0x2F3B68) : Color(hex: 0xD2C6E3))
            )

            let ottoCenterX = w * 0.30
            let mochiCenterX = w * 0.70

            // Physically migrating warm light pool gliding across the mat from Otto toward Mochi
            let poolX = ottoCenterX + (mochiCenterX - ottoCenterX) * CGFloat(t)
            ctx.fill(
                Path(ellipseIn: CGRect(x: poolX - w * 0.18, y: groundY - 12, width: w * 0.36, height: 24)),
                with: .radialGradient(
                    Gradient(colors: [Palette.amber.opacity(passed ? 0.55 : 0.38), Palette.amber.opacity(0)]),
                    center: CGPoint(x: poolX, y: groundY),
                    startRadius: 2,
                    endRadius: w * 0.18
                )
            )

            // Warm Scandinavian crayon-orange dashed handover arrow arcing Otto -> Mochi
            let arcStart = CGPoint(x: ottoCenterX + w * 0.10, y: h * 0.28)
            let arcEnd = CGPoint(x: mochiCenterX - w * 0.10, y: h * 0.34)
            let arcCtrl = CGPoint(x: w * 0.50, y: h * 0.14)
            var passArc = Path()
            passArc.move(to: arcStart)
            passArc.addQuadCurve(to: arcEnd, control: arcCtrl)
            ctx.stroke(
                passArc,
                with: .color((dark ? Palette.amber : Crayon.tangerine).opacity(0.45)),
                style: StrokeStyle(lineWidth: 3.0, lineCap: .round, lineJoin: .round, dash: [8, 6])
            )

            // Lit gold trail tracing traveled progress behind the bead
            var litTrail = Path()
            litTrail.move(to: arcStart)
            let steps = 16
            for i in 1...steps {
                let st = t * Double(i) / Double(steps)
                litTrail.addLine(to: LanternPassMath.quadBezierPoint(t: st, start: arcStart, control: arcCtrl, end: arcEnd))
            }
            ctx.stroke(
                litTrail,
                with: .color(Palette.bead),
                style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round)
            )

            // Arrowhead nib
            var head = Path()
            head.move(to: CGPoint(x: arcEnd.x - 10, y: arcEnd.y - 6))
            head.addLine(to: arcEnd)
            head.addLine(to: CGPoint(x: arcEnd.x - 9, y: arcEnd.y + 7))
            ctx.stroke(head, with: .color(passed ? Palette.bead : (dark ? Palette.amber : Crayon.tangerine)), style: StrokeStyle(lineWidth: 3.4, lineCap: .round, lineJoin: .round))

            // Glowing golden lantern bead smoothly riding along the Bezier passing arc
            let beadCenter = LanternPassMath.quadBezierPoint(t: t, start: arcStart, control: arcCtrl, end: arcEnd)
            ctx.fill(
                Path(ellipseIn: CGRect(x: beadCenter.x - 18, y: beadCenter.y - 18, width: 36, height: 36)),
                with: .radialGradient(Gradient(colors: [Palette.amber.opacity(passed ? 0.65 : 0.48), .clear]), center: beadCenter, startRadius: 2, endRadius: 18)
            )
            ctx.fill(Path(ellipseIn: CGRect(x: beadCenter.x - 7, y: beadCenter.y - 7, width: 14, height: 14)), with: .color(Palette.bead))
            ctx.stroke(Path(ellipseIn: CGRect(x: beadCenter.x - 7, y: beadCenter.y - 7, width: 14, height: 14)), with: .color(.white.opacity(0.90)), lineWidth: 1.8)

            // Contact shadows under both companions
            ctx.fill(Path(ellipseIn: CGRect(x: ottoCenterX - 28, y: groundY - 4, width: 56, height: 9)), with: .color(.black.opacity(dark ? 0.35 : 0.12)))
            ctx.fill(Path(ellipseIn: CGRect(x: mochiCenterX - 26, y: groundY - 4, width: 52, height: 9)), with: .color(.black.opacity(dark ? 0.35 : 0.12)))

            // Canonical Otto (zero hands, live warm glow)
            let spriteH = h * 0.62
            if let ottoImg {
                let ratio = ottoImg.size.width / max(1, ottoImg.size.height)
                let sw = spriteH * ratio
                let rect = CGRect(x: ottoCenterX - sw * 0.5, y: groundY - spriteH + 4, width: sw, height: spriteH)
                ctx.draw(Image(uiImage: ottoImg), in: rect)
            } else {
                let ottoRect = CGRect(x: ottoCenterX - 23, y: groundY - 56, width: 46, height: 56)
                let ottoBody = RoundedRectangle(cornerRadius: 22, style: .continuous).path(in: ottoRect)
                ctx.fill(ottoBody, with: .color(Palette.rod))
                ctx.stroke(ottoBody, with: .color(.white), lineWidth: 3)
            }

            // Celebratory warm lantern aura wrapping Mochi once handover completes
            if passed {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: mochiCenterX - 46, y: groundY - 68, width: 92, height: 76)),
                    with: .radialGradient(Gradient(colors: [Palette.amber.opacity(0.42), .clear]), center: CGPoint(x: mochiCenterX, y: groundY - 30), startRadius: 4, endRadius: 46)
                )
            }

            // Matching white die-cut sticker Mochi (warm ivory pebble + matte coral knit beanie, zero blush)
            let mochiW: CGFloat = min(68, w * 0.17)
            let mochiH: CGFloat = mochiW * 0.88
            let mochiBodyRect = CGRect(x: mochiCenterX - mochiW / 2, y: groundY - mochiH, width: mochiW, height: mochiH)
            let beanieRect = CGRect(x: mochiCenterX - mochiW * 0.44, y: mochiBodyRect.minY - mochiH * 0.24, width: mochiW * 0.88, height: mochiH * 0.42)
            let bodyPath = RoundedRectangle(cornerRadius: mochiH * 0.46, style: .continuous).path(in: mochiBodyRect)
            let beaniePath = RoundedRectangle(cornerRadius: mochiH * 0.20, style: .continuous).path(in: beanieRect)

            ctx.stroke(bodyPath, with: .color(dark ? Color(hex: 0xF3ECE0).opacity(0.85) : .white), style: StrokeStyle(lineWidth: 6.5, lineJoin: .round))
            ctx.stroke(beaniePath, with: .color(dark ? Color(hex: 0xF3ECE0).opacity(0.85) : .white), style: StrokeStyle(lineWidth: 6.5, lineJoin: .round))

            ctx.fill(
                bodyPath,
                with: .linearGradient(Gradient(colors: [Color(hex: 0xFFF9EE), Color(hex: 0xEFE1CB)]), startPoint: CGPoint(x: mochiCenterX, y: mochiBodyRect.minY), endPoint: CGPoint(x: mochiCenterX, y: mochiBodyRect.maxY))
            )
            ctx.fill(
                beaniePath,
                with: .linearGradient(Gradient(colors: [Color(hex: 0xF07B60), Color(hex: 0xD95941)]), startPoint: CGPoint(x: mochiCenterX, y: beanieRect.minY), endPoint: CGPoint(x: mochiCenterX, y: beanieRect.maxY))
            )
            let pomRect = CGRect(x: mochiCenterX - 5, y: beanieRect.minY - 7, width: 10, height: 9)
            ctx.fill(Path(ellipseIn: pomRect), with: .color(Color(hex: 0xF69C82)))

            // Mochi eyes: happy crescents when handed over, otherwise tracking the traveling gold bead
            let eyeY = mochiBodyRect.minY + mochiH * 0.44
            if passed {
                for dx in [-8.0, 4.0] {
                    var arc = Path()
                    arc.addArc(center: CGPoint(x: mochiCenterX + dx, y: eyeY + 1), radius: 3.6, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
                    ctx.stroke(arc, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 1.9, lineCap: .round))
                }
            } else {
                let lookX = CGFloat(max(-1.8, min(1.2, (Double(beadCenter.x) - Double(mochiCenterX)) / Double(w) * 4.5)))
                for dx in [-8.0, 4.0] {
                    let sclera = CGRect(x: mochiCenterX + dx - 4.5, y: eyeY - 4.5, width: 9, height: 9)
                    ctx.fill(Path(ellipseIn: sclera), with: .color(.white))
                    let pupil = CGRect(x: mochiCenterX + dx - 2.6 + lookX, y: eyeY - 2.6, width: 5.2, height: 5.2)
                    ctx.fill(Path(ellipseIn: pupil), with: .color(Palette.ink))
                }
            }
        }
        .accessibilityLabel(L10n.t("Otto 把暖金灯珠的光递给戴珊瑚针织帽的 Mochi", "Otto gently passing warm lantern light toward Mochi in a coral knit beanie"))
    }
}

/// 3× cotton-paper print poster for WeChat / iMessage / AirDrop sharing via `RenderedPoster`.
struct HandoverPoster: View {
    let snapshot: HandoverSnapshot

    var body: some View {
        let paper = Color(hex: 0xFBF7F0)
        let ink = Color(hex: 0x241F1B)
        let muted = Color(hex: 0x6A6156)
        let teal = Color(hex: 0x0B7D74)

        VStack(alignment: .leading, spacing: 12) {
            PassingLanternArt(dark: false, progress: 0.90, passed: true)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Palette.amber.opacity(0.32), lineWidth: 0.9)
                )

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("交接给下一位点灯人", "Passing the Lantern"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(teal)
                    Text(L10n.t("\(snapshot.babyName) · 照护交接卡", "\(snapshot.babyName) · Care Handover"))
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(ink)
                }
                Spacer()
                Text("\(snapshot.dateLabel)\n\(snapshot.timeLabel)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(muted)
                    .multilineTextAlignment(.trailing)
            }

            if let active = snapshot.activeTimerLine {
                Text("●  \(active)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.amber.opacity(0.24)))
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                posterCell(title: L10n.t("上次喂奶", "Last Feed"), value: snapshot.lastFeedHeadline, detail: snapshot.lastFeedDetail, tint: Crayon.pink, ink: ink, muted: muted)
                posterCell(title: L10n.t("上次醒来", "Last Wake"), value: snapshot.lastSleepHeadline, detail: snapshot.lastSleepDetail, tint: Crayon.lilac, ink: ink, muted: muted)
                posterCell(title: L10n.t("上次尿布", "Last Diaper"), value: snapshot.lastDiaperHeadline, detail: snapshot.lastDiaperDetail, tint: Crayon.sky, ink: ink, muted: muted)
                posterCell(title: L10n.t("今日节奏", "Today's Rhythm"), value: snapshot.todayHeadline, detail: snapshot.todayDetail, tint: Crayon.leaf, ink: ink, muted: muted)
            }

            if !snapshot.extraNote.isEmpty {
                Text("“\(snapshot.extraNote)”")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.bead.opacity(0.18)))
            }

            Divider().opacity(0.32)

            HStack {
                Text(L10n.t("摸索台灯 · 孩子摸索，大人点灯", "Moss & Otto · They explore. You hold the light."))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(muted)
                Spacer()
                if !snapshot.ageText.isEmpty {
                    Text(snapshot.ageText)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(teal)
                }
            }
        }
        .padding(22)
        .frame(width: 360)
        .background(paper)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(hex: 0xC6A982).opacity(0.35), lineWidth: 1)
                .padding(6)
        )
    }

    private func posterCell(title: String, value: String, detail: String, tint: Color, ink: Color, muted: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(muted)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.14)))
    }
}
