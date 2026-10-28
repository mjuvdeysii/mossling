import SwiftUI

/// The child, growing: Moss at seven stages (tools/picturebook.py MOSS_STAGES, tools/scene3d.py moss_figures) — asleep
/// in a leaf nest, lifting his face on the tummy mat, sitting up on a cushion, leaning forward on the way somewhere,
/// standing tall, stepping along, off the ground running — bigger each time, his sprig growing with him.
/// Between stages one gives way to the next with a spring; within a stage the child grows a little each month.
struct GrowingChild: View {
    let month: Int
    /// Change it to make the child giggle (a little jump).
    var giggle = 0
    @Environment(\.accessibilityReduceMotion) private var reduce

    static func stage(_ m: Int) -> Int { m < 3 ? 0 : m < 6 ? 1 : m < 9 ? 2 : m < 12 ? 3 : m < 18 ? 4 : m < 24 ? 5 : 6 }
    private static let starts = [0, 3, 6, 9, 12, 18, 24, 37]

    var body: some View {
        let st = Self.stage(month)
        let a = Self.starts[st], b = Self.starts[st + 1]
        let grow = 0.94 + 0.06 * Double(month - a) / Double(max(1, b - a - 1))
        ZStack {
            Figure(name: "child_\(st).webp")
                .id(st)
                .transition(reduce ? .opacity : .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity))
        }
        .scaleEffect(grow, anchor: .bottom)
        .animation(reduce ? nil : .spring(response: 0.5, dampingFraction: 0.62), value: month)
        .modifier(Lively(giggle: giggle))
        .accessibilityHidden(true)
    }
}

/// The child is alive: a slow sway from the feet and a breath, and a little jump of a giggle when `giggle` changes.
/// Still under Reduce Motion.
struct Lively: ViewModifier {
    let giggle: Int
    @Environment(\.accessibilityReduceMotion) private var reduce
    @State private var sway = false
    @State private var breath = false
    func body(content: Self.Content) -> some View {
        // two endless eased swings (not a per-frame clock re-running the view thirty times a second)
        content
            .rotationEffect(.degrees(reduce ? 0 : sway ? 2.4 : -2.4), anchor: .bottom)
            .scaleEffect(x: 1, y: reduce ? 1 : breath ? 1.014 : 0.986, anchor: .bottom)
            .onAppear {
                guard !reduce else { return }
                withAnimation(.easeInOut(duration: 1.96).repeatForever(autoreverses: true)) { sway = true }
                withAnimation(.easeInOut(duration: 1.37).repeatForever(autoreverses: true)) { breath = true }
            }
        .keyframeAnimator(initialValue: 0.0, trigger: giggle) { v, h in
            v.offset(y: reduce ? 0 : -h).rotationEffect(.degrees(reduce ? 0 : h * 0.4), anchor: .bottom)
        } keyframes: { _ in
            SpringKeyframe(16, duration: 0.16, spring: .snappy)
            SpringKeyframe(0, duration: 0.55, spring: .bouncy)
        }
    }
}

/// A picture with a transparent ground (a figure), fitted into its frame.
struct Figure: View {
    let name: String
    @Environment(\.displayScale) private var scale
    @Environment(\.girlArt) private var girl
    @State private var img: UIImage?
    var body: some View {
        let shown = ArtIndex.variant(name, girl: girl)
        GeometryReader { g in
            // Color.clear keeps the view non-empty so its task runs before the image exists
            let px = Int(max(g.size.width, g.size.height) * scale)
            let ready = img ?? ArtCache.shared.cached(shown, maxPixel: px)
            ZStack { Color.clear; if let ready { Image(uiImage: ready).resizable().scaledToFit() } }
                .frame(width: g.size.width, height: g.size.height)
                .task(id: shown) {
                    if ArtCache.shared.cached(shown, maxPixel: px) != nil { return }
                    let n = shown
                    img = await Task.detached(priority: .userInitiated) { ArtCache.shared.image(n, maxPixel: px) }.value
                }
        }
    }
}
