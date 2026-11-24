import SwiftUI
import UniformTypeIdentifiers

/// 导出与导入: everything recorded leaves the phone only when the parent asks, in three forms — a full backup that
/// can be read back (and by the Android app), a readable record for a paediatrician or an AI assistant (the app makes
/// no assessment of its own; this is what makes the record useful), and a table. Each is written straight into the
/// app's own folder in the Files app (我的 iPhone › 摸索台灯 › 导出): no picker, no network. From there, or with 发送,
/// it goes wherever the parent chooses.
struct DataView: View {
    @Environment(AppModel.self) private var app
    @Environment(JournalStore.self) private var j
    @State private var saved: URL?
    @State private var importing = false
    @State private var message: String?
    @State private var confirmImport: URL?
    @State private var clearing = false
    @State private var withdrawing = false

    enum Export: String, CaseIterable, Identifiable {
        case summary, backup, table
        var id: String { rawValue }
        var title: String {
            switch self {
            case .summary: L10n.t("给医生或 AI 看的记录", "Record for doctor or AI")
            case .backup: L10n.t("完整备份", "Full backup")
            case .table: L10n.t("表格", "Spreadsheet")
            }
        }
        var fileSlug: String {
            switch self {
            case .summary: L10n.t("给医生或 AI 看的记录", "Record")
            case .backup: L10n.t("完整备份", "Backup")
            case .table: L10n.t("表格", "Spreadsheet")
            }
        }
        var detail: String {
            switch self {
            case .summary: L10n.t("孩子的资料、生长测量与百分位、百味食盒辅食记录、每天汇总、每月记下的事与全部记录", "Child profile, growth measurements with percentiles, First Foods tasting log, daily totals, monthly notes, and every entry")
            case .backup: L10n.t("全部设置与记录（含百味食盒、时光胶囊与进行中计时）；可以导回摸索台灯", "All settings and records (including First Foods, Time Capsules, and active timers); can be imported back into Moss & Otto")
            case .table: L10n.t("每一条记录一行，可用 Numbers 或 Excel 打开", "One entry per row, ready to open in Numbers or Excel")
            }
        }
        var symbol: String { switch self { case .summary: "doc.text.fill"; case .backup: "externaldrive.fill"; case .table: "tablecells.fill" } }
        var color: Color { switch self { case .summary: Crayon.pink; case .backup: Crayon.sky; case .table: Crayon.leaf } }
        var ext: String { switch self { case .summary: "md"; case .backup: "json"; case .table: "csv" } }
    }

