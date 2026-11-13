package app.mossling.ui.journal

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
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
import app.mossling.ui.components.ShapeBadge
import app.mossling.ui.components.Shapes
import app.mossling.ui.components.minutes
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette

data class LogKind(val label: String, val glyph: G, val tint: Color, val sticker: String = "ic_pencil.webp")

fun logKind(type: String): LogKind = when (type) {
    LogType.Nurse -> LogKind("亲喂", G.Heart, Color(0xFFC2724F), "ic_circle_bottomhalf_filled.webp")
    LogType.Bottle -> LogKind("瓶喂", G.Bottle, Palette.Bead, "ic_waterbottle_fill.webp")
    LogType.Sleep -> LogKind("睡觉", G.Sleep, Palette.Rod, "ic_moon_zzz_fill.webp")
    LogType.Diaper -> LogKind("尿布", G.Diaper, Palette.Moss, "ic_drop_halffull.webp")
    LogType.Solid -> LogKind("辅食", G.Solid, Palette.Wood, "ic_fork_knife.webp")
    LogType.Bath -> LogKind("洗澡", G.Bath, Palette.RodLight, "ic_bathtub_fill.webp")
    LogType.Temp -> LogKind("体温", G.Thermo, Palette.RedRod, "ic_thermometer_medium.webp")
    LogType.Med -> LogKind("用药", G.Pill, Palette.RodDeep, "ic_pills_fill.webp")
    LogType.Play -> LogKind("一起玩", G.Play, Palette.Moss, "ic_puzzlepiece_fill.webp")
    else -> LogKind("记一笔", G.Note, Palette.MossDeep, "ic_pencil.webp")
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun QuickLogSheet(
    type: String,
    onPickType: (String) -> Unit,
    onStartTimer: (String, String?) -> Unit,
    onSave: (LogEntry) -> Unit,
    onDismiss: () -> Unit,
) {
    val kb = androidx.compose.ui.platform.LocalSoftwareKeyboardController.current
    val fm = androidx.compose.ui.platform.LocalFocusManager.current
    val close = { fm.clearFocus(); kb?.hide(); onDismiss() }
    ModalBottomSheet(onDismissRequest = close, containerColor = MaterialTheme.colorScheme.surfaceContainerLowest) {
        Column(
            Modifier
                .fillMaxWidth()
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .padding(bottom = 24.dp)
                .navigationBarsPadding(),
        ) {
            when (type) {
                "more" -> {
                    Text("记一笔", style = MaterialTheme.typography.headlineSmall)
                    Spacer(Modifier.height(14.dp))
                    val more = listOf(LogType.Solid, LogType.Bath, LogType.Temp, LogType.Med, LogType.Note)
                    FlowRow(
                        Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        more.forEach { t ->
                            val k = logKind(t)
                            Surface(onClick = { onPickType(t) }, shape = RoundedCornerShape(20.dp), color = MaterialTheme.colorScheme.surfaceContainerLow) {
                                Row(Modifier.padding(horizontal = 16.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                                    ShapeBadge(k.glyph, k.tint.copy(alpha = 0.16f), k.tint, shape = Shapes.of(t), size = 34.dp)
                                    Spacer(Modifier.width(10.dp))
                                    Text(k.label, style = MaterialTheme.typography.titleMedium)
                                }
                            }
                        }
                    }
                }
                LogType.Nurse -> {
                    var at by remember { mutableLongStateOf(System.currentTimeMillis()) }
                    var min by remember { mutableIntStateOf(15) }
                    var side by remember { mutableStateOf("l") }
                    Text("亲喂", style = MaterialTheme.typography.headlineSmall)
                    Text("现在开始，就点下面两个大按钮计时；已经喂完了，选时长直接记下来。", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 4.dp))
                    Spacer(Modifier.height(14.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Button(onClick = { onStartTimer(LogType.Nurse, "l"); close() }, modifier = Modifier.weight(1f).height(54.dp), shape = RoundedCornerShape(18.dp)) { Text("左侧 · 开始计时") }
                        Button(onClick = { onStartTimer(LogType.Nurse, "r"); close() }, modifier = Modifier.weight(1f).height(54.dp), shape = RoundedCornerShape(18.dp)) { Text("右侧 · 开始计时") }
                    }
                    Spacer(Modifier.height(18.dp))
                    Text("或者记一次已喂完的", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    WhenRow("结束于", at) { at = it }
                    SideChips(side) { side = it }
                    DurationRow(min, listOf(5, 10, 15, 20, 30)) { min = it }
                    SaveButton { onSave(LogEntry(type = LogType.Nurse, start = at - min * 60_000L, end = at, side = side)); close() }
                }
                LogType.Sleep -> {
                    var at by remember { mutableLongStateOf(System.currentTimeMillis()) }
                    var min by remember { mutableIntStateOf(60) }
                    Text("睡觉", style = MaterialTheme.typography.headlineSmall)
                    Spacer(Modifier.height(12.dp))
                    Button(onClick = { onStartTimer(LogType.Sleep, null); close() }, modifier = Modifier.fillMaxWidth().height(54.dp), shape = RoundedCornerShape(18.dp)) {
                        Text("刚睡着 · 开始计时", style = MaterialTheme.typography.titleMedium)
                    }
                    Spacer(Modifier.height(18.dp))
                    Text("或者记一觉已睡醒的", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    WhenRow("醒来于", at) { at = it }
                    DurationRow(min, listOf(30, 45, 60, 90, 120), step = 15) { min = it }
                    SaveButton { onSave(LogEntry(type = LogType.Sleep, start = at - min * 60_000L, end = at)); close() }
                }
                LogType.Bottle -> {
                    var at by remember { mutableLongStateOf(System.currentTimeMillis()) }
                    var ml by remember { mutableIntStateOf(120) }
                    var kind by remember { mutableStateOf("母乳") }
                    Text("瓶喂 · 喝了多少", style = MaterialTheme.typography.headlineSmall)
                    WhenRow("时间", at) { at = it }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 6.dp)) {
                        listOf("母乳", "配方奶", "水").forEach { k -> FilterChip(selected = kind == k, onClick = { kind = k }, label = { Text(k) }) }
                    }
                    Row(Modifier.fillMaxWidth().padding(vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
                        OutlinedButton(onClick = { ml = (ml - 10).coerceAtLeast(10) }, shape = RoundedCornerShape(14.dp)) { Text("−10") }
                        Text("$ml 毫升", fontFamily = Numerals, style = MaterialTheme.typography.headlineLarge, modifier = Modifier.padding(horizontal = 20.dp))
                        OutlinedButton(onClick = { ml = (ml + 10).coerceAtMost(360) }, shape = RoundedCornerShape(14.dp)) { Text("+10") }
                    }
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf(60, 90, 120, 150, 180, 210).forEach { p ->
                            FilterChip(selected = ml == p, onClick = { ml = p }, label = { Text("$p") })
                        }
                    }
                    SaveButton { onSave(LogEntry(type = LogType.Bottle, start = at, amount = ml, detail = kind)); close() }
                }
                LogType.Diaper -> {
                    var at by remember { mutableLongStateOf(System.currentTimeMillis()) }
                    Text("换尿布", style = MaterialTheme.typography.headlineSmall)
                    WhenRow("时间", at) { at = it }
                    Spacer(Modifier.height(8.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        listOf("wet" to "湿了", "dirty" to "便便", "both" to "都有").forEach { (code, label) ->
                            FilledTonalButton(
                                onClick = { onSave(LogEntry(type = LogType.Diaper, start = at, detail = code)); close() },
                                modifier = Modifier.weight(1f).height(56.dp),
                                shape = RoundedCornerShape(18.dp),
                            ) { Text(label, style = MaterialTheme.typography.titleMedium) }
                        }
                    }
                }
                LogType.Temp -> {
                    var at by remember { mutableLongStateOf(System.currentTimeMillis()) }
                    var deg by remember { mutableIntStateOf(370) }
                    Text("体温", style = MaterialTheme.typography.headlineSmall)
                    WhenRow("时间", at) { at = it }
                    Row(Modifier.fillMaxWidth().padding(vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
                        OutlinedButton(onClick = { deg = (deg - 1).coerceAtLeast(350) }) { Text("−0.1") }
                        Text("${"%.1f".format(deg / 10.0)} ℃", fontFamily = Numerals, style = MaterialTheme.typography.headlineLarge, modifier = Modifier.padding(horizontal = 20.dp))
                        OutlinedButton(onClick = { deg = (deg + 1).coerceAtMost(420) }) { Text("+0.1") }
                    }
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf(365, 370, 375, 380, 385, 390).forEach { p ->
                            FilterChip(selected = deg == p, onClick = { deg = p }, label = { Text("%.1f".format(p / 10.0)) })
                        }
                    }
                    if (deg >= 380) {
                        FeverMedicalBanner(Modifier.padding(top = 10.dp))
                    }
                    SaveButton { onSave(LogEntry(type = LogType.Temp, start = at, amount = deg)); close() }
                }
                LogType.Bath -> {
                    var at by remember { mutableLongStateOf(System.currentTimeMillis()) }
                    var note by remember { mutableStateOf("") }
                    Text("洗澡", style = MaterialTheme.typography.headlineSmall)
                    WhenRow("时间", at) { at = it }
                    OutlinedTextField(note, { note = it.take(500) }, label = { Text("备注（选填）") }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp), shape = RoundedCornerShape(16.dp))
                    SaveButton { onSave(LogEntry(type = LogType.Bath, start = at, detail = note.trim().ifEmpty { null })); close() }
                }
                else -> {
                    var at by remember { mutableLongStateOf(System.currentTimeMillis()) }
                    var text by remember { mutableStateOf("") }
                    val k = logKind(type)
                    val presets = when (type) {
                        LogType.Solid -> listOf("米粉", "菜泥", "果泥", "肉泥", "蛋黄", "面条", "手指食物")
                        LogType.Med -> listOf("维生素 D 400 IU", "退烧药（对乙酰氨基酚）", "退烧药（布洛芬）", "口服补液盐", "益生菌")
                        else -> emptyList()
                    }
                    Text(k.label, style = MaterialTheme.typography.headlineSmall)
                    WhenRow("时间", at) { at = it }
                    if (presets.isNotEmpty()) {
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 6.dp)) {
                            presets.forEach { p ->
                                FilterChip(
                                    selected = p in text,
                                    onClick = { text = if (text.isBlank()) p else "$text、$p" },
                                    label = { Text(p) },
                                )
                            }
                        }
                    }
                    OutlinedTextField(
                        value = text,
                        onValueChange = { text = it.take(500) },
                        label = {
                            Text(
                                when (type) {
                                    LogType.Solid -> "吃了什么"
                                    LogType.Med -> "药名与剂量"
                                    else -> "记下什么"
                                }
                            )
                        },
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                        shape = RoundedCornerShape(16.dp),
                    )
                    SaveButton { onSave(LogEntry(type = type, start = at, detail = text.trim().ifEmpty { k.label })); close() }
                }
            }
        }
    }
}

