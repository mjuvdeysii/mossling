# 更新日志

## 2.0
面向 0–3 岁家庭的年度旗舰版本：首页「三层光晕」空间体验、Otto 金色灯珠下拉物理交互与水彩晕染切换 3D/2D、真绘本分步动态图解与完工金珠火漆纪念卡、全站 0 Emoji 植物学百味食盒、纵向「串珠旅程」、四工坊桌面感官玩具盒与护耳音量保护、StandBy 夜间信标、Siri 与控制中心捷径，全程纯离线、完整中英双语。

- **Batch 25（v2.0 正式发布候选 22 · Edition I Round 25 · 三大创意炼金术原生物理仪与界面润色：Otto 光影手影墙 / 无声掌心轻拍 / 划屏传灯交接仪式）**：
  - **【创意炼金术 I · 感官玩具盒第 5 独立工作室「Otto 光影手影墙」】**：在 `ToyboxMode` 新增 `.shadows` 工作室（`ShadowWallStudio.swift`），新增 Metal 着色器 `shadowWallAtmosphere` 渲染卧室墙壁暖金光锥与浮尘肌理；内置可单指拖动的五款纸艺剪影（垂耳兔 / 飞鸟 / 小狗 / 蝴蝶 / 帆船），遵循真实光学反距离平方投影模型 `ShadowWallPhysics`（越靠近 Otto 头部灯珠，投墙影子越大、半影虚化越柔），点触触发摆动并响起对应五声音阶八音盒和弦，地板端 `Moss` 视线实时追随墙上光影惊奇呼应，严格遵守 Otto 无手正典；同步更新首页 `TodayView` 玩具盒副标题入口。
  - **【创意炼金术 II · 床头夜灯「无声掌心轻拍安抚器 Silent Palm-Pat」】**：为 `TactileEngine` 新增严格零声音、低锐度柔弹 `palmPatPulse` 触觉波形；在 `BedsideLampView` 顶部与 4–6 呼吸并列上线「轻拍 / Pat」模式，支持 60 / 54 / 48 BPM 与「渐缓（5 分钟内由 60 温和降至 48 BPM）」及点击灯光即刻对齐父母拍打频率的 Tap-Tempo（`PalmPatRhythm`），中心夜灯晕环实时与拍打脉搏同频闪烁。
  - **【创意炼金术 III · `HandoverSheet` 划屏传灯交接仪式 & 紧凑版面】**：在 `HandoverSheet` 的 `PassingLanternArt` 上线沿二次贝塞尔拱桥单指推金珠交接交互（`LanternPassMath`）：每跨 25% 触发黄铜卡点触觉，地垫暖光池随金珠物理迁移，送达 `>= 0.88` 触发木琴金珠落定音并与佩戴珊瑚针织帽的 Mochi 眉眼弯弯致意；同步收紧交接卡内边距、添加 `.scrollBounceBehavior(.basedOnSize)` 并将「分享交接卡 / 复制文字」改为并排双操作条。补全 `testRound25CreativeAlchemyShadowWallPalmPatAndLanternPass` 与 `test75Round25CreativeAlchemyInstruments`。

- **Batch 24（v2.0 正式发布候选 21 · Edition I Round 24 · 全局首屏主义与工坊单屏驾驶舱 `YouView` · 严禁非必要下拉浏览）**：
  - **【工坊页 `YouView` 单屏驾驶舱重构】**：将工坊首页由原先 6 张纵排大卡与 9 行透明清单（约 `1,550pt`）彻底重铸为 **一屏直达的原生态 iOS 驾驶舱（`~536pt`，零非必要下拉）**：将宝宝信息与「摸索台灯的故事」三幕微剧院入口柔和合入顶卡，外观与语言合为双行紧凑胶囊卡，偏好开关升级为 **2×2 触感控制瓷砖**，「循证来源 / 离线备份 / 隐私保护 / 更新志」化为 **2×2 核心透明门户**，其余法律条款、免责、致谢、重播提示、反馈与可折叠设计工艺四柱收纳进自含 `NavigationStack` 的 `StudioLegalSheet`。
  - **【全站四大主屏首屏纪律 + `.scrollBounceBehavior(.basedOnSize)`】**：统一在 **摸索（`TodayView`）**、**台灯（`LampHubView`）**、**留念（`JourneyHubView`）**、**工坊（`YouView`）** 与 **剧场（`StoryView` / `PlayView`）** 启用 `.inline` 精炼顶栏与 `.scrollBounceBehavior(.basedOnSize)`；优化本周其余活动为 2 列精巧网格并紧致感官双卡；紧致夜灯主卡与随手轻记；「留念」页面移除重复章节条并将三片土地串珠列表默认折叠收起（轻点土地条或“回到现在”才原地展开），全面消除非必要纵滑网页感，并新增 `testRound24ViewportFirstStudioAndFourTabs` 与 `852pt` 单屏检验截图 `test74Round24ViewportFirstFourTabs`。

