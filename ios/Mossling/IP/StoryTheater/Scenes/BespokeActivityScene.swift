import SwiftUI

// MARK: - Bespoke Independent Activity Scene Registry & Context

enum BespokeActivityID: String, CaseIterable, Sendable {
    case n01, n02, n03, n04, n05, n06
    case a01, a02, a03, a04
    case a05, a06, a07, a08, a09, a10, a11, a12, a13, a14
    case a15, a16, a17, a18, a19, a20, a21, a22, a23, a24
    case a25, a26, a27, a28, a29, a30, a31, a32
    case a33, a34, a35, a36, a37, a38, a39, a40

    var code: String {
        rawValue.uppercased()
    }
}

struct BespokeSceneContext: Sendable {
    let code: String
    let stepIndex: Int
    let phase: LivingPhaseSample
    let breathTime: Double
    let stageSize: CGSize
    let dark: Bool
    let flat: Bool
    let isStatic: Bool
    let compact: Bool
    let tapOrigin: CGPoint?
    let tapStrength: Double

    var shaderEnabled: Bool {
        !compact && stageSize.width >= 80 && stageSize.height >= 60
    }
}

struct BespokeSceneMetadata: Sendable {
    let id: BespokeActivityID
    let cameraGrammar: String
    let durations: [Double]
    let posterPhases: [Double]
    let audioAnchors: [LivingAudioAnchor]
    let lightKeyNormalized: CGPoint
    let ottoBeadNormalized: CGPoint
    let propTargetNormalized: CGPoint
    let komorebiStrength: Double
}

enum BespokeActivitySceneRegistry {
    static let registeredCodes: Set<String> = Set(BespokeActivityID.allCases.map(\.code))

    static func id(for code: String) -> BespokeActivityID? {
        BespokeActivityID(rawValue: code.lowercased())
    }

    static func hasBespokeScene(for code: String) -> Bool {
        id(for: code) != nil
    }

    static func metadata(for code: String) -> BespokeSceneMetadata? {
        guard let id = id(for: code) else { return nil }
        return metadata(for: id)
    }

    static func lightAnchors(for id: BespokeActivityID, step: Int, stageSize: CGSize) -> (key: CGPoint, bead: CGPoint, target: CGPoint) {
        let meta = metadata(for: id)
        let w = stageSize.width
        let h = stageSize.height
        var targetNorm = meta.propTargetNormalized
        var beadNorm = meta.ottoBeadNormalized
        if id == .a13 {
            targetNorm = CGPoint(x: step >= 2 ? 0.59 : 0.40, y: meta.propTargetNormalized.y)
        } else if id == .a14 {
            targetNorm = CGPoint(x: step == 0 ? 0.48 : 0.53, y: meta.propTargetNormalized.y)
        } else if id == .a29 {
            let bx: CGFloat = switch step {
            case 0: 0.24
            case 1: 0.30
            case 2: 0.24
            default: 0.56
            }
            beadNorm = CGPoint(x: bx, y: meta.ottoBeadNormalized.y)
            targetNorm = CGPoint(x: step == 3 ? 0.74 : 0.56, y: meta.propTargetNormalized.y)
        }
        return (
            key: CGPoint(x: w * meta.lightKeyNormalized.x, y: h * meta.lightKeyNormalized.y),
            bead: CGPoint(x: w * beadNorm.x, y: h * beadNorm.y),
            target: CGPoint(x: w * targetNorm.x, y: h * targetNorm.y)
        )
    }

