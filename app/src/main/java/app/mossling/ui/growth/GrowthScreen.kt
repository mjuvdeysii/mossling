package app.mossling.ui.growth

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import app.mossling.AppUi
import app.mossling.data.Measure
import app.mossling.domain.Growth
import app.mossling.domain.Indicator
import app.mossling.ui.components.SectionTitle
import app.mossling.ui.components.G
import app.mossling.ui.components.Glyph
import app.mossling.domain.ageOn
import androidx.compose.ui.graphics.Color
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.drawText
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette
import app.mossling.ui.you.Bar
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

data class GrowthActions(val back: () -> Unit = {}, val add: () -> Unit = {}, val edit: (Measure) -> Unit = {}, val sex: (String) -> Unit = {})

private fun Measure.value(i: Indicator): Double? = when (i) { Indicator.Weight -> weightG?.div(1000.0); Indicator.Length -> lengthMm?.div(10.0); Indicator.Head -> headMm?.div(10.0) }
private fun monthsAt(birth: LocalDate, at: Long) = ChronoUnit.DAYS.between(birth, dayOf(at)) / 30.4375
private fun dayOf(at: Long): LocalDate = Instant.ofEpochMilli(at).atZone(ZoneId.systemDefault()).toLocalDate()

/** Each measure has its own colour and pictogram, the same in the tiles, the chart and the list. */
private val Indicator.tint get() = when (this) { Indicator.Weight -> Color(0xFFB07D0C); Indicator.Length -> Palette.Rod; Indicator.Head -> Palette.Mint }
private val Indicator.glyph get() = when (this) { Indicator.Weight -> G.Scale; Indicator.Length -> G.Ruler; Indicator.Head -> G.Head }
private val Indicator.short get() = when (this) { Indicator.Weight -> "体重"; Indicator.Length -> "身长"; Indicator.Head -> "头围" }
private fun Indicator.fmt(v: Double) = if (this == Indicator.Weight) "%.2f".format(v) else "%.1f".format(v)

/** "第 42 百分位"; the far ends say what they are rather than a rounded number. */
fun pctText(p: Double): String = when { p < 3 -> "低于第 3 百分位"; p > 97 -> "高于第 97 百分位"; else -> "第 ${p.toInt().coerceIn(3, 97)} 百分位" }

private fun ageText(birth: LocalDate, d: LocalDate): String {
    val a = ageOn(birth, d)
    return if (a.months == 0) "出生第 ${a.lived} 天" else if (a.days == 0) "满 ${a.months} 个月" else "${a.months} 个月 ${a.days} 天"
}

/**
 * Weight, length and head circumference against the WHO Child Growth Standards: the latest of each on top, then the
 * chart (3rd–97th and 15th–85th percentile bands, the median, the child's own line), then every measurement. A
 * percentile is a position, not a grade.
 */
