import SwiftUI
import TipKit

/// The page of a feed or a sleep — the one place a timer starts, runs and ends (build 169, after "点一下就开始了，点进去
///发现已经开始很久了"). Tapping 亲喂 or 睡觉 anywhere opens this page *not yet running*: the sides (or the moon) say
/// 点按开始, and when it began can be set first (now, a few minutes ago, or a chosen time) — so nothing starts by
/// accident and nothing starts unseen. Once running, one gesture runs the clock: tap the side being fed to pause, tap
/// it again to go on; tap the other side to change sides. Each side keeps its own time, drawn as a ring of beads round
/// it; under the sides, the whole feed and its pauses. Ending sits alone at the bottom.
///
/// The page also checks itself: a feed running over an hour, a pause over twenty minutes, or a sleep over twelve hours
/// is asked about ("还在喂吗？") with a way to give the real end time, and a feed cannot start unnoticed while a sleep
/// runs (or the other way round).
struct TimerScreen: View {
    @Environment(JournalStore.self) private var j
    @Environment(AppModel.self) private var app
    @Environment(\.lamp) private var lamp
    @Environment(\.dismiss) private var dismiss
    let type: String
    @State private var picking = false
    @State private var ending = false
    @State private var acked: Set<String> = []
    @State private var adding = false
    /// Before starting: when it began, in minutes before now (0 = now); a chosen time when picked.
    @State private var startAgo = 0
    @State private var startAt: Date?
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var pickingStart = false

