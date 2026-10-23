import SwiftUI

/// The growth map, as a stage and a wheel. On the stage the child stands among the companions under the sky, at the
/// age of the chosen month — lying, lifting the head, sitting, crawling, standing, walking, running — with the month's
/// name, a word on it and its plays as small icons. Under it a wheel of months, 0 to 36, turns with a tick at every
/// month; turning it walks the child through the months and the page below follows.
struct GrowthWheel: View {
    @Environment(AppModel.self) private var app
    @Binding var month: Int
    let baby: Int

    var body: some View {
        let mo = app.content.month(month)
        let plays = app.content.plays(of: month)
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Sky(hour: 12)
                GrowingChild(month: month)
                    .frame(width: 130, height: 130)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 6)
                Duo(primary: app.companion, size: 74, look: CGPoint(x: -0.8, y: 0.1), poke: true)
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
                .glassEffect(.regular.tint(.white.opacity(0.35)), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                // the lens over the chosen month
                Capsule().fill(.clear)
                    .frame(width: item + 6, height: 46)
                    .glassEffect(.regular.tint(Palette.bead.opacity(0.25)), in: Capsule())
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

/// The child, growing: a round wooden-toy child in candy colours whose pose follows the month. Every part is a view,
/// so between months SwiftUI moves each part to its new place and the child seems to grow.
struct GrowingChild: View {
    let month: Int
    @Environment(\.accessibilityReduceMotion) private var reduce

    private struct Pose {
        var head: CGPoint, headR: CGFloat
        var body: CGPoint, bodySize: CGSize, bodyTurn: Double
        var legs: CGPoint, legsSize: CGSize, legsTurn: Double
        var arm: CGPoint, armSize: CGSize, armTurn: Double
    }

    private var pose: Pose {
        switch month {
        case ..<3:   // lying on the back
            return Pose(head: CGPoint(x: 30, y: 100), headR: 15, body: CGPoint(x: 68, y: 104), bodySize: CGSize(width: 56, height: 26), bodyTurn: 0,
                        legs: CGPoint(x: 100, y: 100), legsSize: CGSize(width: 22, height: 14), legsTurn: -20, arm: CGPoint(x: 56, y: 92), armSize: CGSize(width: 10, height: 20), armTurn: 30)
        case ..<6:   // on the tummy, head up
            return Pose(head: CGPoint(x: 34, y: 82), headR: 15, body: CGPoint(x: 72, y: 106), bodySize: CGSize(width: 58, height: 24), bodyTurn: -6,
                        legs: CGPoint(x: 104, y: 110), legsSize: CGSize(width: 20, height: 12), legsTurn: 0, arm: CGPoint(x: 44, y: 104), armSize: CGSize(width: 10, height: 22), armTurn: 0)
        case ..<9:   // sitting
            return Pose(head: CGPoint(x: 62, y: 56), headR: 17, body: CGPoint(x: 62, y: 90), bodySize: CGSize(width: 36, height: 44), bodyTurn: 0,
                        legs: CGPoint(x: 78, y: 112), legsSize: CGSize(width: 36, height: 14), legsTurn: 0, arm: CGPoint(x: 80, y: 92), armSize: CGSize(width: 10, height: 26), armTurn: -40)
        case ..<12:  // crawling
            return Pose(head: CGPoint(x: 34, y: 74), headR: 16, body: CGPoint(x: 70, y: 86), bodySize: CGSize(width: 54, height: 28), bodyTurn: -8,
                        legs: CGPoint(x: 92, y: 106), legsSize: CGSize(width: 12, height: 26), legsTurn: 10, arm: CGPoint(x: 46, y: 104), armSize: CGSize(width: 11, height: 28), armTurn: -6)
        case ..<18:  // standing
            return Pose(head: CGPoint(x: 64, y: 44), headR: 17, body: CGPoint(x: 64, y: 80), bodySize: CGSize(width: 34, height: 46), bodyTurn: 0,
                        legs: CGPoint(x: 64, y: 110), legsSize: CGSize(width: 24, height: 22), legsTurn: 0, arm: CGPoint(x: 84, y: 76), armSize: CGSize(width: 10, height: 28), armTurn: -20)
        case ..<24:  // walking
            return Pose(head: CGPoint(x: 66, y: 38), headR: 17, body: CGPoint(x: 64, y: 76), bodySize: CGSize(width: 34, height: 50), bodyTurn: 6,
                        legs: CGPoint(x: 62, y: 110), legsSize: CGSize(width: 30, height: 22), legsTurn: 12, arm: CGPoint(x: 84, y: 70), armSize: CGSize(width: 10, height: 30), armTurn: -50)
        default:     // running and jumping
            return Pose(head: CGPoint(x: 68, y: 30), headR: 18, body: CGPoint(x: 64, y: 70), bodySize: CGSize(width: 36, height: 56), bodyTurn: 10,
                        legs: CGPoint(x: 60, y: 108), legsSize: CGSize(width: 34, height: 24), legsTurn: 22, arm: CGPoint(x: 88, y: 60), armSize: CGSize(width: 10, height: 32), armTurn: -80)
        }
    }

    var body: some View {
        let p = pose
        let skin = Color(hex: 0xF1CFA4), suit = Crayon.sunflower
        GeometryReader { g in
            let k = min(g.size.width, g.size.height) / 130
            ZStack(alignment: .topLeading) {
                Ellipse().fill(Color.black.opacity(0.1)).frame(width: 70 * k, height: 8 * k).position(x: 64 * k, y: 122 * k)
                part(p.legs, p.legsSize, p.legsTurn, k, suit.mix(with: .black, by: 0.12))
                part(p.body, p.bodySize, p.bodyTurn, k, suit)
                part(p.arm, p.armSize, p.armTurn, k, suit.mix(with: .white, by: 0.1))
                Circle()
                    .fill(RadialGradient(colors: [skin.mix(with: .white, by: 0.55), skin, skin.mix(with: .black, by: 0.18)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: p.headR * k * 1.4))
                    .frame(width: p.headR * 2 * k, height: p.headR * 2 * k)
                    .overlay(alignment: .topLeading) {
                        Ellipse().fill(.white.opacity(0.7)).frame(width: p.headR * 0.6 * k, height: p.headR * 0.36 * k).offset(x: p.headR * 0.42 * k, y: p.headR * 0.32 * k)
                    }
                    .position(x: p.head.x * k, y: p.head.y * k)
                    .shadow(color: .black.opacity(0.12), radius: 3 * k, y: 2 * k)
            }
        }
        .animation(reduce ? nil : .spring(response: 0.55, dampingFraction: 0.62), value: month)
        .accessibilityHidden(true)
    }

    private func part(_ c: CGPoint, _ s: CGSize, _ turn: Double, _ k: CGFloat, _ color: Color) -> some View {
        Capsule()
            .fill(LinearGradient(colors: [color.mix(with: .black, by: 0.06), color.mix(with: .white, by: 0.42), color, color.mix(with: .black, by: 0.2)],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: s.width * k, height: s.height * k)
            .rotationEffect(.degrees(turn))
            .shadow(color: .black.opacity(0.1), radius: 3 * k, y: 2 * k)
            .position(x: c.x * k, y: c.y * k)
    }
}
