# 摸索台灯（Moss & Otto）v1.3.2 App Store 提审指南与双语资料包

核对日期：2026-11-21。适用于 App Store Connect（以下简称 ASC）中的 **iOS 1.3.2** 正式版本（Bundle ID：`app.mossling`，Apple ID：`6825856138`）。

---

## 一、提交前清点清单

应用与 CI 已完全具备提审条件：
- 版本号：`1.3.2`（合入 `main` 后由 CI 自动递增 Build 号并推送 TestFlight，自动写入中英双语测试说明）。
- 隐私清单（`PrivacyInfo.xcprivacy`）与 `Info.plist` 权限说明（`UIBackgroundModes: audio`、`NSMotionUsageDescription`、`NSPhotoLibraryUsageDescription`）完整合规；零网络请求、零第三方 SDK、零追踪。
- **8 张中文 + 8 张英文 6.9 英寸原尺寸商店截图（`1320×2868`）** 每次 CI 自动生成：
  `GitHub › Actions › 最近一次 iOS 运行 › Artifacts › appstore-screenshots`（包含 `ios_store_1_home.png` … `ios_store_8_journal.png` 与 `ios_store_en_1_home.png` … `ios_store_en_8_journal.png`）。

负责人提审前仅需核对以下 4 项 ASC 后台配置：

| # | 待完成项 | 是否阻断提交 | 说明 |
|---|---|---|---|
| 1 | 隐私政策网址 & 技术支持网址 | 是（ASC 必填） | 公开可访问页面，全文与 `ios/Docs/PRIVACY.md` 一致（见第六部分） |
| 2 | 上传 6.9 英寸截图（8 张中文 / 8 张英文） | 是（ASC 必填） | 直接下载 CI 产物 `appstore-screenshots` 按编号 1–8 上传 |
| 3 | 审核联系人电话 & 协议/税务/银行账户 | 是（付费应用必填） | 确认《付费应用协议》、W-8BEN 税务表与收款银行已生效 |
| 4 | 中国大陆 App 备案豁免 | 中国大陆区上架前需完成 | 纯离线无联网单机应用无需 ICP 备案，按第五部分向 Apple 提交豁免声明 |

---

## 二、App 信息（App Information）

| 字段 | 简体中文（主语言） | English (U.S.) |
|---|---|---|
| **名称**（≤30 字符） | `摸索台灯` | `Moss & Otto` |
| **副标题**（≤30 字符） | `0–3岁亲子共玩、夜灯与成长记录`（16 字） | `Calm Baby Play, Lamp & Log`（26 chars） |
| **主要类别** | 教育（Education） | Education |
| **次要类别** | 生活（Lifestyle） | Lifestyle |
| **内容版权** | 否，不显示或访问第三方版权内容（全部指南自行梳理并注明公开权威来源，插画与音频均为原创/实时合成） | No |
| **App 隐私** | **不收集任何数据**（Data Not Collected） | Data Not Collected |

> **切勿选择「医疗（Medical）」类别**：选医疗会触发审核指南 1.4.1 从严审查及 5.1.1(ix) 机构资质要求。本应用定位为「面向父母与照护者的家庭养育陪伴与日常记录工具」。

### 年龄分级问卷（Age Rating）
- 家长控制 / 年龄验证：无
- 不受限制的网页访问 / UGC / 聊天 / 广告：否
- 暴力、恐怖、色情、粗俗语言、赌博、酒精烟草：无
- **医疗或治疗信息**：不频繁/轻度（含就医提示与儿保接种日程，明确提示遵医嘱）
- **健康或保健话题**：是（WHO 生长曲线、辅食与日常照护）
- 面向人群：面向 **0–3 岁婴幼儿的父母与照护者**（不勾选「儿童专用 / Made for Kids」）。

### 价格与销售范围（Pricing & Availability）
- **定价**：一次性买断付费下载，建议基准价 **¥68（中国区） / $9.99（美区）**，无订阅、无内购、无广告。
- **销售范围**：
  - 优先勾选：美国、英国、加拿大、澳大利亚、新西兰、新加坡、马来西亚、中国香港、中国澳门、中国台湾、日本、韩国等非欧盟地区；
  - **欧盟 / 欧洲经济区（EU/EEA）**：如不希望在商店页公开个人地址与电话（欧盟 DSA 交易者规则），取消勾选欧盟 27 国及挪威、冰岛、列支敦士登；
  - **中国大陆**：提交第五部分「纯离线应用免 ICP 备案豁免」获 Apple 确认后勾选上架。

