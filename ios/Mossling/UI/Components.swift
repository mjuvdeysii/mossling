import SwiftUI
import ImageIO

// MARK: pictures

/// The two ways the app's pictures can be drawn. 立体: matte soft-vinyl 3D (tools/scene3d.py, icons3d.py), the
/// default. 平面: the picture book's 2D drawings (tools/picturebook.py, stickers.py), kept under the same names with
/// "2d_" in front; a picture with no 2D drawing shows its 3D one.
enum ArtStyle: String, CaseIterable {
    case vinyl = "3d", flat = "2d"
    nonisolated(unsafe) static var current: ArtStyle = .vinyl
    var title: String { self == .vinyl ? "立体" : "平面" }
    static func resolve(_ name: String) -> String {
        if name.hasPrefix("3d:") { return String(name.dropFirst(3)) }   // asked for the 3D drawing, whatever the style
        guard current == .flat else { return name }
        let n = "2d_" + name
        return ArtIndex.shared.size[n] == nil ? name : n
    }
}

/// Decodes the pictures in art/ at the size they are shown, off the main thread, and keeps a few in memory.
final class ArtCache {
    static let shared = ArtCache()
    private let cache = NSCache<NSString, UIImage>()
    // enough for a page of pictures and the page behind it, so going back never decodes them again
    init() { cache.totalCostLimit = 160 * 1024 * 1024 }

    private static func key(_ name: String, _ maxPixel: Int) -> NSString {
        let bucket = max(256, 1 << Int(ceil(log2(Double(max(1, maxPixel))))))
        return "\(name)@\(bucket)" as NSString
    }

    /// What a view's loading task is keyed by: the picture and the size bucket it is drawn at (a view that grows past
    /// its first size loads the sharper one).
    static func token(_ name: String, _ maxPixel: Int) -> String { key(name, maxPixel) as String }

    /// The picture if it is already decoded, without decoding: for drawing at once, with no placeholder and no fade.
    func cached(_ asked: String, maxPixel: Int) -> UIImage? {
        cache.object(forKey: Self.key(ArtStyle.resolve(asked), maxPixel))
    }

    func image(_ asked: String, maxPixel: Int) -> UIImage? {
        let name = ArtStyle.resolve(asked)
        let bucket = max(256, 1 << Int(ceil(log2(Double(max(1, maxPixel))))))
        let key = Self.key(name, maxPixel)
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

extension ArtIndex {
    /// The girl's version of a picture with the child in it, when there is one.
    static func variant(_ name: String, girl: Bool) -> String {
        // the 3D pictures are acted by Moss and Otto: one cast for every child, so no girl's set
        // one cast (Moss and Otto) in both worlds: no girl's set
        guard girl, false, name.hasSuffix(".webp") else { return name }
        let g = String(name.dropLast(5)) + "_g.webp"
        return shared.size[g] == nil ? name : g
    }
}

/// One illustration at its own proportions: a quiet placeholder while it decodes, then a short fade.
struct ArtView: View {
    let name: String
    var label: String = ""
    var radius: CGFloat = 18
    @Environment(\.displayScale) private var scale
    @Environment(\.girlArt) private var girl
    @State private var img: UIImage?

    var body: some View {
        let shown = ArtIndex.variant(name, girl: girl)
        GeometryReader { g in
            let px = Int(g.size.width * scale)
            // already decoded (coming back to a page): drawn at once, no placeholder, no fade
            let ready = Perf.noArt ? nil : img ?? ArtCache.shared.cached(shown, maxPixel: px)
            ZStack {
                Palette.fill
                if let ready { Image(uiImage: ready).resizable().scaledToFill().transition(.opacity) }
                NightDim()
            }
            .frame(width: g.size.width, height: g.size.height)
            .task(id: ArtCache.token(shown, px)) {
                // held by the view (see Figure): an evicted cache must not leave the picture blank
                if let c = ArtCache.shared.cached(shown, maxPixel: px) { img = c; return }
                let n = shown
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
                .printCard(radius: 26)
            if let footer { Text(footer).font(.footnote).foregroundStyle(Palette.secondaryText).padding(.horizontal, 16) }
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
                    if let text, !text.isEmpty { Text(rich(text)).font(.subheadline).foregroundStyle(Palette.secondaryText).multilineTextAlignment(.leading) }
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
                        if let tag { Text(tag).font(.footnote).foregroundStyle(Palette.secondaryText) }
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
                    TableBlock(head: b.head ?? [], rows: b.rows ?? [])
                default:
                    Text(rich(b.text ?? "")).font(.body)
                }
            }
        }
    }
}

/// A table of a topic, one card per row. When its rows are age groups (0–3个月, 12–23个月, 满36个月起…), the child's own
/// group is open and the others fold to one line each (tap to open), so the page is read in one screen; a label and a
/// short value share one line.
struct TableBlock: View {
    @Environment(AppModel.self) private var app
    let head: [String]
    let rows: [[String]]
    @State private var open: Set<Int> = []
    @State private var seeded = false

