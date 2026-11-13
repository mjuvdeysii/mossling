package app.mossling

import app.mossling.data.ContentJson
import app.mossling.data.First
import app.mossling.data.LogEntry
import app.mossling.data.LogType
import app.mossling.data.Measure
import app.mossling.data.RunningTimer
import app.mossling.data.Settings
import app.mossling.data.Tick
import app.mossling.data.TickKind
import app.mossling.data.tickKey
import app.mossling.domain.Shelf
import app.mossling.domain.computePlayRecords
import app.mossling.domain.playedInMonth
import app.mossling.journal.Timers
import app.mossling.ui.ip.MascotEvent
import app.mossling.ui.ip.MascotMachine
import app.mossling.ui.ip.MascotPresentationState
import app.mossling.ui.ip.MascotStyle
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate
import java.time.ZoneId

class ParityTest {

    @Test
    fun mascotStyleHasNoStringFieldsAndFastAcknowledge() {
        val stringFields = MascotStyle::class.java.declaredFields.filter { it.type == String::class.java }
        assertTrue("MascotStyle must never carry String fields (docs/IP.md §3.3)", stringFields.isEmpty())

        for (kind in app.mossling.ui.ip.Kind.entries) {
            val style = MascotStyle.of(kind)
            assertTrue("acknowledgeMs must be <= 550ms", style.acknowledgeMs <= 550)
        }
    }

    @Test
    fun mascotMachineTransitionsMatchSpec() {
        val machine = MascotMachine()
        assertEquals(MascotPresentationState.Idle, machine.state)

        assertEquals(MascotPresentationState.Focusing, machine.send(MascotEvent.RecordStartConfirmed))
        assertEquals(MascotPresentationState.Acknowledge, machine.send(MascotEvent.RecordPersistSuccess))
        assertEquals(MascotPresentationState.Idle, machine.send(MascotEvent.PresentationSettle))
        assertEquals(MascotPresentationState.Rest, machine.send(MascotEvent.NightmodeEnabled))
        assertEquals(MascotPresentationState.Dormant, machine.send(MascotEvent.AppBackground))
        assertEquals(MascotPresentationState.Rest, machine.send(MascotEvent.AppActive))
        assertEquals(MascotPresentationState.Idle, machine.send(MascotEvent.NightmodeDisabled))
    }

    @Test
    fun shelfSuggestAndFirstPickUnplayedAndDiverseAreas() {
        val content = ContentJson.parse(File("src/main/assets/content.json").readText())
        val today = LocalDate.of(2026, 10, 21) // Wednesday so yesterday is in the same Monday-based week
        val suggestions = Shelf.suggest(c = content, month = 6, played = emptySet(), lastWeek = emptyList())
        assertEquals(3, suggestions.size)
        val distinctAreas = suggestions.mapNotNull { it.domains.firstOrNull() }.distinct()
        assertTrue("Shelf suggestions should cover multiple Montessori areas", distinctAreas.size >= 2)

        val rolled = Shelf.roll(
            c = content,
            month = 6,
            saved = "",
            today = today,
            played = setOf(suggestions.first().code),
        )
        assertNotNull(rolled)
        val parsed = Shelf.parse(rolled!!)
        assertNotNull(parsed)
        assertEquals(Shelf.week(today), parsed!!.first)
        assertFalse("Newly rolled shelf should prefer unplayed activities", parsed.second.contains(suggestions.first().code))

        val (shelfPlays, _) = Shelf.current(content, 6, rolled, today, emptySet())
        val firstCode = shelfPlays.first().code
        val zone = ZoneId.systemDefault()
        val playTime = today.minusDays(1).atTime(10, 0).atZone(zone).toInstant().toEpochMilli()

        val records = computePlayRecords(
            ticks = mapOf(tickKey(6, TickKind.Did, firstCode) to Tick(tickKey(6, TickKind.Did, firstCode), 6, TickKind.Did, "Test", playTime)),
            logs = listOf(LogEntry(id = 1, type = LogType.Play, start = playTime, detail = "$firstCode 玩法")),
            month = 6,
            today = today,
            zone = zone,
        )
        assertEquals(1, records[firstCode]?.total)
        assertEquals(1, records[firstCode]?.beforeTodayThisWeek)

        val picked = Shelf.first(
            shelf = shelfPlays,
            picked = null,
            weekBeforeTodayCounts = records.mapValues { it.value.beforeTodayThisWeek },
            totalCounts = records.mapValues { it.value.total },
        )
        assertNotNull(picked)
        assertFalse("Today hero card should pick an unplayed tray first", picked?.code == firstCode)
    }

    @Test
    fun nursingTimerTracksLeftAndRightSidesIndependently() {
        val t0 = RunningTimer(
            type = LogType.Nurse,
            start = 1_000_000L,
            side = "l",
            pausedAt = null,
            pausedTotal = 0L,
            carried = 0L,
            carriedPause = 0L,
        )
        // Nurse 60 seconds on Left
        assertEquals(60_000L, Timers.sideElapsed(t0, "l", 1_060_000L))
        assertEquals(0L, Timers.sideElapsed(t0, "r", 1_060_000L))

        // Switch to Right at 1_060_000L: carried becomes 60_000L
        val t1 = t0.copy(
            side = "r",
            carried = 60_000L,
            carriedPause = 0L,
        )
        // Nurse 45 seconds on Right (now = 1_105_000L)
        assertEquals(60_000L, Timers.sideElapsed(t1, "l", 1_105_000L))
        assertEquals(45_000L, Timers.sideElapsed(t1, "r", 1_105_000L))
        assertEquals(105_000L, Timers.elapsed(t1, 1_105_000L))
    }

    @Test
    fun playedInMonthAndSettingsHelpersWorkCorrectly() {
        val content = ContentJson.parse(File("src/main/assets/content.json").readText())
        val birth = LocalDate.of(2026, 4, 2)
        val zone = ZoneId.systemDefault()
        val m6Time = birth.plusMonths(6).plusDays(5).atTime(14, 0).atZone(zone).toInstant().toEpochMilli()
        val played = playedInMonth(
            content = content,
            ticks = emptyMap(),
            logs = listOf(
                LogEntry(id = 1, type = LogType.Play, start = m6Time, detail = "A11 双手物品传递机会"),
                LogEntry(id = 2, type = LogType.Play, start = m6Time + 86_400_000L, detail = "A11 双手物品传递机会"),
            ),
            birth = birth,
            month = 6,
            zone = zone,
        )
        assertEquals(1, played.size)
        assertEquals("A11", played.first().first.code)
        assertEquals(2, played.first().second)

        val settings = Settings(birth = birth, sex = "boy", look = "girl", session = "A11|6|2")
        assertEquals("他", settings.ta)
        assertTrue(settings.drawsGirl)
        assertEquals(Triple("A11", 6, 2), settings.playing)
        assertEquals(12, app.mossling.data.FirstPresets.size)
        val first = First(id = 1, at = m6Time, key = "roll", title = "第一次翻身")
        val measure = Measure(id = 1, at = m6Time, weightG = 7200)
        assertEquals("第一次翻身", first.title)
        assertEquals(7200, measure.weightG)
    }
}
