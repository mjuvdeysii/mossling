package app.mossling.ui.journal

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
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
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import app.mossling.data.LogType
import app.mossling.data.RunningTimer
import app.mossling.journal.Timers
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.clock
import app.mossling.ui.components.hm
import app.mossling.ui.theme.Numerals
import kotlinx.coroutines.delay

data class TimerActions(
    val pause: (String) -> Unit = {},
    val stop: (String) -> Unit = {},
    val switchSide: (String) -> Unit = {},
    val shift: (String, Long) -> Unit = { _, _ -> },
    val discard: (String) -> Unit = {},
)

/**
 * A feed or a sleep in progress, as one card: what and since when, the time running in large numerals, and everything
 * that can be done to it — pause, change breast, say it began a little earlier, finish and keep it, or drop it.
 */
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun TimerCard(t: RunningTimer, a: TimerActions, modifier: Modifier = Modifier, now: () -> Long = System::currentTimeMillis) {
    var tick by remember { mutableLongStateOf(now()) }
    LaunchedEffect(t) { while (true) { tick = now(); delay(1000) } }
    val k = logKind(t.type)
    val paused = t.pausedAt != null
    Surface(shape = RoundedCornerShape(32.dp), color = if (paused) k.tint.copy(alpha = 0.72f) else k.tint, contentColor = Color.White, modifier = modifier.fillMaxWidth()) {
        Column(Modifier.padding(20.dp)) {
            var picking by remember { mutableStateOf(false) }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Glyph(k.glyph, size = 22.dp, color = Color.White, filled = true)
                Text("  " + k.name + when (t.side) { "l" -> " · 左边"; "r" -> " · 右边"; else -> "" } + if (paused) " · 暂停中" else "",
                    style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
            }
            // the start, exact to the minute; tap to set it precisely
            Surface(onClick = { picking = true }, shape = RoundedCornerShape(12.dp), color = Color.White.copy(alpha = 0.16f), contentColor = Color.White, modifier = Modifier.padding(top = 8.dp)) {
                Text(whenLabel(t.start) + " 开始", fontFamily = Numerals, style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(horizontal = 10.dp, vertical = 6.dp))
            }
            if (picking) TimeDialog("开始时间", t.start, { n -> a.shift(t.type, n - t.start) }, { picking = false })
            Text(clock(Timers.elapsed(t, tick)), fontFamily = Numerals, style = MaterialTheme.typography.displayMedium, modifier = Modifier.padding(vertical = 6.dp))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = { a.stop(t.type) }, colors = ButtonDefaults.buttonColors(containerColor = Color.White, contentColor = k.tint), modifier = Modifier.heightIn(min = 48.dp)) { Text("结束并记下") }
                OutlinedButton(onClick = { a.pause(t.type) }, modifier = Modifier.heightIn(min = 48.dp)) { Text(if (paused) "继续" else "暂停", color = Color.White) }
                if (t.type == LogType.Nurse) OutlinedButton(onClick = { a.switchSide(t.type) }, modifier = Modifier.heightIn(min = 48.dp)) { Text(if (t.side == "r") "换到左边" else "换到右边", color = Color.White) }
            }
            Row(Modifier.padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("提前", style = MaterialTheme.typography.labelMedium)
                listOf(5, 15).forEach { m -> TextButton(onClick = { a.shift(t.type, -m * 60_000L) }) { Text("$m 分钟", color = Color.White) } }
                androidx.compose.foundation.layout.Spacer(Modifier.weight(1f))
                TextButton(onClick = { a.discard(t.type) }) { Text("不记了", color = Color.White.copy(alpha = 0.85f)) }
            }
        }
    }
}
