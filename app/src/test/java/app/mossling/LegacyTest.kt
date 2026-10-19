package app.mossling

import app.mossling.data.LogType
import app.mossling.data.legacyEntry
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LegacyTest {
    private fun e(s: String) = legacyEntry(Json.parseToJsonElement(s).jsonObject)

    @Test fun nurseKeepsBothSides() {
        val x = e("""{"id":"a","k":"nurse","t":1000,"e":601000,"v":{"l":420,"r":180}}""")!!
        assertEquals(LogType.Nurse, x.type); assertEquals("l", x.side); assertEquals(601000L, x.end); assertEquals("left:420,right:180", x.detail)
    }
    @Test fun bottleAndDiaper() {
        assertEquals(120, e("""{"k":"bottle","t":5,"v":{"ml":120,"src":"fm"}}""")!!.amount)
        assertEquals("both", e("""{"k":"diaper","t":5,"v":{"w":1,"d":1}}""")!!.detail)
        assertEquals("dirty", e("""{"k":"diaper","t":5,"v":{"w":0,"d":1}}""")!!.detail)
    }
    @Test fun otherKindsBecomeNotes() {
        val x = e("""{"k":"grow","t":5,"v":{"kg":"7.2"}}""")!!
        assertEquals(LogType.Note, x.type); assertEquals("生长 · 7.2 千克", x.detail)
        val t = e("""{"k":"temp","t":5,"v":{"c":"37.6"}}""")!!
        assertEquals(LogType.Temp, t.type); assertEquals(376, t.amount)
    }
    @Test fun brokenEntriesAreSkipped() { assertNull(e("""{"k":"bottle"}""")); assertNull(e("""{"t":5}""")) }
}
