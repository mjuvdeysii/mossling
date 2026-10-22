import SwiftUI

/// 0–36 months as one road: a station per month, left and right like a bead chain laid on the floor; the two companions
/// stand at the child's station; past the last station the road goes on.
struct MapView: View {
    @Environment(AppModel.self) private var app
    @Binding var path: NavigationPath
    private let stages = [0: "0–3 个月", 3: "3–6 个月", 6: "6–9 个月", 9: "9–12 个月", 12: "12–18 个月", 18: "18–24 个月", 24: "24–30 个月", 30: "30–36 个月"]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("跟着孩子，一个月一站。").font(.subheadline).foregroundStyle(Palette.secondaryText)
                        HStack(spacing: 14) {
                            legend(Palette.rod, "接种", round: true); legend(Palette.red, "儿保", round: false); legend(Palette.bead, "这个月都记下了", round: true)
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 8)
                    ForEach(0...36, id: \.self) { m in
                        if let s = stages[m] {
                            Text(s).font(.footnote.weight(.semibold)).foregroundStyle(Palette.tertiary)
                                .padding(.horizontal, 12).padding(.vertical, 5).background(Palette.tertiaryContainer, in: Capsule())
                                .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 6)
                        }
                        Station(month: m) { path.append(Route.month(m)) }.id(m)
                    }
                    StoryGoesOn(primary: app.companion).padding(.horizontal, 16).padding(.top, 16)
                }
                .padding(.bottom, 40)
            }
            .onAppear { if let b = app.babyMonth { proxy.scrollTo(b, anchor: .center) } }
            .toolbar {
                if let b = app.babyMonth {
                    ToolbarItem(placement: .topBarTrailing) { Button("满 \(b) 个月") { withAnimation { proxy.scrollTo(b, anchor: .center) } } }
                }
            }
        }
        .background(Palette.background)
        .navigationTitle("0–36 个月成长地图").navigationBarTitleDisplayMode(.large)
    }

    private func legend(_ c: Color, _ t: String, round: Bool) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: round ? 5 : 2).fill(c).frame(width: 10, height: 10)
            Text(t).font(.caption)
        }
    }
}

private struct Station: View {
    @Environment(AppModel.self) private var app
    let month: Int
    let open: () -> Void
    var body: some View {
        let c = app.content, mo = c.month(month)
        let left = month % 2 == 0
        let here = app.babyMonth == month
        let past = (app.babyMonth ?? -1) > month
        let all = !mo.vaccines.isEmpty || !mo.checkups.isEmpty
            ? (mo.vaccines.indices.allSatisfy { app.ticked(month, TickKind.vaccine, "\($0)") } && mo.checkups.indices.allSatisfy { app.ticked(month, TickKind.checkup, "\($0)") })
            : false
        Button(action: open) {
            HStack(spacing: 12) {
                if !left { Spacer(minLength: 0) }
                bead(here: here, past: past)
                VStack(alignment: .leading, spacing: 6) {
                    if let f = ArtIndex.shared.cover(month) { ArtView(name: f, radius: 12).frame(height: 70).frame(maxWidth: 124, alignment: .leading) }
                    HStack(spacing: 6) {
                        Text("\(month)").font(Typeface.numerals(18)).foregroundStyle(Palette.primary)
                        Text("个月").font(.caption)
                        if let b = app.birth { Text(b.plus(months: month).md).font(.caption2).foregroundStyle(Palette.secondaryText) }
                    }
                    Text(mo.title).font(.footnote).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 5) {
                        if !mo.vaccines.isEmpty { Circle().fill(Palette.rod).frame(width: 8, height: 8) }
                        if !mo.checkups.isEmpty { RoundedRectangle(cornerRadius: 2).fill(Palette.red).frame(width: 8, height: 8) }
                        if all { Circle().fill(Palette.bead).frame(width: 8, height: 8) }
                    }
                }
                .frame(maxWidth: 210, alignment: .leading)
                .card(here ? Palette.primaryContainer : Palette.cardLow, radius: 18, padding: 10)
                if left { Spacer(minLength: 0) }
            }
            .padding(.horizontal, 16).padding(.vertical, 5)
            .overlay(alignment: left ? .trailing : .leading) {
                if here { Duo(primary: app.companion, size: 52, look: CGPoint(x: left ? -0.8 : 0.8, y: 0.2)).padding(.horizontal, 24) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("满 \(month) 个月，\(mo.title)" + (here ? "，宝宝在这里" : ""))
    }

    private func bead(here: Bool, past: Bool) -> some View {
        Text("\(month)").font(Typeface.numerals(16)).foregroundStyle(here || past ? Palette.ink : Palette.secondaryText)
            .frame(width: 42, height: 42)
            .background(here ? Palette.bead : past ? Palette.beadLight : Palette.stone.opacity(0.5), in: Circle())
            .overlay(Circle().stroke(Palette.bead.opacity(here ? 0.5 : 0), lineWidth: 4).padding(-4))
    }
}
