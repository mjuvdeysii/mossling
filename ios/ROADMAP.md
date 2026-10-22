# 芽芽月历 iOS 版 · 重构路线图

目标：一个原汁原味的 iOS 应用，而不是安卓版的搬运。内容与安卓版一致（content.json、WHO 数据、条款），其余按 Apple Human Interface Guidelines 与最新 iOS 设计语言（液态玻璃 / Liquid Glass）重新构思：界面、配色、字体、插画、Moss 与 Otto、应用图标。

## 原则
- 以 developer.apple.com 的 Human Interface Guidelines、Liquid Glass 设计与示例代码为准；采用系统控件、系统材质（glassEffect、GlassEffectContainer）、SF Symbols、系统字体与动态字体。
- 不再沿用安卓版的 Material 风格、Young Serif / Noto Serif 字体与 Material 形状。
- 蒙台梭利教具的形象（串珠、数棒、圆柱插座、粉红塔、摇铃等）用 SF Symbols 式的线面图形与液态玻璃材质表达，参考 Apple 官方图标与示例中模拟实物的做法。
- 不出现需要横向滑动才能看全的内容；放不下就换行，先判断是否需要展示。
- 正式、第三人称；说明性文字只留给早教内容本身。
- 喂奶不得用红色水滴（像血滴）。
- 安卓版不在本路线图内；需要同步的改动单独列出。

## 状态
- [x] 1. 可运行的第一版：全部页面、手帐、实时活动、小组件、生长曲线、记录文件（与安卓通用）、模拟器测试与截图（screens-ios 分支）。
- [x] 2. TestFlight 上传流水线（ASC API 密钥；App Group 在开发者账号设置好并设置仓库变量 APP_GROUP=1 之前不签入）。
- [ ] 3. 设计基础：配色（系统语义色 + 少量品牌色，深浅色与高对比度）、字体（SF Pro / 苹方 + 动态字体，数字用 SF Pro Rounded 或等宽数字）、间距与圆角按 HIG；液态玻璃材质的使用规则（导航层、浮动控件、卡片）。
- [ ] 4. 导航与结构：iOS 26+/27 TabView（含搜索标签与底部附件区）、可折叠标签栏、大标题、工具栏玻璃按钮；页面层级重新梳理。
- [ ] 5. Moss 与 Otto 重绘：液态玻璃质感（高光、折射、景深），保留薄荷叶彩蛋与互动动画；静态与动画版本；减弱动态效果时静止。
- [ ] 6. 插画重制：146 幅步骤图与 37 张封面，改为 iOS 风格（SF Symbols 质感的教具 + 玻璃材质 + 柔和景深），由 tools/ 下的脚本生成，iOS 单独一套资源。
- [ ] 7. 今天 / 成长 / 地图 / 活动页按新设计重做。
- [ ] 8. 手帐、计时卡片、实时活动与灵动岛、小组件按新设计重做；喂养图标与配色。
- [ ] 9. 应用图标：按 HIG 的分层图标（Icon Composer：前景层 + 背景，浅色 / 深色 / 着色 / 透明），Moss 与 Otto 为主体。
- [ ] 10. 辅助功能：旁白标签、动态字体到最大号、对比度、减弱动态效果、减弱透明度时的回退。
- [ ] 11. 打磨与 TestFlight 发布；商店素材（截图、文案）。

## 待用户处理
- 开发者账号中创建 App Group `group.app.mossling`，并在 App ID `app.mossling`、`app.mossling.widget` 上启用；完成后在仓库 Settings › Variables 添加 `APP_GROUP=1`，小组件即可读取手帐数据。

## 记录
- 2026-10-23：第一版上线 TestFlight 流水线；喂奶改为玫瑰色心形。
