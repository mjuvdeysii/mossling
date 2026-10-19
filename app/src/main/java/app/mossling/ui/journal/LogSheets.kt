package app.mossling.ui.journal

import androidx.compose.foundation.layout.heightIn
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.TimePicker
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.AlertDialog
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.FilledTonalButton
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.FlowRow
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
    LogKind(LogType.Temp, "体温", G.Thermo, Color(0xFFB8452E)),
    LogKind(LogType.Medicine, "用药", G.Pill, Color(0xFF6B5B95)),
    LogKind(GROWTH, "生长", G.Ruler, Color(0xFF8A6508)),
    LogKind(LogType.Note, "备注", G.Note, Color(0xFF5A5C55)),
)
/** Not a journal entry: opens the measurement sheet (weight, length, head). */
const val GROWTH = "growth"
fun logKind(type: String) = LogKinds.firstOrNull { it.type == type } ?: LogKinds.last()

/** What a tap on a log button asks for, if anything. */
enum class Ask { None, Side, Amount, Diaper, Temp, Text, Measure }

fun askFor(type: String) = when (type) {
    LogType.Nurse -> Ask.Side; LogType.Bottle -> Ask.Amount; LogType.Diaper -> Ask.Diaper; LogType.Temp -> Ask.Temp
    LogType.Solid, LogType.Medicine, LogType.Note -> Ask.Text; GROWTH -> Ask.Measure; else -> Ask.None
}

