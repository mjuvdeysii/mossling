import Foundation

/// Gentle three-state observation status replacing pass/fail checkboxes on developmental items.
enum ObservationState: String, Codable, CaseIterable, Sendable {
    case notYet
    case observed
    case askDoctor

    var label: String {
        switch self {
        case .notYet: L10n.t("正在摸索中", "Exploring")
        case .observed: L10n.t("亮起来了", "Observed")
        case .askDoctor: L10n.t("留给医生看看", "Ask Doctor")
        }
    }

    var symbol: String {
        switch self {
        case .notYet: "sparkle"
        case .observed: "checkmark.circle.fill"
        case .askDoctor: "stethoscope"
        }
    }
}

/// Six WHO Multicentre Growth Reference Study (MGRS 2006) gross motor healthy windows (1st–99th percentile).
struct WHOMotorWindow: Identifiable, Equatable, Sendable {
    let id: String
    let titleZh: String
    let titleEn: String
    let startMonth: Double
    let endMonth: Double
    let cdcBenchmarkMonth: Double?
    let noteZh: String
    let noteEn: String
    let variableOrder: Bool

    var title: String { L10n.t(titleZh, titleEn) }
    var note: String { L10n.t(noteZh, noteEn) }
    var spanMonths: Double { endMonth - startMonth }

    static let clinicalLineMonth: Double = 18.0

    static let all: [WHOMotorWindow] = [
        WHOMotorWindow(
            id: "sit",
            titleZh: "独坐（无支撑）",
            titleEn: "Sitting without support",
            startMonth: 3.8,
            endMonth: 9.2,
            cdcBenchmarkMonth: 9.0,
            noteZh: "跨度 5.4 个月 · CDC 9m 75% 监测节点",
            noteEn: "5.4-mo span · CDC 9m 75% check-in",
            variableOrder: false
        ),
        WHOMotorWindow(
            id: "standAssist",
            titleZh: "扶站（借助支撑物）",
            titleEn: "Standing with assistance",
            startMonth: 4.8,
            endMonth: 11.4,
            cdcBenchmarkMonth: 12.0,
            noteZh: "跨度 6.6 个月 · CDC 12m 扶物拉站",
            noteEn: "6.6-mo span · CDC 12m pull-to-stand",
            variableOrder: false
        ),
        WHOMotorWindow(
            id: "crawl",
            titleZh: "手膝爬行（顺序可变）",
            titleEn: "Hands-and-knees crawling",
            startMonth: 5.2,
            endMonth: 13.5,
            cdcBenchmarkMonth: nil,
            noteZh: "约 4.3% 健康婴儿直接跳过 · CDC 未列为必达项",
            noteEn: "~4.3% of healthy babies skip crawling",
            variableOrder: true
        ),
        WHOMotorWindow(
            id: "walkAssist",
            titleZh: "扶走（扶家具巡航）",
            titleEn: "Walking with assistance",
            startMonth: 5.9,
            endMonth: 13.7,
            cdcBenchmarkMonth: 12.0,
            noteZh: "跨度 7.8 个月 · CDC 12m 扶家具巡航",
            noteEn: "7.8-mo span · CDC 12m cruising",
            variableOrder: false
        ),
        WHOMotorWindow(
            id: "standAlone",
            titleZh: "独站",
            titleEn: "Standing alone",
            startMonth: 6.9,
            endMonth: 16.9,
            cdcBenchmarkMonth: nil,
            noteZh: "跨度最宽达 10.0 个月 · 个体差异显著",
            noteEn: "Widest 10.0-mo healthy span",
            variableOrder: false
        ),
        WHOMotorWindow(
            id: "walkAlone",
            titleZh: "独走",
            titleEn: "Walking alone",
            startMonth: 8.2,
            endMonth: 17.6,
            cdcBenchmarkMonth: 18.0,
            noteZh: "跨度 9.4 个月 · 18m 未独走建议儿保评估",
            noteEn: "9.4-mo span · evaluate if not walking by 18m",
            variableOrder: false
        )
    ]
}

enum EvidenceTier: String, Codable, CaseIterable, Sendable {
    case clinicalGuideline
    case expertConsensus
    case developmentalResearch
    case pedagogicalPhilosophy

    var label: String {
        switch self {
        case .clinicalGuideline: L10n.t("临床指南与常模", "Clinical Guideline")
        case .expertConsensus: L10n.t("儿科专家共识", "Expert Consensus")
        case .developmentalResearch: L10n.t("发展心理学实证", "Developmental Research")
        case .pedagogicalPhilosophy: L10n.t("养育实践建议", "Caregiving Practice")
        }
    }
}

struct EvidenceSourceRef: Equatable, Hashable, Sendable {
    let org: String
    let docZh: String
    let docEn: String
    let year: String

    var title: String { "\(org) · \(L10n.t(docZh, docEn)) (\(year))" }
}

struct EvidenceMeta: Equatable, Sendable {
    let tiers: [EvidenceTier]
    let sources: [EvidenceSourceRef]
    let limitationZh: String
    let limitationEn: String
    let reviewLabel: String

    var limitation: String { L10n.t(limitationZh, limitationEn) }
}

/// Three-layer progressive disclosure card (L1 Immediate Intuition -> L2 Empathy & Translation -> L3 Clinical Evidence).
struct LampCard: Identifiable, Sendable {
    let id: String
    let stageIndex: Int   // 0..8 matching the 9 stages (0-3m .. 30-36m)
    let minMonth: Int
    let maxMonth: Int
    let stageTitleZh: String
    let stageTitleEn: String
    let headlineZh: String
    let headlineEn: String
    let sayAloudZh: String
    let sayAloudEn: String
    let microActionZh: String
    let microActionEn: String
    let translationZh: String
    let translationEn: String
    let grandparentNoteZh: String
    let grandparentNoteEn: String
    let clinicalTerms: [String]
    let redFlagZh: String
    let redFlagEn: String
    let meta: EvidenceMeta

    var stageTitle: String { L10n.t(stageTitleZh, stageTitleEn) }
    var headline: String { L10n.t(headlineZh, headlineEn) }
    var sayAloud: String { L10n.t(sayAloudZh, sayAloudEn) }
    var microAction: String { L10n.t(microActionZh, microActionEn) }
    var translation: String { L10n.t(translationZh, translationEn) }
    var grandparentNote: String { L10n.t(grandparentNoteZh, grandparentNoteEn) }
    var redFlag: String { L10n.t(redFlagZh, redFlagEn) }

    /// Plain-text shareable summary for WeChat / Messages without needing an app install.
    func shareMessage() -> String {
        """
        【摸索台灯 · \(stageTitle)】\(headline)
        可以这样说：“\(sayAloud)”
        手边微动作：\(microAction)
        写给家人：\(grandparentNote)
        依据：\(meta.sources.map(\.title).joined(separator: "；"))
        """
    }
}