- **Batch 23（v2.0 正式发布候选 20 · Edition I Round 23 · 连续无级控帧活动绘本剧场 `PlayView` · Batch D 独立小动画 `A25–A32` [38 / 46]）**：
  - **【连续物理控帧绘本剧场 × 免连点交互重构 `PlayView`】**：为 `LivingBookStage` 与 `ActivityMotionStage` 新增支持零闪断同步定格的 `scrubPhase` 管线；全面升级 `PlayView` 与垫旁共玩 `MatSideCoPlayView`，以桦木凹槽连续木珠控帧轨 `StorybookSpineScrubber` 与纯数学模块 `PlayScrubMath` 取代纯离散点按进度条，指尖沿木轨连续滑动即可跨步骤并跨越每步 `0.48` 接触峰值触发细腻的核心触感反馈（`CoreHaptics`）；同时将强制多次连点的「下一步」按钮重铸为 **一键「连播全步 / 暂停连播」与随时一键「完成并盖印」**，并精简步骤大纲重复微缩舞台，显著降低滑屏冗余渲染开销。
  - **【Bespoke 独立活动动画 Batch D（`A25–A32` 共 8 部完全独立短片 · 累计 38 / 46）】**：严格恪守 `docs/IP.md`（Otto 永远无手、零腮红、零嘴点/气泡、`1:1` 地面坐标与真实物理接触阴影）手工创作 `A25`（落地木摇篮玩偶盖毯与喂食照护）、`A26`（圆凳暖光情绪灯与安全捏捏抱枕边界）、`A27`（双桦木分类盘形状与冷暖双重有意义归类）、`A28`（矮灶台煮汤与汤碗沿台面平滑送餐）、`A29`（三色稳固低矮踏步垫动态随行路线与护持光环）、`A30`（圆毯八分音符音乐盒与 `0.60` 突然木头人定格冻结）、`A31`（木挂杆三折叙事挂幅时间线索与儿童回应新芽）、`A32`（双人平行地垫与中景稳重引导的轮流木车回合），补全 `testRound23ContinuousPlayScrubberAndBatchDScenes` 与 `test73Round23PlayScrubberAndBatchDShowcases`。

- **Batch 22（v2.0 正式发布候选 19 · Edition I Round 22 · 零迷宫单一真源信息架构 · Tab Bar 与入口统一 · 30 部活动全动态光锥与 8 部空间穿模物理重铸）**：
  - **【零迷宫单一真源架构手术 Single-Source-of-Truth IA】**：新建 `AppRouter.swift` 以 4 组互不重叠的独立路由枚举（`ExploreRoute`、`LampRoute`、`KeepsakesRoute`、`StudioRoute`）与 `CanonicalDestination` 彻底取代全局混用 `Route`/`JournalRoute` 迷宫；`AboutView`、`MonthCard`、`QuietInstrumentsDock`、`NowCard`、`JournalView` 与重复的 `GrowthBookView` 全量退役下线，并将过往多日回看/补记并入 **台灯（`LampHubView`）**，将空生日引导入口并入唯一 **成长绘本（`StorybookView`）**，将「工坊」透明循证收口为单层清单与 Duo 彩蛋；同步仅在沉浸互动页面（`ToyboxView`、`PlayView`）隐藏底部 Tab Bar，普通子页一律保留标签栏退路。
  - **【30 部活动短片全动态光锥 × 8 部空间物理精修】**：升级 `BespokeActivitySceneRegistry` 为全部 30 部短片（`N01–N06`、`A01–A24`）注入精准的 Otto 金珠与教具目标坐标及 `lightAnchors(for:step:stageSize:)`（淘汰硬编码占位光锥）；针对 `A24`、`A20`、`N06`、`A16`、`A11`、`A13`、`A14`、`A19` 逐一重铸三平面纵深、落地接触阴影、无浮空蜡笔/抹布/羽毛笔/鸟架物理牵引、严格对调可触达站位并与 `content.json` 步骤字字严丝合缝，新增 `testRound22SingleSourceOfTruthIAAndScenePhysics` 与 `test72Round22ZeroMazeIAAndScenePhysicsRepair`，并同步将 5 轮彻底推翻重构框架固化为 `docs/METHODOLOGY.md` v3.1。

- **Batch 21（v2.0 正式发布候选 18 · Batch C 独立小动画 `A15–A24` · Tab 3 蒙氏纪念书架与折叠三境章节 · Swift 6 零警告与 Tab 3/4 无障碍精修）**：
  - **【Bespoke 独立活动动画 Batch C（`A15–A24` 共 10 部完全独立短片 · 累计 30 / 46）】**：严格遵循 `docs/IP.md`（Otto 永远无手、零腮红、零气泡、`1:1` Pixar 3D × Ghibli 2D 地面坐标对齐）手工编排 `A15`（绗缝游戏垫清障与木环自由探索）、`A16`（矮柜木鸟共同注意追视光弧）、`A17`（门拱下波浪天线与薄荷叶无手致意）、`A18`（六瓣布球滚动物理自转与回合拉长）、`A19`（正式升格的三层倒角木积木搭高与欢呼倒塌）、`A20`（实用生活矮桌擦水珠与棉布入篮）、`A21`（双桦木托盘二选一高亮询问）、`A22`（植物梨卡片与实木梨配对落点）、`A23`（前展书架选书翻页与随心合书）与 `A24`（棉纸胶带粗蜡笔自由有机笔触），注册至 `BespokeActivitySceneRegistry`（累计 30 部独立镜头语法），补全 `testRound21BespokeBatchCScenesAndKeepsakeTab` 与 `test71Round21BespokeBatchCAndKeepsakesUpgrade`。
  - **【创意炼金术升级 · Tab 3 蒙氏纪念藏品盒与三境折叠章节】**：将 `JourneyHubView` 四格入口升级为数据驱动的实体微缩质感藏品（`MiniStorybookArtifact` 布面书脊绘本、`MiniPolaroidArtifact` 胶带拍立得直显最近照片、`MiniCapsuleEnvelopeArtifact` 对应火漆色信封与待拆微光、`MiniGrowthCurveArtifact` WHO P15–P85 曲线配实时体重金珠折线）；在头卡下方新增「草地 / 森林小丘 / 小河村庄」三境进度跳转条，并将 37 站珠链按三境收纳进平滑 `CalmAccordion` 剪纸章节（默认仅展开宝宝当前王国，大幅压缩首屏滑屏长度）。
  - **【修复 Fix】**：彻底清零 `TimeCapsuleView.swift:18`、`Components.swift:86` / `Theme.swift:127` Swift 6 主线程隔离警告及 `LogicTests.swift:577` 未使用变量警告；修复 `JourneyHubView` 深色/平面未来珠子数字对比度与 AX2/AX3 `FlowRow` 折行，同步强化 `YouView` 语言胶囊与 `EditorialViews` 引用卡及隐私一图读懂在 AX2 下的自适应排版。

