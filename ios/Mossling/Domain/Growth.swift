import Foundation

/// The three WHO growth standards: weight, length/height and head circumference for age.
enum Indicator: String, CaseIterable, Identifiable {
    case weight = "wfa", length = "lhfa", head = "hcfa"
    var id: String { rawValue }
    var label: String { switch self { case .weight: L10n.t("体重", "Weight"); case .length: L10n.t("身长 / 身高", "Length / Height"); case .head: L10n.t("头围", "Head circumference") } }
    var short: String { switch self { case .weight: L10n.t("体重", "Weight"); case .length: L10n.t("身长", "Length"); case .head: L10n.t("头围", "Head") } }
    var unit: String { self == .weight ? L10n.t("千克", "kg") : L10n.t("厘米", "cm") }
    var unitShort: String { self == .weight ? L10n.t("千克", "kg") : L10n.t("厘米", "cm") }
    func fmt(_ v: Double) -> String { String(format: self == .weight ? "%.2f" : "%.1f", v) }
}

/// WHO Child Growth Standards (2006), by LMS; monthly parameters interpolated linearly.
struct Growth {
    private let t: [String: [String: [[Double]]]]
    static let lines = [3, 15, 50, 85, 97]
    private static let zOf: [Int: Double] = [3: -1.880794, 15: -1.036433, 50: 0, 85: 1.036433, 97: 1.880794]

    init(json: Data) throws {
        let o = try JSONSerialization.jsonObject(with: json) as! [String: Any]
        var t: [String: [String: [[Double]]]] = [:]
        for k in ["wfa", "lhfa", "hcfa"] { t[k] = o[k] as? [String: [[Double]]] }
        self.t = t
    }
    static func load(bundle: Bundle = .main) throws -> Growth {
        try Growth(json: Data(contentsOf: bundle.url(forResource: "who_growth", withExtension: "json")!))
    }

    private func lms(_ i: Indicator, _ girl: Bool, _ months: Double) -> (Double, Double, Double) {
        let rows = t[i.rawValue]![girl ? "girls" : "boys"]!
        let m = max(0, min(36, months)); let a = min(Int(m), 35); let f = m - Double(a)
        func v(_ k: Int) -> Double { rows[a][k] + (rows[a + 1][k] - rows[a][k]) * f }
        return (v(0), v(1), v(2))
    }
    /// The value on the curve of [percentile] at [months].
    func at(_ i: Indicator, girl: Bool, months: Double, percentile: Int) -> Double {
        let (l, m, s) = lms(i, girl, months); let z = Growth.zOf[percentile] ?? 0
        return abs(l) < 1e-6 ? m * exp(s * z) : m * pow(1 + l * s * z, 1 / l)
    }
    func z(_ i: Indicator, girl: Bool, months: Double, value: Double) -> Double {
        guard value.isFinite, value > 0 else { return .nan }
        let (l, m, s) = lms(i, girl, months)
        guard m > 0, s > 0 else { return .nan }
        return abs(l) < 1e-6 ? log(value / m) / s : (pow(value / m, l) - 1) / (l * s)
    }
    func percentile(_ i: Indicator, girl: Bool, months: Double, value: Double) -> Double {
        let score = z(i, girl: girl, months: months, value: value)
        guard score.isFinite else { return .nan }
        return 100 * 0.5 * (1 + erf(score / 2.0.squareRoot()))
    }
}

/// "第 42 百分位"; the far ends say what they are.
func pctText(_ p: Double) -> String {
    guard p.isFinite else { return "" }
    if p < 3 { return L10n.t("低于第 3 百分位", "Below 3rd percentile") }
    if p > 97 { return L10n.t("高于第 97 百分位", "Above 97th percentile") }
    let n = max(3, min(97, Int(p.rounded())))
    return L10n.t("约第 \(n) 百分位", "~\(growthOrdinal(n)) percentile")
}

private func growthOrdinal(_ n: Int) -> String {
    let mod100 = n % 100
    if mod100 >= 11 && mod100 <= 13 { return "\(n)th" }
    switch n % 10 {
    case 1: return "\(n)st"
    case 2: return "\(n)nd"
    case 3: return "\(n)rd"
    default: return "\(n)th"
    }
}
