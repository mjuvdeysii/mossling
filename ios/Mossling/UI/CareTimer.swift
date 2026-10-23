import SwiftUI

/// A feed or a sleep in progress, on its own screen (build 151, redesigned after "一次点击就能做的事情变成两次").
///
/// One gesture runs the clock: the sides of a feed are the controls. Tap the side being fed to pause, tap it again to
/// go on; tap the other side to change sides (it runs at once, paused or not). Each side keeps its own time, drawn as
/// a ring of beads round it; under the sides, the whole feed and its pauses. Ending sits alone at the bottom, away
/// from everything a tired hand taps often. A sleep is one big moon to tap. The companions watch the side being fed —
/// they turn to it, and hop when the side changes — and sleep with the baby.
struct TimerScreen: View {
    @Environment(JournalStore.self) private var j
    @Environment(AppModel.self) private var app
    @Environment(\.lamp) private var lamp
    @Environment(\.dismiss) private var dismiss
    let type: String
    @State private var picking = false
    @State private var hop = 0

    var body: some View {
        let c = LogType.color(type)
        NavigationStack {
            if let t = j.timers.first(where: { $0.type == type }) {
                let paused = t.pausedAt != nil
                let side = t.side ?? "l"
                TimelineView(.periodic(from: .now, by: 1)) { tl in
                    let now = tl.date.timeIntervalSince1970 * 1000
                    ScrollView {
                        VStack(spacing: 18) {
                            Duo(primary: lamp ? .otto : app.companion, size: 62,
                                mood: type == LogType.sleep && !paused ? .sleep : .open,
                                look: type == LogType.nurse ? CGPoint(x: side == "l" ? -0.9 : 0.9, y: 0.6) : CGPoint(x: 0, y: 0.5),
                                poke: true, cheer: hop, night: lamp)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 4)

                            if type == LogType.nurse {
                                HStack(spacing: 12) {
                                    ForEach(["l", "r"], id: \.self) { k in
                                        let done = j.logs.feedSides(before: t.start)[k] ?? 0
                                        SidePad(side: k, seconds: done + (k == side ? t.elapsed(now) : 0),
                                                state: k != side ? .other : paused ? .paused : .running, color: c) {
                                            withAnimation(.snappy) { j.tapSide(type, k) }
                                            if k != side { hop += 1 }
                                        }
                                    }
                                }
                            } else {
                                SleepPad(seconds: t.total(now), paused: paused, color: c) {
                                    withAnimation(.snappy) { j.togglePause(type) }
                                }
                            }

                            HStack(spacing: 0) {
                                Stat(title: type == LogType.sleep ? "睡了" : "合计", value: clock(t.total(now)), strong: true)
                                Divider().frame(height: 34)
                                Stat(title: "暂停", value: t.paused(now) >= 1 ? clock(t.paused(now)) : "—", strong: false)
                            }
                            .padding(.vertical, 12)
                            .background(lamp ? Palette.lampCard : Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                            Button { picking = true } label: {
                                Label("开始于 " + whenLabel(Date(timeIntervalSince1970: (t.start - t.carried - t.carriedPause) / 1000)), systemImage: "clock")
                                    .font(.subheadline).monospacedDigit()
                            }
                            .buttonStyle(.glass)
                        }
                        .padding(.horizontal, 20).padding(.bottom, 24)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .background {
                    ZStack {
                        if lamp { Palette.lampPage } else { Palette.background }
                        let glow = lamp ? Palette.amber : c
                        RadialGradient(colors: [glow.opacity(lamp ? 0.2 : 0.26), glow.opacity(0)], center: .top, startRadius: 0, endRadius: 520)
                    }
                    .ignoresSafeArea()
                }
                .navigationTitle(LogType.name(type))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("收起", systemImage: "chevron.down") { dismiss() } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("提前 5 分钟", systemImage: "gobackward.5") { j.shift(type, to: Date(timeIntervalSince1970: t.start / 1000 - 300)) }
                            Button("提前 15 分钟", systemImage: "gobackward.15") { j.shift(type, to: Date(timeIntervalSince1970: t.start / 1000 - 900)) }
                            Divider()
                            Button("不记这一次", systemImage: "xmark", role: .destructive) { j.discard(type); dismiss() }
                        } label: { Image(systemName: "ellipsis") }.accessibilityLabel("更多")
                    }
                }
                // ending, alone: a full-width button in its own band, nothing beside it to hit by mistake
                .safeAreaBar(edge: .bottom) {
                    Button { j.stop(type); dismiss() } label: {
                        Label(type == LogType.sleep ? "醒了，记下" : "喂完了，记下", systemImage: "checkmark")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    .buttonStyle(.glassProminent).tint(Crayon.buttonFill(c)).controlSize(.large)
                    .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 6)
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: paused)
                .sensoryFeedback(.selection, trigger: side)
                .sheet(isPresented: $picking) {
                    TimeSheet(title: "开始时间", initial: Date(timeIntervalSince1970: t.start / 1000)) { j.shift(type, to: $0) }.lampPresented()
                }
            } else {
                Color.clear.onAppear { dismiss() }
            }
        }
    }
}

