import SwiftUI
import ImageIO

// MARK: pictures

/// The two ways the app's pictures can be drawn. 立体: matte soft-vinyl 3D (tools/scene3d.py, icons3d.py), the
/// default. 平面: the picture book's 2D drawings (tools/picturebook.py, stickers.py), kept under the same names with
/// "2d_" in front; a picture with no 2D drawing shows its 3D one.
enum ArtStyle: String, CaseIterable {
    case vinyl = "3d", flat = "2d"
    nonisolated(unsafe) static var current: ArtStyle = .vinyl
    var title: String { self == .vinyl ? L10n.t("立体", "3D") : L10n.t("平面", "Flat") }
    static func resolve(_ name: String) -> String {
        if name.hasPrefix("3d:") { return String(name.dropFirst(3)) }   // asked for the 3D drawing, whatever the style
        guard current == .flat else { return name }
        let n = "2d_" + name
        return ArtIndex.shared.size[n] == nil ? name : n
    }
}

/// Decodes the pictures in art/ at the size they are shown, off the main thread, and keeps a few in memory.
final class ArtCache: @unchecked Sendable {
    static let shared = ArtCache()
    private let cache = NSCache<NSString, UIImage>()
    private let tableLock = NSLock()
    private var keyLocks: [NSString: NSLock] = [:]
    // enough for a page of pictures and the page behind it, so going back never decodes them again
    init() { cache.totalCostLimit = 160 * 1024 * 1024 }

    private static func bucket(for maxPixel: Int) -> Int {
        if maxPixel <= 256 { return 256 }
        if maxPixel <= 384 { return 384 }
        return 1 << Int(ceil(log2(Double(max(1, maxPixel)))))
    }

    private static func key(_ name: String, _ maxPixel: Int) -> NSString {
        return "\(name)@\(bucket(for: maxPixel))" as NSString
    }

