import SwiftUI

/// Motion template archetypes spanning all 46 authoritative activities in `content.json`.
enum ActivityMotionTemplate: String, Codable, CaseIterable, Sendable {
    case soundWave
    case faceMirror
    case gentleHold
    case tummyExplore
    case graspPass
    case tapContainer
    case stackBuild
    case bookMatch
}

/// Meaningful step-specific instructional kinetic action drawn over each real step diagram.
enum StepKineticAction: String, CaseIterable, Sendable {
    case offerArc
    case soundRipple
    case sideSweep
    case pauseWatch
    case liftStack
    case gentleSway

    var label: String {
        switch self {
        case .offerArc: L10n.t("轻递 · 靠近互动", "Offer · Move Closer")
        case .soundRipple: L10n.t("轻声 · 声波呼应", "Voice · Sound Arcs")
        case .sideSweep: L10n.t("慢移 · 左右轮换", "Sweep · Side to Side")
        case .pauseWatch: L10n.t("停顿 · 静等回应", "Pause · Wait & Watch")
        case .liftStack: L10n.t("托举 · 抬高换姿", "Lift · Build & Turn")
        case .gentleSway: L10n.t("轻摇 · 安抚陪伴", "Sway · Calm Rhythm")
        }
    }

    var symbol: String {
        switch self {
        case .offerArc: "arrow.up.right"
        case .soundRipple: "waveform"
        case .sideSweep: "arrow.left.and.right"
        case .pauseWatch: "eye.fill"
        case .liftStack: "arrow.up.circle.fill"
        case .gentleSway: "heart.fill"
        }
    }

    /// Infers the clearest step-specific instructional kinetic cue from the step copy and fallback archetype.
    static func infer(stepText: String, stepIndex: Int, stepCount: Int, template: ActivityMotionTemplate) -> StepKineticAction {
        let lower = stepText.lowercased()
        if stepText.contains("停") || stepText.contains("等") || stepText.contains("观察") || stepText.contains("回应")
            || lower.contains("pause") || lower.contains("wait") || lower.contains("watch") || lower.contains("observe") {
            return .pauseWatch
        }
        if stepText.contains("左右") || stepText.contains("来回") || stepText.contains("倒手") || stepText.contains("换手") || stepText.contains("追视")
            || lower.contains("side") || lower.contains("track") || lower.contains("transfer") || lower.contains("switch") || lower.contains("back and forth") {
            return .sideSweep
        }
        if stepText.contains("声") || stepText.contains("话") || stepText.contains("唱") || stepText.contains("叫") || stepText.contains("摇") || stepText.contains("敲")
            || lower.contains("sound") || lower.contains("voice") || lower.contains("sing") || lower.contains("say") || lower.contains("rattle") || lower.contains("speak") {
            return .soundRipple
        }
        if stepText.contains("叠") || stepText.contains("搭") || stepText.contains("放进") || stepText.contains("拿出") || stepText.contains("翻") || stepText.contains("抬头") || stepText.contains("趴")
            || lower.contains("stack") || lower.contains("drop") || lower.contains("container") || lower.contains("page") || lower.contains("tummy") || lower.contains("lift") {
            return .liftStack
        }
        if stepText.contains("递") || stepText.contains("放") || stepText.contains("摆") || stepText.contains("拿") || stepText.contains("举")
            || lower.contains("offer") || lower.contains("place") || lower.contains("present") || lower.contains("show") || lower.contains("reach") {
            return .offerArc
        }
        if stepText.contains("抱") || stepText.contains("镜") || stepText.contains("笑") || stepText.contains("拍") || stepText.contains("抚")
            || lower.contains("hold") || lower.contains("mirror") || lower.contains("smile") || lower.contains("pat") || lower.contains("cuddle") {
            return .gentleSway
        }

        // Fall back smoothly per archetype + step index so consecutive steps visibly differentiate
        let cycle: [StepKineticAction] = switch template {
        case .soundWave: [.soundRipple, .pauseWatch, .gentleSway]
        case .faceMirror: [.gentleSway, .pauseWatch, .offerArc]
        case .gentleHold: [.gentleSway, .pauseWatch, .soundRipple]
        case .tummyExplore: [.offerArc, .liftStack, .sideSweep]
        case .graspPass: [.offerArc, .sideSweep, .pauseWatch]
        case .tapContainer: [.liftStack, .soundRipple, .pauseWatch]
        case .stackBuild: [.liftStack, .offerArc, .pauseWatch]
        case .bookMatch: [.offerArc, .liftStack, .soundRipple]
        }
        return cycle[max(0, stepIndex) % cycle.count]
    }
}