- **Batch 20（v2.0 正式发布候选 17 · Batch B 独立小动画 `A05–A14` · Tab 2 台灯活态呼吸光晕与 AX2 无障碍修复 · ADA 2027 方法论沉淀）**：
  - **【Bespoke 独立活动动画 Batch B（`A05–A14` 共 10 部完全独立短片）】**：按 Pixar 3D × Studio Ghibli 2D 双画风同构标准逐一手工落地 `A05`（凸窗手铃声源转头弧）、`A06`（5 步大开本绘本瓢虫点读与自主合书）、`A07`（竹帘长廊童谣节律四拍与风铃晃动）、`A08`（双材质棉布绒球与直槽桦木触感碟）、`A09`（壁挂榉木安全镜内置实时镜像反射）、`A10`（户外公园草坡木漏日与滑翔小鸟仰视）、`A11`（中线缝合地垫砂钟摇铃跨中线 8 字传递）、`A12`（恪守 Otto 无手正典的暖亚麻帘布躲猫猫）、`A13`（声学木砖轻敲与快慢对比声波）、`A14`（前后分层藤编百宝箱入篮与出篮），并在 `BespokeActivitySceneRegistry` 完成 20 部（`N01–N06`、`A01–A14`）独立镜头语法注册与 `testRound20BespokeBatchBScenesAndLampHub` / `test70Round20BespokeBatchBShowcases` 四模态渲染校验。
  - **【Tab 2 `LampHubView` 三板块升级 & ADA 2027 方法论】**：修复节律卡底排 3 枚导航胶囊在 AX2 超大字号下的换行与省略号截断；将 6 枚声景胶囊活跃态升级为低眩光褪黑素护眼高对比描边配发光指示点（WCAG AAA）；为 Otto 床头暖灯加入受 `scrolling.moving`、`Reduce Motion` 与可视区域门禁保护的 3.8s 呼吸声光脉冲；同步沉淀双语核心开发与设计规范至 `docs/METHODOLOGY.md`。

- **Batch 19（v2.0 正式发布候选 16 · 四屏纯血叙事重构 `摸索 / 台灯 / 留念 / 工坊` · 行业规范级来源/隐私/版本说明与 0 横滑清零）**：
  - **【四屏纯血信息架构落地】**：重构 `MosslingApp` 与四大主屏边界——第一屏 **摸索（Explore）** 专属于 Moss 探索（当月发展头卡 + 今日一起玩 + 感官玩具盒/百味食盒双卡），彻底清除混杂的喂奶/夜灯/节律/儿保噪音；第二屏 **台灯（Lamp，新建 `LampHubView`）** 以 Otto 可交互床头暖灯、三色光晕与 6 组声景为主舞台，并将 24 小时昼夜节律环/只读泳道/交接卡作为低噪可视化归集、日常随手记与明细折叠收纳，即使关闭记录仍保留完整床头灯；第三屏 **留念（Keepsakes）** 由 `JourneyHubView(isRootTab: true)` 统一承载 37 站串珠旅程、绘本、拍立得相纸、时光胶囊、WHO 生长曲线与当月儿保提示；第四屏 **工坊（Studio）** 将「摸索台灯的故事」三幕微剧院、`CraftPillarsShowcaseCard` 理念展块、外观偏好与透明循证文档中心前置呈现。
  - **【行业规范级来源/隐私/更新日志与版本同步】**：新建 `EditorialViews.swift`，将 `SourcesView` 升级为四大类别零横滑过滤 + 标准学术引文卡（短域名外链与一键复制引文，彻底告别文下裸贴长网址）；将 `DocView` 升级为带 Apple「隐私一图读懂」摘要徽章与儿童保护柔和底纹的规范阅读器；新建面向父母的 `ReleaseNotesView` 同步包版本号呈现产品更新；全面同步 `PRIVACY*.md`、`TERMS*.md`、`DISCLAIMER*.md` 至 `2026-11-24` v2.0 口径（完整如实载明相册仅本地单张选图、动作传感器零留存、后台离线音频、StandBy/控制中心与 4-Tab 路径）。
  - **【全站 0 横滑清零与多地区儿保分流】**：清理 `ReadingViews`、`FoodAtlasView`、`DailyRhythmStudio` 与 `StorybookView` 最后 5 处 `ScrollView(.horizontal)`；新增 `LocalizedHealthSchedule.swift` 在 `CareView` 提供中国 (NHC 2026)、美国 (AAP/CDC)、英国 (NHS)、澳大利亚 (NIP) 分地区参比，并补全 `testRound19FourTabArchitectureSourcesAndHealthRegions` 与 `test69Round19FourTabIAAndEditorialSystem`（更新 `AccessibilityAuditTests` 与 `ScreenshotTests` 4-Tab 基线）。

