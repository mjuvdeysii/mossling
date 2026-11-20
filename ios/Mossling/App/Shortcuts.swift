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
    }
}
