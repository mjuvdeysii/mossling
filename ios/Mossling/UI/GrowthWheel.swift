import SwiftUI

/// The growth map, as a stage and a bead chain. On the stage the child stands among the companions under the sky, at
/// the age of the chosen month — lying, lifting the head, sitting, crawling, standing, walking, running — with the
/// month's name, a word on it and its plays as small icons. Under it all 37 months as a winding bead chain (BeadPath):
/// running a finger along it walks the child through the months and the page below follows.
struct GrowthWheel: View {
    @Environment(AppModel.self) private var app
    @Environment(\.night) private var night
    @Binding var month: Int
    let baby: Int
    @State private var arrived = 0
    @State private var giggles = 0
    /// What the wheel shows while it turns. The page below follows only when the wheel comes to rest, so turning
    /// it stays under the finger (re-laying out the whole page at every bead made it stutter).
    @State private var preview: Int

    init(month: Binding<Int>, baby: Int) {
        _month = month; self.baby = baby; _preview = State(initialValue: month.wrappedValue)
    }

    var body: some View {
        let m = preview
        let mo = app.content.month(m)
        let plays = app.content.plays(of: m)
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                StagePlate(night: night)
                // 3D at night the child is asleep in the crib in the plate; Otto's lamp comes on for a moment and goes out
                if night && StagePlate.room { LampFlash(at: UnitPoint(x: 0.86, y: 0.72), reach: 230) }
                // tap the child: a giggle, and the companions cheer with it
                if !(night && StagePlate.room) {
                GrowingChild(month: m, giggle: giggles)
                    .frame(width: 150, height: 150)
                    .contentShape(Rectangle())
                    .onTapGesture { giggles += 1 }
                    .accessibilityAddTraits(.isButton).accessibilityLabel("宝宝")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 6)
                }
                // 3D: Moss is the child on the stage, so Otto keeps watch beside him alone (the grown-up and the child)
                Group {
                    if ArtStyle.current == .vinyl {
                        Creature(kind: .otto, look: CGPoint(x: -0.8, y: 0.2), lid: night ? 0.5 : nil, poke: true, glow: night, glowFor: night ? 4.5 : nil)
                            .frame(width: 64 * Kind.otto.scale, height: 64 * Kind.otto.scale)
                    } else {
                        Duo(primary: app.companion, size: 64, look: CGPoint(x: -0.8, y: 0.1), poke: true, cheer: arrived &+ giggles, night: night, briefLamp: night && StagePlate.room)
                    }
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 8).padding(.bottom, 4)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(m == 0 ? "出生" : "\(m)").font(Typeface.numerals(m == 0 ? 34 : 46, relativeTo: .largeTitle, weight: .bold))
                            .contentTransition(.numericText(value: Double(m)))
                        if m > 0 { Text("个月").font(.headline) }
                    }
                    Text(verbatim: m == baby ? "宝宝在这里" : m < baby ? "走过的一站" : (app.birth.map { b in let d = b.plus(months: m); return (d.y == Day.today.y ? d.md : "\(d.y)年\(d.md)") + " 到这一站" } ?? "以后的一站"))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(.white.opacity(0.7)))
                }
                .foregroundStyle(Color(hex: 0x2E2418))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(12)
                .accessibilityElement(children: .combine)
            }
            .frame(height: 210)
            .clipped()
            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: m)   // the stage only, never the dial

            VStack(alignment: .leading, spacing: 10) {
                Text(mo.title).font(.headline).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    ForEach(Array(plays.prefix(5)), id: \.id) { p in
                        let k = Palette.areaKey(of: p)
                        IconTile(symbol: Palette.areaSymbol(k), color: Palette.area(k), size: 26)
                    }
                    Text("\(plays.count) 个教具").font(.footnote).foregroundStyle(Palette.secondaryText).padding(.leading, 4)
                    Spacer(minLength: 0)
                }
                BeadPath(preview: $preview, baby: baby, companion: app.companion) { settled in
                    if settled != month { month = settled }
                    if settled == baby { arrived += 1 }
                }
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 12)
        }
        .printCard(radius: 30)
        // a change from outside (回到本月) moves the wheel too
        .onChange(of: month) { _, v in if preview != v { preview = v } }
        .sensoryFeedback(.success, trigger: arrived)
        .sensoryFeedback(.impact(weight: .light), trigger: giggles)
    }
}

/// The growth map as a Montessori bead chain laid out on the card: all 37 months at once, three years in three rows
/// that wind like a board-game path (birth to 1, then back along the second year, then on along the third), so where
/// the child is can be read at a glance and any month is one touch away. Months lived are beads in their year's
/// colour on a coloured string, the child's month is the golden bead with the companion standing on it, months ahead
/// are pale; after the last bead the string runs on, dotted (the story goes on).
///
/// Touch: tap a bead, or run a finger along the chain — the chosen ring follows the finger bead by bead with a tick
/// at each, the stage above shows that month as it passes, and the page below follows when the finger lifts.
/// VoiceOver: one adjustable element (swipe up/down for the next or previous month).
struct BeadPath: View {
    @Binding var preview: Int
    let baby: Int
    var companion: Kind = .moss
    let settle: (Int) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var dragging = false

