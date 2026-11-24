import Foundation
import SwiftUI

/// Regional pediatric immunization and well-child visit schedule reference for `CareView` (100% offline).
/// Supports China (NHC 2026), United States (AAP / CDC), United Kingdom (NHS), and Australia (NIP).
enum HealthRegion: String, CaseIterable, Identifiable, Sendable {
    case cn, us, uk, au

    var id: String { rawValue }

    static func defaultRegion(isEnglish: Bool = L10n.isEnglish, locale: Locale = .current) -> HealthRegion {
        if !isEnglish { return .cn }
        let reg = (locale.region?.identifier ?? "").uppercased()
        switch reg {
        case "GB", "UK": return .uk
        case "AU": return .au
        case "CN", "HK", "MO", "TW": return .cn
        default: return .us
        }
    }

    var shortLabel: String {
        switch self {
        case .cn: L10n.t("中国 (国卫规)", "China (NHC)")
        case .us: L10n.t("美国 (AAP/CDC)", "US (AAP/CDC)")
        case .uk: L10n.t("英国 (NHS)", "UK (NHS)")
        case .au: L10n.t("澳大利亚 (NIP)", "Australia (NIP)")
        }
    }

    var authorityHeadline: String {
        switch self {
        case .cn: L10n.t("国家免疫规划程序（2026 版）", "China National Immunization Program (2026)")
        case .us: L10n.t("AAP 儿保周期表与 CDC 免疫参考", "AAP Periodicity Schedule & CDC Immunization Guide")
        case .uk: L10n.t("NHS 幼儿健康发展评估与免疫节律", "NHS Healthy Child Programme & Routine Vaccines")
        case .au: L10n.t("澳大利亚国家免疫计划 (NIP)", "Australian National Immunisation Program")
        }
    }

    var scopeNote: String {
        switch self {
        case .cn:
            return L10n.t(
                "依据《国家免疫规划疫苗儿童免疫程序及说明（2026年版）》（国疾控卫免发〔2026〕16号）及国家基本公共卫生服务规范整理；各地接种与儿保门诊可能略有调整，请以当地医嘱为准。",
                "Summarized from China's National Immunization Program (2026 Edition) and public 0–6 yr child health specifications. Confirm exact clinic dates with your local provider."
            )
        case .us:
            return L10n.t(
                "对照美国儿科学会 (AAP 2025) 预防性儿保周期与 CDC 常规儿童疫苗建议整理；具体接种剂次与个体情况以美国当地儿科诊所及医生安排为准。",
                "Aligned with AAP Bright Futures Periodicity Schedule (2025) and CDC routine childhood immunization guidelines. Always confirm individualized timing with your pediatrician."
            )
        case .uk:
            return L10n.t(
                "依据英国国民保健署 (NHS) 婴幼儿预防接种日历与 Health Visitor 发育访视节点整理；具体安排请以当地 GP 诊所或健康访视员通知为准。",
                "Summarized from the NHS routine childhood vaccination calendar and Healthy Child Programme reviews. Confirm clinic appointments with your GP surgery or health visitor."
            )
        case .au:
            return L10n.t(
                "依据澳大利亚国家免疫计划 (NIP) 与各州妇幼保健节点整理；各州/领地接种或随访节律存在微调，请以当地社区护士与全科医生意见为准。",
                "Summarized from Australia's National Immunisation Program (NIP) and early childhood health review milestones. Confirm state-specific details with your GP or child health nurse."
            )
        }
    }

    struct ReferenceEntry: Equatable, Identifiable, Sendable {
        let id: String
        let kind: String // "vaccine" or "checkup"
        let title: String
    }

    static func schedule(for region: HealthRegion, month: Int) -> [ReferenceEntry] {
        let m = max(0, min(36, month))
        switch region {
        case .cn:
            return [] // Uses authoritative content.json checklists directly
        case .us:
            return usSchedule(month: m)
        case .uk:
            return ukSchedule(month: m)
        case .au:
            return auSchedule(month: m)
        }
    }

