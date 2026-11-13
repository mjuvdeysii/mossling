package app.mossling.data

import app.mossling.ui.components.ArtStyle
import app.mossling.ui.ip.Kind
import app.mossling.ui.theme.ThemeMode
import kotlinx.serialization.json.Json
import java.time.LocalDate

private val json = Json { ignoreUnknownKeys = true }
private val validTypes = setOf(
    LogType.Nurse, LogType.Bottle, LogType.Sleep, LogType.Diaper, LogType.Solid,
    LogType.Bath, LogType.Temp, LogType.Med, LogType.Note, LogType.Play,
)
private val validKinds = setOf(TickKind.Did, TickKind.Observed, TickKind.Vaccine, TickKind.Checkup)

/**
 * Restores a JSON file exported by `Exporter` or iOS `RecordFile`.
 * Merges into existing records without duplicating entries; checks every field before writing.
 */
class Importer(private val dao: RecordDao, private val settings: SettingsRepository) {
    suspend fun restore(raw: String): Result<Int> = runCatching {
        require(raw.length <= 10_000_000) { "文件过大" }
        val p = json.decodeFromString<ExportPayload>(raw)
        require(p.app == "Mossling") { "不是摸索台灯的记录文件" }

        val st = p.settings
        val birthStr = st?.birth ?: p.birth
        birthStr?.let { runCatching { LocalDate.parse(it) }.getOrNull() }?.let { settings.setBirth(it) }

        val compStr = st?.companion ?: p.companion
        runCatching { Kind.valueOf(compStr) }.getOrNull()?.let { settings.setCompanion(it) }

        val themeStr = st?.theme ?: p.theme
        themeStr?.let { runCatching { ThemeMode.valueOf(it) }.getOrNull() }?.let { settings.setTheme(it) }

        (st?.nightLight ?: p.nightLight)?.let { settings.setNightLight(it) }
        (st?.artStyle ?: p.artStyle)?.let { settings.setArtStyle(ArtStyle.fromRaw(it)) }
        (st?.journal ?: p.journal)?.let { settings.setJournal(it) }
        (st?.shelf ?: p.shelf)?.takeIf { it.isNotBlank() }?.let { settings.setShelf(it) }

        val sexStr = st?.sex ?: p.sex
        sexStr?.takeIf { it == "boy" || it == "girl" }?.let { settings.setSex(it) }

        val lookStr = st?.look ?: p.look
        lookStr?.takeIf { it == "boy" || it == "girl" }?.let { settings.setLook(it) }

        val nickStr = st?.nickname ?: p.nickname
        nickStr?.takeIf { it.isNotBlank() }?.let { settings.setNickname(it.take(20)) }

        var n = 0
        p.ticks.filter { it.month in 0..36 && it.kind in validKinds && it.key.length <= 64 && it.label.length <= 200 }.forEach {
            dao.putTick(it)
            n++
        }

        val haveLogs = dao.allLogs().map { Triple(it.type, it.start, it.detail) }.toHashSet()
        p.logs.filter { it.type in validTypes && it.start > 0 && (it.end == null || it.end >= it.start) }.forEach { e ->
            if (haveLogs.add(Triple(e.type, e.start, e.detail))) {
                dao.putLog(e.copy(id = 0, detail = e.detail?.take(500)))
                n++
            }
        }

        val haveM = dao.allMeasures().map { it.at }.toHashSet()
        p.measures.filter { it.at > 0 && (it.weightG != null || it.lengthMm != null || it.headMm != null) }.forEach { m ->
            if (haveM.add(m.at)) {
                dao.putMeasure(m.copy(id = 0))
                n++
            }
        }

        val haveF = dao.allFirsts().map { it.at to it.title }.toHashSet()
        p.firsts.filter { it.at > 0 && it.title.isNotBlank() }.forEach { f ->
            if (haveF.add(f.at to f.title)) {
                dao.putFirst(f.copy(id = 0, title = f.title.take(100), note = f.note?.take(500)))
                n++
            }
        }

        p.timers.filter { (it.type == LogType.Nurse || it.type == LogType.Sleep) && it.start > 0 }.forEach { t ->
            if (dao.timer(t.type) == null) {
                dao.putTimer(t)
                n++
            }
        }

        if (p.logs.isNotEmpty() || p.timers.isNotEmpty()) settings.setJournal(true)
        n
    }
}