    static func metadata(for id: BespokeActivityID) -> BespokeSceneMetadata {
        switch id {
        case .n01:
            return BespokeSceneMetadata(
                id: .n01,
                cameraGrammar: "closeup-feeding-alcove",
                durations: [4.6, 4.4, 4.8],
                posterPhases: [0.56, 0.54, 0.62],
                audioAnchors: [.softChime, .none, .softChime],
                lightKeyNormalized: CGPoint(x: 0.78, y: 0.16),
                ottoBeadNormalized: CGPoint(x: 0.31, y: 0.43),
                propTargetNormalized: CGPoint(x: 0.68, y: 0.64),
                komorebiStrength: 0.72
            )
        case .n02:
            return BespokeSceneMetadata(
                id: .n02,
                cameraGrammar: "window-seat-two-shot",
                durations: [4.5, 4.8],
                posterPhases: [0.55, 0.64],
                audioAnchors: [.softChime, .none],
                lightKeyNormalized: CGPoint(x: 0.22, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.31, y: 0.42),
                propTargetNormalized: CGPoint(x: 0.70, y: 0.62),
                komorebiStrength: 0.85
            )
        case .n03:
            return BespokeSceneMetadata(
                id: .n03,
                cameraGrammar: "blanket-cocoon-cradle",
                durations: [4.4, 5.2],
                posterPhases: [0.52, 0.58],
                audioAnchors: [.clothSwish, .none],
                lightKeyNormalized: CGPoint(x: 0.70, y: 0.20),
                ottoBeadNormalized: CGPoint(x: 0.37, y: 0.45),
                propTargetNormalized: CGPoint(x: 0.62, y: 0.64),
                komorebiStrength: 0.52
            )
        case .n04:
            return BespokeSceneMetadata(
                id: .n04,
                cameraGrammar: "birds-eye-round-tummy-mat",
                durations: [4.6, 4.5, 4.8],
                posterPhases: [0.54, 0.56, 0.62],
                audioAnchors: [.clothSwish, .none, .softChime],
                lightKeyNormalized: CGPoint(x: 0.80, y: 0.12),
                ottoBeadNormalized: CGPoint(x: 0.71, y: 0.44),
                propTargetNormalized: CGPoint(x: 0.44, y: 0.66),
                komorebiStrength: 0.82
            )
        case .n05:
            return BespokeSceneMetadata(
                id: .n05,
                cameraGrammar: "foreground-open-book-spread",
                durations: [4.8, 4.6],
                posterPhases: [0.55, 0.64],
                audioAnchors: [.clothSwish, .none],
                lightKeyNormalized: CGPoint(x: 0.26, y: 0.18),
                ottoBeadNormalized: CGPoint(x: 0.33, y: 0.40),
                propTargetNormalized: CGPoint(x: 0.52, y: 0.70),
                komorebiStrength: 0.68
            )
        case .n06:
            return BespokeSceneMetadata(
                id: .n06,
                cameraGrammar: "evening-study-desk-journal",
                durations: [4.8, 5.0],
                posterPhases: [0.56, 0.64],
                audioAnchors: [.woodTap, .softChime],
                lightKeyNormalized: CGPoint(x: 0.24, y: 0.22),
                ottoBeadNormalized: CGPoint(x: 0.27, y: 0.40),
                propTargetNormalized: CGPoint(x: 0.50, y: 0.74),
                komorebiStrength: 0.58
            )
        case .a01:
            return BespokeSceneMetadata(
                id: .a01,
                cameraGrammar: "eye-level-musical-alcove",
                durations: [4.2, 4.6, 4.4, 4.8],
                posterPhases: [0.54, 0.52, 0.50, 0.60],
                audioAnchors: [.none, .softChime, .none, .softChime],
                lightKeyNormalized: CGPoint(x: 0.74, y: 0.16),
                ottoBeadNormalized: CGPoint(x: 0.27, y: 0.44),
                propTargetNormalized: CGPoint(x: 0.73, y: 0.64),
                komorebiStrength: 0.78
            )
        case .a02:
            return BespokeSceneMetadata(
                id: .a02,
                cameraGrammar: "linen-care-bench-closeup",
                durations: [4.4, 4.5, 4.8],
                posterPhases: [0.54, 0.56, 0.62],
                audioAnchors: [.softChime, .none, .clothSwish],
                lightKeyNormalized: CGPoint(x: 0.76, y: 0.18),
                ottoBeadNormalized: CGPoint(x: 0.27, y: 0.45),
                propTargetNormalized: CGPoint(x: 0.50, y: 0.60),
                komorebiStrength: 0.70
            )
        case .a03:
            return BespokeSceneMetadata(
                id: .a03,
                cameraGrammar: "wide-low-playroom-horizon",
                durations: [4.5, 4.6, 4.4, 4.8],
                posterPhases: [0.54, 0.52, 0.56, 0.60],
                audioAnchors: [.none, .clothSwish, .softChime, .woodTap],
                lightKeyNormalized: CGPoint(x: 0.80, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.25, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.64, y: 0.66),
                komorebiStrength: 0.86
            )
        case .a04:
            return BespokeSceneMetadata(
                id: .a04,
                cameraGrammar: "macro-sunlit-grasping-mat",
                durations: [4.4, 4.6, 4.6],
                posterPhases: [0.54, 0.52, 0.60],
                audioAnchors: [.woodTap, .none, .woodTap],
                lightKeyNormalized: CGPoint(x: 0.78, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.74, y: 0.44),
                propTargetNormalized: CGPoint(x: 0.26, y: 0.64),
                komorebiStrength: 0.84
            )
        case .a05:
            return BespokeSceneMetadata(
                id: .a05,
                cameraGrammar: "acoustic-bay-window-arc",
                durations: [4.6, 4.8],
                posterPhases: [0.52, 0.58],
                audioAnchors: [.softChime, .none],
                lightKeyNormalized: CGPoint(x: 0.24, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.24, y: 0.44),
                propTargetNormalized: CGPoint(x: 0.56, y: 0.62),
                komorebiStrength: 0.80
            )
        case .a06:
            return BespokeSceneMetadata(
                id: .a06,
                cameraGrammar: "oversized-boardbook-lap-spread",
                durations: [4.6, 4.4, 4.6, 4.8, 4.5],
                posterPhases: [0.56, 0.54, 0.54, 0.58, 0.55],
                audioAnchors: [.clothSwish, .none, .softChime, .none, .clothSwish],
                lightKeyNormalized: CGPoint(x: 0.52, y: 0.16),
                ottoBeadNormalized: CGPoint(x: 0.27, y: 0.44),
                propTargetNormalized: CGPoint(x: 0.52, y: 0.68),
                komorebiStrength: 0.72
            )
        case .a07:
            return BespokeSceneMetadata(
                id: .a07,
                cameraGrammar: "bamboo-veranda-rhythm-sway",
                durations: [4.5, 4.8, 4.8, 5.0],
                posterPhases: [0.54, 0.52, 0.58, 0.60],
                audioAnchors: [.softChime, .woodTap, .none, .softChime],
                lightKeyNormalized: CGPoint(x: 0.80, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.30, y: 0.44),
                propTargetNormalized: CGPoint(x: 0.66, y: 0.62),
                komorebiStrength: 0.82
            )
        case .a08:
            return BespokeSceneMetadata(
                id: .a08,
                cameraGrammar: "montessori-tactile-trays-closeup",
                durations: [4.5, 4.6, 4.5, 4.8],
                posterPhases: [0.54, 0.55, 0.54, 0.60],
                audioAnchors: [.clothSwish, .clothSwish, .none, .none],
                lightKeyNormalized: CGPoint(x: 0.78, y: 0.16),
                ottoBeadNormalized: CGPoint(x: 0.26, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.52, y: 0.76),
                komorebiStrength: 0.74
            )
        case .a09:
            return BespokeSceneMetadata(
                id: .a09,
                cameraGrammar: "beech-wall-mirror-diptych",
                durations: [4.4, 4.6, 4.5, 4.8],
                posterPhases: [0.52, 0.58, 0.54, 0.60],
                audioAnchors: [.none, .vinylPop, .softChime, .none],
                lightKeyNormalized: CGPoint(x: 0.50, y: 0.12),
                ottoBeadNormalized: CGPoint(x: 0.30, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.50, y: 0.44),
                komorebiStrength: 0.76
            )
        case .a10:
            return BespokeSceneMetadata(
                id: .a10,
                cameraGrammar: "breezy-park-canopy-stroll",
                durations: [4.6, 4.8, 4.8],
                posterPhases: [0.54, 0.58, 0.62],
                audioAnchors: [.none, .softChime, .none],
                lightKeyNormalized: CGPoint(x: 0.76, y: 0.12),
                ottoBeadNormalized: CGPoint(x: 0.29, y: 0.44),
                propTargetNormalized: CGPoint(x: 0.60, y: 0.32),
                komorebiStrength: 0.92
            )
        case .a11:
            return BespokeSceneMetadata(
                id: .a11,
                cameraGrammar: "midline-transfer-tabletop-macro",
                durations: [4.4, 4.8, 4.6],
                posterPhases: [0.54, 0.55, 0.60],
                audioAnchors: [.woodTap, .softChime, .none],
                lightKeyNormalized: CGPoint(x: 0.74, y: 0.15),
                ottoBeadNormalized: CGPoint(x: 0.77, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.36, y: 0.76),
                komorebiStrength: 0.78
            )
        case .a12:
            return BespokeSceneMetadata(
                id: .a12,
                cameraGrammar: "playful-peekaboo-curtain-closeup",
                durations: [4.8, 4.6, 4.8],
                posterPhases: [0.58, 0.56, 0.60],
                audioAnchors: [.clothSwish, .vinylPop, .none],
                lightKeyNormalized: CGPoint(x: 0.72, y: 0.16),
                ottoBeadNormalized: CGPoint(x: 0.31, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.68, y: 0.64),
                komorebiStrength: 0.76
            )
        case .a13:
            return BespokeSceneMetadata(
                id: .a13,
                cameraGrammar: "resonant-beech-sound-stage",
                durations: [4.5, 4.6, 4.6, 4.8],
                posterPhases: [0.54, 0.52, 0.58, 0.60],
                audioAnchors: [.woodTap, .none, .woodTap, .softChime],
                lightKeyNormalized: CGPoint(x: 0.76, y: 0.15),
                ottoBeadNormalized: CGPoint(x: 0.26, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.52, y: 0.76),
                komorebiStrength: 0.80
            )
        case .a14:
            return BespokeSceneMetadata(
                id: .a14,
                cameraGrammar: "woven-treasure-basket-floor",
                durations: [4.5, 4.6, 4.8],
                posterPhases: [0.56, 0.56, 0.60],
                audioAnchors: [.woodTap, .vinylPop, .softChime],
                lightKeyNormalized: CGPoint(x: 0.78, y: 0.16),
                ottoBeadNormalized: CGPoint(x: 0.25, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.50, y: 0.78),
                komorebiStrength: 0.78
            )
        case .a15:
            return BespokeSceneMetadata(
                id: .a15,
                cameraGrammar: "wide-sunlit-quilted-floor-mat",
                durations: [4.5, 4.6, 4.8],
                posterPhases: [0.56, 0.56, 0.62],
                audioAnchors: [.clothSwish, .woodTap, .vinylPop],
                lightKeyNormalized: CGPoint(x: 0.76, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.23, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.50, y: 0.78),
                komorebiStrength: 0.86
            )
        case .a16:
            return BespokeSceneMetadata(
                id: .a16,
                cameraGrammar: "sunlit-shelf-sightline-triangle",
                durations: [4.4, 4.6, 4.6, 4.8],
                posterPhases: [0.54, 0.56, 0.54, 0.60],
                audioAnchors: [.none, .softChime, .none, .woodTap],
                lightKeyNormalized: CGPoint(x: 0.26, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.24, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.72, y: 0.38),
                komorebiStrength: 0.80
            )
        case .a17:
            return BespokeSceneMetadata(
                id: .a17,
                cameraGrammar: "entryway-sunlight-greeting-arch",
                durations: [4.5, 4.6, 4.8],
                posterPhases: [0.55, 0.56, 0.62],
                audioAnchors: [.softChime, .softChime, .vinylPop],
                lightKeyNormalized: CGPoint(x: 0.74, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.29, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.69, y: 0.64),
                komorebiStrength: 0.82
            )
        case .a18:
            return BespokeSceneMetadata(
                id: .a18,
                cameraGrammar: "low-angle-ball-rolling-corridor",
                durations: [4.4, 4.6, 4.8],
                posterPhases: [0.54, 0.56, 0.60],
                audioAnchors: [.clothSwish, .vinylPop, .clothSwish],
                lightKeyNormalized: CGPoint(x: 0.50, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.26, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.50, y: 0.78),
                komorebiStrength: 0.78
            )
        case .a19:
            return BespokeSceneMetadata(
                id: .a19,
                cameraGrammar: "sculpted-beech-block-tower-macro",
                durations: [4.6, 4.8, 5.0],
                posterPhases: [0.56, 0.58, 0.64],
                audioAnchors: [.woodTap, .woodTap, .vinylPop],
                lightKeyNormalized: CGPoint(x: 0.78, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.76, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.48, y: 0.72),
                komorebiStrength: 0.80
            )
        case .a20:
            return BespokeSceneMetadata(
                id: .a20,
                cameraGrammar: "low-montessori-table-care-studio",
                durations: [4.5, 4.6, 4.8],
                posterPhases: [0.54, 0.56, 0.62],
                audioAnchors: [.clothSwish, .clothSwish, .softChime],
                lightKeyNormalized: CGPoint(x: 0.26, y: 0.15),
                ottoBeadNormalized: CGPoint(x: 0.24, y: 0.45),
                propTargetNormalized: CGPoint(x: 0.50, y: 0.70),
                komorebiStrength: 0.82
            )
        case .a21:
            return BespokeSceneMetadata(
                id: .a21,
                cameraGrammar: "balanced-dual-wooden-trays-closeup",
                durations: [4.4, 4.6, 4.8],
                posterPhases: [0.54, 0.56, 0.60],
                audioAnchors: [.woodTap, .softChime, .vinylPop],
                lightKeyNormalized: CGPoint(x: 0.50, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.24, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.51, y: 0.78),
                komorebiStrength: 0.76
            )
        case .a22:
            return BespokeSceneMetadata(
                id: .a22,
                cameraGrammar: "botanical-card-tabletop-flatlay",
                durations: [4.5, 4.6, 4.8],
                posterPhases: [0.55, 0.56, 0.62],
                audioAnchors: [.woodTap, .clothSwish, .softChime],
                lightKeyNormalized: CGPoint(x: 0.74, y: 0.15),
                ottoBeadNormalized: CGPoint(x: 0.24, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.52, y: 0.78),
                komorebiStrength: 0.78
            )
        case .a23:
            return BespokeSceneMetadata(
                id: .a23,
                cameraGrammar: "cozy-reading-cushion-book-nook",
                durations: [4.5, 4.8, 4.8],
                posterPhases: [0.54, 0.56, 0.62],
                audioAnchors: [.clothSwish, .softChime, .clothSwish],
                lightKeyNormalized: CGPoint(x: 0.28, y: 0.16),
                ottoBeadNormalized: CGPoint(x: 0.26, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.50, y: 0.78),
                komorebiStrength: 0.74
            )
        case .a24:
            return BespokeSceneMetadata(
                id: .a24,
                cameraGrammar: "clipped-cotton-sketchpad-studio",
                durations: [4.4, 4.6, 4.8, 4.8],
                posterPhases: [0.54, 0.56, 0.62, 0.60],
                audioAnchors: [.woodTap, .clothSwish, .vinylPop, .softChime],
                lightKeyNormalized: CGPoint(x: 0.76, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.77, y: 0.45),
                propTargetNormalized: CGPoint(x: 0.48, y: 0.74),
                komorebiStrength: 0.82
            )
        case .a25:
            return BespokeSceneMetadata(
                id: .a25,
                cameraGrammar: "cozy-doll-cradle-nursery",
                durations: [4.5, 4.6, 4.8],
                posterPhases: [0.55, 0.58, 0.60],
                audioAnchors: [.clothSwish, .woodTap, .softChime],
                lightKeyNormalized: CGPoint(x: 0.76, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.76, y: 0.45),
                propTargetNormalized: CGPoint(x: 0.49, y: 0.76),
                komorebiStrength: 0.76
            )
        case .a26:
            return BespokeSceneMetadata(
                id: .a26,
                cameraGrammar: "hearth-lantern-emotion-sanctuary",
                durations: [4.6, 4.8, 4.8],
                posterPhases: [0.54, 0.56, 0.62],
                audioAnchors: [.softChime, .none, .vinylPop],
                lightKeyNormalized: CGPoint(x: 0.28, y: 0.15),
                ottoBeadNormalized: CGPoint(x: 0.30, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.58, y: 0.72),
                komorebiStrength: 0.74
            )
        case .a27:
            return BespokeSceneMetadata(
                id: .a27,
                cameraGrammar: "dual-sorting-mat-studio",
                durations: [4.5, 4.6, 4.8],
                posterPhases: [0.56, 0.58, 0.62],
                audioAnchors: [.woodTap, .woodTap, .softChime],
                lightKeyNormalized: CGPoint(x: 0.76, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.77, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.50, y: 0.78),
                komorebiStrength: 0.80
            )
        case .a28:
            return BespokeSceneMetadata(
                id: .a28,
                cameraGrammar: "wooden-play-kitchen-counter",
                durations: [4.4, 4.6, 4.8, 4.8],
                posterPhases: [0.54, 0.56, 0.60, 0.62],
                audioAnchors: [.woodTap, .softChime, .woodTap, .softChime],
                lightKeyNormalized: CGPoint(x: 0.76, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.76, y: 0.44),
                propTargetNormalized: CGPoint(x: 0.50, y: 0.66),
                komorebiStrength: 0.78
            )
        case .a29:
            return BespokeSceneMetadata(
                id: .a29,
                cameraGrammar: "wide-playroom-stepping-path",
                durations: [4.4, 4.6, 4.8, 4.6],
                posterPhases: [0.54, 0.56, 0.60, 0.62],
                audioAnchors: [.clothSwish, .woodTap, .vinylPop, .softChime],
                lightKeyNormalized: CGPoint(x: 0.26, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.28, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.54, y: 0.80),
                komorebiStrength: 0.84
            )
        case .a30:
            return BespokeSceneMetadata(
                id: .a30,
                cameraGrammar: "sunlit-dance-rug-rhythm-stage",
                durations: [4.5, 4.6, 5.0],
                posterPhases: [0.54, 0.56, 0.68],
                audioAnchors: [.softChime, .woodTap, .vinylPop],
                lightKeyNormalized: CGPoint(x: 0.74, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.28, y: 0.45),
                propTargetNormalized: CGPoint(x: 0.52, y: 0.74),
                komorebiStrength: 0.82
            )
        case .a31:
            return BespokeSceneMetadata(
                id: .a31,
                cameraGrammar: "twilight-story-bench-triptych",
                durations: [4.5, 4.8, 4.8],
                posterPhases: [0.55, 0.58, 0.62],
                audioAnchors: [.softChime, .clothSwish, .vinylPop],
                lightKeyNormalized: CGPoint(x: 0.26, y: 0.16),
                ottoBeadNormalized: CGPoint(x: 0.27, y: 0.45),
                propTargetNormalized: CGPoint(x: 0.50, y: 0.40),
                komorebiStrength: 0.74
            )
        case .a32:
            return BespokeSceneMetadata(
                id: .a32,
                cameraGrammar: "shared-courtyard-dual-playmat",
                durations: [4.5, 4.8, 4.8],
                posterPhases: [0.54, 0.58, 0.62],
                audioAnchors: [.none, .woodTap, .softChime],
                lightKeyNormalized: CGPoint(x: 0.50, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.50, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.50, y: 0.78),
                komorebiStrength: 0.82
            )
        case .a33:
            return BespokeSceneMetadata(
                id: .a33,
                cameraGrammar: "wide-block-arch-playroom",
                durations: [4.5, 4.8, 5.0],
                posterPhases: [0.52, 0.56, 0.64],
                audioAnchors: [.woodTap, .none, .softChime],
                lightKeyNormalized: CGPoint(x: 0.26, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.70, y: 0.44),
                propTargetNormalized: CGPoint(x: 0.50, y: 0.70),
                komorebiStrength: 0.76
            )
        case .a34:
            return BespokeSceneMetadata(
                id: .a34,
                cameraGrammar: "sunlit-garden-footpath-sky",
                durations: [4.6, 4.8, 4.8],
                posterPhases: [0.54, 0.56, 0.64],
                audioAnchors: [.softChime, .clothSwish, .vinylPop],
                lightKeyNormalized: CGPoint(x: 0.78, y: 0.14),
                ottoBeadNormalized: CGPoint(x: 0.68, y: 0.44),
                propTargetNormalized: CGPoint(x: 0.46, y: 0.46),
                komorebiStrength: 0.90
            )
        case .a35:
            return BespokeSceneMetadata(
                id: .a35,
                cameraGrammar: "entryway-dressing-bench",
                durations: [4.4, 4.6, 4.8, 4.8],
                posterPhases: [0.52, 0.56, 0.58, 0.66],
                audioAnchors: [.clothSwish, .none, .clothSwish, .softChime],
                lightKeyNormalized: CGPoint(x: 0.24, y: 0.16),
                ottoBeadNormalized: CGPoint(x: 0.74, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.54, y: 0.78),
                komorebiStrength: 0.72
            )
        case .a36:
            return BespokeSceneMetadata(
                id: .a36,
                cameraGrammar: "three-card-story-easel-mat",
                durations: [4.8, 4.6, 4.8],
                posterPhases: [0.54, 0.56, 0.64],
                audioAnchors: [.clothSwish, .woodTap, .vinylPop],
                lightKeyNormalized: CGPoint(x: 0.24, y: 0.18),
                ottoBeadNormalized: CGPoint(x: 0.73, y: 0.45),
                propTargetNormalized: CGPoint(x: 0.50, y: 0.58),
                komorebiStrength: 0.70
            )
        case .a37:
            return BespokeSceneMetadata(
                id: .a37,
                cameraGrammar: "dual-melody-story-rug",
                durations: [4.6, 4.8, 4.8],
                posterPhases: [0.54, 0.58, 0.64],
                audioAnchors: [.softChime, .softChime, .vinylPop],
                lightKeyNormalized: CGPoint(x: 0.74, y: 0.16),
                ottoBeadNormalized: CGPoint(x: 0.30, y: 0.45),
                propTargetNormalized: CGPoint(x: 0.50, y: 0.76),
                komorebiStrength: 0.74
            )
        case .a38:
            return BespokeSceneMetadata(
                id: .a38,
                cameraGrammar: "cloth-photo-album-lap-alcove",
                durations: [4.6, 4.8, 4.8],
                posterPhases: [0.54, 0.58, 0.62],
                audioAnchors: [.clothSwish, .softChime, .vinylPop],
                lightKeyNormalized: CGPoint(x: 0.24, y: 0.16),
                ottoBeadNormalized: CGPoint(x: 0.70, y: 0.45),
                propTargetNormalized: CGPoint(x: 0.50, y: 0.76),
                komorebiStrength: 0.72
            )
        case .a39:
            return BespokeSceneMetadata(
                id: .a39,
                cameraGrammar: "indoor-crosswalk-toy-car-mat",
                durations: [4.6, 4.8, 5.0],
                posterPhases: [0.52, 0.56, 0.64],
                audioAnchors: [.woodTap, .woodTap, .softChime],
                lightKeyNormalized: CGPoint(x: 0.74, y: 0.16),
                ottoBeadNormalized: CGPoint(x: 0.32, y: 0.46),
                propTargetNormalized: CGPoint(x: 0.60, y: 0.80),
                komorebiStrength: 0.74
            )
        case .a40:
            return BespokeSceneMetadata(
                id: .a40,
                cameraGrammar: "festive-lantern-tea-mat",
                durations: [4.8, 4.8, 4.8],
                posterPhases: [0.54, 0.58, 0.64],
                audioAnchors: [.softChime, .softChime, .vinylPop],
                lightKeyNormalized: CGPoint(x: 0.76, y: 0.16),
                ottoBeadNormalized: CGPoint(x: 0.31, y: 0.45),
                propTargetNormalized: CGPoint(x: 0.50, y: 0.38),
                komorebiStrength: 0.78
            )
        }
    }

