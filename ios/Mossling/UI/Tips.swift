import SwiftUI
import TipKit

// 使用引导：TipKit（系统原生的就地提示，HIG「Offering help」），每条在出现的位置说明一件事，可以关掉，看过不再出现。
// 文字是中立的界面说明，不出自 Moss 或 Otto（IP v1.3：角色不说话）。首次欢迎页之后不再插入多页引导，提示只在
// 家长第一次来到相应位置时出现。

enum Guide {
    /// Called once at launch. Not in unit tests (screenshots stay comparable).
    static func configure() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        let d = UserDefaults.standard
        if d.bool(forKey: "tipsReset") { try? Tips.resetDatastore(); d.removeObject(forKey: "tipsReset") }
        try? Tips.configure([.displayFrequency(.immediate)])
    }
    /// Shows every tip again from the next launch (TipKit resets only before it is configured).
    static func replayNextLaunch() { UserDefaults.standard.set(true, forKey: "tipsReset") }
}

/// 本月 · this week's shelf.
struct ShelfTip: Tip {
    var title: Text { Text(L10n.t("今天一起玩", "Play together today")) }
    var message: Text? { Text(L10n.t("点开跟着图一步步玩，做完最后一步会自动记一次。「换一个」在这周的几个活动里换；「调整」可以换这周的活动。点月份卡看这个月的全部内容。", "Tap to follow step by step—finishing the last step logs it automatically. Use \"Swap\" to cycle this week's activities, or \"Adjust\" to pick different ones. Tap the month card to see everything for this month.")) }
    var image: Image? { Image(systemName: "hand.tap") }
}

/// 本月 · the records, which are off until turned on.
struct RecordsTip: Tip {
    var title: Text { Text(L10n.t("需要记录喂奶和睡眠？", "Want to track feeds & sleep?")) }
    var message: Text? { Text(L10n.t("打开「记录」后，亲喂、瓶喂、睡眠、尿布都能一点即记，锁屏上也能看到计时。之后可在「我的」里关闭。", "Turn on Log to record nursing, bottles, sleep, and diapers in a tap, with live timers on your Lock Screen. You can turn it off anytime in Me.")) }
    var image: Image? { Image(systemName: "list.bullet.clipboard") }
    var actions: [Action] { [Action(id: "on") { Text(L10n.t("打开记录", "Turn on Log")) }] }
    /// Only while the records are off.
    @Parameter static var recordsOff: Bool = true
    var rules: [Rule] { [#Rule(Self.$recordsOff) { $0 == true }] }
}

/// 记录 · the stickers.
struct StickerTip: Tip {
    var title: Text { Text(L10n.t("点一下就记", "Tap to log")) }
    var message: Text? { Text(L10n.t("瓶喂、尿布等点贴纸记下，时间可改；亲喂和睡眠会打开计时页。记错了，在顶部提示条点「撤销」，或在下面的时间线里改。", "Tap a sticker to log bottles, diapers, and more—times can be adjusted. Nursing and sleep open a timer. Made a mistake? Tap \"Undo\" on the banner or edit it in the timeline below.")) }
    var image: Image? { Image(systemName: "hand.point.up.left") }
}

/// The feeding page, before it starts.
struct SideTip: Tip {
    var title: Text { Text(L10n.t("点一侧开始", "Tap a side to start")) }
    var message: Text? { Text(L10n.t("计时中再点同一侧是暂停，点另一侧是换边。开始时间可以选「5 分钟前」等，补上已经开始的一段。", "Tap the active side again to pause, or tap the other side to switch. You can also pick \"5 min ago\" (or earlier) if you already started.")) }
    var image: Image? { Image(systemName: "timer") }
}

/// The tips on paper: the app's own card, text in the app's ink at full Dynamic Type, and a 44-point close button,
/// rather than the system popover's translucent material (which the accessibility audit flags for contrast).
struct PaperTipStyle: TipViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // the icon, the title and the close button share the top line; the message and actions take the full width
            HStack(alignment: .top, spacing: 8) {
                configuration.image?.font(.title3).foregroundStyle(Palette.accent).accessibilityHidden(true)
                configuration.title?.font(.headline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button { configuration.tip.invalidate(reason: .tipClosed) } label: {
                    Image(systemName: "xmark").font(.footnote.weight(.bold)).foregroundStyle(Palette.secondaryText)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .padding(.top, -10).padding(.trailing, -10)
                .accessibilityLabel(L10n.t("关闭提示", "Dismiss tip"))
            }
            configuration.message?.font(.subheadline).foregroundStyle(Palette.secondaryText).fixedSize(horizontal: false, vertical: true)
            ForEach(configuration.actions) { action in
                Button(action: action.handler) { action.label().font(.subheadline.weight(.semibold)) }
                    .frame(minHeight: 44)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}
