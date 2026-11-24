import SwiftUI

/// Five Nordic cut-paper picture-book stage sets shared across all living activities.
enum LivingBackdropKind: String, Codable, CaseIterable, Sendable {
    case playMat
    case cozyCorner
    case woodenDesk
    case windowSun
    case meadowPath
}

/// Sixteen handcrafted Montessori physical props shared across Phase 1 & Phase 2 scripts.
enum LivingPropKind: String, Codable, CaseIterable, Sendable {
    case woodenRing
    case rattle
    case peekCloth
    case chunkyBlocks
    case softBall
    case mirror
    case woodCup
    case bell
    case pictureBook
    case crayon
    case doll
    case leaf
    case lantern
    case mat
    case ringStacker
    case bridgeBlocks
}

/// Eight OpenMotion non-uniform choreography phrases driven by real caregiver-baby verbs.
enum LivingMotionPhrase: String, Codable, CaseIterable, Sendable {
    case offerArc
    case pauseWatch
    case graspContact
    case peekReveal
    case gentleSway
    case soundRipple
    case liftStack
    case tumbleCheer
}

/// Who leads the present step so the adult (Otto) steps back while the child (Moss) explores.
enum LivingStepLead: String, Codable, CaseIterable, Sendable {
    case adult
    case child
    case together
}

/// Restrained sound-narrative anchor triggered ONLY after a parent explicitly taps to replay (auto-play is silent).
enum LivingAudioAnchor: String, Codable, CaseIterable, Sendable {
    case none
    case woodTap
    case clothSwish
    case softChime
    case vinylPop
}

/// Five-phase non-uniform OpenMotion temporal sample over normalized cycle progress `0...1`:
/// - `0.00..<0.16`: Anticipation (蓄势)
/// - `0.16..<0.46`: Main Action (主体表演)
/// - `0.46..<0.62`: Contact Feedback (接触反馈)
/// - `0.62..<0.78`: Follow-Through (次级跟随)
/// - `0.78...1.00`: Hold / Reading Pause (稳定落点)
struct LivingPhaseSample: Equatable, Sendable {
    let raw: Double
    let anticipation: Double
    let action: Double
    let contact: Double
    let contactEnvelope: Double
    let followThrough: Double
    let hold: Double

    var isContactWindow: Bool {
        raw >= 0.46 && raw < 0.62
    }
}

/// Deterministic, pure time-shape sampler and cyclic clock for `LivingBookStage`.
enum LivingMotionClock {
    static func smoothstep(_ x: Double) -> Double {
        let t = max(0, min(1, x))
        return t * t * (3 - 2 * t)
    }

    static func easeOutCubic(_ x: Double) -> Double {
        let t = max(0, min(1, x))
        return 1 - pow(1 - t, 3)
    }

    static func easeInOutSine(_ x: Double) -> Double {
        let t = max(0, min(1, x))
        return 0.5 - 0.5 * cos(t * .pi)
    }

    static func sample(u rawInput: Double) -> LivingPhaseSample {
        let u = max(0.0, min(1.0, rawInput))
        let ant: Double
        if u < 0.16 {
            ant = smoothstep(u / 0.16)
        } else {
            ant = 1.0
        }

        let act: Double
        if u < 0.16 {
            act = 0.0
        } else if u < 0.46 {
            act = easeOutCubic((u - 0.16) / 0.30)
        } else {
            act = 1.0
        }

        let contactPulse: Double
        let contactEnv: Double
        if u < 0.46 {
            contactPulse = 0.0
            contactEnv = 0.0
        } else if u < 0.62 {
            let t = (u - 0.46) / 0.16
            contactPulse = sin(t * .pi) * exp(-1.1 * t)
            contactEnv = smoothstep(t)
        } else {
            contactPulse = 0.0
            contactEnv = 1.0
        }

        let follow: Double
        if u < 0.62 {
            follow = 0.0
        } else if u < 0.78 {
            follow = easeOutCubic((u - 0.62) / 0.16)
        } else {
            follow = 1.0
        }

        let hold: Double
        if u < 0.78 {
            hold = 0.0
        } else {
            hold = max(0.0, min(1.0, (u - 0.78) / 0.22))
        }

        return LivingPhaseSample(
            raw: u,
            anticipation: ant,
            action: act,
            contact: contactPulse,
            contactEnvelope: contactEnv,
            followThrough: follow,
            hold: hold
        )
    }

