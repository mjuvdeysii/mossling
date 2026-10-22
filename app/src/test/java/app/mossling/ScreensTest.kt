package app.mossling

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.unit.dp
import app.cash.paparazzi.DeviceConfig
import app.cash.paparazzi.Paparazzi
import app.mossling.data.ContentJson
import app.mossling.data.LogEntry
import app.mossling.data.LogType
import app.mossling.data.RunningTimer
import app.mossling.data.Settings
import app.mossling.data.Tick
import app.mossling.data.TickKind
import app.mossling.data.tickKey
import app.mossling.ui.grow.GrowActions
import app.mossling.ui.grow.GrowScreen
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.Kind
import app.mossling.ui.ip.Mood
import app.mossling.ui.journal.JournalActions
import app.mossling.ui.journal.JournalScreen
import app.mossling.ui.onboarding.Onboarding
import app.mossling.ui.play.PlayScreen
import app.mossling.ui.theme.MosslingTheme
import app.mossling.ui.theme.ThemeMode
import app.mossling.ui.today.TodayActions
import app.mossling.ui.today.TodayScreen
import app.mossling.ui.you.AboutScreen
import app.mossling.ui.you.TopicScreen
import app.mossling.ui.you.YouActions
import app.mossling.ui.you.YouScreen
import org.junit.Rule
import org.junit.Test
import java.io.File
import java.time.LocalDate
import java.time.ZoneId

/** Screenshots of every screen (light/dark, Moss/Otto) — written to app/src/test/snapshots/images by recordPaparazziDebug. */
class ScreensTest {
    @get:Rule val paparazzi = Paparazzi(deviceConfig = DeviceConfig.PIXEL_6.copy(softButtons = false), maxPercentDifference = 100.0)

    private val content by lazy { ContentJson.parse(File("src/main/assets/content.json").readText()) }
    private val today = LocalDate.of(2026, 10, 19)
    private val z = ZoneId.systemDefault()
    private fun at(h: Int, m: Int) = today.atTime(h, m).atZone(z).toInstant().toEpochMilli()

    private fun ui(companion: Kind = Kind.Moss, birth: LocalDate? = LocalDate.of(2026, 4, 2), timers: List<RunningTimer> = emptyList()) = AppUi(
        content, Settings(birth = birth, companion = companion, onboarded = true, journal = true), today,
        ticks = listOf(Tick(tickKey(6, TickKind.Did, "A11"), 6, TickKind.Did, "双手物品传递机会", 0), Tick(tickKey(6, TickKind.Observed, "0-0"), 6, TickKind.Observed, "认识熟悉的人", 0)).associateBy { it.key },
        timers = timers, ready = true,
    )

    private val logs = listOf(
        LogEntry(1, LogType.Bottle, at(19, 40), amount = 120),
        LogEntry(2, LogType.Diaper, at(18, 5), detail = "wet"),
        LogEntry(3, LogType.Nurse, at(16, 10), at(16, 28), side = "l"),
        LogEntry(4, LogType.Sleep, at(13, 0), at(14, 35)),
        LogEntry(5, LogType.Bath, at(10, 20)),
    )