@Composable
fun FeverMedicalBanner(modifier: Modifier = Modifier) {
    Surface(
        shape = RoundedCornerShape(18.dp),
        color = MaterialTheme.colorScheme.errorContainer,
        modifier = modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                "体温 ≥ 38.0 ℃ 就医提示（仅供参考，不代替医嘱）",
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.onErrorContainer,
            )
            Text(
                "· 未满 3 个月婴儿体温 ≥ 38.0 ℃，建议立即就医（AAP 指南）。\n" +
                    "· 任何月龄若伴有呼吸急促或费力、精神萎靡、叫不醒、持续哭闹无法安抚、抽搐、口唇发紫或按压不褪色皮疹，请立即就医。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onErrorContainer,
            )
        }
    }
}

@Composable
private fun WhenRow(label: String, at: Long, onChange: (Long) -> Unit) {
    var picking by remember { mutableStateOf(false) }
    val now = System.currentTimeMillis()
    val agoMin = ((now - at) / 60_000).toInt()
    Row(
        Modifier.fillMaxWidth().padding(top = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(label, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.weight(1f))
        listOf(0 to "刚刚", 15 to "15分前", 30 to "半小时前").forEach { (m, t) ->
            FilterChip(
                selected = kotlin.math.abs(agoMin - m) <= 2,
                onClick = { onChange(System.currentTimeMillis() - m * 60_000L) },
                label = { Text(t) },
            )
        }
        TextButton(onClick = { picking = true }, modifier = Modifier.heightIn(min = 48.dp)) {
            Text(whenLabel(at), fontFamily = Numerals, style = MaterialTheme.typography.labelLarge)
        }
    }
    if (picking) TimeDialog(label, at, onChange, { picking = false })
}

@Composable
private fun SideChips(side: String, onPick: (String) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 8.dp)) {
        listOf("l" to "左侧", "r" to "右侧", "b" to "双侧").forEach { (c, l) ->
            FilterChip(selected = side == c, onClick = { onPick(c) }, label = { Text(l) })
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DurationRow(min: Int, presets: List<Int>, step: Int = 5, onChange: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
        OutlinedButton(onClick = { onChange((min - step).coerceAtLeast(1)) }, shape = RoundedCornerShape(14.dp)) { Text("−$step") }
        Text(minutes(min * 60_000L), fontFamily = Numerals, style = MaterialTheme.typography.headlineMedium, modifier = Modifier.padding(horizontal = 18.dp))
        OutlinedButton(onClick = { onChange((min + step).coerceAtMost(720)) }, shape = RoundedCornerShape(14.dp)) { Text("+$step") }
    }
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        presets.forEach { p -> FilterChip(selected = min == p, onClick = { onChange(p) }, label = { Text("${p}分") }) }
    }
}

