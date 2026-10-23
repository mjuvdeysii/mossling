import SwiftUI

/// One play, to read through: the name and area, how many times it has been done, before starting (prepare, safety),
/// each step as its picture with one sentence, what to watch for and when to stop. One button at the bottom records a
/// time it was done; each tap counts.
struct PlayView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    let play: Play
    let month: Int
    @State private var scrolled = false
    @State private var cheer = 0

    var body: some View {
        let rec = app.record(play, j)
        let art = ArtIndex.shared.steps(play.code)
        let key = Palette.areaKey(of: play)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        IconTile(symbol: Palette.areaSymbol(key), color: Palette.area(key), size: 34)
                        Text(play.domains.joined(separator: "、")).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.areaInk(key))
                        Spacer()
                        Text(play.age).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text(play.name).font(.largeTitle.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                    DoneCount(record: rec, cheer: cheer)
                }
                .padding(.horizontal, 4)
                .onScrollVisibilityChange(threshold: 0.2) { v in withAnimation(.easeOut(duration: 0.2)) { scrolled = !v } }

                if !play.prepare.isEmpty || !play.safety.isEmpty {
                    Box {
                        if !play.prepare.isEmpty { BoxRow(symbol: "tray.full.fill", color: Crayon.caramel, title: "准备", text: play.prepare, last: play.safety.isEmpty) }
                        if !play.safety.isEmpty { BoxRow(symbol: "exclamationmark.triangle.fill", color: Crayon.tangerine, title: "安全", text: play.safety, last: true) }
                    }
                }

                ForEach(Array(play.steps.enumerated()), id: \.offset) { i, s in
                    VStack(alignment: .leading, spacing: 0) {
                        if i < art.count { ArtView(name: art[i], label: "第 \(i + 1) 步的图示", radius: 0) }
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(i + 1)").font(Typeface.numerals(15, relativeTo: .headline, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Crayon.buttonFill(Palette.area(key))))
                                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
                            Text(s).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                    }
                    .printCard(radius: 26)
                    .accessibilityElement(children: .combine)
                }

                if !play.observe.isEmpty || !play.pause.isEmpty {
                    Box(title: "做的时候") {
                        if !play.observe.isEmpty { BoxRow(symbol: "eye.fill", color: Crayon.sky, title: "看什么", text: play.observe, last: play.pause.isEmpty) }
                        if !play.pause.isEmpty { BoxRow(symbol: "hand.raised.fill", color: Crayon.lilac, title: "停下来", text: play.pause, last: true) }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .pageBackground()
        .safeAreaBar(edge: .bottom) {
            // the companions stand by the button; when it is pressed they cheer and golden beads fly up
            HStack(alignment: .bottom, spacing: 8) {
                Duo(primary: app.companion, size: 40, look: CGPoint(x: 0.6, y: -0.2), cheer: cheer)
                Button { withAnimation(.snappy) { app.didPlay(play, month: month, j); cheer += 1 } } label: {
                    Label(rec.count == 0 ? "做过了" : "又做了一次", systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent).tint(Palette.accentFill).controlSize(.large)
                .overlay { BeadBurst(trigger: cheer) }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .sensoryFeedback(.success, trigger: cheer)
        }
        .navigationTitle(play.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Text(play.name).font(.headline).lineLimit(1).opacity(scrolled ? 1 : 0) }
            ToolbarItem(placement: .topBarTrailing) {
                Menu { PlayActions(play: play, month: month) } label: { Image(systemName: "ellipsis") }.accessibilityLabel("更多")
            }
        }
    }
}

/// How many times, as beads on a string — one gold bead per time, up to ten — and when last.
struct DoneCount: View {
    let record: PlayRecord
    var cheer = 0
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: -3) {
                ForEach(0..<max(1, min(record.count, 10)), id: \.self) { _ in
                    Circle()
                        .fill(record.count == 0 ? AnyShapeStyle(Palette.fill) : AnyShapeStyle(RadialGradient(colors: [Palette.beadLight, Palette.bead, Color(hex: 0x9C6F08)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 11)))
                        .frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(record.count == 0 ? 0 : 0.18), radius: 1, y: 1)
                }
            }
            .phaseAnimator([1.0, 1.25, 1.0], trigger: cheer) { v, s in v.scaleEffect(s) }
            Text(record.count == 0 ? "还没做过" : "做过 \(record.count) 次" + (record.last.map { " · 上次 \(Day($0).md)" } ?? ""))
                .font(.subheadline.weight(.semibold)).foregroundStyle(record.count == 0 ? Color.secondary : Color.primary)
                .monospacedDigit()
                .contentTransition(.numericText())
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
