import SwiftUI

/// One play: before you start (what to prepare, safety), each step as a card with its picture, what to watch for and
/// when to stop, and "记为做过".
struct PlayView: View {
    @Environment(AppModel.self) private var app
    let play: Play
    let month: Int

    var body: some View {
        let did = app.ticked(month, TickKind.did, play.code)
        let art = ArtIndex.shared.steps(play.code)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        CodeTile(code: play.code, tint: app.companion.tint, size: 30)
                        Text(play.name).font(Typeface.serif(28, relativeTo: .largeTitle)).fixedSize(horizontal: false, vertical: true)
                        Text([play.age, play.domains.joined(separator: "、")].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.subheadline).foregroundStyle(Palette.secondaryText)
                    }
                    Spacer(minLength: 8)
                    Duo(primary: app.companion, size: 70, mood: did ? .happy : .open, look: CGPoint(x: -0.7, y: 0.6))
                }

                if !play.prepare.isEmpty || !play.safety.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("开始之前").font(.headline)
                        if !play.prepare.isEmpty { line("准备", play.prepare, Palette.primary) }
                        if !play.safety.isEmpty { line("安全", play.safety, Palette.danger) }
                    }
                    .card(Palette.cardLow, radius: 22)
                }

                SectionHeader(title: "怎么做", kicker: "\(play.steps.count) 步", symbol: "play.circle.fill").padding(.horizontal, -20).padding(.top, -14)
                ForEach(Array(play.steps.enumerated()), id: \.offset) { i, s in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(i + 1)").font(Typeface.numerals(28)).foregroundStyle(Palette.tertiary)
                            Text(s).font(.body).fixedSize(horizontal: false, vertical: true)
                        }
                        if i < art.count { ArtView(name: art[i], label: "第 \(i + 1) 步的图示", radius: 16) }
                    }
                    .card(Palette.cardLow, radius: 24)
                }

                if !play.observe.isEmpty || !play.pause.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("做的时候").font(.headline)
                        if !play.observe.isEmpty { line("看什么", play.observe, Palette.rod) }
                        if !play.pause.isEmpty { line("停下", play.pause, Palette.tertiary) }
                    }
                    .card(Palette.cardLow, radius: 22)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .background(Palette.background)
        .safeAreaBar(edge: .bottom) {
            Button { withAnimation(.snappy) { app.toggle(month, TickKind.did, play.code, play.name) } } label: {
                Label(did ? "这个月做过了" : "记为做过", systemImage: did ? "checkmark.circle.fill" : "checkmark.circle")
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent).controlSize(.large)
            .tint(did ? Palette.mossLight : Palette.primary)
            .padding(.horizontal, 16).padding(.vertical, 8)

            .sensoryFeedback(.success, trigger: did)
        }
        .navigationTitle("满 \(month) 个月").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("分享")
            }
        }
    }

    private func line(_ label: String, _ text: String, _ color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(color).frame(minWidth: 44, alignment: .leading)
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var shareText: String {
        var s = "\(play.code) \(play.name)\n\(play.age)\n\n"
        if !play.prepare.isEmpty { s += "准备：\(play.prepare)\n" }
        if !play.safety.isEmpty { s += "安全：\(play.safety)\n" }
        s += "\n" + play.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        return s + "\n\n— 来自 芽芽月历 Mossling"
    }
}