@Composable
private fun SaveButton(onClick: () -> Unit) {
    Spacer(Modifier.height(14.dp))
    Button(onClick = onClick, modifier = Modifier.fillMaxWidth().height(52.dp), shape = RoundedCornerShape(18.dp)) {
        Text("记下来", style = MaterialTheme.typography.titleMedium)
    }
}

/** Edit or delete any existing entry: start/end time, side, amount, or note. */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun EntrySheet(
    e: LogEntry,
    onSave: (LogEntry) -> Unit,
    onDelete: (LogEntry) -> Unit,
    onDismiss: () -> Unit,
) {
    val k = logKind(e.type)
    var start by remember(e.id) { mutableLongStateOf(e.start) }
    var end by remember(e.id) { mutableStateOf(e.end) }
    var side by remember(e.id) { mutableStateOf(e.side ?: "l") }
    var amount by remember(e.id) { mutableIntStateOf(e.amount ?: if (e.type == LogType.Temp) 370 else 120) }
    var detail by remember(e.id) { mutableStateOf(e.detail ?: "") }
    var pickStart by remember { mutableStateOf(false) }
    var pickEnd by remember { mutableStateOf(false) }
    val kb = androidx.compose.ui.platform.LocalSoftwareKeyboardController.current
    val fm = androidx.compose.ui.platform.LocalFocusManager.current
    val close = { fm.clearFocus(); kb?.hide(); onDismiss() }

    ModalBottomSheet(onDismissRequest = close, containerColor = MaterialTheme.colorScheme.surfaceContainerLowest) {
        Column(
            Modifier
                .fillMaxWidth()
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .padding(bottom = 24.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                ShapeBadge(k.glyph, k.tint.copy(alpha = 0.16f), k.tint, shape = Shapes.of(e.type), size = 38.dp)
                Spacer(Modifier.width(10.dp))
                Text(k.label, style = MaterialTheme.typography.headlineSmall)
            }
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(if (end != null) "开始时间" else "时间", style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
                TextButton(onClick = { pickStart = true }, modifier = Modifier.heightIn(min = 48.dp)) {
                    Text(whenLabel(start), fontFamily = Numerals, style = MaterialTheme.typography.titleMedium)
                }
            }
            if (end != null || e.type == LogType.Nurse || e.type == LogType.Sleep) {
                val endVal = end ?: (start + 15 * 60_000L)
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text("结束时间（${minutes((endVal - start).coerceAtLeast(0))}）", style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
                    TextButton(onClick = { end = endVal; pickEnd = true }, modifier = Modifier.heightIn(min = 48.dp)) {
                        Text(whenLabel(endVal), fontFamily = Numerals, style = MaterialTheme.typography.titleMedium)
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("时长：", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.align(Alignment.CenterVertically))
                    listOf(-5, +5, +15).forEach { d ->
                        OutlinedButton(
                            onClick = { end = (endVal + d * 60_000L).coerceAtLeast(start + 60_000L).coerceAtMost(System.currentTimeMillis()) },
                            shape = RoundedCornerShape(12.dp),
                        ) { Text(if (d > 0) "+${d}分" else "${d}分") }
                    }
                }
            }
            if (e.type == LogType.Nurse) SideChips(side) { side = it }
            if (e.type == LogType.Bottle) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
                    OutlinedButton(onClick = { amount = (amount - 10).coerceAtLeast(10) }) { Text("−10") }
                    Text("$amount 毫升", fontFamily = Numerals, style = MaterialTheme.typography.headlineMedium, modifier = Modifier.padding(horizontal = 16.dp))
                    OutlinedButton(onClick = { amount = (amount + 10).coerceAtMost(360) }) { Text("+10") }
                }
            }
            if (e.type == LogType.Temp) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
                    OutlinedButton(onClick = { amount = (amount - 1).coerceAtLeast(350) }) { Text("−0.1") }
                    Text("${"%.1f".format(amount / 10.0)} ℃", fontFamily = Numerals, style = MaterialTheme.typography.headlineMedium, modifier = Modifier.padding(horizontal = 16.dp))
                    OutlinedButton(onClick = { amount = (amount + 1).coerceAtMost(420) }) { Text("+0.1") }
                }
                if (amount >= 380) {
                    FeverMedicalBanner()
                }
            }
            if (e.type == LogType.Diaper) {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("wet" to "湿了", "dirty" to "便便", "both" to "都有").forEach { (c, l) ->
                        FilterChip(selected = detail == c, onClick = { detail = c }, label = { Text(l) })
                    }
                }
            } else {
                OutlinedTextField(detail, { detail = it.take(500) }, label = { Text("备注") }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp))
            }
            Row(Modifier.fillMaxWidth().padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedButton(
                    onClick = { onDelete(e); close() },
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error),
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier.height(48.dp),
                ) { Text("删除") }
                Button(
                    onClick = {
                        onSave(
                            e.copy(
                                start = start,
                                end = end?.coerceAtLeast(start),
                                side = if (e.type == LogType.Nurse) side else e.side,
                                amount = if (e.type == LogType.Bottle || e.type == LogType.Temp) amount else e.amount,
                                detail = detail.trim().ifEmpty { null },
                            )
                        )
                        close()
                    },
                    modifier = Modifier.weight(1f).height(48.dp),
                    shape = RoundedCornerShape(16.dp),
                ) { Text("保存") }
            }
        }
    }
    if (pickStart) {
        TimeDialog("开始时间", start, { start = it; if (end != null && end!! < it) end = it + 60_000L }, { pickStart = false })
    }
    if (pickEnd) {
        TimeDialog("结束时间", end ?: start, { end = it }, { pickEnd = false }, notBefore = start)
    }
}
