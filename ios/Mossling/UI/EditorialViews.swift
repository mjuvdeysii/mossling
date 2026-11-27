import SwiftUI

// MARK: - Editorial Citation Classifier & Industry-Standard Typography

enum SourceCategory: String, CaseIterable, Identifiable, Sendable {
    case all
    case publicHealth
    case pediatricCare
    case nationalGuidance
    case familyResearch

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: L10n.t("全部文献", "All")
        case .publicHealth: L10n.t("世界卫生 / 联合国", "WHO & UNICEF")
        case .pediatricCare: L10n.t("儿科学会 / 疾病预防", "AAP, CDC & ASHA")
        case .nationalGuidance: L10n.t("国家卫生健康规范", "National Guidelines")
        case .familyResearch: L10n.t("早期发展与研究", "Child Development")
        }
    }

    var tint: Color {
        switch self {
        case .all: Palette.accent
        case .publicHealth: Crayon.teal
        case .pediatricCare: Crayon.sky
        case .nationalGuidance: Crayon.cherry
        case .familyResearch: Crayon.caramel
        }
    }
}

enum SourceCitationClassifier {
    static func category(for org: String) -> SourceCategory {
        let lower = org.lowercased()
        if lower.contains("who") || lower.contains("world health") || lower.contains("unicef") || lower.contains("卫生组织") || lower.contains("联合国") {
            return .publicHealth
        }
        if lower.contains("卫健") || lower.contains("nhc") || lower.contains("疾控") || lower.contains("国家") || lower.contains("全国人大") || lower.contains("china") || lower.contains("中华") {
            return .nationalGuidance
        }
        if lower.contains("aap") || lower.contains("cdc") || lower.contains("asha") || lower.contains("american") || lower.contains("nhs") {
            return .pediatricCare
        }
        return .familyResearch
    }

    static func orgBadge(for org: String) -> String {
        let lower = org.lowercased()
        if lower.contains("world health") || lower.contains("who") { return "WHO" }
        if lower.contains("unicef") { return "UNICEF" }
        if lower.contains("aap") || lower.contains("pediatrics") { return "AAP" }
        if lower.contains("cdc") { return "CDC" }
        if lower.contains("asha") { return "ASHA" }
        if lower.contains("卫健") || lower.contains("nhc") { return "NHC" }
        if lower.contains("疾控") || lower.contains("ndcpa") { return "NDCPA" }
        if lower.contains("人大") || lower.contains("congress") { return "LAW" }
        if lower.contains("中华") || lower.contains("preventive medicine") { return "CPMA" }
        let words = org.split(separator: " ")
        if let first = words.first, first.count <= 8 {
            return String(first)
        }
        return String(org.prefix(8))
    }

    static func displayHost(from urlString: String?) -> String? {
        guard let raw = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              let host = URL(string: raw)?.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    static func yearTag(from date: String?) -> String? {
        guard let date, !date.isEmpty else { return nil }
        if let range = date.range(of: #"(19|20)\d{2}"#, options: .regularExpression) {
            return String(date[range])
        }
        return date
    }

    static func formattedCitation(index: Int, source: Source) -> String {
        let meta = [source.date, source.checked].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "; ")
        let urlPart = source.url.map { " [\($0)]" } ?? ""
        return "[\(index)] \(source.org). \(source.title). \(meta)\(urlPart)"
    }
}

// MARK: - Structured Evidence & Sources Center (Zero Naked URLs)

