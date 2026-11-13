package app.mossling

import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedContentTransitionScope
import androidx.compose.animation.ExperimentalSharedTransitionApi
import androidx.compose.animation.SharedTransitionLayout
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.toRoute
import app.mossling.data.LogEntry
import app.mossling.data.LogType
import app.mossling.data.Measure
import app.mossling.data.TickKind
import app.mossling.data.tickKey
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.LocalDestination
import app.mossling.ui.components.LocalShared
import app.mossling.ui.components.minutes
import app.mossling.ui.grow.GrowActions
import app.mossling.ui.grow.GrowScreen
import app.mossling.ui.grow.GrowthBookScreen
import app.mossling.ui.grow.MapScreen
import app.mossling.ui.growth.GrowthActions
import app.mossling.ui.growth.GrowthScreen
import app.mossling.ui.growth.MeasureSheet
import app.mossling.ui.ip.Duo
import app.mossling.ui.ip.LocalMascotDirector
import app.mossling.ui.ip.MascotEvent
import app.mossling.ui.ip.Mood
import app.mossling.ui.ip.StorySheet
import app.mossling.ui.ip.rememberMascotDirector
import app.mossling.ui.journal.EntrySheet
import app.mossling.ui.journal.FirstsScreen
import app.mossling.ui.journal.JournalActions
import app.mossling.ui.journal.JournalScreen
import app.mossling.ui.journal.QuickLogSheet
import app.mossling.ui.journal.StatsScreen
import app.mossling.ui.journal.TimerModalSheet
import app.mossling.ui.journal.logKind
import app.mossling.ui.onboarding.BirthDateDialog
import app.mossling.ui.onboarding.Onboarding
import app.mossling.ui.plan.PlanActions
import app.mossling.ui.plan.PlanScreen
import app.mossling.ui.play.PlayScreen
import app.mossling.ui.search.SearchScreen
import app.mossling.ui.theme.LocalNightLamp
import app.mossling.ui.theme.MosslingTheme
import app.mossling.ui.today.TodayActions
import app.mossling.ui.today.TodayScreen
import app.mossling.ui.you.AboutScreen
import app.mossling.ui.you.AppAboutActions
import app.mossling.ui.you.AppAboutScreen
import app.mossling.ui.you.DataScreen
import app.mossling.ui.you.LicensesScreen
import app.mossling.ui.you.TopicScreen
import app.mossling.ui.you.YouActions
import app.mossling.ui.you.YouScreen
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import java.time.LocalDate

sealed interface Route {
    @Serializable data object Today : Route
    @Serializable data object Grow : Route
    @Serializable data object Journal : Route
    @Serializable data object You : Route
    @Serializable data class Play(val code: String, val month: Int, val resumeStep: Int = -1) : Route
    @Serializable data class Topic(val id: String) : Route
    @Serializable data object About : Route
    @Serializable data object Growth : Route
    @Serializable data object Stats : Route
    @Serializable data object Search : Route
    @Serializable data object Licenses : Route
    @Serializable data object Map : Route
    @Serializable data object Plan : Route
    @Serializable data object AppAbout : Route
    @Serializable data object Book : Route
    @Serializable data object Firsts : Route
    @Serializable data object Data : Route
}

private data class Tab(val route: Route, val label: String, val glyph: G)

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
fun MosslingRoot(
    vm: AppViewModel,
    open: MutableStateFlow<String?> = MutableStateFlow(null),
    askNotifications: () -> Unit = {},
    locked: StateFlow<Boolean> = MutableStateFlow(false),
    unlock: () -> Unit = {},
) {
    val ui by vm.ui.collectAsState()
    val isLocked by locked.collectAsState()
    val director = rememberMascotDirector()

    CompositionLocalProvider(LocalMascotDirector provides director) {
        MosslingTheme(
            mode = ui.settings.theme,
            companion = ui.settings.companion,
            nightLight = ui.settings.nightLight,
            artStyle = ui.settings.artStyle,
        ) {
            val isNight = LocalNightLamp.current
            LaunchedEffect(isNight) {
                director.handle(
                    if (isNight) MascotEvent.NightmodeEnabled else MascotEvent.NightmodeDisabled,
                    ui.settings.companion,
                )
            }
            Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                when {
                    !ui.ready -> Box(Modifier.fillMaxSize())
                    isLocked -> LockCover(ui, unlock)
                    !ui.settings.onboarded -> Onboarding(
                        onFinish = { d, k -> vm.setCompanion(k); vm.setBirth(d) },
                        onSkip = vm::skipOnboarding,
                    )
                    else -> MainShell(vm, ui, open, askNotifications)
                }
            }
        }
    }
}

