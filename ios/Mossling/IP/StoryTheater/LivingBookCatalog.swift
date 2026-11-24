import SwiftUI

/// Compact declarative cue for building one step of a `LivingActivityScript`.
private struct StepCue {
    let phrase: LivingMotionPhrase
    let lead: LivingStepLead
    let audio: LivingAudioAnchor
    var poster: Double = 0.56
    var duration: Double = 3.4
    var targetX: CGFloat = 0.50
    var targetY: CGFloat = 0.58

    init(
        _ phrase: LivingMotionPhrase,
        _ lead: LivingStepLead,
        _ audio: LivingAudioAnchor = .woodTap,
        poster: Double = 0.56,
        duration: Double = 3.4,
        targetX: CGFloat = 0.50,
        targetY: CGFloat = 0.58
    ) {
        self.phrase = phrase
        self.lead = lead
        self.audio = audio
        self.poster = poster
        self.duration = duration
        self.targetX = targetX
        self.targetY = targetY
    }
}

/// Complete curated living picture-book catalog spanning all 46 authoritative activities (`N01–N06`, `A01–A40`).
enum LivingBookCatalog {
    private static func activity(
        _ code: String,
        backdrop: LivingBackdropKind,
        prop: LivingPropKind,
        secondary: LivingPropKind? = nil,
        mossX: CGFloat = 0.27,
        ottoX: CGFloat = 0.74,
        _ cues: [StepCue]
    ) -> LivingActivityScript {
        let steps = cues.enumerated().map { idx, c in
            LivingStepScript(
                stepIndex: idx,
                phrase: c.phrase,
                lead: c.lead,
                prop: prop,
                secondaryProp: secondary,
                posterPhase: c.poster,
                duration: c.duration,
                audioAnchor: c.audio,
                mossAnchorX: mossX,
                ottoAnchorX: ottoX,
                lampTargetX: c.targetX,
                lampTargetY: c.targetY
            )
        }
        return LivingActivityScript(code: code, backdrop: backdrop, steps: steps)
    }

