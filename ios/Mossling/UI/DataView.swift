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

    enum Export: String, CaseIterable, Identifiable {
        case summary, backup, table
        var id: String { rawValue }
        var title: String { switch self { case .summary: "给医生或 AI 看的记录"; case .backup: "完整备份"; case .table: "表格" } }
        var detail: String {
            switch self {
            case .summary: "孩子的资料、生长测量与百分位、每天的喂奶睡眠尿布汇总、每月记下的事、全部记录，按时间排好的一份文档"
            case .backup: "全部设置与记录，包括正在进行的计时；可以导回本应用或安卓版"
            case .table: "每一条记录一行，可用 Numbers 或 Excel 打开"
            }
        }
        var symbol: String { switch self { case .summary: "stethoscope"; case .backup: "externaldrive.fill"; case .table: "tablecells.fill" } }
        var color: Color { switch self { case .summary: Crayon.pink; case .backup: Crayon.sky; case .table: Crayon.leaf } }
        var ext: String { switch self { case .summary: "md"; case .backup: "json"; case .table: "csv" } }
    }

    var body: some View {
        List {
            Section {
                Text("摸索台灯不做发育评测。记下的一切都可以完整导出：交给儿科医生，或交给你信任的 AI 助手帮你整理和提问。")
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
                    .accessibilityHint("存到「文件」App")
                }
            } header: { Text("导出") } footer: {
                Text("文件存到「文件」App ›「我的 iPhone」›「摸索台灯」›「导出」。")
            }
            if let url = saved {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("已存好", systemImage: "checkmark.circle.fill").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.accent)
                        Text(url.lastPathComponent).font(.footnote).foregroundStyle(Palette.secondaryText).textSelection(.enabled)
                    }
                    ShareLink(item: url) { Label("发送给医生或其他应用…", systemImage: "square.and.arrow.up") }
                } footer: {
                    Text("发送时，系统可能询问是否允许摸索台灯使用网络（隔空投送、iCloud 云盘需要）。摸索台灯本身不联网，选择「不允许」不影响任何功能。")
                }
            }
            Section {
                Button { importing = true } label: {
                    HStack(spacing: 12) {
                        IconTile(symbol: "square.and.arrow.down.on.square.fill", color: Crayon.lilac, size: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("导入完整备份").font(.body.weight(.semibold)).foregroundStyle(.primary)
                            Text("从摸索台灯（iOS 或安卓）导出的备份文件").font(.footnote).foregroundStyle(Palette.secondaryText)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: { Text("导入") } footer: {
                Text("导入会用备份里的内容替换这台手机上现有的记录和设置。")
            }
            // the one thing that removes everything, last, in red, behind a confirmation
            Section {
                Button(role: .destructive) { clearing = true } label: {
                    Text("清除全部数据").font(.body.weight(.semibold)).foregroundStyle(Palette.danger)
                }
            } footer: { Text("所有记录只保存在这台手机上。清除前可以先导出一份完整备份。") }
        }
        .scrollContentBackground(.hidden).pageBackground(tone: Crayon.lilac)
        .navigationTitle("数据").navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("清除这台手机上的全部记录和设置？", isPresented: $clearing, titleVisibility: .visible) {
            Button("全部清除", role: .destructive) { app.clearAll(); j.reload() }
        } message: { Text("清除后无法恢复。") }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { r in
            if case let .success(url) = r { confirmImport = url }
        }
        .confirmationDialog("用这份备份替换现有的记录和设置？", isPresented: Binding(get: { confirmImport != nil }, set: { if !$0 { confirmImport = nil } }), titleVisibility: .visible) {
            Button("替换", role: .destructive) { if let u = confirmImport { load(u) }; confirmImport = nil }
        } message: { Text("替换后无法恢复。如需保留现有内容，可先导出一份完整备份。") }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button("好") {} }
    }

    private func export(_ k: Export) {
        let body = JournalFile.read()
        let data: Data = switch k { case .summary: RecordFile.summary(app, body); case .backup: RecordFile.json(app, body); case .table: RecordFile.csv(body) }
        let d = Day.today, t = hm(Date()).replacingOccurrences(of: ":", with: "")
        let name = "摸索台灯-\(k.title)-" + String(format: "%04d%02d%02d", d.y, d.m, d.d) + "-\(t).\(k.ext)"
        do {
            let dir = DataView.exportFolder
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            withAnimation(.snappy) { saved = url }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            message = "没有存成功，请检查 iPhone 的存储空间后再试。"
        }
    }

    private func load(_ url: URL) {
        let ok = url.startAccessingSecurityScopedResource(); defer { if ok { url.stopAccessingSecurityScopedResource() } }
        do { try RecordFile.load(Data(contentsOf: url), into: app, journal: j); message = "已导入" }
        catch { message = error is RecordFile.Failure ? "这不是摸索台灯导出的备份文件" : "没有导入成功，文件可能已损坏" }
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
