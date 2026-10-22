import SwiftUI

/// One play, step by step as pictures: before starting (what to prepare, safety), each step as its picture with one
/// sentence, what to watch for and when to stop; "记为做过" stays at the bottom.
struct PlayView: View {
    @Environment(AppModel.self) private var app
    let play: Play
    let month: Int
    @State private var scrolled = false

    var body: some View {
        let did = app.ticked(month, TickKind.did, play.code)
        let art = ArtIndex.shared.steps(play.code)
        let key = Palette.areaKey(of: play)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(play.domains.joined(separator: "、"), systemImage: Palette.areaSymbol(key))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.area(key))
                    Text(play.name).font(.largeTitle.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                    Text("\(play.age) · \(play.code)").font(.subheadline).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .onScrollVisibilityChange(threshold: 0.2) { v in withAnimation(.easeOut(duration: 0.2)) { scrolled = !v } }

                if !play.prepare.isEmpty || !play.safety.isEmpty {
                    Box {
                        if !play.prepare.isEmpty { BoxRow(symbol: "tray.full.fill", color: Crayon.caramel, title: "准备", text: play.prepare, last: play.safety.isEmpty) }
                        if !play.safety.isEmpty { BoxRow(symbol: "exclamationmark.triangle.fill", color: Crayon.tangerine, title: "安全", text: play.safety, last: true) }
                    }
                }

                VStack(alignment: .leading, spacing: 22) {
                    ForEach(Array(play.steps.enumerated()), id: \.offset) { i, s in
                        VStack(alignment: .leading, spacing: 12) {
                            if i < art.count { ArtView(name: art[i], label: "第 \(i + 1) 步的图示", radius: 24) }
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("\(i + 1)").font(Typeface.numerals(15, relativeTo: .headline, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 28, height: 28).background(Palette.area(key), in: Circle())
                                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
                                Text(s).font(.title3).fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 4)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }

                if !play.observe.isEmpty || !play.pause.isEmpty {
                    Box(title: "做的时候") {
                        if !play.observe.isEmpty { BoxRow(symbol: "eye.fill", color: Crayon.sky, title: "看什么", text: play.observe, last: play.pause.isEmpty) }
                        if !play.pause.isEmpty { BoxRow(symbol: "hand.raised.fill", color: Crayon.pebble, title: "停下来", text: play.pause, last: true) }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 24)
        }
        .background(Palette.background)
        .safeAreaBar(edge: .bottom) {
            Button { withAnimation(.snappy) { app.toggle(month, TickKind.did, play.code, play.name) } } label: {
                Label(did ? "这个月做过了" : "记为做过", systemImage: did ? "checkmark.circle.fill" : "checkmark.circle")
                    .contentTransition(.symbolEffect(.replace))
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent).controlSize(.large)
            .tint(did ? Color(uiColor: .systemGray) : Palette.accent)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .sensoryFeedback(.success, trigger: did)
        }
        .navigationTitle(play.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { Text(play.name).font(.headline).lineLimit(1).opacity(scrolled ? 1 : 0) }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("分享")
            }
        }
    }

    private var shareText: String {
        var s = "\(play.name)（\(play.code)）\n\(play.age)\n\n"
        if !play.prepare.isEmpty { s += "准备：\(play.prepare)\n" }
        if !play.safety.isEmpty { s += "安全：\(play.safety)\n" }
        s += "\n" + play.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        return s + "\n\n— 芽芽月历 Mossling"
    }
}
