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
    private static var cache: [String: UIImage] = [:]
    static func image(_ name: String) -> UIImage? {
        if let i = cache[name] { return i }
        for sub in ["widget", "art"] {
            if let url = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: sub), let i = UIImage(contentsOfFile: url.path) {
                cache[name] = i; return i
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

    init(date: Date, snap: Snapshot?, body: JournalFile.Body, size: TodaySize) { self.date = date; self.snap = snap; self.body_ = body; self.size = size }

    private var age: Age? { snap?.birthEpochDay.map { Age.on(birth: Day(epochDay: $0), today: Day(date)) } }
    private var ageText: String { age.map { $0.days > 0 ? "\($0.months) 个月 \($0.days) 天" : "满 \($0.months) 个月" } ?? "填写出生日期" }
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
    private func agoText(_ d: Date) -> String { ago(d, now: date, precise: true) }
    private func agoCard(_ d: Date) -> String { ago(d, now: date) }
    private var journal: Bool { snap?.journal == true }

    var body: some View {
        switch size {
        case .inline: Text("\(ageText)" + (snap?.playName.map { " · \($0)" } ?? ""))
        case .circular: circular
        case .rectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(ageText).font(.headline).widgetAccentable()
                if let t = body_.timers.first {
                    HStack(spacing: 4) {
                        Text(LogType.name(t.type))
                        if let p = t.pausedAt { Text(minutesOf(t.total(p))) } else { Text(t.countsFrom, style: .timer).monospacedDigit() }
                    }.font(.caption)
                } else if let p = snap?.playName { Text(p).font(.caption).lineLimit(1) }
                if journal, let f = lastFeed { Text("喂奶 \(agoText(f))").font(.caption) }
            }
        case .large: large
        case .medium: medium
        case .small: small
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let t = body_.timers.first {
                VStack(spacing: 1) {
                    Image(systemName: t.type == LogType.sleep ? "moon.zzz.fill" : "drop.fill").font(.caption2)
                    if let p = t.pausedAt { Text(minutesOf(t.total(p))).font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit() }
                    else { Text(t.countsFrom, style: .timer).font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit().multilineTextAlignment(.center) }
                }
                .padding(4)
            } else if journal, let f = lastFeed {
                VStack(spacing: 1) {
                    Image(systemName: "drop.fill").font(.caption2)
                    Text(agoCard(f)).font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                }
                .padding(4)
            } else if let a = age {
                VStack(spacing: 0) {
                    Text("\(a.months)").font(.system(size: 20, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("个月").font(.system(size: 9, weight: .semibold, design: .rounded))
                }
            } else {
                Image(systemName: "lamp.desk.fill").font(.title3)
            }
        }
    }

    /// The age as the app shows it: big rounded months, smaller days; the companions in the corner.
    private var head: some View {
        HStack(alignment: .top, spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                if let n = snap?.nickname, !n.isEmpty { Text(n).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1) }
                if let a = age {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(a.months)").font(WidgetInk.numerals(34)).foregroundStyle(WidgetInk.accent)
                        Text("个月").font(.caption2.weight(.semibold))
                        if a.days > 0 { Text("\(a.days)").font(WidgetInk.numerals(17)).foregroundStyle(WidgetInk.accent).padding(.leading, 2); Text("天").font(.caption2.weight(.semibold)) }
                    }
                    .widgetAccentable()
                    .lineLimit(1).minimumScaleFactor(0.7)
                } else { Text("摸索台灯").font(.headline) }
            }
            Spacer(minLength: 0)
            // the companions on a small disc of paper, so Otto's blue still reads on the lamp's blue
            ArtImage(name: WidgetArt.pair).frame(width: 36, height: 36).padding(5).background(Circle().fill(WidgetInk.card))
        }
    }

    /// Today's play (今天一起玩): its tray and its name — the picture first.
    @ViewBuilder private var play: some View {
        if let code = snap?.playCode, let name = snap?.playName {
            // the tray, and under it the name on one line across the column (never broken mid-word)
            VStack(alignment: .leading, spacing: 4) {
                ArtImage(name: WidgetArt.tray(code)).frame(width: 60, height: 45)
                Text(name).font(.footnote.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
    }

    private func running(_ t: RunningTimer) -> some View {
        HStack(spacing: 8) {
            ArtImage(name: WidgetArt.sticker(t.type)).frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text(timerState(t.type, side: t.side, paused: t.pausedAt != nil)).lineLimit(1).minimumScaleFactor(0.8)
                    .font(.caption2.weight(.semibold)).foregroundStyle(Crayon.ink(LogType.color(t.type)))
                if let p = t.pausedAt { Text(minutesOf(t.total(p))).font(WidgetInk.numerals(17)) }
                else { Text(t.countsFrom, style: .timer).font(WidgetInk.numerals(20)) }
            }
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            head
            Spacer(minLength: 4)
            if let t = body_.timers.first { running(t) }
            else if journal { since }
            else { play }
        }
        .foregroundStyle(.primary)
        .widgetURL(body_.timers.first.map { WidgetLinks.care($0.type) })
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
                        Text(t == LogType.nurse ? "上次喂奶" : "上次醒来").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
                        Text(d.map(agoText) ?? "—").font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
                            .foregroundStyle(Crayon.ink(LogType.color(t))).lineLimit(1).minimumScaleFactor(0.8)
                    }
                }
            }
        }
    }

    private var medium: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                head
                Spacer(minLength: 4)
                if journal { play } else if let t = body_.timers.first { running(t) } else { play }
            }
            if journal {
                HStack(spacing: 6) {
                    timerButton(LogType.nurse)
                    timerButton(LogType.sleep)
                    nappy
                }
                .frame(width: 168)
            }
        }
        .foregroundStyle(.primary)
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
        .background(WidgetInk.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Each card opens its page in the app — a feed or a sleep starts only there, where it is seen (nothing starts
    /// from the Home Screen by accident); a running one opens its clock to pause, change side or end.
    private func timerButton(_ type: String) -> some View {
        let t = body_.timers.first { $0.type == type }
        // running: the card is the clock (how long so far)
        let sub: Text? = t.map { t in t.pausedAt.map { Text(minutesOf(t.total($0))) } ?? Text(t.countsFrom, style: .timer) } ?? last(type).map { Text(agoCard($0)) }
        return Link(destination: WidgetLinks.care(type)) {
            card(type, title: LogType.name(type), sub: sub, on: t != nil)
        }
    }

    /// A nappy: opens the nappy page (wet, dirty or both), where one tap records it.
    private var nappy: some View {
        Link(destination: WidgetLinks.log(LogType.diaper)) {
            card(LogType.diaper, title: "尿布", sub: last(LogType.diaper).map { Text(agoCard($0)) }, on: false)
        }
    }

    /// Large Home Screen dashboard: age & companions, today's summary strip, today's play card, and interactive
    /// one-tap care buttons (log wet/dirty diaper, start/stop nursing or sleep without opening the app).
    private var large: some View {
        let day = Day(date)
        let startMs = day.date.timeIntervalSince1970 * 1000
        let todayLogs = body_.logs.filter { $0.start >= startMs || ($0.start < startMs && ($0.end ?? $0.start) > startMs) }
        let feeds = todayLogs.feedCount(from: startMs)
        let sleepSec = todayLogs.filter { $0.type == LogType.sleep }.reduce(0.0) { $0 + $1.seconds(on: day) }
        let diapers = todayLogs.filter { $0.type == LogType.diaper && !$0.carriedOver(into: day) }.count
        return VStack(alignment: .leading, spacing: 10) {
            head
            if journal {
                HStack(spacing: 8) {
                    statPill("喂奶", "\(feeds) 次", LogType.color(LogType.nurse))
                    statPill("睡眠", sleepSec > 0 ? minutesOf(sleepSec) : "—", LogType.color(LogType.sleep))
                    statPill("尿布", "\(diapers) 次", LogType.color(LogType.diaper))
                }
            }
            if let code = snap?.playCode, let name = snap?.playName {
                HStack(spacing: 12) {
                    ArtImage(name: WidgetArt.tray(code)).frame(width: 68, height: 50)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("今天一起玩").font(.caption2.weight(.semibold)).foregroundStyle(WidgetInk.accent)
                        Text(name).font(.subheadline.weight(.bold)).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(WidgetInk.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            if journal {
                Spacer(minLength: 0)
                if let t = body_.timers.first {
                    running(t)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(WidgetInk.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                HStack(spacing: 8) {
                    QuickCareFace.timerTile(body: body_, kind: .nurse, compact: true)
                    QuickCareFace.timerTile(body: body_, kind: .sleep, compact: true)
                    QuickCareFace.diaperTile(kind: .wet, title: "湿尿布", symbol: "drop.fill", compact: true)
                    QuickCareFace.diaperTile(kind: .dirty, title: "便尿布", symbol: "leaf.fill", compact: true)
                }
                .frame(height: 68)
            } else {
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(.primary)
    }

    private func statPill(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(Crayon.ink(color)).lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(WidgetInk.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: Interactive Quick Care Widget (Home Screen — zero-open logging)

struct QuickCareFace: View {
    let date: Date
    let snap: Snapshot?
    let body_: JournalFile.Body
    let isMedium: Bool

    private var lastFeed: Date? { LastFact.of(LogType.nurse, in: body_.logs)?.at }
    private var lastWake: Date? { LastFact.of(LogType.sleep, in: body_.logs)?.at }

    var body: some View {
        if isMedium {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        ArtImage(name: WidgetArt.pair).frame(width: 22, height: 22)
                        Text("一键记录").font(.caption.weight(.bold)).foregroundStyle(WidgetInk.accent)
                    }
                    Spacer(minLength: 0)
                    miniFact("上次喂奶", lastFeed, LogType.nurse)
                    miniFact("上次醒来", lastWake, LogType.sleep)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                grid.frame(width: 176)
            }
            .foregroundStyle(.primary)
        } else {
            grid.foregroundStyle(.primary)
        }
    }

    private var grid: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Self.timerTile(body: body_, kind: .nurse, compact: !isMedium)
                Self.timerTile(body: body_, kind: .sleep, compact: !isMedium)
            }
            HStack(spacing: 6) {
                Self.diaperTile(kind: .wet, title: "湿尿布", symbol: "drop.fill", compact: !isMedium)
                Self.diaperTile(kind: .dirty, title: "便尿布", symbol: "leaf.fill", compact: !isMedium)
            }
        }
    }

    private func miniFact(_ label: String, _ at: Date?, _ type: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.secondary)
            Text(at.map { ago($0, now: date, precise: true) } ?? "—")
                .font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(Crayon.ink(LogType.color(type))).lineLimit(1).minimumScaleFactor(0.75)
        }
    }

    static func timerTile(body: JournalFile.Body, kind: CareTimerAppEnum, compact: Bool) -> some View {
        let type = kind == .nurse ? LogType.nurse : LogType.sleep
        let t = body.timers.first { $0.type == type }
        let c = LogType.color(type)
        let running = t != nil
        return Button(intent: ToggleCareTimerIntent(careType: kind)) {
            VStack(spacing: 2) {
                ArtImage(name: WidgetArt.sticker(type)).frame(width: compact ? 24 : 26, height: compact ? 24 : 26)
                if let t {
                    if let p = t.pausedAt {
                        Text(minutesOf(t.total(p))).font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(Crayon.ink(c))
                    } else {
                        Text(t.countsFrom, style: .timer).font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(Crayon.ink(c)).multilineTextAlignment(.center)
                    }
                } else {
                    Text(LogType.name(type)).font(.caption2.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(running ? c.opacity(0.18) : WidgetInk.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(running ? c.opacity(0.75) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    static func diaperTile(kind: DiaperKindAppEnum, title: String, symbol: String, compact: Bool) -> some View {
        let c = LogType.color(LogType.diaper)
        return Button(intent: QuickLogDiaperIntent(kind: kind)) {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: compact ? 15 : 16, weight: .bold)).foregroundStyle(Crayon.ink(c))
                Text(title).font(.caption2.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WidgetInk.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: Bedside Lamp Widget (StandBy & Night Mode — Otto's warm amber glow)

struct BedsideLampFace: View {
    let date: Date
    let snap: Snapshot?
    let body_: JournalFile.Body
    let isMedium: Bool

    private var age: Age? { snap?.birthEpochDay.map { Age.on(birth: Day(epochDay: $0), today: Day(date)) } }
    private var lastFeed: Date? { LastFact.of(LogType.nurse, in: body_.logs)?.at }
    private var lastWake: Date? { LastFact.of(LogType.sleep, in: body_.logs)?.at }

    var body: some View {
        let amber = Color(red: 0xF5 / 255, green: 0xC6 / 255, blue: 0x6A / 255)
        ZStack {
            RadialGradient(colors: [amber.opacity(0.28), Color.clear], center: UnitPoint(x: 0.22, y: 0.22), startRadius: 4, endRadius: isMedium ? 160 : 110)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    ArtImage(name: WidgetArt.pair)
                        .frame(width: 34, height: 34)
                        .padding(5)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("摸索台灯").font(.caption2.weight(.semibold)).foregroundStyle(amber)
                        if let a = age {
                            Text("第 \(a.lived) 天").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.88)).monospacedDigit()
                        }
                    }
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 2)
                if let t = body_.timers.first {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(timerState(t.type, side: t.side, paused: t.pausedAt != nil))
                            .font(.caption.weight(.semibold)).foregroundStyle(amber)
                        if let p = t.pausedAt {
                            Text(minutesOf(t.total(p))).font(WidgetInk.numerals(isMedium ? 32 : 24)).foregroundStyle(.white)
                        } else {
                            Text(t.countsFrom, style: .timer).font(WidgetInk.numerals(isMedium ? 32 : 24)).foregroundStyle(.white)
                        }
                    }
                } else if isMedium {
                    HStack(spacing: 14) {
                        lampMetric("上次喂奶", lastFeed, amber)
                        lampMetric("上次醒来", lastWake, Color(red: 0x8F / 255, green: 0xB8 / 255, blue: 0xFF / 255))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        lampMetric("上次喂奶", lastFeed, amber)
                        lampMetric("上次醒来", lastWake, Color(red: 0x8F / 255, green: 0xB8 / 255, blue: 0xFF / 255))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .environment(\.colorScheme, .dark)
        .widgetURL(body_.timers.first.map { WidgetLinks.care($0.type) })
    }

    private func lampMetric(_ label: String, _ at: Date?, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.6))
            Text(at.map { ago($0, now: date, precise: isMedium) } ?? "安睡中")
                .font(.system(size: isMedium ? 16 : 13, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.75)
        }
    }
}

enum WidgetLinks {
    static func care(_ type: String) -> URL { URL(string: "mossling://care/\(type)")! }
    static func log(_ type: String) -> URL { URL(string: "mossling://log/\(type)")! }
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
                    Text(timerState(type, side: s.side, paused: s.pausedAt != nil))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Crayon.ink(c))
                    TimerFace.elapsed(s).font(WidgetInk.numerals(34)).foregroundStyle(.primary)
                    if let n = s.note { Text(n).font(.caption.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit() }
                }
                Spacer(minLength: 0)
                ArtImage(name: WidgetArt.pair).frame(width: 42, height: 42).padding(6).background(Circle().fill(WidgetInk.card))
            }
            TimerControls(type: type, s: s, light: true)
        }
        .padding(16)
    }
    @ViewBuilder static func elapsed(_ s: TimerAttributes.ContentState) -> some View {
        if let p = s.pausedAt { Text(minutesOf(p.timeIntervalSince(s.start))) }
        else { Text(timerInterval: s.start...Date.distantFuture, countsDown: false).monospacedDigit() }
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
                        Label(k == "l" ? "左" : "右", systemImage: on ? (s.pausedAt == nil ? "pause.fill" : "play.fill") : "arrow.left.arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(on ? Crayon.buttonFill(c) : quiet)
                }
            } else {
                Button(intent: TimerIntent(type: type, action: "pause")) {
                    Label(s.pausedAt == nil ? "暂停" : "继续", systemImage: s.pausedAt == nil ? "pause.fill" : "play.fill").frame(maxWidth: .infinity)
                }
                .tint(Crayon.buttonFill(c))
            }
            Spacer(minLength: 10)
            Button(intent: TimerIntent(type: type, action: "stop")) { Text(type == LogType.sleep ? "醒了" : "结束") }.tint(quiet)
        }
        .buttonStyle(.borderedProminent)
        .font(.subheadline.weight(.semibold))
    }
}
