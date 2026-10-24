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

enum TodaySize { case small, medium, rectangular, inline }

struct TodayFace: View {
    let date: Date
    let snap: Snapshot?
    let body_: JournalFile.Body
    let size: TodaySize

    init(date: Date, snap: Snapshot?, body: JournalFile.Body, size: TodaySize) { self.date = date; self.snap = snap; self.body_ = body; self.size = size }

    private var age: Age? { snap?.birthEpochDay.map { Age.on(birth: Day(epochDay: $0), today: Day(date)) } }
    private var ageText: String { age.map { $0.days > 0 ? "\($0.months) 个月 \($0.days) 天" : "满 \($0.months) 个月" } ?? "填写出生日期" }
    private func last(_ t: String) -> Date? { body_.logs.filter { $0.type == t }.max { $0.start < $1.start }.map { Date(timeIntervalSince1970: ($0.end ?? $0.start) / 1000) } }
    private func agoText(_ d: Date) -> String {
        let m = Int(date.timeIntervalSince(d) / 60)
        return m < 2 ? "刚刚" : m < 60 ? "\(m) 分钟前" : m < 48 * 60 ? "\(m / 60) 小时前" : "\(m / 1440) 天前"
    }
    private var journal: Bool { snap?.journal == true }

    var body: some View {
        switch size {
        case .inline: Text("\(ageText)" + (snap?.playName.map { " · \($0)" } ?? ""))
        case .rectangular:
            VStack(alignment: .leading, spacing: 1) {
                Text(ageText).font(.headline).widgetAccentable()
                if let t = body_.timers.first {
                    HStack(spacing: 4) {
                        Text(LogType.name(t.type))
                        if let p = t.pausedAt { Text(minutesOf(t.total(p))) } else { Text(t.countsFrom, style: .timer).monospacedDigit() }
                    }.font(.caption)
                } else if let p = snap?.playName { Text(p).font(.caption).lineLimit(1) }
                if journal, let f = [last(LogType.nurse), last(LogType.bottle)].compactMap({ $0 }).max() { Text("喂奶 \(agoText(f))").font(.caption) }
            }
        case .medium: medium
        case .small: small
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

    /// Today's play: its tray from the shelf and its name — the picture first.
    @ViewBuilder private var play: some View {
        if let code = snap?.playCode, let name = snap?.playName {
            HStack(alignment: .center, spacing: 8) {
                ArtImage(name: WidgetArt.tray(code)).frame(width: 60, height: 45)
                Text(name).font(.footnote.weight(.semibold)).lineLimit(2).minimumScaleFactor(0.85)
            }
        }
    }

    private func running(_ t: RunningTimer) -> some View {
        HStack(spacing: 8) {
            ArtImage(name: WidgetArt.sticker(t.type)).frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text(LogType.name(t.type) + (t.side == "l" ? " · 左" : t.side == "r" ? " · 右" : "") + (t.pausedAt != nil ? " · 暂停" : ""))
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
            if let t = body_.timers.first { running(t) } else { play }
        }
        .foregroundStyle(.primary)
        .widgetURL(body_.timers.first.map { WidgetLinks.care($0.type) })
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
        let sub: Text? = t.map { t in t.pausedAt.map { Text(minutesOf(t.total($0))) } ?? Text(t.countsFrom, style: .timer) } ?? last(type).map { Text(agoText($0)) }
        return Link(destination: WidgetLinks.care(type)) {
            card(type, title: LogType.name(type), sub: sub, on: t != nil)
        }
    }

    /// A nappy: opens the nappy page (wet, dirty or both), where one tap records it.
    private var nappy: some View {
        Link(destination: WidgetLinks.log(LogType.diaper)) {
            card(LogType.diaper, title: "尿布", sub: last(LogType.diaper).map { Text(agoText($0)) }, on: false)
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
                    Text(LogType.name(type) + TimerFace.side(s.side) + (s.pausedAt != nil ? " · 暂停中" : ""))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Crayon.ink(c))
                    TimerFace.elapsed(s).font(WidgetInk.numerals(34)).foregroundStyle(.primary)
                    if let n = s.note { Text(n).font(.caption.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit() }
                }
                Spacer(minLength: 0)
                ArtImage(name: WidgetArt.pair).frame(width: 42, height: 42).padding(6).background(Circle().fill(WidgetInk.card))
            }
            TimerControls(type: type, s: s, light: false)
        }
        .padding(16)
    }
    static func side(_ s: String?) -> String { s == "l" ? " · 左侧" : s == "r" ? " · 右侧" : "" }
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
