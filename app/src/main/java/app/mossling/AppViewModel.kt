package app.mossling

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import app.mossling.data.Content
import app.mossling.data.LogEntry
import app.mossling.data.LogType
import app.mossling.data.RunningTimer
import app.mossling.data.Settings
import app.mossling.data.Tick
import app.mossling.data.tickKey
import app.mossling.domain.Age
import app.mossling.domain.ageOn
import app.mossling.ui.ip.Kind
import app.mossling.ui.theme.ThemeMode
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flow
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
    /** the latest feed of any kind, and the latest sleep — for "how long since" on Today */
    val lastFeed: LogEntry? = null,
    val lastSleep: LogEntry? = null,
    val measures: List<app.mossling.data.Measure> = emptyList(),
) {
    val age: Age? get() = settings.birth?.let { ageOn(it, today) }
    val babyMonth: Int? get() = age?.bookMonth
    fun ticked(month: Int, kind: String, id: String) = ticks.containsKey(tickKey(month, kind, id))
    fun count(month: Int, kind: String) = ticks.values.count { it.month == month && it.kind == kind }
}

class AppViewModel(app: Application) : AndroidViewModel(app) {
    private val g = (app as MosslingApp).graph
    private val dao get() = g.db.dao()
    private val content = MutableStateFlow<Content?>(g.content.now)

    private val day: Flow<LocalDate> = flow {
        while (true) { emit(LocalDate.now()); delay(60_000) }
    }.distinctUntilChanged()

    private val base = combine(content, g.settings.settings, day, dao.ticks(), dao.timers()) { c, s, d, t, tm ->
        AppUi(c, s, d, t.associateBy { it.key }, tm, ready = c != null)
    }
    private val feeds = dao.lastOfFlow(listOf(LogType.Nurse, LogType.Bottle))
    private val sleeps = dao.lastOfFlow(listOf(LogType.Sleep))
    val ui: StateFlow<AppUi> = combine(base, feeds, sleeps, dao.measures()) { u, f, sl, ms -> u.copy(lastFeed = f, lastSleep = sl, measures = ms) }
        .stateIn(viewModelScope, SharingStarted.Eagerly, AppUi(content = g.content.now))

    /** the last 30 days of entries, for the statistics */
    val month: StateFlow<List<LogEntry>> = dao.logsSince(System.currentTimeMillis() - 31L * 86_400_000).stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
    val growth get() = g.growth

    init { viewModelScope.launch { content.value = g.content.get() } }

    /** the selected day in the journal; its entries follow it */
    val journalDay = MutableStateFlow(LocalDate.now())
    @OptIn(ExperimentalCoroutinesApi::class)
    val dayLogs: StateFlow<List<LogEntry>> = journalDay.flatMapLatest { d ->
        val z = ZoneId.systemDefault()
        dao.logs(d.atStartOfDay(z).toInstant().toEpochMilli(), d.plusDays(1).atStartOfDay(z).toInstant().toEpochMilli())
    }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun toggleTick(month: Int, kind: String, id: String, label: String, on: Boolean? = null) = viewModelScope.launch {
        val key = tickKey(month, kind, id)
        val now = ui.value.ticks.containsKey(key)
        if (on ?: !now) dao.putTick(Tick(key, month, kind, label, System.currentTimeMillis())) else dao.dropTick(key)
    }

