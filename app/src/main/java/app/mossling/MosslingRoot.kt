package app.mossling

import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
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
import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionLayout
import androidx.compose.runtime.CompositionLocalProvider
import app.mossling.ui.components.LocalDestination
import app.mossling.ui.components.LocalShared
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
@Serializable object GrowthRoute
@Serializable object StatsRoute
@Serializable object SearchRoute
@Serializable object LicensesRoute
@Serializable object MapRoute
@Serializable object PlanRoute
@Serializable object AppAboutRoute
@Serializable data class DocRoute(val name: String)

// key: the route string Navigation derives from the serial name (stable under R8, unlike class names)
private data class Tab(val route: Any, val label: String, val glyph: G, val key: String)
private val Tabs = listOf(
    Tab(TodayRoute, "今天", G.Today, "app.mossling.TodayRoute"), Tab(GrowRoute, "成长", G.Grow, "app.mossling.GrowRoute"),
    Tab(JournalRoute, "手帐", G.Journal, "app.mossling.JournalRoute"), Tab(YouRoute, "我的", G.You, "app.mossling.YouRoute"),
)

@Composable
fun MosslingRoot(vm: AppViewModel, open: MutableStateFlow<String?>, askNotifications: () -> Unit = {}, locked: MutableStateFlow<Boolean> = MutableStateFlow(false), unlock: () -> Unit = {}) {
    val ui by vm.ui.collectAsStateWithLifecycle()
    MosslingTheme(ui.settings.theme, ui.settings.companion) {
        // a Surface, not a bare background: it also sets the content colour, so text is right in the dark theme
        Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background, contentColor = MaterialTheme.colorScheme.onBackground) {
            if (!ui.ready) return@Surface
            var birthDialog by remember { mutableStateOf(false) }
            if (!ui.settings.onboarded) Onboarding(onBirth = { birthDialog = true }, onSkip = vm::finishOnboarding)
            else Shell(vm, open, askNotifications) { birthDialog = true }
            if (birthDialog) BirthDialog(ui.settings.birth, onPick = { vm.setBirth(it) }, onDismiss = { birthDialog = false })
            val isLocked by locked.collectAsStateWithLifecycle()
            if (isLocked) LockScreen(ui.settings.companion, unlock)
        }
    }
}

