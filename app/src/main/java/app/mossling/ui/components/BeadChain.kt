package app.mossling.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.snapping.SnapPosition
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.mossling.ui.theme.Palette
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.drop
import kotlinx.coroutines.launch
import kotlin.math.abs

private val Step = 30.dp

/**
 * The 0–36 month scrubber: a golden bead chain on a thread. Drag or fling it; the bead under the centre mark is the
 * month shown, with a light tick of the phone for each month passed. The child's own month is the gold bead.
 */
@Composable
fun BeadChain(selected: Int, babyMonth: Int?, onSelect: (Int) -> Unit, modifier: Modifier = Modifier) {
    val state = rememberLazyListState(initialFirstVisibleItemIndex = selected)
    val fling = rememberSnapFlingBehavior(state, SnapPosition.Center)
    val haptic = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    val centred by remember {
        derivedStateOf {
            val info = state.layoutInfo
            val mid = (info.viewportStartOffset + info.viewportEndOffset) / 2
            info.visibleItemsInfo.minByOrNull { abs(it.offset + it.size / 2 - mid) }?.index ?: selected
        }
    }
    LaunchedEffect(Unit) {
        snapshotFlow { centred }.distinctUntilChanged().drop(1).collect { haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove); onSelect(it) }
    }
    LaunchedEffect(selected) { if (centred != selected) state.animateScrollToItem(selected) }
    val line = MaterialTheme.colorScheme.outlineVariant
    val future = MaterialTheme.colorScheme.outline
    val past = MaterialTheme.colorScheme.primary
    BoxWithConstraints(modifier.fillMaxWidth().height(64.dp)) {
        val side = (maxWidth - Step) / 2
        // the centre mark
        Canvas(Modifier.align(Alignment.Center).width(Step).height(64.dp)) {
            drawLine(Palette.Bead, Offset(size.width / 2, 2f), Offset(size.width / 2, 9.dp.toPx()), 2.dp.toPx())
        }
        LazyRow(state = state, flingBehavior = fling, contentPadding = PaddingValues(horizontal = side), modifier = Modifier.fillMaxWidth()) {
            items(37, key = { it }) { m ->
                val on = m == centred
                val r by animateFloatAsState(if (on) 1f else 0f, spring(dampingRatio = 0.55f, stiffness = 500f), label = "bead")
                Column(
                    Modifier.width(Step).semantics { contentDescription = "满 $m 个月"; this.selected = on }
                        .clickable(remember { MutableInteractionSource() }, null, role = Role.Tab) { scope.launch { state.animateScrollToItem(m) } },
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Canvas(Modifier.width(Step).height(40.dp)) {
                        val cy = size.height / 2 + 4.dp.toPx()
                        val gapLeft = m % 3 == 0 && m > 0
                        drawLine(line, Offset(if (gapLeft) 4.dp.toPx() else 0f, cy), Offset(size.width, cy), 1.4.dp.toPx())
                        val base = when { m == babyMonth -> 9.5f; m % 12 == 0 -> 7.5f; else -> 6f }.dp.toPx()
                        val rad = base * (1f + 0.32f * r)
                        val c = Offset(size.width / 2, cy)
                        when {
                            m == babyMonth -> { drawCircle(Palette.Bead, rad, c); drawCircle(Palette.BeadLight, rad * 0.32f, Offset(c.x - rad * 0.3f, c.y - rad * 0.34f)) }
                            babyMonth != null && m < babyMonth -> drawCircle(past, rad, c)
                            else -> drawCircle(future, rad, c, style = Stroke(1.6.dp.toPx()))
                        }
                        if (on) drawCircle(Palette.Bead, rad + 4.dp.toPx(), c, style = Stroke(1.6.dp.toPx()))
                    }
                    Box(Modifier.height(18.dp), contentAlignment = Alignment.Center) {
                        val label = when (m) { 0 -> "出生"; 12 -> "1岁"; 24 -> "2岁"; 36 -> "3岁"; else -> if (on) "$m" else "" }
                        if (label.isNotEmpty()) Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center)
                    }
                }
            }
        }
    }
}
