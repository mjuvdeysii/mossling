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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
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
@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
fun Onboarding(onBirth: () -> Unit, onSkip: () -> Unit) {
    val rise = remember { Animatable(0f) }
    val still = LocalInspectionMode.current
    LaunchedEffect(Unit) { if (still) rise.snapTo(1f) else rise.animateTo(1f, tween(900)) }
    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(24.dp)) {
        Spacer(Modifier.weight(1f))
        Box(Modifier.fillMaxWidth().height(200.dp), contentAlignment = Alignment.BottomCenter) {
            Row(horizontalArrangement = Arrangement.spacedBy((-18).dp), verticalAlignment = Alignment.Bottom) {
                Creature(Kind.Moss, Modifier.size(170.dp).graphicsLayer { translationY = (1 - rise.value) * 80f; alpha = rise.value }, look = Offset(0.9f, -0.1f), poke = true)
                Creature(Kind.Otto, Modifier.size(150.dp).graphicsLayer { translationY = (1 - rise.value) * 120f; alpha = rise.value }, look = Offset(-0.9f, 0f), poke = true)
            }
        }
        Spacer(Modifier.height(28.dp))
        Text("小苔花", style = MaterialTheme.typography.displayMedium, color = MaterialTheme.colorScheme.primary)
        Text("Mossling", fontFamily = Numerals, style = MaterialTheme.typography.headlineSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text("跟着孩子，一个月一站。", style = MaterialTheme.typography.bodyLarge, modifier = Modifier.padding(top = 12.dp))
        Text("0–3 岁早教活动规划", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 6.dp))
        Spacer(Modifier.weight(1f))
        Button(onClick = onBirth, modifier = Modifier.fillMaxWidth().height(56.dp), shape = RoundedCornerShape(20.dp)) { Text("填写宝宝的出生日期") }
        TextButton(onClick = onSkip, modifier = Modifier.fillMaxWidth().height(52.dp)) { Text("先看看") }
        // what continuing means, with each document one tap away
        var doc by remember { androidx.compose.runtime.mutableStateOf<String?>(null) }
        Text("继续使用即表示已阅读并同意以下文件。本应用提供家庭养育参考，不能替代医生的诊断和建议。", style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = androidx.compose.ui.text.style.TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
        androidx.compose.foundation.layout.FlowRow(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) {
            listOf("使用条款" to "TERMS.md", "隐私政策" to "PRIVACY.md", "免责声明" to "DISCLAIMER.md").forEach { (t, f) ->
                TextButton(onClick = { doc = f }) { Text("《$t》", style = MaterialTheme.typography.labelLarge) }
            }
        }
        doc?.let { f ->
            androidx.compose.ui.window.Dialog(onDismissRequest = { doc = null }, properties = androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false)) {
                androidx.compose.material3.Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) { app.mossling.ui.you.DocScreen(f) { doc = null } }
            }
        }
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
