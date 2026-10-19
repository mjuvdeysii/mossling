package app.mossling.ui.onboarding

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SelectableDates
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalInspectionMode
import androidx.compose.ui.unit.dp
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.Kind
import app.mossling.ui.theme.Numerals
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

/** First run: the two of them, the name, one question. Everything can be skipped. */
@Composable
fun Onboarding(onBirth: () -> Unit, onSkip: () -> Unit) {
    val rise = remember { Animatable(0f) }
    val still = LocalInspectionMode.current
    LaunchedEffect(Unit) { if (still) rise.snapTo(1f) else rise.animateTo(1f, tween(900)) }
    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(24.dp)) {
        Spacer(Modifier.weight(1f))
        Box(Modifier.fillMaxWidth().height(200.dp), contentAlignment = Alignment.BottomCenter) {
            Row(horizontalArrangement = Arrangement.spacedBy((-18).dp), verticalAlignment = Alignment.Bottom) {
                Creature(Kind.Moss, Modifier.size(170.dp).graphicsLayer { translationY = (1 - rise.value) * 80f; alpha = rise.value }, look = Offset(0.9f, -0.1f))
                Creature(Kind.Otto, Modifier.size(150.dp).graphicsLayer { translationY = (1 - rise.value) * 120f; alpha = rise.value }, look = Offset(-0.9f, 0f))
            }
        }
        Spacer(Modifier.height(28.dp))
        Text("Mossling", fontFamily = Numerals, style = MaterialTheme.typography.displayMedium)
        Text("苔生", style = MaterialTheme.typography.headlineMedium, color = MaterialTheme.colorScheme.primary)
        Text("头一千天，跟着孩子，慢慢来。", style = MaterialTheme.typography.bodyLarge, modifier = Modifier.padding(top = 12.dp))
        Text("Moss 会安静地看，Otto 一次只专心一件事。它们陪你看每个月可以做什么，记下每天发生了什么。", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 6.dp))
        Spacer(Modifier.weight(1f))
        Button(onClick = onBirth, modifier = Modifier.fillMaxWidth().height(56.dp), shape = RoundedCornerShape(20.dp)) { Text("填写宝宝的出生日期") }
        TextButton(onClick = onSkip, modifier = Modifier.fillMaxWidth().height(52.dp)) { Text("先看看") }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BirthDialog(initial: LocalDate?, onPick: (LocalDate) -> Unit, onDismiss: () -> Unit) {
    val today = LocalDate.now()
    val state = rememberDatePickerState(
        initialSelectedDateMillis = (initial ?: today.minusMonths(3)).atStartOfDay().toInstant(ZoneOffset.UTC).toEpochMilli(),
        yearRange = (today.year - 4)..today.year,
        selectableDates = object : SelectableDates {
            override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis <= today.atStartOfDay().toInstant(ZoneOffset.UTC).toEpochMilli()
        },
    )
    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = { state.selectedDateMillis?.let { onPick(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate()) }; onDismiss() }) { Text("好") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("取消") } },
    ) { DatePicker(state, title = { Text("宝宝的出生日期", modifier = Modifier.padding(start = 24.dp, top = 16.dp)) }) }
}
