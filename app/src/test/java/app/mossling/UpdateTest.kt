package app.mossling

import app.mossling.domain.Update
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UpdateTest {
    @Test fun compares() {
        assertTrue(Update.newer("0.2.0", "0.1.1"))
        assertTrue(Update.newer("0.1.2", "0.1.1.1012"))
        assertFalse(Update.newer("0.1.1", "0.1.1.1012"))
        assertFalse(Update.newer("0.1.0", "0.1.1"))
        assertFalse(Update.newer("0.1.1", "0.1.1"))
        assertTrue(Update.newer("1.0.0", "0.9.9"))
    }
    @Test fun parsesRelease() {
        val r = Update.parse("""{"tag_name":"v0.2.0","body":"新的成长地图","html_url":"https://x/y","published_at":"2026-10-20T01:00:00Z",
            "assets":[{"name":"notes.txt","browser_download_url":"https://x/n"},{"name":"mossling-0.2.0.apk","browser_download_url":"https://x/a.apk"}]}""")
        assertEquals("0.2.0", r.version); assertEquals("https://x/a.apk", r.apk); assertEquals("2026-10-20", r.date)
    }
}
