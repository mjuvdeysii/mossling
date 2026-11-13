package app.mossling.data

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import app.mossling.domain.Growth
import app.mossling.domain.Indicator
import app.mossling.domain.ageOn
import kotlinx.coroutines.flow.first
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

@Serializable
data class ExportSettings(
    val companion: String = "Moss",
    val theme: String = "System",
    val nightLight: Boolean = true,
    val artStyle: String = "vinyl",
    val journal: Boolean = false,
    val shelf: String = "",
    val birth: String? = null,
    val sex: String? = null,
    val look: String? = null,
    val nickname: String? = null,
)

@Serializable
data class ExportPayload(
    val app: String = "Mossling",
    val version: Int = 2,
    val exportedAt: String,
    val birth: String? = null,
    val companion: String = "Moss",
    val sex: String? = null,
    val look: String? = null,
    val nickname: String? = null,
    val theme: String? = null,
    val nightLight: Boolean? = null,
    val artStyle: String? = null,
    val journal: Boolean? = null,
    val shelf: String? = null,
    val settings: ExportSettings? = null,
    val ticks: List<Tick> = emptyList(),
    val logs: List<LogEntry> = emptyList(),
    val measures: List<Measure> = emptyList(),
    val firsts: List<First> = emptyList(),
    val timers: List<RunningTimer> = emptyList(),
)

/**
 * Exports all local records to:
 * 1. Full JSON backup (`mossling-records-<date>.json`), cross-compatible with iOS `RecordFile`.
 * 2. UTF-8 CSV spreadsheet (`mossling-logs-<date>.csv`).
 * 3. Doctor / AI Assistant Markdown report (`mossling-summary-<date>.md`), matching iOS `RecordFile.summary`.
 */
