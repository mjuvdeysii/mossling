# 摸索台灯 Moss & Otto

<p align="center"><img src="docs/images/ios/1_opening.jpg" width="300" alt="摸索台灯：Otto 的灯亮起，Moss 在灯下摸索"></p>

<p align="center"><b>孩子摸索，大人点灯。</b><br>陪 0–3 岁的孩子一起玩、一起长大，把每一天记下来。<br>免费 · 无广告 · 不需要账号 · 记录只保存在手机里</p>

<p align="center"><a href="#ios-版">iOS 版</a> · <a href="#安卓版">安卓版</a> · <a href="docs/IP.md">品牌与 IP</a> · <a href="PRIVACY.md">隐私政策</a> · <a href="TERMS.md">使用条款</a> · <a href="DISCLAIMER.md">免责声明</a></p>

## 这是什么

摸索台灯不是育儿课。它不教大人怎么养孩子，也不给孩子打分，只陪大人和孩子一起玩、一起长大，并把长大的样子记下来。

| 名字 | 属于谁 | 含义 |
|---|---|---|
| 摸索 | 孩子 | 0–3 岁的孩子用手、用嘴、用眼睛摸索世界。Moss 的名字取自「摸索」，头上的新芽一直在长。 |
| 台灯 | 大人 | 台灯不替人走路，只把桌面照亮。Otto 头顶的金色灯珠就是这盏灯。 |

在这里做三件事：

| | 在哪里 | 不做什么 |
|---|---|---|
| **一起玩** | 本周的架子：这一周可以摸索的几件教具，点开就是一步步的插画、准备什么、什么时候停下 | 不布置任务，不设打卡 |
| **看他长大** | 0–36 个月，一个月一站，共 37 站；成长滚轮、成长册、WHO 生长曲线 | 不比较，不做发育诊断 |
| **记下来**（可选） | 亲喂、瓶喂、睡眠、尿布一点即记，计时显示在锁屏上；亲喂时长、瓶喂奶量、睡眠的统计 | 不上传，不需要账号 |

满 36 个月是最后一站，却不是终点：**故事仍在继续。**

## Moss 与 Otto

两位伙伴不说话，只用眼神和动作陪伴。Moss（摸索）是孩子的好奇心：苔绿色，两只眼睛，头顶薄荷芽，什么都想先摸一下。Otto（台灯）是大人的陪伴：深蓝色，一只大眼睛，头顶一颗金色灯珠，专注又耐心，Moss 摸到哪里，他就把灯往哪里偏一点。家长可以选任意一位作为主伙伴，两位功能完全相同。完整设定见 [docs/IP.md](docs/IP.md)。

---

## iOS 版

为 iPhone 原生构建（SwiftUI，iOS 26 及以上，液态玻璃设计语言），目前在 TestFlight 测试，公开测试与 App Store 上架准备中。

<p align="center">
  <img src="docs/images/ios/1_opening.jpg" width="31%" alt="首次打开：灯亮起，Moss 在灯下摸索">
  <img src="docs/images/ios/2_home.jpg" width="31%" alt="本月：月龄与本周的架子">
  <img src="docs/images/ios/3_play.jpg" width="31%" alt="活动：一步步的插画，Moss 与 Otto 在旁边看">
</p>
<p align="center">
  <img src="docs/images/ios/4_story.jpg" width="31%" alt="摸索台灯的故事">
  <img src="docs/images/ios/5_journal.jpg" width="31%" alt="记录：一天的串珠与时间线">
  <img src="docs/images/ios/6_night.jpg" width="31%" alt="夜灯：夜里喂奶的计时">
</p>

