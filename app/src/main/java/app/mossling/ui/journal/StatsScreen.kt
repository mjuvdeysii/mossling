package app.mossling.ui.journal

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.mossling.data.LogEntry
import app.mossling.data.LogType
import app.mossling.ui.theme.Numerals
import app.mossling.ui.you.Bar
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** One number per day over the last week or month: how often fed, how much from the bottle, how long asleep, how many changes. */
@Composable
fun StatsScreen(logs: List<LogEntry>, today: LocalDate, onBack: () -> Unit) {
    var days by rememberSaveable { mutableIntStateOf(7) }
    val z = ZoneId.systemDefault()
    val range = (days - 1 downTo 0).map { today.minusDays(it.toLong()) }
    val byDay = logs.groupBy { Instant.ofEpochMilli(it.start).atZone(z).toLocalDate() }
    fun series(f: (List<LogEntry>) -> Double) = range.map { f(byDay[it].orEmpty()) }
    val feeds = series { l -> l.count { it.type == LogType.Nurse || it.type == LogType.Bottle }.toDouble() }
    val ml = series { l -> l.filter { it.type == LogType.Bottle }.sumOf { it.amount ?: 0 }.toDouble() }
    val sleep = series { l -> l.filter { it.type == LogType.Sleep && it.end != null }.sumOf { (it.end!! - it.start) / 3_600_000.0 } }
    val nurse = series { l -> l.filter { it.type == LogType.Nurse && it.end != null }.sumOf { (it.end!! - it.start) / 60_000.0 } }
    val diapers = series { l -> l.count { it.type == LogType.Diaper }.toDouble() }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 40.dp)) {
        item { Bar("统计", onBack) }
        item {
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                listOf(7 to "近 7 天", 30 to "近 30 天").forEachIndexed { i, (d, t) -> SegmentedButton(selected = days == d, onClick = { days = d }, shape = SegmentedButtonDefaults.itemShape(i, 2)) { Text(t) } }
            }
        }
        item { StatCard("喂养", "次 / 天", feeds, logKind(LogType.Nurse).tint, range) }
        item { StatCard("瓶喂奶量", "毫升 / 天", ml, logKind(LogType.Bottle).tint, range) }
        item { StatCard("亲喂时长", "分钟 / 天", nurse, logKind(LogType.Nurse).tint.copy(alpha = 0.7f), range) }
        item { StatCard("睡眠", "小时 / 天", sleep, logKind(LogType.Sleep).tint, range, decimals = 1) }
        item { StatCard("尿布", "片 / 天", diapers, logKind(LogType.Diaper).tint, range) }
    }
}

@Composable
private fun StatCard(title: String, unit: String, v: List<Double>, tint: Color, range: List<LocalDate>, decimals: Int = 0) {
    val recorded = v.filter { it > 0 }
    val avg = if (recorded.isEmpty()) 0.0 else recorded.average()
    fun fmt(x: Double) = if (decimals == 0) "${Math.round(x)}" else "%.${decimals}f".format(x)
    Surface(shape = RoundedCornerShape(24.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 12.dp)) {
        Column(Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.Bottom) {
                Column(Modifier.weight(1f)) {
                    Text(title, style = MaterialTheme.typography.titleMedium)
                    Text(unit, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text(if (recorded.isEmpty()) "—" else fmt(avg), fontFamily = Numerals, style = MaterialTheme.typography.headlineMedium)
                    Text("有记录的日子平均", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            val max = (v.maxOrNull() ?: 0.0).coerceAtLeast(1.0)
            val empty = MaterialTheme.colorScheme.outlineVariant
            Canvas(Modifier.fillMaxWidth().height(96.dp).padding(top = 12.dp).semantics { contentDescription = "$title：" + v.joinToString("、") { fmt(it) } }) {
                val n = v.size; val gap = if (n > 10) 3f else 10f; val w = (size.width - gap * (n - 1)) / n
                v.forEachIndexed { i, x ->
                    val h = if (x <= 0) 3f else (x / max * size.height).toFloat().coerceAtLeast(4f)
                    drawRoundRect(if (x <= 0) empty else tint, Offset(i * (w + gap), size.height - h), Size(w, h), CornerRadius(minOf(w / 2, 8f)))
                }
            }
            Row(Modifier.fillMaxWidth().padding(top = 4.dp)) {
                Text("${range.first().monthValue}/${range.first().dayOfMonth}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
                Text("今天", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
