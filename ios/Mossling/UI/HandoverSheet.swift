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

    init(day: Day, previewNow: Date? = nil, initialNote: String = "") {
        self.day = day
        self.previewNow = previewNow
        _note = State(initialValue: initialNote)
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
                let poster = RenderedPoster {
                    let card = HandoverPoster(snapshot: snap)
                    let renderer = ImageRenderer(content: card)
                    renderer.scale = 3.0
                    return renderer.uiImage
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Live cotton-paper handover card preview
                        HandoverCardContent(snapshot: snap, companion: app.companion, dark: dark)
                            .printCard(radius: Radius.card)

                        // Optional handover note with 4 balanced quick chips
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.t("给下一位照护者留一句（可选）", "Quick note for next caregiver (optional)"))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.primary)

                            LazyVGrid(
                                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                                spacing: 8
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
                                            .padding(.vertical, 8)
                                            .background(Capsule().fill(active ? Palette.accentFill : (dark ? Palette.lampCard : Palette.card)))
                                            .overlay(Capsule().strokeBorder(Palette.outline.opacity(active ? 0 : 0.3), lineWidth: 0.75))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            TextField(L10n.t("例如：半小时前刚吃过维生素 D", "e.g. Vitamin D given 30m ago"), text: $note)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(dark ? Palette.lampCard : Palette.card))
                                .overlay(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).strokeBorder(Palette.outline.opacity(0.28), lineWidth: 0.75))
                        }

                        // Primary Share Visual Card + Secondary Copy Plain Text
                        VStack(spacing: 10) {
                            ShareLink(
                                item: poster,
                                preview: SharePreview(
                                    L10n.t("\(snap.babyName)的照护交接卡", "\(snap.babyName)'s Care Handover Card")
                                )
                            ) {
                                Label(L10n.t("分享精美交接卡图片", "Share Visual Handover Card"), systemImage: "square.and.arrow.up")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
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
                                    copied ? L10n.t("已复制纯文字交接单", "Copied Text Summary") : L10n.t("复制纯文字发给家人", "Copy Plain Text"),
                                    systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc"
                                )
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                            }
                            .buttonStyle(.vinyl(copied ? Crayon.leaf : Crayon.caramel))
                        }

                        Text(L10n.t("全部内容仅在本机即时生成，不上传云端，可直接发给伴侣、长辈或阿姨。", "Generated locally on your phone with zero cloud upload — ready for partner, grandparents, or nanny."))
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                    }
                    .padding(16)
                }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PassingLanternArt(dark: dark)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
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
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                .fill(color.opacity(dark ? 0.14 : 0.11))
        )
    }
}

/// Synchronous picture-book diorama showing Otto (deep twilight-indigo one-eyed lantern pebble) extending his golden
/// lantern glow toward Mochi (ivory rice-cake caregiver companion wearing a coral knit beanie) across the nursery table.
struct PassingLanternArt: View {
    let dark: Bool

