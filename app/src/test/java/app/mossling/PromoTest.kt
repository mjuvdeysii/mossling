package app.mossling

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.requiredHeight
import androidx.compose.foundation.layout.requiredWidth
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.unit.dp
import app.cash.paparazzi.DeviceConfig
import app.cash.paparazzi.Paparazzi
import app.mossling.data.ContentJson
import app.mossling.data.LogEntry
import app.mossling.data.LogType
import app.mossling.data.Measure
import app.mossling.data.Settings
import app.mossling.data.Tick
import app.mossling.data.TickKind
import app.mossling.data.tickKey
import app.mossling.ui.components.ArtIndex
import app.mossling.ui.grow.GrowActions
import app.mossling.ui.grow.GrowScreen
import app.mossling.ui.ip.Kind
import app.mossling.ui.journal.JournalActions
import app.mossling.ui.journal.JournalScreen
import app.mossling.ui.play.PlayScreen
import app.mossling.ui.theme.MosslingTheme
import app.mossling.ui.theme.ThemeMode
import app.mossling.ui.today.TodayActions
import app.mossling.ui.today.TodayScreen
import com.android.resources.Density
import org.junit.Rule
import org.junit.Test
import java.io.File
import java.time.LocalDate
import java.time.ZoneId

/**
 * Full-resolution phone screens with the real illustrations, for promotion. Paparazzi caps an image at 1000 px, so a
 * 1000 × 2166 px screen (333 × 722 dp) is rendered as three 1000 px tiles: promo_<name>_<k>.png, stitched afterwards.
 */
class PromoTest {
    @get:Rule val paparazzi = Paparazzi(
        deviceConfig = DeviceConfig(screenWidth = 1000, screenHeight = 1000, xdpi = 480, ydpi = 480, density = Density.XXHIGH, softButtons = false),
        maxPercentDifference = 100.0,
    )

    init { ArtIndex.source = { File("src/main/assets/$it").inputStream() } }

    private val content by lazy { ContentJson.parse(File("src/main/assets/content.json").readText()) }
    private val today = LocalDate.of(2026, 10, 19)
    private val z = ZoneId.systemDefault()
    private fun at(h: Int, m: Int) = today.atTime(h, m).atZone(z).toInstant().toEpochMilli()
    private fun ui(companion: Kind = Kind.Moss) = AppUi(
        content, Settings(birth = LocalDate.of(2026, 4, 2), companion = companion, onboarded = true, journal = true, sex = "girl", nickname = "小满"), today,
        ticks = listOf(Tick(tickKey(6, TickKind.Did, "A11"), 6, TickKind.Did, "双手物品传递机会", 0)).associateBy { it.key },
        ready = true,
        measures = listOf(Measure(1, at(9, 0) - 200L * 86_400_000, 3300, 500, 340), Measure(2, at(9, 0) - 140L * 86_400_000, 5400, 580, 385),
            Measure(3, at(9, 0) - 80L * 86_400_000, 6600, 625, 410), Measure(4, at(9, 0) - 10L * 86_400_000, 7400, 655, 425)),
        lastFeed = LogEntry(9, LogType.Bottle, at(8, 40), amount = 120), lastSleep = LogEntry(8, LogType.Sleep, at(6, 0), at(7, 30)),
    )
    private val logs = listOf(
        LogEntry(1, LogType.Bottle, at(19, 40), amount = 120), LogEntry(2, LogType.Diaper, at(18, 5), detail = "wet"),
        LogEntry(3, LogType.Nurse, at(16, 10), at(16, 28), side = "l"), LogEntry(4, LogType.Sleep, at(13, 0), at(14, 35)),
        LogEntry(5, LogType.Bath, at(10, 20)), LogEntry(6, LogType.Solid, at(11, 30), detail = "米粉"),
    )

    private val tileDp = 1000 / 3f
    private val screenDp = 722.dp

    private fun tiles(name: String, companion: Kind = Kind.Moss, body: @Composable () -> Unit) = (0 until 3).forEach { k ->
        paparazzi.snapshot("promo_${name}_$k") {
            MosslingTheme(ThemeMode.Light, companion) {
                Box(Modifier.requiredWidth(333.33.dp).requiredHeight(tileDp.dp).clipToBounds(), contentAlignment = Alignment.TopStart) {
                    androidx.compose.material3.Surface(Modifier.wrapContentSize(Alignment.TopStart, unbounded = true).offset(y = (-k * tileDp).dp).requiredWidth(333.33.dp).requiredHeight(screenDp),
                        color = MaterialTheme.colorScheme.background, contentColor = MaterialTheme.colorScheme.onBackground) { body() }
                }
            }
        }
    }

    @Test fun today() = tiles("today") { TodayScreen(ui(), TodayActions(), now = { at(10, 0) }) }
    @Test fun grow() = tiles("grow") { GrowScreen(ui(), 6, GrowActions()) }
    @Test fun play() = tiles("play") { PlayScreen(content.play("A11")!!, 6, false, {}, {}) }
    @Test fun journal() = tiles("journal", Kind.Otto) { JournalScreen(ui(Kind.Otto), today, logs, JournalActions()) }
    @Test fun growth() = tiles("growth") {
        app.mossling.ui.growth.GrowthScreen(ui(), app.mossling.domain.Growth.parse(File("src/main/assets/who_growth.json").readText()), app.mossling.ui.growth.GrowthActions())
    }
    @Test fun map() = tiles("map") { app.mossling.ui.grow.MapScreen(ui(), open = {}) {} }
}