- **Batch 18（v2.0 正式发布候选 15 · Pixar 3D × Ghibli 2D 零依赖 Metal 渲染管线 · Batch A 独立活动小动画 `N01–N06 / A01–A04` · P0 全站折叠流畅度重构与只读总览条）**：
  - **【零依赖 Metal 渲染与双风格引擎 StoryTheaterShaders + Pixar × Ghibli】**：新增 `StoryTheaterShaders.metal`（含暖键光包裹、方向轮廓光、Otto 灯珠体积光锥、水彩湿边/棉纸肌理/木漏日光斑与手绘抖动 6 个原生 `[[stitchable]]` 着色器）、`PixarLightingRig.swift` 与 `GhibliWatercolorKit.swift`；以 `StoryTheaterActorView` 统一 `LivingBookStage`、`LivingMonthCoverStage` 与所有独立场景在 3D 哑光软胶 / 2D 吉卜力水彩及日光 / 夜灯下的同构坐标与物理跟随，并重点打磨 `N01`、`A04` 与 **第 6 月成长封面 `Month06ShowcaseCover`** 旗舰样板。
  - **【Bespoke 独立活动动画架构 & Batch A（10 部独立短片）】**：新建 `BespokeActivityScene.swift` 注册表与 **Batch A（`N01–N06`、`A01–A04`）** 共 10 部完全独立的分幕动画（各自拥有专属镜头语法、布景家具、教具物理轨迹与逐步骤动作编排，严禁套用共享模板）；列表缩略图通过 `ActivityPreviewThumb`（零 `TimelineView` + `compact: true` 定格）实现 120Hz 顺滑滚动，并同步清理 `DayLedger` 拖拽修改入口，保留纯只读泳道浏览与 4 时段快捷跳转。
  - **【P0 全站折叠统一 & 第一声灯绳回归与 502100ed 审查打磨】**：统一全站 `CalmMotion.accordionSpring`、`CalmAccordion` 与 `CalmDisclosureNote` 裁切防穿模展开收起（覆盖 `PlayView`、`GrowView`、`ReadingViews`、`FoodAtlasView`、`JournalView`）；在 `StoryView` 第一幕洁净恢复 `OttoBulbControl` 与 `LampConeOverlay` 拉绳互动；为自定义徽章补齐 `Firsts.customIconLabel` 无障碍朗读并提升 44pt 触控热区、修齐 Polaroid 与 Swift 6 编译警告，并在 CI 流水线补齐按需 `MetalToolchain` 检校与 `testRound18BespokeBatchAScenesAndDualRenderers` / `test68Round18PixarGhibliShowcaseAndP0`。

- **Batch 17（v2.0 正式发布候选 14 · 37 月龄活态成长绘本封面 Phase 3 · 16 教具质感精修与同步 Canvas 渲染）**：
  - **【活态绘本重绘 Phase 3 · 37 个月成长章节封面 `LivingMonthCoverStage`】**：新建 `LivingMonthCoverCatalog.swift` 与 `LivingMonthCoverStage.swift`，全面恪守 `docs/IP.md` 角色正典（3D 严格复用 `ip_moss_*`/`ip_otto_*` 与 2D 无缝切至 `FlatCreature`，绝不使用腮红/嘴点旧立绘），以草地（0–11 月）、树林（12–23 月）、溪边（24–36 月）三境剪纸景深、渐进成长比例、`LampLightRig` 实时光锥及 18 种成长象征教具，全面替换 `JourneyHubView`、`GrowView`、`TodayView`、`StorybookView`、`GrowthBook` 与 `GrowthMap` 全 6 处静态封面入口（旧 `cover_*.webp` 安全保留至 Phase 4 清理），新增 `testLivingMonthCoverCatalogAll37MonthsAndRender` 覆盖校验全部 37 个月。
  - **【StoryTheater Phase 2 教具精修与前景声波】**：在 `MontessoriPropRig` / `MontessoriPropRig+Props` 中将 `.soundRipple` 与 `.peekCloth` 柔和摇曳声波改绘至角色前景层（`.inFrontOfActors`）避免遮挡；升级镜面反射（内置 Moss 与 Otto 正典剪影）、透视桌面蜡笔画纸、3D 倒角积木过桥与接地灯笼木碟，补强圆杯、积木叠环、娃娃、铃铛、绘本与探索垫的哑光立体质感。
  - **【交互修复与同步 Canvas 渲染门禁 Fix & Craft】**：修复 `PlayView` 中 `DoneCount` 未玩过珠孔在浅/深色下对比过弱的问题，并在第 2 步起保留持续可见的圆形重播按钮；将 StoryTheater、首页迷你仪表、`Gauges` 与 `GrowthMap` 切换为 `Canvas(rendersAsynchronously: false)`，并优化 `ScreenshotTests.sharedWindow` 复用（全量 `MosslingTests` 211 项及定向 `test64/65/66` 均 0 失败通过）。

