import SwiftUI

/// The guardian's choice, asked plainly before anything about the child is kept (个人信息保护法 第17、29、31条;
/// 儿童个人信息网络保护规定 第10条; App违法违规收集使用个人信息行为认定方法). Two buttons of equal weight, nothing
/// pre-ticked. 不同意 still opens the whole picture book; only the child's details and the records wait, and the card
/// comes back only when the parent asks for one of those.
enum Consent {
    /// Raised when the privacy policy or the children's rules change in substance: everyone is asked again.
    static let version = SharedConsent.version
}

struct ConsentSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var type
    @State private var doc: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Warm editorial picture-book greeting header (verbatim compliance text preserved below)
                    HStack(alignment: .center, spacing: 14) {
                        Duo(primary: .moss, size: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.t("孩子摸索，大人点灯", "They explore. You hold the light."))
                                .font(.headline)
                                .foregroundStyle(Palette.accent)
                            Text(L10n.t("使用前，请阅读以下文件：", "Before you begin, please review:"))
                                .font(.subheadline)
                                .foregroundStyle(Palette.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        docLink(L10n.t("《隐私政策》（含儿童个人信息保护规则）", "Privacy Policy (incl. children's data)"), "PRIVACY", symbol: "hand.raised.fill", color: Crayon.sky)
                        Divider().padding(.leading, 52).opacity(0.5)
                        docLink(L10n.t("《使用条款》", "Terms of Use"), "TERMS", symbol: "doc.text.fill", color: Crayon.pebble)
                        Divider().padding(.leading, 52).opacity(0.5)
                        docLink(L10n.t("《免责声明》", "Disclaimer"), "DISCLAIMER", symbol: "exclamationmark.shield.fill", color: Crayon.tangerine)
                    }
                    .printCard(radius: Radius.card)

                    VStack(spacing: 0) {
                        point(L10n.t("本应用不需要账号、不联网，不含广告、统计或任何第三方 SDK。", "No account, no internet connection, no ads, no analytics, and no third-party SDKs."), symbol: "wifi.slash", color: Crayon.teal)
                        Divider().padding(.leading, 52).opacity(0.5)
                        point(L10n.t("你填写的孩子信息，包括出生日期、小名、性别、生长测量，以及喂养、睡眠、尿布、体温、用药等照护记录，属于不满十四周岁儿童的个人信息，其中包含健康信息。这些信息只保存在这台设备上，开发者无法获取。", "Everything you enter about your child — birthday, nickname, sex, growth measurements, and care logs — is sensitive child health data. It stays only on this iPhone; the developer never sees or receives it."), symbol: "iphone.gen3", color: Crayon.lilac)
                        Divider().padding(.leading, 52).opacity(0.5)
                        point(L10n.t("你可以随时在「工坊 › 离线数据」中导出、清除全部数据，或撤回同意。", "You can export or erase all data, or withdraw consent, anytime in Studio › Local Data."), symbol: "arrow.uturn.backward.circle.fill", color: Crayon.leaf)
                    }
                    .printCard(radius: Radius.card)

                    Text(L10n.t("点「同意」，表示你是孩子的父母或其他监护人，同意本应用按上述文件在本机保存和使用这些信息。点「不同意」，仍可浏览全部玩法和月龄内容，但不能填写孩子资料和记录；此前已经保存的信息仍只在这台手机上，可在「工坊 › 离线数据」导出或清除。以后需要时，可以再次选择同意。", "By tapping Agree, you confirm you are the child's parent or legal guardian and consent to storing and using this information locally on this device. If you tap Not Now, you can still browse all activities and monthly guides without saving child profile or care logs; any data already saved stays on this device and can be exported or erased in Studio › Local Data. You can agree later at any time."))
                        .font(.footnote).foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .safeAreaBar(edge: .bottom) { buttons }
            .navigationTitle(L10n.t("欢迎使用摸索台灯", "Welcome to Moss & Otto"))
            .navigationBarTitleDisplayMode(.inline)
            .pageBackground()
        }
        .interactiveDismissDisabled()
        .sheet(item: Binding(get: { doc.map { ConsentDoc(id: $0) } }, set: { doc = $0?.id })) { d in
            NavigationStack { DocView(name: d.id).toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.t("关闭", "Close"), systemImage: "xmark") { doc = nil } } } }
                .lampPresented()
        }
    }

    private var buttons: some View {
        // equal weight: neither choice is the easy one
        Group {
            if type.isAccessibilitySize {
                VStack(spacing: 10) {
                    Button { answer(false) } label: { Text(L10n.t("不同意", "Not Now")).frame(maxWidth: .infinity).padding(.vertical, 6) }
                        .buttonStyle(.glass).controlSize(.large)
                    Button { answer(true) } label: { Text(L10n.t("同意", "Agree")).frame(maxWidth: .infinity).padding(.vertical, 6) }
                        .buttonStyle(.glass).controlSize(.large)
                }
            } else {
                HStack(spacing: 12) {
                    Button { answer(false) } label: { Text(L10n.t("不同意", "Not Now")).frame(maxWidth: .infinity).padding(.vertical, 6) }
                        .buttonStyle(.glass).controlSize(.large)
                    Button { answer(true) } label: { Text(L10n.t("同意", "Agree")).frame(maxWidth: .infinity).padding(.vertical, 6) }
                        .buttonStyle(.glass).controlSize(.large)
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }

    private func answer(_ yes: Bool) {
        app.consent = yes ? Consent.version : "declined"
        app.askConsent = false
        // declined: nothing more about the child is kept — the records (and the widgets' quick logging) are turned off
        if !yes { app.journal = false }
    }

    private func docLink(_ title: String, _ name: String, symbol: String, color: Color) -> some View {
        Button { doc = name } label: {
            HStack(spacing: 10) {
                IconTile(symbol: symbol, color: color, size: 28, round: true)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.toy)
    }

    private func point(_ t: String, symbol: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            IconTile(symbol: symbol, color: color, size: 28, round: true)
            Text(t)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

private struct ConsentDoc: Identifiable { let id: String }
