import SwiftUI

/// One play, to read and to play along with, on one page (build 162: the separate play-along screen repeated this
/// page, so it is gone). Everything that is not the step at hand is folded: before starting (prepare, safety) is one
/// line, open the first time; the steps are a column of small rows — picture, number, sentence — and the one being
/// done opens in place as a big picture with its sentence and 下一步, which folds it (marked done) and opens the next;
/// what to watch for and when to stop is one line at the end. The page remembers the open step, and keeps the screen
/// on while it is open. Nothing is pinned over the page: finishing the last step records a time (the companions cheer
/// in a card that appears in its place), and a small 记一次 by the count records a time played without the steps.
struct PlayView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    let play: Play
    let month: Int
    @State private var scrolled = false
    @State private var cheer = 0
    @State private var open = 0
    @State private var before = false
    /// What to watch for and when to stop is safety: open from the start, not folded away.
    @State private var during = true
    /// The count when the page was opened: a count above it means this visit already recorded a time (by 记一次,
    /// the menu, or the last step) — derived from the records, not kept beside them.
    @State private var base: Int?

    var body: some View {
        let rec = app.record(play, j)
        let art = ArtIndex.shared.steps(play.code)
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PlayHeader(play: play, record: rec, cheer: cheer) { record() }
                .onScrollVisibilityChange(threshold: 0.2) { v in withAnimation(.easeOut(duration: 0.2)) { scrolled = !v } }

                if !play.prepare.isEmpty || !play.safety.isEmpty {
                    Fold(title: L10n.t("开始之前", "Before You Start"), summary: [play.prepare.isEmpty ? nil : L10n.t("准备", "Prepare"), play.safety.isEmpty ? nil : L10n.t("安全", "Safety")].compactMap { $0 }.joined(separator: " · "),
                         symbol: "tray.full.fill", color: Crayon.caramel, open: $before) {
                        if !play.prepare.isEmpty { BoxRow(symbol: "tray.full.fill", color: Crayon.caramel, title: L10n.t("准备", "Prepare"), text: play.prepare, last: play.safety.isEmpty) }
                        if !play.safety.isEmpty { BoxRow(symbol: "exclamationmark.triangle.fill", color: Crayon.tangerine, title: L10n.t("安全", "Safety"), text: play.safety, last: true) }
                    }
                }

                if play.steps.count > 1 {
                    StepBeadBar(total: play.steps.count, current: open) { go($0, proxy) }
                }

                ForEach(Array(play.steps.enumerated()), id: \.offset) { i, s in
                    StepCard(n: i + 1, text: s, art: i < art.count ? art[i] : nil, open: i == open, done: i < open, last: i == play.steps.count - 1, companion: app.companion) {
                        go(i, proxy)
                    } next: {
                        go(i + 1, proxy)
                    }
                    .id(i)
                }

                // finishing the last step records the time: the companions come out to cheer, here, in the page
                if open >= play.steps.count {
                    FinishedCard(companion: app.companion, count: rec.count, cheer: cheer)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                        .id("finished")
                }

                if !play.observe.isEmpty || !play.pause.isEmpty {
                    Fold(title: L10n.t("做的时候", "While Playing"), summary: [play.observe.isEmpty ? nil : L10n.t("看什么", "Observe"), play.pause.isEmpty ? nil : L10n.t("停下来", "Pause")].compactMap { $0 }.joined(separator: " · "),
                         symbol: "eye.fill", color: Crayon.sky, open: $during) {
                        if !play.observe.isEmpty { BoxRow(symbol: "eye.fill", color: Crayon.sky, title: L10n.t("看什么", "Observe"), text: play.observe, last: play.pause.isEmpty) }
                        if !play.pause.isEmpty { BoxRow(symbol: "hand.raised.fill", color: Crayon.lilac, title: L10n.t("停下来", "When to Pause"), text: play.pause, last: true) }
                    }
                    .id("during")
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        }
        .calmWhileScrolling()
        .pageBackground()
        .sensoryFeedback(.success, trigger: cheer)
        .sensoryFeedback(.selection, trigger: open)
        .onAppear {
            if let p = app.playing, p.play.code == play.code { open = p.step }
            before = rec.count == 0
            if base == nil { base = j.plays(play.code).count }
            keepAwake(open < play.steps.count)
        }
        .onDisappear { keepAwake(false) }
        // the screen stays on while a step is open (the phone lies on the floor), and may sleep once they are done
        .onChange(of: open) { _, o in keepAwake(o < play.steps.count) }
        // a time taken back (撤销): the finished card goes and the last step opens again, to be finished anew
        .onChange(of: j.plays(play.code).count) { old, new in countChanged(old, new) }
        .navigationTitle(play.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Text(play.name).font(.headline).lineLimit(1).opacity(scrolled ? 1 : 0) }
            ToolbarItem(placement: .topBarTrailing) {
                Menu { PlayActions(play: play, month: month, inPage: true) } label: { Image(systemName: "ellipsis") }.accessibilityLabel(L10n.t("更多", "More"))
            }
        }
    }

    private func record() {
        // the reply only after the time played is really saved
        guard app.mayKeep() else { return }
        withAnimation(.snappy) { if app.didPlay(play, month: month, j) { app.finishPlaying(); cheer += 1 } }
    }
    /// Whether this visit has recorded a time (the count is above what it was when the page opened).
    /// Counted in entries (a mark from before plays were dated would hide the first entry).
    private var recordedHere: Bool { j.plays(play.code).count > (base ?? Int.max) }
    private func keepAwake(_ on: Bool) { UIApplication.shared.isIdleTimerDisabled = on }
    private func countChanged(_ old: Int, _ new: Int) {
        guard new < old else { return }
        base = min(base ?? Int.max, j.plays(play.code).count)
        if open >= play.steps.count { withAnimation(.snappy) { open = max(0, play.steps.count - 1) } }
    }

    private func go(_ i: Int, _ proxy: ScrollViewProxy) {
        if i >= play.steps.count {
            // the last step done: that is a time played — recorded, cheered, and the steps fold away
            // one time played is one entry: if 记一次 already said it on this page, the last step does not again;
            // the steps fold away only once the time is really saved (a failed save leaves the last step open)
            if recordedHere { cheer += 1 } else if app.mayKeep(), app.didPlay(play, month: month, j) { app.finishPlaying(); cheer += 1 } else { return }
            withAnimation(.snappy) { open = play.steps.count }
            withAnimation(.smooth.delay(0.15)) { proxy.scrollTo("finished", anchor: .center) }
            return
        }
        withAnimation(.snappy) { open = i }
        app.play(play, month: month, at: i)
        withAnimation(.smooth.delay(0.15)) { proxy.scrollTo(i, anchor: .top) }
    }
}

