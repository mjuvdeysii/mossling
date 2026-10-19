package app.mossling

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import app.mossling.data.Content
import app.mossling.data.LogEntry
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

    val ui: StateFlow<AppUi> = combine(content, g.settings.settings, day, dao.ticks(), dao.timers()) { c, s, d, t, tm ->
        AppUi(c, s, d, t.associateBy { it.key }, tm, ready = c != null)
    }.stateIn(viewModelScope, SharingStarted.Eagerly, AppUi(content = g.content.now))

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

    fun setBirth(d: LocalDate?) = viewModelScope.launch { g.settings.setBirth(d) }
    fun finishOnboarding() = viewModelScope.launch { g.settings.finishOnboarding() }
    fun setCompanion(k: Kind) = viewModelScope.launch { g.settings.setCompanion(k) }
    fun setTheme(t: ThemeMode) = viewModelScope.launch { g.settings.setTheme(t) }
    fun skipToday(skip: Boolean) = viewModelScope.launch { g.settings.skipToday(if (skip) LocalDate.now().toEpochDay() else null) }
    fun setPick(v: String) = viewModelScope.launch { g.settings.setPick(v) }
    fun setLastMonth(m: Int) = viewModelScope.launch { g.settings.setLastMonth(m) }

    fun startTimer(type: String, side: String? = null) = viewModelScope.launch { g.timers.start(type, side) }
    fun stopTimer(type: String, then: (LogEntry?) -> Unit = {}) = viewModelScope.launch { then(g.timers.stop(type)) }
    fun pauseTimer(type: String) = viewModelScope.launch { g.timers.togglePause(type) }
    fun switchSide(type: String) = viewModelScope.launch { g.timers.switchSide(type) }
    fun discardTimer(type: String) = viewModelScope.launch { g.timers.discard(type) }

    fun addLog(e: LogEntry, then: (LogEntry) -> Unit = {}) = viewModelScope.launch { val id = dao.putLog(e); then(e.copy(id = id)) }
    fun updateLog(e: LogEntry) = viewModelScope.launch { dao.updateLog(e) }
    fun deleteLog(e: LogEntry) = viewModelScope.launch { dao.dropLog(e.id) }
    fun restoreLog(e: LogEntry) = viewModelScope.launch { dao.putLog(e.copy(id = 0)) }
}
