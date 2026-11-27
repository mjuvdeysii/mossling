import AppIntents

/// Siri & Shortcuts phrases for hands-free baby care logging (`zh-Hans` base localized via `AppShortcuts.xcstrings`).
struct MosslingShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .teal

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickLogDiaperIntent(),
            phrases: [
                "用\(.applicationName)记一次尿布",
                "用\(.applicationName)记\(\.$kind)",
            ],
            shortTitle: "记尿布",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: ToggleCareTimerIntent(),
            phrases: [
                "在\(.applicationName)开始\(\.$careType)",
            ],
            shortTitle: "照护计时",
            systemImageName: "moon.zzz.fill"
        )
        AppShortcut(
            intent: QuickLogBottleIntent(),
            phrases: [
                "用\(.applicationName)记瓶喂",
                "用\(.applicationName)记\(\.$milk)",
            ],
            shortTitle: "记瓶喂",
            systemImageName: "waterbottle.fill"
        )
        AppShortcut(
            intent: BabyCareStatusIntent(),
            phrases: [
                "用\(.applicationName)看宝宝近况",
            ],
            shortTitle: "宝宝近况",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: OpenBedsideLampIntent(),
            phrases: [
                "用\(.applicationName)打开床头夜灯",
            ],
            shortTitle: "床头夜灯",
            systemImageName: "lamp.desk.fill"
        )
        AppShortcut(
            intent: QuickLogSolidIntent(),
            phrases: [
                "用\(.applicationName)记辅食",
            ],
            shortTitle: "记辅食",
            systemImageName: "carrot.fill"
        )
    }
}
