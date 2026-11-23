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

/// Picture-book stop-motion stage pairing bespoke miniature diorama plates (or 2D paper illustrations in flat mode)
/// with live dust motes, step-coupled camera framing & Montessori bead track, companion-coupled touch ripples, and prop cues.
struct ActivityMotionStage: View {
    let play: Play
    let stepIndex: Int
    let stepCount: Int
    let companion: Kind
    var compact: Bool = false
    let dark: Bool

    @State private var pulseAt: Date = .distantPast
    @State private var pulseOrigin: CGPoint? = nil
    @State private var bounceTrigger: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduce

    private var spec: ActivityMotionSpec {
        ActivityMotionIndex.spec(for: play)
    }

    private var stageColor: Color {
        Palette.area(Palette.areaKey(of: play))
    }

    private var height: CGFloat {
        compact ? 184 : 224
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
        let plate = StoryPlate.forTemplate(spec.template)
        let progress = Self.stepProgress(stepIndex: stepIndex, stepCount: stepCount)
        let flatSteps = ArtStyle.current == .flat ? ArtIndex.shared.steps(play.code) : []
        let flatArtName = flatSteps.isEmpty ? nil : flatSteps[min(max(stepIndex, 0), flatSteps.count - 1)]

        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Group {
                    if let flatArtName {
                        ArtFill(name: flatArtName, label: L10n.t("共玩绘本场景：\(spec.zhCue)", "Storybook co-play diorama: \(spec.enCue)"))
                    } else {
                        LivingStoryPlateView(
                            plate: plate,
                            dark: dark,
                            alive: true,
                            pulseAt: pulseAt,
                            pulseOrigin: pulseOrigin,
                            stepProgress: progress,
                            companion: companion,
                            accessibilityLabel: L10n.t("共玩绘本场景：\(spec.zhCue)", "Storybook co-play diorama: \(spec.enCue)")
                        )
                    }
                }
                .phaseAnimator(reduce ? [1.0] : [1.0, 1.022, 1.0], trigger: bounceTrigger) { view, scale in
                    view.scaleEffect(scale)
                }

                // Bottom matte ribbon: quiet prop/cue pill on the leading side + Montessori step bead track on trailing
                HStack(alignment: .center, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: Self.propSymbol(for: spec.prop, fallback: spec.template))
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
                            .fill((dark ? Palette.lampCard : .white).opacity(0.92))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(stageColor.opacity(dark ? 0.45 : 0.30), lineWidth: 0.8)
                    )

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
                        .background(
                            Capsule()
                                .fill((dark ? Palette.lampCard : .white).opacity(0.90))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(stageColor.opacity(dark ? 0.40 : 0.24), lineWidth: 0.7)
                        )
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
                        TactileEngine.shared.vinylPop()
                        pulseAt = Date()
                        bounceTrigger += 1
                    }
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                .strokeBorder(stageColor.opacity(dark ? 0.32 : 0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t("共玩绘本场景，第 \(stepIndex + 1) 步，共 \(max(1, stepCount)) 步：\(spec.zhCue)", "Storybook co-play diorama, step \(stepIndex + 1) of \(max(1, stepCount)): \(spec.enCue)"))
        .accessibilityHint(L10n.t("轻点画面可与 \(companion.rawValue) 互动", "Tap the illustration to play with \(companion.rawValue)"))
    }
}
