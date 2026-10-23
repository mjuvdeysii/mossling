import SwiftUI

/// Playing along: one step at a time, full screen, for the minutes the parent is on the floor with the child.
///
/// Why: on the page the steps are a list to read beforehand; while playing, hands are busy and eyes go back and forth
/// between the child and the phone. So each step fills the screen as a big picture and one sentence, the next step is
/// one tap anywhere on the right of the picture (or a swipe; the left goes back), the steps are beads along the top —
/// gold once passed — and the screen stays on. The last page is what to watch for and when to stop, then one tap,
/// 做完了, records the time; the companions cheer and the beads fly. Leaving part-way keeps the step for next time.
struct PlayAlong: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.dismiss) private var dismiss
    let play: Play
    let month: Int
    @State private var step: Int
    @State private var done = 0
    @State private var hop = 0

    init(play: Play, month: Int, from: Int = 0) {
        self.play = play; self.month = month
        _step = State(initialValue: max(0, min(from, play.steps.count - 1)))
    }

    private var hasNotes: Bool { !play.observe.isEmpty || !play.pause.isEmpty }
    private var pages: Int { play.steps.count + (hasNotes ? 1 : 0) }
    private var last: Bool { step >= pages - 1 }

    var body: some View {
        let key = Palette.areaKey(of: play)
        let tint = Palette.area(key)
        let art = ArtIndex.shared.steps(play.code)
        VStack(spacing: 14) {
            // the steps as beads; tap one to go to it
            HStack(spacing: 8) {
                Button { dismiss() } label: { Image(systemName: "xmark").font(.headline).frame(width: 40, height: 40) }
                    .buttonStyle(.glass).buttonBorderShape(.circle).accessibilityLabel("收起")
                Spacer(minLength: 4)
                HStack(spacing: 6) {
                    ForEach(0..<pages, id: \.self) { i in
                        let passed = i < step, here = i == step
                        Button { withAnimation(.snappy) { step = i } } label: {
                            Circle()
                                .fill(passed ? AnyShapeStyle(RadialGradient(colors: [Palette.beadLight, Palette.bead], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 10))
                                      : here ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.22)))
                                .frame(width: here ? 18 : 12, height: here ? 18 : 12)
                                .overlay(Circle().strokeBorder(.white.opacity(here ? 0.9 : 0), lineWidth: 2))
                                .frame(width: 22, height: 40)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(i < play.steps.count ? "第 \(i + 1) 步" : "做的时候")
                    }
                }
                Spacer(minLength: 4)
                Text("\(min(step + 1, play.steps.count))/\(play.steps.count)").font(Typeface.numerals(15, weight: .bold)).monospacedDigit()
                    .foregroundStyle(Palette.areaInk(key)).frame(width: 40)
            }
            .padding(.horizontal, 16)

            TabView(selection: $step) {
                ForEach(0..<pages, id: \.self) { i in
                    Group {
                        if i < play.steps.count {
                            VStack(alignment: .leading, spacing: 16) {
                                if i < art.count {
                                    ArtView(name: art[i], label: "第 \(i + 1) 步的图示", radius: 28)
                                        .overlay {
                                            // the left third goes back, the rest goes on
                                            GeometryReader { g in
                                                Color.clear.contentShape(Rectangle())
                                                    .onTapGesture { p in go(p.x < g.size.width / 3 ? -1 : 1) }
                                            }
                                        }
                                }
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Text("\(i + 1)").font(Typeface.numerals(17, relativeTo: .headline, weight: .bold)).foregroundStyle(.white)
                                        .frame(width: 34, height: 34).background(Circle().fill(Palette.accentFill))
                                        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 7 }
                                    Text(play.steps[i]).font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 14) {
                                Text("做的时候").font(.title2.weight(.bold))
                                Box {
                                    if !play.observe.isEmpty { BoxRow(symbol: "eye.fill", color: Crayon.sky, title: "看什么", text: play.observe, last: play.pause.isEmpty) }
                                    if !play.pause.isEmpty { BoxRow(symbol: "hand.raised.fill", color: Crayon.lilac, title: "停下来", text: play.pause, last: true) }
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(alignment: .bottom, spacing: 10) {
                Duo(primary: app.companion, size: 52, look: CGPoint(x: 0.7, y: -0.3), cheer: done &+ hop)
                Button {
                    if last { finish() } else { go(1) }
                } label: {
                    Label(last ? "做完了" : "下一步", systemImage: last ? "checkmark" : "arrow.right")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glassProminent).tint(Palette.accentFill).controlSize(.large)
                .overlay { BeadBurst(trigger: done) }
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background {
            ZStack {
                Palette.background
                RadialGradient(colors: [tint.opacity(0.22), tint.opacity(0)], center: .top, startRadius: 0, endRadius: 560)
            }
            .ignoresSafeArea()
        }
        .sensoryFeedback(.selection, trigger: step)
        .sensoryFeedback(.success, trigger: done)
        .onChange(of: step) { _, s in app.play(play, month: month, at: min(s, play.steps.count - 1)) }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true; app.play(play, month: month, at: min(step, play.steps.count - 1)) }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private func go(_ d: Int) {
        let n = max(0, min(pages - 1, step + d))
        guard n != step else { return }
        withAnimation(.snappy) { step = n }
        if d > 0 && n == pages - 1 { hop += 1 }   // the last page: the companions hop, nearly there
    }

    private func finish() {
        app.didPlay(play, month: month, j)
        app.finishPlaying()
        done += 1
        Task { try? await Task.sleep(for: .milliseconds(1300)); dismiss() }
    }
}