    fun setBirth(d: LocalDate?) = viewModelScope.launch { g.settings.setBirth(d); widget() }
    fun finishOnboarding() = viewModelScope.launch { g.settings.finishOnboarding() }
    fun setCompanion(k: Kind) = viewModelScope.launch { g.settings.setCompanion(k) }
    fun setTheme(t: ThemeMode) = viewModelScope.launch { g.settings.setTheme(t) }
    fun skipToday(skip: Boolean) = viewModelScope.launch { g.settings.skipToday(if (skip) LocalDate.now().toEpochDay() else null) }
    fun setPick(v: String) = viewModelScope.launch { g.settings.setPick(v) }
    /** read once at start-up from the stored settings, so the lock is never skipped while settings load */
    fun lockOn(): Boolean = kotlinx.coroutines.runBlocking { g.settings.settings.first().lock }
    fun setLock(on: Boolean) = viewModelScope.launch { g.settings.setLock(on) }
    fun setShelf(codes: List<String>) = viewModelScope.launch { g.settings.setShelf(app.mossling.domain.Shelf.format(LocalDate.now(), codes)) }
    fun setSex(s: String?) = viewModelScope.launch { g.settings.setSex(s) }
    fun setNickname(n: String) = viewModelScope.launch { g.settings.setNickname(n); widget() }
    fun putMeasure(m: app.mossling.data.Measure) = viewModelScope.launch { dao.putMeasure(m) }
    fun dropMeasure(m: app.mossling.data.Measure) = viewModelScope.launch { dao.dropMeasure(m.id) }

    /** Writes the record file or the table to [uri] (chosen by the person in the system's save dialog). */
    fun export(uri: android.net.Uri, csv: Boolean, done: (String) -> Unit) = viewModelScope.launch {
        val ok = runCatching {
            val text = if (csv) g.exporter.csv() else g.exporter.json()
            kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                getApplication<Application>().contentResolver.openOutputStream(uri, "wt")!!.use { it.write(text.toByteArray()) }
            }
        }.isSuccess
        done(if (ok) (if (csv) "表格已导出" else "记录文件已导出") else "没有导出成功，请换一个保存位置再试")
    }
    fun exportName(csv: Boolean) = "苔生记录-" + g.exporter.fileStamp() + if (csv) ".csv" else ".json"

    /** Removes every record and setting on this phone. */
    fun clearAll(done: () -> Unit) = viewModelScope.launch {
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
            ui.value.timers.forEach { g.timers.discard(it.type) }
            g.db.clearAllTables()
        }
        g.settings.clear(); widget(); done()
    }
    fun setLastMonth(m: Int) = viewModelScope.launch { g.settings.setLastMonth(m) }

    fun startTimer(type: String, side: String? = null) = viewModelScope.launch { g.timers.start(type, side) }
    fun stopTimer(type: String, then: (LogEntry?) -> Unit = {}) = viewModelScope.launch { then(g.timers.stop(type)) }
    fun pauseTimer(type: String) = viewModelScope.launch { g.timers.togglePause(type) }
    fun switchSide(type: String) = viewModelScope.launch { g.timers.switchSide(type) }
    fun discardTimer(type: String) = viewModelScope.launch { g.timers.discard(type) }

    /** Reads a record file from the earlier handbook app; [done] gets a sentence for the snackbar. */
    fun importLegacy(uri: android.net.Uri, done: (String) -> Unit) = viewModelScope.launch {
        val msg = runCatching {
            val text = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                getApplication<Application>().contentResolver.openInputStream(uri)?.use { it.bufferedReader().readText() }
            } ?: return@runCatching "没有读取到文件"
            val c = g.content.get()
            val r = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) { g.legacy.run(text, c) }
            widget()
            listOfNotNull(
                "导入了 ${r.logs} 条手帐、${r.ticks} 项勾选",
                if (r.birth) "出生日期" else null,
                if (r.skipped > 0) "${r.skipped} 条已有，跳过" else null,
            ).joinToString("、")
        }.getOrElse { if (it is app.mossling.data.LegacyImport.NotAHandbookFile) "这不是成长手册导出的记录文件" else "没有导入成功，文件可能已损坏" }
        done(msg)
    }

    private suspend fun widget() = app.mossling.widget.TodayWidget.refresh(getApplication<Application>())
    fun addLog(e: LogEntry, then: (LogEntry) -> Unit = {}) = viewModelScope.launch { val id = dao.putLog(e); then(e.copy(id = id)); widget() }
    fun updateLog(e: LogEntry) = viewModelScope.launch { dao.updateLog(e); widget() }
    fun deleteLog(e: LogEntry) = viewModelScope.launch { dao.dropLog(e.id); widget() }
    fun restoreLog(e: LogEntry) = viewModelScope.launch { dao.putLog(e.copy(id = 0)); widget() }
}
