package app.mossling.ui.journal

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimeInput
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import app.mossling.ui.theme.Numerals
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset

/** "今天", "昨天", "前天", otherwise "10月20日". */
fun dayLabel(d: LocalDate, today: LocalDate = LocalDate.now()): String = when (d) {
    today -> "今天"; today.minusDays(1) -> "昨天"; today.minusDays(2) -> "前天"; else -> "${d.monthValue}月${d.dayOfMonth}日"
}

/** "今天 14:05" / "昨天 23:40" — the whole time, never shortened. */
fun whenLabel(at: Long): String {
    val t = Instant.ofEpochMilli(at).atZone(ZoneId.systemDefault())
    return dayLabel(t.toLocalDate()) + " " + "%02d:%02d".format(t.hour, t.minute)
}

/**
 * Pick an exact day and minute. The day is one tap (今天 / 昨天 / 前天, or any earlier date); the time is typed
 * (exact to the minute) or set on the dial. Never later than now, never earlier than [notBefore].
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun TimeDialog(title: String, initial: Long, onPick: (Long) -> Unit, onDismiss: () -> Unit, notBefore: Long? = null) {
    val z = ZoneId.systemDefault()
    val t0 = Instant.ofEpochMilli(initial).atZone(z)
    val today = LocalDate.now()
    var day by remember { mutableStateOf(t0.toLocalDate()) }
    var dial by remember { mutableStateOf(false) }
    var calendar by remember { mutableStateOf(false) }
    val st = rememberTimePickerState(t0.hour, t0.minute, is24Hour = true)
    fun result(): Long = day.atTime(st.hour, st.minute).atZone(z).toInstant().toEpochMilli()
    val picked = result()
    val future = picked > System.currentTimeMillis() + 60_000
    val tooEarly = notBefore != null && picked <= notBefore
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Surface(shape = RoundedCornerShape(28.dp), color = MaterialTheme.colorScheme.surfaceContainerHigh,
            modifier = Modifier.fillMaxWidth(0.94f).widthIn(max = 420.dp)) {
            Column(Modifier.verticalScroll(rememberScrollState()).padding(24.dp)) {
                Text(title, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(whenLabel(picked), fontFamily = Numerals, style = MaterialTheme.typography.headlineMedium, modifier = Modifier.padding(top = 4.dp))
                FlowRow(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(today, today.minusDays(1), today.minusDays(2)).forEach { d ->
                        FilterChip(selected = day == d, onClick = { day = d }, label = { Text(dayLabel(d, today)) })
                    }
                    val older = day.isBefore(today.minusDays(2))
                    FilterChip(selected = older, onClick = { calendar = true }, label = { Text(if (older) dayLabel(day, today) else "更早…") })
                }
                Column(Modifier.fillMaxWidth().padding(top = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    if (dial) TimePicker(st) else TimeInput(st)
                }
                when {
                    future -> Text("不能晚于现在", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                    tooEarly -> Text("要晚于开始时间", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
                }
                Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                    TextButton(onClick = { dial = !dial }) { Text(if (dial) "输入时间" else "表盘") }
                    Spacer(Modifier.weight(1f))
                    TextButton(onClick = onDismiss) { Text("取消") }
                    TextButton(onClick = { onPick(picked); onDismiss() }, enabled = !future && !tooEarly, modifier = Modifier.heightIn(min = 48.dp)) { Text("好") }
                }
            }
        }
    }
    if (calendar) {
        val ds = rememberDatePickerState(initialSelectedDateMillis = day.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
            selectableDates = object : SelectableDates { override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis <= System.currentTimeMillis() })
        DatePickerDialog(onDismissRequest = { calendar = false },
            confirmButton = { TextButton(onClick = { ds.selectedDateMillis?.let { day = Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate() }; calendar = false }) { Text("好") } },
            dismissButton = { TextButton(onClick = { calendar = false }) { Text("取消") } }) { DatePicker(ds) }
    }
}
