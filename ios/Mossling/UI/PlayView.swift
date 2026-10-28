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
    @State private var during = false

    var body: some View {
        let rec = app.record(play, j)
        let art = ArtIndex.shared.steps(play.code)
        let key = Palette.areaKey(of: play)
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    // the area and, under it, the age it suits — its own line, wrapping, never cut at the edge
                    HStack(alignment: .center, spacing: 10) {
                        IconTile(symbol: Palette.areaSymbol(key), color: Palette.area(key), size: 34)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(play.domains.joined(separator: "、")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.areaInk(key))
                            Text(play.age).font(.caption).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    Text(play.name).font(.largeTitle.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                    // how many times, and — for a time played without following the steps here — a small 记一次
                    HStack {
                        DoneCount(record: rec, cheer: cheer)
                        Spacer(minLength: 8)
                        Button { record() } label: { Label("记一次", systemImage: "plus") }
                            .buttonStyle(.vinyl)
                            .overlay { BeadBurst(trigger: cheer) }
                            .accessibilityLabel("做过了，记一次")
                    }
                }
                .padding(.horizontal, 4).padding(.bottom, 8)
                .onScrollVisibilityChange(threshold: 0.2) { v in withAnimation(.easeOut(duration: 0.2)) { scrolled = !v } }

                if !play.prepare.isEmpty || !play.safety.isEmpty {
                    Fold(title: "开始之前", summary: [play.prepare.isEmpty ? nil : "准备", play.safety.isEmpty ? nil : "安全"].compactMap { $0 }.joined(separator: " · "),
                         symbol: "tray.full.fill", color: Crayon.caramel, open: $before) {
                        if !play.prepare.isEmpty { BoxRow(symbol: "tray.full.fill", color: Crayon.caramel, title: "准备", text: play.prepare, last: play.safety.isEmpty) }
                        if !play.safety.isEmpty { BoxRow(symbol: "exclamationmark.triangle.fill", color: Crayon.tangerine, title: "安全", text: play.safety, last: true) }
                    }
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
                    HStack(spacing: 14) {
                        Duo(primary: app.companion, size: 56, look: CGPoint(x: 0.5, y: -0.3), cheer: cheer)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("做完了").font(.headline)
                            Text("记下了第 \(rec.count) 次" + (rec.count >= 3 ? "，越来越熟练" : "")).font(.subheadline).foregroundStyle(Palette.secondaryText)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(14).printCard(radius: 22)
                    .overlay { BeadBurst(trigger: cheer) }
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                    .id("finished")
                }

                if !play.observe.isEmpty || !play.pause.isEmpty {
                    Fold(title: "做的时候", summary: [play.observe.isEmpty ? nil : "看什么", play.pause.isEmpty ? nil : "停下来"].compactMap { $0 }.joined(separator: " · "),
                         symbol: "eye.fill", color: Crayon.sky, open: $during) {
                        if !play.observe.isEmpty { BoxRow(symbol: "eye.fill", color: Crayon.sky, title: "看什么", text: play.observe, last: play.pause.isEmpty) }
                        if !play.pause.isEmpty { BoxRow(symbol: "hand.raised.fill", color: Crayon.lilac, title: "停下来", text: play.pause, last: true) }
                    }
                    .id("during")
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        }
        .pageBackground()
        .sensoryFeedback(.success, trigger: cheer)
        .sensoryFeedback(.selection, trigger: open)
        .onAppear {
            if let p = app.playing, p.play.code == play.code { open = p.step }
            before = rec.count == 0
            UIApplication.shared.isIdleTimerDisabled = true   // playing along: the phone lies on the floor
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .navigationTitle(play.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Text(play.name).font(.headline).lineLimit(1).opacity(scrolled ? 1 : 0) }
            ToolbarItem(placement: .topBarTrailing) {
                Menu { PlayActions(play: play, month: month) } label: { Image(systemName: "ellipsis") }.accessibilityLabel("更多")
            }
        }
    }

    private func record() {
        // the reply only after the time played is really saved
        withAnimation(.snappy) { if app.didPlay(play, month: month, j) { app.finishPlaying(); cheer += 1 } }
    }

    private func go(_ i: Int, _ proxy: ScrollViewProxy) {
        if i >= play.steps.count {
            // the last step done: that is a time played — recorded, cheered, and the steps fold away
            withAnimation(.snappy) { open = play.steps.count }
            record()
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
        .printCard(radius: 22)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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

    var body: some View {
        Group {
            if open {
                VStack(alignment: .leading, spacing: 0) {
                    if let art { ArtView(name: art, label: "第 \(n) 步的图示", radius: 0) }
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            badge
                            Text(text).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(alignment: .bottom) {
                            // in the 2D world (build 196) the two are inside the pictures, as they were then
                            if true { Duo(primary: companion, size: 40, look: CGPoint(x: 0.2, y: -0.9), poke: true, cheer: arrived) }
                            Spacer(minLength: 8)
                            Button(action: next) {
                                Label(last ? "做完了" : "下一步", systemImage: last ? "checkmark" : "arrow.down")
                                    .font(.subheadline.weight(.semibold)).padding(.horizontal, 6)
                            }
                            .buttonStyle(.vinyl)
                        }
                        .task { if n > 1 { try? await Task.sleep(for: .milliseconds(380)); arrived += 1 } }
                    }
                    .padding(16)
                }
                .printCard(radius: 26)
                .transition(.opacity)
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
                .printCard(radius: 18)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("第 \(n) 步，\(text)" + (done ? "，已做" : ""))
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
                    Text("还没做过").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                } else {
                    HStack(spacing: 0) {
                        Text("做过 ")
                        Ticking(text: "\(record.count)", tint: Palette.bead)
                        Text(" 次")
                    }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Color.primary).fixedSize()
                    if let last = record.last {
                        Text("上次 \(Day(last).md)").font(.caption).foregroundStyle(Palette.secondaryText)
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
