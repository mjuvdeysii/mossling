import SwiftUI

/// Five handcrafted paper-cut shadow puppets for Otto's Optical Shadow Wall.
enum ShadowPuppetKind: String, CaseIterable, Identifiable, Sendable {
    case rabbit, bird, puppy, butterfly, boat
    var id: String { rawValue }

    var title: String {
        switch self {
        case .rabbit: L10n.t("垂耳兔", "Rabbit")
        case .bird: L10n.t("飞鸟", "Bird")
        case .puppy: L10n.t("小狗", "Puppy")
        case .butterfly: L10n.t("蝴蝶", "Butterfly")
        case .boat: L10n.t("帆船", "Boat")
        }
    }

    var symbol: String {
        switch self {
        case .rabbit: "hare.fill"
        case .bird: "bird.fill"
        case .puppy: "pawprint.fill"
        case .butterfly: "sparkles"
        case .boat: "sailboat.fill"
        }
    }

    /// Pentatonic/triadic celesta chord indices into `ToyboxNote.scale`.
    var chordNotes: [Int] {
        switch self {
        case .rabbit: [0, 4]
        case .bird: [2, 4, 7]
        case .puppy: [0, 2, 4]
        case .butterfly: [4, 5, 7]
        case .boat: [1, 4]
        }
    }
}

/// Pure, deterministic inverse-distance optics projecting a hand-cut puppet from Otto's golden lamp bead
/// onto the bedroom wall while steering Moss's live gaze toward the projected wall shadow.
enum ShadowWallPhysics {
    struct Projection: Equatable, Sendable {
        let wallPoint: CGPoint
        let shadowScale: Double
        let penumbraBlur: Double
        let shadowOpacity: Double
        let rotationDegrees: Double
        let mossLook: CGPoint
    }

    static func project(
        puppetNorm: CGPoint,
        lampNorm: CGPoint = CGPoint(x: 0.50, y: 0.86)
    ) -> Projection {
        let px = min(0.88, max(0.12, Double(puppetNorm.x)))
        let py = min(0.80, max(0.24, Double(puppetNorm.y)))
        let dx = px - Double(lampNorm.x)
        let dy = py - Double(lampNorm.y)
        let dist = max(0.08, hypot(dx, dy))

        // Closer to Otto's golden lamp bead -> dramatically larger, softer-edged shadow on the bedroom wall
        let proximity = min(1.0, max(0.0, (0.58 - dist) / 0.44))
        let shadowScale = 0.96 + proximity * 1.38
        let penumbraBlur = 3.0 + proximity * 12.5
        let shadowOpacity = 0.44 - proximity * 0.14

        let wallX = min(0.84, max(0.16, 0.50 + dx * 1.42))
        let wallY = min(0.56, max(0.16, py - 0.17 - proximity * 0.14))

        // Moss sits on the floor at (0.20, 0.84) looking up at the live shadow
        let mx = wallX - 0.20
        let my = wallY - 0.84
        let mLen = max(0.01, hypot(mx, my))
        let mossLook = CGPoint(x: mx / mLen, y: my / mLen)
        let rotationDegrees = max(-22.0, min(22.0, dx * 28.0))

        return Projection(
            wallPoint: CGPoint(x: wallX, y: wallY),
            shadowScale: shadowScale,
            penumbraBlur: penumbraBlur,
            shadowOpacity: shadowOpacity,
            rotationDegrees: rotationDegrees,
            mossLook: mossLook
        )
    }
}

/// Interactive single-viewport bedroom optical theater inside Sensory Toybox:
/// Otto casts a conical golden light beam upward from his head bead (strictly no hands),
/// the parent glides a die-cut silhouette closer to or farther from the light for true inverse-distance shadows,
/// and Moss gazes up at the moving shadow on the nursery wall.
struct ShadowWallStudio: View {
    let dark: Bool
    let initialPuppet: ShadowPuppetKind
    let onInteract: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var type

