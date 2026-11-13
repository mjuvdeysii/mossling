package app.mossling

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import app.mossling.data.Content
import app.mossling.data.First
import app.mossling.data.LogEntry
import app.mossling.data.LogType
import app.mossling.data.Measure
import app.mossling.data.Play
import app.mossling.data.RunningTimer
import app.mossling.data.Settings
import app.mossling.data.Tick
import app.mossling.data.TickKind
import app.mossling.data.tickKey
import app.mossling.domain.Age
import app.mossling.domain.PlayRecord
import app.mossling.domain.Shelf
import app.mossling.domain.ageOn
import app.mossling.domain.computePlayRecords
import app.mossling.domain.playCodeOf
import app.mossling.ui.ip.Kind
import app.mossling.ui.theme.ThemeMode
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.ZoneId

data class AppUi(
    val content: Content? = null,
    val settings: Settings = Settings(),
    val today: LocalDate = LocalDate.now(),
    val ticks: Map<String, Tick> = emptyMap(),
    val timers: List<RunningTimer> = emptyList(),
    val ready: Boolean = false,
    val measures: List<Measure> = emptyList(),
    val firsts: List<First> = emptyList(),
    val allLogs: List<LogEntry> = emptyList(),
    val lastFeed: LogEntry? = null,
    val lastSleep: LogEntry? = null,
    val lastDiaper: LogEntry? = null,
) {
    val age: Age? get() = settings.birth?.let { ageOn(it, today) }

    fun playRecords(month: Int = age?.bookMonth ?: 0): Map<String, PlayRecord> =
        computePlayRecords(ticks, allLogs, month, today)

    fun playedCodes(): Set<String> = buildSet {
        ticks.values.filter { it.kind == TickKind.Did }.forEach { add(it.key.substringAfterLast(":")) }
        allLogs.filter { it.type == LogType.Play }.forEach { playCodeOf(it.detail)?.let(::add) }
    }
}

class AppViewModel(app: Application) : AndroidViewModel(app) {
    private val g = (app as MosslingApp).graph
    private val dao = g.db.dao()
    private val content = MutableStateFlow<Content?>(null)
    val growth get() = g.growth
    val updater get() = g.updater

    init {
        viewModelScope.launch { content.value = g.content.get() }
    }

    private data class CoreState(
        val c: Content?,
        val s: Settings,
        val t: List<Tick>,
        val r: List<RunningTimer>,
        val m: List<Measure>,
    )

    private val core = combine(
        content,
        g.settings.settings,
        dao.ticks(),
        dao.timers(),
        dao.measures(),
    ) { c, s, t, r, m -> CoreState(c, s, t, r, m) }

    private val extra = combine(
        dao.firsts(),
        dao.logsFlow(),
        dao.latestOf(listOf(LogType.Nurse, LogType.Bottle)),
        dao.latestOf(listOf(LogType.Sleep)),
        dao.latestOf(listOf(LogType.Diaper)),
    ) { firsts, logs, lf, ls, ld ->
        ExtraState(firsts, logs, lf, ls, ld)
    }

    private data class ExtraState(
        val firsts: List<First>,
        val logs: List<LogEntry>,
        val lastFeed: LogEntry?,
        val lastSleep: LogEntry?,
        val lastDiaper: LogEntry?,
    )

