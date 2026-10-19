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
        content, Settings(birth = birth, companion = companion, onboarded = true), today,
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
    @Test fun journal() = shot("11_journal") { JournalScreen(ui(), today, logs, JournalActions()) }
    @Test fun journalDark() = shot("12_journal_dark", dark = true) { JournalScreen(ui(timers = listOf(RunningTimer(LogType.Sleep, at(19, 30)))), today, logs, JournalActions()) }
    @Test fun you() = shot("13_you") { YouScreen(ui(), YouActions()) }
    @Test fun youOttoDark() = shot("14_you_otto_dark", dark = true, companion = Kind.Otto) { YouScreen(ui(Kind.Otto), YouActions()) }
    @Test fun topic() = shot("15_topic") { TopicScreen(content.topics.first()) {} }
    @Test fun about() = shot("16_about") { AboutScreen(content) {} }
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
}
