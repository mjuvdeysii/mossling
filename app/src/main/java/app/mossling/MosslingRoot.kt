package app.mossling

import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.NavigationRail
import androidx.compose.material3.NavigationRailItem
import androidx.compose.material3.NavigationRailItemDefaults
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.toRoute
import app.mossling.data.LogEntry
import app.mossling.data.LogType
import app.mossling.data.TickKind
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.grow.GrowActions
import app.mossling.ui.grow.GrowScreen
import app.mossling.ui.journal.Ask
import app.mossling.ui.journal.AskSheet
import app.mossling.ui.journal.EntrySheet
import app.mossling.ui.journal.JournalActions
import app.mossling.ui.journal.JournalScreen
import app.mossling.ui.journal.askFor
import app.mossling.ui.journal.logKind
import app.mossling.ui.onboarding.BirthDialog
import app.mossling.ui.onboarding.Onboarding
import app.mossling.ui.play.PlayScreen
import app.mossling.ui.theme.MosslingTheme
import app.mossling.ui.today.TodayActions
import app.mossling.ui.today.TodayScreen
import app.mossling.ui.today.todaysPlays
import app.mossling.ui.you.AboutScreen
import app.mossling.ui.you.TopicScreen
import app.mossling.ui.you.YouActions
import app.mossling.ui.you.YouScreen
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

@Serializable object TodayRoute
@Serializable object GrowRoute
@Serializable object JournalRoute
@Serializable object YouRoute
@Serializable data class PlayRoute(val code: String, val month: Int)
@Serializable data class TopicRoute(val id: String)
@Serializable object AboutRoute

// key: the route string Navigation derives from the serial name (stable under R8, unlike class names)
private data class Tab(val route: Any, val label: String, val glyph: G, val key: String)
private val Tabs = listOf(
    Tab(TodayRoute, "今天", G.Today, "app.mossling.TodayRoute"), Tab(GrowRoute, "成长", G.Grow, "app.mossling.GrowRoute"),
    Tab(JournalRoute, "手帐", G.Journal, "app.mossling.JournalRoute"), Tab(YouRoute, "我的", G.You, "app.mossling.YouRoute"),
)

@Composable
fun MosslingRoot(vm: AppViewModel, open: MutableStateFlow<String?>, askNotifications: () -> Unit = {}) {
    val ui by vm.ui.collectAsStateWithLifecycle()
    MosslingTheme(ui.settings.theme, ui.settings.companion) {
        // a Surface, not a bare background: it also sets the content colour, so text is right in the dark theme
        Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background, contentColor = MaterialTheme.colorScheme.onBackground) {
            if (!ui.ready) return@Surface
            var birthDialog by remember { mutableStateOf(false) }
            if (!ui.settings.onboarded) Onboarding(onBirth = { birthDialog = true }, onSkip = vm::finishOnboarding)
            else Shell(vm, open, askNotifications) { birthDialog = true }
            if (birthDialog) BirthDialog(ui.settings.birth, onPick = { vm.setBirth(it) }, onDismiss = { birthDialog = false })
        }
    }
}

