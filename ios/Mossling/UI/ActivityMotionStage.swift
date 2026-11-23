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

/// Interactive Montessori layered motion stage pairing live 3D/2D `Moss` & `Otto` with pure-vector wooden & linen props
/// customized for each of the 46 activities and responsive to both the active step and touch taps.
struct ActivityMotionStage: View {
    let play: Play
    let stepIndex: Int
    let stepCount: Int
    let companion: Kind
    var compact: Bool = false
    let dark: Bool

    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var pulseAt: Date = .distantPast
    @State private var tapNotice: Int = 0

    private var spec: ActivityMotionSpec {
        ActivityMotionIndex.spec(for: play)
    }

    private var stageColor: Color {
        Palette.area(Palette.areaKey(of: play))
    }

    private var height: CGFloat {
        compact ? 176 : 210
    }

    var body: some View {
        let stepFrac = stepCount > 1
            ? Double(min(stepIndex, stepCount - 1)) / Double(max(1, stepCount - 1))
            : 0.5
        let toneInk = dark ? stageColor.mix(with: .white, by: 0.25) : Crayon.ink(stageColor)

        ZStack(alignment: .bottomLeading) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduce || Perf.still)) { tl in
                let now = (reduce || Perf.still) ? Date(timeIntervalSinceReferenceDate: 1.4 + Double(stepIndex) * 0.7) : tl.date
                let time = now.timeIntervalSinceReferenceDate
                let pulseAge = max(0, min(1.2, now.timeIntervalSince(pulseAt)))
                let pulseIntensity = pulseAt == .distantPast ? 0.0 : max(0, 1.0 - pulseAge / 1.1)

                ZStack {
                    // Backdrop wash & Montessori woven mat stage
                    stageCanvas(time: time, stepFrac: stepFrac, pulseIntensity: pulseIntensity, now: now)

                    // Companions positioned carefully per template while never overlapping props
                    companionLayer(time: time, stepFrac: stepFrac, pulseIntensity: pulseIntensity)
                }
            }

            // Quiet tactile cue whisper on the card frame (never a speech bubble on creatures!)
            HStack(spacing: 6) {
                Image(systemName: templateSymbol)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(toneInk)
                Text(spec.cue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(dark ? Palette.lampInk : Palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill((dark ? Palette.lampCard : .white).opacity(0.90))
            )
            .overlay(
                Capsule()
                    .strokeBorder(stageColor.opacity(dark ? 0.45 : 0.28), lineWidth: 0.8)
            )
            .padding(10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                .strokeBorder(stageColor.opacity(dark ? 0.30 : 0.18), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            TactileEngine.shared.vinylPop()
            pulseAt = Date()
            tapNotice += 1
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t("共玩动态示范：\(spec.zhCue)", "Interactive play demo: \(spec.enCue)"))
        .accessibilityHint(L10n.t("轻点可触发一次轻快互动回弹", "Tap for a gentle interactive bounce"))
    }

    private var templateSymbol: String {
        switch spec.template {
        case .soundWave: "waveform"
        case .faceMirror: "sparkles"
        case .gentleHold: "hands.and.sparkles.fill"
        case .tummyExplore: "figure.play"
        case .graspPass: "circle.dashed"
        case .tapContainer: "cylinder.split.1x2.fill"
        case .stackBuild: "square.stack.3d.up.fill"
        case .bookMatch: "book.pages.fill"
        }
    }

    // MARK: - Live Companions Layer (Honors 3D Vinyl & 2D Cut-Paper Styles)

    @ViewBuilder
    private func companionLayer(time: TimeInterval, stepFrac: Double, pulseIntensity: Double) -> some View {
        let sway = sin(time * 1.45)
        let mossSize: CGFloat = compact ? 52 : 60
        let ottoSize: CGFloat = compact ? 58 : 66
        let bounceOffset = -CGFloat(pulseIntensity * 10 * sin(pulseIntensity * .pi))

        switch spec.template {
        case .soundWave:
            HStack {
                Creature(kind: .otto, mood: .open, look: CGPoint(x: 0.65, y: -0.1), alive: !reduce, glow: true)
                    .frame(width: ottoSize, height: ottoSize)
                Spacer()
                Creature(kind: .moss, mood: pulseIntensity > 0.1 ? .happy : .open, look: CGPoint(x: -0.7, y: -0.15 + sway * 0.2), alive: !reduce, poke: true, notice: tapNotice)
                    .frame(width: mossSize, height: mossSize)
                    .offset(y: bounceOffset)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 16)

        case .faceMirror:
            HStack {
                Creature(kind: .otto, mood: .open, look: CGPoint(x: 0.55, y: 0), alive: !reduce)
                    .frame(width: ottoSize * 0.9, height: ottoSize * 0.9)
                    .offset(y: 4)
                Spacer()
                Creature(kind: .moss, mood: sway > 0 || pulseIntensity > 0.1 ? .happy : .wow, look: CGPoint(x: -0.5, y: 0), alive: !reduce, poke: true, notice: tapNotice)
                    .frame(width: mossSize, height: mossSize)
                    .offset(y: bounceOffset)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 18)

        case .gentleHold:
            HStack(spacing: -8) {
                Creature(kind: .otto, mood: .open, look: CGPoint(x: 0.4, y: 0.2), alive: !reduce, glow: true)
                    .frame(width: ottoSize, height: ottoSize)
                Creature(kind: .moss, mood: .happy, look: CGPoint(x: -0.35, y: -0.1), alive: !reduce, poke: true, notice: tapNotice)
                    .frame(width: mossSize * 0.92, height: mossSize * 0.92)
                    .offset(y: CGFloat(sin(time * 1.1) * 3) + bounceOffset)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 18)

        case .tummyExplore:
            HStack {
                Creature(kind: .moss, mood: .open, look: CGPoint(x: CGFloat(sin(time * 0.95) * 0.75), y: -0.2), alive: !reduce, poke: true, notice: tapNotice)
                    .frame(width: mossSize, height: mossSize)
                    .offset(x: CGFloat(sin(time * 0.85) * 6), y: 2 + bounceOffset)
                Spacer()
                Creature(kind: .otto, mood: .open, look: CGPoint(x: -0.65, y: 0.15), alive: !reduce, glow: true)
                    .frame(width: ottoSize * 0.88, height: ottoSize * 0.88)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)

        case .graspPass:
            let lookDir = CGPoint(x: CGFloat(-cos(time * 1.35) * 0.7), y: -0.1)
            HStack {
                Creature(kind: .otto, mood: .open, look: lookDir, alive: !reduce)
                    .frame(width: ottoSize * 0.92, height: ottoSize * 0.92)
                Spacer()
                Creature(kind: .moss, mood: pulseIntensity > 0.1 ? .happy : .open, look: CGPoint(x: -0.7, y: 0), alive: !reduce, poke: true, notice: tapNotice)
                    .frame(width: mossSize, height: mossSize)
                    .offset(y: bounceOffset)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 16)

        case .tapContainer:
            HStack {
                Creature(kind: .moss, mood: pulseIntensity > 0.1 ? .happy : .wow, look: CGPoint(x: 0.75, y: 0.15), alive: !reduce, poke: true, notice: tapNotice)
                    .frame(width: mossSize, height: mossSize)
                    .offset(y: bounceOffset)
                Spacer()
                Creature(kind: .otto, mood: .open, look: CGPoint(x: -0.75, y: 0.2), alive: !reduce)
                    .frame(width: ottoSize * 0.9, height: ottoSize * 0.9)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 16)

        case .stackBuild:
            HStack {
                Creature(kind: .moss, mood: stepFrac > 0.6 ? .happy : .open, look: CGPoint(x: 0.75, y: -0.35), alive: !reduce, poke: true, notice: tapNotice)
                    .frame(width: mossSize, height: mossSize)
                    .offset(y: bounceOffset)
                Spacer()
                Creature(kind: .otto, mood: .open, look: CGPoint(x: -0.7, y: -0.2), alive: !reduce, glow: true)
                    .frame(width: ottoSize * 0.92, height: ottoSize * 0.92)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

        case .bookMatch:
            HStack {
                Creature(kind: .moss, mood: .open, look: CGPoint(x: 0.65, y: 0.2), alive: !reduce, poke: true, notice: tapNotice)
                    .frame(width: mossSize, height: mossSize)
                    .offset(y: bounceOffset)
                Spacer()
                Creature(kind: .otto, mood: .open, look: CGPoint(x: -0.7, y: 0.15), alive: !reduce, glow: true)
                    .frame(width: ottoSize * 0.9, height: ottoSize * 0.9)
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 18)
        }
    }

    // MARK: - Pure Vector Montessori Physics Stage (Zero State Mutation!)

    private func stageCanvas(time: TimeInterval, stepFrac: Double, pulseIntensity: Double, now: Date) -> some View {
        let tone = stageColor
        let prop = spec.prop
        let template = spec.template
        let darkMode = dark

        return Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let midX = w * 0.5
            let horizonY = h * 0.64

            // 1. Soft watercolor wash & warm play-mat floor
            let skyColors = darkMode
                ? [Color(hex: 0x161E3C), tone.opacity(0.18), Color(hex: 0x0F152D)]
                : [tone.opacity(0.14), Palette.paper, tone.opacity(0.08)]
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(Gradient(colors: skyColors), startPoint: CGPoint(x: midX, y: 0), endPoint: CGPoint(x: midX, y: h))
            )

            // Woven linen nursery mat arc
            var mat = Path()
            mat.move(to: CGPoint(x: 0, y: horizonY + 12))
            mat.addQuadCurve(to: CGPoint(x: w, y: horizonY + 12), control: CGPoint(x: midX, y: horizonY - 12))
            mat.addLine(to: CGPoint(x: w, y: h))
            mat.addLine(to: CGPoint(x: 0, y: h))
            mat.closeSubpath()
            ctx.fill(mat, with: .color(darkMode ? Color(hex: 0x1E274B) : Color(hex: 0xF5EFE3)))
            ctx.stroke(mat, with: .color(tone.opacity(darkMode ? 0.25 : 0.22)), lineWidth: 1.2)

            // 2. Interactive tap golden pulse halo
            if pulseIntensity > 0.01 {
                let r = CGFloat((1.0 - pulseIntensity) * Double(min(w, h) * 0.45) + 18)
                var ring = Path()
                ring.addEllipse(in: CGRect(x: midX - r, y: h * 0.46 - r, width: r * 2, height: r * 2))
                ctx.stroke(ring, with: .color(Palette.bead.opacity(pulseIntensity * 0.55)), lineWidth: 2.5)
            }

            // 3. Template-specific physical Montessori props
            let centerY = h * 0.44
            let woodLight = Color(hex: 0xE6C394)
            let woodMid = Color(hex: 0xC99962)
            let woodDark = Color(hex: 0x8F6235)
            let outlineCol = darkMode ? Color.white.opacity(0.22) : Color(hex: 0x4A3A28).opacity(0.32)

            switch template {
            case .soundWave:
                // Concentric acoustic waves drifting across from lantern/bell to Moss
                for i in 0..<4 {
                    let phase = (time * 0.62 + Double(i) * 0.25).truncatingRemainder(dividingBy: 1.0)
                    let radius = 14.0 + phase * Double(min(w, h) * 0.34)
                    let alpha = (1.0 - phase) * (0.46 + pulseIntensity * 0.35)
                    var wave = Path()
                    wave.addEllipse(in: CGRect(x: midX - radius, y: centerY - radius * 0.72, width: radius * 2, height: radius * 1.44))
                    ctx.stroke(wave, with: .color((i % 2 == 0 ? tone : Palette.bead).opacity(alpha)), lineWidth: 2.2 - phase * 1.1)
                }

                // Suspended Montessori wooden chime bell or glowing bead at center
                let swing = sin(time * 2.2) * (10 + pulseIntensity * 14)
                let bellCenter = CGPoint(x: midX + swing, y: centerY)
                var cord = Path()
                cord.move(to: CGPoint(x: midX, y: 0))
                cord.addQuadCurve(to: bellCenter, control: CGPoint(x: midX + swing * 0.35, y: centerY * 0.5))
                ctx.stroke(cord, with: .color(woodDark.opacity(0.5)), lineWidth: 1.5)

                if prop == "bell" {
                    let bellRect = CGRect(x: bellCenter.x - 15, y: bellCenter.y - 14, width: 30, height: 26)
                    let bellPath = RoundedRectangle(cornerRadius: 12, style: .continuous).path(in: bellRect)
                    ctx.fill(bellPath, with: .linearGradient(Gradient(colors: [woodLight, woodMid]), startPoint: CGPoint(x: bellRect.midX, y: bellRect.minY), endPoint: CGPoint(x: bellRect.midX, y: bellRect.maxY)))
                    ctx.stroke(bellPath, with: .color(outlineCol), lineWidth: 1)
                    var clapper = Path()
                    clapper.addEllipse(in: CGRect(x: bellCenter.x - 5 + swing * 0.15, y: bellCenter.y + 8, width: 10, height: 10))
                    ctx.fill(clapper, with: .color(Palette.bead))
                } else {
                    var glowBead = Path()
                    glowBead.addEllipse(in: CGRect(x: bellCenter.x - 14, y: bellCenter.y - 14, width: 28, height: 28))
                    ctx.fill(glowBead, with: .radialGradient(Gradient(colors: [Palette.beadLight, Palette.bead, tone.opacity(0.8)]), center: CGPoint(x: bellCenter.x - 4, y: bellCenter.y - 4), startRadius: 2, endRadius: 18))
                }

            case .faceMirror:
                // Beechwood hand mirror or gentle linen peekaboo veil
                let mRadius: CGFloat = 34
                let mirrorRect = CGRect(x: midX - mRadius, y: centerY - mRadius, width: mRadius * 2, height: mRadius * 2)
                var frame = Path()
                frame.addEllipse(in: mirrorRect.insetBy(dx: -6, dy: -6))
                ctx.fill(frame, with: .linearGradient(Gradient(colors: [woodLight, woodMid]), startPoint: CGPoint(x: mirrorRect.minX, y: mirrorRect.minY), endPoint: CGPoint(x: mirrorRect.maxX, y: mirrorRect.maxY)))
                ctx.stroke(frame, with: .color(outlineCol), lineWidth: 1.2)

                var glass = Path()
                glass.addEllipse(in: mirrorRect)
                ctx.fill(glass, with: .linearGradient(Gradient(colors: [Color(hex: 0xEAF4FA), Color(hex: 0xCFE4F2)]), startPoint: CGPoint(x: mirrorRect.minX, y: mirrorRect.minY), endPoint: CGPoint(x: mirrorRect.maxX, y: mirrorRect.maxY)))

                // Specular diagonal shimmer sweep
                let sweep = CGFloat((sin(time * 1.4) + 1) * 0.5) * mRadius * 1.3 - mRadius * 0.65
                var gleam = Path()
                gleam.move(to: CGPoint(x: midX - 24 + sweep, y: centerY - 22))
                gleam.addLine(to: CGPoint(x: midX - 10 + sweep, y: centerY - 22))
                gleam.addLine(to: CGPoint(x: midX - 26 + sweep, y: centerY + 22))
                gleam.addLine(to: CGPoint(x: midX - 38 + sweep, y: centerY + 22))
                gleam.closeSubpath()
                ctx.fill(gleam, with: .color(.white.opacity(0.65)))

                if prop == "peekCloth" {
                    let lift = (sin(time * 1.5) * 0.5 + 0.5) * 38
                    let veilRect = CGRect(x: midX - 40, y: centerY - 36 - lift, width: 80, height: 64)
                    let veil = RoundedRectangle(cornerRadius: 14, style: .continuous).path(in: veilRect)
                    ctx.fill(veil, with: .color(Crayon.peach.opacity(0.88)))
                    ctx.stroke(veil, with: .color(Crayon.tangerine.opacity(0.45)), lineWidth: 1.2)
                }

            case .gentleHold:
                // Warm soothing infinity cradle arc & heartbeat halo
                let breath = 0.5 + 0.5 * sin(time * 1.55)
                let haloR = 32.0 + breath * 22.0 + pulseIntensity * 12.0
                var halo = Path()
                halo.addEllipse(in: CGRect(x: midX - haloR, y: h * 0.46 - haloR * 0.8, width: haloR * 2, height: haloR * 1.6))
                ctx.fill(halo, with: .radialGradient(Gradient(colors: [Palette.amber.opacity(0.28), Palette.amber.opacity(0.0)]), center: CGPoint(x: midX, y: h * 0.46), startRadius: 4, endRadius: haloR))

                // Soft blanket ribbon swaying underneath
                var ribbon = Path()
                let dip = CGFloat(sin(time * 1.1) * 7)
                ribbon.move(to: CGPoint(x: midX - 88, y: horizonY - 4))
                ribbon.addQuadCurve(to: CGPoint(x: midX + 88, y: horizonY - 4), control: CGPoint(x: midX, y: horizonY + 18 + dip))
                ctx.stroke(ribbon, with: .color(Crayon.pink.opacity(0.55)), style: StrokeStyle(lineWidth: 6, lineCap: .round))

            case .tummyExplore:
                // Rolling bright wooden sphere & dotted path encouraging head lift
                let rollT = sin(time * 1.1)
                let bx = midX + CGFloat(rollT * 58)
                let by = horizonY - 12 - CGFloat(abs(cos(time * 1.1)) * 4)

                var trail = Path()
                trail.move(to: CGPoint(x: midX - 66, y: horizonY - 6))
                trail.addQuadCurve(to: CGPoint(x: midX + 66, y: horizonY - 6), control: CGPoint(x: midX, y: horizonY - 18))
                ctx.stroke(trail, with: .color(tone.opacity(0.35)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5]))

                let ballRect = CGRect(x: bx - 15, y: by - 15, width: 30, height: 30)
                var ball = Path()
                ball.addEllipse(in: ballRect)
                ctx.fill(ball, with: .radialGradient(Gradient(colors: [Palette.beadLight, Palette.bead, woodMid]), center: CGPoint(x: bx - 5, y: by - 5), startRadius: 2, endRadius: 18))
                ctx.stroke(ball, with: .color(outlineCol), lineWidth: 1)

            case .graspPass:
                // Midline arc: Montessori beech ring / soft coral ball passing smoothly left <-> right
                let arcU = 0.5 - 0.5 * cos(time * 1.45)
                let startP = CGPoint(x: midX - 66, y: h * 0.50)
                let endP = CGPoint(x: midX + 66, y: h * 0.50)
                let ctrl = CGPoint(x: midX, y: h * 0.14)

                var arcPath = Path()
                arcPath.move(to: startP)
                arcPath.addQuadCurve(to: endP, control: ctrl)
                ctx.stroke(arcPath, with: .color(tone.opacity(0.32)), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 6]))

                // Quad bezier interpolation
                let u = CGFloat(arcU)
                let inv = 1 - u
                let px = inv * inv * startP.x + 2 * inv * u * ctrl.x + u * u * endP.x
                let py = inv * inv * startP.y + 2 * inv * u * ctrl.y + u * u * endP.y

                if prop == "softBall" {
                    let r: CGFloat = 16 + CGFloat(pulseIntensity * 3)
                    var b = Path()
                    b.addEllipse(in: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
                    ctx.fill(b, with: .radialGradient(Gradient(colors: [Crayon.peach, tone]), center: CGPoint(x: px - 4, y: py - 4), startRadius: 2, endRadius: r + 2))
                    ctx.stroke(b, with: .color(outlineCol), lineWidth: 1)
                } else {
                    let r: CGFloat = 17
                    var ring = Path()
                    ring.addEllipse(in: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
                    ctx.stroke(ring, with: .linearGradient(Gradient(colors: [woodLight, woodMid]), startPoint: CGPoint(x: px - r, y: py - r), endPoint: CGPoint(x: px + r, y: py + r)), lineWidth: 8)
                    ctx.stroke(ring, with: .color(outlineCol), lineWidth: 1)
                }

            case .tapContainer:
                // Beechwood Montessori cup & rhythmic bead drop + wooden ripple
                let cupRect = CGRect(x: midX - 24, y: horizonY - 32, width: 48, height: 34)
                var cup = Path()
                cup.move(to: CGPoint(x: cupRect.minX, y: cupRect.minY))
                cup.addLine(to: CGPoint(x: cupRect.minX + 6, y: cupRect.maxY))
                cup.addQuadCurve(to: CGPoint(x: cupRect.maxX - 6, y: cupRect.maxY), control: CGPoint(x: midX, y: cupRect.maxY + 6))
                cup.addLine(to: CGPoint(x: cupRect.maxX, y: cupRect.minY))
                cup.closeSubpath()
                ctx.fill(cup, with: .linearGradient(Gradient(colors: [woodLight, woodMid]), startPoint: CGPoint(x: cupRect.minX, y: cupRect.midY), endPoint: CGPoint(x: cupRect.maxX, y: cupRect.midY)))
                ctx.stroke(cup, with: .color(outlineCol), lineWidth: 1.1)

                var rim = Path()
                rim.addEllipse(in: CGRect(x: cupRect.minX, y: cupRect.minY - 5, width: cupRect.width, height: 10))
                ctx.fill(rim, with: .color(woodDark.opacity(0.65)))
                ctx.stroke(rim, with: .color(woodLight), lineWidth: 1.4)

                // Dropping golden wooden bead
                let dropCycle = (time * 0.72).truncatingRemainder(dividingBy: 1.0)
                let beadY = dropCycle < 0.7
                    ? (h * 0.14 + CGFloat(pow(dropCycle / 0.7, 2.0)) * (cupRect.minY - h * 0.14))
                    : cupRect.minY
                let fade = dropCycle > 0.75 ? max(0, 1.0 - (dropCycle - 0.75) / 0.25) : 1.0
                var bead = Path()
                bead.addEllipse(in: CGRect(x: midX - 10, y: beadY - 10, width: 20, height: 20))
                ctx.fill(bead, with: .color(Palette.bead.opacity(fade)))
                ctx.stroke(bead, with: .color(outlineCol.opacity(fade)), lineWidth: 1)

                if dropCycle >= 0.68 {
                    let rp = (dropCycle - 0.68) / 0.32
                    var impact = Path()
                    impact.addEllipse(in: CGRect(x: midX - 24 - rp * 20, y: cupRect.minY - 6 - rp * 6, width: 48 + rp * 40, height: 12 + rp * 12))
                    ctx.stroke(impact, with: .color(Palette.bead.opacity((1 - rp) * 0.7)), lineWidth: 1.8)
                }

            case .stackBuild:
                // Graduated Montessori wooden blocks building higher with each step!
                let baseBlocks: [(w: CGFloat, h: CGFloat, col: Color)] = [
                    (66, 20, woodLight),
                    (52, 18, Crayon.teal.opacity(0.82)),
                    (38, 17, Palette.bead),
                    (26, 15, Crayon.peach)
                ]
                let visibleCount = max(2, min(baseBlocks.count, 2 + Int(round(stepFrac * 2))))
                var curY = horizonY + 2
                let floatTop = sin(time * 2.1) * 4

                for i in 0..<visibleCount {
                    let blk = baseBlocks[i]
                    let isTop = (i == visibleCount - 1)
                    let yOff: CGFloat = isTop ? CGFloat(floatTop - pulseIntensity * 6) : 0
                    let rect = CGRect(x: midX - blk.w / 2, y: curY - blk.h + yOff, width: blk.w, height: blk.h)
                    let p = RoundedRectangle(cornerRadius: 5, style: .continuous).path(in: rect)
                    ctx.fill(p, with: .linearGradient(Gradient(colors: [blk.col.mix(with: .white, by: 0.16), blk.col]), startPoint: CGPoint(x: rect.midX, y: rect.minY), endPoint: CGPoint(x: rect.midX, y: rect.maxY)))
                    ctx.stroke(p, with: .color(outlineCol), lineWidth: 1)
                    curY -= (blk.h + 2)
                }

            case .bookMatch:
                // Linen picture book / botanical leaf / crayon stroke
                if prop == "crayon" {
                    var scribble = Path()
                    let progress = 0.25 + 0.75 * (0.5 + 0.5 * sin(time * 1.15))
                    scribble.move(to: CGPoint(x: midX - 54, y: centerY + 12))
                    scribble.addCurve(
                        to: CGPoint(x: midX + 54 * progress, y: centerY - 6 + sin(time * 2) * 10),
                        control1: CGPoint(x: midX - 18, y: centerY - 24),
                        control2: CGPoint(x: midX + 18, y: centerY + 28)
                    )
                    ctx.stroke(scribble, with: .color(Crayon.tangerine), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                } else {
                    // Open sturdy cardboard book with animated page flip shimmer
                    let spreadRect = CGRect(x: midX - 52, y: centerY - 26, width: 104, height: 64)
                    let leftPage = RoundedRectangle(cornerRadius: 8, style: .continuous).path(in: CGRect(x: spreadRect.minX, y: spreadRect.minY, width: 51, height: 64))
                    let rightPage = RoundedRectangle(cornerRadius: 8, style: .continuous).path(in: CGRect(x: midX + 1, y: spreadRect.minY, width: 51, height: 64))
                    ctx.fill(leftPage, with: .color(Color(hex: 0xFFFDF8)))
                    ctx.fill(rightPage, with: .color(Color(hex: 0xF7EFE1)))
                    ctx.stroke(leftPage, with: .color(woodMid.opacity(0.6)), lineWidth: 1.4)
                    ctx.stroke(rightPage, with: .color(woodMid.opacity(0.6)), lineWidth: 1.4)

                    // Tiny geometric illustration inside book + floating point dot
                    var sun = Path()
                    sun.addEllipse(in: CGRect(x: spreadRect.minX + 14, y: spreadRect.minY + 16, width: 22, height: 22))
                    ctx.fill(sun, with: .color(Palette.bead))
                    var leaf = Path()
                    leaf.addEllipse(in: CGRect(x: midX + 14, y: spreadRect.minY + 20, width: 22, height: 22))
                    ctx.fill(leaf, with: .color(Crayon.leaf.opacity(0.85)))

                    let lift = (0.5 + 0.5 * sin(time * 1.5)) * 18
                    var turning = Path()
                    turning.move(to: CGPoint(x: midX, y: spreadRect.maxY - 2))
                    turning.addQuadCurve(to: CGPoint(x: midX + 26 - lift, y: spreadRect.minY + 4), control: CGPoint(x: midX + 14, y: centerY - 12))
                    ctx.stroke(turning, with: .color(tone.opacity(0.55)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                }
            }
            _ = now
        }
    }
}