    var body: some View {
        List {
            Section {
                Text(L10n.t("摸索台灯不做发育评测。记下的一切都可以完整导出：交给儿科医生，或交给你信任的 AI 助手帮你整理和提问。导出的文件含孩子的出生日期、生长和健康记录；交给他人或其他应用（包括 AI 助手）后，如何处理由接收方负责，请只交给你信任的对象。文件发送或复制到这台手机以外后不再受本应用保护。", "Moss & Otto does not assess development. Everything you log can be exported in full—for your pediatrician, or for an AI assistant you trust to help organize notes and prepare questions. Exported files include your child's birth date, growth, and health records. Once shared with another person or app, that recipient is responsible for how the file is handled, and it is no longer protected by this app. Share only with people and services you trust."))
                    .font(.subheadline).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                    .listRowBackground(Color.clear)
            }
            Section {
                ForEach(Export.allCases) { k in
                    Button { export(k) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            IconTile(symbol: k.symbol, color: k.color, size: 34)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(k.title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                                Text(k.detail).font(.footnote).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "square.and.arrow.down").foregroundStyle(Palette.accent).padding(.top, 4)
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityHint(L10n.t("存到「文件」App", "Save to the Files app"))
                }
            } header: { Text(L10n.t("导出", "Export")) } footer: {
                Text(L10n.t("文件存到「文件」App ›「我的 iPhone」›「摸索台灯」›「导出」。", "Files are saved in the Files app under On My iPhone › Moss & Otto."))
            }
            if let url = saved {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(L10n.t("已存好", "Saved"), systemImage: "checkmark.circle.fill").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.accent)
                        Text(url.lastPathComponent).font(.footnote).foregroundStyle(Palette.secondaryText).textSelection(.enabled)
                    }
                    ShareLink(item: url, subject: Text(L10n.t("摸索台灯记录", "Moss & Otto record"))) {
                        Label(L10n.t("发送给医生或其他应用…", "Share with doctor or another app…"), systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text(L10n.t("发送时，系统可能询问是否允许摸索台灯使用网络（隔空投送、iCloud 云盘需要）。摸索台灯本身不联网，选择「不允许」不影响任何功能。", "When sharing, iOS may ask for network access (used by AirDrop or iCloud Drive). Moss & Otto never connects to the internet—tapping Don't Allow will not affect any feature."))
                }
            }
            Section {
                Button { if app.mayKeep() { importing = true } } label: {
                    HStack(spacing: 12) {
                        IconTile(symbol: "square.and.arrow.down.on.square.fill", color: Crayon.lilac, size: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.t("导入完整备份", "Import full backup")).font(.body.weight(.semibold)).foregroundStyle(.primary)
                            Text(L10n.t("从摸索台灯导出的完整备份文件", "A full backup file exported from Moss & Otto")).font(.footnote).foregroundStyle(Palette.secondaryText)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: { Text(L10n.t("导入", "Import")) } footer: {
                Text(L10n.t("导入会用备份里的内容替换这台手机上现有的记录和设置。", "Importing replaces all current records and settings on this iPhone with the backup."))
            }
            // the one thing that removes everything, last, in red, behind a confirmation
            Section {
                Button(role: .destructive) { clearing = true } label: {
                    Text(L10n.t("清除全部数据", "Clear all data")).font(.body.weight(.semibold)).foregroundStyle(Palette.danger)
                }
                // 个人信息保护法 第15条: consent can be withdrawn as easily as it was given
                if app.consented {
                    Button(role: .destructive) { withdrawing = true } label: {
                        Text(L10n.t("撤回同意", "Withdraw consent")).font(.body.weight(.semibold)).foregroundStyle(Palette.danger)
                    }
                }
            } footer: { Text(L10n.t("所有记录只保存在这台手机上。清除会删除孩子资料、全部记录、设置，以及存在「导出」文件夹里的文件；已经发送到其他地方的文件不受影响。清除前可以先导出一份完整备份。撤回同意会同时清除以上全部数据，之后仍可浏览全部内容。", "All records stay on this iPhone. Clearing removes your child's profile, all records, settings, and files saved in the export folder; files already shared elsewhere are unaffected. You can export a full backup first. Withdrawing consent also clears all of the above, while leaving all guides and activities available to browse.")) }
        }
        .scrollContentBackground(.hidden).pageBackground(tone: Crayon.lilac)
        .navigationTitle(L10n.t("数据", "Data")).navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(L10n.t("清除这台手机上的全部数据？", "Clear all data on this iPhone?"), isPresented: $clearing, titleVisibility: .visible) {
            Button(L10n.t("全部清除", "Clear all"), role: .destructive) { app.clearAll(); j.reload(); saved = nil }
        } message: { Text(L10n.t("包括孩子资料、全部记录、设置和「导出」文件夹里的文件。清除后无法恢复。", "This includes your child's profile, all records, settings, and exported files. This cannot be undone.")) }
        .confirmationDialog(L10n.t("撤回同意，并清除这台手机上的全部数据？", "Withdraw consent and clear all data on this iPhone?"), isPresented: $withdrawing, titleVisibility: .visible) {
            Button(L10n.t("撤回并清除", "Withdraw and clear"), role: .destructive) { app.clearAll(); app.consent = "declined"; app.onboarded = true; j.reload(); saved = nil }
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
        let body = JournalFile.read()
        let foods = Array(FoodAtlasStore.shared.records.values)
        let capsules = CapsuleStore.shared.items
        let data: Data = switch k {
        case .summary: RecordFile.summary(app, body, foods: foods)
        case .backup: RecordFile.json(app, body, foods: foods, capsules: capsules)
        case .table: RecordFile.csv(body)
        }
        let d = Day.today, t = hm(Date()).replacingOccurrences(of: ":", with: "")
        let name = "\(L10n.appName)-\(k.fileSlug)-" + String(format: "%04d%02d%02d", d.y, d.m, d.d) + "-\(t).\(k.ext)"
        do {
            let dir = DataView.exportFolder
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
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
        do { try RecordFile.load(Data(contentsOf: url), into: app, journal: j, foodStore: .shared, capsuleStore: .shared); message = L10n.t("已导入", "Imported") }
        catch RecordFile.Failure.notOurs { message = L10n.t("这不是摸索台灯导出的备份文件", "This isn't a Moss & Otto backup file.") }
        catch RecordFile.Failure.saveFailed { message = L10n.t("没有导入成功，请检查 iPhone 的存储空间后再试。", "Couldn't import the backup. Check your iPhone storage and try again.") }
        catch { message = L10n.t("没有导入成功，文件可能已损坏", "Couldn't import the backup. The file may be damaged.") }
    }

    /// The app's own folder in the Files app (Documents is shared there: UIFileSharingEnabled), its 导出 subfolder.
    static var exportFolder: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("导出", isDirectory: true) }

    /// Documents is visible in the Files app, so nothing internal is left there: files older builds kept in Documents
    /// (the journal before the app group, moved aside after migrating) go to Library, out of sight. Moved, not deleted.
    static func tidyDocuments() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let keep = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("earlier", isDirectory: true)
        guard let items = try? fm.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) else { return }
        for u in items where u.lastPathComponent != "导出" {
            // with no app group the journal itself lives in Documents: leave it where the app reads it
            if JournalFile.dir.standardizedFileURL == docs.standardizedFileURL && ["journal.json", "snapshot.json"].contains(u.lastPathComponent) { continue }
            try? fm.createDirectory(at: keep, withIntermediateDirectories: true)
            try? fm.moveItem(at: u, to: keep.appendingPathComponent(u.lastPathComponent))
        }
    }
}