    @State private var puppet: ShadowPuppetKind
    @State private var puppetNorm = CGPoint(x: 0.54, y: 0.54)
    @State private var flapPhase: Double = 0.0
    @State private var leafBurst: Int = 0
    @State private var mossExcited = false
    @State private var chordTask: Task<Void, Never>?
    @State private var settleTask: Task<Void, Never>?

    private let lampNorm = CGPoint(x: 0.50, y: 0.84)

    init(dark: Bool, initialPuppet: ShadowPuppetKind = .rabbit, onInteract: @escaping () -> Void) {
        self.dark = dark
        self.initialPuppet = initialPuppet
        self.onInteract = onInteract
        _puppet = State(initialValue: initialPuppet)
    }

    var body: some View {
        let proj = ShadowWallPhysics.project(puppetNorm: puppetNorm, lampNorm: lampNorm)
        let flat = ArtStyle.current == .flat

        VStack(spacing: 10) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let lampPt = CGPoint(x: w * lampNorm.x, y: h * lampNorm.y)
                let puppetPt = CGPoint(x: w * puppetNorm.x, y: h * puppetNorm.y)
                let wallPt = CGPoint(x: w * proj.wallPoint.x, y: h * proj.wallPoint.y)

                ZStack(alignment: .topLeading) {
                    wallBackdrop(w: w, h: h, lampPt: lampPt)

                    // Conical amber projection beam radiating from Otto's golden head bead
                    Canvas(rendersAsynchronously: false) { ctx, _ in
                        var cone = Path()
                        cone.move(to: CGPoint(x: lampPt.x - 10, y: lampPt.y - 6))
                        cone.addLine(to: CGPoint(x: lampPt.x + 10, y: lampPt.y - 6))
                        cone.addLine(to: CGPoint(x: w * 0.96, y: 0))
                        cone.addLine(to: CGPoint(x: w * 0.04, y: 0))
                        cone.closeSubpath()
                        ctx.fill(
                            cone,
                            with: .linearGradient(
                                Gradient(colors: [
                                    Palette.amber.opacity(0.32),
                                    Color(hex: 0xFFE6A8).opacity(0.14),
                                    Color(hex: 0xFFE6A8).opacity(0.02)
                                ]),
                                startPoint: lampPt,
                                endPoint: CGPoint(x: lampPt.x, y: 0)
                            )
                        )
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                    // Optical penumbra halo behind sharp inner shadow
                    ShadowPuppetShape(kind: puppet, flapPhase: flapPhase)
                        .fill(Color(hex: 0x161224).opacity(proj.shadowOpacity * 0.42))
                        .frame(width: 96, height: 96)
                        .scaleEffect(proj.shadowScale * 1.07)
                        .rotationEffect(.degrees(proj.rotationDegrees))
                        .blur(radius: proj.penumbraBlur * 1.55)
                        .position(wallPt)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                    // Primary optical wall silhouette (closer to Otto's bead -> bigger + softer blur)
                    ShadowPuppetShape(kind: puppet, flapPhase: flapPhase)
                        .fill(Color(hex: 0x1A152C).opacity(proj.shadowOpacity))
                        .frame(width: 96, height: 96)
                        .scaleEffect(proj.shadowScale)
                        .rotationEffect(.degrees(proj.rotationDegrees))
                        .blur(radius: proj.penumbraBlur)
                        .position(wallPt)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                    // Quiet nursery wooden skirting & woven play mat at floor level
                    nurseryFloor(w: w, h: h)

                    // Slender birch control rod connecting parent's hand zone up to the paper-cut puppet
                    Canvas(rendersAsynchronously: false) { ctx, _ in
                        var rod = Path()
                        rod.move(to: CGPoint(x: puppetPt.x + 2, y: puppetPt.y + 18))
                        rod.addLine(to: CGPoint(x: puppetPt.x + 12, y: h + 8))
                        ctx.stroke(
                            rod,
                            with: .color(Color(hex: 0xD9B582).opacity(0.85)),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                    // Tactile foreground birch paper-cut puppet silhouette
                    ShadowPuppetShape(kind: puppet, flapPhase: flapPhase)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x5E4A36), Color(hex: 0x3D2E20)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            ShadowPuppetShape(kind: puppet, flapPhase: flapPhase)
                                .stroke(Palette.beadLight.opacity(0.55), lineWidth: 1.2)
                        )
                        .frame(width: 58, height: 58)
                        .rotationEffect(.degrees(proj.rotationDegrees * 0.55))
                        .shadow(color: .black.opacity(0.32), radius: 5, y: 3)
                        .position(puppetPt)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                    // Grounded Moss gazing up at the live wall shadow
                    StoryTheaterActorView(
                        kind: .moss,
                        size: 72,
                        mood: mossExcited ? .wow : .open,
                        look: proj.mossLook,
                        lean: Double(proj.mossLook.x) * 6.0,
                        isStatic: reduce || Perf.still,
                        dark: true,
                        flat: flat,
                        compact: true
                    )
                    .overlay { MintLeafBurst(trigger: leafBurst) }
                    .position(x: w * 0.19, y: h * 0.87)
                    .allowsHitTesting(false)

                    // Grounded Otto casting light strictly from his golden head bead (zero hands)
                    StoryTheaterActorView(
                        kind: .otto,
                        size: 78,
                        mood: .happy,
                        look: CGPoint(x: (puppetNorm.x - 0.50) * 1.4, y: -0.72),
                        lid: 0.25,
                        lean: Double((puppetNorm.x - 0.50) * 8.0),
                        isStatic: reduce || Perf.still,
                        dark: true,
                        flat: flat,
                        compact: true
                    )
                    .position(x: w * 0.50, y: h * 0.87)
                    .allowsHitTesting(false)

                    // Minimal top cue badge inside optical darkroom wall
                    HStack(spacing: 6) {
                        GoldBead(size: 8)
                        Text(L10n.t("拖动纸偶靠近光珠 · 轻点挥动", "Drag puppet toward light · Tap to animate"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Palette.lampInk.opacity(0.84))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.28)))
                    .padding(10)
                    .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let nx = min(0.86, max(0.14, value.location.x / max(1, w)))
                            let ny = min(0.78, max(0.26, value.location.y / max(1, h)))
                            let movedLarge = abs(nx - puppetNorm.x) + abs(ny - puppetNorm.y) > 0.05
                            puppetNorm = CGPoint(x: nx, y: ny)
                            onInteract()
                            if movedLarge {
                                TactileEngine.shared.dimmerTick()
                            }
                        }
                        .onEnded { value in
                            if hypot(value.translation.width, value.translation.height) < 10 {
                                animatePuppet()
                            }
                        }
                )
            }
            .frame(minHeight: 320)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Palette.amber.opacity(0.28), lineWidth: 1)
            )
            .printCard(radius: Radius.card)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.t("Otto 光影手影墙，当前纸偶为\(puppet.title)", "Otto Shadow Wall, current puppet \(puppet.title)"))
            .accessibilityHint(L10n.t("拖动调整手影大小与位置，轻点或调整触发声光律动", "Drag to move puppet toward lamp; tap or adjust to animate"))
            .accessibilityAdjustableAction { dir in
                let delta: CGFloat = dir == .increment ? -0.08 : 0.08
                puppetNorm.y = min(0.78, max(0.26, puppetNorm.y + delta))
                animatePuppet()
            }

            puppetSelectorDock
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                chordTask?.cancel()
                chordTask = nil
                settleTask?.cancel()
                settleTask = nil
                flapPhase = 0.0
                mossExcited = false
                ToyboxAudioEngine.shared.stop()
            }
        }
        .onChange(of: ToyboxAudioEngine.shared.routeStopGeneration) { _, _ in
            chordTask?.cancel()
            chordTask = nil
        }
        .onDisappear {
            chordTask?.cancel()
            chordTask = nil
            settleTask?.cancel()
            settleTask = nil
        }
    }

    private func wallBackdrop(w: CGFloat, h: CGFloat, lampPt: CGPoint) -> some View {
        let baseWall = LinearGradient(
            colors: [Color(hex: 0x1E2542), Color(hex: 0x352D46), Color(hex: 0x4E3B3E)],
            startPoint: .top,
            endPoint: .bottom
        )

        return Group {
            if !Perf.still && scenePhase == .active {
                TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduce)) { tl in
                    let t = Float(tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 120))
                    baseWall
                        .colorEffect(
                            ShaderLibrary.shadowWallAtmosphere(
                                .float2(Float(w), Float(h)),
                                .float2(Float(lampPt.x), Float(lampPt.y)),
                                .float(1.0),
                                .float(t)
                            )
                        )
                }
            } else {
                baseWall
                    .overlay(
                        RadialGradient(
                            colors: [Palette.amber.opacity(0.28), Color(hex: 0xFFE6A8).opacity(0.08), .clear],
                            center: UnitPoint(x: 0.50, y: 0.72),
                            startRadius: 8,
                            endRadius: max(w, h) * 0.72
                        )
                    )
            }
        }
        .accessibilityHidden(true)
    }

    private func nurseryFloor(w: CGFloat, h: CGFloat) -> some View {
        Canvas(rendersAsynchronously: false) { ctx, _ in
            let floorY = h * 0.85
            ctx.fill(
                Path(CGRect(x: 0, y: floorY, width: w, height: h - floorY)),
                with: .linearGradient(
                    Gradient(colors: [Color(hex: 0x7E5938), Color(hex: 0x5B3D24)]),
                    startPoint: CGPoint(x: 0, y: floorY),
                    endPoint: CGPoint(x: 0, y: h)
                )
            )
            // Baseboard molding trim separating plaster wall from wood floor
            ctx.fill(
                Path(CGRect(x: 0, y: floorY - 5, width: w, height: 6)),
                with: .color(Color(hex: 0x9C754E))
            )
            // Quilted mat pool under Moss & Otto
            let matRect = CGRect(x: w * 0.08, y: floorY + 2, width: w * 0.72, height: 14)
            ctx.fill(Path(ellipseIn: matRect), with: .color(Palette.amber.opacity(0.22)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var puppetSelectorDock: some View {
        let pills = ForEach(ShadowPuppetKind.allCases) { item in
            let selected = puppet == item
            Button {
                TactileEngine.shared.beadClick()
                onInteract()
                withAnimation(reduce ? nil : .spring(response: 0.34, dampingFraction: 0.78)) {
                    puppet = item
                }
                animatePuppet()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: item.symbol)
                        .font(.caption2.weight(.bold))
                    Text(item.title)
                        .font(.caption2.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }
                .foregroundStyle(selected ? .white : .primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: type.isAccessibilitySize ? nil : .infinity, minHeight: 34)
                .background(Capsule().fill(selected ? Palette.accentFill : (dark ? Palette.lampCard : Palette.card)))
                .overlay(Capsule().strokeBorder(selected ? .clear : Palette.outline.opacity(0.24), lineWidth: 0.75))
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }

        return Group {
            if type.isAccessibilitySize {
                FlowRow(spacing: 6, lineSpacing: 6) { pills }
            } else {
                HStack(spacing: 6) { pills }
            }
        }
    }

    private func animatePuppet() {
        chordTask?.cancel()
        settleTask?.cancel()
        onInteract()
        TactileEngine.shared.vinylPop()
        leafBurst += 1
        // Play gentle music-box chord matching this puppet
        let notes = puppet.chordNotes
        if let firstIdx = notes.first, ToyboxNote.scale.indices.contains(firstIdx) {
            ToyboxAudioEngine.shared.playNote(ToyboxNote.scale[firstIdx], timbre: .musicBox)
        }
        if notes.count > 1 {
            chordTask = Task { @MainActor in
                for (offset, scaleIdx) in notes.enumerated() where offset > 0 && ToyboxNote.scale.indices.contains(scaleIdx) {
                    try? await Task.sleep(for: .milliseconds(75))
                    guard !Task.isCancelled else { return }
                    ToyboxAudioEngine.shared.playNote(ToyboxNote.scale[scaleIdx], timbre: .musicBox)
                }
            }
        }

        if reduce || scenePhase != .active {
            flapPhase = 0.0
            mossExcited = false
            return
        }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.55)) {
            flapPhase = 1.0
            mossExcited = true
        }
        settleTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
                flapPhase = 0.0
                mossExcited = false
            }
        }
    }
}

