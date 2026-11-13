package app.mossling.ui.journal

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.mossling.AppUi
import app.mossling.data.LogEntry
import app.mossling.data.LogType
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.NumberRod
import app.mossling.ui.components.Plate
import app.mossling.ui.components.SectionTitle
import app.mossling.ui.components.ShapeBadge
import app.mossling.ui.components.Shapes
import app.mossling.ui.components.hm
import app.mossling.ui.components.md
import app.mossling.ui.components.minutes
import app.mossling.ui.components.startOf
import app.mossling.ui.components.weekday
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.Mood
import app.mossling.ui.theme.Numerals
import kotlinx.coroutines.delay
import java.time.LocalDate

data class JournalActions(
    val setDay: (LocalDate) -> Unit = {},
    val openSheet: (String) -> Unit = {},
    val editEntry: (LogEntry) -> Unit = {},
    val delete: (Long) -> Unit = {},
    val pauseTimer: (String) -> Unit = {},
    val switchSide: (String) -> Unit = {},
    val shiftTimer: (String, Long) -> Unit = { _, _ -> },
    val stopTimer: (String) -> Unit = {},
    val discardTimer: (String) -> Unit = {},
    val turnOn: () -> Unit = {},
    val openStats: () -> Unit = {},
    val openGrowth: () -> Unit = {},
    val openFirsts: () -> Unit = {},
    val openTimerModal: ((String) -> Unit)? = null,
)

private enum class LogFilter(val label: String) {
    All("全部"),
    Feed("喂养"),
    Sleep("睡眠"),
    Diaper("尿布"),
    Other("其他"),
}

private fun LogEntry.matches(filter: LogFilter): Boolean = when (filter) {
    LogFilter.All -> true
    LogFilter.Feed -> type == LogType.Nurse || type == LogType.Bottle || type == LogType.Solid
    LogFilter.Sleep -> type == LogType.Sleep
    LogFilter.Diaper -> type == LogType.Diaper
    LogFilter.Other -> type != LogType.Nurse && type != LogType.Bottle && type != LogType.Solid && type != LogType.Sleep && type != LogType.Diaper
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun JournalScreen(
    ui: AppUi,
    day: LocalDate,
    logs: List<LogEntry>,
    a: JournalActions,
    last: Map<String, Long> = emptyMap(),
    now: () -> Long = System::currentTimeMillis,
) {
    if (!ui.settings.journal) {
        JournalOffState(ui, a.turnOn)
        return
    }
    var nowMs by remember { mutableLongStateOf(now()) }
    var filter by rememberSaveable(day.toString()) { mutableStateOf(LogFilter.All) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(30_000)
            nowMs = now()
        }
    }
    fun ago(t: Long?): String? = t?.let {
        val m = ((nowMs - it).coerceAtLeast(0) / 60_000).toInt()
        when {
            m < 2 -> "刚刚"
            m < 60 -> "$m 分钟前"
            m < 1440 -> "${m / 60} 小时前"
            else -> "${m / 1440} 天前"
        }
    }

    val primary = listOf(LogType.Nurse, LogType.Bottle, LogType.Sleep, LogType.Diaper)
    val secondary = listOf(LogType.Solid, LogType.Bath, LogType.Temp, LogType.Med, LogType.Note)
    val filteredLogs = remember(logs, filter) { logs.filter { it.matches(filter) } }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 112.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            DayBar(
                day = day,
                today = ui.today,
                onPick = a.setDay,
                onStats = a.openStats,
                onGrowth = a.openGrowth,
                onFirsts = a.openFirsts,
            )
        }
        items(ui.timers, key = { "t:${it.type}" }) { t ->
            TimerCard(
                t = t,
                onPause = { a.pauseTimer(t.type) },
                onSwitchSide = { a.switchSide(t.type) },
                onShift = { a.shiftTimer(t.type, it) },
                onStop = { a.stopTimer(t.type) },
                onDiscard = { a.discardTimer(t.type) },
                modifier = Modifier.padding(horizontal = 16.dp),
                onExpand = a.openTimerModal?.let { open -> { open(t.type) } },
                now = now,
            )
        }
        item {
            Column(Modifier.padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    primary.forEach { t ->
                        val k = logKind(t)
                        Surface(
                            onClick = { a.openSheet(t) },
                            modifier = Modifier.weight(1f),
                            shape = RoundedCornerShape(22.dp),
                            color = MaterialTheme.colorScheme.surfaceContainer,
                        ) {
                            Column(Modifier.padding(vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                ShapeBadge(k.glyph, k.tint.copy(alpha = 0.18f), k.tint, shape = Shapes.of(t), size = 40.dp)
                                Spacer(Modifier.height(6.dp))
                                Text(k.label, style = MaterialTheme.typography.titleSmall)
                                ago(last[t])?.let {
                                    Text(
                                        it,
                                        fontFamily = Numerals,
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                            }
                        }
                    }
                }
                FlowRow(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    secondary.forEach { t ->
                        val k = logKind(t)
                        Surface(
                            onClick = { a.openSheet(t) },
                            shape = RoundedCornerShape(16.dp),
                            color = MaterialTheme.colorScheme.surfaceContainerLow,
                        ) {
                            Row(Modifier.padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                                Glyph(k.glyph, size = 16.dp, color = k.tint)
                                Spacer(Modifier.width(6.dp))
                                Text(k.label, style = MaterialTheme.typography.labelLarge)
                            }
                        }
                    }
                }
            }
        }
        item { DaySummary(day, logs) }
        if (logs.isEmpty()) {
            item {
                Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp), color = MaterialTheme.colorScheme.surfaceContainerLow) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("这一天还没有记下什么", style = MaterialTheme.typography.titleMedium)
                            Text(
                                "点上面任一按钮就能记一笔；不记也没关系。",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(top = 4.dp),
                            )
                        }
                        Creature(ui.settings.companion, Modifier.size(64.dp), mood = Mood.Calm)
                    }
                }
            }
        } else {
            item {
                SectionTitle("这一天", kicker = "${logs.size} 条 · 点任意一条可改时间或删除")
                LazyRow(
                    contentPadding = PaddingValues(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(LogFilter.entries) { f ->
                        val c = logs.count { it.matches(f) }
                        if (f == LogFilter.All || c > 0) {
                            FilterChip(
                                selected = filter == f,
                                onClick = { filter = f },
                                label = { Text("${f.label} ($c)") },
                            )
                        }
                    }
                }
            }
            items(filteredLogs, key = { it.id }) { e ->
                LogRow(e, onClick = { a.editEntry(e) }, modifier = Modifier.padding(horizontal = 16.dp))
            }
        }
    }
}