- **Batch 16（v2.0 正式发布候选 13 · 活态绘本微剧场引擎 Phase 1 · 深色宣纸夜境修复与活动页减负）**：
  - **全维度视觉与状态修复**：修复深色模式下 `PageBackground` 未跟随 `colorScheme == .dark` 仍渲染日间天光草地的问题；修复 `YouView` 外观色板 `Swatch` 在 AX2 大字下勾选标与标签重叠；将 `SearchEngine.quickQueries`（`ReadingViews.swift`）优化为分龄 4 枚均衡胶囊（`...3`、`4...8`、`9...18`、`default`）消除 4+1 孤儿换行；为 `Creature` / `FlatCreature` 的 `patted` 状态补齐 `!still` 守卫修复 2D 静态定格闭眼问题；修复 `Fold` 在 AX2 下「准备 · ...」标题截断并补充 `ArtView` 缩略图（`px <= 512`）同步解码回退消除 `MonthView` 深色冷启动空白。
  - **活态绘本微剧场 StoryTheater（Phase 1）**：新建 `ios/Mossling/IP/StoryTheater/`（`LivingBookModels.swift`、`PictureBookBackdrop.swift`、`LampLightRig.swift`、`MontessoriPropRig.swift`、`LivingBookStage.swift`），落地 5 相位 OpenMotion 动作时钟（蓄势 -> 主体表演 -> 接触反馈 -> 次级跟随 -> 稳定落点）、恪守 `docs/IP.md` 角色正典（零腮红/零嘴点/零台词气泡，严格沿用 `Sprites.mossFeet`/`ottoFeet`/`bead` 比例）、Otto 金珠实时光学追踪光锥、5 套北欧剪纸布景，并率先完成 `A04`（递木环摇铃）、`A12`（躲猫猫真实掀布）与 `A19`（叠积木搭建与倒塌欢呼）全模态动态脚本（Daylight 3D / Dark & Lamp 3D / 2D Flat / ZH-EN / AX2 / `Reduce Motion` `posterPhase` 确定性定格 / `ImageRenderer`），接入 `ActivityMotionStage`、`PlayView` 与 `TodayView`。
  - **全站版面减负与触控优化**：将 `PlayView` 多处冗余步骤计数与提示语收口为 `PlayLivingHeroCard` 内联 `StepBeadBar` 与轻触 `重播` 按钮；AX2 下操作按钮纵向排布；`CompactStepOutlineRow` 与 `FinishedCard` 同步升级为活态舞台微缩预览，并提升 `MatSideCoPlayView` 深色/夜灯模式下「安全看护」橘色调对比度；同时升级 `Gauges.swift`（`FluidGaugeCanvas` 弹簧液面与体温温区色带）及 `LogSheets.swift`（`CareEntryHelpers` 百味食盒快捷食材、`-15m/-5m/+5m` 快速调时与卡片化 `EntrySheet`）。

- **Batch 15（v2.0 正式发布候选 12 · 首页蒙氏工作台 · 三幕交互故事微剧院 · 活态计时伴护与 iOS 26 细节精修）**：
  - **【修复 Fix】**：在全站 `CalmScroll` 统一启用 iOS 26 `.scrollEdgeEffectStyle(.soft, for: .all)`，消除导航栏与底栏下滚动卡片出现的硬切模糊线；修复 `TimerScreen` 在 AX2 超大字号下声景控制行（`"床头..."` / `"草坡..."`）与尿布按钮（`"都有"`）的省略截断；优化 `StorybookView` 成长绘本单页纵深留白与底部柔化边界，完整呈现页尾父母随笔不被翻页豆链遮挡。
  - **【创意炼金术升级 Creative Alchemy Upgrade】**：彻底清理首页主卡多余的悬浮灯珠点与重复角标伙伴，将「**陪伴小器具**」重塑为三阶 **蒙氏生活工作台（Living Montessori Atelier Dock）**——首行直觉呈现带一键播/停助眠声景的深夜暖灯控制台与真实 24 小时睡眠/喂奶微型节律盘；中行换装实时六色花环食盒与五音条手工木琴；底行以折角纪念画册叠卡与信封折痕火漆囊收尾；同步将「**摸索台灯的故事 `StoryView`**」升级为「**点灯 -> 摸索 -> 0–36 个月长大**」三幕交互微剧院，支持轻拉灯绳开关暖光、轻碰木套环激发弹跳与撒叶、拖动金珠标尺实时看宝宝月龄成长。
  - **【IP 交互动效与版面优化 Living IP Motion & Visual-First】**：为 `CareTimer` 计时页新增随左右亲喂方向平滑追光与声景呼吸涟漪共鸣的 `CareCompanionStage`；将「我的」页 4 枚巨型控制块收敛为精致分组开关卡片，让底栏上方拥有从容呼吸感；清理「百味食盒」未标注圆点与重复横条，改用自解释类目图标计数与单行精简筛选带。
- **Batch 11（v2.0 正式发布候选 8 · 蒙氏交互木质尝味盒 · CareStage 粒子柔化与双语收口 · TabBar 沉浸与视口修复）**：
  - **【修复 Fix】**：修复 `CareStage` 奶瓶/尿布飘浮气泡在卡片底部被硬裁切的问题，为 `Drift` 粒子层加入垂直渐变遮罩后再裁切；修复英文版 `TodayView` 旅程卡副标题 `"37-Station Journey & Keeps..."` 省略号截断（`.minimumScaleFactor(0.84)`）；收紧 `SourcesView` `"0–3 yr activity, sleep & screen guide (2019)"` 以消除孤立换行 `"3 (2019)"`；为 `BirthSheet` 补充温柔的 `Duo` 双伴角色头图与 `Palette.bead` 宣纸底色；新增真实 `TabView + NavigationStack + ZoomDestination` 回归用例 `56_play_real_tabview_zh` 验证 `PlayView` 推入时底部 TabBar 已彻底隐藏，并统一 `FoodSpecimenChip` 四列等高与双行英文排布。
  - **【创意炼金术升级 Creative Alchemy Upgrade】**：彻底重构「**百味食盒 `FoodAtlasView`**」静态 60 格堆砌卡片，升级为「**蒙氏木质分格尝味标本盒（Montessori Wooden Tasting Cabinet）**」：花环顶卡轻盈化（82pt）并支持 6 色类目点按直达及 3 连击小薄荷撒叶特效；新增可 1 键洗牌/当场盖章的「**今日试味灵感 / 再试推荐台**」；新增拇指区浮停的「**快捷盖章坞 Quick-Stamp Dock**」，点选任意食材即可单手 1 键盖上「很喜欢 / 尝过啦 / 再试试 / +1 次数」并实时响应 `FoodAtlasStore.quickStamp` & `incrementTimes`。
  - **【版面与交互优化 Layout & Ergonomic Optimization】**：取消每张食材卡下冗余重复的 `"蔬菜/水果"` 类目副标题，改为双轨水平筛选带（6 大可折叠植物学抽屉 + 状态过滤胶囊）与紧凑 4 列（AX 自动降 3 列）标本芯片，大幅提升单屏信息密度与首屏可扫读性。