| 截图 | 说明 |
|---|---|
| 首次打开 | 没有文字的开场：Otto 的灯亮起，Moss 在灯下醒来，摸了摸套圈，转头看 Otto。约四秒，只播一次，随时可跳过；开启「减弱动态效果」时静止 |
| 本月 | 孩子满几个月几天；**本周的架子**是首页的核心：木头矮柜上的托盘、纸签上的名字，每玩一次多一颗金珠；之后是这个月的其他活动、这个月的要点与专题 |
| 活动 | 开始之前（准备与安全）、一步步的插画、做的时候看什么、什么时候停下；Moss 与 Otto 在每一幅插画里陪着看，做完最后一步时一起笑 |
| 故事 | 「关于摸索台灯」里讲述名字的含义、能做的三件事，以及 36 个月以后故事仍在继续 |
| 记录（可选） | 一点即记，时间可精确选择；亲喂左右侧分别计时，可暂停、换边；瓶喂精确到 5 毫升；锁屏实时活动与灵动岛、桌面小组件 |
| 夜灯 | 晚上自动变成一盏小夜灯：深蓝底、琥珀色光，Otto 的灯珠微亮 |

**隐私**：不联网、不需要账号，不含广告、统计或第三方 SDK。CI 在模拟器测试中记录应用进程的网络活动（`ios_network.txt`），用来核查这一点。

**开发**：`ios/project.yml`（XcodeGen）；CI `.github/workflows/ios.yml` 运行单元测试、截图测试与无障碍审查，截图发布到 `screens-ios` 分支，并上传 TestFlight。设计说明见 [ios/DESIGN.md](ios/DESIGN.md)，路线图见 [ios/ROADMAP.md](ios/ROADMAP.md)。

---

## 安卓版

适用于 Android 8.0 及以上。[下载最新版本](https://github.com/mjuvdeysii/mossling/releases/latest)。

<p align="center">
  <img src="docs/images/android/1_welcome.jpg" width="31%" alt="欢迎页">
  <img src="docs/images/android/2_shelf.jpg" width="31%" alt="本周的架子">
  <img src="docs/images/android/3_materials.jpg" width="31%" alt="教具">
</p>
<p align="center">
  <img src="docs/images/android/4_journal.jpg" width="31%" alt="手帐">
  <img src="docs/images/android/5_stats.jpg" width="31%" alt="统计">
  <img src="docs/images/android/6_growth.jpg" width="31%" alt="生长曲线">
</p>

| 截图 | 说明 |
|---|---|
| 欢迎页 | 孩子摸索，大人点灯；填写出生日期，或先看看 |
| 本周的架子 | 这一周放上架子的几件教具，以及怎么用这个架子 |
| 教具 | 蒙台梭利式的家庭教具，按月龄出现 |
| 手帐（可选） | 亲喂、瓶喂（精确到 5 毫升）、睡眠、尿布等；通知栏计时，可暂停、换边；桌面小组件 |
| 统计 | 喂养次数、亲喂时长、睡眠与尿布 |
| 生长曲线 | 世界卫生组织儿童生长标准（2006），百分位带与中位数 |

此外还有「今天」（月龄、今天的一个活动）、「成长」（0–36 个月串珠、每月要点、成长地图、专题与搜索）和 46 个家庭活动、146 幅分步插画。

**隐私**：不需要账号，不收集、不上传任何数据；只在用户主动点「检查更新」时联网。

**开发**：`gradle :app:assembleDebug`（Gradle 8.9、JDK 17、Android SDK 35）。CI `build.yml` 运行单元测试与 Paparazzi 截图（`screens` 分支），`VERSION` 中的版本尚未发布时构建签名 APK 并发布；`emulator.yml` 在模拟器上运行关键路径测试。签名密钥来自 GitHub Secrets，不在仓库中。

---

## 内容依据

育儿内容整理自世界卫生组织、联合国儿童基金会、国家卫生健康委员会、国家疾病预防控制局、中华预防医学会、美国疾病控制与预防中心、美国儿科学会等机构公开发布的指南与资料，在应用内「内容来源」中逐项标明机构、文件名称、发布日期与核对日期。`app/src/main/assets/content.json` 为两个平台共用的内容；`who_growth.json` 由 `tools/export_who.py` 生成；iOS 插画由 `tools/picturebook.py` 生成，安卓插画由 `tools/illustrate.py` 生成。

## 制作

摸索台灯由创作者本人构思与主导，借助 AI（Anthropic 的 Claude）辅助完成产品设计、插画与代码。

## 说明

本应用陪伴家庭养育，内容仅供参考，不构成医疗诊断或治疗建议。详见《[使用条款](TERMS.md)》《[隐私政策](PRIVACY.md)》《[免责声明](DISCLAIMER.md)》。
