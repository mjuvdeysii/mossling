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

/// Picture-book stop-motion stage pairing bespoke miniature diorama plates with live dust motes, gentle parallax breath,
/// interactive touch ripples, and a quiet rhythm caption below Moss & Otto.
struct ActivityMotionStage: View {
    let play: Play
    let stepIndex: Int
    let stepCount: Int
    let companion: Kind
    var compact: Bool = false
    let dark: Bool

    @State private var pulseAt: Date = .distantPast
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

    var body: some View {
        let toneInk = dark ? stageColor.mix(with: .white, by: 0.25) : Crayon.ink(stageColor)
        let plate = StoryPlate.forTemplate(spec.template)

        ZStack(alignment: .bottomLeading) {
            LivingStoryPlateView(
                plate: plate,
                dark: dark,
                alive: true,
                pulseAt: pulseAt,
                accessibilityLabel: L10n.t("共玩绘本场景：\(spec.zhCue)", "Storybook co-play diorama: \(spec.enCue)")
            )
            .phaseAnimator(reduce ? [1.0] : [1.0, 1.022, 1.0], trigger: bounceTrigger) { view, scale in
                view.scaleEffect(scale)
            }

            // Quiet tactile cue whisper pinned to the corner of the matte frame
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
                    .fill((dark ? Palette.lampCard : .white).opacity(0.92))
            )
            .overlay(
                Capsule()
                    .strokeBorder(stageColor.opacity(dark ? 0.45 : 0.30), lineWidth: 0.8)
            )
            .padding(10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                .strokeBorder(stageColor.opacity(dark ? 0.32 : 0.22), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            TactileEngine.shared.vinylPop()
            pulseAt = Date()
            bounceTrigger += 1
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t("共玩绘本场景：\(spec.zhCue)", "Storybook co-play diorama: \(spec.enCue)"))
        .accessibilityHint(L10n.t("轻点画面可触发光晕回弹", "Tap the illustration for a gentle golden light pulse"))
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
}