    /// Maps every 0–36m activity into one of 5 cohesive picture-book wallpaper environments.
    static func wallpaperBiome(for id: BespokeActivityID) -> WallpaperBiome {
        switch id {
        case .a10, .a34:
            return .gardenMeadowSky
        case .n02, .n03, .n05, .n06, .a14, .a29, .a37:
            return .twilightLanternRoom
        case .a01, .a02, .a04, .a07, .a12, .a15, .a21, .a24, .a28, .a33, .a40:
            return .cozyReadingAlcove
        case .a05, .a08, .a11, .a13, .a18, .a19, .a20, .a23, .a25, .a26, .a30, .a32, .a35, .a36, .a39:
            return .atelierWorkTable
        case .n01, .n04, .a03, .a06, .a09, .a16, .a17, .a22, .a27, .a31, .a38:
            return .sunlitNurseryWindow
        }
    }

    @ViewBuilder
    static func stageView(id: BespokeActivityID, context: BespokeSceneContext) -> some View {
        let meta = metadata(for: id)
        let anchors = lightAnchors(for: id, step: context.stepIndex, stageSize: context.stageSize)
        let biome = wallpaperBiome(for: id)

        ZStack {
            rawScene(id: id, context: context)

            AtelierWallpaperFraming(
                biome: biome,
                dark: context.dark,
                compact: context.compact
            )
            .allowsHitTesting(false)

            if context.tapStrength > 0.01, let tap = context.tapOrigin, !context.isStatic {
                TapReactionChimeLayer(origin: tap, strength: context.tapStrength, dark: context.dark, size: context.stageSize)
            }
        }
        .modifier(
            GhibliStageGrade(
                stageSize: context.stageSize,
                time: context.breathTime,
                dark: context.dark,
                komorebiStrength: meta.komorebiStrength,
                enabled: context.flat && context.shaderEnabled
            )
        )
        .modifier(
            PixarStageGrade(
                stageSize: context.stageSize,
                keyPos: anchors.key,
                beadPos: anchors.bead,
                targetPos: anchors.target,
                time: context.breathTime,
                dark: context.dark,
                keyIntensity: context.dark ? 0.92 : 1.0,
                volumetricIntensity: context.dark ? 1.05 : 0.62,
                enabled: !context.flat && context.shaderEnabled
            )
        )
    }

