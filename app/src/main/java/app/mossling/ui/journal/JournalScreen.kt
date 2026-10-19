package app.mossling.ui.journal

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
)

/** The day, as it happened. Quick buttons at the top, then the day's entries with a small summary. */
@Composable
fun JournalScreen(ui: AppUi, day: LocalDate, logs: List<LogEntry>, a: JournalActions, modifier: Modifier = Modifier) {
    val companion = LocalCompanion.current
    LazyColumn(modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 40.dp)) {
        item("head") {
            Row(Modifier.statusBarsPadding().padding(start = 20.dp, end = 12.dp, top = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("手帐", style = MaterialTheme.typography.headlineLarge)
                    Text(if (day == ui.today) "今天 · ${md(day)}" else "${md(day)} · ${weekday(day)}", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Creature(companion, Modifier.size(64.dp), mood = if (ui.timers.any { it.type == LogType.Sleep }) Mood.Sleep else Mood.Open, look = Offset(0f, 0.7f))
            }
        }
        item("week") { Week(ui.today, day, a.pickDay) }
        item("grid") {
            Column(Modifier.padding(horizontal = 16.dp).padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                LogKinds.chunked(4).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        row.forEach { k -> LogButton(k, ui.timers.any { it.type == k.type }, onClick = { a.log(k.type) }, modifier = Modifier.weight(1f)) }
                        repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
                    }
                }
            }
        }
        item("sum") { Summary(logs) }
        item("title") { SectionTitle(if (logs.isEmpty()) "还没有记录" else "这一天", kicker = if (logs.isEmpty()) null else "${logs.size} 条") }
        items(logs, key = { it.id }) { e -> Entry(e) { a.open(e) } }
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
        Fact("$feeds", "次喂奶" + if (ml > 0) " · $ml 毫升" else "", Modifier.weight(1f))
        Fact(if (sleep > 0) "%.1f".format(sleep / 3_600_000.0) else "0", "小时睡眠", Modifier.weight(1f))
        Fact("$diapers", "片尿布", Modifier.weight(1f))
    }
}

@Composable
private fun Fact(n: String, label: String, modifier: Modifier) {
    Surface(shape = RoundedCornerShape(22.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = modifier) {
        Column(Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            Text(n, fontFamily = Numerals, style = MaterialTheme.typography.displaySmall)
            Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun Entry(e: LogEntry, onClick: () -> Unit) {
    val k = logKind(e.type)
    Surface(onClick = onClick, color = Color.Transparent, modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(horizontal = 20.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(hm(e.start), fontFamily = Numerals, style = MaterialTheme.typography.titleLarge, softWrap = false, modifier = Modifier.widthIn(min = 64.dp).padding(end = 8.dp))
            Box(Modifier.size(36.dp).clip(CircleShape).background(k.tint.copy(alpha = 0.12f)), contentAlignment = Alignment.Center) { Glyph(k.glyph, size = 20.dp, color = k.tint) }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(k.name, style = MaterialTheme.typography.titleMedium)
                val d = describe(e); if (d.isNotBlank()) Text(d, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            if (e.end != null) Text(hm(e.end), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