---

## 三、App Store 版本页元数据（可直接复制粘贴）

### 1. 简体中文（zh-Hans）

**推广文本（Promotional Text，≤170 字，可随时更新无需重审）**
```text
孩子摸索，大人点灯。给 0–3 岁家庭的纯离线陪伴工具：每日蒙氏共玩、床头暖光夜灯与 4–6 呼吸光环、双层助眠声景、感官玩具盒、百味食盒、24 小时节律盘、成长绘本、时光胶囊与可视化家庭交接卡——零账号、零联网、零广告。
```

**版本更新说明（What's New in 1.3.2）**
```text
v1.3.2 带来面向 0–3 岁家庭的全新打磨，全部离线无打扰：

• 全新「百味食盒」：60 种全食物蒙氏味觉图鉴，标记常见致敏食材，六色寻味花环与三档温和反应，一键同步辅食日志并导出 3× 百味护照。
• 感官玩具盒新增「萤火流光瓶」：与木琴七音、26 颗金珠雨棒、8 张新生儿黑白视卡组成四套蒙氏共玩小器具，指尖轻触牵引萤火伴五声音阶风铃轻响。
• 床头夜灯升级「4–6 慢呼吸光环」与「双层声景混音」：4 秒吸气 / 6 秒呼气暖光陪伴深夜安抚，四种实时合成助眠声景支持「+」叠层混音与锁屏后台播放。
• 可视化「家庭交接卡」：记录页一键生成 3× 棉纸交接卡图片或复制纯文字，轻松交接给伴侣、长辈或阿姨。
• 首页 2×3「陪伴小器具」坞、火漆封存的时光胶囊信笺、24 小时昼夜节律盘、翻页成长绘本与完整中英双语。
```

**描述（Description）**
```text
摸索台灯（Moss & Otto）是一款献给 0–3 岁宝宝父母的安静陪伴应用。孩子摸索，大人点灯——没有打卡分数、没有焦虑预测、没有广告与云端账号，只把温和的指引与趁手的小器具留在你的手机里。

【首页 2×3 陪伴小器具，离线随时点亮】
• Otto 床头夜灯与双层助眠声景：全屏无眩光深夜暖灯，上下滑动带机械顿挫手感无级调光，倾斜手机暖光微晃；内置「4–6 慢呼吸光环」陪伴大人深夜平复情绪；四种实时离线合成声景（雨落纸窗、草坡微风、温暖心跳、木琴摇篮）支持「+」双层叠音混音、15/30/60 分钟余弦渐弱定时与锁屏后台播放，暗光下可一键记睡眠或亲喂。
• 感官玩具盒（亲子共玩）：四套零广告蒙氏共玩器具——实时玫瑰木泛音「木琴七音」（支持连滑与摇篮曲）；26 颗金珠彩木珠随手机倾角滚落的「金珠雨棒」；18 只暖金薄荷萤火随指尖环绕伴风铃轻响的「萤火流光瓶」；以及 8 张 0–4 月新生儿高对比「黑白视卡」。
• 百味食盒（60 种初尝味觉图鉴）：涵盖蔬果、谷物、蛋白、奶豆、坚果籽类与温和风味六大类，清晰标注常见致敏食材，用「很喜欢 / 尝过啦 / 下次再试」零评判记录每一口探索，顶部六色寻味花环自动点亮，支持一键记入今日辅食与 3× 百味护照印画分享。
• 24 小时昼夜节律盘：以 7 天 / 14 天同心极坐标圆盘呈现真实睡眠、喂奶与玩耍节律，手指轻滑指针逐小时回看事实，一键导出 3× 典藏印画。
• 翻页成长绘本与本机拍立得：把每个月玩过的活动、写下的「第一次」与仅存本机的拍立得照片，自动装订成可横向翻页的棉纸成长绘本。
• 时光胶囊信笺：深夜灯下给宝宝写一封信，盖上暖金、苔绿或柔粉浮雕火漆，约定在 1 岁、2 岁、3 岁或 5 岁生日拆封重读。

【0–36 个月每日共玩与权威月龄指南】
• 37 站月龄指南（0–36 个月）、46 个家庭亲子活动与 146 幅手作 3D 软胶分步插画，首页每天推荐一个适龄活动，一步步跟着玩，不合适随时「换一个」。
• 涵盖六大发展领域、接种与儿保参考日程（注明公开权威机构来源）、照护安全提示与全文搜索。

【趁手的照护记录与可视化家庭交接卡（可选）】
• 喂奶、瓶喂、睡眠、尿布、辅食、洗澡、体温、用药与小记，支持亲喂换边/暂停、锁屏实时活动、灵动岛与桌面交互小组件。
• 可视化「家庭交接卡」：一键生成棉纸交接卡图片或纯文字，清晰汇总进行中计时、上次喂奶/醒来/尿布与交接备注，零云端即可顺畅交接给家人。
• 内置 WHO 0–36 个月儿童生长标准曲线（体重、身长、头围百分位）。

【隐私与边界】
• 纯离线设计：不需要账号，不发起网络请求，不含广告、数据统计或任何第三方 SDK；全部数据与照片仅保存在你的 iPhone 上，随时支持完整导出或一键清除。
• 本应用为家庭日常养育陪伴参考，不构成医疗诊断或治疗建议；如宝宝身体不适，请及时咨询儿科医生。
```

