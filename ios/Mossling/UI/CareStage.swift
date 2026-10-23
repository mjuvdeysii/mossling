import SwiftUI

/// The top of every record page: a small stage in the colour of the kind of record, the kind's sticker and name, when
/// it was last recorded, and the companion doing it with you — sleepy for a sleep, cheerful for the rest, and at night
/// Otto with his lamp. Little things drift up behind them, chosen by the kind: hearts for a feed, milk bubbles for a
/// bottle, z's and stars for a sleep, soap bubbles for a nappy or a bath, sparkles for the rest. Tap the companion and
/// it waves. The page's name lives here, so the bar above carries none (no duplicate).
struct CareStage: View {
    let type: String
    @Environment(JournalStore.self) private var j
    @Environment(AppModel.self) private var app
    @Environment(\.lamp) private var lamp
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var waving = true

    var body: some View {
        let c = LogType.color(type)
        let kind: Kind = lamp ? .otto : app.companion
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(LinearGradient(colors: [c.opacity(lamp ? 0.3 : 0.28), c.opacity(lamp ? 0.1 : 0.08)], startPoint: .topTrailing, endPoint: .bottomLeading))
                .background(lamp ? Palette.lampCard : Color.clear, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            Drift(kind: Drift.kind(of: type), color: c, still: reduce)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .accessibilityHidden(true)
            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    IconTile(symbol: LogType.symbol(type), color: c, size: 46, round: true)
                    Text(LogType.name(type)).font(.title2.weight(.bold))
                    Text(last).font(.footnote.weight(.medium)).foregroundStyle(.secondary).monospacedDigit()
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                Spacer(minLength: 0)
                Creature(kind: kind, mood: type == LogType.sleep && !lamp ? .sleep : .happy,
                         look: CGPoint(x: -0.7, y: -0.1), poke: true, arms: waving ? .wave : .rest, glow: lamp)
                    .frame(width: 104, height: 104)
                    .padding(.trailing, 12).padding(.bottom, 4)
                    .onTapGesture { wave() }
            }
        }
        .frame(minHeight: 156)
        .accessibilityElement(children: .combine)
        .task { try? await Task.sleep(for: .milliseconds(1300)); waving = false }
    }

    private func wave() {
        waving = true
        Task { try? await Task.sleep(for: .milliseconds(1300)); waving = false }
    }

    private var last: String {
        guard let d = j.last(type) else { return "还没有记录" }
        var s = "上次 " + ago(d)
        if type == LogType.nurse, let side = j.logs.filter({ $0.type == LogType.nurse }).max(by: { $0.start < $1.start })?.side {
            s += side == "l" ? " · 左侧" : " · 右侧"
        }
        return s
    }
}

/// Little things drifting up behind the stage.
private struct Drift: View {
    enum Kind { case hearts, milk, night, bubbles, sparkles }
    let kind: Kind
    let color: Color
    let still: Bool

    static func kind(of type: String) -> Kind {
        switch type {
        case LogType.nurse: .hearts
        case LogType.bottle: .milk
        case LogType.sleep: .night
        case LogType.diaper, LogType.bath: .bubbles
        default: .sparkles
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: still)) { tl in
            Canvas { ctx, size in
                let t = still ? 0 : tl.date.timeIntervalSinceReferenceDate
                for i in 0..<8 {
                    let seed = Double(i) * 0.618
                    let period = 7.0 + Double(i % 3) * 1.6
                    let f = (t / period + seed).truncatingRemainder(dividingBy: 1)   // 0 … 1, bottom to top
                    let x = size.width * (0.42 + 0.5 * (seed.truncatingRemainder(dividingBy: 1))) + sin(t * 0.9 + Double(i)) * 8
                    let y = size.height * (1.05 - f * 1.1)
                    let a = min(1, f * 5) * min(1, (1 - f) * 3) * 0.55
                    let s = 7 + Double(i % 3) * 3
                    draw(&ctx, CGPoint(x: x, y: y), s, a, i)
                }
            }
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ p: CGPoint, _ s: Double, _ a: Double, _ i: Int) {
        let r = CGRect(x: p.x - s / 2, y: p.y - s / 2, width: s, height: s)
        switch kind {
        case .hearts:
            ctx.fill(heart(r), with: .color(Crayon.pink.opacity(a)))
        case .milk:
            ctx.fill(Path(ellipseIn: r), with: .color(Color.white.opacity(a * 1.3)))
            ctx.stroke(Path(ellipseIn: r), with: .color(color.opacity(a)), lineWidth: 1)
        case .bubbles:
            ctx.stroke(Path(ellipseIn: r), with: .color(color.opacity(a * 1.3)), lineWidth: 1.5)
            ctx.fill(Path(ellipseIn: CGRect(x: r.minX + s * 0.22, y: r.minY + s * 0.2, width: s * 0.25, height: s * 0.25)), with: .color(Color.white.opacity(a)))
        case .night:
            if i % 2 == 0 {
                ctx.draw(Text("z").font(.system(size: s * 1.5, weight: .heavy, design: .rounded)).foregroundStyle(Crayon.lilac.opacity(a * 1.4)), at: p)
            } else {
                ctx.fill(sparkle(r), with: .color(Palette.bead.opacity(a * 1.3)))
            }
        case .sparkles:
            ctx.fill(sparkle(r), with: .color((i % 2 == 0 ? Palette.bead : color).opacity(a * 1.2)))
        }
    }

    private func heart(_ r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.3), control1: CGPoint(x: r.midX - r.width * 0.2, y: r.maxY - r.height * 0.2), control2: CGPoint(x: r.minX, y: r.midY))
        p.addArc(center: CGPoint(x: r.minX + r.width * 0.25, y: r.minY + r.height * 0.3), radius: r.width * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
        p.addArc(center: CGPoint(x: r.minX + r.width * 0.75, y: r.minY + r.height * 0.3), radius: r.width * 0.25, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: true)
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY), control1: CGPoint(x: r.maxX, y: r.midY), control2: CGPoint(x: r.midX + r.width * 0.2, y: r.maxY - r.height * 0.2))
        return p
    }

    private func sparkle(_ r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY), w = r.width / 2
        p.move(to: CGPoint(x: c.x, y: c.y - w))
        p.addQuadCurve(to: CGPoint(x: c.x + w, y: c.y), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + w), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x - w, y: c.y), control: c)
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - w), control: c)
        return p
    }
}
