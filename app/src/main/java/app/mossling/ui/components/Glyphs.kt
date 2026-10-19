package app.mossling.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.material3.LocalContentColor
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** The app's own small pictograms, drawn on a 24 × 24 grid with a 1.8 stroke: no stock icon set. */
enum class G { Today, Grow, Journal, You, Nurse, Bottle, Sleep, Diaper, Solid, Bath, Note, Play, Bead, Check, Plus, Close, Back, Clock, Sun, Moon }

@Composable
fun Glyph(g: G, modifier: Modifier = Modifier, size: Dp = 24.dp, color: Color = LocalContentColor.current, filled: Boolean = false) {
    Canvas(modifier.size(size)) {
        val s = this.size.minDimension / 24f
        withTransform({ scale(s, s, Offset.Zero) }) { drawGlyph(g, color, filled) }
    }
}

private fun DrawScope.drawGlyph(g: G, c: Color, filled: Boolean) {
    val st = Stroke(1.8f, cap = StrokeCap.Round, join = StrokeJoin.Round)
    fun path(b: Path.() -> Unit) = Path().apply(b)
    when (g) {
        G.Today -> { // a sun that is also an eye
            drawCircle(c, 5.2f, Offset(12f, 12f), style = if (filled) androidx.compose.ui.graphics.drawscope.Fill else st)
            if (filled) drawCircle(Color.White.copy(alpha = 0.9f), 1.8f, Offset(13f, 11.4f))
            for (i in 0 until 8) {
                val a = Math.toRadians(i * 45.0); val x = Math.cos(a).toFloat(); val y = Math.sin(a).toFloat()
                drawLine(c, Offset(12 + x * 8.3f, 12 + y * 8.3f), Offset(12 + x * 10.2f, 12 + y * 10.2f), 1.8f, StrokeCap.Round)
            }
        }
        G.Grow -> { // a short bead chain
            drawLine(c, Offset(2.5f, 15f), Offset(21.5f, 9f), 1.4f, StrokeCap.Round)
            listOf(Offset(5.5f, 14f), Offset(12f, 12f), Offset(18.5f, 10f)).forEachIndexed { i, o ->
                if (filled || i == 1) drawCircle(c, if (i == 1) 3.6f else 2.8f, o) else drawCircle(c, 2.8f, o, style = st)
            }
        }
        G.Journal -> {
            drawRoundRect(c, Offset(5f, 3.5f), Size(14f, 17f), CornerRadius(2.6f), style = if (filled) androidx.compose.ui.graphics.drawscope.Fill else st)
            val lc = if (filled) Color.White.copy(alpha = 0.85f) else c
            drawLine(lc, Offset(8.5f, 9f), Offset(15.5f, 9f), 1.6f, StrokeCap.Round); drawLine(lc, Offset(8.5f, 13f), Offset(13.5f, 13f), 1.6f, StrokeCap.Round)
        }
        G.You -> { // a pebble with two eyes: the companion
            val p = path { moveTo(4f, 17.5f); cubicTo(3f, 11f, 7f, 6f, 12.5f, 6f); cubicTo(18f, 6f, 21.5f, 10.5f, 20.5f, 16f); cubicTo(20f, 19.5f, 16f, 20.5f, 12f, 20.5f); cubicTo(7.5f, 20.5f, 4.5f, 20f, 4f, 17.5f); close() }
            if (filled) drawPath(p, c) else drawPath(p, c, style = st)
            val e = if (filled) Color.White else c
            drawCircle(e, 1.4f, Offset(10.2f, 12.8f)); drawCircle(e, 1.4f, Offset(14.6f, 12.8f))
        }
        G.Nurse -> { val p = path { moveTo(12f, 3.5f); cubicTo(16.5f, 9f, 18.5f, 12.5f, 18.5f, 15f); cubicTo(18.5f, 18.6f, 15.6f, 21f, 12f, 21f); cubicTo(8.4f, 21f, 5.5f, 18.6f, 5.5f, 15f); cubicTo(5.5f, 12.5f, 7.5f, 9f, 12f, 3.5f); close() }; if (filled) drawPath(p, c) else drawPath(p, c, style = st) }
        G.Bottle -> {
            drawRoundRect(c, Offset(7.5f, 8f), Size(9f, 13f), CornerRadius(3f), style = if (filled) androidx.compose.ui.graphics.drawscope.Fill else st)
            drawLine(c, Offset(9.5f, 8f), Offset(10.5f, 5f), 1.8f, StrokeCap.Round); drawLine(c, Offset(14.5f, 8f), Offset(13.5f, 5f), 1.8f, StrokeCap.Round); drawLine(c, Offset(10.5f, 5f), Offset(13.5f, 5f), 1.8f, StrokeCap.Round)
            drawLine(c, Offset(12f, 5f), Offset(12f, 2.8f), 1.8f, StrokeCap.Round)
        }
        G.Sleep, G.Moon -> { val p = path { moveTo(15.5f, 4f); cubicTo(10f, 4.5f, 6f, 8.5f, 6f, 13.5f); cubicTo(6f, 18f, 9.8f, 21f, 14f, 21f); cubicTo(16.6f, 21f, 18.6f, 20f, 20f, 18.4f); cubicTo(14.6f, 18.4f, 11.5f, 14.4f, 11.5f, 10.4f); cubicTo(11.5f, 7.8f, 13.2f, 5.2f, 15.5f, 4f); close() }; if (filled) drawPath(p, c) else drawPath(p, c, style = st) }
        G.Diaper -> { val p = path { moveTo(3.5f, 7f); lineTo(20.5f, 7f); lineTo(20.5f, 10f); cubicTo(17f, 11f, 15f, 14f, 14.5f, 18f); lineTo(9.5f, 18f); cubicTo(9f, 14f, 7f, 11f, 3.5f, 10f); close() }; if (filled) drawPath(p, c) else drawPath(p, c, style = st) }
        G.Solid -> { drawOval(c, Offset(8f, 3f), Size(8f, 9.5f), style = if (filled) androidx.compose.ui.graphics.drawscope.Fill else st); drawLine(c, Offset(12f, 12.5f), Offset(12f, 21f), 1.9f, StrokeCap.Round) }
        G.Bath -> { drawLine(c, Offset(3f, 12f), Offset(21f, 12f), 1.8f, StrokeCap.Round); drawPath(path { moveTo(4.5f, 12f); lineTo(5.5f, 17f); cubicTo(6f, 19f, 7.5f, 20f, 9.5f, 20f); lineTo(14.5f, 20f); cubicTo(16.5f, 20f, 18f, 19f, 18.5f, 17f); lineTo(19.5f, 12f) }, c, style = st); drawCircle(c, 1.3f, Offset(9f, 7f)); drawCircle(c, 1.8f, Offset(13.5f, 5.5f), style = Stroke(1.4f)) }
        G.Note -> { drawPath(path { moveTo(5f, 19f); lineTo(5.6f, 15.4f); lineTo(15.8f, 5.2f); cubicTo(16.6f, 4.4f, 17.9f, 4.4f, 18.7f, 5.2f); cubicTo(19.5f, 6f, 19.5f, 7.3f, 18.7f, 8.1f); lineTo(8.5f, 18.3f); close() }, c, style = st) }
        G.Play -> { drawCircle(c, 8.5f, Offset(12f, 12f), style = st); drawPath(path { moveTo(10f, 8.5f); lineTo(16f, 12f); lineTo(10f, 15.5f); close() }, c) }
        G.Bead -> { drawCircle(c, 7f, Offset(12f, 12f)); drawCircle(Color.White.copy(alpha = 0.55f), 2.2f, Offset(9.8f, 9.6f)) }
        G.Check -> drawPath(path { moveTo(5f, 12.5f); lineTo(10f, 17.5f); lineTo(19f, 7f) }, c, style = Stroke(2.2f, cap = StrokeCap.Round, join = StrokeJoin.Round))
        G.Plus -> { drawLine(c, Offset(12f, 5f), Offset(12f, 19f), 2f, StrokeCap.Round); drawLine(c, Offset(5f, 12f), Offset(19f, 12f), 2f, StrokeCap.Round) }
        G.Close -> { drawLine(c, Offset(6f, 6f), Offset(18f, 18f), 2f, StrokeCap.Round); drawLine(c, Offset(18f, 6f), Offset(6f, 18f), 2f, StrokeCap.Round) }
        G.Back -> drawPath(path { moveTo(15f, 5f); lineTo(8f, 12f); lineTo(15f, 19f) }, c, style = Stroke(2f, cap = StrokeCap.Round, join = StrokeJoin.Round))
        G.Clock -> { drawCircle(c, 8.5f, Offset(12f, 12f), style = st); drawPath(path { moveTo(12f, 7.5f); lineTo(12f, 12f); lineTo(15f, 14f) }, c, style = st) }
        G.Sun -> { drawCircle(c, 4.5f, Offset(12f, 12f)); for (i in 0 until 8) { val a = Math.toRadians(i * 45.0); drawLine(c, Offset(12 + Math.cos(a).toFloat() * 7.5f, 12 + Math.sin(a).toFloat() * 7.5f), Offset(12 + Math.cos(a).toFloat() * 9.6f, 12 + Math.sin(a).toFloat() * 9.6f), 1.8f, StrokeCap.Round) } }
    }
}
