import Foundation

/// Lightweight bilingual (zh-Hans / en) & regional unit helper shared by the app, widgets, Live Activities, and intents.
/// Preserves Moss & Otto's quiet, warm tone in both Chinese and English ("They explore. You hold the light.").
enum L10n {
    #if DEBUG
    /// Tests may set this to render deterministic Chinese or English screenshots regardless of simulator locale.
    nonisolated(unsafe) static var overrideEnglish: Bool? = nil
    #endif

    static var isEnglish: Bool {
        #if DEBUG
        if let o = overrideEnglish { return o }
        #endif
        let lang = Locale.preferredLanguages.first ?? Locale.current.identifier
        return lang.hasPrefix("en")
    }

    static var usesImperial: Bool {
        Locale.current.measurementSystem == .us
    }

    /// Picks idiomatic Chinese or English copy.
    static func t(_ zh: String, _ en: String) -> String {
        isEnglish ? en : zh
    }

    /// Returns a `LocalizedStringResource` for APIs like `ControlWidgetConfiguration.displayName(_:)`.
    static func res(_ zh: String, _ en: String) -> LocalizedStringResource {
        LocalizedStringResource(stringLiteral: t(zh, en))
    }

    static func logName(_ type: String) -> String {
        guard isEnglish else { return LogType.name(type) }
        switch type {
        case LogType.nurse: return "Nurse"
        case LogType.bottle: return "Bottle"
        case LogType.sleep: return "Sleep"
        case LogType.diaper: return "Diaper"
        case LogType.solid: return "Solids"
        case LogType.bath: return "Bath"
        case LogType.temp: return "Temp"
        case LogType.medicine: return "Meds"
        case LogType.note: return "Note"
        case LogType.play: return "Play"
        case LogType.growth: return "Growth"
        default: return type
        }
    }

    static func ageText(_ age: Age) -> String {
        if isEnglish {
            if age.months == 0 { return "\(age.days)d" }
            return age.days > 0 ? "\(age.months)m \(age.days)d" : "\(age.months) mo"
        }
        return age.days > 0 ? "\(age.months) 个月 \(age.days) 天" : "满 \(age.months) 个月"
    }

    static func livedDays(_ days: Int) -> String {
        isEnglish ? "Day \(days)" : "第 \(days) 天"
    }

    static func timerStatus(_ type: String, side: String?, paused: Bool) -> String {
        guard isEnglish else { return timerState(type, side: side, paused: paused) }
        let base = logName(type)
        let s = side == "l" ? "Left" : side == "r" ? "Right" : nil
        let p = paused ? "Paused" : nil
        return ([base, s, p].compactMap { $0 }).joined(separator: " · ")
    }

    static func duration(_ seconds: Double) -> String {
        guard isEnglish else { return minutesOf(seconds) }
        let m = max(1, Int((seconds / 60).rounded()))
        if m < 60 { return "\(m)m" }
        let h = m / 60, r = m % 60
        return r == 0 ? "\(h)h" : "\(h)h \(r)m"
    }

    static func agoText(_ at: Date, now: Date = Date(), precise: Bool = false) -> String {
        guard isEnglish else { return ago(at, now: now, precise: precise) }
        let s = max(0, Int(now.timeIntervalSince(at)))
        if s < 60 { return "Just now" }
        let m = s / 60
        if m < 60 { return "\(m)m ago" }
        let h = m / 60, r = m % 60
        if h < 24 { return precise && r > 0 ? "\(h)h \(r)m ago" : "\(h)h ago" }
        return "\(h / 24)d ago"
    }

    static func volume(ml: Int) -> String {
        if isEnglish && usesImperial {
            let oz = Double(ml) / 29.5735
            return String(format: "%.1f fl oz", oz)
        }
        return isEnglish ? "\(ml) ml" : "\(ml) 毫升"
    }

    static func temperature(tenthsC: Int) -> String {
        let c = Double(tenthsC) / 10.0
        if isEnglish && usesImperial {
            return String(format: "%.1f °F", c * 9.0 / 5.0 + 32.0)
        }
        return String(format: "%.1f °C", c)
    }
}
