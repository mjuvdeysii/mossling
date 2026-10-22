package app.mossling.data

import android.content.Context
import kotlinx.coroutines.flow.first
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * Writes everything recorded into one file the family keeps (all ticks, entries, measurements and settings), and a
 * table of entries and measurements for a spreadsheet or the doctor.
 */
class Exporter(private val context: Context, private val dao: RecordDao, private val settings: SettingsRepository) {
    private val pretty = Json { prettyPrint = false }

    suspend fun json(): String {
        val s = settings.settings.first()
        val ticks = dao.allTicks(); val logs = dao.allLogs(); val measures = dao.allMeasures()
        val root = buildJsonObject {
            put("app", "mossling"); put("v", 1); put("at", Instant.now().toString())
            put("mossling", buildJsonObject {
                put("v", 1)
                put("settings", buildJsonObject {
                    s.birth?.let { put("birth", it.toString()) }; s.sex?.let { put("sex", it) }
                    if (s.nickname.isNotBlank()) put("nickname", s.nickname); put("companion", s.companion.name)
                })
                put("ticks", buildJsonArray { ticks.forEach { t -> add(buildJsonObject { put("key", t.key); put("month", t.month); put("kind", t.kind); put("label", t.label); put("at", t.at) }) } })
                put("logs", buildJsonArray { logs.forEach { e -> add(buildJsonObject {
                    put("type", e.type); put("start", e.start); e.end?.let { put("end", it) }; e.amount?.let { put("amount", it) }
                    e.side?.let { put("side", it) }; e.detail?.let { put("detail", it) } }) } })
                put("measures", buildJsonArray { measures.forEach { m -> add(buildJsonObject {
                    put("at", m.at); m.weightG?.let { put("weightG", it) }; m.lengthMm?.let { put("lengthMm", it) }; m.headMm?.let { put("headMm", it) } }) } })
            })
        }
        return pretty.encodeToString(JsonObject.serializer(), root)
    }

    /** One row per entry, for a spreadsheet or the doctor. */
    suspend fun csv(): String {
        val z = ZoneId.systemDefault(); val d = DateTimeFormatter.ofPattern("yyyy-MM-dd"); val t = DateTimeFormatter.ofPattern("HH:mm")
        fun day(ms: Long) = Instant.ofEpochMilli(ms).atZone(z).format(d)
        fun hm(ms: Long) = Instant.ofEpochMilli(ms).atZone(z).format(t)
        fun q(v: String) = if (v.any { it == ',' || it == '"' || it == '\n' }) "\"" + v.replace("\"", "\"\"") + "\"" else v
        val names = mapOf(LogType.Nurse to "亲喂", LogType.Bottle to "瓶喂", LogType.Sleep to "睡觉", LogType.Diaper to "尿布", LogType.Solid to "辅食",
            LogType.Bath to "洗澡", LogType.Temp to "体温", LogType.Medicine to "用药", LogType.Note to "备注", LogType.Play to "一起玩")
        val sb = StringBuilder("﻿日期,开始,结束,时长（分钟）,类型,数量,单位,侧,详情\n")
        dao.allLogs().forEach { e ->
            val (amt, unit) = when (e.type) { LogType.Bottle -> "${e.amount ?: ""}" to "毫升"; LogType.Temp -> (e.amount?.let { "%.1f".format(it / 10.0) } ?: "") to "°C"; else -> "" to "" }
            val side = when (e.side) { "l" -> "左"; "r" -> "右"; else -> "" }
            val detail = when (e.type) { LogType.Diaper -> when (e.detail) { "wet" -> "湿"; "dirty" -> "便"; "both" -> "湿和便"; else -> "" }; else -> e.detail ?: "" }
            sb.append(listOf(day(e.start), hm(e.start), e.end?.let(::hm) ?: "", e.end?.let { "${(it - e.start) / 60_000}" } ?: "", names[e.type] ?: e.type, amt, unit, side, q(detail)).joinToString(",")).append('\n')
        }
        dao.allMeasures().forEach { m ->
            listOfNotNull(m.weightG?.let { "体重" to "%.2f".format(it / 1000.0) to "千克" }, m.lengthMm?.let { "身长" to "%.1f".format(it / 10.0) to "厘米" }, m.headMm?.let { "头围" to "%.1f".format(it / 10.0) to "厘米" })
                .forEach { (kv, unit) -> sb.append(listOf(day(m.at), hm(m.at), "", "", kv.first, kv.second, unit, "", "").joinToString(",")).append('\n') }
        }
        return sb.toString()
    }

    fun fileStamp(): String = LocalDate.now().format(DateTimeFormatter.BASIC_ISO_DATE)
}