struct SourcesView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.dynamicTypeSize) private var type

    @State private var selectedCategory: SourceCategory = .all
    @State private var showWHO = false
    @State private var copiedId: String? = nil

    private var allItems: [(index: Int, source: Source)] {
        var rows = app.content.sources.enumerated().map { ($0.offset + 1, $0.element) }
        rows.append((
            rows.count + 1,
            Source(
                code: "WHO-2006",
                org: "World Health Organization",
                title: L10n.t(
                    "WHO Child Growth Standards：体重、身长 / 身高与头围的年龄别标准",
                    "WHO Child Growth Standards: weight, length/height, and head circumference for age"
                ),
                date: "2006",
                url: "https://www.who.int/tools/child-growth-standards",
                checked: L10n.t("用于生长曲线百分位绘图（纯离线内置计算）", "Bundled offline for growth percentile curves")
            )
        ))
        return rows
    }

    private var filteredItems: [(index: Int, source: Source)] {
        guard selectedCategory != .all else { return allItems }
        return allItems.filter { SourceCitationClassifier.category(for: $0.source.org) == selectedCategory }
    }

    var body: some View {
        let dark = lamp || scheme == .dark

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                editorialHeader(dark: dark)

                if !app.content.who.isEmpty {
                    whoRhythmCard(dark: dark)
                }

                // Zero horizontal scroll category filter
                FlowRow(spacing: 8, lineSpacing: 8) {
                    ForEach(SourceCategory.allCases) { cat in
                        let on = selectedCategory == cat
                        let count = cat == .all
                            ? allItems.count
                            : allItems.filter { SourceCitationClassifier.category(for: $0.source.org) == cat }.count
                        if cat == .all || count > 0 {
                            Button {
                                TactileEngine.shared.beadClick()
                                withAnimation(.snappy) { selectedCategory = cat }
                            } label: {
                                HStack(spacing: 5) {
                                    Text(cat.label)
                                        .font(.caption.weight(on ? .bold : .semibold))
                                    Text("\(count)")
                                        .font(Typeface.numerals(11, relativeTo: .caption2, weight: .bold))
                                        .opacity(on ? 0.92 : 0.72)
                                }
                                .foregroundStyle(on ? .white : .primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(on ? Palette.accentFill : (dark ? Palette.lampCard : Palette.card)))
                                .overlay(Capsule().strokeBorder(on ? .clear : Palette.outline.opacity(0.22), lineWidth: 0.75))
                                .pillHitTarget()
                            }
                            .buttonStyle(.toy)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(filteredItems, id: \.index) { item in
                        citationCard(index: item.index, source: item.source, dark: dark)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .padding(.bottom, 32)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.lilac)
        .navigationTitle(L10n.t("循证内容来源", "Evidence & Sources"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func editorialHeader(dark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                IconTile(symbol: "books.vertical.fill", color: Crayon.caramel, size: 34, round: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("公开权威文献索引", "Public Reference Index"))
                        .font(.headline.weight(.bold))
                    Text(L10n.t(
                        "每条发展提示、活动编排与健康要点均核对原机构公开文献，仅作家庭参考。",
                        "Every milestone, activity, and health note cross-checks published institutional references for home guidance."
                    ))
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            FlowRow(spacing: 6, lineSpacing: 6) {
                credibilityPill("checkmark.shield.fill", L10n.t("公开机构文献", "Peer & Public Guides"), Crayon.teal, dark: dark)
                credibilityPill("calendar.badge.checkmark", L10n.t("2026 年版本核校", "Verified Oct 2026"), Crayon.caramel, dark: dark)
                credibilityPill("stethoscope", L10n.t("不替代医疗诊断", "Not Medical Advice"), Crayon.tangerine, dark: dark)
            }
        }
        .padding(14)
        .printCard(radius: Radius.card)
    }

    private func credibilityPill(_ symbol: String, _ text: String, _ color: Color, dark: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.caption2.weight(.bold))
            Text(text)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(dark ? color : Crayon.ink(color))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(dark ? 0.18 : 0.12)))
    }

    private func whoRhythmCard(dark: Bool) -> some View {
        VStack(spacing: 0) {
            CalmAccordion(isExpanded: $showWHO, spacing: 10, dividerHorizontalPadding: 14) { open in
                HStack(spacing: 10) {
                    IconTile(symbol: "clock.badge.checkmark.fill", color: Crayon.aqua, size: 30, round: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("WHO 24 小时活动与睡眠参考表", "WHO 24-Hour Movement & Sleep Reference"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(L10n.t("出生至 3 岁分段参考（WHO 2019）", "Age-banded guide, 0–3 yrs (WHO 2019)"))
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryText)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(.vertical, 2)
            } content: {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(app.content.who.enumerated()), id: \.offset) { idx, row in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(row.age).font(.subheadline.weight(.bold)).foregroundStyle(Palette.accent)
                            whoLine(L10n.t("活动", "Activity"), row.act)
                            whoLine(L10n.t("睡眠", "Sleep"), row.sleep)
                            whoLine(L10n.t("屏幕", "Screens"), row.screen)
                            whoLine(L10n.t("久坐", "Restraint"), row.restrain)
                        }
                        if idx < app.content.who.count - 1 { Divider().opacity(0.4) }
                    }
                }
                .padding(.top, 4)
            }
            .padding(14)
        }
        .printCard(radius: Radius.card)
    }

    private func citationCard(index: Int, source: Source, dark: Bool) -> some View {
        let cat = SourceCitationClassifier.category(for: source.org)
        let orgBadge = SourceCitationClassifier.orgBadge(for: source.org)
        let year = SourceCitationClassifier.yearTag(from: source.date)
        let host = SourceCitationClassifier.displayHost(from: source.url)
        let keyId = "\(index)-\(source.code)"

        return VStack(alignment: .leading, spacing: 8) {
            let indexText = Text(String(format: "[%02d]", index))
                .font(Typeface.numerals(11, relativeTo: .caption2, weight: .bold))
                .foregroundStyle(Palette.secondaryText)
            let orgPill = Text(orgBadge)
                .font(.caption2.weight(.bold))
                .foregroundStyle(dark ? cat.tint : Crayon.ink(cat.tint))
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Capsule().fill(cat.tint.opacity(dark ? 0.22 : 0.14)))
            let orgName = Text(source.org)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.secondaryText)
                .lineLimit(type.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)
            let yearPill = year.map { y in
                Text(y)
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Palette.secondaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(Palette.fill.opacity(dark ? 0.35 : 0.85)))
            }

            if type.isAccessibilitySize {
                FlowRow(spacing: 6, lineSpacing: 6) {
                    indexText
                    orgPill
                    orgName
                    if let yearPill { yearPill }
                }
            } else {
                HStack(alignment: .center, spacing: 6) {
                    indexText
                    orgPill
                    orgName
                    Spacer(minLength: 4)
                    if let yearPill { yearPill }
                }
            }

            Text(source.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            let meta = [source.date, source.checked].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
            if !meta.isEmpty {
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            let sourceLink = Group {
                if let urlStr = source.url, let url = URL(string: urlStr), let host {
                    Link(destination: url) {
                        HStack(spacing: 5) {
                            Image(systemName: "safari")
                                .font(.caption2.weight(.semibold))
                            Text("\(host) · " + L10n.t("查看原文", "Source"))
                                .font(.caption.weight(.semibold))
                                .lineLimit(type.isAccessibilitySize ? nil : 1)
                                .fixedSize(horizontal: false, vertical: true)
                            Image(systemName: "arrow.up.right")
                                .font(Typeface.label(11, relativeTo: .caption2, weight: .bold))
                        }
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Palette.accent.opacity(dark ? 0.18 : 0.10)))
                        .pillHitTarget()
                    }
                    .buttonStyle(.plain)
                }
            }

            let citeButton = Button {
                UIPasteboard.general.string = SourceCitationClassifier.formattedCitation(index: index, source: source)
                TactileEngine.shared.beadClick()
                copiedId = keyId
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.8))
                    if copiedId == keyId { copiedId = nil }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: copiedId == keyId ? "checkmark" : "doc.on.doc")
                        .font(.caption2.weight(.bold))
                    Text(copiedId == keyId ? L10n.t("已复制引文", "Copied") : L10n.t("复制引文", "Cite"))
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(copiedId == keyId ? Palette.accent : Palette.secondaryText)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(Capsule().fill(Palette.fill.opacity(dark ? 0.35 : 0.80)))
                .pillHitTarget()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("复制第 \(index) 条标准引文", "Copy formatted citation \(index)"))

            Group {
                if type.isAccessibilitySize {
                    FlowRow(spacing: 8, lineSpacing: 6) {
                        sourceLink
                        citeButton
                    }
                } else {
                    HStack(spacing: 8) {
                        sourceLink
                        Spacer(minLength: 4)
                        citeButton
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .printCard(radius: Radius.card)
    }

    private func whoLine(_ label: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Palette.secondaryText)
                .frame(width: L10n.isEnglish ? 64 : 30, alignment: .leading)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Editorial Legal Document Reader (`DocView` with App Store Privacy Nutrition Header)

private struct ParsedDocSection: Identifiable {
    let id: Int
    let heading: String?
    let lines: [String]
}

struct DocView: View {
    let name: String
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @Environment(\.dynamicTypeSize) private var type

    private var rawText: String {
        let resURL = (L10n.isEnglish ? Bundle.main.url(forResource: name + "_EN", withExtension: "md") : nil)
            ?? Bundle.main.url(forResource: name, withExtension: "md")
        let raw = (resURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
            ?? L10n.t("读取不到这份文件。", "This document could not be loaded."))
            .replacingOccurrences(of: "安卓应用", with: "应用")
        return Owner.fill(raw)
    }

    private func parse(_ text: String) -> (title: String, metadata: [String], sections: [ParsedDocSection]) {
        let allLines = text.components(separatedBy: "\n")
        var title = L10n.appName
        var meta: [String] = []
        var sections: [ParsedDocSection] = []
        var currentHeading: String? = nil
        var currentLines: [String] = []
        var sawHeading = false
        var secCounter = 0

        for line in allLines {
            if line.hasPrefix("# ") && !sawHeading {
                title = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("## ") {
                if !currentLines.isEmpty || currentHeading != nil {
                    sections.append(ParsedDocSection(id: secCounter, heading: currentHeading, lines: currentLines))
                    secCounter += 1
                }
                sawHeading = true
                currentHeading = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                currentLines = []
            } else if !sawHeading {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { meta.append(trimmed) }
            } else {
                currentLines.append(line)
            }
        }
        if !currentLines.isEmpty || currentHeading != nil {
            sections.append(ParsedDocSection(id: secCounter, heading: currentHeading, lines: currentLines))
        }
        return (title, meta, sections)
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        let parsed = parse(rawText)

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerCard(title: parsed.title, metadata: parsed.metadata, dark: dark)

                if name == "PRIVACY" {
                    privacyNutritionSummary(dark: dark)
                }

                ForEach(parsed.sections) { sec in
                    sectionCard(sec, dark: dark)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 36)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.lilac)
        .navigationTitle(parsed.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func headerCard(title: String, metadata: [String], dark: Bool) -> some View {
        let icon: String = name == "PRIVACY" ? "hand.raised.fill" : name == "TERMS" ? "doc.text.fill" : "exclamationmark.shield.fill"
        let color: Color = name == "PRIVACY" ? Crayon.sky : name == "TERMS" ? Crayon.pebble : Crayon.tangerine
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                IconTile(symbol: icon, color: color, size: 32, round: true)
                Text(title)
                    .font(.title3.weight(.bold))
            }
            ForEach(metadata, id: \.self) { m in
                Text(rich(m))
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .printCard(radius: Radius.card)
    }

    private func privacyNutritionSummary(dark: Bool) -> some View {
        let badges: [(String, String, Color)] = [
            ("eye.slash.fill", L10n.t("不收集数据", "Data Not Collected"), Crayon.teal),
            ("wifi.slash", L10n.t("零网络访问", "Zero Network"), Crayon.sky),
            ("person.crop.circle.badge.xmark", L10n.t("无需账号", "No Account Needed"), Crayon.leaf),
            ("trash.fill", L10n.t("本机可随时清空", "Full Local Control"), Crayon.caramel)
        ]
        let cols = type.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        return VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("隐私承诺一图读懂", "Privacy at a Glance"))
                .font(.caption.weight(.bold))
                .foregroundStyle(Palette.secondaryText)
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(badges, id: \.1) { sym, title, col in
                    HStack(spacing: 7) {
                        Image(systemName: sym)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(dark ? col : Crayon.ink(col))
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(type.isAccessibilitySize ? nil : 1)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: Radius.inner, style: .continuous).fill(col.opacity(dark ? 0.16 : 0.10)))
                }
            }
        }
        .padding(14)
        .printCard(radius: Radius.card)
    }

    private func sectionCard(_ sec: ParsedDocSection, dark: Bool) -> some View {
        let isChildProtect = (sec.heading ?? "").contains("儿童") || (sec.heading ?? "").lowercased().contains("children")
        let heads = Set(sec.lines.indices.filter { i in
            i + 1 < sec.lines.count
                && sec.lines[i].hasPrefix("|")
                && sec.lines[i + 1].replacingOccurrences(of: " ", with: "").hasPrefix("|---")
        })

        return VStack(alignment: .leading, spacing: 8) {
            if let heading = sec.heading {
                Text(heading)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isChildProtect ? Palette.accent : .primary)
            }
            ForEach(Array(sec.lines.enumerated()), id: \.offset) { idx, line in
                docLine(line, dark: dark, isHeader: heads.contains(idx))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isChildProtect ? Palette.accent.opacity(dark ? 0.10 : 0.05) : .clear)
        .printCard(radius: Radius.card)
    }

    @ViewBuilder
    private func docLine(_ l: String, dark: Bool, isHeader: Bool = false) -> some View {
        if l.hasPrefix("- ") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle().fill(Palette.accent).frame(width: 5, height: 5).offset(y: -2)
                Text(rich(String(l.dropFirst(2))))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if let r = l.range(of: #"^\d+\. "#, options: .regularExpression) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(l[r].trimmingCharacters(in: .whitespaces))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Palette.secondaryText)
                    .frame(width: 24, alignment: .leading)
                Text(rich(String(l[r.upperBound...])))
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else if l.hasPrefix("|") {
            let cells = l.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if !cells.allSatisfy({ $0.hasPrefix("---") || $0.isEmpty }) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(rich(cells.first ?? ""))
                        .font((isHeader ? Font.footnote : Font.subheadline).weight(.bold))
                        .foregroundStyle(isHeader ? Palette.accent : .primary)
                    ForEach(Array(cells.dropFirst().enumerated()), id: \.offset) { _, c in
                        Text(rich(c))
                            .font(isHeader ? .caption.weight(.semibold) : .caption)
                            .foregroundStyle(isHeader ? .primary : Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Radius.inner, style: .continuous)
                        .fill(isHeader ? Palette.accent.opacity(dark ? 0.16 : 0.10) : Palette.fill.opacity(dark ? 0.25 : 0.65))
                )
            }
        } else if l.trimmingCharacters(in: .whitespaces).isEmpty {
            EmptyView()
        } else {
            Text(rich(l))
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Parent-Facing Version-Synced Release Notes (`ReleaseNotesView`)

struct ReleaseNotesView: View {
    @State private var showHistory = false

    private struct ReleaseFeature: Identifiable {
        let id: String
        let symbol: String
        let color: Color
        let title: String
        let detail: String
    }

    var body: some View {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        let currentHighlights: [ReleaseFeature] = [
            ReleaseFeature(
                id: "four-tabs",
                symbol: "square.grid.2x2.fill",
                color: Crayon.teal,
                title: L10n.t("四屏全新布局：摸索 · 台灯 · 留念 · 工坊", "Four-Tab Layout: Explore · Lamp · Keepsakes · Studio"),
                detail: L10n.t(
                    "首屏完全留给孩子探索、本周活动与感官小工坊；第二屏把 Otto 床头暖灯与 24 小时节律归集放到台前；成长绘本、纪念相纸、火漆胶囊与 WHO 曲线归入「留念」；理念故事与透明文档回归「工坊」。",
                    "Explore focuses purely on play and discovery; Lamp centers Otto's interactive bedside light and rhythm; Keepsakes houses Storybook, Firsts, Capsules, and WHO curves; Studio carries philosophy, design craft, and evidence."
                )
            ),
            ReleaseFeature(
                id: "story-theater",
                symbol: "sparkles",
                color: Palette.amber,
                title: L10n.t("双画风活态绘本与独立动画", "Living Picture-Book Stage (3D & 2D)"),
                detail: L10n.t(
                    "加入柔光棚拍与手绘水彩双风格画面，推出 46 部覆盖 0–36 个月的完全独立手工编排活动小动画与全月龄活态成长封面。",
                    "Paired soft-vinyl warm studio lighting with hand-tinted watercolor textures, featuring 46 bespoke step animations across 0–36 months and living monthly covers."
                )
            ),
            ReleaseFeature(
                id: "health-sources",
                symbol: "books.vertical.fill",
                color: Crayon.sky,
                title: L10n.t("分地区儿保参考与规范循证来源", "Regional Health Schedules & Clean Citations"),
                detail: L10n.t(
                    "新增中国、美国、英国、澳大利亚四地接种与随访周期参考；重构内容来源、隐私保护与更新志排版，告别裸露网址。",
                    "Added CN, US, UK, and AU immunization/visit references and redesigned Evidence Sources, Privacy Policy, and Release Notes into clean editorial cards."
                )
            ),
            ReleaseFeature(
                id: "smooth",
                symbol: "hand.draw.fill",
                color: Crayon.leaf,
                title: L10n.t("舒心展开与全览卡片", "Calm Cards & Smooth Expanding Sections"),
                detail: L10n.t(
                    "今日时间轴专注清晰阅读，所有展开收起顺滑自然，在任意字号下都完整排布不裁切。",
                    "Refined the daily overview for effortless reading with calm expanding sections and clean layout across text sizes."
                )
            )
        ]

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Hero synced version badge card
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        IconTile(symbol: "sparkles.rectangle.stack.fill", color: Crayon.lilac, size: 36, round: true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("版本 \(v)（\(b)）", "Version \(v) (\(b))"))
                                .font(.title3.weight(.bold))
                                .monospacedDigit()
                            Text(L10n.t("孩子摸索，大人点灯 · 2026 年 11 月更新", "They explore. You hold the light · Nov 2026"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.accent)
                        }
                        Spacer(minLength: 0)
                    }
                    Text(L10n.t(
                        "这一版重点让每个板块各安其位：陪玩时不受记账打扰，夜晚唤醒台灯一触即亮，每一条信息都有迹可循。",
                        "This release clarifies every space in the app: calm play without log clutter, Otto's lamp front and center at night, and transparent, citation-grade references."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .printCard(radius: Radius.card)

                VStack(spacing: 10) {
                    ForEach(currentHighlights) { item in
                        HStack(alignment: .top, spacing: 12) {
                            IconTile(symbol: item.symbol, color: item.color, size: 32, round: true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(Palette.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .printCard(radius: Radius.card)
                    }
                }

                // Earlier milestones inside calm accordion
                VStack(spacing: 0) {
                    CalmAccordion(isExpanded: $showHistory, spacing: 8, dividerHorizontalPadding: 14) { open in
                        HStack(spacing: 10) {
                            IconTile(symbol: "clock.arrow.circlepath", color: Crayon.pebble, size: 28, round: true)
                            Text(L10n.t("早期版本回顾 · 2.0 奠基特性", "Earlier 2.0 Highlights"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                                .rotationEffect(.degrees(open ? 180 : 0))
                        }
                    } content: {
                        VStack(alignment: .leading, spacing: 8) {
                            historyRow("2.0", L10n.t(
                                "推出床头六声景交互暖灯、护耳音量监测、灵动岛实时计时、StandBy 夜间床头牌、Siri 与控制中心捷径、60 种辅食图鉴、五工坊感官玩具盒与火漆时光胶囊。",
                                "Introduced Otto's 6-soundscape Bedside Lamp, Ear-Safe Monitor, Live Activities, StandBy Night Beacon, Control Center & Siri shortcuts, 60 First Foods Atlas, Sensory Toybox, and Wax-Sealed Time Capsules."
                            ))
                            Divider().opacity(0.45)
                            historyRow("1.0", L10n.t(
                                "纯离线 0–36 个月育儿探索手册、WHO 生长标准曲线、家庭照护手账与 Moss / Otto 双陪伴角色诞生。",
                                "Launched as a 100% offline 0–36 month parenting guide with WHO growth curves, care log, and Moss & Otto."
                            ))
                        }
                        .padding(.top, 4)
                    }
                    .padding(14)
                }
                .printCard(radius: Radius.card)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 32)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.lilac)
        .navigationTitle(L10n.t("版本更新志", "What's New"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func historyRow(_ ver: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ver).font(.caption.weight(.bold)).foregroundStyle(Palette.accent)
            Text(text).font(.caption).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Studio Craft Pillars Showcase (Tab 4 Design-Philosophy Tiles)

struct CraftPillarsShowcaseCard: View {
    let dark: Bool
    @Environment(\.dynamicTypeSize) private var type

    var body: some View {
        let cols = type.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

        let pillars: [(String, Color, String, String)] = [
            ("paintpalette.fill", Crayon.teal, L10n.t("3D × 2D 双世界", "3D & 2D Worlds"), L10n.t("柔光哑胶与水彩纸感原地蜕变", "Soft-vinyl light or watercolor washes")),
            ("wifi.slash", Crayon.leaf, L10n.t("100% 离线零追踪", "Zero Cloud & Zero Ads"), L10n.t("无账号无统计，完整归属家庭本机", "Every note stays privately on iPhone")),
            ("ear.badge.checkmark", Palette.amber, L10n.t("护耳声学实验室", "Ear-Safe Lamp Audio"), L10n.t("无文件实时合成声景与温和渐熄", "Real-time soothing synthesis & gentle fade")),
            ("iphone.gen3.radiowaves.left.and.right", Crayon.sky, L10n.t("StandBy 与灵动岛", "Apple Ecosystem"), L10n.t("锁屏床头牌、控制中心与物理触感", "Live Activities, Control Center & haptics"))
        ]

        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("摸索台灯的四个坚持", "Four Principles of Craft"))
                .font(.caption.weight(.bold))
                .foregroundStyle(Palette.secondaryText)
                .padding(.leading, 4)

            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(pillars, id: \.2) { sym, col, title, detail in
                    VStack(alignment: .leading, spacing: 6) {
                        IconTile(symbol: sym, color: col, size: 28, round: true)
                        Text(title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                    .background(
                        LinearGradient(
                            colors: [col.opacity(dark ? 0.14 : 0.10), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .printCard(radius: Radius.card)
                }
            }
        }
    }
}