    static let rowHeight: CGFloat = 46
    /// Where bead `m` sits in a chain `width` wide: column and row of the winding path, then points.
    static func point(_ m: Int, width: CGFloat) -> CGPoint {
        let margin: CGFloat = 16, step = (width - 2 * margin - 12) / 12
        let (row, col): (Int, Int) = m <= 12 ? (0, m) : m <= 24 ? (1, 12 - (m - 13)) : (2, 1 + (m - 25))
        return CGPoint(x: margin + CGFloat(col) * step, y: 34 + CGFloat(row) * rowHeight)
    }
    /// The bead nearest a touch.
    static func month(near p: CGPoint, width: CGFloat) -> Int {
        (0...36).min { a, b in
            let pa = point(a, width: width), pb = point(b, width: width)
            return hypot(pa.x - p.x, (pa.y - p.y) * 1.6) < hypot(pb.x - p.x, (pb.y - p.y) * 1.6)
        } ?? 0
    }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in draw(&ctx, w) }
                // the year marks under the chain's turns
                ForEach([(0, "出生"), (12, "1 岁"), (24, "2 岁"), (36, "3 岁")], id: \.0) { m, t in
                    let p = Self.point(m, width: w)
                    Text(t).font(.caption2.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                        .fixedSize().position(x: p.x, y: p.y + 17)
                }
                // the child's month: the companion stands on its bead
                let h = Self.point(baby, width: w)
                Figure(name: "ip_\(companion == .moss ? "moss" : "otto")_idle.webp")
                    .frame(width: 30, height: 30)
                    .position(x: h.x, y: h.y - 22)
                    .allowsHitTesting(false)
                // the chosen month: a ring that glides along the chain, and its number above it
                let c = Self.point(preview, width: w)
                // the month's number sits inside the ring (never above it, where the year marks and the companion are)
                ZStack {
                    if preview != baby {
                        Circle().fill(Palette.card).frame(width: 28, height: 28)
                        Text("\(preview)").font(Typeface.numerals(13, relativeTo: .caption2, weight: .bold))
                            .foregroundStyle(.primary).minimumScaleFactor(0.7).lineLimit(1).frame(width: 24)
                    }
                    Circle().strokeBorder(Color.primary.opacity(0.75), lineWidth: 2.5).frame(width: 30, height: 30)
                }
                .position(c)
                .animation(reduce ? nil : .spring(response: dragging ? 0.18 : 0.38, dampingFraction: 0.78), value: preview)
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    dragging = true
                    let m = Self.month(near: v.location, width: w)
                    if m != preview { preview = m }
                }
                .onEnded { v in
                    dragging = false
                    let m = Self.month(near: v.location, width: w)
                    preview = m; settle(m)
                })
        }
        .frame(height: 34 + Self.rowHeight * 2 + 30)
        .sensoryFeedback(.selection, trigger: preview)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("成长地图，37 个月")
        .accessibilityValue((preview == 0 ? "出生" : "满 \(preview) 个月") + (preview == baby ? "，宝宝在这里" : ""))
        .accessibilityAdjustableAction { d in
            switch d {
            case .increment: preview = min(36, preview + 1); settle(preview)
            case .decrement: preview = max(0, preview - 1); settle(preview)
            default: break
            }
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ w: CGFloat) {
        // the string: through every bead, with a round turn at the end of each year; lived in colour, ahead pale
        func segment(_ a: Int, _ b: Int) -> Path {
            var p = Path(); let pa = Self.point(a, width: w), pb = Self.point(b, width: w)
            p.move(to: pa)
            if pa.y == pb.y { p.addLine(to: pb) }
            else {
                let out: CGFloat = a == 12 ? 22 : -22
                p.addCurve(to: pb, control1: CGPoint(x: pa.x + out, y: pa.y), control2: CGPoint(x: pb.x + out, y: pb.y))
            }
            return p
        }
        for m in 0..<36 {
            let lived = m + 1 <= baby
            ctx.stroke(segment(m, m + 1), with: .color(lived ? Land.of(m).crayon.opacity(0.75) : Palette.outline.opacity(0.9)),
                       style: StrokeStyle(lineWidth: lived ? 3 : 2, lineCap: .round))
        }
        // after the last bead the string runs on, dotted
        let end = Self.point(36, width: w)
        var tail = Path(); tail.move(to: end)
        tail.addCurve(to: CGPoint(x: end.x + 12, y: end.y + 18), control1: CGPoint(x: end.x + 14, y: end.y), control2: CGPoint(x: end.x + 14, y: end.y + 8))
        ctx.stroke(tail, with: .color(Palette.bead.opacity(0.7)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 5]))
        for m in 0...36 {
            let p = Self.point(m, width: w)
            let here = m == baby, lived = m < baby
            let d: CGFloat = here ? 20 : lived ? 15 : 13
            let r = CGRect(x: p.x - d / 2, y: p.y - d / 2, width: d, height: d)
            let c = here ? Palette.bead : Land.of(m).crayon
            if here || lived {
                ctx.fill(Path(ellipseIn: r.offsetBy(dx: 0, dy: 1.5)), with: .color(c.mix(with: .black, by: 0.35).opacity(0.25)))
                ctx.fill(Path(ellipseIn: r), with: .radialGradient(Gradient(colors: [c.mix(with: .white, by: 0.35), c, c.mix(with: .black, by: 0.15)]),
                                                                   center: CGPoint(x: r.minX + d * 0.35, y: r.minY + d * 0.3), startRadius: 0, endRadius: d * 0.75))
            } else {
                ctx.fill(Path(ellipseIn: r), with: .color(Palette.card))
                ctx.stroke(Path(ellipseIn: r.insetBy(dx: 0.75, dy: 0.75)), with: .color(c.opacity(0.55)), lineWidth: 1.5)
            }
            // every year's first bead is a little larger in the real chains; here it carries a dot
            if m % 12 == 0 && !here { ctx.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(lived ? .white.opacity(0.9) : c.opacity(0.7))) }
        }
    }
}