- **Batch 10（v2.0 正式发布候选 7 · 时光胶囊按住火漆揭封仪式 · 封存天数印记 · 绘本尾声专属 3× 印画）**：为 `TimeCapsuleView` 已就绪信笺加入物理阻尼「**按住火漆揭封**」仪式（按住火漆印章 0.65 秒，金色蜡融进度环随三段 `dimmerTick` 触感微震环绕升温，放开自动回弹并温柔提示，同时保留一键直接拆封与完整 VoiceOver / 减弱动态兼容）；在展开信笺与 3× 导出印画卡片上新增「**静静等待了 N 天**」真实封存跨度徽章；同步修复 `StorybookView` 翻至尾声页点击分享时误导出封面的问题，补齐专属 `StorybookEpiloguePrintCard`。
- **Batch 9（v2.0 正式发布候选 6 · 绘本折页迎宾扉页 · 「第一次」月龄灵感签盘 · 超大字号标题自折与全站底栏沉浸闭环）**：将初次打开迎宾页 `OnboardingView` 改造为**弧角棉纸扉页过渡**（柔和 `28pt` 圆角纸页轻叠台灯木桌下缘，告别生硬平直切线）；在「第一次」时间线尾新增按宝宝月龄自动推荐的**灵感拾珠托盘**（轻点未记下的「笑出声 / 坐 / 长出第一颗牙」等时刻直接预填留存）；重构 `SectionTitle` 适配系统 AX2/AX3 超大字号纵向排印，彻底消除右侧副标题挤折；同时补全「月份」「第一次」「搜索」「数据」「关于」「故事」「来源」「致谢」二级推送页面的浮动底栏隐藏，完成全站二级阅读沉浸闭环。
- **Batch 8（v2.0 正式发布候选 5 · 床头夜灯声灯共眠余烬协议与全页真色温联动）**：打通「声景定时渐弱」与「夜灯物理亮度/防息屏」的状态耦合——开启 15/30/60 分钟助眠声景进入最后 20 秒余弦渐弱时，Otto 的暖光、尘粒与屏幕亮度同步随声景平滑坠入微弱余烬，计时自然走完后自动合眼进入「安睡余烬」并释放常亮锁以省电，轻点即可温柔重燃；同步升级 `LampWarmth` 全谱系语义色彩令牌，切至「深烛红」或「蜜桃暖」时，顶栏、声景卡片、音量珠、4–6 呼吸与计时胶囊全部统一浸入对应色温并保留高对比可读墨色，深夜告别亮琥珀刺眼残留。
- **Batch 7（v2.0 正式发布候选 4 · 暗色舞台对比度修复 · 蒙氏串珠田野手账 · 布面压痕典藏绘本封面与全面沉浸式底栏）**：修复系统深色模式下首页主卡左下角动作提示胶囊因误判 `night` 而出现「白字配白底」的对比度缺陷（现按 `darkStage = night || envLamp || scheme == .dark` 统一渲染高对比深蓝底囊与明晰彩铅墨字）；升级「可以留意」与「接种与儿保」为蒙氏**串珠田野手账**（顶部实心光泽彩珠链与各领域分色对勾底晕 + 页尾棉纸引文卡）；为「成长绘本」封面移除重复角色贴纸、改钤金色火漆 Ex Libris 印章并增添棉布书脊压痕质感；同步为「生长曲线」「昼夜节律」「一天的节奏」隐藏底部 TabBar 实现二级工具页面全面沉浸。
- **Batch 6（v2.0 正式发布候选 3 · 蒙氏选架筛选工作室 · 温柔初次同意卡与焦点高亮）**：全面升级初次打开「欢迎使用摸索台灯」合规同意卡视觉，保留全部法定原文与等重操作按钮的同时，以温柔 `Duo` 问候头图与棉纸圆角卡分列协议条款与离线承诺；在「这周一起玩 / 调整」选架页为「这个月还可以玩」加入一键 **全部 / 还没玩过 / 蒙氏六大发展领域** 胶囊筛选，帮爸爸妈妈按宝宝此刻兴趣精准挑牌；为「六个方面」本月重点卡加入暖色焦点描边与底晕，「接种与儿保」页尾法规引文收纳进柔和卡片并加大底部留白，同时统一隐藏二级阅读页浮动底栏。
- **Batch 5（v2.0 正式发布候选 2 · 一键单日分类筛选胶囊 · 大字号精细排印与夜间高对比度优化 · CI 稳健度加固）**：在照护手账分时段列表上方新增 `DayFilterRail` 一键胶囊筛选栏（支持单日超过 2 类记录时一键直达「全部 / 喂奶 / 睡眠 / 尿布 / 辅食等」，找记录零凌乱）；消除单日条目跨日显示「N 天前」的时间戳冗余，并让超大字号（AX3）下的时段章节标题完整折行；修复「我的」页 `外观 / 语言` 大字号左对齐错位并放大主题预览窗以保护选中对勾不裁切；提升 `Crayon.pebble` 在深夜夜灯模式下的文字对比度；加固 `MascotTests.testAcknowledgeIsShortAndOnce` 在高负载 CI Runner 下的异步等待稳定性。
- **Batch 4（v2.0 正式发布候选 · 绘本页码与完工火漆纪念 · 灯珠温润手感定型 · 全站低功耗与十屏双语画册）**：为全 46 项活动分步舞台右上角加入绘本页码卡（`01 / 03`）与轻点彩珠爆发重播动画，并将活动完成页升级为**绘本贴纸胶带微缩图 + 金色火漆印章纪念卡**；正式定型并锁定 **Otto 金色灯珠「温润 `.warm`」物理阻尼弹簧**，移除「关于」页临时实验开关；完成全站 `TimelineView` 与 `CMMotionManager` 后台/滑动/熄屏超低功耗审计（床头夜灯尘粒、呼吸光环与陀螺仪，金珠雨棒，萤火瓶，纸面漂浮星点及绘本动态叠层均在后台或滚动中自动暂停，水彩晕染尊重减弱动态效果）；同步升级至 **`2.0`** 并刷新 10 屏 6.9 英寸中英双语 App Store 上架展示截图与审核指引。
- **Batch 3D（真绘本分步动态图解 · 剪纸山水与信笺桌案重塑）**：全面移除违和感 3D AI 场景图，回归品牌原汁原味的 **儿童绘本 + 白色模切贴纸** 世界观——全 46 项活动页、`4:3` 首页主卡与「垫旁共玩」现均严格对应每一步的真实绘本分步插画（覆盖 3D 软胶与 2D 纸面双画风 146 幅步骤图），并按步骤语义（轻递弧线 / 声波呼应 / 左右追视 / 静等停顿 / 托举翻页 / 轻摇安抚）叠加强辨识度**北欧蜡笔矢量动态引导箭头与波纹**，支持左右滑动或轻点画面重播；家庭交接卡重塑为 **Otto × 珊瑚针织帽白模切贴纸 Mochi 传递灯笼**绘本场景，串珠旅程三大国度升级为**剪纸叠峦 + 虚线小径 + 胶带贴封面卡**横幅，时光胶囊书桌改版为斜叠棉纸火漆信封搭档守夜 Otto。
- **Batch 3C（创意炼金术桌面手感重塑 · 沉浸工坊零遮挡 · 3D 器具徽章统一）**：全面消解沉浸页底部悬浮 TabBar 对主操作按钮的遮挡（感官玩具盒、活动页、百味食盒、时光胶囊、串珠旅程、成长册推入自动隐藏底栏）；感官玩具盒移除顶栏防碰撞横幅，改用原生副标题与右上角实时 **护耳音量百分比胶囊**（轻点随时展开/收起）；将护耳音量提示卡压缩为 **单屏无压紧致 HUD（高度减半，把更多画面还给乐器）**；质感全面雕琢 **黄铜铆钉花梨木琴音箱**、**斜角桦木钢化玻璃雨棒匣（带四角黄铜钉）** 与 **一体旋钮铜盖吹制玻璃萤火罐**；首页「陪伴小器具」全部 6 枚徽章统一升级为 **3D 哑光软胶立体浮雕质感**，与时光胶囊火漆徽章视觉同宗。
- **Batch 3B（床头待机信标 · 控制中心与 Siri · 夜间计时驾驶舱 · 成长月度双层画廊）**：床头台灯小组件全面适配 iOS **StandBy 待机红光夜间模式**（`.widgetRenderingMode` / `.widgetAccentable` 高对比描边与超清远距大数字、24 小时微光律动条及中型一键暂停/睡前快捷按钮）；新增控制中心「**床头夜灯**」一键直达按钮与 Siri「**查看宝宝近况**」棉纸摘要卡及「**记一次瓶喂**」语音指令；亲喂/睡觉计时页统一换装**哑光软胶触感按键**，新增计时内一键开关助眠声景、音量护耳提示与顺手三选一记尿布栏；月度详情页升级「这个月」**环形进度双卡 + 探索 2×2 宫格**，全站补强叙事旁白并仅在白天温和触发纪念回响评分引导。
- **Batch 2B（智能护耳音量检测 · 全 46 项活动微动效舞台与垫旁共玩 · Mochi×Otto 交接插画）**：为感官玩具盒（木琴 / 金珠 / 萤火）与床头夜灯加入非打扰式**智能护耳音量监测**——仅在首次进入或手机实际音量偏大（>60%）/ 静音时温和浮现实时三段式音量条（清晰标示 `20%–55%` 绿色护耳带，按侧边音量键实时同步滑动）；重塑活动页为「去任务化」**蒙氏活体示范舞台**（`ActivityMotionSpecs.json` 覆盖全 46 项活动的 8 类木质/布艺交互物理动效并与原本步骤插画一键切换），并新增全屏一指触控**「垫旁共玩态」**；交接卡顶部加入 **Mochi × Otto 传递灯笼** 插画并同步印上 3× 分享海报；百味食盒新增盖章果冻回弹与三击 Moss 嫩芽散叶彩蛋。
- **Batch 2A（记录页 ADA 重构 · 三轨时间条 · 一张全年/日长图 · 0.6 秒内联快记）**：重构高密新生儿记录页阅读与输入流畅度——24 小时时间条升级为睡眠 / 喂奶 / 照护**三轨并行**（支持手指左右搓动实时定位任意事件与四时段跳转）；历史回顾日自动折叠贴纸坞归还一屏阅读空间；一日条目按**夜晚 / 下午 / 上午 / 深夜**四章智慧折叠（紧致三列呈现完整细节与间隔，单屏可览全天）；点「尿布 / 瓶喂」贴纸展开 0.6 秒内联快选与智能奶量推荐；记录页支持**一键导出整天完整高清手账长图**（无需再手动连截多图）。
- **Batch 1 先行预览（三层光晕 · 0 Emoji 工艺 · 串珠旅程）**：首页主舞台上方悬挂可交互 **Otto 金色灯珠**（轻点或下拉阻尼微震直接点亮床头夜灯，长按 2 秒触发全屏水彩晕染切换 3D 软胶 / 2D 纸面世界，经盲测在 2.0 锁定为温润弹簧阻尼）；2D 与 3D Moss 全面统一去腮红并补齐 2D 叶脉与背毛；百味食盒 60 种全食物与陪伴小器具全面采用手绘双画风矢量工艺图标（全站 0 Emoji）；点击首页月份卡直达纵向**「串珠旅程」**总览 37 站月龄、纪念书架与静谧珠链。

