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
    var title: Text { Text("今天一起玩") }
    var message: Text? { Text("点开跟着图一步步玩，做完最后一步会自动记一次。「换一个」在这周的几个活动里换；「调整」可以换这周的活动。点月份卡看这个月的全部内容。") }
    var image: Image? { Image(systemName: "hand.tap") }
}

/// 本月 · the records, which are off until turned on.
struct RecordsTip: Tip {
    var title: Text { Text("需要记录喂奶和睡眠？") }
    var message: Text? { Text("打开「记录」后，亲喂、瓶喂、睡眠、尿布都能一点即记，锁屏上也能看到计时。之后可在「我的」里关闭。") }
    var image: Image? { Image(systemName: "list.bullet.clipboard") }
    var actions: [Action] { [Action(id: "on", title: "打开记录")] }
    /// Only while the records are off.
    @Parameter static var recordsOff: Bool = true
    var rules: [Rule] { [#Rule(Self.$recordsOff) { $0 == true }] }
}

/// 记录 · the stickers.
struct StickerTip: Tip {
    var title: Text { Text("点一下就记") }
    var message: Text? { Text("瓶喂、尿布等点贴纸记下，时间可改；亲喂和睡眠会打开计时页。记错了，在顶部提示条点「撤销」，或在下面的时间线里改。") }
    var image: Image? { Image(systemName: "hand.point.up.left") }
}

/// The feeding page, before it starts.
struct SideTip: Tip {
    var title: Text { Text("点一侧开始") }
    var message: Text? { Text("计时中再点同一侧是暂停，点另一侧是换边。开始时间可以选「5 分钟前」等，补上已经开始的一段。") }
    var image: Image? { Image(systemName: "timer") }
}