    var body: some View {
        let c = LogType.color(type)
        let activeTimer = j.timers.first(where: { $0.type == type })
        NavigationStack {
            ZStack {
                if let t = activeTimer {
                    running(t, c)
                        .transition(reduce ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                } else {
                    ready(c)
                        .transition(reduce ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .animation(reduce ? nil : .spring(response: 0.38, dampingFraction: 0.84), value: activeTimer != nil)
            .background {
                // the same air as every page — sunlight and seeds by day, the lamp and its motes at night — tinted by
                // the kind being timed
                ZStack {
                    PageBackground(tone: c)
                    if !lamp { RadialGradient(colors: [c.opacity(0.2), c.opacity(0)], center: .top, startRadius: 0, endRadius: 520).ignoresSafeArea() }
                }
            }
            .navigationTitle(L10n.logName(type))
            .navigationBarTitleDisplayMode(.inline)
            .toasts(bottom: true)
        }
    }

    // MARK: before starting

    private var lastNurseSide: String? { j.logs.filter { $0.type == LogType.nurse }.max { $0.start < $1.start }?.side }
    /// The side to start on: the one not used last time.
    private var suggested: String { lastNurseSide == "l" ? "r" : "l" }
    private var chosenStart: Date { startAt ?? Date().addingTimeInterval(-Double(startAgo) * 60) }
    private var other: String { type == LogType.nurse ? LogType.sleep : LogType.nurse }

    private func ready(_ c: Color) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                Duo(primary: app.companion, size: 62, mood: .open, look: CGPoint(x: 0, y: 0.5), poke: true, night: lamp)
                    .frame(maxWidth: .infinity).padding(.top, 4)
                Text(type == LogType.nurse ? L10n.t("从哪一侧开始", "Which side to start?") : L10n.t("宝宝要睡了", "Ready for sleep")).font(.title3.weight(.bold))
                LastLine(type: type)

                // something else still running: say so here, so two clocks never run unnoticed
                if let o = j.timers.first(where: { $0.type == other }) {
                    TimelineView(.periodic(from: .now, by: 30)) { tl in
                        Notice(type: other, text: L10n.t(LogType.name(other) + "还在计时", L10n.logName(other) + " is still running"), detail: L10n.t("已经 " + durationValue(o.total(ms(tl.date))), L10n.duration(o.total(ms(tl.date))) + " elapsed"),
                               action: other == LogType.sleep ? L10n.t("先记醒了", "Mark Awake") : L10n.t("先记喂完", "End Feed")) { withAnimation(.snappy) { j.stop(other) } }
                    }
                }

                if type == LogType.nurse {
                    TipView(SideTip())
                    HStack(spacing: 12) {
                        ForEach(["l", "r"], id: \.self) { k in
                            SidePad(side: k, seconds: 0, state: .ready(suggested: k == suggested), color: c) { begin(side: k) }
                        }
                    }
                } else {
                    SleepPad(seconds: 0, paused: true, ready: true, color: c) { begin(side: nil) }
                }

                // when it began: now unless said otherwise — set before starting, shown on the button
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.t("开始时间", "Start Time")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                    WrapLayout(spacing: 8) {
                        // the same choices as every record's time: 现在, 5, 10, 15, 30 minutes, an hour
                        ForEach([0, 5, 10, 15, 30, 60], id: \.self) { m in
                            let on = startAt == nil && startAgo == m
                            Button(m == 0 ? L10n.t("现在", "Now") : m == 60 ? L10n.t("1 小时前", "1 hr ago") : L10n.t("\(m) 分钟前", "\(m) min ago")) { withAnimation(.snappy) { startAt = nil; startAgo = m } }
                                .buttonStyle(.vinyl(on ? c : Color(hex: 0x8A8279)))
                                .fontWeight(on ? .semibold : .regular).accessibilityAddTraits(on ? .isSelected : [])
                        }
                        Button(startAt.map { whenLabel($0) } ?? L10n.t("其他时间…", "Other…")) { pickingStart = true }
                            .buttonStyle(.vinyl(startAt != nil ? c : Color(hex: 0x8A8279)))
                            .fontWeight(startAt != nil ? .semibold : .regular)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .printCard(radius: Radius.card)
                .sensoryFeedback(.selection, trigger: startAgo)
            }
            .padding(.horizontal, 20).padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(L10n.t("关闭", "Close"), systemImage: "xmark") { dismiss() } }
        }
        // already over: add it with its start and end instead of timing it
        .safeAreaBar(edge: .bottom) {
            Button { adding = true } label: {
                Label(type == LogType.sleep ? L10n.t("已经睡过了？补记一段", "Already slept? Log past sleep") : L10n.t("已经喂完了？补记一次", "Already fed? Log past feed"), systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.glass).controlSize(.large)
            .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 6)
        }
        .sheet(isPresented: $pickingStart) {
            TimeSheet(title: L10n.t("开始时间", "Start Time"), initial: startAt ?? Date()) { startAt = $0 }.lampPresented()
        }
        .sheet(isPresented: $adding) {
            EntrySheet(entry: LogEntry(type: type, start: ms(Date().addingTimeInterval(type == LogType.sleep ? -3600 : -20 * 60)), end: ms(Date()),
                                       side: type == LogType.nurse ? suggested : nil), isNew: true)
                .lampPresented()
        }
    }

    private func begin(side: String?) {
        withAnimation(.snappy) { j.start(type, side: side, at: min(chosenStart, Date())) }
        startAgo = 0; startAt = nil
    }

    // MARK: running

    @ViewBuilder private func running(_ t: RunningTimer, _ c: Color) -> some View {
        let paused = t.pausedAt != nil
        let side = t.side ?? "l"
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            let now = tl.date.timeIntervalSince1970 * 1000
            ScrollView {
                VStack(spacing: 18) {
                    if let q = question(t, now) {
                        Check(text: q.text, keep: q.keep, end: q.end, color: c,
                              onKeep: { acked.insert(q.key) }, onEnd: { ending = true })
                    }
                    Duo(primary: app.companion, size: 62,
                        mood: type == LogType.sleep && !paused ? .sleep : .open,
                        look: type == LogType.nurse ? CGPoint(x: side == "l" ? -0.9 : 0.9, y: 0.6) : CGPoint(x: 0, y: 0.5),
                        poke: true, night: lamp)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    LastLine(type: type, until: t.start - t.carried - t.carriedPause, compact: true)

                    if type == LogType.nurse {
                        HStack(spacing: 12) {
                            ForEach(["l", "r"], id: \.self) { k in
                                let done = j.logs.feedSides(before: t.start)[k] ?? 0
                                SidePad(side: k, seconds: done + (k == side ? t.elapsed(now) : 0),
                                        state: k != side ? .other : paused ? .paused : .running, color: c) {
                                    withAnimation(.snappy) { j.tapSide(type, k) }
                                }
                            }
                        }
                    } else {
                        SleepPad(seconds: t.total(now), paused: paused, color: c) {
                            withAnimation(.snappy) { j.togglePause(type) }
                        }
                    }

                    HStack(spacing: 0) {
                        // a sleep shows its length once, in the moon; here, when it began instead
                        if type == LogType.sleep {
                            Button { picking = true } label: {
                                Stat(title: L10n.t("睡着于", "Asleep since"), value: whenLabel(Date(timeIntervalSince1970: t.start / 1000)), strong: true)
                            }
                            .buttonStyle(.toy).accessibilityHint(L10n.t("改开始时间", "Change start time"))
                        } else {
                            Stat(title: L10n.t("合计", "Total"), value: span(t.total(now)), strong: true, tint: Crayon.ink(c))
                        }
                        Divider().frame(height: 34)
                        Stat(title: L10n.t("暂停", "Paused"), value: t.paused(now) >= 1 ? span(t.paused(now)) : "—", strong: false)
                    }
                    .padding(.vertical, 12)
                    .printCard(radius: Radius.card)

                    if type != LogType.sleep {
                        Button { picking = true } label: {
                            Label(L10n.t("开始于 ", "Started ") + whenLabel(Date(timeIntervalSince1970: (t.start - t.carried - t.carriedPause) / 1000)), systemImage: "clock")
                                .font(.subheadline).monospacedDigit()
                        }
                        .buttonStyle(.glass)
                    }
                }
                .padding(.horizontal, 20).padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button(L10n.t("收起", "Minimize"), systemImage: "chevron.down") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(L10n.t("已经结束了，选结束时间", "Already finished — pick end time"), systemImage: "clock.badge.checkmark") { ending = true }
                    Button(L10n.t("提前 5 分钟开始", "Start 5 min earlier"), systemImage: "gobackward.5") { j.shift(type, to: Date(timeIntervalSince1970: t.start / 1000 - 300)) }
                    Button(L10n.t("提前 15 分钟开始", "Start 15 min earlier"), systemImage: "gobackward.15") { j.shift(type, to: Date(timeIntervalSince1970: t.start / 1000 - 900)) }
                    Divider()
                    Button(L10n.t("不记这一次", "Discard timer"), systemImage: "xmark", role: .destructive) { j.discard(type) }
                } label: { Image(systemName: "ellipsis") }.accessibilityLabel(L10n.t("更多", "More"))
            }
        }
        // ending, alone: a full-width button in its own band, nothing beside it to hit by mistake
        .safeAreaBar(edge: .bottom) {
            Button { j.stop(type); dismiss() } label: {
                Label(type == LogType.sleep ? L10n.t("醒了，记下", "Awake — Save") : L10n.t("喂完了，记下", "Done — Save"), systemImage: "checkmark")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .buttonStyle(.glassProminent).tint(Crayon.fill(c, lamp)).controlSize(.large)
            .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 6)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: paused)
        .sensoryFeedback(.selection, trigger: side)
        .sheet(isPresented: $picking) {
            TimeSheet(title: L10n.t("开始时间", "Start Time"), initial: Date(timeIntervalSince1970: t.start / 1000)) { j.shift(type, to: $0) }.lampPresented()
        }
        .sheet(isPresented: $ending) {
            // the real end: not before it began, not later than now (or than the pause, if paused)
            TimeSheet(title: type == LogType.sleep ? L10n.t("什么时候醒的", "When did they wake?") : L10n.t("什么时候喂完的", "When did the feed end?"),
                      initial: t.pausedAt.map { Date(timeIntervalSince1970: $0 / 1000) } ?? Date(),
                      notBefore: Date(timeIntervalSince1970: t.start / 1000)) { d in j.stop(type, at: d); dismiss() }
                .lampPresented()
        }
    }

    /// A running timer that looks forgotten: asked about once per timer (per question) while this page is open.
    private func question(_ t: RunningTimer, _ now: Double) -> (key: String, text: String, keep: String, end: String)? {
        let key = "\(t.type)-\(Int(t.start))"
        if let p = t.pausedAt, now - p > 20 * 60_000, !acked.contains(key + "p") {
            let dur = durationValue((now - p) / 1000)
            return (key + "p",
                    L10n.t("已经暂停了 " + dur + "。" + (type == LogType.sleep ? "宝宝已经醒了吗？" : "这一顿喂完了吗？"),
                           "Paused for " + dur + ". " + (type == LogType.sleep ? "Already awake?" : "Finished feeding?")),
                    type == LogType.sleep ? L10n.t("还在睡", "Still asleep") : L10n.t("还没喂完", "Still feeding"),
                    type == LogType.sleep ? L10n.t("选醒来时间", "Set wake time") : L10n.t("选结束时间", "Set end time"))
        }
        let total = t.total(now)
        if type == LogType.nurse, total > 3600, !acked.contains(key) {
            let dur = durationValue(total)
            return (key, L10n.t("这次亲喂已经计时 " + dur + "，还在喂吗？", "Nursing has run for " + dur + ". Still feeding?"),
                    L10n.t("还在喂", "Still feeding"), L10n.t("选结束时间", "Set end time"))
        }
        if type == LogType.sleep, total > 12 * 3600, !acked.contains(key) {
            let dur = durationValue(total)
            return (key, L10n.t("已经睡了 " + dur + "，是不是忘了记醒来？", "Asleep for " + dur + ". Forgot to log wake?"),
                    L10n.t("还在睡", "Still asleep"), L10n.t("选醒来时间", "Set wake time"))
        }
        return nil
    }
}