@Composable
private fun DayBar(
    day: LocalDate,
    today: LocalDate,
    onPick: (LocalDate) -> Unit,
    onStats: () -> Unit,
    onGrowth: () -> Unit,
    onFirsts: () -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .statusBarsPadding()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(
            Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            OutlinedButton(
                onClick = { onPick(day.minusDays(1)) },
                shape = RoundedCornerShape(14.dp),
                contentPadding = PaddingValues(horizontal = 10.dp),
            ) {
                Text("前一天")
            }
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(if (day == today) "今天 · ${md(day)}" else md(day), style = MaterialTheme.typography.headlineSmall)
                Text(weekday(day), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            if (day < today) {
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    AssistChip(onClick = { onPick(today) }, label = { Text("回今天") })
                    OutlinedButton(
                        onClick = { onPick(day.plusDays(1)) },
                        shape = RoundedCornerShape(14.dp),
                        contentPadding = PaddingValues(horizontal = 10.dp),
                    ) {
                        Text("后一天")
                    }
                }
            } else {
                Row {
                    TextButton(onClick = onFirsts, contentPadding = PaddingValues(horizontal = 6.dp)) {
                        Glyph(G.Heart, size = 16.dp)
                        Text(" 第一次")
                    }
                    TextButton(onClick = onGrowth, contentPadding = PaddingValues(horizontal = 6.dp)) {
                        Glyph(G.Ruler, size = 16.dp)
                        Text(" 生长")
                    }
                    TextButton(onClick = onStats, contentPadding = PaddingValues(horizontal = 6.dp)) {
                        Glyph(G.Chart, size = 16.dp)
                        Text(" 统计")
                    }
                }
            }
        }
        if (day < today) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                TextButton(onClick = onFirsts, contentPadding = PaddingValues(horizontal = 8.dp)) {
                    Glyph(G.Heart, size = 15.dp)
                    Text(" 第一次")
                }
                TextButton(onClick = onGrowth, contentPadding = PaddingValues(horizontal = 8.dp)) {
                    Glyph(G.Ruler, size = 15.dp)
                    Text(" 生长")
                }
                TextButton(onClick = onStats, contentPadding = PaddingValues(horizontal = 8.dp)) {
                    Glyph(G.Chart, size = 15.dp)
                    Text(" 统计")
                }
            }
        }
    }
}

@Composable
private fun DaySummary(day: LocalDate, logs: List<LogEntry>) {
    val feeds = logs.count { it.type == LogType.Nurse || it.type == LogType.Bottle }
    val bottleMl = logs.filter { it.type == LogType.Bottle }.sumOf { it.amount ?: 0 }
    val sleepMs = logs.filter { it.type == LogType.Sleep && it.end != null }.sumOf { (it.end!! - it.start).coerceAtLeast(0) }
    val diapers = logs.count { it.type == LogType.Diaper }
    Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        DayRibbon(day, logs)
        Spacer(Modifier.height(14.dp))
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SummaryRod("喂养", if (bottleMl > 0) "$feeds 次 · 瓶喂 $bottleMl ml" else "$feeds 次", feeds, 8)
            SummaryRod("睡眠", if (sleepMs > 0) minutes(sleepMs) else "—", (sleepMs / 1_800_000L).toInt(), 10)
            SummaryRod("尿布", "$diapers 片", diapers, 8)
        }
    }
}