/// A folded section: one line (sticker, title, what is inside) that opens in place.
struct Fold<Content: View>: View {
    let title: String
    let summary: String
    let symbol: String
    let color: Color
    @Binding var open: Bool
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) {
            Button { withAnimation(.snappy) { open.toggle() } } label: {
                HStack(spacing: 12) {
                    IconTile(symbol: symbol, color: color, size: 30)
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(summary).font(.subheadline).foregroundStyle(Palette.secondaryText).lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.footnote.weight(.bold)).foregroundStyle(Palette.secondaryText)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.toy)
            .accessibilityValue(open ? "已展开" : "已折叠")
            if open {
                Divider().padding(.horizontal, 16)
                VStack(spacing: 0) { content }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .printCard(radius: Radius.card)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

/// A quiet Montessori bead progress bar for a play's steps: gold beads for finished steps, an active pill for the step
/// in hand, pale stone for the steps ahead. Tapping any bead opens that step.
private struct StepBeadBar: View {
    let total: Int
    let current: Int
    let pick: (Int) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        let done = min(current, total)
        let label = current >= total ? L10n.t("全部 \(total) 步已完成", "All \(total) steps done") : L10n.t("第 \(current + 1) 步，共 \(total) 步", "Step \(current + 1) of \(total)")
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { i in
                    Button { pick(i) } label: {
                        Group {
                            if i < current {
                                GoldBead(size: 11)
                            } else if i == current {
                                Capsule().fill(Palette.accent).frame(width: 24, height: 11)
                            } else {
                                Circle().fill(Palette.stone.opacity(0.75)).frame(width: 9, height: 9)
                            }
                        }
                        .frame(minWidth: 28, minHeight: 32)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("第 \(i + 1) 步", "Step \(i + 1)"))
                }
            }
            Spacer(minLength: 4)
            Text(current >= total ? L10n.t("全部完成", "All Done") : L10n.t("第 \(done + 1) / \(total) 步", "Step \(done + 1) / \(total)"))
                .font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText).monospacedDigit()
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .printCard(radius: Radius.inner)
        .animation(reduce ? nil : .snappy, value: current)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

/// One step. Open: the big picture, the number and the sentence, and 下一步. Folded: a small row — the picture as a
/// thumbnail, the number (a gold bead once done) and the sentence — that opens it when tapped.
private struct StepCard: View {
    let n: Int
    let text: String
    let art: String?
    let open: Bool
    let done: Bool
    let last: Bool
    /// Moss and Otto stay out of the picture (it shows the people and the play, nothing else) and keep the parent
    /// company beside it: they sit by 下一步, looking up at the picture, and give a little hop each time a new step
    /// opens — following along, never in the way.
    let companion: Kind
    let tap: () -> Void
    let next: () -> Void
    @State private var arrived = 0
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        Group {
            if open {
                VStack(alignment: .leading, spacing: 0) {
                    if let art { ArtView(name: art, label: L10n.t("第 \(n) 步的图示", "Illustration for step \(n)"), radius: 0) }
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            badge
                            Text(text).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(alignment: .bottom) {
                            // the two are already in the step's picture (one pair to a card); only a step without a
                            // picture has them here, hopping as it opens
                            if art == nil { Duo(primary: companion, size: 40, look: CGPoint(x: 0.2, y: -0.9), poke: true, cheer: arrived) }
                            Spacer(minLength: 8)
                            Button(action: next) {
                                Label(last ? L10n.t("做完了", "All Done") : L10n.t("下一步", "Next Step"), systemImage: last ? "checkmark" : "arrow.down")
                                    .font(.subheadline.weight(.semibold)).padding(.horizontal, 6)
                            }
                            .buttonStyle(.vinyl)
                        }
                        .task { if n > 1 { try? await Task.sleep(for: .milliseconds(380)); arrived += 1 } }
                    }
                    .padding(16)
                }
                .printCard(radius: Radius.card)
                .transition(reduce ? .opacity : .opacity.combined(with: .scale(scale: 0.985)))
            } else {
                Button(action: tap) {
                    HStack(spacing: 12) {
                        if let art {
                            ArtView(name: art, radius: 10).frame(width: 76).opacity(done ? 0.6 : 1)
                        }
                        badge
                        Text(text).font(.subheadline.weight(.medium)).foregroundStyle(done ? Palette.secondaryText : Color.primary)
                            .lineLimit(2).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.toy)
                .printCard(radius: Radius.inner)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.t("第 \(n) 步，\(text)", "Step \(n), \(text)"))
        .accessibilityAddTraits(open ? [] : .isButton)
    }

    @ViewBuilder private var badge: some View {
        ZStack {
            if done {
                Circle().fill(RadialGradient(colors: [Palette.beadLight, Palette.bead], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 16))
                Image(systemName: "checkmark").font(.caption.weight(.heavy)).foregroundStyle(Color(hex: 0x5A3D00))
            } else {
                Circle().fill(Palette.accentFill)
                Text("\(n)").font(Typeface.numerals(15, relativeTo: .headline, weight: .bold)).foregroundStyle(.white)
            }
        }
        .frame(width: 30, height: 30)
        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
    }
}

/// How many times, as beads on a string — one gold bead per time, up to five — the count, and when last (its own
/// line, so nothing is ever squeezed).
struct DoneCount: View {
    let record: PlayRecord
    var cheer = 0
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: -3) {
                ForEach(0..<max(1, min(record.count, 5)), id: \.self) { _ in
                    Circle()
                        .fill(record.count == 0 ? AnyShapeStyle(Palette.fill) : AnyShapeStyle(RadialGradient(colors: [Palette.beadLight, Palette.bead, Color(hex: 0x9C6F08)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 11)))
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(record.count == 0 ? 0 : 0.18), radius: 1, y: 1)
                }
            }
            .phaseAnimator([1.0, 1.25, 1.0], trigger: cheer) { v, s in v.scaleEffect(s) }
            VStack(alignment: .leading, spacing: 1) {
                if record.count == 0 {
                    Text(L10n.t("还没玩过", "Not played yet")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                } else {
                    HStack(spacing: 0) {
                        Text(L10n.t("玩过 ", "Played "))
                        Ticking(text: "\(record.count)", tint: Palette.bead)
                        Text(L10n.t(" 次", record.count == 1 ? " time" : " times"))
                    }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary).fixedSize()
                    if let last = record.last {
                        Text(L10n.t("上次 \(Day(last).md)", "Last \(Day(last).m)/\(Day(last).d)")).font(.caption).foregroundStyle(Palette.secondaryText)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Golden and rainbow beads that fly up out of a button and fall away, once each time `trigger` changes.
struct BeadBurst: View {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduce
    private static let beads: [(dx: Double, up: Double, r: Double, c: Color)] = [
        (-120, 150, 7, Palette.bead), (-80, 190, 6, Crayon.teal), (-40, 210, 8, Palette.bead), (0, 230, 6, Crayon.pink),
        (40, 205, 7, Palette.bead), (80, 185, 6, Crayon.sunflower), (120, 150, 8, Crayon.cherry), (-100, 120, 5, Crayon.sky), (100, 125, 5, Palette.bead)]
    var body: some View {
        if reduce { EmptyView() } else {
            Color.clear
                .overlay {
                    KeyframeAnimator(initialValue: 0.0, trigger: trigger) { t in
                        ZStack {
                            ForEach(Array(Self.beads.enumerated()), id: \.offset) { _, b in
                                // a throw upward with gravity: y = up·(2t − t²)·…, fading at the end
                                let y = -b.up * (2 * t - t * t * 1.4)
                                Circle().fill(b.c).frame(width: b.r * 2, height: b.r * 2)
                                    .offset(x: b.dx * t, y: y)
                                    .opacity(t <= 0 || t >= 1 ? 0 : 1 - max(0, t - 0.7) / 0.3)
                            }
                        }
                    } keyframes: { _ in
                        LinearKeyframe(0.0, duration: 0.0)
                        LinearKeyframe(1.0, duration: 1.1)
                        LinearKeyframe(0.0, duration: 0.0)
                    }
                }
                .allowsHitTesting(false)
        }
    }
}

/// The play's head: its area and age, its name, how many times, and 记一次.
private struct PlayHeader: View {
    let play: Play
    let record: PlayRecord
    let cheer: Int
    let add: () -> Void
    var body: some View {
        let key: String = Palette.areaKey(of: play)
        VStack(alignment: .leading, spacing: 10) {
            // the area and, under it, the age it suits — its own line, wrapping, never cut at the edge
            HStack(alignment: .center, spacing: 10) {
                IconTile(symbol: Palette.areaSymbol(key), color: Palette.area(key), size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(play.domains.joined(separator: L10n.isEnglish ? " · " : "、")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.areaInk(key))
                    Text(play.age).font(.caption).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            Text(play.name).font(.largeTitle.weight(.bold)).fixedSize(horizontal: false, vertical: true)
            // how many times, and — for a time played without following the steps here — a small 记一次
            HStack {
                DoneCount(record: record, cheer: cheer)
                Spacer(minLength: 8)
                Button(action: add) { Label(L10n.t("记一次", "Log Play"), systemImage: "plus") }
                    .buttonStyle(.vinyl)
                    .overlay { BeadBurst(trigger: cheer) }
                    .accessibilityLabel(L10n.t("玩过了，记一次", "Log one play session"))
            }
        }
        .padding(.horizontal, 4).padding(.bottom, 8)
    }
}

/// The steps finished: the companions come out to cheer, here, in the page, with the count.
private struct FinishedCard: View {
    let companion: Kind
    let count: Int
    let cheer: Int
    var body: some View {
        let line: String = L10n.t(
            "记下了第 \(count) 次" + (count >= 3 ? "，越来越熟练" : ""),
            "Logged session #\(count)" + (count >= 3 ? " — getting more natural" : "")
        )
        HStack(spacing: 14) {
            Duo(primary: companion, size: 56, look: CGPoint(x: 0.5, y: -0.3), cheer: cheer)
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t("做完了", "All Done")).font(.headline)
                Text(line).font(.subheadline).foregroundStyle(Palette.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(14).printCard(radius: Radius.card)
        .overlay { BeadBurst(trigger: cheer) }
    }
}
