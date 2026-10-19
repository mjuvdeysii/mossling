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
import app.mossling.ui.theme.Numerals
import app.mossling.ui.theme.Palette
import app.mossling.ui.you.Bar
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

data class GrowthActions(val back: () -> Unit = {}, val add: () -> Unit = {}, val edit: (Measure) -> Unit = {}, val sex: (String) -> Unit = {})

private fun Measure.value(i: Indicator): Double? = when (i) { Indicator.Weight -> weightG?.div(1000.0); Indicator.Length -> lengthMm?.div(10.0); Indicator.Head -> headMm?.div(10.0) }
private fun monthsAt(birth: LocalDate, at: Long) = ChronoUnit.DAYS.between(birth, Instant.ofEpochMilli(at).atZone(ZoneId.systemDefault()).toLocalDate()) / 30.4375

/**
 * Weight, length and head circumference against the WHO Child Growth Standards: the band from the 15th to the 85th
 * percentile, the 3rd/50th/97th lines, and this child's own points. A percentile is a position, not a grade.
 */
@Composable
fun GrowthScreen(ui: AppUi, growth: Growth, a: GrowthActions) {
    var ind by rememberSaveable { mutableStateOf(Indicator.Weight) }
    val birth = ui.settings.birth
    val girl = ui.settings.sex == "girl"
    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 120.dp)) {
        item { Bar("生长", a.back) }
        item {
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
                Indicator.entries.forEachIndexed { i, x -> SegmentedButton(selected = ind == x, onClick = { ind = x }, shape = SegmentedButtonDefaults.itemShape(i, 3)) { Text(x.label.substringBefore(" ")) } }
            }
        }
        if (ui.settings.sex == null) item {
            Surface(shape = RoundedCornerShape(22.dp), color = MaterialTheme.colorScheme.surfaceContainerLow, modifier = Modifier.fillMaxWidth().padding(16.dp)) {
                Column(Modifier.padding(16.dp)) {
                    Text("世界卫生组织的生长标准分男孩和女孩两套曲线。", style = MaterialTheme.typography.bodyMedium)
                    Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = { a.sex("boy") }, shape = RoundedCornerShape(16.dp)) { Text("男孩") }
                        Button(onClick = { a.sex("girl") }, shape = RoundedCornerShape(16.dp)) { Text("女孩") }
                    }
                }
            }
        }
        item {
            val pts = if (birth == null) emptyList() else ui.measures.mapNotNull { m -> m.value(ind)?.let { monthsAt(birth, m.at) to it } }
            val ageNow = ui.age?.let { it.months + it.days / 30.4375 } ?: 0.0
            Chart(growth, ind, girl, pts, span = (maxOf(ageNow, pts.maxOfOrNull { it.first } ?: 0.0) + 3).coerceIn(6.0, 36.0),
                modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 12.dp))
            Text("浅色带是第 15 到第 85 百分位，三条线是第 3、50、97 百分位。来源：世界卫生组织儿童生长标准（2006）。",
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(horizontal = 20.dp))
        }
        item { SectionTitle("每一次测量", kicker = if (ui.measures.isEmpty()) "还没有" else "${ui.measures.size} 次") }
        items(ui.measures.reversed(), key = { it.id }) { m ->
            val d = Instant.ofEpochMilli(m.at).atZone(ZoneId.systemDefault()).toLocalDate()
            Row(Modifier.fillMaxWidth().clickable { a.edit(m) }.heightIn(min = 56.dp).padding(horizontal = 20.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("${d.year}.${d.monthValue}.${d.dayOfMonth}", fontFamily = Numerals, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                Column(horizontalAlignment = Alignment.End) {
                    Text(listOfNotNull(m.weightG?.let { "%.2f 千克".format(it / 1000.0) }, m.lengthMm?.let { "%.1f 厘米".format(it / 10.0) }, m.headMm?.let { "头围 %.1f".format(it / 10.0) }).joinToString(" · "),
                        style = MaterialTheme.typography.bodyMedium)
                    if (birth != null && ui.settings.sex != null) m.value(ind)?.let { v ->
                        Text("第 ${growth.percentile(ind, girl, monthsAt(birth, m.at), v).toInt().coerceIn(1, 99)} 百分位", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
        item {
            Button(onClick = a.add, shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth().padding(16.dp).heightIn(min = 52.dp)) { Text("记一次测量") }
        }
    }
}

@Composable
private fun Chart(g: Growth, ind: Indicator, girl: Boolean, pts: List<Pair<Double, Double>>, span: Double, modifier: Modifier) {
    val band = if (girl) Palette.Bead.copy(alpha = 0.16f) else Palette.Rod.copy(alpha = 0.12f)
    val line = MaterialTheme.colorScheme.outline
    val mid = MaterialTheme.colorScheme.onSurfaceVariant
    val dot = MaterialTheme.colorScheme.primary
    val grid = MaterialTheme.colorScheme.outlineVariant
    val label = "${ind.label}曲线，${pts.size} 个测量点"
    Canvas(modifier.aspectRatio(1.25f).semantics { contentDescription = label }) {
        val steps = (span * 4).toInt().coerceAtLeast(8)
        val xs = (0..steps).map { it * span / steps }
        val lo = xs.minOf { g.at(ind, girl, it, 3) } * 0.96; val hi = xs.maxOf { g.at(ind, girl, it, 97) } * 1.03
        val ys = pts.map { it.second }; val y0 = minOf(lo, ys.minOrNull() ?: lo); val y1 = maxOf(hi, ys.maxOrNull() ?: hi)
        fun px(m: Double) = (m / span * size.width).toFloat()
        fun py(v: Double) = (size.height - (v - y0) / (y1 - y0) * size.height).toFloat()
        val every = if (span <= 12) 1 else if (span <= 24) 3 else 6
        for (m in 0..span.toInt() step every) drawLine(grid, Offset(px(m.toDouble()), 0f), Offset(px(m.toDouble()), size.height), 1f)
        val p = Path().apply {
            xs.forEachIndexed { i, m -> val o = Offset(px(m), py(g.at(ind, girl, m, 85))); if (i == 0) moveTo(o.x, o.y) else lineTo(o.x, o.y) }
            xs.reversed().forEach { m -> lineTo(px(m), py(g.at(ind, girl, m, 15))) }; close()
        }
        drawPath(p, band)
        listOf(3, 50, 97).forEach { pc ->
            val l = Path().apply { xs.forEachIndexed { i, m -> val o = Offset(px(m), py(g.at(ind, girl, m, pc))); if (i == 0) moveTo(o.x, o.y) else lineTo(o.x, o.y) } }
            drawPath(l, if (pc == 50) mid else line, style = Stroke(if (pc == 50) 2.2f else 1.4f, pathEffect = if (pc == 50) null else PathEffect.dashPathEffect(floatArrayOf(8f, 8f))))
        }
        if (pts.size > 1) drawPath(Path().apply { pts.sortedBy { it.first }.forEachIndexed { i, (m, v) -> if (i == 0) moveTo(px(m), py(v)) else lineTo(px(m), py(v)) } }, dot, style = Stroke(2.4f))
        pts.forEach { (m, v) -> drawCircle(Palette.Paper, 7f, Offset(px(m), py(v))); drawCircle(dot, 5f, Offset(px(m), py(v))) }
    }
    Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp)) {
        val every = if (span <= 12) 3 else if (span <= 24) 6 else 12
        (0..span.toInt() step every).forEach { m -> Text("${m}月", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.weight(1f)) }
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
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                TextButton(onClick = { day = day.minusDays(1) }) { Text("前一天") }
                Text("${day.monthValue}月${day.dayOfMonth}日" + if (day == LocalDate.now()) " · 今天" else "", style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                TextButton(onClick = { if (day < LocalDate.now()) day = day.plusDays(1) }, enabled = day < LocalDate.now()) { Text("后一天") }
            }
            val num = KeyboardOptions(keyboardType = KeyboardType.Decimal)
            OutlinedTextField(w, { w = it.filter { c -> c.isDigit() || c == '.' }.take(6) }, Modifier.fillMaxWidth().padding(top = 8.dp), label = { Text("体重（千克）") }, keyboardOptions = num, singleLine = true, shape = RoundedCornerShape(16.dp))
            OutlinedTextField(l, { l = it.filter { c -> c.isDigit() || c == '.' }.take(5) }, Modifier.fillMaxWidth().padding(top = 8.dp), label = { Text("身长 / 身高（厘米）") }, keyboardOptions = num, singleLine = true, shape = RoundedCornerShape(16.dp))
            OutlinedTextField(h, { h = it.filter { c -> c.isDigit() || c == '.' }.take(5) }, Modifier.fillMaxWidth().padding(top = 8.dp), label = { Text("头围（厘米）") }, keyboardOptions = num, singleLine = true, shape = RoundedCornerShape(16.dp))
            val wg = w.toDoubleOrNull()?.takeIf { it in 1.0..30.0 }?.let { Math.round(it * 1000).toInt() }
            val lm = l.toDoubleOrNull()?.takeIf { it in 35.0..120.0 }?.let { Math.round(it * 10).toInt() }
            val hm = h.toDoubleOrNull()?.takeIf { it in 25.0..60.0 }?.let { Math.round(it * 10).toInt() }
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
