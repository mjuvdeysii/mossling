package app.mossling.ui.grow

import androidx.compose.foundation.layout.heightIn
import androidx.compose.ui.draw.clip
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AssistChip
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.mossling.AppUi
import app.mossling.data.Month
import app.mossling.data.TickKind
import app.mossling.domain.monthStart
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.ui.components.reducedMotion
import app.mossling.ui.ip.Creature
import app.mossling.ui.ip.Family
import app.mossling.ui.ip.MaterialStill
import app.mossling.ui.theme.LocalCompanion
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.sin
import kotlin.random.Random

private val Stages = listOf(0 to "0–3 个月", 3 to "3–6 个月", 6 to "6–9 个月", 9 to "9–12 个月", 12 to "12–18 个月", 18 to "18–24 个月", 24 to "24–30 个月", 30 to "30–36 个月")

/**
 * 0–36 months as one road: a station per month, winding left and right like a bead chain laid on the floor.
 * Each station shows the month's title and material, the child's date for it, and whether the month has a vaccine,
 * a check-up, and everything recorded. The companion sits at the child's station; now and then a paper butterfly
 * crosses the map — tap it to go back to where the child is.
 */
@Composable
fun MapScreen(ui: AppUi, open: (Int) -> Unit, onBack: () -> Unit) {
    val c = ui.content ?: return
    val baby = ui.babyMonth
    val list = rememberLazyListState()
    val scope = rememberCoroutineScope()
    // item index of month m: the header is item 0, every stage label adds one
    fun indexOf(m: Int) = 1 + m + Stages.count { it.first <= m }
    LaunchedEffect(baby) { if (baby != null) list.scrollToItem((indexOf(baby) - 1).coerceAtLeast(0)) }
    Box(Modifier.fillMaxSize()) {
        LazyColumn(state = list, contentPadding = PaddingValues(bottom = 48.dp), modifier = Modifier.fillMaxSize()) {
            item("head") {
                Column(Modifier.statusBarsPadding().padding(horizontal = 4.dp, vertical = 4.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        IconButton(onClick = onBack, modifier = Modifier.semantics { contentDescription = "返回" }) { Glyph(G.Back) }
                        Spacer(Modifier.weight(1f))
                        if (baby != null) AssistChip(onClick = { scope.launch { list.animateScrollToItem((indexOf(baby) - 1).coerceAtLeast(0)) } }, label = { Text("跳到满 $baby 个月") }, modifier = Modifier.padding(end = 12.dp))
                    }
                    Text("0–36 个月成长地图", style = MaterialTheme.typography.headlineLarge, modifier = Modifier.padding(horizontal = 16.dp))
                    Text("跟着孩子，一个月一站。", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp))
                    Row(Modifier.padding(horizontal = 16.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
                        Legend(Palette.Rod, "接种", round = true); Legend(Palette.RedRod, "儿保", round = false); Legend(Palette.Bead, "这个月都记下了", round = true)
                    }
                }
            }
            for (m in 0..36) {
                Stages.firstOrNull { it.first == m }?.let { (s, label) -> item("stage$s") { StageLabel(label) } }
                item("m$m") {
                    Station(ui, c.month(m), m, baby, family = c.month(m).feature?.let { c.play(it) }?.let { Family.of(it.domains) }) { open(m) }
                }
            }
        }
        Butterfly(Modifier.fillMaxSize()) { if (baby != null) scope.launch { list.animateScrollToItem((indexOf(baby) - 1).coerceAtLeast(0)) } }
    }
}

@Composable
private fun Legend(color: Color, text: String, round: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(10.dp).background(color, if (round) CircleShape else RoundedCornerShape(2.dp)))
        Text(text, style = MaterialTheme.typography.labelMedium, modifier = Modifier.padding(start = 5.dp))
    }
}


@Composable
private fun StageLabel(label: String) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
        Surface(shape = RoundedCornerShape(14.dp), color = MaterialTheme.colorScheme.surfaceContainer) {
            Row(Modifier.padding(horizontal = 14.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                repeat(3) { Box(Modifier.padding(end = 4.dp).size(7.dp).background(Palette.Bead, CircleShape)) }
                Text(label, style = MaterialTheme.typography.titleSmall, modifier = Modifier.padding(start = 6.dp))
            }
        }
    }
}

