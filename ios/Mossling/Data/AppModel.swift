import SwiftUI
import Observation
import WidgetKit

enum TickKind { static let observed = "c", did = "a", vaccine = "v", checkup = "k" }
func tickKey(_ month: Int, _ kind: String, _ id: String) -> String { "\(month):\(kind):\(id)" }

struct Tick: Codable, Hashable {
    let key: String, month: Int, kind: String, label: String, at: Double
}

enum ThemeMode: String, CaseIterable { case system, light, dark
    var label: String { switch self { case .system: L10n.t("自动", "Auto"); case .light: L10n.t("日光", "Day"); case .dark: L10n.t("夜灯", "Lamp") } }
    var scheme: ColorScheme? { switch self { case .system: nil; case .light: .light; case .dark: .dark } }
}

extension AppLanguage {
    var label: String { switch self { case .system: L10n.t("自动", "Auto"); case .zh: "中文"; case .en: "English" } }
}

/// Settings and month records, kept on the phone (UserDefaults); the journal lives in its own store.
@Observable
final class AppModel {
    var content: Content
    let growth: Growth
    var today: Day = .today

    private let d: UserDefaults
    var birth: Day? { didSet { d.set(birth?.epochDay, forKey: "birth"); if birth != nil { onboarded = true } } }
    var companion: Kind { didSet { d.set(companion.rawValue, forKey: "companion") } }
    var theme: ThemeMode { didSet { d.set(theme.rawValue, forKey: "theme") } }
    /// In-app language preference (shared with widgets & controls via App Group).
    var language: AppLanguage {
        didSet {
            L10n.preference = language
            if let reloaded = try? Content.load(english: L10n.isEnglish) {
                content = reloaded
            }
            WidgetCenter.shared.reloadAllTimelines()
            if #available(iOS 18.0, *) { ControlCenter.shared.reloadAllControls() }
        }
    }
    /// How the pictures and icons are drawn: 立体 (3D vinyl, the default) or 平面 (the picture book's 2D drawings).
    var artStyle: ArtStyle { didSet { d.set(artStyle.rawValue, forKey: "artStyle"); ArtStyle.current = artStyle } }
    var onboarded: Bool { didSet { d.set(onboarded, forKey: "onboarded") } }
    /// Today's play when the parent chose another with 换一个: "<epoch day>|CODE", good for that day only.
    var pick: String { didSet { d.set(pick, forKey: "todayPick") } }
    var sex: String? { didSet { d.set(sex, forKey: "sex") } }
    /// How the child is drawn in the pictures: "boy" or "girl"; until chosen, it follows `sex`. Independent of the
    /// companion.
    var look: String? { didSet { d.set(look, forKey: "look") } }
    var nickname: String { didSet { d.set(nickname, forKey: "nickname") } }
    var lock: Bool { didSet { d.set(lock, forKey: "lock") } }
    var shelf: String { didSet { d.set(shelf, forKey: "shelf") } }
    /// The guardian's choice on the privacy policy and the children's information rules: the version agreed to
    /// (Consent.version), "declined", or "" before the first answer.
    var consent: String { didSet { d.set(consent, forKey: "consent") } }
    /// Set when something that keeps the child's information is asked for before the guardian has agreed: the consent
    /// card comes up (once per ask, never on its own).
    var askConsent = false
    var journal: Bool { didSet { d.set(journal, forKey: "journal") } }
    /// 夜灯: from 7 pm to 6 am the records and the timer turn into Otto's lamp — dim warm light on deep blue.
    var nightLight: Bool { didSet { d.set(nightLight, forKey: "nightLight") } }
    /// Tactile Montessori wooden/paper micro-acoustics (automatically muted at night, under Sleep timers, or on Silent).
    var tactileSounds: Bool {
        didSet {
            d.set(tactileSounds, forKey: "tactileSounds")
            let enabled = tactileSounds
            Task { @MainActor in TactileEngine.shared.soundEnabled = enabled }
        }
    }
    /// A play started and not finished: "CODE|month|step". Shown above the tab bar until it is finished or put away.
    var session: String { didSet { d.set(session, forKey: "session") } }
    private(set) var ticks: [String: Tick] { didSet { d.set(try? JSONEncoder().encode(Array(ticks.values)), forKey: "ticks") } }