/// Declarative per-activity physics & prop specification loaded from `ActivityMotionSpecs.json`.
struct ActivityMotionSpec: Codable, Sendable, Equatable {
    let code: String
    let template: ActivityMotionTemplate
    let prop: String
    let zhCue: String
    let enCue: String

    var cue: String { L10n.t(zhCue, enCue) }
}

/// Offline index mapping all 46 activity codes (`N01–N06`, `A01–A40`) to curated Montessori motion scripts.
enum ActivityMotionIndex {
    static let specsByCode: [String: ActivityMotionSpec] = {
        let bundles = [Bundle.main] + Bundle.allBundles
        for bundle in bundles {
            if let url = bundle.url(forResource: "ActivityMotionSpecs", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let items = try? JSONDecoder().decode([ActivityMotionSpec].self, from: data),
               !items.isEmpty {
                return Dictionary(uniqueKeysWithValues: items.map { ($0.code, $0) })
            }
        }
        return [:]
    }()

    static func spec(for play: Play) -> ActivityMotionSpec {
        if let found = specsByCode[play.code] {
            return found
        }
        let area = Palette.areaKey(of: play)
        let fallbackTemplate: ActivityMotionTemplate = switch area {
        case "A": .soundWave
        case "B": .tummyExplore
        case "D": .faceMirror
        case "F": .gentleHold
        default: .graspPass
        }
        return ActivityMotionSpec(
            code: play.code,
            template: fallbackTemplate,
            prop: "woodRing",
            zhCue: "放慢节奏，陪宝宝轻点试一试",
            enCue: "Slow down and explore together step by step"
        )
    }
}

/// Unified kinetic picture-book diagram stage: always displays each step's REAL illustrated diagram (`ArtIndex.steps`)
/// inside a crisp Scandinavian stitched paper spread with step-coupled kinetic crayon vector overlays & synchronous frame-1 loading.
struct ActivityMotionStage: View {
    let play: Play
    let stepIndex: Int
    let stepCount: Int
    var stepText: String = ""
    let companion: Kind
    var compact: Bool = false
    let dark: Bool

    @State private var pulseAt: Date = .distantPast
    @State private var pulseOrigin: CGPoint? = nil
    @State private var bounceTrigger: Int = 0
    @State private var stepDirection: Int = 1
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.displayScale) private var scale
    @Environment(\.girlArt) private var girl

    private var spec: ActivityMotionSpec {
        ActivityMotionIndex.spec(for: play)
    }

    private var stageColor: Color {
        Palette.area(Palette.areaKey(of: play))
    }

    nonisolated static func stepProgress(stepIndex: Int, stepCount: Int) -> CGFloat {
        guard stepCount > 1 else { return 0 }
        let clamped = min(max(stepIndex, 0), stepCount - 1)
        return CGFloat(clamped) / CGFloat(stepCount - 1)
    }

    nonisolated static func propSymbol(for prop: String, fallback: ActivityMotionTemplate) -> String {
        switch prop {
        case "bell", "chime", "rattle": return "bell.and.waves.left.and.right.fill"
        case "mirror": return "circle.lefthalf.filled"
        case "book", "card", "picture": return "book.pages.fill"
        case "block", "blocks", "tower": return "square.stack.3d.up.fill"
        case "cup", "bowl", "box", "basket": return "tray.fill"
        case "ball": return "circle.circle.fill"
        case "scarf", "blanket": return "wind"
        case "ring", "woodRing": return "circle.dashed"
        default:
            switch fallback {
            case .soundWave: return "waveform"
            case .faceMirror: return "sparkles"
            case .gentleHold: return "hands.and.sparkles.fill"
            case .tummyExplore: return "figure.play"
            case .graspPass: return "circle.dashed"
            case .tapContainer: return "cylinder.split.1x2.fill"
            case .stackBuild: return "square.stack.3d.up.fill"
            case .bookMatch: return "book.pages.fill"
            }
        }
    }

