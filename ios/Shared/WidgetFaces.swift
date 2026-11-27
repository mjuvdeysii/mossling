import SwiftUI
import WidgetKit
import AppIntents

/// The faces of the widget and of the Live Activity, shared by the widget extension (which shows them) and the app
/// (whose screenshot tests render them for review). Same language as the app (ios/DESIGN.md §3): a paper ground,
/// drawn stickers instead of symbols, the shelf tray of today's play, Moss and Otto in the corner, rounded numerals.
/// At night (dark appearance) the paper becomes the lamp: deep blue, warm amber.

/// The drawings the widget needs: in the widget they come from its own small folder (Art/widget), in the app from the
/// full picture folder (Art/art); the names are the same.
enum WidgetArt {
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 48
        return c
    }()
    static func image(_ name: String) -> UIImage? {
        if let i = cache.object(forKey: name as NSString) { return i }
        for sub in ["widget", "art"] {
            if let url = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: sub), let i = UIImage(contentsOfFile: url.path) {
                cache.setObject(i, forKey: name as NSString)
                return i
            }
        }
        return nil
    }
    /// The sticker drawn for a kind of entry (tools/stickers.py names them after the symbol they replace).
    static func sticker(_ type: String) -> String { "ic_" + LogType.symbol(type).replacingOccurrences(of: ".", with: "_") + ".webp" }
    static func tray(_ code: String) -> String { "tray_\(code.lowercased()).webp" }
    static let pair = "pair.png"
}

enum WidgetInk {
    static func dyn(_ light: UInt32, _ dark: UInt32) -> Color { Crayon.dyn(light, dark) }
    /// Paper by day; the lamp's deep blue at night.
    static let paper = dyn(0xFBF7F0, 0x0E1430)
    static let card = dyn(0xFFFFFF, 0x19213F)
    /// The brand teal, deep enough for text (4.7:1 on paper; the light value on the lamp).
    static let accent = dyn(0x0B7D74, 0x4FD8CB)
    static let bead = Color(red: 0xD4 / 255, green: 0xA2 / 255, blue: 0x1C / 255)
    static func numerals(_ s: CGFloat) -> Font { .system(size: s, weight: .semibold, design: .rounded).monospacedDigit() }
}

/// A drawing, or nothing when it is missing; desaturated in the tinted Home Screen like the system's own pictures.
struct ArtImage: View {
    let name: String
    var body: some View {
        if let i = WidgetArt.image(name) {
            Image(uiImage: i).resizable().widgetAccentedRenderingMode(.accentedDesaturated).scaledToFit().accessibilityHidden(true)
        }
    }
}

// MARK: Home Screen and Lock Screen widget

enum TodaySize { case small, medium, large, circular, rectangular, inline }

struct TodayFace: View {
    let date: Date
    let snap: Snapshot?
    let body_: JournalFile.Body
    let size: TodaySize

    @Environment(\.widgetRenderingMode) private var renderingMode
    private var isFullColor: Bool { renderingMode == .fullColor }

    init(date: Date, snap: Snapshot?, body: JournalFile.Body, size: TodaySize) { self.date = date; self.snap = snap; self.body_ = body; self.size = size }

    private var locked: Bool { WidgetPrivacy.isLocked(snap: snap) }
    private var visible: Bool { WidgetPrivacy.canShowRecords(snap: snap) }
    private var resolvedAge: (age: Age, isCorrected: Bool)? { visible ? snap?.developmentalAge(on: Day(date)) : nil }
    private var age: Age? { resolvedAge?.age }
    private var isCorrectedAge: Bool { resolvedAge?.isCorrected == true }
    private var ageText: String {
        guard visible else { return locked ? L10n.t("已锁定", "Locked") : L10n.appName }
        guard let a = age else { return L10n.t("填写出生日期", "Add birthday") }
        let base = L10n.ageText(a)
        return isCorrectedAge ? L10n.t("矫·\(base)", "Corr. \(base)") : base
    }
    /// When it was last done, as the app says it (LastFact): a feed — breast or bottle — by when it began, a sleep by
    /// when the baby woke.
    private func last(_ t: String) -> Date? {
        // a kind's own card (亲喂, 瓶喂): its own last feed, as the app's sticker
        if t == LogType.nurse || t == LogType.bottle { return body_.logs.filter { $0.type == t }.feeds().last?.startDate }
        return LastFact.of(t, in: body_.logs)?.at
    }
    /// 喂奶, either kind: the last feed, as the app's 上次喂奶.
    private var lastFeed: Date? { LastFact.of(LogType.nurse, in: body_.logs)?.at }
    /// The wide faces have room for the minutes past the hour ("2 小时 30 分前"); the narrow cards use the short form.
    private func agoText(_ d: Date) -> String { L10n.agoText(d, now: date, precise: true) }
    private func agoCard(_ d: Date) -> String { L10n.agoText(d, now: date) }
    private var journal: Bool { visible && snap?.journal == true }