/** The small sheet that follows a log button. Each choice is one tap and closes the sheet. */
@OptIn(ExperimentalMaterial3Api::class, androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun AskSheet(ask: Ask, onDismiss: () -> Unit, onSide: (String) -> Unit, onAmount: (Int) -> Unit, onDiaper: (String) -> Unit,
             type: String = "", onTemp: (Int) -> Unit = {}, onText: (String) -> Unit = {}) {
    if (ask == Ask.None || ask == Ask.Measure) return
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
                Ask.Temp -> {
                    var c by remember { mutableIntStateOf(368) }
                    Text("体温", style = MaterialTheme.typography.headlineSmall)
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 12.dp)) {
                        FilledTonalButton(onClick = { c = (c - 1).coerceAtLeast(340) }, modifier = Modifier.size(56.dp), contentPadding = PaddingValues(0.dp)) { Text("−", style = MaterialTheme.typography.headlineSmall) }
                        Text("%.1f".format(c / 10.0), fontFamily = Numerals, style = MaterialTheme.typography.displayMedium, color = if (c >= 380) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface,
                            modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                        FilledTonalButton(onClick = { c = (c + 1).coerceAtMost(425) }, modifier = Modifier.size(56.dp), contentPadding = PaddingValues(0.dp)) { Text("+", style = MaterialTheme.typography.headlineSmall) }
                    }
                    Text("°C", style = MaterialTheme.typography.titleMedium, modifier = Modifier.align(Alignment.CenterHorizontally))
                    Spacer(Modifier.height(16.dp))
                    Button(onClick = { onTemp(c) }, modifier = Modifier.fillMaxWidth().height(56.dp), shape = RoundedCornerShape(18.dp)) { Text("记下来") }
                }
                Ask.Text -> {
                    var t by remember { mutableStateOf("") }
                    val (title, hint, chips) = when (type) {
                        LogType.Solid -> Triple("吃了什么", "食物和大概的量", listOf("米粉", "蔬菜泥", "水果泥", "肉泥", "蛋黄", "粥"))
                        LogType.Medicine -> Triple("用了什么药", "药名与剂量，按医嘱或说明书", listOf("维生素 D", "维生素 AD"))
                        else -> Triple("备注", "发生了什么", emptyList())
                    }
                    Text(title, style = MaterialTheme.typography.headlineSmall)
                    OutlinedTextField(t, { t = it.take(120) }, Modifier.fillMaxWidth().padding(top = 12.dp), placeholder = { Text(hint) }, shape = RoundedCornerShape(16.dp), minLines = if (type == LogType.Note) 3 else 1)
                    if (chips.isNotEmpty()) FlowRow(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        chips.forEach { ch -> FilterChip(selected = t.contains(ch), onClick = { t = if (t.isBlank()) ch else "$t、$ch" }, label = { Text(ch) }) }
                    }
                    Spacer(Modifier.height(16.dp))
                    Button(onClick = { onText(t.trim()) }, enabled = t.isNotBlank() || type == LogType.Solid, modifier = Modifier.fillMaxWidth().height(56.dp), shape = RoundedCornerShape(18.dp)) { Text("记下来") }
                }
                Ask.None, Ask.Measure -> Unit
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
    LogType.Temp -> e.amount?.let { "%.1f °C".format(it / 10.0) } ?: ""
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

/**
 * One entry, to change or to add after the fact: any day and time (tap the date or the time), the amount, side or
 * kind, the text; delete with undo. An entry with id 0 is new ("补记") and is only written when confirmed.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EntrySheet(e: LogEntry, onChange: (LogEntry) -> Unit, onDelete: (LogEntry) -> Unit, onDismiss: () -> Unit) {
    var cur by remember(e.id, e.start) { mutableStateOf(e) }
    val fresh = e.id == 0L
    var pickDate by remember { mutableStateOf<Boolean?>(null) }   // true: start, false: end
    var pickTime by remember { mutableStateOf<Boolean?>(null) }
    ModalBottomSheet(onDismissRequest = { if (!fresh) onChange(cur); onDismiss() }, containerColor = MaterialTheme.colorScheme.surfaceContainerLowest) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(bottom = 24.dp).navigationBarsPadding()) {
            Text((if (fresh) "补记 · " else "") + logKind(cur.type).name, style = MaterialTheme.typography.headlineSmall)
            if (!fresh) Text(describe(cur), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(12.dp))
            WhenRow(if (cur.end != null) "开始" else "时间", cur.start, { pickDate = true }, { pickTime = true }) { d -> val ms = d * 60_000L; cur = cur.copy(start = cur.start + ms, end = cur.end?.let { it + ms }) }
            if (cur.end != null) WhenRow("结束", cur.end!!, { pickDate = false }, { pickTime = false }) { d -> val n = cur.end!! + d * 60_000L; if (n > cur.start) cur = cur.copy(end = n) }
            when (cur.type) {
                LogType.Bottle -> {
                    var ml by remember(e.id) { mutableFloatStateOf((cur.amount ?: 120).toFloat()) }
                    Text("${ml.roundToInt()} 毫升", style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(top = 12.dp))
                    Slider(ml, { ml = (it / 10).roundToInt() * 10f; cur = cur.copy(amount = ml.roundToInt()) }, valueRange = 10f..300f)
                }
                LogType.Nurse -> Choice(listOf("l" to "左边", "r" to "右边"), cur.side) { cur = cur.copy(side = it) }
                LogType.Diaper -> Choice(listOf("wet" to "湿", "dirty" to "便", "both" to "都有"), cur.detail) { cur = cur.copy(detail = it) }
                LogType.Temp -> Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 12.dp)) {
                    val c = cur.amount ?: 368
                    FilledTonalButton(onClick = { cur = cur.copy(amount = (c - 1).coerceAtLeast(340)) }, modifier = Modifier.size(48.dp), contentPadding = PaddingValues(0.dp)) { Text("−") }
                    Text("%.1f °C".format(c / 10.0), fontFamily = Numerals, style = MaterialTheme.typography.headlineMedium, modifier = Modifier.padding(horizontal = 16.dp))
                    FilledTonalButton(onClick = { cur = cur.copy(amount = (c + 1).coerceAtMost(425)) }, modifier = Modifier.size(48.dp), contentPadding = PaddingValues(0.dp)) { Text("+") }
                }
                LogType.Solid, LogType.Medicine, LogType.Note ->
                    OutlinedTextField(cur.detail ?: "", { cur = cur.copy(detail = it.take(120)) }, Modifier.fillMaxWidth().padding(top = 12.dp), shape = RoundedCornerShape(16.dp),
                        placeholder = { Text(when (cur.type) { LogType.Solid -> "食物和大概的量"; LogType.Medicine -> "药名与剂量"; else -> "发生了什么" }) }, minLines = if (cur.type == LogType.Note) 3 else 1)
                else -> Unit
            }
            Row(Modifier.fillMaxWidth().padding(top = 20.dp)) {
                if (!fresh) TextButton(onClick = { onDelete(cur); onDismiss() }) { Text("删除这条", color = MaterialTheme.colorScheme.error) }
                Spacer(Modifier.weight(1f))
                if (fresh) TextButton(onClick = onDismiss) { Text("取消") }
                Button(onClick = { onChange(cur); onDismiss() }, shape = RoundedCornerShape(18.dp), modifier = Modifier.heightIn(min = 48.dp)) { Text(if (fresh) "记下来" else "好") }
            }
        }
    }
    val z = java.time.ZoneId.systemDefault()
    pickDate?.let { forStart ->
        val base = if (forStart) cur.start else cur.end!!
        val st = rememberDatePickerState(initialSelectedDateMillis = java.time.Instant.ofEpochMilli(base).atZone(z).toLocalDate().atStartOfDay(java.time.ZoneOffset.UTC).toInstant().toEpochMilli(),
            selectableDates = object : SelectableDates { override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis <= System.currentTimeMillis() })
        DatePickerDialog(onDismissRequest = { pickDate = null }, confirmButton = { TextButton(onClick = {
            st.selectedDateMillis?.let { d ->
                val day = java.time.Instant.ofEpochMilli(d).atZone(java.time.ZoneOffset.UTC).toLocalDate()
                val t = java.time.Instant.ofEpochMilli(base).atZone(z)
                val n = day.atTime(t.toLocalTime()).atZone(z).toInstant().toEpochMilli(); val delta = n - base
                cur = if (forStart) cur.copy(start = n, end = cur.end?.let { it + delta }) else cur.copy(end = n.coerceAtLeast(cur.start + 60_000))
            }; pickDate = null }) { Text("好") } }, dismissButton = { TextButton(onClick = { pickDate = null }) { Text("取消") } }) { DatePicker(st) }
    }
    pickTime?.let { forStart ->
        val base = if (forStart) cur.start else cur.end!!
        val t0 = java.time.Instant.ofEpochMilli(base).atZone(z)
        val st = rememberTimePickerState(t0.hour, t0.minute, is24Hour = true)
        AlertDialog(onDismissRequest = { pickTime = null }, confirmButton = { TextButton(onClick = {
            val n = t0.withHour(st.hour).withMinute(st.minute).toInstant().toEpochMilli(); val delta = n - base
            cur = if (forStart) cur.copy(start = n, end = cur.end?.let { it + delta }) else cur.copy(end = if (n > cur.start) n else n + 86_400_000)
            pickTime = null }) { Text("好") } }, dismissButton = { TextButton(onClick = { pickTime = null }) { Text("取消") } }, text = { TimePicker(st) })
    }
}

@Composable
private fun WhenRow(label: String, at: Long, onDate: () -> Unit, onTime: () -> Unit, step: (Int) -> Unit) {
    Text(label, style = MaterialTheme.typography.labelLarge, modifier = Modifier.padding(top = 8.dp))
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        val z = java.time.ZoneId.systemDefault(); val d = java.time.Instant.ofEpochMilli(at).atZone(z).toLocalDate(); val today = java.time.LocalDate.now()
        TextButton(onClick = onDate, contentPadding = PaddingValues(horizontal = 4.dp)) {
            Text(when (d) { today -> "今天"; today.minusDays(1) -> "昨天"; else -> "${d.monthValue}月${d.dayOfMonth}日" }, style = MaterialTheme.typography.titleMedium)
        }
        TextButton(onClick = onTime, contentPadding = PaddingValues(horizontal = 4.dp)) {
            Text(app.mossling.ui.components.hm(at), fontFamily = Numerals, style = MaterialTheme.typography.headlineMedium)
        }
        Spacer(Modifier.weight(1f))
        listOf(-5, 5).forEach { s -> FilterChip(selected = false, onClick = { step(s) }, label = { Text(if (s > 0) "+$s" else "$s") }) }
    }
}

@Composable
private fun Choice(options: List<Pair<String, String>>, selected: String?, onPick: (String) -> Unit) {
    SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(top = 12.dp)) {
        options.forEachIndexed { i, (k, t) -> SegmentedButton(selected = selected == k, onClick = { onPick(k) }, shape = SegmentedButtonDefaults.itemShape(i, options.size)) { Text(t) } }
    }
}

/** Which kind of entry to add after the fact. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun KindSheet(onPick: (String) -> Unit, onDismiss: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = MaterialTheme.colorScheme.surfaceContainerLowest) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 24.dp).navigationBarsPadding(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("补记哪一项", style = MaterialTheme.typography.headlineSmall, modifier = Modifier.padding(start = 8.dp, bottom = 8.dp))
            LogKinds.filter { it.type != GROWTH }.chunked(3).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    row.forEach { k -> LogButton(k, false, onClick = { onPick(k.type) }, modifier = Modifier.weight(1f)) }
                    repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
    }
}