    private static func usSchedule(month: Int) -> [ReferenceEntry] {
        switch month {
        case 0:
            return [
                ReferenceEntry(id: "us-0-v", kind: "vaccine", title: L10n.t("乙肝疫苗第 1 剂（出生后）", "HepB dose 1 (birth)")),
                ReferenceEntry(id: "us-0-c", kind: "checkup", title: L10n.t("新生儿出院后首次儿科复诊（3–5 天）与满月随访", "Newborn visit (3–5 days) & 1-month well-child check"))
            ]
        case 2:
            return [
                ReferenceEntry(id: "us-2-v", kind: "vaccine", title: L10n.t("2 月龄联合免疫（DTaP / Hib / IPV / PCV / 轮状病毒）", "2-month vaccines: DTaP, Hib, IPV, PCV, Rotavirus (HepB dose 2 at 1–2 mo)")),
                ReferenceEntry(id: "us-2-c", kind: "checkup", title: L10n.t("2 月龄 AAP 儿保访视：体重身高头围曲线与喂养沟通", "2-month AAP well-child visit & maternal depression screen"))
            ]
        case 4:
            return [
                ReferenceEntry(id: "us-4-v", kind: "vaccine", title: L10n.t("4 月龄第 2 剂联合免疫（DTaP / Hib / IPV / PCV / 轮状病毒）", "4-month vaccines: DTaP, Hib, IPV, PCV, Rotavirus")),
                ReferenceEntry(id: "us-4-c", kind: "checkup", title: L10n.t("4 月龄 AAP 儿保访视：生长曲线与抬头趴玩评估", "4-month AAP well-child visit & developmental surveillance"))
            ]
        case 6:
            return [
                ReferenceEntry(id: "us-6-v", kind: "vaccine", title: L10n.t("6 月龄联合免疫（DTaP / PCV / 乙肝 / 季节性流感建议）", "6-month vaccines: DTaP, PCV, HepB (6–18 mo window), Influenza (6 mo+)")),
                ReferenceEntry(id: "us-6-c", kind: "checkup", title: L10n.t("6 月龄 AAP 儿保访视：口腔涂氟问询与辅食引入", "6-month AAP well-child visit, oral health & solid foods review"))
            ]
        case 9:
            return [
                ReferenceEntry(id: "us-9-c", kind: "checkup", title: L10n.t("9 月龄 AAP 专项发育筛查（运动、语言与互动评估）", "9-month AAP standardized developmental screening"))
            ]
        case 12:
            return [
                ReferenceEntry(id: "us-12-v", kind: "vaccine", title: L10n.t("12–15 月龄疫苗窗口：MMR、水痘、Hib 与 PCV 加强、甲肝第 1 剂", "12–15 mo window: MMR, Varicella, Hib/PCV boosters, HepA dose 1")),
                ReferenceEntry(id: "us-12-c", kind: "checkup", title: L10n.t("12 月龄 AAP 儿保访视：血红蛋白/血铅风险评估", "12-month AAP well-child visit, anemia & lead risk screening"))
            ]
        case 15:
            return [
                ReferenceEntry(id: "us-15-v", kind: "vaccine", title: L10n.t("15–18 月龄 DTaP 第 4 剂（及未完成窗口疫苗）", "15–18 mo DTaP dose 4 & catch-up check")),
                ReferenceEntry(id: "us-15-c", kind: "checkup", title: L10n.t("15 月龄 AAP 儿保访视", "15-month AAP well-child visit"))
            ]
        case 18:
            return [
                ReferenceEntry(id: "us-18-v", kind: "vaccine", title: L10n.t("甲肝第 2 剂（间隔 6 个月）与流感季补种", "HepA dose 2 (6 mo after dose 1) & seasonal check")),
                ReferenceEntry(id: "us-18-c", kind: "checkup", title: L10n.t("18 月龄 AAP 发育与社交沟通专项筛查", "18-month AAP developmental & autism-specific screening"))
            ]
        case 24:
            return [
                ReferenceEntry(id: "us-24-c", kind: "checkup", title: L10n.t("2 岁 AAP 儿保访视：24 月龄社交沟通筛查与血压/口腔复核", "24-month AAP well-child visit & developmental follow-up"))
            ]
        case 30:
            return [
                ReferenceEntry(id: "us-30-c", kind: "checkup", title: L10n.t("30 月龄 AAP 专项发育筛查", "30-month AAP standardized developmental screening"))
            ]
        case 36:
            return [
                ReferenceEntry(id: "us-36-c", kind: "checkup", title: L10n.t("3 岁 AAP 儿保访视：视力初步检查、语言与社会情绪评估", "3-year AAP well-child visit, vision & emotional screening"))
            ]
        default:
            return [
                ReferenceEntry(id: "us-\(month)-n", kind: "checkup", title: L10n.t("美国 AAP 本月无固定常规接种节点，关注年度生长记录与日常发育观察即可。", "No routine US AAP/CDC well-child visit scheduled specifically at \(month) months; check adjacent milestones."))
            ]
        }
    }