- **全新升级「感官玩具盒」四工坊共玩**：**音阶木琴**支持木琴 / 八音盒 / 拇指琴 3 种离线实时合成音色、内置「小星星」「茉莉花」「摇篮曲」「欢乐颂」「小羊羔」「划小船」6 首曲目试听与「跟光弹」逐音光晕引导、击打音波环与音符粒子动效；**金珠雨棒**新增雨滴 / 沙漏 / 花环 3 种木钉阵型，支持「木珠 / 风铃」双音色切换、撞柱光环与珠尾轨迹；**萤火流光瓶**新增漫游 / 爱心 / 弯月 / 银河 4 种聚集阵型、慧尾光迹、触屏涟漪与五声音阶琶音；**黑白视卡**扩充至 12 张并支持轻柔律动、黑白反色与防息屏全屏展示。
- **Otto 床头夜灯 · 6 大声景、3 档暖色与 4–6 呼吸光环**：声景扩展至 6 种（新增「轻声嘘拍」与「暖海潮汐」），支持「+」无爆音平滑双层混音、耳机拔出静音保护、电话中断恢复与锁屏 Now Playing 控制；新增琥珀光 / 深烛红 / 蜜桃暖 3 档色温切换与双击快速调暗。
- **「百味食盒」与「成长绘本 / 昼夜节律盘」深度联动**：百味食盒收录 60 种常见全食物、致敏与留意角标、尝过次数、关键词搜索、折行筛选与 3× 百味护照分享；成长绘本按月自动收录「这个月新尝的味道」；昼夜节律盘新增日均睡/喂/最长一觉与入睡时段事实摘要。
- **可视化「家庭交接卡」**：记录页右上角一键打开「交接给下一位点灯人」，与首页及小组件统一按开始时间实时刷新，一键生成 3× 棉纸交接卡或复制纯文字发给家人。
- **完整备份与全局搜索打通**：「完整备份」与「给医生或 AI 看的记录」完整纳入百味食盒记录、时光胶囊信笺与安全存储保护；首页全局搜索支持直达 6 大陪伴小器具与 60 种食材。

