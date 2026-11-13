package app.mossling.ui.journal

import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import app.mossling.AppUi
import app.mossling.data.First
import app.mossling.data.FirstPresets
import app.mossling.domain.ageOn
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.Plate
import app.mossling.ui.components.ShapeBadge
import app.mossling.ui.components.Shapes
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.Mood
import app.mossling.ui.theme.Numerals
import app.mossling.ui.you.Bar
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset

/**
 * Baby's "Firsts" screen ("第一次"):
 * View, add, edit, and delete special first moments (first smile, roll, tooth, solid food, steps, or custom).
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun FirstsScreen(
    ui: AppUi,
    onSave: (First) -> Unit,
    onDelete: (Long) -> Unit,
    onBack: () -> Unit,
) {
    var editing by remember { mutableStateOf<First?>(null) }
    val zone = ZoneId.systemDefault()
    val birth = ui.settings.birth
    val sorted = remember(ui.firsts) { ui.firsts.sortedByDescending { it.at } }
    val recordedKeys = remember(ui.firsts) { ui.firsts.map { it.key }.toSet() }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 112.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item("bar") { Bar("第一次", onBack) }

        item("hero") {
            Surface(
                shape = RoundedCornerShape(28.dp),
                color = MaterialTheme.colorScheme.surfaceContainer,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            ) {
                Row(
                    Modifier.padding(20.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text("留住那些「第一次」", style = MaterialTheme.typography.headlineSmall)
                        Text(
                            "第一次对着人笑、第一颗小乳牙、第一次松开手走两步……不用每天都记，遇到的时候顺手写下一行，会自动收进成长册。",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                    Spacer(Modifier.width(8.dp))
                    Creature(ui.settings.companion, Modifier.size(64.dp), mood = Mood.Happy)
                }
            }
        }

        item("presets") {
            Plate(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Glyph(G.Heart, size = 20.dp, filled = true, color = MaterialTheme.colorScheme.primary)
                    Spacer(Modifier.width(8.dp))
                    Text("常见的第一次 · 点一下直接记", style = MaterialTheme.typography.titleSmall)
                }
                Spacer(Modifier.height(10.dp))
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    FirstPresets.forEach { preset ->
                        val done = preset.key in recordedKeys
                        FilterChip(
                            selected = done,
                            onClick = {
                                val existing = ui.firsts.firstOrNull { it.key == preset.key }
                                editing = existing ?: First(
                                    at = System.currentTimeMillis(),
                                    key = preset.key,
                                    title = preset.title,
                                )
                            },
                            label = { Text(preset.title) },
                        )
                    }
                }
                Spacer(Modifier.height(12.dp))
                Button(
                    onClick = {
                        editing = First(
                            at = System.currentTimeMillis(),
                            key = "custom",
                            title = "",
                        )
                    },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
                    shape = RoundedCornerShape(16.dp),
                ) {
                    Glyph(G.Plus, size = 18.dp)
                    Spacer(Modifier.width(6.dp))
                    Text("记一个自己的「第一次」")
                }
            }
        }

        if (sorted.isEmpty()) {
            item("empty") {
                Text(
                    "还没有记下「第一次」；点上面的卡片就能添一条。",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 24.dp, vertical = 12.dp),
                )
            }
        } else {
            items(sorted, key = { it.id }) { f ->
                val d = Instant.ofEpochMilli(f.at).atZone(zone).toLocalDate()
                val ageStr = birth?.let { b ->
                    val a = ageOn(b, d)
                    if (a.months == 0) "出生第 ${a.lived} 天"
                    else if (a.days == 0) "满 ${a.months} 个月"
                    else "${a.months} 个月 ${a.days} 天"
                }
                Surface(
                    onClick = { editing = f },
                    shape = RoundedCornerShape(22.dp),
                    color = MaterialTheme.colorScheme.surfaceContainerLowest,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
                ) {
                    Row(
                        Modifier.padding(18.dp),
                        verticalAlignment = Alignment.Top,
                    ) {
                        ShapeBadge(
                            G.Heart,
                            MaterialTheme.colorScheme.tertiaryContainer,
                            MaterialTheme.colorScheme.onTertiaryContainer,
                            shape = Shapes.Flower,
                            size = 34.dp,
                            filled = true,
                        )
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(f.title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                                Text(
                                    "${d.year}.${d.monthValue}.${d.dayOfMonth}",
                                    fontFamily = Numerals,
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            if (ageStr != null) {
                                Text(
                                    ageStr,
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.primary,
                                    modifier = Modifier.padding(top = 2.dp),
                                )
                            }
                            if (!f.note.isNullOrBlank()) {
                                Text(
                                    f.note,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(top = 6.dp),
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    editing?.let { current ->
        FirstEditSheet(
            first = current,
            onSave = {
                onSave(it)
                editing = null
            },
            onDelete = {
                if (current.id != 0L) onDelete(current.id)
                editing = null
            },
            onDismiss = { editing = null },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FirstEditSheet(
    first: First,
    onSave: (First) -> Unit,
    onDelete: () -> Unit,
    onDismiss: () -> Unit,
) {
    val zone = ZoneId.systemDefault()
    var title by remember(first.id, first.key) { mutableStateOf(first.title) }
    var note by remember(first.id, first.key) { mutableStateOf(first.note ?: "") }
    var day by remember(first.id, first.at) {
        mutableStateOf(Instant.ofEpochMilli(first.at).atZone(zone).toLocalDate())
    }
    var calendar by remember { mutableStateOf(false) }
    val presetHint = remember(first.key) { FirstPresets.firstOrNull { it.key == first.key }?.hint }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surfaceContainerLowest,
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .imePadding()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .padding(bottom = 28.dp)
                .navigationBarsPadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                if (first.id == 0L) "记一次「第一次」" else "编辑「第一次」",
                style = MaterialTheme.typography.headlineSmall,
            )
            if (presetHint != null) {
                Text(presetHint, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = { day = day.minusDays(1) }) { Text("前一天") }
                FilledTonalButton(
                    onClick = { calendar = true },
                    shape = RoundedCornerShape(16.dp),
                    modifier = Modifier.weight(1f).heightIn(min = 48.dp),
                ) {
                    Text(
                        "${day.year}年${day.monthValue}月${day.dayOfMonth}日" + if (day == LocalDate.now()) " · 今天" else "",
                        style = MaterialTheme.typography.titleSmall,
                    )
                }
                TextButton(
                    onClick = { if (day < LocalDate.now()) day = day.plusDays(1) },
                    enabled = day < LocalDate.now(),
                ) { Text("后一天") }
            }
            OutlinedTextField(
                value = title,
                onValueChange = { title = it.take(80) },
                label = { Text("这件事的名字") },
                placeholder = { Text("例如：第一次翻身、第一颗小牙") },
                singleLine = true,
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = note,
                onValueChange = { note = it.take(400) },
                label = { Text("当时的样子（选填）") },
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier.fillMaxWidth(),
            )
            Row(Modifier.fillMaxWidth().padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                if (first.id != 0L) {
                    TextButton(onClick = onDelete) { Text("删除", color = MaterialTheme.colorScheme.error) }
                }
                Spacer(Modifier.weight(1f))
                TextButton(onClick = onDismiss) { Text("取消") }
                Button(
                    onClick = {
                        val atMs = day.atTime(12, 0).atZone(zone).toInstant().toEpochMilli()
                        onSave(
                            first.copy(
                                at = atMs,
                                title = title.trim(),
                                note = note.trim().ifEmpty { null },
                            )
                        )
                    },
                    enabled = title.isNotBlank(),
                    shape = RoundedCornerShape(18.dp),
                    modifier = Modifier.heightIn(min = 48.dp),
                ) {
                    Text("保存")
                }
            }
        }
    }

    if (calendar) {
        val ds = rememberDatePickerState(
            initialSelectedDateMillis = day.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis <= System.currentTimeMillis()
            },
        )
        DatePickerDialog(
            onDismissRequest = { calendar = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        ds.selectedDateMillis?.let { day = Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate() }
                        calendar = false
                    }
                ) { Text("好") }
            },
            dismissButton = { TextButton(onClick = { calendar = false }) { Text("取消") } },
        ) { DatePicker(ds) }
    }
}