/// Another timer still running, said on the page about to start one.
private struct Notice: View {
    let type: String, text: String, detail: String, action: String
    let tap: () -> Void
    var body: some View {
        let c = LogType.color(type)
        HStack(spacing: 10) {
            IconTile(symbol: LogType.symbol(type), color: c, size: 30, round: true)
            VStack(alignment: .leading, spacing: 1) {
                Text(text).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(Palette.secondaryText).monospacedDigit()
            }
            Spacer(minLength: 6)
            Button(action, action: tap).buttonStyle(.vinyl(c))
        }
        .padding(12)
        .background(c.opacity(0.14), in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
    }
}

/// The page asking about a timer that looks forgotten: keep it running, or give the real end time.
private struct Check: View {
    let text: String, keep: String, end: String
    let color: Color
    let onKeep: () -> Void
    let onEnd: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(text, systemImage: "questionmark.circle.fill").font(.subheadline.weight(.semibold))
                .labelStyle(.titleAndIcon).foregroundStyle(.primary)
            HStack(spacing: 10) {
                Button(action: onKeep) { Text(keep).frame(maxWidth: .infinity) }.buttonStyle(.vinyl(color))
                Button(action: onEnd) { Text(end).frame(maxWidth: .infinity) }.buttonStyle(.vinyl(Crayon.buttonFill(color), prominent: true))
            }
            .font(.subheadline.weight(.semibold)).controlSize(.large)
        }
        .padding(14)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).strokeBorder(Crayon.ink(color).opacity(0.5), lineWidth: 1.5))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// One side of a feed, and its control. Being fed: a deep pad, its minutes as lit beads round the time, breathing
