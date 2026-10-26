# 摸索台灯 · 应用内付费研究（VAL-01–04）

状态：**研究，未批准**。本文件不授权收费、定价、App Store Connect 配置或任何工程实现；不改变 IP 计划 M0–M5 的顺序。核对日期 2026-10-26。

## 1. 结论

1. **现阶段不进入付费实现。** 代码中没有 StoreKit，也没有服务器；记录保存在本机（App Group 内的 JSON 文件）。这意味着目前没有持续发生的服务成本，可以收费的持续价值也没有经过验证。
2. **首要研究假设：免费核心 + 可选的一次性买断（非消耗型 In-App Purchase）。** 候选权益只限可选的美术与输出内容，例如成长册的印刷级导出或装帧模板、额外的插画与主题包。这类权益不需要服务器，也能用 Family Sharing 在家庭成员之间共享。
3. **订阅暂不作为方向。** 只有出现确有运营成本的服务时才重新评估，例如多人照护的同步或云备份；这需要先完成账户、儿童数据与隐私审核。App Review 对订阅的要求是提供持续的价值，下面第 3 节有原文出处。
4. **免费底线不变。** 以下内容永久免费：
   - 护理记录的查看、编辑、删除与导出
   - 安全提示与内容来源
   - 两位伙伴的全部陪伴
   
   伙伴不参与任何销售，也不以失望、缺席或倒计时促使购买。

## 2. 事实、估算与假设

| 类别 | 内容 | 依据 |
|---|---|---|
| 事实 | Small Business Program 佣金为 15%。参加条件是上一自然年和当年的收益（扣除佣金与部分税费之后）均不超过 100 万美元；新开发者可以加入；需要接受 Paid Apps 协议，并在 App Store Connect 申请加入 | Apple《App Store Small Business Program》页面 |
| 事实（二手转引 Apple） | 中国大陆店面自 2026-03-15 起：标准佣金 25%（原 30%）；Small Business Program 与 Mini Apps Partner Program 12%（原 15%）；自动续期订阅第二年起 12%（原 15%） | Apple Developer News 2026-03-12（原文链接本轮未能直接打开），经 MacTrast 全文引用、TechCrunch 报道 |
| 事实（App Review 原话，转引自开发者论坛） | 自动续期订阅的 App 内必须写明以下信息，App Store Connect 的元数据中也须有隐私政策与 EULA 链接：<br>• 订阅名称<br>• 订阅时长<br>• 价格<br>• 隐私政策与使用条款（EULA）的可用链接<br>扣款金额必须是付费页上最醒目的价格元素 | Apple Developer Forums thread 807082 中 App Review 的回复 |
| 待核对 | 审核指南 3.1.1（数字内容须使用 In-App Purchase，并提供恢复购买）与 3.1.2(a)（订阅须提供持续价值）的原文 | 本轮未能直接读取审核指南页面，上线前须对照原文核对 |
| 待核对 | 个人开发者账号在商店页面显示的销售方名称；中国大陆店面对非游戏类 App 内付费是否有额外资质要求 | 需查 Apple 支持文档，或向备案服务商确认 |
| 未核实观察 | 竞品「58 元内购」 | 产品、币种、周期、权益均不明，不作为定价锚点 |
| 估算 | 无 | 本文件不做市场规模、价格或收入估算 |

## 3. 候选模式比较（假设，待用户研究验证）

| 模式 | 适合的前提 | 对摸索台灯的判断 |
|---|---|---|
| A 完全免费 | 维护成本低，以口碑和成熟度优先 | 当前状态。持续成本主要是开发者本人的时间 |
| B 一次性买断 | 权益明确、边际成本低、可以恢复购买 | **首要研究方向**。权益必须是可选的美术或输出，不涉及育儿能力 |
| C 订阅 | 有持续交付的服务与成本 | 当前不成立：没有服务器，也没有持续更新的付费内容 |
| D 混合 | 免费核心，加买断，加未来的服务订阅 | 等 B 被验证之后，再随同步类功能评估 |

## 4. 研究包与验收标准

| 编号 | 内容 | 验收标准（达到后才进入下一项） |
|---|---|---|
| VAL-01 竞品核查 | 每个样本都记录以下项目，并标注证据等级 A–D：<br>• 产品、平台与店面区域<br>• 版本与收集日期<br>• 免费与付费权益表<br>• 标价与周期<br>• 是否自动续费<br>• 恢复购买的路径 | 至少覆盖 3 个同类场景，每项都有截图或链接；C、D 级证据不写成事实 |
| VAL-02 用户价值 | 访谈三类家长（日间探索、夜间记录、长期回顾），追问最近一次的真实行为；做任务观察 | 至少找出一个可以归因于摸索台灯的明确价值，并有真实样本记录 |
| VAL-03 权益与成本 | 定义候选付费权益与免费底线，估计维护时间与服务成本，写明恢复购买和退款的处理 | 权益与免费功能边界清楚，不影响记录与安全信息；成本假设写明来源 |
| VAL-04 合规与体验 | 完成以下审查：<br>• 对照审核指南 3.1 原文<br>• 隐私说明（含 App 隐私标签）<br>• 中国大陆店面与备案<br>• 付费页文案<br>测试购买、取消、恢复、中断与离线等路径 | 在 StoreKit 测试环境和 TestFlight 沙盒中各路径通过，有录屏为证 |

## 5. 需要产品负责人决定的事项

1. 是否启动 VAL-01、VAL-02（只做研究，不改代码）。
2. 免费底线（第 1 节第 4 条）是否作为长期承诺写入隐私政策或条款。
3. 首次上架是否保持完全免费。保持免费不影响以后再加入买断。

## 来源

- [App Store Small Business Program（Apple）](https://developer.apple.com/app-store/small-business-program/?page=2)
- [Apple Developer News：中国大陆佣金调整](https://developer.apple.com/news/?id=dadukodv)（本轮未能直接打开，内容来自下列转引）
- [MacTrast：Apple to Reduce Developer Fees in Chinese App Store As of Sunday, March 15](https://www.mactrast.com/2026/03/apple-to-reduce-developer-fees-in-chinese-app-store-as-of-sunday-march-15/)
- [TechCrunch：Apple drops commission rates in China](https://techcrunch.com/2026/03/13/apple-drops-commission-rates-in-china-25-percent/)
- [Apple Developer Forums：Guideline 3.1.2 - Business - Payments - Subscriptions](https://developer.apple.com/forums/thread/807082)
- App Review Guidelines：https://developer.apple.com/app-store/review/guidelines/（待直接核对 3.1.1、3.1.2）
