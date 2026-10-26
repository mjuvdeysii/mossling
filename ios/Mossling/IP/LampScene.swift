import SwiftUI

/// The name, told without words (docs/IP.md §2): a low table in an evening room; Otto's bead lights up like a desk
/// lamp; in its light Moss wakes, looks twice, leans in and touches the ring stacker; the top ring wobbles; Moss turns to
/// Otto, delighted, and Otto answers with one slow blink. 孩子摸索，大人点灯 — the child explores, the adult holds the
/// light.
///
/// About four seconds, played once where it opens (the welcome page); everywhere else, and under Reduce Motion, it is
/// the last frame, still. Nothing waits for it. With `pick`, each companion is a button that makes it the main one.
struct LampScene: View {
    var play = true
    /// The main companion, ringed by a pool of light (nil: none shown).
    var chosen: Kind? = nil
    /// Shot C of the welcome page: the main one looks down at the way in.
    var lookDown = false
    var pick: ((Kind) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var light = 0.0
    @State private var awake = false
    @State private var mossLook = CGPoint(x: 0.2, y: 0.5)
    @State private var mossLean = 0.0
    @State private var reach = false
    @State private var delighted = false
    @State private var ottoLid: Double? = 0.85
    @State private var ottoLean = 0.0
    @State private var ottoLook = CGPoint(x: -0.6, y: 0.5)
    @State private var wobble = 0.0
    @State private var played = false

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let deskY = h * 0.72
            let ms = min(w * 0.36, h * 0.46), os = ms * 0.96
            let mossX = w * 0.30, ottoX = w * 0.72, toyX = w * 0.505
            let ottoOrigin = CGPoint(x: ottoX - os / 2, y: deskY - os * 0.9)
            let bead = CGPoint(x: ottoOrigin.x + os * 0.2, y: ottoOrigin.y + os * 0.115)
            ZStack(alignment: .topLeading) {
                room(w, h, deskY, bead, toyX)
                lit(w, h, deskY, bead, toyX)
                toy(at: CGPoint(x: toyX, y: deskY + 4), scale: ms / 150)
                if let c = chosen {
                    Ellipse().fill(RadialGradient(colors: [Palette.amber.opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: (c == .moss ? ms : os) * 0.5))
                        .frame(width: (c == .moss ? ms : os) * 1.1, height: 22)
                        .position(x: c == .moss ? mossX : ottoX, y: deskY + 9)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: chosen)
                }
                companion(.moss, size: ms, at: CGPoint(x: mossX, y: deskY - ms * 0.9 + ms / 2))
                companion(.otto, size: os, at: CGPoint(x: ottoX, y: deskY - os * 0.9 + os / 2))
            }
        }
        .clipped()
        .task { await run() }
        .onChange(of: lookDown) { _, _ in settleLooks() }
        .onChange(of: chosen) { _, _ in settleLooks() }
    }

    // MARK: the room

    private func room(_ w: CGFloat, _ h: CGFloat, _ deskY: CGFloat, _ bead: CGPoint, _ toyX: CGFloat) -> some View {
        Canvas { ctx, size in
            // an evening wall, warm violet, and a window with the moon
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(colors: [Color(hex: 0x2C2944), Color(hex: 0x433852)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: deskY)))
            let win = CGRect(x: w * 0.07, y: h * 0.1, width: w * 0.2, height: h * 0.26)
            ctx.fill(Path(roundedRect: win, cornerRadius: 6), with: .color(Color(hex: 0x1E2148)))
            ctx.stroke(Path(roundedRect: win, cornerRadius: 6), with: .color(Color(hex: 0x6B5A70)), lineWidth: 3)
            var cross = Path(); cross.move(to: CGPoint(x: win.midX, y: win.minY)); cross.addLine(to: CGPoint(x: win.midX, y: win.maxY))
            cross.move(to: CGPoint(x: win.minX, y: win.midY)); cross.addLine(to: CGPoint(x: win.maxX, y: win.midY))
            ctx.stroke(cross, with: .color(Color(hex: 0x6B5A70)), lineWidth: 2)
            var moon = Path(ellipseIn: CGRect(x: win.minX + win.width * 0.58, y: win.minY + win.height * 0.12, width: 12, height: 12))
            moon = moon.subtracting(Path(ellipseIn: CGRect(x: win.minX + win.width * 0.58 + 4, y: win.minY + win.height * 0.12 - 3, width: 12, height: 12)))
            ctx.fill(moon, with: .color(Color(hex: 0xFFF1C4)))
            for (x, y) in [(0.2, 0.62), (0.32, 0.3), (0.78, 0.74)] as [(CGFloat, CGFloat)] {
                ctx.fill(Path(ellipseIn: CGRect(x: win.minX + win.width * x, y: win.minY + win.height * y, width: 2, height: 2)), with: .color(.white.opacity(0.7)))
            }
            // the table: a top face and a front edge, with grain
            let top = CGRect(x: -10, y: deskY, width: w + 20, height: 16)
            ctx.fill(Path(top), with: .linearGradient(Gradient(colors: [Color(hex: 0xC99A62), Color(hex: 0xB78650)]), startPoint: CGPoint(x: 0, y: deskY), endPoint: CGPoint(x: 0, y: deskY + 16)))
            let front = CGRect(x: -10, y: deskY + 16, width: w + 20, height: h - deskY - 16)
            ctx.fill(Path(front), with: .linearGradient(Gradient(colors: [Color(hex: 0x9C6B3C), Color(hex: 0x7A522D)]), startPoint: CGPoint(x: 0, y: deskY + 16), endPoint: CGPoint(x: 0, y: h)))
            ctx.fill(Path(CGRect(x: -10, y: deskY + 15, width: w + 20, height: 1.5)), with: .color(Color(hex: 0xE2BC86).opacity(0.7)))
            for (y, x0, x1) in [(0.3, 0.05, 0.4), (0.55, 0.3, 0.85), (0.78, 0.1, 0.6)] as [(CGFloat, CGFloat, CGFloat)] {
                var gr = Path(); let gy = deskY + 16 + (h - deskY - 16) * y
                gr.move(to: CGPoint(x: w * x0, y: gy)); gr.addQuadCurve(to: CGPoint(x: w * x1, y: gy + 2), control: CGPoint(x: w * (x0 + x1) / 2, y: gy - 3))
                ctx.stroke(gr, with: .color(Color(hex: 0x6A4526).opacity(0.5)), lineWidth: 1)
            }
        }
        .accessibilityHidden(true)
    }

    /// The lamp's light: a warm halo on the wall, a soft cone, a pool on the table. Faded in as one layer.
    private func lit(_ w: CGFloat, _ h: CGFloat, _ deskY: CGFloat, _ bead: CGPoint, _ toyX: CGFloat) -> some View {
        Canvas { ctx, _ in
            ctx.fill(Path(ellipseIn: CGRect(x: bead.x - w * 0.5, y: bead.y - w * 0.5, width: w, height: w)),
                     with: .radialGradient(Gradient(colors: [Palette.amber.opacity(0.32), Palette.amber.opacity(0)]), center: bead, startRadius: 0, endRadius: w * 0.5))
            var cone = Path()
            cone.move(to: CGPoint(x: bead.x - 5, y: bead.y)); cone.addLine(to: CGPoint(x: bead.x + 5, y: bead.y))
            cone.addLine(to: CGPoint(x: toyX + w * 0.2, y: deskY + 6)); cone.addLine(to: CGPoint(x: toyX - w * 0.3, y: deskY + 6)); cone.closeSubpath()
            ctx.fill(cone, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFD98A).opacity(0.34), Color(hex: 0xFFD98A).opacity(0.04)]), startPoint: bead, endPoint: CGPoint(x: bead.x, y: deskY)))
            ctx.fill(Path(ellipseIn: CGRect(x: toyX - w * 0.34, y: deskY - 2, width: w * 0.62, height: 20)),
                     with: .radialGradient(Gradient(colors: [Color(hex: 0xFFE2A6).opacity(0.55), Color(hex: 0xFFE2A6).opacity(0)]), center: CGPoint(x: toyX - w * 0.03, y: deskY + 8), startRadius: 0, endRadius: w * 0.31))
        }
        .opacity(light)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The ring stacker, the first Montessori material many children meet: a base, a rod and three rings.
    private func toy(at p: CGPoint, scale k: CGFloat) -> some View {
        Canvas { ctx, size in
            let cx = size.width / 2, base = size.height - 4
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 30 * k, y: base - 3 * k, width: 60 * k, height: 8 * k)), with: .color(Color.black.opacity(0.22)))
            ctx.fill(Path(roundedRect: CGRect(x: cx - 26 * k, y: base - 9 * k, width: 52 * k, height: 9 * k), cornerRadius: 3 * k), with: .color(Color(hex: 0xE8C48C)))
            ctx.fill(Path(roundedRect: CGRect(x: cx - 2.5 * k, y: base - 58 * k, width: 5 * k, height: 50 * k), cornerRadius: 2.5 * k), with: .color(Color(hex: 0xE8C48C)))
            let rings: [(CGFloat, Color)] = [(44, Color(hex: 0x4FA3A0)), (34, Color(hex: 0xF2C14E)), (24, Color(hex: 0xE0644B))]
            var y = base - 9 * k
            for (i, (rw, c)) in rings.enumerated() {
                var r = ctx
                let rh = 11 * k
                if i == rings.count - 1 { r.translateBy(x: cx, y: y); r.rotate(by: .degrees(wobble)); r.translateBy(x: -cx, y: -y) }
                let rect = CGRect(x: cx - rw * k / 2, y: y - rh, width: rw * k, height: rh)
                r.fill(Path(roundedRect: rect, cornerRadius: rh / 2), with: .linearGradient(Gradient(colors: [c.mix(with: .white, by: 0.25), c, c.mix(with: .black, by: 0.18)]), startPoint: CGPoint(x: rect.minX, y: rect.minY), endPoint: CGPoint(x: rect.minX, y: rect.maxY)))
                y -= rh - 1
            }
            ctx.fill(Path(ellipseIn: CGRect(x: cx - 3.5 * k, y: base - 62 * k, width: 7 * k, height: 7 * k)), with: .color(Color(hex: 0xE8C48C)))
        }
        .frame(width: 70 * k, height: 72 * k)
        .position(x: p.x, y: p.y - 36 * k)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func companion(_ kind: Kind, size: CGFloat, at p: CGPoint) -> some View {
        let moss = kind == .moss
        let c = Creature(kind: kind,
                         mood: moss ? (!awake ? .sleep : delighted ? .happy : .open) : (delighted ? .happy : .open),
                         look: moss ? mossLook : ottoLook,
                         lid: moss ? nil : ottoLid,
                         lean: moss ? mossLean : ottoLean,
                         arms: moss && reach ? .wave : .rest,
                         glow: !moss && light > 0.5,
                         lookSeconds: Double(MascotStyle.of(kind).glanceMs) / 1000)
            .frame(width: size, height: size)
            .environment(\.colorScheme, .dark)   // an evening room: the thin light rim keeps both silhouettes
        if let pick {
            Button { pick(kind) } label: { c }
                .buttonStyle(.plain)
                .position(p)
                .accessibilityLabel("选择 \(kind.rawValue) 作为主伙伴，\(kind.trait)")
                .accessibilityAddTraits(chosen == kind ? .isSelected : [])
        } else {
            c.position(p).accessibilityHidden(true)
        }
    }

    // MARK: the four seconds

    private func run() async {
        guard play, !reduce, !played else { finalFrame(); return }
        played = true
        func wait(_ ms: Int) async { try? await Task.sleep(for: .milliseconds(ms)) }
        await wait(450)
        ottoLid = nil                                                     // Otto opens his eye, slowly
        await wait(450)
        withAnimation(.easeOut(duration: 0.7)) { light = 1 }              // the lamp comes on
        await wait(750)
        awake = true                                                      // in its light, Moss wakes
        mossLook = CGPoint(x: 0.5, y: 0.2); await wait(MascotStyle.moss.glanceMs + 40)
        mossLook = CGPoint(x: 0.95, y: 0.55); ottoLook = CGPoint(x: -0.9, y: 0.7)   // two quick looks at the rings
        await wait(500)
        mossLean = MascotStyle.moss.tiltDegrees; reach = true            // leans in and touches
        await wait(260)
        for a in [9.0, -6, 3.5, -1.5, 0] { wobble = a; await wait(80) }     // the top ring wobbles
        ottoLean = -MascotStyle.otto.tiltDegrees                          // the lamp follows the hand
        await wait(520)
        reach = false; mossLean = 0
        delighted = true; mossLook = CGPoint(x: 0.95, y: -0.2)            // turns to Otto, delighted
        await wait(450)
        ottoLook = CGPoint(x: -0.95, y: 0.1); ottoLid = 1                 // one slow blink back
        await wait(MascotStyle.otto.blinkMs + 120)
        ottoLid = nil
        await wait(700)
        delighted = false
        settleLooks()
    }

    private func finalFrame() {
        light = 1; awake = true; ottoLid = nil; reach = false; mossLean = 0; delighted = false
        settleLooks()
    }

    /// At rest: the two look at each other, or (shot C) the main one looks down at the way in.
    private func settleLooks() {
        guard light > 0.5 else { return }
        let main = chosen ?? .moss
        if lookDown {
            mossLook = main == .moss ? CGPoint(x: 0.3, y: 1) : CGPoint(x: 0.95, y: -0.1)
            ottoLook = main == .otto ? CGPoint(x: -0.3, y: 1) : CGPoint(x: -0.95, y: 0.2)
        } else {
            mossLook = CGPoint(x: 0.9, y: 0.1); ottoLook = CGPoint(x: -0.9, y: 0.4)
        }
    }
}