    init(defaults: UserDefaults = .standard, content: Content? = nil, growth: Growth? = nil) {
        d = defaults
        self.content = content ?? (try! Content.load())
        self.growth = growth ?? (try! Growth.load())
        // a number, or text from the launch arguments (the accessibility audit starts the app with -birth <day>)
        birth = ((d.object(forKey: "birth") as? Int) ?? d.string(forKey: "birth").flatMap { Int($0) }).map { Day(epochDay: $0) }
        companion = Kind(rawValue: d.string(forKey: "companion") ?? "") ?? .moss
        theme = ThemeMode(rawValue: d.string(forKey: "theme") ?? "") ?? .system
        language = L10n.preference
        let style = ArtStyle(rawValue: d.string(forKey: "artStyle") ?? "") ?? .vinyl
        artStyle = style
        ArtStyle.current = style
        onboarded = d.bool(forKey: "onboarded")
        pick = d.string(forKey: "todayPick") ?? ""
        // old keys nothing reads any more (they were never in the record file)
        d.removeObject(forKey: "pick"); d.removeObject(forKey: "skipDay")
        sex = d.string(forKey: "sex")
        look = d.string(forKey: "look")
        nickname = d.string(forKey: "nickname") ?? ""
        lock = d.bool(forKey: "lock")
        shelf = d.string(forKey: "shelf") ?? ""
        consent = d.string(forKey: "consent") ?? ""
        journal = d.bool(forKey: "journal")
        nightLight = d.object(forKey: "nightLight") == nil ? true : d.bool(forKey: "nightLight")
        let sounds = d.object(forKey: "tactileSounds") == nil ? true : d.bool(forKey: "tactileSounds")
        tactileSounds = sounds
        Task { @MainActor in TactileEngine.shared.soundEnabled = sounds }
        session = d.string(forKey: "session") ?? ""
        let list = (d.data(forKey: "ticks")).flatMap { try? JSONDecoder().decode([Tick].self, from: $0) } ?? []
        ticks = Dictionary(list.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var age: Age? { birth.map { Age.on(birth: $0, today: today) } }
    var babyMonth: Int? { age?.bookMonth }
    var girl: Bool { sex == "girl" }
    /// The child, in a sentence: 她 or 他 when the parent has said, 孩子 until then.
    var ta: String { sex == "girl" ? "她" : sex == "boy" ? "他" : "孩子" }
    var drawsGirl: Bool { (look ?? (sex == "girl" ? "girl" : "boy")) == "girl" }

    func ticked(_ m: Int, _ kind: String, _ id: String) -> Bool { ticks[tickKey(m, kind, id)] != nil }
    func toggle(_ m: Int, _ kind: String, _ id: String, _ label: String) {
        let k = tickKey(m, kind, id)
        // a tick is the child's own record (a vaccine given, a check-up done, a milestone seen): kept only with consent;
        // taking one off is always allowed
        if ticks[k] != nil { ticks[k] = nil } else if !mayKeep() { return } else { ticks[k] = Tick(key: k, month: m, kind: kind, label: label, at: Date().timeIntervalSince1970 * 1000) }
    }
    func count(_ m: Int, _ kind: String) -> Int { ticks.values.filter { $0.month == m && $0.kind == kind }.count }

    /// This week's plays for the child's month.
    func weekShelf(_ m: Int) -> (plays: [Play], stale: Bool) { Shelf.current(content, m, stored: shelf, today: today) }
    func setShelf(_ codes: [String]) { shelf = Shelf.format(today, codes) }
    /// Turns the week by itself when it has gone by, and replaces what the child has outgrown — done when the app
    /// comes forward, never while a page is being drawn.
    func rollWeek(played: (String) -> Int = { _ in 0 }, fresh: Bool = false) {
        guard let m = babyMonth, let next = Shelf.roll(content, m, stored: shelf, today: today, played: played, fresh: fresh) else { return }
        shelf = next
        // a week chosen anew: a play picked for today that is not in it no longer stands
        if fresh, let c = Shelf.pick(pick, today: today), !(Shelf.parse(next)?.codes.contains(c) ?? false) { pick = "" }
    }

    /// The play in progress, if any.
    var playing: (play: Play, month: Int, step: Int)? {
        let p = session.split(separator: "|")
        guard p.count == 3, let pl = content.play(String(p[0])), !pl.steps.isEmpty, let m = Int(p[1]), let st = Int(p[2]) else { return nil }
        return (pl, m, max(0, min(st, pl.steps.count - 1)))
    }
    func play(_ p: Play, month: Int, at step: Int) { session = "\(p.code)|\(month)|\(step)" }
    func finishPlaying() { session = "" }

    func replaceTicks(_ l: [Tick]) { ticks = Dictionary(l.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a }) }

    /// Adopts a play swapped directly on a Home Screen widget today so opening the app never resets it.
    func syncWidgetPick() {
        guard let snap = JournalFile.snapshot(),
              snap.playPickedEpochDay == today.epochDay,
              let code = snap.playCode,
              content.play(code) != nil else { return }
        let formatted = Shelf.formatPick(code, today: today)
        if pick != formatted { pick = formatted }
    }

    /// What the widget shows, written whenever it changes.
    func publish(_ j: JournalStore) {
        // the widget says the play the home page says, plus this week's shelf so the widget can swap plays inline
        let p = babyMonth.flatMap { todayPlay($0, j) }
        let code = p?.code, name = p?.name
        let pool: [PlayRef] = babyMonth.map { mo in
            let w = weekShelf(mo).plays
            let list = w.count >= 2 ? w : Array(content.plays(of: mo).prefix(4))
            return list.map { PlayRef(code: $0.code, name: $0.name) }
        } ?? []
        let pickedDay = Shelf.pick(pick, today: today) != nil ? today.epochDay : nil
        JournalFile.writeSnapshot(Snapshot(birthEpochDay: birth?.epochDay, nickname: nickname, companion: companion.rawValue, journal: journal, playCode: code, playName: name, consented: consented, weekPlays: pool.isEmpty ? nil : pool, playPickedEpochDay: pickedDay))
        WidgetCenter.shared.reloadAllTimelines()
    }
    var publishKey: String { "\(birth?.epochDay ?? -1)|\(nickname)|\(companion.rawValue)|\(journal)|\(consented)|\(pick)|\(shelf)|\(today.epochDay)|\(language.rawValue)" }

    func clearAll() {
        for k in ["birth", "companion", "theme", "onboarded", "todayPick", "sex", "look", "nickname", "lock", "shelf", "journal", "ticks", "session", "consent",
                  "artStyle", "nightLight", "tactileSounds", "mapSeenMonth"] { d.removeObject(forKey: k) }
        JournalFile.write(JournalFile.Body())
        // everything the app wrote about the child, not only the settings: the widget's copy, the exports in the Files
        // app, files kept aside from older builds; and a timer on the Lock Screen ends at once
        JournalFile.writeSnapshot(Snapshot(birthEpochDay: nil, nickname: "", companion: Kind.moss.rawValue, journal: false, playCode: nil, playName: nil, consented: false))
        WidgetCenter.shared.reloadAllTimelines()
        let fm = FileManager.default
        try? fm.removeItem(at: DataView.exportFolder)
        try? fm.removeItem(at: fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("earlier", isDirectory: true))
        FirstPhotoStore.clearAll()
        Task { @MainActor in
            SoundscapeEngine.shared.stop()
            ToyboxAudioEngine.shared.stop()
            CapsuleStore.shared.clearAll()
            FoodAtlasStore.shared.clearAll()
        }
        Task { await LiveTimers.sync() }
        Guide.replayNextLaunch()
        birth = nil; sex = nil; look = nil; nickname = ""; shelf = ""; pick = ""; consent = ""; ticks = [:]; session = ""; journal = false; lock = false; onboarded = false
        theme = .system; companion = .moss; artStyle = .vinyl; nightLight = true; tactileSounds = true
    }

    /// Whether the guardian has agreed to the current rules (the child's information may be kept).
    var consented: Bool { consent == Consent.version }
    /// Call before keeping anything about the child: true when it may go ahead; otherwise the consent card is asked for.
    func mayKeep() -> Bool {
        if consented { return true }
        askConsent = true
        return false
    }
}