## 1.0.1
更稳妥的本地记录，更顺手的生长曲线，以及多处夜灯与手感打磨。

- **夜灯与手感细节**：夜灯模式下的软胶卡片、计时页与成长册相纸色调更统一；首页「换一个」加入轻柔的换卡过渡，活动页新增串珠步进条，背景飘落画面在后台自动暂停更省电。
- **WHO 生长曲线升级**：曲线更顺滑，可在「当前阶段」和「0–36 个月」之间切换视野，点击曲线下方即可逐条查看每次测量与较上次的变化，并直接编辑。
- **更安心的本地存储**：加固记录与小组件之间的数据同步，避免意外覆盖历史记录；强化应用锁保护，并优化锁屏实时活动的显示。
- **记录与导出修正**：表格导出与编辑页里的时长现在会准确扣除暂停时间，只记录身长或头围时也能正常显示。
- **稳定性修复**：修复计时刚满 1 分钟内选择结束时间，以及导入异常日期或测量值时可能闪退的问题。

## 1.0.0
摸索台灯的第一个 iOS 版本，陪你和 0–3 岁的孩子一起玩、一起长大。

- **孩子摸索，大人点灯**：首次打开时，Otto 的灯亮起，Moss 在灯下摸索；在「关于摸索台灯」里可以读到名字的故事。
- **今天一起玩**：首页每天推荐一个适合当前月龄的活动，第一步插图一眼可见，随时可以「换一个」；每周自动准备几项备选。
- **37 站成长与 46 个家庭活动**：涵盖 0–36 个月共 37 站指南、46 个家庭活动与 146 幅逐步插画，支持按六个发展领域、专题与搜索浏览。
- **可选的照护记录**：支持喂养、睡眠、尿布等记录与计时，可补记时间、分别记录暂停与换边，并提供时间线、统计、WHO 生长曲线、锁屏实时活动与桌面小组件。
- **安静陪伴的 Moss 与 Otto**：两位伙伴不说话，只用眼神和动作陪伴；任选一位作为主伙伴，所有功能完全相同。
- **只留在你的设备上**：无需账号，不连接网络，附完整的隐私政策、使用条款与免责声明。