**关键词（Keywords，≤100 字符，英文逗号分隔）**
```text
早教,育儿,月龄,亲子游戏,蒙氏,白噪音,助眠,床头灯,喂奶记录,睡眠记录,辅食,百味,尿布,生长曲线,疫苗,绘本,宝宝日记,时光胶囊,交接
```
*(共 82 字符，精准覆盖早教/蒙氏/助眠白噪音/喂奶睡眠/辅食/成长绘本/家庭交接高搜索词，零重复名称与副标题)*

---

### 2. English (U.S.)

**App Name (≤30 chars)**
```text
Moss & Otto
```

**Subtitle (≤30 chars)**
```text
Calm Baby Play, Lamp & Log
```

**Promotional Text (≤170 chars)**
```text
They explore. You hold the light. An offline 0–3 companion with Montessori play, a dimming bedside lamp, dual soundscapes, sensory toybox, 60 first foods & care log.
```
*(166 chars)*

**What's New in 1.3.2**
```text
A quiet flagship update for Moss & Otto—100% offline, with zero ads or accounts:

• New First Foods Tasting Box: Track 60 whole foods across 6 Montessori categories with common-allergen badges, gentle zero-judgment reactions, a 6-color botanical wreath, and 3× Passport poster export.
• Firefly Lantern Jar in Sensory Toybox: Join our Rosewood Xylophone, 26-bead tilt Rainstick, and Newborn High-Contrast Cards with 18 glowing fireflies that orbit your touch to soft pentatonic chimes.
• Bedside Lamp 4–6 Breathing Halo & Dual Soundscapes: A golden 4s-in / 6s-out breathing halo for late-night soothing, plus lock-free dual-layer soundscape mixing (e.g., Paper Rain + Wood Lullaby) with background playback.
• Visual Care Handover Studio: Share a crisp 3× cotton-paper handover card or copy plain text for partners, grandparents, or nannies—no cloud needed.
• Balanced 2×3 Quiet Instruments Home Dock, wax-sealed Time Capsule Letters, 24h Rhythm Dial, and page-turning Growth Storybook.
```