/** One month on the road. Even months sit on the left of the road, odd months on the right. */
@Composable
private fun Station(ui: AppUi, mo: Month, m: Int, baby: Int?, family: Family?, onClick: () -> Unit) {
    val companion = LocalCompanion.current
    val left = m % 2 == 0
    val here = m == baby
    val past = baby != null && m < baby
    val observe = mo.observe.sumOf { it.items.size }
    val total = observe + mo.vaccines.size + mo.checkups.size
    val done = total > 0 && ui.count(m, TickKind.Observed) + ui.count(m, TickKind.Vaccine) + ui.count(m, TickKind.Checkup) >= total
    val date = ui.settings.birth?.let { monthStart(it, m) }
    val road = MaterialTheme.colorScheme.surfaceContainerHigh
    val dash = MaterialTheme.colorScheme.outlineVariant
    BoxWithConstraints(Modifier.fillMaxWidth().height(168.dp).clickable(onClick = onClick).semantics {
        contentDescription = "满 $m 个月，${mo.title}" + (if (here) "，宝宝现在在这里" else "") + (if (done) "，都记下了" else "")
    }) {
        val w = maxWidth
        // the road: a band that swings from one side to the other through this row
        Canvas(Modifier.fillMaxSize()) {
            val xL = size.width * 0.18f; val xR = size.width * 0.82f
            val from = if (left) xR else xL; val to = if (left) xL else xR
            val p = Path().apply {
                moveTo((from + to) / 2 + (from - to) * 0.0f, 0f)
                cubicTo((from + to) / 2, size.height * 0.15f, to, size.height * 0.25f, to, size.height * 0.5f)
                cubicTo(to, size.height * 0.75f, (from + to) / 2, size.height * 0.85f, (from + to) / 2, size.height)
            }
            drawPath(p, road, style = Stroke(26.dp.toPx(), cap = StrokeCap.Round))
            drawPath(p, if (past || here) Palette.Bead.copy(alpha = 0.55f) else dash, style = Stroke(2.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 10f))))
        }
        // the station: a numbered bead on the road
        val sx = if (left) w * 0.18f else w * 0.82f
        Box(Modifier.offset(x = sx - 28.dp, y = 84.dp - 28.dp).size(56.dp), contentAlignment = Alignment.Center) {
            Surface(shape = CircleShape, color = when { here -> MaterialTheme.colorScheme.primary; past -> Palette.Bead; else -> MaterialTheme.colorScheme.surfaceContainerLowest },
                border = androidx.compose.foundation.BorderStroke(2.dp, if (here) MaterialTheme.colorScheme.primary else Palette.Bead.copy(alpha = if (past) 1f else 0.6f)), modifier = Modifier.size(52.dp)) {
                Box(contentAlignment = Alignment.Center) {
                    Text("$m", fontFamily = Numerals, style = MaterialTheme.typography.titleLarge, color = if (here) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface)
                }
            }
            if (mo.vaccines.isNotEmpty()) Box(Modifier.align(Alignment.TopEnd).size(11.dp).background(Palette.Rod, CircleShape))
            if (mo.checkups.isNotEmpty()) Box(Modifier.align(Alignment.TopStart).size(10.dp).background(Palette.RedRod, RoundedCornerShape(2.dp)))
            if (done) Box(Modifier.align(Alignment.BottomEnd).size(14.dp).background(Palette.Bead, CircleShape))
        }
        if (here) Creature(companion, Modifier.offset(x = sx - 24.dp, y = 0.dp).size(48.dp), look = androidx.compose.ui.geometry.Offset(if (left) 0.8f else -0.8f, 0.6f))
        // the card on the other side of the road
        Surface(shape = RoundedCornerShape(20.dp), color = if (here) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceContainerLowest,
            border = if (here) androidx.compose.foundation.BorderStroke(2.dp, MaterialTheme.colorScheme.primary) else null,
            modifier = Modifier.width(w * 0.62f).offset(x = if (left) w * 0.34f else w * 0.04f, y = 18.dp).heightIn(min = 114.dp)) {
            Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                val ctx = androidx.compose.ui.platform.LocalContext.current
                val cover = remember(m) { app.mossling.ui.components.ArtIndex.cover(ctx, m) }
                if (cover != null) app.mossling.ui.components.Art(cover, "", Modifier.width(84.dp).padding(end = 8.dp).clip(RoundedCornerShape(14.dp)))
                else if (family != null) MaterialStill(family, Modifier.width(72.dp).padding(end = 8.dp), ground = MaterialTheme.colorScheme.surfaceContainerHigh)
                Column(Modifier.weight(1f)) {
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text("$m", fontFamily = Numerals, style = MaterialTheme.typography.headlineSmall, color = if (here) MaterialTheme.colorScheme.primary else Palette.RedRod.copy(alpha = 0.9f))
                        Text(" 个月", style = MaterialTheme.typography.labelMedium, modifier = Modifier.padding(bottom = 3.dp))
                        Spacer(Modifier.weight(1f))
                        if (date != null) Text("${date.year}.${date.monthValue}.${date.dayOfMonth}", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Text(mo.title, style = MaterialTheme.typography.bodyMedium)
                }
            }
        }
    }
}

