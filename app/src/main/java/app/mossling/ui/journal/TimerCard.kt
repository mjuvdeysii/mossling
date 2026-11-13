package app.mossling.ui.journal

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import app.mossling.data.LogType
import app.mossling.data.RunningTimer
import app.mossling.journal.Timers
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.TickingText
import app.mossling.ui.components.clock
import app.mossling.ui.components.hm
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.Mood
import app.mossling.ui.theme.LocalCompanion
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette
import kotlinx.coroutines.delay

@Composable
fun TimerCard(
    t: RunningTimer,
    onPause: () -> Unit,
    onSwitchSide: () -> Unit,
    onShift: (Long) -> Unit,
    onStop: () -> Unit,
    onDiscard: () -> Unit,
    modifier: Modifier = Modifier,
    onExpand: (() -> Unit)? = null,
    now: () -> Long = System::currentTimeMillis,
) {
    var tick by remember { mutableLongStateOf(now()) }
    LaunchedEffect(t.pausedAt) {
        while (t.pausedAt == null) {
            delay(500)
            tick = now()
        }
    }
    val elapsed = Timers.elapsed(t, tick)
    val leftMs = if (t.type == LogType.Nurse) Timers.sideElapsed(t, "l", tick) else 0L
    val rightMs = if (t.type == LogType.Nurse) Timers.sideElapsed(t, "r", tick) else 0L
    val pausedDuration = if (t.pausedAt != null) (tick - t.pausedAt).coerceAtLeast(0) else 0L

    val title = when (t.type) {
        LogType.Nurse -> "正在亲喂" + when (t.side) {
            "l" -> " · 左侧"
            "r" -> " · 右侧"
            else -> ""
        }
        LogType.Sleep -> "正在睡觉"
        else -> "计时中"
    }
    val longWarning = when {
        t.type == LogType.Nurse && elapsed > 3_600_000L -> "亲喂计时已超过 1 小时，如已结束可点「记下来」或调整开始时间"
        t.type == LogType.Sleep && elapsed > 12 * 3_600_000L -> "睡眠计时已超过 12 小时，如已醒来可点「记下来」"
        pausedDuration > 20 * 60_000L -> "已暂停超过 20 分钟，别忘了继续或结束记录"
        else -> null
    }
    val companion = LocalCompanion.current

    Surface(
        modifier = modifier.fillMaxWidth().let { if (onExpand != null) it.clickable { onExpand() } else it },
        shape = RoundedCornerShape(28.dp),
        color = MaterialTheme.colorScheme.primaryContainer,
    ) {
        Column(Modifier.padding(20.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            text = title + if (t.pausedAt != null) "（已暂停）" else "",
                            style = MaterialTheme.typography.labelLarge,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                        )
                        if (onExpand != null) {
                            Text(
                                "展开 →",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                    }
                    Text(
                        "从 ${hm(t.start)} 开始",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.75f),
                    )
                    TickingText(
                        text = clock(elapsed),
                        style = MaterialTheme.typography.displayMedium,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                        fontFamily = Numerals,
                    )
                    if (t.type == LogType.Nurse && t.carried > 0L) {
                        Text(
                            "左 ${clock(leftMs)} · 右 ${clock(rightMs)}",
                            fontFamily = Numerals,
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.85f),
                        )
                    }
                }
                Creature(
                    companion,
                    Modifier.size(72.dp),
                    mood = if (t.type == LogType.Sleep) Mood.Sleep else Mood.Listening,
                )
            }
            if (longWarning != null) {
                Spacer(Modifier.height(6.dp))
                Text(
                    longWarning,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onPrimaryContainer,
                )
            }
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(
                    "开始得更早：",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.75f),
                )
                TextButton(onClick = { onShift(-5 * 60_000L) }, contentPadding = PaddingValues(horizontal = 8.dp)) { Text("早 5 分钟") }
                TextButton(onClick = { onShift(-15 * 60_000L) }, contentPadding = PaddingValues(horizontal = 8.dp)) { Text("早 15 分钟") }
                Spacer(Modifier.weight(1f))
                TextButton(onClick = onDiscard, contentPadding = PaddingValues(horizontal = 8.dp)) { Text("放弃") }
            }
            Spacer(Modifier.height(6.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilledTonalButton(onClick = onPause, shape = RoundedCornerShape(16.dp)) {
                    Text(if (t.pausedAt == null) "暂停" else "继续")
                }
                if (t.type == LogType.Nurse) {
                    FilledTonalButton(onClick = onSwitchSide, shape = RoundedCornerShape(16.dp)) {
                        Text("换到" + if (t.side == "l") "右侧" else "左侧")
                    }
                }
                Spacer(Modifier.weight(1f))
                Button(
                    onClick = onStop,
                    shape = RoundedCornerShape(16.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = MaterialTheme.colorScheme.primary,
                        contentColor = MaterialTheme.colorScheme.onPrimary,
                    ),
                ) {
                    Glyph(G.Check, size = 18.dp)
                    Spacer(Modifier.width(6.dp))
                    Text("记下来")
                }
            }
        }
    }
}

