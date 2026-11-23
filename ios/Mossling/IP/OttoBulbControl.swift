import SwiftUI

/// Interactive Otto Golden Bulb pull-cord for the Home Lamp Desk (`TodayView`):
/// - Quick tap or gentle downward pull past detent opens the Bedside Lamp sanctuary (`onOpenLamp`).
/// - Sustained 2-second press triggers the app-wide `StyleShift` watercolor wash morphing 3D ↔ 2D.
struct OttoBulbControl: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.night) private var night
    @Environment(\.colorScheme) private var scheme

    let soundscapeActive: Bool
    @Binding var pullProgress: CGFloat
    let onOpenLamp: () -> Void

    @State private var pullY: CGFloat = 0
    @State private var globalFrame: CGRect = .zero
    @State private var isPressing = false
    @State private var pressStart: Date? = nil
    @State private var maxDragDistance: CGFloat = 0
    @State private var lastDetentStage = 0
    @State private var didLongTrigger = false
    @State private var holdProgress: CGFloat = 0
    @State private var holdTask: Task<Void, Never>? = nil

    private var lit: Bool { night || scheme == .dark || soundscapeActive || pullProgress > 0.1 }
    private var flat: Bool { ArtStyle.current == .flat }

    var body: some View {
        let beadRadius: CGFloat = 11.5
        let baseCord: CGFloat = 20
        let cordLength = baseCord + pullY

        ZStack(alignment: .top) {
            // Subtle brass mount plate + curved cord + Otto's golden bulb
            Canvas { ctx, size in
                let cx = size.width / 2
                let topY: CGFloat = 4
                let bulbCenter = CGPoint(x: cx, y: topY + cordLength)

                // Brass bracket stud at top
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - 5.5, y: topY - 4, width: 11, height: 8)),
                    with: .color(Palette.rodDeep)
                )

                // Suspended navy cord elongating smoothly on pull
                var cord = Path()
                cord.move(to: CGPoint(x: cx, y: topY))
                cord.addQuadCurve(
                    to: bulbCenter,
                    control: CGPoint(x: cx - 4 * (1 - pullProgress * 0.8), y: (topY + bulbCenter.y) * 0.5)
                )
                ctx.stroke(
                    cord,
                    with: .color(Palette.rod),
                    style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
                )

                // Radial amber glow behind golden bulb
                let glowAlpha = lit ? 0.52 + 0.30 * Double(pullProgress) : 0.14 + 0.55 * Double(pullProgress)
                let glowR: CGFloat = lit || pullProgress > 0.05 ? 25 + 8 * pullProgress : 16
                ctx.fill(
                    Path(ellipseIn: CGRect(x: bulbCenter.x - glowR, y: bulbCenter.y - glowR, width: glowR * 2, height: glowR * 2)),
                    with: .radialGradient(
                        Gradient(colors: [Palette.amber.opacity(glowAlpha), Palette.amber.opacity(0)]),
                        center: bulbCenter,
                        startRadius: 2,
                        endRadius: glowR
                    )
                )

                // 2-second watercolor-wash hold halo
                if holdProgress > 0.02 {
                    var arc = Path()
                    arc.addArc(
                        center: bulbCenter,
                        radius: beadRadius + 5,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * Double(holdProgress)),
                        clockwise: false
                    )
                    ctx.stroke(
                        arc,
                        with: .color(Palette.beadLight),
                        style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
                    )
                }

                // Golden bead body (vinyl matte gradient vs flat ink cut-paper)
                let bulbRect = CGRect(
                    x: bulbCenter.x - beadRadius,
                    y: bulbCenter.y - beadRadius,
                    width: beadRadius * 2,
                    height: beadRadius * 2
                )
                let bulbPath = Path(ellipseIn: bulbRect)
                if flat {
                    ctx.fill(bulbPath, with: .color(lit ? Palette.amber : Palette.bead))
                    ctx.stroke(bulbPath, with: .color(Palette.ink.opacity(0.35)), lineWidth: 1.5)
                } else {
                    ctx.fill(
                        bulbPath,
                        with: .radialGradient(
                            Gradient(colors: [Palette.beadLight, lit ? Palette.amber : Palette.bead, Color(hex: 0xB37D10)]),
                            center: CGPoint(x: bulbCenter.x - 3.5, y: bulbCenter.y - 3.5),
                            startRadius: 1,
                            endRadius: beadRadius * 1.4
                        )
                    )
                }

                // Matte highlight dot
                ctx.fill(
                    Path(ellipseIn: CGRect(x: bulbCenter.x - 5.5, y: bulbCenter.y - 6.0, width: 4.6, height: 3.8)),
                    with: .color(Palette.beadLight.opacity(flat ? 0.6 : 0.85))
                )
            }
        }
        .frame(width: 54, height: 78)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { globalFrame = $0 }
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isPressing {
                        isPressing = true
                        pressStart = Date()
                        maxDragDistance = 0
                        lastDetentStage = 0
                        didLongTrigger = false
                        startHoldMonitor()
                    }
                    let dist = hypot(value.translation.width, value.translation.height)
                    maxDragDistance = max(maxDragDistance, dist)

                    // Moving past 8pt cancels 2s watercolor wash hold and enters tactile pull-cord mode
                    if dist > 8 {
                        cancelHoldMonitor()
                        let preset = app.bulbPreset
                        let down = max(0, value.translation.height)
                        let elastic = min(preset.maxStretch, down * preset.resistance)
                        pullY = elastic
                        let p = min(1.0, elastic / preset.triggerThreshold)
                        pullProgress = p

                        let stage = p >= 1.0 ? 3 : p >= 0.65 ? 2 : p >= 0.30 ? 1 : 0
                        if stage > lastDetentStage {
                            lastDetentStage = stage
                            if stage == 3 {
                                TactileEngine.shared.beadClick()
                            } else {
                                TactileEngine.shared.dimmerTick()
                            }
                        }
                    }
                }
                .onEnded { value in
                    let start = pressStart ?? Date()
                    let elapsed = Date().timeIntervalSince(start)
                    let dragged = max(maxDragDistance, hypot(value.translation.width, value.translation.height))
                    let triggeredByPull = pullY >= app.bulbPreset.triggerThreshold
                    let triggeredByTap = !didLongTrigger && dragged < 10 && elapsed < 0.45

                    cancelHoldMonitor()
                    isPressing = false
                    pressStart = nil
                    lastDetentStage = 0

                    withAnimation(reduce ? nil : app.bulbPreset.springAnimation) {
                        pullY = 0
                        pullProgress = 0
                    }

                    if !didLongTrigger && (triggeredByPull || triggeredByTap) {
                        TactileEngine.shared.beadClick()
                        onOpenLamp()
                    }
                    didLongTrigger = false
                }
        )
        .onDisappear { cancelHoldMonitor() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t("Otto 金色灯珠", "Otto's Golden Lamp Bulb"))
        .accessibilityHint(L10n.t("轻按或向下轻拉打开床头夜灯；长按两秒切换立体与平面画风", "Tap or pull down to open Bedside Lamp; hold two seconds to switch between 3D and 2D art"))
        .accessibilityAction(named: L10n.t("打开床头夜灯", "Open Bedside Lamp")) {
            onOpenLamp()
        }
        .accessibilityAction(named: L10n.t("切换画风", "Switch Art Style")) {
            let anchor = globalFrame.width > 1 ? globalFrame : CGRect(x: 320, y: 240, width: 54, height: 78)
            StyleShift.shared.toggleArtStyle(from: anchor, app: app, reduce: reduce)
        }
    }

    private func startHoldMonitor() {
        holdTask?.cancel()
        holdProgress = 0
        holdTask = Task { @MainActor in
            let steps = 40
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(50))
                if Task.isCancelled || !isPressing || maxDragDistance > 10 { return }
                holdProgress = CGFloat(step) / CGFloat(steps)
                if step == 13 || step == 27 {
                    TactileEngine.shared.dimmerTick()
                }
            }
            guard isPressing, maxDragDistance <= 10, !didLongTrigger else { return }
            didLongTrigger = true
            holdProgress = 0
            TactileEngine.shared.goldChime()
            let anchor = globalFrame.width > 1 ? globalFrame : CGRect(x: 320, y: 240, width: 54, height: 78)
            StyleShift.shared.toggleArtStyle(from: anchor, impact: CGPoint(x: 0.5, y: 0.65), app: app, reduce: reduce)
        }
    }

    private func cancelHoldMonitor() {
        holdTask?.cancel()
        holdTask = nil
        if holdProgress > 0 {
            withAnimation(.easeOut(duration: 0.15)) { holdProgress = 0 }
        }
    }
}

/// Soft warm conical amber wash cast diagonally down-right from Otto's Golden Bulb onto the Lamp Desk play hero.
struct LampConeOverlay: View {
    let intensity: CGFloat
    let night: Bool

    var body: some View {
        let strength = night ? (0.14 + 0.16 * intensity) : (0.04 + 0.14 * intensity)
        GeometryReader { geo in
            let apex = CGPoint(x: 43, y: 0)
            Path { p in
                p.move(to: CGPoint(x: max(0, apex.x - 20), y: 0))
                p.addLine(to: CGPoint(x: apex.x + 22, y: 0))
                p.addLine(to: CGPoint(x: geo.size.width * 0.92, y: geo.size.height))
                p.addLine(to: CGPoint(x: 0, y: geo.size.height))
                p.closeSubpath()
            }
            .fill(
                RadialGradient(
                    colors: [
                        Palette.amber.opacity(strength),
                        Palette.amber.opacity(strength * 0.32),
                        Palette.amber.opacity(0),
                    ],
                    center: UnitPoint(x: 0.12, y: 0.04),
                    startRadius: 8,
                    endRadius: max(geo.size.width, geo.size.height) * 0.92
                )
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