**Description**
```text
Moss & Otto is a quiet, screen-calm companion for parents of 0–3 year olds. They explore; you hold the light—with zero streak scores, zero anxious predictions, zero ads, and zero accounts. Everything lives privately on your iPhone.

SIX QUIET INSTRUMENTS ON YOUR HOME SCREEN (100% OFFLINE)
• Otto's Bedside Lamp & Dual Soundscapes: A full-screen zero-glare midnight lantern with tactile brass-detent dimming and gentle pendulum tilt. Toggle the golden 4–6 calm breathing halo for late-night soothing, and blend any two real-time synthesized soundscapes (Paper Rain, Meadow Breeze, Soft Heartbeat, Wood Lullaby) with cosine auto-fade and Lock Screen background playback.
• Sensory Toybox (Parent-Child Co-Play): Four handcrafted zero-asset Montessori studios—an 8-bar Rosewood Xylophone with glissando & lullaby mode, a 26-bead Golden Rainstick driven by gentle tilt or touch, a Firefly Lantern Jar with 18 glowing fireflies and pentatonic wind chimes, and 8 newborn (0–4 mo) High-Contrast Visual Cards.
• First Foods Tasting Box: Explore 60 curated whole foods across 6 botanical categories with common-allergen markers, warm zero-judgment stamps (Loved / Tasted / Try Again), a 6-color tasting wreath, optional Care Journal sync, and 3× Passport poster sharing.
• 24-Hour Circadian Rhythm Dial: See 7 or 14 days of real sleep, feeding, and play patterns on one concentric clock face, scrub hour-by-hour, and export 3× keepsake prints.
• Page-Turning Growth Storybook: Monthly chapters, milestones, and on-device Polaroid "Firsts" photos bound automatically into a cotton-paper keepsake book.
• Time Capsule Letters: Seal a midnight letter with an embossed wax stamp to unseal on your child's 1st, 2nd, 3rd, or 5th birthday.

DAILY MONTESSORI PLAY & 0–36 MONTH GUIDE
• 37 monthly stations (0–36 months), 46 home co-play activities, and 146 handcrafted 3D soft-vinyl step illustrations. Open Today for one age-matched activity and swap anytime.
• Clear developmental areas, practical care & safety notes with cited public sources, and instant offline search.

OPTIONAL CARE JOURNAL & VISUAL CARE HANDOVER
• Track nursing (with pause & side switch), bottles, sleep, diapers, solids, baths, temperature, medicine, and notes—complete with Live Activities, Dynamic Island, interactive widgets, and WHO 0–36 mo growth percentile curves.
• Passing the Lantern (Visual Care Handover): Export a clean 3× cotton-paper handover card image or copy plain text with active timers, last feed/wake/diaper, and custom notes for your partner, grandparents, or nanny.

PRIVATE BY DESIGN
• No accounts, no internet requests, no tracking, no ads, and no third-party SDKs. Export full backups or erase all local data anytime.
• Moss & Otto is a parenting reference and daily log—not medical advice. Always consult your pediatrician for health concerns.
```

**Keywords (≤100 chars, comma-separated, no spaces)**
```text
baby,tracker,montessori,feeding,sleep,white,noise,nightlight,solids,first,foods,milestone,diary,log
```
*(99 chars)*

**Copyright & Support**
- **Copyright**：`© 2026 摸索台灯` / `© 2026 Moss & Otto`
- **Support URL / Privacy Policy URL**：填入托管后的公开网址（见第六部分）
- **Version**：`1.3.2`

---

## 四、6.9 英寸 App Store 商店截图顺序与配文（`1320×2868`）

CI 产物 `appstore-screenshots` 已按 1–8 编号自动输出原尺寸无压缩 PNG（中文 8 张 + 英文 8 张），可直接上传至 ASC 的 **iPhone 6.9" Display**（ASC 会自动适配 6.7"/6.5" 槽位）：

