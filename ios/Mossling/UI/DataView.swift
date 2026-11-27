import SwiftUI
import UniformTypeIdentifiers
import WidgetKit

/// 导出与导入: everything recorded leaves the phone only when the parent asks, in four forms — a full JSON backup that
/// can be read back (and by the Android app), a readable record for a paediatrician or an AI assistant, a 3-year PDF
/// yearbook, and a spreadsheet. Files are staged privately in Application Support until explicitly shared or saved via
/// the system Share sheet.
struct DataView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @Environment(\.colorScheme) private var scheme
    @Environment(\.lamp) private var lamp
    @State private var saved: URL?
    @State private var importing = false
    @State private var message: String?
    @State private var confirmImport: URL?
    @State private var clearing = false
    @State private var withdrawing = false

    private static let maxImportBytes = 20 * 1024 * 1024

    enum Export: String, CaseIterable, Identifiable {
        case summary, yearbook, backup, table
        var id: String { rawValue }
        var title: String {
            switch self {
            case .summary: L10n.t("给医生或 AI 看的记录", "Record for doctor or AI")
            case .yearbook: L10n.t("三岁成长年鉴（PDF）", "3-Year Growth Yearbook (PDF)")
            case .backup: L10n.t("完整备份", "Full backup")
            case .table: L10n.t("表格", "Spreadsheet")
            }
        }
        var fileSlug: String {
            switch self {
            case .summary: L10n.t("给医生或 AI 看的记录", "Record")
            case .yearbook: L10n.t("三岁成长年鉴", "Yearbook")
            case .backup: L10n.t("完整备份", "Backup")
            case .table: L10n.t("表格", "Spreadsheet")
            }
        }
        var detail: String {
            switch self {
            case .summary: L10n.t("孩子的资料、生长测量与百分位、百味食盒辅食记录、每天汇总、每月记下的事与全部记录", "Child profile, growth measurements with percentiles, First Foods tasting log, daily totals, monthly notes, and every entry")
            case .yearbook: L10n.t("图文并排的多页纪念册 PDF（含每月足迹、第一次相纸与辅食护照；未启封未来胶囊严格保密）", "Multi-page printable keepsake PDF with monthly milestones, Firsts photos, and Food Passport (locked capsules stay sealed)")
            case .backup: L10n.t("结构化设置、日志、测量、百味食盒记录与时光胶囊信件（原图与童声录音留在手机本地，可随整机迁移带走）", "Structured settings, logs, measurements, First Foods, and sealed letters (original photos & voice clips stay on this iPhone across device transfer)")
            case .table: L10n.t("每一条记录一行，可用 Numbers 或 Excel 打开", "One entry per row, ready to open in Numbers or Excel")
            }
        }
        var symbol: String {
            switch self {
            case .summary: "doc.text.fill"
            case .yearbook: "book.closed.fill"
            case .backup: "externaldrive.fill"
            case .table: "tablecells.fill"
            }
        }
        var color: Color {
            switch self {
            case .summary: Crayon.pink
            case .yearbook: Palette.bead
            case .backup: Crayon.sky
            case .table: Crayon.leaf
            }
        }
        var ext: String {
            switch self {
            case .summary: "md"
            case .yearbook: "pdf"
            case .backup: "json"
            case .table: "csv"
            }
        }
    }

    var body: some View {
        let dark = lamp || scheme == .dark
        ScrollView {
            VStack(alignment: .leading, spacing: LayoutSpec.cardGap) {
                Text(L10n.t("摸索台灯不做发育评测。记下的一切都可以按需生成导出文件：交给儿科医生，或交给你信任的 AI 助手帮你整理和提问。导出的文件含孩子的出生日期、生长和健康记录；交给他人或其他应用（包括 AI 助手）后，如何处理由接收方负责，请只交给你信任的对象。文件发送或保存到其他位置后不再受本应用保护。", "Moss & Otto does not assess development. Everything you log can be exported on demand—for your pediatrician, or for an AI assistant you trust to help organize notes and prepare questions. Exported files include your child's birth date, growth, and health records. Once shared with another person or app, that recipient is responsible for how the file is handled, and it is no longer protected by this app. Share only with people and services you trust."))
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(LayoutSpec.cardPad)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .printCard(radius: Radius.card)

                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(title: L10n.t("按需导出", "Export"))
                    VStack(spacing: 0) {
                        ForEach(Array(Export.allCases.enumerated()), id: \.element.id) { idx, k in
                            Button { export(k) } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    IconTile(symbol: k.symbol, color: k.color, size: 34)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(k.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)
                                        Text(k.detail)
                                            .font(.footnote)
                                            .foregroundStyle(Palette.secondaryText)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Palette.accent)
                                        .padding(.top, 4)
                                }
                                .padding(.horizontal, LayoutSpec.cardPad)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.toy)
                            .accessibilityHint(L10n.t("生成文件并通过系统分享菜单保存或转发", "Generates a file ready to save to Files or share"))

                            if idx < Export.allCases.count - 1 {
                                Divider().padding(.leading, 62).opacity(0.45)
                            }
                        }
                    }
                    .printCard(radius: Radius.card)

                    Text(L10n.t("导出文件先保存在受保护的应用私有容器中，不会直接暴露进公共文件夹；生成后请在下方点击分享以存到「文件」或发送。", "Exports are staged privately on this iPhone without exposing a public folder. Use the Share action below to save to Files or send."))
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }

                if let url = saved {
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                IconTile(symbol: "checkmark.circle.fill", color: Crayon.leaf, size: 30, round: true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.t("已生成导出文件", "Export ready"))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(dark ? Crayon.leaf : Crayon.ink(Crayon.leaf))
                                    Text(url.lastPathComponent)
                                        .font(.caption)
                                        .foregroundStyle(Palette.secondaryText)
                                        .textSelection(.enabled)
                                }
                                Spacer(minLength: 0)
                            }

                            ShareLink(item: url, subject: Text(L10n.t("摸索台灯记录", "Moss & Otto record"))) {
                                Label(L10n.t("存储到文件 / 发送给医生或家人…", "Save to Files / Share…"), systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                                    .dsPill(.primary, height: LayoutSpec.ctaSecondaryHeight)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(LayoutSpec.cardPad)
                        .printCard(radius: Radius.card)

                        Text(L10n.t("发送时，系统可能询问是否允许使用隔空投送或 iCloud 云盘。摸索台灯本身不联网，选择「不允许」不影响任何本地功能。", "When sharing, iOS may ask for AirDrop or iCloud Drive access. Moss & Otto never connects to the internet—tapping Don't Allow will not affect any feature."))
                            .font(.caption)
                            .foregroundStyle(Palette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(title: L10n.t("导入", "Import"))
                    Button { if app.mayKeep() { importing = true } } label: {
                        HStack(spacing: 12) {
                            IconTile(symbol: "square.and.arrow.down.on.square.fill", color: Crayon.lilac, size: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.t("导入完整备份", "Import full backup"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(L10n.t("从摸索台灯导出的 JSON 备份文件", "A JSON backup file exported from Moss & Otto"))
                                    .font(.footnote)
                                    .foregroundStyle(Palette.secondaryText)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(LayoutSpec.cardPad)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.toy)
                    .printCard(radius: Radius.card)

                    Text(L10n.t("导入会用备份里的内容替换这台手机上现有的记录和设置（上限 20 MB）。", "Importing replaces current records and settings on this iPhone (max 20 MB)."))
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }

                // the one thing that removes everything, last, in red, behind a confirmation
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(title: L10n.t("清除与撤回", "Erase & Consent"))
                    VStack(spacing: 0) {
                        Button(role: .destructive) { clearing = true } label: {
                            HStack(spacing: 10) {
                                IconTile(symbol: "trash.fill", color: Palette.danger, size: 30, round: true)
                                Text(L10n.t("清除全部数据", "Clear all data"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Palette.danger)
                                Spacer(minLength: 0)
                            }
                            .padding(LayoutSpec.cardPad)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.toy)

                        // 个人信息保护法 第15条: consent can be withdrawn as easily as it was given
                        if app.consented {
                            Divider().padding(.leading, 56).opacity(0.45)
                            Button(role: .destructive) { withdrawing = true } label: {
                                HStack(spacing: 10) {
                                    IconTile(symbol: "hand.raised.slash.fill", color: Palette.danger, size: 30, round: true)
                                    Text(L10n.t("撤回同意", "Withdraw consent"))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Palette.danger)
                                    Spacer(minLength: 0)
                                }
                                .padding(LayoutSpec.cardPad)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.toy)
                        }
                    }
                    .printCard(radius: Radius.card)

                    Text(L10n.t("所有记录只保存在这台手机上。清除会删除孩子资料、全部记录、设置，以及本机暂存的导出文件；已经发送到其他地方的文件不受影响。撤回同意会同时清除以上全部数据，之后仍可浏览全部内容。", "All records stay on this iPhone. Clearing removes your child's profile, all records, settings, and locally staged exports; files already shared elsewhere are unaffected. Withdrawing consent clears all of the above while leaving all guides available."))
                        .font(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, LayoutSpec.pageH)
            .padding(.vertical, 12)
        }
        .calmWhileScrolling()
        .pageBackground(tone: Crayon.lilac)
        .navigationTitle(L10n.t("离线备份", "Local Data"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(L10n.t("清除这台手机上的全部数据？", "Clear all data on this iPhone?"), isPresented: $clearing, titleVisibility: .visible) {
            Button(L10n.t("全部清除", "Clear all"), role: .destructive) {
                app.clearAll()
                j.reload()
                j.toast = nil
                j.focus = nil
                j.ask = nil
                saved = nil
            }
        } message: { Text(L10n.t("包括孩子资料、全部记录、设置与本机暂存的导出文件。清除后无法恢复。", "This includes your child's profile, all records, settings, and staged exports. This cannot be undone.")) }
        .confirmationDialog(L10n.t("撤回同意，并清除这台手机上的全部数据？", "Withdraw consent and clear all data on this iPhone?"), isPresented: $withdrawing, titleVisibility: .visible) {
            Button(L10n.t("撤回并清除", "Withdraw and clear"), role: .destructive) {
                app.clearAll()
                app.consent = "declined"
                app.onboarded = true
                j.reload()
                j.toast = nil
                j.focus = nil
                j.ask = nil
                saved = nil
            }
        } message: { Text(L10n.t("撤回后不再保存孩子的信息，已保存的会全部删除，无法恢复；需要保留的，请先在上面导出完整备份。仍可浏览全部玩法和月龄内容。以后需要时，可以再次选择同意。", "After withdrawing, no child information will be stored and all saved data will be permanently deleted. Export a full backup above first if you want to keep a copy. You can still browse all activities and age guides, and agree again anytime.")) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { r in
            if case let .success(url) = r { confirmImport = url }
        }
        .confirmationDialog(L10n.t("用这份备份替换现有的记录和设置？", "Replace current records and settings with this backup?"), isPresented: Binding(get: { confirmImport != nil }, set: { if !$0 { confirmImport = nil } }), titleVisibility: .visible) {
            Button(L10n.t("替换", "Replace"), role: .destructive) { if let u = confirmImport { load(u) }; confirmImport = nil }
        } message: { Text(L10n.t("替换后无法恢复。如需保留现有内容，可先导出一份完整备份。", "This cannot be undone. Export a full backup first if you want to keep your current data.")) }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button(L10n.t("好", "OK")) {} }
    }

    private func export(_ k: Export) {
        if (k == .backup || k == .yearbook), (CapsuleStore.shared.loadFailed || FoodAtlasStore.shared.loadFailed) {
            message = L10n.t("辅食或时光胶囊读取失败，为避免导出空备份覆盖原有数据，请先在对应页面点击重试后再导出。", "Foods or Time Capsule storage failed to load. Retry loading before exporting so existing data isn't replaced by empty records.")
            return
        }
        let body: JournalFile.Body
        do {
            body = try JournalFile.load()
        } catch {
            message = L10n.t("读取记录失败，请稍后重试。", "Couldn't read saved records. Please try again.")
            return
        }
        let foods = Array(FoodAtlasStore.shared.records.values)
        let capsules = CapsuleStore.shared.items
        let data: Data = switch k {
        case .summary: RecordFile.summary(app, body, foods: foods)
        case .yearbook: GrowthYearbookPDF.render(app: app, j: JournalStore(preview: body), foods: foods, capsules: capsules)
        case .backup: RecordFile.json(app, body, foods: foods, capsules: capsules)
        case .table: RecordFile.csv(body)
        }
        let d = Day.today, t = hm(Date()).replacingOccurrences(of: ":", with: "")
        let name = "\(L10n.appName)-\(k.fileSlug)-" + String(format: "%04d%02d%02d", d.y, d.m, d.d) + "-\(t).\(k.ext)"
        do {
            let fm = FileManager.default
            var dir = DataView.exportFolder
            try? fm.removeItem(at: dir)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            var rv = URLResourceValues()
            rv.isExcludedFromBackup = true
            try? dir.setResourceValues(rv)
            let url = dir.appendingPathComponent(name)
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            withAnimation(.snappy) { saved = url }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            message = L10n.t("没有存成功，请检查 iPhone 的存储空间后再试。", "Couldn't save the file. Check your iPhone storage and try again.")
        }
    }

    private func load(_ url: URL) {
        let ok = url.startAccessingSecurityScopedResource(); defer { if ok { url.stopAccessingSecurityScopedResource() } }
        do {
            if let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, fileSize > Self.maxImportBytes {
                message = L10n.t("备份文件超过 20 MB，无法导入。", "Backup file exceeds the 20 MB limit.")
                return
            }
            let data = try Data(contentsOf: url)
            guard data.count <= Self.maxImportBytes else {
                message = L10n.t("备份文件超过 20 MB，无法导入。", "Backup file exceeds the 20 MB limit.")
                return
            }
            try RecordFile.load(data, into: app, journal: j, foodStore: .shared, capsuleStore: .shared)
            Task { await LiveTimers.sync() }
            WidgetCenter.shared.reloadAllTimelines()
            message = L10n.t("已导入", "Imported")
        }
        catch RecordFile.Failure.notOurs { message = L10n.t("这不是摸索台灯导出的备份文件", "This isn't a Moss & Otto backup file.") }
        catch RecordFile.Failure.saveFailed { message = L10n.t("没有导入成功，请检查 iPhone 的存储空间后再试。", "Couldn't import the backup. Check your iPhone storage and try again.") }
        catch { message = L10n.t("没有导入成功，文件可能已损坏", "Couldn't import the backup. The file may be damaged.") }
    }

    /// Protected staging folder under Application Support (hidden from the Files app; shared on demand).
    static var exportFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Exports", isDirectory: true)
    }

    /// Legacy public Documents/导出 folder cleaned up during `AppModel.clearAll()` and `tidyDocuments()`.
    static var legacyDocumentsExportFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("导出", isDirectory: true)
    }

    /// Moves any legacy files placed in Documents aside into Application Support.
    static func tidyDocuments() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var keep = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("earlier", isDirectory: true)
        guard let items = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) else { return }
        for u in items {
            // with no app group the journal itself lives in Documents: leave it where the app reads it
            if JournalFile.dir.standardizedFileURL == docs.standardizedFileURL && ["journal.json", "snapshot.json"].contains(u.lastPathComponent) { continue }
            try? fm.createDirectory(at: keep, withIntermediateDirectories: true)
            var rv = URLResourceValues()
            rv.isExcludedFromBackup = true
            try? keep.setResourceValues(rv)
            let preferred = keep.appendingPathComponent(u.lastPathComponent)
            let dest = fm.fileExists(atPath: preferred.path)
                ? keep.appendingPathComponent("\(UUID().uuidString)-\(u.lastPathComponent)")
                : preferred
            try? fm.moveItem(at: u, to: dest)
        }
    }
}
