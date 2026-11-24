# 摸索台灯（Moss & Otto）· 冲刺 Apple Design Awards 2027 开发与设计方法论 v3.2

> **文档定位**：本方法论在 Round 24 正式升级为 **v3.2（八大核心支柱 + 全局首屏主义零非必要下拉铁律 + 五大版螺旋自我推翻机制）**。明确界定：**完整的一轮全站大重构（Rounds 22–26）仅构成「Edition I（第一大版）」**；其后必须通过强制归零重审门禁，以同等烈度再推翻重铸 **Edition II -> III -> IV -> V** 共五大版。全文严格遵守 **0 Emoji** 规范。
>
> **配套专项技能**：[ios-spatial-ia-tactile-craft/SKILL.md](file:///Users/someone/.gemini/config/skills/ios-spatial-ia-tactile-craft/SKILL.md)。

---

## 核心总纲

**「孩子摸索，大人点灯」不止是一句口号，而必须由零迷路原生态 iOS 空间秩序、不靠繁琐点击的流动交互叙事、真材实料的器物物理手感和学术级透明共同传达。严禁用做网页的层级套娃思维堆砌软件，也绝不能把「一版完整大改拆成五小步做完」误当作迭代——必须在连续五个大版周期中反复把上一版打散重审、敢删敢重建，方能逼近 Apple Design Awards 水准。**

---

## 八大核心支柱

### 一、原生 iOS 空间秩序与单源真理（Zero-Maze Single-Source-of-Truth IA）

1. **一物一处，全局唯一归属**：
   - 严禁同一业务功能、清单或设置入口在两个页面重复出现（**唯一合法跨屏共享仅限 IP 性格彩蛋**，如点击 Moss/Otto 的互动彩蛋与解锁故事入口）。
   - 彻底消灭“HTML 多级抽屉套娃”（如禁止 `YouView` 外层已有链接的前提下再嵌套一个重复半数链接的 `AboutView`）。任何二级页面只有在“内容体量独立且父级完全不再重复出现”时才值得存在。
2. **四 Tab 路由严格分域，杜绝跨 Tab 交叉感染**：
   - 将单一全域 `.routes(path:)` 拆分为四个互补相交的领域路由（`ExploreRoute`、`LampRoute`、`KeepsakesRoute`、`StudioRoute`），通过统一 `AppRouter` 治理跳转。
   - **Tab 0 · 摸索（`Explore` / Moss 主角）**：晨光探索主轴，严格只留本周主打流动游玩、本周玩具架、感官玩具盒与百味食盒；坚决不出现跨界月卡、儿保待办、实时喂奶或夜灯。
   - **Tab 1 · 台灯（`Lamp` / Otto 主角）**：暖琥珀床头夜灯器物舞台 + 声景 + 24h 节律盘 + 只读日泳道 + 传灯交接与随手照护轻记（支持页内切日与补记，不再另 push 克隆了夜灯与生长曲线的分裂手账页）；照护记录关闭时台灯与声景依旧完整独立可用。
   - **Tab 2 · 留念（`Keepsakes` / Moss × Otto 成长轨）**：37 站可搓动串珠小路与月份详情 `MonthView` 的**唯一法定归属地**、统一成长绘本（废除无生日/有生日两套分裂绘本）、第一次相纸册、火漆时光胶囊、WHO 生长曲线与温和儿保卡。
   - **Tab 3 · 工坊（`Studio` / 理念 · 伙伴 · 设定 · 透明循证）**：严格遵循 **单屏免下拉驾驶舱（Single-Viewport Cockpit，默认字号 `<= 655pt`）**——紧凑合体「宝宝与伙伴卡（内联「摸索台灯的故事」三幕微剧院金珠入口）」、紧凑外观与语言切换卡、2×2 触感偏好磁贴格、2×2「循证 / 备份 / 隐私 / 更新志」核心透明格，以及一行静态页脚 + 轻弹 `StudioLegalSheet`（收纳条款、免责、许可致谢、重播提示、反馈与可折叠设计工艺四柱；零嵌套 `AboutView`、零重复行、零页面堆砌）。
3. **搜索与跨 Tab 跳转守则 + HIG 底栏位置感 + 全局严禁非必要下拉浏览**：
   - 全局 `SearchView` 或 Deep Link 指向其他 Tab 资产时，**必须调用 `AppRouter` 切换 `selectedTab`** 再推栈，严禁把异域页面克隆压入当前 Tab 栈内。
   - 遵照 Apple HIG（`tab-bars.md`）：正常层级推进时**保持底部 Tab Bar 清晰可见**，绝不随意隐藏底栏造成迷路；仅在真正全屏焦点剧场与床头夜灯模态中隐去外部导航栏。
   - **全局首屏主义（Viewport-First / 严禁非必要下拉浏览）**：所有四大主屏（`摸索 / 台灯 / 留念 / 工坊`）在默认字号与默认折叠态下**必须一屏完整呈现（`393 × 852pt` 内 `<= 655pt` 主体高度，零非必要纵滑）**；所有主屏及核心焦点页统一启用 `.scrollBounceBehavior(.basedOnSize)` 消除网页橡皮筋弹性误触，且「留念」三片土地章节默认保持折叠（仅点“回到现在”或点击土地条时原地展开）。纵向滚动仅保留给 AX1–AX5 无障碍大字、长文阅读器/索引及用户主动展开的明细抽屉。

---

### 二、去步骤化连续叙事与原生器物手感（Frictionless Story-Through-Touch & Creative Alchemy）

1. **消灭“多步点按跑步机”**：
   - 陪伴 0–3 岁孩子时父母往往只空得出半只手。活动页严禁强迫用户一步一步连点「下一步 -> 1 -> 2 -> 3 -> 4 -> 做完了」或重复堆砌完整步骤列表及分裂全屏模式。
   - 取而代之：以**单卡片连续流动剧场（Continuous Living Vignette）**呈现每张活动卡——自动柔和演进完整过程，底部配备一根可单指顺滑搓动的**蒙氏滑珠时间轨（`CoreHaptics` 节拍卡点）**、原地展开无打扰焦点模式，以及页尾一颗「长按 0.6s 落珠」直接完成仪式。
2. **让每一套核心仪器真正“令人屏息”（Metal + CoreHaptics + DSP + CoreMotion）**：
   - 创意炼金术拒绝“换皮肤式排版”，必须直接突破软件的物理错觉边界：
     - **Metal 着色器分工**：纯局部像素光色温与棉纸质感用 `colorEffect`；涉及半影柔和边缘、灯光涟漪与相邻像素采样的柔和衍射用 `layerEffect`；120Hz 手势拖拽仅传入平铺基础标量 uniforms。
     - **CoreHaptics 生命力**：全站复用单一长寿 `CHHapticEngine`（配置 `resetHandler` 与硬件降级回落），严禁高频重建；将连续细腻波形（丝绸摩擦、无声掌心轻拍哄睡节律）与清晰瞬态敲击（滑珠卡点、金珠碰击、蜡封裂开）精准耦合。
     - **物理直观讲故事**：围绕「孩子摸索，大人点灯」持续孵化标志性原生交互，包括「Otto 光影手影墙」、「黑体色温 + DSP 包络床头灯」、「无声掌心轻拍器」、「划屏传灯交接仪式」、「物理刚体碰撞雨声棒」与「37 站可搓动串珠望远镜」。

---

### 三、一卡一动画 1:1 咬合与三平面空间物理严谨（Bespoke 1:1 Craft & 3-Plane Grounding）

1. **46 部活动 100% 独立手绘成片，零套壳、零幽灵道具**：
   - 严禁任何“左右对称固定站位 + 居中悬浮物体”的模板，以及脱离 `content.json` / `content_en.json` 步骤描述的空转动作。46/46 全部完成后彻底清除通用 `MontessoriPropRig` 兜底模板。
   - **三平面空间铁律**：严格区分「背景天空/墙面 -> 中景家具/地垫 -> 前景 Grounded 角色与手触道具」。严禁把整宽桌面画在人物脚底上方导致“角色站在桌子垂直立面上”（如历史问题 `A20`/`A24`）；严禁抹布、蜡笔、杯子、积木在未受角色肢体与地面承托的情况下凭空漂浮或自行动手。
   - **动态灯珠着色器坐标**：`PixarStageGrade` 的金珠光源 `beadPos` 与焦距落点 `targetPos` 必须由每个场景实时计算并传入，禁止统一写死固定屏幕百分比。
   - **多机位镜头语法**：积极采用俯视桌面/地垫平铺、肩后半身视角、同侧共读、墙面镜对望与斜向穿插景别，彻底打破「左 Otto 右 Moss」对称疲劳。
2. **双画风成片标准 & IP 正典红线（`docs/IP.md`）**：
   - **Pixar 3D × Studio Ghibli 2D**：共用同一 `groundY` 与重心锚点，切换画风原地渐变 Zero-Pop；Pixar 保有软胶体积与双层 Contact AO，Ghibli 保有冷压棉纸、木漏日与非纯黑彩铅线。
   - **IP 正典红线**：零腮红、零嘴点（仅 `.wow` / `.happy` 绘制合法嘴型）、零对话气泡、**Otto 永远无手**、不饿不哭不受伤、无打卡焦虑、第 4 位照护交接伙伴正典名称固定为 **Mochi**（珊瑚针织帽白陶小鹅卵石）。

---

### 四、丝滑交互、防误触与零横滑红线（Fluidity & Ergonomics）

1. **概览条纯只读防误触**：`DaySwimlaneCanvas` 保持 `.allowsHitTesting(false)`，零纵向抢手势。
2. **全站统一折叠物理学**：折叠容器统一复用 `CalmAccordion` / `CalmDisclosureNote`（平滑弹簧 + `.clipped()`），折叠态不执行离屏重计算。
3. **零横向滚动（`ScrollView(.horizontal)` = 0）**：所有标签、筛选条与卡片集采用自适应折行 `FlowRow`、`LazyVGrid` 或直向搓动滑轨，彻底消灭横竖手势冲突与边缘截断。
4. **滚动 120Hz 热路径与 Liquid Glass 严格限额**：列表缩略图走静态零 `TimelineView` 的 `ActivityPreviewThumb`；主舞台 `TimelineView` 必须同时受 `accessibilityReduceMotion`、`Perf.still`、`.onScrollVisibilityChange` 与 `scrolling.moving` 保护；`.glassEffect` 全站**有且仅允许**存在于 [ToastHost.swift:46](file:///Users/someone/Projects/mossling/ios/Mossling/UI/ToastHost.swift#L46)。
5. **褪黑素安全与无障碍（AX2/AX3 / VoiceOver）**：深蓝夜灯底避免高饱和大块亮底配浅字；三联及以上横向胶囊在 `type.isAccessibilitySize` 自动改纵向堆叠；所有自定义连续搓动器与手影舞台提供完整 VoiceOver 语义与 `.accessibilityAdjustableAction`。

---

### 五、行业规范级透明与国际化可信度（Editorial & Global Rigor）

1. **学术级循证视图（`SourcesView`）**：禁止一段文字下裸贴长网址；提供 `FlowRow` 机构分类、认证胶囊、修订年份、引文复制与干净短域名链接。
2. **隐私营养标签实事求是同步**：`DocView` 与 `PRIVACY*.md`、`TERMS*.md`、`DISCLAIMER*.md` 实时匹配真实 `Info.plist` 权限（照片手选、零留存 Motion、纯离线声景）与最新四屏路径，提供儿童数据专项说明。
3. **面向父母的版本更新志（`ReleaseNotesView`）**：与工程师 [CHANGELOG.md](file:///Users/someone/Projects/mossling/ios/Docs/CHANGELOG.md) 严格解耦，自动读取 Bundle 版本，严禁出现类名、内部轮次或研发行话。
4. **纯离线多地区健康日程**：`LocalizedHealthSchedule` 按 CN / US / UK / AU 四地离线提供儿保与疫苗时间参考与审慎医疗边界。

---

### 六、本机零模拟器 + 零第三方依赖 + 五大版螺旋推翻机制（Zero-Simulator & Five-Edition Cadence）

1. **绝对禁用 Xcode 模拟器**：严禁调用 `Simulator.app`、`xcrun simctl`、`xcodebuild test` 或 `-destination 'platform=iOS Simulator...'`。本机日常编译门禁严格采用：
   - `xcodegen generate`
   - `xcodebuild build -project Mossling.xcodeproj -scheme Mossling -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`
   - `xcodebuild build-for-testing -project Mossling.xcodeproj -scheme Mossling -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`
   - 静态扫描红线：`ScrollView(.horizontal)` = `0`、`.glassEffect` = `1`、`DisclosureGroup` = `0`、0 Emoji、`app/src/main/assets/` diff = `0`、主屏/焦点页统一 `.scrollBounceBehavior(.basedOnSize)` 与 `852pt` 单屏验证截图、目标 Swift 编译零新增警告。
2. **零第三方运行时 SDK & 禁止 OpenMotion MCP**：100% 原生 Swift / Metal / CoreHaptics / AVAudioEngine；严禁调用 OpenMotion MCP 工具。
3. **大版（Edition）与战术轮次（Round）严格区分**：
   - 每一轮战术更新仍围绕「【一、修复 & 空间治理】+【二、创意炼金术物理跃迁】+【三、插画精修与全局交互打磨】」三板块闭环推进；
   - 数个连续战术轮次（如 Rounds 22–26 共同构成 **Edition I**）合起来才完成**一整个大版**的架构、动画与器物重塑；严禁将同一轮架构工程切成五块就当作“打磨五个版本”。
4. **跨大版强制归零重审门禁（Kill-Your-Darlings Reset Gate）**：每当 **Edition $N$** 交付并跑绿云端 CI 后、启动 **Edition $N+1$** 前，必须执行：真机全路径盲测 -> 调用 `creative-alchemy` + `bold-design-refactor` + `get-more-perspectives` 做陌生人挑刺 -> 输出显式「删减与推翻重构清单（Kill Your Darlings）」-> 依据实机发现动态定稿下一大版的战术轮次并与用户确认，如此真刀真枪迭代足足 **五大版（Edition I -> V）**。
5. **智能错峰 CI 推包**：每次 `git push` 前务必 `curl -sL "https://github.com/mjuvdeysii/mossling/actions/workflows/ios.yml"` 检查队列。若上一轮仍在运行或排队，**严禁强行推包打断 TestFlight**（`cancel-in-progress: true`）；利用等包窗口打磨测试与文案，待上一轮 `completed successfully` 后再接力推送；严禁 `git add -A` 与暂存 `.DS_Store`。

---

### 七、物理真机协同验证规程（Physical iPhone Verification Gate）

由于严格零模拟器原则，凡涉及以下体验细节的终局验收，**主动邀请用户连接物理 iPhone 真机**进行联合实测，绝不凭空臆测效果：
1. `CHHapticEngine` 无声掌心轻拍、蒙氏滑珠卡点与雨声棒颗粒触觉质感。
2. 深夜低光实测床头灯 `1800K` 黑体调光、系统亮度天花板钳制与连续 30 分钟音频播放的温控/耗电。
3. VoiceOver 实机焦点顺序、120Hz ProMotion 搓动跟手度与 3x 传灯海报微信/隔空投送视觉观感。

---

### 八、上下文主动交接门禁（Context Handoff Gate）

当多轮开发推进至重要交付节点或上下文接近上限时：
1. 绝不硬撑至上下文自动压缩失真，主动精确汇总当前状态与实核哈希/CI 结果。
2. 生成可直接接棒的 `HANDOFF_ROUNDXX_ADA2027.md`（并对照 [ADA2027_MASTER_PLAN_v3.0.md](file:///Users/someone/.gemini/antigravity/brain/78a5a83f-079c-4bbd-bad3-bf0005e04eb2/ADA2027_MASTER_PLAN_v3.0.md) 标明所属 **Edition I–V 编号**、当前战术轮次，以及若抵达大版边界时必须先执行的 Reset Gate）。
