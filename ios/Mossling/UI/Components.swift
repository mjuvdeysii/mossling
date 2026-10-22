import SwiftUI
import ImageIO

// MARK: pictures

/// Decodes the pictures in art/ at the size they are shown, off the main thread, and keeps a few in memory.
final class ArtCache {
    static let shared = ArtCache()
    private let cache = NSCache<NSString, UIImage>()
    init() { cache.totalCostLimit = 48 * 1024 * 1024 }

    func image(_ name: String, maxPixel: Int) -> UIImage? {
        let bucket = max(256, 1 << Int(ceil(log2(Double(max(1, maxPixel))))))
        let key = "\(name)@\(bucket)" as NSString
        if let i = cache.object(forKey: key) { return i }
        guard let url = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "art"),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: bucket,
                                     kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceShouldCacheImmediately: true]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        let img = UIImage(cgImage: cg)
        cache.setObject(img, forKey: key, cost: cg.width * cg.height * 4)
        return img
    }
}

/// One illustration at its own proportions: a quiet placeholder while it decodes, then a short fade.
struct ArtView: View {
    let name: String
    var label: String = ""
    var radius: CGFloat = 18
    @Environment(\.displayScale) private var scale
    @State private var img: UIImage?

    var body: some View {
        GeometryReader { g in
            ZStack {
                Palette.fill
                if let img { Image(uiImage: img).resizable().scaledToFill().transition(.opacity) }
            }
            .frame(width: g.size.width, height: g.size.height)
            .task(id: name) {
                let px = Int(g.size.width * scale)
                let n = name
                let i = await Task.detached(priority: .userInitiated) { ArtCache.shared.image(n, maxPixel: px) }.value
                withAnimation(.easeOut(duration: 0.18)) { img = i }
            }
        }
        .aspectRatio(ArtIndex.shared.ratio(name), contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isImage)
    }
}

// MARK: text

/// "**bold**" inside content text, as Markdown.
func rich(_ s: String) -> AttributedString {
    (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(s)
}

/// A grouped box: rows on one rounded surface, an optional heading above and a note below. The one container used for
/// lists inside scrolling pages, so every page groups the same way.
struct Box<Content: View>: View {
    var title: String? = nil
    var detail: String? = nil
    var footer: String? = nil
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { SectionTitle(title: title, detail: detail) }
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            if let footer { Text(footer).font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 16) }
        }
    }
}

/// A row in a box: an icon tile, a title, an optional line under it, something at the end; a hairline under it unless
/// it is the last.
struct BoxRow<Trailing: View>: View {
    var symbol: String? = nil
    var color: Color = Palette.accent
    let title: String
    var text: String? = nil
    var last = false
    var opens = false
    @ViewBuilder var trailing: Trailing
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                if let symbol { IconTile(symbol: symbol, color: color) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.body).foregroundStyle(.primary).multilineTextAlignment(.leading)
                    if let text, !text.isEmpty { Text(rich(text)).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailing
                if opens { Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary) }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .contentShape(Rectangle())
            if !last { Divider().padding(.leading, symbol == nil ? 16 : 60) }
        }
    }
}
extension BoxRow where Trailing == EmptyView {
    init(symbol: String? = nil, color: Color = Palette.accent, title: String, text: String? = nil, last: Bool = false, opens: Bool = false) {
        self.init(symbol: symbol, color: color, title: title, text: text, last: last, opens: opens) { EmptyView() }
    }
}

/// A checkbox row: a record, not an assessment.
struct CheckRow: View {
    let text: String
    let on: Bool
    var tag: String? = nil
    var last = false
    let toggle: () -> Void
    var body: some View {
        Button(action: toggle) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.title2)
                        .foregroundStyle(on ? Palette.accent : Color(uiColor: .tertiaryLabel))
                        .contentTransition(.symbolEffect(.replace))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(text).font(.body).foregroundStyle(.primary).multilineTextAlignment(.leading)
                        if let tag { Text(tag).font(.footnote).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
                if !last { Divider().padding(.leading, 56) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: on)
    }
}

