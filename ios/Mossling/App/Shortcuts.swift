import AppIntents

/// Siri & Shortcuts phrases for hands-free baby care logging (zh-Hans).
struct MosslingShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .teal

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickLogDiaperIntent(),
            phrases: [
                "用\(.applicationName)记一次尿布",
                "在\(.applicationName)记尿布",
                "用\(.applicationName)记\(\.$kind)",
                "Log a diaper in \(.applicationName)",
                "Log \(\.$kind) in \(.applicationName)",
            ],
            shortTitle: "记尿布",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: ToggleCareTimerIntent(),
            phrases: [
                "在\(.applicationName)开始\(\.$careType)",
                "用\(.applicationName)记\(\.$careType)",
                "在\(.applicationName)切换\(\.$careType)计时",
                "Start \(\.$careType) in \(.applicationName)",
                "Toggle \(\.$careType) timer in \(.applicationName)",
            ],
            shortTitle: "照护计时",
            systemImageName: "moon.zzz.fill"
        )
        AppShortcut(
            intent: QuickLogBottleIntent(),
            phrases: [
                "用\(.applicationName)记瓶喂",
                "用\(.applicationName)记\(\.$milk)",
                "在\(.applicationName)记一顿\(\.$milk)",
                "Log a bottle in \(.applicationName)",
                "Log \(\.$milk) bottle in \(.applicationName)",
            ],
            shortTitle: "记瓶喂",
            systemImageName: "waterbottle.fill"
        )
        AppShortcut(
            intent: BabyCareStatusIntent(),
            phrases: [
                "用\(.applicationName)看宝宝近况",
                "问\(.applicationName)宝宝上次喂奶",
                "Check baby status in \(.applicationName)",
                "How long since last feed in \(.applicationName)",
            ],
            shortTitle: "宝宝近况",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: OpenBedsideLampIntent(),
            phrases: [
                "用\(.applicationName)打开床头夜灯",
                "打开\(.applicationName)夜灯",
                "Open bedside lamp in \(.applicationName)",
            ],
            shortTitle: "床头夜灯",
            systemImageName: "lamp.desk.fill"
        )
        AppShortcut(
            intent: QuickLogSolidIntent(),
            phrases: [
                "用\(.applicationName)记辅食",
                "在\(.applicationName)记宝宝吃辅食",
                "用\(.applicationName)记一顿辅食",
                "Log first food in \(.applicationName)",
            ],
            shortTitle: "记辅食",
            systemImageName: "carrot.fill"
        )
    }
}
