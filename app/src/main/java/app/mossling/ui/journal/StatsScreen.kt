package app.mossling.ui.journal

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
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
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import app.mossling.data.LogEntry
import app.mossling.data.LogType
import app.mossling.ui.components.Plate
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.Mood
import app.mossling.ui.theme.LocalCompanion
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
    val range = remember(days, today) { (days - 1 downTo 0).map { today.minusDays(it.toLong()) } }
    val byDay = remember(logs) { logs.groupBy { Instant.ofEpochMilli(it.start).atZone(z).toLocalDate() } }
    fun series(f: (List<LogEntry>) -> Double) = range.map { f(byDay[it].orEmpty()) }
    val feeds = remember(byDay, range) { series { l -> l.count { it.type == LogType.Nurse || it.type == LogType.Bottle }.toDouble() } }
    val ml = remember(byDay, range) { series { l -> l.filter { it.type == LogType.Bottle }.sumOf { it.amount ?: 0 }.toDouble() } }
    val sleep = remember(byDay, range) { series { l -> l.filter { it.type == LogType.Sleep && it.end != null }.sumOf { (it.end!! - it.start) / 3_600_000.0 } } }
    val nurse = remember(byDay, range) { series { l -> l.filter { it.type == LogType.Nurse && it.end != null }.sumOf { (it.end!! - it.start) / 60_000.0 } } }
    val diapers = remember(byDay, range) { series { l -> l.count { it.type == LogType.Diaper }.toDouble() } }
    val haptic = LocalHapticFeedback.current
    val companion = LocalCompanion.current

    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 48.dp)) {
        item { Bar("统计", onBack) }
        item {
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                listOf(7 to "近 7 天", 30 to "近 30 天").forEachIndexed { i, (d, t) ->
                    SegmentedButton(
                        selected = days == d,
                        onClick = {
                            if (days != d) {
                                haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                                days = d
                            }
                        },
                        shape = SegmentedButtonDefaults.itemShape(i, 2),
                    ) { Text(t) }
                }
            }
        }
        if (logs.isEmpty()) {
            item {
                Plate(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 14.dp),
                    color = MaterialTheme.colorScheme.surfaceContainerLow,
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("还没有可画成曲线的记录", style = MaterialTheme.typography.titleMedium)
                            Text(
                                "在「手帐」记下喂奶、睡觉或换尿布之后，这里会自动画出最近节奏；也可以点下面任意柱子查看每天的数字。",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(top = 4.dp),
                            )
                        }
                        Spacer(Modifier.width(8.dp))
                        Creature(companion, Modifier.size(64.dp), mood = Mood.Calm)
                    }
                }
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
    var selected by remember(v.size, range.firstOrNull()) { mutableIntStateOf(-1) }
    val haptic = LocalHapticFeedback.current

    fun pickAt(x: Float, width: Float) {
        if (v.isEmpty() || width <= 0f) return
        val idx = ((x / width) * v.size).toInt().coerceIn(0, v.lastIndex)
        if (idx != selected) {
            haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
            selected = idx
        }
    }

    val pickedDay = range.getOrNull(selected)
    val pickedVal = v.getOrNull(selected)

    Surface(
        shape = RoundedCornerShape(24.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 12.dp),
    ) {
        Column(Modifier.padding(16.dp)) {
            Row(verticalAlignment = Alignment.Bottom) {
                Column(Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(title, style = MaterialTheme.typography.titleMedium)
                        if (pickedDay != null && pickedVal != null) {
                            Surface(
                                shape = RoundedCornerShape(10.dp),
                                color = tint.copy(alpha = 0.16f),
                            ) {
                                Text(
                                    "${pickedDay.monthValue}/${pickedDay.dayOfMonth} · ${if (pickedVal <= 0) "无记录" else fmt(pickedVal)}",
                                    fontFamily = Numerals,
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurface,
                                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                                )
                            }
                        }
                    }
                    Text(unit, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text(if (recorded.isEmpty()) "—" else fmt(avg), fontFamily = Numerals, style = MaterialTheme.typography.headlineMedium)
                    Text(
                        if (recorded.isEmpty()) "有记录的日子平均" else "有记录 ${recorded.size}/${range.size} 天均值",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            val max = (v.maxOrNull() ?: 0.0).coerceAtLeast(1.0)
            val empty = MaterialTheme.colorScheme.outlineVariant
            val focusStroke = MaterialTheme.colorScheme.onSurface
            Canvas(
                Modifier
                    .fillMaxWidth()
                    .height(96.dp)
                    .padding(top = 12.dp)
                    .semantics { contentDescription = "$title：" + v.joinToString("、") { fmt(it) } }
                    .pointerInput(v) {
                        detectTapGestures { offset -> pickAt(offset.x, size.width.toFloat()) }
                    }
                    .pointerInput(v) {
                        detectHorizontalDragGestures { change, _ ->
                            pickAt(change.position.x, size.width.toFloat())
                        }
                    },
            ) {
                val n = v.size
                val gap = if (n > 10) 3f else 10f
                val w = (size.width - gap * (n - 1)) / n
                v.forEachIndexed { i, x ->
                    val h = if (x <= 0) 3f else (x / max * size.height).toFloat().coerceAtLeast(4f)
                    val isSelected = i == selected
                    val barColor = when {
                        x <= 0 -> empty
                        selected >= 0 && !isSelected -> tint.copy(alpha = 0.45f)
                        else -> tint
                    }
                    val topLeft = Offset(i * (w + gap), size.height - h)
                    val barSize = Size(w, h)
                    val corner = CornerRadius(minOf(w / 2, 8f))
                    drawRoundRect(barColor, topLeft, barSize, corner)
                    if (isSelected) {
                        drawRoundRect(focusStroke, topLeft, barSize, corner, style = Stroke(2.dp.toPx()))
                    }
                }
            }
            Row(Modifier.fillMaxWidth().padding(top = 4.dp)) {
                Text("${range.first().monthValue}/${range.first().dayOfMonth}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f))
                if (selected < 0 && recorded.isNotEmpty()) {
                    Text("点按或滑动查看单日", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.weight(1f))
                }
                Text("今天", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