@Composable
fun GrowthScreen(ui: AppUi, growth: Growth, a: GrowthActions) {
    var ind by rememberSaveable { mutableStateOf(Indicator.Weight) }
    val birth = ui.settings.birth
    val girl = ui.settings.sex == "girl"
    val known = birth != null && ui.settings.sex != null
    val sorted = ui.measures.sortedBy { it.at }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 120.dp)) {
        item { Bar("生长", a.back) }
        // the latest of each measure; a tile is also the switch for the chart
        item {
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Indicator.entries.forEach { x ->
                    val hist = sorted.filter { it.value(x) != null }
                    val last = hist.lastOrNull(); val prev = hist.dropLast(1).lastOrNull()
                    Tile(x, selected = ind == x, last = last?.value(x), delta = if (last != null && prev != null) last.value(x)!! - prev.value(x)!! else null,
                        pct = if (known && last != null) growth.percentile(x, girl, monthsAt(birth!!, last.at), last.value(x)!!) else null,
                        modifier = Modifier.weight(1f)) { ind = x }
                }
            }
        }
        if (ui.settings.sex == null) item {
            Surface(shape = RoundedCornerShape(22.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 12.dp)) {
                Column(Modifier.padding(16.dp)) {
                    Text("选择性别以对照 WHO 生长曲线", style = MaterialTheme.typography.bodyMedium)
                    Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = { a.sex("boy") }, shape = RoundedCornerShape(16.dp)) { Text("男孩") }
                        Button(onClick = { a.sex("girl") }, shape = RoundedCornerShape(16.dp)) { Text("女孩") }
                    }
                }
            }
        }
        item {
            val pts = if (birth == null) emptyList() else sorted.mapNotNull { m -> m.value(ind)?.let { Pt(monthsAt(birth, m.at), it, dayOf(m.at)) } }
            val ageNow = ui.age?.let { it.months + it.days / 30.4375 }
            Surface(shape = RoundedCornerShape(28.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 12.dp)) {
                Column(Modifier.padding(top = 16.dp, bottom = 12.dp)) {
                    Row(Modifier.padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                        app.mossling.ui.components.ShapeBadge(ind.glyph, ind.tint.copy(alpha = 0.16f), ind.tint, shape = app.mossling.ui.components.Shapes.Cookie, size = 36.dp)
                        Column(Modifier.padding(start = 10.dp)) {
                            Text("${ind.label} · ${ind.unit}", style = MaterialTheme.typography.titleMedium)
                            Text(if (ui.settings.sex == null) "WHO 儿童生长标准" else "WHO 儿童生长标准 · " + if (girl) "女孩" else "男孩",
                                style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    Chart(growth, ind, girl, pts, ageNow, span = (maxOf(ageNow ?: 0.0, pts.maxOfOrNull { it.m } ?: 0.0) + 3).coerceIn(6.0, 36.0),
                        modifier = Modifier.fillMaxWidth().padding(start = 4.dp, end = 8.dp, top = 12.dp))
                    Legend(ind, Modifier.padding(horizontal = 16.dp, vertical = 8.dp))
                }
            }
            Text("资料来源：世界卫生组织儿童生长标准（2006）。百分位表示同龄同性别儿童中的位置，不是评分；判断生长情况请以儿童保健医生的评估为准。",
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(horizontal = 24.dp, vertical = 10.dp))
        }
        item { SectionTitle("每一次测量", kicker = if (ui.measures.isEmpty()) "还没有" else "${ui.measures.size} 次", glyph = G.Ruler) }
        val rev = sorted.reversed()
        items(rev, key = { it.id }) { m ->
            val prev = sorted.getOrNull(sorted.indexOf(m) - 1)
            MeasureRow(m, prev, birth, ind, if (known && m.value(ind) != null) growth.percentile(ind, girl, monthsAt(birth!!, m.at), m.value(ind)!!) else null) { a.edit(m) }
        }
        item {
            Button(onClick = a.add, shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth().padding(16.dp).heightIn(min = 52.dp)) {
                Glyph(G.Plus, size = 18.dp); Spacer(Modifier.width(8.dp)); Text("记一次测量")
            }
        }
    }
}

private data class Pt(val m: Double, val v: Double, val day: LocalDate)

@Composable
private fun Tile(x: Indicator, selected: Boolean, last: Double?, delta: Double?, pct: Double?, modifier: Modifier, onClick: () -> Unit) {
    Surface(onClick = onClick, shape = RoundedCornerShape(22.dp), color = if (selected) x.tint.copy(alpha = 0.14f) else MaterialTheme.colorScheme.surfaceContainerLow,
        border = if (selected) androidx.compose.foundation.BorderStroke(2.dp, x.tint) else null, modifier = modifier.semantics { contentDescription = x.label }) {
        Column(Modifier.padding(horizontal = 12.dp, vertical = 12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Glyph(x.glyph, size = 20.dp, color = x.tint, filled = selected)
                Text(" " + x.short, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Row(verticalAlignment = Alignment.Bottom, modifier = Modifier.padding(top = 6.dp)) {
                Text(last?.let { x.fmt(it) } ?: "—", fontFamily = Numerals, style = MaterialTheme.typography.headlineSmall, modifier = Modifier.alignByBaseline())
                if (last != null) Text(if (x == Indicator.Weight) " kg" else " cm", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.alignByBaseline())
            }
            delta?.let { d -> Text((if (d >= 0) "+" else "−") + x.fmt(kotlin.math.abs(d)), fontFamily = Numerals, style = MaterialTheme.typography.labelMedium, color = x.tint) }
            pct?.let { Text(pctText(it), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
    }
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun Legend(ind: Indicator, modifier: Modifier) {
    val outline = MaterialTheme.colorScheme.outline
    val mid = MaterialTheme.colorScheme.onSurfaceVariant
    androidx.compose.foundation.layout.FlowRow(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        @Composable fun swatch(text: String, draw: androidx.compose.ui.graphics.drawscope.DrawScope.() -> Unit) = Row(verticalAlignment = Alignment.CenterVertically) {
            Canvas(Modifier.width(22.dp).height(12.dp), onDraw = draw); Text(" $text", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        swatch("第 15–85 百分位") { drawRoundRect(ind.tint.copy(alpha = 0.22f), cornerRadius = androidx.compose.ui.geometry.CornerRadius(4f)) }
        swatch("第 3–97 百分位") { drawRoundRect(ind.tint.copy(alpha = 0.09f), cornerRadius = androidx.compose.ui.geometry.CornerRadius(4f)) }
        swatch("中位数") { drawLine(mid, Offset(0f, size.height / 2), Offset(size.width, size.height / 2), 2.2f) }
        swatch("第 3 / 97") { drawLine(outline, Offset(0f, size.height / 2), Offset(size.width, size.height / 2), 1.4f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 5f))) }
        swatch("测量") { drawLine(ind.tint, Offset(0f, size.height / 2), Offset(size.width, size.height / 2), 2.4f); drawCircle(Palette.Paper, 5f, center); drawCircle(ind.tint, 3.6f, center) }
    }
}

/** A tidy step for the value axis: about five lines. */
private fun niceStep(range: Double): Double {
    val raw = range / 5; val mag = Math.pow(10.0, kotlin.math.floor(kotlin.math.log10(raw)))
    return listOf(1.0, 2.0, 2.5, 5.0, 10.0).map { it * mag }.first { it >= raw }
}

@Composable
private fun Chart(g: Growth, ind: Indicator, girl: Boolean, pts: List<Pt>, ageNow: Double?, span: Double, modifier: Modifier) {
    val tint = ind.tint
    val line = MaterialTheme.colorScheme.outline
    val mid = MaterialTheme.colorScheme.onSurfaceVariant
    val grid = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f)
    val ink = MaterialTheme.colorScheme.onSurface
    val surface = MaterialTheme.colorScheme.surfaceContainerHighest
    val axis = MaterialTheme.typography.labelSmall.copy(color = MaterialTheme.colorScheme.onSurfaceVariant, fontFamily = Numerals)
    val tip = MaterialTheme.typography.labelMedium.copy(color = ink, fontFamily = Numerals)
    val tm = androidx.compose.ui.text.rememberTextMeasurer()
    var pick by remember(ind, pts.size) { mutableStateOf(if (pts.isEmpty()) -1 else pts.lastIndex) }
    val label = "${ind.label}曲线，${pts.size} 个测量点" + (pts.lastOrNull()?.let { "，最近一次 ${ind.fmt(it.v)} ${ind.unit}" } ?: "")
    val geo = remember { floatArrayOf(0f, 0f, 1f, 1f) } // left, top, plot width, plot height
    Canvas(modifier.aspectRatio(1.1f).semantics { contentDescription = label }
        .pointerInput(pts, span) {
            detectTapGestures { o ->
                if (pts.isEmpty()) return@detectTapGestures
                val (l, _, w, _) = geo.toList()
                val near = pts.indices.minByOrNull { kotlin.math.abs(l + (pts[it].m / span * w).toFloat() - o.x) } ?: -1
                pick = near
            }
        }) {
        val left = 40.dp.toPx(); val right = 26.dp.toPx(); val top = 8.dp.toPx(); val bottom = 22.dp.toPx()
        val w = size.width - left - right; val h = size.height - top - bottom
        geo[0] = left; geo[1] = top; geo[2] = w; geo[3] = h
        val steps = (span * 4).toInt().coerceAtLeast(8)
        val xs = (0..steps).map { it * span / steps }
        val lo = xs.minOf { g.at(ind, girl, it, 3) }; val hi = xs.maxOf { g.at(ind, girl, it, 97) }
        val ys = pts.map { it.v }
        val step = niceStep(maxOf(hi, ys.maxOrNull() ?: hi) - minOf(lo, ys.minOrNull() ?: lo))
        val y0 = kotlin.math.floor(minOf(lo, ys.minOrNull() ?: lo) / step) * step
        val y1 = kotlin.math.ceil(maxOf(hi, ys.maxOrNull() ?: hi) / step) * step
        fun px(m: Double) = left + (m / span * w).toFloat()
        fun py(v: Double) = top + (h - (v - y0) / (y1 - y0) * h).toFloat()
        // value grid and labels
        var v = y0
        while (v <= y1 + 1e-9) {
            drawLine(grid, Offset(left, py(v)), Offset(left + w, py(v)), 1f)
            val t = tm.measure(if (step < 1) "%.1f".format(v) else "%.0f".format(v), axis)
            drawText(t, topLeft = Offset(left - t.size.width - 6.dp.toPx(), py(v) - t.size.height / 2))
            v += step
        }
        // month grid and labels, aligned to the plot
        val every = if (span <= 12) 1 else if (span <= 24) 3 else 6
        val labelEvery = if (span <= 12) 2 else if (span <= 24) 6 else 6
        for (m in 0..span.toInt() step every) {
            drawLine(grid, Offset(px(m.toDouble()), top), Offset(px(m.toDouble()), top + h), 1f)
            if (m % labelEvery == 0) { val t = tm.measure("${m}月", axis); drawText(t, topLeft = Offset((px(m.toDouble()) - t.size.width / 2).coerceIn(left - 8f, left + w - t.size.width.toFloat()), top + h + 4.dp.toPx())) }
        }
        fun band(a: Int, b: Int, alpha: Float) = drawPath(Path().apply {
            xs.forEachIndexed { i, m -> val o = Offset(px(m), py(g.at(ind, girl, m, b))); if (i == 0) moveTo(o.x, o.y) else lineTo(o.x, o.y) }
            xs.reversed().forEach { m -> lineTo(px(m), py(g.at(ind, girl, m, a))) }; close()
        }, tint.copy(alpha = alpha))
        band(3, 97, 0.09f); band(15, 85, 0.20f)
        Growth.Lines.forEach { pc ->
            if (pc == 15 || pc == 85) return@forEach
            val l = Path().apply { xs.forEachIndexed { i, m -> val o = Offset(px(m), py(g.at(ind, girl, m, pc))); if (i == 0) moveTo(o.x, o.y) else lineTo(o.x, o.y) } }
            drawPath(l, if (pc == 50) mid else line, style = Stroke(if (pc == 50) 2.2f else 1.4f, pathEffect = if (pc == 50) null else PathEffect.dashPathEffect(floatArrayOf(8f, 8f))))
        }
        // percentile names at the right end of each curve
        Growth.Lines.forEach { pc ->
            val t = tm.measure("$pc", axis); val y = py(g.at(ind, girl, span, pc))
            drawText(t, topLeft = Offset(left + w + 4.dp.toPx(), y - t.size.height / 2))
        }
        // today
        ageNow?.takeIf { it in 0.0..span }?.let { m ->
            drawLine(tint.copy(alpha = 0.7f), Offset(px(m), top), Offset(px(m), top + h), 1.6f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f, 6f)))
            val t = tm.measure("今天", axis.copy(color = tint)); drawText(t, topLeft = Offset((px(m) - t.size.width / 2).coerceAtMost(left + w - t.size.width), top))
        }
        // the child's own line
        if (pts.size > 1) drawPath(Path().apply { pts.forEachIndexed { i, p -> if (i == 0) moveTo(px(p.m), py(p.v)) else lineTo(px(p.m), py(p.v)) } }, tint, style = Stroke(2.6f, cap = androidx.compose.ui.graphics.StrokeCap.Round, join = androidx.compose.ui.graphics.StrokeJoin.Round))
        pts.forEachIndexed { i, p ->
            val c = Offset(px(p.m), py(p.v)); val on = i == pick
            drawCircle(Palette.Paper, if (on) 9f else 7f, c); drawCircle(tint, if (on) 7f else 5f, c)
            if (on) drawCircle(tint.copy(alpha = 0.25f), 14f, c)
        }
        // the picked point, spelled out
        pts.getOrNull(pick)?.let { p ->
            val t = tm.measure("${p.day.monthValue}月${p.day.dayOfMonth}日 · ${ind.fmt(p.v)} ${ind.unit}", tip)
            val pad = 6.dp.toPx(); val bw = t.size.width + pad * 2; val bh = t.size.height + pad
            val cx = px(p.m); val cy = py(p.v)
            val bx = (cx - bw / 2).coerceIn(left, left + w - bw); val by = if (cy - bh - 16f > top) cy - bh - 14f else cy + 14f
            drawRoundRect(surface, Offset(bx, by), androidx.compose.ui.geometry.Size(bw, bh), androidx.compose.ui.geometry.CornerRadius(8.dp.toPx()))
            drawText(t, topLeft = Offset(bx + pad, by + pad / 2))
        }
    }
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun MeasureRow(m: Measure, prev: Measure?, birth: LocalDate?, ind: Indicator, pct: Double?, onClick: () -> Unit) {
    val d = dayOf(m.at)
    Surface(onClick = onClick, color = Color.Transparent, modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(horizontal = 20.dp, vertical = 10.dp), verticalAlignment = Alignment.Top) {
            Column(Modifier.width(112.dp)) {
                Text("${d.year}.${d.monthValue}.${d.dayOfMonth}", fontFamily = Numerals, style = MaterialTheme.typography.titleMedium)
                birth?.let { Text(ageText(it, d), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant) }
            }
            Column(Modifier.weight(1f)) {
                androidx.compose.foundation.layout.FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Indicator.entries.forEach { x ->
                        m.value(x)?.let { v ->
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Glyph(x.glyph, size = 16.dp, color = x.tint)
                                Text(" ${x.fmt(v)}", fontFamily = Numerals, style = MaterialTheme.typography.bodyLarge, color = if (x == ind) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant)
                                Text(if (x == Indicator.Weight) " kg" else " cm", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
                val dv = prev?.value(ind)?.let { pv -> m.value(ind)?.let { it - pv } }
                val bits = listOfNotNull(pct?.let { pctText(it) }, dv?.let { (if (it >= 0) "比上次 +" else "比上次 −") + ind.fmt(kotlin.math.abs(it)) })
                if (bits.isNotEmpty()) Text("${ind.short} " + bits.joinToString(" · "), style = MaterialTheme.typography.labelMedium, color = ind.tint, modifier = Modifier.padding(top = 2.dp))
            }
        }
    }
}

/** Add or change one measurement: any of the three, on any day. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MeasureSheet(m: Measure, onSave: (Measure) -> Unit, onDelete: (Measure) -> Unit, onDismiss: () -> Unit) {
    var w by remember(m.id) { mutableStateOf(m.weightG?.let { "%.2f".format(it / 1000.0) } ?: "") }
    var l by remember(m.id) { mutableStateOf(m.lengthMm?.let { "%.1f".format(it / 10.0) } ?: "") }
    var h by remember(m.id) { mutableStateOf(m.headMm?.let { "%.1f".format(it / 10.0) } ?: "") }
    var day by remember(m.id) { mutableStateOf(Instant.ofEpochMilli(m.at).atZone(ZoneId.systemDefault()).toLocalDate()) }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = MaterialTheme.colorScheme.surfaceContainerLowest) {
        Column(Modifier.fillMaxWidth().padding(horizontal = 24.dp).padding(bottom = 24.dp).navigationBarsPadding()) {
            Text(if (m.id == 0L) "记一次测量" else "这次测量", style = MaterialTheme.typography.headlineSmall)
            var calendar by remember { mutableStateOf(false) }
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                TextButton(onClick = { day = day.minusDays(1) }) { Text("前一天") }
                androidx.compose.material3.FilledTonalButton(onClick = { calendar = true }, shape = RoundedCornerShape(16.dp), modifier = Modifier.weight(1f).heightIn(min = 48.dp)) {
                    Text("${day.year}年${day.monthValue}月${day.dayOfMonth}日" + if (day == LocalDate.now()) " · 今天" else "", style = MaterialTheme.typography.titleSmall)
                }
                TextButton(onClick = { if (day < LocalDate.now()) day = day.plusDays(1) }, enabled = day < LocalDate.now()) { Text("后一天") }
            }
            if (calendar) {
                val ds = androidx.compose.material3.rememberDatePickerState(initialSelectedDateMillis = day.atStartOfDay(java.time.ZoneOffset.UTC).toInstant().toEpochMilli(),
                    selectableDates = object : androidx.compose.material3.SelectableDates { override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis <= System.currentTimeMillis() })
                androidx.compose.material3.DatePickerDialog(onDismissRequest = { calendar = false },
                    confirmButton = { TextButton(onClick = { ds.selectedDateMillis?.let { day = Instant.ofEpochMilli(it).atZone(java.time.ZoneOffset.UTC).toLocalDate() }; calendar = false }) { Text("好") } },
                    dismissButton = { TextButton(onClick = { calendar = false }) { Text("取消") } }) { androidx.compose.material3.DatePicker(ds) }
            }
            val num = KeyboardOptions(keyboardType = KeyboardType.Decimal)
            val wg = w.toDoubleOrNull()?.takeIf { it in 1.0..30.0 }?.let { Math.round(it * 1000).toInt() }
            val lm = l.toDoubleOrNull()?.takeIf { it in 35.0..120.0 }?.let { Math.round(it * 10).toInt() }
            val hm = h.toDoubleOrNull()?.takeIf { it in 25.0..60.0 }?.let { Math.round(it * 10).toInt() }
            @Composable fun field(x: Indicator, text: String, set: (String) -> Unit, ok: Boolean, hint: String, max: Int) =
                OutlinedTextField(text, { set(it.filter { c -> c.isDigit() || c == '.' }.take(max)) }, Modifier.fillMaxWidth().padding(top = 8.dp),
                    label = { Text(x.label) }, leadingIcon = { Glyph(x.glyph, size = 22.dp, color = x.tint) }, suffix = { Text(x.unit) },
                    supportingText = { Text(hint) }, isError = text.isNotBlank() && !ok, keyboardOptions = num, singleLine = true, shape = RoundedCornerShape(16.dp))
            field(Indicator.Weight, w, { w = it }, wg != null, "精确到 0.01 千克，如 7.85", 6)
            field(Indicator.Length, l, { l = it }, lm != null, "精确到 0.1 厘米；2 岁前躺着量身长", 5)
            field(Indicator.Head, h, { h = it }, hm != null, "精确到 0.1 厘米，经眉上缘与后脑最突出处", 5)
            Row(Modifier.fillMaxWidth().padding(top = 16.dp)) {
                if (m.id != 0L) TextButton(onClick = { onDelete(m); onDismiss() }) { Text("删除", color = MaterialTheme.colorScheme.error) }
                Spacer(Modifier.weight(1f))
                Button(onClick = {
                    onSave(m.copy(at = day.atTime(12, 0).atZone(ZoneId.systemDefault()).toInstant().toEpochMilli(), weightG = wg, lengthMm = lm, headMm = hm)); onDismiss()
                }, enabled = wg != null || lm != null || hm != null, shape = RoundedCornerShape(18.dp), modifier = Modifier.heightIn(min = 48.dp)) { Text("好") }
            }
        }
    }
}
