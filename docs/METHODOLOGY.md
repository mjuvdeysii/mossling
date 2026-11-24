# 摸索台灯（Moss & Otto）· 冲刺 Apple Design Awards 2027 开发与设计方法论

> **文档定位**：本方法论系统提炼自历轮用户核心指示、设计纠偏与架构演进（截至 Round 19 提交 `b7115289`），作为后续全站打磨、动画创作、文案规范与 CI 发包的唯一指导纲领。全文遵守仓库 **0 Emoji** 规范。

---

## 核心总纲

**「孩子摸索，大人点灯」不止是一句口号，而必须由信息架构、画面克制、触感节奏与行业级透明共同传达。绝不能让产品看起来“有产品思维，但没有设计”。**

---

## 六大核心支柱

### 一、设计叙事高于产品堆砌（Design Narrative > Feature Dumping）

1. **四屏纯血叙事分工**：一级界面严格按「探索 -> 点灯 -> 留念 -> 工坊」四步情感情境拆分，各自持有唯一视觉主角，严禁板块互串感染：
   - **Tab 0 · 摸索（`Explore` / Moss 主角）**：晨光纸面质感；仅承载月龄探索头卡、本周主打游玩（Pixar 3D × Ghibli 2D 活态舞台）与双感官小工坊入口（感官玩具盒、百味食盒），坚决移出实时喂奶卡、儿保待办、夜灯入口与节律环。
   - **Tab 1 · 台灯（`Lamp` / Otto 主角）**：暖琥珀夜灯舞台绝对居首（三暖光预设、亮度滑杆、六声景单触切换、全屏沉浸夜灯入口），下方收拢柔和可读的 24h 节律盘、纯只读日泳道总览、传灯交接与可折叠轻量手账；即使关闭「照护记录」，Otto 台灯与声景依旧完整独立可用。
   - **Tab 2 · 留念（`Keepsakes` / Moss × Otto 成长轨）**：37 站「串珠小路」、当前月明信片、四大成长藏品入口（成长绘本、第一次拍立得画册、火漆时光胶囊、WHO 生长曲线）与温和儿保节律卡。
   - **Tab 3 · 工坊（`Studio` / 理念展厅 · 设定 · 循证）**：紧凑宝宝名片、「摸索台灯的故事」三幕微剧院入口、四大克制支柱可视化展块、外观/语言/锁屏设置与循证透明文档中心。
2. **少字多可视化（Show, Don't Tell）**：日常页面削减说教段落与重复分类胶囊墙，用串珠、节律盘、泳道色块、交互灯珠与 2–4 字短标直观呈现状态。

---

### 二、拒绝套壳模板与半成品试水（Bespoke Craft & First-Shot Final Quality）

1. **46 部活动逐一手工独立编排**：严禁「左 Otto 右 Moss 固定站位 + 居中道具 + 两层滤镜」的套壳模板。每张活动卡片（`N01–N06`、`A01–A40`）必须拥有独立 Swift 舞台文件、唯一 `cameraGrammar`（镜头语法/视口景别）、贴合蒙氏教具物理规律的轨迹（如穿过中线弧、藤编篮前后遮罩入篮出篮、墙面安全镜同步反射），以及与 `content.json` / `content_en.json` 步骤字面一一对应的动作演化。
2. **首版即成片级定调**：绝不用草稿占位再反复返工，新场景首版即同时达到双画风最终成片品质：
   - **Pixar 3D 标准**：三点棚拍暖光包裹、哑光软胶质地、双层 Contact AO 接地阴影、体积保留挤压拉伸（squash & stretch）与 Otto 金珠体积光池。
   - **Studio Ghibli 2D 标准**：冷压棉纸颗粒与水彩湿边渗色着色器、木漏日（Komorebi）柔光、非纯黑彩铅轮廓线（深苔绿/深靛蓝）、严格基于 `Shapes.swift` 1:1 正典路径与次级延迟摆动。
   - **1:1 空间坐标系零跳位**：两套画风共用同一 `actorCenterY` 与地平线坐标，切换画风原地渐变成形。
3. **IP 正典红线（`docs/IP.md`）**：零腮红、零嘴点（仅在 `.wow` / `.happy` 时按规定绘制嘴型）、零台词/零对话气泡、**Otto 永远无手**（如躲猫猫使用柔和织物垂帘而非手掌）、不饿不哭不受伤、无连续打卡焦虑，同时严格遵守 `Mood` 枚举合法值（`.open`, `.happy`, `.wow`, `.sleep`）。

---

### 三、丝滑交互、防误触与零横滑红线（Fluidity & Ergonomics）

