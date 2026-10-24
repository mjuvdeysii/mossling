import SwiftUI

/// What was just recorded or started, said back at the top of the screen for a few seconds: the kind's sticker, one
/// line ("已记下 尿布 · 湿 · 14:05"), and 撤销. A one-tap record never happens silently.
struct ToastHost: ViewModifier {
    @Environment(JournalStore.self) private var j
    @Environment(\.accessibilityReduceMotion) private var reduce

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let t = j.toast {
                HStack(spacing: 10) {
                    IconTile(symbol: LogType.symbol(t.type), color: LogType.color(t.type), size: 30, round: true)
                    Text(t.text).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if t.restore != nil {
                        Button("撤销") { withAnimation(.snappy) { j.undo(t) } }
                            .font(.subheadline.weight(.bold)).buttonStyle(.borderless)
                    }
                }
                .padding(.leading, 10).padding(.trailing, 16).padding(.vertical, 10)
                .glassEffect(.regular, in: Capsule())
                .padding(.horizontal, 16).padding(.top, 6)
                .transition(reduce ? .opacity : .move(edge: .top).combined(with: .opacity))
                .id(t.id)
                .task(id: t.id) {
                    try? await Task.sleep(for: .seconds(t.restore == nil ? 2 : 5))
                    withAnimation(.snappy) { if j.toast?.id == t.id { j.toast = nil } }
                }
                .onTapGesture { withAnimation(.snappy) { j.toast = nil } }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isStaticText)
                .onAppear { UIAccessibility.post(notification: .announcement, argument: t.text) }
            }
        }
        .animation(.snappy, value: j.toast?.id)
        .sensoryFeedback(.success, trigger: j.toast?.id) { _, new in new != nil }
    }
}

extension View {
    func toasts() -> some View { modifier(ToastHost()) }
}
