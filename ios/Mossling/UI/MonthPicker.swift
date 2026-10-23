import SwiftUI

/// Going to any month: the 37 months as a bead chain folded into three years — two rows of beads a year, each year in
/// its own colour — the months lived full, the child's month a larger golden bead. Tap a bead to open its month.
struct MonthPicker: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    let open: (Int) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(Land.allCases, id: \.rawValue) { land in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                IconTile(symbol: land.symbol, color: land.crayon, size: 26)
                                Text(land.years).font(.headline)
                            }
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 10) {
                                ForEach(land.rawValue * 12..<land.rawValue * 12 + 12, id: \.self) { m in bead(m) }
                            }
                        }
                        .padding(14)
                        .printCard(radius: 24)
                    }
                    HStack(spacing: 14) {
                        bead(36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("满 36 个月").font(.headline)
                            Text("故事仍在继续").font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Duo(primary: app.companion, size: 44, look: CGPoint(x: -0.8, y: 0.2), poke: false)
                    }
                    .padding(14)
                    .printCard(radius: 24)
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            .pageBackground()
            .navigationTitle("选择月份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭", systemImage: "xmark") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    private func bead(_ m: Int) -> some View {
        let baby = app.babyMonth
        return Button {
            dismiss()
            if m != baby { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { open(m) } }
        } label: {
            VStack(spacing: 3) {
                Bead(month: m, here: baby == m, past: (baby ?? -1) > m)
                    .frame(width: 48, height: 48)
                if let b = app.birth { Text(b.plus(months: m).md).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary).monospacedDigit().lineLimit(1) }
            }
        }
        .buttonStyle(.toy)
        .accessibilityLabel(m == 0 ? "出生" : "满 \(m) 个月" + (baby == m ? "，宝宝在这里" : ""))
    }
}
