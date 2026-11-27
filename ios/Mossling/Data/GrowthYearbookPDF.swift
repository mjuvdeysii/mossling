import UIKit
import SwiftUI
import UniformTypeIdentifiers
import PDFKit

/// Asynchronous transferable wrapper so `ShareLink` exports a multi-page 3-Year Growth Yearbook PDF only on tap.
struct GrowthYearbookPDFTransfer: Transferable {
    let filename: String
    let render: @MainActor @Sendable () -> Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { item in
            await MainActor.run { item.render() }
        }
        .suggestedFileName { item in
            item.filename
        }
    }
}

/// Offline, multi-page US-Letter (612x792) PDF generator assembling monthly storybook pages,
/// Firsts & voice-keepsake indicators, First Foods tasting summaries, and sealed Time Capsules.
/// Never reveals the body text of any locked future Time Capsule before its unlock date.
enum GrowthYearbookPDF {
    struct YearbookSection: Equatable, Sendable {
        let title: String
        let lines: [String]
    }

    @MainActor
    static func buildSections(
        app: AppModel,
        j: JournalStore,
        foods: [FoodRecord]? = nil,
        capsules: [TimeCapsule]? = nil
    ) -> [YearbookSection] {
        let allPages = Array(BookPage.all(app, j).reversed())
        let foodRecords = foods ?? Array(FoodAtlasStore.shared.records.values)
        let capsuleItems = capsules ?? CapsuleStore.shared.items
        var sections: [YearbookSection] = []

        let who = app.nickname.isEmpty ? L10n.t("宝宝", "Baby") : app.nickname
        var coverLines: [String] = []
        if let birth = app.birth {
            coverLines.append(L10n.t("出生日期：\(birth.ymd)", "Birth date: \(birth.ymd)"))
        }
        if let actual = app.actualAge {
            coverLines.append(L10n.t("记录跨度：\(L10n.ageText(actual))（\(L10n.livedDays(actual.lived))）", "Span: \(L10n.ageText(actual)) (\(L10n.livedDays(actual.lived)))"))
        }
        if let gw = app.gestationalWeeks, Age.isPreterm(gw), let ca = app.correctedAge {
            coverLines.append(L10n.t("早产 \(gw) 周 · 矫正月龄：\(L10n.ageText(ca))", "Preterm \(gw)w · Corrected age: \(L10n.ageText(ca))"))
        }
        let nonEmptyPages = allPages.filter { !$0.empty }
        let voiceCount = FirstVoiceStore.count(in: j.firsts.map(\.id))
        let photoCount = j.firsts.filter { FirstPhotoStore.exists(for: $0.id) }.count
        coverLines.append(
            L10n.t(
                "已留存 \(nonEmptyPages.count) 个月份脚印 · \(j.firsts.count) 个第一次（\(photoCount) 张照片 / \(voiceCount) 段声音贴纸）",
                "\(nonEmptyPages.count) documented months · \(j.firsts.count) firsts (\(photoCount) photos / \(voiceCount) voice clips)"
            )
        )
        sections.append(YearbookSection(title: L10n.t("\(who)的三岁成长年鉴", "\(who)'s Three-Year Growth Yearbook"), lines: coverLines))

        for page in nonEmptyPages {
            let mo = app.content.month(page.month)
            let heading = page.month == 0
                ? L10n.t("第 0 站 · 出生与新生儿 · \(mo.title)", "Month 0 · Arrival · \(mo.title)")
                : L10n.t("第 \(page.month) 个月 · \(mo.title)", "Month \(page.month) · \(mo.title)")
            var lines: [String] = []
            var routineParts: [String] = []
            if let f = page.feeds {
                routineParts.append(String(format: L10n.t("日均喂奶 %.1f 次", "%.1f feeds/d"), f))
            }
            if let s = page.sleepHours {
                routineParts.append(String(format: L10n.t("日均睡眠 %.1f h", "%.1fh sleep/d"), s))
            }
            if let d = page.diapers {
                routineParts.append(String(format: L10n.t("尿布 %.1f 片", "%.1f diapers/d"), d))
            }
            if !routineParts.isEmpty {
                lines.append(
                    L10n.t("本月照护节律（有记录 \(page.days) 天）：", "Routine (\(page.days)d logged): ")
                        + routineParts.joined(separator: " · ")
                )
            } else if page.days > 0 {
                lines.append(L10n.t("本月记录天数：\(page.days) 天", "Logged care days: \(page.days)"))
            }
            if let m = page.measure {
                var parts: [String] = []
                if let wg = m.weightG, wg > 0 { parts.append(String(format: "%.2f kg", Double(wg) / 1000)) }
                if let lm = m.lengthMm, lm > 0 { parts.append(String(format: "%.1f cm", Double(lm) / 10)) }
                if let hm = m.headMm, hm > 0 { parts.append(L10n.t("头围 ", "Head ") + String(format: "%.1f cm", Double(hm) / 10)) }
                if !parts.isEmpty {
                    lines.append(L10n.t("生长测量：", "Measurements: ") + parts.joined(separator: " · "))
                }
            }
            if !page.plays.isEmpty {
                let names = page.plays.prefix(6).map { "\($0.play.name) (×\($0.times))" }.joined(separator: L10n.t("、", ", "))
                lines.append(L10n.t("玩过的游戏：", "Plays explored: ") + names)
            }
            for f in page.firsts {
                var tags: [String] = []
                if FirstPhotoStore.exists(for: f.id) { tags.append(L10n.t("相纸", "Photo")) }
                if FirstVoiceStore.exists(for: f.id) { tags.append(L10n.t("童言录音", "Voice")) }
                let badge = tags.isEmpty ? "" : " [" + tags.joined(separator: "·") + "]"
                let notePart = (f.note?.isEmpty == false) ? " — \(f.note!)" : ""
                lines.append(L10n.t("第一次·", "First · ") + Firsts.displayTitle(f) + " (\(Day(f.date).ymd))\(badge)\(notePart)")
            }
            for n in page.notes where !(n.detail ?? "").isEmpty {
                lines.append(L10n.t("手账随笔：", "Note: ") + (n.detail ?? ""))
            }
            if !lines.isEmpty {
                sections.append(YearbookSection(title: heading, lines: lines))
            }
        }

        if !foodRecords.isEmpty {
            let loved = foodRecords.filter { $0.reaction == .loved }.compactMap { FoodItem.item(id: $0.foodId)?.name }.sorted()
            let allergens = foodRecords.filter { FoodItem.item(id: $0.foodId)?.isCommonAllergen == true }
                .compactMap { FoodItem.item(id: $0.foodId)?.name }.sorted()
            var foodLines: [String] = [
                L10n.t("累计尝过 \(foodRecords.count) 种天然食材", "Total foods sampled: \(foodRecords.count)")
            ]
            if !loved.isEmpty {
                foodLines.append(L10n.t("很喜欢的食材：", "Favorites: ") + loved.prefix(12).joined(separator: L10n.t("、", ", ")))
            }
            if !allergens.isEmpty {
                foodLines.append(L10n.t("已稳步引入常见致敏食材：", "Common allergens tried: ") + allergens.joined(separator: L10n.t("、", ", ")))
            }
            sections.append(YearbookSection(title: L10n.t("百味食盒辅食护照", "First Foods Tasting Passport"), lines: foodLines))
        }

        if !capsuleItems.isEmpty {
            var capLines: [String] = []
            for cap in capsuleItems.sorted(by: { $0.writtenAt < $1.writtenAt }) {
                let ageTrim = cap.writtenAgeLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                if cap.isLocked(on: app.today) {
                    let unlockLabel = cap.unlockDay?.ymd ?? L10n.t("未来约定日", "Future date")
                    let agePartZh = ageTrim.isEmpty ? "" : "\(ageTrim)"
                    let agePartEn = ageTrim.isEmpty ? "" : " \(ageTrim)"
                    capLines.append(
                        L10n.t(
                            "[\(cap.seal.title)]《\(cap.title)》· \(agePartZh)封缄（\(unlockLabel)启封，正文封存保密中）",
                            "[\(cap.seal.title)] \"\(cap.title)\" · sealed\(agePartEn) (locked until \(unlockLabel))"
                        )
                    )
                } else {
                    let trimmed = cap.body.trimmingCharacters(in: .whitespacesAndNewlines)
                    let snippet = trimmed.count > 220 ? String(trimmed.prefix(220)) + "…" : trimmed
                    let ageParenZh = ageTrim.isEmpty ? "" : "（\(ageTrim)）"
                    let ageParenEn = ageTrim.isEmpty ? "" : " (\(ageTrim))"
                    capLines.append(
                        L10n.t(
                            "[\(cap.seal.title)]《\(cap.title)》\(ageParenZh)：\(snippet)",
                            "[\(cap.seal.title)] \"\(cap.title)\"\(ageParenEn): \(snippet)"
                        )
                    )
                }
            }
            sections.append(YearbookSection(title: L10n.t("火漆时光胶囊索引", "Wax-Sealed Time Capsules"), lines: capLines))
        }

        return sections
    }

