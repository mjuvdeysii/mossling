package app.mossling.data

import kotlinx.coroutines.flow.first
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.longOrNull
import java.time.LocalDate

/**
 * Reads a record file written by 「导出记录文件」 back in. Nothing is overwritten: a tick already set stays, an entry
 * already present (same kind, same minute) or a measurement on the same day is skipped.
 */
class Importer(private val dao: RecordDao, private val settings: SettingsRepository) {
    data class Result(val ticks: Int, val logs: Int, val skipped: Int, val birth: Boolean)
    class NotOurFile : Exception()

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    suspend fun run(text: String): Result {
        val root = runCatching { json.parseToJsonElement(text).jsonObject }.getOrNull() ?: throw NotOurFile()
        val o = root["mossling"] as? JsonObject ?: throw NotOurFile()
        return own(o)
    }

    private suspend fun own(o: JsonObject): Result {
        fun JsonObject.s(k: String) = (this[k] as? JsonPrimitive)?.content
        fun JsonObject.l(k: String) = (this[k] as? JsonPrimitive)?.longOrNull
        fun JsonObject.i(k: String) = (this[k] as? JsonPrimitive)?.intOrNull
        var birth = false
        (o["settings"] as? JsonObject)?.let { st ->
            val cur = settings.settings.first()
            st.s("birth")?.let { runCatching { LocalDate.parse(it) }.getOrNull() }?.let { if (cur.birth == null) { settings.setBirth(it); birth = true } }
            st.s("sex")?.let { if (cur.sex == null) settings.setSex(it) }
            st.s("nickname")?.let { if (cur.nickname.isBlank()) settings.setNickname(it) }
        }
        var ticks = 0; var logs = 0; var skipped = 0
        (o["ticks"] as? JsonArray)?.forEach { el ->
            val t = el as? JsonObject ?: return@forEach
            val tick = Tick(t.s("key") ?: return@forEach, t.i("month") ?: return@forEach, t.s("kind") ?: return@forEach, t.s("label") ?: "", t.l("at") ?: 0)
            if (dao.putTickIfAbsent(tick) != -1L) ticks++
        }
        (o["logs"] as? JsonArray)?.forEach { el ->
            val e = el as? JsonObject ?: return@forEach
            val x = LogEntry(type = e.s("type") ?: return@forEach, start = e.l("start") ?: return@forEach, end = e.l("end"), amount = e.i("amount"), side = e.s("side"), detail = e.s("detail"))
            if (dao.sameMinute(x.type, x.start - 60_000, x.start + 60_000) > 0) skipped++ else { dao.putLog(x); logs++ }
        }
        val have = dao.allMeasures().map { it.at }.toSet()
        (o["measures"] as? JsonArray)?.forEach { el ->
            val m = el as? JsonObject ?: return@forEach
            val at = m.l("at") ?: return@forEach
            if (at in have) skipped++ else { dao.putMeasure(Measure(at = at, weightG = m.i("weightG"), lengthMm = m.i("lengthMm"), headMm = m.i("headMm"))); logs++ }
        }
        return Result(ticks, logs, skipped, birth)
    }

}