    static func cyclicProgress(elapsed: Double, duration: Double) -> Double {
        guard duration > 0.05 else { return 0 }
        let mod = elapsed.truncatingRemainder(dividingBy: duration)
        let positive = mod < 0 ? mod + duration : mod
        return max(0.0, min(0.9999, positive / duration))
    }
}

/// Snapshot of a companion's spatial, gaze, lean, and canonical `docs/IP.md` expression state.
struct LivingActorPose: Equatable, Sendable {
    var x: CGFloat
    var hopLift: CGFloat
    var lean: Double
    var look: CGPoint
    var mood: Mood
    var lid: Double?
    var hopping: Bool
}

/// One step's declarative choreography script inside a living picture-book activity.
struct LivingStepScript: Equatable, Sendable {
    let stepIndex: Int
    let phrase: LivingMotionPhrase
    let lead: LivingStepLead
    let prop: LivingPropKind
    let secondaryProp: LivingPropKind?
    let posterPhase: Double
    let duration: Double
    let audioAnchor: LivingAudioAnchor
    let mossAnchorX: CGFloat
    let ottoAnchorX: CGFloat
    let lampTargetX: CGFloat
    let lampTargetY: CGFloat

    /// Pure deterministic actor poses adhering 100% to `docs/IP.md` (zero blush, zero speech bubbles,
    /// Moss curious & bouncy, Otto slow-lidded & holding the golden light).
    func actors(at s: LivingPhaseSample, dark: Bool) -> (moss: LivingActorPose, otto: LivingActorPose) {
        let restLid: Double? = dark ? 0.45 : nil

        switch phrase {
        case .offerArc:
            let ottoTilt = -3.0 - 2.5 * s.action + 1.5 * s.followThrough
            let mossTilt = 2.0 + 3.5 * s.contactEnvelope
            let mossLook = CGPoint(x: 0.85, y: -0.25 + 0.35 * s.action)
            let ottoLook = CGPoint(x: -0.90, y: 0.25 + 0.20 * s.action)
            let mossMood: Mood = s.raw >= 0.44 ? .wow : .open
            return (
                moss: LivingActorPose(
                    x: mossAnchorX,
                    hopLift: CGFloat(s.contact * 0.35),
                    lean: mossTilt,
                    look: mossLook,
                    mood: mossMood,
                    lid: restLid,
                    hopping: s.contact > 0.45
                ),
                otto: LivingActorPose(
                    x: ottoAnchorX,
                    hopLift: 0,
                    lean: ottoTilt,
                    look: ottoLook,
                    mood: .open,
                    lid: restLid,
                    hopping: false
                )
            )

        case .pauseWatch:
            let curiousHop = s.contact * 0.55
            let mossTilt = 4.5 * s.action + 2.5 * s.contact
            let mossMood: Mood = s.isContactWindow ? .wow : .open
            let blinkLid: Double? = (s.raw > 0.72 && s.raw < 0.80) ? 1.0 : restLid
            return (
                moss: LivingActorPose(
                    x: mossAnchorX + CGFloat(0.025 * s.action),
                    hopLift: CGFloat(curiousHop),
                    lean: mossTilt,
                    look: CGPoint(x: 0.90, y: 0.10),
                    mood: mossMood,
                    lid: restLid,
                    hopping: curiousHop > 0.22
                ),
                otto: LivingActorPose(
                    x: ottoAnchorX,
                    hopLift: 0,
                    lean: -2.0,
                    look: CGPoint(x: -0.88, y: 0.30),
                    mood: .open,
                    lid: blinkLid,
                    hopping: false
                )
            )

        case .graspContact:
            let joyHop = s.contact * 0.90 + s.followThrough * 0.12
            let happyNow = s.raw >= 0.42
            return (
                moss: LivingActorPose(
                    x: mossAnchorX + CGFloat(0.03 * s.action),
                    hopLift: CGFloat(joyHop),
                    lean: 5.5 - 2.0 * s.followThrough,
                    look: CGPoint(x: 0.88, y: happyNow ? -0.15 : 0.25),
                    mood: happyNow ? .happy : .wow,
                    lid: restLid,
                    hopping: joyHop > 0.20
                ),
                otto: LivingActorPose(
                    x: ottoAnchorX,
                    hopLift: 0,
                    lean: -3.8,
                    look: CGPoint(x: -0.92, y: 0.32),
                    mood: happyNow ? .happy : .open,
                    lid: restLid,
                    hopping: false
                )
            )

        case .peekReveal:
            if lead == .child {
                let hiddenBehindCloth = s.raw < 0.34
                let popHop = s.raw >= 0.36 ? max(0, sin(min(1, (s.raw - 0.36) / 0.32) * .pi) * 0.95) : 0
                let happyNow = s.raw >= 0.36
                return (
                    moss: LivingActorPose(
                        x: mossAnchorX,
                        hopLift: CGFloat(popHop),
                        lean: hiddenBehindCloth ? -3.0 : 4.5,
                        look: CGPoint(x: 0.92, y: -0.10),
                        mood: happyNow ? .happy : .open,
                        lid: hiddenBehindCloth ? 0.65 : restLid,
                        hopping: popHop > 0.20
                    ),
                    otto: LivingActorPose(
                        x: ottoAnchorX,
                        hopLift: 0,
                        lean: -3.5,
                        look: CGPoint(x: -0.92, y: 0.22),
                        mood: happyNow ? .happy : .open,
                        lid: restLid,
                        hopping: false
                    )
                )
            } else {
                let adultHidden = s.raw < 0.34
                let mossHop = s.raw >= 0.42 ? s.contact * 0.88 : 0
                let happyNow = s.raw >= 0.36
                return (
                    moss: LivingActorPose(
                        x: mossAnchorX,
                        hopLift: CGFloat(mossHop),
                        lean: happyNow ? 5.0 : 2.0,
                        look: CGPoint(x: 0.92, y: -0.12),
                        mood: happyNow ? .happy : .wow,
                        lid: restLid,
                        hopping: mossHop > 0.18
                    ),
                    otto: LivingActorPose(
                        x: ottoAnchorX,
                        hopLift: 0,
                        lean: adultHidden ? -1.5 : -4.2,
                        look: CGPoint(x: -0.92, y: 0.20),
                        mood: happyNow ? .happy : .open,
                        lid: adultHidden ? 0.72 : restLid,
                        hopping: false
                    )
                )
            }

        case .gentleSway:
            let swayDeg = sin(s.raw * .pi * 2.0) * 3.5
            let slowBlink: Double? = (s.raw > 0.65 && s.raw < 0.76) ? 1.0 : restLid
            return (
                moss: LivingActorPose(
                    x: mossAnchorX,
                    hopLift: CGFloat(max(0, sin(s.raw * .pi) * 0.18)),
                    lean: 2.5 + swayDeg * 0.7,
                    look: CGPoint(x: 0.90, y: -0.08),
                    mood: .happy,
                    lid: restLid,
                    hopping: false
                ),
                otto: LivingActorPose(
                    x: ottoAnchorX,
                    hopLift: 0,
                    lean: -3.0 + swayDeg * 0.5,
                    look: CGPoint(x: -0.92, y: 0.18),
                    mood: .happy,
                    lid: slowBlink,
                    hopping: false
                )
            )

        case .soundRipple:
            return (
                moss: LivingActorPose(
                    x: mossAnchorX,
                    hopLift: CGFloat(s.contact * 0.30),
                    lean: 3.5,
                    look: CGPoint(x: 0.88, y: -0.10),
                    mood: s.raw >= 0.50 ? .happy : .wow,
                    lid: restLid,
                    hopping: false
                ),
                otto: LivingActorPose(
                    x: ottoAnchorX,
                    hopLift: 0,
                    lean: -3.2,
                    look: CGPoint(x: -0.90, y: 0.22),
                    mood: .open,
                    lid: restLid,
                    hopping: false
                )
            )

        case .liftStack:
            if lead == .child {
                let mossHop = s.contact * 0.78
                return (
                    moss: LivingActorPose(
                        x: mossAnchorX + CGFloat(0.02 * s.action),
                        hopLift: CGFloat(mossHop),
                        lean: 5.5 - 2.0 * s.followThrough,
                        look: CGPoint(x: 0.90, y: -0.20),
                        mood: s.raw >= 0.45 ? .happy : .wow,
                        lid: restLid,
                        hopping: mossHop > 0.18
                    ),
                    otto: LivingActorPose(
                        x: ottoAnchorX,
                        hopLift: 0,
                        lean: -1.5,
                        look: CGPoint(x: -0.90, y: 0.26),
                        mood: s.raw >= 0.50 ? .happy : .open,
                        lid: restLid,
                        hopping: false
                    )
                )
            } else {
                return (
                    moss: LivingActorPose(
                        x: mossAnchorX,
                        hopLift: CGFloat(s.contact * 0.28),
                        lean: 2.5,
                        look: CGPoint(x: 0.90, y: -0.15),
                        mood: s.raw >= 0.46 ? .wow : .open,
                        lid: restLid,
                        hopping: false
                    ),
                    otto: LivingActorPose(
                        x: ottoAnchorX,
                        hopLift: 0,
                        lean: -4.2,
                        look: CGPoint(x: -0.88, y: 0.34),
                        mood: s.raw >= 0.52 ? .happy : .open,
                        lid: restLid,
                        hopping: false
                    )
                )
            }

        case .tumbleCheer:
            let cheerHop = s.raw >= 0.46 ? max(0, sin(min(1, (s.raw - 0.46) / 0.30) * .pi) * 0.92) : 0
            let cheerNow = s.raw >= 0.44
            return (
                moss: LivingActorPose(
                    x: mossAnchorX,
                    hopLift: CGFloat(cheerHop),
                    lean: cheerNow ? 5.0 : -2.0 * s.anticipation,
                    look: CGPoint(x: 0.88, y: cheerNow ? -0.15 : 0.20),
                    mood: cheerNow ? .happy : .wow,
                    lid: restLid,
                    hopping: cheerHop > 0.18
                ),
                otto: LivingActorPose(
                    x: ottoAnchorX,
                    hopLift: 0,
                    lean: cheerNow ? -4.5 : -2.5,
                    look: CGPoint(x: -0.92, y: cheerNow ? 0.22 : 0.38),
                    mood: cheerNow ? .happy : .open,
                    lid: restLid,
                    hopping: false
                )
            )
        }
    }
}

