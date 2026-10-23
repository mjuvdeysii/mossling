import SwiftUI

/// The baby's picture with the chosen companion cuddled up against the frame, leaning in. Choose the other companion and it
/// comes over and takes the hug; tap the picture and the companion hugs the baby tighter — eyes closed, a squeeze, a
/// heart — with a soft haptic. The companion keeps the baby company, so it is drawn holding the baby's picture.
struct HuggedAvatar: View {
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduce
    @Environment(\.lamp) private var lamp
    var size: CGFloat = 72
    @State private var hugging = false
    @State private var hugs = 0

    var body: some View {
        let kind = app.companion
        let c = size * 0.74
        // the companion's box: its body overlaps the frame's right edge
        let box = CGRect(x: size * 0.6, y: size - c * 0.86, width: c, height: c)
        ZStack(alignment: .topLeading) {
            Figure(name: "child_\(GrowingChild.stage(app.babyMonth ?? 0)).webp")
                .modifier(Lively(giggle: hugs))
                .scaleEffect(1.3, anchor: .bottom)   // the figures carry a margin; fill the frame with the child
                .offset(y: size * 0.06)
                .frame(width: size, height: size)
                .background(Crayon.sunflower.opacity(lamp ? 0.32 : 0.2), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 3))
                .clipShape(Circle())
                .scaleEffect(hugging ? 0.95 : 1, anchor: .trailing)
                .rotationEffect(.degrees(hugging ? 5 : 0), anchor: .bottomTrailing)   // the frame leans into the cuddle

            Creature(kind: kind, mood: hugging ? .happy : .open, look: CGPoint(x: -0.9, y: 0.35), lid: hugging ? 1 : nil,
                     lean: hugging ? -16 : -6, poke: false, arms: .rest)
                .frame(width: c, height: c)
                .offset(x: box.minX, y: box.minY)
                .id(kind)
                .transition(reduce ? AnyTransition.opacity : AnyTransition.asymmetric(insertion: AnyTransition.offset(x: size * 0.8).combined(with: AnyTransition.opacity), removal: AnyTransition.opacity))

            // a heart between the two, for each hug
            Figure(name: "ic_heart_fill.webp")
                .frame(width: size * 0.3, height: size * 0.3)
                .keyframeAnimator(initialValue: Pop(), trigger: hugs) { v, p in
                    v.scaleEffect(p.scale).opacity(p.opacity).offset(y: p.rise)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) { SpringKeyframe(1.1, duration: 0.3, spring: .bouncy); LinearKeyframe(0.9, duration: 0.9) }
                    KeyframeTrack(\.opacity) { LinearKeyframe(1, duration: 0.15); LinearKeyframe(1, duration: 0.6); LinearKeyframe(0, duration: 0.45) }
                    KeyframeTrack(\.rise) { CubicKeyframe(-size * 0.28, duration: 1.2) }
                }
                .offset(x: size * 0.62, y: -size * 0.02)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .frame(width: size * 1.4, height: size * 1.1, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { hug() }
        .onChange(of: kind) { _, _ in
            Task { try? await Task.sleep(for: .milliseconds(350)); hug() }   // it comes over first, then hugs
        }
        .onChange(of: app.drawsGirl) { _, _ in hug() }   // a new look for the baby: a hug to welcome it
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: hugs)
        .accessibilityElement()
        .accessibilityLabel("\(kind.rawValue) 抱着宝宝")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { hug() }
    }

    private func hug() {
        hugs += 1
        guard !reduce else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { hugging = true }
        Task {
            try? await Task.sleep(for: .milliseconds(1100))
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { hugging = false }
        }
    }

    private struct Pop { var scale = 0.0; var opacity = 0.0; var rise = 0.0 }
}
