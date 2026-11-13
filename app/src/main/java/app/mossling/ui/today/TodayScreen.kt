package app.mossling.ui.today

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.mossling.AppUi
import app.mossling.data.LogType
import app.mossling.data.MonthGuide
import app.mossling.data.Play
import app.mossling.data.TickKind
import app.mossling.data.tickKey
import app.mossling.domain.Age
import app.mossling.domain.PlayRecord
import app.mossling.domain.Shelf
import app.mossling.ui.components.Art
import app.mossling.ui.components.ArtIndex
import app.mossling.ui.components.ColorTablet
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.MorphBlob
import app.mossling.ui.components.NumberRod
import app.mossling.ui.components.Plate
import app.mossling.ui.components.SandpaperNumber
import app.mossling.ui.components.SectionTitle
import app.mossling.ui.components.ShapeBadge
import app.mossling.ui.components.Shapes
import app.mossling.ui.components.Shelf as WoodShelf
import app.mossling.ui.components.Tagged
import app.mossling.ui.components.WorkTray
import app.mossling.ui.components.areaColor
import app.mossling.ui.components.areaGlyph
import app.mossling.ui.components.md
import app.mossling.ui.components.shared
import app.mossling.ui.components.weekday
import app.mossling.ui.ip.Duo
import app.mossling.ui.ip.MaterialStill
import app.mossling.ui.ip.Mood
import app.mossling.ui.ip.familyOf
import app.mossling.ui.journal.TimerCard
import app.mossling.ui.journal.logKind
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

data class TodayActions(
    val openPlay: (String, Int) -> Unit = { _, _ -> },
    val openMonth: (Int) -> Unit = {},
    val toggleDid: (Int, String, String) -> Unit = { _, _, _ -> },
    val toggleObserved: (Int, String, String) -> Unit = { _, _, _ -> },
    val pickBirth: () -> Unit = {},
    val quickLog: (String) -> Unit = {},
    val pauseTimer: (String) -> Unit = {},
    val switchSide: (String) -> Unit = {},
    val shiftTimer: (String, Long) -> Unit = { _, _ -> },
    val stopTimer: (String) -> Unit = {},
    val discardTimer: (String) -> Unit = {},
    val openSearch: () -> Unit = {},
    val openMap: () -> Unit = {},
    val openPlan: () -> Unit = {},
    val pickToday: (String) -> Unit = {},
    val resumePlay: (String, Int, Int) -> Unit = { c, m, _ -> openPlay(c, m) },
    val clearSession: () -> Unit = {},
    val openBook: () -> Unit = {},
    val openTimer: (String) -> Unit = {},
)