    val ui: StateFlow<AppUi> = combine(core, extra) { (c, s, t, r, m), ex ->
        val today = LocalDate.now()
        val tickMap = t.associateBy { it.key }
        // Auto-roll shelf if needed
        if (c != null) {
            val month = s.birth?.let { ageOn(it, today).bookMonth } ?: 0
            val played = buildSet {
                t.filter { it.kind == TickKind.Did }.forEach { add(it.key.substringAfterLast(":")) }
                ex.logs.filter { it.type == LogType.Play }.forEach { playCodeOf(it.detail)?.let(::add) }
            }
            val rolled = Shelf.roll(c, month, s.shelf, today, played)
            if (rolled != null && rolled != s.shelf) {
                viewModelScope.launch { g.settings.setShelf(rolled) }
            }
        }
        AppUi(
            content = c,
            settings = s,
            today = today,
            ticks = tickMap,
            timers = r,
            ready = c != null,
            measures = m,
            firsts = ex.firsts,
            allLogs = ex.logs,
            lastFeed = ex.lastFeed,
            lastSleep = ex.lastSleep,
            lastDiaper = ex.lastDiaper,
        )
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), AppUi())

    fun setBirth(d: LocalDate?) = viewModelScope.launch {
        g.settings.setBirth(d)
        val c = content.value ?: return@launch
        val month = d?.let { ageOn(it, LocalDate.now()).bookMonth } ?: 0
        val played = ui.value.playedCodes()
        Shelf.roll(c, month, "", LocalDate.now(), played, fresh = true)?.let { g.settings.setShelf(it) }
    }

    fun skipOnboarding() = viewModelScope.launch { g.settings.skipOnboarding() }
    fun setCompanion(k: Kind) = viewModelScope.launch { g.settings.setCompanion(k) }
    fun setTheme(m: ThemeMode) = viewModelScope.launch { g.settings.setTheme(m) }
    fun setNightLight(on: Boolean) = viewModelScope.launch { g.settings.setNightLight(on) }
    fun setJournal(on: Boolean) = viewModelScope.launch { g.settings.setJournal(on) }
    fun setSex(s: String?) = viewModelScope.launch { g.settings.setSex(s) }
    fun setLook(l: String?) = viewModelScope.launch { g.settings.setLook(l) }
    fun setNickname(n: String) = viewModelScope.launch { g.settings.setNickname(n) }
    fun setAppLock(on: Boolean) = viewModelScope.launch { g.settings.setAppLock(on) }
    fun setShelf(codes: List<String>) = viewModelScope.launch { g.settings.setShelf(Shelf.format(Shelf.week(LocalDate.now()), codes)) }

    fun rollShelf() = viewModelScope.launch {
        val u = ui.value
        val c = u.content ?: return@launch
        val month = u.age?.bookMonth ?: 0
        val prev = Shelf.parse(u.settings.shelf)?.second.orEmpty()
        val next = Shelf.suggest(c, month, u.playedCodes(), prev).map { it.code }
        if (next.isNotEmpty()) {
            g.settings.setShelf(Shelf.format(Shelf.week(LocalDate.now()), next))
        }
    }

    fun pickToday(code: String) = viewModelScope.launch { g.settings.setTodayPick(Shelf.formatPick(LocalDate.now(), code)) }
    fun saveSession(code: String, month: Int, step: Int) = viewModelScope.launch { g.settings.saveSession(code, month, step) }
    fun clearSession(code: String? = null) = viewModelScope.launch { g.settings.clearSession(code) }

    fun acceptConsent() = viewModelScope.launch { g.settings.acceptConsent() }
    fun declineConsent() = viewModelScope.launch { g.settings.declineConsent() }
    fun withdrawConsent() = viewModelScope.launch { g.settings.withdrawConsent() }

    fun lockOn(): Boolean = ui.value.settings.appLock
    fun putMeasure(m: Measure) = viewModelScope.launch { dao.putMeasure(m) }
    fun dropMeasure(id: Long) = viewModelScope.launch { dao.dropMeasure(id) }
    fun putFirst(f: First) = viewModelScope.launch { dao.putFirst(f) }
    fun dropFirst(id: Long) = viewModelScope.launch { dao.dropFirst(id) }

    fun toggleTick(month: Int, kind: String, item: String, label: String = item) = viewModelScope.launch {
        val key = tickKey(month, kind, item)
        val wasDone = key in ui.value.ticks
        if (wasDone) {
            dao.dropTick(key)
        } else {
            val now = System.currentTimeMillis()
            dao.putTick(Tick(key, month, kind, label, now))
            if (kind == TickKind.Did) {
                val play = ui.value.content?.play(item)
                val detail = if (play != null) "${play.code} ${play.name}" else "$item $label"
                dao.putLog(LogEntry(type = LogType.Play, start = now, detail = detail))
            }
        }
    }

    /** Records one completed play session (even if already played before, increments the play count in logs). */
    fun recordPlay(play: Play, month: Int, note: String? = null) = viewModelScope.launch {
        val now = System.currentTimeMillis()
        val key = tickKey(month, TickKind.Did, play.code)
        dao.putTick(Tick(key, month, TickKind.Did, play.name, now))
        val detail = "${play.code} ${play.name}" + (note?.trim()?.takeIf { it.isNotBlank() }?.let { " · $it" } ?: "")
        dao.putLog(LogEntry(type = LogType.Play, start = now, detail = detail))
        g.settings.clearSession(play.code)
    }

    fun logsForDay(day: LocalDate): Flow<List<LogEntry>> {
        val z = ZoneId.systemDefault()
        val a = day.atStartOfDay(z).toInstant().toEpochMilli()
        val b = day.plusDays(1).atStartOfDay(z).toInstant().toEpochMilli()
        return dao.logsBetween(a, b)
    }

    fun allLogs(): Flow<List<LogEntry>> = dao.logsFlow()

    private val ctx get() = getApplication<Application>()

    fun log(e: LogEntry, onSaved: (LogEntry) -> Unit = {}) = viewModelScope.launch {
        val id = dao.putLog(e)
        app.mossling.widget.TodayWidget.refresh(ctx)
        onSaved(e.copy(id = id))
    }

    fun dropLog(id: Long) = viewModelScope.launch {
        dao.dropLog(id)
        app.mossling.widget.TodayWidget.refresh(ctx)
    }

    fun startTimer(type: String, side: String? = null) = viewModelScope.launch { g.timers.start(type, side) }
    fun pauseTimer(type: String) = viewModelScope.launch { g.timers.togglePause(type) }
    fun switchTimerSide(type: String) = viewModelScope.launch { g.timers.switchSide(type) }
    fun tapNurseSide(side: String) = viewModelScope.launch { g.timers.tapSide(side) }
    fun shiftTimer(type: String, deltaMs: Long) = viewModelScope.launch { g.timers.shift(type, deltaMs) }
    fun stopTimer(type: String, onSaved: (LogEntry) -> Unit = {}) = viewModelScope.launch { g.timers.stop(type)?.let(onSaved) }
    fun discardTimer(type: String) = viewModelScope.launch { g.timers.discard(type) }

    fun shareJson() = viewModelScope.launch { g.exporter.shareJson() }
    fun shareCsv() = viewModelScope.launch { g.exporter.shareCsv() }
    fun shareSummary() = viewModelScope.launch {
        val c = content.value ?: g.content.get()
        g.exporter.shareSummary(c, g.growth)
    }

    fun importJson(uri: Uri, onResult: (String) -> Unit) = viewModelScope.launch(Dispatchers.IO) {
        val msg = runCatching {
            val raw = getApplication<Application>().contentResolver.openInputStream(uri)?.use { it.bufferedReader().readText() }
                ?: error("无法读取文件")
            g.importer.restore(raw).getOrThrow()
        }.fold(
            onSuccess = {
                app.mossling.widget.TodayWidget.refresh(ctx)
                "已导入 $it 条记录"
            },
            onFailure = { "未能导入：${it.message ?: "格式不对"}" },
        )
        onResult(msg)
    }

    fun clearAll() = viewModelScope.launch {
        dao.clearTicks()
        dao.clearLogs()
        dao.clearTimers()
        dao.clearMeasures()
        dao.clearFirsts()
        g.settings.clear()
    }
}