    var body: some View {
        let toneInk = dark ? stageColor.mix(with: .white, by: 0.25) : Crayon.ink(stageColor)
        let steps = ArtIndex.shared.steps(play.code)
        let artName = steps.isEmpty ? nil : steps[min(max(stepIndex, 0), steps.count - 1)]
        let action = StepKineticAction.infer(
            stepText: stepText.isEmpty ? spec.cue : stepText,
            stepIndex: stepIndex,
            stepCount: stepCount,
            template: spec.template
        )

        GeometryReader { geo in
            let px = max(420, Int(geo.size.width * scale))
            let img = artName.flatMap { name -> UIImage? in
                let shown = ArtIndex.variant(name, girl: girl)
                return Perf.noArt ? nil : (ArtCache.shared.cached(shown, maxPixel: px) ?? ArtCache.shared.image(shown, maxPixel: px))
            }

            ZStack(alignment: .bottom) {
                // Real step diagram page with smooth left/right page-turn transitions
                ZStack {
                    Color(hex: dark ? 0x161E3D : 0xFAF4E8)

                    if let img {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .id("\(play.code)-\(stepIndex)-\(ArtStyle.current.rawValue)")
                            .transition(
                                reduce
                                    ? .opacity
                                    : .asymmetric(
                                        insertion: .move(edge: stepDirection >= 0 ? .trailing : .leading).combined(with: .opacity),
                                        removal: .opacity
                                    )
                            )
                    } else {
                        TrayTile(code: play.code, color: stageColor, flat: ArtStyle.current == .flat)
                            .frame(width: 92, height: 92)
                    }

                    if dark {
                        Color(hex: 0x0A1026).opacity(0.24)
                    }

                    // Animated Scandinavian crayon kinetic diagram overlay (zero state mutation inside draw)
                    StepKineticOverlay(
                        action: action,
                        accent: stageColor,
                        dark: dark,
                        pulseAt: pulseAt,
                        pulseOrigin: pulseOrigin,
                        reduce: reduce
                    )
                    .allowsHitTesting(false)
                }
                .phaseAnimator(reduce ? [1.0] : [1.0, 1.022, 1.0], trigger: bounceTrigger) { view, scaleVal in
                    view.scaleEffect(scaleVal)
                }

                // Bottom picture-book caption bar: step-specific kinetic badge + Montessori step bead track
                HStack(alignment: .center, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: action.symbol)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(toneInk)
                        Text(action.label)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(dark ? Palette.lampInk : Palette.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill((dark ? Palette.lampCard : .white).opacity(0.92)))
                    .overlay(Capsule().strokeBorder(stageColor.opacity(dark ? 0.45 : 0.30), lineWidth: 0.85))

                    Spacer(minLength: 4)

                    if stepCount > 1 {
                        HStack(spacing: 4) {
                            ForEach(0..<stepCount, id: \.self) { idx in
                                let active = idx == stepIndex
                                let done = idx < stepIndex
                                Circle()
                                    .fill(active ? (companion == .moss ? Palette.mint : Palette.bead) : done ? Palette.bead.opacity(0.55) : Palette.secondaryText.opacity(0.30))
                                    .frame(width: active ? 7 : 5, height: active ? 7 : 5)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Capsule().fill((dark ? Palette.lampCard : .white).opacity(0.92)))
                        .overlay(Capsule().strokeBorder(stageColor.opacity(dark ? 0.40 : 0.24), lineWidth: 0.7))
                    }
                }
                .padding(10)
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let nx = geo.size.width > 0 ? value.location.x / geo.size.width : 0.5
                        let ny = geo.size.height > 0 ? value.location.y / geo.size.height : 0.48
                        pulseOrigin = CGPoint(x: nx, y: ny)
                        TactileEngine.shared.beadClick()
                        pulseAt = Date()
                        bounceTrigger += 1
                    }
            )
        }
        .aspectRatio(artName.map { ArtIndex.shared.ratio($0) } ?? (4.0 / 3.0), contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Radius.tile, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                .strokeBorder(stageColor.opacity(dark ? 0.38 : 0.28), style: StrokeStyle(lineWidth: 1.15, dash: [6, 4]))
        )
        .onChange(of: stepIndex) { oldVal, newVal in
            stepDirection = newVal >= oldVal ? 1 : -1
        }
        .accessibilityElement()
        .accessibilityLabel(L10n.t("第 \(stepIndex + 1) 步绘本示意：\(action.label)", "Step \(stepIndex + 1) kinetic illustration: \(action.label)"))
        .accessibilityHint(L10n.t("轻点画面重播动作示意", "Tap the illustration to replay the motion cue"))
    }
}