/// The child, growing: the picture book's own child (tools/picturebook.py draws it at seven stages — lying, lifting
/// the head, sitting, crawling, standing, walking, running), so the child on the wheel is the child in the pictures.
/// Between stages one gives way to the next with a spring; within a stage the child grows a little each month.
struct GrowingChild: View {
    let month: Int
    /// Change it to make the child giggle (a little jump).
    var giggle = 0
    @Environment(\.accessibilityReduceMotion) private var reduce

    static func stage(_ m: Int) -> Int { m < 3 ? 0 : m < 6 ? 1 : m < 9 ? 2 : m < 12 ? 3 : m < 18 ? 4 : m < 24 ? 5 : 6 }
    private static let starts = [0, 3, 6, 9, 12, 18, 24, 37]

    var body: some View {
        let st = Self.stage(month)
        let a = Self.starts[st], b = Self.starts[st + 1]
        let grow = 0.94 + 0.06 * Double(month - a) / Double(max(1, b - a - 1))
        ZStack {
            Figure(name: "child_\(st).webp")
                .id(st)
                .transition(reduce ? .opacity : .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
        }
        .scaleEffect(grow, anchor: .bottom)
        .animation(reduce ? nil : .spring(response: 0.5, dampingFraction: 0.62), value: month)
        .modifier(Lively(giggle: giggle))
        .accessibilityHidden(true)
    }
}

/// The child is alive: a slow sway from the feet and a breath, and a little jump of a giggle when `giggle` changes.
/// Still under Reduce Motion.
struct Lively: ViewModifier {
    let giggle: Int
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var sway = false
    @State private var breath = false
    func body(content: Self.Content) -> some View {
        // two endless eased swings (not a per-frame clock re-running the view thirty times a second)
        content
            .rotationEffect(.degrees(reduce ? 0 : sway ? 2.4 : -2.4), anchor: .bottom)
            .scaleEffect(x: 1, y: reduce ? 1 : breath ? 1.014 : 0.986, anchor: .bottom)
            .onAppear {
                guard !reduce else { return }
                withAnimation(.easeInOut(duration: 1.96).repeatForever(autoreverses: true)) { sway = true }
                withAnimation(.easeInOut(duration: 1.37).repeatForever(autoreverses: true)) { breath = true }
            }
        .keyframeAnimator(initialValue: 0.0, trigger: giggle) { v, h in
            v.offset(y: reduce ? 0 : -h).rotationEffect(.degrees(reduce ? 0 : h * 0.4), anchor: .bottom)
        } keyframes: { _ in
            SpringKeyframe(16, duration: 0.16, spring: .snappy)
            SpringKeyframe(0, duration: 0.55, spring: .bouncy)
        }
    }
}

/// A picture with a transparent ground (a figure), fitted into its frame.
struct Figure: View {
    let name: String
    @Environment(\.displayScale) private var scale
    @Environment(\.girlArt) private var girl
    @State private var img: UIImage?
    var body: some View {
        let shown = ArtIndex.variant(name, girl: girl)
        GeometryReader { g in
            // Color.clear keeps the view non-empty so its task runs before the image exists
            let px = Int(max(g.size.width, g.size.height) * scale)
            let ready = img ?? ArtCache.shared.cached(shown, maxPixel: px)
            ZStack { Color.clear; if let ready { Image(uiImage: ready).resizable().scaledToFit() } }
                .frame(width: g.size.width, height: g.size.height)
                .task(id: shown) {
                    if ArtCache.shared.cached(shown, maxPixel: px) != nil { return }
                    let n = shown
                    img = await Task.detached(priority: .userInitiated) { ArtCache.shared.image(n, maxPixel: px) }.value
                }
        }
    }
}