@Composable
fun TodayScreen(ui: AppUi, a: TodayActions, now: () -> Long = System::currentTimeMillis) {
    val content = ui.content ?: return
    val age = ui.age
    val month = age?.bookMonth ?: 0
    val guide = content.month(month) ?: content.months.first()
    val records = remember(ui.ticks, ui.allLogs, month, ui.today) { ui.playRecords(month) }
    val playedCodes = remember(ui.ticks, ui.allLogs) { ui.playedCodes() }
    val done = ui.ticks.values.filter { it.month == month && it.kind == TickKind.Did }.map { it.key.substringAfterLast(":") }.toSet() +
        records.values.filter { it.total > 0 }.map { it.code }
    val (shelf, _) = Shelf.current(content, month, ui.settings.shelf, ui.today, playedCodes)
    val picked = Shelf.pick(ui.settings.todayPick, ui.today)
    val todayPlay = Shelf.first(
        shelf = shelf,
        picked = picked,
        weekBeforeTodayCounts = records.mapValues { it.value.beforeTodayThisWeek },
        totalCounts = records.mapValues { it.value.total },
    ) ?: shelf.firstOrNull()
    val nextChoice = if (shelf.size <= 1) null else shelf[(shelf.indexOfFirst { it.code == todayPlay?.code } + 1).mod(shelf.size)]

    val mood = when {
        ui.timers.any { it.type == LogType.Sleep } -> Mood.Sleep
        ui.timers.any { it.type == LogType.Nurse } -> Mood.Listening
        else -> Mood.Calm
    }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 112.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item("hero") { Hero(ui, age, guide, mood, a.pickBirth, a.openMonth, a.openSearch, a.openMap, a.openBook, now) }

        // Resume in-progress follow-along session if present
        val playing = ui.settings.playing
        if (playing != null) {
            val sessionPlay = content.play(playing.first)
            if (sessionPlay != null) {
                item("resume") {
                    ResumeSessionBanner(
                        play = sessionPlay,
                        month = playing.second,
                        step = playing.third,
                        onResume = { a.resumePlay(playing.first, playing.second, playing.third) },
                        onDismiss = a.clearSession,
                    )
                }
            }
        }

        if (ui.settings.journal) {
            items(ui.timers.size, key = { "timer:${ui.timers[it].type}" }) { i ->
                val t = ui.timers[i]
                TimerCard(
                    t = t,
                    onPause = { a.pauseTimer(t.type) },
                    onSwitchSide = { a.switchSide(t.type) },
                    onShift = { a.shiftTimer(t.type, it) },
                    onStop = { a.stopTimer(t.type) },
                    onDiscard = { a.discardTimer(t.type) },
                    modifier = Modifier.padding(horizontal = 16.dp),
                    onExpand = { a.openTimer(t.type) },
                    now = now,
                )
            }
            item("quick") {
                SectionTitle(
                    "记一下",
                    kicker = "点一下就能记，也可直接开始计时",
                    trailing = {
                        TextButton(onClick = { a.openTimer(LogType.Nurse) }) { Text("专注计时") }
                    },
                )
                QuickStrip(a.quickLog)
            }
        }

        if (todayPlay != null) {
            item("play") {
                val rec = records[todayPlay.code]
                TodayPlayCard(
                    play = todayPlay,
                    month = month,
                    done = todayPlay.code in done,
                    record = rec,
                    onOpen = { a.openPlay(todayPlay.code, month) },
                    onToggle = { a.toggleDid(month, todayPlay.code, todayPlay.name) },
                    onNext = nextChoice?.let { n -> { a.pickToday(n.code) } },
                )
            }
        }

        if (shelf.size > 1) {
            item("shelf") {
                SectionTitle(
                    "本周的架子",
                    kicker = "摆上 ${shelf.size} 样，不着急换",
                    trailing = { TextButton(onClick = a.openPlan) { Text("调整") } },
                )
                WeekShelf(shelf, done, records, month, a.openPlay)
            }
        }

        item("watch") {
            val total = guide.observe.sumOf { it.items.size }
            val checked = ui.ticks.values.count { it.month == month && it.kind == TickKind.Observed }
            SectionTitle(
                "这一站可以留意",
                kicker = "满 $month 个月 · 已记下 $checked / $total",
                trailing = { TextButton(onClick = { a.openMonth(month) }) { Text("全部 $total 项") } },
            )
            MilestonePeek(guide, month, ui, a.toggleObserved)
        }
    }
}

@Composable
private fun ResumeSessionBanner(
    play: Play,
    month: Int,
    step: Int,
    onResume: () -> Unit,
    onDismiss: () -> Unit,
) {
    Surface(
        onClick = onResume,
        shape = RoundedCornerShape(24.dp),
        color = MaterialTheme.colorScheme.secondaryContainer,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
    ) {
        Row(
            Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            val d0 = play.domains.firstOrNull() ?: "A"
            val c = areaColor(d0)
            ShapeBadge(areaGlyph(d0), c.copy(alpha = 0.16f), c, shape = Shapes.of(play.code), size = 44.dp)
            Column(Modifier.weight(1f)) {
                Text(
                    "接着做 · 第 ${step + 1} / ${play.steps.size} 步",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSecondaryContainer,
                )
                Text(
                    play.name,
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSecondaryContainer,
                )
            }
            TextButton(onClick = onDismiss) { Text("收起") }
            Button(onClick = onResume, shape = RoundedCornerShape(16.dp)) { Text("继续") }
        }
    }
}

