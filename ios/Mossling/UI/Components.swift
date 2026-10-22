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
                Palette.cardHigh
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

/// A section heading: an SF Symbol on a soft badge, the title in the serif, an optional line above it.
struct SectionHeader: View {
    let title: String
    var kicker: String? = nil
    var symbol: String? = nil
    var tint: Color = Palette.primary
    var body: some View {
        HStack(spacing: 12) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(tint)
                    .frame(width: 36, height: 36).background(tint.opacity(0.13), in: Circle())
            }
            VStack(alignment: .leading, spacing: 1) {
                if let kicker { Text(kicker).font(.caption).foregroundStyle(Palette.secondaryText) }
                Text(title).font(Typeface.serif(21, relativeTo: .title2)).foregroundStyle(Palette.text)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 8)
        .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
    }
}

/// The activity's code on a coloured tile; grows with the code so it is always whole.
struct CodeTile: View {
    let code: String
    var tint: Color = Palette.moss
    var size: CGFloat = 26
    var body: some View {
        Text(code).font(Typeface.numerals(size, relativeTo: .title2)).foregroundStyle(Palette.paper).lineLimit(1).fixedSize()
            .padding(.horizontal, size * 0.5).padding(.vertical, size * 0.3)
            .background(tint, in: RoundedRectangle(cornerRadius: size * 0.6, style: .continuous))
    }
}

/// A checkbox row: a record, not an assessment.
struct CheckRow: View {
    let text: String
    let on: Bool
    var tag: String? = nil
    let toggle: () -> Void
    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(on ? Palette.primary : Palette.secondaryText.opacity(0.6))
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
                VStack(alignment: .leading, spacing: 2) {
                    if let tag { Text(tag).font(.caption.weight(.semibold)).foregroundStyle(tag == "接种" ? Palette.rod : Palette.red) }
                    Text(text).font(.body).foregroundStyle(Palette.text).multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10).padding(.horizontal, 16).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: on)
    }
}

/// Content blocks (paragraphs, lists, tables). A table becomes one card per row — label above value — so nothing
/// needs scrolling sideways.
struct BlocksView: View {
    let blocks: [Block]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, b in
                switch b.type {
                case "list":
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array((b.items ?? []).enumerated()), id: \.offset) { _, t in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Circle().fill(Palette.primary).frame(width: 6, height: 6).alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                                Text(rich(t)).font(.body)
                            }
                        }
                    }
                case "table":
                    let head = b.head ?? []
                    VStack(spacing: 8) {
                        ForEach(Array((b.rows ?? []).enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: 6) {
                                if let first = row.first { Text(first).font(.headline) }
                                ForEach(Array(row.dropFirst().enumerated()), id: \.offset) { i, cell in
                                    VStack(alignment: .leading, spacing: 1) {
                                        if i + 1 < head.count { Text(head[i + 1]).font(.caption).foregroundStyle(Palette.secondaryText) }
                                        Text(rich(cell)).font(.subheadline)
                                    }
                                }
                            }
                            .card(Palette.cardLow, radius: 16, padding: 14)
                        }
                    }
                default:
                    Text(rich(b.text ?? "")).font(.body)
                }
            }
        }
    }
}

// MARK: formatting

func hm(_ t: Date) -> String { let c = Day.cal.dateComponents([.hour, .minute], from: t); return String(format: "%02d:%02d", c.hour!, c.minute!) }
func clock(_ s: TimeInterval) -> String {
    let n = Int(max(0, s)); let h = n / 3600
    return h > 0 ? String(format: "%d:%02d:%02d", h, n / 60 % 60, n % 60) : String(format: "%02d:%02d", n / 60, n % 60)
}
func minutesText(_ s: TimeInterval) -> String { let m = Int(max(0, s) / 60); return m >= 60 ? "\(m / 60) 小时 \(m % 60) 分" : "\(m) 分钟" }