/** The 24 hours of [day], drawn as a Montessori bead thread. */
@Composable
private fun DayRibbon(day: LocalDate, logs: List<LogEntry>) {
    val d0 = startOf(day)
    val span = 86_400_000f
    val wire = MaterialTheme.colorScheme.outlineVariant
    val tick = MaterialTheme.colorScheme.outline
    Column {
        Canvas(Modifier.fillMaxWidth().height(26.dp)) {
            val cy = size.height / 2
            drawLine(wire, Offset(0f, cy), Offset(size.width, cy), 1.4.dp.toPx())
            listOf(0, 6, 12, 18, 24).forEach { h ->
                val x = (h / 24f) * size.width
                drawLine(tick, Offset(x, cy - 4.dp.toPx()), Offset(x, cy + 4.dp.toPx()), 1.dp.toPx())
            }
            logs.forEach { e ->
                val c = logKind(e.type).tint
                val x1 = (((e.start - d0) / span).coerceIn(0f, 1f)) * size.width
                if (e.end != null && e.end > e.start) {
                    val x2 = (((e.end - d0) / span).coerceIn(0f, 1f)) * size.width
                    val n = (((x2 - x1) / 8.dp.toPx()).toInt()).coerceAtLeast(2)
                    for (i in 0 until n) {
                        val bx = x1 + (x2 - x1) * (i + 0.5f) / n
                        drawCircle(c, 4.dp.toPx(), Offset(bx, cy))
                    }
                } else {
                    drawCircle(c, 5.dp.toPx(), Offset(x1, cy))
                }
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            listOf("0时", "6时", "12时", "18时", "24时").forEach {
                Text(it, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun SummaryRod(label: String, value: String, n: Int, scale: Int) {
    Column {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
            Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
            Text(value, fontFamily = Numerals, style = MaterialTheme.typography.titleMedium)
        }
        Spacer(Modifier.height(4.dp))
        NumberRod(n, scale, height = 8.dp)
    }
}

@Composable
private fun LogRow(e: LogEntry, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val k = logKind(e.type)
    val detail = buildList {
        when (e.side) {
            "l" -> add("左侧")
            "r" -> add("右侧")
            "b" -> add("双侧")
        }
        if (e.end != null) add(minutes((e.end - e.start).coerceAtLeast(0)))
        if (e.type == LogType.Bottle && e.amount != null) add("${e.amount} 毫升")
        if (e.type == LogType.Temp && e.amount != null) add("%.1f ℃".format(e.amount / 10.0))
        if (e.type == LogType.Diaper) add(
            when (e.detail) {
                "wet" -> "湿了"
                "dirty" -> "便便"
                "both" -> "湿了 + 便便"
                else -> e.detail ?: ""
            }
        ) else if (!e.detail.isNullOrEmpty() && !e.detail.startsWith("paused:")) {
            add(e.detail)
        }
    }.filter { it.isNotEmpty() }.joinToString(" · ")

    Surface(onClick = onClick, modifier = modifier.fillMaxWidth(), shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.surfaceContainerLowest) {
        Row(Modifier.padding(horizontal = 16.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            ShapeBadge(k.glyph, k.tint.copy(alpha = 0.16f), k.tint, shape = Shapes.of(e.type), size = 36.dp)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(k.label, style = MaterialTheme.typography.titleMedium)
                if (detail.isNotEmpty()) Text(detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text(
                if (e.end != null) "${hm(e.start)}–${hm(e.end)}" else hm(e.start),
                fontFamily = Numerals,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun JournalOffState(ui: AppUi, onTurnOn: () -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Creature(ui.settings.companion, Modifier.size(120.dp), mood = Mood.Calm)
        Spacer(Modifier.height(16.dp))
        Text("手帐是可选的", style = MaterialTheme.typography.headlineMedium, textAlign = TextAlign.Center)
        Text(
            "想记喂奶、换尿布、睡觉的时候打开它；不想被数字追着跑的时候，随时在「我的」里关掉。关掉不会删掉已记的内容。",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp),
        )
        Spacer(Modifier.height(20.dp))
        Button(onClick = onTurnOn, shape = RoundedCornerShape(18.dp), modifier = Modifier.height(50.dp)) {
            Text("开启手帐", style = MaterialTheme.typography.titleMedium)
        }
    }
}