    @ViewBuilder
    private static func rawScene(id: BespokeActivityID, context: BespokeSceneContext) -> some View {
        switch id {
        case .n01: SceneN01_VoiceTurns(ctx: context)
        case .n02: SceneN02_FamiliarFaces(ctx: context)
        case .n03: SceneN03_GentleHolding(ctx: context)
        case .n04: SceneN04_TummyTime(ctx: context)
        case .n05: SceneN05_ShortReads(ctx: context)
        case .n06: SceneN06_CareNotes(ctx: context)
        case .a01: SceneA01_FaceSoundTurns(ctx: context)
        case .a02: SceneA02_NarratingCare(ctx: context)
        case .a03: SceneA03_AwakeTummyPlay(ctx: context)
        case .a04: SceneA04_WatchHandsReach(ctx: context)
        case .a05: SceneA05_SoundDirection(ctx: context)
        case .a06: SceneA06_OnePageReading(ctx: context)
        case .a07: SceneA07_RhymesFingerplay(ctx: context)
        case .a08: SceneA08_TextureDiscovery(ctx: context)
        case .a09: SceneA09_MirrorFaces(ctx: context)
        case .a10: SceneA10_OutdoorListening(ctx: context)
        case .a11: SceneA11_HandToHandTransfer(ctx: context)
        case .a12: SceneA12_PeekabooHands(ctx: context)
        case .a13: SceneA13_TappingSounds(ctx: context)
        case .a14: SceneA14_BasketInOut(ctx: context)
        case .a15: SceneA15_FreeFloorExploration(ctx: context)
        case .a16: SceneA16_FollowGazeName(ctx: context)
        case .a17: SceneA17_EverydayGestures(ctx: context)
        case .a18: SceneA18_RollingSoftBall(ctx: context)
        case .a19: SceneA19_StackingChunkyBlocks(ctx: context)
        case .a20: SceneA20_WipingTidying(ctx: context)
        case .a21: SceneA21_TwoSimpleChoices(ctx: context)
        case .a22: SceneA22_MatchingPicturesObjects(ctx: context)
        case .a23: SceneA23_TurningPagesPointing(ctx: context)
        case .a24: SceneA24_FreeScribblingCrayons(ctx: context)
        case .a25: SceneA25_DollCarePlay(ctx: context)
        case .a26: SceneA26_NamingFeelings(ctx: context)
        case .a27: SceneA27_SortingLargeObjects(ctx: context)
        case .a28: SceneA28_KitchenPretendPlay(ctx: context)
        case .a29: SceneA29_SafeObstaclePath(ctx: context)
        case .a30: SceneA30_ParentChildActionMusic(ctx: context)
        case .a31: SceneA31_TellingDayStories(ctx: context)
        case .a32: SceneA32_ParallelPlayTurnTaking(ctx: context)
        case .a33: SceneA33_BuildingBigBlocks(ctx: context)
        case .a34: SceneA34_NoticingNature(ctx: context)
        case .a35: SceneA35_SocksPuttingAway(ctx: context)
        case .a36: SceneA36_PictureStorySequence(ctx: context)
        case .a37: SceneA37_TwoLanguagesNaturally(ctx: context)
        case .a38: SceneA38_FamilyPhotosNames(ctx: context)
        case .a39: SceneA39_RoadSafetyPractice(ctx: context)
        case .a40: SceneA40_FamilyStoriesTraditions(ctx: context)
        }
    }
}

