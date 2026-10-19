package app.mossling.data

import android.content.Context
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull
import kotlinx.coroutines.flow.first
import java.time.LocalDate

/**
 * Reads the record file exported by the earlier handbook app (养小怪兽记录-*.json: {app:"growth-handbook", v:1, data:{"hb:…": "…"}})
 * and turns it into this app's records: the birth date, the month ticks and the journal. Nothing is overwritten:
 * a tick already set stays, an entry already present (same kind, same minute) is skipped.
 */
class LegacyImport(private val context: Context, private val dao: RecordDao, private val settings: SettingsRepository) {
    data class Result(val ticks: Int, val logs: Int, val skipped: Int, val birth: Boolean)
    class NotAHandbookFile : Exception()

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    private val keyMap: Map<String, String> by lazy {
        runCatching { json.parseToJsonElement(context.assets.open("legacy_map.json").bufferedReader().readText()).jsonObject.mapValues { it.value.jsonPrimitive.content } }.getOrDefault(emptyMap())
    }

    suspend fun run(text: String, content: Content): Result {
        val root = runCatching { json.parseToJsonElement(text).jsonObject }.getOrNull() ?: throw NotAHandbookFile()
        if (root["app"]?.jsonPrimitive?.content != "growth-handbook") throw NotAHandbookFile()
        val data = root["data"]?.jsonObject ?: throw NotAHandbookFile()
        fun str(k: String) = (data[k] as? JsonPrimitive)?.content

        var birth = false
        str("hb:birth")?.let { v -> runCatching { LocalDate.parse(v) }.getOrNull()?.let { if (settings.settings.first().birth == null) { settings.setBirth(it); birth = true } } }

        // ticks: hb:rec is {"6:c7az543":1, …}; hb:recT, when present, holds when each was made
        val made = str("hb:recT")?.let { runCatching { json.parseToJsonElement(it).jsonObject }.getOrNull() }
        var ticks = 0
        str("hb:rec")?.let { runCatching { json.parseToJsonElement(it).jsonObject }.getOrNull() }?.keys?.forEach { old ->
            val key = keyMap[old] ?: return@forEach
            val (m, kind, id) = key.split(":", limit = 3).let { Triple(it[0].toInt(), it[1], it[2]) }
            val at = (made?.get(old) as? JsonPrimitive)?.longOrNull ?: (made?.get(old) as? JsonObject)?.get("t")?.jsonPrimitive?.longOrNull ?: System.currentTimeMillis()
            dao.putTickIfAbsent(Tick(key, m, kind, label(content, m, kind, id), at)).let { if (it != -1L) ticks++ }
        }

        // journal: hb:jr:ev is [{id, k, t, e?, v:{…}}]
        var logs = 0; var skipped = 0
        str("hb:jr:ev")?.let { runCatching { json.parseToJsonElement(it).jsonArray }.getOrNull() }?.forEach { el ->
            val o = el as? JsonObject ?: return@forEach
            val e = legacyEntry(o) ?: return@forEach
            if (dao.sameMinute(e.type, e.start - 60_000, e.start + 60_000) > 0) skipped++ else { dao.putLog(e); logs++ }
        }
        return Result(ticks, logs, skipped, birth)
    }

    private fun label(c: Content, m: Int, kind: String, id: String): String {
        val mo = c.months.firstOrNull { it.month == m } ?: return ""
        return when (kind) {
            TickKind.Observed -> id.split("-").let { p -> mo.observe.getOrNull(p[0].toInt())?.items?.getOrNull(p[1].toInt()) } ?: ""
            TickKind.Did -> c.play(id)?.name ?: id
            TickKind.Vaccine -> mo.vaccines.getOrNull(id.toInt()) ?: ""
            TickKind.Checkup -> mo.checkups.getOrNull(id.toInt()) ?: ""
            else -> ""
        }
    }

}

/** One journal entry of the earlier app → one entry here (null when it has no kind or time). */
internal fun legacyEntry(o: JsonObject): LogEntry? {
    val k = o["k"]?.jsonPrimitive?.content ?: return null
    val t = o["t"]?.jsonPrimitive?.longOrNull ?: return null
    val end = o["e"]?.jsonPrimitive?.longOrNull
    val v = o["v"] as? JsonObject ?: JsonObject(emptyMap())
    fun s(n: String) = (v[n] as? JsonPrimitive)?.content?.takeIf { it.isNotBlank() }
    fun i(n: String) = (v[n] as? JsonPrimitive)?.intOrNull ?: (v[n] as? JsonPrimitive)?.doubleOrNull?.toInt()
    return when (k) {
        "nurse" -> {
            val l = i("l") ?: 0; val r = i("r") ?: 0
            LogEntry(type = LogType.Nurse, start = t, end = end, side = when { l == 0 && r == 0 -> null; l >= r -> "l"; else -> "r" },
                detail = if (l > 0 && r > 0) "left:$l,right:$r" else null)
        }
        "sleep" -> LogEntry(type = LogType.Sleep, start = t, end = end)
        "bottle" -> LogEntry(type = LogType.Bottle, start = t, amount = i("ml"))
        "diaper" -> LogEntry(type = LogType.Diaper, start = t, detail = when { i("w") == 1 && i("d") == 1 -> "both"; i("d") == 1 -> "dirty"; else -> "wet" })
        "food" -> LogEntry(type = LogType.Solid, start = t, detail = listOfNotNull(s("name"), s("amt"), if (i("first") == 1) "第一次" else null).joinToString(" · ").ifBlank { null })
        "bath" -> LogEntry(type = LogType.Bath, start = t)
        "note" -> LogEntry(type = LogType.Note, start = t, detail = s("txt"))
        // kinds this app does not keep as their own type are kept as notes, so nothing is lost
        else -> {
            val name = mapOf("vitd" to "维生素 D", "play" to "一起玩", "temp" to "体温", "grow" to "生长", "care" to "接种儿保", "react" to "辅食观察")[k] ?: k
            val bits = listOfNotNull(
                s("title"), s("name"), s("txt"), s("food"),
                s("c")?.let { "$it °C" }, s("kg")?.let { "$it 千克" }, s("cm")?.let { "$it 厘米" }, s("l")?.takeIf { k == "grow" }?.let { "身长 $it 厘米" },
            )
            LogEntry(type = LogType.Note, start = t, end = end, detail = (listOf(name) + bits).joinToString(" · "))
        }
    }
}
