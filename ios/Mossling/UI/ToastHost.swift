import SwiftUI

/// What was just recorded or started, said back at the top of the screen for a few seconds: the kind's sticker, one
/// line ("已记下 尿布 · 湿 · 14:05"), and 撤销. A one-tap record never happens silently.
/// On the timer page it sits at the foot instead, just above the button that ends — the top of that page is where the
/// two keep watch, and they are not to be covered.
struct ToastHost: ViewModifier {
    var bottom = false
    var suppressed = false
    func body(content: Self.Content) -> some View {
        content.overlay(alignment: bottom ? .bottom : .top) {
            ToastSlot(bottom: bottom, suppressed: suppressed).padding(.bottom, bottom ? 84 : 0)
        }
    }
}

private struct ToastSlot: View {
    var bottom = false
    var suppressed = false
    @Environment(JournalStore.self) private var j
    @Environment(\.accessibilityReduceMotion) private var reduce
    var body: some View {
        ZStack {
            if let t = j.toast, !suppressed, bottom ? (j.focus != nil) : (j.focus == nil) {
                ToastBar(toast: t)
                    .transition(reduce ? AnyTransition.opacity : AnyTransition.move(edge: bottom ? .bottom : .top).combined(with: .opacity))
                    .id(t.id)
            }
        }
        .animation(reduce ? nil : .snappy, value: j.toast?.id)
        .onChange(of: suppressed, initial: true) { _, isSuppressed in
            if isSuppressed && j.toast != nil {
                j.toast = nil
            }
        }
    }
}

private struct ToastBar: View {
    @Environment(JournalStore.self) private var j
    @Environment(\.dynamicTypeSize) private var typeSize
    let toast: Toast
    var body: some View {
        let glassShape = typeSize.isAccessibilitySize
            ? AnyShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            : AnyShape(Capsule())
        HStack(spacing: 10) {
            if toast.failed { IconTile(symbol: "exclamationmark.triangle.fill", color: Palette.danger, size: 30, round: true) }
            else { IconTile(symbol: LogType.symbol(toast.type), color: LogType.color(toast.type), size: 30, round: true) }
            Text(toast.text).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                .lineLimit(typeSize.isAccessibilitySize ? 4 : 2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if toast.restore != nil || toast.deltaUndo != nil {
                Button(L10n.t("撤销", "Undo")) { j.undo(toast) }
                    .font(.subheadline.weight(.bold))
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 10)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
        .padding(.leading, 10).padding(.trailing, 10).padding(.vertical, 6)
        .glassEffect(.regular, in: glassShape)
        .padding(.horizontal, typeSize.isAccessibilitySize ? 12 : 16).padding(.vertical, 6)
        .gesture(
            DragGesture(minimumDistance: 16).onEnded { value in
                if abs(value.translation.height) > 12 { j.toast = nil }
            }
        )
        .task(id: toast.id) {
            if !TactileEngine.shared.quietNight {
                UINotificationFeedbackGenerator().notificationOccurred(toast.failed ? .error : .success)
            }
            UIAccessibility.post(notification: .announcement, argument: toast.text)
            let baseSeconds: Double = toast.failed ? 6 : (toast.restore == nil ? 3.5 : 5)
            let seconds: Double = UIAccessibility.isVoiceOverRunning ? max(15, baseSeconds) : baseSeconds
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            if j.toast?.id == toast.id { j.toast = nil }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAction(.escape) {
            j.toast = nil
        }
        .accessibilityAction(named: L10n.t("关闭提示", "Dismiss")) { j.toast = nil }
    }
}

extension View {
    func toasts(bottom: Bool = false, suppressed: Bool = false) -> some View {
        modifier(ToastHost(bottom: bottom, suppressed: suppressed))
    }
}