    private static func ukSchedule(month: Int) -> [ReferenceEntry] {
        switch month {
        case 0:
            return [
                ReferenceEntry(id: "uk-0-c", kind: "checkup", title: L10n.t("新生儿检查（72 小时内）与 Health Visitor 首月访视（10–14 天 / 6–8 周）", "Newborn physical exam & Health Visitor new-baby review"))
            ]
        case 2:
            return [
                ReferenceEntry(id: "uk-2-v", kind: "vaccine", title: L10n.t("8 周（约 2 月龄）：六联疫苗第 1 剂、MenB、轮状病毒", "8 weeks (~2 mo): 6-in-1 (1st), MenB (1st), Rotavirus (1st)")),
                ReferenceEntry(id: "uk-2-c", kind: "checkup", title: L10n.t("6–8 周 GP 婴儿与产后全面健康检查", "6–8 week GP baby & postnatal health check"))
            ]
        case 3:
            return [
                ReferenceEntry(id: "uk-3-v", kind: "vaccine", title: L10n.t("12 周（约 3 月龄）：六联疫苗第 2 剂、PCV13、轮状病毒第 2 剂", "12 weeks (~3 mo): 6-in-1 (2nd), PCV, Rotavirus (2nd)"))
            ]
        case 4:
            return [
                ReferenceEntry(id: "uk-4-v", kind: "vaccine", title: L10n.t("16 周（约 4 月龄）：六联疫苗第 3 剂、MenB 第 2 剂", "16 weeks (~4 mo): 6-in-1 (3rd), MenB (2nd)"))
            ]
        case 9...11:
            return month == 10 ? [
                ReferenceEntry(id: "uk-10-c", kind: "checkup", title: L10n.t("9–12 月龄 NHS 健康发展评估（Health & Development Review）", "9–12 month NHS Healthy Child development review"))
            ] : [
                ReferenceEntry(id: "uk-fit-note", kind: "checkup", title: L10n.t("可在 9–12 月龄窗口安排 NHS 发育随访（ASQ-3）。", "9–12 month NHS development review window."))
            ]
        case 12:
            return [
                ReferenceEntry(id: "uk-12-v", kind: "vaccine", title: L10n.t("1 周岁疫苗：Hib/MenC、PCV 加强、MMR 第 1 剂、MenB 加强", "1 year vaccines: Hib/MenC, PCV booster, MMR (1st), MenB booster"))
            ]
        case 24...30:
            return month == 27 ? [
                ReferenceEntry(id: "uk-27-c", kind: "checkup", title: L10n.t("2–2.5 岁 NHS 全面发展评估（语言、社交与动作观察）", "2 to 2.5 year NHS Health Visitor developmental review"))
            ] : [
                ReferenceEntry(id: "uk-24-note", kind: "checkup", title: L10n.t("注意 2–2.5 岁 NHS 发育回顾通知；每年秋季关注适用月龄流感喷剂计划。", "Expect the 2–2.5 yr NHS development review invitation; check annual flu schedule from 2 yrs."))
            ]
        default:
            return [
                ReferenceEntry(id: "uk-\(month)-n", kind: "checkup", title: L10n.t("英国 NHS 本月无固定常规接种节点，沿用红本（Red Book）日常生长追踪。", "No routine UK NHS clinic milestone at \(month) months; track growth in your Personal Child Health Record (Red Book)."))
            ]
        }
    }