| 序号 | 中文文件 / 英文文件 | 展示页面 | 中文建议副标（可选装框） | English Caption (Optional Frame) |
|---|---|---|---|---|
| 1 | `ios_store_1_home.png` / `ios_store_en_1_home.png` | 本月首页 + 2×3 陪伴小器具坞 | 孩子摸索，大人点灯 · 六大离线小器具一键点亮 | They explore. You hold the light. |
| 2 | `ios_store_2_lamp.png` / `ios_store_en_2_lamp.png` | Otto 床头夜灯 · 4–6 呼吸光环 + 双层混音 | 凌晨三点的温柔陪伴 · 调光夜灯、呼吸光环与双层声景 | Midnight lantern, 4–6 breath & dual soundscapes |
| 3 | `ios_store_3_toybox.png` / `ios_store_en_3_toybox.png` | 感官玩具盒（木琴 / 金珠 / 萤火 / 视卡） | 零广告亲子共玩 · 木琴、金珠雨棒、萤火瓶与黑白视卡 | Handcrafted offline Montessori co-play toybox |
| 4 | `ios_store_4_foods.png` / `ios_store_en_4_foods.png` | 百味食盒 · 6 色花环 + 60 种辅食图鉴 | 初尝人间百味 · 60 种全食物图鉴与致敏观察 | 60 first foods & gentle tasting passport |
| 5 | `ios_store_5_rhythm.png` / `ios_store_en_5_rhythm.png` | 24 小时昼夜节律盘 | 一眼读懂宝宝昼夜节律 · 不预测不焦虑，只呈现实录 | 24-hour circadian rhythm dial, zero anxiety |
| 6 | `ios_store_6_storybook.png` / `ios_store_en_6_storybook.png` | 翻页成长绘本 + 本机拍立得 | 把每个月的「第一次」装订成一本棉纸绘本 | Page-turning keepsake storybook & Polaroid firsts |
| 7 | `ios_store_7_capsules.png` / `ios_store_en_7_capsules.png` | 时光胶囊信笺（火漆封存） | 盖上一枚火漆，把今晚写给一岁、三岁的宝宝 | Wax-sealed letters for future birthdays |
| 8 | `ios_store_8_journal.png` / `ios_store_en_8_journal.png` | 贴纸照护记录 + 串珠时间轴 + 交接卡 | 一点即记、锁屏计时，还能一键生成家庭交接卡 | One-tap care journal & visual family handover |

> 审核合规提示：截图文案避免出现「儿童专用 / Made for Kids」或「预防 / 治疗 / 医疗诊断」等字眼（审核指南 2.3.8、5.1.4、1.4.1）。

---

## 五、App 审核备注（App Review Notes，直接粘贴）

- **Sign-in Required**：取消勾选（无需任何登录账号）
- **Contact**：App Store Connect 账号主体 / `lbuiuiysdeyzxl@yeah.net` / 负责人手机号（含国家区号）
- **Review Notes（中英双语，直接整段粘贴，便于北美/爱尔兰/上海审核团队秒懂）**：

```text
Thank you for reviewing Moss & Otto (摸索台灯) v1.3.2!

1. Audience & Offline Privacy
- Designed for parents and caregivers of children aged 0–3 (NOT directed to children under Kids Category).
- 100% offline: zero user accounts, zero network requests, zero analytics, zero ads, and zero third-party SDKs. All care logs, First Foods records, Time Capsule letters, and Polaroid Firsts photos remain strictly on-device and can be exported or erased anytime under Me > Data.
- First launch presents an explicit guardian privacy consent sheet. Declining still allows full browsing of all 0–36 month guides, activities, Bedside Lamp, and Sensory Toybox without storing any child data.

2. Declared Capabilities & Permissions (How to Test)
- Background Audio (UIBackgroundModes: audio): Used exclusively for Otto's Bedside Lamp real-time synthesized soothing soundscapes (Home > Bedside Lamp > tap Paper Rain / Wood Lullaby, optionally tap "+" to blend a second layer, and lock the device—gentle sound continues smoothly until the cosine auto-fade timer ends).
- CoreMotion (NSMotionUsageDescription): Used strictly on-device for the subtle pendulum lamp glow in Bedside Lamp and the 26-bead gravity physics in Home > Sensory Toybox > Beads (Montessori Rainstick). No motion data is recorded or transmitted.
- Photo Library (NSPhotoLibraryUsageDescription): Used via PHPicker when a parent optionally attaches a local Polaroid keepsake photo to a "First" milestone (Journal > "+" > Log a first) or saves a keepsake poster.
- Live Activities & Widgets: Optional feeding/sleep timers appear on Lock Screen and Dynamic Island, synced locally via App Group container.

3. Health & Parenting Disclaimer
- Growth curves display standard WHO 0–36 month percentiles only (no diagnosis). Vaccination/checkup schedules and First Foods allergen badges cite public sources (Me > About > Sources) and advise consulting a pediatrician.

4. Easter Eggs (For Reviewer Awareness)
- Me > About Moss & Otto: Tapping Moss & Otto 3 times opens the origin story ("The Story of Moss & Otto").
- Inside that story page, tapping the illustration 10 times toggles the classic 2D picture-book illustration style (press-and-hold/drag ~3s to return to 3D vinyl style). Neither affects any core feature or business model.
```

---

## 六、中国大陆纯离线 App 免 ICP 备案豁免说明