    private func lock(for key: NSString) -> NSLock {
        tableLock.lock()
        defer { tableLock.unlock() }
        if let existing = keyLocks[key] { return existing }
        let l = NSLock()
        keyLocks[key] = l
        return l
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
        let bucket = Self.bucket(for: maxPixel)
        let key = Self.key(name, maxPixel)
        if let i = cache.object(forKey: key) { return i }
        // Deduplicate concurrent decodes of identical stickers/art (e.g. 15 rows sharing one icon)
        let kl = lock(for: key)
        kl.lock()
        defer { kl.unlock() }
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

    /// Pre-decodes the small stickers and companion idle sprites off the main thread at launch so the first scroll is hitch-free.
    func prewarmCommonStickers() {
        Task.detached(priority: .utility) {
            for idle in ["ip_moss_idle.webp", "ip_otto_idle.webp"] {
                _ = ArtCache.shared.image(idle, maxPixel: 384)
            }
            let symbols = LogType.buttons.map(LogType.symbol) + ["A", "B", "C", "D", "E", "F"].map(Palette.areaSymbol)
            for sym in Set(symbols) {
                if let file = IconTile.sticker(sym) {
                    _ = ArtCache.shared.image(file, maxPixel: 256)
                }
            }
        }
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
                .printCard(radius: Radius.card)
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
    @Environment(\.dynamicTypeSize) private var type

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if type.isAccessibilitySize, let text, !text.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 12) {
                        if let symbol { IconTile(symbol: symbol, color: color) }
                        Text(title).font(.body.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        trailing
                        if opens { Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary) }
                    }
                    Text(rich(text)).font(.subheadline).foregroundStyle(Palette.secondaryText).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .contentShape(Rectangle())
                if !last { Divider().padding(.leading, 16) }
            } else {
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
    var accent: Color = Palette.accent
    var last = false
    let toggle: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp

    var body: some View {
        let dark = lamp || scheme == .dark
        Button(action: toggle) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: on ? "checkmark.circle.fill" : "circle").font(.title2)
                        .foregroundStyle(on ? (dark ? accent : Crayon.ink(accent)) : accent.opacity(0.45))
                        .contentTransition(.symbolEffect(.replace))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(text).font(.body).foregroundStyle(.primary).multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if let tag, !tag.isEmpty {
                            Text(tag)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(dark ? accent : Crayon.ink(accent))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(accent.opacity(dark ? 0.22 : 0.14)))
                                .fixedSize()
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(on ? accent.opacity(dark ? 0.12 : 0.06) : .clear)
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
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    let head: [String]
    let rows: [[String]]
    @State private var selectedStage: Int? = nil

    /// The months an age-group heading covers, or nil when the heading is not an age group.
    static func months(_ t: String) -> ClosedRange<Int>? {
        let ns = t.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        let low = t.lowercased()
        let hasMonth = t.contains("月") || low.contains("month") || low.contains("mo")
        let hasYear = t.contains("岁") || low.contains("year") || low.contains("yr")
        guard hasMonth || hasYear, let a = ns.first else { return nil }
        let k = hasYear && !hasMonth ? 12 : 1
        if t.contains("起") || t.contains("以上") || t.contains("+") || low.contains("and up") || low.contains("onward") { return (a * k)...999 }
        return (a * k)...((ns.count > 1 ? ns[1] : a) * k)
    }

    private func metricStyle(for label: String) -> (symbol: String, color: Color)? {
        let low = label.lowercased()
        if label.contains("活动") || low.contains("activity") || low.contains("movement") || low.contains("play") {
            return ("figure.play", Crayon.teal)
        }
        if label.contains("睡") || low.contains("sleep") {
            return ("moon.zzz.fill", Crayon.lilac)
        }
        if label.contains("屏") || low.contains("screen") {
            return ("tv.slash", Crayon.cherry)
        }
        if label.contains("受限") || low.contains("restrain") || low.contains("sedentary") {
            return ("chair.lounge.fill", Crayon.tangerine)
        }
        if label.contains("辅食") || label.contains("餐") || low.contains("feed") || low.contains("meal") || low.contains("milk") {
            return ("fork.knife", Crayon.leaf)
        }
        return nil
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        let ranges = rows.map { Self.months($0.first ?? "") }
        let grouped = rows.count >= 3 && ranges.allSatisfy { $0 != nil }
        let m = app.babyMonth ?? 0
        let mine: Int? = grouped ? (ranges.firstIndex { $0!.contains(m) } ?? 0) : nil

        if grouped, !rows.isEmpty {
            let active = min(max(0, selectedStage ?? mine ?? 0), rows.count - 1)
            let row = rows[active]
            VStack(alignment: .leading, spacing: 12) {
                // Stage Pill Selector (wrapped cleanly with zero right-edge clipping)
                WrapLayout(spacing: 7) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                        let label = r.first ?? ""
                        let isOn = (i == active)
                        let isNow = (i == mine)
                        Button {
                            withAnimation(.snappy) { selectedStage = i }
                        } label: {
                            HStack(spacing: 5) {
                                if isNow {
                                    Circle()
                                        .fill(isOn ? Palette.beadLight : Palette.bead)
                                        .frame(width: 6.5, height: 6.5)
                                }
                                Text(label)
                                    .font(.caption.weight(isOn ? .bold : .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(isOn ? .white : .primary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(isOn ? Palette.accentFill : (dark ? Color.white.opacity(0.08) : Palette.card)))
                            .overlay(Capsule().strokeBorder(isOn ? Color.clear : Palette.outline.opacity(dark ? 0.25 : 0.16), lineWidth: 0.75))
                        }
                        .buttonStyle(.toy)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }

                // Single Focused Visual Stage Card
                VStack(alignment: .leading, spacing: 0) {
                    if let first = row.first {
                        HStack(spacing: 8) {
                            Text(first).font(.headline).foregroundStyle(.primary)
                            if active == mine {
                                Text(L10n.t("宝宝现在", "Now"))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color(hex: 0x4A3300))
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(Capsule().fill(Palette.bead))
                            }
                            Spacer(minLength: 0)
                            Text("\(active + 1) / \(rows.count)")
                                .font(Typeface.numerals(11, relativeTo: .caption2, weight: .semibold))
                                .foregroundStyle(Palette.secondaryText)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }

                    ForEach(Array(row.dropFirst().enumerated()), id: \.offset) { j, cell in
                        Divider().padding(.leading, 16)
                        let label = j + 1 < head.count ? head[j + 1] : ""
                        let icon = metricStyle(for: label)
                        HStack(alignment: .top, spacing: 11) {
                            if let icon {
                                Image(systemName: icon.symbol)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(dark ? icon.color : Crayon.ink(icon.color))
                                    .frame(width: 26, height: 26)
                                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(icon.color.opacity(dark ? 0.20 : 0.14)))
                                    .padding(.top, 1)
                            }
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    if !label.isEmpty { Text(label).font(.footnote.weight(.medium)).foregroundStyle(Palette.secondaryText).fixedSize() }
                                    Spacer(minLength: 8)
                                    Text(rich(cell)).font(.body).multilineTextAlignment(.trailing).fixedSize()
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    if !label.isEmpty { Text(label).font(.footnote.weight(.medium)).foregroundStyle(Palette.secondaryText) }
                                    Text(rich(cell)).font(.body).fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 11)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .printCard(radius: Radius.card)
            }
        } else {
            VStack(spacing: 10) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    VStack(alignment: .leading, spacing: 0) {
                        if let first = row.first {
                            Text(first).font(.headline).foregroundStyle(.primary)
                                .padding(.horizontal, 16).padding(.vertical, 12)
                        }
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .printCard(radius: Radius.card)
                }
            }
        }
    }
}

/// A picture that fills its frame (cropped to it), for headers and tiles.
/// In dark mode the pictures' paper is toned down so it does not glare during night feeds.
struct NightDim: View {
    @Environment(\.colorScheme) private var scheme
    // at night a picture is seen by the lamp: its middle lit warm, its edges going down into the night's own blue —
    // so it sits in the dark page instead of standing on it as a pale grey box (an even wash of blue made the paper
    // ground muddy)
    var body: some View {
        if scheme == .dark {
            ZStack {
                EllipticalGradient(stops: [.init(color: Color(hex: 0xF2E3C8), location: 0), .init(color: Color(hex: 0xC9B79B), location: 0.45),
                                           .init(color: Palette.lampPage, location: 1)],
                                   center: UnitPoint(x: 0.5, y: 0.42), startRadiusFraction: 0, endRadiusFraction: 0.78)
                    .blendMode(.multiply)
                Palette.amber.opacity(0.12).blendMode(.softLight)
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
            let px = Int(max(g.size.width, g.size.height) * scale)
            let ready = Perf.noArt ? nil : img ?? ArtCache.shared.cached(shown, maxPixel: px)
            ZStack {
                Palette.fill
                if let ready { Image(uiImage: ready).resizable().scaledToFill().frame(width: g.size.width, height: g.size.height).clipped().transition(.opacity) }
                NightDim()
            }
            .frame(width: g.size.width, height: g.size.height)
            .task(id: ArtCache.token(shown, px)) {
                if let c = ArtCache.shared.cached(shown, maxPixel: px) { img = c; return }
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
/// A length of time read as one, never as a time of day: "45 秒", "12 分 01 秒", "1 小时 15 分".
func span(_ s: TimeInterval) -> String {
    let n = Int(max(0, s))
    if L10n.isEnglish {
        if n < 60 { return "\(n)s" }
        if n < 3600 { return String(format: "%dm %02ds", n / 60, n % 60) }
        return "\(n / 3600)h \(n / 60 % 60)m"
    }
    if n < 60 { return "\(n) 秒" }
    if n < 3600 { return String(format: "%d 分 %02d 秒", n / 60, n % 60) }
    return "\(n / 3600) 小时 \(n / 60 % 60) 分"
}
func minutesText(_ s: TimeInterval) -> String {
    let m = Int(max(0, s) / 60)
    if L10n.isEnglish { return m >= 60 ? "\(m / 60) hr \(m % 60) min" : "\(m) min" }
    return m >= 60 ? "\(m / 60) 小时 \(m % 60) 分" : "\(m) 分钟"
}

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
        .accessibilityElement().accessibilityLabel(L10n.t("已记下 \(done) / \(total)", "\(done) of \(total) completed"))
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
        .accessibilityAddTraits(.isStaticText)
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

/// Chips laid out in lines that wrap left to right without horizontal scrolling.
struct FlowRow: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > w { y += line + lineSpacing; x = 0; line = 0 }
            x += s.width + spacing; line = max(line, s.height); widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + line)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, line: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > b.minX && x + s.width > b.maxX { y += line + lineSpacing; x = b.minX; line = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing; line = max(line, s.height)
        }
    }
}