/**
 * Full-screen / modal interactive timer sheet:
 * - For **亲喂 (`LogType.Nurse`)**: Tap Left or Right circle directly to start, pause, or switch side; shows per-side and total duration, with a separate bottom "喂完了，记下" button.
 * - For **睡觉 (`LogType.Sleep`)**: Tap Moon circle to pause/resume, with a separate bottom "醒了，记下" button.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimerModalSheet(
    type: String,
    timer: RunningTimer?,
    onStart: (String?) -> Unit,
    onTapSide: (String) -> Unit,
    onPause: () -> Unit,
    onShift: (Long) -> Unit,
    onStop: () -> Unit,
    onDiscard: () -> Unit,
    onManualEntry: () -> Unit,
    onDismiss: () -> Unit,
    now: () -> Long = System::currentTimeMillis,
) {
    var tick by remember { mutableLongStateOf(now()) }
    LaunchedEffect(timer?.pausedAt, timer?.start) {
        while (timer != null && timer.pausedAt == null) {
            delay(500)
            tick = now()
        }
    }
    val elapsed = if (timer != null) Timers.elapsed(timer, tick) else 0L
    val leftMs = if (timer != null && type == LogType.Nurse) Timers.sideElapsed(timer, "l", tick) else 0L
    val rightMs = if (timer != null && type == LogType.Nurse) Timers.sideElapsed(timer, "r", tick) else 0L
    val companion = LocalCompanion.current

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = MaterialTheme.colorScheme.surfaceContainerLowest,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 28.dp)
                .navigationBarsPadding(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(
                        if (type == LogType.Sleep) "睡觉计时" else "亲喂计时",
                        style = MaterialTheme.typography.headlineSmall,
                    )
                    Text(
                        if (timer != null) "从 ${hm(timer.start)} 开始" + (if (timer.pausedAt != null) " · 已暂停" else "")
                        else if (type == LogType.Sleep) "点中间的月亮开始计时" else "点「左」或「右」开始计时，再点暂停或换边",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                TextButton(onClick = onManualEntry) { Text("补记已结束的") }
            }

            TickingText(
                text = clock(elapsed),
                style = MaterialTheme.typography.displayLarge,
                fontFamily = Numerals,
                color = MaterialTheme.colorScheme.primary,
            )

            if (type == LogType.Nurse) {
                Row(
                    Modifier.fillMaxWidth().padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterHorizontally),
                ) {
                    NurseSideCircle(
                        label = "左侧 L",
                        elapsedMs = leftMs,
                        active = timer != null && timer.side == "l" && timer.pausedAt == null,
                        paused = timer != null && timer.side == "l" && timer.pausedAt != null,
                        onClick = { onTapSide("l") },
                    )
                    NurseSideCircle(
                        label = "右侧 R",
                        elapsedMs = rightMs,
                        active = timer != null && timer.side == "r" && timer.pausedAt == null,
                        paused = timer != null && timer.side == "r" && timer.pausedAt != null,
                        onClick = { onTapSide("r") },
                    )
                }
            } else {
                val active = timer != null && timer.pausedAt == null
                Surface(
                    onClick = { if (timer == null) onStart(null) else onPause() },
                    shape = CircleShape,
                    color = if (active) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceContainerHigh,
                    border = BorderStroke(if (active) 3.dp else 1.dp, if (active) Palette.Bead else MaterialTheme.colorScheme.outlineVariant),
                    modifier = Modifier.size(148.dp),
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center,
                    ) {
                        Glyph(
                            G.Moon,
                            size = 40.dp,
                            filled = active,
                            color = if (active) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Spacer(Modifier.height(6.dp))
                        Text(
                            when {
                                timer == null -> "点一下睡着"
                                timer.pausedAt != null -> "点一下继续"
                                else -> "正在睡 · 点暂停"
                            },
                            style = MaterialTheme.typography.labelLarge,
                        )
                    }
                }
            }

            if (timer != null) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("其实开始得更早：", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    TextButton(onClick = { onShift(-5 * 60_000L) }) { Text("早 5 分钟") }
                    TextButton(onClick = { onShift(-15 * 60_000L) }) { Text("早 15 分钟") }
                }

                Row(
                    Modifier.fillMaxWidth().padding(top = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    OutlinedButton(
                        onClick = { onDiscard(); onDismiss() },
                        modifier = Modifier.heightIn(min = 52.dp),
                        shape = RoundedCornerShape(18.dp),
                    ) {
                        Text("放弃")
                    }
                    Button(
                        onClick = { onStop(); onDismiss() },
                        modifier = Modifier.weight(1f).heightIn(min = 52.dp),
                        shape = RoundedCornerShape(18.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Palette.Bead,
                            contentColor = Palette.Ink,
                        ),
                    ) {
                        Glyph(G.Check, size = 18.dp, color = Palette.Ink)
                        Spacer(Modifier.width(8.dp))
                        Text(
                            if (type == LogType.Sleep) "醒了，记下" else "喂完了，记下",
                            style = MaterialTheme.typography.titleMedium,
                        )
                    }
                }
            } else {
                Creature(
                    companion,
                    Modifier.size(64.dp),
                    mood = if (type == LogType.Sleep) Mood.Sleep else Mood.Listening,
                )
            }
        }
    }
}

@Composable
private fun NurseSideCircle(
    label: String,
    elapsedMs: Long,
    active: Boolean,
    paused: Boolean,
    onClick: () -> Unit,
) {
    Surface(
        onClick = onClick,
        shape = CircleShape,
        color = when {
            active -> MaterialTheme.colorScheme.primaryContainer
            paused -> MaterialTheme.colorScheme.secondaryContainer
            else -> MaterialTheme.colorScheme.surfaceContainerHigh
        },
        border = BorderStroke(
            width = if (active) 3.dp else 1.5.dp,
            color = if (active) Palette.Bead else MaterialTheme.colorScheme.outlineVariant,
        ),
        modifier = Modifier.size(136.dp),
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.padding(12.dp),
        ) {
            Text(label, style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(4.dp))
            TickingText(
                text = clock(elapsedMs),
                style = MaterialTheme.typography.headlineSmall,
                fontFamily = Numerals,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                when {
                    active -> "计时中 · 点暂停"
                    paused -> "已暂停 · 点继续"
                    elapsedMs > 0 -> "点换到这边"
                    else -> "点开始"
                },
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