本应用无服务器、不发起任何网络请求，依据工信部《互联网信息服务管理办法》属于**单机离线客户端软件**，无需办理 ICP App 备案，只需在勾选中国大陆店面前向 Apple 申请备案豁免（通常 1–2 个工作日回复）：

1. 打开 [developer.apple.com/cn/contact](https://developer.apple.com/cn/contact/) → 选择「App Store 分发」→「中国大陆 App 备案」或「有关分发的其它疑问」。
2. 填写 App 名称 `摸索台灯`、Bundle ID `app.mossling`、Apple ID `6825856138`。
3. 豁免说明正文（直接复制）：

```text
您好，

我申请为 iOS 应用「摸索台灯」（Bundle ID: app.mossling，Apple ID: 6825856138）办理中国大陆 App Store 备案豁免。

本应用为 100% 纯离线单机客户端软件：
1. 应用运行全程不发起任何网络请求，不连接任何自有或第三方服务器，不包含用户注册/登录、云同步、在线社区、广告或任何第三方网络 SDK；
2. 全部内容（育儿指南、插画、本地实时合成音频与日常记录）均封装或保存在用户本机设备中，不向公众提供互联网信息服务；
3. 本应用的付费下载交易仅通过 Apple App Store 完成，应用本身不含网络支付或联网接口。

依据《互联网信息服务管理办法》及相关规定，本应用无需办理工信部 ICP App 备案。特此说明并申请豁免，感谢协助！
```

---

## 七、隐私政策与技术支持页托管建议

ASC 要求「隐私政策网址」与「技术支持网址」为公开可访问的 HTTPS 链接，内容与仓库内 `ios/Docs/PRIVACY.md`（中文）及英文隐私说明保持一致：
- **最快捷方式（免域名免备案、国内直连稳定）**：使用飞书文档 / 腾讯文档新建公开只读页，或开启本 GitHub 仓库的 GitHub Pages（将 `PRIVACY.md` 与支持邮箱 `lbuiuiysdeyzxl@yeah.net` 发布为静态页）。

---

## 八、Apple Editorial 编辑推荐自荐信（App Store Feature Nomination）

可在 ASC「App Store 推广与推荐提名（Featuring Nominations）」页面提交（建议上线前 2–3 周提交）：

```text
Title: Moss & Otto (摸索台灯) — A Zero-Anxiety, 100% Offline Montessori Craft Companion for 0–3 Families

Why Moss & Otto stands out:
Most parenting apps overwhelm sleep-deprived new parents with cloud accounts, subscriptions, guilt-inducing streaks, and noisy AI feeds. Moss & Otto takes the opposite path: "They explore. You hold the light."

Built exclusively for iOS with native SwiftUI, Canvas, CoreHaptics, AVAudioEngine DSP, Live Activities, and Interactive Widgets, Moss & Otto pairs 146 bespoke 3D soft-vinyl Montessori illustrations with six quiet, handcrafted offline instruments right on Screen 1:
1. Otto's Bedside Lamp — a zero-glare midnight sanctuary with tactile brass-detent dimming, a golden 4–6 calm breathing halo, and lock-free dual-layer real-time synthesized soundscapes (zero bundled audio files).
2. Sensory Toybox — four ad-free parent-child co-play studios (8-bar rosewood marimba xylophone, 26-bead tilt Montessori rainstick, 18-firefly pentatonic lantern jar, and 8 newborn high-contrast visual cards).
3. First Foods Tasting Box — 60 curated whole foods with a 6-color botanical wreath, allergen reminders, zero-judgment stamps, and 3× Passport print export.
4. 24-Hour Circadian Rhythm Dial — 7/14-day concentric polar clock showing honest sleep & feed patterns with zero anxious predictions.
5. Page-Turning Growth Storybook — automatically binds milestones and on-device Polaroid "Firsts" photos into a cotton-paper keepsake book.
6. Time Capsule Letters — embossed wax-sealed letters scheduled for a baby's 1st, 2nd, 3rd, or 5th birthday, plus a visual Care Handover studio for sharing shifts with family—completely offline.

Zero accounts. Zero network calls. Zero tracking. One-time purchase. Bilingual in Simplified Chinese and English, crafted with deep respect for quiet family moments.
```
