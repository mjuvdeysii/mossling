import SwiftUI

/// What was just recorded or started, said back at the top of the screen for a few seconds: the kind's sticker, one
/// line ("已记下 尿布 · 湿 · 14:05"), and 撤销. A one-tap record never happens silently.
/// On the timer page it sits at the foot instead, just above the button that ends — the top of that page is where the
/// two keep watch, and they are not to be covered.
struct ToastHost: ViewModifier {
    var bottom = false
    func body(content: Self.Content) -> some View {
        content.overlay(alignment: bottom ? .bottom : .top) { ToastSlot(bottom: bottom).padding(.bottom, bottom ? 84 : 0) }
    }
}

private struct ToastSlot: View {
    var bottom = false
    @Environment(JournalStore.self) private var j
    @Environment(\.accessibilityReduceMotion) private var reduce
    var body: some View {
        ZStack {
            if let t = j.toast {
                ToastBar(toast: t)
                    .transition(reduce ? AnyTransition.opacity : AnyTransition.move(edge: bottom ? .bottom : .top).combined(with: .opacity))
                    .id(t.id)
            }
        }
        .animation(.snappy, value: j.toast?.id)
    }
}

private struct ToastBar: View {
    @Environment(JournalStore.self) private var j
    let toast: Toast
    var body: some View {
        HStack(spacing: 10) {
            if toast.failed { IconTile(symbol: "exclamationmark.triangle.fill", color: Palette.danger, size: 30, round: true) }
            else { IconTile(symbol: LogType.symbol(toast.type), color: LogType.color(toast.type), size: 30, round: true) }
            Text(toast.text).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                .lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if toast.restore != nil {
                Button("撤销") { j.undo(toast) }
                    .font(.subheadline.weight(.bold)).buttonStyle(.borderless)
            }
        }
        .padding(.leading, 10).padding(.trailing, 16).padding(.vertical, 10)
        .glassEffect(.regular, in: Capsule())
        .padding(.horizontal, 16).padding(.vertical, 6)
        .onTapGesture { j.toast = nil }
        .task(id: toast.id) {
            UINotificationFeedbackGenerator().notificationOccurred(toast.failed ? .error : .success)
            UIAccessibility.post(notification: .announcement, argument: toast.text)
            try? await Task.sleep(for: .seconds(toast.failed ? 6 : toast.restore == nil ? 2 : 5))
            if j.toast?.id == toast.id { j.toast = nil }
        }
        .accessibilityElement(children: .combine)
    }
}

extension View {
    func toasts(bottom: Bool = false) -> some View { modifier(ToastHost(bottom: bottom)) }
}