/// Complete declarative living picture-book script for a single activity (`A04`, `A12`, `A19` in Phase 1).
struct LivingActivityScript: Equatable, Sendable {
    let code: String
    let backdrop: LivingBackdropKind
    let steps: [LivingStepScript]
}

/// Phase 1 curated living picture-book catalog (`A04`, `A12`, `A19`).
enum LivingBookCatalog {
    static let scriptsByCode: [String: LivingActivityScript] = {
        let items: [LivingActivityScript] = [
            // A04: Watching Hands & Reaching (playMat + woodenRing + rattle)
            LivingActivityScript(
                code: "A04",
                backdrop: .playMat,
                steps: [
                    LivingStepScript(
                        stepIndex: 0,
                        phrase: .offerArc,
                        lead: .adult,
                        prop: .woodenRing,
                        secondaryProp: .rattle,
                        posterPhase: 0.64,
                        duration: 3.4,
                        audioAnchor: .woodTap,
                        mossAnchorX: 0.28,
                        ottoAnchorX: 0.75,
                        lampTargetX: 0.49,
                        lampTargetY: 0.56
                    ),
                    LivingStepScript(
                        stepIndex: 1,
                        phrase: .pauseWatch,
                        lead: .child,
                        prop: .woodenRing,
                        secondaryProp: .rattle,
                        posterPhase: 0.56,
                        duration: 3.4,
                        audioAnchor: .vinylPop,
                        mossAnchorX: 0.29,
                        ottoAnchorX: 0.75,
                        lampTargetX: 0.48,
                        lampTargetY: 0.57
                    ),
                    LivingStepScript(
                        stepIndex: 2,
                        phrase: .graspContact,
                        lead: .together,
                        prop: .woodenRing,
                        secondaryProp: .rattle,
                        posterPhase: 0.58,
                        duration: 3.4,
                        audioAnchor: .woodTap,
                        mossAnchorX: 0.30,
                        ottoAnchorX: 0.74,
                        lampTargetX: 0.40,
                        lampTargetY: 0.62
                    ),
                ]
            ),
            // A12: Peekaboo Hands (cozyCorner + organic muslin peekCloth)
            LivingActivityScript(
                code: "A12",
                backdrop: .cozyCorner,
                steps: [
                    LivingStepScript(
                        stepIndex: 0,
                        phrase: .peekReveal,
                        lead: .adult,
                        prop: .peekCloth,
                        secondaryProp: nil,
                        posterPhase: 0.45,
                        duration: 3.5,
                        audioAnchor: .clothSwish,
                        mossAnchorX: 0.27,
                        ottoAnchorX: 0.72,
                        lampTargetX: 0.52,
                        lampTargetY: 0.54
                    ),
                    LivingStepScript(
                        stepIndex: 1,
                        phrase: .gentleSway,
                        lead: .adult,
                        prop: .peekCloth,
                        secondaryProp: nil,
                        posterPhase: 0.52,
                        duration: 3.4,
                        audioAnchor: .softChime,
                        mossAnchorX: 0.28,
                        ottoAnchorX: 0.72,
                        lampTargetX: 0.50,
                        lampTargetY: 0.54
                    ),
                    LivingStepScript(
                        stepIndex: 2,
                        phrase: .peekReveal,
                        lead: .child,
                        prop: .peekCloth,
                        secondaryProp: nil,
                        posterPhase: 0.45,
                        duration: 3.5,
                        audioAnchor: .clothSwish,
                        mossAnchorX: 0.30,
                        ottoAnchorX: 0.74,
                        lampTargetX: 0.38,
                        lampTargetY: 0.58
                    ),
                ]
            ),
            // A19: Stacking Chunky Blocks (woodenDesk + 3-block tower + joyful tumble)
            LivingActivityScript(
                code: "A19",
                backdrop: .woodenDesk,
                steps: [
                    LivingStepScript(
                        stepIndex: 0,
                        phrase: .liftStack,
                        lead: .adult,
                        prop: .chunkyBlocks,
                        secondaryProp: nil,
                        posterPhase: 0.56,
                        duration: 3.4,
                        audioAnchor: .woodTap,
                        mossAnchorX: 0.25,
                        ottoAnchorX: 0.76,
                        lampTargetX: 0.50,
                        lampTargetY: 0.60
                    ),
                    LivingStepScript(
                        stepIndex: 1,
                        phrase: .liftStack,
                        lead: .child,
                        prop: .chunkyBlocks,
                        secondaryProp: nil,
                        posterPhase: 0.56,
                        duration: 3.5,
                        audioAnchor: .woodTap,
                        mossAnchorX: 0.26,
                        ottoAnchorX: 0.77,
                        lampTargetX: 0.50,
                        lampTargetY: 0.54
                    ),
                    LivingStepScript(
                        stepIndex: 2,
                        phrase: .tumbleCheer,
                        lead: .together,
                        prop: .chunkyBlocks,
                        secondaryProp: nil,
                        posterPhase: 0.56,
                        duration: 3.8,
                        audioAnchor: .softChime,
                        mossAnchorX: 0.25,
                        ottoAnchorX: 0.76,
                        lampTargetX: 0.50,
                        lampTargetY: 0.66
                    ),
                ]
            ),
        ]
        return Dictionary(uniqueKeysWithValues: items.map { ($0.code, $0) })
    }()

    static var supportedCodes: [String] {
        scriptsByCode.keys.sorted()
    }

    static func hasScript(for code: String) -> Bool {
        scriptsByCode[code] != nil
    }

    static func script(for code: String) -> LivingActivityScript? {
        scriptsByCode[code]
    }

    static func stepScript(for code: String, stepIndex: Int) -> LivingStepScript? {
        guard let script = scriptsByCode[code], !script.steps.isEmpty else { return nil }
        let clamped = min(max(0, stepIndex), script.steps.count - 1)
        return script.steps[clamped]
    }
}
