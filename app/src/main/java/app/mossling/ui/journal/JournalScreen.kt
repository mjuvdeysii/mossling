package app.mossling.ui.journal

import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.mossling.AppUi
import app.mossling.data.LogEntry
import app.mossling.data.LogType
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.SectionTitle
import app.mossling.ui.components.hm
import app.mossling.ui.components.md
import app.mossling.ui.components.minutes
import app.mossling.ui.components.weekday
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.Mood
import app.mossling.ui.theme.LocalCompanion
import app.mossling.ui.theme.Numerals
import java.time.LocalDate

data class JournalActions(
    val pickDay: (LocalDate) -> Unit = {},
    val log: (String) -> Unit = {},
    val open: (LogEntry) -> Unit = {},
    val stats: () -> Unit = {},
    val growth: () -> Unit = {},
    /** add an entry after the fact, on the selected day */
    val backfill: () -> Unit = {},
    val timer: TimerActions = TimerActions(),
)

/** The day, as it happened. Quick buttons at the top, then the day's entries with a small summary. */
@Composable
fun JournalScreen(ui: AppUi, day: LocalDate, logs: List<LogEntry>, a: JournalActions, modifier: Modifier = Modifier, last: Map<String, Long> = emptyMap(), now: () -> Long = System::currentTimeMillis) {
    val companion = LocalCompanion.current
    LazyColumn(modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 40.dp)) {
        item("head") {
            Row(Modifier.statusBarsPadding().padding(start = 20.dp, end = 12.dp, top = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("手帐", style = MaterialTheme.typography.headlineLarge)
                    Text(if (day == ui.today) "今天 · ${md(day)}" else "${md(day)} · ${weekday(day)}", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                app.mossling.ui.ip.Duo(companion, size = 60.dp, mood = if (ui.timers.any { it.type == LogType.Sleep }) Mood.Sleep else Mood.Open, look = Offset(0.2f, 0.7f))
            }
        }
        // what is running comes first: it is what the hands are busy with
        if (ui.timers.isNotEmpty()) item("timers") {
            Column(Modifier.padding(horizontal = 16.dp).padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                ui.timers.forEach { t -> TimerCard(t, a.timer, now = now) }
            }
        }
        item("grid") {
            val t = now()
            Column(Modifier.padding(horizontal = 16.dp).padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                LogKinds.chunked(4).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        row.forEach { k -> LogButton(k, ui.timers.any { it.type == k.type }, onClick = { a.log(k.type) }, modifier = Modifier.weight(1f), since = last[k.type]?.let { ago(it, t) }) }
                        repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        }
        item("week") { Week(ui.today, day, a.pickDay) }
        item("ribbon") { DayRibbon(day, logs, ui.timers, now) }
        item("sum") { Summary(logs) }
        item("title") {
            SectionTitle(if (logs.isEmpty()) "这一天还没有记录" else "这一天", kicker = if (logs.isEmpty()) null else "${logs.size} 条", trailing = {
                androidx.compose.material3.TextButton(onClick = a.backfill) { Glyph(G.Plus, size = 18.dp); Text(" 补记") }
            })
        }
        itemsIndexed(logs, key = { _, e -> e.id }) { i, e -> Entry(e, first = i == 0, last = i == logs.lastIndex) { a.open(e) } }
        item("more") {
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 24.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(Triple(G.Chart, "统计", a.stats), Triple(G.Ruler, "生长曲线", a.growth)).forEach { (g, t, f) ->
                    Surface(onClick = f, shape = RoundedCornerShape(22.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.weight(1f)) {
                        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                            app.mossling.ui.components.ShapeBadge(g, MaterialTheme.colorScheme.primary.copy(alpha = 0.12f), MaterialTheme.colorScheme.primary, shape = app.mossling.ui.components.Shapes.of(t), size = 36.dp)
                            Text(t, style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(start = 10.dp))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Week(today: LocalDate, day: LocalDate, pick: (LocalDate) -> Unit) {
    var end = day.plusDays(3); if (end.isAfter(today)) end = today
    Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 12.dp), horizontalArrangement = Arrangement.SpaceBetween) {
        for (i in 6 downTo 0) {
            val d = end.minusDays(i.toLong()); val on = d == day
            Surface(onClick = { pick(d) }, shape = RoundedCornerShape(18.dp), color = if (on) MaterialTheme.colorScheme.primary else Color.Transparent, contentColor = if (on) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface, modifier = Modifier.width(46.dp).heightIn(min = 62.dp)) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center, modifier = Modifier.padding(vertical = 8.dp)) {
                    Text(weekday(d).takeLast(1), style = MaterialTheme.typography.labelSmall)
                    Text("${d.dayOfMonth}", fontFamily = Numerals, style = MaterialTheme.typography.titleLarge, textAlign = TextAlign.Center)
                }
            }
        }
    }
}

@Composable
private fun Summary(logs: List<LogEntry>) {
    val feeds = logs.count { it.type == LogType.Nurse || it.type == LogType.Bottle }
    val ml = logs.filter { it.type == LogType.Bottle }.sumOf { it.amount ?: 0 }
    val sleep = logs.filter { it.type == LogType.Sleep && it.end != null }.sumOf { it.end!! - it.start }
    val diapers = logs.count { it.type == LogType.Diaper }
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Fact("$feeds", "次喂奶", Modifier.weight(1f), sub = if (ml > 0) "瓶喂 $ml 毫升" else null)
        Fact(if (sleep > 0) "%.1f".format(sleep / 3_600_000.0) else "0", "小时睡眠", Modifier.weight(1f))
        Fact("$diapers", "片尿布", Modifier.weight(1f))
    }
}

@Composable
private fun Fact(n: String, label: String, modifier: Modifier, sub: String? = null) {
    Surface(shape = RoundedCornerShape(22.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = modifier) {
        Column(Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            Text(n, fontFamily = Numerals, style = MaterialTheme.typography.displaySmall)
            Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (sub != null) Text(sub, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
        }
    }
}

/** One entry on the day's thread: time, a coloured bead with its pictogram, a line joining it to the next. */
@Composable
private fun Entry(e: LogEntry, first: Boolean = false, last: Boolean = false, onClick: () -> Unit) {
    val k = logKind(e.type)
    val thread = MaterialTheme.colorScheme.outlineVariant
    Surface(onClick = onClick, color = Color.Transparent, modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(horizontal = 20.dp).height(androidx.compose.foundation.layout.IntrinsicSize.Min), verticalAlignment = Alignment.CenterVertically) {
            Text(hm(e.start), fontFamily = Numerals, style = MaterialTheme.typography.titleLarge, softWrap = false, modifier = Modifier.widthIn(min = 64.dp).padding(end = 8.dp))
            Box(Modifier.width(36.dp).fillMaxHeight(), contentAlignment = Alignment.Center) {
                androidx.compose.foundation.Canvas(Modifier.matchParentSize()) {
                    val x = size.width / 2
                    if (!first) drawLine(thread, androidx.compose.ui.geometry.Offset(x, 0f), androidx.compose.ui.geometry.Offset(x, size.height / 2), 2.dp.toPx())
                    if (!last) drawLine(thread, androidx.compose.ui.geometry.Offset(x, size.height / 2), androidx.compose.ui.geometry.Offset(x, size.height), 2.dp.toPx())
                }
                Box(Modifier.padding(vertical = 10.dp).size(36.dp).clip(CircleShape).background(MaterialTheme.colorScheme.background).background(k.tint.copy(alpha = 0.14f)), contentAlignment = Alignment.Center) { Glyph(k.glyph, size = 20.dp, color = k.tint) }
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(k.name, style = MaterialTheme.typography.titleMedium)
                val d = listOfNotNull(e.end?.let { "${hm(e.start)}–${hm(it)}" }, describe(e).ifBlank { null }).joinToString(" · ")
                if (d.isNotBlank()) Text(d, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

/**
 * The day as one strip from midnight to midnight: sleeps and feeds as blocks of their length, everything else as a
 * mark at its time, what is running now drawn up to the present. All 24 hours fit the width — nothing to scroll.
 */
@Composable
private fun DayRibbon(day: LocalDate, logs: List<LogEntry>, running: List<app.mossling.data.RunningTimer>, now: () -> Long) {
    val z = java.time.ZoneId.systemDefault()
    val d0 = day.atStartOfDay(z).toInstant().toEpochMilli(); val d1 = d0 + 86_400_000L
    val track = MaterialTheme.colorScheme.surfaceContainerHigh
    val nowLine = MaterialTheme.colorScheme.primary
    val t = now()
    Surface(shape = RoundedCornerShape(24.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 4.dp)) {
        Column(Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            androidx.compose.foundation.Canvas(Modifier.fillMaxWidth().height(44.dp).semantics { contentDescription = "这一天的时间条：" + logs.size + " 条记录" }) {
                fun x(ms: Long) = ((ms - d0).toFloat() / (d1 - d0) * size.width).coerceIn(0f, size.width)
                val top = 6.dp.toPx(); val h = size.height - 12.dp.toPx()
                drawRoundRect(track, androidx.compose.ui.geometry.Offset(0f, top), androidx.compose.ui.geometry.Size(size.width, h), androidx.compose.ui.geometry.CornerRadius(h / 2))
                for (hr in listOf(6, 12, 18)) drawLine(Color.Black.copy(alpha = 0.06f), androidx.compose.ui.geometry.Offset(size.width * hr / 24f, top), androidx.compose.ui.geometry.Offset(size.width * hr / 24f, top + h), 1.dp.toPx())
                fun block(a: Long, b: Long, c: Color, inset: Float) {
                    if (b <= d0 || a >= d1) return
                    val l = x(a); val r = x(b).coerceAtLeast(l + 3.dp.toPx())
                    drawRoundRect(c, androidx.compose.ui.geometry.Offset(l, top + inset), androidx.compose.ui.geometry.Size(r - l, h - 2 * inset), androidx.compose.ui.geometry.CornerRadius((h - 2 * inset) / 2))
                }
                logs.forEach { e ->
                    val k = logKind(e.type)
                    when {
                        e.end != null -> block(e.start, e.end, k.tint.copy(alpha = if (e.type == LogType.Sleep) 0.85f else 0.95f), if (e.type == LogType.Sleep) 0f else 5.dp.toPx())
                        e.start in d0 until d1 -> drawCircle(k.tint, 4.dp.toPx(), androidx.compose.ui.geometry.Offset(x(e.start), top + h / 2))
                    }
                }
                running.forEach { r -> block(r.start, t, logKind(r.type).tint.copy(alpha = 0.55f), if (r.type == LogType.Sleep) 0f else 5.dp.toPx()) }
                if (t in d0 until d1) drawLine(nowLine, androidx.compose.ui.geometry.Offset(x(t), 0f), androidx.compose.ui.geometry.Offset(x(t), size.height), 2.dp.toPx())
            }
            Row(Modifier.fillMaxWidth()) {
                // each label starts exactly where its hour line is
                listOf("0 点", "6 点", "12 点", "18 点").forEach { s ->
                    Text(s, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Start, modifier = Modifier.weight(1f))
                }
            }
        }
    }
}