/// Pure vector kinetic picture-book diagram overlay tuned for clarity without obscuring Otto & Moss.
private struct StepKineticOverlay: View {
    let action: StepKineticAction
    let accent: Color
    let dark: Bool
    let pulseAt: Date
    let pulseOrigin: CGPoint?
    let reduce: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduce || Perf.still)) { tl in
            let now = tl.date
            let phase = (reduce || Perf.still) ? 0.56 : now.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.2) / 2.2
            let pulseAge = pulseAt == .distantPast ? 9.9 : max(0, now.timeIntervalSince(pulseAt))
            let pulseStrength = pulseAge < 0.9 ? (1.0 - pulseAge / 0.9) : 0.0

            Canvas { ctx, size in
                let w = size.width
                let h = size.height
                let crayonInk = (dark ? accent.mix(with: .white, by: 0.35) : Crayon.tangerine).opacity(0.72)

                switch action {
                case .offerArc:
                    // Gentle overhead arc showing offering / placing within reach
                    var arc = Path()
                    let p0 = CGPoint(x: w * 0.28, y: h * 0.28)
                    let p1 = CGPoint(x: w * 0.72, y: h * 0.31)
                    let ctrl = CGPoint(x: w * 0.50, y: h * 0.12)
                    arc.move(to: p0)
                    arc.addQuadCurve(to: p1, control: ctrl)
                    ctx.stroke(arc, with: .color(crayonInk), style: StrokeStyle(lineWidth: 2.6, lineCap: .round, dash: [7, 5]))
                    drawArrowHead(in: &ctx, at: p1, angle: atan2(p1.y - ctrl.y, p1.x - ctrl.x), color: crayonInk)
                    let t = CGFloat(phase)
                    let bx = (1 - t) * (1 - t) * p0.x + 2 * (1 - t) * t * ctrl.x + t * t * p1.x
                    let by = (1 - t) * (1 - t) * p0.y + 2 * (1 - t) * t * ctrl.y + t * t * p1.y
                    ctx.fill(Path(ellipseIn: CGRect(x: bx - 5, y: by - 5, width: 10, height: 10)), with: .color(Palette.bead))

                case .soundRipple:
                    let origin = CGPoint(x: w * 0.50, y: h * 0.26)
                    for i in 0..<3 {
                        let p = (phase + Double(i) * 0.33).truncatingRemainder(dividingBy: 1.0)
                        let r = CGFloat(12 + p * 32)
                        let alpha = (1.0 - p) * 0.65
                        ctx.stroke(
                            Path(ellipseIn: CGRect(x: origin.x - r, y: origin.y - r, width: r * 2, height: r * 2)),
                            with: .color(Crayon.lilac.opacity(alpha)),
                            lineWidth: 2.2
                        )
                    }

                case .sideSweep:
                    let y = h * 0.23
                    let leftPt = CGPoint(x: w * 0.30, y: y)
                    let rightPt = CGPoint(x: w * 0.70, y: y)
                    let ctrl = CGPoint(x: w * 0.50, y: y - 15)
                    var line = Path()
                    line.move(to: leftPt)
                    line.addQuadCurve(to: rightPt, control: ctrl)
                    ctx.stroke(line, with: .color(crayonInk), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [6, 5]))
                    drawArrowHead(in: &ctx, at: leftPt, angle: atan2(leftPt.y - ctrl.y, leftPt.x - ctrl.x), color: crayonInk)
                    drawArrowHead(in: &ctx, at: rightPt, angle: atan2(rightPt.y - ctrl.y, rightPt.x - ctrl.x), color: crayonInk)
                    let swing = CGFloat(0.5 - 0.5 * cos(phase * .pi * 2))
                    let x = w * (0.30 + 0.40 * swing)
                    let dy = sin(swing * .pi) * 7.5
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 5, y: y - dy - 5, width: 10, height: 10)), with: .color(Palette.bead))

                case .pauseWatch:
                    let center = CGPoint(x: w * 0.50, y: h * 0.24)
                    let r = CGFloat(14 + 5 * sin(phase * .pi * 2))
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                        with: .color(Crayon.sky.opacity(0.68)),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, dash: [4, 4])
                    )
                    ctx.fill(Path(ellipseIn: CGRect(x: center.x - 3.5, y: center.y - 3.5, width: 7, height: 7)), with: .color(Palette.beadLight))

                case .liftStack:
                    let cx = w * 0.50
                    let topPt = CGPoint(x: cx, y: h * 0.14)
                    var riser = Path()
                    riser.move(to: CGPoint(x: cx, y: h * 0.35))
                    riser.addLine(to: topPt)
                    ctx.stroke(riser, with: .color(crayonInk), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [5, 5]))
                    drawArrowHead(in: &ctx, at: topPt, angle: -.pi / 2, color: crayonInk)
                    let ty = h * (0.35 - 0.21 * phase)
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - 5, y: ty - 5, width: 10, height: 10)), with: .color(Palette.bead))

                case .gentleSway:
                    var wave = Path()
                    wave.move(to: CGPoint(x: w * 0.34, y: h * 0.25))
                    wave.addCurve(
                        to: CGPoint(x: w * 0.66, y: h * 0.25),
                        control1: CGPoint(x: w * 0.44, y: h * 0.18),
                        control2: CGPoint(x: w * 0.56, y: h * 0.32)
                    )
                    ctx.stroke(wave, with: .color(Crayon.mint.opacity(0.70)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [5, 4]))
                    let s = CGFloat(0.5 + 0.5 * sin(phase * .pi * 2))
                    let sx = w * (0.34 + 0.32 * s)
                    ctx.fill(Path(ellipseIn: CGRect(x: sx - 4.5, y: h * 0.25 - 4.5, width: 9, height: 9)), with: .color(Palette.beadLight))
                }

                // Interactive tap replay ring where finger touched
                if pulseStrength > 0.01 {
                    let origin = pulseOrigin ?? CGPoint(x: 0.5, y: 0.48)
                    let px = size.width * min(0.92, max(0.08, origin.x))
                    let py = size.height * min(0.88, max(0.12, origin.y))
                    let pr = CGFloat(14 + (1.0 - pulseStrength) * Double(min(w, h) * 0.32))
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: px - pr, y: py - pr, width: pr * 2, height: pr * 2)),
                        with: .color(Palette.bead.opacity(pulseStrength * 0.85)),
                        lineWidth: 2.6
                    )
                }
            }
        }
    }

    private func drawArrowHead(in ctx: inout GraphicsContext, at tip: CGPoint, angle: CGFloat, color: Color) {
        let spread: CGFloat = .pi - 0.52
        let len: CGFloat = 7.5
        var head = Path()
        head.move(to: CGPoint(x: tip.x + cos(angle + spread) * len, y: tip.y + sin(angle + spread) * len))
        head.addLine(to: tip)
        head.addLine(to: CGPoint(x: tip.x + cos(angle - spread) * len, y: tip.y + sin(angle - spread) * len))
        ctx.stroke(head, with: .color(color), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
    }
}