/// slowly. Paused: the pad goes pale, the beads stay. The other side: pale, waiting for a tap.
private struct SidePad: View {
    enum Mode: Equatable { case running, paused, other, ready(suggested: Bool) }
    let side: String
    let seconds: Double
    let state: Mode
    let color: Color
    let tap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.lamp) private var lamp

    var body: some View {
        Button(action: tap) { face }
            .buttonStyle(.toy)
            .accessibilityLabel((side == "l" ? L10n.t("左侧", "Left") : L10n.t("右侧", "Right")) + (isReady ? "" : " " + minutesOf(seconds)))
            .accessibilityHint(hint)
            .accessibilityAddTraits(state == .other || isReady ? [] : .isSelected)
            .accessibilityValue(state == .ready(suggested: true) ? L10n.t("建议从这一侧开始", "Suggested side to start") : "")
    }

    // Split out of `body`: the whole pad in one expression was more than the type checker would chew through.
    private var face: some View {
        ZStack {
            Dial(seconds: seconds, color: on ? (lamp ? Palette.lampInk : Color.white) : color)
                .padding(8)
                .opacity(state == .other || isReady ? 0.55 : 1)
            label
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background { pad }
        .overlay(alignment: .topTrailing) { badge }
        .animation(reduce ? nil : .spring(response: 0.32, dampingFraction: 0.78), value: state)
        .modifier(Breathe(on: state == .running && !reduce, amount: 1.015, period: 1.6))
    }

    private var label: some View {
        VStack(spacing: 2) {
            Text(side == "l" ? L10n.t("左", "Left") : L10n.t("右", "Right")).font(Typeface.numerals(28, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.75)
            Group {
                // before it starts the big 左 / 右 already names the side: the line keeps its height, empty
                if isReady { Text("00:00").hidden() }
                else { Ticking(text: seconds >= 1 ? clock(seconds) : "—") }   // 余影: each second leaves an afterimage
            }
            .font(Typeface.numerals(20, relativeTo: .title3, weight: .bold))
            .lineLimit(1).minimumScaleFactor(0.6)
            hintRow
        }
        .foregroundStyle(ink)
    }

    private var hintRow: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(hint).lineLimit(1).minimumScaleFactor(0.7)
        }
        .font(.caption2.weight(.bold)).dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(on ? (lamp ? Palette.lampInk : Color.white).opacity(0.18) : color.opacity(0.16)))
        .padding(.top, 4)
    }

    @ViewBuilder private var pad: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.stage, style: .continuous)
        ZStack {
            shape
                .fill(on ? AnyShapeStyle(LinearGradient(colors: [Crayon.fill(color, lamp).mix(with: color, by: lamp ? 0.05 : 0.12), Crayon.fill(color, lamp)], startPoint: .top, endPoint: .bottom))
                         : AnyShapeStyle(color.opacity(state == .paused ? (lamp ? 0.34 : 0.22) : lamp ? 0.16 : 0.12)))
                .shadow(color: on && !lamp ? color.opacity(0.4) : .clear, radius: 12, y: 6)
            // 3D: lit from above like the buttons and tokens — a lighter top and a lit rim
            if ArtStyle.current == .vinyl {
                shape.fill(LinearGradient(colors: [.white.opacity(on ? 0.24 : (lamp ? 0.05 : 0.45)), .white.opacity(0)], startPoint: .top, endPoint: .center))
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(lamp ? 0.16 : 0.8), .white.opacity(0)], startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
            }
            // paused: the side stays coloured (it is still this side's feed) with a solid rim
            if state == .paused {
                shape.strokeBorder(Crayon.ink(color), lineWidth: 2.5)
            }
        }
    }

    @ViewBuilder private var badge: some View {
        if state == .ready(suggested: true) {
            Text(L10n.t("建议", "Suggested")).font(.caption2.weight(.bold)).padding(.horizontal, 7).padding(.vertical, 3)
                .background(Capsule().fill(.white.opacity(0.92))).foregroundStyle(Crayon.buttonFill(color)).padding(10)
        }
    }

    private var on: Bool { state == .running || state == .ready(suggested: true) }
    private var ink: Color { on ? (lamp ? Palette.lampInk : Color.white) : Crayon.ink(color) }
    // named: the nested ternary inside Image(systemName:) made the type checker give up
    private var symbol: String { isReady ? "play.fill" : on ? "pause.fill" : state == .paused ? "play.fill" : "arrow.left.arrow.right" }

    private var isReady: Bool { if case .ready = state { true } else { false } }
    private var hint: String {
        switch state {
        case .running: L10n.t("点按暂停", "Tap to pause")
        case .paused: L10n.t("点按继续", "Tap to resume")
        case .other: L10n.t("点按换到这侧", "Tap to switch")
        case .ready: L10n.t("点按开始", "Tap to start")
        }
    }
}