    /// The months an age-group heading covers, or nil when the heading is not an age group.
    static func months(_ t: String) -> ClosedRange<Int>? {
        let ns = t.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard t.contains("月") || t.contains("岁"), let a = ns.first else { return nil }
        let k = t.contains("岁") && !t.contains("月") ? 12 : 1
        if t.contains("起") || t.contains("以上") { return (a * k)...999 }
        return (a * k)...((ns.count > 1 ? ns[1] : a) * k)
    }

    var body: some View {
        let ranges = rows.map { Self.months($0.first ?? "") }
        let grouped = rows.count >= 3 && ranges.allSatisfy { $0 != nil }
        let m = app.babyMonth ?? 0
        let mine: Int? = grouped ? (ranges.firstIndex { $0!.contains(m) } ?? 0) : nil
        VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                let shown = !grouped || open.contains(i)
                VStack(alignment: .leading, spacing: 0) {
                    if let first = row.first {
                        Button {
                            guard grouped else { return }
                            withAnimation(.snappy) { if open.contains(i) { open.remove(i) } else { open.insert(i) } }
                        } label: {
                            HStack(spacing: 8) {
                                Text(first).font(.headline).foregroundStyle(.primary)
                                if i == mine {
                                    Text("宝宝现在").font(.caption2.weight(.bold)).foregroundStyle(Color(hex: 0x4A3300))
                                        .padding(.horizontal, 7).padding(.vertical, 2).background(Capsule().fill(Palette.bead))
                                }
                                Spacer(minLength: 0)
                                if grouped {
                                    Image(systemName: "chevron.down").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
                                        .rotationEffect(.degrees(shown ? 180 : 0))
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 12).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!grouped)
                        .accessibilityAddTraits(grouped ? .isButton : [])
                    }
                    if shown {
                        ForEach(Array(row.dropFirst().enumerated()), id: \.offset) { j, cell in
                            Divider().padding(.leading, 16)
                            let label = j + 1 < head.count ? head[j + 1] : ""
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    if !label.isEmpty { Text(label).font(.footnote).foregroundStyle(Palette.secondaryText).fixedSize() }
                                    Spacer(minLength: 8)
                                    Text(rich(cell)).font(.body).multilineTextAlignment(.trailing).fixedSize()
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    if !label.isEmpty { Text(label).font(.footnote).foregroundStyle(Palette.secondaryText) }
                                    Text(rich(cell)).font(.body).fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 9)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .printCard(radius: 22)
            }
        }
        .onAppear { if !seeded, let mine { open = [mine]; seeded = true } }
    }
}

/// A picture that fills its frame (cropped to it), for headers and tiles.
/// In dark mode the pictures' paper is toned down so it does not glare during night feeds.
struct NightDim: View {
    @Environment(\.colorScheme) private var scheme
    // at night a picture is printed on the same paper under the same lamp: the lamp's blue multiplied in (the paper
    // ground goes dusky instead of glaring as a pale box), then a breath of amber light over it
    var body: some View {
        if scheme == .dark {
            ZStack {
                Palette.lampPage.opacity(0.5).blendMode(.multiply)
                Palette.amber.opacity(0.1).blendMode(.softLight)
            }
            .allowsHitTesting(false)
        }
    }
}

struct ArtFill: View {
    let name: String
    var label: String = ""
    @Environment(\.displayScale) private var scale
    @Environment(\.girlArt) private var girl
    @State private var img: UIImage?
    var body: some View {
        let shown = ArtIndex.variant(name, girl: girl)
        GeometryReader { g in
            ZStack {
                Palette.fill
                if let img { Image(uiImage: img).resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped().transition(.opacity) }
                NightDim()
            }
            .task(id: shown) {
                let px = Int(max(g.size.width, g.size.height) * scale)
                let n = shown
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
    /// The child in the pictures is drawn as a girl (the `_g` pictures).
    @Entry var girlArt: Bool = false
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

// MARK: layout

/// A section laid out with a lead (ios/DESIGN.md §3 · 版面): the first item is the lead, full width and larger; the
/// rest follow in pairs; if one is left over it becomes a compact full-width row, so no row is ever half empty. At the
/// largest text sizes everything stacks in one column.
struct LeadGrid<Item: Identifiable, Lead: View, Cell: View, Row: View>: View {
    let items: [Item]
    @ViewBuilder let lead: (Item) -> Lead
    @ViewBuilder let cell: (Item) -> Cell
    @ViewBuilder let row: (Item) -> Row
    @Environment(\.dynamicTypeSize) private var type
    var body: some View {
        VStack(spacing: 12) {
            if let first = items.first { lead(first) }
            let rest = Array(items.dropFirst())
            if type.isAccessibilitySize {
                ForEach(rest) { row($0) }
            } else {
                let paired = rest.count / 2 * 2
                if paired > 0 {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(rest.prefix(paired)) { cell($0) }
                    }
                }
                if rest.count % 2 == 1, let last = rest.last { row(last) }
            }
        }
    }
}

// MARK: 余影 — afterimages

/// A value that changes leaves a soft afterimage of what it was: each character that changes lifts away, blurring
/// and fading in the kind's colour, while the new one settles in sharp — after the old one has gone, so two glyphs are
/// never seen on top of each other. The more significant the place (minutes over
/// seconds, hours over minutes), the further and larger its afterimage, so a minute turning over is felt more than a
/// second. Every live clock and every count that a tap changes uses it (ios/DESIGN.md §3, 余影). With Reduce Motion
/// the value simply changes.
struct Ticking: View {
    let text: String
    /// The afterimage's colour; nil keeps the text's own.
    var tint: Color? = nil
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        let chars = Array(text)
        // places counted from the right among digits: 0 for the last digit, 1 for the one before, …
        let place: [Int] = {
            var out = Array(repeating: 0, count: chars.count), k = 0
            for i in chars.indices.reversed() { out[i] = k; if chars[i].isNumber { k += 1 } }
            return out
        }()
        HStack(spacing: 0) {
            ForEach(chars.indices, id: \.self) { i in
                let c = String(chars[i])
                ZStack {
                    Text(c)
                        .id("\(i)·\(c)")
                        .transition(reduce ? .identity : .afterimage(place: place[i], tint: tint))
                }
                .fixedSize()   // a character never shrinks or clips (one Text per character: squeezed, each would truncate)
            }
        }
        .fixedSize()
        .monospacedDigit()
        .animation(reduce ? nil : .easeOut(duration: 0.9), value: text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

extension AnyTransition {
    /// The new character settles in quickly; the old one lingers, lifts and blurs away.
    static func afterimage(place: Int, tint: Color?) -> AnyTransition {
        let p = CGFloat(min(place, 4))
        return .asymmetric(
            insertion: .modifier(active: Afterimage(fade: 1, rise: -2, blur: 1.5, scale: 0.96, tint: nil), identity: Afterimage.none).animation(.easeOut(duration: 0.18).delay(0.07)),
            // the removal starts from the character exactly as it was (a removal caught at rest must look like the text)
            removal: .modifier(active: Afterimage(fade: 1, rise: 6 + 2 * p, blur: 3.5 + p, scale: 1.04 + 0.035 * p, tint: tint), identity: Afterimage.none)
                .animation(.easeOut(duration: 0.4 + 0.06 * Double(p)))
        )
    }
}

/// One frame of an afterimage: how far faded (0 sharp … 1 gone), lifted, blurred and grown.
struct Afterimage: ViewModifier {
    var fade: CGFloat, rise: CGFloat, blur: CGFloat, scale: CGFloat
    var tint: Color?
    static let none = Afterimage(fade: 0, rise: 0, blur: 0, scale: 1, tint: nil)
    func body(content: Self.Content) -> some View {
        // one structure in every state (switching between a tinted and an untinted branch mid-transition left the
        // text dimmed); the ghost keeps the text's own colour
        content
        .scaleEffect(scale)
        .blur(radius: blur)
        .offset(y: -rise)
        // the glyph is gone by a little under half the way, before the new one starts to show
        .opacity(Double(max(CGFloat(0), 1 - fade * 2.2)))
    }
}
