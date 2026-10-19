package app.mossling.ui.journal

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import app.mossling.data.LogEntry
import app.mossling.data.LogType
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette
import kotlin.math.roundToInt

/** The things that can be logged, in the order they are offered. */
data class LogKind(val type: String, val name: String, val glyph: G, val tint: Color)

val LogKinds = listOf(
    LogKind(LogType.Nurse, "亲喂", G.Nurse, Color(0xFFB8382B)),
    LogKind(LogType.Bottle, "瓶喂", G.Bottle, Color(0xFFB07B12)),
    LogKind(LogType.Sleep, "睡觉", G.Sleep, Palette.Rod),
    LogKind(LogType.Diaper, "尿布", G.Diaper, Palette.MossDeep),
    LogKind(LogType.Solid, "辅食", G.Solid, Color(0xFF8C6A45)),
    LogKind(LogType.Bath, "洗澡", G.Bath, Color(0xFF3F7F86)),
    LogKind(LogType.Note, "备注", G.Note, Color(0xFF5A5C55)),
)
fun logKind(type: String) = LogKinds.firstOrNull { it.type == type } ?: LogKinds.last()

/** What a tap on a log button asks for, if anything. */
enum class Ask { None, Side, Amount, Diaper }

fun askFor(type: String) = when (type) { LogType.Nurse -> Ask.Side; LogType.Bottle -> Ask.Amount; LogType.Diaper -> Ask.Diaper; else -> Ask.None }