/// Content blocks (paragraphs, lists, tables). A table becomes one box per row — label above value — so nothing
/// needs scrolling sideways.
struct BlocksView: View {
    let blocks: [Block]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in
                switch b.type {
                case "list":
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array((b.items ?? []).enumerated()), id: \.offset) { _, t in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Circle().fill(Palette.accent).frame(width: 6, height: 6).alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                                Text(rich(t)).font(.body)
                            }
                        }
                    }
                case "table":
                    let head = b.head ?? []
                    VStack(spacing: 10) {
                        ForEach(Array((b.rows ?? []).enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: 0) {
                                if let first = row.first { Text(first).font(.headline).padding(.horizontal, 16).padding(.vertical, 12) }
                                ForEach(Array(row.dropFirst().enumerated()), id: \.offset) { i, cell in
                                    Divider().padding(.leading, 16)
                                    VStack(alignment: .leading, spacing: 2) {
                                        if i + 1 < head.count { Text(head[i + 1]).font(.footnote).foregroundStyle(.secondary) }
                                        Text(rich(cell)).font(.body)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 10)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                    }
                default:
                    Text(rich(b.text ?? "")).font(.body)
                }
            }
        }
    }
}

/// A picture that fills its frame (cropped to it), for headers and tiles.
struct ArtFill: View {
    let name: String
    var label: String = ""
    @Environment(\.displayScale) private var scale
    @State private var img: UIImage?
    var body: some View {
        GeometryReader { g in
            ZStack {
                Palette.fill
                if let img { Image(uiImage: img).resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped().transition(.opacity) }
            }
            .task(id: name) {
                let px = Int(max(g.size.width, g.size.height) * scale)
                let n = name
                let i = await Task.detached(priority: .userInitiated) { ArtCache.shared.image(n, maxPixel: px) }.value
                withAnimation(.easeOut(duration: 0.18)) { img = i }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isImage)
        .accessibilityHidden(label.isEmpty)
    }
}

// MARK: formatting

func hm(_ t: Date) -> String { let c = Day.cal.dateComponents([.hour, .minute], from: t); return String(format: "%02d:%02d", c.hour!, c.minute!) }
func clock(_ s: TimeInterval) -> String {
    let n = Int(max(0, s)); let h = n / 3600
    return h > 0 ? String(format: "%d:%02d:%02d", h, n / 60 % 60, n % 60) : String(format: "%02d:%02d", n / 60, n % 60)
}
func minutesText(_ s: TimeInterval) -> String { let m = Int(max(0, s) / 60); return m >= 60 ? "\(m / 60) 小时 \(m % 60) 分" : "\(m) 分钟" }

// MARK: navigation

extension EnvironmentValues {
    /// The namespace of the navigation stack a view is in, for zoom transitions from a card to its page.
    @Entry var zoomNS: Namespace.ID? = nil
}

/// Marks a card as the place its page zooms out of (and back into, when one swipes back or drags the page down).
private struct ZoomSource<ID: Hashable>: ViewModifier {
    let id: ID
    @Environment(\.zoomNS) private var ns
    @ViewBuilder func body(content: Self.Content) -> some View {
        if let ns { content.matchedTransitionSource(id: id, in: ns) } else { content }
    }
}
/// A page that zooms out of its card.
private struct ZoomDestination<ID: Hashable>: ViewModifier {
    let id: ID
    @Environment(\.zoomNS) private var ns
    @ViewBuilder func body(content: Self.Content) -> some View {
        if let ns { content.navigationTransition(.zoom(sourceID: id, in: ns)) } else { content }
    }
}
extension View {
    func zoomSource(_ id: some Hashable) -> some View { modifier(ZoomSource(id: id)) }
    func zoomDestination(_ id: some Hashable) -> some View { modifier(ZoomDestination(id: id)) }
}

/// A small ring for progress: how much of something has been recorded.
struct Ring: View {
    let done: Int, total: Int
    var color: Color = Palette.accent
    var size: CGFloat = 26
    var body: some View {
        let f = total == 0 ? 0 : Double(done) / Double(total)
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: size * 0.16)
            Circle().trim(from: 0, to: f).stroke(color, style: StrokeStyle(lineWidth: size * 0.16, lineCap: .round)).rotationEffect(.degrees(-90))
            if f >= 1 { Image(systemName: "checkmark").font(.system(size: size * 0.4, weight: .bold)).foregroundStyle(color) }
        }
        .frame(width: size, height: size)
        .animation(.snappy, value: done)
        .accessibilityElement().accessibilityLabel("已记下 \(done) / \(total)")
    }
}
