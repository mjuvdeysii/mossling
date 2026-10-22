package app.mossling.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.ProgressBarRangeInfo
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.progressBarRangeInfo
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.setProgress
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.mossling.ui.theme.Palette
import kotlin.math.roundToInt

/**
 * The 0–36 month chain: all 37 beads on one thread across the width — every month in view at once, nothing to
 * scroll. Tap a bead or slide a finger along the thread; each month passed gives a light tick. The child's own
 * month is the gold bead; months already lived are filled, months ahead are open rings; birth and each birthday
 * are larger, like the ten-bead marks of a Montessori bead chain.
 */
@Composable
fun BeadChain(selected: Int, babyMonth: Int?, onSelect: (Int) -> Unit, modifier: Modifier = Modifier) {
    val haptic = LocalHapticFeedback.current
    val sel by rememberUpdatedState(selected)
    val pick by rememberUpdatedState(onSelect)
    val line = MaterialTheme.colorScheme.outlineVariant
    val future = MaterialTheme.colorScheme.outline
    val past = MaterialTheme.colorScheme.primary
    val on by animateFloatAsState(selected.toFloat(), spring(dampingRatio = 0.7f, stiffness = 420f), label = "ring")
    BoxWithConstraints(modifier.fillMaxWidth().height(64.dp).semantics {
        contentDescription = "月龄串珠"; stateDescription = "满 $selected 个月"
        progressBarRangeInfo = ProgressBarRangeInfo(selected.toFloat(), 0f..36f, steps = 35)
        setProgress { v -> pick(v.roundToInt().coerceIn(0, 36)); true }
    }) {
        val w = constraints.maxWidth.toFloat()
        val pad = 14f * (w / 360f).coerceAtLeast(1f)
        fun monthAt(x: Float) = (((x - pad) / (w - 2 * pad)) * 36).roundToInt().coerceIn(0, 36)
        fun choose(m: Int) { if (m != sel) { haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove); pick(m) } }
        Canvas(Modifier.fillMaxSize()
            .pointerInput(Unit) { detectTapGestures { choose(monthAt(it.x)) } }
            .pointerInput(Unit) { detectHorizontalDragGestures { ch, _ -> choose(monthAt(ch.position.x)) } }) {
            val step = (size.width - 2 * pad) / 36
            val cy = 22.dp.toPx()
            drawLine(line, Offset(pad, cy), Offset(size.width - pad, cy), 1.4.dp.toPx())
            for (m in 0..36) {
                val c = Offset(pad + m * step, cy)
                val base = when { m == babyMonth -> 5.6f; m % 12 == 0 -> 4.6f; else -> 3.4f }.dp.toPx().coerceAtMost(step * 0.48f + if (m == babyMonth || m % 12 == 0) 2.dp.toPx() else 0f)
                when {
                    m == babyMonth -> { drawCircle(Palette.Bead, base, c); drawCircle(Palette.BeadLight, base * 0.32f, Offset(c.x - base * 0.3f, c.y - base * 0.34f)) }
                    babyMonth != null && m < babyMonth -> drawCircle(past, base, c)
                    else -> drawCircle(future, base, c, style = Stroke(1.3.dp.toPx()))
                }
            }
            // the ring of the month shown glides from bead to bead
            drawCircle(Palette.Bead, 8.dp.toPx(), Offset(pad + on * step, cy), style = Stroke(2.dp.toPx()))
        }
        val density = androidx.compose.ui.platform.LocalDensity.current
        fun xDp(m: Int) = with(density) { (pad + m * (w - 2 * pad) / 36).toDp() }
        listOf(0 to "出生", 12 to "1岁", 24 to "2岁", 36 to "3岁").forEach { (m, t) ->
            Box(Modifier.offset(x = xDp(m) - 20.dp, y = 36.dp).width(40.dp)) {
                Text(t, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth())
            }
        }
    }
}