    var body: some View {
        if let img = StoryPlateLoader.image(for: .handoverLantern) {
            ZStack {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                if dark {
                    Color(hex: 0x090E22).opacity(0.24)
                }
            }
            .clipped()
            .accessibilityLabel(L10n.t("Otto 把暖金灯珠的光递给戴珊瑚针织帽的 Mochi", "Otto gently passing warm lantern light toward Mochi in a coral knit beanie"))
        } else {
            Canvas { ctx, size in
                let w = size.width
                let h = size.height
                let groundY = h * 0.84

                let skyColors: [Color] = dark
                    ? [Color(hex: 0x151D3D), Color(hex: 0x1E274B), Color(hex: 0x182040)]
                    : [Color(hex: 0xFDF6EA), Color(hex: 0xF9ECD8), Color(hex: 0xFBF7F0)]
                ctx.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(Gradient(colors: skyColors), startPoint: .zero, endPoint: CGPoint(x: w, y: h))
                )

                var meadow = Path()
                meadow.move(to: CGPoint(x: 0, y: groundY + 4))
                meadow.addQuadCurve(to: CGPoint(x: w, y: groundY + 4), control: CGPoint(x: w * 0.5, y: groundY - 14))
                meadow.addLine(to: CGPoint(x: w, y: h))
                meadow.addLine(to: CGPoint(x: 0, y: h))
                meadow.closeSubpath()
                ctx.fill(meadow, with: .color(dark ? Color(hex: 0x222C52) : Color(hex: 0xF2E7D5)))

                let ottoX = w * 0.31
                let ottoFootY = groundY + 1
                let mochiX = w * 0.69
                let mochiFootY = groundY + 1
                let beadCenter = CGPoint(x: w * 0.485, y: h * 0.42)

                var halo = Path()
                halo.addEllipse(in: CGRect(x: beadCenter.x - 56, y: beadCenter.y - 56, width: 112, height: 112))
                ctx.fill(
                    halo,
                    with: .radialGradient(
                        Gradient(colors: [Palette.amber.opacity(dark ? 0.42 : 0.48), Palette.beadLight.opacity(0.18), .clear]),
                        center: beadCenter,
                        startRadius: 2,
                        endRadius: 56
                    )
                )

                // Canonical deep twilight-indigo ONE-EYED Otto (zero blush, zero arms)
                var ottoShadow = Path()
                ottoShadow.addEllipse(in: CGRect(x: ottoX - 24, y: ottoFootY - 4, width: 48, height: 8))
                ctx.fill(ottoShadow, with: .color(Color(hex: 0x1A2140).opacity(dark ? 0.38 : 0.16)))

                var stem = Path()
                stem.move(to: CGPoint(x: ottoX + 4, y: ottoFootY - 48))
                stem.addCurve(to: beadCenter, control1: CGPoint(x: ottoX + 16, y: h * 0.18), control2: CGPoint(x: w * 0.44, y: h * 0.16))
                ctx.stroke(stem, with: .color(Palette.rod), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))

                var beadPath = Path()
                beadPath.addEllipse(in: CGRect(x: beadCenter.x - 8, y: beadCenter.y - 8, width: 16, height: 16))
                ctx.fill(beadPath, with: .color(Palette.bead))

                let ottoRect = CGRect(x: ottoX - 22, y: ottoFootY - 50, width: 44, height: 50)
                let ottoBody = RoundedRectangle(cornerRadius: 21, style: .continuous).path(in: ottoRect)
                ctx.fill(ottoBody, with: .linearGradient(Gradient(colors: [Palette.rod, Palette.rodDeep]), startPoint: CGPoint(x: ottoX, y: ottoRect.minY), endPoint: CGPoint(x: ottoX, y: ottoRect.maxY)))

                // Single heavy-lidded eye
                let eyeY = ottoRect.minY + 23
                var eyeWhite = Path()
                eyeWhite.addEllipse(in: CGRect(x: ottoX - 8, y: eyeY - 6, width: 16, height: 12))
                ctx.fill(eyeWhite, with: .color(.white))
                var pupil = Path()
                pupil.addEllipse(in: CGRect(x: ottoX - 3, y: eyeY - 3, width: 8, height: 8))
                ctx.fill(pupil, with: .color(Palette.ink))
                var lid = Path()
                lid.addRect(CGRect(x: ottoX - 9, y: eyeY - 7, width: 18, height: 6))
                ctx.fill(lid, with: .color(Palette.rod))

                // Mochi (right)
                let mochiRect = CGRect(x: mochiX - 23, y: mochiFootY - 46, width: 46, height: 46)
                let mochiBody = RoundedRectangle(cornerRadius: 21, style: .continuous).path(in: mochiRect)
                ctx.fill(mochiBody, with: .color(Color(hex: 0xFAF0DF)))
                let hatRect = CGRect(x: mochiX - 21, y: mochiRect.minY - 11, width: 42, height: 22)
                var hatDome = Path()
                hatDome.addRoundedRect(in: hatRect, cornerSize: CGSize(width: 19, height: 18))
                ctx.fill(hatDome, with: .color(Color(hex: 0xE66A50)))
            }
            .accessibilityLabel(L10n.t("Otto 把暖金灯珠的光递给戴珊瑚针织帽的 Mochi", "Otto gently passing warm lantern light toward Mochi in a coral knit beanie"))
        }
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
            PassingLanternArt(dark: false)
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