/**
 * A paper butterfly that crosses the map every so often, flapping, never in the way (it ignores touches except a
 * tap on itself). Nothing moves when animations are off.
 */
@Composable
private fun Butterfly(modifier: Modifier, onTap: () -> Unit) {
    if (reducedMotion()) return
    val x = remember { Animatable(-0.15f) }
    var y by remember { mutableStateOf(0.4f) }
    var tint by remember { mutableStateOf(Palette.Bead) }
    var flying by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        delay(1800)
        while (true) {
            y = 0.25f + Random.nextFloat() * 0.5f
            tint = listOf(Palette.Bead, Palette.RodLight, Palette.RedRod, Palette.MossLight).random()
            flying = true; x.snapTo(-0.15f)
            x.animateTo(1.15f, tween(8500, easing = LinearEasing))
            flying = false
            delay(15_000)
        }
    }
    if (!flying) return
    val flap by rememberInfiniteTransition(label = "flap").animateFloat(1f, 0.3f, infiniteRepeatable(tween(220), RepeatMode.Reverse), label = "w")
    BoxWithConstraints(modifier) {
        val px = maxWidth * x.value
        val bob = (sin(x.value * 14f) * 14f).dp
        Canvas(Modifier.offset(x = px, y = maxHeight * y + bob).size(40.dp, 30.dp)
            .clickable(interactionSource = remember { MutableInteractionSource() }, indication = null, onClick = onTap)
            .semantics { contentDescription = "纸蝴蝶：回到宝宝现在的月份" }) {
            val s = size.width / 40f
            withTransform({ scale(s, s, Offset.Zero); rotate(sin(x.value * 9f) * 10f, Offset(20f, 15f)) }) {
                val edge = Color(0xFF8B7A66)
                fun wing(dir: Float) {
                    withTransform({ scale(dir * flap, 1f, Offset(20f, 15f)) }) {
                        val up = Path().apply { moveTo(20f, 15f); cubicTo(12f, 2f, 2f, 4f, 4f, 12f); cubicTo(5f, 17f, 13f, 18f, 20f, 15f); close() }
                        val dn = Path().apply { moveTo(20f, 16f); cubicTo(13f, 18f, 8f, 24f, 12f, 27f); cubicTo(15f, 29f, 19f, 24f, 20f, 16f); close() }
                        drawPath(up, tint); drawPath(up, edge, style = Stroke(1f)); drawPath(dn, tint.copy(alpha = 0.85f)); drawPath(dn, edge, style = Stroke(1f))
                    }
                }
                wing(1f); wing(-1f)
                drawLine(Color(0xFF5A4A3A), Offset(20f, 10f), Offset(20f, 22f), 2f, StrokeCap.Round)
            }
        }
    }
}
