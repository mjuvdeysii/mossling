import SwiftUI

/// The growth map, as a stage and a wheel. On the stage the child stands among the companions under the sky, at the
/// age of the chosen month — lying, lifting the head, sitting, crawling, standing, walking, running — with the month's
/// name, a word on it and its plays as small icons. Under it a wheel of months, 0 to 36, turns with a tick at every
/// month; turning it walks the child through the months and the page below follows.
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
                Sky(hour: night ? 22 : 12)
                // tap the child: a giggle, and the companions cheer with it
                GrowingChild(month: m, giggle: giggles)
                    .frame(width: 150, height: 150)
                    .contentShape(Rectangle())
                    .onTapGesture { giggles += 1 }
                    .accessibilityAddTraits(.isButton).accessibilityLabel("宝宝")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 6)
                Duo(primary: night ? .otto : app.companion, size: 74, look: CGPoint(x: -0.8, y: 0.1), poke: true, cheer: arrived &+ giggles, night: night)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 8).padding(.bottom, 4)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(m == 0 ? "出生" : "\(m)").font(Typeface.numerals(m == 0 ? 34 : 46, relativeTo: .largeTitle, weight: .bold))
                            .contentTransition(.numericText(value: Double(m)))
                        if m > 0 { Text("个月").font(.headline) }
                    }
                    Text(m == baby ? "宝宝在这里" : m < baby ? "走过的一站" : (app.birth.map { b in let d = b.plus(months: m); return (d.y == Day.today.y ? d.md : "\(d.y)年\(d.md)") + " 到这一站" } ?? "以后的一站"))
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
                MonthDial(preview: $preview, baby: baby) { settled in
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

/// The wheel of months: beads on a band that scrolls sideways and snaps to a month, curving away at both ends like a
/// wheel seen from the front, a ring under the chosen month and a tick under the finger at every month. It reports
/// the month under the ring as it turns (`preview`) and the month it settles on when the scroll comes to rest.
///
/// How it moves (build 150, after "往回不跟手、定位阻尼不够细腻"): the band is a plain system scroll view, so the finger
/// drives it 1:1 both ways and a flick decelerates with the system's own physics. Two things that fought the finger
/// are gone: the old `viewAligned` snapping aligned beads to the band's *leading* edge (with the centring padding
/// that is half a bead off the ring, so every rest ended with a correction), and the month was written back into the
/// scroll position while the finger was still on it (a quick drag could be pulled back to the bead it just left).
/// Now the month is only *read* from the offset while turning; the wheel is moved by code only when it is at rest
/// (a tap, or 回到本月). Where a flick comes to rest is decided once, at release: the system's predicted resting
/// point rounded to the nearest bead (`BeadSnap`), so the deceleration itself lands on the bead with no second snap.
private struct MonthDial: View {
    @Binding var preview: Int
    let baby: Int
    let settle: (Int) -> Void
    @State private var position: ScrollPosition
    @State private var start: Int
    @State private var phase: ScrollPhase = .idle
    @State private var under: Int
    private let item = BeadSnap.item

    init(preview: Binding<Int>, baby: Int, settle: @escaping (Int) -> Void) {
        _preview = preview; self.baby = baby; self.settle = settle
        _position = State(initialValue: ScrollPosition(x: CGFloat(preview.wrappedValue) * BeadSnap.item))
        _start = State(initialValue: preview.wrappedValue)   // the first position only; never moves while turning
        _under = State(initialValue: preview.wrappedValue)
    }

    var body: some View {
        GeometryReader { g in
            let half = g.size.width / 2
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(0...36, id: \.self) { m in
                        VStack(spacing: 4) {
                            Bead(month: m, here: m == baby, past: m < baby)
                                .scaleEffect(m == baby ? 0.72 : 0.86)
                                .frame(width: item, height: 40)
                            Text(m % 12 == 0 ? (m == 0 ? "出生" : "\(m / 12) 岁") : " ")
                                .font(.caption2.weight(.semibold)).foregroundStyle(Palette.secondaryText)
                        }
                        .frame(width: item)
                        .visualEffect { content, proxy in
                            // d: −1 … 1 across the band. The bead under the ring swells a little as it arrives
                            // (a continuous "pull" rather than a jump), the ends turn away like a wheel's rim.
                            let d = (proxy.frame(in: .scrollView).midX - half) / half
                            let near = max(0, 1 - abs(d) * half / item)   // 1 at the ring, 0 a bead away
                            return content
                                .rotation3DEffect(.degrees(Double(d) * 30), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                                .scaleEffect(1 - min(0.25, abs(d) * 0.25) + near * 0.1)
                                .opacity(1 - min(0.45, abs(d) * 0.45))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { go(to: m) }
                        .accessibilityLabel(m == 0 ? "出生" : "满 \(m) 个月")
                    }
                }
                .padding(.horizontal, half - item / 2)
            }
            .scrollPosition($position)
            .scrollTargetBehavior(BeadSnap())
            .defaultScrollAnchor(UnitPoint(x: CGFloat(start) / 36, y: 0.5), for: .initialOffset)
            .onScrollGeometryChange(for: Int.self) { geo in
                BeadSnap.month(at: geo.contentOffset.x)
            } action: { _, m in
                under = m
            }
            .onScrollPhaseChange { _, p in
                phase = p
                if p == .idle { settle(under) }
            }
            .background(alignment: .top) {
                Circle().fill(Palette.bead.opacity(0.14))
                    .overlay(Circle().strokeBorder(Palette.bead.opacity(0.55), lineWidth: 2))
                    .frame(width: 46, height: 46).offset(y: -3)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 64)
        // read while turning; the stage follows the bead under the ring
        .onChange(of: under) { _, m in if m != preview { preview = m } }
        // written only at rest: a change from outside (回到本月, VoiceOver) turns the wheel to it
        .onChange(of: preview) { _, m in
            if phase == .idle, m != under { withAnimation(.smooth(duration: 0.45)) { position.scrollTo(x: CGFloat(m) * item) } }
        }
        .sensoryFeedback(.selection, trigger: under)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("月份")
        .accessibilityValue(preview == 0 ? "出生" : "满 \(preview) 个月")
        .accessibilityAdjustableAction { d in
            switch d {
            case .increment: preview = min(36, preview + 1); settle(preview)
            case .decrement: preview = max(0, preview - 1); settle(preview)
            default: break
            }
        }
    }

    private func go(to m: Int) {
        guard phase == .idle else { return }   // a tap that catches a turning wheel only stops it
        preview = m
        withAnimation(.smooth(duration: 0.45)) { position.scrollTo(x: CGFloat(m) * item) }
        settle(m)
    }
}

/// Where the wheel comes to rest. With the band padded by half its width less half a bead, bead `m` sits under the
/// ring exactly when the content offset is `m × item`; the system's predicted resting offset is rounded to the
/// nearest such offset, so a slow release settles on the nearest bead and a flick on the bead its momentum reaches.
struct BeadSnap: ScrollTargetBehavior {
    static let item: CGFloat = 46
    static let last = 36

    static func month(at offset: CGFloat) -> Int {
        min(last, max(0, Int((offset / item).rounded())))
    }

    static func resting(_ predicted: CGFloat) -> CGFloat {
        CGFloat(month(at: predicted)) * item
    }

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.x = Self.resting(target.rect.minX)
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
    func body(content: Self.Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduce)) { tl in
            let t = reduce ? 0 : tl.date.timeIntervalSinceReferenceDate
            content
                .rotationEffect(.degrees(Foundation.sin(t * 1.6) * 2.4), anchor: .bottom)
                .scaleEffect(x: 1, y: 1 + 0.014 * Foundation.sin(t * 2.3), anchor: .bottom)
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
            ZStack { Color.clear; if let img { Image(uiImage: img).resizable().scaledToFit() } }
                .frame(width: g.size.width, height: g.size.height)
                .task(id: shown) {
                    let px = Int(max(g.size.width, g.size.height) * scale), n = shown
                    img = await Task.detached(priority: .userInitiated) { ArtCache.shared.image(n, maxPixel: px) }.value
                }
        }
    }
}