// MARK: - Bespoke Shared Spatial & Graphic Helpers (Zero IP Violation)

/// Five cohesive Scandinavian × Ghibli nursery wallpaper environments shared across all 46 activities.
enum WallpaperBiome: String, CaseIterable, Sendable {
    case sunlitNurseryWindow
    case cozyReadingAlcove
    case gardenMeadowSky
    case atelierWorkTable
    case twilightLanternRoom
}

/// Non-intrusive perimeter botanical framing, window light rays & collector mat finish.
struct AtelierWallpaperFraming: View {
    let biome: WallpaperBiome
    let dark: Bool
    let compact: Bool

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            let w = size.width
            let h = size.height
            let s = min(w, h)
            guard w > 12, h > 12 else { return }

            // 1. Diagonal afternoon sunbeams or evening paper-lantern corner glow
            if !compact {
                let beamTint: Color = switch biome {
                case .twilightLanternRoom:
                    dark ? Color(hex: 0xFFBC68) : Color(hex: 0xFFE3A8)
                case .gardenMeadowSky:
                    dark ? Color(hex: 0x89B6E8) : Color(hex: 0xFFF7D6)
                case .cozyReadingAlcove:
                    dark ? Color(hex: 0xFFAE5E) : Color(hex: 0xFFEAC2)
                case .atelierWorkTable:
                    dark ? Color(hex: 0xDFB678) : Color(hex: 0xFFF5DB)
                case .sunlitNurseryWindow:
                    dark ? Color(hex: 0xF5BF74) : Color(hex: 0xFFF8DF)
                }

                for i in 0..<2 {
                    let offset = CGFloat(i) * w * 0.14
                    var shaft = Path()
                    shaft.move(to: CGPoint(x: w * 0.04 + offset, y: 0))
                    shaft.addLine(to: CGPoint(x: w * 0.17 + offset, y: 0))
                    shaft.addLine(to: CGPoint(x: w * 0.42 + offset, y: h * 0.85))
                    shaft.addLine(to: CGPoint(x: w * 0.25 + offset, y: h * 0.85))
                    shaft.closeSubpath()
                    ctx.fill(
                        shaft,
                        with: .linearGradient(
                            Gradient(colors: [
                                beamTint.opacity(dark ? 0.055 : 0.11),
                                beamTint.opacity(0.0)
                            ]),
                            startPoint: CGPoint(x: w * 0.12 + offset, y: 0),
                            endPoint: CGPoint(x: w * 0.34 + offset, y: h * 0.82)
                        )
                    )
                }

                // 2. Whisper-soft upper corner botanical foliage or cozy alcove valance
                if biome == .gardenMeadowSky || biome == .sunlitNurseryWindow {
                    let leafColor = (dark ? Color(hex: 0x4E746C) : Color(hex: 0x6F8F69)).opacity(dark ? 0.16 : 0.14)
                    for i in 0..<4 {
                        let t = CGFloat(i) / 3.0
                        let lx = w * (0.04 + t * 0.055)
                        let ly = h * (0.06 + t * 0.045)
                        let lw = s * (0.075 - t * 0.01)
                        let lh = lw * 0.42
                        var leaf = Path(ellipseIn: CGRect(x: lx - lw * 0.5, y: ly - lh * 0.5, width: lw, height: lh))
                        leaf = leaf.applying(CGAffineTransform(translationX: lx, y: ly).rotated(by: -0.45 + Double(i) * 0.22).translatedBy(x: -lx, y: -ly))
                        ctx.fill(leaf, with: .color(leafColor))
                    }
                } else if biome == .cozyReadingAlcove {
                    var arch = Path()
                    arch.move(to: CGPoint(x: 0, y: h * 0.12))
                    arch.addQuadCurve(to: CGPoint(x: w * 0.22, y: 0), control: CGPoint(x: w * 0.06, y: h * 0.02))
                    arch.addLine(to: .zero)
                    arch.closeSubpath()
                    ctx.fill(arch, with: .color((dark ? Color(hex: 0x2C3F63) : Color(hex: 0xD6B48F)).opacity(0.18)))
                } else if biome == .twilightLanternRoom {
                    let starColor = (dark ? Color(hex: 0xFFE5A3) : Color(hex: 0xC9985A)).opacity(dark ? 0.22 : 0.12)
                    for pt in [CGPoint(x: w * 0.11, y: h * 0.11), CGPoint(x: w * 0.88, y: h * 0.14)] {
                        ctx.fill(Path(ellipseIn: CGRect(x: pt.x - 2, y: pt.y - 2, width: 4, height: 4)), with: .color(starColor))
                    }
                }
            }