/// Curated 9-stage bilingual catalog covering 0–36 months (rejecting irreproducible Wonder Weeks claims).
enum LampCardCatalog {
    static func cards(forMonth month: Int) -> [LampCard] {
        let m = max(0, min(36, month))
        let matches = all.filter { m >= $0.minMonth && m <= $0.maxMonth }
        return matches.isEmpty ? Array(all.suffix(2)) : matches
    }

    static func spotlight(forMonth month: Int, day: Day) -> LampCard {
        let pool = cards(forMonth: month)
        return pool[abs(day.epochDay) % pool.count]
    }

    static let all: [LampCard] = [
        // Stage 0: 0–3m
        LampCard(
            id: "0_3m_tummy", stageIndex: 0, minMonth: 0, maxMonth: 2,
            stageTitleZh: "0–3 月 · 感官初醒", stageTitleEn: "0–3m · First Trust",
            headlineZh: "一放地板趴着就哭？趴在大人胸口同样算数",
            headlineEn: "Crying on the floor? Chest tummy-time counts just the same",
            sayAloudZh: "宝宝正在练力气，妈妈贴着你一起慢慢撑一分钟。",
            sayAloudEn: "You are building strength, right here on my chest for one calm minute.",
            microActionZh: "大人半躺，让宝宝趴在胸口感受心跳，清醒时每次 2–5 分钟零存整取。",
            microActionEn: "Recline and rest baby belly-down on your chest for 2–5 calm minutes while awake.",
            translationZh: "对新生儿而言地板趴卧相当于高强度平板支撑。胸口趴、横抱飞机抱都会平稳锻炼头颈背肌，不需强迫硬撑。",
            translationEn: "Flat-floor tummy time is intense core work for a newborn; chest-to-chest reclines build neck strength calmly.",
            grandparentNoteZh: "每次趴一两分钟、一天凑几次就好，哭累了随时抱起歇歇，不用硬趴到哭。",
            grandparentNoteEn: "Short 1–2 minute sessions added up across the day work better than pushing through tears.",
            clinicalTerms: ["Tummy Time Gradient", "Early Neck Control", "Core Attachment"],
            redFlagZh: "满 2–3 月龄对巨大声响无反应、满 3 月龄仍无社交微笑或目光不追视请咨询儿保。",
            redFlagEn: "Consult pediatrics if no startle/response to loud sounds or no social smile/tracking by 3 months.",
            meta: EvidenceMeta(
                tiers: [.clinicalGuideline, .pedagogicalPhilosophy],
                sources: [
                    EvidenceSourceRef(org: "AAP / Pathways", docZh: "俯卧时间分月龄指南", docEn: "Tummy Time Gradient Guide", year: "2024"),
                    EvidenceSourceRef(org: "CDC", docZh: "2月龄发育里程碑 (75%)", docEn: "2-Month Milestones (75%)", year: "2022")
                ],
                limitationZh: "本条为日常陪伴参考，若出现明显肌张力过软或偏头严重请由儿保医生评估。",
                limitationEn: "For daily care guidance; consult your pediatrician for persistent floppiness or head preference.",
                reviewLabel: "CDC 2022 · AAP"
            )
        ),
        LampCard(
            id: "0_3m_trust", stageIndex: 0, minMonth: 0, maxMonth: 2,
            stageTitleZh: "0–3 月 · 感官初醒", stageTitleEn: "0–3m · First Trust",
            headlineZh: "前三个月没有“抱惯”，每次抱起都在筑底气",
            headlineEn: "You cannot spoil a newborn—every pickup builds safety",
            sayAloudZh: "我听到你啦，这就抱抱你，现在安全了。",
            sayAloudEn: "I hear you. Here I am—you are safe right now.",
            microActionZh: "换尿布前看着眼睛轻声预告“妈妈要解开扣子啦”，停一秒等他踢腿再动手。",
            microActionEn: "Make eye contact and narrate before undoing a diaper; pause one second for a reply kick.",
            translationZh: "小月龄哭闹是唯一的求助信号。大人稳定回应帮大脑搭起“世界安全可信”的基底，长大了反而更敢独立探索。",
            translationEn: "Early crying is pure communication. Reliable warmth wires stress-regulation and future confidence.",
            grandparentNoteZh: "前三个月怎么抱都不会娇气；实在抱到大人撑不住时，先把宝宝仰卧放进空婴儿床，深呼吸五分钟再来。",
            grandparentNoteEn: "Holding early creates trust. If overwhelmed, lay baby safely on their back and take 5 minutes.",
            clinicalTerms: ["Basic Trust", "Serve & Return Step 1", "RIE Slow Diaper Care"],
            redFlagZh: "持续尖锐不可安抚哭闹伴拒奶、发热（<3个月体温>=38C）或精神萎靡须立即就医。",
            redFlagEn: "Seek prompt care for inconsolable crying with poor feeding, lethargy, or fever >=38C under 3 months.",
            meta: EvidenceMeta(
                tiers: [.clinicalGuideline, .developmentalResearch],
                sources: [
                    EvidenceSourceRef(org: "CDC / NHC", docZh: "3岁以下婴幼儿照护指南", docEn: "Infant Care & Trust Guidance", year: "2022"),
                    EvidenceSourceRef(org: "RIE", docZh: "尊重照护基础原则", docEn: "Basic RIE Educaring Principles", year: "2024")
                ],
                limitationZh: "哭闹骤变时首先排查胀气、发热与裹被过热等生理原因。",
                limitationEn: "Always rule out fever, discomfort, or overheating when crying changes abruptly.",
                reviewLabel: "CDC · NHC · RIE"
            )
        ),
        // Stage 1: 3–6m
        LampCard(
            id: "3_6m_roll", stageIndex: 1, minMonth: 3, maxMonth: 5,
            stageTitleZh: "3–6 月 · 掌控身体", stageTitleEn: "3–6m · Body & Voice",
            headlineZh: "4 个月还没翻身很正常，CDC 已把基准放到 6 个月",
            headlineEn: "Not rolling at 4m is normal—the 75% benchmark sits at 6 months",
            sayAloudZh: "手手伸到侧面够那个大木勺，身体自己扭一扭哦。",
            sayAloudEn: "Reach toward the wooden spoon on the side—feel your core twist!",
            microActionZh: "把干净大木勺放在宝宝斜前方伸手差一点的地方，鼓励自己侧身发力，不代劳帮翻。",
            microActionEn: "Place a large wooden spoon just past side reach on a firm mat; let baby initiate the twist.",
            translationZh: "CDC 2022 将旧版基于半数的 4m 翻身标尺调至 6m 75% 基准。只要清醒时抬头、踢腿有劲、伸手抓物即可。",
            translationEn: "CDC 2022 moved tummy-to-back rolling to the 6m (75%) list to curb unnecessary parent panic.",
            grandparentNoteZh: "少久坐学步椅、多放平坦地垫自由蹬腿，核心力量攒够了翻身自然水到渠成。",
            grandparentNoteEn: "Floor mat freedom builds core strength far faster than propping in seats.",
            clinicalTerms: ["CDC 75% Revision", "Midline Grasp", "Independent Initiation"],
            redFlagZh: "满 6 月龄仍不能抬头、不会伸手抓物、发音极少、不笑出声或双侧明显不对称需儿保评估。",
            redFlagEn: "Check with pediatrics if not reaching/grasping, rarely vocalizing, or showing strong asymmetry by 6m.",
            meta: EvidenceMeta(
                tiers: [.clinicalGuideline, .expertConsensus],
                sources: [
                    EvidenceSourceRef(org: "Pediatrics (Zubler)", docZh: "CDC 发育里程碑修订解读", docEn: "Evidence-Informed Milestones Revision", year: "2022"),
                    EvidenceSourceRef(org: "NHC", docZh: "6月龄儿童健康检查", docEn: "6-Month Well-Child Check", year: "2022")
                ],
                limitationZh: "早产儿应按矫正月龄对照，但若双侧肌力明显不对称不受月龄限制。",
                limitationEn: "Apply preterm corrected age for rolling timelines, though marked asymmetry always warrants review.",
                reviewLabel: "CDC 2022 · Zubler"
            )
        ),
        LampCard(
            id: "3_6m_babble", stageIndex: 1, minMonth: 3, maxMonth: 5,
            stageTitleZh: "3–6 月 · 掌控身体", stageTitleEn: "3–6m · Body & Voice",
            headlineZh: "什么都往嘴里塞：口腔是他最精密的触觉实验室",
            headlineEn: "Everything goes in the mouth—his most sensitive tactile lab",
            sayAloudZh: "这个硅胶勺凉凉滑滑的，你尝出它的形状了吗？",
            sayAloudEn: "Ooh, this spoon feels cool and smooth—you are checking how it feels!",
            microActionZh: "宝宝吹泡泡发元音后你夸张模仿并停顿 3–5 秒，把下一轮“发球权”留给他。",
            microActionEn: "Echo baby's vowel sounds warmly, then pause 3–5 quiet seconds for their turn.",
            translationZh: "四五个月口腔神经末梢密度高于手指，咬玩具正是测绘软硬冷暖的认知过程，顺便也减了大人的尿布记账心事。",
            translationEn: "Oral exploration maps texture and temperature while Serve-and-Return vocal turns wire early language.",
            grandparentNoteZh: "只要确认抓在手里的东西大于防呛标准（塞不进卫生纸筒芯）且干净无尖角，放心让他啃一会儿。",
            grandparentNoteEn: "If larger than a choking cylinder and clean without sharp edges, mouthing is safe learning.",
            clinicalTerms: ["Oral Sensory Exploration", "Serve & Return Turns", "Vowel Cooing"],
            redFlagZh: "6 月龄对熟悉人脸与呼唤几乎无反应或从不发元音互动需安排听力与发育检查。",
            redFlagEn: "Seek hearing/developmental evaluation if little response to faces or voices by 6 months.",
            meta: EvidenceMeta(
                tiers: [.developmentalResearch, .clinicalGuideline],
                sources: [
                    EvidenceSourceRef(org: "Harvard CDC", docZh: "发球与回球五步互动法", docEn: "Serve and Return 5 Steps", year: "2023"),
                    EvidenceSourceRef(org: "CDC", docZh: "4–6月龄里程碑清单", docEn: "4–6 Month Milestones", year: "2022")
                ],
                limitationZh: "严防直径小于 3.17 cm 的细小部件入口。",
                limitationEn: "Always keep small objects capable of fitting inside a toilet-paper roll out of reach.",
                reviewLabel: "Harvard · CDC 2022"
            )
        ),
        // Stage 2: 6–9m
        LampCard(
            id: "6_9m_spoon", stageIndex: 2, minMonth: 6, maxMonth: 8,
            stageTitleZh: "6–9 月 · 坐稳探索", stageTitleEn: "6–9m · Solids & Sit",
            headlineZh: "反复把勺子扔下餐椅？这是他的第一场重力实验",
            headlineEn: "Dropping the spoon again? Welcome to his first physics lab",
            sayAloudZh: "勺子掉下去，咣当！我把它捡起来啦，再试一次。",
            sayAloudEn: "Down went the spoon—clink! Back up it comes to the tray.",
            microActionZh: "给一只安全木勺与不锈钢碗，一边命名动作一边稳稳捡回 3 次，随后温柔收起结束游戏。",
            microActionEn: "Name the fall calmly 3 rounds ('spoon down!'), then gently pivot to the meal when finished.",
            translationZh: "宝宝并非故意捣乱，而是在反复验证“离开视野的物体还在（客体永存）”和松手下坠的因果规律。",
            translationEn: "Repeated dropping tests object permanence and cause-and-effect rather than defiance.",
            grandparentNoteZh: "1 岁前奶仍是主粮，辅食重点是尝味道和抓握质感，掉地上大半不是没吃饱。",
            grandparentNoteEn: "Before 12 months, milk stays foundational; messy solids build oral-motor confidence.",
            clinicalTerms: ["Object Permanence", "Cause & Effect", "Division of Responsibility"],
            redFlagZh: "满 9 月龄仍不能无支撑独坐（触及 WHO 9.2m 上限）、叫名无反应或持续进食呛咳请咨询儿保。",
            redFlagEn: "Consult pediatrics if unable to sit unsupported at 9m (WHO 9.2m upper bound) or frequently choking.",
            meta: EvidenceMeta(
                tiers: [.clinicalGuideline, .developmentalResearch],
                sources: [
                    EvidenceSourceRef(org: "WHO MGRS", docZh: "粗大运动成就窗口研究", docEn: "WHO Motor Windows Study", year: "2006"),
                    EvidenceSourceRef(org: "CDC", docZh: "9月龄发育里程碑", docEn: "9-Month Milestones", year: "2022")
                ],
                limitationZh: "若喂食时反复剧烈呛咳或拒绝一切泥糊质感，建议及早由儿保/言语治疗师评估。",
                limitationEn: "Seek feeding support promptly if gagging/coughing persists across all purees.",
                reviewLabel: "WHO · CDC 2022"
            )
        ),
        LampCard(
            id: "6_9m_stranger", stageIndex: 2, minMonth: 6, maxMonth: 8,
            stageTitleZh: "6–9 月 · 坐稳探索", stageTitleEn: "6–9m · Solids & Sit",
            headlineZh: "突然黏人又认生？说明他的依恋与记忆升级了",
            headlineEn: "Sudden stranger wariness means attachment just leveled up",
            sayAloudZh: "妈妈只去倒杯水，马上就回来，不用慌。",
            sayAloudEn: "I am just getting a glass of water—I will come right back.",
            microActionZh: "即使短时离开视线也微笑告别，回来大声宣布“我回来啦”，绝不趁机偷偷溜走。",
            microActionEn: "Give a calm, visible goodbye and joyful return every time—never sneak out unnoticed.",
            translationZh: "7–9 月龄能清晰分辨熟人与生人、记得你“走开了却看不见”。被他推开外人恰恰证明你给了他最扎实的依靠。",
            translationEn: "Clinginess reflects sharper face memory and secure attachment—not shyness or regression.",
            grandparentNoteZh: "别强行从妈妈怀里抢抱过去，先让宝宝在熟悉的怀抱里观察客人几分钟，通常自己就探头笑了。",
            grandparentNoteEn: "Let baby observe guests safely from a trusted arm first rather than forcing immediate handoffs.",
            clinicalTerms: ["Stranger Wariness", "Secure Attachment", "Predictable Separation"],
            redFlagZh: "8–9 月龄全无“mamamama/bababa”等含辅音咿呀音、或不随声转头寻声应排查听力。",
            redFlagEn: "Check hearing and development if no consonant babbling (b/m/d) or name turning by 9 months.",
            meta: EvidenceMeta(
                tiers: [.clinicalGuideline, .developmentalResearch],
                sources: [
                    EvidenceSourceRef(org: "CDC", docZh: "9月龄社交情绪清单", docEn: "9-Month Social-Emotional List", year: "2022"),
                    EvidenceSourceRef(org: "Zero to Three", docZh: "早期依恋与分离焦虑", docEn: "Understanding Separation", year: "2024")
                ],
                limitationZh: "分离安慰困难若持续伴随眼神零接触或互动丧失，请记录观察片段带去随访。",
                limitationEn: "Note any persistent loss of eye contact alongside separation distress for your well-child visit.",
                reviewLabel: "CDC 2022 · ZTT"
            )
        ),
        // Stage 3: 9–12m
        LampCard(
            id: "9_12m_cruising", stageIndex: 3, minMonth: 9, maxMonth: 11,
            stageTitleZh: "9–12 月 · 自由移动", stageTitleEn: "9–12m · Moving & Pointing",
            headlineZh: "快 1 岁还不会独立走？健康独走窗口一直宽到 17.6 个月",
            headlineEn: "Not walking at one? Healthy walking spans up to 17.6 months",
            sayAloudZh: "光脚踩在防滑垫上扶着沙发挪一挪，稳稳的。",
            sayAloudEn: "Bare feet on the rug, hands on the sofa—take your time side-stepping.",
            microActionZh: "拆掉学步车束缚，在防滑地垫让宝宝光脚扶稳矮沙发左右巡航（Cruising），尽量不弯腰架着腋下拖着走。",
            microActionEn: "Skip baby walkers; let barefoot baby cruise sturdy low furniture without holding arms overhead.",
            translationZh: "WHO 多中心跟踪证实独走健康窗口跨越 8.2–17.6 个月（宽 9.4 个月）；1 岁会扶物巡航已稳居 CDC 75% 基准线之内。",
            translationEn: "WHO tracked healthy unsupported walking from 8.2 to 17.6 months. Barefoot cruising builds real balance.",
            grandparentNoteZh: "架着腋下领着走反而打乱重心校准；约 4.3% 健康宝宝还会直接跳过四肢爬直接站走，不必硬逼着爬。",
            grandparentNoteEn: "Holding arms aloft delays balance calibration; ~4.3% of healthy babies even skip crawling altogether.",
            clinicalTerms: ["WHO Walk Window", "Barefoot Cruising", "RIE Unassisted Motor"],
            redFlagZh: "12 月龄尚不能扶物拉起站立、或持续单侧脚尖拖行/明显肌张力偏低请尽快评估。",
            redFlagEn: "Consult pediatrics if unable to pull to stand with support or showing persistent asymmetry at 12m.",
            meta: EvidenceMeta(
                tiers: [.clinicalGuideline, .pedagogicalPhilosophy],
                sources: [
                    EvidenceSourceRef(org: "WHO MGRS", docZh: "独走与扶走发育窗口", docEn: "WHO Walking Windows Study", year: "2006"),
                    EvidenceSourceRef(org: "CDC / RIE", docZh: "12月龄运动与自主探索", docEn: "12-Month Milestones & RIE", year: "2022")
                ],
                limitationZh: "确保茶几桌角加防撞护角、稳固重型电视柜防止拉站倾倒。",
                limitationEn: "Anchor heavy furniture and pad sharp corners as pulling-to-stand begins.",
                reviewLabel: "WHO · CDC 2022 · RIE"
            )
        ),
        LampCard(
            id: "9_12m_yesspace", stageIndex: 3, minMonth: 9, maxMonth: 11,
            stageTitleZh: "9–12 月 · 自由移动", stageTitleEn: "9–12m · Moving & Pointing",
            headlineZh: "别总用喊“不行”对抗好奇，留一个安全的专属底层抽屉",
            headlineEn: "Replace nonstop 'No!' with one safe bottom drawer just for them",
            sayAloudZh: "厨房大抽屉只摸上面，下面这个是宝宝的百宝盒，硅胶铲子随便拿！",
            sayAloudEn: "This bottom drawer is all yours—wooden spoons and lids ready to explore!",
            microActionZh: "把危险品和药箱锁高收好，把客厅/厨房最低一层设为“全允许区 Yes Space”，放锅盖、棉袜和硅胶勺。",
            microActionEn: "Lock hazards high and dedicate one lowest drawer as a safe Yes Space full of lids and soft cloths.",
            translationZh: "9–12 月手指向物分享与翻找欲井喷，但自控力尚为零。划出“能摸区”能瞬间减少 80% 徒劳拉扯，大人也能省心看着微笑。",
            translationEn: "Curiosity and pointing soar while impulse control is near zero; a Yes Space saves constant conflict.",
            grandparentNoteZh: "同时看到他用手指点东西时，顺着他手看过去大声念出名字（“那是风扇！对，蓝杯子！”），是最管用的说话启蒙。",
            grandparentNoteEn: "When baby points, look where their finger aims and name the object—it supercharges early words.",
            clinicalTerms: ["Joint Attention", "Proto-declarative Pointing", "RIE Yes Space"],
            redFlagZh: "12 月龄没有任何沟通手势（不挥手、不手指指物、不伸手求抱）或叫名全无反应需做专业评估。",
            redFlagEn: "Evaluate promptly if zero communicative gestures (waving, pointing, reaching) or no response to name at 12m.",
            meta: EvidenceMeta(
                tiers: [.developmentalResearch, .pedagogicalPhilosophy],
                sources: [
                    EvidenceSourceRef(org: "CDC", docZh: "12月龄沟通里程碑", docEn: "12-Month Communication", year: "2022"),
                    EvidenceSourceRef(org: "Harvard CDC", docZh: "共同注意与命名回应", docEn: "Serve & Return Naming", year: "2023")
                ],
                limitationZh: "电器插座与长垂电源线仍须物理遮挡，不可只靠口头制止。",
                limitationEn: "Cover outlets and tuck hanging cords physically; verbal cues alone cannot keep a 1-year-old safe.",
                reviewLabel: "CDC 2022 · Harvard"
            )
        ),
        // Stage 4: 12–15m
        LampCard(
            id: "12_15m_tantrum", stageIndex: 4, minMonth: 12, maxMonth: 14,
            stageTitleZh: "12–15 月 · 迈步独立", stageTitleEn: "12–15m · First Steps",
            headlineZh: "第一次为小事躺地崩哭？他想说的比嘴里能说的快太多",
            headlineEn: "First floor-meltdown? Their ideas outrun their words",
            sayAloudZh: "拿不到那个红球你好着急啊，妈妈就坐在这里陪着你。",
            sayAloudEn: "You really wanted that red ball right now—I am sitting right here with you.",
            microActionZh: "情绪风暴高峰不讲长道理，先用 1 句话接住感受并确保四周安全，稳稳蹲在一旁等浪退去。",
            microActionEn: "Skip long lectures during peak tears: name the feeling once, keep the floor safe, and wait calmly.",
            translationZh: "15 个月是独立意愿大爆发却只有几个词的落差期；饿、困并觉时尤为明显。稳稳旁观不是冷漠，而是帮他借用大人的平稳神经网络。",
            translationEn: "Independence surges far ahead of 15-month vocabulary. Your steady presence acts as external emotional regulation.",
            grandparentNoteZh: "这时别急着用糖果或手机堵嘴，也别训斥“这么点事哭什么”，哭潮 2 分钟过去后递个抱抱最管用。",
            grandparentNoteEn: "Avoid bribing with screens or shaming tears; once the 2-minute wave crests, offer a quiet hug.",
            clinicalTerms: ["External Co-Regulation", "15-Month Tantrum Surge", "Nap Transition Window"],
            redFlagZh: "15 月龄从未用手指物求助或展示、不看大人所指物体、或出现任何已掌握语言/社交技能倒退请及时就医。",
            redFlagEn: "Consult pediatrics if never pointing to request/show or any regression in words or engagement at 15m.",
            meta: EvidenceMeta(
                tiers: [.clinicalGuideline, .developmentalResearch],
                sources: [
                    EvidenceSourceRef(org: "CDC", docZh: "15月龄新增发育清单", docEn: "15-Month Milestone Checklist", year: "2022"),
                    EvidenceSourceRef(org: "AAP", docZh: "15月龄儿保预见性指导", docEn: "AAP 15-Month Well Visit", year: "2024")
                ],
                limitationZh: "并觉期常伴黄昏提前困倦崩溃，适度前移傍晚小睡或提前半小时入睡能显著减少发作。",
                limitationEn: "During 2-to-1 nap transitions, an earlier bedtime noticeably prevents late-afternoon meltdowns.",
                reviewLabel: "CDC 2022 · AAP"
            )
        ),
        LampCard(
            id: "12_15m_feeding", stageIndex: 4, minMonth: 12, maxMonth: 14,
            stageTitleZh: "12–15 月 · 迈步独立", stageTitleEn: "12–15m · First Steps",
            headlineZh: "满周岁饭量忽然只吃三口？生长增速天然变慢了",
            headlineEn: "Eating just three bites after birthday? Growth rate naturally slows",
            sayAloudZh: "你摇摇头是不吃西兰花啦，盘子收好，我们下顿再尝。",
            sayAloudEn: "Looks like broccoli is all done—let us clear the bowl cleanly until next snack.",
            microActionZh: "践行「餐桌分工」：大人定食材与时间，宝宝决定吃不吃与吃多少；让宝宝顺手帮拿鞋子、把脏袜子扔进篮子。",
            microActionEn: "Adults choose safe menu and mealtime; toddler chooses how much. Invite tiny chores like fetching shoes.",
            translationZh: "婴儿第一年体重翻三倍，第二年全年仅增重约 2–3 公斤，胃口自然波动；停止追着喂反而保住内在饥饱信号。",
            translationEn: "Birth-to-one weight triples, whereas year two slows markedly. Dropping pressure-feeding protects appetite cues.",
            grandparentNoteZh: "满岁后可以把小袜子放洗衣篮、递纸巾当作游戏，比手里捧着饭碗满屋追着跑开心得多。",
            grandparentNoteEn: "Trading spoon-chasing for tiny helpful chores turns toddlers into willing mealtime participants.",
            clinicalTerms: ["Normal Toddler Growth Deceleration", "Montessori Practical Life", "Cup Transition"],
            redFlagZh: "15 月龄完全无法独立或扶物站稳、或生长曲线连续掉出原有两条主百分位线须请儿保评估。",
            redFlagEn: "Check with pediatrics if zero standing weight-bearing at 15m or weight drops across two major percentiles.",
            meta: EvidenceMeta(
                tiers: [.clinicalGuideline, .pedagogicalPhilosophy],
                sources: [
                    EvidenceSourceRef(org: "AAP Bright Futures", docZh: "周岁后喂养分工指导", docEn: "Bright Futures Feeding Roles", year: "2023"),
                    EvidenceSourceRef(org: "Montessori", docZh: "12–18月龄实践生活启蒙", docEn: "Toddler Practical Life", year: "2023")
                ],
                limitationZh: "若伴反复呕吐、苍白乏力或长期只接受单一质感，需排查铁缺乏与吞咽障碍。",
                limitationEn: "Evaluate persistent gagging, extreme texture refusal, or pallor for iron deficiency or feeding needs.",
                reviewLabel: "AAP · Montessori"
            )
        ),
        // Stage 5: 15–18m
        LampCard(
            id: "15_18m_order", stageIndex: 5, minMonth: 15, maxMonth: 17,
            stageTitleZh: "15–18 月 · 秩序与独立", stageTitleEn: "15–18m · Order & Agency",
            headlineZh: "椅子挪位或碗色不对就崩溃？蒙氏“秩序敏感期”正在画地图",
            headlineEn: "Meltdown over a moved chair? Sensitive Period for Order is mapping safety",
            sayAloudZh: "你记得小板凳一直靠在门边呀，今天变位置让你很不习惯。",
            sayAloudEn: "You remembered the stool belongs right beside the door—changes feel big right now.",
            microActionZh: "穿衣或选水果时改用「受限二选一」：“今天穿红袜子还是蓝袜子？”并提前 1 句预告小变动。",
            microActionEn: "Offer two acceptable choices ('red socks or blue socks?') and give a calm heads-up before changes.",
            translationZh: "尚无时钟概念的幼儿靠环境物品位置与流程顺序预测世界。“顺着小秩序 + 受限二选一”比硬碰硬省下大半眼泪。",
            translationEn: "Without clock sense, fixed objects and routines act as a toddler's predictability map.",
            grandparentNoteZh: "这不是小孩子“拧巴找茬”，顺手把鞋摆整齐再一起出门，全家情绪都能温和很多。",
            grandparentNoteEn: "Honoring harmless small routines keeps peace far better than forcing compliance.",
            clinicalTerms: ["Sensitive Period for Order", "Limited Choices", "Anticipatory Guidance"],
            redFlagZh: "18 月龄需做常规发育与 ASD 专项筛查；如全无分享式指点、叫名不回或 18m 仍不能独走务必就医。",
            redFlagEn: "Complete standard 18m developmental & ASD screening; evaluate absent pointing, name response, or walking.",
            meta: EvidenceMeta(
                tiers: [.pedagogicalPhilosophy, .clinicalGuideline],
                sources: [
                    EvidenceSourceRef(org: "CDC / CHAT-23", docZh: "18月龄发育与沟通筛查指南", docEn: "18-Month Screening Guidance", year: "2022"),
                    EvidenceSourceRef(org: "Montessori / ZTT", docZh: "幼儿秩序敏感期", docEn: "Sensitive Period for Order", year: "2023")
                ],
                limitationZh: "区分常见短暂秩序坚持与“伴随零眼神交流、无分享指点的持续刻板行为”。",
                limitationEn: "Distinguish common routine preference from rigid distress paired with absent social gaze or pointing.",
                reviewLabel: "CDC · CHAT-23 · NHC"
            )
        ),
        LampCard(
            id: "15_18m_potty", stageIndex: 5, minMonth: 15, maxMonth: 17,
            stageTitleZh: "15–18 月 · 秩序与独立", stageTitleEn: "15–18m · Order & Agency",
            headlineZh: "别在 1 岁半强迫“把尿”，大多数孩子 2–3 岁才生理就绪",
            headlineEn: "Skip forced early potty training—true readiness arrives around 2–3 years",
            sayAloudZh: "宝宝尿尿啦，纸尿裤暖暖的，需要换干爽的新尿裤吗？",
            sayAloudEn: "Ooh, wet diaper—let us change into a dry, comfy one together.",
            microActionZh: "改用尊重式身体命名（洗漱换裤时指出“这是膝盖、这是肚子”），安静等待膀胱控尿反射与配合意愿成熟。",
            microActionEn: "Build body awareness calmly during dressing/bath while letting bladder maturity catch up naturally.",
            translationZh: "CDC 与 AAP 共识指出强迫过早把尿易引起憋尿便秘、心理抗拒并反而拉长整个戒尿不湿周期。",
            translationEn: "Coercive early training frequently triggers stool withholding, constipation, and prolonged struggles.",
            grandparentNoteZh: "老辈省纸尿裤的心疼可以理解，但等孩子自己能站走稳、尿裤能干爽超 2 小时后再启动通常两周就成。",
            grandparentNoteEn: "Waiting for dry 2-hour stretches and steady walking turns months of battle into days.",
            clinicalTerms: ["Toilet Readiness Cues", "Autonomous Body Naming", "18m Preventive Care"],
            redFlagZh: "18 月龄听不懂不带手势的单步日常指令、极少模仿大人扫地擦桌等动作应尽快儿保沟通。",
            redFlagEn: "Mention to pediatrics if unable to follow simple gesture-free 1-step requests or imitate chores at 18m.",
            meta: EvidenceMeta(
                tiers: [.clinicalGuideline, .expertConsensus],
                sources: [
                    EvidenceSourceRef(org: "AAP / CDC", docZh: "18月龄如厕与自主发展建议", docEn: "18m Developmental & Readiness Advice", year: "2022"),
                    EvidenceSourceRef(org: "Shanghai NHC", docZh: "0–6岁孤独症早期识别共识", docEn: "ASD Early Screening Consensus", year: "2023")
                ],
                limitationZh: "每个孩子膀胱括约肌发育速度差异大，早产儿同样建议按矫正月龄耐心等待信号。",
                limitationEn: "Sphincter maturity varies widely; wait calmly for readiness cues especially in preterm toddlers.",
                reviewLabel: "AAP · CDC 2022"
            )
        ),
        // Stage 6: 18–24m
        LampCard(
            id: "18_24m_parallel", stageIndex: 6, minMonth: 18, maxMonth: 23,
            stageTitleZh: "18–24 月 · 双词与自主", stageTitleEn: "18–24m · Two-Word & Self",
            headlineZh: "游乐场抢玩具不分享？2 岁孩子只适合当「体育解说员」",
            headlineEn: "Not sharing on the playground? Be a calm sportscaster, not a judge",
            sayAloudZh: "你很想玩那辆消防车，小朋友手里正玩着呢；等他放下，或者我们先去玩滑梯。",
            sayAloudEn: "You really want that fire truck while he is using it. We can wait a turn or try the slide!",
            microActionZh: "停止当众训斥“快给弟弟玩”，改用平等客观描述帮双方理解“物权与轮流”概念。",
            microActionEn: "Describe what both children want calmly without shaming—building turn-taking foundation safely.",
            translationZh: "AAP 明确提醒不要期待 2 岁幼儿自动懂得大方分享。此时处于「平行游戏」期，安全感先于礼貌分享发展出来。",
            translationEn: "Two-year-olds live in parallel play; expecting adult-style sharing triggers hoarding rather than generosity.",
            grandparentNoteZh: "出门带两三件可互换小勺/沙铲，遇到冲突从容抱开换场地，不用觉得大人“管不好没面子”。",
            grandparentNoteEn: "Packing duplicate sand toys or gently redirecting saves playground tension without losing face.",
            clinicalTerms: ["Parallel Play", "Sportscaster Technique", "Proto-Share Development"],
            redFlagZh: "满 24 月龄仍无任何有意义双词短语（如“要奶”“妈妈抱”，非机械复读）、听不懂简单指令请及时筛查。",
            redFlagEn: "Evaluate promptly at 24m if no meaningful 2-word phrases (beyond echoing) or simple command comprehension.",
            meta: EvidenceMeta(
                tiers: [.clinicalGuideline, .developmentalResearch],
                sources: [
                    EvidenceSourceRef(org: "CDC / AAP", docZh: "24月龄社交与双词组合指南", docEn: "2-Year Milestones & Sharing Advice", year: "2022"),
                    EvidenceSourceRef(org: "Bright Futures", docZh: "2岁儿保访视前指导", docEn: "24-Month Previsit Guidance", year: "2023")
                ],
                limitationZh: "攻击性咬人打人需即时温和拉手制止并说出底线（“手不能打人”）。",
                limitationEn: "Biting or hitting always receives a calm immediate physical boundary ('hands are not for hitting').",
                reviewLabel: "CDC 2022 · AAP"
            )
        ),
        LampCard(
            id: "18_24m_self", stageIndex: 6, minMonth: 18, maxMonth: 23,
            stageTitleZh: "18–24 月 · 双词与自主", stageTitleEn: "18–24m · Two-Word & Self",
            headlineZh: "喊“不要！我自己来！”慢吞吞还洒水？那是大脑独立布线",
            headlineEn: "Shouting 'No! Me do it!' while spilling water—that is independence wiring",
            sayAloudZh: "水洒到桌子上啦，我们一起拿小抹布把它擦干。",
            sayAloudEn: "The water spilled! Let us grab the little towel together and wipe it dry.",
            microActionZh: "洗澡或餐桌备一只小水壶和塑料杯让他练习倾倒，平时故意把袜子套手上玩“不要”幽默游戏释放逆反。",
            microActionEn: "Offer small cup-pouring at bath time, and play silly 'put socks on hands? No!' games to ease power struggles.",
            translationZh: "蒙特梭利称两岁为「帮我自己做」的关键期。早出门 5 分钟、在低处常备一块小抹布，孩子越受信任合作反而越好。",
            translationEn: "'Help me do it myself' peaks around age two. Five extra minutes plus an accessible cloth unlocks pride.",
            grandparentNoteZh: "洒水扣不上鞋子不要立刻抢过来代做，哪怕扣歪一只也算了不起的尝试；满 24m 早产儿也迎来矫正月龄终点核对。",
            grandparentNoteEn: "Letting crooked buckles stay builds skill; note 24m also marks the transition check for preterm corrected age.",
            clinicalTerms: ["Toddler Autonomy", "Pouring Coordination", "24m ASD & BMI Baseline"],
            redFlagZh: "24 月龄无法稳走奔跑、不会模仿动作词语、无简单假扮游戏或出现倒退请安排儿保重点评估。",
            redFlagEn: "Consult pediatrics at 24m for unsteady walking, zero imitation/pretend play, or any regression.",
            meta: EvidenceMeta(
                tiers: [.clinicalGuideline, .pedagogicalPhilosophy],
                sources: [
                    EvidenceSourceRef(org: "Montessori / Vroom", docZh: "两岁自我服务与幽默化解", docEn: "Practical Autonomy & The No Game", year: "2023"),
                    EvidenceSourceRef(org: "AAP / PMC", docZh: "早产儿两岁发育评估终点", docEn: "24-Month Preterm Assessment", year: "2026")
                ],
                limitationZh: "早产儿满 2 岁后是否继续微调参考，需遵随访儿保医生个体化建议。",
                limitationEn: "Follow your pediatrician's advice on any remaining preterm adjustments beyond 24 months.",
                reviewLabel: "AAP · Vroom · PMC"
            )
        ),
        // Stage 7: 24–30m
        LampCard(
            id: "24_30m_dark", stageIndex: 7, minMonth: 24, maxMonth: 29,
            stageTitleZh: "24–30 月 · 想象与解惑", stageTitleEn: "24–30m · Pretend & Solve",
            headlineZh: "忽然怕黑说床底有怪兽？分不清想象与现实正说明脑力飞跃",
            headlineEn: "Scared of dark corners? Vivid imagination just switched on like a projector",
            sayAloudZh: "黑黑的影子让你觉得好害怕呀，我们把小台灯照过去看清楚是什么。",
            sayAloudEn: "Dark shadows look spooky! Let us shine our warm lamp over together to see what is really there.",
            microActionZh: "别嘲笑胆小或强行关黑屋，蹲下来开启低光夜灯照亮墙角，教他在难过生气时撕废纸/跺脚宣泄再用词命名。",
            microActionEn: "Acknowledge the fear calmly, check corners with the warm lamp, and name big feelings afterward.",
            translationZh: "2 岁半想象与象征思维陡增（会把积木当食物喂娃娃），却尚未学会把幻想和真实区分开，接纳是最快的镇定剂。",
            translationEn: "Symbolic pretend play surges at 30 months before reality-testing matures—calm validation beats dismissal.",
            grandparentNoteZh: "2 岁以上每日高质量屏幕互动上限 1 小时以内、须大人共看对话；睡前一小时留给暖光绘本和聊天。",
            grandparentNoteEn: "Keep screens under 1 hr/day co-viewed with you, and reserve the hour before bed for dim books.",
            clinicalTerms: ["Symbolic Imagination", "Co-Viewed Media Limit", "Emotional Naming"],
            redFlagZh: "30 月龄（CDC 新增清单节点）不会用约 50 个词、不会动词短语、听不懂两步指令或不会双脚离地跳请咨询儿保。",
            redFlagEn: "Consult pediatrics at 30m if fewer than ~50 words, no 2-step commands, no pretend play, or no 2-foot jump.",
            meta: EvidenceMeta(
                tiers: [.clinicalGuideline, .developmentalResearch],
                sources: [
                    EvidenceSourceRef(org: "CDC", docZh: "30月龄新增发育清单", docEn: "30-Month Milestone Checklist", year: "2022"),
                    EvidenceSourceRef(org: "AAP", docZh: "两岁后屏幕与睡眠节律建议", docEn: "2+ Media & Bedtime Guidance", year: "2023")
                ],
                limitationZh: "若夜间惊恐伴随白昼长期萎靡或拒绝入睡，记录发作规律供门诊问询。",
                limitationEn: "Track persistent night terrors impacting daytime energy to discuss at your 30m well visit.",
                reviewLabel: "CDC 2022 · AAP"
            )
        ),
        LampCard(
            id: "24_30m_math", stageIndex: 7, minMonth: 24, maxMonth: 29,
            stageTitleZh: "24–30 月 · 想象与解惑", stageTitleEn: "24–30m · Pretend & Solve",
            headlineZh: "不必焦虑认字 App：爬楼梯数台阶、收玩具寻宝就是最硬核启蒙",
            headlineEn: "Skip flashcard apps—stairs counting & toy-sorting treasures build real math",
            sayAloudZh: "我们一起来找所有带轮子的玩具送回家！1 个、2 个，还找到一个圆球。",
            sayAloudEn: "Let us rescue every toy with wheels! One, two—plus look, a round wooden ball.",
            microActionZh: "把睡前收玩具变成「找同类寻宝」，并在爬楼梯、擦桌摆筷时聊“大小、多少、上下”。",
            microActionEn: "Turn cleanup into a category hunt ('find everything round!') and chat big/small while climbing stairs.",
            translationZh: "动手抓物、生活空间分类与面对面绘本一问一答（谁在跑、去哪了），激活脑区比电子屏幕点读高出数倍。",
            translationEn: "Embodied sorting, kitchen routines, and back-and-forth book talk wire reasoning far deeper than tablet apps.",
            grandparentNoteZh: "外公外婆拎菜回来让孩子帮挑出两个大土豆，就是活生生的 30 月龄早期数学和生活能力课。",
            grandparentNoteEn: "Sorting two big potatoes from grocery bags gives effortless hands-on counting and pride.",
            clinicalTerms: ["Embodied Spatial Math", "Two-Step Directions", "Open-Ended Book Talk"],
            redFlagZh: "满 30 月龄对同伴完全无意识、完全无假扮游戏或出现沟通能力明显滑坡须尽快就诊筛查。",
            redFlagEn: "Evaluate promptly at 30m if completely unaware of peers, zero pretend play, or any lost skills.",
            meta: EvidenceMeta(
                tiers: [.developmentalResearch, .pedagogicalPhilosophy],
                sources: [
                    EvidenceSourceRef(org: "Vroom", docZh: "日常找同类与对话延展", docEn: "Can You Find & Stretch Prompts", year: "2023"),
                    EvidenceSourceRef(org: "CDC / NHC", docZh: "30月龄认知与语言照护", docEn: "30m Cognitive & Speech Check", year: "2022")
                ],
                limitationZh: "本玩法强调零成本生活化互动，不需额外购置学科早教教具包。",
                limitationEn: "Everyday household moments provide rich learning without costly commercial kits.",
                reviewLabel: "Vroom · CDC · NHC"
            )
        ),
        // Stage 8: 30–36m
        LampCard(
            id: "30_36m_school", stageIndex: 8, minMonth: 30, maxMonth: 36,
            stageTitleZh: "30–36 月 · 对话入园", stageTitleEn: "30–36m · Ready for Peers",
            headlineZh: "入园分开时撕心裂肺大哭？离开后多数 10 分钟就能平静融入",
            headlineEn: "Tearful daycare drop-offs? Most 3-year-olds settle calmly within 10 minutes",
            sayAloudZh: "贴贴脸亲一下，下午吃完加餐妈妈就第一个来接你。",
            sayAloudEn: "One kiss and a hug—after afternoon snack I will be back right here to pick you up.",
            microActionZh: "在家先用两只毛绒玩偶预演“告别—吃水果—接回家”完整剧本；真进园保持微笑简短告别，切忌反复回头偷看。",
            microActionEn: "Rehearse drop-off and pickup using two plush toys at home; keep real goodbyes warm, brief, and firm.",
            translationZh: "依恋深才会依依不舍。大人反复折返等于向孩子确认“离开好危险”；坚定信任老师则帮他把信任安全迁移到新群体。",
            translationEn: "Strong tears reflect deep attachment. Brief confident goodbyes help them settle quickly—often within 10 minutes.",
            grandparentNoteZh: "接孩子放学第一句话先给大拥抱聊今天玩了什么小花，把好奇留给过程，不急着考“学了几个字”。",
            grandparentNoteEn: "Greet pickup with a hug and curiosity about friends rather than quizzing memorized facts.",
            clinicalTerms: ["10-Minute Settling Window", "Separation Ritual", "Social Graces & Courtesy"],
            redFlagZh: "36 月龄无法与熟人进行两轮以上往复对话、说话含糊致家人也听不清或完全拒绝同伴请与儿保沟通。",
            redFlagEn: "Consult pediatrics at 36m if unable to hold 2 back-and-forth turns, unclear speech to family, or zero peer play.",
            meta: EvidenceMeta(
                tiers: [.clinicalGuideline, .pedagogicalPhilosophy],
                sources: [
                    EvidenceSourceRef(org: "CDC", docZh: "3岁儿童社交情绪基准", docEn: "3-Year Milestones (CDC 2022)", year: "2022"),
                    EvidenceSourceRef(org: "Montessori / AAP", docZh: "社会礼仪敏感期与年度体检", docEn: "Courtesy & 3-Year Well Visit", year: "2024")
                ],
                limitationZh: "若入园适应超过 1 个月仍出现持续整夜噩梦或行为大倒退，请与老师及儿保共同评估。",
                limitationEn: "Partner with teachers and pediatrics if severe distress persists beyond the first month.",
                reviewLabel: "CDC 2022 · AAP"
            )
        ),
        LampCard(
            id: "30_36m_why", stageIndex: 8, minMonth: 30, maxMonth: 36,
            stageTitleZh: "30–36 月 · 对话入园", stageTitleEn: "30–36m · Ready for Peers",
            headlineZh: "每天一百个“为什么”答到词穷？把问题温柔抛回去摸索",
            headlineEn: "Exhausted by endless 'Why?' questions? Toss curiosity gently back",
            sayAloudZh: "这个问题真好玩！我也还没想清楚，你猜叶子为什么会有小洞洞？",
            sayAloudEn: "What a fun question! What do YOU think made that tiny hole in the leaf?",
            microActionZh: "请小厨师一起洗葡萄、挑菜叶，或读绘本读到一半合起问“你猜下一页发生什么”，顺手录下童言贴进成长册。",
            microActionEn: "Cook together washing grapes or pause mid-story asking 'what happens next?'—and record their funny answer!",
            translationZh: "三岁娃追问“为什么”不是在考百科知识，而是借语言拉着最爱的你一起延续对话；他最迷恋的是并肩摸索的过程。",
            translationEn: "'Why?' is rarely a trivia test—it is an invitation to stay in delighted conversation alongside you.",
            grandparentNoteZh: "趁着满三岁前那口奶音还在，在「留念」里记下几句他的奇思妙想，回头看比成绩单珍贵得多。",
            grandparentNoteEn: "Capture these quirky 3-year-old sayings in Keepsakes before the little voice grows up.",
            clinicalTerms: ["Reciprocal Conversation", "Pre-Literacy Narrative", "Fine Motor Kitchen Prep"],
            redFlagZh: "3 岁体检启动常规视力、血压及听觉语言核查，如有清晰度疑虑及时趁体检一并询问。",
            redFlagEn: "The 3-year checkup initiates routine vision, blood pressure, and speech checks—bring questions along.",
            meta: EvidenceMeta(
                tiers: [.clinicalGuideline, .developmentalResearch],
                sources: [
                    EvidenceSourceRef(org: "AAP Bright Futures", docZh: "3岁年度保健访视指南", docEn: "3-Year Preventive Visit", year: "2025"),
                    EvidenceSourceRef(org: "NHC", docZh: "3岁心理行为预警征象", docEn: "36m Warning Signs Screening", year: "2022")
                ],
                limitationZh: "本条目为亲子沟通启发，如有语言发育疑虑请以专业听力与言语评估为准。",
                limitationEn: "For conversational inspiration; rely on formal hearing/speech screening if speech clarity lags.",
                reviewLabel: "AAP 2025 · NHC"
            )
        )
    ]
}