    static let scriptsByCode: [String: LivingActivityScript] = {
        let items: [LivingActivityScript] = [
            // MARK: Newborn (N01–N06)
            activity("N01", backdrop: .cozyCorner, prop: .lantern, mossX: 0.31, ottoX: 0.69, [
                StepCue(.soundRipple, .adult, .softChime, poster: 0.54, duration: 3.5),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4, targetX: 0.44),
                StepCue(.soundRipple, .together, .softChime, poster: 0.58, duration: 3.6),
            ]),
            activity("N02", backdrop: .windowSun, prop: .mirror, mossX: 0.29, ottoX: 0.71, [
                StepCue(.gentleSway, .adult, .softChime, poster: 0.52, duration: 3.6),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.5, targetX: 0.46),
            ]),
            activity("N03", backdrop: .cozyCorner, prop: .doll, secondary: .lantern, mossX: 0.31, ottoX: 0.69, [
                StepCue(.gentleSway, .adult, .clothSwish, poster: 0.52, duration: 3.6),
                StepCue(.gentleSway, .together, .softChime, poster: 0.56, duration: 3.8),
            ]),
            activity("N04", backdrop: .playMat, prop: .lantern, secondary: .mat, mossX: 0.27, ottoX: 0.74, [
                StepCue(.offerArc, .adult, .clothSwish, poster: 0.60, duration: 3.5, targetX: 0.48),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4, targetX: 0.44),
                StepCue(.soundRipple, .together, .softChime, poster: 0.56, duration: 3.5),
            ]),
            activity("N05", backdrop: .cozyCorner, prop: .pictureBook, mossX: 0.28, ottoX: 0.73, [
                StepCue(.soundRipple, .adult, .clothSwish, poster: 0.55, duration: 3.6),
                StepCue(.gentleSway, .together, .softChime, poster: 0.52, duration: 3.5),
            ]),
            activity("N06", backdrop: .woodenDesk, prop: .lantern, secondary: .pictureBook, mossX: 0.28, ottoX: 0.73, [
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.5, targetX: 0.44),
                StepCue(.gentleSway, .adult, .softChime, poster: 0.54, duration: 3.5),
            ]),

            // MARK: Year 1 (A01–A15)
            activity("A01", backdrop: .cozyCorner, prop: .lantern, mossX: 0.30, ottoX: 0.70, [
                StepCue(.gentleSway, .together, .softChime, poster: 0.52, duration: 3.4),
                StepCue(.soundRipple, .adult, .softChime, poster: 0.55, duration: 3.4),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4, targetX: 0.42),
                StepCue(.soundRipple, .together, .softChime, poster: 0.58, duration: 3.5),
            ]),
            activity("A02", backdrop: .cozyCorner, prop: .peekCloth, mossX: 0.29, ottoX: 0.72, [
                StepCue(.soundRipple, .adult, .clothSwish, poster: 0.54, duration: 3.4),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4, targetX: 0.44),
                StepCue(.offerArc, .together, .clothSwish, poster: 0.60, duration: 3.5),
            ]),
            activity("A03", backdrop: .playMat, prop: .softBall, secondary: .mat, mossX: 0.26, ottoX: 0.75, [
                StepCue(.offerArc, .adult, .clothSwish, poster: 0.62, duration: 3.4),
                StepCue(.pauseWatch, .adult, .vinylPop, poster: 0.55, duration: 3.4, targetX: 0.48),
                StepCue(.soundRipple, .together, .softChime, poster: 0.56, duration: 3.4),
                StepCue(.graspContact, .child, .clothSwish, poster: 0.58, duration: 3.5, targetX: 0.42, targetY: 0.62),
            ]),
            // A04: Phase 1 Hero (Watching Hands & Reaching)
            LivingActivityScript(
                code: "A04",
                backdrop: .playMat,
                steps: [
                    LivingStepScript(
                        stepIndex: 0, phrase: .offerArc, lead: .adult, prop: .woodenRing, secondaryProp: .rattle,
                        posterPhase: 0.64, duration: 3.4, audioAnchor: .woodTap,
                        mossAnchorX: 0.28, ottoAnchorX: 0.75, lampTargetX: 0.49, lampTargetY: 0.56
                    ),
                    LivingStepScript(
                        stepIndex: 1, phrase: .pauseWatch, lead: .child, prop: .woodenRing, secondaryProp: .rattle,
                        posterPhase: 0.56, duration: 3.4, audioAnchor: .vinylPop,
                        mossAnchorX: 0.29, ottoAnchorX: 0.75, lampTargetX: 0.48, lampTargetY: 0.57
                    ),
                    LivingStepScript(
                        stepIndex: 2, phrase: .graspContact, lead: .together, prop: .woodenRing, secondaryProp: .rattle,
                        posterPhase: 0.58, duration: 3.4, audioAnchor: .woodTap,
                        mossAnchorX: 0.30, ottoAnchorX: 0.74, lampTargetX: 0.40, lampTargetY: 0.62
                    ),
                ]
            ),
            activity("A05", backdrop: .playMat, prop: .bell, mossX: 0.28, ottoX: 0.74, [
                StepCue(.soundRipple, .adult, .softChime, poster: 0.54, duration: 3.5, targetX: 0.52),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4, targetX: 0.44),
            ]),
            activity("A06", backdrop: .cozyCorner, prop: .pictureBook, mossX: 0.27, ottoX: 0.74, [
                StepCue(.liftStack, .adult, .clothSwish, poster: 0.56, duration: 3.4),
                StepCue(.offerArc, .adult, .woodTap, poster: 0.60, duration: 3.4),
                StepCue(.soundRipple, .adult, .softChime, poster: 0.55, duration: 3.4),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4, targetX: 0.44),
                StepCue(.gentleSway, .together, .softChime, poster: 0.54, duration: 3.5),
            ]),
            activity("A07", backdrop: .cozyCorner, prop: .bell, mossX: 0.28, ottoX: 0.73, [
                StepCue(.soundRipple, .adult, .softChime, poster: 0.54, duration: 3.4),
                StepCue(.gentleSway, .adult, .woodTap, poster: 0.52, duration: 3.4),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4, targetX: 0.44),
                StepCue(.soundRipple, .together, .softChime, poster: 0.58, duration: 3.5),
            ]),
            activity("A08", backdrop: .playMat, prop: .peekCloth, secondary: .woodenRing, mossX: 0.28, ottoX: 0.74, [
                StepCue(.offerArc, .adult, .clothSwish, poster: 0.60, duration: 3.4),
                StepCue(.graspContact, .child, .clothSwish, poster: 0.58, duration: 3.4, targetX: 0.42),
                StepCue(.soundRipple, .adult, .softChime, poster: 0.54, duration: 3.4),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4),
            ]),
            activity("A09", backdrop: .cozyCorner, prop: .mirror, mossX: 0.29, ottoX: 0.71, [
                StepCue(.gentleSway, .together, .softChime, poster: 0.54, duration: 3.5),
                StepCue(.soundRipple, .adult, .softChime, poster: 0.56, duration: 3.4),
                StepCue(.offerArc, .adult, .vinylPop, poster: 0.60, duration: 3.4),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4, targetX: 0.46),
            ]),
            activity("A10", backdrop: .meadowPath, prop: .leaf, mossX: 0.26, ottoX: 0.75, [
                StepCue(.gentleSway, .together, .clothSwish, poster: 0.52, duration: 3.6),
                StepCue(.soundRipple, .adult, .softChime, poster: 0.56, duration: 3.5),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4, targetX: 0.44),
            ]),
            activity("A11", backdrop: .playMat, prop: .rattle, secondary: .woodenRing, mossX: 0.28, ottoX: 0.74, [
                StepCue(.offerArc, .adult, .woodTap, poster: 0.62, duration: 3.4),
                StepCue(.graspContact, .child, .woodTap, poster: 0.58, duration: 3.4, targetX: 0.42, targetY: 0.60),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4, targetX: 0.44),
            ]),
            // A12: Phase 1 Hero (Peekaboo Hands)
            LivingActivityScript(
                code: "A12",
                backdrop: .cozyCorner,
                steps: [
                    LivingStepScript(
                        stepIndex: 0, phrase: .peekReveal, lead: .adult, prop: .peekCloth, secondaryProp: nil,
                        posterPhase: 0.45, duration: 3.5, audioAnchor: .clothSwish,
                        mossAnchorX: 0.27, ottoAnchorX: 0.72, lampTargetX: 0.52, lampTargetY: 0.54
                    ),
                    LivingStepScript(
                        stepIndex: 1, phrase: .gentleSway, lead: .adult, prop: .peekCloth, secondaryProp: nil,
                        posterPhase: 0.52, duration: 3.4, audioAnchor: .softChime,
                        mossAnchorX: 0.28, ottoAnchorX: 0.72, lampTargetX: 0.50, lampTargetY: 0.54
                    ),
                    LivingStepScript(
                        stepIndex: 2, phrase: .peekReveal, lead: .child, prop: .peekCloth, secondaryProp: nil,
                        posterPhase: 0.45, duration: 3.5, audioAnchor: .clothSwish,
                        mossAnchorX: 0.30, ottoAnchorX: 0.74, lampTargetX: 0.38, lampTargetY: 0.58
                    ),
                ]
            ),
            activity("A13", backdrop: .woodenDesk, prop: .bell, mossX: 0.26, ottoX: 0.75, [
                StepCue(.liftStack, .adult, .softChime, poster: 0.56, duration: 3.4),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4),
                StepCue(.graspContact, .child, .woodTap, poster: 0.58, duration: 3.4, targetX: 0.44),
                StepCue(.soundRipple, .together, .softChime, poster: 0.55, duration: 3.5),
            ]),
            activity("A14", backdrop: .woodenDesk, prop: .woodCup, mossX: 0.26, ottoX: 0.75, [
                StepCue(.liftStack, .adult, .woodTap, poster: 0.56, duration: 3.4),
                StepCue(.graspContact, .child, .woodTap, poster: 0.58, duration: 3.5, targetX: 0.44),
                StepCue(.soundRipple, .together, .vinylPop, poster: 0.56, duration: 3.4),
            ]),
            activity("A15", backdrop: .playMat, prop: .mat, secondary: .softBall, mossX: 0.23, ottoX: 0.77, [
                StepCue(.offerArc, .adult, .clothSwish, poster: 0.60, duration: 3.4),
                StepCue(.pauseWatch, .adult, .vinylPop, poster: 0.56, duration: 3.4),
                StepCue(.graspContact, .child, .woodTap, poster: 0.58, duration: 3.5, targetX: 0.44),
            ]),

            // MARK: Year 2 (A16–A28)
            activity("A16", backdrop: .windowSun, prop: .lantern, secondary: .woodenRing, mossX: 0.27, ottoX: 0.74, [
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4, targetX: 0.42),
                StepCue(.soundRipple, .adult, .softChime, poster: 0.55, duration: 3.4),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4, targetX: 0.45),
                StepCue(.offerArc, .together, .woodTap, poster: 0.60, duration: 3.4),
            ]),
            activity("A17", backdrop: .cozyCorner, prop: .lantern, mossX: 0.28, ottoX: 0.73, [
                StepCue(.offerArc, .adult, .softChime, poster: 0.58, duration: 3.4),
                StepCue(.soundRipple, .together, .softChime, poster: 0.55, duration: 3.4),
                StepCue(.graspContact, .child, .vinylPop, poster: 0.58, duration: 3.4),
            ]),
            activity("A18", backdrop: .playMat, prop: .softBall, mossX: 0.23, ottoX: 0.77, [
                StepCue(.offerArc, .adult, .clothSwish, poster: 0.62, duration: 3.4),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4, targetX: 0.42),
                StepCue(.graspContact, .together, .clothSwish, poster: 0.58, duration: 3.5, targetX: 0.50, targetY: 0.64),
            ]),
            // A19: Phase 1 Hero (Stacking Chunky Blocks)
            LivingActivityScript(
                code: "A19",
                backdrop: .woodenDesk,
                steps: [
                    LivingStepScript(
                        stepIndex: 0, phrase: .liftStack, lead: .adult, prop: .chunkyBlocks, secondaryProp: nil,
                        posterPhase: 0.56, duration: 3.4, audioAnchor: .woodTap,
                        mossAnchorX: 0.25, ottoAnchorX: 0.76, lampTargetX: 0.50, lampTargetY: 0.60
                    ),
                    LivingStepScript(
                        stepIndex: 1, phrase: .liftStack, lead: .child, prop: .chunkyBlocks, secondaryProp: nil,
                        posterPhase: 0.56, duration: 3.5, audioAnchor: .woodTap,
                        mossAnchorX: 0.26, ottoAnchorX: 0.77, lampTargetX: 0.50, lampTargetY: 0.54
                    ),
                    LivingStepScript(
                        stepIndex: 2, phrase: .tumbleCheer, lead: .together, prop: .chunkyBlocks, secondaryProp: nil,
                        posterPhase: 0.56, duration: 3.8, audioAnchor: .softChime,
                        mossAnchorX: 0.25, ottoAnchorX: 0.76, lampTargetX: 0.50, lampTargetY: 0.66
                    ),
                ]
            ),
            activity("A20", backdrop: .woodenDesk, prop: .peekCloth, secondary: .woodCup, mossX: 0.26, ottoX: 0.75, [
                StepCue(.gentleSway, .adult, .clothSwish, poster: 0.54, duration: 3.4),
                StepCue(.offerArc, .adult, .clothSwish, poster: 0.60, duration: 3.4),
                StepCue(.graspContact, .child, .woodTap, poster: 0.58, duration: 3.4),
            ]),
            activity("A21", backdrop: .woodenDesk, prop: .woodenRing, secondary: .softBall, mossX: 0.26, ottoX: 0.75, [
                StepCue(.offerArc, .adult, .woodTap, poster: 0.62, duration: 3.4),
                StepCue(.soundRipple, .adult, .softChime, poster: 0.54, duration: 3.4),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.58, duration: 3.5, targetX: 0.44),
            ]),
            activity("A22", backdrop: .woodenDesk, prop: .pictureBook, secondary: .leaf, mossX: 0.26, ottoX: 0.75, [
                StepCue(.offerArc, .adult, .woodTap, poster: 0.60, duration: 3.4),
                StepCue(.liftStack, .adult, .clothSwish, poster: 0.56, duration: 3.4),
                StepCue(.graspContact, .child, .woodTap, poster: 0.58, duration: 3.4),
            ]),
            activity("A23", backdrop: .cozyCorner, prop: .pictureBook, mossX: 0.27, ottoX: 0.74, [
                StepCue(.offerArc, .child, .clothSwish, poster: 0.60, duration: 3.4),
                StepCue(.soundRipple, .adult, .softChime, poster: 0.54, duration: 3.4),
                StepCue(.liftStack, .together, .clothSwish, poster: 0.56, duration: 3.4),
            ]),
            activity("A24", backdrop: .woodenDesk, prop: .crayon, mossX: 0.26, ottoX: 0.75, [
                StepCue(.offerArc, .adult, .woodTap, poster: 0.58, duration: 3.4),
                StepCue(.liftStack, .adult, .woodTap, poster: 0.58, duration: 3.5),
                StepCue(.graspContact, .child, .vinylPop, poster: 0.62, duration: 3.6, targetX: 0.48),
                StepCue(.soundRipple, .together, .softChime, poster: 0.55, duration: 3.4),
            ]),
            activity("A25", backdrop: .cozyCorner, prop: .doll, mossX: 0.27, ottoX: 0.74, [
                StepCue(.gentleSway, .adult, .clothSwish, poster: 0.54, duration: 3.5),
                StepCue(.graspContact, .child, .clothSwish, poster: 0.58, duration: 3.5, targetX: 0.46),
                StepCue(.soundRipple, .together, .softChime, poster: 0.54, duration: 3.4),
            ]),
            activity("A26", backdrop: .cozyCorner, prop: .lantern, mossX: 0.29, ottoX: 0.72, [
                StepCue(.soundRipple, .adult, .softChime, poster: 0.55, duration: 3.5),
                StepCue(.gentleSway, .together, .softChime, poster: 0.52, duration: 3.6),
                StepCue(.pauseWatch, .together, .vinylPop, poster: 0.56, duration: 3.4),
            ]),
            activity("A27", backdrop: .woodenDesk, prop: .ringStacker, secondary: .woodCup, mossX: 0.25, ottoX: 0.76, [
                StepCue(.liftStack, .adult, .woodTap, poster: 0.56, duration: 3.4),
                StepCue(.graspContact, .child, .woodTap, poster: 0.58, duration: 3.5),
                StepCue(.pauseWatch, .together, .vinylPop, poster: 0.56, duration: 3.4),
            ]),
            activity("A28", backdrop: .woodenDesk, prop: .woodCup, mossX: 0.26, ottoX: 0.75, [
                StepCue(.offerArc, .adult, .woodTap, poster: 0.60, duration: 3.4),
                StepCue(.graspContact, .adult, .woodTap, poster: 0.58, duration: 3.4),
                StepCue(.liftStack, .child, .woodTap, poster: 0.56, duration: 3.4),
                StepCue(.soundRipple, .together, .softChime, poster: 0.56, duration: 3.5),
            ]),

            // MARK: Year 3 (A29–A40)
            activity("A29", backdrop: .playMat, prop: .mat, mossX: 0.23, ottoX: 0.77, [
                StepCue(.offerArc, .adult, .clothSwish, poster: 0.58, duration: 3.4),
                StepCue(.liftStack, .adult, .woodTap, poster: 0.56, duration: 3.4),
                StepCue(.graspContact, .child, .vinylPop, poster: 0.58, duration: 3.5),
                StepCue(.gentleSway, .together, .softChime, poster: 0.54, duration: 3.4),
            ]),
            activity("A30", backdrop: .playMat, prop: .bell, mossX: 0.27, ottoX: 0.74, [
                StepCue(.soundRipple, .adult, .softChime, poster: 0.54, duration: 3.4),
                StepCue(.gentleSway, .together, .woodTap, poster: 0.52, duration: 3.5),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4),
            ]),
            activity("A31", backdrop: .cozyCorner, prop: .pictureBook, mossX: 0.28, ottoX: 0.73, [
                StepCue(.soundRipple, .adult, .softChime, poster: 0.55, duration: 3.5),
                StepCue(.liftStack, .adult, .clothSwish, poster: 0.56, duration: 3.4),
                StepCue(.graspContact, .child, .vinylPop, poster: 0.58, duration: 3.4),
            ]),
            activity("A32", backdrop: .playMat, prop: .softBall, mossX: 0.24, ottoX: 0.76, [
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4),
                StepCue(.offerArc, .together, .clothSwish, poster: 0.62, duration: 3.5),
                StepCue(.gentleSway, .together, .softChime, poster: 0.54, duration: 3.4),
            ]),
            activity("A33", backdrop: .woodenDesk, prop: .bridgeBlocks, mossX: 0.25, ottoX: 0.76, [
                StepCue(.offerArc, .together, .woodTap, poster: 0.60, duration: 3.4),
                StepCue(.liftStack, .together, .woodTap, poster: 0.58, duration: 3.6, targetY: 0.56),
                StepCue(.pauseWatch, .child, .softChime, poster: 0.58, duration: 3.5),
            ]),
            activity("A34", backdrop: .meadowPath, prop: .leaf, mossX: 0.26, ottoX: 0.75, [
                StepCue(.gentleSway, .together, .clothSwish, poster: 0.54, duration: 3.6),
                StepCue(.soundRipple, .adult, .softChime, poster: 0.56, duration: 3.5),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4),
            ]),
            activity("A35", backdrop: .cozyCorner, prop: .peekCloth, secondary: .woodCup, mossX: 0.27, ottoX: 0.74, [
                StepCue(.liftStack, .adult, .clothSwish, poster: 0.56, duration: 3.4),
                StepCue(.graspContact, .child, .clothSwish, poster: 0.58, duration: 3.4),
                StepCue(.offerArc, .together, .woodTap, poster: 0.60, duration: 3.4),
                StepCue(.soundRipple, .adult, .softChime, poster: 0.54, duration: 3.4),
            ]),
            activity("A36", backdrop: .woodenDesk, prop: .pictureBook, mossX: 0.26, ottoX: 0.75, [
                StepCue(.soundRipple, .adult, .softChime, poster: 0.54, duration: 3.4),
                StepCue(.liftStack, .child, .clothSwish, poster: 0.58, duration: 3.5),
                StepCue(.gentleSway, .together, .softChime, poster: 0.54, duration: 3.4),
            ]),
            activity("A37", backdrop: .windowSun, prop: .pictureBook, mossX: 0.27, ottoX: 0.74, [
                StepCue(.soundRipple, .adult, .softChime, poster: 0.55, duration: 3.5),
                StepCue(.gentleSway, .together, .clothSwish, poster: 0.54, duration: 3.4),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4),
            ]),
            activity("A38", backdrop: .cozyCorner, prop: .mirror, secondary: .pictureBook, mossX: 0.28, ottoX: 0.73, [
                StepCue(.offerArc, .adult, .clothSwish, poster: 0.60, duration: 3.5),
                StepCue(.soundRipple, .together, .softChime, poster: 0.55, duration: 3.4),
                StepCue(.graspContact, .child, .vinylPop, poster: 0.58, duration: 3.4),
            ]),
            activity("A39", backdrop: .meadowPath, prop: .bridgeBlocks, secondary: .softBall, mossX: 0.25, ottoX: 0.76, [
                StepCue(.pauseWatch, .adult, .vinylPop, poster: 0.56, duration: 3.4),
                StepCue(.offerArc, .together, .woodTap, poster: 0.60, duration: 3.5),
                StepCue(.gentleSway, .together, .softChime, poster: 0.54, duration: 3.4),
            ]),
            activity("A40", backdrop: .cozyCorner, prop: .lantern, mossX: 0.28, ottoX: 0.73, [
                StepCue(.gentleSway, .adult, .softChime, poster: 0.54, duration: 3.6),
                StepCue(.soundRipple, .together, .softChime, poster: 0.56, duration: 3.6),
                StepCue(.pauseWatch, .child, .vinylPop, poster: 0.56, duration: 3.4),
            ]),
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
