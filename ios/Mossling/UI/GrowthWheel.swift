import SwiftUI

/// The growth map, as a stage and a wheel. On the stage the child stands among the companions under the sky, at the
/// age of the chosen month — lying, lifting the head, sitting, crawling, standing, walking, running — with the month's
/// name, a word on it and its plays as small icons. Under it a wheel of months, 0 to 36, turns with a tick at every
/// month; turning it walks the child through the months and the page below follows.
struct GrowthWheel: View {
    @Environment(AppModel.self) private var app
    @Binding var month: Int
    let baby: Int
    @State private var arrived = 0

    var body: some View {
        let mo = app.content.month(month)
        let plays = app.content.plays(of: month)
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Sky(hour: 12)
                GrowingChild(month: month)
                    .frame(width: 150, height: 150)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 6)
                Duo(primary: app.companion, size: 74, look: CGPoint(x: -0.8, y: 0.1), poke: true, cheer: arrived)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 8).padding(.bottom, 4)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(month == 0 ? "出生" : "\(month)").font(Typeface.numerals(month == 0 ? 34 : 46, relativeTo: .largeTitle, weight: .bold))
                            .contentTransition(.numericText(value: Double(month)))
                        if month > 0 { Text("个月").font(.headline) }
                    }
                    Text(month == baby ? "宝宝在这里" : month < baby ? "走过的一站" : (app.birth.map { $0.plus(months: month).md + " 到这一站" } ?? "以后的一站"))
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

            VStack(alignment: .leading, spacing: 10) {
                Text(mo.title).font(.headline).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 6) {
                    ForEach(Array(plays.prefix(5)), id: \.id) { p in
                        let k = Palette.areaKey(of: p)
                        IconTile(symbol: Palette.areaSymbol(k), color: Palette.area(k), size: 26)
                    }
                    Text("\(plays.count) 个教具").font(.footnote).foregroundStyle(.secondary).padding(.leading, 4)
                    Spacer(minLength: 0)
                }
                MonthDial(month: $month, baby: baby)
            }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 12)
        }
        .printCard(radius: 30)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: month)
        .onChange(of: month) { _, m in if m == baby { arrived += 1 } }
        .sensoryFeedback(.success, trigger: arrived)
    }
}

/// The wheel of months: beads on a band that scrolls sideways and snaps to a month, curving away at both ends like a
/// wheel seen from the front, with a glass lens over the chosen month and a tick under the finger at every month.
private struct MonthDial: View {
    @Binding var month: Int
    let baby: Int
    @State private var pos: Int?
    private let item: CGFloat = 46

    init(month: Binding<Int>, baby: Int) {
        _month = month
        self.baby = baby
        _pos = State(initialValue: month.wrappedValue)   // centred on the chosen month from the first frame
    }

    var body: some View {
        GeometryReader { g in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(0...36, id: \.self) { m in
                        VStack(spacing: 4) {
                            Bead(month: m, here: m == baby, past: m < baby)
                                .scaleEffect(m == baby ? 0.72 : 0.86)
                                .frame(width: item, height: 40)
                            Text(m % 12 == 0 ? (m == 0 ? "出生" : "\(m / 12) 岁") : " ")
                                .font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        .frame(width: item)
                        .visualEffect { content, proxy in
                            let mid = proxy.frame(in: .scrollView).midX
                            let d = (mid - g.size.width / 2) / (g.size.width / 2)
                            return content
                                .rotation3DEffect(.degrees(Double(d) * 32), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                                .scaleEffect(1 - min(0.25, abs(d) * 0.25))
                                .opacity(1 - min(0.45, abs(d) * 0.45))
                        }
                        .id(m)
                        .onTapGesture { withAnimation(.snappy) { pos = m } }
                        .accessibilityLabel(m == 0 ? "出生" : "满 \(m) 个月")
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, (g.size.width - item) / 2)
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $pos, anchor: .center)
            .defaultScrollAnchor(UnitPoint(x: CGFloat(month) / 36, y: 0.5))
            .background(alignment: .top) {
                // a ring of gold under the chosen month (content layer: no glass)
                Circle().fill(Palette.bead.opacity(0.14))
                    .overlay(Circle().strokeBorder(Palette.bead.opacity(0.55), lineWidth: 2))
                    .frame(width: 46, height: 46).offset(y: -3)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 64)
                .onChange(of: pos) { _, p in if let p, p != month { month = p } }
        .onChange(of: month) { _, m in if pos != m { withAnimation(.snappy) { pos = m } } }
        .sensoryFeedback(.selection, trigger: pos)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("月份")
        .accessibilityValue(month == 0 ? "出生" : "满 \(month) 个月")
        .accessibilityAdjustableAction { d in
            switch d { case .increment: month = min(36, month + 1); case .decrement: month = max(0, month - 1); default: break }
        }
    }
}

/// The child, growing: the picture book's own child (tools/picturebook.py draws it at seven stages — lying, lifting
/// the head, sitting, crawling, standing, walking, running), so the child on the wheel is the child in the pictures.
/// Between stages one gives way to the next with a spring; within a stage the child grows a little each month.
struct GrowingChild: View {
    let month: Int
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
        .accessibilityHidden(true)
    }
}

/// A picture with a transparent ground (a figure), fitted into its frame.
struct Figure: View {
    let name: String
    @Environment(\.displayScale) private var scale
    @State private var img: UIImage?
    var body: some View {
        GeometryReader { g in
            // Color.clear keeps the view non-empty so its task runs before the image exists
            ZStack { Color.clear; if let img { Image(uiImage: img).resizable().scaledToFit() } }
                .frame(width: g.size.width, height: g.size.height)
                .task(id: name) {
                    let px = Int(max(g.size.width, g.size.height) * scale), n = name
                    img = await Task.detached(priority: .userInitiated) { ArtCache.shared.image(n, maxPixel: px) }.value
                }
        }
    }
}