    var body: some View {
        switch size {
        case .inline:
            if visible {
                Text("\(ageText)" + (snap?.playName.map { " · \($0)" } ?? ""))
                    .privacySensitive()
            } else {
                Text(locked ? L10n.t("摸索台灯已锁定", "Moss & Otto Locked") : L10n.appName)
            }
        case .circular: circular
        case .rectangular:
            if !visible {
                VStack(alignment: .leading, spacing: 1) {
                    Text(locked ? L10n.t("摸索台灯已锁定", "Moss & Otto Locked") : L10n.appName).font(.headline).lineLimit(1).minimumScaleFactor(0.72)
                    Text(locked ? L10n.t("打开应用解锁后查看", "Open app to unlock") : L10n.t("孩子摸索，大人点灯", "They explore. You hold the light.")).font(.caption).lineLimit(1).minimumScaleFactor(0.75)
                }
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text(ageText).font(.headline).lineLimit(1).minimumScaleFactor(0.72).privacySensitive().widgetAccentable()
                    if let t = body_.timers.first {
                        HStack(spacing: 4) {
                            Text(L10n.logName(t.type))
                            if let p = t.pausedAt { Text(L10n.duration(t.total(p))) } else { Text(t.countsFrom, style: .timer).monospacedDigit().contentTransition(.numericText(countsDown: false)) }
                        }.font(.caption).lineLimit(1).minimumScaleFactor(0.72).privacySensitive()
                    } else if let p = snap?.playName { Text(p).font(.caption).lineLimit(1).minimumScaleFactor(0.8) }
                    if journal, let f = lastFeed { Text("\(L10n.t("喂奶", "Fed")) \(agoText(f))").font(.caption).lineLimit(1).minimumScaleFactor(0.75).privacySensitive() }
                }
            }
        case .large: large
        case .medium: medium
        case .small: small
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if !visible {
                Image(systemName: locked ? "lock.fill" : "lamp.desk.fill").font(.title3)
            } else if let t = body_.timers.first {
                VStack(spacing: 1) {
                    Image(systemName: t.type == LogType.sleep ? "moon.zzz.fill" : "drop.fill").font(.caption2)
                    if let p = t.pausedAt {
                        Text(L10n.duration(t.total(p)))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .privacySensitive()
                    } else {
                        Text(t.countsFrom, style: .timer)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .multilineTextAlignment(.center)
                            .contentTransition(.numericText(countsDown: false))
                            .privacySensitive()
                    }
                }
                .padding(4)
            } else if journal, let f = lastFeed {
                VStack(spacing: 1) {
                    Image(systemName: "drop.fill").font(.caption2)
                    Text(agoCard(f)).font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                }
                .padding(4)
                .privacySensitive()
            } else if let a = age {
                VStack(spacing: 0) {
                    Text("\(a.months)").font(.system(size: 20, weight: .bold, design: .rounded)).monospacedDigit()
                    Text(L10n.t("个月", "mo")).font(.system(size: 9, weight: .semibold, design: .rounded))
                }
                .privacySensitive()
            } else {
                Image(systemName: "lamp.desk.fill").font(.title3)
            }
        }
    }

    /// The age as the app shows it: big rounded months, smaller days; the companions in the corner.
    private var head: some View {
        HStack(alignment: .top, spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                if visible {
                    if let n = snap?.nickname, !n.isEmpty {
                        Text(n)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .privacySensitive()
                    }
                    if let a = age {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            if isCorrectedAge {
                                Text(L10n.t("矫", "C"))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(isFullColor ? .white : .primary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1.5)
                                    .background(Capsule().fill(isFullColor ? WidgetInk.accent : Color.primary.opacity(0.14)))
                            }
                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                Text("\(a.months)").font(WidgetInk.numerals(34)).foregroundStyle(WidgetInk.accent)
                                Text(L10n.t("个月", "m")).font(.caption2.weight(.semibold))
                            }
                            if a.days > 0 {
                                HStack(alignment: .firstTextBaseline, spacing: 1) {
                                    Text("\(a.days)").font(WidgetInk.numerals(17)).foregroundStyle(WidgetInk.accent)
                                    Text(L10n.t("天", "d")).font(.caption2.weight(.semibold))
                                }
                            }
                        }
                        .widgetAccentable()
                        .privacySensitive()
                        .lineLimit(1).minimumScaleFactor(0.7)
                        if let badge = snap?.careBadgeLabel() {
                            Text(badge)
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(snap?.careModeActive == true ? Crayon.ink(Crayon.teal) : .secondary)
                                .lineLimit(1)
                                .privacySensitive()
                        }
                    } else { Text(L10n.appName).font(.headline) }
                } else {
                    Text(L10n.appName).font(.headline)
                    if locked {
                        Label(L10n.t("已锁定", "Locked"), systemImage: "lock.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(WidgetInk.accent)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
            // the companions on a small disc of paper, so Otto's blue still reads on the lamp's blue
            ArtImage(name: WidgetArt.pair)
                .frame(width: 36, height: 36)
                .padding(5)
                .background(Circle().fill(isFullColor ? WidgetInk.card : Color.primary.opacity(0.08)))
        }
    }

    /// Today's play (今天一起玩): its tray and its name — wrapped in Link on medium/large, plain on small (.widgetURL only).
    @ViewBuilder private func playView(linked: Bool) -> some View {
        if let code = snap?.playCode, let name = snap?.playName {
            let content = VStack(alignment: .leading, spacing: 4) {
                ArtImage(name: WidgetArt.tray(code)).frame(width: 60, height: 45)
                Text(name).font(.footnote.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            if linked {
                Link(destination: WidgetLinks.play(code)) { content }
            } else {
                content
            }
        }
    }

    private func running(_ t: RunningTimer) -> some View {
        HStack(spacing: 8) {
            ArtImage(name: WidgetArt.sticker(t.type)).frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text(L10n.timerStatus(t.type, side: t.side, paused: t.pausedAt != nil)).lineLimit(1).minimumScaleFactor(0.8)
                    .font(.caption2.weight(.semibold)).foregroundStyle(Crayon.ink(LogType.color(t.type)))
                if let p = t.pausedAt { Text(L10n.duration(t.total(p))).font(WidgetInk.numerals(17)) }
                else { Text(t.countsFrom, style: .timer).font(WidgetInk.numerals(20)).contentTransition(.numericText(countsDown: false)) }
            }
        }
        .privacySensitive()
    }

    private var small: some View {
        let dest = visible
            ? (body_.timers.first.map { WidgetLinks.care($0.type) }
                ?? (journal ? WidgetLinks.journal : snap?.playCode.map(WidgetLinks.play))
                ?? WidgetLinks.today)
            : WidgetLinks.today
        return VStack(alignment: .leading, spacing: 0) {
            head
            Spacer(minLength: 4)
            if !visible {
                Text(locked ? L10n.t("打开应用解锁后查看记录", "Open app to unlock records") : L10n.t("孩子摸索，大人点灯。", "They explore. You hold the light."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            else if let t = body_.timers.first { running(t) }
            else if journal { since }
            else { playView(linked: false) }
        }
        .foregroundStyle(.primary)
        .widgetURL(dest)
    }

    /// With records on, the small widget answers the question asked most at night: how long since the last feed, and
    /// since the baby woke — each with its sticker.
    private var since: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach([LogType.nurse, LogType.sleep], id: \.self) { t in
                let d = t == LogType.nurse ? lastFeed : last(t)
                HStack(spacing: 6) {
                    ArtImage(name: WidgetArt.sticker(t)).frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(t == LogType.nurse ? L10n.t("上次喂奶", "Last feed") : L10n.t("上次醒来", "Last wake")).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                        Text(d.map(agoText) ?? "—").font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
                            .foregroundStyle(Crayon.ink(LogType.color(t))).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
            }
        }
        .privacySensitive()
    }

    private var medium: some View {
        let headerDest = visible ? (age.map { WidgetLinks.month($0.bookMonth) } ?? WidgetLinks.today) : WidgetLinks.today
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Link(destination: headerDest) { head }
                Spacer(minLength: 4)
                if !visible {
                    Text(locked ? L10n.t("应用已锁定，宝宝记录与快捷按钮已隐藏。", "App is locked. Records and quick actions are hidden.") : L10n.t("孩子摸索，大人点灯。在应用里同意本地保存即可同步卡片。", "They explore. You hold the light. Agree to local storage in the app to sync cards."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if journal {
                    playView(linked: true)
                } else if let t = body_.timers.first {
                    Link(destination: WidgetLinks.care(t.type)) { running(t) }
                } else {
                    playView(linked: true)
                }
            }
            if visible && journal {
                HStack(spacing: 6) {
                    timerButton(LogType.nurse)
                    timerButton(LogType.sleep)
                    nappy
                }
                .frame(width: 168)
            }
        }
        .foregroundStyle(.primary)
        .widgetURL(visible ? (snap?.playCode.map(WidgetLinks.play) ?? headerDest) : WidgetLinks.today)
    }

    /// A kind of entry as a sticker on a paper card: the sticker, its name and how long ago; a timer that runs shows
    /// a coloured ring and ends from here.
    private func card(_ type: String, title: String, sub: Text?, on: Bool) -> some View {
        let c = LogType.color(type)
        return VStack(spacing: 2) {
            ArtImage(name: WidgetArt.sticker(type)).frame(width: 34, height: 34)
                .padding(3).overlay(Circle().stroke(c.opacity(on ? 0.6 : 0), lineWidth: 3))
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(on ? Crayon.ink(c) : .primary).lineLimit(1)
            (sub ?? Text(" ")).font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(on ? Crayon.ink(LogType.color(type)) : .secondary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isFullColor ? WidgetInk.card : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .privacySensitive()
    }

    /// Each card opens its page in the app — a feed or a sleep starts only there, where it is seen (nothing starts
    /// from the Home Screen by accident); a running one opens its clock to pause, change side or end.
    private func timerButton(_ type: String) -> some View {
        let t = body_.timers.first { $0.type == type }
        // running: the card is the clock (how long so far)
        let sub: Text? = t.map { t in t.pausedAt.map { Text(L10n.duration(t.total($0))) } ?? Text(t.countsFrom, style: .timer) } ?? last(type).map { Text(agoCard($0)) }
        return Link(destination: WidgetLinks.care(type)) {
            card(type, title: L10n.logName(type), sub: sub, on: t != nil)
        }
    }

    /// A nappy: opens the nappy page (wet, dirty or both), where one tap records it.
    private var nappy: some View {
        Link(destination: WidgetLinks.log(LogType.diaper)) {
            card(LogType.diaper, title: L10n.logName(LogType.diaper), sub: last(LogType.diaper).map { Text(agoCard($0)) }, on: false)
        }
    }

    /// Large Home Screen dashboard: age & companions, interactive today's play hero card (with inline shuffle),
    /// 24-hour Montessori bead strip, live summary + 1-tap undo when a diaper was just logged, and 4 interactive 3D-sticker tiles.
    private var large: some View {
        let day = Day(date)
        let startMs = day.date.timeIntervalSince1970 * 1000
        let todayLogs = body_.logs.filter { $0.start >= startMs || ($0.start < startMs && ($0.end ?? $0.start) > startMs) }
        let feeds = todayLogs.feedCount(from: startMs)
        let sleepSec = todayLogs.filter { $0.type == LogType.sleep }.reduce(0.0) { $0 + $1.seconds(on: day) }
        let diapers = todayLogs.filter { $0.type == LogType.diaper && !$0.carriedOver(into: day) }
        let wetCount = diapers.filter { $0.detail == "wet" || $0.detail == "both" }.count
        let dirtyCount = diapers.filter { $0.detail == "dirty" || $0.detail == "both" }.count
        let recentDiaper = QuickCareFace.recentDiaper(in: body_.logs, now: date)
        let canShuffle = (snap?.weekPlays?.count ?? 0) >= 2
        let isSleeping = body_.timers.contains { $0.type == LogType.sleep }
        let awakeMinutes: Int? = {
            guard !isSleeping, let w = last(LogType.sleep) else { return nil }
            let m = Int(date.timeIntervalSince(w) / 60)
            return (m >= 10 && m <= 150) ? m : nil
        }()
        let playCue: String = {
            if isSleeping { return L10n.t("正在睡觉 · 醒来再一起玩", "Sleeping · Play when awake") }
            if let m = awakeMinutes {
                return L10n.t("醒来 \(L10n.duration(Double(m) * 60)) · 正适合一起玩", "Awake \(L10n.duration(Double(m) * 60)) · Ready to play")
            }
            return L10n.t("今天一起玩", "Today's Play")
        }()
        let headerLink = visible ? (age.map { WidgetLinks.month($0.bookMonth) } ?? WidgetLinks.today) : WidgetLinks.today
        return VStack(alignment: .leading, spacing: 11) {
            Link(destination: headerLink) { head }

            if !visible {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: locked ? "lock.fill" : "lamp.desk.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(WidgetInk.accent)
                    Text(locked ? L10n.t("摸索台灯已锁定", "Moss & Otto is Locked") : L10n.t("孩子摸索，大人点灯。", "They explore. You hold the light."))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(locked ? L10n.t("打开应用解锁后查看今日活动与记录", "Open Moss & Otto to unlock today's play and care records.") : L10n.t("在应用里同意本地保存并填写宝宝生日，桌面小组件会同步陪伴。", "Agree to local storage and add baby's birthday inside the app to activate widgets."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isFullColor ? WidgetInk.card : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Spacer(minLength: 0)
            } else {
                if let code = snap?.playCode, let name = snap?.playName {
                    HStack(spacing: 12) {
                        Link(destination: WidgetLinks.play(code)) {
                            HStack(spacing: 12) {
                                ArtImage(name: WidgetArt.tray(code))
                                    .frame(width: 80, height: 58)
                                    .id(code)
                                    .transition(.push(from: .bottom).combined(with: .opacity))
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 5) {
                                        Circle().fill(isSleeping ? Crayon.lilac : WidgetInk.bead).frame(width: 6, height: 6)
                                        Text(playCue).font(.caption2.weight(.semibold)).foregroundStyle(isSleeping ? Crayon.ink(Crayon.lilac) : WidgetInk.accent).lineLimit(1).minimumScaleFactor(0.8)
                                    }
                                    .privacySensitive()
                                    Text(name)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.88)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .id(name)
                                        .transition(.opacity)
                                }
                                Spacer(minLength: 4)
                            }
                            .contentShape(Rectangle())
                        }
                        if canShuffle {
                            Button(intent: CycleWidgetPlayIntent()) {
                                Image(systemName: "arrow.trianglehead.2.clockwise")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(WidgetInk.accent)
                                    .frame(width: 30, height: 30)
                                    .background(WidgetInk.accent.opacity(0.12), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .invalidatableContent()
                            .accessibilityLabel(L10n.t("换一个活动", "Swap activity"))
                        }
                    }
                    .padding(.horizontal, 13).padding(.vertical, 12)
                    .background(isFullColor ? WidgetInk.card : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Spacer(minLength: 0)

                if journal {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .center, spacing: 6) {
                            Link(destination: WidgetLinks.journal) {
                                HStack(spacing: 6) {
                                    Text(L10n.t("今天", "Today")).font(.caption2.weight(.semibold)).foregroundStyle(WidgetInk.accent)
                                    Text(L10n.t(
                                        "喂奶 \(feeds) 次 · 睡眠 \(sleepSec > 0 ? L10n.duration(sleepSec) : "—") · 尿布 \(diapers.count) 次",
                                        "\(feeds) \(feeds == 1 ? "feed" : "feeds") · \(sleepSec > 0 ? L10n.duration(sleepSec) : "—") sleep · \(diapers.count) \(diapers.count == 1 ? "diaper" : "diapers")"
                                    ))
                                        .font(.caption2.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
                                        .contentTransition(.numericText())
                                        .lineLimit(1).minimumScaleFactor(0.78)
                                }
                            }
                            .privacySensitive()
                            Spacer(minLength: 2)
                            if recentDiaper != nil {
                                Button(intent: UndoLastDiaperIntent()) {
                                    Text(L10n.t("撤销", "Undo"))
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(WidgetInk.accent)
                                        .padding(.horizontal, 7).padding(.vertical, 3)
                                        .background(WidgetInk.accent.opacity(0.14), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 2)

                        Link(destination: WidgetLinks.journal) {
                            MontessoriDayStrip(day: day, now: date, logs: todayLogs, isFullColor: isFullColor)
                                .frame(height: 12)
                                .padding(.horizontal, 2)
                        }
                        .privacySensitive()
                    }

                    HStack(spacing: 8) {
                        QuickCareFace.timerTile(body: body_, kind: .nurse, stickerSize: 32, isFullColor: isFullColor)
                        QuickCareFace.timerTile(body: body_, kind: .sleep, stickerSize: 32, isFullColor: isFullColor)
                        QuickCareFace.diaperTile(kind: .wet, title: L10n.t("湿尿布", "Wet"), dot: Crayon.sky, stickerSize: 32, count: wetCount, justLogged: recentDiaper?.detail == "wet", isFullColor: isFullColor)
                        QuickCareFace.diaperTile(kind: .dirty, title: L10n.t("便尿布", "Dirty"), dot: Crayon.caramel, stickerSize: 32, count: dirtyCount, justLogged: recentDiaper?.detail == "dirty", isFullColor: isFullColor)
                    }
                    .frame(height: 84)
                }
            }
        }
        .foregroundStyle(.primary)
        .widgetURL(visible ? (snap?.playCode.map(WidgetLinks.play) ?? headerLink) : WidgetLinks.today)
    }
}

/// Miniature 24-hour Montessori bead thread echoing the Journal timeline: feeds, sleeps, and diapers sit along
/// 00:00–24:00 as soft colored beads, with Otto's warm gold bead marking the present moment.
struct MontessoriDayStrip: View {
    let day: Day
    let now: Date
    let logs: [LogEntry]
    var isFullColor: Bool = true

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let cy = g.size.height / 2
            let dayStart = day.date.timeIntervalSince1970 * 1000
            let daySpan: Double = 86_400_000
            let nowFrac = max(0, min(1, (now.timeIntervalSince1970 * 1000 - dayStart) / daySpan))
            ZStack(alignment: .leading) {
                // quiet linen thread
                Capsule()
                    .fill(Color.secondary.opacity(0.16))
                    .frame(height: 3)
                // subtle 6h / 12h / 18h reference ticks
                ForEach([0.25, 0.5, 0.75], id: \.self) { q in
                    Circle()
                        .fill(Color.secondary.opacity(0.28))
                        .frame(width: 3, height: 3)
                        .position(x: w * q, y: cy)
                }
                // proportional beads for today's entries
                ForEach(logs.suffix(24), id: \.id) { e in
                    let s = max(0, min(1, (e.start - dayStart) / daySpan))
                    let eEnd = max(e.start, e.end ?? e.start)
                    let f = max(s, min(1, (eEnd - dayStart) / daySpan))
                    let bw = max(6, CGFloat(f - s) * w)
                    let bx = max(bw / 2, min(w - bw / 2, CGFloat(s) * w + bw / 2))
                    Capsule()
                        .fill(LogType.color(e.type).opacity(0.88))
                        .frame(width: bw, height: e.type == LogType.diaper ? 6 : 7)
                        .position(x: bx, y: cy)
                }
                // Otto's gold "now" bead with soft halo
                Circle()
                    .fill(WidgetInk.bead.opacity(0.28))
                    .frame(width: 12, height: 12)
                    .position(x: max(6, min(w - 6, w * nowFrac)), y: cy)
                Circle()
                    .fill(WidgetInk.bead)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(isFullColor ? WidgetInk.card : Color.clear, lineWidth: 1))
                    .position(x: max(6, min(w - 6, w * nowFrac)), y: cy)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: Interactive Quick Care Widget (Home Screen — zero-open logging with 3D stickers & instant confirmation)

struct QuickCareFace: View {
    let date: Date
    let snap: Snapshot?
    let body_: JournalFile.Body
    let isMedium: Bool

    @Environment(\.widgetRenderingMode) private var renderingMode
    private var isFullColor: Bool { renderingMode == .fullColor }

    static let confirmWindowSeconds: Double = 12

    static func recentDiaper(in logs: [LogEntry], now: Date) -> LogEntry? {
        guard let last = logs.filter({ $0.type == LogType.diaper }).max(by: { $0.start < $1.start }) else { return nil }
        let elapsed = now.timeIntervalSince(last.startDate)
        return (elapsed >= -2 && elapsed <= confirmWindowSeconds) ? last : nil
    }

    private var locked: Bool { WidgetPrivacy.isLocked(snap: snap) }
    private var visible: Bool { WidgetPrivacy.canShowRecords(snap: snap) }
    private var journal: Bool { visible && snap?.journal == true }
    private var lastFeed: Date? { LastFact.of(LogType.nurse, in: body_.logs)?.at }
    private var lastWake: Date? { LastFact.of(LogType.sleep, in: body_.logs)?.at }

    var body: some View {
        let day = Day(date)
        let startMs = day.date.timeIntervalSince1970 * 1000
        let todayDiapers = body_.logs.filter { $0.type == LogType.diaper && $0.start >= startMs }
        let wetCount = todayDiapers.filter { $0.detail == "wet" || $0.detail == "both" }.count
        let dirtyCount = todayDiapers.filter { $0.detail == "dirty" || $0.detail == "both" }.count
        let recent = Self.recentDiaper(in: body_.logs, now: date)

        if locked {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(WidgetInk.accent)
                    .padding(8)
                    .background(Circle().fill(isFullColor ? WidgetInk.card : Color.primary.opacity(0.08)))
                Spacer(minLength: 0)
                Text(L10n.t("应用已锁定", "App Locked")).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                Text(L10n.t("解锁摸索台灯后再查看或快速记录", "Unlock Moss & Otto to view or quick log")).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .widgetURL(WidgetLinks.today)
        } else if !journal {
            VStack(alignment: .leading, spacing: 8) {
                ArtImage(name: WidgetArt.pair)
                    .frame(width: 34, height: 34)
                    .padding(5)
                    .background(Circle().fill(isFullColor ? WidgetInk.card : Color.primary.opacity(0.08)))
                Spacer(minLength: 0)
                Text(L10n.t("一键记录", "Quick Log")).font(.subheadline.weight(.bold)).foregroundStyle(.primary)
                Text(L10n.t("在「工坊」打开记录后即可使用", "Turn on Log in Studio to enable")).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .widgetURL(WidgetLinks.settings)
        } else if isMedium {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Link(destination: WidgetLinks.journal) {
                            HStack(spacing: 6) {
                                ArtImage(name: WidgetArt.pair)
                                    .frame(width: 24, height: 24)
                                    .padding(4)
                                    .background(Circle().fill(isFullColor ? WidgetInk.card : Color.primary.opacity(0.08)))
                                Text(snap?.nickname.isEmpty == false ? snap!.nickname : L10n.t("一键记录", "Quick Log"))
                                    .font(.caption.weight(.bold)).foregroundStyle(WidgetInk.accent).lineLimit(1).privacySensitive()
                            }
                        }
                        Spacer(minLength: 2)
                        if recent != nil {
                            Button(intent: UndoLastDiaperIntent()) {
                                Text(L10n.t("撤销", "Undo"))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(WidgetInk.accent)
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(WidgetInk.accent.opacity(0.14), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }
                    }
                    Spacer(minLength: 0)
                    Link(destination: WidgetLinks.care(LogType.nurse)) {
                        miniFact(L10n.t("上次喂奶", "Last feed"), lastFeed, LogType.nurse)
                            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            .privacySensitive()
                    }
                    Link(destination: WidgetLinks.care(LogType.sleep)) {
                        miniFact(L10n.t("上次醒来", "Last wake"), lastWake, LogType.sleep)
                            .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            .privacySensitive()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                grid(stickerSize: 26, wetCount: wetCount, dirtyCount: dirtyCount, recent: recent).frame(width: 174)
            }
            .foregroundStyle(.primary)
            .widgetURL(WidgetLinks.journal)
        } else {
            grid(stickerSize: 26, wetCount: wetCount, dirtyCount: dirtyCount, recent: recent, tapToUndo: true)
                .foregroundStyle(.primary)
                .widgetURL(WidgetLinks.journal)
        }
    }

    private func grid(stickerSize: CGFloat, wetCount: Int, dirtyCount: Int, recent: LogEntry?, tapToUndo: Bool = false) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Self.timerTile(body: body_, kind: .nurse, stickerSize: stickerSize, isFullColor: isFullColor)
                Self.timerTile(body: body_, kind: .sleep, stickerSize: stickerSize, isFullColor: isFullColor)
            }
            HStack(spacing: 8) {
                Self.diaperTile(kind: .wet, title: L10n.t("湿尿布", "Wet"), dot: Crayon.sky, stickerSize: stickerSize, count: wetCount, justLogged: recent?.detail == "wet", tapToUndo: tapToUndo, isFullColor: isFullColor)
                Self.diaperTile(kind: .dirty, title: L10n.t("便尿布", "Dirty"), dot: Crayon.caramel, stickerSize: stickerSize, count: dirtyCount, justLogged: recent?.detail == "dirty", tapToUndo: tapToUndo, isFullColor: isFullColor)
            }
        }
    }

    private func miniFact(_ label: String, _ at: Date?, _ type: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
            Text(at.map { L10n.agoText($0, now: date, precise: true) } ?? "—")
                .font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(Crayon.ink(LogType.color(type))).lineLimit(1).minimumScaleFactor(0.75)
        }
    }

    static func timerTile(body: JournalFile.Body, kind: CareTimerAppEnum, stickerSize: CGFloat, isFullColor: Bool = true) -> some View {
        let type = kind == .nurse ? LogType.nurse : LogType.sleep
        let t = body.timers.first { $0.type == type }
        let c = LogType.color(type)
        let running = t != nil
        return Button(intent: ToggleCareTimerIntent(careType: kind)) {
            VStack(spacing: 3) {
                ArtImage(name: WidgetArt.sticker(type))
                    .frame(width: stickerSize, height: stickerSize)
                    .padding(2)
                    .overlay(Circle().stroke(c.opacity(running ? 0.65 : 0), lineWidth: 2.5))
                if let t {
                    if let p = t.pausedAt {
                        Text(L10n.duration(t.total(p))).font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(Crayon.ink(c)).lineLimit(1).minimumScaleFactor(0.75).privacySensitive()
                    } else {
                        Text(t.countsFrom, style: .timer).font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(Crayon.ink(c)).multilineTextAlignment(.center).lineLimit(1).minimumScaleFactor(0.75)
                            .contentTransition(.numericText(countsDown: false))
                            .privacySensitive()
                    }
                } else {
                    Text(L10n.logName(type)).font(.caption2.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isFullColor ? WidgetInk.card : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .invalidatableContent()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    static func diaperTile(kind: DiaperKindAppEnum, title: String, dot: Color, stickerSize: CGFloat, count: Int = 0, justLogged: Bool = false, tapToUndo: Bool = false, isFullColor: Bool = true) -> some View {
        let tile = ZStack(alignment: .topTrailing) {
            VStack(spacing: 3) {
                ArtImage(name: WidgetArt.sticker(LogType.diaper))
                    .frame(width: stickerSize, height: stickerSize)
                    .padding(2)
                    .overlay(Circle().stroke(WidgetInk.accent.opacity(justLogged ? 0.7 : 0), lineWidth: 2.2))
                    .overlay(alignment: .bottomTrailing) {
                        if justLogged {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white, WidgetInk.accent)
                                .transition(.scale(scale: 0.7).combined(with: .opacity))
                        } else {
                            Circle().fill(dot).frame(width: 8, height: 8)
                                .overlay(Circle().stroke(isFullColor ? WidgetInk.card : Color.clear, lineWidth: 1.5))
                        }
                    }
                Text(justLogged ? (tapToUndo ? L10n.t("已记·撤销", "Undo") : L10n.t("已记", "Logged")) : title)
                    .font(.caption2.weight(justLogged ? .bold : .semibold))
                    .foregroundStyle(justLogged ? WidgetInk.accent : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(justLogged ? WidgetInk.accent : .secondary)
                    .contentTransition(.numericText())
                    .privacySensitive()
                    .padding(.top, 5).padding(.trailing, 7)
            }
        }
        .background(isFullColor ? WidgetInk.card : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .invalidatableContent()

        // While the 12s confirmation badge is shown, tapping the same tile undoes instead of accidentally double-logging
        if justLogged {
            Button(intent: UndoLastDiaperIntent()) { tile }
                .buttonStyle(.plain)
        } else {
            Button(intent: QuickLogDiaperIntent(kind: kind)) { tile }
                .buttonStyle(.plain)
        }
    }
}

// MARK: Bedside Lamp Widget (StandBy & Night Mode — Otto's warm amber glow)

struct BedsideLampFace: View {
    let date: Date
    let snap: Snapshot?
    let body_: JournalFile.Body
    let isMedium: Bool
    var forceAccentedPreview: Bool = false

    @Environment(\.widgetRenderingMode) private var renderingMode

    static let lampBase = Color(red: 0x0E / 255, green: 0x14 / 255, blue: 0x30 / 255)
    static let amber = Color(red: 0xF5 / 255, green: 0xC6 / 255, blue: 0x6A / 255)
    static let sleepMist = Color(red: 0x94 / 255, green: 0xBC / 255, blue: 0xFF / 255)

    /// Full-bleed night-lamp backdrop used in `containerBackground(for: .widget)` so the amber glow never clips.
    static var backdrop: some View {
        ZStack {
            lampBase
            RadialGradient(
                colors: [amber.opacity(0.24), amber.opacity(0.06), .clear],
                center: UnitPoint(x: 0.16, y: 0.16),
                startRadius: 8,
                endRadius: 190
            )
        }
    }

    private var locked: Bool { WidgetPrivacy.isLocked(snap: snap) }
    private var visible: Bool { WidgetPrivacy.canShowRecords(snap: snap) }
    private var accented: Bool { forceAccentedPreview || renderingMode != .fullColor }
    private var primaryAccent: Color { forceAccentedPreview ? Color(red: 0xFF / 255, green: 0x5C / 255, blue: 0x4D / 255) : Self.amber }
    private var primaryInk: Color { forceAccentedPreview ? Color(red: 0xFF / 255, green: 0x8F / 255, blue: 0x7A / 255) : .white }
    private var resolvedAge: (age: Age, isCorrected: Bool)? { visible ? snap?.developmentalAge(on: Day(date)) : nil }
    private var age: Age? { resolvedAge?.age }
    private var isCorrectedAge: Bool { resolvedAge?.isCorrected == true }
    private var lastFeed: Date? { LastFact.of(LogType.nurse, in: body_.logs)?.at }
    private var lastWake: Date? { LastFact.of(LogType.sleep, in: body_.logs)?.at }
    private var horizonWindow: (startMs: Double, endMs: Double, sleeps: [(Double, Double)], feeds: [Double]) {
        let endMs = date.timeIntervalSince1970 * 1000
        let span = 86_400_000.0
        let startMs = endMs - span
        var sleepSpans: [(Double, Double)] = []
        for e in body_.logs where e.type == LogType.sleep {
            let eEnd = e.end ?? endMs
            guard eEnd >= startMs && e.start <= endMs else { continue }
            let a = max(0.0, (e.start - startMs) / span)
            let b = min(1.0, (eEnd - startMs) / span)
            if b > a { sleepSpans.append((a, b)) }
        }
        let feedPts = body_.logs.feeds().compactMap { f -> Double? in
            guard f.start >= startMs && f.start <= endMs else { return nil }
            return max(0.0, min(1.0, (f.start - startMs) / span))
        }
        return (startMs, endMs, sleepSpans, feedPts)
    }

    var body: some View {
        let cardDark = Color(red: 0x19 / 255, green: 0x21 / 255, blue: 0x3F / 255)
        let wakeTint = accented ? primaryInk.opacity(0.88) : Self.sleepMist
        let journalOn = visible && snap?.journal == true
        VStack(alignment: .leading, spacing: isMedium ? 8 : 6) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    if accented {
                        Circle()
                            .strokeBorder(primaryAccent.opacity(0.45), lineWidth: 1)
                    } else {
                        Circle().fill(cardDark)
                    }
                    ArtImage(name: WidgetArt.pair)
                        .frame(width: isMedium ? 30 : 28, height: isMedium ? 30 : 28)
                        .widgetAccentable()
                }
                .frame(width: isMedium ? 38 : 34, height: isMedium ? 38 : 34)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(primaryAccent)
                            .frame(width: 6, height: 6)
                            .widgetAccentable()
                        Text(journalOn && snap?.nickname.isEmpty == false ? snap!.nickname : L10n.appName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(primaryAccent)
                            .lineLimit(1)
                            .privacySensitive()
                            .widgetAccentable()
                    }
                    if journalOn, let a = age {
                        let ageLine = (isCorrectedAge ? L10n.t("矫·\(a.months)月 · ", "Corr. \(a.months)m · ") : "") + L10n.livedDays(a.lived)
                        let extra = snap?.careModeActive == true ? L10n.t(" · 减负照护", " · Care Mode") : ""
                        Text(ageLine + extra)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(primaryInk.opacity(0.86))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .privacySensitive()
                    } else if journalOn, let badge = snap?.careBadgeLabel() {
                        Text(badge)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(primaryInk.opacity(0.82))
                            .lineLimit(1)
                            .privacySensitive()
                    }
                }
                Spacer(minLength: 4)

                if isMedium && journalOn {
                    headerControl(cardDark: cardDark)
                        .privacySensitive()
                }
            }

            Spacer(minLength: 0)

            if locked {
                VStack(alignment: .leading, spacing: 4) {
                    Label(L10n.t("摸索台灯已锁定", "Moss & Otto Locked"), systemImage: "lock.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(primaryAccent)
                    Text(L10n.t("夜间记录与台灯卡片已隐藏", "Night records hidden until unlocked"))
                        .font(.caption2)
                        .foregroundStyle(primaryInk.opacity(0.78))
                        .lineLimit(2)
                }
            } else if !journalOn {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("床头夜灯", "Bedside Lamp"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(primaryAccent)
                    Text(L10n.t("轻触打开暖琥珀床头夜灯", "Tap for warm amber bedside lamp"))
                        .font(.caption2)
                        .foregroundStyle(primaryInk.opacity(0.78))
                        .lineLimit(2)
                }
            } else if let t = body_.timers.first {
                HStack(alignment: .center, spacing: 10) {
                    ArtImage(name: WidgetArt.sticker(t.type))
                        .frame(width: isMedium ? 36 : 26, height: isMedium ? 36 : 26)
                        .widgetAccentable()
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.timerStatus(t.type, side: t.side, paused: t.pausedAt != nil))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(primaryAccent)
                            .lineLimit(1)
                            .privacySensitive()
                            .widgetAccentable()
                        if let p = t.pausedAt {
                            Text(L10n.duration(t.total(p)))
                                .font(WidgetInk.numerals(isMedium ? 38 : 26))
                                .foregroundStyle(primaryInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .privacySensitive()
                                .widgetAccentable()
                        } else {
                            Text(t.countsFrom, style: .timer)
                                .font(WidgetInk.numerals(isMedium ? 38 : 26))
                                .foregroundStyle(primaryInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .contentTransition(.numericText(countsDown: false))
                                .privacySensitive()
                                .widgetAccentable()
                        }
                    }
                }
            } else if isMedium {
                HStack(spacing: 18) {
                    Link(destination: WidgetLinks.care(LogType.nurse)) {
                        lampMetric(L10n.t("上次喂奶", "Last feed"), lastFeed, primaryAccent, inkColor: primaryInk)
                    }
                    Link(destination: WidgetLinks.care(LogType.sleep)) {
                        lampMetric(L10n.t("上次醒来", "Last wake"), lastWake, wakeTint, inkColor: primaryInk)
                    }
                }
                .privacySensitive()
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    lampMetric(L10n.t("上次喂奶", "Last feed"), lastFeed, primaryAccent, inkColor: primaryInk)
                    lampMetric(L10n.t("上次醒来", "Last wake"), lastWake, wakeTint, inkColor: primaryInk)
                }
                .privacySensitive()
            }

            if journalOn {
                horizonStrip(sleepTint: wakeTint)
                    .privacySensitive()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .environment(\.colorScheme, .dark)
        .widgetURL(locked ? WidgetLinks.today : (journalOn ? (body_.timers.first.map { WidgetLinks.care($0.type) } ?? WidgetLinks.lamp) : WidgetLinks.lamp))
    }

    @ViewBuilder
    private func headerControl(cardDark: Color) -> some View {
        let shape = Capsule(style: .continuous)
        let activeTimer = body_.timers.first
        let label = activeTimer.map {
            $0.pausedAt == nil ? L10n.t("暂停", "Pause") : L10n.t("继续", "Resume")
        } ?? L10n.t("睡觉", "Sleep")
        let symbol = activeTimer.map {
            $0.pausedAt == nil ? "pause.fill" : "play.fill"
        } ?? "moon.zzz.fill"

        Group {
            if let t = activeTimer {
                Button(intent: TimerIntent(type: t.type, action: "pause")) {
                    Label(label, systemImage: symbol)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Group {
                                if accented {
                                    shape.strokeBorder(primaryAccent.opacity(0.45), lineWidth: 1)
                                } else {
                                    shape.fill(cardDark).overlay(shape.strokeBorder(Self.amber.opacity(0.32), lineWidth: 1))
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            } else {
                Button(intent: ToggleCareTimerIntent(careType: .sleep)) {
                    Label(label, systemImage: symbol)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Group {
                                if accented {
                                    shape.strokeBorder(primaryAccent.opacity(0.45), lineWidth: 1)
                                } else {
                                    shape.fill(cardDark).overlay(shape.strokeBorder(Self.amber.opacity(0.28), lineWidth: 1))
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .widgetAccentable()
    }

    private func lampMetric(_ label: String, _ at: Date?, _ tint: Color, inkColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(inkColor.opacity(0.68))
            Text(at.map { L10n.agoText($0, now: date, precise: isMedium) } ?? "—")
                .font(.system(size: isMedium ? 22 : 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .widgetAccentable()
        }
    }

    /// 24-hour micro-horizon bead strip readable at bedside distance (pure static layout for WidgetKit).
    private func horizonStrip(sleepTint: Color) -> some View {
        let horizon = horizonWindow
        return GeometryReader { geo in
            let w = max(1, geo.size.width)
            let midY = geo.size.height / 2
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(primaryInk.opacity(accented ? 0.22 : 0.14))
                    .frame(height: 2.5)
                    .position(x: w / 2, y: midY)

                ForEach(Array(horizon.sleeps.enumerated()), id: \.offset) { _, span in
                    let x0 = CGFloat(span.0) * w
                    let x1 = CGFloat(span.1) * w
                    let segW = max(5, x1 - x0)
                    Capsule(style: .continuous)
                        .fill(sleepTint.opacity(accented ? 0.55 : 0.48))
                        .frame(width: segW, height: 5)
                        .position(x: x0 + segW / 2, y: midY)
                }

                ForEach(Array(horizon.feeds.enumerated()), id: \.offset) { _, pt in
                    let bx = max(3, min(w - 3, CGFloat(pt) * w))
                    Circle()
                        .fill(primaryAccent)
                        .frame(width: 5, height: 5)
                        .position(x: bx, y: midY)
                        .widgetAccentable()
                }

                Circle()
                    .fill(primaryAccent)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(accented ? .clear : Self.lampBase, lineWidth: 1))
                    .position(x: w - 3.5, y: midY)
                    .widgetAccentable()
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

/// Story Window (成长故事窗): a poetic Montessori keepsake window showing the baby's 37-bead growth journey,
/// current developmental chapter, and Moss & Otto's quiet presence. Tapping opens the Growth Book or Month chapter.
struct StoryWindowFace: View {
    let date: Date
    let snap: Snapshot?
    let body_: JournalFile.Body
    let isMedium: Bool

    @Environment(\.widgetRenderingMode) private var renderingMode
    private var isFullColor: Bool { renderingMode == .fullColor }

    private var locked: Bool { WidgetPrivacy.isLocked(snap: snap) }
    private var visible: Bool { WidgetPrivacy.canShowRecords(snap: snap) }
    private var resolvedAge: (age: Age, isCorrected: Bool)? { visible ? snap?.developmentalAge(on: Day(date)) : nil }
    private var age: Age? { resolvedAge?.age }
    private var isCorrectedAge: Bool { resolvedAge?.isCorrected == true }
    private var bookMonth: Int { age?.bookMonth ?? 0 }
    private var isSleeping: Bool { visible && body_.timers.contains { $0.type == LogType.sleep } }

    var body: some View {
        let name = visible && snap?.nickname.isEmpty == false ? snap!.nickname : L10n.appName
        let chapter = visible ? L10n.stretchName(for: bookMonth) : (locked ? L10n.t("成长故事已锁定", "Story Locked") : L10n.t("孩子摸索，大人点灯。", "They explore. You hold the light."))
        let beadNum = min(bookMonth + 1, 37)
        let beadLabel = visible
            ? (isMedium
                ? (isCorrectedAge ? L10n.t("矫·第 \(beadNum)/37 颗成长珠", "Corr. Bead \(beadNum)/37") : L10n.t("第 \(beadNum) / 37 颗成长珠", "Bead \(beadNum) of 37"))
                : (isCorrectedAge ? L10n.t("矫 \(beadNum)/37 珠", "Corr \(beadNum)/37") : L10n.t("\(beadNum) / 37 珠", "\(beadNum) / 37")))
            : (locked ? L10n.t("解锁后查看成长旅程", "Unlock to view story") : L10n.t("37 颗蒙氏成长珠", "37 Growth Beads"))
        let monthDest = visible ? (age.map { WidgetLinks.month($0.bookMonth) } ?? WidgetLinks.today) : WidgetLinks.today

        VStack(alignment: .leading, spacing: isMedium ? 10 : 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(name).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1).privacySensitive()
                        if visible, let badge = snap?.careBadgeLabel() {
                            Text("· \(badge)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(WidgetInk.accent)
                                .lineLimit(1)
                                .privacySensitive()
                        }
                    }
                    Text(chapter)
                        .font(.system(size: isMedium ? 18 : 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                        .fixedSize(horizontal: false, vertical: true)
                        .privacySensitive()
                }
                Spacer(minLength: 4)
                ArtImage(name: WidgetArt.pair)
                    .frame(width: isMedium ? 40 : 32, height: isMedium ? 40 : 32)
                    .padding(5)
                    .background(Circle().fill(isFullColor ? WidgetInk.card : Color.primary.opacity(0.08)))
            }

            if isMedium {
                HStack(spacing: 10) {
                    if visible, let code = snap?.playCode, let playName = snap?.playName {
                        Link(destination: WidgetLinks.play(code)) {
                            HStack(spacing: 8) {
                                ArtImage(name: WidgetArt.tray(code)).frame(width: 44, height: 34)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(isSleeping ? L10n.t("正在小睡", "Napping") : L10n.t("本周一起玩", "This Week's Play"))
                                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                                        .foregroundStyle(isSleeping ? Crayon.ink(Crayon.lilac) : WidgetInk.accent)
                                    Text(playName)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(isFullColor ? WidgetInk.card : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .privacySensitive()
                        }
                    } else {
                        Text(locked ? L10n.t("打开摸索台灯解锁后查看陪伴活动。", "Open Moss & Otto to unlock activities.") : L10n.t("孩子摸索，大人点灯。", "They explore. You hold the light."))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            let progressBar = VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    Text(beadLabel)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetInk.accent)
                        .monospacedDigit()
                        .privacySensitive()
                    Spacer(minLength: 2)
                    if visible, let a = age {
                        Text(L10n.livedDays(a.lived))
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .privacySensitive()
                    }
                }
                beadHorizon(current: visible ? bookMonth : 0)
                    .frame(height: 10)
                    .privacySensitive()
            }
            if isMedium {
                Link(destination: monthDest) { progressBar }
            } else {
                progressBar
            }
        }
        .foregroundStyle(.primary)
        .widgetURL(visible ? WidgetLinks.book : WidgetLinks.today)
    }

    /// 37-bead Montessori growth path condensed into a clean horizon bar with Otto's gold bead marking the child's month.
    private func beadHorizon(current: Int) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let cy = geo.size.height / 2
            let progress = max(0, min(1, CGFloat(current) / 36.0))
            let x = max(5, min(w - 5, progress * w))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.09))
                    .frame(height: 4)
                    .position(x: w / 2, y: cy)
                Capsule()
                    .fill(WidgetInk.accent.opacity(0.65))
                    .frame(width: max(6, x), height: 4)
                    .position(x: max(6, x) / 2, y: cy)
                Circle()
                    .fill(WidgetInk.bead)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(isFullColor ? WidgetInk.card : Color.clear, lineWidth: 1.5))
                    .position(x: x, y: cy)
            }
        }
    }
}

enum WidgetLinks {
    static let today = URL(string: "mossling://today")!
    static let journal = URL(string: "mossling://journal")!
    static let book = URL(string: "mossling://book")!
    static let settings = URL(string: "mossling://settings")!
    static let lamp = URL(string: "mossling://lamp")!
    private static func url(_ s: String) -> URL { URL(string: s) ?? today }
    static func play(_ code: String) -> URL { url("mossling://play/\(code)") }
    static func month(_ m: Int) -> URL { url("mossling://month/\(m)") }
    static func care(_ type: String) -> URL { url("mossling://care/\(type)") }
    static func log(_ type: String) -> URL { url("mossling://log/\(type)") }
}

// MARK: Live Activity on the Lock Screen

struct TimerFace: View {
    let type: String
    let s: TimerAttributes.ContentState
    var body: some View {
        let c = LogType.color(type)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ArtImage(name: WidgetArt.sticker(type)).frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 0) {
                    Text(L10n.timerStatus(type, side: s.side, paused: s.pausedAt != nil))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Crayon.ink(c))
                    TimerFace.elapsed(s)
                        .font(WidgetInk.numerals(34))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    if let n = s.note { Text(n).font(.caption.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit() }
                }
                .privacySensitive()
                Spacer(minLength: 0)
                ArtImage(name: WidgetArt.pair).frame(width: 42, height: 42).padding(6).background(Circle().fill(WidgetInk.card))
            }
            TimerControls(type: type, s: s, light: true)
        }
        .padding(16)
    }
    @ViewBuilder static func elapsed(_ s: TimerAttributes.ContentState) -> some View {
        if let p = s.pausedAt { Text(L10n.duration(p.timeIntervalSince(s.start))).lineLimit(1).minimumScaleFactor(0.65) }
        else { Text(timerInterval: s.start...Date.distantFuture, countsDown: false).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65).contentTransition(.numericText(countsDown: false)) }
    }
}

/// As on the timer screen: the sides are the controls (the side being fed pauses, the other changes sides); ending
/// sits apart, at the far end.
struct TimerControls: View {
    let type: String
    let s: TimerAttributes.ContentState
    let light: Bool
    var body: some View {
        let c = LogType.color(type)
        let quiet: Color = light ? .white.opacity(0.28) : Color(white: 0.42)
        HStack(spacing: 8) {
            if type == LogType.nurse {
                ForEach(["l", "r"], id: \.self) { k in
                    let on = (s.side ?? "l") == k
                    Button(intent: TimerIntent(type: type, action: "tap-" + k)) {
                        Label(k == "l" ? L10n.t("左", "L") : L10n.t("右", "R"), systemImage: on ? (s.pausedAt == nil ? "pause.fill" : "play.fill") : "arrow.left.arrow.right")
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(on ? Crayon.buttonFill(c) : quiet)
                }
            } else {
                Button(intent: TimerIntent(type: type, action: "pause")) {
                    Label(s.pausedAt == nil ? L10n.t("暂停", "Pause") : L10n.t("继续", "Resume"), systemImage: s.pausedAt == nil ? "pause.fill" : "play.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .frame(maxWidth: .infinity)
                }
                .tint(Crayon.buttonFill(c))
                if type == LogType.sleep {
                    Button(intent: QuickLogDiaperIntent(kind: .wet)) {
                        Label(L10n.t("湿尿布", "Wet"), systemImage: "drop.fill")
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                    .tint(Crayon.buttonFill(LogType.color(LogType.diaper)))
                }
            }
            Spacer(minLength: 10)
            Button(intent: TimerIntent(type: type, action: "stop")) {
                Text(type == LogType.sleep ? L10n.t("醒了", "Awake") : L10n.t("结束", "End"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }.tint(quiet)
        }
        .buttonStyle(.borderedProminent)
        .font(.subheadline.weight(.semibold))
        .privacySensitive()
    }
}
