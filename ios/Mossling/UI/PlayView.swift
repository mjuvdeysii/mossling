import SwiftUI

/// One play, as an overview: its first picture, the name and area, before starting (prepare, safety), the steps in
/// short, what to watch for and when to stop. "开始" opens the step mode; the check in the bottom bar records it.
struct PlayView: View {
    @Environment(AppModel.self) private var app
    let play: Play
    let month: Int
    @State private var doing = false
    @State private var scrolled = false

    var body: some View {
        let did = app.ticked(month, TickKind.did, play.code)
        let art = ArtIndex.shared.steps(play.code)
        let key = Palette.areaKey(of: play)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let f = art.first { ArtView(name: f, label: "第一步的图示", radius: 26).padding(.horizontal, 16).padding(.top, 8) }
                VStack(alignment: .leading, spacing: 6) {
                    Label(play.domains.joined(separator: "、"), systemImage: Palette.areaSymbol(key))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.area(key))
                    Text(play.name).font(.largeTitle.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                    Text("\(play.age) · \(play.code)").font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20).padding(.top, 16)
                .onScrollVisibilityChange(threshold: 0.2) { v in withAnimation(.easeOut(duration: 0.2)) { scrolled = !v } }

                VStack(alignment: .leading, spacing: 18) {
                    if !play.prepare.isEmpty || !play.safety.isEmpty {
                        Box {
                            if !play.prepare.isEmpty { BoxRow(symbol: "tray.full.fill", color: Crayon.caramel, title: "准备", text: play.prepare, last: play.safety.isEmpty) }
                            if !play.safety.isEmpty { BoxRow(symbol: "exclamationmark.triangle.fill", color: Crayon.tangerine, title: "安全", text: play.safety, last: true) }
                        }
                    }
                    Box(title: "步骤", detail: "\(play.steps.count) 步") {
                        ForEach(Array(play.steps.enumerated()), id: \.offset) { i, s in
                            Button { doing = true } label: {
                                VStack(spacing: 0) {
                                    HStack(spacing: 14) {
                                        Text("\(i + 1)").font(Typeface.numerals(15, relativeTo: .headline, weight: .bold)).foregroundStyle(.white)
                                            .frame(width: 30, height: 30).background(Palette.area(key).gradient, in: Circle())
                                        Text(s).font(.body).foregroundStyle(.primary).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 12)
                                    if i < play.steps.count - 1 { Divider().padding(.leading, 60) }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if !play.observe.isEmpty || !play.pause.isEmpty {
                        Box(title: "做的时候") {
                            if !play.observe.isEmpty { BoxRow(symbol: "eye.fill", color: Crayon.sky, title: "看什么", text: play.observe, last: play.pause.isEmpty) }
                            if !play.pause.isEmpty { BoxRow(symbol: "hand.raised.fill", color: Crayon.pebble, title: "停下来", text: play.pause, last: true) }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 24)
            }
        }
        .background(Palette.background)
        .safeAreaBar(edge: .bottom) {
            HStack(spacing: 12) {
                Button { doing = true } label: { Label("开始", systemImage: "play.fill").frame(maxWidth: .infinity).padding(.vertical, 6) }
                    .buttonStyle(.glassProminent).controlSize(.large)
                Button { withAnimation(.snappy) { app.toggle(month, TickKind.did, play.code, play.name) } } label: {
                    Image(systemName: did ? "checkmark.circle.fill" : "checkmark.circle").font(.title2)
                        .foregroundStyle(did ? Palette.accent : Color.primary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 30, height: 30).padding(4)
                }
                .buttonStyle(.glass).controlSize(.large)
                .accessibilityLabel(did ? "这个月做过了" : "记为做过")
                .sensoryFeedback(.success, trigger: did)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .navigationTitle(play.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Text(play.name).font(.headline).lineLimit(1).opacity(scrolled ? 1 : 0) }
            ToolbarItem(placement: .topBarTrailing) {
                Menu { PlayActions(play: play, month: month) } label: { Image(systemName: "ellipsis") }.accessibilityLabel("更多")
            }
        }
        .fullScreenCover(isPresented: $doing) {
            StepMode(play: play, month: month, start: app.playing.flatMap { $0.play.code == play.code ? $0.step : nil } ?? 0)
        }
    }
}

/// Doing the play: one step at a time, its picture large, one sentence, back and next at the bottom; the last step
/// records it as done.
struct StepMode: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduce
    let play: Play, month: Int
    var start = 0
    @State private var i = 0
    @State private var forward = true

    var body: some View {
        let art = ArtIndex.shared.steps(play.code)
        let key = Palette.areaKey(of: play)
        let n = play.steps.count
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 6) {
                    ForEach(0..<n, id: \.self) { k in
                        Capsule().fill(k <= i ? Palette.area(key) : Palette.fill).frame(height: 6)
                    }
                }
                .accessibilityElement().accessibilityLabel("第 \(i + 1) 步，共 \(n) 步")
                VStack(alignment: .leading, spacing: 20) {
                    if i < art.count { ArtView(name: art[i], label: "第 \(i + 1) 步的图示", radius: 30) }
                    Text("第 \(i + 1) 步").font(.headline).foregroundStyle(Palette.area(key))
                    Text(play.steps[i]).font(.title.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                }
                .id(i)
                .transition(reduce ? .opacity : .asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                                            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)))
                Spacer(minLength: 0)
                if i == n - 1, !play.safety.isEmpty {
                    Label(play.safety, systemImage: "exclamationmark.triangle.fill").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20).padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Palette.background)
            .navigationTitle(play.name).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("关闭", systemImage: "xmark") { dismiss() } }
            }
            .safeAreaBar(edge: .bottom) {
                HStack(spacing: 12) {
                    Button { go(-1) } label: { Image(systemName: "chevron.left").frame(width: 30, height: 30).padding(4) }
                        .buttonStyle(.glass).controlSize(.large).disabled(i == 0).accessibilityLabel("上一步")
                    if i < n - 1 {
                        Button { go(1) } label: { Text("下一步").frame(maxWidth: .infinity).padding(.vertical, 6) }
                            .buttonStyle(.glassProminent).tint(Palette.area(key)).controlSize(.large)
                    } else {
                        Button {
                            if !app.ticked(month, TickKind.did, play.code) { app.toggle(month, TickKind.did, play.code, play.name) }
                            app.finishPlaying()
                            dismiss()
                        } label: { Label("完成", systemImage: "checkmark").frame(maxWidth: .infinity).padding(.vertical, 6) }
                            .buttonStyle(.glassProminent).tint(Palette.accent).controlSize(.large)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 8)
            }
            .sensoryFeedback(.selection, trigger: i)
            .onAppear { i = min(start, max(0, play.steps.count - 1)); app.play(play, month: month, at: i) }
            .onChange(of: i) { _, k in app.play(play, month: month, at: k) }
        }
    }

    private func go(_ d: Int) {
        forward = d > 0
        withAnimation(.snappy) { i = max(0, min(play.steps.count - 1, i + d)) }
    }
}

/// The play in progress, small, above the tab bar: its picture, its name and step; tap to go on, or put it away.
struct PlayingAccessory: View {
    @Environment(AppModel.self) private var app
    let play: Play, step: Int
    let resume: () -> Void
    var body: some View {
        let art = ArtIndex.shared.steps(play.code)
        HStack(spacing: 12) {
            Button(action: resume) {
                HStack(spacing: 12) {
                    if step < art.count { ArtFill(name: art[step]).frame(width: 34, height: 34).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous)) }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(play.name).font(.footnote.weight(.semibold)).lineLimit(1)
                        Text("第 \(step + 1) 步，共 \(play.steps.count) 步").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("继续：\(play.name)，第 \(step + 1) 步")
            Button { resume() } label: { Image(systemName: "play.fill") }.accessibilityLabel("继续")
            Button { withAnimation(.snappy) { app.finishPlaying() } } label: { Image(systemName: "xmark") }.accessibilityLabel("放下")
        }
        .padding(.horizontal, 14)
        .tint(.primary)
    }
}