    @MainActor
    static func render(
        app: AppModel,
        j: JournalStore,
        foods: [FoodRecord]? = nil,
        capsules: [TimeCapsule]? = nil
    ) -> Data {
        let sections = buildSections(app: app, j: j, foods: foods, capsules: capsules)
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let photoThumbs: [UIImage] = Array(j.firsts.lazy.compactMap { FirstPhotoStore.load(for: $0.id) }.prefix(4))

        return renderer.pdfData { ctx in
            let margin: CGFloat = 44
            let contentWidth = pageRect.width - margin * 2
            var y: CGFloat = 0
            var pageNo = 0

            let paperBg = UIColor(red: 0.99, green: 0.98, blue: 0.95, alpha: 1)
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor(red: 0.14, green: 0.12, blue: 0.10, alpha: 1)
            ]
            let subAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: UIColor(red: 0.44, green: 0.40, blue: 0.36, alpha: 1)
            ]
            let secTitleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13.5, weight: .bold),
                .foregroundColor: UIColor(red: 0.04, green: 0.49, blue: 0.45, alpha: 1)
            ]
            let bodyAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10.8, weight: .regular),
                .foregroundColor: UIColor(red: 0.16, green: 0.15, blue: 0.14, alpha: 1)
            ]

            func beginFreshPage() {
                ctx.beginPage()
                pageNo += 1
                let cg = ctx.cgContext
                cg.setFillColor(paperBg.cgColor)
                cg.fill(pageRect)
                y = 46

                let footerLeft = L10n.t("摸索台灯 Moss & Otto · 三岁成长年鉴", "Moss & Otto · 3-Year Growth Yearbook")
                let footerRight = L10n.t("第 \(pageNo) 页", "Page \(pageNo)")
                NSAttributedString(string: "\(footerLeft)   ·   \(footerRight)", attributes: subAttr)
                    .draw(in: CGRect(x: margin, y: pageRect.height - 36, width: contentWidth, height: 18))
            }

            func ensureSpace(_ heightNeeded: CGFloat) {
                if y + heightNeeded > pageRect.height - 54 {
                    beginFreshPage()
                }
            }

            @discardableResult
            func drawWrapped(_ text: String, attrs: [NSAttributedString.Key: Any], spacingAfter: CGFloat = 5) -> CGFloat {
                let ns = NSAttributedString(string: text, attributes: attrs)
                let box = ns.boundingRect(
                    with: CGSize(width: contentWidth, height: pageRect.height - 100),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    context: nil
                )
                let h = ceil(box.height) + 2
                ensureSpace(h + spacingAfter)
                ns.draw(with: CGRect(x: margin, y: y, width: contentWidth, height: h), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                y += h + spacingAfter
                return h
            }

            beginFreshPage()

            if let cover = sections.first {
                drawWrapped(cover.title, attrs: titleAttr, spacingAfter: 6)
                drawWrapped(
                    L10n.t("生成于 \(app.today.ymd) · 纯离线端侧保存", "Generated \(app.today.ymd) · 100% On-Device"),
                    attrs: subAttr,
                    spacingAfter: 16
                )
                for line in cover.lines {
                    drawWrapped("• " + line, attrs: bodyAttr, spacingAfter: 5)
                }

                if !photoThumbs.isEmpty {
                    y += 8
                    let thumbSize: CGFloat = 96
                    let gap: CGFloat = 14
                    ensureSpace(thumbSize + 18)
                    for (idx, img) in photoThumbs.enumerated() {
                        let x = margin + CGFloat(idx) * (thumbSize + gap)
                        guard x + thumbSize <= margin + contentWidth else { break }
                        let rect = CGRect(x: x, y: y, width: thumbSize, height: thumbSize)
                        let cg = ctx.cgContext
                        cg.setFillColor(UIColor.white.cgColor)
                        cg.fill(rect.insetBy(dx: -4, dy: -4))
                        cg.setStrokeColor(UIColor(red: 0.85, green: 0.82, blue: 0.77, alpha: 1).cgColor)
                        cg.setLineWidth(0.75)
                        cg.stroke(rect.insetBy(dx: -4, dy: -4))
                        cg.saveGState()
                        cg.clip(to: rect)
                        let iw = max(1, img.size.width)
                        let ih = max(1, img.size.height)
                        let fillScale = max(rect.width / iw, rect.height / ih)
                        let drawW = iw * fillScale
                        let drawH = ih * fillScale
                        img.draw(in: CGRect(x: rect.midX - drawW * 0.5, y: rect.midY - drawH * 0.5, width: drawW, height: drawH))
                        cg.restoreGState()
                    }
                    y += thumbSize + 20
                }
                y += 10
            }

            for sec in sections.dropFirst() {
                ensureSpace(46)
                let cg = ctx.cgContext
                cg.setStrokeColor(UIColor(red: 0.85, green: 0.82, blue: 0.77, alpha: 1).cgColor)
                cg.setLineWidth(0.75)
                cg.move(to: CGPoint(x: margin, y: y))
                cg.addLine(to: CGPoint(x: margin + contentWidth, y: y))
                cg.strokePath()
                y += 10

                drawWrapped(sec.title, attrs: secTitleAttr, spacingAfter: 5)
                for line in sec.lines {
                    drawWrapped("• " + line, attrs: bodyAttr, spacingAfter: 4)
                }
                y += 8
            }
        }
    }
}