1. **概览条纯只读防误触**：`DaySwimlaneCanvas` 保持零 `DragGesture`、零拖拽浮条、零内联误触编辑入口（`.allowsHitTesting(false)`），彻底杜绝与外层纵向 `ScrollView` 抢手势。
2. **全站统一折叠物理学**：折叠容器统一复用 `CalmAccordion` / `CalmDisclosureNote`（平滑物理弹簧 + `.clipped()` 裁边），折叠态不执行离屏重计算。
3. **零横向滚动（`ScrollView(.horizontal)` = 0）**：全站所有标签、筛选条、卡片列表均采用自适应折行 `FlowRow`、`LazyVGrid` 或静态分页点，彻底消灭横竖手势冲突与边缘截断。
4. **滚动 120Hz 热路径减负与静态占位门禁**：所有滚动流中的预览缩略图必须走静态零 `TimelineView` 的 `ActivityPreviewThumb`（传固定 `posterPhase` 且 `compact: true`）；任何主舞台 `TimelineView` 必须同时受 `accessibilityReduceMotion`、`Perf.still`、`.onScrollVisibilityChange` 与 `scrolling.moving` 节流保护；Liquid Glass（`.glassEffect`）全站**有且仅允许**存在于 [ToastHost.swift:46](file:///Users/someone/Projects/mossling/ios/Mossling/UI/ToastHost.swift#L46)。
5. **褪黑素安全与无障碍（AX2/AX3）合规**：夜灯深蓝底色上活跃控件避免高饱和大块亮底配浅字或刺眼撞色，改用低饱和柔光描边 + 高对比度暖白墨字；三联及以上横向胶囊在 `type.isAccessibilitySize` 下自动切为纵向堆叠，允许自然折行、零省略号截断。

---

### 四、行业规范级透明与国际化可信度（Editorial & Global Rigor）

1. **告别裸贴 URL，建立学术级循证视图（`SourcesView`）**：禁止一段文字下裸贴长网址；按机构与研究性质分四大类（`FlowRow` 筛选），每条展示机构认证胶囊（`WHO / AAP / CDC / NHC / UNICEF`）、修订年份、规范文献标题、一键复制引文与干净短域名外链（如 `who.int`）。
2. **隐私营养标签与权限实事求是同步**：`DocView` 与 `PRIVACY*.md`、`TERMS*.md`、`DISCLAIMER*.md` 必须随 `Info.plist` 真实权限（如仅「第一次」手动选图时读取相册、仅床头灯/雨声棒使用零留存 Motion、纯离线后台声景播放）以及当前四屏路径同步更新，并以 Apple App Store 风格「隐私一图读懂」摘要与儿童数据专项说明高亮呈现。
3. **面向父母的版本更新志（`ReleaseNotesView`）**：与工程师 [CHANGELOG.md](file:///Users/someone/Projects/mossling/ios/Docs/CHANGELOG.md) 解耦，自动读取 Bundle 版本号，用温暖清晰的家庭语言讲述新特性，绝不暴露源码类名或内部轮次编号。
4. **海外健康内容纯离线地区分流**：`LocalizedHealthSchedule` 按 CN / US / UK / AU 四地离线提供儿保与疫苗参考时间线，并保留医疗审慎边界说明。

---

### 五、本机零模拟器 + 零第三方依赖 + 错峰推包飞轮（Zero-Simulator CI Cadence）

1. **绝对禁用 Xcode 模拟器**：严禁运行 `Simulator.app`、`xcrun simctl`、`xcodebuild test` 或任何 `-destination 'platform=iOS Simulator...'` 命令。本机验证严格采用：
   - `xcodegen generate`
   - `xcodebuild build -project Mossling.xcodeproj -scheme Mossling -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`
   - `xcodebuild build-for-testing ... -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO`
   - 静态边界审计（`ScrollView(.horizontal)` = 0、`.glassEffect` 仅 1 处、0 Emoji、`app/src/main/assets/` 未改动、新增 Swift 文件零 Warning/Error）。
   - 全量单元测试、无障碍审计与截图回归交由 GitHub Actions 云端运行（`.github/workflows/ios.yml`），真机体验/能耗/VoiceOver 由用户连接 iPhone 真机协助完成。
2. **零第三方运行时依赖**：不引入任何外部 Swift Package 或运行时 SDK；Metal 着色器（`StoryTheaterShaders.metal`）、物理弹簧、触觉（`CHHapticEngine`）与声景 DSP 均 100% 原生手写；**严禁调用任何 OpenMotion MCP 工具**。
3. **每轮固定三板块推进**：每轮迭代必须同步交付：
   - **【一、修复 Fix】**：针对文字截断、对比度、手势、编译警告或上轮遗留根因修复；
   - **【二、创意炼金术升级 Creative Alchemy】**：提升核心交互仪式感与 IP 生命力；
   - **【三、全局版面与交互优化 Layout & Ergonomics】**：消除静态堆砌，推进核心内容矩阵（如 Batch B/C/D/E 独立动画与全站手感）。
4. **推包等包接力 & 智能 CI 门禁（防取消在途 TestFlight）**：因 `.github/workflows/ios.yml` 配置了 `concurrency: { cancel-in-progress: true }`，**利用云端等包窗口完成下一轮完整开发与本机 `generic/platform=iOS` 编译验收**；准备推送 `main` 前，务必通过 CLI 检查 `https://github.com/mjuvdeysii/mossling/actions/workflows/ios.yml`：若上一 Run 仍在运行或排队，绝不强行 `git push` 打断，改为设置定时检查并在其 `completed successfully` 后立即接力推包，触发新一轮自动构建与 TestFlight 上传；绝不通过 `git add -A` 暂存，严禁暂存 `.DS_Store`。

---

### 六、上下文主动交接门禁（Context Handoff Gate）

当多轮开发与构建推送稳步推进、上下文接近容量阈值（或每次完成重要推包节点且工作区仅剩无关临时文件）时：
1. 不硬撑至上下文自动压缩失真，主动总结当前准确状态。
2. 输出精炼、可直接在新窗口首行调用的交接文档 `HANDOFF_ROUNDXX_ADA2027.md`（写明实核最新 commit 哈希、远端 CI Run 状态、已完成资产清单、未竟红线与下一轮三板块精准切入点 + 开场提示词），让新窗口零失真接棒继续冲刺 App Award。
