import SwiftUI

/// The top of every record page: a small stage in the colour of the kind of record, the kind's sticker and name, when
/// it was last recorded, and the chosen companion with you — asleep beside a sleep, quiet otherwise, resting under the
/// lamp (the same companion by day and by night). Little things drift up behind them, chosen by the kind: hearts for a feed, milk bubbles for a
/// bottle, z's and stars for a sleep, soap bubbles for a nappy or a bath, sparkles for the rest. Tap the companion and
/// it waves. The page's name lives here, so the bar above carries none (no duplicate).
struct CareStage: View {
    let type: String
    @Environment(JournalStore.self) private var j
    @Environment(AppModel.self) private var app
    @Environment(\.lamp) private var lamp
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var waving = false

    var body: some View {
        let c = LogType.color(type)
        let kind: Kind = app.companion
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
                }
                .padding(18)
                Spacer(minLength: 0)
                // mostly still: the chosen companion, quiet; resting under the lamp (Otto's bead glows), asleep
                // beside a sleep; a wave only when tapped
                Creature(kind: kind, mood: type == LogType.sleep && !lamp ? .sleep : .open,
                         look: CGPoint(x: -0.7, y: -0.1), lid: lamp && !waving ? 0.5 : nil, poke: true,
                         arms: waving ? .wave : .rest, glow: lamp && kind == .otto)
                    .frame(width: 104, height: 104)
                    .padding(.trailing, 12).padding(.bottom, 4)
                    .onTapGesture { wave() }
            }
        }
        .frame(minHeight: 156)
        .accessibilityElement(children: .combine)
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

    @State private var images: [UIImage] = []

    var body: some View {
        // risen by Core Animation at the display's own rate (no per-frame drawing on the app's side)
        ZStack { if !still && !images.isEmpty { AirEmitter(kind: .rise(images)) } }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .onAppear { if images.isEmpty { images = Self.marks(self) } }
    }

    /// The things that rise, each drawn once at three sizes (the same drawing as before, now a particle image).
    @MainActor private static func marks(_ d: Drift) -> [UIImage] {
        [7.0, 10.0, 13.0].enumerated().compactMap { i, s in
            let side = s * 1.6 + 4
            let r = ImageRenderer(content: Canvas { ctx, _ in d.draw(&ctx, CGPoint(x: side / 2, y: side / 2), s, 0.6, i) }.frame(width: side, height: side))
            r.scale = 3
            return r.uiImage
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

/// When this kind was last recorded, and how long ago — on every record page, so the parent sees at a glance when
/// the last feed (or sleep, or nappy) was before recording the next. A feed counts from the start of the last feed,
/// breast or bottle, as feeding intervals are counted; a sleep from when the baby woke. The "ago" ticks once a minute
/// with the afterimage. Running timers are not "last".
struct LastLine: View {
    let type: String
    /// The start of a feed being timed now: the interval is then measured to it, not to now.
    var until: Double? = nil
    var compact = false
    @Environment(JournalStore.self) private var j

    struct Fact { let label: String; let at: Date; let note: String? }

    static func fact(_ type: String, in logs: [LogEntry], before: Double = .infinity) -> Fact? {
        let older = logs.filter { $0.start < before }
        switch type {
        case LogType.nurse, LogType.bottle:
            let feeds = older.filter { $0.type == LogType.nurse || $0.type == LogType.bottle }.sorted { $0.start < $1.start }
            guard var i = feeds.indices.last else { return nil }
            // walk back over the sides of the same feed to its first side
            while i > 0, feeds[i].type == LogType.nurse, feeds[i - 1].type == LogType.nurse, let pe = feeds[i - 1].end, feeds[i].start - pe <= 120_000 { i -= 1 }
            let f = feeds[i]
            let note = f.type == LogType.bottle ? "瓶喂 \(f.amount ?? 0) 毫升" : f.side.map { $0 == "l" ? "亲喂 · 先左侧" : "亲喂 · 先右侧" }
            return Fact(label: "上次喂奶", at: f.startDate, note: note)
        case LogType.sleep:
            guard let s = older.filter({ $0.type == LogType.sleep && $0.end != nil }).max(by: { $0.start < $1.start }), let e = s.endDate else { return nil }
            return Fact(label: "上次醒来", at: e, note: "睡了 " + durationValue(s.activeSeconds))
        default:
            guard let e = older.filter({ $0.type == type }).max(by: { $0.start < $1.start }) else { return nil }
            return Fact(label: "上次" + LogType.name(type), at: e.startDate, note: e.summary.isEmpty ? nil : e.summary)
        }
    }

    @Environment(\.dynamicTypeSize) private var typeSize
    private var big: Bool { typeSize >= .xxLarge }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { tl in
            if let f = Self.fact(type, in: j.logs, before: until ?? .infinity) {
                let to = until.map { Date(timeIntervalSince1970: $0 / 1000) } ?? tl.date
                let gap = to.timeIntervalSince(f.at)
                let c = LogType.color(type)
                let when = VStack(alignment: .leading, spacing: 1) {
                    Text(f.label).font(.caption.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                    Text(whenLabel(f.at) + (!compact ? f.note.map { " · " + $0 } ?? "" : ""))
                        .font(.subheadline.weight(.semibold)).monospacedDigit().fixedSize(horizontal: false, vertical: true)
                }
                let since = VStack(alignment: big ? .leading : .trailing, spacing: 0) {
                    Text(until == nil ? "已过" : "间隔").font(.caption2.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                    Ticking(text: durationValue(max(0, gap)), tint: Crayon.ink(c))
                        .font(Typeface.numerals(17, relativeTo: .headline, weight: .bold)).foregroundStyle(Crayon.ink(c)).fixedSize()
                }
                // large text: the two stack (nothing is cut or squeezed); otherwise one row
                Group {
                    if big {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "clock.arrow.circlepath").font(.footnote.weight(.semibold)).foregroundStyle(Crayon.ink(c))
                            VStack(alignment: .leading, spacing: 6) { when; since }
                            Spacer(minLength: 0)
                        }
                    } else {
                        HStack(spacing: 10) {
                            Image(systemName: "clock.arrow.circlepath").font(.footnote.weight(.semibold)).foregroundStyle(Crayon.ink(c))
                            when
                            Spacer(minLength: 6)
                            since
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(c.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityElement(children: .combine)
            } else {
                Text("还没有" + LogType.name(type) + "的记录").font(.footnote).foregroundStyle(Palette.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(LogType.color(type).opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}
