package app.mossling

import app.mossling.domain.ageOn
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

class AgeTest {
    @Test fun sameDayOfMonth() { val a = ageOn(LocalDate.of(2026, 4, 2), LocalDate.of(2026, 10, 19)); assertEquals(6, a.months); assertEquals(17, a.days); assertEquals(14, a.toNext) }
    @Test fun endOfShortMonth() { val a = ageOn(LocalDate.of(2026, 1, 31), LocalDate.of(2026, 2, 28)); assertEquals(1, a.months); assertEquals(0, a.days) }
    @Test fun dayBefore() { val a = ageOn(LocalDate.of(2026, 4, 2), LocalDate.of(2026, 5, 1)); assertEquals(0, a.months); assertEquals(29, a.days) }
    @Test fun contentParses() { val c = app.mossling.data.ContentJson.parse(java.io.File("src/main/assets/content.json").readText()); assertEquals(37, c.months.size); assertEquals(46, c.activities.size) }
}