            // 3. Museum archival matte edge bevel & warm deckled vignette
            let edgeRect = CGRect(x: 1, y: 1, width: w - 2, height: h - 2)
            ctx.stroke(
                Path(roundedRect: edgeRect, cornerRadius: max(8, s * 0.03)),
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(dark ? 0.10 : 0.28),
                        (dark ? Color(hex: 0x091122) : Color(hex: 0xB89F79)).opacity(dark ? 0.22 : 0.14)
                    ]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: w, y: h)
                ),
                lineWidth: compact ? 0.8 : 1.15
            )
        }
    }
}

enum BespokeStageHelpers {
    /// Identical foot baseline positioning for 3D soft-vinyl & 2D Ghibli actors.
    static func actorCenterY(kind: Kind, size: CGFloat, groundY: CGFloat, flat: Bool, lift: CGFloat = 0) -> CGFloat {
        let feetFrac: CGFloat = flat ? 0.88 : ((kind == .moss ? Sprites.mossFeet : Sprites.ottoFeet) / 100.0)
        return groundY - size * feetFrac + size * 0.5 - lift
    }

    /// Dual-layer sky + wall atmosphere backing shared cleanly across Day and Lamp with subtle 5-biome craft depth.
    static func drawAtmosphereWash(
        in ctx: inout GraphicsContext,
        w: CGFloat,
        h: CGFloat,
        dayTop: Color,
        dayBottom: Color,
        nightTop: Color,
        nightBottom: Color,
        dark: Bool,
        biome: WallpaperBiome = .sunlitNurseryWindow
    ) {
        let top = dark ? nightTop : dayTop
        let bot = dark ? nightBottom : dayBottom
        let mid = top.mix(with: bot, by: 0.44)
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: w, height: h)),
            with: .linearGradient(
                Gradient(colors: [top, mid, bot]),
                startPoint: CGPoint(x: w * 0.20, y: 0),
                endPoint: CGPoint(x: w * 0.80, y: h)
            )
        )

        // Painterly sunlit arch / twilight aureole bloom in upper wall plane
        let bloomColor: Color = dark ? Color(hex: 0x263E68) : Color(hex: 0xFFFDF4)
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: w, height: h * 0.72)),
            with: .radialGradient(
                Gradient(colors: [bloomColor.opacity(dark ? 0.30 : 0.42), .clear]),
                center: CGPoint(x: w * 0.28, y: h * 0.22),
                startRadius: 4,
                endRadius: max(w, h) * 0.65
            )
        )

        if biome == .gardenMeadowSky {
            // Soft atmospheric cloud mist & distant meadow haze band
            let mistColor = (dark ? Color(hex: 0x1F3554) : Color(hex: 0xF7F9EF)).opacity(dark ? 0.24 : 0.34)
            ctx.fill(
                Path(ellipseIn: CGRect(x: -w * 0.1, y: h * 0.42, width: w * 1.2, height: h * 0.26)),
                with: .color(mistColor)
            )
        } else {
            // Whisper-soft Scandinavian vertical linen wall flutes + gentle dado molding
            let fluteColor = (dark ? Color(hex: 0x627DAE) : Color(hex: 0xA8926D)).opacity(dark ? 0.045 : 0.055)
            let count = biome == .cozyReadingAlcove ? 8 : 6
            for i in 1..<count {
                let x = w * CGFloat(i) / CGFloat(count)
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: h * 0.62))
                ctx.stroke(line, with: .color(fluteColor), lineWidth: 1.0)
            }
            var dado = Path()
            dado.move(to: CGPoint(x: 0, y: h * 0.62))
            dado.addLine(to: CGPoint(x: w, y: h * 0.62))
            ctx.stroke(dado, with: .color(fluteColor.opacity(1.5)), lineWidth: 1.1)
        }
    }

    /// Flowing multi-ribbon voice wave conveying gentle dialogue without speech bubbles or mouth dots.
    static func drawSilkVoiceRibbon(
        in ctx: inout GraphicsContext,
        from start: CGPoint,
        to end: CGPoint,
        progress: Double,
        waveOffset: Double,
        color: Color,
        lineWidth: CGFloat,
        dark: Bool
    ) {
        let clamped = max(0.0, min(1.0, progress))
        guard clamped > 0.02 else { return }

        var p = Path()
        let samples = 24
        for i in 0...samples {
            let t = Double(i) / Double(samples) * clamped
            let x = start.x + (end.x - start.x) * CGFloat(t)
            let baseY = start.y + (end.y - start.y) * CGFloat(t)
            let env = sin(t * .pi)
            let wave = sin(t * .pi * 3.0 + waveOffset) * 7.5 * env
            let pt = CGPoint(x: x, y: baseY + CGFloat(wave))
            if i == 0 {
                p.move(to: pt)
            } else {
                p.addLine(to: pt)
            }
        }
        ctx.stroke(
            p,
            with: .linearGradient(
                Gradient(colors: [
                    color.opacity(0.08),
                    color.opacity(dark ? 0.72 : 0.62),
                    color.opacity(dark ? 0.88 : 0.75)
                ]),
                startPoint: start,
                endPoint: end
            ),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        )
    }

    /// Golden stillness halo expanding softly in the pause space between turns.
    static func drawPauseHalo(
        in ctx: inout GraphicsContext,
        center: CGPoint,
        baseRadius: CGFloat,
        progress: Double,
        tint: Color,
        dark: Bool
    ) {
        let t = max(0.0, min(1.0, progress))
        guard t > 0.01 else { return }
        for ring in 0..<2 {
            let local = max(0.0, min(1.0, t - Double(ring) * 0.24))
            guard local > 0 else { continue }
            let r = baseRadius * (0.45 + 0.85 * CGFloat(local))
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            let alpha = (1.0 - local * 0.65) * (dark ? 0.48 : 0.36)
            ctx.stroke(
                Path(ellipseIn: rect),
                with: .color(tint.opacity(alpha)),
                style: StrokeStyle(lineWidth: ring == 0 ? 1.8 : 1.1, dash: ring == 1 ? [3, 4] : [])
            )
        }
    }

    /// Subtle sparkling bead cluster emitted on caregiver tactile contact.
    static func drawContactSparkles(
        in ctx: inout GraphicsContext,
        center: CGPoint,
        pulse: Double,
        radius: CGFloat,
        color: Color
    ) {
        guard pulse > 0.02 else { return }
        for i in 0..<5 {
            let ang = Double(i) * (2.0 * .pi / 5.0) - .pi / 2.0
            let dist = radius * CGFloat(0.45 + 0.75 * pulse)
            let pt = CGPoint(x: center.x + cos(ang) * dist, y: center.y + sin(ang) * dist)
            let dotR = max(1.4, 3.6 * CGFloat(pulse))
            ctx.fill(
                Path(ellipseIn: CGRect(x: pt.x - dotR, y: pt.y - dotR, width: dotR * 2, height: dotR * 2)),
                with: .color(color.opacity(min(1.0, pulse * 1.15)))
            )
        }
    }
}

private struct TapReactionChimeLayer: View {
    let origin: CGPoint
    let strength: Double
    let dark: Bool
    let size: CGSize

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, s in
            let center = CGPoint(x: origin.x * s.width, y: origin.y * s.height)
            let col = dark ? Palette.amber : Palette.accent
            let ringR = min(s.width, s.height) * CGFloat(0.06 + 0.14 * (1.0 - strength))
            let rect = CGRect(x: center.x - ringR, y: center.y - ringR, width: ringR * 2, height: ringR * 2)
            ctx.stroke(
                Path(ellipseIn: rect),
                with: .color(col.opacity(strength * 0.55)),
                lineWidth: 2.0
            )
            BespokeStageHelpers.drawContactSparkles(
                in: &ctx,
                center: center,
                pulse: strength,
                radius: min(s.width, s.height) * 0.09,
                color: Palette.amber.opacity(0.90)
            )
        }
        .allowsHitTesting(false)
    }
}