@Composable
private fun Shell(vm: AppViewModel, open: MutableStateFlow<String?>, askNotifications: () -> Unit, askBirth: () -> Unit) {
    val ui by vm.ui.collectAsStateWithLifecycle()
    val logs by vm.dayLogs.collectAsStateWithLifecycle()
    val day by vm.journalDay.collectAsStateWithLifecycle()
    val nav = rememberNavController()
    val back by nav.currentBackStackEntryAsState()
    val snack = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val haptic = LocalHapticFeedback.current
    var browse by rememberSaveable { mutableStateOf(-1) }
    var ask by remember { mutableStateOf(Ask.None to "") }
    var editing by remember { mutableStateOf<LogEntry?>(null) }
    var asked by rememberSaveable { mutableStateOf(false) }
    val c = ui.content ?: return
    val month = if (browse >= 0) browse else ui.babyMonth ?: 0

    fun go(route: Any) = nav.navigate(route) { popUpTo(nav.graph.findStartDestination().id) { saveState = true }; launchSingleTop = true; restoreState = true }
    fun undoable(msg: String, undo: () -> Unit) = scope.launch {
        snack.currentSnackbarData?.dismiss()
        if (snack.showSnackbar(msg, actionLabel = "撤销", duration = SnackbarDuration.Short) == SnackbarResult.ActionPerformed) undo()
    }
    fun added(e: LogEntry) { undoable("记下了 · ${logKind(e.type).name}") { vm.deleteLog(e) } }
    fun log(type: String) {
        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
        if (ui.timers.any { it.type == type }) { vm.stopTimer(type) { it?.let(::added) }; return }
        when (askFor(type)) {
            Ask.None -> when (type) {
                LogType.Sleep -> { if (!asked) { asked = true; askNotifications() }; vm.startTimer(type) }
                LogType.Note -> vm.addLog(LogEntry(type = type, start = System.currentTimeMillis(), detail = "")) { editing = it }
                else -> vm.addLog(LogEntry(type = type, start = System.currentTimeMillis())) { added(it) }
            }
            else -> ask = askFor(type) to type
        }
    }

    LaunchedEffect(Unit) {
        open.collect { o ->
            when {
                o == "journal" -> { go(JournalRoute); open.value = null }
                o != null && o.startsWith("log:") -> { open.value = null; go(JournalRoute); log(o.removePrefix("log:")) }
            }
        }
    }

    val wide = LocalConfiguration.current.screenWidthDp >= 600
    val here = back?.destination?.route
    val isTop = here == null || Tabs.any { it.key == here }
    Scaffold(
        snackbarHost = { SnackbarHost(snack) },
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            if (isTop && !wide) NavigationBar(containerColor = MaterialTheme.colorScheme.surfaceContainerLow, tonalElevation = 0.dp) {
                Tabs.forEach { t ->
                    val on = here == t.key || (here == null && t.route == TodayRoute)
                    NavigationBarItem(
                        selected = on,
                        onClick = { if (t.route == GrowRoute && !on) browse = -1; go(t.route) },
                        icon = { Glyph(t.glyph, filled = on) },
                        label = { Text(t.label) },
                        colors = NavigationBarItemDefaults.colors(indicatorColor = MaterialTheme.colorScheme.primaryContainer),
                    )
                }
            }
        },
    ) { pad ->
      Row(Modifier.fillMaxSize()) {
        // tablets, foldables and landscape: the same four places as a rail on the side
        if (wide && isTop) NavigationRail(containerColor = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxHeight()) {
            Spacer(Modifier.weight(1f))
            Tabs.forEach { t ->
                val on = here == t.key || (here == null && t.route == TodayRoute)
                NavigationRailItem(selected = on, onClick = { if (t.route == GrowRoute && !on) browse = -1; go(t.route) },
                    icon = { Glyph(t.glyph, filled = on) }, label = { Text(t.label) },
                    colors = NavigationRailItemDefaults.colors(indicatorColor = MaterialTheme.colorScheme.primaryContainer))
            }
            Spacer(Modifier.weight(1f))
        }
        NavHost(nav, startDestination = TodayRoute, modifier = Modifier.weight(1f).padding(bottom = pad.calculateBottomPadding()),
            enterTransition = { fadeIn(tween(220)) + scaleIn(tween(260), initialScale = 0.98f) },
            exitTransition = { fadeOut(tween(160)) },
            popEnterTransition = { fadeIn(tween(220)) },
            popExitTransition = { fadeOut(tween(160)) + slideOutHorizontally(tween(220)) { it / 8 } },
        ) {
            composable<TodayRoute> {
                TodayScreen(ui, TodayActions(
                    openPlay = { code, m -> nav.navigate(PlayRoute(code, m)) },
                    openMonth = { browse = it; go(GrowRoute) },
                    setBirth = askBirth,
                    another = {
                        val m = ui.babyMonth ?: 0; val n = todaysPlays(c.month(m)) { c.play(it) }.size.coerceAtLeast(1)
                        val i = ui.settings.pick.split(":").let { p -> if (p.size == 2 && p[0].toIntOrNull() == m) p[1].toIntOrNull() ?: 0 else 0 }
                        vm.setPick("$m:${(i + 1) % n}")
                    },
                    skip = { vm.skipToday(it) },
                    log = ::log,
                    pause = vm::pauseTimer,
                    stop = { t -> vm.stopTimer(t) { it?.let(::added) } },
                    openJournal = { go(JournalRoute) },
                ))
            }
            composable<GrowRoute> {
                GrowScreen(ui, month, GrowActions(
                    select = { browse = it },
                    openPlay = { code, m -> nav.navigate(PlayRoute(code, m)) },
                    tick = { m, kind, id, label -> vm.toggleTick(m, kind, id, label) },
                ))
            }
            composable<JournalRoute> {
                JournalScreen(ui, day, logs, JournalActions(pickDay = { vm.journalDay.value = it }, log = ::log, open = { editing = it }))
            }
            composable<YouRoute> {
                YouScreen(ui, YouActions(
                    companion = vm::setCompanion, theme = vm::setTheme, birth = askBirth,
                    topic = { nav.navigate(TopicRoute(it)) }, about = { nav.navigate(AboutRoute) },
                    openMonth = { browse = it; go(GrowRoute) },
                ))
            }
            composable<PlayRoute>(
                enterTransition = { slideInHorizontally(tween(280)) { it / 5 } + fadeIn(tween(240)) },
                popExitTransition = { slideOutHorizontally(tween(240)) { it / 4 } + fadeOut(tween(200)) },
            ) { entry ->
                val r = entry.toRoute<PlayRoute>()
                val p = c.play(r.code) ?: return@composable
                val did = ui.ticked(r.month, TickKind.Did, p.code)
                PlayScreen(p, r.month, did, onDid = { on ->
                    vm.toggleTick(r.month, TickKind.Did, p.code, p.name, on)
                    if (on) { haptic.performHapticFeedback(HapticFeedbackType.LongPress); undoable("记为这个月做过（只是记录，不是评估）") { vm.toggleTick(r.month, TickKind.Did, p.code, p.name, false) } }
                }, onBack = { nav.popBackStack() })
            }
            composable<TopicRoute> { entry -> c.topics.firstOrNull { it.id == entry.toRoute<TopicRoute>().id }?.let { TopicScreen(it) { nav.popBackStack() } } }
            composable<AboutRoute> { AboutScreen(c) { nav.popBackStack() } }
        }
      }
    }

    AskSheet(ask.first, onDismiss = { ask = Ask.None to "" },
        onSide = { side -> val t = ask.second; ask = Ask.None to ""; if (!asked) { asked = true; askNotifications() }; vm.startTimer(t, side) },
        onAmount = { ml -> val t = ask.second; ask = Ask.None to ""; vm.addLog(LogEntry(type = t, start = System.currentTimeMillis(), amount = ml)) { added(it) } },
        onDiaper = { d -> val t = ask.second; ask = Ask.None to ""; vm.addLog(LogEntry(type = t, start = System.currentTimeMillis(), detail = d)) { added(it) } },
    )
    editing?.let { e ->
        EntrySheet(e, onChange = { if (it != e) vm.updateLog(it) }, onDelete = { d -> vm.deleteLog(d); undoable("删掉了一条") { vm.restoreLog(d) } }, onDismiss = { editing = null })
    }
}