class Exporter(
    private val context: Context,
    private val dao: RecordDao,
    private val settings: SettingsRepository,
) {
    private val json = Json { prettyPrint = true; encodeDefaults = true }
    private val zone get() = ZoneId.systemDefault()
    private val iso = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm").withZone(zone)

    suspend fun buildPayload(): ExportPayload {
        val s = settings.settings.first()
        val expSettings = ExportSettings(
            companion = s.companion.name,
            theme = s.theme.name,
            nightLight = s.nightLight,
            artStyle = s.artStyle.raw,
            journal = s.journal,
            shelf = s.shelf,
            birth = s.birth?.toString(),
            sex = s.sex,
            look = s.look,
            nickname = s.nickname.ifBlank { null },
        )
        return ExportPayload(
            exportedAt = Instant.now().toString(),
            birth = s.birth?.toString(),
            companion = s.companion.name,
            sex = s.sex,
            look = s.look,
            nickname = s.nickname.ifBlank { null },
            theme = s.theme.name,
            nightLight = s.nightLight,
            artStyle = s.artStyle.raw,
            journal = s.journal,
            shelf = s.shelf,
            settings = expSettings,
            ticks = dao.allTicks(),
            logs = dao.allLogs(),
            measures = dao.allMeasures(),
            firsts = dao.allFirsts(),
            timers = dao.timers().first(),
        )
    }

    suspend fun shareJson() {
        val p = buildPayload()
        shareFile("mossling-records-${LocalDate.now()}.json", "application/json", json.encodeToString(p))
    }

    suspend fun shareCsv() {
        val logs = dao.allLogs()
        val measures = dao.allMeasures()
        val ticks = dao.allTicks()
        val firsts = dao.allFirsts()
        val sb = StringBuilder("\uFEFF") // UTF-8 BOM for spreadsheet apps
        sb.appendLine("id,type,start,end,duration_min,amount_ml,side,detail")
        for (e in logs) {
            val dur = if (e.end != null) ((e.end - e.start) / 60000).toString() else ""
            sb.appendLine(
                listOf(
                    e.id.toString(),
                    e.type,
                    iso.format(Instant.ofEpochMilli(e.start)),
                    e.end?.let { iso.format(Instant.ofEpochMilli(it)) } ?: "",
                    dur,
                    e.amount?.toString() ?: "",
                    e.side ?: "",
                    csvCell(e.detail ?: ""),
                ).joinToString(",")
            )
        }
        for (m in measures) {
            val detail = listOfNotNull(
                m.weightG?.let { "weight_g:$it" },
                m.lengthMm?.let { "length_mm:$it" },
                m.headMm?.let { "head_mm:$it" },
            ).joinToString(";")
            sb.appendLine("${m.id},measure,${iso.format(Instant.ofEpochMilli(m.at))},,,,,${csvCell(detail)}")
        }
        for (t in ticks) {
            sb.appendLine(",tick_${t.kind},${iso.format(Instant.ofEpochMilli(t.at))},,,,,${csvCell("m${t.month}:${t.label}")}")
        }
        for (f in firsts) {
            val text = listOfNotNull(f.title, f.note?.takeIf { it.isNotBlank() }).joinToString(" · ")
            sb.appendLine("${f.id},first_${f.key},${iso.format(Instant.ofEpochMilli(f.at))},,,,,${csvCell(text)}")
        }
        shareFile("mossling-logs-${LocalDate.now()}.csv", "text/csv", sb.toString())
    }

    suspend fun shareSummary(content: Content, growth: Growth) {
        val s = settings.settings.first()
        val md = buildSummary(
            settings = s,
            ticks = dao.allTicks(),
            logs = dao.allLogs(),
            measures = dao.allMeasures(),
            firsts = dao.allFirsts(),
            timers = dao.timers().first(),
            content = content,
            growth = growth,
        )
        shareFile("mossling-summary-${LocalDate.now()}.md", "text/markdown", md)
    }

    fun buildSummary(
        settings: Settings,
        ticks: List<Tick>,
        logs: List<LogEntry>,
        measures: List<Measure>,
        firsts: List<First>,
        timers: List<RunningTimer>,
        content: Content,
        growth: Growth,
        today: LocalDate = LocalDate.now(),
    ): String {
        val sb = StringBuilder()
        sb.appendLine("# 摸索台灯 · 成长与照护记录")
        sb.appendLine()
        val name = settings.nickname.ifBlank { "未填写小名" }
        val sexLabel = when (settings.sex) {
            "girl" -> "女孩"
            "boy" -> "男孩"
            else -> "未选择"
        }
        val birthLabel = settings.birth?.toString() ?: "未填写"
        val ageLabel = settings.birth?.let { b ->
            val a = ageOn(b, today)
            if (a.days > 0) "${a.months} 个月 ${a.days} 天（出生第 ${a.lived} 天）" else "满 ${a.months} 个月（出生第 ${a.lived} 天）"
        } ?: "未计算"
        sb.appendLine("- **孩子**：$name")
        sb.appendLine("- **出生日期**：$birthLabel")
        sb.appendLine("- **当前月龄**：$ageLabel")
        sb.appendLine("- **性别**：$sexLabel")
        sb.appendLine("- **导出时间**：${iso.format(Instant.now())}")
        sb.appendLine()
        sb.appendLine("> 说明：本文件由家长在手机本地生成，供儿科门诊、儿童保健或家长自选的 AI 工具阅读参考；不代表医疗诊断。")
        sb.appendLine()

        // 1. Firsts
        if (firsts.isNotEmpty()) {
            sb.appendLine("## 第一次")
            sb.appendLine()
            sb.appendLine("| 日期 | 月龄 | 第一次 | 备注 |")
            sb.appendLine("|---|---|---|---|")
            for (f in firsts.sortedBy { it.at }) {
                val d = Instant.ofEpochMilli(f.at).atZone(zone).toLocalDate()
                val age = settings.birth?.let { b ->
                    val a = ageOn(b, d)
                    if (a.months == 0) "出生第 ${a.lived} 天" else "${a.months}月${a.days}天"
                } ?: "—"
                sb.appendLine("| $d | $age | ${mdCell(f.title)} | ${mdCell(f.note ?: "")} |")
            }
            sb.appendLine()
        }

        // 2. Growth Measurements
        if (measures.isNotEmpty()) {
            sb.appendLine("## 生长测量（对照 WHO 2006 标准）")
            sb.appendLine()
            sb.appendLine("| 日期 | 月龄 | 体重 (kg) | 身长 (cm) | 头围 (cm) |")
            sb.appendLine("|---|---|---|---|---|")
            val girl = settings.sex == "girl"
            val hasSex = settings.sex != null && settings.birth != null
            for (m in measures.sortedBy { it.at }) {
                val d = Instant.ofEpochMilli(m.at).atZone(zone).toLocalDate()
                val mAge = settings.birth?.let { ChronoUnit.DAYS.between(it, d) / 30.4375 }
                val ageStr = settings.birth?.let { b ->
                    val a = ageOn(b, d)
                    if (a.months == 0) "第${a.lived}天" else "${a.months}月${a.days}天"
                } ?: "—"
                fun cell(ind: Indicator, raw: Double?, fmt: String): String {
                    if (raw == null) return "—"
                    val v = fmt.format(raw)
                    val pct = if (hasSex && mAge != null) {
                        val p = growth.percentile(ind, girl, mAge, raw).toInt().coerceIn(1, 99)
                        " (P$p)"
                    } else ""
                    return "$v$pct"
                }
                val w = cell(Indicator.Weight, m.weightG?.div(1000.0), "%.2f")
                val l = cell(Indicator.Length, m.lengthMm?.div(10.0), "%.1f")
                val h = cell(Indicator.Head, m.headMm?.div(10.0), "%.1f")
                sb.appendLine("| $d | $ageStr | $w | $l | $h |")
            }
            sb.appendLine()
        }

        // 3. Daily summary
        if (logs.isNotEmpty()) {
            sb.appendLine("## 每天汇总")
            sb.appendLine()
            sb.appendLine("| 日期 | 亲喂 | 瓶喂 | 辅食 | 睡眠 | 尿布 | 体温/用药/备注 |")
            sb.appendLine("|---|---|---|---|---|---|---|")
            val byDay = logs.groupBy { Instant.ofEpochMilli(it.start).atZone(zone).toLocalDate() }.toSortedMap(compareByDescending { it })
            for ((day, list) in byDay) {
                val nurses = list.filter { it.type == LogType.Nurse }
                val nurseMin = nurses.sumOf { ((it.end ?: it.start) - it.start).coerceAtLeast(0) } / 60_000
                val nurseStr = if (nurses.isEmpty()) "—" else "${nurses.size}次 (${nurseMin}分)"

                val bottles = list.filter { it.type == LogType.Bottle }
                val bottleMl = bottles.sumOf { it.amount ?: 0 }
                val bottleStr = if (bottles.isEmpty()) "—" else "${bottles.size}次 (${bottleMl}ml)"

                val solids = list.filter { it.type == LogType.Solid }
                val solidStr = if (solids.isEmpty()) "—" else solids.mapNotNull { it.detail?.takeIf { d -> d.isNotBlank() } }.joinToString("、").ifBlank { "${solids.size}次" }

                val sleeps = list.filter { it.type == LogType.Sleep && it.end != null }
                val sleepHrs = sleeps.sumOf { (it.end!! - it.start).coerceAtLeast(0) } / 3_600_000.0
                val sleepStr = if (sleeps.isEmpty()) "—" else "${sleeps.size}段 (${"%.1f".format(sleepHrs)}h)"

                val diapers = list.filter { it.type == LogType.Diaper }
                val diaperStr = if (diapers.isEmpty()) "—" else "${diapers.size}片"

                val notes = buildList {
                    list.filter { it.type == LogType.Temp }.forEach { e -> e.amount?.let { add("体温 ${"%.1f".format(it / 10.0)}℃") } }
                    list.filter { it.type == LogType.Med }.forEach { e -> e.detail?.let { add("用药 $it") } }
                    list.filter { it.type == LogType.Note }.forEach { e -> e.detail?.let { add(it) } }
                }.joinToString("；").ifBlank { "—" }

                sb.appendLine("| $day | $nurseStr | $bottleStr | ${mdCell(solidStr)} | $sleepStr | $diaperStr | ${mdCell(notes)} |")
            }
            sb.appendLine()
        }

        // 4. Month-by-month ticks
        if (ticks.isNotEmpty()) {
            sb.appendLine("## 每个月记下的事")
            sb.appendLine()
            val byMonth = ticks.groupBy { it.month }.toSortedMap()
            for ((m, list) in byMonth) {
                val title = content.month(m)?.title ?: "满 $m 个月"
                sb.appendLine("### 满 $m 个月 · $title")
                val did = list.filter { it.kind == TickKind.Did }.map { it.label }
                val obs = list.filter { it.kind == TickKind.Observed }.map { it.label }
                val vac = list.filter { it.kind == TickKind.Vaccine }.map { it.label }
                val chk = list.filter { it.kind == TickKind.Checkup }.map { it.label }
                if (did.isNotEmpty()) sb.appendLine("- **玩过**：${did.joinToString("、")}")
                if (obs.isNotEmpty()) sb.appendLine("- **留意到**：${obs.joinToString("、")}")
                if (vac.isNotEmpty()) sb.appendLine("- **接种**：${vac.joinToString("、")}")
                if (chk.isNotEmpty()) sb.appendLine("- **儿保**：${chk.joinToString("、")}")
                sb.appendLine()
            }
        }

        // 5. All log entries
        if (logs.isNotEmpty()) {
            sb.appendLine("## 全部记录（按时间）")
            sb.appendLine()
            sb.appendLine("| 时间 | 类型 | 详情 |")
            sb.appendLine("|---|---|---|")
            for (e in logs.sortedByDescending { it.start }) {
                val t = iso.format(Instant.ofEpochMilli(e.start))
                val kind = when (e.type) {
                    LogType.Nurse -> "亲喂"
                    LogType.Bottle -> "瓶喂"
                    LogType.Sleep -> "睡觉"
                    LogType.Diaper -> "尿布"
                    LogType.Solid -> "辅食"
                    LogType.Bath -> "洗澡"
                    LogType.Temp -> "体温"
                    LogType.Med -> "用药"
                    LogType.Play -> "一起玩"
                    else -> "记一笔"
                }
                val detail = buildList {
                    when (e.side) {
                        "l" -> add("左侧")
                        "r" -> add("右侧")
                        "b" -> add("双侧")
                    }
                    if (e.end != null && e.end > e.start) add("${(e.end - e.start) / 60_000} 分钟")
                    if (e.type == LogType.Bottle && e.amount != null) add("${e.amount} 毫升")
                    if (e.type == LogType.Temp && e.amount != null) add("${"%.1f".format(e.amount / 10.0)} ℃")
                    e.detail?.takeIf { it.isNotBlank() }?.let { add(it) }
                }.joinToString(" · ")
                sb.appendLine("| $t | $kind | ${mdCell(detail)} |")
            }
            sb.appendLine()
        }

        // 6. Running timers
        if (timers.isNotEmpty()) {
            sb.appendLine("## 正在计时")
            sb.appendLine()
            for (t in timers) {
                val label = if (t.type == LogType.Sleep) "睡觉" else "亲喂"
                sb.appendLine("- **$label**：开始于 ${iso.format(Instant.ofEpochMilli(t.start))}${if (t.pausedAt != null) "（暂停中）" else ""}")
            }
            sb.appendLine()
        }

        return sb.toString()
    }

    private fun csvCell(s: String): String {
        val c0 = s.firstOrNull()
        val safe = if (c0 != null && c0 in charArrayOf('=', '+', '-', '@', '\t', '\r')) "'$s" else s
        return if (safe.any { it == ',' || it == '"' || it == '\n' }) "\"${safe.replace("\"", "\"\"")}\"" else safe
    }

    private fun mdCell(s: String): String = s.replace("|", "\\|").replace("\n", " ")

    private fun shareFile(name: String, mime: String, body: String) {
        val dir = File(context.cacheDir, "exports").apply { mkdirs() }
        val file = File(dir, name).apply { writeText(body) }
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(Intent.createChooser(intent, name).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }
}