@Composable
private fun LockCover(ui: AppUi, unlock: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
        Duo(ui.settings.companion, size = 120.dp, mood = Mood.Sleep)
        Spacer(Modifier.height(16.dp))
        Text("摸索台灯已锁上", style = MaterialTheme.typography.headlineSmall)
        Spacer(Modifier.height(16.dp))
        Button(onClick = unlock, shape = RoundedCornerShape(18.dp)) { Text("解锁") }
    }
}

@OptIn(ExperimentalSharedTransitionApi::class)
@Composable
private fun MainShell(
    vm: AppViewModel,
    ui: AppUi,
    open: MutableStateFlow<String?>,
    askNotifications: () -> Unit,
) {
    val director = LocalMascotDirector.current
    val nav = rememberNavController()
    val back by nav.currentBackStackEntryAsState()
    val dest = back?.destination

    var growMonth by rememberSaveable(ui.settings.birth) { mutableIntStateOf(ui.age?.bookMonth ?: 0) }
    var journalDay by remember { mutableStateOf(ui.today) }
    val dayLogs by remember(journalDay) { vm.logsForDay(journalDay) }.collectAsState(initial = emptyList())
    var logSheet by remember { mutableStateOf<String?>(null) }
    var editEntry by remember { mutableStateOf<LogEntry?>(null) }
    var editMeasure by remember { mutableStateOf<Measure?>(null) }
    var birthDialog by remember { mutableStateOf(false) }
    var showStory by remember { mutableStateOf(false) }
    var timerModalType by remember { mutableStateOf<String?>(null) }

    val snack = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val importPicker = androidx.activity.compose.rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            vm.importJson(uri) { msg ->
                if (msg.startsWith("已导入")) {
                    director.handle(MascotEvent.RecordPersistSuccess, ui.settings.companion)
                } else {
                    director.handle(MascotEvent.RecordPersistFailure, ui.settings.companion)
                }
                scope.launch { snack.showSnackbar(msg, duration = SnackbarDuration.Short) }
            }
        }
    }

    fun savedToast(e: LogEntry) {
        director.handle(MascotEvent.RecordPersistSuccess, ui.settings.companion)
        val dur = if (e.end != null) " · ${minutes((e.end - e.start).coerceAtLeast(0))}" else ""
        val amt = if (e.type == LogType.Bottle && e.amount != null) " · ${e.amount} 毫升" else ""
        scope.launch {
            snack.currentSnackbarData?.dismiss()
            val r = snack.showSnackbar("记下了：${logKind(e.type).label}$dur$amt", actionLabel = "撤销", duration = SnackbarDuration.Short)
            if (r == SnackbarResult.ActionPerformed) vm.dropLog(e.id)
        }
    }

    fun startTimer(type: String, side: String?) {
        askNotifications()
        if (type == LogType.Sleep) {
            director.noteSleepStarted(ui.settings.companion)
        } else {
            director.handle(MascotEvent.RecordStartConfirmed, ui.settings.companion)
        }
        vm.startTimer(type, side)
    }

    val openTarget by open.collectAsState()
    LaunchedEffect(openTarget) {
        val t = openTarget ?: return@LaunchedEffect
        open.value = null
        when {
            t == "journal" -> nav.navigate(Route.Journal) { launchSingleTop = true }
            t.startsWith("log:") -> logSheet = t.removePrefix("log:")
        }
    }

    val tabs = buildList {
        add(Tab(Route.Today, "今天", G.Today))
        add(Tab(Route.Grow, "成长", G.Grow))
        if (ui.settings.journal) add(Tab(Route.Journal, "手帐", G.Journal))
        add(Tab(Route.You, "我的", G.You))
    }
    val onTopTab = tabs.any { dest?.hasRoute(it.route::class) == true }

    Scaffold(
        snackbarHost = { SnackbarHost(snack) },
        bottomBar = {
            if (onTopTab) {
                NavigationBar(containerColor = MaterialTheme.colorScheme.surfaceContainerLow, tonalElevation = 0.dp) {
                    tabs.forEach { t ->
                        val selected = dest?.hasRoute(t.route::class) == true
                        NavigationBarItem(
                            selected = selected,
                            onClick = {
                                nav.navigate(t.route) {
                                    popUpTo(nav.graph.findStartDestination().id) { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = { Glyph(t.glyph, filled = selected) },
                            label = { Text(t.label) },
                        )
                    }
                }
            }
        },
    ) { pad ->
        SharedTransitionLayout {
            CompositionLocalProvider(LocalShared provides this) {
                NavHost(
                    navController = nav,
                    startDestination = Route.Today,
                    modifier = Modifier.padding(bottom = pad.calculateBottomPadding()),
                    enterTransition = { fadeIn(tween(180)) + slideIntoContainer(AnimatedContentTransitionScope.SlideDirection.Start, tween(220)) },
                    exitTransition = { fadeOut(tween(140)) },
                    popEnterTransition = { fadeIn(tween(180)) },
                    popExitTransition = { fadeOut(tween(160)) + slideOutOfContainer(AnimatedContentTransitionScope.SlideDirection.End, tween(200)) },
                ) {
                    composable<Route.Today> {
                        CompositionLocalProvider(LocalDestination provides this) {
                            TodayScreen(
                                ui = ui,
                                a = TodayActions(
                                    openPlay = { code, m -> nav.navigate(Route.Play(code, m)) },
                                    openMonth = { m -> growMonth = m; nav.navigate(Route.Grow) },
                                    toggleDid = { m, code, label ->
                                        vm.toggleTick(m, TickKind.Did, code, label)
                                        director.handle(MascotEvent.RecordPersistSuccess, ui.settings.companion)
                                    },
                                    toggleObserved = { m, id, label ->
                                        vm.toggleTick(m, TickKind.Observed, id, label)
                                        director.handle(MascotEvent.RecordPersistSuccess, ui.settings.companion)
                                    },
                                    pickBirth = { birthDialog = true },
                                    quickLog = { logSheet = it },
                                    pauseTimer = vm::pauseTimer,
                                    switchSide = vm::switchTimerSide,
                                    shiftTimer = vm::shiftTimer,
                                    stopTimer = {
                                        director.handle(MascotEvent.RecordTimerEnded, ui.settings.companion)
                                        vm.stopTimer(it, ::savedToast)
                                    },
                                    discardTimer = {
                                        director.handle(MascotEvent.RecordTimerEnded, ui.settings.companion)
                                        vm.discardTimer(it)
                                    },
                                    openSearch = { nav.navigate(Route.Search) },
                                    openMap = { nav.navigate(Route.Map) },
                                    openPlan = { nav.navigate(Route.Plan) },
                                    pickToday = {
                                        vm.pickToday(it)
                                        director.handle(MascotEvent.ActivityRecommendationChanged, ui.settings.companion)
                                    },
                                    resumePlay = { code, m, step -> nav.navigate(Route.Play(code, m, step)) },
                                    clearSession = { vm.clearSession() },
                                    openBook = { nav.navigate(Route.Book) },
                                    openTimer = { timerModalType = it },
                                ),
                            )
                        }
                    }
                    composable<Route.Grow> {
                        CompositionLocalProvider(LocalDestination provides this) {
                            GrowScreen(
                                ui = ui,
                                month = growMonth,
                                a = GrowActions(
                                    selectMonth = { growMonth = it },
                                    openPlay = { code -> nav.navigate(Route.Play(code, growMonth)) },
                                    openTopic = { id -> nav.navigate(Route.Topic(id)) },
                                    toggle = { kind, item, label ->
                                        vm.toggleTick(growMonth, kind, item, label)
                                        director.handle(MascotEvent.RecordPersistSuccess, ui.settings.companion)
                                    },
                                    openGrowth = { nav.navigate(Route.Growth) },
                                    openMap = { nav.navigate(Route.Map) },
                                    openPlan = { nav.navigate(Route.Plan) },
                                    openBook = { nav.navigate(Route.Book) },
                                ),
                            )
                        }
                    }
                    composable<Route.Journal> {
                        val last = mapOf(
                            LogType.Nurse to (ui.lastFeed?.takeIf { it.type == LogType.Nurse }?.let { it.end ?: it.start } ?: 0L),
                            LogType.Bottle to (ui.lastFeed?.takeIf { it.type == LogType.Bottle }?.start ?: 0L),
                            LogType.Sleep to (ui.lastSleep?.let { it.end ?: it.start } ?: 0L),
                            LogType.Diaper to (ui.lastDiaper?.start ?: 0L),
                        ).filterValues { it > 0L }
                        JournalScreen(
                            ui = ui,
                            day = journalDay,
                            logs = dayLogs,
                            last = last,
                            a = JournalActions(
                                setDay = { journalDay = it },
                                openSheet = { logSheet = it },
                                editEntry = { editEntry = it },
                                delete = vm::dropLog,
                                pauseTimer = vm::pauseTimer,
                                switchSide = vm::switchTimerSide,
                                shiftTimer = vm::shiftTimer,
                                stopTimer = {
                                    director.handle(MascotEvent.RecordTimerEnded, ui.settings.companion)
                                    vm.stopTimer(it, ::savedToast)
                                },
                                discardTimer = {
                                    director.handle(MascotEvent.RecordTimerEnded, ui.settings.companion)
                                    vm.discardTimer(it)
                                },
                                turnOn = { vm.setJournal(true) },
                                openStats = { nav.navigate(Route.Stats) },
                                openGrowth = { nav.navigate(Route.Growth) },
                                openFirsts = { nav.navigate(Route.Firsts) },
                                openTimerModal = { timerModalType = it },
                            ),
                        )
                    }
                    composable<Route.You> {
                        YouScreen(
                            ui = ui,
                            a = YouActions(
                                pickBirth = { birthDialog = true },
                                setCompanion = {
                                    vm.setCompanion(it)
                                    director.handle(MascotEvent.CompanionChanged, it)
                                },
                                setTheme = vm::setTheme,
                                setNightLight = vm::setNightLight,
                                setArtStyle = vm::setArtStyle,
                                setJournal = vm::setJournal,
                                setSex = vm::setSex,
                                setLook = vm::setLook,
                                setNickname = vm::setNickname,
                                setAppLock = vm::setAppLock,
                                openGrowth = { nav.navigate(Route.Growth) },
                                openBook = { nav.navigate(Route.Book) },
                                openFirsts = { nav.navigate(Route.Firsts) },
                                openData = { nav.navigate(Route.Data) },
                                openStory = { showStory = true },
                                openTopic = { id -> nav.navigate(Route.Topic(id)) },
                                openAbout = { nav.navigate(Route.About) },
                                openAppAbout = { nav.navigate(Route.AppAbout) },
                                shareSummary = vm::shareSummary,
                                shareJson = vm::shareJson,
                                shareCsv = vm::shareCsv,
                                importJson = { importPicker.launch(arrayOf("application/json", "text/*", "*/*")) },
                                clearAll = vm::clearAll,
                            ),
                        )
                    }
                    composable<Route.Play> { entry ->
                        val r = entry.toRoute<Route.Play>()
                        val p = ui.content?.play(r.code) ?: return@composable
                        val done = tickKey(r.month, TickKind.Did, r.code) in ui.ticks
                        val rec = ui.playRecords(r.month)[r.code]
                        val savedSessionStep = ui.settings.playing?.takeIf { it.first == r.code }?.third
                        val initStep = r.resumeStep.takeIf { it >= 0 }
                        CompositionLocalProvider(LocalDestination provides this) {
                            PlayScreen(
                                play = p,
                                month = r.month,
                                done = done,
                                onToggleDone = { vm.toggleTick(r.month, TickKind.Did, r.code, p.name) },
                                onBack = { nav.popBackStack() },
                                record = rec,
                                initialStep = initStep,
                                savedStep = savedSessionStep,
                                onSaveSession = { step -> vm.saveSession(r.code, r.month, step) },
                                onClearSession = { vm.clearSession(r.code) },
                                onRecordPlay = { note -> vm.recordPlay(p, r.month, note) },
                                onPickToday = {
                                    vm.pickToday(r.code)
                                    director.handle(MascotEvent.ActivityRecommendationChanged, ui.settings.companion)
                                    scope.launch { snack.showSnackbar("已设为「今天一起玩」", duration = SnackbarDuration.Short) }
                                },
                            )
                        }
                    }
                    composable<Route.Topic> { entry ->
                        val r = entry.toRoute<Route.Topic>()
                        val t = ui.content?.topic(r.id) ?: return@composable
                        TopicScreen(t) { nav.popBackStack() }
                    }
                    composable<Route.About> {
                        val c = ui.content ?: return@composable
                        AboutScreen(c, licenses = { nav.navigate(Route.Licenses) }) { nav.popBackStack() }
                    }
                    composable<Route.Licenses> { LicensesScreen { nav.popBackStack() } }
                    composable<Route.Growth> {
                        GrowthScreen(
                            ui = ui,
                            growth = vm.growth,
                            a = GrowthActions(
                                back = { nav.popBackStack() },
                                add = { editMeasure = Measure(at = System.currentTimeMillis()) },
                                edit = { editMeasure = it },
                                sex = vm::setSex,
                            ),
                        )
                    }
                    composable<Route.Stats> {
                        val all by remember { vm.allLogs() }.collectAsState(initial = emptyList())
                        StatsScreen(all, ui.today) { nav.popBackStack() }
                    }
                    composable<Route.Search> {
                        val c = ui.content ?: return@composable
                        SearchScreen(
                            c = c,
                            onBack = { nav.popBackStack() },
                            openPlay = { code -> nav.navigate(Route.Play(code, ui.age?.bookMonth ?: 0)) },
                            openMonth = { m -> growMonth = m; nav.navigate(Route.Grow) },
                            openTopic = { id -> nav.navigate(Route.Topic(id)) },
                        )
                    }
                    composable<Route.Map> {
                        MapScreen(
                            ui = ui,
                            open = { m ->
                                growMonth = m
                                nav.popBackStack()
                                nav.navigate(Route.Grow) { launchSingleTop = true }
                            },
                        ) { nav.popBackStack() }
                    }
                    composable<Route.Plan> {
                        PlanScreen(
                            ui = ui,
                            playLogs = ui.allLogs,
                            a = PlanActions(
                                setShelf = {
                                    vm.setShelf(it)
                                    director.handle(MascotEvent.ActivityRecommendationChanged, ui.settings.companion)
                                },
                                openPlay = { code, m -> nav.navigate(Route.Play(code, m)) },
                                logPlayed = { p, m ->
                                    vm.recordPlay(p, m)
                                    director.handle(MascotEvent.RecordPersistSuccess, ui.settings.companion)
                                    scope.launch { snack.showSnackbar("记下了：今天玩了「${p.name}」", duration = SnackbarDuration.Short) }
                                },
                                back = { nav.popBackStack() },
                            ),
                        )
                    }
                    composable<Route.AppAbout> {
                        AppAboutScreen(
                            a = AppAboutActions(
                                openContentAbout = { nav.navigate(Route.About) },
                                openLicenses = { nav.navigate(Route.Licenses) },
                                toggleArtStyle = {
                                    vm.toggleArtStyle()
                                    scope.launch {
                                        val next = if (ui.settings.artStyle == app.mossling.ui.components.ArtStyle.Vinyl) "平面" else "立体"
                                        snack.showSnackbar("画风已切换为：$next", duration = SnackbarDuration.Short)
                                    }
                                },
                                openStory = { showStory = true },
                                back = { nav.popBackStack() },
                            ),
                            updater = vm.updater,
                        )
                    }
                    composable<Route.Book> {
                        GrowthBookScreen(
                            ui = ui,
                            openMonth = { m -> growMonth = m; nav.navigate(Route.Grow) },
                            openPlay = { code, m -> nav.navigate(Route.Play(code, m)) },
                            openFirsts = { nav.navigate(Route.Firsts) },
                            onBack = { nav.popBackStack() },
                        )
                    }
                    composable<Route.Firsts> {
                        FirstsScreen(
                            ui = ui,
                            onSave = {
                                vm.putFirst(it)
                                director.handle(MascotEvent.RecordPersistSuccess, ui.settings.companion)
                            },
                            onDelete = vm::dropFirst,
                            onBack = { nav.popBackStack() },
                        )
                    }
                    composable<Route.Data> {
                        DataScreen(
                            ui = ui,
                            onShareSummary = vm::shareSummary,
                            onShareJson = vm::shareJson,
                            onShareCsv = vm::shareCsv,
                            onImportJson = { importPicker.launch(arrayOf("application/json", "text/*", "*/*")) },
                            onWithdrawConsent = {
                                vm.withdrawConsent()
                                scope.launch { snack.showSnackbar("已撤回同意并清除儿童个人资料", duration = SnackbarDuration.Short) }
                            },
                            onClearAll = {
                                vm.clearAll()
                                nav.popBackStack()
                            },
                            onBack = { nav.popBackStack() },
                        )
                    }
                }
            }
        }
    }

    logSheet?.let { t ->
        QuickLogSheet(
            type = t,
            onPickType = { logSheet = it },
            onStartTimer = ::startTimer,
            onSave = { vm.log(it, ::savedToast) },
            onDismiss = { logSheet = null },
        )
    }
    editEntry?.let { e ->
        EntrySheet(
            e = e,
            onSave = {
                vm.log(it)
                director.handle(MascotEvent.RecordPersistSuccess, ui.settings.companion)
            },
            onDelete = { vm.dropLog(it.id) },
            onDismiss = { editEntry = null },
        )
    }
    editMeasure?.let { m ->
        MeasureSheet(
            m = m,
            onSave = {
                vm.putMeasure(it)
                director.handle(MascotEvent.RecordPersistSuccess, ui.settings.companion)
            },
            onDelete = { vm.dropMeasure(it.id) },
            onDismiss = { editMeasure = null },
        )
    }
    if (birthDialog) {
        BirthDateDialog(
            initial = ui.settings.birth ?: LocalDate.now().minusMonths(6),
            onConfirm = { birthDialog = false; vm.setBirth(it) },
            onDismiss = { birthDialog = false },
        )
    }
    if (showStory) {
        StorySheet(
            companion = ui.settings.companion,
            onSelectCompanion = {
                vm.setCompanion(it)
                director.handle(MascotEvent.CompanionChanged, it)
            },
            onDismiss = { showStory = false },
        )
    }
    timerModalType?.let { type ->
        val running = ui.timers.firstOrNull { it.type == type }
        TimerModalSheet(
            type = type,
            timer = running,
            onStart = { side -> startTimer(type, side) },
            onTapSide = { side ->
                askNotifications()
                director.handle(MascotEvent.RecordStartConfirmed, ui.settings.companion)
                vm.tapNurseSide(side)
            },
            onPause = { vm.pauseTimer(type) },
            onShift = { delta -> vm.shiftTimer(type, delta) },
            onStop = {
                director.handle(MascotEvent.RecordTimerEnded, ui.settings.companion)
                vm.stopTimer(type, ::savedToast)
            },
            onDiscard = {
                director.handle(MascotEvent.RecordTimerEnded, ui.settings.companion)
                vm.discardTimer(type)
            },
            onManualEntry = {
                timerModalType = null
                logSheet = type
            },
            onDismiss = { timerModalType = null },
        )
    }
}