/// Custom procedural silhouettes for the 5 paper-cut shadow puppets.
private struct ShadowPuppetShape: Shape {
    let kind: ShadowPuppetKind
    var flapPhase: Double = 0

    var animatableData: Double {
        get { flapPhase }
        set { flapPhase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let f = CGFloat(flapPhase)
        var p = Path()

        switch kind {
        case .rabbit:
            // Plump seated rabbit body + twin tall ears that tilt cheerfully on tap
            p.addEllipse(in: CGRect(x: w * 0.28, y: h * 0.48, width: w * 0.44, height: h * 0.38))
            p.addEllipse(in: CGRect(x: w * 0.34, y: h * 0.28, width: w * 0.32, height: h * 0.28))
            p.addEllipse(in: CGRect(x: w * 0.20, y: h * 0.70, width: w * 0.14, height: h * 0.14))
            let earL = Path(roundedRect: CGRect(x: w * 0.38, y: h * (0.04 + f * 0.04), width: w * 0.10, height: h * 0.30), cornerRadius: w * 0.05)
            let earR = Path(roundedRect: CGRect(x: w * (0.52 + f * 0.04), y: h * (0.06 + f * 0.06), width: w * 0.10, height: h * 0.28), cornerRadius: w * 0.05)
            p.addPath(earL)
            p.addPath(earR)

        case .bird:
            // Soaring songbird with dynamic wing-beat arc driven by flapPhase
            p.addEllipse(in: CGRect(x: w * 0.28, y: h * 0.46, width: w * 0.44, height: h * 0.24))
            p.addEllipse(in: CGRect(x: w * 0.62, y: h * 0.38, width: w * 0.18, height: h * 0.18))
            var beak = Path()
            beak.move(to: CGPoint(x: w * 0.78, y: h * 0.44))
            beak.addLine(to: CGPoint(x: w * 0.94, y: h * 0.48))
            beak.addLine(to: CGPoint(x: w * 0.78, y: h * 0.52))
            beak.closeSubpath()
            p.addPath(beak)

            let wingY = h * (0.14 + f * 0.18)
            var wing = Path()
            wing.move(to: CGPoint(x: w * 0.44, y: h * 0.50))
            wing.addQuadCurve(to: CGPoint(x: w * 0.26, y: wingY), control: CGPoint(x: w * 0.24, y: h * 0.34))
            wing.addQuadCurve(to: CGPoint(x: w * 0.58, y: h * 0.48), control: CGPoint(x: w * 0.48, y: wingY + h * 0.04))
            wing.closeSubpath()
            p.addPath(wing)

            var tail = Path()
            tail.move(to: CGPoint(x: w * 0.30, y: h * 0.54))
            tail.addLine(to: CGPoint(x: w * 0.08, y: h * 0.46))
            tail.addLine(to: CGPoint(x: w * 0.12, y: h * 0.62))
            tail.closeSubpath()
            p.addPath(tail)

        case .puppy:
            // Friendly playful puppy silhouette with floppy ear & tail wag
            p.addRoundedRect(in: CGRect(x: w * 0.22, y: h * 0.46, width: w * 0.44, height: h * 0.30), cornerSize: CGSize(width: w * 0.12, height: w * 0.12))
            p.addEllipse(in: CGRect(x: w * 0.52, y: h * 0.24, width: w * 0.30, height: h * 0.28))
            p.addRoundedRect(in: CGRect(x: w * 0.72, y: h * (0.34 + f * 0.04), width: w * 0.16, height: h * 0.12), cornerSize: CGSize(width: w * 0.06, height: w * 0.06))
            p.addRoundedRect(in: CGRect(x: w * 0.52, y: h * 0.28, width: w * 0.10, height: h * 0.22), cornerSize: CGSize(width: w * 0.05, height: w * 0.05))
            // Legs & cheerful wagging tail
            p.addRoundedRect(in: CGRect(x: w * 0.26, y: h * 0.68, width: w * 0.10, height: h * 0.20), cornerSize: CGSize(width: 4, height: 4))
            p.addRoundedRect(in: CGRect(x: w * 0.52, y: h * 0.68, width: w * 0.10, height: h * 0.20), cornerSize: CGSize(width: 4, height: 4))
            var tail = Path()
            tail.move(to: CGPoint(x: w * 0.24, y: h * 0.52))
            tail.addQuadCurve(to: CGPoint(x: w * (0.10 + f * 0.06), y: h * (0.32 - f * 0.06)), control: CGPoint(x: w * 0.10, y: h * 0.48))
            tail.addQuadCurve(to: CGPoint(x: w * 0.26, y: h * 0.58), control: CGPoint(x: w * 0.20, y: h * 0.46))
            p.addPath(tail)

        case .butterfly:
            let spread = 1.0 - f * 0.34
            let cx = w * 0.50
            p.addRoundedRect(in: CGRect(x: cx - w * 0.04, y: h * 0.24, width: w * 0.08, height: h * 0.54), cornerSize: CGSize(width: w * 0.04, height: w * 0.04))
            for dir in [-1.0, 1.0] {
                let s = CGFloat(dir) * spread
                p.addEllipse(in: CGRect(x: cx + (dir < 0 ? -w * 0.38 * spread : w * 0.02), y: h * 0.18, width: w * 0.36 * spread, height: h * 0.32))
                p.addEllipse(in: CGRect(x: cx + (dir < 0 ? -w * 0.30 * spread : w * 0.02), y: h * 0.48, width: w * 0.28 * spread, height: h * 0.28))
                _ = s
            }

        case .boat:
            let rock = f * h * 0.04
            var hull = Path()
            hull.move(to: CGPoint(x: w * 0.16, y: h * 0.62 - rock))
            hull.addLine(to: CGPoint(x: w * 0.84, y: h * 0.62 + rock))
            hull.addQuadCurve(to: CGPoint(x: w * 0.70, y: h * 0.82), control: CGPoint(x: w * 0.80, y: h * 0.78))
            hull.addLine(to: CGPoint(x: w * 0.30, y: h * 0.82))
            hull.addQuadCurve(to: CGPoint(x: w * 0.16, y: h * 0.62 - rock), control: CGPoint(x: w * 0.20, y: h * 0.78))
            hull.closeSubpath()
            p.addPath(hull)

            var mainSail = Path()
            mainSail.move(to: CGPoint(x: w * 0.48, y: h * 0.12))
            mainSail.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.56), control: CGPoint(x: w * 0.72, y: h * 0.30))
            mainSail.addLine(to: CGPoint(x: w * 0.48, y: h * 0.56))
            mainSail.closeSubpath()
            p.addPath(mainSail)

            var jib = Path()
            jib.move(to: CGPoint(x: w * 0.44, y: h * 0.20))
            jib.addLine(to: CGPoint(x: w * 0.22, y: h * 0.56))
            jib.addLine(to: CGPoint(x: w * 0.44, y: h * 0.56))
            jib.closeSubpath()
            p.addPath(jib)
        }
        return p
    }
}