    private static func auSchedule(month: Int) -> [ReferenceEntry] {
        switch month {
        case 0:
            return [
                ReferenceEntry(id: "au-0-v", kind: "vaccine", title: L10n.t("出生乙肝疫苗（Hospital birth dose HepB）", "Birth dose Hepatitis B")),
                ReferenceEntry(id: "au-0-c", kind: "checkup", title: L10n.t("出生后 1–4 周社区妇幼护士初访", "1–4 week Child & Family Health nurse home/clinic visit"))
            ]
        case 2:
            return [
                ReferenceEntry(id: "au-2-v", kind: "vaccine", title: L10n.t("2 月龄（6–8 周起）：DTPa-HepB-IPV-Hib、肺炎球菌、轮状病毒第 1 剂", "2 months (from 6 wks): Infanrix hexa, Pneumococcal, Rotavirus (1st)"))
            ]
        case 4:
            return [
                ReferenceEntry(id: "au-4-v", kind: "vaccine", title: L10n.t("4 月龄：六联疫苗、肺炎球菌、轮状病毒第 2 剂", "4 months: 6-in-1, Pneumococcal, Rotavirus (2nd)")),
                ReferenceEntry(id: "au-4-c", kind: "checkup", title: L10n.t("4 月龄澳洲健康发育检查（Blue Book / Green Book）", "4-month child health & development check"))
            ]
        case 6:
            return [
                ReferenceEntry(id: "au-6-v", kind: "vaccine", title: L10n.t("6 月龄：六联疫苗第 3 剂（及 6 月龄起季节性流感计划）", "6 months: 6-in-1 (3rd dose) & annual influenza recommendation")),
                ReferenceEntry(id: "au-6-c", kind: "checkup", title: L10n.t("6 月龄发育与辅食过渡随访", "6-month child health check"))
            ]
        case 12:
            return [
                ReferenceEntry(id: "au-12-v", kind: "vaccine", title: L10n.t("12 月龄：Meningococcal ACWY、MMR 第 1 剂、肺炎球菌第 3 剂", "12 months: MenACWY, MMR (1st dose), Pneumococcal booster")),
                ReferenceEntry(id: "au-12-c", kind: "checkup", title: L10n.t("12 月龄澳洲生长与动作随访", "12-month child health & development check"))
            ]
        case 18:
            return [
                ReferenceEntry(id: "au-18-v", kind: "vaccine", title: L10n.t("18 月龄：Hib 加强、MMR-V（麻腮风水痘）、DTPa 第 4 剂", "18 months: Hib booster, MMRV, DTPa")),
                ReferenceEntry(id: "au-18-c", kind: "checkup", title: L10n.t("18 月龄语言与社交互动随访", "18-month developmental review"))
            ]
        case 24:
            return [
                ReferenceEntry(id: "au-24-c", kind: "checkup", title: L10n.t("2 周岁澳洲常规生长与发育检查", "2-year child health & development check"))
            ]
        case 36:
            return [
                ReferenceEntry(id: "au-36-c", kind: "checkup", title: L10n.t("3 周岁（或 3.5 岁前）社区儿保随访", "3-year child health & development check"))
            ]
        default:
            return [
                ReferenceEntry(id: "au-\(month)-n", kind: "checkup", title: L10n.t("澳洲 NIP 本月无常规疫苗节点，保持社区保健册定期记录。", "No routine Australian NIP milestone scheduled at \(month) months."))
            ]
        }
    }
}