/** The small sheet that follows a log button. Each choice is one tap and closes the sheet. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AskSheet(ask: Ask, onDismiss: () -> Unit, onSide: (String) -> Unit, onAmount: (Int) -> Unit, onDiaper: (String) -> Unit) {
    if (ask == Ask.None) return
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = MaterialTheme.colorScheme.surfaceContainerLowest) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(bottom = 24.dp).navigationBarsPadding()) {
            when (ask) {
                Ask.Side -> {
                    Text("从哪边开始", style = MaterialTheme.typography.headlineSmall)
                    Spacer(Modifier.height(20.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        listOf("l" to "左边", "r" to "右边").forEach { (k, t) ->
                            Surface(onClick = { onSide(k) }, shape = CircleShape, color = Color(0xFFB8382B).copy(alpha = 0.12f), modifier = Modifier.weight(1f).aspectRatio(1f)) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                                    Text(if (k == "l") "L" else "R", fontFamily = Numerals, style = MaterialTheme.typography.displaySmall, color = Color(0xFFB8382B))
                                    Text(t, style = MaterialTheme.typography.titleMedium)
                                }
                            }
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                    Text("点了才开始计时；通知栏里可以暂停和结束。", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Ask.Amount -> {
                    var ml by remember { mutableFloatStateOf(120f) }
                    Text("喝了多少", style = MaterialTheme.typography.headlineSmall)
                    Row(verticalAlignment = Alignment.Bottom, modifier = Modifier.padding(top = 12.dp)) {
                        Text("${ml.roundToInt()}", style = MaterialTheme.typography.displayMedium)
                        Text(" 毫升", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(bottom = 10.dp))
                    }
                    Slider(ml, { ml = (it / 10).roundToInt() * 10f }, valueRange = 10f..300f)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf(60, 90, 120, 150, 180).forEach { v -> FilterChip(selected = ml.roundToInt() == v, onClick = { ml = v.toFloat() }, label = { Text("$v") }) }
                    }
                    Spacer(Modifier.height(16.dp))
                    Button(onClick = { onAmount(ml.roundToInt()) }, modifier = Modifier.fillMaxWidth().height(56.dp), shape = RoundedCornerShape(18.dp)) { Text("记下来") }
                }
                Ask.Diaper -> {
                    Text("换尿布", style = MaterialTheme.typography.headlineSmall)
                    Spacer(Modifier.height(16.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        listOf("wet" to "湿", "dirty" to "便", "both" to "都有").forEach { (k, t) ->
                            Surface(onClick = { onDiaper(k) }, shape = RoundedCornerShape(24.dp), color = MaterialTheme.colorScheme.primaryContainer, modifier = Modifier.weight(1f).height(96.dp)) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                                    Glyph(G.Diaper, size = 28.dp, color = MaterialTheme.colorScheme.onPrimaryContainer)
                                    Text(t, style = MaterialTheme.typography.titleMedium)
                                }
                            }
                        }
                    }
                }
                Ask.None -> Unit
            }
            TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.End)) { Text("取消") }
        }
    }
}

fun describe(e: LogEntry): String = when (e.type) {
    LogType.Nurse -> listOfNotNull(when (e.side) { "l" -> "左边"; "r" -> "右边"; else -> null }, e.end?.let { app.mossling.ui.components.minutes(it - e.start) }).joinToString(" · ")
    LogType.Sleep -> e.end?.let { app.mossling.ui.components.minutes(it - e.start) } ?: "进行中"
    LogType.Bottle -> "${e.amount ?: 0} 毫升"
    LogType.Diaper -> when (e.detail) { "wet" -> "湿"; "dirty" -> "便"; "both" -> "湿和便"; else -> "" }
    else -> e.detail ?: ""
}

@Composable
fun LogButton(k: LogKind, running: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    Surface(onClick = onClick, shape = RoundedCornerShape(24.dp), color = if (running) k.tint else k.tint.copy(alpha = 0.10f), modifier = modifier.height(88.dp)) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
            Glyph(k.glyph, size = 26.dp, color = if (running) Color.White else k.tint, filled = running)
            Spacer(Modifier.size(6.dp))
            Text(if (running) "进行中" else k.name, style = MaterialTheme.typography.labelLarge, color = if (running) Color.White else MaterialTheme.colorScheme.onSurface)
        }
    }
}

/** Change or remove one entry: move its time in small steps, change the amount, or delete it (with undo). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EntrySheet(e: LogEntry, onChange: (LogEntry) -> Unit, onDelete: (LogEntry) -> Unit, onDismiss: () -> Unit) {
    var cur by remember(e.id) { mutableStateOf(e) }
    ModalBottomSheet(onDismissRequest = { onChange(cur); onDismiss() }, containerColor = MaterialTheme.colorScheme.surfaceContainerLowest) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(bottom = 24.dp).navigationBarsPadding()) {
            Text(logKind(cur.type).name, style = MaterialTheme.typography.headlineSmall)
            Text(describe(cur), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(16.dp))
            Text("开始", style = MaterialTheme.typography.labelLarge)
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(app.mossling.ui.components.hm(cur.start), fontFamily = Numerals, style = MaterialTheme.typography.displaySmall, modifier = Modifier.padding(end = 8.dp))
                listOf(-15, -5, 5, 15).forEach { d ->
                    FilterChip(selected = false, onClick = { val ms = d * 60_000L; cur = cur.copy(start = cur.start + ms, end = cur.end?.let { it + ms }) }, label = { Text(if (d > 0) "+$d" else "$d") })
                }
            }
            if (cur.end != null) {
                Text("结束", style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(top = 12.dp))
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(app.mossling.ui.components.hm(cur.end!!), fontFamily = Numerals, style = MaterialTheme.typography.displaySmall, modifier = Modifier.padding(end = 8.dp))
                    listOf(-5, 5).forEach { d -> FilterChip(selected = false, onClick = { val n = cur.end!! + d * 60_000L; if (n > cur.start) cur = cur.copy(end = n) }, label = { Text(if (d > 0) "+$d" else "$d") }) }
                }
            }
            if (cur.type == LogType.Bottle) {
                var ml by remember(e.id) { mutableFloatStateOf((cur.amount ?: 120).toFloat()) }
                Text("${ml.roundToInt()} 毫升", style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(top = 12.dp))
                Slider(ml, { ml = (it / 10).roundToInt() * 10f; cur = cur.copy(amount = ml.roundToInt()) }, valueRange = 10f..300f)
            }
            Row(Modifier.fillMaxWidth().padding(top = 20.dp)) {
                TextButton(onClick = { onDelete(cur); onDismiss() }) { Text("删除这条", color = MaterialTheme.colorScheme.error) }
                Spacer(Modifier.weight(1f))
                Button(onClick = { onChange(cur); onDismiss() }, shape = RoundedCornerShape(18.dp), modifier = Modifier.height(48.dp)) { Text("好") }
            }
        }
    }
}
