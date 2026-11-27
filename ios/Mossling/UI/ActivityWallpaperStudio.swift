import SwiftUI

/// Output frame ratios supported by the in-app Collector Wallpaper Atelier.
enum ActivityWallpaperFormat: String, CaseIterable, Identifiable, Sendable {
    case lockScreen
    case galleryPrint

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lockScreen: L10n.t("9:19.5 锁屏壁纸", "9:19.5 Lock Screen")
        case .galleryPrint: L10n.t("4:3 美术框画", "4:3 Collector Print")
        }
    }

    var aspectRatio: CGFloat {
        switch self {
        case .lockScreen: 9.0 / 19.5
        case .galleryPrint: 4.0 / 3.0
        }
    }

    var previewSize: CGSize {
        switch self {
        case .lockScreen: CGSize(width: 248, height: 537)
        case .galleryPrint: CGSize(width: 312, height: 234)
        }
    }

    var exportSize: CGSize {
        switch self {
        case .lockScreen: CGSize(width: 430, height: 932)
        case .galleryPrint: CGSize(width: 640, height: 480)
        }
    }
}

/// Curated museum-grade Moss & Otto collector wallpaper plate baked into `Art/art/`.
struct ActivityWallpaperPlate: Identifiable, Hashable, Sendable {
    let id: String
    let code: String
    let filename: String
    let titleZH: String
    let titleEN: String
    let subtitleZH: String
    let subtitleEN: String
    let biomeZH: String
    let biomeEN: String
    let accentHex: UInt32
    let prefersEveningGlaze: Bool

    var title: String { L10n.t(titleZH, titleEN) }
    var subtitle: String { L10n.t(subtitleZH, subtitleEN) }
    var biome: String { L10n.t(biomeZH, biomeEN) }

    static let all: [ActivityWallpaperPlate] = [
        ActivityWallpaperPlate(
            id: "wp_a09",
            code: "A09",
            filename: "wp_a09.jpg",
            titleZH: "镜中对望 · 午后窗影",
            titleEN: "Mirror Afternoon",
            subtitleZH: "黄铜弧形落地镜与午后橄榄叶日影，定格第一次认出自己。",
            subtitleEN: "Arched brass nursery mirror & olive sunlight casting quiet afternoon wonder.",
            biomeZH: "日光窗边 · Sunlit Nursery",
            biomeEN: "Sunlit Nursery Window",
            accentHex: 0xD79A43,
            prefersEveningGlaze: false
        ),
        ActivityWallpaperPlate(
            id: "wp_a11",
            code: "A11",
            filename: "wp_a11.jpg",
            titleZH: "过手摇铃 · 榉木手作台",
            titleEN: "Timber Transfer",
            subtitleZH: "双手跨越身体中线交接桦木双色摇铃，暖光落满亚麻地垫。",
            subtitleEN: "Hand-to-hand beechwood rattle transfer under morning linen sunbeams.",
            biomeZH: "木作桌边 · Atelier Table",
            biomeEN: "Atelier Work Table",
            accentHex: 0x5E9B71,
            prefersEveningGlaze: false
        ),
        ActivityWallpaperPlate(
            id: "wp_n04",
            code: "N04",
            filename: "wp_n04.jpg",
            titleZH: "光斑趴垫 · 晨光拼布毯",
            titleEN: "Sunlit Blanket",
            subtitleZH: "窗格日光投影落在滚边棉麻圆毯上，风铃在头顶轻轻摇曳。",
            subtitleEN: "Morning window panes drifting across an oatmeal-sage heirloom play quilt.",
            biomeZH: "日光窗边 · Sunlit Nursery",
            biomeEN: "Sunlit Nursery Window",
            accentHex: 0x82A87E,
            prefersEveningGlaze: false
        ),
        ActivityWallpaperPlate(
            id: "wp_a19",
            code: "A19",
            filename: "wp_a19.jpg",
            titleZH: "积木叠叠 · 暮色橡木塔",
            titleEN: "Oak Tower",
            subtitleZH: "鼠尾草绿、蜂蜜黄与赤陶红三块倒角木块，在晚霞余晖中稳稳相叠。",
            subtitleEN: "Three chamfered matte beech blocks catching golden hour hearth warmth.",
            biomeZH: "暮色壁炉角 · Dusk Atelier",
            biomeEN: "Atelier Work Table",
            accentHex: 0xC87A50,
            prefersEveningGlaze: false
        ),
        ActivityWallpaperPlate(
            id: "wp_a06",
            code: "A06",
            filename: "wp_a06.jpg",
            titleZH: "听声转头 · 星夜小铜铃",
            titleEN: "Gentle Bell",
            subtitleZH: "靛蓝夜窗前的一声轻响，金色音波穿过星光流向安睡中的小树苗。",
            subtitleEN: "Twilight chime arcs drifting across starry indigo curtains and Otto's glow.",
            biomeZH: "星夜台灯角 · Twilight Room",
            biomeEN: "Twilight Lantern Room",
            accentHex: 0xF0A847,
            prefersEveningGlaze: true
        ),
        ActivityWallpaperPlate(
            id: "wp_a34",
            code: "A34",
            filename: "wp_a34.jpg",
            titleZH: "自然观察 · 风与蒲公英",
            titleEN: "Meadow Composure",
            subtitleZH: "尤加利树荫下铺开赤陶锁边野餐布，和蕨芽与蒲公英安静打招呼。",
            subtitleEN: "Rolling watercolor clover hills under swaying komorebi eucalyptus shade.",
            biomeZH: "日光草地 · Meadow Sky",
            biomeEN: "Garden Meadow Sky",
            accentHex: 0x6AA87B,
            prefersEveningGlaze: false
        )
    ]