@OptIn(ExperimentalSharedTransitionApi::class)
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
    var measuring by remember { mutableStateOf<app.mossling.data.Measure?>(null) }
    var backfilling by remember { mutableStateOf(false) }
    var clearing by remember { mutableStateOf(false) }
    val month30 by vm.month.collectAsStateWithLifecycle()
    val c = ui.content ?: return
    val month = if (browse >= 0) browse else ui.babyMonth ?: 0

    fun go(route: Any) = nav.navigate(route) { popUpTo(nav.graph.findStartDestination().id) { saveState = true }; launchSingleTop = true; restoreState = true }
    fun undoable(msg: String, undo: () -> Unit) = scope.launch {
        snack.currentSnackbarData?.dismiss()
        if (snack.showSnackbar(msg, actionLabel = "撤销", duration = SnackbarDuration.Short) == SnackbarResult.ActionPerformed) undo()
    }
    val pickFile = androidx.activity.compose.rememberLauncherForActivityResult(androidx.activity.result.contract.ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) vm.importFile(uri) { msg -> scope.launch { snack.showSnackbar(msg, duration = SnackbarDuration.Long) } }
    }
    fun say(msg: String) { scope.launch { snack.currentSnackbarData?.dismiss(); snack.showSnackbar(msg, duration = SnackbarDuration.Short) } }
    val saveJson = androidx.activity.compose.rememberLauncherForActivityResult(androidx.activity.result.contract.ActivityResultContracts.CreateDocument("application/json")) { uri ->
        if (uri != null) vm.export(uri, csv = false, done = ::say)
    }
    val saveCsv = androidx.activity.compose.rememberLauncherForActivityResult(androidx.activity.result.contract.ActivityResultContracts.CreateDocument("text/csv")) { uri ->
        if (uri != null) vm.export(uri, csv = true, done = ::say)
    }
    // once after an unexpected stop: say so, and where the report is (it stays on the phone)
    LaunchedEffect(Unit) {
        val ctx0 = vm.getApplication<android.app.Application>()
        if (app.mossling.CrashLog.read(ctx0) != null && snack.showSnackbar("上次异常退出", actionLabel = "查看", duration = SnackbarDuration.Long) == SnackbarResult.ActionPerformed) nav.navigate(AppAboutRoute)
    }
    fun added(e: LogEntry) { undoable("记下了 · ${logKind(e.type).name}") { vm.deleteLog(e) } }
    val timerActions = app.mossling.ui.journal.TimerActions(
        pause = vm::pauseTimer, stop = { t -> vm.stopTimer(t) { it?.let(::added) } }, switchSide = vm::switchSide, shift = vm::shiftTimer,
        discard = { type -> ui.timers.firstOrNull { it.type == type }?.let { r -> vm.discardTimer(type); undoable("这次不记了") { vm.startTimer(r.type, r.side, r.start) } } },
    )
    // when each kind was last recorded (a running timer counts as now)
    val lastOf = remember(month30, ui.timers) { month30.groupBy { it.type }.mapValues { (_, v) -> v.maxOf { it.end ?: it.start } } }
    fun log(type: String) {
        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
        // a running feed or sleep is ended on its timer card (with its own 结束), never by tapping its button again
        if (ui.timers.any { it.type == type }) { go(JournalRoute); say(logKind(type).name + "正在计时，可在计时卡片上暂停或结束"); return }
        when (askFor(type)) {
            Ask.Measure -> measuring = app.mossling.data.Measure(at = System.currentTimeMillis())
            Ask.None -> when (type) {
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
                o != null && o.startsWith("log:") -> { open.value = null; if (!ui.settings.journal) vm.setJournal(true); go(JournalRoute); log(o.removePrefix("log:")) }
            }
        }
    }

    val wide = LocalConfiguration.current.screenWidthDp >= 600
    val here = back?.destination?.route
    val tabs = if (ui.settings.journal) Tabs else Tabs.filter { it.route != JournalRoute }
    val isTop = here == null || tabs.any { it.key == here }
    Scaffold(
        snackbarHost = { SnackbarHost(snack) },
        containerColor = MaterialTheme.colorScheme.background,
        bottomBar = {
            if (isTop && !wide) NavigationBar(containerColor = MaterialTheme.colorScheme.surfaceContainerLow, tonalElevation = 0.dp) {
                tabs.forEach { t ->
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
            tabs.forEach { t ->
                val on = here == t.key || (here == null && t.route == TodayRoute)
                NavigationRailItem(selected = on, onClick = { if (t.route == GrowRoute && !on) browse = -1; go(t.route) },
                    icon = { Glyph(t.glyph, filled = on) }, label = { Text(t.label) },
                    colors = NavigationRailItemDefaults.colors(indicatorColor = MaterialTheme.colorScheme.primaryContainer))
            }
            Spacer(Modifier.weight(1f))
        }
        SharedTransitionLayout(Modifier.weight(1f)) {
        CompositionLocalProvider(LocalShared provides this) {
        NavHost(nav, startDestination = TodayRoute, modifier = Modifier.fillMaxSize().padding(bottom = pad.calculateBottomPadding()),
            enterTransition = { fadeIn(tween(220)) + scaleIn(tween(260), initialScale = 0.98f) },
            exitTransition = { fadeOut(tween(160)) },
            popEnterTransition = { fadeIn(tween(220)) },
            popExitTransition = { fadeOut(tween(160)) + slideOutHorizontally(tween(220)) { it / 8 } },
        ) {
            composable<TodayRoute> { CompositionLocalProvider(LocalDestination provides this) {
                TodayScreen(ui, TodayActions(
                    openPlay = { code, m -> nav.navigate(PlayRoute(code, m)) },
                    openMonth = { browse = it; go(GrowRoute) },
                    setBirth = askBirth,
                    another = {
                        val m = ui.babyMonth ?: 0; val n = app.mossling.domain.Shelf.current(c, m, ui.settings.shelf, ui.today).first.ifEmpty { todaysPlays(c.month(m)) { c.play(it) } }.size.coerceAtLeast(1)
                        val i = ui.settings.pick.split(":").let { p -> if (p.size == 2 && p[0].toIntOrNull() == m) p[1].toIntOrNull() ?: 0 else 0 }
                        vm.setPick("$m:${(i + 1) % n}")
                    },
                    skip = { vm.skipToday(it) },
                    log = ::log,
                    pause = vm::pauseTimer,
                    stop = { t -> vm.stopTimer(t) { it?.let(::added) } },
                    openJournal = { go(JournalRoute) },
                    openMap = { nav.navigate(MapRoute) }, openPlan = { nav.navigate(PlanRoute) }, timer = timerActions,
                ))
            } }
            composable<GrowRoute> { CompositionLocalProvider(LocalDestination provides this) {
                GrowScreen(ui, month, GrowActions(
                    select = { browse = it },
                    openPlay = { code, m -> nav.navigate(PlayRoute(code, m)) },
                    tick = { m, kind, id, label -> vm.toggleTick(m, kind, id, label) },
                    openMap = { nav.navigate(MapRoute) }, openPlan = { nav.navigate(PlanRoute) }, openGrowth = { nav.navigate(GrowthRoute) }, topic = { nav.navigate(TopicRoute(it)) }, search = { nav.navigate(SearchRoute) },
                ))
            } }
            composable<JournalRoute> {
                JournalScreen(ui, day, logs, last = lastOf, a = JournalActions(pickDay = { vm.journalDay.value = it }, log = ::log, open = { editing = it }, timer = timerActions,
                    stats = { nav.navigate(StatsRoute) }, growth = { nav.navigate(GrowthRoute) }, backfill = { backfilling = true }))
            }
            composable<YouRoute> {
                YouScreen(ui, YouActions(
                    companion = vm::setCompanion, theme = vm::setTheme, birth = askBirth,
                    topic = { nav.navigate(TopicRoute(it)) }, about = { nav.navigate(AboutRoute) },
                    openMonth = { browse = it; go(GrowRoute) },
                    exportJson = { saveJson.launch(vm.exportName(false)) },
                    exportCsv = { saveCsv.launch(vm.exportName(true)) },
                    clearAll = { clearing = true },
                    nickname = vm::setNickname, sex = vm::setSex,
                    search = { nav.navigate(SearchRoute) },
                    lock = vm::setLock,
                    journal = vm::setJournal,
                    appAbout = { nav.navigate(AppAboutRoute) },
                    importFile = { pickFile.launch(arrayOf("application/json", "text/plain", "application/octet-stream")) },
                ))
            }
            composable<PlayRoute>(
                enterTransition = { slideInHorizontally(tween(280)) { it / 5 } + fadeIn(tween(240)) },
                popExitTransition = { slideOutHorizontally(tween(240)) { it / 4 } + fadeOut(tween(200)) },
            ) { entry -> CompositionLocalProvider(LocalDestination provides this) {
                val r = entry.toRoute<PlayRoute>()
                val p = c.play(r.code) ?: return@CompositionLocalProvider
                val did = ui.ticked(r.month, TickKind.Did, p.code)
                PlayScreen(p, r.month, did, onDid = { on ->
                    vm.toggleTick(r.month, TickKind.Did, p.code, p.name, on)
                    // each time it is done also goes in the journal, so the week's shelf can count repetitions
                    if (on) vm.addLog(LogEntry(type = LogType.Play, start = System.currentTimeMillis(), detail = "${p.code} ${p.name}"))
                    if (on) { haptic.performHapticFeedback(HapticFeedbackType.LongPress); undoable("记为做过") { vm.toggleTick(r.month, TickKind.Did, p.code, p.name, false) } }
                }, onBack = { nav.popBackStack() })
            } }
            composable<TopicRoute> { entry -> c.topics.firstOrNull { it.id == entry.toRoute<TopicRoute>().id }?.let { TopicScreen(it) { nav.popBackStack() } } }
            composable<MapRoute> { app.mossling.ui.grow.MapScreen(ui, open = { m -> browse = m; nav.popBackStack(); go(GrowRoute) }) { nav.popBackStack() } }
            composable<PlanRoute> {
                val monday = app.mossling.domain.Shelf.weekOf(ui.today)
                val z = java.time.ZoneId.systemDefault(); val from = monday.atStartOfDay(z).toInstant().toEpochMilli()
                app.mossling.ui.plan.PlanScreen(ui, month30.filter { it.start >= from }, app.mossling.ui.plan.PlanActions(
                    back = { nav.popBackStack() }, set = { vm.setShelf(it) }, openPlay = { code -> nav.navigate(PlayRoute(code, ui.babyMonth ?: month)) }))
            }
            composable<AppAboutRoute> {
                app.mossling.ui.you.AppAboutScreen(app.mossling.ui.you.AppAboutActions(back = { nav.popBackStack() }, sources = { nav.navigate(AboutRoute) },
                    licenses = { nav.navigate(LicensesRoute) }, doc = { nav.navigate(DocRoute(it)) }), updater = vm.updater)
            }
            composable<DocRoute> { e -> app.mossling.ui.you.DocScreen(e.toRoute<DocRoute>().name) { nav.popBackStack() } }
            composable<AboutRoute> { AboutScreen(c, licenses = { nav.navigate(LicensesRoute) }) { nav.popBackStack() } }
            composable<LicensesRoute> { app.mossling.ui.you.LicensesScreen { nav.popBackStack() } }
            composable<StatsRoute> { app.mossling.ui.journal.StatsScreen(month30, ui.today) { nav.popBackStack() } }
            composable<GrowthRoute> {
                app.mossling.ui.growth.GrowthScreen(ui, vm.growth, app.mossling.ui.growth.GrowthActions(
                    back = { nav.popBackStack() }, add = { measuring = app.mossling.data.Measure(at = System.currentTimeMillis()) },
                    edit = { measuring = it }, sex = vm::setSex))
            }
            composable<SearchRoute> {
                app.mossling.ui.search.SearchScreen(c, onBack = { nav.popBackStack() },
                    openPlay = { code -> nav.navigate(PlayRoute(code, c.months.firstOrNull { code in it.activities }?.month ?: month)) },
                    openMonth = { m -> browse = m; go(GrowRoute) }, openTopic = { nav.navigate(TopicRoute(it)) })
            }
        }
        }
        }
      }
    }

    AskSheet(ask.first, type = ask.second, onDismiss = { ask = Ask.None to "" },
        lastAmount = month30.lastOrNull { it.type == LogType.Bottle }?.amount,
        onTemp = { c10, at -> val t = ask.second; ask = Ask.None to ""; vm.addLog(LogEntry(type = t, start = at, amount = c10)) { added(it) } },
        onText = { text, at -> val t = ask.second; ask = Ask.None to ""; vm.addLog(LogEntry(type = t, start = at, detail = text.ifBlank { null })) { added(it) } },
        onSide = { side, at ->
            val t = ask.second; ask = Ask.None to ""; if (!asked) { asked = true; askNotifications() }
            val s = side.ifEmpty { null }; vm.startTimer(t, s, at)
            // said back, so a start never goes unnoticed; 撤销 takes it back
            val ago = ((System.currentTimeMillis() - at) / 60_000).toInt()
            undoable(logKind(t).name + "开始计时" + when (s) { "l" -> " · 左侧"; "r" -> " · 右侧"; else -> "" } + if (ago >= 1) " · 从 $ago 分钟前算起" else "") { vm.discardTimer(t) }
        },
        onAmount = { ml, at -> val t = ask.second; ask = Ask.None to ""; vm.addLog(LogEntry(type = t, start = at, amount = ml)) { added(it) } },
        onDiaper = { d, at -> val t = ask.second; ask = Ask.None to ""; vm.addLog(LogEntry(type = t, start = at, detail = d)) { added(it) } },
    )
    measuring?.let { m ->
        app.mossling.ui.growth.MeasureSheet(m, onSave = { vm.putMeasure(it); say("记下了 · 生长") }, onDelete = { d -> vm.dropMeasure(d); undoable("删掉了一次测量") { vm.putMeasure(d) } }, onDismiss = { measuring = null })
    }
    if (backfilling) app.mossling.ui.journal.KindSheet(onPick = { t ->
        backfilling = false
        val z = java.time.ZoneId.systemDefault()
        val now = java.time.LocalTime.now()
        val at = day.atTime(now).atZone(z).toInstant().toEpochMilli().coerceAtMost(System.currentTimeMillis())
        val dur = when (t) { LogType.Sleep -> 60 * 60_000L; LogType.Nurse -> 15 * 60_000L; else -> null }
        editing = LogEntry(type = t, start = dur?.let { at - it } ?: at, end = dur?.let { at }, amount = when (t) { LogType.Bottle -> 120; LogType.Temp -> 368; else -> null },
            side = if (t == LogType.Nurse) "l" else null, detail = if (t == LogType.Diaper) "wet" else null)
    }, onDismiss = { backfilling = false })
    if (clearing) androidx.compose.material3.AlertDialog(onDismissRequest = { clearing = false },
        title = { Text("清除这台手机上的全部记录？") },
        text = { Text("出生日期、勾选、手帐、生长测量和设置都会删除，无法恢复。") },
        confirmButton = { androidx.compose.material3.TextButton(onClick = { clearing = false; vm.clearAll { } }) { Text("全部清除", color = MaterialTheme.colorScheme.error) } },
        dismissButton = { androidx.compose.material3.TextButton(onClick = { clearing = false }) { Text("取消") } })
    editing?.let { e ->
        EntrySheet(e, onChange = { if (it.id == 0L) vm.addLog(it) { n -> added(n) } else if (it != e) vm.updateLog(it) }, onDelete = { d -> vm.deleteLog(d); undoable("删掉了一条") { vm.restoreLog(d) } }, onDismiss = { editing = null })
    }
}

/** Covers everything until the person has confirmed it is them. The companion is asleep; nothing of the records shows. */
@Composable
private fun LockScreen(companion: app.mossling.ui.ip.Kind, unlock: () -> Unit) {
    Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        androidx.compose.foundation.layout.Column(Modifier.fillMaxSize(), horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally, verticalArrangement = androidx.compose.foundation.layout.Arrangement.Center) {
            app.mossling.ui.ip.Duo(companion, size = 120.dp, mood = app.mossling.ui.ip.Mood.Sleep, poke = false)
            Text("摸索台灯已锁定", style = MaterialTheme.typography.headlineSmall, modifier = Modifier.padding(top = 16.dp))
            androidx.compose.material3.Button(onClick = unlock, shape = androidx.compose.foundation.shape.RoundedCornerShape(18.dp), modifier = Modifier.padding(top = 24.dp).heightIn(min = 52.dp)) { Text("解锁") }
        }
    }
}