/// A sleep, as one moon to tap: tap to pause (a wake in the night), tap again to go on.
private struct SleepPad: View {
    let seconds: Double
    let paused: Bool
    var ready = false
    let color: Color
    let tap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.lamp) private var lamp

    /// Under the lamp the moon's figures are a warm, dimmed cream, not white: at 3 a.m. the brightest thing on the
    /// screen should be no brighter than the lamp itself.
    private var light: Color { lamp ? Palette.lampInk : .white }

    var body: some View {
        // The moon starts a sleep; once it runs, the moon only shows it. Pausing is its own small button, so a hand
        // that brushes the screen in the dark does not stop the count.
        if ready {
            Button(action: tap) { face }
                .buttonStyle(.toy)
                .accessibilityLabel(L10n.t("开始睡觉", "Start Sleep"))
                .accessibilityHint(L10n.t("点按开始计时", "Tap to start sleep timer"))
        } else {
            face
                .accessibilityElement(children: .contain)
        }
    }

    private var face: some View {
        let ink = paused && !ready ? Crayon.ink(color) : light
        return ZStack {
            Dial(seconds: seconds, color: paused && !ready ? color : light).padding(10)
            VStack(spacing: 6) {
                IconTile(symbol: LogType.symbol(LogType.sleep), color: color, size: 46, round: true)
                Group {
                    if ready { Text(L10n.t("开始睡觉", "Start Sleep")) } else { Ticking(text: clock(seconds)) }
                }
                .font(Typeface.numerals(ready ? 30 : 38, relativeTo: .largeTitle, weight: .bold))
                .lineLimit(1).minimumScaleFactor(0.6)
                .accessibilityLabel(ready ? L10n.t("开始睡觉", "Start Sleep") : L10n.t("睡眠 ", "Sleep ") + minutesOf(seconds))
                // before it starts the moon already says 开始睡觉: no second line saying it again
                if !ready {
                    Button(action: tap) {
                        HStack(spacing: 4) {
                            Image(systemName: paused ? "play.fill" : "pause.fill")
                            Text(paused ? L10n.t("继续", "Resume") : L10n.t("暂停", "Pause")).lineLimit(1)
                        }
                        .font(.subheadline.weight(.bold)).dynamicTypeSize(...DynamicTypeSize.xxLarge)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Capsule().fill(paused ? color.opacity(0.16) : light.opacity(0.18)))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.toy)
                    .accessibilityLabel(paused ? L10n.t("继续睡眠计时", "Resume sleep timer") : L10n.t("暂停睡眠计时", "Pause sleep timer"))
                }
            }
            .frame(width: 170)
            .foregroundStyle(ink)
        }
        .frame(width: 250, height: 250)
        .background {
            ZStack {
                Circle()
                    .fill(paused && !ready ? AnyShapeStyle(color.opacity(0.14))
                          : AnyShapeStyle(RadialGradient(colors: [Crayon.fill(color, lamp).mix(with: color, by: lamp ? 0.06 : 0.15), Crayon.fill(color, lamp)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 240)))
                    .shadow(color: (paused && !ready) || lamp ? .clear : color.opacity(0.4), radius: 16, y: 8)
                if ArtStyle.current == .vinyl {
                    Circle().fill(LinearGradient(colors: [.white.opacity(paused && !ready ? (lamp ? 0.05 : 0.45) : 0.24), .white.opacity(0)], startPoint: .top, endPoint: .center))
                    Circle().strokeBorder(LinearGradient(colors: [.white.opacity(lamp ? 0.16 : 0.8), .white.opacity(0)], startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
                }
            }
        }
        .modifier(Breathe(on: !paused && !reduce, amount: 1.02, period: 2.1))   // slow, like a sleeping breath
        .frame(maxWidth: .infinity)
    }
}

private struct Stat: View {
    let title: String
    let value: String
    let strong: Bool
    var tint: Color? = nil
    @Environment(\.lamp) private var lamp
    var body: some View {
        VStack(spacing: 2) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText)
            // under the lamp the figures are the lamp's cream, as in the dial above
            Ticking(text: value, tint: tint).font(Typeface.numerals(strong ? 26 : 20, relativeTo: .title2, weight: .bold))
                .foregroundStyle(strong ? (lamp ? Palette.lampInk : Color.primary) : Palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// The dial: sixty beads round a circle, one per minute; those already passed this hour are full and coloured, the
/// current one glows; whole hours show as gold beads near the top.
struct Dial: View {
    let seconds: Double
    let color: Color

    private func paint(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let r: CGFloat = min(size.width, size.height) / 2 - 8
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let minutes: Int = Int(seconds / 60)
        let inHour: Int = minutes % 60, hours: Int = minutes / 60
        let k: CGFloat = min(1, r / 140)   // beads scale with the ring
        let lit = Gradient(colors: [color.mix(with: .white, by: 0.45), color])
        for i in 0..<60 {
            let a: CGFloat = CGFloat(i) / 60 * 2 * .pi - .pi / 2
            let px: CGFloat = c.x + cos(a) * r, py: CGFloat = c.y + sin(a) * r
            let d: CGFloat = ((i % 5 == 0 ? 11 : 8) + (i <= inHour && seconds > 0 ? 3 : 0)) * k
            let rect = CGRect(x: px - d / 2, y: py - d / 2, width: d, height: d)
            if i <= inHour && seconds > 0 {
                let hi = CGPoint(x: rect.minX + d * 0.35, y: rect.minY + d * 0.3)
                ctx.fill(Path(ellipseIn: rect), with: .radialGradient(lit, center: hi, startRadius: 0, endRadius: d))
                if i == inHour { ctx.stroke(Path(ellipseIn: rect.insetBy(dx: -3 * k, dy: -3 * k)), with: .color(color.opacity(0.45)), lineWidth: 2) }
            } else {
                ctx.fill(Path(ellipseIn: rect.insetBy(dx: 1.5 * k, dy: 1.5 * k)), with: .color(color.opacity(0.16)))
            }
        }
        let shown: Int = min(hours, 6)
        let gold = Gradient(colors: [Palette.beadLight, Palette.bead])
        for h in 0..<shown {
            let x: CGFloat = c.x - CGFloat(shown - 1) * 9 * k + CGFloat(h) * 18 * k
            let rect = CGRect(x: x - 7 * k, y: c.y - r * 0.72 - 7 * k, width: 14 * k, height: 14 * k)
            ctx.fill(Path(ellipseIn: rect), with: .radialGradient(gold, center: CGPoint(x: rect.minX + 5 * k, y: rect.minY + 4 * k), startRadius: 0, endRadius: 12 * k))
        }
    }
    var body: some View {
        Canvas { ctx, size in paint(&ctx, size) }
        .accessibilityHidden(true)
    }
}

/// A slow breath: the pad grows a little and back, forever, while on. Only the scale is animated — the clock inside
/// changes every second in its own, unanimated update (a phase animator animated those too, and the numbers smeared).
struct Breathe: ViewModifier {
    let on: Bool
    let amount: CGFloat
    let period: Double
    @State private var up = false
    func body(content: Self.Content) -> some View {
        content
            .scaleEffect(on && up ? amount : 1)
            .onAppear { if on { withAnimation(.easeInOut(duration: period).repeatForever(autoreverses: true)) { up = true } } }
            .onChange(of: on) { _, v in
                if v { withAnimation(.easeInOut(duration: period).repeatForever(autoreverses: true)) { up = true } }
                else { withAnimation(.easeOut(duration: 0.3)) { up = false } }
            }
    }
}