    static func plate(matching code: String?) -> ActivityWallpaperPlate {
        guard let code else { return all[0] }
        let normalized = code.uppercased()
        if let exact = all.first(where: { $0.code == normalized }) {
            return exact
        }
        // Harmonize non-featured activity codes via deterministic index
        let sum = normalized.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return all[sum % all.count]
    }
}

/// High-resolution exportable poster composition shared between live preview & 3x ImageRenderer export.
struct ActivityWallpaperPoster: View {
    let plate: ActivityWallpaperPlate
    let format: ActivityWallpaperFormat
    let eveningWarmth: Bool
    let showMuseumPlaque: Bool
    let targetSize: CGSize
    let maxPixel: Int
    var isExport: Bool = false

    var body: some View {
        let image = ArtCache.shared.image(plate.filename, maxPixel: maxPixel)

        ZStack(alignment: .bottom) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: targetSize.width, height: targetSize.height)
                    .clipped()
                    .overlay {
                        if eveningWarmth {
                            LinearGradient(
                                colors: [
                                    Color(hex: 0x0B152A).opacity(0.32),
                                    Color(hex: 0xFFB85C).opacity(0.10),
                                    Color(hex: 0x0B152A).opacity(0.38)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                    }
            } else {
                LinearGradient(
                    colors: [Color(hex: 0xFAF6EB), Color(hex: plate.accentHex).opacity(0.35)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            if showMuseumPlaque {
                VStack(spacing: 3) {
                    HStack(spacing: 8) {
                        Text(plate.code)
                            .font(.system(.caption2, design: .rounded).weight(.bold))
                            .foregroundStyle(Color(hex: plate.accentHex))
                        Text(plate.title)
                            .font(.system(.footnote, design: .serif).weight(.semibold))
                            .foregroundStyle(Color(hex: 0x1F2A38))
                            .lineLimit(1)
                    }
                    Text(L10n.t("摸索台灯 · 藏画版壁纸", "Moss & Otto · Collector Illustration"))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(hex: 0x5B6778))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(
                    Color(hex: 0xFCF8EE).opacity(0.92)
                )
                .overlay(alignment: .top) {
                    Rectangle().fill(Color(hex: 0xD9CEB8)).frame(height: 0.8)
                }
            } else if format == .lockScreen {
                // Clean visual lockscreen time cue preview is strictly omitted from exported art
                EmptyView()
            }
        }
        .frame(width: targetSize.width, height: targetSize.height)
        .clipShape(RoundedRectangle(cornerRadius: isExport ? 0 : (format == .lockScreen ? 28 : 14), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isExport ? 0 : (format == .lockScreen ? 28 : 14), style: .continuous)
                .stroke(Color.white.opacity(isExport ? 0 : (eveningWarmth ? 0.14 : 0.45)), lineWidth: isExport ? 0 : 1)
        )
        .shadow(color: isExport ? .clear : .black.opacity(0.18), radius: isExport ? 0 : 18, y: isExport ? 0 : 10)
    }
}

/// Interactive Art Wallpaper Atelier sheet for previewing, toning, and saving 9:19.5 Lock Screen & 4:3 Collector Prints.
struct ActivityWallpaperSheet: View {
    let initialCode: String?

    @Environment(\.dismiss) private var dismiss
    @State private var selected: ActivityWallpaperPlate
    @State private var format: ActivityWallpaperFormat = .lockScreen
    @State private var eveningWarmth: Bool
    @State private var showPlaque = false

    init(initialCode: String? = nil) {
        let plate = ActivityWallpaperPlate.plate(matching: initialCode)
        self.initialCode = initialCode
        _selected = State(initialValue: plate)
        _eveningWarmth = State(initialValue: plate.prefersEveningGlaze)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Text(selected.title)
                            .font(.system(.title3, design: .serif).weight(.semibold))
                            .multilineTextAlignment(.center)
                        Text(selected.subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                    .padding(.top, 4)

                    // Live Lock Screen / 4:3 Gallery Preview Stage
                    ZStack(alignment: .top) {
                        ActivityWallpaperPoster(
                            plate: selected,
                            format: format,
                            eveningWarmth: eveningWarmth,
                            showMuseumPlaque: showPlaque,
                            targetSize: format.previewSize,
                            maxPixel: 1400
                        )

                        if format == .lockScreen && !showPlaque {
                            VStack(spacing: 2) {
                                Text("9:41")
                                    .font(Typeface.numerals(46, relativeTo: .largeTitle, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.90))
                                    .shadow(color: .black.opacity(0.24), radius: 8, y: 2)
                                Text(selected.biome)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.84))
                                    .shadow(color: .black.opacity(0.24), radius: 6, y: 1)
                            }
                            .padding(.top, 38)
                            .allowsHitTesting(false)
                        }
                    }
                    .animation(.spring(response: 0.36, dampingFraction: 0.86), value: format)
                    .animation(.easeInOut(duration: 0.25), value: selected.id)

                    // Format & Toning Controls
                    Picker(L10n.t("画幅比例", "Frame Ratio"), selection: $format) {
                        ForEach(ActivityWallpaperFormat.allCases) { item in
                            Text(item.label).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 4)

                    HStack(spacing: 12) {
                        Toggle(isOn: $eveningWarmth) {
                            Label(L10n.t("夜间暖釉", "Night Glaze"), systemImage: "moon.stars")
                                .font(.footnote.weight(.medium))
                                .pillHitTarget()
                        }
                        .toggleStyle(.button)
                        .tint(Palette.amber)

                        Toggle(isOn: $showPlaque) {
                            Label(L10n.t("底部画签", "Mat Plaque"), systemImage: "text.below.photo")
                                .font(.footnote.weight(.medium))
                                .pillHitTarget()
                        }
                        .toggleStyle(.button)
                        .tint(Color(hex: selected.accentHex))
                    }

                    // 6-Plate Wrapped Collector Switcher (Zero Horizontal Scroll)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 98), spacing: 10)], spacing: 10) {
                        ForEach(ActivityWallpaperPlate.all) { item in
                            Button {
                                TactileEngine.shared.beadClick()
                                selected = item
                                eveningWarmth = item.prefersEveningGlaze
                            } label: {
                                VStack(spacing: 6) {
                                    let thumb = ArtCache.shared.image(item.filename, maxPixel: 360)
                                    ZStack {
                                        if let thumb {
                                            Image(uiImage: thumb)
                                                .resizable()
                                                .scaledToFill()
                                        } else {
                                            Color(hex: item.accentHex).opacity(0.25)
                                        }
                                    }
                                    .frame(height: 82)
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(
                                                selected.id == item.id ? Color(hex: item.accentHex) : Color.primary.opacity(0.10),
                                                lineWidth: selected.id == item.id ? 2.4 : 0.8
                                            )
                                    )

                                    Text("\(item.code) · \(L10n.t(String(item.titleZH.prefix(4)), item.titleEN))")
                                        .font(.caption2.weight(selected.id == item.id ? .bold : .medium))
                                        .foregroundStyle(selected.id == item.id ? Color.primary : Color.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(item.code) \(item.title)")
                        }
                    }

                    let exportPoster = RenderedPoster {
                        let poster = ActivityWallpaperPoster(
                            plate: selected,
                            format: format,
                            eveningWarmth: eveningWarmth,
                            showMuseumPlaque: showPlaque,
                            targetSize: format.exportSize,
                            maxPixel: 2400,
                            isExport: true
                        )
                        let renderer = ImageRenderer(content: poster)
                        renderer.scale = 3.0
                        return renderer.uiImage
                    }

                    ShareLink(
                        item: exportPoster,
                        preview: SharePreview(
                            L10n.t("摸索台灯 · \(selected.title)", "Moss & Otto · \(selected.title)")
                        )
                    ) {
                        Label(
                            L10n.t("保存或分享超清壁纸 / 印画", "Save or Share High-Res Wallpaper"),
                            systemImage: "square.and.arrow.down"
                        )
                        .font(.callout.weight(.semibold))
                    }
                    .buttonStyle(.ds(.primary, fullWidth: true, height: LayoutSpec.ctaPrimaryHeight))
                }
                .padding(.horizontal, LayoutSpec.pageH)
                .padding(.bottom, 24)
            }
            .navigationTitle(L10n.t("藏画壁纸画室", "Wallpaper Atelier"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("关闭", "Close")) { dismiss() }
                }
            }
        }
    }
}
