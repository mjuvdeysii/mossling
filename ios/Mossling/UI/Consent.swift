import SwiftUI

/// The guardian's choice, asked plainly before anything about the child is kept (个人信息保护法 第17、29、31条;
/// 儿童个人信息网络保护规定 第10条; App违法违规收集使用个人信息行为认定方法). Two buttons of equal weight, nothing
/// pre-ticked. 不同意 still opens the whole picture book; only the child's details and the records wait, and the card
/// comes back only when the parent asks for one of those.
enum Consent {
    /// Raised when the privacy policy or the children's rules change in substance: everyone is asked again.
    static let version = "2026-10-31"
}

struct ConsentSheet: View {
    @Environment(AppModel.self) private var app
    @State private var doc: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("使用前，请阅读以下文件：").font(.body)
                    VStack(alignment: .leading, spacing: 8) {
                        docLink("《隐私政策》（含儿童个人信息保护规则）", "PRIVACY")
                        docLink("《使用条款》", "TERMS")
                        docLink("《免责声明》", "DISCLAIMER")
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        point("本应用不需要账号、不联网，不含广告、统计或任何第三方 SDK。")
                        point("你填写的孩子信息，包括出生日期、小名、性别、生长测量，以及喂养、睡眠、尿布、体温、用药等照护记录，属于不满十四周岁儿童的个人信息，其中包含健康信息。这些信息只保存在这台设备上，开发者无法获取。")
                        point("你可以随时在「我的 › 数据」中导出、清除全部数据，或撤回同意。")
                    }
                    Text("点「同意」，表示你是孩子的父母或其他监护人，同意本应用按上述文件在本机保存和使用这些信息。点「不同意」，仍可浏览全部玩法和月龄内容，但不能填写孩子资料和记录；此前已经保存的信息仍只在这台手机上，可在「我的 › 数据」导出或清除。以后需要时，可以再次选择同意。")
                        .font(.subheadline).foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .safeAreaBar(edge: .bottom) { buttons }
            .navigationTitle("欢迎使用摸索台灯")
            .navigationBarTitleDisplayMode(.inline)
            .pageBackground()
        }
        .interactiveDismissDisabled()
        .sheet(item: Binding(get: { doc.map { ConsentDoc(id: $0) } }, set: { doc = $0?.id })) { d in
            NavigationStack { DocView(name: d.id).toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成", systemImage: "checkmark") { doc = nil } } } }
        }
    }

    private var buttons: some View {
        // equal weight: neither choice is the easy one
        HStack(spacing: 12) {
            Button { answer(false) } label: { Text("不同意").frame(maxWidth: .infinity).padding(.vertical, 6) }
                .buttonStyle(.glass).controlSize(.large)
            Button { answer(true) } label: { Text("同意").frame(maxWidth: .infinity).padding(.vertical, 6) }
                .buttonStyle(.glass).controlSize(.large)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }

    private func answer(_ yes: Bool) {
        app.consent = yes ? Consent.version : "declined"
        app.askConsent = false
        // declined: nothing more about the child is kept — the records (and the widgets' quick logging) are turned off
        if !yes { app.journal = false }
    }

    private func docLink(_ title: String, _ name: String) -> some View {
        Button { doc = name } label: {
            HStack(spacing: 6) {
                Text(title).font(.body.weight(.semibold))
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
            }
        }
        .tint(Palette.accent)
    }

    private func point(_ t: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("·").font(.body.weight(.bold))
            Text(t).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ConsentDoc: Identifiable { let id: String }