/// One side of a feed, and its control. Being fed: a deep pad, its minutes as lit beads round the time, breathing
/// slowly. Paused: the pad goes pale, the beads stay. The other side: pale, waiting for a tap.
private struct SidePad: View {
    enum Mode { case running, paused, other }
    let side: String
    let seconds: Double
    let state: Mode
    let color: Color
    let tap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.lamp) private var lamp

    var body: some View {
        let on = state == .running
        let ink = on ? Color.white : Crayon.ink(color)
        Button(action: tap) {
            ZStack {
                Dial(seconds: seconds, color: on ? .white : color)
                    .padding(8)
                    .opacity(state == .other ? 0.55 : 1)
                VStack(spacing: 2) {
                    Text(side == "l" ? "L" : "R").font(Typeface.numerals(30, weight: .heavy))
                    Text(seconds >= 1 ? clock(seconds) : "—").font(Typeface.numerals(20, relativeTo: .title3, weight: .bold)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Label(hint, systemImage: on ? "pause.fill" : state == .paused ? "play.fill" : "arrow.left.arrow.right")
                        .font(.caption2.weight(.bold)).labelStyle(.titleAndIcon).lineLimit(1).minimumScaleFactor(0.7)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(on ? Color.white.opacity(0.18) : color.opacity(0.16)))
                        .padding(.top, 4)
                }
                .foregroundStyle(ink)
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(on ? AnyShapeStyle(LinearGradient(colors: [Crayon.buttonFill(color).mix(with: color, by: 0.12), Crayon.buttonFill(color)], startPoint: .top, endPoint: .bottom))
                             : AnyShapeStyle(color.opacity(lamp ? 0.16 : 0.12)))
                    .overlay {
                        if state == .paused {
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .strokeBorder(Crayon.ink(color).opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        }
                    }
            }
            .phaseAnimator(on && !reduce ? [false, true] : [false]) { v, up in
                v.scaleEffect(up ? 1.015 : 1)
            } animation: { _ in .easeInOut(duration: 1.6) }
            .shadow(color: on ? color.opacity(0.4) : .clear, radius: 12, y: 6)
        }
        .buttonStyle(.toy)
        .accessibilityLabel((side == "l" ? "左侧 " : "右侧 ") + minutesOf(seconds))
        .accessibilityHint(hint)
        .accessibilityAddTraits(state == .other ? [] : .isSelected)
    }

    private var hint: String {
        switch state {
        case .running: "点按暂停"
        case .paused: "点按继续"
        case .other: "点按换到这侧"
        }
    }
}

/// A sleep, as one moon to tap: tap to pause (a wake in the night), tap again to go on.
private struct SleepPad: View {
    let seconds: Double
    let paused: Bool
    let color: Color
    let tap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        let ink = paused ? Crayon.ink(color) : Color.white
        Button(action: tap) {
            ZStack {
                Dial(seconds: seconds, color: paused ? color : .white).padding(10)
                VStack(spacing: 6) {
                    IconTile(symbol: LogType.symbol(LogType.sleep), color: color, size: 46, round: true)
                    Text(clock(seconds)).font(Typeface.numerals(38, relativeTo: .largeTitle, weight: .bold)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Label(paused ? "点按继续" : "点按暂停", systemImage: paused ? "play.fill" : "pause.fill")
                        .font(.caption.weight(.bold)).lineLimit(1)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Capsule().fill(paused ? color.opacity(0.16) : Color.white.opacity(0.18)))
                }
                .frame(width: 170)
                .foregroundStyle(ink)
            }
            .frame(width: 250, height: 250)
            .background {
                Circle().fill(paused ? AnyShapeStyle(color.opacity(0.14))
                              : AnyShapeStyle(RadialGradient(colors: [Crayon.buttonFill(color).mix(with: color, by: 0.15), Crayon.buttonFill(color)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 240)))
            }
            .phaseAnimator(!paused && !reduce ? [false, true] : [false]) { v, up in
                v.scaleEffect(up ? 1.02 : 1)
            } animation: { _ in .easeInOut(duration: 2.1) }   // slow, like a sleeping breath
            .shadow(color: paused ? .clear : color.opacity(0.4), radius: 16, y: 8)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.toy)
        .accessibilityLabel("睡眠 " + minutesOf(seconds))
        .accessibilityHint(paused ? "点按继续" : "点按暂停")
    }
}

private struct Stat: View {
    let title: String
    let value: String
    let strong: Bool
    var body: some View {
        VStack(spacing: 2) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(Typeface.numerals(strong ? 26 : 20, relativeTo: .title2, weight: .bold)).monospacedDigit()
                .foregroundStyle(strong ? Color.primary : Color.secondary)
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