@Composable
private fun Hero(
    ui: AppUi,
    age: Age?,
    guide: MonthGuide,
    mood: Mood,
    onPickBirth: () -> Unit,
    onOpenMonth: (Int) -> Unit,
    onSearch: () -> Unit,
    onMap: () -> Unit,
    onBook: () -> Unit,
    now: () -> Long,
) {
    Surface(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 8.dp),
        shape = RoundedCornerShape(32.dp),
        color = MaterialTheme.colorScheme.surfaceContainer,
    ) {
        Column(Modifier.statusBarsPadding().padding(horizontal = 20.dp, vertical = 16.dp)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
                Column(Modifier.weight(1f)) {
                    val name = ui.settings.nickname.ifBlank { null }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = (if (name != null) "$name · " else "") + "${md(ui.today)} · ${weekday(ui.today)}",
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.weight(1f),
                        )
                        Surface(
                            onClick = onSearch,
                            shape = CircleShape,
                            color = MaterialTheme.colorScheme.surfaceContainerHighest,
                            modifier = Modifier.size(36.dp).semantics { contentDescription = "搜索" },
                        ) {
                            Box(contentAlignment = Alignment.Center) { Glyph(G.Search, size = 18.dp) }
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                    if (age != null) {
                        Row(verticalAlignment = Alignment.Bottom) {
                            SandpaperNumber("${age.months}", MaterialTheme.typography.displayMedium)
                            Spacer(Modifier.width(10.dp))
                            Column(Modifier.padding(bottom = 2.dp)) {
                                Text(if (age.days > 0) "个月 ${age.days} 天" else "个月整", style = MaterialTheme.typography.headlineSmall)
                                Text("出生第 ${age.lived} 天", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                        Spacer(Modifier.height(10.dp))
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .clip(RoundedCornerShape(14.dp))
                                .clickable { onOpenMonth(age.bookMonth) }
                                .padding(vertical = 4.dp, horizontal = 2.dp),
                        ) {
                            BeadRing(done = age.days, total = (age.days + age.toNext).coerceAtLeast(1))
                            Spacer(Modifier.width(8.dp))
                            Text(
                                text = "第 ${age.bookMonth} 站 · ${guide.title}" + if (age.months < 36) " · 离下一站 ${age.toNext} 天" else "",
                                style = MaterialTheme.typography.labelLarge,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                        Row(
                            modifier = Modifier.padding(top = 6.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Surface(
                                onClick = onMap,
                                shape = RoundedCornerShape(12.dp),
                                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                            ) {
                                Row(
                                    Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                                ) {
                                    Glyph(G.Grow, size = 14.dp, color = MaterialTheme.colorScheme.primary)
                                    Text("0–36 个月成长地图", style = MaterialTheme.typography.labelMedium)
                                }
                            }
                            Surface(
                                onClick = onBook,
                                shape = RoundedCornerShape(12.dp),
                                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                            ) {
                                Row(
                                    Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
                                    verticalAlignment = Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                                ) {
                                    Glyph(G.Journal, size = 14.dp, color = MaterialTheme.colorScheme.primary)
                                    Text("成长册", style = MaterialTheme.typography.labelMedium)
                                }
                            }
                        }
                        if (ui.settings.journal && (ui.lastFeed != null || ui.lastSleep != null || ui.timers.isNotEmpty())) {
                            SinceLine(ui, now)
                        }
                    } else {
                        Text("还没有填出生日期", style = MaterialTheme.typography.headlineMedium)
                        Text(
                            "填好后，按孩子的月龄摆出今天能做的事；现在先看刚出生的第一站。",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                        Spacer(Modifier.height(10.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            FilledTonalButton(onClick = onPickBirth, shape = RoundedCornerShape(16.dp)) { Text("填写出生日期") }
                            TextButton(onClick = onMap) { Text("0–36 个月成长地图") }
                        }
                    }
                }
                Spacer(Modifier.width(8.dp))
                Duo(lead = ui.settings.companion, size = 84.dp, mood = mood)
            }
        }
    }
}

/** A circle of small beads: one for each day of the current month of life, filled up to today. */
@Composable
private fun BeadRing(done: Int, total: Int) {
    val empty = MaterialTheme.colorScheme.outlineVariant
    Canvas(Modifier.size(22.dp)) {
        val n = total.coerceIn(28, 31)
        val r = size.minDimension * 0.40f
        val c = Offset(size.width / 2, size.height / 2)
        for (i in 0 until n) {
            val a = (i.toFloat() / n) * 2f * PI.toFloat() - PI.toFloat() / 2f
            val p = c + Offset(cos(a) * r, sin(a) * r)
            drawCircle(if (i <= done) Palette.Bead else empty, radius = if (i == done) 2.3f else 1.6f, center = p)
        }
    }
}

/** How long since the last feed and the last sleep, plus awake window prompt ("醒了 X 分钟 · 一起玩"). */
@Composable
private fun SinceLine(ui: AppUi, nowSource: () -> Long) {
    var now by remember { mutableLongStateOf(nowSource()) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(30_000)
            now = nowSource()
        }
    }
    fun ago(at: Long): String {
        val m = ((now - at).coerceAtLeast(0) / 60_000).toInt()
        return when {
            m < 2 -> "刚刚"
            m < 60 -> "$m 分钟前"
            m < 1440 -> "${m / 60} 小时" + (if (m % 60 >= 10) " ${m % 60} 分" else "") + "前"
            else -> "${m / 1440} 天前"
        }
    }
    val sleepRunning = ui.timers.any { it.type == LogType.Sleep }
    val nurseRunning = ui.timers.any { it.type == LogType.Nurse }
    val awakeMin = if (!sleepRunning && ui.lastSleep?.end != null) {
        ((now - ui.lastSleep.end).coerceAtLeast(0) / 60_000).toInt()
    } else null

    val parts = buildList {
        when {
            sleepRunning -> add("正在睡觉")
            nurseRunning -> add("正在亲喂")
            awakeMin != null && awakeMin in 5..240 -> add("醒了 $awakeMin 分钟 · 一起玩")
        }
        ui.lastFeed?.let { add("上次喂 ${ago(it.end ?: it.start)}") }
        if (!sleepRunning) {
            ui.lastSleep?.let { add(if (it.end == null) "正在睡" else "上一觉 ${ago(it.end)}") }
        }
    }
    if (parts.isNotEmpty()) {
        Text(
            parts.joinToString(" · "),
            fontFamily = Numerals,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

@Composable
private fun QuickStrip(onPick: (String) -> Unit) {
    val items = listOf(LogType.Nurse, LogType.Bottle, LogType.Sleep, LogType.Diaper, "more")
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        items.forEach { t ->
            val k = if (t == "more") null else logKind(t)
            val label = k?.label ?: "更多"
            val g = k?.glyph ?: G.Plus
            val bg = k?.tint?.copy(alpha = 0.16f) ?: MaterialTheme.colorScheme.surfaceContainerHighest
            val fg = k?.tint ?: MaterialTheme.colorScheme.onSurface
            Surface(
                onClick = { onPick(t) },
                modifier = Modifier.weight(1f),
                shape = RoundedCornerShape(22.dp),
                color = MaterialTheme.colorScheme.surfaceContainerLow,
            ) {
                Column(Modifier.padding(vertical = 10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    ShapeBadge(g, bg, fg, shape = Shapes.of(t), size = 36.dp)
                    Spacer(Modifier.height(4.dp))
                    Text(label, style = MaterialTheme.typography.labelMedium)
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun TodayPlayCard(
    play: Play,
    month: Int,
    done: Boolean,
    record: PlayRecord?,
    onOpen: () -> Unit,
    onToggle: () -> Unit,
    onNext: (() -> Unit)? = null,
) {
    val ctx = LocalContext.current
    val firstPic = remember(play.code) { ArtIndex.steps(ctx, play.code).firstOrNull() }
    val playedToday = (record?.todayCount ?: 0) > 0
    val totalCount = maxOf(record?.total ?: 0, if (done) 1 else 0)

    WorkTray(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .clickable(onClick = onOpen),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("今天一起玩", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
                    if (playedToday) {
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = MaterialTheme.colorScheme.primaryContainer,
                        ) {
                            Text(
                                "今天玩过",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onPrimaryContainer,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                            )
                        }
                    } else if (totalCount > 0) {
                        Surface(
                            shape = RoundedCornerShape(10.dp),
                            color = MaterialTheme.colorScheme.tertiaryContainer,
                        ) {
                            Text(
                                "做过 ×$totalCount",
                                fontFamily = Numerals,
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onTertiaryContainer,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                            )
                        }
                    }
                }
                Spacer(Modifier.height(4.dp))
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.Center,
                ) {
                    Text(
                        play.code,
                        fontFamily = Numerals,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.shared("play-code-${play.code}"),
                    )
                    play.domains.forEach { d -> ColorTablet(areaColor(d)) }
                }
            }
            Box(
                Modifier
                    .size(48.dp)
                    .clickable(onClick = onToggle)
                    .semantics {
                        role = Role.Checkbox
                        contentDescription = "记为今天做过"
                        stateDescription = if (done) "已做过" else "未做"
                    },
                contentAlignment = Alignment.Center,
            ) {
                MorphBlob(
                    done,
                    from = Shapes.Circle,
                    to = Shapes.Burst,
                    color = if (done) Palette.Bead else MaterialTheme.colorScheme.surfaceContainerHigh,
                    modifier = Modifier.size(44.dp),
                )
                Glyph(G.Check, size = 20.dp, color = if (done) Palette.Ink else MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Spacer(Modifier.height(10.dp))
        if (firstPic != null) {
            Art(
                firstPic,
                label = "${play.name}，第一步",
                modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)),
            )
        } else {
            MaterialStill(
                familyOf(play.domains),
                Modifier.fillMaxWidth().clip(RoundedCornerShape(20.dp)),
                ground = MaterialTheme.colorScheme.surfaceContainer,
            )
        }
        Spacer(Modifier.height(12.dp))
        Text(
            play.name,
            style = MaterialTheme.typography.headlineMedium,
            modifier = Modifier.shared("play-title-${play.code}"),
        )
        Spacer(Modifier.height(8.dp))
        if (play.prepare.isNotEmpty() && play.prepare != "无" && play.prepare != "不需要任何道具") {
            Tagged("准备", play.prepare)
        }
        play.steps.firstOrNull()?.let { Tagged("怎么做", it) }
        if (play.observe.isNotEmpty()) Tagged("留意", play.observe)
        if (play.safety.isNotEmpty()) Tagged("注意", play.safety, tagColor = MaterialTheme.colorScheme.error)
        Spacer(Modifier.height(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                if (play.steps.size > 1) "共 ${play.steps.size} 步 · 点开跟着做" else "点开看完整做法",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.weight(1f),
            )
            if (onNext != null) {
                TextButton(onClick = onNext) { Text("换一个") }
                Spacer(Modifier.width(4.dp))
            }
            Button(onClick = onOpen, shape = RoundedCornerShape(16.dp)) { Text("开始") }
        }
    }
}

/** Up to three plays sitting side by side on a wooden shelf plank, with tray art and golden play beads. */
@Composable
private fun WeekShelf(
    plays: List<Play>,
    done: Set<String>,
    records: Map<String, PlayRecord>,
    month: Int,
    onOpen: (String, Int) -> Unit,
) {
    WoodShelf(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            plays.take(3).forEach { p ->
                val isDone = p.code in done
                val rec = records[p.code]
                val weekCount = maxOf(rec?.thisWeek ?: 0, if (isDone) 1 else 0)
                Surface(
                    onClick = { onOpen(p.code, month) },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp, bottomStart = 8.dp, bottomEnd = 8.dp),
                    color = MaterialTheme.colorScheme.surfaceContainerLowest,
                ) {
                    Column(Modifier.padding(10.dp)) {
                        Box(
                            Modifier
                                .fillMaxWidth()
                                .clip(RoundedCornerShape(14.dp)),
                            contentAlignment = Alignment.Center,
                        ) {
                            MaterialStill(
                                family = familyOf(p.domains),
                                modifier = Modifier.fillMaxWidth(),
                                ground = MaterialTheme.colorScheme.surfaceContainer,
                            )
                            if (weekCount > 0) {
                                Row(
                                    modifier = Modifier
                                        .align(Alignment.TopEnd)
                                        .padding(6.dp),
                                    horizontalArrangement = Arrangement.spacedBy(3.dp),
                                ) {
                                    repeat(weekCount.coerceAtMost(5)) {
                                        Box(Modifier.size(8.dp).background(Palette.Bead, CircleShape))
                                    }
                                }
                            }
                        }
                        Spacer(Modifier.height(6.dp))
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            ColorTablet(areaColor(p.domains.firstOrNull() ?: "A"))
                            Text(
                                p.code,
                                fontFamily = Numerals,
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.shared("play-code-${p.code}"),
                            )
                        }
                        Text(
                            p.name,
                            style = MaterialTheme.typography.titleSmall,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.padding(top = 2.dp),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun MilestonePeek(guide: MonthGuide, month: Int, ui: AppUi, onToggle: (Int, String, String) -> Unit) {
    val all = guide.observe.flatMapIndexed { gi, g -> g.items.mapIndexed { ii, text -> Triple("$gi-$ii", g.group, text) } }
    val done = all.count { (id, _, _) -> tickKey(month, TickKind.Observed, id) in ui.ticks }
    val shown = all.sortedBy { (id, _, _) -> if (tickKey(month, TickKind.Observed, id) in ui.ticks) 1 else 0 }.take(3)
    Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        NumberRod(done, all.size, Modifier.padding(bottom = 10.dp))
        shown.forEachIndexed { idx, (id, group, text) ->
            val checked = tickKey(month, TickKind.Observed, id) in ui.ticks
            Row(
                Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .clickable { onToggle(month, id, text) }
                    .padding(vertical = 8.dp),
                verticalAlignment = Alignment.Top,
            ) {
                SmallCheck(checked, Modifier.padding(top = 2.dp))
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(group, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text(text, style = MaterialTheme.typography.bodyMedium)
                }
            }
            if (idx < shown.lastIndex) Spacer(Modifier.height(2.dp))
        }
        AnimatedVisibility(done == all.size && all.isNotEmpty()) {
            Text(
                "这一站的每一项都记下了。",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(top = 6.dp),
            )
        }
    }
}

@Composable
fun SmallCheck(checked: Boolean, modifier: Modifier = Modifier) {
    val stroke = MaterialTheme.colorScheme.outline
    Canvas(modifier.size(22.dp)) {
        val r = size.minDimension / 2
        if (checked) {
            drawCircle(Palette.Moss, r)
            val p = androidx.compose.ui.graphics.Path().apply {
                moveTo(size.width * 0.28f, size.height * 0.52f)
                lineTo(size.width * 0.44f, size.height * 0.68f)
                lineTo(size.width * 0.74f, size.height * 0.34f)
            }
            drawPath(p, Palette.Paper, style = Stroke(2.2.dp.toPx(), cap = StrokeCap.Round))
        } else {
            drawCircle(stroke, r - 1.dp.toPx(), style = Stroke(1.6.dp.toPx()))
        }
    }
}