    private fun shot(name: String, dark: Boolean = false, companion: Kind = Kind.Moss, body: @Composable () -> Unit) =
        paparazzi.snapshot(name) {
            MosslingTheme(if (dark) ThemeMode.Dark else ThemeMode.Light, companion) {
                androidx.compose.material3.Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background, contentColor = MaterialTheme.colorScheme.onBackground) { body() }
            }
        }

    @Test fun characters() = shot("00_characters") {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(Kind.Moss, Kind.Otto).forEach { k ->
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Creature(k, Modifier.size(84.dp), look = Offset(0.9f, 0f))
                    Creature(k, Modifier.size(84.dp), look = Offset(-0.9f, 0.3f))
                    Creature(k, Modifier.size(84.dp), mood = Mood.Happy)
                    Creature(k, Modifier.size(84.dp), mood = Mood.Wow)
                    Creature(k, Modifier.size(84.dp), mood = Mood.Sleep)
                }
            }
        }
    }
    @Test fun onboarding() = shot("01_onboarding") { Onboarding({}, {}) }
    @Test fun todayMoss() = shot("02_today_moss") { TodayScreen(ui(), TodayActions(), now = { at(20, 0) }) }
    @Test fun todayOttoTimer() = shot("03_today_otto_timer", companion = Kind.Otto) { TodayScreen(ui(Kind.Otto, timers = listOf(RunningTimer(LogType.Nurse, at(19, 48), "l"))), TodayActions(), now = { at(20, 0) }) }
    @Test fun todayNoBirth() = shot("04_today_nobirth") { TodayScreen(ui(birth = null), TodayActions()) }
    @Test fun todayDark() = shot("05_today_dark", dark = true) { TodayScreen(ui(), TodayActions(), now = { at(20, 0) }) }
    @Test fun grow() = shot("06_grow") { GrowScreen(ui(), 6, GrowActions()) }
    @Test fun growPast() = shot("07_grow_past_otto", companion = Kind.Otto) { GrowScreen(ui(Kind.Otto), 2, GrowActions()) }
    @Test fun growDark() = shot("08_grow_dark", dark = true) { GrowScreen(ui(), 9, GrowActions()) }
    @Test fun play() = shot("09_play") { PlayScreen(content.play("A11")!!, 6, false, {}, {}) }
    @Test fun playDone() = shot("10_play_done_dark", dark = true, companion = Kind.Otto) { PlayScreen(content.play("A08")!!, 6, true, {}, {}) }
    @Test fun journal() = shot("11_journal") { JournalScreen(ui(), today, logs, JournalActions(), last = mapOf(LogType.Bottle to at(19, 40), LogType.Diaper to at(18, 5), LogType.Nurse to at(16, 28), LogType.Sleep to at(14, 35)), now = { at(20, 0) }) }
    @Test fun journalTimer() = shot("11b_journal_nursing") { JournalScreen(ui(timers = listOf(RunningTimer(LogType.Nurse, at(19, 42), "l"))), today, logs, JournalActions(), now = { at(20, 0) }) }
    @Test fun journalDark() = shot("12_journal_dark", dark = true) { JournalScreen(ui(timers = listOf(RunningTimer(LogType.Sleep, at(19, 30)))), today, logs, JournalActions()) }
    @Test fun you() = shot("13_you") { YouScreen(ui(), YouActions()) }
    @Test fun youOttoDark() = shot("14_you_otto_dark", dark = true, companion = Kind.Otto) { YouScreen(ui(Kind.Otto), YouActions()) }
    @Test fun topic() = shot("15_topic") { TopicScreen(content.topics.first()) {} }
    @Test fun about() = shot("16_about") { AboutScreen(content) {} }
    // the largest system font size: nothing may clip, overlap or run off the edge
    @Test fun todayLargeFont() { paparazzi.unsafeUpdateConfig(DeviceConfig.PIXEL_6.copy(softButtons = false, fontScale = 2.0f)); shot("19_today_font200") { TodayScreen(ui(), TodayActions(), now = { at(20, 0) }) } }
    @Test fun playLargeFont() { paparazzi.unsafeUpdateConfig(DeviceConfig.PIXEL_6.copy(softButtons = false, fontScale = 2.0f)); shot("20_play_font200") { PlayScreen(content.play("A11")!!, 6, false, {}, {}) } }
    @Test fun journalLargeFont() { paparazzi.unsafeUpdateConfig(DeviceConfig.PIXEL_6.copy(softButtons = false, fontScale = 2.0f)); shot("21_journal_font200") { JournalScreen(ui(), today, logs, JournalActions()) } }
    // Google Play feature graphic, 1024 × 500 at 1x
    @Test fun featureGraphic() {
        paparazzi.unsafeUpdateConfig(DeviceConfig(screenWidth = 1024, screenHeight = 500, xdpi = 160, ydpi = 160, density = com.android.resources.Density.MEDIUM, orientation = com.android.resources.ScreenOrientation.LANDSCAPE, softButtons = false))
        shot("22_feature_graphic") {
            Row(Modifier.fillMaxSize().background(app.mossling.ui.theme.Palette.Chalk).padding(horizontal = 64.dp), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    androidx.compose.material3.Text("小苔花", style = MaterialTheme.typography.displayLarge, color = app.mossling.ui.theme.Palette.MossDeep, softWrap = false, maxLines = 1)
                    androidx.compose.material3.Text("Mossling · 跟着孩子，一个月一站", style = MaterialTheme.typography.headlineSmall, color = app.mossling.ui.theme.Palette.Ink)
                    Row(Modifier.padding(top = 28.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        repeat(17) { Box(Modifier.size(12.dp).background(if (it == 16) app.mossling.ui.theme.Palette.Bead else app.mossling.ui.theme.Palette.Moss, androidx.compose.foundation.shape.CircleShape)) }
                        repeat(8) { Box(Modifier.size(12.dp).background(app.mossling.ui.theme.Palette.Stone, androidx.compose.foundation.shape.CircleShape)) }
                    }
                }
                Row(verticalAlignment = androidx.compose.ui.Alignment.Bottom) {
                    Creature(Kind.Moss, Modifier.size(190.dp), look = Offset(0.9f, -0.1f))
                    Creature(Kind.Otto, Modifier.size(230.dp), look = Offset(-0.9f, 0f))
                }
            }
        }
    }
    // store screenshots: 9:16, inside Google Play's 2:1 limit
    private fun store() = paparazzi.unsafeUpdateConfig(DeviceConfig.PIXEL_6.copy(screenHeight = 1920, softButtons = false))
    @Test fun store1() { store(); shot("store_1_today") { TodayScreen(ui(), TodayActions(), now = { at(10, 0) }) } }
    @Test fun store2() { store(); shot("store_2_grow") { GrowScreen(ui(), 6, GrowActions()) } }
    @Test fun store3() { store(); shot("store_3_play") { PlayScreen(content.play("A11")!!, 6, false, {}, {}) } }
    @Test fun store4() { store(); shot("store_4_journal_otto", companion = Kind.Otto) { JournalScreen(ui(Kind.Otto), today, logs, JournalActions()) } }
    @Test fun store5() { store(); shot("store_5_today_dark", dark = true, companion = Kind.Otto) { TodayScreen(ui(Kind.Otto, timers = listOf(RunningTimer(LogType.Nurse, at(19, 48), "l"))), TodayActions(), now = { at(20, 0) }) } }
    private val growth by lazy { app.mossling.domain.Growth.parse(File("src/main/assets/who_growth.json").readText()) }
    private fun measured() = ui().let { u -> u.copy(settings = u.settings.copy(sex = "girl", nickname = "小满"), measures = listOf(
        app.mossling.data.Measure(1, at(9, 0) - 200L * 86_400_000, 3300, 500, 340), app.mossling.data.Measure(2, at(9, 0) - 140L * 86_400_000, 5400, 580, 385),
        app.mossling.data.Measure(3, at(9, 0) - 80L * 86_400_000, 6600, 625, 410), app.mossling.data.Measure(4, at(9, 0) - 10L * 86_400_000, 7400, 655, 425))) }
    @Test fun growthChart() = shot("23_growth") { app.mossling.ui.growth.GrowthScreen(measured(), growth, app.mossling.ui.growth.GrowthActions()) }
    @Test fun growthDark() = shot("24_growth_dark", dark = true) { app.mossling.ui.growth.GrowthScreen(measured(), growth, app.mossling.ui.growth.GrowthActions()) }
    @Test fun stats() = shot("25_stats") {
        val week = (0 until 7).flatMap { d -> val b = at(8, 0) - d * 86_400_000L
            listOf(LogEntry(0, LogType.Bottle, b, amount = 120 + d * 10), LogEntry(0, LogType.Bottle, b + 4 * 3_600_000, amount = 150), LogEntry(0, LogType.Nurse, b + 7 * 3_600_000, b + 7 * 3_600_000 + 18 * 60_000, side = "l"),
                LogEntry(0, LogType.Sleep, b - 9 * 3_600_000, b - (d % 3) * 1_800_000L), LogEntry(0, LogType.Diaper, b + 3_600_000, detail = "wet"), LogEntry(0, LogType.Diaper, b + 5 * 3_600_000, detail = "both")) }
        app.mossling.ui.journal.StatsScreen(week, today) {}
    }
    @Test fun search() = shot("26_search") { app.mossling.ui.search.SearchScreen(content, {}, {}, {}, {}) }
    @Test fun todayNick() = shot("27_today_nickname_since") { TodayScreen(measured().copy(lastFeed = LogEntry(9, LogType.Bottle, at(17, 50), amount = 120), lastSleep = LogEntry(8, LogType.Sleep, at(16, 0), at(18, 55))), TodayActions(), now = { at(20, 0) }) }
    @Test fun licenses() = shot("28_licenses") { app.mossling.ui.you.LicensesScreen {} }
    @Test fun growthMap() = shot("29_growth_map") { app.mossling.ui.grow.MapScreen(measured(), open = {}) {} }
    @Test fun plan() = shot("30_week_shelf") { app.mossling.ui.plan.PlanScreen(measured(), listOf(LogEntry(0, LogType.Play, at(9, 0), detail = "A11 双手物品传递机会"), LogEntry(0, LogType.Play, at(15, 0), detail = "A11 双手物品传递机会")), app.mossling.ui.plan.PlanActions()) }
    @Test fun appAbout() = shot("31_about_app") { app.mossling.ui.you.AppAboutScreen(app.mossling.ui.you.AppAboutActions()) }
    @Test fun materials() = shot("17_materials") {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            app.mossling.ui.ip.Family.entries.chunked(2).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { row.forEach { app.mossling.ui.ip.MaterialStill(it, Modifier.weight(1f).background(MaterialTheme.colorScheme.surfaceContainer)) } }
            }
        }
    }
    @Test fun materialsDark() = shot("18_materials_dark", dark = true) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            app.mossling.ui.ip.Family.entries.forEach { app.mossling.ui.ip.MaterialStill(it, Modifier.size(200.dp, 125.dp), ground = MaterialTheme.colorScheme.surfaceContainerHigh) }
        }
    }
    @Test fun icon() = shot("32_icon") {
        Column(Modifier.padding(24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Box(Modifier.size(160.dp).background(androidx.compose.ui.graphics.Color(0xFFF4F2EC), androidx.compose.foundation.shape.CircleShape)) {
                    androidx.compose.foundation.Image(androidx.compose.ui.res.painterResource(R.drawable.ic_launcher_background), null, Modifier.fillMaxSize())
                    androidx.compose.foundation.Image(androidx.compose.ui.res.painterResource(R.drawable.ic_launcher_foreground), null, Modifier.fillMaxSize())
                }
                Box(Modifier.size(160.dp).background(androidx.compose.ui.graphics.Color(0xFF34553A), androidx.compose.foundation.shape.CircleShape)) {
                    androidx.compose.foundation.Image(androidx.compose.ui.res.painterResource(R.drawable.ic_launcher_monochrome), null, Modifier.fillMaxSize())
                }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                app.mossling.ui.ip.Duo(Kind.Moss, size = 120.dp)
                app.mossling.ui.ip.Duo(Kind.Otto, size = 120.dp)
            }
            app.mossling.ui.ip.Duo(Kind.Moss, size = 120.dp, mood = Mood.Sleep)
        }
    }
    @Test fun timeDialog() = shot("33_time_dialog") { app.mossling.ui.journal.TimeDialog("开始时间", at(16, 10), {}, {}) }
    @Test fun entrySheet() = shot("34_entry_nurse") { app.mossling.ui.journal.EntrySheet(logs[2], {}, {}, {}) }
}
